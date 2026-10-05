import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../services/contract_service.dart';
import '../services/privy_service.dart';
import '../services/yield_history_service.dart';
import '../widgets/yield_chart.dart';

// UI/UX: Controls yield tabs, staking controls, drip-jar visuals, claim/fund
// actions, polling, loading, processing, and error states.
class YieldScreen extends StatefulWidget {
  const YieldScreen({super.key});

  @override
  State<YieldScreen> createState() => _YieldScreenState();
}

class _YieldScreenState extends State<YieldScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _ticker;
  bool _tickInFlight = false;
  bool _refreshInFlight = false;

  BigInt _nftEarned = BigInt.zero;
  BigInt _nftStaked = BigInt.zero;
  BigInt _nftTotalStaked = BigInt.zero;
  BigInt _nftRewardRate = BigInt.zero;
  BigInt _goldEarned = BigInt.zero;
  BigInt _goldStaked = BigInt.zero;
  BigInt _coffeeEarned = BigInt.zero;
  BigInt _coffeeStaked = BigInt.zero;
  List<YieldSnapshot> _nftHistory = [];
  List<YieldSnapshot> _goldHistory = [];
  List<YieldSnapshot> _coffeeHistory = [];
  final _yieldHistory = YieldHistoryService();

  bool _loading = true;
  bool _processing = false;
  bool _pulse = false;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _tick() async {
    if (_tickInFlight) return;
    _tickInFlight = true;
    final privy = context.read<PrivyService>();
    final contracts = context.read<ContractService>();
    final addr = privy.walletAddress;
    if (addr == null) {
      if (!mounted) return;
      setState(() {
        _goldEarned += BigInt.from(100000000000000);
        _pulse = !_pulse;
      });
      _tickInFlight = false;
      return;
    }

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
        _pulse = !_pulse;
      });
    } catch (_) {
      // Keep the last known yield visible when the RPC is temporarily slow.
    } finally {
      _tickInFlight = false;
    }
  }

  Future<void> _refresh() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    setState(() {
      _loading = true;
    });

    final privy = context.read<PrivyService>();
    final contracts = context.read<ContractService>();
    final addr = privy.walletAddress;

    if (addr == null) {
      setState(() {
        _goldEarned = BigInt.parse('12458200000000000000');
        _goldStaked = BigInt.parse('10000000000000000000000');
        _coffeeEarned = BigInt.parse('8420000000000000000');
        _coffeeStaked = BigInt.parse('5000000000000000000000');
        _nftEarned = BigInt.parse('3250000000000000000');
        _nftStaked = BigInt.parse('1000000000000000000000');
        _nftTotalStaked = BigInt.zero;
        _nftRewardRate = BigInt.zero;
        _nftHistory = [];
        _goldHistory = [];
        _coffeeHistory = [];
        _loading = false;
      });
      _refreshInFlight = false;
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
        contracts.getTotalStaked(),
        contracts.getRewardRate(),
      ]);

      if (!mounted) return;
      await _yieldHistory.recordSnapshot(
        context,
        streamerId: 'nft',
        amount: _asYieldAmount(results[2]),
      );
      if (!mounted) return;
      await _yieldHistory.recordSnapshot(
        context,
        streamerId: 'gold',
        amount: _asYieldAmount(results[0]),
      );
      if (!mounted) return;
      await _yieldHistory.recordSnapshot(
        context,
        streamerId: 'coffee',
        amount: _asYieldAmount(results[1]),
      );
      if (!mounted) return;
      final nftHistory = await _yieldHistory.getHistory(context, 'nft');
      if (!mounted) return;
      final goldHistory = await _yieldHistory.getHistory(context, 'gold');
      if (!mounted) return;
      final coffeeHistory = await _yieldHistory.getHistory(context, 'coffee');
      if (!mounted) return;
      setState(() {
        _goldEarned = results[0];
        _coffeeEarned = results[1];
        _nftEarned = results[2];
        _goldStaked = results[3];
        _coffeeStaked = results[4];
        _nftStaked = results[5];
        _nftTotalStaked = results[6];
        _nftRewardRate = results[7];
        _nftHistory = nftHistory;
        _goldHistory = goldHistory;
        _coffeeHistory = coffeeHistory;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _claimFrom(String streamerAddress) async {
    final contracts = context.read<ContractService>();
    setState(() {
      _processing = true;
      _status = 'Claiming...';
    });
    try {
      await contracts.claimRevenueYield(streamerAddress);
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        _status = 'Claimed!';
        _processing = false;
      });
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Claim failed: $e';
        _processing = false;
        _status = null;
      });
    }
  }

  Future<void> _stakeNft() async {
    final contracts = context.read<ContractService>();
    final walletAddress = context.read<PrivyService>().walletAddress;
    var enteredAmount = '';
    final amountText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stake fGOLD'),
        content: TextField(
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
          onChanged: (value) => enteredAmount = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(enteredAmount),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted || amountText == null) return;

    try {
      if (walletAddress == null || walletAddress.isEmpty) {
        throw StateError('Connect a wallet before staking.');
      }
      final amount = contracts.parseToken(amountText.trim());
      if (amount <= BigInt.zero) {
        throw const FormatException('Enter an amount greater than zero.');
      }
      final balance = await contracts.getERC20Balance(
        AppConstants.goldFractionToken,
        walletAddress,
      );
      if (!mounted) return;
      if (amount > balance) {
        throw StateError('Insufficient fGOLD balance.');
      }

      setState(() {
        _processing = true;
        _error = null;
        _status = 'Approving fGOLD...';
      });
      await contracts.approveRevenueStake(
        AppConstants.goldFractionToken,
        AppConstants.streamer,
        amount,
      );
      if (!mounted) return;
      setState(() => _status = 'Staking fGOLD...');
      await contracts.stakeRevenue(AppConstants.streamer, amount);
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'fGOLD staked';
      });
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = null;
        _error = 'Stake failed: $error';
      });
    }
  }

  Future<void> _simulateRevenue(
    String streamerAddress,
    String streamerName,
  ) async {
    final contracts = context.read<ContractService>();
    setState(() {
      _processing = true;
      _error = null;
      _status = 'Approving mUSD...';
    });

    try {
      final amount = BigInt.from(10000) * BigInt.from(10).pow(18);

      final approveTx = await contracts.approveMockStablecoin(
        streamerAddress,
        amount,
      );
      if (!mounted) return;
      await contracts.waitForReceipt(approveTx);
      if (!mounted) return;

      setState(() => _status = 'Depositing revenue...');
      final depositTx = await contracts.depositRevenue(streamerAddress, amount);
      if (!mounted) return;
      await contracts.waitForReceipt(depositTx);
      if (!mounted) return;

      setState(() {
        _processing = false;
        _status = '$streamerName: 10,000 mUSD deposited!';
      });

      await _refresh();
    } catch (e) {
      if (!mounted) return;
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
        title: const Text('Yield'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color.fromARGB(255, 74, 24, 199),
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
                  subtitle: 'Earned in \$AREAL (minted rewards)',
                  earned: _nftEarned,
                  staked: _nftStaked,
                  symbol: 'AREAL',
                  color: const Color.fromARGB(255, 74, 24, 199),
                  streamerAddress: AppConstants.streamer,
                  showDemoButton: false,
                  history: _nftHistory,
                ),
                _buildStreamerTab(
                  title: 'Gold Revenue',
                  subtitle: 'Earned in mUSD (real revenue)',
                  earned: _goldEarned,
                  staked: _goldStaked,
                  symbol: 'mUSD',
                  color: const Color(0xFFFFD700),
                  streamerAddress: AppConstants.goldStreamer,
                  showDemoButton: true,
                  history: _goldHistory,
                ),
                _buildStreamerTab(
                  title: 'Coffee Revenue',
                  subtitle: 'Earned in mUSD (real revenue)',
                  earned: _coffeeEarned,
                  staked: _coffeeStaked,
                  symbol: 'mUSD',
                  color: const Color(0xFFA0522D),
                  streamerAddress: AppConstants.coffeeStreamer,
                  showDemoButton: true,
                  history: _coffeeHistory,
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
    required String streamerAddress,
    required bool showDemoButton,
    required List<YieldSnapshot> history,
  }) {
    final contracts = context.read<ContractService>();
    final change24h = _yieldHistory.calculateChange(
      history,
      window: const Duration(hours: 24),
    );
    final change7d = _yieldHistory.calculateChange(
      history,
      window: const Duration(days: 7),
    );
    final change30d = _yieldHistory.calculateChange(
      history,
      window: const Duration(days: 30),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        _DripJar(
          earned: earned,
          title: title,
          symbol: symbol,
          color: color,
          pulse: _pulse,
        ),
        const SizedBox(height: 20),
        const Text(
          'YIELD HISTORY',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        YieldChart(history: history, color: color),
        const SizedBox(height: 10),
        YieldStatRow(
          label: '24h',
          value: _formatYieldDelta(change24h['delta']!, symbol),
          change: _formatPercent(change24h['percent']!),
          isPositive: change24h['percent']! >= 0,
        ),
        YieldStatRow(
          label: '7d',
          value: _formatYieldDelta(change7d['delta']!, symbol),
          change: _formatPercent(change7d['percent']!),
          isPositive: change7d['percent']! >= 0,
        ),
        YieldStatRow(
          label: '30d',
          value: _formatYieldDelta(change30d['delta']!, symbol),
          change: _formatPercent(change30d['percent']!),
          isPositive: change30d['percent']! >= 0,
        ),
        const SizedBox(height: 18),
        _statsCard(
          contracts,
          staked,
          symbol,
          totalStaked: symbol == 'AREAL' ? _nftTotalStaked : null,
          rewardRate: symbol == 'AREAL' ? _nftRewardRate : null,
        ),
        const SizedBox(height: 18),
        if (symbol == 'AREAL') ...[
          OutlinedButton.icon(
            onPressed: _processing ? null : _stakeNft,
            icon: const Icon(Icons.savings_outlined),
            label: const Text('Stake fGOLD'),
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
          onPressed: staked > BigInt.zero && !_processing
              ? () => _claimFrom(streamerAddress)
              : null,
          icon: const Icon(Icons.water_drop_outlined),
          label: Text('Claim ${contracts.formatToken(earned)} $symbol'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 74, 24, 199),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF332C4C),
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          symbol == 'AREAL'
              ? 'AREAL rewards are minted by the configured staking stream.'
              : 'Yield streams every second from real revenue. In production, this comes from rent, invoice repayment, or commodity sales.',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
          textAlign: TextAlign.center,
        ),
        if (showDemoButton) ...[
          const SizedBox(height: 16),
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
      ],
    );
  }

  double _asYieldAmount(dynamic value) {
    if (value is BigInt) return value.toDouble() / 1e18;
    if (value is num) return value.toDouble();
    return 0;
  }

  String _formatYieldDelta(double value, String symbol) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)} $symbol';
  }

  String _formatPercent(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(1)}%';
  }

  Widget _statsCard(
    ContractService contracts,
    BigInt staked,
    String symbol, {
    BigInt? totalStaked,
    BigInt? rewardRate,
  }) {
    final totalValue = totalStaked == null
        ? (symbol == 'mUSD' ? '10,000.00 fTokens' : '1,000.00 fTokens')
        : '${contracts.formatToken(totalStaked)} fTokens';
    final rateValue = rewardRate == null
        ? '0.0001 mUSD/sec'
        : '${contracts.formatToken(rewardRate)} $symbol/sec';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _StatRow(
            label: 'Total Staked',
            value: totalValue,
            color: Colors.white,
          ),
          _StatRow(
            label: 'Your Stake',
            value: '${contracts.formatToken(staked)} fTokens',
            color: Colors.white,
          ),
          _StatRow(label: 'Reward Rate', value: rateValue, color: Colors.white),
        ],
      ),
    );
  }
}

