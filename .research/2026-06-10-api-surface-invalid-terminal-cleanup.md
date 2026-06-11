---
date: 2026-06-10
researcher: Codex
commit: 80646b68
branch: new-architecture
research_question: "Research before designing API-002 + SURFACE-002 from the retired stage-report scratchpad."
---

# Research: API and Surface Invalid Terminal Cleanup

## Summary

API-002 and SURFACE-002 both concern terminal pointer input whose position is not finite. The retired stage-report scratchpad identified API-002 as a public API issue and described the public contract expectation that invalid terminal samples route to cleanup logic. It identified SURFACE-002 as the Flutter surface issue and described the adapter dropping non-finite terminal events before runtime cleanup receives them.

The current public pointer API exports `CanvasPointerSample` and `CanvasPointerLifecyclePhase`, and the public contract states that pointer position is finite for down/move while invalid terminal samples are routed to cleanup logic. The implementation constructs public samples through a factory that validates `position` with no branch on `phase`, so a non-finite `up` or `cancel` position cannot be represented by that public constructor.

The current surface path uses a Flutter `Listener`, maps down/move/up/cancel events to lifecycle phases, and checks `event.localPosition` for finiteness before constructing `CanvasPointerSample`. That check returns before calling the route callback for all phases, so non-finite terminal `PointerUpEvent` and `PointerCancelEvent` do not reach the active-surface port or runtime pointer cleanup path.

## Detailed Findings

### 1. Public Pointer Export Surface

- **Location**: primary `lib/iwb_canvas_engine.dart:12`; additional `lib/src/api/canvas_pointer.dart:1`, `docs/_registry/public_api_v1.yaml:65`.
- **Description**: The root package barrel exports the public pointer facade at `lib/iwb_canvas_engine.dart:12`. That facade re-exports the public pointer contract declarations from `lib/src/api/canvas_pointer.dart:1`. The public API registry includes `CanvasPointerPolicy`, `CanvasPointerSample`, and `CanvasPointerLifecyclePhase` in `public_exports` at `docs/_registry/public_api_v1.yaml:65`, `docs/_registry/public_api_v1.yaml:66`, and `docs/_registry/public_api_v1.yaml:67`.
- **Dependencies**: The pointer declarations import `dart:ui` for `Offset` at `lib/src/contracts/public/canvas_pointer.dart:1` and Flutter foundation for `PointerDeviceKind` at `lib/src/contracts/public/canvas_pointer.dart:3`.
- **Data flow**: Root import -> `src/api/canvas_pointer.dart` facade -> `src/contracts/public/canvas_pointer.dart` declarations.

### 2. Public Pointer Contract Text

- **Location**: primary `docs/contracts/public_api_v1.md:1568`; additional `docs/contracts/public_api_v1.md:1779`.
- **Description**: The public contract's tools and pointer API section defines `CanvasPointerLifecyclePhase { down, move, up, cancel }` at `docs/contracts/public_api_v1.md:1573` and `CanvasToolPort.handlePointer(CanvasPointerSample sample)` at `docs/contracts/public_api_v1.md:1726`. Its validation block states `pointer position -> finite for down/move; invalid terminal samples are routed to cleanup logic` at `docs/contracts/public_api_v1.md:1787`.
- **Dependencies**: The same contract states pointer id scope and single-session behavior: pointer id routes samples and rejects stale terminal samples at `docs/contracts/public_api_v1.md:1793`, one runtime has at most one active pointer session at `docs/contracts/public_api_v1.md:1794`, a second down is ignored while active at `docs/contracts/public_api_v1.md:1795`, and concurrent pointer sessions are not stored at `docs/contracts/public_api_v1.md:1796`.
- **Data flow**: Public input contract -> `CanvasPointerSample` accepted by `CanvasToolPort.handlePointer` -> runtime terminal cleanup behavior described by pointer validation and scope text.

### 3. Public CanvasPointerSample Construction

