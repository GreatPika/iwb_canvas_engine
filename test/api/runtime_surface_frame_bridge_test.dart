// ignore_for_file: missing-test-assertion

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/api/canvas_runtime_surface_bridge.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/surface_frame_signal.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

import '../support/runtime_root_with_committed_document_seed.dart';
import '../support/runtime_with_document.dart';

void main() {
  test(
    'surface port publishes state-matched layer targets for active surface',
    _surfacePortPublishesStateMatchedTargets,
  );
  test(
    'inactive runtime publication does not update surface frame signal',
    _inactiveRuntimePublicationDoesNotUpdateSurfaceFrameSignal,
  );
  test(
    'runtime maps preview and cleanup changes to surface repaint targets',
    _runtimeMapsPreviewAndCleanupChangesToSurfaceRepaintTargets,
  );
  test(
    'runtime maps selection resource load camera and unknown repaint targets',
    _runtimeMapsStateEffectsToSurfaceRepaintTargets,
  );
  test(
    'surface frame publication is not overwritten by reentrant state listeners',
    _surfaceFramePublicationRejectsReentrantStaleOverwrite,
  );
  test(
    'public state publication is not overwritten by reentrant surface listeners',
    _publicStatePublicationRejectsReentrantStaleOverwrite,
  );
  test(
    'text edit interaction state publishes conservative surface repaint target',
    _textEditInteractionPublishesConservativeSurfaceRepaintTarget,
  );
  test(
    'surface bridge does not expose frame repaint signal ownership',
    _surfaceBridgeDoesNotExposeFrameRepaintSignalOwnership,
  );
  test(
    'runtime state publication requires explicit surface target classification',
    _runtimeStatePublicationRequiresExplicitSurfaceTargetClassification,
  );
}

void _surfacePortPublishesStateMatchedTargets() {
  final runtime = runtimeWithDocument(_document());
  addTearDown(runtime.dispose);
  final port = canvasRuntimeSurfacePortFor(runtime);
  expect(port, isNotNull);
  final surfacePort = port as CanvasRuntimeSurfacePort;
  final token = Object();
  final frames = <CanvasRuntimeSurfaceFrame>[];
  surfacePort.attachSurface(token);
  surfacePort.surfaceFrame.addListener(() {
    final frame = surfacePort.surfaceFrame.value;
    if (frame != null) {
      frames.add(frame);
    }
  });

  runtime.selection.setSelection([CanvasElementId('rect-a')]);

  _expectSurfacePortFrameMatchesState(frames, runtime: runtime);
  _expectDetachedSurfacePortClearsFrame(runtime, surfacePort, token);
}

void _expectSurfacePortFrameMatchesState(
  List<CanvasRuntimeSurfaceFrame> frames, {
  required CanvasRuntime runtime,
}) {
  expect(frames, hasLength(1));
  _expectTarget(frames.single.repaintTarget, main: true, overlay: false);
  expect(frames.single.generation, 1);
  expect(frames.single.state, runtime.state.value);
}

void _expectDetachedSurfacePortClearsFrame(
  CanvasRuntime runtime,
  CanvasRuntimeSurfacePort surfacePort,
  Object token,
) {
  expect(surfacePort.detachSurface(token), isTrue);
  expect(surfacePort.surfaceFrame.value, isNull);
  runtime.camera.setOffset(const Offset(10, 11));
  expect(surfacePort.surfaceFrame.value, isNull);
  surfacePort.attachSurface(Object());
  expect(surfacePort.surfaceFrame.value, isNull);
}

void _inactiveRuntimePublicationDoesNotUpdateSurfaceFrameSignal() {
  final root = _runtimeRoot();
  final frames = _recordFrames(root);

  root.replaceInteractionPreview(
    const CanvasMarqueePreview(rect: Rect.fromLTWH(0, 0, 1, 1)),
  );
  expect(frames, isEmpty);

  final token = Object();
  root.attachSurface(token);
  root.detachSurface(token);
  root.setCameraOffset(const Offset(4, 5));
  expect(frames, isEmpty);

  root.dispose();
}

void _runtimeMapsPreviewAndCleanupChangesToSurfaceRepaintTargets() {
  final root = _runtimeRoot();
  final token = Object();
  root.attachSurface(token);
  final frames = _recordFrames(root);

  _expectOverlayPreviewTargets(root, frames);
  _expectSelectedMovePreviewTarget(root, frames);
  _expectNoPreviewStyleChangeIsSilent(root, frames);
  _expectPendingPreviewStyleChangeTargetsOverlay(root, frames);

  root.dispose();
}

