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

  test('interactive/deletable selection helpers honor node flags', () {
    final node = RectNode(id: 'n', size: const Size(10, 10));

    expect(isNodeInteractiveForSelection(node, onlySelectable: false), isTrue);
    node.isSelectable = false;
    expect(isNodeInteractiveForSelection(node, onlySelectable: true), isFalse);

    node.isVisible = false;
    expect(isNodeInteractiveForSelection(node, onlySelectable: false), isFalse);

    node.isDeletable = false;
    expect(isNodeDeletableInLayer(node), isFalse);
  });

  test('selectedTransformableNodesInSceneOrder filters by ids and flags', () {
    final a = RectNode(id: 'a', size: const Size(1, 1));
    final b = RectNode(id: 'b', size: const Size(1, 1))
      ..isTransformable = false;
    final c = RectNode(id: 'c', size: const Size(1, 1));

    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(nodes: <SceneNode>[a]),
        ContentLayer(nodes: <SceneNode>[b, c]),
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
      const <String>['a', 'c'],
    );
  });
}
