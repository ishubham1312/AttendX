import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendx/widgets/progress_bar.dart';

void main() {
  testWidgets('GradientProgressBar renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: GradientProgressBar(value: 0.5),
          ),
        ),
      ),
    );
    expect(find.byType(GradientProgressBar), findsOneWidget);
  });
}
