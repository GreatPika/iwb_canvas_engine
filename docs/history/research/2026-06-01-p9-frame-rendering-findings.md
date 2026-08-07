---
date: 2026-06-01
researcher: Codex
commit: 8ea63e69
branch: new-architecture
research_question: "Research how the implemented P9 frame rendering and cache findings relate to code, design, contracts, source-of-truth docs, guardrails, tests, and diagrams."
---

# Research: P9 Frame Rendering Findings

## Summary

P9 is implemented as an internal frame pipeline: `FrameEngine` captures immutable
main and overlay frame inputs, delegates ordinary planning, selected-move
supplement staging, overlay preview admission, asset binding, selection
decoration, static background planning, and repaint signal production to
frame-private collaborators (`lib/src/frame/frame_engine.dart:33`,
`lib/src/frame/frame_engine.dart:39`, `lib/src/frame/frame_engine.dart:44`,
`lib/src/frame/frame_engine.dart:51`, `lib/src/frame/frame_engine.dart:57`).
The durable graph records P9 as closed and maps the `frame.renderer` node to
`FrameEngine` plus the implemented collaborators
(`docs/architecture/architecture_graph.yaml:54`,
`docs/architecture/architecture_graph.yaml:398`,
`docs/architecture/architecture_graph.yaml:413`).

The reviewed findings cluster into four factual areas: selected-move supplement
staging after ordinary planning, overlay eraser preview admission and passive
painting, frame/cache guardrail recognition surfaces, and source-of-truth file
layout naming. Current tests cover candidate selected supplement staging,
ordinary non-candidate spatial rejection, one-point eraser admission/capture, and
guardrail runner registration, while searches found no selected-supplement test
for non-candidate shifted spatial results and no raster/recorded paint assertion
for one-point eraser corridor output.

The guardrail implementation is runner-registered and structurally scans
`lib/src/frame/**` (`tool/guardrails/src/guardrail_registry.dart:196`,
`tool/guardrails/src/guardrail_executor.dart:268`,
`tool/guardrails/src/frame_cache_guardrail_checks.dart:205`). Its cache
exclusion checks currently scan a fixed set of cached paint classes and token
sets, while the source-of-truth docs describe ordinary cached values, selection
flags, and global scene sort constraints in broader language
(`docs/contracts/cache_policy.md:65`, `docs/contracts/cache_policy.md:74`,
`docs/verification/guardrails.md:212`, `docs/verification/guardrails.md:214`).

Additional P9 review coverage found adjacent facts in preview and committed
rendering: marquee overlay capture freezes selection style but the primitive
stores only a rectangle, one-point pencil/marker overlay previews and one-point
committed strokes are admitted before reaching path/point painters, and
same-point committed lines receive geometry bounds before `drawLine`
consumption (`lib/src/frame/captured_frame.dart:14`,
`lib/src/frame/overlay_preview_planner.dart:104`,
`lib/src/frame/overlay_frame_painter.dart:47`,
`lib/src/frame/render_family_caches.dart:130`,
`lib/src/frame/main_frame_record_painter.dart:189`). The same pass found P9
documentation-source drift around active resource-session ownership,
`beginFrameResourcePass()` sequencing, and registry-backed P9 test inventory
(`docs/architecture/01_runtime_ownership.md:200`,
`docs/diagrams/seq_main_paint.mmd:100`,
`docs/_registry/sections.yaml:619`).

## Detailed Findings

### 1. P9 Frame Owner And Implemented Layout

- **Location**: primary `lib/src/frame/frame_engine.dart:33`; graph at
  `docs/architecture/architecture_graph.yaml:398`.
- **Description**: `FrameEngine` is the frame-private facade. It constructs
  `FrameCaptureService` with `FrameFactsPort`, `SelectionFactsPort`, and
  `SpatialKernel.queryPaint` (`lib/src/frame/frame_engine.dart:35`,
  `lib/src/frame/frame_engine.dart:39`, `lib/src/frame/frame_engine.dart:42`).
  It also constructs `SelectedMoveSupplementPlanner` with `FrameFactsPort` and
  `SpatialKernel.queryPaint` (`lib/src/frame/frame_engine.dart:44`,
  `lib/src/frame/frame_engine.dart:46`). It owns fields for ordinary planning,
  static background planning, selection decoration, selected order cache, and
  overlay preview planning (`lib/src/frame/frame_engine.dart:51`,
  `lib/src/frame/frame_engine.dart:52`, `lib/src/frame/frame_engine.dart:54`,
  `lib/src/frame/frame_engine.dart:56`, `lib/src/frame/frame_engine.dart:57`).
- **Dependencies**: Frame code imports frame facts, selection facts, spatial
  kernel, captured frame models, paint outputs, repaint signal, planners, and
  render record types (`lib/src/frame/frame_engine.dart:6`,
  `lib/src/frame/frame_engine.dart:7`, `lib/src/frame/frame_engine.dart:9`,
  `lib/src/frame/frame_engine.dart:10`, `lib/src/frame/frame_engine.dart:13`,
  `lib/src/frame/frame_engine.dart:14`, `lib/src/frame/frame_engine.dart:19`).
- **Data flow**: `FrameEngine._buildMainFrame` captures a main frame, builds the
  ordinary plan, builds selected-move supplement output from that ordinary plan,
  builds static background and selection decoration, binds render primitive and
  asset outputs, then returns `MainFramePaintOutput`
  (`lib/src/frame/frame_engine.dart:92`, `lib/src/frame/frame_engine.dart:97`,
  `lib/src/frame/frame_engine.dart:98`, `lib/src/frame/frame_engine.dart:99`,
  `lib/src/frame/frame_engine.dart:118`). Overlay output captures an overlay
  frame, builds an overlay preview plan, and returns `OverlayFramePaintOutput`
  with a repaint signal (`lib/src/frame/frame_engine.dart:145`,
  `lib/src/frame/frame_engine.dart:148`, `lib/src/frame/frame_engine.dart:149`,
  `lib/src/frame/frame_engine.dart:151`, `lib/src/frame/frame_engine.dart:154`).

### 2. Selected-Move Supplement Staging

- **Location**: primary `lib/src/frame/selected_move_supplement_planner.dart:55`.
- **Description**: Without a selected-move preview, the planner returns ordinary
  records unchanged and zero probe counters
  (`lib/src/frame/selected_move_supplement_planner.dart:59`,
  `lib/src/frame/selected_move_supplement_planner.dart:60`,
  `lib/src/frame/selected_move_supplement_planner.dart:97`,
  `lib/src/frame/selected_move_supplement_planner.dart:100`). With a selected
  preview, it computes movable selected ids from captured selection and captured
  row facts, excluding locked and non-transformable rows
  (`lib/src/frame/selected_move_supplement_planner.dart:64`,
  `lib/src/frame/selected_move_supplement_planner.dart:119`,
  `lib/src/frame/selected_move_supplement_planner.dart:124`,
  `lib/src/frame/selected_move_supplement_planner.dart:125`,
  `lib/src/frame/selected_move_supplement_planner.dart:126`).
