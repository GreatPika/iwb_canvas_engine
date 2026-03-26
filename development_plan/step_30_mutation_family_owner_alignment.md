language: russian

# Шаг 30. Выровнять owner boundary mutation families под `MutationExecutor`

## 1. Change Mandate

Этот шаг доводит mutation-family ownership в controller-layer до финальной
формы: file-local execution owners под `MutationExecutor` должны совпасть с уже
зафиксированными mutation families в `mutation_op.dart` без изменения public
write semantics или mutation catalog contract.

## 2. Change Boundary

### Included in the Change

- Extraction of an explicit private owner for
  `SelectionTransformMutationOp` execution.
- Reduction of `node_mutation_applier.dart` to node-local mutation ownership.
- Minimal `MutationExecutor` adaptation required to dispatch each mutation
  family into its matching private owner boundary.
- Structural, metric, clone, and roadmap updates tied directly to this
  mutation-family slice.

### Not Included in the Change

- Reopening `SceneWriter` thinning work from step 29 beyond minimal adaptation
  required by the mutation-family boundary.
- Public API changes for `SceneWriteTxn`, command methods, write return
  semantics, or selection transform semantics.
- Reopening `SceneControllerCore`, `SceneControllerCommitRuntime`, `TxnContext`,
  `txn_workspace.dart`, `txn_derived_state.dart`, or
  `internal/spatial_index_cache.dart` as the main subject of the change.
- Reopening `mutation_op.dart` as the typed mutation catalog boundary beyond
  minimal adaptation required by the new private owner split.
- Clone cleanup in `draw_commands.dart` or `scene_invariants.dart`.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/controller/mutation_executor.dart`
- `lib/src/controller/node_mutation_applier.dart`

### Test Files

- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/commands/move_commands_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`

