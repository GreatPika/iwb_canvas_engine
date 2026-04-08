import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contract/scene_view_render_state.dart';
import '../contract/scene_view_runtime.dart';
import '../contract/snapshot.dart';
import '../contract/pointer_input.dart';
import '../controller/scene_store_controller.dart';
import '../core/action_events.dart';
import 'internal/scene_controller_graph.dart';
import 'scene_controller_interaction.dart';
import 'scene_controller_scene.dart';
import 'scene_controller_selection.dart';

class SceneController extends ChangeNotifier {
  SceneController({
    SceneSnapshot? initialSnapshot,
    PointerInputSettings? pointerSettings,
    double? dragStartSlop,
    bool clearSelectionOnDrawModeEnter = false,
    MoveCommitDeltaResolver? moveCommitDeltaResolver,
    String? textFontFamilyByDefault,
  }) : _storeController = SceneStoreController(
         initialSnapshot: initialSnapshot,
         textFontFamilyByDefault: textFontFamilyByDefault,
       ) {
    _graph = createSceneControllerGraph(
      SceneControllerGraphRequest(
        owner: this,
        notifyListeners: notifyListeners,
        storeController: _storeController,
        readSnapshot: () => snapshot,
        readSelectedNodeIds: () => selectedNodeIds,
        readControllerEpoch: () => controllerEpoch,
        readPreviewDeltaResolver: () => previewDeltaResolver,
        pointerSettings: pointerSettings,
        dragStartSlop: dragStartSlop,
        clearSelectionOnDrawModeEnter: clearSelectionOnDrawModeEnter,
        moveCommitDeltaResolver: moveCommitDeltaResolver,
      ),
    );
  }

  final SceneStoreController _storeController;
  late final SceneControllerGraph _graph;

  SceneViewRenderState get _viewRenderState =>
      _graph.sceneViewRuntime.renderState;

  SceneSnapshot get snapshot => _storeController.snapshot;
  Set<NodeId> get selectedNodeIds => _storeController.selectedNodeIds;
  int get controllerEpoch => _storeController.controllerEpoch;

  Rect? get selectionRect => _viewRenderState.selectionRect;
  Offset get cameraOffset => _viewRenderState.cameraOffset;
  Offset Function(NodeId nodeId) get previewDeltaResolver =>
      sceneControllerGraphPreviewDeltaResolver(_graph);

  bool get hasActiveStrokePreview => _viewRenderState.hasActiveStrokePreview;
  List<Offset> get activeStrokePreviewPoints =>
      _viewRenderState.activeStrokePreviewPoints;
  double get activeStrokePreviewThickness =>
      _viewRenderState.activeStrokePreviewThickness;
  Color get activeStrokePreviewColor =>
      _viewRenderState.activeStrokePreviewColor;
  double get activeStrokePreviewOpacity =>
      _viewRenderState.activeStrokePreviewOpacity;

  bool get hasActiveLinePreview => _viewRenderState.hasActiveLinePreview;
  Offset? get activeLinePreviewStart => _viewRenderState.activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _viewRenderState.activeLinePreviewEnd;
  double get activeLinePreviewThickness =>
      _viewRenderState.activeLinePreviewThickness;
  Color get activeLinePreviewColor => _viewRenderState.activeLinePreviewColor;

  SceneControllerInteraction get interaction => _graph.interaction;
  SceneControllerSelection get selection => _graph.selection;
  SceneControllerScene get scene => _graph.scene;

  Stream<ActionCommitted> get actions => sceneControllerGraphActions(_graph);
  Stream<EditTextRequested> get editTextRequests =>
      sceneControllerGraphEditTextRequests(_graph);

  void _ensurePublicSideEffectAllowed(
    String operation, {
    bool allowAfterDispose = false,
  }) {
    sceneControllerGraphEnsurePublicSideEffectAllowed(
      _graph,
      operation,
      allowAfterDispose: allowAfterDispose,
    );
  }

  @override
  void dispose() {
    _ensurePublicSideEffectAllowed('dispose', allowAfterDispose: true);
    if (sceneControllerGraphIsDisposed(_graph)) {
      return;
    }
    _storeController.dispose();
    disposeSceneControllerGraph(_graph);
    detachSceneControllerGraphInternalAccess(this);
    super.dispose();
  }
}

SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller) {
  return controller._graph.sceneViewRuntime;
}
