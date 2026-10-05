import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../services/contract_service.dart';
import '../services/privy_service.dart';

class CreateNftScreen extends StatefulWidget {
  const CreateNftScreen({super.key});

  @override
  State<CreateNftScreen> createState() => _CreateNftScreenState();
}

class _CreateNftScreenState extends State<CreateNftScreen> {
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _image;
  bool _uploading = false;
  bool _minting = false;
  String? _status;
  String? _error;
  String? _txHash;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _image = File(picked.path));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  Future<void> _createNft() async {
    if (_image == null) {
      if (!mounted) return;
      setState(() => _error = 'Please select an image');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'Please enter a name');
      return;
    }

    if (!mounted) return;
    setState(() {
      _uploading = true;
      _error = null;
      _status = 'Uploading to IPFS...';
    });

    try {
      final bytes = await _image!.readAsBytes();
      final base64Image = 'data:image/png;base64,${base64Encode(bytes)}';

      final uploadRes = await http.post(
        Uri.parse('http://10.0.2.2:3001/api/nft/upload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'image': base64Image,
        }),
      );

      if (uploadRes.statusCode != 200) {
        throw Exception('Upload failed: ${uploadRes.body}');
      }

      final uploadData = jsonDecode(uploadRes.body) as Map<String, dynamic>;
      final tokenUri = uploadData['tokenUri'] as String;

      if (!mounted) return;
      setState(() {
        _status = 'Minting on Monad...';
        _uploading = false;
        _minting = true;
      });

      final contracts = context.read<ContractService>();
      final privy = context.read<PrivyService>();
      final addr = privy.walletAddress;
      if (addr == null) throw Exception('No wallet connected');

      final txHash = await contracts.mintUserNft(
        tokenUri: tokenUri,
        recipient: addr,
        royaltyBps: 500,
      );

      if (!mounted) return;
      setState(() {
        _txHash = txHash;
        _status = 'Success! Your NFT is live.';
        _minting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed: $e';
        _uploading = false;
        _minting = false;
        _status = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create NFT')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Create your own NFT',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload an image, add details, and mint it on Monad. It will appear in the Marketplace.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _showImageSourceSheet(),
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1625),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: _image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        _image!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tap to upload an image',
                          style: TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Camera or gallery',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'NFT Name',
              hintText: 'e.g., Cosmic Ape #1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Tell the story behind your NFT...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          if (_status != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF836EF9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_uploading || _minting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF836EF9),
                      ),
                    ),
                  if (!_uploading && !_minting)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF00D18A),
                      size: 16,
                    ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_status!)),
                ],
              ),
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
                    'Transaction Hash',
                    style: TextStyle(
                      color: Color(0xFF00D18A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _txHash!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: _uploading || _minting ? null : _createNft,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF836EF9),
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _minting ? 'Minting...' : 'Create & Mint NFT',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1625),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF836EF9)),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF836EF9)),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
