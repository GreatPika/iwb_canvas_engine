import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/guardrail_violation.dart';
import '../../tool/guardrails/src/interaction_guardrail_checks.dart';
import '../../tool/guardrails/src/selection_move_guardrail_suite.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  _registerRunnerBackedProofs();
  _registerStructuralNegativeProofs();
  _registerStructuralPositiveProofs();
}

void _registerRunnerBackedProofs() {
  for (final proof in _runnerBackedProofs) {
    test('${proof.id} is runner-backed', () async {
      expect(
        await guardrailIsRunnerBacked(
          id: proof.id,
          suites: proof.suites,
          proofPaths: proof.proofPaths,
        ),
        isTrue,
      );
    });
  }
}

void _registerStructuralNegativeProofs() {
  _registerInteractionImportNegativeProofs();
  _registerRetiredFlutterBridgeImportNegativeProof();
  _registerCleanupCoordinatorNegativeProof();
  _registerRetiredFlutterBridgeCleanupNegativeProof();
  _registerReadPortNegativeProof();
}

void _registerInteractionImportNegativeProofs() {
  test('interaction store import fixture is rejected', () async {
    final violations = checkInteractionImportBoundaryFile(
      path: 'lib/src/interaction/bad_store_import.dart',
      content: "import '../store/document_store_kernel.dart';\n",
    );
    expect(violations, isNotEmpty);

    await _expectStructuralRejection(
      id: interactionNoConcreteStoreImportsGuardrailId,
      violations: violations,
    );
  });

  test('interaction selection import fixture is rejected', () async {
    final violations = checkInteractionImportBoundaryFile(
      path: 'lib/src/interaction/bad_selection_import.dart',
      content: "import '../selection/selection_kernel.dart';\n",
    );
    expect(violations, isNotEmpty);

    await _expectStructuralRejection(
      id: interactionNoConcreteSelectionImportsGuardrailId,
      violations: violations,
    );
  });

  test('interaction command facts import fixture is rejected', () async {
    final violations = checkInteractionImportBoundaryFile(
      path: 'lib/src/interaction/bad_command_facts_import.dart',
      content: "import '../contracts/internal/command_facts_port.dart';\n",
    );
    expect(violations, isNotEmpty);

    await _expectStructuralRejection(
      id: interactionNoCommandFactsImportGuardrailId,
      violations: violations,
    );
  });
}

void _registerRetiredFlutterBridgeImportNegativeProof() {
  test('interaction retired flutter bridge import fixture is rejected', () {
    final violations = checkInteractionImportBoundaryFile(
      path: 'lib/src/interaction/bad_flutter_bridge_import.dart',
      content: "import '../flutter_bridge/canvas_surface.dart';\n",
    );
    expect(
      violations,
      contains(
        isA<GuardrailViolation>().having(
          (violation) => violation.guardrailId,
          'guardrailId',
          'core.import_boundaries',
        ),
      ),
    );
  });
}

void _registerCleanupCoordinatorNegativeProof() {
  _registerCleanupCoordinatorFileNegativeProof();
  _registerCleanupProtocolFileNegativeProof();
}

void _registerCleanupCoordinatorFileNegativeProof() {
  test('cleanup coordinator dependency fixture is rejected', () async {
    expect(
      await _expectCleanupCoordinatorImportRejected(
        "import '../frame/frame_engine.dart';\n",
      ),
      isNotEmpty,
    );
  });

  test('cleanup coordinator runtime dependency fixture is rejected', () async {
    expect(
      await _expectCleanupCoordinatorImportRejected(
        "import '../runtime/runtime_root.dart';\n",
      ),
      isNotEmpty,
    );
  });

  test('cleanup coordinator resolver contract fixture is rejected', () async {
    expect(
      await _expectCleanupCoordinatorImportRejected(
        "import '../contracts/public/canvas_actions.dart';\n",
      ),
      isNotEmpty,
    );
  });

  test('cleanup coordinator resolver guard fixture is rejected', () async {
    expect(
      await _expectCleanupCoordinatorImportRejected(
        "import '../contracts/internal/resolver_mutation_guard.dart';\n",
      ),
      isNotEmpty,
    );
  });
}

