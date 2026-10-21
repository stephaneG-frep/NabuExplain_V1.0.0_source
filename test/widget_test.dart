import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nabu_explain/main.dart';

void main() {
  testWidgets('App starts and shows onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NabuExplainApp()));
    await tester.pumpAndSettle();

    // Onboarding first screen should be visible
    expect(find.text('Tu ne comprends pas quelque chose ?'), findsOneWidget);
  });
}