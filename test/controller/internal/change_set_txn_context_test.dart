import 'dart:collection';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/controller/change_set.dart';
import 'package:iwb_canvas_engine/src/controller/store.dart';
import 'package:iwb_canvas_engine/src/controller/txn_context.dart';
import 'package:iwb_canvas_engine/src/model/document.dart';

// INV:INV-ENG-TXN-COPY-ON-WRITE

class _LayerDropTxnContext extends TxnContext {
  _LayerDropTxnContext({
    required super.baseScene,
    required super.workingSelection,
    required super.baseAllNodeIds,
    required super.nodeIdSeed,
    required super.nextInstanceRevision,
  });

  bool _dropped = false;

  @override
  ContentLayer txnEnsureMutableLayer(int layerIndex) {
    final layer = super.txnEnsureMutableLayer(layerIndex);
    if (!_dropped) {
      _dropped = true;
      layer.nodes.clear();
    }
    return layer;
  }
}

class _BackgroundDropTxnContext extends TxnContext {
  _BackgroundDropTxnContext({
    required super.baseScene,
    required super.workingSelection,
    required super.baseAllNodeIds,
    required super.nodeIdSeed,
    required super.nextInstanceRevision,
  });

  ({SceneNode node, int layerIndex, int nodeIndex})? _cachedFound;
  var _findCalls = 0;

  @override
  ({SceneNode node, int layerIndex, int nodeIndex})? txnFindNodeById(
    NodeId id,
  ) {
    final found = super.txnFindNodeById(id);
    _findCalls = _findCalls + 1;
    if (_findCalls == 1) {
      _cachedFound = found;
      return found;
    }
    return found ?? _cachedFound;
  }

  @override
  BackgroundLayer txnEnsureMutableBackgroundLayer() {
    final layer = super.txnEnsureMutableBackgroundLayer();
    workingScene.backgroundLayer = null;
    return layer;
  }
}

