import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'canvas_contract_limits.dart';
import 'canvas_element.dart';
import 'canvas_errors.dart';
import 'canvas_ids.dart';
import 'canvas_resource.dart';
import 'canvas_value_equality.dart';
import 'canvas_value_validators.dart';

@immutable
final class CanvasMetadata {
  const CanvasMetadata.empty() : _values = const {}, _encodedByteLength = 0;
  factory CanvasMetadata.fromMap(Map<String, Object?> values) {
    final frozen = freezeCanvasMetadata(values);

    return CanvasMetadata._(frozen, utf8.encode(jsonEncode(frozen)).length);
  }

  const CanvasMetadata._(this._values, this._encodedByteLength);

  final Map<String, Object?> _values;
  final int _encodedByteLength;

  bool get isEmpty => _values.isEmpty;
  Iterable<String> get keys => _values.keys;
  bool containsKey(String key) => _values.containsKey(key);
  Object? operator [](String key) => _values[key];

  @override
  bool operator ==(Object other) {
    return other is CanvasMetadata &&
        canvasJsonMapEquals(other._values, _values);
  }

  @override
  int get hashCode => canvasJsonMapHash(_values);
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
       _layers = List.unmodifiable(layers) {
    if (_resources.length > canvasMaxResources) {
      throw const CanvasDataException(
        code: CanvasDataErrorCode.maxItems,
        message: 'document resources exceed the maximum count.',
        path: 'resources',
      );
    }
    if (_layers.length > canvasMaxContentLayers) {
      throw const CanvasDataException(
        code: CanvasDataErrorCode.maxItems,
        message: 'document layers exceed the maximum count.',
        path: 'layers',
      );
    }
    final totalElements =
        _backgroundElements.length +
        _layers.fold<int>(0, (count, layer) => count + layer.elements.length);
    if (totalElements > canvasMaxTotalElements) {
      throw const CanvasDataException(
        code: CanvasDataErrorCode.maxNodes,
        message: 'document elements exceed the maximum count.',
        path: 'elements',
      );
    }
    _validateDocumentMetadataBudget(
      metadata,
      resources: _resources,
      backgroundElements: _backgroundElements,
      layers: _layers,
    );
  }

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

@immutable
final class CanvasDocumentSummary {
  const CanvasDocumentSummary({
    required this.elementCount,
    required this.layerCount,
    required this.resourceCount,
  });

  final int elementCount;
  final int layerCount;
  final int resourceCount;

  @override
  bool operator ==(Object other) {
    return other is CanvasDocumentSummary &&
        other.elementCount == elementCount &&
        other.layerCount == layerCount &&
        other.resourceCount == resourceCount;
  }

  @override
  int get hashCode => Object.hash(elementCount, layerCount, resourceCount);
}

final class CanvasLayer {
  CanvasLayer({
    required this.id,
    Iterable<CanvasElement> elements = const [],
    this.metadata = const CanvasMetadata.empty(),
  }) : _elements = List.unmodifiable(elements) {
    if (_elements.length > canvasMaxTotalElements) {
      throw const CanvasDataException(
        code: CanvasDataErrorCode.maxNodes,
        message: 'layer elements exceed the maximum count.',
        path: 'layer.elements',
      );
    }
  }

  final CanvasLayerId id;
  final List<CanvasElement> _elements;
  final CanvasMetadata metadata;
  List<CanvasElement> get elements => _elements;
}

@immutable
final class CanvasCamera {
  factory CanvasCamera({Offset offset = Offset.zero}) {
    validateOffset(offset, path: 'camera.offset');

    return CanvasCamera._(offset: offset);
  }

  const CanvasCamera._({this.offset = Offset.zero});
  static const origin = CanvasCamera._();
  final Offset offset;

  @override
  bool operator ==(Object other) {
    return other is CanvasCamera && other.offset == offset;
  }

  @override
  int get hashCode => offset.hashCode;
}

@immutable
final class CanvasBackground {
  const CanvasBackground({
    this.color = const Color(0xFFFFFFFF),
    this.grid = CanvasGrid.disabled,
  });

