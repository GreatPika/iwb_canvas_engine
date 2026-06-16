---
date: 2026-06-16
researcher: Codex
commit: 2fc64dfd
branch: new-architecture
research_question: "Map the existing code paths behind the problematic Android Flutter performance measurements and identify all possible implementation areas involved."
---

# Research: Android Performance Hotspot Paths

## Summary

The current Android performance artifacts show the largest measured build-side
work in large-document scenarios and in interactions that first load a 50k or
100k fixture inside the traced action. Generated artifact exception: the raw
measurements live under `example/build/flutter_performance/` and do not have
stable source line numbers. The largest build summaries in the current artifact
set are `load_document.100k` at 195.75 ms average / 1758.14 ms worst,
`camera_pan.100k` at 88.55 ms average / 1813.91 ms worst,
`first_canvas_frame.50k` at 125.71 ms average / 1128.17 ms worst,
`json_export.50k` at 103.37 ms average / 1028.29 ms worst,
`selection_move.50k` at 95.78 ms average / 1045.95 ms worst,
`marquee_select.50k` at 92.62 ms average / 1105.28 ms worst,
`eraser_dense_50k` at 94.34 ms average / 1126.37 ms worst,
`eraser_normal.50k` at 88.31 ms average / 1054.18 ms worst, and
`line_two_tap.50k` at 87.56 ms average / 1128.54 ms worst. The generated
summaries report `missed_frame_rasterizer_budget_count` as `0` for all 26
scenarios.

The performance route itself is an artifact/completion gate, not a numeric
performance threshold gate. The repository documentation states that the route
does not define numeric pass/fail thresholds (`docs/verification/performance.md:30`,
`docs/verification/performance.md:32`) and that p95, p99, frame-budget,
baseline-diff, repeat-count, and regression-threshold policy are not claimed by
this route (`docs/verification/performance.md:112`,
`docs/verification/performance.md:118`). The current traces therefore identify
which repository code paths are exercised by heavy scenarios, but they do not
contain CPU-sample attribution that proves exclusive cost ownership for one
function or subsystem.

The researched paths converge on a small set of existing implementation areas:
document JSON import and store installation, spatial index replacement and
spatial queries, runtime surface-frame publication, `CanvasSurface` output
cache rebuilds, frame capture and paint-plan construction, interaction/read
adapters for selection, marquee, draw, line, and eraser, resource/text/export
ports, and the Flutter performance driver/checker route.

## Detailed Findings

### 1. Measurement Route And Artifact Semantics

- **Location**: primary `docs/verification/performance.md:30`; related
  `example/integration_test/perf_canvas_surface_test.dart:21`,
  `example/test_driver/perf_driver.dart:57`,
  `tool/check_flutter_performance_artifacts.dart:249`.
- **Description**: `docs/verification/performance.md` owns the official Flutter
  performance route and describes it as a release-blocking completion and
  artifact-production gate, not a numeric threshold gate
  (`docs/verification/performance.md:30`,
  `docs/verification/performance.md:33`). The documented command uses
  `flutter drive --profile --no-dds` from the example app
  (`docs/verification/performance.md:40`,
  `docs/verification/performance.md:46`).
- **Dependencies**: The integration test mounts `PerformanceHost`, iterates
  `allPerformanceScenarios`, and calls `scenario.runTraced` for each scenario
  (`example/integration_test/perf_canvas_surface_test.dart:18`,
  `example/integration_test/perf_canvas_surface_test.dart:23`). The traced
  runner wraps scenario action, settle, optional after-settle, and another
  settle in `binding.traceAction` using the scenario id as `reportKey`
  (`example/lib/perf/performance_scenario.dart:96`,
  `example/lib/perf/performance_scenario.dart:104`).
- **Data flow**: `traceAction` report data flows to the driver callback, where
  each entry is converted through `Timeline.fromJson`, summarized with
  `TimelineSummary.summarize`, and written through `writeTimelineToFile` with
  `includeSummary: true` (`example/test_driver/perf_driver.dart:46`,
  `example/test_driver/perf_driver.dart:63`). The checker parses required
  scenario ids from the catalog and verifies the artifact directory shape and
  JSON shape (`tool/check_flutter_performance_artifacts.dart:249`,
  `tool/check_flutter_performance_artifacts.dart:263`,
  `tool/check_flutter_performance_artifacts.dart:349`).
