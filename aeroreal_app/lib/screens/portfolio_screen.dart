import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/app_icons.dart';
import 'package:provider/provider.dart';

import '../services/contract_service.dart';
import '../services/blockvision_service.dart';
import '../services/portfolio_service.dart';
import '../services/privy_service.dart';
import '../services/rwa_service.dart';
import '../services/user_profile_service.dart';
import '../services/wallet_service.dart';
import '../services/zerion_service.dart';
import '../utils/number_formatting.dart';
import '../widgets/asset_image_avatar.dart';
import '../widgets/error_banner.dart';

// UI/UX: Controls portfolio summary cards, PnL, allocation, chart ranges,
// holdings, chain balances, refresh, and live/demo fallback states.
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _portfolio = PortfolioService();
  final _rwa = RwaService();
  final _zerionService = ZerionService();
  final _blockvisionService = BlockVisionService();
  Map<String, dynamic> _costBasis = {};
  Map<String, double> _prices = {};
  List<Map<String, dynamic>> _snapshots = [];
  BigInt _mon = BigInt.zero;
  BigInt _fractions = BigInt.zero;
  BigInt _sprinkle = BigInt.zero;
  BigInt _gold = BigInt.zero;
  Map<String, Map<String, dynamic>> _simulatedHoldings = {};
  List<Map<String, dynamic>> _simulatedNfts = [];
  List<ZerionNft> _realMonadNfts = [];
  List<BlockVisionCollection> _blockvisionNfts = [];
  Map<String, double> _simPrices = {};
  double _simulatedValueUsd = 0;
  double _value = 0;
  double _cost = 0;
  bool _loading = true;
  String? _error;
  bool _demoMode = false;
  String _range = '1M';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _realMonadNfts = [];
      _blockvisionNfts = [];
    });
    try {
      final privy = context.read<PrivyService>();
      final address = privy.walletAddress;
      if (address == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _demoMode = true;
          _value = 12450.82;
          _cost = 12108.64;
          _mon = BigInt.from(6004300000000000000);
          _fractions = BigInt.parse('10000000000000000000000');
          _sprinkle = BigInt.parse('142500000000000000000');
          _gold = BigInt.parse('10000000000000000000000');
          _simulatedHoldings = {};
          _simulatedNfts = [];
          _realMonadNfts = [];
          _blockvisionNfts = [];
          _simPrices = {};
          _simulatedValueUsd = 0;
          _snapshots = _demoSnapshots;
        });
        return;
      }
      final contracts = context.read<ContractService>();
      final profileService = context.read<UserProfileService>();
      final wallet = context.read<WalletService>();
      await profileService.load(address);
      if (!mounted) return;
      final results = await Future.wait([
        wallet.getMonBalance(ownerAddress: address),
        contracts.getFractionBalance(address),
        contracts.getSprinkleBalance(address),
        contracts.getGoldFractionBalance(address),
      ]);
      if (!mounted) return;
      final savedBasis = await _portfolio.getCostBasis(context);
      final basis = Map<String, dynamic>.fromEntries(
        savedBasis.entries.where(
          (entry) => !entry.key.startsWith('simulated:'),
        ),
      );
      final prices = <String, double>{};
      for (final entry in basis.entries) {
        final quote = await _rwa.getQuote(entry.key);
        if (quote['price_usd'] is num) {
          prices[entry.key] = (quote['price_usd'] as num).toDouble();
        }
      }
      var value = 0.0;
      var cost = 0.0;
      for (final entry in basis.entries) {
        final data = entry.value as Map<String, dynamic>;
        final amount = (data['total_amount'] as num).toDouble();
        final entryCost = (data['total_cost_usd'] as num).toDouble();
        value += amount * (prices[entry.key] ?? 0);
        cost += entryCost;
      }

      final profileHoldings = profileService.simulatedHoldings;
      final profileNfts = profileService.simulatedNfts
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final simulated = <String, Map<String, dynamic>>{};
      for (final entry in profileHoldings.entries) {
        simulated[entry.key] = Map<String, dynamic>.from(entry.value as Map);
      }
      final simulatedValuation = await _computeSimulatedValue(simulated);
      for (final entry in simulated.entries) {
        final data = entry.value;
        cost += (data['totalCostAreal'] as num?)?.toDouble() ?? 0;
      }

      await _portfolio.recordSnapshot(value + simulatedValuation.value);
      final snapshots = await _portfolio.getSnapshots();
      if (!mounted) return;
      setState(() {
        _mon = results[0];
        _fractions = results[1];
        _sprinkle = results[2];
        _gold = results[3];
        _simulatedHoldings = simulated;
        _simulatedNfts = profileNfts;
        _simPrices = simulatedValuation.prices;
        _simulatedValueUsd = simulatedValuation.value;
        _costBasis = basis;
        _prices = prices;
        _value = value;
        _cost = cost;
        _snapshots = snapshots;
        _loading = false;
        _demoMode = false;
      });
      _loadRealMonadNfts(address);
      _loadBlockVisionNfts(address);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load portfolio: $error';
        _loading = false;
      });
    }
  }

  Future<void> _loadRealMonadNfts(String address) async {
    final nfts = await _zerionService.getWalletNfts(address);
    if (!mounted) return;
    setState(() => _realMonadNfts = nfts);
  }

  Future<void> _loadBlockVisionNfts(String address) async {
    final collections = await _blockvisionService.getWalletNfts(address);
    if (!mounted) return;
    setState(() => _blockvisionNfts = collections);
  }

  Future<({double value, Map<String, double> prices})> _computeSimulatedValue(
    Map<String, Map<String, dynamic>> holdings,
  ) async {
    if (holdings.isEmpty) {
      return (value: 0.0, prices: <String, double>{});
    }

    final idBySymbol = <String, String>{};
    for (final entry in holdings.entries) {
      final configuredId = (entry.value['coingeckoId'] as String?)?.trim();
      idBySymbol[entry.key] = configuredId == null || configuredId.isEmpty
          ? entry.key.toLowerCase()
          : configuredId;
    }

    final prices = <String, double>{};
    try {
      final response = await http
          .get(
            Uri.https('api.coingecko.com', '/api/v3/simple/price', {
              'ids': idBySymbol.values.toSet().join(','),
              'vs_currencies': 'usd',
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        for (final entry in idBySymbol.entries) {
          final quote = data[entry.value];
          final price = quote is Map ? quote['usd'] : null;
          if (price is num && price > 0) {
            prices[entry.key] = price.toDouble();
          }
        }
      }
    } catch (_) {}

    var value = 0.0;
    for (final entry in holdings.entries) {
      final amount = (entry.value['totalAmount'] as num?)?.toDouble() ?? 0;
      final price =
          prices[entry.key] ??
          (entry.value['avgPrice'] as num?)?.toDouble() ??
          0;
      value += amount * price;
    }
    return (value: value, prices: prices);
  }

  static final _demoSnapshots = [
    {'value': 11780.0},
    {'value': 11840.0},
    {'value': 11920.0},
    {'value': 11890.0},
    {'value': 12040.0},
    {'value': 12120.0},
    {'value': 12280.0},
    {'value': 12450.82},
  ];

  static const _demoHoldings = [
    (
      'Gold Certificate',
      '10,000 fractions',
      '\$2,150.42',
      '+\$120.20 (+5.9%)',
      Color(0xFFE4A84B),
      AppIcons.workspacePremium,
    ),
    (
      'Coffee Batch',
      '5,000 fractions',
      '\$1,850.00',
      '-\$50.00 (-2.6%)',
      Color(0xFF9B6A4A),
      AppIcons.coffee,
    ),
    (
      'Demo NFT',
      '1 NFT',
      '\$500.00',
      '+\$50.00 (+11.1%)',
      Color(0xFF836EF9),
      AppIcons.imageOutlined,
    ),
    (
      'USDC',
      '500 USDC',
      '\$500.00',
      '\$0.00 (0%)',
      Color(0xFF00D18A),
      AppIcons.attachMoney,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final realNftValue = _realMonadNfts.fold<double>(
      0,
      (total, nft) => total + (nft.floorPriceUsd ?? 0),
    );
    final totalValue = _value + _simulatedValueUsd + realNftValue;
    final pnl = totalValue - _cost;
    final pnlPercent = _cost > 0 ? pnl / _cost * 100 : 0.0;
    final positive = pnl >= 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Portfolio',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh portfolio',
            icon: const AppIcon(AppIcons.refresh, color: Color(0xFF9587B8)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color.fromARGB(255, 74, 24, 199),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _summaryCard(totalValue, pnl, pnlPercent, positive),
                  const SizedBox(height: 20),
                  _allocationCard(),
                  const SizedBox(height: 20),
                  _performanceCard(),
                  const SizedBox(height: 20),
                  _sectionTitle(
                    'HOLDINGS',
                    trailing:
                        '${_demoMode ? 4 : _costBasis.length + _simulatedHoldings.length + _simulatedNfts.length + _realMonadNfts.length + _blockvisionNfts.length} assets',
                  ),
                  if (_demoMode)
                    ..._demoHoldings.map(_demoHoldingCard)
                  else if (_costBasis.isEmpty &&
                      _simulatedHoldings.isEmpty &&
                      _simulatedNfts.isEmpty &&
                      _realMonadNfts.isEmpty &&
                      _blockvisionNfts.isEmpty)
                    _emptyCard(
                      'No holdings yet. Buy an asset to start tracking PnL.',
                    )
                  else
                    ..._costBasis.entries.map(_holdingCard),
                  if (_blockvisionNfts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _sectionTitle(
                      'MONAD NFTS · BLOCKVISION',
                      trailing: '${_blockvisionNfts.length} collections',
                    ),
                    ..._blockvisionNfts.expand(
                      (collection) => collection.items
                          .take(5)
                          .map((item) => _blockVisionNftCard(collection, item)),
                    ),
                  ],
                  if (_realMonadNfts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'MONAD NFTS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._realMonadNfts.take(10).map(_realMonadNftCard),
                  ],
                  if (_simulatedHoldings.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'SIMULATED ASSETS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._simulatedHoldings.entries.map((entry) {
                      final symbol = entry.key;
                      final data = entry.value;
                      final amount =
                          (data['totalAmount'] as num?)?.toDouble() ?? 0;
                      final cost =
                          (data['totalCostAreal'] as num?)?.toDouble() ?? 0;
                      final simPrice = _simPrices[symbol];
                      final simValue = simPrice == null
                          ? null
                          : amount * simPrice;
                      final simPnl = simValue == null ? null : simValue - cost;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1625),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                AssetImageAvatar(
                                  imageUrl: data['imageUrl']?.toString(),
                                  seed: (data['symbol'] ?? symbol).toString(),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  's$symbol',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${amount.toStringAsFixed(4)} $symbol',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (simValue != null)
                                  Text(
                                    _money(simValue),
                                    style: const TextStyle(
                                      color: Color(0xFF00D18A),
                                      fontSize: 12,
                                    ),
                                  ),
                                if (simPnl != null)
                                  Text(
                                    '${simPnl >= 0 ? '+' : '-'}${_money(simPnl.abs())}',
                                    style: TextStyle(
                                      color: simPnl >= 0
                                          ? const Color(0xFF00D18A)
                                          : Colors.redAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                Text(
                                  'Cost: ${cost.toStringAsFixed(2)} AREAL',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (_simulatedNfts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'SIMULATED NFTS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._simulatedNfts.map(_simulatedNftCard),
                  ],
                  const SizedBox(height: 20),
                  _sectionTitle('CHAIN BALANCES'),
                  _balanceRow('MON (gas)', _mon),
                  _balanceRow('fMDAPE (fractions)', _fractions),
                  _balanceRow('AREAL (rewards)', _sprinkle),
                  _balanceRow('fGOLD (gold fractions)', _gold),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    ErrorBanner(
                      error: _error!,
                      onDismiss: () => setState(() => _error = null),
                      onRetry: () => setState(() => _error = null),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(
    double totalValue,
    double pnl,
    double percent,
    bool positive,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/card2.png'),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00D18A).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL VALUE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _money(totalValue),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '${positive ? '+' : ''}${_money(pnl)} (${percent.toStringAsFixed(2)}%) all time',
            style: TextStyle(
              color: positive ? const Color(0xFF00D18A) : Colors.redAccent,
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              AppIcon(AppIcons.link, size: 14, color: Colors.white70),
              SizedBox(width: 6),
              Text(
                'On Monad Testnet',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _allocationCard() {
    const entries = [
      ('NFTs', '45%', Color(0xFF836EF9)),
      ('Commodities', '35%', Color(0xFFE4A84B)),
      ('Stablecoins', '15%', Color(0xFF00D18A)),
      ('Invoices', '5%', Color(0xFF5690C9)),
    ];
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeading('Allocation', 'By Asset Type'),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 42,
                    sectionsSpace: 3,
                    sections: entries
                        .map(
                          (entry) => PieChartSectionData(
                            value: double.parse(entry.$2.replaceAll('%', '')),
                            color: entry.$3,
                            radius: 28,
                            showTitle: false,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: entries
                      .map(
                        (entry) => _Legend(
                          color: entry.$3,
                          label: '${entry.$1}  ${entry.$2}',
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _performanceCard() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeading('30-Day Performance', null),
          const SizedBox(height: 14),
          SizedBox(height: 150, child: _performanceChart()),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['AUG 22', 'AUG 29', 'SEP 05', 'SEP 12', 'SEP 20']
                .map(
                  (date) => Text(
                    date,
                    style: const TextStyle(
                      color: Color(0xFF746B83),
                      fontSize: 9,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['1D', '1W', '1M', '1Y', 'All']
                .map(
                  (range) => GestureDetector(
                    onTap: () => setState(() => _range = range),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _range == range
                            ? const Color.fromARGB(255, 74, 24, 199)
                            : const Color(0xFF211B31),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        range,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _range == range
                              ? Colors.white
                              : const Color(0xFF837C95),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 0, 0, 0),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: child,
  );

  Widget _cardHeading(String title, String? subtitle) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      if (subtitle != null)
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF837C95), fontSize: 11),
        ),
    ],
  );

  Widget _performanceChart() {
    final values = _snapshots
        .map((item) => (item['value'] as num).toDouble())
        .toList();
    if (values.length < 2) {
      return _emptyCard(
        'Performance history will appear after more portfolio refreshes.',
      );
    }
    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: values
                  .asMap()
                  .entries
                  .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
                  .toList(),
              color: const Color(0xFF00D18A),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF00D18A).withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _holdingCard(MapEntry<String, dynamic> entry) {
    final data = entry.value as Map<String, dynamic>;
    final amount = (data['total_amount'] as num).toDouble();
    final cost = (data['total_cost_usd'] as num).toDouble();
    final price = _prices[entry.key] ?? 0;
    final current = amount * price;
    final pnl = current - cost;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['name'] ?? entry.key,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${data['symbol'] ?? ''} · ${amount.toStringAsFixed(4)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(current),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${pnl >= 0 ? '+' : ''}${_money(pnl)}',
                style: TextStyle(
                  color: pnl >= 0 ? const Color(0xFF00D18A) : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _simulatedNftCard(Map<String, dynamic> nft) {
    final name = (nft['collectionName'] ?? 'Simulated NFT').toString();
    final tokenId = (nft['tokenId'] ?? '?').toString();
    final symbol = (nft['collectionSymbol'] ?? 'NFT').toString();
    final fractionalized = nft['fractionalized'] == true;
    final fractionToken = nft['fractionTokenAddress']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const AppIcon(
            AppIcons.imageOutlined,
            color: Color(0xFFE4A84B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name #$tokenId',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$symbol · ${fractionalized ? 'Fractionalized' : '1 NFT'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                if (fractionalized && fractionToken != null)
                  Text(
                    'Fraction token: ${fractionToken.substring(0, 8)}...',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceRow(String label, BigInt value) {
    final contracts = context.read<ContractService>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            contracts.formatToken(value),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _realMonadNftCard(ZerionNft nft) {
    final image = nft.image;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image == null || image.isEmpty
                ? _nftImagePlaceholder()
                : Image.network(
                    image,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _nftImagePlaceholder(),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nft.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  nft.collectionName,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (nft.floorPriceUsd != null)
            Text(
              _money(nft.floorPriceUsd!),
              style: const TextStyle(
                color: Color(0xFF00D18A),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _blockVisionNftCard(
    BlockVisionCollection collection,
    BlockVisionItem item,
  ) {
    final image = item.image;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image == null || image.isEmpty
                ? _nftImagePlaceholder()
                : Image.network(
                    image,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _nftImagePlaceholder(),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  collection.name,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (collection.verified)
            const Icon(Icons.verified, color: Color(0xFF00D18A), size: 16),
        ],
      ),
    );
  }

  Widget _nftImagePlaceholder() => Container(
    width: 44,
    height: 44,
    color: const Color(0xFF0D0B14),
    child: const Icon(Icons.image, color: Colors.white24, size: 20),
  );

  Widget _sectionTitle(String text, {String? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(color: Color(0xFF837C95), fontSize: 12),
          ),
      ],
    ),
  );

  Widget _demoHoldingCard(
    (String, String, String, String, Color, FaIconData) holding,
  ) {
    final positive = holding.$4.startsWith('+');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: holding.$5.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: AppIcon(holding.$6, color: holding.$5, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holding.$1,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  holding.$2,
                  style: const TextStyle(
                    color: Color(0xFF837C95),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                holding.$3,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                holding.$4,
                style: TextStyle(
                  color: positive
                      ? const Color(0xFF00D18A)
                      : const Color(0xFFFF6B7A),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 0, 0, 0),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text, style: const TextStyle(color: Colors.white54)),
  );

  String _money(double value) => NumberFormatting.money(value);
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}
