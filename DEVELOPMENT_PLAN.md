# Development Plan

Objective: remove `lib/src/public/` as an internal architectural layer, replace
it with a single explicit low-level `contract/` layer for stable API
contracts and shared contract-facing value types, and make "public API" mean
only "exported from `lib/iwb_canvas_engine.dart`". Release target: `5.1.0` as
the next non-breaking minor; if the work uncovers an unavoidable external
contract break, split the breaking portion into a separate `6.0.0` wave
instead of weakening the design.

## Scope

- In: internal module reshaping, import graph cleanup, invariant/guardrail
  updates, test coverage updates, and documentation alignment required to make
  the new structure self-explanatory.
- Out: product-level features, new runtime capabilities, JSON schema changes,
  app-owned persistence, collaboration, and temporary long-lived compatibility
  shims that preserve the old `src/public/**` layer shape.
- Out: compatibility guarantees for unsupported `package:iwb_canvas_engine/src/**`
  imports outside this repository; repo-owned tests and tooling must migrate,
  but external consumers are supported only through `lib/iwb_canvas_engine.dart`.

## Success criteria

- [ ] The `lib/src/public/` directory no longer exists in the merged design.
- [ ] Stable API contracts live in a dedicated layer whose name matches its
      architectural role.
- [ ] The import DAG has no special-case rule that treats "public" as both a
      top layer and a shared dependency.
- [ ] `lib/iwb_canvas_engine.dart` preserves the intended external API surface
      unless an explicitly approved breaking change is split into a later wave.
- [ ] `ARCHITECTURE.md`, `API_GUIDE.md`, `README.md`, `CHANGELOG.md`, and the
      guardrail tools describe the same module model.

## Target ownership map

- [ ] Move `lib/src/public/canvas_pointer_input.dart` to
      `lib/src/contract/canvas_pointer_input.dart`.
- [ ] Move `lib/src/public/node_patch.dart` to
      `lib/src/contract/node_patch.dart`.
- [ ] Move `lib/src/public/node_spec.dart` to
      `lib/src/contract/node_spec.dart`.
- [ ] Move `lib/src/public/patch_field.dart` to
      `lib/src/contract/patch_field.dart`.
- [ ] Move `lib/src/public/scene_data_exception.dart` to
      `lib/src/contract/scene_data_exception.dart`.
- [ ] Move `lib/src/public/scene_render_state.dart` to
      `lib/src/contract/scene_render_state.dart`.
- [ ] Move `lib/src/public/scene_write_txn.dart` to
      `lib/src/contract/scene_write_txn.dart`.
- [ ] Move `lib/src/public/snapshot.dart` to `lib/src/contract/snapshot.dart`.
- [x] Move `lib/src/core/transform2d.dart` to `lib/src/contract/transform2d.dart`.
- [x] Split `PathFillRule` out of `lib/src/core/nodes.dart` into
      `lib/src/contract/path_fill_rule.dart`.
- [ ] Move the public `SceneBuilder` facade out of `public/` into
      `lib/src/model/scene_builder_api.dart`; keep the exported class name
      `SceneBuilder` stable even if internal helper files in `model/` are
      renamed to avoid collisions.

## Required architecture decisions

- [x] Treat `contract/` as the single low-level home for stable API data
      contracts; do not place runtime orchestration, stateful facades, or
      owner-specific adapters there. Ratified by `Phase 1` inventory and
      ownership mapping: stable contracts move into `contract/`, while
      `SceneBuilder` remains owned by `model/`.
- [x] Keep this wave strictly `contract/`-only. Do not introduce
      `lib/src/foundation/`; `Transform2D` and `PathFillRule` move into
      `contract/` as part of the supported contract language. Ratified by
      `Phase 1`: this wave adds no alternate low-level bucket and no new
      catch-all layer.
- [x] Keep existing public symbol names stable unless an explicit breaking
      change is separately approved; file moves are internal, export names are
      not. Ratified by the package export map: ownership changes may update
      source files, but exported symbol names stay unchanged.
- [x] Preserve package-level public access only through
      `lib/iwb_canvas_engine.dart`; do not add a new secondary public entrypoint
      to compensate for internal file moves. Ratified by `Phase 1`: package
      exports remain the single supported public API boundary.

## Phase 1: Freeze the target architecture and file ownership

- [x] Write an ADR-style note in `ARCHITECTURE.md` that defines the target
      import DAG, states that "public API" is determined by package exports only,
      and defines `contract/` as the stable low-level contract layer.
