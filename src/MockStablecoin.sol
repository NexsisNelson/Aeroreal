// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockStablecoin
 * @notice A testnet-only stablecoin that anyone can mint.
 *         Used for demoing revenue flows on Monad Testnet.
 *         NOT for production.
 */
contract MockStablecoin is ERC20, Ownable {

    constructor() ERC20("Mock USD", "mUSD") Ownable(msg.sender) {}

    /// @notice Anyone can mint for testing purposes. Rate-limited in production.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
