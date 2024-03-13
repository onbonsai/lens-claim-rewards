// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.21;

import {ILensProtocol} from "lens/interfaces/ILensProtocol.sol";
import {IModuleRegistry} from "lens/interfaces/IModuleRegistry.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import "./interfaces/IProfileTokenClaim.sol";

/**
 * @title ProfileTokenClaim
 * @notice This contract enables claiming of tokens by Lens profile owners or via the Lens Profile Manager
 */
contract ProfileTokenClaim is Ownable, IProfileTokenClaim {
    using SafeERC20 for IERC20;

    uint16 public epoch; // allow multiple claim seasons; 1-based
    IERC20 public immutable token; // Lens whitelisted currency
    ILensProtocol public immutable hub; // Lens profile owners

    mapping (uint16 epoch => mapping (uint256 profileId => bool claimed)) public claims;
    mapping (uint16 epoch => ClaimAmountData) public claimAmounts;

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
    }
}