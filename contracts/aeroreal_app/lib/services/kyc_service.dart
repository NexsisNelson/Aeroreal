import 'package:shared_preferences/shared_preferences.dart';

/// Stores mock identity verification locally for the demo flow.
/// A production integration would replace this with a regulated KYC provider
/// and an authorized compliance service that updates the on-chain whitelist.
class KycService {
  static const String _keyPrefix = 'kyc_verified_';

  Future<bool> isVerified(String walletAddress) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyPrefix$walletAddress') ?? false;
  }

  Future<void> markVerified({
    required String walletAddress,
    required String fullName,
    required String country,
    required String idType,
    required String idNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$walletAddress', true);
    await prefs.setString('$_keyPrefix${walletAddress}_name', fullName);
    await prefs.setString('$_keyPrefix${walletAddress}_country', country);
    await prefs.setString('$_keyPrefix${walletAddress}_id_type', idType);
    await prefs.setString('$_keyPrefix${walletAddress}_id_number', idNumber);
    await prefs.setString(
      '$_keyPrefix${walletAddress}_verified_at',
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> clearVerification(String walletAddress) async {
    final prefs = await SharedPreferences.getInstance();
    for (final suffix in [
      '',
      '_name',
      '_country',
      '_id_type',
      '_id_number',
      '_verified_at',
    ]) {
      await prefs.remove('$_keyPrefix$walletAddress$suffix');
    }
  }

  Future<Map<String, String?>?> getDetails(String walletAddress) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await isVerified(walletAddress)) return null;
    return {
      'name': prefs.getString('$_keyPrefix${walletAddress}_name'),
      'country': prefs.getString('$_keyPrefix${walletAddress}_country'),
      'idType': prefs.getString('$_keyPrefix${walletAddress}_id_type'),
      'idNumber': prefs.getString('$_keyPrefix${walletAddress}_id_number'),
      'verifiedAt': prefs.getString('$_keyPrefix${walletAddress}_verified_at'),
    };
  }
}
