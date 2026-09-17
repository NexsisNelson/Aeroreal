import 'package:flutter/material.dart';

class RiskDisclosure extends StatelessWidget {
  final String assetType;

  const RiskDisclosure({super.key, required this.assetType});

  String get _riskText {
    switch (assetType) {
      case 'Commodity':
        return 'Commodity investments carry market price risk. The value of the underlying goods may fluctuate based on global supply, demand, and geopolitical factors. Storage and custody risks are borne by the vault custodian.';
      case 'Invoice':
        return 'Invoice investments carry credit risk. If the buyer fails to pay at maturity, investors may lose part or all of their principal. Past performance is not indicative of future results.';
      default:
        return 'This is a tokenized real-world asset. Investing involves risk of loss. Past performance is not indicative of future results.';
    }
  }

  Color get _accentColor {
    switch (assetType) {
      case 'Commodity':
        return const Color(0xFFFF6B35);
      case 'Invoice':
        return const Color(0xFF00D18A);
      default:
        return const Color(0xFF836EF9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk Disclosure',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _riskText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Only invest what you can afford to lose.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
