import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService extends ChangeNotifier {
  static String get baseUrl => defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3001'
      : 'http://localhost:3001';
  static const String _cachePrefix = 'profile_';

  String? _walletAddress;
  Map<String, dynamic> _profile = {};

  String? get walletAddress => _walletAddress;
  Map<String, dynamic> get profile => _profile;
  List<dynamic> get watchlist => _profile['watchlist'] as List<dynamic>? ?? [];
  List<dynamic> get txHistory => _profile['txHistory'] as List<dynamic>? ?? [];
  List<dynamic> get tractionLog =>
      _profile['tractionLog'] as List<dynamic>? ?? [];
  List<dynamic> get searchHistory =>
      _profile['searchHistory'] as List<dynamic>? ?? [];
  Map<String, dynamic> get costBasis =>
      _profile['costBasis'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get preferences =>
      _profile['preferences'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get customData => _profile;

  Future<void> load(String walletAddress) async {
    _walletAddress = walletAddress.toLowerCase();
    final cacheKey = '$_cachePrefix$_walletAddress';

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/user/profile/$_walletAddress'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _profile = _decodeProfile(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(_profile));
        notifyListeners();
        return;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null) _profile = _decodeProfile(cached);
    notifyListeners();
  }

  Future<void> update({
    List<dynamic>? watchlist,
    Map<String, dynamic>? costBasis,
    List<dynamic>? txHistory,
    List<dynamic>? tractionLog,
    List<dynamic>? searchHistory,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? customData,
  }) async {
    if (_walletAddress == null) return;
    if (watchlist != null) _profile['watchlist'] = watchlist;
    if (costBasis != null) _profile['costBasis'] = costBasis;
    if (txHistory != null) _profile['txHistory'] = txHistory;
    if (tractionLog != null) _profile['tractionLog'] = tractionLog;
    if (searchHistory != null) _profile['searchHistory'] = searchHistory;
    if (preferences != null) {
      _profile['preferences'] = {...this.preferences, ...preferences};
    }
    if (customData != null) {
      _profile.addAll(customData);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_cachePrefix$_walletAddress', jsonEncode(_profile));
    notifyListeners();

    try {
      await http
          .put(
            Uri.parse('$baseUrl/api/user/profile/$_walletAddress'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(_profile),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> updateCustom(Map<String, dynamic> customData) async {
    await update(customData: customData);
  }

  Future<void> addSearch(String query) async {
    if (_walletAddress == null || query.trim().isEmpty) return;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/user/search/$_walletAddress'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _profile['searchHistory'] =
            (jsonDecode(response.body) as Map)['searchHistory'];
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> clearLocal() async {
    if (_walletAddress == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cachePrefix$_walletAddress');
    _profile = {};
    notifyListeners();
  }

  Map<String, dynamic> _decodeProfile(String body) {
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  }
}
