import 'dart:collection';

import '../contract/pointer_input.dart';

enum SceneViewPointerRouteKind { routedDown, routedKnown, stray }

class SceneViewPointerRouteResult {
  const SceneViewPointerRouteResult._({
    required this.kind,
    required this.pointerId,
  });

  const SceneViewPointerRouteResult.routedDown(int pointerId)
    : this._(kind: SceneViewPointerRouteKind.routedDown, pointerId: pointerId);

  const SceneViewPointerRouteResult.routedKnown(int pointerId)
    : this._(kind: SceneViewPointerRouteKind.routedKnown, pointerId: pointerId);

  const SceneViewPointerRouteResult.stray()
    : this._(kind: SceneViewPointerRouteKind.stray, pointerId: null);

  final SceneViewPointerRouteKind kind;
  final int? pointerId;

  bool get isStray => kind == SceneViewPointerRouteKind.stray;
}

class SceneViewPointerReleaseResult {
  const SceneViewPointerReleaseResult({
    required this.pointerId,
    required this.releasedTrackedPointer,
    required this.isIdleAfterRelease,
  });

  const SceneViewPointerReleaseResult.noop()
    : this(
        pointerId: null,
        releasedTrackedPointer: false,
        isIdleAfterRelease: false,
      );

  final int? pointerId;
  final bool releasedTrackedPointer;
  final bool isIdleAfterRelease;

  bool get didRelease => pointerId != null;
}

class SceneViewPointerRouter {
  final Map<int, int> _routedPointerIdByRawPointer = <int, int>{};
  final SplayTreeSet<int> _freePointerIds = SplayTreeSet<int>();

  int _nextPointerId = 1;
  int? _activeTrackedPointerId;
  bool _trackingBlockedUntilIdle = false;

  bool get isIdle => _routedPointerIdByRawPointer.isEmpty;
  bool get hasLiveRawPointers => _routedPointerIdByRawPointer.isNotEmpty;
  int get liveRawPointerCount => _routedPointerIdByRawPointer.length;

  SceneViewPointerRouteResult route({
    required int rawPointer,
    required PointerPhase phase,
  }) {
    final existingPointerId = _routedPointerIdByRawPointer[rawPointer];
    if (existingPointerId != null) {
      return SceneViewPointerRouteResult.routedKnown(existingPointerId);
    }
    if (phase != PointerPhase.down) {
      return const SceneViewPointerRouteResult.stray();
    }

    final pointerId = _allocatePointerId();
    _routedPointerIdByRawPointer[rawPointer] = pointerId;
    return SceneViewPointerRouteResult.routedDown(pointerId);
  }

  bool shouldTrackSignals({
    required int pointerId,
    required PointerPhase phase,
  }) {
    if (_trackingBlockedUntilIdle) {
      return false;
    }

    final activeTrackedPointerId = _activeTrackedPointerId;
    if (activeTrackedPointerId == null) {
      if (phase != PointerPhase.down) {
        return false;
      }
      _activeTrackedPointerId = pointerId;
      return true;
    }

    return activeTrackedPointerId == pointerId;
  }

  SceneViewPointerReleaseResult release(int rawPointer) {
    final pointerId = _routedPointerIdByRawPointer.remove(rawPointer);
    if (pointerId == null) {
      return const SceneViewPointerReleaseResult.noop();
    }

    _freePointerIds.add(pointerId);
    final releasedTrackedPointer = _activeTrackedPointerId == pointerId;
    if (releasedTrackedPointer) {
      _activeTrackedPointerId = null;
    }

    final idleAfterRelease = isIdle;
    if (idleAfterRelease) {
      _trackingBlockedUntilIdle = false;
    } else if (releasedTrackedPointer) {
      _trackingBlockedUntilIdle = true;
    }

    return SceneViewPointerReleaseResult(
      pointerId: pointerId,
      releasedTrackedPointer: releasedTrackedPointer,
      isIdleAfterRelease: idleAfterRelease,
    );
  }

  void reset() {
    _routedPointerIdByRawPointer.clear();
    _freePointerIds.clear();
    _nextPointerId = 1;
    _activeTrackedPointerId = null;
    _trackingBlockedUntilIdle = false;
  }

  int _allocatePointerId() {
    if (_freePointerIds.isEmpty) {
      return _nextPointerId++;
    }
    final pointerId = _freePointerIds.first;
    _freePointerIds.remove(pointerId);
    return pointerId;
  }
}
