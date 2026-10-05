import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user_profile_service.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  String _currency = 'USD';
  bool _notifications = true;
  bool _hideBalances = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final preferences = context.read<UserProfileService>().preferences;
    _currency = preferences['currency'] as String? ?? 'USD';
    _notifications = preferences['notifications'] as bool? ?? true;
    _hideBalances = preferences['hideBalances'] as bool? ?? false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<UserProfileService>().update(
      preferences: {
        'currency': _currency,
        'notifications': _notifications,
        'hideBalances': _hideBalances,
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preferences saved'),
        backgroundColor: Color(0xFF00D18A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionLabel('CURRENCY'),
          _surface(
            DropdownButton<String>(
              value: _currency,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1625),
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'USD', child: Text('USD - US Dollar')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
                DropdownMenuItem(
                  value: 'GBP',
                  child: Text('GBP - British Pound'),
                ),
                DropdownMenuItem(
                  value: 'NGN',
                  child: Text('NGN - Nigerian Naira'),
                ),
                DropdownMenuItem(
                  value: 'KES',
                  child: Text('KES - Kenyan Shilling'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _currency = value);
              },
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('NOTIFICATIONS'),
          _surface(
            SwitchListTile(
              value: _notifications,
              onChanged: (value) => setState(() => _notifications = value),
              title: const Text('Enable notifications'),
              subtitle: const Text(
                'Transaction confirmations, yield alerts, price movements',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              activeThumbColor: const Color(0xFF836EF9),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('PRIVACY'),
          _surface(
            SwitchListTile(
              value: _hideBalances,
              onChanged: (value) => setState(() => _hideBalances = value),
              title: const Text('Hide balances'),
              subtitle: const Text(
                'Replace portfolio values with hidden placeholders',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              activeThumbColor: const Color(0xFF836EF9),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 40),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF836EF9),
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Preferences'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 9),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF837C95),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _surface(Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF15121E),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: child,
  );
}
