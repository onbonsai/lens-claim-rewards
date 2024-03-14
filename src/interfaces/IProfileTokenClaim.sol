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
    event Claimed(uint16 epoch, uint256 profileId, uint256 amount);
    event ClaimedWithProof(uint256 profileId, uint256 amount);

    error NoZeroAddress();
    error InvalidInput();
    error AlreadyClaimed();
    error EpochEnded();
    error ExecutorInvalid();
    error NotAllowed();
    error InvalidProof();

    function claimTokens(uint256 profileId) external;
    function claimTokensWithProof(bytes32[] calldata proof, uint256 profileId, uint16 claimScoreBbps) external;
    function claimableAmount(uint256 profileId) external view returns (uint256);
}
