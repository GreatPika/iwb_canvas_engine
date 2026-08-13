<!-- CONTEXT:BEGIN -->
Registry id: `section_17_spatial_kernel`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/spatial_kernel.md`
Owns:
- 17. SpatialKernel
Must read before editing:
- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
- `section_16_geometry_policy` -> `docs/contracts/geometry.md`
Current owners:
- `contract`
Related diagrams:
- `dfd_cache_invalidation`
- `dfd_spatial_query_budget`
- `seq_spatial_touched_update`
- `seq_hit_test_candidate_resolution`
- `seq_eraser_exact_budget`
Required tests:
- `test.spatial.committed_spatial_read_boundary`
- `test.spatial.tile_outlier_membership`
- `test.spatial.touched_update`
- `test.spatial.no_full_clone_for_touched_update`
- `test.spatial.stale_generation_rejected`
- `test.spatial.fallback_budget_enforced`
- `test.spatial.invalid_index_fallback`
- `test.spatial.runtime_delivery_order`
Guardrails:
- `spatial.no_full_clone_ordinary_edit`
- `spatial.stale_candidate_rejected`
- `spatial.fallback_budget_enforced`
Do not assume:
- use current document facts and locator maps only
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
if query tile count > 50000 -> typed budget-exceeded result, non-hub budget counter incremented;
maxFallbackCandidates = 4096;
normal element is not duplicated into all tiles when marked outlier;
queries union tile candidates + outliers;
ordinary edit updates only touched ids;
document replacement or staged load invalidates the current index and schedules
the next spatial query to rebuild against committed frame facts before returning
candidates;
operation-matrix `clearContent` may reset to an empty index only when the
accepted post-clear committed frame has zero elements; when preserved background
elements remain, normal touched/rebuild delivery reads committed frame facts and
keeps their paint membership.
```

Staged update algorithm:

```text
1. compile SpatialDelta from TouchedSet;
2. prepare removals using previous memberships;
3. prepare additions using new bounds;
4. validate ids/generations/revisions;
5. apply removals;
6. apply additions;
7. update entriesById;
8. if any step fails, discard prepared delta and mark index invalid;
9. invalid index uses bounded fallback and schedules rebuild outside hot pointer path;
10. fallback candidate union that would exceed maxFallbackCandidates returns a typed budget-exceeded result instead of partial candidates.
```

Full clone of spatial index for ordinary edit is forbidden. Page-level copy is
allowed only for touched pages. Full rebuild/reset is allowed only for
replacement/load query recovery paths or the operation-matrix `clearContent`
empty reset of a genuinely zero-element post-clear frame. A clear that retains
background elements uses normal committed-frame touched/rebuild delivery; those
elements remain available to paint queries, while the existing hit and context
policies continue to exclude background elements.

Fallback budget behavior:

```text
- pure SpatialKernel fallback increments a non-hub budget counter whenever the query tile or candidate budget is hit;
- this counter is not a DiagnosticsHub write; only interaction-observed user-facing reliability events route through the `interaction` row in `section_20_diagnostics_hub`;
- budget-exceeded fallback does not return partial hit/paint candidates as valid results;
- RuntimeRoot schedules rebuild or retry outside the hot pointer/paint path;
- no fallback path may scan the full scene silently.
```

Spatial query hot path:

```text
query request -> revision/generation gate -> tile/outlier union -> candidate budget gate -> typed result;
query tile count > 50000 -> typed budget-exceeded result with no partial candidates and non-hub budget counter;
fallback candidate count > maxFallbackCandidates -> typed budget-exceeded result;
budget-exceeded result contains no partial candidates and does not mutate indexes;
invalid index can request rebuild/retry only outside the hot pointer/paint path.
```

Candidate admission is explicit. Only `SpatialCandidatesResult` carries
candidate handles. Non-candidate typed results, including budget-exceeded,
invalid-index, and stale-candidate results, must not be projected as successful
empty candidate sets by frame or interaction callers.

---
