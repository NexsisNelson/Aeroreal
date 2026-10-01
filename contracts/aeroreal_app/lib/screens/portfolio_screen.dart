import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/contract_service.dart';
import '../services/portfolio_service.dart';
import '../services/privy_service.dart';
import '../services/rwa_service.dart';
import '../services/wallet_service.dart';

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
  Map<String, dynamic> _costBasis = {};
  Map<String, double> _prices = {};
  List<Map<String, dynamic>> _snapshots = [];
  BigInt _mon = BigInt.zero;
  BigInt _fractions = BigInt.zero;
  BigInt _sprinkle = BigInt.zero;
  BigInt _gold = BigInt.zero;
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
          _snapshots = _demoSnapshots;
        });
        return;
      }
      final contracts = context.read<ContractService>();
      final results = await Future.wait([
        context.read<WalletService>().getMonBalance(ownerAddress: address),
        contracts.getFractionBalance(address),
        contracts.getSprinkleBalance(address),
        contracts.getGoldFractionBalance(address),
      ]);
      if (!mounted) return;
      final basis = await _portfolio.getCostBasis(context);
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
      await _portfolio.recordSnapshot(value);
      final snapshots = await _portfolio.getSnapshots();
      if (!mounted) return;
      setState(() {
        _mon = results[0];
        _fractions = results[1];
        _sprinkle = results[2];
        _gold = results[3];
        _costBasis = basis;
        _prices = prices;
        _value = value;
        _cost = cost;
        _snapshots = snapshots;
        _loading = false;
        _demoMode = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load portfolio: $error';
        _loading = false;
      });
    }
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
      Icons.workspace_premium,
    ),
    (
      'Coffee Batch',
      '5,000 fractions',
      '\$1,850.00',
      '-\$50.00 (-2.6%)',
      Color(0xFF9B6A4A),
      Icons.coffee,
    ),
    (
      'Demo NFT',
      '1 NFT',
      '\$500.00',
      '+\$50.00 (+11.1%)',
      Color(0xFF836EF9),
      Icons.image_outlined,
    ),
    (
      'USDC',
      '500 USDC',
      '\$500.00',
      '\$0.00 (0%)',
      Color(0xFF00D18A),
      Icons.attach_money,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pnl = _value - _cost;
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
            icon: const Icon(Icons.refresh, color: Color(0xFF9587B8)),
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
                  _summaryCard(pnl, pnlPercent, positive),
                  const SizedBox(height: 20),
                  _allocationCard(),
                  const SizedBox(height: 20),
                  _performanceCard(),
                  const SizedBox(height: 20),
                  _sectionTitle(
                    'HOLDINGS',
                    trailing: '${_demoMode ? 4 : _costBasis.length} assets',
                  ),
                  if (_demoMode)
                    ..._demoHoldings.map(_demoHoldingCard)
                  else if (_costBasis.isEmpty)
                    _emptyCard(
                      'No holdings yet. Buy an asset to start tracking PnL.',
                    )
                  else
                    ..._costBasis.entries.map(_holdingCard),
                  const SizedBox(height: 20),
                  _sectionTitle('CHAIN BALANCES'),
                  _balanceRow('MON (gas)', _mon),
                  _balanceRow('fMDAPE (fractions)', _fractions),
                  _balanceRow('AREAL (rewards)', _sprinkle),
                  _balanceRow('fGOLD (gold fractions)', _gold),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(double pnl, double percent, bool positive) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6E55D9), Color(0xFF302875)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
            _money(_value),
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
              Icon(Icons.link, size: 14, color: Colors.white70),
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
    (String, String, String, String, Color, IconData) holding,
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
            child: Icon(holding.$6, color: holding.$5, size: 20),
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

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
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
