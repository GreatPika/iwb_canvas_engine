# Change Contract

## 1. Change Mandate

- This change fixes background-layer render admission by indexing `backgroundLayer` nodes in the shared paint spatial index and removing the committed-frame linear background scan.

## 2. Change Boundary

### Included in the Change

- Extend the existing `SceneSpatialIndex` paint role so it can index committed `backgroundLayer` nodes together with committed content-layer nodes.
- Add an explicit paint-query scope so existing content-only paint queries keep their current semantics unless a caller asks for background plus content.
- Change controller-backed committed paint enumeration to query the shared paint spatial index once for ordinary background and content candidates.
- Preserve the existing hit-test, eraser, move hit-test, selection supplement, frame-authoritative fallback, and paint-order contracts.
- Add load-profile coverage for a background-heavy committed paint-admission frame.
- Add structural and behavioral tests that reject reintroducing a committed-frame linear `backgroundLayer` scan.
- Update invariant text and release-ready documentation for the indexed background paint-admission contract.

### Not Included in the Change

- Do not add a second spatial index, a background-only spatial index, a background-only candidate-bounds cache, or synchronization glue between duplicated candidate stores.
- Do not include `backgroundLayer` nodes in hit-test candidate admission.
- Do not change eraser target eligibility, move hit-test behavior, marquee selection behavior, selection normalization, write APIs, public package exports, JSON format, or snapshot format.
- Do not change active-frame-snapshot fallback enumeration to use committed spatial data when the active frame snapshot is not identical to the committed controller snapshot.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/scene_spatial_index.dart`
- `lib/src/controller/internal/spatial_index_cache.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`

### Test Files

- `test/core/scene_spatial_index_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `tool/bench/load_profiles_cases_test.dart`

### Fixture and Supporting Data Files

- `tool/invariant_registry.dart`
- `tool/bench/load_profile_policy.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`

### Analysis Area

- `lib/src/core/scene_spatial_index.dart`
- `lib/src/controller/internal/spatial_index_cache.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/model/document_locator.dart`
- `lib/src/core/scene_snapshot_paint_candidates.dart`
- `test/core/**`
- `test/controller/internal/**`
- `test/render/**`
- `test/interactive/core/**`
- `tool/bench/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every newly proposed file or directory name must comply with the global `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. The selected architecture is the shared spatial-index architecture: `backgroundLayer` participates in the existing `SceneSpatialIndex` paint role.
2. The implementation uses one shared committed spatial index and does not introduce a second background index.
3. The paint-query scope type name is `ScenePaintSpatialQueryScope`.
4. `ScenePaintSpatialQueryScope` has exactly two values: `contentLayersOnly` and `backgroundAndContentLayers`.
5. `SceneSpatialIndex.queryPaintCandidates(...)`, `SpatialIndexCache.writeQueryPaintCandidates(...)`, and `SceneStoreController.queryPaintCandidates(...)` default to `ScenePaintSpatialQueryScope.contentLayersOnly`.
6. Controller-backed committed frame enumeration uses `ScenePaintSpatialQueryScope.backgroundAndContentLayers`.
7. Hit-test spatial queries remain content-layer-only.
8. `backgroundLayer` locations continue to use `layerIndex == -1` and their existing `nodeIndex`.
9. The active frame snapshot remains the only node authority for a divergent frame.
10. `SceneControllerSceneViewRenderState` remains the single owner of controller-backed paint-candidate merge order.

## 5. Result Requirements

