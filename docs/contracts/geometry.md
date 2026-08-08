<!-- CONTEXT:BEGIN -->
Registry id: `section_16_geometry_policy`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/geometry.md`
Owns:
- 16. Geometry policy v1
Must read before editing:
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
Current owners:
- `contract`
Related diagrams:
- `dfd_pointer_preview_commit`
- `seq_hit_test_candidate_resolution`
- `seq_eraser_exact_budget`
Required tests:
- `test.geometry.hit_policy`
- `test.interaction.context_action_request`
- `test.geometry.eraser_exact_budget_inputs`
- `test.geometry.eraser_exact_budget_no_partial_commit`
- `test.frame.measured_text_layout`
- `test.guardrails.text_surface_guardrail_checks`
Guardrails:
- `geometry.committed_handle_order`
- `geometry.eraser_exact_budget_no_partial`
- `text.single_measured_layout_source`
Do not assume:
- geometry reads committed frame facts, not runtime owner internals
- hit ordering is owned by committed handle order tokens
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

Context-action target eligibility is separate from selection hit eligibility:

```text
point finite && content element.isVisible && transform finite && transform invertible && exact geometry hit
```

Context-action target resolution:

```text
- content layers only;
- reverse layer order;
- reverse element order within layer;
- first exact geometry hit wins as the topmost content target in content paint order;
- element.isSelectable does not gate context-action targets;
- non-selectable visible content elements can produce content-element context targets;
- background elements never produce content-element context targets;
- a point covered only by background elements resolves as an empty-canvas target
  when it otherwise satisfies double-tap timing and slop constraints.
```

Point hit:

```text
- content layers only;
- reverse layer order;
- reverse element order within layer;
- first exact hit wins;
- policy-owned topmost hit result exposes both element id and paint order token
  when interaction admission needs occlusion-aware ordering facts;
- background elements are not pointer-selectable in v1.
```

Box/image/text/rect hit:

```text
- coarse bounds = transformed local bounds inflated by hitPadding + 4.0;
- exact hit uses inverse transform and local bounds inflated by scene padding mapped into local space;
- text local paint, hit, selection, edit, and context bounds come from
  frame-measured `MeasuredTextLayout` facts; geometry must not calculate text
  bounds from string length, font size, maxWidth, or a second TextPainter;
- measured text bounds are stable relative to the element transform when only
  `TextAlign` changes, so selection/edit frames do not jump between left,
  center, and right alignment; alignment affects glyph placement inside the
  measured layout, not the owning geometry anchor;
- if a committed row has a non-invertible transform, treat it as corrupted
  internal state: the `section_20_diagnostics_hub` routing table classifies
  the deferred corrupted-row route as policy-gated `spatial` diagnostics;
  until that future route is implemented, the hit path returns miss and
  continues the candidate scan without state mutation;
- coarse candidate bounds may never accept a non-invertible box/image/text/rect
  hit.
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
- active text editing suppresses only frame paint output for the active text
  element; it does not change geometry visibility, hit membership, context
  membership, or document `CanvasTextElement.isVisible`;
- background elements are included in paint scope;
- content elements are included in paint scope;
- candidate admitted if queryRect overlaps paintBoundsWorld;
- edge-touch tests must cover the current hit-admission behavior.
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
budget exceeded increments eraser-owned metric/probe counters only; this is not a DiagnosticsHub write;
budget exceeded does not mutate document, selection, spatial index, projection,
cache, repaint main scene, or emit erase action.
Geometry/spatial owns the geometry primitives and exact-check budget
foundations; terminal no-partial-commit behavior is owned by the eraser
interaction path.
```

---
