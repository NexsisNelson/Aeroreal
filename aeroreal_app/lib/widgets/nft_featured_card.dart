import 'package:flutter/material.dart';
import '../utils/app_icons.dart';
import 'package:provider/provider.dart';

import '../services/contract_service.dart';
import '../utils/nft_image.dart';

// UI/UX: Controls featured NFT card sizing, image/price hierarchy, tap-to-
// detail behavior, watch action, and buy action.
class NftFeaturedCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final VoidCallback onBuy;
  final VoidCallback onWatch;
  final VoidCallback onTap;

  const NftFeaturedCard({
    super.key,
    required this.listing,
    required this.onBuy,
    required this.onWatch,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = context.read<ContractService>().formatToken(
      listing['price'] as BigInt,
    );
    final seller = listing['seller'] as String;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1625),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(
                255,
                74,
                24,
                199,
              ).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'FEATURED',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onWatch,
                  icon: const AppIcon(
                    AppIcons.favoriteBorder,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                NftImage.forToken(
                  tokenId: listing['tokenId'] as BigInt,
                  collectionSymbol: 'demo-ape',
                ),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 220,
                    color: const Color(0xFF1A1625),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, _, _) => Container(
                  height: 220,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF836EF9), Color(0xFF5C4BC7)],
                    ),
                  ),
                  child: const Icon(
                    Icons.image,
                    color: Colors.white30,
                    size: 80,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Demo Ape #${listing['tokenId']}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Listed by ${seller.length > 10 ? seller.substring(0, 10) : seller}...',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '$price AREAL',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onBuy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color.fromARGB(255, 74, 24, 199),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Buy Now',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
