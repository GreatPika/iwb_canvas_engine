import 'dart:collection';
import 'dart:ui';

import '../../../core/nodes.dart';

/// Selection state for the input pipeline.
///
/// This slice owns:
/// - selected node IDs (stable iteration order)
/// - marquee selection rectangle (scene coordinates)
/// - a monotonically increasing selection revision
class SelectionModel {
  final LinkedHashSet<NodeId> _selectedNodeIds = LinkedHashSet<NodeId>();
  late final Set<NodeId> _selectedNodeIdsView = UnmodifiableSetView(
    _selectedNodeIds,
  );

  Rect? _selectionRect;
  int _selectionRevision = 0;

  Set<NodeId> get selectedNodeIds => _selectedNodeIdsView;
  Rect? get selectionRect => _selectionRect;
  int get selectionRevision => _selectionRevision;

  bool setSelection(Iterable<NodeId> nodeIds) {
    final next = LinkedHashSet<NodeId>.from(nodeIds);
    if (_selectedNodeIds.length == next.length &&
        _selectedNodeIds.containsAll(next)) {
      return false;
    }
    _selectedNodeIds
      ..clear()
      ..addAll(next);
    return true;
  }

  bool setSelectionRect(Rect? rect) {
    if (_selectionRect == rect) return false;
    _selectionRect = rect;
    return true;
  }

  void markSelectionChanged() {
    _selectionRevision++;
  }

  void debugSetSelection(Iterable<NodeId> nodeIds) {
    _selectedNodeIds
      ..clear()
      ..addAll(nodeIds);
  }

  void debugSetSelectionRect(Rect? rect) {
    _selectionRect = rect;
  }
}

