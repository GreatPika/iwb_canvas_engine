# Change Contract

## Goal

Overlay-only interactions must capture a compact overlay frame instead of reusing
main-frame snapshot capture, while preserving visible overlay preview behavior,
public preview/runtime DTO compatibility, frame-owned planning boundaries, and
the no-live-runtime-read painter boundary.

## Source Inputs

- Design: `.design/2026-06-10-overlay-frame-capture.md`
- Research: `.research/2026-06-10-overlay-frame-capture.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `docs/README.md`; `docs/contracts/frame_rendering.md`; `docs/architecture/01_runtime_ownership.md`; `docs/architecture/architecture_graph.yaml`; `docs/diagrams/dfd_overlay_frame.mmd`; `docs/diagrams/seq_overlay_paint.mmd`; current frame/runtime/surface/test files cited in Evidence

## Classification

Profile: BEHAVIOR_CHANGE

Obligations: BUG_FIX; SEAM_MIGRATION

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1`: Overlay capture must be compact and must not call the shared full `_captureSnapshot` path. | `Boundaries.Owner`; `Boundaries.In Scope`; `Boundaries.Order Constraints` | Unit 2; compact overlay read-counter proof that overlay capture avoids selection, spatial, background, element-row, descriptor, and committed revision reads while main capture still reads full facts |
| `D2`: `FrameCaptureService` remains one-time overlay capture owner, and `OverlayPreviewPlanner` remains variant admission owner. | `Boundaries.Owner`; `Boundaries.Out of Scope`; `Boundaries.Order Constraints` | Units 2 and 3; planner/painter import and dependency proof showing no runtime/store/selection/spatial/resource ownership is added |
| `D3`: Compact `CapturedOverlayFrame` must carry captured overlay viewport/effective bounds, preview revision, view camera revision, view camera offset, overlay preview payload, and selection style. | `Boundaries.Source of Truth`; `Boundaries.In Scope`; `Boundaries.Compatibility` | Units 1, 2, and 3; model assertions plus overlay painter translation proof and marquee captured-style proof |
| `D4`: Runtime must pass existing camera revision into frame capture without changing public runtime DTO shapes. | `Boundaries.Compatibility`; `Boundaries.Order Constraints` | Unit 2; runtime/frame input test for captured `viewCameraRevision`; public API analyzer compatibility and no public DTO field-shape change |
| `D5`: Public preview variant behavior remains unchanged: selected move is excluded from overlay, overlay variants still build immutable primitives, and marquee keeps captured style. | `Boundaries.Compatibility`; `Boundaries.Out of Scope` | Unit 3; migrated overlay preview admission fixture and marquee captured style fixture |
| `D6`: Source-of-truth repair is mandatory because durable docs describe compact overlay capture but omit the viewport fact needed by painter output. | `Boundaries.Source of Truth`; `Boundaries.Order Constraints` | Unit 1; documentation checks and architecture graph checks for updated contract/diagram sources |
| `D7`: Ordinary/main frame capture and ordinary cache behavior must not be changed to achieve overlay efficiency. | `Boundaries.Out of Scope`; `Boundaries.Compatibility` | Units 2 and 4; main-capture read proof and ordinary camera-pan cache non-regression proof |

## Evidence

