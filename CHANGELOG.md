# Changelog

All notable changes to `iwb_canvas_engine` are documented here.

## Unreleased

### Breaking

- `SceneDataErrorCode.multipleBackgroundLayers` was removed as an unreachable
  public contract branch. Integrations must stop matching this enum value and
  treat background-layer canonicalization as a single-layer boundary rule.
- Duplicate content-layer ids now use the dedicated
  `SceneDataErrorCode.duplicateLayerId` contract instead of
  `SceneDataErrorCode.invalidValue`.
- `SceneDataException(...)` is no longer `const`. The constructor now
  sanitizes `source` eagerly and may replace structured values with immutable
  snapshots or preview payloads.
- Public snapshot/node constructors are no longer `const`; they now validate
  boundary ids and numeric values eagerly.
- Public `NodeSpec`, `NodePatch`, and `CommonNodePatch` constructors are no
  longer `const`; they now validate write-boundary values eagerly.
- Exported validated boundary value types no longer expose unsupported
  `validated(...)` fast-path constructors. Supported factory entrypoints are
  `parse(...)`, `of(...)`, and `fromJson(...)`.
- Public generated-id helpers were removed from the package surface.
  Integrations must stop depending on `generate*`, `isGenerated*`, and
  `tryParseGenerated*` helpers or on the legacy `node-<n>` / `layer-<n>`
  runtime format as a public contract.

### Changed

- `SceneControllerInteractive.handlePointer(...)` now owns canonical terminal
  pointer normalization for both direct and `SceneView`-routed input:
  non-finite `down`/`move` are still dropped, while non-finite terminal
  `up`/`cancel` preserve their original phase only when the same `pointerId`
  already has a cached finite position; otherwise they stay a no-op. Explicit
  `dragStartSlop` now uses the same finite `>= 0` validation rule in both the
  constructor and `setDragStartSlop(...)`.
- `SceneViewInteractive` now owns raw Flutter pointer routing through the
  dedicated `SceneViewPointerRouter`, so routed `pointerId` values are created
  only on `down`, stray non-down host events are dropped, minimum free slot
  reuse stays deterministic, and pending pointer-setting resets wait for full
  router idle instead of only the tracked pointer.
- `PointerInputSettings` now uses value semantics, and `SceneViewInteractive`
  keeps explicit applied/pending tracker settings with last-write-wins
  apply-on-idle behavior for live raw pointers.
- Render-cache invalidation is now explicitly owned by
  `SceneRenderCaches.clearAll()` on controller epoch/document boundaries;
  render cache keys stay scoped to local revision/layout inputs only, while
  text layout cache keys still include paint color because cached
  `TextPainter` instances retain render style.
- Unified scene-level validation ownership under `ScenePolicy` so import,
  decode, and runtime scene canonicalization now report the same deterministic
  `SceneDataException.code` / `path` / `details` contract for duplicate node
  ids, duplicate content-layer ids, scene-wide count limits, and scene-level
  range violations; `message` is now documented as derived user-facing text.
- `decodeSceneFromJson(...)` now routes transport-level parse/root/oversize
  failures through serialization-local codec guards and rejects raw JSON
  strings longer than `33554432` characters before `jsonDecode`.
- `SceneBuilder.buildFromJson(...)` now normalizes parsed maps behind a
  model-local guard so builder/decode parity stays anchored on stable
  `SceneDataException.code` / `path` / `details` without adding a
  `model -> serialization` dependency.
- `scene_codec.dart` now adopts the unified boundary contract across
  `decodeSceneFromJson(...)`, `decodeScene(...)`, `encodeScene(...)`, and
  `encodeSceneDocument(...)`, keeping builder/decode/encode parity anchored on
  stable `SceneDataException.code` / `path` / `details`.
- Clarified step `5.1` `backgroundLayer` policy: mutable runtime `Scene`
  keeps `backgroundLayer` nullable, while snapshot/JSON boundaries continue to
  canonicalize it to a dedicated single layer.
