import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/commit_delivery.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

const _marqueeDragStart = Offset(-20, -20);
const _marqueeBacktrackSteps = [
  (position: Offset(-15, -20), rect: Rect.fromLTRB(-20, -20, -15, -20)),
  (position: Offset(-18, -20), rect: Rect.fromLTRB(-20, -20, -18, -20)),
  (position: Offset(-20, -20), rect: Rect.fromLTRB(-20, -20, -20, -20)),
  (position: Offset(-22, -20), rect: Rect.fromLTRB(-22, -20, -20, -20)),
];

void main() {
  _testMarqueeAdmissionAndPreview();
  _testMarqueeDragStartSlopControlsFirstPreview();
  _testMarqueeDragStartSlopFallbackUsesTapSlop();
  _testMarqueeContinuesInsideSlopAfterPreviewStart();
  _testSameRectMoveKeepsPreviewRevision();
  _testPointClickSelectsTopmostObject();
  _testPointClickJitterSelectsTopmostOnly();
  _testPointClickSelectsLine();
  _testUnchangedSelectionCleansWithoutAction();
  _testChangedSelectionCommitsAndEmitsAction();
  _testDeletedCandidateIsSkipped();
}

void _testMarqueeAdmissionAndPreview() {
  test('marquee admits empty-canvas drag and publishes overlay preview', () {
    final root = _runtimeRoot();
    addTearDown(root.dispose);

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.down, const Offset(-20, -20)),
    );
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(15, 10)),
    );

    final session = root.interactionEngine.activeSession;
    expect(session, isNotNull);
    final preview = root.preview as CanvasMarqueePreview;
    expect(preview.rect, const Rect.fromLTRB(-20, -20, 15, 10));
    expect(root.state.value.revisions.preview, 1);
  });
}

void _testMarqueeDragStartSlopControlsFirstPreview() {
  test('marquee dragStartSlop controls the first visible preview', () {
    final root = _runtimeRoot(
      config: CanvasRuntimeConfig(
        pointerPolicy: CanvasPointerPolicy(tapSlop: 16, dragStartSlop: 4),
      ),
    );
    addTearDown(root.dispose);

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.down, const Offset(-20, -20)),
    );
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(-16, -20)),
    );
    expect(root.preview, isA<CanvasNoPreview>());

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(-15, -20)),
    );
    final preview = root.preview as CanvasMarqueePreview;
    expect(preview.rect, const Rect.fromLTRB(-20, -20, -15, -20));
  });
}

void _testMarqueeDragStartSlopFallbackUsesTapSlop() {
  test('marquee dragStartSlop null falls back to tapSlop', () {
    final root = _runtimeRoot(
      config: CanvasRuntimeConfig(
        pointerPolicy: CanvasPointerPolicy(tapSlop: 8),
      ),
    );
    addTearDown(root.dispose);

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.down, const Offset(-20, -20)),
    );
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(-12, -20)),
    );
    expect(root.preview, isA<CanvasNoPreview>());

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(-11, -20)),
    );
    final preview = root.preview as CanvasMarqueePreview;
    expect(preview.rect, const Rect.fromLTRB(-20, -20, -11, -20));
  });
}

void _testMarqueeContinuesInsideSlopAfterPreviewStart() {
  test('marquee keeps preview live when crossing back through start', () {
    expect(_marqueeBacktrackSteps, hasLength(4));
    final root = _runtimeRoot(
      config: CanvasRuntimeConfig(
        pointerPolicy: CanvasPointerPolicy(tapSlop: 16, dragStartSlop: 4),
      ),
    );
    addTearDown(root.dispose);

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.down, _marqueeDragStart),
    );

    for (final step in _marqueeBacktrackSteps) {
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.move, step.position),
      );
      _expectMarqueePreviewRect(root, step.rect);
    }
  });
}

void _testSameRectMoveKeepsPreviewRevision() {
  test('marquee same-rect move stays private before drag threshold', () {
    final root = _runtimeRoot();
    addTearDown(root.dispose);

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.down, const Offset(-5, -5)),
    );
    final beforeSameRectState = root.state.value;
    final previewRevision = root.interactionEngine.previewRevision;
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(-5, -5)),
    );

    expect(root.interactionEngine.previewRevision, previewRevision);
    expect(root.state.value, same(beforeSameRectState));
    expect(root.preview, isA<CanvasNoPreview>());
  });
}

