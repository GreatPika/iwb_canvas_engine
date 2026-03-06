import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/controller/scene_writer.dart';
import 'package:iwb_canvas_engine/src/controller/txn_context.dart';
import 'package:iwb_canvas_engine/src/controller/internal/signal_event.dart';

// INV:INV-ENG-WRITE-NUMERIC-GUARDS

void main() {
  test('SceneWriter handles write operations and updates changeset', () {
    final bufferedSignals = <BufferedSignal>[];
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-1',
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
      throwsA(
        isA<ArgumentError>().having((error) => error.name, 'name', 'spec.id'),
      ),
    );

    final generatedId = writer.writeNodeInsert(
      RectNodeSpec(size: const Size(2, 2)),
    );
    expect(generatedId, 'node-0');
    expect(ctx.changeSet.structuralChanged, isTrue);
    expect(ctx.changeSet.addedNodeIds, contains('node-0'));

    expect(writer.writeNodePatch(RectNodePatch(id: 'missing')), isFalse);
    expect(writer.writeNodePatch(RectNodePatch(id: 'r1')), isFalse);
    expect(
      writer.writeNodePatch(
        RectNodePatch(id: 'r1', strokeWidth: PatchField<double>.value(2)),
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
            id: 'layer-auto-0',
            nodes: <NodeSnapshot>[
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
              id: 'layer-auto-2',
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

  test('SceneWriter selectedNodeIds exposes immutable transaction view', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-2b',
            nodes: <SceneNode>[RectNode(id: 'r1', size: const Size(10, 10))],
          ),
        ],
      ),
      workingSelection: <NodeId>{'r1'},
      baseAllNodeIds: const <NodeId>{'r1'},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final writer = SceneWriter(ctx, txnSignalSink: (_) {});

    expect(() => writer.selectedNodeIds.add('other'), throwsUnsupportedError);
    expect(writer.selectedNodeIds, const <NodeId>{'r1'});
  });

  test(
    'SceneWriter selection hot-path keeps in-place set on 1000 toggle/replace/erase ops',
    () {
      final nodes = <SceneNode>[
        for (var i = 0; i < 1000; i++)
          RectNode(id: 'n$i', size: const Size(10, 10)),
      ];
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-3', nodes: nodes),
          ],
        ),
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

  test('SceneWriter writeNodeInsert resolves target layer by layerId', () {
    final baseScene = Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-auto-10'),
        ContentLayer(id: 'layer-auto-11'),
      ],
    );
    final ctx = TxnContext(
      baseScene: baseScene,
      workingSelection: <NodeId>{},
      baseAllNodeIds: const <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final writer = SceneWriter(ctx, txnSignalSink: (_) {});

    final insertedId = writer.writeNodeInsert(
      RectNodeSpec(id: 'n-target', size: const Size(3, 3)),
      layerId: 'layer-auto-10',
    );
    expect(insertedId, 'n-target');
    expect(ctx.workingScene.layers[0].nodes.single.id, 'n-target');
    expect(ctx.workingScene.layers[1].nodes, isEmpty);

    expect(
      () => writer.writeNodeInsert(
        RectNodeSpec(id: 'bad-target', size: const Size(1, 1)),
        layerId: 'missing-layer',
      ),
      throwsArgumentError,
    );

    final emptyCtx = TxnContext(
      baseScene: Scene(),
      workingSelection: <NodeId>{},
      baseAllNodeIds: const <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final emptyWriter = SceneWriter(emptyCtx, txnSignalSink: (_) {});
    final autoInsertedId = emptyWriter.writeNodeInsert(
      RectNodeSpec(id: 'first', size: const Size(2, 2)),
    );
    expect(autoInsertedId, 'first');
    expect(emptyCtx.workingScene.layers, hasLength(1));
    expect(emptyCtx.workingScene.layers.single.id, 'layer-0');
    expect(emptyCtx.workingScene.layers.single.nodes.single.id, 'first');
  });

  test(
    'SceneWriter inserts nodes at explicit index and shifts locator state',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-12',
              nodes: <SceneNode>[
                RectNode(id: 'first', size: const Size(1, 1)),
                RectNode(id: 'last', size: const Size(1, 1)),
              ],
            ),
          ],
        ),
        workingSelection: <NodeId>{},
        baseAllNodeIds: const <NodeId>{'first', 'last'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final writer = SceneWriter(ctx, txnSignalSink: (_) {});

      writer.writeNodeInsert(
        RectNodeSpec(id: 'middle', size: const Size(2, 2)),
        insertIndex: 1,
      );

      expect(
        ctx.workingScene.layers.single.nodes
            .map((node) => node.id)
            .toList(growable: false),
        <String>['first', 'middle', 'last'],
      );
      expect(ctx.txnFindNodeById('last')?.nodeIndex, 2);
      expect(
        () => writer.writeNodeInsert(
          RectNodeSpec(id: 'bad', size: const Size(1, 1)),
          insertIndex: 4,
        ),
        throwsRangeError,
      );
    },
  );

  test(
    'SceneWriter ensure layer is idempotent and updates shifted lookups',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-20'),
            ContentLayer(
              id: 'layer-auto-21',
              nodes: <SceneNode>[RectNode(id: 'tail', size: const Size(1, 1))],
            ),
          ],
        ),
        workingSelection: <NodeId>{},
        baseAllNodeIds: const <NodeId>{'tail'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final writer = SceneWriter(ctx, txnSignalSink: (_) {});

      expect(writer.writeLayerEnsure('inserted', index: 1), isTrue);
      expect(writer.writeLayerEnsure('inserted', index: 0), isFalse);
      expect(
        ctx.workingScene.layers
            .map((layer) => layer.id)
            .toList(growable: false),
        <String>['layer-auto-20', 'inserted', 'layer-auto-21'],
      );
      expect(ctx.txnFindNodeById('tail')?.layerIndex, 2);
      expect(
        writer.writeNodeTransformSet(
          'tail',
          Transform2D.translation(const Offset(3, 0)),
        ),
        isTrue,
      );
      expect(() => writer.writeLayerEnsure('bad', index: 5), throwsRangeError);
    },
  );

  test('SceneWriter applies default text font family only when absent', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[ContentLayer(id: 'layer-auto-22')],
      ),
      workingSelection: <NodeId>{},
      baseAllNodeIds: const <NodeId>{},
      nodeIdSeed: 0,
      nextInstanceRevision: 1,
    );
    final writer = SceneWriter(
      ctx,
      txnSignalSink: (_) {},
      textFontFamilyByDefault: 'Mono',
    );

    writer.writeNodeInsert(
      TextNodeSpec(
        id: 'default-font',
        text: 'hello',
        color: const Color(0xFF111111),
      ),
    );
    writer.writeNodeInsert(
      TextNodeSpec(
        id: 'explicit-font',
        text: 'world',
        color: const Color(0xFF111111),
        fontFamily: 'Serif',
      ),
    );

    final nodes = ctx.workingScene.layers.single.nodes
        .whereType<TextNode>()
        .toList(growable: false);
    expect(nodes[0].fontFamily, 'Mono');
    expect(nodes[1].fontFamily, 'Serif');
  });

  test('SceneWriter covers id generation and selection branches', () {
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-4',
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

  test(
    'SceneWriter selection replace keeps current selection on empty normalized input',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          backgroundLayer: BackgroundLayer(
            nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(4, 4))],
          ),
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-4b',
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
        workingSelection: <NodeId>{'visible'},
        baseAllNodeIds: const <NodeId>{'bg', 'visible', 'hidden'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final writer = SceneWriter(ctx, txnSignalSink: (_) {});

      expect(writer.writeSelectionReplace(const <NodeId>{}), isFalse);
      expect(
        writer.writeSelectionReplace(const <NodeId>{'missing', 'bg', 'hidden'}),
        isFalse,
      );
      expect(writer.selectedNodeIds, const <NodeId>{'visible'});
    },
  );

  test('SceneWriter writeNodeErase respects deletable layer policy', () {
    // INV:INV-ENG-WRITE-NUMERIC-GUARDS
    final ctx = TxnContext(
      baseScene: Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-5',
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
            id: 'layer-auto-6',
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
      () => writer.writeNodeTransformSet(
        'r1',
        const Transform2D(a: 1, b: 2, c: 2, d: 4, tx: 0, ty: 0),
      ),
      throwsArgumentError,
    );
    expect(
      () => writer.writeSelectionTransform(
        const Transform2D(a: 1, b: 2, c: 2, d: 4, tx: 0, ty: 0),
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
            id: 'layer-auto-7',
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
          ContentLayer(id: 'layer-auto-8'),
          ContentLayer(
            id: 'layer-auto-9',
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

    final cleared = writer.writeClearSceneKeepBackgroundResult();
    expect(cleared.removedNodeIds, const <NodeId>['keep']);
    expect(cleared.didStructuralClear, isTrue);
    expect(ctx.workingScene.layers, isEmpty);
    expect(ctx.workingScene.backgroundLayer, isNotNull);
    expect(ctx.workingSelection, isEmpty);
    final clearNoop = writer.writeClearSceneKeepBackgroundResult();
    expect(clearNoop.removedNodeIds, isEmpty);
    expect(clearNoop.didStructuralClear, isFalse);
    expect(ctx.changeSet.structuralChanged, isTrue);
    expect(ctx.changeSet.boundsChanged, isTrue);
    expect(ctx.changeSet.visualChanged, isTrue);
    expect(ctx.changeSet.selectionChanged, isTrue);
  });

  test('ClearSceneResult exposes immutable removedNodeIds snapshot', () {
    final result = ClearSceneResult(
      removedNodeIds: <NodeId>['a'],
      didStructuralClear: true,
    );

    expect(() => result.removedNodeIds.add('b'), throwsUnsupportedError);
    expect(result.removedNodeIds, <NodeId>['a']);
  });

  test(
    'writeClearSceneKeepBackground returns immutable removedNodeIds snapshot',
    () {
      final ctx = TxnContext(
        baseScene: Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-9b',
              nodes: <SceneNode>[RectNode(id: 'gone', size: const Size(1, 1))],
            ),
          ],
        ),
        workingSelection: const <NodeId>{},
        baseAllNodeIds: const <NodeId>{'gone'},
        nodeIdSeed: 0,
        nextInstanceRevision: 1,
      );
      final writer = SceneWriter(ctx, txnSignalSink: (_) {});

      final removedNodeIds = writer.writeClearSceneKeepBackground();

      expect(removedNodeIds, const <NodeId>['gone']);
      expect(() => removedNodeIds.add('other'), throwsUnsupportedError);
    },
  );

  test('ClearSceneResult defensively copies removedNodeIds source', () {
    final source = <NodeId>['a'];
    final result = ClearSceneResult(
      removedNodeIds: source,
      didStructuralClear: false,
    );

    source.add('b');
    expect(result.removedNodeIds, <NodeId>['a']);
  });
}
