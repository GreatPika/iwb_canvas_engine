import 'package:iwb_canvas_engine/src/interaction/pointer_tool_cleanup_coordinator.dart';
import 'package:test/test.dart';

void main() {
  test('classifies every cleanup reason', () {
    expect(_verifyCleanupReasons, returnsNormally);
  });

  test('maps preview cleanup to repaint targets', () {
    expect(_verifyPreviewRepaintTargets, returnsNormally);
  });

  test('records token, session, pending, load, and dispose dispositions', () {
    expect(_verifyCleanupDispositions, returnsNormally);
  });

  test('resolver error cleanup cannot produce an action', () {
    expect(_verifyResolverErrorNoAction, returnsNormally);
  });
}

void _verifyCleanupReasons() {
  const coordinator = PointerToolCleanupCoordinator();

  for (final reason in PointerCleanupReason.values) {
    final outcome = coordinator.cleanup(PointerCleanupRequest(reason: reason));
    expect(outcome.reason, reason);
    expect(outcome.actionEmissionAllowed, isFalse);
  }
}

void _verifyPreviewRepaintTargets() {
  const coordinator = PointerToolCleanupCoordinator();

  final selectedMove = coordinator.cleanup(
    const PointerCleanupRequest(
      reason: PointerCleanupReason.selectedMove,
      activePreviewKind: PointerCleanupPreviewKind.selectedMove,
    ),
  );
  final marquee = coordinator.cleanup(
    const PointerCleanupRequest(
      reason: PointerCleanupReason.marquee,
      activePreviewKind: PointerCleanupPreviewKind.marquee,
    ),
  );
  final noPreview = coordinator.cleanup(
    const PointerCleanupRequest(reason: PointerCleanupReason.noOpTerminal),
  );

  expect(selectedMove.previewChanged, isTrue);
  expect(selectedMove.publicStateNeeded, isTrue);
  expect(selectedMove.repaintTarget, PointerCleanupRepaintTarget.main);
  expect(marquee.previewChanged, isTrue);
  expect(marquee.repaintTarget, PointerCleanupRepaintTarget.overlay);
  expect(noPreview.previewChanged, isFalse);
  expect(noPreview.publicStateNeeded, isFalse);
  expect(noPreview.repaintTarget, PointerCleanupRepaintTarget.none);
}

void _verifyCleanupDispositions() {
  const coordinator = PointerToolCleanupCoordinator();

  final load = coordinator.cleanup(
    const PointerCleanupRequest(
      reason: PointerCleanupReason.preparedLoadSuccess,
      hasActiveToken: true,
      hasActiveSession: true,
      ownsPendingLine: true,
      hasPendingLine: true,
      hasPendingContextTap: true,
    ),
  );
  final interactiveFalse = coordinator.cleanup(
    const PointerCleanupRequest(
      reason: PointerCleanupReason.interactiveDisabled,
      hasPendingLine: true,
    ),
  );
  final dispose = coordinator.cleanup(
    const PointerCleanupRequest(reason: PointerCleanupReason.dispose),
  );

  expect(load.activeTokenReleased, isTrue);
  expect(load.sessionDisposition, PointerSessionDisposition.released);
  expect(load.pendingLineDisposition, PointerPendingLineDisposition.cleared);
  expect(
    load.pendingContextTapDisposition,
    PointerPendingContextTapDisposition.cleared,
  );
  expect(load.loadPreparedBeforeInstall, isTrue);
  expect(
    interactiveFalse.pendingLineDisposition,
    PointerPendingLineDisposition.preserved,
  );
  expect(dispose.disposeBeforeStreamClose, isTrue);
}

void _verifyResolverErrorNoAction() {
  const coordinator = PointerToolCleanupCoordinator();

  final outcome = coordinator.cleanup(
    const PointerCleanupRequest(
      reason: PointerCleanupReason.resolverError,
      activePreviewKind: PointerCleanupPreviewKind.selectedMove,
    ),
  );

  expect(outcome.previewChanged, isTrue);
  expect(outcome.actionEmissionAllowed, isFalse);
}
