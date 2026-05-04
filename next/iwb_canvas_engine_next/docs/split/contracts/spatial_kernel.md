<!-- CONTEXT:BEGIN -->
Registry id: `section_17_spatial_kernel`
Registry source: `docs/split/_registry/sections.yaml`
Document path: `docs/split/contracts/spatial_kernel.md`
Owns:
- 17. SpatialKernel
Must read before editing:
- `section_10_runtime_data_model` -> `docs/split/architecture/03_data_model.md`
- `section_15_frame_render_contract` -> `docs/split/contracts/frame_rendering.md`
- `section_16_geometry_policy` -> `docs/split/contracts/geometry.md`
Feeds phases:
- `P7`
- `P8`
Related donors:
- `spatial_scene_spatial_index`
- `spatial_index_cache`
- `store_scene_controller_read_paths`
Related diagrams:
- `dfd_cache_invalidation`
Required tests:
- `test.spatial.touched_update`
Guardrails:
- `none`
Do not assume:
- do not port old Scene or locator maps
- do not rely on stale structuralRevision
<!-- CONTEXT:END -->

## 17. SpatialKernel

Spatial structure:

```text
SpatialKernel
  hitIndex: TileIndex
  paintIndex: TileIndex
  hitOutliers: OutlierIndex
  paintOutliers: OutlierIndex
  entriesById
  structuralRevision
```

Tile policy:

```text
cellSize = 256;
if covered tile count > 1024 -> outlier only;
if query tile count > 50000 -> fallback candidate union, diagnostic counter incremented;
normal element is not duplicated into all tiles when marked outlier;
queries union tile candidates + outliers;
ordinary edit updates only touched ids;
document replacement rebuilds full index.
```

Staged update algorithm:

```text
1. compile SpatialDelta from TouchedSet;
2. prepare removals using old memberships;
3. prepare additions using new bounds;
4. validate ids/generations/revisions;
5. apply removals;
6. apply additions;
7. update entriesById;
8. if any step fails, discard prepared delta and mark index invalid;
9. invalid index uses bounded fallback and schedules rebuild outside hot pointer path.
```

Full clone of spatial index for ordinary edit is forbidden. Page-level copy is allowed only for touched pages.

---

