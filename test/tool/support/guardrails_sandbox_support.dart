import 'dart:io';

import '../../../tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart';
import 'tool_process_test_support.dart';

Future<Directory> createGuardrailsSandbox() {
  return createToolSandbox(
    tempPrefix: 'iwb_canvas_engine_guardrails_tool_test_',
    toolFiles: const <String>['tool/check_guardrails.dart', 'tool/src'],
  );
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
  writeSandboxFile(sandbox, 'lib/src/contract/node_patch.dart', '''
class NodePatch {}
''');
  writeSandboxFile(sandbox, 'lib/src/contract/node_spec.dart', '''
typedef NodeId = String;
typedef LayerId = String;

class NodeSpec {}
''');
  writeSandboxFile(sandbox, 'lib/src/contract/scene_write_txn.dart', '''
class SceneWriteTxn {}
''');
  writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
typedef NodeId = String;
typedef LayerId = String;

class SceneSnapshot {}

class NodeSnapshot {}

class ClearSceneResult {}
''');
  writeSandboxFile(sandbox, 'lib/src/contract/transform2d.dart', '''
class Transform2D {}
''');
  writeSandboxFile(
    sandbox,
    'lib/src/controller/scene_controller_committed_mutation_access.dart',
    '''
import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';

typedef SceneControllerCommittedMutationWriteResult<T> = ({
  T value,
  bool didChangeRenderState,
});

abstract interface class SceneControllerCommittedMutationAccess {
  T write<T>(T Function(SceneWriteTxn writer) fn);

  SceneControllerCommittedMutationWriteResult<T> writeExact<T>(
    T Function(SceneWriteTxn writer) fn,
  );

  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex});

  bool ensureLayer(LayerId layerId, {int? index});

  bool patchNode(NodePatch patch);

  bool removeNode(NodeId id);

  bool setBackgroundColor(Color value);

  bool setGridEnabled(bool value);

  bool setGridCellSize(double value);

  bool setCameraOffset(Offset value);

  bool replaceSelection(Object nodeIds);

  bool clearSelection();

  bool toggleSelection(NodeId nodeId);

  ({int selectedCount, bool changed}) selectAll({bool onlySelectable = true});

  int deleteSelection();

  int transformSelection(Transform2D delta);

  void replaceScene(SceneSnapshot snapshot, {required VoidCallback beforeApply});

  NodeId commitDrawStroke({
    required List<Offset> points,
    required double thickness,
    required Color color,
    required double opacity,
  });

  NodeId commitDrawLineFromWorldSegment({
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    required double opacity,
  });

  int commitEraseNodes(Iterable<NodeId> ids);

  ClearSceneResult clearSceneExactResult();

  void requestRepaint();

  SceneSnapshot get snapshot;

  Set<NodeId> get selectedNodeIds;

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots);
}

