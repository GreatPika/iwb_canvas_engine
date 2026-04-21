language: english

# Change Contract

## 1. Change Mandate

This change fixes committed paint-path staging so one controller-owned
production service prepares render candidates, owns canonical candidate order,
and is enforced through repository-local performance contracts.

## 2. Change Boundary

### Included in the Change

- One controller-owned prepared paint-plan contract for committed render frames.
- Transfer of candidate-order and candidate-packaging ownership out of
  painter-side modules.
- Canonical ordinary candidate ordering in the shared committed paint-query
  source.
- Ordered selected-node supplement staging, deduplication, and linear merge
  with ordinary candidates.
- Benchmark taxonomy, benchmark policy, invariant, and documentation updates
  that lock the production paint-staging contract.

### Not Included in the Change

- Public package-surface additions, removals, or renames.
- Cross-frame viewport memoization or any second cache owner for committed
  paint plans.
- Changes to hit-test semantics, preview semantics, selection semantics, or
  JSON contracts.
- Geometry-cache, text-layout-cache, or stroke-path-cache redesign outside the
  changes required to consume the prepared paint plan.

## 3. Surrounding Code Review

### Inspected Artifacts

- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` —
  owns `captureFrameRead()` and the committed `preparePaintPlan(...)` branch;
  this is the live entrypoint that decides between committed staging and
  divergent snapshot fallback.
- `lib/src/contract/scene_view_render_state.dart` — defines
  `SceneViewFrameRead`, `ScenePreparedPaintPlan`, and the internal read-side
  render contract; this is the existing carrier boundary for atomic render
  inputs.
- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart` —
  current committed stage owner for ordinary candidate staging, selected
  supplement staging, linear merge, and stage-local debug counters.
- `lib/src/interactive/internal/scene_controller_selected_paint_order_cache.dart` —
  current selected-order cache owner; today it still rebuilds by
  recompute-and-compare instead of an explicit committed invalidation key.
- `lib/src/controller/store.dart` — committed controller state owner for the
  selection set and monotonic revision counters.
- `lib/src/controller/committed_store_state.dart` — commit-pipeline snapshot of
  controller-owned state applied after a successful committed write.
- `lib/src/controller/scene_controller_commit_plan.dart` —
  controller-owned commit planning path where committed revision changes are
  derived from `ChangeSet`.
- `lib/src/controller/scene_controller_commit_execution.dart` — single apply
  path that commits planned controller-owned state into `SceneStore`.
- `lib/src/controller/scene_store_controller.dart` — sealed controller facade
  plus the already sealed `SceneStoreControllerSpatialAccess` helper surface;
  this is the nearby seam that must not be widened for Slice 3.5.
- `lib/src/controller/scene_controller_commit_debug.dart` — existing debug-only
  seam; it proves a `debug` path exists but is the wrong production owner for
  revision delivery.
- `lib/src/controller/scene_controller_committed_mutation_access.dart` —
  repository precedent for a sealed single-owner access boundary; it is valid
  for committed mutation orchestration but is the wrong owner for committed
  read-side revision delivery.
- `ARCHITECTURE.md` — repository source of truth for the render admission
  boundary, controller/read-side ownership split, and divergent snapshot
  fallback invariants.
- `test/render/scene_painter_frame_contract_test.dart` — behavioral coverage
  for controller-owned render-state integration and frame-read capture.
- `test/render/scene_painter_bounds_contract_test.dart` — structural and
  behavioral coverage for paint-plan ownership and render-side consumption.
- `test/controller/core/scene_controller_commit_atomicity_test.dart` —
  behavioral coverage for commit atomicity and revision monotonicity.
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` —
  structural test that pins render-state/stage/cache ownership and forbids
  architecture drift in the committed paint path.
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` —
  guardrail that seals `SceneStoreControllerSpatialAccess` to its exact helper
  surface.
- `tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart` —
  guardrail that seals `SceneStoreController` public members to the allowed
  controller facade surface.
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` —
  repository-owned regression coverage proving controller-layer import and
  surface widening violations fail mechanically.

### Current Entry Path

- `ScenePainter` captures one `SceneViewFrameRead`, then calls
  `SceneViewRenderState.preparePaintPlan(...)`.
- On the committed path,
  `SceneControllerSceneViewRenderState.preparePaintPlan(...)` delegates to
  `SceneControllerPaintCandidateStage.prepareCommittedPaintPlan(...)`.
- On the divergent path,
  `SceneControllerSceneViewRenderState.preparePaintPlan(...)` falls back to
  `enumerateSnapshotPaintCandidates(...)` against the captured frame snapshot.

### Current Owner

- Committed render-side orchestration lives in
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`.
- Committed candidate staging lives in
  `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart`.
- Committed revision and selection-membership state live under
  `lib/src/controller/**`.

### Adjacent Abstractions

- `SceneSpatialIndex` — shared committed paint-query owner for ordinary
  candidate admission and canonical ordinary order.
- `SceneControllerSelectedPaintOrderCache` — committed selected-order token
  owner for supplement ordering.
- `SceneStoreControllerSpatialAccess` — sealed helper surface for committed
  read-side spatial queries and snapshot resolution.
- `SceneControllerCommittedMutationAccess` — sealed committed mutation adapter
  pattern that is adjacent in shape but not the owner of committed read-side
  invalidation delivery.

### Existing Tests

- `test/render/scene_painter_frame_contract_test.dart` — proves the render
  path consumes controller-owned paint plans and reuses one captured frame
  read.
- `test/render/scene_painter_bounds_contract_test.dart` — proves render-side
  staging ownership and forbids painter-side candidate enumeration drift.
- `test/controller/core/scene_controller_commit_atomicity_test.dart` — proves
  committed writes stay atomic and revisions do not drift on no-op or failed
  paths.
- `test/core/scene_spatial_index_test.dart` — proves canonical ordinary paint
  order now lives in `SceneSpatialIndex`.
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` —
  proves committed staging, render-state boundaries, and selected-order cache
  ownership are mechanically enforced.
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` — proves
  sealed controller-surface and sealed committed read-helper drift fail
  mechanically.
- `test/tool/bench_run_load_profiles_test.dart` and
  `test/tool/bench_diff_load_profiles_test.dart` — prove benchmark taxonomy
  and metric-schema drift fail in-repo.
- `test/tool/verification_contract_tool_test.dart` — proves workflow-contract
  drift for `.github/workflows/ci.yaml` and
  `.github/workflows/perf_nightly.yaml` fails in-repo.

### Analogous Implementation Path

