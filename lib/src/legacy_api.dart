/// Internal legacy barrel for repository tests and migration tooling only.
///
/// Do not use from external package consumers.
library;

export 'core/defaults.dart';
export 'core/geometry.dart';
export 'core/hit_test.dart' hide nodeHitTestCandidateBoundsWorld;
export 'core/nodes.dart';
export 'core/scene.dart';
export 'core/transform2d.dart';
export 'input/action_events.dart';
export 'input/pointer_input.dart';
export 'input/scene_controller.dart';
export 'render/scene_painter.dart';
export 'serialization/scene_codec.dart';
export 'view/scene_view.dart';
