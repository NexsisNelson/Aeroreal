import 'package:flutter/material.dart';

import '../services/reputation_service.dart';

class ReputationBadge extends StatelessWidget {
  final IssuerReputation reputation;
  final bool showScore;

  const ReputationBadge({
    super.key,
    required this.reputation,
    this.showScore = true,
  });

  Color get _color {
    if (reputation.tier.startsWith('A')) return const Color(0xFF00D18A);
    if (reputation.tier.startsWith('B')) return const Color(0xFF836EF9);
    return const Color(0xFFED9B40);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, color: _color, size: 13),
          const SizedBox(width: 5),
          Text(
            reputation.tier,
            style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (showScore) ...[
            const SizedBox(width: 6),
            Text(
              '${reputation.score}',
              style: TextStyle(color: _color, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class ReputationCard extends StatelessWidget {
  final IssuerReputation reputation;

  const ReputationCard({super.key, required this.reputation});

  Color get _color {
    if (reputation.tier.startsWith('A')) return const Color(0xFF00D18A);
    if (reputation.tier.startsWith('B')) return const Color(0xFF836EF9);
    return const Color(0xFFED9B40);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: _color, size: 21),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Issuer Reputation',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              ReputationBadge(reputation: reputation, showScore: false),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${reputation.score}/100',
                style: TextStyle(
                  color: _color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Trust score',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          _stat('Assets Tokenized', '${reputation.assetsTokenized}'),
          _stat(
            'On-time Settlement',
            reputation.onTimeSettlement == null
                ? 'N/A'
                : '${reputation.onTimeSettlement}%',
          ),
          _stat('Audits Passed', '${reputation.auditsPassed}'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
