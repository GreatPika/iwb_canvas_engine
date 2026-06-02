import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

typedef _DrawPreviewStep = ({
  CanvasPointerLifecyclePhase phase,
  Offset position,
  List<Offset> expectedPoints,
});
typedef _DrawPreviewScenario = ({
  RuntimeRoot root,
  List<CanvasRuntimeState> snapshots,
  List<CanvasActionCommitted> actions,
});

void main() {
  test('preview-only changes publish only preview revision', () {
    expect(_verifyPreviewOnlyPublication, returnsNormally);
  });

  test('same preview value and empty cleanup stay public-state silent', () {
    expect(_verifySilentNoOpPreviewChanges, returnsNormally);
  });

  test('draw stroke previews publish only preview revision', () {
    expect(_verifyDrawStrokePreviewOnlyPublication, returnsNormally);
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

void _verifyDrawStrokePreviewOnlyPublication() {
  final scenario = _drawPreviewScenario();

  _expectDrawPreviewPublication(scenario, (
    phase: CanvasPointerLifecyclePhase.down,
    position: Offset.zero,
    expectedPoints: const [Offset.zero],
  ));
  _expectDrawPreviewPublication(scenario, (
    phase: CanvasPointerLifecyclePhase.move,
    position: const Offset(2, 3),
    expectedPoints: const [Offset.zero, Offset(2, 3)],
  ));
}

_DrawPreviewScenario _drawPreviewScenario() {
  final root = _drawRuntimeRoot();
  final actions = <CanvasActionCommitted>[];
  final actionSubscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await actionSubscription.cancel();
    root.dispose();
  });
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(
    CanvasDrawStyle(color: const Color(0xFFAA0000), pencilThickness: 5),
  );
  final snapshots = <CanvasRuntimeState>[];
  root.state.addListener(() {
    snapshots.add(root.state.value);
  });

  return (root: root, snapshots: snapshots, actions: actions);
}

RuntimeRoot _drawRuntimeRoot() {
  final root = RuntimeRoot(
    initialDocument: CanvasDocument(),
    config: const CanvasRuntimeConfig(),
  );
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(
    CanvasDrawStyle(color: const Color(0xFFAA0000), pencilThickness: 5),
  );

  return root;
}

void _expectDrawPreviewPublication(
  _DrawPreviewScenario scenario,
  _DrawPreviewStep step,
) {
  scenario.snapshots.clear();
  final before = scenario.root.state.value;

  scenario.root.handlePointer(_sample(step.phase, step.position));

  expect(scenario.snapshots, hasLength(1));
  _expectPencilPreview(scenario.root.preview, points: step.expectedPoints);
  _expectOnlyPreviewRevisionChanged(before, scenario.snapshots.single);
  expect(scenario.actions, isEmpty);
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

CanvasPointerSample _sample(
  CanvasPointerLifecyclePhase phase,
  Offset position,
) {
  return CanvasPointerSample(
    pointerId: 1,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
  );
}

void _expectPencilPreview(
  CanvasPreviewState preview, {
  required List<Offset> points,
}) {
  final pencil = preview as CanvasPencilStrokePreview;
  expect(pencil.points, points);
  expect(pencil.color, const Color(0xFFAA0000));
  expect(pencil.thickness, 5);
  expect(pencil.opacity, 1);
}
