language: english

# Change Contract

## 1. Change Mandate

Close `KI-8` by making main-scene selection rendering a halo-only overlay so
selected line, stroke, dot, and open-path nodes preserve base content alpha,
scene draw order, and single-pass stroke-path work.

## 2. Change Boundary

### Included in the Change

- reproduce `KI-8` with render proof for selected vector alpha preservation,
  selected-vector overlap order, and selected-stroke path work
- keep base node geometry rendering owned by the main content pass
- keep selection rendering owned by the existing selection renderer, but limit
  it to selection visuals only
- extend frame-resolved paint data only as needed for content and selection
  passes to share prepared stroke geometry without rebuilding stroke paths in
  the selection pass
- preserve bounded halo compositing for selected rect, image, text, closed
  path, line, stroke, dot, and open-path nodes
- strengthen render structural proof so future selection overlay drift is
  mechanically visible
- update render architecture source-of-truth, invariant wording, release notes,
  `API_GUIDE.md` selection-rendering text, `KNOWN_ISSUES.md`, `PLAN.md`, and
  this step file in the implementation change

### Not Included in the Change

- no new render owner family or replacement painter pipeline
- no selected-node second content pass
- no movement of selection rendering into the node renderer
- no movement of base geometry rendering into the selection renderer
- no public API, JSON schema, controller, interaction, model, or serialization
  contract change
- no `README.md` update unless implementation-time inspection finds existing
  README selection-rendering behavior text; current inspection found only a
  generic `SceneView` mention, so README is not part of the planned file map
- no broad render cache redesign beyond the minimum frame-resolved stroke-path
  data needed to close `KI-8`
- no implementation for active known issues other than `KI-8`

## 3. Surrounding Code Review

### Inspected Artifacts

- `KNOWN_ISSUES.md` - records `KI-8` as an active `P1` defect: selection
  rendering redraws base line, stroke, dot, and open-path geometry after the
  full content pass, changing alpha, draw order, and stroke-path work.
- `ARCHITECTURE.md` - render flow requires one atomic frame read, one frozen
  frame-preview authority, content paint order preservation, selected-node
  supplement deduplication, bounded selection `saveLayer` work, and separate
  overlay repaint ownership.
- `docs/architecture/families/render_frame_admission_and_caches.md` - the
  render family owns selection rendering and render caches; target rules say
  selection overlays must not introduce unbounded work or draw-order drift and
  explicitly track `KI-8` as the remaining violation.
- `docs/architecture/overview.md` - identifies
  `render_frame_admission_and_caches` as the current architecture family with a
  known issue.
- `docs/proof_architecture/overview.md` and
  `docs/proof_architecture/proof_flows.md` - proof reachability is owned
  through checked-in invariant registry and verification-contract tooling.
- `tool/invariant_registry.dart` - render-family invariants already include
  `INV-ENG-SELECTION-BOUNDED-COMPOSITING`,
  `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION`,
  `INV-ENG-RENDER-CACHE-SCAN-RESISTANT`, and
  `INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY`; current wording does not yet state
  that selection overlay is forbidden from drawing base node geometry.
- `lib/src/render/scene_painter_shell.dart` - current paint order is
  background, content node layers, then selection visuals from a single
  prepared frame.
- `lib/src/render/scene_painter_frame.dart` - `ScenePainterFrameOwner`
  prepares frame style, paint-plan admission, text layout, geometry, and
  preview deltas; it is the current frame data owner.
- `lib/src/render/scene_painter_contract.dart` - `ScenePainterResolvedNodePaintData`
  is the existing payload shared from frame resolution into content and
  selection rendering.
- `lib/src/render/scene_painter_node_renderer.dart` - the content pass already
  owns base line, stroke, dot, rect, text, image, and path drawing.
- `lib/src/render/scene_painter_selection.dart` - current selection pass draws
  halo and then redraws base line, stroke path, dot, and open-path stroke
  geometry; selected stroke paths call `scenePainterResolveStrokePath(...)`
  again from the selection renderer.
- `lib/src/render/selection_halo_compositing.dart` - existing bounded halo
  helper owns masked `saveLayer` behavior for rect and path halo work.
- `lib/src/render/cache/scene_stroke_path_cache.dart` - stroke-path cache owns
  borrowed render paths keyed by node id, instance revision, and canonical
  public stroke points; degenerate dot cases stay uncached.
