# Changelog

All notable changes to `iwb_canvas_engine` are documented here.

## Unreleased

- Fixed render-path over-admission by separating hit-test and paint spatial
  admission. Hit-testing still uses hit-padding plus `kHitSlop`, while paint
  admission now uses paint bounds only, culls before render-geometry or text
  layout resolution, includes committed `backgroundLayer` nodes on the shared
  paint spatial path, and preserves original background/content order even
  when selected-node supplements are admitted only through the widened
  visibility rect.
- Fixed move-mode listener/repaint noise: selected-node move taps without drag no longer trigger scene repaint.
  They also no longer trigger public scene-change listener activity, while
  non-zero move previews still repaint and notify through the scene channel.
- Prepared replace-scene payloads are now sealed as controller-private
  implementation detail. Public and interactive callers still use only
  `replaceScene(SceneSnapshot snapshot)`, preflight validation/import happens
  exactly once before any external-mutation interrupt, and guardrails now
  reject reintroducing prepared replace-scene payload APIs above
  controller-private code.
- Committed read-side runtime graph leaks are now sealed. Live runtime
  `Scene` / `SceneNode` objects stay write-private, controller and interactive
  committed reads resolve immutable snapshot-backed node data only, and
  guardrails now reject reintroducing runtime-node leaks across that boundary.
- Render-frame snapshot resolution is now frame-authoritative. If
  `SceneViewRenderState.snapshot` diverges from the committed controller
  snapshot, ordinary paint candidates and selected-node supplements resolve
  against the active frame snapshot instead of mixing committed-only nodes
  into that frame. `ScenePainter` now captures one atomic frame read before
  shell paint so background paint, candidate enumeration, and preview
  geometry share one authority, while the controller-owned viewport-first
  spatial-index path remains the normal fast path when both snapshots are
  identical.
- Runtime scene validity ownership now closes before commit: content-layer and
  total-node budget overflows fail at model mutation owners, constrained
  runtime node fields validate eagerly on owner writes, and the controller
  commit gate revalidates the changed runtime scene surface before store apply
  while `debug`/`profile` keep the full invariant sweep.
- Breaking: The package entrypoint now exposes only the stable public scene
  error contract `SceneDataException` and `SceneDataErrorCode`. Internal
  diagnostic descriptor / validation adapter types remain available only under
  `src/**` and are no longer part of the supported package import surface.
- Scene boundary diagnostics are now aligned across parsed JSON import,
  typed snapshot import, and public builder entrypoints for palette item
  limits, stroke point limits, optional image `naturalSize`, and parsed
  color/enum literals. These failures now keep their stable meaning in
  `SceneDataException.code` / `path` / `details`, while `message` remains a
  derived user-facing summary.
- `SceneControllerInteraction`, `SceneControllerSelection`, and
  `SceneControllerScene` now stay controller-owned public capability contracts
  only. Public callers obtain them from `SceneController`, while direct public
  construction is no longer part of the supported surface.
- `tool/check_guardrails.dart` now enforces public signature hermeticity for
  `lib/iwb_canvas_engine.dart`, rejecting exported signatures that leak
  `internal/**` or non-exported helper types.
- Repository verification now uses the shell-first
  `tool/run_verification_preset.dart` contract with registry-backed drift
  checks in `tool/check_verification_contract.dart`, `VERIFICATION.md` is no
  longer a second verification source of truth, and the canonical changed-file
  input now supports compact `--changed-paths-file=<path>` invocation.
- Added `tool/run_temp_pkg_test.dart` as the canonical runtime/listener repro
  workflow. The tool assembles a temporary Flutter package with a path
  dependency on the current repository, supports wrapped snippet input from a
  file or stdin, and runs the repro in the correct package context without
  manual `/tmp` setup.
- `tool/check_coverage.dart` machine mode now returns one flat actionable
  `gaps` collection with declaration-clustered missed lines and branches,
  compact source snippets, candidate test files, preferred verification step
  ids, and explicit `--changed-only` git filtering on top of the existing
  `--json` and `--uncovered-branches` workflow.
