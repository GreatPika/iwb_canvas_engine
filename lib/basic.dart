/// Basic public API exports for `iwb_canvas_engine`.
///
/// This is the primary v2 entrypoint and recommended default import.
library;

export 'src/v2/public/node_patch.dart';
export 'src/v2/public/node_spec.dart';
export 'src/v2/public/patch_field.dart';
export 'src/v2/public/snapshot.dart' hide NodeId;
export 'src/core/action_events.dart';
export 'src/core/defaults.dart';
export 'src/core/geometry.dart';
export 'src/core/interaction_types.dart';
export 'src/core/nodes.dart';
export 'src/core/pointer_input.dart' show PointerInputSettings;
export 'src/core/scene.dart';
export 'src/core/transform2d.dart';
export 'src/v2/interactive/scene_controller_interactive_v2.dart';
export 'src/v2/view/scene_view_interactive_v2.dart';
export 'src/v2/render/scene_painter_v2.dart'
    show
        ImageResolverV2,
        SceneStaticLayerCacheV2,
        SceneStrokePathCacheV2,
        SceneTextLayoutCacheV2,
        ScenePathMetricsCacheV2;
export 'src/v2/serialization/scene_codec.dart'
    show
        SceneJsonFormatException,
        decodeScene,
        decodeSceneFromJson,
        encodeScene,
        encodeSceneToJson,
        schemaVersionWrite,
        schemaVersionsRead;
