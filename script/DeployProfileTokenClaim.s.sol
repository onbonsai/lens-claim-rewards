// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import "../src/ProfileTokenClaim.sol";

/**
 * @dev this script deploys our `ProfileTokenClaim` contract to polygon testnet/mainnet
 */
contract DeployProfileTokenClaim is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address hub;
        address moduleRegistry;
        address token = 0x3d2bD0e15829AA5C362a4144FdF4A1112fa29B5c;

        if (block.chainid == 137) {
            // polygon mainnet config
            hub = 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d;
            moduleRegistry = 0x1eD5983F0c883B96f7C35528a1e22EEA67DE3Ff9;
        } else if (block.chainid == 80001) {
            // polygon mumbai testnet config
            hub = 0x4fbffF20302F3326B20052ab9C217C44F6480900;
            moduleRegistry = 0x4BeB63842BB800A1Da77a62F2c74dE3CA39AF7C0;
        } else {
            revert("unsupported chain");
        }

        vm.startBroadcast(deployerPrivateKey);

        // deploy
        ProfileTokenClaim tokenClaim = new ProfileTokenClaim(hub, moduleRegistry, token);

        // // proof claims
        // bytes32 merkleRoot;
        // uint256 merkleClaimTotal;
        // uint256 merkleClaimAmountMax;

        // if (block.chainid == 137) {
        //     // TODO
        //     merkleRoot = bytes32(0);
        //     merkleClaimTotal = 0;
        //     merkleClaimAmountMax = 0;
        // } else if (block.chainid == 80001) {
        //     merkleRoot = 0x356b96bfc7a22623a7b44e8ea2a43a611a8dca215089fc8575fb061ce1984b8c;
        //     merkleClaimTotal = 45_000 ether;
        //     merkleClaimAmountMax = 10_000 ether;
        // }
        // IERC20(token).approve(address(tokenClaim), merkleClaimTotal);
        // tokenClaim.setClaimProof(merkleClaimTotal, merkleClaimAmountMax, merkleRoot);

        vm.stopBroadcast();
    }
}

/**
 * @dev this script sets a new rewards epoch for a deployed instance of `ProfileTokenClaim`
 */
contract NewEpoch is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address tokenClaim;
        address token = 0x3d2bD0e15829AA5C362a4144FdF4A1112fa29B5c;

        if (block.chainid == 137) {
            // polygon mainnet config
            // TODO
            revert("unsupported chain");
        } else if (block.chainid == 80001) {
            // polygon mumbai testnet config
            tokenClaim = 0xB41C763DF745946B3cFd3c8A93cbc9806714D5Ea;
        } else {
            revert("unsupported chain");
        }

        vm.startBroadcast(deployerPrivateKey);

        // rewards; 1000 $bonsai, 100 profiles
        uint256 totalAmount = 1000 ether;
        uint256 totalCount = 100;
        uint256 startingTokenId = 0; // TODO

        IERC20(token).approve(tokenClaim, totalAmount);
        ProfileTokenClaim(tokenClaim).newEpoch(startingTokenId, totalAmount, totalCount);

        vm.stopBroadcast();
    }
}

/**
 * @dev this script attempts to claim tokens for a given epoch
 */
contract ClaimTokens is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        address tokenClaim;

        if (block.chainid == 137) {
            // polygon mainnet config
            // TODO
            revert("unsupported chain");
        } else if (block.chainid == 80001) {
            // polygon mumbai testnet config
            tokenClaim = 0xB41C763DF745946B3cFd3c8A93cbc9806714D5Ea;
        } else {
            revert("unsupported chain");
        }

        vm.startBroadcast(privateKey);

        uint256 profileId = 140; // test/carlosbeltran

        ProfileTokenClaim(tokenClaim).claimTokens(profileId);

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

        if (block.chainid == 137) {
            // polygon mainnet config
            // TODO
            revert("unsupported chain");
        } else if (block.chainid == 80001) {
            // polygon mumbai testnet config
            tokenClaim = 0xB41C763DF745946B3cFd3c8A93cbc9806714D5Ea;
        } else {
            revert("unsupported chain");
        }

        // "0x8c": {
        //     "proof": [
        //         "0x8308e716b8f6e08300f76f019ded6f5ccdc8f75a5cf2d5d7c02afc4ddeeacb3b",
        //         "0xd9c511c04ab6ef49683b04df399278db420f76722c2b14bbee1811ce1bfc8d15",
        //         "0xb554f56f3dd0e3f431f90d2d3f1f56a10fcb91ebf0f037b524499c6244787835"
        //     ],
        //     "profileId": "0x8c",
        //     "claimScoreBbps": "10000",
        //     "claimableAmount": "10000000000000000000000"
        // },

        vm.startBroadcast(privateKey);

        uint256 profileId = 140; // test/carlosbeltran
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = 0x8308e716b8f6e08300f76f019ded6f5ccdc8f75a5cf2d5d7c02afc4ddeeacb3b;
        proof[1] = 0xd9c511c04ab6ef49683b04df399278db420f76722c2b14bbee1811ce1bfc8d15;
        proof[2] = 0xb554f56f3dd0e3f431f90d2d3f1f56a10fcb91ebf0f037b524499c6244787835;
        uint16 claimScoreBbps = 10000;

        ProfileTokenClaim(tokenClaim).claimTokensWithProof(proof, profileId, claimScoreBbps);

        vm.stopBroadcast();
    }
}
