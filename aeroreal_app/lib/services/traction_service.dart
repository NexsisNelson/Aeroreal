import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'user_profile_service.dart';

enum TractionAction {
  mintNft,
  fractionalizeNft,
  tokenizeRwa,
  listNft,
  buyNft,
  stakeFractions,
  claimYield,
  depositRevenue,
  addToWhitelist,
  kycVerified,
}

class TractionEntry {
  final String hash;
  final TractionAction action;
  final String description;
  final DateTime timestamp;

  TractionEntry({
    required this.hash,
    required this.action,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'action': action.name,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
  };

  static TractionEntry fromJson(Map<String, dynamic> json) => TractionEntry(
    hash: json['hash'] as String,
    action: TractionAction.values.firstWhere(
      (action) => action.name == json['action'],
      orElse: () => TractionAction.stakeFractions,
    ),
    description: json['description'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

class TractionService {
  Future<void> log(
    BuildContext context, {
    required String hash,
    required TractionAction action,
    required String description,
  }) async {
    final profile = context.read<UserProfileService>();
    final entries = profile.tractionLog
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    final entry = TractionEntry(
      hash: hash,
      action: action,
      description: description,
      timestamp: DateTime.now(),
    );
    entries.insert(0, entry.toJson());
    await profile.update(tractionLog: entries.take(200).toList());
  }

  Future<List<TractionEntry>> getAll(BuildContext context) async {
    final profile = context.read<UserProfileService>();
    return profile.tractionLog
        .map(
          (value) =>
              TractionEntry.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
  }

  Future<Map<TractionAction, int>> getCountsByAction(
    BuildContext context,
  ) async {
    final all = await getAll(context);
    final counts = <TractionAction, int>{};
    for (final entry in all) {
      counts[entry.action] = (counts[entry.action] ?? 0) + 1;
    }
    return counts;
  }

  Future<int> getTotalCount(BuildContext context) async =>
      (await getAll(context)).length;

  Future<void> clear(BuildContext context) async {
    await context.read<UserProfileService>().update(tractionLog: []);
  }
}
