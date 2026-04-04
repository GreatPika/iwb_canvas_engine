# Architecture Overview

This document describes the current mainline architecture of
`iwb_canvas_engine`. It focuses on system shape, data flow, invariants, and the
constraints that keep the public API stable.

## Goals

- Keep scene state in one place.
- Expose stable public contracts around immutable snapshots and safe writes.
- Separate product UI concerns from engine/runtime concerns.

## System boundary

- Public entrypoint: `package:iwb_canvas_engine/iwb_canvas_engine.dart`
- Supported public surface: exactly the exports declared by
  `lib/iwb_canvas_engine.dart`
- Current serialization contract: write `schemaVersion = 7`, read `{7}`
- Public interactive runtime root: `SceneController`
- Public interactive widget: `SceneView`
- Public write boundary: `SceneWriteTxn`

The package is an engine. It does not own app UI, persistence, collaboration, or
undo/redo policy.

## Module layout

Current repository layout:

```text
lib/
  iwb_canvas_engine.dart
  src/
    contract/       // stable API contracts and contract-facing value types
      validated/    // boundary value objects and id/revision parsing rules
    core/           // primitives, defaults, math, event types
    controller/     // committed store, command execution, transactional writes
    interactive/    // public controller facade and gesture orchestration
    model/          // conversions between internal document and public snapshot
    render/         // painter and render-cache implementations
    serialization/  // JSON codec and validation boundary
    view/           // Flutter widget that wires input + painting
```

## Layer ownership note (ADR)

- Public API is defined only by exports from
  `lib/iwb_canvas_engine.dart`.
- `src/**` remains internal package structure rather than a supported external
  import contract.
- `src/contract/validated.dart` is part of the supported public API because it
  is exported by the package barrel; no separate compat or advanced entrypoint
  exists for it.
- `contract/` is the low-level layer for stable API contracts and
  shared contract-facing value types.
- `contract/pointer_input.dart` owns routed pointer boundary value types
  (`PointerPhase`, `PointerSample`, `PointerInputSettings`) and pointer
  settings validation; `core/` consumes that boundary instead of owning a
  second copy.
- `contract/validated/**` is the single contract-facing home for boundary value
  parsing/generation rules; `model/` and `serialization/` consume it rather
  than re-owning those rules independently.
- The `lib/src` dependency graph is explicit and acyclic.

Current dependency DAG:

- `contract -> none`
- `core -> contract`
- `model -> core + contract`
- `serialization -> model + core + contract`
- `controller -> model + core + contract`
- `interactive -> controller + model + core + contract`
- `render -> model + core + contract`
- `view -> interactive + controller + render + model + core + contract`

Ownership decisions for the target state:

- `SceneBuilder` is not part of `contract/`; it belongs to `model/`.
- Parsed-map normalization for `SceneBuilder.buildFromJson(...)` stays in the
  `model/` layer via a model-local guard; `model/` must not import
  `serialization/` to reuse transport wrappers.
- `SceneBuilder` is a thin model-local import facade: orchestration remains in
  `model/scene_builder.dart`, parsed-map require/decode ownership lives in
  explicit `model/scene_builder_json_require.dart`,
  `model/scene_builder_decode_json.dart`,
  `model/scene_builder_decode_scene.dart`,
  `model/scene_builder_decode_scene_metadata.dart`,
  `model/scene_builder_decode_layers.dart`,
  `model/scene_builder_decode_node_common.dart`,
  `model/scene_builder_decode_node_family.dart`, and family-local decode
  owners, and shared typed-snapshot adapters/runtime import live in
  `model/scene_import_draft_from_snapshot.dart`,
  `model/scene_from_import_draft.dart`, and
  `model/scene_from_snapshot.dart`.
- `document.dart` remains the downstream transaction facade, but it consumes
  focused model-local owners for locator, scene-edit, patch, and
  selection/grid work, and it consumes `scene_from_snapshot.dart` and
  `scene_snapshot_from_scene.dart` directly for runtime import/export instead
  of depending on `scene_builder.dart`.
- `Transform2D` is part of the supported contract language and lives in
  `contract/` as a contract-facing value type; its file move does not change
  the public symbol name.
- `PathFillRule` is part of the supported contract language and lives in
  `contract/path_fill_rule.dart`; `core/nodes.dart` is a consumer rather than
  the long-term owner of that enum.
