part of '../../guardrails_interactive_api_tool_test.dart';

void _registerInteractiveArchitectureBoundaryViewSurfaceAndRuntimeTests() {
  test(
    'rejects render surface that shadows the SceneViewMainSceneRenderRead contract locally',
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

class SceneViewMainSceneRenderRead {
  void addListener(Object listener) {}

  void removeListener(Object listener) {}
}

class SceneViewRenderSurface {
  SceneViewRenderSurface({
    required SceneViewMainSceneRenderRead mainSceneRenderRead,
  }) : _mainSceneRenderRead = mainSceneRenderRead;

  final SceneViewMainSceneRenderRead _mainSceneRenderRead;

  State<SceneViewRenderSurface> createState() => SceneViewRenderSurfaceState();
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

  test(
    'rejects render surface that subscribes listeners outside widget mainSceneRenderRead',
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

class SceneViewRenderSurface {
  SceneViewRenderSurface({
    required SceneViewMainSceneRenderRead mainSceneRenderRead,
  }) : _mainSceneRenderRead = mainSceneRenderRead;

  final SceneViewMainSceneRenderRead _mainSceneRenderRead;
  final SceneViewMainSceneRenderRead _otherRenderState = SceneControllerSceneViewMainSceneRenderRead();
}

class SceneViewRenderSurfaceState extends State<SceneViewRenderSurface> {
  void initState() {
    super.initState();
    widget._otherRenderState.addListener(_handleControllerChanged);
  }

  void didUpdateWidget(SceneViewRenderSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget._otherRenderState.removeListener(_handleControllerChanged);
    widget._otherRenderState.addListener(_handleControllerChanged);
  }

  void dispose() {
    widget._otherRenderState.removeListener(_handleControllerChanged);
  }

  Object build(Object context) => Object();

  void _handleControllerChanged() {}
}

class SceneControllerSceneViewMainSceneRenderRead implements SceneViewMainSceneRenderRead {
  @override
  void addListener(Object listener) {}

  @override
  void removeListener(Object listener) {}
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

  test(
    'rejects scene view runtime that shadows SceneControllerPointerSession locally',
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
          'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
          '''
import '../../contract/scene_view_runtime.dart';
import 'scene_controller_pointer_session.dart';
import 'pointer_session_token.dart';

final class SceneControllerSceneViewRuntime implements SceneViewRuntime {
  SceneControllerSceneViewRuntime({
    Object? ensurePublicSideEffectAllowed,
  });

  @override
  final mainSceneRenderRead = SceneControllerSceneViewMainSceneRenderRead();
  final _interactionRuntime = SceneControllerInteractionRuntime();

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    return SceneControllerPointerSession(
      token: _interactionRuntime.createPointerSessionToken(),
      detachPointerSession: _interactionRuntime.detachPointerSession,
      releasePointerSessionToken: _interactionRuntime.releasePointerSessionToken,
      handlePointerFromSession: _interactionRuntime.handlePointerFromSession,
      handleDoubleTapFromSession:
          _interactionRuntime.handleDoubleTapFromSession,
    );
  }
}

class SceneControllerPointerSession implements SceneViewPointerSession {
  SceneControllerPointerSession({
    required Object token,
    required Object detachPointerSession,
    required Object releasePointerSessionToken,
    required Object handlePointerFromSession,
    required Object handleDoubleTapFromSession,
  });
}

class SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(Object token) {}

  void releasePointerSessionToken(Object token) {}

  void handlePointerFromSession() {}

  void handleDoubleTapFromSession() {}
}

class SceneControllerSceneViewMainSceneRenderRead implements SceneViewMainSceneRenderRead {
  @override
  void addListener(Object listener) {}

  @override
  void removeListener(Object listener) {}
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
                'SceneControllerSceneViewRuntime must own the render-state '
                'adapter and pointer-session factory',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene view runtime that mints pointer-session tokens outside interaction runtime',
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
          'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
          '''
import '../../contract/scene_view_runtime.dart';
import 'scene_controller_pointer_session.dart';
import 'pointer_session_token.dart';

final class SceneControllerSceneViewRuntime implements SceneViewRuntime {
  SceneControllerSceneViewRuntime({
    Object? ensurePublicSideEffectAllowed,
  });

  @override
  final mainSceneRenderRead = SceneControllerSceneViewMainSceneRenderRead();
  final _interactionRuntime = SceneControllerInteractionRuntime();

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    return SceneControllerPointerSession(
      token: PointerSessionToken(),
      detachPointerSession: _interactionRuntime.detachPointerSession,
      releasePointerSessionToken: _interactionRuntime.releasePointerSessionToken,
      handlePointerFromSession: _interactionRuntime.handlePointerFromSession,
      handleDoubleTapFromSession:
          _interactionRuntime.handleDoubleTapFromSession,
    );
  }
}

class SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(Object token) {}

  void releasePointerSessionToken(Object token) {}

  void handlePointerFromSession() {}

  void handleDoubleTapFromSession() {}
}

class SceneControllerSceneViewMainSceneRenderRead implements SceneViewMainSceneRenderRead {
  @override
  void addListener(Object listener) {}

  @override
  void removeListener(Object listener) {}
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
                'SceneControllerSceneViewRuntime must own the render-state '
                'adapter and pointer-session factory',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene view runtime whose main read owner drops its contract',
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
          'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
          _sceneViewRuntimeFixtureWithReadOwnerImplementationDrift(
            mainReadImplementsContract: false,
            overlayReadImplementsContract: true,
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerSceneViewRuntime must own the render-state '
                'adapter and pointer-session factory',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene view runtime whose overlay read owner drops its contract',
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
          'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
          _sceneViewRuntimeFixtureWithReadOwnerImplementationDrift(
            mainReadImplementsContract: true,
            overlayReadImplementsContract: false,
          ),
        );

        final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
        expect(result.exitCode, isNonZero);
        expect(
          result.stderr.toString(),
          diagnostic(
            category: 'interactive API',
            detail:
                'SceneControllerSceneViewRuntime must own the render-state '
                'adapter and pointer-session factory',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene view runtime that skips runtime-owned live-session registration',
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
          'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
          '''
import '../../contract/scene_view_runtime.dart';
import 'scene_controller_pointer_session.dart';
import 'pointer_session_token.dart';

final class SceneControllerSceneViewRuntime implements SceneViewRuntime {
  SceneControllerSceneViewRuntime({
    Object? ensurePublicSideEffectAllowed,
  });

  @override
  final mainSceneRenderRead = SceneControllerSceneViewMainSceneRenderRead();
  final _interactionRuntime = SceneControllerInteractionRuntime();

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    final token = _interactionRuntime.createPointerSessionToken();
    return SceneControllerPointerSession(
      token: token,
      detachPointerSession: _interactionRuntime.detachPointerSession,
      releasePointerSessionToken: _interactionRuntime.releasePointerSessionToken,
      handlePointerFromSession: _interactionRuntime.handlePointerFromSession,
      handleDoubleTapFromSession:
          _interactionRuntime.handleDoubleTapFromSession,
    );
  }
}

class SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void registerPointerSession(
    Object session, {
    required PointerSessionToken token,
  }) {}

  void detachPointerSession(Object token) {}

  void releasePointerSessionToken(Object token) {}

  void handlePointerFromSession() {}

  void handleDoubleTapFromSession() {}
}

class SceneControllerSceneViewMainSceneRenderRead implements SceneViewMainSceneRenderRead {
  @override
  void addListener(Object listener) {}

  @override
  void removeListener(Object listener) {}
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
                'SceneControllerSceneViewRuntime must own the render-state '
                'adapter and pointer-session factory.',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects scene view runtime that routes pointer-session callbacks through local wrappers',
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
          'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
          '''
import '../../contract/scene_view_runtime.dart';
import 'scene_controller_pointer_session.dart';
import 'pointer_session_token.dart';

final class SceneControllerSceneViewRuntime implements SceneViewRuntime {
  SceneControllerSceneViewRuntime({
    Object? ensurePublicSideEffectAllowed,
  });

  @override
  final mainSceneRenderRead = SceneControllerSceneViewMainSceneRenderRead();
  final _interactionRuntime = SceneControllerInteractionRuntime();

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    return SceneControllerPointerSession(
      token: _interactionRuntime.createPointerSessionToken(),
      detachPointerSession: detachPointerSession,
      releasePointerSessionToken: releasePointerSessionToken,
      handlePointerFromSession: handlePointerFromSession,
      handleDoubleTapFromSession: handleDoubleTapFromSession,
    );
  }

  void detachPointerSession(Object token) {}

  void releasePointerSessionToken(Object token) {}

  void handlePointerFromSession() {}

  void handleDoubleTapFromSession() {}
}

class SceneControllerInteractionRuntime {
  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(Object token) {}

  void releasePointerSessionToken(Object token) {}

  void handlePointerFromSession() {}

  void handleDoubleTapFromSession() {}
}

class SceneControllerSceneViewMainSceneRenderRead implements SceneViewMainSceneRenderRead {
  @override
  void addListener(Object listener) {}

  @override
  void removeListener(Object listener) {}
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
                'SceneControllerSceneViewRuntime must own the render-state '
                'adapter and pointer-session factory',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test(
    'rejects pointer session that routes through public interaction facade',
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
          'lib/src/interactive/internal/scene_controller_pointer_session.dart',
          '''
class SceneControllerInteraction {}
class PointerInputTracker {}
class PointerSessionToken {}

class SceneControllerPointerSession {
  final _ownerListenable = _OwnerListenable();
  final _PendingTapFlushScheduler scheduler = _PendingTapFlushScheduler();
  final SceneControllerInteraction _readInteraction = SceneControllerInteraction();

  void createTracker() {
    PointerInputTracker();
  }

  void attach() {
    _ownerListenable.addListener(Object());
    _readInteraction.runtimeType;
  }
}

class _PendingTapFlushScheduler {}

class _OwnerListenable {
  void addListener(Object listener) {}
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
    },
  );

  test(
    'rejects interactive runtime that keeps pre-split pointer boundary names',
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
import '../contract/canvas_pointer_input.dart';
import 'pointer_session_token.dart';
import 'interactive_draw_coordinator.dart';
import 'interactive_event_dispatcher.dart';
import 'interactive_move_session.dart';
import 'interactive_pointer_normalizer.dart';
import 'interactive_gesture_router.dart';
import 'interactive_double_tap_router.dart';

class InteractiveRuntime {
  void handlePointer(CanvasPointerInput input) {}

  void handleDoubleTap({required Object position, int? timestampMs}) {}
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
                'InteractiveRuntime must keep event timeline and draw-local geometry outside the boundary runtime',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );

  test('rejects retained scene access seam', () async {
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
        'lib/src/interactive/scene_controller_interaction.dart',
        '''
import '../contract/snapshot.dart';

abstract interface class SceneControllerInteraction {
  SceneSnapshot get snapshot;
}

class SceneControllerInteractionOwner implements SceneControllerInteraction {
  final _access = _Access();

  @override
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
}

String _sceneViewRuntimeFixtureWithReadOwnerImplementationDrift({
  required bool mainReadImplementsContract,
  required bool overlayReadImplementsContract,
}) {
  final mainReadInterfaces = mainReadImplementsContract
      ? 'SceneViewMainSceneRenderRead, Listenable'
      : 'Listenable';
  final overlayReadInterface = overlayReadImplementsContract
      ? ' implements SceneViewOverlayPreviewRead'
      : '';
  return '''
import 'package:flutter/foundation.dart';

import '../../contract/scene_view_runtime.dart';
import '../../contract/pointer_input.dart';
import 'scene_controller_pointer_session.dart';
import 'pointer_session_token.dart';
import 'scene_controller_interaction_runtime.dart';

final class SceneControllerSceneViewRuntime implements SceneViewRuntime {
  SceneControllerSceneViewRuntime({
    Object? ensurePublicSideEffectAllowed,
  });

  final _interactionRuntime = SceneControllerInteractionRuntime();
  final SceneControllerSceneViewMainSceneRenderRead _mainSceneRenderRead =
      SceneControllerSceneViewMainSceneRenderRead();
  final SceneControllerSceneViewOverlayPreviewRead _overlayPreviewRead =
      SceneControllerSceneViewOverlayPreviewRead();

  @override
  SceneViewMainSceneRenderRead get mainSceneRenderRead =>
      _mainSceneRenderRead as dynamic;

  @override
  SceneViewOverlayPreviewRead get overlayPreviewRead =>
      _overlayPreviewRead as dynamic;

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    final token = _interactionRuntime.createPointerSessionToken();
    final session = SceneControllerPointerSession(
      ownerListenable: _mainSceneRenderRead,
      token: token,
      readPointerSettings: () => const PointerInputSettings(),
      isMounted: isMounted,
      hasLiveRawPointers: hasLiveRawPointers,
      detachPointerSession:
          _interactionRuntime.detachPointerSession,
      releasePointerSessionToken:
          _interactionRuntime.releasePointerSessionToken,
      handlePointerFromSession:
          _interactionRuntime.handlePointerFromSession,
      handleDoubleTapFromSession:
          _interactionRuntime.handleDoubleTapFromSession,
    );
    _interactionRuntime.registerPointerSession(session, token: token);
    return session;
  }
}

final class SceneControllerSceneViewMainSceneRenderRead
    implements $mainReadInterfaces {
  @override
  void addListener(Object listener) {}

  @override
  void removeListener(Object listener) {}
}

final class SceneControllerSceneViewOverlayPreviewRead$overlayReadInterface {}
''';
}