final class SceneStoreControllerCommittedMutationAccess
    implements SceneControllerCommittedMutationAccess {
  @override
  T write<T>(T Function(SceneWriteTxn writer) fn) => fn(SceneWriteTxn());

  @override
  SceneControllerCommittedMutationWriteResult<T> writeExact<T>(
    T Function(SceneWriteTxn writer) fn,
  ) => (value: fn(SceneWriteTxn()), didChangeRenderState: true);

  @override
  NodeId addNode(NodeSpec node, {LayerId? layerId, int? insertIndex}) => 'id';

  @override
  bool ensureLayer(LayerId layerId, {int? index}) => true;

  @override
  bool patchNode(NodePatch patch) => true;

  @override
  bool removeNode(NodeId id) => true;

  @override
  bool setBackgroundColor(Color value) => true;

  @override
  bool setGridEnabled(bool value) => true;

  @override
  bool setGridCellSize(double value) => true;

  @override
  bool setCameraOffset(Offset value) => true;

  @override
  bool replaceSelection(Object nodeIds) => true;

  @override
  bool clearSelection() => true;

  @override
  bool toggleSelection(NodeId nodeId) => true;

  @override
  ({int selectedCount, bool changed}) selectAll({bool onlySelectable = true}) =>
      (selectedCount: 0, changed: true);

  @override
  int deleteSelection() => 0;

  @override
  int transformSelection(Transform2D delta) => 0;

  @override
  void replaceScene(
    SceneSnapshot snapshot, {
    required VoidCallback beforeApply,
  }) {}

  @override
  NodeId commitDrawStroke({
    required List<Offset> points,
    required double thickness,
    required Color color,
    required double opacity,
  }) => 'id';

  @override
  NodeId commitDrawLineFromWorldSegment({
    required Offset start,
    required Offset end,
    required double thickness,
    required Color color,
    required double opacity,
  }) => 'id';

  @override
  int commitEraseNodes(Iterable<NodeId> ids) => 0;

  @override
  ClearSceneResult clearSceneExactResult() => ClearSceneResult();

  @override
  void requestRepaint() {}

  @override
  SceneSnapshot get snapshot => SceneSnapshot();

  @override
  Set<NodeId> get selectedNodeIds => <NodeId>{};

  @override
  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      const Offset();
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/scene_controller_interaction.dart',
    '''
import 'package:flutter/foundation.dart';

import 'internal/scene_controller_interaction_config.dart';
import 'internal/scene_controller_interaction_runtime.dart';

abstract interface class SceneControllerInteraction {}

class SceneControllerInteractionOwner implements SceneControllerInteraction {
  SceneControllerInteractionOwner({
    required Listenable ownerListenable,
    required SceneControllerInteractionConfig config,
    required SceneControllerInteractionRuntime runtime,
    required bool clearSelectionOnDrawModeEnter,
    required bool Function() hasSelection,
    required VoidCallback clearSelectionState,
  }) : _ownerListenable = ownerListenable,
       _config = config,
       _runtime = runtime,
       _clearSelectionOnDrawModeEnter = clearSelectionOnDrawModeEnter,
       _hasSelection = hasSelection,
       _clearSelectionState = clearSelectionState;

  final Listenable _ownerListenable;
  final SceneControllerInteractionConfig _config;
  final SceneControllerInteractionRuntime _runtime;
  final bool _clearSelectionOnDrawModeEnter;
  final bool Function() _hasSelection;
  final VoidCallback _clearSelectionState;

  void handlePointer(Object input) {
    _runtime.ensurePublicSideEffectAllowed('handlePointer');
  }

  void handleDoubleTap() {
    _runtime.ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  set mode(int value) {
    _runtime.ensurePublicSideEffectAllowed('mode');
    _config.toString();
    _ownerListenable.toString();
    _clearSelectionOnDrawModeEnter.toString();
    _hasSelection.toString();
    _clearSelectionState.toString();
  }
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/scene_controller_selection.dart',
    '''
import 'internal/scene_controller_interaction_runtime.dart';
import 'internal/scene_controller_mutation_boundary.dart';

class SceneControllerSelectionOwner {
  SceneControllerSelectionOwner({
    required SceneControllerInteractionRuntime runtime,
    required SceneControllerMutationBoundary mutationBoundary,
  }) : _runtime = runtime,
       _mutationBoundary = mutationBoundary;

  final SceneControllerInteractionRuntime _runtime;
  final SceneControllerMutationBoundary _mutationBoundary;

  void setSelection(Object nodeIds) {
    _runtime.ensurePublicSideEffectAllowed('setSelection');
    _ensureExternalMutationAllowed('setSelection');
    _mutationBoundary.setSelection(nodeIds);
  }

  void toggleSelection(Object nodeId) {
    _runtime.ensurePublicSideEffectAllowed('toggleSelection');
    _ensureExternalMutationAllowed('toggleSelection');
    _mutationBoundary.toggleSelection(nodeId);
  }

  void clearSelection() {
    _runtime.ensurePublicSideEffectAllowed('clearSelection');
    _ensureExternalMutationAllowed('clearSelection');
    _mutationBoundary.clearSelection();
  }

  void selectAll() {
    _runtime.ensurePublicSideEffectAllowed('selectAll');
    _ensureExternalMutationAllowed('selectAll');
    _mutationBoundary.selectAll();
  }

  void rotateSelection() {
    _runtime.ensurePublicSideEffectAllowed('rotateSelection');
    _ensureExternalMutationAllowed('rotateSelection');
    _mutationBoundary.rotateSelection(clockwise: true);
  }

  void flipSelectionVertical() {
    _runtime.ensurePublicSideEffectAllowed('flipSelectionVertical');
    _ensureExternalMutationAllowed('flipSelectionVertical');
    _mutationBoundary.flipSelectionVertical();
  }

  void flipSelectionHorizontal() {
    _runtime.ensurePublicSideEffectAllowed('flipSelectionHorizontal');
    _ensureExternalMutationAllowed('flipSelectionHorizontal');
    _mutationBoundary.flipSelectionHorizontal();
  }

  void deleteSelection() {
    _runtime.ensurePublicSideEffectAllowed('deleteSelection');
    _ensureExternalMutationAllowed('deleteSelection');
    _mutationBoundary.deleteSelection();
  }

  void _ensureExternalMutationAllowed(String operation) {
    _runtime._ensureExternalMutationAllowed(operation);
  }
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/scene_controller_scene.dart',
    '''
import 'internal/scene_controller_interaction_runtime.dart';
import 'internal/scene_controller_mutation_boundary.dart';

abstract interface class SceneControllerScene {
  void write(Object fn);

  void clearScene();
}

class SceneControllerSceneOwner implements SceneControllerScene {
  SceneControllerSceneOwner({
    required SceneControllerInteractionRuntime runtime,
    required SceneControllerMutationBoundary mutationBoundary,
  }) : _runtime = runtime,
       _mutationBoundary = mutationBoundary;

  final SceneControllerInteractionRuntime _runtime;
  final SceneControllerMutationBoundary _mutationBoundary;

  @override
  void write(Object fn) {
    _runtime.ensurePublicSideEffectAllowed('write');
    _ensureExternalMutationAllowed('write');
    _mutationBoundary.write(fn);
  }

  @override
  void clearScene() {
    _runtime.ensurePublicSideEffectAllowed('clearScene');
    _ensureExternalMutationAllowed('clearScene');
    _mutationBoundary.clearScene();
  }

  void setBackgroundColor(Object value) {
    _runtime.ensurePublicSideEffectAllowed('setBackgroundColor');
    _ensureExternalMutationAllowed('setBackgroundColor');
    _mutationBoundary.setBackgroundColor(value);
  }

  void setGridEnabled(bool value) {
    _runtime.ensurePublicSideEffectAllowed('setGridEnabled');
    _ensureExternalMutationAllowed('setGridEnabled');
    _mutationBoundary.setGridEnabled(value);
  }

  void setGridCellSize(double value) {
    _runtime.ensurePublicSideEffectAllowed('setGridCellSize');
    _ensureExternalMutationAllowed('setGridCellSize');
    _mutationBoundary.setGridCellSize(value);
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

  void addNode(Object node) {
    _runtime.ensurePublicSideEffectAllowed('addNode');
    _ensureExternalMutationAllowed('addNode');
    _mutationBoundary.addNode(node);
  }

  void ensureLayer(Object layerId) {
    _runtime.ensurePublicSideEffectAllowed('ensureLayer');
    _ensureExternalMutationAllowed('ensureLayer');
    _mutationBoundary.ensureLayer(layerId);
  }

  void patchNode(Object patch) {
    _runtime.ensurePublicSideEffectAllowed('patchNode');
    _ensureExternalMutationAllowed('patchNode');
    _mutationBoundary.patchNode(patch);
  }

  void removeNode(Object id) {
    _runtime.ensurePublicSideEffectAllowed('removeNode');
    _ensureExternalMutationAllowed('removeNode');
    _mutationBoundary.removeNode(id);
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

  void _ensureExternalMutationAllowed(String operation) {
    _runtime._ensureExternalMutationAllowed(operation);
  }

  void _interruptForExternalMutation() {
    _runtime._interruptForExternalMutation();
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
    'lib/src/interactive/internal/scene_controller_mutation_boundary.dart',
    '''
import '../../controller/scene_controller_committed_mutation_access.dart';

class SceneControllerMutationBoundary {
  SceneControllerMutationBoundary({
    required this.mutationAccess,
  });

  final SceneControllerCommittedMutationAccess mutationAccess;

  void write(Object fn) {
    mutationAccess.clearSceneExactResult();
  }

  void setBackgroundColor(Object value) {}

  void setGridEnabled(bool value) {}

  void setGridCellSize(double value) {}

  void validateCameraOffset(Object value) {}

  bool shouldApplyCameraOffset(Object value) => true;

  void setCameraOffset(Object value) {}

  void addNode(Object node) {}

  void ensureLayer(Object layerId) {}

  void patchNode(Object patch) {}

  void removeNode(Object id) {}

  void clearScene() {
    mutationAccess.clearSceneExactResult();
  }

  void setSelection(Object nodeIds) {
    if (!mutationAccess.replaceSelection(nodeIds)) {
      return;
    }
  }

  void toggleSelection(Object nodeId) {}

  void clearSelection() {
    if (!mutationAccess.clearSelection()) {
      return;
    }
  }

  void selectAll() {}

  void deleteSelection() {
    mutationAccess.deleteSelection();
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {}

  void flipSelectionVertical({int? timestampMs}) {}

  void flipSelectionHorizontal({int? timestampMs}) {}

  void transformSelection(Object delta) {
    mutationAccess.transformSelection(delta);
  }

  void replaceScene(Object snapshot, {required Object interruptBeforeApply}) {
    mutationAccess.replaceScene(snapshot, beforeApply: interruptBeforeApply);
  }

  Object commitMoveSelection(Object proposedDelta) => proposedDelta;

  Object commitDrawStroke(Object payload) {
    return mutationAccess.commitDrawStroke(payload);
  }

  Object commitDrawLineFromWorldSegment(Object payload) {
    return mutationAccess.commitDrawLineFromWorldSegment(payload);
  }

  int commitEraseNodes(Object ids) {
    return mutationAccess.commitEraseNodes(ids);
  }

  void notifySceneChanged() {
    mutationAccess.requestRepaint();
  }

  void requestRepaint() {
    mutationAccess.requestRepaint();
  }
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/interaction_eligibility_policy.dart',
    '''
Object _snapshotBoundsWorld(Object node) => node;

bool canSelect(Object node) {
  _snapshotBoundsWorld(node);
  return true;
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_runtime.dart',
    '''
import 'dart:ui';

import '../contract/canvas_pointer_input.dart';
import 'interactive_draw_coordinator.dart';
import 'interactive_event_dispatcher.dart';
import 'interactive_move_session.dart';
import 'interactive_pointer_normalizer.dart';
import 'interactive_gesture_router.dart';
import 'interactive_double_tap_router.dart';
import 'interactive_runtime_callbacks.dart';
import 'pointer_session_token.dart';

class InteractiveRuntime {
  InteractiveRuntime({
    required this.callbacks,
    InteractiveEventDispatcher? events,
  }) : events = events ?? InteractiveEventDispatcher();

  final InteractiveEventDispatcher events;
  final InteractiveRuntimeCallbacks callbacks;

  void handlePublicPointer(CanvasPointerInput input) {}

  void handlePointerFromSession(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  }) {}

  void handlePublicDoubleTap({required Offset position, int? timestampMs}) {
    events.resolveTimestampMs(timestampMs);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    events.resolveTimestampMs(timestampMs);
  }

  void interruptForInteractionConfigChange() {}

  void _interruptForExternalMutation() {}

  void detachPointerSession(PointerSessionToken token) {}
}
''',
  );
  writeSandboxFile(sandbox, 'lib/src/contract/canvas_pointer_input.dart', '''
class CanvasPointerInput {}
''');
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/pointer_session_token.dart',
    '''
final class PointerSessionToken {
  PointerSessionToken();
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
  final InteractiveDrawStrokeEngine _strokeEngine = InteractiveDrawStrokeEngine();
  final InteractiveDrawLineEngine _lineEngine = InteractiveDrawLineEngine();
  final InteractiveDrawEraserEngine _eraserEngine = InteractiveDrawEraserEngine();
  final InteractiveDrawTerminalRouter _terminalRouter =
      InteractiveDrawTerminalRouter();

  void handlePointer(Object sample) {}
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_eraser_engine.dart',
    '''
import 'interactive_draw_eraser_exact_hit.dart';
import 'interactive_draw_eraser_targets.dart';
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveDrawEraserEngineCallbacks {
  const InteractiveDrawEraserEngineCallbacks({
    required this.onOverlayStateChanged,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.commitEraseNodes,
  });

  final Object onOverlayStateChanged;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object commitEraseNodes;
}

class InteractiveDrawEraserEngine {
  final InteractiveDrawEraserTargets _targets = InteractiveDrawEraserTargets();
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
  writeSandboxFile(sandbox, 'lib/src/contract/scene_view_runtime.dart', '''
import 'canvas_pointer_input.dart';

abstract interface class SceneViewRuntime {
  SceneViewMainSceneRenderRead get mainSceneRenderRead;

  SceneViewOverlayPreviewRead get overlayPreviewRead;

  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  });
}

abstract interface class SceneViewMainSceneRenderRead {
  void addListener(Object listener);

  void removeListener(Object listener);
}

abstract interface class SceneViewOverlayPreviewRead {}

abstract interface class SceneViewPointerSession {
  int? get pendingTapFlushTimestampMs;

  void detach();

  void handleRoutedSample(
    Object sample, {
    required bool shouldTrackSignals,
  });

  void handleInvalidTerminalSample({
    required CanvasPointerInput input,
    required int pointerId,
    required int referenceTimestampMs,
  });

  void handleRawPointerRelease({required bool isIdleAfterRelease});

  void dispose();
}
''');
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
    '''
import 'dart:ui';

import '../contract/canvas_pointer_input.dart';
import '../../controller/scene_controller_committed_mutation_access.dart';
import 'interactive_runtime.dart';
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

  final void Function(String operation) ensureExternalMutationAllowed =
      (String operation) {};

  void interruptForInteractionConfigChange() {}

  void _interruptForExternalMutation() {}

  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void registerPointerSession(Object session, {required PointerSessionToken token}) {}

  void detachPointerSession(PointerSessionToken token) {
    _ensureKnownPointerSessionToken(token);
  }

  void releasePointerSessionToken(PointerSessionToken token) {
    _ensureKnownPointerSessionToken(token);
  }

  void handlePublicPointer(CanvasPointerInput input) {}

  void handlePublicDoubleTap({required Offset position, int? timestampMs}) {}

  void clearSceneSelectionState({int? timestampMs}) {
    mutationBoundary.clearScene();
  }

  void rotateSelection({required bool clockwise, int? timestampMs}) {
    mutationBoundary.rotateSelection(clockwise: clockwise);
  }

  void flipSelectionVertical({int? timestampMs}) {
    mutationBoundary.flipSelectionVertical();
  }

  void flipSelectionHorizontal({int? timestampMs}) {
    mutationBoundary.flipSelectionHorizontal();
  }

  void deleteSelection({int? timestampMs}) {
    mutationBoundary.deleteSelection();
  }

  void handlePointerFromSession(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  }) {
    _ensureKnownPointerSessionToken(token);
    runtime.handlePointerFromSession(input, token: token);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    _ensureKnownPointerSessionToken(token);
    runtime.handleDoubleTapFromSession(
      position: position,
      timestampMs: timestampMs,
      token: token,
    );
  }

  void _ensureKnownPointerSessionToken(PointerSessionToken token) {}
}

