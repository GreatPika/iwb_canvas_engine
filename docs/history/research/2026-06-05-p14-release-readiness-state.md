---
date: 2026-06-05
researcher: Codex
commit: f5eaaba5
branch: new-architecture
research_question: "What is the current repository state for P14 benchmarks, diagrams, guardrails, and release readiness?"
---

# Research: P14 Release Readiness State

## Summary

P14 is documented as the closing implementation phase for benchmarks, diagrams,
guardrails, donor use, phase alignment, and final release gates. The phase
document states that it closes implementation by proving those surfaces match the
target architecture (`docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:5`),
and it lists benchmark baselines, a benchmark diff tool, blocking guardrails,
guardrail runner closure, release checklist, phase guardrail alignment, and no
app adapters in the engine package as build scope
(`docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:11`,
`docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:20`).

The current repository contains executable guardrail and architecture graph
surfaces for parts of P14 release readiness. The guardrail runner exists and is
registered as the project-owned entrypoint (`docs/verification/guardrails.md:114`),
`api.integration_surface_complete` and `diagnostics.disabled_no_alloc_hot_path`
are registered blocking guardrails (`tool/guardrails/src/guardrail_registry.dart:36`,
`tool/guardrails/src/guardrail_registry.dart:97`), and the app-adapter compile
fixture test exists (`test/api_contract/app_next_engine_adapter_compile_fixture_test.dart:7`).
The current package does not contain the P14-referenced benchmark test
`test/benchmarks/required_cases_test.dart`; the benchmark runner, diff tool, and
baseline JSON files found during this research are under the legacy donor path.

Architecture graph P14 state is active but not closed. P14 is declared in
`docs/architecture/architecture_graph.yaml` with status `measurement`
(`docs/architecture/architecture_graph.yaml:85`,
`docs/architecture/architecture_graph.yaml:87`), and the P14
`release.measurement` node expects a `ReleaseReadiness` declaration
(`docs/architecture/architecture_graph.yaml:498`,
`docs/architecture/architecture_graph.yaml:520`). An observed run of
`dart run tool/architecture_graph/check.dart --phase P14` returned exit code 1
with one missing node violation for `release.measurement`. An observed run of
`dart run tool/architecture_graph/generate_views.dart --phase P14 --check`
returned exit code 1 and reported all five generated graph views stale.

## Detailed Findings

### 1. P14 Phase Contract

- **Location**: `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:1`.
- **Description**: P14 is titled "benchmarks, diagrams, and release readiness"
  and its purpose is to prove that guardrails, diagrams, benchmarks, donor use,
  phase alignment, and final release gates match the target architecture
  (`docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:5`,
  `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:7`).
- **Dependencies**: P14 depends on P0-P13 implementation phases being complete
  with phase-local exit gates green
  (`docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:24`).
  It reads cache policy, diagnostics, guardrails, tests, benchmarks, and final
  release gates (`docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:29`,
  `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:34`).
- **Data flow**: P14 takes existing P0-P13 implementation proof surfaces as
  inputs, then closes cross-cutting proof surfaces: required diagrams,
  benchmark baselines, benchmark diff tooling, blocking guardrails, guardrail
  runner closure, release checklist, phase guardrail alignment, and package
  adapter absence (`docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:11`,
  `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:20`).

### 2. Benchmark Policy and Current Benchmark Files

- **Location**: `docs/verification/benchmarks.md:25`.
- **Description**: The benchmark verification section owns "24. Benchmarks" and
  feeds P14 (`docs/verification/benchmarks.md:2`,
  `docs/verification/benchmarks.md:12`). Its policy states that equivalent
  legacy feature paths have no unapproved regression, new-only paths receive an
  own baseline, hot input paths require avg/P95/max gates, paint paths are
  bounded by candidate count, and memory paths require RSS plus allocation
  budget (`docs/verification/benchmarks.md:29`,
  `docs/verification/benchmarks.md:35`).
- **Dependencies**: The benchmark registry entry depends on frame rendering,
  spatial kernel, and cache policy sections
  (`docs/_registry/sections.yaml:1213`,
  `docs/_registry/sections.yaml:1216`). It registers
  `test.benchmarks.required_cases` as the required test
  (`docs/_registry/sections.yaml:1223`,
  `docs/_registry/sections.yaml:1224`).
