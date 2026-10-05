// lib/screens/fund_wallet_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/contract_service.dart';
import '../services/privy_service.dart';
import '../services/wallet_service.dart';

class FundWalletScreen extends StatefulWidget {
  const FundWalletScreen({super.key});

  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}

class _FundWalletScreenState extends State<FundWalletScreen> {
  BigInt _monBalance = BigInt.zero;
  BigInt _musdBalance = BigInt.zero;
  BigInt _goldBalance = BigInt.zero;
  BigInt _coffeeBalance = BigInt.zero;
  BigInt _cooldown = BigInt.zero;
  BigInt _totalClaims = BigInt.zero;
  bool _loading = true;
  bool _claiming = false;
  String? _claimStatus;
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
        contracts.getMockStablecoinBalance(addr),
        contracts.getGoldFractionBalance(addr),
        contracts.getCoffeeFractionBalance(addr),
        contracts.getFaucetCooldown(addr),
        contracts.getTotalClaims(),
      ]);
      if (!mounted) return;
      setState(() {
        _address = addr;
        _monBalance = results[0];
        _musdBalance = results[1];
        _goldBalance = results[2];
        _coffeeBalance = results[3];
        _cooldown = results[4];
        _totalClaims = results[5];
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _address = addr;
        _loading = false;
      });
    }
  }

  Future<void> _claimTokens() async {
    final contracts = context.read<ContractService>();
    setState(() {
      _claiming = true;
      _claimStatus = 'Claiming testnet tokens...';
    });

    try {
      await contracts.claimFromFaucet();
      await Future.delayed(const Duration(seconds: 4));

      await _load();

      setState(() {
        _claiming = false;
        _claimStatus = 'Claimed!';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Claimed: 10,000 mUSD · 1,000 fGOLD · 1,000 fCOFFEE · 1 NFT',
          ),
          backgroundColor: Color(0xFF00D18A),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() {
        _claiming = false;
        _claimStatus = 'Claim failed: $e';
      });
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
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Get testnet tokens',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Claim free tokens from our public faucet, or send MON to your address.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF836EF9), Color(0xFF5C4BC7)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF836EF9).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.water_drop, color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Claim Testnet Tokens',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'One claim gives you:',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      _bullet('10,000 mUSD (stablecoin)'),
                      _bullet('1,000 fGOLD (gold fractions)'),
                      _bullet('1,000 fCOFFEE (coffee fractions)'),
                      _bullet('1 Demo NFT'),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _claiming || _cooldown > BigInt.zero
                              ? null
                              : _claimTokens,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF836EF9),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            disabledBackgroundColor: Colors.white.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          child: _claiming
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF836EF9),
                                  ),
                                )
                              : Text(
                                  _cooldown > BigInt.zero
                                      ? 'Claim in ${_formatCooldown(_cooldown)}'
                                      : 'Claim Now',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      if (_claimStatus != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _claimStatus!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Total claims on the network: ${_totalClaims.toString()}',
                        style: const TextStyle(
                          color: Colors.white54,
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
                          Icon(Icons.bolt, color: Color(0xFFED9B40), size: 20),
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
                        icon: const Icon(Icons.open_in_new, size: 16),
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
                              icon: const Icon(
                                Icons.copy,
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
                _balanceRow('mUSD (stablecoin)', _formatBalance(_musdBalance)),
                _balanceRow('fGOLD (gold)', _formatBalance(_goldBalance)),
                _balanceRow('fCOFFEE (coffee)', _formatBalance(_coffeeBalance)),
              ],
            ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white70, size: 14),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
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
