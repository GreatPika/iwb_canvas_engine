import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'public_entrypoint_contract.dart';
import 'tool_process_test_support.dart';

Matcher diagnostic({required String category, required String detail}) {
  return allOf(contains('$category violation:'), contains(detail));
}

Future<Directory> createGuardrailsSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_guardrails_tool_test_',
    toolFiles: const <String>['tool/check_guardrails.dart', 'tool/src'],
  );
}

Future<Directory> createImportBoundariesSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_import_boundaries_tool_test_',
    toolFiles: const <String>['tool/check_import_boundaries.dart', 'tool/src'],
  );
}

void writeCanonicalPublicExportScaffold(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'lib/iwb_canvas_engine.dart',
    canonicalPublicEntrypoint(),
  );
  for (final filePath in canonicalPublicExportFiles) {
    writeSandboxFile(sandbox, filePath, '// stub\n');
  }
}

void writeMinimalControllerStore(Directory sandbox) {
  writeSandboxFile(sandbox, 'lib/src/controller/store.dart', '''
class Store {
  int controllerEpoch = 0;

  void writeMutations() {}

  void txnCommit() {
    writeMutations();
  }
}
''');
}

void writeInteractiveArchitectureSupportScaffold(Directory sandbox) {
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/scene_controller_interaction.dart',
    '''
class SceneControllerInteraction {
  final _access = _Access();

  void handlePointer(Object input) {
    _access.runtime.ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _access.runtime.ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _access.runtime.ensurePublicSideEffectAllowed('mode');
  }
}

class _Access {
  final runtime = _RuntimeAccess();
}

class _RuntimeAccess {
  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/scene_controller_selection.dart',
    '''
class SceneControllerSelection {
  final _runtime = _Runtime();

  void setSelection(Object nodeIds) {
    _runtime.ensurePublicSideEffectAllowed('setSelection');
    _runtime.ensureExternalSelectionMutationAllowed('setSelection');
  }

  void toggleSelection(Object nodeId) {
    _runtime.ensurePublicSideEffectAllowed('toggleSelection');
    _runtime.ensureExternalSelectionMutationAllowed('toggleSelection');
  }

  void clearSelection() {
    _runtime.ensurePublicSideEffectAllowed('clearSelection');
    _runtime.ensureExternalSelectionMutationAllowed('clearSelection');
  }

  void selectAll() {
    _runtime.ensurePublicSideEffectAllowed('selectAll');
    _runtime.ensureExternalSelectionMutationAllowed('selectAll');
  }

  void rotateSelection() {
    _runtime.ensurePublicSideEffectAllowed('rotateSelection');
  }
}

class _Runtime {
  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}

  void ensureExternalSelectionMutationAllowed(String operation) {}
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/scene_controller_scene.dart',
    '''
class SceneControllerScene {
  final void Function(String operation, {bool allowAfterDispose})
  ensurePublicSideEffectAllowed = _ensure;

  void write(Object fn) {
    ensurePublicSideEffectAllowed('write');
  }

  void clearScene() {
    ensurePublicSideEffectAllowed('clearScene');
  }
}

void _ensure(
  String operation, {
  bool allowAfterDispose = false,
}) {}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_event_dispatcher.dart',
    '''
import 'dart:async';

class InteractiveEventDispatcher {
  final _actions = StreamController<Object>.broadcast();
  final _editTextRequests = StreamController<Object>.broadcast();

  Stream<Object> get actions => _actions.stream;
  Stream<Object> get editTextRequests => _editTextRequests.stream;

  int resolveTimestampMs(int? hintTimestampMs) => hintTimestampMs ?? 0;

  void emitAction(
    Object type,
    List<Object> nodeIds,
    int timestampMs, {
    Map<String, Object?>? payload,
  }) {}

  void emitEditTextRequested(Object request) {}
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_selection_actions.dart',
    'class InteractiveSelectionActions {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_runtime.dart',
    '''
import 'interactive_draw_coordinator.dart';
import 'interactive_event_dispatcher.dart';
import 'interactive_move_session.dart';
import 'interactive_pointer_normalizer.dart';
import 'interactive_gesture_router.dart';
import 'interactive_double_tap_router.dart';

class InteractiveRuntime {
  InteractiveRuntime({required this.events});

  final InteractiveEventDispatcher events;

  void handlePointer(Object input) {}

  void handleDoubleTap({required Object position, int? timestampMs}) {
    events.resolveTimestampMs(timestampMs);
  }
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
  void handlePointer(Object sample) {}
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_eraser_engine.dart',
    '''
import 'interactive_draw_eraser_exact_hit.dart';

class InteractiveDrawEraserEngine {
  final InteractiveDrawEraserExactHit _exactHit = InteractiveDrawEraserExactHit();

  bool erase(Object points, Object node) => _exactHit.hitsNode(points, node);
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_eraser_exact_hit.dart',
    '''
import 'interactive_draw_eraser_line_hit.dart';
import 'interactive_draw_eraser_projection.dart';
import 'interactive_draw_eraser_stroke_hit.dart';

class InteractiveDrawEraserExactHit {
  final InteractiveDrawEraserLineHit _lineHit = InteractiveDrawEraserLineHit();
  final InteractiveDrawEraserStrokeHit _strokeHit =
      InteractiveDrawEraserStrokeHit();

  bool hitsNode(Object points, Object node) {
    _projectEraserToLocal(points);
    _fallbackWorldBoundsHit(node);
    return _lineHit.hitsProjectedLine(points, node) ||
        _strokeHit.hitsProjectedStroke(points, node);
  }

  InteractiveDrawProjectedEraser _projectEraserToLocal(Object points) =>
      (points: const [], threshold: 0, thresholdSquared: 0);

  bool _fallbackWorldBoundsHit(Object node) => false;
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_eraser_line_hit.dart',
    '''
class InteractiveDrawEraserLineHit {
  bool hitsProjectedLine(Object points, Object node) {
    return _localEraserSegmentsHitLine(points, node);
  }

  bool _localEraserSegmentsHitLine(Object points, Object node) {
    onPreciseSegmentCheck();
    return false;
  }

  void onPreciseSegmentCheck() {}
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_eraser_projection.dart',
    '''
import 'dart:ui';

typedef InteractiveDrawProjectedEraser = ({
  List<Offset> points,
  double threshold,
  double thresholdSquared,
});
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_eraser_stroke_hit.dart',
    '''
class InteractiveDrawEraserStrokeHit {
  bool hitsProjectedStroke(Object points, Object node) {
    return _eraserSegmentHitsStrokeBatch(points, node);
  }

  bool _eraserSegmentHitsStrokeBatch(Object points, Object node) {
    onPreciseSegmentCheck();
    return false;
  }

  void onPreciseSegmentCheck() {}
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_move_session.dart',
    'class InteractiveMoveSession {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_pointer_normalizer.dart',
    'class InteractivePointerNormalizer {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_gesture_router.dart',
    'class InteractiveGestureRouter {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_double_tap_router.dart',
    'class InteractiveDoubleTapRouter {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_line_engine.dart',
    'class InteractiveDrawLineEngine {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_stroke_engine.dart',
    'class InteractiveDrawStrokeEngine {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_terminal_router.dart',
    'class InteractiveDrawTerminalRouter {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_style.dart',
    '''
import 'dart:ui';

enum DrawTool { pen, highlighter, line, eraser }

typedef InteractiveDrawStyle = ({
  DrawTool drawTool,
  Color drawColor,
  double penThickness,
  double highlighterThickness,
  double lineThickness,
  double eraserThickness,
  double highlighterOpacity,
});
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_interaction_config.dart',
    'class SceneControllerInteractionConfig {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
    'class SceneControllerInteractionRuntime {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_interaction_access.dart',
    'class SceneControllerInteractionContext {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
    'class SceneControllerSceneMutations {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_selection_mutations.dart',
    'class SceneControllerSelectionMutations {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_facade_assembly.dart',
    'void assembleSceneControllerFacade() {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_internal_access.dart',
    '''
void registerSceneControllerInternalAccess(
  Object controller, {
  required Object readEpoch,
  required Object previewDeltaForNode,
  required Object setBeforePointerDispatchHook,
  required Object runMoveCommitDeltaResolverForTest,
  required Object readInteractionAccessForTest,
  required Object readActiveEraserPointsLength,
  required Object readEraserSpatialQueryCount,
  required Object readEraserPreciseSegmentCheckCount,
}) {}

int sceneControllerInternalEpoch(Object controller) => 0;

Object sceneControllerInternalPreviewDeltaForNode(
  Object controller,
  Object nodeId,
) => Object();

void sceneControllerInternalSetBeforePointerDispatchHook(
  Object controller,
  Object? hook,
) {}
''',
  );
}
