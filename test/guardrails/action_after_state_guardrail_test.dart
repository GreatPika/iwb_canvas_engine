import 'package:test/test.dart';

import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  test('commands action guardrail is runner-backed', () async {
    expect(
      await guardrailIsRunnerBacked(
        id: 'events.commands_emit_user_actions',
        suites: {'blocking', 'events'},
        proofPaths: [
          'test/interaction/commands_emit_user_actions_test.dart',
          'test/api/typed_action_payloads_test.dart',
          'test/guardrails/action_after_state_guardrail_test.dart',
        ],
      ),
      isTrue,
    );
  });

  test('action-after-state guardrail rejects inverted fixture order', () {
    expect(_actionAfterStateViolations(_badFixtureEvents), [
      'action selectMarquee emitted before accepted public state',
    ]);
  });

  test('action-after-state guardrail accepts state-first fixture order', () {
    expect(_actionAfterStateViolations(_goodFixtureEvents), isEmpty);
  });
}

List<String> _actionAfterStateViolations(List<String> events) {
  var acceptedStatePublished = false;
  final violations = <String>[];

  for (final event in events) {
    if (event == 'accepted-public-state') {
      acceptedStatePublished = true;
    }
    if (event.startsWith('action:') && !acceptedStatePublished) {
      violations.add(
        'action ${event.replaceFirst('action:', '')} emitted before accepted public state',
      );
    }
  }

  return violations;
}

const _badFixtureEvents = ['action:selectMarquee', 'accepted-public-state'];

const _goodFixtureEvents = [
  'accepted-public-state',
  'action:selectMarquee',
  'action:moveSelection',
];
