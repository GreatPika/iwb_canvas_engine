## Unreleased

### Breaking

- `SceneJsonFormatException` is removed from public API; scene import/serialization boundaries now throw `SceneDataException` with `SceneDataErrorCode`.
- Typed layer model replaces `LayerSnapshot(isBackground: ...)`:
  - `SceneSnapshot.backgroundLayer: BackgroundLayerSnapshot?`
  - `SceneSnapshot.layers: List<ContentLayerSnapshot>` (content-only)
  - `layerIndex` in write APIs addresses content layers only.
- JSON codec now supports only `schemaVersion = 4`; schema `3` and legacy schema `2` are rejected.
- Interactive input API is reshaped:
  - removed public `handlePointer(PointerSample ...)` / `handlePointerSignal(PointerSignal ...)`,
  - added `handlePointer(CanvasPointerInput)` / `handleDoubleTap(...)`,
  - internal `PointerSample`/`PointerSignal` are no longer required for public usage.
- `SceneViewInteractiveV2` no longer exposes `geometryCache` in its public constructor; geometry cache ownership is fully internal to keep non-exported render-cache types out of public signatures.

### Changed

- Internal `RenderGeometryCache` now uses bounded LRU eviction (`maxEntries = 512`) to prevent unbounded geometry-cache growth during long node churn (create/delete cycles).
- Internal `RenderGeometryCache` stroke validity key now excludes point-list object identity and relies on stable scalar/revision geometry inputs (`pointsRevision`, transform, thickness), restoring cache hits across logically unchanged snapshots.
- `iwb_canvas_engine.dart` export surface is narrowed: removed public exports of `defaults.dart`, `geometry.dart`, and render cache/resolver types from `scene_painter.dart`; pointer input export now exposes `PointerInputSettings` and new public `CanvasPointerInput` contracts.
- Added public `SceneBuilder` as a unified immutable import gateway for both JSON maps and `SceneSnapshot`.
- `SceneStrokePathCacheV2`, `SceneTextLayoutCacheV2`, and `ScenePathMetricsCacheV2` now throw `ArgumentError` for `maxEntries <= 0` in all build modes (not only debug).
- `ScenePainterV2` now reuses per-node geometry via injected `RenderGeometryCache` (`NodeId` + validity key), removing duplicate path parsing/bounds calculations across culling, selection, and path drawing.
- `SceneViewV2` and `SceneViewInteractiveV2` now own render-cache lifecycle consistently (including `RenderGeometryCache`) and clear all render caches on controller epoch changes; only internal `SceneViewV2` keeps optional `geometryCache` injection for explicit ownership/customization.
- Added immutable `instanceRevision` node identity across runtime/snapshot/JSON boundaries; render caches now isolate entries by `(nodeId, instanceRevision)` to prevent stale cache hits after id reuse.
- Local bounds policy for `Rect`/`Path` is now unified between core nodes and render cache: stroke inflation applies only for enabled stroke and cache validity keys use effective stroke width, preventing edge culling regressions when stroke is disabled.
- Bounds-based selection frame for `Image`/`Text`/`Rect` now uses the same render `worldBounds` source as culling, and hit candidate bounds parity is covered by dedicated regression tests.
- `SceneView` now keeps render cache ownership internal while exposing an optional `imageResolver` callback (`ui.Image? Function(String imageId)`) so public image nodes remain renderable without exporting internal resolver/cache types.
- `CanvasPointerInput.timestampMs` is now optional; when omitted, controller assigns a monotonic timestamp internally.
- `SceneSpatialIndex` now exposes explicit validity state (`isValid`) and degrades to safe linear candidate scan when indexing cannot be maintained (including out-of-range/extreme geometry), preventing hard failures in query paths.
- `V2SpatialIndexSlice` now keeps invalid index instances in fallback mode instead of forcing rebuild loops after failed incremental updates.
- `SceneControllerV2.selectedNodeIds` now reuses a cached `UnmodifiableSetView` and refreshes it only when selection actually changes, removing per-read allocation on hot getter paths.
- `clearScene`/`writeClearSceneKeepBackground` now keep (or create) dedicated `backgroundLayer` and clear all content layers.
- Snapshot/JSON import boundaries now canonicalize missing `backgroundLayer` to a dedicated empty background layer; JSON encode always writes canonical `backgroundLayer`.
- `V2SignalsSlice` now buffers pending signals in-place and clears on take/discard, removing per-append list copying in large signal batches.
- `PathNode` hit-testing now falls back to candidate bounds when node transform is non-invertible, keeping singular transformed paths selectable.

