// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/NFTMarketplace.sol";
import "../src/FractionMarketplace.sol";
import "../src/FractionalizerVault.sol";

contract RedeployMarketplaces is Script {
    address constant AREAL =
        0x01c6b9a2F0f73eb7f6a3280C5D028cB2BAe40B76;
    address constant GOLD_VAULT =
        0x1dBBfCCe0095847548dD21dCCEbfe8eB9C7cdb4a;
    address constant COFFEE_VAULT =
        0x5fD30D6E3C736e5E8FFA70abd4c3FBDeAdcEED2E;
    address constant TREASURY_VAULT =
        0x934F83a89C4471b5D375f4ac52Ee45c9f5E94df0;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deployer:", deployer);
        console.log("AREAL (payment token):", AREAL);

        vm.startBroadcast(privateKey);

        NFTMarketplace nftMarket = new NFTMarketplace(AREAL);
        console.log("NFTMarketplace:", address(nftMarket));

        FractionMarketplace fractionMarket = new FractionMarketplace(AREAL);
        console.log("FractionMarketplace:", address(fractionMarket));

        FractionalizerVault(GOLD_VAULT).whitelistStreamer(address(fractionMarket));
        FractionalizerVault(COFFEE_VAULT).whitelistStreamer(address(fractionMarket));
        FractionalizerVault(TREASURY_VAULT).whitelistStreamer(address(fractionMarket));
        console.log("Fraction marketplace whitelisted on asset vaults");

        vm.stopBroadcast();

        console.log("");
        console.log("=== MARKETPLACES REDEPLOYED ===");
        console.log("NFTMarketplace:", address(nftMarket));
        console.log("FractionMarketplace:", address(fractionMarket));
    }
}