# Change Contract

## 1. Change Mandate

Make main-scene paint work bounded and reuse-oriented so stable over-capacity
frames stop thrashing hot render caches, selection halo compositing always
uses tight layer bounds, dense grid rendering iterates only planned visible
lines, and the existing benchmark surfaces can measure those improvements
without changing the accepted target architecture.

## 2. Change Boundary

### Included in the Change

- introduce one shared render-local scan-resistant cache policy owner under
  `lib/src/render/cache/**` and migrate
  `RenderGeometryCache`,
  `SceneTextLayoutCache`,
  `SceneStrokePathCache`, and
  `ScenePathMetricsCache` onto that owner while keeping per-cache key and
  payload semantics local
- add failing deterministic reproducer tests for steady-state cache churn on a
  stable ordered working set larger than cache capacity, plus neighboring
  guard tests for unchanged single-entry reuse and invalidation boundaries
- introduce a render-local selection halo compositing helper that computes
  tight layer bounds from the halo style and shape geometry and migrate
  rect/path halo masking to that helper
- add failing deterministic selection tests for `saveLayer(null, ...)` on the
  real paint path, plus neighboring visual guard tests for rect/path halo
  parity and preview-delta parity
- reshape `SceneGridAxisPlan` so the plan itself owns bounded iteration shape
  and both direct grid draw and static-layer recording consume that same plan
- add failing deterministic grid tests for dense-grid over-iteration, plus
  neighboring guard tests for camera-phase stride stability and static-cache
  hit behavior
- extend `tool/bench/**` only where needed so diagnostics can observe
  main-scene cache stability, bounded selection compositing, and bounded grid
  work on production owners
- register new invariant coverage for cache retention, selection compositing,
  and grid iteration ownership, and update `ARCHITECTURE.md`,
  `CHANGELOG.md`, `PLAN.md`, and this step document with the final state

### Not Included in the Change

- no split of `SceneViewRenderState`, `SceneViewRuntime`, or the mixed
  view/runtime render seam
- no changes to `view/**`, `interactive/**`, `controller/**`, public API
  exports, serialization contracts, or document-model ownership
- no blanket cache-capacity increase, cache-size tuning, or per-callsite cache
  bypass as the primary fix
- no migration of selection halo rendering into the overlay painter
- no benchmark-only render owners, benchmark-only committed-scene seams, or
  machine-dependent required-CI timing gates
- no full removal of offscreen halo masking semantics beyond replacing
  unbounded layer bounds with tight bounds

## 3. Surrounding Code Review

### Inspected Artifacts

- `docs/adr/0001_target_engine_architecture.md` — target architecture keeps
  main-scene rendering on one atomic frame read and does not authorize moving
  render support policy into `view/**` or benchmark-only seams
- `docs/target_architecture/families/view_runtime_and_render_seam.md` — the
  render support cluster under the main-scene painter path is the correct
  owner bucket for cache, selection, and grid work policy
- `ARCHITECTURE.md` — render remains a read-only layer and repository policy
  requires mechanically enforced invariants instead of prose-only reminders
- `lib/src/render/scene_painter.dart` — `ScenePainter` captures one frame read
  and owns the integrated main-scene paint path used by the defects
- `lib/src/render/scene_painter_frame.dart` — geometry and text-layout
  resolution are performed during the frame-owned hot path
- `lib/src/render/render_geometry_cache.dart` — geometry cache currently uses
  per-file `LinkedHashMap` LRU eviction and exposes debug build/hit/evict
  counters
- `lib/src/render/cache/scene_text_layout_cache.dart` — text-layout cache
  repeats the same per-file access-ordered `LinkedHashMap` LRU shape
- `lib/src/render/cache/scene_stroke_path_cache.dart` — stroke-path cache
  repeats the same per-file access-ordered `LinkedHashMap` LRU shape
- `lib/src/render/cache/scene_path_metrics_cache.dart` — path-metrics cache
  repeats the same per-file access-ordered `LinkedHashMap` LRU shape
- `lib/src/render/scene_render_caches.dart` — render cache lifecycle is
  already centralized at the render owner level and is the closest local
  precedent for a shared cache-support seam
- `lib/src/render/scene_painter_selection.dart` — rect and closed-path halo
  masking currently call `canvas.saveLayer(null, Paint())` even though the
  geometry-owner rect/path bounds are already available at the call sites
- `lib/src/render/scene_grid_renderer.dart` — grid stride is planned, but the
  current axis loop still walks each raw cell position and therefore preserves
  linear iteration cost on dense grids
- `lib/src/render/cache/scene_static_layer_cache.dart` — static background
  cache already records grid work counters and is the closest owner-local
  probe precedent for bounded grid work proof