- `SceneView` render-state now uses split repaint channels: the main painter
  listens to scene repaint through `SceneViewRenderState`, the interactive
  overlay listens to `overlayRepaintListenable`, and marquee selection
  rectangles moved out of `ScenePainter` into the overlay painter so
  overlay-only interactive state no longer repaints the base scene.
- Render read-side text layout now uses one canonical resolved payload per
  text candidate. `SceneTextLayoutCache` stores resolved text layout instead of
  bare `TextPainter` instances, `ScenePainterFrameOwner` resolves that payload
  once and hands it to both geometry sizing and text paint, and
  `ScenePainterNodeRenderer` no longer re-enters text layout ownership during
  paint.
- `ScenePainter` now consumes controller-owned ordered viewport paint
  candidates from the internal render-state path before frame-local geometry
  resolution. Cold paints no longer resolve off-viewport content nodes, while
  `backgroundLayer` order and selected move-preview visibility stay intact.
- `ScenePainterFrameOwner` now owns one render-local
  `ScenePainterVisibilityBudget` per frame without widening ordinary candidate
  enumeration. Controller paint-candidate queries stay viewport-first, while
  the budgeted visibility rect is used only for selected-node supplement and
  final cull. The base budget remains `1.0`, and active selection expands
  visibility only by the outward halo extent so selected edge nodes stay
  paint-visible without reintroducing unselected off-viewport geometry or
  text-layout work.
- Interactive lifecycle closure is now documented and pinned by repository
  invariants: public `handlePointer(...)` / `handleDoubleTap(...)` remain
  manual-only hooks, active draw and pending two-tap line state use captured
  gesture-start style, and `SceneView` session teardown is explicitly
  detach-before-dispose.
- `SceneView` runtime session teardown is now fully terminal on `detach()`.
  Failed runtime swaps now surface to the host instead of being swallowed,
  while rendering and pointer input stay on the last installed runtime until a
  later successful rebuild replaces it. Detached pointer sessions also release
  controller-owned listener/token resources immediately instead of waiting for
  a later `dispose()`.
- Pending two-tap line read-state now exposes captured line color and
  thickness through `SceneControllerInteraction.pendingLineColor` and
  `pendingLineThickness`, so host UI can render pending-line markers with the
  same style that the eventual line commit will use.
- Added a manual GitHub Actions workflow that builds the `example/` Windows
  desktop app and publishes an Inno Setup `setup.exe` installer artifact for
  install-and-launch smoke testing on Windows machines.
- Breaking: Scene metadata contracts are now aligned across ordinary public
  constructors, runtime owners, validated helper paths, and import/decode.
  `CameraSnapshot`, `GridSnapshot`, and `BackgroundSnapshot` now reject invalid
  metadata eagerly, runtime `Camera`, `GridSettings`, and `ScenePalette` use
  the same shared value contract, validated `...FromValidated` metadata
  helpers no longer materialize invalid values, and raw malformed scene
  metadata remains available only through explicit internal backing or draft
  materialization paths.
- Public `SceneSnapshot` is now structurally valid by construction for public
  callers: ordinary `SceneSnapshot(...)` and validated producer paths reject
  duplicate node ids, duplicate content-layer ids, and scene-wide
  layer/node-count overflow at the snapshot boundary, while explicit malformed
  snapshot materialization remains internal-only under `contract/internal/**`.
- Public stroke snapshots no longer expose `pointsRevision`. Typed
  snapshot import/export and JSON persistence now treat stroke geometry
  revision as runtime-only metadata, and render/cache read-side freshness for
  public stroke snapshots now keys off public geometry/scalar payload instead
  of a public runtime revision field.
- Transaction state now finalizes before commit planning: successful node and
  structural writes expose finalized `SceneWriteTxn.snapshot` /
  `selectedNodeIds` before callback return, commit planning is read-only over
  finalized transaction state, and `isSelectable: false` patches no longer
  create false `selectionChanged` deltas for explicitly selected visible ids.
