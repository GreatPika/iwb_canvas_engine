language: russian

# Шаг 19.2. Развести owner-ов write pipeline между SceneWriter и MutationExecutor

## 1. Change Mandate

Этот шаг разводит ownership write pipeline between `SceneWriter` and
`MutationExecutor`, so public write boundary and mutation application no longer
share one mixed responsibility surface.

## 2. Change Boundary

### Included in the Change

- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/mutation_executor.dart`
- `lib/src/controller/mutation_op.dart`

### Not Included in the Change

- `TxnContext`
- `SceneControllerCore` commit lifecycle
- Invariant sweep
- Interactive stack

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/mutation_executor.dart`
- `lib/src/controller/mutation_op.dart`

### Test Files

- `test/controller/internal/scene_writer_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/commands/move_commands_test.dart`
- `test/controller/commands/draw_commands_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_19_2_scene_writer_and_mutation_executor_pipeline_split.md`

### Analysis Area

- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/mutation_executor.dart`
- `lib/src/controller/mutation_op.dart`
- `test/controller/internal/**`
- `test/controller/commands/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one write-pipeline slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneWriter` remains the public `SceneWriteTxn` boundary.
2. `MutationExecutor` remains the owner of mutation application, not public API
   shaping.
3. This step must not reintroduce duplicate selection or signal ownership.

## 5. Result Requirements

1. `SceneWriter` and `MutationExecutor` no longer mix public write-boundary
   shaping and mutation application responsibilities in the same logic paths.
2. Selection and signal semantics remain equivalent.
3. Current hotspots improve against the confirmed baseline:
   `scene_writer.dart = 4 HIGH+`, `mutation_executor.dart = 4 HIGH+`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current confirmed hotspot classes are:
  - `SceneWriter: CBO 26, RFC 58, WMC 47`
  - `MutationExecutor: CBO 43, RFC 83, WMC 109`
- The step owns the write pipeline seam only and must not solve `TxnContext`
  materialization in this step.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller/scene_writer.dart lib/src/controller/mutation_executor.dart lib/src/controller/mutation_op.dart --report-all`
- MCP test runner: `test/controller/internal/scene_writer_test.dart test/controller/internal/mutation_executor_test.dart`
- MCP test runner: `test/controller/commands/scene_commands_test.dart test/controller/commands/move_commands_test.dart test/controller/commands/draw_commands_test.dart`
- `dart run tool/check_import_boundaries.dart`

### 6.3 Protected States, Data, or Structures

- `SceneWriteTxn` public semantics.
- Selection and signal write semantics.
- Mutation op contract.

### 6.4 Allowed Semantic Change Zones

- Public write boundary orchestration in `SceneWriter`.
- Mutation family dispatch and applicator ownership in `MutationExecutor`.
- Internal op structuring in `mutation_op.dart`.

### 6.8 Prohibited

- Pushing public write-boundary semantics deeper into executor internals.
- Duplicating selection or signal ownership.
- Touching `TxnContext` ownership beyond targeted support that is required by
  the slice.

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

### Slice 1. [x] SceneWriter is reduced to exact public write-boundary ownership

#### Slice Contract

`SceneWriter` owns only exact public write-boundary shaping and does not keep
duplicated mutation-application logic.

#### Change

Развести public write-boundary responsibilities in `scene_writer.dart` from
mutation application and remove the replaced mixed logic.

#### Verification

- `dcm calculate-metrics lib/src/controller/scene_writer.dart --report-all`
- MCP test runner: `test/controller/internal/scene_writer_test.dart`
- MCP test runner: `test/controller/commands/scene_commands_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `scene_writer.dart` no longer keeps the replaced mixed public / mutation
  logic body.

### Slice 2. [x] MutationExecutor owns only mutation family application

#### Slice Contract

`MutationExecutor` owns mutation family application without preserving
public-boundary shaping or duplicated write-pipeline glue.

#### Change

Разрезать `mutation_executor.dart` and supporting op structure so executor
owns only mutation family application responsibilities.

#### Verification

- `dcm calculate-metrics lib/src/controller/mutation_executor.dart lib/src/controller/mutation_op.dart --report-all`
- MCP test runner: `test/controller/internal/mutation_executor_test.dart`
- MCP test runner: `test/controller/commands/move_commands_test.dart test/controller/commands/draw_commands_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Executor no longer keeps the replaced mixed write-pipeline glue.

## 9. Final Verification

- `dcm calculate-metrics lib/src/controller/scene_writer.dart lib/src/controller/mutation_executor.dart lib/src/controller/mutation_op.dart --report-all`
- MCP test runner: `test/controller/internal/scene_writer_test.dart test/controller/internal/mutation_executor_test.dart`
- MCP test runner: `test/controller/commands/scene_commands_test.dart test/controller/commands/move_commands_test.dart test/controller/commands/draw_commands_test.dart`
- `dart run tool/check_import_boundaries.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
