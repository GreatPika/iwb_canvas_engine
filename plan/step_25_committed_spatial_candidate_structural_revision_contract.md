language: english

# Change Contract

## 1. Change Mandate

Make committed spatial candidates reject stale structural handles by carrying
`structuralRevision` through the existing query/resolve pair and sealing that
contract in tests, guardrails, and architecture sources of truth.

## 2. Change Boundary

### Included in the Change

- reproduce the stale committed spatial candidate defect on the existing
  `SceneStoreController.resolveSpatialCandidateSnapshot(...)` owner surface for
  same-id reuse after `replaceScene`
- reproduce the same stale defect for same-id reuse after an ordinary
  structural committed write (`delete + insert` at the same location), because
  the current gap is broader than `replaceScene`
- add 1 to 3 neighboring guard tests around the same contract, including the
  background-layer branch and the already-supported non-structural reuse branch
- extend committed spatial candidate identity so
  `SceneSpatialCandidateReference`, `SceneHitTestSpatialCandidate`, and
  `ScenePaintSpatialCandidate` carry `structuralRevision`
- carry controller-owned `structuralRevision` through the existing committed
  spatial index path so rebuilt and incremental queries emit current candidate
  provenance without adding a new helper seam
- reject stale candidates in
  `SceneStoreController.resolveSpatialCandidateSnapshot(...)` before snapshot
  location lookup when the candidate revision no longer matches the committed
  store
- update all in-scope committed-read consumers that manually reconstruct
  `SceneSpatialCandidateReference` records from candidate fields
- update controller and interactive guardrails, sandbox fixtures, and invariant
  wording so repository-local enforcement seals the new structural-provenance
  candidate surface
- update `ARCHITECTURE.md` and add this step to `PLAN.md` so future work does
  not rely on chat-only knowledge about spatial candidate lifetime

### Not Included in the Change

- no public package API or export-surface change; the spatial candidate types
  remain internal-only
- no new committed read helper method, wrapper surface, or alternate resolver
  seam beside the existing `query*Candidates(...)` /
  `resolveSpatialCandidateSnapshot(...)` pair
- no change to `resolveSnapshotNodeById(...)`; it remains the current-locator
  API and does not become an external stale-handle validator
- no render-cache key redesign, no `controllerEpoch` invalidation redesign, and
  no broader revision-policy rewrite
- no change to mutation-side ownership, node id allocation policy, or
  `replaceScene` boundary sequencing beyond the minimum read-side proof needed
  to validate stale candidate rejection
- no attempt to make `instanceRevision`, `selectionRevision`, or
  `controllerEpoch` the committed spatial candidate provenance token
