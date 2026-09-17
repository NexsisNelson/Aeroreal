import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/tx_history_service.dart';

class TxHistoryScreen extends StatefulWidget {
  const TxHistoryScreen({super.key});

  @override
  State<TxHistoryScreen> createState() => _TxHistoryScreenState();
}

class _TxHistoryScreenState extends State<TxHistoryScreen> {
  final _service = TxHistoryService();
  List<TransactionRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await _service.getAll();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _openExplorer(String hash) async {
    final uri = Uri.parse('https://testnet.monadscan.com/tx/$hash');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _clear() async {
    await _service.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              onPressed: _clear,
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? const Center(
              child: Text(
                'No transactions yet',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF836EF9),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _records.length,
                itemBuilder: (context, index) {
                  final record = _records[index];
                  return InkWell(
                    onTap: () => _openExplorer(record.hash),
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF836EF9,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.receipt_long,
                              color: Color(0xFF836EF9),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.action,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  record.details,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  record.timestamp
                                      .toLocal()
                                      .toString()
                                      .split('.')
                                      .first,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.open_in_new,
                            color: Colors.white54,
                            size: 16,
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
}
