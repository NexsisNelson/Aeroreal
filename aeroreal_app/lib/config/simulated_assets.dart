import 'constants.dart';

/// Maps underlying asset symbols to their simulated token contracts.
class SimulatedAssets {
  static const Map<String, String> _bySymbol = {
    'BTC': AppConstants.simulatedBtc,
    'ETH': AppConstants.simulatedEth,
    'XAU': AppConstants.simulatedGold,
    'COFFEE': AppConstants.simulatedCoffee,
    'SOL': AppConstants.simulatedSol,
  };

  static const Map<String, String> _aliases = {
    'PAXG': 'XAU',
    'XAUT': 'XAU',
    'XGLD': 'XAU',
    'CCF': 'COFFEE',
  };

  static String canonicalSymbolFor(String symbol) {
    final normalized = symbol.toUpperCase();
    return _aliases[normalized] ?? normalized;
  }

  static String? contractFor(String symbol) =>
      _bySymbol[canonicalSymbolFor(symbol)];

  static bool hasSimulated(String symbol) =>
      _bySymbol.containsKey(canonicalSymbolFor(symbol));

  static String tokenSymbolFor(String symbol) {
    final normalized = canonicalSymbolFor(symbol);
    if (normalized == 'XAU') return 'sGOLD';
    return 's$normalized';
  }

  static List<String> get supportedSymbols => _bySymbol.keys.toList();
}