- `lib/src/render/scene_painter_shared.dart` - owns the existing shared
  `scenePainterResolveStrokePath(...)` helper; this file is in scope only to
  preserve or narrowly reshape that stroke-path helper seam for content-owned
  stroke rendering, not to add selection-owned base drawing helpers.
- `lib/src/render/cache/scene_path_metrics_cache.dart` - path-selection
  contour metrics are the accepted selection-only path contour support seam.
- `test/render/scene_painter_test.dart` - integrated painter tests cover node
  variants, selected line/stroke paint, bounded selection `saveLayer` behavior,
  cache reuse, path geometry reuse, and closed-path halo cache parity, but do
  not currently forbid selection base-geometry redraw.
- `test/render/scene_painter_bounds_contract_test.dart` - structural render
  proof already checks frame/admission boundaries, bounded compositing imports,
  and module ownership, but does not currently reject selection redraw of base
  vector content.
- `test/render/scene_painter_frame_contract_test.dart` - frame proof already
  checks resolved geometry and paint-candidate ownership.
- `test/render/scene_stroke_path_cache_test.dart` and
  `test/render/scene_render_caches_test.dart` - existing cache proof locks the
  stroke-path cache and shared render-cache lifecycle.
- `dart run tool/lsp_trace_symbol.dart lib/src/render/scene_painter_selection.dart ScenePainterSelectionRenderer.drawSceneSelection --direction=both --depth=3 --json`
  - confirms selection rendering is called only from `ScenePainterShell` and
  fans out to `_drawLineSelection`, `_drawStrokeSelection`, and
  `_drawPathSelection`.
- `dart run tool/lsp_trace_flow.dart lib/src/render/scene_painter_shell.dart ScenePainterShell.paintPrepared --depth=4`
  - confirms the current main paint flow is background, node layers, and then
  selection rendering.
- `dart run tool/analysis/find_similar_clones.dart --json --top 20 lib/src/render 30 20 5 3 0.45 20`
  - found local render duplication signals, but no valid precedent for a
  second selected-content pass.
- `dcm calculate-metrics lib/src/render/scene_painter_selection.dart lib/src/render/scene_painter_node_renderer.dart lib/src/render/scene_painter_frame.dart`
  - reports `ScenePainterFrameOwner` coupling above threshold; this is a signal
  to keep the fix narrow and not a reason to split or contort the owner solely
  for metrics.
- `dart run tool/run_repository_audits.dart`,
  `dart run tool/check_guardrails.dart`,
  `dart run tool/check_invariant_coverage.dart`, and
  `dart run tool/check_architecture_atlas.dart` - current repository-wide
  structural checks are green and do not catch `KI-8`; the missing proof is
  render-specific.

### Current Entry Path

- main-scene paint path:
  `ScenePainter.paint(...) -> SceneViewMainSceneRenderRead.captureFrameRead() -> ScenePainterShell.paint(...) -> ScenePainterShell.paintPrepared(...)`
- content pass:
  `ScenePainterShell.paintPrepared(...) -> ScenePainterNodeRenderer.paintNodeLayers(...) -> _drawResolvedNode(...)`
- selection pass:
  `ScenePainterShell.paintPrepared(...) -> ScenePainterSelectionRenderer.drawSceneSelection(...) -> _drawSelectionForNode(...)`
- current failing selected-line path:
  `_drawSelectionForNode(...) -> _drawLineSelection(...) -> canvas.drawLine(halo) -> canvas.drawLine(base)`
- current failing selected-stroke path:
  `_drawSelectionForNode(...) -> _drawStrokeSelection(...) -> scenePainterResolveStrokePath(...) -> _drawStrokePathSelection(...) -> canvas.drawPath(halo) -> canvas.drawPath(base)`
- current failing selected-dot path:
  `_drawSelectionForNode(...) -> _drawStrokeSelection(...) -> _drawDotSelection(...) -> canvas.drawCircle(halo) -> canvas.drawCircle(base)`
- current failing selected-open-path path:
  `_drawSelectionForNode(...) -> _drawPathSelection(...) -> _drawOpenPathSelection(...) -> canvas.drawPath(halo) -> canvas.drawPath(base)`