- **Evidence consequence**: Because the route explicitly excludes numeric
  threshold policy (`docs/verification/performance.md:114`,
  `docs/verification/performance.md:116`), the current Android summaries are
  evidence of measured trace behavior and artifact shape, not a repository
  pass/fail baseline.

### 2. Trace Window Shape

- **Location**: primary `example/integration_test/perf_canvas_surface_test.dart:7`;
  related `example/lib/perf/performance_scenario.dart:24`.
- **Description**: The integration route uses a fixed settle window of 8 frame
  pumps at 16 ms and then a 500 ms asynchronous delay
  (`example/integration_test/perf_canvas_surface_test.dart:7`,
  `example/integration_test/perf_canvas_surface_test.dart:9`,
  `example/integration_test/perf_canvas_surface_test.dart:47`,
  `example/integration_test/perf_canvas_surface_test.dart:53`). Scenario-level
  frame steps also default to 16 ms (`example/lib/perf/performance_scenario.dart:24`,
  `example/lib/perf/performance_scenario.dart:38`).
- **Dependencies**: Each scenario supplies its own action frames and then the
  shared settle frames inside the same traced action
  (`example/lib/perf/performance_scenario.dart:96`,
  `example/lib/perf/performance_scenario.dart:102`).
- **Data flow**: The number of full frame events included in each generated
  `timeline_summary.json` follows from the scenario action frames plus this
  bounded settle window. Generated artifact exception: the current summaries
  show 9 frames for `load_document.*`, 21 frames for `camera_pan.*`, 10 to 13
  frames for most single-action flows, and 19 frames for `text_edit.open_commit`.
- **Evidence consequence**: The summaries are short action-window measurements,
  so p99 often equals worst frame in the generated artifacts; that equality is
  an artifact of short trace windows, not a separately configured percentile
  policy.

### 3. Document Load And First Canvas Frame

- **Location**: primary `example/lib/perf/performance_scenario.dart:137`;
  related `lib/src/edit/staged_document_load.dart:123`,
  `lib/src/runtime/runtime_root.dart:1746`,
  `lib/src/frame/frame_engine.dart:97`.
- **Description**: `load_document.1k`, `load_document.10k`,
  `load_document.50k`, `load_document.100k`, and `first_canvas_frame.50k` all
  use `_loadDocumentScenario`, which builds a rect fixture, encodes it to JSON,
  calls `context.runtime.edits.loadDocumentFromJson(...)`, and pumps one
  scenario frame (`example/lib/perf/performance_scenario.dart:109`,
  `example/lib/perf/performance_scenario.dart:113`,
  `example/lib/perf/performance_scenario.dart:141`,
  `example/lib/perf/performance_scenario.dart:144`).
- **Dependencies**: `performanceRectDocument` creates one layer and generates
  `elementCount` rect elements (`example/lib/perf/performance_fixtures.dart:12`,
  `example/lib/perf/performance_fixtures.dart:17`). Each rect has id
  `r$index`, translated by grid coordinates, and size 2x2
  (`example/lib/perf/performance_fixtures.dart:115`,
  `example/lib/perf/performance_fixtures.dart:122`).
- **Data flow**: The public edit port calls the load-document path
  (`lib/src/api/canvas_runtime.dart:38`,
  `lib/src/contracts/public/canvas_runtime.dart:138`), the edit kernel calls
  `_installLoadedDocument` (`lib/src/edit/edit_kernel.dart:324`,
  `lib/src/edit/edit_kernel.dart:332`), and `RuntimeRoot` delegates to
  `_loadDocumentFromJson` (`lib/src/runtime/runtime_root.dart:1746`). The load
  pipeline decodes schema-v1 JSON and prepares a store import
  (`lib/src/edit/staged_document_load.dart:123`,
  `lib/src/edit/staged_document_load.dart:144`), then the store installs the
  prepared document (`lib/src/store/document_store_kernel.dart:354`,
  `lib/src/store/document_store_kernel.dart:360`).
