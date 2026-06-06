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
Feeds phases:
- `P14`
Related donors:
- `direct_scan_resistant_cache`
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
- no unapproved legacy feature path regression
<!-- CONTEXT:END -->

## 24. Benchmarks

Benchmark policy:

The structured source of truth for section 24 benchmark cases, scales,
measurement boundaries, fixture shapes, metrics, numeric budget classes,
exact invariants, and profile membership is
`docs/_registry/benchmarks.yaml`. This section is a checked human projection of
that manifest.

<!-- BENCHMARK-MANIFEST-FINGERPRINT: cb283b7a -->

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
| `load_document.success` | 1k/10k/50k/100k | lifecycle | normal_spread | avg/P95/max, rebuild cost, alloc bytes |
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
- Manual device baselines for optimization work live under
  `tool/bench/baselines/manual/`. They are committed comparison anchors for a
  named local device and toolchain, not release-approval baselines.
- The Pixel 6 Android 16 baseline is
  `tool/bench/baselines/manual/pixel6_android16_flutter_3_44_0.json`.
- To refresh the current Pixel 6 report, run
  `dart run tool/bench/run.dart --profile=release --device=23081FDF6000L2 --output=build/bench/current/pixel6_release.json`.
- To compare a new Pixel 6 report against the committed manual baseline, run
  `dart run tool/bench/diff.dart --profile=release --baseline=tool/bench/baselines/manual/pixel6_android16_flutter_3_44_0.json --current=build/bench/current/pixel6_release.json --output=build/bench/diff/pixel6_release.json`.
- Manual device-baseline diff is for regression tracking during optimization;
  it must preserve same-contour runtime metadata, including `deviceId`, but it
  does not replace the approved Ubuntu release baseline or release workflow.

Benchmark CI routing:

- Root PR CI runs the deterministic benchmark machinery checks first: manifest
  tests, required-case dry-run proof, diff fixtures, benchmark runner proof, and
  docs projection checks. It then runs all non-benchmark Flutter tests with
  `flutter test --concurrency=1`, followed by `dart analyze` and guardrails.
- Release benchmark CI runs on `ubuntu-24.04` with Flutter `3.38.0` stable,
  writes the current release report, runs the read-only release diff, and then
  blocks on P14 graph, generated-view, and guardrail checks.
- Manual baseline update is a separate `workflow_dispatch` route that writes a
  candidate under `build/bench/candidates/`, runs `update_baseline`, and uploads
  the accepted baseline artifact without auto-committing it.
