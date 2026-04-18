import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/scene_contract_limits.dart'
    show
        kMaxContentLayersPerScene,
        kMaxPaletteItems,
        sceneCoordMax,
        sceneSizeMax;
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/controller/change_set.dart';
import 'package:iwb_canvas_engine/src/controller/committed_store_state.dart';
import 'package:iwb_canvas_engine/src/controller/scene_invariants.dart'
    as scene_invariants;
import 'package:iwb_canvas_engine/src/core/id_generator.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/revision_policy.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/model/document.dart';
import 'package:iwb_canvas_engine/src/model/document_clone.dart';

// INV:INV-ENG-ID-INDEX-FROM-SCENE
// INV:INV-ENG-INSTANCE-REVISION-MONOTONIC
// INV:INV-G-NODEID-UNIQUE
// INV:INV-G-LAYERID-UNIQUE
// INV:INV-G-SELECTION-NORMALIZED
// INV:INV-G-GRID-ENABLE-CELL-SIZE-RELATION
// INV:INV-ENG-COMMITTED-STORE-METADATA-CONTRACT

void main() {
  Scene sceneFixture({
    bool gridEnabled = false,
    double gridCellSize = 16,
    Offset cameraOffset = Offset.zero,
    Camera? camera,
    Background? background,
    ScenePalette? palette,
  }) {
    return Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-0',
          nodes: <SceneNode>[RectNode(id: 'node-1', size: const Size(10, 10))],
        ),
      ],
      camera: camera ?? Camera(offset: cameraOffset),
      background:
          background ??
          Background(
            grid: GridSettings(isEnabled: gridEnabled, cellSize: gridCellSize),
          ),
      palette: palette ?? ScenePalette(),
    );
  }

  Camera rawCameraFixture(Offset offset) {
    return _RawCamera(offset);
  }

  Background rawBackgroundFixture({
    required GridSettings grid,
    Color color = const Color(0xFFFFFFFF),
  }) {
    return _RawBackground(color: color, grid: grid);
  }

  GridSettings rawGridFixture({
    required bool isEnabled,
    required double cellSize,
    Color color = const Color(0xFF000000),
  }) {
    return _RawGridSettings(
      isEnabled: isEnabled,
      cellSize: cellSize,
      color: color,
    );
  }

  ScenePalette rawPaletteFixture({
    required List<Color> penColors,
    required List<Color> backgroundColors,
    required List<double> gridSizes,
  }) {
    return _RawScenePalette(
      penColors: penColors,
      backgroundColors: backgroundColors,
      gridSizes: gridSizes,
    );
  }

  IdGeneratorState state({
    int nextNodeCounter = 1,
    int nextLayerCounter = 1,
    String sessionToken = 'test-session',
  }) {
    return createIdGeneratorStateForTesting(
      sessionToken: sessionToken,
      nextNodeCounter: nextNodeCounter,
      nextLayerCounter: nextLayerCounter,
    );
  }

  CommittedStoreState committedStoreState({
    required Scene scene,
    required Set<NodeId> selectedNodeIds,
    required Set<NodeId> allNodeIds,
    required Map<NodeId, NodeLocatorEntry> nodeLocator,
    required IdGeneratorState idGeneratorState,
    int controllerEpoch = 0,
    RevisionAllocatorState? revisionState,
    int nextInstanceRevision = 1,
    required int commitRevision,
  }) {
    return CommittedStoreState(
      scene: scene,
      selectedNodeIds: selectedNodeIds,
      allNodeIds: allNodeIds,
      nodeLocator: nodeLocator,
      idGeneratorState: idGeneratorState,
      revisionState:
          revisionState ??
          createInitialRevisionAllocatorState(
            nextInstanceRevision: nextInstanceRevision,
          ),
      controllerEpoch: controllerEpoch,
      structuralRevision: 0,
      selectionRevision: 0,
      boundsRevision: 0,
      visualRevision: 0,
      commitRevision: commitRevision,
    );
  }

  List<String> txnCollectStoreInvariantViolations({
    required Scene scene,
    required Set<NodeId> selectedNodeIds,
    required Set<NodeId> allNodeIds,
    required Map<NodeId, NodeLocatorEntry> nodeLocator,
    required IdGeneratorState idGeneratorState,
    int controllerEpoch = 0,
    RevisionAllocatorState? revisionState,
    int nextInstanceRevision = 1,
    required int commitRevision,
  }) {
    return scene_invariants.txnCollectStoreInvariantViolations(
      committedStoreState(
        scene: scene,
        selectedNodeIds: selectedNodeIds,
        allNodeIds: allNodeIds,
        nodeLocator: nodeLocator,
        idGeneratorState: idGeneratorState,
        controllerEpoch: controllerEpoch,
        revisionState: revisionState,
        nextInstanceRevision: nextInstanceRevision,
        commitRevision: commitRevision,
      ),
    );
  }

  void debugAssertTxnStoreInvariants({
    required Scene scene,
    required Set<NodeId> selectedNodeIds,
    required Set<NodeId> allNodeIds,
    required Map<NodeId, NodeLocatorEntry> nodeLocator,
    required IdGeneratorState idGeneratorState,
    int controllerEpoch = 0,
    RevisionAllocatorState? revisionState,
    int nextInstanceRevision = 1,
    required int commitRevision,
  }) {
    scene_invariants.debugAssertTxnStoreInvariants(
      committedStoreState(
        scene: scene,
        selectedNodeIds: selectedNodeIds,
        allNodeIds: allNodeIds,
        nodeLocator: nodeLocator,
        idGeneratorState: idGeneratorState,
        controllerEpoch: controllerEpoch,
        revisionState: revisionState,
        nextInstanceRevision: nextInstanceRevision,
        commitRevision: commitRevision,
      ),
    );
  }

  void assertCriticalTxnStoreInvariants({
    required Scene scene,
    required int commitRevision,
    required int previousCommitRevision,
    Scene? previousScene,
    ChangeSet? changeSet,
  }) {
    scene_invariants.assertCriticalTxnStoreInvariants(
      state: committedStoreState(
        scene: scene,
        selectedNodeIds: const <NodeId>{},
        allNodeIds: txnCollectNodeIds(scene),
        nodeLocator: txnBuildNodeLocator(scene),
        idGeneratorState: state(),
        commitRevision: commitRevision,
      ),
      commitRevision: commitRevision,
      previousCommitRevision: previousCommitRevision,
      previousScene: previousScene,
      changeSet: changeSet,
    );
  }

  List<String> txnCollectCriticalStoreInvariantViolations({
    required Scene scene,
    required int commitRevision,
    required int previousCommitRevision,
    Scene? previousScene,
    ChangeSet? changeSet,
  }) {
    return scene_invariants.txnCollectCriticalStoreInvariantViolations(
      state: committedStoreState(
        scene: scene,
        selectedNodeIds: const <NodeId>{},
        allNodeIds: txnCollectNodeIds(scene),
        nodeLocator: txnBuildNodeLocator(scene),
        idGeneratorState: state(),
        commitRevision: commitRevision,
      ),
      commitRevision: commitRevision,
      previousCommitRevision: previousCommitRevision,
      previousScene: previousScene,
      changeSet: changeSet,
    );
  }

  test('returns no violations for valid committed store', () {
    final scene = sceneFixture(gridEnabled: true, gridCellSize: 16);
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{'node-1'},
      allNodeIds: const <NodeId>{'node-1'},
      nodeLocator: const <NodeId, NodeLocatorEntry>{
        'node-1': (layerIndex: 0, nodeIndex: 0),
      },
      idGeneratorState: state(nextNodeCounter: 2),
      nextInstanceRevision: 2,
      commitRevision: 1,
    );

    expect(violations, isEmpty);
  });

  test('collects violations for mismatched index and non-finite values', () {
    // INV:INV-G-SELECTION-NORMALIZED
    final scene = sceneFixture(
      camera: rawCameraFixture(const Offset(double.infinity, 0)),
    );
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{'missing'},
      allNodeIds: const <NodeId>{},
      nodeLocator: const <NodeId, NodeLocatorEntry>{},
      idGeneratorState: state(sessionToken: ''),
      nextInstanceRevision: 2,
      commitRevision: -1,
    );

    expect(
      violations.join('\n'),
      contains('allNodeIds must equal collectNodeIds(scene)'),
    );
    expect(
      violations.join('\n'),
      contains('selectedNodeIds must be normalized'),
    );
    expect(
      violations.join('\n'),
      contains('idGeneratorState.sessionToken must not be empty'),
    );
    expect(
      violations.join('\n'),
      contains('commitRevision must be non-negative'),
    );
    expect(violations.join('\n'), contains('camera.offset.dx must be finite'));
    expect(violations.join('\n'), isNot(contains('background.grid.cellSize')));
  });

  test(
    'collects shared scene metadata contract violations from raw committed state',
    () {
      final scene = sceneFixture(
        camera: rawCameraFixture(Offset(sceneCoordMax + 1, 0)),
        background: rawBackgroundFixture(
          grid: rawGridFixture(isEnabled: true, cellSize: 0.5),
        ),
        palette: rawPaletteFixture(
          penColors: const <Color>[],
          backgroundColors: <Color>[
            for (var i = 0; i < kMaxPaletteItems + 1; i++)
              const Color(0xFF010101),
          ],
          gridSizes: <double>[0, sceneSizeMax + 1],
        ),
      );

      final violations = txnCollectStoreInvariantViolations(
        scene: scene,
        selectedNodeIds: const <NodeId>{},
        allNodeIds: const <NodeId>{'node-1'},
        nodeLocator: const <NodeId, NodeLocatorEntry>{
          'node-1': (layerIndex: 0, nodeIndex: 0),
        },
        idGeneratorState: state(nextNodeCounter: 2),
        nextInstanceRevision: 2,
        commitRevision: 0,
      );

      expect(
        violations.join('\n'),
        contains('camera.offset.dx must be within [-10000000.0, 10000000.0].'),
      );
      expect(
        violations.join('\n'),
        contains(
          'background.grid.cellSize must be >= 1.0 when background.grid.enabled is true.',
        ),
      );
      expect(
        violations.join('\n'),
        contains(
          'palette.backgroundColors must contain at most $kMaxPaletteItems items.',
        ),
      );
    },
  );

  test('runtime grid owner rejects invalid committed grid states eagerly', () {
    // INV:INV-G-GRID-ENABLE-CELL-SIZE-RELATION
    final scene = sceneFixture(gridEnabled: false, gridCellSize: 16);

    scene.background.grid.cellSize = 0.5;
    expect(() => scene.background.grid.isEnabled = true, throwsArgumentError);
    expect(() => scene.background.grid.cellSize = 0, throwsArgumentError);
  });

  test('detects duplicate node ids in committed scene', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-1',
          nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(10, 10))],
        ),
        ContentLayer(
          id: 'layer-auto-2',
          nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(12, 12))],
        ),
      ],
    );
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{},
      allNodeIds: const <NodeId>{'dup'},
      nodeLocator: const <NodeId, NodeLocatorEntry>{
        'dup': (layerIndex: 0, nodeIndex: 0),
      },
      idGeneratorState: state(),
      nextInstanceRevision: 2,
      commitRevision: 0,
    );

    expect(
      violations.join('\n'),
      contains('layers[1].nodes[0].id Must be unique across scene layers.'),
    );
  });

  test('detects duplicate content layer ids in committed scene', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-auto-dup'),
        ContentLayer(id: 'layer-auto-dup'),
      ],
    );
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{},
      allNodeIds: const <NodeId>{},
      nodeLocator: const <NodeId, NodeLocatorEntry>{},
      idGeneratorState: state(),
      nextInstanceRevision: 1,
      commitRevision: 0,
    );

    expect(
      violations.join('\n'),
      contains('layers[1].id must be unique across content layers.'),
    );
  });

  test('detects duplicate node ids inside background layer', () {
    final scene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[
          RectNode(id: 'dup-bg', size: const Size(10, 10)),
          RectNode(id: 'dup-bg', size: const Size(12, 12)),
        ],
      ),
      layers: <ContentLayer>[ContentLayer(id: 'layer-auto-3')],
    );
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{},
      allNodeIds: const <NodeId>{'dup-bg'},
      nodeLocator: const <NodeId, NodeLocatorEntry>{
        'dup-bg': (layerIndex: -1, nodeIndex: 0),
      },
      idGeneratorState: state(),
      nextInstanceRevision: 2,
      commitRevision: 0,
    );

    expect(
      violations.join('\n'),
      contains(
        'backgroundLayer.nodes[1].id Must be unique across scene layers.',
      ),
    );
  });

  test('accepts typed background layer outside content layer index space', () {
    final scene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[RectNode(id: 'bg', size: const Size(8, 8))],
      ),
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-4',
          nodes: <SceneNode>[RectNode(id: 'n1', size: const Size(10, 10))],
        ),
      ],
    );
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{},
      allNodeIds: const <NodeId>{'bg', 'n1'},
      nodeLocator: const <NodeId, NodeLocatorEntry>{
        'bg': (layerIndex: -1, nodeIndex: 0),
        'n1': (layerIndex: 0, nodeIndex: 0),
      },
      idGeneratorState: state(nextNodeCounter: 2),
      nextInstanceRevision: 2,
      commitRevision: 0,
    );

    expect(violations, isEmpty);
  });

  test('detects duplicate node ids across background and content layers', () {
    final scene = Scene(
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(8, 8))],
      ),
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-5',
          nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(10, 10))],
        ),
      ],
    );
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{},
      allNodeIds: const <NodeId>{'dup'},
      nodeLocator: const <NodeId, NodeLocatorEntry>{
        'dup': (layerIndex: -1, nodeIndex: 0),
      },
      idGeneratorState: state(),
      nextInstanceRevision: 2,
      commitRevision: 0,
    );

    expect(
      violations.join('\n'),
      contains('layers[0].nodes[0].id Must be unique across scene layers.'),
    );
  });

  test(
    'collects canonical structural overflow violation from committed scene',
    () {
      final scene = Scene(
        layers: <ContentLayer>[
          for (var index = 0; index < kMaxContentLayersPerScene + 1; index++)
            ContentLayer(id: 'layer-auto-$index'),
        ],
      );
      final violations = txnCollectStoreInvariantViolations(
        scene: scene,
        selectedNodeIds: const <NodeId>{},
        allNodeIds: const <NodeId>{},
        nodeLocator: const <NodeId, NodeLocatorEntry>{},
        idGeneratorState: state(),
        nextInstanceRevision: 1,
        commitRevision: 0,
      );

      expect(
        violations.join('\n'),
        contains(
          'layers must contain at most $kMaxContentLayersPerScene items.',
        ),
      );
    },
  );

  test(
    'collects canonical runtime node-field violation from committed scene',
    () {
      final node = _RawTransformRectNode(
        id: 'bad-node',
        rawTransform: const Transform2D(
          a: double.infinity,
          b: 0,
          c: 0,
          d: 1,
          tx: 0,
          ty: 0,
        ),
      );
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(id: 'layer-auto-node', nodes: <SceneNode>[node]),
        ],
      );
      final violations = txnCollectStoreInvariantViolations(
        scene: scene,
        selectedNodeIds: const <NodeId>{},
        allNodeIds: const <NodeId>{'bad-node'},
        nodeLocator: const <NodeId, NodeLocatorEntry>{
          'bad-node': (layerIndex: 0, nodeIndex: 0),
        },
        idGeneratorState: state(nextNodeCounter: 2),
        nextInstanceRevision: 2,
        commitRevision: 0,
      );

      expect(
        violations.join('\n'),
        contains('layers[0].nodes[0].transform.a must be finite.'),
      );
    },
  );

  test('detects committed epoch bump request in store state', () {
    final scene = sceneFixture();
    final revisionState = createInitialRevisionAllocatorState();
    revisionState.epochBumpRequested = true;
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{'node-1'},
      allNodeIds: const <NodeId>{'node-1'},
      nodeLocator: const <NodeId, NodeLocatorEntry>{
        'node-1': (layerIndex: 0, nodeIndex: 0),
      },
      idGeneratorState: state(nextNodeCounter: 2),
      revisionState: revisionState,
      commitRevision: 0,
    );

    expect(
      violations.join('\n'),
      contains('committed revisionState.epochBumpRequested must be false'),
    );
  });

  test('detects invalid allocator counters', () {
    final scene = Scene(layers: <ContentLayer>[ContentLayer(id: 'layer-3')]);
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{},
      allNodeIds: const <NodeId>{},
      nodeLocator: const <NodeId, NodeLocatorEntry>{},
      idGeneratorState: state(nextNodeCounter: 0, nextLayerCounter: 0),
      nextInstanceRevision: 1,
      commitRevision: 0,
    );

    expect(
      violations.join('\n'),
      contains('idGeneratorState.nextNodeCounter must be >= 1'),
    );
    expect(
      violations.join('\n'),
      contains('idGeneratorState.nextLayerCounter must be >= 1'),
    );
  });

  test('detects invalid committed controllerEpoch', () {
    final scene = sceneFixture();
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{'node-1'},
      allNodeIds: const <NodeId>{'node-1'},
      nodeLocator: const <NodeId, NodeLocatorEntry>{
        'node-1': (layerIndex: 0, nodeIndex: 0),
      },
      idGeneratorState: state(nextNodeCounter: 2),
      controllerEpoch: -1,
      commitRevision: 0,
    );

    expect(violations.join('\n'), contains('controllerEpoch must stay within'));
  });

  test('detects invalid committed revisionState counter', () {
    final scene = sceneFixture();
    final revisionState = createInitialRevisionAllocatorState();
    revisionState.nextInstanceRevision = kMaxInstanceRevision + 1;
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{'node-1'},
      allNodeIds: const <NodeId>{'node-1'},
      nodeLocator: const <NodeId, NodeLocatorEntry>{
        'node-1': (layerIndex: 0, nodeIndex: 0),
      },
      idGeneratorState: state(nextNodeCounter: 2),
      revisionState: revisionState,
      commitRevision: 0,
    );

    expect(
      violations.join('\n'),
      contains('revisionState.nextInstanceRevision must stay within'),
    );
  });

  test('detects invalid node instanceRevision in committed scene', () {
    final badNode = _BadInstanceRevisionNode(id: 'bad-rev')
      ..forceInvalidInstanceRevision();
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-auto-6', nodes: <SceneNode>[badNode]),
      ],
    );
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{},
      allNodeIds: const <NodeId>{'bad-rev'},
      nodeLocator: const <NodeId, NodeLocatorEntry>{
        'bad-rev': (layerIndex: 0, nodeIndex: 0),
      },
      idGeneratorState: state(),
      nextInstanceRevision: 1,
      commitRevision: 0,
    );

    expect(
      violations.join('\n'),
      contains('scene nodes must have instanceRevision >= 1'),
    );
  });

  test('runtime invariant check throws for invalid committed store', () {
    final scene = sceneFixture(
      camera: rawCameraFixture(const Offset(double.nan, 0)),
    );
    expect(
      () => debugAssertTxnStoreInvariants(
        scene: scene,
        selectedNodeIds: const <NodeId>{},
        allNodeIds: const <NodeId>{},
        nodeLocator: const <NodeId, NodeLocatorEntry>{},
        idGeneratorState: state(),
        nextInstanceRevision: 2,
        commitRevision: 0,
      ),
      throwsStateError,
    );
  });

  test(
    'runtime invariant check throws for out-of-range committed scene metadata',
    () {
      final scene = sceneFixture(
        camera: rawCameraFixture(Offset(sceneCoordMax + 1, 0)),
        background: rawBackgroundFixture(
          grid: rawGridFixture(isEnabled: true, cellSize: 0.5),
        ),
      );
      expect(
        () => debugAssertTxnStoreInvariants(
          scene: scene,
          selectedNodeIds: const <NodeId>{},
          allNodeIds: const <NodeId>{'node-1'},
          nodeLocator: const <NodeId, NodeLocatorEntry>{
            'node-1': (layerIndex: 0, nodeIndex: 0),
          },
          idGeneratorState: state(nextNodeCounter: 2),
          nextInstanceRevision: 2,
          commitRevision: 0,
        ),
        throwsStateError,
      );
    },
  );

  test('critical runtime invariant check throws for invalid numeric state', () {
    final scene = sceneFixture(
      camera: rawCameraFixture(const Offset(double.infinity, 0)),
    );
    expect(
      () => assertCriticalTxnStoreInvariants(
        scene: scene,
        commitRevision: 0,
        previousCommitRevision: -1,
      ),
      throwsStateError,
    );
  });

  test(
    'critical runtime invariant check throws for out-of-range metadata state',
    () {
      final scene = sceneFixture(
        camera: rawCameraFixture(Offset(sceneCoordMax + 1, 0)),
        palette: rawPaletteFixture(
          penColors: const <Color>[Color(0xFF000000)],
          backgroundColors: const <Color>[Color(0xFFFFFFFF)],
          gridSizes: <double>[sceneSizeMax + 1],
        ),
      );
      expect(
        () => assertCriticalTxnStoreInvariants(
          scene: scene,
          commitRevision: 0,
          previousCommitRevision: -1,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'critical runtime invariant check revalidates changed palette surface',
    () {
      final previousScene = sceneFixture();
      final scene = sceneFixture(
        palette: rawPaletteFixture(
          penColors: const <Color>[],
          backgroundColors: const <Color>[Color(0xFFFFFFFF)],
          gridSizes: const <double>[16],
        ),
      );

      expect(
        () => assertCriticalTxnStoreInvariants(
          scene: scene,
          commitRevision: 0,
          previousCommitRevision: -1,
          previousScene: previousScene,
          changeSet: ChangeSet(),
        ),
        throwsStateError,
      );
    },
  );

  test('critical runtime invariant check skips unchanged palette surface', () {
    final previousScene = sceneFixture(
      palette: rawPaletteFixture(
        penColors: const <Color>[],
        backgroundColors: const <Color>[Color(0xFFFFFFFF)],
        gridSizes: const <double>[16],
      ),
    );
    final scene = sceneFixture(
      palette: rawPaletteFixture(
        penColors: const <Color>[],
        backgroundColors: const <Color>[Color(0xFFFFFFFF)],
        gridSizes: const <double>[16],
      ),
    );

    final violations = txnCollectCriticalStoreInvariantViolations(
      scene: scene,
      commitRevision: 1,
      previousCommitRevision: 0,
      previousScene: previousScene,
      changeSet: ChangeSet(),
    );

    expect(violations, isNot(contains('palette.penColors must not be empty.')));
  });

  test(
    'critical runtime invariant check revalidates changed structural layer ids',
    () {
      final previousScene = sceneFixture();
      final scene = Scene(
        layers: <ContentLayer>[ContentLayer(id: '', nodes: <SceneNode>[])],
      );

      expect(
        () => assertCriticalTxnStoreInvariants(
          scene: scene,
          commitRevision: 0,
          previousCommitRevision: -1,
          previousScene: previousScene,
          changeSet: ChangeSet()..structuralChanged = true,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'critical runtime invariant check revalidates full scene for document replacement',
    () {
      final invalidScene = sceneFixture(
        palette: rawPaletteFixture(
          penColors: const <Color>[],
          backgroundColors: const <Color>[Color(0xFFFFFFFF)],
          gridSizes: const <double>[16],
        ),
      );

      expect(
        () => assertCriticalTxnStoreInvariants(
          scene: invalidScene,
          commitRevision: 1,
          previousCommitRevision: 0,
          previousScene: invalidScene,
          changeSet: ChangeSet()..documentReplaced = true,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'critical runtime invariant check reports negative commit regression',
    () {
      final scene = sceneFixture();
      expect(
        () => assertCriticalTxnStoreInvariants(
          scene: scene,
          commitRevision: -1,
          previousCommitRevision: -2,
        ),
        throwsStateError,
      );
    },
  );

  test('critical runtime invariant check throws on commit regression', () {
    final scene = sceneFixture();
    expect(
      () => assertCriticalTxnStoreInvariants(
        scene: scene,
        commitRevision: 3,
        previousCommitRevision: 4,
      ),
      throwsStateError,
    );
  });

  test(
    'critical runtime invariant check throws for structural overflow state',
    () {
      final scene = Scene(
        layers: <ContentLayer>[
          for (var index = 0; index < kMaxContentLayersPerScene + 1; index++)
            ContentLayer(id: 'layer-auto-$index'),
        ],
      );
      expect(
        () => assertCriticalTxnStoreInvariants(
          scene: scene,
          commitRevision: 0,
          previousCommitRevision: -1,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'critical runtime invariant check throws for invalid node field state',
    () {
      final node = _RawTransformRectNode(
        id: 'bad-node',
        rawTransform: const Transform2D(
          a: double.infinity,
          b: 0,
          c: 0,
          d: 1,
          tx: 0,
          ty: 0,
        ),
      );
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(id: 'layer-auto-node', nodes: <SceneNode>[node]),
        ],
      );
      expect(
        () => assertCriticalTxnStoreInvariants(
          scene: scene,
          commitRevision: 0,
          previousCommitRevision: -1,
        ),
        throwsStateError,
      );
    },
  );

  test('critical runtime invariant check validates only tracked node ids', () {
    final invalidNode = _RawTransformRectNode(
      id: 'bad-node',
      rawTransform: const Transform2D(
        a: double.infinity,
        b: 0,
        c: 0,
        d: 1,
        tx: 0,
        ty: 0,
      ),
    );
    final previousScene = Scene(
      layers: <ContentLayer>[
        ContentLayer(id: 'layer-auto-node', nodes: <SceneNode>[invalidNode]),
      ],
    );
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-node',
          nodes: <SceneNode>[
            _RawTransformRectNode(
              id: 'bad-node',
              rawTransform: const Transform2D(
                a: double.infinity,
                b: 0,
                c: 0,
                d: 1,
                tx: 0,
                ty: 0,
              ),
            ),
          ],
        ),
      ],
    );

    final violations = txnCollectCriticalStoreInvariantViolations(
      scene: scene,
      commitRevision: 1,
      previousCommitRevision: 0,
      previousScene: previousScene,
      changeSet: ChangeSet(),
    );

    expect(
      violations,
      isNot(contains('layers[0].nodes[0].transform.a must be finite.')),
    );
  });

  test(
    'critical runtime invariant check throws for invalid content layer id',
    () {
      final scene = Scene(
        layers: <ContentLayer>[ContentLayer(id: '', nodes: <SceneNode>[])],
      );
      expect(
        () => assertCriticalTxnStoreInvariants(
          scene: scene,
          commitRevision: 0,
          previousCommitRevision: -1,
        ),
        throwsStateError,
      );
    },
  );

  test('critical runtime invariant check throws on equal commit revision', () {
    final scene = sceneFixture();
    expect(
      () => assertCriticalTxnStoreInvariants(
        scene: scene,
        commitRevision: 3,
        previousCommitRevision: 3,
      ),
      throwsStateError,
    );
  });

  test(
    'critical runtime invariant check passes on strictly increasing revision',
    () {
      final scene = sceneFixture();
      expect(
        () => assertCriticalTxnStoreInvariants(
          scene: scene,
          commitRevision: 4,
          previousCommitRevision: 3,
        ),
        returnsNormally,
      );
    },
  );

  test('detects mismatched nodeLocator entries', () {
    final scene = sceneFixture();
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{'node-1'},
      allNodeIds: const <NodeId>{'node-1'},
      nodeLocator: const <NodeId, NodeLocatorEntry>{
        'node-1': (layerIndex: 0, nodeIndex: 7),
      },
      idGeneratorState: state(nextNodeCounter: 2),
      nextInstanceRevision: 2,
      commitRevision: 0,
    );
    expect(
      violations.join('\n'),
      contains('nodeLocator must match buildNodeLocator(scene)'),
    );
  });

  test('detects mismatch between allNodeIds and nodeLocator keys', () {
    final scene = sceneFixture();
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{'node-1'},
      allNodeIds: const <NodeId>{'node-1'},
      nodeLocator: const <NodeId, NodeLocatorEntry>{},
      idGeneratorState: state(nextNodeCounter: 2),
      nextInstanceRevision: 2,
      commitRevision: 0,
    );
    expect(
      violations.join('\n'),
      contains('allNodeIds must equal nodeLocator keys'),
    );
  });
}

final class _RawCamera extends Camera {
  _RawCamera(this._offset) : super();

  final Offset _offset;

  @override
  Offset get offset => _offset;
}

final class _RawBackground extends Background {
  _RawBackground({required Color color, required GridSettings grid})
    : _color = color,
      _grid = grid,
      super();

  final Color _color;
  final GridSettings _grid;

  @override
  Color get color => _color;

  @override
  GridSettings get grid => _grid;
}

final class _RawGridSettings extends GridSettings {
  _RawGridSettings({
    required bool isEnabled,
    required double cellSize,
    required Color color,
  }) : _isEnabled = isEnabled,
       _cellSize = cellSize,
       _color = color,
       super();

  final bool _isEnabled;
  final double _cellSize;
  final Color _color;

  @override
  bool get isEnabled => _isEnabled;

  @override
  double get cellSize => _cellSize;

  @override
  Color get color => _color;
}

final class _RawScenePalette extends ScenePalette {
  _RawScenePalette({
    required List<Color> penColors,
    required List<Color> backgroundColors,
    required List<double> gridSizes,
  }) : _penColors = penColors,
       _backgroundColors = backgroundColors,
       _gridSizes = gridSizes,
       super();

  final List<Color> _penColors;
  final List<Color> _backgroundColors;
  final List<double> _gridSizes;

  @override
  List<Color> get penColors => _penColors;

  @override
  List<Color> get backgroundColors => _backgroundColors;

  @override
  List<double> get gridSizes => _gridSizes;
}

class _BadInstanceRevisionNode extends SceneNode {
  _BadInstanceRevisionNode({required super.id}) : super(type: NodeType.rect);

  int _fakeInstanceRevision = 1;

  @override
  int get instanceRevision => _fakeInstanceRevision;

  void forceInvalidInstanceRevision() {
    _fakeInstanceRevision = 0;
  }

  @override
  Rect get localBounds => Rect.zero;
}

final class _RawTransformRectNode extends RectNode {
  _RawTransformRectNode({required super.id, required Transform2D rawTransform})
    : _rawTransform = rawTransform,
      super(size: const Size(10, 10));

  final Transform2D _rawTransform;

  @override
  Transform2D get transform => _rawTransform;
}