void _expectOverlayPreviewTargets(
  RuntimeRoot root,
  List<RuntimeSurfaceFrameSignal> frames,
) {
  root.replaceInteractionPreview(
    const CanvasMarqueePreview(rect: Rect.fromLTWH(0, 0, 1, 1)),
  );
  _expectLastTarget(frames, main: false, overlay: true);

  root.replaceInteractionPreview(
    CanvasPencilStrokePreview(
      points: const [Offset(1, 1), Offset(2, 2)],
      color: const Color(0xFFAA0000),
      thickness: 2,
      opacity: 1,
    ),
  );
  _expectLastTarget(frames, main: false, overlay: true);

  root.replaceInteractionPreview(
    const CanvasLinePreview(
      start: Offset.zero,
      end: Offset(3, 3),
      color: Color(0xFF00AA00),
      thickness: 2,
    ),
  );
  _expectLastTarget(frames, main: false, overlay: true);

  root.replaceInteractionPreview(
    CanvasEraserPreview(corridor: const [Offset(1, 1)], thickness: 4),
  );
  _expectLastTarget(frames, main: false, overlay: true);
}

void _expectSelectedMovePreviewTarget(
  RuntimeRoot root,
  List<RuntimeSurfaceFrameSignal> frames,
) {
  final beforeSelectedMove = frames.length;
  root.replaceInteractionPreview(
    const CanvasSelectedMovePreview(delta: Offset(2, 3)),
  );
  expect(frames, hasLength(beforeSelectedMove + 2));
  _expectTargetAt(frames, beforeSelectedMove, main: false, overlay: true);
  _expectLastTarget(frames, main: true, overlay: false);
}

void _expectNoPreviewStyleChangeIsSilent(
  RuntimeRoot root,
  List<RuntimeSurfaceFrameSignal> frames,
) {
  final beforeNoPreviewStyleChange = frames.length;
  root.clearInteractionPreview();
  _expectLastTarget(frames, main: true, overlay: false);
  root.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.marker));
  expect(frames, hasLength(beforeNoPreviewStyleChange + 1));
}

void _expectPendingPreviewStyleChangeTargetsOverlay(
  RuntimeRoot root,
  List<RuntimeSurfaceFrameSignal> frames,
) {
  root.interactionEngine.storePendingLineStart(
    preview: const CanvasPendingLineStartPreview(
      start: Offset.zero,
      timestampMs: 1,
      color: Color(0xFF0000AA),
      thickness: 3,
    ),
    controllerEpoch: 0,
  );
  root.setDrawStyle(CanvasDrawStyle(tool: CanvasDrawTool.pencil));
  _expectLastTarget(frames, main: false, overlay: true);
}

void _runtimeMapsStateEffectsToSurfaceRepaintTargets() {
  final root = _runtimeRoot();
  final token = Object();
  root.attachSurface(token);
  final frames = _recordFrames(root);

  _expectSelectionAndResourceTargets(root, frames);
  _expectBothLayerRuntimeTargets(root, frames);

  expect(frames.map((frame) => frame.generation), [1, 2, 3, 4, 5, 6]);
  root.dispose();
}

void _expectSelectionAndResourceTargets(
  RuntimeRoot root,
  List<RuntimeSurfaceFrameSignal> frames,
) {
  root.selection.setSelection([CanvasElementId('rect-a')]);
  _expectLastTarget(frames, main: true, overlay: false);

  root.resources.markResourceDirty(CanvasResourceId('resource-a'));
  _expectLastTarget(frames, main: true, overlay: false);
}

void _expectBothLayerRuntimeTargets(
  RuntimeRoot root,
  List<RuntimeSurfaceFrameSignal> frames,
) {
  root.setCameraOffset(const Offset(8, 9));
  _expectLastTarget(frames, main: true, overlay: true);

  root.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(_document()));
  _expectLastTarget(frames, main: true, overlay: true);

  root.edits.edit((edit) {
    edit.replaceDraftDocument(_replacementDocument());
  });
  _expectLastTarget(frames, main: true, overlay: true);

  root.publishUnclassifiedRuntimeStateForTesting();
  _expectLastTarget(frames, main: true, overlay: true);
}

void _surfaceFramePublicationRejectsReentrantStaleOverwrite() {
  final root = _runtimeRoot();
  final token = Object();
  root.attachSurface(token);
  final frames = _recordFrames(root);
  var reentered = false;
  root.state.addListener(() {
    if (reentered) {
      return;
    }
    reentered = true;
    root.setCameraOffset(const Offset(13, 17));
  });

  root.selection.setSelection([CanvasElementId('rect-a')]);

  expect(frames, hasLength(2));
  _expectTargetAt(frames, 0, main: true, overlay: false);
  _expectTargetAt(frames, 1, main: true, overlay: true);
  expect(frames.last.state, root.state.value);
  expect(frames.last.generation, 2);
  root.dispose();
}