### Current Owner

- `ScenePainterShell` owns paint ordering only.
- `ScenePainterFrameOwner` owns prepared frame data and late render resolution.
- `ScenePainterNodeRenderer` owns base content rendering for scene nodes.
- `ScenePainterSelectionRenderer` owns selection visuals, but currently also
  redraws selected vector base geometry, which is the ownership violation.
- `SelectionHaloStyle` and `selection_halo_compositing.dart` own bounded halo
  compositing behavior.
- `SceneStrokePathCache` owns cached stroke paths when supplied; without that
  cache, `scenePainterResolveStrokePath(...)` builds a path at the call site.

### Adjacent Abstractions

- `ScenePainterResolvedNodePaintData` - existing frame-resolved data seam
  shared from frame resolution into both content and selection passes.
- `GeometryEntry.localPath` - accepted precedent for carrying path geometry
  from frame resolution into both culling/content/selection use without
  reparsing SVG paths.
- `ScenePathMetricsCache.getOrBuild(...)` - accepted selection-only support for
  path contour metrics derived from an already resolved local path.
- `ScenePainterSelectionStyle` and `SelectionHaloStyle` - current style seams
  for halo color and width.
- `ScenePainterVisibilityBudget` and `visibilityRectForNode(...)` - current
  selected-node halo admission support that keeps selected halo work visible
  without changing content draw order.

### Existing Tests

- `test/render/scene_painter_test.dart` - integrated rendering proof for
  selected variants, cache reuse, bounded saveLayer behavior, geometry reuse,
  and preview/selection parity.
- `test/render/scene_painter_bounds_contract_test.dart` - structural proof for
  painter module boundaries, bounded selection compositing, and frame/admission
  contracts.
- `test/render/scene_painter_frame_contract_test.dart` - proof that frame
  resolution occurs only for controller-owned paint candidates and uses the
  captured frame preview.
- `test/render/scene_stroke_path_cache_test.dart` - owner-level stroke-path
  cache proof.
- `test/render/scene_render_caches_test.dart` - shared render-cache lifecycle
  and scan-resistant reuse proof.

### Analogous Implementation Path

- `GeometryEntry.localPath` in `lib/src/render/render_geometry_entry.dart` and
  `RenderGeometryCache.get(...)` in `lib/src/render/render_geometry_cache.dart`
  are the closest valid precedent: frame resolution builds reusable render
  geometry once and downstream render modules borrow it without rebuilding the
  same expensive geometry.
- `drawBoundedPathHalo(...)` in `lib/src/render/selection_halo_compositing.dart`
  is the closest valid halo precedent: selection visuals can use masked
  compositing to reveal only the halo around existing content instead of
  repainting the base content.
- `ScenePainterNodeRenderer._drawResolvedNode(...)` is the accepted base
  rendering owner and therefore the correct place for selected nodes to keep
  their base geometry draw.

### Governing Repository Rules

- `AGENTS.md` - fix the root cause at the owning layer and prefer a single
  source of truth over sync logic.
- `AGENTS.md` - use repository-local mechanical enforcement for stable
  constraints instead of prose-only reminders.
- `AGENTS.md` - metrics and static-analysis thresholds are signals, not goals;
  do not split code solely to satisfy a threshold.
- `ARCHITECTURE.md` - the render pipeline paints from one atomic frame read and
  must preserve content paint order regardless of supplement source.
- `ARCHITECTURE.md` - paint-candidate admission and render caches remain in the
  render layer; text layout and path geometry are late render-resolution work.
- `docs/architecture/families/render_frame_admission_and_caches.md` -
  selection overlays must not introduce unbounded work or draw-order drift.
- `tool/invariant_registry.dart` - render proof must stay reachable through the
  required-code-change preset and explicit invariant markers.
- `KNOWN_ISSUES.md` - active known issues are removed only in the same change
  that fixes them and adds regression proof.

### Rejected Misleading Local Patterns

- adding a second selected-content pass after selection admission - wrong level
  because it explicitly makes selected content draw later than ordinary content
  and preserves the class of draw-order bugs behind `KI-8`
- moving base vector drawing helpers from `ScenePainterNodeRenderer` into
  `ScenePainterSelectionRenderer` - wrong owner because selection visuals
  would continue to own base scene content
