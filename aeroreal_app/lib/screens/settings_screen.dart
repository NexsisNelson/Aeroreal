// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import '../utils/app_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../config/routes.dart';
import '../services/privy_service.dart';
import '../services/notification_service.dart';
import '../services/wallet_service.dart';
import 'agent_api_screen.dart';
import 'kyc/kyc_intro_screen.dart';
import 'notifications_screen.dart';
import 'preferences_screen.dart';
import 'traction_screen.dart';
import 'tx_history_screen.dart';

// UI/UX: Controls the account/settings hierarchy, wallet profile card,
// navigation rows, support links, and sign-out confirmation flow.
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
    final walletAddress = context.watch<PrivyService>().walletAddress;
    final shortAddress = walletAddress == null || walletAddress.length < 10
        ? '0x50b3...F2e7'
        : '${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}';
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        elevation: 0,
        leading: IconButton(
          icon: const AppIcon(AppIcons.arrowBackIosRounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const SizedBox(height: 8),
            _ProfileCard(
              address: shortAddress,
              onCopy: walletAddress == null
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: walletAddress),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Wallet address copied'),
                          ),
                        );
                      }
                    },
            ),
            const SizedBox(height: 26),
            _sectionLabel('ACCOUNT'),
            _SettingsGroup(
              items: [
                _SettingsItem(
                  AppIcons.shieldOutlined,
                  'Verify Identity',
                  'Demo KYC flow for RWA tokens',
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const KycIntroScreen(),
                      ),
                    );
                  },
                ),
                _SettingsItem(
                  AppIcons.accountBalanceWalletOutlined,
                  'Linked Wallets',
                  '2 wallets connected',
                  () {},
                ),
                _SettingsItem(
                  AppIcons.lockOutline,
                  'Security',
                  'Biometrics, PIN',
                  () {},
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionLabel('ACTIVITY'),
            _SettingsGroup(
              items: [
                _SettingsItem(
                  AppIcons.receiptLongOutlined,
                  'Transaction History',
                  'See all your on-chain actions',
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TxHistoryScreen()),
                  ),
                ),
                _SettingsItem(
                  AppIcons.analyticsOutlined,
                  'Traction Dashboard',
                  '24 total transactions',
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TractionScreen()),
                  ),
                ),
                _SettingsItem(
                  AppIcons.notificationsNone,
                  'Notifications',
                  '3 unread',
                  () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
                _SettingsItem(
                  AppIcons.tune,
                  'Preferences',
                  'Currency, notifications, privacy',
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PreferencesScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionLabel('NETWORK'),
            _SettingsGroup(
              items: [
                _SettingsItem(
                  AppIcons.smartToyOutlined,
                  'Agent API',
                  'Inspect the Aeroreal agent API',
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AgentApiScreen()),
                  ),
                ),
                _SettingsItem(AppIcons.public, 'Network', 'Monad Testnet', () {}),
                _SettingsItem(
                  AppIcons.dnsOutlined,
                  'RPC Endpoint',
                  'thirdweb.com',
                  () {},
                ),
                _SettingsItem(
                  AppIcons.storageOutlined,
                  'Data Sources',
                  'CoinGecko, Chainlink, CMC',
                  () {},
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionLabel('SUPPORT'),
            _SettingsGroup(
              items: [
                _SettingsItem(
                  AppIcons.helpOutline,
                  'Help Center',
                  'Guides and frequently asked questions',
                  () {},
                ),
                _SettingsItem(
                  AppIcons.mailOutline,
                  'Contact Us',
                  'Reach the Aeroreal team',
                  () {},
                ),
                _SettingsItem(
                  AppIcons.descriptionOutlined,
                  'Terms & Privacy',
                  'Legal and privacy information',
                  () {},
                ),
              ],
            ),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _handleSignOut(context),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Color(0xFFFF6B7A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'v1.0.0 (build 42)',
                style: TextStyle(color: Color(0xFF746B83), fontSize: 11),
              ),
            ),
          ],
        ),
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
}

class _ProfileCard extends StatelessWidget {
  final String address;
  final VoidCallback? onCopy;

  const _ProfileCard({required this.address, required this.onCopy});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF5C43B3), Color(0xFF21183F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(255, 74, 24, 199).withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF836EF9),
            shape: BoxShape.circle,
          ),
          child: const Text(
            'N',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Flexible(
                    child: Text(
                      'nexsisnelson@gmail.com',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00D18A),
                      shape: BoxShape.circle,
                    ),
                    child: const AppIcon(
                      AppIcons.check,
                      size: 11,
                      color: Color(0xFF071711),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      address,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onCopy,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const AppIcon(
                      AppIcons.copy,
                      color: Colors.white70,
                      size: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsItem {
  final FaIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem(this.icon, this.title, this.subtitle, this.onTap);
}

class _SettingsGroup extends StatelessWidget {
  final List<_SettingsItem> items;

  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color.fromARGB(255, 0, 0, 0),
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: items
          .map(
            (item) => _SettingsRow(item: item, showDivider: item != items.last),
          )
          .toList(),
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  final _SettingsItem item;
  final bool showDivider;

  const _SettingsRow({required this.item, required this.showDivider});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        leading: AppIcon(item.icon, color: const Color(0xFF9A87FF), size: 21),
        title: Text(
          item.title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          item.subtitle,
          style: const TextStyle(color: Color(0xFF837C95), fontSize: 11),
        ),
        trailing: item.title == 'Notifications'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5364),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '3',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  const AppIcon(AppIcons.chevronRight, color: Color(0xFF746B83)),
                ],
              )
            : const AppIcon(AppIcons.chevronRight, color: Color(0xFF746B83)),
        onTap: item.onTap,
      ),
      if (showDivider)
        const Divider(
          height: 1,
          indent: 54,
          endIndent: 14,
          color: Color(0x1FFFFFFF),
        ),
    ],
  );
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
      leading: const AppIcon(
        AppIcons.notificationsOutlined,
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
          : const AppIcon(AppIcons.chevronRight),
      onTap: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        _loadCount();
      },
    );
  }
}
