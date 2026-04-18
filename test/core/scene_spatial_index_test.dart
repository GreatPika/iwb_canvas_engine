import 'dart:collection';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/core/hit_test.dart';
import 'package:iwb_canvas_engine/src/core/node_geometry.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart';
import 'package:iwb_canvas_engine/src/core/scene_spatial_index.dart';

class _ThrowingLookupMap<K, V> extends MapBase<K, V> {
  _ThrowingLookupMap(this._delegate);

  final Map<K, V> _delegate;

  @override
  V? operator [](Object? key) => throw StateError('lookup failed');

  @override
  void operator []=(K key, V value) {
    _delegate[key] = value;
  }

  @override
  void clear() {
    _delegate.clear();
  }

  @override
  Iterable<K> get keys => _delegate.keys;

  @override
  V? remove(Object? key) => _delegate.remove(key);
}

class _ThrowingContainsKeyMap<K, V> extends MapBase<K, V> {
  _ThrowingContainsKeyMap(this._delegate);

  final Map<K, V> _delegate;

  @override
  V? operator [](Object? key) => _delegate[key];

  @override
  void operator []=(K key, V value) {
    _delegate[key] = value;
  }

  @override
  void clear() {
    _delegate.clear();
  }

  @override
  bool containsKey(Object? key) => throw StateError('containsKey failed');

  @override
  Iterable<K> get keys => _delegate.keys;

  @override
  V? remove(Object? key) => _delegate.remove(key);
}

class _ThrowingLayersScene extends Scene {
  _ThrowingLayersScene();

  @override
  List<ContentLayer> get layers => throw StateError('layers failed');
}

class _CountingLayersScene extends Scene {
  _CountingLayersScene(this._layers);

  final List<ContentLayer> _layers;
  int layerReadCount = 0;

  @override
  List<ContentLayer> get layers {
    layerReadCount = layerReadCount + 1;
    return _layers;
  }
}

