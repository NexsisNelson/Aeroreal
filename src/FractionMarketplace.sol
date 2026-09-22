// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FractionMarketplace
 * @notice A peer-to-peer marketplace for trading fraction tokens.
 *         Listed fractions are held in escrow until purchase or cancellation.
 */
contract FractionMarketplace is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable paymentToken;

    struct Listing {
        address seller;
        address fractionToken;
        uint256 amount;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId = 1;
    uint256 public activeListingCount;
    uint256 public feeBps = 100;
    address public feeRecipient;

    event Listed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed fractionToken,
        uint256 amount,
        uint256 price
    );
    event Purchased(uint256 indexed listingId, address indexed buyer, uint256 price);
    event Cancelled(uint256 indexed listingId);

    constructor(address paymentTokenAddress) Ownable(msg.sender) {
        require(paymentTokenAddress != address(0), "Invalid payment token");
        paymentToken = IERC20(paymentTokenAddress);
        feeRecipient = msg.sender;
    }

    function list(
        address fractionToken,
        uint256 amount,
        uint256 price
    ) external nonReentrant returns (uint256) {
        require(fractionToken != address(0), "Invalid fraction token");
        require(amount > 0, "Amount must be > 0");
        require(price > 0, "Price must be > 0");

        IERC20(fractionToken).safeTransferFrom(msg.sender, address(this), amount);

        uint256 listingId = nextListingId++;
        listings[listingId] = Listing({
            seller: msg.sender,
            fractionToken: fractionToken,
            amount: amount,
            price: price,
            active: true
        });
        activeListingCount++;

        emit Listed(listingId, msg.sender, fractionToken, amount, price);
        return listingId;
    }

    function buy(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Not active");
        require(listing.seller != msg.sender, "Cannot buy own listing");

        uint256 fee = (listing.price * feeBps) / 10000;
        paymentToken.safeTransferFrom(msg.sender, listing.seller, listing.price - fee);
        if (fee > 0) paymentToken.safeTransferFrom(msg.sender, feeRecipient, fee);
        IERC20(listing.fractionToken).safeTransfer(msg.sender, listing.amount);

        listing.active = false;
        activeListingCount--;
        emit Purchased(listingId, msg.sender, listing.price);
    }

    function cancel(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Not active");
        require(listing.seller == msg.sender, "Not the seller");

        listing.active = false;
        activeListingCount--;
        IERC20(listing.fractionToken).safeTransfer(listing.seller, listing.amount);
        emit Cancelled(listingId);
    }

    function setFee(uint256 feeBpsValue) external onlyOwner {
        require(feeBpsValue <= 1000, "Max 10%");
        feeBps = feeBpsValue;
    }

    function setFeeRecipient(address recipient) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        feeRecipient = recipient;
    }

    function getListing(uint256 listingId)
        external
        view
        returns (
            address seller,
            address fractionToken,
            uint256 amount,
            uint256 price,
            bool active
        )
    {
        Listing storage listing = listings[listingId];
        return (
            listing.seller,
            listing.fractionToken,
            listing.amount,
            listing.price,
            listing.active
        );
    }
}