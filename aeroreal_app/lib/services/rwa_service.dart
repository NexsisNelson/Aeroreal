import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RwaService {
  static const _androidBaseUrl = 'http://10.0.2.2:3001';
  static const _desktopBaseUrl = 'http://localhost:3001';

  String get baseUrl => defaultTargetPlatform == TargetPlatform.android
      ? _androidBaseUrl
      : _desktopBaseUrl;

  Future<List<Map<String, dynamic>>> searchAssets({
    String? query,
    String? type,
  }) async {
    final params = <String, String>{};
    if (query != null && query.isNotEmpty) params['search'] = query;
    if (type != null && type.isNotEmpty) params['type'] = type;
    final uri = Uri.parse('$baseUrl/api/rwa/search').replace(
      queryParameters: {if (params['search'] != null) 'q': params['search']!},
    );
    final body = await _get(uri);
    return List<Map<String, dynamic>>.from(body['assets'] ?? const []);
  }

  Future<Map<String, dynamic>> getQuote(String slug) {
    return _get(
      Uri.parse('$baseUrl/api/rwa/asset/${Uri.encodeComponent(slug)}'),
    );
  }

  Future<List<Map<String, dynamic>>> getChart(
    String symbol, {
    String period = 'daily',
    int count = 30,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/rwa/asset/${Uri.encodeComponent(symbol)}/chart',
    ).replace(queryParameters: {'period': period, 'count': '$count'});
    final body = await _get(uri);
    return List<Map<String, dynamic>>.from(body['candles'] ?? const []);
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await http.get(uri);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || decoded['error'] != null) {
      throw Exception(decoded['error'] ?? 'RWA request failed');
    }
    return decoded;
  }
}
