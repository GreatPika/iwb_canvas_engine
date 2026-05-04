<!-- CONTEXT:BEGIN -->
Registry id: `section_15_frame_render_contract`
Registry source: `docs/split/_registry/sections.yaml`
Document path: `docs/split/contracts/frame_rendering.md`
Owns:
- 15. FrameEngine and render contract
Must read before editing:
- `section_10_runtime_data_model` -> `docs/split/architecture/03_data_model.md`
- `section_14_interaction_engine` -> `docs/split/contracts/interaction_engine.md`
- `section_16_geometry_policy` -> `docs/split/contracts/geometry.md`
- `section_17_spatial_kernel` -> `docs/split/contracts/spatial_kernel.md`
- `section_18_cache_policy` -> `docs/split/contracts/cache_policy.md`
Depends on:
- `section_10_runtime_data_model` -> `docs/split/architecture/03_data_model.md`
- `section_14_interaction_engine` -> `docs/split/contracts/interaction_engine.md`
- `section_16_geometry_policy` -> `docs/split/contracts/geometry.md`
- `section_17_spatial_kernel` -> `docs/split/contracts/spatial_kernel.md`
- `section_18_cache_policy` -> `docs/split/contracts/cache_policy.md`
Feeds phases:
- `P8`
- `P10`
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
- `docs/split/diagrams/README.md#dfd_main_paint_frame` -> `docs/split/diagrams/generated/dfd_main_paint_frame.mmd`
- `docs/split/diagrams/README.md#dfd_overlay_frame` -> `docs/split/diagrams/generated/dfd_overlay_frame.mmd`
- `docs/split/diagrams/README.md#seq_main_paint` -> `docs/split/diagrams/generated/seq_main_paint.mmd`
- `docs/split/diagrams/README.md#seq_overlay_paint` -> `docs/split/diagrams/generated/seq_overlay_paint.mmd`
Required tests:
- `test.store.no_projection_hot_path`
- `test.frame.main_overlay_capture`
- `test.frame.no_live_runtime_read_in_painters`
- `test.surface.widget_paint`
Guardrails:
- `preview.selected_move_main_repaint`
Do not assume:
- no live runtime reads in painters
- no CanvasDocument projection in paint
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
## 15. FrameEngine and render contract

### 15.1 Captured frames

Main frame:

```text
CapturedMainFrame
  documentRevision
  structuralRevision
  boundsRevision
  visualRevision
  selectionRevision
  resourceVisualRevision
  cameraOffset
  viewportRect
  selectionIds
  selectedMoveDelta
```

Overlay frame:

```text
CapturedOverlayFrame
  overlayRevision
  cameraOffset
  previewState
  selectionStyle
```

Rules:

```text
- main paint captures main frame once;
- overlay paint captures overlay frame once;
- painters do not live-read runtime;
- painters do not materialize CanvasDocument;
- stale spatial candidate is rejected by structuralRevision/generation check;
- image resolver is the only external read boundary in paint, and it cannot mutate runtime;
- v1 resolver calls are synchronous.
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
  selectionFlags
  previewDelta
```

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
1. Build ordinary paint candidates from spatial index for viewport.
2. Resolve candidate handles by generation and structuralRevision.
3. Determine selected transformable ids.
4. For selected move preview, query visibilityRect shifted by -previewDelta.
5. Resolve selected handles.
6. Create shifted RenderElementRecord with previewDelta.
7. Merge ordinary and supplement records by orderToken.
8. Do not global sort all scene elements.
9. Do not materialize CanvasDocument.
```

---

<!-- ORIGINAL-SECTION:END -->