- **Location**: primary `lib/src/contracts/public/canvas_pointer.dart:91`.
- **Description**: `CanvasPointerSample` is a public immutable value with fields `pointerId`, `position`, `timestampMs`, `phase`, and `kind` at `lib/src/contracts/public/canvas_pointer.dart:122`, `lib/src/contracts/public/canvas_pointer.dart:123`, `lib/src/contracts/public/canvas_pointer.dart:124`, `lib/src/contracts/public/canvas_pointer.dart:125`, and `lib/src/contracts/public/canvas_pointer.dart:126`. Its factory takes required `pointerId`, `position`, `phase`, `kind`, and optional `timestampMs` at `lib/src/contracts/public/canvas_pointer.dart:92`.
- **Dependencies**: The factory validates `pointerId` at `lib/src/contracts/public/canvas_pointer.dart:99`, validates `position` at `lib/src/contracts/public/canvas_pointer.dart:100`, validates non-null `timestampMs` at `lib/src/contracts/public/canvas_pointer.dart:101`, and constructs the private value at `lib/src/contracts/public/canvas_pointer.dart:105`. `validateOffset` validates both coordinates through `validateDoubleRange` at `lib/src/contracts/public/canvas_value_validators.dart:185`, `lib/src/contracts/public/canvas_value_validators.dart:186`, and `lib/src/contracts/public/canvas_value_validators.dart:192`; `validateDoubleRange` first calls finite validation at `lib/src/contracts/public/canvas_value_validators.dart:142`. Coordinate limits are `-1e7` and `1e7` at `lib/src/contracts/public/canvas_contract_limits.dart:18` and `lib/src/contracts/public/canvas_contract_limits.dart:19`.
- **Data flow**: Public constructor arguments -> pointer id/position/timestamp validators -> private immutable `CanvasPointerSample._`. The validation sequence from `lib/src/contracts/public/canvas_pointer.dart:92` through `lib/src/contracts/public/canvas_pointer.dart:111` contains no `phase` branch.

### 4. Surface Pointer Adapter

- **Location**: primary `lib/src/surface/pointer_adapter.dart:5`.
- **Description**: `CanvasSurfacePointerAdapter` is a `StatelessWidget` that receives a child and `routeSample` callback at `lib/src/surface/pointer_adapter.dart:6`, `lib/src/surface/pointer_adapter.dart:7`, and `lib/src/surface/pointer_adapter.dart:8`. Its `Listener` maps Flutter pointer callbacks to `CanvasPointerLifecyclePhase.down`, `.move`, `.up`, and `.cancel` at `lib/src/surface/pointer_adapter.dart:19`, `lib/src/surface/pointer_adapter.dart:22`, `lib/src/surface/pointer_adapter.dart:25`, and `lib/src/surface/pointer_adapter.dart:28`.
- **Dependencies**: `_route` reads `event.localPosition` at `lib/src/surface/pointer_adapter.dart:36` and returns before routing when either coordinate is not finite at `lib/src/surface/pointer_adapter.dart:37`. If the position is finite, it reads `event.timeStamp` at `lib/src/surface/pointer_adapter.dart:40` and calls `routeSample(CanvasPointerSample(...))` at `lib/src/surface/pointer_adapter.dart:41`, using the event pointer id, local position, phase, kind, and a non-negative millisecond timestamp or null at `lib/src/surface/pointer_adapter.dart:43`, `lib/src/surface/pointer_adapter.dart:44`, `lib/src/surface/pointer_adapter.dart:45`, `lib/src/surface/pointer_adapter.dart:46`, and `lib/src/surface/pointer_adapter.dart:47`.
- **Data flow**: Flutter `PointerEvent` -> `event.localPosition` finite check -> public `CanvasPointerSample` construction -> `routeSample` callback. Non-finite local positions return before sample construction and before `routeSample`.

### 5. CanvasSurface to Runtime Surface Port

