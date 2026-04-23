# Change Contract

## 1. Change Mandate

Establish a repository-owned, product-realistic performance measurement
contract that measures the three known product defects on real target
scenarios, keeps required CI deterministic and hardware-independent, and
produces trustworthy before/after diagnostic baselines for later runtime
optimizations.

## 2. Change Boundary

### Included in the Change

- Repurpose the existing concrete benchmark profile ids into one semantic split:
  `smoke` becomes the product profile for scenes up to and including `1000`
  nodes plus an explicit `3840x2160` viewport scenario, while `full` becomes
  the stress/nightly profile rather than the primary product norm.
- Keep a separate stress profile for large-scene and worst-case diagnostics so
  repository tooling still exposes upper-bound behavior without treating it as
  the product baseline.
- Retool benchmark taxonomy, case corpus, and report schema so the measurement
  surface answers the three current product questions directly:
  render-cache instability on stable scenes,
  selection compositing cost, and
  grid over-iteration cost.
- Add owner-correct probes and benchmark outputs for:
  cache hit/miss/rebuild behavior,
  `saveLayer`-driven selection compositing cost, and
  grid iteration work versus actually drawn line count.
- Refresh checked-in diagnostic baselines only after the new measurement
  surface is live.
- Keep the measurement surface aligned with the accepted target architecture:
  no benchmark-only runtime owners, no benchmark-only committed-scene seam, and
  no overlay-preview perf contract in this step.

### Not Included in the Change

- No runtime fixes for render caches, selection compositing, or grid rendering.
- No cache-capacity redesign, no `saveLayer` removal, and no grid-loop
  algorithm rewrite in this step.
- No platform-specific hard memory budgets for Windows, Linux, or Android.
- No internet-derived performance or memory budgets.
- No new required-CI wall-clock or memory gate that depends on GitHub-hosted
  runner characteristics.
- No overlay-preview benchmark taxonomy while the target render-seam split is
  still intentionally deferred.

## 3. Surrounding Code Review

### Inspected Artifacts

- `docs/target_architecture/README.md` — the accepted target remains anchored
  in ADR 0001 and the family maps; this step must fit the target instead of
  inventing a benchmark-local architecture.
- `docs/adr/0001_target_engine_architecture.md` — the view/runtime boundary,
  render family, store family, and mutation gateway keep their current owner
  roles, so measurement must consume those owners rather than bypass them.
- `docs/target_architecture/families/view_runtime_and_render_seam.md` — the
  main-scene render path stays the correct measurement seam and overlay preview
  remains explicitly deferred as a separate target question.
- `docs/target_architecture/families/store_and_commit_path.md` — committed
  spatial queries stay in the store/write-kernel family and must not be
  replaced with benchmark-only lookup owners.
- `tool/bench/load_profile_policy.dart` — the current `smoke`/`full` taxonomy
  still treats `10000`, `50000`, and `100000` node scenes as the benchmark
  center, which does not match the current product expectation.
- `tool/bench/load_profiles_cases_test.dart` — current benchmark cases cover
  hot-path branches, but they are not yet organized around the three known
  product defects and still emphasize stress scenarios.
- `tool/bench/run_load_profiles.dart` and `tool/bench/diff_load_profiles.dart`
  — the benchmark runner and diff layer own the diagnostic report shape and
  baseline comparison behavior.
- `lib/src/render/render_geometry_cache.dart` — geometry cache is bounded by
  local LRU ownership and already exposes debug build/hit/evict counters.
- `lib/src/render/cache/scene_text_layout_cache.dart` and
  `lib/src/render/cache/scene_stroke_path_cache.dart` — text and stroke caches
  already expose owner-local debug counters suitable for deterministic probes.
- `lib/src/render/scene_painter_selection.dart` — current selection halo
  rendering performs `saveLayer(null, ...)` in `_drawRectHalo(...)` and
  `_drawPathHalo(...)`, which is the measurement seam for the known
  compositing-cost defect.
- `lib/src/render/scene_grid_renderer.dart` — `_drawAxisLines(...)` applies a
  stride cap but still loops across the underlying axis range, which is the
  seam for the known over-iteration defect.
