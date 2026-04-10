language: russian

# Шаг 99. Ввести controller-owned viewport candidate contract для `ScenePainter`

## 1. Change Mandate

Этот шаг вводит controller-owned internal contract перечисления viewport
paint-candidates для `ScenePainter`, чтобы `previewDeltaResolver(...)` и
`geometryCache.get(node)` выполнялись только для уже отобранных и упорядоченных
кандидатов кадра, без потери `backgroundLayer`/content порядка и live
move-preview видимости.

## 2. Change Boundary

### Included in the Change

- Internal render read-side contract for ordered paint-candidate enumeration.
- Controller-owned runtime implementation that combines background candidates,
  committed content spatial candidates, preview supplements, and stable paint
  order.
- `ScenePainter` frame/node pipeline migration from snapshot-wide content scans
  to candidate-first enumeration.
- Render/view/contract/invariant/documentation surfaces required to prove and
  publish the new candidate-first frame architecture.

### Not Included in the Change

- Text-layout owner unification between geometry sizing and text paint.
- Main-painter/overlay repaint-topology changes and marquee migration into the
  overlay path.
- Dynamic selection-halo cull-budget computation.
- Public API widening on `SceneRenderState`, `SceneViewRuntime`,
  `SceneController`, or public scene/model contracts.
- Write-side mutation-pipeline changes and hit-test behavior changes outside the
  render read-side candidate enumeration required by this step.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_contract.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/render/scene_painter_node_renderer.dart`
- `lib/src/render/scene_painter_shell.dart`

### Test Files

- `test/contract/runtime_contract_interfaces_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/view/scene_view_interactive_test.dart`

### Fixture and Supporting Data Files

- `test/support/committed_scene_view_render_state.dart`
- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_99_scene_painter_viewport_candidate_contract.md`

### Analysis Area

- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/render/**`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/render/**`
- `test/view/scene_view_interactive_test.dart`
- `test/support/committed_scene_view_render_state.dart`
- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must either introduce the internal
  paint-candidate contract, adopt it on the controller-owned render-state path,
  or switch `ScenePainter` from snapshot-wide content scans to candidate-first
  iteration.
- Every modified test file must pin one closed seam of this step:
  ordered candidate enumeration,
  preview supplement visibility,
  background/content paint order preservation,
  or the absence of all-content-node expensive resolution before culling.
- Every modified supporting or documentation file must publish or enforce the
  exact candidate-first frame contract closed by this step.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step changes only viewport paint-candidate ownership and candidate-first
   frame resolution. It must not absorb text-layout owner unification,
   main-painter/overlay repaint-topology changes, marquee ownership migration,
   or selection-halo cull-budget changes.
2. Viewport candidate enumeration becomes controller-owned read-side work;
   `ScenePainter` must consume ordered candidates instead of scanning every
   content node from `snapshot.layers` on the paint path.
3. The existing controller-owned spatial query owner remains the coarse content
   candidate source; this step must not introduce a second render-local spatial
   index or a second cached viewport-candidate source of truth.
4. `backgroundLayer` remains a dedicated below-content paint pass in final paint
   order, but its eligibility must be decided inside the same controller-owned
   candidate enumeration contract instead of by the node renderer's current
   all-node layer scan.
5. Preview-driven visibility must be preserved: a node whose committed bounds
   are outside the viewport but whose live preview delta moves it into the
   viewport must still be enumerated and painted in the same frame.
6. `ScenePainterShell` remains orchestration-only, and this step must update the
   existing frame-resolution invariant instead of creating a second overlapping
   invariant for the same contract.

## 5. Result Requirements

1. The production tree has one internal render-state contract that can
   enumerate viewport paint candidates in final paint order for the current
   frame.
2. Content nodes that are outside the viewport and have zero live preview delta
   are not passed to expensive render resolution on a cold paint or after
   epoch-triggered render-cache invalidation.
3. Nodes whose live preview delta moves their visual bounds into the viewport
   are enumerated and painted without reopening a full content-node scan.
4. `backgroundLayer` nodes still paint below content layers, and candidate-first
   enumeration does not change their order relative to content or their order
   inside the background layer.
5. Render-local frame resolution now occurs once per paint candidate per frame,
   and the proof surface no longer describes a resolve-on-all-nodes contract.
6. `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, and
   `tool/invariant_registry.dart` publish the same candidate-first frame
   architecture.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/render/scene_painter_node_renderer.dart` currently iterates
  `snapshot.backgroundLayer.nodes` and every `snapshot.layers` node list, calls
  `resolveNodePaintData(node)`, and only then applies `_canPaintNodeInFrame(...)`.
- `lib/src/render/scene_painter_frame.dart` currently resolves
  `previewDeltaResolver(node.id)` and `geometryCache.get(node)` every time
  `resolveNodePaintData(node)` is called.
- `lib/src/contract/scene_view_render_state.dart` currently has no viewport
  paint-candidate enumeration contract.
- `lib/src/controller/scene_store_controller.dart` already exposes the
  controller-owned coarse content query
  `querySpatialCandidates(Rect worldBounds)` for committed runtime nodes.
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
  already owns the controller-side render read boundary for snapshot,
  selected ids, controller epoch, live preview delta, live selection rectangle,
  and camera offset.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/render lib/src/interactive lib/src/controller --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner shard preset: `model_contract`
- MCP test runner shard preset: `render_view`
- MCP test runner shard preset: `interactive`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- Background-before-content paint order and in-layer node order.
- Live move-preview visibility semantics for selected nodes.
- The current repaint topology and overlay ownership from step `69`; this step
  must not split repaint channels.
- Public `SceneRenderState`, `SceneViewRuntime`, `SceneController`, and public
  scene/model contract surfaces.
- Existing hit-test and non-render spatial-query behavior outside the internal
  candidate enumeration introduced by this step.
- The current `scenePainterCullPadding` and selection-halo behavior until the
  dedicated later step changes that contract.

### 6.4 Allowed Semantic Change Zones

- Internal render read-side enumeration of frame paint candidates.
- Frame-local handoff from viewport candidate enumeration to expensive node
  resolution.
- Controller-owned mapping between runtime nodes/spatial candidates and
  snapshot nodes for render-only consumption.
- Invariant and documentation wording for the frame-resolution contract.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- The internal render-state contract must expose
  `Iterable<NodeSnapshot> enumeratePaintCandidates(Rect worldRect)`. This
  surface must remain internal and must not widen the public
  `SceneRenderState` contract.
- Content candidates must be sourced from
  `SceneStoreController.querySpatialCandidates(worldRect)`, resolved back to the
  current snapshot by `(layerIndex, nodeIndex)`, and validated by `node.id` plus
  `node.type`. A mismatch must skip the candidate instead of falling back to a
  scene-wide scan.
- Background candidates must be derived from the current runtime
  `Scene.backgroundLayer?.nodes` in node order, validated against the current
  snapshot background layer by index, and skipped on `id`/`type` mismatch.
- Preview supplements must be limited to nodes whose
  `previewDeltaResolver(nodeId)` is non-zero, must use preview-shifted runtime
  candidate bounds for overlap checks, and must be de-duplicated by `NodeId`
  before final emission.
- Final candidate emission order must be:
  background candidates in background-layer node order,
  then content candidates sorted by `(layerIndex, nodeIndex)`.
  Preview supplements must merge into that order and must not be appended in
  arbitrary discovery order.
- `ScenePainterFrameOwner.create(...)` must compute `viewRect` once and must
  pass that exact `viewRect` into the ordered candidate enumeration path.
  `ScenePainter` must not derive a second independent query rectangle in this
  step.
- `ScenePainterNodeRenderer` must consume frame-provided candidates and must no
  longer accept raw `snapshot.layers` iteration as the content paint source.
- Final `_canPaintNodeInFrame(...)` remains in the render path as a safety gate
  after expensive resolution; this step removes the all-content-node expensive
  work, not the final exact render-bounds cull.

### 6.8 Prohibited

- Introducing a render-local spatial index, viewport cache, or all-node
  precomputed render list independent of the controller-owned read-side state.
- Calling `geometryCache.get(node)` or `previewDeltaResolver(node.id)` for every
  content node before candidate preselection.
- Reopening a snapshot-wide content scan inside `ScenePainterNodeRenderer`,
  `ScenePainterShell`, or a new helper called from them.
- Appending preview supplements after content candidates in arbitrary order.
- Changing text-layout ownership, overlay repaint ownership, marquee ownership,
  or selection cull padding in this step.
- Widening public `SceneRenderState`, `SceneViewRuntime`, or
  `SceneController` surfaces.

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
9. The plan must be detailed enough that the implementing agent has no material
   branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered valid.
11. If a slice depends on an unconfirmed architectural decision, planning must
    stop and that decision must be explicitly confirmed by the user before the
    slice can be written or expanded.

## 8. Vertical Slices

### Slice 1. [x] Candidate-first paint pipeline is live

#### Slice Contract

`ScenePainter` enumerates ordered viewport paint candidates through the
controller-owned render-state path and resolves preview delta plus geometry only
for those candidates, while preserving `backgroundLayer` order and
preview-driven visibility.

#### Change

- Extend `SceneViewRenderState` with one internal ordered paint-candidate
  enumeration surface and update
  `SceneControllerSceneViewRenderState` plus the graph wiring so the controller
  runtime can implement it without widget-side or render-local helper readers.
- Implement controller-owned enumeration with this exact sequence:
  1. read runtime `backgroundLayer` nodes in node order, apply live preview
     delta by `node.id`, test overlap against the frame `viewRect`, resolve the
     accepted nodes to snapshot background nodes by index with `id`/`type`
     validation, and keep only accepted nodes;
  2. read committed content candidates from
     `SceneStoreController.querySpatialCandidates(viewRect)`, resolve them to
     snapshot nodes by `(layerIndex, nodeIndex)` with `id`/`type` validation,
     and collect accepted content candidates;
  3. inspect selected node ids, evaluate `previewDeltaResolver(nodeId)` only for
     those ids, add any non-zero-preview node whose preview-shifted runtime
     candidate bounds overlap `viewRect` and which was not already accepted by
     the committed query;
  4. de-duplicate by `NodeId`, sort content candidates by
     `(layerIndex, nodeIndex)`, and emit final order as background first, then
     sorted content.
- Move `ScenePainter` frame assembly to store the frame candidate sequence and
  switch `ScenePainterNodeRenderer` from raw snapshot-layer iteration to
  frame-provided candidate iteration.
- Keep `_canPaintNodeInFrame(...)` as the final exact render-bounds gate after
  `resolveNodePaintData(...)`; this slice removes the eager all-content-node
  expensive work and keeps the exact final cull.
- Update `test/support/committed_scene_view_render_state.dart` only to satisfy
  the expanded internal render-state interface; it must not become a second
  production candidate owner.

#### Verification

- `dcm calculate-metrics lib/src/render lib/src/interactive lib/src/controller --report-all`
- `dart run tool/check_import_boundaries.dart`
- MCP test runner shard preset: `model_contract`
- MCP test runner shard preset: `render_view`
- MCP test runner shard preset: `interactive`

#### Fixtures Used

- `test/support/committed_scene_view_render_state.dart`

#### Positive Scenarios

- A cold paint with many off-viewport content nodes resolves geometry only for
  the in-frame candidates instead of the full content-node population.
- A selected node whose committed bounds are outside the viewport but whose live
  preview delta moves it into the viewport is still enumerated and painted in
  the same frame.
- Background candidates remain below content candidates in the final paint
  order.

#### Negative Scenarios

- A content node outside the viewport with zero preview delta is not enumerated
  and does not trigger expensive render resolution on a cold frame.
- Spatial-query discovery order must not leak into final paint order; accepted
  content candidates must paint in scene layer/node order.
- A candidate whose resolved snapshot slot no longer matches `node.id` and
  `node.type` must be skipped instead of triggering a scene-wide recovery scan.

#### Closure Evidence

- Green run of the listed verifications.
- Cache-count assertions and structural render tests prove that the eager
  all-content-node expensive path is gone.
- Candidate-order assertions prove background/content and in-layer order remain
  intact.

### Slice 2. [x] Invariant and docs publish candidate-first frame resolution

#### Slice Contract

The invariant registry, proof surface, and release-ready docs describe and pin
the candidate-first frame-resolution contract instead of the superseded
resolve-on-all-nodes contract.

#### Change

- Update `tool/invariant_registry.dart` so the existing frame-resolution
  invariant describes candidate-first frame resolution and does not keep the old
  `once per node per frame` wording in parallel.
- Update the proof wording in
  `test/render/scene_painter_frame_contract_test.dart` and
  `test/render/scene_painter_bounds_contract_test.dart` so the proof surface
  matches the new invariant exactly.
- Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
  `PLAN.md`, and this step document so they publish the same internal
  architecture:
  controller-owned viewport candidate enumeration,
  candidate-first frame resolution,
  preserved background/content order,
  and preserved preview-driven visibility.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner shard preset: `render_view`

#### Positive Scenarios

- The frame-resolution invariant text and its proof files describe the same
  candidate-first contract.
- The architecture docs describe `ScenePainter` as consuming controller-owned
  ordered paint candidates before expensive node resolution.

#### Negative Scenarios

- No invariant or documentation text must continue to claim that `ScenePainter`
  resolves preview delta and geometry once for every node in the snapshot before
  viewport preselection.

#### Closure Evidence

- Green run of the listed verifications.
- `tool/invariant_registry.dart` and the proof files contain aligned invariant
  wording with exact `// INV:<id>` coverage.
- Release-ready docs no longer describe the superseded all-node frame path.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/render lib/src/interactive lib/src/controller --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner shard preset: `core`
- MCP test runner shard preset: `model_contract`
- MCP test runner shard preset: `controller_internal`
- MCP test runner shard preset: `controller`
- MCP test runner shard preset: `render_view`
- MCP test runner shard preset: `interactive`
- MCP test runner shard preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
