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
    this.preservePendingContextTap = false,
  });

  final PointerCleanupReason reason;
  final PointerCleanupPreviewKind activePreviewKind;
  final bool hasActiveToken;
  final bool hasActiveSession;
  final bool ownsPendingLine;
  final bool hasPendingLine;
  final bool hasPendingContextTap;
  final bool preservePendingContextTap;
}
