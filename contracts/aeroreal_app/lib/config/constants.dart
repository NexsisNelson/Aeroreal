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
      '0xaa1fbec3F43a6dE2E2791052d593C2b9b7A57Ed4';
  static const String fractionFactory =
      '0xeB4f5592d12B59910ef92584e59767A931d8Ce40';
  static const String demoNft = '0x4DAafE00142c33ca08860Dea01991fFcB6CDC334';
  static const String nftMarketplace =
      '0x6CB3FaD51E56B5428D9566cE7D7020952E9015E3';
  static const String nftMarketplacePaymentToken =
      '0x01eA8d5FF45f5fAaC8b5BbE1e48cc734cd104512';
  static const String vault = '0x1dBBfCCe0095847548dD21dCCEbfe8eB9C7cdb4a';
  static const String fractionToken =
      '0x6511204b20e1cbeCEC46673Ac602F97C72388Ff1';
  static const String streamer = '0x7a66c68Fe33337Cf472A7D4a2dbEcE9bae5675ff';

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
      '0x6965C9D3c2f5FbcC3258a2F1ce6683CbE3dB03C1';
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

  // ---- Token Decimals ----
  static const int standardDecimals = 18;
}
