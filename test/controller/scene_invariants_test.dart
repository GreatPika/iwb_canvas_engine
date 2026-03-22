import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/scene_invariants.dart';
import 'package:iwb_canvas_engine/src/core/id_generator.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/revision_policy.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/model/document.dart';

// INV:INV-ENG-ID-INDEX-FROM-SCENE
// INV:INV-ENG-INSTANCE-REVISION-MONOTONIC
// INV:INV-G-NODEID-UNIQUE
// INV:INV-G-LAYERID-UNIQUE

void main() {
  Scene sceneFixture({
    bool gridEnabled = false,
    double gridCellSize = 16,
    Offset cameraOffset = Offset.zero,
  }) {
    return Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-0',
          nodes: <SceneNode>[RectNode(id: 'node-1', size: const Size(10, 10))],
        ),
      ],
      camera: Camera(offset: cameraOffset),
      background: Background(
        grid: GridSettings(isEnabled: gridEnabled, cellSize: gridCellSize),
      ),
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
    final scene = sceneFixture(
      gridEnabled: false,
      gridCellSize: double.nan,
      cameraOffset: const Offset(double.infinity, 0),
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
    expect(violations.join('\n'), contains('camera.offset must be finite'));
    expect(
      violations.join('\n'),
      contains('grid.cellSize must be finite and > 0'),
    );
  });

  test('checks minimum enabled grid size invariant', () {
    final scene = sceneFixture(gridEnabled: true, gridCellSize: 0.5);
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{'node-1'},
      allNodeIds: const <NodeId>{'node-1'},
      nodeLocator: const <NodeId, NodeLocatorEntry>{
        'node-1': (layerIndex: 0, nodeIndex: 0),
      },
      idGeneratorState: state(nextNodeCounter: 2),
      nextInstanceRevision: 2,
      commitRevision: 0,
    );

    expect(violations.join('\n'), contains('enabled grid.cellSize must be >='));
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
      contains('scene must not contain duplicate node ids'),
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
      contains('scene must not contain duplicate content layer ids'),
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
      contains('scene must not contain duplicate node ids'),
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
      contains('scene must not contain duplicate node ids'),
    );
  });

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
    final scene = sceneFixture(cameraOffset: const Offset(double.nan, 0));
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

  test('critical runtime invariant check throws for invalid numeric state', () {
    final scene = sceneFixture(
      gridEnabled: false,
      gridCellSize: double.nan,
      cameraOffset: const Offset(double.infinity, 0),
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
    'critical runtime invariant check reports negative commit and enabled min grid',
    () {
      final scene = sceneFixture(gridEnabled: true, gridCellSize: 0.5);
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
