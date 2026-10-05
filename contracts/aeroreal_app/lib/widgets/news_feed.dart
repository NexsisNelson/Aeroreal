import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/news_service.dart';

class NewsFeed extends StatefulWidget {
  const NewsFeed({super.key});

  @override
  State<NewsFeed> createState() => _NewsFeedState();
}

class _NewsFeedState extends State<NewsFeed> {
  final _service = NewsService();
  List<NewsItem> _items = [];
  bool _loading = true;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.getRwaNews();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 100,
        decoration: _decoration(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_items.isEmpty) return const SizedBox.shrink();

    final visibleItems = _showAll ? _items : _items.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MARKET NEWS',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll ? 'See Less' : 'See All',
                style: const TextStyle(color: Color(0xFF836EF9), fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visibleItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = visibleItems[index];
              return GestureDetector(
                onTap: () => _open(item.url),
                child: SizedBox(
                  width: 240,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: _decoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _thumbnail(item.thumbnail),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.source,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF836EF9),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            Text(
                              item.relativeTime,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _thumbnail(String? url) {
    if (url == null || url.isEmpty) return _thumbnailPlaceholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        height: 60,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _thumbnailPlaceholder(),
      ),
    );
  }

  Widget _thumbnailPlaceholder() => Container(
    height: 60,
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFF0D0B14),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.article_outlined, color: Colors.white24),
  );

  BoxDecoration _decoration() => BoxDecoration(
    color: const Color(0xFF1A1625),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
  );
}