- **Location**: primary `lib/src/surface/canvas_surface_widget.dart:177`.
- **Description**: `_buildPaintHost` creates the `CustomPaint` host at `lib/src/surface/canvas_surface_widget.dart:208`, uses `MainFramePainter` and `OverlayFramePainter` at `lib/src/surface/canvas_surface_widget.dart:210` and `lib/src/surface/canvas_surface_widget.dart:211`, returns the paint host directly when `widget.interactive` is false at `lib/src/surface/canvas_surface_widget.dart:214`, and wraps it in `CanvasSurfacePointerAdapter` when interactive at `lib/src/surface/canvas_surface_widget.dart:218`.
- **Dependencies**: The adapter callback calls `port.handlePointer(_surfaceToken, sample)` at `lib/src/surface/canvas_surface_widget.dart:219` and `lib/src/surface/canvas_surface_widget.dart:220`. The surface imports the runtime surface bridge at `lib/src/surface/canvas_surface_widget.dart:4` and the pointer adapter at `lib/src/surface/canvas_surface_widget.dart:11`.
- **Data flow**: `CanvasPointerSample` from adapter -> closure with current `CanvasRuntimeSurfacePort` and `_surfaceToken` -> `CanvasRuntimeSurfacePort.handlePointer`.

### 6. Active Surface Port Guard

- **Location**: primary `lib/src/api/canvas_runtime_surface_bridge.dart:60`.
- **Description**: `CanvasRuntimeSurfacePort.handlePointer` checks `_root.isActiveSurface(token)` at `lib/src/api/canvas_runtime_surface_bridge.dart:61` and returns for inactive tokens at `lib/src/api/canvas_runtime_surface_bridge.dart:62`; otherwise it calls `_root.handlePointer(sample)` at `lib/src/api/canvas_runtime_surface_bridge.dart:64`.
- **Dependencies**: Surface ports are stored in an `Expando` at `lib/src/api/canvas_runtime_surface_bridge.dart:14`, attached to a runtime object at `lib/src/api/canvas_runtime_surface_bridge.dart:17`, and looked up by runtime object at `lib/src/api/canvas_runtime_surface_bridge.dart:25`. `RuntimeRoot.attachSurface` sets `_activeSurfaceToken` when no other token is active or the token is already active at `lib/src/runtime/runtime_root.dart:329`, `lib/src/runtime/runtime_root.dart:331`, and `lib/src/runtime/runtime_root.dart:332`; `detachSurface` clears it at `lib/src/runtime/runtime_root.dart:341` and `lib/src/runtime/runtime_root.dart:346`; `isActiveSurface` uses identity comparison at `lib/src/runtime/runtime_root.dart:351`.
- **Data flow**: Surface token + sample -> active-surface identity check -> runtime pointer handling or no-op return.

### 7. Runtime Public Tool Pointer Entry

- **Location**: primary `lib/src/contracts/public/canvas_tools.dart:110`; additional `lib/src/runtime/runtime_root.dart:2527`.
- **Description**: `CanvasToolPort` declares `handlePointer(CanvasPointerSample sample)` at `lib/src/contracts/public/canvas_tools.dart:121`. `_RuntimeToolPort.handlePointer` delegates to `root.handlePointer(sample)` at `lib/src/runtime/runtime_root.dart:2527`.
- **Dependencies**: `RuntimeRoot.handlePointer` calls `ensureRuntimeMutationAllowed()` at `lib/src/runtime/runtime_root.dart:1245`, sends the sample to `_interactionEngine.handlePointerSample` at `lib/src/runtime/runtime_root.dart:1247`, and supplies `viewCameraOffset`, `controllerEpoch`, selected ids, selection revision, and timestamp resolver in `InteractionPointerContext` at `lib/src/runtime/runtime_root.dart:1249`, `lib/src/runtime/runtime_root.dart:1250`, `lib/src/runtime/runtime_root.dart:1252`, `lib/src/runtime/runtime_root.dart:1253`, and `lib/src/runtime/runtime_root.dart:1254`.
- **Data flow**: External code or surface port -> `CanvasToolPort.handlePointer` or `RuntimeRoot.handlePointer` -> interaction engine admission -> commit delivery or runtime-state publication. Runtime publishes state when admission requests it at `lib/src/runtime/runtime_root.dart:1272`; commit/context admissions are checked at `lib/src/runtime/runtime_root.dart:1277`.

