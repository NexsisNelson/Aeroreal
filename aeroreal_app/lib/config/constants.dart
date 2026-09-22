// lib/config/constants.dart

class AppConstants {
  // ---- Monad Testnet ----
  static const String monadRpcUrl = 'https://10143.rpc.thirdweb.com';
  static const int monadChainId = 10143;

  // ---- Chainlink Price Feeds (Monad Mainnet, read-only) ----
  static const String monadMainnetRpcUrl = 'https://rpc.monad.xyz';
  static const String xauUsdFeed = '0x61dD33A34E47a181EE02e42eE0546a3DA808f1B4';

  // ---- Your Deployed Contracts on Monad Testnet ----
  static const String sprinkleToken =
      '0x52ed56213b76636CA031ec6D0fE3944ef777b914';
  static const String fractionFactory =
      '0xeB4f5592d12B59910ef92584e59767A931d8Ce40';
  static const String demoNft = '0x1eBaCA771E149b589E04C80003E037b0E1dC9469';
  static const String nftMarketplace =
      '0x6CB3FaD51E56B5428D9566cE7D7020952E9015E3';
  static const String vault = '0xd55B8592c24564B9A863388E7E958460e749e41b';
  static const String fractionToken =
      '0xF52D7E38a83650121F9550Db1Da92e449e3a03DE';
  static const String streamer = '0x82f55225C4F1a18287548caEC516a5e598725C9F';

  // ---- Real Assets (New Deployment) ----
  static const String goldVault = '0xe524bd915098eec8f0fb73e9f4d7321597c90d72';
  static const String goldStreamer =
      '0x89316635940E0e447E76dDC4De89ccaaE277235b';
  static const String coffeeVault =
      '0x05d826fba0271cd5fe6d10a0aebe79da6c49ac9e';
  static const String coffeeStreamer =
      '0x769c3a84fe55ebcd1a728317085a7e1409b66f5f';
  static const String treasuryVault =
      '0x934f83a89c4471b5d375f4ac52ee45c9f5e94df0';
  static const String treasuryStreamer =
      '0xa127741629f3104d6c19c178d090fea3a0770531';

  // ---- RWA Contracts (Monad Testnet) ----
  static const String mockStablecoin =
      '0x01eA8d5FF45f5fAaC8b5BbE1e48cc734cd104512';
  static const String fractionMarketplace =
      '0x301426360A0E81c62C45cCA1E308963be6926C69';
  static const String revenueOracle =
      '0x867Ca7417E20c191AAf149219B8af86f3Bb6d689';
  static const String commodityCertificate =
      '0x322E06498ACD5246ecf090D12C80CA32408baDAB';
  static const String invoiceCertificate =
      '0x2f13D80e842b9Aeb277b14A7c4523fdfA15912Ed';
  static const String commodityVault =
      '0xe524bd915098eec8f0fb73e9f4d7321597c90d72'; // Gold
  static const String invoiceVault =
      '0xd5FF21c3516e54178bc82640dd4Ee3777e7870E1';
  static const String cocoaStreamer =
      '0x3a0FD8976Ac5AE693DF2bFdD3116b4e591e6b5F9';
  static const String invoiceStreamer =
      '0xe04BFfbE8e234708bEB2D702C7982e8Cc9a15C29';

  // ---- Token Decimals ----
  static const int standardDecimals = 18;
}
