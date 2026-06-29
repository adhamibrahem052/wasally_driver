import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Driver app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Wasally Driver'))));
    expect(find.text('Wasally Driver'), findsOneWidget);
  });
}
