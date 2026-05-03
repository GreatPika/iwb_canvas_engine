import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/scene_contract_limits.dart';
import 'package:iwb_canvas_engine/src/contract/scene_data_exception.dart';
import 'package:iwb_canvas_engine/src/contract/internal/snapshot_fast_path.dart';
import 'package:iwb_canvas_engine/src/contract/scene_validation_diagnostics.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/core/scene_limits.dart'
    show sceneThicknessMax;
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/model/scene_value_validation.dart';
import 'package:iwb_canvas_engine/src/model/scene_value_validation_node.dart'
    as node_validation;
import 'package:iwb_canvas_engine/src/model/scene_value_validation_scene.dart'
    as scene_value_validation_scene;
import 'package:iwb_canvas_engine/src/model/scene_value_validation_palette_grid.dart'
    show
        sceneValidateCameraOffsetValue,
        sceneValidateGridCellSizeValue,
        sceneValidatePaletteFields;
import 'package:iwb_canvas_engine/src/model/scene_value_validation_support.dart'
    show sceneMessageFromArgumentError, sceneValidateArgumentBoundary;

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
      'stroke runtime snapshot and backing validators share thickness range',
      () {
        final oversizedThickness = sceneThicknessMax + 1;

        expect(
          () => sceneValidateNode(
            _RawStrokeNode(
              id: 'stroke-runtime',
              rawPoints: const <Offset>[Offset(0, 0), Offset(1, 1)],
              rawThickness: oversizedThickness,
            ),
            field: 'node',
            onError: _throwFailure,
          ),
          throwsA(_outOfRangeFailure('node.thickness', oversizedThickness)),
        );

        expect(
          () => sceneValidateNodeSnapshot(
            StrokeNodeSnapshot(
              id: 'stroke-snapshot',
              points: const <Offset>[Offset(0, 0), Offset(1, 1)],
              thickness: oversizedThickness,
              color: const Color(0xFF000000),
            ),
            field: 'node',
            onError: _throwFailure,
          ),
          throwsA(_outOfRangeFailure('node.thickness', oversizedThickness)),
        );

        expect(
          () => node_validation.sceneValidateNodeSnapshotBacking(
            StrokeNodeSnapshotBacking(
              id: 'stroke-backing',
              points: const <Offset>[Offset(0, 0), Offset(1, 1)],
              thickness: oversizedThickness,
              color: const Color(0xFF000000),
            ),
            field: 'node',
            onError: _throwFailure,
          ),
          throwsA(_outOfRangeFailure('node.thickness', oversizedThickness)),
        );
      },
    );

    test('adjacent vector width validators keep their range contracts', () {
      final oversizedThickness = sceneThicknessMax + 1;

      expect(
        () => sceneValidateNode(
          _RawLineNode(
            id: 'line-runtime',
            rawStart: const Offset(0, 0),
            rawEnd: const Offset(1, 1),
            rawThickness: oversizedThickness,
          ),
          field: 'node',
          onError: _throwFailure,
        ),
        throwsA(_outOfRangeFailure('node.thickness', oversizedThickness)),
      );

      expect(
        () => sceneValidateNode(
          _RawRectNode(
            id: 'rect-runtime',
            transform: Transform2D.identity,
            hitPadding: 0,
            opacity: 1,
            size: const Size(10, 10),
            strokeWidth: oversizedThickness,
          ),
          field: 'node',
          onError: _throwFailure,
        ),
        throwsA(_outOfRangeFailure('node.strokeWidth', oversizedThickness)),
      );

      expect(
        () => sceneValidateNode(
          _RawPathNode(strokeWidth: oversizedThickness),
          field: 'node',
          onError: _throwFailure,
        ),
        throwsA(_outOfRangeFailure('node.strokeWidth', oversizedThickness)),
      );
    });

    test(
      'sceneValidateNode keeps line runtime field paths after family split',
      () {
        expect(
          () => sceneValidateNode(
            _RawLineNode(
              id: 'line-0',
              rawStart: const Offset(double.infinity, 0),
              rawEnd: const Offset(1, 1),
              rawThickness: 1,
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
      'sceneValidateNodeSnapshot keeps canonical snapshot field paths for out-of-range coordinates',
      () {
        expect(
          () => sceneValidateNodeSnapshot(
            LineNodeSnapshot(
              id: 'line-range',
              start: Offset(sceneCoordMax + 1, 0),
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
                  error.field == 'node.start.x' &&
                  error.diagnostic?.template == 'outOfRange' &&
                  error.diagnostic?.args['min'] == -sceneCoordMax &&
                  error.diagnostic?.args['max'] == sceneCoordMax,
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
      'sceneCollectRuntimeSceneValidityViolations collects canonical runtime scene failures',
      () {
        final scene = Scene(
          camera: Camera(offset: const Offset(1, 2)),
          background: Background(
            grid: _RawGridSettings(isEnabled: true, cellSize: 0.5),
          ),
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-a',
              nodes: <SceneNode>[
                _RawRectNode(
                  id: 'dup',
                  transform: const Transform2D(
                    a: double.infinity,
                    b: 0,
                    c: 0,
                    d: 1,
                    tx: 0,
                    ty: 0,
                  ),
                  hitPadding: 0,
                  opacity: 1,
                  size: const Size(4, 5),
                  strokeWidth: 0,
                ),
              ],
            ),
            ContentLayer(
              id: 'layer-a',
              nodes: <SceneNode>[RectNode(id: 'dup', size: const Size(6, 7))],
            ),
          ],
        );
        final violations = sceneCollectRuntimeSceneValidityViolations(scene);

        expect(
          violations,
          contains('layers[1].id must be unique across content layers.'),
        );
        expect(
          violations,
          contains('layers[1].nodes[0].id Must be unique across scene layers.'),
        );
        expect(
          violations,
          contains(
            'background.grid.cellSize must be >= 1.0 when background.grid.enabled is true.',
          ),
        );
        expect(
          violations,
          contains('layers[0].nodes[0].transform.a must be finite.'),
        );
      },
    );

    test('sceneValidateSceneValues rejects blank runtime layer id', () {
      expect(
        () => sceneValidateSceneValues(
          Scene(
            layers: <ContentLayer>[ContentLayer(id: '', nodes: <SceneNode>[])],
          ),
          onError: _throwFailure,
          requirePositiveGridCellSize: true,
          requireEnabledMinGridCellSize: true,
        ),
        throwsA(
          predicate(
            (error) =>
                error is _ValidationFailure &&
                error.field == 'layers[0].id' &&
                error.message == 'Field layers[0].id must not be empty.',
          ),
        ),
      );
    });

    test('sceneCollectRuntimeSceneValueViolations skips runtime layer ids', () {
      final scene = Scene(
        layers: <ContentLayer>[ContentLayer(id: '', nodes: <SceneNode>[])],
      );

      final violations = scene_value_validation_scene
          .sceneCollectRuntimeSceneValueViolations(
            scene,
            requirePositiveGridCellSize: true,
            requireEnabledMinGridCellSize: true,
          );

      expect(violations, isNot(contains('layers[0].id must not be empty.')));
    });

    test(
      'sceneCollectRuntimeSceneValidityViolations rejects blank runtime layer id',
      () {
        final scene = Scene(
          layers: <ContentLayer>[ContentLayer(id: '', nodes: <SceneNode>[])],
        );

        final violations = sceneCollectRuntimeSceneValidityViolations(scene);
        final layerIdViolations = violations
            .where((message) => message == 'layers[0].id must not be empty.')
            .toList();

        expect(violations, contains('layers[0].id must not be empty.'));
        expect(layerIdViolations, hasLength(1));
      },
    );

    test(
      'sceneCollectRuntimeStructuralSurfaceViolations includes runtime layer ids',
      () {
        final scene = Scene(
          layers: <ContentLayer>[ContentLayer(id: '', nodes: <SceneNode>[])],
        );

        final violations = sceneCollectRuntimeStructuralSurfaceViolations(
          scene,
        );

        expect(violations, contains('layers[0].id must not be empty.'));
      },
    );

    test(
      'sceneCollectRuntimeSceneValidityViolations reports invalid runtime node id once',
      () {
        final scene = Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-a',
              nodes: <SceneNode>[RectNode(id: '', size: const Size(4, 5))],
            ),
          ],
        );

        final violations = sceneCollectRuntimeSceneValidityViolations(scene);
        final nodeIdViolations = violations
            .where(
              (message) =>
                  message == 'layers[0].nodes[0].id must not be empty.',
            )
            .toList();

        expect(nodeIdViolations, hasLength(1));
      },
    );

    test(
      'sceneCollectRuntimeSceneValidityViolations collects every structural violation',
      () {
        final scene = Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-a',
              nodes: <SceneNode>[
                RectNode(id: 'dup-node', size: const Size(4, 5)),
              ],
            ),
            ContentLayer(
              id: 'layer-a',
              nodes: <SceneNode>[
                RectNode(id: 'dup-node', size: const Size(6, 7)),
              ],
            ),
          ],
        );

        final violations = sceneCollectRuntimeSceneValidityViolations(scene);

        expect(
          violations,
          containsAll(<String>[
            'layers[1].id must be unique across content layers.',
            'layers[1].nodes[0].id Must be unique across scene layers.',
          ]),
        );
      },
    );

    test(
      'sceneCollectRuntimeSceneValidityViolations reports max-node overflow once across layers',
      () {
        final scene = Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-a',
              nodes: <SceneNode>[
                for (var index = 0; index < kMaxNodesPerScene; index++)
                  RectNode(id: 'node-$index', size: const Size(4, 5)),
              ],
            ),
            ContentLayer(
              id: 'layer-b',
              nodes: <SceneNode>[
                RectNode(id: 'node-overflow', size: const Size(6, 7)),
                RectNode(id: 'node-overflow-2', size: const Size(8, 9)),
              ],
            ),
          ],
        );

        final violations = sceneCollectRuntimeSceneValidityViolations(scene);
        final overflowViolations = violations
            .where(
              (message) => message.contains(
                'Scene must contain at most $kMaxNodesPerScene nodes.',
              ),
            )
            .toList();

        expect(overflowViolations, hasLength(1));
      },
    );

    test(
      'sceneCollectRuntimeSceneValidityViolations keeps canonical first failure per step',
      () {
        final scene = Scene(
          palette: _RawScenePalette(
            penColors: const <Color>[],
            backgroundColors: const <Color>[],
            gridSizes: const <double>[0, double.infinity],
          ),
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-a',
              nodes: <SceneNode>[
                _RawRectNode(
                  id: 'bad-rect',
                  transform: const Transform2D(
                    a: 0,
                    b: 0,
                    c: 0,
                    d: 0,
                    tx: 0,
                    ty: 0,
                  ),
                  hitPadding: -1,
                  opacity: 2,
                  size: const Size(-2, -3),
                  strokeWidth: -4,
                ),
              ],
            ),
          ],
        );

        final violations = sceneCollectRuntimeSceneValidityViolations(scene);

        expect(violations, contains('palette.penColors must not be empty.'));
        expect(
          violations,
          contains(
            'layers[0].nodes[0].transform must be invertible (non-singular).',
          ),
        );
        expect(
          violations,
          isNot(contains('palette.backgroundColors must not be empty.')),
        );
        expect(
          violations,
          isNot(contains('layers[0].nodes[0].hitPadding must be >= 0.')),
        );
      },
    );

    test(
      'sceneCollectRuntimeSceneValidityViolations rejects mismatched runtime node subtype',
      () {
        final scene = Scene(
          layers: <ContentLayer>[
            ContentLayer(
              id: 'layer-a',
              nodes: <SceneNode>[_MismatchedRectTypeNode(id: 'bad-node')],
            ),
          ],
        );
        final violations = sceneCollectRuntimeSceneValidityViolations(scene);

        expect(
          violations,
          contains(
            'layers[0].nodes[0].type must match the concrete runtime node subtype for rect.',
          ),
        );
      },
    );

    test(
      'sceneCollectRuntimePaletteViolations reports canonical palette failures',
      () {
        final violations = sceneCollectRuntimePaletteViolations(
          _RawScenePalette(
            penColors: const <Color>[],
            backgroundColors: const <Color>[Color(0xFFFFFFFF)],
            gridSizes: const <double>[16],
          ),
        );

        expect(violations, contains('palette.penColors must not be empty.'));
      },
    );

    test('sceneValidateCameraOffsetValue rejects non-finite offsets', () {
      expect(
        () => sceneValidateCameraOffsetValue(
          const Offset(double.infinity, 0),
          field: 'camera.offset',
          onError: _throwFailure,
        ),
        throwsA(
          predicate(
            (error) =>
                error is _ValidationFailure &&
                error.field == 'camera.offset.dx' &&
                error.message == 'Field camera.offset.dx must be finite.',
          ),
        ),
      );
    });

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

