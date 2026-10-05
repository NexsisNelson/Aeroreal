import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// UI/UX: Controls the compact market-summary card, quote loading state, and
// the empty/failure fallback shown when market data is unavailable.
class MarketOverviewCard extends StatefulWidget {
  const MarketOverviewCard({super.key});

  @override
  State<MarketOverviewCard> createState() => _MarketOverviewCardState();
}

class _MarketOverviewCardState extends State<MarketOverviewCard> {
  List<Map<String, dynamic>> _collections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.coingecko.com/api/v3/nfts/markets?per_page=5&page=1',
        ),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _collections = data.take(5).map<Map<String, dynamic>>((item) {
            final collection = item as Map<String, dynamic>;
            return {
              'name': collection['name'] ?? '',
              'floor': collection['floor_price']?['native_currency'] ?? 0,
              'change': collection['floor_price_24h_percentage_change'] ?? 0,
            };
          }).toList();
        });
      }
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_collections.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: Color(0xFF836EF9), size: 16),
              SizedBox(width: 8),
              Text(
                'Market Overview',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Spacer(),
              Text(
                'Powered by CoinGecko',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _collections.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final collection = _collections[index];
                final change = (collection['change'] as num).toDouble();
                return Container(
                  width: 130,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 0, 0, 0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (collection['name'] as String).length > 12
                            ? '${(collection['name'] as String).substring(0, 12)}...'
                            : collection['name'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${collection['floor']} ETH',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: change >= 0
                              ? const Color(0xFF00D18A)
                              : Colors.redAccent,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
