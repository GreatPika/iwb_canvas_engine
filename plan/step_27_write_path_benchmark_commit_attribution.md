# Change Contract

## 1. Change Mandate

Make write-path load-profile benchmarks honest about the runtime contour they
measure by recording mandatory runtime-mode metadata at the report level and
controller-owned commit/invariant attribution probes at the write-operation
level, without introducing a benchmark-only write seam or changing committed
write semantics.

## 2. Change Boundary

### Included in the Change

- Add explicit run-level metadata to `load_profiles` reports for the benchmark
  harness/runtime contour that produced the measurements, including
  `runtimeMode`, `assertionsEnabled`, and `debugInvariantMode` with a fixed
  contract vocabulary.
- Add controller-owned attribution probes for write-scale benchmark cases so
  node/stroke write operations can report which commit/invariant contour ran
  under the measured `controller.write(...)` call.
- Extend the write-scale load-profile policy, runner validation, diff parsing,
  and baseline fixtures so missing runtime metadata or missing attribution
  probes become contract violations.
- Keep write-scale benchmark timing on the current production owner path:
  `SceneStoreController.write(...)` through commit planning/execution and the
  existing invariant checks.
- Update architecture/proof source-of-truth text only after the successor
  attribution seam is implemented and mechanically verified.

### Not Included in the Change

- No separate `profile` or `release` benchmark harness.
- No disabling of critical or debug invariant checks for benchmark runs.
- No change to committed write behavior, commit ordering, or invariant
  semantics.
- No new benchmark-only committed-store owner, write runner, or mutation path.
- No eraser benchmark coverage change; that remains a separate step.
- No change to `selection_control_diagnostics` ownership or baseline policy.

## 3. Surrounding Code Review

### Inspected Artifacts

- `ARCHITECTURE.md` — the repository already declares a two-contour
  performance-proof architecture where deterministic owner proof stays in
  tests and `tool/bench/**` remains a diagnostic regression surface over
  production owners.
- `docs/adr/0001_target_engine_architecture.md` — committed scene state and
  transactional writes stay owned by the store/controller family; benchmark
  work must not introduce a second write kernel.
- `docs/target_architecture/families/store_and_commit_path.md` — the accepted
  target explicitly keeps `SceneControllerCommitRuntime` as the write kernel
  and `SceneStoreController` as the committed store facade.
- `tool/invariant_registry.dart` — `INV-ENG-PERFORMANCE-PROOF-CONTOUR`
  already treats diagnostic benchmark policy as a regression surface separate
  from deterministic required proof.
- `.github/workflows/perf_nightly.yaml` — nightly currently runs only
  `run_load_profiles` and `diff_load_profiles` against the checked-in baseline.
- `tool/bench/run_load_profiles.dart` — the runner launches
  `flutter test tool/bench/load_profiles_cases_test.dart`, validates case
  names/probes, and writes only `generatedAtUtc/profile/policy/caseCount/cases`
  today.
- `tool/bench/load_profile_policy.dart` — write-scale node/stroke cases gate
  only `avgUs` and currently declare no required probes.
- `tool/bench/load_profiles_cases_test.dart` — node/stroke write cases measure
  `controller.write(...)` directly; the report already supports operation-level
  probes for other benchmark families but not for write-scale cases.
- `tool/bench/diff_load_profiles.dart` — diffing already understands
  operation-level probes but does not validate run-level runtime metadata.
- `tool/bench/baselines/load_profiles_full_baseline.json` — the
  `strokes_5000_pts_512` case currently records `toggle_selection` at nearly
  the same cost as stroke patch operations while declaring empty `probeKeys`.
- `lib/src/controller/scene_store_controller.dart` — the committed store
  boundary already exposes `debug` as an internal/test-facing access seam over
  commit runtime state.
- `lib/src/controller/scene_controller_commit_debug.dart` — the debug seam
  already records commit phases, change-set data, and transaction clone stats;
  it is the closest valid owner for commit attribution facts.
- `lib/src/controller/scene_controller_commit_runtime.dart` — all
  `SceneStoreController.write(...)` calls converge on `_commitTxn(...)` here.
