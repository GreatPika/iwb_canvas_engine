language: russian

# Шаг 29. Сделать `SceneWriter` тонким shell над writer-local owner-ами

## 1. Change Mandate

Этот шаг доводит write boundary в controller-layer до финальной формы:
`SceneWriter` должен стать тонким internal shell над явными writer-local
owner-ами без изменения public `SceneWriteTxn` contract, command-facing result
semantics или buffered signal behavior.

## 2. Change Boundary

### Included in the Change

- Final thinning of `SceneWriter` as the single internal implementation of
  `SceneWriteTxn`.
- Extraction of explicit writer-local owners for selection-only transitions.
- Extraction of explicit writer-local owners for scene-setting and document
  replacement boundary transitions.
- Extraction of explicit writer-local owner for buffered signal enqueue.
- Minimal adaptation of controller command adapters required to consume the new
  writer-local structure without changing public controller behavior.
- Structural, metric, clone, and roadmap updates tied directly to this
  writer-local slice.

### Not Included in the Change

- Reopening `SceneControllerCore` or `SceneControllerCommitRuntime` as the main
  subject of the change.
- Splitting `MutationExecutor` or `node_mutation_applier.dart` by mutation
  family; that is a separate follow-up slice.
- Public API changes for `SceneWriteTxn`, `SceneControllerCore`, command
  methods, streams, or write return semantics.
- Reopening `TxnContext`, `txn_workspace.dart`, `txn_derived_state.dart`, or
  `internal/spatial_index_cache.dart` beyond minimal adaptation required by the
  new writer-local boundary.
- Clone cleanup in `draw_commands.dart` or `scene_invariants.dart`.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/commands/scene_commands.dart`
- `lib/src/controller/commands/draw_commands.dart`
- `lib/src/controller/commands/move_commands.dart`

### Test Files

- `test/controller/internal/scene_writer_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/commands/draw_commands_test.dart`
- `test/controller/commands/move_commands_test.dart`
- `test/controller/core/scene_controller_writer_lifecycle_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`

### Fixture and Supporting Data Files

- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/step_29_scene_writer_thin_shell_and_writer_local_owners.md`

### Analysis Area

- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/commands/**`
- `lib/src/controller/**`
- `test/controller/internal/**`
- `test/controller/commands/**`
- `test/controller/core/**`
- `test/controller/scene_controller_randomized_txn_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must either remove mixed ownership from
  `SceneWriter` or adapt one command-facing seam to the new writer-local
  structure.
- Every new implementation file must represent one explicit writer-local owner
  with one clear reason to change.
- Every modified test must validate writer boundary semantics, command-facing
  exact results, or writer lifecycle behavior.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneWriter` remains the single internal implementation of
   `SceneWriteTxn`.
2. Public `SceneWriteTxn` method set and return types do not change in this
   step.
3. Internal commands continue to consume writer-local exact result semantics
   directly instead of expanding the public `SceneWriteTxn` contract or
   diffing `snapshot`.
4. `MutationExecutor` remains the owner of mutation application; selection,
   buffered signal enqueue, and writer-local exact result shaping do not move
   into executor internals.
5. Commit/store/signal lifecycle remains under
   `SceneControllerCore -> SceneControllerCommitRuntime`.
6. Remaining clone pairs in `draw_commands.dart` and `scene_invariants.dart`
   are non-regression only in this step.

## 5. Result Requirements

1. `SceneWriter` no longer keeps mixed bodies for selection-only transitions,
   scene-setting/document replacement boundary transitions, and buffered signal
   enqueue; those responsibilities are owned by explicit private writer-local
   modules under `lib/src/controller/**`.
2. `SceneWriter` remains the only `SceneWriteTxn` implementation and is reduced
   to a thin writer boundary shell plus exact mutation-op forwarding.
3. Exact command-facing writer semantics remain unchanged for:
   `writeSelectionReplaceResult(...)`,
   `writeSelectionSelectAllResult(...)`,
   `writeDeleteSelectionResult(...)`,
   `writeOwnedSignalEnqueue(...)`,
   and `...Changed(...)` scene-setting helpers.
4. `SceneWriter` may remain a thin-shell residual seam with `HIGH RFC` if the
   file contains no mixed writer-local bodies, introduces no clone pair, and
   keeps the public `SceneWriteTxn` breadth unchanged.
5. `SceneWriterRuntime` may remain a temporary coupling residual seam for exact
   mutation-op forwarding in this step; mutation-family decomposition is
   explicitly deferred to step `30`.
6. `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
   reports `2` or fewer pairs after the change and introduces no pair
   involving `scene_writer.dart`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current confirmed writer hotspot baseline:
  - `scene_writer.dart` file imports `13`
  - `SceneWriter` coupling `27`
  - `SceneWriter` RFC `59`
  - `SceneWriter` WMC `48`
- Current command adapters consume writer-local internal seam methods:
  `writeSelectionReplaceResult(...)`,
  `writeSelectionSelectAllResult(...)`,
  `writeDeleteSelectionResult(...)`,
  `writeOwnedSignalEnqueue(...)`,
  `writeBackgroundColorChanged(...)`,
  `writeGridEnableChanged(...)`,
  `writeGridCellSizeChanged(...)`,
  and `writeCameraOffsetChanged(...)`.
- Current controller clone baseline is `2` pairs and neither pair involves
  `scene_writer.dart`.
- Closure-state baseline for this step:
  - `SceneWriter` RFC `44` as accepted thin-shell residual seam
  - `SceneWriterRuntime` coupling `17` as accepted temporary runtime residual
    seam before step `30`
  - controller clone scan remains at `2` pairs with no pair involving
    `scene_writer.dart`

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller/scene_writer.dart --report-all`
- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- MCP test runner: `test/controller/internal/scene_writer_test.dart`
- MCP test runner:
  `test/controller/commands/scene_commands_test.dart test/controller/commands/draw_commands_test.dart test/controller/commands/move_commands_test.dart`
- MCP test runner:
  `test/controller/core/scene_controller_writer_lifecycle_test.dart test/controller/core/scene_controller_commit_atomicity_test.dart`
- MCP test runner: `test/controller/scene_controller_randomized_txn_test.dart`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test`

### 6.3 Protected States, Data, or Structures

- Public `SceneWriteTxn` contract and write callback lifecycle.
- Writer stale-handle rejection, async write rejection, and rollback behavior.
- Exact command-facing selection result semantics and sorted node-id payload
  semantics.
- Single immutability boundary for owned signal enqueue.
- Scene-setting changed/no-op semantics and document replacement boundary
  behavior.
- Existing command-level signal names and payload shapes.

### 6.4 Allowed Semantic Change Zones

- Writer-local selection boundary ownership.
- Writer-local scene-setting and document replacement boundary ownership.
- Writer-local buffered signal enqueue ownership.
- `SceneWriter` constructor, delegation, and exact mutation-op forwarding.
- Minimal command adapter interaction with the new writer-local structure.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `SceneWriter` must remain the only `SceneWriteTxn` implementation in
  `lib/src/controller/**`.
- Extracted writer-local owners must stay private to `lib/src/controller/**`
  and must not become new public exports or package entrypoints.
- Command adapters may depend on writer-local exact-result helpers, but this
  dependency must stay internal to `lib/src/controller/**` and must not expand
  the public `SceneWriteTxn` seam.
- Replaced mixed bodies must be deleted from `scene_writer.dart` in the same
  slice that introduces the corresponding writer-local owner.

### 6.8 Prohibited

- Splitting `SceneWriteTxn` into capability-specific public interfaces.
- Pushing selection, signal, or scene-setting boundary semantics into
  `MutationExecutor`.
- Reopening commit runtime, transaction substrate, or mutation-family
  decomposition as the main subject of this step.
- Introducing wrappers whose main effect is moving imports or silencing metrics
  without deleting the replaced mixed ownership from `scene_writer.dart`.

## 7. Execution Rules

1. This step closes only if `SceneWriter` becomes a thin shell over explicit
   writer-local owners.
2. Preparatory extraction without deleting the replaced mixed bodies from
   `scene_writer.dart` does not count as closure.
3. Any new private owner is valid only when it removes one mixed writer
   responsibility from `SceneWriter` in the same slice.
4. Metric improvement counts only when it follows from clarified writer-local
   ownership rather than compatibility wrappers.

## 8. Vertical Slices

### Slice 1. [x] Extract selection-only writer owner

#### Slice Contract

Selection-only transitions and exact selection-facing command results are owned
by an explicit writer-local module instead of mixed directly into
`SceneWriter`.

#### Change

Move selection-only transition bodies and exact selection result helpers out of
`scene_writer.dart` into one explicit private writer-local owner and keep
`SceneWriter` as the delegating boundary shell for those operations.

#### Verification

- `dcm calculate-metrics lib/src/controller/scene_writer.dart --report-all`
- MCP test runner: `test/controller/internal/scene_writer_test.dart`
- MCP test runner:
  `test/controller/commands/scene_commands_test.dart test/controller/commands/move_commands_test.dart`
- MCP test runner: `test/controller/scene_controller_randomized_txn_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `scene_writer.dart` no longer contains the replaced selection-only bodies.

### Slice 2. [x] Extract scene-setting and document boundary writer owner

#### Slice Contract

Scene-setting changed helpers and document replacement boundary transitions are
owned by an explicit writer-local module instead of mixed directly into
`SceneWriter`.

#### Change

Move `...Changed(...)` scene-setting helpers and document replacement boundary
logic out of `scene_writer.dart` into one explicit private writer-local owner
and keep `SceneWriter` as the delegating boundary shell.

#### Verification

- `dcm calculate-metrics lib/src/controller/scene_writer.dart --report-all`
- MCP test runner: `test/controller/internal/scene_writer_test.dart`
- MCP test runner: `test/controller/commands/scene_commands_test.dart`
- MCP test runner:
  `test/controller/core/scene_controller_commit_atomicity_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `scene_writer.dart` no longer contains the replaced scene-setting and
  document-boundary bodies.

### Slice 3. [x] Extract buffered signal owner and collapse `SceneWriter` to a thin shell

#### Slice Contract

Buffered signal enqueue has one explicit writer-local owner, and
`SceneWriter` is reduced to thin boundary orchestration plus exact mutation-op
forwarding.

#### Change

Move buffered signal enqueue logic out of `scene_writer.dart` into one explicit
private writer-local owner, adapt command adapters as required, and delete the
replaced mixed boundary code from `SceneWriter`.

#### Verification

- `dcm calculate-metrics lib/src/controller/scene_writer.dart --report-all`
- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- MCP test runner: `test/controller/internal/scene_writer_test.dart`
- MCP test runner:
  `test/controller/commands/scene_commands_test.dart test/controller/commands/draw_commands_test.dart test/controller/commands/move_commands_test.dart`
- MCP test runner:
  `test/controller/core/scene_controller_writer_lifecycle_test.dart test/controller/core/scene_controller_commit_atomicity_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `scene_writer.dart` no longer contains mixed selection, scene/document, or
  signal bodies and remains a thin shell over writer-local modules.
- `SceneWriter` RFC `44` is accepted as residual public-boundary breadth in
  this step, and `SceneWriterRuntime` coupling `17` is accepted as temporary
  exact mutation-op forwarding breadth before step `30`.
- Controller clone scan remains at `2` or fewer pairs with no pair involving
  `scene_writer.dart`.

## 9. Final Verification and Closure

- `flutter analyze`
- `dcm calculate-metrics lib/src/controller/scene_writer.dart lib/src/controller/scene_writer_runtime.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- MCP test runner:
  `test/controller/internal/scene_writer_test.dart test/controller/commands/scene_commands_test.dart test/controller/commands/draw_commands_test.dart test/controller/commands/move_commands_test.dart test/controller/core/scene_controller_writer_lifecycle_test.dart test/controller/core/scene_controller_commit_atomicity_test.dart test/controller/scene_controller_randomized_txn_test.dart`

Closure summary:

- `SceneWriter` is now a thin shell over `scene_writer_selection.dart`,
  `scene_writer_scene.dart`, `scene_writer_signals.dart`, and
  `scene_writer_command_results.dart`.
- Public `SceneWriteTxn` breadth did not change.
- Internal command adapters still consume exact writer-local semantics without
  snapshot diffing.
- Clone scan remains at `2` pairs, and neither pair involves
  `scene_writer.dart`.

## 9. Final Verification

- `dcm calculate-metrics lib/src/controller/scene_writer.dart --report-all`
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
