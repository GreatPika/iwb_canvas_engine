# Change Contract

## 1. Change Mandate

Make transaction handles unreadable after callback close by moving transaction
read ownership into `SceneWriterRuntime`, returning detached immutable read
values, and proving the lifetime contract for both `SceneWriteTxn` and
`SceneWriter`.

## 2. Change Boundary

### Included in the Change

- move transaction read-boundary ownership for `snapshot` and
  `selectedNodeIds` into `SceneWriterRuntime`
- remove transaction-side live selection aliasing from `SceneWriter`
- align both public `SceneWriteTxn` and internal `SceneWriter` handles with the
  same closed-handle read semantics
- add failing lifecycle reproducers first, then neighboring guard tests for
  commit and rollback read paths
- add a lightweight structural proof that `SceneWriter` public read getters
  delegate into runtime-owned boundary helpers
- update public and architecture documentation for the transaction read
  lifetime and detached selection semantics
- update invariant proof ownership for transaction writer lifetime

### Not Included in the Change

- new AST/tooling guardrails that ban direct `TxnContext` reads across the
  repository
- changes to committed-store read-side caching or committed selection view
  identity
- changes to `TxnContext` close behavior beyond its current active/inactive
  lifetime flag
- changes to unrelated write planning, commit execution, replace-scene
  sequencing, or pointer interaction flows

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` — active plan index requires one linked step document per step
- `lib/src/contract/scene_write_txn.dart` — public contract says a
  `SceneWriteTxn` handle is valid only inside the active write callback
- `lib/src/controller/scene_write_txn_public_adapter.dart` — public adapter
  delegates transaction reads and writes to `SceneWriter`
- `lib/src/controller/scene_writer.dart` — current read getters bypass runtime
  ownership, materialize `snapshot` directly from `ctx.workingScene`, and cache
  a transaction-lifetime `UnmodifiableSetView` over `ctx.workingSelection`
- `lib/src/controller/scene_writer_runtime.dart` — current runtime already owns
  active-check enforcement for write execution and staged replace-scene writes
- `lib/src/controller/txn_context.dart` — close semantics only flip `_isActive`
  and do not poison already-issued values
- `lib/src/controller/scene_controller_commit_write_runner.dart` — write runner
  closes the transaction in `finally`, so stale handle reads happen only after
  callback close
- `lib/src/controller/scene_controller_commit_runtime.dart` — committed
  controller read side owns stable committed `selectedNodeIds` view reuse and
  is the correct precedent for read-boundary ownership, but not for transaction
  lifetime semantics
- `lib/src/controller/scene_store_controller.dart` — public controller routes
  `write(...)` and `writeWithSceneWriter(...)` through the same runtime-owned
  write path
- `lib/src/controller/scene_controller_committed_mutation_access.dart` —
  internal committed mutation facade can still hand out `SceneWriter`, so the
  fix must cover internal writer lifetime, not only the public adapter
- `test/controller/core/scene_controller_writer_lifecycle_test.dart` —
  existing lifecycle proof covers stale writes after commit/rollback but does
  not cover stale reads
- `test/controller/internal/scene_write_txn_public_adapter_test.dart` —
  adapter proof covers delegation surface but not lifecycle enforcement
- `test/controller/internal/scene_writer_test.dart` — internal writer tests
  currently lock the wrong transaction-side selection semantics by asserting
  stable live-view identity reuse
- `test/controller/core/scene_controller_commit_atomicity_test.dart` —
  committed controller tests correctly lock stable committed selection view
  reuse and must remain unaffected
- `API_GUIDE.md` — public guide already states that a transaction handle is
  valid only inside the active callback
- `ARCHITECTURE.md` — architecture already states that mutable transaction
  state must not leak after callback close and that committed reads are
  snapshot-backed
- `tool/invariant_registry.dart` — `INV-ENG-TXN-WRITER-LIFETIME` currently
  points at a proof surface that does not directly exercise stale transaction
  reads

### Current Entry Path

- `SceneStoreController.write(...)` ->
  `SceneControllerCommitRuntime.write(...)` ->
  `SceneControllerCommitWriteRunner.run(...)` ->
  callback receives `SceneWriteTxnPublicAdapter(SceneWriter(...))`
- `SceneStoreController.writeWithSceneWriter(...)` ->
  `SceneControllerCommitRuntime.writeWithSceneWriter(...)` ->
  `SceneControllerCommitWriteRunner.run(...)` ->
  callback receives `SceneWriter(...)`

### Current Owner

- transaction runtime ownership lives in `lib/src/controller/scene_writer_runtime.dart`
- transaction mutable state ownership lives in `lib/src/controller/txn_context.dart`
- transaction public/internal handle surface lives in
  `lib/src/controller/scene_writer.dart` and
  `lib/src/controller/scene_write_txn_public_adapter.dart`

### Adjacent Abstractions

- `SceneWriterRuntime` — current owner for write execution and staged
  replace-scene entrypoints
- `TxnContext` — mutable transaction workspace and active flag owner
- `SceneControllerCommitRuntime` — committed-store read boundary owner for
  controller-level cached views
- `SceneStoreControllerCommittedMutationAccess` — internal committed mutation
  facade that must inherit the same closed-handle behavior through
  `SceneWriter`

### Existing Tests

- `test/controller/core/scene_controller_writer_lifecycle_test.dart` — proves
  stale writes fail after commit/rollback and that write failures do not poison
  later writes
- `test/controller/internal/scene_write_txn_public_adapter_test.dart` — proves
  the public adapter delegates the write surface to `SceneWriter`
- `test/controller/internal/scene_writer_test.dart` — proves `SceneWriter`
  remains a thin shell and currently locks the transaction-side stable
  `selectedNodeIds` identity that this change must intentionally replace
- `test/controller/core/scene_controller_commit_atomicity_test.dart` — proves
  committed controller-side snapshot and selection view caching behavior that
  must remain unchanged
- `test/controller/core/scene_controller_commit_runtime_contract_test.dart` —
  existing source-level structural proof pattern for controller/runtime
  ownership boundaries

### Analogous Implementation Path

- `lib/src/controller/scene_controller_commit_runtime.dart` — committed
  controller reads are routed through a dedicated owner that decides cached
  snapshot/view semantics centrally instead of exposing direct store internals
- `lib/src/controller/scene_store_controller.dart` — controller `snapshot`
  materialization is owned at the boundary getter rather than leaking internal
  mutable scene references

### Governing Repository Rules

- repository `AGENTS.md` and project instructions — fixes must be applied at
  the owning layer, not as adapter-only call-site patches
- repository `AGENTS.md` and project instructions — public behavior changes
  must update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and
  `CHANGELOG.md`
- `API_GUIDE.md` — transaction handle validity is limited to the active
  callback
- `ARCHITECTURE.md` — transaction-owned mutable runtime state must not leak
  after callback close
- `tool/invariant_registry.dart` — important behavior must have explicit proof
  surfaces with matching invariant markers

### Rejected Misleading Local Patterns

- `SceneWriteTxnPublicAdapter`-only fix — wrong seam because
  `writeWithSceneWriter(...)` would remain able to read closed transaction state
- transaction-side stable `UnmodifiableSetView` reuse in `SceneWriter` — wrong
  lifetime model because it aliases mutable transaction state beyond callback
  close
- poisoning or clearing `TxnContext` on `txnClose()` — wrong ownership level
  because it mixes mutable workspace ownership with public handle lifetime
  policy
- committed controller selection-view caching pattern in
  `SceneControllerCommitRuntime` — correct for committed read state, wrong for
  short-lived transaction handles

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- transaction boundary ownership inside the controller write subsystem

#### Selected Architectural Form

- `SceneWriterRuntime` becomes the single owner for both transaction writes and
  transaction reads that cross the public/internal writer handle boundary
- `SceneWriter` becomes a thin shell that delegates read and write entrypoints
  to runtime-owned helpers
- runtime-owned transaction reads always perform the active-handle check before
  materialization and always return detached immutable value objects

#### Owning Layer or Module

- owner: `lib/src/controller/scene_writer_runtime.dart`
- thin surface: `lib/src/controller/scene_writer.dart`
- public adapter passthrough:
  `lib/src/controller/scene_write_txn_public_adapter.dart`

#### Dependency Direction

- `SceneWriteTxnPublicAdapter` -> `SceneWriter`
- `SceneWriter` -> `SceneWriterRuntime`
- `SceneWriterRuntime` -> `TxnContext`
- `TxnContext` remains unaware of public read-boundary semantics

#### State and Data Ownership

- `TxnContext` continues to own mutable `workingScene` and `workingSelection`
- `SceneWriterRuntime` owns boundary checks and conversion from mutable
  transaction state to detached immutable public values
- `SceneWriter` owns no cached transaction read state

#### Entry and Exit Boundaries

- entry: every `SceneWriter.snapshot` and `SceneWriter.selectedNodeIds` access,
  whether reached through `SceneWriteTxn` or direct internal writer access
- exit: detached immutable `SceneSnapshot` and detached immutable
  `Set<NodeId>` values
- close semantics: any new boundary read after `txnClose()` throws `StateError`;
  values returned while active remain ordinary immutable values

#### Permitted Extension Seam

- any future transaction read getter added to `SceneWriter` must route through
  `SceneWriterRuntime` helper methods that enforce active-check plus detached
  materialization

#### Rejected Alternatives

- keep read getters in `SceneWriter` and add local `ensureTxnActive()` calls —
  too weak because it still leaves read-boundary ownership split across files
  and makes future live-alias regressions easy to reintroduce
- move close-time poisoning into `TxnContext` — wrong ownership level and would
  retroactively entangle mutable workspace internals with already-issued value
  semantics

#### Why This Level Is Correct

- write-path lifetime enforcement already lives in `SceneWriterRuntime`, so the
  missing read enforcement is a split-owner defect
- both public and internal transaction handles already converge on
  `SceneWriter`, so routing all reads through runtime closes the bug once at
  the shared owner
- detached immutable values match existing `snapshot` value semantics and avoid
  transaction-lifetime aliasing through `selectedNodeIds`

### 4B. Architecture Decision Gate

Not needed. The owner, seam, and dependency direction are locked by current
repository structure and inspected evidence.

## 5. Locked Decisions

1. `SceneWriter.selectedNodeIds` changes from stable live-view semantics to a
   detached immutable snapshot per access.
2. `SceneWriter.snapshot` and `SceneWriter.selectedNodeIds` must be closed
   symmetrically: both throw on new reads after callback close.
3. Already-issued values from an active transaction remain valid immutable
   values after close; the handle is what expires, not previously-returned
   values.
4. No new repository-wide guardrail is added in this change; structural drift
   is caught with source-level structural tests at the owner seam.
5. `INV-ENG-TXN-WRITER-LIFETIME` proof ownership moves to direct lifecycle
   tests that exercise stale reads as well as stale writes.

## 6. Result Requirements

1. After commit or rollback, any new `snapshot` or `selectedNodeIds` read
   through a captured `SceneWriteTxn` or `SceneWriter` throws `StateError`.
2. A `selectedNodeIds` value captured during an active transaction is detached
   from later transaction mutations and does not alias `workingSelection`.
3. Committed controller read-side caching and committed `selectedNodeIds` view
   identity semantics remain unchanged.
4. `SceneWriter` no longer owns transaction read-state caching or direct public
   reads from `TxnContext`.
5. Public docs describe the closed-handle read rule and detached transaction
   selection semantics consistently.

## 7. Execution Order and Gates

### Required Order

- first add one failing stale-read reproducer and 1 to 3 neighboring guard
  tests at the lifecycle owner surfaces
- then move read-boundary ownership into `SceneWriterRuntime` and remove the
  transaction-side live selection alias
- then align docs and invariant proof ownership with the implemented behavior

### Successor Seam and Retirement Gates

- successor seam: runtime-owned transaction read helpers in
  `SceneWriterRuntime`
- retirement gate: `SceneWriter` no longer caches `_selectedNodeIdsView` and no
  public read getter directly materializes from `runtime.ctx.workingScene` or
  `runtime.ctx.workingSelection`
- proof-retirement gate: old transaction-side stable selection identity test is
  replaced by detached selection semantics tests before the change is closed

### Deferred Broad Verification

- run the required code-change verification preset only after all slices land
- do not add repository-wide guardrail work to this contract; that remains a
  separate future decision if lifecycle and structural tests prove insufficient

## 8. File Map

### Implementation Files

- `lib/src/controller/scene_writer_runtime.dart`
- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/scene_write_txn_public_adapter.dart`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `README.md`
- `CHANGELOG.md`
- `tool/invariant_registry.dart`