  final Color color;
  final CanvasGrid grid;

  @override
  bool operator ==(Object other) {
    return other is CanvasBackground &&
        other.color == color &&
        other.grid == grid;
  }

  @override
  int get hashCode => Object.hash(color, grid);
}

@immutable
final class CanvasGrid {
  factory CanvasGrid({
    bool enabled = false,
    double cellSize = 10.0,
    Color color = const Color(0x1F000000),
  }) {
    if (enabled) {
      validatePositiveDouble(
        cellSize,
        path: 'grid.cellSize',
        max: canvasMaxPositiveSize,
      );
      if (cellSize < canvasMinEnabledGridCellSize) {
        throw CanvasDataException(
          code: CanvasDataErrorCode.fieldMustBeInRange,
          message: 'enabled grid cell size is below the minimum.',
          path: 'grid.cellSize',
          details: {'min': canvasMinEnabledGridCellSize, 'actual': cellSize},
        );
      }
    } else {
      validateNonNegativeDouble(
        cellSize,
        path: 'grid.cellSize',
        max: canvasMaxPositiveSize,
      );
    }

    return CanvasGrid._(enabled: enabled, cellSize: cellSize, color: color);
  }

  const CanvasGrid._({
    this.enabled = false,
    this.cellSize = 10.0,
    this.color = const Color(0x1F000000),
  });

  static const disabled = CanvasGrid._();
  final bool enabled;
  final double cellSize;
  final Color color;

  @override
  bool operator ==(Object other) {
    return other is CanvasGrid &&
        other.enabled == enabled &&
        other.cellSize == cellSize &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(enabled, cellSize, color);
}

final class CanvasPalette {
  CanvasPalette({
    required Iterable<Color> penColors,
    required Iterable<Color> backgroundColors,
    required Iterable<double> gridSizes,
  }) : _penColors = List.unmodifiable(penColors),
       _backgroundColors = List.unmodifiable(backgroundColors),
       _gridSizes = List.unmodifiable(gridSizes) {
    _validatePaletteList(_penColors, path: 'palette.penColors');
    _validatePaletteList(_backgroundColors, path: 'palette.backgroundColors');
    _validatePaletteList(_gridSizes, path: 'palette.gridSizes');
    for (final gridSize in _gridSizes) {
      validatePositiveDouble(
        gridSize,
        path: 'palette.gridSizes',
        max: canvasMaxPositiveSize,
      );
    }
  }

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

void _validatePaletteList(List<Object> values, {required String path}) {
  if (values.length > canvasMaxPaletteItems) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.maxItems,
      message: '$path exceeds the maximum count.',
      path: path,
      details: {'maxItems': canvasMaxPaletteItems, 'actual': values.length},
    );
  }
}

void _validateDocumentMetadataBudget(
  CanvasMetadata documentMetadata, {
  required List<CanvasResource> resources,
  required List<CanvasElement> backgroundElements,
  required List<CanvasLayer> layers,
}) {
  final total =
      documentMetadata._encodedByteLength +
      resources.fold<int>(
        0,
        (count, resource) => count + resource.metadata._encodedByteLength,
      ) +
      backgroundElements.fold<int>(
        0,
        (count, element) => count + element.metadata._encodedByteLength,
      ) +
      layers.fold<int>(
        0,
        (count, layer) =>
            count +
            layer.metadata._encodedByteLength +
            layer.elements.fold<int>(
              0,
              (elementCount, element) =>
                  elementCount + element.metadata._encodedByteLength,
            ),
      );
  if (total > canvasMetadataMaxEncodedBytes) {
    throw CanvasDataException(
      code: CanvasDataErrorCode.invalidMetadata,
      message: 'document metadata exceeds the aggregate encoded byte limit.',
      path: 'metadata',
      details: {
        'maxEncodedBytes': canvasMetadataMaxEncodedBytes,
        'actualEncodedBytes': total,
      },
    );
  }
}
