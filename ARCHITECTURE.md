# Architecture Overview

This document describes the current checked-in architecture of
`iwb_canvas_engine` using only repository-backed facts: public exports,
current source layout, executable interfaces, and repository-local
enforcement.

## System boundary

- Supported public entrypoint:
  `package:iwb_canvas_engine/iwb_canvas_engine.dart`
- Supported public surface:
  exactly the symbols exported from `lib/iwb_canvas_engine.dart`
- Current JSON contract:
  write `schemaVersion = 7`, read `{7}`
- Public interactive runtime root:
  `SceneController`
- Public interactive widget:
  `SceneView` / `SceneViewInteractive`
- Public non-controller import boundary:
  `SceneBuilder`
- Public write boundary:
  `SceneWriteTxn`

The package owns scene modeling, rendering, input handling, and JSON
serialization. It does not own app UI, persistence, sync, backend logic, or
product workflows.

## Public surface

`lib/iwb_canvas_engine.dart` currently exports:

- contract types for snapshots, specs, patches, patch fields, transforms,
  pointer input, validated values, render-state reads, and transactional
  writes
- `SceneBuilder`
- `SceneController`, `SceneControllerInteraction`,
  `SceneControllerSelection`, and `SceneControllerScene`
- `SceneView` / `SceneViewInteractive`
- scene JSON codec entrypoints:
  `decodeScene`, `decodeSceneFromJson`, `encodeScene`, `encodeSceneToJson`,
  `schemaVersionWrite`, and `schemaVersionsRead`
- action event types:
  `ActionCommitted`, `ActionCommittedDelta`, `ActionType`,
  and `EditTextRequested`

Imports from `package:iwb_canvas_engine/src/**` are internal package details,
not a supported integration contract.

## Repository layout

Current repository layout:

```text
lib/
  iwb_canvas_engine.dart          // public exports for the package API
  src/
    contract/                     // snapshot/spec/patch, pointer, transform, render-state contracts
      internal/                   // non-exported contract helpers used from src/**
      validated/                  // validated value types re-exported via validated.dart
    controller/                   // SceneStoreController, commit runtime, scene writer, mutation appliers
      commands/                   // draw/move/scene command entrypoints
      internal/                   // controller support files not exported from the package barrel
    core/                         // Scene, SceneNode, geometry, hit-test, spatial index, text layout
    interactive/                  // SceneController and public capability-owner surfaces
      internal/                   // interactive runtime, gesture, draw, selection, pointer-session files
    model/                        // SceneBuilder, document mutations, import draft, snapshot mapping
    render/                       // ScenePainter and render pipeline owners
      cache/                      // scene text/path/static-layer cache files
    serialization/                // scene_codec.dart and codec guards
    view/                         // SceneViewInteractive, runtime host, render surface, pointer host/router
```

Repository tooling layout relevant to enforcement and verification:

```text
tool/
  analysis/                       // analysis scripts such as find_similar_clones.dart
    src/                          // support files for tool/analysis/**
  bench/                          // benchmark runners, policies, baselines, and benchmark tests
    baselines/                    // checked-in benchmark baseline JSON
  check_coverage.dart             // coverage checker entrypoint
  check_guardrails.dart           // guardrail runner entrypoint
  check_import_boundaries.dart    // import-boundary checker entrypoint
  check_invariant_coverage.dart   // invariant coverage checker entrypoint
  check_public_api_surface.dart   // public API surface checker entrypoint
  check_verification_contract.dart // AGENTS/CI verification contract checker entrypoint
  goldens/                        // golden files used by tool checks
  invariant_registry.dart         // invariant registry consumed by tooling
  run_temp_pkg_test.dart          // temporary package test runner entrypoint
  run_tool_tests.dart             // tool test runner entrypoint
  run_verification_preset.dart    // verification preset resolve/run entrypoint
  src/
    check_coverage/               // coverage parser/report support
    guardrails/                   // guardrail runner implementation
      core/                       // shared guardrail infrastructure
      rules/                      // guardrail rule sets
      support/                    // guardrail support code
    import_boundaries/            // import-boundary implementation
    temp_pkg_test/                // temp package runner support
    verification_contract/        // verification registry, resolver, runner, report models
  windows/                        // Windows installer script for the example app
```

## Runtime components

The current runtime boundary is split across these checked-in interfaces and
implementations:

- `SceneController` is the public interactive facade.
  It owns a `SceneStoreController`, exposes `snapshot`, `selectedNodeIds`,
  `controllerEpoch`, capability owners (`interaction`, `selection`, `scene`),
  and host-facing streams (`actions`, `editTextRequests`).
- `SceneStoreController` implements `SceneRenderState`.
  It owns the committed store, transactional writes, committed snapshot
  materialization, committed selected ids, and committed spatial query helpers
  such as `queryHitTestCandidates(...)`, `queryPaintCandidates(...)`,
  `resolveSpatialCandidateSnapshot(...)`, and `resolveSnapshotNodeById(...)`.
- `SceneViewRuntime` is the view/runtime seam.
  It exposes a `SceneViewRenderState` plus `createPointerSession(...)`.
