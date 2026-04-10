import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../contract/scene_view_render_state.dart';
import '../../contract/scene_view_runtime.dart';
import '../../contract/snapshot.dart';
import '../../controller/scene_store_controller.dart';
import '../../core/geometry.dart';
import '../../core/node_geometry.dart';
import '../../core/numeric_clamp.dart';
import '../../core/scene_node.dart';
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
  Iterable<NodeSnapshot> enumeratePaintCandidates(Rect worldRect) sync* {
    final snapshot = _readSnapshot();
    final selectedNodeIds = _readSelectedNodeIds();
    final previewResolver = _readPreviewDeltaResolver();
    final acceptedNodeIds = <NodeId>{};
    final contentCandidates =
        <({NodeSnapshot node, int layerIndex, int nodeIndex})>[];

    final runtimeBackgroundNodes = _storeController.backgroundLayerNodes();
    final snapshotBackgroundNodes = snapshot.backgroundLayer.nodes;
    final backgroundCount =
        runtimeBackgroundNodes.length < snapshotBackgroundNodes.length
        ? runtimeBackgroundNodes.length
        : snapshotBackgroundNodes.length;
    for (var nodeIndex = 0; nodeIndex < backgroundCount; nodeIndex++) {
      final runtimeNode = runtimeBackgroundNodes[nodeIndex];
      final snapshotNode = snapshotBackgroundNodes[nodeIndex];
      if (!_matchesSnapshotNode(
        runtimeNode: runtimeNode,
        snapshot: snapshotNode,
      )) {
        continue;
      }
      final previewDelta = _previewDeltaForNode(
        previewResolver,
        runtimeNode.id,
      );
      final candidateBounds = nodeGeometryCandidateBoundsWorld(
        runtimeNode,
      ).shift(previewDelta);
      if (!isFiniteRect(candidateBounds) ||
          !worldRect.overlaps(candidateBounds)) {
        continue;
      }
      acceptedNodeIds.add(snapshotNode.id);
      yield snapshotNode;
    }

    for (final candidate in _storeController.querySpatialCandidates(
      worldRect,
    )) {
      final snapshotNode = _resolveSnapshotContentNode(
        snapshot: snapshot,
        layerIndex: candidate.layerIndex,
        nodeIndex: candidate.nodeIndex,
      );
      if (snapshotNode == null ||
          !_matchesSnapshotNode(
            runtimeNode: candidate.node,
            snapshot: snapshotNode,
          ) ||
          !acceptedNodeIds.add(snapshotNode.id)) {
        continue;
      }
      contentCandidates.add((
        node: snapshotNode,
        layerIndex: candidate.layerIndex,
        nodeIndex: candidate.nodeIndex,
      ));
    }

    for (final nodeId in selectedNodeIds) {
      final previewDelta = _previewDeltaForNode(previewResolver, nodeId);
      if (previewDelta == Offset.zero) {
        continue;
      }
      final resolvedNode = _storeController.resolveNodeById(nodeId);
      if (resolvedNode == null ||
          resolvedNode.layerIndex < 0 ||
          acceptedNodeIds.contains(nodeId)) {
        continue;
      }
      final candidateBounds = nodeGeometryCandidateBoundsWorld(
        resolvedNode.node,
      ).shift(previewDelta);
      if (!isFiniteRect(candidateBounds) ||
          !worldRect.overlaps(candidateBounds)) {
        continue;
      }
      final snapshotNode = _resolveSnapshotContentNode(
        snapshot: snapshot,
        layerIndex: resolvedNode.layerIndex,
        nodeIndex: resolvedNode.nodeIndex,
      );
      if (snapshotNode == null ||
          !_matchesSnapshotNode(
            runtimeNode: resolvedNode.node,
            snapshot: snapshotNode,
          ) ||
          !acceptedNodeIds.add(nodeId)) {
        continue;
      }
      contentCandidates.add((
        node: snapshotNode,
        layerIndex: resolvedNode.layerIndex,
        nodeIndex: resolvedNode.nodeIndex,
      ));
    }

    contentCandidates.sort((a, b) {
      final layerOrder = a.layerIndex.compareTo(b.layerIndex);
      if (layerOrder != 0) {
        return layerOrder;
      }
      return a.nodeIndex.compareTo(b.nodeIndex);
    });

    for (final candidate in contentCandidates) {
      yield candidate.node;
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

NodeSnapshot? _resolveSnapshotContentNode({
  required SceneSnapshot snapshot,
  required int layerIndex,
  required int nodeIndex,
}) {
  if (layerIndex < 0 || layerIndex >= snapshot.layers.length) {
    return null;
  }
  final layer = snapshot.layers[layerIndex];
  if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) {
    return null;
  }
  return layer.nodes[nodeIndex];
}

Offset _previewDeltaForNode(
  Offset Function(NodeId nodeId) previewResolver,
  NodeId nodeId,
) {
  return sanitizeFiniteOffset(previewResolver(nodeId));
}

bool _matchesSnapshotNode({
  required SceneNode runtimeNode,
  required NodeSnapshot snapshot,
}) {
  return runtimeNode.id == snapshot.id &&
      runtimeNode.type == _snapshotNodeType(snapshot);
}

NodeType _snapshotNodeType(NodeSnapshot snapshot) {
  return switch (snapshot) {
    ImageNodeSnapshot() => NodeType.image,
    TextNodeSnapshot() => NodeType.text,
    StrokeNodeSnapshot() => NodeType.stroke,
    LineNodeSnapshot() => NodeType.line,
    RectNodeSnapshot() => NodeType.rect,
    PathNodeSnapshot() => NodeType.path,
    _ => throw StateError(
      'Unsupported snapshot node type: ${snapshot.runtimeType}',
    ),
  };
}
