<!-- CONTEXT:BEGIN -->
Registry id: `section_24_performance_verification`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/performance.md`
Owns:
- 24. Performance verification
Must read before editing:
- `section_23_tests` -> `docs/verification/tests.md`
- `section_27_final_release_gates` -> `docs/verification/release_gates.md`
Current owners:
- `test`
- `release`
Related diagrams:
- `none`
Required tests:
- `test.performance.flutter_route_contract`
- `test.example.performance_host_smoke`
- `test.example.performance_fixture_limits`
- `test.example.performance_profile_drive_artifacts`
Guardrails:
- `none`
Do not assume:
- no numeric performance threshold gate
- no private example route imports
- no restored benchmark route
<!-- CONTEXT:END -->

## 24. Performance verification

This document owns the official Flutter performance verification route. The
route is a release-blocking completion and artifact-production gate for the
Flutter scenario group catalog. It does not define numeric performance
pass/fail thresholds.

Vector admission adds no benchmark id or custom performance schema. Its
record-local Picture paint and shared resource-cache behavior are covered by
owner-focused correctness probes; cache capacities and byte accounting remain
solely in the cache-policy ledger.

The route runs the example app as an external public consumer through
`integration_test` and `flutter drive --profile --no-dds`. Route code must use
`package:iwb_canvas_engine/iwb_canvas_engine.dart` and must not import
`package:iwb_canvas_engine/src/**`.

## Release command

Run the profile route from the repository root with:

```bash
cd example && flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/perf_canvas_surface_test.dart --profile --no-dds
```

Then validate the generated route artifacts from the repository root with:

```bash
dart run tool/check_flutter_performance_artifacts.dart --results example/build/flutter_performance
```

These commands must complete every required report key derived from the
catalog. A non-zero exit, crash, hang, missing report, missing artifact, stale
preview or overlay completion failure, or malformed artifact is a route failure.

## Scenario group model

The catalog is organized by scenario group. Each group expands into one or more
phase report keys. A report key must use this exact grammar:

```text
<scenario_group>__<phase_kind>.<phase_name>__repeat_<NNN>
```

`phase_kind` must be exactly one of `setup`, `warm`, `steady`, or `single`.
`repeat_<NNN>` is a three-digit repeat id. `setup.*`, `warm.*`, and
`single.*` phases use exactly `repeat_001`. `steady.*` phases for redesigned
groups use exactly five repeats: `repeat_001`, `repeat_002`, `repeat_003`,
`repeat_004`, and `repeat_005`.

`setup.*` phases describe fixture or document preparation context. `warm.*`
phases measure the first action from canonical prepared state. `steady.*`
phases measure repeated action cost from the same canonical prepared state,
with reset/reseed cost outside the measured trace. `single.current_behavior`
preserves the current one-shot behavior for groups that are not redesigned in
this route.

The catalog excludes startup scenarios from the Flutter gate; startup
performance is future Android Macrobenchmark scope.

## Scenario group catalog

| Scenario group | Migration | Phase key | Repeats |
|---|---|---|---|
| `load_document.1k` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `load_document.10k` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `load_document.50k` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `load_document.100k` | `redesigned` | `setup.fixture_json` | `repeat_001` |
| `load_document.100k` | `redesigned` | `warm.load_document` | `repeat_001` |
| `load_document.100k` | `redesigned` | `steady.load_document` | `repeat_001`, `repeat_002`, `repeat_003`, `repeat_004`, `repeat_005` |
| `first_canvas_frame.50k` | `redesigned` | `setup.preloaded_runtime` | `repeat_001` |
| `first_canvas_frame.50k` | `redesigned` | `warm.first_canvas_frame` | `repeat_001` |
| `first_canvas_frame.50k` | `redesigned` | `steady.first_canvas_frame` | `repeat_001`, `repeat_002`, `repeat_003`, `repeat_004`, `repeat_005` |
| `camera_pan.50k` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `camera_pan.100k` | `redesigned` | `setup.loaded_document` | `repeat_001` |
| `camera_pan.100k` | `redesigned` | `warm.camera_pan` | `repeat_001` |
| `camera_pan.100k` | `redesigned` | `steady.camera_pan` | `repeat_001`, `repeat_002`, `repeat_003`, `repeat_004`, `repeat_005` |
| `selection_tap.10k` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `selection_move.10k` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `selection_move.50k` | `redesigned` | `setup.loaded_selected_document` | `repeat_001` |
| `selection_move.50k` | `redesigned` | `warm.selection_move` | `repeat_001` |
| `selection_move.50k` | `redesigned` | `steady.selection_move` | `repeat_001`, `repeat_002`, `repeat_003`, `repeat_004`, `repeat_005` |
| `marquee_select.50k` | `redesigned` | `setup.loaded_document` | `repeat_001` |
| `marquee_select.50k` | `redesigned` | `warm.marquee_select` | `repeat_001` |
| `marquee_select.50k` | `redesigned` | `steady.marquee_select` | `repeat_001`, `repeat_002`, `repeat_003`, `repeat_004`, `repeat_005` |
| `pencil_draw.10k` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `marker_draw.10k` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `line_two_tap.50k` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `eraser_normal.50k` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `eraser_dense_50k` | `redesigned` | `setup.loaded_draw_mode_document` | `repeat_001` |
| `eraser_dense_50k` | `redesigned` | `warm.eraser_dense` | `repeat_001` |
| `eraser_dense_50k` | `redesigned` | `steady.eraser_dense` | `repeat_001`, `repeat_002`, `repeat_003`, `repeat_004`, `repeat_005` |
| `context_delete.10k` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `text_edit.open_commit` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `text_style_change.10k` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `resource_image_cold` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `resource_image_warm` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `resource_mark_dirty` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `missing_resource` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `surface_runtime_swap` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `dispose_during_preview` | `single.current_behavior` | `single.current_behavior` | `repeat_001` |
| `json_export.50k` | `redesigned` | `setup.loaded_document` | `repeat_001` |
| `json_export.50k` | `redesigned` | `warm.json_export` | `repeat_001` |
| `json_export.50k` | `redesigned` | `steady.json_export` | `repeat_001`, `repeat_002`, `repeat_003`, `repeat_004`, `repeat_005` |

The `load_document.100k` and `camera_pan.100k` groups are catalog requirements
only for exact fixtures that fit the current validation limits. Do not expand
validation limits or claim generic 100k raw JSON readiness from this route.

## Canonical redesigned actions

Warm and steady repeats for redesigned groups must start from the same
canonical prepared state. Preparation and reset are outside the measured warm
and steady traces.

| Scenario group | canonicalPreparation | resetReason | measuredAction |
|---|---|---|---|
| `load_document.100k` | `empty_runtime_with_prepared_json_fixture` | `load_writes_document_state` | `load_document` |
| `first_canvas_frame.50k` | `preloaded_runtime_not_rendered_by_measured_surface` | `first_frame_cost_disappears_after_render` | `first_canvas_frame` |
| `camera_pan.100k` | `loaded_document_camera_origin_settled_surface` | `pan_accumulates_camera_offset` | `camera_pan` |
| `selection_move.50k` | `loaded_selected_document_original_geometry` | `move_translates_selected_geometry` | `selection_move` |
| `marquee_select.50k` | `loaded_document_move_mode_no_selection_settled_surface` | `marquee_commit_replaces_selection` | `marquee_select` |
| `json_export.50k` | `loaded_document_stable_order_no_pending_edit` | `export_reset_keeps_repeats_comparable` | `json_export` |
| `eraser_dense_50k` | `loaded_draw_mode_eraser_document_without_prior_erasure` | `eraser_removes_elements` | `eraser_dense` |

## Artifact contract

Profile-drive outputs live under `example/build/flutter_performance/`. Generated
artifacts are local build output and are not checked in. A successful run
produces:

```text
example/build/flutter_performance/performance_run_manifest.json
example/build/flutter_performance/comparison_summary.json
example/build/flutter_performance/<scenario_group>/<phase_kind>.<phase_name>/<repeat_NNN>/<report_key>.timeline_summary.json
example/build/flutter_performance/<scenario_group>/<phase_kind>.<phase_name>/<repeat_NNN>/<report_key>.timeline.json
```

The driver writes timeline files from Flutter timeline data through
`TimelineSummary.writeTimelineToFile(...)`. The route must not introduce a
custom timing collector or a checked-in artifact location.

## Manifest schema

`performance_run_manifest.json` is a local generated summary over official
Flutter outputs. It must contain exactly these top-level keys:
`schemaVersion`, `route`, `unsupportedClaims`, and `scenarioGroups`.

`schemaVersion` must be `1`.
`route` must contain exactly `name`, `commandFamily`, `driver`, and `target`.
Their values are fixed to `flutter_performance`,
`flutter drive --profile --no-dds`, `test_driver/perf_driver.dart`, and
`integration_test/perf_canvas_surface_test.dart`.

`unsupportedClaims` must contain exactly `numericThresholds`,
`passFailPerformance`, `baselines`, `regressionStatusClaims`, `cpuAttribution`,
`startup`, and `androidMacrobenchmark`, all set to `false`.

Each manifest `scenarioGroups` entry must contain exactly `id`, `migration`,
and `phases`. `migration` must be either `redesigned` or
`single.current_behavior`. Each phase entry must contain exactly `kind`, `name`,
`comparisonRole`, and `repeats`. `comparisonRole` must be exactly one of
`setup_context`, `first_use_action`, `steady_action`, or `current_behavior`.

Each repeat entry must contain exactly `repeat`, `reportKey`,
`artifactDirectory`, `timelineFile`, and `timelineSummaryFile`. Redesigned
`warm.*` and `steady.*` repeat entries must also contain exactly
`canonicalPreparation`, `resetReason`, `measuredAction`, and
`preparationMeasured: false`. `single.current_behavior` entries must not
contain `canonicalPreparation`, `resetReason`, or `measuredAction`.

## Comparison summary schema

`comparison_summary.json` is a local generated comparison aid over the raw
repeat summaries. It must contain exactly these top-level keys:
`schemaVersion`, `sourceManifest`, `routeName`, `commandFamily`, and
`scenarioGroups`.

`schemaVersion` must be `1`.
`sourceManifest` must be `performance_run_manifest.json`. `routeName` must be
`flutter_performance`. `commandFamily` must be
`flutter drive --profile --no-dds`.

Each comparison `scenarioGroups` entry must contain exactly `id` and `phases`.
Each phase entry must contain exactly `kind`, `name`, `repeatCount`, and
`metrics`. Each metric entry must contain exactly `summaryField`, `unit`,
`rawRepeats`, `median`, `min`, `max`, and `interquartileRange`.

`summaryField` must be one of these exact Flutter `TimelineSummary` numeric
fields:

```text
average_frame_build_time_millis
worst_frame_build_time_millis
average_frame_rasterizer_time_millis
worst_frame_rasterizer_time_millis
frame_count
missed_frame_build_budget_count
missed_frame_rasterizer_budget_count
```

`unit` must be `millis` for fields ending in `_millis` and `count` for the
other fields. `rawRepeats` contains one object per repeat, and each object must
contain exactly `repeat` and `value`.

Median, minimum, maximum, and interquartile range are derived only from
`rawRepeats` for the same `summaryField`:

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

Generated JSON files must reject keys named exactly `threshold`, `thresholds`,
`passFail`, `passed`, `failed`, `baseline`, `baselineId`, `baselinePath`,
`regression`, `regressionStatus`, `isRegression`, `allowedDelta`,
`budgetMillis`, or `verdict` at any nesting level.

## Local comparison semantics

The generated comparison summary supports local before/after inspection only.
Compare runs only when they use the same scenario group, phase, repeat count,
route command, and local environment notes. Median and spread values summarize
the raw repeat outputs from that local run; they are not device-independent
precision claims and are not release thresholds.

## Gate semantics

The release gate verifies route completion and required artifact production
only. It does not claim p95, p99, frame-budget, baseline-diff, regression
threshold, custom baseline, or manual-history pass/fail policy. Those policies
require a later design and contract that define device, environment,
artifact-retention, and baseline rules. The required catalog repeat counts
above are completion and artifact-integrity obligations, not numeric
performance threshold policy.

## Retired benchmark boundary

The former benchmark route remains retired. Do not restore the benchmark
registry, benchmark index, benchmark verification document, `tool/bench/**`,
`test/benchmarks/**`, internal benchmark case ids, or a custom benchmark-result
schema as part of this route.