- Runtime id allocation is now fully store-owned: controller bootstrap starts
  a fresh `IdGeneratorState`, commit/adopt/replace preserve allocator state
  verbatim, and future generated ids are no longer reconstructed from scene
  scans or legacy generated-id parsing.
- Runtime revision allocation is now store-owned and composite with
  `controllerEpoch`: snapshot/import preserves valid positive revisions,
  replace/adopt no longer reseed from `max(scene)`, and revision overflow now
  fails through `epoch bump + revision reset` instead of silent saturation or
  wraparound.
- Clarified the writer/controller contract for step `4.4`: draw command
  entrypoints return committed `NodeId` values, and
  `writeSelectionTransform(...)` is documented with pre-multiply semantics
  (`nextTransform = delta.multiply(existingTransform)`).
- Consolidated `NodeId`/`LayerId` ownership under `src/contract/ids.dart` and
  removed duplicate local `NodeId` declarations from core internals.
- Tightened public-entrypoint contract enforcement so tool tests derive the
  canonical export scaffold from `lib/iwb_canvas_engine.dart` while keeping an
  explicit canonical export-owner manifest in test support.
- Added `tool/check_public_api_surface.dart` with
  `tool/goldens/public_api_symbols.txt` to enforce a stable exported symbol set
  from `lib/iwb_canvas_engine.dart`.
- Migrated `tool/check_guardrails.dart` and
  `tool/check_import_boundaries.dart` to `package:analyzer` AST parsing to
  harden multiline `import`/`export`/`part` and signature guardrails.
- Expanded docs to improve `PathFillRule` discoverability in public API
  references.
- Documented that the `contract/` layer is intentionally Flutter-oriented
  (`dart:ui` + `Listenable`) and is not a pure Dart compatibility boundary.
- `writeNodeInsert(...)` / `addNode(...)` now throw `ArgumentError` (instead of
  `StateError`) when a caller provides a duplicate explicit `NodeSpec.id`.
- Clarified and enforced text snapshot canonicalization: import now treats
  `TextNodeSnapshot.size` as derived/non-authoritative metadata and always
  recomputes canonical bounds from layout inputs.
- Moved public `SceneSnapshot`/`NodeSnapshot` constructor validation onto the
  snapshot boundary while keeping internal decode/runtime producers on fast
  paths for already validated data.
- Hardened JSON decode guardrails against oversized string and palette payloads
  by enforcing max lengths for layer/node/image/font ids and text, plus max
  palette item counts.
- Added a public `contract/validated/**` boundary-value layer with typed
  parsing/generation for ids, image ids, revisions, finite offsets, bounded
  text/font values, SVG path payloads, and bounded numeric semantics.
- Runtime generated-id ownership now lives under `src/core/id_generator.dart`;
  public boundary code keeps only explicit id validation helpers while runtime
  generation remains an internal concern.
- `SceneDataException.source` now snapshots small structured values into
  bounded immutable payloads and sanitizes oversized strings, collections,
  errors, and arbitrary objects into deterministic previews instead of
  retaining raw live input.
- Safe-int enforcement now rejects unsafe JSON integer literals and generated-id
  recognition no longer accepts overlong, overflow, or non-canonical
  leading-zero legacy ids that factory generation would never emit.
- JSON decode/build boundaries now route id, revision, text, font-family,
  SVG-path, opacity, finite-offset, and bounded numeric fields through the same
  exported validated boundary helpers used by runtime-facing callers.
- `imageId` now uses the same exported validated boundary owner across
  decode/build, snapshot validation, runtime scene validation, `NodeSpec`, and
  `NodePatch`.
- Public `NodePatch` now validates only present fields at construction time,
  and stroke point patches defensively copy once at the boundary before runtime
  no-op checks.

## 5.1.0 (2026-03-04)

### Changed

- Completed the `src/public/` cleanup wave:
  - removed the deleted mixed-responsibility internal layer from the active
    architecture
  - consolidated stable contract types under `src/contract/`
  - aligned guardrails, package-entrypoint tests, and architecture docs with
    the current module model
- Release artifacts now advertise `5.1.0` as the current package version.

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
