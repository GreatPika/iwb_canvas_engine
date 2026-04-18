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

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/controller/internal/spatial_index_cache.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart`
- `lib/src/interactive/internal/scene_controller_selected_paint_order_cache.dart`
- `lib/src/render/scene_painter_contract.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/render/scene_painter_node_renderer.dart`
- `tool/bench/load_profile_policy.dart`
- `tool/bench/load_profiles_cases_test.dart`
- `tool/bench/diff_load_profiles.dart`
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
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/bench_diff_load_profiles_test.dart`
- `tool/bench/load_profiles_cases_test.dart`

### Fixture and Supporting Data Files

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

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

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

## 5. Result Requirements

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
14. Checked-in benchmark baselines for `smoke` and `full` intentionally match
    the finalized contract shape, required case set, required operations, and
    metric schema after Slice 4 closes.

## 6. Implementation Specification

### 6.1 Analysis Scope

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

### 6.2 Target Verification Units

- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/core/scene_spatial_index_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<path-or->`

### 6.3 Protected States, Data, or Structures

- `SceneViewFrameRead` remains the single atomic frame-read capture reused
  across background paint, candidate staging, preview resolution, and node
  paint.
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
- No committed paint-path owner outside test-only counters, including
  `scene_controller_scene_view_runtime.dart`, may retain cross-frame prepared
  plans, candidate sequences, supplement lists, or other committed staging
  artifacts.
- Background/content order semantics stay identical to the committed scene
  order already encoded by `layerIndex` and `nodeIndex`.
- Hit-test admission remains independent from committed paint-candidate
  staging.

### 6.4 Allowed Semantic Change Zones

- Internal read-side paint-plan contract shape.
- Controller-owned committed paint-candidate stage ownership.
- Selected-node supplement ordering and deduplication behavior.
- Shared paint-query ordering behavior for ordinary committed candidates.
- Benchmark case taxonomy, metric schema, and workflow expectations.
- Invariant wording, architecture wording, and release-ready documentation for
  the sealed paint-staging contract.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- ordinary committed viewport candidate;
- selected-node supplement admitted only through `visibilityRect`;
- divergent active-frame snapshot fallback candidate;
- `selection_path_candidate_staging` benchmark case;
- `selection_path_painter_only` benchmark case;
- `selection_path_end_to_end_paint` benchmark case.

### 6.6 Allowed Forms That Do Not Count as Violations

- Divergent frame-snapshot enumeration may continue to linearly enumerate
  arbitrary snapshots through `enumerateSnapshotPaintCandidates(...)`.
- Selected-node supplements may continue to compute preview-adjusted paint
  bounds after ordered node-location resolution.
- Hit-test query ordering and hit-test query payload semantics may remain
  unchanged.
- Smoke profiles keep non-percentile latency and RSS metrics only.

### 6.7 Requirements for Resolution of Links and Structural Analysis

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
  outside
  `scene_controller_paint_candidate_stage.dart`.
- Structural tests proving Slice 3 must inspect the committed staging owner and
  reject a committed fast-path global `.sort(` on the final ordinary-plus-
  supplement candidate sequence.
- Structural tests proving Slice 2 must inspect the shared paint-query source
  and reject a query-level global repair sort over unordered ordinary paint
  candidates.
- Structural tests proving Slice 2 must reject ordinary-order repair in
  `spatial_index_cache.dart`, `scene_store_controller.dart`, and
  `scene_controller_paint_candidate_stage.dart` after
  `queryPaintCandidates(...)`.
- Structural tests proving Slice 3 must reject selected-order derivation or
  selected-supplement sorting outside
  `scene_controller_selected_paint_order_cache.dart`.
- Structural tests proving Slice 3 must reject retaining any cross-frame
  selected candidate lists, filtered supplement lists, or prepared plans inside
  `scene_controller_selected_paint_order_cache.dart`.
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
- Metric-schema tests must reject publishing percentile metrics from smoke
  policy.
- Structural tests proving the memoization boundary must reject any retained
  cross-frame prepared-plan state, filtered candidate-list state, or other
  committed-frame staging artifacts in any committed paint-path owner outside
  test-only counters, including
  `scene_controller_scene_view_runtime.dart`,
  `scene_controller_paint_candidate_stage.dart`, and
  `scene_controller_selected_paint_order_cache.dart`.

### 6.8 Prohibited

- Do not keep painter-side defensive candidate copying in the committed hot
  path after Slice 1 closes.
- Do not leave canonical ordinary ordering as a caller-side repair step after
  Slice 2 closes.
- Do not satisfy Slice 2 by collecting unordered ordinary paint candidates and
  performing a query-level global repair sort inside the shared paint-query
  source.
- Do not keep a committed fast-path global repair sort after Slice 3 closes.
- Do not derive canonical selected order or retain any cross-frame selected
  candidate lists, filtered supplement lists, or prepared paint plans outside
  `scene_controller_selected_paint_order_cache.dart` after Slice 3 closes.
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

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must
   be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. The plan must be detailed enough that the implementing agent has no
   material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered
    valid.
11. Slice order is fixed: prepared-plan ownership closes before shared
    ordering, shared ordering closes before ordered supplement merge, and perf
    tooling/docs close only after the runtime slices are green.

## 8. Vertical Slices

### Slice 1. [ ] Establish the controller-owned prepared paint-plan boundary

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

#### Verification

- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
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

### Slice 2. [ ] Promote canonical ordinary paint order into the shared paint-query source

#### Slice Contract

Ordinary committed paint candidates returned by the shared paint-query source
already follow canonical scene order for background and content nodes.

#### Change

- In `lib/src/core/scene_spatial_index.dart`, change the paint-query path so
  ordinary committed paint candidates are emitted in canonical scene order
  rather than as an unordered candidate-id collection that requires caller-side
  repair sorting.
- Slice 2 must derive ordinary paint order inside the shared paint-query owner
  itself. It is not allowed to leave unordered ordinary query output in place
  and repair the order with a final query-result sort.
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

#### Verification

- `flutter test test/core/scene_spatial_index_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios

- Ordinary background candidates are emitted before content candidates.
- Ordinary content candidates remain ordered by `(layerIndex, nodeIndex)`.
- Large-query fallback and linear paint fallback keep the same canonical order
  as the fast path.

#### Negative Scenarios

- The ordinary committed paint-query source is not allowed to return candidates
  in cell-collection order.
- Hit-test query behavior does not change as a side effect of the paint-order
  work.
- No layer above `SceneSpatialIndex` repairs ordinary committed paint order
  after `queryPaintCandidates(...)`.

#### Closure Evidence

- Green run of the listed verifications.
- Regression assertions proving canonical ordinary ordering at the shared
  paint-query source.
- Structural assertions proving no caller-side ordinary-order repair survives
  above `SceneSpatialIndex`.

### Slice 3. [ ] Replace global repair sorting with ordered supplement merge

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

#### Verification

- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
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

### Slice 4. [ ] Seal the performance contract, benchmark taxonomy, and release documentation

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
- After slices 1 through 3 close, regenerate `smoke` and `full` benchmark
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
- Keep `.github/workflows/ci.yaml` as the smoke-profile PR perf gate and keep
  `.github/workflows/perf_nightly.yaml` as the full-profile schedule/manual
  perf gate. If workflow edits are required, they must preserve that exact
  split.
- Update `tool/invariant_registry.dart`, `README.md`, `API_GUIDE.md`,
  `ARCHITECTURE.md`, `CHANGELOG.md`, this step document, and `PLAN.md` only
  after slices 1 through 3 are closed.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`
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
- Updated or explicitly revalidated
  `tool/bench/baselines/load_profiles_smoke_baseline.json` and
  `tool/bench/baselines/load_profiles_full_baseline.json`, plus a short
  before/after summary of the finalized required-case metrics they encode.

## 9. Final Verification

- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/core/scene_spatial_index_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<path-or->`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