- `test/render/scene_render_caches_test.dart`,
  `test/render/render_geometry_cache_test.dart`,
  `test/render/scene_text_layout_cache_test.dart`,
  `test/render/scene_stroke_path_cache_test.dart`, and
  `test/controller/internal/spatial_index_cache_test.dart` — deterministic
  owner-local cache and reuse proof already exists and must remain the required
  CI contour.
- `test/render/scene_painter_test.dart` — the real `ScenePainter` path already
  has a stable recording-canvas probe for `saveLayer` counting.
- `test/render/scene_grid_renderer_test.dart` and
  `test/render/scene_static_layer_cache_test.dart` — current grid tests already
  prove stride and cache behavior and are the closest structural seams for a
  new measurement contract.
- `tool/invariant_registry.dart` — `INV-ENG-PERFORMANCE-PROOF-CONTOUR` already
  separates deterministic required proof from benchmark regression surfaces,
  which this step must preserve.

### Current Entry Path

- Product diagnostic benchmark path today:
  `tool/bench/run_load_profiles.dart` ->
  `flutter test tool/bench/load_profiles_cases_test.dart` ->
  `IWB_BENCH_RESULT` JSON ->
  checked-in baseline JSON ->
  `tool/bench/diff_load_profiles.dart`.
- Main-scene production path under measurement:
  `SceneViewRenderSurface` ->
  `ScenePainter` ->
  `ScenePainterShell` ->
  `ScenePainterBackground` / `ScenePainterSelectionRenderer` /
  render-cache owners.
- Committed spatial path under measurement:
  `SceneStoreController.queryPaintCandidates(...)` ->
  `SpatialIndexCache`.

### Current Owner

- Diagnostic benchmark ownership lives in `tool/bench/**`.
- Deterministic no-extra-work proof already lives with the runtime owners in
  `test/controller/**` and `test/render/**`.
- The three known defects belong to existing production owners, not to a new
  benchmark-only abstraction:
  render-cache owners and their integrated `ScenePainter` path,
  `ScenePainterSelectionRenderer`,
  and `SceneGridRenderer`.

### Adjacent Abstractions

- `lib/src/render/scene_render_caches.dart` — shared render-cache bundle and
  lifecycle owner.
- `test/render/scene_painter_bounds_contract_test.dart` — structural proof
  that the painter path stays on the real render seam.
- `lib/src/view/scene_view_render_surface.dart` and
  `lib/src/view/scene_view_runtime_host.dart` — existing render-cache host
  probes stay available for test-only ownership verification.
- `test/tool/bench_run_load_profiles_test.dart` and
  `test/tool/bench_diff_load_profiles_test.dart` — current tool-level contract
  surfaces for benchmark taxonomy and diffing.

### Existing Tests

- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/bench_diff_load_profiles_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_grid_renderer_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/render/scene_render_caches_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`

### Analogous Implementation Path

- `test/render/scene_render_caches_test.dart` — the closest valid precedent for
  required deterministic proof on the real render-cache owners.
- `test/tool/bench_run_load_profiles_test.dart` together with
  `tool/bench/load_profiles_cases_test.dart` — the closest valid precedent for
  changing benchmark taxonomy and report meaning without inventing a second
  benchmark runner seam.
- `test/render/scene_painter_test.dart` — the closest valid precedent for
  measuring selection compositing through the real painter path via
  `TestRecordingCanvas` instead of a benchmark-only render owner.

### Governing Repository Rules

- `docs/adr/0001_target_engine_architecture.md` — one assembled runtime
  boundary, one main-scene render read, and no benchmark-only runtime owner.
- `docs/target_architecture/families/view_runtime_and_render_seam.md` —
  measurement must stay on the main-scene render family and must not pretend
  overlay-preview separation is already implemented.
- `docs/target_architecture/families/store_and_commit_path.md` — committed
  spatial measurement stays on the committed store/write path.
- `tool/invariant_registry.dart` / `INV-ENG-PERFORMANCE-PROOF-CONTOUR` —
  deterministic proof remains required, while benchmark policy remains a
  regression surface.

### Rejected Misleading Local Patterns

- Treat `10k+` scenes as the primary product profile — wrong product baseline
  for the current target usage.
- Fix the three runtime defects in the same step as the measurement contract —
  wrong scope because this step must first establish trustworthy “before”
  measurement.
- Set one hard memory budget for all operating systems — wrong abstraction
  because the product will run on different hardware classes and resolutions.
- Move benchmark measurement onto benchmark-only runtime owners — wrong owner
  level and contrary to ADR 0001.
- Promote machine-dependent wall-clock or memory thresholds into required CI —
  wrong verification layer because required CI must stay deterministic.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- The problem belongs to the product diagnostic measurement contract over the
  existing render and committed-spatial owners.

#### Selected Architectural Form

- Keep one deterministic required-CI contour unchanged in principle:
  owner-local cache and reuse proof stays in `test/controller/**` and
  `test/render/**`.
- Lock one semantic successor seam over the existing concrete benchmark ids:
  `smoke` is the product profile and `full` is the stress/nightly profile.
- The `smoke` product profile must cover real product scenarios:
  scenes up to and including `1000` nodes, an explicit `3840x2160` viewport
  scenario, stable scene frames, dense selection frames, and large-grid
  frames.
- The `full` profile remains the heavy stress/nightly contour for large-scene
  and worst-case behavior, so product reporting and stress reporting stop
  sharing one ambiguous “normal” benchmark meaning.
- Extend benchmark reports with explicit probe outputs for the three known
  defects:
  cache churn on stable frames,
  selection `saveLayer` cost, and
  grid iteration waste.
- Keep memory diagnostic-only in this step; required proof and blocking gates
  remain counter- and structure-based.

#### Owning Layer or Module

- Benchmark taxonomy and reporting owner:
  `tool/bench/load_profile_policy.dart`,
  `tool/bench/load_profiles_cases_test.dart`,
  `tool/bench/run_load_profiles.dart`, and
  `tool/bench/diff_load_profiles.dart`.
- Deterministic production-owner proof:
  `test/controller/internal/spatial_index_cache_test.dart`,
  `test/render/scene_render_caches_test.dart`,
  `test/render/scene_painter_test.dart`,
  `test/render/scene_grid_renderer_test.dart`, and neighbor tests.
- Production owner probes:
  existing render-cache owners,
  `ScenePainterSelectionRenderer`, and
  `SceneGridRenderer`.

#### Dependency Direction

- `tool/bench/**` consumes existing production owners and test probes.
- `lib/src/render/**` remains the production-owner source of selection/grid
  semantics and any local debug probe that may be needed.
- Deterministic proof tests remain downstream consumers of the production
  owners and continue to define required CI expectations.

#### State and Data Ownership

- Checked-in benchmark baselines remain diagnostic artifacts only.
- Product-profile baselines describe current product-like behavior before
  optimization; they do not declare a universal cross-platform memory budget.
- Stress-profile baselines remain explicit stress diagnostics and must not be
  interpreted as the product norm.

#### Entry and Exit Boundaries

- Entry:
  benchmark policy, benchmark case corpus, production-owner debug probes,
  baseline capture, and benchmark contract tests.
- Exit:
  one reshootable “before” baseline for product scenarios,
  one separate stress baseline,
  and report outputs that let later optimization steps answer
  “did cache churn improve?”
  “did selection compositing get cheaper?”
  “did grid over-iteration shrink?”

#### Permitted Extension Seam

- Later steps may attach device-lab budgets to the product profile, but only
  after this step makes the product profile and probe metrics stable.
- Later optimization steps may use these reports for before/after comparison,
  but they must not redefine the product profile ad hoc while claiming to
  compare against the same baseline.

#### Rejected Alternatives

- Keep one mixed benchmark profile where product and stress scenarios share one
  normality claim.
- Treat timing-only deltas as sufficient evidence for cache and compositing
  defects.
- Introduce benchmark-only render-state or store seams.
- Set OS-wide memory budgets before device-profile evidence exists.

#### Why This Level Is Correct

- The target architecture already fixes the owner graph, so the missing piece
  is not a new runtime split but a better diagnostic contract over the current
  owners.
- The known defects are owner-local enough that later fixes should be compared
  by counters and directly observable work, not by one generic benchmark
  number.

## 5. Locked Decisions

1. This step measures the three known defects; it does not fix them.
2. The existing concrete id `smoke` is retained but repurposed as the product
   profile id.
3. The existing concrete id `full` is retained but repurposed as the
   stress/nightly profile id.
4. Stress profile keeps `10k+` and worst-case scenarios separate from product
   reporting.
5. Benchmark reports must expose cache churn, selection compositing work, and
   grid iteration waste explicitly enough to compare before/after fixes.
6. Memory remains diagnostic-only in this step; no platform-wide hard memory
   budget is introduced.
7. Required CI remains deterministic and owner-local; machine-dependent
   benchmark numbers remain outside the required contour.
8. Overlay-preview performance stays outside this contract until the target
   render-seam split is a stable contract surface.

## 6. Result Requirements

1. Product benchmarks no longer treat `10k+` scenes as the primary product
   reality.
2. The `smoke` profile reports product scenarios, including a `1000`-node case
   and an explicit `3840x2160` viewport case.
3. The `full` profile reports stress/nightly scenarios and is no longer treated
   as the primary product baseline.
4. Cache-oriented product cases expose hit, miss, and rebuild signals for the
   relevant owners on stable-frame scenarios.
5. Selection-oriented product cases expose `saveLayer`-related work at the real
   `ScenePainter` path.
6. Grid-oriented product cases expose loop work versus actual drawn grid work.
7. The repository can capture a trustworthy “before optimization” baseline for
   the three known defects.
8. Required CI still proves no-extra-work semantics deterministically without
   depending on benchmark hardware.

## 7. Execution Order and Gates

### Required Order

- first add failing contract tests that prove the semantic split
  `smoke == product` and `full == stress/nightly`, and that the benchmark
  reports must expose the three known problem surfaces explicitly
- then update benchmark policy and case corpus while preserving the concrete
  profile ids
- then update runner, diff CLI/help text, and report assertions to the new
  `smoke` / `full` meanings
- then add or wire any owner-correct probes needed for cache churn,
  selection `saveLayer` work, and grid iteration work
- then reshoot checked-in `load_profiles_smoke_*` and `load_profiles_full_*`
  baseline artifacts only after the new benchmark contract is stable
- then align docs and release notes with the new measurement meaning

### Successor Seam and Retirement Gates

- successor seam:
  one semantic split over the existing concrete ids,
  where `smoke` is the product profile,
  `full` is the stress/nightly profile, and
  both reports expose explicit defect-oriented probe metrics
- consumer migration order:
  `tool/bench/load_profile_policy.dart` and
  `tool/bench/load_profiles_cases_test.dart` ->
  `test/tool/bench_run_load_profiles_test.dart` and
  `test/tool/bench_diff_load_profiles_test.dart` ->
  `tool/bench/run_load_profiles.dart` and
  `tool/bench/diff_load_profiles.dart` ->
  checked-in `load_profiles_smoke_*` and `load_profiles_full_*` artifacts ->
  docs and release notes that explain the profile meanings
- retirement gate:
  no benchmark contract file, CLI help text, baseline artifact description, or
  doc still treats `smoke` / `full` as generic size tiers or implies that
  `10k+` scenes are the default product baseline
- proof-retirement gate:
  no new measurement path bypasses the existing production-owner seams to get
  its numbers

### Deferred Broad Verification

- run the required code-change preset only after all measurement-contract files
  land
- run the heavier benchmark reshoots sequentially and only after taxonomy and
  report schema stop moving

## 8. File Map

### Implementation Files

- `tool/bench/load_profile_policy.dart`
- `tool/bench/load_profiles_cases_test.dart`
- `tool/bench/run_load_profiles.dart`
- `tool/bench/diff_load_profiles.dart`
- `lib/src/render/scene_grid_renderer.dart`
- `lib/src/render/scene_painter_selection.dart`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Test Files

- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/bench_diff_load_profiles_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_grid_renderer_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/render/scene_render_caches_test.dart`

### Fixtures and Supporting Data

- `tool/bench/baselines/load_profiles_smoke_baseline.json`
- `tool/bench/baselines/load_profiles_full_baseline.json`
- generated verification outputs under `build/bench/`, including
  `load_profiles_smoke.json`,
  `load_profiles_smoke_diff.json`,
  `load_profiles_full.json`, and
  `load_profiles_full_diff.json`

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `tool/run_tool_tests.dart`
- `tool/run_verification_preset.dart`

### Analysis Area

- product-realistic diagnostic perf measurement over the render family and
  committed spatial consumers

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-PERFORMANCE-PROOF-CONTOUR`
- `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION`
- `INV-ENG-SCENE-PAINTER-MODULE-BOUNDARY`
- `INV-ENG-EPOCH-INVALIDATION`

### Required Proof

- behavioral proof:
  `test/tool/bench_run_load_profiles_test.dart` must lock the new taxonomy and
  benchmark report shape;
  `test/tool/bench_diff_load_profiles_test.dart` must lock the new product
  versus stress semantics;
  `test/render/scene_painter_test.dart` must prove the real painter path still
  exposes the intended compositing probe surface;
  `test/render/scene_render_caches_test.dart` and existing owner-local cache
  tests remain the deterministic comparison surface for cache work.
- structural proof:
  `test/render/scene_painter_bounds_contract_test.dart` remains the structural
  guard that benchmark measurement stays on the real main-scene render seam;
  `test/render/scene_grid_renderer_test.dart` and
  `test/render/scene_static_layer_cache_test.dart` must make the grid
  measurement seam mechanically visible if new grid probes are added.
- for benchmark-contract changes:
  start with one failing taxonomy/report contract test, plus 1 to 3 guard
  tests for neighboring branches when needed.

### Allowed Change Surface

- `tool/bench/**`
- owner-local render probe surfaces needed only for measurement
- benchmark baseline artifacts
- docs and release notes required to explain the new profile meaning

### Forbidden Moves

- Do not fix the cache, selection, or grid algorithms in this step.
- Do not add benchmark-only committed-scene or render-state owners.
- Do not add overlay-preview measurement in this step.
- Do not introduce one hard memory budget for all operating systems.
- Do not make benchmark baselines the required CI truth surface.

## 10. Vertical Slices

### Slice 1. [x] Product Profile Taxonomy

#### Slice Contract

Benchmark policy distinguishes product-realistic scenarios from stress
scenarios, so repository diagnostics stop treating `10k+` scenes as the
primary product norm.

#### Change

- add one failing benchmark-policy contract test that proves
  `smoke == product` and `full == stress/nightly`
- replace the current profile meaning while preserving the concrete ids
  `smoke` and `full`
- keep large-scene and worst-case cases in `full` instead of deleting them

#### Behavioral Verification

- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/bench_diff_load_profiles_test.dart`

#### Structural Verification

- source-level contract checks in `test/tool/bench_run_load_profiles_test.dart`

#### Fixtures Used

- inline benchmark-case fixtures in `test/tool/bench_run_load_profiles_test.dart`

#### Positive Scenarios

- product profile covers scenes up to and including `1000` nodes
- product profile includes an explicit `3840x2160` viewport scenario
- `smoke` resolves to the product profile semantics
- `full` resolves to the stress/nightly profile semantics
- stress profile retains large-scene and worst-case cases explicitly

#### Negative Scenarios

- treating `10k+` as the default product profile fails the benchmark contract
  tests
- treating `smoke` and `full` as generic size tiers instead of explicit
  semantic profiles fails the benchmark contract tests

#### Closure Evidence

- repository diagnostics now speak clearly about product versus stress results

### Slice 2. [x] Defect-Oriented Probe Metrics

#### Slice Contract

Benchmark reports expose direct measurement surfaces for cache churn, selection
compositing work, and grid over-iteration cost without introducing benchmark-
only owners.

#### Change

- add one failing report-shape contract test and neighboring guard tests
- extend product-profile cases and report payloads so cache-oriented scenarios
  emit hit/miss/rebuild evidence from the relevant owners
- wire selection-oriented scenarios through the real `ScenePainter` path and
  expose `saveLayer`-related work in the report surface
- expose grid loop work versus actual drawn-line work at the grid owner seam

#### Behavioral Verification

- `test/tool/bench_run_load_profiles_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_grid_renderer_test.dart`

#### Structural Verification

- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_static_layer_cache_test.dart`

#### Fixtures Used

- existing recording-canvas fixtures in `test/render/scene_painter_test.dart`
- existing grid plan/cache fixtures in render tests

#### Positive Scenarios

- stable-scene cache cases expose whether repeated frames are hitting or
  rebuilding
- selection-heavy cases expose compositing work on the real painter path
- grid-heavy cases expose loop work and drawn-line work separately

#### Negative Scenarios

- a benchmark-only render seam fails structural contract checks
- a report that collapses the three known defects into one generic timing value
  fails the tool-level contract tests

#### Closure Evidence

- later optimization steps can compare before/after results for each known
  defect instead of one generic perf number

### Slice 3. [x] Product Baseline Capture

#### Slice Contract

The repository captures a trustworthy “before optimization” diagnostic
baseline on the new product/stress measurement surface.

#### Change

- reshoot checked-in benchmark baselines only after the new taxonomy and report
  shape are stable
- ensure checked-in artifacts represent the new product/stress meaning rather
  than the old mixed benchmark meaning
- document that these artifacts are diagnostic baselines, not universal
  cross-platform memory budgets

#### Behavioral Verification

- `test/tool/bench_diff_load_profiles_test.dart`
- `test/tool/bench_run_load_profiles_test.dart`

#### Structural Verification

- `dart run tool/bench/run_load_profiles.dart --profile=smoke --output=build/bench/load_profiles_smoke.json`
- `dart run tool/bench/diff_load_profiles.dart --profile=smoke --baseline=tool/bench/baselines/load_profiles_smoke_baseline.json --current=build/bench/load_profiles_smoke.json --output=build/bench/load_profiles_smoke_diff.json`
- `dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json`
- `dart run tool/bench/diff_load_profiles.dart --profile=full --baseline=tool/bench/baselines/load_profiles_full_baseline.json --current=build/bench/load_profiles_full.json --output=build/bench/load_profiles_full_diff.json`

#### Fixtures Used

- checked-in baseline JSON artifacts in `tool/bench/baselines/**`

#### Positive Scenarios

- the repository can reshoot the product baseline and compare it later against
  post-fix runs
- stress baselines remain available without claiming to be the product norm

#### Negative Scenarios

- baseline descriptions that imply one universal OS-wide memory budget fail the
  documentation/contract review for this step

#### Closure Evidence

- the repository has a stable “before” measurement surface for later cache,
  selection, and grid fixes

## 11. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart test/tool/bench_diff_load_profiles_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_grid_renderer_test.dart`
- `flutter test test/render/scene_static_layer_cache_test.dart`
- `flutter test test/render/scene_render_caches_test.dart`
- `printf '%s\n' 'PLAN.md' 'plan/step_12_product_realistic_performance_measurement_contract.md' 'tool/bench/load_profile_policy.dart' 'tool/bench/load_profiles_cases_test.dart' 'tool/bench/run_load_profiles.dart' 'tool/bench/diff_load_profiles.dart' 'tool/bench/baselines/load_profiles_smoke_baseline.json' 'tool/bench/baselines/load_profiles_full_baseline.json' 'test/tool/bench_run_load_profiles_test.dart' 'test/tool/bench_diff_load_profiles_test.dart' 'test/render/scene_painter_test.dart' 'test/render/scene_painter_bounds_contract_test.dart' 'test/render/scene_grid_renderer_test.dart' 'test/render/scene_static_layer_cache_test.dart' 'test/render/scene_render_caches_test.dart' 'ARCHITECTURE.md' 'CHANGELOG.md' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
- `dart run tool/bench/run_load_profiles.dart --profile=smoke --output=build/bench/load_profiles_smoke.json`
- `dart run tool/bench/diff_load_profiles.dart --profile=smoke --baseline=tool/bench/baselines/load_profiles_smoke_baseline.json --current=build/bench/load_profiles_smoke.json --output=build/bench/load_profiles_smoke_diff.json`
- `dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json`
- `dart run tool/bench/diff_load_profiles.dart --profile=full --baseline=tool/bench/baselines/load_profiles_full_baseline.json --current=build/bench/load_profiles_full.json --output=build/bench/load_profiles_full_diff.json`

## 12. Acceptance Criteria

- the next perf-measurement step is explicitly about measurement, not runtime
  fixes
- product diagnostics reflect scenes up to and including `1000` nodes and an
  explicit `3840x2160` viewport scenario instead of treating `10k+` scenes as
  the default norm
- the benchmark surface can later show before/after change for
  render-cache instability,
  selection compositing cost, and
  grid over-iteration cost
- stress scenarios remain available without being mislabeled as the main
  product baseline
- required CI remains deterministic and owner-correct
