import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('material app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Expat8'),
        ),
      ),
    );

    expect(find.text('Expat8'), findsOneWidget);
  });
}