- `SceneViewRenderState` extends `SceneRenderState`.
  It exposes `captureFrameRead()`, `preparePaintPlan(...)`,
  overlay repaint listenable, selection rectangle, preview delta reads, and
  active line/stroke preview reads.
- `SceneControllerSceneViewRuntime` is the checked-in bridge from
  `SceneController` to `SceneViewRuntime`.
  Its render-state implementation is
  `SceneControllerSceneViewRenderState`.
- `ScenePainter` is the scene painter.
  It is a `CustomPainter` that repaints from a `SceneViewRenderState` and
  paints from one captured `SceneViewFrameRead`.
- `SceneBuilder` is the checked-in non-controller import boundary.
  It exposes `buildFromSnapshot(...)` and `buildFromJson(...)`.
- `scene_codec.dart` is the checked-in public JSON boundary.
  It exposes `decodeScene`, `decodeSceneFromJson`, `encodeScene`,
  `encodeSceneToJson`, plus internal document codec helpers that are not
  exported from the package barrel.

## Runtime flow

The checked-in runtime flow is:

1. `SceneViewInteractive` adapts a `SceneController` into a
   `SceneViewRuntimeHost` by calling `sceneControllerViewRuntimeOf(controller)`.
2. `SceneViewRuntimeHost` owns the mounted runtime instance, installs a
   `SceneViewPointerSession`, routes raw Flutter pointer events through
   `SceneViewInteractivePointerHost`, and renders:
   - `SceneViewInteractiveOverlayPainter` as `foregroundPainter`
   - `SceneViewRenderSurface` as the scene paint surface
3. `SceneViewRenderSurface` consumes `SceneViewRenderState`.
   `ScenePainter` also consumes `SceneViewRenderState`.
4. `SceneControllerSceneViewRenderState.captureFrameRead()` captures one atomic
   `SceneViewFrameRead` containing:
   - `snapshot`
   - `selectedNodeIds`
   - `selectionRevision`
   - `previewDeltaResolver`
5. `SceneControllerSceneViewRenderState.preparePaintPlan(...)` chooses between:
   - committed candidate staging from `SceneStoreController` when the captured
     frame snapshot is identical to the committed store snapshot
   - snapshot-local candidate enumeration when the captured frame snapshot is
     not identical to the committed store snapshot
6. `ScenePainter` paints from the captured frame read and the prepared paint
   plan. It does not read a second snapshot for the same frame.

## Serialization and import boundaries

Current checked-in boundaries are:

- `SceneBuilder.buildFromSnapshot(...)`:
  typed snapshot validation and canonicalization
- `SceneBuilder.buildFromJson(...)`:
  parsed-map validation and canonicalization
- `decodeSceneFromJson(...)`:
  string JSON boundary
- `decodeScene(...)`:
  parsed-map decode boundary
- `encodeScene(...)`:
  snapshot-to-map boundary
- `encodeSceneToJson(...)`:
  snapshot-to-string boundary

`scene_codec.dart` also contains `encodeSceneDocument(...)` and
`decodeSceneDocument(...)`, but those functions are internal to `src/**` and
are not exported from the supported package entrypoint.

## Enforced architectural rules

The repository contains mechanical enforcement for important architectural
constraints:

- `tool/check_public_api_surface.dart`
  checks the exported symbol set of `lib/iwb_canvas_engine.dart` against
  `tool/goldens/public_api_symbols.txt`
- `tool/check_import_boundaries.dart`
  enforces import-boundary and layer-boundary rules
- `tool/check_guardrails.dart`
  enforces structural guardrails, including public-surface hermeticity,
  controller/read-write boundaries, interactive boundaries, model architecture,
  contract architecture, and committed read-side restrictions
- `tool/check_invariant_coverage.dart`
  checks invariant registry coverage against declared proof surfaces
- `tool/check_verification_contract.dart`
  checks that `AGENTS.md` and CI stay aligned with the verification registry

Canonical invariant ids live in `tool/invariant_registry.dart`.

## Stable facts worth preserving

These points are directly backed by code or repository-local enforcement:

- the package has one supported public entrypoint:
  `lib/iwb_canvas_engine.dart`
- `SceneStoreController` is consumable as `SceneRenderState`, not as the full
  `SceneViewRenderState` view contract
- full view render-state assembly happens on the controller-owned view runtime
  path, not on the committed store facade
- `SceneViewFrameRead` is the frame snapshot carrier consumed by the scene
  paint pipeline
- `SceneWriteTxn` is the public write seam; the writer/runtime implementation
  stays internal under `controller/**`
- `SceneViewRuntime` and `SceneViewPointerSession` are explicit seams between
  the Flutter view host and the controller-owned interactive runtime
- public JSON APIs are exported only from `scene_codec.dart`; internal document
  codec helpers remain under `src/**`

## Verification

For code changes, the repository-local source of truth is
`tool/run_verification_preset.dart` together with:

- `tool/src/verification_contract/verification_contract_registry.dart`
- `AGENTS.md`
- `.github/workflows/ci.yaml`

Documentation-only changes do not automatically imply that the full Flutter
pipeline is needed; use the repository-local verification contract in
`AGENTS.md`.
