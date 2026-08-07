---
date: 2026-06-13
researcher: Codex
commit: b6b59575
branch: new-architecture
research_question: "FRAME-001 -- repaint signals are computed, but the real Flutter surface is not guided by them"
---

# Research: Frame Repaint Signal Surface Usage

## Summary

The frame layer defines `FrameRepaintSignal` as a data object with separate
`mainCanvas`, `overlayCanvas`, and `reason` fields (`lib/src/frame/frame_repaint_signal.dart:1`).
`FrameEngine` attaches a signal to every `MainFramePaintOutput` and
`OverlayFramePaintOutput` it constructs (`lib/src/frame/frame_engine.dart:125`,
`lib/src/frame/frame_engine.dart:158`), and the output classes store those
signals as fields (`lib/src/frame/frame_paint_output.dart:33`,
`lib/src/frame/frame_paint_output.dart:45`).

The Flutter surface builds both frame outputs inside the `ValueListenableBuilder`
path for `port.state` (`lib/src/surface/canvas_surface_widget.dart:91`,
`lib/src/surface/canvas_surface_widget.dart:187`,
`lib/src/surface/canvas_surface_widget.dart:200`) and installs both outputs into
a single `CustomPaint` as `painter` and `foregroundPainter`
(`lib/src/surface/canvas_surface_widget.dart:208`,
`lib/src/surface/canvas_surface_widget.dart:210`,
`lib/src/surface/canvas_surface_widget.dart:211`). The two CustomPainter
delegates use output object identity in `shouldRepaint`
(`lib/src/surface/main_painter.dart:29`, `lib/src/surface/main_painter.dart:31`,
`lib/src/surface/overlay_painter.dart:26`, `lib/src/surface/overlay_painter.dart:28`).

Search found production reads of `repaintSignal` only at output construction
sites and output field declarations, not in the surface painter scheduling path.
Tests assert the signal values at the frame layer
(`test/frame/fixtures/repaint_bus_output_fixture.dart:32`,
`test/frame/fixtures/repaint_bus_output_fixture.dart:50`) and inspect one surface
main painter signal reason in a widget fixture
(`test/surface/fixtures/widget_paint_fixture.dart:219`), but the production
surface path does not read `mainCanvas` or `overlayCanvas` in the inspected code.

## Detailed Findings

### 1. Frame Repaint Signal Model

- **Location**: primary `lib/src/frame/frame_repaint_signal.dart:1`.
- **Description**: `FrameRepaintSignal` stores three fields: `mainCanvas` at
  `lib/src/frame/frame_repaint_signal.dart:13`, `overlayCanvas` at
  `lib/src/frame/frame_repaint_signal.dart:14`, and `reason` at
  `lib/src/frame/frame_repaint_signal.dart:15`. The default named constructor
  requires all three values (`lib/src/frame/frame_repaint_signal.dart:2`), and
  `FrameRepaintSignal.none()` sets both canvas flags to `false` with reason
  `'none'` (`lib/src/frame/frame_repaint_signal.dart:8`).
- **Dependencies**: The model has no imports in the inspected file
  (`lib/src/frame/frame_repaint_signal.dart:1`).
- **Data flow**: Constructor input -> stored boolean target flags and string
  reason -> consumers read fields from frame output objects
  (`lib/src/frame/frame_paint_output.dart:33`,
  `lib/src/frame/frame_paint_output.dart:45`).

### 2. Frame Engine Signal Construction

- **Location**: primary `lib/src/frame/frame_engine.dart:125`.
- **Description**: `_buildMainFrame` returns a new `MainFramePaintOutput`
  (`lib/src/frame/frame_engine.dart:125`) with captured frame, paint plans,
  cache snapshots, asset bindings, and `repaintSignal: _mainRepaintSignal(frame)`
  (`lib/src/frame/frame_engine.dart:126`, `lib/src/frame/frame_engine.dart:134`).
  `_mainRepaintSignal` always sets `mainCanvas: true` and
  `overlayCanvas: false` (`lib/src/frame/frame_engine.dart:190`,
  `lib/src/frame/frame_engine.dart:192`, `lib/src/frame/frame_engine.dart:193`);
  its reason is `'main_frame'` unless `frame.selectedMovePreview` is present,
  in which case it is `'selected_move_preview'`
  (`lib/src/frame/frame_engine.dart:194`).
