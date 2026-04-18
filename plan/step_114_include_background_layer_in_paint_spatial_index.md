# Change Contract

## 1. Change Mandate

- This change fixes committed-frame background paint admission so ordinary
  `backgroundLayer` nodes stop incurring a linear per-frame scan while staying
  on one closed shared committed spatial read path.

## 2. Change Boundary

### Included in the Change

- Add a required background-heavy benchmark case that measures the committed
  render path affected by this issue.
- Extend the existing `SceneSpatialIndex` owner so its paint admission role can
  admit committed background nodes under an explicit paint-query scope.
- Keep hit-test admission content-only and isolate hit-test fast-path validity
  from background-only paint admission failures.
- Thread the scoped paint query through `SpatialIndexCache`,
  `SceneStoreController`, and the committed renderer path.
- Close the controller committed query/resolve surface so background candidates
  returned by the controller can be resolved by the paired committed helper.
- Remove the committed ordinary background linear scan from
  `_enumerateCommittedSnapshotPaintCandidates`.
- Tighten guardrails and release-ready documentation so the corrected contract
  is enforced in-repo.

### Not Included in the Change

- Do not introduce a second spatial index, a background-only spatial index, or
  a background-only candidate-bounds cache.
- Do not include `backgroundLayer` nodes in hit-test admission.
- Do not change eraser eligibility, move hit-test behavior, marquee selection
  behavior, selection normalization, write APIs, JSON format, or public
  exports.
- Do not replace divergent active-frame fallback enumeration with committed
  spatial reads.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/scene_spatial_index.dart`
- `lib/src/controller/internal/spatial_index_cache.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `tool/bench/load_profile_policy.dart`
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`

### Test Files

- `test/core/scene_spatial_index_test.dart`
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/bench_diff_load_profiles_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `tool/bench/load_profiles_cases_test.dart`

### Fixture and Supporting Data Files

- `test/tool/support/guardrails_tool_test_support.dart`
- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`

### Analysis Area

- `lib/src/core/**`
- `lib/src/controller/**`
- `lib/src/interactive/internal/**`
- `lib/src/render/**`
- `test/core/**`
- `test/controller/**`
- `test/render/**`
- `test/interactive/core/**`
- `test/tool/**`
- `tool/bench/**`

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

1. This step uses one shared `SceneSpatialIndex` owner. The fix is not allowed
   to introduce a second background-specific index or cache owner.
2. `backgroundLayer` participates only in the paint admission role. Hit-test
   admission remains content-layer-only.
3. The paint-query API name is `ScenePaintSpatialQueryScope`, and the scope has
   exactly two values: `contentLayersOnly` and
   `backgroundAndContentLayers`.
4. `SceneSpatialIndex.queryPaintCandidates(...)`,
   `SpatialIndexCache.writeQueryPaintCandidates(...)`, and
   `SceneStoreController.queryPaintCandidates(...)` default to
   `ScenePaintSpatialQueryScope.contentLayersOnly`.
5. Controller-backed committed ordinary paint enumeration uses
   `ScenePaintSpatialQueryScope.backgroundAndContentLayers`.
6. `backgroundLayer` locations continue to use `layerIndex == -1` with the
   existing `nodeIndex` semantics from the node locator.
7. Divergent active-frame enumeration remains the only linear background path
   and remains authoritative when `frameRead.snapshot` is not identical to
   `SceneStoreController.snapshot`.
8. The first slice is measurement closure: the step is not allowed to change
   the runtime path before the repository has a required background-heavy
   benchmark case for this issue.
9. The committed renderer fast path must resolve ordinary committed candidates
   through the paired committed resolver
   `resolveSpatialCandidateSnapshot(...)`, not through an unrelated
   node-id-only lookup.
10. Exact sealed-signature enforcement for committed read helpers must preserve
    parameter kind and default semantics, not only parameter name and type.

## 5. Result Requirements

1. The repository defines a required benchmark case for committed background
   paint admission, and the benchmark case is part of the required case set for
   every supported load-profile policy.