- no target-family reclassification or target-map evidence regeneration unless
  the checked-in architecture wording must change materially for this contract

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` - the active roadmap is closed through step 24, so this bug fix
  needs its own dedicated step contract instead of being folded into an already
  closed plan document
- `ARCHITECTURE.md` - the checked-in architecture already requires read-side
  helpers to return detached immutable values and reject stale handles, and it
  keeps `SceneStoreController` as the committed store boundary for committed
  queries and revision metadata
- `docs/target_architecture/families/store_and_commit_path.md` - the target
  family is `locked` and keeps committed read ownership on the store family
  rather than on interactive consumers or a new wrapper seam
- `docs/target_architecture/evidence/commit_move_selection_flow.md` and
  `docs/target_architecture/evidence/commit_move_selection_flow.json` - the
  checked-in evidence shows committed spatial query and candidate resolution
  flow through `SceneStoreControllerSpatialAccess.queryHitTestCandidates(...)`
  and `SceneStoreControllerSpatialAccess.resolveSpatialCandidateSnapshot(...)`
- `lib/src/core/scene_spatial_index.dart` - committed spatial payload owners
  currently expose only `nodeId`, `layerIndex`, `nodeIndex`, and bounds; the
  index already accepts controller-supplied companion data
  (`nodeLocator`, `layerIndexById`) when it is built and cloned
- `lib/src/controller/internal/spatial_index_cache.dart` - the cache already
  owns the committed spatial index lifecycle and already threads
  `controllerEpoch` through query/build/commit invalidation, but it does not
  currently carry `structuralRevision` into emitted candidates
- `lib/src/controller/scene_store_controller.dart` - the committed read-side
  boundary already exposes `structuralRevision`, emits committed spatial
  candidates, and resolves candidates only by current `nodeId` and location
- `lib/src/controller/scene_controller_commit_execution.dart` - the prepared
  spatial commit path currently passes only `controllerEpoch` into
  `SpatialIndexCache.writePrepareCommit(...)` before `_applyCommittedStore(...)`,
  so it is the current owner seam that must forward
  `committedStoreState.structuralRevision` if prepared cache rebuilds and
  incremental swaps are updated to carry structural provenance
- `lib/src/controller/scene_controller_commit_plan.dart` - structural commits
  already advance `structuralRevision`, while `controllerEpoch` advances only
  on document replacement or revision allocator epoch rollover
- `lib/src/controller/change_set.dart` - `txnMarkDocumentReplaced()` already
  marks `structuralChanged = true`, so `replaceScene` is inside the same
  structural contract as other location-changing writes
- `lib/src/interactive/internal/scene_controller_selected_paint_order_cache.dart`
  - the checked-in render-side precedent already uses `structuralRevision` as
  the cache invalidation token for node-order state that depends on structural
  layout
- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart`,
  `lib/src/interactive/internal/interactive_move_hit_test_engine.dart`, and
  `lib/src/interactive/internal/interactive_draw_eraser_targets.dart` - the
  current in-scope consumers rebuild `SceneSpatialCandidateReference` manually
  from candidate fields and therefore must forward any new provenance field
- `lib/src/render/scene_render_caches.dart` - render caches intentionally use
  `controllerEpoch` only for epoch/document boundaries, which is a checked-in
  precedent for why epoch is the wrong token for per-structural locator
  identity
- `lib/src/core/revision_policy.dart` and
  `lib/src/model/scene_node_boundary_mapping.dart` - imported snapshots preserve
  positive `instanceRevision`, so `instanceRevision` is not a reliable
  replacement for committed structural provenance
- `tool/invariant_registry.dart` - the current read-side invariant already
  seals committed query candidate shape and paired helper resolution, but does
  not yet say that stale candidates from an earlier structural revision must be
  rejected
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` - the
  controller API guardrail currently seals a three-field locator-only candidate
  payload surface and explicitly rejects extra fields such as
  `SceneHitTestSpatialCandidate.structuralRevision`
- `tool/src/guardrails/rules/interactive/interactive_committed_read_callback_guard_rules.dart`
  - the interactive callback guard currently hard-codes the exact
  `SceneSpatialCandidateReference` signature as
  `({int layerIndex, String nodeId, int nodeIndex})`
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
  - the existing proof already covers stale rejection for missing ids,
  out-of-range indices, and selection-only reuse, but does not cover same-id
  reuse at the same structural location
- `test/controller/internal/spatial_index_cache_test.dart` - the existing proof
  covers cache invalidation and incremental rebuild behavior, but does not lock
  the provenance value emitted on already-queried candidates after later
  structural commits
- `test/interactive/core/interactive_move_session_test.dart` and
  `test/interactive/core/interactive_draw_eraser_engine_test.dart` - the
  internal committed-read consumers already build or compare committed spatial
  candidates directly, so signature drift will surface there
- `test/render/scene_painter_frame_contract_test.dart` and
  `test/render/scene_painter_bounds_contract_test.dart` - render-stage fast-path
  proof already depends on controller-owned structural and selection revision
  carriage around committed candidate staging
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`,
  `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`,
  `test/tool/guardrails/interactive_api/committed_read_callbacks/callback_contract_cases.dart`,
  and `test/tool/support/guardrails_sandbox_support.dart` - repository-local
  structural proof currently encodes the old three-field candidate contract and
  therefore must move in lockstep with the owner-side fix
