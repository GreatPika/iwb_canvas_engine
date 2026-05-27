import '../contracts/internal/load_interaction_boundary.dart';

const LoadInteractionBoundary noopLoadInteractionBoundary =
    _NoopLoadInteractionBoundary();

final class _NoopLoadInteractionBoundary implements LoadInteractionBoundary {
  const _NoopLoadInteractionBoundary();

  @override
  PointerCleanupOutcome prepareLoadCleanup() => PointerCleanupOutcome.noChange;
}
