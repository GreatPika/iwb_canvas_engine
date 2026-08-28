import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

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
typedef _LinePreviewStep = ({
  CanvasPointerLifecyclePhase phase,
  Offset position,
  void Function(CanvasPreviewState preview) expectPreview,
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

  test('draw line previews publish only preview revision', () {
    expect(_verifyDrawLinePreviewOnlyPublication, returnsNormally);
  });

  test('drag-start draw line previews publish only preview revision', () {
    expect(_verifyDragStartDrawLinePreviewOnlyPublication, returnsNormally);
  });

  test('eraser previews publish only preview revision', () {
    expect(_verifyEraserPreviewOnlyPublication, returnsNormally);
  });

  test('post-resample eraser preview remains isolated', () {
    expect(_verifyPostResampleEraserPreviewIsolation, returnsNormally);
  });
}

void _verifyPreviewOnlyPublication() {
  final root = runtimeRootWithCommittedDocumentSeed(CanvasDocument());
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
  final root = runtimeRootWithCommittedDocumentSeed(CanvasDocument());
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

void _verifyDrawLinePreviewOnlyPublication() {
  final scenario = _linePreviewScenario();

  scenario.root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
  );
  expect(scenario.snapshots, isEmpty);
  scenario.root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.up, Offset.zero),
  );
  expect(scenario.snapshots, hasLength(1));
  _expectPendingLineStartPreview(scenario.root.preview);
  expect(scenario.actions, isEmpty);

  _expectLinePreviewPublication(scenario, (
    phase: CanvasPointerLifecyclePhase.down,
    position: const Offset(2, 3),
    expectPreview: _expectInitialLinePreview,
  ));
  _expectLinePreviewPublication(scenario, (
    phase: CanvasPointerLifecyclePhase.move,
    position: const Offset(4, 5),
    expectPreview: _expectMovedLinePreview,
  ));
}

void _verifyDragStartDrawLinePreviewOnlyPublication() {
  final scenario = _linePreviewScenario();

  scenario.root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
  );
  expect(scenario.snapshots, isEmpty);

  _expectLinePreviewPublication(scenario, (
    phase: CanvasPointerLifecyclePhase.move,
    position: const Offset(18, 2),
    expectPreview: _expectDraggedLinePreview,
  ));
}

void _verifyEraserPreviewOnlyPublication() {
  final scenario = _eraserPreviewScenario();

  _expectEraserPreviewPublication(
    scenario,
    CanvasPointerLifecyclePhase.down,
    Offset.zero,
    const [Offset.zero],
  );
  _expectEraserPreviewPublication(
    scenario,
    CanvasPointerLifecyclePhase.move,
    const Offset(3, 4),
    const [Offset.zero, Offset(3, 4)],
  );
}

// This one gesture retains the exact public-state comparison across overflow.
// The full preview-only sequence must compare every owner before and after the
// same overflow transition; splitting it would obscure the isolation boundary.
// ignore: halstead-volume, source-lines-of-code
void _verifyPostResampleEraserPreviewIsolation() {
  final scenario = _eraserPreviewScenario();
  final surface = Object();
  scenario.root.attachSurface(surface);
  addTearDown(() => scenario.root.detachSurface(surface));
  scenario.root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
  );
  scenario.root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.move, const Offset(3, 4)),
  );
  scenario.snapshots.clear();
  final before = scenario.root.state.value;
  final beforeSpatial = scenario.root.spatialKernel.snapshot;
  final beforeProjectionBuilds = scenario.root.projectionBuildCount;
  final frames = <RuntimeSurfaceFrameSignal?>[];
  scenario.root.surfaceFrameSignal.addListener(() {
    frames.add(scenario.root.surfaceFrameSignal.value);
  });

  for (var index = 2; index <= 8000; index += 1) {
    scenario.root.handlePointer(
      _sample(
        CanvasPointerLifecyclePhase.move,
        Offset((index % 24).toDouble(), ((index * 7) % 24).toDouble()),
      ),
    );
  }

  final preview = scenario.root.preview as CanvasEraserPreview;
  expect(preview.corridor, hasLength(4000));
  expect(scenario.snapshots, isNotEmpty);
  _expectOnlyPreviewRevisionChanged(
    before,
    scenario.snapshots.last,
    previewDelta: 7999,
  );
  expect(scenario.root.projectionBuildCount, beforeProjectionBuilds);
  _expectSpatialSnapshotUnchanged(
    beforeSpatial,
    scenario.root.spatialKernel.snapshot,
  );
  expect(scenario.actions, isEmpty);
  expect(frames, isNotEmpty);
  expect(frames.last?.mainCanvas, isFalse);
  expect(frames.last?.overlayCanvas, isTrue);
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
  final root = runtimeRootWithCommittedDocumentSeed(CanvasDocument());
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(
    CanvasDrawStyle(color: const Color(0xFFAA0000), pencilThickness: 5),
  );

  return root;
}

