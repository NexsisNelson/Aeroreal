// lib/screens/micro_yield_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../services/contract_service.dart';
import '../services/wallet_service.dart';

class MicroYieldScreen extends StatefulWidget {
  const MicroYieldScreen({super.key});

  @override
  State<MicroYieldScreen> createState() => _MicroYieldScreenState();
}

class _MicroYieldScreenState extends State<MicroYieldScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _ticker;

  // ---- Gold streamer state ----
  Map<String, dynamic>? _goldInfo;
  BigInt _goldEarned = BigInt.zero;
  BigInt _goldStaked = BigInt.zero;

  // ---- Coffee streamer state ----
  Map<String, dynamic>? _coffeeInfo;
  BigInt _coffeeEarned = BigInt.zero;
  BigInt _coffeeStaked = BigInt.zero;

  bool _loading = true;
  bool _processing = false;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final wallet = context.read<WalletService>();
    final contracts = context.read<ContractService>();
    if (!wallet.hasWallet) return;

    try {
      final goldEarned = await contracts.getRevenueEarned(
        AppConstants.goldStreamer,
        wallet.address!.with0x,
      );
      final coffeeEarned = await contracts.getRevenueEarned(
        AppConstants.coffeeStreamer,
        wallet.address!.with0x,
      );
      if (!mounted) return;
      setState(() {
        _goldEarned = goldEarned;
        _coffeeEarned = coffeeEarned;
      });
    } catch (_) {
      // Silent.
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final wallet = context.read<WalletService>();
    final contracts = context.read<ContractService>();

    if (!wallet.hasWallet) {
      setState(() => _loading = false);
      return;
    }

    try {
      final addr = wallet.address!.with0x;
      final goldInfo = await contracts.getGoldStreamerInfo();
      final coffeeInfo = await contracts.getCoffeeStreamerInfo();
      final goldEarned = await contracts.getRevenueEarned(
        AppConstants.goldStreamer,
        addr,
      );
      final coffeeEarned = await contracts.getRevenueEarned(
        AppConstants.coffeeStreamer,
        addr,
      );
      final goldStaked = await contracts.getRevenueStaked(
        AppConstants.goldStreamer,
        addr,
      );
      final coffeeStaked = await contracts.getRevenueStaked(
        AppConstants.coffeeStreamer,
        addr,
      );

      if (!mounted) return;
      setState(() {
        _goldInfo = goldInfo;
        _coffeeInfo = coffeeInfo;
        _goldEarned = goldEarned;
        _coffeeEarned = coffeeEarned;
        _goldStaked = goldStaked;
        _coffeeStaked = coffeeStaked;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
      });
    }
  }

  Future<void> _claimFrom(String streamerAddress) async {
    setState(() {
      _processing = true;
      _status = 'Claiming...';
    });
    try {
      final contracts = context.read<ContractService>();
      await contracts.claimRevenueYield(streamerAddress);
      await Future.delayed(const Duration(seconds: 4));
      setState(() {
        _status = 'Claimed!';
        _processing = false;
      });
      await _refresh();
    } catch (e) {
      setState(() {
        _error = 'Claim failed: $e';
        _processing = false;
        _status = null;
      });
    }
  }

  Future<void> _simulateRevenue(
    String streamerAddress,
    String streamerName,
  ) async {
    setState(() {
      _processing = true;
      _error = null;
      _status = 'Approving mUSD...';
    });

    try {
      final contracts = context.read<ContractService>();
      final amount = BigInt.from(10000) * BigInt.from(10).pow(18);

      final approveTx = await contracts.approveMockStablecoin(
        streamerAddress,
        amount,
      );
      await contracts.waitForReceipt(approveTx);

      setState(() => _status = 'Depositing revenue...');
      final depositTx = await contracts.depositRevenue(streamerAddress, amount);
      await contracts.waitForReceipt(depositTx);

      setState(() {
        _processing = false;
        _status = '$streamerName: 10,000 mUSD deposited!';
      });

      await _refresh();
    } catch (e) {
      setState(() {
        _error = 'Simulate failed: $e';
        _processing = false;
        _status = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Micro Yield'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF836EF9),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Gold', icon: Icon(Icons.monetization_on)),
            Tab(text: 'Coffee', icon: Icon(Icons.local_cafe)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStreamerView(
                  title: 'Gold Revenue',
                  subtitle: 'Real stablecoin yield from tokenized gold',
                  info: _goldInfo,
                  earned: _goldEarned,
                  staked: _goldStaked,
                  streamerAddress: AppConstants.goldStreamer,
                  color: const Color(0xFFEABF62),
                ),
                _buildStreamerView(
                  title: 'Coffee Revenue',
                  subtitle: 'Real stablecoin yield from coffee export receipts',
                  info: _coffeeInfo,
                  earned: _coffeeEarned,
                  staked: _coffeeStaked,
                  streamerAddress: AppConstants.coffeeStreamer,
                  color: const Color(0xFFB77B48),
                ),
              ],
            ),
    );
  }

  Widget _buildStreamerView({
    required String title,
    required String subtitle,
    required Map<String, dynamic>? info,
    required BigInt earned,
    required BigInt staked,
    required String streamerAddress,
    required Color color,
  }) {
    final contracts = context.read<ContractService>();
    final lifetimeRevenue =
        info?['lifetimeRevenueReceived'] as BigInt? ?? BigInt.zero;
    final lifetimeClaimed =
        info?['lifetimeYieldClaimed'] as BigInt? ?? BigInt.zero;
    final poolBalance = info?['currentPoolBalance'] as BigInt? ?? BigInt.zero;
    final totalStaked = info?['totalStaked'] as BigInt? ?? BigInt.zero;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _RevenueDripJar(earned: earned, title: title, color: color),
        const SizedBox(height: 24),
        const Text(
          'Live Revenue Pool',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _StatRow(
          label: 'Lifetime Revenue Received',
          value: '${contracts.formatToken(lifetimeRevenue)} mUSD',
          color: color,
        ),
        _StatRow(
          label: 'Lifetime Yield Claimed',
          value: '${contracts.formatToken(lifetimeClaimed)} mUSD',
          color: Colors.white70,
        ),
        _StatRow(
          label: 'Current Pool Balance',
          value: '${contracts.formatToken(poolBalance)} mUSD',
          color: Colors.white70,
        ),
        const SizedBox(height: 20),
        const Text(
          'Staking',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _StatRow(
          label: 'Total Staked',
          value: '${contracts.formatToken(totalStaked)} fTokens',
          color: Colors.white70,
        ),
        _StatRow(
          label: 'Your Stake',
          value: '${contracts.formatToken(staked)} fTokens',
          color: color,
        ),
        const SizedBox(height: 24),
        if (staked > BigInt.zero)
          ElevatedButton.icon(
            onPressed: _processing ? null : () => _claimFrom(streamerAddress),
            icon: const Icon(Icons.water_drop),
            label: Text(
              'Claim ${contracts.formatToken(earned)} mUSD',
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        if (staked == BigInt.zero) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1625),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'You have no stakes in this streamer yet. To earn real revenue, you need to hold fraction tokens for this asset.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
        if (_processing) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(_status ?? 'Processing...'),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 20),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 24),
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _processing
              ? null
              : () => _simulateRevenue(streamerAddress, title),
          icon: const Icon(Icons.science, size: 16),
          label: const Text('🧪 Simulate Revenue Payment (10,000 mUSD)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Demo action: deposits test mUSD into this streamer to trigger the drip. In production, this comes from real revenue (rent, invoice settlement, commodity sales).',
          style: TextStyle(color: Colors.white38, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RevenueDripJar extends StatelessWidget {
  final BigInt earned;
  final String title;
  final Color color;

  const _RevenueDripJar({
    required this.earned,
    required this.title,
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
          colors: [color, color.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 24,
            right: 30,
            child: Icon(
              Icons.attach_money,
              color: Colors.white.withValues(alpha: 0.15),
              size: 80,
            ),
          ),
          Center(
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
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'mUSD',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Real revenue streaming',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
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
