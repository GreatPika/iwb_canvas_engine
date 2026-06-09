---
date: 2026-06-09
researcher: Codex
commit: fdefe361
branch: new-architecture
research_question: "Confirm all P1 issues in iwb_canvas_engine_12_stage_reports.md against the current codebase."
---

# Research: P1 Stage Report Confirmation

## Summary

All 21 P1 entries in `iwb_canvas_engine_12_stage_reports.md` were checked against the current codebase. The current code confirms every P1 entry as present. No P1 entry was refuted by the inspected code, tests, docs, or guardrail/tooling paths.

Several entries describe overlapping symptoms of the same underlying code path. `EDIT-001` and `RESOURCE-002` both trace to materialized document paths building resource descriptors from `CommittedDocument(document)` with `const RevisionState()`. `RESOURCE-003` and `SURFACE-001` both trace to the same budget follow-up flag being produced by `SurfaceResourceSession` without a production surface/runtime consumer. `API-002` and `SURFACE-002` both trace to invalid terminal pointer cleanup being documented but not representable or routable through the current public/surface sample path. `RUNTIME-003` and `RESOURCE-001` overlap on load/edit resource-session lifecycle delivery.

The research was static. The spawned codebase researchers inspected code, docs, and fixtures with exact line references; no tests or analyzers were run as part of this research note.

## Detailed Findings

### 1. Public API And Codec Boundary

- **Location**: primary `docs/contracts/public_api_v1.md:1769`; additional `lib/src/runtime/runtime_root.dart:2449`, `lib/src/runtime/runtime_root.dart:2450`, `lib/src/runtime/runtime_root.dart:1333`, `lib/src/runtime/runtime_root.dart:1343`.
- **Description**: `API-001` is confirmed. The public contract says direct `CanvasToolPort.handleDoubleTap` throws `UnsupportedError` and has no request/state/action/timestamp effects (`docs/contracts/public_api_v1.md:1769`, `docs/contracts/public_api_v1.md:1771`, `docs/contracts/public_api_v1.md:2352`, `docs/contracts/public_api_v1.md:2353`). The public tool port delegates to `RuntimeRoot.handleDoubleTap` (`lib/src/runtime/runtime_root.dart:2449`, `lib/src/runtime/runtime_root.dart:2450`), and runtime calls `_interactionEngine.handleDoubleTap(...)` and emits a context request if an intent exists (`lib/src/runtime/runtime_root.dart:1333`, `lib/src/runtime/runtime_root.dart:1342`, `lib/src/runtime/runtime_root.dart:1343`). A public fixture expects one request after `runtime.tools.handleDoubleTap(...)` (`test/api/fixtures/tool_port_settings_fixture.dart:164`, `test/api/fixtures/tool_port_settings_fixture.dart:166`).
- **Dependencies**: `RuntimeRoot`, `_RuntimeToolPort`, `InteractionEngine`, async context request stream.
- **Data flow**: Public tool call -> `_RuntimeToolPort.handleDoubleTap` -> `RuntimeRoot.handleDoubleTap` -> `_interactionEngine.handleDoubleTap` -> `_emitContextRequest`.

- **Location**: primary `docs/contracts/public_api_v1.md:1782`; additional `lib/src/contracts/public/canvas_pointer.dart:92`, `lib/src/contracts/public/canvas_pointer.dart:100`, `lib/src/surface/pointer_adapter.dart:37`, `lib/src/surface/pointer_adapter.dart:38`.
- **Description**: `API-002` is confirmed. The contract says down/move positions are finite and invalid terminal samples route to cleanup logic (`docs/contracts/public_api_v1.md:1782`). `CanvasPointerSample` requires a `position` (`lib/src/contracts/public/canvas_pointer.dart:92`) and validates it before construction for every phase (`lib/src/contracts/public/canvas_pointer.dart:100`). `CanvasSurfacePointerAdapter` also returns before constructing a sample when `event.localPosition` is non-finite (`lib/src/surface/pointer_adapter.dart:35`, `lib/src/surface/pointer_adapter.dart:37`, `lib/src/surface/pointer_adapter.dart:38`, `lib/src/surface/pointer_adapter.dart:42`). Surface tests cover finite routing and non-finite down/move no-effect, not active-session invalid up/cancel cleanup (`test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:55`, `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:56`, `test/surface/pointer_adapter_finite_normalization_test.dart:9`).
- **Dependencies**: public pointer sample constructor, value validators, surface pointer adapter.
- **Data flow**: Flutter pointer event -> local position finite gate -> `CanvasPointerSample` factory -> runtime route only if finite.

- **Location**: primary `docs/contracts/schema_v1.md:253`; additional `lib/src/contracts/public/canvas_document.dart:51`, `lib/src/edit/staged_document_load.dart:57`, `lib/src/edit/staged_document_load.dart:127`, `lib/src/store/schema_v1_store_import.dart:110`.
- **Description**: `CODEC-001` is confirmed. Schema and validation docs define a 1MB total encoded metadata budget for the document and say schema import/load applies the limits (`docs/contracts/schema_v1.md:253`, `docs/contracts/validation_limits.md:62`, `docs/contracts/validation_limits.md:73`, `docs/contracts/validation_limits.md:74`). `CanvasDocument` applies aggregate metadata validation (`lib/src/contracts/public/canvas_document.dart:51`, `lib/src/contracts/public/canvas_document.dart:269`, `lib/src/contracts/public/canvas_document.dart:293`, `lib/src/contracts/public/canvas_document.dart:294`). Runtime load prepares from JSON through schema import events and store preparation (`lib/src/edit/staged_document_load.dart:125`, `lib/src/edit/staged_document_load.dart:127`, `lib/src/edit/staged_document_load.dart:134`) while `PreparedDocumentLoad.document` explicitly does not materialize a `CanvasDocument` projection (`lib/src/edit/staged_document_load.dart:57`, `lib/src/edit/staged_document_load.dart:58`, `lib/src/edit/staged_document_load.dart:59`). Import reads each metadata map via `CanvasMetadata.fromMap(...)` (`lib/src/codec/schema_v1_import_emitter.dart:1387`, `lib/src/codec/schema_v1_import_emitter.dart:1402`) and store import creates a committed document without the DTO aggregate constructor (`lib/src/store/schema_v1_store_import.dart:87`, `lib/src/store/schema_v1_store_import.dart:110`, `lib/src/store/schema_v1_store_import.dart:120`).
- **Dependencies**: schema v1 import emitter, staged load pipeline, store import builder, public DTO projection cache.
- **Data flow**: JSON -> import emitter per-map metadata validation -> store import -> committed document -> later projection can call `CanvasDocument`.

