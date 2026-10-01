import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/app_icons.dart';
import '../utils/number_formatting.dart';
import 'package:provider/provider.dart';

import 'fund_wallet_screen.dart';
import 'explore_screen.dart';
import 'nft_marketplace_screen.dart';
import 'portfolio_screen.dart';
import 'notifications_screen.dart';
import 'send_tokens_screen.dart';
import 'settings_screen.dart';
import 'tx_history_screen.dart';
import 'watchlist_screen.dart';
import '../services/contract_service.dart';
import '../services/portfolio_service.dart';
import '../services/privy_service.dart';
import '../services/rwa_service.dart';
import '../services/tx_history_service.dart';
import '../services/wallet_service.dart';
import '../services/user_profile_service.dart';
import '../utils/transaction_feedback.dart';
import '../widgets/asset_image_avatar.dart';

// UI/UX: Controls the main dashboard: greeting actions, portfolio summary,
// token balances, quick actions, holdings, activity, and pull-to-refresh.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  bool _hasLoaded = false;
  bool _refreshAgain = false;
  Future<void>? _refreshFuture;
  String _activitySnapshot = '';
  String _costBasisSnapshot = '';
  String _simulatedSnapshot = '';
  ContractService? _listenedContracts;
  UserProfileService? _listenedProfile;
  BigInt _monBalance = BigInt.zero;
  BigInt _sprinkleBalance = BigInt.zero;
  BigInt _fractionBalance = BigInt.zero;
  double _portfolioValue = 0;
  double _portfolioCost = 0;
  List<_HomeAsset> _assets = [];
  List<TransactionRecord> _activity = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final contracts = context.read<ContractService>();
    contracts.context = context;
    if (_listenedContracts != contracts) {
      _listenedContracts?.removeListener(_onDataChanged);
      _listenedContracts = contracts..addListener(_onDataChanged);
    }
    final profile = context.read<UserProfileService>();
    if (_listenedProfile != profile) {
      _listenedProfile?.removeListener(_onProfileChanged);
      _listenedProfile = profile;
      _activitySnapshot = jsonEncode(profile.txHistory);
      _costBasisSnapshot = jsonEncode(profile.costBasis);
      _simulatedSnapshot = jsonEncode(profile.simulatedHoldings);
      profile.addListener(_onProfileChanged);
    }
  }

  void _onDataChanged() {
    if (mounted) _refresh();
  }

  void _onProfileChanged() {
    final profile = _listenedProfile;
    if (!mounted || profile == null) return;

    final activitySnapshot = jsonEncode(profile.txHistory);
    final costBasisSnapshot = jsonEncode(profile.costBasis);
    final simulatedSnapshot = jsonEncode(profile.simulatedHoldings);
    final activityChanged = activitySnapshot != _activitySnapshot;
    final costBasisChanged = costBasisSnapshot != _costBasisSnapshot;
    final simulatedChanged = simulatedSnapshot != _simulatedSnapshot;
    _activitySnapshot = activitySnapshot;
    _costBasisSnapshot = costBasisSnapshot;
    _simulatedSnapshot = simulatedSnapshot;

    if (activityChanged) unawaited(_updateActivity());
    if (costBasisChanged || simulatedChanged) _refresh();
  }

  @override
  void dispose() {
    _listenedContracts?.removeListener(_onDataChanged);
    _listenedProfile?.removeListener(_onProfileChanged);
    super.dispose();
  }

  Future<void> _refresh() {
    final activeRefresh = _refreshFuture;
    if (activeRefresh != null) {
      _refreshAgain = true;
      return activeRefresh;
    }

    final refresh = _refreshLoop();
    _refreshFuture = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshFuture, refresh)) _refreshFuture = null;
    });
  }

  Future<void> _refreshLoop() async {
    do {
      _refreshAgain = false;
      await _loadDashboard();
    } while (_refreshAgain && mounted);
  }

  Future<void> _updateActivity() async {
    try {
      final activity = await TxHistoryService().getAll(context);
      if (mounted) setState(() => _activity = activity);
    } catch (_) {}
  }

  Future<void> _loadDashboard() async {
    // Data/state touchpoint: change this method when dashboard balances,
    // portfolio quotes, loading behavior, or activity refresh rules change.
    if (mounted && !_hasLoaded) setState(() => _loading = true);
    final address = context.read<PrivyService>().walletAddress;
    if (address == null || address.isEmpty) {
      if (mounted) {
        setState(() {
          _monBalance = BigInt.zero;
          _sprinkleBalance = BigInt.zero;
          _fractionBalance = BigInt.zero;
          _portfolioValue = 0;
          _portfolioCost = 0;
          _assets = [];
          _activity = [];
          _loading = false;
          _hasLoaded = true;
        });
      }
      return;
    }
    unawaited(_updateActivity());

    final wallet = context.read<WalletService>();
    final contracts = context.read<ContractService>();
    final profile = context.read<UserProfileService>();
    final portfolio = PortfolioService();
    final rwa = RwaService();
    Object? balanceError;

    Future<BigInt> readBalance(Future<BigInt> request, BigInt previous) async {
      try {
        return await request;
      } catch (error) {
        balanceError ??= error;
        return previous;
      }
    }

    final balancesFuture = Future.wait<BigInt>([
      readBalance(wallet.getMonBalance(ownerAddress: address), _monBalance),
      readBalance(contracts.getSprinkleBalance(address), _sprinkleBalance),
      readBalance(contracts.getFractionBalance(address), _fractionBalance),
    ]);
    unawaited(
      balancesFuture.then((balances) {
        if (!mounted) return;
        setState(() {
          _monBalance = balances[0];
          _sprinkleBalance = balances[1];
          _fractionBalance = balances[2];
        });
        final error = balanceError;
        if (error != null && TransactionFeedback.isConnectionIssue(error)) {
          TransactionFeedback.showConnectionToast(context);
        }
      }),
    );

    try {
      final savedBasis = await portfolio.getCostBasis(context);
      final basis = Map<String, dynamic>.fromEntries(
        savedBasis.entries.where(
          (entry) => !entry.key.startsWith('simulated:'),
        ),
      );
      final simulated = <String, Map<String, dynamic>>{
        for (final entry in profile.simulatedHoldings.entries)
          entry.key: Map<String, dynamic>.from(entry.value as Map),
      };

      _HomeAsset buildBasisAsset(
        MapEntry<String, dynamic> entry, {
        double? livePrice,
      }) {
        final data = Map<String, dynamic>.from(entry.value as Map);
        final amount = (data['total_amount'] as num?)?.toDouble() ?? 0;
        final cost = (data['total_cost_usd'] as num?)?.toDouble() ?? 0;
        final hasLiveQuote = livePrice != null && livePrice > 0;
        final price = hasLiveQuote
            ? livePrice
            : amount > 0
            ? cost / amount
            : 0.0;
        final current = amount * price;
        return _HomeAsset(
          title: (data['name'] ?? data['symbol'] ?? entry.key).toString(),
          subtitle: '${data['symbol'] ?? entry.key} · ${_amount(amount)} units',
          value: current,
          pnl: current - cost,
          apy: hasLiveQuote ? 'Live quote' : 'Cost basis',
        );
      }

      List<_HomeAsset> buildSimulatedAssets(Map<String, double> prices) =>
          simulated.entries.map((entry) {
            final data = entry.value;
            final symbol = (data['symbol'] ?? entry.key).toString();
            final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
            final cost = (data['totalCostAreal'] as num?)?.toDouble() ?? 0;
            final price =
                prices[entry.key] ??
                (data['avgPrice'] as num?)?.toDouble() ??
                0;
            final current = amount * price;
            return _HomeAsset(
              title: 's$symbol',
              subtitle: '$symbol · ${_amount(amount)} units',
              value: current,
              pnl: current - cost,
              apy: prices.containsKey(entry.key) ? 'Live price' : 'Cost basis',
              imageUrl: data['imageUrl']?.toString(),
            );
          }).toList();

      final initialAssets = <_HomeAsset>[
        for (final entry in basis.entries) buildBasisAsset(entry),
        ...buildSimulatedAssets(const {}),
      ];
      if (!mounted) return;
      setState(() {
        _assets = initialAssets;
        _portfolioValue = initialAssets.fold(
          0,
          (sum, asset) => sum + asset.value,
        );
        _portfolioCost = initialAssets.fold(
          0,
          (sum, asset) => sum + asset.value - asset.pnl,
        );
        _loading = false;
        _hasLoaded = true;
      });

      final onChainAssetsFuture = Future.wait(
        basis.entries.map((entry) async {
          double? livePrice;
          try {
            final quote = await rwa.getQuote(entry.key);
            final price = _number(quote['price_usd'] ?? quote['current_price']);
            if (price > 0) livePrice = price;
          } catch (_) {}
          return buildBasisAsset(entry, livePrice: livePrice);
        }),
      );
      final simulatedPricesFuture = _fetchSimulatedPrices(simulated);
      final onChainAssets = await onChainAssetsFuture;
      final simulatedPrices = await simulatedPricesFuture;
      final assets = <_HomeAsset>[
        ...onChainAssets,
        ...buildSimulatedAssets(simulatedPrices),
      ];
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _portfolioValue = assets.fold(0, (sum, asset) => sum + asset.value);
        _portfolioCost = assets.fold(
          0,
          (sum, asset) => sum + asset.value - asset.pnl,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasLoaded = true;
      });
      if (TransactionFeedback.isConnectionIssue(error)) {
        TransactionFeedback.showConnectionToast(context);
      }
    }
  }

  Future<Map<String, double>> _fetchSimulatedPrices(
    Map<String, Map<String, dynamic>> holdings,
  ) async {
    if (holdings.isEmpty) return {};
    final idBySymbol = <String, String>{};
    for (final entry in holdings.entries) {
      final id = (entry.value['coingeckoId'] as String?)?.trim();
      idBySymbol[entry.key] = id == null || id.isEmpty
          ? entry.key.toLowerCase()
          : id;
    }

    try {
      final response = await http
          .get(
            Uri.https('api.coingecko.com', '/api/v3/simple/price', {
              'ids': idBySymbol.values.toSet().join(','),
              'vs_currencies': 'usd',
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return {};
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final prices = <String, double>{};
      for (final entry in idBySymbol.entries) {
        final quote = data[entry.value];
        final price = quote is Map ? quote['usd'] : null;
        if (price is num && price > 0) prices[entry.key] = price.toDouble();
      }
      return prices;
    } catch (_) {
      return {};
    }
  }

  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static String _amount(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(4);

  static String _money(double value) => NumberFormatting.money(value);

  static String _token(BigInt value) {
    final divisor = BigInt.from(10).pow(18);
    final whole = value ~/ divisor;
    final decimals = (value % divisor)
        .toString()
        .padLeft(18, '0')
        .substring(0, 4);
    return '$whole.$decimals';
  }

  String _timeAgo(DateTime timestamp) {
    final minutes = DateTime.now().difference(timestamp).inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '${minutes}m ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '${hours}h ago';
    return '${hours ~/ 24}d ago';
  }

  @override
  Widget build(BuildContext context) {
    // Layout touchpoint: this widget tree defines the complete Home tab UI.
    final portfolioPnl = _portfolioValue - _portfolioCost;
    final portfolioIsPositive = portfolioPnl >= 0;
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                color: const Color.fromARGB(255, 74, 24, 199),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFBCAEFF), Color(0xFF6B56D9)],
                            ),
                          ),
                          child: const AppIcon(
                            AppIcons.person,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Good morning',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          ),
                          icon: const AppIcon(
                            AppIcons.notificationsNoneRounded,
                          ),
                          color: const Color(0xFFBCAEFF),
                          tooltip: 'Notifications',
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                          icon: const AppIcon(AppIcons.settingsOutlined),
                          color: const Color(0xFFBCAEFF),
                          tooltip: 'Settings',
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/card2.png'),
                          fit: BoxFit.fill,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL PORTFOLIO VALUE',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _money(_portfolioValue),
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              AppIcon(
                                portfolioIsPositive
                                    ? AppIcons.arrowUpwardRounded
                                    : AppIcons.arrowDownwardRounded,
                                size: 14,
                                color: portfolioIsPositive
                                    ? Color(0xFF00D18A)
                                    : Color(0xFFE96B78),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${portfolioIsPositive ? '+' : '-'}${_money(portfolioPnl.abs())} all time',
                                style: TextStyle(
                                  color: portfolioIsPositive
                                      ? Color(0xFF00D18A)
                                      : Color(0xFFE96B78),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              _HeroAction(
                                label: 'Add Funds',
                                icon: AppIcons.addRounded,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const FundWalletScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _HeroAction(
                                label: 'Send',
                                icon: AppIcons.send,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SendTokensScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _HeroAction(
                                label: 'Receive',
                                icon: AppIcons.arrowDownwardRounded,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const FundWalletScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              _TokenBalance(label: 'MON', value: _monBalance),
                              _TokenBalance(
                                label: 'fTokens',
                                value: _fractionBalance,
                              ),
                              _TokenBalance(
                                label: 'AREAL',
                                value: _sprinkleBalance,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const _SectionHeader(
                      title: 'QUICK ACTIONS',
                      showSeeAll: false,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _QuickAction(
                          icon: AppIcons.searchRounded,
                          label: 'Explore',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ExploreScreen(),
                            ),
                          ),
                        ),
                        _QuickAction(
                          icon: AppIcons.shoppingBagOutlined,
                          label: 'Market',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NftMarketplaceScreen(),
                            ),
                          ),
                        ),
                        _QuickAction(
                          icon: AppIcons.starBorderRounded,
                          label: 'Watchlist',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WatchlistScreen(),
                            ),
                          ),
                        ),
                        _QuickAction(
                          icon: AppIcons.barChartRounded,
                          label: 'Portfolio',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PortfolioScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Holdings and activity each have their own See All route;
                    // change those callbacks when dashboard navigation changes.
                    _SectionHeader(
                      title: 'YOUR ASSETS',
                      onSeeAll: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PortfolioScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_assets.isEmpty)
                      const _EmptyHomeCard(
                        text:
                            'No holdings yet. Explore an asset to start building your portfolio.',
                      )
                    else
                      ..._assets.map(
                        (asset) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AssetRow(asset: asset),
                        ),
                      ),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      title: 'RECENT ACTIVITY',
                      onSeeAll: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TxHistoryScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_activity.isEmpty)
                      const _EmptyHomeCard(text: 'No on-chain activity yet.')
                    else
                      ..._activity
                          .take(3)
                          .map(
                            (record) => _ActivityRow(
                              title: record.action,
                              time: _timeAgo(record.timestamp),
                            ),
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  final String label;
  final FaIconData icon;
  final VoidCallback onPressed;

  const _HeroAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF171326),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Colors.white),
            padding: const EdgeInsets.all(6),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: 30),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2342),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF403663)),
                ),
                child: AppIcon(icon, color: const Color(0xFFBCAEFF), size: 22),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool showSeeAll;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.title,
    this.showSeeAll = true,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.white54,
          ),
        ),
        if (showSeeAll)
          TextButton.icon(
            onPressed: onSeeAll,
            icon: const AppIcon(AppIcons.arrowForwardRounded, size: 14),
            label: const Text('See all'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF9A87FF),
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeAsset {
  final String title;
  final String subtitle;
  final double value;
  final double pnl;
  final String apy;
  final String? imageUrl;

  const _HomeAsset({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.pnl,
    required this.apy,
    this.imageUrl,
  });
}

class _TokenBalance extends StatelessWidget {
  final String label;
  final BigInt value;

  const _TokenBalance({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_HomeScreenState._token(value)} $label',
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  final _HomeAsset asset;

  const _AssetRow({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111018),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF292533)),
      ),
      child: Row(
        children: [
          AssetImageAvatar(imageUrl: asset.imageUrl, seed: asset.title),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  asset.subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Text(
                      _HomeScreenState._money(asset.value),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${asset.pnl >= 0 ? '↑' : '↓'} ${_HomeScreenState._money(asset.pnl)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: asset.pnl >= 0
                            ? const Color(0xFF00D18A)
                            : const Color(0xFFE96B78),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Text(
              asset.apy,
              style: const TextStyle(
                color: Color(0xFF9A87FF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String title;
  final String time;

  const _ActivityRow({required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          const AppIcon(
            AppIcons.checkCircle,
            color: Color(0xFF00D18A),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            time,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _EmptyHomeCard extends StatelessWidget {
  final String text;

  const _EmptyHomeCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111018),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF292533)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF837C95), fontSize: 12),
      ),
    );
  }
}
