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
          'lib/src/interactive/scene_controller_scene.dart',
          '''
import 'internal/scene_controller_interaction_runtime.dart';

class SceneControllerSceneOwner {
  final SceneControllerInteractionRuntime _runtime =
      SceneControllerInteractionRuntime();
  final _mutationBoundary = _MutationBoundary();

  void write(Object fn) {
    _runtime.ensurePublicSideEffectAllowed('write');
    _ensureExternalMutationAllowed('write');
    storeController.write(fn);
  }

  void setBackgroundColor(Object value) {
    _runtime.ensurePublicSideEffectAllowed('setBackgroundColor');
    _ensureExternalMutationAllowed('setBackgroundColor');
    _mutationBoundary.toString();
  }

  void setGridEnabled(bool value) {
    _runtime.ensurePublicSideEffectAllowed('setGridEnabled');
    _ensureExternalMutationAllowed('setGridEnabled');
    _mutationBoundary.toString();
  }

  void setGridCellSize(double value) {
    _runtime.ensurePublicSideEffectAllowed('setGridCellSize');
    _ensureExternalMutationAllowed('setGridCellSize');
    _mutationBoundary.toString();
  }

  void addNode(Object node) {
    _runtime.ensurePublicSideEffectAllowed('addNode');
    _ensureExternalMutationAllowed('addNode');
    _mutationBoundary.toString();
  }

  void ensureLayer(Object layerId) {
    _runtime.ensurePublicSideEffectAllowed('ensureLayer');
    _ensureExternalMutationAllowed('ensureLayer');
    _mutationBoundary.toString();
  }

  void patchNode(Object patch) {
    _runtime.ensurePublicSideEffectAllowed('patchNode');
    _ensureExternalMutationAllowed('patchNode');
    _mutationBoundary.toString();
  }

  void removeNode(Object nodeId) {
    _runtime.ensurePublicSideEffectAllowed('removeNode');
    _ensureExternalMutationAllowed('removeNode');
    _mutationBoundary.toString();
  }

  void clearScene() {
    _runtime.ensurePublicSideEffectAllowed('clearScene');
    _ensureExternalMutationAllowed('clearScene');
    _mutationBoundary.toString();
  }

  void setCameraOffset(Object value) {
    _runtime.ensurePublicSideEffectAllowed('setCameraOffset');
    _mutationBoundary.validateCameraOffset(value);
    if (!_mutationBoundary.shouldApplyCameraOffset(value)) {
      return;
    }
    _interruptForExternalMutation();
    _mutationBoundary.setCameraOffset(value);
  }

  void replaceScene(Object snapshot) {
    _runtime.ensurePublicSideEffectAllowed('replaceScene');
    _mutationBoundary.replaceScene(
      snapshot,
      interruptBeforeApply: _interruptForExternalMutation,
    );
  }

  void notifySceneChanged() {
    _runtime.ensurePublicSideEffectAllowed('notifySceneChanged');
    _mutationBoundary.notifySceneChanged();
  }

  final void Function(String operation) _ensureExternalMutationAllowed =
      (String operation) {};

  final void Function() _interruptForExternalMutation = () {};

  final storeController = _StoreController();
}

class _StoreController {
  void write(Object fn) {}
}

class _MutationBoundary {
  void validateCameraOffset(Object value) {}

  bool shouldApplyCameraOffset(Object value) => true;

  void setCameraOffset(Object value) {}

  void replaceScene(Object snapshot, {required Object interruptBeforeApply}) {}

  void notifySceneChanged() {}
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
                'SceneControllerSceneOwner must delegate committed scene '
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
        'lib/src/interactive/scene_controller_scene.dart',
        '''
import 'internal/scene_controller_interaction_runtime.dart';

class SceneControllerSceneOwner {
  final SceneControllerInteractionRuntime _runtime =
      SceneControllerInteractionRuntime();
  final _mutationBoundary = _MutationBoundary();

