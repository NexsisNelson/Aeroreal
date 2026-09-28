// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/MicroYieldStreamer.sol";
import "../src/YieldRewardToken.sol";
import "../src/FractionalizerVault.sol";

contract DeployYieldStreamer is Script {
    address constant GOLD_FRACTION_TOKEN =
        0x6511204b20e1cbeCEC46673Ac602F97C72388Ff1;
    address constant GOLD_VAULT =
        0x1dBBfCCe0095847548dD21dCCEbfe8eB9C7cdb4a;
    address constant AREAL_TOKEN =
        0xaa1fbec3F43a6dE2E2791052d593C2b9b7A57Ed4;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deployer:", deployer);
        console.log("Gold FractionToken:", GOLD_FRACTION_TOKEN);
        console.log("AREAL Token:", AREAL_TOKEN);

        vm.startBroadcast(privateKey);

        MicroYieldStreamer streamer = new MicroYieldStreamer(
            GOLD_FRACTION_TOKEN,
            AREAL_TOKEN
        );
        console.log("MicroYieldStreamer:", address(streamer));

        YieldRewardToken(AREAL_TOKEN).setStreamer(address(streamer));
        console.log("AREAL streamer set");

        FractionalizerVault(GOLD_VAULT).whitelistStreamer(address(streamer));
        console.log("Gold fraction token authorized the streamer");

        streamer.setRewardRate(1e18);
        console.log("Reward rate set to 1 AREAL/sec");

        vm.stopBroadcast();

        console.log("");
        console.log("=== YIELD STREAMER DEPLOYED ===");
        console.log("MicroYieldStreamer:", address(streamer));
    }
}