- patching only opacity values in selection redraws - incomplete root-cause fix
  because draw order and repeated stroke-path work remain wrong
- relying only on `SceneStrokePathCache` to reduce repeated work - incomplete
  fix because the no-cache path still builds twice and base content still
  redraws in the overlay
- moving halo drawing into `ScenePainterNodeRenderer` - wrong seam because
  selection visuals are intentionally a later overlay after content rendering
- broad render-family refactor to reduce DCM coupling - wrong scope because
  `KI-8` needs a bounded ownership correction, not a metric-driven redesign

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- render-family selection-overlay ownership correction inside the existing
  main-scene painter pipeline

#### Selected Architectural Form

- keep the current paint order:
  `background -> content node layers -> selection overlay`
- keep all base scene geometry drawing in `ScenePainterNodeRenderer`
- make `ScenePainterSelectionRenderer` halo-only for all selected node families
- use the existing frame-resolved paint data seam to share any stroke render
  payload needed by both content and selection passes
- keep bounded halo compositing as the only selection-pass mechanism that may
  mask over existing content
- strengthen render structural proof so selection overlay cannot reintroduce
  base geometry drawing for line, stroke, dot, or open-path nodes

#### Owning Layer or Module

- primary implementation owners:
  `lib/src/render/scene_painter_contract.dart`,
  `lib/src/render/scene_painter_frame.dart`,
  `lib/src/render/scene_painter_node_renderer.dart`, and
  `lib/src/render/scene_painter_selection.dart`
- halo-compositing support owner:
  `lib/src/render/selection_halo_compositing.dart`
- cache support owner remains:
  `lib/src/render/cache/scene_stroke_path_cache.dart`
- no ownership moves to controller, interactive, model, serialization, view, or
  public API layers

#### Dependency Direction

- `ScenePainterShell` continues to call frame owner, node renderer, and
  selection renderer without part files or back edges.
- frame owner may prepare render payloads consumed by render modules.
- node renderer consumes frame-resolved data to draw base content.
- selection renderer consumes the same resolved data to draw halo only.
- selection renderer must not call `scenePainterResolveStrokePath(...)`,
  `buildStrokePath(...)`, or any base-node draw helper.

#### State and Data Ownership

- selected ids and frame preview stay owned by `SceneViewFrameRead`.
- paint candidate planning stays owned by `SceneViewMainSceneRenderRead` and
  `ScenePainterFrameOwner`.
- `ScenePainterResolvedNodePaintData` owns the per-node resolved payload shared
  by content and selection rendering during a frame.
- stroke paths used by a non-dot stroke in the frame are resolved once through
  the node/frame rendering seam and borrowed by selection halo rendering.
- path contours for open/closed path selection stay owned by
  `ScenePathMetricsCache` or direct contour building from the resolved local
  path.

#### Entry and Exit Boundaries

- entry boundary:
  `ScenePainterShell.paintPrepared(...)` with a prepared frame and captured
  `SceneViewFrameRead`
- content exit boundary:
  every visible selected vector node has already had base content drawn by
  `ScenePainterNodeRenderer` before it is recorded in
  `frame.selectedNodes`
- selection exit boundary:
  selection rendering adds only halo pixels around the already drawn content;
  it does not draw base node color, opacity, fill, or stroke payload again

#### Permitted Extension Seam

- `ScenePainterResolvedNodePaintData` may gain a narrow optional resolved
  stroke-path payload for non-dot `StrokeNodeSnapshot` rendering.
- `selection_halo_compositing.dart` may gain focused bounded halo helpers for
  line and dot geometry if direct masked path/rect halo helpers do not express
  those shapes clearly.
- `test/render/scene_painter_test.dart` and
  `test/render/scene_painter_bounds_contract_test.dart` are the required proof
  surfaces for behavior and structure.

#### Rejected Alternatives

- second selected-content pass - rejected because it still changes selected
  content draw order relative to unselected content
- node-renderer-owned halo drawing - rejected because it mixes selection
  visuals into the content pass and weakens the existing shell order
- selection-renderer-owned base draw helpers - rejected because it preserves
  the current ownership violation
- cache-only optimization - rejected because it does not fix alpha or draw
  order and does not cover no-cache paints
- full render pipeline rewrite - rejected because the existing owner graph and
  repository checks are green outside the specific selection overlay defect