- Interactive committed draw-family writes now route through
  `SceneControllerMutationBoundary` together with move and selection commits,
  and guardrails reject direct draw callback wiring from
  `scene_controller_interaction_runtime.dart` to `storeController.draw.*`.
- Runtime numeric write semantics are now reject-only for `SceneNode.opacity`
  and background-grid cell size. Invalid runtime writes throw
  `ArgumentError`, enabled-grid writes no longer clamp undersized cell sizes,
  controller commit no longer repairs grid numeric state after mutation, and
  import/snapshot validation now rejects enabled grid payloads whose
  `cellSize` is below `1.0` before runtime materialization.
- Breaking: JSON schema `6` is no longer supported. The engine now writes and
  reads only `schemaVersion = 7`, text JSON payloads must not contain `size`,
  and text bounds are derived from layout inputs instead of crossing runtime,
  snapshot, or JSON boundaries as stored size metadata.
- Import/decode once again rejects text nodes whose derived layout bounds
  exceed scene size limits, restoring the pre-removal range guard after stored
  text `size` was removed from typed and JSON boundaries.
- Shared scene-model invariants now reject oversized stroke point lists and
  palette lists through one shared contract path across typed construction,
  import/decode, and encode. Text nodes now carry explicit `textDirection` in
  runtime and serialized scene data, public `TextNodeSpec` /
  `TextNodeSnapshot` creation requires explicit direction, and `TextNodePatch`
  can update direction for existing text nodes.
- Breaking: Runtime stroke geometry is now hermetic: `StrokeNode.points` exposes a
  read-only view, direct list mutation is rejected, `StrokeNode.replacePoints`
  is the canonical runtime geometry write surface, and stroke point patches now
  route through that owner while preserving `pointsRevision` no-op semantics.
- Runtime palette ownership is now replacement-only: `Scene.palette` keeps a
  mutable reference to an immutable `ScenePalette` value object, palette
  constructor inputs are defensively copied, and direct mutation of
  `penColors`, `backgroundColors`, or `gridSizes` is rejected after
  construction.
- Interactive write-side ownership is now canonicalized across
  `replaceScene(...)`, controller-side transform/delete preflight, and
  `SceneView` pointer semantics: `replaceScene(...)` now materializes its
  runtime payload exactly once before gesture reset, files under
  `lib/src/interactive/**` no longer import `model/document.dart`, and
  tap/double-tap recognition plus live pointer-settings adoption moved out of
  `SceneViewInteractivePointerHost` into a dedicated controller-owned
  pointer-semantics runtime assembled behind controller-private internal
  access instead of a view-local concrete dependency. `clearScene(...)` now
  routes its structural write through the same command-layer owner that emits
  `scene.cleared`, leaving `SceneControllerMutationBoundary` as the interactive
  action adapter instead of a second write-side owner.
- Interactive render read-side ownership is now unified under one
  controller-owned internal render-state: `SceneViewRenderSurface`,
  `ScenePainter`, `ScenePainterFrameOwner`, and
  `SceneViewInteractiveOverlayPainter` share the same live marquee/preview
  reads and the same repaint source, `view/**` no longer uses
  `interactive/internal/**` helper reads for the closed render seam, and
  reset mutations such as `setCameraOffset(...)` and `replaceScene(...)` clear
  stale overlay state immediately on screen.

### Breaking

- `SceneWriteTxn` no longer exposes `writeSignalEnqueue(...)` on the public
  package surface. Committed-signal buffering and delivery remain internal
  controller/runtime behavior instead of a supported public write capability.
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
- `SceneControllerInteraction.snapshot` was removed from the public runtime
  surface. Integrations must read committed render-state from
  `controller.snapshot` instead of `controller.interaction.snapshot`.
- JSON schema `5` is no longer supported. The engine now writes and reads only
  `schemaVersion = 6`, and text nodes must include explicit `textDirection`
  during decode instead of relying on legacy view-context fallback semantics.
- `ScenePainter` and `SceneViewRenderSurface` no longer accept a
  painter-level `textDirection` override. Text layout and `TextAlign.start` /
  `TextAlign.end` semantics are now fully owned by per-node
  `TextNode.textDirection`.

