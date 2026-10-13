// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "./SimulatedAsset.sol";

contract SimulatedAssetFactory is EIP712 {
    using ECDSA for bytes32;

    bytes32 private constant ASSET_TYPEHASH = keccak256(
        "Asset(string coingeckoId,string name,string symbol,string underlyingSymbol,uint256 initialPriceUsd,uint256 deadline)"
    );

    address public immutable marketplace;
    address public immutable oracle;
    mapping(string => address) public assetForId;
    string[] private _coingeckoIds;

    event AssetCreated(string coingeckoId, address indexed asset, string name, string symbol);

    constructor(address _marketplace, address _oracle) EIP712("Aeroreal Simulated Factory", "1") {
        require(_marketplace != address(0), "Invalid marketplace");
        require(_oracle != address(0), "Invalid oracle");
        marketplace = _marketplace;
        oracle = _oracle;
    }

    function createAsset(
        string calldata coingeckoId,
        string calldata name,
        string calldata symbol,
        string calldata underlyingSymbol,
        uint256 initialPriceUsd,
        uint256 deadline,
        bytes calldata signature
    ) external returns (address assetAddress) {
        require(bytes(coingeckoId).length > 0, "Missing asset id");
        require(bytes(name).length > 0, "Missing name");
        require(bytes(symbol).length > 0, "Missing symbol");
        require(initialPriceUsd > 0, "Invalid price");
        require(block.timestamp <= deadline, "Quote expired");
        require(assetForId[coingeckoId] == address(0), "Asset already exists");

        bytes32 structHash = keccak256(
            abi.encode(
                ASSET_TYPEHASH,
                keccak256(bytes(coingeckoId)),
                keccak256(bytes(name)),
                keccak256(bytes(symbol)),
                keccak256(bytes(underlyingSymbol)),
                initialPriceUsd,
                deadline
            )
        );
        require(_hashTypedDataV4(structHash).recover(signature) == oracle, "Invalid oracle signature");

        SimulatedAsset asset = new SimulatedAsset(name, symbol, underlyingSymbol, oracle, initialPriceUsd);
        asset.transferOwnership(marketplace);

        assetAddress = address(asset);
        assetForId[coingeckoId] = assetAddress;
        _coingeckoIds.push(coingeckoId);
        emit AssetCreated(coingeckoId, assetAddress, name, symbol);
    }

    function assetCount() external view returns (uint256) {
        return _coingeckoIds.length;
    }

    function assetAt(uint256 index) external view returns (string memory coingeckoId, address assetAddress) {
        coingeckoId = _coingeckoIds[index];
        assetAddress = assetForId[coingeckoId];
    }
}
