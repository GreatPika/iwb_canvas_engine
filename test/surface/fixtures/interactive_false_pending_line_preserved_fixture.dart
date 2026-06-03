import 'package:flutter_test/flutter_test.dart';

import 'interactive_false_surface_test_support.dart';

void main() {
  testWidgets('interactive false preserves non-owned pending line state', (
    tester,
  ) async {
    await expectInteractiveFalsePendingLinePreserved(tester);
    expect(tester.takeException(), isNull);
  });
}
