import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WatchlistService {
  static const _key = 'watchlist_assets';

  Future<List<Map<String, dynamic>>> getWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    return raw
        .map((value) => Map<String, dynamic>.from(jsonDecode(value) as Map))
        .toList();
  }

  Future<bool> isWatched(String assetId) async {
    final assets = await getWatchlist();
    return assets.any((asset) => asset['id'] == assetId);
  }

  Future<void> addToWatchlist(Map<String, dynamic> asset) async {
    final id = asset['id'] as String?;
    if (id == null || id.isEmpty || await isWatched(id)) return;
    final assets = await getWatchlist();
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
    await _save(assets);
  }

  Future<void> removeFromWatchlist(String assetId) async {
    final assets = await getWatchlist();
    assets.removeWhere((asset) => asset['id'] == assetId);
    await _save(assets);
  }

  Future<void> toggleWatchlist(Map<String, dynamic> asset) async {
    final id = asset['id'] as String?;
    if (id == null) return;
    if (await isWatched(id)) {
      await removeFromWatchlist(id);
    } else {
      await addToWatchlist(asset);
    }
  }

  Future<void> _save(List<Map<String, dynamic>> assets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      assets.map((asset) => jsonEncode(asset)).toList(),
    );
  }
}
