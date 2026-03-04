import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

import '../core/nodes.dart';
import '../core/scene.dart';
import '../contract/transform2d.dart';
import '../contract/node_patch.dart';
import '../contract/node_spec.dart';
import '../contract/patch_field.dart';
import '../contract/snapshot.dart' hide NodeId;

part 'scene_value_validation_primitives.part.dart';
part 'scene_value_validation_palette_grid.part.dart';
part 'scene_value_validation_node.part.dart';
part 'scene_value_validation_top_level.part.dart';

typedef SceneValidationErrorReporter =
    Never Function({
      required Object? value,
      required String field,
      required String message,
    });
