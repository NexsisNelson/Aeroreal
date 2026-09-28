import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'user_profile_service.dart';

class TransactionRecord {
  final String hash;
  final String action;
  final String details;
  final DateTime timestamp;

  const TransactionRecord({
    required this.hash,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'action': action,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };

  static TransactionRecord fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      hash: json['hash'] as String,
      action: json['action'] as String,
      details: json['details'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class TxHistoryService {
  Future<void> log(
    BuildContext context, {
    required String hash,
    required String action,
    required String details,
  }) async {
    final profile = context.read<UserProfileService>();
    final records = profile.txHistory
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    records.insert(
      0,
      TransactionRecord(
        hash: hash,
        action: action,
        details: details,
        timestamp: DateTime.now(),
      ).toJson(),
    );
    await profile.update(txHistory: records.take(100).toList());
  }

  Future<List<TransactionRecord>> getAll(BuildContext context) async {
    final profile = context.read<UserProfileService>();
    return profile.txHistory
        .map(
          (value) => TransactionRecord.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList();
  }

  Future<void> clear(BuildContext context) async {
    await context.read<UserProfileService>().update(txHistory: []);
  }
}