- `lib/src/render/scene_painter_background.dart` — direct background draw and
  static cache hit the same `SceneGridRenderer` owner
- `tool/bench/load_profile_policy.dart` — benchmark policy already has
  explicit probe-key contracts for cache, selection, and grid diagnostics
- `tool/bench/load_profiles_cases_test.dart` — benchmarks already use
  production owners, but current cache and selection probes do not yet model
  the over-capacity scan-thrash and bounded-layer cases needed by this step
- `tool/invariant_registry.dart` — existing invariant coverage tracks render
  proof contours, but does not yet register the three owner-local bounded-work
  constraints this step introduces
- `test/render/render_geometry_cache_test.dart` — geometry cache tests prove
  reuse and invalidation but currently encode small LRU scenarios rather than
  steady-state over-capacity scans
- `test/render/scene_text_layout_cache_test.dart` — text cache tests prove
  reuse and currently encode LRU eviction semantics that will need to move to
  scan-resistant expectations
- `test/render/scene_stroke_path_cache_test.dart` — stroke cache tests prove
  reuse and currently encode LRU eviction semantics that will need to move to
  scan-resistant expectations
- `test/render/scene_path_metrics_cache_test.dart` — path-metrics cache tests
  prove reuse and currently encode LRU eviction semantics that will need to
  move to scan-resistant expectations
- `test/render/scene_render_caches_test.dart` — integrated render-cache owner
  tests already prove lifecycle invalidation and are the closest place for an
  owner-level steady-state cache proof
- `test/render/scene_painter_test.dart` — real painter tests already use
  `TestRecordingCanvas` for `saveLayer` counting and own the visual parity
  branches for selection rendering
- `test/render/scene_painter_bounds_contract_test.dart` — source-level render
  structure tests already own the selection-renderer structural seam and
  currently lock the wrong `saveLayer(null, Paint())` behavior
- `test/render/scene_grid_renderer_test.dart` — grid tests already prove
  stride stability and expose current loop waste through owner-local work
  stats
- `test/render/scene_static_layer_cache_test.dart` — static background cache
  tests already prove grid picture reuse and expose owner-local work counters
- `test/tool/bench_run_load_profiles_test.dart` and
  `test/tool/bench_diff_load_profiles_test.dart` — tool tests already own
  source-level benchmark case/probe wiring and diff schema validation
- `test/tool/invariant_coverage_tool_test.dart` — invariant registry changes
  must remain mechanically covered

### Current Entry Path

- cache hot path:
  `ScenePainter.paint(...)` ->
  `ScenePainterShell.paint(...)` ->
  `ScenePainterNodeRenderer._drawVisibleNodes(...)` ->
  `ScenePainterFrameOwner.resolveNodePaintData(...)` ->
  `RenderGeometryCache.get(...)` /
  `SceneTextLayoutCache.getOrBuild(...)`
- selection hot path:
  `ScenePainter.paint(...)` ->
  `ScenePainterShell.paint(...)` ->
  `ScenePainterSelectionRenderer.drawSceneSelection(...)` ->
  `_drawRectHalo(...)` / `_drawPathHalo(...)`
- grid hot path:
  `ScenePainterBackgroundOwner.paint(...)` ->
  `SceneGridRenderer.draw(...)` / `SceneStaticLayerCache._recordGridPicture(...)`
  -> `SceneGridRenderer.drawPlan(...)` -> `_drawAxisLines(...)`
- diagnostic measurement path:
  `tool/bench/load_profiles_cases_test.dart` ->
  production `ScenePainter` / cache owners / `SceneGridRenderer` probes ->
  `tool/bench/load_profile_policy.dart` and
  `tool/bench/diff_load_profiles.dart`

### Current Owner

- render cache payload owners:
  `RenderGeometryCache`,
  `SceneTextLayoutCache`,
  `SceneStrokePathCache`, and
  `ScenePathMetricsCache`
- selection compositing owner:
  `ScenePainterSelectionRenderer` in `lib/src/render/scene_painter_selection.dart`
- grid iteration owner:
  `SceneGridRenderer`
- downstream diagnostic owner:
  `tool/bench/**`, which already consumes production owners and must stay a
  pure observer

### Adjacent Abstractions

- `SceneRenderCaches` — render-local lifecycle owner adjacent to the cache
  policy seam
- `ScenePainterFrameOwner` — frame-local resolver adjacent to geometry and
  text-layout cache consumption
- `ScenePainterNodeRenderer` — stable ordered candidate traversal that
  triggers the cache-thrash defect
- `ScenePainterBackgroundOwner` — direct background draw owner adjacent to
  grid planning
