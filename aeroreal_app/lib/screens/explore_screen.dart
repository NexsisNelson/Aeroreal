// lib/screens/explore_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/contract_service.dart';
import '../services/rwa_service.dart';
import 'nft_discovery_screen.dart';
import 'rwa_detail_screen.dart';
import '../widgets/ipfs_link.dart';
import '../widgets/risk_disclosure.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'All';
  String _sortBy = 'Newest';

  List<Map<String, dynamic>> _allVaults = [];
  final _rwaService = RwaService();
  List<Map<String, dynamic>> _rwaAssets = [];
  bool _loading = true;
  bool _loadingRwa = true;
  String? _rwaError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVaults();
    _loadRwaAssets();
    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      setState(() => _searchQuery = query);
      _loadRwaAssets(query: query);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVaults() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contracts = context.read<ContractService>();
      final vaults = await contracts.getAllVaults();
      setState(() {
        _allVaults = vaults;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load vaults: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadRwaAssets({String? query}) async {
    if (mounted) {
      setState(() {
        _loadingRwa = true;
        _rwaError = null;
      });
    }
    try {
      final assets = await _rwaService.searchAssets(
        query: query ?? _searchQuery,
      );
      if (!mounted) return;
      setState(() {
        _rwaAssets = assets;
        _loadingRwa = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rwaError = error.toString().replaceFirst('Exception: ', '');
        _loadingRwa = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredVaults {
    var result = _allVaults.where((v) {
      // Filter by type.
      if (_filterType == 'Commodities' && v['commodityInfo'] == null) {
        return false;
      }
      if (_filterType == 'Invoices' && v['invoiceInfo'] == null) {
        return false;
      }

      // Filter by search query.
      if (_searchQuery.isEmpty) return true;

      final commodity = v['commodityInfo'];
      final invoice = v['invoiceInfo'];
      final searchable = [
        if (commodity != null) commodity['commodityType'],
        if (commodity != null) commodity['storageLocation'],
        if (commodity != null) commodity['custodian'],
        if (invoice != null) invoice['buyerJurisdiction'],
        v['address'],
      ].join(' ').toLowerCase();

      return searchable.contains(_searchQuery);
    }).toList();

    // Sort.
    switch (_sortBy) {
      case 'Highest Yield':
        // Sort invoices by discount (higher = better yield).
        result.sort((a, b) {
          final aDisc =
              a['invoiceInfo']?['discountBps'] as BigInt? ?? BigInt.zero;
          final bDisc =
              b['invoiceInfo']?['discountBps'] as BigInt? ?? BigInt.zero;
          return bDisc.compareTo(aDisc);
        });
        break;
      case 'Closing Soon':
        result.sort((a, b) {
          final aMat = a['invoiceInfo']?['maturityDate'] as BigInt?;
          final bMat = b['invoiceInfo']?['maturityDate'] as BigInt?;
          if (aMat == null || bMat == null) return 0;
          return aMat.compareTo(bMat);
        });
        break;
      case 'Newest':
      default:
        // Keep original order (newest first from Factory).
        break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Assets'),
        actions: [
          IconButton(onPressed: _loadVaults, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Search bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NftDiscoveryScreen()),
              ),
              icon: const Icon(Icons.collections_outlined),
              label: const Text('Browse Any NFT Collection'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search commodities, invoices, issuers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFF1A1625),
              ),
            ),
          ),

          // Filter chips.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filterType == 'All',
                  onTap: () => setState(() => _filterType = 'All'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Commodities',
                  selected: _filterType == 'Commodities',
                  onTap: () => setState(() => _filterType = 'Commodities'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Invoices',
                  selected: _filterType == 'Invoices',
                  onTap: () => setState(() => _filterType = 'Invoices'),
                ),
              ],
            ),
          ),

          // Sort row.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Sort by: ',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor: const Color(0xFF1A1625),
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'Newest', child: Text('Newest')),
                    DropdownMenuItem(
                      value: 'Highest Yield',
                      child: Text('Highest Yield'),
                    ),
                    DropdownMenuItem(
                      value: 'Closing Soon',
                      child: Text('Closing Soon'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _sortBy = v);
                  },
                ),
              ],
            ),
          ),

          // Results.
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadVaults,
                    color: const Color(0xFF836EF9),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_filteredVaults.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text(
                              'No vaults match your search.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        else
                          ..._filteredVaults.map(
                            (vault) => _VaultCard(vault: vault),
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          'Real-World Assets',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_loadingRwa)
                          const Center(child: CircularProgressIndicator())
                        else if (_rwaError != null)
                          Text(
                            _rwaError!,
                            style: const TextStyle(color: Colors.white54),
                          )
                        else if (_rwaAssets.isEmpty)
                          const Text(
                            'No RWA assets match your search.',
                            style: TextStyle(color: Colors.white54),
                          )
                        else
                          ..._rwaAssets.map(_RwaAssetCard.new),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF836EF9) : const Color(0xFF1A1625),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _RwaAssetCard extends StatelessWidget {
  final Map<String, dynamic> asset;

  const _RwaAssetCard(this.asset);

  @override
  Widget build(BuildContext context) {
    final price = asset['average_tokenized_price'];
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => RwaDetailScreen(asset: asset))),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1625),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF00D18A).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.token, color: Color(0xFF00D18A)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset['name'] ?? asset['symbol'] ?? 'RWA Asset',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${asset['symbol'] ?? ''}  ${asset['asset_type'] ?? ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              _displayPrice(price),
              style: const TextStyle(color: Color(0xFF00D18A)),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  String _displayPrice(dynamic value) {
    if (value is num) return '\$${value.toStringAsFixed(2)}';
    if (value is Map) {
      final usd = value['quote']?['USD'];
      if (usd is Map && usd['price'] is num) {
        return '\$${(usd['price'] as num).toStringAsFixed(2)}';
      }
    }
    return '--';
  }
}

