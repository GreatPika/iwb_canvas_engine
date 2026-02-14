import 'dart:ui';

/// Public pointer phase for manual controller input routing.
enum CanvasPointerPhase { down, move, up, cancel }

/// Public pointer input sample accepted by [SceneControllerInteractiveV2].
class CanvasPointerInput {
  const CanvasPointerInput({
    required this.pointerId,
    required this.position,
    required this.timestampMs,
    required this.phase,
    required this.kind,
  });

  final int pointerId;
  final Offset position;
  final int timestampMs;
  final CanvasPointerPhase phase;
  final PointerDeviceKind kind;
}
