// lib/services/contract_service.dart

import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:wallet/wallet.dart';

import '../config/abis.dart';
import '../config/constants.dart';
import 'privy_service.dart';
import 'notification_service.dart';
import 'tx_history_service.dart';

/// ContractService reads from and writes to the deployed Monad contracts.
class ContractService {
  final PrivyService privyService;
  late final Web3Client client;
  late final Web3Client mainnetClient;
  final _txHistory = TxHistoryService();

  ContractService(this.privyService) {
    client = Web3Client(AppConstants.monadRpcUrl, http.Client());
    mainnetClient = Web3Client(AppConstants.monadMainnetRpcUrl, http.Client());
  }

  // =========================================================
  // PRIVY-BACKED TRANSACTION SENDER
  // =========================================================

  /// Send a transaction through the embedded Privy wallet.
  Future<String> _sendPrivyTransaction({
    required String contractAddress,
    required String functionName,
    required List<dynamic> params,
    required String abi,
  }) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(abi, 'Contract'),
      EthereumAddress.fromHex(contractAddress),
    );
    final fn = contract.function(functionName);
    final encoded = fn.encodeCall(params);
    final hexData =
        '0x${encoded.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    try {
      final hash = await privyService.signAndSendTransaction(
        to: contractAddress,
        data: hexData,
        value: '0x0',
      );

      if (hash == null) {
        final walletAddress = privyService.walletAddress;
        if (walletAddress != null) {
          final balance = await client.getBalance(
            EthereumAddress.fromHex(walletAddress),
          );
          throw Exception(
            'Privy signing failed. Wallet balance: ${balance.getInWei} wei. '
            'Ensure the wallet has MON for gas.',
          );
        }
        throw Exception(
          'Privy signing failed. Ensure the wallet has MON for gas.',
        );
      }

      await _txHistory.log(
        hash: hash,
        action: functionName,
        details: 'Contract: ${contractAddress.substring(0, 10)}...',
      );
      await NotificationService().notify(
        type: NotificationType.transactionSuccess,
        title: 'Transaction Submitted',
        body: '$functionName submitted on Monad Testnet',
      );
      await _waitForReceipt(hash);
      return hash;
    } catch (error) {
      await NotificationService().notify(
        type: NotificationType.transactionFailed,
        title: 'Transaction Failed',
        body: '$functionName: $error',
      );
      rethrow;
    }
  }

  /// Poll for a transaction receipt.
  Future<void> _waitForReceipt(String txHash, {int maxAttempts = 30}) async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final receipt = await client.getTransactionReceipt(txHash);
        if (receipt != null) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw Exception(
      'Transaction not confirmed after ${maxAttempts * 2}s: $txHash',
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  DeployedContract _contract(String address, String abi) {
    return DeployedContract(
      ContractAbi.fromJson(abi, 'Contract'),
      EthereumAddress.fromHex(address),
    );
  }

  /// Parse a BigInt amount into a human-readable string (divides by 10^18).
  String formatToken(BigInt raw) {
    final divisor = BigInt.from(10).pow(AppConstants.standardDecimals);
    final whole = raw ~/ divisor;
    final remainder = raw % divisor;
    if (remainder == BigInt.zero) return whole.toString();
    final decimals = remainder.toString().padLeft(18, '0').substring(0, 4);
    return '$whole.$decimals';
  }

  /// Convert a human-readable amount to raw BigInt (multiplies by 10^18).
  BigInt parseToken(String human) {
    final parts = human.split('.');
    final whole = BigInt.parse(parts[0]);
    final multiplier = BigInt.from(10).pow(AppConstants.standardDecimals);
    if (parts.length == 1) return whole * multiplier;

    final fraction = parts[1].padRight(18, '0').substring(0, 18);
    return whole * multiplier + BigInt.parse(fraction);
  }

  // =========================================================
  // READS
  // =========================================================

  Future<BigInt> getFractionBalance(String address) async {
    final contract = _contract(AppConstants.fractionToken, AppABIs.erc20);
    final fn = contract.function('balanceOf');
    final result = await client.call(
      contract: contract,
      function: fn,
      params: [EthereumAddress.fromHex(address)],
    );
    return result[0] as BigInt;
  }

  Future<BigInt> getSprinkleBalance(String address) async {
    final contract = _contract(AppConstants.sprinkleToken, AppABIs.erc20);
    final fn = contract.function('balanceOf');
    final result = await client.call(
      contract: contract,
      function: fn,
      params: [EthereumAddress.fromHex(address)],
    );
    return result[0] as BigInt;
  }

  Future<BigInt> getGoldFractionBalance(String address) async {
    final vault = _contract(AppConstants.goldVault, AppABIs.vault);
    final tokenResult = await client.call(
      contract: vault,
      function: vault.function('fractionToken'),
      params: [],
    );
    final token = _contract(
      (tokenResult[0] as EthereumAddress).with0x,
      AppABIs.erc20,
    );
    final result = await client.call(
      contract: token,
      function: token.function('balanceOf'),
      params: [EthereumAddress.fromHex(address)],
    );
    return result[0] as BigInt;
  }

  Future<BigInt> getEarnedYield(String address) async {
    final contract = _contract(AppConstants.streamer, AppABIs.streamer);
    final fn = contract.function('earned');
    final result = await client.call(
      contract: contract,
      function: fn,
      params: [EthereumAddress.fromHex(address)],
    );
    return result[0] as BigInt;
  }

  Future<BigInt> getTotalStaked() async {
    final contract = _contract(AppConstants.streamer, AppABIs.streamer);
    final fn = contract.function('totalStaked');
    final result = await client.call(
      contract: contract,
      function: fn,
      params: [],
    );
    return result[0] as BigInt;
  }

  Future<BigInt> getRewardRate() async {
    final contract = _contract(AppConstants.streamer, AppABIs.streamer);
    final fn = contract.function('rewardRate');
    final result = await client.call(
      contract: contract,
      function: fn,
      params: [],
    );
    return result[0] as BigInt;
  }

  /// Read an ERC-20 balance at any address.
  Future<BigInt> getERC20Balance(String tokenAddress, String owner) async {
    final contract = _contract(tokenAddress, AppABIs.erc20);
    final result = await client.call(
      contract: contract,
      function: contract.function('balanceOf'),
      params: [EthereumAddress.fromHex(owner)],
    );
    return result[0] as BigInt;
  }

  /// Read the fraction token address from any vault.
  Future<String> getVaultFractionToken(String vaultAddress) async {
    final contract = _contract(vaultAddress, AppABIs.vault);
    final result = await client.call(
      contract: contract,
      function: contract.function('fractionToken'),
      params: [],
    );
    return (result[0] as EthereumAddress).with0x;
  }

  /// Read commodity metadata from the deployed commodity vault.
  Future<List<dynamic>> getCommodityInfo(String commodityVaultAddress) async {
    final contract = _contract(commodityVaultAddress, AppABIs.commodityVault);
    final result = await client.call(
      contract: contract,
      function: contract.function('getCommodityInfo'),
      params: [],
    );
    return result;
  }

  /// Read invoice metadata from the deployed invoice vault.
  Future<List<dynamic>> getInvoiceInfo(String invoiceVaultAddress) async {
    final contract = _contract(invoiceVaultAddress, AppABIs.invoiceVault);
    final result = await client.call(
      contract: contract,
      function: contract.function('getInvoiceInfo'),
      params: [],
    );
    return result;
  }

  // =========================================================
  // WRITES
  // =========================================================

  Future<String> approveFractionToken(String spender, BigInt amount) async {
    return _sendPrivyTransaction(
      contractAddress: AppConstants.fractionToken,
      functionName: 'approve',
      params: [EthereumAddress.fromHex(spender), amount],
      abi: AppABIs.erc20,
    );
  }

  Future<String> stake(BigInt amount) async {
    return _sendPrivyTransaction(
      contractAddress: AppConstants.streamer,
      functionName: 'stake',
      params: [amount],
      abi: AppABIs.streamer,
    );
  }

  Future<String> withdraw(BigInt amount) async {
    return _sendPrivyTransaction(
      contractAddress: AppConstants.streamer,
      functionName: 'withdraw',
      params: [amount],
      abi: AppABIs.streamer,
    );
  }

  Future<String> claimYield() async {
    return _sendPrivyTransaction(
      contractAddress: AppConstants.streamer,
      functionName: 'claimYield',
      params: [],
      abi: AppABIs.streamer,
    );
  }

  // =========================================================
  // NFT + FACTORY METHODS
  // =========================================================

  Future<BigInt> getNFTTotalSupply() async {
    final contract = _contract(AppConstants.demoNft, AppABIs.erc721);
    final result = await client.call(
      contract: contract,
      function: contract.function('totalSupply'),
      params: [],
    );
    return result[0] as BigInt;
  }

  Future<String> getNFTOwner(BigInt tokenId, {int retries = 3}) async {
    final contract = _contract(AppConstants.demoNft, AppABIs.erc721);
    final fn = contract.function('ownerOf');

    for (var attempt = 0; attempt < retries; attempt++) {
      try {
        final result = await client.call(
          contract: contract,
          function: fn,
          params: [tokenId],
        );
        return (result[0] as EthereumAddress).with0x;
      } catch (_) {
        if (attempt == retries - 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    throw StateError('NFT owner lookup failed');
  }

  Future<List<BigInt>> getNFTsOwnedBy(String owner) async {
    final total = await getNFTTotalSupply();
    final owned = <BigInt>[];
    final targetOwner = owner.toLowerCase();

    for (var tokenId = BigInt.one; tokenId <= total; tokenId += BigInt.one) {
      try {
        final nftOwner = await getNFTOwner(tokenId);
        if (nftOwner.toLowerCase() == targetOwner) owned.add(tokenId);
      } catch (_) {
        // Skip missing or burned token IDs.
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return owned;
  }

  Future<String> getCollectionName(String contractAddress) async {
    final contract = _contract(contractAddress, AppABIs.erc721);
    final result = await client.call(
      contract: contract,
      function: contract.function('name'),
      params: [],
    );
    return result[0] as String;
  }

  Future<String> getCollectionSymbol(String contractAddress) async {
    final contract = _contract(contractAddress, AppABIs.erc721);
    final result = await client.call(
      contract: contract,
      function: contract.function('symbol'),
      params: [],
    );
    return result[0] as String;
  }

  Future<BigInt> getCollectionBalance(
    String contractAddress,
    String walletAddress,
  ) async {
    final contract = _contract(contractAddress, AppABIs.erc721);
    final result = await client.call(
      contract: contract,
      function: contract.function('balanceOf'),
      params: [EthereumAddress.fromHex(walletAddress)],
    );
    return result[0] as BigInt;
  }

  Future<List<BigInt>> getNFTsOfCollectionOwnedBy(
    String contractAddress,
    String walletAddress,
  ) async {
    final balance = await getCollectionBalance(contractAddress, walletAddress);
    final owned = <BigInt>[];
    final contract = _contract(contractAddress, AppABIs.erc721);
    try {
      final function = contract.function('tokenOfOwnerByIndex');
      for (var index = BigInt.zero; index < balance; index += BigInt.one) {
        final result = await client.call(
          contract: contract,
          function: function,
          params: [EthereumAddress.fromHex(walletAddress), index],
        );
        owned.add(result[0] as BigInt);
      }
      return owned;
    } catch (_) {
      for (
        var tokenId = BigInt.one;
        tokenId <= BigInt.from(100);
        tokenId += BigInt.one
      ) {
        try {
          final result = await client.call(
            contract: contract,
            function: contract.function('ownerOf'),
            params: [tokenId],
          );
          final owner = (result[0] as EthereumAddress).with0x;
          if (owner.toLowerCase() == walletAddress.toLowerCase()) {
            owned.add(tokenId);
          }
        } catch (_) {
          break;
        }
      }
      return owned;
    }
  }

  Future<String> approveNFT(BigInt tokenId, String vaultAddress) async {
    return _sendPrivyTransaction(
      contractAddress: AppConstants.demoNft,
      functionName: 'approve',
      params: [EthereumAddress.fromHex(vaultAddress), tokenId],
      abi: AppABIs.erc721,
    );
  }

  Future<String> createVault({
    required BigInt tokenId,
    required int totalFractions,
    required String name,
    required String symbol,
  }) async {
    final scaled =
        BigInt.from(totalFractions) *
        BigInt.from(10).pow(AppConstants.standardDecimals);

    return _sendPrivyTransaction(
      contractAddress: AppConstants.fractionFactory,
      functionName: 'createVault',
      params: [
        EthereumAddress.fromHex(AppConstants.demoNft),
        tokenId,
        scaled,
        name,
        symbol,
      ],
      abi: AppABIs.factory,
    );
  }

  Future<BigInt> getVaultCount() async {
    final contract = _contract(AppConstants.fractionFactory, AppABIs.factory);
    final result = await client.call(
      contract: contract,
      function: contract.function('getVaultCount'),
      params: [],
    );
    return result[0] as BigInt;
  }

  Future<String> getVaultAt(BigInt index) async {
    final contract = _contract(AppConstants.fractionFactory, AppABIs.factory);
    final result = await client.call(
      contract: contract,
      function: contract.function('getVaults'),
      params: [index, index + BigInt.one],
    );
    return (result[0] as List<EthereumAddress>).first.with0x;
  }

  /// Get the most recently deployed vault from the Factory.
  /// Used to discover the vault that was just created.
  Future<String> getLatestVault() async {
    final contract = _contract(AppConstants.fractionFactory, AppABIs.factory);

    final countFn = contract.function('getVaultCount');
    final countRes = await client.call(
      contract: contract,
      function: countFn,
      params: [],
    );
    final count = (countRes[0] as BigInt).toInt();
    if (count == 0) throw Exception('No vaults deployed');

    final getVaultsFn = contract.function('getVaults');
    final result = await client.call(
      contract: contract,
      function: getVaultsFn,
      params: [BigInt.from(count - 1), BigInt.from(count)],
    );
    final vaults = (result[0] as List)
        .map((a) => (a as EthereumAddress).with0x)
        .toList();
    return vaults.first;
  }

  Future<String> fractionalize(String vaultAddress) async {
    return _sendPrivyTransaction(
      contractAddress: vaultAddress,
      functionName: 'fractionalize',
      params: [],
      abi: AppABIs.vault,
    );
  }

  // =========================================================
  // NFT MARKETPLACE
  // =========================================================

  Future<String> listNft({
    required String nftContract,
    required BigInt tokenId,
    required BigInt price,
  }) async {
    return _sendPrivyTransaction(
      contractAddress: AppConstants.nftMarketplace,
      functionName: 'list',
      params: [EthereumAddress.fromHex(nftContract), tokenId, price],
      abi: AppABIs.marketplace,
    );
  }

  Future<String> buyNft(BigInt listingId) async {
    return _sendPrivyTransaction(
      contractAddress: AppConstants.nftMarketplace,
      functionName: 'buy',
      params: [listingId],
      abi: AppABIs.marketplace,
    );
  }

  Future<String> cancelListing(BigInt listingId) async {
    return _sendPrivyTransaction(
      contractAddress: AppConstants.nftMarketplace,
      functionName: 'cancel',
      params: [listingId],
      abi: AppABIs.marketplace,
    );
  }

  Future<String> approveMarketplaceForNft(String nftContract) async {
    return _sendPrivyTransaction(
      contractAddress: nftContract,
      functionName: 'setApprovalForAll',
      params: [EthereumAddress.fromHex(AppConstants.nftMarketplace), true],
      abi: AppABIs.erc721,
    );
  }

  Future<String> approveMarketplaceForPayment(BigInt amount) async {
    return _sendPrivyTransaction(
      contractAddress: AppConstants.mockStablecoin,
      functionName: 'approve',
      params: [EthereumAddress.fromHex(AppConstants.nftMarketplace), amount],
      abi: AppABIs.erc20,
    );
  }

  Future<Map<String, dynamic>> getListing(BigInt listingId) async {
    final contract = _contract(
      AppConstants.nftMarketplace,
      AppABIs.marketplace,
    );
    final result = await client.call(
      contract: contract,
      function: contract.function('getListing'),
      params: [listingId],
    );
    return {
      'seller': (result[0] as EthereumAddress).with0x,
      'nftContract': (result[1] as EthereumAddress).with0x,
      'tokenId': result[2] as BigInt,
      'price': result[3] as BigInt,
      'active': result[4] as bool,
    };
  }

  Future<int> getNextListingId() async {
    final contract = _contract(
      AppConstants.nftMarketplace,
      AppABIs.marketplace,
    );
    final result = await client.call(
      contract: contract,
      function: contract.function('nextListingId'),
      params: [],
    );
    return (result[0] as BigInt).toInt();
  }

  Future<List<Map<String, dynamic>>> getActiveListings() async {
    final total = await getNextListingId();
    final listings = <Map<String, dynamic>>[];
    for (var id = 1; id < total; id++) {
      final listing = await getListing(BigInt.from(id));
      if (listing['active'] as bool) {
        listings.add({...listing, 'listingId': id});
      }
    }
    return listings;
  }

  /// Mint a fresh DemoNFT to the current wallet.
  Future<String> mintDemoNFT() async {
    final address = privyService.walletAddress;
    if (address == null) throw Exception('No wallet connected');
    return _sendPrivyTransaction(
      contractAddress: AppConstants.demoNft,
      functionName: 'mint',
      params: [EthereumAddress.fromHex(address)],
      abi: AppABIs.erc721,
    );
  }

  /// Get a user's staked amount from the Streamer.
  Future<BigInt> getUserStakedAmount(String address) async {
    final contract = _contract(AppConstants.streamer, AppABIs.streamer);
    final result = await client.call(
      contract: contract,
      function: contract.function('userInfo'),
      params: [EthereumAddress.fromHex(address)],
    );
    return result[0] as BigInt;
  }

  /// Approve the Streamer to spend FractionTokens.
  Future<String> approveStreamer(BigInt amount) async {
    return _sendPrivyTransaction(
      contractAddress: AppConstants.fractionToken,
      functionName: 'approve',
      params: [EthereumAddress.fromHex(AppConstants.streamer), amount],
      abi: AppABIs.erc20,
    );
  }

  // =========================================================
  // REVENUE STREAMER (RWA) METHODS
  // =========================================================

  /// Read info from the Gold RevenueStreamer.
  Future<Map<String, dynamic>> getGoldStreamerInfo() async {
    return _getRevenueStreamerInfo(AppConstants.goldStreamer);
  }

  /// Read info from the Coffee RevenueStreamer.
  Future<Map<String, dynamic>> getCoffeeStreamerInfo() async {
    return _getRevenueStreamerInfo(AppConstants.coffeeStreamer);
  }

  /// Compatibility aliases for older Cocoa/Invoice screens.
  Future<Map<String, dynamic>> getCocoaStreamerInfo() async {
    return _getRevenueStreamerInfo(AppConstants.cocoaStreamer);
  }

  Future<Map<String, dynamic>> getInvoiceStreamerInfo() async {
    return _getRevenueStreamerInfo(AppConstants.invoiceStreamer);
  }

  /// Generic helper: read info from any RevenueStreamer.
  Future<Map<String, dynamic>> _getRevenueStreamerInfo(String address) async {
    final contract = _contract(address, AppABIs.revenueStreamer);
    final fn = contract.function('getStreamerInfo');
    final result = await client.call(
      contract: contract,
      function: fn,
      params: [],
    );
    return {
      'stakingToken': (result[0] as EthereumAddress).with0x,
      'rewardToken': (result[1] as EthereumAddress).with0x,
      'vault': (result[2] as EthereumAddress).with0x,
      'totalStaked': result[3] as BigInt,
      'rewardRate': result[4] as BigInt,
      'lifetimeRevenueReceived': result[5] as BigInt,
      'lifetimeYieldClaimed': result[6] as BigInt,
      'currentPoolBalance': result[7] as BigInt,
    };
  }

  /// Read pending yield from a RevenueStreamer for a specific user.
  Future<BigInt> getRevenueEarned(
    String streamerAddress,
    String userAddress,
  ) async {
    final contract = _contract(streamerAddress, AppABIs.revenueStreamer);
    final fn = contract.function('earned');
    final result = await client.call(
      contract: contract,
      function: fn,
      params: [EthereumAddress.fromHex(userAddress)],
    );
    return result[0] as BigInt;
  }

  /// Read a user's staked amount in a RevenueStreamer.
  Future<BigInt> getRevenueStaked(
    String streamerAddress,
    String userAddress,
  ) async {
    final contract = _contract(streamerAddress, AppABIs.revenueStreamer);
    final fn = contract.function('userInfo');
    final result = await client.call(
      contract: contract,
      function: fn,
      params: [EthereumAddress.fromHex(userAddress)],
    );
    return result[0] as BigInt;
  }

  /// Claim yield from a RevenueStreamer. Returns the transaction hash.
  Future<String> claimRevenueYield(String streamerAddress) async {
    return _sendPrivyTransaction(
      contractAddress: streamerAddress,
      functionName: 'claimYield',
      params: [],
      abi: AppABIs.revenueStreamer,
    );
  }

  /// Approve a RevenueStreamer to spend your FractionTokens.
  Future<String> approveRevenueStake(
    String fractionTokenAddress,
    String streamerAddress,
    BigInt amount,
  ) async {
    return _sendPrivyTransaction(
      contractAddress: fractionTokenAddress,
      functionName: 'approve',
      params: [EthereumAddress.fromHex(streamerAddress), amount],
      abi: AppABIs.erc20,
    );
  }

  /// Stake into a RevenueStreamer. Returns the transaction hash.
  Future<String> stakeRevenue(String streamerAddress, BigInt amount) async {
    return _sendPrivyTransaction(
      contractAddress: streamerAddress,
      functionName: 'stake',
      params: [amount],
      abi: AppABIs.revenueStreamer,
    );
  }

  /// Withdraw from a RevenueStreamer.
  Future<String> withdrawRevenue(String streamerAddress, BigInt amount) async {
    return _sendPrivyTransaction(
      contractAddress: streamerAddress,
      functionName: 'withdraw',
      params: [amount],
      abi: AppABIs.revenueStreamer,
    );
  }

  // =========================================================
  // DEMO: SIMULATE REVENUE PAYMENT (Monad-optimized)
  // =========================================================

  /// Approve the RevenueStreamer to spend mock stablecoin.
  Future<String> approveMockStablecoin(
    String streamerAddress,
    BigInt amount,
  ) async {
    return _sendPrivyTransaction(
      contractAddress: AppConstants.mockStablecoin,
      functionName: 'approve',
      params: [EthereumAddress.fromHex(streamerAddress), amount],
      abi: AppABIs.erc20,
    );
  }

  /// Deposit real revenue into a RevenueStreamer.
  Future<String> depositRevenue(String streamerAddress, BigInt amount) async {
    return _sendPrivyTransaction(
      contractAddress: streamerAddress,
      functionName: 'depositRevenue',
      params: [amount],
      abi: AppABIs.revenueStreamer,
    );
  }

  /// Compatibility waiter for the UI flow and screen-level receipt checks.
  Future<void> waitForReceipt(String txHash, {int maxAttempts = 60}) async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final receipt = await client.getTransactionReceipt(txHash);
        if (receipt != null) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw Exception('Transaction not confirmed after ${maxAttempts}s');
  }

  /// Read the user's mock stablecoin balance.
  Future<BigInt> getMockStablecoinBalance(String address) async {
    final contract = _contract(AppConstants.mockStablecoin, AppABIs.erc20);
    final fn = contract.function('balanceOf');
    final result = await client.call(
      contract: contract,
      function: fn,
      params: [EthereumAddress.fromHex(address)],
    );
    return result[0] as BigInt;
  }

  // =========================================================
  // CHAINLINK PRICE FEEDS (read from Monad Mainnet)
  // =========================================================

  /// Read the live XAU/USD (gold) price from Chainlink on Monad Mainnet.
  /// Returns a formatted string like "$2,150.42".
  Future<String> getGoldPrice() async {
    final contract = DeployedContract(
      ContractAbi.fromJson(AppABIs.chainlinkFeed, 'Aggregator'),
      EthereumAddress.fromHex(AppConstants.xauUsdFeed),
    );

    final decimalsFn = contract.function('decimals');
    final decimalsResult = await mainnetClient.call(
      contract: contract,
      function: decimalsFn,
      params: [],
    );
    final decimalsValue = decimalsResult[0];
    final decimals = decimalsValue is BigInt
        ? decimalsValue.toInt()
        : decimalsValue as int;

    final fn = contract.function('latestRoundData');
    final result = await mainnetClient.call(
      contract: contract,
      function: fn,
      params: [],
    );

    final answer = result[1] as BigInt;
    final divisor = BigInt.from(10).pow(decimals - 2);
    final scaled = answer ~/ divisor;
    final dollars = scaled ~/ BigInt.from(100);
    final cents = scaled % BigInt.from(100);

    return '\$${_formatNumber(dollars)}.${cents.toString().padLeft(2, '0')}';
  }

  String _formatNumber(BigInt n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  // =========================================================
  // EXPLORE: READ ALL VAULTS FROM FACTORY
  // =========================================================

  /// Read all deployed vaults from the Factory and their metadata.
  /// Runs the per-vault summary reads concurrently to avoid the Android
  /// ANR dialog seen when the Explore screen triggers a long sequential scan.
  Future<List<Map<String, dynamic>>> getAllVaults() async {
    final contract = _contract(AppConstants.fractionFactory, AppABIs.factory);

    // 1. Get the vault count.
    final countFn = contract.function('getVaultCount');
    final countResult = await client.call(
      contract: contract,
      function: countFn,
      params: [],
    );
    final count = (countResult[0] as BigInt).toInt();

    if (count == 0) return [];

    // 2. Get all vault addresses.
    final getVaultsFn = contract.function('getVaults');
    final vaultsResult = await client.call(
      contract: contract,
      function: getVaultsFn,
      params: [BigInt.zero, BigInt.from(count)],
    );
    final vaultAddresses = (vaultsResult[0] as List)
        .map((a) => (a as EthereumAddress).with0x)
        .toList();

    // 3. Read every vault summary in small batches so the Explore screen
    // does not swamp the emulator or main thread with a full factory scan.
    const batchSize = 3;
    final output = <Map<String, dynamic>>[];

    for (var offset = 0; offset < vaultAddresses.length; offset += batchSize) {
      final batch = vaultAddresses.skip(offset).take(batchSize).toList();
      final futures = batch.map((addr) async {
        try {
          return await getVaultSummary(addr);
        } catch (_) {
          return null;
        }
      }).toList();

      final results = await Future.wait(futures);
      for (final item in results) {
        if (item != null) output.add(item);
      }
    }

    return output;
  }

  /// Read a single vault's summary info.
  Future<Map<String, dynamic>> getVaultSummary(String vaultAddress) async {
    final vaultContract = _contract(vaultAddress, AppABIs.vault);

    final fractionTokenFn = vaultContract.function('fractionToken');
    final totalFractionsFn = vaultContract.function('totalFractions');
    final isRedeemedFn = vaultContract.function('isRedeemed');

    final fractionTokenRes = await client.call(
      contract: vaultContract,
      function: fractionTokenFn,
      params: [],
    );
    final fractionTokenAddr = (fractionTokenRes[0] as EthereumAddress).with0x;

    final totalFractionsRes = await client.call(
      contract: vaultContract,
      function: totalFractionsFn,
      params: [],
    );
    final totalFractions = totalFractionsRes[0] as BigInt;

    final isRedeemedRes = await client.call(
      contract: vaultContract,
      function: isRedeemedFn,
      params: [],
    );
    final isRedeemed = isRedeemedRes[0] as bool;

    Map<String, dynamic>? commodityInfo;
    try {
      commodityInfo = await _readCommodityInfo(vaultAddress);
    } catch (_) {}

    Map<String, dynamic>? invoiceInfo;
    try {
      invoiceInfo = await _readInvoiceInfo(vaultAddress);
    } catch (_) {}

    return {
      'address': vaultAddress,
      'fractionToken': fractionTokenAddr,
      'totalFractions': totalFractions,
      'isRedeemed': isRedeemed,
      'commodityInfo': commodityInfo,
      'invoiceInfo': invoiceInfo,
    };
  }

  Future<Map<String, dynamic>?> _readCommodityInfo(String vaultAddress) async {
    final contract = _contract(vaultAddress, AppABIs.commodityVault);
    final fn = contract.function('getCommodityInfo');
    final result = await client.call(
      contract: contract,
      function: fn,
      params: [],
    );
    return {
      'commodityType': result[0] as String,
      'quantity': result[1] as BigInt,
      'unitOfMeasure': result[2] as String,
      'storageLocation': result[3] as String,
      'auditReportURI': result[4] as String,
      'insuranceURI': result[5] as String,
      'custodian': result[6] as String,
    };
  }

  Future<Map<String, dynamic>?> _readInvoiceInfo(String vaultAddress) async {
    final contract = _contract(vaultAddress, AppABIs.invoiceVault);
    final fn = contract.function('getInvoiceInfo');
    final result = await client.call(
      contract: contract,
      function: fn,
      params: [],
    );
    return {
      'smeIssuer': (result[0] as EthereumAddress).with0x,
      'invoiceBuyer': (result[1] as EthereumAddress).with0x,
      'faceValue': result[2] as BigInt,
      'discountBps': result[3] as BigInt,
      'issueDate': result[4] as BigInt,
      'maturityDate': result[5] as BigInt,
      'isSettled': result[6] as bool,
      'totalSettled': result[7] as BigInt,
      'settlementToken': (result[8] as EthereumAddress).with0x,
      'invoiceDocumentURI': result[9] as String,
      'buyerJurisdiction': result[10] as String,
    };
  }
}
