// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";
import "../src/FractionMarketplace.sol";

contract MarketplaceToken is ERC20 {
    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FractionMarketplaceTest is Test {
    MarketplaceToken public paymentToken;
    MarketplaceToken public fractionToken;
    FractionMarketplace public marketplace;

    address public seller = address(0x1);
    address public buyer = address(0x2);
    address public feeRecipient = address(0x3);

    uint256 public constant FRACTIONS = 1_000 ether;
    uint256 public constant PRICE = 500 ether;

    function setUp() public {
        paymentToken = new MarketplaceToken("Mock USD", "mUSD");
        fractionToken = new MarketplaceToken("Fraction", "FRAC");
        marketplace = new FractionMarketplace(address(paymentToken));

        fractionToken.mint(seller, FRACTIONS);
        paymentToken.mint(buyer, PRICE);

        vm.prank(seller);
        fractionToken.approve(address(marketplace), FRACTIONS);
        vm.prank(buyer);
        paymentToken.approve(address(marketplace), PRICE);
    }

    function testListEscrowsFractions() public {
        vm.prank(seller);
        uint256 listingId = marketplace.list(address(fractionToken), FRACTIONS, PRICE);

        assertEq(listingId, 1);
        assertEq(fractionToken.balanceOf(seller), 0);
        assertEq(fractionToken.balanceOf(address(marketplace)), FRACTIONS);
        assertEq(marketplace.activeListingCount(), 1);
    }

    function testBuyTransfersFractionsAndSplitsFee() public {
        vm.prank(seller);
        uint256 listingId = marketplace.list(address(fractionToken), FRACTIONS, PRICE);
        marketplace.setFeeRecipient(feeRecipient);

        vm.prank(buyer);
        marketplace.buy(listingId);

        assertEq(fractionToken.balanceOf(buyer), FRACTIONS);
        assertEq(fractionToken.balanceOf(address(marketplace)), 0);
        assertEq(paymentToken.balanceOf(seller), 495 ether);
        assertEq(paymentToken.balanceOf(feeRecipient), 5 ether);
        assertEq(marketplace.activeListingCount(), 0);
        (, , , , bool active) = marketplace.getListing(listingId);
        assertFalse(active);
    }

    function testCancelReturnsEscrowedFractions() public {
        vm.prank(seller);
        uint256 listingId = marketplace.list(address(fractionToken), FRACTIONS, PRICE);

        vm.prank(seller);
        marketplace.cancel(listingId);

        assertEq(fractionToken.balanceOf(seller), FRACTIONS);
        assertEq(fractionToken.balanceOf(address(marketplace)), 0);
        assertEq(marketplace.activeListingCount(), 0);
    }

    function testCannotBuyOwnListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.list(address(fractionToken), FRACTIONS, PRICE);

        vm.prank(seller);
        vm.expectRevert("Cannot buy own listing");
        marketplace.buy(listingId);
    }

    function testCannotCancelAnotherSellersListing() public {
        vm.prank(seller);
        uint256 listingId = marketplace.list(address(fractionToken), FRACTIONS, PRICE);

        vm.prank(buyer);
        vm.expectRevert("Not the seller");
        marketplace.cancel(listingId);
    }
}