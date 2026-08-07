---
date: 2026-06-13
researcher: Codex
commit: e85188a9
branch: new-architecture
research_question: "SURFACE-001: CanvasSurface silently collapses to zero size under unbounded layout constraints"
---

# Research: CanvasSurface Unbounded Layout

## Summary

`CanvasSurface` currently derives its paint size from Flutter layout constraints inside `LayoutBuilder`. Finite maximum width and height become the `CustomPaint.size`; any non-finite maximum dimension becomes `0.0`. The same derived size becomes the surface viewport via `Offset.zero & paintSize`, and that viewport is passed into both main and overlay frame capture.

The inspected public contract documents `CanvasSurface` construction, active-surface lifecycle, pointer routing, `interactive=false`, and resource-session behavior, but it does not define a layout-constraints contract for bounded or unbounded parents. Existing tests mount `CanvasSurface` through bounded hosts and verify paint host, painter, resource, pointer, and lifecycle behavior; no inspected test directly asserts `CanvasSurface` layout size or covers unbounded widget constraints.

## Detailed Findings

### 1. CanvasSurface Layout-To-Paint Path

- **Location**: `lib/src/surface/canvas_surface_widget.dart:84`
- **Description**: `CanvasSurface.build` obtains the current surface port and returns `SizedBox.shrink()` when no current port exists at `lib/src/surface/canvas_surface_widget.dart:86` and `lib/src/surface/canvas_surface_widget.dart:88`.
- **Dependencies**: The widget uses `ValueListenableBuilder` on `port.state` at `lib/src/surface/canvas_surface_widget.dart:91` and `LayoutBuilder` at `lib/src/surface/canvas_surface_widget.dart:94`.
- **Data flow**: `BoxConstraints` enter the layout builder at `lib/src/surface/canvas_surface_widget.dart:95`; `_paintSizeFor(constraints)` computes `paintSize` at `lib/src/surface/canvas_surface_widget.dart:96`; `Offset.zero & paintSize` becomes `viewport` at `lib/src/surface/canvas_surface_widget.dart:97`; `_buildPaintHost` receives both values at `lib/src/surface/canvas_surface_widget.dart:99`.

`_paintSizeFor` returns a `Size` at `lib/src/surface/canvas_surface_widget.dart:226`. It uses `constraints.maxWidth` only if finite and otherwise `0.0` at `lib/src/surface/canvas_surface_widget.dart:228`; it uses `constraints.maxHeight` only if finite and otherwise `0.0` at `lib/src/surface/canvas_surface_widget.dart:229`.

### 2. Paint Size And Viewport Consumers

- **Location**: `lib/src/surface/canvas_surface_widget.dart:177`
- **Description**: `_buildPaintHost` consumes the surface port, derived `paintSize`, derived `viewport`, and device pixel ratio.
- **Dependencies**: `_buildPaintHost` calls the runtime surface port, creates `MainFramePainter`, creates `OverlayFramePainter`, and optionally wraps the paint host in `CanvasSurfacePointerAdapter`.
- **Data flow**: The derived `viewport` is passed to `port.buildSurfaceMainFrame` as `viewportWorldBounds` at `lib/src/surface/canvas_surface_widget.dart:187` and `lib/src/surface/canvas_surface_widget.dart:189`. The same `viewport` is passed to `port.buildSurfaceOverlayFrame` as `viewportWorldBounds` at `lib/src/surface/canvas_surface_widget.dart:200` and `lib/src/surface/canvas_surface_widget.dart:202`. The derived `paintSize` is assigned to `CustomPaint.size` at `lib/src/surface/canvas_surface_widget.dart:208` and `lib/src/surface/canvas_surface_widget.dart:212`.

The surface bridge keeps `viewportWorldBounds` explicit in `buildSurfaceMainFrame` at `lib/src/api/canvas_runtime_surface_bridge.dart:70` and forwards it to `RuntimeRoot.buildMainFrameWithAssetBindings` at `lib/src/api/canvas_runtime_surface_bridge.dart:83`. Overlay frame building has the same explicit `viewportWorldBounds` input at `lib/src/api/canvas_runtime_surface_bridge.dart:95` and forwards it to `RuntimeRoot.buildResourceFreeOverlayFrame` at `lib/src/api/canvas_runtime_surface_bridge.dart:106`.