1. A committed ordinary background node whose paint bounds overlap the raw viewport is admitted through `SceneSpatialIndex` when the paint-query scope is `backgroundAndContentLayers`.
2. A committed ordinary background node is not returned by default content-only paint queries.
3. A committed background node is not returned by hit-test spatial queries.
4. A committed frame containing many off-viewport background nodes does not scan `snapshot.backgroundLayer.nodes` inside `_enumerateCommittedSnapshotPaintCandidates`.
5. Ordinary background and content paint candidates emitted by controller-backed committed enumeration are sorted by original paint order: all `layerIndex == -1` candidates in `nodeIndex` order, followed by content candidates ordered by `(layerIndex, nodeIndex)`.
6. Selected background supplements admitted only through `ScenePaintCandidateQuery.visibilityRect` keep their original background order and are emitted once.
7. Selected content supplements admitted only through `ScenePaintCandidateQuery.visibilityRect` keep their original content order and are emitted once.
8. Active-frame-snapshot fallback continues to enumerate background and content from the active frame snapshot without querying committed spatial data.
9. The background-heavy load profile emits a required benchmark case that exercises committed background paint admission with a small viewport.
10. Repository-local invariants and documentation state that background paint admission is indexed through the shared paint spatial index while hit-test admission remains content-layer-only.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Inspect every call site of `queryPaintCandidates(` before adding the scope parameter.
- Inspect every call site of `queryHitTestCandidates(` to confirm no hit-test caller receives a background scope.
- Inspect `_visitResolvedNodes`, `_buildNodeLocator`, `_resolveSpatialNodeById`, `_queryLinearHitTest`, `_queryLinearPaint`, `_resolvePaintCandidates`, `_upsertResolvedSpatialNode`, and `_SpatialEntry` in `lib/src/core/scene_spatial_index.dart` before changing index membership.
- Inspect `_enumerateCommittedSnapshotPaintCandidates` in `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` before changing merge order.
- Inspect `tool/bench/load_profile_policy.dart` and `tool/bench/load_profiles_cases_test.dart` before adding the background-heavy load profile.

### 6.2 Target Verification Units

- `test/core/scene_spatial_index_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `tool/bench/load_profiles_cases_test.dart`

### 6.3 Protected States, Data, or Structures

- `SceneStore.nodeLocator` remains the committed node-location source and already contains background locations through `lib/src/model/document_locator.dart`.
- `SceneSpatialIndex` remains the only committed coarse spatial-index owner.
- `ScenePaintSpatialCandidate` remains the render-facing spatial candidate payload for paint admission.
- `SceneHitTestSpatialCandidate` remains the interaction-facing spatial candidate payload for hit-test admission.
- `ScenePaintCandidate` remains the frame paint-candidate payload consumed by render code.
- `SceneViewFrameRead.snapshot` remains the authoritative snapshot for a frame.
- `SceneControllerSceneViewRenderState` remains the owner that combines ordinary candidates and selected-node supplements.

### 6.4 Allowed Semantic Change Zones

- Paint-scope selection for spatial paint queries.
- Paint-role indexing of `backgroundLayer` nodes inside `SceneSpatialIndex`.
- Content-only preservation for hit-test role queries and default paint queries.
- Controller-backed committed-frame ordinary paint-candidate enumeration.
- Selected-node supplement deduplication and original-order sorting.
- Load-profile policy and case emission for background-heavy paint admission.
- Structural tests, invariant text, and release documentation that encode the shared-index background paint-admission contract.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- content-only paint query;
- background-and-content paint query;
- content-only hit-test query;
- background paint candidate with `layerIndex == -1`;
- content paint candidate with `layerIndex >= 0`;
- selected background supplement admitted through `visibilityRect`;
- selected content supplement admitted through `visibilityRect`;
- active-frame-snapshot fallback enumeration;
- invalid-index linear fallback for hit-test admission;
- invalid-index linear fallback for paint admission.

### 6.6 Allowed Forms That Do Not Count as Violations

- Active-frame-snapshot fallback may linearly enumerate `snapshot.backgroundLayer.nodes` because no committed spatial index is authoritative for a divergent frame.
- `lib/src/core/scene_snapshot_paint_candidates.dart` may linearly enumerate background and content nodes because it handles arbitrary snapshots outside the committed spatial-index identity contract.
- Tests may construct scenes with background nodes directly through `Scene(backgroundLayer: ...)` and `SceneSnapshot(backgroundLayer: ...)`.
- Documentation may mention that snapshots and JSON keep `backgroundLayer` distinct from content `layers`.

### 6.8 Prohibited

- Do not keep a committed-frame ordinary background loop in `_enumerateCommittedSnapshotPaintCandidates`.
- Do not call `nodeSnapshotPaintBoundsWorld(...)`, `nodePaintBoundsWorld(...)`, or `_snapshotPaintBoundsWorld(...)` for every ordinary committed background node during each committed frame enumeration.
- Do not introduce `BackgroundSpatialIndex`, `SceneBackgroundSpatialIndex`, `BackgroundPaintCandidateCache`, `backgroundLayerNodes(...)`, or any new background-only spatial/cache owner.
- Do not make `queryHitTestCandidates(...)` accept `ScenePaintSpatialQueryScope`.
- Do not let hit-test linear fallback enumerate `scene.backgroundLayer?.nodes`.
- Do not make default `queryPaintCandidates(...)` return background candidates.
- Do not replace the divergent active-frame fallback with committed spatial-index reads.
- Do not append selected background supplements after content candidates.
- Do not add scope-specific paint cell maps, background-specific paint cell maps, or duplicate candidate-id stores; scoped paint queries must use `_paintCells`, `_largePaintNodeIds`, and `_entriesById` with explicit scope filtering.
- Do not broaden public package exports.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. The plan must be detailed enough that the implementing agent has no material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global `AGENTS.md` section `### File naming` before the slice is considered valid.
11. If a slice depends on an unconfirmed architectural decision, planning must stop and that decision must be explicitly confirmed by the user before the slice can be written or expanded.

