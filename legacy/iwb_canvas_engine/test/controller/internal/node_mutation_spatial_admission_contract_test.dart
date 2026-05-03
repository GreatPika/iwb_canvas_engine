import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_executor.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_op.dart';
import 'package:iwb_canvas_engine/src/controller/txn_context.dart';
import 'package:iwb_canvas_engine/src/model/document.dart';

// INV:INV-ENG-COMMITTED-SPATIAL-ADMISSION-ALIGNMENT

void main() {
  TxnContext newContext(Scene scene) {
    final nodeLocator = txnBuildNodeLocator(scene);
    return TxnContext(
      baseScene: scene,
      workingSelection: <NodeId>{},
      baseAllNodeIds: nodeLocator.keys.toSet(),
      baseNodeLocator: nodeLocator,
      nextInstanceRevision: 1,
    );
  }

  Scene rectScene() {
    return Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-admission',
          nodes: <SceneNode>[
            RectNode(
              id: 'r1',
              size: const Size(10, 10),
              strokeColor: const Color(0xFF000000),
              strokeWidth: 0,
              hitPadding: 6,
              transform: Transform2D.translation(const Offset(5, 5)),
            ),
          ],
        ),
      ],
    );
  }

  RectNodePatch expandingPaintButStableHitPatch() {
    return RectNodePatch(
      id: 'r1',
      strokeWidth: PatchField<double>.value(4),
      common: CommonNodePatch(hitPadding: PatchField<double>.value(4)),
    );
  }

  test(
    'patch marks spatial change when paint admission expands but hit admission stays stable',
    () {
      final ctx = newContext(rectScene());
      final executor = MutationExecutor();

      final result = executor.execute<bool>(
        ctx,
        PatchNodeOp(expandingPaintButStableHitPatch()),
      );

      expect(result.changed, isTrue);
      expect(ctx.changeSet.updatedNodeIds, <NodeId>{'r1'});
      expect(ctx.changeSet.boundsChanged, isTrue);
      expect(ctx.changeSet.spatialGeometryChangedIds, <NodeId>{'r1'});
      expect(ctx.changeSet.visualChanged, isTrue);
    },
  );

  test(
    'visual-only patch keeps spatial flags clear when coarse spatial admission is unchanged',
    () {
      final ctx = newContext(rectScene());
      final executor = MutationExecutor();

      final result = executor.execute<bool>(
        ctx,
        PatchNodeOp(
          RectNodePatch(
            id: 'r1',
            common: CommonNodePatch(opacity: PatchField<double>.value(0.5)),
          ),
        ),
      );

      expect(result.changed, isTrue);
      expect(ctx.changeSet.updatedNodeIds, <NodeId>{'r1'});
      expect(ctx.changeSet.boundsChanged, isFalse);
      expect(ctx.changeSet.spatialGeometryChangedIds, isEmpty);
      expect(ctx.changeSet.visualChanged, isTrue);
    },
  );

  test(
    'mutation owner and committed spatial index both reference the shared admission helper',
    () {
      final mutationOwnerSource = File(
        'lib/src/controller/node_mutation_applier.dart',
      ).readAsStringSync();
      final spatialIndexSource = File(
        'lib/src/core/scene_spatial_index.dart',
      ).readAsStringSync();
      final upsertHitTestSection = spatialIndexSource.substring(
        spatialIndexSource.indexOf('bool _upsertResolvedHitTestNode('),
        spatialIndexSource.indexOf('bool _upsertResolvedPaintNode('),
      );
      final upsertPaintSection = spatialIndexSource.substring(
        spatialIndexSource.indexOf('bool _upsertResolvedPaintNode('),
        spatialIndexSource.indexOf('bool _isResolvedPaintNodeInScene('),
      );

      expect(mutationOwnerSource, contains('nodeSpatialAdmissionBoundsWorld'));
      expect(
        mutationOwnerSource,
        isNot(contains('beforeCandidate = nodeHitTestCandidateBoundsWorld')),
      );
      expect(
        mutationOwnerSource,
        isNot(contains('afterCandidate = nodeHitTestCandidateBoundsWorld')),
      );
      expect(spatialIndexSource, contains('nodeSpatialAdmissionBoundsWorld'));
      expect(upsertHitTestSection, contains('nodeSpatialAdmissionBoundsWorld'));
      expect(
        upsertHitTestSection,
        isNot(
          contains('final hitTestBounds = nodeHitTestCandidateBoundsWorld'),
        ),
      );
      expect(upsertPaintSection, contains('nodeSpatialAdmissionBoundsWorld'));
      expect(
        upsertPaintSection,
        isNot(contains('final paintBounds = nodePaintBoundsWorld')),
      );
    },
  );
}
