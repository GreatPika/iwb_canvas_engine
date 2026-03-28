import 'dart:ui';

import '../contract/internal/snapshot_fast_path.dart';
import '../contract/scene_data_exception.dart';
import '../contract/validated/validated_value_support.dart';
import '../core/scene_limits.dart';
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
    ..sort((a, b) => a.compareTo(b));
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
  return cameraSnapshotBackingFromValidated(
    offset: Offset(
      validatedRequireJsonFiniteDouble(
        sceneBuilderRequireField(cameraJson, 'offsetX', pathPrefix: 'camera'),
        path: 'camera.offsetX',
        fieldName: 'offsetX',
      ),
      validatedRequireJsonFiniteDouble(
        sceneBuilderRequireField(cameraJson, 'offsetY', pathPrefix: 'camera'),
        path: 'camera.offsetY',
        fieldName: 'offsetY',
      ),
    ),
  );
}

BackgroundSnapshotBacking _decodeBackgroundSnapshot(Map<String, Object?> json) {
  final backgroundJson = sceneBuilderRequireMap(json, 'background');
  return backgroundSnapshotBackingFromValidated(
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
  return gridSnapshotBackingFromValidated(
    isEnabled: sceneBuilderRequireTypedField<bool>(
      gridJson,
      'enabled',
      pathPrefix: 'background.grid',
      typeLabel: 'bool',
    ),
    cellSize: validatedRequireJsonFiniteDouble(
      sceneBuilderRequireField(
        gridJson,
        'cellSize',
        pathPrefix: 'background.grid',
      ),
      path: 'background.grid.cellSize',
      fieldName: 'cellSize',
    ),
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
  return scenePaletteSnapshotBackingFromValidated(
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
    maxLength: kMaxPaletteItems,
  );
  final colorsPath = sceneBuilderPathAt(pathPrefix, key);
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
    maxLength: kMaxPaletteItems,
  );
  const gridSizesField = 'gridSizes';
  const gridSizesPath = 'palette.gridSizes';
  final gridSizes = <double>[];
  for (var i = 0; i < gridSizesJson.length; i++) {
    final path = sceneBuilderPathAt(gridSizesPath, '[$i]');
    gridSizes.add(
      sceneBuilderRequireDoubleValue(
        gridSizesJson[i],
        field: gridSizesField,
        path: path,
      ),
    );
  }
  return gridSizes;
}
