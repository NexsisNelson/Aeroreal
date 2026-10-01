// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title CommodityCertificate
 * @notice An NFT that represents physical ownership of a commodity batch.
 *         Minted by the custodian and locked in a CommodityVault when
 *         fractionalized.
 */
contract CommodityCertificate is ERC721 {
    uint256 private _nextId = 1;

    constructor() ERC721("Commodity Certificate", "CERT") {}

    function mint(address to) external returns (uint256) {
        uint256 id = _nextId++;
        _safeMint(to, id);
        return id;
    }
}
