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
  }

  void toggleSelection(Object nodeId) {
    _runtime.ensurePublicSideEffectAllowed('toggleSelection');
  }

  void clearSelection() {
    _runtime.ensurePublicSideEffectAllowed('clearSelection');
  }

  void selectAll() {
    _runtime.ensurePublicSideEffectAllowed('selectAll');
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

  void ensureExternalMutationAllowed(String operation) {}

  void interruptForExternalMutation() {}
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
class SceneControllerMutationBoundary {
  final storeController = _Core();

  void clearScene() {
    storeController.commands.writeClearSceneExactResult();
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

  Object prepareSceneReplacement(Object snapshot) => snapshot;

  void writePreparedSceneReplacement(Object replacement) {}
}

class _Commands {
  void writeClearSceneExactResult() {}

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
import 'pointer_session_token.dart';
import 'scene_controller_mutation_boundary.dart';

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
  }) : session = pointerSession;

  final SceneViewPointerSession session;

  void replacePointerSession(SceneViewPointerSession pointerSession) {
    pointerSession.dispose();
  }
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
  final Object runtime;
  final Object _pointerHost = Object();

  SceneViewRuntimeHost({required this.runtime});

  Object build() {
    widget.runtime.createPointerSession(
      isMounted: Object(),
      hasLiveRawPointers: Object(),
    );
    _pointerHost.replacePointerSession(Object());
    return SceneViewRenderSurface(renderState: Object());
  }
}

class StatefulWidget {}

class SceneViewRenderSurface {
  SceneViewRenderSurface({
    required Object renderState,
  });
}

final widget = _WidgetRuntime();

class _WidgetRuntime {
  Object createPointerSession({
    required Object isMounted,
    required Object hasLiveRawPointers,
  }) => Object();
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
    required void Function(PointerSessionToken token) releasePointerSessionToken,
  });

  final _ownerListenable = _OwnerListenable();
  final _PendingTapFlushScheduler scheduler = _PendingTapFlushScheduler();

  void createTracker() {
    PointerInputTracker();
  }

  void attach() {
    _ownerListenable.addListener(Object());
  }

  void route(PointerSessionToken token) {
    _handlePointerFromSession(token);
    _handleDoubleTapFromSession(token);
  }

  void dispose(PointerSessionToken token) {
    _releasePointerSessionToken(token);
  }

  void _handlePointerFromSession(PointerSessionToken token) {}

  void _handleDoubleTapFromSession(PointerSessionToken token) {}

  void _releasePointerSessionToken(PointerSessionToken token) {}
}

class _PendingTapFlushScheduler {}

class _OwnerListenable {
  void addListener(Object listener) {}
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
      releasePointerSessionToken:
          _interactionRuntime.releasePointerSessionToken,
      // handlePointerFromSession: _interactionRuntime.handlePointerFromSession,
    );
  }

  Object createPointerSessionToken() => Object();
}

class SceneControllerInteraction {}
class _InteractionRuntime {
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

class SceneControllerSelection {
  SceneControllerSelection({required Object runtime, required Object mutations});
}

class SceneControllerScene {
  SceneControllerScene({
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
  SceneControllerInteraction();
  SceneControllerSelection(
    runtime: interactionRuntime,
    mutations: interactionRuntime.mutationBoundary,
  );
  SceneControllerScene(
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
final replacement = mutations.prepareSceneReplacement(snapshot);
interruptForExternalMutation();
mutations.replaceScene(replacement);
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