- `contract/transform_tolerance.dart` is the single internal source of truth
  for the near-singular 2x2 criterion used by `contract/transform2d.dart` and
  downstream `core/` consumers; `contract/` must not import
  `core/numeric_tolerance.dart`.
- Runtime orchestration and owner-specific facades do not move into
  `contract/`.
- `contract/` is low-level but not pure Dart: contract types intentionally use
  `dart:ui`, and `SceneRenderState` depends on Flutter `Listenable`.

## Contract owner graph

- The final `contract` layer is fully part-free. Structural closure is pinned
  mechanically by `tool/check_guardrails.dart` and
  `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`; `part` / `part of` must not return
  anywhere under `lib/src/contract/**`.
- `contract/node_patch.dart`, `contract/node_spec.dart`, and
  `contract/snapshot.dart` remain the public immutable boundary owners and keep
  validation at the public constructor boundary.
- Exported public contract and runtime signatures must not expose mutable core
  model owners or mutable controller/runtime owners directly; the supported
  public API stays on immutable boundary types and explicit facade contracts.
  This contract is pinned by `INV-ENG-PUBLIC-SURFACE-NO-MUTABLE-TYPES`.
- `contract/node_spec.dart` and `contract/node_patch.dart` are thin public
  wrappers over immutable internal backing graphs. Trusted spec/patch storage
  and public wrapper materialization no longer live inside the public files.
- `contract/snapshot.dart` is part-free and stays the only supported public
  snapshot surface, but scene/layer/palette/node snapshots are now thin public
  wrappers over immutable internal backing objects rather than owners of
  trusted field assembly.
- `contract/internal/node_boundary_schema.dart` is the canonical internal
  schema import surface, but it is barrel-only.
- `contract/internal/node_boundary_schema_common.dart` owns shared schema field
  definitions plus truly cross-direction primitive validators.
- `contract/internal/node_boundary_schema_patch.dart`,
  `contract/internal/node_boundary_schema_spec.dart`, and
  `contract/internal/node_boundary_schema_snapshot.dart` own direction-local
  validation and validated-field rehydration for patch, spec, and snapshot
  flows respectively.
- `contract/internal/snapshot_backing.dart` owns the immutable internal
  snapshot backing graph for scene, layer, palette, and node snapshot state.
- `contract/internal/snapshot_materialization.dart` owns public wrapper
  materialization plus the internal compatibility helpers used by contract
  tests and malformed-snapshot failure injection.
- Validated snapshot materialization must preserve the original top-level
  `SceneSnapshotBacking` carrier; metadata revalidation belongs on the backing
  path before wrapper materialization rather than by rebuilding plain public
  snapshot wrappers.
- Public snapshot/spec/patch files do not expose backing getters or
  `materialize(...)` members. Backing identity and wrapper materialization stay
  on internal helper paths under `contract/internal/**`.
- `contract/internal/snapshot_fast_path.dart` is the canonical internal
  snapshot construction import surface; downstream code uses it instead of
  importing privileged construction from `contract/snapshot.dart`.
- `contract/internal/node_spec_backing.dart` and
  `contract/internal/node_patch_backing.dart` own the immutable internal
  `NodeSpec` / `NodePatch` family backing graphs.
- `contract/internal/node_spec_materialization.dart` and
  `contract/internal/node_patch_materialization.dart` own public wrapper
  materialization plus the validated compatibility helpers used by
  contract-local fast-path tests.
- `contract/internal/node_spec_fast_path.dart` and
  `contract/internal/node_patch_fast_path.dart` are thin canonical barrels for
  contract-local validated construction; they export backing/materialization
  owners and must not grow back into mixed implementation buckets.
- Downstream `model/` and `serialization/` code consume those internal schema
  owners through the barrel and do not re-own schema validation locally.
- Downstream non-contract production code may import only the canonical
  internal surfaces `contract/internal/node_boundary_schema.dart` and
  `contract/internal/snapshot_fast_path.dart`; it must not bypass them and
  import lower-level contract owner modules directly.

## Model owner graph

- Public `SceneBuilder` surface lives in `model/scene_builder_api.dart`; the
  exported static API is the supported non-controller import boundary.
