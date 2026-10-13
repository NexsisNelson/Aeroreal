// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/YieldRewardToken.sol";
import "../src/ArealFaucet.sol";
import "../src/MicroYieldStreamer.sol";
import "../src/FractionalizerVault.sol";

contract RedeployArealStack is Script {
    address constant GOLD_FRACTION_TOKEN = 0x6511204b20e1cbeCEC46673Ac602F97C72388Ff1;
    address constant GOLD_VAULT = 0x1dBBfCCe0095847548dD21dCCEbfe8eB9C7cdb4a;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deployer:", deployer);
        console.log("Gas balance (wei):", deployer.balance);

        vm.startBroadcast(privateKey);

        YieldRewardToken areal = new YieldRewardToken("Aeroreal Token", "AREAL");
        console.log("New AREAL:", address(areal));

        ArealFaucet faucet = new ArealFaucet(address(areal));
        console.log("New ArealFaucet:", address(faucet));

        areal.setFaucet(address(faucet));
        console.log("AREAL faucet set");

        MicroYieldStreamer streamer = new MicroYieldStreamer(GOLD_FRACTION_TOKEN, address(areal));
        console.log("New MicroYieldStreamer:", address(streamer));

        areal.setStreamer(address(streamer));
        console.log("AREAL streamer set");

        streamer.setRewardRate(1e18);
        console.log("Reward rate set to 1 AREAL/sec");

        FractionalizerVault(GOLD_VAULT).whitelistStreamer(address(streamer));
        console.log("Gold fraction token authorized the streamer");

        vm.stopBroadcast();

        console.log("");
        console.log("=== AREAL STACK REDEPLOYED ===");
        console.log("AREAL:", address(areal));
        console.log("ArealFaucet:", address(faucet));
        console.log("MicroYieldStreamer:", address(streamer));
    }
}