- **Data flow**: Load effects include projection, spatial document replacement,
  resource document replacement, main+overlay repaint, optional selection, and
  public-state effects (`lib/src/runtime/runtime_root.dart:2913`,
  `lib/src/runtime/runtime_root.dart:2920`). Spatial replacement schedules a
  replacement rebuild and clears indexes (`lib/src/geometry/spatial_kernel.dart:67`,
  `lib/src/geometry/spatial_kernel.dart:78`,
  `lib/src/geometry/spatial_kernel.dart:153`,
  `lib/src/geometry/spatial_kernel.dart:162`).
- **Evidence consequence**: The generated heavy build summaries for
  `load_document.50k`, `load_document.100k`, and `first_canvas_frame.50k`
  exercise JSON encoding/decoding, store installation, spatial replacement, and
  the first main+overlay surface-frame rebuild in the same traced action.

### 4. Surface Frame Publication And Output Cache Rebuild

- **Location**: primary `lib/src/runtime/runtime_root.dart:1573`; related
  `lib/src/surface/canvas_surface_widget.dart:262`,
  `lib/src/surface/surface_frame_output_cache.dart:42`.
- **Description**: Runtime state publication constructs `CanvasRuntimeState`,
  publishes a surface frame when a repaint target exists, and then updates the
  public state value (`lib/src/runtime/runtime_root.dart:1573`,
  `lib/src/runtime/runtime_root.dart:1597`). `_publishSurfaceFrame` requires an
  active surface token, increments generation, and writes a
  `RuntimeSurfaceFrameSignal` (`lib/src/runtime/runtime_root.dart:1600`,
  `lib/src/runtime/runtime_root.dart:1608`).
- **Dependencies**: `PerformanceHost` builds `CanvasSurface` and
  `CanvasTextEditingOverlay` over the controller runtime
  (`example/lib/perf/performance_host.dart:59`,
  `example/lib/perf/performance_host.dart:69`). `CanvasSurface` attaches the
  runtime surface, creates a resource session, installs it, and listens to
  `port.surfaceFrame` (`lib/src/surface/canvas_surface_widget.dart:115`,
  `lib/src/surface/canvas_surface_widget.dart:137`).
- **Data flow**: `CanvasSurface._handleSurfaceFrame` calls `setState` and queues
  the runtime frame in `_outputCache`
  (`lib/src/surface/canvas_surface_widget.dart:262`,
  `lib/src/surface/canvas_surface_widget.dart:269`). During build,
  `_updateOutputCacheForBuildInputs` applies pending runtime frames
  (`lib/src/surface/canvas_surface_widget.dart:228`,
  `lib/src/surface/canvas_surface_widget.dart:244`). `SurfaceFrameOutputCache`
  rebuilds main and/or overlay outputs according to the repaint target
  (`lib/src/surface/surface_frame_output_cache.dart:42`,
  `lib/src/surface/surface_frame_output_cache.dart:52`).
- **Data flow**: Main output flows through `FrameEngine._buildMainFrame`, which
  captures the frame, builds ordinary paint, selected-move supplement, static
  background, selection decoration, render primitive snapshot, and asset
  bindings (`lib/src/frame/frame_engine.dart:97`,
  `lib/src/frame/frame_engine.dart:125`). Overlay output flows through overlay
  frame build and preview planning (`lib/src/frame/frame_engine.dart:152`,
  `lib/src/frame/frame_engine.dart:156`).
- **Evidence consequence**: Every researched heavy scenario eventually reaches
  this surface-frame and output-cache path, but the repaint target differs by
  action: document load targets both canvases, selection changes target main,
  marquee preview targets overlay, and camera changes target both.

### 5. Camera Pan

- **Location**: primary `example/lib/perf/performance_scenario.dart:149`;
  related `lib/src/runtime/runtime_root.dart:1247`,
  `lib/src/frame/frame_capture_service.dart:55`.
- **Description**: `camera_pan.50k` and `camera_pan.100k` load 50k/100k rect
  documents, pump once, then run 12 `runtime.camera.panBy(...)` steps with a
  pump after each step (`example/lib/perf/performance_scenario.dart:114`,
  `example/lib/perf/performance_scenario.dart:115`,
  `example/lib/perf/performance_scenario.dart:153`,
  `example/lib/perf/performance_scenario.dart:158`).
