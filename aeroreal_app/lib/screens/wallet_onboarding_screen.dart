// lib/screens/wallet_onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/privy_service.dart';

class WalletOnboardingScreen extends StatefulWidget {
  const WalletOnboardingScreen({super.key});

  @override
  State<WalletOnboardingScreen> createState() => _WalletOnboardingScreenState();
}

class _WalletOnboardingScreenState extends State<WalletOnboardingScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _status;
  String? _address;
  String? _pendingEmail;
  String? _pendingPhone;
  bool _showCodeInput = false;

  @override
  void initState() {
    super.initState();
    final privy = context.read<PrivyService>();
    if (privy.isAuthenticated) {
      setState(() => _address = privy.walletAddress);
    }
  }

  // =========================================================
  // EMAIL LOGIN FLOW
  // =========================================================

  Future<void> _sendEmailCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _status = 'Sending code...';
    });

    try {
      final privy = context.read<PrivyService>();
      final ok = await privy.sendEmailCode(email);
      if (!ok) throw Exception('Failed to send email code');

      setState(() {
        _pendingEmail = email;
        _showCodeInput = true;
        _loading = false;
        _status = 'Check your email for the 6-digit code';
      });
    } catch (e) {
      setState(() {
        _error = 'Send failed: $e';
        _loading = false;
        _status = null;
      });
    }
  }

  Future<void> _verifyEmailCode() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code from your email');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _status = 'Verifying...';
    });

    try {
      final privy = context.read<PrivyService>();
      final ok = await privy.loginWithEmailCode(
        code: code,
        email: _pendingEmail!,
      );
      if (!ok) throw Exception('Invalid code');

      setState(() {
        _address = privy.walletAddress;
        _loading = false;
        _status = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Verification failed: $e';
        _loading = false;
        _status = null;
      });
    }
  }

  // =========================================================
  // PHONE LOGIN FLOW
  // =========================================================

  Future<void> _sendPhoneCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || !phone.startsWith('+')) {
      setState(() => _error = 'Enter phone in format +234...');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _status = 'Sending SMS...';
    });

    try {
      final privy = context.read<PrivyService>();
      final ok = await privy.sendSmsCode(phone);
      if (!ok) throw Exception('Failed to send SMS');

      setState(() {
        _pendingPhone = phone;
        _showCodeInput = true;
        _loading = false;
        _status = 'Check your SMS for the 6-digit code';
      });
    } catch (e) {
      setState(() {
        _error = 'Send failed: $e';
        _loading = false;
        _status = null;
      });
    }
  }

  Future<void> _verifyPhoneCode() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code from your SMS');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _status = 'Verifying...';
    });

    try {
      final privy = context.read<PrivyService>();
      final ok = await privy.loginWithSmsCode(
        code: code,
        phoneNumber: _pendingPhone!,
      );
      if (!ok) throw Exception('Invalid code');

      setState(() {
        _address = privy.walletAddress;
        _loading = false;
        _status = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Verification failed: $e';
        _loading = false;
        _status = null;
      });
    }
  }

  Future<void> _copyAddress() async {
    final address = _address;
    if (address == null) return;

    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Wallet address copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.water_drop, size: 80, color: Color(0xFF836EF9)),
              const SizedBox(height: 16),
              const Text(
                'Aeroreal',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Own Anything. Earn Everything.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 48),

              // ---- Already logged in ----
              if (_address != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1625),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your Wallet',
                        style: TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _address!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _copyAddress,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy address'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/main'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D18A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Continue to App',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ]
              // ---- OTP code input ----
              else if (_showCodeInput) ...[
                Text(
                  _pendingEmail != null
                      ? 'Code sent to $_pendingEmail'
                      : 'Code sent to $_pendingPhone',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '6-digit code',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading
                      ? null
                      : (_pendingEmail != null
                            ? _verifyEmailCode
                            : _verifyPhoneCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF836EF9),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Verify Code'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _showCodeInput = false;
                    _codeController.clear();
                  }),
                  child: const Text('Back'),
                ),
              ]
              // ---- Login buttons ----
              else ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _sendEmailCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF836EF9),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Continue with Email',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white12)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white12)),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Phone (+234...)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _loading ? null : _sendPhoneCode,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Continue with Phone',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],

              if (_loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],

              if (_status != null) ...[
                const SizedBox(height: 16),
                Text(
                  _status!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
