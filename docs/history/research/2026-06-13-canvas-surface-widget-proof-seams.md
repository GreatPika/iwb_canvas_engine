---
date: 2026-06-13
researcher: Codex
commit: a87c82fd
branch: new-architecture
research_question: "Исследуй CanvasSurface/widget test seams для focused proof, что overlay-only/main-only события сейчас проходят через реальную Flutter surface. Нужны факты с точными file:line: CanvasSurface, runtime surface bridge, painters, existing surface widget fixtures/tests, helper seams. Ответь, какие observable signals уже можно получить без production changes, где их недостаточно, и какие минимальные in-repo seams могут доказать main/overlay output identity/build/paint routing. Не предлагай будущий repaint-routing implementation."
---

# Research: CanvasSurface Widget Proof Seams

## Summary

`CanvasSurface` currently builds a real Flutter `CustomPaint` host from runtime
surface output: main output is assigned to `CustomPaint.painter`, and overlay
output is assigned to `CustomPaint.foregroundPainter`
(`lib/src/surface/canvas_surface_widget.dart:187`,
`lib/src/surface/canvas_surface_widget.dart:200`,
`lib/src/surface/canvas_surface_widget.dart:208`). Existing widget fixtures can
observe those painter delegates and their output objects after `tester.pumpWidget`
(`test/surface/fixtures/widget_paint_fixture.dart:274`,
`test/surface/fixtures/widget_paint_fixture.dart:282`).

Existing tests already prove preview routing at frame/capture/output level and
at widget delegate-output level for selected-move main and marquee overlay
previews (`test/frame/fixtures/main_overlay_capture_fixture.dart:151`,
`test/frame/fixtures/repaint_bus_output_fixture.dart:23`,
`test/surface/fixtures/widget_paint_fixture.dart:175`). Existing pixel probes
paint `MainFramePainter` or `OverlayFramePainter` into a `PictureRecorder`,
not by capturing the rendered widget tree
(`test/surface/fixtures/painter_clipping_test_support.dart:8`,
`test/surface/fixtures/selection_chrome_topmost_paint_fixture.dart:242`).

## Detailed Findings

### 1. Public CanvasSurface Entry Point

- **Location**: `lib/src/api/canvas_surface.dart:1`
- **Description**: The public API file exports `CanvasSurface` from
  `../surface/canvas_surface_widget.dart` and exposes `CanvasTextEditingOverlay`
  from `../surface/text_editing_overlay.dart`
  (`lib/src/api/canvas_surface.dart:2`,
  `lib/src/api/canvas_surface.dart:3`).
- **Dependencies**: The widget implementation imports the public runtime,
  runtime surface bridge, public resource/style contracts, surface resource
  session, image bridge, main painter, overlay painter, and pointer adapter
  (`lib/src/surface/canvas_surface_widget.dart:3`,
  `lib/src/surface/canvas_surface_widget.dart:11`).
- **Data flow**: `CanvasSurface.build` reads the current surface port, subscribes
  to `port.state` through `ValueListenableBuilder`, computes paint size and
  viewport in `LayoutBuilder`, then calls `_buildPaintHost`
  (`lib/src/surface/canvas_surface_widget.dart:85`,
  `lib/src/surface/canvas_surface_widget.dart:91`,
  `lib/src/surface/canvas_surface_widget.dart:94`,
  `lib/src/surface/canvas_surface_widget.dart:99`).

### 2. Runtime Surface Bridge

- **Location**: `lib/src/api/canvas_runtime_surface_bridge.dart:14`
- **Description**: Runtime-to-surface attachment is stored in an
  `Expando<CanvasRuntimeSurfacePort>` keyed by the runtime object
  (`lib/src/api/canvas_runtime_surface_bridge.dart:14`). `CanvasRuntime`
  installs this port when constructed and detaches it on dispose
  (`lib/src/api/canvas_runtime.dart:27`,
  `lib/src/api/canvas_runtime.dart:31`,
  `lib/src/api/canvas_runtime.dart:52`).
- **Dependencies**: The bridge uses `CanvasRuntimeState`,
  `CanvasPointerInput`, `CanvasSelectionStyle`, `CanvasGridStyle`,
  `FrameAssetBindingBuilder`, `MainFramePaintOutput`, `OverlayFramePaintOutput`,
  and `RuntimeRoot` (`lib/src/api/canvas_runtime_surface_bridge.dart:7`,
  `lib/src/api/canvas_runtime_surface_bridge.dart:12`).
