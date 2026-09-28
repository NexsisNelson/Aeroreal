import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../services/contract_service.dart';

// UI/UX: Controls token selection, recipient/amount inputs, validation,
// submit progress, confirmation dialog, and transfer error feedback.
class SendTokensScreen extends StatefulWidget {
  const SendTokensScreen({super.key});

  @override
  State<SendTokensScreen> createState() => _SendTokensScreenState();
}

class _SendTokensScreenState extends State<SendTokensScreen> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  String _token = 'fTokens';
  bool _sending = false;
  String? _error;

  String get _tokenAddress => _token == 'fTokens'
      ? AppConstants.fractionToken
      : AppConstants.sprinkleToken;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    // Interaction touchpoint: change validation, token transfer behavior, or
    // post-submit navigation here.
    final recipient = _recipientController.text.trim();
    final amountText = _amountController.text.trim();
    final validRecipient = RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(recipient);
    if (!validRecipient) {
      setState(() => _error = 'Enter a valid recipient address');
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final rawAmount = context.read<ContractService>().parseToken(amountText);
      final hash = await context.read<ContractService>().transferERC20(
        tokenAddress: _tokenAddress,
        recipient: recipient,
        amount: rawAmount,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Transfer submitted'),
          content: SelectableText(hash),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Transfer failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send tokens')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _token,
            decoration: const InputDecoration(labelText: 'Token'),
            items: const [
              DropdownMenuItem(value: 'fTokens', child: Text('fTokens')),
              DropdownMenuItem(value: 'AREAL', child: Text('AREAL')),
            ],
            onChanged: _sending
                ? null
                : (value) => setState(() => _token = value!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _recipientController,
            enabled: !_sending,
            decoration: const InputDecoration(
              labelText: 'Recipient address',
              hintText: '0x...',
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            enabled: !_sending,
            decoration: const InputDecoration(labelText: 'Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.arrow_upward),
            label: Text(_sending ? 'Sending...' : 'Send $_token'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    );
  }
}
