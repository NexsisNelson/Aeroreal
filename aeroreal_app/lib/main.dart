// lib/main.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'services/wallet_service.dart';
import 'services/contract_service.dart';
import 'services/privy_service.dart';
import 'services/notification_service.dart';
import 'config/routes.dart';
import 'screens/main_shell.dart';
import 'screens/wallet_onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await NotificationService().initialize();

  final privyService = PrivyService(
    appId: dotenv.env['PRIVY_APP_ID'],
    clientId: dotenv.env['PRIVY_CLIENT_ID'],
  );

  if (!kIsWeb) {
    await privyService.initialize();
  } else {
    debugPrint('PrivyService skipped on Web target.');
  }

  final walletService = WalletService();
  await walletService.loadWallet();

  runApp(
    MultiProvider(
      providers: [
        Provider<PrivyService>.value(value: privyService),
        ChangeNotifierProvider<WalletService>.value(value: walletService),
        Provider<ContractService>(create: (_) => ContractService(privyService)),
      ],
      child: const AerorealApp(),
    ),
  );
}

class AerorealApp extends StatelessWidget {
  const AerorealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aeroreal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0B14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF836EF9),
          secondary: Color(0xFF00D18A),
          surface: Color(0xFF1A1625),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0B14),
          elevation: 0,
        ),
      ),
      initialRoute: AppRoutes.main,
      routes: {
        AppRoutes.onboarding: (_) => const WalletOnboardingScreen(),
        AppRoutes.main: (_) => const MainShell(),
      },
    );
  }
}
