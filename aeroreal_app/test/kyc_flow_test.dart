import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aeroreal_app/screens/kyc/kyc_camera_screen.dart';
import 'package:aeroreal_app/screens/kyc/kyc_document_screen.dart';
import 'package:aeroreal_app/screens/kyc/kyc_intro_screen.dart';

void main() {
  testWidgets('intro opens document selection and camera guidance', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: KycIntroScreen()));

    expect(find.text('Identity verification'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Begin verification'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Begin verification'));
    await tester.pumpAndSettle();

    expect(find.byType(KycDocumentScreen), findsOneWidget);
    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue to camera'),
    );
    expect(continueButton.onPressed, isNull);
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to camera'));
    await tester.pumpAndSettle();

    expect(find.byType(KycCameraScreen), findsOneWidget);
    expect(find.text('Capture your document'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