## 3.0.0 (2026-02-13)

### Breaking

- Runtime snapshot boundaries are now strict:
  - `SceneController(initialSnapshot: ...)` throws `SceneDataException` for malformed snapshots.
  - `replaceScene(...)` throws `SceneDataException` for malformed snapshots.
- Runtime snapshot import no longer auto-inserts a missing background layer.
- JSON codec now rejects non-positive `background.grid.cellSize` regardless of grid enabled state.
- Write-boundary validation is now strict:
  - `addNode(...)` rejects malformed `NodeSpec` values with `ArgumentError`.
  - `patchNode(...)` rejects malformed present `NodePatch` fields with `ArgumentError`.
  - `writeNodeTransformSet(...)`, `writeSelectionTransform(...)`, and `writeSelectionTranslate(...)` reject non-finite `Transform2D`/`Offset`.
  - `opacity` is now strict at write boundary (`[0,1]`) instead of relying on soft normalization.
- Text node write API is now size-derived:
  - `TextNodeSpec` no longer accepts `size`.
  - `TextNodePatch` no longer accepts `size`.
- Interactive controller event streams (`actions`, `editTextRequests`) are now asynchronous; listeners are no longer invoked in the emitter call stack.

### Changed

- Controller repaint/listener notifications are now deferred to a microtask after commit and coalesced to one notification per event-loop tick, so `write(...)` calls inside listeners no longer trip nested-write guards from the originating transaction.
- Transactional repaint requests are now buffered until successful commit; rollback discards buffered repaint/signals, and successful commit delivers signals before repaint listener notification.
- Spatial-index invalidation now tracks hit candidate bounds (`nodeHitTestCandidateBoundsWorld`) so `hitPadding` updates rebuild candidate lookup correctly.
- Spatial index now uses a dual-path layout (`grid cells` + `large candidates`) with `kMaxCellsPerNode = 1024`, so a single huge node can no longer explode per-cell indexing cost.
- Spatial index construction is fixed to the internal index cell size and no longer depends on background visual grid settings.
- Spatial index commits are now incremental: local hit-geometry changes update per-node cell coverage (`added/removed/hitGeometryChangedIds`) without full-index rebuild; rebuild is kept as a fallback path when incremental apply is not possible.
- Interactive pen/highlighter commits now enforce `kMaxStrokePointsPerNode = 20_000` with deterministic index-uniform downsampling that preserves stroke endpoints.
- Path-stroke precise hit-testing now enforces `kMaxStrokeHitSamplesPerMetric = 2_048` by increasing sampling step on very long path metrics.
- Spatial index query now enforces `kMaxQueryCells = 50_000`; oversized queries switch to bounded all-candidate scan with exact intersection filtering instead of unbounded cell iteration.
- Transaction write path now uses scene/layer/node copy-on-write: first mutation shallow-clones scene metadata and clones only touched layers/nodes, while no-op node patches skip COW cloning.
- Commit state-change path now keeps node-id index incrementally: local non-structural commits reuse existing `allNodeIds`, structural commits materialize ids lazily once, and `nodeIdSeed` is treated as a monotonic generator (lower-bounded by committed scene ids).
- Commit/store now maintain `nodeLocator` (`NodeId -> layer/node position`) and writer hot paths use locator-based O(1) lookup instead of linear node-id scans.
- Stroke render-path cache now validates freshness by `(node.id, pointsRevision)` in O(1), avoiding per-frame point-list hashing/traversal in cache checks.
- Move-mode drag now uses preview translation during pointer move and commits scene translation once on pointer up; pointer cancel no longer mutates document state.
- Added shared internal scene-value validation (`scene_value_validation.dart`) and wired it into runtime snapshot import and JSON encode/decode validation paths.
- Selection transaction hot paths now keep a hash-based mutable working set in place (`toggle/clear/erase/delete/replace`) instead of rebuilding `Set` instances on each step.
- Text node bounds are now derived in-engine from text layout inputs; snapshot/JSON import recomputes text size on load so stale serialized values do not stay authoritative at runtime.
- Added load-profile benchmark tooling (`dart run tool/bench/run_load_profiles.dart --profile=<smoke|full>`) with structured JSON output and dedicated benchmark cases for large node/stroke scenes and worst-case spatial/path scenarios.
- CI now runs smoke load profiles and uploads benchmark artifacts; a new nightly workflow runs full load profiles and extended randomized transaction fuzzing.
- Randomized transaction fuzz tests now support environment-based scaling (`IWB_FUZZ_SEEDS`, `IWB_FUZZ_STEPS`, `IWB_FUZZ_BASE_SEED`) and explicitly assert finite numeric state after each step.

