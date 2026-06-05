---
date: 2026-06-06
researcher: Codex
commit: 78ffc658
branch: new-architecture
research_question: "Analyze build/bench/current/pixel6_release.json and identify performance-relevant bottlenecks that affect cutting the numbers in half."
---

# Research: Pixel 6 Release Benchmark Hotspots

## Summary

The current Pixel 6 release benchmark report contains 74 case/scale rows for the
`release` profile (`build/bench/current/pixel6_release.json:6`,
`build/bench/current/pixel6_release.json:34`). The slowest rows are concentrated
in 50k/100k scale cases, with `edit.add_element/100k` at `avg_us: 1406329`,
`frame.paint_candidates/100k` at `avg_us: 1382744`,
`edit.update_transform/100k` at `avg_us: 1257124`,
`edit.update_visual/100k` at `avg_us: 1235702`,
`load_document.success/100k` at `avg_us: 1219081`, and
`projection.read_document/100k` at `avg_us: 1184379`
(`build/bench/current/pixel6_release.json:106`,
`build/bench/current/pixel6_release.json:122`,
`build/bench/current/pixel6_release.json:1473`,
`build/bench/current/pixel6_release.json:1493`,
`build/bench/current/pixel6_release.json:297`,
`build/bench/current/pixel6_release.json:314`,
`build/bench/current/pixel6_release.json:201`,
`build/bench/current/pixel6_release.json:218`,
`build/bench/current/pixel6_release.json:1856`,
`build/bench/current/pixel6_release.json:1874`,
`build/bench/current/pixel6_release.json:1723`,
`build/bench/current/pixel6_release.json:1740`).

The benchmark sample timer wraps each complete `_runOperation`, so reported
`avg_us`, `p95_us`, and `max_us` include each case's runtime/document setup and
dispose work, not only the inner metric-specific operation
(`test/benchmarks/benchmark_probe_flutter.dart:131`,
`test/benchmarks/benchmark_probe_flutter.dart:133`,
`test/benchmarks/benchmark_probe_flutter.dart:134`,
`test/benchmarks/benchmark_probe_flutter.dart:135`). This matters for
interpretation: `projection.read_document/100k` reports `first_read_us: 94542`
and `cache_hit_us: 1`, while the same case reports `avg_us: 1184379`
(`build/bench/current/pixel6_release.json:1736`,
`build/bench/current/pixel6_release.json:1737`,
`build/bench/current/pixel6_release.json:1740`).

The repeated performance-relevant facts are: benchmark setup creates full
synthetic documents by scale; `RuntimeRoot` construction builds committed store
state and immediately rebuilds spatial indexes; edit cases materialize and copy
a full document into `DraftDocument` even for one-element changes; load success
validates all input rows and rebuilds committed/spatial state; spatial/frame
queries hit the 4096 candidate budget at larger scales; and resource/diagnostic
cases are bounded and low-cost in the current report.

## Detailed Findings

### 1. Benchmark Harness And Timing Scope

- **Location**: primary `test/benchmarks/benchmark_probe_flutter.dart:131`.
- **Description**: `_measureOperation` records RSS before running an operation,
  starts a stopwatch, awaits `_runOperation(caseId, scaleId)`, stops the
  stopwatch, computes non-negative RSS delta, fills missing `allocation_bytes`
  and `rss_delta_bytes`, and returns elapsed microseconds
  (`test/benchmarks/benchmark_probe_flutter.dart:131`,
  `test/benchmarks/benchmark_probe_flutter.dart:132`,
  `test/benchmarks/benchmark_probe_flutter.dart:133`,
  `test/benchmarks/benchmark_probe_flutter.dart:134`,
  `test/benchmarks/benchmark_probe_flutter.dart:135`,
  `test/benchmarks/benchmark_probe_flutter.dart:136`,
  `test/benchmarks/benchmark_probe_flutter.dart:137`,
  `test/benchmarks/benchmark_probe_flutter.dart:138`,
  `test/benchmarks/benchmark_probe_flutter.dart:139`).
- **Dependencies**: The CLI adapter invokes `dart run
  test/benchmarks/benchmark_probe.dart` and forwards `--case`, `--scale`,
  `--profile`, warmup/repetition/minimum/timing options, plus `--device` when
  present (`tool/bench/src/benchmark_case_adapters.dart:39`,
  `tool/bench/src/benchmark_case_adapters.dart:43`,
  `tool/bench/src/benchmark_case_adapters.dart:44`,
  `tool/bench/src/benchmark_case_adapters.dart:45`,
  `tool/bench/src/benchmark_case_adapters.dart:46`,
  `tool/bench/src/benchmark_case_adapters.dart:47`,
  `tool/bench/src/benchmark_case_adapters.dart:48`,
  `tool/bench/src/benchmark_case_adapters.dart:49`,
  `tool/bench/src/benchmark_case_adapters.dart:50`).
