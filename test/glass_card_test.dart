// test/glass_card_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_learning_application/widgets/glass_card.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('GlassCard renders child', (WidgetTester tester) async {
    const child = Text('Hello');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassCard(child: child),
        ),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
  });
}
