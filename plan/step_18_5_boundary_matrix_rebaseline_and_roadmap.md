language: russian

# Шаг 18.5. Переснять baseline boundary matrix compression и обновить roadmap

## 1. Change Mandate

Этот шаг переснимает post-compression baseline для boundary matrix и обновляет
roadmap по новой измеренной реальности без возврата к устаревшим допущениям.

## 2. Change Boundary

### Included in the Change

- Повторный clone inventory по `lib/**` в cluster-mode.
- Повторный configured DCM baseline по `lib/src/contract` и
  `lib/src/model`.
- Обновление roadmap и step-документов по измеренным остаточным hot spots.

### Not Included in the Change

- Production code under `lib/**`
- Runtime orchestration or render/view implementation work
- Public contract changes

## 3. File Map and Analysis Areas

### Implementation Files

- `plan/step_18_schema_first_boundary_matrix_compression.md`
- `plan/step_18_5_boundary_matrix_rebaseline_and_roadmap.md`
- `PLAN.md`

### Fixture and Supporting Data Files

- `analysis_options.yaml`

### Analysis Area

- `lib/**`
- `plan/step_18*.md`
- `PLAN.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified planning file must be tied to one measured baseline or one
  roadmap correction.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Rebaseline uses the same instruments as the execution step:
   `dcm calculate-metrics ... --report-all` and
   `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`.
2. This step does not edit production code.
3. Residual work is recorded from measured data only.

## 5. Result Requirements

1. Post-step boundary matrix baseline is captured with the same instruments as
   the starting baseline of step 18.
2. Roadmap reflects only the measured residual work that remains after
   `18.1-18.4`.
3. Stale assumptions about already removed boundary-matrix families are not
   carried forward.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Starting confirmed boundary baseline for step 18 is:
  - `28` `HIGH+` entries attributed to the boundary-matrix family
  - `19` clone clusters in `lib` involving
    `node_boundary_schema`, `fast_path`, `scene_node_boundary_mapping`,
    `scene_builder`, or `scene_value_validation`

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`

### 6.3 Protected States, Data, or Structures

- The recorded starting baseline of step 18.
- The separation between boundary-matrix work and downstream runtime/render
  work.

### 6.8 Prohibited

- Editing production code under `lib/**`.
- Declaring residual work closed without a new measured baseline.

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

### Slice 1. [x] Post-compression baseline is recaptured

#### Slice Contract

Boundary matrix baseline is recaptured with the same instruments and compared
to the starting baseline of step 18.

#### Change

Переснять cluster-mode clone inventory and configured DCM baseline and
подготовить прямое сравнение со стартовыми значениями шага 18.

#### Verification

- `dcm calculate-metrics lib/src/contract lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`

#### Closure Evidence

- Green run of the listed verifications.
- Output explicitly compares the starting and post-step baseline of step 18.
- Measured configured DCM baseline for the boundary-matrix family:
  - `HIGH+ entries: 28 -> 11`
- Measured clone baseline for boundary-matrix families in `lib`:
  - `related clone clusters: 19 -> 18`

### Slice 2. [x] Roadmap reflects only measured residual work

#### Slice Contract

Planning documents reflect only the residual boundary-matrix work that
factually remains after `18.1-18.4`.

#### Change

Обновить `PLAN.md` and `plan/step_18*.md` по
измеренному результату rebaseline и передать remaining live boundary-matrix
clusters в corrective step `18.6`.

#### Verification

- `dcm calculate-metrics lib/src/contract lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`

#### Closure Evidence

- Green run of the listed verifications.
- Planning files no longer carry stale assumptions about already removed
  boundary-matrix families.
- Residual boundary-matrix work is now explicitly assigned to step `18.6` and
  includes the live contract family in:
  - `lib/src/contract/internal/node_patch_fast_path.part.dart`
  - `lib/src/contract/internal/node_spec_fast_path.part.dart`
  - `lib/src/contract/internal/snapshot_fast_path.part.dart`
  - `lib/src/contract/node_patch.dart`
  - `lib/src/contract/node_spec.dart`
  - `lib/src/contract/snapshot.dart`
- Residual boundary-matrix work is also assigned to the decode/import family
  in:
  - `lib/src/model/scene_builder.dart`
  - `lib/src/model/scene_builder_contract_support.dart`
  - `lib/src/model/scene_builder_decode_json.part.dart`
  - `lib/src/model/scene_builder_json_require.part.dart`
- Residual boundary-matrix work is also assigned to the mapping family in:
  - `lib/src/model/scene_node_boundary_mapping.dart`
  - `lib/src/model/scene_node_boundary_mapping_common.part.dart`
  - `lib/src/model/scene_node_boundary_mapping_from_snapshot.part.dart`
  - `lib/src/model/scene_node_boundary_mapping_from_spec.part.dart`
  - `lib/src/model/scene_node_boundary_mapping_to_snapshot.part.dart`

## 9. Final Verification

- `dcm calculate-metrics lib/src/contract lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
