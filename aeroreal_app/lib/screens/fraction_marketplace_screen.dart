import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../services/contract_service.dart';
import '../services/privy_service.dart';
import '../utils/app_icons.dart';
import '../widgets/error_banner.dart';

class FractionMarketplaceScreen extends StatefulWidget {
  const FractionMarketplaceScreen({super.key});

  @override
  State<FractionMarketplaceScreen> createState() =>
      _FractionMarketplaceScreenState();
}

class _FractionMarketplaceScreenState extends State<FractionMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  static final BigInt _tokenUnit = BigInt.from(10).pow(18);
  static const Color _accent = Color(0xFF836EF9);
  static const Color _surface = Color(0xFF1A1625);

  late final TabController _tabController;
  final _amountController = TextEditingController(text: '1000');
  final _priceController = TextEditingController(text: '50');

  List<Map<String, dynamic>> _listings = [];
  BigInt _goldBalance = BigInt.zero;
  BigInt _coffeeBalance = BigInt.zero;
  BigInt _treasuryBalance = BigInt.zero;
  bool _loadingListings = true;
  bool _processing = false;
  String _sellAsset = 'Gold';
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadListings(), _loadBalances()]);
  }

  Future<void> _loadListings() async {
    if (!mounted) return;
    setState(() {
      _loadingListings = true;
      _error = null;
    });
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
        _error = 'Could not load listings: $error';
        _loadingListings = false;
      });
    }
  }

  Future<void> _loadBalances() async {
    final address = context.read<PrivyService>().walletAddress;
    if (address == null) return;
    try {
      final contracts = context.read<ContractService>();
      final balances = await Future.wait([
        contracts.getGoldFractionBalance(address),
        contracts.getCoffeeFractionBalance(address),
        contracts.getTreasuryFractionBalance(address),
      ]);
      if (!mounted) return;
      setState(() {
        _goldBalance = balances[0];
        _coffeeBalance = balances[1];
        _treasuryBalance = balances[2];
      });
    } catch (_) {
      // A balance read should not prevent browsing active listings.
    }
  }

  BigInt get _selectedBalance => switch (_sellAsset) {
    'Gold' => _goldBalance,
    'Coffee' => _coffeeBalance,
    'Treasury' => _treasuryBalance,
    _ => BigInt.zero,
  };

  String get _selectedSymbol => switch (_sellAsset) {
    'Gold' => 'fGOLD',
    'Coffee' => 'fCOFFEE',
    'Treasury' => 'fTBILL',
    _ => 'fGOLD',
  };

  String get _selectedTokenAddress => switch (_sellAsset) {
    'Gold' => AppConstants.goldFractionToken,
    'Coffee' => AppConstants.coffeeFractionToken,
    'Treasury' => AppConstants.treasuryFractionToken,
    _ => AppConstants.goldFractionToken,
  };

  BigInt? _parseTokenAmount(String input) {
    final value = input.trim();
    final parts = value.split('.');
    if (parts.length > 2 ||
        parts.first.isEmpty ||
        !RegExp(r'^\d+$').hasMatch(parts.first) ||
        (parts.length == 2 &&
            (parts[1].length > 18 ||
                (parts[1].isNotEmpty &&
                    !RegExp(r'^\d+$').hasMatch(parts[1]))))) {
      return null;
    }
    final fraction = parts.length == 2 ? parts[1].padRight(18, '0') : '';
    return BigInt.parse(parts.first) * _tokenUnit +
        (fraction.isEmpty ? BigInt.zero : BigInt.parse(fraction));
  }

  String _formatTokenInput(BigInt raw) {
    final whole = raw ~/ _tokenUnit;
    final fraction = (raw % _tokenUnit).toString().padLeft(18, '0');
    final trimmedFraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    return trimmedFraction.isEmpty ? '$whole' : '$whole.$trimmedFraction';
  }

  String _formatNetProceeds() {
    final price = _parseTokenAmount(_priceController.text);
    if (price == null || price <= BigInt.zero) return '—';
    return _formatTokenInput(price * BigInt.from(99) ~/ BigInt.from(100));
  }

  String _formatFee() {
    final price = _parseTokenAmount(_priceController.text);
    if (price == null || price <= BigInt.zero) return '—';
    return _formatTokenInput(price ~/ BigInt.from(100));
  }

  void _setAmountPercent(int percent) {
    final amount = _selectedBalance * BigInt.from(percent) ~/ BigInt.from(100);
    _amountController.text = _formatTokenInput(amount);
    setState(() {});
  }

  Future<void> _listFractions() async {
    final amount = _parseTokenAmount(_amountController.text);
    final price = _parseTokenAmount(_priceController.text);
    if (amount == null || amount <= BigInt.zero) {
      setState(() => _error = 'Enter a valid amount greater than zero.');
      return;
    }
    if (amount > _selectedBalance) {
      setState(() => _error = 'Amount exceeds your available balance.');
      return;
    }
    if (price == null || price <= BigInt.zero) {
      setState(() => _error = 'Enter a valid price greater than zero.');
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
      _status = 'Approving and listing fractions...';
    });
    try {
      await context.read<ContractService>().listFractions(
        fractionToken: _selectedTokenAddress,
        amount: amount,
        price: price,
      );
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'Fractions listed successfully.';
      });
      await _loadAll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = null;
        _error = 'Listing failed: $error';
      });
    }
  }

  Future<void> _buy(int listingId) async {
    setState(() {
      _processing = true;
      _error = null;
      _status = 'Buying fractions...';
    });
    try {
      await context.read<ContractService>().buyFractions(
        BigInt.from(listingId),
      );
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'Fractions purchased.';
      });
      await _loadListings();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = null;
        _error = 'Purchase failed: $error';
      });
    }
  }

  Future<void> _cancel(int listingId) async {
    setState(() {
      _processing = true;
      _error = null;
      _status = 'Cancelling listing...';
    });
    try {
      await context.read<ContractService>().cancelFractionListing(
        BigInt.from(listingId),
      );
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'Listing cancelled.';
      });
      await _loadListings();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = null;
        _error = 'Cancellation failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final contracts = context.read<ContractService>();
    final privy = context.read<PrivyService>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Fraction Market'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Buy', icon: AppIcon(AppIcons.shoppingCartOutlined)),
            Tab(text: 'Sell', icon: AppIcon(AppIcons.sellOutlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildBuyTab(contracts, privy), _buildSellTab(contracts)],
      ),
    );
  }

  Widget _buildBuyTab(ContractService contracts, PrivyService privy) {
    if (_loadingListings) {
      return const Center(child: CircularProgressIndicator());
    }
    final floor = _listings.isEmpty
        ? '—'
        : contracts.formatToken(
            _listings
                .map((listing) => listing['price'] as BigInt)
                .reduce((a, b) => a < b ? a : b),
          );

    return RefreshIndicator(
      onRefresh: _loadListings,
      color: _accent,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Fraction Market',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Buy fractions of real-world assets with AREAL.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _panel(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _stat('FLOOR PRICE', '$floor AREAL'),
                _stat('ACTIVE LISTINGS', '${_listings.length}', alignEnd: true),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(
              error: _error!,
              onDismiss: () => setState(() => _error = null),
              onRetry: () => setState(() => _error = null),
            ),
          ],
          if (_status != null) ...[
            const SizedBox(height: 12),
            _feedback(_status!, busy: _processing),
          ],
          const SizedBox(height: 20),
          if (_listings.isEmpty)
            _panel(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(
                    Icons.pie_chart_outline,
                    size: 44,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No listings yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Be the first to list fractions for sale.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.sell_outlined),
                    label: const Text('List Fractions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._listings.map((listing) {
              final amount = contracts.formatToken(listing['amount'] as BigInt);
              final price = contracts.formatToken(listing['price'] as BigInt);
              final seller = listing['seller'] as String;
              final shortSeller = seller.length > 12
                  ? '${seller.substring(0, 10)}...'
                  : seller;
              final isOwner =
                  privy.walletAddress?.toLowerCase() == seller.toLowerCase();
              final asset = _assetNameForAddress(
                listing['fractionToken'] as String? ?? '',
              );
              return _panel(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_assetIcon(asset), color: _assetColor(asset)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$asset fractions',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$amount ${_assetSymbol(asset)} · $shortSeller',
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
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$price AREAL',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00D18A),
                          ),
                        ),
                        if (isOwner)
                          OutlinedButton(
                            onPressed: _processing
                                ? null
                                : () => _cancel(listing['listingId'] as int),
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
                                : () => _buy(listing['listingId'] as int),
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
            }),
          const SizedBox(height: 8),
          const Text(
            'HOW IT WORKS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _panel(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepLine(number: '01', text: 'Find an RWA vault'),
                _StepLine(number: '02', text: 'Buy fractions with AREAL'),
                _StepLine(number: '03', text: 'Sell fractions anytime'),
                _StepLine(number: '04', text: 'Track holdings in Portfolio'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellTab(ContractService contracts) {
    final balance = contracts.formatToken(_selectedBalance);
    final amount = _parseTokenAmount(_amountController.text) ?? BigInt.zero;
    final amountExceedsBalance = amount > _selectedBalance;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'List your fractions',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sell a portion of your RWA holdings for AREAL.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _sectionLabel('SELECT AN ASSET'),
        const SizedBox(height: 12),
        Row(
          children: [
            _assetTile(
              'Gold',
              'fGOLD',
              Icons.workspace_premium,
              const Color(0xFFFFD166),
              _goldBalance,
            ),
            const SizedBox(width: 8),
            _assetTile(
              'Coffee',
              'fCOFFEE',
              Icons.coffee,
              const Color(0xFFD99A72),
              _coffeeBalance,
            ),
            const SizedBox(width: 8),
            _assetTile(
              'Treasury',
              'fTBILL',
              Icons.account_balance,
              const Color(0xFF77C9AE),
              _treasuryBalance,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('YOUR HOLDINGS'),
              const SizedBox(height: 8),
              Text(
                '$balance $_selectedSymbol',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel('AMOUNT TO SELL'),
        const SizedBox(height: 10),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: _selectedSymbol,
                  suffixStyle: const TextStyle(
                    color: _accent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const Divider(color: Colors.white12),
              Text(
                'Available: $balance $_selectedSymbol',
                style: TextStyle(
                  color: amountExceedsBalance
                      ? Colors.redAccent
                      : Colors.white54,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _percentButton('25%', 25),
                  const SizedBox(width: 6),
                  _percentButton('50%', 50),
                  const SizedBox(width: 6),
                  _percentButton('75%', 75),
                  const SizedBox(width: 6),
                  _percentButton('MAX', 100),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel('LISTING PRICE (AREAL)'),
        const SizedBox(height: 10),
        _panel(
          child: TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: '0',
              suffixText: 'AREAL',
              suffixStyle: TextStyle(
                color: Color(0xFF00D18A),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF00D18A).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00D18A).withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('ESTIMATED PROCEEDS'),
              const SizedBox(height: 8),
              Text(
                '${_formatNetProceeds()} AREAL',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'After 1% marketplace fee (${_formatFee()} AREAL)',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        if (_status != null) ...[
          const SizedBox(height: 14),
          _feedback(_status!, busy: _processing),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          _feedback(_error!, isError: true),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed:
                _processing ||
                    _selectedBalance == BigInt.zero ||
                    amountExceedsBalance
                ? null
                : _listFractions,
            icon: const Icon(Icons.sell_outlined),
            label: const Text(
              'List for Sale',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_selectedBalance == BigInt.zero) ...[
          const SizedBox(height: 12),
          const Text(
            'You need to hold fractions to list them. Get some from the Faucet or buy them in the marketplace.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _assetTile(
    String name,
    String symbol,
    IconData icon,
    Color color,
    BigInt balance,
  ) {
    final selected = _sellAsset == name;
    final balanceText = context.read<ContractService>().formatToken(balance);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$name, $balanceText $symbol',
        child: InkWell(
          onTap: () => setState(() => _sellAsset = name),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 114),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? _accent
                    : Colors.white.withValues(alpha: 0.08),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 7),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  balanceText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                if (selected)
                  const Text(
                    'SELECTED',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _percentButton(String label, int percent) => Expanded(
    child: TextButton(
      onPressed: () => _setAmountPercent(percent),
      style: TextButton.styleFrom(
        backgroundColor: _accent.withValues(alpha: 0.14),
        foregroundColor: _accent,
        padding: const EdgeInsets.symmetric(vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    ),
  );

  Widget _panel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    EdgeInsetsGeometry? margin,
  }) => Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    ),
    child: child,
  );

  Widget _stat(String label, String value, {bool alignEnd = false}) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    ],
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white54,
      fontSize: 10,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _feedback(String text, {bool busy = false, bool isError = false}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (isError ? Colors.redAccent : _accent).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (busy) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _accent,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isError ? Colors.redAccent : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      );

  String _assetNameForAddress(String address) {
    final normalized = address.toLowerCase();
    if (normalized == AppConstants.goldFractionToken.toLowerCase()) {
      return 'Gold';
    }
    if (normalized == AppConstants.coffeeFractionToken.toLowerCase()) {
      return 'Coffee';
    }
    if (normalized == AppConstants.treasuryFractionToken.toLowerCase()) {
      return 'Treasury';
    }
    return 'RWA';
  }

  String _assetSymbol(String asset) => switch (asset) {
    'Gold' => 'fGOLD',
    'Coffee' => 'fCOFFEE',
    'Treasury' => 'fTBILL',
    _ => 'fractions',
  };

  IconData _assetIcon(String asset) => switch (asset) {
    'Gold' => Icons.workspace_premium,
    'Coffee' => Icons.coffee,
    'Treasury' => Icons.account_balance,
    _ => Icons.pie_chart_outline,
  };

  Color _assetColor(String asset) => switch (asset) {
    'Gold' => const Color(0xFFFFD166),
    'Coffee' => const Color(0xFFD99A72),
    'Treasury' => const Color(0xFF77C9AE),
    _ => _accent,
  };
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Color(0xFF836EF9),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    ),
  );
}
