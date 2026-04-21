/// Public API exports for `iwb_canvas_engine`.
///
/// This is the primary public entrypoint and recommended default import.
library;

export 'src/contract/node_patch.dart';
export 'src/contract/node_spec.dart';
export 'src/contract/patch_field.dart';
export 'src/contract/canvas_pointer_input.dart';
export 'src/model/scene_builder_api.dart';
export 'src/contract/scene_data_exception.dart';
export 'src/contract/scene_render_state.dart';
export 'src/contract/scene_write_txn.dart';
export 'src/contract/snapshot.dart';
export 'src/contract/validated.dart';
export 'src/core/action_events.dart'
    show ActionCommitted, ActionCommittedDelta, ActionType, EditTextRequested;
export 'src/core/interaction_types.dart' show CanvasMode, DrawTool;
export 'src/contract/pointer_input.dart' show PointerInputSettings;
export 'src/contract/transform2d.dart' show Transform2D;
export 'src/interactive/scene_controller.dart' show SceneController;
export 'src/interactive/scene_controller_interaction.dart'
    show MoveCommitDeltaResolver, SceneControllerInteraction;
export 'src/interactive/scene_controller_selection.dart'
    show SceneControllerSelection;
export 'src/interactive/scene_controller_scene.dart' show SceneControllerScene;
export 'src/view/scene_view_interactive.dart'
    show SceneView, SceneViewInteractive;
export 'src/serialization/scene_codec.dart'
    show
        decodeScene,
        decodeSceneFromJson,
        encodeScene,
        encodeSceneToJson,
        schemaVersionWrite,
        schemaVersionsRead;
