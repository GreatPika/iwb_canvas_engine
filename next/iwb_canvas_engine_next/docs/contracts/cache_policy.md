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
Guardrails:
- `cache.keys_use_next_revisions_only`
- `cache.hot_caches_have_capacity_eviction`
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
| ImageResolveCache | Resource | resourceId/resourceRevision | resource dirty/descriptor change | 1024 entries | target/all invalidation, then LRU | resolver calls, hit/miss, null-cache count | yes, sync app resolver only |
| StaticBackgroundCache | Frame | background/grid/camera bucket/dpr | camera/background/grid | 1 picture per camera bucket | replace and dispose old picture | picture count, rebuild count | yes bounded |
| PaintPlanCache | Frame | structural/bounds/visual/viewport/selection | typed invalidation | 16 viewport plans | LRU by viewport/revision tuple | candidate count, hit/miss, full-sort probe | yes bounded |
| SelectedOrderCache | Frame | selectionRevision/structuralRevision | selection/structure | 1 selected-order snapshot | replace on revision change | selected count, rebuild count | yes bounded |
| SpatialIndex | Spatial | structural/bounds revisions | touched geometry/structure | current index only | invalid/rebuild lifecycle, not cache eviction | fallback count, budget-exceeded count | yes query only |
| OverlayStateSnapshot | Interaction | overlayRevision | pointer/tool/load/mode/dispose | 1 overlay snapshot | replace on overlayRevision | overlay revision churn | yes tiny |
| DiagnosticFormattingCache | Diagnostics | diagnostic id | verbose diagnostics only | 128 formatted previews | LRU, disabled on hot success path | allocation count, truncation count | no hot success path |

Cache miss in hot path must be bounded by candidate count, not total scene size.
Hot caches must declare capacity, eviction, key components, invalidation owner,
and a metric/probe before implementation.

---