- `lib/src/controller/scene_controller_commit_execution.dart` — commit
  execution calls `_assertStoreInvariantsCandidate(...)` before applying state
  and conditionally runs `debugAssertTxnStoreInvariants(...)` in
  `kDebugMode || kProfileMode`.
- `lib/src/controller/scene_invariants.dart` — critical invariant scope is
  derived from `ChangeSet`, while `debugAssertTxnStoreInvariants(...)` walks
  the full committed-store invariant surface.
- `lib/src/controller/scene_controller_commit_plan.dart` and
  `lib/src/controller/change_set.dart` — commit phases and change categories
  already exist and can support attribution without inventing a new planner.
- `test/controller/core/scene_controller_commit_atomicity_test.dart` —
  controller tests already prove commit-phase recording and atomic write
  behavior.
- `test/controller/core/scene_controller_commit_failures_test.dart` —
  controller tests already prove that debug hooks are proxied through
  `SceneStoreController.debug` and that failures before/inside commit leave the
  store unchanged.
- `test/tool/bench_run_load_profiles_test.dart` — tool-level structural proof
  already guards benchmark taxonomy and owner-correct probe usage.
- `test/tool/bench_diff_load_profiles_test.dart` — diff-level proof already
  guards probe preservation and report semantics for other benchmark families.
- `test/render/scene_static_layer_cache_test.dart` and
  `tool/bench/load_profiles_cases_test.dart` cache cases — existing benchmark
  diagnostics already consume owner-local debug probes rather than inventing
  benchmark-only render seams.

### Current Entry Path

- `perf_nightly.yaml` ->
  `tool/bench/run_load_profiles.dart` ->
  `flutter test tool/bench/load_profiles_cases_test.dart` ->
  `_runNodeScaleCase(...)` / `_runStrokeScaleCase(...)` ->
  `SceneStoreController.write(...)` ->
  `SceneControllerCommitRuntime._commitTxn(...)` ->
  `executeControllerCommitPlan(...)` ->
  `_assertStoreInvariantsCandidate(...)` ->
  optional `debugAssertTxnStoreInvariants(...)` ->
  emitted `IWB_BENCH_RESULT` JSON ->
  `tool/bench/diff_load_profiles.dart`.

### Current Owner

- The misleading report contract is owned jointly by `tool/bench/**` and the
  controller commit path:
  `tool/bench/**` owns the emitted diagnostic schema and baseline semantics,
  while `lib/src/controller/**` owns the actual write/commit/invariant work
  being measured.

### Adjacent Abstractions

- `SceneStoreController.debug` — existing internal seam for commit/runtime
  debug facts.
- `SceneControllerCommitDebugState` — existing commit-owned recorder for
  last-commit facts.
- `LoadProfilePolicy.contractForCase(...)` — existing benchmark contract owner
  for required operations, probe keys, and execution-mode metadata.
- `tool/bench/diff_load_profiles.dart` probe parsing — existing contract owner
  for probe-presence enforcement in baselines and current reports.

### Existing Tests

- `test/controller/core/scene_controller_commit_atomicity_test.dart` — proves
  commit phases, write atomicity, and no-op commit behavior.
- `test/controller/core/scene_controller_commit_failures_test.dart` — proves
  debug hook access, invariant-precheck failure behavior, and rollback safety.
- `test/tool/bench_run_load_profiles_test.dart` — proves benchmark case-set
  contract and source-level owner usage for production-owner probes.
- `test/tool/bench_diff_load_profiles_test.dart` — proves benchmark diff
  semantics and probe preservation in diff output.

### Analogous Implementation Path

- `tool/bench/load_profiles_cases_test.dart` cache cases together with
  `test/render/scene_static_layer_cache_test.dart`,
  `test/render/scene_text_layout_cache_test.dart`, and
  `test/render/scene_stroke_path_cache_test.dart` — the closest valid
  precedent because benchmark diagnostics there read owner-local debug counters
  from production owners and then serialize them through the bench contract.

### Governing Repository Rules

- `AGENTS.md` — fixes must land at the owner of the invariant/contract rather
  than at one caller, and stable constraints should be mechanically enforced.
- `ARCHITECTURE.md` — diagnostic load profiles must consume production-owner
  seams only and remain a repository-owned regression surface.
- `docs/adr/0001_target_engine_architecture.md` — the store/controller family
  remains the only committed-write owner.
