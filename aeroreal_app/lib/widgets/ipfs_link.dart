import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class IpfsLink extends StatelessWidget {
  final String label;
  final String ipfsHash;
  final IconData icon;

  const IpfsLink({
    super.key,
    required this.label,
    required this.ipfsHash,
    this.icon = Icons.description_outlined,
  });

  String get _gatewayUrl {
    var hash = ipfsHash;
    if (hash.startsWith('ipfs://')) {
      hash = hash.substring(7);
    }
    return 'https://ipfs.io/ipfs/$hash';
  }

  bool get _hasDocument => ipfsHash.isNotEmpty;

  Future<void> _open() async {
    final uri = Uri.parse(_gatewayUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasDocument) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white38),
            const SizedBox(width: 8),
            Text(
              '$label: Not provided',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF836EF9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF836EF9),
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF836EF9),
                  ),
                ),
              ),
              const Icon(Icons.open_in_new,
                  size: 14, color: Color(0xFF836EF9)),
            ],
          ),
        ),
      ),
    );
  }
}
