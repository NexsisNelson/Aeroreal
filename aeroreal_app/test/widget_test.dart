// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aeroreal_app/main.dart';
import 'package:aeroreal_app/services/wallet_service.dart';

void main() {
  testWidgets('shows wallet onboarding actions', (WidgetTester tester) async {
    final walletService = WalletService();

    await tester.pumpWidget(
      ChangeNotifierProvider<WalletService>.value(
        value: walletService,
        child: const AerorealApp(),
      ),
    );

    expect(find.text('Aeroreal'), findsOneWidget);
    expect(find.text('Generate New Wallet'), findsOneWidget);
    expect(find.text('Import Wallet'), findsOneWidget);
  });
}
