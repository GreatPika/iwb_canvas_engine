import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart'
    show
        kMaxContentLayersPerScene,
        kMaxFontFamilyLength,
        kMaxLayerIdLength,
        kMaxNodesPerScene,
        kMaxPaletteItems,
        kMaxStrokePointsPerNode,
        kMaxSvgPathDataLength,
        kMaxTextLength;
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/serialization/scene_codec.dart'
    show encodeSceneDocument;

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
  };
}

String _expectedSchemaVersionsMessage() {
  final versions = schemaVersionsRead.toList()..sort((a, b) => a.compareTo(b));
  return versions.join(', ');
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
      code: SceneDataErrorCode.invalidValue,
      message: 'bad',
      source: 'source',
    );
    expect(error.message, 'bad');
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

  test(
    'SceneBuilder.buildFromJson and decodeScene report matching nested validation diagnostics',
    () {
      final invalidAlignJson = _baseNodeJson(id: 't2', type: 'text')
        ..addAll(<String, Object?>{
          'text': 'Hello',
          'size': <String, Object?>{'w': 10, 'h': 10},
          'fontSize': 12,
          'color': '#FF000000',
          'align': 'diagonal',
          'isBold': false,
          'isItalic': false,
          'isUnderline': false,
        });
      final raw = _sceneWithSingleNode(invalidAlignJson);

      SceneDataException capture(void Function() callback) {
        try {
          callback();
          fail('Expected SceneDataException');
        } on SceneDataException catch (error) {
          return error;
        }
      }

      final fromBuilder = capture(() => SceneBuilder.buildFromJson(raw));
      final fromCodec = capture(
        () => decodeScene(Map<String, Object?>.from(raw)),
      );

      expect(fromBuilder.code, fromCodec.code);
      expect(fromBuilder.message, fromCodec.message);
      expect(fromBuilder.path, fromCodec.path);
      expect(fromBuilder.path, 'layers[0].nodes[0].align');
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
      final backgroundNode = _baseNodeJson(id: 'bg', type: 'rect')
        ..addAll(<String, Object?>{
          'size': <String, Object?>{'w': 1, 'h': 1},
          'strokeWidth': 0,
        });
      final contentNode = _baseNodeJson(id: 'fg', type: 'rect')
        ..addAll(<String, Object?>{
          'size': <String, Object?>{'w': 1, 'h': 1},
          'strokeWidth': 0,
        });
      json['backgroundLayer'] = <String, Object?>{
        'nodes': <Object?>[
          for (var i = 0; i < kMaxNodesPerScene; i++) backgroundNode,
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
        'size': <String, Object?>{'w': 1, 'h': 1},
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

  test('decodeScene rejects oversized palette penColors', () {
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

  test('encodeScene round-trips supported extended TextAlign values', () {
    SceneSnapshot sceneFor(TextAlign align, String id) {
      return SceneSnapshot(
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            id: 'layer-auto-3',
            nodes: <NodeSnapshot>[
              TextNodeSnapshot(
                id: id,
                text: 'Hello',
                size: const Size(10, 10),
                fontSize: 12,
                color: const Color(0xFF000000),
                align: align,
              ),
            ],
          ),
        ],
      );
    }

    for (final entry in <(TextAlign, String)>[
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

  test('decodeScene parses full supported text align set', () {
    for (final entry in <(String, TextAlign)>[
      ('right', TextAlign.right),
      ('justify', TextAlign.justify),
      ('start', TextAlign.start),
      ('end', TextAlign.end),
    ]) {
      final nodeJson = _baseNodeJson(id: 't-${entry.$1}', type: 'text')
        ..addAll(<String, Object?>{
          'text': 'Hello',
          'size': <String, Object?>{'w': 10, 'h': 10},
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
        'size': <String, Object?>{'w': 10, 'h': 10},
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

  test('decodeScene re-derives stale serialized text size on import', () {
    final nodeJson = _baseNodeJson(id: 't-derived', type: 'text')
      ..addAll(<String, Object?>{
        'text': 'Derived text size',
        'size': <String, Object?>{'w': 1, 'h': 1},
        'fontSize': 24,
        'color': '#FF000000',
        'align': 'left',
        'isBold': false,
        'isItalic': false,
        'isUnderline': false,
      });

    final decoded = decodeScene(_sceneWithSingleNode(nodeJson));
    final text = decoded.layers.first.nodes.single as TextNodeSnapshot;
    expect(text.size, isNot(const Size(1, 1)));
    expect(text.size.width, greaterThan(1));
    expect(text.size.height, greaterThan(1));

    final encoded = encodeScene(decoded);
    final layers = encoded['layers'] as List<Object?>;
    final layer = layers.single as Map<String, Object?>;
    final nodes = layer['nodes'] as List<Object?>;
    final encodedText = nodes.single as Map<String, Object?>;
    final encodedSize = encodedText['size'] as Map<String, Object?>;
    expect(encodedSize['w'], closeTo(text.size.width, 0.001));
    expect(encodedSize['h'], closeTo(text.size.height, 0.001));
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
        'size': <String, Object?>{'w': 10, 'h': 10},
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
        'size': <String, Object?>{'w': 10, 'h': 10},
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
          'size': <String, Object?>{'w': 10, 'h': 10},
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
    final json = _minimalSceneJson();
    json['schemaVersion'] = 5.0;

    final scene = decodeScene(json);
    expect(scene.layers, isEmpty);
    expect(scene.backgroundLayer, isNotNull);
  });

  test('schema write version is included in read versions', () {
    expect(schemaVersionsRead, contains(schemaVersionWrite));
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
      final json = _minimalSceneJson();
      json['schemaVersion'] = 1.0;
      expect(
        () => decodeScene(json),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.message ==
                    'Unsupported schemaVersion: 1. Expected one of: [${_expectedSchemaVersionsMessage()}].',
          ),
        ),
      );
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
    final snapshot = SceneSnapshot(
      backgroundLayer: BackgroundLayerSnapshot(
        nodes: <NodeSnapshot>[
          RectNodeSnapshot(id: 'dup', size: const Size(1, 1)),
        ],
      ),
      layers: <ContentLayerSnapshot>[
        ContentLayerSnapshot(
          id: 'layer-auto-dup-encode',
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(id: 'dup', size: const Size(2, 2)),
          ],
        ),
      ],
    );

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
        'size': <String, Object?>{'w': 10, 'h': 10},
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
        'size': <String, Object?>{'w': 10, 'h': 10},
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
              id: 'r1',
              size: const Size(10, 10),
              fillColor: const Color(0xFF000000),
              hitPadding: -1,
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
              id: 't1',
              text: 'Hello',
              size: const Size(10, 10),
              fontSize: 0,
              color: const Color(0xFF000000),
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
              id: 'r1',
              size: const Size(10, 10),
              fillColor: const Color(0xFF000000),
              opacity: 2,
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