### 8. Interaction Normalization and Terminal Routing

- **Location**: primary `lib/src/interaction/interaction_engine.dart:344`.
- **Description**: `InteractionEngine.handlePointerSample` normalizes the public sample at `lib/src/interaction/interaction_engine.dart:348` and routes by phase at `lib/src/interaction/interaction_engine.dart:354`, sending down to `_handleDown`, move to `_handleMove`, and up/cancel to `_handleTerminal` at `lib/src/interaction/interaction_engine.dart:355`, `lib/src/interaction/interaction_engine.dart:356`, and `lib/src/interaction/interaction_engine.dart:357`.
- **Dependencies**: `PointerSampleNormalizer.normalizePublicSample` copies pointer id, view position, phase, kind, timestamp, and controller epoch at `lib/src/interaction/pointer_sample_normalizer.dart:50`, `lib/src/interaction/pointer_sample_normalizer.dart:52`, `lib/src/interaction/pointer_sample_normalizer.dart:54`, `lib/src/interaction/pointer_sample_normalizer.dart:55`, `lib/src/interaction/pointer_sample_normalizer.dart:56`, and `lib/src/interaction/pointer_sample_normalizer.dart:57`; it computes `worldPosition` as `sample.position + viewCameraOffset` at `lib/src/interaction/pointer_sample_normalizer.dart:53`.
- **Data flow**: `CanvasPointerSample.position` -> normalized `viewPosition` and `worldPosition` -> phase-specific pointer session handling.

### 9. Existing Invalid-Terminal Cleanup Classifier

- **Location**: primary `lib/src/interaction/pointer_sample_normalizer.dart:25`.
- **Description**: The normalizer defines `InvalidTerminalCleanupKind` with `none`, `noActiveSession`, `stalePointer`, and `staleControllerEpoch` at `lib/src/interaction/pointer_sample_normalizer.dart:25`, `lib/src/interaction/pointer_sample_normalizer.dart:26`, `lib/src/interaction/pointer_sample_normalizer.dart:27`, `lib/src/interaction/pointer_sample_normalizer.dart:28`, and `lib/src/interaction/pointer_sample_normalizer.dart:29`. `invalidTerminalCleanupDecision` returns `noActiveSession` when active pointer or epoch is missing at `lib/src/interaction/pointer_sample_normalizer.dart:67`, `stalePointer` when active pointer id differs at `lib/src/interaction/pointer_sample_normalizer.dart:73`, `staleControllerEpoch` when the epoch differs at `lib/src/interaction/pointer_sample_normalizer.dart:79`, and `none` otherwise at `lib/src/interaction/pointer_sample_normalizer.dart:86`.
- **Dependencies**: `_handleTerminal` calls `_terminalCleanupDecision` at `lib/src/interaction/interaction_engine.dart:830`; non-`none` decisions route to `_handleInvalidTerminal` at `lib/src/interaction/interaction_engine.dart:831`; cancel terminals route to cleanup at `lib/src/interaction/interaction_engine.dart:834`; active sessions route to active terminal handling at `lib/src/interaction/interaction_engine.dart:837`; terminals with no active session route to context-tap handling at `lib/src/interaction/interaction_engine.dart:840`.
- **Data flow**: Terminal normalized sample + active session identity -> invalid-terminal decision -> cleanup-only or ignored admission, or normal active-terminal/context-tap path.

### 10. Runtime Cleanup Outcome Application

