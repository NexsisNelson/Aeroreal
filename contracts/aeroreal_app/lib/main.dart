// lib/main.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'services/wallet_service.dart';
import 'services/contract_service.dart';
import 'services/privy_service.dart';
import 'services/notification_service.dart';
import 'services/user_profile_service.dart';
import 'config/routes.dart';
import 'screens/main_shell.dart';
import 'screens/wallet_onboarding_screen.dart';

Future<void> main() async {
  // Flutter must be ready before plugins such as dotenv and notifications
  // can be initialized from the platform-specific runners.
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await NotificationService().initialize();

  // Privy supplies embedded-wallet functionality on native platforms. The
  // web build skips it because its native initialization is not available.
  final privyService = PrivyService(
    appId: dotenv.env['PRIVY_APP_ID'],
    clientId: dotenv.env['PRIVY_CLIENT_ID'],
  );

  if (!kIsWeb) {
    await privyService.initialize();
  } else {
    debugPrint('PrivyService skipped on Web target.');
  }

  // Restore the locally managed wallet before the widget tree is created so
  // the first screen can immediately reflect the current wallet state.
  final walletService = WalletService();
  await walletService.loadWallet();
  final userProfileService = UserProfileService();
  final initialAddress = privyService.walletAddress;

  // Providers make the shared services available to screens without passing
  // them through every widget constructor.
  runApp(
    MultiProvider(
      providers: [
        Provider<PrivyService>.value(value: privyService),
        ChangeNotifierProvider<WalletService>.value(value: walletService),
        ChangeNotifierProvider<UserProfileService>.value(
          value: userProfileService,
        ),
        ChangeNotifierProvider<ContractService>(
          create: (_) => ContractService(privyService),
        ),
      ],
      child: const AerorealApp(),
    ),
  );

  if (initialAddress != null) {
    unawaited(userProfileService.load(initialAddress));
  }
}

class AerorealApp extends StatelessWidget {
  const AerorealApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Keep routing centralized here so onboarding and the main shell use the
    // same route names throughout the application.
    return MaterialApp(
      title: 'Aeroreal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color.fromARGB(255, 0, 0, 0),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF836EF9),
          secondary: Color.fromARGB(255, 209, 94, 0),
          surface: Color.fromARGB(255, 0, 0, 0),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 0, 0, 0),
          elevation: 0,
        ),
      ),
      initialRoute: context.read<PrivyService>().isAuthenticated
          ? AppRoutes.main
          : AppRoutes.onboarding,
      routes: {
        AppRoutes.onboarding: (_) => const WalletOnboardingScreen(),
        AppRoutes.main: (_) => const MainShell(),
      },
    );
  }
}
