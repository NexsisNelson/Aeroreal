// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimulatedNFTCollection is ERC721, Ownable {
    uint256 private _nextId = 1;
    string public baseTokenURI;

    event Minted(address indexed to, uint256 indexed tokenId);

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) Ownable(msg.sender) {}

    function mint(address to) external onlyOwner returns (uint256) {
        return _mintToken(to);
    }

    function userMint(address to) external returns (uint256) {
        return _mintToken(to);
    }

    function totalSupply() external view returns (uint256) {
        return _nextId - 1;
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseTokenURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    function _mintToken(address to) private returns (uint256 tokenId) {
        tokenId = _nextId++;
        _safeMint(to, tokenId);
        emit Minted(to, tokenId);
    }
}
