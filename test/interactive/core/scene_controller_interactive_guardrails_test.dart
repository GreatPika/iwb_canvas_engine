import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneControllerInteractive unit', () {
    group('interactive hardening: long gesture guardrails', () {
      test('pen commit caps very long stroke and preserves endpoints', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.pen);
        controller.penThickness = 2;

        const totalRawPoints = 20050;
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i < totalRawPoints - 1; i++) {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: Offset((totalRawPoints - 1).toDouble(), 0),
            timestampMs: totalRawPoints + 1,
            phase: CanvasPointerPhase.up,
          ),
        );

        final strokeSnap = controller.snapshot.layers
            .expand((layer) => layer.nodes)
            .whereType<StrokeNodeSnapshot>()
            .single;
        expect(strokeSnap.points.length, 20000);
        expect(strokeSnap.points.first, const Offset(0, 0));
        expect(
          strokeSnap.points.last,
          Offset((totalRawPoints - 1).toDouble(), 0),
        );
      });

      test('pen preview buffer is soft-capped during long move', () {
        // INV:INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.pen);

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );

        for (var i = 1; i <= 26000; i++) {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        expect(controller.hasActiveStrokePreview, isTrue);
        expect(
          controller.activeStrokePreviewPoints.length,
          lessThanOrEqualTo(interactiveStrokePointsSoftLimit),
        );
      });

      test('soft-capped stroke preview keeps endpoints after pruning', () {
        // INV:INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.pen);

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );

        const latestPoint = Offset(26000, 0);
        for (var i = 1; i <= latestPoint.dx; i++) {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        expect(controller.activeStrokePreviewPoints, isNotEmpty);
        expect(controller.activeStrokePreviewPoints.first, const Offset(0, 0));
        expect(controller.activeStrokePreviewPoints.last, latestPoint);
      });

      test(
        'highlighter long preview and commit keep soft-limit and endpoints',
        () async {
          // INV:INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP
          final controller = SceneControllerInteractive(
            initialSnapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(),
                ContentLayerSnapshot(),
              ],
            ),
          );
          addTearDown(controller.dispose);

          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.highlighter);
          controller.highlighterThickness = 7;
          controller.highlighterOpacity = 0.35;

          final actions = <ActionCommitted>[];
          final sub = controller.actions.listen(actions.add);
          addTearDown(sub.cancel);

          const latestPoint = Offset(26000, 0);
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(0, 0),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          for (var i = 1; i <= latestPoint.dx; i++) {
            controller.handlePointer(
              sampleInput(
                pointerId: 1,
                position: Offset(i.toDouble(), 0),
                timestampMs: i + 1,
                phase: CanvasPointerPhase.move,
              ),
            );
          }
          expect(
            controller.activeStrokePreviewPoints.length,
            lessThanOrEqualTo(interactiveStrokePointsSoftLimit),
          );
          expect(
            controller.activeStrokePreviewPoints.first,
            const Offset(0, 0),
          );
          expect(controller.activeStrokePreviewPoints.last, latestPoint);

          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: latestPoint,
              timestampMs: 26002,
              phase: CanvasPointerPhase.up,
            ),
          );
          await pumpEventQueue();

          expect(
            actions.where((a) => a.type == ActionType.drawHighlighter),
            hasLength(1),
          );
          final strokeSnap = controller.snapshot.layers
              .expand((layer) => layer.nodes)
              .whereType<StrokeNodeSnapshot>()
              .single;
          expect(strokeSnap.points.first, const Offset(0, 0));
          expect(strokeSnap.points.last, latestPoint);
          expect(strokeSnap.points.length, lessThanOrEqualTo(20000));
          expect(strokeSnap.opacity, closeTo(0.35, 1e-6));
        },
      );

      test('eraser long gesture remains bounded and erases near both ends', () {
        final startLine = LineNode(
          id: 'line-start',
          start: const Offset(-12, 0),
          end: const Offset(12, 0),
          thickness: 2,
          color: const Color(0xFF000000),
        )..position = const Offset(20, 50);
        final endLine = LineNode(
          id: 'line-end',
          start: const Offset(-12, 0),
          end: const Offset(12, 0),
          thickness: 2,
          color: const Color(0xFF000000),
        )..position = const Offset(9000, 50);

        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[startLine, endLine]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);
        controller.eraserThickness = 24;

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(20, 50),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 21; i <= 9000; i++) {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 50),
              timestampMs: i,
              phase: CanvasPointerPhase.move,
            ),
          );
        }
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(9000, 50),
            timestampMs: 9001,
            phase: CanvasPointerPhase.up,
          ),
        );

        final ids = <NodeId>{
          for (final layer in controller.snapshot.layers)
            for (final node in layer.nodes) node.id,
        };
        expect(ids.contains('line-start'), isFalse);
        expect(ids.contains('line-end'), isFalse);
      });

      test('long eraser stress keeps correctness on dense scene', () {
        const gestureLength = 4096;
        final nodes = <SceneNode>[];
        for (var i = 0; i < 40; i++) {
          final y = i.isEven ? 0.0 : 12.0;
          nodes.add(
            horizontalStroke(
              id: 'stroke-$i',
              y: y,
              length: gestureLength.toDouble(),
              step: 8,
              thickness: 2,
            ),
          );
        }
        for (var i = 0; i < 20; i++) {
          nodes.add(
            horizontalStroke(
              id: 'far-$i',
              y: 220 + i.toDouble(),
              length: gestureLength.toDouble(),
              step: 8,
              thickness: 2,
            ),
          );
        }

        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: nodes),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);
        controller.eraserThickness = 20;

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i <= gestureLength; i++) {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: Offset(gestureLength.toDouble(), 0),
            timestampMs: gestureLength + 2,
            phase: CanvasPointerPhase.up,
          ),
        );

        final ids = <NodeId>{
          for (final layer in controller.snapshot.layers)
            for (final node in layer.nodes) node.id,
        };
        for (var i = 0; i < 40; i++) {
          expect(
            ids.contains('stroke-$i'),
            i.isEven ? isFalse : isTrue,
            reason: 'stroke-$i',
          );
        }
        for (var i = 0; i < 20; i++) {
          expect(ids.contains('far-$i'), isTrue, reason: 'far-$i');
        }
      });

      test('long eraser commit keeps bounded query/check complexity', () {
        const gestureLength = 4096;
        final nodes = <SceneNode>[];
        for (var i = 0; i < 32; i++) {
          final y = i.isEven ? 0.0 : 12.0;
          nodes.add(
            horizontalStroke(
              id: 'stress-$i',
              y: y,
              length: gestureLength.toDouble(),
              step: 8,
              thickness: 2,
            ),
          );
        }

        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: nodes),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);
        controller.eraserThickness = 20;

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i <= gestureLength; i++) {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        final stopwatch = Stopwatch()..start();
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: Offset(gestureLength.toDouble(), 0),
            timestampMs: gestureLength + 2,
            phase: CanvasPointerPhase.up,
          ),
        );
        stopwatch.stop();

        final spatialQueryCount = eraserSpatialQueryCount(controller);
        final preciseChecks = eraserPreciseSegmentCheckCount(controller);
        final expectedBatchQueryUpperBound = (gestureLength / 64).ceil() + 2;

        // Deterministic perf guards are primary acceptance criteria.
        expect(
          spatialQueryCount,
          lessThanOrEqualTo(expectedBatchQueryUpperBound),
        );
        expect(preciseChecks, lessThan(500000));
        // Wall-clock bound is a secondary smoke guard only; if CI is noisy,
        // deterministic counters above remain source-of-truth for regressions.
        expect(stopwatch.elapsedMilliseconds, lessThan(2500));
      });

      test(
        'eraser zigzag path keeps coarse prefilter correctness and bounded checks',
        () {
          const zigzagLength = 2000.0;
          const int zigzagPoints = 200;
          final zigzag = List<Offset>.generate(zigzagPoints, (index) {
            final x = zigzagLength * index / (zigzagPoints - 1);
            final y = index.isEven ? -8.0 : 8.0;
            return Offset(x, y);
          }, growable: false);

          final targetNear = StrokeNode(
            id: 'zigzag-target-near',
            points: const <Offset>[Offset(100, 0), Offset(1900, 0)],
            thickness: 2,
            color: const Color(0xFF000000),
          );
          final targetCross = StrokeNode(
            id: 'zigzag-target-cross',
            points: const <Offset>[Offset(1000, -30), Offset(1000, 30)],
            thickness: 2,
            color: const Color(0xFF000000),
          );
          final safeFar = StrokeNode(
            id: 'zigzag-safe-far',
            points: const <Offset>[Offset(100, 80), Offset(1900, 80)],
            thickness: 2,
            color: const Color(0xFF000000),
          );
          final safeLow = StrokeNode(
            id: 'zigzag-safe-low',
            points: const <Offset>[Offset(100, -80), Offset(1900, -80)],
            thickness: 2,
            color: const Color(0xFF000000),
          );

          final controller = controllerFromScene(
            Scene(
              layers: <ContentLayer>[
                ContentLayer(),
                ContentLayer(
                  nodes: <SceneNode>[targetNear, targetCross, safeFar, safeLow],
                ),
              ],
            ),
          );
          addTearDown(controller.dispose);

          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.eraser);
          controller.eraserThickness = 14;

          controller.handlePointer(
            sampleInput(
              pointerId: 11,
              position: zigzag.first,
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          for (var i = 1; i < zigzag.length; i++) {
            final phase = i == zigzag.length - 1
                ? CanvasPointerPhase.up
                : CanvasPointerPhase.move;
            controller.handlePointer(
              sampleInput(
                pointerId: 11,
                position: zigzag[i],
                timestampMs: i + 1,
                phase: phase,
              ),
            );
          }

          final ids = <NodeId>{
            for (final layer in controller.snapshot.layers)
              for (final node in layer.nodes) node.id,
          };
          expect(ids.contains('zigzag-target-near'), isFalse);
          expect(ids.contains('zigzag-target-cross'), isFalse);
          expect(ids.contains('zigzag-safe-far'), isTrue);
          expect(ids.contains('zigzag-safe-low'), isTrue);

          final preciseChecks = eraserPreciseSegmentCheckCount(controller);
          final spatialQueries = eraserSpatialQueryCount(controller);
          expect(preciseChecks, lessThan(15000));
          expect(
            spatialQueries,
            lessThanOrEqualTo((zigzagPoints / 64).ceil() + 2),
          );
        },
      );

      test(
        'eraser stroke coarse prefilter runs batched checks for non-hit geometry',
        () {
          final nonHitStroke = StrokeNode(
            id: 'non-hit',
            points: const <Offset>[
              Offset(0, 100),
              Offset(0, 200),
              Offset(100, 200),
            ],
            thickness: 1,
            color: const Color(0xFF000000),
          );
          final aboveStroke = StrokeNode(
            id: 'above',
            points: const <Offset>[Offset(0, -3), Offset(100, -3)],
            thickness: 1,
            color: const Color(0xFF000000),
          );
          final controller = controllerFromScene(
            Scene(
              layers: <ContentLayer>[
                ContentLayer(),
                ContentLayer(nodes: <SceneNode>[nonHitStroke, aboveStroke]),
              ],
            ),
          );
          addTearDown(controller.dispose);

          controller.setMode(CanvasMode.draw);
          controller.setDrawTool(DrawTool.eraser);
          controller.eraserThickness = 1;

          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(0, 0),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(100, 0),
              timestampMs: 2,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(100, 100),
              timestampMs: 3,
              phase: CanvasPointerPhase.up,
            ),
          );

          final ids = <NodeId>{
            for (final layer in controller.snapshot.layers)
              for (final node in layer.nodes) node.id,
          };
          expect(ids.contains('non-hit'), isTrue);
          expect(ids.contains('above'), isTrue);
          expect(eraserPreciseSegmentCheckCount(controller), greaterThan(0));
        },
      );

      test('long eraser gesture does not throw', () {
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);

        expect(() {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(0, 0),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          for (var i = 1; i <= 20000; i++) {
            controller.handlePointer(
              sampleInput(
                pointerId: 1,
                position: Offset(i.toDouble(), 0),
                timestampMs: i + 1,
                phase: CanvasPointerPhase.move,
              ),
            );
          }
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(20000, 0),
              timestampMs: 20002,
              phase: CanvasPointerPhase.up,
            ),
          );
        }, returnsNormally);
      });

      test('long eraser gesture cancel does not mutate scene', () async {
        // INV:INV-ENG-INTERACTIVE-CANCEL-STATE-RESET
        final startLine = LineNode(
          id: 'cancel-line-start',
          start: const Offset(-12, 0),
          end: const Offset(12, 0),
          thickness: 2,
          color: const Color(0xFF000000),
        )..position = const Offset(20, 50);
        final endLine = LineNode(
          id: 'cancel-line-end',
          start: const Offset(-12, 0),
          end: const Offset(12, 0),
          thickness: 2,
          color: const Color(0xFF000000),
        )..position = const Offset(9000, 50);
        final controller = controllerFromScene(
          Scene(
            layers: <ContentLayer>[
              ContentLayer(),
              ContentLayer(nodes: <SceneNode>[startLine, endLine]),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);
        controller.eraserThickness = 24;

        final actions = <ActionCommitted>[];
        final sub = controller.actions.listen(actions.add);
        addTearDown(sub.cancel);

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(20, 50),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 21; i <= 9000; i++) {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 50),
              timestampMs: i,
              phase: CanvasPointerPhase.move,
            ),
          );
        }
        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(9000, 50),
            timestampMs: 9001,
            phase: CanvasPointerPhase.cancel,
          ),
        );

        await pumpEventQueue();
        final ids = <NodeId>{
          for (final layer in controller.snapshot.layers)
            for (final node in layer.nodes) node.id,
        };
        expect(ids.contains('cancel-line-start'), isTrue);
        expect(ids.contains('cancel-line-end'), isTrue);
        expect(
          actions.where((event) => event.type == ActionType.erase),
          isEmpty,
        );
      });

      test('invalid soft-limit config throws ArgumentError', () {
        // INV:INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        final points = <Offset>[const Offset(0, 0), const Offset(1, 0)];

        expect(
          () => enforceGestureBufferSoftLimitForTest(
            controller,
            points: points,
            softLimit: 10,
            trimTo: 1,
          ),
          throwsArgumentError,
        );
        expect(
          () => enforceGestureBufferSoftLimitForTest(
            controller,
            points: points,
            softLimit: 5,
            trimTo: 5,
          ),
          throwsArgumentError,
        );
        expect(
          () => enforceGestureBufferSoftLimitForTest(
            controller,
            points: points,
            softLimit: 1,
            trimTo: 1,
          ),
          throwsArgumentError,
        );
      });

      test('eraser active buffer is capped during long move', () {
        // INV:INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP
        final controller = SceneControllerInteractive(
          initialSnapshot: SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(),
              ContentLayerSnapshot(),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.setMode(CanvasMode.draw);
        controller.setDrawTool(DrawTool.eraser);

        controller.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i <= 20000; i++) {
          controller.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        expect(
          activeEraserPointsLength(controller),
          lessThanOrEqualTo(interactiveEraserPointsSoftLimit),
        );
      });
    });

    test('stroke preview is available during drag and clears on up', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
      final controller = SceneControllerInteractive(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(),
            ContentLayerSnapshot(),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.highlighter);
      controller.highlighterThickness = 8;
      controller.highlighterOpacity = 0.3;

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      expect(controller.hasActiveStrokePreview, isTrue);
      expect(controller.activeStrokePreviewPoints, const <Offset>[
        Offset(10, 10),
      ]);
      expect(controller.activeStrokePreviewThickness, 8);
      expect(controller.activeStrokePreviewOpacity, 0.3);

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(14, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );
      expect(controller.activeStrokePreviewPoints.length, 2);

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(14, 10),
          timestampMs: 3,
          phase: CanvasPointerPhase.up,
        ),
      );
      expect(controller.hasActiveStrokePreview, isFalse);
      expect(controller.activeStrokePreviewPoints, isEmpty);
    });

    test('line preview does not mutate scene until pointer up commit', () {
      // INV:INV-ENG-INTERACTIVE-PREVIEW-COMMIT-ON-UP
      final controller = SceneControllerInteractive(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(),
            ContentLayerSnapshot(),
          ],
        ),
        dragStartSlop: 10,
      );
      addTearDown(controller.dispose);

      controller.setMode(CanvasMode.draw);
      controller.setDrawTool(DrawTool.line);

      final beforeNodeCount = controller.snapshot.layers[1].nodes.length;
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(10, 10),
          timestampMs: 1,
          phase: CanvasPointerPhase.down,
        ),
      );
      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(30, 10),
          timestampMs: 2,
          phase: CanvasPointerPhase.move,
        ),
      );

      expect(controller.hasActiveLinePreview, isTrue);
      expect(controller.snapshot.layers[1].nodes.length, beforeNodeCount);

      controller.handlePointer(
        sampleInput(
          pointerId: 1,
          position: const Offset(30, 10),
          timestampMs: 3,
          phase: CanvasPointerPhase.up,
        ),
      );

      expect(controller.hasActiveLinePreview, isFalse);
      expect(controller.snapshot.layers[1].nodes.length, beforeNodeCount + 1);
    });
  });
}
