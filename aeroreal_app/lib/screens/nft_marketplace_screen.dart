import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../services/contract_service.dart';
import '../services/privy_service.dart';
import '../services/portfolio_service.dart';

class NftMarketplaceScreen extends StatefulWidget {
  const NftMarketplaceScreen({super.key});

  @override
  State<NftMarketplaceScreen> createState() => _NftMarketplaceScreenState();
}

class _NftMarketplaceScreenState extends State<NftMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _priceController = TextEditingController();
  List<Map<String, dynamic>> _listings = [];
  List<BigInt> _ownedNfts = [];
  BigInt? _selectedNft;
  bool _loadingListings = true;
  bool _loadingOwned = true;
  bool _processing = false;
  String? _error;
  String? _status;

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
      final listings = await context
          .read<ContractService>()
          .getActiveListings();
      if (!mounted) {
        return;
      }
      setState(() {
        _listings = listings;
        _loadingListings = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
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
        _selectedNft = nfts.contains(_selectedNft)
            ? _selectedNft
            : (nfts.isEmpty ? null : nfts.first);
        _loadingOwned = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOwned = false);
    }
  }

  BigInt _parseTokenAmount(String input) {
    final value = input.trim();
    final parts = value.split('.');
    if (parts.length > 2 || value.isEmpty) {
      throw const FormatException('Enter a valid price');
    }
    final whole = parts.first.isEmpty ? '0' : parts.first;
    final decimals = parts.length == 1 ? '' : parts[1];
    if (decimals.length > AppConstants.standardDecimals ||
        int.tryParse(whole) == null ||
        (decimals.isNotEmpty && int.tryParse(decimals) == null)) {
      throw const FormatException('Enter a valid price');
    }
    final paddedDecimals = decimals.padRight(
      AppConstants.standardDecimals,
      '0',
    );
    return BigInt.parse(whole) *
            BigInt.from(10).pow(AppConstants.standardDecimals) +
        BigInt.parse(paddedDecimals.isEmpty ? '0' : paddedDecimals);
  }

  Future<void> _listNft() async {
    if (_selectedNft == null) {
      setState(() => _error = 'Select an NFT first');
      return;
    }
    try {
      final price = _parseTokenAmount(_priceController.text);
      if (price <= BigInt.zero) {
        throw const FormatException('Price must be greater than zero');
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
        _status = 'Listed successfully.';
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

  Future<void> _buyNft(int listingId) async {
    setState(() {
      _processing = true;
      _error = null;
      _status = 'Approving payment...';
    });
    try {
      final contracts = context.read<ContractService>();
      final listing = await contracts.getListing(BigInt.from(listingId));
      await contracts.approveMarketplaceForPayment(listing['price'] as BigInt);
      if (!mounted) return;
      setState(() => _status = 'Buying NFT...');
      await contracts.buyNft(BigInt.from(listingId));
      await PortfolioService().recordPurchase(
        assetId: 'demo-nft-$listingId',
        symbol: 'NFT',
        name: 'Demo NFT #$listingId',
        amount: 1,
        priceUsd: (listing['price'] as BigInt).toDouble() / 1e18,
      );
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'Purchased successfully.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFT Marketplace'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Buy', icon: Icon(Icons.shopping_cart_outlined)),
            Tab(text: 'Sell', icon: Icon(Icons.sell_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildBuyTab(), _buildSellTab()],
      ),
    );
  }

  Widget _buildBuyTab() {
    if (_loadingListings) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadListings,
      child: _listings.isEmpty
          ? ListView(
              children: const [_EmptyState(text: 'No active listings yet.')],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _listings.length,
              itemBuilder: (context, index) {
                final listing = _listings[index];
                final contracts = context.read<ContractService>();
                return _ListingCard(
                  tokenId: listing['tokenId'] as BigInt,
                  seller: listing['seller'] as String,
                  price: contracts.formatToken(listing['price'] as BigInt),
                  processing: _processing,
                  onBuy: () => _buyNft(listing['listingId'] as int),
                );
              },
            ),
    );
  }

  Widget _buildSellTab() {
    if (_loadingOwned) return const Center(child: CircularProgressIndicator());
    if (_ownedNfts.isEmpty) {
      return const _EmptyState(text: 'No NFTs to sell. Mint one from Create.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Select NFT', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        RadioGroup<BigInt>(
          groupValue: _selectedNft,
          onChanged: (value) => setState(() => _selectedNft = value),
          child: Column(
            children: _ownedNfts
                .map(
                  (id) => RadioListTile<BigInt>(
                    value: id,
                    title: Text('Demo Ape #$id'),
                    activeColor: const Color(0xFF836EF9),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
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
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _processing ? null : _listNft,
          icon: const Icon(Icons.sell_outlined),
          label: Text(_processing ? 'Processing...' : 'List for sale'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
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
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.tokenId,
    required this.seller,
    required this.price,
    required this.processing,
    required this.onBuy,
  });

  final BigInt tokenId;
  final String seller;
  final String price;
  final bool processing;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final shortSeller = seller.length > 12
        ? '${seller.substring(0, 8)}...'
        : seller;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demo Ape #$tokenId',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Seller: $shortSeller',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$price mUSD',
                  style: const TextStyle(
                    color: Color(0xFF00D18A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton(
                  onPressed: processing ? null : onBuy,
                  child: const Text('Buy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
