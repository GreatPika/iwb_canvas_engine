import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/scene.dart';

import '../test_support/interactive_controller_fixtures.dart';

void main() {
  group('SceneController unit', () {
    group('interactive hardening: long gesture guardrails (eraser)', () {
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
              ContentLayer(id: 'layer-auto-0'),
              ContentLayer(
                id: 'layer-auto-1',
                nodes: <SceneNode>[startLine, endLine],
              ),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.eraser);
        controller.interaction.eraserThickness = 24;

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(20, 50),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 21; i <= 9000; i++) {
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 50),
              timestampMs: i,
              phase: CanvasPointerPhase.move,
            ),
          );
        }
        controller.interaction.handlePointer(
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
              ContentLayer(id: 'layer-auto-2'),
              ContentLayer(id: 'layer-auto-3', nodes: nodes),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.eraser);
        controller.interaction.eraserThickness = 20;

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i <= gestureLength; i++) {
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }
        controller.interaction.handlePointer(
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
              ContentLayer(id: 'layer-auto-4'),
              ContentLayer(id: 'layer-auto-5', nodes: nodes),
            ],
          ),
        );
        addTearDown(controller.dispose);

        controller.interaction.setMode(CanvasMode.draw);
        controller.interaction.setDrawTool(DrawTool.eraser);
        controller.interaction.eraserThickness = 20;

        controller.interaction.handlePointer(
          sampleInput(
            pointerId: 1,
            position: const Offset(0, 0),
            timestampMs: 1,
            phase: CanvasPointerPhase.down,
          ),
        );
        for (var i = 1; i <= gestureLength; i++) {
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: Offset(i.toDouble(), 0),
              timestampMs: i + 1,
              phase: CanvasPointerPhase.move,
            ),
          );
        }

        final stopwatch = Stopwatch()..start();
        controller.interaction.handlePointer(
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

        expect(
          spatialQueryCount,
          lessThanOrEqualTo(expectedBatchQueryUpperBound),
        );
        expect(preciseChecks, lessThan(500000));
        expect(stopwatch.elapsedMilliseconds, lessThan(2500));
      });

      test(
        'eraser projected point count is exposed through internal access',
        () {
          final controller = controllerFromScene(
            Scene(
              layers: <ContentLayer>[
                ContentLayer(id: 'layer-auto-projected-0'),
                ContentLayer(
                  id: 'layer-auto-projected-1',
                  nodes: <SceneNode>[
                    horizontalStroke(
                      id: 'projected-hit',
                      y: 0,
                      length: 120,
                      step: 30,
                      thickness: 2,
                    ),
                  ],
                ),
              ],
            ),
          );
          addTearDown(controller.dispose);

          controller.interaction.setMode(CanvasMode.draw);
          controller.interaction.setDrawTool(DrawTool.eraser);
          controller.interaction.eraserThickness = 20;

          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 7,
              position: const Offset(0, 0),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 7,
              position: const Offset(120, 0),
              timestampMs: 2,
              phase: CanvasPointerPhase.up,
            ),
          );

          expect(eraserProjectedPointCount(controller), greaterThan(0));
        },
      );

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
                ContentLayer(id: 'layer-auto-6'),
                ContentLayer(
                  id: 'layer-auto-7',
                  nodes: <SceneNode>[targetNear, targetCross, safeFar, safeLow],
                ),
              ],
            ),
          );
          addTearDown(controller.dispose);

          controller.interaction.setMode(CanvasMode.draw);
          controller.interaction.setDrawTool(DrawTool.eraser);
          controller.interaction.eraserThickness = 14;

          controller.interaction.handlePointer(
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
            controller.interaction.handlePointer(
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
                ContentLayer(id: 'layer-auto-8'),
                ContentLayer(
                  id: 'layer-auto-9',
                  nodes: <SceneNode>[nonHitStroke, aboveStroke],
                ),
              ],
            ),
          );
          addTearDown(controller.dispose);

          controller.interaction.setMode(CanvasMode.draw);
          controller.interaction.setDrawTool(DrawTool.eraser);
          controller.interaction.eraserThickness = 1;

          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(0, 0),
              timestampMs: 1,
              phase: CanvasPointerPhase.down,
            ),
          );
          controller.interaction.handlePointer(
            sampleInput(
              pointerId: 1,
              position: const Offset(100, 0),
              timestampMs: 2,
              phase: CanvasPointerPhase.move,
            ),
          );
          controller.interaction.handlePointer(
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
    });
  });
}
