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
- `P8`
- `P10`
- `P12`
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
- `test.frame.paint_plan_excludes_preview_delta`
- `test.frame.camera_pan_preserves_ordinary_paint_plan`
Guardrails:
- `cache.keys_use_next_revisions_only`
- `cache.hot_caches_have_capacity_eviction`
- `cache.frame_meta_not_element_visual`
- `frame.paint_plan_excludes_preview_delta`
Do not assume:
- no unbounded cache owner sprawl
- no cache keys tied to old snapshots
<!-- CONTEXT:END -->

## 18. Cache policy ledger

| Cache | Owner | Key | Invalidated by | Capacity | Eviction | Metric/probe | Hot path allowed? |
|---|---|---|---|---:|---|---|---|
| DocumentProjectionCache | Store | projectionRevision | document/projection change | 1 committed projection per revision | replace on projectionRevision | projection read hit/miss | no in pointer/paint/hit |
| TextLayoutCache | Frame | text/style/font/width/direction/lineHeight | text/style update | 1024 entries | scan-resistant LRU | entries, hit/miss, eviction count | yes bounded |
| PathGeometryCache | Geometry/Frame | pathData/fillRule/strokeWidth | path update | 1024 entries | scan-resistant LRU | entries, hit/miss, eviction count | yes bounded |
| StrokePathCache | Frame | pointsKey/thickness/transform scale | stroke update | 1024 entries | scan-resistant LRU | entries, hit/miss, eviction count | yes bounded |
| ImageResolveCache | Resource | resourceId/resourceRevision | resource dirty/descriptor change | 1024 entries | target/all invalidation, then LRU | resolver calls, budget-exceeded count, hit/miss, null-cache count | yes, sync app resolver only with `kMaxSyncResourceResolverCallsPerFrame = 128` |
| StaticBackgroundCache | Frame | background/grid/camera bucket/dpr/frameMetaRevision | camera/background/grid | 1 picture per camera bucket | replace and dispose old picture | picture count, rebuild count | yes bounded |
| PaintPlanCache | Frame | structural/bounds/elementVisual/viewport/selection | typed invalidation excluding frameMeta and preview | 16 viewport plans | LRU by viewport/revision tuple | candidate count, hit/miss, full-sort probe, selected-supplement bypass count | yes bounded |
| SelectedOrderCache | Frame | selectionRevision/structuralRevision | selection/structure | 1 selected-order snapshot | replace on revision change | selected count, rebuild count | yes bounded |
| SpatialIndex | Spatial | structural/bounds revisions | touched geometry/structure | current index only | invalid/rebuild lifecycle, not cache eviction | fallback count, budget-exceeded count | yes query only |
| OverlayStateSnapshot | Interaction | overlayRevision | pointer/tool/load/mode/dispose | 1 overlay snapshot | replace on overlayRevision | overlay revision churn | yes tiny |
| DiagnosticFormattingCache | Diagnostics | diagnostic id | verbose diagnostics only | 128 formatted previews | LRU, disabled on hot success path | allocation count, truncation count | no hot success path |

Cache miss in hot path must be bounded by candidate count, not total scene size.
Hot caches must declare capacity, eviction, key components, invalidation owner,
and a metric/probe before implementation.

Text/path/stroke render cache misses are local to the current render record key:
one miss can fill one bounded cache entry and record hit/miss/eviction probes,
but it must not trigger CanvasDocument projection, full-scene candidate rebuild,
global sort, resolver calls, repaint scheduling, or additional cache-owner work
outside the declared cache row.

`PaintPlanCache` stores ordinary committed records only. It must not store
selected-move supplement records, `selectedMoveDelta`, or `previewDelta`.
`frameMetaRevision` is not a PaintPlanCache key component because camera,
background, and grid changes repaint frame surfaces without changing ordinary
element paint records.

Resource resolver budget behavior:

```text
kMaxSyncResourceResolverCallsPerFrame = 128;
budget-exceeded resource resolution paints a bounded placeholder;
budget-exceeded increments a diagnostic/probe counter;
ResourceKernel owns the budget-exceeded retry scheduler;
budget-exceeded may schedule at most one pending throttled follow-up repaint;
the pending follow-up repaint flag is cleared by the next main frame resource pass;
painters and app resolvers must not schedule budget-exceeded follow-up repaints;
budget-exceeded is not cached as null, missing, or resolved image.
```

---