- `model/scene_builder.dart` is the thin internal import facade only. It may
  orchestrate `scene_builder_decode_json.dart`,
  `scene_builder_decode_scene.dart`,
  `scene_builder_decode_node_common.dart`,
  `scene_builder_decode_node_family.dart`,
  the family-local `scene_builder_decode_{image,text,stroke,line,rect,path}.dart`
  owners,
  `scene_builder_json_parse.dart`,
  `scene_builder_json_require.dart`,
  `scene_import_draft.dart`,
  `scene_import_draft_from_snapshot.dart`,
  `scene_from_import_draft.dart`,
  `scene_from_snapshot.dart`, and
  `scene_snapshot_from_scene.dart`, but downstream non-model code must not
  re-own those internals.
- `model/scene_document_codec.dart` is the canonical runtime document codec
  facade for downstream non-model serialization. It owns internal `Scene`
  decode and encode-canonicalization entrypoints so non-model code does not
  import `scene_builder.dart`, `scene_from_snapshot.dart`, or
  `scene_policy.dart` directly.
- `model/scene_from_snapshot.dart` and
  `model/scene_snapshot_from_scene.dart` are the shared typed-adapter/export
  owners. `document.dart` consumes them directly; it must not recover a
  `document.dart -> scene_builder.dart` dependency.
- `model/scene_import_draft.dart` is the single model-owned pre-canonical
  import carrier. Typed `SceneSnapshot` import and parsed-map decode both
  normalize into this draft before scene-level policy validation closes.
- Ordinary `SceneImportDraft(...)` construction stays on validated backing
  builders; raw decode and malformed-draft assembly must remain explicit
  through `SceneImportDraft.fromBacking(...)`.
- `model/scene_from_import_draft.dart` is the runtime materializer from a
  validated draft to mutable `Scene`; public `SceneSnapshot` is not used as
  the scene-level working container during import.
- Producer-side import/decode work targets the internal snapshot
  backing/materialization graph and materializes public snapshot wrappers only
  at explicit public return edges.
- `model/scene_node_boundary_mapping.dart` is the canonical node-boundary
  mapping facade. The removed residual support file
  `scene_node_boundary_mapping_support.dart` must not return. Family-local
  mapping owners stay in the
  `scene_node_boundary_mapping_*.dart` files and must not be imported directly
  by downstream non-model code; downstream entry uses document/codec facades
  instead of importing `scene_node_boundary_mapping.dart` directly. Mapping and
  JSON decode owners build `NodeSnapshotBacking` values first and only
  materialize public node snapshots at explicit edges.
- `model/scene_value_validation.dart` is the canonical validation facade.
  Focused validation owners stay in
  `scene_value_validation_{node,palette_grid,primitives,support,top_level}.dart`,
  `ScenePolicy` remains the import/runtime orchestration owner for scene-level
  validation closure, and `contract/scene_structure_validation.dart` owns the
  shared duplicate/count document-structure policy reused by public snapshot
  construction and model import validation.
- `model/document.dart` is the canonical downstream transaction facade.
  Locator, scene-insert, patch, scene-edit, and selection/grid ownership stay
  in `document_{locator,scene_insert,node_patch,scene_edit,selection}.dart`
  instead of returning to `document.dart`.
- `model/document_node_patch.dart` is the canonical patch dispatcher or
  validation facade. Shared patch-field application lives in
  `document_node_patch_common.dart`, and family-local runtime patch ownership
  lives in `document_node_patch_{image,text,stroke,line,rect,path}.dart`.
- `model/document_clone.dart` remains a separate focused helper for clone and
  adopt flows; it is not part of the step 40-43 facade/internal-owner split.

## Runtime data flow

1. `SceneView` receives Flutter pointer input and normalizes it into public
   `CanvasPointerInput`, while its view-local pointer router owns raw Flutter
   pointer lifetimes and routed runtime `pointerId` allocation. The closed
   local seam around `scene_view_interactive.dart`,
   `scene_view_runtime_host.dart`, and
   `scene_view_interactive_pointer_host.dart` may consume only the assembled
   `SceneViewRuntime` boundary. The public shell in
   `scene_view_interactive.dart` is the only production `view/**` file allowed
   to adapt `SceneController`; the rest of `view/**` consumes only
   `SceneViewRenderState` and `SceneViewPointerSession`, and must not import
   `interactive/internal/**`. The dedicated controller-owned pointer-session
   owner consumes routed samples, owns tap/double-tap recognition, deferred
   tap flushing, live `PointerInputSettings` adoption, and controller-change
   reaction, and keeps invalid terminal host forwarding on the same
   controller-side path as direct pointer input.
