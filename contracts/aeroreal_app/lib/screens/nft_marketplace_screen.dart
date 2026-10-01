import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import 'fraction_marketplace_screen.dart';
import '../services/contract_service.dart';
import '../services/portfolio_service.dart';
import '../services/privy_service.dart';
import '../services/watchlist_service.dart';
import '../widgets/market_overview_card.dart';
import '../widgets/nft_detail_modal.dart';
import '../widgets/nft_featured_card.dart';
import '../widgets/nft_listing_card.dart';

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
  final _watchlist = WatchlistService();
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
    _loadListings();
    _loadOwnedNfts();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _priceController.dispose();
    super.dispose();
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _listings = _demoListings;
        _error = 'Failed to load listings: $error';
        _loadingListings = false;
      });
    }
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
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'Fraction Market',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color.fromARGB(255, 74, 24, 199),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Buy', icon: Icon(Icons.shopping_cart_outlined)),
            Tab(text: 'Sell', icon: Icon(Icons.sell_outlined)),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 0, 0, 0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.trending_up,
                  color: Color(0xFF00D18A),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Floor: ${contracts.formatToken(_floorPrice)} mUSD',
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
          if (rest.isNotEmpty) ...[
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
                        const Icon(
                          Icons.check_circle,
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
                          '${contracts.formatToken(listing['price'] as BigInt)} mUSD',
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
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _buildSellTab() {
    if (_loadingOwned) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ownedNfts.isEmpty) {
      return const _EmptyState(
        text: 'No NFTs to sell. Mint one from the Create tab.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Select NFT to list',
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 12),
        RadioGroup<BigInt>(
          groupValue: _selectedNft,
          onChanged: (value) => setState(() => _selectedNft = value),
          child: Column(
            children: _ownedNfts
                .map(
                  (id) => RadioListTile<BigInt>(
                    value: id,
                    title: Text('Demo Ape #$id'),
                    activeColor: const Color.fromARGB(255, 74, 24, 199),
                  ),
                )
                .toList(),
          ),
        ),
        TextField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Price (mUSD)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        if (_status != null)
          Text(_status!, style: const TextStyle(color: Colors.white70)),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _processing ? null : _listNft,
          icon: const Icon(Icons.sell_outlined),
          label: Text(_processing ? 'Processing...' : 'List for Sale'),
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

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54),
      ),
    ),
  );
}