- **Data flow**: Manifest case/scale -> adapter process -> Flutter probe ->
  `_runOperation` -> sample elapsed time/RSS -> report metrics. The report loop
  runs warmups before measured samples, records each measured sample, then adds
  timing metrics (`test/benchmarks/benchmark_probe_flutter.dart:64`,
  `test/benchmarks/benchmark_probe_flutter.dart:65`,
  `test/benchmarks/benchmark_probe_flutter.dart:66`,
  `test/benchmarks/benchmark_probe_flutter.dart:69`,
  `test/benchmarks/benchmark_probe_flutter.dart:73`,
  `test/benchmarks/benchmark_probe_flutter.dart:74`,
  `test/benchmarks/benchmark_probe_flutter.dart:82`).
- **Observed consequence**: Case-specific inner metrics can be much smaller than
  sample timing when setup dominates. `projection.read_document/100k` records
  `first_read_us: 94542`, `cache_hit_us: 1`, and `avg_us: 1184379`
  (`build/bench/current/pixel6_release.json:1736`,
  `build/bench/current/pixel6_release.json:1737`,
  `build/bench/current/pixel6_release.json:1740`).

### 2. Shared Synthetic Document And Runtime Setup

- **Location**: primary `test/benchmarks/benchmark_probe_flutter.dart:761`.
- **Description**: `_document(scaleId)` computes `elementCount`, creates up to
  32 image resources, and creates one layer containing `elementCount` rect
  elements (`test/benchmarks/benchmark_probe_flutter.dart:761`,
  `test/benchmarks/benchmark_probe_flutter.dart:762`,
  `test/benchmarks/benchmark_probe_flutter.dart:763`,
  `test/benchmarks/benchmark_probe_flutter.dart:764`,
  `test/benchmarks/benchmark_probe_flutter.dart:765`,
  `test/benchmarks/benchmark_probe_flutter.dart:766`,
  `test/benchmarks/benchmark_probe_flutter.dart:773`,
  `test/benchmarks/benchmark_probe_flutter.dart:774`,
  `test/benchmarks/benchmark_probe_flutter.dart:776`,
  `test/benchmarks/benchmark_probe_flutter.dart:777`).
- **Dependencies**: `_scaleElementCount` maps `100k` to 100000, `50k`/
  `dense_50k`/`invalid_50k` to 50000, `10k`/`invalid_10k` to 10000, and `1k`/
  resource scales to 1000 (`test/benchmarks/benchmark_probe_flutter.dart:924`,
  `test/benchmarks/benchmark_probe_flutter.dart:925`,
  `test/benchmarks/benchmark_probe_flutter.dart:926`,
  `test/benchmarks/benchmark_probe_flutter.dart:927`,
  `test/benchmarks/benchmark_probe_flutter.dart:928`,
  `test/benchmarks/benchmark_probe_flutter.dart:929`,
  `test/benchmarks/benchmark_probe_flutter.dart:930`,
  `test/benchmarks/benchmark_probe_flutter.dart:931`,
  `test/benchmarks/benchmark_probe_flutter.dart:932`).
- **Data flow**: `_runtime(scaleId)` constructs `RuntimeRoot` with the synthetic
  document (`test/benchmarks/benchmark_probe_flutter.dart:784`,
  `test/benchmarks/benchmark_probe_flutter.dart:788`). `RuntimeRoot` constructs
  `DocumentStoreKernel`, `LoadDocumentPipeline`, `SelectionKernel`,
  `SpatialKernel`, and attaches the interaction read port before rebuilding
  spatial indexes (`lib/src/runtime/runtime_root.dart:92`,
  `lib/src/runtime/runtime_root.dart:97`,
  `lib/src/runtime/runtime_root.dart:139`,
  `lib/src/runtime/runtime_root.dart:144`,
  `lib/src/runtime/runtime_root.dart:148`,
  `lib/src/runtime/runtime_root.dart:158`,
  `lib/src/runtime/runtime_root.dart:159`).
- **Observed consequence**: Every benchmark case using `_runtime(scaleId)`
  includes synthetic document construction, committed-store construction, and
  initial spatial rebuild inside the measured sample. Store construction creates
  `CommittedDocument`, which builds `ResourceTable` and `ElementRegistry`
  (`lib/src/store/document_store_kernel.dart:26`,
  `lib/src/store/document_store_kernel.dart:27`,
  `lib/src/store/committed_document.dart:20`,
  `lib/src/store/committed_document.dart:29`). Initial spatial rebuild iterates
  frame handles and replaces index state (`lib/src/geometry/spatial_kernel.dart:37`,
  `lib/src/geometry/spatial_kernel.dart:40`,
  `lib/src/geometry/spatial_entry_loader.dart:13`,
  `lib/src/geometry/spatial_kernel.dart:49`).

### 3. Edit Cases: Full Projection And Draft Copy Before Local Changes

- **Location**: primary `lib/src/edit/edit_kernel.dart:43`.
- **Description**: `EditKernel.edit` creates a `DraftDocument` from
  `_readDocument()`, runs the callback, reads the commit plan, materializes the
  draft document, and installs the committed document when the plan has changes
  (`lib/src/edit/edit_kernel.dart:43`,
  `lib/src/edit/edit_kernel.dart:51`,
  `lib/src/edit/edit_kernel.dart:52`,
  `lib/src/edit/edit_kernel.dart:58`,
  `lib/src/edit/edit_kernel.dart:64`,
  `lib/src/edit/edit_kernel.dart:66`,
  `lib/src/edit/edit_kernel.dart:67`).
