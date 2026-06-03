import 'pointer_cleanup_outcome.dart';

final class PointerToolCleanupCoordinator {
  const PointerToolCleanupCoordinator();

  PointerCleanupOutcome cleanup(PointerCleanupRequest request) {
    final previewChanged = _previewChanged(request);
    final sessionReleased = request.hasActiveSession;
    final pendingLineDisposition = _pendingLineDisposition(request);

    return PointerCleanupOutcome(
      reason: request.reason,
      previousPreviewKind: request.activePreviewKind,
      previewChanged: previewChanged,
      publicStateNeeded: previewChanged || sessionReleased,
      repaintTarget: previewChanged
          ? _repaintTargetFor(request.activePreviewKind)
          : PointerCleanupRepaintTarget.none,
      activeTokenReleased: request.hasActiveToken,
      sessionDisposition: sessionReleased
          ? PointerSessionDisposition.released
          : PointerSessionDisposition.preserved,
      pendingLineDisposition: pendingLineDisposition,
      pendingContextTapDisposition: request.hasPendingContextTap
          ? PointerPendingContextTapDisposition.cleared
          : PointerPendingContextTapDisposition.none,
      loadPreparedBeforeInstall:
          request.reason == PointerCleanupReason.preparedLoadSuccess,
      disposeBeforeStreamClose: request.reason == PointerCleanupReason.dispose,
      actionEmissionAllowed: false,
    );
  }

  bool _previewChanged(PointerCleanupRequest request) {
    if (request.activePreviewKind == PointerCleanupPreviewKind.none) {
      return false;
    }
    if (request.reason == PointerCleanupReason.interactiveDisabled &&
        request.activePreviewKind ==
            PointerCleanupPreviewKind.pendingLineStart &&
        request.hasPendingLine &&
        !request.ownsPendingLine) {
      return false;
    }

    return true;
  }

  PointerCleanupRepaintTarget _repaintTargetFor(
    PointerCleanupPreviewKind kind,
  ) {
    return switch (kind) {
      PointerCleanupPreviewKind.none => PointerCleanupRepaintTarget.none,
      PointerCleanupPreviewKind.selectedMove =>
        PointerCleanupRepaintTarget.main,
      PointerCleanupPreviewKind.marquee ||
      PointerCleanupPreviewKind.pencilStroke ||
      PointerCleanupPreviewKind.markerStroke ||
      PointerCleanupPreviewKind.pendingLineStart ||
      PointerCleanupPreviewKind.linePreview ||
      PointerCleanupPreviewKind.eraser => PointerCleanupRepaintTarget.overlay,
    };
  }

  PointerPendingLineDisposition _pendingLineDisposition(
    PointerCleanupRequest request,
  ) {
    if (!request.hasPendingLine) {
      return PointerPendingLineDisposition.none;
    }
    if (request.reason == PointerCleanupReason.interactiveDisabled &&
        !request.ownsPendingLine) {
      return PointerPendingLineDisposition.preserved;
    }

    return PointerPendingLineDisposition.cleared;
  }
}
