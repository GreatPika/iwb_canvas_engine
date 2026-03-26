language: russian

# Шаг 20.4. Закрыть residual render/view hotspots по measured baseline

## 1. Change Mandate

Этот шаг закрывает measured residual hotspots render/view after `20.1-20.3`,
reducing remaining duplicate and mixed ownership without metric-only reshaping.

## 2. Change Boundary

### Included in the Change

- Residual hotspot reduction in `SceneViewInteractive` and `SceneView`.
- Residual render-local owner cleanup in `ScenePainter` and directly supporting
  render caches and helpers.
- Residual hotspot cleanup in `SceneSpatialIndex` and `node_geometry.dart`
  only where it is required to close the measured remaining work.

### Not Included in the Change

- Rebaseline-only and roadmap-only updates.
- Boundary-matrix work.
- Runtime orchestration work outside targeted residual support.
- Public API and transport contract changes.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/view/scene_view.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_frame.part.dart`
- `lib/src/render/scene_painter_node_renderer.part.dart`
- `lib/src/render/scene_painter_selection.part.dart`
- `lib/src/render/render_geometry_cache.dart`
- `lib/src/render/scene_grid_renderer.dart`
- `lib/src/render/cache/scene_static_layer_cache.dart`
- `lib/src/render/cache/scene_path_metrics_cache.dart`
- `lib/src/render/cache/scene_stroke_path_cache.dart`
- `lib/src/render/cache/scene_text_layout_cache.dart`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/node_geometry.dart`

### Test Files

- `test/view/**`
- `test/render/**`
- `test/core/scene_spatial_index_test.dart`
- `test/core/node_geometry_test.dart`
- `test/core/hit_test_candidate_bounds_test.dart`
- `test/render/render_hit_bounds_parity_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_20_4_residual_render_view_hotspot_closure.md`

### Analysis Area

