# Change Contract

## 1. Change Mandate

Make paint-candidate admission consume one explicit paint-bounds source so
committed selected supplements and snapshot-local fallback cannot perform
text layout or SVG path parsing directly in per-node admission, while render
geometry and text resolution remain separate render-stage work.

## 2. Change Boundary

### Included in the Change

- introduce one mechanically enforced paint-admission bounds contract that
  separates coarse admission bounds from detailed render geometry
- move committed selected-supplement admission onto committed spatial paint
  bounds by using the existing
  `SceneStoreController.queryPaintCandidates(...)` spatial query surface with
  preview-shifted visibility queries and selected `nodeId` matching
- introduce a bounded snapshot-local paint-admission bounds source for
  `enumerateSnapshotPaintCandidates(...)` so snapshot fallback no longer calls
  `nodeSnapshotPaintBoundsWorld(...)` directly from enumeration/admission
- define and test a geometry validity key for snapshot-local admission bounds
  that is stronger than `nodeId + instanceRevision`
- keep preview delta application as a cheap frame-local `Rect.shift(...)`
  operation after base paint bounds are resolved
- add failing reproducer tests for the current heavy admission paths before
  implementation, plus guard tests for ordinary committed candidates,
  selected supplements, background-layer paint candidates, preview deltas, and
  cache key invalidation
- add structural guardrails that make later direct use of text measurement or
  SVG parsing from admission modules mechanically visible
- register or extend invariant coverage for the paint-admission bounds source
  and update `ARCHITECTURE.md`, `CHANGELOG.md`, `PLAN.md`, and this step
  document with the final checked-in state
- extend diagnostic performance coverage to expose snapshot-local admission
  cache build/hit behavior and selected-supplement committed bounds reuse
  through production owners

### Not Included in the Change

- no public API, public export, schema, serialization, or JSON format change
- no writable or serialized `boundsWorld`, `localBounds`, or paint-bounds field
  on `SceneSnapshot` or node snapshots
- no migration of render caches into controller, interactive, model, or
  contract owners
- no change to render-side geometry resolution, text layout rendering,
  selection drawing semantics, or node draw order
- no replacement of `SceneSpatialIndex`, `SpatialIndexCache`, or committed
  dirty tracking with a new committed storage owner
- no use of wall-clock benchmark thresholds as required proof
- no broad interaction, view-runtime, store-facade, or command-owner cleanup

## 3. Surrounding Code Review

### Inspected Artifacts

- `docs/adr/0001_target_engine_architecture.md` - target architecture keeps
  committed state in the store/write-kernel family, keeps interaction preview
  state ephemeral, and requires main-scene rendering to read from one atomic
  frame contract.
- `docs/target_architecture/families/view_runtime_and_render_seam.md` - the
  checked-in target form exposes one `SceneViewRuntime` boundary with separate
  `mainSceneRenderRead` and `overlayPreviewRead` facets; the fix must keep the
  main-scene paint plan behind `SceneViewMainSceneRenderRead`.
- `docs/target_architecture/families/store_and_commit_path.md` - committed
  reads and committed query helpers belong to the store facade and spatial
  cache path, not to interaction or view owners.
- `ARCHITECTURE.md` - render is read-only, frame-authoritative rendering paints
  from one captured frame read, committed fast-path admission is allowed only
  when the frame snapshot matches the committed snapshot, and snapshot-local
  enumeration exists to avoid mixing stale committed candidate data into a
  different frame authority.
- `tool/invariant_registry.dart` - existing invariants already cover the
  scene-painter frame contract, performance proof contour, render cache
  policy, committed spatial admission alignment, and spatial-index invalidation.
  This step will add `INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE`.
- `tool/check_import_boundaries.dart` and `tool/check_guardrails.dart` - both
  currently pass and therefore define the layer and ownership boundaries that
  this change must preserve.
- `lib/src/contract/scene_view_render_state.dart` - `ScenePaintCandidate`
  carries a `NodeSnapshot` plus `paintBoundsWorld`; `SceneViewFrameRead`
  carries one frozen snapshot and one frozen frame preview.
- `lib/src/render/scene_painter.dart` - `ScenePainter.paint(...)` captures a
  frame read once and sends it to the shell; `prepareForPaint(...)` follows the
  same frame-authoritative path.
- `lib/src/render/scene_painter_shell.dart` - paint preparation happens before
  node rendering; the shell delegates candidate preparation to
  `ScenePainterFrameOwner`.
- `lib/src/render/scene_painter_frame.dart` - `ScenePainterFrameOwner` builds
  the viewport/visibility query and resolves detailed render geometry later
  through `RenderGeometryCache` and `SceneTextLayoutCache`.
- `lib/src/render/render_geometry_cache.dart` and
  `lib/src/render/render_geometry_builder.dart` - render geometry is already a
  render-local cache keyed by node id, instance revision, and validity key; it
  is the wrong owner for committed or snapshot-local admission state but a
  valid precedent for strong validity-key semantics.
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` -
  `preparePaintPlan(...)` has the decisive branch:
  committed fast path uses `SceneControllerPaintCandidateStage`, while
  snapshot divergence uses `enumerateSnapshotPaintCandidates(...)`.
- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart` -
  ordinary committed candidates already consume `_store.queryPaintCandidates`
  and preserve `candidate.paintBoundsWorld`, while selected supplements still
  call `_snapshotPaintBoundsWorld(...)`.
- `lib/src/core/scene_snapshot_paint_candidates.dart` - snapshot-local
  enumeration calls `_snapshotPaintBoundsWorld(...)` both for overlap testing
  and candidate construction.
- `lib/src/core/node_geometry.dart` - `nodeSnapshotPaintBoundsWorld(...)`
  reaches `_snapshotLocalBounds(...)`; text snapshots call
  `TextLayoutRequest.forSnapshot(node).measure()` and path snapshots call
  `buildCenteredSvgPathGeometry(...)`.