### Test Files

- `test/controller/core/scene_controller_writer_lifecycle_test.dart`
- `test/controller/internal/scene_write_txn_public_adapter_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`

### Fixtures and Supporting Data

- none

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `tool/invariant_registry.dart`

### Analysis Area

- controller transaction lifetime boundary

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-TXN-WRITER-LIFETIME`
- `INV-ENG-SCENE-WRITE-TXN-ADAPTER-BOUNDARY`
- `INV-ENG-TXN-FINALIZED-BEFORE-COMMIT-PLAN`

### Required Proof

- behavioral proof:
  - stale `snapshot` read through `SceneWriteTxn` throws after commit
  - stale `snapshot` read through `SceneWriteTxn` throws after rollback
  - stale `selectedNodeIds` read through `SceneWriteTxn` throws after close
  - stale `snapshot` and `selectedNodeIds` reads through captured
    `SceneWriter` throw after close
  - a `selectedNodeIds` value captured while active stays detached from later
    transaction mutations
- structural proof:
  - source-level proof that `SceneWriter` read getters delegate into
    `SceneWriterRuntime`
  - source-level proof that `SceneWriter` no longer owns a cached transaction
    `UnmodifiableSetView` for `selectedNodeIds`
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- transaction read getters and runtime helpers
- transaction lifecycle and adapter tests
- internal writer structural proof tests
- invariant registry proof mapping
- user-facing docs required by repository policy

### Forbidden Moves

- do not change committed controller snapshot or committed selection view
  caching semantics
- do not add close-time nulling or clearing of `TxnContext` workspace state
- do not fix only the public adapter while leaving `SceneWriter` stale reads
  available
- do not add a new repository guardrail tool rule in this contract

### Optional: Resolution Rules

- if a detached immutable selection snapshot is needed, prefer
  `Set<NodeId>.unmodifiable(...)` over a live `UnmodifiableSetView` backed by
  mutable transaction state
- if a source-level structural proof is needed, extend an existing owner-side
  source inspection test rather than creating a heavier tool rule

## 10. Vertical Slices

### Slice 1. [ ] Runtime-Owned Transaction Read Boundary

#### Slice Contract

`SceneWriteTxn` and `SceneWriter` both reject new `snapshot` and
`selectedNodeIds` reads after transaction close, and transaction-side
`selectedNodeIds` no longer aliases mutable transaction state.

#### Change

- add one failing stale-read reproducer and neighboring guard tests in
  lifecycle-focused test surfaces
- add runtime-owned transaction read helpers in `SceneWriterRuntime`
- rewrite `SceneWriter.snapshot` and `SceneWriter.selectedNodeIds` to delegate
  into runtime-owned helpers
- remove `_selectedNodeIdsView` and transaction-side live-view reuse semantics
- keep `SceneWriteTxnPublicAdapter` as a thin passthrough over the corrected
  internal writer seam

#### Behavioral Verification

- `flutter test test/controller/core/scene_controller_writer_lifecycle_test.dart`
- `flutter test test/controller/internal/scene_write_txn_public_adapter_test.dart`
- `flutter test test/controller/internal/scene_writer_test.dart`

#### Structural Verification

- `flutter test test/controller/internal/scene_writer_test.dart`
  Source-inspection expectations prove that `SceneWriter` read getters delegate
  into runtime-owned helpers and no longer own a cached transaction selection
  view.

#### Fixtures Used

- in-memory controller snapshots already defined in existing lifecycle tests

#### Positive Scenarios

- captured `SceneWriteTxn.snapshot` throws after successful commit
- captured `SceneWriteTxn.snapshot` throws after rollback
- captured `SceneWriteTxn.selectedNodeIds` throws after close
- `selectedNodeIds` captured while active stays unchanged after later mutation
- captured `SceneWriter` stale reads fail the same way as the public adapter

#### Negative Scenarios

- committed controller `selectedNodeIds` identity reuse tests remain green
- committed controller `snapshot` caching tests remain green
- no close-time poisoning breaks immutable values already captured while active

#### Closure Evidence

- stale read reproducers pass only through runtime-owned getters
- source inspection proves `SceneWriter` no longer exposes transaction read
  aliases backed by mutable `TxnContext` state

### Slice 2. [ ] Contract and Proof Alignment

#### Slice Contract

Repository docs and invariant proof ownership describe the implemented
transaction lifetime semantics without preserving the old live-view contract.

#### Change

- update transaction contract wording in `API_GUIDE.md`
- update architecture wording in `ARCHITECTURE.md`
- add concise user-visible note to `README.md` and `CHANGELOG.md`
- repoint `INV-ENG-TXN-WRITER-LIFETIME` proof ownership to the direct lifecycle
  test surface that now covers stale reads

#### Behavioral Verification

- `flutter test test/controller/core/scene_controller_writer_lifecycle_test.dart`
- `flutter test test/controller/core/scene_controller_commit_atomicity_test.dart`

#### Structural Verification

- inspect `tool/invariant_registry.dart` marker/proof mapping consistency
- `flutter test test/controller/internal/scene_writer_test.dart`

#### Fixtures Used

- none

#### Positive Scenarios

- docs state that the handle expires after callback close
- docs state that transaction `selectedNodeIds` is a detached immutable read
  value, not a live alias
- invariant registry points to the test surface that actually proves stale
  read rejection

#### Negative Scenarios

- no documentation reintroduces transaction live-view wording
- no invariant proof mapping remains tied only to a surface that misses stale
  reads

#### Closure Evidence

- docs and invariant registry match the new runtime-owned boundary semantics

## 11. Final Verification

- create a changed-paths file covering every modified repository-relative path
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<that-file>`
- `flutter test test/controller/core/scene_controller_writer_lifecycle_test.dart`
- `flutter test test/controller/internal/scene_write_txn_public_adapter_test.dart`
- `flutter test test/controller/internal/scene_writer_test.dart`
- `flutter test test/controller/core/scene_controller_commit_atomicity_test.dart`

## 12. Acceptance Criteria

- the transaction-handle read boundary is owned by `SceneWriterRuntime`
- `SceneWriter` no longer exposes a transaction-lifetime live alias of
  `workingSelection`
- stale reads through both `SceneWriteTxn` and `SceneWriter` throw after close
- detached values captured while active remain usable immutable values
- committed controller read-side semantics stay unchanged
- docs and invariant proof ownership match the implemented behavior
