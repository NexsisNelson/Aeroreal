// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/routes.dart';
import '../services/privy_service.dart';
import '../services/notification_service.dart';
import '../services/wallet_service.dart';
import 'kyc_screen.dart';
import 'notifications_screen.dart';
import 'tx_history_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _handleSignOut(BuildContext context) async {
    final privy = context.read<PrivyService>();
    final wallet = context.read<WalletService>();

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text(
          'This will disconnect your Privy session and clear your saved wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) return;

    try {
      await privy.logout();
      await wallet.deleteWallet();
    } catch (_) {
      // continue to clear navigation even if logout fails halfway
    }

    if (!context.mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.onboarding, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.verified_user, color: Color(0xFF836EF9)),
            title: const Text('Verify Identity'),
            subtitle: const Text('Required to hold RWA tokens'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const KycScreen()));
            },
          ),
          const Divider(height: 1),
          const _NotificationTile(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.history, color: Color(0xFF836EF9)),
            title: const Text('Transaction History'),
            subtitle: const Text('See your on-chain actions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TxHistoryScreen())),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.account_balance_wallet_outlined),
            title: Text('Wallet'),
            subtitle: Text('Embedded wallet management'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFFF7A7A)),
            title: const Text('Sign out'),
            subtitle: const Text(
              'Disconnect from Privy and return to onboarding',
            ),
            onTap: () => _handleSignOut(context),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile();

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final count = await NotificationService().getUnreadCount();
    if (!mounted) return;
    setState(() => _unread = count);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.notifications_outlined,
        color: Color(0xFF836EF9),
      ),
      title: const Text('Notifications'),
      subtitle: Text(_unread > 0 ? '$_unread unread' : 'No new notifications'),
      trailing: _unread > 0
          ? Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: Text('$_unread', style: const TextStyle(fontSize: 10)),
            )
          : const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        _loadCount();
      },
    );
  }
}
