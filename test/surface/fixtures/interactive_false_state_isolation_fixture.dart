import 'package:flutter_test/flutter_test.dart';

import 'interactive_false_surface_test_support.dart';

void main() {
  testWidgets('interactive false cleanup isolates runtime state', (
    tester,
  ) async {
    await expectInteractiveFalseStateIsolation(tester);
    expect(tester.takeException(), isNull);
  });
}
