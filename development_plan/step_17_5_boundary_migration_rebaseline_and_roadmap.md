language: russian

# Шаг 17.5. Переснять baseline boundary migration и обновить roadmap

## 1. Change Mandate

Этот шаг переснимает post-schema-first baseline по `lib/**`, сравнивает его со
стартовым baseline шага `17` и обновляет roadmap так, чтобы дальнейшая работа
исходила из новой измеренной реальности, а не из старого manual cleanup плана.

## 2. Change Boundary

### Included in the Change

- Повторный full graph clone inventory по `lib/**` в cluster-режиме.
- Повторный configured DCM baseline по `lib/**`.
- Сравнение post-step baseline со стартовым baseline шага `17`.
- Обновление roadmap и step-документов по фактически оставшимся hot spots.
- Явная фиксация residual work, если оно осталось после boundary migration.

### Not Included in the Change

- Production code under `lib/**`
- Test implementation
- Public contract changes

## 3. File Map and Analysis Areas

### Implementation Files

- `development_plan/step_17_5_boundary_migration_rebaseline_and_roadmap.md`
- `development_plan/step_17_schema_first_boundary_transition.md`
- `DEVELOPMENT_PLAN.md`

### Fixture and Supporting Data Files

- `analysis_options.yaml`

### Analysis Area

- `lib/**`
- `development_plan/step_17_schema_first_boundary_transition.md`
- `development_plan/step_17_5_boundary_migration_rebaseline_and_roadmap.md`
- `DEVELOPMENT_PLAN.md`
- `analysis_options.yaml`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified planning file must be tied to a specific slice.
- Every added comparison, baseline note, or residual-work entry must be tied to
  a concrete verification output.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Clone baseline uses only graph / clusters mode:
   `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`.
2. DCM baseline uses only the configured thresholds from `analysis_options.yaml`.
3. Residual runtime hot spots outside `contract/model/serialization` after the
   rebaseline are recorded as separate residual work and are not pulled
   retroactively into the scope of `17.1-17.4`.
4. This step does not restore the old `16.x` seam-by-seam program as a new
   execution path without an explicit post-step baseline.

## 5. Result Requirements

1. The post-schema-first baseline is captured with the same instruments as the
   starting baseline of step `17`.
2. The roadmap describes only the hot spots that factually remain after the
   boundary migration.
3. Residual runtime hot spots outside `contract/model/serialization` are not
   hidden and are not marked as closed without new data.
4. The rebaseline does not restore the old `16.x` seam-by-seam program as the
   active execution path.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The starting graph baseline for step `17` is fixed as:
  - `clusters = 63`
  - `scannedFiles = 115`
  - `scannedBlocks = 602`
- The starting configured DCM baseline for step `17` is fixed as:
  - `number-of-parameters = 40`
  - `source-lines-of-code = 21`
  - `cyclomatic-complexity = 5`
  - `maximum-nesting-level = 0`
- Confirmed residual hot spots outside the boundary-migration scope are:
  - `lib/src/controller/scene_controller.dart`
  - `lib/src/controller/scene_invariants.dart`
  - `lib/src/core/node_geometry.dart`
  - `lib/src/render/scene_painter.dart`
- Pair-mode clone output is not an acceptance gate for this step.

### 6.2 Target Verification Units

- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dcm calculate-metrics lib`

### 6.3 Protected States, Data, or Structures

- The recorded starting baseline values of step `17`.
- The separation between boundary migration work in `17.1-17.4` and residual
  work outside `contract/model/serialization`.
- The current roadmap ownership model that assigns one seam per step.

### 6.4 Allowed Semantic Change Zones

- Baseline capture and comparison outputs for `lib/**`
- Roadmap wording and step status derived from the measured post-step baseline
- Residual-work notes for confirmed hot spots outside the migrated seam

### 6.8 Prohibited

- Editing production code under `lib/**` as part of this rebaseline step.
- Using pair-mode clone output as the acceptance signal.
- Declaring residual hot spots closed without new baseline data.
- Reinstating the old `16.x` seam-by-seam execution program without an explicit
  post-step comparison.

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

### Slice 1. [x] Post-schema-first baseline is recaptured with step 17 instruments

#### Slice Contract

For `lib/**`, the post-schema-first graph clone inventory and configured DCM
baseline are recaptured with the same instruments and thresholds as the
starting baseline of step `17`.

#### Change

Переснять full graph clone inventory в cluster-режиме и configured DCM
baseline по `lib/**`, затем подготовить прямое сравнение со стартовыми
значениями шага `17`.

#### Verification

- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dcm calculate-metrics lib`

#### Closure Evidence

- Green run of the listed verifications.
- Output explicitly compares the starting and post-step graph baseline and the
  starting and post-step configured DCM baseline.
- Measured graph baseline for `lib/**`:
  - `clusters: 63 -> 58`
  - `scannedFiles: 115 -> 125`
  - `scannedBlocks: 602 -> 661`
- Measured configured DCM baseline for `lib/**`:
  - `number-of-parameters: 40 -> 38`
  - `source-lines-of-code: 21 -> 15`
  - `cyclomatic-complexity: 5 -> 4`
  - `maximum-nesting-level: 0 -> 0`

### Slice 2. [x] Roadmap reflects only the measured residual work

#### Slice Contract

Roadmap and related step documents reflect only the hot spots that factually
remain after the boundary migration and do not carry forward stale assumptions
about already-removed boundary duplication.

#### Change

Обновить `development_plan/step_17_schema_first_boundary_transition.md`,
`development_plan/step_17_5_boundary_migration_rebaseline_and_roadmap.md`,
`DEVELOPMENT_PLAN.md` и любые реально затронутые planning documents по
результату rebaseline. Явно зафиксировать residual work, если оно осталось.

#### Verification

- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dcm calculate-metrics lib`

#### Closure Evidence

- Green run of the listed verifications.
- Roadmap no longer contains stale boundary-duplication assumptions that were
  already removed by `17.1-17.4`.
- Residual runtime hot spots outside `contract/model/serialization` remain
  explicitly tracked only for:
  - `lib/src/controller/scene_controller.dart`
  - `lib/src/controller/scene_invariants.dart`
  - `lib/src/core/node_geometry.dart`
  - `lib/src/render/scene_painter.dart`

## 9. Final Verification

- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dcm calculate-metrics lib`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
