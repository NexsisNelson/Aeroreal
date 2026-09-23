// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title YieldRewardToken
 * @notice This is the "Sprinkle" (the micro yield).
 * It is a standard ERC-20 token, but it is minted exclusively by the
 * MicroYieldStreamer contract as rewards for users.
 */
contract YieldRewardToken is ERC20, Ownable {
    // The 'Streamer' is the contract that calculates and gives out yield.
    address public streamer;

    event StreamerSet(address indexed streamer);

    /**
     * @notice Constructor sets the name of the reward token.
     * @param _name Full name, e.g., "Micro Yield Sprinkle"
     * @param _symbol Ticker, e.g., "SPRINKLE"
     */
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {}

    /**
     * @notice Owner sets the address of the MicroYieldStreamer.
     * @param _streamer The contract address allowed to mint.
     */
    function setStreamer(address _streamer) external onlyOwner {
        require(_streamer != address(0), "Zero address not allowed");
        streamer = _streamer;
        emit StreamerSet(_streamer);
    }

    /**
     * @notice Only the Streamer can call this. It creates new Sprinkles.
     * @param _to The user receiving the micro yield.
     * @param _amount How many sprinkles to give them.
     */
    function mint(address _to, uint256 _amount) external {
        require(msg.sender == streamer, "Only the Streamer can mint");
        _mint(_to, _amount);
    }
}
