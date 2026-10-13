// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SimulatedAssetFactory.sol";

contract DeploySimulatedAssetFactory is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address oracle = vm.addr(privateKey);
        address marketplace = vm.envAddress("SIMULATED_MARKETPLACE_ADDRESS");
        require(marketplace != address(0), "Invalid marketplace");

        vm.startBroadcast(privateKey);
        SimulatedAssetFactory factory =
            new SimulatedAssetFactory(marketplace, oracle);
        vm.stopBroadcast();

        console.log("SimulatedAssetFactory:", address(factory));
        console.log("Oracle:", oracle);
        console.log("Marketplace:", marketplace);
    }
}