2. `SceneController` is the public interactive facade. It validates
   public inputs, keeps host-facing mode/tool/selection semantics, owns the
   snapshot-based eligibility policy used by controller-side transform/delete
   preflight and by move-mode hit-test/preview/commit shaping, keeps public
   scene/selection capability facades thin, restores move-local baseline
   selection on pointer `cancel`, and delegates boundary pointer handling plus
   external-mutation gesture policy to the controller-private
   `InteractiveRuntime`.
3. `InteractiveRuntime` is the controller-private boundary runtime. It owns the
   final interactive owner graph beneath the facade:
   `InteractivePointerNormalizer` for terminal pointer normalization,
   `InteractiveGestureRouter` for active pointer/family orchestration,
   `InteractiveDoubleTapRouter` for text double-tap routing,
   `InteractiveMoveSession` for move preview/commit ownership, and
   `InteractiveDrawCoordinator` for draw-family orchestration.
4. `InteractiveEventDispatcher` is the interactive event/timeline owner. It
   keeps monotonic timestamp sequencing plus `actions` /
   `editTextRequests` stream delivery outside `InteractiveRuntime`.
5. `InteractiveDrawCoordinator` remains a draw-family orchestrator only. It
   routes into `InteractiveDrawLineEngine`,
   `InteractiveDrawStrokeEngine`,
   `InteractiveDrawEraserEngine`, and
   `InteractiveDrawTerminalRouter`; precise eraser hit geometry and coarse
   candidate-query ownership stay inside `InteractiveDrawEraserEngine` and its
   focused helpers instead of returning to the coordinator or the runtime.
6. `SceneStoreController` performs transactional writes and finalizes a canonical
   immutable `SceneSnapshot`. It also owns prepared replace-scene materialization,
   so `replaceScene(...)` validates/imports runtime scene data exactly once
   before any active-gesture reset and the apply path adopts the prepared
   payload without a second snapshot import.
7. `ScenePainter` renders the committed snapshot plus any ephemeral preview
   state owned by the interactive controller. Background-grid draw semantics
   have one render-local owner in `render/scene_grid_renderer.dart`; painter
   and static cache consume the same plan instead of maintaining parallel grid
   math.
8. `actions` and `editTextRequests` expose asynchronous integration boundaries
   back to the host app.

## State ownership model

- The committed `SceneSnapshot` is the single source of truth.
- Committed-store invariant sweeps must reuse the shared runtime scene metadata
  contract for camera, grid, and palette values so raw/internal bypassed state
  is surfaced before controller code treats it as canonical.
- Preview state for move/draw gestures is intentionally ephemeral and does not
  mutate committed scene data until commit on `up`.
- Active gesture identity is controller-owned; move/draw helpers do not own a
  competing pointer lock.
- `SceneControllerMutationBoundary` is the only interactive owner allowed to
  perform committed scene/selection writes from public scene/selection
  capability surfaces and gesture-local selection flows. For `clearScene(...)`,
  the boundary is only the interactive adapter: structural clear ownership
  stays in `controller/commands/scene_commands.dart`, and the boundary adds the
  interactive `ActionType.clear` projection without re-owning the write path.
  Draw-family commits (`stroke`, `line`, `erase`) follow the same rule and may
  not bypass the boundary through direct runtime wiring.
  This contract is pinned by `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY`.
- `SceneControllerSelectionMutations`, `SceneControllerSceneMutations`, and
  `InteractiveSelectionActions` are thin routing shells only. They may enforce
  public gesture policy or route gesture-local requests, but they must not
  retain parallel committed-mutation semantics beside
  `SceneControllerMutationBoundary`.
- During an active move/draw gesture, public `controller.selection.*`
  mutations plus deny-listed `controller.scene.*` mutations are rejected before
  committed state changes; only `setCameraOffset(...)` and `replaceScene(...)`
  may reset the active gesture, and only after their existing preflight proves
  the boundary mutation will proceed.
