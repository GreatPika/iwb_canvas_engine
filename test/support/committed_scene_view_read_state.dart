import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_render_state.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/core/scene_snapshot_paint_candidates.dart';

class CommittedSceneViewReadState extends ChangeNotifier
    implements SceneViewMainSceneRenderRead, SceneViewOverlayPreviewRead {
  CommittedSceneViewReadState({
    required SceneSnapshot snapshot,
    Set<NodeId> selectedNodeIds = const <NodeId>{},
    int controllerEpoch = 0,
    Offset Function(NodeId nodeId)? previewDeltaResolver,
    Rect? selectionRect,
  }) : _snapshot = snapshot,
       _mirroredController = null,
       _selectedNodeIds = Set<NodeId>.unmodifiable(selectedNodeIds),
       _controllerEpoch = controllerEpoch,
       _previewDeltaResolver = previewDeltaResolver ?? _zeroPreviewDelta,
       _selectionRect = selectionRect;

  CommittedSceneViewReadState.mirror(
    SceneStoreController controller, {
    Offset Function(NodeId nodeId)? previewDeltaResolver,
    Rect? selectionRect,
  }) : _mirroredController = controller,
       _previewDeltaResolver = previewDeltaResolver ?? _zeroPreviewDelta,
       _selectionRect = selectionRect {
    _syncFromController(controller);
    controller.addListener(_handleMirroredControllerChanged);
  }

  final SceneStoreController? _mirroredController;
  final Offset Function(NodeId nodeId) _previewDeltaResolver;
  final Rect? _selectionRect;

  SceneSnapshot _snapshot = SceneSnapshot();
  Set<NodeId> _selectedNodeIds = const <NodeId>{};
  int _controllerEpoch = 0;

  @override
  SceneSnapshot get snapshot => _mirroredController?.snapshot ?? _snapshot;

  @override
  Set<NodeId> get selectedNodeIds =>
      _mirroredController?.selectedNodeIds ?? _selectedNodeIds;

  @override
  int get controllerEpoch =>
      _mirroredController?.controllerEpoch ?? _controllerEpoch;

  @override
  Listenable get overlayRepaintListenable => this;

  @override
  Rect? get selectionRect => _selectionRect;

  @override
  Offset get cameraOffset => snapshot.camera.offset;

  @override
  SceneViewFrameRead captureFrameRead() {
    return SceneViewFrameRead(
      snapshot: snapshot,
      selectedNodeIds: selectedNodeIds,
      selectionRevision: 0,
      preview: SceneViewFramePreview.captureSnapshot(
        snapshot: snapshot,
        deltaForNode: _previewDeltaResolver,
      ),
    );
  }

  @override
  ScenePreparedPaintPlan preparePaintPlan(
    SceneViewFrameRead frameRead,
    ScenePaintCandidateQuery query,
  ) {
    return ScenePreparedPaintCandidateList(
      enumerateSnapshotPaintCandidates(
        snapshot: frameRead.snapshot,
        query: query,
        selectedNodeIds: frameRead.selectedNodeIds,
        preview: frameRead.preview,
      ),
    );
  }

  @override
  bool get hasActiveStrokePreview => false;

  @override
  List<Offset> get activeStrokePreviewPoints => const <Offset>[];

  @override
  double get activeStrokePreviewThickness => 0;

  @override
  Color get activeStrokePreviewColor => const Color(0x00000000);

  @override
  double get activeStrokePreviewOpacity => 0;

  @override
  bool get hasActiveLinePreview => false;

  @override
  Offset? get activeLinePreviewStart => null;

  @override
  Offset? get activeLinePreviewEnd => null;

  @override
  double get activeLinePreviewThickness => 0;

  @override
  Color get activeLinePreviewColor => const Color(0x00000000);

  @override
  void dispose() {
    _mirroredController?.removeListener(_handleMirroredControllerChanged);
    super.dispose();
  }

  void _handleMirroredControllerChanged() {
    final controller = _mirroredController;
    if (controller == null) {
      return;
    }
    _syncFromController(controller);
    notifyListeners();
  }

  void _syncFromController(SceneStoreController controller) {
    _snapshot = controller.snapshot;
    _selectedNodeIds = Set<NodeId>.unmodifiable(controller.selectedNodeIds);
    _controllerEpoch = controller.controllerEpoch;
  }
}

Offset _zeroPreviewDelta(NodeId _) => Offset.zero;
