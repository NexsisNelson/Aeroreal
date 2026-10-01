import 'package:flutter/material.dart';
import '../utils/app_icons.dart';

import 'create_nft_screen.dart';
import 'nft_fractionalize_screen.dart';
import 'rwa_tokenize_screen.dart';

// UI/UX: Controls the creation chooser cards and the navigation into NFT or
// real-world-asset tokenization flows.
class FractionalizeScreen extends StatelessWidget {
  const FractionalizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const Text(
              'Create',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'What do you want to fractionalize?',
              style: TextStyle(color: Color(0xFF9C96A9), fontSize: 14),
            ),
            const SizedBox(height: 24),
            _CreationCard(
              icon: AppIcons.imageOutlined,
              color: const Color.fromARGB(255, 74, 24, 199),
              gradient: const [Color(0xFF5740A9), Color(0xFF21183F)],
              title: 'Fractionalize an NFT',
              subtitle: 'Lock an NFT and mint 10,000 tradeable fractions',
              bullets: const [
                'Works with any ERC-721 NFT',
                'Earns \$AREAL rewards every second',
                'Redeem by re-collecting 100% of fractions',
              ],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NftFractionalizeScreen(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _CreationCard(
              icon: AppIcons.imageOutlined,
              color: const Color(0xFF00D18A),
              gradient: const [Color(0xFF0C8F68), Color(0xFF12382F)],
              title: 'Create an NFT',
              subtitle: 'Upload an image and mint your own NFT on Monad',
              bullets: const [
                'No gas fees to list on testnet',
                'Appears in the Marketplace instantly',
                'Can be fractionalized and traded',
              ],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateNftScreen()),
              ),
            ),
            const SizedBox(height: 20),
            _CreationCard(
              icon: AppIcons.public,
              color: const Color(0xFF00D18A),
              gradient: const [Color(0xFF098E69), Color(0xFF12382F)],
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
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 0, 0, 0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(
                    AppIcons.infoOutline,
                    color: Color(0xFF836EF9),
                    size: 20,
                  ),
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
      ),
    );
  }
}

class _CreationCard extends StatelessWidget {
  final FaIconData icon;
  final Color color;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final VoidCallback onTap;

  const _CreationCard({
    required this.icon,
    required this.color,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      shadowColor: color.withValues(alpha: 0.32),
      elevation: 10,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.28),
                      shape: BoxShape.circle,
                    ),
                    child: AppIcon(icon, color: Colors.white, size: 27),
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
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppIcon(AppIcons.chevronRight, color: color),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              ...bullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      AppIcon(
                        AppIcons.checkCircle,
                        color: color == const Color(0xFF00D18A)
                            ? Colors.white
                            : const Color(0xFF00D18A),
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b,
                          style: const TextStyle(
                            color: Color(0xD9FFFFFF),
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
