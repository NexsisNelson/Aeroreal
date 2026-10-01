import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'user_profile_service.dart';

class YieldSnapshot {
  final DateTime timestamp;
  final double amount;

  YieldSnapshot({required this.timestamp, required this.amount});

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'amount': amount,
  };

  static YieldSnapshot fromJson(Map<String, dynamic> json) => YieldSnapshot(
    timestamp: DateTime.parse(json['timestamp'] as String),
    amount: (json['amount'] as num).toDouble(),
  );
}

class YieldHistoryService {
  Future<void> recordSnapshot(
    BuildContext context, {
    required String streamerId,
    required double amount,
  }) async {
    final profile = context.read<UserProfileService>();
    final allHistory = _readHistory(profile.profile['yieldHistory']);
    final list = _readSnapshots(allHistory[streamerId]);

    if (list.isNotEmpty) {
      final last = YieldSnapshot.fromJson(list.last);
      if (DateTime.now().difference(last.timestamp).inHours < 1) return;
    }

    list.add(YieldSnapshot(timestamp: DateTime.now(), amount: amount).toJson());
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    allHistory[streamerId] = list.where((entry) {
      return DateTime.parse(entry['timestamp'] as String).isAfter(cutoff);
    }).toList();
    await profile.updateCustom({'yieldHistory': allHistory});
  }

  Future<List<YieldSnapshot>> getHistory(
    BuildContext context,
    String streamerId,
  ) async {
    final profile = context.read<UserProfileService>();
    final allHistory = _readHistory(profile.profile['yieldHistory']);
    return _readSnapshots(
      allHistory[streamerId],
    ).map(YieldSnapshot.fromJson).toList();
  }

  Map<String, double> calculateChange(
    List<YieldSnapshot> history, {
    required Duration window,
  }) {
    if (history.length < 2) return {'delta': 0, 'percent': 0};
    final cutoff = DateTime.now().subtract(window);
    final inWindow = history.where((snapshot) {
      return snapshot.timestamp.isAfter(cutoff);
    }).toList();
    if (inWindow.length < 2) return {'delta': 0, 'percent': 0};

    final first = inWindow.first.amount;
    final last = inWindow.last.amount;
    final delta = last - first;
    return {'delta': delta, 'percent': first > 0 ? (delta / first) * 100 : 0};
  }

  Map<String, dynamic> _readHistory(dynamic value) {
    if (value is! Map) return {};
    return Map<String, dynamic>.from(value);
  }

  List<Map<String, dynamic>> _readSnapshots(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }
}