- **Data flow**: The policy enumerates required benchmark cases across edit,
  input, frame, resources, projection, codec, load document, spatial, runtime,
  and diagnostics surfaces (`docs/verification/benchmarks.md:37`,
  `docs/verification/benchmarks.md:68`). P14 references
  `test/benchmarks/required_cases_test.dart` as the proof test
  (`docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:107`).
  File search did not find `test/benchmarks/` or
  `test/benchmarks/required_cases_test.dart` in the current package.

### 3. Legacy Benchmark Donor Surface

- **Location**: `legacy/iwb_canvas_engine/tool/bench/run_load_profiles.dart:15`.
- **Description**: The legacy benchmark runner starts `flutter test
  tool/bench/load_profiles_cases_test.dart`, sets `IWB_BENCH_PROFILE`, parses
  `IWB_BENCH_RESULT` lines, validates collected cases and contracts, and writes
  a JSON report (`legacy/iwb_canvas_engine/tool/bench/run_load_profiles.dart:15`,
  `legacy/iwb_canvas_engine/tool/bench/run_load_profiles.dart:27`,
  `legacy/iwb_canvas_engine/tool/bench/run_load_profiles.dart:41`,
  `legacy/iwb_canvas_engine/tool/bench/run_load_profiles.dart:64`,
  `legacy/iwb_canvas_engine/tool/bench/run_load_profiles.dart:101`).
- **Dependencies**: The legacy diff tool reads baseline/current JSON, builds a
  diff report, checks profile/runtime metadata, compares required
  cases/operations/probes, and reports regression failures
  (`legacy/iwb_canvas_engine/tool/bench/diff_load_profiles.dart:12`,
  `legacy/iwb_canvas_engine/tool/bench/diff_load_profiles.dart:67`,
  `legacy/iwb_canvas_engine/tool/bench/diff_load_profiles.dart:82`,
  `legacy/iwb_canvas_engine/tool/bench/diff_load_profiles.dart:137`,
  `legacy/iwb_canvas_engine/tool/bench/diff_load_profiles.dart:167`).
- **Data flow**: Legacy policy defines required metrics `avgUs`, `minUs`,
  `maxUs`, `avgRssDeltaBytes`, `minRssDeltaBytes`, and `maxRssDeltaBytes`
  (`legacy/iwb_canvas_engine/tool/bench/load_profile_policy.dart:1`,
  `legacy/iwb_canvas_engine/tool/bench/load_profile_policy.dart:7`).
  Legacy smoke and full profiles gate `avgUs` at 35% regression
  (`legacy/iwb_canvas_engine/tool/bench/load_profile_policy.dart:145`,
  `legacy/iwb_canvas_engine/tool/bench/load_profile_policy.dart:170`).

### 4. Final Release Gates

- **Location**: `docs/verification/release_gates.md:168`.
- **Description**: The release gates document says release is blocked unless all
  listed statements are true (`docs/verification/release_gates.md:170`). It
  makes selected-phase graph closure a blocking release-gate check through
  `dart run tool/architecture_graph/check.dart --phase Px`
  (`docs/verification/release_gates.md:172`,
  `docs/verification/release_gates.md:180`).
- **Dependencies**: Section 27 must read guardrails, tests, and benchmarks, feeds
  P14, and registers required tests for app adapter compile fixture, frame facts
  guardrail proof, and blocking suite (`docs/verification/release_gates.md:7`,
  `docs/verification/release_gates.md:12`,
  `docs/verification/release_gates.md:83`,
  `docs/verification/release_gates.md:86`).
- **Data flow**: Gates 32-37 require diagrams, phase guardrail alignment,
  generated graph views matching the graph YAML, full guardrail runner success,
  every mandatory guardrail having runner entry and executable proof, benchmark
  gates passing, and absence of `AppCanvasPort`, `LegacyEngineAdapter`, and
  `NextEngineAdapter` from the engine package
  (`docs/verification/release_gates.md:228`,
  `docs/verification/release_gates.md:235`).

### 5. Guardrail Runner and Proof Routes

