# P7 - spatial and geometry

## Build

- GeometryPolicy v1
- HitTestPolicy v1
- TileIndex
- OutlierIndex
- touched spatial update
- exact family hit tests
- paint admission.

## Read first

- `section_16_geometry_policy` -> `docs/contracts/geometry.md`
- `section_17_spatial_kernel` -> `docs/contracts/spatial_kernel.md`

## Required donors

- `direct_numeric_policy` - decision: `copy`; target owner: GeometryPolicy numeric tolerance foundation
- `direct_local_bounds_policy` - decision: `copy`; target owner: GeometryPolicy local bounds
- `direct_paint_admission` - decision: `copy`; target owner: Paint admission policy
- `foundation_transform2d` - decision: `copy/adapt`; target owner: CanvasTransform and geometry math
- `foundation_core_geometry` - decision: `copy/adapt`; target owner: GeometryPolicy v1
- `geometry_node_geometry` - decision: `adapt`; target owner: GeometryPolicy and HitTestPolicy
- `geometry_hit_test` - decision: `adapt`; target owner: HitTestPolicy v1
- `render_geometry_builder` - decision: `adapt`; target owner: RenderElementRecord geometry construction
- `geometry_interactive_geometry` - decision: `copy/adapt`; target owner: Draw and eraser geometry helpers
- `geometry_eraser_exact_hit` - decision: `adapt`; target owner: Eraser exact-hit engine
- `spatial_scene_spatial_index` - decision: `adapt`; target owner: SpatialKernel tile and outlier indexes
- `spatial_index_cache` - decision: `adapt`; target owner: SpatialKernel invalidation cache
- `store_scene_controller_read_paths` - decision: `adapt`; target owner: DocumentStoreKernel committed read and candidate resolve

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `dfd_cache_invalidation` -> `docs/diagrams/dfd_cache_invalidation.mmd`
- `dfd_pointer_preview_commit` -> `docs/diagrams/dfd_pointer_preview_commit.mmd`

## Guardrails

- none

## Tests

- `test.geometry.hit_policy` -> `geometry and hit-test policy tests`
- `test.spatial.touched_update` -> `spatial constants, outlier and touched-only update tests`

## Exit gate

- hit tests green
- spatial constants green
- outlier behavior green
- touched-only spatial update green.
