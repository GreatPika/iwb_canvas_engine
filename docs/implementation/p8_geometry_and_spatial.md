# P8 - geometry and spatial kernels

## Purpose

Implement geometry, hit-test, paint-admission, and spatial candidate lookup
before frame rendering and interaction depend on bounded element queries.

## Build scope

- `GeometryPolicy` v1
- `HitTestPolicy` v1
- transform, local bounds, hit bounds, and paint bounds policy
- exact family hit tests
- paint admission
- eraser geometry primitives and exact-check budget foundations
- `SpatialKernel`
- `TileIndex`
- `OutlierIndex`
- `SpatialMembership`
- touched spatial update
- stale candidate generation/structuralRevision rejection
- fallback query budget and typed budget-exceeded result
- no global scene traversal or legacy scene order logic.

## Dependencies on earlier phases

- P2 public geometry and element DTOs are frozen.
- P4 runtime spine owns committed facts and revisions.
- P5 edit core produces touched sets and typed invalidation effects.
- P7 resource/image rows exist for image geometry and paint admission.

## Read first

- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
- `section_16_geometry_policy` -> `docs/contracts/geometry.md`
- `section_17_spatial_kernel` -> `docs/contracts/spatial_kernel.md`
- `section_23_tests` -> `docs/verification/tests.md`

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
- `store_scene_controller_read_paths` - decision: `adapt`; target owner: DocumentStoreKernel committed read and candidate resolve through immutable query ports

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `dfd_cache_invalidation` -> `docs/diagrams/dfd_cache_invalidation.mmd`
- `dfd_pointer_preview_commit` -> `docs/diagrams/dfd_pointer_preview_commit.mmd`
- `dfd_spatial_query_budget` -> `docs/diagrams/dfd_spatial_query_budget.mmd`
- `seq_spatial_touched_update` -> `docs/diagrams/seq_spatial_touched_update.mmd`
- `seq_hit_test_candidate_resolution` -> `docs/diagrams/seq_hit_test_candidate_resolution.mmd`
- `seq_eraser_exact_budget` -> `docs/diagrams/seq_eraser_exact_budget.mmd`

## Contracts satisfied by this phase

- geometry and hit-test policy from `section_16_geometry_policy`
- spatial index, touched update, stale candidate, and fallback budget contracts
  from `section_17_spatial_kernel`
- geometry-dependent invalidation facts from `section_10_runtime_data_model`

## Tests and guardrails that prove this phase

- `test.geometry.hit_policy` -> `test/geometry/hit_policy_test.dart`
- `test.geometry.no_legacy_scene_order` -> `test/geometry/no_legacy_scene_order_test.dart`
- `test.spatial.touched_update` -> `test/spatial/touched_update_test.dart`
- `test.spatial.no_full_clone_for_touched_update` -> `test/spatial/no_full_clone_for_touched_update_test.dart`
- `test.spatial.stale_generation_rejected` -> `test/spatial/stale_generation_rejected_test.dart`
- `test.spatial.fallback_budget_enforced` -> `test/spatial/fallback_budget_enforced_test.dart`
- `geometry.no_legacy_scene_order`
- `spatial.no_full_clone_ordinary_edit`
- `spatial.stale_candidate_rejected`
- `spatial.fallback_budget_enforced`

The full eraser terminal no-partial-commit proof remains P12 scope. P8 proves
the geometry primitives and exact-check budget inputs that P12 consumes.

## Exit gate

- hit tests green
- spatial constants green
- outlier behavior green
- touched-only spatial update green
- no legacy scene order tests green
- stale candidate rejection tests green
- fallback budget tests green
- eraser exact-hit algorithm inputs are available for P12 terminal behavior.

## Risks and trade-offs

- Porting legacy traversal would couple geometry to old scene order. Geometry
  must operate over next-owned rows and order tokens.
- Silent full-scene fallback would hide performance regressions. Budget-exceeded
  results must be typed and non-partial.

## Why this phase belongs here

Frame rendering, selection, move, draw, text hit-testing, and eraser all need
bounded geometry and spatial queries. P8 follows store/edit/resources and
precedes frame and interaction behavior.
