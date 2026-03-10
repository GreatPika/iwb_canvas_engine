import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_executor.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_op.dart';
import 'package:iwb_canvas_engine/src/controller/txn_context.dart';

// INV:INV-ENG-TXN-ATOMIC-COMMIT

void main() {
  test(
    'canonical mutation op set excludes selection-only and signal paths',
    () {
      expect(canonicalMutationOpTypesView(), const <Type>[
        EnsureLayerOp,
        InsertNodeOp,
        PatchNodeOp,
        SetNodeTransformOp,
        DeleteNodeOp,
        DeleteNodesBulkOp,
        ClearSceneKeepBackgroundOp,
        ReplaceSceneOp,
        SetBackgroundColorOp,
        SetGridEnabledOp,
        SetGridCellSizeOp,
        SetCameraOffsetOp,
        TransformSelectionOp,
        TranslateSelectionOp,
      ]);
    },
  );

  test(
    'MutationExecutor insert prepares commit candidate without store apply',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[ContentLayer(id: 'layer-auto-1')],
        ),
        workingSelection: const <NodeId>{},
        baseAllNodeIds: const <NodeId>{},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final executor = MutationExecutor(textFontFamilyByDefault: 'Mono');

      final result = executor.executeWithPreparedCommit(
        ctx,
        InsertNodeOp(
          TextNodeSpec(text: 'hello', color: const Color(0xFF111111)),
        ),
      );

      expect(result.applyResult.changed, isTrue);
      expect(result.applyResult.value, 'gen-n-test-1');
      expect(result.changeSet.addedNodeIds, const <NodeId>{'gen-n-test-1'});
      final candidate = result.commitCandidate;
      expect(candidate, isNotNull);
      final committed = candidate as MutationCommitCandidate;
      expect(committed.scene.layers.single.nodes.single.id, 'gen-n-test-1');
      expect(committed.allNodeIds, const <NodeId>{'gen-n-test-1'});
      expect(
        committed.nodeLocator.keys.toList(growable: false),
        unorderedEquals(const <NodeId>['gen-n-test-1']),
      );

      final inserted = ctx.workingScene.layers.single.nodes.single as TextNode;
      expect(inserted.fontFamily, 'Mono');
    },
  );

  test('MutationExecutor returns no-op result without commit candidate', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-2',
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      ),
      workingSelection: const <NodeId>{},
      baseAllNodeIds: const <NodeId>{'r1'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final executor = MutationExecutor();

    final result = executor.executeWithPreparedCommit(
      ctx,
      PatchNodeOp(RectNodePatch(id: 'r1')),
    );

    expect(result.applyResult.changed, isFalse);
    expect(result.applyResult.value, isFalse);
    expect(result.changeSet.txnHasAnyChange, isFalse);
    expect(result.commitCandidate, isNull);
  });

  test(
    'MutationExecutor bulk delete updates selection and commit candidate',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-3',
              nodes: <SceneNode>[
                RectNode(
                  id: 'keep',
                  size: const Size(10, 10),
                  isDeletable: false,
                ),
                RectNode(id: 'gone', size: const Size(10, 10)),
              ],
            ),
          ],
        ),
        workingSelection: const <NodeId>{'keep', 'gone'},
        baseAllNodeIds: const <NodeId>{'keep', 'gone'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final executor = MutationExecutor();

      final result = executor.executeWithPreparedCommit(
        ctx,
        DeleteNodesBulkOp(const <NodeId>{'keep', 'gone'}),
      );

      expect(result.applyResult.changed, isTrue);
      expect(result.applyResult.value, 1);
      expect(result.changeSet.removedNodeIds, const <NodeId>{'gone'});
      expect(result.changeSet.selectionChanged, isTrue);
      expect(ctx.workingSelection, const <NodeId>{'keep'});
      expect(
        ctx.workingScene.layers.single.nodes.map((node) => node.id),
        orderedEquals(const <NodeId>['keep']),
      );
      final candidate = result.commitCandidate;
      expect(candidate, isNotNull);
      final committed = candidate as MutationCommitCandidate;
      expect(committed.selection, const <NodeId>{'keep'});
      expect(committed.allNodeIds, const <NodeId>{'keep'});
    },
  );

  test(
    'MutationExecutor replace scene clears selection and marks document replace',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-4',
              nodes: <SceneNode>[RectNode(id: 'old', size: const Size(1, 1))],
            ),
          ],
        ),
        workingSelection: const <NodeId>{'old'},
        baseAllNodeIds: const <NodeId>{'old'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final executor = MutationExecutor();

      final result = executor.executeWithPreparedCommit(
        ctx,
        ReplaceSceneOp(
          SceneSnapshot(
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(
                id: 'layer-auto-5',
                nodes: <NodeSnapshot>[
                  RectNodeSnapshot(id: 'fresh', size: const Size(2, 2)),
                ],
              ),
            ],
          ),
        ),
      );

      expect(result.applyResult.changed, isTrue);
      expect(result.changeSet.documentReplaced, isTrue);
      expect(result.changeSet.selectionChanged, isTrue);
      expect(ctx.workingSelection, isEmpty);
      expect(ctx.workingScene.layers.single.nodes.single.id, 'fresh');
      final candidate = result.commitCandidate;
      expect(candidate, isNotNull);
      final committed = candidate as MutationCommitCandidate;
      expect(committed.selection, isEmpty);
      expect(committed.allNodeIds, const <NodeId>{'fresh'});
    },
  );

  test('MutationExecutor cheap execute skips commit-state materialization', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[ContentLayer(id: 'layer-auto-6')],
      ),
      workingSelection: const <NodeId>{},
      baseAllNodeIds: const <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final executor = MutationExecutor();

    final result = executor.execute(
      ctx,
      InsertNodeOp(RectNodeSpec(size: const Size(3, 3))),
    );

    expect(result.changed, isTrue);
    expect(result.value, 'gen-n-test-1');
    expect(ctx.debugNodeIdSetMaterializations, 0);
  });
}
