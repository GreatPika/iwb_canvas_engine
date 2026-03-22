language: russian

# Шаг 19.1. Разрезать commit/post-commit orchestration в SceneControllerCore

## 1. Change Mandate

Этот шаг разрезает commit и post-commit orchestration в `SceneControllerCore`,
чтобы owner commit lifecycle не смешивал scheduling, signal delivery, and
notify glue в одной unit.

## 2. Change Boundary

### Included in the Change

- `lib/src/controller/scene_controller.dart`
- `lib/src/controller/internal/repaint_flag.dart`
- `lib/src/controller/internal/signals_buffer.dart`

### Not Included in the Change

- `SceneWriter`, `MutationExecutor`, and `TxnContext`
- Invariant sweep decomposition
- Interactive facade thinning

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/controller/scene_controller.dart`
- `lib/src/controller/internal/repaint_flag.dart`
- `lib/src/controller/internal/signals_buffer.dart`

### Test Files

- `test/controller/core/scene_controller_commit_effects_test.dart`
- `test/controller/core/scene_controller_writer_lifecycle_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/core/scene_controller_signals_delivery_test.dart`
- `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_19_1_scene_controller_core_commit_orchestration_split.md`

### Analysis Area

- `lib/src/controller/scene_controller.dart`
- `lib/src/controller/internal/**`
- `test/controller/core/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one commit-lifecycle slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Public controller behavior remains equivalent.
2. Signal ordering relative to notify remains protected.
3. Dispose fail-fast behavior remains protected.
4. This step must not introduce a second post-commit owner.

## 5. Result Requirements

1. `SceneControllerCore` no longer mixes commit execution and post-commit
   scheduling glue in the same owner body.
2. Signal emission, notify coalescing, and commit behavior stay equivalent.
3. The current `scene_controller.dart` hotspot improves against the confirmed
   baseline of `9` `HIGH+` entries.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current confirmed hotspot in `scene_controller.dart` is:
  `imports 28`, `CBO 34`, `RFC 70`, `WMC 90`.
- Current exact duplication includes `_scheduleNotify()` and surrounding
  post-commit scheduling glue.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller/scene_controller.dart lib/src/controller/internal/repaint_flag.dart lib/src/controller/internal/signals_buffer.dart --report-all`
- MCP test runner: `test/controller/core/scene_controller_commit_effects_test.dart test/controller/core/scene_controller_writer_lifecycle_test.dart test/controller/core/scene_controller_commit_atomicity_test.dart test/controller/core/scene_controller_commit_failures_test.dart test/controller/core/scene_controller_signals_delivery_test.dart test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`

### 6.3 Protected States, Data, or Structures

- Commit ordering.
- Signal delivery ordering.
- Notify coalescing semantics.
- Dispose fail-fast semantics.

### 6.4 Allowed Semantic Change Zones

- Commit orchestration and post-commit scheduling ownership.
- Signal / repaint helper ownership under controller internal glue.

### 6.8 Prohibited

- Changing public controller behavior.
- Introducing a second competing owner for post-commit lifecycle.
- Hiding behavior changes behind helper extraction without removing the mixed
  responsibility from `scene_controller.dart`.

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

### Slice 1. [x] Commit execution and post-commit scheduling are separated

#### Slice Contract

`SceneControllerCore` owns commit execution and post-commit lifecycle through
separate internal owners instead of one mixed body.

#### Change

Разделить commit and post-commit ownership inside `scene_controller.dart` and
supporting internal helpers.

#### Verification

- `dcm calculate-metrics lib/src/controller/scene_controller.dart lib/src/controller/internal/repaint_flag.dart lib/src/controller/internal/signals_buffer.dart --report-all`
- MCP test runner: `test/controller/core/scene_controller_commit_effects_test.dart test/controller/core/scene_controller_commit_atomicity_test.dart test/controller/core/scene_controller_signals_delivery_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `scene_controller.dart` no longer keeps the replaced mixed commit /
  post-commit body in the same owner.

### Slice 2. [x] Notify and dispose glue remain exact after the split

#### Slice Contract

Notify coalescing and dispose fail-fast behavior remain exact after the commit
lifecycle split.

#### Change

Перевести remaining notify / dispose glue on the new ownership shape and
remove the replaced duplicate scheduling body.

#### Verification

- `dcm calculate-metrics lib/src/controller/scene_controller.dart --report-all`
- MCP test runner: `test/controller/core/scene_controller_writer_lifecycle_test.dart test/controller/core/scene_controller_commit_failures_test.dart test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
- `dart run tool/check_guardrails.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Post-commit and notify glue no longer preserve the replaced mixed body.

## 9. Final Verification

- `dcm calculate-metrics lib/src/controller/scene_controller.dart lib/src/controller/internal/repaint_flag.dart lib/src/controller/internal/signals_buffer.dart --report-all`
- MCP test runner: `test/controller/core/scene_controller_commit_effects_test.dart test/controller/core/scene_controller_writer_lifecycle_test.dart test/controller/core/scene_controller_commit_atomicity_test.dart test/controller/core/scene_controller_commit_failures_test.dart test/controller/core/scene_controller_signals_delivery_test.dart test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
