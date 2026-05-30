import 'dart:ui';

import 'package:flutter/foundation.dart';

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

final class PaintPlanCache extends FrameLruCache<PaintPlanKey, PaintPlan> {
  PaintPlanCache() : super(capacity: 16);
}
