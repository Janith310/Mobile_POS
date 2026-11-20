// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/db_helper.dart';

void main() {
  testWidgets('Entering new product and updates total', (WidgetTester tester) async {

    final testProducts=[
      Product(id:1, code:'101', name:'Break Oil', price:1450.00),
      Product(id:2, code:'102', name:'Power Steering Fluid', price: 1350.00)
    ];
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const MaterialApp(
        home: BillingScreen(),
    ));

    // Verify that our counter starts at 0.
    expect(find.text('0.00'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.enterText(find.byType(TextField),'101');
    await tester.tap(find.text('add'));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0.00'), findsNothing);
    expect(find.text('2800.00'), findsOneWidget);
  });
}
