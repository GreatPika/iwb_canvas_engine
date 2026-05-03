part of '../../guardrails_interactive_api_tool_test.dart';

void _registerInteractiveArchitectureBoundaryOwnerAndMutationBoundaryTests() {
  test(
    'rejects pointer host that installs a non-next session after releasing current',
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
          'lib/src/view/scene_view_interactive_pointer_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'scene_view_pointer_router.dart';

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({
    required SceneViewPointerSession pointerSession,
  }) : _runtime = _SceneViewInteractivePointerRuntime(
         pointerSession: pointerSession,
       );

  final _SceneViewInteractivePointerRuntime _runtime;

  int get debugLiveRawPointerCount => _runtime.debugLiveRawPointerCount;
  int? get debugPendingTapFlushTimestampMs =>
      _runtime.debugPendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession pointerSession) {
    _runtime.replacePointerSession(pointerSession);
  }

  void dispose() {
    _runtime.dispose();
  }
}

class _SceneViewInteractivePointerRuntime {
  _SceneViewInteractivePointerRuntime({
    required SceneViewPointerSession pointerSession,
  }) : _pointerSession = pointerSession;

  final SceneViewPointerRouter _pointerRouter = SceneViewPointerRouter();
  final SceneViewPointerSession _sentinel = _DisposedSceneViewPointerSession();
  SceneViewPointerSession _pointerSession;

  int get debugLiveRawPointerCount => 0;
  int? get debugPendingTapFlushTimestampMs =>
      _pointerSession.pendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession next) {
    final current = _pointerSession;
    current.detach();
    current.dispose();
    _pointerRouter.reset();
    _pointerSession = _sentinel;
  }

  void dispose() {
    _pointerSession.detach();
    _pointerSession.dispose();
  }
}

class _DisposedSceneViewPointerSession implements SceneViewPointerSession {
  @override
  int? get pendingTapFlushTimestampMs => null;

  @override
  void detach() {}

  @override
  void dispose() {}

  @override
  void handleInvalidTerminalSample({
    required Object input,
    required int pointerId,
    required int referenceTimestampMs,
  }) {}

  @override
  void handleRawPointerRelease({required bool isIdleAfterRelease}) {}