`RuntimeRoot._frameInputs` accepts `viewportWorldBounds` at `lib/src/runtime/runtime_root.dart:430` and stores it in `FrameCaptureInputs` at `lib/src/runtime/runtime_root.dart:436` and `lib/src/runtime/runtime_root.dart:437`. `FrameCaptureInputs` owns `viewportWorldBounds` at `lib/src/frame/captured_frame.dart:24`, and `effectiveWorldBounds` shifts it by camera offset at `lib/src/frame/captured_frame.dart:34`.

Main frame capture stores the inputs in `CapturedFrameSnapshot.inputs` at `lib/src/frame/frame_capture_service.dart:74` and `lib/src/frame/frame_capture_service.dart:81`. Overlay frame capture stores `viewportWorldBounds` and `effectiveWorldBounds` at `lib/src/frame/frame_capture_service.dart:40`, `lib/src/frame/frame_capture_service.dart:42`, and `lib/src/frame/frame_capture_service.dart:43`.

### 3. Painter And Pointer Behavior

- **Location**: `lib/src/surface/main_painter.dart:15`
- **Description**: Painters use captured viewport facts and the `CustomPaint` paint callback size.
- **Dependencies**: Main painter consumes `MainFramePaintOutput`; overlay painter consumes `OverlayFramePaintOutput`.
- **Data flow**: `MainFramePainter.paint` reads `output.capturedFrame.snapshot.inputs.effectiveWorldBounds` at `lib/src/surface/main_painter.dart:16`, clips to `Offset.zero & size` at `lib/src/surface/main_painter.dart:22`, translates by the negative viewport origin at `lib/src/surface/main_painter.dart:23`, and paints records at `lib/src/surface/main_painter.dart:25`. `OverlayFramePainter.paint` reads `output.capturedFrame.effectiveWorldBounds` at `lib/src/surface/overlay_painter.dart:16`, clips to `Offset.zero & size` at `lib/src/surface/overlay_painter.dart:18`, translates at `lib/src/surface/overlay_painter.dart:19`, and paints overlay primitives at `lib/src/surface/overlay_painter.dart:20`.

When `interactive` is false, `_buildPaintHost` returns the `CustomPaint` directly at `lib/src/surface/canvas_surface_widget.dart:214` and `lib/src/surface/canvas_surface_widget.dart:215`. When `interactive` is true, `_buildPaintHost` wraps the paint host in `CanvasSurfacePointerAdapter` at `lib/src/surface/canvas_surface_widget.dart:218` and routes input to `port.handlePointer(_surfaceToken, input)` at `lib/src/surface/canvas_surface_widget.dart:219`.

`CanvasSurfacePointerAdapter` uses a `Listener` at `lib/src/surface/pointer_adapter.dart:17` with opaque hit testing at `lib/src/surface/pointer_adapter.dart:18`. It reads `event.localPosition` at `lib/src/surface/pointer_adapter.dart:36`, drops non-finite down/move positions, routes non-finite up/cancel as terminal cleanup at `lib/src/surface/pointer_adapter.dart:37` and `lib/src/surface/pointer_adapter.dart:40`, and routes finite positions as `CanvasPointerSample(position: position)` at `lib/src/surface/pointer_adapter.dart:52`.

### 4. Public Contracts And Guardrails

- **Location**: `docs/contracts/public_api_v1.md:502`
- **Description**: The public API contract defines `CanvasSurface` as a Flutter surface with `runtime`, optional `resourceResolver`, `selectionStyle`, `gridStyle`, and `interactive`.
- **Dependencies**: The contract links surface behavior to runtime attachment, pointer routing, and resource sessions.
- **Data flow**: The surface contract starts at `docs/contracts/public_api_v1.md:523`. It states that one active `CanvasSurface` is supported per `CanvasRuntime` at `docs/contracts/public_api_v1.md:527`, that `interactive=false` surfaces are still active at `docs/contracts/public_api_v1.md:530`, that `interactive=false` still paints the document at `docs/contracts/public_api_v1.md:539`, and that `CanvasSurface` routes finite pointer samples plus terminal cleanup input at `docs/contracts/public_api_v1.md:551`.

