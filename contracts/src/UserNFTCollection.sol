// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title UserNFTCollection
 * @notice A public ERC-721 collection where any user can mint an NFT.
 * @dev Stores metadata URI (IPFS hash) and creator royalty.
 */
contract UserNFTCollection is ERC721URIStorage, ERC2981, Ownable {
    uint256 private _nextId = 1;

    uint256 public mintFee = 0;
    address public arealToken;

    mapping(uint256 => address) public creatorOf;

    event NFTMinted(uint256 indexed tokenId, address indexed creator, string tokenURI, uint96 royaltyBps);

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) Ownable(msg.sender) {}

    function mint(address _to, string memory _tokenURI, uint96 _royaltyBps) external returns (uint256) {
        require(_to != address(0), "Invalid recipient");
        require(_royaltyBps <= 1000, "Royalty max 10%");

        uint256 tokenId = _nextId++;
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        _setTokenRoyalty(tokenId, _to, _royaltyBps);

        creatorOf[tokenId] = _to;

        emit NFTMinted(tokenId, _to, _tokenURI, _royaltyBps);
        return tokenId;
    }

    function setMintFee(uint256 _fee) external onlyOwner {
        mintFee = _fee;
    }

    function setArealToken(address _areal) external onlyOwner {
        arealToken = _areal;
    }

    function getCreator(uint256 tokenId) external view returns (address) {
        return creatorOf[tokenId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
