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
| `ProfileTokenClaim`  | `0xB41C763DF745946B3cFd3c8A93cbc9806714D5Ea` | `0xC14b0FBB2059698Cf28Fff318D0C40e24eC07fC8` |

Set your `.env` by copying `.env.template`

### Deploy the contract
NOTE: This also sets the merkle root for the one-off claiming - see the script for the config

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

### Claim tokens with proof

We enable a one-off claiming via merkle proofs. Data is to be pre-generated offchain and you can then set a CSV in the root directory (see `merkle_claim_tree_input.csv`) to generate a merkle tree via
```bash
npx ts-node ./ts-scripts/merkleClaimTree.ts --csvInputFile="merkle_claim_tree_input.csv" --jsonOutputFile="merkle_claim_tree_output.json"
```

The root can then be uploaded to the contract - only once - via `#setClaimProof` and transfering in the token amount. Proof data should be stored in a db, indexed by `profileId` and sent along with the transaction to claim via:
```solidity
function claimTokensWithProof(bytes32[] calldata proof, uint256 profileId, uint16 claimScoreBbps) external;
```

You can check if a profile has claimed their one-off via the getter:
```solidity
function proofClaims(uint256 profileId) external view returns (bool claimed);
```

Run the script:
```bash
source .env && forge script script/DeployProfileTokenClaim.s.sol:ClaimTokensWithProof --rpc-url $MUMBAI_RPC_URL -vvvv --skip .t.sol --legacy --broadcast
```