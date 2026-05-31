final class FrameRepaintSignal {
  const FrameRepaintSignal({
    required this.mainCanvas,
    required this.overlayCanvas,
    required this.reason,
  });

  const FrameRepaintSignal.none()
    : mainCanvas = false,
      overlayCanvas = false,
      reason = 'none';

  final bool mainCanvas;
  final bool overlayCanvas;
  final String reason;
}
