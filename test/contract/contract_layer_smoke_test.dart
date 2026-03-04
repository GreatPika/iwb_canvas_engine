import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/path_fill_rule.dart'
    as contract_fill_rule;
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';

void main() {
  test('contract snapshot remains the canonical immutable contract owner', () {
    final snapshot = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-1',
          nodes: <NodeSnapshot>[
            const RectNodeSnapshot(
              id: 'rect-1',
              size: Size(10, 12),
              strokeColor: Color(0xFF000000),
            ),
            const PathNodeSnapshot(
              id: 'path-1',
              svgPathData: 'M0 0 L1 1',
              strokeColor: Color(0xFF000000),
              fillRule: contract_fill_rule.PathFillRule.evenOdd,
              transform: Transform2D.identity,
            ),
          ],
        ),
      ],
    );

    expect(snapshot.layers.single.id, 'layer-1');
    expect(snapshot.layers.single.nodes.first.id, 'rect-1');
    expect(
      (snapshot.layers.single.nodes.last as PathNodeSnapshot).fillRule,
      contract_fill_rule.PathFillRule.evenOdd,
    );
    expect(snapshot.backgroundLayer.nodes, isEmpty);
  });

  test(
    'contract owners expose base transform and fill-rule symbols directly',
    () {
      final moved = Transform2D.translation(const Offset(4, 6));

      expect(moved.translation, const Offset(4, 6));
      expect(
        contract_fill_rule.PathFillRule.values,
        contains(contract_fill_rule.PathFillRule.nonZero),
      );
      expect(
        contract_fill_rule.PathFillRule.values,
        contains(contract_fill_rule.PathFillRule.evenOdd),
      );
    },
  );
}
