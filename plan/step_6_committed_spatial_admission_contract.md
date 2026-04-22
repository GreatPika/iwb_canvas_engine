## 1. Change Mandate

Ensure committed spatial invalidation tracks the full coarse spatial admission
footprint used by hit-test and paint so committed paint queries cannot keep
stale paint bounds after a combined node patch that changes geometry and
`hitPadding`, while transform paths also converge on the same shared
owner-side admission helper.

## 2. Change Boundary

### Included in the Change

- Align committed dirty-tracking with both coarse hit-test admission and coarse
  paint admission for node patch and transform mutation paths.
- Reuse one shared internal geometry helper for the committed spatial footprint
  that those owners compare and store.
- Keep committed paint read-side behavior unchanged while making the owner-side
  admission contract mechanically provable with tests and an invariant entry.

### Not Included in the Change

- Any render-path recompute of committed paint bounds.
- Any `SceneStoreController` facade expansion, commit-runtime restructuring, or
  broader spatial-index redesign.
- Any rename sweep of `ChangeSet.boundsChanged` or
  `ChangeSet.spatialGeometryChangedIds`.
- Any change to stale locator rejection, background inclusion policy, preview
  paint fallback, or public API surface.

## 3. Surrounding Code Review

### Inspected Artifacts

- `lib/src/controller/node_mutation_applier.dart` — patch/transform mutations
  currently compare only `nodeHitTestCandidateBoundsWorld(...)` before calling
  `trackUpdatedNodeGeometry(...)`.
- `lib/src/controller/change_set.dart` — `boundsChanged` is documented as a
  hit-candidate signal and `spatialGeometryChangedIds` is the only incremental
  spatial-delta carrier.
- `lib/src/controller/internal/spatial_index_cache.dart` — commit-time cache
  updates rely on `boundsChanged` and `spatialGeometryChangedIds`; `visualChanged`
  is intentionally ignored for spatial updates.
- `lib/src/core/node_geometry.dart` — coarse hit-test admission and paint bounds
  are derived by separate helpers from the same node geometry.
- `lib/src/core/hit_test.dart` — hit-test candidate bounds already delegate to
  the geometry helper rather than owning separate formulas.
- `lib/src/core/scene_spatial_index.dart` — the committed spatial index stores
  hit-test and paint entries separately and upserts both roles for a node from
  one owner path.
- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart` —
  ordinary committed paint staging trusts committed
  `candidate.paintBoundsWorld` and only revalidates the locator.
- `lib/src/render/scene_painter_node_renderer.dart` — committed culling happens
  against `candidate.paintBoundsWorld` before node render resolution.
- `test/core/scene_spatial_index_test.dart` — existing proof already locks that
  committed hit-test and paint candidates come from shared runtime geometry
  helpers while keeping their policies distinct.
- `test/controller/core/scene_controller_spatial_index_test.dart` — existing
  integration proof locks incremental spatial updates for transforms and
  `hitPadding` changes but not the paint-changed/hit-stable case.
- `test/controller/internal/spatial_index_cache_test.dart` — existing cache
  proof locks rebuild/incremental behavior and invalid-index recovery.
- `test/render/scene_painter_bounds_contract_test.dart` — existing structural
  proof locks the committed paint stage and painter to `candidate.paintBoundsWorld`
  instead of snapshot recompute.
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
  — stale locator and stale background candidate rejection are already covered
  and do not need to move in this step.
- `ARCHITECTURE.md` — the committed store remains the committed read boundary
  while the commit runtime owns write orchestration and spatial-index cache
  ownership.
- `docs/adr/0001_target_engine_architecture.md` — committed indexes stay with
  the committed store/write-kernel family; render remains a consumer seam.
- `docs/adr/0002_post_target_optimization_scope.md` — `SceneStoreController`
  should not absorb more helper ownership; the coherent write kernel is the
  right owner family for spatial cache coordination.
- `tool/invariant_registry.dart` — existing invariants already protect the thin
  controller facade, committed-read seam, painter frame contract, and spatial
  rebuild-on-invalid behavior.

### Current Entry Path

- `PatchNodeOp` / `SetNodeTransformOp`
- `lib/src/controller/node_mutation_applier.dart`
- `ChangeSet.boundsChanged` / `ChangeSet.spatialGeometryChangedIds`
- `lib/src/controller/scene_controller_commit_plan.dart`
- `lib/src/controller/internal/spatial_index_cache.dart`
- `SceneStoreController.queryPaintCandidates(...)`
- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart`
- `lib/src/render/scene_painter_node_renderer.dart`