- `lib/src/contract/scene_view_render_state.dart` plus
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` —
  the repository already uses `SceneViewFrameRead` as the single atomic carrier
  for committed render-side inputs such as `snapshot`, `selectedNodeIds`, and
  preview resolution. Extending that existing atomic carrier is the closest
  valid local precedent for Slice 3.5.

### Governing Repository Rules

- `ARCHITECTURE.md` — render read-side flows consume committed paint
  candidates through the read-side runtime boundary and keep divergent fallback
  snapshot-authoritative.
- `tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart` —
  `SceneStoreController` public member surface is sealed and must not widen for
  local convenience getters.
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` —
  `SceneStoreControllerSpatialAccess` helper surface is sealed to the exact
  committed read-side helper set.
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` — controller
  layer must not import `scene_view_render_state.dart`, and
  `SceneStoreController` must not implement `SceneViewRenderState`.
- `tool/check_verification_contract.dart` and
  `test/tool/verification_contract_tool_test.dart` — workflow ownership for
  `.github/workflows/ci.yaml` and `.github/workflows/perf_nightly.yaml`
  already has repository-local mechanical verification.

### Rejected Misleading Local Patterns

- `lib/src/controller/scene_store_controller.dart` convenience getter growth
  outside one exact `selectionRevision` getter — wrong owner shape and
  mechanically blocked by sealed controller-surface guardrails.
- `SceneStoreControllerSpatialAccess` helper extension growth — wrong seam and
  mechanically blocked by sealed helper-surface guardrails.
- `lib/src/controller/scene_controller_commit_debug.dart` as a production read
  path — wrong seam because `debug`-named access is test/debug-owned, not a
  production dependency boundary.
- `lib/src/controller/scene_controller_committed_mutation_access.dart`-style
  secondary adapter for read-side revision delivery — wrong owner because it
  duplicates access ownership for one committed paint path.
- Live `selectionRevision` reads after frame capture — wrong level because
  they can mix stale frame snapshot state with newer committed selection
  membership and break atomicity.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Interactive read-side orchestration boundary between committed controller
  state and the committed render pipeline.

#### Selected Architectural Form

- Controller-owned committed state owns one monotonic `selectionRevision`.
- The only permitted delivery seam from controller-owned committed state into
  frame capture is one exact internal `SceneStoreController.selectionRevision`
  getter on the already existing controller facade that committed render-state
  code already depends on.
- `SceneControllerSceneViewRenderState.captureFrameRead()` atomically captures
  that committed `selectionRevision` from `SceneStoreController` into
  `SceneViewFrameRead` together with
  `snapshot`, `selectedNodeIds`, and the preview resolver.
- `SceneControllerPaintCandidateStage` and
  `SceneControllerSelectedPaintOrderCache` consume only the frame-captured
  `selectionRevision` plus committed `structuralRevision` on the committed
  paint path.

#### Owning Layer or Module

- State ownership lives in `lib/src/controller/**`.
- Atomic render-side capture and committed-path consumption live in
  `lib/src/contract/scene_view_render_state.dart` and
  `lib/src/interactive/internal/**`.

#### Dependency Direction

- `controller -> contract -> interactive/internal -> render`.
- Controller-owned state may feed the contract carrier, and interactive
  committed staging may consume the captured carrier.
- The committed selection-revision read path must stay on the already existing
  `SceneControllerSceneViewRenderState -> SceneStoreController` dependency and
  must widen that sealed controller surface only by one exact
  `selectionRevision` getter rather than by a new helper surface, graph
  closure chain, or secondary access owner.
- Reverse edges are forbidden: controller code must not import
  `scene_view_render_state.dart`, and committed render-side code must not pull
  live revision state back through controller debug/helper/adapters after frame
  capture.

#### State and Data Ownership

- `selectionRevision` lives in committed controller state and is mutated only
  by the committed write pipeline when selection membership changes.
- `SceneViewFrameRead` owns the per-frame captured revision value passed into
  the committed paint path.
- `SceneControllerSelectedPaintOrderCache` owns only ordered selected-node
  tokens keyed by `(selectionRevision, structuralRevision)`.

#### Entry and Exit Boundaries

- `selectionRevision` enters the architecture at commit planning/execution
  under `lib/src/controller/**`.
- It exits controller-owned state only through one exact internal
  `SceneStoreController.selectionRevision` getter and is consumed only during
  `SceneControllerSceneViewRenderState.captureFrameRead()`.
- The committed paint path consumes it only through
  `SceneViewFrameRead -> SceneControllerSceneViewRenderState.preparePaintPlan(...) -> SceneControllerPaintCandidateStage.prepareCommittedPaintPlan(...)`.

#### Permitted Extension Seam

- The only permitted seam for Slice 3.5 is one exact internal
  `SceneStoreController.selectionRevision` getter plus the internal
  `SceneViewFrameRead` carrier and the committed branch of
  `SceneControllerSceneViewRenderState.captureFrameRead()` and
  `preparePaintPlan(...)`.

#### Rejected Alternatives

- Helper-extension delivery or any controller-surface growth beyond one exact
  internal `SceneStoreController.selectionRevision` getter — rejected because
  it expands the sealed controller/read-helper surfaces beyond the one
  controller-owned revision read that this slice needs.
- `debug` access or a second read adapter/access owner — rejected because it
  either depends on a debug-named production seam or duplicates access
  ownership for one committed paint path.

#### Why This Level Is Correct

- The bug is an atomicity bug in the committed render read boundary, not a
  missing convenience seam on the controller facade.
- Capturing `selectionRevision` into the already existing frame-read carrier
  fixes the bug once at the correct level, preserves one committed paint owner,
  respects repository guardrails, and avoids introducing a second read owner or
  a production dependency on debug access.

## 5. File Map

### Implementation Files

- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/controller/internal/spatial_index_cache.dart`
- `lib/src/controller/committed_store_state.dart`
- `lib/src/controller/change_set.dart`
- `lib/src/controller/scene_controller_commit_execution.dart`
- `lib/src/controller/scene_controller_commit_plan.dart`
- `lib/src/controller/scene_controller_commit_runtime.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/controller/store.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart`
- `lib/src/interactive/internal/scene_controller_selected_paint_order_cache.dart`
- `lib/src/render/scene_painter_contract.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/render/scene_painter_node_renderer.dart`
- `tool/bench/load_profile_policy.dart`
- `tool/bench/load_profiles_cases_test.dart`
- `tool/bench/diff_load_profiles.dart`
- `tool/check_verification_contract.dart`
- `tool/src/verification_contract/**`
- `.github/workflows/ci.yaml`
- `.github/workflows/perf_nightly.yaml`
- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`

### Test Files

- `test/core/scene_spatial_index_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/bench_diff_load_profiles_test.dart`
- `test/tool/verification_contract_tool_test.dart`
- `tool/bench/load_profiles_cases_test.dart`

### Fixtures and Supporting Data

- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`

### Analysis Area

- `lib/src/contract/**`
- `lib/src/core/**`
- `lib/src/controller/**`
- `lib/src/interactive/internal/**`
- `lib/src/render/**`
- `tool/bench/**`
- `tool/invariant_registry.dart`
- `.github/workflows/**`
- `test/core/**`
- `test/controller/**`
- `test/render/**`
- `test/interactive/core/**`
- `test/tool/**`

### File Rules

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. Committed paint-candidate staging after this step is controller-owned.
   Painter-side modules consume prepared staged data and do not own repair-sort
   or defensive candidate packaging.
2. The prepared paint-plan contract remains internal under `src/**` and does
   not change the supported public package surface.
3. Ordinary committed candidate order must become canonical at or below the
   shared paint-query source. The final committed fast path must not depend on
   a per-frame global repair sort for ordinary candidates.
4. Selected-node supplements remain admitted through `visibilityRect`, remain
   deduped once per frame, and must preserve canonical scene order.
5. Divergent active-frame fallback remains snapshot-authoritative and may
   continue using snapshot enumeration instead of committed staged data.
6. This step must not introduce cross-frame viewport memoization, a second
   committed spatial index, or a second committed paint-plan cache owner.
7. Smoke benchmark reporting after this step does not publish percentile
   metrics. Smoke remains a fast guard profile and reports only metrics whose
   sample counts are semantically valid at smoke-scale iteration counts.
8. The heavier `full` benchmark profile remains the separate high-scale perf
   gate under `.github/workflows/perf_nightly.yaml`; this step does not move
   `full` into the regular PR-blocking CI workflow.
9. The committed branch in `SceneControllerSceneViewRenderState` after Slice 1
   closes calls exactly one
   `SceneControllerPaintCandidateStage.prepareCommittedPaintPlan(...)` entry
   point on every committed-frame execution and does not assemble committed
   prepared-plan contents itself.
10. Reuse inside `SceneControllerPaintCandidateStage` is limited to per-call
    scratch buffers and test-only counters. Prepared plans, ordinary candidate
    sequences, supplement results, or other committed-frame staging artifacts
    must not be retained across committed frames.
11. After Slice 2 closes, `SceneSpatialIndex` is the only owner allowed to
    derive canonical ordinary committed paint order. `SpatialIndexCache`,
    `SceneStoreController`, and `SceneControllerPaintCandidateStage` must treat
    ordinary committed paint-query output as already canonical and must not
    repair-sort, re-bucket, or reorder it.
12. `SceneControllerSelectedPaintOrderCache` after Slice 3 closes stores only
    committed selected-node order tokens derived from the committed node
    locator, or equivalent `(layerIndex, nodeIndex)` order records. It does not
    store retained cross-frame candidate lists, filtered supplement lists, or
    prepared paint plans.
13. Slice 3.5 closes only with one invalidation-key shape for committed
    selected-order caching: committed selection-membership invalidation is
    owned by an internal monotonic `selectionRevision` carried in committed
    controller state and atomically captured into `SceneViewFrameRead`. The
    selected-order cache must not infer invalidation from selected-set object
    identity, live controller reads after frame capture, frame-read identity,
    or recompute-and-compare fallback logic.
14. `selectionRevision` remains internal to `lib/src/controller/**`,
    `lib/src/interactive/internal/**`, and `lib/src/contract/**` for this
    step. Slice 3.5 must not add a new public package getter, must not route
    production reads through a `debug` seam, and must not introduce a second
    selection-membership revision owner outside committed controller state.
15. Slice 3.5 closes only with one production delivery form for committed
    render-state consumers: one exact internal
    `SceneStoreController.selectionRevision` getter is allowed on the sealed
    controller facade, `SceneControllerSceneViewRenderState.captureFrameRead()`
    captures that committed `selectionRevision` into `SceneViewFrameRead`, and
    the committed branch consumes only that captured value when calling
    `SceneControllerPaintCandidateStage`. No live post-capture read,
    `debug`-named access, helper extension, graph/runtime callback transport,
    or secondary adapter/access owner is allowed for `selectionRevision`
    delivery in this step.
16. Architecture-relevant slices close only with both behavioral and
    structural verification. `test/interactive/core/scene_controller_architecture_boundary_test.dart`
    is required structural verification for slices 1 through 3.5, and the
    benchmark/tool tests plus workflow verification checks are required
    structural verification for Slice 4.

## 7. Result Requirements

1. Committed scene paint frames consume one controller-owned prepared
   paint-plan object instead of constructing a defensive unmodifiable candidate
   list inside painter-side code.
2. Ordinary committed paint candidates are emitted in canonical scene order
   without a per-frame global repair sort in the committed fast path.
3. Selected-node supplements admitted only through `visibilityRect` preserve
   canonical scene order, are deduped once, and do not move relative to
   ordinary candidates.
4. The committed staging owner exposes deterministic proof of reuse and
   ordering behavior through repository-owned tests or debug counters rather
   than relying on VM-allocation folklore.
5. Divergent active-frame fallback keeps current snapshot-authoritative
   behavior and does not mix committed staged candidates with a divergent frame
   snapshot.
6. The committed branch in `SceneControllerSceneViewRenderState` delegates
   committed plan construction to one exact stage-owner entry point and does
   not assemble committed plan contents locally.
7. Repository benchmarks distinguish these exact selection-path benchmark cases
   and operations: `selection_path_painter_only` with
   `paint_no_selection` and `paint_with_selection`,
   `selection_path_candidate_staging` with
   `stage_no_selection` and `stage_with_selection`, and
   `selection_path_end_to_end_paint` with
   `paint_no_selection` and `paint_with_selection`.
8. Load-profile policy does not publish percentile metrics for smoke profiles,
   and full-profile percentile metrics remain confined to the heavier full perf
   gate.
9. Repository-local tests and invariants describe one coherent rule:
   controller-owned staging owns candidate preparation and ordering, while
   painter-side code consumes prepared staged data only.
10. Documentation under `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and
    `CHANGELOG.md` reflects the sealed committed paint-staging contract and the
    corrected benchmark semantics.
11. Production benchmark cases `selection_path_candidate_staging` and
    `selection_path_end_to_end_paint` execute the committed staging branch with
    identity-equal active and committed snapshots, hit
    `prepareCommittedPaintPlan(...)`, and do not measure divergent snapshot
    fallback.
12. The exact benchmark cases
    `selection_path_painter_only`,
    `selection_path_candidate_staging`, and
    `selection_path_end_to_end_paint` with their exact operations are part of
    the required case set and diff surface for both `smoke` and `full`
    profiles.
13. Repeated committed frames with unchanged selection membership and unchanged
    committed node-location order do not rebuild
    `SceneControllerSelectedPaintOrderCache`; changing either input rebuilds it
    exactly once.
14. After Slice 3.5 closes, repeated committed frames with unchanged
    frame-read-captured `selectionRevision` and unchanged `structuralRevision`
    perform zero selected-order-token recomputation: they do not iterate
    selected ids, do not resolve selected order locations, and do not sort
    selected-order tokens.
15. Checked-in benchmark baselines for `smoke` and `full` intentionally match
    the finalized contract shape, required case set, required operations, and
    metric schema after Slice 4 closes.

## 8. Implementation Rules

### Analysis Scope

- Inspect all current committed paint-path call sites of
  `enumeratePaintCandidates(...)`, `ScenePainterPaintFrame.paintCandidates`,
  `ScenePainterNodeRenderer._drawVisibleNodes(...)`, and
  `_enumerateCommittedSnapshotPaintCandidates(...)` before changing ownership.
- Inspect `SceneSpatialIndex.queryPaintCandidates(...)`,
  `_querySceneSpatialIndexPaint(...)`, `_queryLinearPaint(...)`,
  `_resolvePaintCandidates(...)`, and the candidate-id collection path before
  changing ordinary paint-order ownership.
- Inspect benchmark policy and benchmark case ownership in
  `tool/bench/load_profile_policy.dart`,
  `tool/bench/load_profiles_cases_test.dart`,
  `test/tool/bench_run_load_profiles_test.dart`,
  `test/tool/bench_diff_load_profiles_test.dart`,
  `tool/bench/baselines/load_profiles_smoke_baseline.json`, and
  `tool/bench/baselines/load_profiles_full_baseline.json` before changing perf
  taxonomy or metric semantics.

### Target Verification Units

- `flutter test test/controller/core/scene_controller_commit_atomicity_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/core/scene_spatial_index_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/verification_contract_tool_test.dart`
- `dart run tool/check_verification_contract.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<path-or->`

### Protected States, Data, or Structures

- `SceneViewFrameRead` remains the single atomic frame-read capture reused
  across background paint, candidate staging, preview resolution, and node
  paint.
- `SceneViewFrameRead` becomes the only production handoff allowed to carry
  committed `selectionRevision` from committed controller state into the
  committed paint path.
- `ScenePainterVisibilityBudget` remains render-local and continues to define
  `viewportRect` vs `visibilityRect` semantics.
- Divergent active-frame fallback remains the only owner allowed to enumerate
  arbitrary frame snapshots directly.
- `SceneControllerPaintCandidateStage` remains a per-call staging owner only
  and does not retain any cross-frame prepared plans, candidate sequences,
  filtered supplement lists, or other committed-frame staging artifacts.
- `SceneControllerSelectedPaintOrderCache` keeps only committed selected-node
  order records and does not retain committed-frame supplement lists or
  prepared paint plans across frames.
- Committed selection-membership invalidation belongs to controller-owned
  committed state, not to painter-side code, frame-read identity, or
  selected-set object identity heuristics.
- No committed paint-path owner outside test-only counters, including
  `scene_controller_scene_view_runtime.dart`, may retain cross-frame prepared
  plans, candidate sequences, supplement lists, or other committed staging
  artifacts.
- Background/content order semantics stay identical to the committed scene
  order already encoded by `layerIndex` and `nodeIndex`.
- Hit-test admission remains independent from committed paint-candidate
  staging.

### Allowed Semantic Change Zones

- Internal read-side paint-plan contract shape.
- Controller-owned committed paint-candidate stage ownership.
- Selected-node supplement ordering and deduplication behavior.
- Shared paint-query ordering behavior for ordinary committed candidates.
- Benchmark case taxonomy, metric schema, and workflow expectations.
- Invariant wording, architecture wording, and release-ready documentation for
  the sealed paint-staging contract.

### Structural Enforcement

- Structural tests proving Slice 1 must inspect
  `ScenePainterFrameOwner.create(...)` and reject
  `List<ScenePaintCandidate>.unmodifiable(` in the committed paint-path owner.
- Structural tests proving Slice 1 must inspect the read-side handoff contract
  and prove committed painter-side code consumes one indexed prepared-plan
  contract instead of a lazy candidate iterable or a growable candidate list.
- Structural tests proving Slice 1 must inspect the committed branch in
  `scene_controller_scene_view_runtime.dart`, require one exact
  `SceneControllerPaintCandidateStage.prepareCommittedPaintPlan(...)` call on
  every committed-frame execution, and reject committed prepared-plan assembly
  outside `scene_controller_paint_candidate_stage.dart`.
- Structural tests proving Slice 2 must inspect the shared paint-query source
  and reject full-scene traversal or retained paint-entry topology caches for
  ordinary paint order. Candidate-bounded ordering of admitted spatial ids by
  the current committed node locator is allowed inside `SceneSpatialIndex`.
- Structural tests proving Slice 2 must reject ordinary-order repair in
  `spatial_index_cache.dart`, `scene_store_controller.dart`, and
  `scene_controller_paint_candidate_stage.dart` after
  `queryPaintCandidates(...)`.
- Structural tests proving Slice 3 must inspect the committed staging owner and
  reject a committed fast-path global `.sort(` on the final ordinary-plus-
  supplement candidate sequence.
- Structural tests proving Slice 3 must reject selected-order derivation or
  selected-supplement sorting outside
  `scene_controller_selected_paint_order_cache.dart`.
- Structural tests proving Slice 3 must reject retaining any cross-frame
  selected candidate lists, filtered supplement lists, or prepared plans inside
  `scene_controller_selected_paint_order_cache.dart`.
- Structural tests proving Slice 3.5 must require one committed
  `selectionRevision` owner in controller state, one atomic capture into
  `SceneViewFrameRead`, and must reject selected-order cache invalidation
  based on selected-set object identity, live post-capture reads, or
  recompute-and-compare fallback logic.
- Structural tests proving Slice 3.5 must allow exactly one sealed-surface
  expansion on `scene_store_controller.dart`: internal
  `SceneStoreController.selectionRevision`, with guardrails/tool tests updated
  to permit that getter and no other controller/helper growth.
- Structural tests proving Slice 3.5 must require the exact frame-read
  delivery path into `SceneControllerSceneViewRenderState` and
  `SceneControllerPaintCandidateStage` and must reject `debug`-named access,
  helper-extension delivery, graph/runtime callback transport, secondary
  access owners, or any live `_storeController.selectionRevision` read outside
  `SceneControllerSceneViewRenderState.captureFrameRead()` for
  `selectionRevision`.
- Structural tests proving Slice 3.5 must require
  `SceneControllerSelectedPaintOrderCache` fast-return when
  `selectionRevision` and `structuralRevision` are unchanged, before any
  selected-id iteration, order-resolution callback, or token sorting begins.
- Benchmark ownership tests must distinguish the exact cases
  `selection_path_painter_only`,
  `selection_path_candidate_staging`, and
  `selection_path_end_to_end_paint`; they must reject using
  `_BenchmarkControllerRenderState`, a benchmark-only stage owner, or an
  injected prepared-plan provider for
  `selection_path_candidate_staging` and
  `selection_path_end_to_end_paint`.
- Benchmark ownership tests must prove
  `selection_path_candidate_staging` and
  `selection_path_end_to_end_paint` run with identity-equal active and
  committed snapshots, hit
  `SceneControllerPaintCandidateStage.prepareCommittedPaintPlan(...)`, and do
  not fall back to `enumerateSnapshotPaintCandidates(...)`.
- Tool tests must reject any `smoke` or `full` profile configuration or diff
  surface that omits or renames any required operation of
  `selection_path_painter_only`,
  `selection_path_candidate_staging`, or
  `selection_path_end_to_end_paint`.
- Workflow verification tests must reject moving the smoke benchmark run out of
  `.github/workflows/ci.yaml` or moving the full benchmark run out of
  `.github/workflows/perf_nightly.yaml`.
- Metric-schema tests must reject publishing percentile metrics from smoke
  policy.
- Structural tests proving the memoization boundary must reject any retained
  cross-frame prepared-plan state, filtered candidate-list state, or other
  committed-frame staging artifacts in any committed paint-path owner outside
  test-only counters, including
  `scene_controller_scene_view_runtime.dart`,
  `scene_controller_paint_candidate_stage.dart`, and
  `scene_controller_selected_paint_order_cache.dart`.

### Required Test Strategy

- Behavioral tests must cover committed paint-plan ownership, canonical
  ordinary ordering, ordered supplement merge, selection-invalidation
  behavior, and benchmark-case semantics.
- Architecture-relevant slices must run
  `test/interactive/core/scene_controller_architecture_boundary_test.dart` as
  structural verification for boundary drift.
- Slice 3.5 must also run
  `test/tool/guardrails/guardrails_controller_api_tool_test.dart` so sealed
  controller-surface and sealed helper-surface drift are caught mechanically.
- Benchmark and tooling slices must run the benchmark tool tests plus
  invariant coverage plus workflow verification checks as structural
  verification for taxonomy, metric-schema, workflow, and documentation drift.
- Negative scenarios must be executable and must prove forbidden fallback
  shapes fail mechanically, not just by prose review.
- Slice order is fixed: prepared-plan ownership closes before shared ordering,
  shared ordering closes before ordered supplement merge, ordered supplement
  merge closes before committed selection-membership invalidation, and perf
  tooling/docs close only after runtime slices are green.

### Prohibited

- Do not keep painter-side defensive candidate copying in the committed hot
  path after Slice 1 closes.
- Do not leave canonical ordinary ordering as a caller-side repair step after
  Slice 2 closes.
- Do not satisfy Slice 2 by materializing unordered ordinary paint candidates
  and performing a final query-result repair sort inside or above the shared
  paint-query source. Ordering admitted spatial ids by the current committed
  node locator before candidate materialization is the intended bounded path.
- Do not keep a committed fast-path global repair sort after Slice 3 closes.
- Do not derive canonical selected order or retain any cross-frame selected
  candidate lists, filtered supplement lists, or prepared paint plans outside
  `scene_controller_selected_paint_order_cache.dart` after Slice 3 closes.
- Do not implement Slice 3.5 by using selected-set object identity,
  frame-read identity, `commitRevision`, `controllerEpoch`, live
  post-capture controller reads, or recompute-and-compare token rebuilding as
  the committed selected-order cache invalidation key.
- Do not implement Slice 3.5 by widening `SceneStoreController` public or
  sealed surface, by extending `SceneStoreControllerSpatialAccess`, by routing
  production reads through `SceneStoreController.debug`, or by introducing a
  secondary adapter/access owner for `selectionRevision`.
- Do not add a second committed selection-membership revision owner outside
  controller-owned committed state.
- Do not retain any cross-frame prepared plans, ordinary candidate sequences,
  filtered supplement lists, or other committed-frame staging artifacts inside
  any committed paint-path owner outside test-only counters, including
  `scene_controller_scene_view_runtime.dart`,
  `scene_controller_paint_candidate_stage.dart`, or
  `scene_controller_selected_paint_order_cache.dart`.
- Do not reintroduce a second benchmark-only render-state for a benchmark case
  that is declared as production candidate staging.
- Do not wire `selection_path_candidate_staging` or
  `selection_path_end_to_end_paint` through divergent snapshot fallback or
  `enumerateSnapshotPaintCandidates(...)`.
- Do not add cross-frame viewport memoization or a second committed paint-plan
  cache owner in this step.
- Do not publish percentile metrics from smoke policy.

### Optional: Recognition Forms That Must Be Supported

- ordinary committed viewport candidate;
- selected-node supplement admitted only through `visibilityRect`;
- divergent active-frame snapshot fallback candidate;
- `selection_path_candidate_staging` benchmark case;
- `selection_path_painter_only` benchmark case;
- `selection_path_end_to_end_paint` benchmark case.

### Optional: Allowed Forms That Are Not Violations

- Divergent frame-snapshot enumeration may continue to linearly enumerate
  arbitrary snapshots through `enumerateSnapshotPaintCandidates(...)`.
- Selected-node supplements may continue to compute preview-adjusted paint
  bounds after ordered node-location resolution.
- Hit-test query ordering and hit-test query payload semantics may remain
  unchanged.
- Smoke profiles keep non-percentile latency and RSS metrics only.

## 9. Vertical Slices

Rules:
- one slice closes one new verifiable result;
- every slice must have behavioral verification;
- every architecture-relevant slice must have structural verification;
- preparatory edits alone do not close a slice.

### Slice 1. [x] Establish the controller-owned prepared paint-plan boundary

#### Slice Contract

Committed render frames consume one controller-owned prepared paint plan, and
painter-side modules stop owning defensive candidate packaging.

#### Change

- In `lib/src/contract/scene_view_render_state.dart`, introduce one internal
  prepared-plan contract for committed paint frames and replace the current
  `Iterable<ScenePaintCandidate>` handoff with that prepared-plan contract.
- The prepared-plan contract for Slice 1 must be one immutable indexed owner
  that exposes ordered candidate count plus indexed candidate access. It must
  not expose a growable candidate collection or a lazy iterable as the primary
  committed handoff surface.
- Add `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart`
  as the single controller-owned owner of committed paint-plan preparation.
- Change `SceneControllerSceneViewRenderState` in
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` to
  delegate committed paint-plan preparation to that owner while preserving the
  current selected-supplement behavior and current divergent active-frame
  fallback behavior.
- The committed branch in `SceneControllerSceneViewRenderState` must call
  exactly one
  `SceneControllerPaintCandidateStage.prepareCommittedPaintPlan(...)` entry
  point on every committed-frame execution and must not assemble or reuse
  committed background/content/supplement prepared-plan contents outside
  `scene_controller_paint_candidate_stage.dart`.
- Change `ScenePainterFrameOwner` and `ScenePainterNodeRenderer` to consume the
  prepared plan by indexed staged access instead of wrapping candidates in
  `List<ScenePaintCandidate>.unmodifiable(...)`.
- Keep the Slice 1 committed stage allowed to use the current repair-order
  strategy so this slice changes ownership and copy behavior only.

#### Behavioral Verification

- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios

- A committed paint frame still resolves geometry only for staged visible
  candidates.
- A divergent active-frame snapshot still paints from the frame snapshot rather
  than the committed controller snapshot.

#### Negative Scenarios

- `ScenePainterFrameOwner.create(...)` no longer contains
  `List<ScenePaintCandidate>.unmodifiable(`.
- Painter-side code no longer owns candidate materialization from a lazy
  `Iterable<ScenePaintCandidate>`.
- The committed branch in `SceneControllerSceneViewRenderState` no longer
  assembles committed prepared-plan contents outside the stage owner.

#### Closure Evidence

- Green run of the listed verifications.
- Structural assertion proving the committed frame owner no longer performs the
  defensive candidate copy.
- Structural assertion proving the committed branch delegates through one exact
  stage-owner entry point.
- Structural assertion proving no second committed prepared-plan reuse owner
  exists in the committed branch outside the stage owner.

### Slice 2. [x] Promote canonical ordinary paint order into the shared paint-query source

#### Slice Contract

Ordinary committed paint candidates returned by the shared paint-query source
already follow canonical scene order for background and content nodes while
preserving candidate-bounded spatial-query cost for grid-backed viewport
queries.

#### Change

- In `lib/src/core/scene_spatial_index.dart`, change the paint-query path so
  ordinary committed paint candidates are emitted in canonical scene order
  rather than as an unordered candidate-id collection that requires caller-side
  repair sorting.
- Slice 2 must derive ordinary paint order inside the shared paint-query owner
  itself. It is not allowed to leave unordered ordinary query output in place
  and repair the order with a final query-result sort.
- The grid-backed fast path must not restore order by traversing every
  committed scene node after spatial admission has already produced the
  candidate set; order restoration must stay bounded to admitted spatial
  candidates and use the current committed node locator as the single topology
  source of truth.
- `SceneSpatialIndex` owns ordered paint-query output, but it must not create a
  second retained paint-order cache. Paint cells and entries own spatial
  admission data only; current `(layerIndex, nodeIndex)` order comes from the
  committed node locator already bound to the index.
- Preserve current `ScenePaintSpatialQueryScope` semantics and preserve
  identical background/content order semantics under both grid-backed and
  linear-fallback paint queries.
- Thread the ordered ordinary paint-query contract through
  `lib/src/controller/internal/spatial_index_cache.dart` and
  `lib/src/controller/scene_store_controller.dart` without changing hit-test
  payload or hit-test ordering semantics.
- Allow the controller-owned paint-candidate stage to treat ordinary committed
  paint-query results as already ordered input after this slice closes.
- `SpatialIndexCache`, `SceneStoreController`, and
  `SceneControllerPaintCandidateStage` must not repair-sort, re-bucket, or
  reorder ordinary committed query results after `queryPaintCandidates(...)`.

#### Behavioral Verification

- `flutter test test/core/scene_spatial_index_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios

- Ordinary background candidates are emitted before content candidates.
- Ordinary content candidates remain ordered by `(layerIndex, nodeIndex)`.
- Large-query fallback and linear paint fallback keep the same canonical order
  as the fast path.

#### Negative Scenarios

- The ordinary committed paint-query source is not allowed to return candidates
  in cell-collection order.
- The ordinary committed paint-query source is not allowed to perform a full
  committed-scene traversal only to restore grid-backed candidate order.
- Incremental insertions or removals before retained nodes must not leave
  retained paint candidates ordered by stale pre-commit locations.
- The spatial index must not duplicate committed topology by storing a second
  retained `(layerIndex, nodeIndex)` order cache in paint spatial entries.
- Hit-test query behavior does not change as a side effect of the paint-order
  work.
- No layer above `SceneSpatialIndex` repairs ordinary committed paint order
  after `queryPaintCandidates(...)`.

#### Closure Evidence

- Green run of the listed verifications.
- Regression assertions proving canonical ordinary ordering at the shared
  paint-query source.
- Regression assertions proving grid-backed ordinary paint order does not
  require traversing noncandidate scene layers.
- Regression assertions proving retained paint candidates follow the current
  node locator after incremental structural commits.
- Structural assertions proving no caller-side ordinary-order repair survives
  above `SceneSpatialIndex`.

### Slice 3. [x] Replace global repair sorting with ordered supplement merge

#### Slice Contract

The committed fast path merges ordered ordinary candidates and ordered selected
supplements linearly, dedupes once, and no longer performs a per-frame global
repair sort.

#### Change

- Add `lib/src/interactive/internal/scene_controller_selected_paint_order_cache.dart`
  as the single owner of committed selected-node ordering for paint
  supplements.
- Make the selected-order cache rebuild only when committed selection
  membership changes or committed node-location order changes.
- `SceneControllerSelectedPaintOrderCache` must store only committed selected-
  node order tokens derived from the committed node locator, or equivalent
  `(layerIndex, nodeIndex)` order records. It must not retain cross-frame
  candidate lists, filtered supplement lists, or prepared paint plans.
- Change `SceneControllerPaintCandidateStage` so selected-node supplements are
  produced from the ordered selected-node cache, admitted through
  `visibilityRect`, and linearly merged with the already ordered ordinary
  paint-query output.
- Keep supplement dedupe in the stage owner and keep divergent active-frame
  fallback unchanged.
- `SceneControllerPaintCandidateStage` may filter by `visibilityRect`, dedupe,
  and merge, but it must not derive canonical selected order or sort selected
  supplements after consuming the selected-order cache.
- Add deterministic test-only debug counters on the stage owner for
  selected-order-cache rebuilds, stage-buffer reuse, and committed fast-path
  global-sort avoidance.
- Slice 3 verification must prove with those counters that repeated committed
  frames with unchanged selection membership and unchanged committed
  node-location order do not rebuild the selected-order cache, while changing
  either input rebuilds it exactly once.

#### Behavioral Verification

- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios

- A selected background supplement admitted only through `visibilityRect`
  preserves canonical background order.
- A selected content supplement admitted only through `visibilityRect`
  preserves canonical content order.
- An ordinary candidate that is also selected is emitted once.
- Repeated committed frames with unchanged selection membership and unchanged
  committed node-location order leave the selected-order-cache rebuild counter
  unchanged.

#### Negative Scenarios

- The committed fast path no longer performs a final global `.sort(` over the
  ordinary-plus-supplement sequence.
- Supplement ordering does not depend on `Set<NodeId>` iteration order.
- The selected-order cache does not retain any cross-frame filtered supplement
  lists or prepared paint plans.
- Stable committed frames do not increment the selected-order-cache rebuild
  counter.

#### Closure Evidence

- Green run of the listed verifications.
- Structural assertion proving the committed stage no longer performs a final
  global repair sort.
- Structural assertions proving selected-order ownership stays in
  `SceneControllerSelectedPaintOrderCache` and the committed stage does not
  retain cross-frame supplement lists or prepared plans.
- Counter-backed assertions proving stable committed frames do not rebuild the
  selected-order cache and that each invalidating change rebuilds it exactly
  once.

### Slice 3.5. [x] Seal committed selected-order invalidation on atomically captured selectionRevision

#### Slice Contract

Committed selected-order caching is invalidated only by one controller-owned
committed `selectionRevision` plus committed `structuralRevision`, with
`selectionRevision` captured atomically inside `SceneViewFrameRead`, and
stable committed frames perform zero selected-order recomputation work.

#### Change

- Add one internal monotonic `selectionRevision` field to committed controller
  state in `lib/src/controller/store.dart`.
- Thread that exact `selectionRevision` through
  `lib/src/controller/committed_store_state.dart`,
  `lib/src/controller/scene_controller_commit_plan.dart`,
  and `lib/src/controller/scene_controller_commit_execution.dart` as
  controller-owned committed state only.
- Add one exact internal `selectionRevision` getter to
  `lib/src/controller/scene_store_controller.dart`. This is the only allowed
  sealed-surface expansion for Slice 3.5.
- Update
  `tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart`
  and `test/tool/guardrails/guardrails_controller_api_tool_test.dart` so that
  exact getter is allowed and any other `SceneStoreController` or
  `SceneStoreControllerSpatialAccess` growth still fails mechanically.
- Extend `SceneViewFrameRead` in
  `lib/src/contract/scene_view_render_state.dart` with one internal
  `selectionRevision` field so committed frame capture keeps selection
  membership invalidation atomic with `snapshot`, `selectedNodeIds`, and the
  preview resolver.
- `SceneControllerSceneViewRenderState.captureFrameRead()` in
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
  must be the only production boundary allowed to capture committed
  `selectionRevision`, and it must capture that value from
  `SceneStoreController.selectionRevision` in the same frame-read object as
  `snapshot` and `selectedNodeIds`.
- `SceneControllerSceneViewRenderState.preparePaintPlan(...)` and
  `SceneControllerPaintCandidateStage.prepareCommittedPaintPlan(...)` must use
  only `frameRead.selectionRevision` on the committed branch. They must not
  read a live `selectionRevision` after frame capture.
- Increment `selectionRevision` exactly when committed selection membership
  changes. It must not change for bounds-only, visual-only, structural-only,
  signal-only, repaint-only, no-op, rollback, or failed-write paths unless
  committed selection membership also changes.
- `SceneControllerSelectedPaintOrderCache` in
  `lib/src/interactive/internal/scene_controller_selected_paint_order_cache.dart`
  must use only `(selectionRevision, structuralRevision)` as its invalidation
  key for committed selected-order tokens.
- `SceneControllerSelectedPaintOrderCache` must return its cached ordered-token
  result immediately when both revisions are unchanged. That fast-return must
  happen before selected-id iteration, before any order-resolution callback,
  and before any token sorting.
- `SceneControllerSelectedPaintOrderCache` must rebuild ordered selected tokens
  exactly once when `selectionRevision` changes and exactly once when
  `structuralRevision` changes while `selectionRevision` is stable.
- Slice 3.5 must not widen the sealed `SceneStoreController` surface beyond
  that one exact `selectionRevision` getter, must not extend
  `SceneStoreControllerSpatialAccess`, must not route production reads through
  `SceneStoreController.debug`, and must not introduce a secondary
  adapter/access owner for `selectionRevision`.
- Add deterministic test-only debug counters that separately prove cache
  rebuilds and stable fast-return hits.
- Slice 3.5 must not widen the public package surface. No new public getter,
  public API contract, or public `SceneViewRenderState` member is allowed for
  `selectionRevision` in this step.

#### Behavioral Verification

- `flutter test test/controller/core/scene_controller_commit_atomicity_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`

#### Positive Scenarios

- A committed selection mutation increments `selectionRevision` exactly once.
- A committed structural mutation that preserves selection membership leaves
  `selectionRevision` unchanged and still invalidates selected-order caching
  through `structuralRevision`.
- Repeated committed frames with unchanged `selectionRevision` and unchanged
  `structuralRevision` hit the selected-order cache fast-return path and do not
  iterate selected ids.
- A committed frame after selection replacement rebuilds ordered selected tokens
  exactly once.

#### Negative Scenarios

- Stable committed frames must not rebuild selected-order tokens through
  recompute-and-compare logic.
- Stable committed frames must not call the selected-order location resolver.
- The selected-order cache must not use selected-set object identity,
  frame-read identity, `commitRevision`, `controllerEpoch`, or live
  post-capture controller reads as an
  invalidation key.
- `selectionRevision` must not leak into the public package surface, a
  `debug`-named production path, `SceneStoreControllerSpatialAccess`, or any
  widened `SceneStoreController` API surface beyond the one exact sanctioned
  getter.

#### Closure Evidence

- Green run of the listed verifications.
- Controller-level assertions proving `selectionRevision` monotonicity and
  exact increment semantics for selection-changing versus non-selection
  commits.
- Counter-backed assertions proving stable committed frames hit selected-order
  cache fast-return without selected-id iteration, order resolution, or token
  sorting.
- Structural assertions proving `selectionRevision` stays controller-owned,
  is delivered to the committed paint path only through the
  exact `SceneStoreController.selectionRevision` getter plus
  `SceneViewFrameRead`, with no live `_storeController.selectionRevision` read
  outside `captureFrameRead()`, and
  selected-order invalidation does not fall back to identity heuristics,
  post-capture live reads, or recompute-and-compare logic.

### Slice 4. [x] Seal the performance contract, benchmark taxonomy, and release documentation

#### Slice Contract

Repository performance tooling measures the production staging owner
explicitly, and benchmark policy can no longer publish statistically
misleading percentile metrics.

#### Change

- In `tool/bench/load_profiles_cases_test.dart`, define and keep these exact
  benchmark cases and operations:
  `selection_path_painter_only` with `paint_no_selection` and
  `paint_with_selection`,
  `selection_path_candidate_staging` with `stage_no_selection` and
  `stage_with_selection`, and
  `selection_path_end_to_end_paint` with `paint_no_selection` and
  `paint_with_selection`.
- `selection_path_candidate_staging` must measure the ordinary production
  committed staging path through `SceneControllerSceneViewRenderState` and
  `SceneControllerPaintCandidateStage` with identity-equal active and committed
  snapshots, and it must hit
  `SceneControllerPaintCandidateStage.prepareCommittedPaintPlan(...)`. It is
  not allowed to use
  `_BenchmarkControllerRenderState`, a benchmark-only stage owner, or an
  injected prepared-plan provider, and it must not fall back to
  `enumerateSnapshotPaintCandidates(...)`.
- `selection_path_end_to_end_paint` must measure that same production staging
  path plus painter execution. Only `selection_path_painter_only` may continue
  to use synthetic benchmark-only state.
- The exact cases
  `selection_path_painter_only`,
  `selection_path_candidate_staging`, and
  `selection_path_end_to_end_paint` with their exact operations must remain in
  the required case set and comparison output for both `smoke` and `full`
  profiles.
- After slices 1 through 3.5 close, regenerate `smoke` and `full` benchmark
  reports against the finalized runtime contract and intentionally refresh
  `tool/bench/baselines/load_profiles_smoke_baseline.json` and
  `tool/bench/baselines/load_profiles_full_baseline.json` to that finalized
  case set, operations, and metric schema. If regenerated baseline artifacts
  are byte-for-byte unchanged, closure evidence must still record that they
  were revalidated against the finalized contract shape.
- In `tool/bench/load_profile_policy.dart` and
  `tool/bench/diff_load_profiles.dart`, make smoke policy reject percentile
  metrics entirely and keep heavier percentile reporting on the full policy
  path only.
- Update `test/tool/bench_run_load_profiles_test.dart` and
  `test/tool/bench_diff_load_profiles_test.dart` so benchmark taxonomy and
  metric-schema drift fail in-repo.
- Update `tool/check_verification_contract.dart`,
  `tool/src/verification_contract/**`, and
  `test/tool/verification_contract_tool_test.dart` so workflow verification
  also rejects moving the smoke benchmark run out of
  `.github/workflows/ci.yaml` or moving the full benchmark run out of
  `.github/workflows/perf_nightly.yaml`.
- Keep `.github/workflows/ci.yaml` as the smoke-profile PR perf gate and keep
  `.github/workflows/perf_nightly.yaml` as the full-profile schedule/manual
  perf gate. If workflow edits are required, they must preserve that exact
  split.
- Update `tool/invariant_registry.dart`, `README.md`, `API_GUIDE.md`,
  `ARCHITECTURE.md`, `CHANGELOG.md`, this step document, and `PLAN.md` only
  after slices 1 through 3.5 are closed.

#### Behavioral Verification

- `flutter test tool/bench/load_profiles_cases_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/verification_contract_tool_test.dart`
- `dart run tool/check_verification_contract.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Positive Scenarios

- The repository reports a dedicated production candidate-staging benchmark
  case named `selection_path_candidate_staging`.
- The repository reports the exact companion cases
  `selection_path_painter_only` and `selection_path_end_to_end_paint`.
- `selection_path_candidate_staging` and
  `selection_path_end_to_end_paint` run through the committed staging branch,
  not the divergent snapshot fallback path.
- Checked-in `smoke` and `full` baseline JSONs reflect the finalized required
  cases, required operations, and finalized metric schema.
- Smoke policy publishes no percentile metrics.
- Full policy continues to publish the heavier perf profile data.

#### Negative Scenarios

- A production candidate-staging benchmark case is not allowed to use
  `_BenchmarkControllerRenderState`.
- A production candidate-staging benchmark case is not allowed to use a
  benchmark-only stage owner or an injected prepared-plan provider.
- `selection_path_end_to_end_paint` is not allowed to bypass the production
  staging owner and jump directly to painter-only state.
- `selection_path_candidate_staging` and
  `selection_path_end_to_end_paint` are not allowed to route through
  divergent snapshot fallback or `enumerateSnapshotPaintCandidates(...)`.
- `smoke` and `full` are not allowed to omit any of the exact required
  selection-path benchmark cases or rename or omit any of their required
  operations from case registration or diff output.
- Checked-in benchmark baselines are not allowed to lag an older case set,
  operation set, or superseded smoke/full metric schema after Slice 4 closes.
- Smoke policy is not allowed to publish `p95*` metrics.

#### Closure Evidence

- Green run of the listed verifications.
- Tool-test diagnostics proving benchmark-owner drift and invalid percentile
  schema are rejected in-repo.
- Tool-test diagnostics proving exact benchmark case names and benchmark-owner
  wiring drift are rejected in-repo.
- Tool-test diagnostics proving required case-set or diff-surface omissions are
  rejected in-repo, including omitted or renamed required operations.
- Workflow-verification diagnostics proving the smoke benchmark remains on
  `.github/workflows/ci.yaml` and the full benchmark remains on
  `.github/workflows/perf_nightly.yaml`.
- Updated or explicitly revalidated
  `tool/bench/baselines/load_profiles_smoke_baseline.json` and
  `tool/bench/baselines/load_profiles_full_baseline.json`, plus a short
  before/after summary of the finalized required-case metrics they encode.

## 10. Final Verification

- `flutter test test/controller/core/scene_controller_commit_atomicity_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/core/scene_spatial_index_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/verification_contract_tool_test.dart`
- `dart run tool/check_verification_contract.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<path-or->`

## 11. Acceptance Criteria

- The change mandate is satisfied.
- The surrounding code review records actual repository evidence.
- The architectural form is explicit, justified, and locked at the correct
  level.
- No material architectural choice remains to the implementing agent.
- Result requirements are satisfied.
- Implementation rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
