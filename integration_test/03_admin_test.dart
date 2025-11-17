import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:homiego/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('System Test 03: Admin Routing & Fraud Dashboard', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    print('--- 03. START: Admin Test ---');

    // 1. Login as Admin
    await tester.enterText(find.byType(TextFormField).at(0), 'melvinmelvin2310@gmail.com'); // Ensure user exists
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // 2. Verify Admin Specifics
    // Admin dashboard usually has "Fraud Alert" or "Manage Users"
    expect(find.text('Fraud Alert'), findsOneWidget);
    
    // 3. Enter a Module
    await tester.tap(find.text('Fraud Alert'));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget); // Should list flags

    print('--- 03. END: Admin Test Passed ---');
  });
}