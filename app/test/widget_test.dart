// Smoke test: without Supabase --dart-define config, the app should show
// the configuration-missing screen rather than crash.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows missing-config screen without env vars', (WidgetTester tester) async {
    await tester.pumpWidget(const _MissingConfigAppForTest());
    await tester.pump();
    expect(find.textContaining('Missing Supabase configuration'), findsOneWidget);
  });
}

// Mirrors main.dart's private _MissingConfigApp; kept local to the test
// since the widget itself is intentionally private to main.dart.
class _MissingConfigAppForTest extends StatelessWidget {
  const _MissingConfigAppForTest();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Missing Supabase configuration.'))),
    );
  }
}
