import '../core/id_generator.dart';
import '../core/nodes.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart';
import '../model/document.dart';
import '../model/document_clone.dart';
import '../model/scene_value_validation.dart' as scene_value_validation;
import 'change_set.dart';
import 'committed_store_state.dart';

List<String> txnCollectStoreInvariantViolations(CommittedStoreState state) {
  final violations = <String>[];
  violations.addAll(
    _txnCollectSceneIndexInvariantViolations(
      scene: state.scene,
      allNodeIds: state.allNodeIds,
      nodeLocator: state.nodeLocator,
    ),
  );
  violations.addAll(
    _txnCollectSelectionInvariantViolations(
      scene: state.scene,
      selectedNodeIds: state.selectedNodeIds,
    ),
  );
  violations.addAll(
    _txnCollectIdGeneratorInvariantViolations(
      idGeneratorState: state.idGeneratorState,
    ),
  );
  violations.addAll(
    _txnCollectControllerEpochInvariantViolations(state.controllerEpoch),
  );
  violations.addAll(
    _txnCollectRevisionStateInvariantViolations(
      scene: state.scene,
      revisionState: state.revisionState,
    ),
  );
  violations.addAll(
    _txnCollectCommitRevisionInvariantViolations(state.commitRevision),
  );
  violations.addAll(
    _txnCollectRuntimeSceneValidityInvariantViolations(state.scene),
  );
  return violations;
}

List<String> txnCollectCriticalStoreInvariantViolations({
  required CommittedStoreState state,
  required int commitRevision,
  required int previousCommitRevision,
  ChangeSet? changeSet,
  Scene? previousScene,
}) {
  final violations = <String>[];
  if (commitRevision <= previousCommitRevision) {
    violations.add(
      'commitRevision must be strictly monotonic. '
      'actual=$commitRevision previous=$previousCommitRevision',
    );
  }
  violations.addAll(
    _txnCollectCommitRevisionInvariantViolations(commitRevision),
  );
  violations.addAll(
    _txnCollectCriticalRuntimeSceneValidityInvariantViolations(
      state: state,
      changeSet: changeSet,
      previousScene: previousScene,
    ),
  );
  return violations;
}

void debugAssertTxnStoreInvariants(CommittedStoreState state) {
  final violations = txnCollectStoreInvariantViolations(state);
  if (violations.isNotEmpty) {
    throw StateError(
      'Committed store invariants violated:\n- ${violations.join('\n- ')}',
    );
  }
}

void assertCriticalTxnStoreInvariants({
  required CommittedStoreState state,
  required int commitRevision,
  required int previousCommitRevision,
  ChangeSet? changeSet,
  Scene? previousScene,
}) {
  final violations = txnCollectCriticalStoreInvariantViolations(
    state: state,
    commitRevision: commitRevision,
    previousCommitRevision: previousCommitRevision,
    changeSet: changeSet,
    previousScene: previousScene,
  );
  if (violations.isNotEmpty) {
    throw StateError(
      'Critical committed store invariants violated:\n- '
      '${violations.join('\n- ')}',
    );
  }
}

Iterable<SceneNode> _txnAllNodes(Scene scene) sync* {
  final backgroundLayer = scene.backgroundLayer;
  if (backgroundLayer != null) {
    yield* backgroundLayer.nodes;
  }
  for (final layer in scene.layers) {
    yield* layer.nodes;
  }
}

bool _txnSetsEqual(Set<NodeId> left, Set<NodeId> right) {
  return left.length == right.length && left.containsAll(right);
}

bool _txnNodeLocatorEquals(
  Map<NodeId, NodeLocatorEntry> left,
  Map<NodeId, NodeLocatorEntry> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    final rightValue = right[entry.key];
    if (rightValue == null || rightValue != entry.value) {
      return false;
    }
  }
  return true;
}

