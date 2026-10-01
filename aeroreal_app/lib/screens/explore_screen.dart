import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/app_icons.dart';
import 'package:provider/provider.dart';

import '../config/rwa_categories.dart';
import '../services/rwa_service.dart';
import '../services/user_profile_service.dart';
import '../utils/number_formatting.dart';
import '../widgets/error_banner.dart';
import '../widgets/news_feed.dart';
import 'rwa_detail_screen.dart';

// UI/UX: Controls discovery search, category filters, featured assets, list
// layout, refresh behavior, and navigation into an asset detail view.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  final _rwaService = RwaService();
  final PageController _featuredController = PageController(
    viewportFraction: 0.84,
  );
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  int _categoryRequestId = 0;

  String _query = '';
  String _category = 'All';
  String _selectedRwaCategory = 'all';
  List<Map<String, dynamic>> _assets = [];
  List<Map<String, dynamic>> _categoryAssets = [];
  bool _loading = true;
  bool _loadingCategory = true;
  String? _error;
  String? _categoryError;
  int _featuredIndex = 0;

  static const List<String> _categories = [
    'All',
    'Commodities',
    'Invoices',
    'Treasuries',
    'Real Estate',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next == _query) return;
      setState(() => _query = next);
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 350), _loadAssets);
    });
    _loadAssets();
    _loadCategoryAssets(RwaCategories.all.last);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _featuredController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    final requestId = ++_searchRequestId;
    final query = _query;
    setState(() {
      _loading = true;
      _error = null;
    });

    List<Map<String, dynamic>> assets;
    try {
      final data = await _rwaService.searchAssets(
        query: query.isEmpty ? null : query,
      );
      assets = data.map(_normalizeAsset).toList();
    } catch (_) {
      assets = _demoAssets;
    }

    if (!mounted || requestId != _searchRequestId) return;
    setState(() {
      _assets = assets;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _loadCategoryAssets(RwaCategory category) async {
    final requestId = ++_categoryRequestId;
    setState(() {
      _selectedRwaCategory = category.id;
      _loadingCategory = true;
      _categoryError = null;
    });

    try {
      final data = await _rwaService.getCategoryAssets(
        category.coingeckoCategoryId,
      );
      if (!mounted || requestId != _categoryRequestId) return;
      setState(() {
        _categoryAssets = data.map((asset) {
          final normalized = _normalizeAsset(asset);
          normalized['category'] = category.label;
          normalized['color'] = _colorForCategory(category.label);
          normalized['icon'] = _iconForCategory(category.label);
          return normalized;
        }).toList();
        _loadingCategory = false;
      });
    } catch (error) {
      if (!mounted || requestId != _categoryRequestId) return;
      setState(() {
        _categoryAssets = [];
        _categoryError = error.toString().replaceFirst('Exception: ', '');
        _loadingCategory = false;
      });
    }
  }

  Future<void> _refreshExplore() async {
    final selectedCategory = RwaCategories.all.firstWhere(
      (category) => category.id == _selectedRwaCategory,
    );
    await Future.wait([_loadAssets(), _loadCategoryAssets(selectedCategory)]);
  }

  static final List<Map<String, dynamic>> _demoAssets = [
    {
      'id': 'unitas-gold',
      'rwa_slug': 'unitas-gold',
      'name': 'Unitas Gold',
      'symbol': 'XGLD',
      'asset_type': 'tokenized_asset',
      'price_usd': 4398.58,
      'percent_change_24h': 1.2,
      'category': 'Commodities',
      'price_text': '\$4,398.58',
      'change_text': '↑ 1.2%',
      'icon': AppIcons.workspacePremium,
      'color': Color(0xFFE4A84B),
    },
    {
      'id': 'crown-coffee',
      'rwa_slug': 'crown-coffee',
      'name': 'Crown Coffee',
      'symbol': 'CCF',
      'asset_type': 'tokenized_asset',
      'price_usd': 126.40,
      'percent_change_24h': 0.8,
      'category': 'Commodities',
      'price_text': '\$126.40',
      'change_text': '↑ 0.8%',
      'icon': AppIcons.coffee,
      'color': Color(0xFF9B6A4A),
    },
    {
      'id': 'us-treasury-90d',
      'rwa_slug': 'us-treasury-90d',
      'name': 'US Treasury 90D',
      'symbol': 'UST90',
      'asset_type': 'treasury',
      'price_usd': 99.84,
      'percent_change_24h': -0.5,
      'category': 'Treasuries',
      'price_text': '\$99.84',
      'change_text': '↓ 0.5%',
      'icon': AppIcons.accountBalance,
      'color': Color(0xFF5690C9),
    },
  ];

  Map<String, dynamic> _normalizeAsset(Map<String, dynamic> asset) {
    final name = (asset['name'] ?? asset['symbol'] ?? 'Unknown Asset')
        .toString();
    final symbol = (asset['symbol'] ?? 'ASSET').toString().toUpperCase();
    final rawPrice =
        asset['average_tokenized_price'] ??
        asset['price_usd'] ??
        asset['current_price'] ??
        0.0;
    final rawChange =
        asset['percent_change_24h'] ??
        asset['price_change_percentage_24h'] ??
        0.0;
    final category = _assetCategory(name);
    final price = _asDouble(rawPrice);
    final change = _asDouble(rawChange);

    return {
      'id': asset['id'] ?? asset['rwa_slug'] ?? asset['symbol'] ?? name,
      'rwa_slug': asset['rwa_slug'] ?? asset['id'] ?? symbol.toLowerCase(),
      'name': name,
      'symbol': symbol,
      'asset_type': asset['asset_type'] ?? 'tokenized_asset',
      'price_usd': price,
      'market_cap_usd': _asDouble(
        asset['market_cap_usd'] ?? asset['tokenized_market_cap'],
      ),
      'market_cap_text': _formatMarketCap(
        _asDouble(asset['market_cap_usd'] ?? asset['tokenized_market_cap']),
      ),
      'percent_change_24h': change,
      'category': category,
      'price_text': _formatMoney(price),
      'change_text':
          '${change >= 0 ? '↑' : '↓'} ${change.abs().toStringAsFixed(1)}%',
      'image': _imageUrl(asset),
      'icon': _iconForCategory(category),
      'color': _colorForCategory(category),
      'label': asset['asset_type'] ?? 'tokenized_asset',
      'ticker': symbol,
    };
  }

  String _assetCategory(String name) {
    final value = name.toLowerCase();
    if (value.contains('gold') || value.contains('coffee')) {
      return 'Commodities';
    }
    if (value.contains('treasury') ||
        value.contains('bill') ||
        value.contains('bond')) {
      return 'Treasuries';
    }
    if (value.contains('invoice') || value.contains('receivable')) {
      return 'Invoices';
    }
    if (value.contains('estate') ||
        value.contains('property') ||
        value.contains('real')) {
      return 'Real Estate';
    }
    return 'Commodities';
  }

  List<Map<String, dynamic>> get _visibleAssets {
    final query = _query.trim().toLowerCase();
    return _assets.where((asset) {
      final matchesCategory =
          _category == 'All' || asset['category'] == _category;
      final searchValue = [
        asset['name'],
        asset['symbol'],
        asset['asset_type'],
        asset['category'],
      ].join(' ').toLowerCase();
      final matchesQuery = query.isEmpty || searchValue.contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  List<Map<String, dynamic>> get _visibleCategoryAssets {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _categoryAssets;
    return _categoryAssets.where((asset) {
      return [
        asset['name'],
        asset['symbol'],
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _RoundIconButton(
          icon: AppIcons.navigateBefore,
          onPressed: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Explore Assets',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
        ),
        _RoundIconButton(icon: AppIcons.refresh, onPressed: _loadAssets),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onSubmitted: _trackSearch,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search any asset, ticker, or issuer...',
        hintStyle: const TextStyle(color: Color(0xFF837C95), fontSize: 12),
        prefixIcon: const AppIcon(
          AppIcons.search,
          color: Color(0xFF9A87FF),
          size: 21,
        ),
        filled: true,
        fillColor: const Color(0xFF15121E),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF39304F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF836EF9)),
        ),
      ),
    );
  }

  Future<void> _trackSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;
    final profile = context.read<UserProfileService>();
    await profile.addSearch(query);
  }

  Widget _buildRecentSearches() {
    return Consumer<UserProfileService>(
      builder: (context, profile, _) {
        final history = profile.searchHistory.take(6).toList();
        if (history.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RECENT SEARCHES',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: history.map((query) {
                    final value = query.toString();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        onPressed: () {
                          _searchController.text = value;
                          _searchController.selection = TextSelection.collapsed(
                            offset: value.length,
                          );
                        },
                        avatar: const AppIcon(
                          AppIcons.history,
                          size: 14,
                          color: Colors.white54,
                        ),
                        label: Text(value),
                        labelStyle: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        backgroundColor: const Color(0xFF1A1625),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategories() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: _categories.map((label) {
          final selected = label == _category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _category = label),
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFFB8B1C6),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              backgroundColor: const Color.fromARGB(255, 0, 0, 0),
              selectedColor: const Color.fromARGB(255, 74, 24, 199),
              side: BorderSide.none,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRwaCategoryBrowser() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: RwaCategories.all.map((category) {
          final selected = category.id == _selectedRwaCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Text(
                category.emoji,
                style: const TextStyle(fontSize: 14),
              ),
              label: Text(category.label),
              selected: selected,
              onSelected: (_) => _loadCategoryAssets(category),
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFFB8B1C6),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              backgroundColor: const Color(0xFF15121E),
              selectedColor: const Color(0xFF4A18C7),
              side: BorderSide.none,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryAssets() {
    final category = RwaCategories.all.firstWhere(
      (item) => item.id == _selectedRwaCategory,
    );
    final assets = _visibleCategoryAssets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            category.label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_loadingCategory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_categoryError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _categoryError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          )
        else if (assets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No assets found in this category.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          )
        else
          ...assets.map(
            (asset) => _AssetRow(
              asset: asset,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RwaDetailScreen(asset: asset),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeatured() {
    final featured = _assets.take(3).toList();
    if (featured.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _featuredController,
            itemCount: featured.length,
            onPageChanged: (index) => setState(() => _featuredIndex = index),
            itemBuilder: (context, index) =>
                _FeaturedCard(asset: featured[index]),
          ),
        ),
        const SizedBox(height: 13),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            featured.length,
            (index) => Container(
              width: index == _featuredIndex ? 18 : 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index == _featuredIndex
                    ? const Color.fromARGB(255, 74, 24, 199)
                    : const Color(0xFF4D465B),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'REAL-WORLD ASSETS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
          ),
          child: const Text(
            'See All →',
            style: TextStyle(color: Color(0xFF9A87FF), fontSize: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleAssets;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshExplore,
          color: const Color.fromARGB(255, 74, 24, 199),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              const NewsFeed(),
              const SizedBox(height: 24),
              _buildRwaCategoryBrowser(),
              const SizedBox(height: 12),
              _buildSearch(),
              const SizedBox(height: 16),
              _buildCategoryAssets(),
              const SizedBox(height: 18),
              _buildCategories(),
              const SizedBox(height: 24),
              _buildRecentSearches(),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                ErrorBanner(
                  error: _error!,
                  onDismiss: () => setState(() => _error = null),
                  onRetry: () => setState(() => _error = null),
                )
              else ...[
                _buildFeatured(),
                const SizedBox(height: 30),
                _buildSectionHeader(),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'No real-world assets match your search.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  ...visible.map(
                    (asset) => _AssetRow(
                      asset: asset,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RwaDetailScreen(asset: asset),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _colorForCategory(String category) {
    switch (category) {
      case 'Treasuries':
        return const Color(0xFF5690C9);
      case 'Invoices':
        return const Color(0xFF00D18A);
      case 'Real Estate':
        return const Color(0xFF8E7BFF);
      case 'Commodities':
      default:
        return const Color(0xFFE4A84B);
    }
  }

  static FaIconData _iconForCategory(String category) {
    switch (category) {
      case 'Treasuries':
        return AppIcons.accountBalance;
      case 'Invoices':
        return AppIcons.receiptLong;
      case 'Real Estate':
        return AppIcons.locationCity;
      case 'Commodities':
      default:
        return AppIcons.workspacePremium;
    }
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static String _formatMoney(double value) {
    if (value <= 0) return '\$0.00';
    return NumberFormatting.money(value);
  }

  static String? _formatMarketCap(double value) {
    if (value <= 0) return null;
    if (value >= 1000000000) {
      return '\$${(value / 1000000000).toStringAsFixed(1)}B cap';
    }
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M cap';
    }
    if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(1)}K cap';
    return '\$${value.toStringAsFixed(0)} cap';
  }

  static String? _imageUrl(Map<String, dynamic> asset) {
    final image = asset['image'] ?? asset['image_url'] ?? asset['imageUrl'];
    if (image is String && image.isNotEmpty) return image;
    if (image is Map) {
      final url = image['large'] ?? image['small'] ?? image['thumb'];
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }
}

class _RoundIconButton extends StatelessWidget {
  final FaIconData icon;
  final VoidCallback onPressed;

  const _RoundIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: AppIcon(icon, color: const Color(0xFF9587B8), size: 21),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF171320),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Map<String, dynamic> asset;

  const _FeaturedCard({required this.asset});

  @override
  Widget build(BuildContext context) {
    final color = asset['color'] as Color;
    final subtitle = asset['name'] == 'Unitas Gold'
        ? '100 kg · Zurich'
        : asset['name'] == 'Crown Coffee'
        ? 'Premium Arabica · Brazil'
        : '90-Day US Treasury';

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.42)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 20),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: -4,
            child: _AssetImage(
              imageUrl: asset['image'] as String?,
              size: 78,
              fallback: AppIcon(
                asset['icon'] as FaIconData,
                size: 78,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                asset['category'] as String,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                asset['name'] as String,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 13),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D18A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '4.2% APY',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  final Map<String, dynamic> asset;
  final VoidCallback onTap;

  const _AssetRow({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = asset['color'] as Color;
    final changeText = asset['change_text'] as String;
    final marketCapText = asset['market_cap_text'] as String?;
    final positive = changeText.startsWith('↑');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            _AssetImage(
              imageUrl: asset['image'] as String?,
              size: 42,
              fallback: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  asset['icon'] as FaIconData,
                  color: color,
                  size: 21,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset['name'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${asset['symbol']} · ${asset['asset_type']}',
                    style: const TextStyle(
                      color: Color(0xFF837C95),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  asset['price_text'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  changeText,
                  style: TextStyle(
                    color: positive
                        ? const Color(0xFF00D18A)
                        : const Color(0xFFFF6B7A),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (marketCapText != null)
                  Text(
                    marketCapText,
                    style: const TextStyle(
                      color: Color(0xFF837C95),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 5),
            const AppIcon(
              AppIcons.chevronRight,
              color: Color(0xFF746B83),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Widget fallback;

  const _AssetImage({
    required this.imageUrl,
    required this.size,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