- **Data flow**: `CanvasRuntimeSurfacePort.buildSurfaceMainFrame` checks the
  active surface token, then calls `RuntimeRoot.buildMainFrameWithAssetBindings`
  with viewport, device pixel ratio, style inputs, and asset binding callback
  (`lib/src/api/canvas_runtime_surface_bridge.dart:70`,
  `lib/src/api/canvas_runtime_surface_bridge.dart:78`,
  `lib/src/api/canvas_runtime_surface_bridge.dart:83`).
  `buildSurfaceOverlayFrame` checks the same token and calls
  `RuntimeRoot.buildResourceFreeOverlayFrame`
  (`lib/src/api/canvas_runtime_surface_bridge.dart:95`,
  `lib/src/api/canvas_runtime_surface_bridge.dart:102`,
  `lib/src/api/canvas_runtime_surface_bridge.dart:106`).

### 3. CanvasSurface Build and Delegate Routing

- **Location**: `lib/src/surface/canvas_surface_widget.dart:177`
- **Description**: `_buildPaintHost` obtains `mainOutput` by calling
  `port.buildSurfaceMainFrame`, obtains `overlayOutput` by calling
  `port.buildSurfaceOverlayFrame`, then constructs a `CustomPaint` with key
  `iwb_canvas_surface.paint_host`
  (`lib/src/surface/canvas_surface_widget.dart:187`,
  `lib/src/surface/canvas_surface_widget.dart:200`,
  `lib/src/surface/canvas_surface_widget.dart:208`).
- **Dependencies**: Main output is wrapped in `MainFramePainter`, overlay output
  is wrapped in `OverlayFramePainter`, and interactive surfaces wrap the host in
  `CanvasSurfacePointerAdapter` (`lib/src/surface/canvas_surface_widget.dart:210`,
  `lib/src/surface/canvas_surface_widget.dart:211`,
  `lib/src/surface/canvas_surface_widget.dart:218`).
- **Data flow**: Non-interactive `CanvasSurface` returns the `CustomPaint`
  directly (`lib/src/surface/canvas_surface_widget.dart:214`); interactive
  surfaces route pointer input to `port.handlePointer`
  (`lib/src/surface/canvas_surface_widget.dart:218`,
  `lib/src/surface/canvas_surface_widget.dart:220`).

### 4. Runtime and Frame Output Construction

- **Location**: `lib/src/runtime/runtime_root.dart:395`
- **Description**: `RuntimeRoot.buildMainFrameWithAssetBindings` delegates to
  `_frameEngine.buildMainFrameWithAssetBindings` with `_frameInputs` and the
  current view camera revision bucket (`lib/src/runtime/runtime_root.dart:402`,
  `lib/src/runtime/runtime_root.dart:409`). `RuntimeRoot.buildResourceFreeOverlayFrame`
  delegates to `_frameEngine.buildResourceFreeOverlayFrame`
  (`lib/src/runtime/runtime_root.dart:414`,
  `lib/src/runtime/runtime_root.dart:420`).
- **Dependencies**: Runtime frame inputs include viewport, DPR, selection style,
  grid style, current preview, preview revision, camera offset, camera revision,
  and active text-edit suppression (`lib/src/runtime/runtime_root.dart:430`,
  `lib/src/runtime/runtime_root.dart:445`).
- **Data flow**: `FrameEngine._buildMainFrame` captures a main frame, builds
  ordinary paint, selected move supplement, static background, selection
  decoration plan, selected order snapshot, primitive snapshot, optional asset
  bindings, and a main repaint signal (`lib/src/frame/frame_engine.dart:102`,
  `lib/src/frame/frame_engine.dart:125`,
  `lib/src/frame/frame_engine.dart:134`). Overlay output captures an overlay
  frame, builds an overlay preview plan, and sets `overlayCanvas` from
  `plan.primitives.isNotEmpty` (`lib/src/frame/frame_engine.dart:152`,
  `lib/src/frame/frame_engine.dart:155`,
  `lib/src/frame/frame_engine.dart:161`).

