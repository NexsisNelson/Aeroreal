// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMintableERC20 {
    function mint(address to, uint256 amount) external;
}

interface IFaucetFractionToken {
    function faucetMint(address to, uint256 amount) external;
}

interface IDemoNFT {
    function mint(address to) external returns (uint256);
}

/**
 * @title Faucet
 * @notice Public testnet faucet. Any wallet can claim once every 24 hours.
 *         Mints mUSD, mints fGOLD and fCOFFEE, and mints a Demo NFT.
 */
contract Faucet is ReentrancyGuard, Ownable {
    IMintableERC20 public immutable musd;
    IFaucetFractionToken public immutable fGold;
    IFaucetFractionToken public immutable fCoffee;
    IDemoNFT public immutable demoNft;

    uint256 public musdAmount = 10_000 * 1e18;
    uint256 public fGoldAmount = 1_000 * 1e18;
    uint256 public fCoffeeAmount = 1_000 * 1e18;
    uint256 public constant CLAIM_COOLDOWN = 24 hours;

    mapping(address => uint256) public lastClaimAt;
    uint256 public totalClaims;

    event Claimed(
        address indexed wallet, uint256 musdAmount, uint256 fGoldAmount, uint256 fCoffeeAmount, uint256 nftTokenId
    );

    constructor(address _musd, address _fGold, address _fCoffee, address _demoNft) Ownable(msg.sender) {
        musd = IMintableERC20(_musd);
        fGold = IFaucetFractionToken(_fGold);
        fCoffee = IFaucetFractionToken(_fCoffee);
        demoNft = IDemoNFT(_demoNft);
    }

    function claim() external nonReentrant {
        uint256 last = lastClaimAt[msg.sender];
        require(last == 0 || block.timestamp >= last + CLAIM_COOLDOWN, "Already claimed in the last 24 hours");

        musd.mint(msg.sender, musdAmount);
        fGold.faucetMint(msg.sender, fGoldAmount);
        fCoffee.faucetMint(msg.sender, fCoffeeAmount);

        uint256 tokenId = demoNft.mint(msg.sender);

        lastClaimAt[msg.sender] = block.timestamp;
        totalClaims++;

        emit Claimed(msg.sender, musdAmount, fGoldAmount, fCoffeeAmount, tokenId);
    }

    function timeUntilClaim(address wallet) external view returns (uint256) {
        uint256 last = lastClaimAt[wallet];
        if (last == 0) return 0;
        uint256 next = last + CLAIM_COOLDOWN;
        if (block.timestamp >= next) return 0;
        return next - block.timestamp;
    }

    function setAmounts(uint256 _musdAmount, uint256 _fGoldAmount, uint256 _fCoffeeAmount) external onlyOwner {
        musdAmount = _musdAmount;
        fGoldAmount = _fGoldAmount;
        fCoffeeAmount = _fCoffeeAmount;
    }
}
