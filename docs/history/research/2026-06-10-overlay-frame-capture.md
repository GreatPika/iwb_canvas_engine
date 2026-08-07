---
date: 2026-06-10
researcher: Codex
commit: 6524ace0
branch: new-architecture
research_question: "How overlay frame capture, planning, painting, and tests are structured today for FRAME-001"
---

# Research: Overlay Frame Capture

## Summary

The frame rendering contract describes `CapturedOverlayFrame` as the overlay-side frame shape containing preview revision, view camera revision and offset, preview state, and selection style (`docs/contracts/frame_rendering.md:85`). The code representation of `CapturedOverlayFrame` currently contains a shared `CapturedFrameSnapshot` and a nullable `CanvasPreviewState` overlay preview (`lib/src/frame/captured_frame.dart:90`, `lib/src/frame/captured_frame.dart:96`).

The production overlay path enters through the runtime surface bridge, passes through `RuntimeRoot.buildResourceFreeOverlayFrame`, delegates to `FrameEngine.buildResourceFreeOverlayFrame`, captures an overlay frame, builds an `OverlayPreviewPlan`, and paints primitives in `OverlayFramePainter` (`lib/src/api/canvas_runtime_surface_bridge.dart:95`, `lib/src/runtime/runtime_root.dart:413`, `lib/src/frame/frame_engine.dart:152`, `lib/src/surface/overlay_painter.dart:15`). The overlay capture call uses the same `_captureSnapshot` method used by main capture (`lib/src/frame/frame_capture_service.dart:40`, `lib/src/frame/frame_capture_service.dart:52`).

The current tests cover preview routing, captured style, overlay primitive admission, and the shared capture read sequence. `test/frame/fixtures/main_overlay_capture_fixture.dart` expects both main and overlay capture requests to read frame revisions, background, selected handles, resolved elements, resource descriptors, selection facts, and spatial queries (`test/frame/fixtures/main_overlay_capture_fixture.dart:118`, `test/frame/fixtures/main_overlay_capture_fixture.dart:131`).

## Detailed Findings

### 1. Frame Contract Shape

- **Location**: primary `docs/contracts/frame_rendering.md:61`.
- **Description**: The contract lists main frame fields from `documentRevision` through `selectedMoveDelta` (`docs/contracts/frame_rendering.md:63`, `docs/contracts/frame_rendering.md:66`, `docs/contracts/frame_rendering.md:82`). It lists overlay frame fields as `previewRevision`, `viewCameraRevision`, `viewCameraOffset`, `previewState`, and `selectionStyle` (`docs/contracts/frame_rendering.md:85`, `docs/contracts/frame_rendering.md:88`, `docs/contracts/frame_rendering.md:93`).
- **Dependencies**: The same contract states that committed frame facts enter `FrameEngine` through `FrameFactsPort` (`docs/contracts/frame_rendering.md:107`, `docs/contracts/frame_rendering.md:109`) and that `OverlayPreviewPlanner` owns immutable overlay primitives admitted from `CapturedOverlayFrame` (`docs/contracts/frame_rendering.md:152`, `docs/contracts/frame_rendering.md:160`).
- **Data flow**: Contract text maps public preview variants into frame paths: `CanvasSelectedMovePreview` is captured for the main-scene selected supplement path, while marquee, pencil, marker, pending line start, line, and eraser previews are admitted by overlay frame capture (`docs/contracts/frame_rendering.md:96`, `docs/contracts/frame_rendering.md:100`).

### 2. Captured Frame Code Model

- **Location**: primary `lib/src/frame/captured_frame.dart:11`.
- **Description**: `FrameCaptureInputs` stores viewport bounds, view camera offset, device pixel ratio, selection style, grid style, preview, preview revision, and optional text edit suppression (`lib/src/frame/captured_frame.dart:11`, `lib/src/frame/captured_frame.dart:23`, `lib/src/frame/captured_frame.dart:30`). Its `effectiveWorldBounds` shifts the viewport by the view camera offset (`lib/src/frame/captured_frame.dart:32`).
- **Dependencies**: `captured_frame.dart` imports frame facts, selection facts, text edit suppression, public document and preview types, surface styles, and spatial query results (`lib/src/frame/captured_frame.dart:3`, `lib/src/frame/captured_frame.dart:9`).
- **Data flow**: `CapturedFrameSnapshot` stores frame revisions, captured handles, resolved element facts, resource descriptors, background, selection facts, capture inputs, spatial paint result, and admitted spatial paint candidates (`lib/src/frame/captured_frame.dart:35`, `lib/src/frame/captured_frame.dart:54`, `lib/src/frame/captured_frame.dart:62`). `CapturedMainFrame` wraps that snapshot plus selected-move preview (`lib/src/frame/captured_frame.dart:80`, `lib/src/frame/captured_frame.dart:86`). `CapturedOverlayFrame` wraps that snapshot plus nullable overlay preview (`lib/src/frame/captured_frame.dart:90`, `lib/src/frame/captured_frame.dart:96`).

