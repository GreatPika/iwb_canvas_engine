import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/src/guardrails/interactive_mutation_guard_contract.dart';
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
    'lib/src/controller/scene_controller_committed_mutation_access.dart',
    '''
abstract interface class SceneControllerCommittedMutationAccess {
  bool replaceSelection(Object nodeIds);

  bool clearSelection();

  int deleteSelection();

  int transformSelection(Object delta);

  void replaceScene(Object snapshot, {required Object beforeApply});

  Object commitDrawStroke(Object payload);

  Object commitDrawLineFromWorldSegment(Object payload);

  int commitEraseNodes(Object ids);

  Object clearSceneExactResult();
}

final class SceneStoreControllerCommittedMutationAccess
    implements SceneControllerCommittedMutationAccess {
  final int controllerEpoch = 0;

  @override
  bool replaceSelection(Object nodeIds) => true;

  @override
  bool clearSelection() => true;

  @override
  int deleteSelection() => 0;

  @override
  int transformSelection(Object delta) => 0;

  @override
  void replaceScene(Object snapshot, {required Object beforeApply}) {}

  @override
  Object commitDrawStroke(Object payload) => payload;

  @override
  Object commitDrawLineFromWorldSegment(Object payload) => payload;

  @override
  int commitEraseNodes(Object ids) => 0;

  @override
  Object clearSceneExactResult() => Object();
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/scene_controller_interaction.dart',
    '''
abstract interface class SceneControllerInteraction {
  void handlePointer(Object input);

  void handleDoubleTap();

  set mode(int value);
}

class SceneControllerInteractionOwner implements SceneControllerInteraction {
  final _access = _Access();

  @override
  void handlePointer(Object input) {
    _access.runtime.ensurePublicSideEffectAllowed('handlePointer');
  }

  @override
  void handleDoubleTap() {
    _access.runtime.ensurePublicSideEffectAllowed('handleDoubleTap');
  }

  @override
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
abstract interface class SceneControllerSelection {
  void setSelection(Object nodeIds);

  void toggleSelection(Object nodeId);

  void clearSelection();

  void selectAll();

  void rotateSelection();
}

class SceneControllerSelectionOwner implements SceneControllerSelection {
  final _runtime = _Runtime();

  @override
  void setSelection(Object nodeIds) {
    _runtime.ensurePublicSideEffectAllowed('setSelection');
  }

  @override
  void toggleSelection(Object nodeId) {
    _runtime.ensurePublicSideEffectAllowed('toggleSelection');
  }

  @override
  void clearSelection() {
    _runtime.ensurePublicSideEffectAllowed('clearSelection');
  }

  @override
  void selectAll() {
    _runtime.ensurePublicSideEffectAllowed('selectAll');
  }

  @override
  void rotateSelection() {
    _runtime.ensurePublicSideEffectAllowed('rotateSelection');
  }
}

class _Runtime {
  void ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {}

  void ensureExternalMutationAllowed(String operation) {}

  void interruptForExternalMutation() {}
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/scene_controller_scene.dart',
    '''
abstract interface class SceneControllerScene {
  void write(Object fn);

  void clearScene();
}

class SceneControllerSceneOwner implements SceneControllerScene {
  final void Function(String operation, {bool allowAfterDispose})
  ensurePublicSideEffectAllowed = _ensure;

  @override
  void write(Object fn) {
    ensurePublicSideEffectAllowed('write');
  }

  @override
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
    '''
class InteractiveSelectionActions {
  final mutations = Object();

  Object commitMoveSelection(Object proposedDelta) {
    return mutations.commitMoveSelection(proposedDelta);
  }
}

class _Mutations {
  Object commitMoveSelection(Object proposedDelta) => proposedDelta;
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

  void clearScene() {
    mutationAccess.clearSceneExactResult();
  }

  void setSelection(Object nodeIds) {
    if (!mutationAccess.replaceSelection(nodeIds)) {
      return;
    }
  }

  void clearSelection() {
    if (!mutationAccess.clearSelection()) {
      return;
    }
  }