- **Location**: primary `lib/src/contracts/public/canvas_value_validators.dart:45`; additional `lib/src/contracts/public/canvas_value_validators.dart:50`, `lib/src/contracts/public/canvas_value_validators.dart:74`, `docs/contracts/schema_v1.md:114`.
- **Description**: `CODEC-002` is confirmed. Schema v1 says app keys are non-empty, length <= 1024, and contain no control characters (`docs/contracts/schema_v1.md:113`, `docs/contracts/schema_v1.md:114`). `validateCanvasAppKeyValue(...)` trims first (`lib/src/contracts/public/canvas_value_validators.dart:45`, `lib/src/contracts/public/canvas_value_validators.dart:50`), validates the trimmed value (`lib/src/contracts/public/canvas_value_validators.dart:51`, `lib/src/contracts/public/canvas_value_validators.dart:58`, `lib/src/contracts/public/canvas_value_validators.dart:66`), and returns the trimmed value (`lib/src/contracts/public/canvas_value_validators.dart:74`). Both schema import paths call the validator (`lib/src/codec/schema_v1_import_emitter.dart:561`, `lib/src/codec/schema_v1_decoder.dart:393`), and the public resource source stores the returned key (`lib/src/contracts/public/canvas_resource.dart:78`, `lib/src/contracts/public/canvas_resource.dart:83`).
- **Dependencies**: shared app key validator, schema v1 decoder, schema import emitter, public resource source.
- **Data flow**: JSON/public app key -> trim -> validate trimmed value -> store/export canonicalized key.

### 2. Store, Resource Revisions, And Resource Sessions

- **Location**: primary `lib/src/edit/commit_applier.dart:117`; additional `lib/src/store/committed_document.dart:24`, `lib/src/store/committed_document.dart:37`, `lib/src/store/document_store_kernel.dart:260`.
- **Description**: `EDIT-001` is confirmed. Materialized accepted documents are installed by creating `CommittedDocument(document)` (`lib/src/edit/commit_applier.dart:117`, `lib/src/edit/commit_applier.dart:119`, `lib/src/edit/commit_applier.dart:124`). The default `CommittedDocument(CanvasDocument)` uses `const RevisionState()` (`lib/src/store/committed_document.dart:24`, `lib/src/store/committed_document.dart:27`) and builds `ResourceTable(..., resourceRevision: revisions.resourceRevision)` (`lib/src/store/committed_document.dart:35`, `lib/src/store/committed_document.dart:37`). Store install/replace then copies only aggregate advanced revisions (`lib/src/store/document_store_kernel.dart:256`, `lib/src/store/document_store_kernel.dart:260`, `lib/src/store/document_store_kernel.dart:268`, `lib/src/store/document_store_kernel.dart:272`). Sparse resource upsert passes accepted resource revisions into the resource table (`lib/src/store/document_store_kernel.dart:583`, `lib/src/store/document_store_kernel.dart:590`, `lib/src/store/document_store_kernel.dart:592`).
- **Dependencies**: edit kernel, commit applier, committed document, store kernel, resource table.
- **Data flow**: Materialized edit -> `CommittedDocument(document)` with default revisions -> store advances aggregate revisions -> embedded resource descriptors keep constructor-time revision.

- **Location**: primary `lib/src/runtime/runtime_root.dart:1681`; additional `lib/src/runtime/runtime_root.dart:1636`, `lib/src/runtime/runtime_root.dart:1658`, `lib/src/runtime/runtime_root.dart:1733`.
- **Description**: `RESOURCE-001` is confirmed. Dirty delivery invalidates the active resource session before publication (`lib/src/runtime/runtime_root.dart:1681`, `lib/src/runtime/runtime_root.dart:1686`, `lib/src/runtime/runtime_root.dart:1690`, `lib/src/runtime/runtime_root.dart:1702`). Edit delivery and load delivery publish state/effects without applying `ResourceDeliveryEffect` to the active session (`lib/src/runtime/runtime_root.dart:1636`, `lib/src/runtime/runtime_root.dart:1649`, `lib/src/runtime/runtime_root.dart:1658`, `lib/src/runtime/runtime_root.dart:1671`). The shared delivery helper consumes only `SpatialDeliveryEffect` (`lib/src/runtime/runtime_root.dart:1733`, `lib/src/runtime/runtime_root.dart:1736`). Load effects include `ResourceDeliveryEffect(touchedSet: TouchedSet(documentReplaced: true))` (`lib/src/runtime/runtime_root.dart:2582`, `lib/src/runtime/runtime_root.dart:2590`), and edit effects convert `ResourceEffect` into `ResourceDeliveryEffect` (`lib/src/edit/commit_applier.dart:159`, `lib/src/edit/commit_applier.dart:167`).
- **Dependencies**: RuntimeRoot active surface session, dirty outcome path, commit delivery effects.
- **Data flow**: Dirty outcome -> active session invalidation; edit/load effect -> observer delivery without active session invalidation.