void main() {
  test('ChangeSet tracks and clones change state consistently', () {
    final changeSet = ChangeSet();
    expect(changeSet.txnHasAnyChange, isFalse);

    changeSet.txnMarkSelectionChanged();
    changeSet.txnMarkVisualChanged();
    changeSet.txnMarkGridChanged();
    expect(changeSet.selectionChanged, isTrue);
    expect(changeSet.visualChanged, isTrue);
    expect(changeSet.gridChanged, isTrue);
    expect(changeSet.txnHasAnyChange, isTrue);

    changeSet.txnTrackAdded('n1');
    changeSet.txnTrackUpdated('n1');
    expect(changeSet.updatedNodeIds, isEmpty);

    changeSet.txnTrackRemoved('n1');
    expect(changeSet.addedNodeIds, isEmpty);
    expect(changeSet.removedNodeIds, <NodeId>{'n1'});

    changeSet.txnTrackAdded('n1');
    expect(changeSet.removedNodeIds, isEmpty);
    expect(changeSet.addedNodeIds, <NodeId>{'n1'});

    changeSet.txnTrackUpdated('n2');
    expect(changeSet.updatedNodeIds, <NodeId>{'n2'});
    changeSet.txnTrackHitGeometryChanged('n2');
    expect(changeSet.hitGeometryChangedIds, <NodeId>{'n2'});
    changeSet.txnTrackAdded('n2');
    expect(changeSet.updatedNodeIds, isEmpty);
    expect(changeSet.hitGeometryChangedIds, isEmpty);

    changeSet.txnTrackHitGeometryChanged('n3');
    expect(changeSet.hitGeometryChangedIds, <NodeId>{'n3'});
    changeSet.txnTrackRemoved('n3');
    expect(changeSet.hitGeometryChangedIds, isEmpty);

    changeSet.txnMarkDocumentReplaced();
    expect(changeSet.documentReplaced, isTrue);
    expect(changeSet.structuralChanged, isTrue);
    expect(changeSet.boundsChanged, isTrue);

    final clone = changeSet.txnClone();
    expect(clone.documentReplaced, changeSet.documentReplaced);
    expect(clone.addedNodeIds, changeSet.addedNodeIds);
    expect(clone.hitGeometryChangedIds, changeSet.hitGeometryChangedIds);
    expect(clone, isNot(same(changeSet)));
  });

  test('TxnContext tracks node ids incrementally and materializes lazily', () {
    final ctx = TxnContext(
      baseScene: Scene(),
      workingSelection: <NodeId>{},
      baseAllNodeIds: <NodeId>{'keep'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );

    ctx.txnRememberNodeId('added');
    expect(ctx.txnHasNodeId('added'), isTrue);
    expect(ctx.debugNodeIdSetMaterializations, 0);
    expect(ctx.debugNodeLocatorMaterializations, 0);

    ctx.txnForgetNodeId('keep');
    expect(ctx.txnHasNodeId('keep'), isFalse);
    expect(ctx.debugNodeIdSetMaterializations, 0);
    expect(ctx.debugNodeLocatorMaterializations, 0);

    final materialized = ctx.debugNodeIdsView(structuralChanged: true);
    expect(materialized, <NodeId>{'added'});
    expect(ctx.debugNodeIdSetMaterializations, 1);
    final locatorView = ctx.debugNodeLocatorView(structuralChanged: false);
    expect(locatorView, isEmpty);
    expect(ctx.debugNodeLocatorMaterializations, 0);

    ctx.txnAdoptScene(
      Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-0',
            nodes: <SceneNode>[
              RectNode(id: 'node-7', size: const Size(1, 1)),
              RectNode(id: 'manual', size: const Size(1, 1)),
            ],
          ),
        ],
      ),
    );
    expect(ctx.debugNodeIdsView(structuralChanged: true), <NodeId>{
      'node-7',
      'manual',
    });
    expect(
      ctx.debugNodeLocatorView(structuralChanged: true),
      <NodeId, NodeLocatorEntry>{
        'node-7': (layerIndex: 0, nodeIndex: 0),
        'manual': (layerIndex: 0, nodeIndex: 1),
      },
    );
    expect(ctx.nodeIdSeed, 8);
    expect(ctx.nextInstanceRevision, 2);
  });

  test('TxnContext keeps nextInstanceRevision monotonic on adopt', () {
    final ctx = TxnContext(
      baseScene: Scene(),
      workingSelection: <NodeId>{},
      baseAllNodeIds: <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 50,
    );

    ctx.txnAdoptScene(
      Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-1',
            nodes: <SceneNode>[RectNode(id: 'a', size: const Size(1, 1))],
          ),
        ],
      ),
    );

    expect(ctx.nextInstanceRevision, 50);
  });

  test('TxnContext txnNextLayerId skips existing ids', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(id: 'layer-0'),
          ContentLayer(id: 'layer-1'),
        ],
      ),
      workingSelection: <NodeId>{},
      baseAllNodeIds: const <NodeId>{},
      nodeIdSeed: 0,
      layerIdSeed: 0,
      nextInstanceRevision: 1,
    );

    final next = ctx.txnNextLayerId();

    expect(next, 'layer-2');
    expect(ctx.layerIdSeed, 3);
  });

  test('TxnContext materializes layerId index lazily', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(id: 'layer-auto-10'),
          ContentLayer(id: 'layer-auto-11'),
        ],
      ),
      workingSelection: <NodeId>{},
      baseAllNodeIds: const <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );

    expect(ctx.debugLayerIdIndexMaterializations, 0);
    expect(ctx.txnFindContentLayerIndexById('layer-auto-10'), 0);
    expect(ctx.debugLayerIdIndexMaterializations, 1);
  });

  test('TxnContext reuses layerId index for repeated lookups', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(id: 'layer-auto-20'),
          ContentLayer(id: 'layer-auto-21'),
        ],
      ),
      workingSelection: <NodeId>{},
      baseAllNodeIds: const <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );

    for (var i = 0; i < 1000; i++) {
      expect(ctx.txnFindContentLayerIndexById('layer-auto-20'), 0);
      expect(ctx.txnFindContentLayerIndexById('layer-auto-21'), 1);
    }
    expect(ctx.debugLayerIdIndexMaterializations, 1);
  });

  test('TxnContext resets layerId index after adoptScene', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[ContentLayer(id: 'layer-auto-30')],
      ),
      workingSelection: <NodeId>{},
      baseAllNodeIds: const <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );

    expect(ctx.txnFindContentLayerIndexById('layer-auto-30'), 0);
    expect(ctx.debugLayerIdIndexMaterializations, 1);

    ctx.txnAdoptScene(
      Scene(layers: <ContentLayer>[ContentLayer(id: 'layer-auto-40')]),
    );

    expect(ctx.txnFindContentLayerIndexById('layer-auto-40'), 0);
    expect(ctx.debugLayerIdIndexMaterializations, 2);
  });

  test('TxnContext rebuilds stale layerId index on mismatch', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(id: 'layer-auto-50'),
          ContentLayer(id: 'layer-auto-51'),
        ],
      ),
      workingSelection: <NodeId>{},
      baseAllNodeIds: const <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );

    expect(ctx.txnFindContentLayerIndexById('layer-auto-50'), 0);
    expect(ctx.debugLayerIdIndexMaterializations, 1);

    final mutableScene = ctx.txnEnsureMutableScene();
    final firstLayer = mutableScene.layers[0];
    mutableScene.layers[0] = mutableScene.layers[1];
    mutableScene.layers[1] = firstLayer;

    expect(ctx.txnFindContentLayerIndexById('layer-auto-50'), 1);
    expect(ctx.txnFindContentLayerIndexById('layer-auto-51'), 0);
    expect(ctx.debugLayerIdIndexMaterializations, 2);
  });

  test(
    'TxnContext ensureContentLayer shifts node locator, cloned indexes and layer seed',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-60'),
            ContentLayer(
              id: 'layer-auto-61',
              nodes: <SceneNode>[RectNode(id: 'tail', size: const Size(1, 1))],
            ),
          ],
        ),
        workingSelection: <NodeId>{},
        baseAllNodeIds: const <NodeId>{'tail'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );

      final clonedLayer = ctx.txnEnsureMutableLayer(1);
      expect(ctx.debugLayerShallowClones, 1);

      expect(ctx.txnEnsureContentLayer('layer-10', index: 1), isTrue);
      expect(
        ctx.workingScene.layers
            .map((layer) => layer.id)
            .toList(growable: false),
        <String>['layer-auto-60', 'layer-10', 'layer-auto-61'],
      );
      expect(ctx.txnFindNodeById('tail')?.layerIndex, 2);
      expect(ctx.layerIdSeed, 11);
      final resolvedTail = ctx.txnResolveMutableNode('tail');
      expect(resolvedTail.node.id, 'tail');
      expect(resolvedTail.layerIndex, 2);
      expect(ctx.debugNodeClones, 1);
      final resolvedTailAgain = ctx.txnResolveMutableNode('tail');
      expect(resolvedTailAgain.node.id, 'tail');
      expect(ctx.debugNodeClones, 1);

      expect(ctx.txnEnsureContentLayer('tail-layer'), isTrue);
      expect(ctx.workingScene.layers.last.id, 'tail-layer');

      final shiftedLayer = ctx.txnEnsureMutableLayer(2);
      expect(identical(shiftedLayer, clonedLayer), isTrue);
      expect(ctx.debugLayerShallowClones, 1);

      expect(
        () => ctx.txnEnsureContentLayer('bad', index: -1),
        throwsRangeError,
      );
    },
  );

  test('TxnContext mutating APIs throw after transaction close', () {
    final baseScene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(1, 1))],
      ),
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-2',
          nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(1, 1))],
        ),
      ],
    );
    final ctx = TxnContext(
      baseScene: baseScene,
      workingSelection: <NodeId>{},
      baseAllNodeIds: <NodeId>{'bg', 'r1'},
      nodeIdSeed: 2,
      nextInstanceRevision: 1,
    );

    ctx.txnClose();

    expect(() => ctx.txnEnsureMutableScene(), throwsStateError);
    expect(() => ctx.txnEnsureMutableLayer(0), throwsStateError);
    expect(() => ctx.txnEnsureMutableBackgroundLayer(), throwsStateError);
    expect(() => ctx.txnResolveMutableNode('r1'), throwsStateError);
    expect(() => ctx.txnAdoptScene(Scene()), throwsStateError);
  });

  test(
    'TxnContext updates materialized node ids in place after commit view',
    () {
      final ctx = TxnContext(
        baseScene: Scene(),
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{'keep'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );

      ctx.txnForgetNodeId('keep');
      ctx.txnRememberNodeId('keep');
      expect(ctx.txnHasNodeId('keep'), isTrue);

      final materialized = ctx.debugNodeIdsView(structuralChanged: true);
      expect(materialized, <NodeId>{'keep'});

      ctx.txnRememberNodeId('late');
      expect(ctx.txnHasNodeId('late'), isTrue);
      ctx.txnForgetNodeId('late');
      expect(ctx.txnHasNodeId('late'), isFalse);
      expect(materialized, <NodeId>{'keep'});
    },
  );

  test(
    'TxnContext materializes nodeLocator lazily on structural commit view',
    () {
      final baseScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-3',
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(1, 1))],
          ),
        ],
      );
      final ctx = TxnContext(
        baseScene: baseScene,
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{'r1'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );

      expect(ctx.debugNodeLocatorMaterializations, 0);
      final locator = ctx.debugNodeLocatorView(structuralChanged: true);
      expect(locator['r1'], (layerIndex: 0, nodeIndex: 0));
      expect(ctx.debugNodeLocatorMaterializations, 1);
    },
  );

  test('TxnContext keeps workingSelection hash-based and mutable in place', () {
    final inputSelection = <NodeId>{'a', 'b'};
    final ctx = TxnContext(
      baseScene: Scene(),
      workingSelection: inputSelection,
      baseAllNodeIds: <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );

    expect(ctx.workingSelection, isA<HashSet<NodeId>>());
    expect(ctx.workingSelection, <NodeId>{'a', 'b'});

    inputSelection.add('late');
    expect(ctx.workingSelection, isNot(contains('late')));

    final workingSelectionRef = ctx.workingSelection;
    ctx.workingSelection.remove('a');
    ctx.workingSelection.add('c');

    expect(identical(workingSelectionRef, ctx.workingSelection), isTrue);
    expect(ctx.workingSelection, <NodeId>{'b', 'c'});
  });

  test('ChangeSet mutates tracked sets in place across transitions', () {
    final changeSet = ChangeSet();
    final addedRef = changeSet.addedNodeIds;
    final removedRef = changeSet.removedNodeIds;
    final updatedRef = changeSet.updatedNodeIds;

    changeSet.txnTrackAdded('n1');
    changeSet.txnTrackUpdated('n1');
    changeSet.txnTrackRemoved('n1');
    changeSet.txnTrackAdded('n1');

    changeSet.txnTrackRemoved('n2');
    changeSet.txnTrackAdded('n2');

    changeSet.txnTrackAdded('n3');
    changeSet.txnTrackRemoved('n3');
    changeSet.txnTrackAdded('n3');

    expect(identical(addedRef, changeSet.addedNodeIds), isTrue);
    expect(identical(removedRef, changeSet.removedNodeIds), isTrue);
    expect(identical(updatedRef, changeSet.updatedNodeIds), isTrue);
    expect(changeSet.addedNodeIds, isA<HashSet<NodeId>>());
    expect(changeSet.removedNodeIds, isA<HashSet<NodeId>>());
    expect(changeSet.updatedNodeIds, isA<HashSet<NodeId>>());
    expect(changeSet.hitGeometryChangedIds, isA<HashSet<NodeId>>());

    expect(changeSet.addedNodeIds, <NodeId>{'n1', 'n2', 'n3'});
    expect(changeSet.removedNodeIds, isEmpty);
    expect(changeSet.updatedNodeIds, isEmpty);
  });

  test(
    'TxnContext and ChangeSet keep O(1) id delta updates on 1000 operations',
    () {
      final ctx = TxnContext(
        baseScene: Scene(),
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final changeSet = ChangeSet();
      final addedRef = changeSet.addedNodeIds;
      final removedRef = changeSet.removedNodeIds;
      final updatedRef = changeSet.updatedNodeIds;

      for (var i = 0; i < 1000; i++) {
        final id = 'n$i';
        ctx.txnRememberNodeId(id);
        changeSet.txnTrackAdded(id);

        if (i.isEven) {
          ctx.txnForgetNodeId(id);
          changeSet.txnTrackRemoved(id);
        } else {
          changeSet.txnTrackUpdated(id);
        }
      }

      expect(ctx.debugNodeIdSetMaterializations, 0);
      expect(identical(addedRef, changeSet.addedNodeIds), isTrue);
      expect(identical(removedRef, changeSet.removedNodeIds), isTrue);
      expect(identical(updatedRef, changeSet.updatedNodeIds), isTrue);

      final committedNodeIds = ctx.debugNodeIdsView(structuralChanged: true);
      expect(ctx.debugNodeIdSetMaterializations, 1);
      expect(committedNodeIds.length, 500);
      expect(committedNodeIds, <NodeId>{
        for (var i = 1; i < 1000; i += 2) 'n$i',
      });
      expect(changeSet.addedNodeIds.length, 500);
      expect(changeSet.addedNodeIds, <NodeId>{
        for (var i = 1; i < 1000; i += 2) 'n$i',
      });
      expect(changeSet.removedNodeIds.length, 500);
      expect(changeSet.removedNodeIds, <NodeId>{
        for (var i = 0; i < 1000; i += 2) 'n$i',
      });
      expect(changeSet.updatedNodeIds, isEmpty);
    },
  );

  test('SceneStore initializes selections, id set and id seed from scene', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-4',
          nodes: <SceneNode>[
            RectNode(id: 'node-2', size: const Size(1, 1)),
            RectNode(id: 'node-9', size: const Size(1, 1)),
            RectNode(id: 'custom', size: const Size(1, 1)),
          ],
        ),
      ],
    );

    final incomingSelection = <NodeId>{'node-2'};
    final storeWithSelection = SceneStore(
      sceneDoc: scene,
      selectedNodeIds: incomingSelection,
    );
    incomingSelection.add('custom');

    expect(storeWithSelection.selectedNodeIds, <NodeId>{'node-2'});
    expect(
      storeWithSelection.allNodeIds,
      containsAll(<NodeId>{'node-2', 'node-9', 'custom'}),
    );
    expect(storeWithSelection.nodeLocator, <NodeId, NodeLocatorEntry>{
      'node-2': (layerIndex: 0, nodeIndex: 0),
      'node-9': (layerIndex: 0, nodeIndex: 1),
      'custom': (layerIndex: 0, nodeIndex: 2),
    });
    expect(storeWithSelection.nodeIdSeed, 10);
    expect(storeWithSelection.nextInstanceRevision, 2);

    final storeWithoutSelection = SceneStore(sceneDoc: Scene());
    expect(storeWithoutSelection.selectedNodeIds, isEmpty);
    expect(storeWithoutSelection.nodeIdSeed, 0);
    expect(storeWithoutSelection.nextInstanceRevision, 1);
  });

  test('TxnContext scene-for-commit uses base scene until first mutation', () {
    final baseScene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-5',
          nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
        ),
      ],
    );
    final ctx = TxnContext(
      baseScene: baseScene,
      workingSelection: <NodeId>{},
      baseAllNodeIds: <NodeId>{'r1'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );

    expect(identical(ctx.txnSceneForCommit(), baseScene), isTrue);

    final mutableScene = ctx.txnEnsureMutableScene();
    expect(identical(mutableScene, baseScene), isFalse);
    expect(identical(ctx.txnSceneForCommit(), mutableScene), isTrue);
    expect(identical(ctx.workingScene, mutableScene), isTrue);
  });

  test('TxnContext shallow scene clone defers layer and node cloning', () {
    final baseScene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-6',
          nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
        ),
      ],
    );
    final ctx = TxnContext(
      baseScene: baseScene,
      workingSelection: <NodeId>{},
      baseAllNodeIds: <NodeId>{'r1'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );

    final mutable = ctx.txnEnsureMutableScene();
    expect(ctx.debugSceneShallowClones, 1);
    expect(ctx.debugLayerShallowClones, 0);
    expect(ctx.debugNodeClones, 0);
    expect(identical(mutable.layers, baseScene.layers), isFalse);
    expect(identical(mutable.layers.single, baseScene.layers.single), isTrue);
    expect(
      identical(
        mutable.layers.single.nodes.single,
        baseScene.layers.single.nodes.single,
      ),
      isTrue,
    );
  });

  test(
    'TxnContext resolves mutable nodes with one layer clone and per-node COW',
    () {
      final baseScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-7',
            nodes: <SceneNode>[
              RectNode(id: 'r1', size: const Size(10, 10)),
              RectNode(id: 'r2', size: const Size(12, 12)),
            ],
          ),
        ],
      );
      final baseR1 = baseScene.layers.single.nodes.first;
      final baseR2 = baseScene.layers.single.nodes.last;
      final ctx = TxnContext(
        baseScene: baseScene,
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{'r1', 'r2'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );

      final first = ctx.txnResolveMutableNode('r1');
      expect(ctx.debugSceneShallowClones, 1);
      expect(ctx.debugLayerShallowClones, 1);
      expect(ctx.debugNodeClones, 1);
      expect(identical(first.node, baseR1), isFalse);

      final again = ctx.txnResolveMutableNode('r1');
      expect(ctx.debugLayerShallowClones, 1);
      expect(ctx.debugNodeClones, 1);
      expect(identical(again.node, first.node), isTrue);

      final second = ctx.txnResolveMutableNode('r2');
      expect(ctx.debugLayerShallowClones, 1);
      expect(ctx.debugNodeClones, 2);
      expect(identical(second.node, baseR2), isFalse);
    },
  );

  test('TxnContext adopted scene bypasses layer/node COW cloning', () {
    final adopted = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-8',
          nodes: <SceneNode>[RectNode(id: 'adopted', size: const Size(10, 10))],
        ),
      ],
    );
    final adoptedNode = adopted.layers.single.nodes.single;
    final ctx = TxnContext(
      baseScene: Scene(),
      workingSelection: <NodeId>{},
      baseAllNodeIds: <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );

    ctx.txnAdoptScene(adopted);
    final mutable = ctx.txnResolveMutableNode('adopted');
    mutable.node.opacity = 0.5;

    expect(ctx.debugSceneShallowClones, 0);
    expect(ctx.debugLayerShallowClones, 0);
    expect(ctx.debugNodeClones, 0);
    expect(identical(mutable.node, adoptedNode), isTrue);
  });

  test(
    'TxnContext ensureMutableLayer throws range error for invalid index',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[ContentLayer(id: 'layer-auto-9')],
        ),
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );

      expect(() => ctx.txnEnsureMutableLayer(5), throwsRangeError);
    },
  );

  test(
    'TxnContext ensureMutableLayer fast path returns owned adopted layer',
    () {
      final adopted = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-10',
            nodes: <SceneNode>[RectNode(id: 'n1', size: const Size(1, 1))],
          ),
        ],
      );
      final ctx = TxnContext(
        baseScene: Scene(),
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );

      ctx.txnAdoptScene(adopted);
      final layer = ctx.txnEnsureMutableLayer(0);
      expect(identical(layer, adopted.layers[0]), isTrue);
      expect(ctx.debugLayerShallowClones, 0);
    },
  );

  test('TxnContext resolveMutableNode throws for missing node id', () {
    final ctx = TxnContext(
      baseScene: Scene(),
      workingSelection: <NodeId>{},
      baseAllNodeIds: <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );

    expect(() => ctx.txnResolveMutableNode('missing'), throwsStateError);
  });

  test(
    'TxnContext resolveMutableNode throws when node disappears mid-resolve',
    () {
      final ctx = _LayerDropTxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-11',
              nodes: <SceneNode>[RectNode(id: 'n1', size: const Size(1, 1))],
            ),
          ],
        ),
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{'n1'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );

      expect(() => ctx.txnResolveMutableNode('n1'), throwsStateError);
    },
  );

  test('TxnContext background layer COW resolves mutable background node', () {
    final baseScene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(1, 1))],
      ),
      layers: <ContentLayer>[ContentLayer(id: 'layer-auto-12')],
    );
    final baseBackground = baseScene.backgroundLayer!;
    final ctx = TxnContext(
      baseScene: baseScene,
      workingSelection: <NodeId>{},
      baseAllNodeIds: <NodeId>{'bg'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );

    final firstMutable = ctx.txnEnsureMutableBackgroundLayer();
    expect(firstMutable, isNot(same(baseBackground)));
    expect(ctx.debugLayerShallowClones, 1);

    final secondMutable = ctx.txnEnsureMutableBackgroundLayer();
    expect(identical(secondMutable, firstMutable), isTrue);

    final resolved = ctx.txnResolveMutableNode('bg');
    expect(resolved.layerIndex, -1);
    expect(resolved.nodeIndex, 0);
    expect(resolved.node, isA<RectNode>());
    expect(identical(resolved.node, baseBackground.nodes.first), isFalse);
  });

  test(
    'TxnContext background ensureMutable respects externally replaced layer identity',
    () {
      final baseScene = Scene(
        backgroundLayer: BackgroundLayer(
          nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(1, 1))],
        ),
        layers: <ContentLayer>[ContentLayer(id: 'layer-auto-13')],
      );
      final ctx = TxnContext(
        baseScene: baseScene,
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{'bg'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );

      final scene = ctx.txnEnsureMutableScene();
      final replaced = BackgroundLayer(
        nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(1, 1))],
      );
      scene.backgroundLayer = replaced;

      final mutable = ctx.txnEnsureMutableBackgroundLayer();
      expect(identical(mutable, replaced), isTrue);
      expect(ctx.debugLayerShallowClones, 0);
    },
  );

  test(
    'TxnContext resolveMutableNode throws when background disappears mid-resolve',
    () {
      final ctx = _BackgroundDropTxnContext(
        baseScene: Scene(
          backgroundLayer: BackgroundLayer(
            nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(1, 1))],
          ),
          layers: <ContentLayer>[ContentLayer(id: 'layer-auto-14')],
        ),
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{'bg'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );

      expect(
        () => ctx.txnResolveMutableNode('bg'),
        throwsA(
          predicate(
            (error) =>
                error is StateError &&
                error.message ==
                    'Background layer missing after mutable clone: bg',
          ),
        ),
      );
    },
  );
}