- `.design/2026-06-10-overlay-frame-capture.md:13` / design readiness: design is `READY_FOR_CONTRACT` -> implementation planning may proceed without an architecture blocker.
- `.design/2026-06-10-overlay-frame-capture.md:17` / product outcome: overlay interactions should capture only viewport/camera, preview revision/payload, and captured selection style while preserving visible previews and public DTO shapes -> contract scope must target compact capture, not preview behavior redesign.
- `.design/2026-06-10-overlay-frame-capture.md:21` / classification: design requires BEHAVIOR_CHANGE with BUG_FIX and SEAM_MIGRATION obligations -> classification is locked for this contract.
- `.design/2026-06-10-overlay-frame-capture.md:263` / handoff: design requires preserving decision rows D1 through D7 -> decision trace must map each design decision into units and proof surfaces.
- `.design/2026-06-10-overlay-frame-capture.md:265` / sequencing: design requires source-of-truth repair, compact model/capture migration before consumers, main-capture preservation, no public DTO change, no overlay cache, no runtime/surface primitive builder, and retirement of overlay access to `CapturedFrameSnapshot` -> order and exclusions are mandatory.
- `.research/2026-06-10-overlay-frame-capture.md:13` / research summary: contract already describes compact overlay fields while code stores `CapturedFrameSnapshot` plus nullable overlay preview -> root defect is contract/code drift at the overlay captured-frame shape.
- `.research/2026-06-10-overlay-frame-capture.md:15` / research summary: production overlay path runs through runtime bridge, `RuntimeRoot`, `FrameEngine`, `FrameCaptureService`, `OverlayPreviewPlanner`, and `OverlayFramePainter`; overlay capture uses the shared `_captureSnapshot` path -> fix belongs in frame capture and consumers, not in the painter alone.
- `.research/2026-06-10-overlay-frame-capture.md:17` / research summary: current tests expect duplicate main and overlay reads of revisions, background, handles, elements, descriptors, selection facts, and spatial queries -> test proof must be rewritten to assert reduced overlay read surface directly.
- `docs/contracts/frame_rendering.md:85` / frame contract: overlay frame is listed separately from main frame -> source of truth supports an overlay-specific captured model.
- `docs/contracts/frame_rendering.md:88` / frame contract: overlay frame fields are preview revision, view camera revision, view camera offset, preview state, and selection style -> compact model must include these fields and add the design-required viewport/effective-bounds clarification.
- `docs/contracts/frame_rendering.md:96` / preview routing: selected move is main-scene only, while marquee, pencil, marker, pending line, line, and eraser previews are overlay-admitted -> migration must preserve preview variant semantics.
- `docs/contracts/frame_rendering.md:107` / frame rule: main and overlay paint each capture their frame once -> compact overlay capture must remain one boundary call, not repeated planner or painter reads.
- `docs/contracts/frame_rendering.md:118` / painter rule: painters do not live-read runtime -> viewport, camera, preview, and style facts must be carried in immutable captured output.
- `docs/contracts/frame_rendering.md:128` / camera rule: view camera changes repaint affected frame surfaces and must not invalidate ordinary committed element paint plans -> `viewCameraRevision` may enter overlay output without ordinary cache identity drift.
- `docs/contracts/frame_rendering.md:154` / ownership table: `FrameCaptureService` owns one-time main/overlay capture and must not own planning or cache mutation -> compact capture belongs in `FrameCaptureService`.
- `docs/contracts/frame_rendering.md:160` / ownership table: `OverlayPreviewPlanner` owns immutable overlay primitives from `CapturedOverlayFrame` and excludes selected move, resource reads, cache invalidation, and repaint scheduling -> planner may adapt to compact frame fields but must not gain runtime/store/resource seams.
- `docs/contracts/frame_rendering.md:175` / overlay primitive contract: overlay primitives are admitted from `CapturedOverlayFrame`, and marquee carries captured style values -> captured style must move off `snapshot.inputs` without becoming live style.
- `docs/contracts/frame_rendering.md:242` / ordinary paint algorithm: spatial candidate reads belong to committed-frame ordinary paint planning -> overlay capture must exclude spatial paint queries.
- `docs/contracts/frame_rendering.md:250` / ordinary cache contract: ordinary cache keys and records must exclude view camera, preview, selection, and style-only inputs -> overlay efficiency must not change ordinary cache identity.
- `docs/architecture/01_runtime_ownership.md:142` / ownership docs: `FrameEngine` remains orchestration facade over seven frame-private collaborators -> no new top-level overlay owner is needed.
- `docs/architecture/01_runtime_ownership.md:155` / ownership table: `FrameCaptureService` owns capture into `CapturedMainFrame` and `CapturedOverlayFrame` -> model split remains under existing frame owner.
- `docs/architecture/01_runtime_ownership.md:161` / ownership table: `OverlayPreviewPlanner` owns overlay primitive admission and excludes selected move, resource reads, cache invalidation, and repaint scheduling -> planner migration is consumer adaptation only.
- `docs/architecture/01_runtime_ownership.md:163` / state ownership: committed document facts stay store-owned, selection facts stay selection-owned, preview and view-camera facts stay runtime/interaction-owned and are captured at frame boundaries -> compact overlay frame is transient captured output, not duplicate durable state.
- `docs/architecture/architecture_graph.yaml:270` / graph owner: `frame.renderer` is the required frame owner -> contract must keep implementation under existing frame ownership.
- `docs/architecture/architecture_graph.yaml:278` / graph evidence: `FrameEngine` owns frame capture, overlay planning, immutable output, repaint signals, and cache orchestration -> frame-local migration is the architecture-compatible path.
- `docs/diagrams/dfd_overlay_frame.mmd:21` / overlay data flow: diagram names `FrameCaptureService` as overlay capture and single runtime read boundary -> diagram must continue to show one capture boundary after compact migration.
- `docs/diagrams/dfd_overlay_frame.mmd:22` / overlay data flow: diagram lists compact overlay fields but not viewport/effective bounds -> diagram must be repaired to include the painter-required viewport fact.
- `docs/diagrams/seq_overlay_paint.mmd:16` / overlay sequence: current sequence captures overlay frame once -> implementation order must preserve single capture before planning.
- `docs/diagrams/seq_overlay_paint.mmd:23` / overlay sequence: sequence note freezes preview/camera/style but omits viewport/effective bounds -> sequence must be updated with the compact field list used by code.
- `lib/src/frame/captured_frame.dart:35` / current model: `CapturedFrameSnapshot` owns revisions, handles, resolved element facts, descriptors, background, selection, inputs, spatial result, and candidates -> this shape is broader than overlay preview output requires.
- `lib/src/frame/captured_frame.dart:90` / current model: `CapturedOverlayFrame` currently begins as a wrapper around a shared snapshot and overlay preview -> model migration is required at the owning frame model.
- `lib/src/frame/captured_frame.dart:96` / current model: `CapturedOverlayFrame` stores `CapturedFrameSnapshot` -> retirement gate must remove overlay production/test access to `CapturedOverlayFrame.snapshot`.
- `lib/src/frame/frame_capture_service.dart:40` / capture owner: `captureOverlayFrame` currently starts by calling shared snapshot capture -> root-cause fix is to replace this with compact overlay capture.
- `lib/src/frame/frame_capture_service.dart:52` / shared capture path: `_captureSnapshot` reads frame revisions, selection facts, spatial query, resolved element rows, resource descriptors, and background -> overlay capture must not call this path.
- `lib/src/frame/frame_engine.dart:152` / orchestration: `FrameEngine.buildResourceFreeOverlayFrame` captures overlay frame then builds an overlay plan -> orchestration order remains capture, then plan, then output.
- `lib/src/frame/overlay_preview_planner.dart:99` / planner consumer: `OverlayPreviewPlanner.build` consumes `CapturedOverlayFrame` -> planner must consume compact frame fields rather than runtime dependencies.
- `lib/src/frame/overlay_preview_planner.dart:146` / style read: marquee primitive reads selection style through `frame.snapshot.inputs.selectionStyle` -> compact frame must expose captured selection style directly.
- `lib/src/surface/overlay_painter.dart:16` / painter consumer: overlay painter reads effective world bounds through `output.capturedFrame.snapshot.inputs` -> compact output must carry viewport/effective bounds so painter remains immutable-output-only.
- `lib/src/runtime/runtime_root.dart:413` / runtime boundary: runtime exposes resource-free overlay frame build from viewport, DPR, selection style, and grid style -> camera revision can be added to frame inputs at this boundary without exposing runtime to frame collaborators.
- `lib/src/runtime/runtime_root.dart:435` / input construction: runtime creates `FrameCaptureInputs` with viewport, DPR, selection style, grid style, preview, preview revision, camera offset, and text edit suppression -> implementation may split common inputs or add overlay-specific fields here.
- `lib/src/runtime/runtime_root.dart:1214` / camera revision source: runtime increments `_viewCameraRevision` when camera offset changes -> existing revision source must feed compact overlay output.
- `lib/src/contracts/public/canvas_runtime.dart:60` / public API: `CanvasRuntimeRevisions` already includes `viewCamera` and preview revisions -> no public DTO shape change is required for overlay capture.
- `lib/src/surface/canvas_surface_widget.dart:187` / surface flow: surface builds main frame output before overlay output for the same paint host -> main and overlay capture remain independent calls, with only overlay read surface reduced.
- `lib/src/surface/canvas_surface_widget.dart:200` / surface flow: surface calls `buildSurfaceOverlayFrame` with viewport and styles used by the paint host -> compact overlay viewport/style facts should come from existing surface/runtime boundary values.
- `test/frame/fixtures/main_overlay_capture_fixture.dart:118` / current proof: fixture currently expects duplicate main and overlay frame revision/background/element/resource/selection/spatial reads -> fixture must become direct negative proof for overlay read elimination.
- `test/frame/fixtures/overlay_preview_admission_fixture.dart:46` / current proof: fixture builds primitives from captured overlay frames for every overlay variant -> preserve variant admission proof after compact frame helper migration.
- `test/frame/fixtures/marquee_captured_style_fixture.dart:18` / current proof: fixture expects marquee primitive style to match captured selection style -> preserve captured-style proof after removing snapshot dependency.
- `test/frame/fixtures/ordinary_paint_test_support.dart:66` / helper seam: shared helper constructs captured overlay frames through `FrameCaptureService.captureOverlayFrame` -> helper must migrate to compact frame construction without adding fixture-only production concepts.

