import 'dart:ui';

import '../../core/action_events.dart';
import '../../core/geometry.dart';
import '../../core/interaction_types.dart';
import '../../contract/snapshot.dart';

class InteractiveDoubleTapRouterCallbacks {
  const InteractiveDoubleTapRouterCallbacks({
    required this.readMode,
    required this.readSnapshot,
    required this.hitTestTopNode,
    required this.resolveTimestampMs,
    required this.emitEditTextRequested,
  });

  final CanvasMode Function() readMode;
  final SceneSnapshot Function() readSnapshot;
  final NodeSnapshot? Function(Offset scenePoint) hitTestTopNode;
  final int Function(int? hintTimestampMs) resolveTimestampMs;
  final void Function(EditTextRequested request) emitEditTextRequested;
}

class InteractiveDoubleTapRouter {
  const InteractiveDoubleTapRouter({required this.callbacks});

  final InteractiveDoubleTapRouterCallbacks callbacks;

  void handleDoubleTap({required Offset position, int? timestampMs}) {
    if (!_isFiniteOffset(position) || callbacks.readMode() != CanvasMode.move) {
      return;
    }

    final scenePoint = toScene(
      position,
      callbacks.readSnapshot().camera.offset,
    );
    final hit = callbacks.hitTestTopNode(scenePoint);
    if (hit is! TextNodeSnapshot) {
      return;
    }

    callbacks.emitEditTextRequested(
      EditTextRequested(
        nodeId: hit.id,
        timestampMs: callbacks.resolveTimestampMs(timestampMs),
        position: position,
      ),
    );
  }

  static bool _isFiniteOffset(Offset value) {
    return value.dx.isFinite && value.dy.isFinite;
  }
}
