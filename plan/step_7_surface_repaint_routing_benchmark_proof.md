# Change Contract

## Goal

Add a focused benchmark proof that exercises the real Flutter `CanvasSurface`
path before the layer-aware repaint-routing implementation begins. The new
proof must make Xiaomi/manual benchmark reports show whether overlay-only
surface updates still touch the main delegate route and whether main-only
selected-move updates still touch the overlay delegate route, without adding
production benchmark hooks or changing `CanvasSurface` behavior.

## Source Inputs

- Design: `.design/2026-06-13-layer-aware-surface-repaint-routing.md`
- Research: `.research/2026-06-13-frame-repaint-signal-surface-usage.md`; `.research/2026-06-13-canvas-surface-widget-proof-seams.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: User requirement on 2026-06-13 to improve the benchmark before implementing the repaint-routing design; `docs/README.md`; `docs/_registry/benchmarks.yaml`; `docs/verification/benchmarks.md`; `test/benchmarks/benchmark_probe_flutter.dart`; `tool/bench/src/benchmark_manifest.dart`; `tool/bench/src/benchmark_runner.dart`; `tool/bench/src/benchmark_diff.dart`; `tool/bench/manual/reference_decisions.json`

## Classification

Profile: BEHAVIOR_CHANGE, verification scaffold only.

Obligations: BUG_FIX; SEAM_MIGRATION; Benchmark Source-Of-Truth Update; Negative Proof And Fixture Quarantine; Completion Evidence Boundary. This step inherits the design's performance-proof obligation but intentionally excludes the production repaint-routing implementation.

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Runtime/surface must expose a pre-output `CanvasRuntimeSurfaceFrame` with `CanvasSurfaceRepaintTarget`; `FrameRepaintSignal` stays frame-owned output metadata. | `Out of Scope`; `Compatibility`; future implementation constraint | Step 7 does not implement or redesign this seam; `Unit 2` only records current real-surface route metrics that the future D1 implementation must improve. |
| `D2` RuntimeRoot owns repaint target aggregation and InteractionEngine owns preview target meaning. | `Out of Scope`; `Compatibility`; future implementation constraint | Step 7 does not move repaint policy into benchmark or surface code; `Unit 2` uses existing runtime preview actions only to generate observable benchmark scenarios. |
| `D3` Surface owns transient Flutter lifecycle and output-cache proof, not frame planning or repaint policy meaning. | `Boundaries.Owner`; `Out of Scope`; `Unit 2` | Surface benchmark harness pumps public `CanvasSurface` and reads existing `CustomPaint` delegates; no production hooks or bridge counters are added. |
| `D4` Main and overlay must migrate to separate Flutter paint layers with separate repaint listenables in the future implementation. | `Out of Scope`; `In Scope`; `Unit 1`; `Unit 2` | Step 7 does not perform the paint-host/listenable migration; it records the current delegate-route contour through `surface.overlay_preview_route` and `surface.selected_move_route` counters so the future D4 implementation has a baseline. |
| `D5` Local surface inputs have explicit layer invalidation mapping separate from runtime repaint intent. | `Out of Scope`; future implementation constraint | Step 7 does not classify resolver, budget-follow-up, layout, style, or DPR invalidation; it limits benchmark scenarios to existing preview routes before local-input routing is implemented. |
| `D6` Unknown or unclassified runtime changes conservatively rebuild both layers until narrowed by source-of-truth evidence. | `Compatibility`; `Out of Scope` | Step 7 must not tighten production routing or require zero counters before the implementation contract narrows targets. |
| `D7` Source-of-truth updates must make the frame-output signal vs runtime/surface pre-output invalidation split durable. | `Out of Scope`; `Unit 3` | Step 7 updates only benchmark source-of-truth; production architecture/docs source-of-truth updates remain required in the future repaint-routing implementation contract. |
| Design Outcome-Proof Fit says widget screenshots or frame-level signals are proxy-risky for layer routing. | `Completion Check`; `Unit 2` | Probe must observe the real keyed `CanvasSurface` `CustomPaint` delegates across pumps, not only `FrameEngine` output tests or direct painter `PictureRecorder` tests. |
| Current benchmark manifest is the benchmark source of truth. | `Source of Truth`; `Unit 1`; `Unit 3` | `docs/_registry/benchmarks.yaml`, parser boundary table, manifest inventory tests, docs projection, and section registry are updated together. |
| Current Xiaomi reference is a manual `flutter_test` device contour accepted from three clean runs. | `Compatibility`; `Unit 4` | Expanded-manifest Xiaomi baseline is captured through the existing manual history/reference flow after the new cases are executable. |
| Current code must pass before the repaint-routing implementation, so unaffected-layer counts cannot yet be hard-coded to zero. | `Compatibility`; `Unit 1`; `Unit 4` | New exact invariants allow current baseline values and disallow positive drift after the accepted reference; zero expectations are out of scope until the routing implementation step. |

## Evidence

- `.design/2026-06-13-layer-aware-surface-repaint-routing.md:17` / `design`: selected architecture requires overlay-only changes to avoid main-layer work and main-only changes to avoid overlay-layer work -> benchmark proof must target layer-specific surface routing before production implementation.
- `.design/2026-06-13-layer-aware-surface-repaint-routing.md:168` / `design`: Outcome-Proof Fit identifies painter-output identity alone as proxy-risky for proving skipped main-output construction -> this benchmark may record identity as a baseline metric but must not claim it proves future build suppression by itself.
- `.design/2026-06-13-layer-aware-surface-repaint-routing.md:169` / `design`: Outcome-Proof Fit identifies visual screenshots as proxy-risky for proving main-layer repaint suppression -> completion checks must observe the real surface delegate route instead of relying on screenshots.
- `.research/2026-06-13-frame-repaint-signal-surface-usage.md:21` / `surface`: current `CanvasSurface` builds both main and overlay outputs in the `ValueListenableBuilder` path -> current baseline should record both-route behavior before optimizing it.
- `.research/2026-06-13-frame-repaint-signal-surface-usage.md:29` / `surface`: current painters use output identity in `shouldRepaint` -> output identity and delegate `shouldRepaint` are legitimate current-contour metrics.
- `.research/2026-06-13-canvas-surface-widget-proof-seams.md:15` / `surface`: existing widget fixtures can observe `CustomPaint` delegates and their output objects after `pumpWidget` -> benchmark harness can use the real widget path without production hooks.
- `.research/2026-06-13-canvas-surface-widget-proof-seams.md:22` / `surface`: existing pixel probes paint painters directly rather than capturing the rendered `CanvasSurface` tree -> direct painter pixel proof is out of scope for this routing benchmark.
- `lib/src/surface/canvas_surface_widget.dart:187` / `surface`: `_buildPaintHost` calls `buildSurfaceMainFrame` before installing the main painter -> surface route metrics must observe main delegate output identity after widget pumps.
- `lib/src/surface/canvas_surface_widget.dart:200` / `surface`: `_buildPaintHost` calls `buildSurfaceOverlayFrame` before installing the overlay painter -> surface route metrics must observe overlay delegate output identity after widget pumps.
- `lib/src/surface/canvas_surface_widget.dart:208` / `surface`: production surface creates one keyed `CustomPaint` with main and foreground painters -> the benchmark can find the real paint host by key.
- `lib/src/api/canvas_runtime_surface_bridge.dart:70` / `surface bridge`: main output construction is guarded by active surface token and delegated through the runtime surface port -> benchmark proof should not bypass `CanvasSurface` by calling `RuntimeRoot` frame builders directly.
- `lib/src/api/canvas_runtime_surface_bridge.dart:95` / `surface bridge`: overlay output construction is separately guarded and delegated through the runtime surface port -> benchmark proof must exercise overlay through the same public surface path.
- `test/surface/fixtures/widget_paint_fixture.dart:219` / `surface test`: existing widget proof reads selected-move main repaint reason from `MainFramePainter.output` -> selected-move is an existing main-only surface scenario.
- `test/surface/fixtures/widget_paint_fixture.dart:237` / `surface test`: existing widget proof reads marquee overlay primitives from `OverlayFramePainter.output` -> marquee is an existing overlay-only surface scenario.
- `test/benchmarks/benchmark_probe_flutter.dart:1` / `benchmark`: the probe intentionally imports owner surfaces instead of requiring benchmark-only production exports -> surface benchmark harness belongs under `test/benchmarks`, not production API.
- `test/benchmarks/benchmark_probe_flutter.dart:1163` / `benchmark`: action timing wraps `plan.measure` -> new surface cases must keep widget setup outside action samples except for the specific pump/action route being measured.
- `test/benchmarks/benchmark_probe_flutter.dart:1207` / `benchmark`: benchmark cases are routed by domain factory -> adding a `surface` domain is the local extension point for surface-specific harness code.
- `tool/bench/src/benchmark_manifest.dart:249` / `benchmark`: parser has a selected boundary table for supported cases -> new cases must be registered there or fail closed.
- `tool/bench/src/benchmark_runner.dart:408` / `benchmark`: exact invariants are centralized in runner semantics -> new no-positive-drift surface route invariants need runner support instead of ad hoc report interpretation.
- `tool/bench/src/benchmark_diff.dart:1497` / `benchmark`: post-baseline regression metrics are limited to time and memory keys unless exact invariants are used -> layer-route counters need exact-invariant regression semantics.
- `docs/verification/benchmarks.md:62` / `benchmark docs`: benchmark cases, scales, boundaries, metrics, and exact invariants are owned by `docs/_registry/benchmarks.yaml` -> docs must be generated from the manifest source of truth.
- `docs/tool/check_docs.dart:138` / `docs check`: docs check compares benchmark documentation to the manifest -> docs verification must run after manifest edits.
- `docs/tool/sync_generated_docs.dart:582` / `generated docs`: benchmark indexes are generated from section registry entries -> section registry and generated indexes must be updated for new `surface.*` cases.
- `tool/bench/manual/reference_reports/xiaomi_22081283g_android14_flutter_3_44_0.json:30` / `manual benchmark`: accepted Xiaomi reference currently records `runtimeMode: flutter_test` -> new surface cases must be compatible with the existing device contour.
- `tool/bench/manual/reference_decisions.json:6` / `manual benchmark`: active Xiaomi reference is accepted through a decision log pointing at three history runs -> expanded-manifest baseline must update the same manual decision chain.
- `PLAN.md:8` / `plan`: plan entries link to dedicated step files -> Step 7 must be represented by this linked contract.

## Boundaries

Owner: Benchmark tooling and verification own this step: `docs/_registry/benchmarks.yaml`, `tool/bench/src/**`, `test/benchmarks/**`, `docs/verification/benchmarks.md`, `docs/_registry/sections.yaml`, generated benchmark indexes, and manual benchmark reference artifacts. Production `CanvasSurface`, runtime, frame, painter, and resource owners are source inputs only.

In Scope:

- Add focused `surface.overlay_preview_route` and `surface.selected_move_route` benchmark cases that pump the real public `CanvasSurface` in a benchmark-only Flutter widget harness.
- Record fixed layer-route metrics that are meaningful before and after the future repaint-routing implementation. `surface.overlay_preview_route` owns `main_output_identity_changes`, `main_should_repaint_count`, `overlay_output_identity_changes`, `overlay_should_repaint_count`, and `overlay_primitive_count`. `surface.selected_move_route` owns `overlay_output_identity_changes`, `overlay_should_repaint_count`, `main_output_identity_changes`, `main_should_repaint_count`, and `selected_move_main_signal_count`.
- Add exact-invariant runner semantics that allow current baseline values but disallow positive drift for the unaffected-layer route counters after a manual reference is accepted.
- Keep timing and memory metrics as secondary report fields; do not use timing alone to prove layer routing.
- Update benchmark manifest, parser boundary table, case factories, required-case dry-run proof, manifest inventory tests, docs projection, section registry, and generated benchmark index.
- Capture and accept an expanded-manifest Xiaomi current-contour manual reference through the existing three-run `stable_window_median_v1` flow after the new cases are executable.

Out of Scope:

- Implementing the layer-aware runtime/surface repaint-routing design.
- Adding `CanvasSurface` constructor parameters, public benchmark hooks, production counters, bridge-only test APIs, or fixture-only production state.
- Changing `FrameEngine`, frame output semantics, repaint signal construction, runtime repaint aggregation, resource dirty behavior, or painter rendering behavior.
- Requiring zero unaffected-layer counters before the repaint-routing implementation. The current step records the baseline and prevents positive drift; the future implementation step may tighten expected values to zero.
- Replacing the current `flutter_test` device contour with a real profile app, frame-timing trace, raster timing, screenshot, or rendered-widget pixel benchmark.
- Updating public API contracts for production repaint-routing behavior; this step updates benchmark verification documentation only.
- Satisfying design decisions `D1`, `D2`, `D5`, `D6`, or `D7` for production behavior. They remain locked constraints for the later repaint-routing implementation contract; Step 7 only creates the benchmark evidence needed before that work.

Source of Truth: `docs/_registry/benchmarks.yaml` owns benchmark case definitions, scales, boundaries, metrics, profile membership, and exact invariants. `test/benchmarks/benchmark_probe_flutter.dart` owns executable probe behavior. `tool/bench/src/benchmark_runner.dart` and `tool/bench/src/benchmark_diff.dart` own invariant validation and diff semantics. `docs/verification/benchmarks.md`, `docs/_registry/sections.yaml`, and generated indexes are dependent documentation surfaces. Manual Xiaomi reference artifacts under `tool/bench/manual/**` own accepted device observations after the expanded manifest exists. `.design/` and `.research/` remain evidence only.

Compatibility: Public API and production behavior remain unchanged. Existing benchmark cases, reports, and dry-run behavior remain compatible except for the intentional manifest fingerprint and case-count change caused by adding `surface.*` cases. The current Xiaomi manual reference must be refreshed after the manifest expands because the accepted report fingerprint and case inventory are source-of-truth dependent. The new cases remain in the existing `flutter_test` device contour, with assertions enabled as current reports record.

Order Constraints:

1. Add benchmark manifest policy and runner/diff invariant semantics before adding executable surface probe cases.
2. Add the `test/benchmarks` surface harness and dry-run proof before updating documentation projection and generated indexes.
3. Update benchmark docs and section registry after the manifest/probe case inventory is stable.
4. Capture and accept the Xiaomi expanded-manifest manual reference only after local dry-run, manifest, docs, and focused benchmark checks pass.

## Execution Units

### [ ] Unit 1: Register surface route benchmark policy

Owner: `docs/_registry/benchmarks.yaml`; `tool/bench/src/benchmark_manifest.dart`; `tool/bench/src/benchmark_runner.dart`; `tool/bench/src/benchmark_diff.dart`; `test/benchmarks/benchmark_manifest_test.dart`; `test/benchmarks/benchmark_runner_test.dart`; `test/benchmarks/benchmark_diff_test.dart`

Boundary: Benchmark source-of-truth, parser boundary selection, invariant validation, and diff semantics.

Change: Add `surface.overlay_preview_route` and `surface.selected_move_route` to the benchmark manifest with action-only widget-route measurement boundaries, `normal_spread` fixture shape, release-profile scale coverage matching existing input preview cases, route-counter metrics, and exact invariants for no positive drift on unaffected-layer route counters. `surface.overlay_preview_route` required metrics are `main_output_identity_changes`, `main_should_repaint_count`, `overlay_output_identity_changes`, `overlay_should_repaint_count`, `overlay_primitive_count`, `avg_us`, `p95_us`, and `max_us`; exact invariants are `main_output_identity_changes_no_positive_drift` on `main_output_identity_changes` and `main_should_repaint_count_no_positive_drift` on `main_should_repaint_count`. `surface.selected_move_route` required metrics are `overlay_output_identity_changes`, `overlay_should_repaint_count`, `main_output_identity_changes`, `main_should_repaint_count`, `selected_move_main_signal_count`, `avg_us`, `p95_us`, and `max_us`; exact invariants are `overlay_output_identity_changes_no_positive_drift` on `overlay_output_identity_changes` and `overlay_should_repaint_count_no_positive_drift` on `overlay_should_repaint_count`. Extend parser selected-boundary policy and runner/diff tests so those cases are inventory-checked, dry-run-compatible, and diffable through exact-invariant regression rules. Do not add zero expected values for unaffected-layer route counters in this unit.

Completion Check: `docs/_registry/benchmarks.yaml` contains both `surface.overlay_preview_route` and `surface.selected_move_route` with exactly the required metric keys and exact invariant name/metric pairs listed in this unit. `tool/bench/src/benchmark_manifest.dart` accepts both case ids in the selected boundary table and still rejects unregistered benchmark ids. `tool/bench/src/benchmark_runner.dart` accepts the new route counters as valid non-negative report metrics and preserves them in report output without requiring current values to be zero. `tool/bench/src/benchmark_diff.dart` reports a positive-drift failure if a current report increases any `*_no_positive_drift` surface route counter above the accepted baseline and does not fail when the current report lowers that counter. `test/benchmarks/benchmark_manifest_test.dart`, `test/benchmarks/benchmark_runner_test.dart`, and `test/benchmarks/benchmark_diff_test.dart` pass with the expanded inventory and include at least one fixture assertion for positive drift on `main_output_identity_changes` and one fixture assertion for positive drift on `overlay_output_identity_changes`.

Depends On: none

### [ ] Unit 2: Add benchmark-only CanvasSurface route harness

Owner: `test/benchmarks/benchmark_probe_flutter.dart`; supporting files under `test/benchmarks/**` if extraction is needed.

Boundary: Executable benchmark probe cases that may import measured owner surfaces for test-only measurement, without changing production code.

Change: Add a `surface` domain case plan that pumps the real public `CanvasSurface` with a bounded host, finds the keyed `iwb_canvas_surface.paint_host` `CustomPaint`, reads `MainFramePainter` and `OverlayFramePainter` delegates, captures their output identities before and after one scenario action, and records delegate `shouldRepaint` results for affected and unaffected layers. `surface.overlay_preview_route` uses exactly a `CanvasMarqueePreview(rect: Rect.fromLTWH(1, 2, 3, 4))` overlay-only action and uses `overlay_primitive_count` as its sanity metric. `surface.selected_move_route` selects `CanvasElementId('rect-a')`, applies `CanvasSelectedMovePreview(delta: Offset(4, 5))`, and uses `selected_move_main_signal_count` as the sanity metric, where the count is `1` only when the post-action `MainFramePainter.output.repaintSignal.reason` is `selected_move_preview`. The harness may use `WidgetTester` inside the probe path, but production `CanvasSurface`, runtime bridge, frame output, and painter classes must not gain benchmark-only hooks, counters, or constructor parameters.

Completion Check: Running `dart test test/benchmarks/required_cases_test.dart` emits dry-run reports for every manifest case scale, including the two new `surface.*` cases, with the exact required route metrics present and non-negative. The overlay case proves it exercised the real widget path by finding exactly one keyed `CustomPaint`, applying the fixed marquee preview action, recording `overlay_primitive_count > 0` after the action, and returning `main_output_identity_changes` plus `main_should_repaint_count` from `MainFramePainter` delegate/output comparison rather than from `FrameEngine` direct calls. The selected-move case proves it exercised the real widget path by finding exactly one keyed `CustomPaint`, applying the fixed selected-move preview action, recording `selected_move_main_signal_count == 1` after the action, and returning `overlay_output_identity_changes` plus `overlay_should_repaint_count` from `OverlayFramePainter` delegate/output comparison rather than from `RuntimeRoot` frame builders. The reviewed implementation diff for this unit has no production changes under `lib/src/surface`, `lib/src/api/canvas_runtime_surface_bridge.dart`, `lib/src/runtime`, or `lib/src/frame`; if production files are touched, the unit is incomplete unless a separate benchmark anti-hook guardrail exists that rejects public/widget/bridge/runtime/frame benchmark-only counters and that guardrail is registered and passing.

Depends On: Unit 1

### [ ] Unit 3: Publish benchmark documentation and generated indexes

Owner: `docs/verification/benchmarks.md`; `docs/_registry/sections.yaml`; generated documentation under `docs/indexes/**` as produced by repository tooling.

Boundary: Benchmark documentation projection, section registry benchmark relationships, and generated navigation.

Change: Regenerate or update the benchmark documentation projection so the new `surface.*` cases, scales, boundaries, fixture shape, and metrics match `docs/_registry/benchmarks.yaml`. Register the new benchmark ids under the benchmark section in `docs/_registry/sections.yaml` so generated lookup pages include them. Do not document production repaint-routing behavior as complete in this step.

Completion Check: `docs/verification/benchmarks.md` contains the updated benchmark manifest fingerprint and rows for `surface.overlay_preview_route` and `surface.selected_move_route` whose metrics match the manifest. `docs/_registry/sections.yaml` lists both `surface.*` cases under `section_24_benchmarks` and does not reference benchmark ids absent from the manifest. Generated benchmark indexes are synchronized by running `dart run docs/tool/sync_generated_docs.dart` when needed, then `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` both pass.

Depends On: Unit 1 and Unit 2

### [ ] Unit 4: Accept expanded Xiaomi surface-route baseline

Owner: `tool/bench/manual/run_history/**`; `tool/bench/manual/reference_reports/xiaomi_22081283g_android14_flutter_3_44_0.json`; `tool/bench/manual/reference_decisions.json`

Boundary: Manual device observation artifacts for the existing Xiaomi current-contour release benchmark flow.

Change: After the new cases pass locally, run the existing release benchmark flow on the Xiaomi device for the expanded manifest, archive three clean compatible current-contour runs, and accept a new `stable_window_median_v1` reference report for `xiaomi_22081283g_android14_flutter_3_44_0.json`. The accepted reference must include the new `surface.*` cases and record the new manifest fingerprint and case count. Do not overwrite history to hide changed measurements.

Completion Check: Three new history records under `tool/bench/manual/run_history/` reference the same device identity, Flutter `3.44.0`, `runtimeMode: flutter_test`, `repositoryDirty: false`, recorded `subjectGitHead`, and expanded-manifest source report fingerprints. `tool/bench/manual/reference_reports/xiaomi_22081283g_android14_flutter_3_44_0.json` has the new manifest fingerprint, includes both `surface.*` cases with sample summaries and route metrics, and records `selectionPolicy: stable_window_median_v1`. `tool/bench/manual/reference_decisions.json` points the Xiaomi reference decision at those three clean runs with a reason that states the reference was refreshed after adding surface repaint-route benchmark cases. `dart test test/benchmarks/benchmark_diff_test.dart` passes for the committed manual reference vocabulary, and a manual diff command using the refreshed reference and a same-contour current report succeeds without manifest or contour mismatch.

Depends On: Unit 3
