import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/controller/scene_controller.dart';
import 'package:iwb_canvas_engine/src/controller/scene_invariants.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart' show Scene;
import 'package:iwb_canvas_engine/src/model/document.dart';
import 'package:iwb_canvas_engine/src/model/document_clone.dart';

// INV:INV-G-NODEID-UNIQUE
// INV:INV-V2-ID-INDEX-FROM-SCENE

void main() {
  const scenarioSeeds = <int>[11, 29, 47];
  const scenarioSteps = 200;

  for (final seed in scenarioSeeds) {
    test('randomized transactional scenario keeps invariants (seed=$seed)', () {
      final random = math.Random(seed);
      final controller = SceneControllerV2(initialSnapshot: _initialSnapshot());
      addTearDown(controller.dispose);

      for (var step = 0; step < scenarioSteps; step++) {
        final operation = _runRandomOperation(
          controller: controller,
          random: random,
          seed: seed,
          step: step,
        );
        _assertPostConditions(
          controller: controller,
          seed: seed,
          step: step,
          operation: operation,
        );
      }
    });
  }
}

enum _RandomOperation {
  insertRect,
  eraseRandom,
  patchRect,
  patchCommon,
  selectionReplace,
  selectionToggle,
  selectionTranslate,
  selectionTransform,
  deleteSelection,
  clearScene,
  cameraOffset,
  gridEnable,
  gridCellSize,
  backgroundColor,
  replaceScene,
}

String _runRandomOperation({
  required SceneControllerV2 controller,
  required math.Random random,
  required int seed,
  required int step,
}) {
  final operation =
      _RandomOperation.values[random.nextInt(_RandomOperation.values.length)];
  final context = _opContext(seed: seed, step: step, operation: operation.name);

  expect(
    () {
      switch (operation) {
        case _RandomOperation.insertRect:
          controller.write<void>((writer) {
            writer.writeNodeInsert(
              RectNodeSpec(
                size: _randomSize(random),
                fillColor: _randomNullableColor(random),
                strokeColor: _randomNullableColor(random),
                strokeWidth: _randomNonNegative(random),
                transform: _randomTransform(random),
                opacity: _randomOpacity(random),
                hitPadding: _randomNonNegative(random),
              ),
            );
          });
        case _RandomOperation.eraseRandom:
          final id = _randomNodeId(controller.snapshot, random);
          if (id == null) return;
          controller.write<void>((writer) {
            writer.writeNodeErase(id);
          });
        case _RandomOperation.patchRect:
          final id = _randomNodeId(controller.snapshot, random);
          if (id == null) return;
          controller.write<void>((writer) {
            writer.writeNodePatch(
              RectNodePatch(
                id: id,
                size: PatchField<Size>.value(_randomSize(random)),
                fillColor: PatchField<Color?>.value(
                  _randomNullableColor(random),
                ),
                strokeColor: PatchField<Color?>.value(
                  _randomNullableColor(random),
                ),
                strokeWidth: PatchField<double>.value(
                  _randomNonNegative(random),
                ),
              ),
            );
          });
        case _RandomOperation.patchCommon:
          final id = _randomNodeId(controller.snapshot, random);
          if (id == null) return;
          controller.write<void>((writer) {
            writer.writeNodePatch(
              RectNodePatch(
                id: id,
                common: CommonNodePatch(
                  transform: PatchField<Transform2D>.value(
                    _randomTransform(random),
                  ),
                  opacity: PatchField<double>.value(_randomOpacity(random)),
                  hitPadding: PatchField<double>.value(
                    _randomNonNegative(random),
                  ),
                ),
              ),
            );
          });
        case _RandomOperation.selectionReplace:
          final ids = _allNodeIds(controller.snapshot);
          final nextSelection = _randomSubset(ids, random);
          controller.write<void>((writer) {
            writer.writeSelectionReplace(nextSelection);
          });
        case _RandomOperation.selectionToggle:
          final ids = _allNodeIds(controller.snapshot);
          if (ids.isEmpty) return;
          final id = ids[random.nextInt(ids.length)];
          controller.write<void>((writer) {
            writer.writeSelectionToggle(id);
          });
        case _RandomOperation.selectionTranslate:
          controller.write<void>((writer) {
            writer.writeSelectionTranslate(_randomOffset(random));
          });
        case _RandomOperation.selectionTransform:
          controller.write<void>((writer) {
            writer.writeSelectionTransform(_randomTransform(random));
          });
        case _RandomOperation.deleteSelection:
          controller.write<void>((writer) {
            writer.writeDeleteSelection();
          });
        case _RandomOperation.clearScene:
          controller.write<void>((writer) {
            writer.writeClearSceneKeepBackground();
          });
        case _RandomOperation.cameraOffset:
          controller.write<void>((writer) {
            writer.writeCameraOffset(_randomOffset(random));
          });
        case _RandomOperation.gridEnable:
          controller.write<void>((writer) {
            writer.writeGridEnable(random.nextBool());
          });
        case _RandomOperation.gridCellSize:
          controller.write<void>((writer) {
            writer.writeGridCellSize(_randomPositive(random, min: 1, max: 120));
          });
        case _RandomOperation.backgroundColor:
          controller.write<void>((writer) {
            writer.writeBackgroundColor(_randomColor(random));
          });
        case _RandomOperation.replaceScene:
          controller.writeReplaceScene(
            _randomReplacementSnapshot(random: random, seed: seed, step: step),
          );
      }
    },
    returnsNormally,
    reason: context,
  );

  return operation.name;
}

