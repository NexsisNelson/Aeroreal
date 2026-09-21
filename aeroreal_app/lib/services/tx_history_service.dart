import 'package:shared_preferences/shared_preferences.dart';

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
  static const _key = 'tx_history';

  Future<void> log({
    required String hash,
    required String action,
    required String details,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await getAll();
    records.insert(
      0,
      TransactionRecord(
        hash: hash,
        action: action,
        details: details,
        timestamp: DateTime.now(),
      ),
    );
    await prefs.setStringList(
      _key,
      records.map((record) => jsonEncode(record.toJson())).toList(),
    );
  }

  Future<List<TransactionRecord>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    return raw
        .map(
          (value) => TransactionRecord.fromJson(
            jsonDecode(value) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
