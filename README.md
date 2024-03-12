# lens-claim-rewards

Simple contract to enable token claims. Lens Profiles can claim directly or via the [profile manager](https://docs.lens.xyz/docs/profile-manager) can claim once per epoch.

## Usage

1. [install Foundry](https://book.getfoundry.sh/getting-started/installation.html)
2. `forge install` to download dependencies
3. `forge build` to compile contracts
4. `forge test` to run tests


## Deployments

| Contract Name | Mumbai | Polygon |
| ------------- | ------------- | ------------- |
| `ProfileTokenClaim`  | `0xaA8f262C37c07E99a7BFE2645D066f4eE490805C` | `0x` |

Set your `.env` by copying `.env.template`

### Deploy the contract

```bash
source .env && forge script script/DeployProfileTokenClaim.s.sol:DeployProfileTokenClaim --rpc-url $MUMBAI_RPC_URL -vvvv --skip .t.sol --legacy --broadcast
```

### Start a new rewards epoch

The contract owner can call this function to set a new rewards epoch and transfer in the rewards token
```solidity
function newEpoch(uint256 startingProfileId, uint256 totalAmount, uint256 claimAmount) external;
```

Run the script:
```bash
source .env && forge script script/DeployProfileTokenClaim.s.sol:NewEpoch --rpc-url $MUMBAI_RPC_URL -vvvv --skip .t.sol --legacy --broadcast
```

### Claim tokens

Anyone with a profileId >= the `startingProfileId` for the given `epoch` can claim their rewards - directly or through their Lens Profile Manager.
```solidity
function claimTokens(uint16 _epoch, uint256 profileId) external;
```

Run the script:
```bash
source .env && forge script script/DeployProfileTokenClaim.s.sol:ClaimTokens --rpc-url $MUMBAI_RPC_URL -vvvv --skip .t.sol --legacy --broadcast
```