- **Location**: `docs/verification/guardrails.md:108`.
- **Description**: Guardrails are blocking architecture and release rules, and
  `dart run tool/guardrails/run.dart` is the primary project-owned entrypoint
  (`docs/verification/guardrails.md:110`,
  `docs/verification/guardrails.md:117`). A run without arguments executes the
  full blocking guardrail suite (`docs/verification/guardrails.md:120`).
- **Dependencies**: Runner metadata lives under `tool/guardrails/**` and owns
  executable guardrail ids, suite membership, and dispatch routing
  (`docs/verification/guardrails.md:157`,
  `docs/verification/guardrails.md:160`). The CLI imports the executor and
  registry (`tool/guardrails/run.dart:3`, `tool/guardrails/run.dart:4`).
- **Data flow**: `tool/guardrails/run.dart` selects blocking ids by default,
  `--suite=` via `suiteGuardrailIds`, and `--guardrail=` via
  `guardrailInventory` (`tool/guardrails/run.dart:43`,
  `tool/guardrails/run.dart:55`,
  `tool/guardrails/run.dart:78`). The executor runs proof paths and structural
  checks, caches common Dart-test proof paths, and stops on the first non-zero
  exit code (`tool/guardrails/src/guardrail_executor.dart:53`,
  `tool/guardrails/src/guardrail_executor.dart:70`,
  `tool/guardrails/src/guardrail_executor.dart:101`).

### 6. App Adapter Compile Fixture

- **Location**: `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart:7`.
- **Description**: The test targets
  `test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart`,
  asserts that it imports only `package:iwb_canvas_engine/iwb_canvas_engine.dart`,
  rejects `/src/`, `SceneController`, `NodeSpec`, and `NodePatch`, and checks
  resolver-related public API text
  (`test/api_contract/app_next_engine_adapter_compile_fixture_test.dart:20`,
  `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart:35`).
- **Dependencies**: The test creates a temporary external package, writes the
  fixture into `lib/app_adapter_fixture.dart`, runs `flutter pub get`, and then
  runs `dart analyze lib/app_adapter_fixture.dart`
  (`test/api_contract/app_next_engine_adapter_compile_fixture_test.dart:38`,
  `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart:52`,
  `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart:58`).
- **Data flow**: The fixture imports the root public barrel
  (`test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart:6`)
  and exercises runtime, surface, text overlay, document/state, edit/load,
  selection, camera, tools, commands, resources, actions,
  context-action requests, resolver, and runtime config public surfaces
  (`test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart:8`,
  `test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart:181`).

### 7. Blocking Suite Test

- **Location**: `test/guardrails/blocking_suite_test.dart:13`.
- **Description**: The blocking suite checks that the runner inventory matches
  blocking ids, every inventory entry has a runner route, default dry-run
  selection routes blocking ids, explicit guardrail selection routes one id, and
  suite selections route suite ids (`test/guardrails/blocking_suite_test.dart:13`,
  `test/guardrails/blocking_suite_test.dart:33`,
  `test/guardrails/blocking_suite_test.dart:208`).
- **Dependencies**: It imports guardrail executor, registry, and violation model
  (`test/guardrails/blocking_suite_test.dart:5`,
  `test/guardrails/blocking_suite_test.dart:7`).
- **Data flow**: The test invokes `dart run tool/guardrails/run.dart --dry-run`
  and parses `would run ... via ...` output to derive selected ids
  (`test/guardrails/blocking_suite_test.dart:245`,
  `test/guardrails/blocking_suite_test.dart:254`).

### 8. Diagnostics Hot-Path Proof Scope

- **Location**: `tool/guardrails/src/guardrail_registry.dart:97`.
- **Description**: `diagnostics.disabled_no_alloc_hot_path` is registered as a
  blocking diagnostics guardrail (`tool/guardrails/src/guardrail_registry.dart:97`,
  `tool/guardrails/src/guardrail_registry.dart:99`) and routed to
  `test/diagnostics/disabled_no_alloc_hot_path_test.dart`
  (`tool/guardrails/src/guardrail_executor.dart:204`,
  `tool/guardrails/src/guardrail_executor.dart:206`).