- **Dependencies**: The planner consumes `FrameFactsPort`, `CapturedMainFrame`,
  `PaintPlan`, `RenderElementRecord`, and a `SelectedMovePaintQuery` returning
  `SpatialQueryResult` (`lib/src/frame/selected_move_supplement_planner.dart:3`,
  `lib/src/frame/selected_move_supplement_planner.dart:8`,
  `lib/src/frame/selected_move_supplement_planner.dart:9`,
  `lib/src/frame/selected_move_supplement_planner.dart:10`,
  `lib/src/frame/selected_move_supplement_planner.dart:12`).
- **Data flow**: The planner removes movable selected ids from ordinary records
  before supplement construction (`lib/src/frame/selected_move_supplement_planner.dart:65`,
  `lib/src/frame/selected_move_supplement_planner.dart:110`,
  `lib/src/frame/selected_move_supplement_planner.dart:115`). It queries a
  shifted paint window using `effectiveWorldBounds.shift(-delta)` and captured
  structural revision (`lib/src/frame/selected_move_supplement_planner.dart:138`,
  `lib/src/frame/selected_move_supplement_planner.dart:163`,
  `lib/src/frame/selected_move_supplement_planner.dart:165`,
  `lib/src/frame/selected_move_supplement_planner.dart:166`). It then iterates
  `spatial.candidates`, filters non-selected handles, validates selected handles
  through `FrameFactsPort`, skips stale candidates, builds shifted records, and
  merges filtered ordinary plus supplement streams by `orderToken`
  (`lib/src/frame/selected_move_supplement_planner.dart:139`,
  `lib/src/frame/selected_move_supplement_planner.dart:140`,
  `lib/src/frame/selected_move_supplement_planner.dart:143`,
  `lib/src/frame/selected_move_supplement_planner.dart:147`,
  `lib/src/frame/selected_move_supplement_planner.dart:154`,
  `lib/src/frame/selected_move_supplement_planner.dart:209`).

### 3. Spatial Result Handling In Ordinary And Supplement Paths

- **Location**: primary `lib/src/geometry/spatial_query_result.dart:3`.
- **Description**: Base `SpatialQueryResult` exposes `hasCandidates => false`
  and `candidates => const []` (`lib/src/geometry/spatial_query_result.dart:3`,
  `lib/src/geometry/spatial_query_result.dart:6`,
  `lib/src/geometry/spatial_query_result.dart:7`). Only
  `SpatialCandidatesResult` overrides `candidates`
  (`lib/src/geometry/spatial_query_result.dart:10`,
  `lib/src/geometry/spatial_query_result.dart:19`). `SpatialBudgetExceededResult`,
  `SpatialInvalidIndexResult`, and `SpatialStaleCandidateResult` do not override
  `candidates` (`lib/src/geometry/spatial_query_result.dart:27`,
  `lib/src/geometry/spatial_query_result.dart:41`,
  `lib/src/geometry/spatial_query_result.dart:47`).
- **Dependencies**: Ordinary planning imports `SpatialCandidatesResult` and checks
  the captured spatial result type (`lib/src/frame/ordinary_paint_planner.dart:3`,
  `lib/src/frame/ordinary_paint_planner.dart:83`). Selected supplement staging
  accepts the broader `SpatialQueryResult` through `SelectedMovePaintQuery`
  (`lib/src/frame/selected_move_supplement_planner.dart:12`,
  `lib/src/frame/selected_move_supplement_planner.dart:13`).
- **Data flow**: Ordinary planning rejects the whole ordinary plan if admitted
  candidates are stale or if the captured spatial result is not
  `SpatialCandidatesResult` (`lib/src/frame/ordinary_paint_planner.dart:72`,
  `lib/src/frame/ordinary_paint_planner.dart:76`,
  `lib/src/frame/ordinary_paint_planner.dart:83`,
  `lib/src/frame/ordinary_paint_planner.dart:86`). Selected supplement staging
  calls `_queryPaint(_shiftedWindow(...))` and iterates `spatial.candidates`
  directly (`lib/src/frame/selected_move_supplement_planner.dart:138`,
  `lib/src/frame/selected_move_supplement_planner.dart:139`). For non-candidate
  shifted result types, that inherited candidate getter is empty
  (`lib/src/geometry/spatial_query_result.dart:7`,
  `lib/src/geometry/spatial_query_result.dart:27`,
  `lib/src/geometry/spatial_query_result.dart:41`,
  `lib/src/geometry/spatial_query_result.dart:47`).

### 4. Selected-Move Supplement Tests And Coverage Boundaries

- **Location**: primary
  `test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart:24`.
- **Description**: The selected supplement fixture selects `a`, `c`, `locked`,
  `stale`, and `offscreen`, builds ordinary records, injects a shifted query that
  returns `SpatialCandidatesResult`, and asserts the shifted query window,
  merged record ids, translation, selected filtering count, supplement count,
  stale skip count, global sort count, and ordinary cache writes during
  supplement (`test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart:25`,
  `test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart:35`,
  `test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart:68`,
  `test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart:73`,
  `test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart:84`,
  `test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart:88`,
  `test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart:99`,
  `test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart:103`).
- **Dependencies**: Stale selected facts are modeled through `staleIds`, and the
  shared test frame facts port returns null for stale ids
  (`test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart:54`,
  `test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart:57`,
  `test/frame/fixtures/ordinary_paint_test_support.dart:350`,
  `test/frame/fixtures/ordinary_paint_test_support.dart:352`).
- **Data flow**: The ordinary all-or-nothing fixture injects
  `SpatialBudgetExceededResult` into captured ordinary planning and asserts an
  ordinary rejected result before a later successful frame writes to cache
  (`test/frame/fixtures/paint_plan_write_all_or_nothing_fixture.dart:64`,
  `test/frame/fixtures/paint_plan_write_all_or_nothing_fixture.dart:69`,
  `test/frame/fixtures/paint_plan_write_all_or_nothing_fixture.dart:76`,
  `test/frame/fixtures/paint_plan_write_all_or_nothing_fixture.dart:81`,
  `test/frame/fixtures/paint_plan_write_all_or_nothing_fixture.dart:82`). Search
  coverage found no selected-supplement fixture under `test/frame/fixtures` or
  `lib/src/frame` that injects `SpatialBudgetExceededResult`,
  `SpatialInvalidIndexResult`, or `SpatialStaleCandidateResult` into the shifted
  supplement query.

### 5. Overlay Eraser Preview Admission And Passive Painting

- **Location**: primary `lib/src/frame/overlay_preview_planner.dart:89`;
  painter at `lib/src/frame/overlay_frame_painter.dart:76`.
