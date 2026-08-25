import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  test('runtime cleanup does not advance next draw output timestamp', () async {
    var verifiedPaths = 0;
    for (final cleanupPath in _cleanupTimestampPaths) {
      await _expectNextPendingTimestampZeroAfter(cleanupPath);
      verifiedPaths += 1;
    }

    expect(verifiedPaths, _cleanupTimestampPaths.length);
  });

  test('public tool terminal cleanup is output and timestamp silent', () async {
    await expectLater(_expectPublicToolTerminalCleanupSilent(), completes);
  });
}

final _cleanupTimestampPaths = <void Function(RuntimeRoot root)>[
  _loadSuccessCleanup,
  _loadFailure,
  _interactiveFalseCleanup,
  _settingChangeCleanup,
  _cancelCleanup,
  _noOpTerminal,
];

Future<void> _expectNextPendingTimestampZeroAfter(
  void Function(RuntimeRoot root) cleanupPath,
) async {
  final scenario = _CleanupTimestampScenario();
  addTearDown(scenario.dispose);

  cleanupPath(scenario.root);
  _startLineFirstTap(scenario.root);
  await Future<void>.delayed(Duration.zero);

  final preview = scenario.root.preview as CanvasPendingLineStartPreview;
  expect(preview.timestampMs, 0);
  expect(scenario.actions, isEmpty);
  expect(scenario.requests, isEmpty);
}

Future<void> _expectPublicToolTerminalCleanupSilent() async {
  final scenario = _CleanupTimestampScenario();
  addTearDown(scenario.dispose);

  _startPencilPreviewThroughTools(scenario.root);
  scenario.root.tools.handlePointer(
    CanvasPointerTerminalCleanup(
      pointerId: 1,
      phase: CanvasPointerLifecyclePhase.up,
      kind: PointerDeviceKind.touch,
      timestampMs: 99,
    ),
  );
  await Future<void>.delayed(Duration.zero);

  expect(scenario.root.preview, isA<CanvasNoPreview>());
  expect(scenario.actions, isEmpty);
  expect(scenario.requests, isEmpty);
  expect(scenario.effectBatches, isEmpty);

  _startLineFirstTap(scenario.root);
  await Future<void>.delayed(Duration.zero);

  final preview = scenario.root.preview as CanvasPendingLineStartPreview;
  expect(preview.timestampMs, 0);
  expect(scenario.actions, isEmpty);
  expect(scenario.requests, isEmpty);
  expect(scenario.effectBatches, isEmpty);
}

void _loadSuccessCleanup(RuntimeRoot root) {
  _startPencilPreview(root);
  root.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(CanvasDocument()));
}

void _loadFailure(RuntimeRoot root) {
  _startPencilPreview(root);
  final before = root.state.value;
  expect(
    () => root.edits.loadDocumentFromJson(
      encodeCanvasDocumentToJson(_invalidReplacementDocument()),
    ),
    throwsA(isA<CanvasDataException>()),
  );
  expect(root.state.value, before);
  expect(root.preview, isA<CanvasPencilStrokePreview>());
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.cancel, Offset.zero));
}

void _interactiveFalseCleanup(RuntimeRoot root) {
  _startPencilPreview(root);
  root.handleSurfaceInteractiveDisabled();
}

void _settingChangeCleanup(RuntimeRoot root) {
  _startPencilPreview(root);
  root.setDrawStyle(
    CanvasDrawStyle(
      tool: CanvasDrawTool.marker,
      color: const Color(0xFF445566),
      markerThickness: 8,
    ),
  );
}

void _cancelCleanup(RuntimeRoot root) {
  _startPencilPreview(root);
  root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.cancel, const Offset(1, 1), 20),
  );
}

void _noOpTerminal(RuntimeRoot root) {
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.up, Offset.zero, 20));
}

void _startPencilPreview(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(CanvasDrawStyle.defaultStyle);
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, Offset.zero));
  expect(root.preview, isA<CanvasPencilStrokePreview>());
}

void _startPencilPreviewThroughTools(RuntimeRoot root) {
  root.tools.setMode(CanvasInteractionMode.draw);
  root.tools.setDrawStyle(CanvasDrawStyle.defaultStyle);
  root.tools.handlePointer(
    _sample(CanvasPointerLifecyclePhase.down, Offset.zero),
  );
  expect(root.preview, isA<CanvasPencilStrokePreview>());
}

void _startLineFirstTap(RuntimeRoot root) {
  root.setInteractionMode(CanvasInteractionMode.draw);
  root.setDrawStyle(
    CanvasDrawStyle(tool: CanvasDrawTool.line, lineThickness: 4),
  );
  root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.down, const Offset(1, 2)),
  );
  root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.up, const Offset(1, 2)),
  );
}

CanvasPointerSample _sample(
  CanvasPointerLifecyclePhase phase,
  Offset position, [
  int? timestampMs,
]) {
  return CanvasPointerSample(
    pointerId: 1,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
    timestampMs: timestampMs,
  );
}

CanvasDocument _invalidReplacementDocument() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('bad-layer'),
        elements: [
          CanvasRectElement(id: CanvasElementId('dup'), size: const Size(1, 1)),
          CanvasRectElement(id: CanvasElementId('dup'), size: const Size(2, 2)),
        ],
      ),
    ],
  );
}

final class _CleanupTimestampScenario {
  _CleanupTimestampScenario() {
    actionSubscription = root.actions.listen(actions.add);
    requestSubscription = root.contextActionRequests.listen(requests.add);
  }

  late final root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(),
    commitEffectObserver: effectBatches.add,
  );
  final actions = <CanvasActionCommitted>[];
  final requests = <CanvasContextActionRequested>[];
  final effectBatches = <List<CommitDeliveryEffect>>[];
  late final StreamSubscription<CanvasActionCommitted> actionSubscription;
  late final StreamSubscription<CanvasContextActionRequested>
  requestSubscription;

  Future<void> dispose() async {
    await actionSubscription.cancel();
    await requestSubscription.cancel();
    root.dispose();
  }
}