#### Why This Level Is Correct

- `KI-8` happens after successful frame capture, paint admission, and content
  drawing; it is not a controller, model, serialization, or view-host defect.
- the render layer already has a clear split between content rendering,
  selection visuals, frame data, and bounded halo support.
- repairing the ownership at the selection overlay seam fixes alpha, draw
  order, and repeated stroke-path work once without duplicating policy across
  callers.
- the closest accepted precedent already shares render geometry through
  frame-resolved data instead of rebuilding it in later modules.

### 4B. Architecture Decision Gate

Not used. The architectural form is locked in 4A.

## 5. Locked Decisions

1. Each implementation slice must add its failing `KI-8` proof before changing
   production render code for that slice.
2. Selection rendering must become halo-only for line, stroke, dot, and
   open-path selections.
3. Selected stroke-path data must be resolved once for the frame path that
   paints the selected stroke; the selection renderer must borrow the resolved
   payload instead of resolving or building the stroke path again.
4. Existing closed-path halo behavior remains based on path-selection contours
   and bounded path halo compositing.
5. Structural proof must reject selection-overlay base geometry redraw and
   selection-side stroke-path resolution.
6. `KI-8` closure happens only after behavioral proof, structural proof,
   source-of-truth updates, and required verification are green.

## 6. Result Requirements

1. Selecting a semi-transparent line, stroke, dot, or open path does not change
   the base content alpha.
2. Selecting a vector node does not move that node visually above later scene
   content in the draw order.
3. A selected non-dot stroke does not cause a second stroke-path build in a
   single paint frame when no `SceneStrokePathCache` is supplied.
4. When `SceneStrokePathCache` is supplied, selected non-dot stroke rendering
   does not require an extra selection-side cache lookup beyond the content
   draw path.
5. Selection halo remains visible and bounded for rect, image, text, line,
   stroke, dot, closed-path, and open-path nodes.
6. Preview delta behavior and selected-node halo admission remain unchanged.
7. `KNOWN_ISSUES.md`, render-family architecture status, invariant wording,
   `API_GUIDE.md`, and release notes all agree that `KI-8` is closed.

## 7. Execution Order and Gates

### Required Order

- add each slice's failing behavioral or structural proof for `KI-8` before
  changing the production render code owned by that slice
- land the minimum frame-resolved payload and node-renderer changes needed to
  make selected stroke data reusable in the same frame
- change selection rendering to halo-only and keep bounded compositing proof
  green
- update render invariant wording and architecture/source-of-truth files only
  after behavior and structural proof are green
- remove `KI-8` only after the render proof and source-of-truth updates land in
  the same implementation change

### Successor Seam and Retirement Gates

- successor seam:
  `ScenePainterResolvedNodePaintData` is the only allowed shared frame payload
  seam between base content rendering and selection halo rendering
- retired behavior:
  selection renderer base redraw for selected line, stroke, dot, and open-path
  nodes must be removed
- retirement gate:
  `test/render/scene_painter_bounds_contract_test.dart` must fail if
  `scene_painter_selection.dart` reintroduces base `drawLine`, base
  `drawCircle`, base `drawPath`, `scenePainterResolveStrokePath(...)`, or
  `buildStrokePath(...)` use for selection overlay rendering
- issue-closure gate:
  `KNOWN_ISSUES.md` must keep `KI-8` until the reproducer tests and structural
  tests pass against the implementation

### Deferred Broad Verification

- reserve
  `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
  for the final implementation gate with the final repository-relative changed
  path list on stdin
- reserve broad render/view scope verification for the final gate after slice
  proof is green

## 8. File Map

### Implementation Files

- `lib/src/render/scene_painter_contract.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/render/scene_painter_node_renderer.dart`
- `lib/src/render/scene_painter_selection.dart`
- `lib/src/render/selection_halo_compositing.dart`
- `lib/src/render/scene_painter_shared.dart` - only the existing
  stroke-path helper seam may change
- `lib/src/render/cache/scene_stroke_path_cache.dart`

### Test Files

- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_render_caches_test.dart`

### Fixtures and Supporting Data

- no new external fixture files are allowed; use inline scenes and existing
  test helpers in `test/render/scene_painter_test.dart`

### Registry, Inventory, and Workflow Files

- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `docs/architecture/families/render_frame_admission_and_caches.md`
- `API_GUIDE.md`
- `KNOWN_ISSUES.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_33_selection_overlay_halo_only_rendering.md`

### Analysis Area

- `dart run tool/lsp_trace_symbol.dart lib/src/render/scene_painter_selection.dart ScenePainterSelectionRenderer.drawSceneSelection --direction=both --depth=3 --json`
- `dart run tool/lsp_trace_flow.dart lib/src/render/scene_painter_shell.dart ScenePainterShell.paintPrepared --depth=4`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_architecture_atlas.dart`
- `dcm calculate-metrics lib/src/render/scene_painter_selection.dart lib/src/render/scene_painter_node_renderer.dart lib/src/render/scene_painter_frame.dart`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-SELECTION-BOUNDED-COMPOSITING`
- `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION`
- `INV-ENG-RENDER-CACHE-SCAN-RESISTANT`
- `INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY`
- `INV-ENG-PAINT-ADMISSION-BOUNDS-SOURCE`

### Required Proof

- behavioral proof:
  one failing reproducer for alpha preservation, one failing reproducer for
  overlap draw order, one failing reproducer for selected-stroke path work, and
  1 to 3 neighboring guard tests for halo visibility and preview parity
- structural proof:
  `test/render/scene_painter_bounds_contract_test.dart` must enforce that
  selection rendering is halo-only and does not resolve stroke paths or draw
  base vector content
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps:
  one failing reproducer first, plus 1 to 3 guard tests for neighboring
  branches of the same contract
- for refactors:
  existing locking tests must be named or missing characterization tests must
  be added before structural edits, plus 1 to 3 guard tests for neighboring
  branches when needed

### Allowed Change Surface

- add narrow optional frame-resolved stroke-path data to
  `ScenePainterResolvedNodePaintData` if needed for one-frame reuse
- adjust content rendering only to consume or record that resolved payload
- adjust selection rendering only to remove base redraw and draw bounded halo
  for selected vector nodes
- add focused bounded halo helpers under `selection_halo_compositing.dart`
  only when existing helpers do not express line or dot halo safely
- update render invariant wording, family status, docs, issue tracking,
  release notes, and plan status after proof is green

### Forbidden Moves

- do not add a new selected-content render pass
- do not move base scene drawing out of `ScenePainterNodeRenderer`
- do not move selection halo drawing into controller, interactive, model,
  serialization, or view layers
- do not call `scenePainterResolveStrokePath(...)` or `buildStrokePath(...)`
  from `scene_painter_selection.dart`
- do not redraw selected node base color, opacity, fill, or stroke payload in
  `scene_painter_selection.dart`
- do not satisfy DCM metrics through mechanical splitting that does not improve
  the ownership boundary
- do not remove `KI-8` before failing reproducers, guard tests, structural
  proof, and final verification are green

### Optional: Recognition Forms That Must Be Supported

- selected `LineNodeSnapshot` halo rendered around the original line without
  redrawing line color
- selected one-point `StrokeNodeSnapshot` halo rendered around the original dot
  without redrawing dot color
- selected multi-point `StrokeNodeSnapshot` halo rendered from the frame
  resolved stroke path without selection-side stroke-path resolution
- selected open `PathNodeSnapshot` halo rendered around open contours without
  redrawing the path stroke color
- selected closed `PathNodeSnapshot` halo behavior remains bounded and
  contour-based

### Optional: Allowed Forms That Are Not Violations

- `scene_painter_selection.dart` may call `drawBoundedPathHalo(...)`,
  `drawBoundedRectHalo(...)`, or new bounded halo-only helpers.
- `selection_halo_compositing.dart` may call `drawPath`, `drawRect`,
  `drawLine`, or `drawCircle` internally when those calls are used only to
  build or clear a bounded halo layer.
- `scene_painter_node_renderer.dart` may continue to call
  `scenePainterResolveStrokePath(...)` as the base content owner.

### Optional: Resolution Rules

- if a render helper can be used for both base content and selection visuals,
  it must be named and placed so the call site still expresses whether it is
  drawing base content or halo-only visuals
- if structural proof cannot distinguish halo-only helper calls from base
  redraw calls, add a small owner-local helper boundary instead of weakening
  the proof

