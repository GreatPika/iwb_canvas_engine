import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

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
    'schemaVersion': 5,
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
    'backgroundLayer': <String, Object?>{
      'nodes': <Object?>[_minimalRectNodeJson(id: 'bg')],
    },
    'layers': <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': <Object?>[_minimalRectNodeJson(id: 'n1')],
      },
    ],
  };
}

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
    'size': <String, Object?>{'w': 10, 'h': 10},
    'fontSize': 12,
    'color': '#FF000000',
    'align': align,
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
    final result = SceneBuilder.buildFromJson(_minimalSceneJson());

    expect(result.backgroundLayer.nodes.single.id, 'bg');
    expect(result.layers.single.nodes.single.id, 'n1');
  });

  test(
    'SceneBuilder.buildFromJson matches decodeScene for the same payload',
    () {
      final raw = _minimalSceneJson();

      expect(
        encodeScene(SceneBuilder.buildFromJson(raw)),
        encodeScene(decodeScene(Map<String, dynamic>.from(raw))),
      );
    },
  );

  test(
    'SceneBuilder.buildFromJson surfaces the same path-aware diagnostics as decodeScene',
    () {
      final raw = _minimalSceneJson();
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
    'SceneBuilder.buildFromSnapshot reports path-aware duplicate-id failures',
    () {
      final snapshot = SceneSnapshot(
        backgroundLayer: BackgroundLayerSnapshot(
          nodes: <NodeSnapshot>[
            RectNodeSnapshot(id: 'dup-bg', size: const Size(1, 1)),
            RectNodeSnapshot(id: 'dup-bg', size: const Size(2, 2)),
          ],
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(id: 'layer-auto-0'),
        ],
      );

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
      final raw = _minimalSceneJson();
      raw['backgroundLayer'] = <String, Object?>{
        'nodes': <Object?>[
          _minimalRectNodeJson(id: 'dup-bg'),
          _minimalRectNodeJson(id: 'dup-bg'),
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
