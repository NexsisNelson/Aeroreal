import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NewsItem {
  final String id;
  final String title;
  final String description;
  final String url;
  final String? thumbnail;
  final String source;
  final DateTime? publishedAt;

  NewsItem({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.source,
    this.thumbnail,
    this.publishedAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
    thumbnail: json['thumbnail']?.toString(),
    source: json['source']?.toString() ?? 'Unknown',
    publishedAt: json['published_at'] == null
        ? null
        : DateTime.tryParse(json['published_at'].toString()),
  );

  String get relativeTime {
    if (publishedAt == null) return '';
    final difference = DateTime.now().difference(publishedAt!);
    if (difference.isNegative || difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

class NewsService {
  static String get baseUrl => defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3001'
      : 'http://localhost:3001';

  Future<List<NewsItem>> getRwaNews() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/news/rwa'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return [];
      final body = jsonDecode(response.body) as Map;
      final items = body['items'] as List? ?? const [];
      return items
          .whereType<Map>()
          .map((item) => NewsItem.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.title.isNotEmpty && item.url.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
