import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../services/contract_service.dart';
import '../services/privy_service.dart';
import '../services/user_profile_service.dart';
import '../utils/nft_image.dart';
import '../widgets/error_banner.dart';

class _OwnedNft {
  final BigInt tokenId;
  final String contractAddress;
  final String collectionName;
  final String collectionSymbol;
  final String? profileNftId;

  const _OwnedNft({
    required this.tokenId,
    required this.contractAddress,
    required this.collectionName,
    required this.collectionSymbol,
    this.profileNftId,
  });
}

// UI/UX: Controls the NFT fractionalization wizard, fraction amount controls,
// staged transaction progress, success output, and failure recovery.
class NftFractionalizeScreen extends StatefulWidget {
  const NftFractionalizeScreen({super.key});

  @override
  State<NftFractionalizeScreen> createState() => _NftFractionalizeScreenState();
}

class _NftFractionalizeScreenState extends State<NftFractionalizeScreen> {
  List<_OwnedNft> _ownedNfts = [];
  _OwnedNft? _selectedNft;
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
      final profile = context.read<UserProfileService>();
      final addr = privy.walletAddress;
      if (addr == null) {
        setState(() => _loading = false);
        return;
      }
      await profile.load(addr);
      final profileNfts = profile.simulatedNfts
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      const collections = <(String, String, String)>[
        (AppConstants.demoNft, 'Demo Ape', 'DEMO'),
        (AppConstants.simulatedBayc, 'Simulated Bored Ape', 'sBAYC'),
        (AppConstants.simulatedPunks, 'Simulated CryptoPunk', 'sPUNK'),
        (AppConstants.simulatedDoodles, 'Simulated Doodle', 'sDOODLE'),
      ];
      final nfts = <_OwnedNft>[];
      for (final (contract, fallbackName, symbol) in collections) {
        final tokenIds = await contracts.getNFTsOfCollectionOwnedBy(
          contract,
          addr,
        );
        for (final tokenId in tokenIds) {
          Map<String, dynamic>? record;
          for (final item in profileNfts) {
            if (item['contractAddress'].toString().toLowerCase() ==
                    contract.toLowerCase() &&
                item['tokenId'].toString() == tokenId.toString()) {
              record = item;
              break;
            }
          }
          nfts.add(
            _OwnedNft(
              tokenId: tokenId,
              contractAddress: contract,
              collectionName: (record?['collectionName'] ?? fallbackName)
                  .toString(),
              collectionSymbol: symbol,
              profileNftId: record?['id']?.toString(),
            ),
          );
        }
      }
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
      final profileService = context.read<UserProfileService>();
      final selected = _selectedNft!;

      setState(() => _stage = 'Creating vault...');
      await contracts.createVault(
        tokenId: selected.tokenId,
        totalFractions: _fractionCount,
        name: 'Fractionalized ${selected.collectionName} #${selected.tokenId}',
        symbol: 'f${selected.collectionSymbol}',
        nftContract: selected.contractAddress,
      );
      await Future.delayed(const Duration(seconds: 4));

      setState(() => _stage = 'Discovering vault...');
      final vaultAddress = await contracts.getLatestVault();

      setState(() => _stage = 'Approving NFT...');
      await contracts.approveNFT(
        selected.tokenId,
        vaultAddress,
        nftContract: selected.contractAddress,
      );
      await Future.delayed(const Duration(seconds: 4));

      setState(() => _stage = 'Fractionalizing NFT...');
      final txHash = await contracts.fractionalize(vaultAddress);
      if (selected.profileNftId != null) {
        final fractionToken = await contracts.getVaultFractionToken(
          vaultAddress,
        );
        final saved = await profileService.markNftFractionalized(
          nftId: selected.profileNftId!,
          fractionTokenAddress: fractionToken,
        );
        if (!saved) throw Exception('Could not update your NFT profile');
      }

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
      appBar: AppBar(
        title: const Text('Fractionalize NFT'),
        actions: [
          IconButton(onPressed: _loadNfts, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Turn your NFT into fractions.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lock an NFT in a vault, mint tradeable fractions, and earn AREAL every second.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),

                if (_ownedNfts.isNotEmpty) ...[
                  const Text(
                    'SELECT AN NFT',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _ownedNfts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final nftId = _ownedNfts[i].tokenId;
                        final isSelected = _selectedNft?.tokenId == nftId;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedNft = _ownedNfts[i]),
                          child: Container(
                            width: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1625),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF836EF9)
                                    : Colors.white.withValues(alpha: 0.06),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(14),
                                    ),
                                    child: Image.network(
                                      NftImage.forToken(
                                        tokenId: nftId,
                                        collectionSymbol:
                                            _ownedNfts[i].collectionSymbol,
                                      ),
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: const Color(0xFF0D0B14),
                                                child: const Icon(
                                                  Icons.image,
                                                  color: Colors.white24,
                                                ),
                                              ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    'Ape #${nftId.toString()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? const Color(0xFF836EF9)
                                          : Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (_selectedNft != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1625),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            NftImage.forToken(
                              tokenId: _selectedNft!.tokenId,
                              collectionSymbol: _selectedNft!.collectionSymbol,
                            ),
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 220,
                                  color: const Color(0xFF0D0B14),
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.white24,
                                    size: 80,
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Demo Ape #${_selectedNft!.tokenId}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Owned by you',
                          style: TextStyle(
                            color: Color(0xFF00D18A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                const Text(
                  'NUMBER OF FRACTIONS',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1625),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_fractionCount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} fractions',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _fractionCount.toDouble(),
                        min: 100,
                        max: 100000,
                        divisions: 999,
                        activeColor: const Color(0xFF836EF9),
                        onChanged: (v) =>
                            setState(() => _fractionCount = v.round()),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '100',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '1K',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '10K',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '100K',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                OutlinedButton.icon(
                  onPressed: _creating ? null : _mintDemoNft,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Mint a Fresh Demo NFT'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: const Color(0xFF836EF9),
                    side: const BorderSide(color: Color(0xFF836EF9)),
                  ),
                ),
                const SizedBox(height: 24),

                if (_stage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF836EF9).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF836EF9),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _stage!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_error != null) ...[
                  ErrorBanner(
                    error: _error!,
                    onDismiss: () => setState(() => _error = null),
                    onRetry: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_txHash != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D18A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Success!',
                          style: TextStyle(
                            color: Color(0xFF00D18A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _txHash!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Colors.white70,
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
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _creating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Fractionalize NFT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
