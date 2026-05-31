import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  test('selected move repaint guardrail is runner-backed', () async {
    expect(
      await guardrailIsRunnerBacked(
        id: 'preview.selected_move_main_repaint',
        suites: {'blocking', 'preview'},
        proofPaths: [
          'test/guardrails/preview_selected_move_main_repaint_guardrail_test.dart',
        ],
      ),
      isTrue,
    );
  });

  test('selected move and overlay repaint routing fixture passes', () async {
    await expectLater(
      runFlutterInPackageTest(
        'test/frame/fixtures/repaint_bus_output_fixture.dart',
      ),
      completes,
    );
  });
}