void _registerRetiredFlutterBridgeCleanupNegativeProof() {
  test(
    'cleanup coordinator retired flutter bridge fixture is rejected',
    () async {
      expect(
        await _expectCleanupCoordinatorImportRejected(
          "import '../flutter_bridge/canvas_surface.dart';\n",
        ),
        isNotEmpty,
      );
    },
  );
}

void _registerCleanupProtocolFileNegativeProof() {
  test('cleanup protocol dependency fixture is rejected', () async {
    final violations = checkCleanupCoordinatorDependencyFile(
      path: 'lib/src/interaction/pointer_cleanup_protocol.dart',
      content: "import '../contracts/public/canvas_actions.dart';\n",
    );
    expect(violations, isNotEmpty);

    await _expectStructuralRejection(
      id: interactionCleanupCoordinatorDependencyBansGuardrailId,
      violations: violations,
    );
  });
}

void _registerReadPortNegativeProof() {
  _registerSelectedMoveReadPortNegativeProof();
  _registerEraserReadPortNegativeProof();
  _registerSyntheticReadPortNegativeProof();
}

void _registerSelectedMoveReadPortNegativeProof() {
  test('read-port mutable fact fixture is rejected', () async {
    final productionSource = _interactionReadPortSource();
    final mutableFixture = productionSource.replaceFirst(
      'selectedIds = List.unmodifiable(selectedIds)',
      'selectedIds = selectedIds',
    );
    final violations = _readPortImmutableViolations(mutableFixture);
    expect(violations, isNotEmpty);
    await _expectStructuralRejection(
      id: interactionReadPortImmutableFactsGuardrailId,
      violations: violations,
    );
  });

  test('read-port comment-only copy fixture is rejected', () async {
    final productionSource = _interactionReadPortSource();
    final mutableFixture = productionSource
        .replaceFirst(
          'selectedIds = List.unmodifiable(selectedIds)',
          'selectedIds = selectedIds',
        )
        .replaceFirst('final List<CanvasElementId> selectedIds;', '''
final List<CanvasElementId> selectedIds;
// selectedIds = List.unmodifiable(selectedIds)
''');
    final violations = _readPortImmutableViolations(mutableFixture);
    expect(violations, isNotEmpty);
    await _expectStructuralRejection(
      id: interactionReadPortImmutableFactsGuardrailId,
      violations: violations,
    );
  });
}

void _registerEraserReadPortNegativeProof() {
  test('read-port eraser request corridor fixture is rejected', () async {
    final mutableFixture = _interactionReadPortSource().replaceFirst(
      '}) : corridorPoints = List.unmodifiable(corridorPoints);',
      '}) : corridorPoints = corridorPoints;',
    );
    final violations = _readPortImmutableViolations(mutableFixture);
    expect(violations, isNotEmpty);
    await _expectStructuralRejection(
      id: interactionReadPortImmutableFactsGuardrailId,
      violations: violations,
    );
  });

  test('read-port eraser facts corridor fixture is rejected', () async {
    final mutableFixture = _interactionReadPortSource().replaceFirst(
      '''
}) : corridorPoints = List.unmodifiable(corridorPoints),
       erasedElementIds = List.unmodifiable(erasedElementIds);
''',
      '''
}) : corridorPoints = corridorPoints,
       erasedElementIds = List.unmodifiable(erasedElementIds);
''',
    );
    final violations = _readPortImmutableViolations(mutableFixture);
    expect(violations, isNotEmpty);
    await _expectStructuralRejection(
      id: interactionReadPortImmutableFactsGuardrailId,
      violations: violations,
    );
  });

  test('read-port eraser facts erased ids fixture is rejected', () async {
    final mutableFixture = _interactionReadPortSource().replaceFirst(
      '''
}) : corridorPoints = List.unmodifiable(corridorPoints),
       erasedElementIds = List.unmodifiable(erasedElementIds);
''',
      '''
}) : corridorPoints = List.unmodifiable(corridorPoints),
       erasedElementIds = erasedElementIds;
''',
    );
    final violations = _readPortImmutableViolations(mutableFixture);
    expect(violations, isNotEmpty);
    await _expectStructuralRejection(
      id: interactionReadPortImmutableFactsGuardrailId,
      violations: violations,
    );
  });
}

