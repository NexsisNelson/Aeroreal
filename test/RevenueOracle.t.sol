// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/RevenueOracle.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @notice Mock stablecoin for revenue testing (mimics USDC/cNGN).
 */
contract MockStablecoinOracle is ERC20 {
    constructor() ERC20("Mock USD", "mUSD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract RevenueOracleTest is Test {

    RevenueOracle public oracle;
    MockStablecoinOracle public usdc;

    address public owner = address(this);
    address public reporter = address(0x0E9);
    address public vault1 = address(0x1111);
    address public vault2 = address(0x2222);
    address public streamer = address(0x5757);

    function setUp() public {
        usdc = new MockStablecoinOracle();
        oracle = new RevenueOracle(address(usdc));

        // Add the reporter.
        oracle.addReporter(reporter);

        // Fund the reporter with stablecoins.
        usdc.mint(reporter, 1_000_000e18);
    }

    function testAddReporter() public {
        assertTrue(oracle.reporters(reporter));
        console.log("TEST: Reporter added");
    }

    function testRemoveReporter() public {
        oracle.removeReporter(reporter);
        assertFalse(oracle.reporters(reporter));
        console.log("TEST: Reporter removed");
    }

    function testReportRevenue() public {
        uint256 amount = 10_000e18;

        vm.startPrank(reporter);
        usdc.approve(address(oracle), amount);
        oracle.reportRevenue(vault1, amount, "Rent");
        vm.stopPrank();

        assertEq(oracle.vaultRevenue(vault1), amount);
        assertEq(oracle.totalRevenueReported(), amount);
        assertEq(usdc.balanceOf(address(oracle)), amount);

        console.log("TEST: Revenue reported for vault1:", amount);
    }

    function testReportMultipleVaults() public {
        vm.startPrank(reporter);
        usdc.approve(address(oracle), 100_000e18);

        oracle.reportRevenue(vault1, 10_000e18, "Rent");
        oracle.reportRevenue(vault2, 5_000e18, "InvoiceRepayment");
        oracle.reportRevenue(vault1, 3_000e18, "Rent");
        vm.stopPrank();

        assertEq(oracle.vaultRevenue(vault1), 13_000e18);
        assertEq(oracle.vaultRevenue(vault2), 5_000e18);
        assertEq(oracle.totalRevenueReported(), 18_000e18);

        console.log("TEST: Multiple vault revenues tracked correctly");
    }

    function testWithdrawRevenue() public {
        uint256 amount = 10_000e18;

        vm.startPrank(reporter);
        usdc.approve(address(oracle), amount);
        oracle.reportRevenue(vault1, amount, "Rent");
        oracle.withdrawRevenue(vault1, streamer, amount);
        vm.stopPrank();

        assertEq(oracle.vaultRevenue(vault1), 0);
        assertEq(usdc.balanceOf(streamer), amount);

        console.log("TEST: Revenue withdrawn to streamer");
    }

    function testCannotWithdrawMoreThanReported() public {
        vm.startPrank(reporter);
        usdc.approve(address(oracle), 10_000e18);
        oracle.reportRevenue(vault1, 5_000e18, "Rent");

        vm.expectRevert("Insufficient vault revenue");
        oracle.withdrawRevenue(vault1, streamer, 10_000e18);
        vm.stopPrank();

        console.log("TEST: Cannot withdraw more than reported");
    }

    function testNonReporterCannotReport() public {
        uint256 amount = 1_000e18;

        // Attacker tries to report revenue.
        usdc.mint(address(0xBAD), amount);

        vm.startPrank(address(0xBAD));
        usdc.approve(address(oracle), amount);
        vm.expectRevert("Not a reporter");
        oracle.reportRevenue(vault1, amount, "Fake");
        vm.stopPrank();

        console.log("TEST: Non-reporter cannot report");
    }
}
