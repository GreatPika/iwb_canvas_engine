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
          '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';

class SceneController {
  SceneController() : _graph = Object();

  final dynamic _graph;

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
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
          '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';

class SceneController {
  final dynamic _graph = createSceneControllerGraph(
    SceneControllerGraphRequest(),
  );

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

Object createSceneControllerGraph(Object request) => Object();

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
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
          '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';

class SceneController {
  final dynamic _graph = createSceneControllerGraph(
    SceneControllerGraphRequest(),
  );

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

class SceneControllerGraphRequest {}

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
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
          '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';
import 'internal/scene_controller_graph_shadow.dart' as shadow;

class SceneController {
  final dynamic _graph = shadow.createSceneControllerGraph(
    shadow.SceneControllerGraphRequest(),
  );

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
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
        'lib/src/interactive/internal/scene_controller_graph.dart',
        '''
import 'scene_controller_internal_access.dart';
import 'scene_controller_scene_view_runtime.dart';

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

class _Graph {
  _Graph({
    required this.sceneViewRuntime,
    required this.internalAccessRegistration,
  });

  final SceneControllerSceneViewRuntime sceneViewRuntime;
  final SceneControllerInternalAccessRegistration internalAccessRegistration;
}

Object createSceneControllerGraph(Object request) {
  final graph = _assembleSceneControllerGraph(request);
  registerSceneControllerInternalAccess(Object(), graph.internalAccessRegistration);
  return graph;
}

_Graph _assembleSceneControllerGraph(Object request) {
  final interactionRuntime = _InteractionRuntime();
  final interaction = SceneControllerInteractionOwner();
  final selection = SceneControllerSelectionOwner(interactionRuntime);
  final scene = SceneControllerSceneOwner(
    interactionRuntime.ensurePublicSideEffectAllowed,
  );
  interaction.toString();
  selection.toString();
  scene.toString();
  return _Graph(
    sceneViewRuntime: SceneControllerSceneViewRuntime(
      ensurePublicSideEffectAllowed:
          interactionRuntime.ensurePublicSideEffectAllowed,
    ),
    internalAccessRegistration: SceneControllerInternalAccessRegistration(),
  );
}

Object sceneControllerGraphActions(Object graph) => Object();

Object sceneControllerGraphEditTextRequests(Object graph) => Object();
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
    'rejects facade when SceneController becomes SceneViewRenderState',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'internal/scene_controller_graph.dart';

class SceneController implements SceneViewRenderState {
  SceneController() {
    _graph = createSceneControllerGraph(SceneControllerGraphRequest());
  }

  late final dynamic _graph;

  Object get actions => sceneControllerGraphActions(_graph);
  Object get editTextRequests => sceneControllerGraphEditTextRequests(_graph);

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
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
    final renderState = _activeRuntime.renderState;
    return SceneViewRenderSurface(renderState: renderState);
  }
}

class StatefulWidget {}

class SceneViewRuntime {
  Object get renderState => Object();

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
    required Object renderState,
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