### 5. Painter Behavior

- **Location**: `lib/src/surface/main_painter.dart:9`
- **Description**: `MainFramePainter.paint` reads
  `output.capturedFrame.snapshot.inputs.effectiveWorldBounds`, clips to the
  `CustomPaint` size, translates by the viewport, draws static background, then
  calls `paintMainFrameRecordsAndSelectionDecorations`
  (`lib/src/surface/main_painter.dart:15`,
  `lib/src/surface/main_painter.dart:24`,
  `lib/src/surface/main_painter.dart:25`).
- **Dependencies**: It imports `MainFramePaintOutput`,
  `resolvedMainFrameImages`, `paintMainFrameRecord`, `RenderElementRecord`, and
  `SelectionDecorationPrimitive` (`lib/src/surface/main_painter.dart:3`,
  `lib/src/surface/main_painter.dart:7`).
- **Data flow**: Main records come from
  `output.selectedMoveSupplementPlan.mergedRecords`, are painted via
  `paintMainFrameRecord`, and selection decoration primitives are painted after
  the record loop (`lib/src/surface/main_painter.dart:64`,
  `lib/src/surface/main_painter.dart:65`,
  `lib/src/surface/main_painter.dart:75`).

### 6. Overlay Painter Behavior

- **Location**: `lib/src/surface/overlay_painter.dart:9`
- **Description**: `OverlayFramePainter.paint` reads
  `output.capturedFrame.effectiveWorldBounds`, clips to the supplied size,
  translates by the viewport, then iterates `output.overlayPreviewPlan.primitives`
  (`lib/src/surface/overlay_painter.dart:15`,
  `lib/src/surface/overlay_painter.dart:18`,
  `lib/src/surface/overlay_painter.dart:20`).
- **Dependencies**: It imports `FrameDrawablePolicy`,
  `OverlayFramePaintOutput`, and overlay preview primitive types
  (`lib/src/surface/overlay_painter.dart:3`,
  `lib/src/surface/overlay_painter.dart:5`).
- **Data flow**: The primitive switch paints marquee, stroke, pending line
  start, line, and eraser overlay primitives
  (`lib/src/surface/overlay_painter.dart:32`,
  `lib/src/surface/overlay_painter.dart:44`).

### 7. Existing Widget-Level Signals

- **Location**: `test/surface/fixtures/widget_paint_fixture.dart:175`
- **Description**: The widget fixture pumps `_SurfaceHost` containing
  `CanvasSurface`, mutates runtime preview state, and reads the resulting
  `CustomPaint` delegates through `_mainPainter` and `_overlayPainter`
  (`test/surface/fixtures/widget_paint_fixture.dart:180`,
  `test/surface/fixtures/widget_paint_fixture.dart:209`,
  `test/surface/fixtures/widget_paint_fixture.dart:226`).
- **Dependencies**: It imports public API, runtime frame bridge for test root
  access, runtime root, `MainFramePainter`, and `OverlayFramePainter`
  (`test/surface/fixtures/widget_paint_fixture.dart:6`,
  `test/surface/fixtures/widget_paint_fixture.dart:12`).
- **Data flow**: Selected move preview is installed on the runtime root, then
  the fixture observes `MainFramePainter.output.repaintSignal.reason ==
  'selected_move_preview'` and an empty overlay primitive plan
  (`test/surface/fixtures/widget_paint_fixture.dart:213`,
  `test/surface/fixtures/widget_paint_fixture.dart:219`,
  `test/surface/fixtures/widget_paint_fixture.dart:223`). Marquee preview is
  installed on the same runtime root, then the fixture observes
  `capturedFrame.selectedMovePreview == null` on main output and non-empty
  overlay primitives (`test/surface/fixtures/widget_paint_fixture.dart:230`,
  `test/surface/fixtures/widget_paint_fixture.dart:235`,
  `test/surface/fixtures/widget_paint_fixture.dart:237`).

### 8. Existing Helper Seams

