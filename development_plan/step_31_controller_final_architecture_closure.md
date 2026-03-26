language: russian

# Шаг 31. Замкнуть финальную controller architecture на docs, structural tests и baseline

## 1. Change Mandate

Этот шаг завершает controller-layer sequence after steps 29-30: финальная
архитектура controller должна быть явно зафиксирована в in-repo документации,
подтверждена structural non-regression tests и закрыта финальным measured
baseline без reopening production ownership slices.

## 2. Change Boundary

### Included in the Change

- Final architecture-doc update for the controller transaction and signal
  model.
- Extension of existing controller structural contract tests so the final
  facade/runtime, writer-local, and mutation-family boundaries are pinned
  against regression.
- Final controller metrics/clone rebaseline and roadmap closure tied directly
  to steps 29-31.

### Not Included in the Change

- Reopening production controller refactors from steps 27-30 beyond minimal
  adaptation required to satisfy the structural contract tests introduced by
  this step.
- Public API changes for `SceneWriteTxn`, `SceneControllerCore`, commands, or
  streams.
- New public tooling entrypoints or package exports created only for this step.
- Work in `interactive/**`, `view/**`, `render/**`, `model/**`,
  `serialization/**`, or `contract/**` outside documentation or verification
  that is directly tied to the controller architecture closure.

## 3. File Map and Analysis Areas

### Implementation Files

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`

### Test Files

- `test/controller/core/scene_controller_commit_runtime_contract_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/internal/scene_writer_test.dart`

### Fixture and Supporting Data Files

- `development_plan/step_29_scene_writer_thin_shell_and_writer_local_owners.md`
- `development_plan/step_30_mutation_family_owner_alignment.md`
- `development_plan/step_31_controller_final_architecture_closure.md`

### Analysis Area

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_29_scene_writer_thin_shell_and_writer_local_owners.md`
- `development_plan/step_30_mutation_family_owner_alignment.md`
- `test/controller/core/**`
- `test/controller/internal/**`
- `lib/src/controller/**`
- `lib/src/controller/internal/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified documentation file must either describe the final controller
  architecture or record the final measured controller baseline.
- Every modified test must pin one final controller boundary against
  architectural regression.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneControllerCore` remains the public facade over
   `SceneControllerCommitRuntime`.
2. `TxnContext` remains the transaction root, while workspace and derived-state
   ownership remain split into `txn_workspace.dart` and
   `txn_derived_state.dart`.
3. `SceneWriter` remains the only internal implementation of `SceneWriteTxn`.
4. `MutationExecutor` remains the mutation-family dispatcher, and
   `mutation_op.dart` remains the typed mutation catalog boundary.
5. Public write, signal, and selection transform semantics are not reopened in
   this step.

## 5. Result Requirements

1. `ARCHITECTURE.md` describes the final controller architecture with:
   `SceneControllerCore` as thin public facade,
   `SceneControllerCommitRuntime` as controller-private orchestration owner,
   `TxnContext` plus `txn_workspace.dart` / `txn_derived_state.dart` as the
   transaction substrate,
   `SceneWriter` as a thin shell over explicit writer-local owners,
   and `MutationExecutor` dispatching explicit mutation-family owners.
2. Existing controller structural contract tests pin the final controller
   architecture and fail if:
   `scene_controller.dart` reabsorbs commit/runtime helpers,
   `scene_writer.dart` reabsorbs mixed writer-local bodies,
   or `node_mutation_applier.dart` reabsorbs selection-transform execution.
3. `DEVELOPMENT_PLAN.md` and the step 29-31 documents describe one consistent
   controller end-state with no stale references to remaining writer or
   mutation-family architecture debt.
4. `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
   reports `5` or fewer `HIGH` entries after the step, and the remaining
   `HIGH` entries are limited to accepted controller seams:
   `scene_controller.dart`,
   `scene_controller_commit_runtime.dart`,
   and `mutation_op.dart`.
5. `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
   reports `2` or fewer pairs after the step.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `scene_controller_commit_runtime_contract_test.dart` already pins the
  facade/runtime split for `SceneControllerCore`.
