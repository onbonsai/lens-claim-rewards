// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {AccountTokenClaim} from "./../src/AccountTokenClaim.sol";
import {IAccountTokenClaim} from "./../src/interfaces/IAccountTokenClaim.sol";
import {MockERC20} from "./../src/mocks/MockERC20.sol";

contract AccountTokenClaimTest is Test {
    AccountTokenClaim tokenClaim;
    MockERC20 token;

    uint16 firstEpoch = 1;
    uint256 totalAmount = 2 ether;
    uint256 claimAmount = 1 ether;
    uint256 profileCount = 2; // only 2 can claim

    address user1 = address(0x1);
    address user2 = address(0x2);

    address account1 = address(0x11);
    address account2 = address(0x22);

    function setUp() public {
        token = new MockERC20();
        tokenClaim = new AccountTokenClaim(address(token));

        token.mint(address(this), 1000 ether);
    }

    function testConstructor() public {
        assertEq(address(tokenClaim.token()), address(token));
    }

    function testSetClaimProof() public {
        bytes32 root = keccak256(abi.encodePacked(uint256(1)));
        // it reverts when not called by the owner
        vm.expectRevert(); // Ownable
        vm.prank(user1);
        tokenClaim.setClaimProof(1, 1, root);

        // it reverts when the token transfer was not approved
        vm.expectRevert(); // SafeTransfer
        tokenClaim.setClaimProof(1, 1, root);

        // sets storage
        uint256 total = 10 ether;
        _setClaimProof(total, 1 ether, root);

        assertEq(tokenClaim.merkleClaimAmountTotal(), total);

        // it reverts when trying to override a previous merkle claim root
        token.approve(address(tokenClaim), total);
        vm.expectRevert(IAccountTokenClaim.NotAllowed.selector);
        tokenClaim.setClaimProof(total, 1 ether, root);
    }

    // TODO: update with new account root
    function testClaimTokensWithProof() public {
        // {
        //     "root": "0xcd5508d76406968bb1fb212494f32cc74fa14a1ee8aa01710a07589255839349",
        //     "userData": {
        //         "0x0000000000000000000000000000000000000011": {
        //         "proof": [
        //             "0xc6587dca14bc6bd9b95c553e959785dc27de9e1ed1705932c0b3c95c54a37ffc"
        //         ],
        //         "eoa": "0x0000000000000000000000000000000000000001",
        //         "accountAddress": "0x0000000000000000000000000000000000000011",
        //         "claimScoreBbps": "9999",
        //         "claimableAmount": "9999000000000000000000"
        //         },
        //         "0x0000000000000000000000000000000000000022": {
        //         "proof": [
        //             "0xa7d03422a059a316666a490219cd8c594d78af30039bf21239adc197a0644418"
        //         ],
        //         "eoa": "0x0000000000000000000000000000000000000002",
        //         "accountAddress": "0x0000000000000000000000000000000000000022",
        //         "claimScoreBbps": "5000",
        //         "claimableAmount": "5000000000000000000000"
        //         }
        //     }
        // }

        // mock calls to Account.owner()
        vm.mockCall(
            account1,
            abi.encodeWithSelector(Ownable.owner.selector),
            abi.encode(user1)
        );
        vm.mockCall(
            account2,
            abi.encodeWithSelector(Ownable.owner.selector),
            abi.encode(user2)
        );

        // for user1 and user2 to claim
        bytes32 root = 0xcd5508d76406968bb1fb212494f32cc74fa14a1ee8aa01710a07589255839349;
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = 0xc6587dca14bc6bd9b95c553e959785dc27de9e1ed1705932c0b3c95c54a37ffc;
        uint16 claimScoreBbps = 9999;
        bytes32[] memory proof2 = new bytes32[](1);
        proof2[0] = 0xa7d03422a059a316666a490219cd8c594d78af30039bf21239adc197a0644418;
        uint16 claimScoreBbps2 = 5000;

        // set the proof + amounts
        uint256 total = 20 ether;
        uint256 per = 10 ether;
        _setClaimProof(total, per, root);

        // reverts when not called by the account owner
        vm.expectRevert(IAccountTokenClaim.NotAllowed.selector);
        vm.prank(user1);
        tokenClaim.claimTokensWithProof(proof, account2, claimScoreBbps);

        // reverts with a bad proof
        vm.expectRevert(IAccountTokenClaim.InvalidProof.selector);
        vm.prank(user1);
        tokenClaim.claimTokensWithProof(proof2, account1, claimScoreBbps);

        // it allows the user to claim their tokens
        vm.prank(user1);
        tokenClaim.claimTokensWithProof(proof, account1, claimScoreBbps);
        assertEq(token.balanceOf(account1), per * claimScoreBbps / 10000);
        assertEq(tokenClaim.claims(account1), true);

        // it reverts when trying to claim twice
        vm.expectRevert(IAccountTokenClaim.AlreadyClaimed.selector);
        vm.prank(user1);
        tokenClaim.claimTokensWithProof(proof, account1, claimScoreBbps);

        // it allows the other user to claim their tokens, at 50%
        vm.prank(user2);
        tokenClaim.claimTokensWithProof(proof2, account2, claimScoreBbps2);
        assertEq(token.balanceOf(account2), per * claimScoreBbps2 / 10000);
        assertEq(tokenClaim.claims(account2), true);

        // #withdrawUnclaimed

        // it reverts when calling before the end at
        vm.expectRevert(IAccountTokenClaim.NotAllowed.selector);
        tokenClaim.withdrawUnclaimed();

        // it withdraws the remaining merkle claim amount
        uint256 amount = tokenClaim.merkleClaimAmountTotal();
        uint256 balanceBefore = token.balanceOf(address(this));
        vm.warp(tokenClaim.merkleClaimEndAt());
        tokenClaim.withdrawUnclaimed();

        assertEq(token.balanceOf(address(this)), balanceBefore + amount);
    }

    function _setClaimProof(uint256 total, uint256 maxPer, bytes32 _merkleRoot) internal {
        token.approve(address(tokenClaim), total);
        tokenClaim.setClaimProof(total, maxPer, _merkleRoot);
    }
}