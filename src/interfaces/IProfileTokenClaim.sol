// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

interface IProfileTokenClaim {
    struct ClaimAmountData {
        uint256 total; // immutable
        uint256 available; // decreasing on each claim
        uint256 perProfile; // claimable per profile
        uint256 startingProfileId; // users with profileId >= can claim
        uint256 endingProfileId; // users with profileId < can claim
    }

    event NewEpoch(uint16 epoch, ClaimAmountData data);

    error NoZeroAddress();
    error InvalidInput();
    error AlreadyClaimed();
    error EpochEnded();
    error ExecutorInvalid();
    error NotAllowed();

    function claimTokens(uint256 profileId) external;
    function claimableAmount(uint256 profileId) external view returns (uint256);
}