void _assertPostConditions({
  required SceneControllerV2 controller,
  required int seed,
  required int step,
  required String operation,
}) {
  final context = _opContext(seed: seed, step: step, operation: operation);
  final snapshot = controller.snapshot;

  final duplicateIds = _duplicateNodeIds(snapshot);
  expect(
    duplicateIds,
    isEmpty,
    reason: '$context duplicateNodeIds=$duplicateIds',
  );

  final backgroundLayerIndexes = <int>[];
  for (var i = 0; i < snapshot.layers.length; i++) {
    if (snapshot.layers[i].isBackground) {
      backgroundLayerIndexes.add(i);
    }
  }
  expect(
    backgroundLayerIndexes.length <= 1,
    isTrue,
    reason: '$context backgroundLayerIndexes=$backgroundLayerIndexes',
  );
  if (backgroundLayerIndexes.isNotEmpty) {
    expect(
      backgroundLayerIndexes.single,
      0,
      reason: '$context backgroundLayerIndexes=$backgroundLayerIndexes',
    );
  }

  late final Scene scene;
  expect(
    () {
      scene = txnSceneFromSnapshot(snapshot);
    },
    returnsNormally,
    reason: '$context strictSnapshotValidationFailed',
  );

  final violations = txnCollectStoreInvariantViolations(
    scene: scene,
    selectedNodeIds: controller.selectedNodeIds,
    allNodeIds: txnCollectNodeIds(scene),
    nodeLocator: txnBuildNodeLocator(scene),
    nodeIdSeed: txnInitialNodeIdSeed(scene),
    commitRevision: controller.debugCommitRevision,
  );
  expect(
    violations,
    isEmpty,
    reason: '$context invariantViolations=$violations',
  );
}

SceneSnapshot _initialSnapshot() {
  return SceneSnapshot(
    layers: <LayerSnapshot>[
      LayerSnapshot(
        nodes: const <NodeSnapshot>[
          RectNodeSnapshot(id: 'seed-r1', size: Size(10, 10)),
          RectNodeSnapshot(id: 'seed-r2', size: Size(12, 12)),
        ],
      ),
    ],
  );
}

