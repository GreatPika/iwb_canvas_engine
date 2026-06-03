import 'package:flutter/widgets.dart';

import '../contracts/public/canvas_pointer.dart';

final class CanvasSurfacePointerAdapter extends StatelessWidget {
  const CanvasSurfacePointerAdapter({
    required this.child,
    required this.routeSample,
    super.key,
  });

  final Widget child;
  final void Function(CanvasPointerSample sample) routeSample;

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
      return;
    }
    final timestamp = event.timeStamp;
    routeSample(
      CanvasPointerSample(
        pointerId: event.pointer,
        position: position,
        phase: phase,
        kind: event.kind,
        timestampMs: !timestamp.isNegative ? timestamp.inMilliseconds : null,
      ),
    );
  }
}
