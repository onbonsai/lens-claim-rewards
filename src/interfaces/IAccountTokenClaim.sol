// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

interface IAccountTokenClaim {
    event ClaimedWithProof(address sender, address account, uint256 amount);

    error NoZeroAddress();
    error AlreadyClaimed();
    error NotAllowed();
    error InvalidProof();

    function claimTokensWithProof(bytes32[] calldata proof, address accountAddress, uint16 claimScoreBbps) external;
}
