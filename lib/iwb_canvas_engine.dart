/// Public API exports for `iwb_canvas_engine`.
///
/// This is the primary v2 entrypoint and recommended default import.
library;

export 'src/public/node_patch.dart';
export 'src/public/node_spec.dart';
export 'src/public/patch_field.dart';
export 'src/public/canvas_pointer_input.dart';
export 'src/public/scene_builder.dart';
export 'src/public/scene_data_exception.dart';
export 'src/public/scene_render_state.dart';
export 'src/public/scene_write_txn.dart';
export 'src/public/snapshot.dart';
export 'src/core/action_events.dart';
export 'src/core/interaction_types.dart';
export 'src/core/pointer_input.dart' show PointerInputSettings;
export 'src/core/transform2d.dart' show Transform2D;
export 'src/interactive/scene_controller_interactive.dart';
export 'src/view/scene_view_interactive.dart';
export 'src/serialization/scene_codec.dart'
    show
        decodeScene,
        decodeSceneFromJson,
        encodeScene,
        encodeSceneToJson,
        schemaVersionWrite,
        schemaVersionsRead;
