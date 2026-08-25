import 'package:flutter/foundation.dart';

import 'canvas_element.dart';
import 'canvas_ids.dart';

/// Selects the complete deletion set before it is committed.
typedef CanvasDeletionCommitResolver =
    CanvasDeletionDecision Function(CanvasDeletionCommitRequest request);

/// Determines how selection deletion handles ineligible selected elements.
enum CanvasSelectionDeletePolicy { partial, allOrNone }

/// Identifies the public route that produced a deletion request.
enum CanvasDeletionOperation { deleteSelection, erase }

/// Selects whether a prepared deletion is committed as a whole.
enum CanvasDeletionDecision { accept, cancel }

@immutable
/// Describes whether the current selection can be deleted.
final class CanvasSelectionDeleteAvailability {
  const CanvasSelectionDeleteAvailability({
    required this.hasSelection,
    required this.allSelectedElementsDeletable,
    bool? hasAnySelectedElementDeletable,
  }) : hasAnySelectedElementDeletable =
           hasAnySelectedElementDeletable ?? allSelectedElementsDeletable;

  final bool hasSelection;
  final bool allSelectedElementsDeletable;
  final bool hasAnySelectedElementDeletable;

  @override
  bool operator ==(Object other) {
    return other is CanvasSelectionDeleteAvailability &&
        other.hasSelection == hasSelection &&
        other.allSelectedElementsDeletable == allSelectedElementsDeletable &&
        other.hasAnySelectedElementDeletable == hasAnySelectedElementDeletable;
  }

  @override
  int get hashCode => Object.hash(
    hasSelection,
    allSelectedElementsDeletable,
    hasAnySelectedElementDeletable,
  );
}

@immutable
/// One pre-mutation Store fact supplied to a deletion resolver.
final class CanvasDeletionEntry {
  const CanvasDeletionEntry({
    required this.element,
    required this.layerId,
    required this.elementIndex,
  });

  final CanvasElement element;
  final CanvasLayerId layerId;
  final int elementIndex;
}

@immutable
/// The complete, canonical deletion set proposed to a client.
final class CanvasDeletionCommitRequest {
  CanvasDeletionCommitRequest({
    required this.operation,
    required Iterable<CanvasDeletionEntry> entries,
  }) : _entries = List<CanvasDeletionEntry>.unmodifiable(entries);

  final CanvasDeletionOperation operation;
  final List<CanvasDeletionEntry> _entries;

  List<CanvasDeletionEntry> get entries => _entries;
}
