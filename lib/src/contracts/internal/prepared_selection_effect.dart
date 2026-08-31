import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart' show visibleForTesting;

import '../public/canvas_ids.dart';

final class PreparedSelectionEffect {
  /// Test doubles must supply a final state too; production SelectionKernel
  /// uses [PreparedSelectionEffect.prepared] with its authoritative revision.
  @visibleForTesting
  PreparedSelectionEffect(
    Iterable<CanvasElementId> elementIds, {
    bool didChange = true,
    int nextRevision = 1,
  }) : _ownedElementIds = LinkedHashSet<CanvasElementId>.of(elementIds),
       _didChange = didChange,
       _nextRevision = nextRevision {
    assert(
      _throwInjectedPreparationFailure(),
      'prepared Selection failure injection did not complete',
    );
  }

  PreparedSelectionEffect.prepared(
    LinkedHashSet<CanvasElementId> ownedElementIds, {
    required bool didChange,
    required int nextRevision,
  }) : _ownedElementIds = ownedElementIds,
       _didChange = didChange,
       _nextRevision = nextRevision {
    assert(
      _throwInjectedPreparationFailure(),
      'prepared Selection failure injection did not complete',
    );
  }

  static final Object _preparationFailureZoneKey = Object();
  final LinkedHashSet<CanvasElementId> _ownedElementIds;
  final bool _didChange;
  final int _nextRevision;
  bool _transferred = false;

  /// Causes the real prepared-backing owner to fail only under test asserts.
  @visibleForTesting
  static T injectPreparationFailure<T>(Error error, T Function() operation) =>
      runZoned(operation, zoneValues: {_preparationFailureZoneKey: error});

  static bool _throwInjectedPreparationFailure() {
    final error = Zone.current[_preparationFailureZoneKey];
    if (error is Error) {
      throw error;
    }
    return true;
  }

  /// Transfers the selection-owned final state before any Store mutation.
  PreparedSelectionInstall transferOwnership() {
    if (_transferred) {
      throw StateError(
        'A prepared selection effect can only be transferred once.',
      );
    }
    _transferred = true;
    return PreparedSelectionInstall._(
      elementIds: _ownedElementIds,
      didChange: _didChange,
      nextRevision: _nextRevision,
    );
  }
}

/// Selection-owned final install state. Its fields are complete before Store
/// installation and the Selection tail performs only the recorded assignments.
final class PreparedSelectionInstall {
  const PreparedSelectionInstall._({
    required this.elementIds,
    required this.didChange,
    required this.nextRevision,
  });

  final LinkedHashSet<CanvasElementId> elementIds;
  final bool didChange;
  final int nextRevision;
}
