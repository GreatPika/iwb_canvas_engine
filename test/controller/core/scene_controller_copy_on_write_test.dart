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
        const RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(hitPadding: PatchField<double>.value(0)),
        ),
      );
    });

    expect(controller.boundsRevision, beforeBounds);
    expect(controller.debugLastChangeSet.boundsChanged, isFalse);
    expect(controller.debugLastChangeSet.hitGeometryChangedIds, isEmpty);
    expect(controller.debugSceneShallowClones, 0);
    expect(controller.debugLayerShallowClones, 0);
    expect(controller.debugNodeClones, 0);
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
          const TextNodePatch(id: 't1', fontSize: PatchField<double>.value(36)),
        );
      });

      final afterNode =
          controller.snapshot.layers.first.nodes.single as TextNodeSnapshot;
      expect(afterNode.size.height, greaterThan(beforeSize.height));
      expect(controller.boundsRevision, beforeBoundsRevision + 1);
      expect(controller.debugLastChangeSet.boundsChanged, isTrue);
      expect(
        controller.debugLastChangeSet.hitGeometryChangedIds,
        contains('t1'),
      );
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
        const TextNodePatch(
          id: 't1',
          color: PatchField<Color>.value(Color(0xFF00AA00)),
        ),
      );
    });

    expect(controller.boundsRevision, beforeBoundsRevision);
    expect(controller.debugLastChangeSet.boundsChanged, isFalse);
    expect(controller.debugLastChangeSet.hitGeometryChangedIds, isEmpty);
  });

  test('camera offset write does not clone layers or nodes', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeCameraOffset(const Offset(20, 10));
    });

    expect(controller.debugSceneShallowClones, 1);
    expect(controller.debugLayerShallowClones, 0);
    expect(controller.debugNodeClones, 0);
  });

  test('single node patch clones exactly one layer and one node', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const RectNodePatch(id: 'r1', strokeWidth: PatchField<double>.value(2)),
      );
    });

    expect(controller.debugSceneShallowClones, 1);
    expect(controller.debugLayerShallowClones, 1);
    expect(controller.debugNodeClones, 1);
  });

  test('opacity patch commit does not materialize allNodeIds', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodePatch(
        const RectNodePatch(
          id: 'r1',
          common: CommonNodePatch(opacity: PatchField<double>.value(0.5)),
        ),
      );
    });

    expect(controller.debugNodeIdSetMaterializations, 0);
    expect(controller.debugNodeLocatorMaterializations, 0);
  });

  test('structural commit materializes allNodeIds once', () {
    final controller = SceneControllerCore(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    controller.write<void>((writer) {
      writer.writeNodeInsert(RectNodeSpec(size: const Size(8, 8)));
    });

    expect(controller.debugNodeIdSetMaterializations, 1);
    expect(controller.debugNodeLocatorMaterializations, 1);
  });

  test('node id seed stays monotonic after deleting max node-* id', () {
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

    expect(generatedId, 'node-10');
  });

  test('nextInstanceRevision stays monotonic across replaceScene', () {
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
      insertedId = writer.writeNodeInsert(RectNodeSpec(size: const Size(4, 4)));
    });

    final inserted = controller.snapshot.layers
        .expand((layer) => layer.nodes)
        .firstWhere((node) => node.id == insertedId);
    expect(inserted.instanceRevision, greaterThanOrEqualTo(101));
  });
}