- `lib/src/core/text_layout.dart` - `TextLayoutRequest.measure()` creates a
  `TextPainter` and calls `layout()`.
- `lib/src/core/geometry.dart` - `buildCenteredSvgPathGeometry(...)` calls
  `parseSvgPathDataOrThrow(...)`, checks path metrics, and centers the parsed
  path.
- `lib/src/core/scene_spatial_index.dart` - the committed spatial index already
  stores `_PaintSpatialEntry.paintBoundsWorld`, includes background and content
  nodes for paint entries, and resolves `ScenePaintSpatialCandidate` from those
  stored bounds.
- `lib/src/controller/internal/spatial_index_cache.dart` -
  `writeQueryPaintCandidates(...)` owns build/reuse of the committed spatial
  index and is the existing cache owner for committed paint candidate reads.
- `lib/src/controller/scene_store_controller.dart` - the committed store facade
  already exposes `queryPaintCandidates(...)`, `resolveSpatialCandidateSnapshot`
  and `resolveSnapshotNodeById(...)`; this step must reuse that sealed helper
  surface and must not add another public committed read helper.
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` - mechanically
  rejects public helpers outside the sealed `SceneStoreControllerSpatialAccess`
  surface with `must not extend the sealed helper surface`, so this contract
  cannot add a new `SceneStoreControllerSpatialAccess` member.
- `lib/src/core/text_node_layout_state.dart` and `lib/src/core/path_node.dart`
  - mutable runtime nodes already cache derived text size or local path data;
  snapshot nodes do not carry those caches, so snapshot-local admission needs
  its own bounded source if it cannot use committed runtime nodes.
- `test/render/scene_painter_bounds_contract_test.dart` - existing structural
  proof already locks ordinary committed paint enumeration to shared spatial
  query and proves only ordinary candidates avoid snapshot bounds; it does not
  yet protect selected supplements or snapshot fallback.
- `test/render/scene_painter_frame_contract_test.dart` - existing behavioral
  proof covers frame authority, selected supplement ordering, background
  supplement behavior, and cache order, but it does not prove cheap admission
  for text/path selected supplements or snapshot-local fallback.
- `test/render/scene_painter_test.dart` - integrated painter tests already
  exercise real `ScenePainter` cache reuse and are the right regression surface
  for visible behavior and render-cache lifecycle.
- `test/render/render_geometry_cache_test.dart` - source-level structural proof
  already forbids `.measure()` inside `render_geometry_builder.dart`; this is
  the closest precedent for forbidding heavy work in an owner module.
- `test/controller/internal/spatial_index_cache_test.dart`,
  `test/controller/core/scene_controller_spatial_index_test.dart`, and
  `test/core/scene_spatial_index_test.dart` - existing committed spatial proof
  covers index build/reuse, candidate bounds, background/content paint entries,
  stale locator rejection, and incremental update behavior.
- `tool/bench/load_profiles_cases_test.dart`,
  `tool/bench/load_profile_policy.dart`, and
  `test/tool/bench_run_load_profiles_test.dart` - diagnostic load profiles
  already include selection-path candidate staging, background-layer paint,
  and stable visible working set cases; new diagnostics must consume production
  owners and policy-declared probes.
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/scene_view_runtime.dart SceneViewRuntime.mainSceneRenderRead --direction=both --depth=3 --json`
  - confirms `SceneViewRuntime.mainSceneRenderRead` is consumed by
  `SceneViewRuntimeHost` and implemented by
  `SceneControllerSceneViewRuntime`, with tests around the same seam.
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/scene_view_render_state.dart SceneViewMainSceneRenderRead.preparePaintPlan --direction=both --depth=4 --json`
  - confirms `preparePaintPlan(...)` is called from
  `ScenePainterFrameOwner.createPrepared(...)` and by benchmark/test surfaces.
- `dart run tool/lsp_trace_flow.dart lib/src/interactive/internal/scene_controller_scene_view_runtime.dart SceneControllerSceneViewMainSceneRenderRead.preparePaintPlan --depth=5 --json`
  - confirms the production branch point is exactly committed stage versus
  snapshot-local enumeration.
- `dart run tool/lsp_trace_symbol.dart lib/src/core/node_geometry.dart nodeSnapshotPaintBoundsWorld --direction=both --depth=4 --json`
  - confirms the only production callers of `nodeSnapshotPaintBoundsWorld(...)`
  are snapshot-local candidate enumeration and selected-supplement staging.
- `dart run tool/lsp_trace_symbol.dart lib/src/controller/internal/spatial_index_cache.dart SpatialIndexCache.writeQueryPaintCandidates --direction=both --depth=4 --json`
  - confirms ordinary committed candidate staging already reaches
  `SceneSpatialIndex.queryPaintCandidates(...)` through the committed store
  facade and spatial-index cache.
- `dart run tool/run_tool_tests.dart test/tool/target_architecture_map_tool_test.dart`
  - target architecture map is currently mechanically valid.
- `dart run tool/check_import_boundaries.dart` and
  `dart run tool/check_guardrails.dart` - current layer and guardrail checks
  pass before the step begins.

### Current Entry Path

- main production paint path:
  `ScenePainter.paint(...)` ->
  `ScenePainterShell.paint(...)` ->
  `ScenePainterFrameOwner.createPrepared(...)` ->
  `SceneViewMainSceneRenderRead.preparePaintPlan(...)`
- committed ordinary candidate path:
  `SceneControllerSceneViewMainSceneRenderRead.preparePaintPlan(...)` ->
  `SceneControllerPaintCandidateStage.prepareCommittedPaintPlan(...)` ->
  `_stageOrdinaryCandidates(...)` ->
  `SceneStoreController.queryPaintCandidates(...)` ->
  `SpatialIndexCache.writeQueryPaintCandidates(...)` ->
  `SceneSpatialIndex.queryPaintCandidates(...)`
- committed selected-supplement defect path:
  `SceneControllerPaintCandidateStage._stageSelectedSupplements(...)` ->
  `_snapshotPaintBoundsWorld(...)` ->
  `nodeSnapshotPaintBoundsWorld(...)` ->
  `TextLayoutRequest.measure()` / `buildCenteredSvgPathGeometry(...)`
- snapshot-local defect path:
  `SceneControllerSceneViewMainSceneRenderRead.preparePaintPlan(...)` ->
  `enumerateSnapshotPaintCandidates(...)` ->
  `_snapshotPaintBoundsWorld(...)` ->
  `nodeSnapshotPaintBoundsWorld(...)` ->
  `TextLayoutRequest.measure()` / `buildCenteredSvgPathGeometry(...)`
- late render-resolution path that must stay separate:
  `ScenePainterNodeRenderer.paintNodeLayers(...)` ->
  `ScenePainterFrameOwner.resolveNodePaintData(...)` ->
  `SceneTextLayoutCache.getOrBuild(...)` /
  `RenderGeometryCache.get(...)`

### Current Owner

- committed paint-admission bounds are owned by `SceneSpatialIndex` and
  `SpatialIndexCache`, exposed narrowly through the existing
  `SceneStoreController.queryPaintCandidates(...)` helper; the sealed helper
  surface itself must not grow.
- snapshot-local paint-admission bounds currently have no owner; enumeration
  computes them directly through snapshot geometry helpers.
- detailed render geometry and text layout are owned by the render layer and
  must remain late render-resolution work.

### Adjacent Abstractions

- `ScenePaintCandidateQuery` - carries viewport and selected-node visibility
  rectangles.
- `ScenePaintCandidate` - carries the admitted node plus the paint bounds used
  for culling.
- `SceneControllerSelectedPaintOrderCache` - selected supplement order cache;
  it must stay an order/location cache and not absorb geometry policy.
- `SceneSpatialIndex` and `_PaintSpatialEntry` - existing committed coarse
  paint-admission storage.
- `SpatialIndexCache` - existing committed index lifecycle and reuse owner.
- `RenderGeometryCache`, `SceneTextLayoutCache`, and
  `buildRenderGeometryValidityKey(...)` - render-resolution cache precedent,
  not the new admission owner.
- `ScanResistantCache` - existing bounded cache policy suitable for a bounded
  snapshot-local admission cache if key/value semantics stay local.
- `SceneRenderCaches` - render cache lifecycle owner; it must not become a
  committed admission store.

### Existing Tests

- `test/render/scene_painter_bounds_contract_test.dart` - structural render
  seam proof for frame preparation, ordinary committed spatial query, and
  painter module boundaries.
- `test/render/scene_painter_frame_contract_test.dart` - behavioral proof for
  frame authority, selected supplement order, background/content order,
  visibility rect widening, stale supplement rejection, and cache order.
- `test/render/scene_painter_test.dart` - integrated painter behavior and
  render-cache reuse on the real paint path.
- `test/render/render_geometry_cache_test.dart` - render geometry cache
  key/reuse/invalidations and source-level proof that render geometry builder
  does not measure text.
- `test/controller/internal/spatial_index_cache_test.dart` - committed spatial
  index cache build/reuse/incremental/rebuild behavior.
- `test/controller/core/scene_controller_spatial_index_test.dart` - committed
  spatial query behavior through `SceneStoreController`.
- `test/core/scene_spatial_index_test.dart` - core spatial-index candidate
  bounds and ordering behavior.
- `test/tool/bench_run_load_profiles_test.dart` - diagnostic benchmark case and
  probe policy wiring.
- `test/tool/invariant_coverage_tool_test.dart` - invariant registry proof
  declarations.

### Analogous Implementation Path

- `SceneSpatialIndex.queryPaintCandidates(...)` and
  `SceneStoreController.queryPaintCandidates(...)` are the closest valid
  precedent for committed admission: they return candidates from stored paint
  bounds without render-side resolution and are already allowed by the sealed
  controller helper surface.
- `RenderGeometryCache` is the closest validity-key precedent: bounded cached
  derived data must be keyed by `nodeId`, `instanceRevision`, and a payload key
  that reflects all fields that affect the derived result.
- `ScanResistantCache` is the closest bounded retention precedent for a new
  admission cache that must avoid scan-thrash while keeping cache semantics
  local.
- `test/render/scene_painter_bounds_contract_test.dart` is the closest
  structural enforcement precedent for source-level render/admission drift.
- `tool/bench/load_profiles_cases_test.dart` is the closest diagnostic
  precedent for production-owner perf probes without benchmark-only runtime
  seams.

### Governing Repository Rules

- `AGENTS.md` - fix the root cause at the owning abstraction, prefer one source
  of truth, and use mechanically enforced repository-local rules for stable
  constraints.
- `AGENTS.md` - do not add sync glue to keep duplicate sources consistent; if
  caching is required, keep it explicit, minimal, and validated.
- `AGENTS.md` - after code changes, use the required verification preset with
  all changed paths, not direct package-wide `dart test`.
- `ARCHITECTURE.md` - render is read-only and paints from one atomic
  `SceneViewFrameRead`.
- `ARCHITECTURE.md` - committed fast-path admission may use committed spatial
  data only when the frame snapshot is identical to the committed snapshot.
- `docs/target_architecture/families/store_and_commit_path.md` - committed
  reads and query helpers remain in the store family.
- `docs/target_architecture/families/view_runtime_and_render_seam.md` -
  main-scene render reads stay behind `SceneViewRuntime.mainSceneRenderRead`.
- `tool/invariant_registry.dart` - cross-cutting engine contracts require
  declared executable proof surfaces.

### Rejected Misleading Local Patterns

- adding paint bounds to public `NodeSnapshot` - wrong level because snapshots
  are the immutable document boundary and text bounds are derived layout
  output, not writable or serialized document state.
- passing `RenderGeometryCache` or `SceneTextLayoutCache` into
  `SceneControllerPaintCandidateStage` - wrong dependency direction because
  committed admission would depend on render-local cache lifecycle.
- fixing only `_stageSelectedSupplements(...)` - incomplete because
  snapshot-local fallback would keep direct heavy snapshot bounds.
- leaving `enumerateSnapshotPaintCandidates(...)` as the owner and only
  memoizing inside the function - wrong cohesion because the bounds source
  would remain implicit and hard to guard structurally.
- adding a new `SceneStoreControllerSpatialAccess` helper - forbidden by the
  sealed controller helper-surface guardrail and unnecessary because
  `queryPaintCandidates(...)` can already return committed paint bounds.
- broad invalidation or unconditional spatial index rebuilds - wrong tradeoff
  because committed ordinary admission already has a precise spatial owner.
- approximating text/path bounds with cheap heuristics - wrong behavior because
  candidate admission must remain correct for culling and selection visibility.
- moving snapshot-local fallback through the committed spatial index when the
  frame snapshot diverges - violates frame authority and can mix stale
  committed candidate data into a non-committed frame.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- The problem is a paint-candidate admission ownership defect.
- The owning level is the main-scene render-read admission path: committed
  selected supplements must use committed spatial admission data, while
  snapshot-local fallback must use a snapshot-local admission bounds source.
- The problem does not belong to node drawing, selection drawing, public
  snapshot schema, or render-resolution caches.

#### Selected Architectural Form

- Establish `paint admission bounds source` as an explicit internal contract.
- Committed selected supplements read base `paintBoundsWorld` from the existing
  committed spatial paint index by calling the already allowed
  `SceneStoreController.queryPaintCandidates(...)` surface with a
  preview-shifted selected visibility query and matching the returned spatial
  candidates by selected `nodeId`.
- Snapshot-local enumeration uses one bounded snapshot-local admission bounds
  source/cache. The enumerator receives or owns that source explicitly and
  never calls `nodeSnapshotPaintBoundsWorld(...)`, text measurement, or SVG
  path parsing directly.
- Snapshot-local admission cache entries are keyed by:
  `nodeId`, `instanceRevision`, and a geometry validity key that includes every
  snapshot field that can affect base paint bounds.
- Preview deltas are not part of the base bounds cache key. They are applied
  per frame by shifting the resolved base bounds.
- Late render resolution remains unchanged: visible candidates still resolve
  text layout and render geometry through the render layer after admission.

#### Owning Layer or Module

- committed base paint bounds:
  `lib/src/core/scene_spatial_index.dart` and
  `lib/src/controller/internal/spatial_index_cache.dart`
- committed read facade:
  `lib/src/controller/scene_store_controller.dart`
- committed selected supplement staging:
  `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart`
- snapshot-local admission bounds source:
  `lib/src/core/snapshot_paint_admission_bounds.dart`, next to
  `scene_snapshot_paint_candidates.dart` and `node_geometry.dart`, because it
  consumes contract snapshots and core geometry policy without depending on
  render, controller, or interactive layers
- frame branch owner:
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- render-resolution caches:
  remain in `lib/src/render/**`

#### Dependency Direction

- `interactive` may depend on `controller`, `core`, and `contract`.
- `controller` may depend on `core` and `contract`.
- `core` may depend on `contract`.
- `render` may depend on `core` and `contract`.
- `core` must not depend on `render`, `controller`, `interactive`, or `view`.
- committed selected supplement staging may call the committed store facade for
  spatial paint bounds but must not call render caches.
- snapshot-local enumeration may call the snapshot-local admission bounds
  source but must not call committed spatial data when the frame snapshot is
  not committed-authoritative.

#### State and Data Ownership

- `SceneSpatialIndex` remains the only committed storage owner for committed
  coarse paint-candidate bounds.
- The snapshot-local admission bounds cache stores only derived base paint
  bounds for snapshot nodes; it does not own scene state, render geometry
  entries, text painters, paths, or preview state.
- `SceneViewFramePreview` remains the owner of frozen per-frame preview deltas.
- Render geometry caches remain render-stage caches and do not become
  admission caches.
- Public snapshots remain raw immutable boundary values without stored derived
  paint bounds.

#### Entry and Exit Boundaries

- Entry: `ScenePainterFrameOwner.createPrepared(...)` constructs a
  `ScenePaintCandidateQuery` from the captured frame read.
- Committed exit: `SceneControllerPaintCandidateStage.prepareCommittedPaintPlan`
  returns `ScenePaintCandidate` values whose ordinary and selected-supplement
  bounds both come from committed spatial paint bounds plus preview delta.
- Snapshot-local exit: `enumerateSnapshotPaintCandidates(...)` returns
  `ScenePaintCandidate` values whose base bounds come from the snapshot-local
  admission bounds source plus preview delta.
- Render exit: node drawing receives the same `ScenePaintCandidate` contract
  and resolves detailed render geometry only after candidate admission.

#### Permitted Extension Seam

- No new committed controller helper is permitted. Committed selected
  supplements must use the existing `queryPaintCandidates(...)`,
  `resolveSpatialCandidateSnapshot(...)`, and `resolveSnapshotNodeById(...)`
  helpers on the sealed `SceneStoreControllerSpatialAccess` surface.
- A focused snapshot-local admission bounds source/cache is permitted only in
  `lib/src/core/snapshot_paint_admission_bounds.dart`.
- A focused source-lock/structural test is permitted to forbid direct heavy
  snapshot geometry from admission modules.
- Diagnostic benchmark probes may observe production-owner counters but must
  not introduce benchmark-only render state or store owners.

#### Rejected Alternatives

- Add derived bounds to `NodeSnapshot` - rejected because it changes the public
  document boundary and makes derived layout output look like document state.
- Share `RenderGeometryCache` with admission - rejected because admission would
  depend on render cache lifecycle and blur late render resolution with coarse
  culling.
- Use committed spatial index for snapshot-local fallback - rejected because
  snapshot-local frames are authoritative to their captured snapshot, not the
  current committed store.
- Keep `nodeSnapshotPaintBoundsWorld(...)` in admission and rely on tests only
  for common cases - rejected because the heavy work remains available at the
  wrong layer.
- Add broad invalidation or cache-size tuning - rejected because it does not
  remove heavy work from per-node admission.
- Add a lookup-by-node-id helper to `SceneStoreControllerSpatialAccess` -
  rejected because the surface is mechanically sealed and the existing spatial
  query helper can serve selected supplements without violating guardrails.

#### Why This Level Is Correct

- Mechanical trace shows the heavy snapshot-bounds helper has only two
  production callers: committed selected supplements and snapshot-local
  enumeration.
- Ordinary committed candidates already use the desired committed owner shape:
  stored spatial paint bounds are queried through the committed store facade.
- Snapshot-local fallback cannot safely use committed spatial data, so it needs
  a bounded snapshot-local source rather than a shortcut through the committed
  store.
- Keeping detailed text/layout/path resolution in render preserves the existing
  architecture while removing pre-cull heavy work from admission.

### 4B. Architecture Decision Gate

Not used. Section 4A locks the owner, seam, dependency direction, state
ownership, and verification strategy.

## 5. Locked Decisions

1. The successor seam is named paint-admission bounds source. It has one
   committed implementation backed by the existing spatial paint query surface
   and one snapshot-local implementation backed by a bounded snapshot admission
   cache.
2. Committed selected supplements must stop calling
   `nodeSnapshotPaintBoundsWorld(...)` and must use committed spatial paint
   bounds returned by `queryPaintCandidates(...)` plus frame preview delta.
3. Snapshot-local enumeration must stop calling
   `nodeSnapshotPaintBoundsWorld(...)` directly and must use the snapshot-local
   admission bounds source plus frame preview delta.
4. The snapshot-local cache key must include `nodeId`, `instanceRevision`, and
   a geometry validity key. `nodeId + instanceRevision` alone is insufficient.
5. The snapshot-local geometry validity key must cover all fields that affect
   paint bounds for every supported snapshot family:
   transform, size, text layout inputs, rect stroke inputs, stroke points and
   thickness, line endpoints and thickness, path SVG data, path fill rule, and
   path stroke inputs.
6. Preview delta is applied outside the base bounds cache and is not included
   in cache validity.
7. Structural proof must forbid direct `TextLayoutRequest`, `.measure()`,
   `buildCenteredSvgPathGeometry(...)`, and `nodeSnapshotPaintBoundsWorld(...)`
   usage from admission modules except inside the explicitly allowed
   snapshot-local bounds source and lower-level geometry helpers.
8. `nodeSnapshotPaintBoundsWorld(...)` may remain available for non-admission
   core geometry use, validation, and tests, but it must no longer be a
   production admission dependency.
9. `INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE` is the canonical invariant id for
   this contract.
10. The owning source-lock proof file for
    `INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE` is
    `test/render/scene_painter_bounds_contract_test.dart`.
11. `ARCHITECTURE.md` must describe the final checked-in paint-admission split
   after the implementation lands.
12. Diagnostic load-profile proof is supporting evidence only; required proof
    remains deterministic owner-level tests and structural guardrails.

## 6. Result Requirements

1. Per-node paint-candidate admission in committed selected supplements cannot
   invoke snapshot text measurement or SVG path parsing.
2. Per-node paint-candidate admission in snapshot-local enumeration cannot
   invoke snapshot text measurement or SVG path parsing directly from the
   enumerator.
3. Ordinary committed candidates, committed selected supplements, and selected
   background supplements all use the same committed spatial paint-bounds
   source when the frame snapshot is committed-authoritative.
4. Snapshot-local fallback remains frame-authoritative and never mixes
   committed spatial entries into a divergent snapshot frame.
5. Snapshot-local admission cache hits reuse base paint bounds for unchanged
   snapshot geometry and rebuild when any paint-bounds-affecting field changes.
6. Preview movement changes candidate position by shifting resolved base bounds
   without rebuilding the base snapshot-local cache entry.
7. Render-side text layout and path geometry still happen only for admitted
   candidates during render resolution and drawing.
8. Unsupported or non-finite snapshot geometry remains safely rejected or
   converted to `Rect.zero` according to existing geometry policy.
9. The final structure is mechanically guarded so later direct heavy calls from
   admission fail tests.

## 7. Execution Order and Gates

### Required Order

- First add failing structural proof around admission modules and failing
  behavioral reproducers for selected-supplement and snapshot-local text/path
  admission.
- Then add the stage-local committed spatial paint-bounds query usage and
  migrate selected supplements onto it without changing the sealed controller
  helper surface.
- Then add the snapshot-local admission bounds source/cache and migrate
  snapshot-local enumeration onto it.
- Then retire direct admission calls to `_snapshotPaintBoundsWorld(...)` /
  `nodeSnapshotPaintBoundsWorld(...)` and tighten structural tests.
- Then add invariant registry coverage, architecture/changelog updates, and
  diagnostic benchmark probes.
- Final broad verification runs only after all slices are integrated.

### Successor Seam and Retirement Gates

- Successor seam:
  paint-admission bounds source.
- Committed consumer migration gate:
  `_stageSelectedSupplements(...)` must use committed spatial paint bounds from
  the existing `queryPaintCandidates(...)` surface and must not contain
  `_snapshotPaintBoundsWorld(...)`,
  `nodeSnapshotPaintBoundsWorld(...)`, `TextLayoutRequest`, `.measure()`, or
  `buildCenteredSvgPathGeometry(...)`.
- Snapshot-local consumer migration gate:
  `enumerateSnapshotPaintCandidates(...)` must depend on the snapshot-local
  admission bounds source and must not contain direct heavy snapshot geometry
  calls.
- Shared helper retirement gate:
  private `_snapshotPaintBoundsWorld(...)` helpers inside admission modules are
  removed or made unreachable from production admission.
- Registry/documentation gate:
  the invariant registry, `ARCHITECTURE.md`, `CHANGELOG.md`, `PLAN.md`, and
  this step document match the final code state before final verification.

### Deferred Broad Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=build/verification/changed_paths_step_22.txt`
  is reserved for the final integrated gate.
- `dcm calculate-metrics` on every new production file under `lib/**` and any
  substantially rewritten production hotspot is reserved until production
  implementation lands.
- Diagnostic smoke profile run is reserved until production probes are wired:
  `dart run tool/bench/run_load_profiles.dart --profile=smoke --output=build/bench/load_profiles_smoke_after_paint_admission_bounds.json`.

## 8. File Map

### Implementation Files

- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart`
- `lib/src/core/scene_snapshot_paint_candidates.dart`
- `lib/src/core/node_geometry.dart`
- `lib/src/core/snapshot_paint_admission_bounds.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`

### Test Files

- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/controller/core/scene_controller_spatial_index_test.dart`
- `test/core/scene_spatial_index_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/core/snapshot_paint_admission_bounds_test.dart`
- `test/tool/invariant_coverage_tool_test.dart`
- `test/tool/bench_run_load_profiles_test.dart`

### Fixtures and Supporting Data

- `tool/bench/baselines/load_profiles_smoke_baseline.json`
- `tool/bench/baselines/load_profiles_full_baseline.json`

### Registry, Inventory, and Workflow Files

- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_22_paint_admission_bounds_source_contract.md`
- `tool/bench/load_profile_policy.dart`
- `tool/bench/load_profiles_cases_test.dart`
- `tool/bench/run_load_profiles.dart`
- `tool/bench/baselines/load_profiles_smoke_baseline.json`
- `tool/bench/baselines/load_profiles_full_baseline.json`
- `tool/run_tool_tests.dart`
- `tool/run_verification_preset.dart`
- `tool/check_guardrails.dart`
- `tool/check_import_boundaries.dart`
- `tool/lsp_trace_symbol.dart`

### Analysis Area

- LSP traces for:
  `SceneViewMainSceneRenderRead.preparePaintPlan`,
  `SceneControllerSceneViewMainSceneRenderRead.preparePaintPlan`,
  `nodeSnapshotPaintBoundsWorld`,
  `SpatialIndexCache.writeQueryPaintCandidates`
- import-boundary and guardrail checks
- DCM metrics on new or substantially rewritten production files

## 9. Implementation Rules

### Protected Invariants

- frame-authoritative rendering paints from one captured `SceneViewFrameRead`
  and one frozen frame preview
- committed fast-path admission uses committed spatial data only when the
  frame snapshot matches the committed snapshot
- snapshot-local fallback remains authoritative to the active frame snapshot
- render geometry and text layout remain late render-resolution work
- public snapshots remain immutable document boundary values and do not store
  derived paint bounds
- committed spatial paint bounds remain owned by the committed spatial index
- bounded snapshot-local admission cache must be explicit and validity-keyed

### Required Proof

- behavioral proof: selected text/path supplements at the viewport edge use
  committed spatial paint bounds without snapshot text measurement or SVG path
  parsing.
- behavioral proof: snapshot-local offscreen text/path candidates do not run
  heavy work from enumeration after the snapshot-local admission cache is warm.
- behavioral proof: snapshot-local cache invalidates when text/path geometry
  fields change even when `nodeId` and `instanceRevision` are unchanged.
- behavioral proof: preview delta shifts admission bounds without forcing a
  base-bounds rebuild.
- structural proof: admission modules do not directly reference
  `TextLayoutRequest`, `.measure()`, `buildCenteredSvgPathGeometry(...)`, or
  `nodeSnapshotPaintBoundsWorld(...)` outside the allowed bounds-source owner.
- structural proof: committed selected supplement staging uses the committed
  store/spatial paint-bounds seam, not snapshot geometry helpers.
- for bug-fix slices: add one failing reproducer first, plus neighboring guard
  tests, before changing implementation.

### Allowed Change Surface

- stage-local committed spatial paint-bounds lookup through existing
  `queryPaintCandidates(...)` results, without adding public helper methods
- focused snapshot-local admission bounds source/cache in
  `lib/src/core/snapshot_paint_admission_bounds.dart`
- focused structural and behavioral tests at render/core/controller owner
  surfaces
- invariant registry and architecture/changelog/plan updates required by the
  new contract
- diagnostic benchmark probes that observe production-owner behavior

### Forbidden Moves

- no public snapshot fields for derived bounds
- no new public member on `SceneStoreControllerSpatialAccess`
- no render-cache dependency from controller or interactive admission code
- no committed spatial dependency from snapshot-local fallback
- no benchmark-only committed store, benchmark-only render state, or
  benchmark-only admission implementation
- no heuristic culling bounds that differ from existing paint bounds semantics
- no broad unrelated refactor of render, controller, interaction, or view
  owner families
- no weakening of existing selected supplement ordering, background paint
  ordering, stale locator rejection, or preview freeze behavior

### Optional: Recognition Forms That Must Be Supported

- text, path, image, rect, stroke, and line snapshot families
- background-layer and content-layer paint candidates
- selected and ordinary candidate visibility rectangles
- zero preview and non-zero preview deltas
- invalid path data and non-finite geometry sanitization according to existing
  geometry policy

### Optional: Allowed Forms That Are Not Violations

- `nodeSnapshotPaintBoundsWorld(...)` may remain in lower-level core geometry
  helpers, validation paths, tests, or the explicitly allowed snapshot-local
  bounds source.
- `TextLayoutRequest.measure()` may remain in text validation,
  `TextNodeLayoutState`, and the explicitly allowed snapshot-local bounds
  source.
- `buildCenteredSvgPathGeometry(...)` may remain in render geometry builder,
  path-node runtime cache, lower-level geometry helpers, and the explicitly
  allowed snapshot-local bounds source.

### Optional: Resolution Rules

- If the existing committed spatial query cannot resolve a selected node or
  returns non-finite bounds, the supplement is skipped using the same candidate
  rejection semantics as ordinary committed paint candidates.
- If snapshot-local bounds source cannot resolve finite paint bounds, the
  snapshot-local candidate is skipped.
- `SceneControllerSceneViewMainSceneRenderRead` owns the
  `SnapshotPaintAdmissionBoundsCache` instance for production snapshot-local
  fallback. The cache is bounded and validity-keyed; it is disposed with that
  render-read owner and is not shared with render geometry caches.

## 10. Vertical Slices

### Slice 1. [ ] Characterize Heavy Admission And Lock Structural Boundaries

#### Slice Contract

Add failing tests that prove the current bug class and lock the structural rule
before implementation changes.

#### Change

- add or extend source-level tests in
  `test/render/scene_painter_bounds_contract_test.dart` to require an explicit
  paint-admission bounds source and forbid direct heavy snapshot geometry from
  admission modules
- add behavioral reproducers in
  `test/render/scene_painter_frame_contract_test.dart` for committed selected
  text/path supplement admission and snapshot-local offscreen text/path
  admission
- add neighboring guard tests for ordinary committed candidates and selected
  background supplements so the existing fast path and background behavior stay
  locked

#### Behavioral Verification

- run the new targeted render/core tests and confirm they fail for the current
  implementation for the expected reason before production edits

#### Structural Verification

- `test/render/scene_painter_bounds_contract_test.dart` fails while
  `_stageSelectedSupplements(...)` or `enumerateSnapshotPaintCandidates(...)`
  directly reference snapshot paint bounds or heavy geometry helpers

#### Fixtures Used

- inline test scenes with text and path nodes in background/content layers

#### Positive Scenarios

- ordinary committed candidates keep using `candidate.paintBoundsWorld`
- selected background supplements retain committed order and visibility
  behavior

#### Negative Scenarios

- selected text/path supplement currently reaches snapshot bounds
- snapshot-local offscreen text/path enumeration currently reaches snapshot
  bounds

#### Closure Evidence

- targeted tests fail before implementation and pass after later slices

### Slice 2. [ ] Move Committed Selected Supplements To Spatial Paint Bounds

#### Slice Contract

Selected supplements in committed fast path use the same committed spatial
paint-bounds owner as ordinary candidates.

#### Change

- add a stage-local helper that queries
  `SceneStoreController.queryPaintCandidates(...)` using
  `visibilityRect.shift(-preview.deltaForNode(token.nodeId))` and matches the
  returned committed spatial candidates by selected `nodeId`
- keep `SceneSpatialIndex`, `SpatialIndexCache`, and
  `SceneStoreControllerSpatialAccess` public surfaces unchanged
- update `_stageSelectedSupplements(...)` to resolve selected node order and
  snapshot node identity as it does today, but read base paint bounds from the
  matched committed spatial candidate before applying preview delta
- keep existing selected-order cache behavior and background/content merge
  ordering

#### Behavioral Verification

- selected text/path supplements at the visibility edge are admitted or skipped
  based on committed spatial paint bounds without snapshot geometry work
- selected background supplements still resolve from the active committed
  frame and preserve order
- stale selected supplements remain dropped when committed query or active
  frame resolution fails

#### Structural Verification

- `_stageSelectedSupplements(...)` contains no `_snapshotPaintBoundsWorld(...)`,
  `nodeSnapshotPaintBoundsWorld(...)`, `TextLayoutRequest`, `.measure()`, or
  `buildCenteredSvgPathGeometry(...)`
- committed selected supplements use existing
  `SceneStoreController.queryPaintCandidates(...)` results, not render caches
  or new controller helper methods
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` remains
  green, proving the sealed helper surface was not expanded
- targeted command:
  `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`

#### Fixtures Used

- existing selected supplement tests in
  `test/render/scene_painter_frame_contract_test.dart`
- new text/path selected edge cases

#### Positive Scenarios

- selected node outside viewport but inside visibility rect is included
- selected node outside visibility rect is skipped
- selected node already accepted as ordinary candidate is deduplicated

#### Negative Scenarios

- missing selected node spatial candidate returns no supplement
- non-finite committed paint bounds returns no supplement

#### Closure Evidence

- targeted controller/render tests pass
- source structural test proves no direct heavy snapshot bounds remain in the
  committed selected supplement path

### Slice 3. [ ] Introduce Snapshot-Local Admission Bounds Source

#### Slice Contract

Snapshot-local enumeration resolves base paint bounds through one bounded
snapshot-local admission bounds source with strong validity semantics.

#### Change

- add `lib/src/core/snapshot_paint_admission_bounds.dart` as the focused
  `core` owner for snapshot-local admission bounds and validity keys
- store base `paintBoundsWorld` values keyed by `nodeId`,
  `instanceRevision`, and geometry validity key
- use existing geometry formulas for correctness, but isolate any text
  measurement and SVG parsing inside the new bounds-source owner
- expose deterministic debug probes for build/hit/evict behavior used by tests
  and diagnostics
- prove the cache rebuilds when paint-bounds-affecting fields change even if
  id/revision are reused

#### Behavioral Verification

- repeated snapshot-local enumeration of unchanged text/path snapshots hits
  cached base bounds
- changing text layout input or path SVG/fill/stroke input rebuilds bounds even
  with the same id/revision
- invalid path data still yields safe zero or skipped candidate behavior
- line, stroke, rect, image, text, and path snapshots preserve existing bounds
  behavior

#### Structural Verification

- direct heavy work is allowed only inside the new snapshot-local bounds source
  and lower-level geometry helpers
- new production file passes import boundaries and DCM metrics

#### Fixtures Used

- focused snapshot fixtures with repeated id/revision and changed geometry
  payloads
- offscreen text/path fixtures for culling behavior

#### Positive Scenarios

- unchanged text/path snapshot second enumeration is a cache hit
- preview delta does not invalidate base bounds

#### Negative Scenarios

- changed geometry payload invalidates the cache entry
- unsupported or non-finite geometry is rejected safely

#### Closure Evidence

- targeted core/render tests pass
- DCM metrics for the new production file are green

### Slice 4. [ ] Migrate Snapshot-Local Enumeration And Retire Direct Admission Bounds

#### Slice Contract

`enumerateSnapshotPaintCandidates(...)` becomes a thin enumerator over a
snapshot-local admission bounds source and no longer owns heavy geometry work.

#### Change

- update `enumerateSnapshotPaintCandidates(...)` to request base bounds from
  the snapshot-local admission bounds source
- apply preview delta after base bounds resolution
- avoid duplicate base-bounds resolution for accepted candidates within one
  enumeration pass
- wire the `SnapshotPaintAdmissionBoundsCache` instance through
  `SceneControllerSceneViewMainSceneRenderRead` so snapshot-local fallback can
  reuse base bounds across frames
- remove private `_snapshotPaintBoundsWorld(...)` helpers from admission
  modules after consumers migrate

#### Behavioral Verification

- snapshot-local offscreen text/path nodes do not invoke direct heavy work from
  the enumerator
- accepted snapshot-local candidates carry correct preview-shifted
  `paintBoundsWorld`
- selected snapshot-local nodes still use `visibilityRect` while ordinary nodes
  use `viewportRect`
- background-layer and content-layer order remains unchanged

#### Structural Verification

- `scene_snapshot_paint_candidates.dart` contains no direct
  `nodeSnapshotPaintBoundsWorld(...)`, `TextLayoutRequest`, `.measure()`, or
  `buildCenteredSvgPathGeometry(...)`
- admission modules contain no private `_snapshotPaintBoundsWorld(...)` helper
  unless it delegates only to the explicit bounds source

#### Fixtures Used

- snapshot-local frame-read tests with divergent frame snapshot
- selected and ordinary text/path/background candidates

#### Positive Scenarios

- accepted visible text/path candidate paints normally after late render
  resolution
- repeated snapshot-local frame reuses base bounds when geometry is unchanged

#### Negative Scenarios

- offscreen text/path candidate is rejected before render resolution
- changed geometry payload cannot reuse stale cached bounds

#### Closure Evidence

- targeted render tests pass
- structural source-lock tests pass

### Slice 5. [ ] Register Invariants, Architecture Docs, And Diagnostics

#### Slice Contract

The final paint-admission bounds contract is documented and mechanically
declared as a repository invariant, and diagnostics can observe the new
production-owner behavior.

#### Change

- add `INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE` coverage in
  `tool/invariant_registry.dart`
- update `ARCHITECTURE.md` render flow, render invariants, and mechanical
  enforcement sections to describe the committed/snapshot-local admission
  bounds split
- add an `Unreleased` `CHANGELOG.md` entry for the performance fix
- update `PLAN.md` and this step checkbox state as slices close
- extend `tool/bench/load_profile_policy.dart`,
  `tool/bench/load_profiles_cases_test.dart`,
  `test/tool/bench_run_load_profiles_test.dart`, and both load-profile
  baseline JSON files so diagnostics report snapshot-admission build/hit/evict
  deltas and selected-supplement committed-bounds reuse through production
  owners

#### Behavioral Verification

- invariant coverage tests pass
- benchmark policy tests pass with the new required probe keys
- diagnostic smoke profile emits the new or updated probe keys when run

#### Structural Verification

- invariant registry proof points to executable tests or tools reachable from
  the required verification preset
- `test/render/scene_painter_bounds_contract_test.dart` contains the matching
  `// INV:INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE` marker

#### Fixtures Used

- existing invariant and benchmark tool fixtures

#### Positive Scenarios

- required proof surfaces are reachable from `required_code_change`
- diagnostic probes consume production owners only

#### Negative Scenarios

- missing invariant marker or unreachable proof fails invariant coverage
- missing diagnostic probe key fails benchmark policy tests

#### Closure Evidence

- invariant/tool tests pass
- architecture and changelog reflect final checked-in code

## 11. Final Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=build/verification/changed_paths_step_22.txt`
- `dcm calculate-metrics` for every new production file under `lib/**`
- `dcm calculate-metrics` for legacy production hotspots only if they receive a
  substantial rewrite or a large new unit
- `dart run tool/bench/run_load_profiles.dart --profile=smoke --output=build/bench/load_profiles_smoke_after_paint_admission_bounds.json`
  after diagnostic probes are wired
- targeted LSP traces after implementation:
  `nodeSnapshotPaintBoundsWorld`,
  `SceneViewMainSceneRenderRead.preparePaintPlan`,
  and `SpatialIndexCache.writeQueryPaintCandidates`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`

## 12. Acceptance Criteria

- committed selected supplements no longer perform snapshot text layout or SVG
  path parsing in admission
- snapshot-local enumeration no longer performs direct heavy snapshot geometry
  work from the enumerator
- ordinary committed candidates, selected committed supplements, and selected
  background supplements use the same committed spatial paint-bounds source
- snapshot-local fallback has one explicit bounded admission bounds source with
  strong validity-key semantics
- preview delta handling remains frame-local and does not invalidate base
  bounds
- render-side text layout and geometry resolution remain separate and late
- public snapshots and serialization formats are unchanged
- architecture docs, invariant registry, tests, and diagnostics match the final
  checked-in form
- required verification, relevant DCM metrics, import boundaries, guardrails,
  and targeted diagnostic profile complete successfully
