part of '../../guardrails_interactive_api_tool_test.dart';

void _registerCommittedReadSideHermeticityTests() {
  test('accepts snapshot-only interactive committed read callbacks', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects interactive committed read callback leaking runtime scene node through typedef alias',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {}
''');
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_move_callbacks.dart',
          '''
import '../../core/scene_node.dart';
import '../../core/scene_spatial_index.dart';

typedef LeakedNode = SceneNode;

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onPublicStateChanged,
    required this.onSceneStateChanged,
    required this.onOverlayStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.emitAction,
  });

  final Object onPublicStateChanged;
  final Object onSceneStateChanged;
  final Object onOverlayStateChanged;
  final Object readSnapshot;
  final Object readSelectedNodeIds;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final LeakedNode? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object writeSelectionReplace;
  final Object writeSelectionClear;
  final Object commitMoveSelection;
  final Object emitAction;
}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback '
                '"InteractiveMoveSessionCallbacks.'
                'resolveSpatialCandidateSnapshot" must not expose live '
                'runtime scene-graph types (SceneNode)',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects interactive eraser callback leaking runtime scene node subtype',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {}
''');
        writeSandboxFile(sandbox, 'lib/src/core/vector_nodes.dart', '''
import 'scene_node.dart';

class StrokeNode extends SceneNode {}
''');
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_draw_eraser_targets.dart',
          '''
import '../../core/vector_nodes.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveDrawEraserTargetsCallbacks {
  const InteractiveDrawEraserTargetsCallbacks({
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.onSpatialQuery,
  });

  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final StrokeNode? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object onSpatialQuery;
}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback '
                '"InteractiveDrawEraserTargetsCallbacks.'
                'resolveSpatialCandidateSnapshot" must not expose live '
                'runtime scene-graph types (StrokeNode)',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects interactive callback field outside sealed committed read surface',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_move_callbacks.dart',
          '''
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onPublicStateChanged,
    required this.onSceneStateChanged,
    required this.onOverlayStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.emitAction,
    required this.resolveSnapshotNodeById,
  });

  final Object onPublicStateChanged;
  final Object onSceneStateChanged;
  final Object onOverlayStateChanged;
  final Object readSnapshot;
  final Object readSelectedNodeIds;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object writeSelectionReplace;
  final Object writeSelectionClear;
  final Object commitMoveSelection;
  final Object emitAction;
  final Object resolveSnapshotNodeById;
}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback '
                '"InteractiveMoveSessionCallbacks.resolveSnapshotNodeById" '
                'must not extend the sealed callback surface',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects interactive callback queryHitTestCandidates signature drift',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_move_callbacks.dart',
          '''
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onPublicStateChanged,
    required this.onSceneStateChanged,
    required this.onOverlayStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.emitAction,
  });

  final Object onPublicStateChanged;
  final Object onSceneStateChanged;
  final Object onOverlayStateChanged;
  final Object readSnapshot;
  final Object readSelectedNodeIds;
  final List<SceneHitTestSpatialCandidate> Function(Object bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object writeSelectionReplace;
  final Object writeSelectionClear;
  final Object commitMoveSelection;
  final Object emitAction;
}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback '
                '"InteractiveMoveSessionCallbacks.queryHitTestCandidates" '
                'must keep the exact sealed signature',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects interactive callback resolveSpatialCandidateSnapshot extra parameters',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart',
          '''
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveDrawCoordinatorCallbacks {
  const InteractiveDrawCoordinatorCallbacks({
    required this.onOverlayStateChanged,
    required this.emitAction,
    required this.commitDrawStroke,
    required this.commitDrawLineFromWorldSegment,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.commitEraseNodes,
  });

  final Object onOverlayStateChanged;
  final Object emitAction;
  final Object commitDrawStroke;
  final Object commitDrawLineFromWorldSegment;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(
    SceneHitTestSpatialCandidate candidate, {
    Object? snapshotOverride,
  })
  resolveSpatialCandidateSnapshot;
  final Object commitEraseNodes;
}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback '
                '"InteractiveDrawCoordinatorCallbacks.'
                'resolveSpatialCandidateSnapshot" must keep the exact sealed '
                'signature',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects missing interactive committed read callback owner class',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_draw_eraser_engine.dart',
          '''
class InteractiveDrawEraserEngine {}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback owner '
                '"InteractiveDrawEraserEngineCallbacks" is required in '
                'internal/interactive_draw_eraser_engine.dart',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects missing interactive committed read callback file', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      final missingFile = File(
        '${sandbox.path}/lib/src/interactive/internal/'
        'interactive_draw_eraser_targets.dart',
      );
      missingFile.deleteSync();
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'committed read callback file '
              'internal/interactive_draw_eraser_targets.dart is required '
              'for "InteractiveDrawEraserTargetsCallbacks"',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects when all interactive committed read callback files are missing',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        for (final relativePath in const <String>[
          'lib/src/interactive/internal/interactive_runtime_callbacks.dart',
          'lib/src/interactive/internal/interactive_move_callbacks.dart',
          'lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart',
          'lib/src/interactive/internal/interactive_draw_eraser_engine.dart',
          'lib/src/interactive/internal/interactive_draw_eraser_targets.dart',
        ]) {
          final file = File('${sandbox.path}/$relativePath');
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback files are required for the '
                'interactive committed read surface',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects interactive callback constructor parameter outside sealed surface',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(sandbox, 'lib/src/core/scene_node.dart', '''
class SceneNode {}
''');
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_move_callbacks.dart',
          '''
import '../../contract/snapshot.dart';
import '../../core/scene_node.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onPublicStateChanged,
    required this.onSceneStateChanged,
    required this.onOverlayStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.emitAction,
    required SceneNode leakedNode,
  });

  final Object onPublicStateChanged;
  final Object onSceneStateChanged;
  final Object onOverlayStateChanged;
  final Object readSnapshot;
  final Object readSelectedNodeIds;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object writeSelectionReplace;
  final Object writeSelectionClear;
  final Object commitMoveSelection;
  final Object emitAction;
}
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'committed read callback constructor for '
                '"InteractiveMoveSessionCallbacks" must not expose live '
                'runtime scene-graph types (SceneNode)',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}
