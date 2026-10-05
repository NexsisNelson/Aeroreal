import 'dart:convert';

import 'package:http/http.dart' as http;

import 'user_profile_service.dart';

class BlockVisionCollection {
  const BlockVisionCollection({
    required this.contractAddress,
    required this.name,
    required this.verified,
    required this.ercStandard,
    required this.itemCount,
    required this.items,
    this.image,
  });

  final String contractAddress;
  final String name;
  final String? image;
  final bool verified;
  final String ercStandard;
  final int itemCount;
  final List<BlockVisionItem> items;

  factory BlockVisionCollection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return BlockVisionCollection(
      contractAddress: json['contractAddress']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Collection',
      image: json['image']?.toString(),
      verified: json['verified'] == true,
      ercStandard: json['ercStandard']?.toString() ?? 'ERC721',
      itemCount: json['itemCount'] is num
          ? (json['itemCount'] as num).toInt()
          : 0,
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      BlockVisionItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

class BlockVisionItem {
  const BlockVisionItem({
    required this.name,
    required this.tokenId,
    required this.qty,
    this.image,
  });

  final String name;
  final String tokenId;
  final String? image;
  final String qty;

  factory BlockVisionItem.fromJson(Map<String, dynamic> json) =>
      BlockVisionItem(
        name: json['name']?.toString() ?? 'Unnamed',
        tokenId: json['tokenId']?.toString() ?? '',
        image: json['image']?.toString(),
        qty: json['qty']?.toString() ?? '1',
      );
}

class BlockVisionService {
  Future<List<BlockVisionCollection>> getWalletNfts(
    String walletAddress,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${UserProfileService.baseUrl}/api/blockvision/nfts/$walletAddress',
            ),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return [];
      final collections = body['collections'];
      if (collections is! List) return [];
      return collections
          .whereType<Map>()
          .map(
            (collection) => BlockVisionCollection.fromJson(
              Map<String, dynamic>.from(collection),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }
}
