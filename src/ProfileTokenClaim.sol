// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.21;

import {ILensProtocol} from "lens/interfaces/ILensProtocol.sol";
import {IModuleRegistry} from "lens/interfaces/IModuleRegistry.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {MerkleProofLib} from "solmate/utils/MerkleProofLib.sol";
import "./interfaces/IProfileTokenClaim.sol";

/**
 * @title ProfileTokenClaim
 * @notice This contract enables claiming of tokens by Lens profile owners or via the Lens Profile Manager
 */
contract ProfileTokenClaim is Ownable, IProfileTokenClaim {
    using SafeERC20 for IERC20;

    uint256 public merkleClaimAmountTotal; // remaining amount for merkle claims
    uint256 public merkleClaimEndAt; // the time limit for merkle claims, after which contract owner can withdraw
    uint16 public epoch; // allow multiple claim seasons; 1-based
    IERC20 public immutable token; // Lens whitelisted currency
    ILensProtocol public immutable hub; // Lens profile owners

    mapping (uint16 epoch => mapping (uint256 profileId => bool claimed)) public claims;
    mapping (uint16 epoch => ClaimAmountData) public claimAmounts;
    mapping (uint256 profileId => bool claimed) public proofClaims;

    uint16 internal constant BPS_MAX = 10000;
    bytes32 internal _merkleRoot; // for one-time claiming rewards via proof
    uint256 internal _merkleClaimAmountMax; // the max amount a user could claim via proof

    /**
    * @dev contract constructor
    * @param _hub LensHub
    * @param _moduleRegistry: Lens ModuleRegistry
    * @param _token: Rewards token (ex: BONSAI)
    */
    constructor(address _hub, address _moduleRegistry, address _token) {
        if (_hub == address(0) || _moduleRegistry == address(0) || _token == address(0)) revert NoZeroAddress();

        // token must be whitelisted
        IModuleRegistry(_moduleRegistry).verifyErc20Currency(_token);

        token = IERC20(_token);
        hub = ILensProtocol(_hub);
    }

    /**
    * @notice Allows the contract owner to set the claim via proof data, for one-off claim
    * @param _merkleClaimAmountTotal: Merkle claim amount total (to transfer in)
    * @param __merkleRoot: Merkle proof root for a one-off claim
    * @param __merkleClaimAmountMax: Max amount a profile can claim via proof; proof data contains % in bps
    */
    function setClaimProof(
        uint256 _merkleClaimAmountTotal,
        uint256 __merkleClaimAmountMax,
        bytes32 __merkleRoot
    ) external onlyOwner {
        if (_merkleRoot != bytes32(0)) revert NotAllowed(); // cannot override previous

        merkleClaimAmountTotal = _merkleClaimAmountTotal;
        merkleClaimEndAt = block.timestamp + 364 days;
        _merkleRoot = __merkleRoot;
        _merkleClaimAmountMax = __merkleClaimAmountMax;

        token.safeTransferFrom(msg.sender, address(this), _merkleClaimAmountTotal);
    }

    /**
     * @notice Allows the contract owner to withdraw any unclaimed tokens from merkle claims, past `merkleClaimEndAt`
     */
    function withdrawUnclaimedMerkleAmount() external onlyOwner {
        if (block.timestamp < merkleClaimEndAt) revert NotAllowed();

        uint256 amount = merkleClaimAmountTotal;
        merkleClaimAmountTotal = 0;

        token.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Allows the contract owner to start a new claim epoch by supplying tokens
     * NOTE: requires caller to approve the transfer of `totalAmount`
     * @param startingProfileId The floor of profileId number able to claim
     * @param totalAmount The total amount of tokens for this rewards epoch
     * @param profileCount The number of profiles that can claim
     */
    function newEpoch(uint256 startingProfileId, uint256 totalAmount, uint256 profileCount) external onlyOwner {
        if (totalAmount == 0 || profileCount == 0) revert InvalidInput();

        token.safeTransferFrom(msg.sender, address(this), totalAmount);

        totalAmount += claimAmounts[epoch].available; // unclaimed rewards roll over

        epoch++;
        ClaimAmountData memory data = ClaimAmountData({
            total: totalAmount,
            available: totalAmount,
            perProfile: totalAmount / profileCount,
            startingProfileId: startingProfileId,
            endingProfileId: startingProfileId + profileCount
        });
        claimAmounts[epoch] = data;

        emit NewEpoch(epoch, data);
    }

    /**
     * @notice Returns the claimable reward amount for the given `profileId` in current epoch
     * @param profileId The profile id to check rewards for
     * @return uint256 The claimable reward amount
     */
    function claimableAmount(uint256 profileId) external view returns (uint256) {
        if (
            claims[epoch][profileId] ||
                profileId < claimAmounts[epoch].startingProfileId ||
                profileId > claimAmounts[epoch].endingProfileId
        ) return 0;

        return claimAmounts[epoch].perProfile;
    }

    /**
     * @notice Allows a profile to claim tokens - once - for the current epoch, while there are tokens available
     * @param profileId The profile id to claim tokens for
     */
    function claimTokens(uint256 profileId) external {
        ClaimAmountData storage data = claimAmounts[epoch];
        address profileOwner = IERC721(address(hub)).ownerOf(profileId);

        // revert if not existing or profile id out of range
        if (data.total == 0 || profileId < data.startingProfileId || profileId > data.endingProfileId)
            revert NotAllowed();

        // revert if not profile owner or delegated executor
        if (msg.sender != profileOwner && !hub.isDelegatedExecutorApproved(profileId, msg.sender))
            revert ExecutorInvalid();

        if (claims[epoch][profileId]) revert AlreadyClaimed();
        if (data.available == 0) revert EpochEnded();

        data.available -= data.perProfile;
        claims[epoch][profileId] = true;

        token.safeTransfer(profileOwner, data.perProfile);

        emit Claimed(epoch, profileId, data.perProfile);
    }

    /**
     * @notice Allows a profile to claim tokens via a proof, only once, up to `_merkleClaimAmountMax`
     * @param proof Merkle proof of the claim
     * @param profileId The profile id to claim tokens for
     * @param claimScoreBbps Percent of the `_merkleClaimAmountMax` this profile can claim (in bps)
     */
    function claimTokensWithProof(bytes32[] calldata proof, uint256 profileId, uint16 claimScoreBbps) external {
        address profileOwner = IERC721(address(hub)).ownerOf(profileId);

        // revert if not profile owner or delegated executor
        if (msg.sender != profileOwner && !hub.isDelegatedExecutorApproved(profileId, msg.sender))
            revert ExecutorInvalid();

        if (proofClaims[profileId]) revert AlreadyClaimed();
        if (!MerkleProofLib.verify(
            proof,
            _merkleRoot,
            keccak256(abi.encodePacked(profileId, claimScoreBbps))
        )) revert InvalidProof();

        uint256 amount = (claimScoreBbps * _merkleClaimAmountMax) / BPS_MAX;

        proofClaims[profileId] = true;
        merkleClaimAmountTotal -= amount;
        token.safeTransfer(profileOwner, amount);

        emit ClaimedWithProof(profileId, amount);
    }
}