The frame rendering contract states that `CapturedMainFrame` includes `viewportRect` and `devicePixelRatio` at `docs/contracts/frame_rendering.md:63`; overlay paint captures one compact overlay frame from surface/runtime value inputs at `docs/contracts/frame_rendering.md:115`; cache policy includes `viewportRect` in cache keys at `docs/contracts/cache_policy.md:42`. These inspected contract locations describe frame/cache viewport facts, not the Flutter widget's layout-constraint policy.

The guardrail registry marks `surface.pointer_samples_normalized_before_runtime` as a blocking surface guardrail at `tool/guardrails/src/guardrail_registry.dart:282` and `surface.interactive_false_pending_line_preserved` at `tool/guardrails/src/guardrail_registry.dart:287`. The executor maps the pointer guardrail to `test/guardrails/import_boundaries_test.dart` and `test/surface/pointer_adapter_finite_normalization_test.dart` at `tool/guardrails/src/guardrail_executor.dart:350`, and maps the interactive-false guardrail to import-boundary plus surface behavior tests at `tool/guardrails/src/guardrail_executor.dart:354`. `docs/verification/guardrails.md:255` describes the pointer guardrail as finite sample or terminal cleanup routing without world normalization; `docs/verification/guardrails.md:256` describes interactive-false cleanup and preservation. No inspected guardrail entry describes `CanvasSurface` layout sizing or unbounded constraints.

### 5. Test Coverage Observed

- **Location**: `test/surface/fixtures/widget_paint_fixture.dart:242`
- **Description**: Surface widget tests use bounded hosts.
- **Dependencies**: Tests mount `CanvasSurface`, inspect the paint host key, inspect painter types, and exercise resource, pointer, and lifecycle behavior.
- **Data flow**: `_SurfaceHost` in `widget_paint_fixture.dart` wraps `CanvasSurface` in `SizedBox(width: 100, height: 100)` at `test/surface/fixtures/widget_paint_fixture.dart:252` and `test/surface/fixtures/widget_paint_fixture.dart:255`. The public smoke test mounts `CanvasSurface` in `SizedBox(width: 120, height: 80)` at `test/smoke/public_incremental_smoke_test.dart:39` and `test/smoke/public_incremental_smoke_test.dart:42`; its reusable `_surfaceHost` does the same at `test/smoke/public_incremental_smoke_test.dart:1254` and `test/smoke/public_incremental_smoke_test.dart:1257`. Pointer-adapter surface tests mount in `SizedBox(width: 100, height: 100)` at `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:462` and `test/surface/fixtures/pointer_adapter_finite_normalization_fixture.dart:465`. Single-active-surface fixtures use bounded hosts at `test/surface/fixtures/single_active_surface_fixture.dart:219`.

Painter-level clipping tests call painters with explicit sizes. `MainFramePainter` is painted with `const Size(32, 32)` at `test/surface/fixtures/main_painter_clipping_fixture.dart:21` and asserts an outside pixel is transparent at `test/surface/fixtures/main_painter_clipping_fixture.dart:25`. `OverlayFramePainter` is painted with `const Size(32, 32)` at `test/surface/fixtures/overlay_painter_clipping_fixture.dart:19` and `test/surface/fixtures/overlay_painter_clipping_fixture.dart:21` and asserts an outside pixel is transparent at `test/surface/fixtures/overlay_painter_clipping_fixture.dart:25`.

The inspected test searches did not find a direct `CanvasSurface` size assertion through `tester.getSize`, a zero-sized `CanvasSurface`, or an unbounded-layout host using `UnconstrainedBox`, `OverflowBox`, explicit `BoxConstraints`, `ListView`, or `ScrollView` in the searched surface/smoke/example/API-contract areas.

## Code References