- **Location**: `test/surface/fixtures/widget_paint_fixture.dart:270`
- **Description**: `_paintHosts` finds the keyed `CustomPaint`, `_mainPainter`
  returns the `CustomPaint.painter` after asserting `MainFramePainter`, and
  `_overlayPainter` returns the `CustomPaint.foregroundPainter` after asserting
  `OverlayFramePainter` (`test/surface/fixtures/widget_paint_fixture.dart:270`,
  `test/surface/fixtures/widget_paint_fixture.dart:274`,
  `test/surface/fixtures/widget_paint_fixture.dart:282`).
- **Dependencies**: `surface_camera_frame_output_fixture.dart` duplicates the
  same keyed host lookup and painter extraction helper shape
  (`test/surface/fixtures/surface_camera_frame_output_fixture.dart:141`,
  `test/surface/fixtures/surface_camera_frame_output_fixture.dart:153`).
- **Data flow**: Painter pixel helper seams exist for direct painter recording:
  `painter_clipping_test_support.alphaAt` records a supplied `Canvas` paint
  callback into a `PictureRecorder`
  (`test/surface/fixtures/painter_clipping_test_support.dart:3`,
  `test/surface/fixtures/painter_clipping_test_support.dart:8`), and
  `selection_chrome_topmost_paint_fixture.dart` records `MainFramePainter`
  directly from a `MainFramePaintOutput`
  (`test/surface/fixtures/selection_chrome_topmost_paint_fixture.dart:237`,
  `test/surface/fixtures/selection_chrome_topmost_paint_fixture.dart:243`).

### 9. Existing Lower-Level Routing Proofs

- **Location**: `test/frame/fixtures/main_overlay_capture_fixture.dart:151`
- **Description**: Frame capture tests assert that `CanvasSelectedMovePreview`
  appears in main capture and is absent from overlay capture, while marquee,
  pencil, marker, pending-line, line, and eraser previews are absent from main
  selected-move capture and present in overlay capture
  (`test/frame/fixtures/main_overlay_capture_fixture.dart:154`,
  `test/frame/fixtures/main_overlay_capture_fixture.dart:161`,
  `test/frame/fixtures/main_overlay_capture_fixture.dart:164`,
  `test/frame/fixtures/main_overlay_capture_fixture.dart:197`).
