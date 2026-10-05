import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/rwa_service.dart';
import '../services/reputation_service.dart';
import '../services/watchlist_service.dart';
import '../widgets/reputation_badge.dart';

// UI/UX: Controls the RWA detail hierarchy, price/chart ranges, watchlist,
// audit links, risk disclosure, and bottom trading actions.
class RwaDetailScreen extends StatefulWidget {
  final Map<String, dynamic> asset;

  const RwaDetailScreen({super.key, required this.asset});

  @override
  State<RwaDetailScreen> createState() => _RwaDetailScreenState();
}

class _RwaDetailScreenState extends State<RwaDetailScreen> {
  final _service = RwaService();
  final _reputationService = ReputationService();
  final _watchlist = WatchlistService();
  Map<String, dynamic>? _quote;
  List<Map<String, dynamic>> _candles = [];
  bool _loading = true;
  bool _isWatched = false;
  String? _error;
  String _range = '1M';
  IssuerReputation? _reputation;

  @override
  void initState() {
    super.initState();
    if (widget.asset.isNotEmpty) {
      _quote = Map<String, dynamic>.from(widget.asset);
      _loading = false;
    }
    _checkWatchlist();
    _load();
  }

  Future<void> _checkWatchlist() async {
    final id = _assetId();
    if (id == null) return;
    final watched = await _watchlist.isWatched(context, id);
    if (!mounted) return;
    setState(() => _isWatched = watched);
  }

  Future<void> _toggleWatchlist() async {
    final id = _assetId();
    if (id == null) return;
    final asset = {
      ...widget.asset,
      'id': id,
      'rwa_slug': widget.asset['rwa_slug'] ?? id,
      'name': widget.asset['name'] ?? 'Asset',
      'symbol': widget.asset['symbol'] ?? 'ASSET',
    };
    await _watchlist.toggleWatchlist(context, asset);
    await _checkWatchlist();
  }

  Future<void> _load() async {
    final slug = _assetId();
    if (slug == null) {
      if (widget.asset.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Asset data is incomplete';
      });
      return;
    }

