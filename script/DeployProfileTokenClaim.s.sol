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

        // proof claims
        bytes32 merkleRoot;
        uint256 merkleClaimTotal;
        uint256 merkleClaimAmountMax;

        if (block.chainid == 137) {
            // TODO
            merkleRoot = bytes32(0);
            merkleClaimTotal = 0;
            merkleClaimAmountMax = 0;
        } else if (block.chainid == 80001) {
            merkleRoot = 0x196684a1becab6512d4f338ccd86278623f5bb09d9a12d670dfc1e55b0bbfcd7;
            merkleClaimTotal = 400 ether;
            merkleClaimAmountMax = 100 ether;
        }
        IERC20(token).approve(address(tokenClaim), merkleClaimTotal);
        tokenClaim.setClaimProof(merkleClaimTotal, merkleClaimAmountMax, merkleRoot);

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
            tokenClaim = 0x9213BE0AC5fbbCBF690b52D8c1b0Af2c4B776eb8;
        } else {
            revert("unsupported chain");
        }

        vm.startBroadcast(deployerPrivateKey);

        // rewards; 1000 $bonsai, 10 $bonsai per claim
        uint256 totalAmount = 1000 ether;
        uint256 claimAmount = 10 ether;
        uint256 startingTokenId = 0; // TODO

        IERC20(token).approve(tokenClaim, totalAmount);
        ProfileTokenClaim(tokenClaim).newEpoch(startingTokenId, totalAmount, claimAmount);

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
            tokenClaim = 0x9213BE0AC5fbbCBF690b52D8c1b0Af2c4B776eb8;
        } else {
            revert("unsupported chain");
        }

        vm.startBroadcast(privateKey);

        uint256 profileId = 140; // test/carlosbeltran

        ProfileTokenClaim(tokenClaim).claimTokens(profileId);

        vm.stopBroadcast();
    }
}
