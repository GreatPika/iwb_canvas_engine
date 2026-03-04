# Changelog

All notable changes to `iwb_canvas_engine` are documented here.

## Unreleased

### Changed

- Completed the `src/public/` cleanup wave:
  - removed the deleted mixed-responsibility internal layer from the active
    architecture
  - consolidated stable contract types under `src/contract/`
  - aligned guardrails, package-entrypoint tests, and architecture docs with
    the current module model

## 5.0.1 (2026-03-03)

### Changed

- Improved public API dartdoc coverage for key exported types:
  - documented `ActionCommitted` and `EditTextRequested`
  - documented `ActionType`, `CanvasMode`, and `DrawTool` values
  - documented `SceneDataException`, `SceneDataErrorCode`, and
    `ClearSceneResult`
  - documented the remaining public `SceneWriteTxn` methods that previously had
    no API comments
- Release artifacts now advertise `5.0.1` as the current package version.

## 5.0.0 (2026-02-18)

### Breaking

- JSON read and write now support only `schemaVersion = 5`.
- Public write APIs use `layerId` for content-layer addressing.
- Serialized content layers require stable `layers[].id`.

### Changed

- Refreshed repository documentation for release readiness:
  - `README.md` is now a concise package landing page
  - `API_GUIDE.md` is the single integration reference
  - `ARCHITECTURE.md` is focused on module boundaries and invariants
  - `DEVELOPMENT_PLAN.md` is reduced to active-plan status only
  - `AGENTS.md` now includes a clear document map and validation policy
  - example docs were aligned with current demo capabilities and platform
    template guidance
- Release artifacts, docs, and public API wording were aligned to the `5.x`
  line.
- Command signals became strictly state-change based rather than
  invocation-based.
- Snapshot and JSON validation became stricter and more explicit.
- Runtime now exposes clearer clear-scene semantics and better transaction
  contracts.

## 4.0.0 (2026-02-16)

### Breaking

- The typed layer model replaced the legacy `LayerSnapshot(isBackground: ...)`
  shape.
- Public interactive input moved to `CanvasPointerInput` and
  `handleDoubleTap(...)`.
- Legacy public interactive and view types were removed in favor of
  `SceneControllerInteractive` / `SceneViewInteractive` and their aliases.
- `SceneWriteTxn` selection mutators now expose explicit changed/no-op semantics.

### Changed

- Listener notifications and interactive streams were formalized as asynchronous
  boundaries.
- Runtime fail-fast behavior after `dispose()` was expanded and documented.
- Render caches became more consistent and more aggressively bounded.
- The public export surface was narrowed to the supported API only.
- `SceneBuilder` was added as a canonical import gateway.

## 3.0.0 (2026-02-13)

### Breaking

- Runtime snapshot boundaries became strict and now throw `SceneDataException`
  for malformed snapshots.
- Public write APIs now reject malformed `NodeSpec`, `NodePatch`, and invalid
  transform values.
- Text write APIs no longer accept writable `size`.
- Interactive streams became asynchronous.

### Changed

- Transactional repaint and signal delivery were deferred and coalesced.
- Copy-on-write transactions and indexed lookup improved write-path cost.
- Spatial index and hit-testing guardrails were added for large scenes.
- Text bounds became engine-derived at runtime.

## 2.0.1 (2026-02-10)

### Breaking

- `SceneWriteTxn` stopped exposing internal node-id bookkeeping helpers.
- `ActionCommitted` payloads and node ids became immutable snapshots.

### Changed

- Commit finalization now completes before signal delivery.
- Selection normalization and delete behavior were hardened.
- Runtime commit invariant assertions were expanded.

## 2.0.0 (2026-02-10)

### Breaking

- `iwb_canvas_engine.dart` became the single supported public entrypoint.
- Mutable scene internals were removed from the public surface.
- Public write callbacks switched to `SceneWriteTxn`.

### Added

- Stable public runtime aliases: `SceneController` and `SceneView`.
- `SceneRenderState` as the supported view/painter read contract.
- Guardrails around the single-entrypoint and safe transaction model.

### Changed

- Commit flow was split into clearer no-op, signals-only, and full state-change
  branches.
- Interactive controller internals were refactored away from raw writer misuse.

## 1.0.0 (2026-02-10)

### Breaking

- The initial immutable public API line was finalized and legacy mutable entry
  points were removed.

### Added

- Stable snapshot/spec/patch contracts.
- Strict JSON codec contracts through `SceneDataException`.
- Automated validation for invariants, import boundaries, and rendering parity.

### Changed

- Package documentation and release artifacts were aligned around the initial
  stable release.