void _registerSyntheticReadPortNegativeProof() {
  _registerSyntheticReadPortCopyNegativeProof();
  _registerSyntheticReadPortArgumentNegativeProof();
  _registerSyntheticReadPortFieldFormalNegativeProof();
}

void _registerSyntheticReadPortCopyNegativeProof() {
  test('read-port synthetic copied collection fixture is rejected', () async {
    final violations = _readPortImmutableViolations('''
final class SyntheticReadFacts {
  SyntheticReadFacts({required Iterable<CanvasElementId> ids}) : ids = ids;

  final List<CanvasElementId> ids;
}
''');
    expect(violations, isNotEmpty);
    await _expectStructuralRejection(
      id: interactionReadPortImmutableFactsGuardrailId,
      violations: violations,
    );
  });

  test('read-port synthetic mutable copy fixture is rejected', () async {
    final violations = _readPortImmutableViolations('''
final class SyntheticReadFacts {
  SyntheticReadFacts({required Iterable<CanvasElementId> ids})
    : ids = List.of(ids);

  final List<CanvasElementId> ids;
}
''');
    expect(violations, isNotEmpty);
    await _expectStructuralRejection(
      id: interactionReadPortImmutableFactsGuardrailId,
      violations: violations,
    );
  });
}

void _registerSyntheticReadPortArgumentNegativeProof() {
  test('read-port synthetic wrong unmodifiable argument is rejected', () async {
    final violations = _readPortImmutableViolations('''
final class SyntheticReadFacts {
  SyntheticReadFacts({
    required Iterable<CanvasElementId> ids,
    required Iterable<CanvasElementId> otherIds,
  }) : ids = List.unmodifiable(otherIds);

  final List<CanvasElementId> ids;
}
''');
    expect(violations, isNotEmpty);
    await _expectStructuralRejection(
      id: interactionReadPortImmutableFactsGuardrailId,
      violations: violations,
    );
  });

  test(
    'read-port synthetic mixed unmodifiable expression is rejected',
    () async {
      final violations = _readPortImmutableViolations('''
final class SyntheticReadFacts {
  SyntheticReadFacts({
    required Iterable<CanvasElementId> ids,
    required Iterable<CanvasElementId> otherIds,
  }) : ids = List.unmodifiable(otherIds.followedBy(ids));

  final List<CanvasElementId> ids;
}
''');
      expect(violations, isNotEmpty);
      await _expectStructuralRejection(
        id: interactionReadPortImmutableFactsGuardrailId,
        violations: violations,
      );
    },
  );
}

void _registerSyntheticReadPortFieldFormalNegativeProof() {
  test(
    'read-port synthetic field-formal collection fixture is rejected',
    () async {
      final violations = _readPortImmutableViolations('''
final class SyntheticReadFacts {
  SyntheticReadFacts({required this.ids});

  final List<CanvasElementId> ids;
}
''');
      expect(violations, isNotEmpty);
      await _expectStructuralRejection(
        id: interactionReadPortImmutableFactsGuardrailId,
        violations: violations,
      );
    },
  );
}

List<GuardrailViolation> _readPortImmutableViolations(String source) {
  return checkInteractionReadPortImmutableFactsSources({
    'lib/src/interaction/interaction_read_port.dart': source,
  });
}

String _interactionReadPortSource() {
  return File(
    'lib/src/interaction/interaction_read_port.dart',
  ).readAsStringSync();
}

void _registerStructuralPositiveProofs() {
  test('selection-and-move structural guardrails accept positive fixtures', () {
    expect(
      checkInteractionImportBoundaryFile(
        path: 'lib/src/interaction/good_public_contract_import.dart',
        content: "import '../contracts/public/canvas_ids.dart';\n",
      ).where(_isInteractionBoundaryViolation),
      isEmpty,
    );
    expect(
      checkCleanupCoordinatorDependencyFile(
        path: 'lib/src/interaction/pointer_tool_cleanup_coordinator.dart',
        content: "import 'dart:ui';\n",
      ),
      isEmpty,
    );
    expect(
      checkCleanupCoordinatorDependencyFile(
        path: 'lib/src/interaction/pointer_cleanup_protocol.dart',
        content: '',
      ),
      isEmpty,
    );
  });
}

