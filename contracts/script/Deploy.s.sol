// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/FractionFactory.sol";
import "../src/YieldRewardToken.sol";

/**
 * @title Deploy
 * @notice Deploys the FractionFactory and YieldRewardToken to Monad Testnet.
 */
contract Deploy is Script {
    function run() external {
        // Load the private key from environment.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying from:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the AREAL reward token.
        YieldRewardToken areal = new YieldRewardToken("Aeroreal Token", "AREAL");
        console.log("YieldRewardToken deployed at:", address(areal));

        // 2. Deploy the FractionFactory (the Vending Machine).
        FractionFactory factory = new FractionFactory();
        console.log("FractionFactory deployed at:", address(factory));

        vm.stopBroadcast();

        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Save these addresses:");
        console.log("AREAL:", address(areal));
        console.log("FractionFactory:", address(factory));
    }
}