- `SceneStaticLayerCache` — static grid picture owner adjacent to grid work
  probes
- `ScenePainterBoundsContractTest` source-level seams — closest structural
  proof surface for keeping the main-scene render support cluster honest

### Existing Tests

- `test/render/render_geometry_cache_test.dart` — geometry cache reuse,
  validity, and invalidation behavior
- `test/render/scene_text_layout_cache_test.dart` — text-layout cache reuse,
  key semantics, and bounded capacity behavior
- `test/render/scene_stroke_path_cache_test.dart` — stroke-path cache reuse,
  invalidation, and bounded capacity behavior
- `test/render/scene_path_metrics_cache_test.dart` — path-metrics cache reuse,
  invalidation, and bounded capacity behavior
- `test/render/scene_render_caches_test.dart` — integrated render-cache owner
  lifecycle behavior
- `test/render/scene_painter_test.dart` — integrated main-scene painter
  behavior, save/restore balance, and selection branches
- `test/render/scene_painter_bounds_contract_test.dart` — source-level render
  seam and selection-renderer structure
- `test/render/scene_grid_renderer_test.dart` — direct grid plan/draw/work
  behavior
- `test/render/scene_static_layer_cache_test.dart` — static background grid
  work and cache behavior
- `test/tool/bench_run_load_profiles_test.dart` — benchmark case and probe
  contract wiring
- `test/tool/bench_diff_load_profiles_test.dart` — benchmark diff schema and
  probe diff behavior
- `test/tool/invariant_coverage_tool_test.dart` — invariant registry coverage

### Analogous Implementation Path

- `lib/src/render/scene_render_caches.dart` — the closest valid precedent for
  consolidating render-local support policy in one owner without moving it
  into `view/**` or `interactive/**`
- `lib/src/render/cache/scene_static_layer_cache.dart` together with
  `test/render/scene_static_layer_cache_test.dart` — the closest valid
  precedent for owner-local work counters and bounded-work proof on the real
  production path
- `test/render/scene_painter_bounds_contract_test.dart` — the closest valid
  precedent for source-level render support seam checks that make later drift
  mechanically visible
- `tool/bench/load_profiles_cases_test.dart` together with
  `test/tool/bench_run_load_profiles_test.dart` — the closest valid precedent
  for extending diagnostics without inventing benchmark-only production seams

### Governing Repository Rules

- repository instructions — fix the invariant at the owner that causes the
  defect and prefer executable repository-local enforcement over prose-only
  reminders
- repository instructions — when a touched file is already broad, reduce local
  entropy instead of making the file more mixed
- repository instructions — after code changes, run the required verification
  preset and keep heavyweight verification sequential
- `ARCHITECTURE.md` — render is a read-only layer and frame-authoritative
  rendering must keep one atomic frame read
- `docs/adr/0001_target_engine_architecture.md` — main-scene rendering stays
  on the controller-owned main-scene render read; this step must not reopen
  the view/runtime seam
- `docs/target_architecture/families/view_runtime_and_render_seam.md` — the
  main-scene surface and painter path is the locked owner bucket for these
  fixes
- `tool/invariant_registry.dart` — important engine constraints must be
  declared through executable invariant coverage

### Rejected Misleading Local Patterns

- increasing `maxEntries` without changing policy — wrong fix level because
  the steady-state ordered scan still degenerates once the working set exceeds
  capacity
- keeping four separate per-file `LinkedHashMap` LRU policies — wrong owner
  shape because the bug class repeats across four adjacent cache owners
- replacing `saveLayer(null, ...)` with ad hoc per-callsite math inside one
  large selection file only — wrong cohesion because bounded compositing
  should have one render-local helper seam
- changing only the `drawLine` branch in `SceneGridRenderer` while leaving the
  raw cell-by-cell loop intact — wrong fix level because iteration cost stays
  linear
- pushing cache or selection work policy into `SceneViewRenderSurface`,
  `SceneViewRuntimeHost`, or `SceneViewRenderState` — wrong seam because the
  target architecture keeps these defects inside the render support cluster
- adding benchmark-only render owners or benchmark-only fast paths — wrong
  owner and contrary to the accepted target architecture

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- The problem belongs to the main-scene render support cluster under
  `lib/src/render/**`, with `tool/bench/**` acting only as a downstream
  regression observer of those production owners.

#### Selected Architectural Form

- introduce one shared render-local cache policy owner at
  `lib/src/render/cache/scan_resistant_cache.dart`; it owns bounded
  scan-resistant retention policy only; the fixed policy form is one
  segmented two-queue design with
  `probationary` and `protected` segments,
  bounded total capacity,
  admission into `probationary` on first build,
  promotion into `protected` only after a subsequent reuse,
  demotion from `protected` back to `probationary` when protected capacity is
  exceeded, and eviction only from the probationary tail. Each cache owner
  keeps its own key semantics, payload build logic, and epoch-invalidated
  lifecycle
