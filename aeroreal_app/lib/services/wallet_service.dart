// lib/services/wallet_service.dart

import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';
import 'package:flutter/foundation.dart';

import '../config/constants.dart';

/// WalletService handles generating, storing, loading, and signing with a wallet.
/// It also provides a Web3Client connected to Monad Testnet.
class WalletService extends ChangeNotifier {
  static const String _privateKeyStorageKey = 'aeroreal_private_key';

  late final Web3Client _client;
  EthPrivateKey? _credentials;

  WalletService() {
    _client = Web3Client(AppConstants.monadRpcUrl, http.Client());
  }

  /// Expose the client so other services can use it.
  Web3Client get client => _client;

  /// Expose the current credentials (or null if none loaded).
  EthPrivateKey? get credentials => _credentials;

  /// Expose the current wallet address (or null if none loaded).
  EthereumAddress? get address => _credentials?.address;

  /// True if a wallet is currently loaded.
  bool get hasWallet => _credentials != null;

  /// Generate a brand-new random wallet and save it.
  Future<EthereumAddress> generateWallet() async {
    final credentials = EthPrivateKey.createRandom(Random.secure());
    await _saveCredentials(credentials);
    _credentials = credentials;
    notifyListeners();
    return credentials.address;
  }

  /// Import a wallet from a hex private key (with or without 0x prefix).
  Future<EthereumAddress> importWallet(String privateKeyHex) async {
    final cleaned = privateKeyHex.startsWith('0x')
        ? privateKeyHex.substring(2)
        : privateKeyHex;

    final credentials = EthPrivateKey.fromHex(cleaned);
    await _saveCredentials(credentials);
    _credentials = credentials;
    notifyListeners();
    return credentials.address;
  }

  /// Load a wallet from device storage (call this on app startup).
  Future<bool> loadWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_privateKeyStorageKey);

    if (stored == null || stored.isEmpty) {
      return false;
    }

    try {
      _credentials = EthPrivateKey.fromHex(stored);
      notifyListeners();
      return true;
    } catch (_) {
      // Corrupted key. Remove and return false.
      await prefs.remove(_privateKeyStorageKey);
      return false;
    }
  }

  /// Remove the wallet from device storage.
  Future<void> deleteWallet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_privateKeyStorageKey);
    _credentials = null;
    notifyListeners();
  }

  /// Export the private key (for backup).
  String? exportPrivateKey() {
    if (_credentials == null) return null;
    return _credentials!.privateKey
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Get the native MON balance for the current wallet.
  Future<BigInt> getMonBalance({String? ownerAddress}) async {
    final balanceOwner = ownerAddress == null
        ? _credentials?.address
        : EthereumAddress.fromHex(ownerAddress);
    if (balanceOwner == null) return BigInt.zero;
    final balance = await _client.getBalance(balanceOwner);
    return balance.getValueInUnitBI(EtherUnit.wei);
  }

  /// Internal - save credentials to device.
  Future<void> _saveCredentials(EthPrivateKey credentials) async {
    final prefs = await SharedPreferences.getInstance();
    final hex = credentials.privateKey
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    await prefs.setString(_privateKeyStorageKey, hex);
  }
}