- **Location**: primary `lib/src/edit/staged_document_load.dart:186`; additional `lib/src/resources/resource_cache.dart:7`, `lib/src/frame/paint_asset_binding_service.dart:73`.
- **Description**: `RESOURCE-002` is confirmed and overlaps with `EDIT-001`. Public `replaceDraftDocument` promotes to materialized replacement (`lib/src/edit/edit_session.dart:748`, `lib/src/edit/edit_session.dart:750`), and staged draft replacement builds `storeDocument: CommittedDocument(draft.document)` (`lib/src/edit/staged_document_load.dart:186`, `lib/src/edit/staged_document_load.dart:199`). Cache identity uses `resolverGeneration`, `resourceId`, and `resourceRevision` (`lib/src/resources/resource_cache.dart:7`, `lib/src/resources/resource_cache.dart:11`), session cache reads/writes by request revision (`lib/src/resources/surface_resource_session.dart:81`, `lib/src/resources/surface_resource_session.dart:88`, `lib/src/resources/surface_resource_session.dart:154`, `lib/src/resources/surface_resource_session.dart:159`), and frame asset requests use `descriptor.resourceRevision` (`lib/src/frame/paint_asset_binding_service.dart:66`, `lib/src/frame/paint_asset_binding_service.dart:73`).
- **Dependencies**: staged load/draft replacement, resource cache key, frame asset binding service.
- **Data flow**: Draft/materialized replacement -> default revision descriptor -> frame request -> cache lookup by descriptor revision.

- **Location**: primary `lib/src/resources/surface_resource_session.dart:33`; additional `lib/src/surface/canvas_surface_widget.dart:172`, `lib/src/surface/canvas_surface_widget.dart:203`.
- **Description**: `RESOURCE-003` is confirmed. Resource docs define frame budget, budget-exceeded placeholders, and session-owned follow-up throttle (`docs/contracts/resources.md:249`, `docs/contracts/resources.md:252`, `docs/contracts/resources.md:257`, `docs/contracts/resources.md:259`). `SurfaceResourceSession` stores and exposes `hasPendingBudgetFollowUpRepaint` (`lib/src/resources/surface_resource_session.dart:30`, `lib/src/resources/surface_resource_session.dart:33`), clears it at the next frame pass (`lib/src/resources/surface_resource_session.dart:35`, `lib/src/resources/surface_resource_session.dart:39`), and sets it when resolver-call budget is exhausted (`lib/src/resources/surface_resource_session.dart:120`, `lib/src/resources/surface_resource_session.dart:127`, `lib/src/resources/surface_resource_session.dart:132`). Production frame binding and surface build use the session but do not read the getter (`lib/src/frame/paint_asset_binding_service.dart:23`, `lib/src/frame/paint_asset_binding_service.dart:49`, `lib/src/surface/canvas_surface_widget.dart:172`, `lib/src/surface/canvas_surface_widget.dart:203`). The resource fixture verifies the flag manually (`test/resources/fixtures/resolver_frame_budget_fixture.dart:41`, `test/resources/fixtures/resolver_frame_budget_fixture.dart:59`).
- **Dependencies**: resource session, paint asset binding, surface widget.
- **Data flow**: Frame pass -> resolver budget exceeded -> session flag set -> no production surface/runtime read found.

### 3. Runtime Lifecycle And Interaction Flow

- **Location**: primary `lib/src/runtime/runtime_root.dart:1368`; additional `lib/src/runtime/runtime_root.dart:1745`, `lib/src/runtime/runtime_root.dart:1762`.
- **Description**: `RUNTIME-001` is confirmed. Pending context requests are queued and microtask-delivered (`lib/src/runtime/runtime_root.dart:1745`, `lib/src/runtime/runtime_root.dart:1754`, `lib/src/runtime/runtime_root.dart:1757`). `dispose()` calls `_deliverPendingContextRequests()` before clearing interaction requests, incrementing generation, setting disposed, and closing streams (`lib/src/runtime/runtime_root.dart:1368`, `lib/src/runtime/runtime_root.dart:1370`, `lib/src/runtime/runtime_root.dart:1372`, `lib/src/runtime/runtime_root.dart:1374`). `_deliverPendingContextRequests()` adds deliverable requests to `_contextActionRequests` (`lib/src/runtime/runtime_root.dart:1762`). Existing load-path tests cover queued request suppression on load (`test/runtime/fixtures/load_interaction_cleanup_fixture.dart:225`), while dispose fixture coverage starts at already-live cleanup (`test/runtime/fixtures/load_interaction_cleanup_fixture.dart:245`).
- **Dependencies**: RuntimeRoot dispose, context request queue, interaction cleanup.
- **Data flow**: Gesture emits pending context request -> dispose synchronously delivers pending queue -> generation invalidation and stream close happen after delivery.

- **Location**: primary `lib/src/runtime/runtime_root.dart:1525`; additional `lib/src/runtime/runtime_root.dart:1658`, `lib/src/resources/surface_resource_session.dart:189`.
- **Description**: `RUNTIME-003` is confirmed and overlaps with `RESOURCE-001`. Operation matrix requires successful `loadDocumentFromJson` to replace descriptors, invalidate resource caches, and clear surface-session resource state (`docs/contracts/operation_matrix.md:284`). RuntimeRoot stores active resource session state (`lib/src/runtime/runtime_root.dart:208`). `_loadDocumentFromJson` prepares and consumes load, clears selection, bumps camera/epoch, and calls `_deliverLoadResult(...)` (`lib/src/runtime/runtime_root.dart:1525`, `lib/src/runtime/runtime_root.dart:1544`). `_deliverLoadResult` handles spatial effects, state publication, text editing, and observer delivery without clearing active resource session (`lib/src/runtime/runtime_root.dart:1658`, `lib/src/runtime/runtime_root.dart:1671`). `_dropActiveSurfaceResourceSession()` exists and calls `session.drop()` (`lib/src/runtime/runtime_root.dart:1705`), and `SurfaceResourceSession.drop()` clears resolver/cache/budget/null-suppression state (`lib/src/resources/surface_resource_session.dart:189`).
- **Dependencies**: load pipeline, RuntimeRoot surface session ownership, surface resource session lifecycle.
- **Data flow**: Successful load -> state/effects delivery -> active session cleanup not invoked.

