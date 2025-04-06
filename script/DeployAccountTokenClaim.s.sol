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

        bytes32 merkleRoot;
        uint256 merkleClaimTotal;
        uint256 merkleClaimAmountMax;
        address token;

        if (block.chainid == 37111) {
            // 2 claims
            token = 0x795cc31B44834Ff1F72F7db73985f9159Bd51ac2; // bonsai
            merkleRoot = 0x198fe8fe4a853464521cfb5fd0439659cb6b512c2835ee07134ee9a616c548b8;
            merkleClaimTotal = 2_000 ether;
            merkleClaimAmountMax = 1_000 ether;
        } else {
            // TODO: mainnet
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
            tokenClaim = 0x3B539f9961A03548164d612dc5f44C70973433F7;
        } else {
            // TODO: mainnet
        }

        // "0x7479B233fB386eD4Bcc889c9DF8b522C972b09F2": {
        //     "proof": [
        //         "0xdbb1e739cb22468f8b1c5862320de417c9575443bffc85cf712cd3171b61a3d2"
        //     ],
        //     "eoa": "0x28ff8e457feF9870B9d1529FE68Fbb95C3181f64",
        //     "accountAddress": "0x7479B233fB386eD4Bcc889c9DF8b522C972b09F2",
        //     "claimScoreBbps": "9999",
        //     "claimableAmount": "9999000000000000000000"
        // },

        vm.startBroadcast(privateKey);

        address accountAddress = 0x7479B233fB386eD4Bcc889c9DF8b522C972b09F2; // lens/carlosbeltran
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = 0xdbb1e739cb22468f8b1c5862320de417c9575443bffc85cf712cd3171b61a3d2;
        uint16 claimScoreBbps = 9999;

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