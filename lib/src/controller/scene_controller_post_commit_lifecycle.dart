import 'dart:async';

import 'package:flutter/foundation.dart';

import 'internal/repaint_flag.dart';
import 'internal/signals_buffer.dart';
import 'scene_controller_commit_execution.dart';

final class SceneControllerPostCommitLifecycle {
  SceneControllerPostCommitLifecycle({
    required SignalsBuffer signalsBuffer,
    required VoidCallback notifyListeners,
  }) : _signalsBuffer = signalsBuffer,
       _notifyListeners = notifyListeners;

  final SignalsBuffer _signalsBuffer;
  final VoidCallback _notifyListeners;
  bool _notifyScheduled = false;
  bool _notifyPending = false;
  bool _isDisposed = false;

  void requestRepaint({
    required RepaintFlag repaintFlag,
    required bool writeInProgress,
  }) {
    repaintFlag.writeMarkNeedsRepaint();
    if (writeInProgress) {
      return;
    }
    if (repaintFlag.writeTakeNeedsNotify()) {
      _scheduleNotify();
    }
  }

  void dispatch(SceneControllerWriteCommitResult commitResult) {
    final committedSignals = commitResult.committedSignals;
    final needsNotify = commitResult.needsNotify;
    if (committedSignals.isNotEmpty) {
      _signalsBuffer.emitCommitted(committedSignals);
    }
    if (!needsNotify) {
      return;
    }
    if (committedSignals.isEmpty) {
      _scheduleNotify();
      return;
    }

    scheduleMicrotask(_scheduleNotify);
  }

  void _scheduleNotify() {
    if (_isDisposed) {
      return;
    }
    _notifyPending = true;
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;

    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (_isDisposed || !_notifyPending) {
        return;
      }
      _notifyPending = false;
      _notifyListeners();
    });
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _notifyPending = false;
    _notifyScheduled = false;
  }
}