- `docs/target_architecture/families/store_and_commit_path.md` — do not create
  a second committed-write kernel outside `SceneControllerCommitRuntime`.
- `tool/invariant_registry.dart` / `INV-ENG-PERFORMANCE-PROOF-CONTOUR` —
  benchmark policy changes must stay explicit and mechanically provable.

### Rejected Misleading Local Patterns

- `tool/bench/load_profiles_cases_test.dart` current write-scale cases with
  empty `probeKeys` — wrong proof level because they time the full
  `controller.write(...)` contour while reporting no attribution facts.
- A benchmark-only write helper or direct call around
  `SceneControllerCommitRuntime` — wrong owner because it would bypass the real
  committed-write surface under measurement.
- A benchmark env flag that suppresses invariant validation inside the current
  write kernel — wrong semantic level because it would silently change the
  measured runtime contour instead of reporting it.
- A new release/profile benchmark harness in this step — wrong scope because
  the defect is first that the existing diagnostic surface is mislabeled and
  opaque.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- The problem belongs to the diagnostic measurement contract over the existing
  controller-owned committed write path.

#### Selected Architectural Form

- Keep the existing `flutter test`-based diagnostic benchmark harness.
- Add run-level runtime metadata in `tool/bench/**` for the current benchmark
  process so every report declares which runtime contour produced it.
- Add controller-owned last-commit attribution facts in
  `SceneControllerCommitDebugState` and expose them through the existing
  `SceneStoreController.debug` seam.
- Make write-scale benchmark cases read those controller-owned facts and emit
  them as operation-level probes alongside the already-timed metric.
- Keep the timed metric as the total cost of the real write path in the active
  runtime mode; do not relabel it as a production-only hot-path number.

#### Owning Layer or Module

- Report schema, policy, and baseline contract:
  `tool/bench/**`.
- Commit/invariant attribution facts:
  `lib/src/controller/scene_controller_commit_debug.dart` and the commit
  execution/runtime owners that already produce the measured work.

#### Dependency Direction

- `tool/bench/**` may read controller-owned debug facts through
  `SceneStoreController.debug`.
- `lib/src/controller/**` must not depend on `tool/bench/**` or on benchmark
  policy.

#### State and Data Ownership

- Controller commit debug state owns the last committed attribution facts for a
  write.
- The benchmark runner owns serialization of run metadata and case-level probe
  leaves.
- Baseline JSON remains a diagnostic artifact that records the explicit
  runtime/attribution contour; it does not define commit semantics.

#### Entry and Exit Boundaries

- Entry:
  `SceneStoreController.write(...)` and write-scale benchmark cases in
  `tool/bench/load_profiles_cases_test.dart`.
- Exit:
  `IWB_BENCH_RESULT` payloads and `run_load_profiles` / `diff_load_profiles`
  reports with explicit runtime metadata and write-attribution probes.

#### Permitted Extension Seam

- The only new benchmark-consumable production seam is controller-owned debug
  attribution on `SceneStoreController.debug`.
- Run-level runtime metadata may be derived in the benchmark process and
  serialized by `tool/bench/**`.

#### Rejected Alternatives

- Separate release/profile benchmark harness in this step — higher
  infrastructure cost and the wrong first fix while the existing diagnostic
  surface is still opaque.
- Benchmark-only bypass of the controller commit path — violates the accepted
  owner model and would no longer measure the real write path.
- Benchmark flag to disable invariant checks in normal benchmark runs — hides
  the contour change instead of reporting it.

#### Why This Level Is Correct

- The defect is not that the controller write path is wrong; it is that the
  diagnostic surface is attributing that path opaquely.
- The repository already uses owner-local probes for benchmark diagnostics in
  render/cache cases, so extending that form to the controller commit owner is
  the dominant local pattern.
- This keeps benchmark policy downstream from the production owner graph and
  prevents benchmark-specific semantics from leaking into committed writes.

## 5. Locked Decisions

1. This step keeps the existing `flutter test` load-profile harness and makes
   its runtime contour explicit instead of replacing it.
2. Write-scale benchmark timing continues to measure the full
   `SceneStoreController.write(...)` path under the active runtime mode.
