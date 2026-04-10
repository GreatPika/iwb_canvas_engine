import 'dart:ui' hide Scene;

import 'package:flutter/foundation.dart';

import '../contract/scene_render_state.dart';
import '../core/nodes.dart' show SceneNode;
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
  List<SceneNode> backgroundLayerNodes() {
    return _store.sceneDoc.backgroundLayer?.nodes ?? const <SceneNode>[];
  }

  List<SceneSpatialCandidate> querySpatialCandidates(Rect worldBounds) {
    return _commitRuntime.spatialIndexCache.writeQueryCandidates(
      scene: _store.sceneDoc,
      nodeLocator: _store.nodeLocator,
      worldBounds: worldBounds,
      controllerEpoch: _store.controllerEpoch,
    );
  }

  SceneNode? resolveSpatialCandidateNode(SceneSpatialCandidate candidate) {
    final layerIndex = candidate.layerIndex;
    if (layerIndex < 0 || layerIndex >= _store.sceneDoc.layers.length) {
      return null;
    }

    final layer = _store.sceneDoc.layers[layerIndex];
    final nodeIndex = candidate.nodeIndex;
    if (nodeIndex < 0 || nodeIndex >= layer.nodes.length) {
      return null;
    }

    final node = layer.nodes[nodeIndex];
    if (identical(node, candidate.node)) {
      return node;
    }

    if (node.id != candidate.node.id || node.type != candidate.node.type) {
      return null;
    }
    return node;
  }

  ({SceneNode node, int layerIndex, int nodeIndex})? resolveNodeById(
    NodeId nodeId,
  ) {
    return txnFindNodeByLocator(
      scene: _store.sceneDoc,
      nodeLocator: _store.nodeLocator,
      nodeId: nodeId,
    );
  }

  void writeReplaceScene(SceneSnapshot snapshot) {
    write<void>((writer) {
      writer.writeDocumentReplace(snapshot);
    });
  }

  PreparedSceneReplacement prepareSceneReplacement(SceneSnapshot snapshot) {
    return materializeSceneReplacement(
      snapshot: snapshot,
      nextInstanceRevisionSeed: _store.nextInstanceRevision,
    );
  }

  void writePreparedSceneReplacement(PreparedSceneReplacement replacement) {
    writeWithSceneWriter<void>((writer) {
      writer.writePreparedDocumentReplace(replacement);
    });
  }

  Offset centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) {
    return centerWorldForNodeSnapshotsMaterialized(snapshots);
  }
}
