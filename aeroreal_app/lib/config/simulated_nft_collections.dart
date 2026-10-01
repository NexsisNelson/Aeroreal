import 'constants.dart';

class SimulatedNftCollections {
  static const Map<String, String> _contracts = {
    'sbayc': AppConstants.simulatedBayc,
    'spunk': AppConstants.simulatedPunks,
    'sdoodle': AppConstants.simulatedDoodles,
  };

  static String symbolFor(String collectionName, String collectionSymbol) {
    final search = '$collectionName $collectionSymbol'.toLowerCase();
    if (search.contains('punk')) return 'sPUNK';
    if (search.contains('doodle')) return 'sDOODLE';
    return 'sBAYC';
  }

  static String contractFor(String symbol) =>
      _contracts[symbol.toLowerCase()] ?? AppConstants.simulatedBayc;
}