3. Run-level report metadata must include:
   `runtimeMode` with exact values `debug`, `profile`, or `release`;
   `assertionsEnabled` as a boolean that reflects Dart assert availability in
   the benchmark process;
   `debugInvariantMode` with exact values `disabled` or `full_store`.
4. Write-scale node/stroke cases must declare required commit-attribution
   probes in `LoadProfilePolicy`; empty `probeKeys` are no longer valid there.
5. Commit/invariant attribution facts must be read from controller-owned debug
   state, not inferred by duplicating commit logic in `tool/bench/**`.
6. This step does not add a benchmark mode that changes commit behavior.
7. Proof/documentation updates happen only after the successor attribution seam
   is mechanically enforced by tests.
8. The exact write-scale probe vocabulary is fixed to numeric leaves so it
   stays compatible with the existing bench runner/diff contract:
   `stateCommitExecuted`,
   `effectsOnlyCommitExecuted`,
   `criticalValidationRan`,
   `criticalValidationFullScene`,
   `criticalValidationTrackedNodeCount`,
   `debugFullStoreInvariantPassRan`.
9. The exact write-scale probe semantics are fixed as follows:
   `stateCommitExecuted = 1` only when the measured write resolves to
   `ControllerStateCommitPlan`, otherwise `0`;
   `effectsOnlyCommitExecuted = 1` only when the measured write resolves to
   `ControllerEffectsOnlyCommitPlan`, otherwise `0`;
   `criticalValidationRan = 1` whenever `_assertStoreInvariantsCandidate(...)`
   executes for the measured write, otherwise `0`;
   `criticalValidationFullScene = 1` only when the critical validation scope
   executes the full-scene runtime validation branch, otherwise `0`;
   `criticalValidationTrackedNodeCount` equals the tracked-node set size used
   by the critical validation scope for that measured write;
   `debugFullStoreInvariantPassRan = 1` only when
   `debugAssertTxnStoreInvariants(...)` executes for the measured write,
   otherwise `0`.

## 6. Result Requirements

1. Every `load_profiles` report states the runtime contour that produced it.
2. Every write-scale node/stroke benchmark case emits mandatory
   commit-attribution probes in addition to timing/memory metrics.
3. Missing runtime metadata or missing write-attribution probes fails tool
   contract validation and diff validation.
4. The benchmark implementation still measures the real committed write path
   and still routes through `SceneStoreController.write(...)`.
5. Architecture and invariant text explicitly describe write-path benchmark
   attribution as a controller-owned diagnostic seam over the existing
   write kernel.
6. The controller-owned attribution seam exposes raw numeric facts only:
   bench-specific JSON naming and serialization remain owned by `tool/bench/**`.
7. For every measured write operation, exactly one of
   `stateCommitExecuted` and `effectsOnlyCommitExecuted` is `1`, and the other
   is `0`.

## 7. Execution Order and Gates

### Required Order

- First, add one failing tool-level reproducer for missing run metadata, one
  failing tool-level reproducer for missing write-attribution probes, and 1 to
  3 focused controller guard tests that lock the new attribution facts at the
  commit owner before the owner-side implementation changes.
- Second, add controller-owned attribution recording and expose it through the
  existing debug seam.
- Third, wire write-scale benchmark cases, runner validation, diff parsing,
  and baseline fixtures to the new runtime/attribution contract.
- Fourth, update invariant/architecture source-of-truth text and refresh the
  checked-in baselines only after the runtime/attribution surface is stable and
  mechanically verified.

### Successor Seam and Retirement Gates

- Successor seam:
  write-scale benchmark attribution through `SceneStoreController.debug`.
- Retirement gate:
  the old probe-less write-case contract is not retired until
  `load_profile_policy.dart`,
  `load_profiles_cases_test.dart`,
  `run_load_profiles.dart`,
  `diff_load_profiles.dart`,
  both checked-in load-profile baselines,
  and the proof/documentation references all agree on the new runtime and
  attribution surface.

### Deferred Broad Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change`
  with the final changed-path set is reserved for the final gate.
- Full `smoke` and `full` benchmark reshoots are reserved for the final gate
  after tool tests and focused controller tests are green.

## 8. File Map

### Implementation Files

