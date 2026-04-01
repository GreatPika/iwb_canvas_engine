import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';

// INV:INV-ENG-TXN-COPY-ON-WRITE
// INV:INV-ENG-TEXT-SIZE-DERIVED

void main() {
  SceneSnapshot twoRectSnapshot() {
    return SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-0',
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(id: 'r1', size: Size(10, 10)),
            RectNodeSnapshot(id: 'r2', size: Size(12, 12)),
          ],
        ),
      ],
    );
  }

  test('no-op hitPadding patch does not bump bounds revision', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    final beforeBounds = controller.boundsRevision;

    controller.write<void>((writer) {
      writer.writeNodePatch(
        RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(hitPadding: PatchField<double>.value(0)),
        ),
      );
    });

    expect(controller.boundsRevision, beforeBounds);
    expect(controller.debug.lastChangeSet.boundsChanged, isFalse);
    expect(controller.debug.lastChangeSet.hitGeometryChangedIds, isEmpty);
    expect(controller.debug.sceneShallowClones, 0);
    expect(controller.debug.layerShallowClones, 0);
    expect(controller.debug.nodeClones, 0);
  });

  test(
    'text layout patch recomputes derived size and bumps bounds revision',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-1',
              nodes: <NodeSnapshot>[
                TextNodeSnapshot(
                  id: 't1',
                  text: 'hello',
                  size: Size(1, 1),
                  fontSize: 12,
                  color: Color(0xFF000000),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final beforeNode =
          controller.snapshot.layers.first.nodes.single as TextNodeSnapshot;
      final beforeSize = beforeNode.size;
      final beforeBoundsRevision = controller.boundsRevision;

      controller.write<void>((writer) {
        writer.writeNodePatch(
          TextNodePatch(id: 't1', fontSize: PatchField<double>.value(36)),
        );
      });

      final afterNode =
          controller.snapshot.layers.first.nodes.single as TextNodeSnapshot;
      expect(afterNode.size.height, greaterThan(beforeSize.height));
      expect(controller.boundsRevision, beforeBoundsRevision + 1);
      expect(controller.debug.lastChangeSet.boundsChanged, isTrue);
      expect(
        controller.debug.lastChangeSet.hitGeometryChangedIds,
        contains('t1'),
      );
    },
  );

  test(
    'textDirection patch updates snapshot through controller write path',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-1b',
              nodes: <NodeSnapshot>[
                TextNodeSnapshot(
                  id: 't-dir',
                  text: 'abc אבג',
                  size: const Size(1, 1),
                  fontSize: 24,
                  color: const Color(0xFF000000),
                  textDirection: TextDirection.ltr,
                  align: TextAlign.start,
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final beforeNode =
          controller.snapshot.layers.first.nodes.single as TextNodeSnapshot;

      controller.write<void>((writer) {
        writer.writeNodePatch(
          TextNodePatch(
            id: 't-dir',
            textDirection: PatchField<TextDirection>.value(TextDirection.rtl),
          ),
        );
      });

      final afterNode =
          controller.snapshot.layers.first.nodes.single as TextNodeSnapshot;
      expect(beforeNode.textDirection, TextDirection.ltr);
      expect(afterNode.textDirection, TextDirection.rtl);
      expect(afterNode.size, isNot(const Size(1, 1)));
    },
  );

  test('text visual-only patch keeps bounds revision unchanged', () {
    final controller = SceneControllerCore(
      initialSnapshot: SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-2',
            nodes: <NodeSnapshot>[
              TextNodeSnapshot(
                id: 't1',
                text: 'hello',
                size: Size(80, 24),
                fontSize: 24,
                color: Color(0xFF000000),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    final beforeBoundsRevision = controller.boundsRevision;

    controller.write<void>((writer) {
      writer.writeNodePatch(
        TextNodePatch(
          id: 't1',
          color: PatchField<Color>.value(Color(0xFF00AA00)),
        ),
      );
    });

    expect(controller.boundsRevision, beforeBoundsRevision);
    expect(controller.debug.lastChangeSet.boundsChanged, isFalse);
    expect(controller.debug.lastChangeSet.hitGeometryChangedIds, isEmpty);
  });

  test('camera offset write does not clone layers or nodes', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeCameraOffset(const Offset(20, 10));
    });

    expect(controller.debug.sceneShallowClones, 1);
    expect(controller.debug.layerShallowClones, 0);
    expect(controller.debug.nodeClones, 0);
  });

  test('single node patch clones exactly one layer and one node', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        RectNodePatch(id: 'r1', strokeWidth: PatchField<double>.value(2)),
      );
    });

    expect(controller.debug.sceneShallowClones, 1);
    expect(controller.debug.layerShallowClones, 1);
    expect(controller.debug.nodeClones, 1);
  });

  test('opacity patch commit does not materialize allNodeIds', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(opacity: PatchField<double>.value(0.5)),
        ),
      );
    });

    expect(controller.debug.nodeIdSetMaterializations, 0);
    expect(controller.debug.nodeLocatorMaterializations, 0);
  });

  test('structural commit materializes allNodeIds once', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodeInsert(RectNodeSpec(size: const Size(8, 8)));
    });

    expect(controller.debug.nodeIdSetMaterializations, 1);
    expect(controller.debug.nodeLocatorMaterializations, 1);
  });

  test(
    'node allocation stays runtime-owned after deleting explicit max id',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-3',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'node-1', size: Size(10, 10)),
                RectNodeSnapshot(id: 'node-9', size: Size(12, 12)),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.write<void>((writer) {
        writer.writeNodeErase('node-9');
      });

      late final NodeId generatedId;
      controller.write<void>((writer) {
        generatedId = writer.writeNodeInsert(
          RectNodeSpec(size: const Size(6, 6)),
        );
      });

      expect(generatedId, startsWith('gen-n-'));
      expect(generatedId, isNot(anyOf('node-1', 'node-9')));
    },
  );

  test(
    'replaceScene keeps runtime revision allocator independent from snapshot max',
    () {
      final controller = SceneControllerCore(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-4',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'high',
                  instanceRevision: 100,
                  size: Size(10, 10),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.writeReplaceScene(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-5',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(
                  id: 'low',
                  instanceRevision: 3,
                  size: Size(10, 10),
                ),
              ],
            ),
          ],
        ),
      );

      late final NodeId insertedId;
      controller.write<void>((writer) {
        insertedId = writer.writeNodeInsert(
          RectNodeSpec(size: const Size(4, 4)),
        );
      });

      final inserted = controller.snapshot.layers
          .expand((layer) => layer.nodes)
          .firstWhere((node) => node.id == insertedId);
      expect(controller.controllerEpoch, 1);
      expect(inserted.instanceRevision, 1);
    },
  );
}
