/// Advanced public API exports for `iwb_canvas_engine`.
///
/// This entrypoint exposes the full API surface, including low-level building
/// blocks (custom painting, hit-testing, pointer tracking).
///
/// Prefer `package:iwb_canvas_engine/basic.dart` unless you need low-level APIs.
library;

export 'src/core/defaults.dart';
export 'src/core/geometry.dart';
export 'src/core/hit_test.dart';
export 'src/core/nodes.dart';
export 'src/core/scene.dart';
export 'src/core/transform2d.dart';
export 'src/input/action_events.dart';
export 'src/input/pointer_input.dart';
export 'src/input/scene_controller.dart';
export 'src/render/scene_painter.dart';
export 'src/serialization/scene_codec.dart';
export 'src/view/scene_view.dart';
