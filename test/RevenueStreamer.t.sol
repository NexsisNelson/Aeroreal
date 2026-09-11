// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/RevenueStreamer.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @notice Mock fraction token for staking.
 */
contract MockFractionToken is ERC20 {
    constructor() ERC20("Mock Fraction", "mFRAC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @notice Mock stablecoin for revenue.
 */
contract MockStablecoinRS is ERC20 {
    constructor() ERC20("Mock USD", "mUSD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract RevenueStreamerTest is Test {

    MockFractionToken public fractionToken;
    MockStablecoinRS public usdc;
    RevenueStreamer public streamer;

    address public alice = address(uint160(0xA11CE));
    address public bob = address(uint160(0xB0B));
    address public vaultAddr = address(uint160(0x1234));

    uint256 constant TOTAL_FRACTIONS = 10_000e18;
    uint256 constant REVENUE_AMOUNT = 30_000e18; // 30,000 mUSD

    function setUp() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        // Deploy mock tokens.
        fractionToken = new MockFractionToken();
        usdc = new MockStablecoinRS();

        // Deploy streamer.
        streamer = new RevenueStreamer(
            address(fractionToken),
            address(usdc),
            vaultAddr
        );

        // Mint fractions to Alice and Bob.
        fractionToken.mint(alice, 10_000e18);
        fractionToken.mint(bob, 5_000e18);

        // Fund the test contract for revenue deposits.
        usdc.mint(address(this), 1_000_000e18);
    }

    // =========================================================
    // TEST 1: Metadata correct
    // =========================================================
    function testStreamerMetadata() public view {
        (
            address _staking,
            address _reward,
            address _vault,
            ,
            ,
            ,
            ,
        ) = streamer.getStreamerInfo();

        assertEq(_staking, address(fractionToken));
        assertEq(_reward, address(usdc));
        assertEq(_vault, vaultAddr);
    }

    // =========================================================
    // TEST 2: Deposit revenue increases reward rate
    // =========================================================
    function testDepositRevenue() public {
        usdc.approve(address(streamer), REVENUE_AMOUNT);
        streamer.depositRevenue(REVENUE_AMOUNT);

        uint256 rate = streamer.rewardRate();
        // 30,000 mUSD over 30 days = ~0.0115 mUSD/sec.
        assertGt(rate, 0);

        assertEq(streamer.lifetimeRevenueReceived(), REVENUE_AMOUNT);
        assertEq(usdc.balanceOf(address(streamer)), REVENUE_AMOUNT);
    }

    // =========================================================
    // TEST 3: Stake and earn over time
    // =========================================================
    function testStakeAndEarn() public {
        // Deposit revenue.
        usdc.approve(address(streamer), REVENUE_AMOUNT);
        streamer.depositRevenue(REVENUE_AMOUNT);

        // Alice stakes.
        vm.startPrank(alice);
        fractionToken.approve(address(streamer), TOTAL_FRACTIONS);
        streamer.stake(TOTAL_FRACTIONS);
        vm.stopPrank();

        // Fast forward 1 day.
        skip(1 days);

        uint256 earned = streamer.earned(alice);
        assertGt(earned, 0, "Alice should have earned something");

        console.log("Alice earned after 1 day:", earned);
    }

    // =========================================================
    // TEST 4: Claim yield (real stablecoins)
    // =========================================================
    function testClaimYield() public {
        usdc.approve(address(streamer), REVENUE_AMOUNT);
        streamer.depositRevenue(REVENUE_AMOUNT);

        vm.startPrank(alice);
        fractionToken.approve(address(streamer), TOTAL_FRACTIONS);
        streamer.stake(TOTAL_FRACTIONS);
        vm.stopPrank();

        skip(1 days);

        uint256 balanceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        streamer.claimYield();

        uint256 balanceAfter = usdc.balanceOf(alice);
        assertGt(balanceAfter, balanceBefore, "Alice should have received yield");

        console.log("Alice received:", balanceAfter - balanceBefore);
    }

    // =========================================================
    // TEST 5: Two stakers split proportionally
    // =========================================================
    function testProportionalSplit() public {
        usdc.approve(address(streamer), REVENUE_AMOUNT);
        streamer.depositRevenue(REVENUE_AMOUNT);

        // Alice stakes 10,000. Bob stakes 5,000. Ratio: 2:1.
        vm.startPrank(alice);
        fractionToken.approve(address(streamer), 10_000e18);
        streamer.stake(10_000e18);
        vm.stopPrank();

        vm.startPrank(bob);
        fractionToken.approve(address(streamer), 5_000e18);
        streamer.stake(5_000e18);
        vm.stopPrank();

        skip(1 days);

        uint256 aliceEarned = streamer.earned(alice);
        uint256 bobEarned = streamer.earned(bob);

        console.log("Alice earned:", aliceEarned);
        console.log("Bob earned:", bobEarned);

        // Alice should have ~2x Bob's earnings.
        assertApproxEqRel(aliceEarned, bobEarned * 2, 0.01e18);
    }

    // =========================================================
    // TEST 6: Cannot claim without staking
    // =========================================================
    function testNonStakerCannotClaim() public {
        usdc.approve(address(streamer), REVENUE_AMOUNT);
        streamer.depositRevenue(REVENUE_AMOUNT);

        // Alice never staked. Try to claim.
        vm.prank(alice);
        vm.expectRevert("Nothing to claim");
        streamer.claimYield();
    }

    // =========================================================
    // TEST 7: Withdraw works
    // =========================================================
    function testWithdraw() public {
        vm.startPrank(alice);
        fractionToken.approve(address(streamer), TOTAL_FRACTIONS);
        streamer.stake(TOTAL_FRACTIONS);

        uint256 balanceBefore = fractionToken.balanceOf(alice);
        assertEq(balanceBefore, 0);

        streamer.withdraw(TOTAL_FRACTIONS);

        uint256 balanceAfter = fractionToken.balanceOf(alice);
        assertEq(balanceAfter, TOTAL_FRACTIONS);

        vm.stopPrank();

        console.log("Alice withdrew all fractions");
    }
}
