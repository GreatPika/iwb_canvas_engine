import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/scene_contract_limits.dart';
import 'package:iwb_canvas_engine/src/contract/scene_data_exception.dart';
import 'package:iwb_canvas_engine/src/contract/scene_validation_diagnostics.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/model/scene_value_validation.dart';
import 'package:iwb_canvas_engine/src/model/scene_value_validation_palette_grid.dart'
    show
        sceneValidateCameraOffsetValue,
        sceneValidateGridCellSizeValue,
        sceneValidatePaletteFields;
import 'package:iwb_canvas_engine/src/model/scene_value_validation_support.dart'
    show
        sceneMessageFromArgumentError,
        sceneValidateArgumentBoundary,
        sceneValidationThrowSceneDataException;

void main() {
  group('scene value validation primitives', () {
    test('sceneValidateNonNegativeInt accepts zero and rejects negatives', () {
      sceneValidateNonNegativeInt(0, field: 'count', onError: _throwFailure);

      expect(
        () => sceneValidateNonNegativeInt(
          -1,
          field: 'count',
          onError: _throwFailure,
        ),
        throwsA(
          predicate(
            (error) =>
                error is _ValidationFailure &&
                error.field == 'count' &&
                error.diagnostic?.template == 'fieldMustBeAtLeast' &&
                error.message == 'Field count must be >= 0.' &&
                error.value == -1,
          ),
        ),
      );
    });

    test('sceneValidatePositiveInt accepts positive and rejects zero', () {
      sceneValidatePositiveInt(1, field: 'count', onError: _throwFailure);

      expect(
        () =>
            sceneValidatePositiveInt(0, field: 'count', onError: _throwFailure),
        throwsA(
          predicate(
            (error) =>
                error is _ValidationFailure &&
                error.field == 'count' &&
                error.diagnostic?.template == 'fieldMustBeGreaterThan' &&
                error.message == 'Field count must be > 0.' &&
                error.value == 0,
          ),
        ),
      );
    });

    test('sceneValidateSvgPathData reports empty and invalid values', () {
      sceneValidateSvgPathData(
        'M0 0 L1 1',
        field: 'svgPathData',
        onError: _throwFailure,
      );

      expect(
        () => sceneValidateSvgPathData(
          '   ',
          field: 'svgPathData',
          onError: _throwFailure,
        ),
        throwsA(
          predicate(
            (error) =>
                error is _ValidationFailure &&
                error.field == 'svgPathData' &&
                error.diagnostic?.template == 'fieldMustNotBeEmpty' &&
                error.message == 'Field svgPathData must not be empty.',
          ),
        ),
      );

      expect(
        () => sceneValidateSvgPathData(
          'not svg',
          field: 'svgPathData',
          onError: _throwFailure,
        ),
        throwsA(
          predicate(
            (error) =>
                error is _ValidationFailure &&
                error.field == 'svgPathData' &&
                error.diagnostic?.template == 'fieldMustBeValidSvgPathData' &&
                error.message ==
                    'Field svgPathData must be valid SVG path data.',
          ),
        ),
      );
    });

    test('sceneValidateClamped01Double accepts range and rejects overflow', () {
      sceneValidateClamped01Double(
        0.5,
        field: 'opacity',
        onError: _throwFailure,
      );

      expect(
        () => sceneValidateClamped01Double(
          1.1,
          field: 'opacity',
          onError: _throwFailure,
        ),
        throwsA(
          predicate(
            (error) =>
                error is _ValidationFailure &&
                error.field == 'opacity' &&
                error.diagnostic?.template == 'outOfRange' &&
                error.message == 'Field opacity must be within [0, 1].' &&
                error.value == 1.1,
          ),
        ),
      );
    });

    test('sceneValidateNode accepts valid text node fontFamily boundary', () {
      expect(
        () => sceneValidateNode(
          TextNode(
            id: 'node-0',
            instanceRevision: 1,
            text: 'hello',
            fontSize: 16,
            color: const Color(0xFF000000),
            fontFamily: 'Inter',
          ),
          field: 'node',
          onError: _throwFailure,
        ),
        returnsNormally,
      );
    });

    test(
      'sceneValidateNodeSnapshot accepts valid stroke snapshots after family split',
      () {
        expect(
          () => sceneValidateNodeSnapshot(
            StrokeNodeSnapshot(
              id: 'stroke-0',
              points: const <Offset>[Offset(0, 0)],
              thickness: 1,
              color: const Color(0xFF000000),
            ),
            field: 'node',
            onError: _throwFailure,
          ),
          returnsNormally,
        );
      },
    );

    test(
      'sceneValidateNode keeps line runtime field paths after family split',
      () {
        expect(
          () => sceneValidateNode(
            LineNode(
              id: 'line-0',
              start: const Offset(double.infinity, 0),
              end: const Offset(1, 1),
              thickness: 1,
              color: const Color(0xFF000000),
            ),
            field: 'node',
            onError: _throwFailure,
          ),
          throwsA(
            predicate(
              (error) =>
                  error is _ValidationFailure &&
                  error.field == 'node.localA.dx' &&
                  error.diagnostic?.template == 'fieldMustBeFinite' &&
                  error.message == 'Field node.localA.dx must be finite.' &&
                  error.value == const Offset(double.infinity, 0),
            ),
          ),
        );
      },
    );

    test(
      'facade forwards validation entrypoints to explicit owner modules',
      () {
        expect(() {
          sceneValidateFiniteDouble(
            1.5,
            field: 'finite',
            onError: _throwFailure,
          );
          sceneValidateNonNegativeDouble(
            0,
            field: 'nonNegative',
            onError: _throwFailure,
          );
          sceneValidatePositiveDouble(
            2,
            field: 'positive',
            onError: _throwFailure,
          );
          sceneValidateFiniteOffset(
            const Offset(1, 2),
            field: 'offset',
            onError: _throwFailure,
          );
          sceneValidateNonNegativeSize(
            const Size(3, 4),
            field: 'size',
            onError: _throwFailure,
          );
          sceneValidateFiniteTransform2D(
            Transform2D.identity,
            field: 'transform',
            onError: _throwFailure,
          );
          sceneValidateNonEmptyList(
            const <Object?>[1],
            field: 'items',
            onError: _throwFailure,
          );
          sceneValidatePaletteSnapshot(
            ScenePaletteSnapshot(),
            field: 'paletteSnapshot',
            onError: _throwFailure,
          );
          sceneValidatePalette(
            ScenePalette(),
            field: 'palette',
            onError: _throwFailure,
          );
          sceneValidateGridSnapshot(
            GridSnapshot(cellSize: 16),
            field: 'gridSnapshot',
            onError: _throwFailure,
            requirePositiveCellSize: true,
            requireEnabledMinCellSize: true,
          );
          sceneValidateGrid(
            GridSettings(cellSize: 16),
            field: 'grid',
            onError: _throwFailure,
            requirePositiveCellSize: true,
            requireEnabledMinCellSize: true,
          );
          sceneValidateNodeSnapshot(
            RectNodeSnapshot(id: 'snapshot-node', size: const Size(4, 5)),
            field: 'nodeSnapshot',
            onError: _throwFailure,
          );
          sceneValidateSceneValues(
            Scene(
              backgroundLayer: BackgroundLayer(),
              layers: <ContentLayer>[
                ContentLayer(
                  id: 'layer-runtime',
                  nodes: <SceneNode>[
                    RectNode(id: 'runtime-node', size: const Size(4, 5)),
                  ],
                ),
              ],
            ),
            onError: _throwFailure,
            requirePositiveGridCellSize: true,
            requireEnabledMinGridCellSize: true,
          );
        }, returnsNormally);
      },
    );

    test(
      'scene metadata helper functions distinguish finite errors from range overflow',
      () {
        expect(
          () => sceneValidateCameraOffsetValue(
            const Offset(double.infinity, 0),
            field: 'camera',
            onError: _throwFailure,
          ),
          throwsA(
            predicate(
              (error) =>
                  error is _ValidationFailure &&
                  error.field == 'camera.dx' &&
                  error.diagnostic?.template == 'fieldMustBeFinite' &&
                  error.message == 'Field camera.dx must be finite.' &&
                  error.value == double.infinity,
            ),
          ),
        );

        expect(
          () => sceneValidateCameraOffsetValue(
            Offset(sceneCoordMax + 1, 0),
            field: 'camera',
            onError: _throwFailure,
          ),
          throwsA(
            predicate(
              (error) =>
                  error is SceneDataException &&
                  error.code == SceneDataErrorCode.outOfRange &&
                  error.path == 'camera.dx',
            ),
          ),
        );

        expect(
          () => sceneValidateGridCellSizeValue(
            cellSize: double.nan,
            isEnabled: false,
            field: 'background.grid',
            onError: _throwFailure,
            requirePositiveCellSize: false,
            requireEnabledMinCellSize: false,
          ),
          throwsA(
            predicate(
              (error) =>
                  error is _ValidationFailure &&
                  error.field == 'background.grid.cellSize' &&
                  error.diagnostic?.template == 'fieldMustBeFinite' &&
                  error.message ==
                      'Field background.grid.cellSize must be finite.',
            ),
          ),
        );

        expect(
          () => sceneValidateGridCellSizeValue(
            cellSize: sceneSizeMax + 1,
            isEnabled: false,
            field: 'background.grid',
            onError: _throwFailure,
            requirePositiveCellSize: false,
            requireEnabledMinCellSize: false,
          ),
          throwsA(
            predicate(
              (error) =>
                  error is SceneDataException &&
                  error.code == SceneDataErrorCode.outOfRange &&
                  error.path == 'background.grid.cellSize',
            ),
          ),
        );

        expect(
          () => sceneValidatePaletteFields(
            penColors: const <Color>[Color(0xFF000000)],
            backgroundColors: const <Color>[Color(0xFFFFFFFF)],
            gridSizes: <double>[sceneSizeMax + 1],
            field: 'palette',
            onError: _throwFailure,
          ),
          throwsA(
            predicate(
              (error) =>
                  error is SceneDataException &&
                  error.code == SceneDataErrorCode.outOfRange &&
                  error.path == 'palette.gridSizes[0]',
            ),
          ),
        );
      },
    );

    test(
      'sceneValidateGridCellSizeValue reports non-finite values with explicit diagnostic args',
      () {
        expect(
          () => sceneValidateGridCellSizeValue(
            cellSize: double.infinity,
            isEnabled: false,
            field: 'background.grid',
            onError: _throwFailure,
            requirePositiveCellSize: false,
            requireEnabledMinCellSize: false,
          ),
          throwsA(
            predicate(
              (error) =>
                  error is _ValidationFailure &&
                  error.field == 'background.grid.cellSize' &&
                  error.diagnostic?.template == 'fieldMustBeFinite' &&
                  error.diagnostic?.args['fieldName'] ==
                      'background.grid.cellSize',
            ),
          ),
        );
      },
    );

    test(
      'sceneValidatePaletteFields reports non-finite gridSizes through positive bounded size helper',
      () {
        expect(
          () => sceneValidatePaletteFields(
            penColors: const <Color>[Color(0xFF000000)],
            backgroundColors: const <Color>[Color(0xFFFFFFFF)],
            gridSizes: const <double>[double.infinity],
            field: 'palette',
            onError: _throwFailure,
          ),
          throwsA(
            predicate(
              (error) =>
                  error is _ValidationFailure &&
                  error.field == 'palette.gridSizes[0]' &&
                  error.diagnostic?.template == 'fieldMustBeFinite' &&
                  error.diagnostic?.args['fieldName'] == 'palette.gridSizes[0]',
            ),
          ),
        );
      },
    );

    test(
      'sceneValidateArgumentBoundary lowers plain ArgumentError messages and preserves fallback field',
      () {
        expect(
          () => sceneValidateArgumentBoundary(
            field: 'fallbackField',
            value: 1,
            onError: _throwFailure,
            validate: () {
              throw ArgumentError.value(1, null, 'Must be a number.');
            },
          ),
          throwsA(
            predicate(
              (error) =>
                  error is _ValidationFailure &&
                  error.field == 'fallbackField' &&
                  error.message == 'must be a number.' &&
                  error.diagnostic == null,
            ),
          ),
        );
      },
    );

    test(
      'sceneValidationThrowSceneDataException supports diagnostic and plain-message paths',
      () {
        expect(
          () => sceneValidationThrowSceneDataException(
            value: const Transform2D(a: 1, b: 0, c: 0, d: 0, tx: 0, ty: 0),
            field: 'transform',
            diagnostic: SceneDataDiagnosticDescriptor.fieldMustBeInvertible(),
          ),
          throwsA(
            predicate(
              (error) =>
                  error is SceneDataException &&
                  error.path == 'transform' &&
                  error.details['template'] == 'fieldMustBeInvertible',
            ),
          ),
        );

        expect(
          () => sceneValidationThrowSceneDataException(
            value: 1,
            field: 'count',
            message: 'must be valid.',
          ),
          throwsA(
            predicate(
              (error) =>
                  error is SceneDataException &&
                  error.path == 'count' &&
                  error.message == 'Field count must be valid.',
            ),
          ),
        );

        final finiteFromPath = SceneDataDiagnosticDescriptor.fieldMustBeFinite()
            .toException(path: 'node.localA.dx');
        expect(finiteFromPath.path, 'node.localA.dx');
        expect(finiteFromPath.details['template'], 'fieldMustBeFinite');
        expect(finiteFromPath.details['fieldName'], 'dx');
        expect(finiteFromPath.message, 'Field dx must be finite.');

        final finiteFromIndexedPath =
            SceneDataDiagnosticDescriptor.fieldMustBeFinite().toException(
              path: 'gridSizes[0]',
            );
        expect(finiteFromIndexedPath.path, 'gridSizes[0]');
        expect(finiteFromIndexedPath.details['template'], 'fieldMustBeFinite');
        expect(finiteFromIndexedPath.details['fieldName'], 'gridSizes');
        expect(
          finiteFromIndexedPath.message,
          'Field gridSizes must be finite.',
        );
      },
    );

    test(
      'sceneMessageFromArgumentError preserves lowercase strings and default fallback',
      () {
        expect(
          sceneMessageFromArgumentError(
            ArgumentError.value(1, 'count', 'must already be lowercase.'),
          ),
          'must already be lowercase.',
        );
        expect(sceneMessageFromArgumentError(ArgumentError()), 'is invalid.');
      },
    );
  });
}

Never _throwFailure({
  required Object? value,
  required String field,
  String? message,
  SceneDataDiagnosticDescriptor? diagnostic,
}) {
  final resolvedMessage =
      diagnostic?.toException(path: field, source: value).message ??
      message ??
      'is invalid.';
  throw _ValidationFailure(
    value: value,
    field: field,
    message: resolvedMessage,
    diagnostic: diagnostic,
  );
}

class _ValidationFailure {
  _ValidationFailure({
    required this.value,
    required this.field,
    required this.message,
    required this.diagnostic,
  });

  final Object? value;
  final String field;
  final String message;
  final SceneDataDiagnosticDescriptor? diagnostic;
}
