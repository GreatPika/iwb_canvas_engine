import 'dart:ui';

import '../contract/internal/snapshot_fast_path.dart';
import '../contract/scene_contract_limits.dart';
import '../contract/scene_data_exception.dart';
import '../contract/scene_model_invariants.dart';
import '../contract/validated/validated_value_support.dart';
import '../core/scene_limits.dart' show sceneSchemaVersionsRead;
import 'scene_builder_json_parse.dart';
import 'scene_builder_json_require.dart';

typedef DecodedSceneMetadata = ({
  CameraSnapshotBacking camera,
  BackgroundSnapshotBacking background,
  ScenePaletteSnapshotBacking palette,
});

void sceneBuilderRequireSupportedSchemaVersion(Map<String, Object?> json) {
  final version = sceneBuilderRequireValidatedField(
    json,
    'schemaVersion',
    parse: (value, {required path, required fieldName}) =>
        validatedRequireJsonInt(
          value,
          path: path,
          fieldName: fieldName,
          allowZero: false,
        ),
  );
  if (sceneSchemaVersionsRead.contains(version)) {
    return;
  }
  final expectedVersions = sceneSchemaVersionsRead.toList()
    ..sort((int a, int b) => a.compareTo(b));
  final expectedVersionsMessage = expectedVersions.join(', ');
  throw SceneDataException(
    code: SceneDataErrorCode.unsupportedSchemaVersion,
    path: 'schemaVersion',
    message:
        'Unsupported schemaVersion: $version. Expected one of: [$expectedVersionsMessage].',
  );
}

DecodedSceneMetadata sceneBuilderDecodeSceneMetadata(
  Map<String, Object?> json,
) {
  return (
    camera: _decodeCameraSnapshot(json),
    background: _decodeBackgroundSnapshot(json),
    palette: _decodePaletteSnapshot(json),
  );
}

CameraSnapshotBacking _decodeCameraSnapshot(Map<String, Object?> json) {
  final cameraJson = sceneBuilderRequireMap(json, 'camera');
  final offsetX = _decodeRequiredDoubleField(
    sceneBuilderRequireField(cameraJson, 'offsetX', pathPrefix: 'camera'),
    path: 'camera.offsetX',
    fieldName: 'offsetX',
  );
  final offsetY = _decodeRequiredDoubleField(
    sceneBuilderRequireField(cameraJson, 'offsetY', pathPrefix: 'camera'),
    path: 'camera.offsetY',
    fieldName: 'offsetY',
  );
  _validateDecodedCoordinate(offsetX, path: 'camera.offsetX');
  _validateDecodedCoordinate(offsetY, path: 'camera.offsetY');
  return CameraSnapshotBacking(offset: Offset(offsetX, offsetY));
}

BackgroundSnapshotBacking _decodeBackgroundSnapshot(Map<String, Object?> json) {
  final backgroundJson = sceneBuilderRequireMap(json, 'background');
  return BackgroundSnapshotBacking(
    color: _decodeBackgroundColor(backgroundJson),
    grid: _decodeBackgroundGrid(backgroundJson),
  );
}

Color _decodeBackgroundColor(Map<String, Object?> backgroundJson) {
  return sceneBuilderParseColor(
    sceneBuilderRequireTypedField<String>(
      backgroundJson,
      'color',
      pathPrefix: 'background',
      typeLabel: 'string',
    ),
    path: 'background.color',
  );
}

GridSnapshotBacking _decodeBackgroundGrid(Map<String, Object?> backgroundJson) {
  final gridJson = sceneBuilderRequireMap(
    backgroundJson,
    'grid',
    pathPrefix: 'background',
  );
  final isEnabled = sceneBuilderRequireTypedField<bool>(
    gridJson,
    'enabled',
    pathPrefix: 'background.grid',
    typeLabel: 'bool',
  );
  final cellSize = _decodeRequiredDoubleField(
    sceneBuilderRequireField(
      gridJson,
      'cellSize',
      pathPrefix: 'background.grid',
    ),
    path: 'background.grid.cellSize',
    fieldName: 'cellSize',
  );
  _validateDecodedPositiveBoundedSize(
    cellSize,
    path: 'background.grid.cellSize',
  );
  if (isEnabled) {
    final message = sceneEnabledGridCellSizeViolationMessage(cellSize);
    if (message != null) {
      throw SceneDataException.boundary(
        code: SceneDataErrorCode.invalidValue,
        path: 'background.grid.cellSize',
        message:
            'Field background.grid.cellSize must be >= $kMinGridCellSize when background.grid.enabled is true.',
        source: cellSize,
      );
    }
  }
  return GridSnapshotBacking(
    isEnabled: isEnabled,
    cellSize: cellSize,
    color: sceneBuilderParseColor(
      sceneBuilderRequireTypedField<String>(
        gridJson,
        'color',
        pathPrefix: 'background.grid',
        typeLabel: 'string',
      ),
      path: 'background.grid.color',
    ),
  );
}

