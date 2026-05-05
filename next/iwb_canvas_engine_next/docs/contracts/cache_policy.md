<!-- CONTEXT:BEGIN -->
Registry id: `section_18_cache_policy`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/cache_policy.md`
Owns:
- 18. Cache policy ledger
Must read before editing:
- `section_15_frame_render_contract` -> `docs/contracts/frame_rendering.md`
- `section_17_spatial_kernel` -> `docs/contracts/spatial_kernel.md`
- `section_24_benchmarks` -> `docs/verification/benchmarks.md`
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
Guardrails:
- `cache.keys_use_next_revisions_only`
Do not assume:
- no unbounded cache owner sprawl
- no cache keys tied to old snapshots
<!-- CONTEXT:END -->

## 18. Cache policy ledger

| Cache | Owner | Key | Invalidated by | Hot path allowed? |
|---|---|---|---|---|
| DocumentProjectionCache | Store | projectionRevision | document/projection change | no in pointer/paint/hit |
| TextLayoutCache | Frame | text/style/font/width/direction/lineHeight | text/style update | yes bounded |
| PathGeometryCache | Geometry/Frame | pathData/fillRule/strokeWidth | path update | yes bounded |
| StrokePathCache | Frame | pointsKey/thickness/transform scale | stroke update | yes bounded |
| ImageResolveCache | Resource | resourceId/resourceRevision | resource dirty/descriptor change | yes, sync app resolver only |
| StaticBackgroundCache | Frame | background/grid/camera bucket/dpr | camera/background/grid | yes bounded |
| PaintPlanCache | Frame | structural/bounds/visual/viewport/selection | typed invalidation | yes bounded |
| SelectedOrderCache | Frame | selectionRevision/structuralRevision | selection/structure | yes bounded |
| SpatialIndex | Spatial | structural/bounds revisions | touched geometry/structure | yes query only |
| OverlayStateSnapshot | Interaction | overlayRevision | pointer/tool/load/mode/dispose | yes tiny |
| DiagnosticFormattingCache | Diagnostics | diagnostic id | verbose diagnostics only | no hot success path |

Cache miss in hot path must be bounded by candidate count, not total scene size.

---

