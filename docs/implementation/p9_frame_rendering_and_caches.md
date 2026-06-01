# P9 - frame rendering, paint plans, and render caches

## Purpose

Implement frame capture, paint plan construction, painter-safe render records,
resource resolution use in paint, selected-supplement staging support, and
bounded render caches before interaction previews and Flutter painters consume
frame output.

## Build scope

- `FrameEngine`
- `FrameEngine` internal collaborator split:
  `FrameCaptureService`, `OrdinaryPaintPlanner`,
  `SelectedMoveSupplementPlanner`, `SelectionDecorationPlanner`,
  `PaintAssetBindingService`, `StaticBackgroundPlanner`, and
  `OverlayPreviewPlanner`
- `CapturedMainFrame`
- `CapturedOverlayFrame`
- `RenderElementRecord`
- `PaintPlan`
- selected supplement staging support for later move preview
- selection decoration reads through captured selection facts, separate from
  ordinary paint plans
- main/overlay repaint buses
- text/path/stroke/background/resource caches
- OrdinaryPaintRecordCache with ordinary committed records only
- cache keys based on next-owned revisions, not legacy snapshot shapes
- `backgroundRevision` and `gridRevision` excluded from ordinary element
  paint-plan invalidation
- runtime view camera revision/offset excluded from ordinary element paint-plan
  invalidation and public document projection invalidation
- `selectionRevision`, selected ids, selection flags, and selected-move preview
  deltas excluded from ordinary paint-plan keys and cached ordinary records
- explicit frame spatial paint admission for ordinary and selected-move shifted
  candidates, with typed non-candidate spatial results rejected visibly
- rejected selected-move shifted admission publishes ordinary records unchanged
  and performs no ordinary cache write
- frame-owned degenerate drawable policy for one-point strokes, eraser
  corridors, and same-point lines
- marquee overlay primitives carry captured selection style for painter output
- no live runtime read in painters
- no `CanvasDocument` projection in paint
- resource image resolution only through `SurfaceResourceSession` owned by
  `lib/src/resources/**`
- committed frame facts, row snapshot resolution, and descriptor snapshot
  lookup only through `FrameFactsPort` owned by `contracts/internal/**`
- ordinary opacity through primitive paint alpha, not implicit `Canvas.saveLayer`.

## Implemented FrameEngine internal split

Candidate B is the accepted frame rendering form: `FrameEngine` remains the
frame-internal facade and delegates focused work to seven frame-private
collaborators. The split is larger than the backlog's five-service sketch
because selected move supplement staging and overlay preview primitive
admission need explicit owners.

| Collaborator | Owns | Must not own |
|---|---|---|
| `FrameCaptureService` | one-time capture of main/overlay live frame facts into `CapturedMainFrame` and `CapturedOverlayFrame` | record planning, resolver/session calls, cache mutation beyond captured-frame construction |
| `OrdinaryPaintPlanner` | per-frame ordinary spatial admission and committed render-record reuse inside the 16-entry viewport/revision OrdinaryPaintRecordCache | selection revision, selection style, selected move delta, preview state, resource resolver/session, static background identity |
| `SelectedMoveSupplementPlanner` | per-frame selected move filtering, shifted candidate lookup, row resolution, and merge by `orderToken` | ordinary `OrdinaryPaintRecordCache` writes, overlay rendering, global scene sort |
| `SelectionDecorationPlanner` | selection UI decoration and `SelectionDecorationPlan` key including `boundsRevision` | ordinary record cache identity, selected move supplement records, static background identity |
| `PaintAssetBindingService` | descriptor-to-asset binding for records with image resource ids, using immutable descriptor facts and `SurfaceResourceSession` | ordinary paint plan construction, painter resolver calls, app resolver ownership |
| `StaticBackgroundPlanner` | static background/grid plan and cache identity | selection, preview, resource visual, ordinary element visual identity |
| `OverlayPreviewPlanner` | immutable overlay primitives admitted from `CapturedOverlayFrame` | selected move rendering, resource resolver reads, cache invalidation, repaint scheduling |

