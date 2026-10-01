import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/community_nfts.dart';
import '../utils/app_icons.dart';
import '../config/constants.dart';
import '../config/simulated_nft_collections.dart';
import 'fraction_marketplace_screen.dart';
import '../services/coingecko_nft_service.dart';
import '../services/contract_service.dart';
import '../services/portfolio_service.dart';
import '../services/privy_service.dart';
import '../services/rwa_service.dart';
import '../services/user_profile_service.dart';
import '../services/watchlist_service.dart';
import '../widgets/market_overview_card.dart';
import '../widgets/nft_detail_modal.dart';
import '../widgets/nft_featured_card.dart';
import '../widgets/nft_listing_card.dart';
import '../utils/error_mapper.dart';
import '../utils/nft_image.dart';
import '../utils/number_formatting.dart';
import '../widgets/error_banner.dart';

// UI/UX: Controls marketplace tabs, filters, featured/listing cards, buy/sell
// actions, watchlist behavior, and transaction status feedback.
class NftMarketplaceScreen extends StatefulWidget {
  const NftMarketplaceScreen({super.key});

  @override
  State<NftMarketplaceScreen> createState() => _NftMarketplaceScreenState();
}

class _NftMarketplaceScreenState extends State<NftMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _priceController = TextEditingController();
  final _searchController = TextEditingController();
  final _watchlist = WatchlistService();
  final _rwaService = RwaService();
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  List<Map<String, dynamic>> _listings = [];
  List<Map<String, dynamic>> _soldListings = [];
  List<BigInt> _ownedNfts = [];
  BigInt? _selectedNft;
  String _filter = 'All';
  bool _loadingListings = true;
  bool _loadingOwned = true;
  bool _processing = false;
  String? _error;
  String? _status;
  String _nftQuery = '';
  List<Map<String, dynamic>> _nftCollections = [];
  List<Map<String, dynamic>> _liveActivities = [];
  List<TrendingNftCollection> _trendingCollections = [];
  bool _loadingNftCollections = false;
  bool _loadingLiveActivities = false;
  bool _mintingNft = false;
  final _coingeckoNftService = CoinGeckoNftService();

  static final _demoListings = [
    {
      'listingId': 42,
      'tokenId': BigInt.from(42),
      'seller': '0x9Ab8F1c42D7e',
      'price': BigInt.parse('500000000000000000000'),
    },
    {
      'listingId': 43,
      'tokenId': BigInt.from(43),
      'seller': '0x7F31a0D94b20',
      'price': BigInt.parse('85000000000000000000'),
    },
    {
      'listingId': 44,
      'tokenId': BigInt.from(44),
      'seller': '0xC40e9B1F820a',
      'price': BigInt.parse('1200000000000000000'),
    },
    {
      'listingId': 45,
      'tokenId': BigInt.from(45),
      'seller': '0x4D0a33e7F12c',
      'price': BigInt.parse('65000000000000000000'),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      final query = _searchController.text.trim();
      if (query == _nftQuery) return;
      setState(() => _nftQuery = query);
      _searchDebounce?.cancel();
      _searchDebounce = Timer(
        const Duration(milliseconds: 350),
        _searchNftCollections,
      );
    });
    _loadListings();
    _loadOwnedNfts();
    _loadLiveActivities();
    _loadTrendingCollections();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _priceController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _searchNftCollections() async {
    final query = _nftQuery;
    final requestId = ++_searchRequestId;
    if (query.isEmpty) {
      if (mounted) setState(() => _nftCollections = []);
      return;
    }
    setState(() => _loadingNftCollections = true);
    try {
      final collections = await _rwaService.searchNftCollections(query: query);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _nftCollections = collections;
        _loadingNftCollections = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _nftCollections = [];
        _loadingNftCollections = false;
      });
    }
  }

  Future<void> _loadLiveActivities() async {
    if (!mounted) return;
    setState(() => _loadingLiveActivities = true);

    try {
      final discovered = <Map<String, dynamic>>[];
      final addresses = CommunityNfts.collections
          .map((collection) => collection.address)
          .where((address) => address.isNotEmpty)
          .toSet()
          .toList();

      for (final address in addresses) {
        final response = await http
            .get(
              Uri.parse(
                '${UserProfileService.baseUrl}/api/blockvision/activity/$address',
              ),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) continue;
        final body = jsonDecode(response.body);
        if (body is! Map || body['activities'] is! List) continue;
        for (final activity in body['activities'] as List) {
          if (activity is Map) {
            discovered.add(Map<String, dynamic>.from(activity));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _liveActivities = discovered.take(5).toList();
        _loadingLiveActivities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liveActivities = [];
        _loadingLiveActivities = false;
      });
    }
  }

  Future<void> _mintSimulatedNft(Map<String, dynamic> collection) async {
    if (_mintingNft) return;
    setState(() => _mintingNft = true);
    final messenger = ScaffoldMessenger.of(context);
    final privy = context.read<PrivyService>();
    final contracts = context.read<ContractService>();
    final profile = context.read<UserProfileService>();
    try {
      final address = privy.walletAddress;
      if (address == null) throw Exception('Connect a wallet first');
      final name = (collection['name'] ?? 'Simulated NFT').toString();
      final symbol = (collection['symbol'] ?? 'NFT').toString();
      final simulatedSymbol = SimulatedNftCollections.symbolFor(name, symbol);
      final contractAddress = SimulatedNftCollections.contractFor(
        simulatedSymbol,
      );
      final result = await contracts.mintSimulatedNft(
        collectionAddress: contractAddress,
        recipient: address,
      );
      await profile.load(address);
      await profile.mintSimulatedNft(
        collectionSymbol: symbol,
        collectionName: name,
        contractAddress: contractAddress,
        tokenId: result.tokenId,
        transactionHash: result.transactionHash,
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Minted $name #${result.tokenId}!')),
        );
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.shortMessage(error)),
            backgroundColor: const Color(0xFFFF6B35),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _mintingNft = false);
    }
  }

  Future<void> _loadListings() async {
    if (mounted) setState(() => _loadingListings = true);
    try {
      final contracts = context.read<ContractService>();
      final active = await contracts.getActiveListings();
      List<Map<String, dynamic>> sold = [];
      try {
        sold = await contracts.getSoldListings();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _listings = active.isEmpty ? _demoListings : active;
        _soldListings = sold;
        _loadingListings = false;
      });
      await _loadTrendingCollections();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _listings = _demoListings;
        _error = 'Failed to load listings: $error';
        _loadingListings = false;
      });
    }
  }

  Future<void> _loadTrendingCollections() async {
    final collections = await _coingeckoNftService.getTrendingCollections(
      limit: 10,
    );
    if (!mounted) return;
    setState(() => _trendingCollections = collections);
  }

  Future<void> _loadOwnedNfts() async {
    if (mounted) setState(() => _loadingOwned = true);
    try {
      final address = context.read<PrivyService>().walletAddress;
      if (address == null) {
        if (mounted) setState(() => _loadingOwned = false);
        return;
      }
      final nfts = await context.read<ContractService>().getNFTsOwnedBy(
        address,
      );
      if (!mounted) return;
      setState(() {
        _ownedNfts = nfts;
        _selectedNft = nfts.isEmpty ? null : nfts.first;
        _loadingOwned = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOwned = false);
    }
  }

  List<Map<String, dynamic>> get _filteredListings {
    final list = List<Map<String, dynamic>>.from(_listings);
    if (_filter == 'Low to High') {
      list.sort(
        (a, b) => (a['price'] as BigInt).compareTo(b['price'] as BigInt),
      );
    } else if (_filter == 'High to Low') {
      list.sort(
        (a, b) => (b['price'] as BigInt).compareTo(a['price'] as BigInt),
      );
    } else if (_filter == 'Recently Listed') {
      list.sort(
        (a, b) => (b['listingId'] as int).compareTo(a['listingId'] as int),
      );
    }
    return list;
  }

  BigInt get _floorPrice => _listings.isEmpty
      ? BigInt.zero
      : _listings
            .map((item) => item['price'] as BigInt)
            .reduce((a, b) => a < b ? a : b);

  BigInt _parseTokenAmount(String input) {
    final value = input.trim();
    final parts = value.split('.');
    if (parts.length > 2 || value.isEmpty) {
      throw const FormatException('Enter a valid price');
    }
    final whole = parts.first.isEmpty ? '0' : parts.first;
    final decimals = parts.length == 1 ? '' : parts[1];
    if (int.tryParse(whole) == null ||
        (decimals.isNotEmpty && int.tryParse(decimals) == null) ||
        decimals.length > AppConstants.standardDecimals) {
      throw const FormatException('Enter a valid price');
    }
    return BigInt.parse(whole) * BigInt.from(10).pow(18) +
        BigInt.parse(
          decimals.padRight(18, '0').isEmpty ? '0' : decimals.padRight(18, '0'),
        );
  }

  Future<void> _buyNft(int listingId) async {
    setState(() {
      _processing = true;
      _error = null;
      _status = 'Approving payment...';
    });
    try {
      final contracts = context.read<ContractService>();
      final listing = await contracts.getListing(BigInt.from(listingId));
      final price = listing['price'] as BigInt;
      await contracts.approveMarketplaceForPayment(price);
      if (!mounted) return;
      setState(() => _status = 'Buying NFT...');
      await contracts.buyNft(BigInt.from(listingId));
      if (!mounted) return;
      await PortfolioService().recordPurchase(
        context,
        assetId: 'demo-nft-$listingId',
        symbol: 'NFT',
        name: 'Demo NFT #$listingId',
        amount: 1,
        priceUsd: price.toDouble() / 1e18,
      );
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'Purchased!';
      });
      await _loadListings();
      await _loadOwnedNfts();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = null;
        _error = 'Buy failed: $error';
      });
    }
  }

  Future<void> _listNft() async {
    if (_selectedNft == null) {
      return;
    }
    try {
      final price = _parseTokenAmount(_priceController.text);
      if (price <= BigInt.zero) {
        throw const FormatException('Enter a price greater than zero');
      }
      setState(() {
        _processing = true;
        _error = null;
        _status = 'Approving marketplace...';
      });
      final contracts = context.read<ContractService>();
      await contracts.approveMarketplaceForNft(AppConstants.demoNft);
      if (!mounted) return;
      setState(() => _status = 'Listing NFT...');
      await contracts.listNft(
        nftContract: AppConstants.demoNft,
        tokenId: _selectedNft!,
        price: price,
      );
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'Listed!';
      });
      await _loadListings();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = null;
        _error = 'List failed: $error';
      });
    }
  }

  Future<void> _toggleWatch(Map<String, dynamic> listing) async {
    await _watchlist.toggleWatchlist(context, {
      'id': 'nft-${listing['listingId']}',
      'name': 'Demo Ape #${listing['tokenId']}',
      'symbol': 'NFT',
      'price_usd': (listing['price'] as BigInt).toDouble() / 1e18,
    });
    if (mounted) setState(() {});
  }

  String _calculateSellerProceeds() {
    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) return '—';
    final fee = price * 0.01;
    final proceeds = price - fee;
    return proceeds.toStringAsFixed(2);
  }

  String _formatUsd(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(2);
  }

  String _calculateFee() {
    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) return '—';
    return (price * 0.01).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final contracts = context.read<ContractService>();
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),

      appBar: AppBar(
        title: const Text('Market'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FractionMarketplaceScreen(),
              ),
            ),
            icon: const AppIcon(AppIcons.pieChartOutline),
            tooltip: 'Fraction Market',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color.fromARGB(255, 74, 24, 199),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Buy', icon: AppIcon(AppIcons.shoppingCartOutlined)),
            Tab(text: 'Sell', icon: AppIcon(AppIcons.sellOutlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildBuyTab(contracts), _buildSellTab()],
      ),
    );
  }

  Widget _buildBuyTab(ContractService contracts) {
    if (_loadingListings) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _filteredListings;
    final featured = filtered.isEmpty ? null : filtered.first;
    final rest = filtered.length > 1
        ? filtered.sublist(1)
        : <Map<String, dynamic>>[];
    return RefreshIndicator(
      onRefresh: _loadListings,
      color: const Color.fromARGB(255, 74, 24, 199),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const MarketOverviewCard(),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search NFT collections...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const AppIcon(AppIcons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF15121E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_loadingNftCollections)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_nftCollections.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'NFT COLLECTIONS',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ..._nftCollections.map(
              (collection) => _MarketplaceNftCollectionRow(
                collection: collection,
                minting: _mintingNft,
                onMint: () => _mintSimulatedNft(collection),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 0, 0, 0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const AppIcon(
                  AppIcons.trendingUp,
                  color: Color(0xFF00D18A),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Floor: ${contracts.formatToken(_floorPrice)} AREAL',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_listings.length} listings',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Recently Listed', 'Low to High', 'High to Low']
                  .map(
                    (filter) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                        selectedColor: const Color.fromARGB(255, 74, 24, 199),
                        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                        labelStyle: TextStyle(
                          color: _filter == filter
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (featured != null) ...[
            NftFeaturedCard(
              listing: featured,
              onBuy: () => _buyNft(featured['listingId'] as int),
              onWatch: () => _toggleWatch(featured),
              onTap: () => _openDetail(featured),
            ),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TRENDING COLLECTIONS',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_trendingCollections.isNotEmpty)
                Text(
                  _trendingCollections.first.source == 'coingecko'
                      ? 'LIVE'
                      : 'FALLBACK DATA',
                  style: TextStyle(
                    color: _trendingCollections.first.source == 'coingecko'
                        ? const Color(0xFF00D18A)
                        : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _trendingCollections.isEmpty
                ? const Center(
                    child: Text(
                      'Loading trending collections...',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _trendingCollections.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final collection = _trendingCollections[i];
                      final change = collection.floorPriceChange24h;
                      final isPositive = change >= 0;

                      return GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Viewing ${collection.name}'),
                            ),
                          );
                        },
                        child: Container(
                          width: 160,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1625),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: collection.image != null
                                    ? Image.network(
                                        collection.image!,
                                        height: 100,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, progress) {
                                              if (progress == null) {
                                                return child;
                                              }
                                              return Container(
                                                height: 100,
                                                color: const Color(0xFF0D0B14),
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              );
                                            },
                                        errorBuilder: (_, _, _) => Container(
                                          height: 100,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF836EF9),
                                                Color(0xFF5C4BC7),
                                              ],
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.image,
                                            color: Colors.white30,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 100,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF836EF9),
                                              Color(0xFF5C4BC7),
                                            ],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.image,
                                          color: Colors.white30,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                collection.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${_formatUsd(collection.floorPriceUsd)} floor',
                                style: const TextStyle(
                                  color: Color(0xFF00D18A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}% (24h)',
                                style: TextStyle(
                                  color: isPositive
                                      ? const Color(0xFF00D18A)
                                      : Colors.redAccent,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'All Listings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: rest.length,
              itemBuilder: (context, index) {
                final listing = rest[index];
                return NftListingCard(
                  listing: listing,
                  onBuy: () => _buyNft(listing['listingId'] as int),
                  onTap: () => _openDetail(listing),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          if (_loadingLiveActivities || _liveActivities.isNotEmpty) ...[
            const Text(
              'LIVE ACTIVITY',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingLiveActivities)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              ..._liveActivities.map(
                (activity) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1625),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF836EF9,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.swap_horiz,
                          color: Color(0xFF836EF9),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${activity['method'] ?? 'Transfer'} · ${activity['nftName'] ?? 'Unknown NFT'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Text(
                        'just now',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
          if (_soldListings.isNotEmpty) ...[
            const Text(
              'Recently Sold',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._soldListings
                .take(5)
                .map(
                  (listing) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const AppIcon(
                          AppIcons.checkCircle,
                          color: Color(0xFF00D18A),
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Demo Ape #${listing['tokenId']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${contracts.formatToken(listing['price'] as BigInt)} AREAL',
                          style: const TextStyle(
                            color: Color(0xFF00D18A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No active listings. Be the first to sell!',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          if (_error != null)
            ErrorBanner(
              error: _error!,
              onDismiss: () => setState(() => _error = null),
              onRetry: () => setState(() => _error = null),
            ),
        ],
      ),
    );
  }

  Widget _buildSellTab() {
    final contracts = context.read<ContractService>();

    if (_loadingOwned) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_ownedNfts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_outlined,
                size: 64,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              const Text(
                'No NFTs to sell',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mint a Demo NFT from the Create tab to list it here.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'List your NFT for sale',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose an NFT, set a price in AREAL, and list it on the marketplace.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 24),
        const Text(
          'SELECT AN NFT TO LIST',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _ownedNfts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final nftId = _ownedNfts[i];
              final isSelected = _selectedNft == nftId;
              return GestureDetector(
                onTap: () => setState(() => _selectedNft = nftId),
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1625),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF836EF9)
                          : Colors.white.withValues(alpha: 0.06),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                          child: Image.network(
                            NftImage.forToken(
                              tokenId: nftId,
                              collectionSymbol: 'demo-ape',
                            ),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: const Color(0xFF0D0B14),
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.white24,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          'Ape #$nftId',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFF836EF9)
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        if (_selectedNft != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1625),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    NftImage.forToken(
                      tokenId: _selectedNft!,
                      collectionSymbol: 'demo-ape',
                    ),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: const Color(0xFF0D0B14),
                      child: const Icon(
                        Icons.image,
                        color: Colors.white24,
                        size: 80,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Demo Ape #$_selectedNft',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Owned by you',
                  style: TextStyle(color: Color(0xFF00D18A), fontSize: 12),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'LISTING PRICE (AREAL)',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1625),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  suffixText: 'AREAL',
                  suffixStyle: TextStyle(
                    color: Color(0xFF836EF9),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.trending_up,
                    color: Color(0xFF00D18A),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Floor price: ${contracts.formatToken(_floorPrice)} AREAL',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [100, 500, 1000, 5000].map((price) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _priceController.text = price.toString();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1625),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      '$price AREAL',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF836EF9).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF836EF9).withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOU WILL RECEIVE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _priceController.text.isEmpty
                    ? '— AREAL'
                    : '${_calculateSellerProceeds()} AREAL',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _priceController.text.isEmpty
                    ? 'Enter a price to see the breakdown'
                    : 'Less 1% marketplace fee (${_calculateFee()} AREAL)',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_status != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF836EF9).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF836EF9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_status!, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_error != null) ...[
          ErrorBanner(
            error: _error!,
            onDismiss: () => setState(() => _error = null),
            onRetry: () => setState(() => _error = null),
          ),
          const SizedBox(height: 16),
        ],
        ElevatedButton.icon(
          onPressed: _processing || _selectedNft == null ? null : _listNft,
          icon: const Icon(Icons.sell_outlined),
          label: const Text(
            'List for Sale',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF836EF9),
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  void _openDetail(Map<String, dynamic> listing) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => NftDetailModal(
        listing: listing,
        onBuy: () {
          Navigator.pop(context);
          _buyNft(listing['listingId'] as int);
        },
      ),
    );
  }
}

class _MarketplaceNftCollectionRow extends StatelessWidget {
  final Map<String, dynamic> collection;
  final bool minting;
  final VoidCallback onMint;

  const _MarketplaceNftCollectionRow({
    required this.collection,
    required this.minting,
    required this.onMint,
  });

  String _money(dynamic value) {
    if (value is num && value > 0) return NumberFormatting.money(value);
    return 'Not available';
  }

  @override
  Widget build(BuildContext context) {
    final name = (collection['name'] ?? 'NFT collection').toString();
    final symbol = (collection['symbol'] ?? '').toString().toUpperCase();
    final image = collection['image'] as String?;
    final imageUrl = image == null || image.isEmpty
        ? NftImage.forCollection(symbol.isEmpty ? name : symbol)
        : image;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF15121E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Image.network(
                  imageUrl,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 42,
                    height: 42,
                    child: AppIcon(AppIcons.imageOutlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      symbol.isEmpty ? 'NFT collection' : symbol,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Floor ${_money(collection['floor_price_usd'])}  ·  '
            '24h volume ${_money(collection['volume_24h_usd'])}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: minting ? null : onMint,
              icon: const AppIcon(AppIcons.add, size: 17),
              label: const Text('Mint Simulated NFT'),
            ),
          ),
        ],
      ),
    );
  }
}
