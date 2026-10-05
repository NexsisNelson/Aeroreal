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

import 'package:aeroreal_app/screens/rwa_detail_screen.dart';
import 'package:aeroreal_app/screens/wallet_onboarding_screen.dart';
import 'package:aeroreal_app/services/contract_service.dart';
import 'package:aeroreal_app/services/privy_service.dart';
import 'package:aeroreal_app/services/wallet_service.dart';
import 'package:aeroreal_app/utils/transaction_feedback.dart';

void main() {
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

  testWidgets('shows wallet onboarding actions', (WidgetTester tester) async {
    final walletService = WalletService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PrivyService>(create: (_) => PrivyService()),
          ProxyProvider<PrivyService, ContractService>(
            update: (context, privy, previous) => ContractService(privy),
          ),
          ChangeNotifierProvider<WalletService>.value(value: walletService),
        ],
        child: const MaterialApp(home: WalletOnboardingScreen()),
      ),
    );

    expect(find.text('Aeroreal'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(find.text('Continue with Phone'), findsOneWidget);
  });

  testWidgets('renders the live asset metadata on the detail page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
}
