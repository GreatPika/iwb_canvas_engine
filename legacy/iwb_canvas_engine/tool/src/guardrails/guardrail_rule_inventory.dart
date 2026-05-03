import 'core/guardrail_rule.dart';
import 'rules/contract/contract_architecture_rules.dart';
import 'rules/controller/write_only_mutation_rules.dart';
import 'rules/interactive/mutation_boundary_rules.dart';
import 'rules/model/model_architecture_rules.dart';
import 'rules/public/public_signature_rules.dart';
import 'rules/public/public_surface_rules.dart';

final List<GuardrailRule> guardrailRuleInventory =
    List<GuardrailRule>.unmodifiable(<GuardrailRule>[
      publicSurfaceGuardrailRule,
      publicSignatureGuardrailRule,
      interactiveApiGuardrailRule,
      controllerApiGuardrailRule,
      modelArchitectureGuardrailRule,
      contractArchitectureGuardrailRule,
    ]);
