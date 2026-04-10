import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:iwb_canvas_engine/src/controller/scene_snapshot_materializer.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/contract/scene_view_render_state.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';

class CommittedSceneViewRenderState extends ChangeNotifier
    implements SceneViewRenderState {
  CommittedSceneViewRenderState({
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

  CommittedSceneViewRenderState.mirror(
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
  Rect? get selectionRect => _selectionRect;

  @override
  Offset get cameraOffset => snapshot.camera.offset;

  @override
  Offset Function(NodeId nodeId) get previewDeltaResolver =>
      _previewDeltaResolver;

  @override
  Iterable<NodeSnapshot> enumeratePaintCandidates(Rect worldRect) {
    return enumerateSnapshotPaintCandidates(
      snapshot: snapshot,
      worldRect: worldRect,
      previewDeltaResolver: previewDeltaResolver,
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

Iterable<NodeSnapshot> enumerateSnapshotPaintCandidates({
  required SceneSnapshot snapshot,
  required Rect worldRect,
  required Offset Function(NodeId nodeId) previewDeltaResolver,
}) sync* {
  for (final node in snapshot.backgroundLayer.nodes) {
    if (_snapshotNodeOverlapsWorldRect(node, worldRect, previewDeltaResolver)) {
      yield node;
    }
  }
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      if (_snapshotNodeOverlapsWorldRect(
        node,
        worldRect,
        previewDeltaResolver,
      )) {
        yield node;
      }
    }
  }
}

bool _snapshotNodeOverlapsWorldRect(
  NodeSnapshot node,
  Rect worldRect,
  Offset Function(NodeId nodeId) previewDeltaResolver,
) {
  final previewDelta = _safePreviewDelta(previewDeltaResolver(node.id));
  final candidateBounds = boundsWorldForNodeSnapshot(node).shift(previewDelta);
  return _isFiniteRect(candidateBounds) && worldRect.overlaps(candidateBounds);
}

Offset _safePreviewDelta(Offset value) {
  if (!value.dx.isFinite || !value.dy.isFinite) {
    return Offset.zero;
  }
  return value;
}

bool _isFiniteRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}
