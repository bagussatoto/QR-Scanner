// test/widget_test.dart
// -------------------------------------------------------------------
// Smoke test ensuring HomePage and core UI widgets compile and render.
// -------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterqrscan/main.dart';

void main() {
  testWidgets('HomePage renders core navigation and scanner controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(),
      ),
    );

    expect(find.text('QR Scanner'), findsOneWidget);
    expect(find.text('Scan Kamera'), findsOneWidget);
    expect(find.text('Mode Batch'), findsOneWidget);
    expect(find.text('Statistik'), findsOneWidget);
  });
}