### Changed

- `SceneController` post-split cleanup removed residual selection/scene access
  adapters, restored root-owned committed render-state reads for interactive
  overlay painting, and aligned docs/guardrails with the final
  `controller.interaction` / `controller.selection` / `controller.scene`
  capability graph.
- Finalized the internal `model/` owner graph for steps `40-44`: the
  repository now documents `scene_builder_api.dart` as the public
  `SceneBuilder` surface, keeps `scene_builder.dart`,
  `scene_node_boundary_mapping.dart`,
  `scene_value_validation.dart`, and `document.dart` as thin canonical
  facades, and enforces the no-`part` / no-bypass architecture with dedicated
  model guardrails and invariant coverage.
- Background-grid rendering now has one internal owner in
  `src/render/scene_grid_renderer.dart`: `ScenePainter` and
  `SceneStaticLayerCache` share the same drawable predicate, density bucket,
  camera-shift math, and line-emission plan, while static cache remains
  responsible only for picture lifecycle and the existing local key contract.
  Density bucketing now uses a deterministic bounded anti-flap policy based on
  a camera-phase-independent visible-line upper bound, so near-threshold pans
  no longer switch stride modes unnecessarily and still stay within
  `kMaxGridLinesPerAxis`.
- `SceneController.interaction.handlePointer(...)` now owns canonical terminal
  pointer normalization for both direct and `SceneView`-routed input:
  non-finite `down`/`move` are still dropped, while non-finite terminal
  `up`/`cancel` preserve their original phase only when the same `pointerId`
  already has a cached finite position; otherwise they stay a no-op. Explicit
  `dragStartSlop` now uses the same finite `>= 0` validation rule in both the
  constructor and `setDragStartSlop(...)`.
- `SceneController` now owns one internal active-gesture machine:
  it captures baseline `dragStartSlop` on `down`, ignores parallel
  non-owning `pointerId`s until terminal release, and force-resets the active
  gesture only when `replaceScene(...)`, `setCameraOffset(...)`, mode/tool
  transitions, and `dispose()` continue with an observable boundary change.
- Interactive transform/delete preflight now has one owner in
  `src/interactive/interaction_eligibility_policy.dart`: controller-side
  rotate/flip/delete entrypoints use shared snapshot-based admissibility,
  while `MutationExecutor` keeps its write-layer guards as a separate
  defensive barrier rather than a competing policy owner.
- Move-mode hit-test, marquee selection, preview, and commit now use one
  shared interactive eligibility contract: selectable-but-non-movable nodes
  can still become selected on pointer `down`, but they no longer start move
  preview, and pointer `cancel` restores the gesture baseline selection after
  move-local selection changes.
- `SceneController` now rejects external `setSelection(...)`,
  `toggleSelection(...)`, `clearSelection()`, and `selectAll(...)` while an
  active move/draw gesture is in progress, so selection lifecycle has one
  controller-owned gesture owner between `down` and terminal `up`/`cancel`.
- Active-gesture exclusivity now covers all mutating
  `controller.selection.*` entrypoints and public deny-listed
  `controller.scene.*` mutations. `scene.write(...)`,
  `setBackgroundColor(...)`, `setGridEnabled(...)`, `setGridCellSize(...)`,
  `addNode(...)`, `ensureLayer(...)`, `patchNode(...)`, `removeNode(...)`,
  `clearScene(...)`, `rotateSelection(...)`, `flipSelectionVertical(...)`,
  `flipSelectionHorizontal(...)`, and `deleteSelection(...)` now throw
  `StateError` during an active gesture, while `setCameraOffset(...)` and
  `replaceScene(...)` remain the only public scene mutations that can
  force-release the gesture after their existing preflight succeeds.
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
  text layout cache keys still include paint color because cached resolved
  text-layout payloads retain render style.
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
  - `PLAN.md` is reduced to active-plan status only
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
  `SceneController` / `SceneViewInteractive` and their aliases.
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

- Stable public interactive runtime root `SceneController` and widget
  `SceneView`.
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
