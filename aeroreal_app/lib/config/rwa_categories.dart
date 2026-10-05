class RwaCategory {
  final String id;
  final String label;
  final String coingeckoCategoryId;
  final String emoji;

  const RwaCategory({
    required this.id,
    required this.label,
    required this.coingeckoCategoryId,
    required this.emoji,
  });
}

class RwaCategories {
  static const List<RwaCategory> all = [
    RwaCategory(
      id: 'treasuries',
      label: 'Treasuries',
      coingeckoCategoryId: 'tokenized-treasuries',
      emoji: '\u{1F3E6}',
    ),
    RwaCategory(
      id: 'commodities',
      label: 'Commodities',
      coingeckoCategoryId: 'tokenized-commodities',
      emoji: '\u{1F947}',
    ),
    RwaCategory(
      id: 'real_estate',
      label: 'Real Estate',
      coingeckoCategoryId: 'real-estate',
      emoji: '\u{1F3E0}',
    ),
    RwaCategory(
      id: 'private_credit',
      label: 'Private Credit',
      coingeckoCategoryId: 'tokenized-private-credit',
      emoji: '\u{1F4B3}',
    ),
    RwaCategory(
      id: 'collectibles',
      label: 'Collectibles',
      coingeckoCategoryId: 'collectibles',
      emoji: '\u{1F3A8}',
    ),
    RwaCategory(
      id: 'equities',
      label: 'Equities & ETFs',
      coingeckoCategoryId: 'tokenized-stock',
      emoji: '\u{1F4C8}',
    ),
    RwaCategory(
      id: 'all',
      label: 'All RWA',
      coingeckoCategoryId: 'real-world-assets-rwa',
      emoji: '\u{1F30D}',
    ),
  ];
}
