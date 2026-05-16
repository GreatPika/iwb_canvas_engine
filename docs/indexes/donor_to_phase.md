# Donor to phase

Every donor is mapped to target phases. `avoid` records are forbidden as structure.

## direct_numeric_policy

- Decision: `copy`
- Target phases: `P2`, `P8`
- Target owner: GeometryPolicy numeric tolerance foundation

## direct_local_bounds_policy

- Decision: `copy`
- Target phases: `P8`, `P9`
- Target owner: GeometryPolicy local bounds

## direct_paint_admission

- Decision: `copy`
- Target phases: `P8`, `P9`
- Target owner: Paint admission policy

## direct_scan_resistant_cache

- Decision: `copy`
- Target phases: `P9`, `P14`
- Target owner: Render cache policy

## direct_pointer_tap_tracking

- Decision: `copy`
- Target phases: `P10`
- Target owner: Pointer session tap tracking

## direct_flutter_pointer_routing

- Decision: `copy`
- Target phases: `P13`
- Target owner: CanvasSurface pointer adapter

## direct_gesture_ownership

- Decision: `copy`
- Target phases: `P10`
- Target owner: InteractionEngine gesture ownership

## direct_structure_validation

- Decision: `copy_adapt`
- Target phases: `P2`, `P3`
- Target owner: DTO and schema structure validation

## foundation_transform2d

- Decision: `copy_adapt`
- Target phases: `P2`, `P3`, `P8`
- Target owner: CanvasTransform and geometry math

## foundation_core_geometry

- Decision: `copy_adapt`
- Target phases: `P8`
- Target owner: GeometryPolicy v1

## foundation_contract_limits

- Decision: `copy_adapt`
- Target phases: `P1.5`, `P2`, `P3`
- Target owner: Validation limits and public constructors

## foundation_error_contract

- Decision: `copy_adapt`
- Target phases: `P2`, `P3`
- Target owner: CanvasDataException and DiagnosticsHub

## foundation_validators

- Decision: `adapt`
- Target phases: `P2`, `P3`
- Target owner: Public DTO and schema validators

## foundation_tri_state_patch_semantics

- Decision: `copy_adapt`
- Target phases: `P2`
- Target owner: CanvasFieldUpdate update semantics

## foundation_immutable_collections

- Decision: `adapt`
- Target phases: `P2`
- Target owner: DTO immutability

## foundation_pointer_input_contract

- Decision: `copy_adapt`
- Target phases: `P2`, `P10`, `P11`, `P12`
- Target owner: Canvas pointer API and InteractionEngine

## foundation_action_event_immutability

- Decision: `adapt`
- Target phases: `P2`, `P10`, `P11`, `P12`
- Target owner: CanvasActionEvent and text edit events

## geometry_node_geometry

- Decision: `adapt`
- Target phases: `P8`
- Target owner: GeometryPolicy and HitTestPolicy

## geometry_hit_test

- Decision: `adapt`
- Target phases: `P8`
- Target owner: HitTestPolicy v1

## render_geometry_builder

- Decision: `adapt`
- Target phases: `P8`, `P9`
- Target owner: RenderElementRecord geometry construction

## geometry_interactive_geometry

- Decision: `copy_adapt`
- Target phases: `P8`, `P10`, `P11`, `P12`
- Target owner: Draw and eraser geometry helpers

## geometry_eraser_exact_hit

- Decision: `adapt`
- Target phases: `P8`, `P12`
- Target owner: Eraser exact-hit engine

## spatial_scene_spatial_index

- Decision: `adapt`
- Target phases: `P8`
- Target owner: SpatialKernel tile and outlier indexes

## spatial_index_cache

- Decision: `adapt`
- Target phases: `P8`, `P9`
- Target owner: SpatialKernel invalidation cache

## store_scene_controller_read_paths

- Decision: `adapt`
- Target phases: `P4`, `P8`
- Target owner: DocumentStoreKernel committed read and candidate resolve

## snapshot_paint_admission_bounds

- Decision: `adapt`
- Target phases: `P9`
- Target owner: FrameEngine paint bounds cache

## snapshot_paint_candidates

- Decision: `adapt`
- Target phases: `P9`
- Target owner: FrameEngine fallback candidate enumeration

## frame_render_state

- Decision: `adapt`
- Target phases: `P9`
- Target owner: Captured frame model

## scene_view_runtime_fast_path

- Decision: `adapt`
- Target phases: `P9`
- Target owner: FrameEngine committed fast path

## paint_candidate_stage

- Decision: `adapt`
- Target phases: `P9`
- Target owner: PaintPlan staging

## scene_painter_frame

- Decision: `adapt`
- Target phases: `P9`, `P13`
- Target owner: Main and overlay painters

## scene_render_caches

- Decision: `adapt`
- Target phases: `P9`, `P13`
- Target owner: Render cache owner lifecycle