- **Dependencies**: The guardrails document states this guardrail covers
  schema/codec success paths while diagnostics are disabled, with pointer/paint
  hot-path proof deferred until those runtime owners exist
  (`docs/verification/guardrails.md:248`). The tests document states the same
  schema/codec-only subset (`docs/verification/tests.md:463`,
  `docs/verification/tests.md:465`).
- **Data flow**: P14 lists `diagnostics.disabled_no_alloc_hot_path` among its
  proof guardrails
  (`docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:110`).

### 9. Diagram Registry and Catalog

- **Location**: `docs/_registry/diagrams.yaml:578`.
- **Description**: The diagram registry contains five generated architecture
  graph view entries: `generated/full_architecture`,
  `generated/current_phase`, `generated/future_target`,
  `generated/actual_vs_expected_diff`, and `generated/release_verification`
  (`docs/_registry/diagrams.yaml:578`,
  `docs/_registry/diagrams.yaml:618`).
- **Dependencies**: Each generated entry points to
  `docs/architecture/architecture_graph.yaml` as graph view source
  (`docs/_registry/diagrams.yaml:586`,
  `docs/_registry/diagrams.yaml:626`). The generated catalog also states that
  generated graph-backed Mermaid files use that YAML file as source of truth
  (`docs/diagrams/catalog.md:7`, `docs/diagrams/catalog.md:9`).
- **Data flow**: The catalog command examples use `--phase P13`
  (`docs/diagrams/catalog.md:12`, `docs/diagrams/catalog.md:13`). Semantic
  diagram catalog entries include P14 markers, including `c4_context`,
  `dfd_public_edit`, and `state_resource_resolution`
  (`docs/diagrams/catalog.md:62`,
  `docs/diagrams/catalog.md:98`,
  `docs/diagrams/catalog.md:449`).

### 10. Architecture Graph P14 State

- **Location**: `docs/architecture/architecture_graph.yaml:85`.
- **Description**: P14 is declared as "Benchmarks, diagrams, and release
  readiness" with status `measurement`
  (`docs/architecture/architecture_graph.yaml:85`,
  `docs/architecture/architecture_graph.yaml:87`). Its source docs are the P14
  implementation doc and benchmark verification doc
  (`docs/architecture/architecture_graph.yaml:88`,
  `docs/architecture/architecture_graph.yaml:90`).
- **Dependencies**: The P14 graph node is `release.measurement`, has owner
  `release`, is required by P14, and expects declaration `ReleaseReadiness`
  (`docs/architecture/architecture_graph.yaml:498`,
  `docs/architecture/architecture_graph.yaml:503`,
  `docs/architecture/architecture_graph.yaml:520`).
- **Data flow**: Phase closure treats `required`, `future`, and `measurement`
  statuses as required once their phase is active
  (`tool/architecture_graph/src/phase_closure.dart:161`,
  `tool/architecture_graph/src/phase_closure.dart:163`). Missing node evidence
  creates a `missing_required_node` violation
  (`tool/architecture_graph/src/phase_closure.dart:212`,
  `tool/architecture_graph/src/phase_closure.dart:219`).

### 11. Generated Architecture Views

- **Location**: `docs/architecture/architecture_graph.yaml:1609`.
- **Description**: The architecture graph declares five generated view outputs:
  `full_architecture`, `current_phase`, `future_target`,
  `actual_vs_expected_diff`, and `release_verification`
  (`docs/architecture/architecture_graph.yaml:1609`,
  `docs/architecture/architecture_graph.yaml:1646`).
- **Dependencies**: The `release_verification` view sources P14 implementation
  and benchmark docs (`docs/architecture/architecture_graph.yaml:1640`,
  `docs/architecture/architecture_graph.yaml:1646`).
- **Data flow**: Checked-in generated files currently show
  `Selected phase: P13` (`docs/diagrams/generated/full_architecture.mmd:4`,
  `docs/diagrams/generated/current_phase.mmd:4`,
  `docs/diagrams/generated/future_target.mmd:4`,
  `docs/diagrams/generated/release_verification.mmd:4`). The P13
  `future_target` view contains two planned P14 diagnostics edges
  (`docs/diagrams/generated/future_target.mmd:10`,
  `docs/diagrams/generated/future_target.mmd:11`), and
  `release_verification` contains the P14 `release_measurement` node
  (`docs/diagrams/generated/release_verification.mmd:6`).

