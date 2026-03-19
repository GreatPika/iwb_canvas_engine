language: russian

# Шаг 14.2. Закрыть regression-матрицу controller

## 1. Change Mandate

This change closes the unresolved controller-side regression matrix for write,
commit, command, and immutable-result semantics in the current
`lib/src/controller/**` ownership boundary.

## 2. Change Boundary

### Included in the Change
- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/scene_controller.dart`
- `lib/src/controller/mutation_executor.dart`
- `lib/src/controller/txn_context.dart`
- `lib/src/controller/mutation_op.dart`
- `lib/src/controller/commands/scene_commands.dart`
- `lib/src/controller/commands/draw_commands.dart`
- `lib/src/controller/commands/move_commands.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/commands/draw_commands_test.dart`
- `test/controller/commands/move_commands_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
- `test/controller/core/scene_controller_writer_lifecycle_test.dart`

### Not Included in the Change
- Serialization, model, or core boundary regressions
- Interactive/view pointer-host regressions
- Render/cache regressions

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/scene_controller.dart`
- `lib/src/controller/mutation_executor.dart`
- `lib/src/controller/txn_context.dart`
- `lib/src/controller/mutation_op.dart`
- `lib/src/controller/commands/scene_commands.dart`
- `lib/src/controller/commands/draw_commands.dart`
- `lib/src/controller/commands/move_commands.dart`

### Test Files
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/commands/draw_commands_test.dart`
- `test/controller/commands/move_commands_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
- `test/controller/core/scene_controller_writer_lifecycle_test.dart`

### Analysis Area
- `lib/src/controller/**`
- `test/controller/**`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Controller write semantics remain owned by `SceneWriter`,
   `MutationExecutor`, and `SceneControllerCore`; this step only closes their
   regression proofs.
2. `ClearSceneResult` remains an immutable result payload on the controller
   boundary.
3. Dispose, commit, and nested-write lifecycle rules remain controller-owned
   behavior, not interactive/view behavior.
4. Selection normalization and bulk delete semantics stay in the current
   controller boundary and are not moved into tests as a second owner.

## 5. Result Requirements

1. The unresolved controller matrix is covered for
   `writeSelectionReplace([])`, bulk delete across all paths, transform
   composition order, dispose-during-write behavior, immutable
   `ClearSceneResult`, and no-op point patches.
2. Controller tests prove the committed behavior through owner-level APIs and do
   not rely on indirect coverage from interactive or render tests.
3. The controller matrix keeps regression proof at the correct seam: command,
   write-txn, commit-lifecycle, or internal executor behavior.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Start from the existing `test/controller/**` split into `commands`,
  `internal`, `core`, and controller-root tests.
- Extend the owner-level tests closest to the current production seam.
- Keep internal helper assertions inside the controller test area.

### 6.2 Target Verification Units
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/commands/draw_commands_test.dart`
- `test/controller/commands/move_commands_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
- `test/controller/core/scene_controller_writer_lifecycle_test.dart`

### 6.3 Protected States, Data, or Structures
- Working selection normalization
- Commit atomicity and commit revision behavior
- Immutable controller result payloads
- Stroke `pointsRevision` monotonicity and no-op behavior

### 6.4 Allowed Semantic Change Zones
- Controller write-entry regression proofs
- Controller command-adapter regression proofs
- Commit lifecycle and failure regression proofs

### 6.8 Prohibited
- Proving controller behavior only through interactive wrappers
- Adding duplicate immutability owners outside the controller boundary
- Mixing controller regressions into render or view tests

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

### Slice 1. [ ] Selection and Delete Matrix

#### Slice Contract
Selection replacement and bulk delete semantics are closed by direct controller
tests across command and writer entrypoints.

#### Change
Extend the command and writer tests that own selection replacement and bulk
delete behavior.

#### Verification
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/internal/scene_writer_test.dart`

#### Positive Scenarios
- valid selection replacement returns the current normalized committed ids
- bulk delete removes all deletable nodes across the current controller paths

#### Negative Scenarios
- `writeSelectionReplace([])` keeps the current no-op semantics
- missing, locked, background, or otherwise rejected ids do not report false
  success through bulk delete paths

#### Closure Evidence
- Green run of the listed tests.
- The original selection/delete items from step `14` are mapped to these
  controller owners.

### Slice 2. [ ] Commit Lifecycle and Result Matrix

#### Slice Contract
Controller commit order, failure behavior, and immutable result payloads have
explicit regression proofs.

#### Change
Extend the controller-core and internal tests around commit, dispose, and
`ClearSceneResult`.

#### Verification
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/core/scene_controller_core_dispose_fail_fast_test.dart`
- `test/controller/core/scene_controller_writer_lifecycle_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/internal/scene_writer_test.dart`

#### Positive Scenarios
- committed transforms apply in the current composition order
- immutable `ClearSceneResult.removedNodeIds` remains safe after construction

#### Negative Scenarios
- dispose during active write fails according to the current controller
  lifecycle contract
- stale or nested write handles do not poison the commit lifecycle

#### Closure Evidence
- Green run of the listed tests.
- The unresolved lifecycle and immutable-result items from step `14` are tied
  to one controller-owned proof set.

### Slice 3. [ ] Point Patch Revision Matrix

#### Slice Contract
Point-patch no-op behavior is closed by targeted regression proofs for copy and
`pointsRevision` invariants.

#### Change
Extend the controller tests that own stroke patch application and commit
materialization.

#### Verification
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/internal/scene_writer_test.dart`

#### Positive Scenarios
- mutating point patches copy input points on commit
- effective geometry changes advance `pointsRevision`

#### Negative Scenarios
- no-op point patches do not copy the point list
- no-op point patches do not advance `pointsRevision`

#### Closure Evidence
- Green run of the listed tests.
- No original point-patch regression item remains without a direct controller
  proof.

## 9. Final Verification

- `dart run tool/check_invariant_coverage.dart`
- MCP test shards for `test/controller/internal`
- MCP test shards for `test/controller/core test/controller/commands` plus
  controller-root `*_test.dart` files

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