  void deleteSelection() {
    mutationAccess.deleteSelection();
  }

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
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/interaction_eligibility_policy.dart',
    '''
Object _snapshotBoundsWorld(Object node) => node;

bool canSelect(Object node) => true;
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
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

class InteractiveRuntime {
  InteractiveRuntime({required this.events});

  final InteractiveEventDispatcher events;
  final mutationBoundary = SceneControllerMutationBoundary();

  void wireSelectionCallbacks() {
    // writeSelectionReplace: mutationBoundary.setSelection,
    // writeSelectionClear: mutationBoundary.clearSelection,
    // commitMoveSelection: mutationBoundary.commitMoveSelection,
    // commitDrawStroke: mutationBoundary.commitDrawStroke,
    // commitDrawLineFromWorldSegment:
    //     mutationBoundary.commitDrawLineFromWorldSegment,
    // commitEraseNodes: mutationBoundary.commitEraseNodes,
  }

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

  void interruptForExternalMutation() {}

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
  void handlePointer(Object sample) {}
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/interactive_draw_eraser_engine.dart',
    '''
import 'interactive_draw_eraser_exact_hit.dart';
import '../../contract/snapshot.dart';
import '../../core/scene_spatial_index.dart';

class InteractiveDrawEraserEngineCallbacks {
  const InteractiveDrawEraserEngineCallbacks({
    required this.onOverlayStateChanged,
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.commitEraseNodes,
  });

