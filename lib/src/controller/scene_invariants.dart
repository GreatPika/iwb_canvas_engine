import 'dart:ui';

import '../core/grid_safety_limits.dart';
import '../core/nodes.dart';
import '../core/scene.dart';
import '../model/document_clone.dart';
import '../model/document.dart';

List<String> txnCollectStoreInvariantViolations({
  required Scene scene,
  required Set<NodeId> selectedNodeIds,
  required Set<NodeId> allNodeIds,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required int nodeIdSeed,
  required int commitRevision,
}) {
  var violations = const <String>[];

  final expectedAllNodeIds = txnCollectNodeIds(scene);
  if (!_txnSetsEqual(allNodeIds, expectedAllNodeIds)) {
    violations = <String>[
      ...violations,
      'allNodeIds must equal collectNodeIds(scene). '
          'actual=$allNodeIds expected=$expectedAllNodeIds',
    ];
  }
  if (!_txnSetsEqual(allNodeIds, nodeLocator.keys.toSet())) {
    violations = <String>[
      ...violations,
      'allNodeIds must equal nodeLocator keys. '
          'allNodeIds=$allNodeIds locatorKeys=${nodeLocator.keys.toSet()}',
    ];
  }
  final expectedNodeLocator = txnBuildNodeLocator(scene);
  if (!_txnNodeLocatorEquals(nodeLocator, expectedNodeLocator)) {
    violations = <String>[
      ...violations,
      'nodeLocator must match buildNodeLocator(scene). '
          'actual=$nodeLocator expected=$expectedNodeLocator',
    ];
  }

  final duplicateNodeIds = _txnCollectDuplicateNodeIds(scene);
  if (duplicateNodeIds.isNotEmpty) {
    violations = <String>[
      ...violations,
      'scene must not contain duplicate node ids. '
          'duplicates=$duplicateNodeIds',
    ];
  }

  final normalizedSelection = txnNormalizeSelection(
    rawSelection: selectedNodeIds,
    scene: scene,
  );
  if (!_txnSetsEqual(selectedNodeIds, normalizedSelection)) {
    violations = <String>[
      ...violations,
      'selectedNodeIds must be normalized against scene interaction policy. '
          'actual=$selectedNodeIds normalized=$normalizedSelection',
    ];
  }

  final expectedSeed = txnInitialNodeIdSeed(scene);
  if (nodeIdSeed < expectedSeed) {
    violations = <String>[
      ...violations,
      'nodeIdSeed must be >= initialNodeIdSeed(scene). '
          'actual=$nodeIdSeed min=$expectedSeed',
    ];
  }

  if (commitRevision < 0) {
    violations = <String>[
      ...violations,
      'commitRevision must be non-negative.',
    ];
  }

  final cameraOffset = scene.camera.offset;
  if (!_txnIsFiniteOffset(cameraOffset)) {
    violations = <String>[...violations, 'camera.offset must be finite.'];
  }

  final grid = scene.background.grid;
  if (!grid.cellSize.isFinite || grid.cellSize <= 0) {
    violations = <String>[
      ...violations,
      'grid.cellSize must be finite and > 0.',
    ];
  } else if (grid.isEnabled && grid.cellSize < kMinGridCellSize) {
    violations = <String>[
      ...violations,
      'enabled grid.cellSize must be >= $kMinGridCellSize.',
    ];
  }

  return violations;
}

void debugAssertTxnStoreInvariants({
  required Scene scene,
  required Set<NodeId> selectedNodeIds,
  required Set<NodeId> allNodeIds,
  required Map<NodeId, NodeLocatorEntry> nodeLocator,
  required int nodeIdSeed,
  required int commitRevision,
}) {
  assert(() {
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: selectedNodeIds,
      allNodeIds: allNodeIds,
      nodeLocator: nodeLocator,
      nodeIdSeed: nodeIdSeed,
      commitRevision: commitRevision,
    );
    if (violations.isNotEmpty) {
      throw StateError(
        'Committed store invariants violated:\n- ${violations.join('\n- ')}',
      );
    }
    return true;
  }());
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
