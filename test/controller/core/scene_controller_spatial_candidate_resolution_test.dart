import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_store_controller.dart';
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';

// INV:INV-ENG-ID-INDEX-FROM-SCENE
// INV:INV-ENG-COMMITTED-READ-SIDE-HERMETICITY

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

  SceneSpatialCandidateReference hitTestReference(
    SceneHitTestSpatialCandidate candidate,
  ) {
    return (
      nodeId: candidate.nodeId,
      layerIndex: candidate.layerIndex,
      nodeIndex: candidate.nodeIndex,
      structuralRevision: candidate.structuralRevision,
    );
  }

  SceneSpatialCandidateReference paintReference(
    ScenePaintSpatialCandidate candidate,
  ) {
    return (
      nodeId: candidate.nodeId,
      layerIndex: candidate.layerIndex,
      nodeIndex: candidate.nodeIndex,
      structuralRevision: candidate.structuralRevision,
    );
  }

  test(
    'resolveSpatialCandidateSnapshot accepts valid foreground candidate',
    () {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final candidates = controller.queryHitTestCandidates(
        const Rect.fromLTWH(0, 0, 0, 0),
      );
      expect(candidates, isNotEmpty);

      final resolved = controller.resolveSpatialCandidateSnapshot(
        hitTestReference(candidates.first),
      );
      expect(resolved, isNotNull);
      expect(resolved?.id, candidates.first.nodeId);
    },
  );

  test(
    'resolveSpatialCandidateSnapshot accepts current background paint candidate',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'bg-node', size: Size(10, 10)),
            ],
          ),
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-1'),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final backgroundCandidate = controller
          .queryPaintCandidates(
            const Rect.fromLTWH(0, 0, 20, 20),
            scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
          )
          .single;
      final resolved = controller.resolveSpatialCandidateSnapshot(
        paintReference(backgroundCandidate),
      );

      expect(backgroundCandidate.layerIndex, -1);
      expect(resolved, isNotNull);
      expect(resolved?.id, 'bg-node');
    },
  );

  test('queryPaintCandidates remains content-only by default', () {
    final controller = SceneStoreController(
      initialSnapshot: SceneSnapshot(
        backgroundLayer: BackgroundLayerSnapshot(
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(id: 'bg-node', size: Size(10, 10)),
          ],
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-1',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'fg-node', size: Size(10, 10)),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    expect(
      controller
          .queryPaintCandidates(const Rect.fromLTWH(0, 0, 20, 20))
          .map((candidate) => candidate.nodeId),
      <NodeId>['fg-node'],
    );
    expect(
      controller
          .queryPaintCandidates(
            const Rect.fromLTWH(0, 0, 20, 20),
            scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
          )
          .map((candidate) => candidate.nodeId)
          .toSet(),
      <NodeId>{'bg-node', 'fg-node'},
    );
  });

  test(
    'resolveSpatialCandidateSnapshot rejects stale background candidate',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'bg-node', size: Size(10, 10)),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);

      final stale = controller
          .queryPaintCandidates(
            const Rect.fromLTWH(0, 0, 20, 20),
            scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
          )
          .single;

      controller.writeReplaceScene(
        SceneSnapshot(backgroundLayer: BackgroundLayerSnapshot()),
      );

      expect(
        controller.resolveSpatialCandidateSnapshot((
          nodeId: stale.nodeId,
          layerIndex: stale.layerIndex,
          nodeIndex: stale.nodeIndex,
          structuralRevision: stale.structuralRevision,
        )),
        isNull,
      );
    },
  );

  test(
    'resolveSpatialCandidateSnapshot rejects out-of-range background candidate',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'bg-node', size: Size(10, 10)),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);

      expect(
        controller.resolveSpatialCandidateSnapshot(const (
          nodeId: 'bg-node',
          layerIndex: -1,
          nodeIndex: 99,
          structuralRevision: 0,
        )),
        isNull,
      );
    },
  );

  test('resolveSpatialCandidateSnapshot rejects out-of-range indices', () {
    final controller = SceneStoreController(initialSnapshot: twoRectSnapshot());
    addTearDown(controller.dispose);

    const outOfRangeLayer = (
      nodeId: 'r1',
      layerIndex: 99,
      nodeIndex: 0,
      structuralRevision: 0,
    );
    const outOfRangeNode = (
      nodeId: 'r1',
      layerIndex: 0,
      nodeIndex: 99,
      structuralRevision: 0,
    );

    expect(controller.resolveSpatialCandidateSnapshot(outOfRangeLayer), isNull);
    expect(controller.resolveSpatialCandidateSnapshot(outOfRangeNode), isNull);
  });

  test(
    'resolveSpatialCandidateSnapshot rejects stale identity after replaceScene',
    () {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final stale = controller
          .queryHitTestCandidates(const Rect.fromLTWH(0, 0, 0, 0))
          .first;

      controller.writeReplaceScene(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-2',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'fresh-1', size: Size(10, 10)),
                RectNodeSnapshot(id: 'fresh-2', size: Size(12, 12)),
              ],
            ),
          ],
        ),
      );

      expect(
        controller.resolveSpatialCandidateSnapshot((
          nodeId: stale.nodeId,
          layerIndex: stale.layerIndex,
          nodeIndex: stale.nodeIndex,
          structuralRevision: stale.structuralRevision,
        )),
        isNull,
      );
    },
  );

  test(
    'resolveSpatialCandidateSnapshot rejects same-id stale foreground candidate after replaceScene',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-0',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'reused', size: Size(10, 10)),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final stale = controller
          .queryHitTestCandidates(const Rect.fromLTWH(0, 0, 10, 10))
          .single;

      controller.writeReplaceScene(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-1',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'reused', size: Size(20, 20)),
              ],
            ),
          ],
        ),
      );

      expect(
        controller.resolveSpatialCandidateSnapshot((
          nodeId: stale.nodeId,
          layerIndex: stale.layerIndex,
          nodeIndex: stale.nodeIndex,
          structuralRevision: stale.structuralRevision,
        )),
        isNull,
      );
    },
  );

  test(
    'resolveSpatialCandidateSnapshot rejects same-id stale background candidate after replaceScene',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'bg-reused', size: Size(10, 10)),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);

      final stale = controller
          .queryPaintCandidates(
            const Rect.fromLTWH(0, 0, 10, 10),
            scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
          )
          .single;

      controller.writeReplaceScene(
        SceneSnapshot(
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'bg-reused', size: Size(20, 20)),
            ],
          ),
        ),
      );

      expect(
        controller.resolveSpatialCandidateSnapshot((
          nodeId: stale.nodeId,
          layerIndex: stale.layerIndex,
          nodeIndex: stale.nodeIndex,
          structuralRevision: stale.structuralRevision,
        )),
        isNull,
      );
    },
  );

  test(
    'resolveSpatialCandidateSnapshot rejects same-id stale candidate after structural rewrite',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-0',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'reused', size: Size(10, 10)),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      final stale = controller
          .queryHitTestCandidates(const Rect.fromLTWH(0, 0, 10, 10))
          .single;

      controller.write<void>((writer) {
        expect(writer.writeNodeErase('reused'), isTrue);
        writer.writeNodeInsert(
          RectNodeSpec(id: 'reused', size: const Size(20, 20)),
          insertIndex: 0,
        );
      });

      expect(
        controller.resolveSpatialCandidateSnapshot((
          nodeId: stale.nodeId,
          layerIndex: stale.layerIndex,
          nodeIndex: stale.nodeIndex,
          structuralRevision: stale.structuralRevision,
        )),
        isNull,
      );
    },
  );

  test(
    'resolveSpatialCandidateSnapshot accepts non-geometry clone after selection write',
    () {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final candidate = controller
          .queryHitTestCandidates(const Rect.fromLTWH(0, 0, 0, 0))
          .first;

      controller.write<void>((writer) {
        writer.writeSelectionReplace(const <NodeId>{'r1'});
      });

      final resolved = controller.resolveSpatialCandidateSnapshot(
        hitTestReference(candidate),
      );
      expect(resolved, isNotNull);
      if (resolved == null) {
        fail('Expected spatial candidate resolution to return selected node.');
      }
      expect(resolved.id, candidate.nodeId);
      expect(resolved, isA<RectNodeSnapshot>());
    },
  );

  test(
    'resolveSnapshotNodeById accepts valid content locator and validates id at location',
    () {
      final controller = SceneStoreController(
        initialSnapshot: twoRectSnapshot(),
      );
      addTearDown(controller.dispose);

      final resolved = controller.resolveSnapshotNodeById('r2');

      expect(resolved, isNotNull);
      expect(resolved?.layerIndex, 0);
      expect(resolved?.nodeIndex, 1);
      expect(resolved?.node.id, 'r2');
    },
  );

  test(
    'resolveSnapshotNodeById supports background locator with layerIndex -1',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          backgroundLayer: BackgroundLayerSnapshot(
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'bg-node', size: Size(10, 10)),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);

      final resolved = controller.resolveSnapshotNodeById('bg-node');

      expect(resolved, isNotNull);
      expect(resolved?.layerIndex, -1);
      expect(resolved?.nodeIndex, 0);
      expect(resolved?.node.id, 'bg-node');
    },
  );

  test(
    'resolveSnapshotNodeById rejects stale locator after replaceScene without snapshot scan fallback',
    () {
      final controller = SceneStoreController(
        initialSnapshot: SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-0',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'stale', size: Size(10, 10)),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.resolveSnapshotNodeById('stale'), isNotNull);

      controller.writeReplaceScene(
        SceneSnapshot(
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-1',
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'fresh', size: Size(10, 10)),
                RectNodeSnapshot(id: 'stale', size: Size(10, 10)),
              ],
            ),
          ],
        ),
      );

      expect(controller.resolveSnapshotNodeById('stale')?.nodeIndex, 1);
      expect(
        controller.resolveSpatialCandidateSnapshot(const (
          nodeId: 'stale',
          layerIndex: 0,
          nodeIndex: 0,
          structuralRevision: 0,
        )),
        isNull,
      );
    },
  );
}
