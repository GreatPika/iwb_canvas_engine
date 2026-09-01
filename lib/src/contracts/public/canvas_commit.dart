import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'canvas_actions.dart';
import 'canvas_document.dart';
import 'canvas_element.dart';
import 'canvas_geometry.dart';
import 'canvas_ids.dart';
import 'canvas_tools.dart';

/// Resolves one fully-qualified user document operation before installation.
typedef CanvasCommitResolver =
    CanvasCommitResolution Function(CanvasCommitRequest request);

/// A host-owned terminal for one accepted confirmation attempt.
abstract interface class CanvasCommitLease {
  void committed();
  void aborted();
}

@immutable
/// Resolver outcome for a prepared canvas commit.
sealed class CanvasCommitResolution {
  const CanvasCommitResolution();
}

@immutable
/// Cancels a prepared canvas commit.
final class CanvasCommitCancel extends CanvasCommitResolution {
  const CanvasCommitCancel({this.reason});

  final String? reason;
}

@immutable
/// Accepts a prepared canvas commit with its terminal lease.
final class CanvasCommitAccept extends CanvasCommitResolution {
  const CanvasCommitAccept({required this.lease});

  final CanvasCommitLease lease;
}

@immutable
/// Accepts a move commit with the resolved translation and lease.
final class CanvasMoveCommitAccept extends CanvasCommitResolution {
  const CanvasMoveCommitAccept({required this.delta, required this.lease});

  final Offset delta;
  final CanvasCommitLease lease;
}

/// Immutable facts shared by every pre-commit operation proposal.
@immutable
sealed class CanvasCommitRequest {
  CanvasCommitRequest({
    required this.documentSummary,
    required this.documentRevision,
    required Iterable<CanvasElementId> selectedElementIdsBefore,
  }) : _selectedElementIdsBefore = List.unmodifiable(selectedElementIdsBefore);

  final CanvasDocumentSummary documentSummary;
  final int documentRevision;
  final List<CanvasElementId> _selectedElementIdsBefore;

  List<CanvasElementId> get selectedElementIdsBefore =>
      _selectedElementIdsBefore;
}

/// Exact pre-mutation placement for an element in content or background.
@immutable
final class CanvasCommitElementEntry {
  const CanvasCommitElementEntry({
    required this.element,
    required this.layerId,
    required this.elementIndex,
  });

  final CanvasElement element;
  final CanvasLayerId? layerId;
  final int elementIndex;
}

@immutable
/// Prepared draw candidate submitted for host confirmation.
final class CanvasDrawCommitRequest extends CanvasCommitRequest {
  CanvasDrawCommitRequest({
    required super.documentSummary,
    required super.documentRevision,
    required super.selectedElementIdsBefore,
    required this.entry,
    required this.tool,
    required this.layerIndex,
    required this.createsLayer,
  });

  final CanvasCommitElementEntry entry;
  final CanvasDrawTool tool;
  final int layerIndex;
  final bool createsLayer;
}

@immutable
/// Prepared deletion entries submitted for host confirmation.
final class CanvasDeleteCommitRequest extends CanvasCommitRequest {
  CanvasDeleteCommitRequest({
    required super.documentSummary,
    required super.documentRevision,
    required super.selectedElementIdsBefore,
    required Iterable<CanvasCommitElementEntry> entries,
  }) : _entries = List.unmodifiable(entries);

  final List<CanvasCommitElementEntry> _entries;
  List<CanvasCommitElementEntry> get entries => _entries;
}

@immutable
/// Prepared terminal erase submitted for host confirmation.
final class CanvasEraseCommitRequest extends CanvasCommitRequest {
  CanvasEraseCommitRequest({
    required super.documentSummary,
    required super.documentRevision,
    required super.selectedElementIdsBefore,
    required Iterable<CanvasCommitElementEntry> entries,
    required Iterable<Offset> corridorWorld,
    required this.eraserThickness,
  }) : _entries = List.unmodifiable(entries),
       _corridorWorld = List.unmodifiable(corridorWorld);

  final List<CanvasCommitElementEntry> _entries;
  final List<Offset> _corridorWorld;
  final double eraserThickness;
  List<CanvasCommitElementEntry> get entries => _entries;
  List<Offset> get corridorWorld => _corridorWorld;
}

@immutable
/// Prepared selection move submitted with its proposed delta.
final class CanvasMoveCommitRequest extends CanvasCommitRequest {
  CanvasMoveCommitRequest({
    required super.documentSummary,
    required super.documentRevision,
    required super.selectedElementIdsBefore,
    required Iterable<CanvasElementRead> movedElements,
    required this.proposedDelta,
    required this.selectionBoundsWorld,
  }) : _movedElements = List.unmodifiable(movedElements);

  final List<CanvasElementRead> _movedElements;
  final Offset proposedDelta;
  final Rect selectionBoundsWorld;
  List<CanvasElementRead> get movedElements => _movedElements;
}

@immutable
/// Prepared selection rotation submitted for host confirmation.
final class CanvasRotateCommitRequest extends CanvasCommitRequest {
  CanvasRotateCommitRequest({
    required super.documentSummary,
    required super.documentRevision,
    required super.selectedElementIdsBefore,
    required Iterable<CanvasElementRead> affectedElements,
    required this.pivotWorld,
    required this.worldTransform,
    required CanvasTransformOperation operation,
  }) : _affectedElements = List.unmodifiable(affectedElements),
       operation = _rotationOperation(operation);

  final List<CanvasElementRead> _affectedElements;
  final Offset pivotWorld;
  final CanvasTransform worldTransform;
  final CanvasTransformOperation operation;
  List<CanvasElementRead> get affectedElements => _affectedElements;
}

@immutable
/// Prepared selection reflection submitted for host confirmation.
final class CanvasReflectCommitRequest extends CanvasCommitRequest {
  CanvasReflectCommitRequest({
    required super.documentSummary,
    required super.documentRevision,
    required super.selectedElementIdsBefore,
    required Iterable<CanvasElementRead> affectedElements,
    required this.pivotWorld,
    required this.worldTransform,
    required CanvasTransformOperation operation,
  }) : _affectedElements = List.unmodifiable(affectedElements),
       operation = _reflectionOperation(operation);

  final List<CanvasElementRead> _affectedElements;
  final Offset pivotWorld;
  final CanvasTransform worldTransform;
  final CanvasTransformOperation operation;
  List<CanvasElementRead> get affectedElements => _affectedElements;
}

CanvasTransformOperation _rotationOperation(CanvasTransformOperation value) {
  if (value == CanvasTransformOperation.rotateClockwise ||
      value == CanvasTransformOperation.rotateCounterClockwise) {
    return value;
  }
  throw ArgumentError.value(value, 'operation', 'must be a rotation');
}

CanvasTransformOperation _reflectionOperation(CanvasTransformOperation value) {
  if (value == CanvasTransformOperation.flipVertical ||
      value == CanvasTransformOperation.flipHorizontal) {
    return value;
  }
  throw ArgumentError.value(value, 'operation', 'must be a reflection');
}

@immutable
/// Prepared changed text edit submitted for host confirmation.
final class CanvasTextEditCommitRequest extends CanvasCommitRequest {
  CanvasTextEditCommitRequest({
    required super.documentSummary,
    required super.documentRevision,
    required super.selectedElementIdsBefore,
    required this.before,
    required this.after,
  });

  final CanvasTextElement before;
  final CanvasTextElement after;
}
