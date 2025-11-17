import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:homiego/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('System Test 01: Auth Validation (Error Handling & Logout)', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    print('--- 01. START: Auth Flow Test ---');

    // 1. Try Invalid Login (Validation Test)
    print('Step: Testing Invalid Credentials');
    await tester.enterText(find.byType(TextFormField).at(0), 'fake@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify Error (Look for Snackbars or Error Text)
    // Note: Adjust string to match your actual error message
    expect(find.byType(SnackBar), findsOneWidget); 
    print('Success: Invalid Login blocked.');

    // 2. Login as Tenant (Valid)
    print('Step: Testing Valid Tenant Login');
    await tester.enterText(find.byType(TextFormField).at(0), 'leeaikyen@gmail.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'lee123'); 
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // 3. Verify Home & Logout
    expect(find.byIcon(Icons.home), findsOneWidget);
    
    // Go to Profile -> Logout
    await tester.tap(find.byIcon(Icons.person_outline)); // Account Tab
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    
    // Confirm Logout Dialog
    if (find.text('Confirm').evaluate().isNotEmpty) {
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Login'), findsOneWidget);
    print('--- 01. END: Auth Flow Passed ---');
  });
}