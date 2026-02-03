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

void main() {
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
}