class _VaultCard extends StatelessWidget {
  final Map<String, dynamic> vault;

  const _VaultCard({required this.vault});

  @override
  Widget build(BuildContext context) {
    final commodity = vault['commodityInfo'];
    final invoice = vault['invoiceInfo'];

    if (commodity != null) {
      return _buildCommodityCard(commodity);
    }
    if (invoice != null) {
      return _buildInvoiceCard(invoice);
    }
    return _buildGenericCard();
  }

  Widget _buildCommodityCard(Map<String, dynamic> commodity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFED9B40).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFED9B40).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.grain, color: Color(0xFFED9B40)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COMMODITY',
                      style: TextStyle(
                        color: Color(0xFFED9B40),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      commodity['commodityType'] ?? 'Commodity',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${commodity['quantity']} ${commodity['unitOfMeasure']}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                commodity['storageLocation'] ?? '',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const Text(
                'View Details →',
                style: TextStyle(color: Color(0xFFED9B40), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const RiskDisclosure(assetType: 'Commodity'),
          const SizedBox(height: 4),
          if (commodity['auditReportURI'] != null)
            IpfsLink(
              label: 'View Audit Report',
              ipfsHash: commodity['auditReportURI'],
              icon: Icons.verified_outlined,
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final face = (invoice['faceValue'] as BigInt) ~/ BigInt.from(10).pow(18);
    final discount = (invoice['discountBps'] as BigInt) ~/ BigInt.from(100);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D18A).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D18A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long, color: Color(0xFF00D18A)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INVOICE',
                      style: TextStyle(
                        color: Color(0xFF00D18A),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Face Value: $face mUSD',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${invoice['buyerJurisdiction'] ?? ''}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$discount% discount',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const Text(
                'View Details →',
                style: TextStyle(color: Color(0xFF00D18A), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const RiskDisclosure(assetType: 'Invoice'),
          const SizedBox(height: 4),
          if (invoice['invoiceDocumentURI'] != null)
            IpfsLink(
              label: 'View Invoice Document',
              ipfsHash: invoice['invoiceDocumentURI'],
              icon: Icons.receipt_long_outlined,
            ),
        ],
      ),
    );
  }

  Widget _buildGenericCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Vault: ${vault['address']}',
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}
