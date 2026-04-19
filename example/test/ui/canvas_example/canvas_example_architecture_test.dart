import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// INV:INV-G-PUBLIC-ENTRYPOINTS

void main() {
  test('example source keeps feature ownership boundaries locked', () {
    final libRoot = Directory('${Directory.current.path}/lib');
    final files = libRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    final allowedByToken = <String, Set<String>>{
      'SceneController(': <String>{
        'lib/ui/canvas_example/view_models/canvas_example_view_model.dart',
      },
      'controller.scene': <String>{
        'lib/ui/canvas_example/view_models/canvas_example_view_model.dart',
      },
      'controller.selection': <String>{
        'lib/ui/canvas_example/view_models/canvas_example_view_model.dart',
      },
      'controller.interaction': <String>{
        'lib/ui/canvas_example/view_models/canvas_example_view_model.dart',
      },
      'encodeSceneToJson': <String>{
        'lib/ui/canvas_example/view_models/canvas_example_view_model.dart',
      },
      'decodeSceneFromJson': <String>{
        'lib/ui/canvas_example/view_models/canvas_example_view_model.dart',
      },
      'RectNodeSpec': <String>{
        'lib/ui/canvas_example/view_models/canvas_example_view_model.dart',
      },
      'TextNodeSpec': <String>{
        'lib/ui/canvas_example/view_models/canvas_example_view_model.dart',
      },
      'ImageNodeSpec': <String>{
        'lib/ui/canvas_example/view_models/canvas_example_view_model.dart',
      },
      'TextNodePatch': <String>{
        'lib/ui/canvas_example/view_models/canvas_example_view_model.dart',
      },
      'rootBundle.load': <String>{
        'lib/data/services/sample_image_asset_service.dart',
      },
      'instantiateImageCodec': <String>{
        'lib/data/services/sample_image_asset_service.dart',
      },
      'SceneView(': <String>{
        'lib/ui/canvas_example/widgets/canvas_scene_surface.dart',
      },
    };

    final violations = <String>[];
    for (final file in files) {
      final relativePath = file.path.replaceFirst(
        '${Directory.current.path}/',
        '',
      );
      final content = file.readAsStringSync();
      for (final entry in allowedByToken.entries) {
        if (!content.contains(entry.key)) {
          continue;
        }
        if (entry.value.contains(relativePath)) {
          continue;
        }
        violations.add('$relativePath contains ${entry.key}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Feature ownership drifted back into main.dart, widgets, or service-unowned code.',
    );
  });
}