void main() {
  Scene sceneWithRect(RectNode node) {
    return Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-auto-0', nodes: <SceneNode>[node]),
      ],
    );
  }

  RectNode rectCoveringCells({
    required String id,
    required double width,
    required double height,
  }) {
    return RectNode(
      id: id,
      size: Size(width, height),
      transform: Transform2D.translation(Offset(width / 2 + 4, height / 2 + 4)),
    );
  }

  test('huge bounds route node to large candidates and query returns it', () {
    final scene = sceneWithRect(
      RectNode(id: 'huge', size: const Size(1e6, 1e6)),
    );

    final index = SceneSpatialIndex.build(scene);
    final candidates = index.queryHitTestCandidates(
      const Rect.fromLTWH(0, 0, 10, 10),
    );

    expect(index.debugLargeCandidateCount, 1);
    expect(index.debugCellCount, 0);
    expect(candidates.map((candidate) => candidate.nodeId), <NodeId>['huge']);
  });

  test(
    'out-of-range node marks index invalid and serves repeated linear fallback queries',
    () {
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-1',
            nodes: <SceneNode>[
              RectNode(
                id: 'oor',
                size: const Size(10, 10),
                transform: Transform2D.translation(
                  Offset(sceneCoordMax + 500, 0),
                ),
              ),
            ],
          ),
        ],
      );
      final queryRect = Rect.fromLTWH(sceneCoordMax + 450, -20, 100, 40);

      final index = SceneSpatialIndex.build(scene);
      expect(index.isValid, isFalse);

      final first = index.queryHitTestCandidates(queryRect);
      final second = index.queryHitTestCandidates(queryRect);

      expect(first.map((candidate) => candidate.nodeId), <NodeId>['oor']);
      expect(second.map((candidate) => candidate.nodeId), <NodeId>['oor']);
      expect(index.debugFallbackQueryCount, 2);
      expect(index.debugCellCount, 0);
      expect(index.debugLargeCandidateCount, 0);
    },
  );

  test('out-of-range query falls back linearly without invalidating index', () {
    final scene = sceneWithRect(
      RectNode(id: 'regular', size: const Size(100, 100)),
    );
    final index = SceneSpatialIndex.build(scene);

    final candidates = index.queryHitTestCandidates(
      Rect.fromLTWH(sceneCoordMax + 10, sceneCoordMax + 10, 20, 20),
    );

    expect(candidates, isEmpty);
    expect(index.isValid, isTrue);
    expect(index.debugFallbackQueryCount, 1);
  });

  test('regular bounds still use grid cells', () {
    final scene = sceneWithRect(
      RectNode(id: 'regular', size: const Size(100, 100)),
    );

    final index = SceneSpatialIndex.build(scene);
    final candidates = index.queryHitTestCandidates(
      const Rect.fromLTWH(0, 0, 10, 10),
    );

    expect(index.debugLargeCandidateCount, 0);
    expect(index.debugCellCount, greaterThan(0));
    expect(candidates.map((candidate) => candidate.nodeId), <NodeId>[
      'regular',
    ]);
  });

  test('query candidates use shared runtime geometry contract', () {
    final line = LineNode(
      id: 'line-shared-contract',
      start: const Offset(-10, 0),
      end: const Offset(10, 0),
      thickness: 4,
      color: const Color(0xFF000000),
      hitPadding: 2,
    )..position = const Offset(15, 12);
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-auto-shared', nodes: <SceneNode>[line]),
      ],
    );

    final index = SceneSpatialIndex.build(scene);
    final hitTestCandidate = index
        .queryHitTestCandidates(const Rect.fromLTWH(0, 0, 40, 40))
        .single;
    final paintCandidate = index
        .queryPaintCandidates(const Rect.fromLTWH(0, 0, 40, 40))
        .single;

    expect(
      hitTestCandidate.hitTestBoundsWorld,
      nodeHitTestCandidateBoundsWorld(line),
    );
    expect(paintCandidate.paintBoundsWorld, nodePaintBoundsWorld(line));
  });

  test('paint query excludes hit-test-only overlap ring', () {
    final line = LineNode(
      id: 'line-hit-only-ring',
      start: const Offset(-10, 0),
      end: const Offset(10, 0),
      thickness: 4,
      color: const Color(0xFF000000),
      hitPadding: 20,
    )..position = const Offset(15, 12);
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-hit-only-ring', nodes: <SceneNode>[line]),
      ],
    );

    final index = SceneSpatialIndex.build(scene);
    final ringProbe = const Rect.fromLTWH(35, 10, 2, 4);

    expect(
      index
          .queryHitTestCandidates(ringProbe)
          .map((candidate) => candidate.nodeId),
      <NodeId>['line-hit-only-ring'],
    );
    expect(index.queryPaintCandidates(ringProbe), isEmpty);
  });

  test('paint scope includes background while hit-test stays content-only', () {
    final scene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[
          RectNode(
            id: 'bg',
            size: const Size(20, 20),
            transform: Transform2D.translation(const Offset(10, 10)),
          ),
        ],
      ),
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-scope',
          nodes: <SceneNode>[
            RectNode(
              id: 'fg',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(10, 10)),
            ),
          ],
        ),
      ],
    );

    final index = SceneSpatialIndex.build(scene);
    final query = const Rect.fromLTWH(0, 0, 40, 40);

    expect(
      index.queryPaintCandidates(query).map((candidate) => candidate.nodeId),
      <NodeId>['fg'],
    );
    expect(
      index
          .queryPaintCandidates(
            query,
            scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
          )
          .map((candidate) => candidate.nodeId)
          .toSet(),
      <NodeId>{'bg', 'fg'},
    );
    expect(
      index.queryHitTestCandidates(query).map((candidate) => candidate.nodeId),
      <NodeId>['fg'],
    );
  });

  test(
    'paint query emits background before content in canonical scene order',
    () {
      final scene = Scene(
        backgroundLayer: BackgroundLayer(
          nodes: <SceneNode>[
            RectNode(
              id: 'bg-right',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(710, 10)),
            ),
          ],
        ),
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-canonical-bg-content',
            nodes: <SceneNode>[
              RectNode(
                id: 'fg-left',
                size: const Size(20, 20),
                transform: Transform2D.translation(const Offset(10, 10)),
              ),
            ],
          ),
        ],
      );

      final index = SceneSpatialIndex.build(scene);
      final candidates = index.queryPaintCandidates(
        const Rect.fromLTWH(0, 0, 760, 40),
        scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
      );

      expect(candidates.map((candidate) => candidate.nodeId), <NodeId>[
        'bg-right',
        'fg-left',
      ]);
    },
  );

  test('grid-backed paint query emits content in scene order', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-canonical-content',
          nodes: <SceneNode>[
            RectNode(
              id: 'first-right',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(710, 10)),
            ),
            RectNode(
              id: 'second-left',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(10, 10)),
            ),
          ],
        ),
      ],
    );

    final index = SceneSpatialIndex.build(scene);
    final candidates = index.queryPaintCandidates(
      const Rect.fromLTWH(0, 0, 760, 40),
    );

    expect(candidates.map((candidate) => candidate.nodeId), <NodeId>[
      'first-right',
      'second-left',
    ]);
  });

  test('grid-backed paint query does not traverse noncandidate layers', () {
    final layers = <ContentLayer>[
      ContentLayer(
        id: 'layer-visible',
        nodes: <SceneNode>[
          RectNode(
            id: 'visible',
            size: const Size(20, 20),
            transform: Transform2D.translation(const Offset(10, 10)),
          ),
        ],
      ),
      for (var i = 0; i < 64; i++)
        ContentLayer(
          id: 'layer-offscreen-$i',
          nodes: <SceneNode>[
            RectNode(
              id: 'offscreen-$i',
              size: const Size(20, 20),
              transform: Transform2D.translation(Offset(10000 + i * 100, 10)),
            ),
          ],
        ),
    ];
    final scene = _CountingLayersScene(layers);
    final index = SceneSpatialIndex.build(scene);
    scene.layerReadCount = 0;

    final candidates = index.queryPaintCandidates(
      const Rect.fromLTWH(0, 0, 40, 40),
    );

    expect(candidates.map((candidate) => candidate.nodeId), <NodeId>[
      'visible',
    ]);
    expect(scene.layerReadCount, lessThan(10));
  });

  test(
    'build without explicit locator still resolves background paint scope',
    () {
      final scene = Scene(
        backgroundLayer: BackgroundLayer(
          nodes: <SceneNode>[
            RectNode(
              id: 'bg-auto-locator',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(10, 10)),
            ),
          ],
        ),
      );

      final index = SceneSpatialIndex.build(scene);
      final candidates = index.queryPaintCandidates(
        const Rect.fromLTWH(0, 0, 40, 40),
        scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
      );

      expect(candidates.map((candidate) => candidate.nodeId), <NodeId>[
        'bg-auto-locator',
      ]);
    },
  );

  test('boundary: 1024 cells stays grid, 1025 cells goes large', () {
    final exact1024Scene = sceneWithRect(
      rectCoveringCells(id: 'exact-1024', width: 8183, height: 8183),
    );
    final over1024Scene = sceneWithRect(
      rectCoveringCells(id: 'over-1024', width: 8184, height: 8183),
    );

    final exact1024Index = SceneSpatialIndex.build(exact1024Scene);
    final over1024Index = SceneSpatialIndex.build(over1024Scene);

    expect(exact1024Index.debugLargeCandidateCount, 0);
    expect(exact1024Index.debugCellCount, greaterThan(0));
    expect(
      exact1024Index
          .queryHitTestCandidates(const Rect.fromLTWH(0, 0, 10, 10))
          .single
          .nodeId,
      'exact-1024',
    );

    expect(over1024Index.debugLargeCandidateCount, 1);
    expect(over1024Index.debugCellCount, greaterThan(0));
    expect(
      over1024Index
          .queryHitTestCandidates(const Rect.fromLTWH(0, 0, 10, 10))
          .single
          .nodeId,
      'over-1024',
    );
  });

  test('huge query switches to fallback candidate scan', () {
    final inside = RectNode(id: 'inside', size: const Size(10, 10));
    final outside = RectNode(id: 'outside', size: const Size(10, 10))
      ..position = const Offset(9999990, 9999990);
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-auto-2', nodes: <SceneNode>[inside, outside]),
      ],
    );

    final index = SceneSpatialIndex.build(scene);
    final candidates = index.queryHitTestCandidates(
      const Rect.fromLTWH(-128000, -12800, 256000, 25600),
    );

    final ids = candidates.map((candidate) => candidate.nodeId).toSet();
    expect(index.debugFallbackQueryCount, 1);
    expect(ids, contains('inside'));
    expect(ids, isNot(contains('outside')));
  });

  test('huge paint query switches to fallback candidate scan', () {
    final inside = RectNode(id: 'inside-paint', size: const Size(10, 10));
    final outside = RectNode(id: 'outside-paint', size: const Size(10, 10))
      ..position = const Offset(9999990, 9999990);
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-paint-huge',
          nodes: <SceneNode>[inside, outside],
        ),
      ],
    );

    final index = SceneSpatialIndex.build(scene);
    final candidates = index.queryPaintCandidates(
      const Rect.fromLTWH(-128000, -12800, 256000, 25600),
    );

    final ids = candidates.map((candidate) => candidate.nodeId).toSet();
    expect(index.debugFallbackQueryCount, 1);
    expect(ids, contains('inside-paint'));
    expect(ids, isNot(contains('outside-paint')));
  });

  test('huge paint query keeps canonical scene order', () {
    final scene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[
          RectNode(
            id: 'bg-huge-right',
            size: const Size(20, 20),
            transform: Transform2D.translation(const Offset(710, 10)),
          ),
        ],
      ),
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-huge-order',
          nodes: <SceneNode>[
            RectNode(
              id: 'fg-huge-right',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(970, 10)),
            ),
            RectNode(
              id: 'fg-huge-left',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(10, 10)),
            ),
          ],
        ),
      ],
    );

    final index = SceneSpatialIndex.build(scene);
    final candidates = index.queryPaintCandidates(
      const Rect.fromLTWH(-128000, -12800, 256000, 25600),
      scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
    );

    expect(index.debugFallbackQueryCount, 1);
    expect(candidates.map((candidate) => candidate.nodeId), <NodeId>[
      'bg-huge-right',
      'fg-huge-right',
      'fg-huge-left',
    ]);
  });

  test('invalid paint index serves repeated linear fallback queries', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-paint-invalid',
          nodes: <SceneNode>[
            RectNode(
              id: 'oor-paint',
              size: const Size(10, 10),
              transform: Transform2D.translation(
                Offset(sceneCoordMax + 500, 0),
              ),
            ),
          ],
        ),
      ],
    );
    final queryRect = Rect.fromLTWH(sceneCoordMax + 450, -20, 100, 40);

    final index = SceneSpatialIndex.build(scene);
    expect(index.isValid, isFalse);

    final first = index.queryPaintCandidates(queryRect);
    final second = index.queryPaintCandidates(queryRect);

    expect(first.map((candidate) => candidate.nodeId), <NodeId>['oor-paint']);
    expect(second.map((candidate) => candidate.nodeId), <NodeId>['oor-paint']);
    expect(index.debugFallbackQueryCount, 2);
  });

  test(
    'background-only paint failure keeps content hit-test fast path available',
    () {
      final scene = Scene(
        backgroundLayer: BackgroundLayer(
          nodes: <SceneNode>[
            RectNode(
              id: 'bg-oor',
              size: const Size(10, 10),
              transform: Transform2D.translation(
                Offset(sceneCoordMax + 500, 0),
              ),
            ),
          ],
        ),
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-content-fast-path',
            nodes: <SceneNode>[
              RectNode(id: 'fg-fast', size: const Size(10, 10)),
            ],
          ),
        ],
      );

      final index = SceneSpatialIndex.build(scene);

      expect(index.isValid, isFalse);
      expect(
        index
            .queryHitTestCandidates(const Rect.fromLTWH(0, 0, 20, 20))
            .map((candidate) => candidate.nodeId),
        <NodeId>['fg-fast'],
      );
      expect(index.debugFallbackQueryCount, 0);
      expect(
        index
            .queryPaintCandidates(
              Rect.fromLTWH(sceneCoordMax + 450, -20, 100, 40),
              scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
            )
            .map((candidate) => candidate.nodeId),
        <NodeId>['bg-oor'],
      );
      expect(index.debugFallbackQueryCount, 1);
    },
  );

  test(
    'out-of-range paint query falls back linearly without invalidating index',
    () {
      final scene = sceneWithRect(
        RectNode(id: 'paint-regular', size: const Size(100, 100)),
      );
      final index = SceneSpatialIndex.build(scene);

      final candidates = index.queryPaintCandidates(
        Rect.fromLTWH(sceneCoordMax + 10, sceneCoordMax + 10, 20, 20),
      );

      expect(candidates, isEmpty);
      expect(index.isValid, isTrue);
      expect(index.debugFallbackQueryCount, 1);
    },
  );

  test(
    'query catches locator lookup errors and switches to invalid fallback',
    () {
      final scene = sceneWithRect(
        RectNode(id: 'r1', size: const Size(100, 100)),
      );
      final index = SceneSpatialIndex.build(scene);
      final throwingLookup =
          _ThrowingLookupMap<NodeId, SceneSpatialCandidateLocation>({
            'r1': (layerIndex: 0, nodeIndex: 0),
          });

      final applied = index.applyIncremental(
        scene: scene,
        nodeLocator: throwingLookup,
        changeSet: const SceneSpatialIndexChangeSet(
          addedNodeIds: <NodeId>{},
          removedNodeIds: <NodeId>{},
          spatialGeometryChangedIds: <NodeId>{},
        ),
      );
      expect(applied, isTrue);

      final candidates = index.queryHitTestCandidates(
        const Rect.fromLTWH(0, 0, 20, 20),
      );
      expect(candidates, isNotEmpty);
      expect(index.isValid, isFalse);
    },
  );

  test(
    'paint query catches locator lookup errors and switches to invalid fallback',
    () {
      final scene = sceneWithRect(
        RectNode(id: 'paint-r1', size: const Size(100, 100)),
      );
      final index = SceneSpatialIndex.build(scene);
      final throwingLookup =
          _ThrowingLookupMap<NodeId, SceneSpatialCandidateLocation>({
            'paint-r1': (layerIndex: 0, nodeIndex: 0),
          });

      final applied = index.applyIncremental(
        scene: scene,
        nodeLocator: throwingLookup,
        changeSet: const SceneSpatialIndexChangeSet(
          addedNodeIds: <NodeId>{},
          removedNodeIds: <NodeId>{},
          spatialGeometryChangedIds: <NodeId>{},
        ),
      );
      expect(applied, isTrue);

      final candidates = index.queryPaintCandidates(
        const Rect.fromLTWH(0, 0, 20, 20),
      );
      expect(candidates.map((candidate) => candidate.nodeId), <NodeId>[
        'paint-r1',
      ]);
      expect(index.isValid, isFalse);
    },
  );

  test(
    'applyIncremental catches containsKey errors and marks index invalid',
    () {
      final scene = sceneWithRect(
        RectNode(id: 'r1', size: const Size(100, 100)),
      );
      final index = SceneSpatialIndex.build(scene);
      final throwingContainsKey =
          _ThrowingContainsKeyMap<NodeId, SceneSpatialCandidateLocation>({
            'r1': (layerIndex: 0, nodeIndex: 0),
          });

      final applied = index.applyIncremental(
        scene: scene,
        nodeLocator: throwingContainsKey,
        changeSet: const SceneSpatialIndexChangeSet(
          addedNodeIds: <NodeId>{},
          removedNodeIds: <NodeId>{},
          spatialGeometryChangedIds: <NodeId>{'r1'},
        ),
      );

      expect(applied, isFalse);
      expect(index.isValid, isFalse);
    },
  );

  test(
    'cloneForIncrementalUpdate keeps source index unchanged before swap',
    () {
      final sourceScene = sceneWithRect(
        RectNode(id: 'r1', size: const Size(10, 10)),
      );
      final sourceLocator = <NodeId, SceneSpatialCandidateLocation>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };
      final sourceIndex = SceneSpatialIndex.build(
        sourceScene,
        nodeLocator: sourceLocator,
      );

      final movedScene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-3',
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
      final movedLocator = <NodeId, SceneSpatialCandidateLocation>{
        'r1': (layerIndex: 0, nodeIndex: 0),
      };

      final candidate = sourceIndex.cloneForIncrementalUpdate(
        scene: movedScene,
        nodeLocator: movedLocator,
      );
      final applied = candidate.applyIncremental(
        scene: movedScene,
        nodeLocator: movedLocator,
        changeSet: const SceneSpatialIndexChangeSet(
          addedNodeIds: <NodeId>{},
          removedNodeIds: <NodeId>{},
          spatialGeometryChangedIds: <NodeId>{'r1'},
        ),
      );
      expect(applied, isTrue);

      final sourceAtOld = sourceIndex.queryHitTestCandidates(
        const Rect.fromLTWH(0, 0, 20, 20),
      );
      final sourceAtMoved = sourceIndex.queryHitTestCandidates(
        const Rect.fromLTWH(100, 0, 20, 20),
      );
      final candidateAtOld = candidate.queryHitTestCandidates(
        const Rect.fromLTWH(0, 0, 20, 20),
      );
      final candidateAtMoved = candidate.queryHitTestCandidates(
        const Rect.fromLTWH(100, 0, 20, 20),
      );

      expect(sourceAtOld.map((candidate) => candidate.nodeId), <NodeId>['r1']);
      expect(sourceAtMoved, isEmpty);
      expect(candidateAtOld, isEmpty);
      expect(candidateAtMoved.map((candidate) => candidate.nodeId), <NodeId>[
        'r1',
      ]);
    },
  );

  test('incremental update resolves background paint nodes by locator', () {
    final originalScene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[
          RectNode(
            id: 'bg-incremental',
            size: const Size(10, 10),
            transform: Transform2D.translation(const Offset(10, 10)),
          ),
        ],
      ),
    );
    final originalLocator = <NodeId, SceneSpatialCandidateLocation>{
      'bg-incremental': (layerIndex: -1, nodeIndex: 0),
    };
    final index = SceneSpatialIndex.build(
      originalScene,
      nodeLocator: originalLocator,
    );

    final movedScene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[
          RectNode(
            id: 'bg-incremental',
            size: const Size(10, 10),
            transform: Transform2D.translation(const Offset(80, 10)),
          ),
        ],
      ),
    );
    final movedLocator = <NodeId, SceneSpatialCandidateLocation>{
      'bg-incremental': (layerIndex: -1, nodeIndex: 0),
    };

    final applied = index.applyIncremental(
      scene: movedScene,
      nodeLocator: movedLocator,
      changeSet: const SceneSpatialIndexChangeSet(
        addedNodeIds: <NodeId>{},
        removedNodeIds: <NodeId>{},
        spatialGeometryChangedIds: <NodeId>{'bg-incremental'},
      ),
    );

    final atOldLocation = index.queryPaintCandidates(
      const Rect.fromLTWH(0, 0, 30, 30),
      scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
    );
    final atNewLocation = index.queryPaintCandidates(
      const Rect.fromLTWH(60, 0, 40, 30),
      scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,
    );

    expect(applied, isTrue);
    expect(atOldLocation, isEmpty);
    expect(atNewLocation.map((candidate) => candidate.nodeId), <NodeId>[
      'bg-incremental',
    ]);
  });

  test('incremental insert orders paint candidates from current locator', () {
    final originalScene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-insert-order',
          nodes: <SceneNode>[
            RectNode(
              id: 'a-first',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(40, 10)),
            ),
            RectNode(
              id: 'b-second',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(70, 10)),
            ),
          ],
        ),
      ],
    );
    final originalLocator = <NodeId, SceneSpatialCandidateLocation>{
      'a-first': (layerIndex: 0, nodeIndex: 0),
      'b-second': (layerIndex: 0, nodeIndex: 1),
    };
    final index = SceneSpatialIndex.build(
      originalScene,
      nodeLocator: originalLocator,
    );

    final updatedScene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-insert-order',
          nodes: <SceneNode>[
            RectNode(
              id: 'z-inserted',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(10, 10)),
            ),
            RectNode(
              id: 'a-first',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(40, 10)),
            ),
            RectNode(
              id: 'b-second',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(70, 10)),
            ),
          ],
        ),
      ],
    );
    final updatedLocator = <NodeId, SceneSpatialCandidateLocation>{
      'z-inserted': (layerIndex: 0, nodeIndex: 0),
      'a-first': (layerIndex: 0, nodeIndex: 1),
      'b-second': (layerIndex: 0, nodeIndex: 2),
    };

    final applied = index.applyIncremental(
      scene: updatedScene,
      nodeLocator: updatedLocator,
      changeSet: const SceneSpatialIndexChangeSet(
        addedNodeIds: <NodeId>{'z-inserted'},
        removedNodeIds: <NodeId>{},
        spatialGeometryChangedIds: <NodeId>{},
      ),
    );
    final candidates = index.queryPaintCandidates(
      const Rect.fromLTWH(0, 0, 100, 40),
    );

    expect(applied, isTrue);
    expect(candidates.map((candidate) => candidate.nodeId), <NodeId>[
      'z-inserted',
      'a-first',
      'b-second',
    ]);
  });

  test('incremental removal orders paint candidates from current locator', () {
    final originalScene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-remove-order',
          nodes: <SceneNode>[
            RectNode(
              id: 'z-removed',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(10, 10)),
            ),
            RectNode(
              id: 'a-first',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(70, 10)),
            ),
            RectNode(
              id: 'b-second',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(40, 10)),
            ),
          ],
        ),
      ],
    );
    final originalLocator = <NodeId, SceneSpatialCandidateLocation>{
      'z-removed': (layerIndex: 0, nodeIndex: 0),
      'a-first': (layerIndex: 0, nodeIndex: 1),
      'b-second': (layerIndex: 0, nodeIndex: 2),
    };
    final index = SceneSpatialIndex.build(
      originalScene,
      nodeLocator: originalLocator,
    );

    final updatedScene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-remove-order',
          nodes: <SceneNode>[
            RectNode(
              id: 'a-first',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(70, 10)),
            ),
            RectNode(
              id: 'b-second',
              size: const Size(20, 20),
              transform: Transform2D.translation(const Offset(40, 10)),
            ),
          ],
        ),
      ],
    );
    final updatedLocator = <NodeId, SceneSpatialCandidateLocation>{
      'a-first': (layerIndex: 0, nodeIndex: 0),
      'b-second': (layerIndex: 0, nodeIndex: 1),
    };

    final applied = index.applyIncremental(
      scene: updatedScene,
      nodeLocator: updatedLocator,
      changeSet: const SceneSpatialIndexChangeSet(
        addedNodeIds: <NodeId>{},
        removedNodeIds: <NodeId>{'z-removed'},
        spatialGeometryChangedIds: <NodeId>{},
      ),
    );
    final candidates = index.queryPaintCandidates(
      const Rect.fromLTWH(0, 0, 100, 40),
    );

    expect(applied, isTrue);
    expect(candidates.map((candidate) => candidate.nodeId), <NodeId>[
      'a-first',
      'b-second',
    ]);
  });

  test('build catches scene iteration errors and marks index invalid', () {
    final index = SceneSpatialIndex.build(
      _ThrowingLayersScene(),
      nodeLocator: const <NodeId, SceneSpatialCandidateLocation>{},
    );
    expect(index.isValid, isFalse);
  });

  test('incremental update keeps parity with full rebuild path', () {
    final originalNode = StrokeNode(
      id: 'stroke-parity',
      points: const <Offset>[Offset(-10, 0), Offset(10, 0)],
      thickness: 3,
      color: const Color(0xFF000000),
      hitPadding: 1.5,
    )..position = const Offset(20, 20);
    final originalScene = Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-auto-parity', nodes: <SceneNode>[originalNode]),
      ],
    );
    final originalLocator = <NodeId, SceneSpatialCandidateLocation>{
      originalNode.id: (layerIndex: 0, nodeIndex: 0),
    };
    final incremental = SceneSpatialIndex.build(
      originalScene,
      nodeLocator: originalLocator,
    );

    final movedNode = StrokeNode(
      id: 'stroke-parity',
      points: const <Offset>[Offset(-20, 0), Offset(20, 0), Offset(25, 4)],
      thickness: 5,
      color: const Color(0xFF000000),
      hitPadding: 2,
    )..position = const Offset(80, 20);
    final movedScene = Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-auto-parity', nodes: <SceneNode>[movedNode]),
      ],
    );
    final movedLocator = <NodeId, SceneSpatialCandidateLocation>{
      movedNode.id: (layerIndex: 0, nodeIndex: 0),
    };

    final applied = incremental.applyIncremental(
      scene: movedScene,
      nodeLocator: movedLocator,
      changeSet: SceneSpatialIndexChangeSet(
        addedNodeIds: const <NodeId>{},
        removedNodeIds: const <NodeId>{},
        spatialGeometryChangedIds: <NodeId>{movedNode.id},
      ),
    );
    final rebuilt = SceneSpatialIndex.build(
      movedScene,
      nodeLocator: movedLocator,
    );
    final queryRect = const Rect.fromLTWH(40, 0, 100, 60);

    final incrementalCandidates = incremental.queryHitTestCandidates(queryRect);
    final rebuiltCandidates = rebuilt.queryHitTestCandidates(queryRect);

    expect(applied, isTrue);
    expect(incrementalCandidates.map((candidate) => candidate.nodeId), <NodeId>[
      movedNode.id,
    ]);
    expect(rebuiltCandidates.map((candidate) => candidate.nodeId), <NodeId>[
      movedNode.id,
    ]);
    expect(
      incrementalCandidates.single.hitTestBoundsWorld,
      rebuiltCandidates.single.hitTestBoundsWorld,
    );
    expect(
      rebuiltCandidates.single.hitTestBoundsWorld,
      nodeHitTestCandidateBoundsWorld(movedNode),
    );
  });
}