- **Location**: primary `lib/src/runtime/runtime_interaction_read_adapter.dart:171`; additional `lib/src/interaction/select_machine.dart:35`.
- **Description**: `INTERACTION-001` is confirmed. Marquee read facts return `nextSelectedIds` plus query facts (`lib/src/runtime/runtime_interaction_read_adapter.dart:171`), and point-selection path does the same (`lib/src/runtime/runtime_interaction_read_adapter.dart:205`). Interaction engine records query diagnostics and still passes facts to `SelectMachine.terminal(...)` (`lib/src/interaction/interaction_engine.dart:1134`, `lib/src/interaction/interaction_engine.dart:1487`, `lib/src/interaction/interaction_engine.dart:1494`). `SelectMachine.terminal` checks selection revision, controller epoch, and ids, not `facts.query.status` or skipped candidates (`lib/src/interaction/select_machine.dart:35`, `lib/src/interaction/select_machine.dart:40`). A fixture records `budgetExceeded` with empty `nextSelectedIds` (`test/interaction/fixtures/interaction_read_port_fixture.dart:320`, `test/interaction/fixtures/interaction_read_port_fixture.dart:328`).
- **Dependencies**: runtime interaction read adapter, interaction engine, select machine.
- **Data flow**: Spatial query facts -> diagnostic recording -> selection machine terminal decision using ids/revisions only.

- **Location**: primary `lib/src/runtime/runtime_interaction_read_mapping.dart:21`; additional `lib/src/runtime/runtime_interaction_read_adapter.dart:399`, `lib/src/runtime/runtime_interaction_read_adapter.dart:426`.
- **Description**: `INTERACTION-002` is confirmed. Candidate resolution skips unresolved handles and increments `skippedCandidateCount` (`lib/src/runtime/runtime_interaction_read_mapping.dart:21`, `lib/src/runtime/runtime_interaction_read_mapping.dart:52`). Context target facts reject only when `interactionQueryHasCandidates(query)` is false (`lib/src/runtime/runtime_interaction_read_adapter.dart:399`, `lib/src/runtime/runtime_interaction_read_adapter.dart:414`). `interactionQueryHasCandidates` returns true for any `SpatialCandidatesResult` (`lib/src/runtime/runtime_interaction_read_mapping.dart:48`). `_admittedContextTarget` computes topmost hit from filtered handles and can admit empty canvas when no hit remains (`lib/src/runtime/runtime_interaction_read_adapter.dart:426`, `lib/src/runtime/runtime_interaction_read_adapter.dart:450`). Rejection diagnostics are only recorded for `RejectedContextTargetRead` (`lib/src/interaction/interaction_engine.dart:899`).
- **Dependencies**: candidate mapping, context target read adapter, interaction engine diagnostics.
- **Data flow**: Spatial handles -> unresolved handles skipped -> candidates query still admitted -> context target computed from partial handles.

- **Location**: primary `lib/src/runtime/runtime_root.dart:1899`; additional `lib/src/runtime/runtime_root.dart:2073`, `lib/src/runtime/runtime_root.dart:2132`.
- **Description**: `INTERACTION-003` is confirmed. Operation matrix requires main + overlay cleanup for marquee, pencil/marker, line, and eraser commits (`docs/contracts/operation_matrix.md:57`, `docs/contracts/operation_matrix.md:78`, `docs/contracts/operation_matrix.md:80`, `docs/contracts/operation_matrix.md:84`). Cleanup coordinator maps active preview cleanup to overlay repaint (`lib/src/interaction/pointer_tool_cleanup_coordinator.dart:47`). Eraser commit captures cleanup and delivers `_withPointerCleanupEffects(applyResult, cleanup)` (`lib/src/runtime/runtime_root.dart:2073`, `lib/src/runtime/runtime_root.dart:2089`). Marquee, draw stroke, and line commit call cleanup with `publish: false` but deliver `applyResult` without merging cleanup effects (`lib/src/runtime/runtime_root.dart:1899`, `lib/src/runtime/runtime_root.dart:1945`, `lib/src/runtime/runtime_root.dart:2007`). `_withPointerCleanupEffects` exists and merges cleanup repaint effects (`lib/src/runtime/runtime_root.dart:2132`, `lib/src/runtime/runtime_root.dart:2156`, `lib/src/runtime/runtime_root.dart:2175`).
- **Dependencies**: RuntimeRoot commit delivery, cleanup coordinator, commit delivery effects.
- **Data flow**: Successful pointer commit -> preview cleanup outcome -> eraser merges repaint effect; marquee/draw/line ignore cleanup outcome for delivery effects.

### 4. Geometry, Spatial, And Frame Capture