### Current Owner

- The defect originates in committed write-side dirty-tracking:
  `node_mutation_applier.dart` decides whether a node mutation is spatial,
  while `scene_spatial_index.dart` owns the committed hit-test and paint
  entries consumed later by committed paint reads.

### Adjacent Abstractions

- `lib/src/controller/internal/spatial_index_cache.dart` — chooses no-op,
  incremental apply, or rebuild based on `ChangeSet`.
- `lib/src/controller/scene_controller_commit_plan.dart` — derives
  `boundsRevision` from `ChangeSet.boundsChanged`.
- `lib/src/core/hit_test.dart` — exposes the existing public-facing hit-test
  candidate helper built on top of geometry policy.
- `lib/src/core/scene_snapshot_paint_candidates.dart` — snapshot fallback owner
  for preview/local paint enumeration, not the committed-path owner.

### Existing Tests

- `test/core/scene_spatial_index_test.dart` — locks shared runtime geometry
  sourcing for committed hit-test and paint candidates.
- `test/controller/core/scene_controller_spatial_index_test.dart` — locks
  incremental committed spatial updates for transforms and `hitPadding`.
- `test/controller/internal/spatial_index_cache_test.dart` — locks cache
  invalidation, incremental apply, and rebuild fallback behavior.
- `test/render/scene_painter_bounds_contract_test.dart` — locks ordinary
  committed paint staging to committed candidate bounds.
- `test/controller/core/scene_controller_commit_runtime_contract_test.dart` —
  locks `SceneStoreController` as a thin facade over the commit runtime.
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
  — locks stale committed candidate rejection so this step does not need to
  change that seam.

### Analogous Implementation Path

- `lib/src/core/scene_spatial_index.dart` — `_upsertNodeById(...)` already
  treats hit-test and paint entries as one node-owned refresh operation, which
  is the closest valid precedent for keeping both coarse admission roles aligned
  from one owner.

### Governing Repository Rules

- `AGENTS.md` — fix bugs at the owning layer, avoid sync glue, reuse existing
  abstractions, and prefer repository-local enforcement for stable constraints.
- `ARCHITECTURE.md` — `SceneStoreController` stays the committed store boundary
  while `SceneControllerCommitRuntime` owns write orchestration and spatial-index
  cache ownership.
- `tool/invariant_registry.dart` /
  `INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY` — the public controller facade
  must stay thin and must not re-own commit helpers.
- `tool/invariant_registry.dart` /
  `INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE` — committed store reads must
  not grow into full render-state ownership.
- `tool/invariant_registry.dart` /
  `INV-ENG-SPATIAL-INDEX-REBUILD-ON-INVALID` — invalid spatial index state must
  transition into rebuild-required behavior.
- `tool/invariant_registry.dart` /
  `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION` — committed paint staging and frame
  resolution stay consumer-only and depend on committed candidate bounds.

### Rejected Misleading Local Patterns

- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart` —
  recomputing paint bounds here would patch a downstream consumer instead of
  repairing the committed owner contract.
- `lib/src/render/scene_painter_node_renderer.dart` — painter-side fallback
  culling changes would hide stale committed data rather than prevent it.
- `lib/src/controller/scene_store_controller.dart` — adding helper ownership to
  the public facade conflicts with the committed-runtime boundary already locked
  by architecture and invariants.
- `lib/src/controller/internal/spatial_index_cache.dart` — broad invalidation on
  `visualChanged` or unconditional rebuilds would abandon correct owner-side
  detection and erase useful incrementality.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- The problem belongs to the committed write-kernel spatial invalidation
  contract, not to render-stage candidate consumption.

#### Selected Architectural Form

- Add one shared internal coarse spatial admission helper in
  `lib/src/core/node_geometry.dart` for `SceneNode` that returns both the
  committed hit-test admission bounds and the committed paint bounds, then make
  both `node_mutation_applier.dart` and `scene_spatial_index.dart` consume that
  helper.

#### Owning Layer or Module

- `lib/src/core/node_geometry.dart` owns the coarse spatial footprint formula.
- `lib/src/controller/node_mutation_applier.dart` remains the owner that decides
  whether a node mutation produced a spatial change.

#### Dependency Direction

- `controller` depends on the shared `core` geometry helper for admission
  comparison.
- `scene_spatial_index.dart` depends on the same helper for stored hit/paint
  entry values.
- `SpatialIndexCache`, `SceneStoreController`, stage, and painter remain
  downstream consumers of the resulting committed state.

#### State and Data Ownership

- `ChangeSet` remains the single committed dirty-signal carrier for spatial
  changes.
- `SceneSpatialIndex` remains the only committed store of coarse hit-test and
  paint candidate bounds.
- No duplicate admission cache, per-role dirty-set split, or sync bridge is
  introduced.

#### Entry and Exit Boundaries

- Entry: node patch and node transform mutation application before commit-plan
  derivation.
- Exit: `ChangeSet.boundsChanged` plus
  `ChangeSet.spatialGeometryChangedIds` drive `SpatialIndexCache` incremental
  refresh so committed `queryPaintCandidates(...)` returns current paint bounds.

#### Permitted Extension Seam

- This step may extend only the existing geometry helper seam in
  `node_geometry.dart`.
- If a future committed spatial role is added, it must extend this shared
  helper first instead of adding new role-specific dirty tracking elsewhere.

#### Rejected Alternatives

- Recompute committed paint bounds in stage or painter — wrong owner, masks stale
  committed state, and violates the committed-read consumer seam.
- Invalidate spatial state on every `visualChanged` or ordinary controller epoch
  churn — corrects the symptom by brute force and discards incremental behavior.
- Keep the composite footprint helper private inside
  `node_mutation_applier.dart` — duplicates geometry semantics in the controller
  instead of consolidating them at the geometry owner.
- Introduce a new spatial-admission subsystem/file or extend
  `SceneStoreController` — adds new abstraction or facade ownership that the ADR
  trajectory does not need.

#### Why This Level Is Correct

- The bug exists because the write owner decides “spatial change” using a
  narrower formula than the committed spatial index stores and exposes. Sharing
  one coarse admission formula between those two owners fixes the root cause
  once without changing downstream consumers.

## 5. Locked Decisions

1. Add one internal record-style helper in `lib/src/core/node_geometry.dart`
   that returns the coarse committed hit-test admission bounds and coarse
   committed paint bounds for a `SceneNode`.
2. Update `trackUpdatedNodeGeometry(...)` and `txnApplyNodeTransform(...)` in
   `lib/src/controller/node_mutation_applier.dart` to compare the full coarse
   admission record instead of only `nodeHitTestCandidateBoundsWorld(...)`.
3. Update `lib/src/core/scene_spatial_index.dart` to source stored hit-test and
   paint bounds from the same shared helper so build and incremental upsert stay
   formula-aligned with mutation dirty-tracking.
4. Keep `ChangeSet.boundsChanged` and `ChangeSet.spatialGeometryChangedIds`
   names in this step; only update comments and semantics where they currently
   claim “hit candidate bounds” specifically.
5. Keep `SpatialIndexCache` decision logic and `SceneStoreController` public
   surface unchanged; the fix must come entirely from improved owner-side
   spatial detection and shared geometry semantics.
6. Add one repository-local invariant and one dedicated structural test file so
   future drift back to hit-only dirty-tracking becomes mechanically visible.

## 6. Result Requirements

1. A combined node patch that changes committed paint admission while keeping
   committed hit-test admission unchanged must still mark a spatial change and
   refresh committed paint queries.
2. The fix must preserve the ordinary committed fast path: the stage continues
   to trust `candidate.paintBoundsWorld`, and the painter continues to cull from
   that committed value without recompute.
3. Non-spatial visual changes remain spatial no-ops; this step must not turn
   `visualChanged` into a spatial invalidation trigger.
4. The same owner-side admission contract must hold for both foreground content
   nodes and background paint candidates when committed paint queries include
   `backgroundAndContentLayers`.
5. Committed spatial refresh for the reproduced case remains incremental rather
   than forcing a rebuild or controller-facade workaround.
6. Public controller, render, and committed spatial candidate APIs remain
   unchanged.

## 7. Execution Order and Gates

### Required Order

- Slice 1 must add the failing reproducer and neighboring guards before any
  owner-side implementation edit.
- Slice 2 may change `node_geometry.dart`, `node_mutation_applier.dart`, and
  `scene_spatial_index.dart` only after the reproducer is in place.
- Slice 3 may register the new invariant and final semantic comments only after
  Slice 2 has the behavioral tests green.

### Successor Seam and Retirement Gates

- None — this step tightens an existing owner contract in place and does not
  introduce a replacement facade, replacement runtime seam, or shared helper
  retirement gate.

### Deferred Broad Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
  — reserve for the final gate after all slices land.

## 8. File Map

### Implementation Files

- `lib/src/core/node_geometry.dart`
- `lib/src/controller/node_mutation_applier.dart`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/controller/change_set.dart`

