import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Coalesces repaint notifications to at most one per frame.
///
/// This is intentionally separate from [SceneController] so that future input
/// slices can depend on it without importing the controller.
class RepaintScheduler {
  RepaintScheduler({required VoidCallback notifyListeners})
    : _notifyListeners = notifyListeners;

  final VoidCallback _notifyListeners;

  bool _repaintScheduled = false;
  int _repaintToken = 0;
  bool _isDisposed = false;
  bool _needsNotify = false;

  bool get needsNotify => _needsNotify;

  void markNeedsNotify() {
    _needsNotify = true;
  }

  void dispose() {
    _isDisposed = true;
    _needsNotify = false;
    _cancelScheduledRepaint();
  }

  void _cancelScheduledRepaint() {
    _repaintScheduled = false;
    _repaintToken++;
  }

  void requestRepaintOncePerFrame() {
    if (_isDisposed) return;
    if (_repaintScheduled) return;

    _repaintScheduled = true;
    final token = ++_repaintToken;

    try {
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        if (_isDisposed) return;
        if (token != _repaintToken) return;
        _repaintScheduled = false;
        _needsNotify = false;
        _notifyListeners();
      });

      SchedulerBinding.instance.ensureVisualUpdate();
    } on FlutterError {
      // If no binding exists yet (e.g. in certain tests or during early init),
      // fall back to an immediate notification.
      notifyNow();
    }
  }

  void notifyNow() {
    if (_isDisposed) return;
    _cancelScheduledRepaint();
    _notifyListeners();
    _needsNotify = false;
  }
}
