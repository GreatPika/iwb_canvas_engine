language: russian

# Шаг 20.2. Свести lifecycle render caches в SceneViewCore и SceneViewInteractive

## 1. Change Mandate

Этот шаг сводит duplicated render-cache lifecycle between `SceneViewCore` and
`SceneViewInteractive` without moving cache ownership out of the view layer.

## 2. Change Boundary

### Included in the Change

- `lib/src/view/scene_view.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/render/scene_render_caches.dart`
- `lib/src/render/render_geometry_cache.dart`

### Not Included in the Change

- `ScenePainter`
- `SceneSpatialIndex`
- Interactive runtime beneath the facade

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/view/scene_view.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/render/scene_render_caches.dart`
- `lib/src/render/render_geometry_cache.dart`

### Test Files

- `test/view/scene_view_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_pointer_router_test.dart`
- `test/render/scene_render_caches_test.dart`
- `test/render/render_geometry_cache_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_20_2_scene_view_render_cache_lifecycle_consolidation.md`

### Analysis Area

- `lib/src/view/**`
- `lib/src/render/scene_render_caches.dart`
- `lib/src/render/render_geometry_cache.dart`
- `test/view/**`
- `test/render/scene_render_caches_test.dart`
- `test/render/render_geometry_cache_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one view-lifecycle slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Render-cache lifecycle remains view-owned.
2. This step must not introduce a base widget hierarchy as a cosmetic
   abstraction.
3. Interactive host admission and pointer-router ownership remain outside this
   step unless strictly required by the cache lifecycle seam.

## 5. Result Requirements

1. `SceneViewCore` and `SceneViewInteractive` no longer keep duplicated
   render-cache lifecycle ownership in parallel.
2. View behavior remains equivalent.
3. Current hotspots improve against the confirmed baseline:
   `scene_view_interactive.dart = 4 HIGH+`, `scene_view.dart = 1 HIGH+`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current duplication includes render-cache lifecycle, debug cache accessors,
  cache recreation, and controller epoch invalidation across
  `scene_view.dart` and `scene_view_interactive.dart`.
- The step must consolidate lifecycle ownership without moving it out of the
  view layer.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/view/scene_view.dart lib/src/view/scene_view_interactive.dart lib/src/render/scene_render_caches.dart lib/src/render/render_geometry_cache.dart --report-all`
- MCP test runner: `test/view/scene_view_test.dart test/view/scene_view_interactive_test.dart test/view/scene_view_pointer_router_test.dart`
- MCP test runner: `test/render/scene_render_caches_test.dart test/render/render_geometry_cache_test.dart`
- `dart run tool/check_import_boundaries.dart`

### 6.3 Protected States, Data, or Structures

- View-owned render-cache lifecycle.
- Interactive host behavior exposed through the current views.
- Debug cache access behavior.

### 6.4 Allowed Semantic Change Zones

- Cache lifecycle ownership in `SceneViewCore`
- Cache lifecycle ownership in `SceneViewInteractive`
- Shared view-local render-cache support

### 6.8 Prohibited

- Moving cache lifecycle into controller or render global owners.
- Introducing a base widget hierarchy as a metric-only abstraction.
- Reopening pointer-host admission work beyond targeted support.

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

### Slice 1. [ ] One view-owned cache lifecycle path exists

#### Slice Contract

The two view widgets consume one consolidated view-owned cache lifecycle path.

#### Change

Свести duplicated cache lifecycle in `scene_view.dart` and
`scene_view_interactive.dart` to one consolidated view-owned path and remove
the replaced duplicates.

#### Verification

- `dcm calculate-metrics lib/src/view/scene_view.dart lib/src/view/scene_view_interactive.dart lib/src/render/scene_render_caches.dart lib/src/render/render_geometry_cache.dart --report-all`
- MCP test runner: `test/view/scene_view_test.dart test/view/scene_view_interactive_test.dart`
- MCP test runner: `test/render/scene_render_caches_test.dart test/render/render_geometry_cache_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The replaced duplicated cache lifecycle bodies are no longer present in both
  view owners.

### Slice 2. [ ] View semantics remain exact after consolidation

#### Slice Contract

View semantics remain exact after lifecycle consolidation.

#### Change

Align remaining view-local debug access and pointer-router interaction with the
new consolidated lifecycle shape.

#### Verification

- MCP test runner: `test/view/scene_view_test.dart test/view/scene_view_interactive_test.dart test/view/scene_view_pointer_router_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- View-level cache lifecycle remains view-owned after the consolidation.

## 9. Final Verification

- `dcm calculate-metrics lib/src/view/scene_view.dart lib/src/view/scene_view_interactive.dart lib/src/render/scene_render_caches.dart lib/src/render/render_geometry_cache.dart --report-all`
- MCP test runner: `test/view/scene_view_test.dart test/view/scene_view_interactive_test.dart test/view/scene_view_pointer_router_test.dart`
- MCP test runner: `test/render/scene_render_caches_test.dart test/render/render_geometry_cache_test.dart`
- `dart run tool/check_import_boundaries.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
