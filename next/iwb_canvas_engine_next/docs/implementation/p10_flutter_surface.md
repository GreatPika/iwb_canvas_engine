# P10 - Flutter surface

## Build

- CanvasSurface widget
- pointer adapter
- main painter
- overlay painter
- synchronous app-owned resource resolver bridge
- selection/grid style application.

## Read first

- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_07_resource_lifecycle` -> `docs/contracts/resources.md`
- `section_14_interaction_engine` -> `docs/contracts/interaction_engine.md`
- `section_15_frame_render_contract` -> `docs/contracts/frame_rendering.md`
- `section_18_cache_policy` -> `docs/contracts/cache_policy.md`
- `section_23_tests` -> `docs/verification/tests.md`

## Required donors

- `direct_flutter_pointer_routing` - decision: `copy`; target owner: CanvasSurface pointer adapter
- `scene_painter_frame` - decision: `adapt`; target owner: Main and overlay painters
- `scene_render_caches` - decision: `adapt`; target owner: Render cache owner lifecycle
- `static_layer_cache` - decision: `adapt`; target owner: Optional static layer cache
- `interaction_pointer_host` - decision: `adapt`; target owner: CanvasSurface pointer host
- `interaction_pointer_session` - decision: `adapt`; target owner: InteractionEngine pointer session

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `c4_context` -> `docs/diagrams/c4_context.mmd`
- `dfd_cache_invalidation` -> `docs/diagrams/dfd_cache_invalidation.mmd`
- `dfd_main_paint_frame` -> `docs/diagrams/dfd_main_paint_frame.mmd`
- `dfd_overlay_frame` -> `docs/diagrams/dfd_overlay_frame.mmd`
- `dfd_pointer_preview_commit` -> `docs/diagrams/dfd_pointer_preview_commit.mmd`
- `dfd_public_edit` -> `docs/diagrams/dfd_public_edit.mmd`
- `dfd_resource_resolution` -> `docs/diagrams/dfd_resource_resolution.mmd`
- `seq_dispose_during_gesture` -> `docs/diagrams/seq_dispose_during_gesture.mmd`
- `seq_eraser_commit` -> `docs/diagrams/seq_eraser_commit.mmd`
- `seq_line_two_tap_commit` -> `docs/diagrams/seq_line_two_tap_commit.mmd`
- `seq_main_paint` -> `docs/diagrams/seq_main_paint.mmd`
- `seq_marquee_select` -> `docs/diagrams/seq_marquee_select.mmd`
- `seq_overlay_paint` -> `docs/diagrams/seq_overlay_paint.mmd`
- `seq_pencil_marker_commit` -> `docs/diagrams/seq_pencil_marker_commit.mmd`
- `seq_resource_resolution` -> `docs/diagrams/seq_resource_resolution.mmd`
- `seq_selected_move_cancel` -> `docs/diagrams/seq_selected_move_cancel.mmd`
- `seq_selected_move_preview_commit` -> `docs/diagrams/seq_selected_move_preview_commit.mmd`
- `seq_text_edit_request` -> `docs/diagrams/seq_text_edit_request.mmd`
- `state_eraser` -> `docs/diagrams/state_eraser.mmd`
- `state_pencil_marker_draw` -> `docs/diagrams/state_pencil_marker_draw.mmd`
- `state_pending_text_edit_request` -> `docs/diagrams/state_pending_text_edit_request.mmd`
- `state_pointer_session` -> `docs/diagrams/state_pointer_session.mmd`
- `state_resource_resolution` -> `docs/diagrams/state_resource_resolution.mmd`
- `state_select_marquee` -> `docs/diagrams/state_select_marquee.mmd`
- `state_selected_move` -> `docs/diagrams/state_selected_move.mmd`
- `state_two_tap_line` -> `docs/diagrams/state_two_tap_line.mmd`

## Guardrails

- `load.prepares_before_interrupt` - failed load does not interrupt gesture
- `load.success_interrupts_before_install` - success interrupt happens before atomic install
- `api.dto_immutability` - DTO collections defensively copied and unmodifiable
- `api.functional_ledger_complete` - every functional ledger row has API + tests
- `api.id_validation_no_extension_type_escape` - ids cannot be publicly constructed without validation
- `api.no_undefined_public_type_references` - every exported signature type is exported or from Flutter/Dart SDK
- `api.public_api_compiles_as_written` - public API declarations compile in an empty consumer package
- `api.public_types_complete` - all public signatures reference defined public types
- `preview.selected_move_main_repaint` - selected move preview increments main repaint, not overlay
- `resources.app_key_only` - resource descriptors use appKey only
- `resources.dirty_no_document_revision` - markResourceDirty does not increment documentRevision
- `resources.mutation_inside_edit_only` - resource descriptor mutation only via CanvasEdit
- `surface.pointer_samples_normalized_before_runtime` - Flutter adapters pass only normalized finite pointer samples into runtime routing
- `surface.interactive_false_pending_line_preserved` - interactive=false cancels active routed pointers but preserves non-active pending line state

## Tests

- `test.resources.sync_image_resolver` -> `test/resources/sync_image_resolver_test.dart`
- `test.resources.app_owned_image_not_disposed` -> `test/resources/app_owned_image_not_disposed_test.dart`
- `test.surface.interactive_false_pointer_routing` -> `test/surface/interactive_false_pointer_routing_test.dart`
- `test.surface.interactive_false_active_session_cancel` -> `test/surface/interactive_false_active_session_cancel_test.dart`
- `test.surface.interactive_false_pending_line_preserved` -> `test/surface/interactive_false_pending_line_preserved_test.dart`
- `test.surface.pointer_adapter_finite_normalization` -> `test/surface/pointer_adapter_finite_normalization_test.dart`
- `test.surface.widget_paint` -> `CanvasSurface empty/populated widget paint tests`

## Exit gate

- surface paints empty and populated docs
- interactive=false disables pointer routing
- interactive=false cancels active pointer sessions but preserves non-active pending line state
- resource resolver repaint works
- pointer adapter normalization tests green
- widget tests green.
