// lib/screens/wallet_onboarding_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/wallet_service.dart';
import '../services/privy_service.dart';
import '../services/user_profile_service.dart';
import 'fund_wallet_screen.dart';

// UI/UX: Controls the authentication state machine, email/phone OTP forms,
// resend timer, wallet-ready state, and funding navigation.
class WalletOnboardingScreen extends StatefulWidget {
  const WalletOnboardingScreen({super.key});

  @override
  State<WalletOnboardingScreen> createState() => _WalletOnboardingScreenState();
}

class _WalletOnboardingScreenState extends State<WalletOnboardingScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  String? _error;
  String? _status;
  String? _address;
  String? _pendingEmail;
  String? _pendingPhone;
  bool _showCodeInput = false;
  bool _showSignIn = false;
  bool _showEmailForm = false;
  bool _showPhoneForm = false;
  Timer? _resendTimer;
  Timer? _readyPulseTimer;
  int _resendSeconds = 0;
  BigInt _monBalance = BigInt.zero;
  bool _readyPulse = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _readyPulseTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _phoneController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final privy = context.read<PrivyService>();
    if (privy.isAuthenticated) {
      _address = privy.walletAddress;
      _loadWalletReadyState();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || context.read<PrivyService>().isAuthenticated) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'You are signed out. Sign in to access your wallet and portfolio.',
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'SIGN IN',
              onPressed: () {
                if (mounted) setState(() => _showSignIn = true);
              },
            ),
          ),
        );
      });
    }
  }

  Future<void> _loadWalletReadyState() async {
    final address = _address;
    if (address == null || address.isEmpty) return;
    try {
      final balance = await context.read<WalletService>().getMonBalance(
        ownerAddress: address,
      );
      if (mounted) setState(() => _monBalance = balance);
    } catch (_) {}
    _readyPulseTimer?.cancel();
    _readyPulseTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) setState(() => _readyPulse = !_readyPulse);
    });
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
        _startResendTimer();
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
    final code = _otpCode.isNotEmpty ? _otpCode : _codeController.text.trim();
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
      final userProfile = context.read<UserProfileService>();
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
      final address = privy.walletAddress;
      if (address != null && mounted) await userProfile.load(address);
      _loadWalletReadyState();
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
        _startResendTimer();
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
    final code = _otpCode.isNotEmpty ? _otpCode : _codeController.text.trim();
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
      final userProfile = context.read<UserProfileService>();
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
      final address = privy.walletAddress;
      if (address != null && mounted) await userProfile.load(address);
      _loadWalletReadyState();
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

  void _selectEmail() => setState(() {
    _showEmailForm = true;
    _showPhoneForm = false;
  });

  void _selectPhone() => setState(() {
    _showEmailForm = false;
    _showPhoneForm = true;
    _showCodeInput = false;
    _status = null;
  });

  void _showUnavailable(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider sign-in will be available soon.')),
    );
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _otpCode =>
      _otpControllers.map((controller) => controller.text).join();

  void _handleOtpChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (
        var offset = 0;
        offset < digits.length && index + offset < 6;
        offset++
      ) {
        _otpControllers[index + offset].text = digits[offset];
      }
      final next = (index + digits.length).clamp(0, 5);
      _otpFocusNodes[next].requestFocus();
      setState(() {});
      return;
    }
    if (value.isNotEmpty && index < 5) _otpFocusNodes[index + 1].requestFocus();
    setState(() {});
  }

  KeyEventResult _handleOtpKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpControllers[index].text.isEmpty &&
        index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    return KeyEventResult.ignored;
  }

  Future<void> _resendCode() async {
    if (_resendSeconds > 0 || _loading) return;
    if (_pendingEmail != null) {
      await _sendEmailCode();
    } else if (_pendingPhone != null) {
      await _sendPhoneCode();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_address != null) return _buildWalletReadyScreen(context);
    if (_showCodeInput && _address == null) {
      return _buildOtpScreen(context);
    }
    if (_showSignIn && _showEmailForm && !_showCodeInput && _address == null) {
      return _buildEmailEntryScreen(context);
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: Stack(
          children: [
            const _WelcomeBackdrop(),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: _showSignIn ? 4 : 86),
                  const _AerorealMark(),
                  const SizedBox(height: 22),
                  const Text(
                    'Aeroreal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Own Anything. Earn Everything.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (!_showSignIn) ...[
                    const SizedBox(height: 300),
                    FilledButton(
                      onPressed: () => setState(() => _showSignIn = true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 74, 24, 199),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 17),
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() => _showSignIn = true),
                        child: const Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(
                              color: Color(0xFF837C95),
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign In',
                                style: TextStyle(
                                  color: Color(0xFFB09EFF),
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFFB09EFF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_showSignIn) ...[
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            _showSignIn = false;
                            _showEmailForm = false;
                          }),
                          icon: const Icon(
                            Icons.navigate_before_ios_new,
                            size: 18,
                          ),
                          color: const Color(0xFF9A87FF),
                        ),
                      ],
                    ),
                    _SignInHero(),
                    const SizedBox(height: 22),
                    if (!_showEmailForm &&
                        !_showPhoneForm &&
                        !_showCodeInput &&
                        _address == null) ...[
                      const Text(
                        'Continue with',
                        style: TextStyle(
                          color: Color(0xFF9C96A9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AuthOption(
                        icon: Icons.g_mobiledata,
                        label: 'Continue with Google',
                        highlighted: true,
                        onTap: () => _showUnavailable('Google'),
                      ),
                      _AuthOption(
                        icon: Icons.apple,
                        label: 'Continue with Apple',
                        onTap: () => _showUnavailable('Apple'),
                      ),
                      _AuthOption(
                        icon: Icons.email_outlined,
                        label: 'Continue with Email',
                        onTap: _selectEmail,
                      ),
                      _AuthOption(
                        icon: Icons.phone_outlined,
                        label: 'Continue with Phone',
                        onTap: _selectPhone,
                      ),
                      _AuthOption(
                        icon: Icons.fingerprint,
                        label: 'Sign in with Passkey',
                        onTap: () => _showUnavailable('Passkey'),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white12)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: TextStyle(
                                color: Color(0xFF837C95),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.white12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 12),
                      const Text.rich(
                        TextSpan(
                          text: 'By continuing, you agree to Aeroreal\'s ',
                          style: TextStyle(
                            color: Color(0xFF625C6C),
                            fontSize: 9,
                          ),
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(
                              text: ' and ',
                              style: TextStyle(decoration: TextDecoration.none),
                            ),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    // ---- Already logged in ----
                    if (_address != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 0, 0, 0),
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
                          backgroundColor: const Color.fromARGB(
                            255,
                            74,
                            24,
                            199,
                          ),
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
                    else if (_showEmailForm) ...[
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
                          backgroundColor: const Color.fromARGB(
                            255,
                            74,
                            24,
                            199,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Continue with Email',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _showEmailForm = false),
                        child: const Text('Back to sign-in options'),
                      ),
                    ] else if (_showPhoneForm) ...[
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
                      TextButton(
                        onPressed: () => setState(() => _showPhoneForm = false),
                        child: const Text('Back to sign-in options'),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailEntryScreen(BuildContext context) {
    final canContinue = _emailController.text.trim().contains('@');
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => setState(() => _showEmailForm = false),
                  icon: const Icon(Icons.navigate_before_ios_new, size: 18),
                  color: const Color(0xFF9A87FF),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: 72),
              const Text(
                "What's your email?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "We'll send you a 6-digit code to verify it's you.",
                style: TextStyle(color: Color(0xFF938DA1), fontSize: 14),
              ),
              const SizedBox(height: 34),
              TextField(
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'your@email.com',
                  hintStyle: const TextStyle(color: Color(0xFF746E7F)),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF9A87FF),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF15121E),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(color: Color(0xFF4A3A75)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(
                      color: Color(0xFF836EF9),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: canContinue && !_loading ? _sendEmailCode : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 74, 24, 199),
                    disabledBackgroundColor: const Color(0xFF302A41),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF746E7F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _loading ? 'Sending...' : 'Send Verification Code',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: GestureDetector(
                  onTap: _selectPhone,
                  child: const Text.rich(
                    TextSpan(
                      text: 'Prefer ',
                      style: TextStyle(color: Color(0xFF837C95), fontSize: 12),
                      children: [
                        TextSpan(
                          text: 'phone',
                          style: TextStyle(
                            color: Color(0xFFB09EFF),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(
                          text: '? Use your number instead',
                          style: TextStyle(
                            color: Color(0xFF837C95),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 150),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 0, 0, 0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF9A87FF),
                      size: 19,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your email is only used to verify your identity. We never share it.',
                        style: TextStyle(
                          color: Color(0xFF938DA1),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpScreen(BuildContext context) {
    final destination = _pendingEmail ?? _pendingPhone ?? 'your contact';
    final isEmail = _pendingEmail != null;
    final complete = _otpCode.length == 6;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => setState(() {
                    _showCodeInput = false;
                    _resendTimer?.cancel();
                  }),
                  icon: const Icon(Icons.navigate_before_ios_new, size: 18),
                  color: const Color(0xFF9A87FF),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: 72),
              const Text(
                'Check your email',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isEmail
                    ? 'We sent a 6-digit code to $destination. It expires in 10 minutes.'
                    : 'We sent a 6-digit code to $destination.',
                style: const TextStyle(
                  color: Color(0xFF938DA1),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 34),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => _OtpBox(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    onChanged: (value) => _handleOtpChanged(index, value),
                    onKey: (event) => _handleOtpKey(index, event),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: _resendSeconds > 0
                    ? Text(
                        'Resend code in 0:${_resendSeconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Color(0xFF837C95),
                          fontSize: 12,
                        ),
                      )
                    : GestureDetector(
                        onTap: _resendCode,
                        child: const Text.rich(
                          TextSpan(
                            text: "Didn't receive it? ",
                            style: TextStyle(
                              color: Color(0xFF837C95),
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: 'Resend',
                                style: TextStyle(
                                  color: Color(0xFFB09EFF),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: complete && !_loading
                      ? (isEmail ? _verifyEmailCode : _verifyPhoneCode)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 74, 24, 199),
                    disabledBackgroundColor: const Color(0xFF302A41),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _loading ? 'Verifying...' : 'Verify Code',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 150),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, color: Color(0xFF837C95), size: 15),
                  SizedBox(width: 7),
                  Text(
                    'Protected by Privy. Your key never leaves your device.',
                    style: TextStyle(color: Color(0xFF837C95), fontSize: 10),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletReadyScreen(BuildContext context) {
    final address = _address!;
    final mon = _formatMon(_monBalance);
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 38),
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 420),
                  width: _readyPulse ? 132 : 116,
                  height: _readyPulse ? 132 : 116,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9B88FF), Color(0xFF5038A7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF836EF9,
                        ).withValues(alpha: _readyPulse ? 0.5 : 0.28),
                        blurRadius: _readyPulse ? 34 : 22,
                        spreadRadius: _readyPulse ? 8 : 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 62,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Your wallet is ready',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "We've created a secure wallet for you. No seed phrase. No private key. Just your email.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF938DA1),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 34),
              _WalletAddressCard(address: address, onCopy: _copyAddress),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 0, 0, 0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MON Balance',
                      style: TextStyle(
                        color: Color(0xFF837C95),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$mon MON',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Fund your wallet to start trading',
                      style: TextStyle(color: Color(0xFF837C95), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/main'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 74, 24, 199),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue to App',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FundWalletScreen()),
                  ),
                  icon: const Icon(Icons.credit_card, size: 18),
                  label: const Text('Add Funds with Card'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB09EFF),
                    side: const BorderSide(color: Color(0xFF554A70)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMon(BigInt value) {
    final whole = value ~/ BigInt.from(10).pow(18);
    final fraction = (value % BigInt.from(10).pow(18))
        .toString()
        .padLeft(18, '0')
        .substring(0, 4);
    return '$whole.$fraction';
  }
}

class _WalletAddressCard extends StatelessWidget {
  final String address;
  final VoidCallback onCopy;

  const _WalletAddressCard({required this.address, required this.onCopy});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 0, 0, 0),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR WALLET ADDRESS',
                style: TextStyle(
                  color: Color(0xFF837C95),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 9),
              SelectableText(
                address,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onCopy,
          icon: const Icon(Icons.copy, color: Color(0xFF9A87FF), size: 19),
          tooltip: 'Copy wallet address',
        ),
      ],
    ),
  );
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(KeyEvent) onKey;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 47,
    height: 56,
    child: Focus(
      onKeyEvent: (node, event) => onKey(event),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFF15121E),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFF4A3A75)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFF836EF9), width: 2),
          ),
        ),
      ),
    ),
  );
}

class _SignInHero extends StatelessWidget {
  const _SignInHero();

  @override
  Widget build(BuildContext context) => Container(
    height: 220,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6548C4), Color(0xFF241B49)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(255, 74, 24, 199).withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          color: Colors.white,
          size: 52,
        ),
        const SizedBox(height: 14),
        const Text(
          'Welcome to Aeroreal',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create your account in seconds - no seed phrase, no private key',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    ),
  );
}

class _AuthOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlighted;
  final VoidCallback onTap;

  const _AuthOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: highlighted
              ? const Color.fromARGB(255, 74, 24, 199)
              : Colors.white,
          size: 22,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: highlighted ? const Color(0xFF171320) : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: highlighted
              ? Colors.white
              : const Color.fromARGB(255, 0, 0, 0),
          side: BorderSide(
            color: highlighted
                ? const Color.fromARGB(255, 74, 24, 199)
                : const Color(0xFF30283F),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    ),
  );
}

