language: russian

# Шаг 27. Сделать `SceneControllerCore` тонким facade над controller commit runtime

## 1. Change Mandate

Этот шаг завершает facade/runtime slice в controller-layer:
`SceneControllerCore` должен стать тонким public facade над
controller-private commit runtime без изменения write/signal/repaint/spatial
семантики.

## 2. Change Boundary

### Included in the Change

- Final thinning of `SceneControllerCore` as the public controller facade.
- Extraction of controller-private commit/runtime ownership out of
  `scene_controller.dart`.
- Split of planning, execution, post-commit delivery, write-runner, and debug
  support into explicit controller-private modules beneath the public facade.
- Structural verification for the new facade/runtime graph.
- Roadmap updates tied directly to this controller slice.

### Not Included in the Change

- Cleanup of remaining controller debt in `SceneWriter`, `TxnContext`, or
  `SpatialIndexCache`.
- Clone cleanup outside the extracted facade/runtime slice.
- Any work in `lib/src/interactive/**`, `lib/src/view/**`, `lib/src/render/**`,
  `lib/src/model/**`, or `lib/src/contract/**`.
- Public API changes for `SceneControllerCore`, `SceneWriteTxn`, commands,
  streams, or write semantics.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/controller/scene_controller.dart`
- `lib/src/controller/scene_controller_commit_runtime.dart`
- `lib/src/controller/scene_controller_commit_plan.dart`
- `lib/src/controller/scene_controller_commit_execution.dart`
- `lib/src/controller/scene_controller_commit_write_runner.dart`
- `lib/src/controller/scene_controller_post_commit_lifecycle.dart`
- `lib/src/controller/scene_controller_commit_debug.dart`

### Test Files

- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/core/scene_controller_commit_effects_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/core/scene_controller_commit_runtime_contract_test.dart`
- `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
- `test/controller/core/scene_controller_signals_delivery_test.dart`
- `test/controller/core/scene_controller_spatial_index_test.dart`
- `test/controller/core/scene_controller_writer_lifecycle_test.dart`
- `test/controller/commands/draw_commands_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`

### Fixture and Supporting Data Files

- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/step_27_scene_controller_core_facade_finalization.md`

### Analysis Area

- `lib/src/controller/scene_controller.dart`
- `lib/src/controller/scene_controller_commit_runtime.dart`
- `lib/src/controller/scene_controller_commit_plan.dart`
- `lib/src/controller/scene_controller_commit_execution.dart`
- `lib/src/controller/scene_controller_commit_write_runner.dart`
- `lib/src/controller/scene_controller_post_commit_lifecycle.dart`
- `lib/src/controller/scene_controller_commit_debug.dart`
- `lib/src/controller/**`
- `test/controller/core/**`
- `test/controller/internal/**`
- `test/controller/commands/**`
- `test/controller/scene_controller_randomized_txn_test.dart`
- `PLAN.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which the slice
  verification cannot be closed.

### File Change Rule

- Every modified implementation file must either remove mixed commit
  orchestration from `SceneControllerCore` or become one explicit
  controller-private owner under the new runtime graph.
- Every modified test must validate facade/runtime behavior or the new
  structural boundary.
- Untied changes are out of scope.

## 4. Locked Decisions

1. `SceneControllerCore` remains the public controller facade.
2. `SceneControllerCommitRuntime` is the controller-private orchestration
   owner beneath `SceneControllerCore`.
3. Planning, execution, write-session lifecycle, post-commit delivery, and
   debug access are explicit private modules under the controller facade.
4. `SceneWriter` remains the internal owner for exact command-facing mutation
   results and buffered signal enqueue semantics.
5. Signal delivery remains ordered before repaint notification for the same
   successful commit.
6. `write(...)` remains synchronous-only and nested writes remain forbidden.
7. `dispose()` remains idempotent on the facade boundary.
8. Clone cleanup outside the facade/runtime slice is not part of this step.

## 5. Result Requirements

1. `SceneControllerCore` no longer keeps detailed commit normalization, plan
   construction, execution, store apply, or post-commit sequencing bodies in
   the public facade file.
2. One controller-private facade/runtime graph exists beneath
   `SceneControllerCore`, with explicit private owners for:
   planning, execution, write-session lifecycle, post-commit delivery, and
   debug access.
3. `dcm calculate-metrics lib/src/controller/scene_controller.dart lib/src/controller/scene_controller_commit_runtime.dart lib/src/controller/scene_controller_commit_plan.dart lib/src/controller/scene_controller_commit_execution.dart --report-all`
   reports `4` or fewer `HIGH` entries.
4. `dcm calculate-metrics lib/src/controller/scene_controller.dart --report-all`
   reports `2` or fewer `HIGH` entries in `scene_controller.dart`.
5. `dcm calculate-metrics lib/src/controller/scene_controller.dart --report-all`
   reports `1` or fewer `HIGH` class entries on `SceneControllerCore`.
6. `scene_controller_commit_plan.dart` and
   `scene_controller_commit_execution.dart` report `0 HIGH`.
7. `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
   introduces no new clone pair involving:
   `scene_controller.dart`,
   `scene_controller_commit_runtime.dart`,
   `scene_controller_commit_plan.dart`,
   or `scene_controller_commit_execution.dart`.
8. Public controller behavior remains unchanged for:
   - sync-only write contract;
   - nested-write failure;
   - signal-before-notify ordering;
   - spatial-index prepare/apply behavior;
   - controller epoch, revision, and commit-revision semantics;
   - buffered-effect discard on failed transactions.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Baseline before this slice:
  `scene_controller.dart` held facade, planning, execution, store apply, and
  post-commit delivery in one file-local hotspot.