void _testPointClickSelectsTopmostObject() {
  test('move-mode point click selects the topmost hit object', () async {
    final scenario = _scenario();
    final root = scenario.root;

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.down, const Offset(5, 5)),
    );
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.up, const Offset(5, 5)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(root.preview, isA<CanvasNoPreview>());
    expect(root.interactionEngine.activeSession, isNull);
    expect(root.selection.selectedElementIds, {CanvasElementId('a')});
    expect(scenario.actions.single.elementIds, [CanvasElementId('a')]);
  });
}

void _testPointClickJitterSelectsTopmostOnly() {
  test(
    'move-mode point click with jitter selects only the topmost hit',
    () async {
      final scenario = _overlappingScenario();
      final root = scenario.root;

      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.down, const Offset(5, 5)),
      );
      root.handlePointer(
        _sample(CanvasPointerLifecyclePhase.up, const Offset(6, 5)),
      );
      await Future<void>.delayed(Duration.zero);

      expect(root.selection.selectedElementIds, {CanvasElementId('top')});
      expect(scenario.actions.single.elementIds, [CanvasElementId('top')]);
    },
  );
}

void _testPointClickSelectsLine() {
  test('move-mode point click selects line hits', () async {
    final scenario = _lineScenario();
    final root = scenario.root;

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.down, const Offset(5, 0)),
    );
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.up, const Offset(5, 0)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(root.selection.selectedElementIds, {CanvasElementId('line-a')});
    expect(scenario.actions.single.elementIds, [CanvasElementId('line-a')]);
  });
}

void _testUnchangedSelectionCleansWithoutAction() {
  test('marquee unchanged selection cleans preview without action', () async {
    final scenario = _scenario();
    final root = scenario.root;
    root.selection.setSelection([CanvasElementId('a')]);

    _dragMarquee(root, start: const Offset(-20, -20), end: const Offset(5, 5));
    await Future<void>.delayed(Duration.zero);

    expect(root.preview, isA<CanvasNoPreview>());
    expect(root.interactionEngine.activeSession, isNull);
    expect(root.selection.selectedElementIds, {CanvasElementId('a')});
    expect(scenario.actions, isEmpty);
  });
}

void _testChangedSelectionCommitsAndEmitsAction() {
  test(
    'marquee changed selection commits replacement and typed action',
    () async {
      final scenario = _scenario();
      final root = scenario.root;
      root.selection.setSelection([CanvasElementId('a')]);
      expect(root.projectionBuildCount, 0);

      _dragMarquee(
        root,
        start: const Offset(-20, -20),
        end: const Offset(55, 12),
        timestampMs: 17,
      );
      await Future<void>.delayed(Duration.zero);

      expect(root.preview, isA<CanvasNoPreview>());
      expect(root.interactionEngine.activeSession, isNull);
      expect(root.selection.selectedElementIds, {
        CanvasElementId('a'),
        CanvasElementId('b'),
        CanvasElementId('locked'),
      });
      expect(root.projectionBuildCount, 0);
      _expectMarqueeAction(scenario.actions.single);
      _expectMarqueeCommitRepaintsMainAndOverlay(scenario.effectBatches.single);
    },
  );
}

void _testDeletedCandidateIsSkipped() {
  test('marquee skips elements deleted before terminal commit', () async {
    final scenario = _scenario();
    final root = scenario.root;

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.down, const Offset(-20, -20)),
    );
    root.edits.edit((edit) => edit.removeElement(CanvasElementId('b')));
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.up, const Offset(25, 12)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(root.selection.selectedElementIds, {CanvasElementId('a')});
    final action = scenario.actions.single;
    expect(action.elementIds, [CanvasElementId('a')]);
  });
}

