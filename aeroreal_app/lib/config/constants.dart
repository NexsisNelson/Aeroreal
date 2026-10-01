// lib/config/constants.dart

class AppConstants {
  // All contract addresses live here so screens and services share one
  // deployment configuration instead of embedding addresses in UI code.

  // ---- Monad Testnet ----
  static const String monadRpcUrl = 'https://testnet-rpc.monad.xyz';
  static const int monadChainId = 10143;

  // ---- Chainlink Price Feeds (Monad Mainnet, read-only) ----
  static const String monadMainnetRpcUrl = 'https://rpc.monad.xyz';
  static const String xauUsdFeed = '0x61dD33A34E47a181EE02e42eE0546a3DA808f1B4';

  // ---- Your Deployed Contracts on Monad Testnet ----
  static const String sprinkleToken =
      '0x01c6b9a2F0f73eb7f6a3280C5D028cB2BAe40B76';
  static const String arealFaucet =
      '0x6C256F5CAbd6EB830106860FF79F2a5ddFeD9E04';
  static const String fractionFactory =
      '0xeB4f5592d12B59910ef92584e59767A931d8Ce40';
  static const String demoNft = '0x4DAafE00142c33ca08860Dea01991fFcB6CDC334';
  static const String userNftCollection =
      '0x0000000000000000000000000000000000000000';
  static const String nftMarketplace =
      '0x9b18373F4985394D75b1b50c4a1E7cA15c025b05';
  static const String nftMarketplacePaymentToken =
      '0x01c6b9a2F0f73eb7f6a3280C5D028cB2BAe40B76';
  static const String vault = '0x1dBBfCCe0095847548dD21dCCEbfe8eB9C7cdb4a';
  static const String fractionToken =
      '0x6511204b20e1cbeCEC46673Ac602F97C72388Ff1';
  static const String streamer = '0x208a530c597da61EA7332fE6e4cb6048D8bF449F';

  // ---- Real Assets (New Deployment) ----
  static const String goldVault = '0x1dBBfCCe0095847548dD21dCCEbfe8eB9C7cdb4a';
  static const String goldStreamer =
      '0x89316635940E0e447E76dDC4De89ccaaE277235b';
  static const String coffeeVault =
      '0x5fD30D6E3C736e5E8FFA70abd4c3FBDeAdcEED2E';
  static const String coffeeStreamer =
      '0x769c3a84fe55ebcd1a728317085a7e1409b66f5f';
  static const String treasuryVault =
      '0x934f83a89c4471b5d375f4ac52ee45c9f5e94df0';
  static const String treasuryStreamer =
      '0xa127741629f3104d6c19c178d090fea3a0770531';

  // ---- RWA Contracts (Monad Testnet) ----
  static const String mockStablecoin =
      '0x05053c8877330536a002ca4F06F43740AEBC969B';
  static const String fractionMarketplace =
      '0xF1b6f185e48FEBFDf428ecB157b6aABbeF1c1fe5';
  static const String goldFractionToken =
      '0x6511204b20e1cbeCEC46673Ac602F97C72388Ff1';
  static const String coffeeFractionToken =
      '0x0a0e77B60675C97B070db144fb08DE7b418f036B';
  static const String treasuryFractionToken =
      '0x44e1D5A9d1Aa66D056847749b889cd4fBC1da440';
  static const String faucet = '0x52dbb61fB6416923D982e4BCaA4EDB8d8510ca58';
  static const String revenueOracle =
      '0x867Ca7417E20c191AAf149219B8af86f3Bb6d689';
  static const String commodityCertificate =
      '0x4DAafE00142c33ca08860Dea01991fFcB6CDC334';
  static const String invoiceCertificate =
      '0x2f13D80e842b9Aeb277b14A7c4523fdfA15912Ed';
  static const String commodityVault =
      '0x1dBBfCCe0095847548dD21dCCEbfe8eB9C7cdb4a'; // Gold
  static const String invoiceVault =
      '0xd5FF21c3516e54178bc82640dd4Ee3777e7870E1';
  static const String cocoaStreamer =
      '0x3a0FD8976Ac5AE693DF2bFdD3116b4e591e6b5F9';
  static const String invoiceStreamer =
      '0xe04BFfbE8e234708bEB2D702C7982e8Cc9a15C29';

  // ---- Simulated Asset Layer (Day 3) ----
  static const String simulatedMarketplace =
      '0x5c1eFEAb0c242FB6eE7c5F9BF02B4041C3b0E2d0';
  static const String simulatedBtc =
      '0xc9918cBFdD2AeFaeA4270898C9dee2393749218a';
  static const String simulatedEth =
      '0xdE522022eCE6793DB0Dab1B6690d80E87B9eb77F';
  static const String simulatedGold =
      '0x625Cf7Ae602d2F084A2A2E85b60288588DF125C6';
  static const String simulatedCoffee =
      '0x29dfbE86ab0aA6B2aF9EFd059E628Dc87998a9BB';
  static const String simulatedSol =
      '0x88e0b708e1350C481Fd4e8BE2Baffcb9C22E300d';

  // ---- Simulated NFT Collections (Day 4) ----
  static const String simulatedBayc =
      '0x7d235E698e9ae7C00c62aEdab060fD50185d7fF3';
  static const String simulatedPunks =
      '0x28aA6bf9e7EE92712051653325193Cc7F9EA0dD7';
  static const String simulatedDoodles =
      '0x4aA282eA78cd190802af8334dCC93c0a68b8c44e';

  // ---- Monad Community NFT Collections ----
  static const String monadApes = '0x6a51cb2a57183bff87eb1dd6f0414bd0c4455f95';
  static const String monadPunks = '0x392bb9840cdab3983fd24d0c239669b2e71429f4';
  static const String monadFrogs = '0x589cdb72735f1fed754499453eeb7b6360c9b0c5';

  // ---- Token Decimals ----
  static const int standardDecimals = 18;
}
