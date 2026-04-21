language: english

# Change Contract

## 1. Change Mandate

This change fixes committed selection invalidation ownership so
`selectionRevision` is derived from the final committed selection membership at
the controller commit boundary instead of trusting `ChangeSet.selectionChanged`
as the sole source of truth.

## 2. Change Boundary

### Included in the Change

- Controller commit-boundary derivation of committed selection membership
  change.
- Controller invariant coverage that makes selection-membership bookkeeping
  drift fail mechanically.
- Behavioral and structural tests that pin the new ownership rule.

### Not Included in the Change

- Removal of `selectionRevision` from committed controller state,
  `SceneViewFrameRead`, or committed paint-path consumers.
- Cache-key redesign for selected-order invalidation.
- Public package-surface additions, removals, or renames.
- Benchmark, workflow, or performance-policy changes.

## 3. Surrounding Code Review

### Inspected Artifacts

- `lib/src/controller/scene_controller_commit_plan.dart` — current owner that
  derives `committedSelection` and bumps `selectionRevision`, today gated only
  by `changeSet.selectionChanged`.
- `lib/src/controller/change_set.dart` — carries `selectionChanged` as a
  transaction-local bookkeeping flag rather than final committed truth.
- `lib/src/controller/selection_state_mutation_applier.dart` — primary owner
  for explicit selection mutations that mark `selectionChanged`.
- `lib/src/controller/selection_post_apply_finalizer.dart` — secondary owner
  that can normalize selection membership after structural/node writes and also
  marks `selectionChanged`.
- `lib/src/controller/mutation_commit_preparer.dart` — exposes the final
  transaction `selection` as `commitCandidate.selection`.
- `lib/src/controller/committed_store_state.dart` — commit snapshot carrier
  that already owns committed `selectedNodeIds` and `selectionRevision`.
- `lib/src/controller/scene_controller_commit_execution.dart` — single apply
  path that writes the committed selection state into `SceneStore`.
- `lib/src/controller/scene_invariants.dart` — existing invariant layer for
  committed store state and critical commit checks.
- `lib/src/contract/scene_view_render_state.dart` — internal carrier boundary
  where `SceneViewFrameRead` already transports `selectionRevision`.
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` —
  committed render entrypoint that atomically captures `selectionRevision` and
  must remain unchanged by this follow-up.
- `lib/src/interactive/internal/scene_controller_selected_paint_order_cache.dart`
  — committed selected-order cache keyed by `(selectionRevision,
  structuralRevision)`.
- `test/controller/core/scene_controller_commit_atomicity_test.dart` —
  behavioral coverage for selection membership identity and revision behavior.
- `test/controller/scene_invariants_test.dart` — existing invariant coverage
  seam for committed store assertions.
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` —
  structural coverage that already pins the render-side `selectionRevision`
  carrier path.

### Current Entry Path

- `SceneStoreController.write*` creates one `TxnContext`.
- Selection mutations and post-apply finalization mutate `ctx.workingSelection`
  and may mark `ctx.changeSet.selectionChanged`.
- `prepareMutationPreparedCommitResult(...)` produces `commitCandidate.selection`.
- `buildControllerCommitPlan(...)` derives committed selection and revision
  state.
- `executeControllerCommitPlan(...)` commits that state into `SceneStore`.

### Current Owner

- Final committed selection state ownership lives in `lib/src/controller/**`,
  specifically the commit planning boundary.

### Adjacent Abstractions

- `ChangeSet` — transaction-local change bookkeeping.
- `TxnContext.workingSelection` — mutable transaction selection workspace.
- `SceneControllerSelectedPaintOrderCache` — read-side consumer of committed
  invalidation keys.
- `SceneViewFrameRead` — atomic render-side carrier for committed selection
  invalidation.

### Existing Tests

- `test/controller/core/scene_controller_commit_atomicity_test.dart` — proves
  selection view identity stability and current `selectionRevision` behavior.
