import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_profile_service.dart';

class PortfolioService {
  static const _snapshotsKey = 'portfolio_snapshots';

  Future<void> recordPurchase(
    BuildContext context, {
    required String assetId,
    required String symbol,
    required String name,
    required double amount,
    required double priceUsd,
  }) async {
    final profile = context.read<UserProfileService>();
    final data = Map<String, dynamic>.from(profile.costBasis);
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
    await profile.update(costBasis: data);
  }

  Future<Map<String, dynamic>> getCostBasis(BuildContext context) async {
    final profile = context.read<UserProfileService>();
    final data = Map<String, dynamic>.from(profile.costBasis);
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

  Future<void> clear(BuildContext context) async {
    final profile = context.read<UserProfileService>();
    final prefs = await SharedPreferences.getInstance();
    await profile.update(costBasis: {});
    await prefs.remove(_snapshotsKey);
  }
}