List<String> _txnCollectSceneIndexInvariantViolations({
  required Scene scene,
  required Set<NodeId> allNodeIds,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
}) {
  final violations = <String>[];

  final expectedAllNodeIds = txnCollectNodeIds(scene);
  if (!_txnSetsEqual(allNodeIds, expectedAllNodeIds)) {
    violations.add(
      'allNodeIds must equal collectNodeIds(scene). '
      'actual=$allNodeIds expected=$expectedAllNodeIds',
    );
  }

  if (!_txnSetsEqual(allNodeIds, nodeLocator.keys.toSet())) {
    violations.add(
      'allNodeIds must equal nodeLocator keys. '
      'allNodeIds=$allNodeIds locatorKeys=${nodeLocator.keys.toSet()}',
    );
  }

  final expectedNodeLocator = txnBuildNodeLocator(scene);
  if (!_txnNodeLocatorEquals(nodeLocator, expectedNodeLocator)) {
    violations.add(
      'nodeLocator must match buildNodeLocator(scene). '
      'actual=$nodeLocator expected=$expectedNodeLocator',
    );
  }

  return violations;
}

List<String> _txnCollectRuntimeSceneValidityInvariantViolations(Scene scene) {
  return scene_value_validation.sceneCollectRuntimeSceneValidityViolations(
    scene,
  );
}

List<String> _txnCollectCriticalRuntimeSceneValidityInvariantViolations({
  required CommittedStoreState state,
  required ChangeSet? changeSet,
  required Scene? previousScene,
}) {
  if (changeSet == null) {
    return _txnCollectRuntimeSceneValidityInvariantViolations(state.scene);
  }
  if (changeSet.documentReplaced) {
    return _txnCollectRuntimeSceneValidityInvariantViolations(state.scene);
  }

  final violations = <String>[];

  if (changeSet.structuralChanged) {
    violations.addAll(
      scene_value_validation.sceneCollectRuntimeStructuralSurfaceViolations(
        state.scene,
      ),
    );
  }

  if (_txnDidCriticalCameraChange(previousScene, state.scene)) {
    violations.addAll(
      scene_value_validation.sceneCollectRuntimeCameraOffsetViolations(
        value: state.scene.camera.offset,
      ),
    );
  }

  if (_txnDidCriticalGridChange(previousScene, state.scene)) {
    violations.addAll(
      scene_value_validation.sceneCollectRuntimeGridViolations(
        state.scene.background.grid,
        requirePositiveCellSize: true,
        requireEnabledMinCellSize: true,
      ),
    );
  }

  if (_txnDidCriticalPaletteChange(previousScene, state.scene)) {
    violations.addAll(
      scene_value_validation.sceneCollectRuntimePaletteViolations(
        state.scene.palette,
      ),
    );
  }

  violations.addAll(
    _txnCollectCriticalTrackedNodeViolations(
      scene: state.scene,
      nodeLocator: state.nodeLocator,
      nodeIds: <NodeId>{...changeSet.addedNodeIds, ...changeSet.updatedNodeIds},
    ),
  );

  return violations;
}

List<String> _txnCollectCriticalTrackedNodeViolations({
  required Scene scene,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required Set<NodeId> nodeIds,
}) {
  if (nodeIds.isEmpty) {
    return const <String>[];
  }

  final orderedNodeIds = nodeIds.toList(growable: false)..sort();
  final violations = <String>[];
  for (final nodeId in orderedNodeIds) {
    final found = txnFindNodeByLocator(
      scene: scene,
      nodeLocator: nodeLocator,
      nodeId: nodeId,
    );
    if (found == null) {
      continue;
    }
    final fieldPrefix = found.layerIndex == -1
        ? 'backgroundLayer.nodes[${found.nodeIndex}]'
        : 'layers[${found.layerIndex}].nodes[${found.nodeIndex}]';
    violations.addAll(
      scene_value_validation.sceneCollectRuntimeNodeViolations(
        found.node,
        field: fieldPrefix,
      ),
    );
  }
  return violations;
}

