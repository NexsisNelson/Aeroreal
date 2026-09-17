import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/contract_service.dart';
import '../services/privy_service.dart';

class NftFractionalizeScreen extends StatefulWidget {
  const NftFractionalizeScreen({super.key});

  @override
  State<NftFractionalizeScreen> createState() => _NftFractionalizeScreenState();
}

class _NftFractionalizeScreenState extends State<NftFractionalizeScreen> {
  List<BigInt> _ownedNfts = [];
  BigInt? _selectedNft;
  int _fractionCount = 10000;

  bool _loading = true;
  bool _creating = false;
  String? _error;
  String? _stage;
  String? _txHash;

  @override
  void initState() {
    super.initState();
    _loadNfts();
  }

  Future<void> _loadNfts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final privy = context.read<PrivyService>();
      final contracts = context.read<ContractService>();
      final addr = privy.walletAddress;
      if (addr == null) {
        setState(() => _loading = false);
        return;
      }
      final nfts = await contracts.getNFTsOwnedBy(addr);
      setState(() {
        _ownedNfts = nfts;
        _selectedNft = nfts.isNotEmpty ? nfts.first : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load NFTs: $e';
        _loading = false;
      });
    }
  }

  Future<void> _mintDemoNft() async {
    setState(() {
      _creating = true;
      _error = null;
      _stage = 'Minting a new Demo NFT...';
    });
    try {
      final contracts = context.read<ContractService>();
      await contracts.mintDemoNFT();
      await Future.delayed(const Duration(seconds: 4));
      setState(() => _stage = 'Refreshing your NFTs...');
      await _loadNfts();
      setState(() {
        _creating = false;
        _stage = null;
      });
    } catch (e) {
      setState(() {
        _creating = false;
        _stage = null;
        _error = 'Mint failed: $e';
      });
    }
  }

  Future<void> _fractionalize() async {
    if (_selectedNft == null) {
      setState(() => _error = 'Select an NFT first');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
      _txHash = null;
    });

    try {
      final contracts = context.read<ContractService>();

      setState(() => _stage = 'Creating vault...');
      await contracts.createVault(
        tokenId: _selectedNft!,
        totalFractions: _fractionCount,
        name: 'Fractionalized Demo Ape #$_selectedNft',
        symbol: 'fMDAPE',
      );
      await Future.delayed(const Duration(seconds: 4));

      setState(() => _stage = 'Discovering vault...');
      final vaultAddress = await contracts.getLatestVault();

      setState(() => _stage = 'Approving NFT...');
      await contracts.approveNFT(_selectedNft!, vaultAddress);
      await Future.delayed(const Duration(seconds: 4));

      setState(() => _stage = 'Fractionalizing NFT...');
      final txHash = await contracts.fractionalize(vaultAddress);

      setState(() {
        _txHash = txHash;
        _stage = 'Success! You now own $_fractionCount fractions.';
        _creating = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed: $e';
        _creating = false;
        _stage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fractionalize NFT')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Turn your NFT into fractions.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lock an NFT and mint 10,000 tradeable pieces. Each piece earns \$SPR rewards every second.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: _creating ? null : _mintDemoNft,
                  icon: const Icon(Icons.add),
                  label: const Text('Mint a Fresh Demo NFT'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: const Color(0xFF836EF9),
                    side: const BorderSide(color: Color(0xFF836EF9)),
                  ),
                ),
                const SizedBox(height: 24),

                if (_ownedNfts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1625),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'No NFTs found. Tap "Mint a Fresh Demo NFT" to create one.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1625),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select NFT',
                          style: TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 12),
                        RadioGroup<BigInt>(
                          groupValue: _selectedNft,
                          onChanged: (value) =>
                              setState(() => _selectedNft = value),
                          child: Column(
                            children: _ownedNfts
                                .map(
                                  (id) => RadioListTile<BigInt>(
                                    value: id,
                                    title: Text('Demo Ape #$id'),
                                    activeColor: const Color(0xFF836EF9),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      const Text(
                        'Number of fractions',
                        style: TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: _fractionCount.toDouble(),
                        min: 100,
                        max: 100000,
                        divisions: 999,
                        label: _fractionCount.toString(),
                        activeColor: const Color(0xFF836EF9),
                        onChanged: (value) =>
                            setState(() => _fractionCount = value.round()),
                      ),
                      Text(
                        '$_fractionCount fractions',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_stage != null) ...[
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_stage!)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_txHash != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D18A).withAlpha(38),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Success! Transaction Hash',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _txHash!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                ElevatedButton(
                  onPressed: _creating || _selectedNft == null
                      ? null
                      : _fractionalize,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF836EF9),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: _creating
                      ? const Text('Processing...')
                      : const Text(
                          'Fractionalize NFT',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
    );
  }
}