- Interactive admissibility has one owner per boundary: snapshot-based
  transform/delete preflight and move-mode preview/commit shaping live under
  `interactive/`, while marquee inclusion and move hit-testing reuse the same
  owner contract for selection admissibility. `controller/mutation_executor.dart`
  keeps write guards as commit-time
  defensive barriers and does not import interactive-layer policy code.
- Move-session cancel semantics are local to the move owner: pointer `cancel`
  clears ephemeral preview/marquee state and restores the gesture baseline
  selection when that gesture changed selection before terminal completion.
- Interactive owner boundaries are structurally pinned:
  `SceneController` stays a facade over runtime/event/selection
  owners,
  `InteractiveRuntime` stays a boundary orchestrator rather than an event or
  draw-local geometry owner,
  and `InteractiveDrawCoordinator` stays a draw-family router rather than an
  eraser geometry/query owner.
- View-side render-cache lifecycle and `ScenePainter` assembly have one shared
  owner in the internal render-surface boundary; `SceneViewInteractive` remains
  the public interactive shell around that boundary, keeps pointer host and
  overlay ownership outside it, and routes both the main painter and overlay
  through the same controller-owned internal render-state plus one repaint
  source.
- `ScenePainter` keeps frame ownership and selection ownership separate:
  frame-local geometry resolution happens once in the frame owner, while
  selection rendering consumes only resolved `worldBounds` / `localPath`
  through focused render-local helpers instead of reopening geometry lookup.
  This contract is pinned by `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION`.
- `ScenePainter` keeps node-family rendering separate from frame ownership:
  rect/path, line/stroke, and text/image rendering consume only
  frame-resolved node data through focused render-local helpers instead of one
  mixed node-render owner.
- `ScenePainter` is a thin public shell over explicit private painter-local
  modules; `ScenePainterShell` is orchestration-only and sequences frame,
  background, node, and selection owners without owning cache/grid assembly,
  while frame, node-render, selection, and shared draw helpers communicate
  through imported contracts instead of library `part` coupling. This contract
  is pinned by `INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY`.
- Background-grid semantics are stateless and render-local: one shared owner
  computes drawable eligibility, density bucketing, camera shift, and line
  emission; `SceneStaticLayerCache` owns only picture lifecycle and key reuse
  around that shared grid plan.
- All committed mutations go through `write(...)` or higher-level controller
  methods that delegate to the same write path.
- Public API never exposes mutable internal scene objects.
- Runtime revision allocation is store-owned. The store keeps one composite
  invalidation identity from `controllerEpoch` plus node `instanceRevision`;
  commits never derive the next revision by scanning scene data.
- When the runtime revision counter reaches the safe-int ceiling, allocation
  resets the next revision to `1` and the commit must bump `controllerEpoch`.
  If the epoch cannot be bumped safely, the commit fails fast.

## Core owner graph

- `core/` remains the low-level owner for primitives, defaults, math, and
  event types; it depends only on `contract/`.
- `core/nodes.dart` is the canonical mutable-node facade for downstream
  consumers; it re-exports focused file-local owner modules rather than
  hand-owning mutable node implementations.
- `SceneNode` lives in `core/scene_node.dart` and remains the common mutable
  shell for `transform`, opacity, and bounds semantics.
  `SceneNode.transform` stays the single source of truth for mutable node
  transforms, `_SceneNodeTransformConvenience` remains file-local there, and
  runtime `opacity` writes are reject-only instead of clamp-normalized.
- `GridSettings` lives in `core/scene.dart` and owns the runtime validity
  envelope for background-grid writes: `cellSize` must stay finite and `> 0`,
  and enabling the grid is reject-only when `cellSize < 1.0`.
- Box-family mutable nodes live in `core/box_nodes.dart`, which keeps
  `_BoxNodePlacementOwner` as the file-local owner for top-left/AABB placement
  semantics.
- Stroke/line mutable nodes live in `core/vector_nodes.dart`, which keeps
  `_VectorNodeGeometryOwner` as the file-local owner for stroke/line
  world-local normalization and mutable geometry revision behavior.
  `StrokeNode.points` is a read-only runtime view; `StrokeNode.replacePoints`
  is the canonical write owner for stroke geometry validation and
  `pointsRevision` monotonicity. Public snapshot/JSON boundaries transport
  stroke geometry and scalar document data only; runtime `pointsRevision`
  stays inside the runtime owner.
