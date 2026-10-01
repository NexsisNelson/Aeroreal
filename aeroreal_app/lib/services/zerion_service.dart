import 'dart:convert';

import 'package:http/http.dart' as http;

import 'user_profile_service.dart';

class ZerionNft {
  const ZerionNft({
    required this.id,
    required this.name,
    required this.collectionName,
    required this.collectionSymbol,
    required this.contractAddress,
    required this.tokenId,
    this.image,
    this.floorPriceUsd,
  });

  final String id;
  final String name;
  final String collectionName;
  final String collectionSymbol;
  final String contractAddress;
  final String tokenId;
  final String? image;
  final double? floorPriceUsd;

  factory ZerionNft.fromJson(Map<String, dynamic> json) {
    final floorPrice = json['floorPriceUsd'];
    return ZerionNft(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed NFT',
      collectionName:
          json['collectionName']?.toString() ?? 'Unknown Collection',
      collectionSymbol: json['collectionSymbol']?.toString() ?? '',
      contractAddress: json['contractAddress']?.toString() ?? '',
      tokenId: json['tokenId']?.toString() ?? '',
      image: json['image']?.toString(),
      floorPriceUsd: floorPrice is num
          ? floorPrice.toDouble()
          : double.tryParse(floorPrice?.toString() ?? ''),
    );
  }
}

class ZerionService {
  Future<List<ZerionNft>> getWalletNfts(String walletAddress) async {
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(seconds: 15));
        }
        final response = await http
            .get(
              Uri.parse(
                '${UserProfileService.baseUrl}/api/zerion/nfts/$walletAddress',
              ),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 202 && attempt == 0) continue;
        if (response.statusCode != 200) return [];

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final nfts = body['nfts'];
        if (nfts is! List) return [];
        return nfts
            .whereType<Map>()
            .map((item) => ZerionNft.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
