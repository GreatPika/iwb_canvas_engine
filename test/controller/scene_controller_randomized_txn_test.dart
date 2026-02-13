import 'dart:io';
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
  final scenarioSeeds = _resolveScenarioSeeds();
  final scenarioSteps = _resolveScenarioSteps();

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
  insertStroke,
  insertPath,
  eraseRandom,
  patchNodeSpecific,
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
        case _RandomOperation.insertStroke:
          controller.write<void>((writer) {
            writer.writeNodeInsert(
              StrokeNodeSpec(
                points: _randomStrokePoints(
                  random,
                  minPoints: 2,
                  maxPoints: 64,
                ),
                thickness: _randomPositive(random, min: 0.5, max: 16),
                color: _randomColor(random),
                transform: _randomTransform(random),
                opacity: _randomOpacity(random),
                hitPadding: _randomNonNegative(random),
              ),
            );
          });
        case _RandomOperation.insertPath:
          controller.write<void>((writer) {
            writer.writeNodeInsert(
              PathNodeSpec(
                svgPathData: _randomSvgPathData(
                  random,
                  minSegments: 2,
                  maxSegments: 48,
                ),
                fillColor: _randomNullableColor(random),
                strokeColor: _randomNullableColor(random),
                strokeWidth: _randomNonNegative(random),
                fillRule: random.nextBool()
                    ? V2PathFillRule.nonZero
                    : V2PathFillRule.evenOdd,
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
        case _RandomOperation.patchNodeSpecific:
          final node = _randomNodeSnapshot(controller.snapshot, random);
          if (node == null) return;
          controller.write<void>((writer) {
            writer.writeNodePatch(_typeSpecificPatchForNode(node, random));
          });
        case _RandomOperation.patchCommon:
          final node = _randomNodeSnapshot(controller.snapshot, random);
          if (node == null) return;
          controller.write<void>((writer) {
            writer.writeNodePatch(
              _commonPatchForNode(node: node, random: random),
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
  _assertFiniteSnapshotNumbers(snapshot: snapshot, context: context);

  final duplicateIds = _duplicateNodeIds(snapshot);
  expect(
    duplicateIds,
    isEmpty,
    reason: '$context duplicateNodeIds=$duplicateIds',
  );

  expect(
    snapshot.backgroundLayer == null ||
        snapshot.backgroundLayer is BackgroundLayerSnapshot,
    isTrue,
    reason: '$context backgroundLayer must be nullable single layer',
  );

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
    layers: <ContentLayerSnapshot>[
      ContentLayerSnapshot(
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
  final nodeCount = random.nextInt(8);
  final nodes = <NodeSnapshot>[
    for (var i = 0; i < nodeCount; i++)
      _randomReplacementNodeSnapshot(
        random: random,
        id: 'seed-$seed-step-$step-node-$i',
      ),
  ];

  final layers = <ContentLayerSnapshot>[
    if (includeBackground) ContentLayerSnapshot(),
    ContentLayerSnapshot(nodes: nodes),
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

NodeSnapshot? _randomNodeSnapshot(SceneSnapshot snapshot, math.Random random) {
  final nodes = <NodeSnapshot>[
    for (final layer in snapshot.layers) ...layer.nodes,
  ];
  if (nodes.isEmpty) {
    return null;
  }
  return nodes[random.nextInt(nodes.length)];
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

List<int> _resolveScenarioSeeds() {
  final configured = Platform.environment['IWB_FUZZ_SEEDS']?.trim();
  if (configured != null && configured.isNotEmpty) {
    final parsed = configured
        .split(',')
        .map((token) => int.tryParse(token.trim()))
        .whereType<int>()
        .toList(growable: false);
    if (parsed.isNotEmpty) {
      return parsed;
    }
  }

  final baseSeed = _resolveEnvInt('IWB_FUZZ_BASE_SEED', fallback: 11);
  return <int>[baseSeed, baseSeed + 18, baseSeed + 36];
}

int _resolveScenarioSteps() {
  return _resolveEnvInt('IWB_FUZZ_STEPS', fallback: 200);
}

int _resolveEnvInt(String key, {required int fallback}) {
  final raw = Platform.environment[key];
  if (raw == null || raw.trim().isEmpty) {
    return fallback;
  }
  final parsed = int.tryParse(raw.trim());
  if (parsed == null) {
    return fallback;
  }
  return parsed;
}

NodePatch _typeSpecificPatchForNode(NodeSnapshot node, math.Random random) {
  switch (node) {
    case RectNodeSnapshot():
      return RectNodePatch(
        id: node.id,
        size: PatchField<Size>.value(_randomSize(random)),
        fillColor: PatchField<Color?>.value(_randomNullableColor(random)),
        strokeColor: PatchField<Color?>.value(_randomNullableColor(random)),
        strokeWidth: PatchField<double>.value(_randomNonNegative(random)),
      );
    case StrokeNodeSnapshot():
      return StrokeNodePatch(
        id: node.id,
        points: PatchField<List<Offset>>.value(
          _randomStrokePoints(random, minPoints: 2, maxPoints: 128),
        ),
        thickness: PatchField<double>.value(
          _randomPositive(random, min: 0.5, max: 24),
        ),
        color: PatchField<Color>.value(_randomColor(random)),
      );
    case PathNodeSnapshot():
      return PathNodePatch(
        id: node.id,
        svgPathData: PatchField<String>.value(
          _randomSvgPathData(random, minSegments: 2, maxSegments: 64),
        ),
        fillColor: PatchField<Color?>.value(_randomNullableColor(random)),
        strokeColor: PatchField<Color?>.value(_randomNullableColor(random)),
        strokeWidth: PatchField<double>.value(_randomNonNegative(random)),
        fillRule: PatchField<V2PathFillRule>.value(
          random.nextBool() ? V2PathFillRule.nonZero : V2PathFillRule.evenOdd,
        ),
      );
    case LineNodeSnapshot():
      return LineNodePatch(
        id: node.id,
        start: PatchField<Offset>.value(_randomOffset(random)),
        end: PatchField<Offset>.value(_randomOffset(random)),
        thickness: PatchField<double>.value(
          _randomPositive(random, min: 0.5, max: 20),
        ),
        color: PatchField<Color>.value(_randomColor(random)),
      );
    case TextNodeSnapshot():
      return TextNodePatch(
        id: node.id,
        text: PatchField<String>.value('text-${random.nextInt(1000)}'),
        fontSize: PatchField<double>.value(
          _randomPositive(random, min: 8, max: 64),
        ),
        color: PatchField<Color>.value(_randomColor(random)),
        isBold: PatchField<bool>.value(random.nextBool()),
        isItalic: PatchField<bool>.value(random.nextBool()),
        isUnderline: PatchField<bool>.value(random.nextBool()),
        maxWidth: PatchField<double?>.value(
          random.nextBool() ? null : _randomPositive(random, min: 20, max: 300),
        ),
        lineHeight: PatchField<double?>.value(
          random.nextBool() ? null : _randomPositive(random, min: 0.8, max: 2),
        ),
      );
    case ImageNodeSnapshot():
      return ImageNodePatch(
        id: node.id,
        size: PatchField<Size>.value(_randomSize(random)),
        naturalSize: PatchField<Size?>.value(
          random.nextBool() ? null : _randomSize(random),
        ),
      );
  }
}

NodePatch _commonPatchForNode({
  required NodeSnapshot node,
  required math.Random random,
}) {
  final common = CommonNodePatch(
    transform: PatchField<Transform2D>.value(_randomTransform(random)),
    opacity: PatchField<double>.value(_randomOpacity(random)),
    hitPadding: PatchField<double>.value(_randomNonNegative(random)),
    isVisible: PatchField<bool>.value(random.nextBool()),
    isSelectable: PatchField<bool>.value(random.nextBool()),
    isLocked: PatchField<bool>.value(random.nextBool()),
    isDeletable: PatchField<bool>.value(random.nextBool()),
    isTransformable: PatchField<bool>.value(random.nextBool()),
  );

  switch (node) {
    case RectNodeSnapshot():
      return RectNodePatch(id: node.id, common: common);
    case StrokeNodeSnapshot():
      return StrokeNodePatch(id: node.id, common: common);
    case PathNodeSnapshot():
      return PathNodePatch(id: node.id, common: common);
    case LineNodeSnapshot():
      return LineNodePatch(id: node.id, common: common);
    case TextNodeSnapshot():
      return TextNodePatch(id: node.id, common: common);
    case ImageNodeSnapshot():
      return ImageNodePatch(id: node.id, common: common);
  }
}

NodeSnapshot _randomReplacementNodeSnapshot({
  required math.Random random,
  required String id,
}) {
  final variant = random.nextInt(3);
  switch (variant) {
    case 0:
      return RectNodeSnapshot(
        id: id,
        size: _randomSize(random),
        fillColor: _randomNullableColor(random),
        strokeColor: _randomNullableColor(random),
        strokeWidth: _randomNonNegative(random),
        transform: _randomTransform(random),
        opacity: _randomOpacity(random),
        hitPadding: _randomNonNegative(random),
      );
    case 1:
      return StrokeNodeSnapshot(
        id: id,
        points: _randomStrokePoints(random, minPoints: 2, maxPoints: 96),
        thickness: _randomPositive(random, min: 0.5, max: 16),
        color: _randomColor(random),
        transform: _randomTransform(random),
        opacity: _randomOpacity(random),
        hitPadding: _randomNonNegative(random),
      );
    default:
      return PathNodeSnapshot(
        id: id,
        svgPathData: _randomSvgPathData(
          random,
          minSegments: 2,
          maxSegments: 64,
        ),
        fillColor: _randomNullableColor(random),
        strokeColor: _randomNullableColor(random),
        strokeWidth: _randomNonNegative(random),
        fillRule: random.nextBool()
            ? V2PathFillRule.nonZero
            : V2PathFillRule.evenOdd,
        transform: _randomTransform(random),
        opacity: _randomOpacity(random),
        hitPadding: _randomNonNegative(random),
      );
  }
}

List<Offset> _randomStrokePoints(
  math.Random random, {
  required int minPoints,
  required int maxPoints,
}) {
  final count = minPoints + random.nextInt(maxPoints - minPoints + 1);
  var x = _randomInRange(random, min: -20, max: 20);
  var y = _randomInRange(random, min: -20, max: 20);
  final points = <Offset>[Offset(x, y)];
  for (var i = 1; i < count; i++) {
    x = x + _randomInRange(random, min: -8, max: 8);
    y = y + _randomInRange(random, min: -8, max: 8);
    points.add(Offset(x, y));
  }
  return points;
}

String _randomSvgPathData(
  math.Random random, {
  required int minSegments,
  required int maxSegments,
}) {
  final count = minSegments + random.nextInt(maxSegments - minSegments + 1);
  final buf = StringBuffer('M0 0');
  var x = 0.0;
  var y = 0.0;
  for (var i = 0; i < count; i++) {
    x = x + _randomInRange(random, min: -20, max: 20);
    y = y + _randomInRange(random, min: -20, max: 20);
    buf.write(' L$x $y');
  }
  return buf.toString();
}

void _assertFiniteSnapshotNumbers({
  required SceneSnapshot snapshot,
  required String context,
}) {
  expect(
    _isFiniteOffset(snapshot.camera.offset),
    isTrue,
    reason: '$context camera.offset',
  );
  expect(
    snapshot.background.grid.cellSize.isFinite &&
        snapshot.background.grid.cellSize > 0,
    isTrue,
    reason: '$context background.grid.cellSize',
  );
  for (final layer in snapshot.layers) {
    for (final node in layer.nodes) {
      final nodeCtx = '$context node=${node.id}';
      expect(
        _isFiniteTransform(node.transform),
        isTrue,
        reason: '$nodeCtx transform',
      );
      expect(
        node.opacity.isFinite && node.opacity >= 0 && node.opacity <= 1,
        isTrue,
        reason: '$nodeCtx opacity',
      );
      expect(
        node.hitPadding.isFinite && node.hitPadding >= 0,
        isTrue,
        reason: '$nodeCtx hitPadding',
      );

      switch (node) {
        case RectNodeSnapshot():
          expect(
            _isFiniteSize(node.size) &&
                node.strokeWidth.isFinite &&
                node.strokeWidth >= 0,
            isTrue,
            reason: '$nodeCtx rect',
          );
        case StrokeNodeSnapshot():
          expect(
            node.thickness.isFinite &&
                node.thickness > 0 &&
                node.pointsRevision >= 0,
            isTrue,
            reason: '$nodeCtx stroke',
          );
          for (final point in node.points) {
            expect(
              _isFiniteOffset(point),
              isTrue,
              reason: '$nodeCtx strokePoint',
            );
          }
        case PathNodeSnapshot():
          expect(
            node.strokeWidth.isFinite && node.strokeWidth >= 0,
            isTrue,
            reason: '$nodeCtx path',
          );
        case LineNodeSnapshot():
          expect(
            _isFiniteOffset(node.start) &&
                _isFiniteOffset(node.end) &&
                node.thickness.isFinite &&
                node.thickness > 0,
            isTrue,
            reason: '$nodeCtx line',
          );
        case TextNodeSnapshot():
          expect(
            _isFiniteSize(node.size) &&
                node.fontSize.isFinite &&
                node.fontSize > 0,
            isTrue,
            reason: '$nodeCtx text',
          );
          final maxWidth = node.maxWidth;
          if (maxWidth != null) {
            expect(
              maxWidth.isFinite && maxWidth > 0,
              isTrue,
              reason: '$nodeCtx text.maxWidth',
            );
          }
          final lineHeight = node.lineHeight;
          if (lineHeight != null) {
            expect(
              lineHeight.isFinite && lineHeight > 0,
              isTrue,
              reason: '$nodeCtx text.lineHeight',
            );
          }
        case ImageNodeSnapshot():
          expect(
            _isFiniteSize(node.size),
            isTrue,
            reason: '$nodeCtx image.size',
          );
          final naturalSize = node.naturalSize;
          if (naturalSize != null) {
            expect(
              _isFiniteSize(naturalSize),
              isTrue,
              reason: '$nodeCtx image.naturalSize',
            );
          }
      }
    }
  }
}

bool _isFiniteOffset(Offset value) => value.dx.isFinite && value.dy.isFinite;

bool _isFiniteSize(Size value) =>
    value.width.isFinite &&
    value.height.isFinite &&
    value.width >= 0 &&
    value.height >= 0;

bool _isFiniteTransform(Transform2D value) =>
    value.a.isFinite &&
    value.b.isFinite &&
    value.c.isFinite &&
    value.d.isFinite &&
    value.tx.isFinite &&
    value.ty.isFinite;

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