2. A committed ordinary background node whose paint bounds overlap the viewport
   is returned by `SceneSpatialIndex.queryPaintCandidates(...)` only when
   `scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers` is used.
3. `SceneSpatialIndex.build(scene)` without an explicit `nodeLocator` still
   admits current committed background nodes for scoped paint queries.
4. The same background node is not returned by default content-only paint
   queries.
5. The same background node is not returned by hit-test spatial queries.
6. A background-only paint admission anomaly, including out-of-range paint
   bounds, does not disable content hit-test grid fast paths for otherwise
   valid content nodes.
7. `SceneStoreController.queryPaintCandidates(...)` can return ordinary
   background candidates, and
   `SceneStoreController.resolveSpatialCandidateSnapshot(...)` resolves those
   current committed background candidates while still rejecting stale and
   out-of-range candidates.
8. `_enumerateCommittedSnapshotPaintCandidates` no longer linearly iterates
   ordinary `snapshot.backgroundLayer.nodes` in the committed fast path.
9. Ordinary committed background and content paint candidates are emitted in
   original paint order: all `layerIndex == -1` candidates in `nodeIndex`
   order, followed by content candidates ordered by `(layerIndex, nodeIndex)`.
10. Selected-node supplements admitted through `visibilityRect` remain deduped,
   remain ordered by their original location, and are emitted once.
11. Divergent active-frame fallback continues to enumerate background and
    content from the active frame snapshot without consulting committed spatial
    state.
12. Guardrails reject committed helper signatures that promote an optional named
    parameter to required, remove a default value, or change a default value
    for the sealed read-side helper surface.
13. Repository-local invariants and documentation describe one coherent
    contract: shared committed paint admission includes background, hit-test
    admission excludes background, and the controller committed
    query/resolve surface is closed for every returned candidate shape.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Inspect `SceneControllerSceneViewRenderState.enumeratePaintCandidates(...)`
  and `_enumerateCommittedSnapshotPaintCandidates(...)` before changing the
  committed render path.
- Inspect `SceneStoreController.queryPaintCandidates(...)`,
  `SceneStoreController.resolveSpatialCandidateSnapshot(...)`, and
  `SceneStoreController.resolveSnapshotNodeById(...)` before changing the
  controller read-side surface.
- Inspect `SpatialIndexCache.writeQueryPaintCandidates(...)` before threading
  scope through controller-owned cache reads.
- Inspect `_rebuildSpatialIndex(...)`, `_upsertResolvedSpatialNode(...)`,
  `_placeSpatialEntry(...)`, `_queryLinearHitTest(...)`,
  `_queryLinearPaint(...)`, `_resolvePaintCandidates(...)`,
  `_resolveSpatialNodeById(...)`, `_buildNodeLocator(...)`, and
  `_visitResolvedNodes(...)` in
  `lib/src/core/scene_spatial_index.dart` before changing admission and
  invalidation behavior.
- Inspect `tool/bench/load_profile_policy.dart`,
  `tool/bench/load_profiles_cases_test.dart`,
  `test/tool/bench_run_load_profiles_test.dart`, and
  `test/tool/bench_diff_load_profiles_test.dart` before adding the benchmark
  case.
- Inspect exact sealed-signature checking in
  `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` and its
  sandbox fixtures before changing committed helper signatures.

### 6.2 Target Verification Units

- `flutter test test/core/scene_spatial_index_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<path-or->`

### 6.3 Protected States, Data, or Structures

- `SceneStore.nodeLocator` remains the committed node-location source and
  remains the source of `layerIndex == -1` background locations.
- `SceneSpatialIndex` remains the only committed coarse-admission owner.
- `ScenePaintSpatialCandidate` remains the paint-admission payload.
- `SceneHitTestSpatialCandidate` remains the hit-test admission payload.
- `SceneViewFrameRead.snapshot` remains the only authority for the divergent
  active-frame branch.
- `SceneControllerSceneViewRenderState` remains the only owner of committed
  ordinary paint-candidate ordering and selected-node supplement merging.

### 6.4 Allowed Semantic Change Zones

