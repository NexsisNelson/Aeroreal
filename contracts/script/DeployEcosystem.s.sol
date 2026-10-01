// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/FractionFactory.sol";
import "../src/MicroYieldStreamer.sol";
import "../src/YieldRewardToken.sol";
import "../src/FractionalizerVault.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @notice A simple Mock NFT deployed on Monad Testnet for demo purposes.
 */
contract DemoNFT is ERC721 {
    uint256 private _nextId = 1;

    constructor() ERC721("Monad Demo Ape", "MDAPE") {}

    function mint(address to) external returns (uint256) {
        uint256 id = _nextId++;
        _safeMint(to, id);
        return id;
    }
}

/**
 * @title DeployEcosystem
 * @notice Deploys a Vault + Streamer pair, mints a demo NFT, and wires it all up.
 */
contract DeployEcosystem is Script {
    // Addresses deployed by Deploy.s.sol on Monad Testnet.
    address constant SPRINKLE_TOKEN = 0x52ed56213b76636CA031ec6D0fE3944ef777b914;
    address constant FRACTION_FACTORY = 0xeB4f5592d12B59910ef92584e59767A931d8Ce40;

    // 10,000 fractions, scaled to 18 decimals (the standard for ERC-20).
    // The FractionToken uses 18 decimals, so this value displays as "10,000.0".
    uint256 constant TOTAL_FRACTIONS = 10_000 * 1e18;
    uint256 constant REWARD_RATE = 1e18; // 1 SPR per second

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);

        YieldRewardToken sprinkle = YieldRewardToken(SPRINKLE_TOKEN);
        FractionFactory factory = FractionFactory(FRACTION_FACTORY);

        vm.startBroadcast(deployerPrivateKey);

        // =====================================================
        // STEP 1: Deploy the Demo NFT and mint one to the deployer.
        // =====================================================
        DemoNFT demoNft = new DemoNFT();
        console.log("DemoNFT deployed at:", address(demoNft));

        uint256 tokenId = demoNft.mint(deployer);
        console.log("Minted DemoNFT #", tokenId, "to deployer");

        // =====================================================
        // STEP 2: Create a Vault via the Factory.
        // =====================================================
        address vaultAddress = factory.createVault(
            address(demoNft),
            tokenId,
            TOTAL_FRACTIONS,
            "Fractionalized Monad Demo Ape",
            "fMDAPE"
        );
        console.log("Vault deployed at:", vaultAddress);

        FractionalizerVault vault = FractionalizerVault(vaultAddress);
        address fractionTokenAddress = address(vault.fractionToken());
        console.log("FractionToken deployed at:", fractionTokenAddress);

        // =====================================================
        // STEP 3: Approve and Fractionalize the NFT.
        // =====================================================
        demoNft.approve(vaultAddress, tokenId);
        vault.fractionalize();
        console.log("NFT fractionalized. Deployer owns", TOTAL_FRACTIONS, "fractions.");

        // =====================================================
        // STEP 4: Deploy the MicroYieldStreamer for this FractionToken.
        // =====================================================
        MicroYieldStreamer streamer = new MicroYieldStreamer(
            fractionTokenAddress,
            SPRINKLE_TOKEN
        );
        console.log("Streamer deployed at:", address(streamer));

        // =====================================================
        // STEP 5: Wire the Sprinkle token to authorize the Streamer.
        // =====================================================
        sprinkle.setStreamer(address(streamer));
        console.log("Sprinkle token authorized Streamer to mint.");

        // =====================================================
        // STEP 6: Set the reward rate (1 SPR per second globally).
        // =====================================================
        streamer.setRewardRate(REWARD_RATE);
        console.log("Reward rate set to 1 SPR/sec.");

        vm.stopBroadcast();

        // =====================================================
        // SUMMARY
        // =====================================================
        console.log("");
        console.log("=== ECOSYSTEM DEPLOYMENT COMPLETE ===");
        console.log("DemoNFT:", address(demoNft));
        console.log("Vault:", vaultAddress);
        console.log("FractionToken:", fractionTokenAddress);
        console.log("Streamer:", address(streamer));
        console.log("SprinkleToken:", SPRINKLE_TOKEN);
        console.log("Factory:", FRACTION_FACTORY);
    }
}