void _publicStatePublicationRejectsReentrantStaleOverwrite() {
  final root = _runtimeRoot();
  final token = Object();
  root.attachSurface(token);
  final frames = _recordFrames(root);
  var reentered = false;
  root.surfaceFrameSignal.addListener(() {
    if (reentered || root.surfaceFrameSignal.value == null) {
      return;
    }
    reentered = true;
    root.setCameraOffset(const Offset(21, 34));
  });

  root.selection.setSelection([CanvasElementId('rect-a')]);

  expect(frames, hasLength(2));
  _expectTargetAt(frames, 0, main: true, overlay: false);
  _expectTargetAt(frames, 1, main: true, overlay: true);
  expect(root.state.value, frames.last.state);
  expect(frames.last.generation, 2);
  root.dispose();
}

Future<void>
_textEditInteractionPublishesConservativeSurfaceRepaintTarget() async {
  final root = runtimeRootWithCommittedDocumentSeed(_textDocument());
  final requests = <CanvasContextActionRequested>[];
  final subscription = root.contextActionRequests.listen(requests.add);
  final token = Object();
  root.attachSurface(token);
  final frames = _recordFrames(root);
  try {
    root.handleDoubleTap(position: Offset.zero, timestampMs: 1);
    await Future<void>.delayed(Duration.zero);
    final request = requests.single;

    final session = root.textEditing.startFromContextAction(request);

    expect(session, isA<CanvasTextEditSession>());
    _expectLastTarget(frames, main: true, overlay: true);

    root.textEditing.dismissActive();
    _expectLastTarget(frames, main: true, overlay: true);
  } finally {
    await subscription.cancel();
    root.dispose();
  }
}

void _surfaceBridgeDoesNotExposeFrameRepaintSignalOwnership() {
  final source = File(
    'lib/src/api/canvas_runtime_surface_bridge.dart',
  ).readAsStringSync();

  expect(source, isNot(contains('frame_repaint_signal.dart')));
  expect(source, isNot(contains('FrameRepaintSignal')));
}

void _runtimeStatePublicationRequiresExplicitSurfaceTargetClassification() {
  final source = File('lib/src/runtime/runtime_root.dart').readAsStringSync();

  expect(
    source,
    contains('required _RuntimeSurfaceRepaintTarget? surfaceRepaintTarget'),
  );
  expect(source, isNot(contains('_publishRuntimeState();')));
  for (final match in '_publishRuntimeState('.allMatches(source)) {
    final callStart = match.start;
    if (source.indexOf('_publishRuntimeState({', callStart) == callStart) {
      continue;
    }
    final callEnd = source.indexOf(';', callStart);
    expect(callEnd, isNonNegative);
    final targetArgument = source.indexOf('surfaceRepaintTarget:', callStart);
    expect(targetArgument, isNonNegative);
    expect(targetArgument, lessThan(callEnd));
  }
}

List<RuntimeSurfaceFrameSignal> _recordFrames(RuntimeRoot root) {
  final frames = <RuntimeSurfaceFrameSignal>[];
  root.surfaceFrameSignal.addListener(() {
    final frame = root.surfaceFrameSignal.value;
    if (frame != null) {
      frames.add(frame);
    }
  });

  return frames;
}

void _expectLastTarget(
  List<RuntimeSurfaceFrameSignal> frames, {
  required bool main,
  required bool overlay,
}) {
  expect(frames, isNotEmpty);
  final frame = frames.last;
  expect(frame.state, isA<CanvasRuntimeState>());
  expect(frame.mainCanvas, main);
  expect(frame.overlayCanvas, overlay);
  expect(frame.reason, isNotEmpty);
}

void _expectTargetAt(
  List<RuntimeSurfaceFrameSignal> frames,
  int index, {
  required bool main,
  required bool overlay,
}) {
  final frame = frames[index];
  expect(frame.state, isA<CanvasRuntimeState>());
  expect(frame.mainCanvas, main);
  expect(frame.overlayCanvas, overlay);
  expect(frame.reason, isNotEmpty);
}

void _expectTarget(
  CanvasSurfaceRepaintTarget target, {
  required bool main,
  required bool overlay,
}) {
  expect(target.mainCanvas, main);
  expect(target.overlayCanvas, overlay);
  expect(target.reason, isNotEmpty);
}

RuntimeRoot _runtimeRoot() {
  return runtimeRootWithCommittedDocumentSeed(_document());
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(4, 4),
          ),
        ],
      ),
    ],
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('asset-a'),
      ),
    ],
  );
}

CanvasDocument _replacementDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('replacement-layer'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('replacement-rect'),
            size: const Size(8, 9),
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _textDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('text-layer'),
        elements: [
          CanvasTextElement(
            id: CanvasElementId('text-a'),
            text: 'hello',
            fontSize: 16,
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    ],
  );
}