- `lib/src/controller/scene_controller_commit_debug.dart`
- `lib/src/controller/scene_controller_commit_execution.dart`
- `lib/src/controller/scene_controller_commit_runtime.dart`
- `tool/bench/load_profile_policy.dart`
- `tool/bench/load_profiles_cases_test.dart`
- `tool/bench/run_load_profiles.dart`
- `tool/bench/diff_load_profiles.dart`

### Test Files

- `test/controller/core/scene_controller_commit_debug_test.dart`
- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/bench_diff_load_profiles_test.dart`

### Fixtures and Supporting Data

- `tool/bench/baselines/load_profiles_smoke_baseline.json`
- `tool/bench/baselines/load_profiles_full_baseline.json`

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `plan/step_27_write_path_benchmark_commit_attribution.md`
- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`

### Analysis Area

- `lib/src/controller/**`
- `tool/bench/**`
- `test/controller/core/**`
- `test/tool/**`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-PERFORMANCE-PROOF-CONTOUR` remains the governing performance-proof
  invariant.
- The committed store/write kernel remains owned by `SceneStoreController` and
  `SceneControllerCommitRuntime`.
- Benchmark tooling must not mutate controller/runtime semantics in order to
  obtain a cleaner number.
- The write-scale attribution probe vocabulary remains numeric and fixed to:
  `stateCommitExecuted`,
  `effectsOnlyCommitExecuted`,
  `criticalValidationRan`,
  `criticalValidationFullScene`,
  `criticalValidationTrackedNodeCount`,
  `debugFullStoreInvariantPassRan`.
- The write-scale attribution probe semantics remain fixed to:
  `stateCommitExecuted = 1` only for `ControllerStateCommitPlan`;
  `effectsOnlyCommitExecuted = 1` only for `ControllerEffectsOnlyCommitPlan`;
  `criticalValidationRan = 1` only when
  `_assertStoreInvariantsCandidate(...)` executes;
  `criticalValidationFullScene = 1` only when critical validation takes the
  full-scene branch;
  `criticalValidationTrackedNodeCount` equals the tracked-node scope size used
  by critical validation for that write;
  `debugFullStoreInvariantPassRan = 1` only when
  `debugAssertTxnStoreInvariants(...)` executes.

### Required Proof

- behavioral proof:
  `test/controller/core/scene_controller_commit_debug_test.dart`,
  `test/tool/bench_run_load_profiles_test.dart`,
  `test/tool/bench_diff_load_profiles_test.dart`
- structural proof:
  source-level owner checks in `test/tool/bench_run_load_profiles_test.dart`
  must prove write-scale cases still use `SceneStoreController.write(...)` and
  read controller-owned debug attribution instead of a benchmark-only bypass;
  `dart run tool/check_guardrails.dart` must stay green so no public or
  boundary leak is introduced
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- Extend controller debug-state recording only enough to expose write-path
  attribution facts.
- Extend benchmark report/diff schema only enough to serialize and enforce the
  explicit runtime/attribution contour.
- Refresh checked-in load-profile baselines only after the new contract is
  fully wired and verified.

### Forbidden Moves

- Do not add a public API surface for benchmark attribution.
- Do not add benchmark-only write helpers, commit runners, or environment
  switches that change commit behavior.
- Do not move commit attribution into interactive or render owners.
- Do not treat the resulting timed metric as a release-only or production-only
  number while it is still collected under the current diagnostic harness.

## 10. Vertical Slices

### Slice 1. [ ] Lock the write-path attribution contract with failing proof

#### Slice Contract

The repository must fail mechanically when write-scale load-profile reports omit
runtime contour metadata or omit commit-attribution probes, and the controller
owner must have focused tests that lock the attribution facts expected from the
commit path.

#### Change

- Add one failing tool reproducer in `test/tool/bench_run_load_profiles_test.dart`
  for missing run-level runtime metadata.
- Add one failing tool reproducer in `test/tool/bench_run_load_profiles_test.dart`
  for missing write-case attribution probes using the fixed numeric vocabulary:
  `stateCommitExecuted`,
  `effectsOnlyCommitExecuted`,
  `criticalValidationRan`,
  `criticalValidationFullScene`,
  `criticalValidationTrackedNodeCount`,
  `debugFullStoreInvariantPassRan`.
- Add one failing diff reproducer in `test/tool/bench_diff_load_profiles_test.dart`
  for missing run-level runtime metadata.
- Add one failing diff reproducer in `test/tool/bench_diff_load_profiles_test.dart`
  for missing write-case attribution probes using the same fixed numeric
  vocabulary.
- Add 1 to 3 focused controller guard tests in
  `test/controller/core/scene_controller_commit_debug_test.dart` that lock:
  a state-changing commit,
  an effects-only commit,
  and a no-op write
  against the new attribution surface before the owner-side implementation.

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart test/tool/bench_diff_load_profiles_test.dart`
- `flutter test test/controller/core/scene_controller_commit_debug_test.dart`

