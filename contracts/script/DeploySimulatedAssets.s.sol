// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SimulatedAsset.sol";
import "../src/SimulatedMarketplace.sol";

contract DeploySimulatedAssets is Script {
    address constant AREAL = 0x01c6b9a2F0f73eb7f6a3280C5D028cB2BAe40B76;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deployer:", deployer);
        vm.startBroadcast(privateKey);

        SimulatedMarketplace market = new SimulatedMarketplace(AREAL);
        console.log("SimulatedMarketplace:", address(market));

        SimulatedAsset sBTC = new SimulatedAsset("Simulated Bitcoin", "sBTC", "BTC", deployer, 60_000 * 1e18);
        SimulatedAsset sETH = new SimulatedAsset("Simulated Ethereum", "sETH", "ETH", deployer, 3_000 * 1e18);
        SimulatedAsset sGOLD = new SimulatedAsset("Simulated Gold", "sGOLD", "XAU", deployer, 2_100 * 1e18);
        SimulatedAsset sCOFFEE = new SimulatedAsset("Simulated Coffee", "sCOFFEE", "COFFEE", deployer, 200 * 1e18);
        SimulatedAsset sSOL = new SimulatedAsset("Simulated Solana", "sSOL", "SOL", deployer, 150 * 1e18);

        console.log("sBTC:", address(sBTC));
        console.log("sETH:", address(sETH));
        console.log("sGOLD:", address(sGOLD));
        console.log("sCOFFEE:", address(sCOFFEE));
        console.log("sSOL:", address(sSOL));

        sBTC.transferOwnership(address(market));
        sETH.transferOwnership(address(market));
        sGOLD.transferOwnership(address(market));
        sCOFFEE.transferOwnership(address(market));
        sSOL.transferOwnership(address(market));

        vm.stopBroadcast();

        console.log("");
        console.log("=== SIMULATED ASSETS DEPLOYED ===");
        console.log("Marketplace:", address(market));
        console.log("sBTC:", address(sBTC));
        console.log("sETH:", address(sETH));
        console.log("sGOLD:", address(sGOLD));
        console.log("sCOFFEE:", address(sCOFFEE));
        console.log("sSOL:", address(sSOL));
    }
}
