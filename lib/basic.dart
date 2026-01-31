/// Basic public API exports for `iwb_canvas_engine`.
///
/// This entrypoint is intended for the common "happy path" integration:
/// - Build and mutate a [Scene] via [SceneController]
/// - Render and handle input via [SceneView]
/// - Persist via JSON codec helpers
///
/// Low-level building blocks (custom painting, hit testing, pointer tracking,
/// etc.) are intentionally omitted. For the full API, import
/// `package:iwb_canvas_engine/advanced.dart`.
library;

// Model.
export 'core/defaults.dart';
export 'core/geometry.dart';
export 'core/nodes.dart';
export 'core/scene.dart';

// Integration.
export 'input/action_events.dart';
export 'input/scene_controller.dart';
export 'view/scene_view.dart';

// JSON.
export 'serialization/scene_codec.dart'
    show
        SceneJsonFormatException,
        decodeSceneFromJson,
        encodeSceneToJson,
        schemaVersion;

// Types needed to use the widget API.
export 'render/scene_painter.dart' show ImageResolver;
