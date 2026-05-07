<!-- CONTEXT:BEGIN -->
Registry id: `section_16_geometry_policy`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/geometry.md`
Owns:
- 16. Geometry policy v1
Must read before editing:
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
Feeds phases:
- `P7`
- `P8`
Related donors:
- `foundation_core_geometry`
- `geometry_node_geometry`
- `geometry_hit_test`
- `geometry_interactive_geometry`
- `geometry_eraser_exact_hit`
- `foundation_transform2d`
- `direct_numeric_policy`
- `direct_local_bounds_policy`
- `direct_paint_admission`
Related diagrams:
- `dfd_pointer_preview_commit`
Required tests:
- `test.geometry.hit_policy`
- `test.geometry.no_legacy_scene_order`
- `test.geometry.eraser_exact_budget_no_partial_commit`
Guardrails:
- `geometry.no_legacy_scene_order`
- `geometry.eraser_exact_budget_no_partial`
Do not assume:
- do not port old SceneNode traversal
- do not copy legacy scene order logic
<!-- CONTEXT:END -->

## 16. Geometry policy v1

Constants:

```text
kCanvasGeometryHitSlop = 4.0
kCanvasMaxPathHitSamplesPerMetric = 2048
kCanvasSpatialCellSize = 256
kCanvasMaxCellsPerElement = 1024
kCanvasMaxQueryCells = 50000
```

Hit eligibility:

```text
point finite && element.isVisible && element.isSelectable && transform finite
```

Point hit:

```text
- content layers only;
- reverse layer order;
- reverse element order within layer;
- first exact hit wins;
- background elements are not pointer-selectable in v1.
```

Box/image/text/rect hit:

```text
- coarse bounds = transformed local bounds inflated by hitPadding + 4.0;
- exact hit uses inverse transform and local bounds inflated by scene padding mapped into local space;
- if transform non-invertible, fall back to coarse candidate bounds.
```

Line hit:

```text
- transform start/end to world;
- radius = transformed(thickness / 2) + hitPadding + 4.0;
- hit if squared distance point-to-segment <= radius^2;
- degenerate segment becomes point hit.
```

Stroke hit:

```text
- empty stroke never hits;
- one-point stroke is circular hit;
- multi-point stroke checks every transformed segment;
- radius = transformed(thickness / 2) + hitPadding + 4.0;
- points are capped/resampled to max stroke limit at commit.
```

Path hit:

```text
- path data parsed into centered local path;
- fillRule applied as nonZero/evenOdd;
- if fillColor != null, localPath.contains(localPoint) hits;
- fill contour padding uses path metrics forceClosed=true;
- if strokeColor != null && strokeWidth > 0, stroke path metrics are checked;
- metric sampling step = max(0.5, radius * 0.5) but capped by 2048 samples per metric;
- invalid/unparseable path has zero bounds and never hits.
```

Paint admission:

```text
- paint bounds are separate from hit bounds;
- invisible elements are not painted;
- background elements are included in paint scope;
- content elements are included in paint scope;
- candidate admitted if queryRect overlaps paintBoundsWorld;
- edge-touch parity tests must cover legacy behavior.
```

Marquee selection:

```text
- selection rectangle normalized;
- candidate if hitBoundsWorld overlaps marquee rect;
- exact family inclusion test runs after coarse overlap;
- only visible && selectable elements can be selected;
- locked elements can be selected but cannot be moved/transformed.
```

Eraser:

```text
- eraser corridor is a polyline in world coordinates;
- coarse query uses corridor envelope inflated by eraserThickness/2 + hitPadding + 4.0;
- exact deletion uses segment-to-family geometry checks;
- deletes only isDeletable=true elements;
- background elements are not erased in v1.
```

Eraser exact-check budget:

```text
kMaxEraserPreviewCandidatesPerSample = 512;
kMaxEraserPreviewExactChecksPerSample = 4096;
kMaxEraserTerminalCandidates = 4096;
kMaxEraserTerminalExactChecks = 32768;
preview budget exceeded -> corridor-only preview, no tentative ids;
terminal budget exceeded -> cleanup/no-op, no partial erase;
budget exceeded increments diagnostic/probe counters;
budget exceeded does not mutate document, selection, spatial index, projection,
cache, repaint main scene, or emit erase action.
```

---
