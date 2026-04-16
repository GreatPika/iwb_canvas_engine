# Change Contract

## 1. Change Mandate

- This change fixes render-path over-admission by separating paint spatial admission from hit-test spatial admission at the engine contract boundary.

## 2. Change Boundary

### Included in the Change

- Separate spatial query contracts for paint admission and hit-test admission.
- Paint candidates that carry paint bounds only, with no hit-padding or hit-slop admission data exposed to the render path.
- Render-path culling before `ScenePainterFrameOwner.resolveNodePaintData(...)`.
- Tests proving nodes in the hit-test-only ring do not build render geometry or text layout during paint.
- Tool guardrail updates for the renamed spatial candidate contracts and committed read callbacks.
- Repository-local invariant, architecture, API, README, and changelog updates for the new paint/hit-test admission boundary.

### Not Included in the Change

- Public API changes outside the internal `src/**` render and controller read-side contracts.
- Changes to hit-test precision, eraser behavior, marquee selection behavior, or move preview semantics.
- Changes to render geometry cache key semantics, text layout measurement semantics, path parsing semantics, or scene serialization.
- A second physical spatial-index cache.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/node_geometry.dart`
- `lib/src/core/hit_test.dart`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/scene_snapshot_paint_candidates.dart`
- `lib/src/controller/change_set.dart`
- `lib/src/controller/internal/spatial_index_cache.dart`
- `lib/src/controller/node_mutation_applier.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/controller/selection_transform_mutation_applier.dart`
- `lib/src/contract/scene_view_render_state.dart`
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

- `test/core/hit_test_test.dart`
- `test/core/node_geometry_test.dart`
- `test/core/scene_spatial_index_test.dart`
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `test/controller/core/scene_controller_spatial_index_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `test/interactive/core/interactive_move_session_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/render_hit_bounds_parity_test.dart`
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
3. Paint admission uses paint bounds, not hit-test candidate bounds.
4. The render path must not call `ScenePainterFrameOwner.resolveNodePaintData(...)` for a candidate that fails the cheap paint-bounds visibility check.
5. `SceneSpatialIndex` remains the spatial-query owner and becomes role-aware; spatial indexing must not move into render modules.
6. The active frame snapshot remains the node authority for paint enumeration.
7. Selected-node supplements remain the only path that uses the budgeted visibility rect to keep selected edge nodes paint-visible.
8. The role-aware spatial API names are `SceneSpatialCandidateLocation`, `SceneHitTestSpatialCandidate`, `ScenePaintSpatialCandidate`, `queryHitTestCandidates(...)`, and `queryPaintCandidates(...)`.
9. The render frame candidate carrier name is `ScenePaintCandidate`.

## 5. Result Requirements

1. A node whose paint bounds do not overlap the effective paint visibility rect, but whose hit-test bounds overlap the viewport, is not resolved into render geometry during paint.
2. Hit-testing, eraser target lookup, and move hit-test candidate lookup continue to find nodes through hit-test bounds.
3. Paint candidate enumeration cannot access hit-padding or hit-slop candidate bounds through its candidate type.
4. Render geometry cache build count does not increase for hit-test-only ring nodes during a paint frame.
5. Text layout cache build count does not increase for hit-test-only ring text nodes during a paint frame.
6. Path local geometry is not built by the render geometry cache for hit-test-only ring path nodes during a paint frame.
7. Selected edge nodes that overlap only the budgeted selected-node visibility rect remain paint candidates.
8. Unselected nodes whose paint bounds do not overlap the raw viewport remain excluded from paint candidate resolution.
9. Repository guardrails no longer require or allow the neutral `SceneSpatialCandidate` / `querySpatialCandidates(...)` committed read contract.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Inspect all production and tooling call sites of `SceneSpatialCandidate`, `candidateBoundsWorld`, `querySpatialCandidates(...)`, `resolveSpatialCandidateSnapshot(...)`, `enumeratePaintCandidates(...)`, `ScenePainterPaintFrame.paintCandidates`, and `resolveNodePaintData(...)`.
- Inspect all tests that construct spatial candidates or fake `SceneViewRenderState` implementations.

### 6.2 Target Verification Units

- `test/core/scene_spatial_index_test.dart`
- `test/controller/core/scene_controller_spatial_index_test.dart`
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `test/interactive/core/interactive_move_session_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/render_hit_bounds_parity_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### 6.3 Protected States, Data, or Structures

