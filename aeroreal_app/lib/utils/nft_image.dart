/// Resolves deterministic artwork for NFT cards when metadata is unavailable.
class NftImage {
  static String forToken({
    required BigInt tokenId,
    String? collectionSymbol,
    String? metadataImageUrl,
  }) {
    if (metadataImageUrl != null && metadataImageUrl.isNotEmpty) {
      return metadataImageUrl;
    }
    final seed = '${collectionSymbol ?? 'nft'}-${tokenId.toString()}';
    return 'https://api.dicebear.com/7.x/shapes/svg?seed=$seed&size=400';
  }

  static String forCollection(String collectionId) {
    return 'https://api.dicebear.com/7.x/shapes/svg?seed=$collectionId&size=400';
  }
}
