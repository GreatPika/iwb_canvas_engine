import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/serialization/scene_codec.dart'
    show encodeSceneDocument;

Map<String, dynamic> _minimalSceneJson() {
  return <String, dynamic>{
    'schemaVersion': schemaVersionWrite,
    'camera': <String, dynamic>{'offsetX': 0, 'offsetY': 0},
    'background': <String, dynamic>{
      'color': '#FFFFFFFF',
      'grid': <String, dynamic>{
        'enabled': false,
        'cellSize': 10,
        'color': '#1F000000',
      },
    },
    'palette': <String, dynamic>{
      'penColors': <dynamic>['#FF000000'],
      'backgroundColors': <dynamic>['#FFFFFFFF'],
      'gridSizes': <dynamic>[10],
    },
    'layers': <dynamic>[],
  };
}

Map<String, dynamic> _sceneWithSingleNode(Map<String, dynamic> nodeJson) {
  final json = _minimalSceneJson();
  json['layers'] = <dynamic>[
    <String, dynamic>{
      'isBackground': false,
      'nodes': <dynamic>[nodeJson],
    },
  ];
  return json;
}

Map<String, dynamic> _baseNodeJson({required String id, required String type}) {
  return <String, dynamic>{
    'id': id,
    'type': type,
    'transform': <String, dynamic>{
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

void main() {
  // INV:INV-SER-JSON-NUMERIC-VALIDATION
  test('encodeSceneToJson -> decodeSceneFromJson is stable', () {
    final scene = SceneSnapshot(
      layers: [LayerSnapshot(isBackground: true), LayerSnapshot()],
    );
    final json = encodeSceneToJson(scene);
    final decoded = decodeSceneFromJson(json);
    expect(encodeScene(decoded), encodeScene(scene));
  });

  test('SceneDataException implements FormatException shape', () {
    const error = SceneDataException(
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
              e.message == 'Root JSON must be an object.',
        ),
      ),
    );
  });

  test('decodeSceneFromJson wraps JSON parse failures', () {
    expect(() => decodeSceneFromJson('{'), throwsA(isA<SceneDataException>()));
  });

  test('decodeScene does not auto-insert missing background layer', () {
    // INV:INV-SER-BACKGROUND-SINGLE-AT-ZERO
    final scene = decodeScene(_minimalSceneJson());
    expect(scene.layers, isEmpty);
  });

  test(
    'decodeScene moves misordered background layer to index 0 preserving order',
    () {
      // INV:INV-SER-BACKGROUND-SINGLE-AT-ZERO
      final bgNode = _baseNodeJson(id: 'bg', type: 'rect')
        ..addAll(<String, dynamic>{
          'size': <String, dynamic>{'w': 1, 'h': 1},
          'strokeWidth': 0,
        });
      final n1 = _baseNodeJson(id: 'n1', type: 'rect')
        ..addAll(<String, dynamic>{
          'size': <String, dynamic>{'w': 1, 'h': 1},
          'strokeWidth': 0,
        });
      final n2 = _baseNodeJson(id: 'n2', type: 'rect')
        ..addAll(<String, dynamic>{
          'size': <String, dynamic>{'w': 1, 'h': 1},
          'strokeWidth': 0,
        });
      final json = _minimalSceneJson();
      json['layers'] = <dynamic>[
        <String, dynamic>{
          'isBackground': false,
          'nodes': <dynamic>[n1],
        },
        <String, dynamic>{
          'isBackground': true,
          'nodes': <dynamic>[bgNode],
        },
        <String, dynamic>{
          'isBackground': false,
          'nodes': <dynamic>[n2],
        },
      ];

      final scene = decodeScene(json);

      expect(scene.layers, hasLength(3));
      expect(scene.layers.first.isBackground, isTrue);
      expect(scene.layers[1].nodes.single.id, 'n1');
      expect(scene.layers[2].nodes.single.id, 'n2');
    },
  );

  test('decodeScene rejects multiple background layers', () {
    // INV:INV-SER-BACKGROUND-SINGLE-AT-ZERO
    final firstBg = _baseNodeJson(id: 'bg-1', type: 'rect')
      ..addAll(<String, dynamic>{
        'size': <String, dynamic>{'w': 1, 'h': 1},
        'strokeWidth': 0,
      });
    final secondBg = _baseNodeJson(id: 'bg-2', type: 'rect')
      ..addAll(<String, dynamic>{
        'size': <String, dynamic>{'w': 1, 'h': 1},
        'strokeWidth': 0,
      });
    final json = _minimalSceneJson();
    json['layers'] = <dynamic>[
      <String, dynamic>{
        'isBackground': true,
        'nodes': <dynamic>[firstBg],
      },
      <String, dynamic>{
        'isBackground': true,
        'nodes': <dynamic>[secondBg],
      },
    ];

    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Must contain at most one background layer.',
        ),
      ),
    );
  });

  test('decodeScene rejects non-object layer entries', () {
    final json = _minimalSceneJson();
    json['layers'] = <dynamic>[123];
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
    json['layers'] = <dynamic>[
      <String, dynamic>{
        'isBackground': false,
        'nodes': <dynamic>[123],
      },
    ];
    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException && e.message == 'Node must be an object.',
        ),
      ),
    );
  });

  test('decodeScene rejects duplicate node ids across layers', () {
    // INV:INV-G-NODEID-UNIQUE
    final json = _minimalSceneJson();
    json['layers'] = <dynamic>[
      <String, dynamic>{
        'isBackground': false,
        'nodes': <dynamic>[
          _baseNodeJson(id: 'dup-node', type: 'rect')..addAll(<String, dynamic>{
            'size': <String, dynamic>{'w': 10, 'h': 10},
            'strokeWidth': 0,
          }),
        ],
      },
      <String, dynamic>{
        'isBackground': false,
        'nodes': <dynamic>[
          _baseNodeJson(id: 'dup-node', type: 'rect')..addAll(<String, dynamic>{
            'size': <String, dynamic>{'w': 20, 'h': 20},
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

  test('encodeScene rejects unsupported TextAlign values', () {
    final scene = SceneSnapshot(
      layers: [
        LayerSnapshot(
          nodes: [
            TextNodeSnapshot(
              id: 'text-1',
              text: 'Hello',
              size: const Size(10, 10),
              fontSize: 12,
              color: const Color(0xFF000000),
              align: TextAlign.justify,
            ),
          ],
        ),
      ],
    );

    expect(() => encodeScene(scene), throwsA(isA<SceneDataException>()));
  });

  test('decodeScene rejects unknown fillRule', () {
    final nodeJson = _baseNodeJson(id: 'p1', type: 'path')
      ..addAll(<String, dynamic>{
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
      ..addAll(<String, dynamic>{
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
      ..addAll(<String, dynamic>{
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
    (six['background'] as Map<String, dynamic>)['color'] = '#GGGGGG';
    expect(() => decodeScene(six), throwsA(isA<SceneDataException>()));

    final eight = _minimalSceneJson();
    (eight['background'] as Map<String, dynamic>)['color'] = '#GGGGGGGG';
    expect(() => decodeScene(eight), throwsA(isA<SceneDataException>()));
  });

  test('decodeScene accepts 6-digit colors', () {
    final json = _minimalSceneJson();
    (json['background'] as Map<String, dynamic>)['color'] = '#112233';

    final scene = decodeScene(json);
    expect(scene.background.color, const Color(0xFF112233));
  });

  test('decodeScene rejects non-object naturalSize for image nodes', () {
    final nodeJson = _baseNodeJson(id: 'img-1', type: 'image')
      ..addAll(<String, dynamic>{
        'imageId': 'image-1',
        'size': <String, dynamic>{'w': 10, 'h': 20},
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

  test('decodeScene parses text align right and rejects unknown aligns', () {
    final nodeJson = _baseNodeJson(id: 't1', type: 'text')
      ..addAll(<String, dynamic>{
        'text': 'Hello',
        'size': <String, dynamic>{'w': 10, 'h': 10},
        'fontSize': 12,
        'color': '#FF000000',
        'align': 'right',
        'isBold': false,
        'isItalic': false,
        'isUnderline': false,
      });

    final scene = decodeScene(_sceneWithSingleNode(nodeJson));
    final node =
        scene.layers.firstWhere((layer) => !layer.isBackground).nodes.single
            as TextNodeSnapshot;
    expect(node.align, TextAlign.right);

    final invalidAlignJson = _baseNodeJson(id: 't2', type: 'text')
      ..addAll(<String, dynamic>{
        'text': 'Hello',
        'size': <String, dynamic>{'w': 10, 'h': 10},
        'fontSize': 12,
        'color': '#FF000000',
        'align': 'start',
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
              e.message == 'Unknown text align: start.',
        ),
      ),
    );
  });

  test('decodeScene validates point and optional field types', () {
    final strokeJson = _baseNodeJson(id: 's1', type: 'stroke')
      ..addAll(<String, dynamic>{
        'localPoints': <dynamic>[123],
        'thickness': 2,
        'color': '#FF000000',
      });

    expect(
      () => decodeScene(_sceneWithSingleNode(strokeJson)),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'localPoints must be an object with x/y.',
        ),
      ),
    );

    final imageJson = _baseNodeJson(id: 'img1', type: 'image')
      ..addAll(<String, dynamic>{
        'imageId': 'asset:sample',
        'size': <String, dynamic>{'w': 10, 'h': 10},
        'naturalSize': <String, dynamic>{'w': 'x', 'h': 10},
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
      ..addAll(<String, dynamic>{
        'text': 'Hello',
        'size': <String, dynamic>{'w': 10, 'h': 10},
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
              e.message == 'Field fontFamily must be a string.',
        ),
      ),
    );

    final textJsonWidth = _baseNodeJson(id: 't2', type: 'text')
      ..addAll(<String, dynamic>{
        'text': 'Hello',
        'size': <String, dynamic>{'w': 10, 'h': 10},
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
              e.message == 'Field maxWidth must be a number.',
        ),
      ),
    );

    final pathJson = _baseNodeJson(id: 'p1', type: 'path')
      ..addAll(<String, dynamic>{
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
    (listWrong['palette'] as Map<String, dynamic>)['penColors'] = 'not-a-list';
    expect(
      () => decodeScene(listWrong),
      throwsA(
        predicate(
          (e) =>
              e is SceneDataException &&
              e.message == 'Field penColors must be a list.',
        ),
      ),
    );

    final stringWrong = _minimalSceneJson();
    (stringWrong['background'] as Map<String, dynamic>)['color'] = 123;
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
    (numberWrong['camera'] as Map<String, dynamic>)['offsetX'] = '0';
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
      ..addAll(<String, dynamic>{
        'size': <String, dynamic>{'w': 10, 'h': 10},
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
    (paletteWrong['palette'] as Map<String, dynamic>)['penColors'] = <dynamic>[
      123,
    ];
    expect(() => decodeScene(paletteWrong), throwsA(isA<SceneDataException>()));

    final gridSizesWrong = _minimalSceneJson();
    (gridSizesWrong['palette'] as Map<String, dynamic>)['gridSizes'] =
        <dynamic>['10'];
    expect(
      () => decodeScene(gridSizesWrong),
      throwsA(isA<SceneDataException>()),
    );
  });

  test('decodeScene rejects empty palette lists', () {
    // INV:INV-SER-JSON-GRID-PALETTE-CONTRACTS
    final emptyPen = _minimalSceneJson();
    (emptyPen['palette'] as Map<String, dynamic>)['penColors'] = <dynamic>[];
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
    (emptyBackground['palette'] as Map<String, dynamic>)['backgroundColors'] =
        <dynamic>[];
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
    (emptyGridSizes['palette'] as Map<String, dynamic>)['gridSizes'] =
        <dynamic>[];
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
    cameraWrong['camera'] = <dynamic>[];
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
    ((enabledWrong['background'] as Map<String, dynamic>)['grid']
            as Map<String, dynamic>)['enabled'] =
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

  test('decodeScene accepts integer-valued numeric schemaVersion', () {
    final json = _minimalSceneJson();
    json['schemaVersion'] = 2.0;

    final scene = decodeScene(json);
    expect(scene.layers, isEmpty);
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
                    'Unsupported schemaVersion: 1. Expected one of: [2].',
          ),
        ),
      );
    },
  );

  test('decodeScene rejects NaN/Infinity numeric fields', () {
    final json = _minimalSceneJson();
    (json['camera'] as Map<String, dynamic>)['offsetX'] = double.nan;
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
    (json2['camera'] as Map<String, dynamic>)['offsetY'] = double.infinity;
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
      ..addAll(<String, dynamic>{
        'size': <String, dynamic>{'w': 10, 'h': 10},
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
      layers: <Layer>[
        Layer(nodes: <SceneNode>[_BadOpacityNode(id: 'bad-opacity')]),
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
      layers: <Layer>[
        Layer(
          isBackground: true,
          nodes: <SceneNode>[RectNode(id: 'bg-rect', size: const Size(10, 5))],
        ),
        Layer(
          nodes: <SceneNode>[RectNode(id: 'fg-rect', size: const Size(3, 2))],
        ),
      ],
    );

    final encoded = encodeSceneDocument(scene);
    expect(encoded['schemaVersion'], schemaVersionWrite);

    final camera = encoded['camera'] as Map<String, dynamic>;
    expect(camera['offsetX'], 12);
    expect(camera['offsetY'], -7);

    final background = encoded['background'] as Map<String, dynamic>;
    expect(background['color'], '#FF010203');
    final grid = background['grid'] as Map<String, dynamic>;
    expect(grid['enabled'], isTrue);
    expect(grid['cellSize'], 16);
    expect(grid['color'], '#FF040506');

    final palette = encoded['palette'] as Map<String, dynamic>;
    expect(palette['penColors'], <String>['#FF111111']);
    expect(palette['backgroundColors'], <String>['#FF222222']);
    expect(palette['gridSizes'], <double>[8, 16]);

    final layers = encoded['layers'] as List<dynamic>;
    expect(layers, hasLength(2));
    expect((layers[0] as Map<String, dynamic>)['isBackground'], isTrue);
    expect((layers[1] as Map<String, dynamic>)['isBackground'], isFalse);
  });

  test(
    'encodeSceneDocument rejects duplicate node ids and multiple background layers',
    () {
      final duplicateIds = Scene(
        layers: <Layer>[
          Layer(
            nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(1, 1))],
          ),
          Layer(
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
                e.message ==
                    'Field layers[1].nodes[0].id must be unique across scene layers.',
          ),
        ),
      );

      final multipleBackground = Scene(
        layers: <Layer>[Layer(isBackground: true), Layer(isBackground: true)],
      );
      expect(
        () => encodeSceneDocument(multipleBackground),
        throwsA(
          predicate(
            (e) =>
                e is SceneDataException &&
                e.message ==
                    'Field layers must contain at most one background layer.',
          ),
        ),
      );
    },
  );

  test('decodeScene rejects non-positive thickness', () {
    final nodeJson = _baseNodeJson(id: 's1', type: 'stroke')
      ..addAll(<String, dynamic>{
        'localPoints': <dynamic>[
          <String, dynamic>{'x': 0, 'y': 0},
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
      ..addAll(<String, dynamic>{
        'localPoints': <dynamic>[
          <String, dynamic>{'x': 0, 'y': 0},
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
      ..addAll(<String, dynamic>{
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
      ..addAll(<String, dynamic>{
        'size': <String, dynamic>{'w': 10, 'h': 10},
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
            (json['background'] as Map<String, dynamic>)['grid']
                as Map<String, dynamic>;
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
          (json['background'] as Map<String, dynamic>)['grid']
              as Map<String, dynamic>;
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
            (json['background'] as Map<String, dynamic>)['grid']
                as Map<String, dynamic>;
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
      ..addAll(<String, dynamic>{
        'imageId': 'image-1',
        'size': <String, dynamic>{'w': -10, 'h': 20},
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
      ..addAll(<String, dynamic>{
        'imageId': 'image-1',
        'size': <String, dynamic>{'w': 10, 'h': 20},
        'naturalSize': <String, dynamic>{'w': double.infinity, 'h': 20},
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
      ..addAll(<String, dynamic>{
        'imageId': 'image-1',
        'size': <String, dynamic>{'w': 10, 'h': 20},
        'naturalSize': <String, dynamic>{'w': -1, 'h': 20},
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
      ..addAll(<String, dynamic>{
        'text': 'Hello',
        'size': <String, dynamic>{'w': 10, 'h': 10},
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
      ..addAll(<String, dynamic>{
        'text': 'Hello',
        'size': <String, dynamic>{'w': 10, 'h': 10},
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
    (json['palette'] as Map<String, dynamic>)['gridSizes'] = <dynamic>[0];

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
    (json['palette'] as Map<String, dynamic>)['gridSizes'] = <dynamic>[
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
    final invalidGridScene = SceneSnapshot(
      layers: [LayerSnapshot()],
      background: BackgroundSnapshot(
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

    final enabledGridScene = SceneSnapshot(
      layers: [LayerSnapshot()],
      background: BackgroundSnapshot(
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
        SceneSnapshot(
          layers: [LayerSnapshot()],
          palette: ScenePaletteSnapshot(penColors: const []),
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
        SceneSnapshot(
          layers: [LayerSnapshot()],
          palette: ScenePaletteSnapshot(backgroundColors: const []),
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
        SceneSnapshot(
          layers: [LayerSnapshot()],
          palette: ScenePaletteSnapshot(gridSizes: const []),
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
    final cameraNaN = SceneSnapshot(
      layers: [LayerSnapshot()],
      camera: CameraSnapshot(offset: Offset(double.nan, 0)),
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

    final negativeHitPaddingScene = SceneSnapshot(
      layers: [
        LayerSnapshot(
          nodes: [
            RectNodeSnapshot(
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

    final nonPositiveFontSizeScene = SceneSnapshot(
      layers: [
        LayerSnapshot(
          nodes: [
            TextNodeSnapshot(
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

    final opacityOutOfRangeScene = SceneSnapshot(
      layers: [
        LayerSnapshot(
          nodes: [
            RectNodeSnapshot(
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
}

class _BadOpacityNode extends SceneNode {
  _BadOpacityNode({required super.id}) : super(type: NodeType.rect);

  @override
  Rect get localBounds => Rect.zero;

  @override
  double get opacity => 2;
}