void _expectMarqueeAction(CanvasActionCommitted action) {
  expect(action.type, CanvasActionType.selectMarquee);
  expect(action.elementIds, [
    CanvasElementId('a'),
    CanvasElementId('b'),
    CanvasElementId('locked'),
  ]);
  expect(action.timestampMs, 17);
  final payload = action.payload as CanvasSelectionActionPayload;
  expect(payload.previousSelection, [CanvasElementId('a')]);
  expect(payload.nextSelection, [
    CanvasElementId('a'),
    CanvasElementId('b'),
    CanvasElementId('locked'),
  ]);
  expect(payload.marqueeRectWorld, const Rect.fromLTRB(-20, -20, 55, 12));
}

void _expectMarqueeCommitRepaintsMainAndOverlay(
  List<CommitDeliveryEffect> effects,
) {
  final repaint = effects.whereType<RepaintDeliveryEffect>().single;
  expect(repaint.mainCanvas, isTrue);
  expect(repaint.overlayCanvas, isTrue);
}

void _expectMarqueePreviewRect(RuntimeRoot root, Rect rect) {
  expect((root.preview as CanvasMarqueePreview).rect, rect);
}

_MarqueeScenario _scenario() {
  final effectBatches = <List<CommitDeliveryEffect>>[];
  final root = _runtimeRoot(commitEffectObserver: effectBatches.add);
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  return _MarqueeScenario(
    root: root,
    actions: actions,
    effectBatches: effectBatches,
  );
}

_MarqueeScenario _overlappingScenario() {
  final root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [
            CanvasRectElement(
              id: CanvasElementId('lower'),
              size: const Size(20, 20),
            ),
            CanvasRectElement(
              id: CanvasElementId('top'),
              size: const Size(20, 20),
            ),
          ],
        ),
      ],
    ),
    config: const CanvasRuntimeConfig(),
  );
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  return _MarqueeScenario(
    root: root,
    actions: actions,
    effectBatches: const [],
  );
}

_MarqueeScenario _lineScenario() {
  final root = runtimeRootWithCommittedDocumentSeed(
    CanvasDocument(
      layers: [
        CanvasLayer(
          id: CanvasLayerId('layer-a'),
          elements: [
            CanvasLineElement(
              id: CanvasElementId('line-a'),
              start: Offset.zero,
              end: const Offset(10, 0),
              color: const Color(0xFF111111),
              thickness: 3,
            ),
          ],
        ),
      ],
    ),
    config: const CanvasRuntimeConfig(),
  );
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  return _MarqueeScenario(
    root: root,
    actions: actions,
    effectBatches: const [],
  );
}

void _dragMarquee(
  RuntimeRoot root, {
  required Offset start,
  required Offset end,
  int? timestampMs,
}) {
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.down, start));
  root.handlePointer(_sample(CanvasPointerLifecyclePhase.move, end));
  root.handlePointer(
    _sample(CanvasPointerLifecyclePhase.up, end, timestampMs: timestampMs),
  );
}

RuntimeRoot _runtimeRoot({
  CanvasRuntimeConfig? config,
  void Function(List<CommitDeliveryEffect> effects)? commitEffectObserver,
}) {
  return runtimeRootWithCommittedDocumentSeed(
    _document(),
    config: config ?? const CanvasRuntimeConfig(),
    commitEffectObserver: commitEffectObserver,
  );
}

CanvasPointerSample _sample(
  CanvasPointerLifecyclePhase phase,
  Offset position, {
  int? timestampMs,
}) {
  return CanvasPointerSample(
    pointerId: 1,
    position: position,
    phase: phase,
    kind: PointerDeviceKind.touch,
    timestampMs: timestampMs,
  );
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(id: CanvasElementId('a'), size: const Size(10, 10)),
          CanvasRectElement(
            id: CanvasElementId('b'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(20, 0)),
          ),
          CanvasRectElement(
            id: CanvasElementId('locked'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(40, 0)),
            isLocked: true,
          ),
          CanvasRectElement(
            id: CanvasElementId('hidden'),
            size: const Size(10, 10),
            transform: CanvasTransform.translation(const Offset(45, 0)),
            isVisible: false,
          ),
        ],
      ),
    ],
  );
}

final class _MarqueeScenario {
  const _MarqueeScenario({
    required this.root,
    required this.actions,
    required this.effectBatches,
  });

  final RuntimeRoot root;
  final List<CanvasActionCommitted> actions;
  final List<List<CommitDeliveryEffect>> effectBatches;
}
