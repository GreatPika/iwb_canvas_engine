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
export 'src/core/defaults.dart';
export 'src/core/geometry.dart';
export 'src/core/nodes.dart';
export 'src/core/scene.dart';
export 'src/core/transform2d.dart';

// Integration.
export 'src/input/action_events.dart';
export 'src/input/pointer_input.dart' show PointerInputSettings;
export 'src/input/scene_controller.dart';
export 'src/view/scene_view.dart';

// JSON.
export 'src/serialization/scene_codec.dart'
    show
        SceneJsonFormatException,
        decodeSceneFromJson,
        encodeSceneToJson,
        schemaVersionWrite,
        schemaVersionsRead;

// Types needed to use the widget API.
export 'src/render/scene_painter.dart'
    show
        ImageResolver,
        SceneStaticLayerCache,
        SceneTextLayoutCache,
        SceneStrokePathCache;
