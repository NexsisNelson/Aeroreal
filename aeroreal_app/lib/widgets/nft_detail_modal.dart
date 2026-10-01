import 'package:flutter/material.dart';
import '../utils/app_icons.dart';
import 'package:provider/provider.dart';

import '../services/contract_service.dart';
import '../utils/nft_image.dart';

// UI/UX: Controls the NFT detail bottom sheet, image/price hierarchy, Buy
// action, seller details, and offer-action presentation.
class NftDetailModal extends StatelessWidget {
  final Map<String, dynamic> listing;
  final VoidCallback onBuy;

  const NftDetailModal({super.key, required this.listing, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final price = context.read<ContractService>().formatToken(
      listing['price'] as BigInt,
    );
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1625),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: Image.network(
                NftImage.forToken(
                  tokenId: listing['tokenId'] as BigInt,
                  collectionSymbol: 'demo-ape',
                ),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFF1A1625),
                  child: Center(
                    child: AppIcon(
                      AppIcons.image,
                      color: Colors.white54,
                      size: 80,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Demo Ape #${listing['tokenId']}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Listed by ${listing['seller']}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Price',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    Text(
                      '$price AREAL',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00D18A),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onBuy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 74, 24, 199),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'Buy Now',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const AppIcon(AppIcons.localOfferOutlined, size: 16),
            label: const Text('Make an Offer'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
      ),
    );
  }
}
