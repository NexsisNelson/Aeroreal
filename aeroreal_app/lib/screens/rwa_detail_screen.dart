import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../utils/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../services/contract_service.dart';
import '../services/privy_service.dart';
import '../services/rwa_service.dart';
import '../services/reputation_service.dart';
import '../services/user_profile_service.dart';
import '../services/watchlist_service.dart';
import '../widgets/error_banner.dart';
import '../widgets/pill_nav_bar.dart';
import '../widgets/reputation_badge.dart';
import 'fraction_marketplace_screen.dart';
import 'nft_fractionalize_screen.dart';

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
  bool _buying = false;
  String? _buyStatus;

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
      final chartId = (widget.asset['id'] ?? widget.asset['symbol'] ?? slug)
          .toString();
      final quote = await quoteFuture;
      List<Map<String, dynamic>> candles = [];
      try {
        candles = await _service.getChart(chartId, count: 30);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _quote = quote;
        _candles = candles.where((entry) => entry['close'] != null).toList();
        _loading = false;
        _error = null;
      });
      await _loadReputation(quote);
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

  Future<void> _buySimulated(String symbol) async {
    final priceUsd = (widget.asset['price_usd'] as num?)?.toDouble() ?? 0;
    if (priceUsd <= 0) {
      setState(() => _buyStatus = 'Price unavailable');
      return;
    }

    final amountController = TextEditingController();
    final amountStr = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1625),
        title: Text('Buy $symbol'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount ($symbol)',
            hintText: 'e.g., 0.5',
            helperText: 'Price: \$${priceUsd.toStringAsFixed(2)}',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, amountController.text),
            child: const Text('Review buy'),
          ),
        ],
      ),
    );

    if (!mounted || amountStr == null || amountStr.isEmpty) return;

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      setState(() => _buyStatus = 'Invalid amount');
      return;
    }

    final costAreal = amount * priceUsd;
    final fee = costAreal * 0.01;
    final totalCost = costAreal + fee;

    setState(() {
      _buying = true;
      _buyStatus = 'Approving AREAL...';
    });

    try {
      final privy = context.read<PrivyService>();
      final contracts = context.read<ContractService>();
      final profileService = context.read<UserProfileService>();
      final addr = privy.walletAddress;
      if (addr == null) throw Exception('No wallet');

      final costWei = BigInt.from((totalCost * 1e18).round());
      await contracts.transferAreal(
        to: AppConstants.simulatedMarketplace,
        amount: costWei,
      );
      await Future.delayed(const Duration(seconds: 4));

      setState(() => _buyStatus = 'Recording purchase...');
      await profileService.recordSimulatedBuy(
        symbol: symbol,
        amountAsset: amount,
        arealCost: totalCost,
        coingeckoId:
            (widget.asset['coingeckoId'] ?? widget.asset['id'] ?? symbol)
                .toString()
                .toLowerCase(),
        imageUrl: _imageUrl(widget.asset),
      );

      if (!mounted) return;
      setState(() {
        _buying = false;
        _buyStatus = 'Purchased $amount $symbol';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bought $amount $symbol'),
          backgroundColor: const Color(0xFF00D18A),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _buying = false;
        _buyStatus = 'Buy failed: $error';
      });
    }
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
            ? Center(
                child: ErrorBanner(
                  error: _error!,
                  onDismiss: () => setState(() => _error = null),
                  onRetry: () => setState(() => _error = null),
                ),
              )
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
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    sliver: SliverToBoxAdapter(child: _buildActions(symbol)),
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
                    sliver: SliverToBoxAdapter(child: _buildFractionActions()),
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
          icon: AppIcons.navigateBefore,
          onPressed: () => Navigator.maybePop(context),
        ),
        IconButton(
          onPressed: _toggleWatchlist,
          tooltip: _isWatched ? 'Remove from watchlist' : 'Add to watchlist',
          icon: AppIcon(
            _isWatched ? AppIcons.star : AppIcons.starBorder,
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
          icon: const AppIcon(
            AppIcons.openInNew,
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
            AppIcon(
              isPositive ? AppIcons.arrowUpward : AppIcons.arrowDownward,
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
      ('Native Chain', chain),
      ('Traded On', 'Monad Testnet'),
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
          const AppIcon(
            AppIcons.warningAmberRounded,
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
            const AppIcon(
              AppIcons.descriptionOutlined,
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
            const AppIcon(
              AppIcons.openInNew,
              color: Color(0xFF837C95),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(String symbol) {
    return _buildSimulatedTradeCard(symbol);
  }

  Widget _buildFractionActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NftFractionalizeScreen(),
              ),
            ),
            icon: const AppIcon(AppIcons.add, size: 18),
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const FractionMarketplaceScreen(),
              ),
            ),
            icon: const AppIcon(AppIcons.swapHoriz, size: 19),
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

  Widget _buildSimulatedTradeCard(String symbol) {
    final priceUsd = _asDouble(
      _quote?['price_usd'] ?? widget.asset['price_usd'],
    );
    final currentPrice = priceUsd <= 0
        ? 'Price unavailable'
        : '${_money(priceUsd)} per token';
    final tokenSymbol = symbol.toUpperCase();
    final profileHoldings = context
        .read<UserProfileService>()
        .simulatedHoldings;
    final holding = profileHoldings[symbol.toUpperCase()];
    final amount = holding == null
        ? 0.0
        : (holding['totalAmount'] as num?)?.toDouble() ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101A17),
        border: Border.all(color: const Color(0xFF087F5B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(AppIcons.bolt, color: Color(0xFF00D18A), size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Simulated $tokenSymbol',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Text(
                'PROFILE',
                style: TextStyle(
                  color: Color(0xFF00D18A),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$currentPrice · Off-chain simulated balance',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            'You own ${amount.toStringAsFixed(4)} $tokenSymbol',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (_buyStatus != null) ...[
            const SizedBox(height: 8),
            Text(_buyStatus!, style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _buying
                  ? null
                  : () => _buySimulated(symbol.toUpperCase()),
              icon: _buying
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const AppIcon(AppIcons.shoppingBagOutlined, size: 18),
              label: Text(_buying ? 'Processing...' : 'Buy $tokenSymbol'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() => PillNavBar(
    selectedIndex: 1,
    onSelect: (index) {
      if (index == 1) Navigator.maybePop(context);
    },
    items: const [
      PillNavItem(
        icon: AppIcons.homeOutlined,
        selectedIcon: AppIcons.home,
        label: 'Home',
      ),
      PillNavItem(
        icon: AppIcons.searchOutlined,
        selectedIcon: AppIcons.search,
        label: 'Explore',
      ),
      PillNavItem(
        icon: AppIcons.storefrontOutlined,
        selectedIcon: AppIcons.storefront,
        label: 'Market',
      ),
      PillNavItem(
        icon: AppIcons.addBoxOutlined,
        selectedIcon: AppIcons.addBox,
        label: 'Create',
      ),
      PillNavItem(
        icon: AppIcons.waterDropOutlined,
        selectedIcon: AppIcons.waterDrop,
        label: 'Yield',
      ),
    ],
  );
}

class _SimulatedBuyDialog extends StatefulWidget {
  final String symbol;
  final String tokenSymbol;

  const _SimulatedBuyDialog({required this.symbol, required this.tokenSymbol});

  @override
  State<_SimulatedBuyDialog> createState() => _SimulatedBuyDialogState();
}

class _SimulatedBuyDialogState extends State<_SimulatedBuyDialog> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '0.001');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Buy ${widget.tokenSymbol}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _amountController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: 'Amount (${widget.symbol})',
            hintText: '0.001',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Simulated token. Tracks a market price but has no real-world value.',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _amountController.text),
        child: const Text('Review buy'),
      ),
    ],
  );
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
      child: const AppIcon(
        AppIcons.workspacePremium,
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
  final FaIconData icon;
  final VoidCallback onPressed;

  const _RoundIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: AppIcon(icon, color: const Color(0xFF9587B8), size: 21),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF171320),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }
}
