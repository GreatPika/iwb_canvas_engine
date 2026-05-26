import 'dart:collection';

import '../api/canvas_ids.dart';
import '../runtime/selection_facts_port.dart';
import '../runtime/selection_membership_port.dart';

final class SelectionKernel implements SelectionFactsPort {
  SelectionKernel({required SelectionMembershipPort membership})
    : _membership = membership;

  final SelectionMembershipPort _membership;
  final LinkedHashSet<CanvasElementId> _selectedIds = LinkedHashSet();
  int _selectionRevision = 0;

  Set<CanvasElementId> get selectedElementIds => Set.unmodifiable(_selectedIds);

  @override
  SelectionFacts get selectionFacts {
    return SelectionFacts(
      selectedElementIds: _selectedIds,
      selectionRevision: _selectionRevision,
    );
  }

  bool setSelection(Iterable<CanvasElementId> ids) {
    return _replaceSelection(_membership.normalizeSelection(ids));
  }

  bool toggleSelection(CanvasElementId id) {
    if (_selectedIds.contains(id)) {
      final next = LinkedHashSet<CanvasElementId>.of(_selectedIds)..remove(id);

      return _replaceSelection(next);
    }

    final normalized = _membership.normalizeSelection([id]);
    if (normalized.isEmpty) {
      return false;
    }

    return _replaceSelection(
      LinkedHashSet<CanvasElementId>.of(_selectedIds)..add(normalized.single),
    );
  }

  bool clearSelection() {
    if (_selectedIds.isEmpty) {
      return false;
    }

    return _replaceSelection(const {});
  }

  bool clearForDocumentReplacement() {
    _selectedIds.clear();
    _selectionRevision += 1;

    return true;
  }

  bool selectAll({required bool onlySelectable}) {
    return _replaceSelection(
      _membership.selectAllElementIds(onlySelectable: onlySelectable),
    );
  }

  bool pruneSelection() {
    return _replaceSelection(_membership.normalizeSelection(_selectedIds));
  }

  bool _replaceSelection(Iterable<CanvasElementId> ids) {
    final next = LinkedHashSet<CanvasElementId>.of(ids);
    if (_sameMembership(_selectedIds, next)) {
      return false;
    }
    _selectedIds
      ..clear()
      ..addAll(next);
    _selectionRevision += 1;

    return true;
  }
}

bool _sameMembership(Set<CanvasElementId> current, Set<CanvasElementId> next) {
  if (current.length != next.length) {
    return false;
  }

  return current.every(next.contains);
}
