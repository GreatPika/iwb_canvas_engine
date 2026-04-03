import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_executor.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_commit_preparer.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_execution_types.dart';
import 'package:iwb_canvas_engine/src/controller/mutation_op.dart';
import 'package:iwb_canvas_engine/src/controller/scene_snapshot_materializer.dart';
import 'package:iwb_canvas_engine/src/controller/txn_context.dart';

// INV:INV-ENG-TXN-ATOMIC-COMMIT
// INV:INV-ENG-TXN-FINALIZED-BEFORE-COMMIT-PLAN

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
        ReplaceSelectionOp,
        ToggleSelectionOp,
        ClearSelectionOp,
        SelectAllSelectionOp,
        TransformSelectionOp,
        TranslateSelectionOp,
      ]);
    },
  );

  test(
    'MutationExecutor keeps mutation families split across explicit owners',
    () {
      final executorSource = File(
        'lib/src/controller/mutation_executor.dart',
      ).readAsStringSync();
      final nodeApplierSource = File(
        'lib/src/controller/node_mutation_applier.dart',
      ).readAsStringSync();
      final selectionFinalizerSource = File(
        'lib/src/controller/selection_post_apply_finalizer.dart',
      ).readAsStringSync();
      final selectionApplierSource = File(
        'lib/src/controller/selection_state_mutation_applier.dart',
      ).readAsStringSync();
      final selectionTransformApplierSource = File(
        'lib/src/controller/selection_transform_mutation_applier.dart',
      ).readAsStringSync();
      final sceneApplierSource = File(
        'lib/src/controller/scene_mutation_applier.dart',
      ).readAsStringSync();

      expect(executorSource, contains("import 'node_mutation_applier.dart';"));
      expect(
        executorSource,
        contains("import 'selection_post_apply_finalizer.dart';"),
      );
      expect(
        executorSource,
        contains("import 'selection_state_mutation_applier.dart';"),
      );
      expect(
        executorSource,
        contains("import 'selection_transform_mutation_applier.dart';"),
      );
      expect(executorSource, contains("import 'scene_mutation_applier.dart';"));
      expect(
        executorSource,
        contains('SelectionStateMutationOp() => _castResult<TValue>('),
      );
      expect(
        executorSource,
        contains('executeSelectionStateMutationOp(ctx, op)'),
      );
      expect(
        executorSource,
        contains('SelectionTransformMutationOp() => _castResult<TValue>('),
      );
      expect(
        executorSource,
        contains('executeSelectionTransformMutationOp(ctx, op)'),
      );
      expect(
        executorSource,
        contains('_executeStructuralDocumentMutation<TValue>(ctx, op)'),
      );
      expect(executorSource, contains('_executeNodeMutation<TValue>(ctx, op)'));
      expect(
        executorSource,
        contains(
          'PatchNodeOp(:final patch) => !patch.common.isVisible.isAbsent',
        ),
      );
      expect(executorSource, contains('DeleteNodeOp() => true,'));
      expect(executorSource, contains('DeleteNodesBulkOp() => true,'));
      expect(executorSource, contains('ClearSceneKeepBackgroundOp() => true,'));
      expect(executorSource, contains('ReplaceSceneOp() => true,'));
      expect(
        executorSource,
        isNot(
          contains(
            'NodeMutationOp() => _executeWithPostApplySelection<TValue>(',
          ),
        ),
      );
      expect(
        executorSource,
        isNot(
          contains(
            'StructuralDocumentMutationOp() => _executeWithPostApplySelection<TValue>(',
          ),
        ),
      );
      expect(executorSource, contains('finalizePostApplySelection(ctx);'));

      expect(
        selectionApplierSource,
        contains('executeSelectionStateMutationOp('),
      );
      expect(selectionApplierSource, contains('ReplaceSelectionOp('));
      expect(selectionApplierSource, contains('ToggleSelectionOp('));
      expect(selectionApplierSource, contains('ClearSelectionOp()'));
      expect(selectionApplierSource, contains('SelectAllSelectionOp('));

      expect(
        selectionTransformApplierSource,
        contains('executeSelectionTransformMutationOp('),
      );
      expect(
        selectionTransformApplierSource,
        contains('TransformSelectionOp('),
      );
      expect(
        selectionTransformApplierSource,
        contains('TranslateSelectionOp('),
      );
      expect(
        sceneApplierSource,
        contains('executeStructuralDocumentMutationOp('),
      );
      expect(
        selectionFinalizerSource,
        contains('void finalizePostApplySelection(TxnContext ctx)'),
      );
      expect(
        File(
          'lib/src/controller/internal/selection_normalizer.dart',
        ).existsSync(),
        isFalse,
      );

      expect(
        nodeApplierSource,
        isNot(contains('executeSelectionStateMutationOp(')),
      );
      expect(nodeApplierSource, isNot(contains('ReplaceSelectionOp(')));
      expect(nodeApplierSource, isNot(contains('ToggleSelectionOp(')));
      expect(nodeApplierSource, isNot(contains('ClearSelectionOp(')));
      expect(nodeApplierSource, isNot(contains('SelectAllSelectionOp(')));
      expect(
        nodeApplierSource,
        isNot(contains('executeSelectionTransformMutationOp(')),
      );
      expect(nodeApplierSource, isNot(contains('TransformSelectionOp(')));
      expect(nodeApplierSource, isNot(contains('TranslateSelectionOp(')));
      expect(
        nodeApplierSource,
        isNot(contains('_patchTouchesSelectionPolicy')),
      );
    },
  );

  test(
    'MutationExecutor finalizes selection on node patches before commit planning',
    () {
      final hiddenCtx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-finalize',
              nodes: <SceneNode>[
                RectNode(id: 'visible', size: const Size(10, 10)),
                RectNode(id: 'stable', size: const Size(10, 10)),
              ],
            ),
          ],
        ),
        workingSelection: <NodeId>{'visible'},
        baseAllNodeIds: const <NodeId>{'visible', 'stable'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final executor = MutationExecutor();

      final hideResult = executor.execute(
        hiddenCtx,
        PatchNodeOp(
          RectNodePatch(
            id: 'visible',
            common: CommonNodePatch(isVisible: PatchField<bool>.value(false)),
          ),
        ),
      );
      expect(hideResult.changed, isTrue);
      expect(hiddenCtx.workingSelection, isEmpty);
      expect(hiddenCtx.changeSet.selectionChanged, isTrue);

      final nonSelectableCtx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-finalize',
              nodes: <SceneNode>[
                RectNode(id: 'visible', size: const Size(10, 10)),
                RectNode(id: 'stable', size: const Size(10, 10)),
              ],
            ),
          ],
        ),
        workingSelection: <NodeId>{'stable'},
        baseAllNodeIds: const <NodeId>{'visible', 'stable'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );

      final nonSelectableResult = executor.execute(
        nonSelectableCtx,
        PatchNodeOp(
          RectNodePatch(
            id: 'stable',
            common: CommonNodePatch(
              isSelectable: PatchField<bool>.value(false),
            ),
          ),
        ),
      );
      expect(nonSelectableResult.changed, isTrue);
      expect(nonSelectableCtx.workingSelection, const <NodeId>{'stable'});
      expect(nonSelectableCtx.changeSet.selectionChanged, isFalse);
    },
  );

  test(
    'MutationExecutor skips post-apply selection finalization for transform-only node writes',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-finalize',
              nodes: <SceneNode>[
                RectNode(id: 'selected', size: const Size(10, 10)),
                RectNode(id: 'moved', size: const Size(10, 10)),
              ],
            ),
          ],
        ),
        workingSelection: <NodeId>{'selected'},
        baseAllNodeIds: const <NodeId>{'selected', 'moved'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final executor = MutationExecutor();

      final result = executor.execute(
        ctx,
        SetNodeTransformOp(
          'moved',
          Transform2D.translation(const Offset(12, 8)),
        ),
      );

      expect(result.changed, isTrue);
      expect(ctx.workingSelection, const <NodeId>{'selected'});
      expect(ctx.changeSet.selectionChanged, isFalse);
    },
  );

  test(
    'MutationExecutor selection-state ops preserve normalized selection semantics',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          backgroundLayer: BackgroundLayer(
            nodes: <SceneNode>[RectNode(id: 'bg-node', size: const Size(2, 2))],
          ),
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-selection',
              nodes: <SceneNode>[
                RectNode(id: 'visible', size: const Size(10, 10)),
                RectNode(
                  id: 'hidden',
                  size: const Size(10, 10),
                  isVisible: false,
                ),
              ],
            ),
          ],
        ),
        workingSelection: const <NodeId>{'visible'},
        baseAllNodeIds: const <NodeId>{'bg-node', 'visible', 'hidden'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final executor = MutationExecutor();

      final replaceNoop = executor.execute(
        ctx,
        ReplaceSelectionOp(const <NodeId>{'missing', 'bg-node', 'hidden'}),
      );
      expect(replaceNoop.value, isNull);
      expect(replaceNoop.changed, isFalse);
      expect(ctx.workingSelection, const <NodeId>{'visible'});

      final toggle = executor.execute(ctx, const ToggleSelectionOp('visible'));
      expect(toggle.value, isTrue);
      expect(toggle.changed, isTrue);
      expect(ctx.workingSelection, isEmpty);

      final clear = executor.execute(ctx, const ClearSelectionOp());
      expect(clear.value, isFalse);
      expect(clear.changed, isFalse);

      final selectAll = executor.execute(
        ctx,
        const SelectAllSelectionOp(onlySelectable: false),
      );
      expect(selectAll.value, (selectedCount: 1, changed: true));
      expect(selectAll.changed, isTrue);
      expect(ctx.workingSelection, const <NodeId>{'visible'});
      expect(ctx.changeSet.selectionChanged, isTrue);
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
          TextNodeSpec(
            text: 'hello',
            color: const Color(0xFF111111),
            textDirection: TextDirection.ltr,
          ),
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
          materializeSceneReplacement(
            snapshot: SceneSnapshot(
              layers: <ContentLayerSnapshot>[
                ContentLayerSnapshot(
                  id: 'layer-auto-5',
                  nodes: <NodeSnapshot>[
                    RectNodeSnapshot(id: 'fresh', size: const Size(2, 2)),
                  ],
                ),
              ],
            ),
            nextInstanceRevisionSeed: ctx.nextInstanceRevision,
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
