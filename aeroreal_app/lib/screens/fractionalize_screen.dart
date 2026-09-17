import 'package:flutter/material.dart';

import 'nft_fractionalize_screen.dart';
import 'rwa_tokenize_screen.dart';

class FractionalizeScreen extends StatelessWidget {
  const FractionalizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'What do you want to fractionalize?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aeroreal supports both digital and real-world assets. Pick a path to get started.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 32),
          _CreationCard(
            icon: Icons.image_outlined,
            color: const Color(0xFF836EF9),
            title: 'Fractionalize an NFT',
            subtitle: 'Lock an NFT and mint 10,000 tradeable fractions',
            bullets: const [
              'Works with any ERC-721 NFT',
              'Earns \$SPR rewards every second',
              'Redeem by re-collecting 100% of fractions',
            ],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NftFractionalizeScreen()),
            ),
          ),
          const SizedBox(height: 20),
          _CreationCard(
            icon: Icons.public,
            color: const Color(0xFF00D18A),
            title: 'Tokenize a Real-World Asset',
            subtitle: 'Turn commodities or invoices into compliant tokens',
            bullets: const [
              'KYC-whitelisted for global compliance',
              'Earns real stablecoin yield from cash flows',
              'Live audit reports and custodian metadata',
            ],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RwaTokenizeScreen()),
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1625),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFF836EF9), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Both paths use the same vault infrastructure. The difference is compliance: RWA tokens require KYC-verified wallets, while NFTs are open to anyone.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
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

class _CreationCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final VoidCallback onTap;

  const _CreationCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1625),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withAlpha(38),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: color),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              ...bullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: color, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
