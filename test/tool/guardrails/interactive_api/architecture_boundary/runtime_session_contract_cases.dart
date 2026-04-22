part of '../../guardrails_interactive_api_tool_test.dart';

void _registerInteractiveArchitectureBoundaryRuntimeSessionContractTests() {
  test('rejects runtime session callbacks without token validation', () async {
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
    runtime.handlePointerFromSession(input, token: token);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
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
  });

  test(
    'rejects runtime session callbacks when an unguarded callback appears before a later guarded one',
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
    runtime.handlePointerFromSession(input, token: token);
    _ensureKnownPointerSessionToken(token);
    runtime.handlePointerFromSession(input, token: token);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    runtime.handleDoubleTapFromSession(
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

  test(
    'rejects runtime session callbacks when an unguarded callback appears after a guarded one',
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
    _ensureKnownPointerSessionToken(token);
    runtime.handlePointerFromSession(input, token: token);
    runtime.handlePointerFromSession(input, token: token);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    _ensureKnownPointerSessionToken(token);
    runtime.handleDoubleTapFromSession(
      position: position,
      timestampMs: timestampMs,
      token: token,
    );
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
}
