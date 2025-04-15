// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.26;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {MerkleProofLib} from "solmate/utils/MerkleProofLib.sol";
import "./interfaces/IAccountTokenClaim.sol";

interface IOwnable {
    function owner() external view returns (address);
}

/**
 * @title AccountTokenClaim
 * @notice This contract enables claiming of tokens by Lens profile owners or via the Lens Profile Manager
 */
contract AccountTokenClaim is Ownable, IAccountTokenClaim {
    using SafeERC20 for IERC20;

    uint256 public merkleClaimAmountTotal; // remaining amount for merkle claims
    uint256 public merkleClaimEndAt; // the time limit for merkle claims, after which contract owner can withdraw
    IERC20 public immutable token; // Rewards

    mapping (address accountAddress => bool claimed) public claims;

    uint16 internal constant BPS_MAX = 10000;
    uint256 internal constant CLAIM_WINDOW = 90 days;

    bytes32 internal _merkleRoot; // for one-time claiming rewards via proof
    uint256 internal _merkleClaimAmountMax; // the max amount a user could claim via proof

    /**
    * @dev contract constructor
    * @param _token: Rewards token (ex: BONSAI)
    */
    constructor(address _token) {
        if (_token == address(0)) revert NoZeroAddress();

        token = IERC20(_token);
    }

    /**
    * @notice Allows the contract owner to set the claim via proof data, for one-off claim
    * @param _merkleClaimAmountTotal: Merkle claim amount total (to transfer in)
    * @param __merkleRoot: Merkle proof root for a one-off claim
    * @param __merkleClaimAmountMax: Max amount an account can claim via proof; proof data contains % in bps
    */
    function setClaimProof(
        uint256 _merkleClaimAmountTotal,
        uint256 __merkleClaimAmountMax,
        bytes32 __merkleRoot
    ) external onlyOwner {
        if (_merkleRoot != bytes32(0)) revert NotAllowed(); // cannot override previous

        merkleClaimAmountTotal = _merkleClaimAmountTotal;
        merkleClaimEndAt = block.timestamp + CLAIM_WINDOW;
        _merkleRoot = __merkleRoot;
        _merkleClaimAmountMax = __merkleClaimAmountMax;

        token.safeTransferFrom(msg.sender, address(this), _merkleClaimAmountTotal);
    }

    /**
     * @notice Allows the contract owner to withdraw any unclaimed tokens from merkle claims, past `merkleClaimEndAt`
     */
    function withdrawUnclaimed() external onlyOwner {
        if (block.timestamp < merkleClaimEndAt) revert NotAllowed();

        uint256 amount = merkleClaimAmountTotal;
        merkleClaimAmountTotal = 0;

        token.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Allows an account to claim tokens via a proof, only once, up to `_merkleClaimAmountMax`
     * @param proof Merkle proof of the claim
     * @param accountAddress The Lens Account address to transfer tokens to
     * @param claimScoreBbps Percent of the `_merkleClaimAmountMax` this profile can claim (in bps)
     * NOTE: the caller must be the owner of the Lens Account
     */
    function claimTokensWithProof(bytes32[] calldata proof, address accountAddress, uint16 claimScoreBbps) external {
        // revert if not account owner
        if (msg.sender != IOwnable(accountAddress).owner()) revert NotAllowed();

        if (claims[msg.sender]) revert AlreadyClaimed();
        if (!MerkleProofLib.verify(
            proof,
            _merkleRoot,
            keccak256(abi.encodePacked(msg.sender, claimScoreBbps))
        )) revert InvalidProof();

        uint256 amount = (claimScoreBbps * _merkleClaimAmountMax) / BPS_MAX;

        claims[msg.sender] = true;
        merkleClaimAmountTotal -= amount;
        token.safeTransfer(accountAddress, amount);

        emit ClaimedWithProof(msg.sender, accountAddress, amount);
    }

    /**
     * @notice Returns the amount claimable by the account with the given proof
     * @param proof Merkle proof of the claim
     * @param claimScoreBbps Percent of the `_merkleClaimAmountMax` this profile can claim (in bps)
     */
    function claimableAmount(
        bytes32[] calldata proof,
        uint16 claimScoreBbps
    ) external view returns (uint256) {
        bool isValid = !claims[msg.sender] && MerkleProofLib.verify(
            proof,
            _merkleRoot,
            keccak256(abi.encodePacked(msg.sender, claimScoreBbps))
        );

        return isValid
            ? (claimScoreBbps * _merkleClaimAmountMax) / BPS_MAX
            : 0;
    }
}