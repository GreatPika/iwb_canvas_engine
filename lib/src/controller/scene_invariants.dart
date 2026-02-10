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
  if (nodeIdSeed != expectedSeed) {
    violations = <String>[
      ...violations,
      'nodeIdSeed must be derived from scene. '
          'actual=$nodeIdSeed expected=$expectedSeed',
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
  required int nodeIdSeed,
  required int commitRevision,
}) {
  assert(() {
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: selectedNodeIds,
      allNodeIds: allNodeIds,
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

bool _txnIsFiniteOffset(Offset value) {
  return value.dx.isFinite && value.dy.isFinite;
}
