// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/SimulatedNFTCollection.sol";

contract SimulatedNFTCollectionTest is Test {
    SimulatedNFTCollection private collection;
    address private user = address(0xBEEF);

    function setUp() public {
        collection = new SimulatedNFTCollection("Simulated Apes", "sBAYC");
    }

    function testUserMintCreatesTokenForRecipient() public {
        vm.prank(user);
        uint256 tokenId = collection.userMint(user);

        assertEq(tokenId, 1);
        assertEq(collection.ownerOf(tokenId), user);
        assertEq(collection.balanceOf(user), 1);
        assertEq(collection.totalSupply(), 1);
    }

    function testOwnerMintRemainsRestricted() public {
        vm.prank(user);
        vm.expectRevert();
        collection.mint(user);
    }
}