ScenePaletteSnapshotBacking _decodePaletteSnapshot(Map<String, Object?> json) {
  final paletteJson = sceneBuilderRequireMap(json, 'palette');
  return ScenePaletteSnapshotBacking(
    penColors: _decodePaletteColors(
      paletteJson,
      key: 'penColors',
      pathPrefix: 'palette',
    ),
    backgroundColors: _decodePaletteColors(
      paletteJson,
      key: 'backgroundColors',
      pathPrefix: 'palette',
    ),
    gridSizes: _decodePaletteGridSizes(paletteJson),
  );
}

List<Color> _decodePaletteColors(
  Map<String, Object?> paletteJson, {
  required String key,
  required String pathPrefix,
}) {
  final colorsJson = sceneBuilderRequireList(
    paletteJson,
    key,
    pathPrefix: pathPrefix,
  );
  final colorsPath = sceneBuilderPathAt(pathPrefix, key);
  final limitMessage = scenePaletteItemCountViolationMessage(colorsJson.length);
  if (limitMessage != null) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: colorsPath,
      message: 'Field $colorsPath $limitMessage',
      source: colorsJson.length,
    );
  }
  if (sceneNonEmptyListViolationMessage(colorsJson) != null) {
    throw SceneDataException.fieldMustNotBeEmpty(
      path: colorsPath,
      source: colorsJson,
    );
  }
  final colors = <Color>[];
  for (var i = 0; i < colorsJson.length; i++) {
    final path = sceneBuilderPathAt(colorsPath, '[$i]');
    final value = sceneBuilderRequireStringValue(
      colorsJson[i],
      field: key,
      path: path,
    );
    colors.add(sceneBuilderParseColor(value, path: path));
  }
  return colors;
}

List<double> _decodePaletteGridSizes(Map<String, Object?> paletteJson) {
  final gridSizesJson = sceneBuilderRequireList(
    paletteJson,
    'gridSizes',
    pathPrefix: 'palette',
  );
  const gridSizesField = 'gridSizes';
  const gridSizesPath = 'palette.gridSizes';
  final limitMessage = scenePaletteItemCountViolationMessage(
    gridSizesJson.length,
  );
  if (limitMessage != null) {
    throw SceneDataException(
      code: SceneDataErrorCode.invalidValue,
      path: gridSizesPath,
      message: 'Field $gridSizesPath $limitMessage',
      source: gridSizesJson.length,
    );
  }
  if (sceneNonEmptyListViolationMessage(gridSizesJson) != null) {
    throw SceneDataException.fieldMustNotBeEmpty(
      path: gridSizesPath,
      source: gridSizesJson,
    );
  }
  final gridSizes = <double>[];
  for (var i = 0; i < gridSizesJson.length; i++) {
    final path = sceneBuilderPathAt(gridSizesPath, '[$i]');
    final value = sceneBuilderRequireDoubleValue(
      gridSizesJson[i],
      field: gridSizesField,
      path: path,
    );
    _validateDecodedPositiveBoundedSize(value, path: path);
    gridSizes.add(value);
  }
  return gridSizes;
}

double _decodeRequiredDoubleField(
  Object? raw, {
  required String path,
  required String fieldName,
}) {
  if (raw is! num) {
    throw SceneDataException.invalidFieldType(
      path: path,
      fieldName: fieldName,
      expected: 'number',
      source: raw,
    );
  }
  return raw.toDouble();
}

void _validateDecodedCoordinate(double value, {required String path}) {
  final message = sceneCoordinateViolationMessage(value);
  if (message == null) {
    return;
  }
  if (!value.isFinite) {
    throw SceneDataException.fieldMustBeFinite(
      path: path,
      fieldName: path.split('.').last,
      source: value,
    );
  }
  throw SceneDataException.outOfRange(
    path: path,
    min: sceneCoordMin,
    max: sceneCoordMax,
    source: value,
  );
}

void _validateDecodedPositiveBoundedSize(double value, {required String path}) {
  final message = scenePositiveBoundedSizeViolationMessage(value);
  if (message == null) {
    return;
  }
  if (!value.isFinite) {
    throw SceneDataException.fieldMustBeFinite(
      path: path,
      fieldName: path.split('.').last,
      source: value,
    );
  }
  if (value <= 0) {
    throw SceneDataException.fieldMustBeGreaterThan(
      path: path,
      limit: 0,
      source: value,
    );
  }
  throw SceneDataException.outOfRange(
    path: path,
    min: 0,
    max: sceneSizeMax,
    source: value,
  );
}
