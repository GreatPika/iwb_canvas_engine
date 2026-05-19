<!-- CONTEXT:BEGIN -->
Registry id: `section_15_frame_render_contract`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/frame_rendering.md`
Owns:
- 15. FrameEngine and render contract
Must read before editing:
- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
- `section_07_resource_lifecycle` -> `docs/contracts/resources.md`
- `section_17_spatial_kernel` -> `docs/contracts/spatial_kernel.md`
- `section_18_cache_policy` -> `docs/contracts/cache_policy.md`
Feeds phases:
- `P9`
- `P10`
- `P13`
Related donors:
- `frame_render_state`
- `render_geometry_builder`
- `snapshot_paint_admission_bounds`
- `snapshot_paint_candidates`
- `scene_view_runtime_fast_path`
- `paint_candidate_stage`
- `scene_painter_frame`
- `scene_render_caches`
- `static_layer_cache`
- `text_stroke_path_metrics_caches`
Related diagrams:
- `dfd_main_paint_frame`
- `dfd_overlay_frame`
- `seq_main_paint`
- `seq_overlay_paint`
Required tests:
- `test.store.no_projection_hot_path`
- `test.frame.main_overlay_capture`
- `test.frame.no_live_runtime_read_in_painters`
- `test.guardrails.frame_committed_facts_via_frame_facts_port`
- `test.frame.paint_plan_excludes_preview_delta`
- `test.frame.paint_plan_excludes_selection_state`
- `test.frame.camera_pan_preserves_ordinary_paint_plan`
- `test.frame.selected_supplement_staging_no_global_sort`
- `test.api_contract.preview_state_sealed_union`
- `test.flutter_bridge.widget_paint`
Guardrails:
- `preview.selected_move_main_repaint`
- `api.preview_state_sealed_union_publicly_readable`
- `frame.committed_facts_via_frame_facts_port`
- `frame.no_global_scene_sort`
- `frame.paint_plan_excludes_preview_delta`
- `frame.paint_plan_excludes_selection_state`
- `cache.background_grid_not_element_visual`
Do not assume:
- no live runtime reads in painters
- no CanvasDocument projection in paint
<!-- CONTEXT:END -->

## 15. FrameEngine and render contract

### 15.1 Captured frames

Main frame:

```text
CapturedMainFrame
  documentRevision
  structuralRevision
  boundsRevision
  elementVisualRevision
  backgroundRevision
  gridRevision
  gridStrokeWidth
  selectionRevision
  resourceVisualRevision
  viewCameraRevision
  viewCameraOffset
  viewportRect
  devicePixelRatio
  selectionIds
  selectionStyle
  selectedMoveDelta
```

Overlay frame:

```text
CapturedOverlayFrame
  previewRevision
  viewCameraRevision
  viewCameraOffset
  previewState
  selectionStyle
```

Frame consumes public preview state by variant. `CanvasSelectedMovePreview` is
captured for the main-scene selected supplement path only. `CanvasMarqueePreview`,
`CanvasPencilStrokePreview`, `CanvasMarkerStrokePreview`,
`CanvasPendingLineStartPreview`, `CanvasLinePreview`, and `CanvasEraserPreview`
are admitted by overlay frame capture. `CanvasStrokePreview` supplies the shared
points, color, thickness, and opacity facts for pencil and marker overlay
primitives.

Rules:

```text
- main paint captures main frame once;
- overlay paint captures overlay frame once;
- committed frame facts enter FrameEngine through FrameFactsPort;
- FrameFactsPort supplies documentRevision, structuralRevision, boundsRevision,
  elementVisualRevision, backgroundRevision, gridRevision, immutable committed
  render-row facts, immutable resource descriptor snapshots, and resourceRevision;
- FrameFactsPort rejects stale row facts by captured structuralRevision and
  generation before FrameEngine builds render records;
- FrameFactsPort must not return RenderElementRecord, PaintPlan, selected
  supplement records, selection decoration plans, selection facts, or resolver
  state;
- painters do not live-read runtime;
- painters do not materialize CanvasDocument;
- stale spatial candidate is rejected by structuralRevision/generation check;
- `SurfaceResourceSession` is the only image resolution boundary in paint, and
  app resolver callbacks cannot mutate runtime;
- v1 resolver calls are synchronous and bounded by the per-frame resolver budget;
- runtime view camera changes use `state.revisions.viewCamera`, repaint affected
  frame surfaces, and must not invalidate ordinary committed element paint
  plans or public `CanvasDocument` projection;
- background/grid document changes use internal backgroundRevision/gridRevision
  facts and captured grid style values where they affect static background
  output, and must not invalidate ordinary committed element paint plans.
