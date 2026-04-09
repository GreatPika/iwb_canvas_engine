import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contract/pointer_input.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneController unit', () {
    test('line tool supports drag flow and two-tap pending flow', () async {
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-0'),
            ContentLayerSnapshot(id: 'layer-auto-1'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final actions = <ActionCommitted>[];
      final sub = controller.actions.listen(actions.add);
      addTearDown(sub.cancel);

      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.line);
      controller.interaction.setDragStartSlop(0.001);

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(20, 20),
          timestampMs: 10,
          phase: CanvasPointerPhase.down,
        ),
      );
      expect(controller.interaction.hasActiveLinePreview, isFalse);
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(50, 20),
          timestampMs: 11,
          phase: CanvasPointerPhase.move,
        ),
      );
      expect(controller.interaction.hasActiveLinePreview, isTrue);
      expect(
        controller.interaction.activeLinePreviewStart,
        const Offset(20, 20),
      );
      expect(controller.interaction.activeLinePreviewEnd, const Offset(50, 20));
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(60, 20),
          timestampMs: 12,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.interaction.hasActiveLinePreview, isFalse);
      expect(controller.interaction.hasPendingLineStart, isFalse);

      final dragLine = controller.snapshot.layers
          .expand((layer) => layer.nodes)
          .whereType<LineNodeSnapshot>()
          .first;
      expect(dragLine.transform.tx, 40);
      expect(dragLine.transform.ty, 20);
      expect(dragLine.start, const Offset(-20, 0));
      expect(dragLine.end, const Offset(20, 0));
      expect(
        dragLine.transform.applyToPoint(dragLine.start),
        const Offset(20, 20),
      );
      expect(
        dragLine.transform.applyToPoint(dragLine.end),
        const Offset(60, 20),
      );

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(100, 100),
          timestampMs: 30,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 2,
          position: const Offset(100, 100),
          timestampMs: 31,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.interaction.hasPendingLineStart, isTrue);
      expect(controller.interaction.pendingLineTimestampMs, 31);

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 20,
          position: const Offset(220, 220),
          timestampMs: 32,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 20,
          position: const Offset(280, 220),
          timestampMs: 33,
          phase: CanvasPointerPhase.move,
        ),
      );
      expect(controller.interaction.hasActiveLinePreview, isTrue);
      expect(
        controller.interaction.activeLinePreviewStart,
        const Offset(220, 220),
      );
      expect(
        controller.interaction.activeLinePreviewEnd,
        const Offset(280, 220),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 20,
          position: const Offset(280, 220),
          timestampMs: 34,
          phase: CanvasPointerPhase.up,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 3,
          position: const Offset(130, 130),
          timestampMs: 40,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 3,
          position: const Offset(130, 130),
          timestampMs: 41,
          phase: CanvasPointerPhase.up,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 4,
          position: const Offset(150, 150),
          timestampMs: 50,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 4,
          position: const Offset(150, 150),
          timestampMs: 51,
          phase: CanvasPointerPhase.up,
        ),
      );
      controller.interaction.setDrawTool(DrawTool.pen);
      expect(controller.interaction.hasPendingLineStart, isFalse);

      await pumpEventQueue();
      expect(
        actions.where((a) => a.type == ActionType.drawLine).length,
        greaterThanOrEqualTo(2),
      );
      final lines = controller.snapshot.layers
          .expand((layer) => layer.nodes)
          .whereType<LineNodeSnapshot>();
      expect(
        lines.any((line) {
          final worldStart = line.transform.applyToPoint(line.start);
          final worldEnd = line.transform.applyToPoint(line.end);
          return worldStart == const Offset(130, 130) &&
              worldEnd == const Offset(150, 150);
        }),
        isTrue,
      );

      controller.interaction.setMode(CanvasMode.move);
      controller.selection.toggleSelection('missing');
      controller.selection.clearSelection();
      controller.selection.selectAll(onlySelectable: false);
      expect(controller.selectedNodeIds, isNotEmpty);
    });

    test(
      'line preview and pending commit keep captured style and do not cross owners',
      () {
        // INV:INV-ENG-INTERACTIVE-DRAW-STYLE-SNAPSHOT
        final controller = SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-20'),
              ContentLayerSnapshot(id: 'layer-auto-21'),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.line);
        controller.interaction.lineThickness = 5;
        controller.interaction.setDrawColor(const Color(0xFF224466));
        controller.interaction.setDragStartSlop(0.001);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(20, 20),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(40, 20),
            timestampMs: 2,
            phase: CanvasPointerPhase.move,
          ),
        );

        controller.interaction.lineThickness = 11;
        controller.interaction.setDrawColor(const Color(0xFFAA3300));

        expect(controller.interaction.hasActiveLinePreview, isTrue);
        expect(controller.interaction.activeLinePreviewThickness, 5);
        expect(
          controller.interaction.activeLinePreviewColor,
          const Color(0xFF224466),
        );

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(50, 20),
            timestampMs: 3,
            phase: CanvasPointerPhase.up,
          ),
        );

        controller.interaction.lineThickness = 7;
        controller.interaction.setDrawColor(const Color(0xFF0055AA));
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(100, 100),
            timestampMs: 10,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(100, 100),
            timestampMs: 11,
            phase: CanvasPointerPhase.up,
          ),
        );

        controller.interaction.lineThickness = 13;
        controller.interaction.setDrawColor(const Color(0xFFAA0055));
        expect(
          controller.interaction.pendingLineColor,
          const Color(0xFF0055AA),
        );
        expect(controller.interaction.pendingLineThickness, 7);
        final session = sceneControllerViewRuntimeOf(controller)
            .createPointerSession(
              isMounted: () => true,
              hasLiveRawPointers: () => false,
            );
        addTearDown(session.dispose);
        session.handleRoutedSample(
          const PointerSample(
            pointerId: 3,
            position: Offset(140, 140),
            timestampMs: 12,
            phase: PointerPhase.down,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: false,
        );
        session.handleRoutedSample(
          const PointerSample(
            pointerId: 3,
            position: Offset(140, 140),
            timestampMs: 13,
            phase: PointerPhase.up,
            kind: PointerDeviceKind.touch,
          ),
          shouldTrackSignals: false,
        );

        expect(controller.interaction.hasPendingLineStart, isTrue);
        expect(controller.interaction.pendingLineStart, const Offset(140, 140));
        expect(controller.interaction.pendingLineTimestampMs, 13);
        expect(
          controller.interaction.pendingLineColor,
          const Color(0xFFAA0055),
        );
        expect(controller.interaction.pendingLineThickness, 13);

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 4,
            position: const Offset(180, 180),
            timestampMs: 14,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 4,
            position: const Offset(180, 180),
            timestampMs: 15,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(controller.interaction.hasPendingLineStart, isTrue);
        expect(controller.interaction.pendingLineStart, const Offset(180, 180));
        expect(controller.interaction.pendingLineTimestampMs, 15);
        expect(
          controller.interaction.pendingLineColor,
          const Color(0xFFAA0055),
        );
        expect(controller.interaction.pendingLineThickness, 13);

        controller.interaction.lineThickness = 19;
        controller.interaction.setDrawColor(const Color(0xFF00AA55));
        expect(
          controller.interaction.pendingLineColor,
          const Color(0xFFAA0055),
        );
        expect(controller.interaction.pendingLineThickness, 13);
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 5,
            position: const Offset(220, 220),
            timestampMs: 16,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 5,
            position: const Offset(220, 220),
            timestampMs: 17,
            phase: CanvasPointerPhase.up,
          ),
        );

        final lines = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<LineNodeSnapshot>()
            .toList();
        expect(lines, hasLength(2));
        expect(controller.interaction.pendingLineColor, isNull);
        expect(controller.interaction.pendingLineThickness, isNull);

        final draggedLine = lines.firstWhere(
          (line) =>
              line.transform.applyToPoint(line.start) == const Offset(20, 20) &&
              line.transform.applyToPoint(line.end) == const Offset(50, 20),
        );
        expect(draggedLine.thickness, 5);
        expect(draggedLine.color, const Color(0xFF224466));

        final tappedLine = lines.firstWhere(
          (line) =>
              line.transform.applyToPoint(line.start) ==
                  const Offset(180, 180) &&
              line.transform.applyToPoint(line.end) == const Offset(220, 220),
        );
        expect(tappedLine.thickness, 13);
        expect(tappedLine.color, const Color(0xFFAA0055));
      },
    );

    test('foreign drag commit preserves pending line for its owner', () {
      final controller = SceneController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-30'),
            ContentLayerSnapshot(id: 'layer-auto-31'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.interaction.setMode(CanvasMode.draw);
      controller.interaction.setDrawTool(DrawTool.line);
      controller.interaction.setDragStartSlop(0.001);

      final session = sceneControllerViewRuntimeOf(controller)
          .createPointerSession(
            isMounted: () => true,
            hasLiveRawPointers: () => false,
          );
      addTearDown(session.dispose);
      session.handleRoutedSample(
        const PointerSample(
          pointerId: 10,
          position: Offset(40, 40),
          timestampMs: 1,
          phase: PointerPhase.down,
          kind: PointerDeviceKind.touch,
        ),
        shouldTrackSignals: false,
      );
      session.handleRoutedSample(
        const PointerSample(
          pointerId: 10,
          position: Offset(40, 40),
          timestampMs: 2,
          phase: PointerPhase.up,
          kind: PointerDeviceKind.touch,
        ),
        shouldTrackSignals: false,
      );

      expect(controller.interaction.pendingLineStart, const Offset(40, 40));
      expect(controller.interaction.pendingLineTimestampMs, 2);

      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(100, 100),
          timestampMs: 3,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(130, 100),
          timestampMs: 4,
          phase: CanvasPointerPhase.move,
        ),
      );
      controller.interaction.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(150, 100),
          timestampMs: 5,
          phase: CanvasPointerPhase.up,
        ),
      );

      expect(controller.interaction.hasPendingLineStart, isTrue);
      expect(controller.interaction.pendingLineStart, const Offset(40, 40));
      expect(controller.interaction.pendingLineTimestampMs, 2);

      session.handleRoutedSample(
        const PointerSample(
          pointerId: 11,
          position: Offset(80, 80),
          timestampMs: 6,
          phase: PointerPhase.down,
          kind: PointerDeviceKind.touch,
        ),
        shouldTrackSignals: false,
      );
      session.handleRoutedSample(
        const PointerSample(
          pointerId: 11,
          position: Offset(80, 80),
          timestampMs: 7,
          phase: PointerPhase.up,
          kind: PointerDeviceKind.touch,
        ),
        shouldTrackSignals: false,
      );

      final lines = controller.snapshot.layers
          .expand((layer) => layer.nodes)
          .whereType<LineNodeSnapshot>()
          .toList();
      expect(lines, hasLength(2));

      expect(controller.interaction.hasPendingLineStart, isFalse);
      expect(
        lines.any(
          (line) =>
              line.transform.applyToPoint(line.start) ==
                  const Offset(100, 100) &&
              line.transform.applyToPoint(line.end) == const Offset(150, 100),
        ),
        isTrue,
      );
      expect(
        lines.any(
          (line) =>
              line.transform.applyToPoint(line.start) == const Offset(40, 40) &&
              line.transform.applyToPoint(line.end) == const Offset(80, 80),
        ),
        isTrue,
      );
    });

    test(
      'pen commit adds up-point and eraser single point hits stroke segment',
      () {
        final controller = SceneController(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-2'),
              ContentLayerSnapshot(id: 'layer-auto-3'),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.pen);
        controller.interaction.penThickness = 2;
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(10, 10),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(13, 10),
            timestampMs: 2,
            phase: CanvasPointerPhase.up,
          ),
        );

        final strokeSnap = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<StrokeNodeSnapshot>()
            .single;
        expect(strokeSnap.points.length, 2);

        controller.interaction.setDrawTool(DrawTool.eraser);
        controller.interaction.eraserThickness = 20;
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(11, 10),
            timestampMs: 3,
            phase: CanvasPointerPhase.down,
          ),
        );
        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 2,
            position: const Offset(11, 10),
            timestampMs: 4,
            phase: CanvasPointerPhase.up,
          ),
        );

        expect(
          controller.snapshot.layers
              .expand((layer) => layer.nodes)
              .whereType<StrokeNodeSnapshot>(),
          isEmpty,
        );
      },
    );
  });
}