- **Location**: primary `lib/src/interaction/interaction_engine.dart:1381`.
- **Description**: `_handleInvalidTerminal` records invalid-terminal cleanup at `lib/src/interaction/interaction_engine.dart:1385`, computes `shouldCleanup` from the decision and line-session rule at `lib/src/interaction/interaction_engine.dart:1386`, calls `_cleanupWithReason` when cleanup is needed at `lib/src/interaction/interaction_engine.dart:1390`, and returns `InteractionPointerAdmissionKind.cleanupOnly` or `ignored` at `lib/src/interaction/interaction_engine.dart:1395`, `lib/src/interaction/interaction_engine.dart:1396`, and `lib/src/interaction/interaction_engine.dart:1397`.
- **Dependencies**: `_cleanupWithReason` creates `PointerCleanupRequest` with reason, active preview kind, active token/session flags, pending line state, pending context-tap state, and context preservation flag at `lib/src/interaction/interaction_engine.dart:1652`, `lib/src/interaction/interaction_engine.dart:1657`, `lib/src/interaction/interaction_engine.dart:1658`, `lib/src/interaction/interaction_engine.dart:1659`, `lib/src/interaction/interaction_engine.dart:1660`, `lib/src/interaction/interaction_engine.dart:1661`, `lib/src/interaction/interaction_engine.dart:1662`, `lib/src/interaction/interaction_engine.dart:1663`, `lib/src/interaction/interaction_engine.dart:1664`, and `lib/src/interaction/interaction_engine.dart:1665`. The cleanup coordinator releases the session when `request.hasActiveSession` is true at `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:8` and `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:20`; `_applyCleanupOutcome` clears preview, pending line, pending context tap, and active session according to outcome flags at `lib/src/interaction/interaction_engine.dart:1722`, `lib/src/interaction/interaction_engine.dart:1726`, `lib/src/interaction/interaction_engine.dart:1730`, and `lib/src/interaction/interaction_engine.dart:1734`.
- **Data flow**: Invalid/stale terminal decision -> cleanup request -> cleanup outcome -> preview/session/pending-state mutation -> optional runtime state publication via admission.

### 11. Surface Interactive Disabled Cleanup Path

- **Location**: primary `lib/src/surface/canvas_surface_widget.dart:70`.
- **Description**: `CanvasSurface.didUpdateWidget` calls `handleSurfaceInteractiveDisabled` when `interactive` changes from true to false at `lib/src/surface/canvas_surface_widget.dart:70` and `lib/src/surface/canvas_surface_widget.dart:71`; `dispose` calls it for an interactive widget at `lib/src/surface/canvas_surface_widget.dart:76` and `lib/src/surface/canvas_surface_widget.dart:78`.
- **Dependencies**: `CanvasRuntimeSurfacePort.handleSurfaceInteractiveDisabled` checks the active surface token at `lib/src/api/canvas_runtime_surface_bridge.dart:53` and `lib/src/api/canvas_runtime_surface_bridge.dart:54`, then calls `_root.handleSurfaceInteractiveDisabled()` at `lib/src/api/canvas_runtime_surface_bridge.dart:57`. `RuntimeRoot.handleSurfaceInteractiveDisabled` calls `_interactionEngine.interactiveDisabledCleanup()`, applies cleanup selection effects, and publishes runtime state when needed at `lib/src/runtime/runtime_root.dart:1158`, `lib/src/runtime/runtime_root.dart:1160`, `lib/src/runtime/runtime_root.dart:1161`, and `lib/src/runtime/runtime_root.dart:1162`. `interactiveDisabledCleanup` delegates to `_cleanupWithReason(PointerCleanupReason.interactiveDisabled)` at `lib/src/interaction/interaction_engine.dart:245`.
- **Data flow**: Widget lifecycle interactive disable/dispose -> active surface port guard -> runtime interactive-disabled cleanup -> cleanup outcome application and optional state publication.

### 12. Test Coverage Around Pointer Finite and Cleanup Behavior

- **Location**: primary `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:13`.
- **Description**: The surface fixture tests finite mapping from Flutter down/move/up/cancel to public samples at `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:13`, routes finite events at `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:59`, and expects phases down/move/up/cancel at `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:94`. It routes non-finite move events at `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:114` and verifies sample count remains four after those events at `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:55`.
- **Dependencies**: The same fixture asserts that non-finite surface events have no runtime effects at `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:211`, routes non-finite down/move events at `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:229`, and verifies no preview, state, document, or action changes at `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:320`.
- **Data flow**: Test `Listener` callbacks -> finite mapping assertions or non-finite down/move no-effect assertions.

