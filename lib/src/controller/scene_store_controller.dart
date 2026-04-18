import 'dart:ui' hide Scene;

import 'package:flutter/foundation.dart';

import '../contract/scene_render_state.dart';
import '../core/scene.dart' show Scene;
import '../core/scene_spatial_index.dart';
import '../model/document.dart';
import '../contract/scene_write_txn.dart';
import '../contract/snapshot.dart';
import 'commands/draw_commands.dart';
import 'commands/move_commands.dart';
import 'commands/scene_commands.dart';
import 'internal/signal_event.dart';
import 'scene_controller_commit_debug.dart';
import 'scene_controller_commit_runtime.dart';
import 'scene_snapshot_materializer.dart';
import 'scene_writer.dart';
import 'store.dart';

class SceneStoreController extends ChangeNotifier implements SceneRenderState {
  SceneStoreController({
    SceneSnapshot? initialSnapshot,
    this.textFontFamilyByDefault,
  }) : _store = SceneStore(
         sceneDoc: txnSceneFromSnapshot(initialSnapshot ?? SceneSnapshot()),
       ) {
    _commitRuntime = SceneControllerCommitRuntime(
      store: _store,
      textFontFamilyByDefault: textFontFamilyByDefault,
      notifyListeners: notifyListeners,
    );
  }

  final SceneStore _store;
  final String? textFontFamilyByDefault;
  late final SceneControllerCommitRuntime _commitRuntime;
  bool _isDisposed = false;

  Scene? _cachedSnapshotScene;
  SceneSnapshot? _cachedSnapshot;
  late final SceneCommands commands = SceneCommands(writeWithSceneWriter);
  late final MoveCommands move = MoveCommands(writeWithSceneWriter);
  late final DrawCommands draw = DrawCommands(writeWithSceneWriter);

  @override
  SceneSnapshot get snapshot {
    final sceneDoc = _store.sceneDoc;
    final cachedSnapshot = _cachedSnapshot;
    if (cachedSnapshot != null && identical(sceneDoc, _cachedSnapshotScene)) {
      return cachedSnapshot;
    }

    // Safe because committed scene identity changes on first mutating write.
    // Non-mutating commits keep identity and can reuse immutable snapshot.
    final rebuiltSnapshot = txnSceneToSnapshot(sceneDoc);
    _cachedSnapshotScene = sceneDoc;
    _cachedSnapshot = rebuiltSnapshot;
    return rebuiltSnapshot;
  }

  @override
  Set<NodeId> get selectedNodeIds => _commitRuntime.selectedNodeIdsView;

  int get controllerEpoch => _store.controllerEpoch;
  int get structuralRevision => _store.structuralRevision;
  int get selectionRevision => _store.selectionRevision;
  int get boundsRevision => _store.boundsRevision;
  int get visualRevision => _store.visualRevision;

  Stream<CommittedSignal> get signals => _commitRuntime.signals;

  @visibleForTesting
  SceneStoreControllerDebugAccess get debug =>
      SceneStoreControllerDebugAccess(store: _store, runtime: _commitRuntime);

  T write<T>(T Function(SceneWriteTxn txn) fn) {
    return _commitRuntime.write(fn);
  }

  SceneControllerCommittedWrite<T> writeCommitted<T>(
    T Function(SceneWriteTxn txn) fn,
  ) {
    return _commitRuntime.writeCommitted(fn);
  }

  T writeWithSceneWriter<T>(T Function(SceneWriter writer) fn) {
    return _commitRuntime.writeWithSceneWriter(fn);
  }

  SceneControllerCommittedWrite<T> writeWithSceneWriterCommitted<T>(
    T Function(SceneWriter writer) fn,
  ) {
    return _commitRuntime.writeWithSceneWriterCommitted(fn);
  }

  void requestRepaint() {
    _commitRuntime.requestRepaint();
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _commitRuntime.dispose();
    _isDisposed = true;
    super.dispose();
  }
}

extension SceneStoreControllerSpatialAccess on SceneStoreController {
  List<SceneHitTestSpatialCandidate> queryHitTestCandidates(Rect worldBounds) {
    return _commitRuntime.spatialIndexCache.writeQueryHitTestCandidates(
      scene: _store.sceneDoc,
      nodeLocator: _store.nodeLocator,
      worldBounds: worldBounds,
      controllerEpoch: _store.controllerEpoch,
    );
  }

  List<ScenePaintSpatialCandidate> queryPaintCandidates(
    Rect worldBounds, {
    ScenePaintSpatialQueryScope scope =
        ScenePaintSpatialQueryScope.contentLayersOnly,
  }) {
    return _commitRuntime.spatialIndexCache.writeQueryPaintCandidates(
      scene: _store.sceneDoc,
      nodeLocator: _store.nodeLocator,
      worldBounds: worldBounds,
      controllerEpoch: _store.controllerEpoch,
      scope: scope,
    );
  }

  NodeSnapshot? resolveSpatialCandidateSnapshot(
    SceneSpatialCandidateReference candidate,
  ) {
    return _resolveSnapshotAtLocationInSnapshot(
      snapshot: snapshot,
      nodeId: candidate.nodeId,
      layerIndex: candidate.layerIndex,
      nodeIndex: candidate.nodeIndex,
    )?.node;
  }

  ({NodeSnapshot node, int layerIndex, int nodeIndex})? resolveSnapshotNodeById(
    NodeId nodeId,
  ) {
    final location = _store.nodeLocator[nodeId];
    if (location == null) {
      return null;
    }
    return _resolveSnapshotAtLocationInSnapshot(
      snapshot: snapshot,
      nodeId: nodeId,
      layerIndex: location.layerIndex,
      nodeIndex: location.nodeIndex,
    );
  }

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) {
    return centerWorldForNodeSnapshotsMaterialized(snapshots);
  }
}

extension SceneStoreControllerCommittedSceneReplacementAccess
    on SceneStoreController {
  void writeReplaceScene(SceneSnapshot snapshot) {
    writeWithSceneWriter<void>((writer) {
      writer.writeDocumentReplace(snapshot);
    });
  }
}

({NodeSnapshot node, int layerIndex, int nodeIndex})?
_resolveSnapshotAtLocationInSnapshot({
  required SceneSnapshot snapshot,
  required NodeId nodeId,
  required int layerIndex,
  required int nodeIndex,
}) {
  if (layerIndex == -1) {
    final backgroundNodes = snapshot.backgroundLayer.nodes;
    if (nodeIndex < 0 || nodeIndex >= backgroundNodes.length) {
      return null;
    }
    final node = backgroundNodes[nodeIndex];
    if (node.id != nodeId) {
      return null;
    }
    return (node: node, layerIndex: -1, nodeIndex: nodeIndex);
  }
  if (layerIndex < 0 || layerIndex >= snapshot.layers.length) {
    return null;
  }
  final layer = snapshot.layers[layerIndex];
  if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) {
    return null;
  }
  final node = layer.nodes[nodeIndex];
  if (node.id != nodeId) {
    return null;
  }
  return (node: node, layerIndex: layerIndex, nodeIndex: nodeIndex);
}