- `lib/src/surface/canvas_surface_widget.dart:96` - layout builder converts constraints to paint size.
- `lib/src/surface/canvas_surface_widget.dart:97` - paint size becomes the viewport rectangle.
- `lib/src/surface/canvas_surface_widget.dart:187` - main frame build receives the derived viewport.
- `lib/src/surface/canvas_surface_widget.dart:200` - overlay frame build receives the same derived viewport.
- `lib/src/surface/canvas_surface_widget.dart:208` - `CustomPaint` is created as the paint host.
- `lib/src/surface/canvas_surface_widget.dart:212` - `CustomPaint.size` is set to the derived paint size.
- `lib/src/surface/canvas_surface_widget.dart:226` - `_paintSizeFor` owns constraint-to-size conversion.
- `lib/src/api/canvas_runtime_surface_bridge.dart:70` - main frame bridge accepts explicit viewport input.
- `lib/src/api/canvas_runtime_surface_bridge.dart:95` - overlay frame bridge accepts explicit viewport input.
- `lib/src/runtime/runtime_root.dart:430` - runtime creates frame inputs from viewport/style/DPR facts.
- `lib/src/frame/captured_frame.dart:34` - effective world bounds are derived from viewport plus camera offset.
- `lib/src/frame/frame_capture_service.dart:40` - overlay capture stores viewport and effective bounds.
- `lib/src/surface/main_painter.dart:16` - main painter reads captured effective bounds.
- `lib/src/surface/overlay_painter.dart:16` - overlay painter reads captured effective bounds.
- `lib/src/surface/pointer_adapter.dart:36` - pointer adapter reads Flutter local position.
- `docs/contracts/public_api_v1.md:523` - public surface behavior contract begins.
- `docs/verification/guardrails.md:255` - pointer surface guardrail covers routing and normalization ownership.
- `test/surface/fixtures/widget_paint_fixture.dart:252` - common widget paint test host provides bounded size.
- `test/smoke/public_incremental_smoke_test.dart:1254` - public smoke surface host provides bounded size.

## Search Coverage

- Inspected: `lib/src/surface/canvas_surface_widget.dart`, `lib/src/surface/main_painter.dart`, `lib/src/surface/overlay_painter.dart`, `lib/src/surface/pointer_adapter.dart`, `lib/src/api/canvas_runtime_surface_bridge.dart`, relevant frame input/capture paths in `lib/src/runtime/runtime_root.dart`, `lib/src/frame/captured_frame.dart`, and `lib/src/frame/frame_capture_service.dart`.
- Inspected: `docs/contracts/public_api_v1.md`, `docs/contracts/frame_rendering.md`, `docs/contracts/cache_policy.md`, `docs/contracts/resources.md`, `docs/architecture/02_package_boundaries.md`, `docs/verification/tests.md`, `docs/verification/guardrails.md`, `tool/guardrails/src/core_boundary_checks.dart`, `tool/guardrails/src/guardrail_registry.dart`, and `tool/guardrails/src/guardrail_executor.dart`.
- Inspected: surface/smoke/example/API-contract test areas that mention `CanvasSurface`, paint host keys, `CustomPaint`, bounded hosts, pointer routing, and painter clipping.
- Searched: `_paintSizeFor`, `CanvasSurface`, `paint_host`, `CustomPaint`, `BoxConstraints`, `hasBounded`, `constraints`, `maxWidth`, `maxHeight`, `bounded`, `unbounded`, `UnconstrainedBox`, `OverflowBox`, `ListView`, `ScrollView`, `Size.zero`, `width: 0`, `height: 0`, `getSize`, `viewportWorldBounds`, `effectiveWorldBounds`, `SizedBox.shrink`, and `placeholder`.
- Not found: a documented `CanvasSurface` layout-constraints policy, a guardrail that enforces bounded constraints for `CanvasSurface`, a direct `CanvasSurface` widget size assertion, or an unbounded-layout test host for `CanvasSurface`.
- Not inspected: Flutter framework documentation and unrelated production owners outside the surface/frame/runtime/pointer path.

## Observed Architecture Facts

- Pattern observed: `CanvasSurface` is the Flutter boundary that converts layout constraints into frame inputs; runtime/frame code receives an already computed `viewportWorldBounds` through explicit bridge parameters.
- Data flow: Flutter `BoxConstraints` -> `_paintSizeFor` -> `paintSize` -> `viewport` -> `CanvasRuntimeSurfacePort` -> `RuntimeRoot._frameInputs` -> frame capture -> surface painters.
- Key dependencies: surface owns Flutter widgets and pointer adapter; runtime surface bridge token-checks active-surface access; frame capture and painters consume immutable viewport inputs.

## Open Questions

- Whether the intended product behavior under unbounded Flutter constraints should be debug-only assertion, release-mode domain error, or a visible placeholder is not defined in the inspected repository sources.
- Whether the public contract should state that `CanvasSurface` requires bounded width and height is not defined in the inspected repository sources.