- **Dependencies**: Store reads use `DocumentProjectionCache.projectionFor`
  (`lib/src/store/document_store_kernel.dart:48`,
  `lib/src/store/document_projection_cache.dart:12`). On cache miss,
  `_buildProjection` creates a `CanvasDocument`, copies palette/resources, maps
  background elements, and maps layer rows to `CanvasLayer` objects
  (`lib/src/store/document_projection_cache.dart:20`,
  `lib/src/store/document_projection_cache.dart:21`,
  `lib/src/store/document_projection_cache.dart:29`,
  `lib/src/store/document_projection_cache.dart:33`,
  `lib/src/store/document_projection_cache.dart:34`,
  `lib/src/store/document_projection_cache.dart:35`,
  `lib/src/store/document_projection_cache.dart:38`,
  `lib/src/store/document_projection_cache.dart:41`).
- **Data flow**: edit case -> `_runtime(scaleId)` -> `runtime.edits.edit` ->
  `_store.readDocument()` projection -> `DraftDocument` copies -> local mutation
  -> materialized `CanvasDocument` -> commit apply -> delivery effects. The
  draft constructor copies palette, resources, background elements, and each
  layer's elements into mutable draft state (`lib/src/edit/draft_document.dart:31`,
  `lib/src/edit/draft_document.dart:37`,
  `lib/src/edit/draft_document.dart:39`,
  `lib/src/edit/draft_document.dart:42`,
  `lib/src/edit/draft_document.dart:43`,
  `lib/src/edit/draft_document.dart:47`).
- **Observed consequence**: `edit.update_visual`, `edit.update_transform`,
  `edit.add_element`, and `edit.add_line` all enter the same full projection/
  draft/materialize transaction path before or after touching one element
  (`test/benchmarks/benchmark_probe_flutter.dart:197`,
  `test/benchmarks/benchmark_probe_flutter.dart:200`,
  `test/benchmarks/benchmark_probe_flutter.dart:209`,
  `test/benchmarks/benchmark_probe_flutter.dart:212`,
  `test/benchmarks/benchmark_probe_flutter.dart:226`,
  `test/benchmarks/benchmark_probe_flutter.dart:229`,
  `test/benchmarks/benchmark_probe_flutter.dart:267`,
  `test/benchmarks/benchmark_probe_flutter.dart:270`). The current report shows
  these cases among the slowest rows at 50k/100k
  (`build/bench/current/pixel6_release.json:106`,
  `build/bench/current/pixel6_release.json:122`,
  `build/bench/current/pixel6_release.json:201`,
  `build/bench/current/pixel6_release.json:218`,
  `build/bench/current/pixel6_release.json:297`,
  `build/bench/current/pixel6_release.json:314`,
  `build/bench/current/pixel6_release.json:598`,
  `build/bench/current/pixel6_release.json:614`).

### 4. Selection Move: Full Order Read Plus Edit Updates

- **Location**: primary `lib/src/runtime/runtime_command_facts_adapter.dart:38`.
- **Description**: `selectionTransformFacts` builds a command read context,
  derives selected ids in document order, creates a selected set, and loops
  every context handle while resolving selected movable elements
  (`lib/src/runtime/runtime_command_facts_adapter.dart:38`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:39`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:40`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:41`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:42`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:44`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:45`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:46`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:47`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:48`).
- **Dependencies**: `_context` reads the current structural revision, all element
  handles, and selection facts (`lib/src/runtime/runtime_command_facts_adapter.dart:103`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:104`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:106`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:107`,
  `lib/src/runtime/runtime_command_facts_adapter.dart:108`).
- **Data flow**: benchmark selects up to 16 ids, calls
  `runtime.selection.moveSelection`, runtime validates and builds a translation,
  then `_deliverSelectionTransform` loops movable elements and calls
  `edit.updateElement` for each transformed element
  (`test/benchmarks/benchmark_probe_flutter.dart:245`,
  `test/benchmarks/benchmark_probe_flutter.dart:248`,
  `test/benchmarks/benchmark_probe_flutter.dart:249`,
  `test/benchmarks/benchmark_probe_flutter.dart:250`,
  `lib/src/runtime/runtime_root.dart:780`,
  `lib/src/runtime/runtime_root.dart:782`,
  `lib/src/runtime/runtime_root.dart:786`,
  `lib/src/runtime/runtime_root.dart:787`,
  `lib/src/runtime/runtime_root.dart:913`,
  `lib/src/runtime/runtime_root.dart:914`,
  `lib/src/runtime/runtime_root.dart:915`).
- **Observed consequence**: `edit.move_selection/50k` reports
  `selected_count: 16`, `avg_us: 690630`, and `allocation_bytes: 5111808`
  (`build/bench/current/pixel6_release.json:387`,
  `build/bench/current/pixel6_release.json:401`,
  `build/bench/current/pixel6_release.json:405`).

### 5. Camera Offset: Runtime Setup Dominates A Local State Update

