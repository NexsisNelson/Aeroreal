import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'kyc_review_screen.dart';

class KycCameraScreen extends StatefulWidget {
  const KycCameraScreen({super.key, required this.documentType});

  final String documentType;

  @override
  State<KycCameraScreen> createState() => _KycCameraScreenState();
}

class _KycCameraScreenState extends State<KycCameraScreen> {
  final _picker = ImagePicker();
  XFile? _image;
  bool _openingCamera = false;

  Future<void> _capture() async {
    setState(() => _openingCamera = true);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (picked != null) setState(() => _image = picked);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the camera.')),
      );
    } finally {
      if (mounted) setState(() => _openingCamera = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC verification'),
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
              'Capture your document',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use a sample document image. Nothing is uploaded or checked by this demo.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _tip('01', 'Even lighting', 'Avoid glare and dark shadows.'),
            const SizedBox(height: 12),
            _tip('02', 'All edges visible', 'Keep the full document in frame.'),
            const SizedBox(height: 12),
            _tip('03', 'Hold steady', 'Check that the image is in focus.'),
            if (_image case final image?) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FutureBuilder(
                  future: image.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Image.memory(
                        snapshot.data!,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      );
                    }
                    return const SizedBox(
                      height: 190,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_image == null)
              FilledButton.icon(
                onPressed: _openingCamera ? null : _capture,
                icon: _openingCamera
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.camera_alt_outlined),
                label: Text(_openingCamera ? 'Opening camera' : 'Open camera'),
                style: _primaryButtonStyle,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openingCamera ? null : _capture,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => KycReviewScreen(
                            documentType: widget.documentType,
                            documentImage: _image!,
                          ),
                        ),
                      ),
                      style: _primaryButtonStyle,
                      child: const Text('Review'),
                    ),
                  ),
                ],
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
          'STEP 2 OF 3',
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
            value: 2 / 3,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            backgroundColor: Colors.white12,
            color: const Color(0xFF00D18A),
          ),
        ),
      ],
    );
  }

  Widget _tip(String number, String title, String detail) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Text(
            number,
            style: const TextStyle(
              color: Color(0xFF00D18A),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final _primaryButtonStyle = FilledButton.styleFrom(
  backgroundColor: const Color(0xFF00D18A),
  foregroundColor: Colors.black,
  minimumSize: const Size.fromHeight(52),
  textStyle: const TextStyle(fontWeight: FontWeight.bold),
);