### 3. Capture Service

- **Location**: primary `lib/src/frame/frame_capture_service.dart:15`.
- **Description**: `FrameCaptureService` is constructed with `FrameFactsPort`, `SelectionFactsPort`, and a spatial paint query callback (`lib/src/frame/frame_capture_service.dart:16`, `lib/src/frame/frame_capture_service.dart:17`, `lib/src/frame/frame_capture_service.dart:19`). `captureMainFrame` and `captureOverlayFrame` both call `_captureSnapshot(inputs)` (`lib/src/frame/frame_capture_service.dart:28`, `lib/src/frame/frame_capture_service.dart:29`, `lib/src/frame/frame_capture_service.dart:40`, `lib/src/frame/frame_capture_service.dart:41`).
- **Dependencies**: `_captureSnapshot` reads `frameRevisions`, `selectionFacts`, spatial query results, spatial admission, selected ids, resolved elements, resource descriptors, and background (`lib/src/frame/frame_capture_service.dart:52`, `lib/src/frame/frame_capture_service.dart:53`, `lib/src/frame/frame_capture_service.dart:55`, `lib/src/frame/frame_capture_service.dart:56`, `lib/src/frame/frame_capture_service.dart:59`, `lib/src/frame/frame_capture_service.dart:69`, `lib/src/frame/frame_capture_service.dart:76`).
- **Data flow**: `_capturedHandles` appends spatial candidates first and then selected element handles not already seen (`lib/src/frame/frame_capture_service.dart:84`, `lib/src/frame/frame_capture_service.dart:91`, `lib/src/frame/frame_capture_service.dart:96`). `_resolvedElementsAndDescriptors` resolves every captured handle through `_frameFacts.resolveElement` and collects descriptors for resource-bearing elements through `_frameFacts.resourceDescriptor` (`lib/src/frame/frame_capture_service.dart:109`, `lib/src/frame/frame_capture_service.dart:117`, `lib/src/frame/frame_capture_service.dart:141`).

### 4. Runtime And Surface Pipeline

- **Location**: primary `lib/src/runtime/runtime_root.dart:374`.
- **Description**: `RuntimeRoot.buildResourceFreeMainFrame`, `RuntimeRoot.buildMainFrameWithAssetBindings`, and `RuntimeRoot.buildResourceFreeOverlayFrame` all create `FrameCaptureInputs` through `_frameInputs` (`lib/src/runtime/runtime_root.dart:374`, `lib/src/runtime/runtime_root.dart:394`, `lib/src/runtime/runtime_root.dart:413`, `lib/src/runtime/runtime_root.dart:429`). `_frameInputs` passes current preview, preview revision, view camera offset, and text edit suppression into the frame input object (`lib/src/runtime/runtime_root.dart:435`, `lib/src/runtime/runtime_root.dart:440`, `lib/src/runtime/runtime_root.dart:443`).
- **Dependencies**: `RuntimeRoot` implements `FrameFactsPort` (`lib/src/runtime/runtime_root.dart:88`). Its frame facts implementation copies revisions and background from the store, wraps store element handles, resolves store elements into `FrameElementFacts`, and wraps resource descriptors (`lib/src/runtime/runtime_root.dart:484`, `lib/src/runtime/runtime_root.dart:497`, `lib/src/runtime/runtime_root.dart:520`, `lib/src/runtime/runtime_root.dart:541`, `lib/src/runtime/runtime_root.dart:604`).
- **Data flow**: `CanvasRuntimeSurfacePort.buildSurfaceOverlayFrame` validates the active surface token and calls `_root.buildResourceFreeOverlayFrame` (`lib/src/api/canvas_runtime_surface_bridge.dart:95`, `lib/src/api/canvas_runtime_surface_bridge.dart:102`, `lib/src/api/canvas_runtime_surface_bridge.dart:106`). `_CanvasSurfaceState._buildPaintHost` builds main and overlay outputs and passes them to `MainFramePainter` and `OverlayFramePainter` (`lib/src/surface/canvas_surface_widget.dart:177`, `lib/src/surface/canvas_surface_widget.dart:187`, `lib/src/surface/canvas_surface_widget.dart:201`, `lib/src/surface/canvas_surface_widget.dart:210`).