- **Description**: Public `CanvasPreviewState.eraser` takes an iterable corridor
  and thickness (`lib/src/contracts/public/canvas_preview.dart:47`,
  `lib/src/contracts/public/canvas_preview.dart:48`,
  `lib/src/contracts/public/canvas_preview.dart:49`). `CanvasEraserPreview`
  stores the corridor as `List.unmodifiable(corridor)`
  (`lib/src/contracts/public/canvas_preview.dart:165`,
  `lib/src/contracts/public/canvas_preview.dart:168`,
  `lib/src/contracts/public/canvas_preview.dart:170`). Overlay capture retains
  every non-none and non-selected-move preview as overlay preview
  (`lib/src/frame/frame_capture_service.dart:39`,
  `lib/src/frame/frame_capture_service.dart:44`,
  `lib/src/frame/frame_capture_service.dart:45`,
  `lib/src/frame/frame_capture_service.dart:46`).
- **Dependencies**: `OverlayPreviewPlanner` imports public preview states and
  captured overlay frames (`lib/src/frame/overlay_preview_planner.dart:3`,
  `lib/src/frame/overlay_preview_planner.dart:4`). `OverlayFramePainter` imports
  immutable frame paint output and overlay preview primitives
  (`lib/src/frame/overlay_frame_painter.dart:5`,
  `lib/src/frame/overlay_frame_painter.dart:6`).
- **Data flow**: `OverlayPreviewPlanner.build` converts `CanvasEraserPreview` to
  `EraserOverlayPrimitive(corridor: preview.corridor, thickness:
  preview.thickness)` (`lib/src/frame/overlay_preview_planner.dart:92`,
  `lib/src/frame/overlay_preview_planner.dart:128`,
  `lib/src/frame/overlay_preview_planner.dart:129`,
  `lib/src/frame/overlay_preview_planner.dart:130`). `EraserOverlayPrimitive`
  copies the corridor into an unmodifiable list
  (`lib/src/frame/overlay_preview_planner.dart:71`,
  `lib/src/frame/overlay_preview_planner.dart:75`,
  `lib/src/frame/overlay_preview_planner.dart:78`). `OverlayFramePainter.paint`
  iterates primitives and dispatches eraser primitives to `_paintEraserOverlay`
  (`lib/src/frame/overlay_frame_painter.dart:18`,
  `lib/src/frame/overlay_frame_painter.dart:40`,
  `lib/src/frame/overlay_frame_painter.dart:41`). `_paintEraserOverlay` calls
  `canvas.drawPoints(PointMode.polygon, primitive.corridor, Paint()...)` with no
  separate corridor-length branch (`lib/src/frame/overlay_frame_painter.dart:76`,
  `lib/src/frame/overlay_frame_painter.dart:77`,
  `lib/src/frame/overlay_frame_painter.dart:78`,
  `lib/src/frame/overlay_frame_painter.dart:79`).

### 6. Overlay Tests And Eraser Corridor Proof Surfaces

- **Location**: primary
  `test/frame/fixtures/overlay_preview_admission_fixture.dart:43`.
- **Description**: The overlay admission fixture includes
  `CanvasEraserPreview(corridor: const [Offset(6, 6)], thickness: 5)` and
  asserts the resulting primitive kind list contains
  `OverlayPreviewPrimitiveKind.eraser`
  (`test/frame/fixtures/overlay_preview_admission_fixture.dart:17`,
  `test/frame/fixtures/overlay_preview_admission_fixture.dart:43`,
  `test/frame/fixtures/overlay_preview_admission_fixture.dart:55`,
  `test/frame/fixtures/overlay_preview_admission_fixture.dart:61`). The main
  and overlay capture fixture also includes a one-point eraser preview and
  asserts overlay capture retains it
  (`test/frame/fixtures/main_overlay_capture_fixture.dart:183`,
  `test/frame/fixtures/main_overlay_capture_fixture.dart:186`,
  `test/frame/fixtures/main_overlay_capture_fixture.dart:191`).
- **Dependencies**: Public API contract tests construct and read eraser previews
  through public imports (`test/api_contract/public_readable_union_variants_test.dart:21`,
  `test/api_contract/public_readable_union_variants_test.dart:73`,
  `test/api_contract/public_readable_union_variants_test.dart:105`,
  `test/api_contract/public_readable_union_variants_test.dart:106`). The sealed
  union test checks copied and unmodifiable two-point eraser corridors
  (`test/api_contract/preview_state_sealed_union_test.dart:59`,
  `test/api_contract/preview_state_sealed_union_test.dart:99`,
  `test/api_contract/preview_state_sealed_union_test.dart:101`).
- **Data flow**: Painter boundary tests read `overlay_frame_painter.dart` source
  and assert it contains `_paintEraserOverlay`, omits `BlendMode.clear`, and
  omits live input tokens such as `RuntimeRoot`, `DocumentStoreKernel`,
  `CanvasRuntime`, `SurfaceResourceSession`, `CanvasResourceResolver`,
  `readDocument`, and `resolveImage`
  (`test/frame/fixtures/no_live_runtime_read_in_painters_fixture.dart:49`,
  `test/frame/fixtures/no_live_runtime_read_in_painters_fixture.dart:59`,
  `test/frame/fixtures/no_live_runtime_read_in_painters_fixture.dart:60`,
  `test/frame/fixtures/no_live_runtime_read_in_painters_fixture.dart:107`,
  `test/frame/fixtures/no_live_runtime_read_in_painters_fixture.dart:117`).
  Search coverage found no raster, golden, pixel, or recorded-canvas assertion
  specifically for a one-point eraser corridor.

### 7. Overlay Marquee And Stroke Preview Rendering

- **Location**: primary `lib/src/frame/overlay_preview_planner.dart:104`;
  painter at `lib/src/frame/overlay_frame_painter.dart:32` and
  `lib/src/frame/overlay_frame_painter.dart:45`.
- **Description**: `CanvasMarqueePreview` stores only a `Rect`
  (`lib/src/contracts/public/canvas_preview.dart:63`,
  `lib/src/contracts/public/canvas_preview.dart:64`). Captured overlay frame
  inputs include `CanvasSelectionStyle`
  (`lib/src/frame/captured_frame.dart:10`,
  `lib/src/frame/captured_frame.dart:14`,
  `lib/src/frame/captured_frame.dart:24`). `MarqueeOverlayPrimitive` stores
  only the marquee rectangle (`lib/src/frame/overlay_preview_planner.dart:21`,
  `lib/src/frame/overlay_preview_planner.dart:22`,
  `lib/src/frame/overlay_preview_planner.dart:24`), and the planner maps
  `CanvasMarqueePreview` to that rectangle-only primitive
  (`lib/src/frame/overlay_preview_planner.dart:104`,
  `lib/src/frame/overlay_preview_planner.dart:105`). The painter branch draws
  that rectangle with a default stroke `Paint`
  (`lib/src/frame/overlay_frame_painter.dart:32`,
  `lib/src/frame/overlay_frame_painter.dart:33`).