## 10. Vertical Slices

### Slice 1. [ ] Close Line and Dot Selection Redraw

#### Slice Contract

Selected line and one-point stroke selections draw halo without redrawing base
line or dot content.

#### Change

- add failing render tests for selected-line alpha preservation and selected
  line draw-order preservation before production edits
- add a neighboring guard test for selected one-point stroke halo visibility
  and base dot alpha preservation before production edits
- remove selection-overlay base redraw for selected lines and selected dots
- add structural proof that `scene_painter_selection.dart` does not contain
  selection-side base `drawLine` or base `drawCircle` redraw for those
  branches

#### Behavioral Verification

- `flutter test --no-pub test/render/scene_painter_test.dart`

#### Structural Verification

- `flutter test --no-pub test/render/scene_painter_bounds_contract_test.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- inline scenes in `test/render/scene_painter_test.dart`

#### Positive Scenarios

- selected semi-transparent line content keeps the same base alpha as
  unselected line content
- later content still visually covers earlier selected line content where scene
  order says it should
- selected one-point stroke halo remains visible without repainting dot color
- preview delta still moves selected content and halo together

#### Negative Scenarios

- selection overlay cannot repaint selected line base content
- selection overlay cannot repaint selected dot base content

#### Closure Evidence

- new line and dot behavioral tests fail before production edits and pass after
  the slice implementation
- line/dot structural proof fails against the current selection redraw code and
  passes after the slice implementation

### Slice 2. [ ] Move Stroke Path Reuse to Frame-Resolved Data

#### Slice Contract

Selected multi-point stroke rendering uses one frame-resolved stroke path for
the content draw and the selection halo draw, without selection-overlay base
stroke redraw.

#### Change

- add a failing selected-stroke path-work reproducer before production edits
- add the minimum optional stroke-path payload to
  `ScenePainterResolvedNodePaintData`
- resolve multi-point stroke paths in the frame/content owner path
- update `ScenePainterNodeRenderer` to draw non-dot strokes from the resolved
  payload
- remove selection-overlay base redraw and selection-side stroke-path
  resolution for selected multi-point strokes
- keep dot strokes as dot geometry and do not force them through
  `SceneStrokePathCache`
- keep `SceneStrokePathCache` owner behavior unchanged unless a narrow helper
  is needed to expose the borrowed path safely
- add structural proof that `scene_painter_selection.dart` does not call
  `scenePainterResolveStrokePath(...)`, `buildStrokePath(...)`, or base stroke
  redraw for selected strokes

#### Behavioral Verification

- `flutter test --no-pub test/render/scene_painter_test.dart`
- `flutter test --no-pub test/render/scene_stroke_path_cache_test.dart`

#### Structural Verification

- `flutter test --no-pub test/render/scene_painter_frame_contract_test.dart`
- `flutter test --no-pub test/render/scene_painter_bounds_contract_test.dart`
- `dcm calculate-metrics lib/src/render/scene_painter_contract.dart lib/src/render/scene_painter_frame.dart lib/src/render/scene_painter_node_renderer.dart`

#### Fixtures Used

- inline selected-stroke scenes in `test/render/scene_painter_test.dart`

#### Positive Scenarios

- selected multi-point stroke content draws from the resolved payload
- no-cache selected stroke does not build the stroke path twice in one frame
- cached selected stroke does not need an extra selection-side cache lookup
- selected multi-point stroke halo remains visible without repainting stroke
  color

#### Negative Scenarios

- dot strokes are not routed through stroke-path cache work
- frame payload does not expose mutable path ownership outside the render frame
- selection renderer does not resolve or build stroke paths

#### Closure Evidence

- selected-stroke path-work reproducer passes
- selected-stroke halo-only structural proof passes
- stroke cache owner tests remain green
- DCM output is reviewed as a signal and not used to justify mechanical
  splitting

### Slice 3. [ ] Close Path Selection Redraw and Full Halo-Only Proof

#### Slice Contract

Selection rendering draws only bounded halo visuals for selected open-path and
closed-path nodes, and the full selection renderer is mechanically locked as
halo-only.

#### Change

- add failing selected open-path alpha and draw-order reproducers before
  production edits
- remove open-path base stroke redraw from `scene_painter_selection.dart`
- add or reuse bounded halo-only helpers for open-path selection
- keep world-bounds halo behavior for image, text, and rect selections
- preserve closed-path halo parity with and without `ScenePathMetricsCache`
- extend structural proof so the full selection renderer cannot reintroduce
  base `drawLine`, base `drawCircle`, base `drawPath`, selection-side
  `scenePainterResolveStrokePath(...)`, or selection-side `buildStrokePath(...)`
  use

#### Behavioral Verification

- `flutter test --no-pub test/render/scene_painter_test.dart`
- `flutter test --no-pub test/render/scene_render_caches_test.dart`

#### Structural Verification

- `flutter test --no-pub test/render/scene_painter_bounds_contract_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- inline selection scenes in `test/render/scene_painter_test.dart`

