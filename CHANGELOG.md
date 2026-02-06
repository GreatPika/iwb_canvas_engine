## Unreleased

- Serialization: stricter numeric validation for JSON import/export (finite
  numbers + valid ranges); invalid input throws `SceneJsonFormatException`.
- Input: `SceneController` numeric setters now reject invalid values and throw
  `ArgumentError`.
- View: add `SceneView` pointer sample callbacks (`onPointerSampleBefore`,
  `onPointerSampleAfter`) for app-level integrations (snap, grouped drag).
- Core: fix `Transform2D.applyToRect` to preserve translation for degenerate
  rects (zero width/height).
- Fix: `PathNode.buildLocalPath` no longer rejects valid linear SVG paths
  (degenerate bounds); path nodes no longer disappear/cull incorrectly.
- Fix: `LineNode` hit-testing now accounts for `hitPadding` and `kHitSlop` in
  scene units (touch-friendly, scale-aware).
- Fix: `StrokeNode` hit-testing now accounts for `hitPadding` and `kHitSlop` in
  scene units (touch-friendly, scale-aware).
- Fix: `PathNode` hit-testing includes stroke even when the node is filled
  (selection = fill ∪ stroke; coarse stage A for stroke).
- Fix: `PathNode` stroke hit-testing no longer double-counts `strokeWidth` when
  inflating `boundsWorld`; selection tolerance uses only `hitPadding + kHitSlop`.
- Fix: invalid/unbuildable `PathNode` SVG data is now non-interactive in
  hit-testing (no coarse AABB phantom hits).
- Fix: hit-testing fallback for non-invertible transforms now preserves
  `hitPadding` + `kHitSlop` and keeps nodes selectable via inflated `boundsWorld`.
- Fix: negative `thickness/strokeWidth` values are treated as zero in bounds,
  hit-testing (including `hitTestLine`), and rendering.
- Core: `segmentsIntersect` now uses scale-aware epsilon logic for near-collinear
  doubles, improving robustness in eraser-adjacent segment cases.
- Fix: runtime bounds/hit-testing/rendering sanitize non-finite numeric values
  (NaN/Infinity) to prevent crashes and non-finite geometry; JSON validation
  remains strict.
- Fix: `RectNode` bounds now include stroke thickness (`strokeWidth/2`) when stroked.
- Fix: `rotationDeg/scaleX/scaleY` setters now reject sheared transforms instead of silently normalizing to TRS.
- Core: improve numeric robustness for near-zero values (near-singular
  `Transform2D.invert()` returns `null`; derived `rotationDeg/scaleY` are stable;
  geometry helpers avoid division by almost-zero).
- Fix: `StrokeNode.normalizeToLocalCenter` and `LineNode.normalizeToLocalCenter`
  now validate preconditions at runtime and throw `StateError` in release builds
  (previously debug-only via `assert`).
- Fix: `topLeftWorld` setters now use epsilon comparisons to avoid floating-point
  micro-drift under repeated updates.
- Core: `Scene`/`Layer` constructors defensively copy `layers:`/`nodes:` lists to
  prevent external aliasing.
- Breaking: `PathNode.buildLocalPath` now has an optional named parameter
  `{copy}`; custom overrides must match the updated signature.
- Fix: `PathNode.buildLocalPath` returns a defensive copy by default; internal
  hot paths use `copy:false` to avoid per-frame allocations.
- Debug: optional `PathNode.enableBuildLocalPathDiagnostics` + debug getters to
  capture/log `buildLocalPath` failure reasons (keeps `null` return contract).

## 0.2.0 (2026-02-04)

- Breaking: remove legacy `package:iwb_canvas_engine/iwb_canvas_engine.dart`
  entrypoint; use `basic.dart` or `advanced.dart`.
- `SceneView`: `imageResolver` is now optional; add optional configuration
  parameters (`pointerSettings`, `dragStartSlop`, `nodeIdGenerator`) for the
  internally owned controller.
- `SceneController`: breaking: remove direct setters for `mode/drawTool/drawColor`
  (use `setMode/setDrawTool/setDrawColor`); add selection helpers
  (`setSelection`, `toggleSelection`, `selectAll`) and selection geometry getters
  (`selectionBoundsWorld`, `selectionCenterWorld`); add `mutate(...)` and
  `getNode/findNode`.
- Nodes: add AABB-based `topLeftWorld` / `fromTopLeftWorld` helpers for
  `RectNode`, `ImageNode`, and `TextNode`.
- Breaking: remove legacy aliases `SceneNode.aabb` and `schemaVersion`.
- Action events: document payload schemas and add typed payload accessors.
- More accurate hit-test for rotated rect/image/text nodes; `hitPadding` now
  affects them.
- Internal: tighten repaint notification invariants and add a debug-only guard
  that disables drag-move buffering on external structural scene mutations.
- Refactor input internals into vertical slices with explicit boundary
  contracts, strict import boundary checks, and slice-level regression tests.
- Tooling: add invariant registry + coverage checks to ensure every invariant is
  enforced by a test and/or tool check.
- Docs: add `CODE_REVIEW_CHECKLIST.md` for maintainers.
- Docs/tooling: keep `dart doc` warning-free via `dartdoc_options.yaml`.

## 0.1.0 (2026-02-03)

### Performance

- Cache `PathNode` local paths to reduce selection rendering overhead.
- Avoid extra scene traversal when rendering selections.
- Simplify selection halo rendering to avoid expensive path unions/layers.

### Serialization (breaking)

- JSON import/export is now v2-only (`schemaVersion = 2`). v1 scenes are not supported.

### Selection transforms

- Add horizontal flip alongside vertical flip.
- Replace rotate/flip/drag-move action events with `ActionType.transform` and
  `payload.delta` (2×3 affine matrix).
- Breaking: `ActionType.rotate` and `ActionType.flip` removed.

### Stage 1 — Public API split (basic vs advanced)

- Add `basic.dart` entrypoint with a minimal public surface.
- Add `advanced.dart` entrypoint that exports the full API.
- Document public API split and usage in README.

### Stage 2 — SceneController mutations

- Add `SceneController` mutation helpers (`addNode`, `removeNode`, `moveNode`).

### Stage 3 — notifySceneChanged invariants

- Enforce selection cleanup on `notifySceneChanged()` after external mutations.

### Stage 4 — NodeId generation

- Use per-controller NodeId seed; document `nodeIdGenerator`.

### Stage 5 — SceneView without external controller

- Allow `SceneView` without an external controller + `onControllerReady`.

### Stage 6 — Locked/transformable rules

- Define locked/transformable selection rules and document behavior.

### Stage 7 — Public API docs

- Add Dartdoc for `SceneController` public methods and streams.

### Stage 8 — Example app updates

- Update example app to use `basic.dart` and demonstrate JSON export/import.

### Selection rendering

- Draw selection outlines using each node's geometry instead of the combined AABB.
- Render selection as a halo around the node geometry.

### Backlog item delivered

- Add viewport culling in `ScenePainter` to skip offscreen nodes.

## 0.0.3

- Publish web demo (Flutter Web) to GitHub Pages.
- Improve README links for pub.dev.

## 0.0.2

- Declare supported platforms on pub.dev.
- Add documentation link to GitHub Pages.

## 0.0.1

Initial release.

- Scene model (layers, nodes, background, camera)
- Rendering via `ScenePainter` and `SceneView`
- Input handling via `SceneController` (move/draw modes)
- JSON v1 import/export with validation
- Example app and unit tests