- [x] Inventory every file currently in `lib/src/public/` and classify it as one
      of: stable contract, low-level value type, or owner-specific facade, using
      the target ownership map above as the default unless code evidence forces
      a documented exception. Observed inventory: 9 files and no nested
      subdirectories. No exceptions found; current file inventory:
      - `canvas_pointer_input.dart` -> stable contract -> `contract/` -> pointer
        input enum/value object for API-facing controller input; depends only on
        SDK/UI primitives.
      - `node_patch.dart` -> stable contract -> `contract/` -> immutable patch
        request types; currently imports `Transform2D` and `PathFillRule` from
        `core/`, which Phase 2 must eliminate.
      - `node_spec.dart` -> stable contract -> `contract/` -> immutable node
        creation specs; currently imports `Transform2D` and `PathFillRule` from
        `core/`, which Phase 2 must eliminate.
      - `patch_field.dart` -> stable contract -> `contract/` -> tri-state patch
        wrapper used directly by the public write contract.
      - `scene_data_exception.dart` -> stable contract -> `contract/` -> stable
        error shape and error-code enum for import/build/serialization
        boundaries.
      - `scene_render_state.dart` -> stable contract -> `contract/` -> read-only
        painter-facing interface for snapshot/selection access.
      - `scene_write_txn.dart` -> stable contract -> `contract/` -> transactional
        write interface and clear-scene result; currently imports
        `Transform2D` from `core/`, which Phase 2 must eliminate.
      - `snapshot.dart` -> stable contract -> `contract/` -> immutable snapshot,
        ids, and related value shapes; currently imports `Transform2D` and
        re-exports `PathFillRule` from `core/`, which Phase 2 must eliminate.
      - `scene_builder.dart` -> owner-specific facade -> `model/` -> thin public
        facade over `model.sceneBuild*` canonicalization entrypoints; not a
        low-level contract because it imports and orchestrates model behavior.
      No file in `lib/src/public/` is best classified as a standalone low-level
      value type; that role is expected to be filled by the Phase 2 extraction
      of `Transform2D` and `PathFillRule` into `contract/`.
- [x] Inventory every symbol currently exported from
      `lib/iwb_canvas_engine.dart` and map each symbol to its long-term owning
      layer so that exports remain stable even if file locations change.
      Current package export map:
      - `contract/` ownership:
        `CanvasPointerPhase`, `CanvasPointerInput` ->
        `lib/src/contract/canvas_pointer_input.dart`;
        `CommonNodePatch`, `NodePatch`, `ImageNodePatch`,
        `TextNodePatch`, `StrokeNodePatch`, `LineNodePatch`,
        `RectNodePatch`, `PathNodePatch` ->
        `lib/src/contract/node_patch.dart`;
        `NodeSpec`, `ImageNodeSpec`, `TextNodeSpec`, `StrokeNodeSpec`,
        `LineNodeSpec`, `RectNodeSpec`, `PathNodeSpec` ->
        `lib/src/contract/node_spec.dart`;
        `PatchFieldState`, `PatchField` ->
        `lib/src/contract/patch_field.dart`;
        `SceneDataException`, `SceneDataErrorCode` ->
        `lib/src/contract/scene_data_exception.dart`;
        `SceneRenderState` ->
        `lib/src/contract/scene_render_state.dart`;
        `ClearSceneResult`, `SceneWriteTxn` ->
        `lib/src/contract/scene_write_txn.dart`;
        `NodeId`, `LayerId`, `SceneSnapshot`, `BackgroundLayerSnapshot`,
        `ContentLayerSnapshot`, `CameraSnapshot`, `BackgroundSnapshot`,
        `GridSnapshot`, `ScenePaletteSnapshot`, `NodeSnapshot`,
        `ImageNodeSnapshot`, `TextNodeSnapshot`, `StrokeNodeSnapshot`,
        `LineNodeSnapshot`, `RectNodeSnapshot`, `PathNodeSnapshot` ->
        `lib/src/contract/snapshot.dart`;
        `PathFillRule` -> `lib/src/contract/path_fill_rule.dart`
        (still re-exported as part of the public contract surface);
        `Transform2D` remains publicly exported but its long-term owner moves
        from `lib/src/core/transform2d.dart` to
        `lib/src/contract/transform2d.dart`.
      - `core/` ownership:
        `ActionType`, `ActionCommitted`, `ActionCommittedDelta`,
        `EditTextRequested` -> `lib/src/core/action_events.dart`;
        `CanvasMode`, `DrawTool` ->
        `lib/src/core/interaction_types.dart`;
        `PointerInputSettings` -> `lib/src/core/pointer_input.dart`.
      - `model/` ownership:
        `SceneBuilder` -> `lib/src/model/scene_builder_api.dart`.
      - `interactive/` ownership:
        `MoveCommitDeltaResolver`, `SceneControllerInteractive`,
        `SceneController` ->
        `lib/src/interactive/scene_controller_interactive.dart`.
      - `view/` ownership:
        `SceneViewInteractive`, `SceneView` ->
        `lib/src/view/scene_view_interactive.dart`.
      - `serialization/` ownership:
        `decodeSceneFromJson`, `decodeScene`, `encodeSceneToJson`,
        `encodeScene`, `schemaVersionWrite`, `schemaVersionsRead` ->
        `lib/src/serialization/scene_codec.dart`.
      No currently exported symbol is intended to keep `public/` as a
      long-term owner after the migration.
