import 'package:flutter_test/flutter_test.dart';
import 'package:aeroreal_app/utils/nft_image.dart';

void main() {
  test('forToken uses shapes style and deterministic token output', () {
    final tokenUrl = NftImage.forToken(
      tokenId: BigInt.from(42),
      collectionSymbol: 'demo-ape',
    );

    expect(tokenUrl, contains('api.dicebear.com/7.x/shapes/svg'));
    expect(tokenUrl, contains('seed=demo-ape-42'));
    expect(tokenUrl, contains('size=400'));
  });

  test('forCollection uses a stable shapes collection seed', () {
    final collectionUrl = NftImage.forCollection('MAPE');

    expect(collectionUrl, contains('api.dicebear.com/7.x/shapes/svg'));
    expect(collectionUrl, contains('seed=MAPE'));
    expect(collectionUrl, contains('size=400'));
  });
}
