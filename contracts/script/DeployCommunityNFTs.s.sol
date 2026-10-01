// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SimulatedNFTCollection.sol";

/**
 * @title DeployCommunityNFTs
 * @notice Deploys mock NFT collections that represent the "Monad community"
 *         in the Aeroreal marketplace. These are real ERC-721 contracts
 *         with real tokens, intended to demo a populated NFT ecosystem.
 */
contract DeployCommunityNFTs is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deployer:", deployer);

        vm.startBroadcast(privateKey);

        SimulatedNFTCollection monadApes = new SimulatedNFTCollection("Monad Apes", "MAPE");
        console.log("Monad Apes:", address(monadApes));
        for (uint256 i = 0; i < 10; i++) {
            monadApes.mint(deployer);
        }
        console.log("Minted 10 Monad Apes");

        SimulatedNFTCollection monadPunks = new SimulatedNFTCollection("Monad Punks", "MPUNK");
        console.log("Monad Punks:", address(monadPunks));
        for (uint256 i = 0; i < 10; i++) {
            monadPunks.mint(deployer);
        }
        console.log("Minted 10 Monad Punks");

        SimulatedNFTCollection monadFrogs = new SimulatedNFTCollection("Monad Frogs", "MFROG");
        console.log("Monad Frogs:", address(monadFrogs));
        for (uint256 i = 0; i < 10; i++) {
            monadFrogs.mint(deployer);
        }
        console.log("Minted 10 Monad Frogs");

        vm.stopBroadcast();

        console.log("");
        console.log("=== COMMUNITY NFT COLLECTIONS DEPLOYED ===");
        console.log("Monad Apes:", address(monadApes));
        console.log("Monad Punks:", address(monadPunks));
        console.log("Monad Frogs:", address(monadFrogs));
    }
}
