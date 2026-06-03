import 'dart:ui';

import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_tools.dart';
import 'interaction_read_port.dart';
import 'interaction_runtime_intents.dart';
import 'pointer_session_identity.dart';

final class EraserMachine {
  const EraserMachine();

  EraserStartDecision start({
    required CanvasDrawTool tool,
    required Offset startWorld,
    required CanvasDrawStyle style,
  }) {
    if (tool != CanvasDrawTool.eraser) {
      return const EraserStartDecision.rejected();
    }

    return EraserStartDecision.admitted(
      eraser: PointerEraserCapture(
        points: [startWorld],
        thickness: style.eraserThickness,
      ),
    );
  }

  EraserPreviewDecision preview({
    required PointerEraserCapture eraser,
    required Offset currentWorld,
    required EraserReadFacts facts,
  }) {
    final next = eraser.appendPoint(currentWorld);
    if (identical(next, eraser)) {
      return const EraserPreviewDecision.noChange();
    }

    return EraserPreviewDecision.changed(
      eraser: next,
      preview: CanvasEraserPreview(
        corridor: facts.corridorPoints,
        thickness: next.thickness,
      ),
      exactBudgetExceeded: facts.exactBudgetExceeded,
    );
  }

  EraserPreviewDecision initialPreview({
    required PointerEraserCapture eraser,
    required EraserReadFacts facts,
  }) {
    return EraserPreviewDecision.changed(
      eraser: eraser,
      preview: CanvasEraserPreview(
        corridor: facts.corridorPoints,
        thickness: eraser.thickness,
      ),
      exactBudgetExceeded: facts.exactBudgetExceeded,
    );
  }

  EraserTerminalDecision terminal({
    required PointerSessionId sessionId,
    required PointerSessionToken pointerToken,
    required PointerEraserCapture eraser,
    required EraserReadFacts facts,
  }) {
    if (facts.exactBudgetExceeded || facts.erasedElementIds.isEmpty) {
      return const EraserTerminalDecision.cleanupOnly();
    }

    return EraserTerminalDecision.commit(
      sessionId: sessionId,
      pointerToken: pointerToken,
      eraser: eraser,
      corridorPointCount: facts.corridorPoints.length,
      erasedElementIds: facts.erasedElementIds,
    );
  }
}

final class PointerEraserCapture {
  PointerEraserCapture({
    required Iterable<Offset> points,
    required this.thickness,
  }) : points = List.unmodifiable(points);

  final List<Offset> points;
  final double thickness;

  PointerEraserCapture appendPoint(Offset point) {
    if (points.isNotEmpty && points.last == point) {
      return this;
    }

    return PointerEraserCapture(
      points: [...points, point],
      thickness: thickness,
    );
  }
}

final class EraserStartDecision {
  const EraserStartDecision.rejected() : admitted = false, eraser = null;

  const EraserStartDecision.admitted({required this.eraser}) : admitted = true;

  final bool admitted;
  final PointerEraserCapture? eraser;
}

final class EraserPreviewDecision {
  const EraserPreviewDecision.noChange()
    : changed = false,
      eraser = null,
      preview = null,
      exactBudgetExceeded = false;

  const EraserPreviewDecision.changed({
    required this.eraser,
    required this.preview,
    required this.exactBudgetExceeded,
  }) : changed = true;

  final bool changed;
  final PointerEraserCapture? eraser;
  final CanvasEraserPreview? preview;
  final bool exactBudgetExceeded;
}

final class EraserTerminalDecision {
  const EraserTerminalDecision.cleanupOnly() : intent = null;

  EraserTerminalDecision.commit({
    required PointerSessionId sessionId,
    required PointerSessionToken pointerToken,
    required PointerEraserCapture eraser,
    required int corridorPointCount,
    required Iterable<CanvasElementId> erasedElementIds,
  }) : intent = EraserCommitIntent(
         sessionId: sessionId,
         pointerToken: pointerToken,
         eraserThickness: eraser.thickness,
         corridorPointCount: corridorPointCount,
         erasedElementIds: erasedElementIds,
       );

  final EraserCommitIntent? intent;
}
