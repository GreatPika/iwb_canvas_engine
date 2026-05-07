# P8 - frame engine and render caches

## Build

- CapturedMainFrame
- CapturedOverlayFrame
- RenderElementRecord
- PaintPlan
- selected supplement staging
- main/overlay repaint buses
- text/path/stroke/background/resource caches.

## Read first

- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
- `section_15_frame_render_contract` -> `docs/contracts/frame_rendering.md`
- `section_16_geometry_policy` -> `docs/contracts/geometry.md`
- `section_17_spatial_kernel` -> `docs/contracts/spatial_kernel.md`
- `section_18_cache_policy` -> `docs/contracts/cache_policy.md`

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

## Guardrails

- `core.single_runtime_root` - exactly one production RuntimeRoot
- `preview.selected_move_main_repaint` - selected move preview increments main repaint, not overlay
- `frame.no_global_scene_sort` - selected supplement staging merges by orderToken without globally sorting the scene
- `cache.keys_use_next_revisions_only` - cache keys use next-owned revision facts and stable inputs, not legacy snapshot shapes
- `cache.hot_caches_have_capacity_eviction` - hot caches declare capacity, eviction, invalidation owner, and probe

## Tests

- `test.store.no_projection_hot_path` -> `test/store/no_projection_hot_path_test.dart`
- `test.frame.main_overlay_capture` -> `test/frame/main_overlay_capture_test.dart`
- `test.frame.no_live_runtime_read_in_painters` -> `test/frame/no_live_runtime_read_in_painters_test.dart`
- `test.frame.cache_keys_do_not_use_legacy_snapshot_shape` -> `test/frame/cache_keys_do_not_use_legacy_snapshot_shape_test.dart`
- `test.frame.cache_capacity_eviction_policy` -> `test/frame/cache_capacity_eviction_policy_test.dart`
- `test.frame.selected_supplement_staging_no_global_sort` -> `test/frame/selected_supplement_staging_no_global_sort_test.dart`

## Exit gate

- main capture once
- overlay capture once
- selected move preview main repaint
- overlay previews overlay repaint
- no live runtime read in painters
- no CanvasDocument projection in paint
- cache keys are next-revision based
- hot cache capacity/eviction policy is explicit
- selected supplement staging avoids global scene sort.