- local temporary-package repros run with `dart run tool/run_temp_pkg_test.dart`
  - confirmed that stale candidates currently resolve after both same-id
  `replaceScene` and same-id `delete + insert` structural writes, so the defect
  is broader than document replacement

### Current Entry Path

- committed hit-test candidate flow:
  `interactive/render consumer -> SceneStoreController.queryHitTestCandidates(...) -> SpatialIndexCache.writeQueryHitTestCandidates(...) -> SceneSpatialIndex.queryHitTestCandidates(...) -> consumer rebuilds SceneSpatialCandidateReference -> SceneStoreController.resolveSpatialCandidateSnapshot(...) -> _resolveSnapshotAtLocationInSnapshot(...)`
- committed paint candidate flow:
  `SceneControllerPaintCandidateStage / other committed consumer -> SceneStoreController.queryPaintCandidates(...) -> SpatialIndexCache.writeQueryPaintCandidates(...) -> SceneSpatialIndex.queryPaintCandidates(...) -> consumer rebuilds SceneSpatialCandidateReference -> SceneStoreController.resolveSpatialCandidateSnapshot(...)`
- structural provenance source:
  `mutation write -> ChangeSet.structuralChanged/documentReplaced -> buildControllerCommitPlan(...) -> CommittedStoreState.structuralRevision -> SceneStore.structuralRevision`

### Current Owner

- committed spatial candidate lifetime is currently split across the controller
  committed read-side boundary (`SceneStoreControllerSpatialAccess` and
  `SpatialIndexCache`) and the shared payload/index file
  `lib/src/core/scene_spatial_index.dart`
- `SceneStore.structuralRevision` is already the committed source of truth for
  structural identity
- interactive and render consumers are only forwarders of committed candidate
  payload; they do not own stale-handle policy

### Adjacent Abstractions

- `lib/src/controller/internal/spatial_index_cache.dart` - adjacent committed
  spatial owner that can carry controller-owned provenance into rebuilt and
  incremental index state
- `lib/src/interactive/internal/scene_controller_selected_paint_order_cache.dart`
  - closest owner-local precedent for invalidating locator-derived state on
  `structuralRevision`
- `lib/src/render/scene_render_caches.dart` - adjacent but intentionally
  different use of `controllerEpoch` for document/epoch cache invalidation only
- `lib/src/controller/scene_store_controller.dart` -
  `resolveSnapshotNodeById(...)` is the adjacent current-locator API and must
  stay distinct from stale external candidate validation
- `lib/src/core/revision_policy.dart` - adjacent revision primitive owner that
  explains why `controllerEpoch` and `instanceRevision` mean different things
  from committed structural layout identity

### Existing Tests

- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
  - locks the resolver contract and already proves selection-only reuse stays
  valid
- `test/controller/internal/spatial_index_cache_test.dart` - locks rebuild and
  incremental cache behavior on committed structural changes
- `test/interactive/core/interactive_move_session_test.dart` - locks move
  session consumption of committed spatial candidates
- `test/interactive/core/interactive_draw_eraser_engine_test.dart` - locks
  eraser consumption of committed spatial candidates
- `test/render/scene_painter_frame_contract_test.dart` - locks committed
  fast-path frame behavior on controller-owned structural and selection
  revisions
- `test/render/scene_painter_bounds_contract_test.dart` - locks controller
  candidate-stage ordering and supplement selection through structural and
  selection revision carriage
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` - structural
  proof for sealed controller committed-read surface and committed spatial
  payload shape
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` - structural
  proof for sealed interactive committed-read callback surface
- `test/tool/invariant_coverage_tool_test.dart` - structural proof for
  invariant registry and proof marker alignment

### Analogous Implementation Path

