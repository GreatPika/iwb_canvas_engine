import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/path_fill_rule.dart'
    as contract_fill_rule;
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';

// INV:INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY

void main() {
  test('contract snapshot remains the canonical immutable contract owner', () {
    final snapshot = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-1',
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(
              id: 'rect-1',
              size: Size(10, 12),
              strokeColor: Color(0xFF000000),
            ),
            PathNodeSnapshot(
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

  test('contract canonical surfaces stay part-free and explicit', () {
    final snapshotSource = File(
      'lib/src/contract/snapshot.dart',
    ).readAsStringSync();
    final nodeSpecSource = File(
      'lib/src/contract/node_spec.dart',
    ).readAsStringSync();
    final nodePatchSource = File(
      'lib/src/contract/node_patch.dart',
    ).readAsStringSync();
    final schemaBarrelSource = File(
      'lib/src/contract/internal/node_boundary_schema.dart',
    ).readAsStringSync();
    final snapshotFastPathSource = File(
      'lib/src/contract/internal/snapshot_fast_path.dart',
    ).readAsStringSync();
    final nodeSpecFastPathSource = File(
      'lib/src/contract/internal/node_spec_fast_path.dart',
    ).readAsStringSync();
    final nodePatchFastPathSource = File(
      'lib/src/contract/internal/node_patch_fast_path.dart',
    ).readAsStringSync();

    for (final source in <String>[
      snapshotSource,
      nodeSpecSource,
      nodePatchSource,
      schemaBarrelSource,
      snapshotFastPathSource,
      nodeSpecFastPathSource,
      nodePatchFastPathSource,
    ]) {
      expect(
        source
            .split('\n')
            .any(
              (line) => line.startsWith('part ') || line.startsWith('part of '),
            ),
        isFalse,
      );
    }

    expect(
      nodeSpecSource,
      contains("import 'internal/node_boundary_schema.dart';"),
    );
    expect(nodeSpecSource, isNot(contains('internalBacking')));
    expect(
      nodePatchSource,
      contains("import 'internal/node_boundary_schema.dart';"),
    );
    expect(nodePatchSource, isNot(contains('internalBacking')));
    expect(snapshotSource, isNot(contains('@internal')));
    expect(snapshotSource, isNot(contains('.internal(')));
    expect(snapshotSource, isNot(contains('materialize')));
    expect(nodeSpecSource, isNot(contains('materialize')));
    expect(nodePatchSource, isNot(contains('materialize')));
    expect(
      schemaBarrelSource,
      contains("export 'node_boundary_schema_common.dart';"),
    );
    expect(
      schemaBarrelSource,
      contains("export 'node_boundary_schema_snapshot.dart';"),
    );
    expect(snapshotFastPathSource, contains("export 'snapshot_backing.dart'"));
    expect(
      snapshotFastPathSource,
      contains("export 'snapshot_materialization.dart'"),
    );
    expect(nodeSpecFastPathSource, contains("export 'node_spec_backing.dart'"));
    expect(
      nodeSpecFastPathSource,
      contains("export 'node_spec_materialization.dart'"),
    );
    expect(
      nodePatchFastPathSource,
      contains("export 'node_patch_backing.dart'"),
    );
    expect(
      nodePatchFastPathSource,
      contains("export 'node_patch_materialization.dart'"),
    );
  });
}
