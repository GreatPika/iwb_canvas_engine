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
        pointerSettings: pointerSettings,
        dragStartSlop: dragStartSlop,
        clearSelectionOnDrawModeEnter: clearSelectionOnDrawModeEnter,
        moveCommitDeltaResolver: moveCommitDeltaResolver,
      ),
    );
  }

  final SceneStoreController _storeController;
  late final SceneControllerGraph _graph;

  SceneViewOverlayPreviewRead get _overlayPreviewRead =>
      _graph.sceneViewRuntime.overlayPreviewRead;

  SceneSnapshot get snapshot => _storeController.snapshot;
  Set<NodeId> get selectedNodeIds => _storeController.selectedNodeIds;
  int get controllerEpoch => _storeController.controllerEpoch;

  Rect? get selectionRect => _overlayPreviewRead.selectionRect;
  Offset get cameraOffset => _overlayPreviewRead.cameraOffset;
  Offset Function(NodeId nodeId) get previewDeltaResolver =>
      sceneControllerGraphPreviewDeltaResolver(_graph);

  bool get hasActiveStrokePreview => _overlayPreviewRead.hasActiveStrokePreview;
  List<Offset> get activeStrokePreviewPoints =>
      _overlayPreviewRead.activeStrokePreviewPoints;
  double get activeStrokePreviewThickness =>
      _overlayPreviewRead.activeStrokePreviewThickness;
  Color get activeStrokePreviewColor =>
      _overlayPreviewRead.activeStrokePreviewColor;
  double get activeStrokePreviewOpacity =>
      _overlayPreviewRead.activeStrokePreviewOpacity;

  bool get hasActiveLinePreview => _overlayPreviewRead.hasActiveLinePreview;
  Offset? get activeLinePreviewStart =>
      _overlayPreviewRead.activeLinePreviewStart;
  Offset? get activeLinePreviewEnd => _overlayPreviewRead.activeLinePreviewEnd;
  double get activeLinePreviewThickness =>
      _overlayPreviewRead.activeLinePreviewThickness;
  Color get activeLinePreviewColor =>
      _overlayPreviewRead.activeLinePreviewColor;

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