- **Dependencies**: Repaint output tests build `FrameEngine` directly and assert
  selected-move main output has `mainCanvas == true` and `overlayCanvas == false`,
  while marquee overlay output has `mainCanvas == false` and `overlayCanvas ==
  true` (`test/frame/fixtures/repaint_bus_output_fixture.dart:32`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:50`).
- **Data flow**: Existing painter tests prove direct painter pixels, including
  main painter clipping (`test/surface/fixtures/main_painter_clipping_fixture.dart:18`),
  overlay painter clipping and translation
  (`test/surface/fixtures/overlay_painter_clipping_fixture.dart:17`,
  `test/surface/fixtures/overlay_painter_clipping_fixture.dart:34`), and overlay
  degenerate drawable pixels
  (`test/surface/fixtures/overlay_drawable_policy_fixture.dart:20`,
  `test/surface/fixtures/overlay_drawable_policy_fixture.dart:127`).

## Code References

- `lib/src/api/canvas_surface.dart:2` - public export for `CanvasSurface`.
- `lib/src/api/canvas_runtime.dart:31` - `CanvasRuntime` attaches the surface port.
- `lib/src/api/canvas_runtime_surface_bridge.dart:70` - surface bridge main-frame build method.
- `lib/src/api/canvas_runtime_surface_bridge.dart:95` - surface bridge overlay-frame build method.
- `lib/src/surface/canvas_surface_widget.dart:187` - widget builds main output from surface port.
- `lib/src/surface/canvas_surface_widget.dart:200` - widget builds overlay output from surface port.
- `lib/src/surface/canvas_surface_widget.dart:208` - keyed real Flutter `CustomPaint` host.
- `lib/src/surface/canvas_surface_widget.dart:210` - main output assigned to `MainFramePainter`.
- `lib/src/surface/canvas_surface_widget.dart:211` - overlay output assigned to `OverlayFramePainter`.
- `lib/src/surface/main_painter.dart:25` - main painter paints main records and selection decorations.
- `lib/src/surface/overlay_painter.dart:20` - overlay painter iterates overlay primitives.
- `lib/src/frame/frame_engine.dart:125` - `MainFramePaintOutput` construction.
- `lib/src/frame/frame_engine.dart:158` - `OverlayFramePaintOutput` construction.
- `test/surface/fixtures/widget_paint_fixture.dart:219` - widget-level selected-move main repaint signal assertion.
- `test/surface/fixtures/widget_paint_fixture.dart:223` - widget-level selected-move overlay-empty assertion.
- `test/surface/fixtures/widget_paint_fixture.dart:235` - widget-level marquee main selected-move absence assertion.
- `test/surface/fixtures/widget_paint_fixture.dart:237` - widget-level marquee overlay primitive assertion.
- `test/surface/fixtures/painter_clipping_test_support.dart:8` - direct `PictureRecorder` pixel helper.
- `test/support/flutter_in_package_test_harness.dart:25` - wrapper runs fixture files through `flutter test`.

## Search Coverage

- Inspected: `lib/src/api/canvas_surface.dart`,
  `lib/src/api/canvas_runtime.dart`,
  `lib/src/api/canvas_runtime_surface_bridge.dart`,
  `lib/src/surface/canvas_surface_widget.dart`,
  `lib/src/surface/main_painter.dart`,
  `lib/src/surface/overlay_painter.dart`,
  `lib/src/runtime/runtime_root.dart`,
  `lib/src/frame/frame_engine.dart`,
  `lib/src/frame/frame_paint_output.dart`,
  `lib/src/frame/frame_repaint_signal.dart`,
  `lib/src/frame/frame_capture_service.dart`,
  `test/surface/fixtures/widget_paint_fixture.dart`,
  `test/surface/fixtures/surface_camera_frame_output_fixture.dart`,
  `test/surface/fixtures/main_painter_clipping_fixture.dart`,
  `test/surface/fixtures/overlay_painter_clipping_fixture.dart`,
  `test/surface/fixtures/overlay_drawable_policy_fixture.dart`,
  `test/surface/fixtures/painter_clipping_test_support.dart`,
  `test/surface/fixtures/selection_chrome_topmost_paint_fixture.dart`,
  `test/frame/fixtures/main_overlay_capture_fixture.dart`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart`,
  and their wrapper tests.
- Searched: `CanvasSurface`, `RuntimeSurface`, `SurfaceBridge`, `Painter`,
  `CustomPaint`, `overlay-only`, `main-only`, `overlay`, `main`,
  `toImage`, `matchesGoldenFile`, `RepaintBoundary`, `capture`, `renderObject`,
  `PictureRecorder`, `foregroundPainter`, and `painter`.
- Not found: A shared test helper that captures the rendered `CanvasSurface`
  widget tree pixels; current pixel helpers record painter callbacks directly
  (`test/surface/fixtures/painter_clipping_test_support.dart:8`).
- Not inspected: No external packages or generated docs were inspected because
  the question targets repository-local surface/widget seams.

## Observed Architecture Facts

- Pattern observed: surface widget tests use a keyed `CustomPaint` host to read
  installed painter delegates (`lib/src/surface/canvas_surface_widget.dart:209`,
  `test/surface/fixtures/widget_paint_fixture.dart:270`).
- Pattern observed: direct painter pixel tests use `PictureRecorder`, not a
  rendered widget-tree capture (`test/surface/fixtures/painter_clipping_test_support.dart:8`,
  `test/surface/fixtures/overlay_drawable_policy_fixture.dart:128`).
- Data flow: `CanvasRuntime` -> surface bridge `Expando` -> `CanvasSurface`
  port lookup -> `buildSurfaceMainFrame`/`buildSurfaceOverlayFrame` -> `CustomPaint`
  painter delegates (`lib/src/api/canvas_runtime.dart:31`,
  `lib/src/api/canvas_runtime_surface_bridge.dart:25`,
  `lib/src/surface/canvas_surface_widget.dart:112`,
  `lib/src/surface/canvas_surface_widget.dart:187`,
  `lib/src/surface/canvas_surface_widget.dart:208`).

## Open Questions

- No current fixture records pixels from the `CanvasSurface` widget tree itself;
  existing widget fixtures read delegate outputs from `CustomPaint`
  (`test/surface/fixtures/widget_paint_fixture.dart:274`), while existing pixel
  helpers invoke painters directly (`test/surface/fixtures/painter_clipping_test_support.dart:8`).
