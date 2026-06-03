import 'package:flutter_test/flutter_test.dart';

import 'interactive_false_surface_test_support.dart';

void main() {
  testWidgets('interactive false routes no Flutter pointer events', (
    tester,
  ) async {
    await expectInteractiveFalsePointerRouting(tester);
    expect(tester.takeException(), isNull);
  });
}