Future<void> _expectStructuralRejection({
  required String id,
  required List<GuardrailViolation> violations,
}) async {
  expect(
    violations.map((violation) => violation.guardrailId),
    contains(id),
    reason: id,
  );
  expect(
    await guardrailRejectsStructuralViolations(id: id, violations: violations),
    isTrue,
    reason: id,
  );
}

Future<List<GuardrailViolation>> _expectCleanupCoordinatorImportRejected(
  String content,
) async {
  final violations = checkCleanupCoordinatorDependencyFile(
    path: 'lib/src/interaction/pointer_tool_cleanup_coordinator.dart',
    content: content,
  );
  expect(violations, isNotEmpty);

  await _expectStructuralRejection(
    id: interactionCleanupCoordinatorDependencyBansGuardrailId,
    violations: violations,
  );
  return violations;
}

bool _isInteractionBoundaryViolation(GuardrailViolation violation) {
  return {
    interactionNoConcreteStoreImportsGuardrailId,
    interactionNoConcreteSelectionImportsGuardrailId,
    interactionNoCommandFactsImportGuardrailId,
  }.contains(violation.guardrailId);
}

final class _RunnerBackedProof {
  const _RunnerBackedProof({
    required this.id,
    required this.suites,
    required this.proofPaths,
  });

  final String id;
  final Set<String> suites;
  final List<String> proofPaths;
}

const _runnerBackedProofs = [
  _RunnerBackedProof(
    id: 'load.prepares_before_interrupt',
    suites: {'blocking', 'load'},
    proofPaths: ['test/runtime/load_document_ordering_test.dart'],
  ),
  _RunnerBackedProof(
    id: 'load.success_interrupts_before_install',
    suites: {'blocking', 'load'},
    proofPaths: ['test/runtime/load_document_ordering_test.dart'],
  ),
  _RunnerBackedProof(
    id: 'interaction.pointer_cleanup_coordinator_only',
    suites: {'blocking', 'interaction'},
    proofPaths: [
      'test/guardrails/import_boundaries_test.dart',
      'test/interaction/pointer_tool_cleanup_coordinator_test.dart',
    ],
  ),
  _RunnerBackedProof(
    id: interactionNoResolverOnCancelPathsGuardrailId,
    suites: {'blocking', 'interaction'},
    proofPaths: ['test/interaction/move_machine_test.dart'],
  ),
  _RunnerBackedProof(
    id: interactionNoStaleTerminalCommitGuardrailId,
    suites: {'blocking', 'interaction'},
    proofPaths: [
      'test/interaction/move_machine_test.dart',
      'test/interaction/draw_stroke_interaction_routing_test.dart',
      'test/interaction/line_interaction_routing_test.dart',
      'test/interaction/eraser_context_action_routing_test.dart',
    ],
  ),
  _RunnerBackedProof(
    id: eventsActionAfterStateOrderGuardrailId,
    suites: {'blocking', 'events'},
    proofPaths: ['test/interaction/commands_emit_user_actions_test.dart'],
  ),
  _RunnerBackedProof(
    id: selectedMoveMainOnlyPreviewGuardrailId,
    suites: {'blocking', 'preview'},
    proofPaths: ['test/frame/repaint_bus_output_test.dart'],
  ),
  _RunnerBackedProof(
    id: marqueeOverlayOnlyPreviewGuardrailId,
    suites: {'blocking', 'preview'},
    proofPaths: ['test/frame/repaint_bus_output_test.dart'],
  ),
  _RunnerBackedProof(
    id: toolPublicPortBehaviorGuardrailId,
    suites: {'blocking', 'tools'},
    proofPaths: [
      'test/api/tool_port_settings_test.dart',
      'test/api/command_port_actions_test.dart',
      'test/api/typed_action_payloads_test.dart',
    ],
  ),
];
