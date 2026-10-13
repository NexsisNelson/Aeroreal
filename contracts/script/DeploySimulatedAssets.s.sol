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
        uint256 btcInitialPrice = _initialPrice("SIMULATED_BTC_INITIAL_PRICE_USD");
        uint256 ethInitialPrice = _initialPrice("SIMULATED_ETH_INITIAL_PRICE_USD");
        uint256 goldInitialPrice = _initialPrice("SIMULATED_GOLD_INITIAL_PRICE_USD");
        uint256 coffeeInitialPrice = _initialPrice("SIMULATED_COFFEE_INITIAL_PRICE_USD");
        uint256 solInitialPrice = _initialPrice("SIMULATED_SOL_INITIAL_PRICE_USD");

        console.log("Deployer:", deployer);
        vm.startBroadcast(privateKey);

        SimulatedMarketplace market = new SimulatedMarketplace(AREAL);
        console.log("SimulatedMarketplace:", address(market));

        SimulatedAsset sBTC = new SimulatedAsset("Simulated Bitcoin", "sBTC", "BTC", deployer, btcInitialPrice);
        SimulatedAsset sETH = new SimulatedAsset("Simulated Ethereum", "sETH", "ETH", deployer, ethInitialPrice);
        SimulatedAsset sGOLD = new SimulatedAsset("Simulated Gold", "sGOLD", "XAU", deployer, goldInitialPrice);
        SimulatedAsset sCOFFEE =
            new SimulatedAsset("Simulated Coffee", "sCOFFEE", "COFFEE", deployer, coffeeInitialPrice);
        SimulatedAsset sSOL = new SimulatedAsset("Simulated Solana", "sSOL", "SOL", deployer, solInitialPrice);

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

    function _initialPrice(string memory variableName) private view returns (uint256) {
        uint256 price = vm.envUint(variableName);
        require(price > 0, string.concat(variableName, " must be greater than zero"));
        return price * 1e18;
    }
}