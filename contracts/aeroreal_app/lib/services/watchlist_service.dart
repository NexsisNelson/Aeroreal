import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'user_profile_service.dart';

class WatchlistService {
  Future<List<Map<String, dynamic>>> getWatchlist(BuildContext context) async {
    final profile = context.read<UserProfileService>();
    return profile.watchlist
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
  }

  Future<bool> isWatched(BuildContext context, String assetId) async {
    final profile = context.read<UserProfileService>();
    final assets = profile.watchlist
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    return assets.any((asset) => asset['id'] == assetId);
  }

  Future<void> addToWatchlist(
    BuildContext context,
    Map<String, dynamic> asset,
  ) async {
    final profile = context.read<UserProfileService>();
    final id = asset['id'] as String?;
    if (id == null || id.isEmpty || await isWatched(context, id)) return;
    final assets = profile.watchlist
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    assets.add({
      'id': id,
      'rwa_slug': asset['rwa_slug'] ?? id,
      'name': asset['name'],
      'symbol': asset['symbol'],
      'image': asset['image'],
      'price_usd': asset['price_usd'],
      'percent_change_24h': asset['percent_change_24h'],
      'asset_type': asset['asset_type'],
      'added_at': DateTime.now().toIso8601String(),
    });
    await profile.update(watchlist: assets);
  }

  Future<void> removeFromWatchlist(BuildContext context, String assetId) async {
    final profile = context.read<UserProfileService>();
    final assets = profile.watchlist
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    assets.removeWhere((asset) => asset['id'] == assetId);
    await profile.update(watchlist: assets);
  }

  Future<void> toggleWatchlist(
    BuildContext context,
    Map<String, dynamic> asset,
  ) async {
    final profile = context.read<UserProfileService>();
    final id = asset['id'] as String?;
    if (id == null) return;
    if (await isWatched(context, id)) {
      final assets =
          profile.watchlist
              .map((value) => Map<String, dynamic>.from(value as Map))
              .toList()
            ..removeWhere((item) => item['id'] == id);
      await profile.update(watchlist: assets);
    } else {
      final assets = profile.watchlist
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
      assets.add(asset);
      await profile.update(watchlist: assets);
    }
  }
}