- **Location**: primary `lib/src/runtime/runtime_root.dart:1199`.
- **Description**: `setCameraOffset` validates mutation, creates a
  `CanvasCamera`, compares it to `_viewCamera`, assigns it, increments
  `_viewCameraRevision`, and publishes runtime state
  (`lib/src/runtime/runtime_root.dart:1199`,
  `lib/src/runtime/runtime_root.dart:1200`,
  `lib/src/runtime/runtime_root.dart:1201`,
  `lib/src/runtime/runtime_root.dart:1202`,
  `lib/src/runtime/runtime_root.dart:1205`,
  `lib/src/runtime/runtime_root.dart:1206`,
  `lib/src/runtime/runtime_root.dart:1207`).
- **Dependencies**: The benchmark case itself calls only
  `runtime.cameraPort().setOffset(...)` and returns
  `ordinary_paint_plan_invalidations: 0`
  (`test/benchmarks/benchmark_probe_flutter.dart:257`,
  `test/benchmarks/benchmark_probe_flutter.dart:260`,
  `test/benchmarks/benchmark_probe_flutter.dart:261`).
- **Data flow**: `_runtime(scaleId)` setup -> camera port -> local view-camera
  state update -> publish runtime state. The cited body does not call
  `readDocument`, `installDocument`, `replaceDocument`, or spatial delivery
  (`lib/src/runtime/runtime_root.dart:1199`,
  `lib/src/runtime/runtime_root.dart:1207`).
- **Observed consequence**: Despite a local camera body, the current
  `edit.set_camera_offset/100k` row reports `avg_us: 1035753` and
  `ordinary_paint_plan_invalidations: 0`
  (`build/bench/current/pixel6_release.json:519`,
  `build/bench/current/pixel6_release.json:533`,
  `build/bench/current/pixel6_release.json:537`). This aligns with the harness
  fact that sample timing includes case setup.

### 6. Load Success And Projection Read

- **Location**: primary `lib/src/runtime/runtime_root.dart:1494`.
- **Description**: `_loadDocument` prepares the load, prepares interaction
  cleanup, consumes the prepared load, clears selection for document replacement,
  updates view camera and revisions, and delivers load effects
  (`lib/src/runtime/runtime_root.dart:1494`,
  `lib/src/runtime/runtime_root.dart:1495`,
  `lib/src/runtime/runtime_root.dart:1497`,
  `lib/src/runtime/runtime_root.dart:1498`,
  `lib/src/runtime/runtime_root.dart:1499`,
  `lib/src/runtime/runtime_root.dart:1500`,
  `lib/src/runtime/runtime_root.dart:1501`,
  `lib/src/runtime/runtime_root.dart:1502`,
  `lib/src/runtime/runtime_root.dart:1503`).
- **Dependencies**: Load preparation calls `ValidatedImportDraft.fromDocument`,
  which validates resources, layers, and element ids (`lib/src/edit/staged_document_load.dart:54`,
  `lib/src/edit/staged_document_load.dart:55`,
  `lib/src/codec/validated_import_draft.dart:14`,
  `lib/src/codec/validated_import_draft.dart:18`,
  `lib/src/codec/validated_import_draft.dart:19`,
  `lib/src/codec/validated_import_draft.dart:32`,
  `lib/src/codec/validated_import_draft.dart:53`,
  `lib/src/codec/validated_import_draft.dart:75`). Consuming the prepared load
  replaces the document in the store (`lib/src/edit/staged_document_load.dart:70`,
  `lib/src/edit/staged_document_load.dart:81`,
  `lib/src/store/document_store_kernel.dart:191`,
  `lib/src/store/document_store_kernel.dart:195`).
- **Data flow**: load case -> empty `RuntimeRoot` -> synthetic document ->
  validation -> store replacement -> selection/camera/revision updates ->
  document-replacement effects -> spatial rebuild. Spatial delivery calls
  `_spatial.applyTouched`, and document replacement causes `SpatialKernel` to
  rebuild (`lib/src/runtime/runtime_root.dart:1591`,
  `lib/src/runtime/runtime_root.dart:1658`,
  `lib/src/geometry/spatial_kernel.dart:72`,
  `lib/src/geometry/spatial_kernel.dart:74`).
- **Observed consequence**: `load_document.success/100k` reports
  `loaded_element_count: 100000`, `rebuild_cost: 128`, and `avg_us: 1219081`
  (`build/bench/current/pixel6_release.json:1856`,
  `build/bench/current/pixel6_release.json:1870`,
  `build/bench/current/pixel6_release.json:1871`,
  `build/bench/current/pixel6_release.json:1874`). `load_document.failure`
  validates enough to throw duplicate id before consume; the failure case
  catches `CanvasDataException` and returns zero committed mutations
  (`test/benchmarks/benchmark_probe_flutter.dart:707`,
  `test/benchmarks/benchmark_probe_flutter.dart:711`,
  `test/benchmarks/benchmark_probe_flutter.dart:721`,
  `test/benchmarks/benchmark_probe_flutter.dart:722`,
  `test/benchmarks/benchmark_probe_flutter.dart:723`,
  `test/benchmarks/benchmark_probe_flutter.dart:724`).

### 7. Spatial Query Candidate Budget Path