_DrawPreviewScenario _linePreviewScenario() {
  final root = runtimeRootWithCommittedDocumentSeed(CanvasDocument());
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.line,
      color: const Color(0xFF00AAFF),
      lineThickness: 4,
    ),
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

  return (root: root, snapshots: snapshots, actions: actions);
}

_DrawPreviewScenario _eraserPreviewScenario() {
  final root = runtimeRootWithCommittedDocumentSeed(CanvasDocument());
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(
    CanvasDrawStyle(tool: CanvasDrawTool.eraser, eraserThickness: 6),
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

  return (root: root, snapshots: snapshots, actions: actions);
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

void _expectLinePreviewPublication(
  _DrawPreviewScenario scenario,
  _LinePreviewStep step,
) {
  scenario.snapshots.clear();
  final before = scenario.root.state.value;

  scenario.root.handlePointer(_sample(step.phase, step.position));

  expect(scenario.snapshots, hasLength(1));
  step.expectPreview(scenario.root.preview);
  _expectOnlyPreviewRevisionChanged(before, scenario.snapshots.single);
  expect(scenario.actions, isEmpty);
}

void _expectEraserPreviewPublication(
  _DrawPreviewScenario scenario,
  CanvasPointerLifecyclePhase phase,
  Offset position,
  List<Offset> expectedCorridor,
) {
  scenario.snapshots.clear();
  final before = scenario.root.state.value;
  final beforeSpatial = scenario.root.spatialKernel.snapshot;

  scenario.root.handlePointer(_sample(phase, position));

  expect(scenario.snapshots, hasLength(1));
  final preview = scenario.root.preview as CanvasEraserPreview;
  expect(preview.corridor, expectedCorridor);
  expect(preview.thickness, 6);
  _expectOnlyPreviewRevisionChanged(before, scenario.snapshots.single);
  _expectSpatialSnapshotUnchanged(
    beforeSpatial,
    scenario.root.spatialKernel.snapshot,
  );
  expect(scenario.actions, isEmpty);
}

void _expectSpatialSnapshotUnchanged(
  SpatialKernelSnapshot before,
  SpatialKernelSnapshot after,
) {
  expect(after.structuralRevision, before.structuralRevision);
  expect(after.isInvalid, before.isInvalid);
  expect(after.entryCount, before.entryCount);
  expect(after.hitTilePageCount, before.hitTilePageCount);
  expect(after.paintTilePageCount, before.paintTilePageCount);
  expect(after.contextTilePageCount, before.contextTilePageCount);
  expect(after.hitOutlierCount, before.hitOutlierCount);
  expect(after.paintOutlierCount, before.paintOutlierCount);
  expect(after.contextOutlierCount, before.contextOutlierCount);
}

void _expectPendingLineStartPreview(CanvasPreviewState preview) {
  final pending = preview as CanvasPendingLineStartPreview;
  expect(pending.start, Offset.zero);
  expect(pending.timestampMs, 0);
  expect(pending.color, const Color(0xFF00AAFF));
  expect(pending.thickness, 4);
}

void _expectInitialLinePreview(CanvasPreviewState preview) {
  _expectLinePreview(preview, end: const Offset(2, 3));
}

void _expectMovedLinePreview(CanvasPreviewState preview) {
  _expectLinePreview(preview, end: const Offset(4, 5));
}

void _expectDraggedLinePreview(CanvasPreviewState preview) {
  _expectLinePreview(preview, end: const Offset(18, 2));
}

void _expectLinePreview(CanvasPreviewState preview, {required Offset end}) {
  final line = preview as CanvasLinePreview;
  expect(line.start, Offset.zero);
  expect(line.end, end);
  expect(line.color, const Color(0xFF00AAFF));
  expect(line.thickness, 4);
}

void _expectOnlyPreviewRevisionChanged(
  CanvasRuntimeState before,
  CanvasRuntimeState after, {
  int previewDelta = 1,
}) {
  expect(after.revisions.document, before.revisions.document);
  expect(after.revisions.selection, before.revisions.selection);
  expect(after.revisions.resourceVisual, before.revisions.resourceVisual);
  expect(after.revisions.interaction, before.revisions.interaction);
  expect(after.revisions.viewCamera, before.revisions.viewCamera);
  expect(after.revisions.epoch, before.revisions.epoch);
  expect(after.revisions.preview, before.revisions.preview + previewDelta);
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