bool _txnDidCriticalCameraChange(Scene? previousScene, Scene scene) {
  if (previousScene == null) {
    return true;
  }
  return previousScene.camera.offset != scene.camera.offset;
}

bool _txnDidCriticalGridChange(Scene? previousScene, Scene scene) {
  if (previousScene == null) {
    return true;
  }
  final previousGrid = previousScene.background.grid;
  final nextGrid = scene.background.grid;
  return previousGrid.isEnabled != nextGrid.isEnabled ||
      previousGrid.cellSize != nextGrid.cellSize;
}

bool _txnDidCriticalPaletteChange(Scene? previousScene, Scene scene) {
  if (previousScene == null) {
    return true;
  }
  final previousPalette = previousScene.palette;
  final nextPalette = scene.palette;
  return !_txnListEquals(previousPalette.penColors, nextPalette.penColors) ||
      !_txnListEquals(
        previousPalette.backgroundColors,
        nextPalette.backgroundColors,
      ) ||
      !_txnListEquals(previousPalette.gridSizes, nextPalette.gridSizes);
}

bool _txnListEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

List<String> _txnCollectSelectionInvariantViolations({
  required Scene scene,
  required Set<NodeId> selectedNodeIds,
}) {
  final normalizedSelection = txnNormalizeSelection(
    rawSelection: selectedNodeIds,
    scene: scene,
  );
  if (_txnSetsEqual(selectedNodeIds, normalizedSelection)) {
    return const <String>[];
  }
  return <String>[
    'selectedNodeIds must be normalized against scene interaction policy. '
        'actual=$selectedNodeIds normalized=$normalizedSelection',
  ];
}

List<String> _txnCollectIdGeneratorInvariantViolations({
  required IdGeneratorState idGeneratorState,
}) {
  final violations = <String>[];

  if (idGeneratorState.sessionToken.isEmpty) {
    violations.add('idGeneratorState.sessionToken must not be empty.');
  }

  if (idGeneratorState.nextNodeCounter < 1) {
    violations.add(
      'idGeneratorState.nextNodeCounter must be >= 1. '
      'actual=${idGeneratorState.nextNodeCounter}',
    );
  }

  if (idGeneratorState.nextLayerCounter < 1) {
    violations.add(
      'idGeneratorState.nextLayerCounter must be >= 1. '
      'actual=${idGeneratorState.nextLayerCounter}',
    );
  }

  return violations;
}

List<String> _txnCollectControllerEpochInvariantViolations(
  int controllerEpoch,
) {
  if (controllerEpoch < 0 || controllerEpoch > kMaxControllerEpoch) {
    return <String>[
      'controllerEpoch must stay within [0, $kMaxControllerEpoch]. '
          'actual=$controllerEpoch',
    ];
  }
  return const <String>[];
}

List<String> _txnCollectRevisionStateInvariantViolations({
  required Scene scene,
  required RevisionAllocatorState revisionState,
}) {
  final violations = <String>[];

  final nextRevision = revisionState.nextInstanceRevision;
  if (nextRevision < 1 || nextRevision > kMaxInstanceRevision) {
    violations.add(
      'revisionState.nextInstanceRevision must stay within '
      '[1, $kMaxInstanceRevision]. actual=$nextRevision',
    );
  }

  if (revisionState.epochBumpRequested) {
    violations.add('committed revisionState.epochBumpRequested must be false.');
  }

  final invalidInstanceRevisionIds = <NodeId>[];
  for (final node in _txnAllNodes(scene)) {
    if (node.instanceRevision >= 1) continue;
    invalidInstanceRevisionIds.add(node.id);
  }
  if (invalidInstanceRevisionIds.isNotEmpty) {
    violations.add(
      'scene nodes must have instanceRevision >= 1. '
      'nodeIds=$invalidInstanceRevisionIds',
    );
  }

  return violations;
}

List<String> _txnCollectCommitRevisionInvariantViolations(int commitRevision) {
  if (commitRevision < 0) {
    return const <String>['commitRevision must be non-negative.'];
  }
  return const <String>[];
}
