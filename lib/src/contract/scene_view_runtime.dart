import 'canvas_pointer_input.dart';
import 'pointer_input.dart';
import 'scene_view_render_state.dart';

abstract interface class SceneViewRuntime {
  SceneViewRenderState get renderState;

  SceneViewPointerSession createPointerSession({
    required bool Function() isMounted,
    required bool Function() hasLiveRawPointers,
  });
}

abstract interface class SceneViewPointerSession {
  int? get pendingTapFlushTimestampMs;

  void detach();

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
