import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/services/theme_provider.dart';

void main() {
  testWidgets('Darbar app launches with splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppStateProvider(),
        child: const DarbarApp(),
      ),
    );

    // Verify splash screen elements
    expect(find.text('Darbar'), findsOneWidget);
    expect(find.text('AI-Powered Service Finder'), findsOneWidget);
  });
}
