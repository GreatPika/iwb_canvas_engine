language: russian

# Шаг 19.7. Закрыть residual runtime owner hot spots после 19.6

## 1. Change Mandate

Этот шаг закрывает residual runtime hot spots после `19.6` через точечные
owner corrections в commit, mutation, and interactive runtime paths without
reopening solved runtime slices or degrading architecture for metrics.

## 2. Change Boundary

### Included in the Change

- Corrective owner work for committed store payload, invariant proof surface,
  and store apply path.
- Residual mutation-pipeline owner work between `SceneWriter` and
  `MutationExecutor`.
- Residual interactive runtime cleanup in `SceneControllerInteractive` and
  `InteractiveMoveSession`.
- Post-correction runtime rebaseline for the same step-19 runtime family.

### Not Included in the Change

- Contract/model/serialization boundary work
- Render/view hotspot work
- Public API and transport contract changes

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/controller/scene_controller.dart`
- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/mutation_executor.dart`
- `lib/src/controller/mutation_op.dart`
- `lib/src/controller/txn_context.dart`
- `lib/src/controller/scene_invariants.dart`
- `lib/src/controller/committed_store_state.dart`
- `lib/src/interactive/scene_controller_interactive.dart`
- `lib/src/interactive/internal/interactive_move_session.dart`

### Test Files

- `test/controller/core/**`
- `test/controller/internal/**`
- `test/controller/scene_invariants_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`
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

- Every modified implementation file must be tied to exactly one corrective
  slice.
- Every modified test must be tied to one listed verification surface.
- Every modified planning document must be tied to one corrective slice or the
  final rebaseline.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Committed `SceneSnapshot` remains the single source of truth.
2. Runtime stack must not introduce second caches, sync glue, or metric-only
   wrappers.
3. Public controller and interactive contracts remain behaviorally equivalent.
4. Pointer semantics, selection exclusivity, signal ordering, and dispose
   fail-fast behavior remain protected.
5. This step stays inside residual runtime scope confirmed by `19.6`.

## 5. Result Requirements

1. Residual runtime owner corrections remove the remaining mixed commit,
   mutation, and interactive responsibilities from the step-19 hotspot family.
2. Runtime-stack hotspot baseline improves against the measured post-`19.6`
   value of `28` `HIGH+` entries across
   `scene_controller.dart`,
   `scene_writer.dart`,
   `mutation_executor.dart`,
   `txn_context.dart`,
   `scene_invariants.dart`,
   `scene_controller_interactive.dart`,
   and `interactive_move_session.dart`.
3. Runtime-related clone clusters do not regress above the measured
   post-`19.6` value of `5`.
4. Residual runtime work after this corrective step is captured only from a new
   measured baseline.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Step `19.6` confirmed the residual runtime baseline as:
  - `28` `HIGH+` entries across the step-19 runtime-stack family
  - `5` runtime-related clone clusters in `lib`
- The measured residual runtime clone clusters still touch:
  - `lib/src/controller/mutation_executor.dart`
  - `lib/src/controller/scene_controller.dart`
  - `lib/src/controller/txn_context.dart`
  - `lib/src/interactive/internal/interactive_event_dispatcher.dart`
  - `lib/src/interactive/internal/interactive_move_session.dart`
  - `lib/src/interactive/scene_controller_interactive.dart`
