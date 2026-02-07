import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

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

class _RectNodeWithInvalidOpacityGetter extends RectNode {
  _RectNodeWithInvalidOpacityGetter({
    required super.id,
    required super.size,
    super.fillColor,
  });

  @override
  double get opacity => 2;

  @override
  set opacity(double value) {}
}

void main() {
  // INV:INV-SER-JSON-NUMERIC-VALIDATION
  test('encodeSceneToJson -> decodeSceneFromJson is stable', () {
    final scene = Scene(layers: [Layer()]);
    final json = encodeSceneToJson(scene);
    final decoded = decodeSceneFromJson(json);
    expect(encodeScene(decoded), encodeScene(scene));
  });

  test('SceneJsonFormatException implements FormatException shape', () {
    final error = SceneJsonFormatException('bad', 'source');
    expect(error.message, 'bad');
    expect(error.source, 'source');
    expect(error.offset, isNull);
    expect(error.toString(), contains('SceneJsonFormatException'));
  });

  test('decodeSceneFromJson rejects non-object root', () {
    expect(
      () => decodeSceneFromJson('[]'),
      throwsA(
        predicate(
          (e) =>
              e is SceneJsonFormatException &&
              e.message == 'Root JSON must be an object.',
        ),
      ),
    );
  });

  test('decodeSceneFromJson wraps JSON parse failures', () {
    expect(
      () => decodeSceneFromJson('{'),
      throwsA(isA<SceneJsonFormatException>()),
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
              e.message == 'Node must be an object.',
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
              e is SceneJsonFormatException &&
              e.message ==
                  'Duplicate node id: dup-node. Node ids must be unique.',
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
              e is SceneJsonFormatException &&
              e.message == 'Unknown node type: mystery.',
        ),
      ),
    );
  });

  test('encodeScene rejects unsupported TextAlign values', () {
    final scene = Scene(
      layers: [
        Layer(
          nodes: [
            TextNode(
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

    expect(() => encodeScene(scene), throwsA(isA<SceneJsonFormatException>()));
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
              e.message == 'svgPathData must not be empty.',
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
              e is SceneJsonFormatException &&
              e.message == 'Invalid svgPathData.',
        ),
      ),
    );
  });

  test('decodeScene rejects invalid colors in 6- and 8-digit forms', () {
    final six = _minimalSceneJson();
    (six['background'] as Map<String, dynamic>)['color'] = '#GGGGGG';
    expect(() => decodeScene(six), throwsA(isA<SceneJsonFormatException>()));

    final eight = _minimalSceneJson();
    (eight['background'] as Map<String, dynamic>)['color'] = '#GGGGGGGG';
    expect(() => decodeScene(eight), throwsA(isA<SceneJsonFormatException>()));
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
              e is SceneJsonFormatException &&
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
    final node = scene.layers.single.nodes.single as TextNode;
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
              e.message == 'Field fillColor must be a string.',
        ),
      ),
    );

    final paletteWrong = _minimalSceneJson();
    (paletteWrong['palette'] as Map<String, dynamic>)['penColors'] = <dynamic>[
      123,
    ];
    expect(
      () => decodeScene(paletteWrong),
      throwsA(isA<SceneJsonFormatException>()),
    );

    final gridSizesWrong = _minimalSceneJson();
    (gridSizesWrong['palette'] as Map<String, dynamic>)['gridSizes'] =
        <dynamic>['10'];
    expect(
      () => decodeScene(gridSizesWrong),
      throwsA(isA<SceneJsonFormatException>()),
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
              e is SceneJsonFormatException &&
              e.message == 'Field penColors must not be empty.',
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
              e is SceneJsonFormatException &&
              e.message == 'Field backgroundColors must not be empty.',
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
              e is SceneJsonFormatException &&
              e.message == 'Field gridSizes must not be empty.',
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
              e.message == 'Field enabled must be a bool.',
        ),
      ),
    );
  });

  test('decodeScene rejects NaN/Infinity numeric fields', () {
    final json = _minimalSceneJson();
    (json['camera'] as Map<String, dynamic>)['offsetX'] = double.nan;
    expect(
      () => decodeScene(json),
      throwsA(
        predicate(
          (e) =>
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
              e.message == 'Field opacity must be within [0,1].',
        ),
      ),
    );
  });

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
              e is SceneJsonFormatException &&
              e.message == 'Field thickness must be > 0.',
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
              e.message == 'Field strokeWidth must be >= 0.',
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
              e is SceneJsonFormatException &&
              e.message == 'Field hitPadding must be finite.',
        ),
      ),
    );
  });

  test(
    'decodeScene rejects non-positive grid cellSize when grid is enabled',
    () {
      final json = _minimalSceneJson();
      final grid =
          (json['background'] as Map<String, dynamic>)['grid']
              as Map<String, dynamic>;
      grid['enabled'] = true;
      grid['cellSize'] = 0;
      expect(
        () => decodeScene(json),
        throwsA(
          predicate(
            (e) =>
                e is SceneJsonFormatException &&
                e.message == 'Field cellSize must be > 0.',
          ),
        ),
      );
    },
  );

  test('decodeScene accepts disabled-grid finite odd cellSize values', () {
    for (final value in <double>[0, -12.5, 0.125]) {
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
                  e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
              e.message == 'Field w must be >= 0.',
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
              e.message == 'Optional size must be non-negative.',
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
              e is SceneJsonFormatException &&
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
              e is SceneJsonFormatException &&
              e.message == 'Field maxWidth must be > 0.',
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
              e is SceneJsonFormatException &&
              e.message == 'Items of gridSizes must be > 0.',
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
              e is SceneJsonFormatException &&
              e.message == 'Items of gridSizes must be finite.',
        ),
      ),
    );
  });

  test('encodeScene enforces grid and palette contracts', () {
    // INV:INV-SER-JSON-GRID-PALETTE-CONTRACTS
    final disabledGridScene = Scene(
      layers: [Layer()],
      background: Background(
        grid: GridSettings(isEnabled: false, cellSize: -12.5),
      ),
    );
    final disabledGridEncoded = encodeScene(disabledGridScene);
    final disabledGridJson =
        (disabledGridEncoded['background'] as Map<String, dynamic>)['grid']
            as Map<String, dynamic>;
    expect(disabledGridJson['cellSize'], -12.5);

    final enabledGridScene = Scene(
      layers: [Layer()],
      background: Background(grid: GridSettings(isEnabled: true, cellSize: 0)),
    );
    expect(
      () => encodeScene(enabledGridScene),
      throwsA(
        predicate(
          (e) =>
              e is SceneJsonFormatException &&
              e.message == 'Field background.grid.cellSize must be > 0.',
        ),
      ),
    );

    expect(
      () => encodeScene(
        Scene(
          layers: [Layer()],
          palette: ScenePalette(penColors: const []),
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneJsonFormatException &&
              e.message == 'Field palette.penColors must not be empty.',
        ),
      ),
    );
    expect(
      () => encodeScene(
        Scene(
          layers: [Layer()],
          palette: ScenePalette(backgroundColors: const []),
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneJsonFormatException &&
              e.message == 'Field palette.backgroundColors must not be empty.',
        ),
      ),
    );
    expect(
      () => encodeScene(
        Scene(
          layers: [Layer()],
          palette: ScenePalette(gridSizes: const []),
        ),
      ),
      throwsA(
        predicate(
          (e) =>
              e is SceneJsonFormatException &&
              e.message == 'Field palette.gridSizes must not be empty.',
        ),
      ),
    );
  });

  test(
    'encodeScene rejects invalid numeric fields but accepts runtime-normalized opacity',
    () {
      final cameraNaN = Scene(
        layers: [Layer()],
        camera: Camera(offset: Offset(double.nan, 0)),
      );
      expect(
        () => encodeScene(cameraNaN),
        throwsA(
          predicate(
            (e) =>
                e is SceneJsonFormatException &&
                e.message == 'Field camera.offsetX must be finite.',
          ),
        ),
      );

      final negativeHitPaddingScene = Scene(
        layers: [
          Layer(
            nodes: [
              RectNode(
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
                e is SceneJsonFormatException &&
                e.message == 'Field node.hitPadding must be >= 0.',
          ),
        ),
      );

      final nonPositiveFontSizeScene = Scene(
        layers: [
          Layer(
            nodes: [
              TextNode(
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
                e is SceneJsonFormatException &&
                e.message == 'Field text.fontSize must be > 0.',
          ),
        ),
      );

      final opacityOutOfRangeScene = Scene(
        layers: [
          Layer(
            nodes: [
              RectNode(
                id: 'r1',
                size: const Size(10, 10),
                fillColor: const Color(0xFF000000),
                opacity: 2,
              ),
            ],
          ),
        ],
      );
      final encoded = encodeScene(opacityOutOfRangeScene);
      final nodes =
          ((encoded['layers'] as List<dynamic>).single
                  as Map<String, dynamic>)['nodes']
              as List<dynamic>;
      final encodedOpacity = (nodes.single as Map<String, dynamic>)['opacity'];
      expect(encodedOpacity, 1);

      final bypassedOpacityScene = Scene(
        layers: [
          Layer(
            nodes: [
              _RectNodeWithInvalidOpacityGetter(
                id: 'r2',
                size: const Size(10, 10),
                fillColor: const Color(0xFF000000),
              ),
            ],
          ),
        ],
      );
      expect(
        () => encodeScene(bypassedOpacityScene),
        throwsA(
          predicate(
            (e) =>
                e is SceneJsonFormatException &&
                e.message == 'Field node.opacity must be within [0,1].',
          ),
        ),
      );
    },
  );
}