SceneControllerMutationBoundary wireRuntime(
  SceneControllerInteractionRuntimeRequest request,
) => _createMutationBoundary(request);

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
    callbacks: InteractiveRuntimeCallbacks(
      writeSelectionReplace: mutationBoundary.setSelection,
      writeSelectionClear: mutationBoundary.clearSelection,
      commitMoveSelection: mutationBoundary.commitMoveSelection,
      commitDrawStroke: mutationBoundary.commitDrawStroke,
      commitDrawLineFromWorldSegment:
          mutationBoundary.commitDrawLineFromWorldSegment,
      commitEraseNodes: mutationBoundary.commitEraseNodes,
    ),
  );
}
''',
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
    current.detach();
    current.dispose();
    _pointerRouter.reset();
    _pointerSession = next;
  }

  void dispose() {
    _pointerSession.detach();
    _pointerSession.dispose();
  }
}
''',
  );
  writeSandboxFile(sandbox, 'lib/src/view/scene_view_pointer_router.dart', '''
class SceneViewPointerRouter {
  int get liveRawPointerCount => 0;

  void reset() {}
}
''');
  writeSandboxFile(sandbox, 'lib/src/view/scene_view_interactive.dart', '''
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
''');
  writeSandboxFile(sandbox, 'lib/src/view/scene_view_runtime_host.dart', '''
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
    final overlayPreviewRead = _activeRuntime.overlayPreviewRead;
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
''');
  writeSandboxFile(
    sandbox,
    'lib/src/view/scene_view_interactive_overlay_painter.dart',
    '''
import '../contract/scene_view_runtime.dart';

class SceneViewInteractiveOverlayPainter {
  SceneViewInteractiveOverlayPainter({
    required SceneViewOverlayPreviewRead overlayPreviewRead,
  }) : _overlayPreviewRead = overlayPreviewRead;

  final SceneViewOverlayPreviewRead _overlayPreviewRead;
}
''',
  );
  writeSandboxFile(sandbox, 'lib/src/view/scene_view_render_surface.dart', '''
import '../contract/scene_view_runtime.dart';

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
''');
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_pointer_session.dart',
    '''
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../contract/canvas_pointer_input.dart';
import '../../contract/pointer_input.dart';
import '../../contract/scene_view_runtime.dart';
import 'pointer_session_token.dart';

class PointerInputTracker {}

class SceneControllerPointerSession implements SceneViewPointerSession {
  SceneControllerPointerSession({
    required Listenable ownerListenable,
    required PointerSessionToken token,
    required PointerInputSettings Function() readPointerSettings,
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
    required void Function(PointerSessionToken token) detachPointerSession,
    required void Function(PointerSessionToken token) releasePointerSessionToken,
    required void Function(
      CanvasPointerInput input, {
      required PointerSessionToken token,
    })
    handlePointerFromSession,
    required void Function({
      required Offset position,
      int? timestampMs,
      required PointerSessionToken token,
    })
    handleDoubleTapFromSession,
  }) : _ownerListenable = ownerListenable,
       _readPointerSettings = readPointerSettings,
       _isMounted = isMounted,
       _hasLiveRawPointers = hasLiveRawPointers,
       _token = token,
       _handlePointerFromSession = handlePointerFromSession,
       _handleDoubleTapFromSession = handleDoubleTapFromSession;

  final Listenable _ownerListenable;
  final PointerInputSettings Function() _readPointerSettings;
  final bool Function() _isMounted;
  final bool Function() _hasLiveRawPointers;

  final PointerSessionToken _token;
  final Object _ownerListener = Object();
  final _PendingTapFlushScheduler _pendingTapFlushScheduler =
      _PendingTapFlushScheduler();
  final void Function(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  })
  _handlePointerFromSession;
  final void Function({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  })
  _handleDoubleTapFromSession;

  @override
  int? get pendingTapFlushTimestampMs => null;

  void createTracker() {
    PointerInputTracker();
    _readPointerSettings();
    _isMounted();
    _hasLiveRawPointers();
  }

  void attach() {
    _ownerListenable.addListener(_ownerListener);
  }

  void route(PointerSessionToken token) {
    _handlePointerFromSession(
      const CanvasPointerInput(
        pointerId: 1,
        position: Offset.zero,
        timestampMs: 0,
        phase: CanvasPointerPhase.down,
        kind: PointerDeviceKind.touch,
      ),
      token: token,
    );
    _handleDoubleTapFromSession(
      position: Offset.zero,
      timestampMs: 0,
      token: token,
    );
  }

  @override
  void detach() {
    _detachPointerSession(_token);
    _releaseOwnedResources();
  }

  @override
  void handleRoutedSample(
    PointerSample sample, {
    required bool shouldTrackSignals,
  }) {}

  @override
  void handleInvalidTerminalSample({
    required CanvasPointerInput input,
    required int pointerId,
    required int referenceTimestampMs,
  }) {}

  @override
  void handleRawPointerRelease({required bool isIdleAfterRelease}) {}

  @override
  void dispose() {
    detach();
    _pendingTapFlushScheduler.dispose();
  }

  void _releaseOwnedResources() {
    _ownerListenable.removeListener(_ownerListener);
    _releasePointerSessionToken(_token);
  }

  void _detachPointerSession(PointerSessionToken token) {}

  void _handlePointerFromSession(PointerSessionToken token) {}

  void _handleDoubleTapFromSession(PointerSessionToken token) {}

  void _releasePointerSessionToken(PointerSessionToken token) {}
}

class _PendingTapFlushScheduler {
  void dispose() {}
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
    '''