  void write(Object fn) {
    _runtime.ensurePublicSideEffectAllowed('write');
    _ensureExternalMutationAllowed('write');
    storeController.write<int>(fn);
  }

  void setBackgroundColor(Object value) {
    _runtime.ensurePublicSideEffectAllowed('setBackgroundColor');
    _ensureExternalMutationAllowed('setBackgroundColor');
    _mutationBoundary.toString();
  }

  void setGridEnabled(bool value) {
    _runtime.ensurePublicSideEffectAllowed('setGridEnabled');
    _ensureExternalMutationAllowed('setGridEnabled');
    _mutationBoundary.toString();
  }

  void setGridCellSize(double value) {
    _runtime.ensurePublicSideEffectAllowed('setGridCellSize');
    _ensureExternalMutationAllowed('setGridCellSize');
    _mutationBoundary.toString();
  }

  void addNode(Object node) {
    _runtime.ensurePublicSideEffectAllowed('addNode');
    _ensureExternalMutationAllowed('addNode');
    _mutationBoundary.toString();
  }

  void ensureLayer(Object layerId) {
    _runtime.ensurePublicSideEffectAllowed('ensureLayer');
    _ensureExternalMutationAllowed('ensureLayer');
    _mutationBoundary.toString();
  }

  void patchNode(Object patch) {
    _runtime.ensurePublicSideEffectAllowed('patchNode');
    _ensureExternalMutationAllowed('patchNode');
    _mutationBoundary.toString();
  }

  void removeNode(Object nodeId) {
    _runtime.ensurePublicSideEffectAllowed('removeNode');
    _ensureExternalMutationAllowed('removeNode');
    _mutationBoundary.toString();
  }

  void clearScene() {
    _runtime.ensurePublicSideEffectAllowed('clearScene');
    _ensureExternalMutationAllowed('clearScene');
    _mutationBoundary.toString();
  }

  void setCameraOffset(Object value) {
    _runtime.ensurePublicSideEffectAllowed('setCameraOffset');
    _mutationBoundary.validateCameraOffset(value);
    if (!_mutationBoundary.shouldApplyCameraOffset(value)) {
      return;
    }
    _interruptForExternalMutation();
    _mutationBoundary.setCameraOffset(value);
  }

  void replaceScene(Object snapshot) {
    _runtime.ensurePublicSideEffectAllowed('replaceScene');
    _mutationBoundary.replaceScene(
      snapshot,
      interruptBeforeApply: _interruptForExternalMutation,
    );
  }

  void notifySceneChanged() {
    _runtime.ensurePublicSideEffectAllowed('notifySceneChanged');
    _mutationBoundary.notifySceneChanged();
  }

  void _ensureExternalMutationAllowed(String operation) {}

  void _interruptForExternalMutation() {}

  final storeController = _Core();
}

class _Core {
  void write<T>(Object fn) {}
}

class _MutationBoundary {
  void validateCameraOffset(Object value) {}

  bool shouldApplyCameraOffset(Object value) => true;

  void setCameraOffset(Object value) {}

  void replaceScene(Object snapshot, {required Object interruptBeforeApply}) {}

