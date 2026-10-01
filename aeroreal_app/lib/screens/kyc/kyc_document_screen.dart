import 'package:flutter/material.dart';

import 'kyc_camera_screen.dart';

class KycDocumentScreen extends StatefulWidget {
  const KycDocumentScreen({super.key});

  @override
  State<KycDocumentScreen> createState() => _KycDocumentScreenState();
}

class _KycDocumentScreenState extends State<KycDocumentScreen> {
  String? _selectedDocument;

  static const _documents = [
    ('passport', 'Passport', Icons.book_outlined),
    ('national_id', 'National ID card', Icons.badge_outlined),
    ('drivers_license', "Driver's license", Icons.credit_card_outlined),
  ];

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
            _progress(1),
            const SizedBox(height: 28),
            const Text(
              'Select a document',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose the document you will capture. Use a sample image for this demo.',
              style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            for (final document in _documents) ...[
              _documentOption(document.$1, document.$2, document.$3),
              if (document != _documents.last) const SizedBox(height: 10),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _selectedDocument == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => KycCameraScreen(
                          documentType: _selectedDocument!,
                        ),
                      ),
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00D18A),
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF244239),
                minimumSize: const Size.fromHeight(54),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: const Text('Continue to camera'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progress(int step) {
    return Row(
      children: [
        Text(
          'STEP $step OF 3',
          style: const TextStyle(
            color: Color(0xFF00D18A),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 96,
          child: LinearProgressIndicator(
            value: step / 3,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            backgroundColor: Colors.white12,
            color: const Color(0xFF00D18A),
          ),
        ),
      ],
    );
  }

  Widget _documentOption(String id, String title, IconData icon) {
    final selected = _selectedDocument == id;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => setState(() => _selectedDocument = id),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF10251E) : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF00D18A) : Colors.white12,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFF00D18A) : Colors.white70,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 15)),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? const Color(0xFF00D18A) : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}