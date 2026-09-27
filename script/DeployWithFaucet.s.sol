// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/CommodityVault.sol";
import "../src/CommodityCertificate.sol";
import "../src/MockStablecoin.sol";
import "../src/Faucet.sol";
import "../src/FaucetFractionToken.sol";
import "../src/FractionMarketplace.sol";
import "../src/YieldRewardToken.sol";

contract DeployWithFaucet is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);

        MockStablecoin musd = new MockStablecoin();
        console.log("MockStablecoin:", address(musd));

        FractionMarketplace marketplace = new FractionMarketplace(address(musd));
        console.log("FractionMarketplace:", address(marketplace));

        CommodityCertificate cert = new CommodityCertificate();
        console.log("CommodityCertificate:", address(cert));

        uint256 certId = cert.mint(deployer);
        console.log("Minted cert #", certId);

        CommodityVault goldVault = new CommodityVault(
            address(cert),
            certId,
            10_000 * 1e18,
            "Fractionalized Gold",
            "fGOLD",
            "Gold",
            1,
            "kg",
            "Zurich Free Port, Switzerland",
            "ipfs://QmGoldAudit",
            "Swiss Vault Custody AG"
        );
        console.log("GoldVault:", address(goldVault));

        cert.approve(address(goldVault), certId);
        goldVault.fractionalize();

        uint256 certId2 = cert.mint(deployer);
        CommodityVault coffeeVault = new CommodityVault(
            address(cert),
            certId2,
            10_000 * 1e18,
            "Fractionalized Coffee",
            "fCOFFEE",
            "Coffee",
            500,
            "kg",
            "Addis Ababa, Ethiopia",
            "ipfs://QmCoffeeAudit",
            "Ethiopian Coffee Exporters Association"
        );
        console.log("CoffeeVault:", address(coffeeVault));

        cert.approve(address(coffeeVault), certId2);
        coffeeVault.fractionalize();

        Faucet faucet = new Faucet(
            address(musd),
            address(goldVault.fractionToken()),
            address(coffeeVault.fractionToken()),
            address(cert)
        );
        console.log("Faucet:", address(faucet));

        goldVault.setFractionTokenFaucet(address(faucet));
        coffeeVault.setFractionTokenFaucet(address(faucet));
        goldVault.whitelistStreamer(address(faucet));
        coffeeVault.whitelistStreamer(address(faucet));

        goldVault.whitelistStreamer(address(marketplace));
        coffeeVault.whitelistStreamer(address(marketplace));

        YieldRewardToken areal = new YieldRewardToken("Aeroreal Token", "AREAL");
        console.log("AREAL:", address(areal));

        vm.stopBroadcast();

        console.log("");
        console.log("=== FAUCET DEPLOYMENT COMPLETE ===");
        console.log("mUSD:", address(musd));
        console.log("DemoNFT:", address(cert));
        console.log("GoldVault:", address(goldVault));
        console.log("GoldFractionToken:", address(goldVault.fractionToken()));
        console.log("CoffeeVault:", address(coffeeVault));
        console.log("CoffeeFractionToken:", address(coffeeVault.fractionToken()));
        console.log("Faucet:", address(faucet));
        console.log("FractionMarketplace:", address(marketplace));
        console.log("AREAL:", address(areal));
    }
}
