# Change Contract

## Goal

Redesign the existing Android Flutter performance route so the official
`integration_test` plus `flutter drive --profile --no-dds` path emits a complete
26-group catalog with canonical setup, warm, steady, and single phases, repeated
steady-state evidence for the seven high-signal Android groups, and generated
local artifacts that support before/after comparison without introducing custom
measurement infrastructure or numeric release thresholds.

## Source Inputs

- Design: `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md`
- Research: `.research/2026-06-16-android-performance-hotspot-paths.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `AGENTS.md`, `docs/verification/performance.md`,
  `docs/verification/tests.md`, `docs/verification/release_gates.md`,
  `example/lib/perf/performance_scenario.dart`,
  `example/integration_test/perf_canvas_surface_test.dart`,
  `example/test_driver/perf_driver.dart`,
  `lib/src/runtime/runtime_root.dart`,
  `docs/contracts/public_api_v1.md`,
  `tool/check_flutter_performance_artifacts.dart`,
  `test/performance/flutter_performance_route_contract_test.dart`,
  `test/tool/flutter_performance_artifacts_checker_test.dart`

## Classification

Profile: ANALYZER_RULE

Obligations: SEAM_MIGRATION

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Keep `integration_test` plus `flutter drive --profile --no-dds`, Flutter `traceAction`, and `TimelineSummary` as the measurement boundary. | `Boundaries.Owner`, `Boundaries.Compatibility`, `Unit 2`, `Unit 3` | Route contract test proves one traced runner owns report keys and driver still converts report data through `Timeline.fromJson` / `TimelineSummary.summarize`; profile-drive command proves the official route produces artifacts. |
| `D2` Change the catalog from one report key per scenario id to scenario groups with canonical `setup`, `warm`, `steady`, and `single` phases. | `Boundaries.Source of Truth`, `Unit 1`, `Unit 2`, `Unit 4` | `docs/verification/performance.md` defines the phase grammar; route contract test and checker reject unsupported phase kinds and malformed report keys. |
| `D3` Separate fixture/document setup from action cost for the seven redesigned Android groups. | `Boundaries.Order Constraints`, `Unit 1`, `Unit 2`, `Unit 4` | Descriptor tests prove setup/action separation for each redesigned group; focused example tests prove warm and steady phases run from pre-prepared state; checker validates separate setup, warm, and steady artifact phases. |
| `D4` Add warm and repeated steady-state variants for the redesigned groups. | `Unit 1`, `Unit 2`, `Unit 4` | Docs, descriptors, generated manifest, and checker all require exactly five `steady.*` repeats per redesigned group and `repeat_001` for each `warm.*`. |
| `D5` Keep generated artifacts under `example/build/flutter_performance/` and out of source control while defining a stable nested artifact shape. | `Boundaries.Generated Artifacts`, `Unit 3`, `Unit 4` | Driver writes only under `example/build/flutter_performance/`; checker rejects missing, malformed, unexpected, or misplaced outputs. |
| `D6` Generated `performance_run_manifest.json` and `comparison_summary.json` are organization/comparison summaries over official Flutter outputs, not source truth or custom measurement. | `Boundaries.Source of Truth`, `Boundaries.Compatibility`, `Generated Artifacts`, `Unit 3`, `Unit 4` | Driver derives summaries from official timeline summaries; checker validates the exact manifest and comparison-summary JSON shapes and rejects threshold, pass/fail, baseline, or regression-status fields. |
| `D7` Before/after comparison exposes raw-repeat-derived median and spread without threshold or device-independent precision claims. | `Unit 1`, `Unit 3`, `Unit 4` | Performance and release docs define supported local comparison semantics; generated comparison summary contains raw-repeat-derived local fields only. |
| `D8` Startup and Android Macrobenchmark remain outside this redesign. | `Boundaries.Out of Scope`, `Unit 1`, `Unit 2`, `Final Verification` | Route contract tests and docs preserve negative proof that startup/Macrobenchmark coverage is absent and unclaimed. |
| `D9` Retired benchmark infrastructure must not be restored. | `Boundaries.Out of Scope`, `Unit 2`, `Unit 4`, `Final Verification` | Structural tests/search proof reject `tool/bench/**`, `test/benchmarks/**`, retired benchmark ids, and custom benchmark-result schema. |
| `D10` All 26 current required scenarios remain covered: seven redesigned groups and nineteen `single.current_behavior` groups with `repeat_001`. | `Boundaries.Source of Truth`, `Unit 1`, `Unit 2`, `Unit 4` | Docs catalog, descriptor expansion, route contract tests, manifest validation, and checker prove full catalog migration. |
| `D11` Every `steady.*` repeat for redesigned groups starts from canonical prepared state equivalent to warm state; reset/reseed cost is outside measured steady traces. | `Boundaries.Order Constraints`, `Generated Artifacts`, `Unit 2`, `Unit 3`, `Unit 4` | Focused example tests use `PerformancePhasePreparationProbe` to compare two pre-action snapshots per redesigned group; manifest entries carry exact `canonicalPreparation`, `resetReason`, `measuredAction`, and `preparationMeasured: false` values; checker tests reject redesigned warm/steady manifest entries that omit or mis-state those fields. |

## Evidence

- `docs/verification/performance.md:30` / route owner: performance docs own the
  official Flutter performance route -> durable benchmark semantics belong in
  `docs/verification/performance.md`, not generated artifacts or design notes.
- `docs/verification/performance.md:35` / measurement route: the route runs the
  example app through `integration_test` and `flutter drive --profile` -> the
  redesign must preserve the official Flutter route instead of adding a custom
  collector or Android Macrobenchmark path.
- `docs/verification/performance.md:54` / current report-key shape: every
  scenario id is currently also the report key -> the migration must explicitly
  replace this source-of-truth rule with group/phase/repeat report keys.
- `docs/verification/performance.md:58` / current catalog: the current catalog
  lists 26 required scenario ids -> all 26 ids must remain represented as
  scenario groups after migration.
- `docs/verification/performance.md:94` / artifact root: profile-drive outputs
  live under `example/build/flutter_performance/` -> generated run outputs,
  manifests, and comparison summaries stay local and out of source control.
- `docs/verification/performance.md:108` / artifact writer: current driver uses
  `TimelineSummary.writeTimelineToFile(...)` -> generated raw artifacts continue
  to derive from Flutter timeline summaries.
- `docs/verification/performance.md:114` / gate semantics: the gate verifies
  completion and artifact production only -> repeat summaries must not become
  numeric threshold or regression gates.
- `docs/verification/performance.md:122` / retired boundary: benchmark registry,
  benchmark index, benchmark docs, `tool/bench/**`, `test/benchmarks/**`, old
  benchmark ids, and custom benchmark-result schema remain retired -> the
  redesign extends the Flutter route only.
- `docs/verification/tests.md:472` / test source of truth: tests docs identify
  the example integration performance route as a documented test surface -> the
  redesigned route tests must be documented there.
- `docs/verification/tests.md:486` / checker scope: artifact checker proof is
  inventory/JSON-shape only -> checker enforcement must stay shape/completeness
  focused, not performance pass/fail focused.
- `docs/verification/release_gates.md:167` / release gate: release gates require
  the full scenario catalog to complete through the profile-drive command and
  artifact checker -> release wording must migrate to the new artifact shape.
- `docs/verification/release_gates.md:173` / unsupported gates: p95, p99,
  frame-budget, baseline-diff, and regression thresholds remain unclaimed -> the
  new comparison summary cannot expose pass/fail or regression-status fields.
- `.research/2026-06-16-android-performance-hotspot-paths.md:13` / hotspot
  evidence: heavy Android summaries mix large setup work with traced actions ->
  setup/action separation is the owner-level fix.
- `.research/2026-06-16-android-performance-hotspot-paths.md:30` / claim scope:
  current traces are completion/artifact evidence without CPU-sample attribution
  -> before/after comparison claims must remain local and directional.
- `.research/2026-06-16-android-performance-hotspot-paths.md:87` / trace window:
  current traces are short action windows with fixed settle behavior -> steady
  repeats are required so one short trace does not dominate conclusions.
- `.research/2026-06-16-android-performance-hotspot-paths.md:113` / load and
  first-frame path: load and first-frame scenarios mix fixture JSON, document
  load, and first frame -> redesigned load and first-frame groups need explicit
  setup and action phases.
- `.research/2026-06-16-android-performance-hotspot-paths.md:198` / camera pan:
  `camera_pan.100k` mixes initial 100k load with repeated camera invalidation
  and paint planning -> pan needs setup, warm, and steady phases.
- `.research/2026-06-16-android-performance-hotspot-paths.md:231` / selection
  and marquee: selection move and marquee traces load fixtures before
  interaction paths -> those groups need canonical prepared state before action.
- `.research/2026-06-16-android-performance-hotspot-paths.md:280` / eraser:
  eraser summaries include fixture setup, pointer routing, preview repaint,
  commit, and spatial reads -> eraser needs setup-separated warm and steady
  pointer-drag traces.
- `.research/2026-06-16-android-performance-hotspot-paths.md:333` / JSON
  export: `json_export.50k` mixes document load, draft materialization, and JSON
  encoding -> export action cost must be traced after document setup is complete.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:315` /
  selected form: Candidate A is the chosen architecture -> implementation must
  extend the existing Flutter route with phase-aware repeats.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:327` /
  scenario groups: current 26 catalog ids remain scenario group ids -> no
  current required catalog coverage may be dropped.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:332` /
  phase grammar: only `setup`, `warm`, `steady`, and `single` phase kinds are
  canonical -> route, docs, and checker must reject any other phase kind.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:347` /
  report key grammar: report keys are
  `<scenario_group>__<phase_kind>.<phase_name>__repeat_<NNN>` -> descriptors,
  artifacts, manifest, and tests share this exact key shape.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:356` /
  full migration: the design fixes the fate of all 26 current scenarios -> the
  implementer must not choose scenario fate or names.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:387` /
  comparison semantics: seven redesigned groups have fixed required phases and
  comparison intent -> descriptor names and phase semantics are locked.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:399` /
  repeat count policy: steady phases need at least five repeats unless stronger
  evidence justifies more -> this contract fixes five steady repeats for each
  redesigned group and forbids fewer.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:407` /
  repeat invariant: every steady repeat starts from canonical prepared state and
  reset/reseed cost is outside the steady trace -> descriptors and tests must
  prove untraced reset before every steady repeat.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:414` /
  reset rules: each redesigned group has a concrete prepared-state and reset
  reason -> implementation must preserve those reset semantics exactly.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:432` /
  artifact shape: generated artifacts move to nested scenario group,
  phase-name, repeat directories plus manifest and comparison summary -> driver
  and checker must migrate together.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:464` /
  manifest and summary: generated metadata and comparison summaries are local
  generated artifacts and must not introduce thresholds or CPU attribution ->
  checker must validate allowed fields and reject forbidden fields.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:481` /
  decision trace: D1-D11 are locked contract handoff decisions -> this contract
  maps each decision to a unit or proof surface.
- `.design/2026-06-16-android-flutter-performance-benchmark-redesign.md:532` /
  lock-required facts: docs, descriptors, driver, checker, and tests are the
  owning surfaces -> execution units follow those owner boundaries.
- `lib/src/runtime/runtime_root.dart:812` / selection movement: `moveSelection`
  applies a translation transform -> selection-move repeats must reset selected
  element geometry before warm and every steady action trace.
- `lib/src/runtime/runtime_root.dart:1264` / camera movement: `panCameraBy`
  adds the delta to the current camera offset -> camera-pan repeats must reset
  camera offset to the canonical origin before warm and every steady action
  trace.
- `lib/src/runtime/runtime_root.dart:2206` / marquee commit: marquee commit
  delivers a replacement selection plan -> marquee repeats must not inherit a
  prior marquee selection before warm or steady action traces.
- `lib/src/runtime/runtime_root.dart:2427` / eraser commit: eraser commit
  removes erased element ids from the document -> eraser repeats must restore
  the dense document before warm and every steady action trace.
- `docs/contracts/public_api_v1.md:367` / public document read: `CanvasRuntime`
  exposes `readDocument()` -> reset proof can compare document fingerprints
  through public API instead of private runtime internals.
- `docs/contracts/public_api_v1.md:398` / public state observation:
  `state.value` is the single public runtime observation snapshot -> reset
  proof can compare public summaries and revision domains without `src/**`
  imports.
- `docs/contracts/public_api_v1.md:457` / public state summary:
  `CanvasRuntimeSummary` exposes element, layer, resource, and selected counts
  -> reset tests can prove canonical prepared state through public counts.
- `lib/src/contracts/public/canvas_runtime.dart:216` / public camera port:
  `CanvasCameraPort` exposes `offset` -> camera-pan reset proof can require the
  canonical origin through public API.
- `lib/src/contracts/public/canvas_tools.dart:110` / public tool port:
  `CanvasToolPort` exposes mode and draw style -> marquee and eraser reset
  proof can require move mode or eraser draw mode through public API.
- `example/lib/perf/performance_scenario.dart:96` / traced runner: current
  measurement wraps scenario action and settle in `traceAction` -> the redesign
  must retain a single official traced runner while changing report-key
  semantics.
- `example/lib/perf/performance_scenario.dart:107` / executable catalog:
  current descriptors live in one unmodifiable list -> phase/repeat expansion
  belongs at the descriptor/catalog owner, not scattered in the integration
  test.
- `example/lib/perf/performance_scenario.dart:137` / load scenario: current load
  action creates fixture JSON and loads it inside the trace -> `load_document.100k`
  must move fixture preparation outside warm and steady action traces.
- `example/lib/perf/performance_scenario.dart:149` / camera pan: current pan
  action loads the document and pans in one trace -> `camera_pan.100k` needs
  untraced loaded-document preparation before warm and steady traces.
- `example/lib/perf/performance_scenario.dart:177` / selection move: current
  action loads, selects, moves, and pumps in one trace -> `selection_move.50k`
  needs loaded-selected-document setup before measured move action.
- `example/lib/perf/performance_scenario.dart:196` / marquee: current action
  loads 50k rects before a pointer drag -> `marquee_select.50k` needs a loaded
  document, move mode, and no inherited selection before each action trace.
- `example/lib/perf/performance_scenario.dart:213` / eraser: eraser shares the
  draw helper and uses 50k documents for non-10k ids -> `eraser_dense_50k`
  coverage must be preserved while separating load/mode setup from pointer drag.
- `example/lib/perf/performance_scenario.dart:424` / export: current export
  action loads a 50k document before encoding JSON -> `json_export.50k` needs
  loaded-document setup before export traces.
- `example/integration_test/perf_canvas_surface_test.dart:21` / integration
  route: current test loops scenarios and delegates to `scenario.runTraced` ->
  integration test should keep delegation while descriptors own group/phase
  expansion.
- `example/integration_test/perf_canvas_surface_test.dart:47` / settle helper:
  the route owns bounded settle behavior -> setup, warm, steady, and single
  phases must use the same bounded settle policy after measured action.
- `example/test_driver/perf_driver.dart:35` / generated root reset: the driver
  deletes `build/flutter_performance` before writing -> generated local output
  remains disposable and out of source control.
- `example/test_driver/perf_driver.dart:57` / summary source: driver converts
  report data with `Timeline.fromJson` and `TimelineSummary.summarize` ->
  comparison summary must derive from official Flutter summaries, not a second
  measurement engine.
- `tool/check_flutter_performance_artifacts.dart:249` / catalog parser: checker
  currently reads required scenario ids from docs -> checker must keep docs as
  source truth while parsing group/phase/repeat expectations.
- `tool/check_flutter_performance_artifacts.dart:263` / current directory check:
  checker currently validates flat scenario directories -> it must migrate to
  nested group/phase/repeat validation.
- `tool/check_flutter_performance_artifacts.dart:341` / raw timeline shape:
  checker validates `traceEvents` -> raw Flutter timeline shape remains a
  required artifact proof.
- `tool/check_flutter_performance_artifacts.dart:349` / summary shape: checker
  validates Flutter timeline summary keys -> timeline summaries remain the base
  raw-repeat artifact shape.
- `test/performance/flutter_performance_route_contract_test.dart:40` /
  structural route proof: tests currently verify a single traced scenario runner
  -> they must migrate to a single phase/repeat traced runner and negative route
  proof.
- `test/performance/flutter_performance_route_contract_test.dart:116` / docs
  parser proof: route contract tests parse the performance doc catalog -> tests
  must migrate with the new source-of-truth catalog grammar.
- `test/tool/flutter_performance_artifacts_checker_test.dart:13` / accepted
  artifact proof: checker tests already prove accepted artifacts -> extend them
  to the nested generated artifact shape.
- `test/tool/flutter_performance_artifacts_checker_test.dart:40` / negative
  artifact proof: checker tests reject missing, malformed, and unexpected
  artifacts -> extend them to repeat cardinality, manifest, comparison summary,
  unsupported phases, and forbidden fields.

## Boundaries

Owner: `docs/verification/performance.md` owns durable scenario group policy,
phase grammar, repeat policy, artifact shape, comparison semantics, unsupported
claims, and full 26-scenario migration. `docs/verification/tests.md` owns the
documented test surfaces, and `docs/verification/release_gates.md` owns release
gate wording. `example/lib/perf/performance_scenario.dart` owns executable
scenario descriptors, phase expansion, report-key generation, and canonical
preparation/reset semantics. `example/integration_test/perf_canvas_surface_test.dart`
owns the integration route and bounded settle helper. `example/test_driver/perf_driver.dart`
owns generated raw timeline, timeline summary, manifest, and comparison-summary
writing under the build output. `tool/check_flutter_performance_artifacts.dart`
owns generated artifact validation. `test/performance`,
`test/tool`, and focused `example/test` coverage own route, checker, driver,
and scenario-state proof.

In Scope: migrate the current 26-scenario Flutter performance catalog to
scenario groups; redesign exactly `load_document.100k`,
`first_canvas_frame.50k`, `camera_pan.100k`, `selection_move.50k`,
`marquee_select.50k`, `json_export.50k`, and `eraser_dense_50k`; migrate every
other current required scenario to `single.current_behavior` with `repeat_001`;
define and enforce the report key grammar
`<scenario_group>__<phase_kind>.<phase_name>__repeat_<NNN>`; use only `setup`,
`warm`, `steady`, and `single` phase kinds; use exactly five steady repeats for
each redesigned group; preserve Flutter `traceAction` and `TimelineSummary`;
write generated artifacts only under `example/build/flutter_performance/`;
generate `performance_run_manifest.json` and `comparison_summary.json` as local
run output; update docs, route contract tests, focused example tests, checker
tests, and release/test documentation to match the new route.

Out of Scope: production runtime behavior changes; public API changes;
validation-limit expansion; custom measurement infrastructure; custom VM
timeline collectors; custom frame timing engines; checked-in generated
performance artifacts; numeric regression thresholds; checked-in baselines;
pass/fail performance fields; baseline or regression-status fields; startup or
Android Macrobenchmark routes; restored `tool/bench/**`; restored
`test/benchmarks/**`; retired benchmark ids; custom benchmark-result schema;
CPU-subsystem ownership claims; device-independent percentage-win claims.

Source of Truth: `docs/verification/performance.md` is the single durable source
for route command, scenario groups, phase grammar, repeat count, artifact shape,
comparison semantics, unsupported claims, and full catalog migration. Generated
`performance_run_manifest.json`, raw timeline files, timeline summaries, and
`comparison_summary.json` are local build artifacts only and must not become
source truth. Executable descriptors in `example/lib/perf/performance_scenario.dart`
must be mechanically checked against the docs source of truth.

Compatibility: The package public API and production runtime semantics must not
change. The generated artifact shape is allowed to break compatibility with
previous flat `example/build/flutter_performance/<scenario_id>/` output because
that output is generated and disposable, but the official command remains the
same profile-drive family:
`cd example && flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/perf_canvas_surface_test.dart --profile --no-dds`.
Release acceptance remains completion plus artifact integrity only and must not
claim numeric pass/fail thresholds.

Order Constraints: Update documentation source of truth before changing parser,
descriptor, driver, or checker semantics. In Unit 2, implement descriptor-level
full-catalog phase/repeat expansion before updating the integration runner to
emit phase report keys. In Unit 2, implement canonical state
preparation/reset semantics before enabling `steady.*` repeats. Migrate
executable descriptors before driver/checker validation is made strict.
Generate raw timeline and timeline summary artifacts before writing manifest
and comparison summary. Compare optimization runs only across the same scenario
group, phase, repeat count, route command, and local environment notes. Run
checker after profile-drive artifacts exist. Do not remove or weaken
retired-route negative proof while migrating the route.

Measurement Route: The only measurement seam is Flutter
`IntegrationTestWidgetsFlutterBinding.traceAction`, host-side `Timeline.fromJson`,
and `TimelineSummary.summarize` / `TimelineSummary.writeTimelineToFile`. The
repository may organize, summarize, and validate official Flutter outputs, but
must not collect timing data through a custom engine.

Generated Artifacts: Successful runs produce
`example/build/flutter_performance/performance_run_manifest.json`,
`example/build/flutter_performance/comparison_summary.json`, and nested
`<scenario_group>/<phase_kind>.<phase_name>/<repeat_NNN>/` directories
containing exactly `<report_key>.timeline.json` and
`<report_key>.timeline_summary.json` for each report key.

`performance_run_manifest.json` must be a JSON object with exactly these
top-level keys and no extra top-level keys:

```text
schemaVersion: 1
route: object
unsupportedClaims: object
scenarioGroups: array
```

`route` must contain exactly `name: "flutter_performance"`,
`commandFamily: "flutter drive --profile --no-dds"`,
`driver: "test_driver/perf_driver.dart"`, and
`target: "integration_test/perf_canvas_surface_test.dart"`.
`unsupportedClaims` must contain exactly `numericThresholds: false`,
`passFailPerformance: false`, `baselines: false`,
`regressionStatusClaims: false`, `cpuAttribution: false`, `startup: false`, and
`androidMacrobenchmark: false`. Each `scenarioGroups` entry must contain
exactly `id`, `migration`, and `phases`, where `migration` is either
`"redesigned"` or `"single.current_behavior"`. Each phase entry must contain
exactly `kind`, `name`, `comparisonRole`, and `repeats`; `kind` is one of
`setup`, `warm`, `steady`, or `single`, and `comparisonRole` is one of
`setup_context`, `first_use_action`, `steady_action`, or `current_behavior`.
Each repeat entry must contain exactly `repeat`, `reportKey`,
`artifactDirectory`, `timelineFile`, and `timelineSummaryFile`, except
redesigned `warm.*` and `steady.*` repeat entries must additionally contain
`canonicalPreparation`, `resetReason`, `measuredAction`, and
`preparationMeasured: false`. `single.current_behavior` entries must not contain
`canonicalPreparation`, `resetReason`, or `measuredAction`.

The required `canonicalPreparation`, `resetReason`, and `measuredAction` values
for redesigned `warm.*` and `steady.*` repeat entries are fixed:

| Scenario group | canonicalPreparation | resetReason | measuredAction |
|---|---|---|---|
| `load_document.100k` | `empty_runtime_with_prepared_json_fixture` | `load_writes_document_state` | `load_document` |
| `first_canvas_frame.50k` | `preloaded_runtime_not_rendered_by_measured_surface` | `first_frame_cost_disappears_after_render` | `first_canvas_frame` |
| `camera_pan.100k` | `loaded_document_camera_origin_settled_surface` | `pan_accumulates_camera_offset` | `camera_pan` |
| `selection_move.50k` | `loaded_selected_document_original_geometry` | `move_translates_selected_geometry` | `selection_move` |
| `marquee_select.50k` | `loaded_document_move_mode_no_selection_settled_surface` | `marquee_commit_replaces_selection` | `marquee_select` |
| `json_export.50k` | `loaded_document_stable_order_no_pending_edit` | `export_reset_keeps_repeats_comparable` | `json_export` |
| `eraser_dense_50k` | `loaded_draw_mode_eraser_document_without_prior_erasure` | `eraser_removes_elements` | `eraser_dense` |

`comparison_summary.json` must be a JSON object with exactly these top-level
keys and no extra top-level keys:

```text
schemaVersion: 1
sourceManifest: "performance_run_manifest.json"
routeName: "flutter_performance"
commandFamily: "flutter drive --profile --no-dds"
scenarioGroups: array
```

Each comparison `scenarioGroups` entry must contain exactly `id` and `phases`.
Each phase entry must contain exactly `kind`, `name`, `repeatCount`, and
`metrics`. Each metric entry must contain exactly `summaryField`, `unit`,
`rawRepeats`, `median`, `min`, `max`, and `interquartileRange`. `summaryField`
must be one of these exact Flutter `TimelineSummary` numeric fields:
`average_frame_build_time_millis`, `worst_frame_build_time_millis`,
`average_frame_rasterizer_time_millis`, `worst_frame_rasterizer_time_millis`,
`frame_count`, `missed_frame_build_budget_count`, or
`missed_frame_rasterizer_budget_count`. `unit` must be `"millis"` for fields
ending in `_millis` and `"count"` for the other required fields. `rawRepeats`
must be an array of objects containing exactly `repeat` and `value`, one entry
per repeat validated by the manifest. Median, min, max, and interquartile range
must be derived from `rawRepeats` for the same `summaryField` with this exact
calculation rule:

1. Sort the numeric `rawRepeats[*].value` values ascending by `value`; repeat
   ids do not affect the calculation.
2. `min` is the first sorted value and `max` is the last sorted value.
3. `median` is the middle sorted value when `repeatCount` is odd, or the
   arithmetic mean of the two middle sorted values when `repeatCount` is even.
4. `q1` and `q3` use an exclusive median split. For odd `repeatCount > 1`,
   exclude the median value, then compute `q1` as the median of the lower half
   and `q3` as the median of the upper half. For even `repeatCount > 2`, split
   the sorted values into equal lower and upper halves, then compute each half's
   median with the same odd/even median rule.
5. For `repeatCount == 1`, `q1`, `q3`, `median`, `min`, and `max` all equal the
   single value and `interquartileRange` is `0`.
6. For `repeatCount == 2`, `q1` is the lower sorted value, `q3` is the upper
   sorted value, and `interquartileRange` is `q3 - q1`.
7. For every `repeatCount`, `interquartileRange` is exactly `q3 - q1`.

Both generated JSON files must reject keys named exactly `threshold`,
`thresholds`, `passFail`, `passed`, `failed`, `baseline`, `baselineId`,
`baselinePath`, `regression`, `regressionStatus`, `isRegression`,
`allowedDelta`, `budgetMillis`, or `verdict` at any nesting level.

Temporal Surface Closure: The route invariant is that each trace observes only
the selected phase action plus bounded settle from a declared pre-action state.
The synchronous callback surface is the action executed inside `traceAction`.
The phase descriptor runner owns the guard that runs canonical preparation
outside measured warm and steady traces. Public observation order is: setup
trace when required, untraced canonical preparation before warm, warm trace,
untraced canonical preparation before each steady repeat, and steady trace.
Missing reset/reseed semantics is a route/test/checker failure, not a production
runtime mutation behavior change.

All-Or-Nothing Failure Boundary: The irreversible boundary is publishing a
generated run directory after resetting previous `example/build/flutter_performance`
output. Fallible work before acceptance includes Flutter drive execution,
timeline conversion, timeline summary writing, manifest writing, and comparison
summary writing. Later checker failures project as a non-zero artifact check.
No generated run is release-acceptable unless every required raw artifact,
manifest, and comparison summary validates.

## Execution Units

### [ ] Unit 1: Documentation source-of-truth migration

Owner: `docs/verification/performance.md`,
`docs/verification/tests.md`, `docs/verification/release_gates.md`, and the
docs-catalog portion of `test/performance/flutter_performance_route_contract_test.dart`.

Boundary: Documentation and docs-catalog structural proof only. Do not change
route code, checker code, driver code, generated artifacts, or scenario
execution behavior in this unit.

Change: Rewrite `docs/verification/performance.md` so it owns the new scenario
group model, canonical phase grammar, exact report key grammar, exact five
steady repeats for redesigned groups, `repeat_001` policy for `setup`, `warm`,
and `single` phases, nested artifact shape, generated manifest and comparison
summary semantics, local before/after comparison semantics, unsupported claims,
retired benchmark boundary, exact `performance_run_manifest.json` and
`comparison_summary.json` JSON shapes from `Generated Artifacts`, and full
26-scenario migration. The seven redesigned groups must be exactly:
`load_document.100k` with `setup.fixture_json`, `warm.load_document`, and
`steady.load_document`; `first_canvas_frame.50k` with
`setup.preloaded_runtime`, `warm.first_canvas_frame`, and
`steady.first_canvas_frame`; `camera_pan.100k` with `setup.loaded_document`,
`warm.camera_pan`, and `steady.camera_pan`; `selection_move.50k` with
`setup.loaded_selected_document`, `warm.selection_move`, and
`steady.selection_move`; `marquee_select.50k` with `setup.loaded_document`,
`warm.marquee_select`, and `steady.marquee_select`; `json_export.50k` with
`setup.loaded_document`, `warm.json_export`, and `steady.json_export`;
`eraser_dense_50k` with `setup.loaded_draw_mode_document`,
`warm.eraser_dense`, and `steady.eraser_dense`. The other nineteen current
required scenarios must be listed as scenario groups with
`single.current_behavior` and `repeat_001`. Update `docs/verification/tests.md`
and `docs/verification/release_gates.md` so documented tests and release gates
match the new route without claiming numeric thresholds. Update the route
contract test only for docs-catalog parsing and source-of-truth grammar proof:
it must not yet require executable descriptor migration.

Completion Check: Documentation checks pass with
`dart run docs/tool/sync_generated_docs.dart --check` and
`dart run docs/tool/check_docs.dart`; `flutter test
test/performance/flutter_performance_route_contract_test.dart` passes with a
docs-catalog test proving the performance doc exposes all 26 scenario groups,
exactly the seven redesigned phase sets above, exactly five steady repeats for
redesigned groups, only `setup`, `warm`, `steady`, and `single` phase kinds,
the exact manifest and comparison-summary schema keys from `Generated
Artifacts`, and no numeric threshold, baseline, pass/fail, regression-status,
startup, or Macrobenchmark release claim.

Depends On: none.

### [ ] Unit 2: Executable descriptor and integration-route migration

Owner: `example/lib/perf/performance_scenario.dart`,
`example/integration_test/perf_canvas_surface_test.dart`, the descriptor/route
portion of `test/performance/flutter_performance_route_contract_test.dart`, and
focused `example/test` performance state tests.

Boundary: Example performance route code and its direct route/state proof only.
Do not change production `lib/**`, public APIs, artifact checker behavior,
docs, or driver output writing in this unit.

Change: First replace the one-scenario-one-report-key executable catalog with a
descriptor model that expands the documented 26 scenario groups into phase and
repeat report keys, before updating the integration runner to emit those phase
report keys. Report keys must be generated mechanically as
`<scenario_group>__<phase_kind>.<phase_name>__repeat_<NNN>` with three-digit
repeat numbers. The integration route must still delegate to a single traced
runner that calls Flutter `traceAction` for each report key and uses the
existing bounded settle helper after measured action. The seven redesigned
groups must run setup, warm, and exactly five steady repeats, but canonical
preparation/reset semantics must be implemented before `steady.*` repeats are
enabled. Preparation/reset must run outside measured warm and steady traces. The nineteen
non-redesigned groups must preserve current one-shot behavior under
`single.current_behavior` and `repeat_001`. Canonical preparation before warm
and every steady repeat is fixed as follows: `load_document.100k` starts from an
empty runtime/surface plus prepared JSON fixture because loading writes target
state; `first_canvas_frame.50k` starts from a fresh preloaded 50k runtime not
yet rendered by the measured surface because first-frame cost disappears after
render; `camera_pan.100k` starts from loaded 100k document, camera origin, and
settled surface because pan offset accumulates; `selection_move.50k` starts
from loaded 50k document with the same selected id and unchanged element
positions because move translates geometry; `marquee_select.50k` starts from
loaded 50k document, move mode, no inherited marquee selection, and settled
surface because marquee commit replaces selection; `json_export.50k` starts
from loaded 50k document with stable document order and no pending edit session
because reset keeps repeats comparable and detects accidental mutation;
`eraser_dense_50k` starts from loaded 50k document, draw mode with eraser
selected, and no erased elements from previous repeats because eraser commit
removes elements. Update route contract tests for executable descriptor
expansion, traced-runner ownership, report-key generation, public-import
boundary, and retired-route negative proof. Add a named example-only test seam
`PerformancePhasePreparationProbe` owned by `example/lib/perf/performance_scenario.dart`
and consumed only from focused `example/test` performance tests. The probe must
capture a `PerformancePhasePreparationSnapshot` immediately before the measured
action enters `traceAction`; the snapshot must contain `scenarioGroup`,
`phaseKey`, `repeat`, `canonicalPreparation`, `resetReason`,
`preparationMeasured`, `publicState` from `CanvasRuntime.state.value`,
`documentFingerprint` from `CanvasRuntime.readDocument()`,
`cameraOffset` from `CanvasRuntime.camera.offset`, `toolMode` and `drawTool`
from `CanvasRuntime.tools`, and `fixtureMetadata` supplied by the descriptor.
`documentFingerprint` must be exactly
`encodeCanvasDocumentToJson(CanvasRuntime.readDocument())`, using the public
package barrel API rather than a custom fingerprint algorithm.
The probe must use only the public package barrel and example route types, with
no `package:iwb_canvas_engine/src/**` imports and no production `lib/**`
changes. Focused example tests must run two steady repeats per redesigned group
and compare the snapshots before measured action begins. The expected equality
signal is: equal `canonicalPreparation`, equal `resetReason`,
`preparationMeasured == false`, equal `publicState.summary`, equal
`documentFingerprint`, equal group-relevant `cameraOffset`, `toolMode`, and
`drawTool`, and equal group-specific `fixtureMetadata`.

The required group-specific `fixtureMetadata` assertions are fixed:
`load_document.100k` has `preparedJsonElementCount: 100000`,
`targetElementCountBeforeAction: 0`, and `targetSelectedCountBeforeAction: 0`;
`first_canvas_frame.50k` has `loadedElementCount: 50000` and
`surfaceRenderState: "not_rendered_by_measured_surface"`;
`camera_pan.100k` has `loadedElementCount: 100000` and
`cameraOffsetBeforeAction: Offset.zero`; `selection_move.50k` has
`loadedElementCount: 50000`, `selectedElementId: "r0"`, and
`selectedElementGeometry: "original"`; `marquee_select.50k` has
`loadedElementCount: 50000`, `selectedCountBeforeAction: 0`, and
`toolModeBeforeAction: "move"`; `json_export.50k` has
`loadedElementCount: 50000`, `documentOrder: "stable"`, and
`pendingEditSession: false`; `eraser_dense_50k` has
`loadedElementCount: 50000`, `toolModeBeforeAction: "draw"`,
`drawToolBeforeAction: "eraser"`, and `erasedElementCountBeforeAction: 0`.

Completion Check: `test/performance/flutter_performance_route_contract_test.dart`
passes after proving descriptor expansion matches the docs catalog, every
report key matches the canonical grammar, unsupported phase kinds are absent,
the integration test delegates to the single phase/repeat traced runner,
`traceAction` owns report-key measurement, startup/Macrobenchmark route names
are absent, retired benchmark ids are absent, and no private engine imports or
production `lib/**` changes are required. Focused example tests pass after
proving setup/action separation for each redesigned group and proving two
steady repeats per redesigned group emit `PerformancePhasePreparationSnapshot`
values that match the equality and group-specific fixture-metadata signals
above before measured action begins.

Depends On: Unit 1.

### [ ] Unit 3: Official Flutter artifact writer and local summaries

Owner: `example/test_driver/perf_driver.dart` and the new focused writer test
`test/tool/flutter_performance_driver_writer_test.dart`.

Boundary: Driver-side generated output writing and its dedicated writer test
only. Do not change descriptor semantics, checker validation, docs,
route-contract tests, example scenario tests, or production runtime code in
this unit.

Change: Migrate driver output from flat scenario directories to the documented
nested group/phase/repeat shape under `example/build/flutter_performance/`.
Keep deleting/resetting the generated root before a new run. Convert each
`traceAction` report through `Timeline.fromJson` and
`TimelineSummary.summarize`, then write full timeline and timeline summary files
through Flutter's `TimelineSummary.writeTimelineToFile(...)` into the repeat
directory using the report key as the trace name. After raw repeat artifacts are
written, generate `performance_run_manifest.json` and `comparison_summary.json`
as local generated artifacts only. The manifest must match the exact
`performance_run_manifest.json` shape in `Generated Artifacts`, including
`route`, `unsupportedClaims`, `scenarioGroups`, `phases`, and `repeats`.
Every redesigned `warm.*` and `steady.*` manifest entry must include
`canonicalPreparation`, `resetReason`, `measuredAction`, and
`preparationMeasured: false`; `single.current_behavior` entries must not claim
steady-state reset semantics. The comparison summary must derive only from
official Flutter timeline summary JSON files and expose only the exact
`summaryField`, `unit`, `rawRepeats`, `median`, `min`, `max`, and
`interquartileRange` fields and exact median/IQR calculation rules defined in
`Generated Artifacts`; it must not
contain threshold, pass/fail, baseline, or regression-status fields.

Completion Check: `flutter test test/tool/flutter_performance_driver_writer_test.dart`
passes after exercising a representative in-memory or temporary-directory
driver response with at least one redesigned group containing two steady
repeats and one `single.current_behavior` group. The test proves the writer
creates nested group/phase/repeat directories, official raw timeline files,
official timeline summary files, `performance_run_manifest.json`, and
`comparison_summary.json` under the generated output root; proves both JSON
files have exactly the top-level keys and required nested keys defined in
`Generated Artifacts`; proves comparison summary values are derived from the raw
repeat timeline summaries for the exact required `summaryField` names; proves
redesigned warm/steady manifest entries contain the exact
`canonicalPreparation`, `resetReason`, `measuredAction`, and
`preparationMeasured: false` values required for their scenario group; and
proves forbidden threshold, pass/fail, baseline, and regression-status fields
are absent.

Depends On: Unit 2.

### [ ] Unit 4: Artifact checker enforcement

Owner: `tool/check_flutter_performance_artifacts.dart`,
`test/tool/flutter_performance_artifacts_checker_test.dart`, and final
release-route verification command documentation already updated by Unit 1.

Boundary: Artifact checking tool and its tests only. Do not change the route
descriptors, integration route, driver, docs, generated artifacts, or production
runtime code in this unit.

Change: Update the checker to parse the new docs source-of-truth catalog and
validate the generated nested output shape. It must validate scenario group
directories, phase directories, repeat directories, report key grammar, raw
timeline JSON shape, Flutter timeline summary shape, manifest shape,
comparison-summary shape, exact top-level keys and required nested keys for both
generated JSON files, exact comparison metric field names, exact repeat
cardinality, all 26 scenario groups, all seven redesigned phase sets, all
nineteen `single.current_behavior` migrations, unsupported phase names,
unexpected outputs, and forbidden threshold/pass-fail/baseline/regression-status
fields. It must reject missing manifest, missing comparison summary, extra root
files other than the two generated JSON files, malformed JSON, missing repeats,
duplicate/overwritten repeat keys, redesigned warm/steady manifest entries that
omit or mis-state `canonicalPreparation`, `resetReason`, `measuredAction`, or
`preparationMeasured: false`, and outputs that imply restored custom
benchmark-result schema.

Completion Check: `flutter test test/tool/flutter_performance_artifacts_checker_test.dart`
passes with positive fixtures for the complete nested catalog and negative
fixtures for missing repeats, malformed raw timeline, malformed timeline
summary, malformed manifest, malformed comparison summary, unsupported phase
names, unexpected outputs, incomplete full-catalog migration, and forbidden
threshold/pass-fail/baseline/regression-status fields, missing or extra
top-level and nested schema keys in both generated JSON files, unsupported
comparison metric field names, incorrect raw-repeat-derived `median`, `min`,
`max`, or `interquartileRange` values including `repeatCount` 1 and 2 cases, and
missing or incorrect canonical preparation/reset metadata for redesigned
warm/steady manifest entries. The checker command
`dart run tool/check_flutter_performance_artifacts.dart --catalog docs/verification/performance.md --results example/build/flutter_performance`
is listed as the post-drive validation command and succeeds against a generated
profile-drive run.

Depends On: Unit 1 and Unit 3.

## Final Verification

After the execution units are complete, the implementation change is accepted
only after these checks run from the repository root as applicable to changed
owners: `dart analyze`; `dcm analyze .`; scoped `dcm calculate-metrics` for
changed production, test, example, and tool owners; focused tests covering
`test/performance/flutter_performance_route_contract_test.dart`,
`test/tool/flutter_performance_driver_writer_test.dart`,
`test/tool/flutter_performance_artifacts_checker_test.dart`, and focused
`example/test` performance tests; docs checks
`dart run docs/tool/sync_generated_docs.dart --check` and
`dart run docs/tool/check_docs.dart`; the profile-drive command
`cd example && flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/perf_canvas_surface_test.dart --profile --no-dds`;
and the artifact checker command
`dart run tool/check_flutter_performance_artifacts.dart --catalog docs/verification/performance.md --results example/build/flutter_performance`.
The final diff contains no checked-in `example/build/flutter_performance/**`
artifacts, no startup/Macrobenchmark route, no `tool/bench/**`, no
`test/benchmarks/**`, no retired benchmark ids, and no custom benchmark-result
schema.