## static_layer_cache

- Decision: `adapt`
- Target phases: `P9`, `P13`
- Target owner: Optional static layer cache

## text_stroke_path_metrics_caches

- Decision: `adapt`
- Target phases: `P9`
- Target owner: Render family caches

## dto_snapshot_behavior

- Decision: `adapt`
- Target phases: `P2`
- Target owner: CanvasDocument DTOs

## dto_node_spec_behavior

- Decision: `adapt`
- Target phases: `P2`
- Target owner: Element creation DTO validation

## dto_boundary_schema

- Decision: `adapt`
- Target phases: `P2`, `P3`
- Target owner: Typed and JSON schema field groups

## dto_scene_value_validation

- Decision: `adapt_rewrite`
- Target phases: `P2`, `P3`
- Target owner: Runtime/model validation adapters

## dto_node_boundary_mapping

- Decision: `adapt`
- Target phases: `P3`, `P4`
- Target owner: Codec and store mapping families

## dto_document_helpers

- Decision: `adapt`
- Target phases: `P4`, `P5`
- Target owner: DocumentStoreKernel and EditKernel helpers

## codec_guards

- Decision: `copy_adapt`
- Target phases: `P3`
- Target owner: CodecBoundary raw JSON guards

## codec_json_require

- Decision: `copy_adapt`
- Target phases: `P3`
- Target owner: Schema v1 strict field access

## codec_json_parse

- Decision: `adapt`
- Target phases: `P3`
- Target owner: Schema v1 primitive parsers

## codec_metadata_decode

- Decision: `adapt`
- Target phases: `P3`
- Target owner: Schema v1 metadata codec

## codec_layer_decode

- Decision: `adapt`
- Target phases: `P3`
- Target owner: Layer schema codec

## codec_node_common_decode

- Decision: `adapt`
- Target phases: `P3`
- Target owner: Element common schema codec

## codec_family_decode

- Decision: `adapt`
- Target phases: `P3`
- Target owner: Element family codecs

## codec_scene_codec_flow

- Decision: `adapt_rewrite`
- Target phases: `P3`
- Target owner: CodecBoundary codec reference

## codec_validation_path_surface

- Decision: `copy_adapt`
- Target phases: `P3`
- Target owner: Diagnostic path projection

## tooling_schema_family_parity

- Decision: `adapt`
- Target phases: `P14`
- Target owner: Tooling guardrail

## interaction_pointer_host

- Decision: `adapt`
- Target phases: `P13`
- Target owner: CanvasSurface pointer host

## interaction_pointer_session

- Decision: `adapt`
- Target phases: `P10`, `P11`, `P12`, `P13`
- Target owner: InteractionEngine pointer session

## interaction_pointer_normalizer

- Decision: `copy_adapt`
- Target phases: `P10`, `P11`, `P12`
- Target owner: Pointer sample normalizer

## interaction_event_dispatcher

- Decision: `adapt`
- Target phases: `P10`, `P11`, `P12`
- Target owner: Interaction event dispatch

## interaction_double_tap_router

- Decision: `adapt`
- Target phases: `P12`
- Target owner: Text edit request router

## interaction_gesture_runtime

- Decision: `adapt`
- Target phases: `P10`, `P11`, `P12`
- Target owner: InteractionEngine dispatch order and cleanup

## interaction_move_session

- Decision: `adapt`
- Target phases: `P10`
- Target owner: Move and marquee interaction machines

## interaction_draw_coordinator

- Decision: `adapt_rewrite`
- Target phases: `P11`, `P12`
- Target owner: Draw, line and eraser machines

## interaction_mutation_boundary

- Decision: `adapt`
- Target phases: `P5`, `P10`, `P11`, `P12`
- Target owner: Interaction-owned mutation bridge into EditKernel

## staged_load_runtime_materialization

- Decision: `adapt`
- Target phases: `P6`, `P10`
- Target owner: loadDocument staged materialization

## validated_import_draft

- Decision: `adapt`
- Target phases: `P3`, `P6`
- Target owner: Validated document import draft

## interaction_public_controller_behavior

- Decision: `rewrite_reference`
- Target phases: `P1`, `P2`
- Target owner: Behavioral checklist only

## avoid_scene_controller_facades

- Decision: `avoid`
- Target phases: `avoid`
- Target owner: No next owner

## avoid_interactive_runtime_whole

- Decision: `avoid`
- Target phases: `avoid`
- Target owner: No next owner

## avoid_scene_builder_public_architecture

- Decision: `avoid`
- Target phases: `avoid`
- Target owner: No next owner

## avoid_scene_codec_whole

- Decision: `avoid`
- Target phases: `avoid`
- Target owner: No next owner

## avoid_scene_store_controller_whole

- Decision: `avoid`
- Target phases: `avoid`
- Target owner: No next owner