## 2.0.1 (2026-02-10)

### Breaking

- `SceneWriteTxn` no longer exposes node-id bookkeeping methods (`writeNewNodeId`, `writeContainsNodeId`, `writeRegisterNodeId`, `writeUnregisterNodeId`, `writeRebuildNodeIdIndex`).
- `ActionCommitted` and internal committed signal payloads are now immutable snapshots (mutating `nodeIds`/`payload` throws).

### Changed

- Commit pipeline now finalizes store state first and only then emits committed signals.
- Controller commit now derives `allNodeIds` and `nodeIdSeed` from the committed scene as the single source of truth.
- `SceneWriter.writeNodeErase` now respects deletable-layer policy consistently with selection delete flow.
- `SceneWriter.writeGridCellSize` and `SceneWriter.writeCameraOffset` now reject non-finite/invalid inputs at write boundary.
- Selection normalization now preserves explicit non-selectable ids, so `selectAll(onlySelectable: false)` remains stable after commit.
- Commit state-change path no longer performs a redundant second deep clone of scene data; mutating transactions now clone once (clone-on-first-mutation).
- Added runtime commit invariant assertions for store consistency in debug/test execution.

## 2.0.0 (2026-02-10)

### Breaking

- Removed `lib/advanced.dart`; `iwb_canvas_engine.dart` is now the single public entrypoint.
- `iwb_canvas_engine.dart` no longer exports mutable core model files (`src/core/scene.dart`, `src/core/nodes.dart`).
- `SceneControllerInteractiveV2` removed legacy mutable API:
  - removed constructor parameter `scene`,
  - removed getters `core` and `scene`,
  - `addNode` now accepts only `NodeSpec`.
- Public transactional write callback now uses `SceneWriteTxn` (safe contract without raw `scene`, `writeFindNode`, or `writeMark*` APIs).

### Added

- New public `SceneWriteTxn` contract (`lib/src/public/scene_write_txn.dart`).
- New public `SceneRenderState` contract (`lib/src/public/scene_render_state.dart`) for painter/view integration.
- `SceneControllerV2.requestRepaint()` for explicit repaint without transactional mutation.
- Commit-path tests for no-op, signals-only, and selection-policy patch normalization.
- Guardrails for single entrypoint and safe transaction API surface.

### Changed

- `TxnContext` now uses lazy scene clone-on-first-mutation.
- Commit pipeline supports explicit branches:
  - no-op: no commit/revision/repaint,
  - signals-only: commit revision + signal flush without repaint,
  - state-change/document-replace: full commit path.
- Selection normalization now handles node patches that affect selection policy for selected nodes.
- Interactive controller refactored to avoid read-only transaction misuse and raw writer mutations in move rollback.

## 1.0.0 (2026-02-10)

### Breaking

- Finalized the v2 public API in `iwb_canvas_engine.dart`/`advanced.dart` around immutable snapshots, specs, and patch semantics.
- Removed the legacy mutable public surface from package entrypoints.

### Added

- Stable interactive runtime aliases: `SceneController` and `SceneView` over v2 implementations.
- Strict JSON v2 codec contracts (`schemaVersion = 2`) with canonical validation errors via `SceneDataException`.
- Bounded render caches and spatial-index optimizations for interactive performance.
- Expanded automated validation with parity, regression, invariant coverage, and import-boundary checks.

### Changed

- Hardened scene invariants: unique node ids, single canonical background layer, explicit constructor/decoder canonicalization.
- Improved input transactional behavior for move/draw/eraser flows, including cancel safety and monotonic event timelines.
- Improved rendering consistency and parity for selection visuals, text line-height semantics, and thin-line snapping behavior.
- Refreshed package documentation (`README`, `API_GUIDE`, `ARCHITECTURE`) for the `1.0.0` release baseline.
