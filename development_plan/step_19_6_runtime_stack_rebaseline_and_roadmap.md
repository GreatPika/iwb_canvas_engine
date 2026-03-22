language: russian

# Шаг 19.6. Переснять baseline runtime orchestration stack и обновить roadmap

## 1. Change Mandate

Этот шаг переснимает post-stabilization baseline для runtime stack и обновляет
roadmap по новой измеренной реальности без возврата к старым ручным cleanup
предположениям.

## 2. Change Boundary

### Included in the Change

- Повторный configured DCM baseline по `lib/src/controller` и
  `lib/src/interactive`.
- Повторный clone inventory по `lib`.
- Обновление roadmap and step-docs по измеренным residual hot spots runtime
  stack.

### Not Included in the Change

- Production code under `lib/**`
- Boundary-matrix work
- Render/view implementation work

## 3. File Map and Analysis Areas

### Implementation Files

- `development_plan/step_19_runtime_orchestration_stack_stabilization.md`
- `development_plan/step_19_6_runtime_stack_rebaseline_and_roadmap.md`
- `DEVELOPMENT_PLAN.md`

### Fixture and Supporting Data Files

- `analysis_options.yaml`

### Analysis Area

- `lib/**`
- `development_plan/step_19*.md`
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

1. Rebaseline uses the same runtime-step instruments as the execution step.
2. This step does not edit production code.
3. Residual runtime work is recorded from measured data only.

## 5. Result Requirements

1. Post-step runtime baseline is captured with the same instruments as the
   starting baseline of step 19.
2. Roadmap reflects only the measured residual runtime-stack work after
   `19.1-19.5`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Starting confirmed runtime baseline for step 19 is:
  - `25` `HIGH+` entries across the runtime stack files listed in step 19
  - `7` clone clusters in `lib` touching the runtime-stack family

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller lib/src/interactive --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

### 6.3 Protected States, Data, or Structures

- The recorded starting baseline of step 19.
- The separation between runtime-stack work and downstream render/view work.

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

### Slice 1. [ ] Post-runtime baseline is recaptured

#### Slice Contract

Runtime baseline is recaptured with the same instruments and compared to the
starting baseline of step 19.

#### Change

Переснять runtime-stack baseline and prepare a direct comparison against the
starting values of step 19.

#### Verification

- `dcm calculate-metrics lib/src/controller lib/src/interactive --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Output explicitly compares starting and post-step runtime baseline.

### Slice 2. [ ] Roadmap reflects only measured residual runtime work

#### Slice Contract

Planning documents reflect only the residual runtime-stack work that factually
remains after `19.1-19.5`.

#### Change

Обновить `DEVELOPMENT_PLAN.md` and `development_plan/step_19*.md` по
измеренному результату runtime rebaseline.

#### Verification

- `dcm calculate-metrics lib/src/controller lib/src/interactive --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Planning files no longer carry stale runtime-stack assumptions that were
  already removed.

## 9. Final Verification

- `dcm calculate-metrics lib/src/controller lib/src/interactive --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
