language: russian

# Шаг 20.5. Переснять baseline render/view hotspot closure и обновить roadmap

## 1. Change Mandate

Этот шаг переснимает post-step baseline для render/view hotspots after `20.4`
and обновляет roadmap по measured residual reality without reopening steps 18
or 19.

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
- `development_plan/step_20_4_residual_render_view_hotspot_closure.md`
- `development_plan/step_20_5_render_view_rebaseline_and_roadmap.md`
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

1. Post-step render/view baseline is captured with the same instruments as
   `20.4` execution verification.
2. Measured residual reality after `20.4` is recorded as `13` `HIGH+` entries
   and `8` related clone clusters.
3. Roadmap reflects only the residual render/view work that factually remains
   after `20.4`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- This rebaseline records the current measured residual reality after `20.4`:
  - `13` `HIGH+` entries in the configured render/view family
  - `8` clone clusters touching the target render/view zone
- Any pre-rebaseline `23 / 11` references in older planning documents are
  treated as stale assumptions and must not remain recorded as the current
  post-`20.4` state.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/render lib/src/view lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- MCP test runner: `test/render/render_hit_bounds_parity_test.dart`
- `dart run tool/check_import_boundaries.dart`

### 6.3 Protected States, Data, or Structures

- The measured post-`20.4` residual baseline captured by this step.
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

### Slice 1. [x] Post-render/view baseline is recaptured

#### Slice Contract

Render/view baseline is recaptured with the same instruments and recorded as
the current post-`20.4` measured state.

#### Change

Переснять render/view baseline and record the current measured state for the
render/view family and target clone inventory.

#### Verification

- `dcm calculate-metrics lib/src/render lib/src/view lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- MCP test runner: `test/render/render_hit_bounds_parity_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Output records the current measured residual baseline as `13` `HIGH+`
  entries and `8` related clone clusters.

### Slice 2. [x] Roadmap reflects only measured residual render/view work

#### Slice Contract

Planning documents reflect only the residual render/view work that factually
remains after `20.4`, based on the measured `13 / 8` rebaseline.

#### Change

Обновить `DEVELOPMENT_PLAN.md` and `development_plan/step_20*.md` по
измеренному результату render/view rebaseline and leave the remaining
structural work open as follow-up.

#### Verification

- `dcm calculate-metrics lib/src/render lib/src/view lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/core/scene_spatial_index_test.dart test/core/node_geometry_test.dart test/core/hit_test_candidate_bounds_test.dart`
- MCP test runner: `test/render/render_hit_bounds_parity_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Planning files no longer carry stale `23 / 11` assumptions as the current
  post-`20.4` reality.
- Remaining render/view work is opened only where it factually remains after
  the measured rebaseline.

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