- `PathNode` lives in `core/path_node.dart`, which keeps
  `_PathNodeLocalPathCacheOwner` as the file-local owner for local-path cache
  invalidation and diagnostics.
- Leaf support ownership stays isolated outside `nodes.dart`:
  `core/text_layout.dart` owns derived text measurement,
  `core/action_events.dart` owns immutable action payload freezing and parsing,
  and `core/id_generator.dart` owns runtime generated-id allocation state.
- Shared runtime geometry ownership does not move back into mutable node files:
  `core/node_geometry.dart` remains the shared render/hit-test geometry owner,
  and `core/scene_spatial_index.dart` remains the spatial-query owner.

## Core invariants

Canonical invariant definitions live in `tool/invariant_registry.dart`. The
most important architectural rules are:

- `write(...)` is synchronous-only; returning a `Future` is a contract error.
- `SceneWriteTxn` is valid only inside the active write callback.
- `model/` stays structurally part-free; final model architecture is pinned by
  guardrails so `document.dart` cannot re-import `scene_builder.dart` and
  downstream non-model code cannot bypass canonical model facades for focused
  owner modules such as `scene_builder.dart`,
  `scene_node_boundary_mapping.dart`,
  `document_node_patch.dart`,
  `scene_policy.dart`, and the step 40-48 internal owners through direct
  imports or re-exports; the removed residual file
  `scene_node_boundary_mapping_support.dart` is also guardrailed against
  reintroduction.
- Snapshot/JSON boundaries keep `backgroundLayer` distinct from ordered content
  `layers`; mutable runtime `Scene.backgroundLayer` may remain `null` until a
  write path materializes it.
- Content layers are addressed by stable `LayerId`; z-order is defined only by
  list order.
- Text bounds are derived from text layout inputs and do not cross runtime,
  snapshot, or JSON boundaries as stored `size` data.
- Import/decode range policy still validates derived text bounds against scene
  size limits even though text size is no longer stored on typed or JSON
  boundaries.
- Text layout semantics are model-owned: text nodes carry explicit
  `textDirection`, the current schema requires it during decode, and
  render/layout paths consume the node contract instead of a separate
  view-owned fallback. Public text creation is strict-explicit for direction,
  and the public patch boundary exposes direction mutation for existing text
  nodes instead of relying on a compatibility fallback.
- Boundary validation has one source of truth per rule: limits come from
  `contract/scene_contract_limits.dart`, shared scene-metadata and
  stroke/palette invariants live in `contract/scene_model_invariants.dart`,
  boundary value parsing/generation lives in `contract/validated/**`, and
  model/serialization layers reuse those rules instead of re-owning late-only
  copies.
- Public snapshot/spec/patch constructors enforce those primitive boundary
  rules eagerly; `contract/owned_collections.dart` is the single structural
  owner for immutable collection payload ownership; internal decode/runtime
  producers use contract-local fast paths so already validated data does not
  pay the same constructor boundary twice or fork collection semantics.
- Boundary fallback/backing seam helpers are intentionally hermetic: they
  accept only the built-in concrete public boundary types and fail fast with
  `StateError` for unsupported subtypes, including user-defined subclasses of
  known `NodeSpec`, `NodePatch`, `NodeSnapshot`, and scene snapshot wrapper
  families.
- Transactional write/model paths consume those already validated contract
  objects and own only runtime/stateful semantics such as target existence,
  type compatibility, live-scene duplicate checks, index/range checks,
  canonicalization, and derived-value recomputation.
- Generated-id policy is internal runtime ownership in
  `src/core/id_generator.dart`; public boundary code validates only explicit
  ids and must not depend on a generated-id string format.
- Selection normalization drops only missing, background, or invisible ids;
  explicit non-selectable ids remain stable.
- Listener notifications are microtask-deferred and coalesced.
- `actions` and `editTextRequests` are asynchronous; their relative ordering
  against repaint notifications is intentionally not a public contract.
- `PointerInputSettings` is a value object. `SceneView` does not own
  applied-versus-pending settings state; the controller-owned pointer-semantics
  owner applies updates only after the raw-pointer router becomes idle, keeps
  pending updates last-write-wins, and preserves the current settings for live
  routed pointers until terminal release.