## Boundaries

Owner: `FrameEngine` remains the frame orchestration facade; `FrameCaptureService` owns compact one-time overlay capture; `OverlayPreviewPlanner` owns overlay preview variant admission; runtime/surface only supply existing value inputs and the existing camera revision; painters remain immutable-output consumers.

In Scope:

- Update the frame-rendering contract and overlay data-flow/sequence diagrams so `CapturedOverlayFrame` is explicitly compact and includes viewport/effective bounds, preview revision, view camera revision, view camera offset, overlay preview state, and captured selection style.
- Replace overlay dependence on `CapturedFrameSnapshot` with a compact `CapturedOverlayFrame` model.
- Change overlay capture so it does not call `_captureSnapshot` and does not read committed-scene, selection, spatial, background, element-row, or resource descriptor facts.
- Carry the existing `_viewCameraRevision` through frame capture into overlay output without changing public DTO shapes.
- Migrate planner, output, painter, and test helpers from `CapturedOverlayFrame.snapshot` to compact overlay fields.
- Update focused tests and fixture read counters to prove the reduced overlay read surface and unchanged preview behavior.

Out of Scope:

- Public preview DTO shape changes, public runtime revision DTO changes, public surface API redesign, or package API registry changes.
- Replacing `FrameEngine`, `FrameCaptureService`, or `OverlayPreviewPlanner` as owning seams.
- Moving overlay primitive construction into runtime, surface, or painter code.
- Introducing an overlay cache, shared mutable state between main and overlay capture, or synchronization glue to coalesce the two capture calls.
- Changing ordinary/main frame capture behavior, ordinary cache key identity, selected-move supplement behavior, resource resolution, static background planning, or committed record planning except where tests must assert non-regression.

