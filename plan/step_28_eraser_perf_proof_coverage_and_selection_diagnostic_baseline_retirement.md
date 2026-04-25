# Change Contract

## 1. Change Mandate

Normalize the repository-owned performance regression surface so it covers the real eraser commit hot path and no longer carries an orphaned non-canonical selection diagnostic baseline.

## 2. Change Boundary

### Included in the Change

- Add one `full` load-profile eraser case to the canonical `tool/bench/run_load_profiles.dart` and `tool/bench/diff_load_profiles.dart` regression surface.
- Measure that eraser case through the real public interaction path (`SceneController.interaction.handlePointer(...)`) instead of an internal engine shortcut.
- Extend the existing interactive internal-access probe seam with one eraser attribution counter that makes the benchmark report explainable.
- Require exact eraser probe keys in load-profile policy, runner validation, diff validation, and the checked-in `full` baseline.
- Retire `tool/bench/baselines/selection_control_diagnostics_smoke_baseline.json` as an orphaned artifact and lock the existing `run_selection_control_diagnostics.dart` runner as unchanged ad hoc diagnostics instead of a repository-owned regression gate.

### Not Included in the Change

- Any eraser algorithm optimization or interactive geometry refactor.
- A new `smoke` eraser case.
- A separate `profile` or `release` benchmark harness.
- Converting `run_selection_control_diagnostics.dart` into a CI/nightly gate.
- New workflow commands or verification-registry expectations for selection diagnostics.

## 3. Surrounding Code Review

### Inspected Artifacts