- introduce one focused render-local selection helper at
  `lib/src/render/selection_halo_compositing.dart`; it owns tight halo layer
  bounds and bounded masked layer execution, while
  `scene_painter_selection.dart` keeps selection semantics and branch routing
- reshape `SceneGridAxisPlan` inside `lib/src/render/scene_grid_renderer.dart`
  so the plan itself owns actual iteration shape
  (`first position`, `step`, and `iteration count` or equivalent bounded
  contract); both direct draw and static-layer recording consume that one plan
- keep `ScenePainter`, `ScenePainterShell`, `SceneViewRenderState`, and the
  main-scene/overlay seam unchanged; these fixes remain internal to the
  existing render support cluster and do not change the accepted target
  architecture
- extend `tool/bench/**` only as a consumer of the new production-owner
  probes and proof surfaces; benchmark policy must not own or duplicate any
  render work policy

#### Owning Layer or Module

- production owner layer:
  `lib/src/render/**`
- shared cache policy owner:
  `lib/src/render/cache/scan_resistant_cache.dart`
- bounded selection compositing owner:
  `lib/src/render/selection_halo_compositing.dart`
- bounded grid iteration owner:
  `lib/src/render/scene_grid_renderer.dart`
- downstream regression observer:
  `tool/bench/**`

#### Dependency Direction

- `ScenePainterFrameOwner`, `ScenePainterSelectionRenderer`, and
  `ScenePainterBackgroundOwner` continue to consume render-local support
  owners under `lib/src/render/**`
- render caches depend on the shared render-local cache policy helper; the
  helper must not depend back on any one cache owner
- `SceneStaticLayerCache` depends on `SceneGridRenderer` work-plan semantics;
  `SceneGridRenderer` must not depend on the static cache
- `tool/bench/**` depends on production render owners and test probes; the
  production render owners must not depend on benchmark code
- `view/**`, `interactive/**`, and `contract/**` remain unchanged consumers of
  the same main-scene render entrypoints

#### State and Data Ownership

- each render cache continues to own its entry keys, payloads, and explicit
  epoch-boundary invalidation behavior
- the shared scan-resistant cache helper owns retention metadata and bounded
  eviction policy only
- selection halo compositing helper owns only geometry-derived layer bounds,
  bounded layer execution, and no selection state
- `SceneGridAxisPlan` owns the bounded iteration shape for one axis; work
  counters derive from that plan instead of from a second independent loop
  model
- benchmark baselines and reports remain diagnostic artifacts owned by
  `tool/bench/**`

#### Entry and Exit Boundaries

- entry:
  existing main-scene paint and background paths beginning at
  `ScenePainter.paint(...)` and `ScenePainterBackgroundOwner.paint(...)`
- internal bounded-work boundaries:
  render cache `get`/`getOrBuild`,
  selection halo compositing helper calls,
  and `SceneGridAxisPlan` consumption in direct and cached grid draw
- exit:
  reusable cache payloads,
  bounded `saveLayer` invocations,
  bounded grid work stats,
  and benchmark probe outputs that describe those production-owner results

#### Permitted Extension Seam

- future render-support optimizations may extend the shared cache policy
  helper, selection compositing helper, or grid plan contract, but only
  inside `lib/src/render/**`
- benchmark policy may add downstream probes for these owners, but only by
  consuming production-owner counters and surfaces
- future target render-seam work may keep using these helpers from the
  main-scene render read, but must not move their policy into `view/**`

#### Rejected Alternatives

- keep four bespoke cache policies and patch each one separately —
  architectural duplication would remain in the same owner family
- expose frame tokens, traversal ids, or paint-order policy through
  `SceneViewRenderState` — wrong seam because cache retention remains an
  internal render support detail
- move selection halo masking to the overlay painter — wrong owner because the
  halo belongs to committed main-scene selection rendering
- keep current `SceneGridAxisPlan` and only skip more `drawLine` calls —
  wrong result because CPU iteration cost would remain unbounded
- rely on benchmark-only measurements without deterministic owner-local proof —
  wrong verification level because required CI must stay deterministic

#### Why This Level Is Correct

- all three defects are caused by policy that lives entirely inside the locked
  main-scene render support cluster, so fixing them there solves the class
  once without widening public seams
- the accepted target architecture explicitly keeps main-scene rendering on one
  controller-owned read and a downstream render support cluster, which matches
  this contract
- benchmarks already consume these production owners successfully, so the
  missing piece is better owner-local policy and better downstream probes, not
  a new architecture branch

