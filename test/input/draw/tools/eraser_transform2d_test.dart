import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/legacy_api.dart';

void main() {
  const eraserThickness = 3.0;
  const strokeThickness = 3.0;
  const distanceWorldFar = 3.0;
  const distanceWorldNear = 0.5;

  const p1x = 20.0;
  const p2x = 40.0;

  void eraseWithThreePoints(SceneController controller, double y) {
    controller.handlePointer(
      PointerSample(
        pointerId: 1,
        position: Offset(0, y),
        timestampMs: 0,
        phase: PointerPhase.down,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 1,
        position: Offset(p1x, y),
        timestampMs: 10,
        phase: PointerPhase.move,
      ),
    );
    controller.handlePointer(
      PointerSample(
        pointerId: 1,
        position: Offset(p2x, y),
        timestampMs: 20,
        phase: PointerPhase.up,
      ),
    );
  }

  SceneController controllerWithSingleNode(SceneNode node) {
    final scene = Scene(
      layers: [
        Layer(nodes: [node]),
      ],
    );
    final controller = SceneController(scene: scene, dragStartSlop: 0);
    controller.setMode(CanvasMode.draw);
    controller.setDrawTool(DrawTool.eraser);
    controller.eraserThickness = eraserThickness;
    return controller;
  }

  Layer firstNonBackgroundLayer(Scene scene) =>
      scene.layers.firstWhere((layer) => !layer.isBackground);

  void expectEraseResult({
    required String name,
    required SceneNode Function() buildNode,
    required bool shouldErase,
    required double eraserY,
  }) {
    test(name, () {
      final controller = controllerWithSingleNode(buildNode());
      addTearDown(controller.dispose);

      eraseWithThreePoints(controller, eraserY);

      final nodes = firstNonBackgroundLayer(controller.scene).nodes;
      if (shouldErase) {
        expect(nodes, isEmpty);
      } else {
        expect(nodes, hasLength(1));
      }
    });
  }

  Transform2D tScale01() {
    return Transform2D.trs(
      translation: const Offset(20, 0),
      scaleX: 0.1,
      scaleY: 0.1,
    );
  }

  Transform2D tScale01Rot45() {
    return Transform2D.trs(
      translation: const Offset(20, 0),
      rotationDeg: 45,
      scaleX: 0.1,
      scaleY: 0.1,
    );
  }

  Transform2D tAniso2x05() {
    return Transform2D.trs(
      translation: const Offset(20, 0),
      scaleX: 2,
      scaleY: 0.5,
    );
  }

  LineNode lineNode(Transform2D transform) {
    return LineNode(
      id: 'line',
      start: const Offset(-10, 0),
      end: const Offset(10, 0),
      thickness: strokeThickness,
      color: const Color(0xFF000000),
      transform: transform,
    );
  }

  StrokeNode strokeNode(Transform2D transform) {
    return StrokeNode(
      id: 'stroke',
      points: const [Offset(-10, 0), Offset(10, 0)],
      thickness: strokeThickness,
      color: const Color(0xFF000000),
      transform: transform,
    );
  }

  for (final entry in <({String name, Transform2D Function() build})>[
    (name: 'scale=0.1', build: tScale01),
    (name: 'scale=0.1 rot=45', build: tScale01Rot45),
    (name: 'scaleX=2 scaleY=0.5', build: tAniso2x05),
  ]) {
    final caseName = entry.name;

    expectEraseResult(
      name: 'eraser does not delete LineNode ($caseName) when far',
      buildNode: () => lineNode(entry.build()),
      shouldErase: false,
      eraserY: distanceWorldFar,
    );
    expectEraseResult(
      name: 'eraser deletes LineNode ($caseName) when near',
      buildNode: () => lineNode(entry.build()),
      shouldErase: true,
      eraserY: distanceWorldNear,
    );

    expectEraseResult(
      name: 'eraser does not delete StrokeNode ($caseName) when far',
      buildNode: () => strokeNode(entry.build()),
      shouldErase: false,
      eraserY: distanceWorldFar,
    );
    expectEraseResult(
      name: 'eraser deletes StrokeNode ($caseName) when near',
      buildNode: () => strokeNode(entry.build()),
      shouldErase: true,
      eraserY: distanceWorldNear,
    );
  }
}
