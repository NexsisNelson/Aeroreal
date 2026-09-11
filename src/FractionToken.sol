// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FractionToken
 * @notice The "Tiny Piece" of a big asset. Now with compliance whitelist
 *         for real-world asset (RWA) tokenization.
 */
contract FractionToken is ERC20, Ownable {

	address public vault;
	string public assetType;
	string public jurisdiction;
	string public legalDocumentURI;
	bool public whitelistEnabled;
	mapping(address => bool) public whitelisted;

	event VaultSet(address indexed vault);
	event WhitelistEnabledChanged(bool enabled);
	event WalletWhitelisted(address indexed wallet);
	event WalletRemoved(address indexed wallet);
	event AssetMetadataSet(
		string assetType,
		string jurisdiction,
		string legalDocumentURI
	);

	constructor(
		string memory _name,
		string memory _symbol,
		string memory _assetType,
		string memory _jurisdiction,
		string memory _legalDocumentURI
	)
		ERC20(_name, _symbol)
		Ownable(msg.sender)
	{
		assetType = _assetType;
		jurisdiction = _jurisdiction;
		legalDocumentURI = _legalDocumentURI;
		whitelistEnabled = true;
		emit AssetMetadataSet(_assetType, _jurisdiction, _legalDocumentURI);
	}

	function setVault(address _vault) external onlyOwner {
		require(_vault != address(0), "Zero address not allowed");
		vault = _vault;
		emit VaultSet(_vault);
	}

	function setWhitelistEnabled(bool _enabled) external onlyOwner {
		whitelistEnabled = _enabled;
		emit WhitelistEnabledChanged(_enabled);
	}

	function addToWhitelist(address _wallet) external onlyOwner {
		require(_wallet != address(0), "Zero address not allowed");
		whitelisted[_wallet] = true;
		emit WalletWhitelisted(_wallet);
	}

	function addBatchToWhitelist(address[] calldata _wallets) external onlyOwner {
		for (uint256 i = 0; i < _wallets.length; i++) {
			if (_wallets[i] != address(0)) {
				whitelisted[_wallets[i]] = true;
				emit WalletWhitelisted(_wallets[i]);
			}
		}
	}

	function removeFromWhitelist(address _wallet) external onlyOwner {
		whitelisted[_wallet] = false;
		emit WalletRemoved(_wallet);
	}

	function updateMetadata(
		string memory _assetType,
		string memory _jurisdiction,
		string memory _legalDocumentURI
	) external onlyOwner {
		assetType = _assetType;
		jurisdiction = _jurisdiction;
		legalDocumentURI = _legalDocumentURI;
		emit AssetMetadataSet(_assetType, _jurisdiction, _legalDocumentURI);
	}

	function mint(address _to, uint256 _amount) external {
		require(msg.sender == vault, "Only the Vault can mint");
		require(!whitelistEnabled || whitelisted[_to], "Recipient not whitelisted");
		_mint(_to, _amount);
	}

	function burn(address _from, uint256 _amount) external {
		require(msg.sender == vault, "Only the Vault can burn");
		_burn(_from, _amount);
	}

	function _update(
		address from,
		address to,
		uint256 value
	) internal override {
		if (whitelistEnabled) {
			if (from != address(0)) {
				require(whitelisted[from], "Sender not whitelisted");
			}
			if (to != address(0)) {
				require(whitelisted[to], "Recipient not whitelisted");
			}
		}
		super._update(from, to, value);
	}
}