    try {
      final quoteFuture = _service.getQuote(slug);
      final chartFuture = _service.getChart(slug, count: 30);
      final results = await Future.wait([quoteFuture, chartFuture]);

      if (!mounted) return;
      setState(() {
        _quote = results[0] as Map<String, dynamic>;
        _candles = (results[1] as List<Map<String, dynamic>>)
            .where((entry) => entry['close'] != null)
            .toList();
        _loading = false;
        _error = null;
      });
      await _loadReputation(Map<String, dynamic>.from(results[0] as Map));
    } catch (error) {
      if (widget.asset.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String? _assetId() {
    return (widget.asset['id'] ??
            widget.asset['rwa_slug'] ??
            widget.asset['slug'] ??
            widget.asset['symbol'])
        ?.toString();
  }

  Future<void> _loadReputation(Map<String, dynamic> quote) async {
    final issuer =
        (quote['smeIssuer'] ??
                quote['issuer'] ??
                widget.asset['smeIssuer'] ??
                widget.asset['issuer'])
            ?.toString();
    if (issuer == null || issuer.isEmpty) return;
    final reputation = await _reputationService.getReputation(issuer);
    if (!mounted) return;
    setState(() => _reputation = reputation);
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  String _money(double value) {
    final sign = value < 0 ? '-' : '';
    final absValue = value.abs();
    final formatted = absValue.toStringAsFixed(2);
    final parts = formatted.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '\$$sign$whole.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.asset['name'] ?? 'Asset').toString();
    final symbol = (widget.asset['symbol'] ?? 'ASSET').toString().toUpperCase();
    final price = _asDouble(
      _quote?['price_usd'] ??
          widget.asset['price_usd'] ??
          widget.asset['average_tokenized_price'],
    );
    final change = _asDouble(
      _quote?['percent_change_24h'] ??
          widget.asset['percent_change_24h'] ??
          widget.asset['percent_change_24h'],
    );
    final marketCap = _asDouble(
      _quote?['market_cap_usd'] ??
          widget.asset['market_cap_usd'] ??
          widget.asset['tokenized_market_cap'],
    );
    final volume = _asDouble(
      _quote?['volume_24h_usd'] ??
          widget.asset['volume_24h_usd'] ??
          widget.asset['tokenized_volume_24h'],
    );
    final supply = _asDouble(
      widget.asset['circulating_supply'] ??
          widget.asset['total_supply'] ??
          1000000,
    );
    final allTimeHigh = _asDouble(
      widget.asset['all_time_high'] ?? widget.asset['ath'] ?? 4512.30,
    );
    final assetType = widget.asset['asset_type'] ?? 'tokenized_asset';
    final chain = widget.asset['chain'] ?? 'Ethereum';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    sliver: SliverToBoxAdapter(child: _buildTopBar()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _buildAssetHeader(name, symbol),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _buildPrice(price, change),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    sliver: SliverToBoxAdapter(child: _buildChart()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    sliver: SliverToBoxAdapter(child: _buildRanges()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _buildStats(
                        marketCap: marketCap,
                        volume: volume,
                        supply: supply,
                        allTimeHigh: allTimeHigh,
                        assetType: assetType,
                        chain: chain,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    sliver: SliverToBoxAdapter(child: _buildRiskDisclosure()),
                  ),
                  if (_reputation != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: ReputationCard(reputation: _reputation!),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    sliver: SliverToBoxAdapter(child: _buildAuditLink()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverToBoxAdapter(child: _buildActions()),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundIconButton(
          icon: Icons.navigate_before,
          onPressed: () => Navigator.maybePop(context),
        ),
        IconButton(
          onPressed: _toggleWatchlist,
          tooltip: _isWatched ? 'Remove from watchlist' : 'Add to watchlist',
          icon: Icon(
            _isWatched ? Icons.star : Icons.star_border,
            color: const Color(0xFFFFD66B),
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildAssetHeader(String name, String symbol) {
    final imageUrl = _imageUrl(widget.asset);
    return Row(
      children: [
        _AssetLogo(imageUrl: imageUrl, size: 48),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                symbol,
                style: const TextStyle(
                  color: Color(0xFF837C95),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.open_in_new,
            color: Color(0xFF9587B8),
            size: 20,
          ),
        ),
      ],
    );
  }

  String? _imageUrl(Map<String, dynamic> asset) {
    final image = asset['image'] ?? asset['image_url'] ?? asset['imageUrl'];
    if (image is String && image.isNotEmpty) return image;
    if (image is Map) {
      final url = image['large'] ?? image['small'] ?? image['thumb'];
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }

  Widget _buildPrice(double price, double change) {
    final isPositive = change >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _money(price),
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              color: isPositive
                  ? const Color(0xFF00D18A)
                  : const Color(0xFFFF6B7A),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}% (24h)',
              style: TextStyle(
                color: isPositive
                    ? const Color(0xFF00D18A)
                    : const Color(0xFFFF6B7A),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        const Text(
          'Updated 12 seconds ago',
          style: TextStyle(color: Color(0xFF837C95), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildChart() {
    final values = _candles
        .map((entry) => _asDouble(entry['close'], fallback: 0))
        .where((value) => value > 0)
        .toList();

    if (values.length < 2) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Chart data unavailable.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxValue - minValue) * 0.15;

    return Container(
      height: 245,
      padding: const EdgeInsets.fromLTRB(8, 18, 15, 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: minValue - padding,
          maxY: maxValue + padding,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: (maxValue - minValue) / 3,
                getTitlesWidget: (value, meta) => Text(
                  '\$${value.toInt()}',
                  style: const TextStyle(color: Color(0xFF746B83), fontSize: 9),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: (values.length / 4).clamp(1, 1000).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= values.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    index % 4 == 0 ? 'D${index + 1}' : '',
                    style: const TextStyle(
                      color: Color(0xFF746B83),
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: values
                  .asMap()
                  .entries
                  .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
                  .toList(),
              isCurved: true,
              curveSmoothness: 0.28,
              color: const Color.fromARGB(255, 74, 24, 199),
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color.fromARGB(
                      255,
                      74,
                      24,
                      199,
                    ).withValues(alpha: 0.30),
                    const Color.fromARGB(
                      255,
                      74,
                      24,
                      199,
                    ).withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRanges() {
    const ranges = ['1H', '1D', '1W', '1M', '1Y', 'All'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: ranges.map((range) {
        final selected = range == _range;
        return GestureDetector(
          onTap: () => setState(() => _range = range),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? const Color.fromARGB(255, 74, 24, 199)
                  : const Color.fromARGB(255, 0, 0, 0),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              range,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF837C95),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStats({
    required double marketCap,
    required double volume,
    required double supply,
    required double allTimeHigh,
    required String assetType,
    required String chain,
  }) {
    final stats = [
      ('Market Cap', _money(marketCap)),
      ('24h Volume', _money(volume)),
      ('Circulating Supply', supply.toStringAsFixed(0)),
      ('All-Time High', _money(allTimeHigh)),
      ('Asset Type', assetType),
      ('Chain', chain),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MARKET STATS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF15121E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: stats
                .map(
                  (stat) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            stat.$1,
                            style: const TextStyle(
                              color: Color(0xFF837C95),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          stat.$2,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskDisclosure() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2119),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFB9784F).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFE4A84B),
            size: 21,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk Disclosure',
                  style: TextStyle(
                    color: Color(0xFFE4A84B),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Commodity investments carry market price risk. The value of the underlying goods may fluctuate based on global supply, demand, and geopolitical factors. Only invest what you can afford to lose.',
                  style: TextStyle(
                    color: Color(0xFFD6CFD8),
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLink() {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audit report link coming soon')),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(
              Icons.description_outlined,
              color: Color(0xFF9A87FF),
              size: 20,
            ),
            const SizedBox(width: 10),
            const Text(
              'View Audit Report →',
              style: TextStyle(
                color: Color(0xFF9A87FF),
                decoration: TextDecoration.underline,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            const Icon(Icons.open_in_new, color: Color(0xFF837C95), size: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Fractionalize This Asset'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 74, 24, 199),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.swap_horiz, size: 19),
            label: const Text('Trade Fractions'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF554A70)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: 1,
          onDestinationSelected: (index) {
            if (index == 0) {
              Navigator.maybePop(context);
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 68,
          indicatorColor: const Color.fromARGB(
            255,
            74,
            24,
            199,
          ).withValues(alpha: 0.22),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: Color(0xFF9A87FF)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search, color: Color(0xFF9A87FF)),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront, color: Color(0xFF9A87FF)),
              label: 'Market',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_box_outlined),
              selectedIcon: Icon(Icons.add_box, color: Color(0xFF9A87FF)),
              label: 'Create',
            ),
            NavigationDestination(
              icon: Icon(Icons.water_drop_outlined),
              selectedIcon: Icon(Icons.water_drop, color: Color(0xFF9A87FF)),
              label: 'Yield',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings, color: Color(0xFF9A87FF)),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
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
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFD66B), Color(0xFFB87924)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.workspace_premium,
        color: Color(0xFF4D2E0D),
        size: 27,
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
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

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: const Color(0xFF9587B8), size: 21),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF171320),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }
}
