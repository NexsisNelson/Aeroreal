import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/kyc_service.dart';
import '../services/privy_service.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _kycService = KycService();

  String _idType = 'Passport';
  bool _loading = true;
  bool _verified = false;
  String? _error;
  Map<String, String?>? _details;

  @override
  void initState() {
    super.initState();
    _checkVerification();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    final address = context.read<PrivyService>().walletAddress;
    if (address == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final verified = await _kycService.isVerified(address);
    final details = await _kycService.getDetails(address);
    if (!mounted) return;
    setState(() {
      _verified = verified;
      _details = details;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final country = _countryController.text.trim();
    final idNumber = _idNumberController.text.trim();

    if (name.isEmpty || country.isEmpty || idNumber.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final address = context.read<PrivyService>().walletAddress;
    if (address == null) {
      setState(() {
        _error = 'No wallet connected';
        _loading = false;
      });
      return;
    }

    await _kycService.markVerified(
      walletAddress: address,
      fullName: name,
      country: country,
      idType: _idType,
      idNumber: idNumber,
    );
    await _checkVerification();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identity Verification')),
      body: _loading && !_verified
          ? const Center(child: CircularProgressIndicator())
          : _verified
          ? _buildVerified()
          : _buildForm(),
    );
  }

  Widget _buildVerified() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.verified, color: Color(0xFF00D18A), size: 80),
        const SizedBox(height: 16),
        const Text(
          'Identity Verified',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your demo verification is complete. Production compliance would authorize the wallet through a regulated compliance service.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 32),
        _detailsPanel(),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _resetVerification,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset Demo Verification'),
        ),
      ],
    );
  }

  Widget _detailsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1625),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _row('Name', _details?['name'] ?? 'Not provided'),
          _row('Country', _details?['country'] ?? 'Not provided'),
          _row('ID Type', _details?['idType'] ?? 'Not provided'),
          _row('ID Number', _masked(_details?['idNumber'])),
          _row(
            'Verified At',
            _details?['verifiedAt']?.split('T').first ?? 'Unknown',
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Verify your identity',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'RWA tokens require compliance checks before they can be held. This hackathon flow stores mock verification locally on this device.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full Legal Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _countryController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Country of Residence',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _idType,
          decoration: const InputDecoration(
            labelText: 'ID Type',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Passport', child: Text('Passport')),
            DropdownMenuItem(value: 'National ID', child: Text('National ID')),
            DropdownMenuItem(
              value: "Driver's License",
              child: Text("Driver's License"),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _idType = value);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _idNumberController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'ID Number',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Do not enter a real identity number. Use mock data for this demo.',
          style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user),
          label: Text(_loading ? 'Checking...' : 'Verify Identity'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }

  Future<void> _resetVerification() async {
    final address = context.read<PrivyService>().walletAddress;
    if (address == null) return;
    await _kycService.clearVerification(address);
    if (!mounted) return;
    setState(() {
      _verified = false;
      _details = null;
      _error = null;
    });
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _masked(String? value) {
    if (value == null || value.length < 4) return 'Not provided';
    return '****${value.substring(value.length - 4)}';
  }
}
