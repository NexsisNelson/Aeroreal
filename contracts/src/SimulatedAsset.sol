// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimulatedAsset
 * @notice A simulated asset token whose price is updated by an off-chain
 *         oracle. Used for the Aeroreal testnet sandbox. Has no real value.
 */
contract SimulatedAsset is ERC20, Ownable {
    string public underlyingSymbol;
    uint256 public currentPriceUsd;
    address public priceOracle;
    bool public tradingEnabled;

    event PriceUpdated(uint256 newPrice, uint256 timestamp);
    event TradingEnabled(bool enabled);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _underlyingSymbol,
        address _priceOracle,
        uint256 _initialPriceUsd
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        require(_priceOracle != address(0), "Invalid oracle");
        underlyingSymbol = _underlyingSymbol;
        priceOracle = _priceOracle;
        currentPriceUsd = _initialPriceUsd;
        tradingEnabled = true;
    }

    function updatePrice(uint256 _newPrice) external {
        require(msg.sender == priceOracle, "Only oracle");
        require(_newPrice > 0, "Invalid price");
        currentPriceUsd = _newPrice;
        emit PriceUpdated(_newPrice, block.timestamp);
    }

    function setPriceOracle(address _newOracle) external onlyOwner {
        require(_newOracle != address(0), "Invalid oracle");
        priceOracle = _newOracle;
    }

    function setTradingEnabled(bool _enabled) external onlyOwner {
        tradingEnabled = _enabled;
        emit TradingEnabled(_enabled);
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyOwner {
        _burn(_from, _amount);
    }
}
