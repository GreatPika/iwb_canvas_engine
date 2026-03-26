import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_executor.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_commit_preparer.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_op.dart';
import 'package:iwb_canvas_engine/src/controller/txn_context.dart';

// INV:INV-ENG-TXN-ATOMIC-COMMIT

void main() {
  MutationExecutionResult<TValue> executeWithPreparedCommit<
    TValue extends Object?
  >(MutationExecutor executor, TxnContext ctx, TypedMutationOp<TValue> op) {
    final applyResult = executor.execute(ctx, op);
    final preparedCommit = prepareMutationPreparedCommitResult(ctx);
    return MutationExecutionResult<TValue>(
      applyResult: applyResult,
      changeSet: preparedCommit.changeSet,
      commitCandidate: preparedCommit.commitCandidate,
    );
  }

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

      final result = executeWithPreparedCommit(
        executor,
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

    final result = executeWithPreparedCommit(
      executor,
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

      final result = executeWithPreparedCommit(
        executor,
        ctx,
        DeleteNodesBulkOp(const <NodeId>{'keep', 'gone'}),
      );

      expect(result.applyResult.changed, isTrue);
      expect(result.applyResult.value, const <NodeId>['gone']);
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
    'MutationExecutor selection transform routes through family dispatch',
    () {
      final existingTransform = Transform2D.rotationDeg(30);
      final delta = Transform2D.translation(const Offset(4, -3));
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-3sel',
              nodes: <SceneNode>[
                RectNode(
                  id: 'r1',
                  size: const Size(10, 10),
                  transform: existingTransform,
                ),
                RectNode(id: 'locked', size: const Size(5, 5), isLocked: true),
              ],
            ),
          ],
        ),
        workingSelection: const <NodeId>{'r1', 'locked', 'missing'},
        baseAllNodeIds: const <NodeId>{'r1', 'locked'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final executor = MutationExecutor();

      final result = executeWithPreparedCommit(
        executor,
        ctx,
        TransformSelectionOp(delta),
      );

      final updated = ctx.workingScene.layers.single.nodes.first as RectNode;
      expect(result.applyResult.value, 1);
      expect(result.applyResult.changed, isTrue);
      expect(
        updated.transform.toJsonMap(),
        delta.multiply(existingTransform).toJsonMap(),
      );
      expect(result.changeSet.updatedNodeIds, const <NodeId>{'r1'});
      expect(result.changeSet.hitGeometryChangedIds, const <NodeId>{'r1'});
      expect(result.changeSet.boundsChanged, isTrue);
    },
  );

  test(
    'MutationExecutor keeps locator correct after inserted layer and same-txn delete',
    () {
      final baseScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(id: 'layer-auto-3a'),
          ContentLayer(
            id: 'layer-auto-3b',
            nodes: <SceneNode>[RectNode(id: 'tail', size: const Size(1, 1))],
          ),
        ],
      );
      final ctx = TxnContext(
        baseScene: baseScene,
        workingSelection: const <NodeId>{},
        baseAllNodeIds: const <NodeId>{'tail'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final executor = MutationExecutor();

      final ensureResult = executor.execute(
        ctx,
        const EnsureLayerOp('layer-inserted', index: 1),
      );
      expect(ensureResult.changed, isTrue);
      expect(ctx.txnFindNodeById('tail')?.layerIndex, 2);

      final deleteResult = executor.execute(ctx, const DeleteNodeOp('tail'));

      expect(deleteResult.changed, isTrue);
      expect(ctx.txnFindNodeById('tail'), isNull);
      expect(
        ctx.workingScene.layers
            .map((layer) => layer.id)
            .toList(growable: false),
        const <LayerId>['layer-auto-3a', 'layer-inserted', 'layer-auto-3b'],
      );
    },
  );

  test(
    'MutationExecutor clear marks structural change without removed nodes',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[ContentLayer(id: 'layer-auto-3c')],
        ),
        workingSelection: const <NodeId>{},
        baseAllNodeIds: const <NodeId>{},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final executor = MutationExecutor();

      final result = executeWithPreparedCommit(
        executor,
        ctx,
        const ClearSceneKeepBackgroundOp(),
      );

      expect(result.applyResult.changed, isTrue);
      expect(
        result.applyResult.value,
        isA<ClearSceneResult>()
            .having((value) => value.removedNodeIds, 'removedNodeIds', isEmpty)
            .having(
              (value) => value.didStructuralClear,
              'didStructuralClear',
              isTrue,
            ),
      );
      expect(result.changeSet.structuralChanged, isTrue);
      expect(result.changeSet.removedNodeIds, isEmpty);
      expect(result.commitCandidate, isNotNull);
      expect(ctx.workingScene.layers, isEmpty);
      expect(ctx.workingScene.backgroundLayer, isNotNull);
    },
  );

  test(
    'MutationExecutor structural apply preserves base-scene copy-on-write',
    () {
      final baseScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-3d',
            nodes: <SceneNode>[RectNode(id: 'gone', size: const Size(1, 1))],
          ),
        ],
      );
      final ctx = TxnContext(
        baseScene: baseScene,
        workingSelection: const <NodeId>{'gone'},
        baseAllNodeIds: const <NodeId>{'gone'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final executor = MutationExecutor();

      executor.execute(ctx, const ClearSceneKeepBackgroundOp());

      expect(baseScene.layers, hasLength(1));
      expect(baseScene.layers.single.nodes.single.id, 'gone');
      expect(baseScene.backgroundLayer, isNull);
      expect(ctx.workingScene.layers, isEmpty);
      expect(ctx.workingScene.backgroundLayer, isNotNull);
    },
  );

  test('MutationExecutor bulk delete preserves base-scene copy-on-write', () {
    final baseScene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-3e',
          nodes: <SceneNode>[
            RectNode(id: 'a', size: const Size(1, 1)),
            RectNode(id: 'b', size: const Size(1, 1)),
          ],
        ),
      ],
    );
    final ctx = TxnContext(
      baseScene: baseScene,
      workingSelection: const <NodeId>{'a', 'b'},
      baseAllNodeIds: const <NodeId>{'a', 'b'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final executor = MutationExecutor();

    final result = executor.execute(
      ctx,
      DeleteNodesBulkOp(const <NodeId>{'a'}),
    );

    expect(result.changed, isTrue);
    expect(
      baseScene.layers.single.nodes
          .map((node) => node.id)
          .toList(growable: false),
      const <NodeId>['a', 'b'],
    );
    expect(
      ctx.workingScene.layers.single.nodes
          .map((node) => node.id)
          .toList(growable: false),
      const <NodeId>['b'],
    );
  });

  test('MutationExecutor bulk delete no-op keeps changeset untouched', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-3f',
            nodes: <SceneNode>[
              RectNode(
                id: 'locked',
                size: const Size(1, 1),
                isDeletable: false,
              ),
            ],
          ),
        ],
      ),
      workingSelection: const <NodeId>{'locked'},
      baseAllNodeIds: const <NodeId>{'locked'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final executor = MutationExecutor();

    final result = executor.execute(
      ctx,
      DeleteNodesBulkOp(const <NodeId>{'missing', 'locked'}),
    );

    expect(result.changed, isFalse);
    expect(result.value, isEmpty);
    expect(ctx.changeSet.txnHasAnyChange, isFalse);
    expect(ctx.changeSet.removedNodeIds, isEmpty);
    expect(ctx.changeSet.selectionChanged, isFalse);
    expect(ctx.workingSelection, const <NodeId>{'locked'});
    expect(
      ctx.workingScene.layers.single.nodes
          .map((node) => node.id)
          .toList(growable: false),
      const <NodeId>['locked'],
    );
  });

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

      final result = executeWithPreparedCommit(
        executor,
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