  @override
  void handleRoutedSample(Object sample, {required bool shouldTrackSignals}) {}
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
                'SceneViewInteractivePointerHost must remain a raw '
                'routing/lifecycle shell over pointer sessions',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects pointer host that overwrites next session after canonical install',
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
          'lib/src/view/scene_view_interactive_pointer_host.dart',
          '''
import '../contract/scene_view_runtime.dart';
import 'scene_view_pointer_router.dart';

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({
    required SceneViewPointerSession pointerSession,
  }) : _runtime = _SceneViewInteractivePointerRuntime(
         pointerSession: pointerSession,
       );

  final _SceneViewInteractivePointerRuntime _runtime;

  int get debugLiveRawPointerCount => _runtime.debugLiveRawPointerCount;
  int? get debugPendingTapFlushTimestampMs =>
      _runtime.debugPendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession pointerSession) {
    _runtime.replacePointerSession(pointerSession);
  }

  void dispose() {
    _runtime.dispose();
  }
}

class _SceneViewInteractivePointerRuntime {
  _SceneViewInteractivePointerRuntime({
    required SceneViewPointerSession pointerSession,
  }) : _pointerSession = pointerSession;

  final SceneViewPointerRouter _pointerRouter = SceneViewPointerRouter();
  final SceneViewPointerSession _sentinel = _DisposedSceneViewPointerSession();
  SceneViewPointerSession _pointerSession;

  int get debugLiveRawPointerCount => 0;
  int? get debugPendingTapFlushTimestampMs =>
      _pointerSession.pendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession next) {
    final current = _pointerSession;
    current.detach();
    current.dispose();
    _pointerRouter.reset();
    _pointerSession = next;
    _pointerSession = _sentinel;
  }

  void dispose() {
    _pointerSession.detach();
    _pointerSession.dispose();
  }
}

class _DisposedSceneViewPointerSession implements SceneViewPointerSession {
  @override
  int? get pendingTapFlushTimestampMs => null;

  @override
  void detach() {}

  @override
  void dispose() {}

  @override
  void handleInvalidTerminalSample({
    required Object input,
    required int pointerId,
    required int referenceTimestampMs,
  }) {}

  @override
  void handleRawPointerRelease({required bool isIdleAfterRelease}) {}

  @override
  void handleRoutedSample(Object sample, {required bool shouldTrackSignals}) {}
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
                'SceneViewInteractivePointerHost must remain a raw '
                'routing/lifecycle shell over pointer sessions',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'accepts runtime host render-state bridge routed through owner-local getter',
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
import '../contract/scene_view_runtime.dart';
import 'scene_view_interactive_overlay_painter.dart';
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;

  SceneViewRuntimeHost({required this.runtime});
}

class _SceneViewRuntimeHostState {
  late final SceneViewInteractivePointerHost _pointerHost;
  late SceneViewRuntime _activeRuntime;

  SceneViewMainSceneRenderRead get _mainSceneRenderReadForBuild =>
      _activeRuntime.mainSceneRenderRead;

  SceneViewOverlayPreviewRead get _overlayPreviewReadForBuild =>
      _activeRuntime.overlayPreviewRead;

  void initState() {
    _activeRuntime = widget.runtime;
    _pointerHost = SceneViewInteractivePointerHost(
      pointerSession: _activeRuntime.createPointerSession(
        isMounted: () => true,
        hasLiveRawPointers: () => false,
      ),
    );
  }

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeRuntime == widget.runtime) {
      return;
    }
    final nextPointerSession = _createReplacementPointerSession(widget.runtime);
    _pointerHost.replacePointerSession(nextPointerSession);
    _activeRuntime = widget.runtime;
  }

  Object build() {
    return _SceneViewRuntimeHostShell(
      foregroundPainter: SceneViewInteractiveOverlayPainter(
        overlayPreviewRead: _overlayPreviewReadForBuild,
      ),
      child: SceneViewRenderSurface(
        mainSceneRenderRead: _mainSceneRenderReadForBuild,
      ),
    );
  }

  SceneViewPointerSession _createReplacementPointerSession(
    SceneViewRuntime runtime,
  ) {
    return runtime.createPointerSession(
      isMounted: () => true,
      hasLiveRawPointers: () => false,
    );
  }
}

class StatefulWidget {}

class _SceneViewRuntimeHostShell {
  _SceneViewRuntimeHostShell({
    required this.foregroundPainter,
    required this.child,
  });

  final Object foregroundPainter;
  final Object child;
}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects SceneViewInteractive bridge routed through local runtime host shadow',
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
          'lib/src/view/scene_view_interactive.dart',
          '''
import '../interactive/scene_controller.dart';
import 'scene_view_runtime_host.dart';

class SceneViewInteractive {
  SceneViewInteractive({required this.controller});

  final SceneController controller;

  Object build(Object context) {
    return SceneViewRuntimeHost(
      runtime: sceneControllerViewRuntimeOf(controller),
    );
  }
}

class SceneViewRuntimeHost {
  SceneViewRuntimeHost({required Object runtime});
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
                'SceneViewInteractive must remain a thin public shell over '
                'SceneViewRuntimeHost',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'accepts SceneViewInteractive bridge routed through owner-local getter',
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
          'lib/src/view/scene_view_interactive.dart',
          '''
import '../contract/scene_view_runtime.dart';
import '../interactive/scene_controller.dart';
import 'scene_view_runtime_host.dart';

class SceneViewInteractive {
  SceneViewInteractive({required this.controller});

  final SceneController controller;

  SceneViewRuntime get _runtime => sceneControllerViewRuntimeOf(controller);

  Object build(Object context) {
    return SceneViewRuntimeHost(runtime: _runtime);
  }
}
''',
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects render surface that takes concrete SceneController owner',
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
import '../contract/scene_view_runtime.dart';
import '../interactive/scene_controller.dart';

class SceneViewRenderSurface {
  SceneViewRenderSurface({
    required SceneController renderState,
  }) : _renderState = renderState;

  final SceneController _renderState;

  State<SceneViewRenderSurface> createState() => SceneViewRenderSurfaceState();
}

class SceneViewRenderSurfaceState extends State<SceneViewRenderSurface> {
  void initState() {
    widget._renderState.addListener(_handleControllerChanged);
  }

  void didUpdateWidget(SceneViewRenderSurface oldWidget) {
    oldWidget._renderState.removeListener(_handleControllerChanged);
    widget._renderState.addListener(_handleControllerChanged);
  }

  void dispose() {
    widget._renderState.removeListener(_handleControllerChanged);
  }

  Object build(Object context) => Object();

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
                'SceneViewRenderSurface must remain a render-state-only view '
                'surface',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}