Implementation target keeps committed document facts behind `FrameFactsPort`,
selection facts behind the selection facts boundary, and resolver/session access
isolated to `SurfaceResourceSession`. `PaintAssetBindingService` is the only
frame collaborator that receives the session, and it calls
`beginFrameResourcePass()` before image resolution. `OrdinaryPaintPlanner` must not
depend on selection revision, selection style, selected move delta, preview
state, resolver/session APIs, or static background identity. Painters consume
immutable frame outputs and do not read live runtime, store, resolver, or public
document state.

Implementation must add behavior tests and guardrails for the split
without exposing frame collaborators through the package barrel. At minimum:

- `FrameCaptureService` captures main and overlay live frame facts once.
- `OrdinaryPaintPlanner` keeps ordinary cache identity free of selection,
  preview, resolver/session, static background facts, and viewport-admission
  results, while still admitting committed background elements as ordinary
  render records, and admits only explicit spatial candidate results.
- `SelectedMoveSupplementPlanner` stages selected move records without ordinary
  `OrdinaryPaintRecordCache` writes or global scene sort; rejected shifted
  spatial admission returns ordinary records unchanged.
- `SelectionDecorationPlanner` includes `boundsRevision` so selected element
  bounds changes invalidate decoration even when selection membership is
  unchanged.
- `PaintAssetBindingService` binds image descriptors through
  `SurfaceResourceSession` after record planning.
- `StaticBackgroundPlanner` proves background/grid cache identity does not
  invalidate ordinary element paint plans.
- `OverlayPreviewPlanner` admits immutable overlay primitives from
  `CapturedOverlayFrame` without selected move rendering, resource resolver
  reads, cache invalidation, or repaint scheduling ownership, and marquee
  primitives carry captured selection style values.

## Dependencies on earlier phases

- P4 runtime spine provides committed tables, projection guardrails, revisions,
  and the `contracts/internal/**` `FrameFactsPort` for frame-facing committed
  facts.
- P4 runtime spine provides selection-owner facts through immutable query ports.
- P5 edit core emits typed repaint and invalidation effects.
- P7 resources provide the `lib/src/resources/**` `SurfaceResourceSession`
  boundary and image resolve cache behavior.
- P8 geometry/spatial provides paint bounds, admission, and candidate lookup.

## Read first

- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
- `section_07_resource_lifecycle` -> `docs/contracts/resources.md`
- `section_15_frame_render_contract` -> `docs/contracts/frame_rendering.md`
- `section_16_geometry_policy` -> `docs/contracts/geometry.md`
- `section_17_spatial_kernel` -> `docs/contracts/spatial_kernel.md`
- `section_18_cache_policy` -> `docs/contracts/cache_policy.md`
- `section_23_tests` -> `docs/verification/tests.md`

## Required donors