- [x] Confirm that `Transform2D` and `PathFillRule` can move into `contract/`
      without dragging runtime-only concerns with them; if they cannot, stop and
      record the blocking dependency before moving any files. Confirmation:
      `Transform2D` is a standalone affine value type whose current file depends
      only on SDK primitives plus `core/numeric_tolerance.dart`, and
      `PathFillRule` is a pure enum currently embedded in `core/nodes.dart`
      even though it is already part of the supported contract language through
      `snapshot.dart`, `node_spec.dart`, and `node_patch.dart`. No inspected
      dependency requires moving mutable scene nodes, controller logic, render
      logic, or serialization orchestration into `contract/`. The only blocking
      edge to remove before the move is `Transform2D`'s import of
      `core/numeric_tolerance.dart`. `PathFillRule` will move into
      `lib/src/contract/path_fill_rule.dart`, and `lib/src/core/nodes.dart`
      will become a consumer of both `contract/path_fill_rule.dart` and
      `contract/transform2d.dart` instead of owning either type.
- [x] Resolve `Transform2D`'s current dependency on `core/numeric_tolerance.dart`
      as part of the move by creating one shared contract-local helper file at
      `lib/src/contract/transform_tolerance.dart` and move only the 2x2
      near-singular criterion needed by contract-facing transform math there.
      Do not leave `contract/transform2d.dart` importing from `core/`. The
      future `contract/transform2d.dart` uses that helper, and
      `core/nodes.dart` uses the same helper after `core -> contract` imports
      are rewired, so the near-singular check keeps one source of truth after
      the migration. `contract/` must not import `core/numeric_tolerance.dart`
      and must not absorb unrelated UI-oriented helpers such as `kUiEpsilon`,
      `kUiEpsilonSquared`, or `nearZero` unless a later wave explicitly makes
      them part of contract-facing math.
- [x] Define non-goals for the wave: do not introduce a new "shared" junk
      drawer; every moved file must have a single, named ownership reason.
      Non-goals confirmed for this migration wave:
      - do not introduce `lib/src/shared/`, `lib/src/foundation/`, or any other
        new catch-all layer to avoid making ownership ambiguous again;
      - do not preserve `public/` semantics under a different folder name by
        creating a second mixed-responsibility bucket;
      - do not duplicate contract-facing types across `contract/` and `core/`;
        each moved symbol keeps exactly one owning source file;
      - do not broaden this wave into runtime behavior changes, serialization
        schema changes, or long-lived compatibility shims for old
        `src/public/**` imports.

## Phase 2: Establish the new low-level contract boundary

- [x] Create `lib/src/contract/` and move stable API contracts there:
      immutable snapshots, ids, specs, patches, write contracts, render-state
      contracts, and data-shape exceptions that are part of the supported API.
- [x] Split `PathFillRule` out of `core/nodes.dart` and move `Transform2D` out
      of `core/`; place both in `contract/`. Do not leave `contract/`
      depending on `core/` in the final state.
- [x] Remove `Transform2D`'s dependency on `core/numeric_tolerance.dart` during
      the move by keeping only the small numerical helper needed for inversion
      near the transform code, rather than widening `contract/` with unrelated
      core math helpers.
- [x] Keep `contract/` free of runtime orchestration dependencies: it may depend
      only on other `contract/` files and SDK/framework primitives that are
      already part of the supported API surface.
- [x] Replace cross-layer leakage where `core/` currently imports API contracts
      from `public/` by importing the new contract layer directly, with ids and
      immutable data shapes sourced from a single place.
- [x] Preserve one source of truth for ids and snapshot types during the move;
      do not duplicate typedefs or mirror contract classes across layers.

## Phase 3: Move facades to their real owners and delete the old layer

- [x] Move owner-specific facades out of the old `public/` bucket and into the
      layer that actually owns their behavior. `SceneBuilder` is owned by
      `model/` and should end in `lib/src/model/scene_builder_api.dart`, not in
      `contract/` and not in `serialization/`.
