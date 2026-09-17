import 'package:flutter/material.dart';

import '../services/watchlist_service.dart';
import 'rwa_detail_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final _service = WatchlistService();
  List<Map<String, dynamic>> _assets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final assets = await _service.getWatchlist();
    if (!mounted) return;
    setState(() {
      _assets = assets;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Watchlist')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No assets watched yet. Tap the star on any asset to add it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF836EF9),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _assets.length,
                itemBuilder: (context, index) {
                  final asset = _assets[index];
                  final change = _number(asset['percent_change_24h']);
                  final isPositive = change >= 0;
                  return InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RwaDetailScreen(asset: asset),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1625),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _AssetThumbnail(imageUrl: asset['image'] as String?),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  asset['name'] ?? 'RWA Asset',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  asset['symbol'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _currency(asset['price_usd']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${change.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  color: isPositive
                                      ? const Color(0xFF00D18A)
                                      : Colors.redAccent,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () async {
                              await _service.removeFromWatchlist(asset['id']);
                              _load();
                            },
                            icon: const Icon(
                              Icons.star,
                              color: Color(0xFFFFD700),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  double _number(dynamic value) => value is num ? value.toDouble() : 0;

  String _currency(dynamic value) {
    if (value is num) return '\$${value.toStringAsFixed(2)}';
    return '--';
  }
}

class _AssetThumbnail extends StatelessWidget {
  final String? imageUrl;

  const _AssetThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF2A243A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.token, color: Colors.white54, size: 18),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        imageUrl!,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}