## 8. Vertical Slices

### Slice 1. [ ] Add Scoped Background Paint Indexing

#### Slice Contract

`SceneSpatialIndex` indexes background nodes for paint admission under `ScenePaintSpatialQueryScope.backgroundAndContentLayers`, while default paint queries and all hit-test queries remain content-layer-only.

#### Change

- Add `enum ScenePaintSpatialQueryScope { contentLayersOnly, backgroundAndContentLayers }` to `lib/src/core/scene_spatial_index.dart`.
- Change `SceneSpatialIndex.queryPaintCandidates(Rect worldRect)` to `SceneSpatialIndex.queryPaintCandidates(Rect worldRect, {ScenePaintSpatialQueryScope scope = ScenePaintSpatialQueryScope.contentLayersOnly})`.
- Change `_querySceneSpatialIndexPaint`, `_queryLinearFallbackPaint`, `_queryLinearPaint`, and `_resolvePaintCandidates` to accept the same scope and to include returned background candidates only when the scope is `backgroundAndContentLayers`.
- Keep `SceneSpatialIndex.queryHitTestCandidates(Rect worldRect)` without a scope parameter.
- Replace the content-only private traversal with two explicit traversal helpers: `_visitResolvedContentNodes(...)` for hit-test traversal and `_visitResolvedPaintableNodes(...)` for paint indexing traversal. `_visitResolvedPaintableNodes(...)` must visit `scene.backgroundLayer?.nodes` first with `layerIndex: -1`, then all content layers in existing order.
- Change `_buildNodeLocator(Scene scene)` so the fallback locator created inside `SceneSpatialIndex.build(scene)` includes background nodes with `layerIndex: -1` before content nodes. The logic must match `txnBuildNodeLocator(...)` location semantics.
- Change `_resolveSpatialNodeById(...)` so `layerIndex == -1` resolves from `scene.backgroundLayer?.nodes` and validates `node.id == nodeId`.
- Change `_SpatialEntry` so `hitTestBoundsWorld` has type `Rect?`, `paintBoundsWorld` stays non-null, `_clone()` preserves the nullable hit-test field, and background entries are created with `hitTestBoundsWorld: null`.
- Change `_placeSpatialEntry(SceneSpatialIndex index, _SpatialEntry entry)` so it always places `paintBoundsWorld` into `_paintCells` or `_largePaintNodeIds`, and places hit-test cells only when `entry.hitTestBoundsWorld != null`.
- Change `_resolveHitTestCandidates(...)` so entries with `hitTestBoundsWorld == null` are skipped before intersection checks.
- Change `_upsertResolvedSpatialNode(...)` so content nodes compute both `nodeHitTestCandidateBoundsWorld(...)` and `nodePaintBoundsWorld(...)`, while background nodes compute only `nodePaintBoundsWorld(...)`.
- Change `_queryLinearPaint(...)` and `_resolvePaintCandidates(...)` so `ScenePaintSpatialQueryScope.contentLayersOnly` filters out every resolved candidate with `layerIndex == -1` before adding it to the output.
- Change `_queryLinearHitTest(...)` so invalid-index hit-test fallback uses `_visitResolvedContentNodes(...)` and never visits background nodes.

