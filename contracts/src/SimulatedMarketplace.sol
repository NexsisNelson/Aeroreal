// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SimulatedAsset.sol";

/**
 * @title SimulatedMarketplace
 * @notice Buy and sell simulated assets using AREAL.
 *         Prices are pulled from each SimulatedAsset's oracle.
 */
contract SimulatedMarketplace is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable areal;
    uint256 public feeBps = 100;
    address public feeRecipient;

    event Bought(address indexed buyer, address indexed asset, uint256 amount, uint256 arealCost);
    event Sold(address indexed seller, address indexed asset, uint256 amount, uint256 arealProceeds);

    constructor(address _areal) Ownable(msg.sender) {
        require(_areal != address(0), "Invalid AREAL");
        areal = IERC20(_areal);
        feeRecipient = msg.sender;
    }

    function buy(address _asset, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be > 0");

        SimulatedAsset sim = SimulatedAsset(_asset);
        require(sim.tradingEnabled(), "Trading disabled");

        uint256 cost = (sim.currentPriceUsd() * _amount) / 1e18;
        uint256 fee = Math.mulDiv(cost, feeBps, 10000);
        uint256 totalCost = cost + fee;

        areal.safeTransferFrom(msg.sender, address(this), totalCost);
        if (fee > 0) {
            areal.safeTransfer(feeRecipient, fee);
        }

        sim.mint(msg.sender, _amount);
        emit Bought(msg.sender, _asset, _amount, totalCost);
    }

    function sell(address _asset, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be > 0");

        SimulatedAsset sim = SimulatedAsset(_asset);
        require(sim.tradingEnabled(), "Trading disabled");

        uint256 proceeds = (sim.currentPriceUsd() * _amount) / 1e18;
        uint256 fee = Math.mulDiv(proceeds, feeBps, 10000);
        uint256 netProceeds = proceeds - fee;

        sim.burn(msg.sender, _amount);
        areal.safeTransfer(msg.sender, netProceeds);
        if (fee > 0) {
            areal.safeTransfer(feeRecipient, fee);
        }

        emit Sold(msg.sender, _asset, _amount, netProceeds);
    }

    function claimAssetOwnership(address _asset) external onlyOwner {
        SimulatedAsset(_asset).transferOwnership(address(this));
    }

    function setFee(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 1000, "Max 10%");
        feeBps = _feeBps;
    }

    function setFeeRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "Invalid recipient");
        feeRecipient = _recipient;
    }
}
