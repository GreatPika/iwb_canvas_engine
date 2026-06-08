<!-- CONTEXT:BEGIN -->
Registry id: `section_24_benchmarks`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/benchmarks.md`
Owns:
- 24. Benchmarks
Must read before editing:
- `section_15_frame_render_contract` -> `docs/contracts/frame_rendering.md`
- `section_17_spatial_kernel` -> `docs/contracts/spatial_kernel.md`
- `section_18_cache_policy` -> `docs/contracts/cache_policy.md`
Current owners:
- `benchmark`
Benchmarks:
- `edit.add_element`
- `edit.update_visual`
- `edit.update_transform`
- `edit.move_selection`
- `edit.set_camera_offset`
- `edit.add_line`
- `input.selected_move_preview`
- `frame.selected_move_preview_cached_ordinary_plan`
- `input.marquee_preview`
- `input.draw_preview`
- `input.line_preview`
- `input.eraser_preview`
- `input.eraser_budget_exceeded`
- `frame.main_capture`
- `frame.overlay_capture`
- `frame.paint_candidates`
- `resources.resolve_sync`
- `resources.resolve_sync_cold_budget`
- `resources.mark_dirty`
- `resources.mark_all_dirty`
- `projection.read_document`
- `codec.decode_v1`
- `load_document.success`
- `load_document.breakdown`
- `load_document.failure`
- `spatial.query_point`
- `spatial.query_point_dense_stress`
- `spatial.touched_update`
- `runtime.dispose_during_gesture`
- `diagnostics.disabled_pointer`
Related diagrams:
- `none`
Required tests:
- `test.benchmarks.benchmark_manifest`
- `test.benchmarks.benchmark_diff`
- `test.benchmarks.benchmark_runner`
- `test.guardrails.release_readiness`
- `test.benchmarks.required_cases`
Guardrails:
- `release.benchmark_readiness`
Do not assume:
- no unapproved retired feature route regression
<!-- CONTEXT:END -->

## 24. Benchmarks

Benchmark policy:

The structured source of truth for section 24 benchmark cases, scales,
measurement boundaries, fixture shapes, metrics, numeric budget classes,
exact invariants, and profile membership is
`docs/_registry/benchmarks.yaml`. This section is a checked human projection of
that manifest.

<!-- BENCHMARK-MANIFEST-FINGERPRINT: 2e4b020c -->

Required benchmark cases:

| Case | Nodes | Boundary | Fixture | Metrics |
|---|---:|---|---|---|
| `edit.add_element` | 1k/10k/50k/100k | action_only | normal_spread | avg/P95/max us, alloc bytes |
| `edit.update_visual` | 1k/10k/50k/100k | action_only | normal_spread | avg/P95/max us, touched count |
| `edit.update_transform` | 1k/10k/50k/100k | action_only | normal_spread | spatial touched pages, alloc bytes |
| `edit.move_selection` | 1k/10k/50k | action_only | normal_spread | selected count, avg/P95/max |
| `edit.set_camera_offset` | 1k/10k/50k/100k | action_only | normal_spread | avg/P95/max us, ordinary paint-plan invalidations = 0 |
| `edit.add_line` | 1k/10k/50k | action_only | normal_spread | avg/P95/max us, alloc bytes |
| `input.selected_move_preview` | 1k/10k/50k | action_only | normal_spread | scene repaint count, avg/max |
| `frame.selected_move_preview_cached_ordinary_plan` | 1k/10k/50k | action_only | normal_spread | ordinary plan hit rate, supplement count, no cached previewDelta |
| `input.marquee_preview` | 1k/10k/50k | action_only | normal_spread | overlay repaint count, avg/max |
| `input.draw_preview` | 1k/10k | action_only | normal_spread | point count, avg/max |
| `input.line_preview` | 1k/10k/50k | action_only | normal_spread | overlay repaint count, avg/max |
| `input.eraser_preview` | 1k/10k/50k | action_only | normal_spread | candidate count, exact checks |
| `input.eraser_budget_exceeded` | dense 50k | action_only | dense_stress | budget-exceeded count, partial erase count = 0 |
| `frame.main_capture` | 1k/10k/50k/100k | action_only | normal_spread | avg/P95/max, alloc bytes |
| `frame.overlay_capture` | active previews | action_only | active_preview | avg/P95/max, alloc bytes |
| `frame.paint_candidates` | 1k/10k/50k/100k | action_only | normal_spread | candidate count, offscreen-layer/saveLayer count |
| `resources.resolve_sync` | 1k resources | action_only | resource_set | SurfaceResourceSession resolver calls, session cache hits, repaint count |
| `resources.resolve_sync_cold_budget` | 1k uncached image records | action_only | resource_set | session budget resolver calls <= 128, budget placeholders, throttled repaint count |
| `resources.mark_dirty` | 1k resources | action_only | resource_set | repaint count, target session cache invalidation cost |
| `resources.mark_all_dirty` | 1k resources | action_only | resource_set | repaint count, all-entry session cache invalidation cost |
| `projection.read_document` | 1k/10k/50k/100k | projection_split | normal_spread | first read/cache hit |
| `codec.decode_v1` | all fixtures | lifecycle | codec_fixture | avg/P95/max, error payload |
| `load_document.success` | 1k/10k/50k | action_only | normal_spread | avg/P95/max schema import load, rebuild cost, alloc bytes |
| `load_document.breakdown` | 1k/10k/50k | lifecycle | codec_fixture | decode diagnostic, runtime construct, public schema import load, first projection us |
| `load_document.failure` | invalid 1k/10k/50k inputs | lifecycle | invalid_document | avg/P95/max, committed mutation count = 0 |
| `spatial.query_point` | 1k/10k/50k/100k | action_only | normal_spread | tile count, fallback count |
| `spatial.query_point_dense_stress` | dense 50k | action_only | dense_stress | dense fallback count |
| `spatial.touched_update` | 1k/10k/50k | action_only | normal_spread | rebuilt ids/pages |
| `runtime.dispose_during_gesture` | active selected/overlay previews | action_only | active_preview | avg/P95/max, resolver calls = 0, action events = 0 |
| `diagnostics.disabled_pointer` | hot pointer | action_only | hot_pointer | allocations = 0 records |

---

Release benchmark interpretation:

- Current release reports are transient under `build/bench/current/`.
- Diff reports are transient under `build/bench/diff/`.
- The approved release baseline path is
  `tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json`.
- Until a pinned release/manual update accepts real measurements, that path may
  contain only an uninitialized fail-closed placeholder and release diff must
  fail rather than infer baseline numbers.
- `dart run tool/bench/diff.dart --profile=release --baseline=tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json --current=build/bench/current/release_ubuntu_24_04_flutter_3_38_0.json --output=build/bench/diff/release_ubuntu_24_04_flutter_3_38_0.json`
  is read-only with respect to approved baselines.
- `dart run tool/bench/update_baseline.dart --profile=release --candidate=build/bench/candidates/release_ubuntu_24_04_flutter_3_38_0/<timestamp>.json --approved=tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json`
  is the manual approved-baseline write path after first-baseline acceptance.
- Manual device reference reports for optimization work live under
  `tool/bench/manual/reference_reports/`. They are accepted comparison inputs for
  a named local device and toolchain, not release-approval baselines.
- Runtime-based prepared fixtures may report `spatial_rebuild_setup_us` in
  setup metrics. That diagnostic keeps the lazy spatial-index rebuild displaced
  by document load visible without charging steady-state frame/spatial action
  samples.
- Manual reference decisions are recorded in
  `tool/bench/manual/reference_decisions.json`. A reference report is valid only
  when that decision log says which history run or run window produced it.
- The Xiaomi 22081283G Android 14 Flutter 3.44.0 manual reference report is
  `tool/bench/manual/reference_reports/xiaomi_22081283g_android14_flutter_3_44_0.json`.
- Refresh a device report with
  `dart run tool/bench/run.dart --profile=release --device=<device-id> --output=build/bench/current/<device>_release.json`.
- Record that report in manual run history with
  `dart run tool/bench/archive_manual_run.dart --label=<reason> --report=build/bench/current/<device>_release.json --device-name="<device name>" --device-id=<device-id> --device-os="<os>" --reference=tool/bench/manual/reference_reports/<device>_<os>_flutter_<version>.json`.
- Accept a manual reference report from history with
  `dart run tool/bench/accept_manual_reference.dart --policy=stable_window_median_v1 --run=<history-run-1> --run=<history-run-2> --run=<history-run-3> --output=tool/bench/manual/reference_reports/<device>_<os>_flutter_<version>.json --reason="<why this run window is accepted>"`.
- `stable_window_median_v1` requires at least three compatible history runs and
  writes median numeric metrics across that run window. Use
  `bootstrap_single_run_v1` only for initial device setup when no stable window
  exists yet; it must say that in `--reason`.
- Compare a new device report with its committed manual reference report with
  `dart run tool/bench/diff.dart --profile=release --baseline=tool/bench/manual/reference_reports/<device>_<os>_flutter_<version>.json --current=build/bench/current/<device>_release.json --output=build/bench/diff/<device>_release.json`.
- Manual device-reference diff is for regression tracking during optimization;
  it must preserve same-contour runtime metadata, including `deviceId`, but it
  does not replace the approved Ubuntu release baseline or release workflow.

Manual benchmark history ledger:

- Local files under `build/bench/**` are temporary working files and must not be
  treated as the historical record.
- Accepted manual benchmark observations live under
  `tool/bench/manual/run_history/` and are indexed by
  `tool/bench/manual/run_history/index.json`.
- History records are committed decision traces: they store the run label,
  recorded UTC time, subject git head, dirty flag, device identity, toolchain
  contour, reference report path, source file paths, source size, source SHA-256,
  metrics, and compact sample summaries.
- History records do not replace manual reference reports. Reference reports
  under `tool/bench/manual/reference_reports/` are the accepted comparison
  inputs; history records explain which local observations supported an
  optimization or regression decision.
- Archive a full manual device report with
  `dart run tool/bench/archive_manual_run.dart --label=<reason> --report=build/bench/current/<device>_release.json --device-name="<device name>" --device-id=<device-id> --device-os="<os>" --reference=tool/bench/manual/reference_reports/<device>_<os>_flutter_<version>.json`.
- Archive focused single-case probe logs with
  `dart run tool/bench/archive_manual_run.dart --label=<reason> --probe-log=build/bench/current/<probe>.log --probe-log=build/bench/current/<probe-rerun>.log --device-name="<device name>" --device-id=<device-id> --device-os="<os>" --reference=tool/bench/manual/reference_reports/<device>_<os>_flutter_<version>.json`.
- To write history automatically after a benchmark run, pass
  `--history-label=<reason>` to `tool/bench/run.dart`. Optional history fields
  are `--history-device-name`, `--history-device-id`, `--history-device-os`,
  `--history-reference`, `--history-root`, and `--history-output`.
  `--history-baseline` remains accepted only as a compatibility alias for older
  local commands.
- History records and manual reference reports must not store raw
  `actionUsSamples` or `setupUsSamples` arrays. Store `sampleSummary` instead:
  `count`, `min_us`, `avg_us`, `p50_us`, `p95_us`, and `max_us`.
- Pass `--subject-git-head=<sha>` when archiving an already-completed run whose
  measured code commit is not the current `HEAD`.
- Pass `--allow-dirty` only when the history intentionally records that the
  working tree was dirty at archive time. Prefer archiving from a clean tree
  after the measured code is committed.
- Pass `--overwrite` only to repair a malformed history record for the same
  run; do not overwrite history to hide a changed measurement.

Benchmark CI routing:

- Root PR CI runs the deterministic benchmark machinery checks first: manifest
  tests, required-case dry-run proof, diff fixtures, benchmark runner proof, and
  docs projection checks. It then runs all non-benchmark Flutter tests with
  `flutter test --concurrency=1`, followed by `dart analyze` and guardrails.
- Release benchmark CI runs on `ubuntu-24.04` with Flutter `3.38.0` stable,
  writes the current release report, runs the read-only release diff, and then
  blocks on current graph closure, generated-view, and guardrail checks.
- Release baseline update is a separate `workflow_dispatch` route that writes a
  candidate under `build/bench/candidates/`, runs `update_baseline`, and uploads
  the accepted release-baseline artifact without auto-committing it.
