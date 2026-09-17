import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../services/contract_service.dart';
import '../services/privy_service.dart';

class YieldScreen extends StatefulWidget {
  const YieldScreen({super.key});

  @override
  State<YieldScreen> createState() => _YieldScreenState();
}

class _YieldScreenState extends State<YieldScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _ticker;

  BigInt _nftEarned = BigInt.zero;
  BigInt _nftStaked = BigInt.zero;
  BigInt _goldEarned = BigInt.zero;
  BigInt _goldStaked = BigInt.zero;
  BigInt _coffeeEarned = BigInt.zero;
  BigInt _coffeeStaked = BigInt.zero;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _tick() async {
    final privy = context.read<PrivyService>();
    final contracts = context.read<ContractService>();
    final addr = privy.walletAddress;
    if (addr == null) return;

    try {
      final gold = await contracts.getRevenueEarned(
        AppConstants.goldStreamer,
        addr,
      );
      final coffee = await contracts.getRevenueEarned(
        AppConstants.coffeeStreamer,
        addr,
      );
      final nft = await contracts.getRevenueEarned(AppConstants.streamer, addr);

      if (!mounted) return;
      setState(() {
        _goldEarned = gold;
        _coffeeEarned = coffee;
        _nftEarned = nft;
      });
    } catch (_) {}
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });

    final privy = context.read<PrivyService>();
    final contracts = context.read<ContractService>();
    final addr = privy.walletAddress;

    if (addr == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final results = await Future.wait([
        contracts.getRevenueEarned(AppConstants.goldStreamer, addr),
        contracts.getRevenueEarned(AppConstants.coffeeStreamer, addr),
        contracts.getRevenueEarned(AppConstants.streamer, addr),
        contracts.getRevenueStaked(AppConstants.goldStreamer, addr),
        contracts.getRevenueStaked(AppConstants.coffeeStreamer, addr),
        contracts.getRevenueStaked(AppConstants.streamer, addr),
      ]);

      if (!mounted) return;
      setState(() {
        _goldEarned = results[0];
        _coffeeEarned = results[1];
        _nftEarned = results[2];
        _goldStaked = results[3];
        _coffeeStaked = results[4];
        _nftStaked = results[5];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yield'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF836EF9),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'NFT', icon: Icon(Icons.image_outlined)),
            Tab(text: 'Gold', icon: Icon(Icons.workspace_premium)),
            Tab(text: 'Coffee', icon: Icon(Icons.coffee)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStreamerTab(
                  title: 'NFT Yield',
                  subtitle: 'Earned in \$SPR (minted rewards)',
                  earned: _nftEarned,
                  staked: _nftStaked,
                  symbol: 'SPR',
                  color: const Color(0xFF836EF9),
                ),
                _buildStreamerTab(
                  title: 'Gold Revenue',
                  subtitle: 'Earned in mUSD (real revenue)',
                  earned: _goldEarned,
                  staked: _goldStaked,
                  symbol: 'mUSD',
                  color: const Color(0xFFFFD700),
                ),
                _buildStreamerTab(
                  title: 'Coffee Revenue',
                  subtitle: 'Earned in mUSD (real revenue)',
                  earned: _coffeeEarned,
                  staked: _coffeeStaked,
                  symbol: 'mUSD',
                  color: const Color(0xFFA0522D),
                ),
              ],
            ),
    );
  }

  Widget _buildStreamerTab({
    required String title,
    required String subtitle,
    required BigInt earned,
    required BigInt staked,
    required String symbol,
    required Color color,
  }) {
    final contracts = context.read<ContractService>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _DripJar(earned: earned, title: title, symbol: symbol, color: color),
        const SizedBox(height: 24),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 24),
        _StatRow(
          label: 'Your Stake',
          value: '${contracts.formatToken(staked)} fTokens',
          color: color,
        ),
        const SizedBox(height: 24),
        if (staked > BigInt.zero)
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.water_drop),
            label: Text('Claim ${contracts.formatToken(earned)} $symbol'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
      ],
    );
  }
}

class _DripJar extends StatelessWidget {
  final BigInt earned;
  final String title;
  final String symbol;
  final Color color;

  const _DripJar({
    required this.earned,
    required this.title,
    required this.symbol,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final divisor = BigInt.from(10).pow(18);
    final whole = earned ~/ divisor;
    final remainder = earned % divisor;
    final decimals = remainder.toString().padLeft(18, '0').substring(0, 4);
    final formatted = '$whole.$decimals';

    return Container(
      height: 240,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withAlpha(128)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pending Yield',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              formatted,
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              symbol,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