### Fixture and Supporting Data Files

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_30_mutation_family_owner_alignment.md`

### Analysis Area

- `lib/src/controller/mutation_executor.dart`
- `lib/src/controller/node_mutation_applier.dart`
- `lib/src/controller/mutation_op.dart`
- `lib/src/controller/**`
- `test/controller/internal/**`
- `test/controller/commands/**`
- `test/controller/scene_controller_randomized_txn_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must either align a private execution
  owner with an existing mutation family or adapt executor dispatch to that
  alignment.
- Every new implementation file must represent one explicit mutation-family
  owner with one clear reason to change.
- Every modified test must validate mutation-family behavior, selection
  transform semantics, or mutation-family dispatch structure.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `mutation_op.dart` remains the typed mutation catalog boundary for the
   controller layer.
2. `MutationExecutor` remains the family dispatcher and does not become the
   owner of concrete mutation bodies.
3. `SceneWriter` remains the write boundary shell produced by step 29 and does
   not re-own mutation-family execution logic.
4. `NodeMutationOp` and `SelectionTransformMutationOp` remain distinct mutation
   families.
5. Public selection transform semantics remain unchanged, including
   pre-multiply transform order and no-op behavior for non-applicable selected
   nodes.
6. `SceneWriteTxn` breadth remains unchanged in this step; residual
   `SceneWriter` facade `RFC` caused solely by the fixed public write contract
   is accepted unless the contract itself is changed in a later step.
7. Remaining clone pairs in `draw_commands.dart` and `scene_invariants.dart`
   are non-regression only in this step.

## 5. Result Requirements

1. `node_mutation_applier.dart` no longer owns
   `SelectionTransformMutationOp` execution.
2. An explicit private selection-transform execution owner exists under
   `lib/src/controller/**`, and `MutationExecutor` dispatches
   `SelectionTransformMutationOp` to that owner instead of routing it through
   `node_mutation_applier.dart`.
3. `node_mutation_applier.dart` is reduced to node-local mutation ownership:
   insert, patch, set-node-transform, delete-one, and bulk-delete.
4. `dcm calculate-metrics lib/src/controller/mutation_executor.dart lib/src/controller/node_mutation_applier.dart --report-all`
   reports `0 HIGH`.
5. `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
   reports `6` or fewer `HIGH` entries after the change, and the remaining
   `HIGH` entries are limited to accepted controller seams:
   `scene_controller.dart`,
   `scene_controller_commit_runtime.dart`,
   `mutation_op.dart`,
   and the contract-breadth `SceneWriter` facade.
6. `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
   reports `2` or fewer pairs after the change and introduces no pair
   involving `node_mutation_applier.dart`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `mutation_op.dart` already separates
  `NodeMutationOp<TValue>` and `SelectionTransformMutationOp<TValue>` into
  distinct mutation families.
- `MutationExecutor` already dispatches `NodeMutationOp` and
  `SelectionTransformMutationOp` through separate switch branches.
- `node_mutation_applier.dart` currently still owns both
  `executeNodeMutationOp(...)` and `executeSelectionTransformMutationOp(...)`,
  so file-local ownership lags behind the mutation-family boundary already
  present in `mutation_op.dart`.
- Current confirmed hotspot baseline for this area:
  - `mutation_executor.dart`: `0 HIGH`
  - `mutation_op.dart`: file imports `12` (`HIGH`)
  - `node_mutation_applier.dart`: file imports `11` (`HIGH`)
  - `_transformSelection(...)`: cyclomatic complexity `9` (`NEAR`)
  - `_translateSelection(...)`: cyclomatic complexity `10` (`NEAR`)

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller/mutation_executor.dart lib/src/controller/node_mutation_applier.dart --report-all`
- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- MCP test runner: `test/controller/internal/mutation_executor_test.dart`
- MCP test runner: `test/controller/internal/scene_writer_test.dart`
- MCP test runner:
  `test/controller/commands/move_commands_test.dart test/controller/commands/scene_commands_test.dart`
- MCP test runner: `test/controller/scene_controller_randomized_txn_test.dart`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test`

### 6.3 Protected States, Data, or Structures

- Typed mutation catalog semantics in `mutation_op.dart`.
- Executor family dispatch semantics.
- Selection translate/transform public behavior as observed through
  `SceneWriter` and command adapters.
- Node-local mutation behavior for insert, patch, set-node-transform, delete,
  and bulk-delete.
- Existing command-level signals and payload shapes driven by selection
  translate/transform writes.

### 6.4 Allowed Semantic Change Zones

- Private execution ownership for `SelectionTransformMutationOp`.
- Private execution ownership for node-local mutations.
- `MutationExecutor` family dispatch wiring.
- Minimal non-public mutation-owner support code required to remove the mixed
  file-local ownership from `node_mutation_applier.dart`.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `mutation_op.dart` must remain the single mutation catalog boundary.
- `MutationExecutor` must continue dispatching by mutation family and must not
  absorb concrete mutation bodies.
- `NodeMutationOp` and `SelectionTransformMutationOp` must not share one
  file-local execution owner after this change.
- Any extracted selection-transform owner must stay private to
  `lib/src/controller/**` and must not become a public export or package
  entrypoint.
- Replaced selection-transform execution bodies must be deleted from
  `node_mutation_applier.dart` in the same slice that introduces the new owner.

### 6.8 Prohibited

- Re-merging selection-transform execution into node-local mutation files.
- Pushing concrete mutation-family logic back into `SceneWriter` or into
  `MutationExecutor`.
- Changing typed mutation catalog semantics only to satisfy metrics.
- Introducing wrappers whose main effect is moving imports without aligning the
  owner boundary to the existing mutation-family split.

## 7. Execution Rules

1. This step closes only if file-local execution ownership matches the existing
   mutation-family split in `mutation_op.dart`.
2. Preparatory extraction without deleting the replaced selection-transform
   bodies from `node_mutation_applier.dart` does not count as closure.
3. Any new private owner is valid only when it removes one mixed
   mutation-family responsibility from the old file in the same slice.
4. Metric improvement counts only when it follows from owner-boundary
   alignment rather than compatibility wrappers.

## 8. Vertical Slices

### Slice 1. [x] Extract explicit selection-transform mutation owner

#### Slice Contract

`SelectionTransformMutationOp` execution has one explicit private owner and no
   longer lives in `node_mutation_applier.dart`.

#### Change

Move `executeSelectionTransformMutationOp(...)`,
`_transformSelection(...)`, and `_translateSelection(...)` out of
`node_mutation_applier.dart` into one explicit private mutation-family owner
and adapt executor dispatch accordingly.

#### Verification

- `dcm calculate-metrics lib/src/controller/mutation_executor.dart lib/src/controller/node_mutation_applier.dart --report-all`
- MCP test runner: `test/controller/internal/mutation_executor_test.dart`
- MCP test runner:
  `test/controller/internal/scene_writer_test.dart test/controller/commands/move_commands_test.dart`
- MCP test runner: `test/controller/scene_controller_randomized_txn_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `node_mutation_applier.dart` no longer contains the replaced
  selection-transform execution bodies.

### Slice 2. [x] Finalize node-local mutation owner and metric closure

#### Slice Contract

`node_mutation_applier.dart` owns only node-local mutation execution and no
longer remains a residual controller hotspot.

#### Change

Finish the node-local owner cleanup needed after selection-transform
extraction, keep only node-local mutation bodies in
`node_mutation_applier.dart`, and remove the replaced mixed ownership from the
file.

#### Verification

- `dcm calculate-metrics lib/src/controller/mutation_executor.dart lib/src/controller/node_mutation_applier.dart --report-all`
- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- MCP test runner: `test/controller/internal/mutation_executor_test.dart`
- MCP test runner:
  `test/controller/internal/scene_writer_test.dart test/controller/commands/scene_commands_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `mutation_executor.dart` and `node_mutation_applier.dart` report `0 HIGH`.
- Controller-layer `HIGH` entries are reduced to the accepted seams listed in
  result requirement 5.

## 9. Final Verification

- `dcm calculate-metrics lib/src/controller/mutation_executor.dart lib/src/controller/node_mutation_applier.dart --report-all`
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
