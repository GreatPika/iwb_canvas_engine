import 'dart:collection';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart' hide NodeId;
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/text_layout.dart'
    show TextLayoutRequest;
import 'package:iwb_canvas_engine/src/core/scene_limits.dart'
    show
        kMaxContentLayersPerScene,
        kMaxImageIdLength,
        kMaxNodesPerScene,
        kMaxPaletteItems,
        kMaxStrokePointsPerNode,
        kMaxSvgPathDataLength,
        kMaxTextLength;
import 'package:iwb_canvas_engine/src/model/scene_builder.dart'
    as model_builder;
import 'package:iwb_canvas_engine/src/model/document.dart'
    show txnSceneFromSnapshot, txnSceneToSnapshot;
import 'package:iwb_canvas_engine/src/model/scene_policy.dart';
import 'package:iwb_canvas_engine/src/model/scene_value_validation.dart'
    as value_validation;

import '../support/scene_builder_json_fixtures.dart';

Map<String, Object?> _minimalRectNodeJson({required String id}) {
  return minimalRectNodeJson(id: id);
}

Map<String, Object?> _minimalSceneJson() {
  return minimalSceneJson();
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

class _FormatThrowingMap extends MapBase<String, Object?> {
  @override
  Object? operator [](Object? key) => throw const FormatException('bad map');

  @override
  void operator []=(String key, Object? value) =>
      throw UnsupportedError('noop');

  @override
  void clear() => throw UnsupportedError('noop');

  @override
  Iterable<String> get keys => const <String>['schemaVersion'];

  @override
  Object? remove(Object? key) => throw UnsupportedError('noop');

  @override
  bool containsKey(Object? key) => throw const FormatException('bad map');
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
              e.source is Map<String, Object?> &&
              (e.source as Map<String, Object?>)['type'] == 'StateError',
        ),
      ),
    );
  });

  test(
    'sceneBuildFromDynamicJsonMap maps parsed-map normalization failures to invalidJsonPayload',
    () {
      final malformed = <Object?, Object?>{
        'schemaVersion': 5,
        1: 'non-string-key',
      };

      expect(
        () => model_builder.sceneBuildFromDynamicJsonMap(
          malformed.cast<String, Object?>(),
        ),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidJson &&
                e.path == null &&
                e.details['template'] == 'invalidJsonPayload',
          ),
        ),
      );
    },
  );

  test(
    'sceneBuildFromDynamicJsonMap maps FormatException failures to invalidJsonPayload',
    () {
      expect(
        () => model_builder.sceneBuildFromDynamicJsonMap(_FormatThrowingMap()),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidJson &&
                e.details['template'] == 'invalidJsonPayload',
          ),
        ),
      );
    },
  );

  test(
    'sceneValidateCore canonicalizes background and preserves all node types',
    () {
      final scene = Scene(
        backgroundLayer: BackgroundLayer(),
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-5',
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
        ],
      );

      final canonical = model_builder.sceneValidateCore(scene);

      expect(canonical.backgroundLayer, isNotNull);
      final nodes = canonical.layers.first.nodes;
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

  test('sceneCanonicalizeAndValidateScene canonicalizes runtime scene', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-delegate',
          nodes: <SceneNode>[
            RectNode(id: 'rect-runtime', size: const Size(4, 5)),
          ],
        ),
      ],
    );

    final canonical = model_builder.sceneCanonicalizeAndValidateScene(scene);

    expect(canonical.backgroundLayer, isNotNull);
    expect(canonical.layers.single.nodes.single.id, 'rect-runtime');
  });

  test(
    'sceneValidateCore materializes missing background layer without changing content ownership',
    () {
      final scene = Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-runtime-no-background',
            nodes: <SceneNode>[
              RectNode(
                id: 'rect-runtime-no-background',
                size: const Size(4, 5),
              ),
            ],
          ),
        ],
      );

      final canonical = model_builder.sceneValidateCore(scene);

      expect(canonical.backgroundLayer, isNotNull);
      final backgroundLayer = canonical.backgroundLayer;
      if (backgroundLayer == null) {
        fail('Expected sceneValidateCore to materialize background layer.');
      }
      expect(backgroundLayer.nodes, isEmpty);
      expect(canonical.layers.single.id, 'layer-auto-runtime-no-background');
      expect(
        canonical.layers.single.nodes.single.id,
        'rect-runtime-no-background',
      );
    },
  );

  test(
    'ScenePolicy runtime and encode entrypoints preserve runtime diagnostics',
    () {
      Scene duplicateScene() {
        return Scene(
          backgroundLayer: BackgroundLayer(
            nodes: <SceneNode>[
              RectNode(id: 'dup-runtime', size: const Size(1, 1)),
            ],
          ),
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-runtime-dup',
              nodes: <SceneNode>[
                RectNode(id: 'dup-runtime', size: const Size(2, 2)),
              ],
            ),
          ],
        );
      }

      final validators = <Scene Function(Scene)>[
        (scene) => ScenePolicy.validateRuntimeScene(
          scene,
          snapshotFromScene: txnSceneToSnapshot,
          sceneFromSnapshot: txnSceneFromSnapshot,
        ),
        (scene) => ScenePolicy.validateEncodeScene(
          scene,
          snapshotFromScene: txnSceneToSnapshot,
          sceneFromSnapshot: txnSceneFromSnapshot,
        ),
      ];

      for (final validate in validators) {
        expect(
          () => validate(duplicateScene()),
          throwsA(
            predicate(
              (e) =>
                  e is SceneDataException &&
                  e.code == SceneDataErrorCode.duplicateNodeId &&
                  e.path == 'layers[0].nodes[0].id' &&
                  e.message == 'Must be unique across scene layers.',
            ),
          ),
        );
      }
    },
  );

  test('sceneBuildFromSnapshot rejects out-of-range transform values', () {
    final snapshot = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-0',
          nodes: <NodeSnapshot>[
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

  test('sceneBuildFromSnapshot rejects singular transform values', () {
    final snapshot = sceneSnapshotFromValidated(
      layers: <ContentLayerSnapshot>[
        contentLayerSnapshotFromValidated(
          id: 'layer-auto-1',
          nodes: <NodeSnapshot>[
            rectNodeSnapshotFromValidated(
              id: 'r1',
              size: const Size(1, 1),
              transform: const Transform2D(
                a: 1,
                b: 2,
                c: 2,
                d: 4,
                tx: 0,
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
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes[0].transform' &&
              e.message ==
                  'Field layers[0].nodes[0].transform must be invertible (non-singular).',
        ),
      ),
    );
  });

  test('sceneBuildFromSnapshot rejects duplicate content layer ids', () {
    final snapshot = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-dup',
          nodes: <NodeSnapshot>[RectNodeSnapshot(id: 'r1', size: Size(1, 1))],
        ),
        ContentLayerSnapshot(
          id: 'layer-auto-dup',
          nodes: <NodeSnapshot>[RectNodeSnapshot(id: 'r2', size: Size(1, 1))],
        ),
      ],
    );

    expect(
      () => model_builder.sceneBuildFromSnapshot(snapshot),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.duplicateLayerId &&
              e.path == 'layers[1].id' &&
              e.details['template'] == 'duplicateLayerId' &&
              e.message ==
                  'Field layers[1].id must be unique across content layers.',
        ),
      ),
    );
  });

  test(
    'sceneBuildFromSnapshot ignores input text size and re-derives canonical size',
    () {
      final textSnapshot = TextNodeSnapshot(
        id: 't-derived',
        text: 'Derived text size',
        size: Size(999, 777),
        fontSize: 24,
        color: Color(0xFF000000),
        align: TextAlign.left,
        isBold: false,
        isItalic: false,
        isUnderline: false,
      );
      final snapshot = SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-text',
            nodes: <NodeSnapshot>[textSnapshot],
          ),
        ],
      );

      final expectedSize = TextLayoutRequest(
        text: textSnapshot.text,
        color: textSnapshot.color,
        fontSize: textSnapshot.fontSize,
        isBold: textSnapshot.isBold,
        isItalic: textSnapshot.isItalic,
        isUnderline: textSnapshot.isUnderline,
        textAlign: textSnapshot.align,
        fontFamily: textSnapshot.fontFamily,
        lineHeight: textSnapshot.lineHeight,
        maxWidth: textSnapshot.maxWidth,
      ).measure();

      final scene = model_builder.sceneBuildFromSnapshot(snapshot);
      final textNode = scene.layers.first.nodes.single as TextNode;

      expect(textNode.size, isNot(textSnapshot.size));
      expect(textNode.size.width, closeTo(expectedSize.width, 0.001));
      expect(textNode.size.height, closeTo(expectedSize.height, 0.001));
    },
  );

  test(
    'sceneBuildFromJsonMap keeps legacy node-* and layer-* ids readable',
    () {
      final json = _minimalSceneJson();
      json['backgroundLayer'] = <String, Object?>{
        'nodes': <Object?>[
          <String, Object?>{..._minimalRectNodeJson(id: 'node-1')},
        ],
      };
      json['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-1',
          'nodes': <Object?>[
            <String, Object?>{..._minimalRectNodeJson(id: 'node-2')},
          ],
        },
      ];

      final scene = model_builder.sceneBuildFromJsonMap(json);

      expect(scene.backgroundLayer, isNotNull);
      final backgroundLayer = scene.backgroundLayer;
      if (backgroundLayer == null) {
        fail('Expected legacy payload import to materialize background layer.');
      }
      expect(backgroundLayer.nodes.single.id, 'node-1');
      expect(scene.layers.single.id, 'layer-1');
      expect(scene.layers.single.nodes.single.id, 'node-2');
    },
  );

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
            label: 'camera.offsetX',
            expectedPath: 'camera.offsetX',
            json: (() {
              final json = _minimalSceneJson();
              final camera = json['camera'] as Map<String, Object?>;
              camera.remove('offsetX');
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
            expectedPath: 'layers[0].nodes[0].id',
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
            label: 'node.hitPadding',
            expectedPath: 'layers[0].nodes[0].hitPadding',
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

  test('sceneBuildFromJsonMap rejects non-object background layer nodes', () {
    final json = _minimalSceneJson();
    json['backgroundLayer'] = <String, Object?>{
      'nodes': <Object?>[123],
    };

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidFieldType &&
              e.path == 'backgroundLayer.nodes[0]' &&
              e.message == 'Node must be an object.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects missing content layer id', () {
    final json = _minimalSceneJson();
    final layer =
        (json['layers'] as List<Object?>).first as Map<String, Object?>;
    layer.remove('id');

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.missingField &&
              e.path == 'layers[0].id' &&
              e.message == 'Missing required field layers[0].id.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects non-string content layer id', () {
    final json = _minimalSceneJson();
    final layer =
        (json['layers'] as List<Object?>).first as Map<String, Object?>;
    layer['id'] = 123;

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidFieldType &&
              e.path == 'layers[0].id' &&
              e.message == 'Field layers[0].id must be a string.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap reports missing required bool fields', () {
    final json = _minimalSceneJson();
    final layer =
        (json['layers'] as List<Object?>).first as Map<String, Object?>;
    final node =
        (layer['nodes'] as List<Object?>).first as Map<String, Object?>;
    node.remove('isVisible');

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.missingField &&
              e.path == 'layers[0].nodes[0].isVisible' &&
              e.message ==
                  'Missing required field layers[0].nodes[0].isVisible.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap distinguishes missingField and invalidFieldType '
      'messages for schemaVersion', () {
    final missingJson = _minimalSceneJson()..remove('schemaVersion');
    expect(
      () => model_builder.sceneBuildFromJsonMap(missingJson),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.missingField &&
              e.path == 'schemaVersion' &&
              e.message == 'Missing required field schemaVersion.',
        ),
      ),
    );

    final wrongTypeJson = _minimalSceneJson();
    wrongTypeJson['schemaVersion'] = '1';
    expect(
      () => model_builder.sceneBuildFromJsonMap(wrongTypeJson),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidFieldType &&
              e.path == 'schemaVersion' &&
              e.message == 'Field schemaVersion must be an int.',
        ),
      ),
    );
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

    final intLiteralJson = _minimalSceneJson();
    intLiteralJson['schemaVersion'] = 9007199254740992;

    expect(
      () => model_builder.sceneBuildFromJsonMap(intLiteralJson),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'schemaVersion' &&
              e.message == 'Field schemaVersion must be an int.',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects non-string palette color entries', () {
    final json = _minimalSceneJson();
    final palette = json['palette'] as Map<String, Object?>;
    palette['penColors'] = <Object?>[123];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidFieldType &&
              e.path == 'palette.penColors[0]' &&
              e.message == 'Items of penColors must be strings.',
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

  test('sceneBuildFromJsonMap rejects too many content layers', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      for (var i = 0; i < kMaxContentLayersPerScene + 1; i++)
        <String, Object?>{'id': 'layer-$i', 'nodes': <Object?>[]},
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers',
        ),
      ),
    );
  });

  test(
    'sceneBuildFromJsonMap reports content layer overflow before extra layer shape errors',
    () {
      final json = _minimalSceneJson();
      json['layers'] = <Object?>[
        for (var i = 0; i < kMaxContentLayersPerScene; i++)
          <String, Object?>{'id': 'layer-$i', 'nodes': <Object?>[]},
        null,
      ];

      expect(
        () => model_builder.sceneBuildFromJsonMap(json),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == 'layers',
          ),
        ),
      );
    },
  );

  test('sceneBuildFromJsonMap rejects too many nodes in scene', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          for (var i = 0; i < kMaxNodesPerScene + 1; i++)
            _minimalRectNodeJson(id: 'n$i'),
        ],
      },
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes',
        ),
      ),
    );
  });

  test(
    'sceneBuildFromJsonMap reports node overflow before extra node shape errors',
    () {
      final json = _minimalSceneJson();
      json['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-0',
          'nodes': <Object?>[
            for (var i = 0; i < kMaxNodesPerScene; i++)
              _minimalRectNodeJson(id: 'n$i'),
            <String, Object?>{
              'id': 'overflow-node',
              'transform': <String, Object?>{
                'a': 1,
                'b': 0,
                'c': 0,
                'd': 1,
                'tx': 0,
                'ty': 0,
              },
            },
          ],
        },
      ];

      expect(
        () => model_builder.sceneBuildFromJsonMap(json),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == 'layers[0].nodes',
          ),
        ),
      );
    },
  );

  test(
    'sceneBuildFromJsonMap rejects aggregated node overflow across background and content layers',
    () {
      final json = _minimalSceneJson();
      final contentNode = _minimalRectNodeJson(id: 'fg');
      json['backgroundLayer'] = <String, Object?>{
        'nodes': <Object?>[
          for (var i = 0; i < kMaxNodesPerScene; i++)
            _minimalRectNodeJson(id: 'bg-$i'),
        ],
      };
      json['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-0',
          'nodes': <Object?>[contentNode],
        },
      ];

      expect(
        () => model_builder.sceneBuildFromJsonMap(json),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == 'layers[0].nodes',
          ),
        ),
      );
    },
  );

  test('sceneBuildFromJsonMap rejects too many stroke points', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          <String, Object?>{
            ..._minimalRectNodeJson(id: 's1'),
            'type': 'stroke',
            'localPoints': <Object?>[
              for (var i = 0; i < kMaxStrokePointsPerNode + 1; i++)
                <String, Object?>{'x': i.toDouble(), 'y': 0.0},
            ],
            'thickness': 1,
            'color': '#FF000000',
          },
        ],
      },
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes[0].localPoints',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects oversized svgPathData', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          <String, Object?>{
            ..._minimalRectNodeJson(id: 'p1'),
            'type': 'path',
            'svgPathData':
                "M0 0 ${List<String>.filled(kMaxSvgPathDataLength + 1, 'L1 1').join(' ')}",
            'fillRule': 'nonZero',
            'strokeWidth': 1,
          },
        ],
      },
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes[0].svgPathData',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects oversized text payload', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          <String, Object?>{
            ..._minimalRectNodeJson(id: 't1'),
            'type': 'text',
            'text': List<String>.filled(kMaxTextLength + 1, 'a').join(),
            'size': <String, Object?>{'w': 1, 'h': 1},
            'fontSize': 14,
            'color': '#FF000000',
            'align': 'left',
            'isBold': false,
            'isItalic': false,
            'isUnderline': false,
          },
        ],
      },
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes[0].text',
        ),
      ),
    );
  });

  test('sceneBuildFromJsonMap rejects oversized palette penColors', () {
    final json = _minimalSceneJson();
    (json['palette'] as Map<String, Object?>)['penColors'] = <Object?>[
      for (var i = 0; i < kMaxPaletteItems + 1; i++) '#FF000000',
    ];

    expect(
      () => model_builder.sceneBuildFromJsonMap(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'palette.penColors',
        ),
      ),
    );
  });

  test('public snapshot boundary rejects oversized image ids', () {
    expect(
      () => ImageNodeSnapshot(
        id: 'img-boundary',
        imageId: 'x' * (kMaxImageIdLength + 1),
        size: const Size(1, 1),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('sceneValidateSnapshotValues skips duplicate node-id policy', () {
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
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(
              id: 'layer-auto-2',
              nodes: <NodeSnapshot>[
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
      returnsNormally,
    );
  });

  test('sceneValidateSnapshotValues skips duplicate content-layer policy', () {
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
          layers: <ContentLayerSnapshot>[
            ContentLayerSnapshot(id: 'layer-auto-dup-a'),
            ContentLayerSnapshot(id: 'layer-auto-dup-a'),
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
      returnsNormally,
    );
  });

  test('sceneBuildFromSnapshot rejects duplicate ids in background layer', () {
    final snapshot = SceneSnapshot(
      backgroundLayer: BackgroundLayerSnapshot(
        nodes: <NodeSnapshot>[
          RectNodeSnapshot(id: 'dup-bg', size: Size(1, 1)),
          RectNodeSnapshot(id: 'dup-bg', size: Size(2, 2)),
        ],
      ),
      layers: <ContentLayerSnapshot>[ContentLayerSnapshot(id: 'layer-auto-3')],
    );

    expect(
      () => model_builder.sceneBuildFromSnapshot(snapshot),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.duplicateNodeId &&
              e.path == 'backgroundLayer.nodes[1].id' &&
              e.message == 'Must be unique across scene layers.',
        ),
      ),
    );
  });

  test(
    'sceneValidateSnapshotValues skips background duplicate-node policy',
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
            backgroundLayer: BackgroundLayerSnapshot(
              nodes: <NodeSnapshot>[
                RectNodeSnapshot(id: 'dup-bg', size: Size(1, 1)),
                RectNodeSnapshot(id: 'dup-bg', size: Size(1, 1)),
              ],
            ),
            layers: <ContentLayerSnapshot>[
              ContentLayerSnapshot(id: 'layer-auto-4'),
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
        returnsNormally,
      );
    },
  );

  test('sceneValidateCore reports background duplicate node ids', () {
    expect(
      () => model_builder.sceneValidateCore(
        Scene(
          backgroundLayer: BackgroundLayer(
            nodes: <SceneNode>[
              RectNode(id: 'dup-bg', size: const Size(1, 1)),
              RectNode(id: 'dup-bg', size: const Size(1, 1)),
            ],
          ),
          layers: <ContentLayer>[ContentLayer(id: 'layer-auto-6')],
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.duplicateNodeId &&
              e.path == 'backgroundLayer.nodes[1].id' &&
              e.message == 'Must be unique across scene layers.',
        ),
      ),
    );
  });

  test('sceneValidateCore reports duplicate content layer ids', () {
    expect(
      () => model_builder.sceneValidateCore(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(id: 'layer-auto-dup-b'),
            ContentLayer(id: 'layer-auto-dup-b'),
          ],
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.duplicateLayerId &&
              e.path == 'layers[1].id' &&
              e.details['template'] == 'duplicateLayerId' &&
              e.message ==
                  'Field layers[1].id must be unique across content layers.',
        ),
      ),
    );
  });

  test('sceneValidatePositiveInt reports non-positive values', () {
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
      () => value_validation.sceneValidatePositiveInt(
        0,
        field: 'instanceRevision',
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
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.path == 'instanceRevision' &&
              e.message == 'Field instanceRevision must be > 0.',
        ),
      ),
    );
  });
}