- `lib/src/view/**`
- `lib/src/render/**`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/node_geometry.dart`
- `test/view/**`
- `test/render/**`
- `test/core/scene_spatial_index_test.dart`
- `test/core/node_geometry_test.dart`
- `test/core/hit_test_candidate_bounds_test.dart`
- `test/render/render_hit_bounds_parity_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific residual
  hotspot slice.
- Every modified test must be tied to a listed verification surface.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Residual hotspot closure must remove duplication or mixed ownership instead
   of relocating the same shape behind new wrappers.
2. View-layer cache lifecycle remains view-owned and must not move into
   controller or render global owners.
3. `ScenePainter` work remains render-local and must not introduce a generic
   renderer hierarchy.
4. Spatial-index and hit-test parity behavior remain protected.
5. Metric improvement is valid only when it follows from a real ownership or
   duplication reduction.

## 5. Result Requirements

1. Residual render/view hotspots after `20.1-20.3` are reduced without public
   render/view behavior drift.
2. Remaining duplicate or mixed ownership in the render/view seams is deleted
   rather than moved behind wrappers or cosmetic abstractions.
3. Post-`20.4` implementation state improves against the confirmed residual
   baseline of `23` `HIGH+` entries and `11` related clone clusters.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The confirmed residual baseline after `20.1-20.3` is:
  - `23` `HIGH+` entries in the render/view family
  - `11` clone clusters in `lib` touching render/view hotspots
- Residual metric hotspots are concentrated in:
  - `lib/src/view/scene_view_interactive.dart`
  - `lib/src/view/scene_view.dart`
  - `lib/src/render/scene_painter.dart`
  - `lib/src/render/scene_painter_node_renderer.part.dart`
  - `lib/src/render/scene_painter_selection.part.dart`
  - `lib/src/render/render_geometry_cache.dart`
  - `lib/src/render/scene_grid_renderer.dart`
  - `lib/src/render/cache/scene_static_layer_cache.dart`
  - `lib/src/core/scene_spatial_index.dart`
  - `lib/src/core/node_geometry.dart`
- Residual clone inventory touching the target family includes the
  `SceneViewInteractive` runtime seam, `ScenePainter` node and selection
  support seams, `render_geometry_cache.dart`, and `node_geometry.dart`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/render lib/src/view lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- MCP test runner: `test/render/render_hit_bounds_parity_test.dart`
- `dart run tool/check_import_boundaries.dart`

### 6.3 Protected States, Data, or Structures

- Render output behavior and selection overlay behavior.
- View-owned render-cache lifecycle.
- Spatial-index and hit-test parity behavior.
- The confirmed residual baseline used to justify this step.

### 6.4 Allowed Semantic Change Zones

- Interactive view-local ownership and orchestration inside
  `SceneViewInteractive` and `SceneView`.
- Residual render-local owner boundaries inside `ScenePainter` and directly
  supporting render caches and helpers.
- Residual geometry and spatial helper ownership where it is required to
  delete remaining duplicate or mixed responsibility.

### 6.8 Prohibited

- Introducing wrapper layers, base hierarchies, or helper indirection whose
  primary purpose is metric reduction.
- Moving the same duplicate body from one file to another without deleting the
  replaced duplication.
- Changing render, view, or parity-sensitive semantics solely to reduce counts.
- Reopening boundary-matrix or runtime-stack work outside targeted residual
  support.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must
   be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [ ] SceneView residual ownership is reduced

#### Slice Contract

Residual hotspot ownership in `SceneViewInteractive` and `SceneView` is reduced
without moving view-local responsibilities behind a new base hierarchy.

#### Change

Удалить remaining mixed or duplicated view-local ownership in
`scene_view_interactive.dart` and `scene_view.dart`, keeping the cache
lifecycle and interactive behavior view-owned.

#### Verification

- `dcm calculate-metrics lib/src/view/scene_view.dart lib/src/view/scene_view_interactive.dart --report-all`
- MCP test runner: `test/view`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The replaced mixed or duplicated view-local bodies are no longer present in
  the same form.

### Slice 2. [ ] ScenePainter residual owners are reduced

#### Slice Contract

Residual `ScenePainter` hotspots are reduced by deleting remaining mixed or
duplicated render-local ownership across the painter and its direct support
seams.

#### Change

Refine `scene_painter.dart` and its part files, touching direct render support
only where required to remove the measured residual hotspot shapes.

#### Verification

- `dcm calculate-metrics lib/src/render/scene_painter.dart lib/src/render/scene_painter_frame.part.dart lib/src/render/scene_painter_node_renderer.part.dart lib/src/render/scene_painter_selection.part.dart --report-all`
- MCP test runner: `test/render`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`

#### Closure Evidence

- Green run of the listed verifications.
- The replaced mixed or duplicated painter-local bodies are no longer present
  in the same form.

### Slice 3. [ ] Render helper residual duplicates are closed

#### Slice Contract

Residual helper hotspots in render caches, geometry, and grid support are
reduced through single owners instead of wrapper indirection.

#### Change

Adjust directly supporting render helpers and caches only where required to
delete the measured remaining duplicate or mixed ownership.

#### Verification

- `dcm calculate-metrics lib/src/render/render_geometry_cache.dart lib/src/render/scene_grid_renderer.dart lib/src/render/cache/scene_static_layer_cache.dart lib/src/render/cache/scene_path_metrics_cache.dart lib/src/render/cache/scene_stroke_path_cache.dart lib/src/render/cache/scene_text_layout_cache.dart --report-all`
- MCP test runner: `test/render`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`

#### Closure Evidence

- Green run of the listed verifications.
- The replaced helper duplication is deleted instead of reintroduced elsewhere.

### Slice 4. [ ] Core parity-sensitive residual hotspots are reduced

#### Slice Contract

Residual hotspots in `SceneSpatialIndex` and `node_geometry.dart` are reduced
without hit-test or spatial-query parity drift.

#### Change

Refine core helper ownership only where the measured residual baseline still
requires it and keep parity-sensitive behavior unchanged.

#### Verification

- `dcm calculate-metrics lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- MCP test runner: `test/render/render_hit_bounds_parity_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Spatial-index and hit-test parity remain green after the cleanup.

## 9. Final Verification

- `dcm calculate-metrics lib/src/render lib/src/view lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- MCP test runner: `test/render/render_hit_bounds_parity_test.dart`
- `dart run tool/check_import_boundaries.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