- Baseline metrics before this slice:
  - `scene_controller.dart` file imports `31`
  - `SceneControllerCore` coupling `36`
  - `SceneControllerCore` RFC `69`
  - `SceneControllerCore` WMC `80`
  - `SceneControllerCore.write(...)` SLOC `45`
- Current facade/runtime result after this slice:
  - `scene_controller.dart` now reports `2 HIGH`
  - `SceneControllerCore` now reports `1 HIGH` class entry
  - `scene_controller_commit_plan.dart` reports `0 HIGH`
  - `scene_controller_commit_execution.dart` reports `0 HIGH`
  - the analyzed facade/runtime slice reports `4 HIGH` total
- Remaining controller debt after this slice sits outside the boundary in:
  `SceneWriter`, `TxnContext`, and `SpatialIndexCache`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller/scene_controller.dart lib/src/controller/scene_controller_commit_runtime.dart lib/src/controller/scene_controller_commit_plan.dart lib/src/controller/scene_controller_commit_execution.dart --report-all`
- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- MCP test runner: `test/controller/core`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/commands` plus controller-root `*_test.dart`
- MCP test runner: `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test`

### 6.3 Protected States, Data, or Structures

- Public `SceneControllerCore` constructor and facade shape.
- `write(...)` lifecycle, failure cleanup, and nested-write rejection.
- Facade-boundary `dispose()` idempotence.
- Signal buffering and signal-before-notify ordering.
- Spatial-index prepare/apply ordering and controller epoch interaction.
- Debug hooks and debug access used by controller tests.

### 6.4 Allowed Semantic Change Zones

- Public-facade delegation inside `SceneControllerCore`.
- Controller-private commit runtime ownership and its internal data contracts.
- Controller-private planning, execution, write-runner, post-commit delivery,
  and debug access.
- Structural tests that pin the new facade/runtime boundary.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- The extracted facade/runtime helpers must stay private to
  `lib/src/controller/**` and must not become new public exports or package
  entrypoints.
- `SceneControllerCore` must remain the visible owner of commit/store/signal
  lifecycle.
- Replaced mixed bodies must be deleted from `scene_controller.dart` instead of
  being mirrored through pass-through wrappers.
- `SceneWriter`, `TxnContext`, `MutationExecutor`, and `SpatialIndexCache`
  may receive only the minimal adaptation required to feed the extracted
  facade/runtime seam.

### 6.8 Prohibited

- Reopening `SceneWriter`, `TxnContext`, or `SpatialIndexCache` hotspot cleanup
  as the main subject of this step.
- Changing signals, repaint notifications, epoch/revision semantics, or public
  write behavior only to satisfy metrics.
- Introducing compatibility wrappers whose main effect is moving imports or
  silencing metrics without clarifying ownership.

## 7. Execution Rules

1. This step closes only if `SceneControllerCore` becomes a thin facade over
   one explicit controller-private runtime graph.
2. Preparatory extraction without a verifiable facade/runtime boundary does
   not count as closure.
3. Any new private module is valid only when it removes one mixed commit
   responsibility from `scene_controller.dart`.

## 8. Vertical Slices

### Slice 1. [x] Finalize `SceneControllerCore` as a thin facade over commit runtime

#### Slice Contract

`SceneControllerCore` delegates commit orchestration into one
controller-private runtime graph, reducing public-facade metric pressure
without changing commit, signal, repaint, or spatial-index behavior.

#### Change

Extract controller-private commit planning, execution, write-session
lifecycle, post-commit delivery, and debug access out of `scene_controller.dart`,
keep `SceneControllerCore` as the public write facade, and pin the resulting
boundary with a structural contract test.

#### Verification

- `dcm calculate-metrics lib/src/controller/scene_controller.dart lib/src/controller/scene_controller_commit_runtime.dart lib/src/controller/scene_controller_commit_plan.dart lib/src/controller/scene_controller_commit_execution.dart --report-all`
- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- MCP test runner: `test/controller/core`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/commands` plus controller-root `*_test.dart`
- MCP test runner: `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test`

#### Positive Scenarios

- Successful commits still normalize inputs, finalize store state, prepare and
  apply spatial-index updates, emit committed signals, and schedule repaint in
  the same observable order.
- Failed commits still discard buffered effects and preserve epoch/revision
  state.
- Public command adapters and `write(...)` callers keep the same runtime
  behavior.

#### Negative Scenarios

- `SceneControllerCore` does not retain duplicated orchestration bodies after
  extraction.
- No new clone pair appears inside the facade/runtime slice.
- The new runtime boundary does not widen public API or import topology.

#### Closure Evidence

- Green run of all listed verifications.
- `scene_controller.dart` reports `2 HIGH`.
- `SceneControllerCore` reports `1 HIGH` class entry.
- `scene_controller_commit_plan.dart` reports `0 HIGH`.
- `scene_controller_commit_execution.dart` reports `0 HIGH`.
- The analyzed facade/runtime slice reports `4 HIGH` total.
- `SceneControllerCore.dispose()` remains idempotent on the facade boundary.

## 9. Final Verification

- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/controller/scene_controller.dart lib/src/controller/scene_controller_commit_runtime.dart lib/src/controller/scene_controller_commit_plan.dart lib/src/controller/scene_controller_commit_execution.dart --report-all`
- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/controller/core`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/commands` plus controller-root `*_test.dart`
- MCP test runner: `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