### Test Files

- `test/controller/internal/node_mutation_spatial_admission_contract_test.dart`
- `test/controller/core/scene_controller_spatial_index_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`

### Registry, Inventory, and Workflow Files

- `tool/invariant_registry.dart`
- `PLAN.md`
- `plan/step_6_committed_spatial_admission_contract.md`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY`
- `INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE`
- `INV-ENG-SPATIAL-INDEX-REBUILD-ON-INVALID`
- `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION`
- `INV-ENG-COMMITTED-SPATIAL-ADMISSION-ALIGNMENT` (new in this step)

### Required Proof

- behavioral proof:
  - one failing reproducer first for a combined node change that updates paint
    admission while preserving hit-test admission;
  - 1 to 3 guard tests for neighboring branches of the same contract at the
    mutation-owner, cache, and controller integration levels, including one
    direct visual-only negative guard and one committed background-path guard.
- structural proof:
  - a dedicated contract test must make it mechanically visible that
    `node_mutation_applier.dart` and `scene_spatial_index.dart` both reference
    the shared coarse admission helper rather than comparing or storing a
    hit-only formula in mutation paths;
  - the existing committed paint contract must stay green so the downstream
    stage remains consumer-only.
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract.

### Allowed Change Surface

- Only the implementation, test, and registry files listed in section 8.
- Internal-only helper additions and comment updates required to express the
  shared coarse admission contract.

### Forbidden Moves

- Add new public controller APIs, new `SceneStoreController` helper ownership,
  or new render/runtime callback seams.
- Recompute committed paint bounds in stage, painter, or snapshot fallback code.
- Convert ordinary `visualChanged` mutations into spatial invalidation.
- Add per-role dirty sets or a new spatial-admission subsystem in this step.
- Rename `ChangeSet` fields across the repository as part of this fix.

### Optional: Allowed Forms That Are Not Violations

- The shared helper may use an internal record typedef or equivalent internal
  top-level shape in `lib/src/core/node_geometry.dart`.
- `scene_spatial_index.dart` may keep distinct hit-test and paint entry classes
  while sourcing both rectangles from the shared helper.
- `ChangeSet` comments may generalize from “hit candidate bounds” to
  “coarse spatial admission” without renaming the fields.

### Optional: Resolution Rules

- If implementation only needs a `SceneNode` helper to close this step, do not
  add a snapshot composite helper.
- If an added proof can reuse an existing test file without mixing concerns,
  reuse it; otherwise create the dedicated contract test named in section 8.

## 10. Vertical Slices

### Slice 1. [ ] Lock the stale committed paint reproducer

#### Slice Contract

Make the current defect mechanically visible before changing owner-side
implementation.

#### Change

- Add `test/controller/internal/node_mutation_spatial_admission_contract_test.dart`
  with a failing low-level reproducer that exercises a node mutation where
  `paintBoundsWorld` changes but the coarse hit-test admission stays unchanged,
  and assert that the mutation must still count as a spatial change.
- Add a low-level negative guard in the same test file for a visual-only node
  patch that leaves the full coarse spatial footprint unchanged and must keep
  `boundsChanged == false`, `spatialGeometryChangedIds` empty, and
  `visualChanged == true`.
- Extend `test/controller/core/scene_controller_spatial_index_test.dart` with a
  failing controller-level reproducer that proves committed
  `queryPaintCandidates(...)` must expose the new visible edge without forcing a
  rebuild.
- Add a committed background-path guard in
  `test/controller/core/scene_controller_spatial_index_test.dart` that proves
  the same stale-paint class is closed when the query scope is
  `ScenePaintSpatialQueryScope.backgroundAndContentLayers`.
- Extend `test/controller/internal/spatial_index_cache_test.dart` with
  neighboring guards that keep non-spatial visual changes as spatial no-ops and
  keep the reproduced spatial case incremental.

#### Behavioral Verification

- `flutter test test/controller/internal/node_mutation_spatial_admission_contract_test.dart`
  — expected to fail before Slice 2.
- `flutter test test/controller/core/scene_controller_spatial_index_test.dart`
  — expected to fail on the new reproduced case before Slice 2.
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
  — expected to fail on the new reproduced case before Slice 2.

#### Structural Verification

- `flutter test test/render/scene_painter_bounds_contract_test.dart`
  — must stay green to keep the committed paint consumer seam locked while the
  reproducer is added.

#### Positive Scenarios

- Combined node change widens paint admission but preserves hit-test admission.
- The same committed stale-paint class is closed for a background node returned
  through `backgroundAndContentLayers`.
- The same commit still uses the incremental spatial path once the owner fix
  exists.

#### Negative Scenarios

- Grid-only or selection-only commits remain outside the spatial invalidation
  contract.
- Visual-only node changes that preserve the full coarse spatial footprint keep
  spatial dirty flags clear while still marking `visualChanged`.
- Existing stale locator rejection behavior remains owned by its current tests
  and is not changed here.

#### Closure Evidence

- The new reproducer and guards fail against the current bug, while the
  unchanged committed paint consumer contract remains green.

### Slice 2. [ ] Align owner-side spatial admission semantics

#### Slice Contract

One shared coarse spatial admission formula drives both committed dirty-tracking
and committed spatial-index storage.

#### Change

- Add the shared coarse spatial admission helper in
  `lib/src/core/node_geometry.dart`.
- Update `lib/src/controller/node_mutation_applier.dart` to compare that helper
  for patch and transform mutation paths before deciding whether to mark
  `boundsChanged` and `spatialGeometryChangedIds`.
- Update `lib/src/core/scene_spatial_index.dart` to source committed stored
  hit-test and paint bounds from that helper.
- Update the misleading `ChangeSet.boundsChanged` comment in
  `lib/src/controller/change_set.dart` to describe coarse spatial admission.

#### Behavioral Verification

- `flutter test test/controller/internal/node_mutation_spatial_admission_contract_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_index_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/core/scene_spatial_index_test.dart`

#### Structural Verification

- `test/controller/internal/node_mutation_spatial_admission_contract_test.dart`
  must assert that mutation-owner logic and committed spatial-index logic both
  reference the shared helper instead of a hit-only comparison in node mutation
  paths.
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
  must stay green so ordinary committed paint staging still consumes
  `candidate.paintBoundsWorld` without recompute.

#### Positive Scenarios

- Node patch changes paint admission while a simultaneous `hitPadding` change
  preserves the committed hit-test admission footprint.
- Node transform still routes through the same shared owner-side helper even
  though the reproduced stale-paint branch is patch-specific in the current
  geometry model.
- Background paint candidate refresh stays aligned with the same owner-side
  admission contract.
- Ordinary committed paint staging continues to trust committed candidate bounds.

#### Negative Scenarios

- Visual-only mutations that do not change the coarse spatial footprint remain
  spatial no-ops.
- The owner-side negative guard proves the fix does not widen spatial dirty
  tracking beyond the full coarse admission footprint.
- No `SceneStoreController` or `SpatialIndexCache` surface growth is introduced.

#### Closure Evidence

- All Slice 1 reproducers turn green, and the reproduced case stays incremental
  in controller/cache debug assertions.

### Slice 3. [ ] Register the spatial admission alignment invariant

#### Slice Contract

The repository records and enforces the new owner-side spatial admission
alignment contract so later drift becomes mechanically visible.

#### Change

- Add `INV-ENG-COMMITTED-SPATIAL-ADMISSION-ALIGNMENT` to
  `tool/invariant_registry.dart`.
- Register these exact invariant proofs:
  - `RequiredProof(path: 'test/controller/internal/node_mutation_spatial_admission_contract_test.dart', stepId: 'scope_controller_internal')`
  - `RequiredProof(path: 'test/controller/core/scene_controller_spatial_index_test.dart', stepId: 'scope_controller')`
- Mark those same proof surfaces with the matching `// INV:` marker.