  final Object onOverlayStateChanged;
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateSnapshot;
  final Object commitEraseNodes;
}

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
  writeSandboxFile(sandbox, 'lib/src/contract/scene_view_runtime.dart', '''
abstract interface class SceneViewRuntime {
  Object get renderState;

  SceneViewPointerSession createPointerSession({
    required Object isMounted,
    required Object hasLiveRawPointers,
  });
}

abstract interface class SceneViewPointerSession {
  Object? get pendingTapFlushTimestampMs;

  void detach();

  void handleRoutedSample(Object sample);

  void handleInvalidTerminalSample(Object input);

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
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

class SceneControllerInteractionRuntimeRequest {
  SceneControllerInteractionRuntimeRequest({
    required this.mutationAccess,
  });

  final SceneControllerCommittedMutationAccess mutationAccess;
}

class SceneControllerInteractionRuntime {
  final mutationBoundary = SceneControllerMutationBoundary();

  void ensureExternalMutationAllowed(String operation) {}

  void interruptForInteractionConfigChange() {}

  void interruptForExternalMutation() {}

  void wireSelectionCallbacks() {
    // writeSelectionReplace: mutationBoundary.setSelection,
    // writeSelectionClear: mutationBoundary.clearSelection,
    // commitMoveSelection: mutationBoundary.commitMoveSelection,
    // commitDrawStroke: mutationBoundary.commitDrawStroke,
    // commitDrawLineFromWorldSegment:
    //     mutationBoundary.commitDrawLineFromWorldSegment,
    // commitEraseNodes: mutationBoundary.commitEraseNodes,
  }

  PointerSessionToken createPointerSessionToken() => PointerSessionToken();

  void detachPointerSession(PointerSessionToken token) {
    _ensureKnownPointerSessionToken(token);
  }

  void releasePointerSessionToken(PointerSessionToken token) {
    _ensureKnownPointerSessionToken(token);
  }

  void handlePublicPointer(CanvasPointerInput input) {}

  void handlePublicDoubleTap({required Offset position, int? timestampMs}) {}

  void handlePointerFromSession(
    CanvasPointerInput input, {
    required PointerSessionToken token,
  }) {
    _ensureKnownPointerSessionToken(token);
  }

  void handleDoubleTapFromSession({
    required Offset position,
    int? timestampMs,
    required PointerSessionToken token,
  }) {
    _ensureKnownPointerSessionToken(token);
  }

  void _ensureKnownPointerSessionToken(PointerSessionToken token) {}
}

SceneControllerMutationBoundary wireRuntime(
  SceneControllerInteractionRuntimeRequest request,
) {
  return SceneControllerMutationBoundary()
    // mutationAccess: request.mutationAccess,
    ;
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_interaction_access.dart',
    'class SceneControllerInteractionContext {}\n',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/view/scene_view_interactive_pointer_host.dart',
    '''
import '../contract/scene_view_runtime.dart';

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

  final _pointerRouter = _PointerRouter();
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

class _PointerRouter {
  void reset() {}
}
''',
  );
  writeSandboxFile(sandbox, 'lib/src/view/scene_view_interactive.dart', '''
import '../interactive/scene_controller.dart';
import 'scene_view_runtime_host.dart';

class SceneViewInteractive {
  Object build(SceneController controller) {
    return SceneViewRuntimeHost(
      runtime: sceneControllerViewRuntimeOf(controller),
    );
  }
}
''');
  writeSandboxFile(sandbox, 'lib/src/view/scene_view_runtime_host.dart', '''
class SceneViewRuntimeHost extends StatefulWidget {
  final SceneViewRuntime runtime;

  SceneViewRuntimeHost({required this.runtime});
}

class _SceneViewRuntimeHostState {
  final SceneViewInteractivePointerHost _pointerHost =
      SceneViewInteractivePointerHost();
  late SceneViewRuntime _activeRuntime;

  void initState() {
    _activeRuntime = widget.runtime;
    _activeRuntime.createPointerSession(
      isMounted: Object(),
      hasLiveRawPointers: Object(),
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
    final renderState = _activeRuntime.renderState;
    return SceneViewRenderSurface(renderState: renderState);
  }

  Object _createReplacementPointerSession(SceneViewRuntime runtime) {
    return runtime.createPointerSession(
      isMounted: Object(),
      hasLiveRawPointers: Object(),
    );
  }
}

class StatefulWidget {}

class SceneViewInteractivePointerHost {
  void replacePointerSession(Object session) {}
}

class SceneViewRenderSurface {
  SceneViewRenderSurface({
    required Object renderState,
  });
}
''');
  writeSandboxFile(sandbox, 'lib/src/view/scene_view_render_surface.dart', '''
class SceneViewRenderState {}

class SceneViewRenderSurface {
  SceneViewRenderSurface({
    required SceneViewRenderState renderState,
  });
}
''');
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_pointer_session.dart',
    '''
class PointerInputTracker {}

class PointerSessionToken {}

class SceneControllerPointerSession {
  SceneControllerPointerSession({
    required PointerSessionToken token,
    required void Function(PointerSessionToken token) detachPointerSession,
    required void Function(PointerSessionToken token) releasePointerSessionToken,
  }) : _token = token;

  final PointerSessionToken _token;
  final Object _ownerListener = Object();

  final _ownerListenable = _OwnerListenable();
  final _PendingTapFlushScheduler scheduler = _PendingTapFlushScheduler();

  void createTracker() {
    PointerInputTracker();
  }

  void attach() {
    _ownerListenable.addListener(_ownerListener);
  }

  void route(PointerSessionToken token) {
    _handlePointerFromSession(token);
    _handleDoubleTapFromSession(token);
  }

  void detach() {
    _detachPointerSession(_token);
    _releaseOwnedResources();
  }

  void dispose(PointerSessionToken token) {
    scheduler.dispose();
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

class _OwnerListenable {
  void addListener(Object listener) {}

  void removeListener(Object listener) {}
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
    interactiveSceneMutationsFixture(),
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_selection_mutations.dart',
    interactiveSelectionMutationsFixture(),
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
    '''
final class SceneControllerSceneViewRuntime {
  SceneControllerSceneViewRuntime({
    Object? ensurePublicSideEffectAllowed,
  });

  final renderState = SceneControllerSceneViewRenderState();
  final _interactionRuntime = _InteractionRuntime();

  Object createPointerSession({
    required Object isMounted,
    required Object hasLiveRawPointers,
  }) {
    createPointerSessionToken();
    return SceneControllerPointerSession(
      token: createPointerSessionToken(),
      detachPointerSession:
          _interactionRuntime.detachPointerSession,
      releasePointerSessionToken:
          _interactionRuntime.releasePointerSessionToken,
      // handlePointerFromSession: _interactionRuntime.handlePointerFromSession,
    );
  }

  Object createPointerSessionToken() => Object();
}

class SceneControllerInteraction {}
class _InteractionRuntime {
  void detachPointerSession() {}
  void releasePointerSessionToken() {}
  void handlePointerFromSession() {}
}

final class SceneControllerSceneViewRenderState {
  SceneControllerInteraction get _interaction => SceneControllerInteraction();
}
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_graph.dart',
    '''
class SceneControllerInteraction {}

class SceneControllerInteractionOwner extends SceneControllerInteraction {}

class SceneControllerSelectionOwner {
  SceneControllerSelectionOwner({
    required Object runtime,
    required Object mutations,
  });
}

class SceneControllerSceneOwner {
  SceneControllerSceneOwner({
    required Object ensurePublicSideEffectAllowed,
    required Object mutations,
  });
}

class _InteractionRuntime {
  final mutationBoundary = Object();

  void ensurePublicSideEffectAllowed(String operation) {}
}

class SceneControllerGraphRequest {}

class SceneControllerInternalAccessRegistration {}

class _Graph {
  final sceneViewRuntime = SceneControllerSceneViewRuntime(
    ensurePublicSideEffectAllowed:
        _InteractionRuntime().ensurePublicSideEffectAllowed,
  );
}

Object createSceneControllerGraph(Object request) {
  final interactionRuntime = _InteractionRuntime();
  SceneControllerInternalAccessRegistration();
  registerSceneControllerInternalAccess(Object(), Object());
  SceneControllerInteractionOwner();
  SceneControllerSelectionOwner(
    runtime: interactionRuntime,
    mutations: interactionRuntime.mutationBoundary,
  );
  SceneControllerSceneOwner(
    ensurePublicSideEffectAllowed:
        interactionRuntime.ensurePublicSideEffectAllowed,
    mutations: interactionRuntime.mutationBoundary,
  );
  return _Graph();
}

Object sceneControllerGraphActions(Object graph) => Object();

Object sceneControllerGraphEditTextRequests(Object graph) => Object();
''',
  );
  writeSandboxFile(
    sandbox,
    'lib/src/interactive/internal/scene_controller_internal_access.dart',
    '''
void registerSceneControllerInternalAccess(
  Object controller,
  Object registration,
) {}

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
typedef NodeId = String;

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
import '../contract/snapshot.dart';

class Rect {}

class SceneSpatialCandidate {
  const SceneSpatialCandidate({
    required this.nodeId,
    required this.layerIndex,
    required this.nodeIndex,
    required this.candidateBoundsWorld,
  });

  final NodeId nodeId;
  final int layerIndex;
  final int nodeIndex;
  final Rect candidateBoundsWorld;
}
''');
  writeSandboxFile(
    sandbox,
    'lib/src/controller/scene_store_controller.dart',
    '''
import '../contract/snapshot.dart';
import '../core/scene_spatial_index.dart';

class Offset {}
class SceneSnapshot {}

class SceneStoreController {
  final int controllerEpoch = 0;
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneSpatialCandidate> querySpatialCandidates(Rect worldBounds) =>
      const <SceneSpatialCandidate>[];

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidate candidate,
  ) => null;

  ({NodeSnapshot node, int layerIndex, int nodeIndex})?
  resolveSnapshotNodeById(NodeId nodeId) => null;

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) =>
      Offset();
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
    required this.querySpatialCandidates,
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
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidate candidate)
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
    required this.querySpatialCandidates,
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
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidate candidate)
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
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.commitEraseNodes,
  });