Matcher _outOfRangeFailure(String field, double value) {
  return predicate(
    (error) =>
        error is _ValidationFailure &&
        error.field == field &&
        error.diagnostic?.template == 'outOfRange' &&
        error.diagnostic?.args['min'] == 0 &&
        error.diagnostic?.args['max'] == sceneThicknessMax &&
        error.value == value,
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

final class _RawGridSettings extends GridSettings {
  _RawGridSettings({required bool isEnabled, required double cellSize})
    : _isEnabled = isEnabled,
      _cellSize = cellSize,
      super();

  final bool _isEnabled;
  final double _cellSize;

  @override
  bool get isEnabled => _isEnabled;

  @override
  double get cellSize => _cellSize;
}

final class _RawScenePalette extends ScenePalette {
  _RawScenePalette({
    required List<Color> penColors,
    required List<Color> backgroundColors,
    required List<double> gridSizes,
  }) : _penColors = penColors,
       _backgroundColors = backgroundColors,
       _gridSizes = gridSizes,
       super();

  final List<Color> _penColors;
  final List<Color> _backgroundColors;
  final List<double> _gridSizes;

  @override
  List<Color> get penColors => _penColors;

  @override
  List<Color> get backgroundColors => _backgroundColors;

  @override
  List<double> get gridSizes => _gridSizes;
}

final class _RawRectNode extends RectNode {
  _RawRectNode({
    required super.id,
    required Transform2D transform,
    required double hitPadding,
    required double opacity,
    required Size size,
    required double strokeWidth,
  }) : _transform = transform,
       _hitPadding = hitPadding,
       _opacity = opacity,
       _size = size,
       _strokeWidth = strokeWidth,
       super(size: const Size(1, 1));

  final Transform2D _transform;
  final double _hitPadding;
  final double _opacity;
  final Size _size;
  final double _strokeWidth;

  @override
  Transform2D get transform => _transform;

  @override
  double get hitPadding => _hitPadding;

  @override
  double get opacity => _opacity;

  @override
  Size get size => _size;

  @override
  double get strokeWidth => _strokeWidth;
}

final class _RawLineNode extends LineNode {
  _RawLineNode({
    required super.id,
    required Offset rawStart,
    required Offset rawEnd,
    required double rawThickness,
  }) : _rawStart = rawStart,
       _rawEnd = rawEnd,
       _rawThickness = rawThickness,
       super(
         start: const Offset(0, 0),
         end: const Offset(1, 1),
         thickness: 1,
         color: const Color(0xFF000000),
       );

  final Offset _rawStart;
  final Offset _rawEnd;
  final double _rawThickness;

  @override
  Offset get start => _rawStart;

  @override
  Offset get end => _rawEnd;

  @override
  double get thickness => _rawThickness;
}

final class _RawStrokeNode extends StrokeNode {
  _RawStrokeNode({
    required super.id,
    required List<Offset> rawPoints,
    required double rawThickness,
  }) : _rawPoints = rawPoints,
       _rawThickness = rawThickness,
       super(
         points: const <Offset>[Offset(0, 0), Offset(1, 1)],
         thickness: 1,
         color: const Color(0xFF000000),
       );

  final List<Offset> _rawPoints;
  final double _rawThickness;

  @override
  List<Offset> get points => _rawPoints;

  @override
  double get thickness => _rawThickness;
}

final class _RawPathNode extends PathNode {
  _RawPathNode({required double strokeWidth})
    : _rawStrokeWidth = strokeWidth,
      super(id: 'path-runtime', svgPathData: 'M0 0 L1 1', strokeWidth: 1);

  final double _rawStrokeWidth;

  @override
  double get strokeWidth => _rawStrokeWidth;
}

final class _MismatchedRectTypeNode extends SceneNode {
  _MismatchedRectTypeNode({required super.id}) : super(type: NodeType.rect);

  @override
  Rect get localBounds => Rect.zero;
}
