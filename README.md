# lens-claim-rewards

Simple contract to enable token claims. Lens Profiles can claim directly or via the [profile manager](https://docs.lens.xyz/docs/profile-manager). One claim per epoch.

## Usage

1. [install Foundry](https://book.getfoundry.sh/getting-started/installation.html)
2. `forge install` to download dependencies
3. `forge build` to compile contracts
4. `forge test` to run tests


## Deployments

ABI can be found at [abi/ProfileClaimToken.json](abi/ProfileClaimToken.json)

| Contract Name | Mumbai | Polygon |
| ------------- | ------------- | ------------- |
| `ProfileTokenClaim`  | `0x1378F4E4024af3EE3dAEb11b62fC426B718014B9` | `0x` |

Set your `.env` by copying `.env.template`

### Deploy the contract

```bash
source .env && forge script script/DeployProfileTokenClaim.s.sol:DeployProfileTokenClaim --rpc-url $MUMBAI_RPC_URL -vvvv --skip .t.sol --legacy --broadcast
```

### Start a new rewards epoch

The contract owner can call this function to set a new rewards epoch and transfer in the rewards token
```solidity
function newEpoch(uint256 startingProfileId, uint256 totalAmount, uint256 profileCount) external;
```

Run the script:
```bash
source .env && forge script script/DeployProfileTokenClaim.s.sol:NewEpoch --rpc-url $MUMBAI_RPC_URL -vvvv --skip .t.sol --legacy --broadcast
```

### Check claimable amount
```solidity
function claimableAmount(uint256 profileId) external view returns (uint256);
```

### Claim tokens

Anyone with a profileId >= the `startingProfileId` for the given `epoch` can claim their rewards - directly or through their Lens Profile Manager.
```solidity
function claimTokens(uint256 profileId) external;
```

Run the script:
```bash
source .env && forge script script/DeployProfileTokenClaim.s.sol:ClaimTokens --rpc-url $MUMBAI_RPC_URL -vvvv --skip .t.sol --legacy --broadcast
```