- Confirmed residual class or function hotspots inside that family include:
  - `SceneControllerCore`
  - `SceneWriter`
  - `MutationExecutor`
  - `TxnContext`
  - `txnCollectStoreInvariantViolations(...)`
  - `SceneControllerInteractive`
  - `InteractiveMoveSession`

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller lib/src/interactive --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core`
- MCP test runner: controller-root `*_test.dart`
- MCP test runner: `test/interactive`

### 6.3 Protected States, Data, or Structures

- Commit lifecycle and signal ordering guarantees.
- Selection normalization and mutation semantics.
- Pointer and active-gesture semantics.
- Dispose fail-fast behavior.

### 6.4 Allowed Semantic Change Zones

- Committed store payload ownership and invariant assertion surface.
- Mutation-pipeline ownership between writer and executor.
- Transaction derived-state ownership where it still leaks across owner
  boundaries.
- Pointer and move-session internals beneath the interactive facade.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `19.7` starts from the measured residual scope recorded by `19.6`.
- Slice 1 closes before mutation-pipeline or interactive residual cleanup.
- Final rebaseline is forbidden until all earlier corrective slices are closed
  and remeasured.

### 6.8 Prohibited

- Introducing metric-only wrappers, second caches, or sync glue.
- Moving duplicate bodies between files without reducing architectural
  duplication.
- Changing public behavior to satisfy tooling.
- Pulling render/view or boundary-matrix scope into this corrective runtime
  step.

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

### Slice 1. [x] Committed store payload owns invariant and apply state

#### Slice Contract

One committed-store payload owner exists for controller commit apply and
invariant assertion so the runtime commit path no longer passes the same store
state through wide parameter lists across owners.

#### Change

Introduce one controller-owned committed-store payload type, move the
invariant/assert/apply path onto it, and remove the replaced wide-signature
commit plumbing from `scene_controller.dart` and `scene_invariants.dart`.

#### Verification

- `dcm calculate-metrics lib/src/controller/scene_controller.dart lib/src/controller/scene_invariants.dart lib/src/controller/committed_store_state.dart --report-all`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/controller/core`
- MCP test runner: controller-root `*_test.dart`

#### Closure Evidence

- Introduced `CommittedStoreState` as the single committed-store payload owner
  for invariant assertion and store apply in the controller commit path.
- Removed the replaced wide committed-store parameter plumbing from
  `scene_controller.dart` and `scene_invariants.dart`.
- Targeted metrics after the slice show `scene_invariants.dart` has no `HIGH+`
  entries and the committed-store helper file is fully below thresholds.
- Apples-to-apples residual runtime `HIGH+` count improved from `28` after
  `19.6` to `23` across the same residual family.
- Runtime-related clone clusters remain at `5`; no clone regression was
  introduced by the slice.
- Verified by:
  - `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
  - `flutter analyze`
  - `dcm analyze .`
  - `dart run tool/check_import_boundaries.dart`
  - `dart run tool/check_public_api_surface.dart`
  - `dart run tool/check_guardrails.dart`
  - `dart run tool/check_invariant_coverage.dart`
  - MCP test runner:
    `test/controller/scene_invariants_test.dart`
    and
    `test/controller/scene_controller_randomized_txn_test.dart`

### Slice 2. [x] Mutation pipeline residual owners are consolidated

#### Slice Contract

Residual duplicated or mixed mutation ownership between `SceneWriter` and
`MutationExecutor` is consolidated without introducing new wrapper layers.

#### Change

Correct the remaining write-pipeline owner seams identified by the post-`19.6`
baseline and remove the replaced duplicate or split mutation bodies.

#### Verification

- `dcm calculate-metrics lib/src/controller/scene_writer.dart lib/src/controller/mutation_executor.dart lib/src/controller/txn_context.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `flutter analyze`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/controller/internal`
- MCP test runner: controller-root `*_test.dart`

#### Closure Evidence

- Consolidated the residual mutation pipeline into focused owners:
  `mutation_input_guards.dart`,
  `mutation_commit_preparer.dart`,
  `node_mutation_applier.dart`,
  and
  `scene_mutation_applier.dart`.
- `MutationExecutor` now acts as the typed dispatch owner only; it no longer
  mixes input guards, node mutation bodies, and commit-candidate assembly in
  one hotspot.
- No duplicate mutation bodies were moved into wrapper layers; the replaced
  logic was removed from `mutation_executor.dart`.
- Apples-to-apples residual runtime `HIGH+` count improved from `23` after
  slice 1 to `19`.
- Runtime-related clone clusters improved from `5` after `19.6` to `4`.
- Verified by:
  - `flutter analyze`
  - `dcm analyze .`
  - `dart run tool/check_import_boundaries.dart`
  - `dart run tool/check_guardrails.dart`
  - `dart run tool/check_invariant_coverage.dart`
  - MCP test runner: `test/controller/internal`

### Slice 3. [x] Interactive residual runtime owners are consolidated

#### Slice Contract

Residual interactive runtime hot spots are consolidated beneath the facade
without reintroducing a mixed controller body or view-scope drift.

#### Change

Correct the remaining residual owner seams in
`SceneControllerInteractive` and `InteractiveMoveSession` from the measured
post-`19.6` baseline.

#### Verification

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_move_session.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `flutter analyze`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/interactive`

