// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./FractionToken.sol";

/**
 * @title FaucetFractionToken
 * @notice A FractionToken variant that allows a designated Faucet contract
 *         to mint testnet fractions without requiring pre-funding of the faucet.
 */
contract FaucetFractionToken is FractionToken {
    address public faucet;

    event FaucetSet(address indexed faucet);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _assetType,
        string memory _jurisdiction,
        string memory _legalDocumentURI
    ) FractionToken(_name, _symbol, _assetType, _jurisdiction, _legalDocumentURI) {}

    function setFaucet(address _faucet) external onlyOwner {
        require(_faucet != address(0), "Zero address not allowed");
        faucet = _faucet;
        emit FaucetSet(_faucet);
    }

    function faucetMint(address _to, uint256 _amount) external {
        require(msg.sender == faucet, "Only Faucet");

        _mint(_to, _amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (whitelistEnabled && (msg.sender == vault || msg.sender == faucet)) {
            ERC20._update(from, to, value);
            return;
        }

        if (whitelistEnabled) {
            if (from != address(0)) {
                require(whitelisted[from] || from == faucet, "Sender not whitelisted");
            }
            if (to != address(0)) {
                require(whitelisted[to] || to == faucet || msg.sender == faucet, "Recipient not whitelisted");
            }
        }
        super._update(from, to, value);
    }
}