import 'package:flutter/foundation.dart';

import '../../contract/scene_view_runtime.dart';
import '../../contract/pointer_input.dart';
import '../scene_controller_interaction.dart';
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
  SceneViewMainSceneRenderRead get mainSceneRenderRead => _mainSceneRenderRead;

  @override
  SceneViewOverlayPreviewRead get overlayPreviewRead => _overlayPreviewRead;

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
    implements SceneViewMainSceneRenderRead, Listenable {
  @override
  void addListener(Object listener) {}

  @override
  void removeListener(Object listener) {}
}

final class SceneControllerSceneViewOverlayPreviewRead
    implements SceneViewOverlayPreviewRead {
  SceneControllerInteraction get _interaction => SceneControllerInteraction();
}
''',
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

class SceneControllerGraphRequest {}

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
  final graph = _assembleSceneControllerGraph(request);
  registerSceneControllerInternalAccess(Object(), graph.internalAccessRegistration);
  return graph;
}

SceneControllerGraphHandle _assembleSceneControllerGraph(Object request) {
  final storeController = SceneStoreController();
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
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_internal_access.dart',
    '''
class SceneControllerInternalAccessRegistration {}

void registerSceneControllerInternalAccess(
  Object controller,
  Object registration,
) {}

void unregisterSceneControllerInternalAccess(Object controller) {}

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
  writeSandboxFile(sandbox, 'lib/src/contract/snapshot.dart', '''
import 'node_spec.dart';

class SceneSnapshot {
  const SceneSnapshot({this.backgroundLayer = const BackgroundLayerSnapshot()});

  final BackgroundLayerSnapshot backgroundLayer;
}

class BackgroundLayerSnapshot {
  const BackgroundLayerSnapshot({this.nodes = const <NodeSnapshot>[]});

  final List<NodeSnapshot> nodes;
}

class NodeSnapshot {
  const NodeSnapshot({required this.id});

  final NodeId id;
}
''');
  writeSandboxFile(sandbox, 'lib/src/core/scene_spatial_index.dart', '''
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';

class Rect {}

typedef SceneSpatialCandidateLocation = ({int layerIndex, int nodeIndex});
typedef SceneSpatialCandidateReference = ({
  String nodeId,
  int layerIndex,
  int nodeIndex,
});

enum ScenePaintSpatialQueryScope {
  contentLayersOnly,
  backgroundAndContentLayers,
}

class SceneHitTestSpatialCandidate {
  const SceneHitTestSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.hitTestBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect hitTestBoundsWorld;
}

class ScenePaintSpatialCandidate {
  const ScenePaintSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.paintBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect paintBoundsWorld;
}
''');
  writeSandboxFile(
    sandbox,
    'lib/src/controller/scene_controller_commit_runtime.dart',
    '''
class SceneControllerCommittedWrite<T> {
  const SceneControllerCommittedWrite();
}
''',
  );
  writeSandboxFile(sandbox, 'lib/src/controller/scene_writer.dart', '''
import 'dart:ui';

import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/snapshot.dart';
import '../contract/transform2d.dart';

class SceneWriter {
  SceneSnapshot get snapshot => const SceneSnapshot();

  Set<NodeId> get selectedNodeIds => <NodeId>{};

  Object get runtime => Object();

  NodeId writeNodeInsert(NodeSpec spec, {LayerId? layerId, int? insertIndex}) =>
      'id';

  bool writeLayerEnsure(LayerId layerId, {int? index}) => true;

  bool writeNodeErase(NodeId nodeId) => true;

  bool writeNodePatch(NodePatch patch) => true;

  bool writeNodeTransformSet(NodeId id, Transform2D transform) => true;

  bool writeSelectionReplace(Iterable<NodeId> ids) => true;

  bool writeSelectionToggle(NodeId id) => true;

  bool writeSelectionClear() => true;

  int writeSelectionSelectAll({bool onlySelectable = true}) => 0;

  int writeSelectionTranslate(Offset delta) => 0;

  int writeSelectionTransform(Transform2D delta) => 0;

  int writeDeleteSelection() => 0;

  List<NodeId> writeClearSceneKeepBackground() => const <NodeId>[];

  ClearSceneResult writeClearSceneKeepBackgroundResult() => ClearSceneResult();

  void writeCameraOffset(Offset offset) {}

  void writeGridEnable(bool enabled) {}

  void writeGridCellSize(double cellSize) {}

  void writeBackgroundColor(Color color) {}

  void writeDocumentReplace(SceneSnapshot snapshot) {}

  void writeSignalEnqueue({
    required String type,
    Iterable<NodeId> nodeIds = const <NodeId>[],
    Map<String, Object?>? payload,
  }) {}
}
''');
  writeSandboxFile(
    sandbox,
    'lib/src/controller/scene_store_controller.dart',
    '''
import 'dart:ui';

import '../contract/node_spec.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import '../core/scene_spatial_index.dart';
import 'scene_controller_commit_runtime.dart';
import 'scene_writer.dart';

class SceneStoreController {
  final String? textFontFamilyByDefault = null;

  SceneSnapshot get snapshot => const SceneSnapshot();

  Set<NodeId> get selectedNodeIds => <NodeId>{};

  int get controllerEpoch => 0;

  int get structuralRevision => 0;

  int get boundsRevision => 0;

  int get visualRevision => 0;

  Object get signals => Object();

  Object get debug => Object();

  T write<T>(T Function(SceneWriteTxn txn) fn) => fn(SceneWriteTxn());

  SceneControllerCommittedWrite<T> writeCommitted<T>(
    T Function(SceneWriteTxn txn) fn,
  ) => const SceneControllerCommittedWrite<T>();

  T writeWithSceneWriter<T>(T Function(SceneWriter writer) fn) =>
      fn(SceneWriter());

  SceneControllerCommittedWrite<T> writeWithSceneWriterCommitted<T>(
    T Function(SceneWriter writer) fn,
  ) => const SceneControllerCommittedWrite<T>();

  void requestRepaint() {}

  void dispose() {}
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) =>
      const <SceneHitTestSpatialCandidate>[];

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) => const <ScenePaintSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
  ) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})?
  resolveSnapshotNodeById(NodeId nodeId) => null;

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset.zero;
}

extension SceneStoreControllerCommittedSceneReplacementAccess
    on SceneStoreController {
  void writeReplaceScene(SceneSnapshot snapshot) {}
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_runtime_callbacks.dart',
    '''
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveRuntimeCallbacks {
  const InteractiveRuntimeCallbacks({
    required this.schedulePublicNotify,
    required this.scheduleSceneNotify,
    required this.scheduleOverlayNotify,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.readMode,
    required this.readDragStartSlop,
    required this.readDrawStyle,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.commitDrawStroke,
    required this.commitDrawLineFromWorldSegment,
    required this.commitEraseNodes,
  });

  final Object schedulePublicNotify;
  final Object scheduleSceneNotify;
  final Object scheduleOverlayNotify;
  final Object readSnapshot;
  final Object readSelectedNodeIds;
  final Object readMode;
  final Object readDragStartSlop;
  final Object readDrawStyle;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object writeSelectionReplace;
  final Object writeSelectionClear;
  final Object commitMoveSelection;
  final Object commitDrawStroke;
  final Object commitDrawLineFromWorldSegment;
  final Object commitEraseNodes;
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_move_callbacks.dart',
    '''
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveMoveSessionCallbacks {
  const InteractiveMoveSessionCallbacks({
    required this.onPublicStateChanged,
    required this.onSceneStateChanged,
    required this.onOverlayStateChanged,
    required this.readSnapshot,
    required this.readSelectedNodeIds,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.writeSelectionReplace,
    required this.writeSelectionClear,
    required this.commitMoveSelection,
    required this.emitAction,
  });

  final Object onPublicStateChanged;
  final Object onSceneStateChanged;
  final Object onOverlayStateChanged;
  final Object readSnapshot;
  final Object readSelectedNodeIds;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object writeSelectionReplace;
  final Object writeSelectionClear;
  final Object commitMoveSelection;
  final Object emitAction;
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart',
    '''
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveDrawCoordinatorCallbacks {
  const InteractiveDrawCoordinatorCallbacks({
    required this.onOverlayStateChanged,
    required this.emitAction,
    required this.commitDrawStroke,
    required this.commitDrawLineFromWorldSegment,
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.commitEraseNodes,
  });

  final Object onOverlayStateChanged;
  final Object emitAction;
  final Object commitDrawStroke;
  final Object commitDrawLineFromWorldSegment;
  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object commitEraseNodes;
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_eraser_targets.dart',
    '''
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveDrawEraserTargetsCallbacks {
  const InteractiveDrawEraserTargetsCallbacks({
    required this.queryHitTestCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.onSpatialQuery,
  });

  final List<SceneHitTestSpatialCandidate> Function(Rect bounds)
  queryHitTestCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidateReference candidate)
  resolveSpatialCandidateSnapshot;
  final Object onSpatialQuery;
}

class InteractiveDrawEraserTargets {}
''',
  );
}

String interactiveSelectionMutationsFixture({
  String setSelectionBody = '''
_ensureExternalMutationAllowed('setSelection');
_mutationBoundary.setSelection(nodeIds);
''',
}) {
  return '''
import 'internal/scene_controller_interaction_runtime.dart';

${_mutationOwnerFixture(className: 'SceneControllerSelectionOwner', policies: selectionMutationOwnerPolicies, bodyOverrides: <String, String>{'setSelection': setSelectionBody}, helperMethods: '''
  final SceneControllerInteractionRuntime _runtime =
      SceneControllerInteractionRuntime();
  final _mutationBoundary = _SelectionMutationsBoundary();

  void _ensureExternalMutationAllowed(String operation) {}
}

class _SelectionMutationsBoundary {
  void setSelection(Object nodeIds) {}

  void toggleSelection(Object nodeId) {}

  void clearSelection() {}

  void selectAll() {}

  void rotateSelection() {}

  void flipSelectionVertical() {}

  void flipSelectionHorizontal() {}

  void deleteSelection() {}
}
''')}''';
}

