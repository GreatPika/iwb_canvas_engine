# Change Contract

## 1. Change Mandate

- This change fixes render-path over-admission by separating paint admission from hit-test admission while preserving the existing paint order for background nodes, content nodes, and selected-node supplements.

## 2. Change Boundary

### Included in the Change

- Separate role-specific spatial query contracts for paint admission and hit-test admission.
- Paint candidate payloads that carry paint bounds only and can be culled before render geometry or text layout resolution.
- A single committed-read merge owner for controller-backed paint candidate enumeration.
- Explicit preservation of original paint order for selected-node supplements, including background nodes admitted only through the expanded selected visibility rect.
- Guardrail, invariant, test, and release-document updates for the separated admission boundary and paint-order contract.

### Not Included in the Change

- Moving background nodes into `SceneSpatialIndex`.
- Changing hit-test precision, eraser behavior, marquee behavior, selection semantics, or preview-delta semantics.
- Changing public package exports outside the existing internal `src/**` read-side contracts already touched by this step.
- Introducing a second spatial cache, a synchronizer between duplicated sources of truth, or a background-specific render index.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/scene_spatial_index.dart`
- `lib/src/controller/change_set.dart`
- `lib/src/controller/internal/spatial_index_cache.dart`
- `lib/src/controller/node_mutation_applier.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/controller/selection_transform_mutation_applier.dart`
- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/core/node_geometry.dart`
- `lib/src/core/scene_snapshot_paint_candidates.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart`
- `lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
- `lib/src/interactive/internal/interactive_draw_eraser_targets.dart`
- `lib/src/interactive/internal/interactive_move_callbacks.dart`
- `lib/src/interactive/internal/interactive_move_hit_test_engine.dart`
- `lib/src/interactive/internal/interactive_runtime_callbacks.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/render/scene_painter_contract.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/render/scene_painter_node_renderer.dart`
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`

### Test Files

- `test/core/scene_spatial_index_test.dart`
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `test/controller/core/scene_controller_spatial_index_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `test/interactive/core/interactive_move_session_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/support/committed_scene_view_render_state.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `tool/bench/load_profiles_cases_test.dart`

### Fixture and Supporting Data Files

- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `tool/invariant_registry.dart`

### Analysis Area

