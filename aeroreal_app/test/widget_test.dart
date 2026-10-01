// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aeroreal_app/config/constants.dart';
import 'package:aeroreal_app/config/simulated_assets.dart';
import 'package:aeroreal_app/config/simulated_nft_collections.dart';
import 'package:aeroreal_app/screens/rwa_detail_screen.dart';
import 'package:aeroreal_app/screens/wallet_onboarding_screen.dart';
import 'package:aeroreal_app/services/contract_service.dart';
import 'package:aeroreal_app/services/privy_service.dart';
import 'package:aeroreal_app/services/user_profile_service.dart';
import 'package:aeroreal_app/services/wallet_service.dart';
import 'package:aeroreal_app/utils/app_icons.dart';
import 'package:aeroreal_app/utils/transaction_feedback.dart';

void main() {
  test('maps supported symbols to deployed simulated assets', () {
    expect(SimulatedAssets.hasSimulated('btc'), isTrue);
    expect(SimulatedAssets.hasSimulated('paxg'), isTrue);
    expect(SimulatedAssets.hasSimulated('CCF'), isTrue);
    expect(SimulatedAssets.contractFor('BTC'), AppConstants.simulatedBtc);
    expect(SimulatedAssets.tokenSymbolFor('XAU'), 'sGOLD');
  });

  test('exposes simulated holdings from the user profile', () {
    final profile = UserProfileService();
    expect(profile.simulatedHoldings, isEmpty);
    expect(profile.simulatedNfts, isEmpty);
  });

  test('maps NFT collections to deployed simulated collections', () {
    expect(
      SimulatedNftCollections.contractFor(
        SimulatedNftCollections.symbolFor('CryptoPunks', 'PUNK'),
      ),
      AppConstants.simulatedPunks,
    );
    expect(
      SimulatedNftCollections.contractFor(
        SimulatedNftCollections.symbolFor('Doodles', 'DOODLE'),
      ),
      AppConstants.simulatedDoodles,
    );
    expect(
      SimulatedNftCollections.contractFor('unmatched'),
      AppConstants.simulatedBayc,
    );
  });

  test('classifies connection failures separately from transaction errors', () {
    expect(
      TransactionFeedback.isConnectionIssue(TimeoutException('offline')),
      isTrue,
    );
    expect(
      TransactionFeedback.isConnectionIssue(
        Exception('SocketException: offline'),
      ),
      isTrue,
    );
    expect(
      TransactionFeedback.isConnectionIssue(Exception('execution reverted')),
      isFalse,
    );
  });

  testWidgets('Font Awesome icons fit a stable square slot', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppIcon(AppIcons.swapHoriz, size: 24)),
      ),
    );

    expect(tester.getSize(find.byType(AppIcon)), const Size(24, 24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows wallet onboarding actions', (WidgetTester tester) async {
    final walletService = WalletService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PrivyService>(create: (_) => PrivyService()),
          ChangeNotifierProvider<ContractService>(
            create: (context) => ContractService(context.read<PrivyService>()),
          ),
          ChangeNotifierProvider<WalletService>.value(value: walletService),
        ],
        child: const MaterialApp(home: WalletOnboardingScreen()),
      ),
    );

    expect(find.text('Aeroreal'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(find.text('Continue with Phone'), findsOneWidget);
  });

  testWidgets('renders the live asset metadata on the detail page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PrivyService>(create: (_) => PrivyService()),
          ChangeNotifierProvider<UserProfileService>(
            create: (_) => UserProfileService(),
          ),
          ChangeNotifierProvider<ContractService>(
            create: (context) => ContractService(context.read<PrivyService>()),
          ),
        ],
        child: MaterialApp(
          home: RwaDetailScreen(
            asset: {
              'id': 'unitas-gold',
              'rwa_slug': 'unitas-gold',
              'name': 'Unitas Gold',
              'symbol': 'XGLD',
              'asset_type': 'tokenized_asset',
              'price_usd': 4398.58,
              'percent_change_24h': 1.24,
              'market_cap_usd': 1048092.0,
              'volume_24h_usd': 661322.0,
              'circulating_supply': 1000000.0,
              'all_time_high': 4512.3,
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Unitas Gold'), findsOneWidget);
    expect(find.text('XGLD'), findsOneWidget);
    expect(find.text('\$4,398.58'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Risk Disclosure'),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Risk Disclosure'), findsOneWidget);
  });

  testWidgets('shows simulated purchase controls for any asset', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PrivyService>(create: (_) => PrivyService()),
          ChangeNotifierProvider<UserProfileService>(
            create: (_) => UserProfileService(),
          ),
          ChangeNotifierProvider<ContractService>(
            create: (context) => ContractService(context.read<PrivyService>()),
          ),
        ],
        child: MaterialApp(
          home: RwaDetailScreen(
            asset: {
              'id': 'dogecoin',
              'name': 'Dogecoin',
              'symbol': 'DOGE',
              'price_usd': 0.19,
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Buy DOGE'),
      400,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Simulated DOGE'), findsOneWidget);
    expect(find.text('Buy DOGE'), findsOneWidget);

    await tester.ensureVisible(find.text('Buy DOGE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy DOGE'));
    await tester.pumpAndSettle();
    expect(find.text('Amount (DOGE)'), findsOneWidget);
    expect(find.text('Review buy'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
