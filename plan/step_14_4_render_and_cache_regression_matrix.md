language: russian

# Шаг 14.4. Закрыть regression-матрицу render и cache

## 1. Change Mandate

This change closes the unresolved render/cache regression matrix for painter,
grid, geometry, and cache invalidation contracts in the current
`lib/src/render/**` seam.

## 2. Change Boundary

### Included in the Change
- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_grid_renderer.dart`
- `lib/src/render/scene_render_caches.dart`
- `lib/src/render/render_geometry_cache.dart`
- `lib/src/render/cache/scene_static_layer_cache.dart`
- `lib/src/render/cache/scene_stroke_path_cache.dart`
- `lib/src/render/cache/scene_text_layout_cache.dart`
- `lib/src/render/cache/scene_path_metrics_cache.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_grid_renderer_test.dart`
- `test/render/scene_render_caches_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/render/scene_path_metrics_cache_test.dart`
- `test/render/render_geometry_cache_test.dart`

### Not Included in the Change
- Serialization/model/core regression proofs
- Controller command or commit regression proofs
- Interactive/view pointer lifecycle regressions

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_grid_renderer.dart`
- `lib/src/render/scene_render_caches.dart`
- `lib/src/render/render_geometry_cache.dart`
- `lib/src/render/cache/scene_static_layer_cache.dart`
- `lib/src/render/cache/scene_stroke_path_cache.dart`
- `lib/src/render/cache/scene_text_layout_cache.dart`
- `lib/src/render/cache/scene_path_metrics_cache.dart`

### Test Files
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_grid_renderer_test.dart`
- `test/render/scene_render_caches_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/render/scene_path_metrics_cache_test.dart`
- `test/render/render_geometry_cache_test.dart`

### Analysis Area
- `lib/src/render/**`
- `test/render/**`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Painter, grid, geometry cache, and render caches remain separate owner
   modules inside `lib/src/render/**`.
2. Grid drawing semantics remain owned by `scene_grid_renderer.dart`.
3. Render cache validity remains tied to the current cache-key and revision
   contracts rather than a new synchronization layer.
4. This step closes regression proofs for the current render architecture; it
   does not reopen step `12.x`.

## 5. Result Requirements

1. Render regressions are covered for `save/restore` integrity, bounded grid
   generation, painter/static-cache grid parity, text-layout cache keys,
   path-cache invalidation, and revision-based cache contracts.
2. The render regression matrix stays within `test/render/**` as the primary
   owner-level proof set.
3. Cache-key and invalidation checks prove the current owner contracts instead
   of introducing duplicate lifecycle logic.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Reuse the current render tests around painter, grid, geometry cache, and
  dedicated caches.
- Keep painter-frame and grid-parity checks in painter/grid tests.
- Keep cache-key and invalidation checks in the specific cache tests that own
  those contracts.

### 6.2 Target Verification Units
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_grid_renderer_test.dart`
- `test/render/scene_render_caches_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/render/scene_path_metrics_cache_test.dart`
- `test/render/render_geometry_cache_test.dart`

### 6.3 Protected States, Data, or Structures
- Canvas save/restore nesting
- Grid draw plan and density bounds
- Geometry cache validity keys
- Stroke/path/text cache keys and invalidation state
- Render revision and epoch-based invalidation assumptions

### 6.4 Allowed Semantic Change Zones
- Painter frame and selection render regression proofs
- Grid planner and static-cache parity regression proofs
- Dedicated cache-key and invalidation regression proofs

### 6.8 Prohibited
- Proving render behavior primarily through view tests
- Introducing a second cache-validity owner
- Treating cache clears as sufficient proof of key correctness

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

### Slice 1. [x] Painter and Grid Parity Matrix

#### Slice Contract
Painter frame and grid rendering contracts have explicit regression proofs for
the unresolved parity and integrity cases.

#### Change
Extend the painter and grid tests that own `save/restore`, bounded grid line
generation, and painter/static-cache algorithm parity.

#### Verification
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_grid_renderer_test.dart`
- `test/render/scene_static_layer_cache_test.dart`

#### Positive Scenarios
- finite frames paint through the current painter contract
- painter and static cache use the same current grid algorithm

#### Negative Scenarios
- save/restore nesting cannot leak across painter branches
- grid generation stays bounded by the actual current step policy

#### Closure Evidence
- Green run of the listed tests.
- The original painter/grid regression items from step `14` are covered by
  owner-level render tests.

### Slice 2. [x] Cache Key and Invalidation Matrix

#### Slice Contract
Render cache key composition and invalidation semantics have explicit owner
tests for the unresolved regression set.

#### Change
Extend the cache-specific tests around text layout, stroke paths, path metrics,
geometry cache, and cache lifecycle aggregation.

#### Verification
- `test/render/scene_render_caches_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/render/scene_path_metrics_cache_test.dart`
- `test/render/render_geometry_cache_test.dart`

#### Positive Scenarios
- caches reuse entries when the current validity inputs match
- render cache aggregation respects the current lifecycle boundary

#### Negative Scenarios
- text layout cache key keeps paint-affecting color and opacity while layout
  inputs stay unchanged
- path cache invalidates under the current invariant
- cache reuse does not survive incompatible revision identity changes

#### Closure Evidence
- Green run of the listed cache tests.
- No original cache regression item from step `14` remains without an owner
  proof.

## 9. Final Verification

- `dart run tool/check_invariant_coverage.dart`
- Green run of the render verification units listed in section `6.2`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
