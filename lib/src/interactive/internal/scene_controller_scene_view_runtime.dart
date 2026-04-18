import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../contract/scene_view_render_state.dart';
import '../../contract/scene_view_runtime.dart';
import '../../contract/snapshot.dart';
import '../../controller/scene_store_controller.dart';
import '../../core/geometry.dart';
import '../../core/node_geometry.dart';
import '../../core/numeric_clamp.dart';
import '../../core/scene_spatial_index.dart';
import '../../core/scene_snapshot_paint_candidates.dart';
import '../scene_controller_interaction.dart';
import 'scene_controller_interaction_runtime.dart';
import 'scene_controller_pointer_session.dart';

final class SceneControllerSceneViewRuntime implements SceneViewRuntime {
  SceneControllerSceneViewRuntime({
    required SceneStoreController storeController,
    required Listenable ownerListenable,
    required void Function(String operation, {bool allowAfterDispose})
    ensurePublicSideEffectAllowed,
    required SceneSnapshot Function() readSnapshot,
    required Set<NodeId> Function() readSelectedNodeIds,
    required int Function() readControllerEpoch,
    required Offset Function(NodeId nodeId) Function() readPreviewDeltaResolver,
    required SceneControllerInteraction Function() readInteraction,
    required SceneControllerInteractionRuntime Function()
    readInteractionRuntime,
  }) : _ownerListenable = ownerListenable,
       _ensurePublicSideEffectAllowed = ensurePublicSideEffectAllowed,
       _readInteraction = readInteraction,
       _readInteractionRuntime = readInteractionRuntime,
       _renderState = SceneControllerSceneViewRenderState(
         storeController: storeController,
         readSnapshot: readSnapshot,
         readSelectedNodeIds: readSelectedNodeIds,
         readControllerEpoch: readControllerEpoch,
         readPreviewDeltaResolver: readPreviewDeltaResolver,
         readInteraction: readInteraction,
       );

  final Listenable _ownerListenable;
  final void Function(String operation, {bool allowAfterDispose})
  _ensurePublicSideEffectAllowed;
  final SceneControllerInteraction Function() _readInteraction;
  final SceneControllerInteractionRuntime Function() _readInteractionRuntime;
  final SceneControllerSceneViewRenderState _renderState;

  SceneControllerInteractionRuntime get _interactionRuntime =>
      _readInteractionRuntime();

  @override
  SceneViewRenderState get renderState => _renderState;

  void scheduleSceneRepaint() {
    _renderState.scheduleSceneRepaint();
  }

  void scheduleOverlayRepaint() {
    _renderState.scheduleOverlayRepaint();
  }

  void dispose() {
    _renderState.dispose();
  }

  @override
  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  }) {
    _ensurePublicSideEffectAllowed('createPointerSession');
    final token = _interactionRuntime.createPointerSessionToken();
    return SceneControllerPointerSession(
      ownerListenable: _ownerListenable,
      token: token,
      readPointerSettings: () => _readInteraction().pointerSettings,
      isMounted: isMounted,
      hasLiveRawPointers: hasLiveRawPointers,
      detachPointerSession: _interactionRuntime.detachPointerSession,
      releasePointerSessionToken:
          _interactionRuntime.releasePointerSessionToken,
      handlePointerFromSession: _interactionRuntime.handlePointerFromSession,
      handleDoubleTapFromSession:
          _interactionRuntime.handleDoubleTapFromSession,
    );
  }
}