  final Object onOverlayStateChanged;
  final Object emitAction;
  final Object commitDrawStroke;
  final Object commitDrawLineFromWorldSegment;
  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidate candidate)
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
    required this.querySpatialCandidates,
    required this.resolveSpatialCandidateSnapshot,
    required this.onSpatialQuery,
  });

  final List<SceneSpatialCandidate> Function(Rect bounds)
  querySpatialCandidates;
  final NodeSnapshot? Function(SceneSpatialCandidate candidate)
  resolveSpatialCandidateSnapshot;
  final Object onSpatialQuery;
}
''',
  );
}

String interactiveSelectionMutationsFixture({
  String setSelectionBody = "ensureExternalMutationAllowed('setSelection');",
}) {
  return _mutationOwnerFixture(
    className: 'SceneControllerSelectionMutations',
    policies: selectionMutationOwnerPolicies,
    bodyOverrides: <String, String>{'setSelection': setSelectionBody},
    helperMethods: '''
  final mutations = Object();

  void ensureExternalMutationAllowed(String operation) {}

  void _touchMutationBoundary() {
    mutations.toString();
  }
''',
  );
}

String interactiveSceneMutationsFixture({
  String writeBody = "ensureExternalMutationAllowed('write');",
  String setCameraOffsetBody = '''
_requireFiniteOffset(value);
if (_isSameOffset(value)) {
  return;
}
interruptForExternalMutation();
''',
  String replaceSceneBody = '''
mutations.replaceScene(
  snapshot,
  interruptBeforeApply: interruptForExternalMutation,
);
''',
}) {
  return _mutationOwnerFixture(
    className: 'SceneControllerSceneMutations',
    policies: sceneMutationOwnerPolicies,
    bodyOverrides: <String, String>{
      'write': writeBody,
      'setCameraOffset': setCameraOffsetBody,
      'replaceScene': replaceSceneBody,
    },
    helperMethods: '''
  final mutations = _Mutations();

  void ensureExternalMutationAllowed(String operation) {}

  void interruptForExternalMutation() {}

  void _requireFiniteOffset(Object value) {}

  bool _isSameOffset(Object value) => false;

  void _touchMutationBoundary() {
    mutations.toString();
  }
''',
  );
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
  final normalizedBody = body
      .trimRight()
      .split('\n')
      .map((line) => '    $line')
      .join('\n');
  return '''
  ${_mutationMethodReturnType()} $methodName(${_mutationMethodParameter(methodName)}) {
$normalizedBody
  }''';
}

String _defaultMutationBody(MutationOwnerPolicySpec policy) {
  return "${policy.policyCall}('${policy.methodName}');";
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
