# P13 - Flutter surface

## Purpose

Connect the proved runtime, frame, resource, and interaction behavior to the
Flutter widget boundary without giving the widget direct ownership of document,
store, resolver, or interaction internals.

## Build scope

- `CanvasSurface` widget
- pointer adapter
- main painter
- overlay painter
- synchronous app-owned resource resolver bridge
- selection/grid style application
- `interactive=false` pointer routing behavior
- active routed pointer cancel on `interactive=false`
- pending line preservation when `interactive=false` happens with no active routed pointer
- pointer adapter finite normalization before runtime routing
- widget paint for empty and populated documents
- Flutter painters apply ordinary element/stroke opacity through primitive paint alpha
- Flutter painters do not call `Canvas.saveLayer` for ordinary opacity in the hot paint path
- any future Flutter `Canvas.saveLayer` effect must be explicit, budgeted,
  probed by the frame paint benchmark, and guarded by a contract update.

## Dependencies on earlier phases

- P7 resource resolver boundary is implemented.
- P9 frame rendering exposes main and overlay frame/painter inputs.
- P10-P12 interaction machines and preview states are implemented.

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

## Contracts satisfied by this phase

- Flutter surface contract from `section_04_public_api_v1`
- resource resolver app-owned image and no-dispose rules from
  `section_07_resource_lifecycle`
- pointer normalization, `interactive=false`, and pending line preservation from
  `section_14_interaction_engine`
- painter capture and no-live-runtime-read contract from
  `section_15_frame_render_contract`
- cache and opacity/saveLayer policy from `section_18_cache_policy`

## Tests and guardrails that prove this phase

- `test.resources.sync_image_resolver` -> `test/resources/sync_image_resolver_test.dart`
- `test.resources.app_owned_image_not_disposed` -> `test/resources/app_owned_image_not_disposed_test.dart`
- `test.flutter_bridge.interactive_false_pointer_routing` -> `test/flutter_bridge/interactive_false_pointer_routing_test.dart`
- `test.flutter_bridge.interactive_false_active_session_cancel` -> `test/flutter_bridge/interactive_false_active_session_cancel_test.dart`
- `test.flutter_bridge.interactive_false_pending_line_preserved` -> `test/flutter_bridge/interactive_false_pending_line_preserved_test.dart`
- `test.flutter_bridge.pointer_adapter_finite_normalization` -> `test/flutter_bridge/pointer_adapter_finite_normalization_test.dart`
- `test.flutter_bridge.widget_paint` -> `test/flutter_bridge/widget_paint_test.dart`
- `surface.pointer_samples_normalized_before_runtime`
- `surface.interactive_false_pending_line_preserved`
- `resources.app_key_only`
- `resources.dirty_no_document_revision`
- `resources.mutation_inside_edit_only`
- `preview.selected_move_main_repaint`
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`

## Exit gate

- surface paints empty and populated docs
- `interactive=false` disables pointer routing
- `interactive=false` cancels active pointer sessions but preserves non-active pending line state
- resource resolver repaint works
- Flutter painters apply ordinary element/stroke opacity through primitive paint alpha
- Flutter painters do not call `Canvas.saveLayer` for ordinary opacity in the hot paint path
- any future Flutter `Canvas.saveLayer` effect must be explicit, budgeted, probed by the frame paint benchmark, and guarded by a contract update
- pointer adapter normalization tests green
- widget tests green.

## Risks and trade-offs

- The widget must not become a second runtime owner. It adapts Flutter pointer and
  paint boundaries into already-proved runtime ports.
- Pointer cancellation on `interactive=false` must be narrower than clearing all
  preview state, because pending line state can exist outside an active routed
  pointer session.

## Why this phase belongs here

The Flutter surface is last among implementation features because it composes
runtime, resources, frame, and interaction. Building it earlier would require
widget-owned shortcuts that the architecture forbids.
