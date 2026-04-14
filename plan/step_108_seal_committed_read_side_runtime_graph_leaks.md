language: english

# Change Contract

## 1. Change Mandate
This change seals committed read-side access so live mutable runtime scene
graph objects never leave the write subsystem, and all controller-owned
interactive read paths consume one exact snapshot-backed node-resolution
surface.

## 2. Change Boundary

### Included in the Change
- Removal of committed read-side APIs that expose live `SceneNode` instances
  or owned `List<SceneNode>` containers.
- Conversion of `SceneSpatialCandidate` into one exact locator-only committed
  spatial payload.
- Introduction of one exact snapshot-backed committed node-resolution surface
  on `SceneStoreController`.
- Migration of controller-owned interactive read paths to that exact
  snapshot-backed surface.
- Consolidation of committed read-side geometry and hit-testing on the shared
  snapshot geometry owners in `lib/src/core/**`.
- Repository-local invariant, guardrail, and documentation updates that pin
  the sealed committed read-side contract.

### Not Included in the Change
- Mutation-side fixes for prepared replace-scene payload mutability
  (`PreparedSceneReplacement`) and any other prepare/apply hardening work.
- New node families, rendering features, selection semantics, or gesture
  behavior changes unrelated to sealing committed read-side runtime leaks.
- Public package-surface additions, removals, or renames.
- Spatial-index algorithm changes beyond the payload-shape and resolution
  changes required to stop exposing live runtime nodes.

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/node_geometry.dart`
- `lib/src/core/hit_test.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/interactive/interaction_eligibility_policy.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/interactive_runtime.dart`
- `lib/src/interactive/internal/interactive_runtime_callbacks.dart`
- `lib/src/interactive/internal/interactive_move_callbacks.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart`
- `lib/src/interactive/internal/interactive_move_hit_test_engine.dart`
- `lib/src/interactive/internal/interactive_move_session.dart`
- `lib/src/interactive/internal/interactive_double_tap_router.dart`
- `lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
- `lib/src/interactive/internal/interactive_draw_eraser_targets.dart`
- `lib/src/interactive/internal/interactive_draw_eraser_exact_hit.dart`
- `tool/invariant_registry.dart`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/controller_api_guardrails.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Test Files
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `test/controller/core/scene_controller_spatial_index_test.dart`
- `test/core/node_geometry_test.dart`
- `test/core/hit_test_test.dart`
- `test/render/render_hit_bounds_parity_test.dart`
- `test/interactive/core/interactive_move_session_test.dart`
- `test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `test/interactive/core/scene_controller_interactive_hit_test_foreground_test.dart`
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Analysis Area
- `lib/src/core/{scene_spatial_index,node_geometry,hit_test}.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/interactive/interaction_eligibility_policy.dart`
- `lib/src/interactive/internal/{scene_controller_scene_view_runtime,scene_controller_interaction_runtime,interactive_runtime,interactive_runtime_callbacks,interactive_move_callbacks,interactive_draw_coordinator_callbacks,interactive_move_hit_test_engine,interactive_move_session,interactive_double_tap_router,interactive_draw_eraser_engine,interactive_draw_eraser_targets,interactive_draw_eraser_exact_hit}.dart`
- `tool/{check_guardrails.dart,invariant_registry.dart}`
- `tool/src/guardrails/{controller_api_guardrails,interactive_api_guardrails}.dart`
- `test/controller/core/*.dart`
- `test/core/{node_geometry,hit_test}_test.dart`
- `test/render/render_hit_bounds_parity_test.dart`
- `test/interactive/core/*move*_test.dart`
- `test/interactive/core/*eraser*_test.dart`
- `test/interactive/core/*hit_test_foreground*_test.dart`
- `test/interactive/core/*actions_effects*_test.dart`
- `test/tool/guardrails/*.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified invariant entry must be tied to a concrete proof
  surface.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. The committed runtime scene graph stays write-private: live `Scene`,
   `SceneNode`, and owned runtime node collections must not cross committed
   read-side controller or interactive boundaries after this step.
2. `SceneSpatialCandidate` remains the committed spatial-query payload type,
   but after this step it is a locator-only record with `nodeId`,
   `layerIndex`, `nodeIndex`, and `candidateBoundsWorld` only. It must not
   carry a live runtime node object, a runtime-type mirror, or any second
   freshness token.
3. The exact committed spatial stale predicate is fixed. Resolving a
   `SceneSpatialCandidate` succeeds only when the current committed snapshot
   still contains a node at `[layerIndex][nodeIndex]` and that node's
   `id == candidate.nodeId`. Any index miss or id mismatch is stale and must
   fail. `candidateBoundsWorld` is coarse query data only and must not
   participate in freshness checks.
4. The exact committed node-id stale predicate is fixed. Resolving a node by
   id succeeds only when the current committed locator points to a snapshot
   position that exists and the snapshot node at that position still has the
   requested id. The resolution path must not fall back to a snapshot scan.
   Background-layer resolution uses the same helper and returns
   `layerIndex == -1`.
5. The exact `SceneStoreControllerSpatialAccess` read surface after this step
   is fixed to:
   `querySpatialCandidates(Rect worldBounds) -> List<SceneSpatialCandidate>`,
   `resolveSpatialCandidateSnapshot(SceneSpatialCandidate candidate) -> NodeSnapshot?`,
   `resolveSnapshotNodeById(NodeId nodeId) -> ({NodeSnapshot node, int layerIndex, int nodeIndex})?`,
   and `centerWorldForNodeSnapshots(Iterable<NodeSnapshot> snapshots) -> Offset`.
   `backgroundLayerNodes()`, `resolveSpatialCandidateNode(...)`, and
   `resolveNodeById(...)` must not remain after this step.
6. Background-layer committed read-side access after this step is fixed to the
   immutable controller snapshot only. No replacement background runtime-node
   helper is allowed.
7. The exact interactive committed read callback shape after this step is
   fixed. `InteractiveRuntimeCallbacks`,
   `InteractiveMoveSessionCallbacks`, and
   `InteractiveDrawCoordinatorCallbacks` must expose
   `resolveSpatialCandidateSnapshot(SceneSpatialCandidate candidate) -> NodeSnapshot?`
   and must not expose a runtime-node resolver under any name.
8. `InteractiveMoveHitTestEngine.hitTestTopNode(...)` and
   `InteractiveMoveSession.hitTestTopNode(...)` must return
   `NodeSnapshot?`. `InteractiveDoubleTapRouter` must recognize editable text
   from `TextNodeSnapshot`, not from a runtime `TextNode`.
9. Snapshot read-side geometry and hit-testing must reuse the existing shared
   geometry/hit-test owners in `lib/src/core/`. This step must not introduce a
   second interactive-local geometry owner, a temporary runtime-node
   materialization path, or a runtime-to-snapshot identity cross-check.
10. `SceneStoreController` remains a committed-store `SceneRenderState`; the
    full `SceneViewRenderState` assembly continues to live on the
    controller-owned interactive runtime path.
11. This step does not change the prepared replace-scene contract. Any
    `PreparedSceneReplacement` hardening remains a separate step.
12. Public documentation and changelog updates ship in the same change as the
    sealed committed read-side contract.

## 5. Result Requirements

1. No committed read-side API reachable from `SceneStoreController`,
   `SceneSpatialCandidate`, or the controller-owned interactive callback graph
   exposes a live mutable runtime `SceneNode` or an owned mutable runtime node
   collection.
2. A stale spatial candidate or node-id locator captured before
   `replaceScene(...)` or any other commit that changes committed ordering can
   no longer resolve to a current committed node unless the current committed
   snapshot still matches the fixed stale predicate from section 4.
3. Move hit-testing, marquee selection, double-tap text targeting, preview
   supplement resolution, and eraser targeting/exact-hit logic operate on
   immutable `NodeSnapshot` data while preserving current gesture behavior.
4. Committed read-side bounds and hit-test semantics remain aligned with the
   shared geometry/render contract for rect, image, text, line, stroke, and
   path nodes.
5. Repository-local tooling fails when committed read-side controller or
   interactive code reintroduces runtime `Scene`, `SceneNode`,
   `List<SceneNode>`, or resolved-type aliases of those payloads across the
   sealed boundary.
6. `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md`
   describe one consistent rule: immutable snapshots are the only supported
   committed read-side node surface outside the write subsystem.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Reuse the existing immutable snapshot boundary in
  `lib/src/contract/snapshot.dart`; do not add a second immutable node model.
- Keep `lib/src/core/scene_spatial_index.dart` as the spatial-query owner, but
  reduce its outward payload to the exact locator-plus-bounds record locked in
  section 4.
- Keep shared geometry and hit-test ownership in `lib/src/core/` by extending
  `node_geometry.dart` and the thin `hit_test.dart` facade for `NodeSnapshot`
  input. Do not duplicate snapshot geometry math in `interactive/**`.
- Keep `SceneStoreController` as the only adapter from committed-store state
  to controller-owned interactive read paths. `interactive/**` may read the
  committed `SceneSnapshot`, but it must not read `_store.sceneDoc`, runtime
  node lists, or runtime node locators directly.
- Reuse existing guardrail tooling patterns in `tool/check_guardrails.dart`
  instead of adding a separate linter or ad hoc script.

### 6.2 Target Verification Units
- Spatial payload and stale-resolution regressions in
  `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
  and `test/controller/core/scene_controller_spatial_index_test.dart`.
- Shared snapshot geometry and hit-test regressions in
  `test/core/node_geometry_test.dart`,
  `test/core/hit_test_test.dart`, and
  `test/render/render_hit_bounds_parity_test.dart`.
- Interactive move, double-tap, and eraser committed-read regressions in
  `test/interactive/core/interactive_move_session_test.dart`,
  `test/interactive/core/interactive_draw_eraser_engine_test.dart`,
  `test/interactive/core/scene_controller_interactive_hit_test_foreground_test.dart`,
  and
  `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`.
- Guardrail enforcement in
  `test/tool/guardrails/guardrails_controller_api_tool_test.dart` and
  `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`.
- Final repository verification through the canonical command required by
  `AGENTS.md` for code changes.

### 6.3 Protected States, Data, or Structures
- Existing write/commit flow, copy-on-write discipline, revision allocation,
  and signal/notification semantics.
- Existing public snapshot payload shape and public package entrypoint.
- Existing gesture semantics for move hit-testing, marquee selection,
  double-tap text targeting, preview, erase, and overlay updates.
- Existing render/cache ownership for snapshot geometry, text layout, stroke
  path reuse, and path contour reuse.

### 6.4 Allowed Semantic Change Zones
- Committed spatial-query payload shape and stale-resolution semantics.
- Controller committed read-side helper signatures and resolution behavior.
- Interactive callback signatures and committed read-side hit-test payload
  semantics.
- Shared snapshot geometry and hit-test helpers in `core/**`.
- Repository-local invariants, guardrails, and published committed read-side
  contract documentation.

### 6.5 Recognition Forms That Must Be Supported Within This Change
- Direct committed helper leakage through a returned `SceneNode`.
- Direct committed helper leakage through a returned `List<SceneNode>`.
- Leakage through a record field that includes a `SceneNode`.
- Leakage through a spatial-query payload that carries a runtime node object.
- Interactive callback signatures that accept or return runtime `SceneNode`
  values on the committed read side.
- Typedef or nullable aliases that resolve to `SceneNode`,
  `SceneNode?`,
  `List<SceneNode>`,
  or a record containing `SceneNode`.
- Snapshot-backed resolution of foreground spatial candidates and selected-node
  supplement paths.

### 6.6 Allowed Forms That Do Not Count as Violations
- Runtime `Scene` and `SceneNode` usage inside transaction/write owners under
  `lib/src/controller/**` where the objects do not cross the committed
  read-side boundary.
- Runtime `SceneNode` usage inside mutable core/model owners that remain
  entirely on the write side.
- Immutable `NodeSnapshot` values, ids, indices, bounds, and other computed
  scalar data crossing committed read-side boundaries.
- Render/cache code that continues to use snapshot-owned geometry payloads and
  cache keys.

### 6.7 Requirements for Resolution of Links and Structural Analysis
- Guardrails introduced or updated by this step must inspect resolved Dart
  type information, not raw source text alone, for controller helpers,
  `SceneSpatialCandidate`, and the interactive callback declarations listed in
  section 4.
- A typedef, nullable form, or record alias that resolves to `SceneNode`,
  `SceneNode?`, `List<SceneNode>`, or a record containing `SceneNode` counts
  as a violation on the sealed committed read-side boundary.
- For controller helper and interactive callback signatures covered by this
  step, resolved return types and parameter types are the proof surface.

### 6.8 Prohibited
- Do not keep `SceneSpatialCandidate.node` or replace it with another runtime
  node field under a different name.
- Do not add a second candidate-resolution contract. The only committed
  candidate-resolution helper allowed after this step is
  `resolveSpatialCandidateSnapshot(...)` with the stale predicate locked in
  section 4.
- Do not add a second id-resolution contract. The only committed node-id
  resolution helper allowed after this step is `resolveSnapshotNodeById(...)`
  with the stale predicate locked in section 4.
- Do not replace live runtime leakage with defensive runtime-node clones or a
  read-only runtime facade type.
- Do not materialize temporary runtime nodes from snapshots during interactive
  committed read-side hit-testing.
- Do not keep runtime-to-snapshot matching helpers such as a surviving
  `_matchesSnapshotNode(...)`-style cross-check in the committed read path.
- Do not leave `backgroundLayerNodes()`, `resolveSpatialCandidateNode(...)`,
  or `resolveNodeById(...)` reachable from committed read-side code after this
  step.
- Do not duplicate text/path/stroke snapshot geometry rules inside
  `interactive/**`; those rules must resolve through the shared core owner.
- Do not use `controllerEpoch` as the freshness proof for stale committed
  read-side candidates; stale checks must use the fixed snapshot
  location-plus-id predicates locked in section 4.
- Do not add a controller helper that returns background runtime nodes,
  runtime node collections, or a wrapper/record carrying them.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. Slice 2 is allowed to keep the pre-existing runtime helper surface only as
   an unfinished migration state while no new call site is added to it. It is
   not a fallback contract, not a secondary supported path, and not allowed to
   survive step closure. Slice 3 must delete that legacy surface in the same
   change that switches the last call site.
7. The step must not be marked complete while any committed read-side
   callback, helper, or payload type still exposes a runtime `SceneNode`.
8. Any slice that changes shared geometry ownership must keep
   `test/render/render_hit_bounds_parity_test.dart` green in the same change.
9. Any slice that changes guardrails must update `tool/invariant_registry.dart`
   in the same change where the proof surface is introduced.
10. Scope expansion to prepared replace-scene hardening is forbidden until this
    step is closed as written.
11. The plan must be detailed enough that the implementing agent has no
    material branch in how to execute a slice.
12. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered
    valid.

## 8. Vertical Slices

### Slice 1. [ ] Establish shared snapshot geometry and hit-testing

#### Slice Contract
Shared core geometry and hit-test owners can compute committed read-side
candidate bounds and hit-test behavior directly from immutable `NodeSnapshot`
values for rect, image, text, line, stroke, and path nodes.

#### Change
- Extend the shared geometry owner in `lib/src/core/node_geometry.dart` and
  the thin `lib/src/core/hit_test.dart` facade so committed read-side code can
  compute candidate bounds and hit-test semantics directly from
  `NodeSnapshot`.
- Reuse the same layout/path/stroke inputs already aligned with render
  geometry; do not introduce an interactive-local snapshot geometry
  implementation.
- Keep parity coverage in `test/render/render_hit_bounds_parity_test.dart`
  authoritative for rect, path, line, and stroke world-bounds alignment.

#### Verification
- `flutter test test/core/node_geometry_test.dart`
- `flutter test test/core/hit_test_test.dart`
- `flutter test test/render/render_hit_bounds_parity_test.dart`

#### Positive Scenarios
- Snapshot candidate bounds match the expected world bounds for rect, line,
  stroke, and path nodes.
- Snapshot hit-testing succeeds for representative box, text, line, stroke,
  and path cases.

#### Negative Scenarios
- Snapshot candidate bounds and hit-testing do not diverge from the shared
  render geometry contract for the covered parity cases.

#### Closure Evidence
- Shared core geometry tests and parity tests stay green with direct
  `NodeSnapshot` input support.

### Slice 2. [ ] Introduce exact snapshot-backed controller read helpers

#### Slice Contract
The committed controller read boundary exposes one exact snapshot-backed
resolution surface and one exact locator-only spatial payload, with stale
resolution behavior fixed by section 4.

#### Change
- Change `SceneSpatialCandidate` in
  `lib/src/core/scene_spatial_index.dart` to carry exactly
  `nodeId`, `layerIndex`, `nodeIndex`, and `candidateBoundsWorld`.
- Update spatial-index builders and query code so candidate creation no longer
  stores or returns a runtime node object.
- Add `resolveSpatialCandidateSnapshot(...)` to
  `SceneStoreControllerSpatialAccess` with the exact signature and stale
  predicate locked in section 4.
- Add `resolveSnapshotNodeById(...)` to
  `SceneStoreControllerSpatialAccess` with the exact signature and stale
  predicate locked in section 4, using the committed locator as the only fast
  path and validating the resolved snapshot location before success.
- Do not remove the pre-existing runtime helper surface in this slice unless
  all dependent call sites are switched in the same change. If that legacy
  surface is retained temporarily for migration sequencing, no new call site
  may be added to it and it must not be documented, renamed, or treated as a
  supported fallback.

#### Verification
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_index_test.dart`

#### Positive Scenarios
- A valid foreground spatial candidate resolves to the expected immutable
  `NodeSnapshot`.
- A valid node id resolves to
  `({NodeSnapshot node, int layerIndex, int nodeIndex})`.
- A non-structural commit that keeps locator position and node id stable does
  not invalidate an otherwise valid candidate.

#### Negative Scenarios
- A stale candidate captured before `replaceScene(...)` does not resolve.
- An out-of-range candidate does not resolve.
- A stale id locator whose current snapshot node id no longer matches does not
  resolve.
- `SceneSpatialCandidate` no longer exposes any runtime node object.

#### Closure Evidence
- Targeted controller tests prove the exact stale predicate and snapshot
  payload shape.
- The committed controller read boundary exposes the exact helper surface
  locked in section 4, even if the temporary runtime bridge still exists for
  downstream compilation.

### Slice 3. [ ] Migrate interactive committed reads to the exact snapshot surface

#### Slice Contract
All controller-owned interactive committed read paths consume the exact
snapshot-backed controller helpers from section 4, and the pre-existing
runtime helper surface is deleted.

#### Change
- Rename the committed read callback field in
  `interactive_runtime_callbacks.dart`,
  `interactive_move_callbacks.dart`, and
  `interactive_draw_coordinator_callbacks.dart` to
  `resolveSpatialCandidateSnapshot` with the exact type
  `NodeSnapshot? Function(SceneSpatialCandidate candidate)`.
- Update `scene_controller_interaction_runtime.dart` and
  `interactive_runtime.dart` to wire only that exact snapshot callback.
- Update `InteractiveMoveHitTestEngine` and `InteractiveMoveSession` so their
  hit-test path operates on `NodeSnapshot`, not `SceneNode`, and
  `hitTestTopNode(...)` returns `NodeSnapshot?`.
- Update `InteractiveDoubleTapRouter` so text hit recognition uses
  `TextNodeSnapshot`.
- Update `InteractiveDrawEraserTargets`,
  `InteractiveDrawEraserEngine`, and
  `InteractiveDrawEraserExactHit` so deletable targeting and exact-hit checks
  consume `NodeSnapshot`, with exact-hit dispatch switching on
  `LineNodeSnapshot` and `StrokeNodeSnapshot`. `InteractiveDrawEraserTarget`
  stores `NodeSnapshot`, not `SceneNode`.
- Update `scene_controller_scene_view_runtime.dart` so:
  background candidates read only from `snapshot.backgroundLayer.nodes`,
  foreground candidates resolve only through
  `resolveSpatialCandidateSnapshot(...)`,
  selected-node supplements resolve only through
  `resolveSnapshotNodeById(...)`,
  and no runtime/snapshot cross-check helper remains in the committed read
  path.
- Remove `backgroundLayerNodes()`, `resolveSpatialCandidateNode(...)`, and
  `resolveNodeById(...)` in the same change where the last call site is
  switched.
- Remove runtime-node-specific committed read-side predicates from
  `interaction_eligibility_policy.dart` once the last committed read call site
  no longer depends on them.

#### Verification
- `flutter test test/interactive/core/interactive_move_session_test.dart`
- `flutter test test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_hit_test_foreground_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

#### Positive Scenarios
- Snapshot-based move hit-testing still selects the top-most selectable node.
- Snapshot-based marquee selection still resolves the expected node ids.
- Snapshot-based double-tap still targets editable text nodes correctly.
- Snapshot-based eraser targeting still deletes matching line and stroke
  nodes.
- Selected-node supplement resolution still includes off-viewport selected
  nodes from the current committed snapshot order.

#### Negative Scenarios
- Interactive committed read-side callbacks no longer accept or return
  `SceneNode`.
- No committed read-side path in `interactive/**` reads runtime background
  nodes or runtime node locators directly.
- No committed read-side path in `interactive/**` keeps a runtime-to-snapshot
  identity/type cross-check helper.

#### Closure Evidence
- Interactive move, hit-test-foreground, double-tap, and eraser tests stay
  green with `NodeSnapshot`-based callback contracts.
- The pre-existing runtime helper surface is deleted; no legacy committed
  runtime-node fallback remains at step closure.

### Slice 4. [ ] Guardrail committed read-side hermeticity

#### Slice Contract
Repository-local tooling fails when controller or interactive committed
read-side code reintroduces runtime scene-graph leaks across the sealed
boundary.

#### Change
- Add a new invariant entry in `tool/invariant_registry.dart` for committed
  read-side runtime-graph hermeticity with exact proof surfaces in the
  guardrail tests added by this slice.
- Extend `tool/check_guardrails.dart` and the existing controller/interactive
  guardrail owners so they reject resolved committed read-side signatures that
  expose:
  `SceneNode`,
  `SceneNode?`,
  `Scene`,
  `List<SceneNode>`,
  or a record/typedef alias containing `SceneNode`
  when those types appear in the controller helper surface locked in section
  4, `SceneSpatialCandidate`, or the interactive callback declarations locked
  in section 4.
- Add positive and negative tool regressions in
  `guardrails_controller_api_tool_test.dart` and
  `guardrails_interactive_api_tool_test.dart` that prove allowed
  snapshot-backed read signatures pass while resolved runtime-graph leaks
  fail.

#### Verification
- `flutter test test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `flutter test test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Positive Scenarios
- Snapshot-backed committed read helpers and interactive callbacks pass the
  guardrails.

#### Negative Scenarios
- A controller helper that returns `SceneNode` fails.
- A controller helper that returns `List<SceneNode>` fails.
- A controller helper or callback that uses a typedef alias resolving to
  `SceneNode` fails.
- A spatial payload or interactive callback signature that exposes a record
  containing `SceneNode` fails.

#### Closure Evidence
- Guardrail regression tests prove the sealed boundary is mechanically
  enforced by resolved-type analysis.
- The invariant registry contains the new committed read-side hermeticity
  rule with matching proof surfaces.

### Slice 5. [ ] Publish the sealed committed read-side contract

#### Slice Contract
Repository documentation describes one non-contradictory rule for committed
read-side access: immutable snapshots are the only supported node surface
outside the write subsystem.

#### Change
- Update `ARCHITECTURE.md` so the `SceneStoreController` read-side contract,
  spatial-query contract, and interactive runtime contract explicitly state
  the exact helper surface locked in section 4 and the fixed stale predicate
  for snapshot-backed resolution.
- Update `README.md` and `API_GUIDE.md` where they describe controller
  read-side behavior, internal render-state ownership, and snapshot-based
  interactive read semantics so they no longer imply helper-based runtime node
  reads.
- Add an `## Unreleased` changelog entry in `CHANGELOG.md` describing that
  committed read-side runtime graph leaks were sealed and interactive reads now
  consume immutable snapshot-backed node data.

#### Verification
- `rg -n "resolveSpatialCandidateSnapshot|resolveSnapshotNodeById|write-private|snapshot-backed|runtime graph" ARCHITECTURE.md README.md API_GUIDE.md CHANGELOG.md`

#### Closure Evidence
- The listed documentation files describe one consistent committed read-side
  rule with no remaining wording that blesses live runtime node access outside
  the write subsystem.
