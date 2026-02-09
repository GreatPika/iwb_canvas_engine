## Unreleased

- Add v2 snapshot JSON codec at `lib/src/v2/serialization/scene_codec.dart`
  and export it from `basic_v2.dart` / `advanced_v2.dart` with parity function
  names (`encodeScene*` / `decodeScene*`) and strict JSON validation behavior.

- Add preview v2 immutable public API entrypoints:
  `basic_v2.dart` and `advanced_v2.dart` (snapshot/spec/patch model with
  tri-state `PatchField`, no v2 controller/runtime yet).

- Serialization: `decodeScene(...)` now accepts integer-valued numeric forms
  for integer fields (for example, `schemaVersion: 2.0`); fractional numeric
  values (for example, `2.5`) remain invalid and throw
  `SceneJsonFormatException`.

- Render: grid over-density now degrades uniformly by drawing every `N`th line
  per axis (capped by `kMaxGridLinesPerAxis`) instead of silently skipping the
  grid; no major/accent lines are used.

- Render: `SceneStrokePathCache.getOrBuild(...)` is now fail-safe for `0/1`
  point strokes and no longer throws `StateError` for dot/empty geometry.

- Fix: `LineNode`/`StrokeNode` hit-testing now applies `hitPadding + kHitSlop`
  in strict scene/world units under anisotropic transforms (no max-axis
  tolerance inflation); add regression coverage for anisotropic scale probes.

- View: `SceneView` now invalidates text/stroke/path render caches when the
  bound `SceneController` instance is replaced, preventing stale cache reuse
  across scenes with reused `NodeId` values.

- Render: add `ScenePathMetricsCache` and wire it through
  `ScenePainter`/`SceneView` to avoid per-frame `Path.computeMetrics()` +
  contour decomposition for unchanged selected `PathNode`s
  (`id + svgPathData + fillRule` cache key).
- Core: harden `segmentsIntersect` for very large coordinates via local-frame
  normalization and clamped epsilon scaling; non-finite intermediate
  normalization now returns `false` deterministically.
- Tests: add dedicated `ScenePathMetricsCache` coverage and extend large-scale
  `segmentsIntersect` regression cases (endpoint touch + extreme-offset tiny
  deltas).

- Performance/Input: `SceneController` now maintains an internal
  `Set<NodeId>` membership index (`allNodeIds`) used by `newNodeId()` and
  `notifySceneChanged()` paths for O(1) id checks instead of full scene scans.
- Performance: hot-path hit-testing/eraser threshold checks now use squared
  distances (`dx*dx + dy*dy`) instead of `sqrt`-based distance comparisons.
- Input: custom `nodeIdGenerator` is now fail-fast for duplicates; when the
  callback returns an id that already exists in the scene, `newNodeId()`
  throws `StateError`.
- Render: thin-line pixel snapping now applies only to eligible geometry
  (axis-aligned unit-scale transforms with thin screen-space stroke width);
  rotated/non-unit-scale nodes skip snapping to avoid artifacts.
- Render: `SceneTextLayoutCache` key now excludes non-semantic identity/geometry
  fields (`nodeId`, box height) while preserving paint-style correctness for
  cached `TextPainter` instances (color remains part of the key).
- Render: `SceneStaticLayerCache` no longer keys by `cameraOffset`; camera pan
  now translates cached grid draw at paint time instead of rebuilding the cache.
- Render/View: `SceneView` now forwards ambient `Directionality` to
  `ScenePainter`; text layout and painting resolve `TextAlign.start/end`
  according to `TextDirection` (LTR/RTL).
- Render: `PathNode` selection highlight now respects `fillRule`
  (`evenOdd`/`nonZero`) for closed contours.
- Performance: add a uniform-grid spatial index for scene hit-test candidates.
  Move-mode hit discovery, marquee candidate lookup, and eraser deletion
  candidate lookup now use lazy-rebuilt spatial queries instead of full scene
  scans.
- Input: stroke/eraser trajectories now apply input-point decimation
  (`0.75` scene units) and always keep the final `up` sample when it differs
  from the last accepted point.