#### Positive Scenarios

- open-path selections show halo without changing base content pixels
- closed-path selection keeps current bounded halo behavior
- selected halo saveLayer bounds remain finite and geometry-derived

#### Negative Scenarios

- selected open-path base content is not repainted by the selection renderer
- no selected vector base content is repainted by the selection renderer
- selection renderer does not become a content drawing owner

#### Closure Evidence

- alpha, draw-order, halo visibility, preview parity, and cache tests are green
- structural proof rejects the old selection redraw form

### Slice 4. [ ] Close KI-8 Source-of-Truth and Final Verification

#### Slice Contract

Repository documentation, invariant registry, known-issue tracking, and final
verification agree that selection overlay rendering is halo-only.

#### Change

- update `tool/invariant_registry.dart` wording and proof mapping if needed so
  halo-only selection overlay is part of the render invariant contract
- update `ARCHITECTURE.md` and
  `docs/architecture/families/render_frame_admission_and_caches.md` so
  selection overlay redraw drift is no longer an active known issue
- update `API_GUIDE.md` through its public-doc sync rule because its `SceneView`
  section already describes selection overlay rendering controls
- add the `CHANGELOG.md` unreleased entry
- remove `KI-8` from `KNOWN_ISSUES.md`
- update `PLAN.md` and this step file when the implementation is complete

#### Behavioral Verification

- `flutter test --no-pub test/render/scene_painter_test.dart test/render/scene_stroke_path_cache_test.dart test/render/scene_render_caches_test.dart`

#### Structural Verification

- `flutter test --no-pub test/render/scene_painter_bounds_contract_test.dart test/render/scene_painter_frame_contract_test.dart`
- `dart run tool/check_architecture_atlas.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_guardrails.dart`

#### Fixtures Used

- no new fixtures; slice closes source-of-truth and proof tracking around the
  landed render implementation

#### Positive Scenarios

- `KNOWN_ISSUES.md` no longer lists `KI-8`
- render-family architecture docs no longer describe selection redraw drift as
  open
- invariant proof remains reachable from the required-code-change preset

#### Negative Scenarios

- no issue closure lands without behavioral proof and structural proof
- no documentation claims a broader public API or schema change

#### Closure Evidence

- final targeted render tests and structural checks are green
- source-of-truth files match the landed implementation

## 11. Final Verification

- `flutter test --no-pub test/render/scene_painter_test.dart`
- `flutter test --no-pub test/render/scene_painter_bounds_contract_test.dart test/render/scene_painter_frame_contract_test.dart`
- `flutter test --no-pub test/render/scene_stroke_path_cache_test.dart test/render/scene_render_caches_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_architecture_atlas.dart`
- `dcm calculate-metrics lib/src/render/scene_painter_contract.dart lib/src/render/scene_painter_frame.dart lib/src/render/scene_painter_node_renderer.dart lib/src/render/scene_painter_selection.dart lib/src/render/selection_halo_compositing.dart`
- feed the final repository-relative changed path list on stdin to
  `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- selected line, stroke, dot, and open-path nodes preserve base content alpha
  and scene draw order
- selected vector nodes do not cause selection-overlay base geometry redraw
- selected non-dot stroke path work is not duplicated by the selection pass in
  a single frame
- selection halo remains visible and bounded for all node families currently
  supported by selection rendering
- render structural proof rejects future selection overlay base redraw drift
- render-family architecture docs, invariant registry, release notes,
  `KNOWN_ISSUES.md`, `PLAN.md`, and this step contract agree that `KI-8` is
  closed only after proof is green
