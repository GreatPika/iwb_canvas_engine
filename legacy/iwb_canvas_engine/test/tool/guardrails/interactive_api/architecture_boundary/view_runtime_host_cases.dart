part of '../../guardrails_interactive_api_tool_test.dart';

void _registerInteractiveArchitectureBoundaryViewRuntimeHostTests() {
  test(
    'rejects runtime host that depends on concrete SceneController',
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
import '../interactive/scene_controller.dart';

class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;
  final SceneController controller;

  SceneViewRuntimeHost({
    required this.runtime,
    required this.controller,
  });
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

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    final nextPointerSession = _createReplacementPointerSession(widget.runtime);
    _pointerHost.replacePointerSession(nextPointerSession);
    _activeRuntime = widget.runtime;
  }

  Object build() {
    final renderState = widget.controller;
    return SceneViewRenderSurface(mainSceneRenderRead: renderState);
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

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({
    required SceneViewPointerSession pointerSession,
  });

  void replacePointerSession(SceneViewPointerSession session) {}
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

  test(
    'rejects runtime host that omits overlay preview read routing',
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
    final mainSceneRenderRead = _activeRuntime.mainSceneRenderRead;
    return SceneViewRenderSurface(mainSceneRenderRead: mainSceneRenderRead);
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

  test(
    'rejects runtime host that routes main-scene read to overlay painter',
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
          'lib/src/view/scene_view_interactive_overlay_painter.dart',
          '''
class SceneViewInteractiveOverlayPainter {
  SceneViewInteractiveOverlayPainter({required Object overlayPreviewRead});
}
''',
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
    final mainSceneRenderRead = _activeRuntime.mainSceneRenderRead;
    final overlayPreviewRead = _activeRuntime.mainSceneRenderRead;
    return _SceneViewRuntimeHostShell(
      foregroundPainter: SceneViewInteractiveOverlayPainter(
        overlayPreviewRead: overlayPreviewRead,
      ),
      child: SceneViewRenderSurface(mainSceneRenderRead: mainSceneRenderRead),
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

  test(
    'rejects runtime host that keeps replacement swap on stale runtime',
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
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

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

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    final nextPointerSession = _createReplacementPointerSession(_activeRuntime);
    _pointerHost.replacePointerSession(nextPointerSession);
  }

  Object build() {
    final renderState = _activeRuntime.mainSceneRenderRead;
    return SceneViewRenderSurface(mainSceneRenderRead: renderState);
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

  test(
    'rejects runtime host that creates replacement session before runtime equality short circuit',
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
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

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

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    final nextPointerSession = _createReplacementPointerSession(widget.runtime);
    if (_activeRuntime == widget.runtime) {
      return;
    }
    _pointerHost.replacePointerSession(nextPointerSession);
    _activeRuntime = widget.runtime;
  }

  Object build() {
    final renderState = _activeRuntime.mainSceneRenderRead;
    return SceneViewRenderSurface(mainSceneRenderRead: renderState);
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

  test(
    'rejects runtime host that prefetched replacement session before equality short circuit under another local name',
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
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

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

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    final prefetched = _createReplacementPointerSession(widget.runtime);
    if (_activeRuntime == widget.runtime) {
      return;
    }
    final nextPointerSession = _createReplacementPointerSession(widget.runtime);
    _pointerHost.replacePointerSession(nextPointerSession);
    _activeRuntime = widget.runtime;
    prefetched.dispose();
  }

  Object build() {
    final renderState = _activeRuntime.mainSceneRenderRead;
    return SceneViewRenderSurface(mainSceneRenderRead: renderState);
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

  test(
    'rejects runtime host that renders SceneViewRenderSurface from non-active runtime render state',
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
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;

  SceneViewRuntimeHost({required this.runtime});
}

class _SceneViewRuntimeHostState {
  late final SceneViewInteractivePointerHost _pointerHost;
  late SceneViewRuntime _activeRuntime;
  late SceneViewRuntime _staleRuntime;

  void initState() {
    _activeRuntime = widget.runtime;
    _staleRuntime = widget.runtime;
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
    final renderState = _staleRuntime.mainSceneRenderRead;
    return SceneViewRenderSurface(mainSceneRenderRead: renderState);
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

  test(
    'rejects runtime host that switches active runtime before pointer-session swap',
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
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

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

  void didUpdateWidget(SceneViewRuntimeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeRuntime == widget.runtime) {
      return;
    }
    final nextPointerSession = _createReplacementPointerSession(widget.runtime);
    _activeRuntime = widget.runtime;
    _pointerHost.replacePointerSession(nextPointerSession);
  }

  Object build() {
    final renderState = _activeRuntime.mainSceneRenderRead;
    return SceneViewRenderSurface(mainSceneRenderRead: renderState);
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

  test(
    'rejects runtime host that declares local pointer host shadow',
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
import 'scene_view_interactive_pointer_host.dart';
import 'scene_view_render_surface.dart';

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
    final renderState = _activeRuntime.mainSceneRenderRead;
    return SceneViewRenderSurface(mainSceneRenderRead: renderState);
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

class SceneViewInteractivePointerHost {
  SceneViewInteractivePointerHost({
    required SceneViewPointerSession pointerSession,
  });

  void replacePointerSession(SceneViewPointerSession session) {}
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

  test(
    'rejects pointer host that installs next session before releasing current',
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
  SceneViewPointerSession _pointerSession;

  int get debugLiveRawPointerCount => 0;
  int? get debugPendingTapFlushTimestampMs =>
      _pointerSession.pendingTapFlushTimestampMs;

  void replacePointerSession(SceneViewPointerSession next) {
    final current = _pointerSession;
    _pointerSession = next;
    current.detach();
    current.dispose();
    _pointerRouter.reset();
  }

  void dispose() {
    _pointerSession.detach();
    _pointerSession.dispose();
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
                'SceneViewInteractivePointerHost must remain a raw '
                'routing/lifecycle shell over pointer sessions',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}
