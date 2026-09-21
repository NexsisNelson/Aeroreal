import 'package:shared_preferences/shared_preferences.dart';

class PortfolioService {
  static const _costBasisKey = 'portfolio_cost_basis';
  static const _snapshotsKey = 'portfolio_snapshots';

  Future<void> recordPurchase({
    required String assetId,
    required String symbol,
    required String name,
    required double amount,
    required double priceUsd,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = await getCostBasis();
    final entry = Map<String, dynamic>.from(
      data[assetId] as Map? ??
          {
            'symbol': symbol,
            'name': name,
            'total_amount': 0.0,
            'total_cost_usd': 0.0,
            'first_purchase': DateTime.now().toIso8601String(),
          },
    );
    entry['total_amount'] = (entry['total_amount'] as num).toDouble() + amount;
    entry['total_cost_usd'] =
        (entry['total_cost_usd'] as num).toDouble() + amount * priceUsd;
    entry['last_purchase'] = DateTime.now().toIso8601String();
    data[assetId] = entry;
    await prefs.setString(_costBasisKey, jsonEncode(data));
  }

  Future<Map<String, dynamic>> getCostBasis() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_costBasisKey) ?? '{}';
    final decoded = jsonDecode(raw) as Map;
    final data = Map<String, dynamic>.from(decoded);
    for (final entry in data.entries) {
      final value = Map<String, dynamic>.from(entry.value as Map);
      final amount = (value['total_amount'] as num).toDouble();
      final cost = (value['total_cost_usd'] as num).toDouble();
      value['avg_price'] = amount > 0 ? cost / amount : 0.0;
      data[entry.key] = value;
    }
    return data;
  }

  Future<void> recordSnapshot(double valueUsd) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshots = prefs.getStringList(_snapshotsKey) ?? [];
    snapshots.add(
      jsonEncode({
        'value': valueUsd,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
    if (snapshots.length > 30) snapshots.removeAt(0);
    await prefs.setStringList(_snapshotsKey, snapshots);
  }

  Future<List<Map<String, dynamic>>> getSnapshots() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_snapshotsKey) ?? [])
        .map((value) => Map<String, dynamic>.from(jsonDecode(value) as Map))
        .toList();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_costBasisKey);
    await prefs.remove(_snapshotsKey);
  }
}