## 5. Locked Decisions

1. This remains one umbrella step with four vertical slices:
   scan-resistant cache policy,
   bounded selection compositing,
   bounded grid iteration,
   and diagnostic measurement refresh.
2. The cache fix uses one shared render-local policy owner; per-cache
   retention implementations are not allowed to diverge again.
3. The shared cache helper uses exactly one segmented two-queue retention
   policy with `probationary` and `protected` segments; alternative policy
   families are out of scope for implementation in this step.
4. The selection fix keeps masked halo semantics and only bounds the offscreen
   layer; complete removal of `saveLayer` is not part of this step.
5. The grid fix changes the plan contract itself so planned work, draw work,
   and measured work remain the same concept.
6. This step introduces three owner-local invariants with fixed ids:
   `INV-ENG-RENDER-CACHE-SCAN-RESISTANT`,
   `INV-ENG-SELECTION-BOUNDED-COMPOSITING`, and
   `INV-ENG-GRID-BOUNDED-ITERATION`,
   instead of one broad catch-all invariant.
7. Documentation updates are limited to `ARCHITECTURE.md` and
   `CHANGELOG.md`; `README.md` and `API_GUIDE.md` remain unchanged because the
   public API and integration contract do not change.

## 6. Result Requirements

1. On a stable ordered working set larger than cache capacity, the second
   identical main-scene frame no longer degenerates into full rebuild churn
   for geometry, text-layout, stroke-path, or path-metrics payloads.
2. Main-scene selection halo rendering never issues `saveLayer(null, ...)`;
   every masked halo layer is bounded to the minimum geometry-derived area
   needed for the rendered result.
3. Dense grid rendering performs bounded iteration that matches the planned
   visible line count for both direct background draw and static grid picture
   recording.
4. Diagnostic load-profile outputs can show before/after changes for these
   three defect classes while continuing to use production owners only.

## 7. Execution Order and Gates

### Required Order

- Slice 1 must land before any benchmark refresh so the downstream cache case
  measures the final shared cache policy rather than a transitional state.
- Slice 2 must land before benchmark refresh so selection diagnostics can
  measure bounded versus unbounded layer behavior on the final production
  seam.
- Slice 3 must land before benchmark refresh so grid probes and baselines
  represent the bounded iteration contract rather than the raw loop.
- Slice 4 runs after production-owner slices are green and updates downstream
  probes, invariant coverage references, architecture/changelog text, and
  checked-in benchmark baselines.
- Within each slice, add the failing reproducer and neighboring guard tests
  first, then apply the minimum owner-side fix.

### Successor Seam and Retirement Gates

- `lib/src/render/cache/scan_resistant_cache.dart` succeeds the four local
  `LinkedHashMap` LRU policy copies.
  Retirement gate:
  all four caches consume the shared helper and
  `test/render/render_cache_policy_contract_test.dart` proves the local LRU
  copies are gone.
- `lib/src/render/selection_halo_compositing.dart` succeeds direct
  `saveLayer(null, Paint())` callsites in `scene_painter_selection.dart`.
  Retirement gate:
  `test/render/scene_painter_bounds_contract_test.dart` bans null bounds and
  `test/render/scene_painter_test.dart` keeps halo parity green.
- bounded `SceneGridAxisPlan` succeeds the raw cell-by-cell dense-grid scan.
  Retirement gate:
  `test/render/scene_grid_renderer_contract_test.dart` and
  `test/render/scene_static_layer_cache_test.dart` both prove aligned bounded
  work.

### Deferred Broad Verification

- run `dart run tool/run_verification_preset.dart run --preset=required_code_change`
  only at the final gate after all four slices are locally green
- run smoke/full benchmark capture and diff commands only at the final gate
  after production-owner slices and tool tests are green
- keep heavyweight benchmark capture sequential with the required preset and
  with any tool-test reruns

## 8. File Map

### Implementation Files

- `lib/src/render/render_geometry_cache.dart`
- `lib/src/render/cache/scene_text_layout_cache.dart`
- `lib/src/render/cache/scene_stroke_path_cache.dart`
- `lib/src/render/cache/scene_path_metrics_cache.dart`
- `lib/src/render/cache/scan_resistant_cache.dart`
- `lib/src/render/scene_render_caches.dart`
- `lib/src/render/scene_painter_selection.dart`
- `lib/src/render/selection_halo_compositing.dart`
- `lib/src/render/scene_grid_renderer.dart`
- `lib/src/render/cache/scene_static_layer_cache.dart`
- `tool/bench/load_profile_policy.dart`
- `tool/bench/load_profiles_cases_test.dart`
- `tool/bench/run_load_profiles.dart`
- `tool/bench/diff_load_profiles.dart`

