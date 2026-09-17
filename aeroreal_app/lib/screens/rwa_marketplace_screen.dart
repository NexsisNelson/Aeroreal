// lib/screens/rwa_marketplace_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../services/contract_service.dart';
import '../services/wallet_service.dart';
import '../widgets/ipfs_link.dart';
import '../widgets/risk_disclosure.dart';

class RwaMarketplaceScreen extends StatefulWidget {
  const RwaMarketplaceScreen({super.key});

  @override
  State<RwaMarketplaceScreen> createState() => _RwaMarketplaceScreenState();
}

class _RwaMarketplaceScreenState extends State<RwaMarketplaceScreen> {
  bool _loading = true;
  String? _error;

  String? _goldPrice;

  List<dynamic> _commodityInfo = const [];
  List<dynamic> _invoiceInfo = const [];

  BigInt _commodityFractionBalance = BigInt.zero;
  BigInt _invoiceFractionBalance = BigInt.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;

    final contracts = context.read<ContractService>();
    final wallet = context.read<WalletService>();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      try {
        _goldPrice = await contracts.getGoldPrice();
      } catch (_) {
        _goldPrice = null;
      }

      final commodityInfo = await contracts.getCommodityInfo(
        AppConstants.commodityVault,
      );
      final invoiceInfo = await contracts.getInvoiceInfo(
        AppConstants.invoiceVault,
      );

      final commodityToken = await contracts.getVaultFractionToken(
        AppConstants.commodityVault,
      );
      final invoiceToken = await contracts.getVaultFractionToken(
        AppConstants.invoiceVault,
      );

      final address = wallet.hasWallet && wallet.address != null
          ? wallet.address!.with0x
          : null;

      BigInt commodityBalance = BigInt.zero;
      BigInt invoiceBalance = BigInt.zero;
      if (address != null) {
        commodityBalance = await contracts.getERC20Balance(
          commodityToken,
          address,
        );
        invoiceBalance = await contracts.getERC20Balance(invoiceToken, address);
      }

      if (!mounted) return;
      setState(() {
        _commodityInfo = commodityInfo;
        _invoiceInfo = invoiceInfo;
        _commodityFractionBalance = commodityBalance;
        _invoiceFractionBalance = invoiceBalance;
        _goldPrice = _goldPrice;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load RWA marketplace: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final commodityInfo = _commodityInfo.length >= 7
        ? _commodityInfo
        : <dynamic>[];
    final invoiceInfo = _invoiceInfo.length >= 11 ? _invoiceInfo : <dynamic>[];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: const Color(0xFF836EF9),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RWA Marketplace',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Gold, Coffee and Treasury assets',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, color: Color(0xFF836EF9)),
                    tooltip: 'Refresh marketplace',
                  ),
                ],
              ),
              if (_goldPrice != null)
                Container(
                  margin: const EdgeInsets.only(top: 16, bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Live Gold Price (Chainlink)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _goldPrice!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'per troy ounce',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(_error!),
                ),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: Color(0xFF836EF9)),
                  ),
                ),
              if (!_loading && commodityInfo.isNotEmpty)
                _buildCommodityCard(context, commodityInfo),
              const SizedBox(height: 16),
              if (!_loading && invoiceInfo.isNotEmpty)
                _buildInvoiceCard(context, invoiceInfo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommodityCard(BuildContext context, List<dynamic> info) {
    final commodityType = info[0] as String;
    final quantity = info[1] as BigInt;
    final unit = info[2] as String;
    final location = info[3] as String;
    final audit = info[4] as String;
    final insurance = info[5] as String;
    final custodian = info[6] as String;

    final quantityDisplay = quantity.toString();

    return _assetCard(
      title: 'Gold Certificate',
      subtitle: commodityType,
      status: 'Preview',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Type', commodityType),
          _infoRow('Quantity', '$quantityDisplay $unit'),
          _infoRow('Storage', location),
          _infoRow('Custodian', custodian),
          _infoRow('Audit', audit),
          _infoRow('Insurance', insurance),
          _infoRow(
            'Token Balance',
            context.read<ContractService>().formatToken(
              _commodityFractionBalance,
            ),
          ),
          _infoRow('Vault', AppConstants.commodityVault),
          const SizedBox(height: 8),
          const RiskDisclosure(assetType: 'Commodity'),
          const SizedBox(height: 4),
          IpfsLink(
            label: 'View Audit Report',
            ipfsHash: audit,
            icon: Icons.verified_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(BuildContext context, List<dynamic> info) {
    final smeIssuer = info[0].toString();
    final invoiceBuyer = info[1].toString();
    final faceValue = info[2] as BigInt;
    final discount = info[3] as BigInt;
    final issueDate = info[4] as BigInt;
    final maturityDate = info[5] as BigInt;
    final isSettled = info[6] as bool;
    final totalSettled = info[7] as BigInt;
    final settlementToken = info[8].toString();
    final documentUri = info[9] as String;
    final jurisdiction = info[10] as String;

    return _assetCard(
      title: 'Treasury Certificate',
      subtitle: 'US Treasury Bill',
      status: isSettled ? 'Settled' : 'Preview',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Buyer', invoiceBuyer.toString()),
          _infoRow('Seller', smeIssuer.toString()),
          _infoRow(
            'Face value',
            context.read<ContractService>().formatToken(faceValue),
          ),
          _infoRow('Discount', '${discount.toString()} bps'),
          _infoRow(
            'Issue date',
            DateTime.fromMillisecondsSinceEpoch(
              issueDate.toInt() * 1000,
            ).toIso8601String(),
          ),
          _infoRow(
            'Maturity date',
            DateTime.fromMillisecondsSinceEpoch(
              maturityDate.toInt() * 1000,
            ).toIso8601String(),
          ),
          _infoRow('Settled', isSettled ? 'Yes' : 'No'),
          _infoRow(
            'Total settled',
            context.read<ContractService>().formatToken(totalSettled),
          ),
          _infoRow('Settlement token', settlementToken.toString()),
          _infoRow('Document', documentUri),
          _infoRow('Jurisdiction', jurisdiction),
          _infoRow(
            'Token Balance',
            context.read<ContractService>().formatToken(
              _invoiceFractionBalance,
            ),
          ),
          _infoRow('Vault', AppConstants.invoiceVault),
          const SizedBox(height: 8),
          const RiskDisclosure(assetType: 'Invoice'),
          const SizedBox(height: 4),
          IpfsLink(
            label: 'View Invoice Document',
            ipfsHash: documentUri,
            icon: Icons.receipt_long_outlined,
          ),
        ],
      ),
    );
  }

  Widget _assetCard({
    required String title,
    required String subtitle,
    required String status,
    required Widget body,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF836EF9).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white54)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF382E66),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(status),
              ),
            ],
          ),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
