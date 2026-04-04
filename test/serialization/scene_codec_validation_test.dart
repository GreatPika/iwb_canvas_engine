import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart'
    show
        kMaxContentLayersPerScene,
        kMaxFontFamilyLength,
        kMaxLayerIdLength,
        kMaxNodesPerScene,
        kMaxPaletteItems,
        kMaxRawSceneJsonLength,
        kMaxStrokePointsPerNode,
        kMaxSvgPathDataLength,
        kMaxTextLength;
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/text_layout.dart'
    show TextLayoutRequest;
import 'package:iwb_canvas_engine/src/serialization/scene_codec.dart'
    show debugGuardDecodeForTest, debugGuardEncodeForTest, encodeSceneDocument;

Map<String, Object?> _minimalSceneJson() {
  return <String, Object?>{
    'schemaVersion': schemaVersionWrite,
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
    'layers': <Object?>[],
  };
}

Map<String, Object?> _sceneWithSingleNode(Map<String, Object?> nodeJson) {
  final json = _minimalSceneJson();
  json['layers'] = <Object?>[
    <String, Object?>{
      'id': 'layer-0',
      'nodes': <Object?>[nodeJson],
    },
  ];
  return json;
}

Map<String, Object?> _baseNodeJson({required String id, required String type}) {
  return <String, Object?>{
    'id': id,
    'type': type,
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
    if (type == 'text') 'textDirection': 'ltr',
  };
}

String _expectedSchemaVersionsMessage() {
  final versions = schemaVersionsRead.toList()..sort((a, b) => a.compareTo(b));
  return versions.join(', ');
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
            RectNodeSnapshot(id: 'dup', size: const Size(1, 1)),
          ),
        ],
      ),
      layers: <ContentLayerSnapshotBacking>[
        contentLayerSnapshotBackingFromValidated(
          id: 'layer-auto-dup-snapshot',
          nodes: <NodeSnapshotBacking>[
            nodeSnapshotBackingOf(
              RectNodeSnapshot(id: 'dup', size: const Size(2, 2)),
            ),
          ],
        ),
      ],
    ),
  );
}

