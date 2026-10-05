import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/kyc_service.dart';
import '../../services/privy_service.dart';

class KycReviewScreen extends StatefulWidget {
  const KycReviewScreen({
    super.key,
    required this.documentType,
    required this.documentImage,
  });

  final String documentType;
  final XFile documentImage;

  @override
  State<KycReviewScreen> createState() => _KycReviewScreenState();
}

class _KycReviewScreenState extends State<KycReviewScreen> {
  final _kycService = KycService();
  late final Future<Uint8List> _imageBytes;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.documentImage.readAsBytes();
  }

  Future<void> _submit() async {
    final walletAddress = context.read<PrivyService>().walletAddress;
    if (walletAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect a wallet before submitting.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _kycService.markVerified(
        walletAddress: walletAddress,
        fullName: 'Demo User',
        country: 'Demo',
        idType: widget.documentType,
        idNumber: 'DEMO',
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Demo verification complete'),
          backgroundColor: Color(0xFF176B4D),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not complete demo verification.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Final review'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _progress(),
            const SizedBox(height: 28),
            const Text(
              'Review your image',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check that the sample image is clear before completing the demo.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FutureBuilder<Uint8List>(
                future: _imageBytes,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const SizedBox(
                      height: 210,
                      child: Center(child: Text('Could not load this image.')),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 210,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return Image.memory(
                    snapshot.data!,
                    height: 210,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, color: Color(0xFF00D18A)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _documentLabel(widget.documentType),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Color(0xFF00D18A)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Submitting marks this wallet as demo-verified on this device. The image is not uploaded, and no identity review or on-chain whitelist update occurs.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00D18A),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(54),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Submit demo verification'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progress() {
    return Row(
      children: [
        const Text(
          'STEP 3 OF 3',
          style: TextStyle(
            color: Color(0xFF00D18A),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 96,
          child: LinearProgressIndicator(
            value: 1,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            backgroundColor: Colors.white12,
            color: const Color(0xFF00D18A),
          ),
        ),
      ],
    );
  }

  String _documentLabel(String value) => switch (value) {
    'passport' => 'Passport',
    'national_id' => 'National ID card',
    'drivers_license' => "Driver's license",
    _ => value,
  };
}
