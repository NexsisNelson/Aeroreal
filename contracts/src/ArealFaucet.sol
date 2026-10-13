// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IArealMintable {
    function faucetMint(address to, uint256 amount) external;
}

contract ArealFaucet is ReentrancyGuard, Ownable {
    IArealMintable public immutable areal;

    uint256 public claimAmount = 100_000 * 1e18;
    uint256 public constant CLAIM_COOLDOWN = 24 hours;

    mapping(address => uint256) public lastClaimAt;
    uint256 public totalClaims;

    event Claimed(address indexed wallet, uint256 amount);

    constructor(address _areal) Ownable(msg.sender) {
        require(_areal != address(0), "Invalid AREAL");
        areal = IArealMintable(_areal);
    }

    function claim() external nonReentrant {
        uint256 last = lastClaimAt[msg.sender];
        // Enforce a single one-time claim per wallet.
        require(last == 0, "Already claimed");

        lastClaimAt[msg.sender] = block.timestamp;
        totalClaims++;
        areal.faucetMint(msg.sender, claimAmount);

        emit Claimed(msg.sender, claimAmount);
    }

    function timeUntilClaim(address wallet) external view returns (uint256) {
        uint256 last = lastClaimAt[wallet];
        if (last == 0) return 0;
        uint256 next = last + CLAIM_COOLDOWN;
        if (block.timestamp >= next) return 0;
        return next - block.timestamp;
    }

    /// Returns true if the given wallet has already claimed from this faucet.
    function hasClaimed(address wallet) external view returns (bool) {
        return lastClaimAt[wallet] != 0;
    }

    function setClaimAmount(uint256 _amount) external onlyOwner {
        claimAmount = _amount;
    }
}
