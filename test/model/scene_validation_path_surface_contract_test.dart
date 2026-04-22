import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/model/scene_validation_path_surface.dart';

void main() {
  // INV:INV-SER-IMPORT-DIAGNOSTIC-SURFACE
  test(
    'path surface maps alias-bearing and identity fields through one owner',
    () {
      expect(
        sceneValidationLineStartField(
          SceneValidationPathSurface.snapshot,
          field: 'layers[0].nodes[0]',
        ),
        'layers[0].nodes[0].start',
      );
      expect(
        sceneValidationLineStartField(
          SceneValidationPathSurface.jsonImport,
          field: 'layers[0].nodes[0]',
        ),
        'layers[0].nodes[0].localA',
      );
      expect(
        sceneValidationLineEndField(
          SceneValidationPathSurface.snapshot,
          field: 'layers[0].nodes[0]',
        ),
        'layers[0].nodes[0].end',
      );
      expect(
        sceneValidationLineEndField(
          SceneValidationPathSurface.jsonImport,
          field: 'layers[0].nodes[0]',
        ),
        'layers[0].nodes[0].localB',
      );
      expect(
        sceneValidationStrokePointsField(
          SceneValidationPathSurface.snapshot,
          field: 'layers[0].nodes[0]',
        ),
        'layers[0].nodes[0].points',
      );
      expect(
        sceneValidationStrokePointsField(
          SceneValidationPathSurface.jsonImport,
          field: 'layers[0].nodes[0]',
        ),
        'layers[0].nodes[0].localPoints',
      );
      expect(
        sceneValidationIdentityField(
          SceneValidationPathSurface.snapshot,
          field: 'layers[0].nodes[0]',
          child: 'opacity',
        ),
        'layers[0].nodes[0].opacity',
      );
      expect(
        sceneValidationIdentityField(
          SceneValidationPathSurface.jsonImport,
          field: 'layers[0].nodes[0]',
          child: 'size',
        ),
        'layers[0].nodes[0].size',
      );
    },
  );
}
