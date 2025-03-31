# lens-claim-rewards

Simple contract to enable token claims on Lens Chain, using merkle proofs.

## Usage

1. [install Foundry](https://book.getfoundry.sh/getting-started/installation.html)
1. [install Foundry zkSync](https://docs.zksync.io/zksync-era/tooling/foundry/overview)
2. `forge install` to download dependencies
3. `FOUNDRY_PROFILE=zksync forge build --zksync` to compile contracts
4. `forge test` to run tests

## Deployments

ABI can be found at [abi/ProfileClaimToken.json](abi/ProfileClaimToken.json)

| Contract Name | Lens Chain Sepolia Testnet | Lens Chain Mainnet |
| ------------- | ------------- | ------------- |
| `AccountTokenClaim`  | `0x310F87946E3664ee574DD73066251851B400Db29` | `` |

## Setup

### Deploy the contract
Set your `.env` by copying `.env.template`

Compile the contracts
```bash
FOUNDRY_PROFILE=zksync forge build --zksync
```

Use `create` with zksync
```bash
forge create src/AccountTokenClaim.sol --constructor-args "0x3d2bD0e15829AA5C362a4144FdF4A1112fa29B5c" --account myKeystore --rpc-url https://rpc.testnet.lens.dev --chain 37111 --zksync
```

### Create merkle data

We enable a one-off token claims via merkle proofs. Data is pre-generated offchain; you can then set a CSV in the root directory (see `merkle_claim_tree_input.csv`) to generate a merkle tree via
```bash
npx ts-node ./ts-scripts/merkleClaimTree.ts --csvInputFile="merkle_claim_tree_input.csv" --jsonOutputFile="merkle_claim_tree_output.json"
```

The root can then be uploaded to the contract - only once - via `#setClaimProof` which also transfers in the token amount.

### Set Merkle Claim Proof

The contract owner can call this function to set the one-off merkle claim
```solidity
function setClaimProof(uint256 _merkleClaimAmountTotal, uint256 __merkleClaimAmountMax, bytes32 __merkleRoot) external;
```

First, approve the tokens for the contract
```bash
cast send 0x3d2bD0e15829AA5C362a4144FdF4A1112fa29B5c "approve(address,uint256)" "0x310F87946E3664ee574DD73066251851B400Db29" 100000000000000000000000 --account myKeystore --rpc-url https://rpc.testnet.lens.dev --chain 37111
```

Then set the merkle root
```bash
cast send 0x310F87946E3664ee574DD73066251851B400Db29 "setClaimProof(uint256,uint256,bytes32)" 2000000000000000000000 1000000000000000000000 "0x198fe8fe4a853464521cfb5fd0439659cb6b512c2835ee07134ee9a616c548b8" --account myKeystore --rpc-url https://rpc.testnet.lens.dev --chain 37111
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