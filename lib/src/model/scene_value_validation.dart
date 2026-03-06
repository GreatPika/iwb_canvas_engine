import 'dart:ui';

import '../core/nodes.dart';
import '../core/scene.dart';
import '../contract/transform2d.dart';
import '../contract/snapshot.dart';
import '../contract/validated/finite_offset_value.dart';
import '../contract/validated/font_family_value.dart';
import '../contract/validated/image_id_value.dart';
import '../contract/validated/instance_revision_value.dart';
import '../contract/validated/layer_id_value.dart';
import '../contract/validated/node_id_value.dart';
import '../contract/validated/non_negative_finite_double_value.dart';
import '../contract/validated/opacity_value.dart';
import '../contract/validated/positive_finite_double_value.dart';
import '../contract/validated/svg_path_data_value.dart';
import '../contract/validated/text_content_value.dart';
import '../contract/validated/validated_value_support.dart';

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
