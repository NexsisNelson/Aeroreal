import 'dart:convert';

import 'package:http/http.dart' as http;

import 'user_profile_service.dart';

class TrendingNftCollection {
  final String id;
  final String name;
  final String symbol;
  final String source;
  final String? image;
  final double floorPriceUsd;
  final double volume24hUsd;
  final double floorPriceChange24h;

  const TrendingNftCollection({
    required this.id,
    required this.name,
    required this.symbol,
    required this.source,
    this.image,
    required this.floorPriceUsd,
    required this.volume24hUsd,
    required this.floorPriceChange24h,
  });

  static TrendingNftCollection fromJson(Map<String, dynamic> json) {
    return TrendingNftCollection(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      symbol: json['symbol']?.toString() ?? '',
      source: json['source']?.toString() ?? 'unknown',
      image: json['image']?.toString(),
      floorPriceUsd: (json['floorPriceUsd'] as num?)?.toDouble() ?? 0,
      volume24hUsd: (json['volume24hUsd'] as num?)?.toDouble() ?? 0,
      floorPriceChange24h:
          (json['floorPriceChange24h'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CoinGeckoNftService {
  Future<List<TrendingNftCollection>> getTrendingCollections({
    int limit = 10,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${UserProfileService.baseUrl}/api/coingecko/nft/trending?limit=$limit',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return const [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['collections'] as List? ?? const [];
      final source = body['source']?.toString() ?? 'unknown';
      return items
          .map(
            (item) => TrendingNftCollection.fromJson({
              ...Map<String, dynamic>.from(item as Map),
              'source': source,
            }),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
