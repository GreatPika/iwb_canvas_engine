import 'package:flutter_test/flutter_test.dart';

import 'interactive_false_surface_test_support.dart';

void main() {
  testWidgets('interactive false cancels only the active routed session', (
    tester,
  ) async {
    await expectInteractiveFalseActiveSessionCancel(tester);
    expect(tester.takeException(), isNull);
  });
}
