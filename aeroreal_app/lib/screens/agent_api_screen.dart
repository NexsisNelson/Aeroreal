import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AgentApiScreen extends StatefulWidget {
  const AgentApiScreen({super.key});

  @override
  State<AgentApiScreen> createState() => _AgentApiScreenState();
}

class _AgentApiScreenState extends State<AgentApiScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

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
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaults = _data?['vaults'] as Map<String, dynamic>? ?? {};
    final metadata = _data?['metadata'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent API'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh agent data',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(error: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF836EF9),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _ProtocolHeader(
                    protocol: _data?['protocol']?.toString() ?? 'Aeroreal',
                    chain: _data?['chain']?.toString() ?? 'Unknown chain',
                    vaultCount: metadata['total_vaults']?.toString() ?? '0',
                    compliance:
                        metadata['compliance_layer']?.toString() ?? 'Unknown',
                  ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33836EF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROTOCOL',
            style: TextStyle(
              color: Color(0xFF9F90FF),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            protocol,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _DetailLine(label: 'Chain', value: chain),
          _DetailLine(label: 'Vaults', value: vaultCount),
          _DetailLine(label: 'Compliance', value: compliance),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            id.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF9F90FF),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            vault['asset_name']?.toString() ?? 'Unnamed asset',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
            tradingEnabled ? 'Trading enabled' : 'Preview mode',
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

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
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
