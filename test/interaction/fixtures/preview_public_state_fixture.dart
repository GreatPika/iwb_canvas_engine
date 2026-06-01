import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('preview-only changes publish only preview revision', () {
    expect(_verifyPreviewOnlyPublication, returnsNormally);
  });

  test('same preview value and empty cleanup stay public-state silent', () {
    expect(_verifySilentNoOpPreviewChanges, returnsNormally);
  });
}

void _verifyPreviewOnlyPublication() {
  final root = RuntimeRoot(
    initialDocument: CanvasDocument(),
    config: const CanvasRuntimeConfig(),
  );
  final actions = <CanvasActionCommitted>[];
  final actionSubscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await actionSubscription.cancel();
    root.dispose();
  });
  final snapshots = <CanvasRuntimeState>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });
  final before = root.state.value;

  final didChange = root.replaceInteractionPreview(
    const CanvasSelectedMovePreview(delta: Offset(3, 4)),
  );

  expect(didChange, isTrue);
  _expectSelectedMovePreview(root.preview);
  expect(snapshots, hasLength(1));
  _expectOnlyPreviewRevisionChanged(before, snapshots.single);
  expect(actions, isEmpty);
}

void _expectSelectedMovePreview(CanvasPreviewState preview) {
  expect(
    preview,
    isA<CanvasSelectedMovePreview>().having(
      (selectedMove) => selectedMove.delta,
      'delta',
      const Offset(3, 4),
    ),
  );
}

void _verifySilentNoOpPreviewChanges() {
  final root = RuntimeRoot(
    initialDocument: CanvasDocument(),
    config: const CanvasRuntimeConfig(),
  );
  addTearDown(root.dispose);
  final snapshots = <CanvasRuntimeState>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });

  expect(root.clearInteractionPreview(), isFalse);
  expect(snapshots, isEmpty);

  expect(
    root.replaceInteractionPreview(
      const CanvasSelectedMovePreview(delta: Offset(3, 4)),
    ),
    isTrue,
  );
  snapshots.clear();
  final beforeSameValue = root.state.value;
  expect(
    root.replaceInteractionPreview(
      const CanvasSelectedMovePreview(delta: Offset(3, 4)),
    ),
    isFalse,
  );
  expect(snapshots, isEmpty);
  expect(root.state.value, beforeSameValue);

  expect(root.clearInteractionPreview(), isTrue);
  expect(snapshots, hasLength(1));
  _expectOnlyPreviewRevisionChanged(beforeSameValue, snapshots.single);
}

void _expectOnlyPreviewRevisionChanged(
  CanvasRuntimeState before,
  CanvasRuntimeState after,
) {
  expect(after.revisions.document, before.revisions.document);
  expect(after.revisions.selection, before.revisions.selection);
  expect(after.revisions.resourceVisual, before.revisions.resourceVisual);
  expect(after.revisions.interaction, before.revisions.interaction);
  expect(after.revisions.viewCamera, before.revisions.viewCamera);
  expect(after.revisions.epoch, before.revisions.epoch);
  expect(after.revisions.preview, before.revisions.preview + 1);
  expect(after.summary, before.summary);
}
