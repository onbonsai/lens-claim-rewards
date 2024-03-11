# lens-open-actions

MadFi open actions for Lens v2

## Usage

1. [install Foundry](https://book.getfoundry.sh/getting-started/installation.html)
2. `forge install` to download dependencies
3. `forge build` to compile contracts
4. `forge test` to run tests

## RewardEngagementAction

Allows a creator with a MadSBT collection to give out XP for users to comment/mirror/quote their post that is initialized with this action.

To initialize a publication with this action module, the publication creator must supply in the encoded module init data

- `collectionId`: their MadSBT collectionId (must be active)
- `rewardEnum`: a valid enum for `MadSBT#actionToRewardUnits()`
- `limit`: the maximum number of times to reward the action; actions would still be processed, just without rewarding
- `actionType`: a valid enum of `ActionType` to reward; ex: if this module is initialized with `ActionType.Comment`, the action module data expects `CommentParams` and the associated signature

This is how the module init data is decoded

```solidity
(
    uint256 collectionId,
    uint8 rewardEnum,
    uint16 limit,
    ActionType actionType
) = abi.decode(data, (uint256, uint8, uint16, ActionType));
```

Then, when a user calls `act()` via Lens Protocol, we expect in the action module data the correct signed data for the initialized `ActionType`. For example, if the action module was initialized with `ActionType.Comment`, we expect the correct signed data for `LensHub#commentWithSig()`.

This is how the action module data is decoded

```solidity
(Types.CommentParams memory params, Types.EIP712Signature memory signature) = abi.decode(
    processActionParams.actionModuleData,
    (Types.CommentParams, Types.EIP712Signature)
);
```

## PublicationBountyAction

Allows a sponsor to create a Bounty tied to a Lens publication. The publication content is the bounty description, and the module init data does the deposit. We call `Bounty#depositFromAction()` to set up storage over there. Bid creators must have approved the Bounty contract to be a delegated executor in order to call `LensHub#post()` without needing a signature.

To initialize a publication with this action module, the publication creator must supply in the encoded module init data

- `paymentToken`: the ERC20 token to use for payment
- `bountyAmount`: the total amount available for the bounty

This is how the module init data is decoded

```solidity
(address paymentToken, uint256 bountyAmount) = abi.decode(data, (address, uint256));
```

Then, when a user calls `act()` via Lens Protocol, we expect in the action module data the necessary data to be able to create a lens post, their bid amount, optionally rev share, and optionally reward action module data (to link `RewardEngagementAction`).

This is how the action module data is decoded

```solidity
(
    uint256 bountyId,
    uint256 bidAmount,
    uint256 revShare,
    string memory contentURI,
    bytes memory rewardActionModuleInitData
) = abi.decode(processActionParams.actionModuleData, (uint256, uint256, uint256, string, bytes));
```

When there are a few bids ready, the sponsor can come back and call `#approveBids()` which initiates the process on the Bounty contract to disburse the funds, handle rev share, and of course post the publications on behalf of the bid creators.

## RentableSpaceAction
Enables profiles to rent their publication space for advertising. Payment is done via ERC20 tokens such as GHO or WMATIC, and space is rented on a per second basis. A creator initiates a post with this action module and sets the token cost per second, the allowed category for ads (optional), and whether open actions can also be promoted. A profile that wants to act on this module must specify how long they wish to rent space for and approve the required payment, and if a category was defined on init - prove their content fits the allowed category by submitting a merkle proof. Funds are transferred and the content/open action from the pubId passed in are hotswapped with this post's contentURI / open action, retrieable via the view function `#getActiveAd`.

A creator may cancel an active ad on their space after the protocol-defined window of 12 hours; this refunds the advertiser for the amount of time their ad wasn't live.

We also have a flagging and blacklisting feature that allows a creator to cancel an active ad for the reasons defined in enum `CancelAdReason`:
```solidity
enum CancelAdReason {
    BAD_CONTENT,
    BAD_ADVERTISER,
    BAD_ACTOR, // any bad activity
    EXIT, // to allow good faith canceling after `adMinDuration`
    OTHER
}
```
This flags the appropriate profile for clients to be aware of during the init / act process. A flagged profile may be blacklisted by the contract owner, which prohibits them from ever calling init / act again.

To initialize a publication with this action module, the publication creator must supply in the encoded module init data
- `currency`: the ERC20 token to use for payment
- `allowOpenAction`: whether to allow open actions to also be promoted
- `expireAt`: the expiry timestamp for when this post is accepting ads
- `clientFeePerActBps`: the client fee % on any act, to incentivize clients to promote
- `referralFeePerActBps`: the referral fee % on any act, to incentivize mirrors
- `interestMerkleRoot`: [optional] a merkle tree root for the allowed interest; if set, actors must provide the proof that their profile / content is part of this tree

Then, when a profile calls `act()` via Lens Protocol, we expect a struct of type `RentParams` in the encoded action module data
```solidity
struct RentParams {
    uint256 adPubId; // [optional] the pub id to pull contentUri and action module for the ad
    uint256 duration; // the amount of time the advertiser wishes to pay for
    uint256 costPerSecond; // the amount the advertisers is willing to pay per second
    uint256 merkleProofIndex; // proof index the space's category merkle
    address clientAddress; // [optional] the whitelisted client address to receive fees
    address openActionModule; // [optional] the linked open action module
    string adContentUri; // [optional] if no pub id passed in, use this lens metadata uri
    bytes32[] merkleProof; // proof for the space's category merkle
}
```

By providing an existing `pubId`, the advertiser is wishing to include that post (and optionally the attached `openActionModule`) in the "billboard". Otherwise, they can just provide a `adContentUri` which will be formed as lens post metadata.

To allow for bidding on a "billboard" we allow advertisers to pay the `costPerSecond` times `minBidIncreaseBps` which is set to 20%. So advertisers wishing to replace an active ad must bid 20% more than the current active bid; replacing an ad refunds the previous advertiser from the contract.

Clients and referrers are paid automatically, and creators must call `withdrawFeesEarned` to claim their fees
```solidity
/**
 * @notice Allows a profile owned to withdraw any fees earned, minus the owed amount for a given active ad, if any
 * NOTE: we accrue fees in the contract in order to handle refunds in case of ads being outbidded or canceled
 */
function withdrawFeesEarned(address currency, uint256 profileId) external onlyProfileOwner(profileId);
```
## Rewards Swap

Rewards Swap (or Shill2Earn colloquially) lets you create incentivized swaps for your token. To start you need a UniswapV3 poool for the token that you want to promote. Then you can create a RewardsSwap pool by transferring in tokens and setting some parameters

Now a user can initialize the action on their post by passing in the index of the rewards pool to point to. They can also opt to share some of the rewards with the swapper. When the action is processed the user will pass in the token to swap in and the swap is called on the Uniswap Router. Rewards are doled out to the publication owner, the acter (if the owner has opted to share rewards), and the first profile in the mirror referrals array, if there is one.

You can also select a token when initializing your post that doest not have a pool. In this case the post creator will get .15% of incoming swaps as a reward.

Users can still act on the publication even after the rewards pool is used up and they will be able to swap but no rewards will be given out.

The post creator can opt to share some of their reward with the client also. This is done by setting the `sharedRewardPercent` in the `initializePublicationAction` call. When acting on the publication the client can inject their recipient address into the action module data and the specified percent of the reward will be sent to them.

### Usage

#### createRewardsPool

Creates a rewards pool for a given token. ERC20 approval required in order to transfer the specified tokens into the contract when creating the pool.

- `token`: Address of your token
- `rewardsAmount`: The total amount of tokens to be given out as rewards (these will be transferred into the contract so the contract will need to be approved first)
- `percentReward`: The percent reward - this is the percent of the total amount out of a user's swap that will be given to them out of the pool as a reward
- `percentCap`: The maximum amount of tokens to give out in a single process action call. Passed in as a percent of the total rewards amount and then stored in the contract as as constant
- `profileId`: The profileId of the owner of a MadSBT collection that will be used to reward users with points for every swap. You can pass in zero to skip this.

#### initializePublicationAction

Initializes a publication with the RewardsSwap action module. The publication creator must supply in the encoded module init data:

- `isDirectPromotion`: True if you are promoting a token directly without a reward pool.
- `sharedRewardPercent`: The percent of each reward for the publication owner that they will pass on to the acter. Max 10000 (100% in basis points).
- `recipient`: The address of the recipient of the rewards, typically the publication owner.
- `rewardsPoolId`: The index of the rewards pool to point to.
- `sharedClientPercent`: (Optional) percent of each reward for the publication owner that they will pass on to the client. Max 10000 (100% in basis points).
- `token`: The token to promote if `isDirectPromotion` is true. Can be zero address if not.

#### processPublicationAction

Process the action by swapping into the token and rewarding all eligible parties. When selecting a `tokenIn` the user can select any token path that is valid on Uniswap. The encoded module action data should include:

- `path`: The path of tokens to swap through on Uniswap. [Docs on how to construct path](https://docs.uniswap.org/contracts/v3/guides/swaps/multihop-swaps#exact-input-multi-hop-swaps)
- `amountIn`: The amount of tokens to swap in
- `clientAddress`: (Optional) The address of the client to share rewards with. If set to address 0 or if `sharedClientPercent` is 0 on the post then no rewards will be shared with the client.

All rewards are transferred to their recipients in the process action.