```

Future internal split:

`FrameEngine` remains the frame-internal facade for orchestration order,
collaborator composition, painter input assembly, and repaint bus coordination.
It delegates future frame-owned derived data construction to seven
frame-private collaborators:

| Future collaborator | Owns | Must not own |
|---|---|---|
| `FrameCaptureService` | one-time capture of main/overlay live frame facts into `CapturedMainFrame` and `CapturedOverlayFrame` | record planning, resolver/session calls, cache mutation beyond captured-frame construction |
| `OrdinaryPaintPlanner` | ordinary committed `PaintPlanCache` lookup/build using structure, bounds, element visual, viewport, and DPR | selection revision, selection style, selected move delta, preview state, resource resolver/session, static background identity |
| `SelectedMoveSupplementPlanner` | per-frame selected move filtering, shifted candidate lookup, row resolution, and merge by `orderToken` | ordinary `PaintPlanCache` writes, overlay rendering, global scene sort |
| `SelectionDecorationPlanner` | selection UI decoration and `SelectionDecorationPlan` key including `boundsRevision` | ordinary record cache identity, selected move supplement records, static background identity |
| `PaintAssetBindingService` | descriptor-to-asset binding for records with image resource ids, using immutable descriptor facts and `SurfaceResourceSession` | ordinary paint plan construction, painter resolver calls, app resolver ownership |
| `StaticBackgroundPlanner` | static background/grid plan and cache identity | selection, preview, resource visual, ordinary element visual identity |
| `OverlayPreviewPlanner` | immutable overlay primitives admitted from `CapturedOverlayFrame` | selected move rendering, resource resolver reads, cache invalidation, repaint scheduling |

`OrdinaryPaintPlanner` builds only ordinary committed record plans and excludes
selection revision, selection style, selected move delta, preview state,
resolver/session access, and static background identity from its cache inputs.
`PaintAssetBindingService` is the only future frame collaborator that receives
`SurfaceResourceSession`; painters remain immutable-output consumers and never
receive store, runtime, resolver, or public document read access.

Opacity and layer policy:

```text
- element and stroke opacity are ordinary render inputs applied through primitive paint alpha;
- ordinary opacity must not create an implicit group opacity or offscreen layer in the hot paint path;
- any future saveLayer-producing effect must be explicit in RenderElementRecord,
  budgeted, counted by the frame.paint_candidates offscreen-layer metric, and
  guarded by a contract update before implementation.
```

### 15.2 RenderElementRecord

Painters receive compact immutable render records, not public `CanvasElement`.

```text
RenderElementRecord
  id
  family
  generation
  orderToken
  transform
  opacity
  paintBoundsWorld
  hitBoundsWorld
  resourceId?
  row-specific immutable view
```

Ordinary `RenderElementRecord` values cached in `PaintPlanCache` do not include
selection membership, selection flags, selected-move preview deltas, or any
other selection-only state. Selection UI is built as a separate decoration pass,
and selected-move supplement records are per-frame values that are never stored
in the ordinary paint plan cache.

Family row views:

```text
ImageRenderRow: resourceId, size, naturalSize
PathRenderRow: pathDataKey, fillColor, strokeColor, strokeWidth, fillRule
TextRenderRow: text, fontSize, color, align, direction, bold, italic, underline, fontFamily, maxWidth, lineHeight
StrokeRenderRow: pointsKey, thickness, color
LineRenderRow: start, end, thickness, color
RectRenderRow: size, fillColor, strokeColor, strokeWidth
```

### 15.3 Selected supplement staging

Algorithm:

```text
1. Lookup or build the committed ordinary paint plan from PaintPlanCache.
2. PaintPlanCache stores only ordinary committed RenderElementRecord data.
3. PaintPlanCache key uses structuralRevision, boundsRevision,
   elementVisualRevision, viewportRect, and devicePixelRatio.
4. PaintPlanCache key must not include backgroundRevision, gridRevision,
   gridStrokeWidth, viewCameraRevision, viewCameraOffset, selectedMoveDelta,
   previewDelta, selected ids, selection flags, selectionRevision, or captured
   style-only inputs.
5. When CanvasSelectedMovePreview is active, read selected ids through the captured
   selection facts boundary and filter movable selected ids from the
   ordinary record stream for this frame only.
6. Query visibilityRect shifted by -previewDelta for selected supplement
   candidates.
7. Resolve selected handles through `FrameFactsPort` against the captured
   structuralRevision and generation.
8. If the selected row facts are current, create shifted RenderElementRecord
   instances with previewDelta for this frame only.
9. If `FrameFactsPort` rejects a stale selected candidate, skip that candidate
   and do not build a supplement RenderElementRecord for it.
10. Merge filtered ordinary records and supplement records by orderToken.
11. Do not store selected supplement records in PaintPlanCache.
12. Do not global sort all scene elements.
13. Do not materialize CanvasDocument.
```

Future ownership: `OrdinaryPaintPlanner` owns steps 1 through 4, while
`SelectedMoveSupplementPlanner` owns steps 5 through 12. The supplement planner
consumes captured selection facts and ordinary records for the current frame,
but does not write the ordinary `PaintPlanCache`, does not render overlays, and
does not global sort the scene.

Selection decoration reads selected ids and selectionRevision through the same
captured selection facts boundary and is invalidated separately from ordinary
paint plans. Its decoration key includes `boundsRevision` because selected
element bounds can change without changing selection membership. `selectedOrder`
is derived data or a bounded cache keyed by `selectionRevision` and
`structuralRevision`; it is not a second stored selection source of truth.
Future ownership: `SelectionDecorationPlanner` owns the decoration key,
including `boundsRevision`, and keeps selection decoration state out of
ordinary record cache identity, selected move supplement records, and static
background identity.

### 15.4 Render primitive cache misses

Text, path, and stroke cache misses are bounded by the current render record, not
the scene. A main paint frame may do at most one miss fill per unique
text/path/stroke key encountered in the already-bounded record stream, and every
miss records hit/miss/eviction probes declared in the cache policy. A render
primitive cache miss must not trigger CanvasDocument projection, full-scene
candidate rebuild, global sort, resolver calls, or repaint scheduling.

---
