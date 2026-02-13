import 'dart:collection';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/model/scene_builder.dart'
    as model_builder;
import 'package:iwb_canvas_engine/src/model/scene_value_validation.dart'
    as value_validation;

Map<String, Object?> _minimalRectNodeJson({required String id}) {
  return <String, Object?>{
    'id': id,
    'type': 'rect',
    'transform': <String, Object?>{
      'a': 1,
      'b': 0,
      'c': 0,
      'd': 1,
      'tx': 0,
      'ty': 0,
    },
    'hitPadding': 0,
    'opacity': 1,
    'isVisible': true,
    'isSelectable': true,
    'isLocked': false,
    'isDeletable': true,
    'isTransformable': true,
    'size': <String, Object?>{'w': 1, 'h': 1},
    'strokeWidth': 0,
  };
}

Map<String, Object?> _minimalSceneJson() {
  return <String, Object?>{
    'schemaVersion': 2,
    'camera': <String, Object?>{'offsetX': 0, 'offsetY': 0},
    'background': <String, Object?>{
      'color': '#FFFFFFFF',
      'grid': <String, Object?>{
        'enabled': false,
        'cellSize': 10,
        'color': '#1F000000',
      },
    },
    'palette': <String, Object?>{
      'penColors': <Object?>['#FF000000'],
      'backgroundColors': <Object?>['#FFFFFFFF'],
      'gridSizes': <Object?>[10],
    },
    'layers': <Object?>[
      <String, Object?>{
        'isBackground': false,
        'nodes': <Object?>[_minimalRectNodeJson(id: 'n1')],
      },
    ],
  };
}

class _ThrowingMap extends MapBase<String, Object?> {
  @override
  Object? operator [](Object? key) => throw StateError('boom');

  @override
  void operator []=(String key, Object? value) =>
      throw UnsupportedError('noop');

  @override
  void clear() => throw UnsupportedError('noop');

  @override
  Iterable<String> get keys => const <String>[];

  @override
  Object? remove(Object? key) => throw UnsupportedError('noop');

  @override
  bool containsKey(Object? key) => throw StateError('boom');
}

