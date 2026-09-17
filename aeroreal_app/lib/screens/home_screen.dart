// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/contract_service.dart';
import '../services/privy_service.dart';
import '../services/wallet_service.dart';
import 'fractionalize_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _monBalance;
  String? _sprinkleBalance;
  String? _fractionBalance;
  bool _loading = true;
  int _refreshId = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final refreshId = ++_refreshId;
    if (mounted) setState(() => _loading = true);
    final wallet = context.read<WalletService>();
    final privy = context.read<PrivyService>();
    final contracts = context.read<ContractService>();
    final privyAddress = privy.walletAddress;

    if (privyAddress == null || privyAddress.isEmpty) {
      if (mounted) {
        setState(() {
          _monBalance = null;
          _sprinkleBalance = null;
          _fractionBalance = null;
          _loading = false;
        });
      }
      return;
    }

    try {
      final address = privyAddress;
      final results = await Future.wait([
        wallet
            .getMonBalance(ownerAddress: address)
            .then<BigInt?>((value) => value)
            .catchError((_) => null),
        contracts
            .getSprinkleBalance(address)
            .then<BigInt?>((value) => value)
            .catchError((_) => null),
        contracts
            .getFractionBalance(address)
            .then<BigInt?>((value) => value)
            .catchError((_) => null),
      ]);

      if (!mounted || refreshId != _refreshId) return;
      setState(() {
        _monBalance = results[0] == null ? null : _formatMon(results[0]!);
        _sprinkleBalance = results[1] == null
            ? null
            : contracts.formatToken(results[1]!);
        _fractionBalance = results[2] == null
            ? null
            : contracts.formatToken(results[2]!);
        _loading = false;
      });
    } catch (_) {
      if (mounted && refreshId == _refreshId) {
        setState(() {
          _monBalance = null;
          _sprinkleBalance = null;
          _fractionBalance = null;
          _loading = false;
        });
      }
    }
  }

  String _formatMon(BigInt wei) {
    final unit = BigInt.from(10).pow(18);
    final whole = wei ~/ unit;
    final remainder = (wei % unit).toString().padLeft(18, '0');
    return '$whole.${remainder.substring(0, 4)}';
  }

  Future<void> _copyAddress(String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Wallet address copied')));
  }

  @override
  Widget build(BuildContext context) {
    final address = context.read<PrivyService>().walletAddress;
    final shortAddress = address == null
        ? ''
        : '${address.substring(0, 6)}...${address.substring(address.length - 4)}';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF836EF9),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Peace, God.',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (address != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shortAddress,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _copyAddress(address),
                              icon: const Icon(Icons.copy, size: 16),
                              color: Colors.white54,
                              tooltip: 'Copy wallet address',
                              padding: const EdgeInsets.only(left: 8),
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh, color: Color(0xFF836EF9)),
                    tooltip: 'Refresh balances',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF836EF9), Color(0xFF5C4BC7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MON Balance',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loading ? '—' : '${_monBalance ?? '0.0000'} MON',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.bolt, size: 16, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          'Monad Testnet',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _AssetCard(
                      label: 'Fractions',
                      value: _fractionBalance ?? '0',
                      symbol: 'fMDAPE',
                      icon: Icons.pie_chart_outline,
                      color: const Color(0xFF836EF9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AssetCard(
                      label: 'Sprinkles',
                      value: _sprinkleBalance ?? '0',
                      symbol: 'SPR',
                      icon: Icons.water_drop_outlined,
                      color: const Color(0xFF00D18A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.add_circle_outline,
                title: 'Fractionalize an NFT',
                subtitle: 'Lock an NFT and mint fractions',
                color: const Color(0xFF836EF9),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FractionalizeScreen(),
                    ),
                  );
                },
              ),
              _ActionTile(
                icon: Icons.water_drop,
                title: 'Claim Micro Yield',
                subtitle: 'Collect your accumulated SPR',
                color: const Color(0xFF00D18A),
                onTap: () {},
              ),
              _ActionTile(
                icon: Icons.currency_exchange,
                title: 'Trade Fractions',
                subtitle: 'Swap fractions with others',
                color: const Color(0xFFED9B40),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  final String label;
  final String value;
  final String symbol;
  final IconData icon;
  final Color color;

  const _AssetCard({
    required this.label,
    required this.value,
    required this.symbol,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            symbol,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