- **Location**: primary `lib/src/geometry/tile_index.dart:48`.
- **Description**: `TileIndex.query` computes query tile count, scans all tiles
  for the query window, adds outlier candidates, and calls
  `spatialCandidateResultWithinBudget` (`lib/src/geometry/tile_index.dart:48`,
  `lib/src/geometry/tile_index.dart:52`,
  `lib/src/geometry/tile_index.dart:62`,
  `lib/src/geometry/tile_index.dart:63`,
  `lib/src/geometry/tile_index.dart:64`,
  `lib/src/geometry/tile_index.dart:66`,
  `lib/src/geometry/tile_index.dart:70`).
- **Dependencies**: Candidate budget is `kCanvasMaxFallbackCandidates = 4096`
  (`lib/src/geometry/spatial_query_policy.dart:7`). Candidate admission maps
  each handle, returns `SpatialBudgetExceededResult` when candidates exceed the
  budget, otherwise sorts by descending order token and returns unmodifiable
  candidates (`lib/src/geometry/tile_index.dart:95`,
  `lib/src/geometry/tile_index.dart:101`,
  `lib/src/geometry/tile_index.dart:103`,
  `lib/src/geometry/tile_index.dart:104`,
  `lib/src/geometry/tile_index.dart:107`,
  `lib/src/geometry/tile_index.dart:114`,
  `lib/src/geometry/tile_index.dart:116`,
  `lib/src/geometry/tile_index.dart:117`).
- **Data flow**: spatial benchmark -> `SpatialQueryWindow` for 512x512 viewport
  -> `runtime.spatialKernel.queryHit` -> query state -> tile index -> candidate
  budget. The benchmark maps `fallbackCandidateBudgetExceeded` to
  `fallback_count = observed` (`test/benchmarks/benchmark_probe_flutter.dart:669`,
  `test/benchmarks/benchmark_probe_flutter.dart:674`,
  `test/benchmarks/benchmark_probe_flutter.dart:676`,
  `test/benchmarks/benchmark_probe_flutter.dart:684`,
  `test/benchmarks/benchmark_probe_flutter.dart:687`,
  `test/benchmarks/benchmark_probe_flutter.dart:691`).
- **Observed consequence**: `spatial.query_point/1k` reports `fallback_count: 0`;
  `10k`, `50k`, and `100k` report `fallback_count: 4097`
  (`build/bench/current/pixel6_release.json:2001`,
  `build/bench/current/pixel6_release.json:2034`,
  `build/bench/current/pixel6_release.json:2067`,
  `build/bench/current/pixel6_release.json:2100`). The `100k` row reports
  `avg_us: 1010183` (`build/bench/current/pixel6_release.json:2103`).

### 8. Frame Capture And Paint Candidates

- **Location**: primary `lib/src/frame/frame_capture_service.dart:52`.
- **Description**: `_captureSnapshot` reads frame revisions and selection facts,
  runs spatial paint query over the effective world bounds, admits paint
  candidates, appends selected handles not already seen, resolves elements, and
  collects resource descriptors (`lib/src/frame/frame_capture_service.dart:52`,
  `lib/src/frame/frame_capture_service.dart:53`,
  `lib/src/frame/frame_capture_service.dart:55`,
  `lib/src/frame/frame_capture_service.dart:56`,
  `lib/src/frame/frame_capture_service.dart:59`,
  `lib/src/frame/frame_capture_service.dart:64`,
  `lib/src/frame/frame_capture_service.dart:69`,
  `lib/src/frame/frame_capture_service.dart:71`,
  `lib/src/frame/frame_capture_service.dart:91`,
  `lib/src/frame/frame_capture_service.dart:96`,
  `lib/src/frame/frame_capture_service.dart:116`,
  `lib/src/frame/frame_capture_service.dart:122`).
- **Dependencies**: `frame.paint_candidates` explicitly calls
  `runtime.readDocument()` before `runtime.buildResourceFreeMainFrame`, then
  reads `output.ordinaryPlan.candidateCount` and counts records requiring save
  layers (`test/benchmarks/benchmark_probe_flutter.dart:466`,
  `test/benchmarks/benchmark_probe_flutter.dart:469`,
  `test/benchmarks/benchmark_probe_flutter.dart:470`,
  `test/benchmarks/benchmark_probe_flutter.dart:476`,
  `test/benchmarks/benchmark_probe_flutter.dart:478`,
  `test/benchmarks/benchmark_probe_flutter.dart:479`,
  `test/benchmarks/benchmark_probe_flutter.dart:482`).
- **Data flow**: frame case -> runtime setup -> optional projection read ->
  frame capture -> ordinary planning -> selected-move supplement/static
  background/selection decoration/render primitive snapshot. `FrameEngine` does
  these steps in `_buildMainFrame` (`lib/src/frame/frame_engine.dart:97`,
  `lib/src/frame/frame_engine.dart:102`,
  `lib/src/frame/frame_engine.dart:103`,
  `lib/src/frame/frame_engine.dart:104`,
  `lib/src/frame/frame_engine.dart:105`,
  `lib/src/frame/frame_engine.dart:106`,
  `lib/src/frame/frame_engine.dart:110`,
  `lib/src/frame/frame_engine.dart:114`,
  `lib/src/frame/frame_engine.dart:115`,
  `lib/src/frame/frame_engine.dart:116`,
  `lib/src/frame/frame_engine.dart:125`).
