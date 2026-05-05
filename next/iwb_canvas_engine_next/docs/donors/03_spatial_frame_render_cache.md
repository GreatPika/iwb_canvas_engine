<!-- CONTEXT:BEGIN -->
Registry id: `donors_03_spatial_frame_render_cache`
Source: `docs/_registry/donors.yaml / Spatial, frame, render, and cache donors`
Canonical source: `docs/_registry/donors.yaml`
Feeds registry: `docs/_registry/donors.yaml`
Feeds indexes:
- `docs/indexes/donor_to_phase.md`
Use rule: donor entries are phase-bound implementation inputs, not old architecture to copy.
<!-- CONTEXT:END -->

## Spatial, frame, render, and cache donors

These are valuable after the committed store and revision model exist. Do not
copy old controller shells.

| Donor | What to preserve | Reuse | Risks | Target phase |
|---|---|---:|---|---|
| `lib/src/core/scene_spatial_index.dart` | uniform-grid index, separate hit/paint entries, outlier fallback, `structuralRevision` candidate payload | `adapt` | old `Scene`, `SceneNode`, locator maps, background sentinel | P7 |
| `lib/src/controller/internal/spatial_index_cache.dart` | lazy build, epoch invalidation, incremental commit, fallback rebuild, debug counters | `adapt` | old `ChangeSet` and controller revisions | P7/P8 |
| `lib/src/controller/scene_store_controller.dart` spatial query/resolve paths | opaque committed candidates and stale `structuralRevision` rejection | `adapt` | current file is mixed controller facade | P5/P7 |
| `lib/src/core/snapshot_paint_admission_bounds.dart` | bounded snapshot-local paint-bounds cache keyed by node revision/validity | `adapt` | validity keys must be rebuilt for next shapes | P8 |
| `lib/src/core/scene_snapshot_paint_candidates.dart` | snapshot fallback enumeration and selected preview widened visibility rect | `adapt` | only valid for non-committed fallback paths | P8 |
| `lib/src/contract/scene_view_render_state.dart` | atomic frame-read and immutable preview snapshot model | `adapt` | old contract path/name must not leak | P8 |
| `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` | committed fast path only when frame snapshot matches committed snapshot | `adapt` | do not port controller shell | P8 |
| `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart` | ordered paint plan, selected supplements, preview-shifted bounds, merge without global full-scene sort | `adapt` | requires new order-token and selection model | P8 |
| `lib/src/render/scene_painter_frame.dart` | viewport calculation, halo visibility budget, single paint-plan call | `adapt` | Flutter/render-specific and node-snapshot coupled | P8/P10 |
| `lib/src/render/scene_render_caches.dart` | single render-cache owner lifecycle and epoch/controller swap clearing | `adapt` | lifecycle belongs to new frame/surface owner | P8/P10 |
| `lib/src/render/cache/scene_static_layer_cache.dart` | recorded grid/background cache and explicit `Picture.dispose` lifecycle | `adapt` | only if next keeps static layer cache | P8/P10 |
| `lib/src/render/cache/scene_text_layout_cache.dart`, `scene_stroke_path_cache.dart`, `scene_path_metrics_cache.dart` | text layout, stroke path, path metrics cache shapes | `adapt` | old keys depend on snapshots/revisions | P8 |

