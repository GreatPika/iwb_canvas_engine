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
Current owners:
- `contract`
Related diagrams:
- `dfd_main_paint_frame`
- `dfd_overlay_frame`
- `seq_main_paint`
- `seq_overlay_paint`
Required tests:
- `test.store.no_projection_hot_path`
- `test.frame.main_overlay_capture`
- `test.frame.frame_record_painter_boundary`
- `test.guardrails.frame_committed_facts_via_frame_facts_port`
- `test.frame.frame_spatial_paint_admission`
- `test.frame.frame_drawable_policy`
- `test.frame.marquee_captured_style`
- `test.surface.no_live_runtime_read_in_painters`
- `test.surface.overlay_drawable_policy`
- `test.surface.marquee_captured_style`
- `test.frame.selection_decoration_plan`
- `test.surface.selection_chrome_topmost_paint`
- `test.surface.selection_chrome_hit_target_boundary`
- `test.frame.paint_plan_write_all_or_nothing`
- `test.frame.paint_plan_excludes_preview_delta`
- `test.frame.paint_plan_excludes_selection_state`
- `test.frame.measured_text_layout`
- `test.guardrails.text_surface_guardrail_checks`
- `test.frame.camera_pan_preserves_ordinary_paint_plan`
- `test.frame.selected_supplement_staging_no_global_sort`
- `test.api_contract.preview_state_sealed_union`
- `test.api.runtime_surface_frame_bridge`
- `test.surface.surface_frame_output_cache`
- `test.surface.widget_paint`
Guardrails:
- `preview.selected_move_main_repaint`
- `api.preview_state_sealed_union_publicly_readable`
- `frame.committed_facts_via_frame_facts_port`
- `frame.no_global_scene_sort`
- `frame.paint_plan_excludes_preview_delta`
- `frame.paint_plan_excludes_selection_state`
- `text.single_measured_layout_source`
- `text.no_overlay_textpainter_measurement`
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
  viewportRect
  effectiveWorldBounds
  previewRevision
  viewCameraRevision
  viewCameraOffset
  previewState
  selectionStyle
```

`CapturedOverlayFrame` is compact overlay output. It freezes only the viewport
facts, preview facts, view camera facts, and captured selection style needed by
overlay preview admission and painting. Overlay frame capture must not read
committed document facts, spatial candidates, selection facts, background facts,
element rows, or resource descriptor facts.

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
- overlay paint captures one compact overlay frame once from surface/runtime
  value inputs;
- committed frame facts enter FrameEngine through FrameFactsPort;
- FrameFactsPort supplies documentRevision, structuralRevision, boundsRevision,
  elementVisualRevision, backgroundRevision, gridRevision, immutable committed
  render-row facts, immutable resource descriptor snapshots, and resourceRevision;
- FrameFactsPort rejects stale row facts by captured structuralRevision,
  generation, and orderToken before FrameEngine builds render records;
- FrameFactsPort must not return RenderElementRecord, PaintPlan, selected
  supplement records, selection decoration plans, selection facts, or resolver
  state;
- painters do not live-read runtime;
- painters do not materialize CanvasDocument;
- stale spatial candidate is rejected by structuralRevision/generation/orderToken
  check;
- frame paint admission accepts only explicit spatial candidate results;
  typed non-candidate spatial results stay visible as rejected admissions
  instead of becoming successful candidate streams;
- `SurfaceResourceSession` is the only image resolution boundary in paint, and
  app resolver callbacks cannot mutate runtime;
- v1 resolver calls are synchronous and bounded by the per-frame resolver budget;
- runtime view camera changes use `state.revisions.viewCamera`, repaint affected
  frame surfaces, and must not invalidate ordinary committed element paint
  plans or public `CanvasDocument` projection;
- background/grid document changes use internal backgroundRevision/gridRevision
  facts and captured grid style values where they affect static background
  output, and must not invalidate ordinary committed element paint plans.
- `FrameTextLayoutMeasurer` is the single TextPainter owner for committed and
  live text layout measurement. It produces immutable `MeasuredTextLayout`
  bounds for paint, hit, selection, edit, and context geometry, and frame code
  hands those metrics to geometry/spatial/frame consumers instead of allowing
  downstream formula bounds or duplicate overlay measurement.
- active inline text editing suppresses matching original text records and
  selection decoration in frame output using runtime-owned active session facts.
  Suppression must not mutate `CanvasTextElement.isVisible`, remove the element
  from hit/context membership, or change committed document state.
```