- Fix: `PathNode` stroke hit-testing now uses precise distance-to-path checks
  (with tolerance `strokeWidth/2 + hitPadding + kHitSlop`) instead of coarse
  AABB-final selection; non-invertible path transforms are non-clickable for
  both fill and stroke.
- Input/View: harden multitouch signal policy and pending-tap scheduling.
  `PointerInputTracker` now correlates double-tap by `pointerId`
  (not `PointerDeviceKind`), `SceneView` ignores tap/double-tap candidates from non-active
  pointers during an active gesture, and pending-tap flushing now uses a
  single timer window instead of timer recreation on every pointer sample.
- Input: add optional `SceneController(clearSelectionOnDrawModeEnter: true)`
  policy to clear selection when entering `CanvasMode.draw` (`false` by
  default).
- Input: marquee commit now emits `ActionType.selectMarquee` only when the
  normalized selection actually changes (no-op marquee commits emit no action).
- Input: harden dispose-safety in input slices:
  `RepaintScheduler.notifyNow()` is now a safe no-op after `dispose()`, and
  `ActionDispatcher` drops `emitAction` / `emitEditTextRequested` calls after
  `dispose()` instead of writing to closed streams.
- Input: move-drag is now transactional. `PointerPhase.cancel` and
  `setMode(...)` during an active move drag rollback node transforms and emit
  no `ActionType.transform`.
- Input: line two-tap pending start now expires via an internal `Timer(10s)`,
  so timeout works even without new pointer events.
- Input: eraser behavior is explicitly transactional commit-on-up:
  trajectory during move does not mutate scene; cancel/mode switch leaves scene
  unchanged and emits no `ActionType.erase`.
- Input: `setSelection(...)` / `toggleSelection(...)` now strictly normalize to
  interactive ids only (existing + non-background + visible + selectable).
- Input: selection contract is now explicitly unordered-set semantics; code and
  tests no longer rely on iteration order.
- Input: `clearScene()` now canonicalizes layer structure to exactly one
  background layer at index `0` (removes all non-background layers).
- Input: clarify and enforce flip command axis semantics:
  `flipSelectionHorizontal()` now reflects across the vertical axis through the
  selection center, and `flipSelectionVertical()` reflects across the horizontal
  axis through the selection center.
- Input: enforce a single background interaction policy in move/selection/delete
  paths (background nodes are non-interactive and non-deletable even when ids
  are injected).
- Input: eraser now normalizes selection by removing deleted node ids before
  publishing scene changes and emitting `ActionType.erase`.
- Serialization: `decodeScene(...)` now canonicalizes background layers to
  exactly one layer at index `0` (missing/misordered are fixed; multiple
  background layers throw `SceneJsonFormatException`).
- Breaking: `SceneController.mutate(...)` is now geometry-only and no longer
  accepts `structural:`. Use `SceneController.mutateStructural(...)` for
  add/remove/reorder layer/node edits. In debug, structural edits inside
  `mutate(...)` assert with guidance to use `mutateStructural(...)`.
- Input/View: add `SceneController.reconfigureInput(...)` for runtime updates
  of `pointerSettings`/`dragStartSlop`/`nodeIdGenerator` without recreating
  the controller. `SceneView` now applies these updates to its owned controller
  and defers activation until the current gesture ends.
- Input: make stroke/line commit fail-safe in draw mode. If
  `normalizeToLocalCenter()` throws during commit, the pending preview node is
  discarded, the tool state is reset, and no action is emitted.
- Input: `SceneController(scene: ...)` now validates constructor scene
  invariants and canonicalizes recoverable background-layer cases (ensures
  background exists at index 0, moves misordered background to index 0).
  Unrecoverable constructor violations (for example multiple background layers,
  empty palettes, non-finite camera/grid values) throw `ArgumentError`.
- Behavior: `SceneController.addNode(...)` without `layerIndex` now targets the
  first non-background layer; when no non-background layer exists, the
  controller creates one automatically.
- Fix: enforce unique `NodeId` at both mutation and JSON boundaries:
  `SceneController.addNode(...)` now throws `ArgumentError` for duplicate IDs,
  and `decodeScene(...)` throws `SceneJsonFormatException` when duplicate node
  IDs are present in input JSON.
