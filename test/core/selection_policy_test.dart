import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/selection_policy.dart';

void main() {
  test('boundsWorldForNodes expands over multiple nodes', () {
    final a = RectNode(id: 'a', size: const Size(10, 10))
      ..position = const Offset(0, 0);
    final b = RectNode(id: 'b', size: const Size(10, 10))
      ..position = const Offset(20, 0);

    final bounds = boundsWorldForNodes(<SceneNode>[a, b]);
    expect(bounds, const Rect.fromLTRB(-5, -5, 25, 5));
    expect(centerWorldForNodes(<SceneNode>[a, b]), const Offset(10, 0));
  });

  test('interactive/deletable selection helpers honor layer and flags', () {
    final node = RectNode(id: 'n', size: const Size(10, 10));
    final fg = Layer(nodes: <SceneNode>[node]);
    final bg = Layer(isBackground: true, nodes: <SceneNode>[node]);

    expect(
      isNodeInteractiveForSelection(node, fg, onlySelectable: false),
      isTrue,
    );
    node.isSelectable = false;
    expect(
      isNodeInteractiveForSelection(node, fg, onlySelectable: true),
      isFalse,
    );
    expect(
      isNodeInteractiveForSelection(node, bg, onlySelectable: false),
      isFalse,
    );

    node.isDeletable = false;
    expect(isNodeDeletableInLayer(node, fg), isFalse);
    expect(isNodeDeletableInLayer(node, bg), isFalse);
  });

  test('selectedTransformableNodesInSceneOrder filters by ids/layer/flag', () {
    final a = RectNode(id: 'a', size: const Size(1, 1));
    final b = RectNode(id: 'b', size: const Size(1, 1))
      ..isTransformable = false;
    final c = RectNode(id: 'c', size: const Size(1, 1));

    final scene = Scene(
      layers: <Layer>[
        Layer(isBackground: true, nodes: <SceneNode>[a]),
        Layer(nodes: <SceneNode>[b, c]),
      ],
    );

    expect(
      selectedTransformableNodesInSceneOrder(scene, const <String>{}),
      isEmpty,
    );
    expect(
      selectedTransformableNodesInSceneOrder(scene, const <String>{
        'a',
        'b',
        'c',
      }).map((n) => n.id).toList(),
      const <String>['c'],
    );
  });
}