- `SceneViewFrameRead` remains the single frame-read capture passed through background paint, candidate enumeration, preview delta resolution, and node paint.
- `RenderGeometryCache` remains the only render geometry cache owner.
- `SceneTextLayoutCache` remains the canonical cached text layout owner for render text candidates.
- `ScenePainterVisibilityBudget` remains render-local.
- `SceneStoreController.resolveSpatialCandidateSnapshot(...)` stale protection remains based on `nodeId`, `layerIndex`, and `nodeIndex`.

### 6.4 Allowed Semantic Change Zones

- Spatial candidate type definitions and query methods.
- Spatial-entry bounds storage and query filtering.
- Controller read-side spatial query names and callback plumbing.
- Paint candidate enumeration and frame candidate carrier types.
- Mutation change-set naming for spatial bounds invalidation.
- Pre-resolution paint visibility culling.
- Structural tests and invariant text that encode render admission ownership.
- Guardrail rules that encode committed read helper names, spatial candidate payload fields, and allowed constructor shapes.
- Documentation that describes render admission and hit-test admission ownership.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- hit-test query candidate;
- paint query candidate;
- background paint candidate;
- selected-node paint supplement candidate;
- active-frame-snapshot fallback paint candidate;
- fake test render-state paint candidate;
- manually constructed spatial candidate in tests.
- guardrail fixture spatial candidate declarations.

### 6.6 Allowed Forms That Do Not Count as Violations

- Hit-test code may read hit-test bounds.
- Eraser code may read hit-test candidates before exact target checks.
- Move hit-test code may read hit-test candidates before exact node hit checks.
- Paint selection rendering may consume resolved node paint data after the pre-resolution paint-bounds cull has passed.

### 6.8 Prohibited

- Do not pass a hit-test spatial candidate into paint candidate enumeration.
- Do not name a hit-test-bounds field `candidateBoundsWorld` after this change.
- Do not keep a neutral `SceneSpatialCandidate` type after this change.
- Do not keep a neutral `querySpatialCandidates(...)` method after this change.
- Do not let `ScenePainterNodeRenderer` call `resolveNodePaintData(...)` before the cheap paint-bounds visibility check.
- Do not make text layout resolution a prerequisite for deciding whether a candidate overlaps paint visibility.
- Do not use `hitPadding`, `kHitSlop`, or `nodeSnapshotGeometryCandidateBoundsWorld(...)` as ordinary paint admission.
- Do not keep `hitGeometryChangedIds` as the change-set field name after this change; the invalidation set must be role-neutral because it refreshes both paint and hit-test bounds.
- Do not add synchronizer glue between duplicate spatial-index owners.
- Do not add a second physical spatial-index cache.
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

### Slice 1. [ ] Split Spatial Candidate Roles

#### Slice Contract

`SceneSpatialIndex` exposes distinct hit-test and paint spatial candidate contracts, and paint candidates contain paint bounds that are not inflated by hit-padding or hit-slop.

#### Change

- Replace the single neutral spatial candidate shape in `lib/src/core/scene_spatial_index.dart` with role-specific candidate types for hit-test and paint queries.
- Introduce `SceneSpatialCandidateLocation` with only `nodeId`, `layerIndex`, and `nodeIndex`, and make both role-specific candidate types implement it.
- Define `SceneHitTestSpatialCandidate` with `hitTestBoundsWorld`.
- Define `ScenePaintSpatialCandidate` with `paintBoundsWorld`.
- Store both paint bounds and hit-test bounds on each spatial entry.
- Keep hit-test query filtering against hit-test bounds.
- Add paint query filtering against paint bounds.
- Rename `SceneSpatialIndex.query(...)` to `queryHitTestCandidates(...)` and add `queryPaintCandidates(...)`.
- Rename controller and interactive callback query methods so interactive code consumes `queryHitTestCandidates(...)` and render code consumes `queryPaintCandidates(...)`.
- Change `resolveSpatialCandidateSnapshot(...)` to accept `SceneSpatialCandidateLocation`.
- Rename `ChangeSet.hitGeometryChangedIds` and related change-set/update plumbing to `spatialGeometryChangedIds`.
- Preserve stale snapshot resolution by the `SceneSpatialCandidateLocation` fields.

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