### 13. Test Coverage Around Runtime Cleanup

- **Location**: primary `test/interaction/pointer_session_test.dart:21`.
- **Description**: Interaction tests cover stale terminal epoch cleanup at `test/interaction/pointer_session_test.dart:21`, creating an active session with controller epoch 1 at `test/interaction/pointer_session_test.dart:113`, sending terminal `up` with controller epoch 2 at `test/interaction/pointer_session_test.dart:119`, and expecting `cleanupOnly`, `InvalidTerminalCleanupKind.staleControllerEpoch`, and a null active session at `test/interaction/pointer_session_test.dart:124`, `test/interaction/pointer_session_test.dart:126`, and `test/interaction/pointer_session_test.dart:129`.
- **Dependencies**: The same test file covers admitted cancel terminal cleanup at `test/interaction/pointer_session_test.dart:133`, sends cancel at `test/interaction/pointer_session_test.dart:140`, and expects `cleanupOnly` with no active session at `test/interaction/pointer_session_test.dart:145` and `test/interaction/pointer_session_test.dart:146`. Runtime cleanup timestamp tests include cancel and no-op terminal cleanup paths in `_cleanupTimestampPaths` at `test/runtime/fixtures/draw_cleanup_integration_fixture.dart:21`, `test/runtime/fixtures/draw_cleanup_integration_fixture.dart:26`, and `test/runtime/fixtures/draw_cleanup_integration_fixture.dart:27`.
- **Data flow**: Direct interaction/runtime pointer samples -> terminal routing -> cleanup-only admission or runtime cleanup path -> active session/preview cleared.

### 14. Test Coverage Around Surface Lifecycle Cleanup

- **Location**: primary `test/surface/fixtures/interactive_false_surface_test_support.dart:28`.
- **Description**: Surface lifecycle tests create an active stroke session at `test/surface/fixtures/interactive_false_surface_test_support.dart:83`, assert the preview is `CanvasPencilStrokePreview` after down at `test/surface/fixtures/interactive_false_surface_test_support.dart:90`, switch to `interactive: false` at `test/surface/fixtures/interactive_false_surface_test_support.dart:101`, and expect `CanvasNoPreview` and no pointer adapter after cleanup at `test/surface/fixtures/interactive_false_surface_test_support.dart:104` and `test/surface/fixtures/interactive_false_surface_test_support.dart:105`.
- **Dependencies**: The same helper sends a stale gesture `up` after re-enabling interactivity at `test/surface/fixtures/interactive_false_surface_test_support.dart:119` and `test/surface/fixtures/interactive_false_surface_test_support.dart:125`, then expects no runtime effects at `test/surface/fixtures/interactive_false_surface_test_support.dart:127`.
- **Data flow**: Active surface pointer session -> widget interactive false -> surface-port cleanup -> runtime preview cleared -> stale old terminal ignored.

## Code References

- Retired stage-report scratchpad - API-002 issue id and public invalid-terminal cleanup expectation.
- Retired stage-report scratchpad - SURFACE-002 issue id and non-finite terminal event drop before cleanup routing.
- `docs/contracts/public_api_v1.md:1787` - Public contract validation rule for down/move finite position and invalid terminal cleanup routing.
- `lib/src/contracts/public/canvas_pointer.dart:100` - Public sample factory validates `position`.
- `lib/src/contracts/public/canvas_pointer.dart:105` - Public sample factory constructs the private value after validation.
- `lib/src/surface/pointer_adapter.dart:37` - Surface adapter drops non-finite local positions before routing.
- `lib/src/surface/pointer_adapter.dart:41` - Surface adapter routes by constructing `CanvasPointerSample`.
- `lib/src/surface/canvas_surface_widget.dart:218` - Interactive surface installs `CanvasSurfacePointerAdapter`.
- `lib/src/surface/canvas_surface_widget.dart:220` - Surface callback calls `port.handlePointer`.
- `lib/src/api/canvas_runtime_surface_bridge.dart:60` - Surface port pointer entry point.
- `lib/src/api/canvas_runtime_surface_bridge.dart:61` - Surface port active-token guard.
- `lib/src/runtime/runtime_root.dart:1247` - Runtime root sends samples to the interaction engine.
- `lib/src/interaction/interaction_engine.dart:348` - Interaction engine normalizes public pointer samples.
- `lib/src/interaction/interaction_engine.dart:357` - Up/cancel phases route to terminal handling.
- `lib/src/interaction/interaction_engine.dart:1381` - Invalid-terminal handling entry.
- `lib/src/interaction/pointer_sample_normalizer.dart:61` - Invalid-terminal cleanup decision API.
- `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:20` - Cleanup outcome releases an active session when present.
- `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:211` - Existing non-finite surface event no-effect fixture entry.
- `test/interaction/pointer_session_test.dart:21` - Existing stale terminal cleanup test.
- `test/surface/fixtures/interactive_false_surface_test_support.dart:95` - Existing interactive-false cleanup helper.

