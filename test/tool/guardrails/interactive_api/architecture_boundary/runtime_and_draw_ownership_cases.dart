part of '../../guardrails_interactive_api_tool_test.dart';

void _registerInteractiveArchitectureBoundaryRuntimeAndDrawOwnershipTests() {
  test(
    'rejects mutation boundary clearScene store controller write bypass with return value',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
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
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_mutation_boundary.dart',
          '''
class SceneControllerMutationBoundary {
  final storeController = _Core();

  bool clearScene() {
    return storeController.write<bool>((writer) => true);
  }

  void setSelection(Object nodeIds) {
    storeController.commands.writeSelectionReplace(nodeIds);
  }

  void clearSelection() {
    storeController.commands.writeSelectionClear();
  }

  void deleteSelection() {
    storeController.commands.writeDeleteSelection();
  }

  void transformSelection(Object delta) {
    storeController.commands.writeSelectionTransform(delta);
  }

  Object prepareSceneReplacement(Object snapshot) {
    return storeController.prepareSceneReplacement(snapshot);
  }

  void replaceScene(Object snapshot) {
    final replacement = storeController.prepareSceneReplacement(snapshot);
    storeController.writePreparedSceneReplacement(replacement);
  }

  Object commitMoveSelection(Object proposedDelta) => proposedDelta;

  Object commitDrawStroke(Object payload) {
    return storeController.draw.writeDrawStroke(payload);
  }

  Object commitDrawLineFromWorldSegment(Object payload) {
    return storeController.draw.writeDrawLineFromWorldSegment(payload);
  }

  int commitEraseNodes(Object ids) {
    return storeController.draw.writeEraseNodes(ids);
  }
}

class _Core {
  final commands = _Commands();
  final draw = _Draw();

  T write<T>(Object fn) => true as T;

  Object prepareSceneReplacement(Object snapshot) => snapshot;

  void writePreparedSceneReplacement(Object replacement) {}
}

class _Commands {
  void writeSelectionReplace(Object nodeIds) {}

  void writeSelectionClear() {}

  void writeDeleteSelection() {}

  void writeSelectionTransform(Object delta) {}
}

class _Draw {
  Object writeDrawStroke(Object payload) => payload;

  Object writeDrawLineFromWorldSegment(Object payload) => payload;

  int writeEraseNodes(Object ids) => 0;
}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerMutationBoundary must remain the canonical '
                'scene/selection write owner',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects runtime that re-owns event timeline state', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
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
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/interactive_runtime.dart',
        '''
import 'dart:async';

import 'interactive_draw_coordinator.dart';
import 'interactive_event_dispatcher.dart';
import 'interactive_move_session.dart';
import 'interactive_pointer_normalizer.dart';
import 'interactive_gesture_router.dart';
import 'interactive_double_tap_router.dart';

class InteractiveRuntime {
  InteractiveRuntime({required this.events});

  final InteractiveEventDispatcher events;
  final _actions = StreamController<Object>.broadcast();
  int _timestampCursorMs = 0;

  void handlePointer(Object input) {}

  void handleDoubleTap({required Object position, int? timestampMs}) {
    events.resolveTimestampMs(timestampMs);
  }
}
''',
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'InteractiveRuntime must keep event timeline and draw-local '
              'geometry outside the boundary runtime',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects draw coordinator that re-owns eraser geometry', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
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
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/interactive_draw_coordinator.dart',
        '''
import 'interactive_draw_eraser_engine.dart';
import 'interactive_draw_line_engine.dart';
import 'interactive_draw_stroke_engine.dart';
import 'interactive_draw_terminal_router.dart';

class InteractiveDrawCoordinator {
  bool _eraserHitsLine() => false;

  void handlePointer(Object sample) {}
}
''',
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'InteractiveDrawCoordinator must remain a draw-family '
              'orchestrator and not re-own eraser geometry',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects eraser engine that re-owns exact-hit geometry', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
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
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/interactive_draw_eraser_engine.dart',
        '''
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveDrawEraserEngineCallbacks {
  const InteractiveDrawEraserEngineCallbacks({
    required this.onOverlayStateChanged,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.commitEraseNodes,
  });

  final Object onOverlayStateChanged;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object commitEraseNodes;
}

class InteractiveDrawEraserEngine {
  bool _eraserHitsLine() => false;
}
''',
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'InteractiveDrawEraserEngine must delegate exact-hit geometry '
              'to eraser-local owners',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects internal access seam that drops canonical accessor surface',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            methods: '''
  void handlePointer(Object input) {
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
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_internal_access.dart',
          '''
class SceneControllerInternalAccessRegistration {}

void registerSceneControllerInternalAccess(
  Object controller,
  Object registration,
) {}

void unregisterSceneControllerInternalAccess(Object controller) {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'internal interactive test/debug access must remain outside '
                'SceneController',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects missing required split-owner file', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
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
      File(
        '${sandbox.path}/lib/src/interactive/internal/'
        'interactive_event_dispatcher.dart',
      ).deleteSync();

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'missing required split owner InteractiveEventDispatcher at '
              '/lib/src/interactive/internal/interactive_event_dispatcher.dart',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects SceneViewRuntime contract getter drift', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        sceneControllerFixture(
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
        ),
      );
      writeSandboxFile(sandbox, 'lib/src/contract/scene_view_runtime.dart', '''
abstract interface class SceneViewRuntime {
  SceneViewRenderState get renderState;

  SceneViewPointerSession get createPointerSession;
}

abstract interface class SceneViewRenderState {
  void addListener(Object listener);

  void removeListener(Object listener);
}

abstract interface class SceneViewPointerSession {
  int get detach;

  void dispose();
}
''');

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneViewRuntime must remain the single internal '
              'runtime/session contract for view core',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });
}
