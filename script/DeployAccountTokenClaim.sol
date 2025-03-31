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
            token = 0x3d2bD0e15829AA5C362a4144FdF4A1112fa29B5c; // bonsai
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

        if (block.chainid == 137) {
            // polygon mainnet config
            tokenClaim = 0xC14b0FBB2059698Cf28Fff318D0C40e24eC07fC8;
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

        // "0x01a6": {
        //     "proof": [
        //         "0x26cdab4d1aee2174ce34ab60293e8450bbf2c6ce071797ee4bbfcfe1db35f3e0",
        //         "0xdafd5adbf7540d4c455fb0935d45b85d2d8c6147746626453fd7f2c6b2f19411",
        //         "0x19721b08436bb3e67b73c926914ce88bdc8b78efd4e3853c5b4c34c9832fca11",
        //         "0xdd35a4fc09ac992fecf3acc29cd5036094336792958b3882f3987049bf71e48c",
        //         "0xf9597c7b33319259ae680eee757cee14b8a435ab17a2ed6b3b7d2267fae0f15f",
        //         "0x7c1e6563520fb591a2ddbbe19830b424b4b782c7c3fe7b21a0dca39a04a16670",
        //         "0xab61545440c2850f0054db22db8de8537df0d009333ac9e032b0edbded21bb4f",
        //         "0x126ba6ae4469c7fc319385aabb83b3972574e4da41cd70a7cbd129b6ed0a9a87",
        //         "0xf45a30b5f44bd54c624285b41d6e77557fe70322dc5394bb1dffb7f79a1c7e05",
        //         "0xa4e3ac0cc0050deb43b954e5fdc3d25bdf22c71b4d187f54cbb578b02e4e35e3"
        //     ],
        //     "profileId": "0x01a6",
        //     "claimScoreBbps": "9998",
        //     "claimableAmount": "9998000000000000000000"
        // }

        vm.startBroadcast(privateKey);

        address accountAddress = 0x7479B233fB386eD4Bcc889c9DF8b522C972b09F2; // lens/carlosbeltran
        bytes32[] memory proof = new bytes32[](10);
        proof[0] = 0x26cdab4d1aee2174ce34ab60293e8450bbf2c6ce071797ee4bbfcfe1db35f3e0;
        proof[1] = 0xdafd5adbf7540d4c455fb0935d45b85d2d8c6147746626453fd7f2c6b2f19411;
        proof[2] = 0x19721b08436bb3e67b73c926914ce88bdc8b78efd4e3853c5b4c34c9832fca11;
        proof[3] = 0xdd35a4fc09ac992fecf3acc29cd5036094336792958b3882f3987049bf71e48c;
        proof[4] = 0xf9597c7b33319259ae680eee757cee14b8a435ab17a2ed6b3b7d2267fae0f15f;
        proof[5] = 0x7c1e6563520fb591a2ddbbe19830b424b4b782c7c3fe7b21a0dca39a04a16670;
        proof[6] = 0xab61545440c2850f0054db22db8de8537df0d009333ac9e032b0edbded21bb4f;
        proof[7] = 0x126ba6ae4469c7fc319385aabb83b3972574e4da41cd70a7cbd129b6ed0a9a87;
        proof[8] = 0xf45a30b5f44bd54c624285b41d6e77557fe70322dc5394bb1dffb7f79a1c7e05;
        proof[9] = 0xa4e3ac0cc0050deb43b954e5fdc3d25bdf22c71b4d187f54cbb578b02e4e35e3;
        uint16 claimScoreBbps = 9998;

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