- **Dependencies**: `CanvasSelectionStyle` exposes color, stroke width,
  marquee fill opacity, and halo width
  (`lib/src/contracts/public/canvas_surface_styles.dart:11`,
  `lib/src/contracts/public/canvas_surface_styles.dart:12`,
  `lib/src/contracts/public/canvas_surface_styles.dart:13`,
  `lib/src/contracts/public/canvas_surface_styles.dart:14`,
  `lib/src/contracts/public/canvas_surface_styles.dart:46`,
  `lib/src/contracts/public/canvas_surface_styles.dart:47`,
  `lib/src/contracts/public/canvas_surface_styles.dart:48`,
  `lib/src/contracts/public/canvas_surface_styles.dart:49`). The overlay paint
  sequence states that overlay capture freezes `selectionStyle` and that
  primitive construction uses captured `selectionStyle`
  (`docs/diagrams/seq_overlay_paint.mmd:15`,
  `docs/diagrams/seq_overlay_paint.mmd:21`,
  `docs/diagrams/seq_overlay_paint.mmd:23`,
  `docs/diagrams/seq_overlay_paint.mmd:46`).
- **Data flow**: Pencil and marker previews are mapped to `StrokeOverlayPrimitive`
  values carrying points, color, thickness, and opacity
  (`lib/src/frame/overlay_preview_planner.dart:28`,
  `lib/src/frame/overlay_preview_planner.dart:31`,
  `lib/src/frame/overlay_preview_planner.dart:34`,
  `lib/src/frame/overlay_preview_planner.dart:108`,
  `lib/src/frame/overlay_preview_planner.dart:113`). The passive painter draws
  stroke overlay primitives with `canvas.drawPoints(PointMode.polygon, ...)`
  (`lib/src/frame/overlay_frame_painter.dart:45`,
  `lib/src/frame/overlay_frame_painter.dart:47`). The overlay admission fixture
  admits one-point pencil and marker previews and asserts primitive kinds only
  (`test/frame/fixtures/overlay_preview_admission_fixture.dart:18`,
  `test/frame/fixtures/overlay_preview_admission_fixture.dart:19`,
  `test/frame/fixtures/overlay_preview_admission_fixture.dart:20`,
  `test/frame/fixtures/overlay_preview_admission_fixture.dart:55`,
  `test/frame/fixtures/overlay_preview_admission_fixture.dart:58`).

### 8. Committed Stroke And Degenerate Line Rendering

- **Location**: primary `lib/src/frame/render_family_caches.dart:125`; line
  painter at `lib/src/frame/main_frame_record_painter.dart:189`.
- **Description**: `CanvasStrokeElement` requires non-empty points and positive
  thickness, with no minimum length above one point
  (`lib/src/contracts/public/canvas_element.dart:219`,
  `lib/src/contracts/public/canvas_element.dart:222`,
  `lib/src/contracts/public/canvas_element.dart:235`,
  `lib/src/contracts/public/canvas_element.dart:236`,
  `lib/src/contracts/public/canvas_element.dart:243`,
  `lib/src/contracts/public/canvas_element.dart:250`,
  `lib/src/contracts/public/canvas_element.dart:253`). Geometry policy gives
  one-point strokes a nonzero inflated bounds floor
  (`lib/src/geometry/geometry_policy.dart:357`,
  `lib/src/geometry/geometry_policy.dart:363`,
  `lib/src/geometry/geometry_policy.dart:367`), and the geometry contract names
  one-point stroke as a circular hit (`docs/contracts/geometry.md:118`).
- **Dependencies**: The stroke primitive cache constructs a `Path`, moves to the
  first point, and adds `lineTo` segments for the skipped remaining points
  (`lib/src/frame/render_family_caches.dart:125`,
  `lib/src/frame/render_family_caches.dart:126`,
  `lib/src/frame/render_family_caches.dart:130`,
  `lib/src/frame/render_family_caches.dart:131`,
  `lib/src/frame/render_family_caches.dart:132`). Main record painting later
  consumes the cached stroke path through `drawPath`
  (`lib/src/frame/main_frame_record_painter.dart:156`,
  `lib/src/frame/main_frame_record_painter.dart:163`,
  `lib/src/frame/main_frame_record_painter.dart:173`).
- **Data flow**: `CanvasLineElement` validates start, end, color, and positive
  thickness without a start/end inequality branch
  (`lib/src/contracts/public/canvas_element.dart:268`,
  `lib/src/contracts/public/canvas_element.dart:269`,
  `lib/src/contracts/public/canvas_element.dart:270`,
  `lib/src/contracts/public/canvas_element.dart:287`,
  `lib/src/contracts/public/canvas_element.dart:289`). Geometry policy inflates
  same-point line bounds with a minimum half-thickness
  (`lib/src/geometry/geometry_policy.dart:339`,
  `lib/src/geometry/geometry_policy.dart:349`,
  `lib/src/geometry/geometry_policy.dart:354`). Main record painting draws line
  records through `canvas.drawLine(record.start, record.end, paint)`
  (`lib/src/frame/main_frame_record_painter.dart:183`,
  `lib/src/frame/main_frame_record_painter.dart:188`,
  `lib/src/frame/main_frame_record_painter.dart:189`).

### 9. Resource Session And P9 Test Inventory Source-Of-Truth Drift

- **Location**: primary `docs/architecture/01_runtime_ownership.md:200`;
  sequence at `docs/diagrams/seq_main_paint.mmd:100`; registry at
  `docs/_registry/sections.yaml:619`.
- **Description**: The runtime ownership composition-root tree lists
  `SurfaceResourceSession (owned by active CanvasSurface)` under `RuntimeRoot`
  (`docs/architecture/01_runtime_ownership.md:185`,
  `docs/architecture/01_runtime_ownership.md:188`,
  `docs/architecture/01_runtime_ownership.md:200`). The resource contract states
  that `RuntimeRoot` holds the nullable active `ResourceSessionInvalidationSink`
  and that each active future `CanvasSurface` owns one `SurfaceResourceSession`
  instance (`docs/contracts/resources.md:63`,
  `docs/contracts/resources.md:65`). The P7 design records the same split:
  live resolver state stays in `SurfaceResourceSession`, while `RuntimeRoot`
  stores a nullable active sink
  (`docs/history/designs/2026-05-28-p7-resource-session-resolver-lifecycle.md:155`,
  `docs/history/designs/2026-05-28-p7-resource-session-resolver-lifecycle.md:158`).
