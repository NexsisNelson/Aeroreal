import 'package:flutter/material.dart';
import '../utils/app_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/traction_service.dart';

// UI/UX: Controls transaction analytics cards, action breakdowns, refresh,
// empty states, and explorer-link presentation.
class TractionScreen extends StatefulWidget {
  const TractionScreen({super.key});

  @override
  State<TractionScreen> createState() => _TractionScreenState();
}

class _TractionScreenState extends State<TractionScreen> {
  final _service = TractionService();
  List<TractionEntry> _entries = const <TractionEntry>[];
  Map<TractionAction, int> _counts = const <TractionAction, int>{};
  int _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _service.getAll(context);
    if (!mounted) return;
    final counts = await _service.getCountsByAction(context);
    if (!mounted) return;
    final total = await _service.getTotalCount(context);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _counts = counts;
      _total = total;
      _loading = false;
    });
  }

  Future<void> _openExplorer(String hash) async {
    final uri = Uri.parse('https://testnet.monadscan.com/tx/$hash');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _actionLabel(TractionAction action) {
    switch (action) {
      case TractionAction.mintNft:
        return 'Mint NFT';
      case TractionAction.fractionalizeNft:
        return 'Fractionalize NFT';
      case TractionAction.tokenizeRwa:
        return 'Tokenize RWA';
      case TractionAction.listNft:
        return 'List NFT';
      case TractionAction.buyNft:
        return 'Buy NFT';
      case TractionAction.stakeFractions:
        return 'Stake';
      case TractionAction.claimYield:
        return 'Claim Yield';
      case TractionAction.depositRevenue:
        return 'Deposit Revenue';
      case TractionAction.addToWhitelist:
        return 'Whitelist';
      case TractionAction.kycVerified:
        return 'KYC Verified';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traction'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const AppIcon(AppIcons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
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
                        'Total Transactions',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_total',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'on Monad Testnet',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Action Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_counts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'No transactions yet. Start by minting an NFT or depositing revenue.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  ..._counts.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _actionLabel(entry.key),
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(
                              color: Color(0xFF836EF9),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Recent Transactions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._entries
                    .take(20)
                    .map(
                      (entry) => GestureDetector(
                        onTap: () => _openExplorer(entry.hash),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 0, 0, 0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const AppIcon(
                                AppIcons.checkCircle,
                                color: Color(0xFF00D18A),
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _actionLabel(entry.action),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      entry.hash.length > 18
                                          ? '${entry.hash.substring(0, 18)}...'
                                          : entry.hash,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    ),
                                    if (entry.description.isNotEmpty)
                                      Text(
                                        entry.description,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const AppIcon(
                                AppIcons.openInNew,
                                color: Colors.white54,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
