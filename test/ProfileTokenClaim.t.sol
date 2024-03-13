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
    uint256 startingProfileId = 0;

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
        tokenClaim.newEpoch(1, 1, 0);

        // reverts when the caller does not approve the transfer
        vm.expectRevert(); // SafeTransfer
        tokenClaim.newEpoch(1, 1, 0);

        _newEpoch(startingProfileId);

        // it transfers tokens to the contract
        assertEq(token.balanceOf(address(tokenClaim)), totalAmount);

        // it updates storage
        assertEq(tokenClaim.epoch(), firstEpoch);
        (uint256 total,, uint256 perProfile,) = tokenClaim.claimAmounts(firstEpoch);
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
        (,uint256 available,,) = tokenClaim.claimAmounts(firstEpoch);
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

    function _newEpoch(uint256 _startingProfileId) internal {
        token.approve(address(tokenClaim), totalAmount);
        tokenClaim.newEpoch(_startingProfileId, totalAmount, claimAmount);
    }
}