Source of Truth: `docs/contracts/frame_rendering.md` owns the durable overlay-frame contract; `docs/diagrams/dfd_overlay_frame.mmd` and `docs/diagrams/seq_overlay_paint.mmd` own durable overlay data-flow and sequence views; `CapturedOverlayFrame` implements that frame contract as transient captured output. Runtime remains source of truth for preview/camera state before capture, store/selection/resource/spatial seams remain source of truth for main-frame committed facts, and no second durable overlay state source is introduced.

Compatibility: Public preview variants and public runtime DTOs must remain source-compatible. `CanvasSelectedMovePreview` remains excluded from overlay primitives and stays on the main-scene supplement path. Existing overlay variants must produce the same primitive kinds and fields. Main-frame snapshot capture and ordinary paint cache identity must remain compatible with existing camera-pan cache behavior.

Order Constraints:

1. Update durable contract and overlay diagrams before or in the same change as code that makes them true.
2. Establish compact overlay model fields and runtime/frame input flow, including `viewCameraRevision`, before migrating planner/painter consumers.
3. Change `FrameCaptureService.captureOverlayFrame` to compact capture before removing consumer access to `CapturedOverlayFrame.snapshot`.
4. Migrate `OverlayPreviewPlanner`, `OverlayFramePaintOutput`, `OverlayFramePainter`, and test helpers to compact fields after the compact model exists.
5. Retire overlay production and test access to `CapturedOverlayFrame.snapshot` only after all consumers compile against compact fields.
6. Update focused tests and verification commands after behavior, source-of-truth, and consumer migrations are complete.

