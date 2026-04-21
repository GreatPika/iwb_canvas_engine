part of '../../guardrails_interactive_api_tool_test.dart';

void _registerInteractiveArchitectureBoundaryFacadeAndBoundaryTests() {
  test('rejects facade that directly imports draw-local owner', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        sceneControllerFixture(
          extraImports: "import 'internal/interactive_draw_coordinator.dart';",
          extraMembers:
              '\n  final InteractiveDrawCoordinator _drawCoordinator =\n'
              '      InteractiveDrawCoordinator();\n',
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
    'rejects scene mutation owner store controller write bypass outside mutation boundary',
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
          'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
          '''
class SceneControllerSceneMutations {
  final mutations = Object();

  void write(Object fn) {
    ensureExternalMutationAllowed('write');
    storeController.write(fn);
  }

  void setBackgroundColor(Object value) {
    ensureExternalMutationAllowed('setBackgroundColor');
    mutations.toString();
  }

  void setGridEnabled(bool value) {
    ensureExternalMutationAllowed('setGridEnabled');
    mutations.toString();
  }

  void setGridCellSize(double value) {
    ensureExternalMutationAllowed('setGridCellSize');
    mutations.toString();
  }

  void addNode(Object node) {
    ensureExternalMutationAllowed('addNode');
    mutations.toString();
  }

  void ensureLayer(Object layerId) {
    ensureExternalMutationAllowed('ensureLayer');
    mutations.toString();
  }

  void patchNode(Object patch) {
    ensureExternalMutationAllowed('patchNode');
    mutations.toString();
  }

  void removeNode(Object nodeId) {
    ensureExternalMutationAllowed('removeNode');
    mutations.toString();
  }

  void clearScene() {
    ensureExternalMutationAllowed('clearScene');
    mutations.toString();
  }

  void setCameraOffset(Object value) {
    mutations.validateCameraOffset(value);
    if (!mutations.shouldApplyCameraOffset(value)) {
      return;
    }
    interruptForExternalMutation();
    mutations.setCameraOffset(value);
  }

  void replaceScene(Object snapshot) {
    mutations.replaceScene(
      snapshot,
      interruptBeforeApply: interruptForExternalMutation,
    );
  }

  void notifySceneChanged() {
    mutations.toString();
  }

  final void Function(String operation) ensureExternalMutationAllowed =
      (String operation) {};

  final void Function() interruptForExternalMutation = () {};

  final storeController = _StoreController();
}

class _StoreController {
  void write(Object fn) {}
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
                'SceneControllerSceneMutations must delegate committed scene '
                'writes through SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects scene mutation owner generic core write bypass', () async {
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
        'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
        '''
class SceneControllerSceneMutations {
  final mutations = Object();

  void write(Object fn) {
    ensureExternalMutationAllowed('write');
    storeController.write<int>(fn);
  }

  void setBackgroundColor(Object value) {
    ensureExternalMutationAllowed('setBackgroundColor');
    mutations.toString();
  }

  void setGridEnabled(bool value) {
    ensureExternalMutationAllowed('setGridEnabled');
    mutations.toString();
  }

  void setGridCellSize(double value) {
    ensureExternalMutationAllowed('setGridCellSize');
    mutations.toString();
  }

  void addNode(Object node) {
    ensureExternalMutationAllowed('addNode');
    mutations.toString();
  }

  void ensureLayer(Object layerId) {
    ensureExternalMutationAllowed('ensureLayer');
    mutations.toString();
  }

  void patchNode(Object patch) {
    ensureExternalMutationAllowed('patchNode');
    mutations.toString();
  }

  void removeNode(Object nodeId) {
    ensureExternalMutationAllowed('removeNode');
    mutations.toString();
  }

  void clearScene() {
    ensureExternalMutationAllowed('clearScene');
    mutations.toString();
  }

  void setCameraOffset(Object value) {
    mutations.validateCameraOffset(value);
    if (!mutations.shouldApplyCameraOffset(value)) {
      return;
    }
    interruptForExternalMutation();
    mutations.setCameraOffset(value);
  }

  void replaceScene(Object snapshot) {
    mutations.replaceScene(
      snapshot,
      interruptBeforeApply: interruptForExternalMutation,
    );
  }

  void notifySceneChanged() {
    mutations.toString();
  }

  void ensureExternalMutationAllowed(String operation) {}

  void interruptForExternalMutation() {}

  final storeController = _Core();
}

class _Core {
  void write<T>(Object fn) {}
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
              'SceneControllerSceneMutations must delegate committed scene '
              'writes through SceneControllerMutationBoundary',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects selection mutation owner store controller write bypass outside mutation boundary',
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
          'lib/src/interactive/internal/scene_controller_selection_mutations.dart',
          '''
class SceneControllerSelectionMutations {
  final mutations = Object();

  void setSelection(Object nodeIds) {
    ensureExternalMutationAllowed('setSelection');
    storeController.commands.writeSelectionReplace(nodeIds);
  }

  void toggleSelection(Object nodeId) {
    ensureExternalMutationAllowed('toggleSelection');
    mutations.toString();
  }

  void clearSelection() {
    ensureExternalMutationAllowed('clearSelection');
    mutations.toString();
  }

  void selectAll() {
    ensureExternalMutationAllowed('selectAll');
    mutations.toString();
  }

  void rotateSelection() {
    ensureExternalMutationAllowed('rotateSelection');
    mutations.toString();
  }

  void flipSelectionVertical() {
    ensureExternalMutationAllowed('flipSelectionVertical');
    mutations.toString();
  }

  void flipSelectionHorizontal() {
    ensureExternalMutationAllowed('flipSelectionHorizontal');
    mutations.toString();
  }

  void deleteSelection() {
    ensureExternalMutationAllowed('deleteSelection');
    mutations.toString();
  }

  void ensureExternalMutationAllowed(String operation) {}

  final storeController = _StoreController();
}

class _StoreController {
  final commands = _Commands();
}

class _Commands {
  void writeSelectionReplace(Object nodeIds) {}
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
                'SceneControllerSelectionMutations must delegate committed '
                'selection writes through SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects selection actions core write bypass outside mutation boundary',
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
          'lib/src/interactive/internal/interactive_selection_actions.dart',
          '''
class InteractiveSelectionActions {
  void rotateSelection() {
    core.write('rotateSelection');
  }

  final core = _Core();
}

class _Core {
  void write(Object operation) {}
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
                'InteractiveSelectionActions must remain a thin routing shell '
                'over SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime selection callbacks that bypass mutation boundary',
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
          'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
          '''
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

class SceneControllerInteractionRuntime {
  void ensurePublicSideEffectAllowed(String operation) {}

  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(PointerSessionToken token) {}

  void releasePointerSessionToken(PointerSessionToken token) {}

  void handlePointerFromSession() {}

  void handleDoubleTapFromSession() {}

  void wireRuntime(Object request, Object mutationBoundary) {
    request.storeController.commands.writeSelectionReplace;
    request.storeController.draw.writeDrawStroke;
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
                'SceneControllerInteractionRuntime must route committed '
                'selection/draw callbacks through '
                'SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects runtime assembly without canonical mutation boundary routing',
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
          'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
          '''
import 'dart:ui';

import '../contract/canvas_pointer_input.dart';
import '../../controller/scene_controller_committed_mutation_access.dart';
import 'interactive_selection_actions.dart';
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

class SceneControllerInteractionRuntimeRequest {
  SceneControllerInteractionRuntimeRequest({
    required this.mutationAccess,
  });

  final SceneControllerCommittedMutationAccess mutationAccess;
}

class SceneControllerInteractionRuntime {
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

  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(PointerSessionToken token) {}

  void releasePointerSessionToken(PointerSessionToken token) {}

  void handlePublicPointer(CanvasPointerInput input) {}

  void handlePublicDoubleTap({required Offset position, int? timestampMs}) {}

  void handlePointerFromSession(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  }) {}

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {}
}

class InteractiveRuntime {
  InteractiveRuntime({required Object callbacks});
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
    callbacks: Object(),
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
                'selection/draw callbacks through '
                'SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects mutation boundary concrete SceneStoreController seam', () async {
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
import '../../controller/scene_store_controller.dart';

class SceneControllerMutationBoundary {
  SceneControllerMutationBoundary(this.storeController);

  final SceneStoreController storeController;

  void clearScene() {
    storeController.commands.writeClearSceneExactResult();
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
              'SceneControllerMutationBoundary must remain the canonical '
              'scene/selection write owner',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects mutation boundary generic store controller write bypass',
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

  void clearScene() {
    storeController.write<void>((writer) {});
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

  void write<T>(Object fn) {}

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
}
