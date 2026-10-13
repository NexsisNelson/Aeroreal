// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/SimulatedAssetFactory.sol";
import "../src/SimulatedMarketplace.sol";

contract SimulatedAssetFactoryTest is Test {
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    uint256 private oraclePrivateKey = 0xA11CE;
    address private oracle;
    address private marketplace = address(0xBEEF);
    SimulatedAssetFactory private factory;

    function setUp() public {
        oracle = vm.addr(oraclePrivateKey);
        factory = new SimulatedAssetFactory(marketplace, oracle);
    }

    function testCreateAssetWithOracleQuoteTransfersMintingOwnership() public {
        uint256 price = 2500 ether;
        uint256 deadline = block.timestamp + 5 minutes;
        bytes memory signature = _signQuote("ethereum", "Simulated Ethereum", "sETH", "ETH", price, deadline);

        address assetAddress =
            factory.createAsset("ethereum", "Simulated Ethereum", "sETH", "ETH", price, deadline, signature);
        SimulatedAsset asset = SimulatedAsset(assetAddress);

        assertEq(factory.assetForId("ethereum"), assetAddress);
        assertEq(asset.owner(), marketplace);
        assertEq(asset.priceOracle(), oracle);
        assertEq(asset.currentPriceUsd(), price);
        assertEq(factory.assetCount(), 1);
        (string memory id, address listedAsset) = factory.assetAt(0);
        assertEq(id, "ethereum");
        assertEq(listedAsset, assetAddress);
    }

    function testRejectsSignatureForDifferentQuote() public {
        uint256 deadline = block.timestamp + 5 minutes;
        bytes memory signature = _signQuote("ethereum", "Simulated Ethereum", "sETH", "ETH", 2500 ether, deadline);

        vm.expectRevert("Invalid oracle signature");
        factory.createAsset("ethereum", "Simulated Ethereum", "sETH", "ETH", 1 ether, deadline, signature);
    }

    function testRejectsExpiredQuote() public {
        uint256 deadline = block.timestamp - 1;
        bytes memory signature = _signQuote("ethereum", "Simulated Ethereum", "sETH", "ETH", 2500 ether, deadline);

        vm.expectRevert("Quote expired");
        factory.createAsset("ethereum", "Simulated Ethereum", "sETH", "ETH", 2500 ether, deadline, signature);
    }

    function testRejectsDuplicateAssetId() public {
        uint256 deadline = block.timestamp + 5 minutes;
        bytes memory signature = _signQuote("ethereum", "Simulated Ethereum", "sETH", "ETH", 2500 ether, deadline);
        factory.createAsset("ethereum", "Simulated Ethereum", "sETH", "ETH", 2500 ether, deadline, signature);

        vm.expectRevert("Asset already exists");
        factory.createAsset("ethereum", "Simulated Ethereum", "sETH", "ETH", 2500 ether, deadline, signature);
    }

    function _signQuote(
        string memory id,
        string memory name,
        string memory symbol,
        string memory underlyingSymbol,
        uint256 price,
        uint256 deadline
    ) private view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Asset(string coingeckoId,string name,string symbol,string underlyingSymbol,uint256 initialPriceUsd,uint256 deadline)"
                ),
                keccak256(bytes(id)),
                keccak256(bytes(name)),
                keccak256(bytes(symbol)),
                keccak256(bytes(underlyingSymbol)),
                price,
                deadline
            )
        );
        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("Aeroreal Simulated Factory")),
                keccak256(bytes("1")),
                block.chainid,
                address(factory)
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
