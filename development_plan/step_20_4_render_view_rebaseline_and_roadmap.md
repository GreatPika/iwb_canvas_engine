language: russian

# Шаг 20.4. Переснять baseline render/view hotspot closure и обновить roadmap

## 1. Change Mandate

Этот шаг переснимает post-step baseline для render/view hotspots и обновляет
roadmap по новой measured reality without reopening steps 18 or 19.

## 2. Change Boundary

### Included in the Change

- Повторный configured DCM baseline по render/view family.
- Повторный clone inventory по `lib`.
- Обновление roadmap and step-docs по measured residual render/view work.

### Not Included in the Change

- Production code under `lib/**`
- Boundary-matrix or runtime-stack implementation work

## 3. File Map and Analysis Areas

### Implementation Files

- `development_plan/step_20_render_view_secondary_hotspots.md`
- `development_plan/step_20_4_render_view_rebaseline_and_roadmap.md`
- `DEVELOPMENT_PLAN.md`

### Fixture and Supporting Data Files

- `analysis_options.yaml`

### Analysis Area

- `lib/**`
- `development_plan/step_20*.md`
- `DEVELOPMENT_PLAN.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified planning file must be tied to one measured baseline or one
  roadmap correction.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Rebaseline uses the same instruments as the execution step.
2. This step does not edit production code.
3. Residual render/view work is recorded from measured data only.

## 5. Result Requirements

1. Post-step render/view baseline is captured with the same instruments as the
   starting baseline of step 20.
2. Roadmap reflects only the residual render/view work that factually remains
   after `20.1-20.3`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Starting confirmed render/view baseline for step 20 is:
  - `18` `HIGH+` entries in the render/view family
  - `10` clone clusters in `lib` touching render/view hotspots

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/render lib/src/view lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- `dart run tool/check_import_boundaries.dart`

### 6.3 Protected States, Data, or Structures

- The recorded starting baseline of step 20.
- The separation between render/view work and previous steps.

### 6.8 Prohibited

- Editing production code under `lib/**`.
- Declaring residual work closed without a measured baseline.

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

### Slice 1. [ ] Post-render/view baseline is recaptured

#### Slice Contract

Render/view baseline is recaptured with the same instruments and compared to
the starting baseline of step 20.

#### Change

Переснять render/view baseline and prepare a direct comparison against the
starting values of step 20.

#### Verification

- `dcm calculate-metrics lib/src/render lib/src/view lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Output explicitly compares starting and post-step render/view baseline.

### Slice 2. [ ] Roadmap reflects only measured residual render/view work

#### Slice Contract

Planning documents reflect only the residual render/view work that factually
remains after `20.1-20.3`.

#### Change

Обновить `DEVELOPMENT_PLAN.md` and `development_plan/step_20*.md` по
измеренному результату render/view rebaseline.

#### Verification

- `dcm calculate-metrics lib/src/render lib/src/view lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Planning files no longer carry stale render/view assumptions that were
  already removed.

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
