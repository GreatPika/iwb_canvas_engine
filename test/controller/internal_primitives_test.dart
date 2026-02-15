import 'dart:collection';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart';
import 'package:iwb_canvas_engine/src/controller/change_set.dart';
import 'package:iwb_canvas_engine/src/controller/scene_writer.dart';
import 'package:iwb_canvas_engine/src/controller/store.dart';
import 'package:iwb_canvas_engine/src/controller/txn_context.dart';
import 'package:iwb_canvas_engine/src/controller/internal/repaint_flag.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signal_event.dart';
import 'package:iwb_canvas_engine/src/controller/internal/spatial_index_cache.dart';
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
            nodes: <SceneNode>[RectNode(id: 'a', size: const Size(1, 1))],
          ),
        ],
      ),
    );

    expect(ctx.nextInstanceRevision, 50);
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
        baseScene: Scene(layers: <ContentLayer>[ContentLayer()]),
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
      layers: <ContentLayer>[ContentLayer()],
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
        layers: <ContentLayer>[ContentLayer()],
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
          layers: <ContentLayer>[ContentLayer()],
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

  test('SceneWriter handles write operations and updates changeset', () {
    final bufferedSignals = <BufferedSignal>[];
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      ),
      workingSelection: <NodeId>{'r1'},
      baseAllNodeIds: <NodeId>{'r1'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final writer = SceneWriter(ctx, txnSignalSink: bufferedSignals.add);

    expect(writer.snapshot.layers.single.nodes.single.id, 'r1');
    expect(writer.selectedNodeIds, <NodeId>{'r1'});

    expect(
      () => writer.writeNodeInsert(
        RectNodeSpec(id: 'r1', size: const Size(1, 1)),
      ),
      throwsStateError,
    );

    final generatedId = writer.writeNodeInsert(
      RectNodeSpec(size: const Size(2, 2)),
    );
    expect(generatedId, 'node-0');
    expect(ctx.changeSet.structuralChanged, isTrue);
    expect(ctx.changeSet.addedNodeIds, contains('node-0'));

    expect(writer.writeNodePatch(const RectNodePatch(id: 'missing')), isFalse);
    expect(writer.writeNodePatch(const RectNodePatch(id: 'r1')), isFalse);
    expect(
      writer.writeNodePatch(
        const RectNodePatch(id: 'r1', strokeWidth: PatchField<double>.value(2)),
      ),
      isTrue,
    );
    expect(ctx.changeSet.updatedNodeIds, contains('r1'));

    expect(writer.writeNodeErase('missing'), isFalse);
    expect(writer.writeNodeErase('r1'), isTrue);
    expect(ctx.changeSet.removedNodeIds, contains('r1'));
    expect(ctx.workingSelection, isNot(contains('r1')));
    expect(ctx.changeSet.selectionChanged, isTrue);

    writer.writeSelectionReplace(<NodeId>{'node-0'});
    writer.writeSelectionReplace(<NodeId>{'node-0'});
    writer.writeSelectionToggle('node-0');
    writer.writeSelectionToggle('node-0');

    expect(writer.writeSelectionTranslate(Offset.zero), 0);
    expect(writer.writeSelectionTranslate(const Offset(5, 0)), 1);

    writer.writeGridEnable(false);
    writer.writeGridEnable(true);
    writer.writeGridCellSize(20);
    writer.writeGridCellSize(24);
    writer.writeBackgroundColor(writer.snapshot.background.color);
    writer.writeBackgroundColor(const Color(0xFFEEEEEE));

    writer.writeSignalEnqueue(
      type: 'custom.signal',
      nodeIds: <NodeId>{'node-0'},
    );
    expect(bufferedSignals.single.type, 'custom.signal');

    writer.writeDocumentReplace(
      SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'fresh', size: Size(1, 1)),
            ],
          ),
        ],
      ),
    );
    expect(ctx.workingScene.layers.single.nodes.single.id, 'fresh');
    expect(ctx.workingSelection, isEmpty);
    expect(ctx.changeSet.documentReplaced, isTrue);
  });

  test(
    'SceneWriter keeps selection set identity across hot-path mutations',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(
              nodes: <SceneNode>[
                RectNode(id: 'r1', size: const Size(10, 10)),
                RectNode(id: 'r2', size: const Size(10, 10)),
                RectNode(id: 'r3', size: const Size(10, 10)),
              ],
            ),
          ],
        ),
        workingSelection: <NodeId>{'r1', 'r2'},
        baseAllNodeIds: <NodeId>{'r1', 'r2', 'r3'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final writer = SceneWriter(ctx, txnSignalSink: (_) {});
      final selectionRef = ctx.workingSelection;

      writer.writeSelectionToggle('r3');
      expect(identical(selectionRef, ctx.workingSelection), isTrue);

      writer.writeSelectionReplace(const <NodeId>{'r1', 'r3'});
      expect(identical(selectionRef, ctx.workingSelection), isTrue);

      writer.writeNodeErase('r1');
      expect(identical(selectionRef, ctx.workingSelection), isTrue);

      writer.writeDeleteSelection();
      expect(identical(selectionRef, ctx.workingSelection), isTrue);

      writer.writeSelectionClear();
      expect(identical(selectionRef, ctx.workingSelection), isTrue);
    },
  );

  test(
    'SceneWriter selection hot-path keeps in-place set on 1000 toggle/replace/erase ops',
    () {
      final nodes = <SceneNode>[
        for (var i = 0; i < 1000; i++)
          RectNode(id: 'n$i', size: const Size(10, 10)),
      ];
      final ctx = TxnContext(
        baseScene: Scene(layers: <ContentLayer>[ContentLayer(nodes: nodes)]),
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{for (var i = 0; i < 1000; i++) 'n$i'},
        nodeIdSeed: 1000,
        nextInstanceRevision: 1,
      );
      final writer = SceneWriter(ctx, txnSignalSink: (_) {});
      final selectionRef = ctx.workingSelection;
      final expected = <NodeId>{};

      for (var i = 0; i < 1000; i++) {
        final id = 'n$i';
        switch (i % 3) {
          case 0:
            writer.writeSelectionToggle(id);
            if (!expected.remove(id)) {
              expected.add(id);
            }
            break;
          case 1:
            writer.writeSelectionReplace(<NodeId>{id});
            expected
              ..clear()
              ..add(id);
            break;
          case 2:
            expect(writer.writeNodeErase(id), isTrue);
            expected.remove(id);
            break;
        }
        expect(identical(selectionRef, ctx.workingSelection), isTrue);
      }

      expect(ctx.workingSelection, expected);
    },
  );

  test('SceneWriter covers id generation and selection branches', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(
            nodes: <SceneNode>[
              RectNode(id: 'rect-1', size: const Size(10, 10)),
              RectNode(
                id: 'locked',
                size: const Size(10, 10),
                isSelectable: false,
                isDeletable: false,
              ),
            ],
          ),
        ],
      ),
      workingSelection: <NodeId>{'rect-1'},
      baseAllNodeIds: <NodeId>{'rect-1', 'locked'},
      nodeIdSeed: 2,
      nextInstanceRevision: 1,
    );
    final bufferedSignals = <BufferedSignal>[];
    final writer = SceneWriter(ctx, txnSignalSink: bufferedSignals.add);

    final generatedId = writer.writeNodeInsert(
      RectNodeSpec(size: const Size(2, 2)),
    );
    expect(generatedId, 'node-2');
    expect(ctx.txnHasNodeId('rect-1'), isTrue);
    expect(ctx.txnHasNodeId('locked'), isTrue);

    expect(
      writer.writeNodeTransformSet('missing', Transform2D.identity),
      isFalse,
    );
    expect(
      writer.writeNodeTransformSet(
        'rect-1',
        Transform2D.translation(const Offset(3, 4)),
      ),
      isTrue,
    );
    expect(ctx.changeSet.updatedNodeIds, contains('rect-1'));

    expect(writer.writeSelectionClear(), isTrue);
    expect(writer.writeSelectionClear(), isFalse);

    final selectAll = writer.writeSelectionSelectAll();
    expect(selectAll, 2);
    expect(writer.selectedNodeIds, const <NodeId>{'rect-1', 'node-2'});
    expect(writer.writeSelectionSelectAll(), 0);
  });

  test('SceneWriter writeNodeErase respects deletable layer policy', () {
    // INV:INV-ENG-WRITE-NUMERIC-GUARDS
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(
            nodes: <SceneNode>[
              RectNode(
                id: 'locked',
                size: const Size(10, 10),
                isDeletable: false,
              ),
              RectNode(id: 'free', size: const Size(10, 10)),
            ],
          ),
        ],
      ),
      workingSelection: <NodeId>{'locked', 'free'},
      baseAllNodeIds: <NodeId>{'locked', 'free'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final writer = SceneWriter(ctx, txnSignalSink: (_) {});

    expect(writer.writeNodeErase('locked'), isFalse);
    expect(writer.writeNodeErase('free'), isTrue);
  });

  test('SceneWriter rejects non-finite grid/camera values', () {
    // INV:INV-ENG-WRITE-NUMERIC-GUARDS
    final ctx = TxnContext(
      baseScene: Scene(),
      workingSelection: <NodeId>{},
      baseAllNodeIds: <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final writer = SceneWriter(ctx, txnSignalSink: (_) {});

    expect(() => writer.writeGridCellSize(double.nan), throwsArgumentError);
    expect(() => writer.writeGridCellSize(0), throwsArgumentError);
    expect(
      () => writer.writeCameraOffset(const Offset(double.infinity, 0)),
      throwsArgumentError,
    );
    expect(
      () => writer.writeCameraOffset(const Offset(0, double.nan)),
      throwsArgumentError,
    );
  });

  test('SceneWriter rejects non-finite transform and translate values', () {
    // INV:INV-ENG-WRITE-NUMERIC-GUARDS
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      ),
      workingSelection: <NodeId>{'r1'},
      baseAllNodeIds: <NodeId>{'r1'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final writer = SceneWriter(ctx, txnSignalSink: (_) {});

    expect(
      () => writer.writeNodeTransformSet(
        'r1',
        const Transform2D(a: double.nan, b: 0, c: 0, d: 1, tx: 0, ty: 0),
      ),
      throwsArgumentError,
    );
    expect(
      () => writer.writeSelectionTransform(
        const Transform2D(a: 1, b: 0, c: 0, d: double.infinity, tx: 0, ty: 0),
      ),
      throwsArgumentError,
    );
    expect(
      () => writer.writeSelectionTranslate(const Offset(double.nan, 0)),
      throwsArgumentError,
    );
  });

  test('writeNodeTransformSet marks visual change when bounds stay same', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(
            nodes: <SceneNode>[
              LineNode(
                id: 'line-static',
                start: Offset.zero,
                end: Offset.zero,
                thickness: 2,
                color: const Color(0xFF000000),
              ),
            ],
          ),
        ],
      ),
      workingSelection: <NodeId>{},
      baseAllNodeIds: <NodeId>{'line-static'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final writer = SceneWriter(ctx, txnSignalSink: (_) {});

    final changed = writer.writeNodeTransformSet(
      'line-static',
      Transform2D.rotationDeg(90),
    );

    expect(changed, isTrue);
    expect(ctx.changeSet.boundsChanged, isFalse);
    expect(ctx.changeSet.visualChanged, isTrue);
  });

  test('SceneWriter covers clear/delete/mark helpers', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(),
          ContentLayer(
            nodes: <SceneNode>[
              RectNode(
                id: 'keep',
                size: const Size(10, 10),
                isDeletable: false,
              ),
              RectNode(id: 'del', size: const Size(10, 10)),
            ],
          ),
        ],
      ),
      workingSelection: <NodeId>{'keep', 'del'},
      baseAllNodeIds: <NodeId>{'keep', 'del'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final writer = SceneWriter(ctx, txnSignalSink: (_) {});

    expect(writer.writeDeleteSelection(), 1);
    expect(
      ctx.workingScene.layers[1].nodes.map((n) => n.id),
      orderedEquals(<NodeId>['keep']),
    );
    expect(ctx.workingSelection, const <NodeId>{'keep'});
    expect(writer.writeDeleteSelection(), 0);

    final cleared = writer.writeClearSceneKeepBackground();
    expect(cleared, const <NodeId>['keep']);
    expect(ctx.workingScene.layers, isEmpty);
    expect(ctx.workingScene.backgroundLayer, isNotNull);
    expect(ctx.workingSelection, isEmpty);
    expect(writer.writeClearSceneKeepBackground(), isEmpty);
    expect(ctx.changeSet.structuralChanged, isTrue);
    expect(ctx.changeSet.boundsChanged, isTrue);
    expect(ctx.changeSet.visualChanged, isTrue);
    expect(ctx.changeSet.selectionChanged, isTrue);
  });

  test(
    'SceneWriter clearScene creates missing background layer and clears',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[ContentLayer(), ContentLayer()],
        ),
        workingSelection: <NodeId>{},
        baseAllNodeIds: <NodeId>{},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final writer = SceneWriter(ctx, txnSignalSink: (_) {});

      expect(writer.writeClearSceneKeepBackground(), isEmpty);
      expect(ctx.workingScene.layers, isEmpty);
      expect(ctx.workingScene.backgroundLayer, isNotNull);
    },
  );

  test(
    'SpatialIndexCache caches, applies incremental changes and falls back safely',
    () {
      final slice = SpatialIndexCache();
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      );
      final nodeLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };

      final first = slice.writeQueryCandidates(
        scene: scene,
        nodeLocator: nodeLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(first, isNotEmpty);
      expect(slice.debugBuildCount, 1);
      expect(slice.debugIncrementalApplyCount, 0);

      slice.writeQueryCandidates(
        scene: scene,
        nodeLocator: nodeLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(slice.debugBuildCount, 1);

      final noChange = ChangeSet();
      slice.writeHandleCommit(
        scene: scene,
        nodeLocator: nodeLocator,
        changeSet: noChange,
        controllerEpoch: 0,
      );
      slice.writeQueryCandidates(
        scene: scene,
        nodeLocator: nodeLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(slice.debugBuildCount, 1);
      expect(slice.debugIncrementalApplyCount, 0);

      final movedScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            nodes: <SceneNode>[
              RectNode(
                id: 'r1',
                size: const Size(10, 10),
                transform: Transform2D.translation(const Offset(100, 0)),
              ),
            ],
          ),
        ],
      );
      final movedLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };
      final movedChange = ChangeSet()
        ..txnMarkBoundsChanged()
        ..txnTrackUpdated('r1')
        ..txnTrackHitGeometryChanged('r1');
      slice.writeHandleCommit(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: movedChange,
        controllerEpoch: 0,
      );
      final movedCandidates = slice.writeQueryCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(movedCandidates, isNotEmpty);
      final oldCandidatesAfterMove = slice.writeQueryCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(oldCandidatesAfterMove, isEmpty);
      expect(slice.debugBuildCount, 1);
      expect(slice.debugIncrementalApplyCount, 1);

      final malformedAdded = ChangeSet()
        ..txnMarkStructuralChanged()
        ..txnTrackAdded('ghost');
      slice.writeHandleCommit(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: malformedAdded,
        controllerEpoch: 0,
      );
      final rebuiltAfterMalformedAdd = slice.writeQueryCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(
        rebuiltAfterMalformedAdd.map((candidate) => candidate.node.id),
        <NodeId>['r1'],
      );
      expect(slice.debugBuildCount, 2);

      final malformedBoundsOnly = ChangeSet()..txnMarkBoundsChanged();
      slice.writeHandleCommit(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: malformedBoundsOnly,
        controllerEpoch: 0,
      );
      slice.writeQueryCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(slice.debugBuildCount, 3);

      slice.writeHandleCommit(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: noChange,
        controllerEpoch: 1,
      );
      slice.writeQueryCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 1,
      );
      expect(slice.debugBuildCount, 4);

      final gridOnly = ChangeSet()..txnMarkGridChanged();
      slice.writeHandleCommit(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: gridOnly,
        controllerEpoch: 1,
      );
      slice.writeQueryCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 1,
      );
      expect(slice.debugBuildCount, 4);

      final outOfRangeScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            nodes: <SceneNode>[
              RectNode(
                id: 'r1',
                size: const Size(10, 10),
                transform: Transform2D.translation(
                  Offset(sceneCoordMax + 500, 0),
                ),
              ),
            ],
          ),
        ],
      );
      final outOfRangeLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };
      final outOfRangeBounds = Rect.fromLTWH(sceneCoordMax + 450, -20, 100, 40);
      final invalidFirst = slice.writeQueryCandidates(
        scene: outOfRangeScene,
        nodeLocator: outOfRangeLocator,
        worldBounds: outOfRangeBounds,
        controllerEpoch: 2,
      );
      expect(invalidFirst, isNotEmpty);
      expect(slice.debugBuildCount, 5);

      final outOfRangeChange = ChangeSet()
        ..txnMarkBoundsChanged()
        ..txnTrackUpdated('r1')
        ..txnTrackHitGeometryChanged('r1');
      slice.writeHandleCommit(
        scene: outOfRangeScene,
        nodeLocator: outOfRangeLocator,
        changeSet: outOfRangeChange,
        controllerEpoch: 2,
      );
      // INV:INV-ENG-SPATIAL-INDEX-REBUILD-ON-INVALID
      final invalidSecond = slice.writeQueryCandidates(
        scene: outOfRangeScene,
        nodeLocator: outOfRangeLocator,
        worldBounds: outOfRangeBounds,
        controllerEpoch: 2,
      );
      expect(invalidSecond, isNotEmpty);
      expect(slice.debugBuildCount, 6);

      final invalidThird = slice.writeQueryCandidates(
        scene: outOfRangeScene,
        nodeLocator: outOfRangeLocator,
        worldBounds: outOfRangeBounds,
        controllerEpoch: 2,
      );
      expect(invalidThird, isNotEmpty);
      expect(slice.debugBuildCount, 6);
    },
  );

  test(
    'SpatialIndexCache falls back to full rebuild when incremental prepare throws',
    () {
      final slice = SpatialIndexCache();
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      );
      final nodeLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };

      slice.writeQueryCandidates(
        scene: scene,
        nodeLocator: nodeLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(slice.debugBuildCount, 1);
      expect(slice.debugIncrementalApplyCount, 0);

      final movedScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            nodes: <SceneNode>[
              RectNode(
                id: 'r1',
                size: const Size(10, 10),
                transform: Transform2D.translation(const Offset(100, 0)),
              ),
            ],
          ),
        ],
      );
      final movedLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };
      final movedChange = ChangeSet()
        ..txnMarkBoundsChanged()
        ..txnTrackUpdated('r1')
        ..txnTrackHitGeometryChanged('r1');

      slice.debugBeforeIncrementalPrepareHook = () {
        throw StateError('forced incremental prepare failure');
      };
      slice.writeHandleCommit(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: movedChange,
        controllerEpoch: 0,
      );

      final movedCandidates = slice.writeQueryCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 0,
      );
      final oldCandidates = slice.writeQueryCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );

      expect(movedCandidates.map((candidate) => candidate.node.id), <NodeId>[
        'r1',
      ]);
      expect(oldCandidates, isEmpty);
      expect(slice.debugBuildCount, 2);
      expect(slice.debugIncrementalApplyCount, 0);
    },
  );

  test(
    'SpatialIndexCache rethrows when fallback rebuild also fails and keeps active index',
    () {
      final slice = SpatialIndexCache();
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      );
      final nodeLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };

      final initialCandidates = slice.writeQueryCandidates(
        scene: scene,
        nodeLocator: nodeLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(initialCandidates.map((candidate) => candidate.node.id), <NodeId>[
        'r1',
      ]);
      expect(slice.debugBuildCount, 1);

      final movedScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            nodes: <SceneNode>[
              RectNode(
                id: 'r1',
                size: const Size(10, 10),
                transform: Transform2D.translation(const Offset(100, 0)),
              ),
            ],
          ),
        ],
      );
      final movedLocator = <NodeId, ({int layerIndex, int nodeIndex})>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };
      final movedChange = ChangeSet()
        ..txnMarkBoundsChanged()
        ..txnTrackUpdated('r1')
        ..txnTrackHitGeometryChanged('r1');

      slice.debugBeforeIncrementalPrepareHook = () {
        throw StateError('forced incremental prepare failure');
      };
      slice.debugBeforeFallbackRebuildHook = () {
        throw StateError('forced fallback rebuild failure');
      };

      expect(
        () => slice.writeHandleCommit(
          scene: movedScene,
          nodeLocator: movedLocator,
          changeSet: movedChange,
          controllerEpoch: 0,
        ),
        throwsStateError,
      );

      final stillOldAtOrigin = slice.writeQueryCandidates(
        scene: scene,
        nodeLocator: nodeLocator,
        worldBounds: const Rect.fromLTWH(0, 0, 20, 20),
        controllerEpoch: 0,
      );
      final noMovedCandidates = slice.writeQueryCandidates(
        scene: movedScene,
        nodeLocator: movedLocator,
        worldBounds: const Rect.fromLTWH(100, 0, 20, 20),
        controllerEpoch: 0,
      );
      expect(stillOldAtOrigin.map((candidate) => candidate.node.id), <NodeId>[
        'r1',
      ]);
      expect(noMovedCandidates, isEmpty);
      expect(slice.debugBuildCount, 1);
      expect(slice.debugIncrementalApplyCount, 0);
    },
  );

  test('RepaintFlag marks/takes once and can discard pending', () {
    final slice = RepaintFlag();

    expect(slice.needsNotify, isFalse);
    expect(slice.writeTakeNeedsNotify(), isFalse);

    slice.writeMarkNeedsRepaint();
    expect(slice.needsNotify, isTrue);
    expect(slice.writeTakeNeedsNotify(), isTrue);
    expect(slice.needsNotify, isFalse);

    slice.writeMarkNeedsRepaint();
    slice.writeDiscardPending();
    expect(slice.needsNotify, isFalse);
  });
}
