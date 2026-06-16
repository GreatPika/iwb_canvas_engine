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
Flutter scenario catalog. It does not define numeric performance pass/fail
thresholds.

The route runs the example app as an external public consumer through
`integration_test` and `flutter drive --profile`. Route code must use
`package:iwb_canvas_engine/iwb_canvas_engine.dart` and must not import
`package:iwb_canvas_engine/src/**`.

## Release command

Run the profile route from the repository root with:

```bash
cd example && flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/perf_canvas_surface_test.dart --profile --no-dds
```

The command must complete every scenario in the catalog. A non-zero exit,
crash, hang, missing scenario report, missing artifact, stale preview or
overlay completion failure, or malformed artifact is a route failure.

## Scenario catalog

Every scenario id below is also the required integration-test report key. The
catalog excludes startup scenarios from the Flutter gate; startup performance is
future Android Macrobenchmark scope.

| Scenario id | Release gate status |
|---|---|
| `load_document.1k` | required |
| `load_document.10k` | required |
| `load_document.50k` | required |
| `load_document.100k` | required with current-limit fixture proof |
| `first_canvas_frame.50k` | required |
| `camera_pan.50k` | required |
| `camera_pan.100k` | required with current-limit fixture proof |
| `selection_tap.10k` | required |
| `selection_move.10k` | required |
| `selection_move.50k` | required |
| `marquee_select.50k` | required |
| `pencil_draw.10k` | required |
| `marker_draw.10k` | required |
| `line_two_tap.50k` | required |
| `eraser_normal.50k` | required |
| `eraser_dense_50k` | required |
| `context_delete.10k` | required |
| `text_edit.open_commit` | required |
| `text_style_change.10k` | required |
| `resource_image_cold` | required |
| `resource_image_warm` | required |
| `resource_mark_dirty` | required |
| `missing_resource` | required |
| `surface_runtime_swap` | required |
| `dispose_during_preview` | required |
| `json_export.50k` | required |

The `load_document.100k` and `camera_pan.100k` scenarios are catalog
requirements only for exact fixtures that fit the current validation limits.
Do not expand validation limits or claim generic 100k raw JSON readiness from
this route.

## Artifact contract

Profile-drive outputs live under `example/build/flutter_performance/`. Each
scenario id owns exactly one directory named after the scenario id:

```text
example/build/flutter_performance/<scenario_id>/
```

Each scenario directory must contain the two required Flutter timeline files:

```text
example/build/flutter_performance/<scenario_id>/<scenario_id>.timeline_summary.json
example/build/flutter_performance/<scenario_id>/<scenario_id>.timeline.json
```

The driver writes those files through
`TimelineSummary.writeTimelineToFile(scenario.id, destinationDirectory: scenarioDirectory, includeSummary: true)`.
The route does not introduce a checked-in artifact location.

## Gate semantics

The release gate verifies route completion and required artifact production
only. It does not claim p95, p99, frame-budget, baseline-diff, regression
threshold, custom baseline, repeat-count, or manual-history pass/fail policy.
Those policies require a later design and contract that define device,
environment, repeat-count, artifact-retention, and baseline rules.

## Retired benchmark boundary

The former benchmark route remains retired. Do not restore the benchmark
registry, benchmark index, benchmark verification document, `tool/bench/**`,
`test/benchmarks/**`, internal benchmark case ids, or a custom benchmark-result
schema as part of this route.