- `direct_local_bounds_policy` - decision: `copy`; target owner: GeometryPolicy local bounds
- `direct_paint_admission` - decision: `copy`; target owner: Paint admission policy
- `direct_scan_resistant_cache` - decision: `copy`; target owner: Render cache policy
- `render_geometry_builder` - decision: `adapt`; target owner: RenderElementRecord geometry construction
- `spatial_index_cache` - decision: `adapt`; target owner: SpatialKernel invalidation cache
- `snapshot_paint_admission_bounds` - decision: `adapt`; target owner: FrameEngine paint bounds cache
- `snapshot_paint_candidates` - decision: `adapt`; target owner: FrameEngine fallback candidate enumeration
- `frame_render_state` - decision: `adapt`; target owner: Captured frame model
- `scene_view_runtime_fast_path` - decision: `adapt`; target owner: FrameEngine committed fast path
- `paint_candidate_stage` - decision: `adapt`; target owner: PaintPlan staging
- `scene_painter_frame` - decision: `adapt`; target owner: Main and overlay painters
- `scene_render_caches` - decision: `adapt`; target owner: Render cache owner lifecycle
- `static_layer_cache` - decision: `adapt`; target owner: Optional static layer cache
- `text_stroke_path_metrics_caches` - decision: `adapt`; target owner: Render family caches

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `c4_component_runtime` -> `docs/diagrams/c4_component_runtime.mmd`
- `dfd_cache_invalidation` -> `docs/diagrams/dfd_cache_invalidation.mmd`
- `dfd_main_paint_frame` -> `docs/diagrams/dfd_main_paint_frame.mmd`
- `dfd_overlay_frame` -> `docs/diagrams/dfd_overlay_frame.mmd`
- `dfd_pointer_preview_commit` -> `docs/diagrams/dfd_pointer_preview_commit.mmd`
- `seq_main_paint` -> `docs/diagrams/seq_main_paint.mmd`
- `seq_overlay_paint` -> `docs/diagrams/seq_overlay_paint.mmd`
- `seq_selected_move_preview_commit` -> `docs/diagrams/seq_selected_move_preview_commit.mmd`
- `seq_selected_move_cancel` -> `docs/diagrams/seq_selected_move_cancel.mmd`

## Contracts satisfied by this phase

- captured frame, render record, selected supplement staging, and render cache
  miss contracts from `section_15_frame_render_contract`
- cache policy ledger from `section_18_cache_policy`
- no projection hot-path rule from `section_10_runtime_data_model`
- resource resolver paint boundary from `section_07_resource_lifecycle`

## Tests and guardrails that prove this phase

- `test.store.no_projection_hot_path` -> `test/store/no_projection_hot_path_test.dart`
- `test.api.canvas_runtime_preview` -> `test/api/canvas_runtime_preview_test.dart`
- `test.api_contract.preview_state_sealed_union` -> `test/api_contract/preview_state_sealed_union_test.dart`
- `test.frame.main_overlay_capture` -> `test/frame/main_overlay_capture_test.dart`
- `test.frame.frame_donor_mapping` -> `test/frame/frame_donor_mapping_test.dart`
- `test.frame.no_live_runtime_read_in_painters` -> `test/frame/no_live_runtime_read_in_painters_test.dart`
- `test.frame.frame_spatial_paint_admission` -> `test/frame/frame_spatial_paint_admission_test.dart`
- `test.frame.frame_drawable_policy` -> `test/frame/frame_drawable_policy_test.dart`
- `test.frame.marquee_captured_style` -> `test/frame/marquee_captured_style_test.dart`
- `test.frame.paint_plan_write_all_or_nothing` -> `test/frame/paint_plan_write_all_or_nothing_test.dart`
- `test.frame.paint_asset_binding_service` -> `test/frame/paint_asset_binding_service_test.dart`
- `test.frame.repaint_bus_output` -> `test/frame/repaint_bus_output_test.dart`
- `test.frame.static_background_plan` -> `test/frame/static_background_plan_test.dart`
- `test.flutter_bridge.widget_paint` -> `test/flutter_bridge/widget_paint_test.dart`
- `test.smoke.public_incremental_smoke` -> `test/smoke/public_incremental_smoke_test.dart`
- `test.guardrails.frame_committed_facts_via_frame_facts_port` -> `test/guardrails/frame_committed_facts_via_frame_facts_port_test.dart`
- `test.guardrails.frame_no_global_scene_sort` -> `test/guardrails/frame_no_global_scene_sort_guardrail_test.dart`
- `test.guardrails.frame_paint_plan_excludes_preview_delta` -> `test/guardrails/frame_paint_plan_excludes_preview_delta_guardrail_test.dart`
- `test.guardrails.frame_paint_plan_excludes_selection_state` -> `test/guardrails/frame_paint_plan_excludes_selection_state_guardrail_test.dart`
- `test.guardrails.cache_keys_use_next_revisions_only` -> `test/guardrails/cache_keys_use_next_revisions_only_guardrail_test.dart`
- `test.guardrails.cache_background_grid_not_element_visual` -> `test/guardrails/cache_background_grid_not_element_visual_guardrail_test.dart`
- `test.guardrails.cache_hot_caches_have_capacity_eviction` -> `test/guardrails/cache_hot_caches_have_capacity_eviction_guardrail_test.dart`
- `test.guardrails.preview_selected_move_main_repaint` -> `test/guardrails/preview_selected_move_main_repaint_guardrail_test.dart`
- `test.frame.cache_keys_do_not_use_legacy_snapshot_shape` -> `test/frame/cache_keys_do_not_use_legacy_snapshot_shape_test.dart`
- `test.frame.cache_capacity_eviction_policy` -> `test/frame/cache_capacity_eviction_policy_test.dart`
- `test.frame.paint_plan_excludes_preview_delta` -> `test/frame/paint_plan_excludes_preview_delta_test.dart`
- `test.frame.paint_plan_excludes_selection_state` -> `test/frame/paint_plan_excludes_selection_state_test.dart`
- `test.api_contract.public_exports_complete` -> `test/api_contract/public_exports_complete_test.dart`
- `test.api_contract.api_facades_do_not_export_internal` -> `test/api_contract/api_facades_do_not_export_internal_test.dart`
- `test.selection.runtime_owner_separation` -> `test/selection/runtime_owner_separation_test.dart`
- `test.frame.camera_pan_preserves_ordinary_paint_plan` -> `test/frame/camera_pan_preserves_ordinary_paint_plan_test.dart`
- `test.frame.selected_supplement_staging_no_global_sort` -> `test/frame/selected_supplement_staging_no_global_sort_test.dart`
- `projection.only_explicit_read_paths`
- `resources.resolver_boundary_owned_by_surface_session`
- `resources.resolver_frame_budget`
- `frame.committed_facts_via_frame_facts_port`
- `frame.no_global_scene_sort`
- `frame.paint_plan_excludes_preview_delta`
- `frame.paint_plan_excludes_selection_state`
- `selection.owner_separate_from_document`
- `cache.keys_use_next_revisions_only`
- `cache.background_grid_not_element_visual`
- `cache.hot_caches_have_capacity_eviction`
- `preview.selected_move_main_repaint`
- `api.preview_state_sealed_union_publicly_readable`

