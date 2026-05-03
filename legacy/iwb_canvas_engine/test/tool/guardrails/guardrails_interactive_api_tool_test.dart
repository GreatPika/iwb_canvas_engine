@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/guardrail_fixture_writer.dart';
import '../support/guardrails_sandbox_support.dart';
import '../support/tool_diagnostic_matchers.dart';
import '../support/tool_process_test_support.dart';

part 'interactive_api/resolver_purity/scene_controller_entrypoint_cases.dart';
part 'interactive_api/resolver_purity/dispose_guard_cases.dart';
part 'interactive_api/committed_read_callbacks/callback_contract_cases.dart';
part 'interactive_api/mutation_boundary/owner_guard_cases.dart';
part 'interactive_api/architecture_boundary/architecture_boundary_cases.dart';
part 'interactive_api/architecture_boundary/view_and_graph_cases.dart';
part 'interactive_api/architecture_boundary/view_runtime_host_cases.dart';
part 'interactive_api/architecture_boundary/owner_and_mutation_boundary_cases.dart';
part 'interactive_api/architecture_boundary/view_surface_and_runtime_cases.dart';
part 'interactive_api/architecture_boundary/facade_and_boundary_cases.dart';
part 'interactive_api/architecture_boundary/runtime_ownership_cases.dart';
part 'interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart';
part 'interactive_api/architecture_boundary/runtime_session_contract_cases.dart';
part 'interactive_api/architecture_boundary/pointer_host_and_public_shell_cases.dart';

void main() {
  group('tool/check_guardrails.dart', () {
    // INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
    // INV:INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY
    // INV:INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE
    _registerInteractiveAcceptanceTests();
    _registerInteractiveGuardViolationTests();
    _registerInteractiveDisposeGuardTests();
    _registerCapabilityGuardViolationTests();
    // INV:INV-ENG-INTERACTIVE-MUTATION-BOUNDARY
    // INV:INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY
    // INV:INV-ENG-PREPARED-REPLACE-SCENE-BOUNDARY-HERMETICITY
    _registerInteractiveArchitectureGuardrailTests();
    _registerCommittedReadSideHermeticityTests();
  });
}
