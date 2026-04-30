part of '../../guardrails_interactive_api_tool_test.dart';

void _registerInteractiveArchitectureBoundaryViewAndGraphTests() {
  // INV:INV-ENG-PREPARED-REPLACE-SCENE-BOUNDARY-HERMETICITY
  test('accepts final interactive boundary shape', () async {
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

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects graph assembly that receives a prebuilt store', () async {
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
        'lib/src/interactive/internal/scene_controller_graph.dart',
        '''
import '../../controller/scene_controller_committed_mutation_access.dart';
import '../../controller/scene_store_controller.dart';
import 'package:flutter/foundation.dart';
import '../scene_controller_interaction.dart';
import '../scene_controller_scene.dart';
import '../scene_controller_selection.dart';
import 'scene_controller_internal_access.dart';
import 'scene_controller_interaction_config.dart';
import 'scene_controller_interaction_runtime.dart';
import 'scene_controller_scene_view_runtime.dart';

class SceneControllerGraphRequest {
  SceneStoreController? storeController;
}

class SceneControllerGraphHandle {
  SceneControllerGraphHandle({
    required this.storeController,
    required this.sceneViewRuntime,
    required this.internalAccessRegistration,
  });

  final SceneStoreController storeController;
  final SceneControllerSceneViewRuntime sceneViewRuntime;
  final SceneControllerInternalAccessRegistration internalAccessRegistration;

  Object get actions => Object();

  Object get editTextRequests => Object();
}

SceneControllerGraphHandle createSceneControllerGraph(Object request) {
  final graph = _assembleSceneControllerGraph(request as SceneControllerGraphRequest);
  registerSceneControllerInternalAccess(Object(), graph.internalAccessRegistration);
  return graph;
}

SceneControllerGraphHandle _assembleSceneControllerGraph(
  SceneControllerGraphRequest request,
) {
  final storeController = request.storeController!;
  final interactionConfig = SceneControllerInteractionConfig();
  final interactionRuntime = createSceneControllerInteractionRuntime(
    request: SceneControllerInteractionRuntimeRequest(
      mutationAccess: SceneStoreControllerCommittedMutationAccess(),
    ),
  );
  final interaction = SceneControllerInteractionOwner(
    ownerListenable: ChangeNotifier(),
    config: interactionConfig,
    runtime: interactionRuntime,
    clearSelectionOnDrawModeEnter: true,
    hasSelection: () => false,
    clearSelectionState: () {},
  );
  final selection = SceneControllerSelectionOwner(
    runtime: interactionRuntime,
    mutationBoundary: interactionRuntime.mutationBoundary,
  );
  final scene = SceneControllerSceneOwner(
    runtime: interactionRuntime,
    mutationBoundary: interactionRuntime.mutationBoundary,
  );
  interaction.toString();
  selection.toString();
  scene.toString();
  return SceneControllerGraphHandle(
    storeController: storeController,
    sceneViewRuntime: SceneControllerSceneViewRuntime(
      ensurePublicSideEffectAllowed:
          interactionRuntime.ensurePublicSideEffectAllowed,
    ),
    internalAccessRegistration: SceneControllerInternalAccessRegistration(),
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
              'SceneController graph must assemble view runtime and '
              'internal access outside the facade',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects production committed mutation access assembly outside graph root',
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
          'lib/src/interactive/internal/rogue_mutation_access.dart',
          '''
import '../../controller/scene_controller_committed_mutation_access.dart';

Object createRogueCommittedMutationAccess() {
  return SceneStoreControllerCommittedMutationAccess();
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
                'SceneStoreControllerCommittedMutationAccess must be '
                'assembled only by the SceneController graph composition root',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'accepts facade-to-view runtime bridge with render-state-only view surface',
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

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects facade that skips canonical createSceneControllerGraph assembly',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            graphMembers: '''
  SceneController() : _graph = Object();

  final dynamic _graph;
''',
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
    },
  );

  test(
    'rejects facade that routes graph assembly through local createSceneControllerGraph shadow',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            graphMembers: '''
  final dynamic _graph = createSceneControllerGraph(
    SceneControllerGraphRequest(),
  );
''',
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
            extraDeclarations:
                '\nObject createSceneControllerGraph(Object request) => Object();\n',
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
    },
  );

  test(
    'rejects facade that builds graph with local SceneControllerGraphRequest shadow',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            graphMembers: '''
  final dynamic _graph = createSceneControllerGraph(
    SceneControllerGraphRequest(),
  );
''',
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
            extraDeclarations: '\nclass SceneControllerGraphRequest {}\n',
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
    },
  );

  test(
    'rejects facade that routes graph assembly through imported shadow owners',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/internal/scene_controller_graph_shadow.dart',
          '''
class SceneControllerGraphRequest {}

Object createSceneControllerGraph(Object request) => Object();
''',
        );
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            extraImports:
                "import 'internal/scene_controller_graph_shadow.dart' as shadow;",
            graphMembers: '''
  final dynamic _graph = shadow.createSceneControllerGraph(
    shadow.SceneControllerGraphRequest(),
  );
''',
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
    },
  );

  test('rejects graph assembly that declares local owner shadows', () async {
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
        'lib/src/interactive/internal/scene_controller_graph.dart',
        '''
import 'scene_controller_internal_access.dart';
import 'scene_controller_scene_view_runtime.dart';
import '../../controller/scene_store_controller.dart';

class SceneControllerInteractionOwner {}

class SceneControllerSelectionOwner {
  SceneControllerSelectionOwner(Object runtime);
}

class SceneControllerSceneOwner {
  SceneControllerSceneOwner(Object ensurePublicSideEffectAllowed);
}

class SceneControllerGraphRequest {}

class SceneControllerSceneViewRuntime {
  SceneControllerSceneViewRuntime({
    Object? ensurePublicSideEffectAllowed,
  });
}

class _InteractionRuntime {
  void ensurePublicSideEffectAllowed(String operation) {}
}

class SceneControllerGraphHandle {
  SceneControllerGraphHandle({
    required this.storeController,
    required this.sceneViewRuntime,
    required this.internalAccessRegistration,
  });

  final SceneStoreController storeController;
  final SceneControllerSceneViewRuntime sceneViewRuntime;
  final SceneControllerInternalAccessRegistration internalAccessRegistration;
}

SceneControllerGraphHandle createSceneControllerGraph(Object request) {
  final graph = _assembleSceneControllerGraph(request);
  registerSceneControllerInternalAccess(Object(), graph.internalAccessRegistration);
  return graph;
}

SceneControllerGraphHandle _assembleSceneControllerGraph(Object request) {
  final storeController = SceneStoreController();
  final interactionRuntime = _InteractionRuntime();
  final interaction = SceneControllerInteractionOwner();
  final selection = SceneControllerSelectionOwner(interactionRuntime);
  final scene = SceneControllerSceneOwner(
    interactionRuntime.ensurePublicSideEffectAllowed,
  );
  interaction.toString();
  selection.toString();
  scene.toString();
  return SceneControllerGraphHandle(
    storeController: storeController,
    sceneViewRuntime: SceneControllerSceneViewRuntime(
      ensurePublicSideEffectAllowed:
          interactionRuntime.ensurePublicSideEffectAllowed,
    ),
    internalAccessRegistration: SceneControllerInternalAccessRegistration(),
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
              'SceneController graph must assemble view runtime and '
              'internal access outside the facade',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test(
    'rejects facade when SceneController becomes SceneViewMainSceneRenderRead',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            classDeclaration:
                'class SceneController implements SceneViewMainSceneRenderRead {',
            graphMembers: '''
  SceneController() {
    _graph = createSceneControllerGraph(SceneControllerGraphRequest());
  }

  late final dynamic _graph;
''',
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
    },
  );

  test(
    'rejects facade when SceneController becomes SceneViewOverlayPreviewRead',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          sceneControllerFixture(
            classDeclaration:
                'class SceneController implements SceneViewOverlayPreviewRead {',
            graphMembers: '''
  SceneController() {
    _graph = createSceneControllerGraph(SceneControllerGraphRequest());
  }

  late final dynamic _graph;
''',
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
    },
  );

  test(
    'rejects runtime host that stops owning replacement pointer-session creation',
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
          'lib/src/view/scene_view_runtime_host.dart',
          '''
class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;

  SceneViewRuntimeHost({required this.runtime});
}

class _SceneViewRuntimeHostState {
  late final SceneViewInteractivePointerHost _pointerHost;
  late SceneViewRuntime _activeRuntime;

  void initState() {
    _activeRuntime = widget.runtime;
    _pointerHost = SceneViewInteractivePointerHost(
      pointerSession: _activeRuntime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      ),
    );
  }

  Object build() {
    final renderState = _activeRuntime.mainSceneRenderRead;
    return SceneViewRenderSurface(mainSceneRenderRead: renderState);
  }
}

class StatefulWidget {}

class SceneViewRuntime {
  Object get mainSceneRenderRead => Object();

  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    return SceneViewPointerSession();
  }
}

class SceneViewPointerSession {}

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({required SceneViewPointerSession pointerSession});
}

class SceneViewRenderSurface {
  SceneViewRenderSurface({
    required Object mainSceneRenderRead,
  });
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
                'SceneViewRuntimeHost must remain the active-runtime and '
                'pointer-host owner for the view boundary',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}
