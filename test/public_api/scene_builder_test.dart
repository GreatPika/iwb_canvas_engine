import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart'
    show kMaxPaletteItems, kMaxStrokePointsPerNode;
import '../support/scene_builder_json_fixtures.dart';

Map<String, Object?> _textNodeJson({
  required String id,
  required String align,
}) {
  return <String, Object?>{
    'id': id,
    'type': 'text',
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
    'text': 'hello',
    'fontSize': 12,
    'color': '#FF000000',
    'align': align,
    'textDirection': 'ltr',
    'isBold': false,
    'isItalic': false,
    'isUnderline': false,
  };
}

SceneDataException _captureSceneDataException(Object? Function() callback) {
  try {
    callback();
    fail('Expected SceneDataException');
  } on SceneDataException catch (error) {
    return error;
  }
}

void _expectSameSceneDataContract(
  SceneDataException actual,
  SceneDataException expected,
) {
  expect(actual.code, expected.code);
  expect(actual.path, expected.path);
  expect(actual.details, expected.details);
}

SceneSnapshot _duplicateNodeSnapshotFromInternalBypass() {
  return materializeSceneSnapshot(
    sceneSnapshotBackingFromValidated(
      backgroundLayer: backgroundLayerSnapshotBackingFromValidated(
        nodes: <NodeSnapshotBacking>[
          nodeSnapshotBackingOf(
            RectNodeSnapshot(id: 'dup-bg', size: const Size(1, 1)),
          ),
          nodeSnapshotBackingOf(
            RectNodeSnapshot(id: 'dup-bg', size: const Size(2, 2)),
          ),
        ],
      ),
      layers: <ContentLayerSnapshotBacking>[
        contentLayerSnapshotBackingFromValidated(id: 'layer-auto-0'),
      ],
    ),
  );
}

