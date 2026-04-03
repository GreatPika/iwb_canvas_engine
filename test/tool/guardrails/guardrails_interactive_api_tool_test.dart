@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/guardrails_tool_test_support.dart';
import '../support/tool_process_test_support.dart';

void main() {
  group('tool/check_guardrails.dart', () {
    _registerInteractiveAcceptanceTests();
    _registerInteractiveGuardViolationTests();
    _registerInteractiveDisposeGuardTests();
    _registerCapabilityGuardViolationTests();
    _registerInteractiveArchitectureGuardrailTests();
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

void _registerInteractiveAcceptanceTests() {
  // INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
  test(
    'accepts guarded public interactive entrypoints in SceneController',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            extraMembers: '\n  int get value => 1;\n',
            methods: '''
  void handlePointer() {
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

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('accepts guarded multiline interactive entrypoint signatures', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
          methods: '''
  void handlePointer(
    int value,
  ) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(
    int value,
  ) {
    _ensurePublicSideEffectAllowed('mode');
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
}

void _registerInteractiveGuardViolationTests() {
  test(
    'rejects public interactive method without resolver purity guard',
    () async {
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
    print('missing guard');
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
                'public SceneController entrypoints must guard '
                'resolver purity with _ensurePublicSideEffectAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}

void _registerCapabilityGuardViolationTests() {
  test(
    'rejects public interaction method without resolver purity guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
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
          'lib/src/interactive/scene_controller_interaction.dart',
          '''
class SceneControllerInteraction {
  void handlePointer() {
    print('missing guard');
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
                'public SceneControllerInteraction entrypoints must guard '
                'resolver purity with '
                '_access.runtime.ensurePublicSideEffectAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects public scene mutation without resolver purity guard', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
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
class SceneControllerScene {
  void write(Object fn) {
    print('missing guard');
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
              'public SceneControllerScene entrypoints must guard '
              'resolver purity with ensurePublicSideEffectAllowed',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects selection mutation owner without active gesture guard', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
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
        interactiveSelectionMutationsFixture(
          setSelectionBody: "print('missing guard');",
        ),
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneControllerSelectionMutations.setSelection must guard '
              'active-gesture exclusivity with '
              'ensureExternalMutationAllowed',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects scene mutation owner write without active gesture guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
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
          interactiveSceneMutationsFixture(
            writeBody: "print('missing guard');",
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerSceneMutations.write must guard '
                'active-gesture exclusivity with '
                'ensureExternalMutationAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects reset-listed scene mutation using deny policy', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
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
        interactiveSceneMutationsFixture(
          setCameraOffsetBody: '''
_requireFiniteOffset(value);
if (_isSameOffset(value)) {
  return;
}
ensureExternalMutationAllowed('setCameraOffset');
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
              'SceneControllerSceneMutations.setCameraOffset must guard '
              'active-gesture exclusivity with '
              'resetActiveGestureBeforeExternalMutation',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects mutation-owner helper bypass for scene.write', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
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
  void write(Object fn) {
    _guardExternal('write');
  }

  void setBackgroundColor(Object value) {
    ensureExternalMutationAllowed('setBackgroundColor');
  }

  void setGridEnabled(bool value) {
    ensureExternalMutationAllowed('setGridEnabled');
  }

  void setGridCellSize(double value) {
    ensureExternalMutationAllowed('setGridCellSize');
  }

  void addNode(Object node) {
    ensureExternalMutationAllowed('addNode');
  }

  void ensureLayer(Object layerId) {
    ensureExternalMutationAllowed('ensureLayer');
  }

  void patchNode(Object patch) {
    ensureExternalMutationAllowed('patchNode');
  }

  void removeNode(Object nodeId) {
    ensureExternalMutationAllowed('removeNode');
  }

  void clearScene() {
    ensureExternalMutationAllowed('clearScene');
  }

  void setCameraOffset(Object value) {
    _requireFiniteOffset(value);
    if (_isSameOffset(value)) {
      return;
    }
    resetActiveGestureBeforeExternalMutation();
  }

  void replaceScene(Object snapshot) {
    validateSnapshot(snapshot);
    resetActiveGestureBeforeExternalMutation();
  }

  void _guardExternal(String operation) {
    ensureExternalMutationAllowed(operation);
  }

  void ensureExternalMutationAllowed(String operation) {}

  void resetActiveGestureBeforeExternalMutation() {}

  void _requireFiniteOffset(Object value) {}

  bool _isSameOffset(Object value) => false;

  void validateSnapshot(Object snapshot) {}
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
              'SceneControllerSceneMutations.write must guard '
              'active-gesture exclusivity with '
              'ensureExternalMutationAllowed',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });
}

void _registerInteractiveDisposeGuardTests() {
  test(
    'rejects dispose without allowAfterDispose true in purity guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
            methods: '''
  void dispose() {
    _ensurePublicSideEffectAllowed('dispose');
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
                'dispose() must guard resolver purity with '
                'allowAfterDispose: true',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}

void _registerInteractiveArchitectureGuardrailTests() {
  test('accepts final interactive boundary shape', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
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
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects retained scene access seam', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
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
        'lib/src/interactive/internal/scene_controller_scene_access.dart',
        'class SceneControllerSceneAccessAdapter {}\n',
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr.toString(),
        diagnostic(
          category: 'interactive API',
          detail:
              'SceneControllerSceneAccessAdapter is a deleted residual seam '
              'and must not exist',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects interaction snapshot leak', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
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
        'lib/src/interactive/scene_controller_interaction.dart',
        '''
import '../contract/snapshot.dart';

class SceneControllerInteraction {
  final _access = _Access();

  SceneSnapshot get snapshot => _access.snapshot;
}

class _Access {
  SceneSnapshot get snapshot => throw UnimplementedError();
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
              'SceneControllerInteraction must not expose committed '
              'render-state through snapshot',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects facade that directly imports draw-local owner', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
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
          _sceneControllerFixture(
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
    _requireFiniteOffset(value);
    if (_isSameOffset(value)) {
      return;
    }
    resetActiveGestureBeforeExternalMutation();
    mutations.toString();
  }

  void replaceScene(Object snapshot) {
    ensureExternalMutationAllowed('replaceScene');
    resetActiveGestureBeforeExternalMutation();
    mutations.toString();
  }

  void notifySceneChanged() {
    mutations.toString();
  }

  void ensureExternalMutationAllowed(String operation) {}

  void resetActiveGestureBeforeExternalMutation() {}

  void _requireFiniteOffset(Object value) {}

  bool _isSameOffset(Object value) => false;

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
        _sceneControllerFixture(
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
    _requireFiniteOffset(value);
    if (_isSameOffset(value)) {
      return;
    }
    resetActiveGestureBeforeExternalMutation();
    mutations.toString();
  }

  void replaceScene(Object snapshot) {
    ensureExternalMutationAllowed('replaceScene');
    resetActiveGestureBeforeExternalMutation();
    mutations.toString();
  }

  void notifySceneChanged() {
    mutations.toString();
  }

  void ensureExternalMutationAllowed(String operation) {}

  void resetActiveGestureBeforeExternalMutation() {}

  void _requireFiniteOffset(Object value) {}

  bool _isSameOffset(Object value) => false;

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
    'rejects runtime selection callbacks that bypass mutation boundary',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
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
import 'scene_controller_mutation_boundary.dart';

class SceneControllerInteractionRuntime {
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
    'rejects mutation boundary generic store controller write bypass',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          _sceneControllerFixture(
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
          _sceneControllerFixture(
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
        _sceneControllerFixture(
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
        _sceneControllerFixture(
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
        _sceneControllerFixture(
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

  test('rejects missing required split-owner file', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller.dart',
        _sceneControllerFixture(
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
}
