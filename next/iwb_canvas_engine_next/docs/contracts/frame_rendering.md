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
- `dfd_main_paint_frame`
- `dfd_overlay_frame`
- `seq_main_paint`
- `seq_overlay_paint`
Required tests:
- `test.store.no_projection_hot_path`
- `test.frame.main_overlay_capture`
- `test.frame.no_live_runtime_read_in_painters`
- `test.frame.paint_plan_excludes_preview_delta`
- `test.frame.camera_pan_preserves_ordinary_paint_plan`
- `test.frame.selected_supplement_staging_no_global_sort`
- `test.surface.widget_paint`
Guardrails:
- `preview.selected_move_main_repaint`
- `frame.no_global_scene_sort`
- `frame.paint_plan_excludes_preview_delta`
- `cache.frame_meta_not_element_visual`
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
  frameMetaRevision
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
- v1 resolver calls are synchronous and bounded by the per-frame resolver budget;
- camera/background/grid changes use frameMetaRevision and must not invalidate ordinary committed element paint plans.
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
1. Lookup or build the committed ordinary paint plan from PaintPlanCache.
2. PaintPlanCache stores only ordinary committed RenderElementRecord data.
3. PaintPlanCache key uses structuralRevision, boundsRevision,
   elementVisualRevision, viewport, and selectionRevision.
4. PaintPlanCache key must not include frameMetaRevision, selectedMoveDelta, or
   previewDelta.
5. When selectedMoveDelta is active, filter movable selected ids from the
   ordinary record stream for this frame only.
6. Query visibilityRect shifted by -previewDelta for selected supplement
   candidates.
7. Resolve selected handles and create shifted RenderElementRecord instances
   with previewDelta for this frame only.
8. Merge filtered ordinary records and supplement records by orderToken.
9. Do not store selected supplement records in PaintPlanCache.
10. Do not global sort all scene elements.
11. Do not materialize CanvasDocument.
```

---
