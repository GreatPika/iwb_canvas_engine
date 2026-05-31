import 'package:flutter/foundation.dart';

import '../contracts/public/canvas_ids.dart';

@immutable
final class SelectedOrderKey {
  const SelectedOrderKey({
    required this.selectionRevision,
    required this.structuralRevision,
  });

  final int selectionRevision;
  final int structuralRevision;

  @override
  bool operator ==(Object other) {
    return other is SelectedOrderKey &&
        other.selectionRevision == selectionRevision &&
        other.structuralRevision == structuralRevision;
  }

  @override
  int get hashCode => Object.hash(selectionRevision, structuralRevision);
}

final class SelectedOrderSnapshot {
  SelectedOrderSnapshot({
    required this.key,
    required Iterable<CanvasElementId> orderedSelectedIds,
  }) : orderedSelectedIds = List.unmodifiable(orderedSelectedIds);

  final SelectedOrderKey key;
  final List<CanvasElementId> orderedSelectedIds;
  int get selectedCount => orderedSelectedIds.length;
}

final class SelectedOrderCacheProbe {
  const SelectedOrderCacheProbe({
    required this.selectedCount,
    required this.rebuildCount,
  });

  final int selectedCount;
  final int rebuildCount;
}

final class SelectedOrderCache {
  SelectedOrderSnapshot? _current;
  int _rebuildCount = 0;

  SelectedOrderSnapshot readOrBuild({
    required SelectedOrderKey key,
    required Iterable<CanvasElementId> orderedSelectedIds,
  }) {
    final current = _current;
    if (current != null && current.key == key) {
      return current;
    }
    final snapshot = SelectedOrderSnapshot(
      key: key,
      orderedSelectedIds: orderedSelectedIds,
    );
    _current = snapshot;
    _rebuildCount += 1;

    return snapshot;
  }

  SelectedOrderCacheProbe get probe {
    return SelectedOrderCacheProbe(
      selectedCount: _current?.selectedCount ?? 0,
      rebuildCount: _rebuildCount,
    );
  }
}
