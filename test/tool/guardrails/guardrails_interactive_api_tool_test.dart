@Tags(['tool'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../support/guardrails_tool_test_support.dart';
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
    _registerInteractiveAcceptanceTests();
    _registerInteractiveGuardViolationTests();
    _registerInteractiveDisposeGuardTests();
    _registerCapabilityGuardViolationTests();
    // INV:INV-ENG-INTERACTIVE-MUTATION-BOUNDARY
    // INV:INV-ENG-PREPARED-REPLACE-SCENE-BOUNDARY-HERMETICITY
    _registerInteractiveArchitectureGuardrailTests();
    _registerCommittedReadSideHermeticityTests();
  });
}

String _sceneControllerFixture({
  required String methods,
  String extraImports = '',
  String extraMembers = '',
}) {
  return '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';
$extraImports

class SceneController {
  final Object _graph = createSceneControllerGraph(
    SceneControllerGraphRequest(),
  );
$extraMembers

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

$methods

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
}
''';
}