String interactiveSceneMutationsFixture({
  String writeBody = '''
_ensureExternalMutationAllowed('write');
_mutationBoundary.write(fn);
''',
  String setCameraOffsetBody = '''
_mutationBoundary.validateCameraOffset(value);
if (!_mutationBoundary.shouldApplyCameraOffset(value)) {
  return;
}
_interruptForExternalMutation();
_mutationBoundary.setCameraOffset(value);
''',
  String replaceSceneBody = '''
_mutationBoundary.replaceScene(
  snapshot,
  interruptBeforeApply: _interruptForExternalMutation,
);
''',
  String notifySceneChangedBody = '''
_mutationBoundary.notifySceneChanged();
''',
}) {
  return '''
import 'internal/scene_controller_interaction_runtime.dart';

${_mutationOwnerFixture(className: 'SceneControllerSceneOwner', policies: sceneMutationOwnerPolicies, bodyOverrides: <String, String>{'write': writeBody, 'setCameraOffset': setCameraOffsetBody, 'replaceScene': replaceSceneBody, 'notifySceneChanged': notifySceneChangedBody}, helperMethods: '''
  final SceneControllerInteractionRuntime _runtime =
      SceneControllerInteractionRuntime();
  final _mutationBoundary = _Mutations();

  final void Function(String operation) _ensureExternalMutationAllowed =
      (String operation) {};

  final void Function() _interruptForExternalMutation = () {};
}

