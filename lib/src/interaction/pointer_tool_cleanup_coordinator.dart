enum PointerCleanupReason {
  selectedMove,
  marquee,
  modeToolChange,
  interactiveDisabled,
  preparedLoadSuccess,
  dispose,
  staleTerminal,
  invalidTerminal,
  noOpTerminal,
  resolverCancel,
  resolverError,
  cancel,
  editFailure,
  postSuccessCommit,
  contextTap,
}

enum PointerCleanupPreviewKind {
  none,
  marquee,
  selectedMove,
  pencilStroke,
  markerStroke,
  pendingLineStart,
  linePreview,
  eraser,
}

enum PointerCleanupRepaintTarget { none, main, overlay, mainAndOverlay }

enum PointerSessionDisposition { preserved, released }

enum PointerPendingLineDisposition { none, preserved, cleared }

enum PointerPendingContextTapDisposition { none, preserved, cleared }

final class PointerCleanupOutcome {
  const PointerCleanupOutcome({
    this.reason,
    this.previousPreviewKind = PointerCleanupPreviewKind.none,
    this.previewChanged = false,
    this.publicStateNeeded = false,
    this.repaintTarget = PointerCleanupRepaintTarget.none,
    this.activeTokenReleased = false,
    this.sessionDisposition = PointerSessionDisposition.preserved,
    this.pendingLineDisposition = PointerPendingLineDisposition.none,
    this.pendingContextTapDisposition =
        PointerPendingContextTapDisposition.none,
    this.loadPreparedBeforeInstall = false,
    this.disposeBeforeStreamClose = false,
    this.actionEmissionAllowed = false,
  });

  static const PointerCleanupOutcome noChange = PointerCleanupOutcome();

  final PointerCleanupReason? reason;
  final PointerCleanupPreviewKind previousPreviewKind;
  final bool previewChanged;
  final bool publicStateNeeded;
  final PointerCleanupRepaintTarget repaintTarget;
  final bool activeTokenReleased;
  final PointerSessionDisposition sessionDisposition;
  final PointerPendingLineDisposition pendingLineDisposition;
  final PointerPendingContextTapDisposition pendingContextTapDisposition;
  final bool loadPreparedBeforeInstall;
  final bool disposeBeforeStreamClose;
  final bool actionEmissionAllowed;
}

final class PointerCleanupRequest {
  const PointerCleanupRequest({
    required this.reason,
    this.activePreviewKind = PointerCleanupPreviewKind.none,
    this.hasActiveToken = false,
    this.hasActiveSession = false,
    this.ownsPendingLine = false,
    this.hasPendingLine = false,
    this.hasPendingContextTap = false,
  });

  final PointerCleanupReason reason;
  final PointerCleanupPreviewKind activePreviewKind;
  final bool hasActiveToken;
  final bool hasActiveSession;
  final bool ownsPendingLine;
  final bool hasPendingLine;
  final bool hasPendingContextTap;
}

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
