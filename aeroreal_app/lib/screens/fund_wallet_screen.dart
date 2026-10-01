// lib/screens/fund_wallet_screen.dart

import 'package:flutter/material.dart';
import '../utils/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/constants.dart';
import '../services/contract_service.dart';
import '../services/privy_service.dart';
import '../services/wallet_service.dart';
import '../utils/error_mapper.dart';

class FundWalletScreen extends StatefulWidget {
  const FundWalletScreen({super.key});

  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}

class _FundWalletScreenState extends State<FundWalletScreen> {
  BigInt _monBalance = BigInt.zero;
  BigInt _arealBalance = BigInt.zero;
  BigInt _arealCooldown = BigInt.zero;
  BigInt _arealTotalClaims = BigInt.zero;
  BigInt _goldBalance = BigInt.zero;
  BigInt _coffeeBalance = BigInt.zero;
  bool _loading = true;
  bool _claimingAreal = false;
  String? _address;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final privy = context.read<PrivyService>();
    final contracts = context.read<ContractService>();
    final wallet = context.read<WalletService>();
    final addr = privy.walletAddress;
    if (addr == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final results = await Future.wait([
        wallet.getMonBalance(ownerAddress: addr),
        contracts.getSprinkleBalance(addr),
        contracts.getGoldFractionBalance(addr),
        contracts.getCoffeeFractionBalance(addr),
        if (AppConstants.arealFaucet !=
            '0x0000000000000000000000000000000000000000') ...[
          contracts.getArealCooldown(addr),
          contracts.getArealTotalClaims(),
        ] else ...[
          Future<BigInt>.value(BigInt.zero),
          Future<BigInt>.value(BigInt.zero),
        ],
      ]);
      if (!mounted) return;
      setState(() {
        _address = addr;
        _monBalance = results[0];
        _arealBalance = results[1];
        _goldBalance = results[2];
        _coffeeBalance = results[3];
        _arealCooldown = results[4];
        _arealTotalClaims = results[5];
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _address = addr;
        _loading = false;
      });
    }
  }

  Future<void> _claimAreal() async {
    setState(() => _claimingAreal = true);
    try {
      await context.read<ContractService>().claimAreal();
      await Future<void>.delayed(const Duration(seconds: 4));
      await _load();
      if (!mounted) return;
      setState(() => _claimingAreal = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Claimed 100,000 AREAL!'),
          backgroundColor: Color(0xFF00D18A),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _claimingAreal = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorMapper.shortMessage(error)),
          backgroundColor: const Color(0xFFFF6B35),
        ),
      );
    }
  }

  void _copyAddress() {
    if (_address == null) return;
    Clipboard.setData(ClipboardData(text: _address!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address copied'),
        backgroundColor: Color(0xFF00D18A),
      ),
    );
  }

  Future<void> _openFaucet() async {
    final uri = Uri.parse('https://faucet.monad.xyz');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatCooldown(BigInt seconds) {
    final s = seconds.toInt();
    if (s < 3600) return '${(s / 60).round()}m';
    return '${(s / 3600).round()}h';
  }

  String _formatBalance(BigInt raw) {
    final divisor = BigInt.from(10).pow(18);
    final whole = raw ~/ divisor;
    final remainder = raw % divisor;
    final decimals = remainder.toString().padLeft(18, '0').substring(0, 4);
    return '$whole.$decimals';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fund Wallet'),
        actions: [
          IconButton(onPressed: _load, icon: const AppIcon(AppIcons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Fund your wallet',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Claim AREAL for in-app activity, or send MON to your address.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/card3.png'),
                      fit: BoxFit.fill,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          AppIcon(AppIcons.bolt, color: Colors.black, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Claim 100,000 AREAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'AREAL is the app\'s in-app currency. Use it to trade simulated assets, buy NFTs, list fractions, and earn yield.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _claimingAreal ||
                                  _arealCooldown > BigInt.zero ||
                                  AppConstants.arealFaucet ==
                                      '0x0000000000000000000000000000000000000000'
                              ? null
                              : _claimAreal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color.fromARGB(
                              255,
                              94,
                              15,
                              231,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _claimingAreal
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00D18A),
                                  ),
                                )
                              : Text(
                                  AppConstants.arealFaucet ==
                                          '0x0000000000000000000000000000000000000000'
                                      ? 'Faucet not deployed'
                                      : _arealCooldown > BigInt.zero
                                      ? 'Claim in ${_formatCooldown(_arealCooldown)}'
                                      : 'Claim Now',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total AREAL claims: ${_arealTotalClaims.toString()}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1625),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          AppIcon(
                            AppIcons.bolt,
                            color: Color(0xFFED9B40),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Need MON for gas?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Get free MON from the official Monad faucet.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openFaucet,
                        icon: const AppIcon(AppIcons.openInNew, size: 16),
                        label: const Text('Open Monad Faucet'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          foregroundColor: const Color(0xFFED9B40),
                          side: const BorderSide(color: Color(0xFFED9B40)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_address != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: QrImageView(
                        data: _address!,
                        version: QrVersions.auto,
                        size: 160,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                if (_address != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1625),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Monad Address',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                _address!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _copyAddress,
                              icon: const AppIcon(
                                AppIcons.copy,
                                color: Color(0xFF836EF9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                const Text(
                  'YOUR BALANCES',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _balanceRow('MON (gas)', _formatBalance(_monBalance)),
                _balanceRow(
                  'AREAL (in-app currency)',
                  _formatBalance(_arealBalance),
                ),
                _balanceRow('fGOLD (gold)', _formatBalance(_goldBalance)),
                _balanceRow('fCOFFEE (coffee)', _formatBalance(_coffeeBalance)),
              ],
            ),
    );
  }

  Widget _balanceRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