class _Mutations {
  void write(Object fn) {}

  void setBackgroundColor(Object value) {}

  void setGridEnabled(bool value) {}

  void setGridCellSize(double value) {}

  void addNode(Object node) {}

  void ensureLayer(Object layerId) {}

  void patchNode(Object patch) {}

  void removeNode(Object nodeId) {}

  void clearScene() {}

  void validateCameraOffset(Object value) {}

  bool shouldApplyCameraOffset(Object value) => true;

  void setCameraOffset(Object value) {}

  void replaceScene(
    Object snapshot, {
    required Object interruptBeforeApply,
  }) {}

  void notifySceneChanged() {}
}
''')}''';
}

String _mutationOwnerFixture({
  required String className,
  required List<MutationOwnerPolicySpec> policies,
  required Map<String, String> bodyOverrides,
  required String helperMethods,
}) {
  final buffer = StringBuffer()..writeln('class $className {');
  for (final policy in policies) {
    buffer
      ..writeln(
        _mutationMethodFixture(
          methodName: policy.methodName,
          body:
              bodyOverrides[policy.methodName] ?? _defaultMutationBody(policy),
        ),
      )
      ..writeln();
  }
  buffer
    ..writeln(helperMethods.trimRight())
    ..writeln('}');
  return buffer.toString();
}