### 12. Architecture Graph Commands and Tests

- **Location**: `tool/architecture_graph/check.dart:7`.
- **Description**: `check.dart` accepts `--phase`, loads and validates the
  expected graph, extracts the actual graph, runs phase closure, prints the
  formatted report, and exits 0 only when the report is closed
  (`tool/architecture_graph/check.dart:7`,
  `tool/architecture_graph/check.dart:17`,
  `tool/architecture_graph/check.dart:29`,
  `tool/architecture_graph/check.dart:35`).
- **Dependencies**: `generate_views.dart` accepts `--phase`, validates the graph
  and phase, renders graph views, then either checks stale files with `--check`
  or writes outputs (`tool/architecture_graph/generate_views.dart:7`,
  `tool/architecture_graph/generate_views.dart:21`,
  `tool/architecture_graph/generate_views.dart:26`).
- **Data flow**: Generated graph view tests currently select P13
  (`test/architecture_graph/generated_graph_views_test.dart:9`). Schema tests
  assert graph phases include P0-P14 and that P14 status is `measurement`
  (`test/architecture_graph/architecture_graph_schema_test.dart:48`,
  `test/architecture_graph/architecture_graph_schema_test.dart:51`).
  The production closure test currently checks selected P6
  (`test/architecture_graph/phase_closure_checker_test.dart:226`,
  `test/architecture_graph/phase_closure_checker_test.dart:233`).

## Code References

- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:5` -
  P14 purpose begins.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:14` -
  P14 build scope includes benchmark baselines.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:15` -
  P14 build scope includes benchmark diff tool.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:106` -
  P14 references app-adapter compile fixture proof.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:107` -
  P14 references benchmark required-cases proof.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:119` -
  P14 exit gate includes benchmarks passing.
- `docs/verification/benchmarks.md:29` - Benchmark policy text begins.
- `docs/verification/benchmarks.md:37` - Required benchmark cases table begins.
- `docs/verification/release_gates.md:172` - Architecture graph release-gate
  command context.
- `docs/verification/release_gates.md:231` - Full guardrail runner release gate.
- `docs/verification/release_gates.md:234` - Benchmark gates release gate.
- `docs/verification/guardrails.md:114` - Guardrail runner entrypoint.
- `tool/guardrails/src/guardrail_registry.dart:36` -
  `api.integration_surface_complete` registry entry.
- `tool/guardrails/src/guardrail_registry.dart:97` -
  `diagnostics.disabled_no_alloc_hot_path` registry entry.
- `tool/guardrails/src/guardrail_executor.dart:163` -
  app-adapter guardrail proof route.
- `tool/guardrails/src/guardrail_executor.dart:204` -
  diagnostics no-allocation guardrail proof route.
- `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart:38` -
  external-package compile fixture setup begins.
- `test/guardrails/blocking_suite_test.dart:13` - blocking suite tests begin.
- `docs/architecture/architecture_graph.yaml:85` - P14 phase declaration.
- `docs/architecture/architecture_graph.yaml:498` - `release.measurement` node.
- `docs/architecture/architecture_graph.yaml:520` -
  `ReleaseReadiness` expected declaration.
- `docs/architecture/architecture_graph.yaml:1609` - generated graph view
  definitions begin.
- `docs/diagrams/generated/release_verification.mmd:6` - checked-in release
  verification view contains P14 release measurement node.
- `tool/architecture_graph/check.dart:29` - checker invokes phase closure.
- `tool/architecture_graph/generate_views.dart:21` - generator enters check mode.
- `test/architecture_graph/generated_graph_views_test.dart:9` - generated-view
  tests select P13.

## Search Coverage

