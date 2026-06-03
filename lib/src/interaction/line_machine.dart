import 'dart:ui';

import '../contracts/public/canvas_preview.dart';
import '../contracts/public/canvas_tools.dart';
import 'interaction_runtime_intents.dart';
import 'pointer_session_identity.dart';

final class LineMachine {
  const LineMachine();

  LineFirstTapStartDecision startFirstTap({
    required CanvasDrawTool tool,
    required Offset startWorld,
    required CanvasDrawStyle style,
  }) {
    if (tool != CanvasDrawTool.line) {
      return const LineFirstTapStartDecision.rejected();
    }

    return LineFirstTapStartDecision.admitted(
      firstTap: PointerLineFirstTapCapture(
        startWorld: startWorld,
        color: style.color,
        thickness: style.lineThickness,
      ),
    );
  }

  LineFirstTapTerminalDecision firstTapTerminal({
    required PointerLineFirstTapCapture firstTap,
    required Offset terminalWorld,
    required double tapSlop,
  }) {
    if ((terminalWorld - firstTap.startWorld).distance > tapSlop) {
      return const LineFirstTapTerminalDecision.rejected();
    }

    return LineFirstTapTerminalDecision.accepted(
      startWorld: firstTap.startWorld,
      color: firstTap.color,
      thickness: firstTap.thickness,
    );
  }

  LineEndpointStartDecision startEndpoint({
    required LinePendingStartCapture pendingLine,
    required Offset endWorld,
  }) {
    return LineEndpointStartDecision.admitted(
      line: PointerLineEndpointCapture(
        startWorld: pendingLine.startWorld,
        endWorld: endWorld,
        timestampMs: pendingLine.timestampMs,
        color: pendingLine.color,
        thickness: pendingLine.thickness,
      ),
    );
  }

  LineEndpointPreviewDecision preview({
    required PointerLineEndpointCapture line,
    required Offset endWorld,
  }) {
    if (line.endWorld == endWorld) {
      return const LineEndpointPreviewDecision.noChange();
    }

    return LineEndpointPreviewDecision.changed(
      line: line.withEndWorld(endWorld),
    );
  }

  LineEndpointTerminalDecision terminal({
    required PointerSessionId sessionId,
    required PointerSessionToken pointerToken,
    required PointerLineEndpointCapture line,
    required Offset terminalWorld,
  }) {
    return LineEndpointTerminalDecision.commit(
      sessionId: sessionId,
      pointerToken: pointerToken,
      line: line.withEndWorld(terminalWorld),
    );
  }
}

final class LinePendingStartCapture {
  const LinePendingStartCapture({
    required this.startWorld,
    required this.timestampMs,
    required this.color,
    required this.thickness,
  });

  final Offset startWorld;
  final int timestampMs;
  final Color color;
  final double thickness;
}

final class PointerLineFirstTapCapture {
  const PointerLineFirstTapCapture({
    required this.startWorld,
    required this.color,
    required this.thickness,
  });

  final Offset startWorld;
  final Color color;
  final double thickness;
}

final class PointerLineEndpointCapture {
  const PointerLineEndpointCapture({
    required this.startWorld,
    required this.endWorld,
    required this.timestampMs,
    required this.color,
    required this.thickness,
  });

  final Offset startWorld;
  final Offset endWorld;
  final int timestampMs;
  final Color color;
  final double thickness;

  PointerLineEndpointCapture withEndWorld(Offset value) {
    return PointerLineEndpointCapture(
      startWorld: startWorld,
      endWorld: value,
      timestampMs: timestampMs,
      color: color,
      thickness: thickness,
    );
  }

  CanvasLinePreview get preview {
    return CanvasLinePreview(
      start: startWorld,
      end: endWorld,
      color: color,
      thickness: thickness,
    );
  }
}

final class LineFirstTapStartDecision {
  const LineFirstTapStartDecision.rejected()
    : admitted = false,
      firstTap = null;

  const LineFirstTapStartDecision.admitted({required this.firstTap})
    : admitted = true;

  final bool admitted;
  final PointerLineFirstTapCapture? firstTap;
}

final class LineFirstTapTerminalDecision {
  const LineFirstTapTerminalDecision.rejected()
    : accepted = false,
      startWorld = null,
      color = null,
      thickness = null;

  const LineFirstTapTerminalDecision.accepted({
    required this.startWorld,
    required this.color,
    required this.thickness,
  }) : accepted = true;

  final bool accepted;
  final Offset? startWorld;
  final Color? color;
  final double? thickness;
}

final class LineEndpointStartDecision {
  const LineEndpointStartDecision.admitted({required this.line});

  final PointerLineEndpointCapture line;
}

final class LineEndpointPreviewDecision {
  const LineEndpointPreviewDecision.noChange() : changed = false, line = null;

  const LineEndpointPreviewDecision.changed({required this.line})
    : changed = true;

  final bool changed;
  final PointerLineEndpointCapture? line;
}

final class LineEndpointTerminalDecision {
  LineEndpointTerminalDecision.commit({
    required PointerSessionId sessionId,
    required PointerSessionToken pointerToken,
    required PointerLineEndpointCapture line,
  }) : intent = DrawLineCommitIntent(
         sessionId: sessionId,
         pointerToken: pointerToken,
         startWorld: line.startWorld,
         endWorld: line.endWorld,
         color: line.color,
         thickness: line.thickness,
         opacity: 1.0,
       );

  final DrawLineCommitIntent intent;
}
