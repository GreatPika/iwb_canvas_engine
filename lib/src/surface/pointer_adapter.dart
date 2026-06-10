import 'package:flutter/widgets.dart';

import '../contracts/public/canvas_pointer.dart';

final class CanvasSurfacePointerAdapter extends StatelessWidget {
  const CanvasSurfacePointerAdapter({
    required this.child,
    required this.routeInput,
    super.key,
  });

  final Widget child;
  final void Function(CanvasPointerInput input) routeInput;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _route(event, CanvasPointerLifecyclePhase.down);
      },
      onPointerMove: (event) {
        _route(event, CanvasPointerLifecyclePhase.move);
      },
      onPointerUp: (event) {
        _route(event, CanvasPointerLifecyclePhase.up);
      },
      onPointerCancel: (event) {
        _route(event, CanvasPointerLifecyclePhase.cancel);
      },
      child: child,
    );
  }

  void _route(PointerEvent event, CanvasPointerLifecyclePhase phase) {
    final position = event.localPosition;
    if (!position.dx.isFinite || !position.dy.isFinite) {
      if (phase == CanvasPointerLifecyclePhase.up ||
          phase == CanvasPointerLifecyclePhase.cancel) {
        routeInput(
          CanvasPointerTerminalCleanup(
            pointerId: event.pointer,
            phase: phase,
            kind: event.kind,
            timestampMs: _timestampMsFor(event),
          ),
        );
      }

      return;
    }
    routeInput(
      CanvasPointerSample(
        pointerId: event.pointer,
        position: position,
        phase: phase,
        kind: event.kind,
        timestampMs: _timestampMsFor(event),
      ),
    );
  }

  int? _timestampMsFor(PointerEvent event) {
    final timestamp = event.timeStamp;

    return !timestamp.isNegative ? timestamp.inMilliseconds : null;
  }
}