- **Dependencies**: `FrameEngine` imports `frame_repaint_signal.dart`
  (`lib/src/frame/frame_engine.dart:13`) and `frame_paint_output.dart`
  (`lib/src/frame/frame_engine.dart:12`).
- **Data flow**: `FrameCaptureInputs` -> `captureMainFrame`
  (`lib/src/frame/frame_engine.dart:102`) -> planners and cache snapshots
  (`lib/src/frame/frame_engine.dart:103`, `lib/src/frame/frame_engine.dart:110`,
  `lib/src/frame/frame_engine.dart:114`, `lib/src/frame/frame_engine.dart:116`)
  -> `MainFramePaintOutput` with a main repaint signal
  (`lib/src/frame/frame_engine.dart:125`, `lib/src/frame/frame_engine.dart:134`).

### 3. Overlay Signal Construction

- **Location**: primary `lib/src/frame/frame_engine.dart:152`.
- **Description**: `buildResourceFreeOverlayFrame` captures an overlay frame
  (`lib/src/frame/frame_engine.dart:155`), builds an overlay preview plan
  (`lib/src/frame/frame_engine.dart:156`), and returns an
  `OverlayFramePaintOutput` (`lib/src/frame/frame_engine.dart:158`). The
  overlay signal sets `mainCanvas: false` (`lib/src/frame/frame_engine.dart:162`)
  and sets `overlayCanvas` from `plan.primitives.isNotEmpty`
  (`lib/src/frame/frame_engine.dart:163`). The reason is `'overlay_empty'` when
  the primitive list is empty and `'overlay_preview'` otherwise
  (`lib/src/frame/frame_engine.dart:164`).
- **Dependencies**: Overlay output depends on `OverlayPreviewPlan` through
  `overlayPreviewPlan` (`lib/src/frame/frame_paint_output.dart:39`,
  `lib/src/frame/frame_paint_output.dart:44`) and stores a
  `FrameRepaintSignal` (`lib/src/frame/frame_paint_output.dart:40`,
  `lib/src/frame/frame_paint_output.dart:45`).
- **Data flow**: `FrameCaptureInputs` -> `captureOverlayFrame`
  (`lib/src/frame/frame_engine.dart:155`) -> overlay planner
  (`lib/src/frame/frame_engine.dart:156`) -> `OverlayFramePaintOutput` with an
  overlay-targeted signal (`lib/src/frame/frame_engine.dart:158`,
  `lib/src/frame/frame_engine.dart:161`).

### 4. Runtime Surface Port Frame Access

- **Location**: primary `lib/src/api/canvas_runtime_surface_bridge.dart:29`.
- **Description**: `CanvasRuntimeSurfacePort.state` exposes `_root.state` as a
  `ValueListenable<CanvasRuntimeState>` (`lib/src/api/canvas_runtime_surface_bridge.dart:34`).
  `buildSurfaceMainFrame` checks that the token is the active surface
  (`lib/src/api/canvas_runtime_surface_bridge.dart:78`) and delegates to
  `_root.buildMainFrameWithAssetBindings`
  (`lib/src/api/canvas_runtime_surface_bridge.dart:83`). `buildSurfaceOverlayFrame`
  performs the same active-surface check
  (`lib/src/api/canvas_runtime_surface_bridge.dart:102`) and delegates to
  `_root.buildResourceFreeOverlayFrame`
  (`lib/src/api/canvas_runtime_surface_bridge.dart:106`).
- **Dependencies**: The bridge imports Flutter foundation for `ValueListenable`
  (`lib/src/api/canvas_runtime_surface_bridge.dart:3`), frame output types
  (`lib/src/api/canvas_runtime_surface_bridge.dart:11`), and the frame engine
  asset binding typedef (`lib/src/api/canvas_runtime_surface_bridge.dart:10`).
