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
    'schemaVersion': 4,
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
        'nodes': <Object?>[_minimalRectNodeJson(id: 'n1')],
      },
    ],
  };
}

void main() {
  test('SceneBuilder.buildFromSnapshot keeps typed background layer', () {
    final result = SceneBuilder.buildFromSnapshot(
      SceneSnapshot(
        backgroundLayer: BackgroundLayerSnapshot(
          nodes: const <NodeSnapshot>[
            RectNodeSnapshot(id: 'bg', size: Size(1, 1)),
          ],
        ),
        layers: <ContentLayerSnapshot>[
          ContentLayerSnapshot(
            nodes: const <NodeSnapshot>[
              RectNodeSnapshot(id: 'n1', size: Size(1, 1)),
            ],
          ),
        ],
      ),
    );

    expect(result.backgroundLayer, isNotNull);
    expect(result.backgroundLayer!.nodes.single.id, 'bg');
    expect(result.layers.single.nodes.single.id, 'n1');
  });

  test('SceneBuilder.buildFromJson builds typed snapshot', () {
    final result = SceneBuilder.buildFromJson(_minimalSceneJson());

    expect(result.backgroundLayer, isNotNull);
    expect(result.backgroundLayer!.nodes.single.id, 'bg');
    expect(result.layers.single.nodes.single.id, 'n1');
  });
}
