// lib/config/env.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads configuration from the .env file.
/// Falls back to hardcoded values if .env isn't loaded.
class AppEnv {
  static String get monadRpcUrl =>
      dotenv.env['MONAD_RPC_URL'] ?? 'https://testnet-rpc.monad.xyz';

  static String get sprinkleToken => dotenv.env['SPRINKLE_TOKEN'] ?? '';

  static String get fractionFactory => dotenv.env['FRACTION_FACTORY'] ?? '';

  static String get demoNft => dotenv.env['DEMO_NFT'] ?? '';

  static String get vault => dotenv.env['VAULT'] ?? '';

  static String get fractionToken => dotenv.env['FRACTION_TOKEN'] ?? '';

  static String get streamer => dotenv.env['STREAMER'] ?? '';
}