  void notifySceneChanged() {}
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
              'SceneControllerSceneOwner must delegate committed scene '
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
          'lib/src/interactive/scene_controller_selection.dart',
          '''
import 'internal/scene_controller_interaction_runtime.dart';

class SceneControllerSelectionOwner {
  final SceneControllerInteractionRuntime _runtime =
      SceneControllerInteractionRuntime();
  final _mutationBoundary = _MutationBoundary();
  final _sceneCommands = _Commands();

  void setSelection(Object nodeIds) {
    _runtime.ensurePublicSideEffectAllowed('setSelection');
    _ensureExternalMutationAllowed('setSelection');
    _sceneCommands.writeSelectionReplaceExactResult(nodeIds);
  }

  void toggleSelection(Object nodeId) {
    _runtime.ensurePublicSideEffectAllowed('toggleSelection');
    _ensureExternalMutationAllowed('toggleSelection');
    _mutationBoundary.toString();
  }

  void clearSelection() {
    _runtime.ensurePublicSideEffectAllowed('clearSelection');
    _ensureExternalMutationAllowed('clearSelection');
    _mutationBoundary.toString();
  }

  void selectAll() {
    _runtime.ensurePublicSideEffectAllowed('selectAll');
    _ensureExternalMutationAllowed('selectAll');
    _mutationBoundary.toString();
  }

  void rotateSelection() {
    _runtime.ensurePublicSideEffectAllowed('rotateSelection');
    _ensureExternalMutationAllowed('rotateSelection');
    _mutationBoundary.toString();
  }

  void flipSelectionVertical() {
    _runtime.ensurePublicSideEffectAllowed('flipSelectionVertical');
    _ensureExternalMutationAllowed('flipSelectionVertical');
    _mutationBoundary.toString();
  }

  void flipSelectionHorizontal() {
    _runtime.ensurePublicSideEffectAllowed('flipSelectionHorizontal');
    _ensureExternalMutationAllowed('flipSelectionHorizontal');
    _mutationBoundary.toString();
  }

  void deleteSelection() {
    _runtime.ensurePublicSideEffectAllowed('deleteSelection');
    _ensureExternalMutationAllowed('deleteSelection');
    _mutationBoundary.toString();
  }

  void _ensureExternalMutationAllowed(String operation) {}

  final storeController = _StoreController();
}

class _StoreController {
}

class _Commands {
  Object? writeSelectionReplaceExactResult(Object nodeIds) => null;
}

class _MutationBoundary {}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerSelectionOwner must delegate committed '
                'selection writes through SceneControllerMutationBoundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects reintroduced runtime selection actions shell', () async {
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
              'InteractiveSelectionActions is a deleted routing shell and '
              'must not exist',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

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

  void registerPointerSession(
    Object session, {
    required PointerSessionToken token,
  }) {}

  void detachPointerSession(PointerSessionToken token) {}

  void releasePointerSessionToken(PointerSessionToken token) {}

  void handlePointerFromSession() {}

  void handleDoubleTapFromSession() {}

  void wireRuntime(Object request, Object mutationBoundary) {
    request.sceneCommands.writeSelectionReplace;
    request.drawCommands.writeDrawStroke;
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
    required this.runtime,
  });

  final SceneControllerMutationBoundary mutationBoundary;
  final InteractiveRuntime runtime;

  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}

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
  final interactiveRuntime = _createInteractiveRuntime(
    request,
    mutationBoundary: mutationBoundary,
  );
  return SceneControllerInteractionRuntime._(
    mutationBoundary: mutationBoundary,
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
  final _sceneCommands = _Commands();

  void clearScene() {
    _sceneCommands.writeClearSceneExactResult();
  }
}

class _Commands {
  void writeClearSceneExactResult() {}
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
  final _sceneCommands = _Commands();
  final _drawCommands = _Draw();

  void clearScene() {
    storeController.write<void>((writer) {});
  }

  void setSelection(Object nodeIds) {
    _sceneCommands.writeSelectionReplaceExactResult(nodeIds);
  }

  void clearSelection() {
    _sceneCommands.writeSelectionClearExactChange();
  }

  void deleteSelection() {
    _sceneCommands.writeDeleteSelection();
  }

  void transformSelection(Object delta) {
    _sceneCommands.writeSelectionTransform(delta);
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
    return _drawCommands.writeDrawStroke(payload);
  }

  Object commitDrawLineFromWorldSegment(Object payload) {
    return _drawCommands.writeDrawLineFromWorldSegment(payload);
  }

  int commitEraseNodes(Object ids) {
    return _drawCommands.writeEraseNodes(ids);
  }
}

class _Core {
  void write<T>(Object fn) {}

  Object prepareSceneReplacement(Object snapshot) => snapshot;

  void writePreparedSceneReplacement(Object replacement) {}
}

class _Commands {
  Object? writeSelectionReplaceExactResult(Object nodeIds) => null;

  bool writeSelectionClearExactChange() => false;

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