- `lib/src/interactive/internal/scene_controller_selected_paint_order_cache.dart`
  - the closest checked-in precedent because it already uses
  `structuralRevision` as the correct invalidation token for derived state that
  depends on structural ordering, while still pairing it with
  `selectionRevision` only where selection membership matters

### Governing Repository Rules

- `AGENTS.md` - fix the shared owner of the invariant instead of patching one
  downstream call site
- `AGENTS.md` - repository-specific knowledge must be encoded in checked-in
  tests, invariants, tooling, or source-of-truth docs rather than left in chat
- `AGENTS.md` - bug fixes require automated tests and relevant project checks
- `ARCHITECTURE.md` - committed read helpers must reject stale handles
- `docs/target_architecture/families/store_and_commit_path.md` - committed read
  ownership stays on the store family; interaction and view consumers do not
  become committed scene owners
- `tool/invariant_registry.dart` - `INV-ENG-COMMITTED-READ-SIDE-HERMETICITY`
  governs this committed query and resolver surface
- project verification instructions in `AGENTS.md` - final verification must
  run through `dart run tool/run_verification_preset.dart run --preset=required_code_change`

### Rejected Misleading Local Patterns

- `controllerEpoch` from `lib/src/render/scene_render_caches.dart` and
  `SpatialIndexCache._indexEpoch` - wrong token because it is the
  document/epoch invalidation surface and does not advance on every structural
  rewrite that can reuse the same `nodeId` at the same location
- `selectionRevision` from render frame and selected-order caching - wrong
  token because selection-only writes must keep current candidates valid and do
  not describe spatial locator identity
- `instanceRevision`-keyed node caches such as snapshot-local admission - wrong
  token because imported snapshots preserve positive `instanceRevision`, so
  replace-scene payloads can legitimately carry a repeated instance revision
- add a new `resolve*SpatialCandidate*` helper or wrapper type on the
  controller or interactive side - wrong seam because the committed read helper
  set and callback signature are already mechanically sealed
- patch only interactive consumers - wrong owner because stale external handle
  validation belongs to the committed read boundary, not to each consumer

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- committed read-side stale-handle identity contract for controller-owned
  spatial candidates

#### Selected Architectural Form

- keep the existing committed query/resolve pair:
  `queryHitTestCandidates(...)`, `queryPaintCandidates(...)`, and
  `resolveSpatialCandidateSnapshot(...)` remain the only committed spatial
  candidate seam
- extend committed spatial candidate provenance by carrying
  `structuralRevision` on the emitted candidate payloads and on
  `SceneSpatialCandidateReference`
- carry the controller-owned `structuralRevision` through the existing
  `SceneSpatialIndex` companion-data seam so the index stores and re-emits it
  as an opaque scalar without importing controller policy
- validate provenance only at
  `SceneStoreController.resolveSpatialCandidateSnapshot(...)` before location
  lookup; when the candidate revision differs from the current committed store
  revision, resolution must return `null`
- keep all interactive and render consumers as passive forwarders that rebuild
  `SceneSpatialCandidateReference` from the candidate fields they already hold

#### Owning Layer or Module

- owning policy layer: `lib/src/controller/**` committed read-side ownership
  centered on `SceneStoreControllerSpatialAccess` and
  `lib/src/controller/internal/spatial_index_cache.dart`
- shared payload carrier: `lib/src/core/scene_spatial_index.dart`
- consumer updates stay limited to in-scope forwarders in `interactive/**`

#### Dependency Direction

- `SceneStore.structuralRevision` remains the controller-owned source of truth
- controller read-side code passes the scalar down into the committed spatial
  index/cache seam
- `scene_spatial_index.dart` stores and re-emits the scalar without importing
  controller modules
- interactive and render consumers only pass the scalar back to the controller
  resolver through `SceneSpatialCandidateReference`

#### State and Data Ownership

