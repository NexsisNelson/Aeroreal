import 'package:flutter/material.dart';

// UI/UX: Controls the placeholder tokenization destination shown while the
// full RWA creation workflow is still being built.
class RwaTokenizeScreen extends StatelessWidget {
  const RwaTokenizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tokenize RWA')),
      body: const Center(
        child: Text(
          'RWA tokenization flow coming soon.',
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}