#### Verification

- `flutter test test/core/scene_spatial_index_test.dart`

#### Positive Scenarios

- A scene with one overlapping background rect and one overlapping content rect returns both ids from `index.queryPaintCandidates(rect, scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers)` with the background candidate carrying `layerIndex == -1`.
- A scene whose index is invalid because of an out-of-range content node still returns overlapping background paint candidates from paint fallback only when the scope is `backgroundAndContentLayers`.
- An incremental update for a moved background node updates paint-query results after `cloneForIncrementalUpdate(...).applyIncremental(...)` receives that node id in `spatialGeometryChangedIds`.
- A background node whose hit-test bounds would be larger than its paint bounds is returned only when its paint bounds overlap the paint query.

#### Negative Scenarios

- The same overlapping background rect is absent from `index.queryPaintCandidates(rect)` when the default scope is used.
- The same overlapping background rect is absent from `index.queryHitTestCandidates(rect)`.
- Invalid-index hit-test fallback does not return an overlapping background rect.
- Background hit-test-only overlap does not cause scoped paint admission; the test must use a background node form where paint-only overlap and hit-test-only overlap are distinguishable.

#### Closure Evidence

- Green run of the listed verification.
- Regression assertions proving one background node is returned by scoped paint query, excluded by default paint query, and excluded by hit-test query.

### Slice 2. [ ] Thread Paint Scope Through Controller Cache APIs

#### Slice Contract

Controller-backed paint-query callers can request `backgroundAndContentLayers` through the existing spatial-index cache, and existing callers that omit the scope keep content-only results.

#### Change

- Change `SpatialIndexCache.writeQueryPaintCandidates(...)` in `lib/src/controller/internal/spatial_index_cache.dart` to accept `{ScenePaintSpatialQueryScope scope = ScenePaintSpatialQueryScope.contentLayersOnly}` and pass it to `index.queryPaintCandidates(worldBounds, scope: scope)`.
- Change `SceneStoreController.queryPaintCandidates(...)` in `lib/src/controller/scene_store_controller.dart` to accept the same optional named scope and pass it to `spatialIndexCache.writeQueryPaintCandidates(...)`.
- Do not add a scope parameter to `queryHitTestCandidates(...)` in either file.
- Add focused `SpatialIndexCache` tests showing that the default paint scope excludes background candidates and the explicit `backgroundAndContentLayers` scope includes them through the cache.

#### Verification

- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/core/scene_spatial_index_test.dart`

#### Positive Scenarios

- `SpatialIndexCache.writeQueryPaintCandidates(..., scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers)` returns an overlapping background candidate with `layerIndex == -1`.
- `SceneStoreController.queryPaintCandidates(rect, scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers)` returns an overlapping background candidate from the committed store.

#### Negative Scenarios

- `SpatialIndexCache.writeQueryPaintCandidates(...)` without a scope does not return an overlapping background candidate.
- `SceneStoreController.queryHitTestCandidates(rect)` does not return an overlapping background candidate.

#### Closure Evidence

- Green run of the listed verifications.
- Regression assertions proving the cache and controller defaults remain content-only.

### Slice 3. [ ] Replace Committed Background Scan with Scoped Spatial Query

#### Slice Contract

`SceneControllerSceneViewRenderState._enumerateCommittedSnapshotPaintCandidates` uses one scoped paint spatial query for ordinary committed background and content candidates, then adds selected supplements through the existing visibility-rect path.

#### Change

- In `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`, remove the ordinary loop over `snapshot.backgroundLayer.nodes` from `_enumerateCommittedSnapshotPaintCandidates`.
- Replace the two ordinary source buckets with one ordered candidate collection whose entries contain `ScenePaintCandidate candidate`, `int layerIndex`, and `int nodeIndex`.
- Populate ordinary entries only from `_storeController.queryPaintCandidates(query.viewportRect, scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers)`.
- Resolve each ordinary candidate through `_storeController.resolveSnapshotNodeById(candidate.nodeId)`.
- Keep `acceptedNodeIds` deduplication across ordinary candidates and selected supplements.
- Keep selected supplements resolved through `_storeController.resolveSnapshotNodeById(nodeId)` and admitted through `query.visibilityRect`.
- For selected supplements, compute `_snapshotPaintBoundsWorld(...)` only after confirming the node was not already accepted.
- Sort the final collection by `layerIndex` and then `nodeIndex`. This sort must rely on `layerIndex == -1` to place background candidates before content candidates.
- Keep the divergent-snapshot branch unchanged: it must call `enumerateSnapshotPaintCandidates(...)` and return before committed spatial queries are used.

#### Verification

- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios

- A committed frame with overlapping ordinary background and content nodes emits background candidates before content candidates.
- A selected background supplement outside the raw viewport but inside `visibilityRect` is emitted in background order.
- A selected content supplement outside the raw viewport but inside `visibilityRect` is emitted in content order.
- A node admitted by the ordinary scoped spatial query and also listed in `selectedNodeIds` is emitted once.
- A divergent active frame snapshot still emits frame-only background nodes from the active frame snapshot.
- The committed enumeration method body contains `scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers`.

#### Negative Scenarios

- The committed enumeration method body does not contain `snapshot.backgroundLayer.nodes`.
- The committed enumeration method body does not contain two ordinary buckets named `backgroundCandidates` and `contentCandidates`.
- The structural test fails if the committed enumeration method body omits `scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers`.
- A stale selected background id omitted from the active frame snapshot is not emitted in the divergent fallback branch.

#### Closure Evidence

- Green run of the listed verifications.
- Structural regression assertion proving the committed method no longer scans `snapshot.backgroundLayer.nodes`.
- Functional regression assertion proving ordinary background candidates still paint below content candidates after the scan is removed.

### Slice 4. [ ] Add Background-Heavy Load Profile Coverage

#### Slice Contract

The benchmark policy requires a `background_layer_paint_admission` case that measures committed background paint admission with many off-viewport background nodes and a small viewport.

#### Change

- In `tool/bench/load_profile_policy.dart`, add `backgroundLayerNodeCount` and `backgroundLayerIterations` to `LoadProfilePolicy`.
- Set smoke policy values to `backgroundLayerNodeCount: 10000` and `backgroundLayerIterations: 3`.
- Set full policy values to `backgroundLayerNodeCount: 100000` and `backgroundLayerIterations: 4`.
- Add `const String backgroundLayerPaintCaseName = 'background_layer_paint_admission';`.
- Add required operations for `backgroundLayerPaintCaseName`: `enumerate_small_viewport` and `paint_small_viewport`.
- Include `backgroundLayerPaintCaseName` in `LoadProfilePolicy.requiredCaseNames`.
- Update `LoadProfilePolicy.requiredOperationsForCase(...)` so it returns the background-layer required operations for `backgroundLayerPaintCaseName`.
- In `tool/bench/load_profiles_cases_test.dart`, add one test named `load profile background-layer-paint profile=$profile`.
- Implement `_runBackgroundLayerPaintAdmissionCase({required int backgroundNodeCount, required int iterations})`.
- Import `package:iwb_canvas_engine/src/interactive/internal/scene_controller_scene_view_runtime.dart` in `tool/bench/load_profiles_cases_test.dart` so the benchmark can construct `SceneControllerSceneViewRenderState` directly.
- Build a `SceneSnapshot` whose `backgroundLayer` contains `backgroundNodeCount` `RectNodeSnapshot` nodes with ids `bg-$i`, `size: const Size(8, 8)`, `strokeWidth: 0`, and `transform: Transform2D.translation(Offset((i % 500) * 32.0, (i ~/ 500) * 32.0))`.
- Use `SceneControllerSceneViewRenderState` with a `SceneStoreController` so the measured enumeration path is the committed controller-backed path, not `_BenchmarkControllerRenderState`; construct the required interaction dependency with a `SceneController` instance and dispose both render state and interaction controller in `finally`.
- Measure `enumerate_small_viewport` by calling `renderState.enumeratePaintCandidates(renderState.captureFrameRead(), const ScenePaintCandidateQuery(viewportRect: Rect.fromLTWH(0, 0, 240, 160), visibilityRect: Rect.fromLTWH(-1, -1, 242, 162))).length`.
- Measure `paint_small_viewport` by painting `ScenePainter(controller: renderState, imageResolver: (_) => null)` into `const Size(240, 160)`.
- Return `visibleCandidateCount` alongside the benchmark metrics and assert that it is lower than `backgroundNodeCount / 10`.
- Add an `expect(visibleCandidateCount, lessThan(backgroundNodeCount / 10))` assertion before emitting the benchmark result.
- Dispose the render state, interaction controller, and store controller in `finally`.

#### Verification

- `flutter test tool/bench/load_profiles_cases_test.dart`

#### Positive Scenarios

- The smoke profile emits a `background_layer_paint_admission` result.
- The emitted result contains `enumerate_small_viewport` and `paint_small_viewport` metric objects.
- The benchmark uses `SceneControllerSceneViewRenderState` rather than `_BenchmarkControllerRenderState`.
- The emitted result includes `visibleCandidateCount`, and the value confirms the small viewport did not admit the full background layer.

#### Negative Scenarios

- `validateProducedLoadProfileCaseNames(...)` reports the background-heavy case as missing if the benchmark does not emit it.
- `requiredOperationsForCase(backgroundLayerPaintCaseName)` does not accept unrelated operation names.

#### Closure Evidence

- Green run of the listed verification.
- `IWB_BENCH_RESULT` output includes `name":"background_layer_paint_admission"` when the benchmark test is run.