- **Location**: primary `lib/src/contracts/public/canvas_geometry.dart:144`; additional `lib/src/geometry/hit_test_policy.dart:198`.
- **Description**: `GEOMETRY-001` is confirmed. `CanvasTransform` public factory validates on construction (`lib/src/contracts/public/canvas_geometry.dart:14`, `lib/src/contracts/public/canvas_geometry.dart:22`, `lib/src/contracts/public/canvas_geometry.dart:23`). `CanvasTransform.invert()` returns a new `CanvasTransform(...)` (`lib/src/contracts/public/canvas_geometry.dart:144`, `lib/src/contracts/public/canvas_geometry.dart:155`), which reuses public validation. Transform validation validates translation through `validateOffset` (`lib/src/contracts/public/canvas_geometry.dart:214`, `lib/src/contracts/public/canvas_geometry.dart:216`), and coordinate limits are `[-1e7, 1e7]` while singular value minimum is `1e-4` (`lib/src/contracts/public/canvas_contract_limits.dart:18`, `lib/src/contracts/public/canvas_contract_limits.dart:19`, `lib/src/contracts/public/canvas_contract_limits.dart:24`). Hit paths call `facts.transform.invert()` without catch (`lib/src/geometry/hit_test_policy.dart:193`, `lib/src/geometry/hit_test_policy.dart:198`, `lib/src/geometry/hit_test_policy.dart:462`, `lib/src/geometry/hit_test_policy.dart:467`, `lib/src/geometry/hit_test_policy.dart:513`, `lib/src/geometry/hit_test_policy.dart:518`).
- **Dependencies**: public geometry contracts, transform admission, hit test policy.
- **Data flow**: Valid public transform -> hit test inverse -> public transform validation on derived inverse -> exception possible when derived translation exceeds public coordinate limit.

- **Location**: primary `lib/src/geometry/tile_index.dart:62`; additional `lib/src/geometry/tile_index.dart:70`.
- **Description**: `GEOMETRY-002` is confirmed. Spatial candidate budget is 4096 (`lib/src/geometry/spatial_query_policy.dart:7`). `TileIndex.query` creates a candidates map (`lib/src/geometry/tile_index.dart:62`), adds tile page candidates and all outlier candidates (`lib/src/geometry/tile_index.dart:63`, `lib/src/geometry/tile_index.dart:66`), and only then calls `spatialCandidateResultWithinBudget(candidates.values, ...)` (`lib/src/geometry/tile_index.dart:70`, `lib/src/geometry/tile_index.dart:71`). The budget helper checks length while iterating the already-built source (`lib/src/geometry/tile_index.dart:95`, `lib/src/geometry/tile_index.dart:101`, `lib/src/geometry/tile_index.dart:104`). A fixture expects over-budget outlier iteration to visit the whole source (`test/spatial/fixtures/fallback_budget_enforced_fixture.dart:42`, `test/spatial/fixtures/fallback_budget_enforced_fixture.dart:56`).
- **Dependencies**: tile index, spatial query policy, budget result helper.
- **Data flow**: Query window -> materialize all candidate handles into map -> budget helper returns budget-exceeded result after materialization.

- **Location**: primary `lib/src/frame/frame_capture_service.dart:40`; additional `lib/src/frame/captured_frame.dart:90`.
- **Description**: `FRAME-001` is confirmed. Frame contract describes `CapturedOverlayFrame` as preview/camera/style facts (`docs/contracts/frame_rendering.md:85`, `docs/contracts/frame_rendering.md:88`, `docs/contracts/frame_rendering.md:94`) and says overlay primitives are admitted from `CapturedOverlayFrame` (`docs/contracts/frame_rendering.md:175`, `docs/contracts/frame_rendering.md:178`). Current `captureOverlayFrame` calls `_captureSnapshot(inputs)` (`lib/src/frame/frame_capture_service.dart:40`, `lib/src/frame/frame_capture_service.dart:41`). `_captureSnapshot` reads revisions, selection facts, spatial paint query, resolved elements/descriptors, background, and spatial candidates (`lib/src/frame/frame_capture_service.dart:52`, `lib/src/frame/frame_capture_service.dart:55`, `lib/src/frame/frame_capture_service.dart:56`, `lib/src/frame/frame_capture_service.dart:69`, `lib/src/frame/frame_capture_service.dart:76`, `lib/src/frame/frame_capture_service.dart:80`). `CapturedOverlayFrame` stores a full `CapturedFrameSnapshot` (`lib/src/frame/captured_frame.dart:90`, `lib/src/frame/captured_frame.dart:92`, `lib/src/frame/captured_frame.dart:96`), and that snapshot includes main-frame fields (`lib/src/frame/captured_frame.dart:56`, `lib/src/frame/captured_frame.dart:57`, `lib/src/frame/captured_frame.dart:58`, `lib/src/frame/captured_frame.dart:61`, `lib/src/frame/captured_frame.dart:62`). Existing fixture expects overlay snapshot spatial candidates and doubled reads (`test/frame/fixtures/main_overlay_capture_fixture.dart:76`, `test/frame/fixtures/main_overlay_capture_fixture.dart:115`, `test/frame/fixtures/main_overlay_capture_fixture.dart:132`).
- **Dependencies**: frame capture service, captured frame models, runtime frame facts, overlay planner.
- **Data flow**: Overlay frame request -> full snapshot capture -> overlay planner uses overlay preview plus snapshot inputs.

### 5. Diagnostics And Architecture Guardrails

