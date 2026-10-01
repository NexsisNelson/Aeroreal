// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/MockStablecoin.sol";
import "../src/CommodityCertificate.sol";
import "../src/InvoiceCertificate.sol";
import "../src/CommodityVault.sol";
import "../src/InvoiceVault.sol";
import "../src/RevenueOracle.sol";
import "../src/RevenueStreamer.sol";

/**
 * @title DeployRWA
 * @notice Deploys the full RWA stack on Monad Testnet:
 *         1. Mock stablecoin (mUSD)
 *         2. Commodity + Invoice certificate NFTs
 *         3. RevenueOracle
 *         4. Two demo vaults (Commodity + Invoice)
 *         5. Two RevenueStreamers (one per vault)
 *         Then wires everything together.
 */
contract DeployRWA is Script {

    uint256 constant TOTAL_FRACTIONS = 10_000 * 1e18;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // =====================================================
        // 1. Deploy the mock stablecoin.
        // =====================================================
        MockStablecoin mUSD = new MockStablecoin();
        console.log("MockStablecoin (mUSD):", address(mUSD));

        // =====================================================
        // 2. Deploy certificate NFT contracts.
        // =====================================================
        CommodityCertificate commodityCert = new CommodityCertificate();
        console.log("CommodityCertificate:", address(commodityCert));

        InvoiceCertificate invoiceCert = new InvoiceCertificate();
        console.log("InvoiceCertificate:", address(invoiceCert));

        // =====================================================
        // 3. Mint one certificate of each type to the deployer.
        // =====================================================
        uint256 commodityTokenId = commodityCert.mint(deployer);
        console.log("Minted CommodityCertificate #", commodityTokenId);

        uint256 invoiceTokenId = invoiceCert.mint(deployer);
        console.log("Minted InvoiceCertificate #", invoiceTokenId);

        // =====================================================
        // 4. Deploy the RevenueOracle.
        // =====================================================
        RevenueOracle oracle = new RevenueOracle(address(mUSD));
        console.log("RevenueOracle:", address(oracle));

        // =====================================================
        // 5. Deploy a demo CommodityVault: 100kg Nigerian Cocoa.
        // =====================================================
        CommodityVault cocoaVault = new CommodityVault(
            address(commodityCert),
            commodityTokenId,
            TOTAL_FRACTIONS,
            "Fractionalized Nigerian Cocoa Batch 001",
            "fCOCOA",
            "Cocoa",
            100,
            "kg",
            "Lagos Free Zone, Warehouse A",
            "ipfs://QmDemoAuditReport",
            "Nexsis Custody Ltd"
        );
        console.log("CommodityVault (Cocoa):", address(cocoaVault));

        // =====================================================
        // 6. Deploy a demo InvoiceVault: 5M NGN invoice, 60 days.
        // =====================================================
        InvoiceVault invoiceVault = new InvoiceVault(
            address(invoiceCert),
            invoiceTokenId,
            TOTAL_FRACTIONS,
            "Invoice INV-2026-001",
            "fINV001",
            deployer,
            address(0xB0B),
            5_000_000 * 1e18,
            500,
            block.timestamp + 60 days,
            address(mUSD),
            "ipfs://QmDemoInvoicePDF",
            "Nigeria"
        );
        console.log("InvoiceVault:", address(invoiceVault));

        // =====================================================
        // 7. Approve + fractionalize both vaults.
        // =====================================================
        commodityCert.approve(address(cocoaVault), commodityTokenId);
        cocoaVault.fractionalize();
        console.log("Cocoa vault fractionalized");

        invoiceCert.approve(address(invoiceVault), invoiceTokenId);
        invoiceVault.fractionalize();
        console.log("Invoice vault fractionalized");

        // =====================================================
        // 8. Deploy RevenueStreamers for each vault.
        // =====================================================
        RevenueStreamer cocoaStreamer = new RevenueStreamer(
            address(cocoaVault.fractionToken()),
            address(mUSD),
            address(cocoaVault)
        );
        console.log("Cocoa Streamer:", address(cocoaStreamer));

        RevenueStreamer invoiceStreamer = new RevenueStreamer(
            address(invoiceVault.fractionToken()),
            address(mUSD),
            address(invoiceVault)
        );
        console.log("Invoice Streamer:", address(invoiceStreamer));

        // =====================================================
        // 9. Wire up the oracle reporter (deployer is reporter).
        // =====================================================
        oracle.addReporter(deployer);
        console.log("Deployer added as oracle reporter");

        // =====================================================
        // 10. Mint demo mUSD to the deployer for revenue simulation.
        // =====================================================
        mUSD.mint(deployer, 1_000_000 * 1e18);
        console.log("Minted 1M mUSD to deployer for testing");

        // =====================================================
        // 11. Whitelist the streamers on the fraction tokens.
        // =====================================================
        // Use the vault-side authorize hook and let the vault call the
        // fraction token's vaultWhitelist() escape hatch without a prank.
        cocoaVault.whitelistStreamer(address(cocoaStreamer));
        invoiceVault.whitelistStreamer(address(invoiceStreamer));
        console.log("Streamers whitelisted on fraction tokens via vault escrow");

        vm.stopBroadcast();

        // =====================================================
        // SUMMARY
        // =====================================================
        console.log("");
        console.log("=== RWA DEPLOYMENT COMPLETE ===");
        console.log("");
        console.log("--- Core Contracts ---");
        console.log("MockStablecoin (mUSD):", address(mUSD));
        console.log("RevenueOracle:", address(oracle));
        console.log("");
        console.log("--- Certificate NFTs ---");
        console.log("CommodityCertificate:", address(commodityCert));
        console.log("InvoiceCertificate:", address(invoiceCert));
        console.log("");
        console.log("--- Asset Vaults ---");
        console.log("Cocoa CommodityVault:", address(cocoaVault));
        console.log("Invoice Vault:", address(invoiceVault));
        console.log("");
        console.log("--- FractionTokens ---");
        console.log("fCOCOA:", address(cocoaVault.fractionToken()));
        console.log("fINV001:", address(invoiceVault.fractionToken()));
        console.log("");
        console.log("--- RevenueStreamers ---");
        console.log("Cocoa Streamer:", address(cocoaStreamer));
        console.log("Invoice Streamer:", address(invoiceStreamer));
        console.log("");
        console.log("=== SAVE THESE ADDRESSES FOR THE FLUTTER APP ===");
    }
}