#### Structural Verification

- source-level owner assertions in `test/tool/bench_run_load_profiles_test.dart`
  that write-scale benchmark cases still call `SceneStoreController.write(...)`
  and do not introduce a benchmark-only helper seam
- `dart run tool/check_guardrails.dart`

#### Fixtures Used

- inline benchmark-report fixtures in `test/tool/bench_run_load_profiles_test.dart`
- inline diff fixtures in `test/tool/bench_diff_load_profiles_test.dart`

#### Positive Scenarios

- a report with explicit runtime metadata is accepted
- a diff input pair with explicit runtime metadata is accepted
- a write-scale case with the required attribution probes is accepted
- a diff input pair with the required attribution probes is accepted
- controller tests can read the new last-commit attribution facts through the
  existing debug seam

#### Negative Scenarios

- a report missing `runtimeMode`, `assertionsEnabled`, or `debugInvariantMode`
  fails validation
- a diff input missing `runtimeMode`, `assertionsEnabled`, or
  `debugInvariantMode` fails diff input validation
- a node/stroke write case missing its attribution probes fails validation
- a diff input with a write-scale case missing its attribution probes fails
  diff input validation
- a write-scale benchmark source change that bypasses `SceneStoreController.write(...)`
  fails source-level structural proof

#### Closure Evidence

- the new tests fail before owner-side implementation and then pass without any
  benchmark-only bypass seam

### Slice 2. [ ] Add controller-owned commit attribution and wire write cases

#### Slice Contract

Write-scale benchmarks must read controller-owned attribution facts from the
existing debug seam and emit them per operation while preserving the current
write entry path.

#### Change

- Extend `SceneControllerCommitDebugState` and the commit execution path to
  record the fixed numeric attribution facts needed by the write-scale
  benchmark contract:
  `stateCommitExecuted`,
  `effectsOnlyCommitExecuted`,
  `criticalValidationRan`,
  `criticalValidationFullScene`,
  `criticalValidationTrackedNodeCount`,
  `debugFullStoreInvariantPassRan`.
- Make node/stroke benchmark cases capture those facts around each measured
  write operation and serialize them as operation-level probes.
- Add run-level runtime metadata emission and validation in the bench runner
  and diff layer.

#### Behavioral Verification

- `flutter test test/controller/core/scene_controller_commit_debug_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart test/tool/bench_diff_load_profiles_test.dart`
- `dart run tool/bench/run_load_profiles.dart --profile=smoke --output=build/bench/load_profiles_smoke.json`

#### Structural Verification

- source-level owner checks in `test/tool/bench_run_load_profiles_test.dart`
- `dart run tool/check_guardrails.dart`

#### Fixtures Used

- inline source/body assertions in `test/tool/bench_run_load_profiles_test.dart`
- generated `build/bench/load_profiles_smoke.json`

#### Positive Scenarios

- node and stroke write cases emit attribution probes for
  `single_node_patch`, `single_node_transform`, `toggle_selection`,
  `move_selection`, `single_stroke_patch_thickness`,
  `single_stroke_patch_points`, and `toggle_selection`
- the bench runner writes explicit runtime metadata at the report level
- diff output preserves the new probes instead of dropping them
- the run-level metadata uses only the fixed values:
  `runtimeMode in {debug, profile, release}`,
  `debugInvariantMode in {disabled, full_store}`

#### Negative Scenarios

- write-scale cases cannot silently keep empty `probeKeys`
- the benchmark source cannot replace `SceneStoreController.write(...)` with a
  benchmark-only helper

#### Closure Evidence

