import 'dart:ui';

/// Public pointer phase for manual controller input routing.
enum CanvasPointerPhase { down, move, up, cancel }

/// Public pointer input sample accepted by [SceneControllerInteractive].
class CanvasPointerInput {
  const CanvasPointerInput({
    required this.pointerId,
    required this.position,
    this.timestampMs,
    required this.phase,
    required this.kind,
  });

  final int pointerId;
  final Offset position;

  /// Optional timestamp hint in milliseconds.
  ///
  /// When `null`, controller assigns a monotonic internal timestamp.
  final int? timestampMs;
  final CanvasPointerPhase phase;
  final PointerDeviceKind kind;
}
