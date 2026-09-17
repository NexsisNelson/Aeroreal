import 'package:flutter/material.dart';

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
