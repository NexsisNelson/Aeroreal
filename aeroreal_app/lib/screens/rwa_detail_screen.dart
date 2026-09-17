import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/rwa_service.dart';

class RwaDetailScreen extends StatefulWidget {
  final Map<String, dynamic> asset;

  const RwaDetailScreen({super.key, required this.asset});

  @override
  State<RwaDetailScreen> createState() => _RwaDetailScreenState();
}

class _RwaDetailScreenState extends State<RwaDetailScreen> {
  final _service = RwaService();
  Map<String, dynamic>? _quote;
  List<Map<String, dynamic>> _candles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final slug = widget.asset['rwa_slug'] as String?;
      final assetId =
          widget.asset['id'] as String? ??
          slug ??
          widget.asset['symbol'] as String?;
      if (slug == null || assetId == null) {
        throw Exception('Asset data is incomplete');
      }
      final results = await Future.wait([
        _service.getQuote(slug),
        _service.getChart(assetId),
      ]);
      if (!mounted) return;
      setState(() {
        _quote = results[0] as Map<String, dynamic>;
        _candles = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.asset['name'] ?? 'RWA Asset')),
        body: Center(child: Text(_error!)),
      );
    }

    final price = _number(_quote?['price_usd']);
    final change = _number(_quote?['percent_change_24h']);
    final isPositive = change >= 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.asset['name'] ?? 'RWA Asset')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _AssetLogo(imageUrl: widget.asset['image'] as String?, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.asset['name'] ?? 'RWA Asset',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      (widget.asset['symbol'] as String? ?? '').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _currency(price),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isPositive ? const Color(0xFF00D18A) : Colors.redAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${change.toStringAsFixed(2)}% (24h)',
                style: TextStyle(
                  color: isPositive
                      ? const Color(0xFF00D18A)
                      : Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_candles.isNotEmpty) _buildChart(),
          const SizedBox(height: 24),
          _stat('Market Cap', _currency(_number(_quote?['market_cap_usd']))),
          _stat('24h Volume', _currency(_number(_quote?['volume_24h_usd']))),
          _stat('Asset Type', '${widget.asset['asset_type'] ?? 'Unknown'}'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Fractionalize This Asset'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF836EF9),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.currency_exchange),
            label: const Text('Trade Fractions'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final values = _candles
        .map((candle) => _number(candle['close']))
        .where((value) => value.isFinite)
        .toList();
    if (values.length < 2) return const SizedBox.shrink();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxValue - minValue).abs() * 0.1;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          minY: minValue - padding,
          maxY: maxValue + padding,
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
              isCurved: true,
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

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  double _number(dynamic value) => value is num ? value.toDouble() : 0;

  String _currency(double value) => '\$${value.toStringAsFixed(2)}';
}

class _AssetLogo extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _AssetLogo({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.currency_bitcoin, color: Colors.white54),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}
