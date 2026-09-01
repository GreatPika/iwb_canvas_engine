import 'package:flutter/foundation.dart';

/// Determines how selection deletion handles ineligible selected elements.
enum CanvasSelectionDeletePolicy { partial, allOrNone }

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