final class SceneControllerSceneViewRenderState
    implements SceneViewRenderState {
  SceneControllerSceneViewRenderState({
    required SceneStoreController storeController,
    required SceneSnapshot Function() readSnapshot,
    required Set<NodeId> Function() readSelectedNodeIds,
    required int Function() readControllerEpoch,
    required Offset Function(NodeId nodeId) Function() readPreviewDeltaResolver,
    required SceneControllerInteraction Function() readInteraction,
  }) : _storeController = storeController,
       _readSnapshot = readSnapshot,
       _readSelectedNodeIds = readSelectedNodeIds,
       _readControllerEpoch = readControllerEpoch,
       _readPreviewDeltaResolver = readPreviewDeltaResolver,
       _readInteraction = readInteraction;

  final SceneStoreController _storeController;
  final SceneControllerSceneRepaintChannel _sceneRepaintChannel =
      SceneControllerSceneRepaintChannel();
  final SceneControllerOverlayRepaintChannel _overlayRepaintChannel =
      SceneControllerOverlayRepaintChannel();
  final SceneSnapshot Function() _readSnapshot;
  final Set<NodeId> Function() _readSelectedNodeIds;
  final int Function() _readControllerEpoch;
  final Offset Function(NodeId nodeId) Function() _readPreviewDeltaResolver;
  final SceneControllerInteraction Function() _readInteraction;

  SceneControllerInteraction get _interaction => _readInteraction();

  @override
  void addListener(VoidCallback listener) {
    _sceneRepaintChannel.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _sceneRepaintChannel.removeListener(listener);
  }

  @override
  Listenable get overlayRepaintListenable => _overlayRepaintChannel;

  @override
  SceneSnapshot get snapshot => _readSnapshot();

  @override
  Set<NodeId> get selectedNodeIds => _readSelectedNodeIds();

  @override
  int get controllerEpoch => _readControllerEpoch();

  @override
  Rect? get selectionRect => _interaction.selectionRect;

  @override
  Offset get cameraOffset => snapshot.camera.offset;

  @override
  Offset Function(NodeId nodeId) get previewDeltaResolver =>
      _readPreviewDeltaResolver();

  @override
  SceneViewFrameRead captureFrameRead() {
    return SceneViewFrameRead(
      snapshot: _readSnapshot(),
      selectedNodeIds: _readSelectedNodeIds(),
      previewDeltaResolver: _readPreviewDeltaResolver(),
    );
  }

  @override
  Iterable<ScenePaintCandidate> enumeratePaintCandidates(
    SceneViewFrameRead frameRead,
    ScenePaintCandidateQuery query,
  ) sync* {
    final snapshot = frameRead.snapshot;
    if (!identical(snapshot, _storeController.snapshot)) {
      yield* enumerateSnapshotPaintCandidates(
        snapshot: frameRead.snapshot,
        query: query,
        selectedNodeIds: frameRead.selectedNodeIds,
        previewDeltaResolver: frameRead.previewDeltaResolver,
      );
      return;
    }
    yield* _enumerateCommittedSnapshotPaintCandidates(
      query: query,
      selectedNodeIds: frameRead.selectedNodeIds,
      previewResolver: frameRead.previewDeltaResolver,
    );
  }

  Iterable<ScenePaintCandidate> _enumerateCommittedSnapshotPaintCandidates({
    required ScenePaintCandidateQuery query,
    required Set<NodeId> selectedNodeIds,
    required Offset Function(NodeId nodeId) previewResolver,
  }) sync* {
    final acceptedNodeIds = <NodeId>{};
    final orderedCandidates =
        <({ScenePaintCandidate candidate, int layerIndex, int nodeIndex})>[];

    for (final candidate in _storeController.queryPaintCandidates(
      query.viewportRect,
      scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
    )) {
      final resolvedNode = _storeController.resolveSpatialCandidateSnapshot((
        nodeId: candidate.nodeId,
        layerIndex: candidate.layerIndex,
        nodeIndex: candidate.nodeIndex,
      ));
      if (resolvedNode == null || !acceptedNodeIds.add(resolvedNode.id)) {
        continue;
      }
      orderedCandidates.add((
        candidate: ScenePaintCandidate(
          node: resolvedNode,
          paintBoundsWorld: candidate.paintBoundsWorld,
        ),
        layerIndex: candidate.layerIndex,
        nodeIndex: candidate.nodeIndex,
      ));
    }

    for (final nodeId in selectedNodeIds) {
      final resolvedNode = _storeController.resolveSnapshotNodeById(nodeId);
      if (resolvedNode == null || acceptedNodeIds.contains(nodeId)) {
        continue;
      }
      final paintBounds = _snapshotPaintBoundsWorld(
        node: resolvedNode.node,
        previewResolver: previewResolver,
      );
      if (!isFiniteRect(paintBounds) ||
          !query.visibilityRect.overlaps(paintBounds)) {
        continue;
      }
      if (!acceptedNodeIds.add(nodeId)) {
        continue;
      }
      orderedCandidates.add((
        candidate: ScenePaintCandidate(
          node: resolvedNode.node,
          paintBoundsWorld: paintBounds,
        ),
        layerIndex: resolvedNode.layerIndex,
        nodeIndex: resolvedNode.nodeIndex,
      ));
    }

    orderedCandidates.sort((a, b) {
      final layerOrder = a.layerIndex.compareTo(b.layerIndex);
      if (layerOrder != 0) {
        return layerOrder;
      }
      return a.nodeIndex.compareTo(b.nodeIndex);
    });

    for (final candidate in orderedCandidates) {
      yield candidate.candidate;
    }
  }

  @override
  bool get hasActiveStrokePreview => _interaction.hasActiveStrokePreview;

  @override
  List<Offset> get activeStrokePreviewPoints =>
      _interaction.activeStrokePreviewPoints;

  @override
  double get activeStrokePreviewThickness =>
      _interaction.activeStrokePreviewThickness;

  @override
  Color get activeStrokePreviewColor => _interaction.activeStrokePreviewColor;

  @override
  double get activeStrokePreviewOpacity =>
      _interaction.activeStrokePreviewOpacity;

  @override
  bool get hasActiveLinePreview => _interaction.hasActiveLinePreview;

  @override
  Offset? get activeLinePreviewStart => _interaction.activeLinePreviewStart;

  @override
  Offset? get activeLinePreviewEnd => _interaction.activeLinePreviewEnd;

  @override
  double get activeLinePreviewThickness =>
      _interaction.activeLinePreviewThickness;

  @override
  Color get activeLinePreviewColor => _interaction.activeLinePreviewColor;

  void scheduleSceneRepaint() {
    _sceneRepaintChannel.scheduleNotify();
  }

  void scheduleOverlayRepaint() {
    _overlayRepaintChannel.scheduleNotify();
  }

  void dispose() {
    _sceneRepaintChannel.dispose();
    _overlayRepaintChannel.dispose();
  }
}

final class SceneControllerSceneRepaintChannel extends ChangeNotifier {
  SceneControllerSceneRepaintChannel();

  void scheduleNotify() {
    notifyListeners();
  }
}

final class SceneControllerOverlayRepaintChannel extends ChangeNotifier {
  SceneControllerOverlayRepaintChannel();

  void scheduleNotify() {
    notifyListeners();
  }
}

Offset _previewDeltaForNode(
  Offset Function(NodeId nodeId) previewResolver,
  NodeId nodeId,
) {
  return sanitizeFiniteOffset(previewResolver(nodeId));
}

Rect _snapshotPaintBoundsWorld({
  required NodeSnapshot node,
  required Offset Function(NodeId nodeId) previewResolver,
}) {
  requireNodeSnapshotGeometrySupport(node);
  return nodeSnapshotPaintBoundsWorld(
    node,
  ).shift(_previewDeltaForNode(previewResolver, node.id));
}
