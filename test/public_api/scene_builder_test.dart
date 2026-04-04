import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
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