- **Inspected**: `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md`;
  `docs/verification/benchmarks.md`; `docs/verification/release_gates.md`;
  `docs/verification/guardrails.md`; selected ranges of
  `docs/verification/tests.md`; relevant `docs/_registry/sections.yaml` entries;
  `docs/_registry/diagrams.yaml`; `docs/diagrams/catalog.md`;
  `docs/architecture/architecture_graph.yaml`; all five
  `docs/diagrams/generated/*.mmd`; `tool/guardrails/run.dart`;
  `tool/guardrails/src/guardrail_registry.dart`;
  `tool/guardrails/src/guardrail_executor.dart`;
  `test/guardrails/blocking_suite_test.dart`;
  `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart`;
  `test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart`;
  `tool/architecture_graph/check.dart`;
  `tool/architecture_graph/generate_views.dart`;
  `tool/architecture_graph/src/phase_closure.dart`; architecture graph tests;
  legacy benchmark donor files under `legacy/iwb_canvas_engine/tool/bench/`.
- **Searched**: `P14`, `bench`, `benchmark`, `baseline`, `diff`, `P95`,
  `avgUs`, `alloc bytes`, `RSS`, `required_cases`, `release readiness`,
  `release gates`, `section_24_benchmarks`, `section_27_final_release_gates`,
  `api.integration_surface_complete`, `diagnostics.disabled_no_alloc_hot_path`,
  `blocking_suite`, `app_next_engine_adapter`, `release.measurement`,
  `ReleaseReadiness`, `Selected phase`, `generate_views`, and generated view
  ids across `PLAN.md`, `docs`, `tool`, `test`, and legacy benchmark paths.
- **Not found**: Current-package `test/benchmarks/`; current-package
  `test/benchmarks/required_cases_test.dart`; current-package `tool/bench/`;
  current-package benchmark baseline JSON files; `ReleaseReadiness` declaration
  outside the YAML expectation.
- **Not inspected**: Unrelated production engine implementation outside the
  architecture graph, guardrail, app-adapter fixture, and benchmark proof
  surfaces. Runtime benchmark hook implementation was not inspected because no
  current-package benchmark runner or benchmark test directory was found.

## Observed Architecture Facts

- Pattern observed: P14 is represented as `measurement` phase state in the
  architecture graph rather than an ordinary closed/future phase
  (`docs/architecture/architecture_graph.yaml:85`,
  `docs/architecture/architecture_graph.yaml:87`).
- Pattern observed: The release measurement node is isolated to the
  `release_verification` view and is not a normal runtime production owner
  (`docs/architecture/architecture_graph.yaml:509`,
  `docs/architecture/architecture_graph.yaml:515`).
- Data flow: P14 benchmark contract -> benchmark registry required test ->
  P14 proof list references `test/benchmarks/required_cases_test.dart`
  (`docs/verification/benchmarks.md:17`,
  `docs/_registry/sections.yaml:1224`,
  `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:107`).
- Data flow: Guardrail registry -> guardrail executor -> proof tests routes
  `api.integration_surface_complete` to the app-adapter fixture and
  `diagnostics.disabled_no_alloc_hot_path` to the diagnostics no-allocation test
  (`tool/guardrails/src/guardrail_registry.dart:36`,
  `tool/guardrails/src/guardrail_executor.dart:163`,
  `tool/guardrails/src/guardrail_registry.dart:97`,
  `tool/guardrails/src/guardrail_executor.dart:204`).
- Key dependencies: Final release gates depend on guardrails, tests, benchmarks,
  architecture graph closure, generated graph views, and app-adapter absence
  (`docs/verification/release_gates.md:7`,
  `docs/verification/release_gates.md:10`,
  `docs/verification/release_gates.md:228`,
  `docs/verification/release_gates.md:235`).

## Open Questions

- Whether a current-package `ReleaseReadiness` declaration should exist is not
  answered by this research; the current graph expects it, and searched
  production/tool/test/docs paths did not contain it outside the YAML
  expectation (`docs/architecture/architecture_graph.yaml:520`).
- Whether benchmark gates should be implemented by porting legacy benchmark
  tooling, creating a new runner, or changing the P14 contract is not answered
  by this research. The current observed state is that P14 references benchmark
  baselines, diff tooling, and a benchmark required-cases test
  (`docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:14`,
  `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:107`),
  while those current-package files were not found in the searched paths.
- Whether generated graph views should remain selected at P13 or be regenerated
  for P14 is not answered by this research. The current checked-in generated
  files show `Selected phase: P13`
  (`docs/diagrams/generated/full_architecture.mmd:4`), and the observed
  `--phase P14 --check` command reported stale generated views.
