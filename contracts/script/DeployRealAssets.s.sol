// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/CommodityVault.sol";
import "../src/InvoiceVault.sol";
import "../src/RevenueStreamer.sol";
import "../src/CommodityCertificate.sol";
import "../src/InvoiceCertificate.sol";

/**
 * @title DeployRealAssets
 * @notice Deploys three realistic RWA vaults on Monad Testnet:
 *         1. Gold (CommodityVault)
 *         2. Ethiopian Coffee (CommodityVault)
 *         3. US Treasury Bill (InvoiceVault — 90-day maturity)
 *
 *         Uses the existing deployed infrastructure:
 *         - MockStablecoin (mUSD)
 *         - RevenueOracle
 *         - CommodityCertificate + InvoiceCertificate factories
 */
contract DeployRealAssets is Script {

    // ---- REPLACE THESE with your existing deployed addresses ----
    address constant MOCK_STABLECOIN = 0x01eA8d5FF45f5fAaC8b5BbE1e48cc734cd104512;
    address constant REVENUE_ORACLE = 0x867Ca7417E20c191AAf149219B8af86f3Bb6d689;

    uint256 constant TOTAL_FRACTIONS = 10_000 * 1e18;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // =====================================================
        // 1. Deploy certificate contracts.
        // =====================================================
        CommodityCertificate commodityCert = new CommodityCertificate();
        InvoiceCertificate invoiceCert = new InvoiceCertificate();
        console.log("CommodityCertificate:", address(commodityCert));
        console.log("InvoiceCertificate:", address(invoiceCert));

        // =====================================================
        // 2. GOLD VAULT — 1kg gold in Zurich.
        // =====================================================
        uint256 goldCertId = commodityCert.mint(deployer);
        CommodityVault goldVault = new CommodityVault(
            address(commodityCert),
            goldCertId,
            TOTAL_FRACTIONS,
            "Tokenized Gold - 1kg Bar",
            "fGOLD",
            "Gold",
            1,
            "kg",
            "Zurich Free Port, Switzerland",
            "ipfs://QmGoldAuditReport2026",
            "Swiss Vault Custody AG"
        );
        console.log("GoldVault:", address(goldVault));

        commodityCert.approve(address(goldVault), goldCertId);
        goldVault.fractionalize();
        console.log("Gold vault fractionalized");

        RevenueStreamer goldStreamer = new RevenueStreamer(
            address(goldVault.fractionToken()),
            MOCK_STABLECOIN,
            address(goldVault)
        );
        console.log("GoldStreamer:", address(goldStreamer));
        goldVault.whitelistStreamer(address(goldStreamer));

        // =====================================================
        // 3. COFFEE VAULT — 500kg Ethiopian Yirgacheffe.
        // =====================================================
        uint256 coffeeCertId = commodityCert.mint(deployer);
        CommodityVault coffeeVault = new CommodityVault(
            address(commodityCert),
            coffeeCertId,
            TOTAL_FRACTIONS,
            "Ethiopian Yirgacheffe Coffee - 500kg",
            "fCOFFEE",
            "Coffee",
            500,
            "kg",
            "Addis Ababa Cooperative Warehouse, Ethiopia",
            "ipfs://QmCoffeeAuditReport2026",
            "Ethiopian Coffee Exporters Association"
        );
        console.log("CoffeeVault:", address(coffeeVault));

        commodityCert.approve(address(coffeeVault), coffeeCertId);
        coffeeVault.fractionalize();
        console.log("Coffee vault fractionalized");

        RevenueStreamer coffeeStreamer = new RevenueStreamer(
            address(coffeeVault.fractionToken()),
            MOCK_STABLECOIN,
            address(coffeeVault)
        );
        console.log("CoffeeStreamer:", address(coffeeStreamer));
        coffeeVault.whitelistStreamer(address(coffeeStreamer));

        // =====================================================
        // 4. TREASURY BILL VAULT — $10,000, 90-day maturity.
        // =====================================================
        uint256 tbillCertId = invoiceCert.mint(deployer);
        InvoiceVault tbillVault = new InvoiceVault(
            address(invoiceCert),
            tbillCertId,
            TOTAL_FRACTIONS,
            "US Treasury Bill - 90 Day",
            "fTBILL",
            deployer,
            address(0x0000000000000000000000000000000000000001),
            10_000 * 1e18,
            200,
            block.timestamp + 90 days,
            MOCK_STABLECOIN,
            "ipfs://QmTreasuryBillDoc",
            "United States"
        );
        console.log("TreasuryVault:", address(tbillVault));

        invoiceCert.approve(address(tbillVault), tbillCertId);
        tbillVault.fractionalize();
        console.log("Treasury vault fractionalized");

        RevenueStreamer tbillStreamer = new RevenueStreamer(
            address(tbillVault.fractionToken()),
            MOCK_STABLECOIN,
            address(tbillVault)
        );
        console.log("TreasuryStreamer:", address(tbillStreamer));
        tbillVault.whitelistStreamer(address(tbillStreamer));

        vm.stopBroadcast();

        // =====================================================
        // SUMMARY
        // =====================================================
        console.log("");
        console.log("=== REAL ASSET DEPLOYMENT COMPLETE ===");
        console.log("");
        console.log("CommodityCertificate:", address(commodityCert));
        console.log("InvoiceCertificate:", address(invoiceCert));
        console.log("");
        console.log("--- GOLD ---");
        console.log("GoldVault:", address(goldVault));
        console.log("GoldStreamer:", address(goldStreamer));
        console.log("");
        console.log("--- COFFEE ---");
        console.log("CoffeeVault:", address(coffeeVault));
        console.log("CoffeeStreamer:", address(coffeeStreamer));
        console.log("");
        console.log("--- TREASURY BILLS ---");
        console.log("TreasuryVault:", address(tbillVault));
        console.log("TreasuryStreamer:", address(tbillStreamer));
    }
}
