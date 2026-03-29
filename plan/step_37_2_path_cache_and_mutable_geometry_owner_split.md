language: russian

# Шаг 37.2. Выделить path-cache и mutable geometry support из node entrypoints

## 1. Change Mandate

Этот шаг изолирует node-local support ownership around mutable stroke geometry
and `PathNode` cache resolution so that node entrypoints no longer own those
mixed support bodies directly.

## 2. Change Boundary

### Included in the Change

- Mutable stroke-geometry revision support beneath `StrokeNode`.
- `PathNode` local-path cache lifecycle, resolution, and diagnostics support.
- Minimal adaptation of node entrypoints required to delegate to the new
  focused support owners.

### Not Included in the Change

- Box-node and vector-node family decomposition targeted by step `37.1`.
- `text_layout.dart`, `action_events.dart`, and `id_generator.dart`.
- Reopening render/cache, spatial-index, or higher-layer production scope
  beyond direct verification.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/nodes.dart`

### Test Files

- `test/core/nodes_test.dart`
- `test/core/scene_spatial_index_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `plan/step_37_2_path_cache_and_mutable_geometry_owner_split.md`

### Analysis Area

- `lib/src/core/nodes.dart`
- `test/core/nodes_test.dart`
- `test/core/scene_spatial_index_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one node-support slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `StrokeNode.pointsRevision` remains the monotonic geometry invalidation
   signal for renderer caches.
2. `PathNode` local-path cache invalidates whenever `svgPathData` or `fillRule`
   changes.
3. Node entrypoint APIs remain behaviorally equivalent after the support-owner
   split.
4. This step does not move path or geometry support ownership into render or
   controller layers.

## 5. Result Requirements

1. Mutable stroke-geometry revision tracking no longer remains as a monolithic
   mixed support body inside the `nodes.dart` entrypoint area.
2. `PathNode` cache lifecycle, resolution, and diagnostics support no longer
   remain in the current mixed `PathNode` body shape.
3. No accepted residual hotspot after the step may belong to
   `_RevisionedOffsetList`
   or
   `PathNode._ensureLocalPathCache`
   in their current mixed form.
4. Render-cache invalidation, path-cache invalidation, and geometry parity
   remain equivalent.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `_RevisionedOffsetList` currently contributes `HIGH` `response-for-class` and
  `weighted-methods-per-class` hotspots inside `nodes.dart`.
- `PathNode._ensureLocalPathCache(...)` currently contributes a `HIGH`
  `source-lines-of-code` hotspot and a near-hot cyclomatic hotspot inside
  `nodes.dart`.
- Both hotspots are node-local support ownership and do not justify reopening
  node-family or higher-layer boundaries.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/core/nodes.dart --report-all`
- MCP test runner: `test/core/nodes_test.dart`
- MCP test runner: `test/core/scene_spatial_index_test.dart`
- MCP test runner:
  `test/render/render_geometry_cache_test.dart test/render/scene_stroke_path_cache_test.dart`
- `dart run tool/check_import_boundaries.dart`

### 6.3 Protected States, Data, or Structures

- `pointsRevision` invalidation behavior.
- `PathNode` cache invalidation behavior.
- Existing local/world geometry parity used by render and spatial-index
  consumers.

### 6.4 Allowed Semantic Change Zones

- Mutable stroke-geometry storage and revision support beneath `StrokeNode`.
- Path-local cache lifecycle and diagnostics support beneath `PathNode`.
- Minimal node-entrypoint delegation to the focused support owners.

### 6.8 Prohibited

- Reopening node-family decomposition work that belongs to `37.1`.
- Changing `pointsRevision` or path-cache semantics to improve metrics.
- Moving mutable geometry support or path-cache support into render, model, or
  controller code.
- Hiding the same support hotspot behind cosmetic wrappers inside `nodes.dart`.

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

### Slice 1. [x] Mutable stroke-geometry support owner is isolated

#### Slice Contract

Stroke mutable geometry storage and revision support no longer remain in the
current mixed support-owner form.

#### Change

Выделить focused mutable-geometry support owner beneath `StrokeNode` and
перевести node entrypoint на делегацию к нему.

#### Verification

- `dcm calculate-metrics lib/src/core/nodes.dart --report-all`
- MCP test runner: `test/core/nodes_test.dart`
- MCP test runner:
  `test/render/render_geometry_cache_test.dart test/render/scene_stroke_path_cache_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `pointsRevision` invalidation remains green after the support-owner split.

### Slice 2. [x] Path-local cache owner is isolated

#### Slice Contract

`PathNode` no longer keeps cache lifecycle, resolution, and diagnostics in the
current mixed owner body.

#### Change

Выделить focused path-cache owner beneath `PathNode` and перевести existing
entrypoints на explicit delegation without changing cache invalidation
semantics.

#### Verification

- `dcm calculate-metrics lib/src/core/nodes.dart --report-all`
- MCP test runner: `test/core/nodes_test.dart test/core/scene_spatial_index_test.dart`
- MCP test runner: `test/render/render_geometry_cache_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `PathNode` cache invalidation proofs stay green after the support-owner
  split.

## 9. Final Verification

- `dcm calculate-metrics lib/src/core/nodes.dart --report-all`
- MCP test runner: `test/core/nodes_test.dart test/core/scene_spatial_index_test.dart`
- MCP test runner:
  `test/render/render_geometry_cache_test.dart test/render/scene_stroke_path_cache_test.dart`
- `dart run tool/check_import_boundaries.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