class _AerorealMark extends StatelessWidget {
  const _AerorealMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 104,
    height: 104,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color.fromARGB(255, 74, 24, 199).withValues(alpha: 0.12),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(255, 74, 24, 199).withValues(alpha: 0.5),
          blurRadius: 34,
          spreadRadius: 6,
        ),
      ],
    ),
    child: const Icon(Icons.water_drop, color: Color(0xFF9A87FF), size: 70),
  );
}

class _WelcomeBackdrop extends StatelessWidget {
  const _WelcomeBackdrop();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        Positioned(
          top: 80,
          left: -80,
          child: Container(
            width: 270,
            height: 270,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color.fromARGB(
                255,
                74,
                24,
                199,
              ).withValues(alpha: 0.08),
            ),
          ),
        ),
        Positioned(
          top: 190,
          right: -35,
          child: Icon(
            Icons.water_drop_outlined,
            size: 110,
            color: const Color.fromARGB(
              255,
              74,
              24,
              199,
            ).withValues(alpha: 0.045),
          ),
        ),
        Positioned(
          bottom: 150,
          left: 14,
          child: Icon(
            Icons.hexagon_outlined,
            size: 66,
            color: const Color(0xFF00D18A).withValues(alpha: 0.035),
          ),
        ),
        Positioned(
          bottom: 270,
          right: 26,
          child: Icon(
            Icons.circle_outlined,
            size: 36,
            color: const Color(0xFF9A87FF).withValues(alpha: 0.05),
          ),
        ),
      ],
    ),
  );
}