### 5. Overlay Planning And Painting

- **Location**: primary `lib/src/frame/overlay_preview_planner.dart:96`.
- **Description**: `OverlayPreviewPlanner.build` takes `CapturedOverlayFrame`, computes one nullable primitive, and returns an `OverlayPreviewPlan` with either an empty list or that primitive (`lib/src/frame/overlay_preview_planner.dart:96`, `lib/src/frame/overlay_preview_planner.dart:99`, `lib/src/frame/overlay_preview_planner.dart:103`).
- **Dependencies**: `_primitiveFor` reads `frame.overlayPreview` and maps `null`, `CanvasNoPreview`, and `CanvasSelectedMovePreview` to no primitive (`lib/src/frame/overlay_preview_planner.dart:108`, `lib/src/frame/overlay_preview_planner.dart:111`). It maps marquee, pencil stroke, marker stroke, pending line start, line preview, and eraser preview to overlay primitive classes (`lib/src/frame/overlay_preview_planner.dart:113`, `lib/src/frame/overlay_preview_planner.dart:135`).
- **Data flow**: Marquee primitive creation reads `frame.snapshot.inputs.selectionStyle` and copies color, stroke width, and fill opacity into `MarqueeOverlayPrimitive` (`lib/src/frame/overlay_preview_planner.dart:142`, `lib/src/frame/overlay_preview_planner.dart:146`, `lib/src/frame/overlay_preview_planner.dart:150`). `OverlayFramePainter.paint` reads `output.capturedFrame.snapshot.inputs.effectiveWorldBounds`, clips, translates by viewport origin, and paints each overlay primitive (`lib/src/surface/overlay_painter.dart:15`, `lib/src/surface/overlay_painter.dart:16`, `lib/src/surface/overlay_painter.dart:20`).

### 6. Frame Outputs

- **Location**: primary `lib/src/frame/frame_paint_output.dart:12`.
- **Description**: `MainFramePaintOutput` stores captured main frame, ordinary plan, static background plan, selection decoration plan, selected order snapshot, selected move supplement plan, render primitive snapshot, asset bindings, and repaint signal (`lib/src/frame/frame_paint_output.dart:12`, `lib/src/frame/frame_paint_output.dart:25`, `lib/src/frame/frame_paint_output.dart:33`).
- **Dependencies**: `OverlayFramePaintOutput` stores captured overlay frame, overlay preview plan, and repaint signal (`lib/src/frame/frame_paint_output.dart:36`, `lib/src/frame/frame_paint_output.dart:43`, `lib/src/frame/frame_paint_output.dart:45`).
- **Data flow**: `FrameEngine.buildResourceFreeOverlayFrame` captures the overlay frame, builds an overlay plan, and creates a repaint signal whose overlay canvas flag is based on `plan.primitives.isNotEmpty` (`lib/src/frame/frame_engine.dart:152`, `lib/src/frame/frame_engine.dart:155`, `lib/src/frame/frame_engine.dart:161`, `lib/src/frame/frame_engine.dart:163`).

### 7. Tests And Fixtures

- **Location**: primary `test/frame/fixtures/main_overlay_capture_fixture.dart:31`.
- **Description**: The main/overlay capture fixture creates fake frame facts, selection facts, a spatial query callback, and capture inputs; it then calls `capture.captureMainFrame(inputs)` and `capture.captureOverlayFrame(inputs)` (`test/frame/fixtures/main_overlay_capture_fixture.dart:37`, `test/frame/fixtures/main_overlay_capture_fixture.dart:58`, `test/frame/fixtures/main_overlay_capture_fixture.dart:62`, `test/frame/fixtures/main_overlay_capture_fixture.dart:71`, `test/frame/fixtures/main_overlay_capture_fixture.dart:76`, `test/frame/fixtures/main_overlay_capture_fixture.dart:77`).
- **Dependencies**: The fixture fake `FrameFactsPort` tracks read counters for frame revisions, background, element handles, element handle lookups, element resolution, resource descriptors, and resolved ids (`test/frame/fixtures/main_overlay_capture_fixture.dart:328`, `test/frame/fixtures/main_overlay_capture_fixture.dart:334`). The fake `SelectionFactsPort` tracks selection facts reads (`test/frame/fixtures/main_overlay_capture_fixture.dart:399`, `test/frame/fixtures/main_overlay_capture_fixture.dart:403`).
- **Data flow**: The immutable capture test expects main snapshot facts and overlay snapshot facts to retain captured values after fake data is replaced (`test/frame/fixtures/main_overlay_capture_fixture.dart:79`, `test/frame/fixtures/main_overlay_capture_fixture.dart:89`, `test/frame/fixtures/main_overlay_capture_fixture.dart:115`). It expects two frame revision reads, two background reads, two selected-handle lookups, four element resolutions, two resource descriptor reads, two selection facts reads, and two spatial queries across the main plus overlay capture calls (`test/frame/fixtures/main_overlay_capture_fixture.dart:118`, `test/frame/fixtures/main_overlay_capture_fixture.dart:131`).