SceneSnapshot _randomReplacementSnapshot({
  required math.Random random,
  required int seed,
  required int step,
}) {
  final includeBackground = random.nextBool();
  final nodeCount = random.nextInt(4);
  final nodes = <NodeSnapshot>[
    for (var i = 0; i < nodeCount; i++)
      RectNodeSnapshot(
        id: 'seed-$seed-step-$step-node-$i',
        size: _randomSize(random),
        fillColor: _randomNullableColor(random),
        strokeColor: _randomNullableColor(random),
        strokeWidth: _randomNonNegative(random),
        transform: _randomTransform(random),
        opacity: _randomOpacity(random),
        hitPadding: _randomNonNegative(random),
      ),
  ];

  final layers = <LayerSnapshot>[
    if (includeBackground) LayerSnapshot(isBackground: true),
    LayerSnapshot(nodes: nodes),
  ];

  return SceneSnapshot(
    layers: layers,
    camera: CameraSnapshot(offset: _randomOffset(random)),
    background: BackgroundSnapshot(
      color: _randomColor(random),
      grid: GridSnapshot(
        isEnabled: random.nextBool(),
        cellSize: _randomPositive(random, min: 1, max: 120),
        color: _randomColor(random),
      ),
    ),
  );
}

List<NodeId> _allNodeIds(SceneSnapshot snapshot) {
  return <NodeId>[
    for (final layer in snapshot.layers)
      for (final node in layer.nodes) node.id,
  ];
}

NodeId? _randomNodeId(SceneSnapshot snapshot, math.Random random) {
  final ids = _allNodeIds(snapshot);
  if (ids.isEmpty) {
    return null;
  }
  return ids[random.nextInt(ids.length)];
}

Set<NodeId> _duplicateNodeIds(SceneSnapshot snapshot) {
  final seen = <NodeId>{};
  final duplicates = <NodeId>{};
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      if (!seen.add(node.id)) {
        duplicates.add(node.id);
      }
    }
  }
  return duplicates;
}

Set<NodeId> _randomSubset(List<NodeId> values, math.Random random) {
  final out = <NodeId>{};
  for (final value in values) {
    if (random.nextBool()) {
      out.add(value);
    }
  }
  if (out.isEmpty && values.isNotEmpty && random.nextBool()) {
    out.add(values[random.nextInt(values.length)]);
  }
  return out;
}

Color _randomColor(math.Random random) {
  final rgb = random.nextInt(0x1000000);
  return Color(0xFF000000 | rgb);
}

Color? _randomNullableColor(math.Random random) {
  if (random.nextBool()) {
    return null;
  }
  return _randomColor(random);
}

double _randomNonNegative(math.Random random) {
  return random.nextDouble() * 40;
}

double _randomPositive(
  math.Random random, {
  required double min,
  required double max,
}) {
  return _randomInRange(random, min: min, max: max);
}

double _randomOpacity(math.Random random) {
  return _randomInRange(random, min: 0, max: 1);
}

Size _randomSize(math.Random random) {
  return Size(
    _randomPositive(random, min: 1, max: 300),
    _randomPositive(random, min: 1, max: 300),
  );
}

Offset _randomOffset(math.Random random) {
  return Offset(
    _randomInRange(random, min: -500, max: 500),
    _randomInRange(random, min: -500, max: 500),
  );
}

Transform2D _randomTransform(math.Random random) {
  return Transform2D(
    a: _randomInRange(random, min: 0.5, max: 2.0),
    b: _randomInRange(random, min: -0.5, max: 0.5),
    c: _randomInRange(random, min: -0.5, max: 0.5),
    d: _randomInRange(random, min: 0.5, max: 2.0),
    tx: _randomInRange(random, min: -200, max: 200),
    ty: _randomInRange(random, min: -200, max: 200),
  );
}

double _randomInRange(
  math.Random random, {
  required double min,
  required double max,
}) {
  final value = random.nextDouble() * (max - min);
  return min + value;
}

String _opContext({
  required int seed,
  required int step,
  required String operation,
}) {
  return 'seed=$seed step=$step op=$operation';
}