## Execution Units

### [x] Unit 1: Repair Overlay Frame Source Of Truth

Owner: frame rendering documentation and registered overlay diagrams.

Boundary: `docs/contracts/frame_rendering.md`, `docs/diagrams/dfd_overlay_frame.mmd`, `docs/diagrams/seq_overlay_paint.mmd`, and generated documentation/index output only if repository tooling updates it from those sources.

Change: Clarify that `CapturedOverlayFrame` is compact overlay output containing viewport/effective bounds, preview revision, view camera revision, view camera offset, overlay preview state, and captured selection style. Preserve one overlay capture boundary, selected-move exclusion, no-live-runtime-read painter policy, and frame-owned planner/capture responsibilities. Remove any implication that overlay capture reads committed document, spatial, selection, background, element-row, or resource descriptor facts.

Completion Check: `dart run docs/tool/sync_generated_docs.dart --check`, `dart run docs/tool/check_docs.dart`, `dart run tool/architecture_graph/check.dart`, and `dart run tool/architecture_graph/generate_views.dart --check` pass after the docs/diagram update. A reviewer can inspect `docs/contracts/frame_rendering.md`, `docs/diagrams/dfd_overlay_frame.mmd`, and `docs/diagrams/seq_overlay_paint.mmd` and find the same compact field list and one-capture ordering that Units 2 and 3 implement. This proves the direct source-of-truth alignment claim; docs commands alone are not sufficient without the named field/order inspection.

Depends On: none.

### [x] Unit 2: Introduce Compact Overlay Capture

Owner: `FrameCaptureService` and captured-frame model under `lib/src/frame/**`, with runtime/frame value input flow where required for camera revision.

Boundary: `lib/src/frame/captured_frame.dart`, `lib/src/frame/frame_capture_service.dart`, `lib/src/frame/frame_engine.dart`, `lib/src/runtime/runtime_root.dart`, and any frame-private input type or helper needed to keep the compact model cohesive.

Change: Replace `CapturedOverlayFrame` snapshot reuse with compact immutable fields for effective viewport or viewport bounds, preview revision, view camera revision, view camera offset, normalized overlay preview payload, and captured selection style. Make `captureOverlayFrame` build that compact frame without calling `_captureSnapshot`; it must normalize `CanvasNoPreview` and `CanvasSelectedMovePreview` to empty overlay output and must not read selection facts, spatial paint query, background, element handles, element rows, resource descriptors, or committed frame revisions. Carry existing runtime camera revision into the compact overlay frame without public DTO changes.

