// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_flutter/main.dart';
import 'package:mnd_flutter/providers/auth_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App starts and shows home screen smoke test', (WidgetTester tester) async {
    // This test replaces the old counter test.
    // It verifies that the app builds and the main screen is displayed.

    // The app needs an AuthProvider to be available in the widget tree.
    // We provide one here for the test environment.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: MyApp(),
      ),
    );

    // The app should build without crashing. Now, we verify that the
    // initial screen (HomeScreen) is showing the correct title.
    // We might need to wait for the UI to settle, especially if there
    // are async operations in initState.
    await tester.pumpAndSettle();

    // Verify that the AppBar title of the HomeScreen is visible.
    expect(find.text('MND - Route Planner'), findsOneWidget);

    // Verify that one of the bottom navigation bar items is present.
    expect(find.text('Routes'), findsOneWidget);
  });
}