- **Data flow**: `CanvasSurface` token and viewport/style/resource inputs ->
  `CanvasRuntimeSurfacePort` active-surface guard
  (`lib/src/api/canvas_runtime_surface_bridge.dart:78`,
  `lib/src/api/canvas_runtime_surface_bridge.dart:102`) -> `RuntimeRoot` frame
  facade (`lib/src/api/canvas_runtime_surface_bridge.dart:83`,
  `lib/src/api/canvas_runtime_surface_bridge.dart:106`).

### 5. Runtime State Publication Feeding Surface Rebuilds

- **Location**: primary `lib/src/runtime/runtime_root.dart:157`.
- **Description**: `RuntimeRoot` initializes `_state` as a
  `ValueNotifier<CanvasRuntimeState>` (`lib/src/runtime/runtime_root.dart:157`)
  and exposes it through the `state` getter
  (`lib/src/runtime/runtime_root.dart:259`). `_publishRuntimeState` assigns a new
  `CanvasRuntimeState` to `_state.value` (`lib/src/runtime/runtime_root.dart:1499`,
  `lib/src/runtime/runtime_root.dart:1500`) using runtime revision facts,
  including preview and view camera revisions
  (`lib/src/runtime/runtime_root.dart:1504`,
  `lib/src/runtime/runtime_root.dart:1505`). `replaceInteractionPreview` publishes
  runtime state when the interaction engine reports a preview change
  (`lib/src/runtime/runtime_root.dart:1226`,
  `lib/src/runtime/runtime_root.dart:1229`,
  `lib/src/runtime/runtime_root.dart:1230`).
- **Dependencies**: Runtime state is represented by `CanvasRuntimeState`
  (`lib/src/contracts/public/canvas_runtime.dart:42`) and
  `CanvasRuntimeRevisions` (`lib/src/contracts/public/canvas_runtime.dart:60`).
- **Data flow**: Runtime mutation -> `_publishRuntimeState`
  (`lib/src/runtime/runtime_root.dart:1499`) -> `_state.value`
  (`lib/src/runtime/runtime_root.dart:1500`) -> `CanvasRuntimeSurfacePort.state`
  (`lib/src/api/canvas_runtime_surface_bridge.dart:34`) -> `CanvasSurface`
  `ValueListenableBuilder` (`lib/src/surface/canvas_surface_widget.dart:91`).

### 6. Flutter Surface Paint Host

- **Location**: primary `lib/src/surface/canvas_surface_widget.dart:91`.
- **Description**: `CanvasSurface.build` returns a `ValueListenableBuilder`
  listening to `port.state` (`lib/src/surface/canvas_surface_widget.dart:91`,
  `lib/src/surface/canvas_surface_widget.dart:92`). Inside its builder, it
  computes paint size, viewport, and device pixel ratio
  (`lib/src/surface/canvas_surface_widget.dart:94`,
  `lib/src/surface/canvas_surface_widget.dart:96`,
  `lib/src/surface/canvas_surface_widget.dart:98`), then calls `_buildPaintHost`
  (`lib/src/surface/canvas_surface_widget.dart:99`). `_buildPaintHost` builds the
  main output (`lib/src/surface/canvas_surface_widget.dart:187`) and overlay
  output (`lib/src/surface/canvas_surface_widget.dart:200`) before constructing a
  `CustomPaint` (`lib/src/surface/canvas_surface_widget.dart:208`).
- **Dependencies**: The widget imports `CanvasRuntimeSurfacePort`
  (`lib/src/surface/canvas_surface_widget.dart:4`), `MainFramePainter`
  (`lib/src/surface/canvas_surface_widget.dart:9`), and `OverlayFramePainter`
  (`lib/src/surface/canvas_surface_widget.dart:10`).