- generated smoke report includes the new run metadata and write-attribution
  probes, and tool tests prove both presence and source-level owner usage

### Slice 3. [ ] Refresh proof text and diagnostic baselines to the new contour

#### Slice Contract

The checked-in proof map and baseline artifacts must describe the explicit
runtime/attribution contour for write-path benchmarks so future drift is
mechanically visible.

#### Change

- Refresh `load_profiles_smoke_baseline.json` and
  `load_profiles_full_baseline.json` after the new contract is live.
- Update `ARCHITECTURE.md` and `tool/invariant_registry.dart` so the benchmark
  regression surface explicitly includes runtime contour metadata and
  controller-owned write attribution.

#### Behavioral Verification

- `dart run tool/bench/run_load_profiles.dart --profile=smoke --output=build/bench/load_profiles_smoke.json`
- `dart run tool/bench/diff_load_profiles.dart --profile=smoke --baseline=tool/bench/baselines/load_profiles_smoke_baseline.json --current=build/bench/load_profiles_smoke.json --output=build/bench/load_profiles_smoke_diff.json`
- `dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json`
- `dart run tool/bench/diff_load_profiles.dart --profile=full --baseline=tool/bench/baselines/load_profiles_full_baseline.json --current=build/bench/load_profiles_full.json --output=build/bench/load_profiles_full_diff.json`

#### Structural Verification

- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart test/tool/bench_diff_load_profiles_test.dart`

#### Fixtures Used

- refreshed checked-in load-profile baseline JSON files
- generated `build/bench/load_profiles_*` and `build/bench/load_profiles_*_diff.json` artifacts

#### Positive Scenarios

- checked-in baselines retain the new runtime metadata and write-attribution
  probes
- proof/invariant text points to the updated benchmark regression surface

#### Negative Scenarios

- stale baselines without the new metadata/probes are rejected by diff/tool
  tests
- invariant coverage fails if proof text is updated without executable proof
  references

#### Closure Evidence

- both benchmark profiles diff cleanly against refreshed baselines and
  proof-source files describe the same explicit attribution contour as the
  executable tool tests

## 11. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart test/tool/bench_diff_load_profiles_test.dart`
- `flutter test test/controller/core/scene_controller_commit_debug_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/bench/run_load_profiles.dart --profile=smoke --output=build/bench/load_profiles_smoke.json`
- `dart run tool/bench/diff_load_profiles.dart --profile=smoke --baseline=tool/bench/baselines/load_profiles_smoke_baseline.json --current=build/bench/load_profiles_smoke.json --output=build/bench/load_profiles_smoke_diff.json`
- `dart run tool/bench/run_load_profiles.dart --profile=full --output=build/bench/load_profiles_full.json`
- `dart run tool/bench/diff_load_profiles.dart --profile=full --baseline=tool/bench/baselines/load_profiles_full_baseline.json --current=build/bench/load_profiles_full.json --output=build/bench/load_profiles_full_diff.json`
- `printf '%s\n' 'PLAN.md' 'plan/step_27_write_path_benchmark_commit_attribution.md' 'lib/src/controller/scene_controller_commit_debug.dart' 'lib/src/controller/scene_controller_commit_execution.dart' 'lib/src/controller/scene_controller_commit_runtime.dart' 'tool/bench/load_profile_policy.dart' 'tool/bench/load_profiles_cases_test.dart' 'tool/bench/run_load_profiles.dart' 'tool/bench/diff_load_profiles.dart' 'tool/bench/baselines/load_profiles_smoke_baseline.json' 'tool/bench/baselines/load_profiles_full_baseline.json' 'test/controller/core/scene_controller_commit_debug_test.dart' 'test/tool/bench_run_load_profiles_test.dart' 'test/tool/bench_diff_load_profiles_test.dart' 'tool/invariant_registry.dart' 'ARCHITECTURE.md' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- The contractually required runtime metadata is present in every
  `load_profiles` report.
- Node/stroke write-scale cases emit controller-owned commit-attribution probes
  and can no longer claim empty `probeKeys`.
- Benchmark source-level proof confirms that write cases still route through
  the real committed write path.
- The checked-in baselines and proof text describe the same explicit
  runtime/attribution contour as the executable tool/controller tests.
