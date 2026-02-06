# Performance and maintainability backlog

## Correctness backlog (core/hit-test)

### Important (P1 — correctness before new core features)

- [x] Fix phantom hit-testing for invalid `PathNode` stroke-only data (`svgPathData` parse fails): `hitTestNode` currently falls back to `boundsWorld.inflate(...)` and can return `true` around `Rect.zero` for non-renderable paths.
- [x] Make `segmentsIntersect` numerically robust for near-collinear doubles: remove exact `val == 0` checks and add epsilon-aware orientation/on-segment logic, then add regression tests for eraser-adjacent segment cases.
- [x] Define and enforce a single model-level policy for negative/non-finite width-like inputs (`thickness`, `strokeWidth`, `hitPadding`): either strict validation at mutation boundaries or explicitly documented soft normalization everywhere.

### Follow-up (post-P1 implementation review)

- [x] Remove hot-path list allocation in `segmentsIntersect` (`lib/src/core/geometry.dart`): replace temporary `List<double>` + `reduce(math.max)` with allocation-free max aggregation over local doubles.
- [x] Add missing regression for invalid fill-only `PathNode` hit-test (`test/core/geometry_test.dart`): `buildLocalPath() == null` must be non-interactive for fill-only as well.
- [x] Add large-scale near-collinear regression coverage for segment predicates (`test/core/geometry_test.dart`): validate stability for very large coordinate magnitudes.
- [x] Stabilize plan structure edits: when closing item checkboxes, avoid unrelated rewrites of `DEVELOPMENT_PLAN.md` sections unless the task explicitly includes plan restructuring.

Plan editing rule: checkbox-only updates in this file must be minimal and scoped to the target items; section reorder/reflow is out of scope unless explicitly requested.

### Nice to have (P2 — behavior/UX alignment)

- [x] Decide whether `Layer.isBackground` must affect interactivity in `hitTestTopNode` (skip background layers) or remain a rendering-only flag with explicit `isSelectable=false` enforcement outside hit-testing.
- [x] Unify runtime numeric sanitization semantics for `opacity` across core/render paths (currently effectively clamped in rendering but not normalized at the core model layer).
