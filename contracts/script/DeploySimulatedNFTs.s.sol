// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SimulatedNFTCollection.sol";

contract DeploySimulatedNFTs is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deployer:", deployer);
        vm.startBroadcast(privateKey);

        SimulatedNFTCollection apes = new SimulatedNFTCollection("Simulated Bored Apes", "sBAYC");
        SimulatedNFTCollection punks = new SimulatedNFTCollection("Simulated CryptoPunks", "sPUNK");
        SimulatedNFTCollection doodles = new SimulatedNFTCollection("Simulated Doodles", "sDOODLE");

        vm.stopBroadcast();

        console.log("=== SIMULATED NFT COLLECTIONS DEPLOYED ===");
        console.log("sBAYC:", address(apes));
        console.log("sPUNK:", address(punks));
        console.log("sDOODLE:", address(doodles));
    }
}
