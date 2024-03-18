// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {ProfileTokenClaim} from "./../src/ProfileTokenClaim.sol";
import {IProfileTokenClaim} from "./../src/interfaces/IProfileTokenClaim.sol";
import "./utils/LensUtils.t.sol";

contract ProfileTokenClaimTest is LensUtils {
    ProfileTokenClaim tokenClaim;

    uint16 firstEpoch = 1;
    uint256 totalAmount = 2 ether;
    uint256 claimAmount = 1 ether;
    uint256 profileCount = 2; // only 2 can claim
    uint256 startingProfileId;

    function setUp() public override {
        super.setUp();

        tokenClaim = new ProfileTokenClaim(address(hub), address(moduleRegistry), address(token));
        startingProfileId = user.profileId;
    }

    function testConstructor() public {
        assertEq(address(tokenClaim.token()), address(token));
    }

    function testNewEpoch() public {
        // reverts when not called by the owner
        vm.expectRevert(); // Ownable
        vm.prank(user.owner);
        tokenClaim.newEpoch(1, 1, profileCount);

        // reverts when the caller does not approve the transfer
        vm.expectRevert(); // SafeTransfer
        tokenClaim.newEpoch(1, 1, profileCount);

        _newEpoch(startingProfileId);

        // it transfers tokens to the contract
        assertEq(token.balanceOf(address(tokenClaim)), totalAmount);

        // it updates storage
        assertEq(tokenClaim.epoch(), firstEpoch);
        (uint256 total,, uint256 perProfile,,) = tokenClaim.claimAmounts(firstEpoch);
        assertEq(total, totalAmount);
        assertEq(perProfile, claimAmount);
    }

    function testClaimTokens() public {
        // reverts when the epoch does not exist
        vm.expectRevert(IProfileTokenClaim.NotAllowed.selector);
        vm.prank(user.owner);
        tokenClaim.claimTokens(user.profileId);

        _newEpoch(startingProfileId);

        // reverts when not called by the profile owner or manager
        vm.expectRevert(IProfileTokenClaim.ExecutorInvalid.selector);
        tokenClaim.claimTokens(user.profileId);

        // view functions returns positive amount
        assertEq(tokenClaim.claimableAmount(user.profileId), claimAmount);

        // allows user to claim directly
        vm.prank(user.owner);
        tokenClaim.claimTokens(user.profileId);
        assertEq(token.balanceOf(user.owner), claimAmount);

        // does not allow them to claim again
        vm.expectRevert(IProfileTokenClaim.AlreadyClaimed.selector);
        vm.prank(user.owner);
        tokenClaim.claimTokens(user.profileId);

        // view functions returns 0
        assertEq(tokenClaim.claimableAmount(user.profileId), 0);

        // allows user to claim via profile manager
        vm.prank(defaultTransactionExecutor);
        tokenClaim.claimTokens(user2.profileId);
        assertEq(token.balanceOf(user2.owner), claimAmount);

        // does not allow user3 to claim when rewards are depleted
        (,uint256 available,,,) = tokenClaim.claimAmounts(firstEpoch);
        assertEq(available, 0);
        vm.expectRevert(IProfileTokenClaim.EpochEnded.selector);
        vm.prank(user3.owner);
        tokenClaim.claimTokens(user3.profileId);

        _newEpoch(3); // set new epoch claimable by profileId >= 3

        // it reverts with user trying to claim (profileId: 2)
        vm.expectRevert(IProfileTokenClaim.NotAllowed.selector);
        vm.prank(user.owner);
        tokenClaim.claimTokens(user.profileId);

        // view functions returns 0
        assertEq(tokenClaim.claimableAmount(user.profileId), 0);

        // it allows user2 to claim (profileId: 3)
        vm.prank(user2.owner);
        tokenClaim.claimTokens(user2.profileId);
        assertEq(token.balanceOf(user2.owner), claimAmount * 2);
    }

    function testSetClaimProof() public {
        bytes32 root = keccak256(abi.encodePacked(uint256(1)));
        // it reverts when not called by the owner
        vm.expectRevert(); // Ownable
        vm.prank(user.owner);
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
        vm.expectRevert(IProfileTokenClaim.NotAllowed.selector);
        tokenClaim.setClaimProof(total, 1 ether, root);
    }

    function testClaimTokensWithProof() public {
        // {
        //     "root": "0x196684a1becab6512d4f338ccd86278623f5bb09d9a12d670dfc1e55b0bbfcd7",
        //     "userData": {
        //         "2": {
        //         "proof": [
        //             "0x99c892f05877320e99f59f40a64bc82cd9cce357de2e679e0482f7a4821930cd"
        //         ],
        //         "leaf": "0xb554f56f3dd0e3f431f90d2d3f1f56a10fcb91ebf0f037b524499c6244787835",
        //         "profileId": "2",
        //         "claimScoreBbps": "10000"
        //         },
        //         "3": {
        //         "proof": [
        //             "0x58e00d2af795a36bdc7b7b54a8cdb3b5bde446d47b9d26ff2e2390f6ed1add58",
        //             "0x275423e5d2f39e1eef76e26f7d5e0a9d74dedeb452e783b9d0c7af6e007dd1bb",
        //             "0xb554f56f3dd0e3f431f90d2d3f1f56a10fcb91ebf0f037b524499c6244787835"
        //         ],
        //         "leaf": "0x8308e716b8f6e08300f76f019ded6f5ccdc8f75a5cf2d5d7c02afc4ddeeacb3b",
        //         "profileId": "3",
        //         "claimScoreBbps": "5000"
        //         }
        //     }
        // }

        // for user and user2 to claim (profile ids 2 and 3)
        bytes32 root = 0x196684a1becab6512d4f338ccd86278623f5bb09d9a12d670dfc1e55b0bbfcd7;
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = 0x99c892f05877320e99f59f40a64bc82cd9cce357de2e679e0482f7a4821930cd;
        uint16 claimScoreBbps = 10000;
        bytes32[] memory proof2 = new bytes32[](3);
        proof2[0] = 0x58e00d2af795a36bdc7b7b54a8cdb3b5bde446d47b9d26ff2e2390f6ed1add58;
        proof2[1] = 0x275423e5d2f39e1eef76e26f7d5e0a9d74dedeb452e783b9d0c7af6e007dd1bb;
        proof2[2] = 0xb554f56f3dd0e3f431f90d2d3f1f56a10fcb91ebf0f037b524499c6244787835;
        uint16 claimScoreBbps2 = 5000;

        // set the proof + amounts
        uint256 total = 20 ether;
        uint256 per = 10 ether;
        _setClaimProof(total, per, root);

        // reverts when not called by the profile owner or manager
        vm.expectRevert(IProfileTokenClaim.ExecutorInvalid.selector);
        tokenClaim.claimTokensWithProof(proof, user.profileId, claimScoreBbps);

        // reverts with a bad proof
        vm.expectRevert(IProfileTokenClaim.InvalidProof.selector);
        vm.prank(user.owner);
        tokenClaim.claimTokensWithProof(proof2, user.profileId, claimScoreBbps);

        // it allows the user to claim their tokens
        vm.prank(user.owner);
        tokenClaim.claimTokensWithProof(proof, user.profileId, claimScoreBbps);
        assertEq(token.balanceOf(user.owner), per);
        assertEq(tokenClaim.proofClaims(user.profileId), true);

        // it reverts when trying to claim twice
        vm.expectRevert(IProfileTokenClaim.AlreadyClaimed.selector);
        vm.prank(user.owner);
        tokenClaim.claimTokensWithProof(proof, user.profileId, claimScoreBbps);

        // it allows the other user to claim their tokens, at 50%
        vm.prank(user2.owner);
        tokenClaim.claimTokensWithProof(proof2, user2.profileId, claimScoreBbps2);
        assertEq(token.balanceOf(user2.owner), per * claimScoreBbps2 / 10000);
        assertEq(tokenClaim.proofClaims(user2.profileId), true);

        // #withdrawUnclaimedMerkleAmount

        // it reverts when calling before the end at
        vm.expectRevert(IProfileTokenClaim.NotAllowed.selector);
        tokenClaim.withdrawUnclaimedMerkleAmount();

        // it withdraws the remaining merkle claim amount
        uint256 amount = tokenClaim.merkleClaimAmountTotal();
        uint256 balanceBefore = token.balanceOf(address(this));
        vm.warp(tokenClaim.merkleClaimEndAt());
        tokenClaim.withdrawUnclaimedMerkleAmount();

        assertEq(token.balanceOf(address(this)), balanceBefore + amount);
    }

    function _newEpoch(uint256 _startingProfileId) internal {
        token.approve(address(tokenClaim), totalAmount);
        tokenClaim.newEpoch(_startingProfileId, totalAmount, profileCount);
    }

    function _setClaimProof(uint256 total, uint256 maxPer, bytes32 _merkleRoot) internal {
        token.approve(address(tokenClaim), total);
        tokenClaim.setClaimProof(total, maxPer, _merkleRoot);
    }
}