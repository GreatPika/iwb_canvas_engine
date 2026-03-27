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
    _registerInteractiveArchitectureGuardrailTests();
  });
}

void _registerInteractiveAcceptanceTests() {
  // INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
  test(
    'accepts guarded public interactive entrypoints in SceneControllerInteractive',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeInteractiveArchitectureSupportScaffold(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller_interactive.dart',
          '''
import 'internal/interactive_event_dispatcher.dart';
import 'internal/interactive_runtime.dart';
import 'internal/interactive_selection_actions.dart';

class SceneControllerInteractive {
  final InteractiveEventDispatcher _events = InteractiveEventDispatcher();
  late final InteractiveRuntime _runtime = InteractiveRuntime(events: _events);
  final InteractiveSelectionActions _selectionActions =
      InteractiveSelectionActions();

  Stream<Object> get actions => _events.actions;
  Stream<Object> get editTextRequests => _events.editTextRequests;

  int get value => 1;

  void handlePointer() {
    _ensurePublicSideEffectAllowed('handlePointer');
    _runtime.handlePointer(Object());
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
    _runtime.handleDoubleTap(position: Object());
  }

  set mode(int value) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
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

  test('accepts guarded multiline interactive entrypoint signatures', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller_interactive.dart',
        '''
import 'internal/interactive_event_dispatcher.dart';
import 'internal/interactive_runtime.dart';
import 'internal/interactive_selection_actions.dart';

class SceneControllerInteractive {
  final InteractiveEventDispatcher _events = InteractiveEventDispatcher();
  late final InteractiveRuntime _runtime = InteractiveRuntime(events: _events);
  final InteractiveSelectionActions _selectionActions =
      InteractiveSelectionActions();

  Stream<Object> get actions => _events.actions;
  Stream<Object> get editTextRequests => _events.editTextRequests;

  void handlePointer(
    int value,
  ) {
    _ensurePublicSideEffectAllowed('handlePointer');
    _runtime.handlePointer(value);
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
    _runtime.handleDoubleTap(position: Object());
  }

  set mode(
    int value,
  ) {
    _ensurePublicSideEffectAllowed('mode');
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}
''',
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
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller_interactive.dart',
          '''
class SceneControllerInteractive {
  void handlePointer() {
    print('missing guard');
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
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
                'public SceneControllerInteractive entrypoints must guard '
                'resolver purity with _ensurePublicSideEffectAllowed',
          ),
        );
      } finally {
        sandbox.deleteSync(recursive: true);
      }
    },
  );
}

void _registerInteractiveDisposeGuardTests() {
  test(
    'rejects dispose without allowAfterDispose true in purity guard',
    () async {
      final sandbox = await createGuardrailsSandbox();
      try {
        writeMinimalControllerStore(sandbox);
        writeSandboxFile(
          sandbox,
          'lib/src/interactive/scene_controller_interactive.dart',
          '''
class SceneControllerInteractive {
  void dispose() {
    _ensurePublicSideEffectAllowed('dispose');
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
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
        'lib/src/interactive/scene_controller_interactive.dart',
        '''
import 'internal/interactive_event_dispatcher.dart';
import 'internal/interactive_runtime.dart';
import 'internal/interactive_selection_actions.dart';

class SceneControllerInteractive {
  final InteractiveEventDispatcher _events = InteractiveEventDispatcher();
  late final InteractiveRuntime _runtime = InteractiveRuntime(events: _events);
  final InteractiveSelectionActions _selectionActions =
      InteractiveSelectionActions();

  Stream<Object> get actions => _events.actions;
  Stream<Object> get editTextRequests => _events.editTextRequests;

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
    _runtime.handlePointer(input);
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
    _runtime.handleDoubleTap(position: Object());
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}
''',
      );

      final result = await runSandboxTool(sandbox, 'check_guardrails.dart');
      expect(result.exitCode, 0, reason: result.stderr.toString());
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
        'lib/src/interactive/scene_controller_interactive.dart',
        '''
import 'internal/interactive_draw_coordinator.dart';
import 'internal/interactive_event_dispatcher.dart';
import 'internal/interactive_runtime.dart';
import 'internal/interactive_selection_actions.dart';

class SceneControllerInteractive {
  final InteractiveEventDispatcher _events = InteractiveEventDispatcher();
  late final InteractiveRuntime _runtime = InteractiveRuntime(events: _events);
  final InteractiveSelectionActions _selectionActions =
      InteractiveSelectionActions();
  final InteractiveDrawCoordinator _drawCoordinator =
      InteractiveDrawCoordinator();

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
    _runtime.handlePointer(input);
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
    _runtime.handleDoubleTap(position: Object());
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
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
              'SceneControllerInteractive must remain a thin facade over '
              'runtime/event/selection owners',
        ),
      );
    } finally {
      sandbox.deleteSync(recursive: true);
    }
  });

  test('rejects runtime that re-owns event timeline state', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller_interactive.dart',
        '''
import 'internal/interactive_event_dispatcher.dart';
import 'internal/interactive_runtime.dart';
import 'internal/interactive_selection_actions.dart';

class SceneControllerInteractive {
  final InteractiveEventDispatcher _events = InteractiveEventDispatcher();
  late final InteractiveRuntime _runtime = InteractiveRuntime(events: _events);
  final InteractiveSelectionActions _selectionActions =
      InteractiveSelectionActions();

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
    _runtime.handlePointer(input);
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
    _runtime.handleDoubleTap(position: Object());
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}
''',
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
        'lib/src/interactive/scene_controller_interactive.dart',
        '''
import 'internal/interactive_event_dispatcher.dart';
import 'internal/interactive_runtime.dart';
import 'internal/interactive_selection_actions.dart';

class SceneControllerInteractive {
  final InteractiveEventDispatcher _events = InteractiveEventDispatcher();
  late final InteractiveRuntime _runtime = InteractiveRuntime(events: _events);
  final InteractiveSelectionActions _selectionActions =
      InteractiveSelectionActions();

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
    _runtime.handlePointer(input);
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
    _runtime.handleDoubleTap(position: Object());
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}
''',
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

  test('rejects missing required split-owner file', () async {
    final sandbox = await createGuardrailsSandbox();
    try {
      writeMinimalControllerStore(sandbox);
      writeInteractiveArchitectureSupportScaffold(sandbox);
      writeSandboxFile(
        sandbox,
        'lib/src/interactive/scene_controller_interactive.dart',
        '''
import 'internal/interactive_event_dispatcher.dart';
import 'internal/interactive_runtime.dart';
import 'internal/interactive_selection_actions.dart';

class SceneControllerInteractive {
  final InteractiveEventDispatcher _events = InteractiveEventDispatcher();
  late final InteractiveRuntime _runtime = InteractiveRuntime(events: _events);
  final InteractiveSelectionActions _selectionActions =
      InteractiveSelectionActions();

  void handlePointer(Object input) {
    _ensurePublicSideEffectAllowed('handlePointer');
    _runtime.handlePointer(input);
  }

  void handleDoubleTap() {
    _ensurePublicSideEffectAllowed('handleDoubleTap');
    _runtime.handleDoubleTap(position: Object());
  }

  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
  }

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}
''',
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
