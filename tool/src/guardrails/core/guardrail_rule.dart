import '../support/guardrail_context.dart';
import 'guardrail_rule_metadata.dart';
import 'guardrail_violation.dart';

typedef GuardrailRuleRun =
    Future<List<GuardrailViolation>> Function(GuardrailContext context);

final class GuardrailRule {
  const GuardrailRule({required this.metadata, required this.run});

  final GuardrailRuleMetadata metadata;
  final GuardrailRuleRun run;
}
