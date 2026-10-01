import 'package:flutter/material.dart';
import '../utils/app_icons.dart';

import 'agent_api_screen.dart';
import 'fractionalize_screen.dart';
import 'settings_screen.dart';
import 'tx_history_screen.dart';
import 'yield_screen.dart';

// UI/UX: Controls the secondary navigation list and the destinations exposed
// outside the primary bottom navigation tabs.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          _MoreTile(
            icon: AppIcons.addCircleOutline,
            title: 'Create',
            subtitle: 'Fractionalize an asset or create a vault',
            onTap: () => _open(context, const FractionalizeScreen()),
          ),
          _MoreTile(
            icon: AppIcons.waterDropOutlined,
            title: 'Yield',
            subtitle: 'Stake fractions and track earned yield',
            onTap: () => _open(context, const YieldScreen()),
          ),
          _MoreTile(
            icon: AppIcons.smartToyOutlined,
            title: 'Agent',
            subtitle: 'Inspect the Aeroreal agent API',
            onTap: () => _open(context, const AgentApiScreen()),
          ),
          _MoreTile(
            icon: AppIcons.history,
            title: 'Transaction History',
            subtitle: 'Review on-chain actions and receipts',
            onTap: () => _open(context, const TxHistoryScreen()),
          ),
          const Divider(height: 1),
          _MoreTile(
            icon: AppIcons.settingsOutlined,
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
  final FaIconData icon;
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
      leading: AppIcon(icon, color: const Color.fromARGB(255, 74, 24, 199)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const AppIcon(AppIcons.chevronRight),
      onTap: onTap,
    );
  }
}
