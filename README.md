# lens-claim-rewards

Enable token reward claims on Lens Chain, using merkle proofs.

## Overview
We first identify and rank top collectors using Lens v2 data to generate collector graphs. Then we compute EigenTrust scores via [OpenRank](https://openrank.com/) before normalizing them.

In another [repo](https://github.com/onbonsai/lc-airdrop) we compute EigenTrust scores using OpenRank.

This repo formats the list of scores into a merkle tree, to be put onchain through our `AccountTokenClaim` contract on [Lens Chain](https://lens.xyz/).

A user can submit their proof on the contract and claim tokens to their Lens account.

## Usage

1. [install Foundry](https://book.getfoundry.sh/getting-started/installation.html)
1. [install Foundry zkSync](https://docs.zksync.io/zksync-era/tooling/foundry/overview)
2. `forge install` to download dependencies
3. `FOUNDRY_PROFILE=zksync forge build --zksync` to compile contracts
4. `forge test` to run tests

## Deployments

ABI can be found at [abi/AccountTokenClaim.json](abi/AccountTokenClaim.json)

| Contract Name | Lens Chain Sepolia Testnet | Lens Chain Mainnet |
| ------------- | ------------- | ------------- |
| `AccountTokenClaim`  | `0x1C94ebD5D6B4242CC6b6163d12FbB215ABe0d902` | `` |

## Setup

### Create merkle data

We enable a one-off token claims via merkle proofs. Data is pre-generated offchain; you can then set a CSV in the root directory (see `merkle_claim_tree_input.csv`) to generate a merkle tree via
```bash
npx ts-node ./ts-scripts/merkleClaimTree.ts --csvInputFile="merkle_claim_tree_input.csv" --jsonOutputFile="merkle_claim_tree_output.json"
```

The root can then be uploaded to the contract - only once - via `#setClaimProof` which also transfers in the token amount.

This is done in the deploy script `DeployAccountTokenClaim.s.sol`

### Deploy the contract
Set your `.env` by copying `.env.template`

Compile the contracts
```bash
FOUNDRY_PROFILE=zksync forge build --zksync
```

Deploy via script (make sure you configure the reward amount)
```bash
forge script script/DeployAccountTokenClaim.s.sol:DeployAccountTokenClaim --rpc-url lens-testnet --skip .t.sol --zksync -vvvvv --slow --broadcast
```

And verify the contract (on LC mainnet)
```bash
forge verify-contract \
    --zksync \
    --watch \
    --verifier zksync  \
    --verifier-url https://api-explorer-verify.lens.matterhosted.dev/contract_verification \
    --constructor-args $(cast abi-encode "constructor(address)" 0x795cc31B44834Ff1F72F7db73985f9159Bd51ac2) \
    0xf73Bdd70dBEbaf053Ed01bA45847aE43dE9cFE4F \
    src/AccountTokenClaim.sol:AccountTokenClaim
```

### Claim tokens

Proof data should be stored in a db, indexed by `accountAddress` and sent along with the transaction to claim via:
```solidity
function claimTokensWithProof(bytes32[] calldata proof, address accountAddress, uint16 claimScoreBbps) external;
```

You can check the claimable amount of a given `accountAddress`
```solidity
function claimableAmount(
    bytes32[] calldata proof,
    address accountAddress,
    uint16 claimScoreBbps
) external view returns (uint256);
```

You can check if an account has claimed their one-off via the getter:
```solidity
function claims(address accountAddress) external view returns (bool claimed);
```

Attempt to claim with a valid proof
```bash
forge script script/DeployAccountTokenClaim.s.sol:ClaimTokensWithProof --rpc-url lens-testnet --skip .t.sol --zksync -vvvvv --slow --broadcast
```