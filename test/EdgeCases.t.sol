// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/FractionFactory.sol";
import "../src/MicroYieldStreamer.sol";
import "../src/YieldRewardToken.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNFT2 is ERC721 {
    uint256 private _nextId = 1;

    constructor() ERC721("Mock Ape 2", "MAPE2") {}

    function mint(address to) external returns (uint256) {
        uint256 id = _nextId++;
        _mint(to, id);
        return id;
    }
}

contract EdgeCasesTest is Test {

    MockNFT2 public nft;
    FractionFactory public factory;
    YieldRewardToken public sprinkleToken;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public attacker = address(0xBAD);

    uint256 public constant TOTAL_FRACTIONS = 10_000;

    function setUp() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(attacker, 100 ether);

        nft = new MockNFT2();
        sprinkleToken = new YieldRewardToken("Micro Sprinkle", "SPR");
        factory = new FractionFactory();

        vm.prank(alice);
        nft.mint(alice);

        vm.prank(bob);
        nft.mint(bob);
    }

    // =====================================================
    // TEST 1: Cannot fractionalize the same NFT twice.
    // =====================================================
    function testCannotDoubleFractionalize() public {
        vm.prank(alice);
        address vaultAddress = factory.createVault(
            address(nft), 1, TOTAL_FRACTIONS, "fMAPE", "fMAPE"
        );

        FractionalizerVault vault = FractionalizerVault(vaultAddress);

        vm.startPrank(alice);
        nft.approve(vaultAddress, 1);
        vault.fractionalize();
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert("This NFT is already fractionalized");
        factory.createVault(
            address(nft), 1, TOTAL_FRACTIONS, "fMAPE-DUP", "fMAPED"
        );

        console.log("TEST 1 PASSED: Cannot double fractionalize");
    }

    // =====================================================
    // TEST 2: Cannot redeem NFT without 100% of fractions.
    // =====================================================
    function testCannotRedeemWithPartialFractions() public {
        vm.prank(alice);
        address vaultAddress = factory.createVault(
            address(nft), 1, TOTAL_FRACTIONS, "fMAPE", "fMAPE"
        );

        FractionalizerVault vault = FractionalizerVault(vaultAddress);
        FractionToken fractionToken = vault.fractionToken();

        vm.startPrank(alice);
        nft.approve(vaultAddress, 1);
        vault.fractionalize();
        vm.stopPrank();

        // Whitelist Bob so Alice can transfer fractions to him.
        vm.prank(vaultAddress);
        fractionToken.vaultWhitelist(bob);

        vm.startPrank(alice);
        fractionToken.transfer(bob, TOTAL_FRACTIONS / 2);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert("You must hold 100% of the fractions to redeem");
        vault.redeem();

        console.log("TEST 2 PASSED: Cannot redeem with partial fractions");
    }

    // =====================================================
    // TEST 3: Cannot redeem twice.
    // =====================================================
    function testCannotDoubleRedeem() public {
        vm.prank(alice);
        address vaultAddress = factory.createVault(
            address(nft), 1, TOTAL_FRACTIONS, "fMAPE", "fMAPE"
        );

        FractionalizerVault vault = FractionalizerVault(vaultAddress);

        vm.startPrank(alice);
        nft.approve(vaultAddress, 1);
        vault.fractionalize();
        vault.redeem();
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert("Already redeemed");
        vault.redeem();

        console.log("TEST 3 PASSED: Cannot double redeem");
    }

    // =====================================================
    // TEST 4: Two stakers earn fairly proportional yield.
    // =====================================================
    function testFairYieldSplit() public {
        vm.prank(alice);
        address vaultAddress = factory.createVault(
            address(nft), 1, TOTAL_FRACTIONS, "fMAPE", "fMAPE"
        );
        FractionalizerVault vault = FractionalizerVault(vaultAddress);
        FractionToken fractionToken = vault.fractionToken();

        vm.startPrank(alice);
        nft.approve(vaultAddress, 1);
        vault.fractionalize();
        vm.stopPrank();

        // Whitelist Bob BEFORE transferring to him.
        vm.prank(vaultAddress);
        fractionToken.vaultWhitelist(bob);

        vm.prank(alice);
        fractionToken.transfer(bob, 2_500);

        MicroYieldStreamer streamer = new MicroYieldStreamer(
            address(fractionToken),
            address(sprinkleToken)
        );
        sprinkleToken.setStreamer(address(streamer));
        streamer.setRewardRate(1e18);

        // Whitelist Streamer for staking.
        vm.prank(vaultAddress);
        fractionToken.vaultWhitelist(address(streamer));

        vm.startPrank(alice);
        fractionToken.approve(address(streamer), 7_500);
        streamer.stake(7_500);
        vm.stopPrank();

        vm.startPrank(bob);
        fractionToken.approve(address(streamer), 2_500);
        streamer.stake(2_500);
        vm.stopPrank();

        skip(100);

        uint256 aliceEarned = streamer.earned(alice);
        uint256 bobEarned = streamer.earned(bob);

        console.log("Alice earned:", aliceEarned);
        console.log("Bob earned:", bobEarned);

        assertApproxEqAbs(aliceEarned, 75e18, 1e15, "Alice should earn 75%");
        assertApproxEqAbs(bobEarned, 25e18, 1e15, "Bob should earn 25%");

        console.log("TEST 4 PASSED: Fair yield split");
    }

    // =====================================================
    // TEST 5: Non-staker cannot claim yield.
    // =====================================================
    function testNonStakerCannotClaim() public {
        vm.prank(alice);
        address vaultAddress = factory.createVault(
            address(nft), 1, TOTAL_FRACTIONS, "fMAPE", "fMAPE"
        );
        FractionalizerVault vault = FractionalizerVault(vaultAddress);

        vm.startPrank(alice);
        nft.approve(vaultAddress, 1);
        vault.fractionalize();
        vm.stopPrank();

        MicroYieldStreamer streamer = new MicroYieldStreamer(
            address(vault.fractionToken()),
            address(sprinkleToken)
        );
        sprinkleToken.setStreamer(address(streamer));
        streamer.setRewardRate(1e18);

        vm.prank(attacker);
        streamer.claimYield();

        assertEq(sprinkleToken.balanceOf(attacker), 0, "Attacker should earn nothing");
        console.log("TEST 5 PASSED: Non-staker earns nothing");
    }

    // =====================================================
    // TEST 6: Random wallet cannot mint Sprinkle tokens.
    // =====================================================
    function testCannotMintSprinkle() public {
        vm.prank(attacker);
        vm.expectRevert("Only the Streamer can mint");
        sprinkleToken.mint(attacker, 1_000_000e18);

        console.log("TEST 6 PASSED: Cannot unauthorized mint");
    }
}
