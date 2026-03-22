import 'dart:ui';

import '../core/grid_safety_limits.dart';
import '../core/id_generator.dart';
import '../core/nodes.dart';
import '../core/revision_policy.dart';
import '../core/scene.dart';
import '../contract/ids.dart' show LayerId;
import '../model/document.dart';
import '../model/document_clone.dart';

List<String> txnCollectStoreInvariantViolations({
  required Scene scene,
  required Set<NodeId> selectedNodeIds,
  required Set<NodeId> allNodeIds,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required IdGeneratorState idGeneratorState,
  int controllerEpoch = 0,
  RevisionAllocatorState? revisionState,
  int nextInstanceRevision = 1,
  required int commitRevision,
}) {
  final violations = <String>[];
  violations.addAll(
    _txnCollectSceneIndexInvariantViolations(
      scene: scene,
      allNodeIds: allNodeIds,
      nodeLocator: nodeLocator,
    ),
  );
  violations.addAll(_txnCollectSceneIdentityInvariantViolations(scene));
  violations.addAll(
    _txnCollectSelectionInvariantViolations(
      scene: scene,
      selectedNodeIds: selectedNodeIds,
    ),
  );
  violations.addAll(
    _txnCollectIdGeneratorInvariantViolations(
      idGeneratorState: idGeneratorState,
    ),
  );
  violations.addAll(
    _txnCollectControllerEpochInvariantViolations(controllerEpoch),
  );
  violations.addAll(
    _txnCollectRevisionStateInvariantViolations(
      scene: scene,
      revisionState: revisionState,
      nextInstanceRevision: nextInstanceRevision,
    ),
  );
  violations.addAll(
    _txnCollectCommitRevisionInvariantViolations(commitRevision),
  );
  violations.addAll(_txnCollectSceneNumericInvariantViolations(scene));
  return violations;
}

List<String> txnCollectCriticalStoreInvariantViolations({
  required Scene scene,
  required int commitRevision,
  required int previousCommitRevision,
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
  violations.addAll(_txnCollectSceneNumericInvariantViolations(scene));
  return violations;
}

void debugAssertTxnStoreInvariants({
  required Scene scene,
  required Set<NodeId> selectedNodeIds,
  required Set<NodeId> allNodeIds,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required IdGeneratorState idGeneratorState,
  int controllerEpoch = 0,
  RevisionAllocatorState? revisionState,
  int nextInstanceRevision = 1,
  required int commitRevision,
}) {
  final violations = txnCollectStoreInvariantViolations(
    scene: scene,
    selectedNodeIds: selectedNodeIds,
    allNodeIds: allNodeIds,
    nodeLocator: nodeLocator,
    idGeneratorState: idGeneratorState,
    controllerEpoch: controllerEpoch,
    revisionState: revisionState,
    nextInstanceRevision: nextInstanceRevision,
    commitRevision: commitRevision,
  );
  if (violations.isNotEmpty) {
    throw StateError(
      'Committed store invariants violated:\n- ${violations.join('\n- ')}',
    );
  }
}

void assertCriticalTxnStoreInvariants({
  required Scene scene,
  required int commitRevision,
  required int previousCommitRevision,
}) {
  final violations = txnCollectCriticalStoreInvariantViolations(
    scene: scene,
    commitRevision: commitRevision,
    previousCommitRevision: previousCommitRevision,
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

bool _txnIsFiniteOffset(Offset value) {
  return value.dx.isFinite && value.dy.isFinite;
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

List<String> _txnCollectSceneIdentityInvariantViolations(Scene scene) {
  final violations = <String>[];

  final duplicateNodeIds = _txnCollectDuplicateNodeIds(scene);
  if (duplicateNodeIds.isNotEmpty) {
    violations.add(
      'scene must not contain duplicate node ids. duplicates=$duplicateNodeIds',
    );
  }

  final duplicateLayerIds = _txnCollectDuplicateLayerIds(scene);
  if (duplicateLayerIds.isNotEmpty) {
    violations.add(
      'scene must not contain duplicate content layer ids. '
      'duplicates=$duplicateLayerIds',
    );
  }

  return violations;
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
  required RevisionAllocatorState? revisionState,
  required int nextInstanceRevision,
}) {
  final violations = <String>[];

  final effectiveRevisionState =
      revisionState ??
      createInitialRevisionAllocatorState(
        nextInstanceRevision: nextInstanceRevision,
      );
  final nextRevision = effectiveRevisionState.nextInstanceRevision;
  if (nextRevision < 1 || nextRevision > kMaxInstanceRevision) {
    violations.add(
      'revisionState.nextInstanceRevision must stay within '
      '[1, $kMaxInstanceRevision]. actual=$nextRevision',
    );
  }

  if (effectiveRevisionState.epochBumpRequested) {
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

List<String> _txnCollectSceneNumericInvariantViolations(Scene scene) {
  final violations = <String>[];

  final cameraOffset = scene.camera.offset;
  if (!_txnIsFiniteOffset(cameraOffset)) {
    violations.add('camera.offset must be finite.');
  }

  final grid = scene.background.grid;
  if (!grid.cellSize.isFinite || grid.cellSize <= 0) {
    violations.add('grid.cellSize must be finite and > 0.');
  } else if (grid.isEnabled && grid.cellSize < kMinGridCellSize) {
    violations.add('enabled grid.cellSize must be >= $kMinGridCellSize.');
  }

  return violations;
}

Set<NodeId> _txnCollectDuplicateNodeIds(Scene scene) {
  final seen = <NodeId>{};
  final duplicates = <NodeId>{};
  final backgroundLayer = scene.backgroundLayer;
  if (backgroundLayer != null) {
    for (final node in backgroundLayer.nodes) {
      if (!seen.add(node.id)) {
        duplicates.add(node.id);
      }
    }
  }
  for (final layer in scene.layers) {
    for (final node in layer.nodes) {
      if (!seen.add(node.id)) {
        duplicates.add(node.id);
      }
    }
  }
  return duplicates;
}

Set<LayerId> _txnCollectDuplicateLayerIds(Scene scene) {
  final seen = <LayerId>{};
  final duplicates = <LayerId>{};
  for (final layer in scene.layers) {
    if (!seen.add(layer.id)) {
      duplicates.add(layer.id);
    }
  }
  return duplicates;
}
