// Flutter source file: contracts/aeroreal_app/lib/config/simulated_nft_collections.dart
// This file contains the app logic, UI, or domain behavior for the Aeroreal experience.
// 
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
