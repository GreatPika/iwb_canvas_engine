language: russian

# Шаг 28. Довести controller transaction substrate до финальной формы

## 1. Change Mandate

Этот шаг доводит controller-layer до финальной архитектурной формы после
facade/runtime slice: transaction substrate под `SceneControllerCore` должен
перестать держать mixed-owner hotspot-ы в `TxnContext` и
`SpatialIndexCache`, а remaining controller clone debt должен быть сведен к
двум честным локальным парам вне transaction substrate.

## 2. Change Boundary

### Included in the Change

- Final transaction-substrate cleanup под уже введённым
  `SceneControllerCore -> SceneControllerCommitRuntime` boundary.
- Выделение явных private owner-ов для transaction workspace и derived state
  из `txn_context.dart`.
- Упрощение prepare/apply pipeline в `internal/spatial_index_cache.dart`.
- Удаление clone cluster в `scene_mutation_applier.dart`, связанного с
  scene-settings mutation fanout.
- Минимальная адаптация `scene_writer.dart` и других controller-private
  consumers, необходимая для новой transaction-substrate boundary.
- Structural, metric, clone, architecture, and roadmap updates, directly
  tied to this step.

### Not Included in the Change

- Reopening `SceneControllerCore` or `SceneControllerCommitRuntime` beyond
  minimal adaptation required by the new transaction-substrate boundary.
- Public API changes for `SceneControllerCore`, `SceneWriteTxn`, commands,
  streams, or write semantics.
- Reopening `mutation_op.dart` as the mutation catalog boundary.
- Reopening `node_mutation_applier.dart` beyond minimal adaptation required by
  the new transaction-substrate boundary.
- Clone cleanup in `draw_commands.dart` or `scene_invariants.dart`.
- Any work in `lib/src/interactive/**`, `lib/src/view/**`, `lib/src/render/**`,
  `lib/src/model/**`, `lib/src/contract/**`, or `lib/src/serialization/**`.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/scene_mutation_applier.dart`
- `lib/src/controller/txn_context.dart`
- `lib/src/controller/txn_workspace.dart`
- `lib/src/controller/txn_derived_state.dart`
- `lib/src/controller/internal/spatial_index_cache.dart`

### Test Files

- `test/controller/internal/change_set_txn_context_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/controller/core/scene_controller_writer_lifecycle_test.dart`
- `test/controller/core/scene_controller_spatial_index_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`

### Fixture and Supporting Data Files

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_28_controller_transaction_substrate_finalization.md`

### Analysis Area

- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/scene_mutation_applier.dart`
- `lib/src/controller/txn_context.dart`
- `lib/src/controller/txn_workspace.dart`
- `lib/src/controller/txn_derived_state.dart`
- `lib/src/controller/internal/spatial_index_cache.dart`
- `lib/src/controller/**`
- `lib/src/controller/internal/**`
- `test/controller/internal/**`
- `test/controller/core/**`
- `test/controller/commands/**`
- `test/controller/scene_controller_randomized_txn_test.dart`
- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must reduce one of the remaining
  controller mixed-owner hotspots or the scene-settings clone cluster.
- Every new implementation file must represent one explicit private owner with
  one clear reason to change.
- Every modified test must validate transaction-substrate behavior, clone
  removal, or the new structural boundary introduced by this step.
- Untied changes are out of scope.

## 4. Locked Decisions

1. `SceneControllerCore` remains the public controller facade.
2. `SceneControllerCommitRuntime` remains the controller-private orchestration
   owner introduced by the current facade/runtime slice.
3. `SceneWriter` remains the single internal implementation of
   `SceneWriteTxn` and the owner of exact command-facing write results and
   buffered signal enqueue semantics.
4. `TxnContext` remains the root transaction object, but workspace and
   derived-state ownership may move into explicit private modules.
5. `SpatialIndexCache` remains controller-internal and must preserve the
   existing incremental-vs-rebuild semantics.
6. `mutation_op.dart` remains the typed mutation catalog boundary for this
   step.
7. `node_mutation_applier.dart` remains the node-mutation executor boundary
   for this step.
8. Remaining clone pairs in `draw_commands.dart` and `scene_invariants.dart`
   are not part of this step.
9. Metric improvement is valid only when it follows from clarifying
   transaction-substrate ownership or removing the actual scene-settings clone
   cluster.

## 5. Result Requirements

1. `TxnContext` no longer contains the current mixed file-local ownership for
   transaction workspace and derived-state internals; those owners are
   explicit and private.
2. `internal/spatial_index_cache.dart` no longer reports `HIGH` for
   `writePrepareCommit`.
3. `scene_mutation_applier.dart` no longer contributes the current
   six-pair structural clone cluster from `_setBackgroundColor`,
   `_setGridEnabled`, `_setGridCellSize`, and `_setCameraOffset`.
4. `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
   reports `10` or fewer `HIGH` entries after the change.
5. The remaining controller-layer `HIGH` entries are limited to the accepted
   public/catalog/executor seams:
   `scene_controller.dart`,
   `scene_controller_commit_runtime.dart`,
   `scene_writer.dart`,
   `mutation_op.dart`,
   and `node_mutation_applier.dart`.
6. `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
   reports `2` or fewer pairs after the change.
7. Public controller behavior remains unchanged for:
   - sync-only `write(...)`;
   - nested-write failure;
   - exact command-facing write results;
   - buffered signal enqueue semantics;
   - transaction id/layer/revision allocation;
   - node-locator and all-node-id materialization semantics;
   - spatial-index incremental/rebuild behavior.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current controller-layer baseline is `17 HIGH` entries from:
  `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`.
- Current transaction-substrate hotspot baseline:
  - `scene_writer.dart`: file imports `13`, `SceneWriter` RFC `59`,
    `SceneWriter` WMC `48`
  - `txn_context.dart`: `TxnContext` RFC `71`, `TxnContext` WMC `50`,
    `_TxnWorkspace` WMC `38`, `_TxnDerivedState` WMC `58`
  - `internal/spatial_index_cache.dart`: `writePrepareCommit` cyclomatic `15`,
    source-lines-of-code `53`
- Current controller clone baseline is `8` pairs from
  `dart run tool/analysis/find_similar_clones.dart lib/src/controller`.
- `6` of those `8` clone pairs come from the scene-settings setter cluster in
  `scene_mutation_applier.dart`.
- The remaining `2` clone pairs are:
  - `draw_commands.dart` (`writeDrawStroke` / `writeDrawLine`)
  - `scene_invariants.dart`
    (`_txnCollectDuplicateNodeIds` / `_txnCollectDuplicateLayerIds`)
- `SceneControllerCore` and `SceneControllerCommitRuntime` already form the
  current controller-private facade/runtime graph and are no longer the
  primary structural target of this step.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dcm calculate-metrics lib/src/controller/txn_context.dart lib/src/controller/txn_workspace.dart lib/src/controller/txn_derived_state.dart lib/src/controller/internal/spatial_index_cache.dart lib/src/controller/scene_mutation_applier.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core test/controller/commands` plus
  controller-root `*_test.dart`
- MCP test runner: `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test`

### 6.3 Protected States, Data, or Structures

- Public `SceneWriteTxn` method set and return semantics.
- `SceneWriter` buffered signal enqueue behavior.
- Transaction active/closed lifecycle and stale-handle rejection.
- `TxnContext` node-id, layer-id, and instance-revision allocation semantics.
- Lazy `allNodeIds`, node-locator, and layer-id-index materialization rules.
- Scene-structure mutation behavior for clear/replace/ensure-layer.
- Scene-settings mutation behavior for background, grid, and camera changes.
- Spatial-index incremental prepare/apply and full-rebuild fallback behavior.

### 6.4 Allowed Semantic Change Zones

- Transaction workspace ownership under `TxnContext`.
- Transaction derived-state ownership under `TxnContext`.
- Scene-settings mutation helper structure in `scene_mutation_applier.dart`.
- Spatial-index prepare pipeline structure in `internal/spatial_index_cache.dart`.
- Minimal `SceneWriter` adaptation required to consume the new private
  transaction-substrate owners.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `SceneWriter` must remain the only `SceneWriteTxn` implementation in
  `lib/src/controller/**`.
- `TxnWorkspace` and `TxnDerivedState` must stay private to
  `lib/src/controller/**` and must not become public exports or package
  entrypoints.
- `TxnContext` must remain the transaction root object seen by writer and
  mutation executors; introducing a second peer transaction root is forbidden.
- `SpatialIndexCache` may be split only into private helper logic that keeps
  the same public controller-internal API.
- `scene_mutation_applier.dart` clone cleanup must delete the repeated
  scene-settings setter shape instead of wrapping each setter in one more
  helper layer.
- `mutation_op.dart`, `node_mutation_applier.dart`, `draw_commands.dart`,
  and `scene_invariants.dart` are non-regression only in this step unless one
  exact minimal adaptation is required to close a listed slice verification.

### 6.8 Prohibited

- Reopening `SceneControllerCore` or `SceneControllerCommitRuntime` as the
  main subject of the step.
- Splitting `SceneWriteTxn` into multiple writer facades or changing command
  return semantics.
- Changing transaction/allocator/spatial-index behavior only to satisfy
  metrics.
- Moving signal enqueue ownership out of `SceneWriter`.
- Leaving `_TxnWorkspace` or `_TxnDerivedState` semantics duplicated across
  both old and new files.
- Pulling `draw_commands.dart` or `scene_invariants.dart` clone cleanup into
  this step.
- Introducing wrappers or pass-through files whose main effect is moving
  imports without clarifying ownership.

## 7. Execution Rules

1. This step closes only if the transaction substrate becomes structurally
   explicit and the controller-layer residuals are reduced to accepted seams.
2. Preparatory file moves without metric or clone closure do not count as a
   closed slice.
3. Any new private owner is valid only when it deletes the replaced mixed
   ownership from the old file in the same slice.
4. Clone cleanup counts only if the old repeated setter bodies are removed and
   the controller clone scan reaches the target baseline.
5. Scope expansion into non-listed controller debt is forbidden until the
   mandatory slices of this step are closed.

## 8. Vertical Slices

### Slice 1. [ ] Make transaction workspace and derived state explicit private owners

#### Slice Contract

`TxnContext` becomes the thin transaction root over explicit private
`TxnWorkspace` and `TxnDerivedState` owners, removing the current mixed file
hotspot without changing transaction semantics.

#### Change

Move the current workspace and derived-state ownership out of
`txn_context.dart` into `txn_workspace.dart` and `txn_derived_state.dart`,
delete the replaced mixed implementations from `txn_context.dart`, and keep
only the transaction-root API and debug counters in the root file.

#### Verification

- `dcm calculate-metrics lib/src/controller/txn_context.dart lib/src/controller/txn_workspace.dart lib/src/controller/txn_derived_state.dart --report-all`
- `flutter analyze`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core test/controller/commands` plus
  controller-root `*_test.dart`

#### Positive Scenarios

- Transaction lifecycle still rejects stale handles after commit or rollback.
- Node-id, layer-id, and instance-revision allocation stay monotonic and
  transaction-owned.
- Lazy node-locator, all-node-id, and layer-id-index materialization keeps the
  same behavior under repeated transaction operations.

#### Negative Scenarios

- Closed transactions still throw on any writer or context access.
- Repeated misses do not rebuild the layer-id index eagerly.

#### Closure Evidence

- Green runs of the listed controller internal/core verifications.
- `dcm calculate-metrics` shows that the old mixed-owner hotspot in
  `txn_context.dart` has been redistributed into explicit private owners.

### Slice 2. [ ] Remove scene-settings clone cluster and stabilize spatial-index prepare pipeline

#### Slice Contract

The scene-settings mutation fanout no longer produces the current six clone
pairs, and `SpatialIndexCache.writePrepareCommit` no longer remains a mixed
algorithm hotspot.

#### Change

Delete the repeated scene-settings setter shape in
`scene_mutation_applier.dart` through one shared mutation helper, and split
`SpatialIndexCache.writePrepareCommit` into small deterministic private
branches while preserving incremental-prepare and rebuild fallback semantics.

#### Verification

- `dcm calculate-metrics lib/src/controller/internal/spatial_index_cache.dart lib/src/controller/scene_mutation_applier.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- `flutter analyze`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core test/controller/commands` plus
  controller-root `*_test.dart`

#### Positive Scenarios

- Spatial index still applies incremental commits when delta data is available.
- Spatial index still falls back to rebuild on document replace, epoch change,
  or failed incremental preparation.
- Background/grid/camera mutations still report exact changed/no-op results.

#### Negative Scenarios

- Invalid grid cell size and invalid camera offsets still fail at the mutation
  guard boundary.
- Failed incremental prepare still falls back to rebuild instead of leaving the
  cache in an inconsistent state.

#### Closure Evidence

- Green targeted controller internal/core tests for spatial index and scene
  settings mutations.
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
  reports no clone pair rooted in `scene_mutation_applier.dart`.
- `dcm calculate-metrics` shows no `HIGH` on
  `SpatialIndexCache.writePrepareCommit`.

### Slice 3. [ ] Rebaseline controller as a closed architecture frontier

#### Slice Contract

After the transaction-substrate cleanup, controller residual debt is reduced
to accepted public/catalog/executor seams, and the controller layer reaches
its final baseline.

#### Change

Apply the minimal `SceneWriter` and controller-private adaptations required by
the new transaction-substrate owners, update architecture and roadmap docs,
and rebaseline controller metrics and clone scans against the final accepted
residual set.

#### Verification

- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core test/controller/commands` plus
  controller-root `*_test.dart`
- MCP test runner: `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test`

#### Positive Scenarios

- Controller public write, signal, and repaint behavior stays unchanged.
- Controller command results and transaction semantics remain identical to the
  pre-step behavior.

#### Negative Scenarios

- No new controller clone pair appears outside the accepted
  `draw_commands.dart` and `scene_invariants.dart` residuals.
- No new `HIGH` entry appears in non-controller layers.

#### Closure Evidence

- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
  reports `10` or fewer `HIGH` entries.
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
  reports `2` or fewer pairs.
- Remaining `HIGH` entries are limited to the accepted residual seams named in
  Result Requirement 5.
- Architecture and roadmap docs are updated in the same change.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dcm calculate-metrics lib/src/controller lib/src/controller/internal --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/controller`
- MCP test runner: `test/core`
- MCP test runner: `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core test/controller/commands` plus
  controller-root `*_test.dart`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
