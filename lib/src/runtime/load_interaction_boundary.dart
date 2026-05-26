final class PointerCleanupOutcome {
  const PointerCleanupOutcome({this.previewChanged = false});

  static const PointerCleanupOutcome noChange = PointerCleanupOutcome();

  final bool previewChanged;
}

abstract interface class LoadInteractionBoundary {
  PointerCleanupOutcome prepareLoadCleanup();
}

const LoadInteractionBoundary noopLoadInteractionBoundary =
    _NoopLoadInteractionBoundary();

final class _NoopLoadInteractionBoundary implements LoadInteractionBoundary {
  const _NoopLoadInteractionBoundary();

  @override
  PointerCleanupOutcome prepareLoadCleanup() => PointerCleanupOutcome.noChange;
}
