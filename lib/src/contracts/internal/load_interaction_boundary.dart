final class PointerCleanupOutcome {
  const PointerCleanupOutcome({this.previewChanged = false});

  static const PointerCleanupOutcome noChange = PointerCleanupOutcome();

  final bool previewChanged;
}

abstract interface class LoadInteractionBoundary {
  PointerCleanupOutcome prepareLoadCleanup();
}