- [x] Update imports across `core/`, `model/`, `controller/`, `interactive/`,
      `render/`, `serialization/`, and `view/` to point at the new layer names
      and remove all direct references to `lib/src/public/**`.
- [x] Keep package exports stable by changing only export sources inside
      `lib/iwb_canvas_engine.dart`; the entrypoint remains the single supported
      public import path.
- [x] Remove `lib/src/public/` completely once all consumers compile against the
      new ownership model.
- [x] Avoid transitional alias files in `src/` as a steady state; if a short
      migration shim is temporarily needed inside the branch, delete it before
      merge so the final graph is unambiguous.

## Phase 4: Rebuild guardrails around the new graph

The Phase 4 guardrail follow-up is complete; the checklist below records the
closed structural guardrail work for the `contract/` migration.

- [x] Rename and reword `INV-G-CORE-NO-LAYER-DEPS` in
      `tool/invariant_registry.dart` so the invariant describes the actual DAG
      instead of implying a vague "higher layers" model.
- [x] Rewrite `tool/check_import_boundaries.dart` to encode the new explicit DAG
      (`contract -> none`, `core -> contract`, `model -> core + contract`, and
      so on), with no exceptional "core -> public" rule.
- [x] Add guardrail coverage that fails if `lib/src/public/` is reintroduced or
      if new files bypass the approved layer map.
- [x] Update every path-based tool and test that currently hardcodes
      `src/public/**`, including `tool/check_guardrails.dart`,
      `tool/check_coverage.dart`, and `test/tool/guardrails_tools_test.dart`,
      so guardrails enforce the new structure instead of the deleted one.
- [x] Keep the exported-owner file set in `tool/check_guardrails.dart`
      declarative and aligned with `lib/iwb_canvas_engine.dart`, so mutable-type
      leak coverage does not silently drift when the package export map changes.
- [x] Update any invariant coverage markers and supporting tests so
      `tool/check_invariant_coverage.dart` remains authoritative after the
      reorganization.
- [x] Review adjacent guardrails (`tool/check_guardrails.dart`,
      `tool/check_import_boundaries.dart`, related tests) to ensure naming and
      diagnostics now teach the same architecture a new contributor should infer.

## Phase 5: Lock behavior, docs, and release hygiene

- [ ] Add or update tests that prove the public package import still exposes the
      same supported symbols and that runtime behavior remains unchanged after
      the internal move.
- [ ] Add focused tests for edge cases introduced by the move, especially
      contract/value types that changed ownership and any tools that scan paths
      by directory name.
- [ ] Migrate repo-owned tests that import `package:iwb_canvas_engine/src/public/**`
      to the new internal paths or to `package:iwb_canvas_engine/iwb_canvas_engine.dart`
      where package-level coverage is the real intent; do not preserve old
      unsupported `src/public/**` imports as a compatibility contract.
- [ ] Rename test buckets whose directory names encode the deleted layer
      (for example `test/public/`) if they would otherwise preserve stale
      architecture terminology after the migration.
- [ ] Update `ARCHITECTURE.md` module layout, state-ownership language, and
      layer descriptions so the document no longer references `public/` as an
      internal layer.
- [ ] Update `API_GUIDE.md` and `README.md` only where wording about internal
      ownership or package boundaries changed; keep user-facing API guidance
      stable unless an approved behavior change is intentional.
- [ ] Add a `CHANGELOG.md` entry under `## Unreleased` summarizing the internal
      architectural cleanup and any public-facing clarifications or migration
      notes.

## Validation gates

  Run `dart format --output=none --set-exit-if-changed lib test example/lib tool`.
- Run `flutter analyze`.
- Run `flutter test`.
- Run `flutter test --coverage`.
- Run `dart run tool/check_coverage.dart`.
- Run `dart run tool/check_invariant_coverage.dart`.
- Run `dart run tool/check_guardrails.dart`.
- Run `dart run tool/check_import_boundaries.dart`.
- Run `dart doc` before the release cut if exported symbol ownership or docs
      moved.
- Run `dart pub publish --dry-run` before publishing the release candidate.

## Sequencing notes

- [ ] Land the wave in reviewable slices: first architecture decision and
      guardrail direction, then contract extraction, then consumer rewiring,
      then documentation and release hygiene.
- [ ] Keep each slice buildable and guarded; do not mix speculative renames with
      behavior changes in the same patch unless required to preserve a single
      source of truth.
- [ ] Treat any newly discovered external API break as a hard stop for the
      `5.1.0` target and split it into an explicitly approved follow-up plan.