- **Location**: primary `lib/src/contracts/public/canvas_errors.dart:29`; additional `docs/contracts/public_api_v1.md:2697`, `lib/src/codec/schema_v1_decoder.dart:272`, `lib/src/contracts/public/canvas_value_validators.dart:213`.
- **Description**: `DIAG-001` is confirmed. Public error contract prohibits raw input exposure outside DiagnosticsHub or sanitized bounded details (`docs/contracts/public_api_v1.md:2697`, `docs/contracts/public_api_v1.md:2700`). `CanvasDataException` sanitizes only `details`; `message` and `path` pass through unchanged (`lib/src/contracts/public/canvas_errors.dart:29`, `lib/src/contracts/public/canvas_errors.dart:37`, `lib/src/contracts/public/canvas_errors.dart:38`, `lib/src/contracts/public/canvas_errors.dart:39`). `message`, `path`, and `details` are public fields (`lib/src/contracts/public/canvas_errors.dart:50`, `lib/src/contracts/public/canvas_errors.dart:53`). Schema decoder/import emitter interpolate raw `kind` values into messages (`lib/src/codec/schema_v1_decoder.dart:272`, `lib/src/codec/schema_v1_decoder.dart:381`, `lib/src/codec/schema_v1_decoder.dart:487`, `lib/src/codec/schema_v1_import_emitter.dart:526`, `lib/src/codec/schema_v1_import_emitter.dart:544`). Metadata validation interpolates raw keys into public paths (`lib/src/contracts/public/canvas_value_validators.dart:211`, `lib/src/contracts/public/canvas_value_validators.dart:213`, `lib/src/contracts/public/canvas_value_validators.dart:357`, `lib/src/contracts/public/canvas_value_validators.dart:366`).
- **Dependencies**: public error model, details sanitizer, codec/schema errors, metadata validators.
- **Data flow**: Raw schema/metadata value -> public message/path -> no sanitizer for those fields.

- **Location**: primary `tool/guardrails/src/core_boundary_checks.dart:338`; additional `tool/architecture_graph/src/actual_graph.dart:382`.
- **Description**: `ARCH-001` is confirmed as an enforcement gap. Core boundary checks read only `directive.uri.stringValue` for imports and exports (`tool/guardrails/src/core_boundary_checks.dart:338`, `tool/guardrails/src/core_boundary_checks.dart:341`, `tool/guardrails/src/core_boundary_checks.dart:346`, `tool/guardrails/src/core_boundary_checks.dart:349`) and apply checks to that single URI (`tool/guardrails/src/core_boundary_checks.dart:367`, `tool/guardrails/src/core_boundary_checks.dart:379`). Architecture graph extraction records only `node.uri.stringValue` for export/import facts (`tool/architecture_graph/src/actual_graph.dart:382`, `tool/architecture_graph/src/actual_graph.dart:390`, `tool/architecture_graph/src/actual_graph.dart:397`, `tool/architecture_graph/src/actual_graph.dart:405`). Owner DAG already includes conditional configurations by yielding both main URI and configuration URIs (`tool/guardrails/src/owner_dag_import_checks.dart:137`, `tool/guardrails/src/owner_dag_import_checks.dart:150`, `tool/guardrails/src/owner_dag_import_checks.dart:160`, `tool/guardrails/src/owner_dag_import_checks.dart:163`) and has a conditional hidden-edge test (`test/guardrails/owner_dag_import_boundaries_test.dart:64`, `test/guardrails/owner_dag_import_boundaries_test.dart:82`). No committed production conditional import/export was found in searched `lib/**`.
- **Dependencies**: core boundary checker, architecture graph extractor, owner DAG checker.
- **Data flow**: Dart directive -> core/graph reads main URI only; conditional URI branches are not included in those guardrails.

### 6. Surface Integration And Release Readiness

- **Location**: primary `lib/src/surface/canvas_surface_widget.dart:182`; additional `lib/src/resources/surface_resource_session.dart:127`.
- **Description**: `SURFACE-001` is confirmed and overlaps with `RESOURCE-003`. `CanvasSurface` builds the main frame with `CanvasSurfaceImageBridge().bindAssets(session)` (`lib/src/surface/canvas_surface_widget.dart:182`, `lib/src/surface/canvas_surface_widget.dart:189`), then builds overlay and returns `CustomPaint` (`lib/src/surface/canvas_surface_widget.dart:190`, `lib/src/surface/canvas_surface_widget.dart:203`) without reading `session.hasPendingBudgetFollowUpRepaint`. The flag is produced by `SurfaceResourceSession` on budget exhaustion (`lib/src/resources/surface_resource_session.dart:120`, `lib/src/resources/surface_resource_session.dart:127`, `lib/src/resources/surface_resource_session.dart:132`) and cleared by the next frame pass (`lib/src/resources/surface_resource_session.dart:35`, `lib/src/resources/surface_resource_session.dart:38`). Surface tests cover dirty-resource repaint by explicit dirty action and pump, not budget follow-up scheduling (`test/surface/fixtures/widget_paint_fixture.dart:97`, `test/surface/fixtures/widget_paint_fixture.dart:100`).
- **Dependencies**: CanvasSurface widget, resource session, frame asset binding.
- **Data flow**: Surface frame build -> budget flag can be set during asset binding -> widget build completes with no follow-up scheduling read.

- **Location**: primary `lib/src/surface/pointer_adapter.dart:25`; additional `lib/src/surface/pointer_adapter.dart:38`.
- **Description**: `SURFACE-002` is confirmed and overlaps with `API-002`. Flutter `PointerUpEvent` and `PointerCancelEvent` route into `_route(...)` with terminal phases (`lib/src/surface/pointer_adapter.dart:25`, `lib/src/surface/pointer_adapter.dart:30`). `_route` returns on any non-finite `localPosition` before phase-specific handling or sample creation (`lib/src/surface/pointer_adapter.dart:35`, `lib/src/surface/pointer_adapter.dart:37`, `lib/src/surface/pointer_adapter.dart:38`, `lib/src/surface/pointer_adapter.dart:41`). Interaction tests show cleanup-only terminal behavior once a terminal sample exists (`test/interaction/pointer_session_test.dart:119`, `test/interaction/pointer_session_test.dart:147`), but surface adapter blocks invalid terminal events before runtime routing.
- **Dependencies**: Flutter pointer adapter, public pointer sample, interaction pointer session cleanup.
- **Data flow**: Pointer up/cancel event -> non-finite localPosition gate -> no runtime terminal cleanup sample.