- background-heavy load-profile case definition and required-case policy;
- paint-role coarse admission inside `SceneSpatialIndex`;
- role-scoped validity and fallback behavior inside `SceneSpatialIndex`;
- controller committed paint-query and committed resolver surface;
- committed renderer ordinary paint admission and paint-order assembly;
- exact sealed-signature enforcement for committed read helpers;
- invariant and release-document wording for the corrected contract.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- ordinary committed background candidate with `layerIndex == -1`;
- ordinary committed content candidate with `layerIndex >= 0`;
- background-only paint admission failure caused by out-of-range paint bounds;
- divergent active-frame fallback enumeration;
- exact sealed-signature drift by optional-to-required named promotion;
- exact sealed-signature drift by default-value removal or change.

### 6.6 Allowed Forms That Do Not Count as Violations

- `enumerateSnapshotPaintCandidates(...)` may continue to linearly enumerate
  snapshot background and content nodes because it is the divergent
  active-frame authority.
- `lib/src/core/scene_snapshot_paint_candidates.dart` may continue to linearly
  enumerate arbitrary snapshots because it is outside the committed spatial
  identity contract.
- Selected-node supplements may continue to compute paint bounds linearly after
  the node is resolved and deduped because supplement widening remains
  visibility-rect-driven rather than viewport-spatial-index-driven.