- **Data flow**: `port.state` notification -> widget builder
  (`lib/src/surface/canvas_surface_widget.dart:91`) -> main frame output
  (`lib/src/surface/canvas_surface_widget.dart:187`) and overlay frame output
  (`lib/src/surface/canvas_surface_widget.dart:200`) -> `CustomPaint` painter
  delegates (`lib/src/surface/canvas_surface_widget.dart:210`,
  `lib/src/surface/canvas_surface_widget.dart:211`).

### 7. Main and Overlay Painter Repaint Checks

- **Location**: primary `lib/src/surface/main_painter.dart:9`;
  `lib/src/surface/overlay_painter.dart:9`.
- **Description**: `MainFramePainter` stores a `MainFramePaintOutput`
  (`lib/src/surface/main_painter.dart:10`, `lib/src/surface/main_painter.dart:12`)
  and paints background, records, and selection decorations from that output
  (`lib/src/surface/main_painter.dart:16`, `lib/src/surface/main_painter.dart:24`,
  `lib/src/surface/main_painter.dart:25`). Its `shouldRepaint` returns
  `!identical(oldDelegate.output, output)` (`lib/src/surface/main_painter.dart:29`,
  `lib/src/surface/main_painter.dart:31`). `OverlayFramePainter` stores an
  `OverlayFramePaintOutput` (`lib/src/surface/overlay_painter.dart:10`,
  `lib/src/surface/overlay_painter.dart:12`) and paints each overlay primitive
  from `output.overlayPreviewPlan.primitives`
  (`lib/src/surface/overlay_painter.dart:20`). Its `shouldRepaint` also returns
  `!identical(oldDelegate.output, output)`
  (`lib/src/surface/overlay_painter.dart:26`,
  `lib/src/surface/overlay_painter.dart:28`).
- **Dependencies**: Main painter imports frame output, asset images, record
  painter, render records, and selection decoration planner
  (`lib/src/surface/main_painter.dart:3`,
  `lib/src/surface/main_painter.dart:4`,
  `lib/src/surface/main_painter.dart:5`,
  `lib/src/surface/main_painter.dart:6`,
  `lib/src/surface/main_painter.dart:7`). Overlay painter imports frame drawable
  policy, frame output, and overlay preview planner
  (`lib/src/surface/overlay_painter.dart:3`,
  `lib/src/surface/overlay_painter.dart:4`,
  `lib/src/surface/overlay_painter.dart:5`).
- **Data flow**: Output object supplied by `CanvasSurface` ->
  `CustomPainter.output` field (`lib/src/surface/main_painter.dart:12`,
  `lib/src/surface/overlay_painter.dart:12`) -> paint methods read output
  (`lib/src/surface/main_painter.dart:16`,
  `lib/src/surface/overlay_painter.dart:16`) -> `shouldRepaint` compares output
  object identity (`lib/src/surface/main_painter.dart:31`,
  `lib/src/surface/overlay_painter.dart:28`).

### 8. Test Coverage Around Repaint Signals

- **Location**: primary `test/frame/fixtures/repaint_bus_output_fixture.dart:21`.
- **Description**: The frame fixture creates selected-move and marquee outputs
  (`test/frame/fixtures/repaint_bus_output_fixture.dart:25`) and asserts that a
  selected move main output has reason `'selected_move_preview'`,
  `mainCanvas == true`, and `overlayCanvas == false`
  (`test/frame/fixtures/repaint_bus_output_fixture.dart:32`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:33`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:34`). It also asserts an
  empty selected-move overlay signal has both canvas flags false
  (`test/frame/fixtures/repaint_bus_output_fixture.dart:42`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:43`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:44`) and that a marquee
  overlay signal has `overlayCanvas == true`
  (`test/frame/fixtures/repaint_bus_output_fixture.dart:50`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:51`).
- **Dependencies**: The fixture imports `FrameEngine` and frame output types
  (`test/frame/fixtures/repaint_bus_output_fixture.dart:8`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:9`).
