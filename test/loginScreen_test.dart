import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/login_screen.dart';

void main() {
  group('LoginScreen Widget Tests', () {
    testWidgets('Renders title, email field, password field, and Sign In button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      expect(find.text('POS Cashier Login'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('Shows validation errors when submitting empty or invalid inputs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      // Tap Sign In with empty fields
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );

      // Enter invalid email & short password, then re-submit
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'cashier.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    });

    testWidgets('Toggles password visibility when eye icon is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      // Initially obscured (visibility icon shown)
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsNothing);

      // Tap the eye icon to reveal password
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('Calls login handler with trimmed credentials when form is valid',
        (WidgetTester tester) async {
      String? submittedEmail;
      String? submittedPassword;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onLogin: (email, password) async {
              submittedEmail = email;
              submittedPassword = password;
            },
          ),
        ),
      );

      // Arrange: enter valid credentials with extra spaces
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        '  cashier@shop.com  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret123',
      );

      // Act: tap Sign In
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Assert: validation errors are absent and trimmed values were passed
      expect(find.text('Enter a valid email'), findsNothing);
      expect(
        find.text('Password must be at least 6 characters'),
        findsNothing,
      );
      expect(submittedEmail, 'cashier@shop.com');
      expect(submittedPassword, 'secret123');
    });
  });
}