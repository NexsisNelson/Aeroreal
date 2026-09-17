import 'package:flutter/material.dart';

import 'agent_api_screen.dart';
import 'fractionalize_screen.dart';
import 'settings_screen.dart';
import 'tx_history_screen.dart';
import 'yield_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          _MoreTile(
            icon: Icons.add_circle_outline,
            title: 'Create',
            subtitle: 'Fractionalize an asset or create a vault',
            onTap: () => _open(context, const FractionalizeScreen()),
          ),
          _MoreTile(
            icon: Icons.water_drop_outlined,
            title: 'Yield',
            subtitle: 'Stake fractions and track earned yield',
            onTap: () => _open(context, const YieldScreen()),
          ),
          _MoreTile(
            icon: Icons.smart_toy_outlined,
            title: 'Agent',
            subtitle: 'Inspect the Aeroreal agent API',
            onTap: () => _open(context, const AgentApiScreen()),
          ),
          _MoreTile(
            icon: Icons.history,
            title: 'Transaction History',
            subtitle: 'Review on-chain actions and receipts',
            onTap: () => _open(context, const TxHistoryScreen()),
          ),
          const Divider(height: 1),
          _MoreTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Identity, wallet, and account preferences',
            onTap: () => _open(context, const SettingsScreen()),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Icon(icon, color: const Color(0xFF836EF9)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
