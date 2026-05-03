# Change Contract

## 1. Change Mandate

Establish a repository-owned performance proof architecture where required CI
uses deterministic owner-level proof and executable workflow checks, while
isolated benchmark diagnostics remain production-path artifacts with honest
metric semantics, explicit cold-versus-steady-state meaning, and no dependency
on dedicated hardware, while DCM is removed only from GitHub CI.

## 2. Change Boundary

### Included in the Change

- Remove `dcm analyze .` from `.github/workflows/ci.yaml` and from the
  graph-owned CI workflow expectations only; keep DCM available in
  repository-local verification surfaces.
- Separate hard-gated deterministic performance proof from diagnostic load
  profile collection.
- Make the load-profile contract declare case taxonomy, execution mode,
  warm-up discipline, measured-iteration discipline, required operations,
  truthful metric names, and gated-versus-diagnostic metric status.
- Fix benchmark diff verdicts so absolute budgets apply independently of
  baseline sign or value.
- Remove the current fake percentile contract from load profiles and baseline
  diffing.
- Add deterministic proof for committed spatial warm-path behavior and for the
  currently hot render caches already exposed through owner-local debug
  counters.
- Extend diagnostic benchmark coverage for the currently missing production
  paint branches: text layout cache, stroke path cache, and static background
  cache hit-versus-miss behavior.
- Keep production-path benchmark cases on the current production owners and
  preserve the existing painter-only isolation boundary for the painter-only
  case.

### Not Included in the Change

- No self-hosted runner, dedicated benchmark hardware, or machine pinning.
- No redesign of the engine runtime-center owner graph, mutation gateway,
  store/write-kernel split, or render family ownership.
- No benchmark-only committed render-state or committed store owner for
  production-path measurements.
- No overlay-preview performance contract while the target render-seam split is
  still intentionally deferred.
- No public API, serialization, or document-model behavior change.
- No reintroduction of DCM into GitHub CI through a wrapper, fallback token, or
  separate secret-dependent job.