- `ARCHITECTURE.md` — locks the two-contour performance-proof shape and requires benchmark runners to consume production-owner seams only.
- `docs/adr/0001_target_engine_architecture.md` — keeps interaction-owned state ephemeral until it crosses the mutation gateway and keeps one interaction-owned committed-write gateway.
- `docs/target_architecture/families/mutation_gateway.md` — locks `SceneControllerMutationBoundary` as the only interaction-owned committed-write gateway.
- `tool/invariant_registry.dart` — `INV-ENG-PERFORMANCE-PROOF-CONTOUR` owns the benchmark regression surface; `INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP` already covers eraser/stroke path buffering.
- `tool/bench/load_profile_policy.dart` — defines the canonical load-profile case set, required operations, and required probe keys; eraser is currently absent.
- `tool/bench/load_profiles_cases_test.dart` — owns benchmark case execution and already reads owner-local probes for render/cache diagnostics.
- `tool/bench/run_load_profiles.dart` — runs the canonical benchmark suite and rejects missing cases/probes.
- `tool/bench/diff_load_profiles.dart` — compares canonical benchmark reports and fails missing required cases/probes.
- `tool/bench/run_selection_control_diagnostics.dart` — reruns two selection load-profile cases and writes a standalone report, but has no diff or CI consumer.
- `tool/bench/baselines/selection_control_diagnostics_smoke_baseline.json` — checked-in baseline artifact with no workflow or diff consumer.
- `lib/src/interactive/internal/interactive_draw_eraser_engine.dart` — owns eraser commit-up orchestration and current debug counters for spatial queries and precise checks.
- `lib/src/interactive/internal/interactive_draw_eraser_exact_hit.dart` — owns eraser-to-local projection and exact-hit dispatch.
- `lib/src/interactive/internal/interactive_draw_eraser_targets.dart` — owns batched coarse spatial queries and candidate filtering.
- `lib/src/interactive/internal/interactive_draw_eraser_stroke_hit.dart` — owns nested exact segment checks for stroke hits.
- `lib/src/interactive/internal/interactive_draw_coordinator.dart` — routes draw-tool pointer flow and exposes eraser debug counters upward.
- `lib/src/interactive/internal/interactive_runtime.dart` — exposes interaction-owned eraser counters to the runtime state surface.
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart` — assembles interaction runtime and exposes eraser counters through the runtime state API.
- `lib/src/interactive/internal/scene_controller_internal_access.dart` — current internal-access seam used by tests to read eraser counters.
- `lib/src/interactive/internal/scene_controller_graph.dart` — registers the internal-access getters on the assembled controller graph.
- `test/interactive/core/scene_controller_interactive_guardrails_eraser_test.dart` — already proves bounded eraser correctness/query-check behavior on long gestures, but not nightly perf-baseline ownership.
- `test/interactive/test_support/interactive_controller_fixtures.dart` — current helper surface for eraser internal-access counters in tests.
- `test/tool/bench_run_load_profiles_test.dart` — locks canonical benchmark case/probe contracts and already uses source-level structural checks for benchmark ownership.
- `test/tool/bench_diff_load_profiles_test.dart` — locks diff behavior for required cases and probes.
- `test/tool/bench_selection_control_diagnostics_test.dart` — currently proves only arg parsing and bench-result extraction for the selection diagnostic runner.
- `.github/workflows/perf_nightly.yaml` — runs only canonical `load_profiles full` plus `diff_load_profiles full`.
- `tool/src/verification_contract/verification_contract_registry.dart` — expects only canonical load-profile full runner + diff in nightly verification.

### Current Entry Path

- Canonical nightly perf path: `.github/workflows/perf_nightly.yaml` -> `tool/bench/run_load_profiles.dart --profile=full` -> `flutter test tool/bench/load_profiles_cases_test.dart` -> emitted benchmark cases -> `tool/bench/diff_load_profiles.dart`.
- Real eraser commit path: `SceneController.interaction.handlePointer(...)` -> `SceneControllerInteractionRuntime` -> `InteractiveRuntime` -> `InteractiveDrawCoordinator` -> `InteractiveDrawEraserEngine.commitOnUp(...)` -> `SceneControllerMutationBoundary.commitEraseNodes(...)` -> `SceneControllerCommittedMutationAccess.commitEraseNodes(...)`.
- Selection diagnostic path: `tool/bench/run_selection_control_diagnostics.dart` -> rerun named load-profile tests from `tool/bench/load_profiles_cases_test.dart` -> write standalone report JSON.

### Current Owner

- The canonical performance regression surface is owned by `tool/bench/**` load profiles and their checked-in baselines.
- Raw eraser work counters are owned by `lib/src/interactive/internal/**`, then exposed through `SceneControllerInternalAccess` for tests and benchmark consumers.
- `run_selection_control_diagnostics.dart` is only an auxiliary diagnostic runner; no current workflow or diff surface owns its checked-in baseline.

### Adjacent Abstractions

- Render/cache benchmark probes in `tool/bench/load_profiles_cases_test.dart` already read owner-local debug counters from production owners and serialize them into benchmark reports.
- `SceneControllerInternalAccess` is the existing controller-private seam for interaction/runtime test diagnostics.
- `InteractiveDrawEraserEngine` already owns eraser debug counters for query/check work, so new attribution must extend this owner chain instead of creating a benchmark-owned counter source.

### Existing Tests

- `test/interactive/core/scene_controller_interactive_guardrails_eraser_test.dart` — proves long-gesture eraser correctness and bounded query/check behavior on real interaction flow.
- `test/interactive/core/interactive_draw_eraser_engine_test.dart` — proves local eraser projection/fallback correctness for focused eraser owners.
- `test/tool/bench_run_load_profiles_test.dart` — proves required load-profile case/probe contracts and benchmark-source ownership patterns.
- `test/tool/bench_diff_load_profiles_test.dart` — proves canonical diff behavior for required cases and probes.
- `test/tool/bench_selection_control_diagnostics_test.dart` — proves runner parsing/extraction only; it does not protect baseline ownership or CI status.
- `test/tool/verification_contract_tool_test.dart` — proves the checked-in nightly workflow command set.

### Analogous Implementation Path

- `tool/bench/load_profiles_cases_test.dart` stable-visible-working-set/cache cases plus `tool/bench/load_profile_policy.dart` — this is the closest valid precedent because canonical load profiles already serialize owner-local production probes from render/cache owners, and those probe surfaces are mechanically required by both runner and diff tests.

### Governing Repository Rules

- `ARCHITECTURE.md` — diagnostic load profiles remain repository-owned regression artifacts and benchmark runners must consume production-owner seams only.
- `docs/adr/0001_target_engine_architecture.md` — interaction-owned state stays ephemeral until the mutation gateway; committed writes from interaction paths still pass through one gateway.
- `docs/target_architecture/families/mutation_gateway.md` — `SceneControllerMutationBoundary` remains the only interaction-owned committed-write gateway.
- `tool/invariant_registry.dart` (`INV-ENG-PERFORMANCE-PROOF-CONTOUR`) — benchmark regression surface must stay deterministic and repository-owned.
- `tool/invariant_registry.dart` (`INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP`) — eraser active gesture buffering remains bounded and protected independently of benchmark policy.
- `AGENTS.md` — fixes must go to the owning layer and important constraints should be mechanically enforced in tests/tools instead of remaining prose-only.

### Rejected Misleading Local Patterns

- `test/interactive/core/interactive_draw_eraser_engine_test.dart` direct engine tests — valid for focused owner correctness, but the wrong level for a product-realistic benchmark because they bypass pointer flow and the mutation gateway path.
- `tool/bench/run_selection_control_diagnostics.dart` checked-in baseline artifact — looks like a regression surface, but it has no diff consumer, no workflow step, and no verification-contract expectation.
- Any benchmark helper that calls `InteractiveDrawEraserEngine.commitOnUp(...)` directly — wrong seam because it bypasses the public interaction path that the product actually executes.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Repository-owned performance-proof contour with one interactive-owner probe extension and one artifact-status cleanup.

#### Selected Architectural Form

- Extend the canonical `load_profiles full` regression surface with one eraser benchmark case that executes through the real `SceneController.interaction.handlePointer(...)` path.
- Keep raw eraser attribution facts inside the interactive owner chain and expose them only through the existing controller-private internal-access seam.
- Retire the committed `selection_control_diagnostics` baseline artifact instead of promoting that unchanged runner into a second regression gate.

#### Owning Layer or Module

- `tool/bench/**` owns canonical case naming, policy, report schema, diff comparison, and checked-in load-profile baselines.
- `lib/src/interactive/internal/**` owns raw eraser work counters and their propagation through the existing internal-access seam.
- `tool/bench/run_selection_control_diagnostics.dart` remains an unchanged ad hoc utility and does not own a checked-in regression baseline.

#### Dependency Direction

- `tool/bench/**` may depend on the public `SceneController` interaction surface plus controller-private internal-access helpers already used by tests.
- Interactive runtime owners may expose raw counters upward through the existing internal-access chain, but they do not depend on `tool/bench/**`.
- Selection diagnostics may depend on canonical load-profile cases, but canonical load profiles and verification surfaces must not depend on selection-diagnostic artifacts.

#### State and Data Ownership

- Eraser gesture state, coarse-query counts, exact-check counts, and projected-point counts remain owned by interactive eraser runtime owners.
- Benchmark case geometry, measured metrics, and serialized probe values remain owned by `tool/bench/**`.
- Selection diagnostic output remains transient runtime output only; the repository no longer owns a checked-in selection diagnostic baseline artifact.

#### Entry and Exit Boundaries

- Entry for canonical eraser perf proof: `tool/bench/run_load_profiles.dart --profile=full`.
- Benchmark execution entry: `SceneController.interaction.handlePointer(...)` with real pointer phases and eraser tool configuration.
- Exit for canonical perf proof: `load_profiles` report + diff output with required eraser metrics and probes.
- Exit for selection diagnostics: optional standalone JSON report written under `build/bench/**`, without any checked-in baseline or CI consumption.

#### Permitted Extension Seam

- Add one eraser attribution counter through the existing `InteractiveDrawEraserExactHit` -> `InteractiveDrawEraserEngine` -> `InteractiveDrawCoordinator` -> `InteractiveRuntime` -> `SceneControllerInteractionRuntime` -> `SceneControllerInternalAccess` chain.
- Extend `load_profile_policy.dart`, `load_profiles_cases_test.dart`, runner validation, diff validation, and the checked-in full baseline with one new canonical eraser case.
- Delete the orphaned selection-diagnostic baseline artifact and add tests that mechanically prevent reintroducing it as a fake regression reference.

#### Rejected Alternatives

- Benchmark `InteractiveDrawEraserEngine` directly — wrong level because it bypasses the public interaction flow and the mutation gateway route that architecture locks.
- Add a separate `selection_control_diagnostics` diff tool and nightly workflow gate in this step — wrong scope because it would create a second regression surface instead of removing the current orphaned one.
- Add benchmark-only runtime owners or helper counters outside interactive/internal owners — wrong seam because benchmark policy must consume production-owner seams only.

#### Why This Level Is Correct

- The missing proof is not “eraser helper correctness”; it is missing regression coverage for a real user hot path.
- The repository already uses owner-local debug probes from production owners for other benchmark cases, so eraser should follow the same shape instead of inventing a new one.
- The selection diagnostic artifact problem is not missing runtime behavior; it is false proof surface. The correct fix is to retire the misleading checked-in baseline, not to grow another benchmark gate while this step is already changing the canonical perf-proof contour.

## 5. Locked Decisions

1. The new eraser case is `full`-profile only; `smoke` remains unchanged in this step.
2. The canonical eraser case name is `eraser_long_path_mixed_scene`, and its single measured operation is `erase_path_commit`.
3. The benchmark must enter through `SceneController.interaction.handlePointer(...)` with real pointer phases (`down`, repeated `move`, terminal `up`) and must commit deletion only on the terminal interaction path.
4. The eraser benchmark scene must be deterministic and mixed: it includes near-hit and safe-far stroke candidates plus line candidates, so the measured path covers coarse query, exact hit, and committed deletion together.
5. The required eraser probe keys for `erase_path_commit` are exactly:
   - `spatialQueryCount`
   - `preciseSegmentCheckCount`
   - `projectedPointCount`
   - `deletedCount`
6. Probe semantics are fixed:
   - `spatialQueryCount`: total coarse spatial query invocations performed during the measured eraser commit.
   - `preciseSegmentCheckCount`: total exact segment-to-segment checks performed during the measured eraser commit.
   - `projectedPointCount`: total eraser points materialized into node-local projected point lists across successful eraser-to-local projections during the measured commit; world-bounds fallback without projection contributes `0`.
   - `deletedCount`: committed node-removal count returned by the committed erase path for the measured operation.
7. `projectedPointCount` is a raw interactive-owner fact, not a benchmark-only derived estimate.
8. `tool/bench/baselines/selection_control_diagnostics_smoke_baseline.json` is retired in this step; `run_selection_control_diagnostics.dart` remains an ad hoc diagnostic runner and gains no baseline/diff/CI contract here.
9. `tool/bench/run_selection_control_diagnostics.dart` is not edited in this step; its ad hoc status is enforced by artifact cleanup plus tool/workflow verification.

## 6. Result Requirements

1. `load_profiles full` requires `eraser_long_path_mixed_scene` as a canonical case, and runner/diff validation fail if that case is missing from current or baseline reports.
2. `eraser_long_path_mixed_scene` reports `erase_path_commit` metrics plus the exact four eraser probes from Section 5, and runner/diff validation fail if any required probe is missing or non-finite.
3. The eraser benchmark source executes through the public interaction path and reads eraser attribution only through controller-private internal-access helpers; it does not instantiate or call internal eraser runtime owners directly from benchmark code.
4. The interactive owner chain exposes `projectedPointCount` through the existing internal-access seam without widening the public package API.
5. The checked-in canonical perf baseline inventory contains only canonical load-profile baselines after this step; no selection diagnostic baseline remains committed.
6. `run_selection_control_diagnostics.dart` still produces a standalone diagnostic report from existing selection load-profile cases, but the repository no longer implies that this output is a checked-in regression reference.
7. This step does not modify `tool/bench/run_selection_control_diagnostics.dart`.

## 7. Execution Order and Gates

### Required Order

- Retire the orphaned selection-diagnostic baseline artifact first, with a failing artifact-inventory reproducer and guard tests that lock the runner as ad hoc.
- Then lock the eraser load-profile gap with failing tool-test reproducers for missing case/probes and the required ownership shape.
- Add the interactive-owner projected-point probe seam before wiring the final eraser benchmark case, so the benchmark report never ships without the locked attribution surface.
- Update the full baseline only after policy, benchmark execution, and diff validation all require the eraser case and probe set.

### Successor Seam and Retirement Gates

- Canonical successor surface for repository-owned performance regression remains `run_load_profiles` + `diff_load_profiles` only.
- `selection_control_diagnostics_smoke_baseline.json` may retire once:
  - tool tests fail when any selection diagnostic baseline remains in the committed canonical baseline inventory, and
  - no workflow or verification-contract expectation claims selection diagnostics as a nightly regression run.
- No selection-diagnostic diff tool or workflow integration may be introduced as part of that retirement.

### Deferred Broad Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<...>` — final gate only after all slices are complete.
- Broad workflow/guardrail verification remains deferred to the final gate; slice-local work should use targeted tool tests and interactive tests first.

## 8. File Map

### Implementation Files

- `tool/bench/load_profile_policy.dart`
- `tool/bench/load_profiles_cases_test.dart`
- `lib/src/interactive/internal/interactive_draw_eraser_exact_hit.dart`
- `lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator.dart`
- `lib/src/interactive/internal/interactive_runtime.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`

### Test Files

- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/bench_diff_load_profiles_test.dart`
- `test/tool/bench_selection_control_diagnostics_test.dart`
- `test/tool/verification_contract_tool_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_eraser_test.dart`
- `test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `test/interactive/test_support/interactive_controller_fixtures.dart`

### Fixtures and Supporting Data

- `tool/bench/baselines/load_profiles_full_baseline.json`
- `tool/bench/baselines/selection_control_diagnostics_smoke_baseline.json` (delete)

### Registry, Inventory, and Workflow Files

- `.github/workflows/perf_nightly.yaml`
- `tool/src/verification_contract/verification_contract_registry.dart`
- `PLAN.md`

### Analysis Area

- `tool/bench/**`
- `lib/src/interactive/internal/**`
- `test/tool/**`
- `test/interactive/core/**`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-PERFORMANCE-PROOF-CONTOUR` remains the only repository-owned benchmark regression surface in this area.
- `INV-ENG-INTERACTIVE-GESTURE-BUFFER-SOFT-CAP` remains unchanged; the benchmark may observe long-gesture costs but must not weaken gesture-buffer correctness or bounds.
- The mutation-gateway target form remains unchanged: committed eraser deletion still passes through `SceneControllerMutationBoundary`.
- `run_selection_control_diagnostics.dart` remains unchanged; this step must prove ad hoc status without rewriting the runner.

### Required Proof

- behavioral proof: targeted tool tests must fail first for the missing eraser case/probe contract and for the orphaned selection-diagnostic baseline artifact; interactive tests must prove the new projected-point counter semantics at the owner seam.
- structural proof: targeted tool tests must mechanically lock that the eraser benchmark uses `SceneController.interaction.handlePointer(...)` plus internal-access helpers, not direct internal eraser-owner calls; targeted tool tests must also lock that no selection-diagnostic baseline remains committed.
- for bug fixes, regressions, false positives, false negatives, and invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard tests for neighboring branches of the same contract.
- for refactors: existing locking tests must be named or missing characterization tests must be added before structural edits, plus 1 to 3 guard tests for neighboring branches when needed.

### Allowed Change Surface

- Add one eraser probe callback path and one internal-access getter path through existing interactive owners.
- Add one new canonical `full` load-profile case plus policy/diff/baseline contract for it.
- Delete the orphaned selection-diagnostic baseline artifact and tighten runner/workflow tests around its ad hoc status without editing the runner.

### Forbidden Moves

- Do not benchmark `InteractiveDrawEraserEngine` directly from `tool/bench/**`.
- Do not add a benchmark-only runtime owner, benchmark-only controller hook, or benchmark-only mutation shortcut.
- Do not widen the public package API to expose eraser debug probes.
- Do not add a `smoke` eraser case in this step.
- Do not add a selection-diagnostic diff tool, workflow command, or verification-contract expectation in this step.
- Do not keep the orphaned selection-diagnostic baseline file after the step closes.
- Do not edit `tool/bench/run_selection_control_diagnostics.dart` in this step.

### Optional: Allowed Forms That Are Not Violations

- `run_selection_control_diagnostics.dart` may continue to reuse existing load-profile case names and parse their emitted result lines, as long as it remains an ad hoc report generator without a checked-in baseline contract.
- The eraser benchmark may use benchmark-local scene construction helpers in `tool/bench/load_profiles_cases_test.dart`, as long as execution still enters through the public interaction path.

## 10. Vertical Slices

### Slice 1. [ ] Retire Orphaned Selection Diagnostic Baseline

#### Slice Contract

The repository stops implying that selection-control diagnostics are a checked-in regression reference, while the standalone runner remains usable as an ad hoc report generator.

#### Change

- Add one failing tool-test reproducer that rejects any committed selection diagnostic baseline artifact in the canonical benchmark baseline inventory.
- Add 1 to 3 guard tests that keep `run_selection_control_diagnostics.dart` in ad hoc mode:
  - it still parses its current args and output contract;
  - its source/help surface does not gain baseline/diff workflow semantics;
  - nightly workflow and verification-contract tests continue to omit selection-diagnostic benchmark commands.
- Delete `tool/bench/baselines/selection_control_diagnostics_smoke_baseline.json`.
- Keep the runner report format and source unchanged; the ad hoc status is locked by tests plus baseline-artifact retirement, not by a runner rewrite.

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_selection_control_diagnostics_test.dart test/tool/verification_contract_tool_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_selection_control_diagnostics_test.dart test/tool/verification_contract_tool_test.dart`

#### Fixtures Used

- `tool/bench/baselines/selection_control_diagnostics_smoke_baseline.json`

#### Positive Scenarios

- The selection diagnostic runner still parses default and explicit args.
- The runner still extracts and summarizes selection load-profile result lines.

#### Negative Scenarios

- Any committed `selection_control_diagnostics*.json` baseline artifact fails the tool test.
- Any source drift that turns the runner into a baseline/diff-oriented surface fails the tool test.
- Any workflow or verification-contract drift that adds selection diagnostics as a nightly regression command fails the tool test.

#### Closure Evidence

- The committed baseline inventory contains no selection diagnostic baseline files.
- Tool tests explicitly encode the runner as ad hoc and the inventory as canonical-load-profile-only.

### Slice 2. [ ] Add Full Eraser Load-Profile Regression Surface

#### Slice Contract

`load_profiles full` gains one canonical eraser benchmark case that measures the real public interaction path and reports the exact required eraser attribution probes from production owners only.

#### Change

- Add one failing reproducer in `test/tool/bench_run_load_profiles_test.dart` that requires `eraser_long_path_mixed_scene` and its exact `erase_path_commit` probe contract in the full profile.
- Add 1 to 3 guard tests around the same contract:
  - a diff-tool reproducer in `test/tool/bench_diff_load_profiles_test.dart` for missing eraser case/probes;
  - source-level ownership checks that the benchmark case uses `SceneController.interaction.handlePointer(...)`;
  - source-level ownership checks that benchmark probes are read through internal-access helpers instead of direct internal eraser-owner calls.
- Add owner-side failing/guard tests in interactive eraser tests for the new `projectedPointCount` semantics:
  - a projected-path case increments the counter;
  - a fallback-without-projection case leaves the counter at `0`.
- Implement the new projected-point counter at the interactive-owner level and propagate it through the existing internal-access seam.
- Only after the owner-side probe semantics are locked green, implement the canonical eraser load-profile case and report/probe serialization in `tool/bench/load_profiles_cases_test.dart`.
- Only after runner and diff validation require the eraser case and exact probe set, refresh the checked-in full baseline.

#### Behavioral Verification

- `flutter test test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_guardrails_eraser_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart test/tool/bench_diff_load_profiles_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart test/tool/bench_diff_load_profiles_test.dart`

#### Fixtures Used

- `tool/bench/baselines/load_profiles_full_baseline.json`
- benchmark-local mixed-scene eraser fixture data inside `tool/bench/load_profiles_cases_test.dart`

#### Positive Scenarios

- Full policy requires `eraser_long_path_mixed_scene`.
- The eraser case emits `erase_path_commit` metrics and the exact four eraser probes.
- The eraser case deletes a deterministic non-zero set of intended nodes.
- `projectedPointCount` is non-zero for projected-hit paths and remains zero for fallback-only paths.

#### Negative Scenarios

- Missing eraser case in current or baseline reports fails runner/diff validation.
- Missing or non-finite eraser probe values fail runner/diff validation.
- Benchmark source drift to direct internal eraser-owner calls fails source-level ownership checks.
- A zero-delete or fallback-only benchmark shape cannot satisfy the locked mixed-scene case contract.

#### Closure Evidence

- Full load-profile report contract, diff contract, and checked-in full baseline all include the canonical eraser case.
- Interactive tests prove the new projected-point attribution counter semantics without widening the public API.
- Tool tests mechanically lock the public-interaction-path benchmark form and the required eraser probe set.

## 11. Final Verification

- `flutter test test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_guardrails_eraser_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart test/tool/bench_diff_load_profiles_test.dart test/tool/bench_selection_control_diagnostics_test.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

## 12. Acceptance Criteria

- `load_profiles full` has a canonical eraser regression case measured through the real public interaction path.
- Eraser benchmark reports and diffs require `spatialQueryCount`, `preciseSegmentCheckCount`, `projectedPointCount`, and `deletedCount`.
- The eraser attribution counter is owned by interactive runtime owners and exposed only through the existing internal-access seam.
- No checked-in `selection_control_diagnostics` baseline artifact remains in the repository.
- `run_selection_control_diagnostics.dart` still works as an ad hoc diagnostic runner without becoming a second nightly regression gate.