- `SceneStore.structuralRevision` owns committed structural identity
- `SpatialIndexCache` owns the lifecycle of the committed spatial index and
  must ensure rebuilt and incremental query paths use the current structural
  revision when emitting candidates
- `SceneSpatialIndex` owns candidate enumeration and payload construction, but
  does not own revision policy beyond carrying the opaque scalar it was given
- `SceneSpatialCandidateReference` owns stale-handle provenance for external
  candidate resolution
- `resolveSnapshotNodeById(...)` remains a current-locator API and does not
  gain external provenance checks

#### Entry and Exit Boundaries

- entry boundary:
  `SceneStoreController.queryHitTestCandidates(...)` /
  `SceneStoreController.queryPaintCandidates(...)`
- exit boundary:
  `SceneStoreController.resolveSpatialCandidateSnapshot(...)`
- there is no new public or internal helper seam beyond the existing query and
  resolve surface

#### Permitted Extension Seam

- the only shape change is the sealed committed spatial payload and reference
  surface in `scene_spatial_index.dart`
- controller and interactive guardrails must be updated to seal the new exact
  field set and callback signature
- `INV-ENG-COMMITTED-READ-SIDE-HERMETICITY` is the proof seam that must state
  stale committed spatial candidates from older structural revisions are
  rejected

#### Rejected Alternatives

- `controllerEpoch` provenance - rejected because it misses same-id stale
  candidates created by ordinary structural commits that do not advance the
  epoch
- `selectionRevision` provenance - rejected because it invalidates the wrong
  class of writes and would reject selection-only reuse that the current
  contract intentionally allows
- `instanceRevision` provenance - rejected because imported replacement
  snapshots may preserve positive instance revisions
- new controller-owned wrapper candidates or extra resolve helpers - rejected
  because they widen a sealed committed read-side surface without solving the
  owner problem better than the existing payload seam

#### Why This Level Is Correct

- the defect is a stale external handle problem on the committed read boundary,
  so the fix must live where committed candidate identity is emitted and later
  validated
- `structuralRevision` is already the repository-local token for structural
  layout invalidation, and the codebase already uses it where derived order
  depends on structural placement
- updating the shared payload seam once keeps interactive and render consumers
  as simple forwarders and prevents policy duplication across every caller

## 5. Locked Decisions

1. `SceneSpatialCandidateLocation` stays a pure location alias; provenance is
   added only to `SceneSpatialCandidateReference` and the emitted candidate
   classes.
2. The fix must cover both content and background candidates on the same
   contract surface.
3. The existing selection-only resolver acceptance test remains the guard that
   non-structural commits do not invalidate committed spatial candidates.
4. `resolveSnapshotNodeById(...)` remains unchanged; this step only tightens
   external stale candidate resolution.
5. The old three-field locator-only payload contract is retired only after all
   production consumers, sandbox fixtures, and guardrail expectations migrate
   to the `structuralRevision` shape.

## 6. Result Requirements

1. A committed spatial candidate from an earlier structural revision must
   resolve to `null` even when a later committed scene reuses the same
   `nodeId`, `layerIndex`, and `nodeIndex`.
2. The stale rejection requirement must hold for both `replaceScene` and
   ordinary structural commits such as same-id `delete + insert`.
3. Selection-only and other non-structural commits must keep the current
   candidate resolvable when the node still exists at the same location.
4. Fresh committed queries issued after a structural commit must emit
   candidates that carry the current `structuralRevision` and resolve
   successfully.
5. Repository-local guardrails, invariant wording, and architecture prose must
   describe and mechanically enforce the new structural-provenance candidate
   contract.

## 7. Execution Order and Gates

### Required Order

- first, add the failing reproducer and neighboring guard tests on the current
  owner surface
- next, land the minimal owner-side provenance fix in the committed spatial
  payload, cache, resolver, and in-scope forwarders, and migrate the exact
  controller/interactive guardrail signatures in the same slice so the new
  payload shape is sealed as soon as production code adopts it
