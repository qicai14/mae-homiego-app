import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:homiego/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('System Test 02: Homeowner Dashboard & Add Listing', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    print('--- 02. START: Homeowner Test ---');

    // 1. Login as Homeowner
    await tester.enterText(find.byType(TextFormField).at(0), 'qicailim1114@gmail.com'); 
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // 2. Verify Homeowner Dashboard
    // Look for unique Host widgets like "My Listings" or specific FAB
    expect(find.text('My Listings'), findsOneWidget); 
    print('Success: Homeowner Dashboard Loaded');

    // 3. Check "Add Listing" Navigation
    final addBtn = find.byIcon(Icons.add);
    if (addBtn.evaluate().isNotEmpty) {
       await tester.tap(addBtn);
       await tester.pumpAndSettle();
       expect(find.textContaining('Listing'), findsOneWidget); // Verify Screen Title
       await tester.pageBack();
       await tester.pumpAndSettle();
    }

    print('--- 02. END: Homeowner Test Passed ---');
  });
}