- **Location**: primary `tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:3`; additional `.github/workflows/release_benchmarks.yml:30`, `tool/bench/src/benchmark_diff.dart:168`.
- **Description**: `TEST-001` is confirmed. Release benchmark workflow runs release benchmarks and diffs against the approved baseline path (`.github/workflows/release_benchmarks.yml:30`, `.github/workflows/release_benchmarks.yml:34`). The committed approved baseline exists and has `"status": "unapproved"` (`tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:3`) with a message that no measured release baseline has been approved (`tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:5`). Diff code treats `status == 'unapproved'` as a failure (`tool/bench/src/benchmark_diff.dart:168`, `tool/bench/src/benchmark_diff.dart:174`), and the CLI returns exit code 1 when diff is not passed (`tool/bench/src/benchmark_diff.dart:235`, `tool/bench/src/benchmark_diff.dart:240`). Tests and docs also describe this fail-closed placeholder (`test/benchmarks/benchmark_diff_test.dart:36`, `test/benchmarks/benchmark_diff_test.dart:58`, `docs/verification/benchmarks.md:111`, `docs/verification/benchmarks.md:115`).
- **Dependencies**: release benchmark workflow, approved baseline file, benchmark diff implementation.
- **Data flow**: Release workflow -> current benchmark run -> diff against approved baseline -> unapproved baseline status -> diff failure.

## Code References

- `iwb_canvas_engine_12_stage_reports.md:20` - `API-001` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:84` - `API-002` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:156` - `CODEC-001` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:194` - `CODEC-002` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:276` - `EDIT-001` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:534` - `RUNTIME-001` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:627` - `RUNTIME-003` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:694` - `INTERACTION-001` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:744` - `INTERACTION-002` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:789` - `INTERACTION-003` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:915` - `GEOMETRY-001` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:954` - `GEOMETRY-002` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:1027` - `FRAME-001` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:1180` - `RESOURCE-001` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:1224` - `RESOURCE-002` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:1271` - `RESOURCE-003` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:1352` - `DIAG-001` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:1556` - `SURFACE-001` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:1590` - `SURFACE-002` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:1637` - `ARCH-001` P1 entry.
- `iwb_canvas_engine_12_stage_reports.md:1883` - `TEST-001` P1 entry.
- `lib/src/runtime/runtime_root.dart:2450` - direct tool double-tap delegates to runtime root.
- `lib/src/contracts/public/canvas_pointer.dart:100` - pointer sample validates position for every phase.
- `lib/src/contracts/public/canvas_document.dart:51` - public DTO aggregate metadata validation entry.
- `lib/src/edit/staged_document_load.dart:57` - prepared loads do not materialize DTO projection.
- `lib/src/contracts/public/canvas_value_validators.dart:50` - app key trim before validation.
- `lib/src/edit/commit_applier.dart:119` - materialized commit constructs `CommittedDocument(document)`.
- `lib/src/store/committed_document.dart:37` - resource table descriptors use constructor revision state.
- `lib/src/runtime/runtime_root.dart:1686` - dirty path invalidates active resource session.
- `lib/src/runtime/runtime_root.dart:1733` - shared delivery helper consumes spatial effects only.
- `lib/src/runtime/runtime_root.dart:1370` - dispose delivers pending context requests.
- `lib/src/interaction/select_machine.dart:35` - selection terminal checks revisions/ids, not query status.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:414` - context target admission uses candidates presence.
- `lib/src/runtime/runtime_root.dart:2089` - eraser commit merges cleanup effects.
- `lib/src/runtime/runtime_root.dart:1899` - marquee commit cleanup outcome not merged.
- `lib/src/contracts/public/canvas_geometry.dart:155` - inverse transform uses public constructor.
- `lib/src/geometry/tile_index.dart:70` - candidate budget helper runs after map construction.
- `lib/src/frame/frame_capture_service.dart:40` - overlay capture uses `_captureSnapshot`.
- `lib/src/contracts/public/canvas_errors.dart:39` - sanitizer applied only to details.
- `tool/guardrails/src/core_boundary_checks.dart:341` - core boundary reads only main import URI.
- `tool/architecture_graph/src/actual_graph.dart:397` - actual graph reads only main import URI.
- `lib/src/resources/surface_resource_session.dart:127` - budget exhaustion sets follow-up repaint flag.
- `lib/src/surface/canvas_surface_widget.dart:182` - surface builds main frame with session-backed asset binding.
- `lib/src/surface/pointer_adapter.dart:38` - surface drops non-finite pointer event before sample route.
- `tool/bench/src/benchmark_diff.dart:168` - unapproved baseline status creates failure.

## Search Coverage