- **Observed consequence**: `frame.paint_candidates/100k` reports
  `candidate_count: 0`, zero offscreen/save-layer counts, and
  `avg_us: 1382744` (`build/bench/current/pixel6_release.json:1473`,
  `build/bench/current/pixel6_release.json:1488`,
  `build/bench/current/pixel6_release.json:1489`,
  `build/bench/current/pixel6_release.json:1490`,
  `build/bench/current/pixel6_release.json:1493`). `frame.main_capture/100k`
  also reports zero captured elements and `avg_us: 1066406`
  (`build/bench/current/pixel6_release.json:1296`,
  `build/bench/current/pixel6_release.json:1310`,
  `build/bench/current/pixel6_release.json:1311`,
  `build/bench/current/pixel6_release.json:1315`).

### 9. Input Preview Cases

- **Location**: primary `test/benchmarks/benchmark_probe_flutter.dart:403`.
- **Description**: `_drawToolPreview` creates a runtime, sets draw mode/tool,
  sends down and move pointer samples, and returns either preview point count or
  preview revision count (`test/benchmarks/benchmark_probe_flutter.dart:403`,
  `test/benchmarks/benchmark_probe_flutter.dart:408`,
  `test/benchmarks/benchmark_probe_flutter.dart:410`,
  `test/benchmarks/benchmark_probe_flutter.dart:411`,
  `test/benchmarks/benchmark_probe_flutter.dart:412`,
  `test/benchmarks/benchmark_probe_flutter.dart:413`,
  `test/benchmarks/benchmark_probe_flutter.dart:414`,
  `test/benchmarks/benchmark_probe_flutter.dart:417`,
  `test/benchmarks/benchmark_probe_flutter.dart:418`,
  `test/benchmarks/benchmark_probe_flutter.dart:419`).
- **Dependencies**: Runtime pointer input delegates from tool port to
  `RuntimeRoot.handlePointer`, then into `InteractionEngine.handlePointerSample`
  with camera offset, epoch, selected ids, selection revision, and timestamp
  resolver (`lib/src/runtime/runtime_root.dart:2277`,
  `lib/src/runtime/runtime_root.dart:2278`,
  `lib/src/runtime/runtime_root.dart:1236`,
  `lib/src/runtime/runtime_root.dart:1238`,
  `lib/src/runtime/runtime_root.dart:1240`,
  `lib/src/runtime/runtime_root.dart:1243`,
  `lib/src/runtime/runtime_root.dart:1244`).
- **Data flow**: input case -> runtime setup -> interaction engine pointer down/
  move -> preview replacement -> runtime state publication. Preview replacement
  increments preview revision only when the preview state changes
  (`lib/src/interaction/interaction_engine.dart:188`,
  `lib/src/interaction/interaction_engine.dart:189`,
  `lib/src/interaction/interaction_engine.dart:192`,
  `lib/src/interaction/interaction_engine.dart:193`,
  `lib/src/runtime/runtime_root.dart:1468`,
  `lib/src/runtime/runtime_root.dart:1472`,
  `lib/src/runtime/runtime_root.dart:1474`).
- **Observed consequence**: Larger input preview rows are clustered near the
  frame/spatial/edit rows: `input.line_preview/50k` reports `avg_us: 666377`,
  `input.eraser_preview/50k` reports `avg_us: 635524`,
  `input.selected_move_preview/50k` reports `avg_us: 622195`, and
  `input.marquee_preview/50k` reports `avg_us: 599859`
  (`build/bench/current/pixel6_release.json:1046`,
  `build/bench/current/pixel6_release.json:1063`,
  `build/bench/current/pixel6_release.json:1148`,
  `build/bench/current/pixel6_release.json:1168`,
  `build/bench/current/pixel6_release.json:685`,
  `build/bench/current/pixel6_release.json:702`,
  `build/bench/current/pixel6_release.json:886`,
  `build/bench/current/pixel6_release.json:903`).

### 10. Resource And Diagnostic Contrast Cases

- **Location**: primary `test/benchmarks/benchmark_probe_flutter.dart:494`.
- **Description**: Resource cases create runtime/session/resolver combinations,
  but the current resource scales are bounded to resource-oriented 1k inputs and
  report low timing values relative to 50k/100k document/frame/edit cases
  (`test/benchmarks/benchmark_probe_flutter.dart:494`,
  `test/benchmarks/benchmark_probe_flutter.dart:498`,
  `test/benchmarks/benchmark_probe_flutter.dart:503`,
  `test/benchmarks/benchmark_probe_flutter.dart:524`).
- **Dependencies**: `kMaxSyncResourceResolverCallsPerFrame` is 128
  (`lib/src/resources/resource_resolver_adapter.dart:7`), and the cold-budget
  case resolves exactly that many cold ids before one extra budgeted request
  (`test/benchmarks/benchmark_probe_flutter.dart:546`,
  `test/benchmarks/benchmark_probe_flutter.dart:547`,
  `test/benchmarks/benchmark_probe_flutter.dart:549`,
  `test/benchmarks/benchmark_probe_flutter.dart:552`,
  `test/benchmarks/benchmark_probe_flutter.dart:554`).
