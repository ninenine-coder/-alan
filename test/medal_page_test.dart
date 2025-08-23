import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/medal_page.dart';

void main() {
  group('MedalPage Tests', () {
    testWidgets('MedalPage should build without errors', (
      WidgetTester tester,
    ) async {
      // Build the MedalPage widget
      await tester.pumpWidget(const MaterialApp(home: MedalPage()));

      // Verify that the page builds successfully
      expect(find.byType(MedalPage), findsOneWidget);
    });

    testWidgets('MedalPage should display title', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: MedalPage()));

      // Verify that the title is displayed
      expect(find.text('徽章收藏'), findsOneWidget);
    });

    testWidgets('MedalPage should display filter options', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: MedalPage()));

      // Verify that filter options are displayed
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('已獲得'), findsOneWidget);
      expect(find.text('未獲得'), findsOneWidget);
    });

    testWidgets('MedalPage should have back button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: MedalPage()));

      // Verify that back button is present
      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
    });
  });
}
