import 'dart:ui';

import 'canvas_element.dart';
import 'canvas_ids.dart';
import 'canvas_resource.dart';

final class CanvasMetadata {
  const CanvasMetadata.empty();
  CanvasMetadata.fromMap(Map<String, Object?> values);

  bool get isEmpty => throw UnimplementedError();
  Iterable<String> get keys => throw UnimplementedError();
  bool containsKey(String key) => throw UnimplementedError();
  Object? operator [](String key) => throw UnimplementedError();
}

final class CanvasDocument {
  CanvasDocument({
    this.camera = CanvasCamera.origin,
    this.background = const CanvasBackground(),
    CanvasPalette? palette,
    Iterable<CanvasResource> resources = const [],
    Iterable<CanvasElement> backgroundElements = const [],
    Iterable<CanvasLayer> layers = const [],
    this.metadata = const CanvasMetadata.empty(),
  }) : palette = palette ?? CanvasPalette.defaults(),
       _resources = List.unmodifiable(resources),
       _backgroundElements = List.unmodifiable(backgroundElements),
       _layers = List.unmodifiable(layers);

  final CanvasCamera camera;
  final CanvasBackground background;
  final CanvasPalette palette;
  final List<CanvasResource> _resources;
  final List<CanvasElement> _backgroundElements;
  final List<CanvasLayer> _layers;
  final CanvasMetadata metadata;
  List<CanvasResource> get resources => _resources;
  List<CanvasElement> get backgroundElements => _backgroundElements;
  List<CanvasLayer> get layers => _layers;
}

final class CanvasDocumentSummary {
  const CanvasDocumentSummary({
    required this.elementCount,
    required this.layerCount,
    required this.resourceCount,
  });

  final int elementCount;
  final int layerCount;
  final int resourceCount;
}

final class CanvasLayer {
  CanvasLayer({
    required this.id,
    Iterable<CanvasElement> elements = const [],
    this.metadata = const CanvasMetadata.empty(),
  }) : _elements = List.unmodifiable(elements);

  final CanvasLayerId id;
  final List<CanvasElement> _elements;
  final CanvasMetadata metadata;
  List<CanvasElement> get elements => _elements;
}

final class CanvasCamera {
  const CanvasCamera({this.offset = Offset.zero});
  static const origin = CanvasCamera();
  final Offset offset;
}

final class CanvasBackground {
  const CanvasBackground({
    this.color = const Color(0xFFFFFFFF),
    this.grid = CanvasGrid.disabled,
  });

  final Color color;
  final CanvasGrid grid;
}

final class CanvasGrid {
  const CanvasGrid({
    this.enabled = false,
    this.cellSize = 10.0,
    this.color = const Color(0x1F000000),
  });

  static const disabled = CanvasGrid();
  final bool enabled;
  final double cellSize;
  final Color color;
}

final class CanvasPalette {
  CanvasPalette({
    required Iterable<Color> penColors,
    required Iterable<Color> backgroundColors,
    required Iterable<double> gridSizes,
  }) : _penColors = List.unmodifiable(penColors),
       _backgroundColors = List.unmodifiable(backgroundColors),
       _gridSizes = List.unmodifiable(gridSizes);

  CanvasPalette.defaults()
    : _penColors = const [],
      _backgroundColors = const [],
      _gridSizes = const [];

  final List<Color> _penColors;
  final List<Color> _backgroundColors;
  final List<double> _gridSizes;
  List<Color> get penColors => _penColors;
  List<Color> get backgroundColors => _backgroundColors;
  List<double> get gridSizes => _gridSizes;
}
