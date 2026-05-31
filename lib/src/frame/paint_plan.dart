import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contracts/public/canvas_ids.dart';
import 'frame_cache.dart';
import 'render_element_record.dart';

const int kOrdinaryPaintRecordCacheEntryCapacity = 1024;

@immutable
final class PaintPlanKey {
  const PaintPlanKey({
    required this.structuralRevision,
    required this.boundsRevision,
    required this.elementVisualRevision,
    required this.viewportRect,
    required this.devicePixelRatio,
  });

  final int structuralRevision;
  final int boundsRevision;
  final int elementVisualRevision;
  final Rect viewportRect;
  final double devicePixelRatio;

  @override
  bool operator ==(Object other) {
    return other is PaintPlanKey &&
        other.structuralRevision == structuralRevision &&
        other.boundsRevision == boundsRevision &&
        other.elementVisualRevision == elementVisualRevision &&
        other.viewportRect == viewportRect &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode {
    return Object.hash(
      structuralRevision,
      boundsRevision,
      elementVisualRevision,
      viewportRect,
      devicePixelRatio,
    );
  }
}

final class PaintPlan {
  PaintPlan({
    required this.key,
    required Iterable<RenderElementRecord> ordinaryRecords,
  }) : ordinaryRecords = List.unmodifiable(ordinaryRecords);

  final PaintPlanKey key;
  final List<RenderElementRecord> ordinaryRecords;
  int get candidateCount => ordinaryRecords.length;
}

final class RenderPrimitiveCacheSnapshot {
  RenderPrimitiveCacheSnapshot({
    required Map<TextLayoutCacheKey, TextLayoutCacheEntry> textLayouts,
    required Map<PathGeometryCacheKey, PathGeometryCacheEntry> paths,
    required Map<StrokePathCacheKey, StrokePathCacheEntry> strokes,
  }) : textLayouts = Map.unmodifiable(textLayouts),
       paths = Map.unmodifiable(paths),
       strokes = Map.unmodifiable(strokes);

  static final empty = RenderPrimitiveCacheSnapshot(
    textLayouts: const {},
    paths: const {},
    strokes: const {},
  );

  final Map<TextLayoutCacheKey, TextLayoutCacheEntry> textLayouts;
  final Map<PathGeometryCacheKey, PathGeometryCacheEntry> paths;
  final Map<StrokePathCacheKey, StrokePathCacheEntry> strokes;
}

@immutable
final class OrdinaryPaintRecordKey {
  const OrdinaryPaintRecordKey({
    required this.id,
    required this.structuralRevision,
    required this.boundsRevision,
    required this.elementVisualRevision,
    required this.generation,
    required this.orderToken,
  });

  final CanvasElementId id;
  final int structuralRevision;
  final int boundsRevision;
  final int elementVisualRevision;
  final int generation;
  final int orderToken;

  @override
  bool operator ==(Object other) {
    return other is OrdinaryPaintRecordKey &&
        other.id == id &&
        other.structuralRevision == structuralRevision &&
        other.boundsRevision == boundsRevision &&
        other.elementVisualRevision == elementVisualRevision &&
        other.generation == generation &&
        other.orderToken == orderToken;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      structuralRevision,
      boundsRevision,
      elementVisualRevision,
      generation,
      orderToken,
    );
  }
}

final class OrdinaryPaintRecordCacheEntry {
  OrdinaryPaintRecordCacheEntry({
    required Iterable<MapEntry<OrdinaryPaintRecordKey, RenderElementRecord>>
    records,
    this.capacity = kOrdinaryPaintRecordCacheEntryCapacity,
  }) : _records = Map.unmodifiable(_boundedRecordMap(records, capacity));

  final int capacity;
  final Map<OrdinaryPaintRecordKey, RenderElementRecord> _records;

  RenderElementRecord? readRecord(OrdinaryPaintRecordKey key) {
    return _records[key];
  }

  Iterable<MapEntry<OrdinaryPaintRecordKey, RenderElementRecord>> get records {
    return _records.entries;
  }
}

Map<OrdinaryPaintRecordKey, RenderElementRecord> _boundedRecordMap(
  Iterable<MapEntry<OrdinaryPaintRecordKey, RenderElementRecord>> records,
  int capacity,
) {
  if (capacity <= 0) {
    throw ArgumentError.value(capacity, 'capacity', 'must be positive');
  }
  final bounded = <OrdinaryPaintRecordKey, RenderElementRecord>{};
  for (final entry in records) {
    bounded.remove(entry.key);
    bounded[entry.key] = entry.value;
    while (bounded.length > capacity) {
      bounded.remove(bounded.keys.first);
    }
  }

  return bounded;
}

final class OrdinaryPaintRecordCache
    extends FrameLruCache<PaintPlanKey, OrdinaryPaintRecordCacheEntry> {
  OrdinaryPaintRecordCache() : super(capacity: 16);
}
