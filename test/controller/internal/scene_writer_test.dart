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
}