void main() {
  test('sceneBuildFromJsonMap wraps unexpected parser errors', () {
    expect(
      () => model_builder.sceneBuildFromJsonMap(_ThrowingMap()),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidJson &&
              e.source is StateError,
        ),
      ),
    );
  });

  test(
    'sceneValidateCore canonicalizes background and preserves all node types',
    () {
      final scene = Scene(
        layers: <Layer>[
          Layer(
            nodes: <SceneNode>[
              ImageNode(
                id: 'img',
                imageId: 'image://1',
                size: const Size(8, 9),
                naturalSize: const Size(16, 18),
              ),
              TextNode(
                id: 'txt',
                text: 'hello',
                size: const Size(40, 12),
                fontSize: 18,
                color: const Color(0xFF112233),
                maxWidth: 120,
                lineHeight: 1.3,
              ),
              StrokeNode(
                id: 'str',
                points: const <Offset>[Offset(0, 0), Offset(3, 4)],
                thickness: 2,
                color: Color(0xFF445566),
              ),
              LineNode(
                id: 'ln',
                start: const Offset(0, 0),
                end: const Offset(10, 2),
                thickness: 3,
                color: const Color(0xFF778899),
              ),
              RectNode(id: 'rect', size: const Size(5, 6), strokeWidth: 1),
              PathNode(
                id: 'path-non-zero',
                svgPathData: 'M0 0 L5 0 L5 5 Z',
                strokeWidth: 1,
                fillRule: PathFillRule.nonZero,
              ),
              PathNode(
                id: 'path-even-odd',
                svgPathData: 'M0 0 L5 0 L5 5 Z',
                strokeWidth: 1,
                fillRule: PathFillRule.evenOdd,
              ),
            ],
          ),
          Layer(isBackground: true),
        ],
      );

      final canonical = model_builder.sceneValidateCore(scene);

      expect(canonical.layers.first.isBackground, isTrue);
      final nodes = canonical.layers[1].nodes;
      expect(nodes[0], isA<ImageNode>());
      expect(nodes[1], isA<TextNode>());
      expect(nodes[2], isA<StrokeNode>());
      expect(nodes[3], isA<LineNode>());
      expect(nodes[4], isA<RectNode>());
      expect(nodes[5], isA<PathNode>());
      expect(nodes[6], isA<PathNode>());
      expect((nodes[5] as PathNode).fillRule, PathFillRule.nonZero);
      expect((nodes[6] as PathNode).fillRule, PathFillRule.evenOdd);
    },
  );

  test('sceneBuildFromSnapshot rejects out-of-range transform values', () {
    final snapshot = SceneSnapshot(
      layers: <LayerSnapshot>[
        LayerSnapshot(
          nodes: const <NodeSnapshot>[
            RectNodeSnapshot(
              id: 'r1',
              size: Size(1, 1),
              transform: Transform2D(
                a: 1,
                b: 0,
                c: 0,
                d: 1,
                tx: 10000001,
                ty: 0,
              ),
            ),
          ],
        ),
      ],
    );

    expect(
      () => model_builder.sceneBuildFromSnapshot(snapshot),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.outOfRange &&
              e.path == 'layers[0].nodes[0].transform.tx',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap reports missing required fields', () {
    final missingCases =
        <({String label, String expectedPath, Map<String, Object?> json})>[
          (
            label: 'schemaVersion',
            expectedPath: 'schemaVersion',
            json: (() {
              final json = _minimalSceneJson();
              json.remove('schemaVersion');
              return json;
            })(),
          ),
          (
            label: 'camera',
            expectedPath: 'camera',
            json: (() {
              final json = _minimalSceneJson();
              json.remove('camera');
              return json;
            })(),
          ),
          (
            label: 'layers',
            expectedPath: 'layers',
            json: (() {
              final json = _minimalSceneJson();
              json.remove('layers');
              return json;
            })(),
          ),
          (
            label: 'node.id',
            expectedPath: 'id',
            json: (() {
              final json = _minimalSceneJson();
              final layer =
                  (json['layers'] as List<Object?>).first
                      as Map<String, Object?>;
              final node =
                  (layer['nodes'] as List<Object?>).first
                      as Map<String, Object?>;
              node.remove('id');
              return json;
            })(),
          ),
          (
            label: 'layer.isBackground',
            expectedPath: 'isBackground',
            json: (() {
              final json = _minimalSceneJson();
              final layer =
                  (json['layers'] as List<Object?>).first
                      as Map<String, Object?>;
              layer.remove('isBackground');
              return json;
            })(),
          ),
          (
            label: 'node.hitPadding',
            expectedPath: 'hitPadding',
            json: (() {
              final json = _minimalSceneJson();
              final layer =
                  (json['layers'] as List<Object?>).first
                      as Map<String, Object?>;
              final node =
                  (layer['nodes'] as List<Object?>).first
                      as Map<String, Object?>;
              node.remove('hitPadding');
              return json;
            })(),
          ),
        ];

    for (final testCase in missingCases) {
      expect(
        () => model_builder.sceneBuildFromJsonMap(testCase.json),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.missingField &&
                e.path == testCase.expectedPath,
          ),
        ),
        reason: testCase.label,
      );
    }
  });

  test('sceneBuildFromJsonMap rejects unsafe integer values', () {
    final json = _minimalSceneJson();
    json['schemaVersion'] = 9007199254740992.0;

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'schemaVersion',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects map keys that are not strings', () {
    final json = _minimalSceneJson();
    json['camera'] = <Object?, Object?>{'offsetX': 0, 'offsetY': 0, 1: 0};

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidFieldType &&
              e.message == 'JSON object keys must be strings.',
        ),
      ),
    );
  });

  test(
    'sceneValidateSnapshotValues reports duplicate node ids and backgrounds',
    () {
      SceneDataException asSceneDataException({
        required Object? value,
        required String field,
        required String message,
      }) {
        return SceneDataException(
          code: SceneDataErrorCode.invalidValue,
          path: field,
          message: 'Field $field $message',
          source: value,
        );
      }

      expect(
        () => value_validation.sceneValidateSnapshotValues(
          SceneSnapshot(
            layers: <LayerSnapshot>[
              LayerSnapshot(
                nodes: const <NodeSnapshot>[
                  RectNodeSnapshot(id: 'dup', size: Size(1, 1)),
                  RectNodeSnapshot(id: 'dup', size: Size(1, 1)),
                ],
              ),
            ],
          ),
          onError:
              ({
                required Object? value,
                required String field,
                required String message,
              }) {
                throw asSceneDataException(
                  value: value,
                  field: field,
                  message: message,
                );
              },
          requirePositiveGridCellSize: true,
        ),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.path == 'layers[0].nodes[1].id' &&
                e.message ==
                    'Field layers[0].nodes[1].id must be unique across scene layers.',
          ),
        ),
      );

      expect(
        () => value_validation.sceneValidateSnapshotValues(
          SceneSnapshot(
            layers: <LayerSnapshot>[
              LayerSnapshot(isBackground: true),
              LayerSnapshot(isBackground: true),
            ],
          ),
          onError:
              ({
                required Object? value,
                required String field,
                required String message,
              }) {
                throw asSceneDataException(
                  value: value,
                  field: field,
                  message: message,
                );
              },
          requirePositiveGridCellSize: true,
        ),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.path == 'layers' &&
                e.message ==
                    'Field layers must contain at most one background layer.',
          ),
        ),
      );
    },
  );
}
