language: russian

# Шаг 20.1. Разрезать ScenePainter на render-local owners без нового renderer hierarchy

## 1. Change Mandate

Этот шаг разрезает `ScenePainter` на render-local owners without introducing a
new generic renderer hierarchy.

## 2. Change Boundary

### Included in the Change

- `lib/src/render/scene_painter.dart`
- `lib/src/render/render_geometry_cache.dart`
- `lib/src/render/cache/**` when required by the slice

### Not Included in the Change

- View-side cache lifecycle
- `SceneSpatialIndex`
- Runtime orchestration work

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/render/scene_painter.dart`
- `lib/src/render/render_geometry_cache.dart`
- `lib/src/render/cache/scene_path_metrics_cache.dart`
- `lib/src/render/cache/scene_static_layer_cache.dart`
- `lib/src/render/cache/scene_stroke_path_cache.dart`
- `lib/src/render/cache/scene_text_layout_cache.dart`

### Test Files

- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_render_caches_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_path_metrics_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/render/scene_static_layer_cache_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_20_1_scene_painter_render_owner_decomposition.md`

### Analysis Area

- `lib/src/render/**`
- `test/render/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one render-local slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step must not introduce a generic renderer hierarchy.
2. Render output and selection overlay behavior remain protected.
3. Cache ownership remains render-local or view-owned according to current
   contracts.

## 5. Result Requirements

1. `ScenePainter` no longer keeps the current mixed render-local ownership in
   one class body.
2. Render behavior remains equivalent.
3. Current `ScenePainter` hotspot improves against the confirmed baseline of
   `9` `HIGH+` entries across the file family and class metrics
   `CBO 31`, `RFC 75`, `WMC 103`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `scene_painter.dart` currently mixes frame construction, visible-node
  iteration, selection drawing, and per-node draw families in one owner.
- The step may introduce render-local owners or helpers but not a generic
  renderer hierarchy.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/render/scene_painter.dart lib/src/render/render_geometry_cache.dart lib/src/render/cache/scene_path_metrics_cache.dart lib/src/render/cache/scene_static_layer_cache.dart lib/src/render/cache/scene_stroke_path_cache.dart lib/src/render/cache/scene_text_layout_cache.dart --report-all`
- MCP test runner: `test/render/scene_painter_test.dart test/render/scene_painter_frame_contract_test.dart test/render/scene_painter_bounds_contract_test.dart`
- MCP test runner: `test/render/render_geometry_cache_test.dart test/render/scene_render_caches_test.dart test/render/scene_stroke_path_cache_test.dart test/render/scene_path_metrics_cache_test.dart test/render/scene_text_layout_cache_test.dart test/render/scene_static_layer_cache_test.dart`

### 6.3 Protected States, Data, or Structures

- Render output behavior.
- Selection overlay behavior.
- Render cache behavior.

### 6.4 Allowed Semantic Change Zones

- Frame construction ownership.
- Selection rendering ownership.
- Per-node draw family ownership.
- Render-local helper ownership.

### 6.8 Prohibited

- Introducing a generic renderer hierarchy.
- Moving view-side ownership into the render seam.
- Changing render semantics to improve metrics.

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

### Slice 1. [x] Frame and selection ownership is separated

#### Slice Contract

Frame construction and selection rendering are owned separately from the rest
of `ScenePainter`.

#### Change

Вынести frame / selection responsibilities from the current mixed painter body
into render-local owners and remove the replaced mixed logic.

#### Verification

- `dcm calculate-metrics lib/src/render/scene_painter.dart --report-all`
- MCP test runner: `test/render/scene_painter_frame_contract_test.dart test/render/scene_painter_bounds_contract_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The replaced mixed frame / selection body is no longer present in the same
  form.

### Slice 2. [x] Per-node draw ownership is separated

#### Slice Contract

Per-node draw families are separated into render-local owners without a generic
renderer hierarchy.

#### Change

Разнести per-node draw responsibilities and supporting render-local helpers out
of the mixed painter body.

#### Verification

- `dcm calculate-metrics lib/src/render/scene_painter.dart lib/src/render/render_geometry_cache.dart lib/src/render/cache/scene_path_metrics_cache.dart lib/src/render/cache/scene_static_layer_cache.dart lib/src/render/cache/scene_stroke_path_cache.dart lib/src/render/cache/scene_text_layout_cache.dart --report-all`
- MCP test runner: `test/render/scene_painter_test.dart`
- MCP test runner: `test/render/render_geometry_cache_test.dart test/render/scene_render_caches_test.dart test/render/scene_stroke_path_cache_test.dart test/render/scene_path_metrics_cache_test.dart test/render/scene_text_layout_cache_test.dart test/render/scene_static_layer_cache_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `ScenePainter` no longer keeps the replaced mixed per-node draw body.

## 9. Final Verification

- `dcm calculate-metrics lib/src/render/scene_painter.dart lib/src/render/render_geometry_cache.dart lib/src/render/cache/scene_path_metrics_cache.dart lib/src/render/cache/scene_static_layer_cache.dart lib/src/render/cache/scene_stroke_path_cache.dart lib/src/render/cache/scene_text_layout_cache.dart --report-all`
- MCP test runner: `test/render/scene_painter_test.dart test/render/scene_painter_frame_contract_test.dart test/render/scene_painter_bounds_contract_test.dart`
- MCP test runner: `test/render/render_geometry_cache_test.dart test/render/scene_render_caches_test.dart test/render/scene_stroke_path_cache_test.dart test/render/scene_path_metrics_cache_test.dart test/render/scene_text_layout_cache_test.dart test/render/scene_static_layer_cache_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
