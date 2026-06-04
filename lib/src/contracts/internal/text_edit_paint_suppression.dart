import 'package:flutter/foundation.dart';

import '../public/canvas_element.dart';
import '../public/canvas_ids.dart';

enum TextEditSuppressionFamily { text }

@immutable
final class TextEditPaintSuppression {
  const TextEditPaintSuppression({
    required this.requestId,
    required this.elementId,
    required this.family,
    required this.elementKind,
    required this.controllerEpoch,
    required this.elementRevision,
    required this.generation,
  });

  final CanvasInteractionRequestId requestId;
  final CanvasElementId elementId;
  final TextEditSuppressionFamily family;
  final CanvasElementKind elementKind;
  final int controllerEpoch;
  final int elementRevision;
  final int generation;

  bool matchesTextElement({
    required CanvasElementId id,
    required CanvasElementKind kind,
    required int revision,
    required int generation,
  }) {
    return family == TextEditSuppressionFamily.text &&
        elementKind == CanvasElementKind.text &&
        kind == CanvasElementKind.text &&
        elementId == id &&
        elementRevision == revision &&
        this.generation == generation;
  }

  @override
  bool operator ==(Object other) {
    return other is TextEditPaintSuppression &&
        other.requestId == requestId &&
        other.elementId == elementId &&
        other.family == family &&
        other.elementKind == elementKind &&
        other.controllerEpoch == controllerEpoch &&
        other.elementRevision == elementRevision &&
        other.generation == generation;
  }

  @override
  int get hashCode {
    return Object.hash(
      requestId,
      elementId,
      family,
      elementKind,
      controllerEpoch,
      elementRevision,
      generation,
    );
  }
}