#### Closure Evidence

- `InteractiveMoveSession` now owns pointer-phase orchestration only; preview
  state, hit-testing, selection coordination, gesture-local mutable state, and
  terminal commit semantics were split into dedicated focused owners.
- `SceneControllerInteractive` moved residual selection/move action semantics
  under `interactive_selection_actions.dart` without introducing a second
  facade or sync glue.
- `InteractiveGestureMachine` now stores one coherent active-gesture state
  object, removing the impossible half-active `dragStartSlop` state instead of
  testing around it.
- `scene_invariants.dart` also dropped the dead nullable revision-state branch
  left behind after `CommittedStoreState` made committed revision state
  mandatory.
- Apples-to-apples residual runtime `HIGH+` count improved from `19` after
  slice 2 to `17`.
- Runtime-related clone clusters improved from `4` after slice 2 to `2`.
- `interactive_move_session.dart`, `mutation_executor.dart`, and
  `scene_invariants.dart` now have no `HIGH+` entries.
- Verified by:
  - `flutter analyze`
  - `dcm analyze .`
  - `dart run tool/check_import_boundaries.dart`
  - `dart run tool/check_guardrails.dart`
  - `dart run tool/check_invariant_coverage.dart`
  - MCP test runner: `test/interactive`

### Slice 4. [x] Corrective runtime baseline is recaptured

#### Slice Contract

Residual runtime work is remeasured against the post-`19.6` baseline and the
roadmap records only what factually remains after corrective slices.

#### Change

Rebaseline the step-19 runtime family with the same instruments as `19.6` and
update the runtime roadmap only from measured residual data.

#### Verification

- `dcm calculate-metrics lib/src/controller lib/src/interactive --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `flutter analyze`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core`
- MCP test runner: controller-root `*_test.dart`
- MCP test runner: `test/interactive`

#### Closure Evidence

- Final residual runtime baseline for the step-19 family is `17` `HIGH+`
  entries, improved from `28` after `19.6`.
- Final runtime-related clone baseline is `2` clusters, improved from `5`
  after `19.6`.
- Parent step-19 baseline is now also improved from `25` `HIGH+` entries to
  `17`, so the runtime-stack step closes with a measured net architectural
  improvement.
- `SceneControllerInteractive` remains the largest residual runtime owner, but
  the remaining scope is below the step-19 closure threshold and is no longer
  blocked by mixed mutation, invariant, or move-session ownership.
- Repository-required final verification is green:
  - `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
  - `flutter analyze`
  - `(cd example && flutter analyze lib test)`
  - `dcm analyze .`
  - `dart run tool/check_import_boundaries.dart`
  - `dart run tool/check_public_api_surface.dart`
  - `dart run tool/check_guardrails.dart`
  - `dart run tool/check_invariant_coverage.dart`
  - MCP test runner: `test/core`
  - MCP test runner:
    `test/model test/serialization test/contract test/public_api test/entrypoints`
  - MCP test runner: `test/controller/internal`
  - MCP test runner:
    `test/controller/core test/controller/commands`
    plus
    controller-root
    `scene_snapshot_invariant_assertions_test.dart`,
    `scene_invariants_test.dart`,
    and
    `scene_controller_randomized_txn_test.dart`
  - MCP test runner: `test/render test/view`
  - MCP test runner: `test/interactive`
  - MCP test runner: `example/test` with root `example/`
  - `flutter test --coverage --no-pub --exclude-tags=tool`
  - `dart run tool/check_coverage.dart`

## 9. Final Verification

- `dcm calculate-metrics lib/src/controller lib/src/interactive --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/core`
- MCP test runner: `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core test/controller/commands`
- MCP test runner:
  `test/controller/scene_snapshot_invariant_assertions_test.dart`
  `test/controller/scene_invariants_test.dart`
  `test/controller/scene_controller_randomized_txn_test.dart`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test` with root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
