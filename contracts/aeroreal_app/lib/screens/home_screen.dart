import 'package:flutter/material.dart';
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
  int _refreshId = 0;
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
      _listenedProfile?.removeListener(_onDataChanged);
      _listenedProfile = profile..addListener(_onDataChanged);
    }
  }

  void _onDataChanged() {
    if (mounted) _refresh();
  }

  @override
  void dispose() {
    _listenedContracts?.removeListener(_onDataChanged);
    _listenedProfile?.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> _refresh() async {
    // Data/state touchpoint: change this method when dashboard balances,
    // portfolio quotes, loading behavior, or activity refresh rules change.
    final refreshId = ++_refreshId;
    if (mounted && !_hasLoaded) setState(() => _loading = true);
    final address = context.read<PrivyService>().walletAddress;
    if (address == null || address.isEmpty) {
      if (mounted && refreshId == _refreshId) {
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
    {
      final wallet = context.read<WalletService>();
      final contracts = context.read<ContractService>();
      final portfolio = PortfolioService();
      final rwa = RwaService();
      try {
        final balances = await Future.wait([
          wallet.getMonBalance(ownerAddress: address),
          contracts.getSprinkleBalance(address),
          contracts.getFractionBalance(address),
        ]);
        if (!mounted) return;
        final basis = await portfolio.getCostBasis(context);
        final assets = <_HomeAsset>[];
        var value = 0.0;
        var cost = 0.0;
        for (final entry in basis.entries) {
          final data = Map<String, dynamic>.from(entry.value as Map);
          final amount = (data['total_amount'] as num?)?.toDouble() ?? 0;
          final entryCost = (data['total_cost_usd'] as num?)?.toDouble() ?? 0;
          var price = 0.0;
          final quote = await rwa.getQuote(entry.key);
          price = _number(quote['price_usd'] ?? quote['current_price']);
          final current = amount * price;
          value += current;
          cost += entryCost;
          assets.add(
            _HomeAsset(
              title: (data['name'] ?? data['symbol'] ?? entry.key).toString(),
              subtitle:
                  '${data['symbol'] ?? entry.key} · ${_amount(amount)} units',
              value: current,
              pnl: current - entryCost,
              apy: 'Live quote',
            ),
          );
        }
        if (!mounted) return;
        final activity = await TxHistoryService().getAll(context);
        if (mounted && refreshId == _refreshId) {
          setState(() {
            _monBalance = balances[0];
            _sprinkleBalance = balances[1];
            _fractionBalance = balances[2];
            _portfolioValue = value;
            _portfolioCost = cost;
            _assets = assets;
            _activity = activity;
          });
        }
      } catch (error) {
        if (mounted &&
            refreshId == _refreshId &&
            TransactionFeedback.isConnectionIssue(error)) {
          TransactionFeedback.showConnectionToast(context);
        }
      }
    }
    if (mounted && refreshId == _refreshId) {
      setState(() {
        _loading = false;
        _hasLoaded = true;
      });
    }
  }

  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static String _amount(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(4);

  static String _money(double value) => '\$${value.toStringAsFixed(2)}';

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
                          child: const Icon(Icons.person, color: Colors.white),
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
                          icon: const Icon(Icons.notifications_none_rounded),
                          color: const Color(0xFFBCAEFF),
                          tooltip: 'Notifications',
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.settings_outlined),
                          color: const Color(0xFFBCAEFF),
                          tooltip: 'Settings',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF836EF9), Color(0xFF43329A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF836EF9,
                            ).withValues(alpha: 0.2),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL PORTFOLIO VALUE',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _money(_portfolioValue),
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 14,
                                color: Color(0xFF00D18A),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${_portfolioValue - _portfolioCost >= 0 ? '+' : ''}${_money(_portfolioValue - _portfolioCost)} all time',
                                style: TextStyle(
                                  color: Color(0xFF00D18A),
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
                                icon: Icons.add_rounded,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const FundWalletScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _HeroAction(
                                label: 'Send',
                                icon: Icons.arrow_upward_rounded,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SendTokensScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _HeroAction(
                                label: 'Receive',
                                icon: Icons.arrow_downward_rounded,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const FundWalletScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_token(_monBalance)} MON  ·  ${_token(_fractionBalance)} fTokens  ·  ${_token(_sprinkleBalance)} AREAL',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    const _SectionHeader(
                      title: 'QUICK ACTIONS',
                      showSeeAll: false,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _QuickAction(
                          icon: Icons.search_rounded,
                          label: 'Explore',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ExploreScreen(),
                            ),
                          ),
                        ),
                        _QuickAction(
                          icon: Icons.shopping_bag_outlined,
                          label: 'Market',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NftMarketplaceScreen(),
                            ),
                          ),
                        ),
                        _QuickAction(
                          icon: Icons.star_border_rounded,
                          label: 'Watchlist',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WatchlistScreen(),
                            ),
                          ),
                        ),
                        _QuickAction(
                          icon: Icons.bar_chart_rounded,
                          label: 'Portfolio',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PortfolioScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
  final IconData icon;
  final VoidCallback? onPressed;

  const _HeroAction({required this.label, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed ?? () {},
        icon: Icon(icon, size: 14),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          padding: const EdgeInsets.symmetric(vertical: 9),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
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
                child: Icon(icon, color: const Color(0xFFBCAEFF), size: 22),
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
          GestureDetector(
            onTap: onSeeAll,
            child: const Text(
              'See All →',
              style: TextStyle(
                color: Color(0xFF9A87FF),
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

  const _HomeAsset({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.pnl,
    required this.apy,
  });
}

class _AssetRow extends StatelessWidget {
  final _HomeAsset asset;

  const _AssetRow({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            color: asset.pnl >= 0
                ? const Color(0xFFE7B94B)
                : const Color(0xFFA86B42),
            size: 36,
          ),
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
          const Icon(Icons.check_circle, color: Color(0xFF00D18A), size: 20),
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
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF837C95), fontSize: 12),
      ),
    );
  }
}
