// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./FractionalizerVault.sol";

/**
 * @title FractionFactory
 * @notice The Vending Machine. Anyone can call this to create a new Vault.
 * It deploys a new FractionalizerVault and automatically registers it.
 */
contract FractionFactory {

	// ---- A master list of every Vault ever created ----
	address[] public allVaults;

	// ---- Maps a specific NFT to its Vault (so we don't have duplicates) ----
	// e.g., nftContract => nftTokenId => vaultAddress
	mapping(address => mapping(uint256 => address)) public vaultForNFT;

	// ---- Owner of the factory ----
	address public owner;

	// ---- Events for the Flutter app ----
	event VaultCreated(
		address indexed vault,
		address indexed nftContract,
		uint256 indexed nftTokenId,
		address fractionToken,
		uint256 totalFractions,
		address creator
	);

	modifier onlyOwner() {
		require(msg.sender == owner, "Not the owner");
		_;
	}

	constructor() {
		owner = msg.sender;
	}

	/**
	 * @notice The main function. Creates a brand new Vault for an NFT.
	 * @param _nftContract The NFT collection address.
	 * @param _nftTokenId The specific NFT id.
	 * @param _totalFractions How many tiny pieces to mint.
	 * @param _name Name of the fraction token, e.g., "Fractionalized Ape".
	 * @param _symbol Ticker, e.g., "fAPE".
	 * @return vault The address of the newly created vault.
	 */
	function createVault(
		address _nftContract,
		uint256 _nftTokenId,
		uint256 _totalFractions,
		string memory _name,
		string memory _symbol
	) external returns (address vault) {
		require(_nftContract != address(0), "Invalid NFT contract");
		require(_totalFractions > 0, "Fractions must be > 0");
		require(
			vaultForNFT[_nftContract][_nftTokenId] == address(0),
			"This NFT is already fractionalized"
		);

		// 1. Deploy a brand new Vault from the FractionalizerVault blueprint.
		FractionalizerVault newVault = new FractionalizerVault(
			_nftContract,
			_nftTokenId,
			_totalFractions,
			_name,
			_symbol
		);

		vault = address(newVault);

		// 2. Register the vault in our master list.
		allVaults.push(vault);
		vaultForNFT[_nftContract][_nftTokenId] = vault;

		// 3. Emit an event so the Flutter app hears about it in real time.
		emit VaultCreated(
			vault,
			_nftContract,
			_nftTokenId,
			address(newVault.fractionToken()),
			_totalFractions,
			msg.sender
		);
	}

	/**
	 * @notice Read helper for the Flutter app: How many vaults exist?
	 */
	function getVaultCount() external view returns (uint256) {
		return allVaults.length;
	}

	/**
	 * @notice Read helper: Get a list of vaults (paged to avoid gas issues).
	 * @param _start Starting index.
	 * @param _end Ending index.
	 */
	function getVaults(uint256 _start, uint256 _end)
		external
		view
		returns (address[] memory)
	{
		require(_end <= allVaults.length, "Out of bounds");
		require(_start < _end, "Invalid range");

		address[] memory result = new address[](_end - _start);
		for (uint256 i = _start; i < _end; i++) {
			result[i - _start] = allVaults[i];
		}
		return result;
	}
}