- **Dependencies**: The main paint sequence enters an explicit resource-session
  image-binding branch without naming `beginFrameResourcePass()`
  (`docs/diagrams/seq_main_paint.mmd:100`,
  `docs/diagrams/seq_main_paint.mmd:101`,
  `docs/diagrams/seq_main_paint.mmd:102`). The implemented binding service calls
  `session.beginFrameResourcePass()` before collecting descriptors and resolving
  per-record image ids (`lib/src/frame/paint_asset_binding_service.dart:23`,
  `lib/src/frame/paint_asset_binding_service.dart:28`,
  `lib/src/frame/paint_asset_binding_service.dart:34`). The session resets
  resolver call count, budget follow-up state, and current-frame null result
  suppression in that method
  (`lib/src/resources/surface_resource_session.dart:35`,
  `lib/src/resources/surface_resource_session.dart:36`,
  `lib/src/resources/surface_resource_session.dart:37`,
  `lib/src/resources/surface_resource_session.dart:38`). The P7 design also
  names the same frame-pass boundary
  (`docs/history/designs/2026-05-28-p7-resource-session-resolver-lifecycle.md:162`).
- **Data flow**: Registry-backed section 15 lists nine tests under its `tests`
  key (`docs/_registry/sections.yaml:619`,
  `docs/_registry/sections.yaml:621`,
  `docs/_registry/sections.yaml:627`). The P9 implementation note lists
  additional P9 proof tests, including frame donor mapping, paint asset binding,
  repaint bus output, static background planning, and cache proof tests
  (`docs/implementation/p9_frame_rendering_and_caches.md:162`,
  `docs/implementation/p9_frame_rendering_and_caches.md:163`,
  `docs/implementation/p9_frame_rendering_and_caches.md:165`,
  `docs/implementation/p9_frame_rendering_and_caches.md:166`,
  `docs/implementation/p9_frame_rendering_and_caches.md:167`,
  `docs/implementation/p9_frame_rendering_and_caches.md:178`,
  `docs/implementation/p9_frame_rendering_and_caches.md:179`). The P9 step
  contract names further focused tests for render primitive cache snapshots,
  all-or-nothing writes, primitive opacity policy, surface camera output,
  selected order, selection decoration, static background, and overlay preview
  admission (`plan/step_43_p9_frame_rendering_and_caches.md:105`,
  `plan/step_43_p9_frame_rendering_and_caches.md:127`,
  `plan/step_43_p9_frame_rendering_and_caches.md:149`). The generated test-area
  index maps only the subset present in registry sections
  (`docs/indexes/by_test_area.md:170`,
  `docs/indexes/by_test_area.md:178`,
  `docs/indexes/by_test_area.md:182`,
  `docs/indexes/by_test_area.md:198`).

### 10. Frame/Cache Guardrail Registration And Execution

- **Location**: primary `tool/guardrails/src/guardrail_registry.dart:196`.
- **Description**: Frame guardrails are registered in the blocking and frame
  suites, and cache guardrails are registered in the blocking and cache suites
  (`tool/guardrails/src/guardrail_registry.dart:196`,
  `tool/guardrails/src/guardrail_registry.dart:200`,
  `tool/guardrails/src/guardrail_registry.dart:204`,
  `tool/guardrails/src/guardrail_registry.dart:208`,
  `tool/guardrails/src/guardrail_registry.dart:212`,
  `tool/guardrails/src/guardrail_registry.dart:216`).
- **Dependencies**: Guardrail inventory and suite membership derive from
  `_blockingEntries` (`tool/guardrails/src/guardrail_registry.dart:13`,
  `tool/guardrails/src/guardrail_registry.dart:17`,
  `tool/guardrails/src/guardrail_registry.dart:21`,
  `tool/guardrails/src/guardrail_registry.dart:35`). The executor maps frame
  and cache guardrail ids to proof paths and structural checks
  (`tool/guardrails/src/guardrail_executor.dart:268`,
  `tool/guardrails/src/guardrail_executor.dart:271`,
  `tool/guardrails/src/guardrail_executor.dart:274`,
  `tool/guardrails/src/guardrail_executor.dart:277`,
  `tool/guardrails/src/guardrail_executor.dart:280`,
  `tool/guardrails/src/guardrail_executor.dart:284`,
  `tool/guardrails/src/guardrail_executor.dart:322`,
  `tool/guardrails/src/guardrail_executor.dart:328`).
- **Data flow**: `_productionFrameSources` reads every Dart file under
  `lib/src/frame` and each public P9 check delegates to a source-map function
  (`tool/guardrails/src/frame_cache_guardrail_checks.dart:19`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:24`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:28`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:205`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:207`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:208`).

### 11. Guardrail Cached Paint Surface Recognition

- **Location**: primary `tool/guardrails/src/frame_cache_guardrail_checks.dart:214`.
- **Description**: Preview and selection exclusion checks use
  `_checkCachedPaintSurfacesExclude`, which iterates `_cachedPaintSurfaces`,
  extracts class bodies, and checks token presence
  (`tool/guardrails/src/frame_cache_guardrail_checks.dart:214`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:221`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:222`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:223`). The scanned
  cached paint surfaces are `PaintPlanKey`, `OrdinaryPaintRecordKey`,
  `PaintPlan`, and `RenderElementRecord`
  (`tool/guardrails/src/frame_cache_guardrail_checks.dart:232`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:233`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:236`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:238`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:241`).