- A hit-test query returns a node whose hit-test bounds overlap the probe because of hit-padding plus hit-slop.
- A paint query returns a node whose paint bounds overlap the query rect.
- Selected interactive hit-test and eraser flows continue to resolve candidates in layer/node order.

#### Negative Scenarios

- A paint query does not return a node whose only overlap comes from hit-padding plus hit-slop.
- Render-facing code cannot compile against the hit-test candidate type.
- Tool guardrails reject the old neutral spatial candidate shape.

#### Closure Evidence

- Green run of the listed verifications.
- Test assertion showing the same node is returned by hit-test query and rejected by paint query for a hit-test-only ring probe.

### Slice 2. [ ] Move Paint Culling Before Frame Resolution

#### Slice Contract

`ScenePainterNodeRenderer` performs paint-bounds visibility culling before any render geometry, text layout, or path local geometry resolution can occur.

#### Change

- Add `ScenePaintCandidate` in `lib/src/contract/scene_view_render_state.dart`.
- Change `ScenePainterPaintFrame.paintCandidates` to carry `ScenePaintCandidate` values instead of bare `NodeSnapshot` values.
- Make each paint candidate carry only the `NodeSnapshot` and preview-adjusted `paintBoundsWorld`.
- Preserve paint order through the order of the `ScenePainterPaintFrame.paintCandidates` list.
- Change `SceneControllerSceneViewRenderState.enumeratePaintCandidates(...)` and `enumerateSnapshotPaintCandidates(...)` to produce `ScenePaintCandidate` values.
- Make controller-owned ordinary content enumeration use `queryPaintCandidates(...)`.
- Make active-frame-snapshot fallback enumeration compute paint bounds from `nodeSnapshotBoundsWorld(...)`, not `nodeSnapshotGeometryCandidateBoundsWorld(...)`.
- Change `ScenePainterNodeRenderer._drawVisibleNodes(...)` to call the cheap visibility predicate on candidate paint bounds before invoking `resolveNodePaintData(...)`.
- Keep selected-node collection using resolved node paint data only after the candidate passes pre-resolution culling.

#### Verification

- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/contract/runtime_contract_interfaces_test.dart`

#### Positive Scenarios

- A selected edge node whose paint bounds overlap the selected-node visibility rect is painted and can contribute to selection rendering.
- A visible ordinary node whose paint bounds overlap the raw viewport is resolved and painted.
- Background, ordinary content, selected supplement, and active-frame-snapshot fallback candidates preserve their existing paint order through list order.

#### Negative Scenarios

- A text node whose hit-test bounds overlap the viewport but whose paint bounds do not overlap the candidate visibility rect does not increment text layout cache build count.
- A path node whose hit-test bounds overlap the viewport but whose paint bounds do not overlap the candidate visibility rect does not increment render geometry cache build count.
- A rect node in the hit-test-only ring does not increment render geometry cache build count.
- Active-frame-snapshot fallback does not admit an ordinary unselected node through hit-padding or hit-slop.

#### Closure Evidence

- Green run of the listed verifications.
- Regression test output proving `RenderGeometryCache.debugBuildCount == 0` for hit-test-only ring paint frames.

### Slice 3. [ ] Seal the Admission Boundary with Invariants and Documentation

#### Slice Contract

Repository-local invariant proof and release documentation state that hit-test admission and paint admission are separate and mechanically enforced.

#### Change

- Update `tool/invariant_registry.dart` so `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION` requires paint-bounds admission and pre-resolution culling.
- Update `test/render/scene_painter_bounds_contract_test.dart` to structurally reject render code paths where `resolveNodePaintData(...)` appears before the cheap paint-bounds visibility check.
- Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md` to describe the separated admission boundary and the user-visible performance fix.

#### Verification

- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=-`

#### Positive Scenarios

- Structural test recognizes paint-bounds culling before frame resolution.
- Documentation states that render admission is based on paint bounds while hit-test admission keeps hit-padding plus hit-slop.

#### Negative Scenarios

- Structural test fails if render-local node drawing resolves node paint data before paint-bounds culling.
- Structural test fails if ordinary paint admission uses hit-test candidate bounds.

#### Closure Evidence

- Green run of the listed verifications.
- `CHANGELOG.md` contains an `Unreleased` entry for the render over-admission performance fix.

## 9. Final Verification

- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=-`
- `dcm calculate-metrics` for any new production file under `lib/**`.
- Final `git status --short` review showing only files tied to this contract are modified.

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
