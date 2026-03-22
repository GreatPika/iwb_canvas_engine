language: russian

# Шаг 19. Стабилизировать runtime orchestration stack через подшаги 19.1-19.6

## 1. Change Mandate

Этот шаг стабилизирует runtime orchestration stack в `controller/interactive`
через разрезание перегруженных owners по ответственности без изменения public
controller behavior.

## 2. Change Boundary

### Included in the Change

- Commit and post-commit lifecycle in `SceneControllerCore`.
- Write-pipeline ownership between `SceneWriter` and `MutationExecutor`.
- `TxnContext` mutable workspace and derived-state ownership.
- Invariant sweep and proof surface.
- `SceneControllerInteractive` facade and pointer/gesture runtime ownership.
- Post-step rebaseline по runtime stack.

### Not Included in the Change

- Contract/model/serialization boundary-matrix work.
- Render/view hotspot work.
- Public API and transport contract changes.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/controller/scene_controller.dart`
- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/mutation_executor.dart`
- `lib/src/controller/txn_context.dart`
- `lib/src/controller/scene_invariants.dart`
- `lib/src/controller/internal/repaint_flag.dart`
- `lib/src/controller/internal/signals_buffer.dart`
- `lib/src/interactive/scene_controller_interactive.dart`
- `lib/src/interactive/internal/interactive_move_session.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator.dart`
- `lib/src/interactive/internal/interactive_event_dispatcher.dart`
- `lib/src/interactive/internal/interactive_gesture_machine.dart`

### Test Files

- `test/controller/internal/**`
- `test/controller/core/**`
- `test/controller/commands/**`
- `test/controller/*.dart`
- `test/interactive/**`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_19*.md`

### Analysis Area

- `lib/src/controller/**`
- `lib/src/interactive/**`
- `test/controller/**`
- `test/interactive/**`
- `development_plan/step_19*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to exactly one runtime-stack
  substep.
- Every modified test must be tied to one verification surface.
- Every modified planning document must be tied to one measured baseline or one
  execution slice.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Committed `SceneSnapshot` remains the single source of truth.
2. Runtime stack must not introduce second caches or sync glue to reduce
   metrics.
3. Public controller and interactive contracts remain behaviorally equivalent.
4. Pointer semantics, active-gesture ownership, selection exclusivity, and
   dispose fail-fast contract remain protected.
5. This step does not reopen boundary-matrix or render/view scope.

## 5. Result Requirements

1. Runtime orchestration responsibilities are separated so that the current
   overloaded owners no longer mix unrelated lifecycle concerns in the same
   unit.
2. Public controller and interactive behavior remain equivalent after the
   refactor.
3. The runtime-stack hotspots improve against the current confirmed baseline:
   `25` `HIGH+` entries across
   `scene_controller.dart`,
   `scene_writer.dart`,
   `mutation_executor.dart`,
   `txn_context.dart`,
   `scene_invariants.dart`,
   `scene_controller_interactive.dart`,
   and `interactive_move_session.dart`.
4. Residual work after the step is captured from a new measured baseline.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current confirmed top hotspots inside the stack are:
  - `SceneControllerInteractive: CBO 36, RFC 154, WMC 184`
  - `MutationExecutor: CBO 43, RFC 83, WMC 109`
  - `SceneControllerCore: imports 28, CBO 34, RFC 70, WMC 90`
  - `TxnContext: RFC 77, WMC 118`
  - `txnCollectStoreInvariantViolations(...): CC 25, params 9, SLOC 132`
- Current confirmed runtime-stack family contributes `25` `HIGH+` entries in
  `lib/src` and participates in `7` clone clusters in `lib`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller lib/src/interactive --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core test/controller/commands`
- MCP test runner: controller-root `*_test.dart`
- MCP test runner: `test/interactive`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

### 6.3 Protected States, Data, or Structures

- Commit lifecycle and signal ordering guarantees.
- Pointer and active-gesture semantics.
- Selection exclusivity rules during active gesture.
- Dispose fail-fast behavior.

### 6.4 Allowed Semantic Change Zones

- Commit orchestration and post-commit lifecycle ownership.
- Write pipeline ownership between writer, executor, and transaction state.
- Invariant sweep structure and proof surface.
- Pointer and gesture runtime structure beneath the interactive facade.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `19.1` closes before `19.2`.
- `19.2` closes before `19.3`.
- `19.3` closes before `19.4`.
- `19.5` is forbidden until `19.1-19.4` are closed.
- `19.6` is forbidden until `19.1-19.5` are closed and remeasured.

### 6.8 Prohibited

- Introducing metric-only wrappers or second runtime caches.
- Changing public behavior to get under thresholds.
- Reopening boundary-matrix or render/view work as part of this step.

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

### Slice 1. [ ] SceneControllerCore commit lifecycle split

#### Slice Contract

Закрыть `development_plan/step_19_1_scene_controller_core_commit_orchestration_split.md`
без выхода за ownership boundary `19.1`.

#### Verification

- Verification from `19.1`

### Slice 2. [ ] Write pipeline split

#### Slice Contract

Закрыть `development_plan/step_19_2_scene_writer_and_mutation_executor_pipeline_split.md`
без выхода за ownership boundary `19.2`.

#### Verification

- Verification from `19.2`

### Slice 3. [ ] TxnContext ownership split

#### Slice Contract

Закрыть `development_plan/step_19_3_txn_context_workspace_and_derived_state_split.md`
без выхода за ownership boundary `19.3`.

#### Verification

- Verification from `19.3`

### Slice 4. [ ] Invariant proof surface split

#### Slice Contract

Закрыть `development_plan/step_19_4_scene_invariants_decomposition_and_proof_surface.md`
без выхода за ownership boundary `19.4`.

#### Verification

- Verification from `19.4`

### Slice 5. [ ] Interactive facade thinning

#### Slice Contract

Закрыть `development_plan/step_19_5_scene_controller_interactive_facade_thinning.md`
без выхода за ownership boundary `19.5`.

#### Verification

- Verification from `19.5`

### Slice 6. [ ] Runtime-stack rebaseline

#### Slice Contract

Закрыть `development_plan/step_19_6_runtime_stack_rebaseline_and_roadmap.md`
без повторного открытия semantic scope `19.1-19.5`.

#### Verification

- Verification from `19.6`

## 9. Final Verification

- `dcm calculate-metrics lib/src/controller lib/src/interactive --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core test/controller/commands`
- MCP test runner: controller-root `*_test.dart`
- MCP test runner: `test/interactive`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