- **Data flow**: resource lookup -> `SurfaceResourceSession.resolveImage` ->
  cache/budget/resolver paths. Dirty paths attach session invalidation sinks,
  mark resource(s) dirty, and re-resolve requests
  (`test/benchmarks/benchmark_probe_flutter.dart:583`,
  `test/benchmarks/benchmark_probe_flutter.dart:590`,
  `test/benchmarks/benchmark_probe_flutter.dart:591`,
  `test/benchmarks/benchmark_probe_flutter.dart:613`,
  `test/benchmarks/benchmark_probe_flutter.dart:623`,
  `test/benchmarks/benchmark_probe_flutter.dart:624`).
- **Observed consequence**: Current resource rows report avg values around
  9-11 ms: `resources.resolve_sync` `avg_us: 11170`,
  `resources.resolve_sync_cold_budget` `avg_us: 9664`,
  `resources.mark_dirty` `avg_us: 9113`, and `resources.mark_all_dirty`
  `avg_us: 9472` (`build/bench/current/pixel6_release.json:1515`,
  `build/bench/current/pixel6_release.json:1535`,
  `build/bench/current/pixel6_release.json:1550`,
  `build/bench/current/pixel6_release.json:1570`,
  `build/bench/current/pixel6_release.json:1585`,
  `build/bench/current/pixel6_release.json:1603`,
  `build/bench/current/pixel6_release.json:1618`,
  `build/bench/current/pixel6_release.json:1636`). Diagnostic contrast rows
  are lower: `runtime.dispose_during_gesture` `avg_us: 59` and
  `diagnostics.disabled_pointer` `avg_us: 33`
  (`build/bench/current/pixel6_release.json:2223`,
  `build/bench/current/pixel6_release.json:2241`,
  `build/bench/current/pixel6_release.json:2263`,
  `build/bench/current/pixel6_release.json:2281`).

## Code References

- `test/benchmarks/benchmark_probe_flutter.dart:131` - sample timer wraps
  `_runOperation`.
- `test/benchmarks/benchmark_probe_flutter.dart:761` - synthetic benchmark
  document generation begins.
- `test/benchmarks/benchmark_probe_flutter.dart:784` - runtime setup helper
  constructs `RuntimeRoot`.
- `lib/src/runtime/runtime_root.dart:159` - constructor rebuilds spatial index.
- `lib/src/edit/edit_kernel.dart:52` - edit session starts from full
  `_readDocument()`.
- `lib/src/edit/draft_document.dart:31` - draft constructor copies document
  state into mutable draft state.
- `lib/src/store/document_projection_cache.dart:29` - projection cache builds
  public `CanvasDocument`.
- `lib/src/runtime/runtime_command_facts_adapter.dart:38` - selection transform
  facts read document-order handles.
- `lib/src/runtime/runtime_root.dart:1199` - camera offset body is a local view
  camera update.
- `lib/src/runtime/runtime_root.dart:1494` - load-document pipeline entry.
- `lib/src/geometry/tile_index.dart:95` - spatial candidate budget evaluation.
- `lib/src/frame/frame_capture_service.dart:52` - frame capture snapshot entry.
- `lib/src/frame/frame_engine.dart:97` - main frame build pipeline entry.
- `test/benchmarks/benchmark_probe_flutter.dart:466` - `frame.paint_candidates`
  adapter entry.

## Search Coverage

