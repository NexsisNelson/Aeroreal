// lib/config/abis.dart

class AppABIs {
  /// ERC-20 ABI — used for SprinkleToken and FractionToken.
  static const String erc20 = '''
[
  {"constant":true,"inputs":[{"name":"account","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"constant":false,"inputs":[{"name":"spender","type":"address"},{"name":"amount","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},
  {"constant":true,"inputs":[{"name":"owner","type":"address"},{"name":"spender","type":"address"}],"name":"allowance","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"stateMutability":"view","type":"function"},
  {"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
  {"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
  {"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
]
''';

  /// MicroYieldStreamer ABI.
  static const String streamer = '''
[
  {"inputs":[{"name":"account","type":"address"}],"name":"earned","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"totalStaked","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"rewardRate","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"name":"","type":"address"}],"name":"userInfo","outputs":[{"name":"amount","type":"uint256"},{"name":"rewardPerTokenPaid","type":"uint256"},{"name":"rewards","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"name":"amount","type":"uint256"}],"name":"stake","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[{"name":"amount","type":"uint256"}],"name":"withdraw","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[],"name":"claimYield","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[],"name":"exit","outputs":[],"stateMutability":"nonpayable","type":"function"}
]
''';

  /// FractionalizerVault ABI.
  static const String vault = '''
[
  {"inputs":[],"name":"fractionalize","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[],"name":"redeem","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[],"name":"fractionToken","outputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"nftContract","outputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"nftTokenId","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"totalFractions","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"isRedeemed","outputs":[{"name":"","type":"bool"}],"stateMutability":"view","type":"function"}
]
''';

  /// FractionFactory ABI.
  static const String factory = '''
[
  {"inputs":[{"name":"_nftContract","type":"address"},{"name":"_nftTokenId","type":"uint256"},{"name":"_totalFractions","type":"uint256"},{"name":"_name","type":"string"},{"name":"_symbol","type":"string"}],"name":"createVault","outputs":[{"name":"vault","type":"address"}],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[],"name":"getVaultCount","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"name":"_start","type":"uint256"},{"name":"_end","type":"uint256"}],"name":"getVaults","outputs":[{"name":"","type":"address[]"}],"stateMutability":"view","type":"function"}
]
''';

  /// DemoNFT (ERC-721) ABI.
  static const String erc721 = '''
[
  {"inputs":[{"name":"to","type":"address"}],"name":"mint","outputs":[{"name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[{"name":"owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"name":"tokenId","type":"uint256"}],"name":"ownerOf","outputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"name":"to","type":"address"},{"name":"tokenId","type":"uint256"}],"name":"approve","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[{"name":"operator","type":"address"},{"name":"approved","type":"bool"}],"name":"setApprovalForAll","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[{"name":"owner","type":"address"},{"name":"operator","type":"address"}],"name":"isApprovedForAll","outputs":[{"name":"","type":"bool"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
]
''';

  /// NFT marketplace ABI.
  static const String marketplace = '''
[
  {"inputs":[{"name":"nftContract","type":"address"},{"name":"tokenId","type":"uint256"},{"name":"price","type":"uint256"}],"name":"list","outputs":[{"name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[{"name":"listingId","type":"uint256"}],"name":"buy","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[{"name":"listingId","type":"uint256"}],"name":"cancel","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[{"name":"listingId","type":"uint256"}],"name":"getListing","outputs":[{"name":"seller","type":"address"},{"name":"nftContract","type":"address"},{"name":"tokenId","type":"uint256"},{"name":"price","type":"uint256"},{"name":"active","type":"bool"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"nextListingId","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"activeListingCount","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"feeBps","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
]
''';

  /// CommodityVault ABI.
  static const String commodityVault = '''
[
  {"inputs":[],"name":"commodityType","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"quantity","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"unitOfMeasure","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"storageLocation","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"auditReportURI","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"custodian","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"fractionToken","outputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"getCommodityInfo","outputs":[{"name":"_commodityType","type":"string"},{"name":"_quantity","type":"uint256"},{"name":"_unitOfMeasure","type":"string"},{"name":"_storageLocation","type":"string"},{"name":"_auditReportURI","type":"string"},{"name":"_insuranceURI","type":"string"},{"name":"_custodian","type":"string"}],"stateMutability":"view","type":"function"}
]
''';

  /// Chainlink AggregatorV3Interface (standard ABI, same across all chains).
  static const String chainlinkFeed = '''
[
  {"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"description","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"latestRoundData","outputs":[{"name":"roundId","type":"uint80"},{"name":"answer","type":"int256"},{"name":"startedAt","type":"uint256"},{"name":"updatedAt","type":"uint256"},{"name":"answeredInRound","type":"uint80"}],"stateMutability":"view","type":"function"}
]
''';

  /// InvoiceVault ABI.
  static const String invoiceVault = '''
[
  {"inputs":[],"name":"faceValue","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"discountBps","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"maturityDate","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"isSettled","outputs":[{"name":"","type":"bool"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"totalSettled","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"settlementToken","outputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"buyerJurisdiction","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"invoiceDocumentURI","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"fractionToken","outputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"daysUntilMaturity","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"isMatured","outputs":[{"name":"","type":"bool"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"name":"_investor","type":"address"}],"name":"claimableAmount","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"claimProceeds","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[],"name":"getInvoiceInfo","outputs":[{"name":"_smeIssuer","type":"address"},{"name":"_invoiceBuyer","type":"address"},{"name":"_faceValue","type":"uint256"},{"name":"_discountBps","type":"uint256"},{"name":"_issueDate","type":"uint256"},{"name":"_maturityDate","type":"uint256"},{"name":"_isSettled","type":"bool"},{"name":"_totalSettled","type":"uint256"},{"name":"_settlementToken","type":"address"},{"name":"_invoiceDocumentURI","type":"string"},{"name":"_buyerJurisdiction","type":"string"}],"stateMutability":"view","type":"function"}
]
''';

  /// RevenueStreamer ABI (RWA version — distributes stablecoins).
  static const String revenueStreamer = '''
[
  {"inputs":[],"name":"totalStaked","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"rewardRate","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"lifetimeRevenueReceived","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"lifetimeYieldClaimed","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"name":"account","type":"address"}],"name":"earned","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"name":"","type":"address"}],"name":"userInfo","outputs":[{"name":"amount","type":"uint256"},{"name":"rewardPerTokenPaid","type":"uint256"},{"name":"rewards","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[],"name":"getStreamerInfo","outputs":[{"name":"_stakingToken","type":"address"},{"name":"_rewardToken","type":"address"},{"name":"_vault","type":"address"},{"name":"_totalStaked","type":"uint256"},{"name":"_rewardRate","type":"uint256"},{"name":"_lifetimeRevenueReceived","type":"uint256"},{"name":"_lifetimeYieldClaimed","type":"uint256"},{"name":"_currentPoolBalance","type":"uint256"}],"stateMutability":"view","type":"function"},
  {"inputs":[{"name":"_amount","type":"uint256"}],"name":"stake","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[{"name":"_amount","type":"uint256"}],"name":"withdraw","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[],"name":"claimYield","outputs":[],"stateMutability":"nonpayable","type":"function"},
  {"inputs":[{"name":"_amount","type":"uint256"}],"name":"depositRevenue","outputs":[],"stateMutability":"nonpayable","type":"function"}
]
''';
}