String _mutationMethodFixture({
  required String methodName,
  required String body,
}) {
  final bodyWithPublicGuard =
      """
_runtime.ensurePublicSideEffectAllowed('$methodName');
${body.trimRight()}
""";
  final normalizedBodyWithGuard = bodyWithPublicGuard
      .trimRight()
      .split('\n')
      .map((line) => '    $line')
      .join('\n');
  return '''
  ${_mutationMethodReturnType()} $methodName(${_mutationMethodParameter(methodName)}) {
$normalizedBodyWithGuard
  }''';
}

String _defaultMutationBody(MutationOwnerPolicySpec policy) {
  final guardCall = "${policy.requiredGuard}('${policy.methodName}');";
  return switch (policy.methodName) {
    'setSelection' => '$guardCall\n_mutationBoundary.setSelection(nodeIds);',
    'toggleSelection' =>
      '$guardCall\n_mutationBoundary.toggleSelection(nodeId);',
    'clearSelection' => '$guardCall\n_mutationBoundary.clearSelection();',
    'selectAll' => '$guardCall\n_mutationBoundary.selectAll();',
    'rotateSelection' => '$guardCall\n_mutationBoundary.rotateSelection();',
    'flipSelectionVertical' =>
      '$guardCall\n_mutationBoundary.flipSelectionVertical();',
    'flipSelectionHorizontal' =>
      '$guardCall\n_mutationBoundary.flipSelectionHorizontal();',
    'deleteSelection' => '$guardCall\n_mutationBoundary.deleteSelection();',
    'write' => '$guardCall\n_mutationBoundary.write(fn);',
    'setBackgroundColor' =>
      '$guardCall\n_mutationBoundary.setBackgroundColor(value);',
    'setGridEnabled' => '$guardCall\n_mutationBoundary.setGridEnabled(value);',
    'setGridCellSize' =>
      '$guardCall\n_mutationBoundary.setGridCellSize(value);',
    'addNode' => '$guardCall\n_mutationBoundary.addNode(node);',
    'ensureLayer' => '$guardCall\n_mutationBoundary.ensureLayer(layerId);',
    'patchNode' => '$guardCall\n_mutationBoundary.patchNode(patch);',
    'removeNode' => '$guardCall\n_mutationBoundary.removeNode(nodeId);',
    'clearScene' => '$guardCall\n_mutationBoundary.clearScene();',
    'notifySceneChanged' => '_mutationBoundary.notifySceneChanged();',
    _ => guardCall,
  };
}

String _mutationMethodReturnType() {
  return 'void';
}

String _mutationMethodParameter(String methodName) {
  switch (methodName) {
    case 'write':
      return 'Object fn';
    case 'setBackgroundColor':
      return 'Object value';
    case 'setGridEnabled':
      return 'bool value';
    case 'setGridCellSize':
      return 'double value';
    case 'addNode':
      return 'Object node';
    case 'ensureLayer':
      return 'Object layerId';
    case 'patchNode':
      return 'Object patch';
    case 'removeNode':
      return 'Object nodeId';
    case 'setCameraOffset':
      return 'Object value';
    case 'replaceScene':
      return 'Object snapshot';
    case 'setSelection':
      return 'Object nodeIds';
    case 'toggleSelection':
      return 'Object nodeId';
    case 'clearScene':
    case 'notifySceneChanged':
    case 'clearSelection':
    case 'selectAll':
    case 'rotateSelection':
    case 'flipSelectionVertical':
    case 'flipSelectionHorizontal':
    case 'deleteSelection':
      return '';
  }
  throw ArgumentError.value(methodName, 'methodName', 'Unsupported method.');
}
