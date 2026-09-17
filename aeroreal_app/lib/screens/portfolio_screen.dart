import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/contract_service.dart';
import '../services/portfolio_service.dart';
import '../services/privy_service.dart';
import '../services/rwa_service.dart';
import '../services/wallet_service.dart';

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
        setState(() => _loading = false);
        return;
      }
      final contracts = context.read<ContractService>();
      final results = await Future.wait([
        context.read<WalletService>().getMonBalance(ownerAddress: address),
        contracts.getFractionBalance(address),
        contracts.getSprinkleBalance(address),
        contracts.getGoldFractionBalance(address),
      ]);
      final basis = await _portfolio.getCostBasis();
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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load portfolio: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pnl = _value - _cost;
    final pnlPercent = _cost > 0 ? pnl / _cost * 100 : 0.0;
    final positive = pnl >= 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF836EF9),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _summaryCard(pnl, pnlPercent, positive),
                  const SizedBox(height: 20),
                  _sectionTitle('Allocation'),
                  _allocationChart(),
                  const SizedBox(height: 20),
                  _sectionTitle('Performance'),
                  _performanceChart(),
                  const SizedBox(height: 20),
                  _sectionTitle('Your Holdings'),
                  if (_costBasis.isEmpty)
                    _emptyCard(
                      'No holdings yet. Buy an asset to start tracking PnL.',
                    )
                  else
                    ..._costBasis.entries.map(_holdingCard),
                  const SizedBox(height: 20),
                  _sectionTitle('Chain Balances'),
                  _balanceRow('MON (gas)', _mon),
                  _balanceRow('fMDAPE (fractions)', _fractions),
                  _balanceRow('SPR (rewards)', _sprinkle),
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
        color: const Color(0xFF243B39),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00D18A).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Portfolio Value',
            style: TextStyle(color: Colors.white70),
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
        ],
      ),
    );
  }

  Widget _allocationChart() {
    final values = [
      _mon.toDouble(),
      _fractions.toDouble(),
      _sprinkle.toDouble(),
    ];
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total == 0) return _emptyCard('No balance allocation available yet.');
    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 34,
                sections: [
                  _pie(values[0], const Color(0xFF836EF9)),
                  _pie(values[1], const Color(0xFF00D18A)),
                  _pie(values[2], const Color(0xFFED9B40)),
                ],
              ),
            ),
          ),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: Color(0xFF836EF9), label: 'MON'),
              _Legend(color: Color(0xFF00D18A), label: 'Fractions'),
              _Legend(color: Color(0xFFED9B40), label: 'Rewards'),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pie(double value, Color color) {
    return PieChartSectionData(
      value: value,
      color: color,
      radius: 48,
      showTitle: false,
    );
  }

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
        color: const Color(0xFF1A1625),
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

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );

  Widget _emptyCard(String text) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1625),
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
