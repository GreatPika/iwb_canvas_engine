import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';
import 'package:iwb_canvas_engine/src/input/internal/selection_geometry.dart';

void main() {
  test(
    'selectedTransformableNodesInSceneOrder ignores background ids from selection',
    () {
      // INV:INV-INPUT-BACKGROUND-NONINTERACTIVE-NONDELETABLE
      final backgroundNode = RectNode(
        id: 'bg',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      )..position = const Offset(0, 0);
      final foregroundNode = RectNode(
        id: 'fg',
        size: const Size(10, 10),
        fillColor: const Color(0xFF000000),
      )..position = const Offset(10, 0);

      final scene = Scene(
        layers: [
          Layer(isBackground: true, nodes: [backgroundNode]),
          Layer(nodes: [foregroundNode]),
        ],
      );

      final nodes = selectedTransformableNodesInSceneOrder(
        scene,
        const <NodeId>{'bg', 'fg'},
      );

      expect(nodes.map((node) => node.id), <String>['fg']);
    },
  );
}