class _DripJar extends StatelessWidget {
  final BigInt earned;
  final String title;
  final String symbol;
  final Color color;
  final bool pulse;

  const _DripJar({
    required this.earned,
    required this.title,
    required this.symbol,
    required this.color,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final divisor = BigInt.from(10).pow(18);
    final whole = earned ~/ divisor;
    final remainder = earned % divisor;
    final decimals = remainder.toString().padLeft(18, '0').substring(0, 4);
    final formatted = '$whole.$decimals';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      height: 258,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withAlpha(128)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: pulse ? 0.38 : 0.18),
            blurRadius: pulse ? 28 : 18,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: 18, top: 16, child: _DripIcon(color: color)),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pending Yield',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 8),
                AnimatedScale(
                  scale: pulse ? 1.035 : 1,
                  duration: const Duration(milliseconds: 280),
                  child: Text(
                    formatted,
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  symbol.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 17),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Real revenue streaming',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
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

class _DripIcon extends StatefulWidget {
  final Color color;

  const _DripIcon({required this.color});

  @override
  State<_DripIcon> createState() => _DripIconState();
}

class _DripIconState extends State<_DripIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _controller.value * 8),
        child: Icon(
          Icons.water_drop,
          color: Colors.white.withValues(
            alpha: 0.82 - (_controller.value * 0.35),
          ),
          size: 24,
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
