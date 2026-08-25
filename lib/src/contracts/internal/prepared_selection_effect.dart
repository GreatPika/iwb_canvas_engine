import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart' show visibleForTesting;

import '../public/canvas_ids.dart';

final class PreparedSelectionEffect {
  PreparedSelectionEffect(Iterable<CanvasElementId> elementIds)
    : _ownedElementIds = LinkedHashSet<CanvasElementId>.of(elementIds) {
    assert(
      _throwInjectedPreparationFailure(),
      'prepared Selection failure injection did not complete',
    );
  }

  static final Object _preparationFailureZoneKey = Object();
  final LinkedHashSet<CanvasElementId> _ownedElementIds;
  bool _consumed = false;

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

  /// Transfers the backing prepared before the resolver to SelectionKernel.
  ///
  /// This internal value is part of the deletion install package and cannot be
  /// copied or validated after Store installation.
  LinkedHashSet<CanvasElementId> takeOwnedElementIds() {
    if (_consumed) {
      throw StateError(
        'A prepared selection effect can only be installed once.',
      );
    }
    _consumed = true;
    return _ownedElementIds;
  }
}