void main() {
  // INV:INV-SER-JSON-NUMERIC-VALIDATION
  test('encodeSceneToJson -> decodeSceneFromJson is stable', () {
    final scene = SceneSnapshot(
      layers: [
        ContentLayerSnapshot(id: 'layer-auto-0'),
        ContentLayerSnapshot(id: 'layer-auto-1'),
      ],
    );
    final json = encodeSceneToJson(scene);
    final decoded = decodeSceneFromJson(json);
    expect(encodeScene(decoded), encodeScene(scene));
  });

  test('decodeScene accepts Map<String, Object?> from jsonDecode', () {
    final encoded = encodeScene(
      SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(id: 'layer-auto-2'),
        ],
      ),
    );
    final decodedRaw = jsonDecode(jsonEncode(encoded)) as Map<String, Object?>;
    final snapshot = decodeScene(decodedRaw);

    expect(snapshot.layers.length, 1);
  });

  test('SceneBuilder.buildFromJson accepts Map<String, Object?>', () {
    final decodedRaw =
        jsonDecode(jsonEncode(_minimalSceneJson())) as Map<String, Object?>;
    final snapshot = SceneBuilder.buildFromJson(decodedRaw);

    expect(snapshot.layers, isEmpty);
    expect(snapshot.backgroundLayer.nodes, isEmpty);
  });

  test(
    'SceneBuilder.buildFromJson and decodeScene match invalidJsonPayload on malformed parsed maps',
    () {
      final malformed = <Object?, Object?>{
        'schemaVersion': schemaVersionWrite,
        1: 'non-string-key',
      };

      final fromBuilder = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(malformed.cast<String, Object?>()),
      );
      final fromCodec = _captureSceneDataException(
        () => decodeScene(malformed.cast<String, Object?>()),
      );

      _expectSameSceneDataContract(fromBuilder, fromCodec);
      expect(fromBuilder.code, SceneDataErrorCode.invalidJson);
      expect(fromBuilder.details, const <String, Object?>{
        'template': 'invalidJsonPayload',
      });
    },
  );

  test(
    'SceneBuilder.buildFromJson matches decodeScene for the same payload',
    () {
      final raw = _minimalSceneJson();
      raw['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-0',
          'nodes': <Object?>[
            _baseNodeJson(id: 'n1', type: 'rect')..addAll(<String, Object?>{
              'size': <String, Object?>{'w': 1, 'h': 1},
              'strokeWidth': 0,
            }),
          ],
        },
      ];

      expect(
        encodeScene(SceneBuilder.buildFromJson(raw)),
        encodeScene(decodeScene(Map<String, Object?>.from(raw))),
      );
    },
  );

  test('SceneDataException implements FormatException shape', () {
    final error = SceneDataException(
      code: SceneDataErrorCode.duplicateLayerId,
      path: 'layers[0].id',
      details: const <String, Object?>{'template': 'duplicateLayerId'},
      source: 'source',
    );
    expect(
      error.message,
      'Field layers[0].id must be unique across content layers.',
    );
    expect(error.details, const <String, Object?>{
      'template': 'duplicateLayerId',
    });
    expect(error.source, 'source');
    expect(error.offset, isNull);
    expect(error.toString(), contains('SceneDataException'));
  });

  test('decodeSceneFromJson rejects non-object root', () {
    expect(
      () => decodeSceneFromJson('[]'),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidJson &&
              e.path == null &&
              e.message == 'Root JSON must be an object.',
        ),
      ),
    );
  });

  test('decodeSceneFromJson wraps JSON parse failures', () {
    expect(
      () => decodeSceneFromJson('{'),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidJson &&
              e.path == null,
        ),
      ),
    );
  });

  test('debugGuardDecodeForTest rethrows nested SceneDataException', () {
    final nested = SceneDataException.missingField(path: 'layers');

    expect(
      () => debugGuardDecodeForTest('{}', (_) => throw nested),
      throwsA(same(nested)),
    );
  });

  test(
    'debugGuardDecodeForTest maps callback failures to invalidJsonPayload',
    () {
      expect(
        () => debugGuardDecodeForTest('{}', (_) => throw StateError('boom')),
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

  test('decodeSceneFromJson rejects oversized raw JSON before parsing', () {
    final oversizedJson = '${' ' * kMaxRawSceneJsonLength}[';

    expect(
      () => decodeSceneFromJson(oversizedJson),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidJson &&
              e.path == null &&
              e.details['template'] == 'jsonPayloadTooLarge' &&
              e.details['maxLength'] == kMaxRawSceneJsonLength,
        ),
      ),
    );
  });

  test('debugGuardEncodeForTest rethrows nested SceneDataException', () {
    final nested = SceneDataException.invalidJsonPayload();

    expect(
      () => debugGuardEncodeForTest<Never>(() => throw nested),
      throwsA(same(nested)),
    );
  });

  test(
    'debugGuardEncodeForTest maps format failures to invalidJsonPayload',
    () {
      expect(
        () => debugGuardEncodeForTest<Never>(
          () => throw const FormatException('bad'),
        ),
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
    'debugGuardEncodeForTest maps generic failures to invalidJsonPayload',
    () {
      expect(
        () => debugGuardEncodeForTest<Never>(() => throw StateError('bad')),
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
    'SceneBuilder.buildFromJson and decodeScene report matching nested validation diagnostics',
    () {
      final invalidAlignJson = _baseNodeJson(id: 't2', type: 'text')
        ..addAll(<String, Object?>{
          'text': 'Hello',
          'fontSize': 12,
          'color': '#FF000000',
          'align': 'diagonal',
          'isBold': false,
          'isItalic': false,
          'isUnderline': false,
        });
      final raw = _sceneWithSingleNode(invalidAlignJson);

      final fromBuilder = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(raw),
      );
      final fromCodec = _captureSceneDataException(
        () => decodeScene(Map<String, Object?>.from(raw)),
      );

      _expectSameSceneDataContract(fromBuilder, fromCodec);
      expect(fromBuilder.path, 'layers[0].nodes[0].align');
    },
  );

  test(
    'SceneBuilder.buildFromJson and decodeScene keep matching common node-type diagnostics',
    () {
      final raw = _sceneWithSingleNode(
        _baseNodeJson(id: 'p1', type: 'path')
          ..addAll(<String, Object?>{
            'svgPathData': 'M0 0 H10 V10 H0 Z',
            'strokeWidth': 1,
            'fillRule': 'nonZero',
          })
          ..['type'] = 123,
      );

      final fromBuilder = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(raw),
      );
      final fromCodec = _captureSceneDataException(
        () => decodeScene(Map<String, Object?>.from(raw)),
      );

      _expectSameSceneDataContract(fromBuilder, fromCodec);
      expect(fromBuilder.path, 'layers[0].nodes[0].type');
    },
  );

  test(
    'SceneBuilder.buildFromJson and decodeScene keep matching optional field diagnostics',
    () {
      final raw = _sceneWithSingleNode(
        _baseNodeJson(id: 't1', type: 'text')..addAll(<String, Object?>{
          'text': 'Hello',
          'fontSize': 12,
          'color': '#FF000000',
          'align': 'left',
          'isBold': false,
          'isItalic': false,
          'isUnderline': false,
          'fontFamily': 123,
        }),
      );

      final fromBuilder = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(raw),
      );
      final fromCodec = _captureSceneDataException(
        () => decodeScene(Map<String, Object?>.from(raw)),
      );

      _expectSameSceneDataContract(fromBuilder, fromCodec);
      expect(fromBuilder.path, 'layers[0].nodes[0].fontFamily');
    },
  );

  test(
    'SceneBuilder.buildFromJson and decodeScene keep matching policy-owned scene overflow diagnostics',
    () {
      final json = _minimalSceneJson();
      json['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-0',
          'nodes': <Object?>[
            for (var i = 0; i < kMaxNodesPerScene + 1; i++)
              _baseNodeJson(id: 'n$i', type: 'rect')..addAll(<String, Object?>{
                'size': <String, Object?>{'w': 1, 'h': 1},
                'strokeWidth': 0,
              }),
          ],
        },
      ];

      final fromBuilder = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(json),
      );
      final fromCodec = _captureSceneDataException(
        () => decodeScene(Map<String, Object?>.from(json)),
      );

      _expectSameSceneDataContract(fromBuilder, fromCodec);
      expect(fromBuilder.code, SceneDataErrorCode.invalidValue);
      expect(fromBuilder.path, 'layers[0].nodes');
    },
  );

  test(
    'SceneBuilder.buildFromJson and decodeScene keep layer overflow ahead of extra layer shape errors',
    () {
      final json = _minimalSceneJson();
      json['layers'] = <Object?>[
        for (var i = 0; i < kMaxContentLayersPerScene; i++)
          <String, Object?>{'id': 'layer-$i', 'nodes': <Object?>[]},
        null,
      ];

      final fromBuilder = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(json),
      );
      final fromCodec = _captureSceneDataException(
        () => decodeScene(Map<String, Object?>.from(json)),
      );

      _expectSameSceneDataContract(fromBuilder, fromCodec);
      expect(fromBuilder.code, SceneDataErrorCode.invalidValue);
      expect(fromBuilder.path, 'layers');
    },
  );

  test(
    'SceneBuilder.buildFromJson and decodeScene keep node overflow ahead of extra node shape errors',
    () {
      final json = _minimalSceneJson();
      json['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-0',
          'nodes': <Object?>[
            for (var i = 0; i < kMaxNodesPerScene; i++)
              _baseNodeJson(id: 'n$i', type: 'rect')..addAll(<String, Object?>{
                'size': <String, Object?>{'w': 1, 'h': 1},
                'strokeWidth': 0,
              }),
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

      final fromBuilder = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(json),
      );
      final fromCodec = _captureSceneDataException(
        () => decodeScene(Map<String, Object?>.from(json)),
      );

      _expectSameSceneDataContract(fromBuilder, fromCodec);
      expect(fromBuilder.code, SceneDataErrorCode.invalidValue);
      expect(fromBuilder.path, 'layers[0].nodes');
    },
  );

  test(
    'decodeSceneFromJson, decodeScene, and SceneBuilder.buildFromJson share nested contract triples',
    () {
      final raw = _sceneWithSingleNode(
        _baseNodeJson(id: 't3', type: 'text')..addAll(<String, Object?>{
          'text': 'Hello',
          'fontSize': 12,
          'color': '#FF000000',
          'align': 'diagonal',
          'isBold': false,
          'isItalic': false,
          'isUnderline': false,
        }),
      );
      final rawJson = jsonEncode(raw);

      final fromString = _captureSceneDataException(
        () => decodeSceneFromJson(rawJson),
      );
      final fromMap = _captureSceneDataException(
        () => decodeScene(Map<String, dynamic>.from(raw)),
      );
      final fromBuilder = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(raw),
      );

      _expectSameSceneDataContract(fromString, fromMap);
      _expectSameSceneDataContract(fromBuilder, fromMap);
      expect(fromMap.path, 'layers[0].nodes[0].align');
    },
  );

  test('decodeScene canonicalizes missing background layer', () {
    // INV:INV-SER-TYPED-LAYER-SPLIT
    // INV:INV-SER-CANONICAL-BACKGROUND-LAYER
    final scene = decodeScene(_minimalSceneJson());
    expect(scene.layers, isEmpty);
    expect(scene.backgroundLayer.nodes, isEmpty);
  });

  test(
    'decodeScene reads typed backgroundLayer and preserves content order',
    () {
      // INV:INV-SER-TYPED-LAYER-SPLIT
      final bgNode = _baseNodeJson(id: 'bg', type: 'rect')
        ..addAll(<String, Object?>{
          'size': <String, Object?>{'w': 1, 'h': 1},
          'strokeWidth': 0,
        });
      final n1 = _baseNodeJson(id: 'n1', type: 'rect')
        ..addAll(<String, Object?>{
          'size': <String, Object?>{'w': 1, 'h': 1},
          'strokeWidth': 0,
        });
      final n2 = _baseNodeJson(id: 'n2', type: 'rect')
        ..addAll(<String, Object?>{
          'size': <String, Object?>{'w': 1, 'h': 1},
          'strokeWidth': 0,
        });
      final json = _minimalSceneJson();
      json['backgroundLayer'] = <String, Object?>{
        'nodes': <Object?>[bgNode],
      };
      json['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-auto-json-1',
          'nodes': <Object?>[n1],
        },
        <String, Object?>{
          'id': 'layer-auto-json-2',
          'nodes': <Object?>[n2],
        },
      ];

      final scene = decodeScene(json);

      expect(scene.backgroundLayer.nodes.single.id, 'bg');
      expect(scene.layers, hasLength(2));
      expect(scene.layers[0].nodes.single.id, 'n1');
      expect(scene.layers[1].nodes.single.id, 'n2');
    },
  );

  test('encodeSceneDocument canonicalizes null runtime background layer', () {
    // INV:INV-SER-TYPED-LAYER-SPLIT
    // INV:INV-SER-CANONICAL-BACKGROUND-LAYER
    final encoded = encodeSceneDocument(
      Scene(
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-encode-0',
            nodes: <SceneNode>[
              RectNode(id: 'n1', size: const Size(1, 1), strokeWidth: 0),
            ],
          ),
        ],
      ),
    );

    expect(encoded['backgroundLayer'], <String, Object?>{'nodes': <Object?>[]});
    expect((encoded['layers'] as List<Object?>).length, 1);
  });

  test(
    'encodeSceneDocument -> decodeScene keeps canonical background layer',
    () {
      final encoded = encodeSceneDocument(
        Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-auto-encode-0b',
              nodes: <SceneNode>[
                RectNode(id: 'n1', size: const Size(1, 1), strokeWidth: 0),
              ],
            ),
          ],
        ),
      );
      final decoded = decodeScene(encoded);

      expect(
        (encoded['backgroundLayer'] as Map<String, Object?>)['nodes'],
        <Object?>[],
      );
      expect(decoded.backgroundLayer.nodes, isEmpty);
      expect(decoded.layers.single.nodes.single.id, 'n1');
    },
  );

  test('decodeScene rejects non-object backgroundLayer', () {
    final json = _minimalSceneJson();
    json['backgroundLayer'] = 'invalid';

    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidFieldType &&
              e.path == 'backgroundLayer',
        ),
      ),
    );
  });

  test('decodeScene rejects non-object layer entries', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[123];
    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Layer must be an object.',
        ),
      ),
    );
  });

  test('decodeScene rejects non-object node entries', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-auto-json-3',
        'nodes': <Object?>[123],
      },
    ];
    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.path == 'layers[0].nodes[0]' &&
              e.message == 'Node must be an object.',
        ),
      ),
    );
  });

  test('decodeScene rejects too many content layers', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      for (var i = 0; i < kMaxContentLayersPerScene + 1; i++)
        <String, Object?>{'id': 'layer-$i', 'nodes': <Object?>[]},
    ];

    expect(
      () => decodeScene(json),
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

  test('decodeScene rejects too many nodes in scene', () {
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[
          for (var i = 0; i < kMaxNodesPerScene + 1; i++)
            _baseNodeJson(id: 'n$i', type: 'rect')..addAll(<String, Object?>{
              'size': <String, Object?>{'w': 1, 'h': 1},
              'strokeWidth': 0,
            }),
        ],
      },
    ];

    expect(
      () => decodeScene(json),
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
    'decodeScene rejects aggregated node overflow across background and content layers',
    () {
      final json = _minimalSceneJson();
      final contentNode = _baseNodeJson(id: 'fg', type: 'rect')
        ..addAll(<String, Object?>{
          'size': <String, Object?>{'w': 1, 'h': 1},
          'strokeWidth': 0,
        });
      json['backgroundLayer'] = <String, Object?>{
        'nodes': <Object?>[
          for (var i = 0; i < kMaxNodesPerScene; i++)
            _baseNodeJson(id: 'bg-$i', type: 'rect')..addAll(<String, Object?>{
              'size': <String, Object?>{'w': 1, 'h': 1},
              'strokeWidth': 0,
            }),
        ],
      };
      json['layers'] = <Object?>[
        <String, Object?>{
          'id': 'layer-0',
          'nodes': <Object?>[contentNode],
        },
      ];

      expect(
        () => decodeScene(json),
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

  test('decodeScene rejects too many stroke localPoints', () {
    final strokeJson = _baseNodeJson(id: 'stroke-overflow', type: 'stroke')
      ..addAll(<String, Object?>{
        'localPoints': <Object?>[
          for (var i = 0; i < kMaxStrokePointsPerNode + 1; i++)
            <String, Object?>{'x': i.toDouble(), 'y': 0.0},
        ],
        'thickness': 1,
        'color': '#FF000000',
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(strokeJson)),
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

  test('decodeScene rejects oversized svgPathData payload', () {
    final pathJson = _baseNodeJson(id: 'path-overflow', type: 'path')
      ..addAll(<String, Object?>{
        'svgPathData':
            "M0 0 ${List<String>.filled(kMaxSvgPathDataLength + 1, 'L1 1').join(' ')}",
        'strokeWidth': 1,
        'fillRule': 'nonZero',
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(pathJson)),
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

  test('decodeScene rejects oversized text payload', () {
    final textJson = _baseNodeJson(id: 'text-overflow', type: 'text')
      ..addAll(<String, Object?>{
        'text': List<String>.filled(kMaxTextLength + 1, 'a').join(),
        'fontSize': 14,
        'color': '#FF000000',
        'align': 'left',
        'isBold': false,
        'isItalic': false,
        'isUnderline': false,
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(textJson)),
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

  test('decodeScene rejects oversized derived text bounds', () {
    final textJson = _baseNodeJson(id: 'text-derived-overflow', type: 'text')
      ..addAll(<String, Object?>{
        'text': List<String>.filled(30000, 'W').join(),
        'fontSize': 1000,
        'color': '#FF000000',
        'align': 'left',
        'isBold': false,
        'isItalic': false,
        'isUnderline': false,
        'maxWidth': null,
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(textJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.outOfRange &&
              e.path == 'layers[0].nodes[0].derivedBounds.w',
        ),
      ),
    );
  });

  test('decodeScene rejects oversized palette penColors', () {
    // INV:INV-SER-SHARED-PALETTE-ITEM-LIMIT
    final json = _minimalSceneJson();
    (json['palette'] as Map<String, Object?>)['penColors'] = <Object?>[
      for (var i = 0; i < kMaxPaletteItems + 1; i++) '#FF000000',
    ];

    expect(
      () => decodeScene(json),
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

  test('decodeScene rejects duplicate node ids across layers', () {
    // INV:INV-G-NODEID-UNIQUE
    final json = _minimalSceneJson();
    json['layers'] = <Object?>[
      <String, Object?>{
        'id': 'layer-auto-json-4',
        'nodes': <Object?>[
          _baseNodeJson(id: 'dup-node', type: 'rect')..addAll(<String, Object?>{
            'size': <String, Object?>{'w': 10, 'h': 10},
            'strokeWidth': 0,
          }),
        ],
      },
      <String, Object?>{
        'id': 'layer-auto-json-5',
        'nodes': <Object?>[
          _baseNodeJson(id: 'dup-node', type: 'rect')..addAll(<String, Object?>{
            'size': <String, Object?>{'w': 20, 'h': 20},
            'strokeWidth': 0,
          }),
        ],
      },
    ];
    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Must be unique across scene layers.',
        ),
      ),
    );
  });

  test('decodeScene rejects unknown node types', () {
    final json = _sceneWithSingleNode(_baseNodeJson(id: 'n1', type: 'mystery'));
    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Unknown node type: mystery.',
        ),
      ),
    );
  });

  test('encodeScene round-trips the full supported TextAlign set', () {
    SceneSnapshot sceneFor(TextAlign align, String id) {
      return SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-3',
            nodes: <NodeSnapshot>[
              TextNodeSnapshot(
                id: id,
                text: 'Hello',
                fontSize: 12,
                color: const Color(0xFF000000),
                align: align,
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ],
      );
    }

    for (final entry in <(TextAlign, String)>[
      (TextAlign.left, 'left'),
      (TextAlign.center, 'center'),
      (TextAlign.right, 'right'),
      (TextAlign.justify, 'justify'),
      (TextAlign.start, 'start'),
      (TextAlign.end, 'end'),
    ]) {
      final encoded = encodeScene(sceneFor(entry.$1, 'text-${entry.$2}'));
      final nodeJson =
          ((encoded['layers'] as List<Object?>).single
                  as Map<String, Object?>)['nodes']
              as List<Object?>;
      expect((nodeJson.single as Map<String, Object?>)['align'], entry.$2);

      final decoded = decodeScene(encoded);
      final node = decoded.layers.single.nodes.single as TextNodeSnapshot;
      expect(node.align, entry.$1);
    }
  });

  test('decodeScene rejects unknown fillRule', () {
    final nodeJson = _baseNodeJson(id: 'p1', type: 'path')
      ..addAll(<String, Object?>{
        'svgPathData': 'M0 0 H10 V10 H0 Z',
        'strokeWidth': 1,
        'fillRule': 'weird',
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nodeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Unknown fillRule: weird.',
        ),
      ),
    );
  });

  test('decodeScene rejects empty svgPathData', () {
    final nodeJson = _baseNodeJson(id: 'p1', type: 'path')
      ..addAll(<String, Object?>{
        'svgPathData': '   ',
        'strokeWidth': 1,
        'fillRule': 'nonZero',
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nodeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message ==
                  'Field layers[0].nodes[0].svgPathData must not be empty.',
        ),
      ),
    );
  });

  test('decodeScene rejects invalid svgPathData', () {
    final nodeJson = _baseNodeJson(id: 'p1', type: 'path')
      ..addAll(<String, Object?>{
        'svgPathData': 'not-a-path',
        'strokeWidth': 1,
        'fillRule': 'nonZero',
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nodeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message ==
                  'Field layers[0].nodes[0].svgPathData must be valid SVG path data.',
        ),
      ),
    );
  });

  test('decodeScene rejects invalid colors in 6- and 8-digit forms', () {
    final six = _minimalSceneJson();
    (six['background'] as Map<String, Object?>)['color'] = '#GGGGGG';
    expect(() => decodeScene(six), throwsA(isA<SceneDataException>()));

    final eight = _minimalSceneJson();
    (eight['background'] as Map<String, Object?>)['color'] = '#GGGGGGGG';
    expect(() => decodeScene(eight), throwsA(isA<SceneDataException>()));
  });

  test('decodeScene accepts 6-digit colors', () {
    final json = _minimalSceneJson();
    (json['background'] as Map<String, Object?>)['color'] = '#112233';

    final scene = decodeScene(json);
    expect(scene.background.color, const Color(0xFF112233));
  });

  test('decodeScene rejects non-object naturalSize for image nodes', () {
    final nodeJson = _baseNodeJson(id: 'img-1', type: 'image')
      ..addAll(<String, Object?>{
        'imageId': 'image-1',
        'size': <String, Object?>{'w': 10, 'h': 20},
        'naturalSize': 'oops',
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nodeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field naturalSize must be an object.',
        ),
      ),
    );
  });

  test('decodeScene parses the full supported text align set', () {
    for (final entry in <(String, TextAlign)>[
      ('left', TextAlign.left),
      ('center', TextAlign.center),
      ('right', TextAlign.right),
      ('justify', TextAlign.justify),
      ('start', TextAlign.start),
      ('end', TextAlign.end),
    ]) {
      final nodeJson = _baseNodeJson(id: 't-${entry.$1}', type: 'text')
        ..addAll(<String, Object?>{
          'text': 'Hello',
          'fontSize': 12,
          'color': '#FF000000',
          'align': entry.$1,
          'isBold': false,
          'isItalic': false,
          'isUnderline': false,
        });

      final scene = decodeScene(_sceneWithSingleNode(nodeJson));
      final node = scene.layers.first.nodes.single as TextNodeSnapshot;
      expect(node.align, entry.$2);
    }
  });

  test('decodeScene rejects unknown aligns with path-aware diagnostics', () {
    final invalidAlignJson = _baseNodeJson(id: 't2', type: 'text')
      ..addAll(<String, Object?>{
        'text': 'Hello',
        'fontSize': 12,
        'color': '#FF000000',
        'align': 'diagonal',
        'isBold': false,
        'isItalic': false,
        'isUnderline': false,
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(invalidAlignJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.path == 'layers[0].nodes[0].align' &&
              e.message == 'Unknown text align: diagonal.',
        ),
      ),
    );
  });

  test('decodeScene rejects legacy text size on import', () {
    // INV:INV-SER-TEXT-DIRECTION-EXPLICIT
    final nodeJson = _baseNodeJson(id: 't-derived', type: 'text')
      ..addAll(<String, Object?>{
        'text': 'Derived text size',
        'size': <String, Object?>{'w': 1, 'h': 1},
        'fontSize': 24,
        'color': '#FF000000',
        'align': 'left',
        'textDirection': 'rtl',
        'isBold': false,
        'isItalic': false,
        'isUnderline': false,
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nodeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.path == 'layers[0].nodes[0].size',
        ),
      ),
    );
  });

  test('decodeScene rejects unknown textDirection', () {
    final invalidDirectionJson = _baseNodeJson(id: 't-direction', type: 'text')
      ..addAll(<String, Object?>{
        'text': 'Hello',
        'fontSize': 12,
        'color': '#FF000000',
        'align': 'left',
        'textDirection': 'sideways',
        'isBold': false,
        'isItalic': false,
        'isUnderline': false,
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(invalidDirectionJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.path == 'layers[0].nodes[0].textDirection' &&
              e.message == 'Unknown text direction: sideways.',
        ),
      ),
    );
  });

  test('decodeScene rejects missing textDirection', () {
    final missingDirectionJson =
        _baseNodeJson(id: 't-missing-direction', type: 'text')
          ..addAll(<String, Object?>{
            'text': 'Hello',
            'fontSize': 12,
            'color': '#FF000000',
            'align': 'left',
            'isBold': false,
            'isItalic': false,
            'isUnderline': false,
          });
    missingDirectionJson.remove('textDirection');

    expect(
      () => decodeScene(_sceneWithSingleNode(missingDirectionJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.missingField &&
              e.path == 'layers[0].nodes[0].textDirection' &&
              e.message ==
                  'Missing required field layers[0].nodes[0].textDirection.',
        ),
      ),
    );
  });

  test('encodeScene omits derived text size from JSON export', () {
    final snapshot = SceneSnapshot(
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-text-stale',
          nodes: <NodeSnapshot>[
            TextNodeSnapshot(
              id: 't-encode-derived',
              text: 'Derived text size',
              fontSize: 24,
              color: Color(0xFF000000),
              align: TextAlign.left,
              textDirection: TextDirection.ltr,
              isBold: false,
              isItalic: false,
              isUnderline: false,
            ),
          ],
        ),
      ],
    );

    final expectedSize = TextLayoutRequest(
      text: 'Derived text size',
      color: const Color(0xFF000000),
      fontSize: 24,
      isBold: false,
      isItalic: false,
      isUnderline: false,
      textAlign: TextAlign.left,
      fontFamily: null,
      lineHeight: null,
      maxWidth: null,
    ).measure();

    final encoded = encodeScene(snapshot);
    final layers = encoded['layers'] as List<Object?>;
    final layer = layers.single as Map<String, Object?>;
    final nodes = layer['nodes'] as List<Object?>;
    final encodedText = nodes.single as Map<String, Object?>;

    expect(encodedText.containsKey('size'), isFalse);
    expect(expectedSize.width, greaterThan(0));
    expect(expectedSize.height, greaterThan(0));
  });

  test('decodeScene validates point and optional field types', () {
    final strokeJson = _baseNodeJson(id: 's1', type: 'stroke')
      ..addAll(<String, Object?>{
        'localPoints': <Object?>[123],
        'thickness': 2,
        'color': '#FF000000',
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(strokeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.path == 'layers[0].nodes[0].localPoints[0]' &&
              e.message ==
                  'Field layers[0].nodes[0].localPoints[0] must be an object with x/y.',
        ),
      ),
    );

    final imageJson = _baseNodeJson(id: 'img1', type: 'image')
      ..addAll(<String, Object?>{
        'imageId': 'asset:sample',
        'size': <String, Object?>{'w': 10, 'h': 10},
        'naturalSize': <String, Object?>{'w': 'x', 'h': 10},
      });
    expect(
      () => decodeScene(_sceneWithSingleNode(imageJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Optional size must be numeric.',
        ),
      ),
    );

    final textJson = _baseNodeJson(id: 't1', type: 'text')
      ..addAll(<String, Object?>{
        'text': 'Hello',
        'fontSize': 12,
        'color': '#FF000000',
        'align': 'left',
        'isBold': false,
        'isItalic': false,
        'isUnderline': false,
        'fontFamily': 123,
      });
    expect(
      () => decodeScene(_sceneWithSingleNode(textJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.path == 'layers[0].nodes[0].fontFamily' &&
              e.message == 'Field fontFamily must be a string.',
        ),
      ),
    );

    final textJsonWidth = _baseNodeJson(id: 't2', type: 'text')
      ..addAll(<String, Object?>{
        'text': 'Hello',
        'fontSize': 12,
        'color': '#FF000000',
        'align': 'left',
        'isBold': false,
        'isItalic': false,
        'isUnderline': false,
        'maxWidth': 'x',
      });
    expect(
      () => decodeScene(_sceneWithSingleNode(textJsonWidth)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.path == 'layers[0].nodes[0].maxWidth' &&
              e.message == 'Field maxWidth must be a number.',
        ),
      ),
    );

    final pathJson = _baseNodeJson(id: 'p1', type: 'path')
      ..addAll(<String, Object?>{
        'svgPathData': 'M0 0 H10 V10 H0 Z',
        'strokeWidth': 1,
        'fillRule': 123,
      });
    expect(
      () => decodeScene(_sceneWithSingleNode(pathJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field fillRule must be a string.',
        ),
      ),
    );
  });

  test('decodeScene validates required string/list/number field types', () {
    final listWrong = _minimalSceneJson();
    (listWrong['palette'] as Map<String, Object?>)['penColors'] = 'not-a-list';
    expect(
      () => decodeScene(listWrong),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.path == 'palette.penColors' &&
              e.message == 'Field penColors must be a list.',
        ),
      ),
    );

    final stringWrong = _minimalSceneJson();
    (stringWrong['background'] as Map<String, Object?>)['color'] = 123;
    expect(
      () => decodeScene(stringWrong),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field color must be a string.',
        ),
      ),
    );

    final numberWrong = _minimalSceneJson();
    (numberWrong['camera'] as Map<String, Object?>)['offsetX'] = '0';
    expect(
      () => decodeScene(numberWrong),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field offsetX must be a number.',
        ),
      ),
    );
  });

  test('decodeScene validates optional and list item types', () {
    final rectJson = _baseNodeJson(id: 'r1', type: 'rect')
      ..addAll(<String, Object?>{
        'size': <String, Object?>{'w': 10, 'h': 10},
        'strokeWidth': 1,
        'fillColor': 123,
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(rectJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field fillColor must be a string.',
        ),
      ),
    );

    final paletteWrong = _minimalSceneJson();
    (paletteWrong['palette'] as Map<String, Object?>)['penColors'] = <Object?>[
      123,
    ];
    expect(() => decodeScene(paletteWrong), throwsA(isA<SceneDataException>()));

    final gridSizesWrong = _minimalSceneJson();
    (gridSizesWrong['palette'] as Map<String, Object?>)['gridSizes'] =
        <Object?>['10'];
    expect(
      () => decodeScene(gridSizesWrong),
      throwsA(isA<SceneDataException>()),
    );
  });

  test('decodeScene rejects empty palette lists', () {
    // INV:INV-SER-JSON-GRID-PALETTE-CONTRACTS
    final emptyPen = _minimalSceneJson();
    (emptyPen['palette'] as Map<String, Object?>)['penColors'] = <Object?>[];
    expect(
      () => decodeScene(emptyPen),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field palette.penColors must not be empty.',
        ),
      ),
    );

    final emptyBackground = _minimalSceneJson();
    (emptyBackground['palette'] as Map<String, Object?>)['backgroundColors'] =
        <Object?>[];
    expect(
      () => decodeScene(emptyBackground),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field palette.backgroundColors must not be empty.',
        ),
      ),
    );

    final emptyGridSizes = _minimalSceneJson();
    (emptyGridSizes['palette'] as Map<String, Object?>)['gridSizes'] =
        <Object?>[];
    expect(
      () => decodeScene(emptyGridSizes),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field palette.gridSizes must not be empty.',
        ),
      ),
    );
  });

  test('decodeScene validates required field types', () {
    final schemaWrong = _minimalSceneJson();
    schemaWrong['schemaVersion'] = '1';
    expect(
      () => decodeScene(schemaWrong),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field schemaVersion must be an int.',
        ),
      ),
    );

    final cameraWrong = _minimalSceneJson();
    cameraWrong['camera'] = <Object?>[];
    expect(
      () => decodeScene(cameraWrong),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field camera must be an object.',
        ),
      ),
    );

    final enabledWrong = _minimalSceneJson();
    ((enabledWrong['background'] as Map<String, Object?>)['grid']
            as Map<String, Object?>)['enabled'] =
        1;
    expect(
      () => decodeScene(enabledWrong),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field enabled must be a bool.',
        ),
      ),
    );
  });

  test(
    'decodeScene validates max lengths for layer and optional string fields',
    () {
      final overlongLayerId = _minimalSceneJson();
      overlongLayerId['layers'] = <Object?>[
        <String, Object?>{
          'id': 'l' * (kMaxLayerIdLength + 1),
          'nodes': <Object?>[],
        },
      ];
      expect(
        () => decodeScene(overlongLayerId),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.path == 'layers[0].id' &&
                e.message ==
                    'Field layers[0].id length must be <= $kMaxLayerIdLength characters.',
          ),
        ),
      );

      final textJson = _baseNodeJson(id: 't-overlong-font-family', type: 'text')
        ..addAll(<String, Object?>{
          'text': 'Hello',
          'fontSize': 12,
          'color': '#FF000000',
          'align': 'left',
          'isBold': false,
          'isItalic': false,
          'isUnderline': false,
          'fontFamily': 'f' * (kMaxFontFamilyLength + 1),
        });
      expect(
        () => decodeScene(_sceneWithSingleNode(textJson)),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.path == 'layers[0].nodes[0].fontFamily' &&
                e.message ==
                    'Field layers[0].nodes[0].fontFamily length must be <= $kMaxFontFamilyLength characters.',
          ),
        ),
      );
    },
  );

  test('decodeScene accepts integer-valued numeric schemaVersion', () {
    // INV:INV-SER-SCHEMA-VERSION-CONTRACT
    final json = _minimalSceneJson();
    json['schemaVersion'] = schemaVersionWrite.toDouble();

    final scene = decodeScene(json);
    expect(scene.layers, isEmpty);
    expect(scene.backgroundLayer, isNotNull);
  });

  test('schema write version is included in read versions', () {
    // INV:INV-SER-SCHEMA-VERSION-CONTRACT
    expect(schemaVersionsRead, contains(schemaVersionWrite));
  });

  test('decodeScene accepts every supported schema version', () {
    // INV:INV-SER-SCHEMA-VERSION-CONTRACT
    for (final version in schemaVersionsRead) {
      final json = _minimalSceneJson();
      json['schemaVersion'] = version;

      final scene = decodeScene(json);

      expect(scene.layers, isEmpty, reason: 'schemaVersion=$version');
      expect(
        scene.backgroundLayer.nodes,
        isEmpty,
        reason: 'schemaVersion=$version',
      );
    }
  });

  test('decodeScene rejects non-integer numeric schemaVersion', () {
    final json = _minimalSceneJson();
    json['schemaVersion'] = 2.5;
    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field schemaVersion must be an int.',
        ),
      ),
    );
  });

  test(
    'decodeScene reports unsupported version for integer-valued schemaVersion',
    () {
      // INV:INV-SER-SCHEMA-VERSION-CONTRACT
      // INV:INV-SER-UNSUPPORTED-SCHEMA-VERSION-CODE
      final json = _minimalSceneJson();
      json['schemaVersion'] = 1.0;
      expect(
        () => decodeScene(json),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.unsupportedSchemaVersion &&
                e.message ==
                    'Unsupported schemaVersion: 1. Expected one of: [${_expectedSchemaVersionsMessage()}].',
          ),
        ),
      );
    },
  );

  test(
    'decodeSceneFromJson, decodeScene, and SceneBuilder.buildFromJson keep matching unsupported schema contracts',
    () {
      final raw = _minimalSceneJson();
      raw['schemaVersion'] = 1.0;
      final rawJson = jsonEncode(raw);

      final fromString = _captureSceneDataException(
        () => decodeSceneFromJson(rawJson),
      );
      final fromMap = _captureSceneDataException(
        () => decodeScene(Map<String, dynamic>.from(raw)),
      );
      final fromBuilder = _captureSceneDataException(
        () => SceneBuilder.buildFromJson(raw),
      );

      _expectSameSceneDataContract(fromString, fromMap);
      _expectSameSceneDataContract(fromBuilder, fromMap);
      expect(fromMap.code, SceneDataErrorCode.unsupportedSchemaVersion);
      expect(fromMap.path, 'schemaVersion');
      expect(fromMap.details, isEmpty);
    },
  );

  test(
    'decode -> encode -> decode keeps canonical background layer for JSON missing backgroundLayer',
    () {
      // INV:INV-SER-CANONICAL-BACKGROUND-LAYER
      final input = _minimalSceneJson();
      input.remove('backgroundLayer');

      final decoded = decodeScene(input);
      final encoded = encodeScene(decoded);
      final redecoded = decodeScene(encoded);

      expect(
        (encoded['backgroundLayer'] as Map<String, Object?>)['nodes'],
        <Object?>[],
      );
      expect(redecoded.backgroundLayer.nodes, isEmpty);
      expect(redecoded.layers, isEmpty);
    },
  );

  test('decodeScene rejects NaN/Infinity numeric fields', () {
    final json = _minimalSceneJson();
    (json['camera'] as Map<String, Object?>)['offsetX'] = double.nan;
    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field offsetX must be finite.',
        ),
      ),
    );

    final json2 = _minimalSceneJson();
    (json2['camera'] as Map<String, Object?>)['offsetY'] = double.infinity;
    expect(
      () => decodeScene(json2),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field offsetY must be finite.',
        ),
      ),
    );
  });

  test('decodeScene rejects opacity outside [0,1]', () {
    final nodeJson = _baseNodeJson(id: 'n1', type: 'rect')
      ..addAll(<String, Object?>{
        'size': <String, Object?>{'w': 10, 'h': 10},
        'strokeWidth': 1,
      });
    nodeJson['opacity'] = 2;
    expect(
      () => decodeScene(_sceneWithSingleNode(nodeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message ==
                  'Field layers[0].nodes[0].opacity must be within [0,1].',
        ),
      ),
    );
  });

  test('encodeSceneDocument rejects mutable node opacity outside [0,1]', () {
    final scene = Scene(
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-14',
          nodes: <SceneNode>[_BadOpacityNode(id: 'bad-opacity')],
        ),
      ],
    );

    expect(
      () => encodeSceneDocument(scene),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message ==
                  'Field layers[0].nodes[0].opacity must be within [0,1].',
        ),
      ),
    );
  });

  test('encodeSceneDocument encodes full scene structure', () {
    final scene = Scene(
      camera: Camera(offset: const Offset(12, -7)),
      background: Background(
        color: const Color(0xFF010203),
        grid: GridSettings(
          isEnabled: true,
          cellSize: 16,
          color: const Color(0xFF040506),
        ),
      ),
      palette: ScenePalette(
        penColors: <Color>[const Color(0xFF111111)],
        backgroundColors: <Color>[const Color(0xFF222222)],
        gridSizes: <double>[8, 16],
      ),
      backgroundLayer: BackgroundLayer(
        nodes: <SceneNode>[RectNode(id: 'bg-rect', size: const Size(10, 5))],
      ),
      layers: <ContentLayer>[
        ContentLayer(
          id: 'layer-auto-15',
          nodes: <SceneNode>[RectNode(id: 'fg-rect', size: const Size(3, 2))],
        ),
        ContentLayer(
          id: 'layer-auto-16',
          nodes: <SceneNode>[RectNode(id: 'fg-rect-2', size: const Size(6, 4))],
        ),
      ],
    );

    final encoded = encodeSceneDocument(scene);
    expect(encoded['schemaVersion'], schemaVersionWrite);

    final camera = encoded['camera'] as Map<String, Object?>;
    expect(camera['offsetX'], 12);
    expect(camera['offsetY'], -7);

    final background = encoded['background'] as Map<String, Object?>;
    expect(background['color'], '#FF010203');
    final grid = background['grid'] as Map<String, Object?>;
    expect(grid['enabled'], isTrue);
    expect(grid['cellSize'], 16);
    expect(grid['color'], '#FF040506');

    final palette = encoded['palette'] as Map<String, Object?>;
    expect(palette['penColors'], <String>['#FF111111']);
    expect(palette['backgroundColors'], <String>['#FF222222']);
    expect(palette['gridSizes'], <double>[8, 16]);

    final backgroundLayer = encoded['backgroundLayer'] as Map<String, Object?>;
    final backgroundNodes = backgroundLayer['nodes'] as List<Object?>;
    expect(backgroundNodes, hasLength(1));
    expect((backgroundNodes.single as Map<String, Object?>)['id'], 'bg-rect');

    final layers = encoded['layers'] as List<Object?>;
    expect(layers, hasLength(2));
    expect(
      (layers[0] as Map<String, Object?>).containsKey('isBackground'),
      isFalse,
    );
    expect(
      (layers[1] as Map<String, Object?>).containsKey('isBackground'),
      isFalse,
    );
  });

  test(
    'encodeSceneDocument reads frozen runtime palette values instead of constructor aliases',
    () {
      final sourcePenColors = <Color>[const Color(0xFF111111)];
      final sourceBackgroundColors = <Color>[const Color(0xFF222222)];
      final sourceGridSizes = <double>[8, 16];
      final scene = Scene(
        palette: ScenePalette(
          penColors: sourcePenColors,
          backgroundColors: sourceBackgroundColors,
          gridSizes: sourceGridSizes,
        ),
      );

      sourcePenColors.add(const Color(0xFF333333));
      sourceBackgroundColors.add(const Color(0xFF444444));
      sourceGridSizes.add(32);

      final palette =
          encodeSceneDocument(scene)['palette'] as Map<String, Object?>;
      expect(palette['penColors'], <String>['#FF111111']);
      expect(palette['backgroundColors'], <String>['#FF222222']);
      expect(palette['gridSizes'], <double>[8, 16]);
    },
  );

  test(
    'encodeSceneDocument rejects duplicate node ids across background/content',
    () {
      final duplicateIds = Scene(
        backgroundLayer: BackgroundLayer(
          nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(1, 1))],
        ),
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-17',
            nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(2, 2))],
          ),
        ],
      );
      expect(
        () => encodeSceneDocument(duplicateIds),
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
    },
  );

  test('encodeScene preserves import-boundary duplicate-id diagnostics', () {
    final snapshot = _duplicateNodeSnapshotFromInternalBypass();

    expect(
      () => encodeScene(snapshot),
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
  });

  test(
    'encodeSceneDocument and encodeScene keep matching duplicate-id contracts',
    () {
      final runtimeScene = Scene(
        backgroundLayer: BackgroundLayer(
          nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(1, 1))],
        ),
        layers: <ContentLayer>[
          ContentLayer(
            id: 'layer-auto-dup-runtime',
            nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(2, 2))],
          ),
        ],
      );
      final snapshot = _duplicateNodeSnapshotFromInternalBypass();

      final fromDocument = _captureSceneDataException(
        () => encodeSceneDocument(runtimeScene),
      );
      final fromSnapshot = _captureSceneDataException(
        () => encodeScene(snapshot),
      );

      _expectSameSceneDataContract(fromDocument, fromSnapshot);
      expect(fromDocument.code, SceneDataErrorCode.duplicateNodeId);
      expect(fromDocument.path, 'layers[0].nodes[0].id');
      expect(fromDocument.details, const <String, Object?>{
        'template': 'duplicateNodeId',
      });
    },
  );

  test('decodeScene rejects non-positive thickness', () {
    final nodeJson = _baseNodeJson(id: 's1', type: 'stroke')
      ..addAll(<String, Object?>{
        'localPoints': <Object?>[
          <String, Object?>{'x': 0, 'y': 0},
        ],
        'thickness': 0,
        'color': '#FF000000',
      });
    expect(
      () => decodeScene(_sceneWithSingleNode(nodeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field layers[0].nodes[0].thickness must be > 0.',
        ),
      ),
    );
  });

  test('decodeScene rejects invalid width-like numeric fields', () {
    final strokeWithNonFiniteThickness = _baseNodeJson(id: 's2', type: 'stroke')
      ..addAll(<String, Object?>{
        'localPoints': <Object?>[
          <String, Object?>{'x': 0, 'y': 0},
        ],
        'thickness': double.nan,
        'color': '#FF000000',
      });
    expect(
      () => decodeScene(_sceneWithSingleNode(strokeWithNonFiniteThickness)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field thickness must be finite.',
        ),
      ),
    );

    final pathWithNegativeStrokeWidth = _baseNodeJson(id: 'p2', type: 'path')
      ..addAll(<String, Object?>{
        'svgPathData': 'M0 0 H10 V10 H0 Z',
        'strokeWidth': -1,
        'fillRule': 'nonZero',
      });
    expect(
      () => decodeScene(_sceneWithSingleNode(pathWithNegativeStrokeWidth)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field layers[0].nodes[0].strokeWidth must be >= 0.',
        ),
      ),
    );

    final rectWithNonFiniteHitPadding = _baseNodeJson(id: 'r1', type: 'rect')
      ..addAll(<String, Object?>{
        'size': <String, Object?>{'w': 10, 'h': 10},
        'strokeWidth': 1,
        'hitPadding': double.infinity,
      });
    expect(
      () => decodeScene(_sceneWithSingleNode(rectWithNonFiniteHitPadding)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field hitPadding must be finite.',
        ),
      ),
    );
  });

  test('decodeScene rejects non-positive grid cellSize', () {
    for (final enabled in <bool>[false, true]) {
      for (final value in <double>[0, -12.5]) {
        final json = _minimalSceneJson();
        final grid =
            (json['background'] as Map<String, Object?>)['grid']
                as Map<String, Object?>;
        grid['enabled'] = enabled;
        grid['cellSize'] = value;

        expect(
          () => decodeScene(json),
          throwsA(
            predicate(
              (e) =>
                  e is SceneDataException &&
                  e.message == 'Field background.grid.cellSize must be > 0.',
            ),
          ),
        );
      }
    }
  });

  test('decodeScene accepts positive grid cellSize for disabled grid', () {
    for (final value in <double>[0.125, 1, 12.5]) {
      final json = _minimalSceneJson();
      final grid =
          (json['background'] as Map<String, Object?>)['grid']
              as Map<String, Object?>;
      grid['enabled'] = false;
      grid['cellSize'] = value;

      final scene = decodeScene(json);
      expect(scene.background.grid.isEnabled, isFalse);
      expect(scene.background.grid.cellSize, value);
    }
  });

  test('decodeScene rejects enabled grid cellSize below the safety minimum', () {
    for (final value in <double>[0.125, 0.5]) {
      final json = _minimalSceneJson();
      final grid =
          (json['background'] as Map<String, Object?>)['grid']
              as Map<String, Object?>;
      grid['enabled'] = true;
      grid['cellSize'] = value;

      expect(
        () => decodeScene(json),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.message ==
                    'Field background.grid.cellSize must be >= 1.0 when background.grid.enabled is true.',
          ),
        ),
      );
    }
  });

  test(
    'decodeScene rejects non-finite grid cellSize regardless of enabled',
    () {
      for (final enabled in <bool>[false, true]) {
        final json = _minimalSceneJson();
        final grid =
            (json['background'] as Map<String, Object?>)['grid']
                as Map<String, Object?>;
        grid['enabled'] = enabled;
        grid['cellSize'] = double.infinity;
        expect(
          () => decodeScene(json),
          throwsA(
            predicate(
              (e) =>
                  e is SceneDataException &&
                  e.message == 'Field cellSize must be finite.',
            ),
          ),
        );
      }
    },
  );

  test('decodeScene rejects negative sizes', () {
    final nodeJson = _baseNodeJson(id: 'img-1', type: 'image')
      ..addAll(<String, Object?>{
        'imageId': 'image-1',
        'size': <String, Object?>{'w': -10, 'h': 20},
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nodeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field layers[0].nodes[0].size.w must be >= 0.',
        ),
      ),
    );
  });

  test('decodeScene rejects invalid optional naturalSize values', () {
    final nonFinite = _baseNodeJson(id: 'img-1', type: 'image')
      ..addAll(<String, Object?>{
        'imageId': 'image-1',
        'size': <String, Object?>{'w': 10, 'h': 20},
        'naturalSize': <String, Object?>{'w': double.infinity, 'h': 20},
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nonFinite)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Optional size must be finite.',
        ),
      ),
    );

    final negative = _baseNodeJson(id: 'img-1', type: 'image')
      ..addAll(<String, Object?>{
        'imageId': 'image-1',
        'size': <String, Object?>{'w': 10, 'h': 20},
        'naturalSize': <String, Object?>{'w': -1, 'h': 20},
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(negative)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message ==
                  'Field layers[0].nodes[0].naturalSize.w must be >= 0.',
        ),
      ),
    );
  });

  test('decodeScene rejects invalid optional doubles for TextNode', () {
    final nonFiniteMaxWidth = _baseNodeJson(id: 't1', type: 'text')
      ..addAll(<String, Object?>{
        'text': 'Hello',
        'fontSize': 12,
        'color': '#FF000000',
        'align': 'left',
        'isBold': false,
        'isItalic': false,
        'isUnderline': false,
        'maxWidth': double.nan,
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nonFiniteMaxWidth)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field maxWidth must be finite.',
        ),
      ),
    );

    final nonPositiveMaxWidth = _baseNodeJson(id: 't1', type: 'text')
      ..addAll(<String, Object?>{
        'text': 'Hello',
        'fontSize': 12,
        'color': '#FF000000',
        'align': 'left',
        'isBold': false,
        'isItalic': false,
        'isUnderline': false,
        'maxWidth': 0,
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nonPositiveMaxWidth)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field layers[0].nodes[0].maxWidth must be > 0.',
        ),
      ),
    );
  });

  test('decodeScene rejects non-positive palette gridSizes', () {
    final json = _minimalSceneJson();
    (json['palette'] as Map<String, Object?>)['gridSizes'] = <Object?>[0];

    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field palette.gridSizes[0] must be > 0.',
        ),
      ),
    );
  });

  test('decodeScene rejects non-finite palette gridSizes', () {
    final json = _minimalSceneJson();
    (json['palette'] as Map<String, Object?>)['gridSizes'] = <Object?>[
      double.infinity,
    ];

    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Items of gridSizes must be finite.',
        ),
      ),
    );
  });

  test('decodeScene rejects oversized palette gridSizes', () {
    final json = _minimalSceneJson();
    (json['palette'] as Map<String, Object?>)['gridSizes'] = <Object?>[
      for (var i = 0; i < kMaxPaletteItems + 1; i++) i + 1,
    ];

    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.path == 'palette.gridSizes' &&
              e.message ==
                  'Field palette.gridSizes must contain at most '
                      '$kMaxPaletteItems items.',
        ),
      ),
    );
  });

  test('encodeScene enforces grid and palette contracts', () {
    // INV:INV-SER-JSON-GRID-PALETTE-CONTRACTS
    final invalidGridScene = sceneSnapshotFromValidated(
      layers: <ContentLayerSnapshot>[
        contentLayerSnapshotFromValidated(id: 'layer-auto-4'),
      ],
      background: const BackgroundSnapshot(
        grid: GridSnapshot(isEnabled: false, cellSize: -12.5),
      ),
    );
    expect(
      () => encodeScene(invalidGridScene),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field background.grid.cellSize must be > 0.',
        ),
      ),
    );

    final enabledGridScene = sceneSnapshotFromValidated(
      layers: <ContentLayerSnapshot>[
        contentLayerSnapshotFromValidated(id: 'layer-auto-5'),
      ],
      background: const BackgroundSnapshot(
        grid: GridSnapshot(isEnabled: true, cellSize: 0),
      ),
    );
    expect(
      () => encodeScene(enabledGridScene),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field background.grid.cellSize must be > 0.',
        ),
      ),
    );

    expect(
      () => encodeScene(
        sceneSnapshotFromValidated(
          layers: <ContentLayerSnapshot>[
            contentLayerSnapshotFromValidated(id: 'layer-auto-6'),
          ],
          palette: scenePaletteSnapshotFromValidated(penColors: const []),
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field palette.penColors must not be empty.',
        ),
      ),
    );
    expect(
      () => encodeScene(
        sceneSnapshotFromValidated(
          layers: <ContentLayerSnapshot>[
            contentLayerSnapshotFromValidated(id: 'layer-auto-7'),
          ],
          palette: scenePaletteSnapshotFromValidated(
            backgroundColors: const [],
          ),
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field palette.backgroundColors must not be empty.',
        ),
      ),
    );
    expect(
      () => encodeScene(
        sceneSnapshotFromValidated(
          layers: <ContentLayerSnapshot>[
            contentLayerSnapshotFromValidated(id: 'layer-auto-8'),
          ],
          palette: scenePaletteSnapshotFromValidated(gridSizes: const []),
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field palette.gridSizes must not be empty.',
        ),
      ),
    );
  });

  test(
    'encodeScene rejects snapshots with oversized stroke and palette lists',
    () {
      // INV:INV-SER-SHARED-STROKE-POINT-LIMIT
      // INV:INV-SER-SHARED-PALETTE-ITEM-LIMIT
      final oversizedStrokeScene = sceneSnapshotFromValidated(
        layers: <ContentLayerSnapshot>[
          contentLayerSnapshotFromValidated(
            id: 'layer-auto-stroke-overflow',
            nodes: <NodeSnapshot>[
              strokeNodeSnapshotFromValidated(
                common: nodeSnapshotCommonFieldsFromValidated(
                  id: 'stroke-overflow',
                  instanceRevision: 1,
                  transform: Transform2D.identity,
                  opacity: 1,
                  hitPadding: 0,
                  isVisible: true,
                  isSelectable: true,
                  isLocked: false,
                  isDeletable: true,
                  isTransformable: true,
                ),
                fields: (
                  points: <Offset>[
                    for (var i = 0; i < kMaxStrokePointsPerNode + 1; i++)
                      Offset(i.toDouble(), 0),
                  ],
                  thickness: 1,
                  color: const Color(0xFF000000),
                ),
              ),
            ],
          ),
        ],
      );

      expect(
        () => encodeScene(oversizedStrokeScene),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == 'layers[0].nodes[0].points',
          ),
        ),
      );

      final oversizedPaletteScene = sceneSnapshotFromValidated(
        layers: <ContentLayerSnapshot>[
          contentLayerSnapshotFromValidated(id: 'layer-auto-palette-overflow'),
        ],
        palette: scenePaletteSnapshotFromValidated(
          penColors: <Color>[
            for (var i = 0; i < kMaxPaletteItems + 1; i++)
              const Color(0xFF111111),
          ],
        ),
      );

      expect(
        () => encodeScene(oversizedPaletteScene),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.code == SceneDataErrorCode.invalidValue &&
                e.path == 'palette.penColors',
          ),
        ),
      );
    },
  );

  test('encodeScene rejects invalid numeric fields', () {
    final cameraNaN = sceneSnapshotFromValidated(
      layers: <ContentLayerSnapshot>[
        contentLayerSnapshotFromValidated(id: 'layer-auto-9'),
      ],
      camera: const CameraSnapshot(offset: Offset(double.nan, 0)),
    );
    expect(
      () => encodeScene(cameraNaN),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field camera.offset.dx must be finite.',
        ),
      ),
    );

    final negativeHitPaddingScene = sceneSnapshotFromValidated(
      layers: <ContentLayerSnapshot>[
        contentLayerSnapshotFromValidated(
          id: 'layer-auto-10',
          nodes: <NodeSnapshot>[
            rectNodeSnapshotFromValidated(
              common: nodeSnapshotCommonFieldsFromValidated(
                id: 'r1',
                hitPadding: -1,
              ),
              fields: (
                size: const Size(10, 10),
                fillColor: const Color(0xFF000000),
                strokeColor: null,
                strokeWidth: 0,
              ),
            ),
          ],
        ),
      ],
    );
    expect(
      () => encodeScene(negativeHitPaddingScene),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field layers[0].nodes[0].hitPadding must be >= 0.',
        ),
      ),
    );

    final nonPositiveFontSizeScene = sceneSnapshotFromValidated(
      layers: <ContentLayerSnapshot>[
        contentLayerSnapshotFromValidated(
          id: 'layer-auto-11',
          nodes: <NodeSnapshot>[
            textNodeSnapshotFromValidated(
              common: nodeSnapshotCommonFieldsFromValidated(id: 't1'),
              fields: (
                text: 'Hello',
                fontSize: 0,
                color: const Color(0xFF000000),
                align: TextAlign.left,
                textDirection: TextDirection.ltr,
                isBold: false,
                isItalic: false,
                isUnderline: false,
                fontFamily: null,
                maxWidth: null,
                lineHeight: null,
              ),
            ),
          ],
        ),
      ],
    );
    expect(
      () => encodeScene(nonPositiveFontSizeScene),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field layers[0].nodes[0].fontSize must be > 0.',
        ),
      ),
    );

    final opacityOutOfRangeScene = sceneSnapshotFromValidated(
      layers: <ContentLayerSnapshot>[
        contentLayerSnapshotFromValidated(
          id: 'layer-auto-12',
          nodes: <NodeSnapshot>[
            rectNodeSnapshotFromValidated(
              common: nodeSnapshotCommonFieldsFromValidated(
                id: 'r1',
                opacity: 2,
              ),
              fields: (
                size: const Size(10, 10),
                fillColor: const Color(0xFF000000),
                strokeColor: null,
                strokeWidth: 0,
              ),
            ),
          ],
        ),
      ],
    );
    expect(
      () => encodeScene(opacityOutOfRangeScene),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message ==
                  'Field layers[0].nodes[0].opacity must be within [0,1].',
        ),
      ),
    );
  });

  test('decodeScene rejects non-integer instanceRevision', () {
    final nodeJson = _baseNodeJson(id: 'r-inst-type', type: 'rect')
      ..addAll(<String, Object?>{
        'instanceRevision': 1.5,
        'size': <String, Object?>{'w': 10, 'h': 10},
        'strokeWidth': 0,
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nodeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field instanceRevision must be an int.',
        ),
      ),
    );
  });

  test('decodeScene rejects non-numeric instanceRevision', () {
    final nodeJson = _baseNodeJson(id: 'r-inst-string', type: 'rect')
      ..addAll(<String, Object?>{
        'instanceRevision': 'abc',
        'size': <String, Object?>{'w': 10, 'h': 10},
        'strokeWidth': 0,
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nodeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidFieldType &&
              e.message == 'Field instanceRevision must be an int.',
        ),
      ),
    );
  });

  test('decodeScene rejects out-of-range numeric instanceRevision', () {
    final nodeJson = _baseNodeJson(id: 'r-inst-huge', type: 'rect')
      ..addAll(<String, Object?>{
        'instanceRevision': 9007199254740992.0,
        'size': <String, Object?>{'w': 10, 'h': 10},
        'strokeWidth': 0,
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nodeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.code == SceneDataErrorCode.invalidValue &&
              e.message == 'Field instanceRevision must be an int.',
        ),
      ),
    );
  });

  test('decodeScene accepts integer-valued double instanceRevision', () {
    final nodeJson = _baseNodeJson(id: 'r-inst-double-int', type: 'rect')
      ..addAll(<String, Object?>{
        'instanceRevision': 3.0,
        'size': <String, Object?>{'w': 10, 'h': 10},
        'strokeWidth': 0,
      });

    final decoded = decodeScene(_sceneWithSingleNode(nodeJson));
    final node = decoded.layers.single.nodes.single as RectNodeSnapshot;
    expect(node.instanceRevision, 3);
  });

  test('decodeScene rejects negative instanceRevision', () {
    final nodeJson = _baseNodeJson(id: 'r-inst-negative', type: 'rect')
      ..addAll(<String, Object?>{
        'instanceRevision': -1,
        'size': <String, Object?>{'w': 10, 'h': 10},
        'strokeWidth': 0,
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(nodeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message ==
                  'Field layers[0].nodes[0].instanceRevision must be >= 0.',
        ),
      ),
    );
  });

  test('encodeScene always writes instanceRevision for nodes', () {
    final encoded = encodeScene(
      SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-13',
            nodes: <NodeSnapshot>[
              RectNodeSnapshot(id: 'rect-inst', size: Size(10, 10)),
            ],
          ),
        ],
      ),
    );

    final layers = encoded['layers'] as List<Object?>;
    final layer0 = layers[0] as Map<String, Object?>;
    final nodes = layer0['nodes'] as List<Object?>;
    final node = nodes[0] as Map<String, Object?>;
    expect(node['instanceRevision'], isA<int>());
    expect(node['instanceRevision'], greaterThanOrEqualTo(1));
  });
}

class _BadOpacityNode extends SceneNode {
  _BadOpacityNode({required super.id}) : super(type: NodeType.rect);

  @override
  Rect get localBounds => Rect.zero;

  @override
  double get opacity => 2;
}
