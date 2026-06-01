final class LoadInteractionCleanupOutcome {
  const LoadInteractionCleanupOutcome({this.previewChanged = false});

  static const LoadInteractionCleanupOutcome noChange =
      LoadInteractionCleanupOutcome();

  final bool previewChanged;
}

abstract interface class LoadInteractionBoundary {
  LoadInteractionCleanupOutcome prepareLoadCleanup();
}
