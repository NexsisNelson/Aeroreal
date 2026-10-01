// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/InvoiceVault.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @notice Mock invoice certificate NFT.
 */
contract InvoiceCertificate is ERC721 {
    uint256 private _nextId = 1;

    constructor() ERC721("Invoice Certificate", "INVCERT") {}

    function mint(address to) external returns (uint256) {
        uint256 id = _nextId++;
        _safeMint(to, id);
        return id;
    }
}

/**
 * @notice Mock stablecoin for settlement (mimics USDC/cNGN).
 */
contract MockStablecoin is ERC20 {
    constructor() ERC20("Mock USD", "mUSD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract InvoiceVaultTest is Test {

    InvoiceCertificate public cert;
    InvoiceVault public vault;
    MockStablecoin public usdc;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public issuer = address(0x1550);

    uint256 constant TOTAL_FRACTIONS = 10_000 * 1e18;
    uint256 constant FACE_VALUE = 5_000 * 1e18; // $5,000 invoice
    uint256 constant DISCOUNT_BPS = 500;        // 5% discount
    uint256 constant MATURITY_DAYS = 60;

    function setUp() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(issuer, 100 ether);

        // Deploy mock stablecoin.
        usdc = new MockStablecoin();

        // Deploy invoice certificate NFT.
        cert = new InvoiceCertificate();
        vm.prank(issuer);
        cert.mint(issuer);

        // Deploy the InvoiceVault.
        vault = new InvoiceVault(
            address(cert),
            1,
            TOTAL_FRACTIONS,
            "Invoice INV-2026-001",
            "fINV001",
            issuer,                                       // smeIssuer
            address(0xB0B),                               // invoiceBuyer
            FACE_VALUE,
            DISCOUNT_BPS,
            block.timestamp + (MATURITY_DAYS * 1 days),
            address(usdc),
            "ipfs://QmInvoicePDFHash",
            "Nigeria"
        );

        // Issuer approves the vault to take the invoice certificate.
        vm.prank(issuer);
        cert.approve(address(vault), 1);
    }

    function testInvoiceMetadata() public {
        (
            address smeIssuer,
            address invoiceBuyer,
            uint256 faceValue,
            uint256 discountBps,
            ,
            uint256 maturityDate,
            bool isSettled,
            ,
            address settlementToken,
            string memory invoiceDocURI,
            string memory buyerJurisdiction
        ) = vault.getInvoiceInfo();

        assertEq(smeIssuer, issuer);
        assertEq(invoiceBuyer, address(0xB0B));
        assertEq(faceValue, FACE_VALUE);
        assertEq(discountBps, DISCOUNT_BPS);
        assertEq(maturityDate, block.timestamp + (MATURITY_DAYS * 1 days));
        assertEq(isSettled, false);
        assertEq(settlementToken, address(usdc));
        assertEq(invoiceDocURI, "ipfs://QmInvoicePDFHash");
        assertEq(buyerJurisdiction, "Nigeria");

        console.log("TEST: Invoice metadata correct");
    }

    function testFractionalizeInvoice() public {
        vm.prank(issuer);
        vault.fractionalize();

        assertEq(
            vault.fractionToken().balanceOf(issuer),
            TOTAL_FRACTIONS,
            "Issuer should own all fractions"
        );
        assertEq(
            cert.ownerOf(1),
            address(vault),
            "Certificate should be locked in vault"
        );

        console.log("TEST: Invoice fractionalized");
    }

    function testDaysUntilMaturity() public {
        uint256 daysLeft = vault.daysUntilMaturity();
        assertEq(daysLeft, MATURITY_DAYS);

        // Fast forward 30 days.
        skip(30 days);

        daysLeft = vault.daysUntilMaturity();
        assertEq(daysLeft, 30);

        // Fast forward past maturity.
        skip(40 days);
        assertEq(vault.daysUntilMaturity(), 0);
        assertTrue(vault.isMatured());

        console.log("TEST: Maturity countdown correct");
    }

    function testSettlementAndClaim() public {
        // Step 1: Fractionalize.
        vm.prank(issuer);
        vault.fractionalize();

        // Step 2: Issuer whitelists Alice and Bob, then transfers fractions.
        // (Issuer is the FractionToken owner because the vault deployed it.)
        vm.startPrank(address(vault));
        vault.fractionToken().addToWhitelist(alice);
        vault.fractionToken().addToWhitelist(bob);
        vm.stopPrank();

        vm.startPrank(issuer);
        vault.fractionToken().transfer(alice, TOTAL_FRACTIONS / 2); // 50%
        vault.fractionToken().transfer(bob, TOTAL_FRACTIONS / 4);   // 25%
        vm.stopPrank();

        // Step 3: Buyer pays the invoice at maturity.
        skip(MATURITY_DAYS * 1 days);

        uint256 payment = FACE_VALUE; // Buyer pays full face value.
        usdc.mint(address(this), payment);
        usdc.approve(address(vault), payment);
        vault.settleInvoice(payment);

        assertTrue(vault.isSettled());
        assertEq(vault.totalSettled(), payment);

        console.log("TEST: Invoice settled with", payment);

        // Step 4: Alice claims her 50% share.
        vm.prank(alice);
        vault.claimProceeds();

        uint256 aliceExpected = (payment * 50) / 100;
        assertEq(
            usdc.balanceOf(alice),
            aliceExpected,
            "Alice should have 50% of proceeds"
        );

        console.log("TEST: Alice claimed", aliceExpected);

        // Step 5: Bob claims his 25% share.
        vm.prank(bob);
        vault.claimProceeds();

        uint256 bobExpected = (payment * 25) / 100;
        assertEq(
            usdc.balanceOf(bob),
            bobExpected,
            "Bob should have 25% of proceeds"
        );

        console.log("TEST: Bob claimed", bobExpected);

        // Step 6: Issuer claims their remaining 25% share.
        vm.prank(issuer);
        vault.claimProceeds();

        console.log("TEST: Full invoice lifecycle complete");
    }

    function testCannotClaimBeforeSettlement() public {
        vm.prank(issuer);
        vault.fractionalize();

        // Try to claim before settlement.
        vm.prank(issuer);
        vm.expectRevert("Invoice not settled yet");
        vault.claimProceeds();

        console.log("TEST: Cannot claim before settlement");
    }

    function testCannotDoubleSettle() public {
        vm.prank(issuer);
        vault.fractionalize();

        // Settle once.
        usdc.mint(address(this), FACE_VALUE);
        usdc.approve(address(vault), FACE_VALUE);
        vault.settleInvoice(FACE_VALUE);

        // Try to settle again.
        usdc.mint(address(this), FACE_VALUE);
        usdc.approve(address(vault), FACE_VALUE);
        vm.expectRevert("Already settled");
        vault.settleInvoice(FACE_VALUE);

        console.log("TEST: Cannot double settle");
    }

    function testCannotDoubleClaim() public {
        vm.prank(issuer);
        vault.fractionalize();

        // Settle.
        usdc.mint(address(this), FACE_VALUE);
        usdc.approve(address(vault), FACE_VALUE);
        vault.settleInvoice(FACE_VALUE);

        // Issuer claims once.
        vm.prank(issuer);
        vault.claimProceeds();

        // Try to claim again.
        vm.prank(issuer);
        vm.expectRevert("Nothing to claim");
        vault.claimProceeds();

        console.log("TEST: Cannot double claim");
    }
}
