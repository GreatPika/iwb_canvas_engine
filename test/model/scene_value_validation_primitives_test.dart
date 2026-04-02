import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contract/snapshot.dart';
import 'package:iwb_canvas_engine/src/core/nodes.dart';
import 'package:iwb_canvas_engine/src/core/scene.dart';
import 'package:iwb_canvas_engine/src/contract/transform2d.dart';
import 'package:iwb_canvas_engine/src/model/scene_value_validation.dart';

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
                error.message == 'must be >= 0.' &&
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
                error.message == 'must be > 0.' &&
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
                error.message == 'must not be empty.',
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
                error.message == 'must be valid SVG path data.',
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
                error.message == 'must be within [0,1].' &&
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
              pointsRevision: 0,
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
                  error.message == 'must be finite.' &&
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
            const GridSnapshot(cellSize: 16),
            field: 'gridSnapshot',
            onError: _throwFailure,
            requirePositiveCellSize: true,
          );
          sceneValidateGrid(
            GridSettings(cellSize: 16),
            field: 'grid',
            onError: _throwFailure,
            requirePositiveCellSize: true,
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
          );
        }, returnsNormally);
      },
    );
  });
}

Never _throwFailure({
  required Object? value,
  required String field,
  required String message,
}) {
  throw _ValidationFailure(value: value, field: field, message: message);
}

class _ValidationFailure {
  _ValidationFailure({
    required this.value,
    required this.field,
    required this.message,
  });

  final Object? value;
  final String field;
  final String message;
}