- `ARCHITECTURE.md` currently documents the controller transaction substrate
  and `SceneWriter` ownership, but does not yet describe the final thin-shell
  writer-local structure or the final mutation-family owner split expected
  after steps 29 and 30.
- This step assumes step 29 and step 30 are already closed; it does not reopen
  those production slices as the main subject of change.
- Current measured controller baseline before steps 29 and 30 is `10 HIGH`
  entries and `2` clone pairs; this step records the final measured baseline
  after the preceding two controller slices are complete.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- MCP test runner:
  `test/controller/core/scene_controller_commit_runtime_contract_test.dart`
- MCP test runner:
  `test/controller/internal/mutation_executor_test.dart test/controller/internal/scene_writer_test.dart`
- MCP test runner:
  `test/controller/core test/controller/commands` plus controller-root
  `*_test.dart`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test`

### 6.3 Protected States, Data, or Structures

- Final public controller/write contract shape.
- Final facade/runtime split under `SceneControllerCore`.
- Final writer-local boundary under `SceneWriter`.
- Final mutation-family owner split under `MutationExecutor`.
- Accepted residual controller seams and their measured metric/clone baseline.

### 6.4 Allowed Semantic Change Zones

- Controller architecture documentation.
- Structural contract tests that pin final controller boundaries.
- Roadmap and baseline documentation tied directly to the final controller
  architecture.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- This step must reuse existing controller structural contract tests where
  possible instead of creating new public verification entrypoints.
- Structural assertions must read and pin the final controller file graph
  directly enough to fail when mixed ownership returns to
  `scene_controller.dart`,
  `scene_writer.dart`,
  or `node_mutation_applier.dart`.
- Final measured controller baseline must be recorded from actual runs of the
  metric and clone tools listed in verification, not from inferred or copied
  numbers.

### 6.8 Prohibited

- Reopening production controller refactors as a substitute for documenting or
  pinning the final architecture.
- Leaving the final controller architecture implicit only in step documents
  without updating `ARCHITECTURE.md`.
- Accepting a final baseline without structural non-regression tests that pin
  the final controller boundary shape.

## 7. Execution Rules

1. This step starts only after steps 29 and 30 are closed.
2. This step closes only if the final controller architecture is both
   documented and mechanically pinned against regression.
3. Rebaseline alone does not count as closure without the corresponding
   documentation and structural test updates.
4. Scope expansion beyond controller architecture closure is forbidden.

## 8. Vertical Slices

### Slice 1. [ ] Extend structural contract tests to pin final controller boundaries

#### Slice Contract

Existing controller structural tests fail when commit/runtime, writer-local, or
mutation-family boundaries regress back into mixed owners.

#### Change

Extend the existing controller structural contract tests so they pin the final
controller boundary shape after steps 29 and 30, including the final
`SceneWriter` and mutation-family owner split.

#### Verification

- MCP test runner:
  `test/controller/core/scene_controller_commit_runtime_contract_test.dart`
- MCP test runner:
  `test/controller/internal/mutation_executor_test.dart test/controller/internal/scene_writer_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Structural assertions cover the final controller facade/runtime,
  writer-local, and mutation-family boundaries.

### Slice 2. [ ] Rebaseline and document final controller architecture

#### Slice Contract

The final controller architecture and its accepted residual seams are recorded
consistently in the repo documentation and roadmap.

#### Change

Update `ARCHITECTURE.md`, `DEVELOPMENT_PLAN.md`, and the step 29-31 documents
to describe the final controller architecture, then record the final measured
controller metrics and clone baseline from actual runs.

#### Verification

- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `ARCHITECTURE.md` and `DEVELOPMENT_PLAN.md` reflect the same final
  controller end-state as the step 29-31 contracts.
- Final measured controller baseline is recorded from the verification runs.

## 9. Final Verification

- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- MCP test runner: `test/controller/internal`
- MCP test runner:
  `test/controller/core test/controller/commands` plus controller-root
  `*_test.dart`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
