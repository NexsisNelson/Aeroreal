import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class IssuerReputation {
  final String issuer;
  final int score;
  final String tier;
  final int assetsTokenized;
  final int? onTimeSettlement;
  final int auditsPassed;
  final Map<String, dynamic> breakdown;

  IssuerReputation({
    required this.issuer,
    required this.score,
    required this.tier,
    required this.assetsTokenized,
    required this.auditsPassed,
    this.onTimeSettlement,
    this.breakdown = const {},
  });

  factory IssuerReputation.fromJson(Map<String, dynamic> json) {
    return IssuerReputation(
      issuer: json['issuer']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      tier: json['tier']?.toString() ?? 'C',
      assetsTokenized: (json['assets_tokenized'] as num?)?.toInt() ?? 0,
      onTimeSettlement: (json['on_time_settlement'] as num?)?.toInt(),
      auditsPassed: (json['audits_passed'] as num?)?.toInt() ?? 0,
      breakdown: Map<String, dynamic>.from(json['breakdown'] as Map? ?? {}),
    );
  }
}

class ReputationService {
  static String get baseUrl => defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3001'
      : 'http://localhost:3001';

  Future<IssuerReputation?> getReputation(String issuerAddress) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/api/issuer/${Uri.encodeComponent(issuerAddress)}/reputation',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return IssuerReputation.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    } catch (_) {
      return null;
    }
  }
}
