import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _extractMethodBody({
  required String source,
  required String methodStart,
}) {
  final startIndex = source.indexOf(methodStart);
  if (startIndex < 0) {
    throw StateError('Method signature not found: $methodStart');
  }
  var bodyStart = -1;
  var parenDepth = 0;
  for (var i = startIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '(') {
      parenDepth += 1;
    } else if (char == ')') {
      if (parenDepth > 0) {
        parenDepth -= 1;
      }
    } else if (char == '{' && parenDepth == 0) {
      bodyStart = i;
      break;
    }
  }
  if (bodyStart < 0) {
    throw StateError('Method body start not found: $methodStart');
  }

  var depth = 1;
  for (var i = bodyStart + 1; i < source.length; i++) {
    final char = source[i];
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(bodyStart + 1, i);
      }
    }
  }
  throw StateError('Method body end not found: $methodStart');
}

void main() {
  // INV:INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY
  test(
    'interactive facade/runtime/event/draw owners remain structurally split',
    () {
      final facadeSource = File(
        'lib/src/interactive/scene_controller_interactive.dart',
      ).readAsStringSync();
      final runtimeSource = File(
        'lib/src/interactive/internal/interactive_runtime.dart',
      ).readAsStringSync();
      final eventSource = File(
        'lib/src/interactive/internal/interactive_event_dispatcher.dart',
      ).readAsStringSync();
      final drawCoordinatorSource = File(
        'lib/src/interactive/internal/interactive_draw_coordinator.dart',
      ).readAsStringSync();
      final eraserSource = File(
        'lib/src/interactive/internal/interactive_draw_eraser_engine.dart',
      ).readAsStringSync();

      expect(
        facadeSource,
        contains("import 'internal/interactive_runtime.dart';"),
      );
      expect(
        facadeSource,
        contains("import 'internal/interactive_event_dispatcher.dart';"),
      );
      expect(
        facadeSource,
        contains("import 'internal/interactive_selection_actions.dart';"),
      );
      expect(
        facadeSource,
        isNot(contains("import 'internal/interactive_move_session.dart';")),
      );
      expect(
        facadeSource,
        isNot(contains("import 'internal/interactive_gesture_machine.dart';")),
      );
      expect(
        facadeSource,
        isNot(contains("import 'internal/interactive_draw_coordinator.dart';")),
      );
      expect(
        facadeSource,
        isNot(
          contains("import 'internal/interactive_draw_eraser_engine.dart';"),
        ),
      );

      final handlePointerBody = _extractMethodBody(
        source: facadeSource,
        methodStart: 'void handlePointer(CanvasPointerInput input)',
      );
      expect(handlePointerBody, contains('_runtime.handlePointer(input);'));
      expect(handlePointerBody, isNot(contains('_pointerNormalizer')));
      expect(handlePointerBody, isNot(contains('_gestureRouter')));

      final handleDoubleTapBody = _extractMethodBody(
        source: facadeSource,
        methodStart:
            'void handleDoubleTap({required Offset position, int? timestampMs})',
      );
      expect(
        handleDoubleTapBody,
        contains(
          '_runtime.handleDoubleTap(position: position, timestampMs: timestampMs);',
        ),
      );
      expect(handleDoubleTapBody, isNot(contains('resolveTimestampMs(')));

      expect(
        runtimeSource,
        contains("import 'interactive_draw_coordinator.dart';"),
      );
      expect(
        runtimeSource,
        contains("import 'interactive_event_dispatcher.dart';"),
      );
      expect(
        runtimeSource,
        contains("import 'interactive_move_session.dart';"),
      );
      expect(
        runtimeSource,
        contains("import 'interactive_pointer_normalizer.dart';"),
      );
      expect(
        runtimeSource,
        contains("import 'interactive_gesture_router.dart';"),
      );
      expect(
        runtimeSource,
        contains("import 'interactive_double_tap_router.dart';"),
      );
      expect(runtimeSource, isNot(contains('StreamController<')));
      expect(runtimeSource, isNot(contains('_timestampCursorMs')));
      expect(runtimeSource, isNot(contains('_actionCounter')));
      expect(runtimeSource, isNot(contains('_eraserHitsLine(')));

      expect(eventSource, contains('class InteractiveEventDispatcher'));
      expect(eventSource, contains('resolveTimestampMs('));
      expect(eventSource, contains('emitAction('));
      expect(eventSource, contains('emitEditTextRequested('));

      expect(
        drawCoordinatorSource,
        contains("import 'interactive_draw_eraser_engine.dart';"),
      );
      expect(
        drawCoordinatorSource,
        contains("import 'interactive_draw_line_engine.dart';"),
      );
      expect(
        drawCoordinatorSource,
        contains("import 'interactive_draw_stroke_engine.dart';"),
      );
      expect(
        drawCoordinatorSource,
        contains("import 'interactive_draw_terminal_router.dart';"),
      );
      expect(drawCoordinatorSource, isNot(contains('_eraserHitsLine(')));
      expect(drawCoordinatorSource, isNot(contains('_eraserHitsStroke(')));
      expect(
        drawCoordinatorSource,
        isNot(contains('_localEraserSegmentsHitLine(')),
      );
      expect(
        drawCoordinatorSource,
        isNot(contains('_eraserSegmentHitsStrokeBatch(')),
      );

      expect(eraserSource, contains('_eraserHitsLine('));
      expect(eraserSource, contains('_eraserHitsStroke('));
      expect(eraserSource, contains('_localEraserSegmentsHitLine('));
      expect(eraserSource, contains('_eraserSegmentHitsStrokeBatch('));
    },
  );
}
