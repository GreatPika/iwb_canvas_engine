import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../contracts/public/canvas_ids.dart';
import 'frame_cache.dart';
import 'render_element_record.dart';

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
  }) : _records = Map.unmodifiable(Map.fromEntries(records));

  final Map<OrdinaryPaintRecordKey, RenderElementRecord> _records;

  RenderElementRecord? readRecord(OrdinaryPaintRecordKey key) {
    return _records[key];
  }

  Iterable<MapEntry<OrdinaryPaintRecordKey, RenderElementRecord>> get records {
    return _records.entries;
  }
}

final class OrdinaryPaintRecordCache
    extends FrameLruCache<PaintPlanKey, OrdinaryPaintRecordCacheEntry> {
  OrdinaryPaintRecordCache() : super(capacity: 16);
}