### Test Files

- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_path_metrics_cache_test.dart`
- `test/render/scene_render_caches_test.dart`
- `test/render/render_cache_policy_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_grid_renderer_test.dart`
- `test/render/scene_grid_renderer_contract_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/bench_diff_load_profiles_test.dart`
- `test/tool/invariant_coverage_tool_test.dart`

### Fixtures and Supporting Data

- `tool/bench/baselines/load_profiles_smoke_baseline.json`
- `tool/bench/baselines/load_profiles_full_baseline.json`

### Registry, Inventory, and Workflow Files

- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_13_bounded_main_scene_paint_work.md`

### Analysis Area

- `lib/src/render/**`
- `tool/bench/**`
- `test/render/**`
- `test/tool/**`

## 9. Implementation Rules

### Protected Invariants

- main-scene rendering continues to consume one atomic `SceneViewFrameRead`
  and this step must not reopen the view/runtime seam
- render caches continue to exclude controller epoch from per-entry keys and
  still clear explicitly at owner-level epoch/document boundaries
- selection halo visual semantics, preview-delta parity, and open-versus-closed
  path behavior stay unchanged apart from bounded layer bounds
- dense-grid camera-phase stability near the line-cap threshold stays stable;
  bounded work must not introduce stride jitter
- benchmark cases continue to use production owners only and keep benchmark
  policy downstream of render ownership

### Required Proof

- behavioral proof:
  one failing over-capacity stable-frame reproducer first in each affected
  cache suite, plus 1 to 3 neighboring guard tests for unchanged reuse,
  changed-validity rebuild, and explicit invalidation;
  one failing selection `saveLayer(null, ...)` reproducer first, plus 1 to 3
  neighboring visual guard tests for rect/path halo parity and preview parity;
  one failing dense-grid over-iteration reproducer first, plus 1 to 3
  neighboring guard tests for jitter stability and static-cache hit behavior;
  benchmark contract tests for the new probe keys, case names, and diff schema
- structural proof:
  `test/render/render_cache_policy_contract_test.dart` proves the shared cache
  policy seam and bans local copied LRU policy code;
  `test/render/scene_painter_bounds_contract_test.dart` proves bounded
  selection compositing and bans null layer bounds on the selection owner
  seam;
  `test/render/scene_grid_renderer_contract_test.dart` proves one bounded grid
  plan contract owns direct draw and work statistics;
  `test/tool/bench_run_load_profiles_test.dart` proves benchmark cases keep
  using production owners and emit the required probe keys;
  `test/tool/invariant_coverage_tool_test.dart` proves the new invariants are
  declared and covered
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps:
  one failing reproducer first, plus 1 to 3 guard tests for neighboring
  branches of the same contract
- for refactors:
  existing locking tests must be named or missing characterization tests must
  be added before structural edits, plus 1 to 3 guard tests for neighboring
  branches when needed

### Allowed Change Surface

- the files listed in section 8 only
- owner-local helper extraction inside `lib/src/render/**` when it reduces
  mixed responsibility in the touched area
- benchmark policy, case, diff, and baseline updates that consume the new
  production-owner probes

### Forbidden Moves

- no edits to `lib/src/view/**`, `lib/src/interactive/**`, `lib/src/controller/**`,
  `lib/src/contract/**`, or public exports to solve these defects
- no reintroduction of per-cache bespoke retention policy after the shared
  helper exists
- no `saveLayer(null, Paint())` remaining on the main-scene selection path
- no benchmark-only render state, benchmark-only fast paths, or machine-tuned
  required-CI perf gates
- no doc-only slice and no measurement-only slice before the production-owner
  fixes exist

## 10. Vertical Slices

### Slice 1. [ ] Scan-Resistant Render Cache Policy

#### Slice Contract

Stable ordered working sets larger than cache capacity no longer collapse into
full rebuild churn on the second identical frame, and all four hot render
caches consume one shared render-local retention policy owner.

#### Change

- add the failing `maxEntries + 1` stable-frame reproducer to
  `render_geometry_cache_test.dart`,
  `scene_text_layout_cache_test.dart`,
  `scene_stroke_path_cache_test.dart`, and
  `scene_path_metrics_cache_test.dart`
- add 1 to 3 neighboring guard tests for unchanged single-entry reuse,
  changed-validity rebuild, and explicit invalidation boundaries where they are
  not already locked
- add `lib/src/render/cache/scan_resistant_cache.dart`
- migrate
  `RenderGeometryCache`,
  `SceneTextLayoutCache`,
  `SceneStrokePathCache`, and
  `ScenePathMetricsCache`
  away from copied local LRU policy code and onto the fixed shared
  `probationary/protected` two-queue helper
