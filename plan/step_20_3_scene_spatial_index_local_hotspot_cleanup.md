language: russian

# Шаг 20.3. Упростить local hotspot-ы SceneSpatialIndex без drift hit-test parity

## 1. Change Mandate

Этот шаг упрощает local hotspots around `SceneSpatialIndex` without changing
spatial-query or hit-test parity behavior.

## 2. Change Boundary

### Included in the Change

- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/node_geometry.dart`

### Not Included in the Change

- Render/view cache lifecycle
- Controller runtime stack
- Boundary-matrix work

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/node_geometry.dart`

### Test Files

- `test/core/scene_spatial_index_test.dart`
- `test/core/node_geometry_test.dart`
- `test/core/hit_test_candidate_bounds_test.dart`
- `test/render/render_hit_bounds_parity_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `plan/step_20_3_scene_spatial_index_local_hotspot_cleanup.md`

### Analysis Area

- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/node_geometry.dart`
- `test/core/scene_spatial_index_test.dart`
- `test/core/node_geometry_test.dart`
- `test/core/hit_test_candidate_bounds_test.dart`
- `test/render/render_hit_bounds_parity_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one spatial-index slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Spatial-index and hit-test parity behavior remain protected.
2. This step must not improve metrics by weakening fallback or invalidation
   behavior.
3. Local cleanup must stay inside the core spatial-index seam.

## 5. Result Requirements

1. `SceneSpatialIndex` no longer keeps its current mixed local hotspot shape in
   one owner body.
2. Spatial-query and hit-test parity behavior remain equivalent.
3. Current hotspot improves against the confirmed baseline:
   `RFC 60`, `WMC 107`, and `3 HIGH+` entries in `scene_spatial_index.dart`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The current hotspot is concentrated in `SceneSpatialIndex` rebuild, query,
  incremental apply, and local helper ownership.
- The step may touch `node_geometry.dart` only where parity or local support
  makes it necessary.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- MCP test runner: `test/render/render_hit_bounds_parity_test.dart`
- `dart run tool/check_import_boundaries.dart`

### 6.3 Protected States, Data, or Structures

- Spatial-query behavior.
- Fallback and invalidation behavior.
- Hit-test parity behavior.

### 6.4 Allowed Semantic Change Zones

- Query and rebuild local ownership inside `SceneSpatialIndex`
- Incremental-apply local ownership inside `SceneSpatialIndex`
- Local parity-support helpers in `node_geometry.dart`

### 6.8 Prohibited

- Changing parity behavior to reduce metrics.
- Moving unrelated render or controller work into this step.
- Hiding the same mixed hotspot behind cosmetic wrappers.

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

### Slice 1. [x] Query and rebuild local ownership is decomposed

#### Slice Contract

Query and rebuild ownership in `SceneSpatialIndex` is decomposed into smaller
local owners without changing behavior.

#### Change

Разрезать query and rebuild local ownership in `scene_spatial_index.dart` and
remove the replaced mixed hotspot body.

#### Verification

- `dcm calculate-metrics lib/src/core/scene_spatial_index.dart --report-all`
- MCP test runner: `test/core/scene_spatial_index_test.dart`
- MCP test runner: `test/core/hit_test_candidate_bounds_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The replaced mixed query / rebuild hotspot is no longer present in the same
  form.

### Slice 2. [x] Incremental and parity support remains exact after the split

#### Slice Contract

Incremental update and parity support remain exact after the local ownership
split.

#### Change

Align incremental-apply and parity-support helpers with the new ownership
shape.

#### Verification

- `dcm calculate-metrics lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart`
- MCP test runner: `test/render/render_hit_bounds_parity_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Spatial-index parity remains green after the split.

## 9. Final Verification

- `dcm calculate-metrics lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- MCP test runner: `test/render/render_hit_bounds_parity_test.dart`
- `dart run tool/check_import_boundaries.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
