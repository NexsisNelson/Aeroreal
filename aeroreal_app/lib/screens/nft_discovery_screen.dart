import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/contract_service.dart';

class NftDiscoveryScreen extends StatefulWidget {
  const NftDiscoveryScreen({super.key});

  @override
  State<NftDiscoveryScreen> createState() => _NftDiscoveryScreenState();
}

class _NftDiscoveryScreenState extends State<NftDiscoveryScreen> {
  final _contractController = TextEditingController();
  final _walletController = TextEditingController();
  String? _collectionName;
  String? _collectionSymbol;
  List<BigInt> _ownedNfts = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _contractController.dispose();
    _walletController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final contractAddress = _contractController.text.trim();
    final walletAddress = _walletController.text.trim();
    if (contractAddress.isEmpty || walletAddress.isEmpty) {
      setState(() => _error = 'Enter both contract and wallet address');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contracts = context.read<ContractService>();
      final results = await Future.wait([
        contracts.getCollectionName(contractAddress),
        contracts.getCollectionSymbol(contractAddress),
        contracts.getNFTsOfCollectionOwnedBy(contractAddress, walletAddress),
      ]);
      if (!mounted) return;
      setState(() {
        _collectionName = results[0] as String;
        _collectionSymbol = results[1] as String;
        _ownedNfts = results[2] as List<BigInt>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Lookup failed: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NFT Discovery')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Browse any NFT collection',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter an ERC-721 contract and wallet address to inspect collection ownership.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _contractController,
            decoration: const InputDecoration(
              labelText: 'NFT Contract Address (0x...)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _walletController,
            decoration: const InputDecoration(
              labelText: 'Wallet Address (0x...)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _lookup,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF836EF9),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Search Collection'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 20),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          if (_collectionName != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1625),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _collectionName!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _collectionSymbol ?? '',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Text('${_ownedNfts.length} NFTs owned by this wallet'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._ownedNfts.map(
              (tokenId) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1625),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.image, color: Color(0xFF836EF9)),
                    const SizedBox(width: 12),
                    Text('Token #$tokenId'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