## Search Coverage

- **Inspected**: retired stage-report scratchpad; `lib/src/contracts/public/canvas_pointer.dart:1-141`; `lib/src/surface/pointer_adapter.dart:1-51`; `lib/src/api/canvas_runtime_surface_bridge.dart:1-113`; `lib/src/contracts/public/canvas_tools.dart:1-123`; `lib/iwb_canvas_engine.dart:1-18`; `lib/src/api/canvas_pointer.dart:1`; `lib/src/api/canvas_tools.dart:1`; `lib/src/api/canvas_surface.dart:1-3`; `docs/contracts/public_api_v1.md:1568-1798`; `docs/_registry/public_api_v1.yaml:1-120`; `lib/src/runtime/runtime_root.dart:328-356`, `lib/src/runtime/runtime_root.dart:1157-1165`, `lib/src/runtime/runtime_root.dart:1244-1275`, `lib/src/runtime/runtime_root.dart:1277-1325`, `lib/src/runtime/runtime_root.dart:2521-2534`; `lib/src/interaction/interaction_engine.dart:240-247`, `lib/src/interaction/interaction_engine.dart:343-390`, `lib/src/interaction/interaction_engine.dart:824-871`, `lib/src/interaction/interaction_engine.dart:1369-1436`, `lib/src/interaction/interaction_engine.dart:1652-1738`, `lib/src/interaction/interaction_engine.dart:1781-1811`; `lib/src/interaction/pointer_sample_normalizer.dart:1-90`; `lib/src/interaction/interaction_pointer_context.dart:1-72`; `lib/src/interaction/pointer_cleanup_protocol.dart:1-91`; `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:1-89`; `lib/src/surface/canvas_surface_widget.dart:1-262`; `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:1-336`; `test/surface/pointer_adapter_finite_normalization_test.dart:1-33`; `test/interaction/pointer_sample_normalizer_test.dart:1-76`; `test/interaction/pointer_session_test.dart:1-160`; `test/runtime/fixtures/draw_cleanup_integration_fixture.dart:1-155`; `test/surface/fixtures/interactive_false_surface_test_support.dart:1-368`.
- **Searched**: retired scratchpad API-002/SURFACE-002 issue text; `rg -n "CanvasPointerSample|CanvasPointerLifecyclePhase|handlePointer|routeSample|invalid terminal|terminal samples|pointer position|non-finite|finite" lib docs test example`; `rg --files lib/src/surface test/surface lib/src/contracts/public test/api test/api_contract docs/contracts docs/_registry`; `rg -n "class CanvasRuntime|CanvasRuntimeSurfacePort|routeSample|handlePointer|_routePointer|PointerCancel|PointerUp|CanvasNoPreview|preview" lib/src/runtime lib/src/interaction test/runtime test/interaction test/api test/api_contract`; `rg -n "handlePointerSample|invalidTerminal|cleanupActive|isTerminal|CanvasPointerLifecyclePhase\\.cancel|CanvasPointerLifecyclePhase\\.up|normalizePublicSample" lib/src/interaction/interaction_engine.dart lib/src/interaction/pointer_session.dart lib/src/interaction/pointer_cleanup_protocol.dart lib/src/interaction/pointer_tool_cleanup_coordinator.dart`; `rg -n "final class InteractionPointerAdmission|enum InteractionPointerAdmissionKind|cleanupOnly|selectedMoveCommit|drawStrokeCommit|publishRuntimeState" lib/src/interaction lib/src/runtime/runtime_root.dart`.
- **Not found**: No inspected public API or runtime test constructs `CanvasPointerSample` with a non-finite `up` or `cancel` position through `runtime.tools.handlePointer`. Non-finite pointer sample coverage found in the inspected surface fixture uses non-finite down/move events at `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:229`, and the adapter-only helper routes non-finite move events at `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:114`. `test/surface/pointer_adapter_finite_normalization_test.dart:30`, `test/surface/pointer_adapter_finite_normalization_test.dart:31`, and `test/surface/pointer_adapter_finite_normalization_test.dart:32` assert that `PointerSampleNormalizer`, `viewCameraOffset`, and `worldPosition` are absent from `lib/src/surface/pointer_adapter.dart`.
- **Not inspected**: Full draw/select/move/eraser machine internals beyond immediate pointer terminal dispatch and cleanup paths; full API contract outside the tools/pointer section; documentation generation tooling; architecture graph artifacts. These areas were outside the API-002/SURFACE-002 question unless directly reached by the pointer entry, surface boundary, or cleanup-routing path.