- **Data flow**: Test facts and spatial kernel
  (`test/frame/fixtures/repaint_bus_output_fixture.dart:63`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:65`) -> `FrameEngine`
  (`test/frame/fixtures/repaint_bus_output_fixture.dart:66`) -> resource-free
  main and overlay outputs (`test/frame/fixtures/repaint_bus_output_fixture.dart:75`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:79`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:82`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:88`) -> assertions on
  signal fields (`test/frame/fixtures/repaint_bus_output_fixture.dart:32`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:50`).

## Code References

- `lib/src/frame/frame_repaint_signal.dart:1` - repaint signal model declaration.
- `lib/src/frame/frame_repaint_signal.dart:13` - `mainCanvas` target flag.
- `lib/src/frame/frame_repaint_signal.dart:14` - `overlayCanvas` target flag.
- `lib/src/frame/frame_paint_output.dart:33` - main frame output stores a repaint signal.
- `lib/src/frame/frame_paint_output.dart:45` - overlay frame output stores a repaint signal.
- `lib/src/frame/frame_engine.dart:125` - main frame output construction.
- `lib/src/frame/frame_engine.dart:134` - main frame output receives `_mainRepaintSignal(frame)`.
- `lib/src/frame/frame_engine.dart:158` - overlay frame output construction.
- `lib/src/frame/frame_engine.dart:161` - overlay frame output receives an inline `FrameRepaintSignal`.
- `lib/src/api/canvas_runtime_surface_bridge.dart:34` - surface port exposes runtime state as a `ValueListenable`.
- `lib/src/api/canvas_runtime_surface_bridge.dart:83` - surface main frame call delegates to `RuntimeRoot`.
- `lib/src/api/canvas_runtime_surface_bridge.dart:106` - surface overlay frame call delegates to `RuntimeRoot`.
- `lib/src/runtime/runtime_root.dart:157` - runtime state notifier initialization.
- `lib/src/runtime/runtime_root.dart:1500` - runtime state publication assigns `_state.value`.
- `lib/src/surface/canvas_surface_widget.dart:91` - surface listens to `port.state` with `ValueListenableBuilder`.
- `lib/src/surface/canvas_surface_widget.dart:187` - surface builds main output during paint host build.
- `lib/src/surface/canvas_surface_widget.dart:200` - surface builds overlay output during paint host build.
- `lib/src/surface/canvas_surface_widget.dart:210` - surface installs `MainFramePainter`.
- `lib/src/surface/canvas_surface_widget.dart:211` - surface installs `OverlayFramePainter`.
- `lib/src/surface/main_painter.dart:31` - main painter repaint check compares output identity.
- `lib/src/surface/overlay_painter.dart:28` - overlay painter repaint check compares output identity.
- `test/frame/fixtures/repaint_bus_output_fixture.dart:32` - frame test asserts selected-move main signal reason.
- `test/frame/fixtures/repaint_bus_output_fixture.dart:50` - frame test asserts marquee overlay target flag.
- `test/surface/fixtures/widget_paint_fixture.dart:219` - surface widget fixture reads main painter output signal reason.

## Search Coverage

- Inspected: complete files `lib/src/frame/frame_engine.dart`,
  `lib/src/frame/frame_repaint_signal.dart`,
  `lib/src/surface/canvas_surface_widget.dart`,
  `lib/src/surface/main_painter.dart`, and
  `lib/src/surface/overlay_painter.dart`.
- Inspected: focused runtime and API ranges
  `lib/src/api/canvas_runtime_surface_bridge.dart:1-113`,
  `lib/src/runtime/runtime_root.dart:140-430`,
  `lib/src/runtime/runtime_root.dart:1200-1245`,
  `lib/src/runtime/runtime_root.dart:1460-1520`, and
  `lib/src/runtime/runtime_root.dart:2710-2745`.
- Inspected: focused test ranges
  `test/frame/fixtures/repaint_bus_output_fixture.dart:1-105` and
  `test/surface/fixtures/widget_paint_fixture.dart:180-245`.
- Searched: `rg -n "FrameRepaintSignal|repaintSignal|shouldRepaint|buildSurfaceMainFrame|buildSurfaceOverlayFrame|ValueListenableBuilder|CustomPaint\\(" lib test docs tool`.
- Searched: `rg -n "_state\\.value|notifyListeners\\(|buildMainFrameWithAssetBindings|buildResourceFreeOverlayFrame|buildResourceFreeMainFrame|FrameRepaintSignal|repaintSignal" lib/src/runtime/runtime_root.dart lib/src/frame lib/src/surface test/frame test/surface`.
- Searched: `rg -n "replaceInteractionPreview|previewRevision|_runtimeState\\(" lib/src/runtime/runtime_root.dart lib/src/contracts/public/canvas_runtime.dart test -g '*.dart'`.
- Searched: `rg -n "repaintSignal\\.(mainCanvas|overlayCanvas|reason)|FrameRepaintSignal.none|repaintSignal:" lib test docs tool`.
- Searched: `rg -n "RepaintBoundary|Listenable|repaint:" lib/src/surface lib/src/frame lib/src/runtime test/surface test/frame`.
- Searched: `rg -n "MainFramePainter\\(|OverlayFramePainter\\(|foregroundPainter:|painter:" lib test docs tool`.
- Not found: production references to `repaintSignal.mainCanvas` or
  `repaintSignal.overlayCanvas` outside construction and storage sites.
- Not found: `CustomPainter(repaint: ...)` usage or `RepaintBoundary` usage in
  the inspected `lib/src/surface`, `lib/src/frame`, and `lib/src/runtime` paths.
- Not inspected: Flutter framework internals for `CustomPaint` and
  `CustomPainter`; this note records repository behavior only.

## Observed Architecture Facts

- Pattern observed: frame output objects carry repaint metadata from frame
  planning into painter delegates (`lib/src/frame/frame_paint_output.dart:33`,
  `lib/src/frame/frame_paint_output.dart:45`,
  `lib/src/surface/main_painter.dart:12`,
  `lib/src/surface/overlay_painter.dart:12`).
- Data flow: runtime state mutation -> `_state.value`
  (`lib/src/runtime/runtime_root.dart:1500`) -> surface `ValueListenableBuilder`
  (`lib/src/surface/canvas_surface_widget.dart:91`) -> both frame-output builder
  calls (`lib/src/surface/canvas_surface_widget.dart:187`,
  `lib/src/surface/canvas_surface_widget.dart:200`) -> one `CustomPaint`
  (`lib/src/surface/canvas_surface_widget.dart:208`).
- Data flow: main frame construction -> `FrameRepaintSignal(mainCanvas: true,
  overlayCanvas: false)` (`lib/src/frame/frame_engine.dart:190`,
  `lib/src/frame/frame_engine.dart:192`,
  `lib/src/frame/frame_engine.dart:193`) -> `MainFramePaintOutput.repaintSignal`
  (`lib/src/frame/frame_paint_output.dart:33`).
- Data flow: overlay plan primitive count -> `overlayCanvas` boolean
  (`lib/src/frame/frame_engine.dart:163`) -> `OverlayFramePaintOutput.repaintSignal`
  (`lib/src/frame/frame_paint_output.dart:45`).
- Key dependencies: `CanvasSurface` depends on `CanvasRuntimeSurfacePort`
  (`lib/src/surface/canvas_surface_widget.dart:4`), `MainFramePainter`
  (`lib/src/surface/canvas_surface_widget.dart:9`), and `OverlayFramePainter`
  (`lib/src/surface/canvas_surface_widget.dart:10`); the port depends on
  `RuntimeRoot` (`lib/src/api/canvas_runtime_surface_bridge.dart:12`) and frame
  output types (`lib/src/api/canvas_runtime_surface_bridge.dart:11`).

## Open Questions

- Whether any downstream package consumes `MainFramePaintOutput.repaintSignal` or
  `OverlayFramePaintOutput.repaintSignal` outside this repository was not
  inspected.
- Whether Flutter framework behavior would coalesce paints for this exact
  `CustomPaint` arrangement was not inspected; this research is limited to
  repository-local code paths and tests.
