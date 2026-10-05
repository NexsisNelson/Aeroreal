import 'constants.dart';

class CommunityCollection {
  final String name;
  final String symbol;
  final String address;
  final int totalMinted;
  final double floorPriceAreal;

  const CommunityCollection({
    required this.name,
    required this.symbol,
    required this.address,
    required this.totalMinted,
    required this.floorPriceAreal,
  });
}

class CommunityNfts {
  static const List<CommunityCollection> collections = [
    CommunityCollection(
      name: 'Monad Apes',
      symbol: 'MAPE',
      address: AppConstants.monadApes,
      totalMinted: 10,
      floorPriceAreal: 500,
    ),
    CommunityCollection(
      name: 'Monad Punks',
      symbol: 'MPUNK',
      address: AppConstants.monadPunks,
      totalMinted: 10,
      floorPriceAreal: 350,
    ),
    CommunityCollection(
      name: 'Monad Frogs',
      symbol: 'MFROG',
      address: AppConstants.monadFrogs,
      totalMinted: 10,
      floorPriceAreal: 200,
    ),
  ];
}