- Routed pointer samples/phases and pointer-settings validation are contract
  owners. `PointerInputTracker` is an orchestration-only core owner over two
  focused pointer-local state owners: active down/slop state and deferred
  tap-window/double-tap lifecycle. Hosts consume one tracker contract without
  reopening those internal state machines in `view/` or `interactive/`.
- `debugSceneViewInteractive*`, `debugSceneViewRuntimeHost*`, and
  `debugSceneViewRenderCachesOf(...)` are deliberate stable test probes for
  `test/view/**`; they expose mounted host/render-surface diagnostics and keep
  fail-fast `StateError` behavior outside those boundaries.
- After `dispose()`, mutating or effectful public entrypoints fail fast with
  `StateError`.

## Transaction and signal model

- `SceneStoreController` is the thin public controller facade. It owns public
  lifecycle, exposes the committed store and streams, and delegates commit
  orchestration to the controller-private `SceneControllerCommitRuntime`
  instead of re-owning transaction assembly in `scene_store_controller.dart`. This
  split is pinned by `INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY`.
- `SceneControllerCommitRuntime` is the controller-private orchestration owner
  for transactional writes. It assembles `TxnContext`, `SceneWriter`,
  `MutationExecutor`, commit preparation, and post-commit publication without
  widening the public facade boundary.
- High-level methods such as `addNode`, `patchNode`, `clearScene`, and
  transform commands all route through the same transactional core.
- Scene-mutating runtime intents are modeled as internal `MutationOp` values
  and executed by `MutationExecutor`; `SceneWriteTxn` stays the public write
  seam, while `SceneStoreController` remains the owner of commit/store/signal
  lifecycle.
- Transaction finalization is controller-private and pre-commit-plan:
  `MutationExecutor` applies post-mutation selection finalization before
  control returns to the write callback, while
  `scene_controller_commit_plan.dart` remains read-only and derives phases and
  commit data only from already-finalized transaction state. This contract is
  pinned by `INV-ENG-TXN-FINALIZED-BEFORE-COMMIT-PLAN`.
- Private mutation execution ownership follows the typed mutation families in
  `mutation_op.dart`: structural and scene-setting mutations live in
  `scene_mutation_applier.dart`, node-local mutations live in
  `node_mutation_applier.dart`, and selection transform mutations live in
  `selection_transform_mutation_applier.dart`.
- The controller-private transaction substrate is split by owner:
  `TxnContext` remains the transaction root, while private workspace and
  derived-state owners live in `txn_workspace.dart` and
  `txn_derived_state.dart`; `SceneControllerCommitRuntime` consumes that
  substrate without reopening the public controller facade boundary.
- Public callers receive a dedicated `SceneWriteTxn` adapter that exposes only
  the supported write surface. `SceneWriter` remains the internal writer owner
  for command/runtime code and is a thin shell over writer-local controller
  modules:
  This contract is pinned by `INV-ENG-SCENE-WRITE-TXN-ADAPTER-BOUNDARY`.
  `scene_writer_nodes.dart`,
  `scene_writer_selection.dart`,
  `scene_writer_scene.dart`,
  `scene_writer_signals.dart`, and
  `scene_writer_command_results.dart`.
  `scene_writer_runtime.dart` owns the shared transaction runtime handle used
  by those modules, while committed-signal enqueue stays internal to
  `SceneWriter` / `scene_writer_signals.dart` instead of expanding the public
  `SceneWriteTxn` contract.
- Final measured controller closure baseline after steps 29-31 is:
  `6 HIGH` metric entries limited to accepted seams in
  `mutation_op.dart`,
  `scene_store_controller.dart`,
  `scene_controller_commit_runtime.dart`, and
  `scene_writer.dart`,
  plus `1` remaining clone pair between
  `draw_commands.dart::writeEraseNodes` and
  `scene_commands.dart::writeDeleteSelection`.
