// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/ArealFaucet.sol";
import "../src/YieldRewardToken.sol";

contract DeployArealFaucet is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        address tokenAddress = vm.envAddress("AREAL_TOKEN_ADDRESS");
        YieldRewardToken areal = YieldRewardToken(tokenAddress);

        require(areal.owner() == deployer, "Deployer is not AREAL owner");
        (bool supportsFaucet, bytes memory faucetData) = tokenAddress.staticcall(abi.encodeWithSignature("faucet()"));
        require(supportsFaucet && faucetData.length == 32, "Token lacks faucet support; deploy updated token first");
        require(abi.decode(faucetData, (address)) == address(0), "AREAL faucet already configured");

        vm.startBroadcast(privateKey);
        ArealFaucet faucet = new ArealFaucet(tokenAddress);
        areal.setFaucet(address(faucet));
        vm.stopBroadcast();

        console.log("ArealFaucet:", address(faucet));
    }
}
