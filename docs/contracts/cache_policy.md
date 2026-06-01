<!-- CONTEXT:BEGIN -->
Registry id: `section_18_cache_policy`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/cache_policy.md`
Owns:
- 18. Cache policy ledger
Must read before editing:
- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
- `section_17_spatial_kernel` -> `docs/contracts/spatial_kernel.md`
Feeds phases:
- `P9`
- `P13`
- `P14`
Related donors:
- `direct_scan_resistant_cache`
- `scene_render_caches`
- `static_layer_cache`
- `text_stroke_path_metrics_caches`
Related diagrams:
- `dfd_cache_invalidation`
Required tests:
- `test.frame.cache_keys_do_not_use_legacy_snapshot_shape`
- `test.frame.cache_capacity_eviction_policy`
- `test.frame.paint_plan_write_all_or_nothing`
- `test.frame.paint_plan_excludes_preview_delta`
- `test.frame.paint_plan_excludes_selection_state`
- `test.frame.camera_pan_preserves_ordinary_paint_plan`
Guardrails:
- `cache.keys_use_next_revisions_only`
- `cache.hot_caches_have_capacity_eviction`
- `cache.background_grid_not_element_visual`
- `frame.paint_plan_excludes_preview_delta`
- `frame.paint_plan_excludes_selection_state`
Do not assume:
- no unbounded cache owner sprawl
- no cache keys tied to legacy snapshots
<!-- CONTEXT:END -->

## 18. Cache policy ledger

| Cache | Owner | Key | Invalidated by | Capacity | Eviction | Metric/probe | Hot path allowed? |
|---|---|---|---|---:|---|---|---|
| DocumentProjectionCache | Store | projectionRevision | document/projection change | 1 committed projection per revision | replace on projectionRevision | projection read hit/miss | no in pointer/paint/hit |
| TextLayoutCache | Frame | text/style/font/width/direction/lineHeight | text/style update | 1024 entries | scan-resistant LRU | entries, hit/miss, eviction count | yes bounded |
| PathGeometryCache | Geometry/Frame | pathData/fillRule/strokeWidth | path update | 1024 entries | scan-resistant LRU | entries, hit/miss, eviction count | yes bounded |
| StrokePathCache | Frame | pointsKey/thickness/transform scale | stroke update | 1024 entries | scan-resistant LRU | entries, hit/miss, eviction count | yes bounded |
| StaticBackgroundCache | Frame | backgroundRevision, gridRevision, gridStrokeWidth, viewCameraBucket, viewportRect, devicePixelRatio | view camera bucket/background/grid/captured grid style input | 1 latest picture for the current full static-background key | replace and dispose previous picture on key change or invalidation | picture count, rebuild count | yes bounded |
| OrdinaryPaintRecordCache | Frame | structuralRevision, boundsRevision, elementVisualRevision, viewportRect, devicePixelRatio | typed invalidation excluding background, grid, view camera, preview, selection-only, and style-only changes | 16 viewport/revision entries, each capped at 1024 record-key entries | LRU by viewport/revision tuple and per-entry record key | entry count, hit/miss, eviction/write probes | yes bounded |
| ImageResolveCache | SurfaceResourceSession | resolverGeneration, resourceId, resourceRevision | resolver replacement, descriptor change, resource dirty target/all, detach/dispose/runtime swap | 1024 entries per active session | target/all invalidation, generation reset, then LRU | resolver-call budget and pending budget follow-up flag | yes bounded sync resolver |
| SelectionDecorationPlan | Frame | selectionRevision, structuralRevision, boundsRevision, captured selectionStyle, devicePixelRatio | selection/structure/bounds/captured style/DPR input | 1 current decoration plan | replace on revision, bounds, style, or DPR change | selected count, rebuild count | yes bounded |
| SelectedOrderCache | Frame | selectionRevision/structuralRevision | selection/structure | 1 selected-order snapshot | replace on revision change | selected count, rebuild count | yes bounded |
| SpatialIndex | Spatial | structural/bounds revisions | touched geometry/structure | current index only | invalid/rebuild lifecycle, not cache eviction | fallback count, budget-exceeded count | yes query only |
| PreviewStateSnapshot | Interaction | previewRevision | pointer/tool/load/mode/dispose | 1 preview snapshot | replace on previewRevision | preview revision churn | yes tiny |
| DiagnosticFormattingCache | Diagnostics | diagnostic id | verbose diagnostics only | 128 formatted previews | LRU, disabled on hot success path | allocation count, truncation count | no hot success path |

Cache miss in hot path must be bounded by candidate count, not total scene size.
Hot caches must declare capacity, eviction, key components, invalidation owner,
and a metric/probe before implementation.

Text/path/stroke render cache misses are local to the current render record key:
one miss can fill one bounded cache entry and record hit/miss/eviction probes,
but it must not trigger CanvasDocument projection, full-scene candidate rebuild,
global sort, resolver calls, repaint scheduling, or additional cache-owner work
outside the declared cache row.

`OrdinaryPaintRecordCache` stores ordinary committed render records inside a bounded
viewport/revision entry, not the reusable viewport-admitted ordinary record
stream for a frame. Spatial admission is rebuilt per captured frame from the
effective world viewport; cache hits may reuse only the admitted records whose
committed record keys match the current candidates. Each viewport/revision entry
keeps at most 1024 record-key entries using per-entry LRU replacement, so camera
movement can reuse recently admitted records without unbounded scene growth. It
must not store selected-move supplement records, `selectedMoveDelta`, or
`previewDelta`.
It also must not store selected ids, selection flags, or selectionRevision in
ordinary cache keys or cached ordinary records. `backgroundRevision`,
`gridRevision`, `gridStrokeWidth`, `viewCameraRevision`, `viewCameraOffset`, and
captured style-only inputs are not OrdinaryPaintRecordCache entry-key
components because view camera, background, grid, and style-only changes repaint
frame surfaces or decoration plans without changing ordinary element render
records. Runtime view camera changes also do not invalidate public
`CanvasDocument` projection.
The executable ordinary-cache exclusion guardrails cover all ordinary-record
storage surfaces, including `PaintPlanKey`, `OrdinaryPaintRecordKey`,
`OrdinaryPaintRecordCacheEntry`, `PaintPlan`, and the registered render-row
payloads. Rejected shifted selected-move admission must publish the ordinary
frame unchanged and perform no ordinary cache write.
Committed background elements are still ordinary render records: they are
admitted through spatial candidates and cached through their structural, bounds,
elementVisual, generation, and order-token facts. The separate background/grid
identity above belongs to static background and grid rendering only.

`SelectedOrderCache` is derived data. Its source of truth is the selection owner
plus document order facts from the document boundary; it may be retained only as
a bounded snapshot keyed by `selectionRevision` and `structuralRevision`.

---