- Final measured interactive closure baseline after steps 32-34 is:
  `7 HIGH/VERY HIGH` metric entries and `5` remaining clone pairs across
  `lib/src/interactive`.
  No remaining `HIGH/VERY HIGH` entry belongs to
  `interactive_runtime.dart` or `interactive_draw_coordinator.dart`.
  The remaining metric hotspots are limited to:
  public facade breadth in `scene_controller.dart`,
  the focused eraser-local owner `interactive_draw_eraser_engine.dart`,
  and the focused action owner `interactive_draw_action_emitter.dart`.
  The remaining clone pairs are structural repeats in
  `interaction_eligibility_policy.dart`,
  `interactive_draw_eraser_engine.dart`,
  `interactive_move_hit_test_engine.dart`,
  `interactive_gesture_router.dart`,
  and constructor wiring between
  `interactive_draw_coordinator.dart` and `interactive_runtime.dart`;
  they are documented residuals rather than hidden debt and were not reduced
  with wrapper layers or ownership drift.
- Successful commits finalize store state before publishing signals or repaint
  notifications.
- Committed signals are emitted before repaint listener notification for the
  same successful commit.
- Buffered effects are discarded if a transaction fails.
- Runtime invariant enforcement is two-tiered:
  - critical commit checks run in all build modes;
  - the full committed-store sweep remains enabled in `debug` and `profile`.

## Serialization boundary

- Public JSON APIs accept `Map<String, dynamic>` or JSON strings.
- `decodeSceneFromJson(...)` rejects raw JSON strings longer than `33554432`
  characters before parser allocation.
- Decode/import canonicalizes missing `backgroundLayer` to an empty dedicated
  layer before returning a `SceneSnapshot`.
- Mutable runtime `Scene` keeps `backgroundLayer` nullable as an internal
  shape; local write paths materialize it on demand instead of maintaining a
  second canonical runtime model.
- Mutable runtime `Scene.palette` is a replaceable scene-level reference to an
  immutable `ScenePalette` value object. Palette constructor inputs are
  defensively copied into unmodifiable lists, so runtime palette state does
  not expose mutable nested list ownership after validation.
- Scene metadata now has one lower-layer contract across public constructors,
  runtime owners, and decode/import validation: camera offsets are finite and
  in range, grid sizes are finite positive bounded values, enabled grids
  require `cellSize >= 1.0`, and palette lists stay non-empty and bounded.
- Raw malformed scene metadata remains available only through explicit
  internal backing/materialization paths under `contract/internal/**`; ordinary
  public and runtime APIs do not expose raw invalid metadata containers.
- Decode/import and runtime replacement paths validate structure and numeric
  constraints and throw `SceneDataException` on malformed input.
- `contract/scene_structure_validation.dart` is the single owner for shared
  public scene-document structure rules: duplicate node ids, duplicate
  content-layer ids, and scene-wide node/layer limits are enforced there for
  both ordinary public `SceneSnapshot(...)` construction and model import.
- `ScenePolicy` remains the owner of import/runtime orchestration and
  scene-level numeric range enforcement; it consumes the shared structural
  validator instead of re-owning duplicate/count logic privately.
- `imageId` follows the same validated boundary-owner policy on decode/import,
  snapshot/spec/patch validation, and runtime scene validation.
- Encode/decode/build boundaries sanitize oversized `SceneDataException.source`
  payloads into compact previews and snapshot small structured payloads into
  immutable containers while preserving stable `code`, `path`, and immutable
  `details`; `message` is a derived user-facing rendering owned by
  `scene_data_exception.dart`.
- `scene_codec.dart` is a thin boundary adapter: string decode uses
  serialization-local guards, parsed-map decode delegates to the model-owned
  parsed-map guard, and snapshot/runtime encode entrypoints reuse the shared
  codec error factory instead of owning parallel transport mappings.
- JSON payload limits are enforced to keep import cost bounded.
- Guardrails cover both collection sizes (layers, nodes, points, palette item
  lists) and string lengths (for example node ids, layer ids, text/image ids,
  and path payloads).

## Performance model

- Transactions use copy-on-write: only touched scene parts are cloned.
- Hot-path node lookup uses committed indexes instead of repeated linear scans.
- Spatial queries use a bounded spatial index with a bounded fallback path for
  oversized queries.
- Render caches are owned by `SceneView` and reset on controller
  epoch/document changes.
- Stroke and path rendering use revision-based cache keys to avoid stale reuse
  after node-id reuse or geometry changes.
- Input and hit-testing guardrails cap worst-case work for long strokes and
  large queries.

## Non-goals

- Product-specific UI and workflows outside the canvas engine.
- Network synchronization or backend protocols.
- App-owned persistence and undo/redo history.
