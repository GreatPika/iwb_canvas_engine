# iwb_canvas_engine

[![pub package](https://img.shields.io/pub/v/iwb_canvas_engine.svg)](https://pub.dev/packages/iwb_canvas_engine)
[![CI](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml/badge.svg)](https://github.com/GreatPika/iwb_canvas_engine/actions/workflows/ci.yaml)

`iwb_canvas_engine` is a Flutter canvas engine for whiteboard-style products. It
provides an immutable scene model, rendering, interactive input handling, and
JSON serialization. It does not include app UI, persistence, or undo/redo
storage.

- Current package version: `5.1.0`
- Single public import: `package:iwb_canvas_engine/iwb_canvas_engine.dart`
- JSON contract: write `schemaVersion = 7`, read `{7}`
- Demo: https://greatpika.github.io/iwb_canvas_engine/demo/
- Hosted API docs: https://greatpika.github.io/iwb_canvas_engine/api/
- Full integration reference: `API_GUIDE.md`

## What it provides

- Deterministic scene rendering with a dedicated boundary `backgroundLayer`
  plus ordered content `layers`.
- `SceneController` as the public interactive runtime root, with capability
  owners exposed through `controller.interaction`, `controller.selection`, and
  `controller.scene`, plus `SceneView` as the public interactive widget.
- Transactional write API via `SceneWriteTxn` for supported scene, selection,
  and document mutations.
- Explicit path fill-rule contract via `PathFillRule`.
- JSON import/export with strict validation and canonicalization.
- Parsed-map import via `SceneBuilder.buildFromJson(...)` with the same stable
  `SceneDataException.code` / `path` / `details` contract used by
  `decodeScene(...)`.
- Bounded JSON import guardrails for layers/nodes/points/path data plus string
  and palette payload sizes, including a raw `decodeSceneFromJson(...)` input
  limit of `33554432` characters before parsing.
- Boundary failures expose stable `SceneDataException.code`, `path`, and
  immutable `details`; `message` remains a derived human-readable summary.
- The package entrypoint exports the stable error surface
  `SceneDataException` / `SceneDataErrorCode`; internal diagnostic adapters
  used to assemble those errors remain under `src/**` and are not part of the
  supported package API.
- Collection-limit failures for palette lists and stroke points, optional
  image `naturalSize` child-field failures, and parsed color/enum literals
  all follow the same details-first boundary contract across builder/decode
  entrypoints.
- Public validated boundary value types such as `NodeIdValue`,
  `LayerIdValue`, `ImageIdValue`, `FiniteOffsetValue`, and `OpacityValue` for
  pre-validating external inputs before snapshot/spec construction and for
  keeping decode/build boundary rules aligned with the exported contract.

## What it does not provide

- Toolbars, dialogs, side panels, or product-specific UI.
- Storage, sync, or backend collaboration.
- App-level history management.

## Install

```sh
flutter pub add iwb_canvas_engine
```

## Developer tooling

This repository uses the external DCM CLI for additional static analysis on top
of `flutter analyze`.

1. Install DCM for your platform by following the official guide:
   [Installation](https://dcm.dev/docs/getting-started/for-developers/installation/).
2. Run the repository checks:

```sh
dcm analyze .
flutter analyze
```

In CI, DCM is installed with the official GitHub Action before the static
checks job runs.

For coverage-gap diagnostics after `flutter test --coverage`, use the
machine-first coverage report instead of manual repository searches:

```sh
dart run tool/check_coverage.dart --json
dart run tool/check_coverage.dart --json --uncovered-branches
dart run tool/check_coverage.dart --json --uncovered-branches --changed-only
```

The JSON payload keeps the existing `lib/src/**` coverage gate semantics while
returning one flat `gaps` collection. Each gap carries the source path,
enclosing declaration or file-scope fallback, compact declaration range,
missed lines and optional branch records, a compact source snippet, candidate
test paths, and the preferred verification step id when a repository scope can
be resolved deterministically. Use `--changed-only` to restrict triage to
changed `lib/src/**` files from the current git worktree.

For minimal runtime/listener repros that need a clean package boundary, use the
temporary package runner instead of hand-assembling `/tmp` test directories:

```sh
dart run tool/run_temp_pkg_test.dart --snippet-file=path/to/repro_snippet.dart
dart run tool/run_temp_pkg_test.dart --test-file=path/to/full_repro_test.dart
cat path/to/repro_snippet.dart | dart run tool/run_temp_pkg_test.dart --stdin
```

`--snippet-file` and `--stdin` wrap the snippet with standard
`flutter_test`, `flutter/widgets.dart`, and package imports before running it
inside a temporary Flutter package that depends on the current repository via
`path:`.

For clone-hunting during refactors, use the development-only analyzer script:

```sh
dart run tool/analysis/find_similar_clones.dart . 60 30 5 4 0.55 12
```

Use `dart run tool/analysis/find_similar_clones.dart --help` for the full
argument list and additional examples. Useful variants:

```sh
dart run tool/analysis/find_similar_clones.dart --exclude-main test 60 30 5 4 0.70 10
dart run tool/analysis/find_similar_clones.dart --json --top 20 lib 50 30 5 4 0.55 12
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  late final SceneController controller;

  @override
  void initState() {
    super.initState();
    controller = SceneController(
      initialSnapshot: SceneSnapshot(
        layers: [ContentLayerSnapshot(id: 'layer-0')],
      ),
    );

    controller.scene.addNode(
      RectNodeSpec(
        id: 'rect-1',
        size: const Size(160, 100),
        fillColor: const Color(0xFF1565C0),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SceneView(controller: controller);
  }
}
```

## Runtime contracts worth knowing

- Text runtime and snapshot bounds are derived from text layout inputs.
  `TextNode`, `TextNodeSnapshot`, `TextNodeSpec`, and `TextNodePatch` do not
  expose writable text `size`, and schema-version-7 JSON rejects text payloads
  that still contain `size`. Import/decode also rejects text whose derived
  bounds exceed scene size limits. On the render read-side, one canonical
  resolved text-layout payload now feeds both text geometry sizing and text
  paint, so the engine does not keep parallel layout owners for those paths.
- Runtime stroke geometry is hermetic: `StrokeNode.points` is a read-only view,
  direct list mutation is unsupported, and whole-geometry updates go through
  `StrokeNode.replacePoints(...)`, which preserves `pointsRevision` no-op
  semantics and rejects non-finite or oversized point lists. Public stroke
  snapshots and JSON carry only document geometry/scalar data; runtime
  `pointsRevision` does not cross the public boundary.
- `TextNode`, `TextNodeSnapshot`, and serialized text payloads carry explicit
  `textDirection`. Public `TextNodeSpec` / `TextNodeSnapshot` creation requires
  explicit direction, `TextNodePatch` can update it for existing text nodes,
  and JSON payloads without it are rejected by the current schema.
- Public snapshot/node/spec/patch constructors validate boundary ids and
  numeric values eagerly and are runtime constructors rather than `const`
  entry points. Ordinary public `SceneSnapshot(...)` construction also rejects
  duplicate node ids, duplicate content-layer ids, and scene-wide
  layer/node-count overflow before a malformed public snapshot can escape the
  boundary.
- `SceneSnapshot` is the canonical public document boundary. Typed snapshot
  import and parsed JSON decode may normalize through internal draft/import
  owners, but callers still only construct, pass, and receive public
  snapshots; raw malformed snapshot or metadata assembly stays internal-only.
- Scene metadata uses one shared eager contract across public constructors,
  runtime setters/owners, typed import, and JSON decode. `CameraSnapshot` /
  `Camera.offset` reject non-finite or out-of-range offsets, `GridSnapshot` /
  `GridSettings` require finite positive bounded `cellSize` values, enabling a
  grid still requires `cellSize >= 1.0`, and palette lists must stay non-empty,
  bounded, and use finite positive bounded `gridSizes`.
- Internal snapshot/spec/patch backing identity and materialization helpers
  live only under `lib/src/contract/internal/**`; they are package internals,
  not supported public API.
- runtime `Scene.backgroundLayer` may be absent internally, while snapshot/JSON
  boundaries canonicalize it to a dedicated layer distinct from content
  `layers`; content writes use `LayerId`.
- runtime `SceneNode.opacity` is reject-only: assignments must be finite and
  stay within `[0, 1]`, otherwise the write throws `ArgumentError`.
- runtime `Background.grid` is reject-only: `GridSettings.cellSize` must stay
  finite and `> 0`, and enabling the grid requires
  `cellSize >= 1.0` instead of silently clamping or repairing the value later.
- snapshot/JSON import uses the same enabled-grid minimum, so invalid payloads
  fail at the import boundary with `SceneDataException` instead of later during
  runtime materialization.
- runtime `Scene.palette` is replacement-only at the object level; a
  `ScenePalette` defensively copies and freezes its nested lists, so palette
  presets cannot be mutated in place after construction.
- ordinary runtime scene writes enforce content-layer and total-node budgets at
  the model mutation owner, so oversized layer/node additions fail before the
  scene mutates instead of only at snapshot/export boundaries.
- constrained runtime node fields such as transforms, hit padding, image/text
  layout inputs, vector geometry, path data, and stroke widths are reject-only
  at owner boundaries; invalid assignments throw `ArgumentError` instead of
  relying on later render/layout sanitization.
- controller commits run a critical changed-surface runtime validity backstop
  in every build mode before store apply, while `debug` and `profile` keep the
  full committed-store invariant sweep.
- Boundary helpers such as `parseNodeId(...)`, `parseLayerId(...)`, and
  validated value types including `ImageIdValue` keep external payload checks
  aligned with import/build rules. Runtime-generated ids are internal engine
  details rather than a public compatibility promise. See `API_GUIDE.md` for
  the full list.
- For import/build/encode failures, compare `SceneDataException` instances by
  `code` / `path` / `details`; this parity is shared by
  `SceneBuilder.buildFromJson(...)`, `decodeScene(...)`,
  `decodeSceneFromJson(...)`, `encodeScene(...)`, and `encodeSceneDocument(...)`.
  Treat `message` as user-facing text rather than the primary machine
  contract.
- `ensureLayer(...)` and `writeLayerEnsure(...)` are the supported APIs for
  explicit content-layer creation.
- `write(...)` is synchronous-only. Returning a `Future` throws `StateError`.
- explicit duplicate `NodeSpec.id` in `addNode(...)` or `writeNodeInsert(...)`
  throws `ArgumentError`.
- `actions`, `editTextRequests`, and `ChangeNotifier` updates are asynchronous;
  listener notifications are microtask-deferred and coalesced. For interactive
  state, those public listener updates stay independent from the internal
  scene/overlay repaint split, so overlay-only marquee/preview changes still
  notify `SceneController` listeners.
- `setPointerSettings(...)` is applied live by `SceneView`; active gestures keep
  their current settings until `up` or `cancel`, and parallel raw host pointers
  do not force an early reset of routed pointer tracking. Settings are treated
  as a value object, and while raw pointers remain live a controller-owned
  pointer-semantics owner keeps only the last pending update until router idle.
- Public `handlePointer(...)` / `handleDoubleTap(...)` hooks remain manual-only
  entrypoints on `SceneControllerInteraction`. `SceneView`-routed input uses an
  internal tokenized session path instead of sending session-owned provenance
  back through the public facade.
- `SceneControllerInteraction`, `SceneControllerSelection`, and
  `SceneControllerScene` are controller-owned capability contracts. Obtain them
  from `controller.interaction`, `controller.selection`, and `controller.scene`
  rather than constructing them directly.
- `SceneView` runtime swaps are atomic: replacement pointer sessions are
  created before install, failed replacement creation surfaces to the owner,
  and render/input ownership stays on the last installed runtime until a later
  rebuild succeeds. Session `detach()` is the terminal controller-unbind step:
  it releases controller-owned listener/token resources immediately and turns
  later session callbacks into local no-ops before the final idempotent
  `dispose()`.
- `SceneController` keeps one controller-owned active gesture owner:
  parallel `pointerId`s are ignored until the owner ends, and
  mode/tool changes interrupt for interaction-config changes,
  `replaceScene(...)` / `setCameraOffset(...)` interrupt for external
  mutations only after preflight confirms the boundary transition will proceed,
  routed-session `detach()` clears only matching session-owned state, and
  `dispose()` remains destructive teardown rather than an alias of those
  interruption paths.
- Pending two-tap line state keeps its captured line style on the read side as
  well as the write side: `pendingLineColor` / `pendingLineThickness` reflect
  the pending commit style, while mutable `drawColor` / `lineThickness` remain
  configuration for the next gesture. Pending line ownership remains draw-local,
  so one owner source may replace but not complete another owner source's
  pending commit.
- Public scene/selection mutations are gesture-exclusive while an active
  move/draw gesture is in progress. `scene.write(...)`,
  `setBackgroundColor(...)`, `setGridEnabled(...)`, `setGridCellSize(...)`,
  `addNode(...)`, `ensureLayer(...)`, `patchNode(...)`, `removeNode(...)`,
  `clearScene(...)`, `setSelection(...)`, `toggleSelection(...)`,
  `clearSelection()`, `selectAll(...)`, `rotateSelection(...)`,
  `flipSelectionVertical(...)`, `flipSelectionHorizontal(...)`, and
  `deleteSelection(...)` throw `StateError` until terminal `up` or `cancel`.
- Transaction-scoped reads are finalized before commit planning: after any
  successful node or structural mutation inside `write(...)`,
  `SceneWriteTxn.selectedNodeIds` and `SceneWriteTxn.snapshot` already expose
  the state that would commit if the callback returned immediately. Patching a
  selected visible node to `isSelectable: false` keeps it explicitly selected
  and does not create a false selection delta.
- Background grid rendering now has one internal owner in
  `src/render/scene_grid_renderer.dart`: direct painter draw and static-cache
  recording share the same drawable predicate, density bucketing, camera-shift
  math, and bounded anti-flap policy without any cross-frame mutable grid
  state.
- Interactive transform/delete preflight is snapshot-based and shared:
  controller-side rotate/flip/delete entrypoints use one internal eligibility
  policy owner, while write-layer guards remain defensive commit barriers.
- Interactive committed writes have one owner: stroke, line, erase, move,
  and selection commits all route through `SceneControllerMutationBoundary`
  instead of mixing direct `storeController.draw.*` bypasses into the runtime
  callback graph.
- Move-mode hit-testing, marquee selection, move preview, and move commit now
  share one internal eligibility policy: selectable-but-non-movable nodes can
  still become the selection target, but they do not start move preview, and
  pointer `cancel` restores the gesture baseline selection after any temporary
  move-local selection change.
- `SceneView` main-painter and overlay reads now share one controller-owned
  internal render-state family with split repaint ownership: the main painter
  listens to the scene channel, the interactive overlay listens to
  `overlayRepaintListenable`, and marquee rendering lives fully in the overlay
  painter. Live marquee/preview state therefore updates without widget-field
  snapshots or helper-based read-side seams at the view boundary, while the
  main painter still consumes controller-enumerated ordered viewport
  candidates so cold paints do not resolve off-viewport content geometry and
  selected move previews can still pull nodes into frame. One render-local
  `ScenePainterVisibilityBudget` now widens only the frame visibility rect and
  the selected-node supplement path: ordinary candidate enumeration stays
  viewport-first, the base budget stays at `1.0`, and active selection adds
  only the outward halo extent so selected edge nodes remain visible without
  reintroducing unselected off-viewport work.
- `handlePointer(...)` treats non-finite `down`/`move` as no-op admission
  failures. For non-finite terminal `up`/`cancel`, the controller preserves the
  original terminal phase only when the same `pointerId` already has a cached
  finite position; otherwise the terminal sample stays a no-op. Explicit
  `dragStartSlop` uses the same finite `>= 0` contract in both the constructor
  and `setDragStartSlop(...)`.

## Where to look next

- `API_GUIDE.md` for public API details, validation rules, and migration notes.
- `ARCHITECTURE.md` for module layout, runtime data flow, and invariants.
- `CHANGELOG.md` for release history and unreleased changes.
- `example/README.md` for the demo app scope.

## License

MIT. See `LICENSE`.
