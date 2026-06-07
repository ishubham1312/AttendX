import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/widgets/shield_logo.dart';

void main() {
  testWidgets('ShieldLogo renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: ShieldLogo())),
      ),
    );
    expect(find.byType(ShieldLogo), findsOneWidget);
  });
}