- `test/controller/scene_invariants_test.dart` — proves committed invariant
  failures throw at the controller boundary.
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` —
  proves committed render state captures `selectionRevision` once and does not
  read it live later.

### Analogous Implementation Path

- `lib/src/controller/scene_controller_commit_execution.dart` plus
  `lib/src/controller/scene_invariants.dart` — the repository already resolves
  final committed truth in the controller commit path and validates it through
  committed store invariants instead of trusting earlier transaction-local
  heuristics.

### Governing Repository Rules

- `ARCHITECTURE.md` — committed selected-node supplement order is cached only
  by committed `(selectionRevision, structuralRevision)`, with
  `selectionRevision` remaining controller-owned and atomically captured into
  `SceneViewFrameRead`.
- `plan/step_115_seal_controller_owned_paint_candidate_staging_and_perf_contract.md`
  — step 115 explicitly locked `selectionRevision` as the committed read-side
  invalidation carrier and forbids live post-capture reads.
- `AGENTS.md` verification section — any code change must run the required
  verification preset.

### Rejected Misleading Local Patterns

- `selection_state_mutation_applier.dart` as the final owner — wrong level
  because it sees only explicit selection operations, not post-apply
  normalization or final commit state.
- `selection_post_apply_finalizer.dart` as the final owner — wrong level
  because it sees only one normalization path, not the full commit decision.
- Render-side token or cache rewrites — wrong seam because the defect source is
  controller-side bookkeeping ownership, not read-side consumption.
- Full removal of `selectionRevision` — wrong scope for this follow-up because
  it reopens the step 115 read-side architecture instead of fixing the owning
  controller boundary.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Controller commit-boundary invariant and committed-state derivation.

#### Selected Architectural Form

- `buildControllerCommitPlan(...)` computes one final
  `selectionMembershipChanged` fact by comparing the previous committed
  selection with `commitCandidate.selection`.
- That final fact, not `changeSet.selectionChanged` alone, owns:
  - whether the committed store state reuses the previous selection owner or
    adopts the candidate selection;
  - whether `selectionRevision` increments.
- `changeSet.selectionChanged` remains transaction-local bookkeeping for
  commit phases and debug reporting, but it no longer has sole authority over
  committed selection invalidation.
- Controller invariants verify that committed selection membership and
  `selectionRevision` stay aligned.

#### Owning Layer or Module

- `lib/src/controller/**`, centered on
  `scene_controller_commit_plan.dart` and `scene_invariants.dart`.

#### Dependency Direction

- `selection mutation/finalization -> commit candidate -> commit plan ->
  committed store state -> render/read-side consumers`.
- Reverse ownership is forbidden: render/read-side modules must not infer or
  repair selection invalidation on behalf of the controller layer.

#### State and Data Ownership

- `TxnContext.workingSelection` owns transaction-local mutable membership.
- `commitCandidate.selection` owns the final transaction result before commit.
- `SceneStore.selectedNodeIds` and `selectionRevision` own committed
  controller truth after commit.

#### Entry and Exit Boundaries

- Selection membership enters this form as `store.selectedNodeIds` and
  `commitCandidate.selection` inside `buildControllerCommitPlan(...)`.
- The committed result exits this form as `CommittedStoreState.selectedNodeIds`
  and `CommittedStoreState.selectionRevision`.
- Render-side consumers continue to observe only the committed result through
  `SceneStoreController.selectionRevision` and `SceneViewFrameRead`.

#### Permitted Extension Seam

- `lib/src/controller/scene_controller_commit_plan.dart` is the only permitted
  owner for final committed selection-membership diff derivation.
- `lib/src/controller/scene_invariants.dart` is the only permitted owner for
  mechanical enforcement of committed selection/revision alignment.

#### Rejected Alternatives

- Rely on `ChangeSet.selectionChanged` alone — rejected because it is a
  transaction-local flag set from multiple paths and can drift from final
  committed truth.
- Rework render-side cache keys or remove `selectionRevision` — rejected
  because the defect source is controller-side ownership, and the read-side
  contract from step 115 is already locked.

#### Why This Level Is Correct

- The final committed selection and the final committed revision are both
  decided once in the controller commit plan. Fixing the ownership there
  removes the silent-drift risk at its source without duplicating policy in
  mutation helpers or read-side consumers.

## 5. File Map

### Implementation Files

- `lib/src/controller/scene_controller_commit_plan.dart`
- `lib/src/controller/scene_invariants.dart`

### Test Files

- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/scene_invariants_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`

### Fixtures and Supporting Data

- None.

### Analysis Area

- `lib/src/controller/**`
- `lib/src/interactive/internal/**`
- `test/controller/**`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`

### File Rules

- Every modified implementation file must be tied to a specific slice.
- Every modified test must be tied to a listed verification.
- No new helper module is allowed unless the commit-plan file becomes less
  cohesive; prefer a local helper inside the existing owner first.

## 6. Locked Decisions

1. `selectionRevision` remains part of committed controller state and remains
   part of `SceneViewFrameRead`.
2. The final committed selection-membership diff is computed in
   `buildControllerCommitPlan(...)`, not in mutation appliers or render code.
3. `changeSet.selectionChanged` remains available for commit phases/debug, but
   it does not solely decide revision invalidation.
4. Structural verification must pin both:
   - render-side continued use of frame-captured `selectionRevision`;
   - commit-plan rejection of `changeSet.selectionChanged` as the sole
     `selectionRevision` gate.

## 7. Result Requirements

1. Committed selection membership changes increment `selectionRevision`
   exactly once, regardless of whether the membership change originated from an
   explicit selection operation or post-apply normalization.
2. Commits that do not change committed selection membership leave
   `selectionRevision` unchanged.
3. The committed render path continues to consume only frame-captured
   `selectionRevision` plus `structuralRevision`.
4. Drift between committed selection membership and committed
   `selectionRevision` becomes mechanically visible through repository tests.

## 8. Implementation Rules

### Analysis Scope

- Only controller commit ownership and its existing read-side consumer
  contract.

### Target Verification Units

- `buildControllerCommitPlan(...)`
- committed invariant collection/assertion
- committed render-state architecture boundary assertions

### Protected States, Data, or Structures

- `SceneStore.selectedNodeIds`
- `SceneStore.selectionRevision`
- `SceneViewFrameRead.selectionRevision`
- `SceneControllerSelectedPaintOrderCache` invalidation key shape

### Allowed Semantic Change Zones

- Final committed selection invalidation ownership.
- Controller invariant failure conditions for selection/revision drift.

### Structural Enforcement

- Extend `test/interactive/core/scene_controller_architecture_boundary_test.dart`
  so it mechanically proves:
  - `captureFrameRead()` still captures `_storeController.selectionRevision`;
  - committed paint preparation still consumes `frameRead.selectionRevision`;
  - `scene_controller_commit_plan.dart` no longer derives
    `selectionRevision` from `changeSet.selectionChanged` alone.

### Required Test Strategy

- Behavioral controller tests for membership-changing and membership-stable
  commits.
- Invariant tests for mismatched committed selection/revision state.
- Structural source assertions for commit-plan ownership and render-side
  carrier continuity.

### Prohibited

- Do not remove `selectionRevision` from store, committed state, or frame read.
- Do not move final diff ownership into mutation appliers.
- Do not add read-side fallback heuristics based on selected-set iteration or
  identity.
- Do not modify benchmark policy, workflow contracts, or public API docs in
  this follow-up.

## 9. Vertical Slices

### Slice 1. [x] Recompute committed selection invalidation at commit boundary

#### Slice Contract

`buildControllerCommitPlan(...)` derives committed selection reuse and
`selectionRevision` bumping from the final committed selection-membership diff
instead of trusting `changeSet.selectionChanged` alone.

#### Change

- Add one local committed-selection equality helper in
  `scene_controller_commit_plan.dart`.
- Compare `store.selectedNodeIds` with `commitCandidate.selection` before
  constructing `CommittedStoreState`.
- Use that exact comparison result to choose `committedSelection` ownership and
  to compute the next `selectionRevision`.
- Keep `resolveControllerCommitPhases(...)` and debug `changeSet` reporting
  unchanged unless they must consume the new local fact without widening
  ownership.

#### Behavioral Verification

- `test/controller/core/scene_controller_commit_atomicity_test.dart`
  scenario proving explicit selection mutation increments
  `selectionRevision` exactly once.
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
  scenario proving selection-preserving commits keep `selectionRevision`
  stable.
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
  scenario proving post-apply selection normalization also increments
  `selectionRevision` when committed membership changes.

#### Structural Verification

- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
  source assertion that `scene_controller_commit_plan.dart` no longer contains
  `store.selectionRevision + (changeSet.selectionChanged ? 1 : 0)` as the sole
  `selectionRevision` derivation rule.

#### Fixtures Used

- Existing controller test snapshots such as `twoRectSnapshot()`.

#### Positive Scenarios

- Replace/toggle/clear/select-all selection updates.
- Structural or patch writes that preserve final committed membership.
- Structural writes that trigger post-apply deselection of invalid ids.

#### Negative Scenarios

- No-op selection replace.
- Signals-only commit.
- Selection transform/translate commit that changes geometry but not
  membership.

### Slice 2. [x] Enforce committed selection/revision alignment mechanically

#### Slice Contract

Committed controller invariants and structural tests fail when final committed
selection membership and committed `selectionRevision` drift apart.

#### Change

- Extend `scene_invariants.dart` with one committed-state invariant that checks
  selection-membership/revision alignment when previous committed state and
  current committed state are both known.
- Wire that invariant through existing critical commit assertion paths without
  widening public/debug-only APIs.
- Add invariant tests in `test/controller/scene_invariants_test.dart`.
- Extend the existing architecture boundary test so it continues to pin
  frame-read capture and committed-stage consumption of `selectionRevision`.

#### Behavioral Verification

- `test/controller/scene_invariants_test.dart` scenario where membership
  changes without a revision bump fails.
- `test/controller/scene_invariants_test.dart` scenario where membership stays
  equal but the revision bumps fails, if the invariant is defined symmetrically.

#### Structural Verification

- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
  proves the committed render path still captures
  `_storeController.selectionRevision` exactly in `captureFrameRead()` and
  still consumes only `frameRead.selectionRevision` on the committed branch.

#### Fixtures Used

- Existing invariant-test committed-store-state builders.

#### Positive Scenarios

- Stable membership with stable revision passes.
- Changed membership with incremented revision passes.

#### Negative Scenarios

- Changed membership with stable revision fails.
- Stable membership with bumped revision fails, if supported by the chosen
  invariant form.

## 10. Final Verification

- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<file>`
  with all modified repository-relative paths listed.
- Confirm the updated controller tests are included in the preset-selected
  runs.
- Confirm the updated structural boundary test passes under the preset.

## 11. Acceptance Criteria

- The controller commit boundary, not `ChangeSet.selectionChanged` alone,
  decides committed selection invalidation.
- `selectionRevision` remains controller-owned and frame-captured exactly once.
- Mechanical tests fail when committed selection membership and
  `selectionRevision` drift apart.
- No public API, benchmark contract, or workflow contract changes are
  introduced.