- **Dependencies**: The public camera port delegates `panBy` to
  `RuntimeRoot.panCameraBy` (`lib/src/runtime/runtime_root.dart:2637`,
  `lib/src/runtime/runtime_root.dart:2640`), which calls `setCameraOffset`
  (`lib/src/runtime/runtime_root.dart:1264`,
  `lib/src/runtime/runtime_root.dart:1266`). `setCameraOffset` updates the view
  camera, increments view-camera revision, and publishes a main+overlay repaint
  target with reason `view_camera` (`lib/src/runtime/runtime_root.dart:1247`,
  `lib/src/runtime/runtime_root.dart:1261`).
- **Data flow**: Frame capture computes effective world bounds from viewport
  bounds shifted by camera offset (`lib/src/frame/captured_frame.dart:24`,
  `lib/src/frame/captured_frame.dart:35`). Capture queries spatial paint
  candidates (`lib/src/frame/frame_capture_service.dart:55`,
  `lib/src/frame/frame_capture_service.dart:84`), `TileIndex.query` enumerates
  tiles and candidates (`lib/src/geometry/tile_index.dart:48`,
  `lib/src/geometry/tile_index.dart:91`), and `OrdinaryPaintPlanner` filters
  candidates and builds or reads render records
  (`lib/src/frame/ordinary_paint_planner.dart:74`,
  `lib/src/frame/ordinary_paint_planner.dart:119`).
- **Evidence consequence**: The generated `camera_pan.100k` summary includes
  both the initial 100k document load and repeated camera invalidation/paint
  planning over shifted viewport bounds within one trace.

### 6. Selection, Selection Move, And Marquee

- **Location**: primary `example/lib/perf/performance_scenario.dart:163`;
  related `lib/src/runtime/runtime_root.dart:790`,
  `lib/src/runtime/runtime_interaction_read_adapter.dart:171`.
- **Description**: `selection_tap.10k` loads 10k rects, selects `r0`, and pumps;
  `selection_move.10k` and `selection_move.50k` load a rect fixture, select
  `r0`, then call `moveSelection(Offset(16, 12), timestampMs: 20)`
  (`example/lib/perf/performance_scenario.dart:163`,
  `example/lib/perf/performance_scenario.dart:191`). `marquee_select.50k`
  loads 50k rects and performs a move-mode touch drag from `(0,0)` to
  `(180,180)` (`example/lib/perf/performance_scenario.dart:196`,
  `example/lib/perf/performance_scenario.dart:208`).