void main() {
  test('SceneBuilder.buildFromSnapshot keeps typed background layer', () {
    final result = SceneBuilder.buildFromSnapshot(
      SceneSnapshot(
        backgroundLayer: BackgroundLayerSnapshot(
          nodes: <NodeSnapshot>[RectNodeSnapshot(id: 'bg', size: Size(1, 1))],
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-0',
            nodes: <NodeSnapshot>[RectNodeSnapshot(id: 'n1', size: Size(1, 1))],
          ),
        ],
      ),
    );

    expect(result.backgroundLayer.nodes.single.id, 'bg');
    expect(result.layers.single.nodes.single.id, 'n1');
  });

  test('SceneBuilder.buildFromJson builds typed snapshot', () {
    final result = SceneBuilder.buildFromJson(
      minimalSceneJson(
        backgroundNodes: <Object?>[minimalRectNodeJson(id: 'bg')],
      ),
    );

    expect(result.backgroundLayer.nodes.single.id, 'bg');
    expect(result.layers.single.nodes.single.id, 'n1');
  });

  test(
    'SceneBuilder.buildFromJson matches decodeScene for the same payload',
    () {
      final raw = minimalSceneJson(
        backgroundNodes: <Object?>[minimalRectNodeJson(id: 'bg')],
      );

      expect(
        encodeScene(SceneBuilder.buildFromJson(raw)),
        encodeScene(decodeScene(Map<String, dynamic>.from(raw))),
      );
    },
  );

  test(
    'SceneBuilder.buildFromJson surfaces the same path-aware diagnostics as decodeScene',
    () {
      final raw = minimalSceneJson(
        backgroundNodes: <Object?>[minimalRectNodeJson(id: 'bg')],
      );
      raw['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-0',
          'nodes': <Object?>[_textNodeJson(id: 't1', align: 'diagonal')],
        },
      ];

      final fromBuilder = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(raw),
      );
      final fromCodec = _captureSceneDataException(
        () => decodeScene(Map<String, dynamic>.from(raw)),
      );

      _expectSameSceneDataContract(fromBuilder, fromCodec);
      expect(fromBuilder.path, 'layers[0].nodes[0].align');
    },
  );

  test(
    'SceneBuilder.buildFromJson keeps common validated-field diagnostics aligned with decodeScene',
    () {
      final raw = minimalSceneJson(
        backgroundNodes: <Object?>[minimalRectNodeJson(id: 'bg')],
      );
      final node =
          ((((raw['layers'] as List<Object?>).single
                          as Map<String, Object?>)['nodes']
                      as List<Object?>)
                  .single
              as Map<String, Object?>);
      node['opacity'] = 2;

      final fromBuilder = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(raw),
      );
      final fromCodec = _captureSceneDataException(
        () => decodeScene(Map<String, dynamic>.from(raw)),
      );

      _expectSameSceneDataContract(fromBuilder, fromCodec);
      expect(fromBuilder.path, 'layers[0].nodes[0].opacity');
    },
  );

  test(
    'SceneBuilder palette limit diagnostics stay aligned across json and snapshot entrypoints',
    () {
      for (final scenario
          in <
            ({String field, List<Object?> jsonValues, SceneSnapshot snapshot})
          >[
            (
              field: 'penColors',
              jsonValues: <Object?>[
                for (var i = 0; i < kMaxPaletteItems + 1; i++) '#FF000000',
              ],
              snapshot: materializeSceneSnapshot(
                SceneSnapshotBacking(
                  palette: ScenePaletteSnapshotBacking(
                    penColors: <Color>[
                      for (var i = 0; i < kMaxPaletteItems + 1; i++)
                        const Color(0xFF000000),
                    ],
                  ),
                  layers: <ContentLayerSnapshotBacking>[
                    contentLayerSnapshotBackingFromValidated(
                      id: 'layer-auto-0',
                    ),
                  ],
                ),
              ),
            ),
            (
              field: 'backgroundColors',
              jsonValues: <Object?>[
                for (var i = 0; i < kMaxPaletteItems + 1; i++) '#FFFFFFFF',
              ],
              snapshot: materializeSceneSnapshot(
                SceneSnapshotBacking(
                  palette: ScenePaletteSnapshotBacking(
                    backgroundColors: <Color>[
                      for (var i = 0; i < kMaxPaletteItems + 1; i++)
                        const Color(0xFFFFFFFF),
                    ],
                  ),
                  layers: <ContentLayerSnapshotBacking>[
                    contentLayerSnapshotBackingFromValidated(
                      id: 'layer-auto-0',
                    ),
                  ],
                ),
              ),
            ),
            (
              field: 'gridSizes',
              jsonValues: <Object?>[
                for (var i = 0; i < kMaxPaletteItems + 1; i++) i + 1,
              ],
              snapshot: materializeSceneSnapshot(
                SceneSnapshotBacking(
                  palette: ScenePaletteSnapshotBacking(
                    gridSizes: <double>[
                      for (var i = 0; i < kMaxPaletteItems + 1; i++) i + 1,
                    ],
                  ),
                  layers: <ContentLayerSnapshotBacking>[
                    contentLayerSnapshotBackingFromValidated(
                      id: 'layer-auto-0',
                    ),
                  ],
                ),
              ),
            ),
          ]) {
        final raw = minimalSceneJson();
        (raw['palette'] as Map<String, Object?>)[scenario.field] =
            scenario.jsonValues;

        final fromJson = _captureSceneDataException(
          () => SceneBuilder.buildFromJson(raw),
        );
        final fromSnapshot = _captureSceneDataException(
          () => SceneBuilder.buildFromSnapshot(scenario.snapshot),
        );

        final expectedPath = 'palette.${scenario.field}';
        expect(fromJson.code, SceneDataErrorCode.invalidValue);
        expect(fromJson.path, expectedPath);
        expect(fromJson.details, const <String, Object?>{
          'template': 'maxItems',
          'maxItems': kMaxPaletteItems,
        });
        expect(
          fromJson.message,
          'Field $expectedPath must contain at most $kMaxPaletteItems items.',
        );
        expect(fromSnapshot.code, fromJson.code);
        expect(fromSnapshot.path, fromJson.path);
        expect(fromSnapshot.details, fromJson.details);
        expect(fromSnapshot.message, fromJson.message);
      }
    },
  );

  test(
    'SceneBuilder stroke and optional naturalSize diagnostics keep child-aware boundary contracts',
    () {
      final strokeJson = minimalSceneJson(
        contentNodes: <Object?>[
          <String, Object?>{
            ...minimalRectNodeJson(id: 'stroke-1'),
            'type': 'stroke',
            'localPoints': <Object?>[
              for (var i = 0; i < kMaxStrokePointsPerNode + 1; i++)
                <String, Object?>{'x': i.toDouble(), 'y': 0.0},
            ],
            'thickness': 1,
            'color': '#FF000000',
          },
        ],
      );
      final strokeError = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(strokeJson),
      );
      expect(strokeError.path, 'layers[0].nodes[0].localPoints');
      expect(strokeError.details, const <String, Object?>{
        'template': 'maxPoints',
        'maxPoints': kMaxStrokePointsPerNode,
      });
      expect(
        strokeError.message,
        'Field layers[0].nodes[0].localPoints must contain at most '
        '$kMaxStrokePointsPerNode points.',
      );

      final imageJson = minimalSceneJson(
        contentNodes: <Object?>[
          <String, Object?>{
            ...minimalRectNodeJson(id: 'img-1')
              ..remove('strokeWidth')
              ..remove('size'),
            'type': 'image',
            'imageId': 'asset:image-1',
            'size': <String, Object?>{'w': 10, 'h': 20},
            'naturalSize': <String, Object?>{'h': 20},
          },
        ],
      );
      final naturalSizeError = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(imageJson),
      );
      expect(naturalSizeError.code, SceneDataErrorCode.missingField);
      expect(naturalSizeError.path, 'layers[0].nodes[0].naturalSize.w');
      expect(naturalSizeError.details, const <String, Object?>{
        'template': 'missingField',
      });
      expect(
        naturalSizeError.message,
        'Missing required field layers[0].nodes[0].naturalSize.w.',
      );
    },
  );

  test(
    'SceneBuilder.buildFromSnapshot reports path-aware duplicate-id failures',
    () {
      // INV:INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY
      final snapshot = _duplicateNodeSnapshotFromInternalBypass();

      expect(
        () => SceneBuilder.buildFromSnapshot(snapshot),
        throwsA(
          predicate(
            (error) =>
                error is SceneDataException &&
                error.code == SceneDataErrorCode.duplicateNodeId &&
                error.path == 'backgroundLayer.nodes[1].id' &&
                error.details['template'] == 'duplicateNodeId',
          ),
        ),
      );
    },
  );

  test(
    'SceneBuilder.buildFromJson preserves duplicate-id diagnostics of decodeScene',
    () {
      // INV:INV-ENG-SHARED-SCENE-METADATA-CONTRACT
      final raw = minimalSceneJson(
        backgroundNodes: <Object?>[minimalRectNodeJson(id: 'bg')],
      );
      raw['backgroundLayer'] = <String, Object?>{
        'nodes': <Object?>[
          minimalRectNodeJson(id: 'dup-bg'),
          minimalRectNodeJson(id: 'dup-bg'),
        ],
      };

      final fromBuilder = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(raw),
      );
      final fromCodec = _captureSceneDataException(
        () => decodeScene(Map<String, dynamic>.from(raw)),
      );

      _expectSameSceneDataContract(fromBuilder, fromCodec);
      expect(fromBuilder.code, SceneDataErrorCode.duplicateNodeId);
      expect(fromBuilder.path, 'backgroundLayer.nodes[1].id');
      expect(fromBuilder.details, const <String, Object?>{
        'template': 'duplicateNodeId',
      });
    },
  );
}