## Exit gate

- main capture once
- overlay capture once
- selected supplement staging support is present without caching preview records
- selected supplement rejected shifted admission returns ordinary records
  unchanged and writes no ordinary cache entry
- selection decoration and selected order are separate from ordinary paint plan
  cache entries
- frame paint admission accepts only explicit spatial candidate results
- typed non-candidate spatial results remain visible rejected admissions
- degenerate drawable inputs render through frame-owned explicit commands
- marquee overlay primitives use captured selection style values
- overlay previews can be captured without live runtime reads
- no live runtime read in painters
- no `CanvasDocument` projection in paint
- no concrete `DocumentStoreKernel` imports in frame code for committed frame
  facts; frame capture, row resolution, and descriptor lookup use
  `FrameFactsPort`
- cache keys are next-revision based
- `backgroundRevision`, `gridRevision`, and runtime view-camera changes do not
  invalidate ordinary committed render-record cache entries, while spatial
  admission still follows the current effective world viewport
- `selectionRevision` does not invalidate ordinary committed element paint
  plans
- hot cache capacity/eviction policy is explicit
- selected supplement staging avoids global scene sort
- ordinary opacity does not require `Canvas.saveLayer` in the hot paint path.

## Risks and trade-offs

- Rendering before spatial and resources would force full scans or direct
  resolver calls. P9 must consume those earlier owners instead.
- Selected move behavior is completed in P10; P9 owns the frame-side staging
  mechanism and cache invariants only.

## Why this phase belongs here

Frame rendering is the first phase that combines store, resources, geometry,
spatial, revisions, and cache policy. It must land before interaction previews
and Flutter painters rely on frame output.
