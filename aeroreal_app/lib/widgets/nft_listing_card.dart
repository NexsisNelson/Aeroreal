import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/contract_service.dart';
import '../utils/nft_image.dart';

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
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  NftImage.forToken(
                    tokenId: listing['tokenId'] as BigInt,
                    collectionSymbol: 'demo-ape',
                  ),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: const Color(0xFF1A1625),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF836EF9), Color(0xFF5C4BC7)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.image, color: Colors.white30),
                    ),
                  ),
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
                    '$price AREAL',
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
