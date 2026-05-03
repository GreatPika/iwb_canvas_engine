class RepaintFlag {
  bool _needsNotify = false;

  bool get needsNotify => _needsNotify;

  void writeMarkNeedsRepaint() {
    _needsNotify = true;
  }

  void writeDiscardPending() {
    _needsNotify = false;
  }

  bool writeTakeNeedsNotify() {
    if (!_needsNotify) {
      return false;
    }
    _needsNotify = false;
    return true;
  }
}
