// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title InvoiceCertificate
 * @notice An NFT that represents a specific invoice.
 *         Minted by the SME and locked in an InvoiceVault when fractionalized.
 */
contract InvoiceCertificate is ERC721 {
    uint256 private _nextId = 1;

    constructor() ERC721("Invoice Certificate", "INVCERT") {}

    function mint(address to) external returns (uint256) {
        uint256 id = _nextId++;
        _safeMint(to, id);
        return id;
    }
}
