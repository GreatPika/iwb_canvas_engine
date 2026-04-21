import 'dart:ui';

import '../../core/action_events.dart';
import '../../contract/ids.dart';
import '../interaction_eligibility_policy.dart'
    as interaction_eligibility_policy;
import 'interactive_move_callbacks.dart';
import 'interactive_move_hit_test_engine.dart';

final class InteractiveMoveSelectionCoordinator {
  InteractiveMoveSelectionCoordinator({
    required this.callbacks,
    required this.hitTestEngine,
  });

  final InteractiveMoveSessionCallbacks callbacks;
  final InteractiveMoveHitTestEngine hitTestEngine;

  Set<NodeId> _marqueeBaseline = <NodeId>{};
  bool _selectionChangedLocally = false;

  void beginGesture() {
    _marqueeBaseline = Set<NodeId>.from(callbacks.readSelectedNodeIds());
    _selectionChangedLocally = false;
  }

  void reset() {
    _marqueeBaseline = <NodeId>{};
    _selectionChangedLocally = false;
  }

  void selectHitNodeIfNeeded(NodeId nodeId) {
    final selection = callbacks.readSelectedNodeIds();
    if (selection.contains(nodeId)) {
      return;
    }
    _writeSelectionReplaceIfChanged(<NodeId>{nodeId});
  }

  Set<NodeId> resolvePreviewNodeIds() {
    final previewableNodes = interaction_eligibility_policy
        .selectedPreviewMovableNodesInSnapshotOrder(
          snapshot: callbacks.readSnapshot(),
          selected: callbacks.readSelectedNodeIds(),
        );
    return previewableNodes.map((node) => node.id).toSet();
  }

  void writeSelectionClearIfChanged() {
    if (callbacks.readSelectedNodeIds().isEmpty) {
      return;
    }
    callbacks.writeSelectionClear();
    _selectionChangedLocally = true;
  }

  void commitMarquee({required Rect rect, required int timestampMs}) {
    final selected = hitTestEngine.nodesIntersecting(rect);
    callbacks.writeSelectionReplace(selected);

    final currentSelection = callbacks.readSelectedNodeIds();
    final didChange =
        _marqueeBaseline.length != currentSelection.length ||
        !_marqueeBaseline.containsAll(currentSelection);
    if (didChange) {
      callbacks.emitAction(
        ActionType.selectMarquee,
        currentSelection.toList(growable: false),
        timestampMs,
      );
    }
  }

  void restoreBaselineSelectionIfNeeded() {
    if (!_selectionChangedLocally) {
      return;
    }
    final baseline = _marqueeBaseline;
    final current = callbacks.readSelectedNodeIds();
    if (_sameNodeSet(current, baseline)) {
      return;
    }
    if (baseline.isEmpty) {
      callbacks.writeSelectionClear();
      return;
    }
    callbacks.writeSelectionReplace(baseline);
  }

  bool _sameNodeSet(Set<NodeId> left, Set<NodeId> right) {
    return left.length == right.length && left.containsAll(right);
  }

  void _writeSelectionReplaceIfChanged(Set<NodeId> nextSelection) {
    final current = callbacks.readSelectedNodeIds();
    if (_sameNodeSet(current, nextSelection)) {
      return;
    }
    callbacks.writeSelectionReplace(nextSelection);
    _selectionChangedLocally = true;
  }
}
