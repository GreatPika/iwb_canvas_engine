import 'package:flutter/foundation.dart';

class V2RepaintSlice {
  bool _needsNotify = false;

  bool get needsNotify => _needsNotify;

  void writeMarkNeedsRepaint() {
    _needsNotify = true;
  }

  void writeDiscardPending() {
    _needsNotify = false;
  }

  bool writeFlushNotify(VoidCallback notifyListeners) {
    if (!_needsNotify) {
      return false;
    }
    _needsNotify = false;
    notifyListeners();
    return true;
  }
}
