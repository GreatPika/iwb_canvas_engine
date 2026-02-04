# Performance and maintainability backlog

## Important (P1 — after P0 or when jank appears)

- [x] Cache text layout (`TextPainter`/layout) for `TextNode` to avoid recomputing text every frame.
- [x] Cache draw path for `StrokeNode` to avoid rebuilding `Path` every frame for long or numerous strokes.
- [x] Clarify and separate `selectionRect` updates vs selection/scene "revisions" so selection state is predictable for optimizations and maintenance.

## Nice to have (P2 — as needed)

- [ ] Speed up hit-testing for complex `PathNode` geometries (only if it becomes a bottleneck with large SVG paths).
- [ ] Optimize `NodeId` generation (caching/acceleration). Likely unnecessary unless scenes are very large and nodes are created in bulk.

## Optional (P3 — only with requirements + metrics)

- [ ] Spatial index for the eraser tool (adds complexity; pays off only on very large scenes / frequent erasing).
- [ ] Product-facing documentation: explicitly document serialization compatibility guarantees and external resource handling (e.g., `imageId` portability). Scope depends on cross-version/cross-device promises.
