import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart' show visibleForTesting;

import '../contracts/internal/prepared_selection_effect.dart';
import '../contracts/internal/selection_facts_port.dart';
import '../contracts/internal/selection_membership_port.dart';
import '../contracts/public/canvas_ids.dart';

// Selection state and revision advance must stay in one owner; moving prepared
// effect installation elsewhere would create selection-state sync glue.
// ignore: number-of-methods
final class SelectionKernel implements SelectionFactsPort {
  SelectionKernel({required SelectionMembershipPort membership})
    : _membership = membership;

  final SelectionMembershipPort _membership;
  static final Object _preparedInstallZoneKey = Object();
  LinkedHashSet<CanvasElementId> _selectedIds = LinkedHashSet();
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

  bool installPreparedEffect(PreparedSelectionEffect effect) {
    return installOwnedPreparedElementIds(effect.takeOwnedElementIds());
  }

  /// Observes the already-owned deletion backing installation in tests only.
  @visibleForTesting
  static T observePreparedInstall<T>(
    void Function() sink,
    T Function() operation,
  ) => runZoned(operation, zoneValues: {_preparedInstallZoneKey: sink});

  /// Installs the backing transferred before a deletion resolver is invoked.
  ///
  /// The caller owns the one-time transfer.  This performs no normalization,
  /// validation, or copying after Store has accepted the bound deletion.
  bool installOwnedPreparedElementIds(LinkedHashSet<CanvasElementId> next) {
    assert(
      _recordPreparedInstall(),
      'prepared Selection installation observation failed',
    );
    if (_sameMembership(_selectedIds, next)) {
      return false;
    }
    _selectedIds = next;
    _selectionRevision += 1;
    return true;
  }

  bool _recordPreparedInstall() {
    final sink = Zone.current[_preparedInstallZoneKey];
    if (sink is void Function()) {
      sink();
    }
    return true;
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