### Slice 5. [ ] Seal the Shared-Index Background Paint Contract

#### Slice Contract

Repository-local invariants, structural tests, and release-ready documentation state that committed background paint admission uses the shared paint spatial index and that hit-test admission stays content-layer-only.

#### Change

- Update `tool/invariant_registry.dart` invariant `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION` so its title states that controller-backed ordinary paint admission uses the shared paint spatial index for background plus content nodes.
- Add `// INV:INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION` coverage markers to every new or updated render-frame structural test that enforces the shared-index background paint contract.
- Update `test/interactive/core/scene_controller_architecture_boundary_test.dart` to structurally reject a committed ordinary background scan in `_enumerateCommittedSnapshotPaintCandidates` and to require `ScenePaintSpatialQueryScope.backgroundAndContentLayers` in that method.
- Update `test/render/scene_painter_bounds_contract_test.dart` to structurally reject a background-specific spatial/cache owner name in `lib/src/**`.
- Update `README.md`, `API_GUIDE.md`, and `ARCHITECTURE.md` so they state that committed render paint admission uses the shared paint spatial index for both background and content, with hit-test admission still content-layer-only.
- Add a `CHANGELOG.md` `## Unreleased` entry stating that large `backgroundLayer` render admission now uses the shared paint spatial index instead of scanning all background nodes per committed frame.
- Update `PLAN.md` and this step document checkboxes only when implementation slices are actually closed.

#### Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=-`

#### Positive Scenarios

- Structural tests recognize the committed render path using `ScenePaintSpatialQueryScope.backgroundAndContentLayers`.
- Documentation states the shared-index background paint-admission contract.
- Invariant coverage tooling recognizes the updated proof markers.

#### Negative Scenarios

- Structural tests fail if `_enumerateCommittedSnapshotPaintCandidates` contains `snapshot.backgroundLayer.nodes`.
- Structural tests fail if a production file introduces `BackgroundSpatialIndex`, `SceneBackgroundSpatialIndex`, `BackgroundPaintCandidateCache`, or `backgroundLayerNodes(`.
- Structural tests fail if production code introduces `_backgroundPaintCells`, `_backgroundLargePaintNodeIds`, `_contentPaintCells`, or `_contentLargePaintNodeIds`.
- Structural tests fail if committed render enumeration no longer requests `ScenePaintSpatialQueryScope.backgroundAndContentLayers`.

#### Closure Evidence

- Green run of the listed verifications.
- `CHANGELOG.md` contains an `Unreleased` entry for indexed background-layer paint admission.

## 9. Final Verification

- `flutter test test/core/scene_spatial_index_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=-`
- `dcm calculate-metrics` for any new production file under `lib/**`
- Final `git status --short` review showing only files tied to this contract are modified

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
