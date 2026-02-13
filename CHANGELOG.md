## Unreleased

### Breaking

- Runtime snapshot boundaries are now strict:
  - `SceneController(initialSnapshot: ...)` throws `ArgumentError` for malformed snapshots.
  - `replaceScene(...)` throws `ArgumentError` for malformed snapshots.
- Runtime snapshot import no longer auto-inserts a missing background layer.
- JSON codec now rejects non-positive `background.grid.cellSize` regardless of grid enabled state.
- Write-boundary validation is now strict:
  - `addNode(...)` rejects malformed `NodeSpec` values with `ArgumentError`.
  - `patchNode(...)` rejects malformed present `NodePatch` fields with `ArgumentError`.
  - `writeNodeTransformSet(...)`, `writeSelectionTransform(...)`, and `writeSelectionTranslate(...)` reject non-finite `Transform2D`/`Offset`.
  - `opacity` is now strict at write boundary (`[0,1]`) instead of relying on soft normalization.
- Interactive controller event streams (`actions`, `editTextRequests`) are now asynchronous; listeners are no longer invoked in the emitter call stack.

### Changed

- Controller repaint/listener notifications are now deferred to a microtask after commit and coalesced to one notification per event-loop tick, so `write(...)` calls inside listeners no longer trip nested-write guards from the originating transaction.
- Transactional repaint requests are now buffered until successful commit; rollback discards buffered repaint/signals, and successful commit delivers signals before repaint listener notification.
- Spatial-index invalidation now tracks hit candidate bounds (`nodeHitTestCandidateBoundsWorld`) so `hitPadding` updates rebuild candidate lookup correctly.
- Move-mode drag now uses preview translation during pointer move and commits scene translation once on pointer up; pointer cancel no longer mutates document state.
- Added shared internal scene-value validation (`scene_value_validation.dart`) and wired it into runtime snapshot import and JSON encode/decode validation paths.

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
- Strict JSON v2 codec contracts (`schemaVersion = 2`) with canonical validation errors via `SceneJsonFormatException`.
- Bounded render caches and spatial-index optimizations for interactive performance.
- Expanded automated validation with parity, regression, invariant coverage, and import-boundary checks.

### Changed

- Hardened scene invariants: unique node ids, single canonical background layer, explicit constructor/decoder canonicalization.
- Improved input transactional behavior for move/draw/eraser flows, including cancel safety and monotonic event timelines.
- Improved rendering consistency and parity for selection visuals, text line-height semantics, and thin-line snapping behavior.
- Refreshed package documentation (`README`, `API_GUIDE`, `ARCHITECTURE`) for the `1.0.0` release baseline.