### 8. Overlay Preview Test Coverage

- **Location**: primary `test/frame/fixtures/overlay_preview_admission_fixture.dart:13`.
- **Description**: The overlay preview admission fixture creates an `OverlayPreviewPlanner`, builds captured overlay frames for six overlay preview variants, reads each single primitive kind, and expects marquee, pencil stroke, marker stroke, pending line start, line preview, and eraser primitive kinds (`test/frame/fixtures/overlay_preview_admission_fixture.dart:16`, `test/frame/fixtures/overlay_preview_admission_fixture.dart:46`, `test/frame/fixtures/overlay_preview_admission_fixture.dart:55`).
- **Dependencies**: Shared helper `capturedOverlayFrameFor` constructs empty frame facts, an empty selection facts port, an empty spatial result, and calls `FrameCaptureService.captureOverlayFrame` with supplied preview and selection style (`test/frame/fixtures/ordinary_paint_test_support.dart:66`, `test/frame/fixtures/ordinary_paint_test_support.dart:70`, `test/frame/fixtures/ordinary_paint_test_support.dart:77`).
- **Data flow**: The marquee captured style fixture captures an overlay frame with a custom selection style, builds the overlay primitive, casts it to `MarqueeOverlayPrimitive`, and expects primitive color, stroke width, and fill opacity to match the captured style (`test/frame/fixtures/marquee_captured_style_fixture.dart:11`, `test/frame/fixtures/marquee_captured_style_fixture.dart:13`, `test/frame/fixtures/marquee_captured_style_fixture.dart:18`).

## Code References

- `docs/contracts/frame_rendering.md:85` - Contract overlay frame field list begins.
- `docs/contracts/frame_rendering.md:152` - Contract collaborator table lists `FrameCaptureService` and `OverlayPreviewPlanner` ownership.
- `docs/contracts/frame_rendering.md:175` - Contract states overlay preview primitives are admitted from `CapturedOverlayFrame`.
- `lib/src/frame/captured_frame.dart:35` - Shared `CapturedFrameSnapshot` class begins.
- `lib/src/frame/captured_frame.dart:90` - `CapturedOverlayFrame` class begins.
- `lib/src/frame/frame_capture_service.dart:40` - Overlay capture method begins.
- `lib/src/frame/frame_capture_service.dart:52` - Shared `_captureSnapshot` method begins.
- `lib/src/frame/frame_engine.dart:152` - Resource-free overlay frame build method begins.
- `lib/src/frame/overlay_preview_planner.dart:99` - Overlay planner consumes `CapturedOverlayFrame`.
- `lib/src/surface/overlay_painter.dart:16` - Overlay painter reads viewport from captured frame snapshot inputs.
- `test/frame/fixtures/main_overlay_capture_fixture.dart:118` - Shared capture read counters are asserted.
- `test/frame/fixtures/overlay_preview_admission_fixture.dart:55` - Overlay primitive kinds are asserted.
- `test/frame/fixtures/marquee_captured_style_fixture.dart:18` - Captured style fields are asserted on marquee primitive.

## Search Coverage

