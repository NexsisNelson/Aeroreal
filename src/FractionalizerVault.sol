// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./FractionToken.sol";

/**
 * @title FractionalizerVault
 * @notice This is the Magic Cookie Cutter.
 * It locks an NFT and mints FractionTokens in exchange.
 */
contract FractionalizerVault is ERC721Holder, ReentrancyGuard {

	using SafeERC20 for IERC20;

	// ---- The Big Asset being locked ----
	address public nftContract;  // The address of the NFT collection (e.g., BAYC)
	uint256 public nftTokenId;   // The specific NFT ID (e.g., #4412)

	// ---- The Tiny Pieces handed out ----
	FractionToken public fractionToken;

	// ---- Ownership ----
	address public owner;

	// ---- Total number of tiny pieces to mint (e.g., 10,000) ----
	uint256 public totalFractions;

	// ---- Track if the NFT has been redeemed (all pieces returned) ----
	bool public isRedeemed;

	// ---- Events for the Flutter app ----
	event Fractionalized(address indexed user, uint256 totalSupply);
	event Redeemed(address indexed user, uint256 nftId);

	modifier onlyOwner() {
		require(msg.sender == owner, "Not the owner");
		_;
	}

	/**
	 * @notice Deploying the Vault deploys a new FractionToken alongside it.
	 * @param _nftContract The NFT collection address.
	 * @param _nftTokenId The specific NFT id being locked.
	 * @param _totalFractions How many tiny pieces to mint (e.g., 10000).
	 * @param _name Name of the fraction token, e.g., "Fractionalized Ape".
	 * @param _symbol Ticker, e.g., "fAPE".
	 */
	constructor(
		address _nftContract,
		uint256 _nftTokenId,
		uint256 _totalFractions,
		string memory _name,
		string memory _symbol
	) {
		require(_totalFractions > 0, "Must mint at least 1 fraction");

		nftContract = _nftContract;
		nftTokenId = _nftTokenId;
		totalFractions = _totalFractions;
		owner = msg.sender;

		// Deploy a brand new FractionToken for this specific NFT.
		fractionToken = new FractionToken(
			_name,
			_symbol,
			"NFT",
			"Global",
			""
		);

		// Tell the FractionToken that ONLY THIS VAULT can mint/burn it.
		fractionToken.setVault(address(this));
	}

	/**
	 * @notice Locks the NFT in the vault and mints FractionTokens to the caller.
	 * @dev The caller MUST call nft.approve(vaultAddress, tokenId) FIRST.
	 */
	function fractionalize() external nonReentrant {
		require(!isRedeemed, "Already redeemed");
		require(fractionToken.totalSupply() == 0, "Already fractionalized");

		// 1. Pull the NFT from the user into this vault.
		IERC721(nftContract).safeTransferFrom(
			msg.sender,
			address(this),
			nftTokenId
		);

		// 2. Mint the tiny pieces to the user who deposited.
		fractionToken.addToWhitelist(msg.sender);
		fractionToken.mint(msg.sender, totalFractions);

		emit Fractionalized(msg.sender, totalFractions);
	}

	/**
	 * @notice If a user collects 100% of the FractionTokens, they can redeem the NFT.
	 * @dev This burns ALL the fractions held by the caller and returns the NFT.
	 */
	function redeem() external nonReentrant {
		require(!isRedeemed, "Already redeemed");

		// 1. Verify the caller holds 100% of the supply.
		uint256 userBalance = fractionToken.balanceOf(msg.sender);
		require(
			userBalance == totalFractions,
			"You must hold 100% of the fractions to redeem"
		);

		// 2. Mark as redeemed to prevent re-entrancy.
		isRedeemed = true;

		// 3. Burn all the tiny pieces.
		fractionToken.burn(msg.sender, totalFractions);

		// 4. Send the NFT back to the user.
		IERC721(nftContract).safeTransferFrom(
			address(this),
			msg.sender,
			nftTokenId
		);

		emit Redeemed(msg.sender, nftTokenId);
	}

	/**
	 * @notice Read helper for the Flutter app.
	 */
	function getVaultInfo() external view returns (
		address _nftContract,
		uint256 _nftId,
		address _fractionToken,
		uint256 _totalFractions,
		bool _isRedeemed
	) {
		return (
			nftContract,
			nftTokenId,
			address(fractionToken),
			totalFractions,
			isRedeemed
		);
	}
}
