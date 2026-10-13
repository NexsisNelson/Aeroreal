// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SimulatedAssetFactory.sol";
import "../src/SimulatedMarketplace.sol";

contract DeployRotatedSimulatedStack is Script {
    address constant AREAL = 0x01c6b9a2F0f73eb7f6a3280C5D028cB2BAe40B76;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address oracle = vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        SimulatedMarketplace marketplace = new SimulatedMarketplace(AREAL);
        SimulatedAssetFactory factory =
            new SimulatedAssetFactory(address(marketplace), oracle);
        vm.stopBroadcast();

        console.log("SimulatedMarketplace:", address(marketplace));
        console.log("SimulatedAssetFactory:", address(factory));
        console.log("Oracle:", oracle);
        console.log("AREAL:", AREAL);
    }
}