- **Dependencies**: `RuntimeRoot.setSelection` delegates to `SelectionKernel`
  and publishes selection change (`lib/src/runtime/runtime_root.dart:790`,
  `lib/src/selection/selection_kernel.dart:29`). `RuntimeRoot.moveSelection`
  creates a translation transform and delivers a selection transform
  (`lib/src/runtime/runtime_root.dart:812`,
  `lib/src/runtime/runtime_root.dart:822`). The command facts adapter resolves
  selected ids in document order and filters movable elements
  (`lib/src/runtime/runtime_command_facts_adapter.dart:37`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:54`).
- **Data flow**: Marquee pointer input enters `RuntimeRoot.handlePointer`
  (`lib/src/runtime/runtime_root.dart:1299`), `InteractionEngine` starts
  marquee when selected move is not admitted
  (`lib/src/interaction/interaction_engine.dart:440`,
  `lib/src/interaction/interaction_engine.dart:455`), and
  `RuntimeInteractionReadAdapter.marqueeCommitFacts` queries spatial candidates
  and resolves candidates to selected ids
  (`lib/src/runtime/runtime_interaction_read_adapter.dart:171`,
  `lib/src/runtime/runtime_interaction_read_adapter.dart:196`). The runtime
  delivers marquee commit through `CommitPlan.replaceSelection`
  (`lib/src/runtime/runtime_root.dart:2206`,
  `lib/src/edit/commit_plan.dart:16`,
  `lib/src/edit/commit_plan.dart:25`).
- **Data flow**: Spatial hit/marquee traversal routes through `SpatialKernel`
  and tile index queries (`lib/src/geometry/spatial_kernel.dart:125`,
  `lib/src/geometry/spatial_kernel.dart:166`,
  `lib/src/geometry/tile_index.dart:48`,
  `lib/src/geometry/tile_index.dart:88`). Selection changes publish main-canvas
  repaint (`lib/src/runtime/runtime_root.dart:1560`,
  `lib/src/runtime/runtime_root.dart:1566`), while marquee preview maps to
  overlay repaint (`lib/src/runtime/runtime_root.dart:1666`,
  `lib/src/runtime/runtime_root.dart:1680`).
- **Evidence consequence**: The heavy `selection_move.50k` and
  `marquee_select.50k` summaries include large fixture setup plus selection or
  marquee paths that touch selection normalization, commit effects, spatial
  queries, and frame capture/planning.

### 7. Draw, Line, And Eraser

- **Location**: primary `example/lib/perf/performance_scenario.dart:213`;
  related `lib/src/interaction/interaction_engine.dart:491`,
  `lib/src/runtime/runtime_interaction_read_adapter.dart:325`.
- **Description**: `pencil_draw.10k`, `marker_draw.10k`,
  `eraser_normal.50k`, and `eraser_dense_50k` share `_drawScenario`, which uses
  10k elements only when the id ends with `.10k` and otherwise uses 50k
  elements (`example/lib/perf/performance_scenario.dart:213`,
  `example/lib/perf/performance_scenario.dart:219`). The helper sends down,
  move, and terminal up pointer samples and pumps after each sample
  (`example/lib/perf/performance_scenario.dart:461`,
  `example/lib/perf/performance_scenario.dart:485`). `line_two_tap.50k`
  sends two down/up tap pairs after loading 50k rects
  (`example/lib/perf/performance_scenario.dart:232`,
  `example/lib/perf/performance_scenario.dart:255`).
- **Dependencies**: Public tool calls delegate to runtime tool methods
  (`lib/src/runtime/runtime_root.dart:2724`,
  `lib/src/runtime/runtime_root.dart:2771`). Draw-mode pointer down routes
  eraser to `_handleEraserDown`, line to `_handleLineDown`, and other draw
  tools to stroke start (`lib/src/interaction/interaction_engine.dart:491`,
  `lib/src/interaction/interaction_engine.dart:498`).
- **Data flow**: Pencil/marker stroke start and move produce stroke previews,
  then terminal input returns a stroke commit intent
  (`lib/src/interaction/draw_stroke_machine.dart:22`,
  `lib/src/interaction/draw_stroke_machine.dart:143`), which runtime commits as
  a `CanvasStrokeElement` (`lib/src/runtime/runtime_root.dart:2286`,
  `lib/src/runtime/runtime_root.dart:2299`). Line first tap and second endpoint
  produce pending/line preview and a line commit intent
  (`lib/src/interaction/line_machine.dart:11`,
  `lib/src/interaction/line_machine.dart:205`,
  `lib/src/runtime/runtime_root.dart:2356`,
  `lib/src/runtime/runtime_root.dart:2370`).
- **Data flow**: Eraser preview and terminal facts query the interaction read
  adapter, normalize a corridor envelope, query the paint spatial index, enforce
  candidate/exact-check budgets, and return erased ids in document order
  (`lib/src/runtime/runtime_interaction_read_adapter.dart:241`,
  `lib/src/runtime/runtime_interaction_read_adapter.dart:381`). Runtime removes
  each erased id and emits an erase action intent
  (`lib/src/runtime/runtime_root.dart:2427`,
  `lib/src/runtime/runtime_root.dart:2437`).
- **Data flow**: Preview repaint kinds map to overlay repaint
  (`lib/src/runtime/runtime_root.dart:1666`,
  `lib/src/runtime/runtime_root.dart:1684`). Committed stroke and line records
  later become `StrokeRenderRow` and `LineRenderRow`
  (`lib/src/frame/render_element_record.dart:185`,
  `lib/src/frame/render_element_record.dart:303`) and paint through main frame
  record dispatch (`lib/src/frame/main_frame_record_painter.dart:154`,
  `lib/src/frame/main_frame_record_painter.dart:183`).
- **Evidence consequence**: The generated heavy 50k draw/line/eraser summaries
  cover large fixture setup, pointer routing, preview repaint, commit delivery,
  and for eraser the corridor spatial read path.

### 8. Text, Resource, Runtime Swap, Dispose, And JSON Export

- **Location**: primary `example/lib/perf/performance_scenario.dart:275`;
  related `lib/src/resources/resource_kernel.dart:31`,
  `lib/src/api/canvas_codec.dart:12`.
- **Description**: `text_edit.open_commit` loads the smoke document, resets
  camera, switches to move mode, listens for context action requests, double
  taps, and commits the resulting text edit session after settle
  (`example/lib/perf/performance_scenario.dart:275`,
  `example/lib/perf/performance_scenario.dart:294`,
  `example/lib/perf/performance_scenario.dart:421`). Its generated artifact has
  low build time relative to large-fixture scenarios.
- **Dependencies**: Text style change loads one text element plus 9,999 rects
  and updates bold, italic, underline, color, and font size
  (`example/lib/perf/performance_scenario.dart:299`,
  `example/lib/perf/performance_scenario.dart:315`). Sparse update compiles
  element deltas and touched facts (`lib/src/edit/edit_session.dart:543`,
  `lib/src/edit/edit_session.dart:830`), and text deltas mark font/layout fields
  as bounds changes (`lib/src/store/document_store_kernel.dart:1351`,
  `lib/src/store/document_store_kernel.dart:1370`).
- **Data flow**: Resource scenarios load one-image documents and call
  `markAllResourcesDirty` or `markResourceDirty`
  (`example/lib/perf/performance_scenario.dart:322`,
  `example/lib/perf/performance_scenario.dart:355`). Resource dirty operations
  increment visual revision and runtime invalidates the active resource session
  before publishing repaint (`lib/src/resources/resource_kernel.dart:31`,
  `lib/src/resources/resource_kernel.dart:55`,
  `lib/src/runtime/runtime_root.dart:1909`,
  `lib/src/runtime/runtime_root.dart:1956`). Asset binding resolves captured
  resource descriptors through the surface resource session
  (`lib/src/frame/paint_asset_binding_service.dart:23`,
  `lib/src/resources/surface_resource_session.dart:98`).
- **Data flow**: `surface_runtime_swap` and `dispose_during_preview` create a
  replacement `CanvasRuntime`, load it, swap it into the host, notify listeners,
  and dispose the previous runtime (`example/lib/perf/performance_scenario.dart:372`,
  `example/lib/perf/performance_scenario.dart:400`,
  `example/lib/perf/performance_host.dart:30`,
  `example/lib/perf/performance_host.dart:35`). `CanvasSurface.didUpdateWidget`
  handles runtime identity changes by detaching and attaching runtime surfaces
  (`lib/src/surface/canvas_surface_widget.dart:61`,
  `lib/src/surface/canvas_surface_widget.dart:69`).
- **Data flow**: `json_export.50k` loads 50k rects, reads the draft document
  inside an edit callback, and encodes it through `performanceFixtureJson`
  (`example/lib/perf/performance_scenario.dart:424`,
  `example/lib/perf/performance_scenario.dart:436`). `performanceFixtureJson`
  calls `encodeCanvasDocumentToJson`, which calls `jsonEncode` over the encoded
  document (`example/lib/perf/performance_fixtures.dart:111`,
  `lib/src/api/canvas_codec.dart:12`,
  `lib/src/api/canvas_codec.dart:18`).
- **Evidence consequence**: The heavy `json_export.50k` summary includes
  document load, draft materialization, and schema-v1 JSON encoding within the
  traced action.

## Code References

- `docs/verification/performance.md:30` - official Flutter performance route
  ownership.
- `docs/verification/performance.md:45` - profile-drive command.
- `docs/verification/performance.md:58` - scenario catalog table start.
- `docs/verification/performance.md:94` - artifact root contract.
- `docs/verification/performance.md:112` - gate semantics section.
- `example/integration_test/perf_canvas_surface_test.dart:21` - scenario loop.
- `example/integration_test/perf_canvas_surface_test.dart:47` - bounded settle
  helper.
- `example/lib/perf/performance_scenario.dart:96` - traced scenario wrapper.
- `example/lib/perf/performance_scenario.dart:107` - unmodifiable scenario list.
- `example/lib/perf/performance_scenario.dart:137` - load-document scenario
  helper.
- `example/lib/perf/performance_scenario.dart:149` - camera pan scenario helper.
- `example/lib/perf/performance_scenario.dart:177` - selection move scenario
  helper.
- `example/lib/perf/performance_scenario.dart:196` - marquee scenario helper.
- `example/lib/perf/performance_scenario.dart:213` - draw/eraser shared helper.
- `example/lib/perf/performance_scenario.dart:424` - JSON export scenario.
- `example/lib/perf/performance_fixtures.dart:12` - rectangular fixture factory.
- `example/lib/perf/performance_host.dart:59` - host `CanvasSurface`.
- `example/test_driver/perf_driver.dart:57` - timeline JSON conversion.
- `example/test_driver/perf_driver.dart:58` - `TimelineSummary.summarize`.
- `tool/check_flutter_performance_artifacts.dart:249` - catalog id parsing.
- `tool/check_flutter_performance_artifacts.dart:349` - summary shape
  validation.
- `lib/src/runtime/runtime_root.dart:1247` - camera offset mutation.
- `lib/src/runtime/runtime_root.dart:1573` - runtime state publication.
- `lib/src/runtime/runtime_root.dart:1600` - surface frame signal publication.
- `lib/src/runtime/runtime_root.dart:1746` - JSON load installer.
- `lib/src/runtime/runtime_root.dart:2913` - load delivery effects.
- `lib/src/surface/canvas_surface_widget.dart:262` - surface frame listener.
- `lib/src/surface/surface_frame_output_cache.dart:42` - repaint-target output
  cache application.
- `lib/src/frame/frame_engine.dart:97` - main frame build path.
- `lib/src/frame/frame_capture_service.dart:55` - frame capture and spatial
  paint query.
- `lib/src/geometry/tile_index.dart:48` - tile-index spatial traversal.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:171` - marquee commit
  facts.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:325` - eraser facts
  read path.

## Search Coverage

- Inspected: `docs/verification/performance.md`,
  `example/integration_test/perf_canvas_surface_test.dart`,
  `example/test_driver/perf_driver.dart`,
  `tool/check_flutter_performance_artifacts.dart`,
  `test/performance/flutter_performance_route_contract_test.dart`,
  `example/lib/perf/performance_scenario.dart`,
  `example/lib/perf/performance_host.dart`,
  `example/lib/perf/performance_fixtures.dart`, and current generated files
  under `example/build/flutter_performance/`.
- Inspected by focused researchers: `lib/src/api/canvas_runtime.dart`,
  `lib/src/api/canvas_runtime_surface_bridge.dart`,
  `lib/src/contracts/public/canvas_runtime.dart`,
  `lib/src/edit/edit_kernel.dart`, `lib/src/edit/edit_session.dart`,
  `lib/src/edit/staged_document_load.dart`,
  `lib/src/runtime/runtime_root.dart`,
  `lib/src/runtime/runtime_command_facts_adapter.dart`,
  `lib/src/runtime/runtime_interaction_read_adapter.dart`,
  `lib/src/interaction/interaction_engine.dart`,
  `lib/src/interaction/draw_stroke_machine.dart`,
  `lib/src/interaction/line_machine.dart`,
  `lib/src/interaction/eraser_machine.dart`,
  `lib/src/interaction/select_machine.dart`,
  `lib/src/geometry/spatial_kernel.dart`,
  `lib/src/geometry/spatial_index_set.dart`,
  `lib/src/geometry/tile_index.dart`,
  `lib/src/geometry/geometry_policy.dart`,
  `lib/src/geometry/hit_test_policy.dart`,
  `lib/src/frame/frame_engine.dart`,
  `lib/src/frame/frame_capture_service.dart`,
  `lib/src/frame/ordinary_paint_planner.dart`,
  `lib/src/frame/overlay_preview_planner.dart`,
  `lib/src/frame/render_element_record.dart`,
  `lib/src/frame/main_frame_record_painter.dart`,
  `lib/src/surface/canvas_surface_widget.dart`,
  `lib/src/surface/surface_frame_output_cache.dart`,
  `lib/src/surface/layer_paint_host.dart`,
  `lib/src/surface/main_painter.dart`,
  `lib/src/surface/overlay_painter.dart`,
  `lib/src/resources/resource_kernel.dart`,
  `lib/src/resources/surface_resource_session.dart`, and
  `lib/src/api/canvas_codec.dart`.
- Searched: scenario ids, `allPerformanceScenarios`, `traceAction`,
  `TimelineSummary`, `writeTimelineToFile`, `flutter_performance`,
  `loadDocumentFromJson`, `replaceDraftDocument`, `panBy`, `setCameraOffset`,
  `moveSelection`, `marquee`, `handlePointer`, `CanvasDrawTool`, `eraser`,
  `line`, `pencil`, `marker`, `surfaceFrame`, `SurfaceFrameOutputCache`,
  `queryPaint`, `queryMarquee`, `TileIndex`, `resource`, `textEditing`, and
  `encodeCanvasDocumentToJson`.
- Not found: a repository-local Android-specific device selection policy; the
  route documents `flutter drive --profile --no-dds` and writes artifacts under
  `example/build/flutter_performance/` (`docs/verification/performance.md:45`,
  `example/test_driver/perf_driver.dart:36`). No numeric threshold, baseline,
  repeat-count, or regression policy was found in the inspected route files;
  the route documentation explicitly leaves those unclaimed
  (`docs/verification/performance.md:114`,
  `docs/verification/performance.md:118`).
- Not inspected: CPU-sample attribution outside the generated Flutter timeline
  summary files, because the current artifact route stores Flutter timeline and
  summary JSON but no separate sampled profiler report.

## Observed Architecture Facts

- Pattern observed: scenario setup commonly loads large generated fixtures
  inside the traced action before the measured interaction, e.g.
  `camera_pan.*`, `selection_move.*`, `marquee_select.50k`, draw/eraser/line,
  and `json_export.50k` (`example/lib/perf/performance_scenario.dart:153`,
  `example/lib/perf/performance_scenario.dart:181`,
  `example/lib/perf/performance_scenario.dart:200`,
  `example/lib/perf/performance_scenario.dart:219`,
  `example/lib/perf/performance_scenario.dart:428`).
- Pattern observed: runtime changes publish repaint intent through
  `_publishRuntimeState` and `_publishSurfaceFrame`, then `CanvasSurface`
  rebuilds frame outputs through `SurfaceFrameOutputCache`
  (`lib/src/runtime/runtime_root.dart:1573`,
  `lib/src/runtime/runtime_root.dart:1600`,
  `lib/src/surface/canvas_surface_widget.dart:262`,
  `lib/src/surface/surface_frame_output_cache.dart:42`).
- Data flow: large fixture -> public runtime API -> store/spatial/resource
  effects -> surface frame signal -> frame capture/planning -> main/overlay
  paint output (`example/lib/perf/performance_fixtures.dart:12`,
  `lib/src/runtime/runtime_root.dart:2913`,
  `lib/src/surface/canvas_surface_widget.dart:242`,
  `lib/src/frame/frame_engine.dart:97`).
- Key dependencies: spatial reads route through `SpatialKernel` and
  `TileIndex` for paint, marquee, and eraser facts
  (`lib/src/geometry/spatial_kernel.dart:125`,
  `lib/src/geometry/tile_index.dart:48`,
  `lib/src/runtime/runtime_interaction_read_adapter.dart:171`,
  `lib/src/runtime/runtime_interaction_read_adapter.dart:325`).
- Evidence consequence: the current heavy build measurements identify shared
  runtime/frame/spatial paths reached by the scenarios, but current artifacts do
  not prove which individual function accounts for each heavy frame.

## Open Questions

- The generated timeline summaries do not include CPU-sample attribution, so
  this research does not distinguish setup cost from steady-state interaction
  cost inside scenarios that load large documents before interacting.
- The inspected route does not define repeat count, baseline, or regression
  thresholds, so current measurements are single artifact snapshots rather than
  a statistical baseline.