- Inspected: `iwb_canvas_engine_12_stage_reports.md` completely; all P1 blocks and surrounding report context.
- Inspected: `docs/contracts/public_api_v1.md`, `docs/contracts/schema_v1.md`, `docs/contracts/validation_limits.md`, `docs/contracts/resources.md`, `docs/contracts/operation_matrix.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/frame_rendering.md`, `docs/contracts/geometry.md`, `docs/contracts/spatial_kernel.md`, `docs/verification/benchmarks.md`, `docs/verification/release_gates.md`.
- Inspected: production files under `lib/src/runtime`, `lib/src/interaction`, `lib/src/edit`, `lib/src/store`, `lib/src/resources`, `lib/src/frame`, `lib/src/geometry`, `lib/src/surface`, `lib/src/contracts/public`, `lib/src/codec`.
- Inspected: guardrail and architecture tools under `tool/guardrails/src` and `tool/architecture_graph/src`.
- Inspected: release benchmark workflow and approved baseline under `.github/workflows/release_benchmarks.yml`, `.github/workflows/update_benchmark_baseline.yml`, and `tool/bench/**`.
- Inspected: relevant fixtures/tests under `test/api`, `test/api_contract`, `test/codec`, `test/runtime`, `test/interaction`, `test/resources`, `test/surface`, `test/spatial`, `test/frame`, `test/diagnostics`, `test/guardrails`, `test/architecture_graph`, and `test/benchmarks`.
- Searched: `rg -n "^ID: .*|^Приоритет: P1|^Название проблемы:" iwb_canvas_engine_12_stage_reports.md`.
- Searched: `rg -n "handleDoubleTap|UnsupportedError|contextActionRequests|CanvasContextActionRequested|CanvasPointerSample|non-finite|invalid terminal|localPosition" lib test docs`.
- Searched: `rg -n "metadata.*budget|aggregate|canvasMetadataEncodedByteLength|canvasMetadataMaxEncodedBytes|CanvasMetadata.fromMap|invalidMetadata|validateCanvasAppKeyValue|resource.source.key|trim" lib test docs`.
- Searched: `rg -n "resourceRevision|SurfaceResourceSession|ResourceDeliveryEffect|hasPendingBudgetFollowUpRepaint|beginFrameResourcePass|resolveImage\\(|invalidateResourceImage|CommittedDocument\\(" lib test docs`.
- Searched: `rg -n "CanvasContextActionRequested|loadDocumentFromJson|skippedCandidateCount|RejectedContextTargetRead|MarqueeCommitFacts|_withPointerCleanupEffects|_deliverPendingContextRequests" lib test docs`.
- Searched: `rg -n "invert\\(|CanvasTransform\\(|validateOffset\\(|_hitBox|_hitPath|_eraserHitsPath|spatialCandidateResultWithinBudget|CapturedOverlayFrame|captureOverlayFrame|_captureSnapshot" lib test docs`.
- Searched: `rg -n "CanvasDataException|sanitize|unknown resource kind|unknown element kind|metadata\\.\\$\\{entry\\.key\\}|ImportDirective|ExportDirective|configurations|node\\.uri|stringValue" lib tool test docs`.
- Searched: `rg -n "unapproved|approved baseline is not initialized|release_ubuntu_24_04_flutter_3_38_0|release_benchmarks" .github tool docs test`.
- Not found: aggregate metadata byte summing in runtime load/store import path outside `CanvasDocument`.
- Not found: tests rejecting trimmed-but-noncanonical appKey values.
- Not found: tests requiring invalid terminal up/cancel cleanup through `CanvasSurfacePointerAdapter`.
- Not found: production consumer of `hasPendingBudgetFollowUpRepaint` outside `SurfaceResourceSession`.
- Not found: edit/load runtime path applying `ResourceDeliveryEffect` to the active resource-session invalidation sink.
- Not found: geometry-only unchecked inverse helper in searched geometry/frame paths.
- Not found: current zero-read overlay capture fixture.
- Not found: committed production conditional import/export directives in searched `lib/**`.
- Not found: measured approved release baseline replacing the unapproved placeholder at the approved release baseline path.

## Observed Architecture Facts

- Public contract/code mismatch: direct double-tap is documented as unsupported but implemented and tested as a context request producer (`docs/contracts/public_api_v1.md:1769`, `lib/src/runtime/runtime_root.dart:2450`, `test/api/fixtures/tool_port_settings_fixture.dart:166`).
- Boundary validation mismatch: invalid terminal pointer cleanup is documented but blocked by both public sample validation and surface finite-position gate (`docs/contracts/public_api_v1.md:1782`, `lib/src/contracts/public/canvas_pointer.dart:100`, `lib/src/surface/pointer_adapter.dart:38`).
- Load validation split: aggregate metadata budget is enforced by public DTO construction but not by the runtime schema import path before store install (`lib/src/contracts/public/canvas_document.dart:51`, `lib/src/edit/staged_document_load.dart:127`, `lib/src/store/schema_v1_store_import.dart:110`).
- Materialized resource revision split: sparse/schema import paths can use accepted revisions while materialized paths build resource descriptors from default revision state (`lib/src/store/document_store_kernel.dart:592`, `lib/src/store/schema_v1_store_import.dart:101`, `lib/src/edit/commit_applier.dart:119`, `lib/src/store/committed_document.dart:27`).
- Resource session delivery split: dirty delivery has active-session invalidation, while edit/load resource delivery effects are observer-facing without active-session application (`lib/src/runtime/runtime_root.dart:1686`, `lib/src/runtime/runtime_root.dart:1733`).
- Interaction admission pattern: diagnostics can be recorded for query reliability while terminal mutation continues through machines that do not check query status/skipped candidate count (`lib/src/interaction/interaction_engine.dart:1494`, `lib/src/interaction/select_machine.dart:35`).
- Overlay/main capture coupling: overlay frame capture currently owns a full main-frame snapshot, including spatial/resource/selection facts (`lib/src/frame/frame_capture_service.dart:40`, `lib/src/frame/captured_frame.dart:56`).
- Guardrail asymmetry: owner DAG scans conditional directive URIs, while core boundary and architecture graph do not (`tool/guardrails/src/owner_dag_import_checks.dart:150`, `tool/guardrails/src/core_boundary_checks.dart:341`, `tool/architecture_graph/src/actual_graph.dart:397`).
- Release benchmark gate state: the current approved baseline path is intentionally present but unapproved, and diff code fails closed on that status (`tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json:3`, `tool/bench/src/benchmark_diff.dart:168`).

## Open Questions

- This research did not execute Dart, Flutter, DCM, guardrail, docs, or benchmark commands.
- This research did not evaluate P2 entries from `iwb_canvas_engine_12_stage_reports.md`.
- This research did not choose remediation order or implementation ownership for the confirmed P1 entries.
