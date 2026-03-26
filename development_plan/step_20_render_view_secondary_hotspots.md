language: russian

# Шаг 20. Закрыть secondary hotspots render/view через подшаги 20.1-20.5

## 1. Change Mandate

Этот шаг закрывает secondary hotspots в render/view after boundary and runtime
work, reducing local duplication and owner width without changing render or
view public behavior.

## 2. Change Boundary

### Included in the Change

- `ScenePainter` render-local owner decomposition.
- Render-cache lifecycle consolidation across `SceneViewCore` and
  `SceneViewInteractive`.
- `SceneSpatialIndex` local hotspot cleanup and parity proof refresh.
- Residual render/view hotspot closure after the first implementation pass.
- Post-residual rebaseline по render/view hot spots.

### Not Included in the Change

- Boundary-matrix work.
- Runtime orchestration work.
- Public API and transport contract changes.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/render/scene_painter.dart`
- `lib/src/render/render_geometry_cache.dart`
- `lib/src/render/scene_render_caches.dart`
- `lib/src/view/scene_view.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/node_geometry.dart`

### Test Files

- `test/render/**`
- `test/view/**`
- `test/core/scene_spatial_index_test.dart`
- `test/core/node_geometry_test.dart`
- `test/core/hit_test_candidate_bounds_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_20*.md`

### Analysis Area

- `lib/src/render/**`
- `lib/src/view/**`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/node_geometry.dart`
- `test/render/**`
- `test/view/**`
- `test/core/scene_spatial_index_test.dart`
- `test/core/node_geometry_test.dart`
- `test/core/hit_test_candidate_bounds_test.dart`
- `development_plan/step_20*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to exactly one render/view
  substep.
- Every modified test must be tied to one verification surface.
- Every modified planning document must be tied to one measured baseline or one
  execution slice.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Render-local ownership stays explicit; this step must not introduce a new
   generic renderer hierarchy.
2. View-layer cache lifecycle remains view-owned and must not move into
   controller or render owners.
3. Spatial-index and hit-test parity behavior remain protected.
4. This step is secondary to steps 18 and 19 and must not reopen them.

## 5. Result Requirements

1. Render/view hotspots are reduced without changing public render/view
   behavior.
2. `ScenePainter`, `SceneViewCore`, `SceneViewInteractive`, and
   `SceneSpatialIndex` no longer keep the specific mixed or duplicated local
   ownership shapes targeted by `20.1-20.4`.
3. Post-`20.5` measured residual reality is recorded as `13` `HIGH+` entries
   and `8` related clone clusters, and further work is moved to follow-up
   steps instead of remaining implicit inside step 20.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `20.1-20.4` are closed as execution steps.
- Post-`20.5` measured residual reality for the configured render/view family
  is:
  - `13` `HIGH+` entries
  - `8` related clone clusters in the target zone
- Remaining render/view structural work is recorded only as explicit follow-up
  planning after this rebaseline.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/render lib/src/view lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- `dart run tool/check_import_boundaries.dart`

### 6.3 Protected States, Data, or Structures

- Render output behavior and selection overlay behavior.
- View cache lifecycle ownership.
- Spatial-index and hit-test parity behavior.

### 6.4 Allowed Semantic Change Zones

- Render-local owner structure inside `ScenePainter`.
- View-side render-cache lifecycle structure.
- Spatial-index local helper and ownership structure.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `20.1` closes before `20.2`.
- `20.2` closes before `20.3`.
- `20.4` is forbidden until `20.1-20.3` are closed and the residual baseline
  is captured.
- `20.5` is forbidden until `20.1-20.4` are closed and remeasured.

### 6.8 Prohibited

- Introducing a generic renderer hierarchy.
- Moving view-side cache lifecycle into controller or render global owners.
- Changing hit-test parity behavior to improve metrics.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be
   covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] ScenePainter decomposition

#### Slice Contract

Закрыть `development_plan/step_20_1_scene_painter_render_owner_decomposition.md`
без выхода за ownership boundary `20.1`.

#### Verification

- Verification from `20.1`

### Slice 2. [x] SceneView cache lifecycle consolidation

#### Slice Contract

Закрыть `development_plan/step_20_2_scene_view_render_cache_lifecycle_consolidation.md`
без выхода за ownership boundary `20.2`.

#### Verification

- Verification from `20.2`

### Slice 3. [x] SceneSpatialIndex hotspot cleanup

#### Slice Contract

Закрыть `development_plan/step_20_3_scene_spatial_index_local_hotspot_cleanup.md`
без выхода за ownership boundary `20.3`.

#### Verification

- Verification from `20.3`

### Slice 4. [x] Residual render/view hotspot closure

#### Slice Contract

Закрыть `development_plan/step_20_4_residual_render_view_hotspot_closure.md`
без повторного открытия semantic scope `18-19`.

#### Verification

- Verification from `20.4`

### Slice 5. [x] Render/view rebaseline

#### Slice Contract

Закрыть `development_plan/step_20_5_render_view_rebaseline_and_roadmap.md`
без повторного открытия semantic scope `20.1-20.4`.

#### Verification

- Verification from `20.5`

## 9. Final Verification

- `dcm calculate-metrics lib/src/render lib/src/view lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- `dart run tool/check_import_boundaries.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
