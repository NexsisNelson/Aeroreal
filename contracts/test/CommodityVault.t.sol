// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/CommodityVault.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @notice A mock "certificate NFT" that proves ownership of a physical
 *         commodity batch. In production this would be minted by the
 *         custodian or the SPV that owns the physical goods.
 */
contract CommodityCertificate is ERC721 {
    uint256 private _nextId = 1;

    constructor() ERC721("Commodity Certificate", "CERT") {}

    function mint(address to) external returns (uint256) {
        uint256 id = _nextId++;
        _safeMint(to, id);
        return id;
    }
}

contract CommodityVaultTest is Test {

    CommodityCertificate public cert;
    CommodityVault public vault;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    uint256 constant TOTAL_FRACTIONS = 10_000 * 1e18;

    function setUp() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        // 1. Deploy a certificate NFT contract.
        cert = new CommodityCertificate();

        // 2. Mint a certificate to Alice (represents her commodity batch).
        vm.prank(alice);
        cert.mint(alice);

        // 3. Deploy the CommodityVault for that certificate.
        vault = new CommodityVault(
            address(cert),
            1,                              // tokenId
            TOTAL_FRACTIONS,                // fraction count
            "Fractionalized Cocoa Batch 001", // name
            "fCOCOA",                       // symbol
            "Cocoa",                        // commodityType
            100,                            // quantity: 100 kg
            "kg",                           // unit
            "Lagos Free Zone, Warehouse A", // storageLocation
            "ipfs://QmAuditReportHash",     // auditReportURI
            "Nexsis Custody Ltd"            // custodian
        );

        // 4. Alice approves the vault to take the certificate.
        vm.prank(alice);
        cert.approve(address(vault), 1);
    }

    function testCommodityMetadata() public {
        (
            string memory commodityType,
            uint256 quantity,
            string memory unit,
            string memory location,
            string memory auditURI,
            ,
            string memory custodian
        ) = vault.getCommodityInfo();

        assertEq(commodityType, "Cocoa", "Wrong commodity type");
        assertEq(quantity, 100, "Wrong quantity");
        assertEq(unit, "kg", "Wrong unit");
        assertEq(location, "Lagos Free Zone, Warehouse A", "Wrong location");
        assertEq(auditURI, "ipfs://QmAuditReportHash", "Wrong audit URI");
        assertEq(custodian, "Nexsis Custody Ltd", "Wrong custodian");

        console.log("TEST: Commodity metadata correct");
    }

    function testFullCommodityLifecycle() public {
        // ---- Step 1: Alice fractionalizes her commodity certificate. ----
        vm.prank(alice);
        vault.fractionalize();

        FractionToken fractionToken = vault.fractionToken();
        assertEq(
            fractionToken.balanceOf(alice),
            TOTAL_FRACTIONS,
            "Alice should own all fractions"
        );
        assertEq(
            cert.ownerOf(1),
            address(vault),
            "Certificate should be locked in the vault"
        );

        console.log("TEST: Commodity fractionalized");

        // ---- Step 2: Bob is whitelisted, then receives some fractions. ----
        vm.prank(address(vault));
        fractionToken.addToWhitelist(bob);

        vm.prank(alice);
        fractionToken.transfer(bob, TOTAL_FRACTIONS / 4);

        assertEq(
            fractionToken.balanceOf(bob),
            TOTAL_FRACTIONS / 4,
            "Bob should hold 25% of fractions"
        );

        console.log("TEST: Bob whitelisted and holds 25%");

        // ---- Step 3: Alice redeems by re-collecting all fractions. ----
        vm.prank(bob);
        fractionToken.transfer(alice, TOTAL_FRACTIONS / 4);

        vm.prank(alice);
        vault.redeem();

        assertEq(
            cert.ownerOf(1),
            alice,
            "Alice should own the certificate again"
        );

        console.log("TEST: Full commodity lifecycle complete");
    }

    function testUpdateAuditReport() public {
        vm.prank(address(this));
        // Note: `address(this)` is the test contract, which is the vault owner
        // because it deployed the vault.
        vault.updateAuditReport("ipfs://QmNewAuditHash");

        (, , , , string memory auditURI, , ) = vault.getCommodityInfo();
        assertEq(auditURI, "ipfs://QmNewAuditHash", "Audit URI not updated");

        console.log("TEST: Audit report updated");
    }
}
