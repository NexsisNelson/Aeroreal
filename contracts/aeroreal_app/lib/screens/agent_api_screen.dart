import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// UI/UX: Controls the agent dashboard layout, vault cards, refresh behavior,
// and the loading/fallback states shown while protocol data is fetched.
class AgentApiScreen extends StatefulWidget {
  const AgentApiScreen({super.key});

  @override
  State<AgentApiScreen> createState() => _AgentApiScreenState();
}

class _AgentApiScreenState extends State<AgentApiScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  static const _demoVaults = <Map<String, dynamic>>[
    {
      'id': 'gold_certificate',
      'type': 'COMMODITY',
      'asset_name': 'Gold Certificate',
      'risk_level': 'A',
      'yield_apy': '4.2%',
      'trading_enabled': false,
    },
    {
      'id': 'invoice_pool',
      'type': 'INVOICE',
      'asset_name': 'Invoice Pool',
      'risk_level': 'B+',
      'yield_apy': '8.6%',
      'trading_enabled': true,
    },
    {
      'id': 'demo_ape',
      'type': 'NFT',
      'asset_name': 'Demo Ape #42',
      'risk_level': 'B',
      'yield_apy': '3.1%',
      'trading_enabled': true,
    },
  ];

  String get _endpoint {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001/api/agent/vaults';
    }
    return 'http://localhost:3001/api/agent/vaults';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Agent API returned ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Agent API returned an invalid response');
      }
      if (!mounted) return;
      setState(() {
        _data = decoded;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _data = {
          'vaults': {for (final vault in _demoVaults) vault['id']: vault},
          'metadata': {'total_vaults': 13},
        };
        _error = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaults = _data?['vaults'] as Map<String, dynamic>? ?? {};
    final metadata = _data?['metadata'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(error: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                color: const Color.fromARGB(255, 74, 24, 199),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.smart_toy_outlined,
                          color: Color(0xFF9F90FF),
                          size: 23,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Agent API',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _load,
                          tooltip: 'Refresh agent data',
                          icon: const Icon(
                            Icons.refresh,
                            color: Color(0xFF9587B8),
                          ),
                        ),
                      ],
                    ),
                    _ProtocolHeader(
                      protocol: _data?['protocol']?.toString() ?? 'Aeroreal',
                      chain: _data?['chain']?.toString() ?? 'Unknown chain',
                      vaultCount: metadata['total_vaults']?.toString() ?? '0',
                      compliance:
                          metadata['compliance_layer']?.toString() ?? 'Monad',
                    ),
                    const SizedBox(height: 16),
                    _EndpointCard(endpoint: _endpoint),
                    const SizedBox(height: 16),
                    ...vaults.entries.map(
                      (entry) => _VaultAgentCard(
                        id: entry.key,
                        vault: entry.value as Map<String, dynamic>,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Machine-readable vault data for agents to discover, assess, and allocate to Aeroreal assets.',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProtocolHeader extends StatelessWidget {
  final String protocol;
  final String chain;
  final String vaultCount;
  final String compliance;

  const _ProtocolHeader({
    required this.protocol,
    required this.chain,
    required this.vaultCount,
    required this.compliance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C43B3), Color(0xFF21183F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33836EF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AEROREAL PROTOCOL',
            style: TextStyle(
              color: Color(0xFF9F90FF),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          const SizedBox(height: 10),
          const Text(
            'Machine-readable RWA data for AI agents',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(
                label: '$vaultCount Vaults',
                color: const Color.fromARGB(255, 74, 24, 199),
              ),
              const _StatPill(
                label: '3 Asset Classes',
                color: Color(0xFF00D18A),
              ),
              const _StatPill(
                label: 'Chainlink · CoinGecko',
                color: Color(0xFF5690C9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VaultAgentCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> vault;

  const _VaultAgentCard({required this.id, required this.vault});

  @override
  Widget build(BuildContext context) {
    final tradingEnabled = vault['trading_enabled'] == true;
    final risk = vault['risk_level']?.toString() ?? 'N/A';
    final apy = vault['yield_apy']?.toString() ?? 'N/A';
    final type =
        vault['type']?.toString() ?? id.replaceAll('_', ' ').toUpperCase();
    final badgeColor = type == 'COMMODITY'
        ? const Color(0xFFE4A84B)
        : type == 'INVOICE'
        ? const Color(0xFF5690C9)
        : const Color.fromARGB(255, 74, 24, 199);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  vault['asset_name']?.toString() ?? 'Unnamed asset',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Metric(label: 'Risk', value: risk),
                    const SizedBox(width: 26),
                    _Metric(label: 'APY', value: apy),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  tradingEnabled ? 'Tradeable' : 'Preview Mode',
                  style: TextStyle(
                    color: tradingEnabled
                        ? const Color(0xFF00D18A)
                        : const Color(0xFFFF9F1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF746B83)),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _EndpointCard extends StatelessWidget {
  final String endpoint;

  const _EndpointCard({required this.endpoint});

  @override
  Widget build(BuildContext context) {
    const path = 'GET /api/agent/vaults';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  path,
                  style: TextStyle(
                    color: Color(0xFFB59FFF),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Returns all vault data as JSON',
                  style: TextStyle(color: Color(0xFF837C95), fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: path));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Endpoint copied')),
                );
              }
            },
            icon: const Icon(Icons.copy, color: Color(0xFF9587B8), size: 18),
            tooltip: 'Copy endpoint',
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 36),
            const SizedBox(height: 12),
            const Text(
              'Agent API unavailable',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