- then, update invariant wording and architecture prose to retire the old
  three-field locator-only contract from repository truth

### Successor Seam and Retirement Gates

- successor seam: the existing committed query/resolve pair with
  `structuralRevision` carried on candidate payloads and references
- consumer migration order:
  production committed-read consumers ->
  controller and interactive unit tests ->
  guardrail sandbox support ->
  controller and interactive guardrail exact-signature expectations
- retirement gate: the old three-field candidate contract may be considered
  retired only after both `guardrails_controller_api_tool_test.dart` and
  `guardrails_interactive_api_tool_test.dart` pass with the new shape and no
  production consumer still rebuilds a three-field
  `SceneSpatialCandidateReference`

### Deferred Broad Verification

- reserve `dart run tool/check_guardrails.dart` for the final gate after all
  guardrail fixtures and exact-signature expectations migrate
- reserve `dart run tool/check_invariant_coverage.dart` for the final gate
  after invariant wording is updated
- reserve the required code-change preset for the final gate after all planned
  files in this step are in place

## 8. File Map

### Implementation Files

- `lib/src/core/scene_spatial_index.dart`
- `lib/src/controller/internal/spatial_index_cache.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/controller/scene_controller_commit_execution.dart`
- `lib/src/interactive/internal/interactive_move_hit_test_engine.dart`
- `lib/src/interactive/internal/interactive_draw_eraser_targets.dart`
- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart`

### Test Files

- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/interactive/core/interactive_move_session_test.dart`
- `test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/interactive_api/committed_read_callbacks/callback_contract_cases.dart`
- `test/tool/invariant_coverage_tool_test.dart`

### Fixtures and Supporting Data

