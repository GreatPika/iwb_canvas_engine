import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  _testMarqueeAdmissionAndPreview();
  _testSameRectMoveKeepsPreviewRevision();
  _testUnchangedSelectionCleansWithoutAction();
  _testChangedSelectionCommitsAndEmitsAction();
  _testDeletedCandidateIsSkipped();
}

void _testMarqueeAdmissionAndPreview() {
  test('marquee admits non-selected hit and publishes overlay preview', () {
    final root = _runtimeRoot();
    addTearDown(root.dispose);

    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.down, const Offset(-5, -5)),
    );
    root.handlePointer(
      _sample(CanvasPointerLifecyclePhase.move, const Offset(15, 10)),
    );

    final session = root.interactionEngine.activeSession;
    expect(session, isNotNull);
    final preview = root.preview as CanvasMarqueePreview;
    expect(preview.rect, const Rect.fromLTRB(-5, -5, 15, 10));
    expect(root.state.value.revisions.preview, 2);
  });
}

void _testSameRectMoveKeepsPreviewRevision() {
  test('marquee same-rect move is a preview no-op', () {
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
    final preview = root.preview as CanvasMarqueePreview;
    expect(preview.rect, const Rect.fromLTRB(-5, -5, -5, -5));
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
      _expectMarqueeAction(scenario.actions.single);
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

_MarqueeScenario _scenario() {
  final root = _runtimeRoot();
  final actions = <CanvasActionCommitted>[];
  final subscription = root.actions.listen(actions.add);
  addTearDown(() async {
    await subscription.cancel();
    root.dispose();
  });

  return _MarqueeScenario(root: root, actions: actions);
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

RuntimeRoot _runtimeRoot() {
  return RuntimeRoot(
    initialDocument: _document(),
    config: const CanvasRuntimeConfig(),
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
  const _MarqueeScenario({required this.root, required this.actions});

  final RuntimeRoot root;
  final List<CanvasActionCommitted> actions;
}