- Content hit-test anomalies may continue to invalidate hit-test admission
  state where required by the existing safety contract.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Structural tests that prove committed background scanning removal must inspect
  the body of `_enumerateCommittedSnapshotPaintCandidates` in
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`.
- Those structural tests must require the positive marker
  `scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers` in the
  committed ordinary paint query call.
- Those structural tests must reject the negative marker
  `snapshot.backgroundLayer.nodes` in the committed ordinary paint path.
- Those structural tests must reject recomputing ordinary committed paint
  bounds through `_snapshotPaintBoundsWorld(`,
  `nodeSnapshotPaintBoundsWorld(`, or `nodePaintBoundsWorld(` inside the
  committed ordinary paint path.
- Structural tests that prove the architectural form must reject introducing
  `BackgroundSpatialIndex`, `SceneBackgroundSpatialIndex`,
  `BackgroundPaintCandidateCache`, `_backgroundPaintCells`, or
  `_backgroundLargePaintNodeIds` in `lib/src/**`.
- Guardrail regression tests must continue to use the sandbox fixtures in
  `test/tool/support/guardrails_tool_test_support.dart` so signature analysis
  is verified through the repository’s guardrail tool path instead of an ad hoc
  harness.

### 6.8 Prohibited

- Do not keep a single index-wide validity gate or a single index-wide fallback
  gate that both `queryHitTestCandidates(...)` and `queryPaintCandidates(...)`
  consult after background paint admission is added.
- Do not leave `SceneSpatialIndex` with one shared `_entriesById` store that
  requires paint-role invalidation to clear hit-test-role entries.
- Do not replace the exact split mandated by Slice 2 with a generic
  role-parameterized storage abstraction, a second owner class, or any other
  internal shape that is not the explicitly listed field and entry split.
- Do not keep `_visitResolvedNodes(...)` as the single traversal for both
  hit-test and paint-role admission once background paint admission is added.
- Do not leave `_buildNodeLocator(Scene scene)` content-only after scoped
  background paint admission is added.
- Do not let hit-test fallback enumerate `scene.backgroundLayer?.nodes`.
- Do not keep `SceneStoreController.resolveSpatialCandidateSnapshot(...)`
  hard-rejecting negative `layerIndex` values once controller paint queries can
  return background candidates.
- Do not let `_enumerateCommittedSnapshotPaintCandidates` resolve ordinary
  committed candidates through `resolveSnapshotNodeById(candidate.nodeId)`.
- Do not recompute ordinary committed paint bounds from the resolved snapshot
  node once the spatial query has already returned `candidate.paintBoundsWorld`.
- Do not use `_BenchmarkControllerRenderState` for the new
  background-heavy benchmark case. The benchmark must exercise
  `SceneControllerSceneViewRenderState`.
- Do not reopen the architectural choice between shared-index admission and a
  second background-only owner inside implementation.

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
9. The plan must be detailed enough that the implementing agent has no
   material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered valid.
11. If a slice depends on an unconfirmed architectural decision, planning must
    stop and that decision must be explicitly confirmed by the user before the
    slice can be written or expanded.

## 8. Vertical Slices

### Slice 1. [x] Add Background-Heavy Measurement Closure

#### Slice Contract

The repository has one required benchmark case that measures committed
background paint admission on the controller-owned render path, and the case is
part of the required load-profile policy for every supported profile.

#### Change

- In `tool/bench/load_profile_policy.dart`, add
  `background_layer_paint_admission` as a required case name and define its
  required operations as `enumerate_small_viewport` and
  `paint_small_viewport`.
- Do not introduce new profile-size constants. The benchmark case must derive
  its background node count from `policy.nodeCases.last.nodeCount` and its
  iteration count from `policy.nodeIterations`.
- In `tool/bench/load_profiles_cases_test.dart`, add one test named
  `load profile background-layer-paint profile=$profile`.
- Implement that benchmark case with a `SceneStoreController` plus
  `SceneControllerSceneViewRenderState`, not `_BenchmarkControllerRenderState`.
- The case must build a `SceneSnapshot` whose `backgroundLayer` contains
  `policy.nodeCases.last.nodeCount` `RectNodeSnapshot` nodes with ids `bg$i`,
  `size: const Size(8, 8)`, and
  `transform: Transform2D.translation(Offset((i % 500) * 32.0, (i ~/ 500) * 32.0))`.
- The benchmark helper must use
  `const ScenePaintCandidateQuery(viewportRect: Rect.fromLTWH(0, 0, 240, 160), visibilityRect: Rect.fromLTWH(-1, -1, 242, 162))`
  for `enumerate_small_viewport`.
- The benchmark helper must use `ScenePainter(controller: renderState, imageResolver: (_) => null)`
  and paint into `const Size(240, 160)` for `paint_small_viewport`.
- The case must measure exactly two operations:
  `enumerate_small_viewport` and `paint_small_viewport`.
- Update `test/tool/bench_run_load_profiles_test.dart` and
  `test/tool/bench_diff_load_profiles_test.dart` so the required case set and
  compared-case count include the new benchmark case.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`

#### Fixtures Used

- `tool/bench/load_profile_policy.dart`
- `tool/bench/load_profiles_cases_test.dart`

#### Positive Scenarios

- The smoke and full policies both report
  `background_layer_paint_admission` as a required benchmark case.
- The benchmark result for that case contains both
  `enumerate_small_viewport` and `paint_small_viewport`.
- The case runs through `SceneControllerSceneViewRenderState`.

#### Negative Scenarios

- Validation fails when `background_layer_paint_admission` is missing from the
  produced case set.
- Validation fails when the case omits one of the two required operations.
- The new benchmark case is not allowed to use `_BenchmarkControllerRenderState`.

#### Closure Evidence

- Green run of the listed verifications.
- `IWB_BENCH_RESULT` output includes
  `"name":"background_layer_paint_admission"` during the benchmark test run.

### Slice 2. [x] Add Scoped Background Paint Admission Inside SceneSpatialIndex

#### Slice Contract

`SceneSpatialIndex` admits ordinary background nodes for paint queries under an
explicit scope while background-only paint failures no longer poison content
hit-test fast paths.

#### Change

- In `lib/src/core/scene_spatial_index.dart`, add
  `enum ScenePaintSpatialQueryScope { contentLayersOnly, backgroundAndContentLayers }`.
- Change `SceneSpatialIndex.queryPaintCandidates(...)` to accept
  `{ScenePaintSpatialQueryScope scope = ScenePaintSpatialQueryScope.contentLayersOnly}`.
- Keep one `SceneSpatialIndex` owner type, but replace the current shared
  role state with this exact private split:
  `_isHitTestValid`, `_isPaintValid`,
  `_debugHitTestFallbackQueryCount`, `_debugPaintFallbackQueryCount`,
  `_hitTestEntriesById`, `_paintEntriesById`,
  `_hitTestCells`, `_paintCells`,
  `_largeHitTestNodeIds`, and `_largePaintNodeIds`.
- `_hitTestEntriesById` must have type
  `Map<NodeId, _HitTestSpatialEntry>`, `_paintEntriesById` must have type
  `Map<NodeId, _PaintSpatialEntry>`,
  `_hitTestCells` and `_paintCells` must both have type
  `Map<_CellKey, Set<NodeId>>`, and both large-node stores must have type
  `Set<NodeId>`.
- Introduce exactly two private entry owners:
  `_HitTestSpatialEntry(nodeId, hitTestBoundsWorld, hitTestCoveredCells, isLargeHitTest)`
  and
  `_PaintSpatialEntry(nodeId, paintBoundsWorld, paintCoveredCells, isLargePaint)`.
- Replace the shared invalidation helpers with this exact role split:
  `_markHitTestInvalid(...)`, `_markPaintInvalid(...)`,
  `_clearHitTestData(...)`, and `_clearPaintData(...)`.
- `_markHitTestInvalid(...)` must set only `_isHitTestValid = false` and must
  clear only hit-test-role data through `_clearHitTestData(...)`.
- `_markPaintInvalid(...)` must set only `_isPaintValid = false` and must clear
  only paint-role data through `_clearPaintData(...)`.
- `_clearHitTestData(...)` must clear only `_hitTestEntriesById`,
  `_hitTestCells`, and `_largeHitTestNodeIds`.
- `_clearPaintData(...)` must clear only `_paintEntriesById`, `_paintCells`,
  and `_largePaintNodeIds`.
- `debugLargeCandidateCount` must report the union of
  `_largeHitTestNodeIds` and `_largePaintNodeIds`.
- `debugCellCount` must report the union of hit-test and paint cell keys.
- Preserve the existing public `isValid` surface by reporting the conjunction of
  both role-validity flags, and preserve the existing public
  `debugFallbackQueryCount` surface by reporting the sum of both role fallback
  counters.
- `queryHitTestCandidates(...)` must consult only `_isHitTestValid`,
  `_debugHitTestFallbackQueryCount`, `_hitTestEntriesById`, `_hitTestCells`,
  and `_largeHitTestNodeIds`.
- `queryPaintCandidates(...)` must consult only `_isPaintValid`,
  `_debugPaintFallbackQueryCount`, `_paintEntriesById`, `_paintCells`, and
  `_largePaintNodeIds`.
- Replace `_visitResolvedNodes(...)` with two explicit traversals:
  `_visitResolvedContentNodes(...)` for hit-test admission and
  `_visitResolvedPaintableNodes(...)` for paint admission. The paint traversal
  must visit `scene.backgroundLayer?.nodes` first with `layerIndex: -1`, then
  content layers in existing order.
- `_buildNodeLocator(Scene scene)` must use
  `_visitResolvedPaintableNodes(...)` so `SceneSpatialIndex.build(scene)`
  without an external `nodeLocator` includes background locations for scoped
  paint queries.
- `_rebuildSpatialIndex(...)` must rebuild the hit-test role only from
  `_visitResolvedContentNodes(...)`, then rebuild the paint role only from
  `_visitResolvedPaintableNodes(...)`. A paint-role rebuild failure after a
  successful hit-test rebuild must call only `_markPaintInvalid(...)` and must
  preserve the hit-test role data and validity.
- `cloneForIncrementalUpdate(...)` and `applyIncremental(...)` must clone and
  mutate both role-specific stores, validity flags, and fallback counters under
  the same split. Incremental background paint failures must invalidate only
  the paint role.
- Change `_resolveSpatialNodeById(...)` so `layerIndex == -1` resolves from
  `scene.backgroundLayer?.nodes`.
- Keep hit-test fallback and hit-test role admission content-only.
- Make paint fallback and paint role admission include background nodes only
  when the explicit scope is `backgroundAndContentLayers`.
- Background paint-role failures must invalidate only the paint role. Content
  hit-test queries must continue using the hit-test role fast path when the
  hit-test role remains valid.

#### Verification

- `flutter test test/core/scene_spatial_index_test.dart`

#### Fixtures Used

- `test/core/scene_spatial_index_test.dart`

#### Positive Scenarios

- A scene with one overlapping background node and one overlapping content node
  returns both from `queryPaintCandidates(..., scope: backgroundAndContentLayers)`.
- `SceneSpatialIndex.build(scene)` without an explicit `nodeLocator` still
  returns the overlapping background node from
  `queryPaintCandidates(..., scope: backgroundAndContentLayers)`.
- The same scene returns only the content node from default
  `queryPaintCandidates(...)`.
- A scene with an out-of-range background paint node and a valid content node
  still serves content hit-test queries through the fast path.

#### Negative Scenarios

- Hit-test queries do not return background nodes.
- Hit-test fallback does not enumerate background nodes.
- A background-only paint failure does not force content hit-test queries onto
  the linear fallback path.

#### Closure Evidence

- Green run of the listed verification.
- Regression assertions proving scope-gated background paint admission and
  hit-test fast-path survival under a background-only paint failure.

### Slice 3. [x] Thread Scope Through Controller and Close the Committed Resolver Surface

#### Slice Contract

Controller-owned committed paint queries can return background candidates, and
every current candidate returned by that controller surface is resolvable by the
paired committed resolver.

#### Change

- In `lib/src/controller/internal/spatial_index_cache.dart`, change
  `writeQueryPaintCandidates(...)` to accept the same optional named scope and
  pass it to `SceneSpatialIndex.queryPaintCandidates(...)`.
- In `lib/src/controller/scene_store_controller.dart`, change
  `queryPaintCandidates(...)` to accept the same optional named scope and thread
  it through the cache.
- In `lib/src/controller/scene_store_controller.dart`, remove the early
  negative-layer rejection from `resolveSpatialCandidateSnapshot(...)` and let
  it resolve `layerIndex == -1` through `_resolveSnapshotAtLocationInSnapshot(...)`.
- Keep `queryHitTestCandidates(...)` without a scope parameter.
- Update controller and cache tests so background candidates returned by the
  controller scoped paint query are resolved through
  `resolveSpatialCandidateSnapshot(...)`, not only through
  `resolveSnapshotNodeById(...)`.

#### Verification

- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`

#### Fixtures Used

- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`

#### Positive Scenarios

- `SceneStoreController.queryPaintCandidates(..., scope: backgroundAndContentLayers)`
  returns an overlapping background candidate.
- `SceneStoreController.resolveSpatialCandidateSnapshot(...)` resolves that
  current committed background candidate.
- `SpatialIndexCache.writeQueryPaintCandidates(...)` returns the same scoped
  background candidate shape through the controller-owned cache path.

#### Negative Scenarios

- The default controller paint query remains content-only.
- Stale or out-of-range background candidates are still rejected by the
  committed resolver.

#### Closure Evidence

- Green run of the listed verifications.
- Regression assertions proving the controller query/resolve surface is closed
  for background candidates.

### Slice 4. [x] Replace the Committed Linear Background Scan in the Renderer Fast Path

#### Slice Contract

The committed renderer fast path admits ordinary background and content
candidates through one scoped shared paint query and one paired committed
resolver, without linearly scanning ordinary background nodes.

#### Change

- In `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`,
  delete the ordinary committed loop over `snapshot.backgroundLayer.nodes` from
  `_enumerateCommittedSnapshotPaintCandidates(...)`.
- Replace the separate ordinary `backgroundCandidates` and `contentCandidates`
  buckets with one ordered list of tuples containing
  `ScenePaintCandidate candidate`, `int layerIndex`, and `int nodeIndex`.
- Populate ordinary committed entries only from
  `_storeController.queryPaintCandidates(query.viewportRect, scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers)`.
- Resolve each ordinary committed candidate through
  `_storeController.resolveSpatialCandidateSnapshot((nodeId: candidate.nodeId, layerIndex: candidate.layerIndex, nodeIndex: candidate.nodeIndex))`.
- When building the ordinary committed `ScenePaintCandidate`, reuse
  `candidate.paintBoundsWorld` from the spatial query payload as
  `ScenePaintCandidate.paintBoundsWorld`. Do not recompute ordinary committed
  paint bounds from the resolved snapshot node.
- Resolve selected-node supplements through
  `_storeController.resolveSnapshotNodeById(nodeId)` only after confirming the
  node is not already accepted.
- Compute supplement paint bounds only after supplement dedupe and admit
  supplements only through `query.visibilityRect`.
- Sort the final ordered list by `(layerIndex, nodeIndex)` and then yield in
  that order so all background candidates precede content candidates.
- Keep the divergent active-frame branch unchanged: it must still return early
  to `enumerateSnapshotPaintCandidates(...)` before any committed spatial read.

#### Verification

- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`

#### Fixtures Used

- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`

#### Positive Scenarios

- A committed frame with overlapping ordinary background and content nodes emits
  background candidates before content candidates.
- A selected background supplement admitted only through `visibilityRect`
  retains background ordering.
- A selected content supplement admitted only through `visibilityRect` retains
  content ordering.
- A node admitted as an ordinary committed candidate and also selected is
  emitted once.

#### Negative Scenarios

- `_enumerateCommittedSnapshotPaintCandidates(...)` does not contain
  `snapshot.backgroundLayer.nodes`.
- The committed fast path does not resolve ordinary candidates via
  `resolveSnapshotNodeById(candidate.nodeId)`.
- The committed fast path does not recompute ordinary committed paint bounds
  from the resolved snapshot node.
- The committed fast path does not omit
  `scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers`.

#### Closure Evidence

- Green run of the listed verifications.
- Structural assertions proving the committed path no longer scans ordinary
  `snapshot.backgroundLayer.nodes`.
- Structural assertions proving the committed path reuses
  `candidate.paintBoundsWorld` instead of recomputing ordinary committed paint
  bounds.

### Slice 5. [x] Tighten Guardrails and Release Documentation

#### Slice Contract

Repository-local guardrails and release-ready docs enforce the corrected
background paint admission contract and exact committed helper signature
semantics.

#### Change

- In `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`,
  extend exact sealed-signature matching so it distinguishes:
  optional named vs required named, presence vs absence of a default value, and
  changed default-value source.
- In `test/tool/guardrails/guardrails_controller_api_tool_test.dart`, add
  negative cases for:
  `queryPaintCandidates(Rect worldBounds, {required ScenePaintSpatialQueryScope scope})`,
  `queryPaintCandidates(Rect worldBounds, {ScenePaintSpatialQueryScope scope})`
  without the sealed default value, and
  `queryPaintCandidates(Rect worldBounds, {ScenePaintSpatialQueryScope scope = ScenePaintSpatialQueryScope.backgroundAndContentLayers})`.
- Update sandbox fixtures in
  `test/tool/support/guardrails_tool_test_support.dart` so the accepted
  committed helper surface includes the scoped paint-query signature with the
  sealed default.
- Update `tool/invariant_registry.dart` so the invariant text for the committed
  renderer/read-side path states shared background paint admission,
  content-only hit-test admission, and query/resolve closure together.
- Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md`
  only after slices 1 through 4 are closed.
- Update this step document slice checkboxes in the same changes that close the
  corresponding slices.
- Update the `PLAN.md` Step 114 checkbox only in the same change that closes
  Slice 5 and therefore closes the full step.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- `test/tool/support/guardrails_tool_test_support.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`

#### Positive Scenarios

- The canonical scoped paint-query signature with its sealed default value is
  accepted by the guardrail tool.
- The updated invariant text is covered by repository-local proof surfaces.

#### Negative Scenarios

- Guardrails reject required-named scope promotion.
- Guardrails reject removal of the sealed default value.
- Guardrails reject changing the sealed default value to
  `backgroundAndContentLayers`.

#### Closure Evidence

- Green run of the listed verification.
- Diagnostics from the negative guardrail scenarios proving the new signature
  checks trigger at the controller API layer.
- Green structural tests and invariant-coverage output proving the corrected
  architectural form is enforced by executable checks rather than prose alone.

## 9. Final Verification

- `flutter test test/core/scene_spatial_index_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<path-or->`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
