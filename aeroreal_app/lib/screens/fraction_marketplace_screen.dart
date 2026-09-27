import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../services/contract_service.dart';
import '../services/privy_service.dart';

class FractionMarketplaceScreen extends StatefulWidget {
  const FractionMarketplaceScreen({super.key});

  @override
  State<FractionMarketplaceScreen> createState() =>
      _FractionMarketplaceScreenState();
}

class _FractionMarketplaceScreenState extends State<FractionMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Map<String, dynamic>> _listings = [];
  bool _loadingListings = true;
  bool _processing = false;
  String? _error;
  String? _status;

  String _sellAsset = 'Gold';
  final _amountController = TextEditingController(text: '1000');
  final _priceController = TextEditingController(text: '50');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadListings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadListings() async {
    if (!mounted) return;
    setState(() => _loadingListings = true);
    try {
      final listings = await context
          .read<ContractService>()
          .getActiveFractionListings();
      if (!mounted) return;
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

  Future<void> _listFractions() async {
    final amountText = _amountController.text.trim();
    final priceText = _priceController.text.trim();
    if (amountText.isEmpty || priceText.isEmpty) {
      setState(() => _error = 'Enter both amount and price.');
      return;
    }

    String fractionToken;
    switch (_sellAsset) {
      case 'Gold':
        fractionToken = AppConstants.goldFractionToken;
        break;
      case 'Coffee':
        fractionToken = AppConstants.coffeeFractionToken;
        break;
      case 'Treasury':
        fractionToken = AppConstants.treasuryFractionToken;
        break;
      default:
        fractionToken = AppConstants.goldFractionToken;
    }

    try {
      final amount = BigInt.parse(amountText) * BigInt.from(10).pow(18);
      final price = BigInt.parse(priceText) * BigInt.from(10).pow(18);

      setState(() {
        _processing = true;
        _error = null;
        _status = 'Approving marketplace...';
      });

      final contracts = context.read<ContractService>();
      await contracts.approveFractionToken(
        fractionToken,
        AppConstants.fractionMarketplace,
        amount,
      );

      if (!mounted) return;
      setState(() => _status = 'Listing fractions...');
      await contracts.listFractions(
        fractionToken: fractionToken,
        amount: amount,
        price: price,
      );

      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'Listed successfully!';
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

  Future<void> _buyFraction(int listingId) async {
    setState(() {
      _processing = true;
      _status = 'Buying...';
      _error = null;
    });
    try {
      final contracts = context.read<ContractService>();
      await contracts.buyFractions(BigInt.from(listingId));
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'Purchased successfully!';
      });
      await _loadListings();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = null;
        _error = 'Buy failed: $error';
      });
    }
  }

  Future<void> _cancelFraction(int listingId) async {
    setState(() {
      _processing = true;
      _status = 'Cancelling...';
      _error = null;
    });
    try {
      final contracts = context.read<ContractService>();
      await contracts.cancelFractionListing(BigInt.from(listingId));
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'Cancelled.';
      });
      await _loadListings();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = null;
        _error = 'Cancel failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraction Market'),
        bottom: TabBar(
          controller: _tabController,
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
        controller: _tabController,
        children: [_buildBuyTab(), _buildSellTab()],
      ),
    );
  }

  Widget _buildBuyTab() {
    final privy = context.read<PrivyService>();

    if (_loadingListings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_listings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No fraction listings yet. \\nBe the first to sell!',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadListings,
      color: const Color.fromARGB(255, 74, 24, 199),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _listings.length,
        itemBuilder: (context, index) {
          final listing = _listings[index];
          final amount = listing['amount'] as BigInt;
          final price = listing['price'] as BigInt;
          final seller = (listing['seller'] as String).substring(0, 10);
          final isOwner =
              privy.walletAddress?.toLowerCase() ==
              (listing['seller'] as String).toLowerCase();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 0, 0, 0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.pie_chart,
                      color: Color(0xFF836EF9),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${amount ~/ BigInt.from(10).pow(18)} fractions',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Seller: $seller...',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${price ~/ BigInt.from(10).pow(18)} mUSD',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00D18A),
                      ),
                    ),
                    if (isOwner)
                      OutlinedButton(
                        onPressed: _processing
                            ? null
                            : () =>
                                  _cancelFraction(listing['listingId'] as int),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        child: const Text('Cancel'),
                      )
                    else
                      ElevatedButton(
                        onPressed: _processing
                            ? null
                            : () => _buyFraction(listing['listingId'] as int),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D18A),
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Buy'),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSellTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'List Fractions for Sale',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose which asset you want to sell fractions of, set a price, and list.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 24),
        const Text(
          'Asset',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 0, 0, 0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: _sellAsset,
            isExpanded: true,
            dropdownColor: const Color.fromARGB(255, 0, 0, 0),
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'Gold', child: Text('Gold (fGOLD)')),
              DropdownMenuItem(
                value: 'Coffee',
                child: Text('Coffee (fCOFFEE)'),
              ),
              DropdownMenuItem(
                value: 'Treasury',
                child: Text('Treasury (fTBILL)'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _sellAsset = value);
              }
            },
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount to sell (fractions)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Price (mUSD)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        if (_status != null) ...[
          Text(_status!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          onPressed: _processing ? null : _listFractions,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 74, 24, 199),
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          child: _processing
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('List for Sale', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