- **Inspected**: `build/bench/current/pixel6_release.json`; `tool/bench/src/benchmark_case_adapters.dart`; `tool/bench/src/benchmark_manifest.dart`; `tool/bench/src/benchmark_runner.dart`; `tool/bench/src/benchmark_report.dart`; `docs/_registry/benchmarks.yaml`; `docs/verification/benchmarks.md`; `test/benchmarks/benchmark_probe.dart`; `test/benchmarks/benchmark_probe_flutter.dart`; `lib/src/runtime/runtime_root.dart`; `lib/src/runtime/runtime_command_facts_adapter.dart`; `lib/src/runtime/runtime_interaction_read_adapter.dart`; `lib/src/edit/edit_kernel.dart`; `lib/src/edit/draft_document.dart`; `lib/src/edit/commit_compiler.dart`; `lib/src/edit/staged_document_load.dart`; `lib/src/store/document_store_kernel.dart`; `lib/src/store/document_projection_cache.dart`; `lib/src/store/committed_document.dart`; `lib/src/store/element_registry.dart`; `lib/src/geometry/spatial_kernel.dart`; `lib/src/geometry/spatial_entry_loader.dart`; `lib/src/geometry/spatial_index_set.dart`; `lib/src/geometry/tile_index.dart`; `lib/src/geometry/spatial_kernel_query_state.dart`; `lib/src/geometry/spatial_query_policy.dart`; `lib/src/frame/frame_capture_service.dart`; `lib/src/frame/frame_engine.dart`; `lib/src/frame/ordinary_paint_planner.dart`; `lib/src/frame/selected_move_supplement_planner.dart`; `lib/src/frame/paint_plan.dart`; `lib/src/frame/render_element_record.dart`; `lib/src/interaction/interaction_engine.dart`; `lib/src/interaction/draw_stroke_machine.dart`; `lib/src/interaction/line_machine.dart`; `lib/src/interaction/eraser_machine.dart`; `lib/src/interaction/move_machine.dart`; `lib/src/resources/surface_resource_session.dart`; `lib/src/resources/resource_cache.dart`; `lib/src/resources/resource_kernel.dart`; `lib/src/resources/resource_resolver_adapter.dart`.
- **Searched**: `rg --files | rg 'bench|benchmark|perf|performance'`; `rg -n 'edit\.add_element|edit\.update_visual|edit\.update_transform|edit\.move_selection|edit\.set_camera_offset|edit\.add_line|load_document\.success|projection\.read_document|frame\.paint_candidates|spatial\.query_point|spatial\.touched_update|input\.line_preview|input\.eraser_preview' tool/bench lib test/benchmarks docs/verification docs/_registry`; `rg -n 'class RuntimeRoot|RuntimeRoot\(|readDocument\(|buildResourceFreeMainFrame|loadDocument\(|addElement\(|updateElement\(|moveSelection\(|setOffset\(|queryHit\(|queryPaint' lib/src`; `rg -n 'class FrameCaptureService|captureMainFrame|buildOrdinaryPlan|ordinaryRecords|candidateCount|class OrdinaryPaintPlanner|class SelectedMoveSupplementPlanner' lib/src`; `rg -n 'SpatialKernel|queryHit|queryPaint|SpatialBudgetExceeded|fallbackCandidateBudget|touched|rebuilt|page' lib/src/geometry lib/src/runtime lib/src/frame`; `jq` top timing summaries from `build/bench/current/pixel6_release.json`.
- **Not found**: no evidence that the benchmark sample timer isolates only the
  inner case-specific operation after runtime setup; all cited timing code wraps
  full `_runOperation`.
- **Not inspected**: surface painter draw execution beyond frame output data
  structures, because the inspected benchmark cases stop at frame/input metrics
  returned from `test/benchmarks/benchmark_probe_flutter.dart`.

## Observed Architecture Facts

- Pattern observed: benchmark timing reports full case operation scope, while
  some case-specific metrics time narrower inner operations
  (`test/benchmarks/benchmark_probe_flutter.dart:131`,
  `test/benchmarks/benchmark_probe_flutter.dart:451`,
  `test/benchmarks/benchmark_probe_flutter.dart:454`).
- Pattern observed: runtime setup builds committed document state and spatial
  indexes for synthetic documents before case-specific work
  (`test/benchmarks/benchmark_probe_flutter.dart:784`,
  `lib/src/runtime/runtime_root.dart:97`,
  `lib/src/runtime/runtime_root.dart:159`).
- Data flow: edit operation -> full projection read -> draft copy -> local
  mutation -> materialized document -> commit apply -> delivery effects
  (`lib/src/edit/edit_kernel.dart:52`,
  `lib/src/edit/draft_document.dart:31`,
  `lib/src/edit/edit_kernel.dart:66`,
  `lib/src/edit/edit_kernel.dart:67`,
  `lib/src/runtime/runtime_root.dart:1569`).
- Data flow: frame paint candidates -> projection read -> main frame build ->
  frame capture -> spatial query -> ordinary plan (`test/benchmarks/benchmark_probe_flutter.dart:469`,
  `test/benchmarks/benchmark_probe_flutter.dart:470`,
  `lib/src/frame/frame_engine.dart:102`,
  `lib/src/frame/frame_engine.dart:103`,
  `lib/src/frame/frame_capture_service.dart:56`,
  `lib/src/frame/ordinary_paint_planner.dart:74`).
- Data flow: spatial query -> four-tile viewport -> candidate budget path ->
  fallback count 4097 at 10k+ scales (`test/benchmarks/benchmark_probe_flutter.dart:669`,
  `test/benchmarks/benchmark_probe_flutter.dart:676`,
  `lib/src/geometry/tile_index.dart:95`,
  `build/bench/current/pixel6_release.json:2034`,
  `build/bench/current/pixel6_release.json:2067`,
  `build/bench/current/pixel6_release.json:2100`).
- Key dependency: resource/session benchmarks are bounded around resource caps
  and are not among the slow 50k/100k document/frame/edit rows in the current
  report (`lib/src/resources/resource_resolver_adapter.dart:7`,
  `build/bench/current/pixel6_release.json:1535`,
  `build/bench/current/pixel6_release.json:1570`).

## Open Questions

- The current research maps benchmark rows to code paths and observed full-scope
  work, but it does not separate setup cost from steady-state operation cost by
  running alternate probes.
- The current research records that `frame.paint_candidates` and
  `frame.main_capture` report zero candidates/elements at 10k+ while still
  taking high wall time, but it does not instrument which setup sub-step within
  runtime construction accounts for the largest share.
- The current research does not inspect actual surface painter draw execution,
  because the benchmark cases researched here return frame/input metrics before
  painter execution.