- **Inspected**: `docs/contracts/frame_rendering.md:1`-`322`; `lib/src/frame/captured_frame.dart:1`-`98`; `lib/src/frame/frame_capture_service.dart:1`-`167`; `lib/src/frame/frame_engine.dart:1`-`271`; `lib/src/frame/overlay_preview_planner.dart:1`-`167`; `lib/src/frame/frame_paint_output.dart:1`-`46`; `lib/src/contracts/internal/frame_facts_port.dart:1`-`165`; `lib/src/runtime/runtime_root.dart:1`-`3328`; `lib/src/api/canvas_runtime_surface_bridge.dart:1`-`113`; `lib/src/surface/canvas_surface_widget.dart:1`-`262`; `lib/src/surface/main_painter.dart:1`-`127`; `lib/src/surface/overlay_painter.dart:1`-`109`; `test/frame/main_overlay_capture_test.dart:1`-`17`; `test/frame/fixtures/main_overlay_capture_fixture.dart:1`-`408`; `test/frame/overlay_preview_admission_test.dart:1`-`14`; `test/frame/fixtures/overlay_preview_admission_fixture.dart:1`-`75`; `test/frame/marquee_captured_style_test.dart:1`-`14`; `test/frame/fixtures/marquee_captured_style_fixture.dart:1`-`34`; `test/frame/fixtures/ordinary_paint_test_support.dart:1`-`466`.
- **Searched**: `rg -n "CapturedOverlayFrame|captureOverlayFrame|overlayPreview|CapturedFrameSnapshot|FrameCaptureInputs" lib test docs`; `rg -n "buildSurfaceMainFrame|buildSurfaceOverlayFrame|MainFramePainter|OverlayFramePainter|buildResourceFreeOverlayFrame|buildMainFrameWithAssetBindings|buildResourceFreeMainFrame|captureOverlayFrame\\(" lib test`; `rg -n "frameRevisionReads|backgroundReads|elementHandlesReads|elementHandleForIdReads|resolveElementReads|resourceDescriptorReads|selectionFacts|resolvedIds|spatialQueries" test/frame/fixtures`; `rg -n "OverlayPreviewPlanner|OverlayPreviewPrimitiveKind|MarqueeOverlayPrimitive|CanvasMarqueePreview|CanvasPencilStrokePreview|CanvasMarkerStrokePreview|CanvasPendingLineStartPreview|CanvasLinePreview|CanvasEraserPreview|CanvasSelectedMovePreview" test/frame/fixtures lib/src/frame`.
- **Not found**: No production direct call to `FrameCaptureService.captureOverlayFrame` outside `FrameEngine`; production overlay building is routed through `FrameEngine.captureOverlayFrame` and `FrameEngine.buildResourceFreeOverlayFrame` (`lib/src/frame/frame_engine.dart:70`, `lib/src/frame/frame_engine.dart:152`).
- **Not inspected**: Benchmark tooling, edit/store commit paths, runtime timestamp paths, and non-frame tests were not inspected because the research question was limited to FRAME-001 overlay frame capture/rendering.

## Observed Architecture Facts

- Pattern observed: `FrameEngine` is the frame facade. It constructs `FrameCaptureService` with frame facts, selection facts, and spatial query dependencies (`lib/src/frame/frame_engine.dart:35`, `lib/src/frame/frame_engine.dart:41`).
- Pattern observed: Main and overlay capture both use `FrameCaptureService._captureSnapshot` before their path-specific preview routing is applied (`lib/src/frame/frame_capture_service.dart:28`, `lib/src/frame/frame_capture_service.dart:40`, `lib/src/frame/frame_capture_service.dart:52`).
- Data flow: `CanvasRuntimeSurfacePort.buildSurfaceOverlayFrame` -> `RuntimeRoot.buildResourceFreeOverlayFrame` -> `FrameEngine.buildResourceFreeOverlayFrame` -> `FrameCaptureService.captureOverlayFrame` -> `OverlayPreviewPlanner.build` -> `OverlayFramePaintOutput` -> `OverlayFramePainter.paint` (`lib/src/api/canvas_runtime_surface_bridge.dart:95`, `lib/src/runtime/runtime_root.dart:413`, `lib/src/frame/frame_engine.dart:152`, `lib/src/frame/frame_capture_service.dart:40`, `lib/src/frame/overlay_preview_planner.dart:99`, `lib/src/frame/frame_paint_output.dart:36`, `lib/src/surface/overlay_painter.dart:15`).
- Key dependencies: Overlay primitive planning uses `frame.overlayPreview` for preview routing and `frame.snapshot.inputs.selectionStyle` for marquee style (`lib/src/frame/overlay_preview_planner.dart:109`, `lib/src/frame/overlay_preview_planner.dart:146`).
- Test pattern observed: Frame-level tests run Flutter fixtures through `runFlutterInPackageTest`, which invokes `flutter test` for the fixture path (`test/frame/main_overlay_capture_test.dart:9`, `test/support/flutter_in_package_test_harness.dart:25`).

## Open Questions

None within the inspected FRAME-001 overlay frame capture/rendering scope.
