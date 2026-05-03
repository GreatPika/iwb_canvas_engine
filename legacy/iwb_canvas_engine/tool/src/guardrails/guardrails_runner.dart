import 'dart:io';

import 'support/guardrail_context.dart';
import 'core/guardrail_rule.dart';
import 'core/guardrail_run_state.dart';
import 'core/guardrail_runner_support.dart';
import 'core/guardrail_violation.dart';
import 'guardrail_rule_inventory.dart';
import '../tool_command_result.dart';

Future<ToolCommandResult> evaluateGuardrailsTool({Directory? root}) async {
  final context = GuardrailContext.forDirectory(root ?? Directory.current);
  final state = GuardrailRunState();

  try {
    for (final rule in guardrailRuleInventory) {
      final violations = await _runRule(
        rule: rule,
        context: context,
        state: state,
      );
      failOnFirstViolation(violations);
    }
  } on GuardrailToolFailure catch (failure) {
    return ToolCommandResult(
      exitCode: 1,
      stderr: 'FAIL: guardrails\n- ${failure.violation}\n',
    );
  }

  return const ToolCommandResult(exitCode: 0, stdout: 'OK: guardrails\n');
}

Future<void> runGuardrailsTool({Directory? root}) async {
  final result = await evaluateGuardrailsTool(root: root);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

Future<List<GuardrailViolation>> _runRule({
  required GuardrailRule rule,
  required GuardrailContext context,
  required GuardrailRunState state,
}) {
  return state.runWithRuleContract(
    metadata: rule.metadata,
    action: () => rule.run(context, state),
  );
}
