import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:privy_flutter/privy_flutter.dart';

class PrivyService {
  PrivyService({this.appId, this.clientId});

  final String? appId;
  final String? clientId;

  Privy? _privy;
  PrivyUser? _user;
  bool _ready = false;

  Privy? get privy => _privy;
  PrivyUser? get user => _user;
  bool get isReady => _ready;
  bool get isAuthenticated => _user != null;

  Future<void> initialize() async {
    final resolvedAppId = appId ?? dotenv.env['PRIVY_APP_ID'] ?? '';
    final resolvedClientId = clientId ?? dotenv.env['PRIVY_CLIENT_ID'] ?? '';

    if (resolvedAppId.isEmpty || resolvedClientId.isEmpty) {
      debugPrint(
        'PrivyService skipped: PRIVY_APP_ID or PRIVY_CLIENT_ID is missing.',
      );
      return;
    }

    final config = PrivyConfig(
      appId: resolvedAppId,
      appClientId: resolvedClientId,
      logLevel: PrivyLogLevel.verbose,
    );

    try {
      _privy = Privy.init(config: config);
      await _privy!.getAuthState();
      _ready = true;

      try {
        _user = await _privy!.getUser();
        if (_user != null) {
          await ensureEmbeddedWallet();
        }
      } on PrivyException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('user is not authenticated') ||
            msg.contains('user_not_found') ||
            msg.contains('not authenticated')) {
          _user = null;
          debugPrint('PrivyService: no authenticated user yet.');
        } else {
          debugPrint('Privy getUser error: ${e.message}');
        }
      } on Exception catch (e) {
        _user = null;
        debugPrint('Privy getUser error: $e');
      }
    } catch (e) {
      debugPrint('PrivyService initialize failed: $e');
      _ready = false;
      _user = null;
    }
  }

  String? get walletAddress {
    final wallets = _user?.embeddedEthereumWallets;
    if (wallets == null || wallets.isEmpty) return null;
    return wallets.first.address;
  }

  EmbeddedEthereumWallet? get ethereumWallet {
    final wallets = _user?.embeddedEthereumWallets;
    if (wallets == null || wallets.isEmpty) return null;
    return wallets.first;
  }

  Future<void> loadUser() async {
    if (_privy == null) return;

    try {
      _user = await _privy!.getUser();
      if (_user != null) {
        await ensureEmbeddedWallet();
      }
    } on PrivyException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('user is not authenticated') ||
          msg.contains('user_not_found') ||
          msg.contains('not authenticated')) {
        _user = null;
        debugPrint('PrivyService: no authenticated user loaded.');
      } else {
        debugPrint('Privy loadUser error: ${e.message}');
      }
    } on Exception catch (e) {
      _user = null;
      debugPrint('Privy loadUser error: $e');
    }
  }

  Future<void> ensureEmbeddedWallet() async {
    if (_user == null) return;

    if (_user!.embeddedEthereumWallets.isEmpty) {
      final result = await _user!.createEthereumWallet();
      switch (result) {
        case Success<EmbeddedEthereumWallet>(:final value):
          debugPrint('Privy embedded wallet created: ${value.address}');
        case Failure<EmbeddedEthereumWallet>(:final error):
          debugPrint('Privy wallet creation failed: ${error.message}');
      }
    }
  }

  Future<bool> sendSmsCode(String phoneNumber) async {
    if (_privy == null) return false;
    final result = await _privy!.sms.sendCode(phoneNumber);

    return switch (result) {
      Success<void>() => true,
      Failure<void>() => false,
    };
  }

  Future<bool> loginWithSmsCode({
    required String code,
    required String phoneNumber,
  }) async {
    if (_privy == null) return false;

    final result = await _privy!.sms.loginWithCode(
      code: code,
      phoneNumber: phoneNumber,
    );

    switch (result) {
      case Success<PrivyUser>(:final value):
        _user = value;
        await ensureEmbeddedWallet();
        return true;
      case Failure<PrivyUser>(:final error):
        debugPrint('Privy SMS login failed: ${error.message}');
        return false;
    }
  }

  Future<bool> sendEmailCode(String email) async {
    if (_privy == null) return false;
    final result = await _privy!.email.sendCode(email);

    return switch (result) {
      Success<void>() => true,
      Failure<void>() => false,
    };
  }

  Future<bool> loginWithEmailCode({
    required String code,
    required String email,
  }) async {
    if (_privy == null) return false;

    final result = await _privy!.email.loginWithCode(code: code, email: email);

    switch (result) {
      case Success<PrivyUser>(:final value):
        _user = value;
        await ensureEmbeddedWallet();
        return true;
      case Failure<PrivyUser>(:final error):
        debugPrint('Privy email login failed: ${error.message}');
        return false;
    }
  }

  Future<void> logout() async {
    if (_privy == null) return;
    await _privy!.logout();
    _user = null;
  }

  Future<String?> signAndSendTransaction({
    required String to,
    required String data,
    required String value,
  }) async {
    final wallet = ethereumWallet;
    if (wallet == null) {
      // ignore: avoid_print
      print('Privy: No embedded wallet found');
      return null;
    }

    final transaction = jsonEncode({
      'from': wallet.address,
      'to': to,
      'data': data,
      'value': value,
    });
    final request = EthereumRpcRequest.ethSendTransaction(transaction);

    // ignore: avoid_print
    print('Privy: Sending tx to $to');
    // ignore: avoid_print
    print(
      'Privy: Data: ${data.substring(0, data.length > 40 ? 40 : data.length)}...',
    );

    final result = await wallet.provider.request(request);

    switch (result) {
      case Success<EthereumRpcResponse>(:final value):
        // ignore: avoid_print
        print('Privy: Success! Hash: ${value.data}');
        return value.data;
      case Failure<EthereumRpcResponse>(:final error):
        // ignore: avoid_print
        print('Privy: FAILED - $error');
        debugPrint('Privy eth_sendTransaction failed: ${error.message}');
        return null;
    }
  }

  Future<String?> signAndSendRawTransaction({
    required String transactionJson,
  }) async {
    final wallet = ethereumWallet;
    if (wallet == null) return null;

    final request = EthereumRpcRequest.ethSendTransaction(transactionJson);
    final result = await wallet.provider.request(request);

    switch (result) {
      case Success<EthereumRpcResponse>(:final value):
        return value.data;
      case Failure<EthereumRpcResponse>(:final error):
        debugPrint('Privy eth_sendTransaction failed: ${error.message}');
        return null;
    }
  }
}
