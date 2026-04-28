# Changelog

All notable user-facing changes to `iwb_canvas_engine` are documented here.

This file tracks the repository main branch. `Unreleased` may describe checked-
in changes that have not yet been published to pub.dev.

## Unreleased

### Breaking

- Removed internal diagnostic/helper scene-data types from the public barrel.
  The supported error surface is `SceneDataException` and
  `SceneDataErrorCode`.
- Tightened public boundary validation. Public scene metadata, snapshots,
  specs, and patches now validate eagerly, and `SceneSnapshot` rejects
  duplicate ids plus scene-wide structural overflow at the boundary.
- Removed legacy JSON schema `6`. The current mainline reads and writes only
  `schemaVersion = 7`. Text payloads must include `textDirection` and must not
  contain legacy stored text `size` metadata.
- Removed or narrowed legacy public surfaces that no longer match the supported
  contract, including `SceneControllerInteraction.snapshot`, public
  generated-id helpers, and `SceneWriteTxn.writeSignalEnqueue(...)`.
- Stopped exposing public stroke `pointsRevision`. Stroke geometry revision is
  runtime-only metadata.
- Replaced the old named-parameter `MoveCommitDeltaResolver` surface with
  `MoveCommitDeltaRequest`. Move-commit callbacks now receive immutable
  `movedNodes`, and exported callback typedefs may not expose raw
  `List` / `Map` / `Set` types anywhere inside callback parameter shapes.
- Made `SceneController` final. Integrations must compose the concrete runtime
  owner instead of subclassing it or overriding committed-read getters.

### Added

- Added `SceneControllerInteraction.pendingLineColor` and
  `pendingLineThickness` so host UI can mirror the style of a pending two-tap
  line commit.
- Added public validated boundary-value types for ids, offsets, bounded
  doubles, opacity, SVG path data, text content, font families, and instance
  revisions.

### Changed

- Unified `SceneBuilder`, `decodeScene*`, `encodeScene*`, and typed snapshot
  import around the same stable `SceneDataException.code`, `path`, and
  `details` contract.
- Canonicalized aggregate boundary admission so supported nested snapshot and
  patch values are rebuilt eagerly as exact public contract objects, while
  unsupported boundary subtypes now fail at admission instead of later helper
  seams.
- Split `SceneView` repaint responsibilities into scene and overlay channels so
  overlay-only interactive state does not repaint the base scene.
- Finalized transaction state before commit planning. Inside `write(...)`,
  `SceneWriteTxn.snapshot` and `selectedNodeIds` now reflect the post-mutation
  state.
- Tightened `SceneWriteTxn` lifetime semantics so new `snapshot` and
  `selectedNodeIds` reads throw after callback close, while values captured
  during the callback remain detached immutable snapshots.
- Switched several runtime numeric boundaries, including node opacity and grid
  cell size, to reject invalid writes immediately instead of repairing them
  later.
- Hardened text import/decode so oversized derived layout bounds are rejected
  again at the public boundary.
- Canonicalized nullable patch null writes so `PatchField<T?>.value(null)` now
  resolves to the same explicit-null state as `PatchField.nullValue()`.
- Moved runtime content-layer topology ownership fully into the model seam.
  Stable node locators now track `contentLayerId`, while transaction and
  committed state carry a derived `layerIndexById` companion map.
- Reworked repository-owned performance proof architecture. GitHub CI now uses
  deterministic owner-level proof plus workflow-contract checks, while
  diagnostic load profiles now split `smoke` product scenarios from `full`
  stress/nightly coverage and expose explicit cache-churn, selection
  compositing, grid-iteration, and eraser commit probes. Selection diagnostic
  reports remain ad hoc and no longer ship with a checked-in regression
  baseline.

### Fixed

- Fixed direct model-level scene insertion so stale transaction locator or
  layer-index maps can no longer admit duplicate ids or undercount the scene
  node budget.
- Fixed selected line, stroke, dot, and open-path rendering so selection halos
  no longer repaint base vector content, preserving alpha, scene draw order,
  and stroke-path cache work.
- Fixed draw-mode terminal cleanup so failing stroke, dragged-line, eraser, or
  draw action-emission paths clear gesture, preview, pending-line, and
  tool-local buffer state before rethrowing.
- Fixed validated snapshot fast paths so raw snapshot backing carriers can no
  longer be exposed as public `SceneSnapshot` or `NodeSnapshot` objects without
  crossing the model-owned validation and projection path.
- Fixed public `NodePatch` constructors so explicit null writes to
  non-nullable patch fields now throw `ArgumentError` at construction time
  instead of reaching transactional patch application.
- Fixed unsupported typed `SceneSnapshot` subtype diagnostics so
  `SceneBuilder.buildFromSnapshot(...)`, `encodeScene(...)`, and
  `encodeSceneToJson(...)` now report the same `SceneDataException` contract
  instead of leaking raw `StateError` or JSON transport errors.
