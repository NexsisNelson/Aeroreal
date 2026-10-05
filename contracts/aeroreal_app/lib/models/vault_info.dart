// lib/models/vault_info.dart

class VaultInfo {
  final String address;
  final String assetType; // "NFT", "Commodity", "Invoice"
  final String name;
  final String symbol;
  final String jurisdiction;
  final String? commodityType;
  final String? storageLocation;
  final BigInt? faceValue;
  final BigInt? discountBps;
  final BigInt? maturityDate;
  final bool isSettled;

  VaultInfo({
    required this.address,
    required this.assetType,
    required this.name,
    required this.symbol,
    required this.jurisdiction,
    this.commodityType,
    this.storageLocation,
    this.faceValue,
    this.discountBps,
    this.maturityDate,
    this.isSettled = false,
  });

  /// True if this is a commodity asset.
  bool get isCommodity => assetType == 'Commodity';

  /// True if this is an invoice asset.
  bool get isInvoice => assetType == 'Invoice';

  /// Days until invoice maturity (0 if not an invoice or already matured).
  int get daysUntilMaturity {
    if (maturityDate == null) return 0;
    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    if (maturityDate! <= now) return 0;
    return ((maturityDate! - now) ~/ BigInt.from(86400)).toInt();
  }
}
