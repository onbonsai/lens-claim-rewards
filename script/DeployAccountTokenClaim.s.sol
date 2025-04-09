// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {AccountTokenClaim} from "../src/AccountTokenClaim.sol";
import { console } from "forge-std/console.sol";

/**
 * @dev this script deploys our `AccountTokenClaim` contract to lens chain
 */
contract DeployAccountTokenClaim is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // LC airdrop 1
        bytes32 merkleRoot = 0x1046b23e3310d4225789ea3b9ef16c04c452f4cadfce7129bad003095f7ee2dd;
        uint256 merkleClaimTotal = 10_000_000 ether;
        uint256 merkleClaimAmountMax = 10_000 ether;

        address token;

        if (block.chainid == 37111) {
            token = 0x795cc31B44834Ff1F72F7db73985f9159Bd51ac2; // MCY
        } else {
            token = 0xB0588f9A9cADe7CD5f194a5fe77AcD6A58250f82; // BONSAI
        }

        vm.startBroadcast(deployerPrivateKey);

        // deploy
        AccountTokenClaim tokenClaim = new AccountTokenClaim(token);

        IERC20(token).approve(address(tokenClaim), merkleClaimTotal);
        tokenClaim.setClaimProof(merkleClaimTotal, merkleClaimAmountMax, merkleRoot);

        vm.stopBroadcast();
    }
}

/**
 * @dev this script attempts to claim tokens with a merkle proof
 */
contract ClaimTokensWithProof is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        address tokenClaim;

        if (block.chainid == 37111) {
            // lens testnet
            tokenClaim = 0x1C94ebD5D6B4242CC6b6163d12FbB215ABe0d902;
        } else {
            // TODO: mainnet
        }

        // "0x28ff8e457feF9870B9d1529FE68Fbb95C3181f64": {
        //     "proof": [
        //         "0xad0aa921e1347dffeac1013c03ecf5a3ebd17804b56b74658bc5c3c6e70969e4",
        //         "0x3d12c99c86f943344c5a39c4f1c94d64ccaf8d9c8d008a5a5ea79e10fd8a4207",
        //         "0x98f6de864ffc7dfabf7fb9437462db3fcd2019cb981b00ac8da4fe8bd3068d00",
        //         "0xd370cabd78b798b7fc89d528102e1c74a8becc74e206a301ee7fa816cc5227af",
        //         "0xb46b346ceefcf37c7498bfb7fa05c07f8bbd4b717498803f56c91675e02dc079",
        //         "0x46edc3aec56a039dc5bffd94a7a2c1ab366b613aaedf078c4591d47bfc03d641",
        //         "0x34d1c24007342133b26c8e8367ce8f64b5a38080ddfc633bff5661aea42a2de1",
        //         "0x84eebcec7396ba56f287523ec48d02a121e90deef7665169d60fa15cef1a8589",
        //         "0x86766e552d2c46b38aee9a51be4f09c27a5afeff92ff89941b34cf62ad125755",
        //         "0x076b2b7dffa42d80cbf1a34b1c7bde47fd8162dfe164b579a101051bcfb91629",
        //         "0x30bb9a03a102747c0485ec2525e8ef485a7e2caf71e64e229f6225e13cccf115"
        //     ],
        //     "address": "0x28ff8e457feF9870B9d1529FE68Fbb95C3181f64",
        //     "claimScoreBps": "6062",
        //     "handle": "carlosbeltran"
        // },

        // Valid proof from `merkle_claim_tree_output.json`
        address accountAddress = 0x7479B233fB386eD4Bcc889c9DF8b522C972b09F2;
        bytes32[] memory proof = new bytes32[](11);
        proof[0] = 0xad0aa921e1347dffeac1013c03ecf5a3ebd17804b56b74658bc5c3c6e70969e4;
        proof[1] = 0x3d12c99c86f943344c5a39c4f1c94d64ccaf8d9c8d008a5a5ea79e10fd8a4207;
        proof[2] = 0x98f6de864ffc7dfabf7fb9437462db3fcd2019cb981b00ac8da4fe8bd3068d00;
        proof[3] = 0xd370cabd78b798b7fc89d528102e1c74a8becc74e206a301ee7fa816cc5227af;
        proof[4] = 0xb46b346ceefcf37c7498bfb7fa05c07f8bbd4b717498803f56c91675e02dc079;
        proof[5] = 0x46edc3aec56a039dc5bffd94a7a2c1ab366b613aaedf078c4591d47bfc03d641;
        proof[6] = 0x34d1c24007342133b26c8e8367ce8f64b5a38080ddfc633bff5661aea42a2de1;
        proof[7] = 0x84eebcec7396ba56f287523ec48d02a121e90deef7665169d60fa15cef1a8589;
        proof[8] = 0x86766e552d2c46b38aee9a51be4f09c27a5afeff92ff89941b34cf62ad125755;
        proof[9] = 0x076b2b7dffa42d80cbf1a34b1c7bde47fd8162dfe164b579a101051bcfb91629;
        proof[10] = 0x30bb9a03a102747c0485ec2525e8ef485a7e2caf71e64e229f6225e13cccf115;
        uint16 claimScoreBbps = 6062;

        vm.startBroadcast(privateKey);

        AccountTokenClaim(tokenClaim).claimTokensWithProof(proof, accountAddress, claimScoreBbps);

        vm.stopBroadcast();
    }
}

/**
 * @dev this script withdraws unclaimed tokens
 */
contract WithdrawUnclaimedTokens is Script {
    function run() public {
        uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        AccountTokenClaim claim = AccountTokenClaim(address(0));

        vm.startBroadcast(privateKey);

        console.logUint(claim.merkleClaimEndAt());

        claim.withdrawUnclaimed();

        vm.stopBroadcast();
    }
}