- `test/tool/support/guardrails_sandbox_support.dart`

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `plan/step_25_committed_spatial_candidate_structural_revision_contract.md`
- `tool/invariant_registry.dart`
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_committed_read_callback_guard_rules.dart`
- `ARCHITECTURE.md`

### Analysis Area

- `lib/src/controller/**`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/interactive/internal/**`
- `tool/src/guardrails/rules/controller/**`
- `tool/src/guardrails/rules/interactive/**`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-COMMITTED-READ-SIDE-HERMETICITY` must explicitly cover stale
  committed spatial candidate rejection across structural revision changes
- `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION` must keep committed fast-path paint
  staging tied to the current committed controller snapshot and revision-owned
  ordering assumptions
- `INV-ENG-COMMITTED-SELECTION-REVISION-ALIGNMENT` remains unchanged; do not
  make selection-only commits invalidate spatial candidate identity
- `INV-ENG-SPATIAL-INDEX-REBUILD-ON-INVALID` and
  `INV-ENG-COMMITTED-SPATIAL-ADMISSION-ALIGNMENT` must continue to hold after
  provenance is threaded through rebuilt and incremental index paths

### Required Proof

- behavioral proof:
  `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
  must first fail on the same-id stale content reproducer and add 1 to 3
  neighboring guard tests for the same contract
- behavioral proof:
  `test/controller/internal/spatial_index_cache_test.dart` must prove fresh
  queries after structural commits emit current structural provenance on cache
  rebuild and incremental paths
- behavioral proof:
  `test/interactive/core/interactive_move_session_test.dart`,
  `test/interactive/core/interactive_draw_eraser_engine_test.dart`,
  `test/render/scene_painter_frame_contract_test.dart`, and
  `test/render/scene_painter_bounds_contract_test.dart` must continue to prove
  the in-scope committed-read consumers still work with the revised candidate
  shape
- structural proof:
  `test/tool/guardrails/guardrails_controller_api_tool_test.dart` and
  `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` must seal
  the new exact candidate and callback shapes
- structural proof:
  `test/tool/invariant_coverage_tool_test.dart` and
  `dart run tool/check_invariant_coverage.dart` must stay aligned with the
  updated invariant wording
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- internal committed spatial payload and resolver code under `lib/src/core` and
  `lib/src/controller`
- in-scope internal consumers that manually rebuild
  `SceneSpatialCandidateReference`
- guardrail rules, guardrail sandbox support, invariant wording, and
  architecture prose required to lock the new contract
- plan index and this step document

### Forbidden Moves

- do not add a new committed read helper method or wrapper type to avoid
  touching the sealed payload surface
- do not use `controllerEpoch`, `selectionRevision`, or `instanceRevision` as
  the committed spatial candidate provenance token
- do not move stale-handle rejection into interactive or render callers
- do not change `resolveSnapshotNodeById(...)` semantics in this step
- do not alter public exports, supported imports, or package-visible API shape
- do not leave guardrails or invariant wording on the old three-field contract
  after implementation lands

## 10. Vertical Slices

### Slice 1. [x] Lock the Stale Structural Candidate Regression

#### Slice Contract

Check in failing reproducer-first proof on the current resolver owner surface
so same-id stale reuse after structural commits is no longer an untested gap.

#### Change

- extend
  `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
  with one failing same-id stale content candidate reproducer after
  `replaceScene`
- add neighboring guard tests for same-id stale background candidate after
  `replaceScene` and same-id stale candidate after ordinary same-id
  `delete + insert`
- keep the existing selection-only acceptance test as the non-structural guard
  branch rather than broadening the owner fix before the contract is locked

#### Behavioral Verification

- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
  — expected to fail on the new stale structural candidate assertions until
  slice 2 lands

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Fixtures Used

- none

#### Positive Scenarios

- stale same-id content candidate after `replaceScene` is asserted on the
  existing owner surface
- stale same-id background candidate after `replaceScene` is asserted on the
  existing owner surface

#### Negative Scenarios

- stale same-id candidate after ordinary same-id structural rewrite is asserted
  on the existing owner surface
- existing selection-only reuse remains the passing non-structural branch

#### Closure Evidence

- the new reproducer and neighboring guard tests are checked in and fail for
  the currently confirmed defect
- the current structural guardrail suite still passes before the owner-side fix

### Slice 2. [x] Carry Structural Revision Through the Committed Spatial Seam

#### Slice Contract

Land the minimum owner-side fix so committed spatial candidates carry current
`structuralRevision` from query emission through stale-handle resolution and
fresh queries after structural commits resolve successfully.

#### Change

- extend `SceneSpatialCandidateReference`,
  `SceneHitTestSpatialCandidate`, and `ScenePaintSpatialCandidate` with
  `structuralRevision`
- carry the scalar through `SceneSpatialIndex` build, clone, incremental
  update, and query emission without importing controller modules into `core`
- pass `structuralRevision` through `SpatialIndexCache` query and commit paths
  and into `SceneStoreController.resolveSpatialCandidateSnapshot(...)`
- if `SpatialIndexCache.writePrepareCommit(...)` and its prepared-commit
  carriers grow a `structuralRevision` parameter, thread
  `committedStoreState.structuralRevision` through
  `SceneControllerCommitExecution` so rebuilt and incremental cached indexes
  are stamped before the committed store swap completes
- reject stale candidates in `resolveSpatialCandidateSnapshot(...)` when the
  candidate revision does not match the current committed store revision
- update in-scope consumers that manually rebuild
  `SceneSpatialCandidateReference` so they forward `structuralRevision`
- update controller and interactive guardrail rules, sandbox fixtures, and
  exact-signature expectations so the new candidate/reference shape becomes
  the only accepted committed spatial payload contract
- extend `test/controller/internal/spatial_index_cache_test.dart` so rebuilt
  and incremental query paths both prove fresh candidate provenance after
  structural commits

#### Behavioral Verification

- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/interactive/core/interactive_move_session_test.dart`
- `flutter test test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Fixtures Used

- `test/tool/support/guardrails_sandbox_support.dart`

#### Positive Scenarios

- fresh content and background candidates queried after structural commits carry
  the current `structuralRevision` and resolve successfully
- rebuilt and incremental spatial-index paths emit the same current structural
  provenance contract

#### Negative Scenarios

- stale same-id candidates from an earlier structural revision resolve to
  `null`
- non-structural selection-only reuse remains valid

#### Closure Evidence

- slice 1 behavioral repros turn green without widening the committed read
  helper set
- cache, interactive, and render consumer tests stay green with the revised
  candidate shape
- controller and interactive guardrail rules, fixtures, and tool tests all pass
  with the new exact payload and callback signature

### Slice 3. [x] Seal the Structural-Provenance Contract in Repository Truth

#### Slice Contract

Update invariant wording and architecture prose so the new committed spatial
candidate lifetime rule is mechanically enforced and documented at the
repository source-of-truth level.

#### Change

- extend `INV-ENG-COMMITTED-READ-SIDE-HERMETICITY` in
  `tool/invariant_registry.dart` to require stale committed spatial candidates
  from older structural revisions to reject
- update `ARCHITECTURE.md` where committed read helpers and stale handles are
  described so spatial candidate provenance is no longer implied only by tests
- keep the target family shape unchanged; do not introduce a new family or
  alternate committed read seam

#### Behavioral Verification

- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/invariant_coverage_tool_test.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- none

#### Positive Scenarios

- the invariant registry explicitly names structural-revision stale rejection on
  committed spatial candidates
- architecture prose names the controller-owned provenance contract instead of
  leaving it implicit

#### Negative Scenarios

- invariant coverage must fail if proof markers or invariant ownership drift
  after the wording update
- architecture prose must not claim a new public API or new committed read
  seam

#### Closure Evidence

- invariant coverage passes with the updated wording
- the checked-in architecture text and invariant registry both name the same
  structural-provenance contract that the tests now enforce

## 11. Final Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart test/tool/invariant_coverage_tool_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/interactive/core/interactive_move_session_test.dart`
- `flutter test test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `printf '%s\n' 'PLAN.md' 'plan/step_25_committed_spatial_candidate_structural_revision_contract.md' 'ARCHITECTURE.md' 'lib/src/core/scene_spatial_index.dart' 'lib/src/controller/internal/spatial_index_cache.dart' 'lib/src/controller/scene_store_controller.dart' 'lib/src/controller/scene_controller_commit_execution.dart' 'lib/src/interactive/internal/interactive_move_hit_test_engine.dart' 'lib/src/interactive/internal/interactive_draw_eraser_targets.dart' 'lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart' 'test/controller/core/scene_controller_spatial_candidate_resolution_test.dart' 'test/controller/internal/spatial_index_cache_test.dart' 'test/interactive/core/interactive_move_session_test.dart' 'test/interactive/core/interactive_draw_eraser_engine_test.dart' 'test/render/scene_painter_frame_contract_test.dart' 'test/render/scene_painter_bounds_contract_test.dart' 'test/tool/guardrails/guardrails_controller_api_tool_test.dart' 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart' 'test/tool/guardrails/interactive_api/committed_read_callbacks/callback_contract_cases.dart' 'test/tool/invariant_coverage_tool_test.dart' 'test/tool/support/guardrails_sandbox_support.dart' 'tool/invariant_registry.dart' 'tool/src/guardrails/rules/controller/write_only_mutation_rules.dart' 'tool/src/guardrails/rules/interactive/interactive_committed_read_callback_guard_rules.dart' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- same-id stale committed spatial candidates are rejected after both
  `replaceScene` and ordinary structural rewrites
- selection-only committed writes still preserve current candidate resolution
- fresh committed queries after structural writes emit current
  `structuralRevision` and resolve successfully
- no new committed read helper or wrapper seam is introduced
- controller and interactive guardrails seal the new exact candidate/reference
  shape
- invariant wording and architecture prose match the implemented
  structural-provenance contract
