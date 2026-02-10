import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/controller/scene_invariants.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';

// INV:INV-V2-ID-INDEX-FROM-SCENE
// INV:INV-V2-WRITE-NUMERIC-GUARDS

void main() {
  Scene sceneFixture({
    bool gridEnabled = false,
    double gridCellSize = 16,
    Offset cameraOffset = Offset.zero,
  }) {
    return Scene(
      layers: <Layer>[
        Layer(
          nodes: <SceneNode>[RectNode(id: 'node-1', size: const Size(10, 10))],
        ),
      ],
      camera: Camera(offset: cameraOffset),
      background: Background(
        grid: GridSettings(isEnabled: gridEnabled, cellSize: gridCellSize),
      ),
    );
  }

  test('returns no violations for valid committed store', () {
    final scene = sceneFixture(gridEnabled: true, gridCellSize: 16);
    final violations = txnCollectStoreInvariantViolations(
      scene: scene,
      selectedNodeIds: const <NodeId>{'node-1'},
      allNodeIds: const <NodeId>{'node-1'},
      nodeIdSeed: 2,
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
      nodeIdSeed: 7,
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
      contains('nodeIdSeed must be derived from scene'),
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
      nodeIdSeed: 2,
      commitRevision: 0,
    );

    expect(violations.join('\n'), contains('enabled grid.cellSize must be >='));
  });

  test('debug assert throws for invalid committed store', () {
    final scene = sceneFixture(cameraOffset: const Offset(double.nan, 0));
    expect(
      () => debugAssertTxnStoreInvariants(
        scene: scene,
        selectedNodeIds: const <NodeId>{},
        allNodeIds: const <NodeId>{},
        nodeIdSeed: 0,
        commitRevision: 0,
      ),
      throwsStateError,
    );
  });
}