Accepted internal split:

`FrameEngine` remains the frame-internal facade for orchestration order,
collaborator composition, painter input assembly, and repaint bus coordination.
It delegates target frame-owned derived data construction to seven
frame-private collaborators:

| Target collaborator | Owns | Must not own |
|---|---|---|
| `FrameCaptureService` | one-time capture of main/overlay live frame facts into `CapturedMainFrame` and `CapturedOverlayFrame` | record planning, resolver/session calls, cache mutation beyond captured-frame construction |
| `OrdinaryPaintPlanner` | per-frame ordinary spatial admission and committed render-record cache lookup/build inside the 16-entry viewport/revision OrdinaryPaintRecordCache | selection revision, selection style, selected move delta, preview state, resource resolver/session, static background identity |
| `SelectedMoveSupplementPlanner` | per-frame selected move filtering, shifted candidate lookup, row resolution, and merge by `orderToken` | ordinary `OrdinaryPaintRecordCache` writes, overlay rendering, global scene sort |
| `SelectionDecorationPlanner` | single-element or multi-select group selection UI decoration, chrome placement metadata, and `SelectionDecorationPlan` key including `boundsRevision`, structural invalidation, plus selected-move preview chrome suppression | ordinary record cache identity, selected move supplement records, static background identity |
| `PaintAssetBindingService` | descriptor-to-asset binding for records with image resource ids, using immutable descriptor facts and `SurfaceResourceSession` | ordinary paint plan construction, painter resolver calls, app resolver ownership |
| `StaticBackgroundPlanner` | static background/grid plan and cache identity | selection, preview, resource visual, ordinary element visual identity |
| `OverlayPreviewPlanner` | immutable overlay primitives admitted from `CapturedOverlayFrame` | selected move rendering, resource resolver reads, cache invalidation, repaint scheduling |

`OrdinaryPaintPlanner` builds only ordinary committed record plans and excludes
selection revision, selection style, selected move delta, preview state,
resolver/session access, and static background identity from its cache inputs.
Committed background elements are part of the ordinary committed record stream;
`StaticBackgroundPlanner` owns only static background and grid output, not
document element rows.
`PaintAssetBindingService` is the only target frame collaborator that receives
`SurfaceResourceSession`; painters remain immutable-output consumers and never
receive store, runtime, resolver, or public document read access.
It starts the frame resource pass before image resolution so resolver budgets,
same-frame null suppression, and budget follow-up throttles belong to the
current main paint frame.

Surface repaint routing is split before frame output construction. `RuntimeRoot`
aggregates runtime-owned repaint intent into the internal
`CanvasSurfaceRepaintTarget` published through the runtime-surface bridge, and
`CanvasSurface` consumes that target to decide whether to rebuild main output,
overlay output, or both. `FrameRepaintSignal` remains frame-owned metadata on
immutable frame outputs after they have been built; it is not the pre-output
surface scheduling source. Main and overlay painters consume only their layer
output listenables and immutable output values, so painter repaint remains
output-only and never reads runtime, store, resolver, session, or public
document state during paint.

Overlay preview primitives are immutable frame output admitted from
`CapturedOverlayFrame`. Marquee primitives carry the captured
`CanvasSelectionStyle` values needed for stroke and fill output; the overlay
painter consumes those primitive fields and does not re-read live style state.

`FrameDrawablePolicy` is the single frame-owned drawable edge-case policy.
One-point committed strokes, one-point stroke previews, one-point eraser
corridors, and same-point committed or preview lines render as explicit
commands at the frame boundary. Multi-point stroke and eraser preview polylines
render through round path stroke joins rather than independent point segments
so preview turns remain visually continuous with committed strokes. Committed
stroke paths and overlay stroke previews use round caps and round joins.
Non-degenerate committed lines and overlay line previews use round caps. Empty
point lists remain no-op draw inputs.

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

Ordinary `RenderElementRecord` values cached in `OrdinaryPaintRecordCache` do
not include selection membership, selection flags, selected-move preview deltas,
viewport admission results, or any other selection-only state. Selection UI is
built as separate decoration primitives and painted from immutable frame output
after the ordinary main-record stream so selected chrome remains above all main
scene content. Selected-move supplement records are per-frame values that are
never stored in the ordinary paint plan cache.

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
1. Read captured spatial candidates from the effective world viewport for this
   frame.
