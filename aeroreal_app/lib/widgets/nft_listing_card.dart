import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/contract_service.dart';

// UI/UX: Controls compact NFT listing card layout, placeholder imagery, tap-
// to-detail behavior, and the Buy action.
class NftListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final VoidCallback onBuy;
  final VoidCallback onTap;

  const NftListingCard({
    super.key,
    required this.listing,
    required this.onBuy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = context.read<ContractService>().formatToken(
      listing['price'] as BigInt,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color.fromARGB(
                        255,
                        74,
                        24,
                        199,
                      ).withValues(alpha: 0.6),
                      const Color(0xFF5C4BC7).withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.image, color: Colors.white54, size: 48),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demo Ape #${listing['tokenId']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$price mUSD',
                    style: const TextStyle(
                      color: Color(0xFF00D18A),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onBuy,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 74, 24, 199),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Buy', style: TextStyle(fontSize: 12)),
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