- No retirement of DCM from repository-local verification presets or local
  developer workflows.

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` — new execution contracts must be recorded as dedicated step
  documents linked from the active plan index.
- `docs/target_architecture/README.md` — target architecture is defined by ADR
  0001 and family maps; the plan may schedule work but must not redefine the
  target.
- `docs/adr/0001_target_engine_architecture.md` — runtime ownership stays with
  the existing controller/store/interaction/render families; this perf change
  must not invent benchmark-only runtime owners.
- `docs/adr/0002_post_target_optimization_scope.md` — view host and render
  surface are not phase-2 architecture targets, so perf work here must stay a
  tooling and proof change rather than a new runtime redesign.
- `docs/target_architecture/families/view_runtime_and_render_seam.md` —
  overlay preview still shares the mixed seam that ADR 0001 intends to split,
  so overlay performance taxonomy is not yet a stable contract surface.
- `docs/target_architecture/families/store_and_commit_path.md` — committed
  paint candidate queries and spatial-index ownership stay inside the
  store/write-kernel family, so perf proof must consume that owner rather than
  bypass it.
- `ARCHITECTURE.md` — the repository prefers mechanical enforcement, the render
  path paints from one atomic frame read, and workflow drift is validated
  against a graph-owned executable verification contract.
- `tool/bench/load_profile_policy.dart` — current load-profile ownership mixes
  case taxonomy, iteration counts, metric keys, and thresholds in one file; the
  full profile declares `p95*` metrics while only running 3 to 4 iterations.
- `tool/bench/diff_load_profiles.dart` — current verdict logic applies
  absolute-value gates only when `baselineValue <= 0`, so positive-baseline
  over-budget cases can pass as `ok`.
- `tool/bench/run_load_profiles.dart` — benchmark reports are emitted by
  running `flutter test tool/bench/load_profiles_cases_test.dart` and only
  validate case-name presence today.
- `tool/bench/load_profiles_cases_test.dart` — committed-path benchmark cases
  measure fresh-controller calls without unmeasured warm-up, and the corpus does
  not currently emit dedicated text-layout, stroke-path-cache, or static-layer
  cache cases.
- `.github/workflows/ci.yaml` — GitHub CI currently installs DCM and runs
  `dcm analyze .`.
- `.github/workflows/perf_nightly.yaml` — nightly runs the full load profiles
  and diffs them against the checked-in baseline JSON.
- `tool/src/verification_contract/verification_contract_registry.dart` —
  `required_code_change` and CI workflow expectations currently include
  `dcm_analyze`, so GitHub CI and local required verification are coupled today.
- `test/tool/bench_diff_load_profiles_test.dart` — current coverage locks the
  zero-baseline absolute threshold path, but not the positive-baseline
  over-budget path.
- `test/tool/bench_run_load_profiles_test.dart` — source-level structural proof
  already distinguishes production-path benchmark owners from the benchmark-only
  painter-only owner.
- `test/tool/run_verification_preset_tool_test.dart` — current resolver proof
  still expects `dcm_analyze` inside the required preset.
- `test/tool/verification_contract_tool_test.dart` — current workflow drift
  proof still encodes the DCM step inside canonical CI fixtures.
- `test/tool/invariant_coverage_tool_test.dart` — invariant proof-declaration
  coverage already locks required-versus-regression proof wiring and is the
  executable owner-side proof surface for registering one new invariant.
- `test/controller/internal/spatial_index_cache_test.dart` — committed spatial
  queries already expose deterministic `debugBuildCount` proof for build versus
  reuse behavior.
- `test/render/scene_static_layer_cache_test.dart` — static background caching
  already proves no rebuild on camera pan with deterministic debug counters.
- `test/render/scene_text_layout_cache_test.dart` — text layout caching already
  proves reuse, key semantics, and bounded eviction through deterministic debug
  counters.
- `test/render/scene_stroke_path_cache_test.dart` — stroke path caching already
  proves reuse, invalidation, and LRU behavior through deterministic debug
  counters.
- `test/render/scene_path_metrics_cache_test.dart` — path-metrics caching
  already proves reuse and invalidation through deterministic debug counters.
- `test/render/render_geometry_cache_test.dart` — render geometry caching
  already proves reuse and invalidation through deterministic debug counters.
- `test/render/scene_painter_test.dart` — integrated painter tests already
  exercise cache reuse through the real `ScenePainter` path.
- `test/render/scene_render_caches_test.dart` — integrated cache-bundle tests
  already prove coordinated cache clearing and reuse across the shared render
  cache owner rather than only at individual cache classes.

### Current Entry Path

- GitHub CI verification:
  `required_code_change` ->
  `tool/src/verification_contract/verification_contract_registry.dart` ->
  `.github/workflows/ci.yaml`.
- Diagnostic benchmark path:
  `.github/workflows/perf_nightly.yaml` ->
  `tool/bench/run_load_profiles.dart` ->
  `flutter test tool/bench/load_profiles_cases_test.dart` ->
  `IWB_BENCH_RESULT` JSON payloads ->
  `tool/bench/diff_load_profiles.dart`.
- Production render path under measurement:
  `ScenePainter.paint(...)` ->
  `ScenePainterShell.paint(...)` ->
  `ScenePainterFrameOwner.create(...)` ->
  `SceneViewRenderState.preparePaintPlan(...)`.
- Committed spatial query path under measurement:
  `SceneStoreController.queryPaintCandidates(...)` ->
  `SpatialIndexCache.writeQueryPaintCandidates(...)`.

### Current Owner

- Required verification ownership is currently split between
  `tool/src/verification_contract/verification_contract_registry.dart`,
  `.github/workflows/ci.yaml`, and the hard-coded DCM step, with no current
  distinction between GitHub CI and local required verification.
- Diagnostic benchmark ownership is currently split across
  `tool/bench/load_profile_policy.dart`,
  `tool/bench/run_load_profiles.dart`,
  `tool/bench/diff_load_profiles.dart`, and the checked-in baseline JSON.
- Deterministic no-extra-work proof already lives with the runtime owners in
  `test/controller/**` and `test/render/**`.

### Adjacent Abstractions

- `tool/invariant_registry.dart` — repository owner for executable invariant
  proof declarations when a new stable cross-cutting contract needs mechanical
  proof registration.
- `tool/check_verification_contract.dart` — validates hand-authored workflow
  YAML against the graph-owned executable contract.
- `test/render/scene_painter_bounds_contract_test.dart` — structural proof that
  the main-scene painter consumes the committed render/read seam instead of a
  benchmark-only substitute.
- `test/render/scene_painter_frame_contract_test.dart` — structural and
  behavioral render proof around frame-owned paint-plan preparation and cache
  use.
- `test/render/scene_render_caches_test.dart` — integrated cache-owner proof
  over the shared render cache bundle.

### Existing Tests

- `test/tool/bench_diff_load_profiles_test.dart` — diff verdict and CLI
  contract coverage.
- `test/tool/bench_run_load_profiles_test.dart` — benchmark case-set and
  source-level owner wiring coverage.
- `test/tool/run_verification_preset_tool_test.dart` — required preset
  expansion and ordering coverage.
- `test/tool/verification_contract_tool_test.dart` — workflow drift coverage
  for CI and nightly perf jobs.
- `test/tool/invariant_coverage_tool_test.dart` — invariant proof-declaration
  coverage.
- `test/controller/internal/spatial_index_cache_test.dart` — committed spatial
  cache rebuild versus reuse coverage.
- `test/render/scene_static_layer_cache_test.dart` — static background cache
  reuse and invalidation coverage.
- `test/render/scene_text_layout_cache_test.dart` — text layout cache reuse and
  key coverage.
- `test/render/scene_stroke_path_cache_test.dart` — stroke path cache reuse and
  invalidation coverage.
- `test/render/scene_path_metrics_cache_test.dart` — path-metrics cache reuse
  and invalidation coverage.
- `test/render/render_geometry_cache_test.dart` — render geometry cache reuse
  and invalidation coverage.
- `test/render/scene_painter_test.dart` — integrated painter cache behavior.
- `test/render/scene_render_caches_test.dart` — shared render-cache lifecycle
  coverage across the bundled cache owner.
- `test/render/scene_painter_bounds_contract_test.dart` — structural render
  owner proof.

### Analogous Implementation Path

- `test/controller/internal/spatial_index_cache_test.dart`,
  `test/render/scene_static_layer_cache_test.dart`,
  `test/render/scene_text_layout_cache_test.dart`,
  `test/render/scene_stroke_path_cache_test.dart`, and
  `test/render/render_geometry_cache_test.dart` — the repository already proves
  performance-relevant behavior through deterministic owner-local counters and
  cache-hit semantics instead of through wall-clock thresholds, which is the
  closest valid precedent for the GitHub CI deterministic contour.
- `test/render/scene_render_caches_test.dart` and
  `test/render/scene_painter_test.dart` — the repository already has
  integrated proof at the shared render-cache owner and at the real
  `ScenePainter` path, which is the closest precedent for keeping deterministic
  proof attached to the production owner graph instead of inventing benchmark-only
  seams.
- `tool/invariant_registry.dart` plus
  `tool/src/verification_contract/verification_contract_registry.dart` — the
  repository already separates proof declarations from executable workflow
  ownership, which is the closest valid precedent for separating required perf
  proof from diagnostic benchmark artifacts.

### Governing Repository Rules

- Repository instructions in `AGENTS.md` — fix the invariant at the owning
  layer, prefer executable repository-local enforcement, and use the
  verification preset rather than ad hoc direct test invocation.
- Repository verification rules in `AGENTS.md` — after code changes, run
  `dart run tool/run_verification_preset.dart run --preset=required_code_change`
  with an explicit changed-path list or changed-path file; tool changes may
  require explicit tool-test verification, and heavyweight verification runs
  must stay sequential.
- `ARCHITECTURE.md` — mechanical enforcement, not prose-only guidance, is the
  repository standard for stable constraints.
- `docs/adr/0001_target_engine_architecture.md` — performance tooling must
  consume the existing runtime owner graph and must not create benchmark-only
  view, interaction, or store owners.
- `docs/target_architecture/families/view_runtime_and_render_seam.md` —
  overlay preview remains a deferred seam, so main-scene performance proof must
  not pretend the overlay seam is already split.
- `docs/target_architecture/families/store_and_commit_path.md` — committed
  spatial queries stay with the committed store/write-kernel family.

### Rejected Misleading Local Patterns

- `tool/bench/diff_load_profiles.dart` relative-only verdicting for
  `baselineValue > 0` — wrong fix level because it lets already over-budget
  baselines pass as healthy.
- `tool/bench/load_profile_policy.dart` `p95*` metrics with 3 to 4 iterations
  — wrong metric contract because the reported percentile is mechanically the
  maximum.
- Expanding `_BenchmarkControllerRenderState` or other benchmark-only seams to
  production-path cases — wrong owner because ADR 0001 keeps production reads on
  the real render/store owners.
- Treating baseline JSON diffing as the only required performance proof —
  wrong proof level because commodity CI without pinned hardware is too noisy to
  be the primary invariant owner.
- Adding overlay-preview benchmark taxonomy now — wrong seam timing because the
  target architecture still treats the overlay read as the not-yet-split half of
  the mixed render seam.
- Keeping DCM inside GitHub CI — wrong executable layer for that environment
  because the hosted workflow must run without the missing key, even though DCM
  may remain part of repository-local verification.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Cross-cutting repository verification and diagnostics architecture for engine
  performance proof.

#### Selected Architectural Form

- Adopt a two-contour performance proof architecture:
- the GitHub CI contour is deterministic owner-level proof in `test/**` plus
  executable workflow-contract checks in `test/tool/**`; it proves cache reuse,
  warm-path behavior, benchmark taxonomy, and workflow drift without relying on
  hardware-stable timing and does not depend on DCM;
- the repository-local required verification contour may still include DCM as a
  local analyzer surface;
- the diagnostic contour is isolated load-profile collection in `tool/bench/**`
  plus `perf_nightly.yaml`; it emits production-path artifacts with explicit
  `cold_start` versus `steady_state` meaning, truthful metric names, and
  explicit gated-versus-diagnostic metrics;
- GitHub CI consumes only repository-owned executable checks, so DCM is removed
  from the CI workflow contour instead of being patched through a
  secret-dependent setup step; local verification policy is not narrowed by
  this step.

#### Owning Layer or Module

- Required contour owners:
  `test/controller/**`, `test/render/**`,
  `test/tool/bench_diff_load_profiles_test.dart`,
  `test/tool/bench_run_load_profiles_test.dart`,
  `test/tool/run_verification_preset_tool_test.dart`, and
  `test/tool/verification_contract_tool_test.dart`.
- Diagnostic contour owners:
  `tool/bench/load_profile_policy.dart`,
  `tool/bench/run_load_profiles.dart`,
  `tool/bench/diff_load_profiles.dart`, and
  `tool/bench/load_profiles_cases_test.dart`.
- Executable workflow owner:
  `tool/src/verification_contract/verification_contract_registry.dart` together
  with the hand-authored workflow files it validates.

#### Dependency Direction

- Runtime owners expose only their existing production seams and deterministic
  test-visible counters or state; they do not depend on benchmark tooling.
- `tool/bench/**` consumes runtime behavior through the real production owners,
  except for the already isolated painter-only benchmark case that remains
  structurally guarded as non-production.
- Workflow and verification-contract ownership stays above benchmark tooling:
  workflows call `tool/bench/**`, but benchmark tooling does not define the
  GitHub CI contour.
- Required deterministic proof depends directly on runtime owners and tool
  contract tests, not on benchmark baseline JSON artifacts.

#### State and Data Ownership

- Runtime owners keep the single source of truth for cache hits, cache builds,
  and warm-path reuse behavior.
- The load-profile contract owns benchmark case taxonomy, execution mode,
  required operations, metric names, and gated-versus-diagnostic status.
- Benchmark reports and checked-in baseline JSON files remain diagnostic
  artifacts; they are not the sole source of required CI truth.
- The verification graph owns CI workflow expectations separately from local
  preset membership.

#### Entry and Exit Boundaries

- Required entry boundaries:
  `tool/check_verification_contract.dart`,
  `.github/workflows/ci.yaml`, and the deterministic test suites under
  `test/controller/**`, `test/render/**`, and `test/tool/**`.
- Local verification entry boundaries:
  `required_code_change` and `tool/run_verification_preset.dart`.
- Diagnostic entry boundaries:
  `tool/bench/run_load_profiles.dart` and `.github/workflows/perf_nightly.yaml`.
- Required exit boundaries:
  executable pass/fail results from deterministic proof and workflow drift
  checks.
- Diagnostic exit boundaries:
  machine-readable load-profile reports and benchmark diff artifacts.

#### Permitted Extension Seam

- A new performance-sensitive branch must first be covered by deterministic
  owner-local or structural proof on the existing runtime owner before it may
  gain a diagnostic benchmark case.
- A new diagnostic benchmark case may extend only the load-profile contract and
  must declare its execution mode, warm-up semantics, measured iterations, and
  truthful metric set.
- Production-path diagnostic cases may only use the real production owners that
  already own the measured behavior.

#### Rejected Alternatives

- Keep baseline diffing as the required performance gate — rejected because
  commodity GitHub runners without pinned hardware are too noisy to be the
  invariant owner.
- Introduce benchmark-only render-state or committed-store owners for easier
  measurement — rejected because ADR 0001 keeps measurement on the real runtime
  owner graph.
- Keep percentile metrics with 3 to 4 samples — rejected because the reported
  statistic is semantically false.
- Reintroduce DCM into GitHub CI through a wrapper or secret — rejected because
  the hosted workflow must stay executable from repository-owned surfaces
  without missing credentials.

#### Why This Level Is Correct

- The verified problems are not one runtime bug. They are a proof-model defect:
  the repository currently asks noisy benchmark artifacts to do work that should
  belong either to deterministic owner-local proof or to an explicitly
  diagnostic benchmark contour. Fixing that at the verification-and-tooling
  architecture level preserves the target runtime architecture and makes future
  performance drift mechanically visible without inventing a second engine shape.

## 5. Locked Decisions

1. `dcm_analyze` is retired only from `.github/workflows/ci.yaml` and from the
   graph-owned CI workflow expectations. `required_code_change` and other
   repository-local verification surfaces may continue to include DCM.
2. The required performance contour is deterministic: cache reuse, warm-path
   behavior, and benchmark ownership are proven by owner-local tests and tool
   contract tests, not by wall-clock baseline diffs.
3. Every diagnostic benchmark operation is classified as either `cold_start` or
   `steady_state`. `steady_state` operations require unmeasured warm-up before
   the first measured iteration.
4. The current `p95Us` and `p95RssDeltaBytes` contract is retired from this
   module. Diagnostic reports and diffs must use only truthful metric names.
5. Absolute-value budgets are enforced independently of baseline sign or value.
6. The missing diagnostic hot-path cases added in this step are limited to text
   layout cache, stroke path cache, and static background cache hit-versus-miss
   behavior. Overlay preview remains explicitly deferred.
7. Production-path diagnostic cases continue to use
   `SceneControllerSceneViewRenderState`, `SceneStoreController`, and
   `ScenePainter`; the existing painter-only benchmark remains the only
   benchmark-only render-state exception.
8. Add one invariant entry with id
   `INV-ENG-PERFORMANCE-PROOF-CONTOUR` in `tool/invariant_registry.dart` that
   registers the required deterministic performance-proof contour and the
   diagnostic regression surface for this step.

## 6. Result Requirements

1. GitHub CI runs successfully without DCM and without secret-dependent setup.
2. A positive-baseline benchmark report that is already above an absolute
   budget fails the diff verdict even when `current == baseline`.
3. No fake percentile metric remains in the load-profile contract or checked-in
   baselines.
4. GitHub CI contains deterministic proof for committed spatial warm-path
   behavior and for the existing hot render caches that dominate current
   steady-state paint work.
5. Diagnostic benchmark reports distinguish `cold_start` and `steady_state`
   behavior and no longer mix first-build cost into steady-state verdicts.
6. Diagnostic coverage includes text layout cache, stroke path cache, and
   static background cache hit-versus-miss branches while preserving production
   ownership.
7. Overlay-preview performance remains outside this contract until the target
   main-scene versus overlay render-seam split lands.
8. The invariant registry exposes the new performance-proof contract through
   executable required-versus-regression proof declarations.

## 7. Execution Order and Gates

### Required Order

- First, remove DCM from GitHub CI and its workflow expectations while keeping
  local preset behavior unchanged, and lock that split with workflow-drift
  tests.
- Second, add the failing benchmark reproducer and neighboring guard tests for
  the diff verdict contract before changing the diff owner.
- Third, retire the fake percentile contract and migrate the diagnostic metric
  schema and baseline fixtures to truthful metrics.
- Fourth, add deterministic owner-local proof for warm-path and cache-reuse
  behavior.
- Fifth, extend the diagnostic benchmark taxonomy and case corpus with the
  missing hot branches and explicit `cold_start` versus `steady_state`
  semantics.
- Only after the successor diagnostic contract is live may the old `p95*`
  fields, baseline fixtures, and verdict branches be removed.

### Successor Seam and Retirement Gates

- GitHub CI seam:
  `dcm analyze .` may be removed from `.github/workflows/ci.yaml` and from CI
  workflow expectations only after
  `test/tool/verification_contract_tool_test.dart` proves the successor
  executable contour and
  `test/tool/run_verification_preset_tool_test.dart` proves that local preset
  membership has not been narrowed by mistake.
- Benchmark verdict seam:
  the current positive-baseline relative-only branch in
  `tool/bench/diff_load_profiles.dart` may be retired only after
  `test/tool/bench_diff_load_profiles_test.dart` proves absolute-budget failure
  on the reproduced case plus neighboring guards.
- Metric-schema seam:
  `p95Us`, `p95RssDeltaBytes`, and the old baseline fixture fields may be
  retired only after the load-profile contract, the diff tests, the run tests,
  and both baseline JSON files move to the truthful metric set.
- Diagnostic taxonomy seam:
  the new text-layout, stroke-path-cache, and static-background-cache cases may
  land only after `test/tool/bench_run_load_profiles_test.dart` proves both
  case presence and owner correctness.

### Deferred Broad Verification

- Full `required_code_change` execution is reserved for the final gate after all
  slices close because it is the broadest integrated proof of the new contour.
- Full `tool/run_tool_tests.dart` execution is reserved for the final gate
  because the step changes tool-owned verification and benchmark tooling.
- Full `tool/bench/run_load_profiles.dart --profile=full` plus benchmark diffing
  is reserved for the final gate after the truthful metric schema and the new
  case taxonomy are both live.

## 8. File Map

### Implementation Files

- `tool/bench/load_profile_policy.dart`
- `tool/bench/run_load_profiles.dart`
- `tool/bench/diff_load_profiles.dart`
- `tool/bench/load_profiles_cases_test.dart`
- `tool/src/verification_contract/verification_contract_registry.dart`
- `tool/check_invariant_coverage.dart`
- `tool/check_verification_contract.dart`
- `tool/run_verification_preset.dart`
- `tool/run_tool_tests.dart`
- `tool/invariant_registry.dart`

### Test Files

- `test/tool/bench_diff_load_profiles_test.dart`
- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/run_verification_preset_tool_test.dart`
- `test/tool/verification_contract_tool_test.dart`
- `test/tool/invariant_coverage_tool_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_path_metrics_cache_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_render_caches_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`

### Fixtures and Supporting Data

- `tool/bench/baselines/load_profiles_smoke_baseline.json`
- `tool/bench/baselines/load_profiles_full_baseline.json`
- Existing inline JSON fixtures in `test/tool/bench_diff_load_profiles_test.dart`
- Existing inline workflow sandbox fixtures in
  `test/tool/verification_contract_tool_test.dart`

### Registry, Inventory, and Workflow Files

- `.github/workflows/ci.yaml`
- `.github/workflows/perf_nightly.yaml`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`

### Analysis Area

- `tool/bench/**`
- `tool/src/verification_contract/**`
- `test/tool/**`
- `test/controller/internal/**`
- `test/render/**`
- `.github/workflows/*.yaml`

## 9. Implementation Rules

### Protected Invariants

- Production-path diagnostic benchmarks must stay on the real production owner
  graph.
- The GitHub CI performance contour must remain deterministic and executable on
  GitHub-hosted runners without external keys or dedicated hardware.
- `steady_state` measurements must not include first-build work.
- Absolute budgets must not depend on baseline sign or value.
- Overlay-preview performance remains outside this step until the target
  render-seam split lands.

### Required Proof

- behavioral proof:
  `test/tool/bench_diff_load_profiles_test.dart` must start with one failing
  reproducer for the positive-baseline over-budget case, plus 1 to 3 guard tests
  for neighboring verdict branches;
  `test/tool/verification_contract_tool_test.dart` must start with the failing
  GitHub-CI DCM-removal expectation, and
  `test/tool/run_verification_preset_tool_test.dart` must guard that local
  preset membership still retains DCM;
  deterministic cache and warm-path proofs must use the existing owner-local
  debug counters or directly observable owner behavior.
- structural proof:
  `test/tool/bench_run_load_profiles_test.dart` must make benchmark taxonomy,
  warm-up discipline, and production-owner usage mechanically visible;
  `test/render/scene_painter_bounds_contract_test.dart` remains the structural
  proof that main-scene render benchmarks stay on the real render seam;
  `tool/check_verification_contract.dart` remains the executable workflow-drift
  proof for the GitHub CI contour.
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract.
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed.

### Allowed Change Surface

- `tool/bench/**` contract, runner, diffing, case corpus, and checked-in
  baselines
- Graph-owned workflow expectations and required preset membership
- Owner-local deterministic proof tests under `test/controller/**` and
  `test/render/**`
- Invariant registration and architecture/changelog sync required by the final
  implementation

### Forbidden Moves

- Do not add benchmark-only committed render-state or committed store owners for
  production-path measurements.
- Do not restore DCM to GitHub CI through a wrapper,
  fallback secret, or a parallel required job.
- Do not keep `p95*` names while still collecting too few samples to make those
  names truthful.
- Do not mix `cold_start` cost into `steady_state` verdicts.
- Do not add overlay-preview benchmark taxonomy in this step.
- Do not make benchmark baseline JSON the only required CI proof surface.

## 10. Vertical Slices

### Slice 1. [x] GitHub-Executable Verification Surface

#### Slice Contract

GitHub CI becomes fully executable from repository-owned
surfaces by removing DCM from the CI workflow and CI workflow expectations
without narrowing repository-local verification presets.

#### Change

- Add the failing workflow-drift expectation that proves the CI DCM step must
  disappear, and add the local-preset guard expectation that proves
  `required_code_change` still retains `dcm_analyze`.
- Update the verification graph and `.github/workflows/ci.yaml` so the GitHub
  CI contour no longer includes `dcm analyze .`.
- Keep `perf_nightly.yaml` focused on perf diagnostics rather than adding a DCM
  substitute there.

#### Behavioral Verification

- `test/tool/run_verification_preset_tool_test.dart`
- `test/tool/verification_contract_tool_test.dart`

#### Structural Verification

- `dart run tool/check_verification_contract.dart`

#### Fixtures Used

- Existing sandbox workflow fixtures in
  `test/tool/run_verification_preset_tool_test.dart`
- Existing sandbox workflow fixtures in
  `test/tool/verification_contract_tool_test.dart`

#### Positive Scenarios

- CI workflow drift check accepts the hand-authored workflow without DCM.
- `required_code_change` still resolves with `dcm_analyze`.

#### Negative Scenarios

- Reintroducing `dcm analyze .` into GitHub CI fails the drift checks.
- Removing `dcm_analyze` from `required_code_change` by accident fails the
  preset guard tests.

#### Closure Evidence

- GitHub CI has no executable dependency on DCM, while local required
  verification remains unchanged.

### Slice 2. [x] Honest Benchmark Verdict Contract

#### Slice Contract

Benchmark diffing uses truthful metric semantics and always enforces absolute
budgets, including when the baseline already exceeds the configured cap.

#### Change

- Add the failing positive-baseline over-budget reproducer and neighboring
  guard tests in `test/tool/bench_diff_load_profiles_test.dart`.
- Retire the fake percentile contract from load-profile metric ownership and
  migrate the diff owner and checked-in baselines to truthful metric names.
- Change the diff owner so absolute caps apply independently of baseline sign
  or value.

#### Behavioral Verification

- `test/tool/bench_diff_load_profiles_test.dart`

#### Structural Verification

- `test/tool/bench_run_load_profiles_test.dart`

#### Fixtures Used

- Inline JSON report fixtures in `test/tool/bench_diff_load_profiles_test.dart`
- `tool/bench/baselines/load_profiles_smoke_baseline.json`
- `tool/bench/baselines/load_profiles_full_baseline.json`

#### Positive Scenarios

- A positive-baseline report over the absolute budget fails even when
  `current == baseline`.
- Truthful metric reports are accepted by the diff contract.

#### Negative Scenarios

- Reintroducing `p95*` metric names into the active contract fails the
  tool-level contract tests.
- Relative-only verdicting for positive baselines fails the reproducer.

#### Closure Evidence

- No active load-profile verdict depends on a fake percentile or on
  baseline-sign special casing for absolute budgets.

### Slice 3. [x] Deterministic Hot-Path Proof

#### Slice Contract

GitHub CI proves the currently hot steady-state work through deterministic
owner-local tests for committed spatial reuse and render-cache reuse instead of
through wall-clock benchmark thresholds.

#### Change

- Add the failing warm-path reproducer and neighboring guards in
  `test/controller/internal/spatial_index_cache_test.dart`.
- Extend owner-local render tests so text layout cache, stroke path cache,
  path-metrics cache, render geometry cache, static background cache, and the
  integrated `ScenePainter` path plus the shared render-cache owner all have
  deterministic reuse proof where it is still missing.
- Register `INV-ENG-PERFORMANCE-PROOF-CONTOUR` in
  `tool/invariant_registry.dart` and lock it through executable
  required-versus-regression proof declarations.

#### Behavioral Verification

- `test/controller/internal/spatial_index_cache_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_path_metrics_cache_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_render_caches_test.dart`
- `test/render/scene_painter_test.dart`
- `test/tool/invariant_coverage_tool_test.dart`

#### Structural Verification

- `test/render/scene_painter_bounds_contract_test.dart`
- `tool/check_invariant_coverage.dart`

#### Fixtures Used

- Existing owner-local cache fixtures inside the named render and controller
  tests

#### Positive Scenarios

- Repeated committed paint queries reuse the existing spatial index after the
  initial build.
- Repeated main-scene paint operations hit the existing render caches when the
  relevant inputs stay unchanged.

#### Negative Scenarios

- A fresh-build cost leaking into the steady-state owner proof fails the new
  warm-path reproducer.
- Regressing a cache hit into a rebuild fails the owner-local deterministic
  tests.

#### Closure Evidence

- GitHub CI proves no-extra-work semantics on the current hot owners without
  depending on wall-clock thresholds.

### Slice 4. [x] Diagnostic Benchmark Taxonomy

#### Slice Contract

The diagnostic benchmark corpus covers the current missing hot branches and
explicitly distinguishes `cold_start` from `steady_state` behavior while
preserving the real production owner seams.

#### Change

- Extend the load-profile contract and benchmark case corpus with explicit
  execution-mode semantics and the missing text-layout, stroke-path-cache, and
  static-background-cache cases.
- Add unmeasured warm-up ahead of every `steady_state` production-path case.
- Keep the painter-only benchmark as the only benchmark-only render-state case
  and preserve the existing production-path owner wiring checks.
- Refresh the checked-in diagnostic baseline artifacts after the new truthful
  metric schema and case taxonomy are live.

#### Behavioral Verification

- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/bench_diff_load_profiles_test.dart`

#### Structural Verification

- `test/tool/bench_run_load_profiles_test.dart`
- `tool/check_verification_contract.dart`

#### Fixtures Used

- `tool/bench/baselines/load_profiles_smoke_baseline.json`
- `tool/bench/baselines/load_profiles_full_baseline.json`
- Existing source-text fixtures in `test/tool/bench_run_load_profiles_test.dart`

#### Positive Scenarios

- The benchmark report emits the new cases and required operations.
- `steady_state` cases perform warm-up before the first measured iteration.
- Production-path cases still use the real render/store owners.

#### Negative Scenarios

- Omitting warm-up from a `steady_state` case fails the structural contract
  tests.
- Replacing a production-path owner with a benchmark-only seam fails the source
  contract tests.
- Adding overlay-preview taxonomy in this step fails the contract tests or
  invariant checks.

#### Closure Evidence

- Nightly diagnostics emit an honest, owner-correct benchmark corpus for the
  current main-scene hot paths.

## 11. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart test/tool/bench_run_load_profiles_test.dart test/tool/run_verification_preset_tool_test.dart test/tool/verification_contract_tool_test.dart test/tool/invariant_coverage_tool_test.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_verification_contract.dart`
- `printf '%s\n' 'PLAN.md' 'plan/step_11_performance_proof_architecture.md' 'tool/bench/load_profile_policy.dart' 'tool/bench/run_load_profiles.dart' 'tool/bench/diff_load_profiles.dart' 'tool/bench/load_profiles_cases_test.dart' 'tool/src/verification_contract/verification_contract_registry.dart' 'tool/check_invariant_coverage.dart' 'tool/check_verification_contract.dart' 'tool/run_verification_preset.dart' 'tool/run_tool_tests.dart' 'tool/invariant_registry.dart' 'test/tool/bench_diff_load_profiles_test.dart' 'test/tool/bench_run_load_profiles_test.dart' 'test/tool/run_verification_preset_tool_test.dart' 'test/tool/verification_contract_tool_test.dart' 'test/tool/invariant_coverage_tool_test.dart' 'test/controller/internal/spatial_index_cache_test.dart' 'test/render/scene_static_layer_cache_test.dart' 'test/render/scene_text_layout_cache_test.dart' 'test/render/scene_stroke_path_cache_test.dart' 'test/render/scene_path_metrics_cache_test.dart' 'test/render/render_geometry_cache_test.dart' 'test/render/scene_render_caches_test.dart' 'test/render/scene_painter_test.dart' 'test/render/scene_painter_bounds_contract_test.dart' 'tool/bench/baselines/load_profiles_smoke_baseline.json' 'tool/bench/baselines/load_profiles_full_baseline.json' '.github/workflows/ci.yaml' '.github/workflows/perf_nightly.yaml' 'ARCHITECTURE.md' 'CHANGELOG.md' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
- `dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json`
- `dart run tool/bench/diff_load_profiles.dart --profile=full --baseline=tool/bench/baselines/load_profiles_full_baseline.json --current=build/bench/load_profiles_full.json --output=build/bench/load_profiles_full_diff.json`

## 12. Acceptance Criteria

- GitHub CI no longer depends on DCM and stays aligned with the graph-owned
  CI workflow contract, while local required verification still retains DCM.
- The benchmark diff contract fails positive-baseline over-budget cases and no
  longer exposes fake percentile metrics.
- GitHub CI has deterministic hot-path proof for committed spatial reuse and
  the current render caches.
- Diagnostic benchmarks distinguish `cold_start` from `steady_state` and cover
  text layout cache, stroke path cache, and static background cache
  hit-versus-miss behavior.
- Production-path benchmark ownership stays on the real runtime owners and does
  not reintroduce benchmark-only committed seams.
- Overlay-preview performance remains explicitly deferred until the target
  render-seam split lands.