- **Dependencies**: Production `OrdinaryPaintRecordCacheEntry` is declared in
  `paint_plan.dart` and stores a bounded map of `OrdinaryPaintRecordKey` to
  `RenderElementRecord` (`lib/src/frame/paint_plan.dart:102`,
  `lib/src/frame/paint_plan.dart:104`, `lib/src/frame/paint_plan.dart:107`,
  `lib/src/frame/paint_plan.dart:109`,
  `lib/src/frame/paint_plan.dart:110`). It is not listed in
  `_cachedPaintSurfaces` (`tool/guardrails/src/frame_cache_guardrail_checks.dart:232`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:243`).
- **Data flow**: Preview exclusion scans for `preview` and `selectedMove`
  (`tool/guardrails/src/frame_cache_guardrail_checks.dart:62`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:68`). Selection
  exclusion scans for `selection`, `selectedElementIds`, and `selectionRevision`
  (`tool/guardrails/src/frame_cache_guardrail_checks.dart:73`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:79`). The docs state
  ordinary cached records must exclude selected ids, selection flags,
  `selectionRevision`, selected-move supplement records, `selectedMoveDelta`, and
  `previewDelta` (`docs/contracts/cache_policy.md:72`,
  `docs/contracts/cache_policy.md:74`,
  `docs/contracts/cache_policy.md:75`,
  `docs/verification/guardrails.md:213`,
  `docs/verification/guardrails.md:214`).

### 12. Guardrail No-Global-Scene-Sort Recognition

- **Location**: primary `tool/guardrails/src/frame_cache_guardrail_checks.dart:305`.
- **Description**: The no-global-scene-sort scanner removes full-line `//`
  comments, finds `.sort(` occurrences, and reports a violation only when the
  following statement or 240-character fallback expression contains `orderToken`
  (`tool/guardrails/src/frame_cache_guardrail_checks.dart:305`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:306`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:307`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:321`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:323`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:329`).
- **Dependencies**: The scanner only considers paths under `lib/src/frame/`
  (`tool/guardrails/src/frame_cache_guardrail_checks.dart:52`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:212`). The guardrail
  route describes this as the frame selected supplement global sort check
  (`tool/guardrails/src/guardrail_executor.dart:360`,
  `tool/guardrails/src/guardrail_executor.dart:361`).
- **Data flow**: The structural guardrail test rejects inline comparator sorts
  that mention `orderToken` and allows a local string sort without `orderToken`
  (`test/guardrails/frame_no_global_scene_sort_guardrail_test.dart:21`,
  `test/guardrails/frame_no_global_scene_sort_guardrail_test.dart:24`,
  `test/guardrails/frame_no_global_scene_sort_guardrail_test.dart:32`,
  `test/guardrails/frame_no_global_scene_sort_guardrail_test.dart:35`,
  `test/guardrails/frame_no_global_scene_sort_guardrail_test.dart:41`,
  `test/guardrails/frame_no_global_scene_sort_guardrail_test.dart:44`).
  Production selected supplement merging uses `_mergeByOrderToken` and does not
  call `sort` in that merge function
  (`lib/src/frame/selected_move_supplement_planner.dart:209`,
  `lib/src/frame/selected_move_supplement_planner.dart:214`,
  `lib/src/frame/selected_move_supplement_planner.dart:217`).

### 13. Source-Of-Truth Layout And Naming

- **Location**: primary `docs/architecture/02_package_boundaries.md:112`.
- **Description**: The package boundary layout lists frame target files including
  `captured_main_frame.dart`, `captured_overlay_frame.dart`, and
  `repaint_bus.dart` (`docs/architecture/02_package_boundaries.md:112`,
  `docs/architecture/02_package_boundaries.md:115`,
  `docs/architecture/02_package_boundaries.md:116`,
  `docs/architecture/02_package_boundaries.md:125`). The same document states
  those target frame collaborator files are frame-private implementation layout
  names and omitted from the public package barrel
  (`docs/architecture/02_package_boundaries.md:188`,
  `docs/architecture/02_package_boundaries.md:189`,
  `docs/architecture/02_package_boundaries.md:190`,
  `docs/architecture/02_package_boundaries.md:191`).
- **Dependencies**: Current implementation defines both `CapturedMainFrame` and
  `CapturedOverlayFrame` in `captured_frame.dart`
  (`lib/src/frame/captured_frame.dart:77`,
  `lib/src/frame/captured_frame.dart:87`) and defines repaint output in
  `frame_repaint_signal.dart` (`lib/src/frame/frame_repaint_signal.dart:1`).
  `FrameEngine` imports those actual files
  (`lib/src/frame/frame_engine.dart:10`,
  `lib/src/frame/frame_engine.dart:13`).
- **Data flow**: The P9 design listed expected future files with the older names
  (`docs/history/designs/2026-05-29-p9-frame-rendering-and-caches.md:265`,
  `docs/history/designs/2026-05-29-p9-frame-rendering-and-caches.md:269`,
  `docs/history/designs/2026-05-29-p9-frame-rendering-and-caches.md:270`,
  `docs/history/designs/2026-05-29-p9-frame-rendering-and-caches.md:279`). The current graph
  maps the durable `frame.renderer` node to `FrameEngine` and implemented
  collaborators, not to the older `FrameRenderer` declaration
  (`docs/architecture/architecture_graph.yaml:398`,
  `docs/architecture/architecture_graph.yaml:410`,
  `docs/architecture/architecture_graph.yaml:413`). Generated graph views render
  the node id as `frame_renderer` (`docs/diagrams/generated/current_phase.mmd:14`,
  `docs/diagrams/generated/full_architecture.mmd:18`).

## Code References

- `lib/src/frame/frame_engine.dart:33` - `FrameEngine` facade declaration.
- `lib/src/frame/frame_engine.dart:97` - main frame capture begins inside
  `_buildMainFrame`.
- `lib/src/frame/frame_engine.dart:99` - selected supplement planner receives
  the ordinary plan.
- `lib/src/frame/selected_move_supplement_planner.dart:65` - movable selected
  records are filtered from ordinary records.
- `lib/src/frame/selected_move_supplement_planner.dart:138` - shifted spatial
  paint query is called.
- `lib/src/frame/selected_move_supplement_planner.dart:139` - shifted result
  candidates are iterated.
- `lib/src/geometry/spatial_query_result.dart:7` - base spatial result exposes
  an empty candidates list.
- `lib/src/frame/ordinary_paint_planner.dart:83` - ordinary planner rejects
  non-candidate captured spatial results.
- `test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart:73`
  - selected supplement fixture returns `SpatialCandidatesResult`.
- `test/frame/fixtures/paint_plan_write_all_or_nothing_fixture.dart:69` -
  ordinary all-or-nothing fixture injects `SpatialBudgetExceededResult`.
- `lib/src/frame/overlay_preview_planner.dart:128` - eraser preview is admitted
  into an eraser overlay primitive.
- `lib/src/frame/overlay_preview_planner.dart:104` - marquee preview is admitted
  into a rectangle-only marquee overlay primitive.
- `lib/src/frame/overlay_frame_painter.dart:32` - marquee primitive is painted
  with a default stroke paint.
- `lib/src/frame/overlay_frame_painter.dart:47` - pencil and marker stroke
  overlay primitives are painted with `PointMode.polygon`.
- `lib/src/frame/overlay_frame_painter.dart:77` - eraser primitive is painted
  with `drawPoints`.
- `lib/src/frame/overlay_frame_painter.dart:78` - eraser paint uses
  `PointMode.polygon`.
- `test/frame/fixtures/overlay_preview_admission_fixture.dart:43` - one-point
  eraser preview appears in overlay admission proof.
- `lib/src/frame/render_family_caches.dart:130` - committed stroke path begins
  with `moveTo`.
- `lib/src/frame/render_family_caches.dart:131` - committed stroke path adds
  `lineTo` segments only for remaining points.
- `lib/src/frame/main_frame_record_painter.dart:173` - committed stroke records
  are painted through `drawPath`.
- `lib/src/frame/main_frame_record_painter.dart:189` - committed line records
  are painted through `drawLine`.
- `tool/guardrails/src/frame_cache_guardrail_checks.dart:79` - selection
  exclusion token set.
- `tool/guardrails/src/frame_cache_guardrail_checks.dart:232` - cached paint
  scanner surface list begins.
- `tool/guardrails/src/frame_cache_guardrail_checks.dart:305` - no-global-sort
  scanner begins.
- `lib/src/frame/paint_plan.dart:102` - `OrdinaryPaintRecordCacheEntry`
  declaration.
- `docs/architecture/02_package_boundaries.md:115` - package layout lists
  `captured_main_frame.dart`.
- `docs/architecture/02_package_boundaries.md:125` - package layout lists
  `repaint_bus.dart`.
- `docs/architecture/01_runtime_ownership.md:200` - composition root lists
  `SurfaceResourceSession` under `RuntimeRoot`.
- `docs/diagrams/seq_main_paint.mmd:100` - explicit resource-session branch
  begins without a named frame-pass reset.
- `docs/_registry/sections.yaml:619` - section 15 test inventory begins.
- `lib/src/frame/captured_frame.dart:77` - actual `CapturedMainFrame`
  declaration.
- `lib/src/frame/frame_repaint_signal.dart:1` - actual repaint signal file.
- `docs/architecture/architecture_graph.yaml:413` - graph actual declaration
  includes `FrameEngine`.

## Search Coverage

- **Inspected**: Directly named files were read completely:
  `plan/step_43_p9_frame_rendering_and_caches.md`,
  `docs/history/designs/2026-05-29-p9-frame-rendering-and-caches.md`,
  `docs/implementation/p9_frame_rendering_and_caches.md`,
  `lib/src/frame/selected_move_supplement_planner.dart`,
  `lib/src/frame/overlay_frame_painter.dart`,
  `tool/guardrails/src/frame_cache_guardrail_checks.dart`, and
  `docs/architecture/02_package_boundaries.md`.
- **Inspected**: Related production files:
  `lib/src/frame/frame_engine.dart`,
  `lib/src/frame/frame_capture_service.dart`,
  `lib/src/frame/captured_frame.dart`,
  `lib/src/frame/frame_paint_output.dart`,
  `lib/src/frame/frame_repaint_signal.dart`,
  `lib/src/frame/ordinary_paint_planner.dart`,
  `lib/src/frame/paint_plan.dart`,
  `lib/src/frame/render_element_record.dart`,
  `lib/src/frame/render_family_caches.dart`,
  `lib/src/frame/main_frame_record_painter.dart`,
  `lib/src/frame/overlay_preview_planner.dart`,
  `lib/src/contracts/public/canvas_element.dart`,
  `lib/src/contracts/public/canvas_preview.dart`,
  `lib/src/contracts/public/canvas_surface_styles.dart`, and
  `lib/src/geometry/spatial_query_result.dart`.
- **Inspected**: Related tests and fixtures:
  `test/frame/fixtures/selected_supplement_staging_no_global_sort_fixture.dart`,
  `test/frame/fixtures/paint_plan_write_all_or_nothing_fixture.dart`,
  `test/frame/fixtures/overlay_preview_admission_fixture.dart`,
  `test/frame/fixtures/main_overlay_capture_fixture.dart`,
  `test/frame/fixtures/no_live_runtime_read_in_painters_fixture.dart`,
  `test/frame/fixtures/ordinary_paint_primitive_policy_fixture.dart`,
  `test/frame/fixtures/render_primitive_cache_snapshot_fixture.dart`,
  `test/flutter_bridge/fixtures/surface_camera_frame_output_fixture.dart`,
  `test/flutter_bridge/fixtures/widget_paint_fixture.dart`,
  `test/guardrails/frame_paint_plan_excludes_selection_state_guardrail_test.dart`,
  `test/guardrails/frame_paint_plan_excludes_preview_delta_guardrail_test.dart`,
  and `test/guardrails/frame_no_global_scene_sort_guardrail_test.dart`.
- **Inspected**: Related source-of-truth documents and diagrams:
  `docs/contracts/frame_rendering.md`, `docs/contracts/cache_policy.md`,
  `docs/contracts/spatial_kernel.md`, `docs/contracts/geometry.md`,
  `docs/contracts/resources.md`,
  `docs/verification/guardrails.md`,
  `docs/verification/tests.md`,
  `docs/_registry/sections.yaml`,
  `docs/architecture/01_runtime_ownership.md`,
  `docs/architecture/architecture_graph.yaml`,
  `docs/diagrams/dfd_overlay_frame.mmd`,
  `docs/diagrams/seq_main_paint.mmd`,
  `docs/diagrams/seq_overlay_paint.mmd`,
  `docs/diagrams/generated/current_phase.mmd`, and
  `docs/diagrams/generated/full_architecture.mmd`.
- **Searched**:
  `rg --files lib/src/frame test/frame test/guardrails tool/guardrails docs/diagrams docs/architecture docs/contracts docs/implementation`.
- **Searched**:
  `rg -n "SpatialBudgetExceededResult|SpatialInvalidIndexResult|SpatialQueryResult|SpatialCandidatesResult|candidates" lib/src/geometry lib/src/frame test/frame docs/contracts`.
- **Searched**:
  `rg -n "OrdinaryPaintRecordCacheEntry|previewRevision|selectedElementIds|isSelected|selected|selectionRevision|PaintPlanKey|OrdinaryPaintRecordKey|RenderElementRecord" lib/src/frame tool/guardrails test/guardrails docs/contracts docs/implementation plan`.
- **Searched**:
  `rg -n "captured_frame|captured_main_frame|captured_overlay_frame|frame_repaint_signal|repaint_bus|FrameRepaint" lib/src/frame docs plan .design test tool`.
- **Searched**:
  `rg -n "drawPoints|PointMode|EraserOverlayPrimitive|CanvasEraserPreview|corridor|overlay_frame_painter|OverlayFramePainter" lib/src/frame test/frame test/flutter_bridge docs/contracts docs/implementation plan`.
- **Searched**:
  `rg -n "marquee|CanvasMarqueePreview|selectionStyle|marqueeFillOpacity|pencil|marker|single-point|PointMode" docs/contracts docs/diagrams docs/implementation plan test/frame lib/src/frame`.
- **Searched**:
  `rg -n "CanvasStrokeElement|one-point stroke|stroke points|CanvasLineElement|drawLine|start == end" lib/src docs test`.
- **Searched**:
  `rg -n "selected_order_cache|selection_decoration_plan|overlay_preview_admission|paint_plan_write_all_or_nothing|render_primitive_cache_snapshot|ordinary_paint_primitive_policy|surface_camera_frame_output|test.frame" docs/_registry/sections.yaml docs/verification/tests.md docs/indexes docs/implementation/p9_frame_rendering_and_caches.md plan/step_43_p9_frame_rendering_and_caches.md`.
- **Searched**:
  `rg -n "FrameEngine|FrameRenderer|captured_main_frame|captured_frame|frame_repaint_signal|repaint_bus|SelectedMoveSupplementPlanner|OverlayFramePainter|OrdinaryPaintRecordCacheEntry|ordinary cache|selection flags|global sort|PointMode|CanvasEraserPreview" docs/architecture docs/diagrams docs/contracts docs/implementation .design plan lib/src/frame test/frame test/guardrails tool/guardrails`.
- **Not found**: `lib/src/frame/captured_main_frame.dart`,
  `lib/src/frame/captured_overlay_frame.dart`, and `lib/src/frame/repaint_bus.dart`
  in the current `lib/src/frame` file list.
- **Not found**: a selected-supplement fixture under `test/frame/fixtures` or
  production `lib/src/frame` that injects `SpatialBudgetExceededResult`,
  `SpatialInvalidIndexResult`, or `SpatialStaleCandidateResult` into the shifted
  supplement query.
- **Not found**: a raster/golden/pixel/recorded-canvas assertion specifically
  proving visual output for a one-point `CanvasEraserPreview` corridor.
- **Not found**: a raster/golden/pixel/recorded-canvas assertion specifically
  proving visual output for one-point pencil/marker overlay previews, one-point
  committed strokes, or same-point committed lines.
- **Not inspected**: External Flutter engine rendering behavior for
  `Canvas.drawPoints(PointMode.polygon, [singlePoint], paint)`, `Canvas.drawPath`
  with a path containing only `moveTo`, or `Canvas.drawLine` with equal
  endpoints; this research describes repository code and tests only.

## Observed Architecture Facts

- Pattern observed: P9 uses a frame-private facade with focused collaborators.
  Evidence: `FrameEngine` declaration and fields at
  `lib/src/frame/frame_engine.dart:33`, `lib/src/frame/frame_engine.dart:39`,
  `lib/src/frame/frame_engine.dart:51`; graph evidence at
  `docs/architecture/architecture_graph.yaml:410`.
- Pattern observed: main selected-move preview is admitted to main frame capture
  and excluded from overlay capture. Evidence:
  `lib/src/frame/frame_capture_service.dart:32`,
  `lib/src/frame/frame_capture_service.dart:33`,
  `lib/src/frame/frame_capture_service.dart:44`,
  `lib/src/frame/frame_capture_service.dart:45`.
- Pattern observed: overlay previews are immutable primitive inputs before
  painter consumption. Evidence: `OverlayPreviewPlan` stores unmodifiable
  primitives at `lib/src/frame/overlay_preview_planner.dart:82`,
  `lib/src/frame/overlay_preview_planner.dart:84`; `OverlayFramePainter` consumes
  `OverlayFramePaintOutput` at `lib/src/frame/overlay_frame_painter.dart:8`,
  `lib/src/frame/overlay_frame_painter.dart:11`.
- Pattern observed: public preview and element constructors admit degenerate
  drawable inputs before painter consumption. Evidence: one-point pencil,
  marker, and eraser previews in
  `test/frame/fixtures/overlay_preview_admission_fixture.dart:18`,
  `test/frame/fixtures/overlay_preview_admission_fixture.dart:19`,
  `test/frame/fixtures/overlay_preview_admission_fixture.dart:20`;
  stroke element point validation at
  `lib/src/contracts/public/canvas_element.dart:235`; same-point line geometry
  handling at `lib/src/geometry/geometry_policy.dart:349`.
- Pattern observed: overlay marquee capture freezes selection style, while the
  current marquee primitive carries only a rectangle. Evidence:
  `lib/src/frame/captured_frame.dart:14`,
  `lib/src/frame/overlay_preview_planner.dart:21`,
  `lib/src/frame/overlay_preview_planner.dart:104`,
  `lib/src/frame/overlay_frame_painter.dart:32`.
- Pattern observed: ordinary planning has explicit non-candidate spatial
  rejection; selected supplement shifted query uses the base candidates getter.
  Evidence: `lib/src/frame/ordinary_paint_planner.dart:83`,
  `lib/src/frame/ordinary_paint_planner.dart:86`,
  `lib/src/frame/selected_move_supplement_planner.dart:138`,
  `lib/src/frame/selected_move_supplement_planner.dart:139`,
  `lib/src/geometry/spatial_query_result.dart:7`.
- Pattern observed: guardrails combine proof-test routes and structural checks.
  Evidence: proof paths at `tool/guardrails/src/guardrail_executor.dart:268`,
  structural checks at `tool/guardrails/src/guardrail_executor.dart:322`, and
  frame source loading at
  `tool/guardrails/src/frame_cache_guardrail_checks.dart:205`.
- Pattern observed: implemented asset binding resets session frame-pass state,
  while the main paint sequence enters the explicit image-binding loop without
  naming that reset. Evidence:
  `lib/src/frame/paint_asset_binding_service.dart:28`,
  `lib/src/resources/surface_resource_session.dart:35`,
  `docs/diagrams/seq_main_paint.mmd:100`.
- Pattern observed: current graph and semantic diagrams name `FrameEngine`, while
  one package boundary layout and the historical P9 design still list older file
  names. Evidence: `docs/architecture/architecture_graph.yaml:413`,
  `docs/diagrams/c4_component_runtime.mmd:16`,
  `docs/architecture/02_package_boundaries.md:115`,
  `docs/history/designs/2026-05-29-p9-frame-rendering-and-caches.md:269`.

## Open Questions

- Whether the current package-boundary file-name list is intended to be a current
  exact implementation map or a historical target sketch is not stated near the
  mismatching file names (`docs/architecture/02_package_boundaries.md:112`,
  `docs/architecture/02_package_boundaries.md:188`).
- The repository docs name selection flags as forbidden ordinary cache payloads
  (`docs/contracts/cache_policy.md:74`,
  `docs/verification/guardrails.md:214`), while the current selection exclusion
  scanner uses `selection`, `selectedElementIds`, and `selectionRevision` tokens
  (`tool/guardrails/src/frame_cache_guardrail_checks.dart:79`).
- The repository tests include one-point eraser preview admission/capture
  assertions (`test/frame/fixtures/overlay_preview_admission_fixture.dart:43`,
  `test/frame/fixtures/main_overlay_capture_fixture.dart:183`), but no inspected
  test records the actual painter operation or pixels for that one-point corridor.
- The repository tests include one-point pencil and marker overlay preview
  admission assertions
  (`test/frame/fixtures/overlay_preview_admission_fixture.dart:18`,
  `test/frame/fixtures/overlay_preview_admission_fixture.dart:19`), but no
  inspected painter or pixel assertion records their single-point output.
- Registry-backed section 15 contains a selected P9 test subset
  (`docs/_registry/sections.yaml:619`,
  `docs/_registry/sections.yaml:627`), while P9 implementation and step evidence
  name additional P9 proof files
  (`docs/implementation/p9_frame_rendering_and_caches.md:162`,
  `plan/step_43_p9_frame_rendering_and_caches.md:105`,
  `plan/step_43_p9_frame_rendering_and_caches.md:127`).
