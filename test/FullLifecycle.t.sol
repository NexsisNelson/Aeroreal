// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/FractionFactory.sol";
import "../src/MicroYieldStreamer.sol";
import "../src/YieldRewardToken.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @notice A simple mock NFT for testing purposes.
 */
contract MockNFT is ERC721 {
    uint256 private _nextId = 1;

    constructor() ERC721("Mock Ape", "MAPE") {}

    function mint(address to) external returns (uint256) {
        uint256 id = _nextId++;
        _mint(to, id);
        return id;
    }
}

/**
 * @title FullLifecycleTest
 * @notice Simulates the entire user journey from deposit to redeem.
 */
contract FullLifecycleTest is Test {

    // ---- Our Contracts ----
    MockNFT public nft;
    FractionFactory public factory;
    YieldRewardToken public sprinkleToken;

    // ---- Our Users ----
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    // ---- Test constants ----
    uint256 public constant TOTAL_FRACTIONS = 10_000;

    function setUp() public {
        // 1. Give Alice some ETH to pay for gas.
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        // 2. Deploy the Mock NFT.
        nft = new MockNFT();

        // 3. Deploy the Sprinkle (reward) token.
        // The test contract is the initial owner.
        sprinkleToken = new YieldRewardToken("Micro Sprinkle", "SPR");

        // 4. Deploy the Factory.
        factory = new FractionFactory();

        // 5. Mint an NFT to Alice (id = 1).
        vm.prank(alice);
        nft.mint(alice);
    }

    function testFullLifecycle() public {
        // =====================================================
        // STEP 1: Alice creates a Vault for her NFT.
        // =====================================================
        vm.prank(alice);
        address vaultAddress = factory.createVault(
            address(nft),
            1,
            TOTAL_FRACTIONS,
            "Fractionalized Mock Ape",
            "fMAPE"
        );

        FractionalizerVault vault = FractionalizerVault(vaultAddress);
        FractionToken fractionToken = vault.fractionToken();

        assertEq(fractionToken.totalSupply(), 0, "Supply should start at 0");
        console.log("Vault created at:", vaultAddress);

        // =====================================================
        // STEP 2: Alice approves and fractionalizes her NFT.
        // =====================================================
        vm.startPrank(alice);
        nft.approve(vaultAddress, 1);
        vault.fractionalize();
        vm.stopPrank();

        assertEq(fractionToken.balanceOf(alice), TOTAL_FRACTIONS, "Alice should own all fractions");
        assertEq(nft.ownerOf(1), vaultAddress, "NFT should be locked in vault");
        console.log("Alice owns", fractionToken.balanceOf(alice), "fractions");

        // =====================================================
        // STEP 3: Deploy the MicroYieldStreamer.
        // =====================================================
        MicroYieldStreamer streamer = new MicroYieldStreamer(
            address(fractionToken),
            address(sprinkleToken)
        );

        // The test contract owns the Sprinkle token. Transfer ownership
        // is not needed because the streamer calls setStreamer, but the
        // streamer must be set by the OWNER. Let's transfer ownership
        // of sprinkleToken to the streamer so it can mint.
        // Actually, our YieldRewardToken.setStreamer is onlyOwner.
        // The test contract is the owner. We can call it directly.
        sprinkleToken.setStreamer(address(streamer));

        // =====================================================
        // STEP 4: Alice stakes her fractions.
        // =====================================================
        vm.startPrank(alice);
        fractionToken.approve(address(streamer), TOTAL_FRACTIONS);
        streamer.stake(TOTAL_FRACTIONS);
        vm.stopPrank();

        assertEq(streamer.totalStaked(), TOTAL_FRACTIONS, "Streamer should have all fractions");
        console.log("Alice staked", TOTAL_FRACTIONS, "fractions");

        // =====================================================
        // STEP 5: Set the drip rate. 1 Sprinkle per second.
        // =====================================================
        // Only the owner (this test contract) can call this.
        streamer.setRewardRate(1e18);
        console.log("Reward rate set to 1 SPR/sec");

        // =====================================================
        // STEP 6: Fast forward time by 100 seconds.
        // =====================================================
        skip(100);

        uint256 pending = streamer.earned(alice);
        console.log("After 100 seconds, Alice has earned:", pending);
        assertEq(pending, 100e18, "Alice should have earned 100 SPR");

        // =====================================================
        // STEP 7: Alice claims her yield.
        // =====================================================
        vm.prank(alice);
        streamer.claimYield();

        assertEq(sprinkleToken.balanceOf(alice), 100e18, "Alice should have 100 SPR");
        console.log("Alice claimed", sprinkleToken.balanceOf(alice), "SPR");

        // =====================================================
        // STEP 8: Alice withdraws her fractions.
        // =====================================================
        vm.prank(alice);
        streamer.withdraw(TOTAL_FRACTIONS);

        assertEq(fractionToken.balanceOf(alice), TOTAL_FRACTIONS, "Alice got fractions back");

        // =====================================================
        // STEP 9: Alice redeems the NFT.
        // =====================================================
        vm.prank(alice);
        vault.redeem();

        assertEq(nft.ownerOf(1), alice, "Alice should own the NFT again");
        assertEq(fractionToken.balanceOf(alice), 0, "Fractions should be burned");
        console.log("SUCCESS: Alice redeemed the NFT and the full cycle is complete!");
    }
}