- Fixed paint-candidate admission so committed selected supplements reuse
  committed spatial paint bounds and snapshot-local fallback reuses bounded
  admission bounds, avoiding repeated text layout and SVG path parsing before
  render resolution.
- Fixed main-scene paint hot paths so repeated over-capacity frames keep
  scan-resistant render-cache reuse, selection halo compositing records only
  bounded `saveLayer` regions, and dense-grid diagnostics report bounded work.
- Fixed paint over-admission by separating paint admission from hit-test
  admission. Hit-testing still honors hit padding, while paint admission now
  uses paint bounds only.
- Fixed benchmark diff verdicts so absolute budgets fail even when a positive
  baseline is already over budget and `current == baseline`.
- Fixed JSON import/build line and stroke range diagnostics so alias-bearing
  field paths stay on `localA`, `localB`, and `localPoints`, while typed
  snapshot import surfaces keep canonical `start`, `end`, and `points`.
- Fixed main-scene move-preview rendering so one captured frame keeps a frozen
  preview snapshot across paint admission and late node resolution, even when
  app `imageResolver` callbacks mutate controller state mid-paint.
- Fixed move-mode listener/repaint noise so selected-node taps without drag no
  longer emit scene-change notifications or repaint churn.
- Fixed frame rendering to resolve candidates against the active frame snapshot
  rather than mixing committed and frame-local data.
- Fixed `SceneView` detach/runtime-swap behavior so controller-owned resources
  are released deterministically and the last good runtime remains active until
  a replacement succeeds.
- Fixed controller-owned pointer-session lifecycle so successful same-runtime
  epoch breaks clear pending tap history and still-mounted view hosts ignore
  late routed callbacks after controller disposal.
- Fixed `SceneViewInteractive` terminal pointer cleanup so raw pointer slots
  and deferred pointer settings are released, and tap tracking is cleared,
  even when terminal interactive dispatch throws.
- Fixed same-write and committed node resolution after inserted content layers.
  Ensuring a layer before later delete/patch/selection or committed snapshot
  resolution no longer leaves stale positional locators behind.

## 5.1.0 (2026-03-04)

### Changed

- Consolidated stable public contract types under `src/contract/` and aligned
  guardrails and documentation with that structure.
- Updated release artifacts and repository docs for the `5.1.0` line.

## 5.0.1 (2026-03-03)

### Changed

- Expanded dartdoc coverage for exported runtime, transaction, and error types.

## 5.0.0 (2026-02-18)

### Breaking

- Moved JSON read/write support to schema version `5` only for that release.
- Switched public content-layer addressing to `layerId`.
- Required stable `layers[].id` values in serialized content layers.

### Changed

- Realigned repository documentation around the single public entrypoint and
  the `5.x` integration model.
- Tightened snapshot/JSON validation and clarified signal semantics.

## 4.0.0 (2026-02-16)

### Breaking

- Replaced the legacy `LayerSnapshot(isBackground: ...)` model with typed
  `backgroundLayer` plus content `layers`.
- Moved public interactive input to `CanvasPointerInput` and
  `handleDoubleTap(...)`.
- Removed legacy public interactive/view types in favor of `SceneController`
  and `SceneView`.

### Changed

- Formalized listener delivery and interactive streams as asynchronous
  boundaries.
- Expanded fail-fast runtime behavior after `dispose()`.
- Added `SceneBuilder` as the canonical non-controller import gateway.

## 3.0.0 (2026-02-13)

### Breaking

- Made snapshot/spec/patch boundaries strict and invalid data now fails with
  `SceneDataException` or `ArgumentError` at supported public boundaries.
- Removed writable text `size` from public write flows.

### Changed

- Deferred and coalesced repaint/signal delivery.
- Strengthened spatial-index and hit-test guardrails for larger scenes.
- Made text bounds engine-derived at runtime.

## 2.0.1 (2026-02-10)

### Breaking

- Removed internal node-id bookkeeping helpers from `SceneWriteTxn`.
- Made committed action payloads and node-id collections immutable snapshots.

### Changed

- Finalized commit state before signal delivery.
- Hardened selection normalization and delete behavior.

## 2.0.0 (2026-02-10)

### Breaking

- Made `iwb_canvas_engine.dart` the single supported public entrypoint.
- Switched public write callbacks to `SceneWriteTxn`.
- Removed mutable scene internals from the supported package surface.

### Added

- Added `SceneController` as the stable public runtime root.
- Added `SceneView` as the stable public interactive widget.
- Added `SceneRenderState` as the supported read-only render contract.

### Changed

- Split commit flow into clearer no-op, signals-only, and full state-change
  paths.

## 1.0.0 (2026-02-10)

### Breaking

- Finalized the initial immutable public API line and removed legacy mutable
  entry points.

### Added

- Added stable snapshot/spec/patch contracts.
- Added strict JSON codec contracts through `SceneDataException`.
- Added automated validation around invariants, boundaries, and rendering
  parity.