## Observed Architecture Facts

- Public pointer DTO export is registry-backed: `CanvasPointerSample` and `CanvasPointerLifecyclePhase` are listed in `docs/_registry/public_api_v1.yaml:66` and `docs/_registry/public_api_v1.yaml:67`, exposed through `lib/src/api/canvas_pointer.dart:1`, and exported from the root barrel at `lib/iwb_canvas_engine.dart:12`.
- Public contract and public constructor differ in validation shape: `docs/contracts/public_api_v1.md:1787` distinguishes down/move finite positions from invalid terminal cleanup routing, while `lib/src/contracts/public/canvas_pointer.dart:100` validates `position` before sample construction without using `phase`.
- Surface event flow is Listener-only local-position admission: Flutter `Listener` callbacks are installed at `lib/src/surface/pointer_adapter.dart:17`, phase mapping occurs at `lib/src/surface/pointer_adapter.dart:19`, `lib/src/surface/pointer_adapter.dart:22`, `lib/src/surface/pointer_adapter.dart:25`, and `lib/src/surface/pointer_adapter.dart:28`, and non-finite positions return at `lib/src/surface/pointer_adapter.dart:37`.
- Runtime world normalization is downstream of both public and surface boundaries: `RuntimeRoot.handlePointer` calls the interaction engine at `lib/src/runtime/runtime_root.dart:1247`, and the normalizer computes `worldPosition` from `sample.position + viewCameraOffset` at `lib/src/interaction/pointer_sample_normalizer.dart:53`.
- Invalid-terminal cleanup exists after sample admission: `_handleTerminal` routes non-`none` invalid-terminal decisions to `_handleInvalidTerminal` at `lib/src/interaction/interaction_engine.dart:831`, and `_handleInvalidTerminal` returns cleanup-only admission when cleanup is selected at `lib/src/interaction/interaction_engine.dart:1395`.
- Surface lifecycle cleanup is separate from terminal event cleanup: interactive disable is sent through `CanvasRuntimeSurfacePort.handleSurfaceInteractiveDisabled` at `lib/src/api/canvas_runtime_surface_bridge.dart:53`, then through `RuntimeRoot.handleSurfaceInteractiveDisabled` at `lib/src/runtime/runtime_root.dart:1158`, and not through `CanvasSurfacePointerAdapter._route`.

## Open Questions

- No code path was found in the inspected API or surface tests that covers finite down followed by non-finite terminal up/cancel through `CanvasSurfacePointerAdapter`.
- No public constructor path was found in the inspected files that represents a non-finite terminal `CanvasPointerSample`.