- extend `scene_render_caches_test.dart` with owner-level steady-state proof
- register `INV-ENG-RENDER-CACHE-SCAN-RESISTANT` in
  `tool/invariant_registry.dart`

#### Behavioral Verification

- `flutter test test/render/render_geometry_cache_test.dart`
- `flutter test test/render/scene_text_layout_cache_test.dart`
- `flutter test test/render/scene_stroke_path_cache_test.dart`
- `flutter test test/render/scene_path_metrics_cache_test.dart`
- `flutter test test/render/scene_render_caches_test.dart`

#### Structural Verification

- `flutter test test/render/render_cache_policy_contract_test.dart`

#### Fixtures Used

- synthetic node snapshots only

#### Positive Scenarios

- second identical ordered scan after warm-up keeps cache reuse for geometry,
  text, stroke, and path-metrics payloads even when the visible working set is
  larger than capacity
- owner-level invalidation still clears all caches correctly
- unchanged single-node reuse remains green

#### Negative Scenarios

- changed geometry/layout/path validity still rebuilds the affected cache entry
- epoch/document clear still forces rebuild on the next access
- degenerate uncached stroke-path cases remain uncached safe results

#### Closure Evidence

- all four cache suites prove the over-capacity stable-frame contract
- `test/render/render_cache_policy_contract_test.dart` proves the copied local
  LRU policy code is retired

### Slice 2. [ ] Bounded Selection Halo Compositing

#### Slice Contract

Selection halo masking keeps the same visible result while every masked halo
layer on the main-scene paint path uses non-null tight bounds derived from the
painted geometry and halo style.

#### Change

- add the failing `saveLayer(null, ...)` reproducer on the real painter path
  to `test/render/scene_painter_test.dart`
- add 1 to 3 neighboring visual guard tests for rect halo parity, closed-path
  halo parity, and preview-delta parity
- add `lib/src/render/selection_halo_compositing.dart`
- migrate rect and closed-path halo masking in
  `lib/src/render/scene_painter_selection.dart` onto the helper
- update the source-level selection seam checks in
  `test/render/scene_painter_bounds_contract_test.dart`
- register `INV-ENG-SELECTION-BOUNDED-COMPOSITING` in
  `tool/invariant_registry.dart`

#### Behavioral Verification

- `flutter test test/render/scene_painter_test.dart`

#### Structural Verification

- `flutter test test/render/scene_painter_bounds_contract_test.dart`

#### Fixtures Used

- synthetic painter scenes and `TestRecordingCanvas`

#### Positive Scenarios

- rect, image, text, and closed-path selection halos keep visual parity
- preview-delta selection rendering stays aligned with the node preview path
- bounded layer counts and bounds are observable on the real painter path

#### Negative Scenarios

- no selection means no masked halo layer work
- open-path contours do not regress into closed-path masking behavior
- null layer bounds are mechanically rejected by the structural seam proof

#### Closure Evidence

- `scene_painter_test.dart` proves no main-scene selection path records
  `saveLayer(null, ...)`
- `scene_painter_bounds_contract_test.dart` proves bounded selection
  compositing remains on the render owner seam

### Slice 3. [ ] Bounded Grid Iteration Plan

#### Slice Contract

Dense grid rendering uses one bounded iteration plan whose planned work, draw
work, and recorded work statistics stay aligned for direct draw and static
grid picture recording.

#### Change

- add the failing dense-grid over-iteration reproducer to
  `test/render/scene_grid_renderer_test.dart`
- add 1 to 3 neighboring guard tests for near-threshold stride stability,
  invalid drawable inputs, and static-grid cache hit behavior
- reshape `SceneGridAxisPlan` in `lib/src/render/scene_grid_renderer.dart` so
  it owns the actual bounded iteration contract
- migrate direct draw, work-stat reporting, and static-layer recording to that
  one bounded plan
- update `lib/src/render/cache/scene_static_layer_cache.dart` probes as needed
- add `test/render/scene_grid_renderer_contract_test.dart`
- register `INV-ENG-GRID-BOUNDED-ITERATION` in
  `tool/invariant_registry.dart`

#### Behavioral Verification

- `flutter test test/render/scene_grid_renderer_test.dart`
- `flutter test test/render/scene_static_layer_cache_test.dart`

#### Structural Verification

- `flutter test test/render/scene_grid_renderer_contract_test.dart`

#### Fixtures Used

- synthetic grid requests and static-layer cache probes

#### Positive Scenarios

- dense grids keep the visible line cap and preserve camera-phase stride
  stability