- Fix: harden grid safety limits to prevent pathological rendering load:
  clamp `setGridCellSize` to minimum `1.0` when grid is enabled, skip grid
  paint for `cellSize < 1.0`/non-finite values, and skip when expected grid
  lines exceed `200` per axis.
- Render/View: add configurable thin-line pixel snap strategy
  (`ThinLineSnapStrategy`) and enable HiDPI-friendly snapping for
  axis-aligned 1 logical px lines/strokes in `ScenePainter`/`SceneView`.
- Input: unify `ActionCommitted.timestampMs` scale for command defaults with
  pointer time (monotonic timeline, strict `+1` fallback progression).
- Input: normalize all inbound timestamp hints (pointer/commands/signals) via a
  single controller contract; `ActionCommitted.timestampMs` and
  `EditTextRequested.timestampMs` are now strictly monotonic.
- Input: `SceneController.setCameraOffset(...)` now rejects non-finite
  offsets (`NaN`/`Infinity`) with `ArgumentError` and preserves camera state
  on rejection.
- Behavior: `hitTestTopNode` now skips `Layer.isBackground` layers, so
  background content is no longer returned by top-level selection hit-testing.
- Fix: `PathNode` fill hit-testing no longer uses coarse AABB fallback for
  degenerate/non-invertible transforms (`inverse == null` now returns `false`
  for fill; stroke stage-A behavior is unchanged).
- Core: normalize `SceneNode.opacity` at assignment time (`!finite -> 1`,
  clamp `[0,1]`), aligning model/runtime behavior with rendering.
- Perf: remove hot-path list allocation in `segmentsIntersect` by switching to
  allocation-free max-scale aggregation.
- Tests: extend invalid `PathNode` hit-test regression to cover fill-only nodes
  (`buildLocalPath() == null` stays non-interactive).
- Tests: add large-scale near-collinear regression cases for segment
  intersection predicates.
- Docs: add a plan-editing guardrail to keep `DEVELOPMENT_PLAN.md` checkbox
  updates scoped and avoid unrelated structural rewrites.
- Serialization: stricter numeric validation for JSON import/export (finite
  numbers + valid ranges); invalid input throws `SceneJsonFormatException`.
- Serialization: enforce non-empty palette lists on JSON import/export and
  validate `background.grid.cellSize` conditionally (`enabled=true` requires
  `> 0`; `enabled=false` accepts any finite value).
- Input: `SceneController` numeric setters now reject invalid values and throw
  `ArgumentError`.
- View: add `SceneView` pointer sample callbacks (`onPointerSampleBefore`,
  `onPointerSampleAfter`) for app-level integrations (snap, grouped drag).
- Core: fix `Transform2D.applyToRect` to preserve translation for degenerate
  rects (zero width/height).
- Fix: `SceneStrokePathCache` now invalidates by `StrokeNode.pointsRevision`,
  so any point mutation (including middle-point edits) rebuilds cached paths.
- Fix: `PathNode.buildLocalPath` no longer rejects valid linear SVG paths
  (degenerate bounds); path nodes no longer disappear/cull incorrectly.
- Fix: `LineNode` hit-testing now accounts for `hitPadding` and `kHitSlop` in
  scene units (touch-friendly, scale-aware).
- Fix: `StrokeNode` hit-testing now accounts for `hitPadding` and `kHitSlop` in
  scene units (touch-friendly, scale-aware).
- Fix: `PathNode` hit-testing includes stroke even when the node is filled
  (selection = fill ∪ stroke).
- Fix: `PathNode` stroke hit-testing no longer double-counts `strokeWidth` when
  inflating `boundsWorld`; selection tolerance uses only `hitPadding + kHitSlop`.
- Fix: invalid/unbuildable `PathNode` SVG data is now non-interactive in
  hit-testing (no coarse AABB phantom hits).
- Fix: hit-testing fallback for non-invertible transforms now preserves
  `hitPadding` + `kHitSlop` for non-`PathNode` shapes.
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
