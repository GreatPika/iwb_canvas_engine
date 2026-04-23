part of '../../guardrails_interactive_api_tool_test.dart';

void _registerInteractiveArchitectureBoundaryPointerHostAndPublicShellTests() {
  test(
    'rejects runtime session callbacks routed through runtime alias without token validation',
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

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
          '''
import 'dart:ui';

import '../contract/canvas_pointer_input.dart';
import '../../controller/scene_controller_committed_mutation_access.dart';
import 'interactive_selection_actions.dart';
import 'interactive_runtime.dart';
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

final class SceneControllerInteractionRuntime {
  SceneControllerInteractionRuntime._({
    required this.mutationBoundary,
    required this.selectionActions,
    required this.runtime,
  });

  final SceneControllerMutationBoundary mutationBoundary;
  final InteractiveSelectionActions selectionActions;
  final InteractiveRuntime runtime;

  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}

  void _ensureKnownPointerSessionToken(PointerSessionToken token) {}
}

final class SceneControllerInteractionRuntimeRequest {
  const SceneControllerInteractionRuntimeRequest({
    required this.mutationAccess,
  });

  final SceneControllerCommittedMutationAccess mutationAccess;
}

SceneControllerInteractionRuntime createSceneControllerInteractionRuntime({
  required SceneControllerInteractionRuntimeRequest request,
}) {
  final mutationBoundary = _createMutationBoundary(request);
  final selectionActions = _createSelectionActions(mutationBoundary);
  final interactiveRuntime = _createInteractiveRuntime(
    request,
    mutationBoundary: mutationBoundary,
  );
  return SceneControllerInteractionRuntime._(
    mutationBoundary: mutationBoundary,
    selectionActions: selectionActions,
    runtime: interactiveRuntime,
  );
}

extension SceneControllerInteractionRuntimeMutationApi
    on SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void registerPointerSession(
    Object session, {
    required PointerSessionToken token,
  }) {}

  void detachPointerSession(PointerSessionToken token) {}

  void releasePointerSessionToken(PointerSessionToken token) {}

  void handlePublicPointer(CanvasPointerInput input) {}

  void handlePublicDoubleTap({required Offset position, int? timestampMs}) {}

  void handlePointerFromSession(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  }) {
    final rt = runtime;
    rt.handlePointerFromSession(input, token: token);
    _ensureKnownPointerSessionToken(token);
    runtime.handlePointerFromSession(input, token: token);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    final rt = runtime;
    rt.handleDoubleTapFromSession(
      position: position,
      timestampMs: timestampMs,
      token: token,
    );
    _ensureKnownPointerSessionToken(token);
    runtime.handleDoubleTapFromSession(
      position: position,
      timestampMs: timestampMs,
      token: token,
    );
  }
}

SceneControllerMutationBoundary _createMutationBoundary(
  SceneControllerInteractionRuntimeRequest request,
) {
  return SceneControllerMutationBoundary(
    mutationAccess: request.mutationAccess,
  );
}

InteractiveSelectionActions _createSelectionActions(
  SceneControllerMutationBoundary mutationBoundary,
) {
  return InteractiveSelectionActions(mutations: mutationBoundary);
}

InteractiveRuntime _createInteractiveRuntime(
  SceneControllerInteractionRuntimeRequest request, {
  required SceneControllerMutationBoundary mutationBoundary,
}) {
  return InteractiveRuntime(
    callbacks: InteractiveRuntimeCallbacks(
      writeSelectionReplace: mutationBoundary.setSelection,
      writeSelectionClear: mutationBoundary.clearSelection,
      commitMoveSelection: mutationBoundary.commitMoveSelection,
      commitDrawStroke: mutationBoundary.commitDrawStroke,
      commitDrawLineFromWorldSegment:
          mutationBoundary.commitDrawLineFromWorldSegment,
      commitEraseNodes: mutationBoundary.commitEraseNodes,
    ),
  );
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
                'SceneControllerInteractionRuntime must route committed '
                'selection/draw callbacks through SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects pointer session that skips owned resource release', () async {
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
        'lib/src/interactive/internal/scene_controller_pointer_session.dart',
        '''
import 'dart:ui';

import '../../contract/canvas_pointer_input.dart';
import '../../contract/pointer_input.dart';
import '../../contract/scene_view_runtime.dart';
import '../../core/pointer_input_tracker.dart';
import 'pointer_session_token.dart';

final class SceneControllerPointerSession implements SceneViewPointerSession {
  SceneControllerPointerSession({
    required Listenable ownerListenable,
    required PointerSessionToken token,
    required void Function(PointerSessionToken token) detachPointerSession,
    required void Function(PointerSessionToken token)
    releasePointerSessionToken,
  }) : _ownerListenable = ownerListenable,
       _token = token,
       _detachPointerSession = detachPointerSession,
       _releasePointerSessionToken = releasePointerSessionToken,
       _pointerTracker = PointerInputTracker(settings: const PointerInputSettings()),
       _ownerListener = _handleOwnerChanged {
    _ownerListenable.addListener(_ownerListener);
  }

  final Listenable _ownerListenable;
  final PointerSessionToken _token;
  final void Function(PointerSessionToken token) _detachPointerSession;
  final void Function(PointerSessionToken token) _releasePointerSessionToken;
  final _PendingTapFlushScheduler _pendingTapFlushScheduler =
      _PendingTapFlushScheduler();
  final PointerInputTracker _pointerTracker;
  late final VoidCallback _ownerListener;

  @override
  int? get pendingTapFlushTimestampMs => null;

  @override
  void detach() {
    _detachPointerSession(_token);
  }

  @override
  void dispose() {
    detach();
    _pendingTapFlushScheduler.dispose();
  }

  @override
  void handleRoutedSample(
    PointerSample sample, {
    required bool shouldTrackSignals,
  }) {}

  @override
  void handleInvalidTerminalSample({
    required CanvasPointerInput input,
    required int pointerId,
    required int referenceTimestampMs,
  }) {}

  @override
  void handleRawPointerRelease({required bool isIdleAfterRelease}) {}

  void _handleOwnerChanged() {}
}

class _PendingTapFlushScheduler {
  void dispose() {}
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
              'pointer session must stay owned by SceneControllerPointerSession',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects mutation boundary replaceScene without beforeApply hook',
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
  const SceneControllerMutationBoundary({required this.mutationAccess});

  final _MutationAccess mutationAccess;

  void clearScene() {
    mutationAccess.clearSceneExactResult();
  }

  void setSelection(Object nodeIds) {
    mutationAccess.replaceSelection(nodeIds);
  }

  void clearSelection() {
    mutationAccess.clearSelection();
  }

  void deleteSelection() {
    mutationAccess.deleteSelection();
  }

  void replaceScene(Object snapshot, {required Object interruptBeforeApply}) {
    mutationAccess.replaceScene(snapshot);
  }

  Object commitMoveSelection(Object proposedDelta) => proposedDelta;

  Object commitDrawStroke(Object payload) {
    return mutationAccess.commitDrawStroke(payload);
  }

  Object commitDrawLineFromWorldSegment(Object payload) {
    return mutationAccess.commitDrawLineFromWorldSegment(payload);
  }

  int commitEraseNodes(Object ids) {
    return mutationAccess.commitEraseNodes(ids);
  }

  void notifySceneChanged() {
    mutationAccess.requestRepaint();
  }
}

class _MutationAccess {
  void clearSceneExactResult() {}
  void replaceSelection(Object nodeIds) {}
  void clearSelection() {}
  void deleteSelection() {}
  void replaceScene(Object snapshot) {}
  Object commitDrawStroke(Object payload) => payload;
  Object commitDrawLineFromWorldSegment(Object payload) => payload;
  int commitEraseNodes(Object ids) => 0;
  void requestRepaint() {}
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

  test('rejects facade that re-owns runtime event state', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        sceneControllerFixture(
          extraImports: "import 'dart:async';",
          extraMembers: '''
  final StreamController<Object> _actions = StreamController<Object>.broadcast();
  final dynamic _runtime = Object();
  int _timestampCursorMs = 0;
''',
          methods: '''
  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
    _runtime.handlePointer(input);
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
    _runtime.handleDoubleTap();
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
              'SceneController must remain a thin facade over '
              'the assembled controller graph',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects interactive runtime that drops split public/session entrypoints',
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
          'lib/src/interactive/internal/interactive_runtime.dart',
          '''
import 'interactive_draw_coordinator.dart';
import 'interactive_event_dispatcher.dart';
import 'interactive_move_session.dart';
import 'interactive_pointer_normalizer.dart';
import 'interactive_gesture_router.dart';
import 'interactive_double_tap_router.dart';

class InteractiveRuntime {}
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
    },
  );

  test('rejects SceneViewInteractive wrapper Listener shell', () async {
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
      writeSandboxFile(sandbox, 'lib/src/view/scene_view_interactive.dart', '''
import 'package:flutter/widgets.dart';

import '../interactive/scene_controller.dart';
import 'scene_view_runtime_host.dart';

class SceneViewInteractive extends StatelessWidget {
  const SceneViewInteractive({required this.controller, super.key});

  final SceneController controller;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {},
      child: SceneViewRuntimeHost(
        runtime: sceneControllerViewRuntimeOf(controller),
      ),
    );
  }
}
''');

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneViewInteractive must remain a thin public shell over '
              'SceneViewRuntimeHost',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects render surface with extra named constructor entrypoint',
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
          'lib/src/view/scene_view_render_surface.dart',
          '''
import '../contract/scene_view_render_state.dart';

class SceneViewRenderSurface {
  SceneViewRenderSurface({required SceneViewMainSceneRenderRead mainSceneRenderRead})
    : _mainSceneRenderRead = mainSceneRenderRead;

  SceneViewRenderSurface.interactive({required SceneViewMainSceneRenderRead mainSceneRenderRead})
    : _mainSceneRenderRead = mainSceneRenderRead;

  final SceneViewMainSceneRenderRead _mainSceneRenderRead;

  SceneViewRenderSurfaceState createState() => SceneViewRenderSurfaceState();
}

class SceneViewRenderSurfaceState extends State<SceneViewRenderSurface> {
  void initState() {
    widget._mainSceneRenderRead.addListener(_handleControllerChanged);
  }

  void didUpdateWidget(SceneViewRenderSurface oldWidget) {
    oldWidget._mainSceneRenderRead.removeListener(_handleControllerChanged);
    widget._mainSceneRenderRead.addListener(_handleControllerChanged);
  }

  void dispose() {
    widget._mainSceneRenderRead.removeListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {}
}

class State<T> {
  T get widget => throw UnimplementedError();
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
                'SceneViewRenderSurface must remain a render-state-only '
                'view surface',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects PointerSessionToken with exposed payload field', () async {
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
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/pointer_session_token.dart',
        '''
class PointerSessionToken {
  const PointerSessionToken(this.id);

  final int id;
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
              'PointerSessionToken must remain an opaque internal nominal token',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects PointerSessionToken with exposed payload field under another name',
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

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/pointer_session_token.dart',
          '''
final class PointerSessionToken {
  const PointerSessionToken(this.rawValue);

  final int rawValue;
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
                'PointerSessionToken must remain an opaque internal nominal token',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects event dispatcher that re-owns eraser geometry helper', () async {
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
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/internal/interactive_event_dispatcher.dart',
        '''
import 'dart:async';

class InteractiveEventDispatcher {
  final StreamController<Object> _actions = StreamController<Object>.broadcast();
  final StreamController<Object> _editTextRequests =
      StreamController<Object>.broadcast();

  int resolveTimestampMs(int? value) => value ?? 0;

  void emitAction(Object type, List<Object> nodeIds, int timestampMs) {}

  void emitEditTextRequested(Object request) {}

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
              'InteractiveEventDispatcher must remain the event timeline owner',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects projected eraser contract that drops thresholdSquared',
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

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }
''',
          ),
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/interactive_draw_eraser_projection.dart',
          '''
import 'dart:ui';

typedef InteractiveDrawProjectedEraser = ({
  List<Offset> points,
  double threshold,
});
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'InteractiveDrawProjectedEraser must remain the shared '
                'projection contract',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}