#### Behavioral Verification

- `flutter test test/controller/internal/node_mutation_spatial_admission_contract_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_index_test.dart`

#### Structural Verification

- `dart run tool/check_invariant_coverage.dart`
- The new invariant entry must point only to executable proof surfaces and
  existing verification step ids already reachable from `required_code_change`.
- `tool/check_invariant_coverage.dart` must accept the new invariant without
  requiring any new verification scope or preset wiring.

#### Positive Scenarios

- Future owner-side drift to hit-only mutation invalidation breaks an
  invariant-declared proof surface.

#### Negative Scenarios

- Existing facade, painter, and stale-candidate invariants remain unchanged and
  do not need to move ownership for this step.

#### Closure Evidence

- The invariant registry, proof markers, and executable proof surfaces describe
  the same owner-side contract without adding a new facade or consumer seam.

## 11. Final Verification

- `flutter test test/controller/internal/node_mutation_spatial_admission_contract_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_index_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/core/scene_spatial_index_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
  with these repository-relative paths:
  - `PLAN.md`
  - `plan/step_6_committed_spatial_admission_contract.md`
  - `lib/src/core/node_geometry.dart`
  - `lib/src/controller/node_mutation_applier.dart`
  - `lib/src/core/scene_spatial_index.dart`
  - `lib/src/controller/change_set.dart`
  - `test/controller/internal/node_mutation_spatial_admission_contract_test.dart`
  - `test/controller/core/scene_controller_spatial_index_test.dart`
  - `test/controller/internal/spatial_index_cache_test.dart`
  - `tool/invariant_registry.dart`

## 12. Acceptance Criteria

- A combined committed node patch can no longer leave stale `paintBoundsWorld`
  in committed paint queries when the coarse hit-test admission happens to stay
  unchanged.
- The same guarantee holds for background paint candidates when committed
  queries include `backgroundAndContentLayers`.
- The reproduced fix path stays incremental and does not fall back to broad
  invalidation or render-path recompute.
- Visual-only node changes that preserve the full coarse spatial footprint do
  not start marking spatial dirty state.
- Transform mutation paths consume the same shared owner-side admission helper
  instead of keeping a parallel direct formula.
- Ordinary committed paint staging and painter culling remain consumer-only and
  continue to read committed candidate bounds without recomputing them.
- `SceneStoreController`, `SpatialIndexCache`, and public committed spatial
  payload surfaces do not grow new responsibilities.
- The repository contains an invariant-declared proof surface that will fail if
  owner-side spatial dirty-tracking drifts away from the shared committed
  admission helper again.
