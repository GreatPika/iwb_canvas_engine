import '../contract/canvas_pointer_input.dart';
import '../core/pointer_input.dart';

abstract interface class SceneViewPointerSemanticsBridge {
  int? get pendingTapFlushTimestampMs;

  void handleControllerChanged({required bool routerHasLiveRawPointers});

  void handleRoutedSample(
    PointerSample sample, {
    required bool shouldTrackSignals,
  });

  void handleInvalidTerminalSample({
    required CanvasPointerInput input,
    required int pointerId,
    required int referenceTimestampMs,
  });

  void handleRawPointerRelease({required bool isIdleAfterRelease});

  void dispose();
}

abstract interface class SceneViewPointerSemanticsSource {
  SceneViewPointerSemanticsBridge createPointerSemanticsBridge({
    required bool Function() isMounted,
  });
}
