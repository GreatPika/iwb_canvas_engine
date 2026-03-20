Map<String, Object?> minimalRectNodeJson({required String id}) {
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

Map<String, Object?> minimalSceneJson({
  List<Object?>? backgroundNodes,
  List<Object?>? contentNodes,
}) {
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
    if (backgroundNodes != null)
      'backgroundLayer': <String, Object?>{'nodes': backgroundNodes},
    'layers': <Object?>[
      <String, Object?>{
        'id': 'layer-0',
        'nodes': contentNodes ?? <Object?>[minimalRectNodeJson(id: 'n1')],
      },
    ],
  };
}