2. Admit ordinary committed candidates for this frame before cache lookup.
3. Lookup the OrdinaryPaintRecordCache entry by structuralRevision, boundsRevision,
   elementVisualRevision, viewportRect, and devicePixelRatio.
4. Reuse only the admitted committed RenderElementRecord values whose record
   identity matches the current spatial candidates by element id, generation,
   and orderToken; build the missing admitted records before writing the entry.
5. OrdinaryPaintRecordCache keys and cached records must not include backgroundRevision,
   gridRevision,
   gridStrokeWidth, viewCameraRevision, viewCameraOffset, selectedMoveDelta,
   previewDelta, selected ids, selection flags, selectionRevision, or captured
   style-only inputs. OrdinaryPaintRecordCache also must not store the viewport-admitted
   ordinary record stream as a reusable cache value.
6. Build a per-frame PaintPlan from the current admitted record stream. Its
   PaintPlanKey is the cache-entry lookup, but the entry can only reuse records
   admitted again by the current frame.
7. When `CanvasSelectedMovePreview` is active, query `visibilityRect` shifted by
   `-previewDelta` and admit the shifted spatial result before filtering
   selected ordinary records.
8. Rejected shifted admission publishes the ordinary records unchanged for that
   paint, exposes the internal rejection reason, and performs no ordinary cache
   writes.
9. For admitted shifted candidates, read selected ids through the captured
   selection facts boundary and filter movable selected ids from the ordinary
   record stream for this frame only.
10. Resolve selected handles through `FrameFactsPort` against the captured
   structuralRevision, generation, and orderToken.
11. If the selected row facts are current, create shifted RenderElementRecord
   instances with previewDelta for this frame only.
12. If `FrameFactsPort` rejects a stale selected candidate, skip that candidate
   and do not build a supplement RenderElementRecord for it.
13. Merge filtered ordinary records and supplement records by orderToken.
14. Do not store selected supplement records in OrdinaryPaintRecordCache.
15. Do not global sort all scene elements.
16. Do not materialize CanvasDocument.
```

Accepted internal ownership: `OrdinaryPaintPlanner` owns steps 1 through 6, while
`SelectedMoveSupplementPlanner` owns steps 7 through 15. The supplement planner
consumes captured selection facts and ordinary records for the current frame,
but does not write the ordinary `OrdinaryPaintRecordCache`, does not render overlays, and
does not global sort the scene.

Selection decoration reads selected ids and selectionRevision through the same
captured selection facts boundary and is invalidated separately from ordinary
paint plans. Its decoration key includes `boundsRevision` because selected
element bounds can change without changing selection membership, and it includes
structural facts that can change selected chrome family placement without
changing selected ids. When `CanvasSelectedMovePreview` is active, the key
records that selection chrome is hidden and the decoration plan emits no
primitives; selected-move delta and previewRevision churn while active does not
rebuild a visually empty decoration plan. Single selection emits one primitive
for that element when no selected-move preview is active. Multi-select emits one
group-box primitive whose bounds are the union of selected paint bounds.
Group-box chrome, single rect chrome, and single image chrome use outside-box
stroke placement so their stroke inner edge aligns with the primitive bounds;
single line, stroke, text, and path chrome remain bounds/outline placement
unless a later owner-specific decoration contract changes them. This keeps
selected-move visual feedback owned by the selected-move supplement without
adding preview state to ordinary paint cache identity. `selectedOrder` is
derived data or a bounded cache keyed by `selectionRevision` and
`structuralRevision`; it is not a second stored selection source of truth and is
not the chrome paint-order source. Accepted internal ownership:
`SelectionDecorationPlanner` owns the decoration key, primitive grouping,
placement metadata, and selected-move chrome suppression facts, and keeps
selection decoration state out of ordinary record cache identity, selected move
supplement records, and static background identity. `MainFramePainter` consumes
those immutable primitives after the main-record stream so selection chrome
stays topmost within the main scene.

### 15.4 Render primitive cache misses

Text, path, and stroke cache misses are bounded by the current render record, not
the scene. A main paint frame may do at most one miss fill per unique
text/path/stroke key encountered in the already-bounded record stream, and every
miss records hit/miss/eviction probes declared in the cache policy. A render
primitive cache miss must not trigger CanvasDocument projection, full-scene
candidate rebuild, global sort, resolver calls, or repaint scheduling.

---