- `lib/src/core/**`
- `lib/src/controller/**`
- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/interactive/internal/**`
- `lib/src/render/**`
- `test/core/**`
- `test/controller/**`
- `test/contract/**`
- `test/interactive/**`
- `test/render/**`
- `test/support/**`
- `test/tool/**`
- `tool/bench/**`
- `tool/src/guardrails/**`

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

1. Paint admission and hit-test admission are separate contracts.
2. Hit-test admission keeps using hit-padding plus `kHitSlop`.
3. Paint admission uses paint bounds and must not expose hit-test candidate bounds to render-facing code.
4. `SceneSpatialIndex` remains the spatial-query owner for content-layer nodes only in this step.
5. Background nodes remain a dedicated snapshot/read-side boundary and are not moved into `SceneSpatialIndex` by this step.
6. `SceneControllerSceneViewRenderState` is the single merge owner for controller-backed paint candidate enumeration order.
7. Ordinary coarse paint admission remains viewport-first: the ordinary spatial query continues to use the raw viewport, unselected final paint culling keeps the base `1.0` visibility budget, active selection widens only the selected-node visibility rect, and selected-node supplements remain the only path that may admit a node outside the raw viewport query.
8. The source path of a paint candidate must not change its relative paint order; selected-node supplements keep their original `(layerIndex, nodeIndex)` position semantics, including background nodes with `layerIndex == -1`.
9. `ScenePainterNodeRenderer` must perform cheap paint-bounds visibility culling before `resolveNodePaintData(...)`.
10. The active frame snapshot remains the only node authority for a frame; controller-backed spatial-query enumeration is allowed only while the active frame snapshot is identical to the committed controller snapshot.
11. The role-aware spatial API names are `SceneSpatialCandidateLocation`, `SceneHitTestSpatialCandidate`, `ScenePaintSpatialCandidate`, `queryHitTestCandidates(...)`, and `queryPaintCandidates(...)`.
12. The render-frame candidate carrier name is `ScenePaintCandidate`.

## 5. Result Requirements

1. A node whose paint bounds do not overlap the effective paint visibility rect is not resolved into render geometry or text layout during paint, even if its hit-test bounds overlap the viewport.
2. Hit-testing, eraser target lookup, and move hit-test lookup continue to admit nodes through hit-test bounds.
3. Paint candidate enumeration cannot compile against hit-test-only bounds payload.
4. Ordinary content paint candidates resolved from committed state preserve order by `(layerIndex, nodeIndex)`.
5. Ordinary background paint candidates preserve order by `(nodeIndex)` within the dedicated background layer.
6. A selected-node supplement admitted only through the selected visibility rect keeps the same relative paint order it would have had if admitted through the ordinary path.
7. A selected background-node supplement admitted only through the selected visibility rect stays in background paint order and does not move behind content-layer candidates.
8. A node is emitted at most once in a paint-candidate sequence even when it is reachable through both the ordinary path and the selected-node supplement path.
9. Active-frame-snapshot fallback continues to reject stale selected supplements and continues to resolve both ordinary paint candidates and current selected supplements from the frame snapshot when the frame snapshot diverges from the committed controller snapshot.
10. Unselected nodes whose paint bounds do not overlap the raw viewport query remain excluded from ordinary paint admission, and unselected nodes that fail the base `1.0` final visibility budget remain unpainted.
11. Repository guardrails and invariants reject the old neutral spatial candidate contract and reject render paths that resolve node paint data before cheap paint-bounds culling.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Inspect all call sites of `querySpatialCandidates(...)`, `SceneSpatialCandidate`, `candidateBoundsWorld`, `resolveSpatialCandidateSnapshot(...)`, `enumeratePaintCandidates(...)`, and `resolveNodePaintData(...)`.
- Inspect controller-backed paint enumeration in `scene_controller_scene_view_runtime.dart` together with its ordering tests before changing the merge logic.
- Inspect fake or mirror `SceneViewRenderState` implementations in tests so the updated candidate carrier and order contract are exercised by both snapshot-backed and controller-backed paths.

### 6.2 Target Verification Units

- `test/core/scene_spatial_index_test.dart`
- `test/controller/core/scene_controller_spatial_index_test.dart`
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `test/interactive/core/interactive_move_session_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `tool/bench/load_profiles_cases_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### 6.3 Protected States, Data, or Structures

- `SceneViewFrameRead` remains the single atomic frame-read capture reused across background paint, candidate enumeration, preview resolution, and node paint.
- `SceneStoreController.resolveSpatialCandidateSnapshot(...)` remains content-only and continues to reject background locations.
- `SceneStoreController.resolveSnapshotNodeById(...)` remains the owning read path for selected-node supplement resolution across both background and content.
- `RenderGeometryCache` remains the only render geometry cache owner.
- `SceneTextLayoutCache` remains the canonical cached text-layout owner for render text candidates.
- `ScenePainterVisibilityBudget` remains render-local.

### 6.4 Allowed Semantic Change Zones

- Spatial candidate type definitions, bounds payloads, and query method names.
- Spatial-entry bounds storage and invalidation naming.
- Controller and interactive committed-read callback names that consume role-specific spatial queries.
- Paint candidate carrier shape and pre-resolution paint culling.
- Controller-backed paint candidate merge ordering and selected-node supplement reinsertion.
- Structural ownership enforcement for controller-backed paint enumeration, frame-authoritative fallback, and render-local pre-resolution culling.
- Structural tests, invariant text, and release-ready documentation that encode the separated admission and paint-order contract.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- hit-test query candidate;
- paint query candidate;
- ordinary background paint candidate;
- ordinary content paint candidate;
- selected content supplement admitted only through the selected visibility rect;
- selected background supplement admitted only through the selected visibility rect;
- active-frame-snapshot fallback paint candidate;
- fake test render-state paint candidate.

### 6.6 Allowed Forms That Do Not Count as Violations

- Hit-test code may read hit-test bounds.
- Eraser code may read hit-test candidates before exact target checks.
- Move hit-test code may read hit-test candidates before exact node hit checks.
- Controller-backed paint enumeration may continue using a snapshot scan for background nodes in this step.
- Controller-backed paint enumeration may continue using `resolveSnapshotNodeById(...)` for selected supplements in this step.

### 6.8 Prohibited

- Do not keep a neutral `SceneSpatialCandidate` type or `querySpatialCandidates(...)` method.
- Do not let render-facing code depend on `hitTestBoundsWorld`, `candidateBoundsWorld`, `hitPadding`, `kHitSlop`, or `nodeSnapshotGeometryCandidateBoundsWorld(...)` for ordinary paint admission.
- Do not let selected-node supplements be appended by source bucket in a way that changes their original paint order.
- Do not reinsert a background supplement into the content candidate stream.
- Do not make `ScenePainterNodeRenderer` call `resolveNodePaintData(...)` before the cheap `candidate.paintBoundsWorld` overlap check.
- Do not move background nodes into `SceneSpatialIndex` as part of this step.
- Do not add a second physical spatial-index cache or synchronizer glue between duplicated read-side sources.
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

### Slice 1. [x] Split Spatial Candidate Roles

#### Slice Contract

Committed read-side callers consume separate hit-test and paint spatial candidate contracts, and paint queries return only paint-bounds payload.

#### Change

- Replace the neutral spatial candidate contract in `lib/src/core/scene_spatial_index.dart` with `SceneSpatialCandidateLocation`, `SceneHitTestSpatialCandidate`, and `ScenePaintSpatialCandidate`.
- Store both hit-test bounds and paint bounds in each spatial entry and expose them through `queryHitTestCandidates(...)` and `queryPaintCandidates(...)`.
- Rename committed read-side controller and interactive callback plumbing to the role-specific query names.
- Change `resolveSpatialCandidateSnapshot(...)` to accept `SceneSpatialCandidateLocation`.
- Rename `ChangeSet.hitGeometryChangedIds` and related invalidation plumbing to `spatialGeometryChangedIds`.
- Update guardrails that describe allowed committed-read helper names and allowed spatial candidate fields.

#### Verification

- `flutter test test/core/scene_spatial_index_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_index_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/controller/core/scene_controller_commit_atomicity_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `flutter test test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `flutter test test/interactive/core/interactive_move_session_test.dart`
- `flutter test test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `flutter test test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Positive Scenarios

- A hit-test query returns a node whose hit-test bounds overlap the probe only because of hit-padding plus `kHitSlop`.
- A paint query returns a node whose paint bounds overlap the query rect.
- Committed read-side helpers still resolve the same content-layer node by location after the contract rename.

#### Negative Scenarios

- A paint query does not return a node whose only overlap comes from hit-padding plus `kHitSlop`.
- Render-facing code cannot compile against the hit-test candidate type.
- Guardrails reject the old neutral spatial candidate shape and old helper names.

#### Closure Evidence

- Green run of the listed verifications.
- Test assertion showing the same node is admitted by hit-test query and rejected by paint query for a hit-test-only ring probe.

### Slice 2. [x] Introduce Paint Candidate Carrier and Pre-Resolution Cull

#### Slice Contract

Render-path paint enumeration produces `ScenePaintCandidate` values and `ScenePainterNodeRenderer` culls them by paint bounds before geometry or text-layout resolution.

#### Change

- Add `ScenePaintCandidate` in `lib/src/contract/scene_view_render_state.dart`.
- Change `SceneViewRenderState.enumeratePaintCandidates(...)`, `ScenePainterPaintFrame.paintCandidates`, and snapshot-backed candidate enumeration helpers to use `ScenePaintCandidate`.
- Make each `ScenePaintCandidate` carry only `node` and preview-adjusted `paintBoundsWorld`.
- Change snapshot-backed candidate enumeration to use `nodeSnapshotBoundsWorld(...)` for paint admission.
- Change `ScenePainterNodeRenderer._drawVisibleNodes(...)` to use `candidate.paintBoundsWorld` and `frame.visibilityRectForNode(...)` before calling `resolveNodePaintData(...)`.
- Keep selected-node collection using resolved node paint data only after the pre-resolution cull has passed.

#### Verification

- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/contract/runtime_contract_interfaces_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`

#### Positive Scenarios

- A visible ordinary node whose paint bounds overlap the raw viewport and passes the base `1.0` final visibility budget is resolved and painted.
- A selected edge node whose paint bounds overlap only the selected visibility rect is painted and can contribute to selection rendering.
- Fake and mirror render-state test doubles can still construct valid paint candidates.
- Ordinary coarse admission stays on the raw viewport query, and unselected final culling keeps the base `1.0` budget without widening to the full selected visibility rect.

#### Negative Scenarios

- A rect node in the hit-test-only ring does not increment render geometry cache build count during paint.
- A text node in the hit-test-only ring does not increment text layout cache build count during paint.
- A path node in the hit-test-only ring does not increment render geometry cache build count during paint.
- An unselected edge node outside the raw viewport query is not admitted through the selected-node visibility rect.

#### Closure Evidence

- Green run of the listed verifications.
- Regression test output proving zero render-geometry and text-layout builds for hit-test-only ring paint frames.

### Slice 3. [x] Restore Ordered Controller-Backed Paint Enumeration

#### Slice Contract

`SceneControllerSceneViewRenderState` is the single owner of controller-backed paint-candidate merge order, and selected-node supplements preserve their original background/content paint order regardless of admission source.

#### Change

- In `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`, keep controller-backed enumeration as one ordered merge algorithm that collects internal ordered entries with original `(layerIndex, nodeIndex)` semantics for every source path.
- Deduplicate by `NodeId` across ordinary and supplement paths before final emission so a node can appear at most once in the ordered output.
- Keep ordinary background candidates in the background stream ordered by `nodeIndex`.
- Keep ordinary content candidates from `queryPaintCandidates(...)` ordered by `(layerIndex, nodeIndex)`.
- Reinsert selected-node supplements into the same ordered stream using their original location semantics from `resolveSnapshotNodeById(...)`; for background nodes this means reinserting into background order, not appending to content.
- Preserve the frame-authoritative fallback: when the active frame snapshot diverges from the committed controller snapshot, ordinary paint enumeration and selected-node supplements both resolve against the active frame snapshot instead of mixing committed and frame sources.
- Update structural boundary tests so they fail if ordered controller-backed paint enumeration moves out of `SceneControllerSceneViewRenderState`, if the divergent-snapshot branch still calls committed `queryPaintCandidates(...)`, or if the controller-backed branch stops using the committed paint query plus snapshot background scan plus `resolveSnapshotNodeById(...)` merge shape.
- Add explicit order regressions for selected background supplements, selected content supplements, and mixed ordinary-plus-supplement frames.

#### Verification

- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios

- A selected background node admitted only through the selected visibility rect is emitted before content-layer candidates and at its original background position.
- A selected content node admitted only through the selected visibility rect is emitted at its original `(layerIndex, nodeIndex)` position among content candidates.
- A mixed frame with ordinary candidates plus selected supplements preserves the same order as if all candidates had been admitted through the ordinary path.
- A selected node already admitted by the ordinary path is emitted only once.

#### Negative Scenarios

- A selected background supplement is not appended after ordinary content candidates.
- A stale selected background id omitted from the active frame snapshot is not emitted.
- An unselected edge node outside the raw viewport query is not emitted as an ordinary paint candidate.
- A divergent active frame snapshot does not mix committed ordinary candidates with frame-only selected supplements.

#### Closure Evidence

- Green run of the listed verifications.
- Regression tests that fail when selected background supplements are appended to the content stream.

### Slice 4. [x] Seal the Boundary with Invariants and Documentation

#### Slice Contract

Repository-local invariants, structural tests, and release-ready documentation state the separated admission boundary and the preserved paint-order contract.

#### Change

- Update `tool/invariant_registry.dart` so the render admission invariant includes paint-bounds culling and source-independent paint-order preservation for selected supplements.
- Update the same invariant text so it explicitly states viewport-first ordinary admission with base `1.0` budget, selected-node-only budget widening, single-emission candidate deduplication, and frame-authoritative fallback when snapshots diverge.
- Update `test/render/scene_painter_bounds_contract_test.dart` to structurally reject render paths that resolve node paint data before the cheap paint-bounds overlap check.
- Update `test/interactive/core/scene_controller_architecture_boundary_test.dart` to structurally reject moving paint-candidate merge ownership away from `SceneControllerSceneViewRenderState` or mixing committed and frame snapshot sources inside one frame.
- Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md` so they describe the separated admission boundary and the preserved order semantics for background/content candidate enumeration.
- Update `PLAN.md` checkboxes only when the slice and the whole step are actually closed.

#### Verification

- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=-`

#### Positive Scenarios

- Structural tests recognize paint-bounds culling before render resolution.
- Structural tests recognize `SceneControllerSceneViewRenderState` as the owner of controller-backed paint enumeration and frame-authoritative fallback.
- Documentation states that hit-test admission and paint admission are separate, and that selected supplements do not change paint order.

#### Negative Scenarios

- Structural tests fail if render-local drawing resolves node paint data before paint-bounds culling.
- Structural tests fail if controller-backed paint enumeration is moved out of `SceneControllerSceneViewRenderState` or if one frame mixes committed and active-frame snapshot sources.
- Structural tests fail if selected supplement ordering depends on admission source instead of original location semantics.

#### Closure Evidence

- Green run of the listed verifications.
- `CHANGELOG.md` contains an `Unreleased` entry for the render over-admission fix once the step is implemented.

## 9. Final Verification

- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=-`
- `dcm calculate-metrics` for any new production file under `lib/**`
- Final `git status --short` review showing only files tied to this contract are modified

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