- direct draw and static picture recording report bounded aligned work
- static cache hit path continues to add zero extra grid work after warm-up

#### Negative Scenarios

- invalid grid inputs still return no drawable plan
- camera pan alone still does not rebuild the static grid picture
- dense-grid loop work no longer scales with every raw cell once stride is
  applied

#### Closure Evidence

- grid tests prove bounded iteration and output parity
- `scene_grid_renderer_contract_test.dart` proves one bounded plan owns grid
  work semantics

### Slice 4. [ ] Diagnostic Paint-Work Measurement Refresh

#### Slice Contract

The checked-in load-profile contract can measure before/after improvements for
stable cache reuse, bounded selection compositing, and bounded grid work while
continuing to use production owners only.

#### Change

- add one stable visible-working-set paint benchmark case that uses the real
  `ScenePainter` and over-capacity visible nodes under the fixed case id
  `stableVisibleWorkingSetPaintCaseName`, declared in
  `tool/bench/load_profile_policy.dart`; the fixed required operations for
  this case are
  `paint_cache_miss` and `paint_cache_hit`, and the case emits the flat
  per-cache probe keys
  `geometryBuildDelta`,
  `geometryHitDelta`,
  `geometryEvictDelta`,
  `textBuildDelta`,
  `textHitDelta`,
  `textEvictDelta`,
  `strokeBuildDelta`,
  `strokeHitDelta`,
  `strokeEvictDelta`,
  `pathMetricsBuildDelta`,
  `pathMetricsHitDelta`, and
  `pathMetricsEvictDelta`
- extend the selection end-to-end paint probe to emit the fixed flat keys
  `saveLayerCount`,
  `unboundedSaveLayerCount`, and
  `saveLayerBoundsArea`
- keep the static background probe but align its expected grid work deltas with
  the bounded grid plan from Slice 3
- update `tool/bench/load_profile_policy.dart`,
  `tool/bench/load_profiles_cases_test.dart`,
  `tool/bench/run_load_profiles.dart`, and
  `tool/bench/diff_load_profiles.dart`
  only as needed to support the new case and probe schema
- refresh `tool/bench/baselines/load_profiles_smoke_baseline.json` and
  `tool/bench/baselines/load_profiles_full_baseline.json`
- update `ARCHITECTURE.md`, `CHANGELOG.md`, `PLAN.md`, and this step document
  to the completed state

#### Behavioral Verification

- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/bench_diff_load_profiles_test.dart`

#### Structural Verification

- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/invariant_coverage_tool_test.dart`

#### Fixtures Used

- `tool/bench/baselines/load_profiles_smoke_baseline.json`
- `tool/bench/baselines/load_profiles_full_baseline.json`

#### Positive Scenarios

- the new stable-working-set case emits steady-state cache-stability probes for
  all four cache owners on production paint paths
- selection probes distinguish bounded from unbounded layer behavior
- static background probes reflect bounded grid work without changing owner
  wiring

#### Negative Scenarios

- missing new probe keys fail tool tests
- benchmark cases cannot swap in benchmark-only render owners
- baseline and diff schema stay consistent with the checked-in policy

#### Closure Evidence

- benchmark tool tests prove the new case and probe contract
- checked-in smoke/full baselines reflect the post-fix production-owner schema

## 11. Final Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`
- `dcm calculate-metrics lib/src/render/cache/scan_resistant_cache.dart lib/src/render/selection_halo_compositing.dart`
- `dart run tool/bench/run_load_profiles.dart --profile=smoke --output=build/bench/load_profiles_smoke.json`
- `dart run tool/bench/diff_load_profiles.dart --profile=smoke --baseline=tool/bench/baselines/load_profiles_smoke_baseline.json --current=build/bench/load_profiles_smoke.json --output=build/bench/load_profiles_smoke_diff.json`
- `dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json`
- `dart run tool/bench/diff_load_profiles.dart --profile=full --baseline=tool/bench/baselines/load_profiles_full_baseline.json --current=build/bench/load_profiles_full.json --output=build/bench/load_profiles_full_diff.json`

## 12. Acceptance Criteria

- all four hot render caches prove scan-resistant steady-state behavior on an
  unchanged over-capacity visible working set and share one render-local policy
  owner
- main-scene selection halo rendering has no `saveLayer(null, ...)` callsites
  and keeps halo parity on the real painter path
- dense-grid draw and static grid picture recording both consume one bounded
  iteration plan and keep aligned work counters
- invariant coverage, architecture text, changelog, plan index, and this step
  document reflect the final bounded-work contract
- smoke/full benchmark contracts and baselines can show before/after movement
  for cache stability, selection compositing bounds, and grid work without
  benchmark-only production seams
