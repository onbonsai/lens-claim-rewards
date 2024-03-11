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

    function setUp() public override {
        super.setUp();

        tokenClaim = new ProfileTokenClaim(address(hub), address(moduleRegistry), address(token));
    }

    function testConstructor() public {
        assertEq(address(tokenClaim.token()), address(token));
    }

    function testNewEpoch() public {
        // reverts when not called by the owner
        vm.expectRevert(); // Ownable
        vm.prank(user.owner);
        tokenClaim.newEpoch(1, 1);

        // reverts when the caller does not approve the transfer
        vm.expectRevert(); // SafeTransfer
        tokenClaim.newEpoch(1, 1);

        _newEpoch();

        // it transfers tokens to the contract
        assertEq(token.balanceOf(address(tokenClaim)), totalAmount);

        // it updates storage
        assertEq(tokenClaim.epoch(), firstEpoch);
        (uint256 total,, uint256 perProfile) = tokenClaim.claimAmounts(firstEpoch);
        assertEq(total, totalAmount);
        assertEq(perProfile, claimAmount);
    }

    function testClaimTokens() public {
        // reverts when the epoch does not exist
        vm.expectRevert(IProfileTokenClaim.EpochEnded.selector);
        vm.prank(user.owner);
        tokenClaim.claimTokens(firstEpoch, user.profileId);

        _newEpoch();

        // reverts when not called by the profile owner or manager
        vm.expectRevert(IProfileTokenClaim.ExecutorInvalid.selector);
        tokenClaim.claimTokens(firstEpoch, user.profileId);

        // allows user to claim directly
        vm.prank(user.owner);
        tokenClaim.claimTokens(firstEpoch, user.profileId);
        assertEq(token.balanceOf(user.owner), claimAmount);

        // does not allow them to claim again
        vm.expectRevert(IProfileTokenClaim.AlreadyClaimed.selector);
        vm.prank(user.owner);
        tokenClaim.claimTokens(firstEpoch, user.profileId);

        // allows user to claim via profile manager
        vm.prank(defaultTransactionExecutor);
        tokenClaim.claimTokens(firstEpoch, user2.profileId);
        assertEq(token.balanceOf(user2.owner), claimAmount);

        // does not allow user3 to claim when rewards are depleted
        (,uint256 available,) = tokenClaim.claimAmounts(firstEpoch);
        assertEq(available, 0);
        vm.expectRevert(IProfileTokenClaim.EpochEnded.selector);
        vm.prank(user3.owner);
        tokenClaim.claimTokens(firstEpoch, user3.profileId);
    }

    function _newEpoch() internal {
        token.approve(address(tokenClaim), totalAmount);
        tokenClaim.newEpoch(totalAmount, claimAmount);
    }
}