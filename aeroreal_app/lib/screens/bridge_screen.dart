import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../services/privy_service.dart';

// UI/UX: Controls the bridge form, progress messaging, error state, and the
// burn/mint transaction results displayed after a bridge request.
class BridgeScreen extends StatefulWidget {
  const BridgeScreen({super.key});

  @override
  State<BridgeScreen> createState() => _BridgeScreenState();
}

class _BridgeScreenState extends State<BridgeScreen> {
  final _amountController = TextEditingController(text: '10');
  bool _loading = false;
  String? _status;
  String? _error;
  String? _burnTx;
  String? _mintTx;

  String get _baseUrl =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3001'
      : 'http://localhost:3001';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _bridge() async {
    setState(() {
      _loading = true;
      _status = 'Initiating bridge...';
      _error = null;
      _burnTx = null;
      _mintTx = null;
    });
    try {
      final address = context.read<PrivyService>().walletAddress;
      if (address == null) {
        throw Exception('No wallet connected');
      }
      final amount = double.tryParse(_amountController.text.trim());
      if (amount == null || amount <= 0) {
        throw Exception('Enter a valid USDC amount');
      }
      final baseUnits = BigInt.from(amount * 1000000).toString();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/bridge/cctp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': baseUnits, 'recipientAddress': address}),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(body['error'] ?? 'Bridge failed');
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Bridge complete!';
        _burnTx = body['burnTx']?.toString();
        _mintTx = body['mintTx']?.toString();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = null;
        _error = 'Bridge failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bridge to Monad')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Bridge USDC from Base to Monad',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Powered by Circle CCTP. Your USDC burns on Base Sepolia and mints to your wallet on Monad.',
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (USDC)',
              prefixIcon: Icon(Icons.attach_money),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _loading ? null : _bridge,
              icon: const Icon(Icons.swap_horiz),
              label: Text(_loading ? 'Bridging...' : 'Bridge USDC'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 74, 24, 199),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 20),
            Text(
              _status!,
              style: const TextStyle(
                color: Color(0xFF00D18A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (_burnTx != null) ...[
            const SizedBox(height: 16),
            _TxRow(label: 'Burn (Base Sepolia)', hash: _burnTx!),
          ],
          if (_mintTx != null) ...[
            const SizedBox(height: 8),
            _TxRow(label: 'Mint (Monad)', hash: _mintTx!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 20),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final String label;
  final String hash;
  const _TxRow({required this.label, required this.hash});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 0, 0, 0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 4),
        SelectableText(
          hash,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
        ),
      ],
    ),
  );
}