Completion Check: A focused frame capture fixture proves main capture still reads full committed facts while overlay capture reads only compact overlay value inputs: overlay capture produces zero selection-facts reads, zero spatial query calls, zero background reads, zero element handle/row/descriptor reads, and no `_captureSnapshot`-only committed-scene read counters. The same fixture asserts compact overlay fields equal the captured viewport/effective bounds, preview revision, view camera revision, view camera offset, normalized overlay preview, and selection style. A targeted repository search for `captureOverlayFrame` and `_captureSnapshot` shows overlay capture no longer calls the shared snapshot path. This proves the direct read-surface and field-capture claims; object construction or compile success alone is not enough.

Depends On: Unit 1.

### [x] Unit 3: Migrate Overlay Consumers To Compact Fields

Owner: overlay planner/output/painter consumers under frame and surface rendering.

Boundary: `lib/src/frame/overlay_preview_planner.dart`, `lib/src/frame/frame_paint_output.dart`, `lib/src/surface/overlay_painter.dart`, frame test helpers that construct `CapturedOverlayFrame`, and any directly coupled frame tests.

Change: Update overlay preview admission, overlay paint output, and overlay painter translation to consume compact `CapturedOverlayFrame` fields instead of `CapturedOverlayFrame.snapshot`. Preserve selected-move exclusion, overlay primitive variant mapping, marquee captured style, repaint signal semantics, and immutable painter input. Do not add runtime, store, selection, spatial, resource, resolver, or document dependencies to planner or painter code.

Completion Check: Overlay preview admission tests still assert marquee, pencil stroke, marker stroke, pending line start, line preview, and eraser primitive kinds; selected move and no-preview cases still produce empty overlay primitives; marquee captured-style tests assert primitive color, stroke width, and fill opacity come from the compact frame's captured style; overlay painter tests or focused surface/frame assertions prove translation uses compact captured viewport/effective bounds from `OverlayFramePaintOutput`. A targeted import/search proof over all in-scope Unit 3 consumers, including `lib/src/frame/overlay_preview_planner.dart`, `lib/src/frame/frame_paint_output.dart`, `lib/src/surface/overlay_painter.dart`, frame/surface overlay helpers, and directly coupled tests, shows no runtime/store/selection/spatial/resource/resolver/document dependencies and no `CapturedOverlayFrame.snapshot` access remains in overlay production or test consumers. This proves the direct behavior and boundary claims rather than only proving code compiles.

Depends On: Unit 2.

### [x] Unit 4: Prove Compatibility And Regression Boundaries

Owner: focused frame/runtime/surface tests and verification surfaces.

Boundary: frame capture tests, overlay preview admission tests, marquee style tests, camera revision tests, ordinary camera-pan cache tests, and repository-local static analysis for changed code owners.

Change: Update or add tests so the behavior contract is mechanically enforced: compact overlay capture read surface, captured camera revision, stable overlay variant output, captured marquee style, immutable painter boundary, selected-move overlay exclusion, main capture full snapshot preservation, and ordinary camera-pan cache non-regression. Keep fixture names and data tied to durable behavior, not to this plan step or implementation sequence.

Completion Check: Focused Flutter/Dart tests covering the changed frame fixtures pass and include direct assertions for all named outcomes: overlay zero-read counters for excluded seams, main full-capture counters unchanged, compact `viewCameraRevision` captured from runtime, ordinary camera-pan cache identity preserved, overlay primitive variant matrix unchanged, selected move/no-preview empty overlay output, and painter viewport translation from immutable output. `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics` for changed production/test/tool owner scopes pass or report only justified local metric exceptions with nearby plain-language comments. If Unit 1 changed docs or diagrams, the Unit 1 docs and architecture commands also pass in the final verification run. This proves compatibility and regression boundaries; broad test-suite pass without the named assertions is insufficient.

Depends On: Units 1, 2, and 3.
