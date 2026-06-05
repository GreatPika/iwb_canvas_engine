# Change Contract

## Goal

Create the P14 release-readiness benchmark system as executable release proof: a structured benchmark manifest owns required cases and numeric gates, current-package tooling runs and diffs benchmark reports against approved baselines, deterministic CI proves benchmark machinery without noisy timing claims, pinned release measurement blocks release on real regressions, and P14 graph/release gates close without adding runtime feature behavior or public API.

## Source Inputs

- Design: `.design/2026-06-05-p14-release-readiness-benchmarks.md`
- Research: `.research/2026-06-05-p14-release-readiness-state.md`
- Phase: `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md`
- PLAN: `PLAN.md`
- Other: `docs/verification/benchmarks.md`, `docs/verification/release_gates.md`, `docs/verification/guardrails.md`, `docs/verification/tests.md`, `docs/tool/check_docs.dart`, `docs/_registry/sections.yaml`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/architecture_graph.yaml`, `.github/workflows/root_package.yml`, `test/guardrails/root_ci_target_test.dart`, `AGENTS.md`, `legacy/iwb_canvas_engine/tool/bench/load_profile_policy.dart`, `legacy/iwb_canvas_engine/tool/bench/run_load_profiles.dart`, `legacy/iwb_canvas_engine/tool/bench/diff_load_profiles.dart`, external calibration sources recorded in the design, and the user CI constraint supplied on 2026-06-05 that CI must not run DCM.

## Classification

Profile: ANALYZER_RULE

Obligations: SEAM_MIGRATION

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Benchmark cases, scales, budget classes, metric keys, exact invariants, and profile membership are owned by a structured benchmark manifest, with docs generated from or checked against it. | `Boundaries.Source of Truth`, Unit 1 | Manifest schema tests, docs projection checks, and section registry checks prove the manifest is authoritative. |
| `D2` Current-package runner/diff lives under `tool/bench/**`; legacy tooling is adapted, not invoked in place. | `Boundaries.Owner`, `Boundaries.Order Constraints`, Unit 2, Unit 3 | Runner/diff tests and structural scans prove release proof uses current `tool/bench/**`, not `legacy/**`. |
| `D3` Required benchmark proof lives under `test/benchmarks/required_cases_test.dart` and verifies manifest coverage, output schema, dry-run executability, required metrics, and exact invariant names. | Unit 2 | Required-cases dry-run test fails on missing case/scale, missing metric, missing invariant, or non-executable setup. |
| `D4` Numeric gates are two-layered: absolute time caps, first-baseline memory caps, and exact invariants for first-baseline acceptance; current-baseline regression gates for later release diffs. | Unit 1, Unit 3 | Diff fixture tests cover first-baseline rejection, absolute cap failures, memory cap failures, exact invariant failures, and approved-baseline regressions. |
| `D5` Legacy 35 percent `avgUs` is only a bootstrap equivalent-path ceiling; normal approved-baseline regression caps are +15 percent avg/P95, +30 percent max, and +10 percent allocation/RSS. | Unit 1, Unit 3 | Manifest equivalent-path flags and diff fixtures distinguish bootstrap legacy comparison from normal approved-baseline regression policy. |
| `D6` `ReleaseReadiness` is a graph-checkable release tooling declaration, not public API or runtime production code. | `Boundaries.Out of Scope`, Unit 5 | P14 graph checks close `release.measurement`, while public export and production scans prove no public/runtime release-readiness API was added. |
| `D7` P14 benchmark work must not add feature behavior, public API, app adapters, or benchmark-only production hooks. | `Boundaries.Out of Scope`, `Boundaries.Compatibility`, Unit 6 | Structural scans reject public API export changes, app adapter names, benchmark-only production hooks, and package-source legacy imports. |
| `D8` Baseline updates are explicit write operations; release checks read baselines and fail on violations, never silently rewriting approved baselines. | `All-Or-Nothing Failure Boundary`, Unit 3, Unit 4 | Baseline command tests and CI workflow tests prove ordinary PR/release jobs cannot rewrite approved baselines. |
| `D9` P14 graph and generated views must be checked after the release measurement bridge and graph coverage updates. | `Boundaries.Order Constraints`, Unit 5 | `dart run tool/architecture_graph/check.dart --phase P14` and `dart run tool/architecture_graph/generate_views.dart --phase P14 --check` are required after graph coverage changes. |
| `D10` CI is split by purpose and excludes DCM: PR CI proves benchmark machinery deterministically, nightly/release CI proves measured performance on a pinned runner, and baseline update is manual and fail-closed. | Unit 4, Unit 6 | Root CI structural tests reject `continue-on-error`, benchmark skips, silent baseline rewrites, and `dcm analyze` / `dcm calculate-metrics` in CI workflows. |
| Design run-profile policy: canonical profile names are `dry_run`, `smoke`, and `release`; `dry_run` uses one iteration and one repetition without timing claims; `smoke` uses one warmup, three measured repetitions, and at least 500 ms measured time per operation or at least 100 samples; `release` uses one warmup, five measured repetitions, and at least 2000 ms measured time per microbenchmarkable operation. | Unit 1, Unit 2, `Boundaries.Source of Truth` | Manifest/profile tests fail when a profile name, warmup count, repetition count, minimum measured duration, sample fallback, or timing-claim policy differs from the design. |
| Design spelling conflict: the run-profile section uses `dry_run`, while the later entry-boundary handoff says `dry-run`. | `Boundaries.Source of Truth`, Unit 1, Unit 2 | Contract selects `dry_run` as the normative profile spelling because it is the named run profile in the policy table; tests reject `dry-run` as a non-canonical handoff typo. |
| Repository release contour decision: P14 release measurements run on GitHub-hosted `ubuntu-24.04` with `subosito/flutter-action@v2`, `channel: stable`, `flutter-version: 3.38.0`, matching the package's minimum Flutter constraint while making the release runtime explicit. | `Boundaries.Source of Truth`, Unit 3, Unit 4 | Report metadata and CI structural tests require runner label, OS name/version, Flutter version, Dart version, runtime mode, assertion state, debug invariant mode, profile, and manifest version before diffing. |
| Repository baseline placement decision: `tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json` is the committed approved-baseline location, but Unit 3 may leave it as a fail-closed uninitialized placeholder until a pinned release/manual baseline update produces a measured accepted baseline. Candidate/current/diff reports are transient under `build/bench/**`. | `Boundaries.Source of Truth`, `All-Or-Nothing Failure Boundary`, Unit 3, Unit 4 | Diff and CI tests prove release reads only the approved path, fails closed while that path is uninitialized, and manual baseline update writes measured approved baselines only after candidate acceptance. |
| Repository manifest placement decision: benchmark policy source of truth is `docs/_registry/benchmarks.yaml`, parsed and schema-validated by `tool/bench/src/benchmark_manifest.dart`; `docs/verification/benchmarks.md` is a structurally checked projection, not a generated source. | `Boundaries.Source of Truth`, Unit 1 | Manifest schema tests and docs checks fail when section 24 in `docs/verification/benchmarks.md` drifts from `docs/_registry/benchmarks.yaml`. |
| Repository release graph bridge placement decision: `ReleaseReadiness` is declared in `tool/bench/src/release_readiness.dart`, which is covered by the existing release owner path prefix `tool/`. | Unit 5 | P14 graph tests prove `release.measurement` closes from `tool/bench/src/release_readiness.dart`; public export scans prove it stays out of public API. |

## Evidence

- `.design/2026-06-05-p14-release-readiness-benchmarks.md:13` / disposition: design is `READY_FOR_CONTRACT` -> write a full step contract rather than a blocker.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:17` / product outcome: P14 release readiness requires executable benchmark/release-measurement proof -> contract must create release-blocking benchmark machinery, not prose-only policy.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:29` / classification: selected profile is `ANALYZER_RULE` with `SEAM_MIGRATION` -> contract units must define a rule/tooling proof seam and adapt legacy donor tooling into the rebuilt package.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:64` / CI constraint: CI must not run DCM -> CI workflow units must reject DCM commands while local verification still reports DCM when available.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:337` / future pressure: PR CI proves machinery while nightly/release CI proves measured performance on a pinned runner -> CI unit must split deterministic PR checks from release measurement.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:402` / run profiles: `smoke`, `release`, and `dry_run` have fixed warmup, repetition, minimum-duration/sample, and timing-claim policies -> runner/profile configuration must be contract-locked and directly tested.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:515` / entry boundary: late handoff spells the dry-run entry as `dry-run`, while the normative run-profile section spells it `dry_run` -> contract resolves the source-input spelling conflict by making `dry_run` canonical and requiring tests to reject `dry-run`.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:416` / CI policy: PR CI runs schema, required-cases dry-run, diff fixtures, docs projection, analyze, and guardrails, and fails closed -> CI unit must wire those checks without `continue-on-error`.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:421` / CI policy: benchmark machinery must not be skipped after benchmark files exist -> root CI structural proof must cover skip/bypass routes.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:428` / CI policy: nightly/release CI blocks on time, memory, exact-invariant, metadata, graph, generated view, or guardrail failures -> release workflow must consume diff and graph/guardrail proof.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:459` / D3: required proof lives at `test/benchmarks/required_cases_test.dart` -> required-cases proof placement is locked.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:462` / D6: `ReleaseReadiness` is graph-checkable release tooling -> graph bridge belongs to release tooling, not public API or runtime production owners.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:466` / D10: CI lane split and DCM exclusion are locked -> CI structural tests must prove no CI lane invokes DCM.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:642` / source-of-truth impact: structured benchmark manifest owns case ids, scales, metrics, exact invariants, budget classes, profile membership, and equivalent-legacy classification -> manifest must be the single policy source of truth.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:674` / verification impact: required-cases test must prove executable dry-run, required metrics, and named invariants -> compile-only benchmark proof is insufficient.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:690` / verification impact: CI includes pinned release measurement, manual baseline update, and DCM rejection -> workflow proof belongs in the contract.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:729` / handoff: D1 through D10 must be preserved -> Decision Trace maps all ten design decisions into units and proof surfaces.
- `.design/2026-06-05-p14-release-readiness-benchmarks.md:782` / open decisions: none -> implementation should not re-decide numeric policy, owner, benchmark seam, baseline boundary, graph bridge, CI split, or no-feature P14 boundary.
- `.github/workflows/root_package.yml:12` / existing CI contour: root package CI currently runs on Ubuntu -> release benchmark CI should use an explicit Ubuntu runner label instead of leaving the machine contour implicit.
- `.research/2026-06-05-p14-release-readiness-state.md:31` / current state: current package lacks `test/benchmarks/required_cases_test.dart`; runner, diff, and baselines found only under legacy donor path -> contract must create current-package benchmark seam.
- `.research/2026-06-05-p14-release-readiness-state.md:42` / observed graph check: P14 graph check failed on missing `release.measurement` -> graph unit must add `ReleaseReadiness` and graph coverage before claiming closure.
- `.research/2026-06-05-p14-release-readiness-state.md:93` / search result: `test/benchmarks/` and required-cases proof are absent -> Unit 2 must add the required proof surface.
- `.research/2026-06-05-p14-release-readiness-state.md:391` / not found inventory: current package lacks `test/benchmarks/**`, `tool/bench/**`, benchmark baseline JSON, and `ReleaseReadiness` -> contract scope includes all four creation paths.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:14` / P14 build scope: benchmark baselines are in scope -> approved baseline artifacts and acceptance policy belong in this step.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:15` / P14 build scope: benchmark diff tool is in scope -> current-package diff tool is required.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:107` / P14 proof list: `test.benchmarks.required_cases` maps to `test/benchmarks/required_cases_test.dart` -> required-cases test placement is fixed.
- `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md:137` / P14 risk boundary: phase must not introduce new feature behavior -> production feature work and public API changes are out of scope.
- `docs/verification/benchmarks.md:29` / benchmark policy: equivalent legacy paths need no unapproved regression, new-only paths need baselines, hot paths need avg/P95/max gates, paint paths need candidate bounds, and memory paths need RSS/allocation budgets -> manifest/diff policy must encode these metric families.
- `docs/verification/benchmarks.md:37` / required cases table: benchmark cases span edit, input, frame, resources, projection, codec, load, spatial, runtime, and diagnostics -> required-cases proof must be cross-owner and manifest-driven.
- `docs/verification/release_gates.md:234` / final gate: benchmark gates must pass -> diff failures must block release.
- `docs/architecture/02_package_boundaries.md:259` / test layout: cross-cutting proof includes `test/benchmarks/**` -> required-cases proof belongs outside a single production-owner mirror.
- `docs/tool/check_docs.dart:6` / docs tooling: runtime architecture constraints belong in structured registries, generated docs, analyzer/lint rules, Dart tests, or benchmarks -> benchmark policy must be structured and mechanically checked, not free-form Markdown duplication.
- `docs/architecture/architecture_graph.yaml:498` / graph node: `release.measurement` exists -> P14 release measurement closure is graph-owned.
- `docs/architecture/architecture_graph.yaml:520` / graph declaration: node expects `ReleaseReadiness` -> graph bridge declaration is required.
- `tool/architecture_graph/src/phase_closure.dart:21` / release owner coverage: release owner path prefixes include `tool/` and `docs/verification/` -> `tool/bench/src/release_readiness.dart` is an accepted release tooling location for `ReleaseReadiness`.
- `pubspec.yaml:8` / package environment: package requires Flutter `>=3.38.0` -> pinned release measurement contour uses Flutter `3.38.0` as the selected baseline runtime.
- `legacy/iwb_canvas_engine/tool/bench/load_profile_policy.dart:145` / legacy policy: smoke profile allowed 35 percent `avgUs` regression -> use legacy 35 percent only as bootstrap equivalent-path ceiling.
- `legacy/iwb_canvas_engine/tool/bench/diff_load_profiles.dart:82` / legacy diff: runtime metadata mismatch is rejected -> current diff must fail metadata contour mismatches before numeric comparison.
- `legacy/iwb_canvas_engine/tool/bench/diff_load_profiles.dart:137` / legacy diff: missing required cases are rejected -> current diff/required-cases proof must fail exact inventory gaps.
- `.github/workflows/root_package.yml:3` / CI workflow: current root package workflow runs on PRs and selected pushes -> PR-safe benchmark machinery checks belong in this workflow or a structurally equivalent root CI lane.
- `test/guardrails/root_ci_target_test.dart:40` / CI structural test: root CI rejects `continue-on-error` bypasses -> benchmark CI integration must extend this fail-closed proof.
- `AGENTS.md:67` / repository verification: documentation-only changes run docs checks, while code/tool changes run Dart/DCM locally -> implementation must report local DCM availability without adding DCM to CI.

## Boundaries

Owner:

Release benchmark readiness owns the P14 benchmark manifest, current-package benchmark runner/diff tooling, approved baseline acceptance policy, CI benchmark machinery/release workflows, release graph bridge, and release-gate proof. `docs/_registry/benchmarks.yaml` owns benchmark policy data. `tool/bench/**` owns manifest schema parsing, runner, diff, report schema, baseline update commands, approved baseline artifacts, and `tool/bench/src/release_readiness.dart`. `test/benchmarks/**` owns required-case/dry-run/proof fixtures. Documentation/registry surfaces own the structurally checked human projection in `docs/verification/benchmarks.md`. Architecture graph tooling owns extraction/checking of the `ReleaseReadiness` graph declaration. Production `lib/**` owners remain responsible only for existing P0-P13 behavior that benchmarks observe.

In Scope:

Create `docs/_registry/benchmarks.yaml` as the structured benchmark manifest that owns case ids, scales, budget classes, required metrics, exact invariants, profile membership, equivalent-legacy flags, first-baseline memory scopes, and fixed run-profile parameters. Create current-package `tool/bench/**` runner, report schema, `dry_run`/`smoke`/`release` profiles, diff policy, deterministic fixture tests, and explicit baseline update path. The exact CLI entrypoints are `dart run tool/bench/run.dart`, `dart run tool/bench/diff.dart`, and `dart run tool/bench/update_baseline.dart`; do not replace them with alternate repository-equivalent commands. Add `test/benchmarks/required_cases_test.dart` to prove manifest coverage, dry-run executability, output schema, required metrics, and exact invariant names. Update docs checking so `docs/verification/benchmarks.md` is structurally checked against `docs/_registry/benchmarks.yaml`, not generated and not independent policy. Wire deterministic PR CI benchmark machinery checks and fail-closed structural tests. Add pinned nightly/release measurement workflow on `ubuntu-24.04` with Flutter `3.38.0` stable and manual baseline-update workflow without DCM. Add graph-checkable `ReleaseReadiness` declaration at `tool/bench/src/release_readiness.dart`, generated graph view updates, guardrail/release docs routing, and final structural scans.

Out of Scope:

Do not add runtime feature behavior, public API changes, app adapters, legacy facades, or benchmark-only production hooks. Do not invoke legacy benchmark tooling in place as release proof. Do not make Markdown tables, approved baseline JSON, generated docs, current reports, or diff reports define benchmark cases or thresholds. Do not let ordinary PR or release workflows rewrite approved baselines. Do not compare benchmark reports across different case ids, profiles, runtime modes, operating systems, SDK/runtime versions, or machine contours. Do not add `dcm analyze` or `dcm calculate-metrics` to any CI workflow. Do not claim example parity or full product release readiness if Step 52 remains incomplete; this step may close package-level P14 benchmark/release-measurement machinery, but final release readiness still depends on all active roadmap prerequisites.

Source of Truth:

`docs/_registry/benchmarks.yaml` is the single source of truth for benchmark policy: case ids, scales, budget classes, required metrics, exact invariants, profile membership, equivalent-legacy classification, first-baseline memory scopes, and run-profile parameters. `tool/bench/src/benchmark_manifest.dart` owns schema parsing/validation for that file, but not the policy data itself. Canonical profile names are `dry_run`, `smoke`, and `release`; `dry_run` is the only spelling accepted by manifest/tool/tests/CI. `docs/verification/benchmarks.md` is a structurally checked human projection; `dart run docs/tool/check_docs.dart` must fail if section 24 cases, metrics, invariants, profile names, or numeric gates drift from `docs/_registry/benchmarks.yaml`. The approved baseline path is `tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json`; before a pinned release/manual update accepts real measurements, that file may contain only a fail-closed uninitialized placeholder with no cases, metrics, thresholds, or measured values. Once initialized by `dart run tool/bench/update_baseline.dart`, approved baseline JSON owns measured reference values and run context only, still not case definitions or thresholds. Candidate baseline reports are transient under `build/bench/candidates/release_ubuntu_24_04_flutter_3_38_0/`, current release reports are transient at `build/bench/current/release_ubuntu_24_04_flutter_3_38_0.json`, and diff reports are transient at `build/bench/diff/release_ubuntu_24_04_flutter_3_38_0.json`. The selected pinned release contour is GitHub-hosted `ubuntu-24.04`, `subosito/flutter-action@v2`, `channel: stable`, `flutter-version: 3.38.0`. Release report metadata must record runner label, OS name/version, Flutter version, Dart version, runtime mode, assertion state, debug invariant mode, profile, manifest version/hash, and benchmark tool schema version. `docs/architecture/architecture_graph.yaml` remains the source of truth for P14 graph obligations and generated graph views. `ReleaseReadiness` declaration placement is `tool/bench/src/release_readiness.dart`. CI workflows own execution routing only; they must consume manifest/tooling policy, not duplicate numeric gates.

Compatibility:

Existing public API signatures, exports, schema formats, production runtime behavior, and app-adapter bans must remain compatible. Benchmark tooling may observe existing public/internal test seams through normal test/tool boundaries, but production code must not import or depend on benchmark tooling. Equivalent legacy feature paths are compared only where a donor-equivalent current path exists; new-only paths require first-baseline acceptance against absolute time, memory, and exact-invariant caps before becoming release-approved.

Dependency/import direction:

Allowed: `tool/bench/**` may import package code and tool-local manifest/report models; tests under `test/benchmarks/**` may use test fixtures and package APIs; docs/check tools may read the manifest and generated projection. The only benchmark CLI boundaries are `dart run tool/bench/run.dart`, `dart run tool/bench/diff.dart`, and `dart run tool/bench/update_baseline.dart`. Forbidden: `lib/** -> tool/bench/**`, production source -> benchmark fixtures, current benchmark release proof -> `legacy/**`, alternate benchmark release CLI entrypoints, CI -> DCM commands, and public API exports solely for benchmarking.

Order Constraints:

Unit 1 establishes `docs/_registry/benchmarks.yaml`, fixed profile parameters, and structural docs projection checks before any runner or diff trusts benchmark policy. Unit 2 adds runner, report schema, profiles, dry-run executability, smoke command proof, and required-cases proof before measured results are interpreted. Unit 3 adds diff, baseline acceptance, and deterministic fixtures before CI or release gates trust benchmark output. Unit 4 wires CI lanes only after deterministic machinery tests exist, and the release lane must fail closed on benchmark diff, graph check, generated-view check, and guardrail runner failures. Unit 5 adds `ReleaseReadiness` at `tool/bench/src/release_readiness.dart`, generated graph views, and release routing after the benchmark seam exists. Unit 6 performs final guardrail/docs/compatibility closure after all release-measurement surfaces exist. P14 graph/generated-view checks run after graph declaration changes. Final release readiness remains dependent on all active roadmap prerequisites, including Step 52 if it remains open.

Temporal Surface Closure:

Not applicable to runtime callbacks, observers, public-state publication, or reentrant mutation windows. The temporal surface here is CLI/workflow sequencing: manifest read -> dry-run/report validation -> baseline acceptance or diff validation -> release decision. No runtime mutation surface is introduced.

All-Or-Nothing Failure Boundary:

The irreversible points are approved baseline write/approval and release acceptance. Fallible work before baseline approval includes benchmark execution, report schema validation, runtime contour metadata capture, absolute time cap validation, first-baseline memory cap validation, exact invariant validation, and equivalent-legacy bootstrap comparison. Fallible work before release acceptance includes current report validation, metadata compatibility, missing-case checks, missing-metric checks, exact invariant checks, approved-baseline regression checks, graph checks, generated view checks, and guardrail checks. Approved baseline writes to `tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json` occur only through `dart run tool/bench/update_baseline.dart` or the manual baseline-update workflow after candidate acceptance checks pass. Until that write happens, the committed approved-baseline path remains an uninitialized fail-closed placeholder and ordinary release diff must fail rather than inventing baseline numbers. Ordinary PR and release workflows are read-only with respect to approved baselines and may write only transient candidate/current/diff outputs under `build/bench/**`. Failure projection is non-zero command/workflow exit plus JSON/text failure report; no failing path may silently rewrite baselines or mark release ready.

## Execution Units

### [x] Unit 1: Benchmark manifest and docs source of truth

Owner:

`docs/_registry/benchmarks.yaml`, `tool/bench/src/benchmark_manifest.dart`, docs projection/check tooling, `docs/verification/benchmarks.md`, `docs/_registry/sections.yaml` if needed, and manifest schema tests.

Boundary:

Create the single authoritative benchmark policy file and connect human docs to it through structural checks. This unit does not implement measured benchmark cases, runner timing loops, diff comparisons, CI workflows, or graph closure.

Change:

Add `docs/_registry/benchmarks.yaml` with every required section 24 case/scale, metric key, exact invariant, budget class, first-baseline memory scope, profile membership, equivalent-legacy/new-only classification, and run-profile parameter from the design. Add `tool/bench/src/benchmark_manifest.dart` to parse and schema-validate this YAML without duplicating policy constants outside the manifest. Encode the design numeric policy in the YAML: `hot_input`, `incremental_edit`, `frame_capture`, `query_read`, `resource_budgeted`, `bulk_io`, `exact_invariant`, and `allocation_budget`, including first-baseline memory caps and post-baseline regression caps. Encode canonical profiles exactly: `dry_run` uses one iteration and one repetition of every manifest case/scale and validates setup/output without timing claims; `smoke` uses the smallest required scale per case, preserves dense special cases, runs one warmup and three measured repetitions, and requires minimum 500 ms measured time per operation or at least 100 samples; `release` runs all required scales, one warmup, five measured repetitions, and minimum 2000 ms measured time per operation where the operation is microbenchmarkable. Update `dart run docs/tool/check_docs.dart` so `docs/verification/benchmarks.md` section 24 is structurally checked against `docs/_registry/benchmarks.yaml`; do not generate benchmark docs in this step. Update `docs/_registry/sections.yaml` only if needed to point section 24 at `docs/_registry/benchmarks.yaml` as the benchmark policy source.

Completion Check:

Manifest schema tests fail on duplicate case/scale entries, missing required section 24 cases, missing budget class mapping, missing required metric, missing exact invariant name, missing profile membership, invalid equivalent-legacy classification, threshold values that differ from the design, any non-canonical `dry-run` spelling, or profile parameters that differ from the design warmup/repetition/minimum-duration/sample/timing-claim policy. Documentation checks prove `docs/verification/benchmarks.md` section 24 is structurally checked against `docs/_registry/benchmarks.yaml` and no longer owns independent benchmark policy; a fixture or mutation test fails when a case/metric/gate is changed in the docs but not in the YAML, or vice versa. `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` pass after any docs changes. Owner-scoped local verification for changed docs/tool code includes the relevant Dart tests plus `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics` for changed tool scopes when DCM is available locally; these local DCM checks are not added to CI.

Depends On:

None.

### [x] Unit 2: Current-package runner, profiles, and required-case dry-run proof

Owner:

`tool/bench/**`, `test/benchmarks/**`, runner/report schema tests, required-cases dry-run fixtures, and any benchmark fixture data under test-owned paths.

Boundary:

Adapt the legacy donor runner shape into current package tooling and prove required benchmark cases are executable without making timing claims. This unit does not approve baselines, compare reports, update CI, or close graph/release gates.

Change:

Create exact runner entrypoint `dart run tool/bench/run.dart --profile=dry_run|smoke|release`. The runner reads the manifest, accepts only canonical profile names, validates case/profile selection, emits JSON reports with runtime/machine/profile metadata, and enforces the manifest profile parameters. `dry_run` executes one iteration and one repetition per manifest case/scale and never emits timing pass/fail claims. `smoke` uses one warmup, three measured repetitions, and minimum 500 ms measured time per operation or at least 100 samples. `release` uses one warmup, five measured repetitions, and minimum 2000 ms measured time per operation where the operation is microbenchmarkable. Release run output path is `build/bench/current/release_ubuntu_24_04_flutter_3_38_0.json` unless a command-line `--output=` explicitly selects another transient `build/bench/**` path for local experimentation. Add current-package benchmark case implementations or case adapters for every required manifest entry using existing P0-P13 owner-observable behavior and test/tool boundaries. Create `test/benchmarks/required_cases_test.dart` to prove every manifest case/scale is present, dry-run executable, emits the required report schema, required metrics, and required exact invariant names. Keep legacy benchmark files as donor inputs only; current release proof must not call `legacy/**`.

Completion Check:

Focused runner tests prove `dry_run` validates setup and report shape without timing assertions, rejects `dry-run`, runs one iteration/repetition, and emits no timing release claims; `smoke` uses one warmup, three measured repetitions, and minimum 500 ms or 100 samples; `release` uses one warmup, five measured repetitions, and minimum 2000 ms for microbenchmarkable operations; profile selection comes from the manifest; runtime/machine/profile metadata is recorded; release output defaults to `build/bench/current/release_ubuntu_24_04_flutter_3_38_0.json`; and unsupported/missing case ids fail closed. `test/benchmarks/required_cases_test.dart` fails on any missing required case/scale, missing metric, missing invariant, non-executable dry-run setup, or direct dependency on `legacy/**`. A structural test or guardrail scan proves current benchmark release proof invokes only `dart run tool/bench/run.dart` and not alternate runner entrypoints or legacy paths. `dart run tool/bench/run.dart --profile=smoke` passes as the local benchmark sanity command and writes a valid smoke report under `build/bench/current/` without performing release diff or baseline writes. Focused benchmark tests and runner tests pass, and local verification includes `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics tool/bench test/benchmarks` when DCM is available locally.

Depends On:

Unit 1.

### [x] Unit 3: Diff, baseline acceptance, and deterministic policy fixtures

Owner:

`tool/bench/diff.dart`, `tool/bench/update_baseline.dart`, approved baseline path `tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json`, deterministic JSON fixture tests under benchmark/tool test ownership, and release diff documentation.

Boundary:

Implement release-blocking interpretation of benchmark reports and explicit baseline approval. This unit does not wire CI, graph closure, final release gates beyond local commands/tests, or require producing a real measured approved baseline; measured baseline initialization belongs to a pinned release/manual update path and must stay fail-closed until that path runs.

Change:

Create exact diff entrypoint `dart run tool/bench/diff.dart --profile=release --baseline=tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json --current=build/bench/current/release_ubuntu_24_04_flutter_3_38_0.json --output=build/bench/diff/release_ubuntu_24_04_flutter_3_38_0.json`. The diff reads the approved-baseline path and current report, fails closed if the approved-baseline path is still an uninitialized placeholder, validates same case/profile/runtime/machine contour metadata for initialized baselines, rejects missing cases or metrics, applies absolute caps and exact invariants, applies first-baseline memory caps before approval, applies equivalent-legacy bootstrap `avgUs <= legacy * 1.35` only for equivalent paths, and applies approved-baseline regression caps after bootstrap. Add exact manual baseline-update entrypoint `dart run tool/bench/update_baseline.dart --profile=release --candidate=build/bench/candidates/release_ubuntu_24_04_flutter_3_38_0/<timestamp>.json --approved=tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json`. This command can write an initialized approved baseline only after first-baseline time, memory, exact-invariant, and pinned observed-contour checks pass; those checks must match the runner's real top-level metadata shape by requiring the pinned runner label derived from runner image metadata, observed Linux OS metadata, and the pinned Flutter channel/version, while the nested `releaseContour` records the manifest-owned Ubuntu 24.04 contour. Do not treat GitHub's `RUNNER_NAME` as the `runs-on` label. Unit 3 may commit a fail-closed uninitialized placeholder at the approved path; it must contain no measured values, cases, thresholds, or policy data. Ensure initialized approved baselines written by the update command store measured values and run context only, not case definitions or thresholds.

Completion Check:

Deterministic diff fixture tests fail for uninitialized approved-baseline placeholder, metadata mismatch, missing case, missing metric, absolute time cap violation, first-baseline memory cap violation, exact invariant violation, bootstrap legacy ceiling violation, approved-baseline avg/P95/max regression, allocation/RSS regression, rejected first baseline, and any attempt by ordinary diff/release mode to rewrite approved baselines. Metadata mismatch tests include runner label, OS name/version, Flutter version, Dart version, runtime mode, assertion state, debug invariant mode, profile, manifest version/hash, and benchmark tool schema version. A positive fixture proves a valid same-contour current report passes after `dart run tool/bench/update_baseline.dart` temporarily installs an accepted deterministic candidate at `tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json`; the committed Unit 3 baseline file may remain the uninitialized fail-closed placeholder and must not contain synthetic measured numbers. Command-level tests prove `dart run tool/bench/update_baseline.dart` is the only approved-baseline write path and `dart run tool/bench/diff.dart` is read-only. Focused tool tests pass without running the full benchmark suite or release benchmark matrix, and local verification includes `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics tool/bench test/benchmarks` when DCM is available locally.

Depends On:

Unit 1 and Unit 2.

### [x] Unit 4: CI benchmark lanes and fail-closed workflow proof

Owner:

`.github/workflows/**`, `test/guardrails/root_ci_target_test.dart`, CI workflow structural fixtures/tests, and benchmark CI documentation/routing.

Boundary:

Wire benchmark machinery into CI with the design lane split. This unit does not make PR CI perform noisy timing release measurements and does not add DCM to CI.

Change:

Update the root PR CI lane or structurally equivalent workflow so PR CI always runs deterministic benchmark machinery checks: manifest/schema tests, required-cases dry-run, diff fixture tests, docs projection checks, `dart analyze`, and the guardrail runner. Add or update nightly/release workflow routing to run on `ubuntu-24.04`, set up Flutter through `subosito/flutter-action@v2` with `channel: stable` and `flutter-version: 3.38.0`, run `dart run tool/bench/run.dart --profile=release`, run `dart run tool/bench/diff.dart --profile=release --baseline=tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json --current=build/bench/current/release_ubuntu_24_04_flutter_3_38_0.json --output=build/bench/diff/release_ubuntu_24_04_flutter_3_38_0.json`, and fail closed on benchmark diff, P14 graph check, P14 generated-view check, and guardrail runner failures. Add a separate manual baseline-update workflow or documented manual command path that writes candidates under `build/bench/candidates/release_ubuntu_24_04_flutter_3_38_0/` and cannot auto-approve or auto-commit approved baselines from ordinary PR/release jobs. Update root CI structural tests to reject `continue-on-error`, job-level/per-step bypasses, path skips that exclude benchmark machinery after benchmark files exist, silent baseline rewrites, missing or different pinned release contour, missing release-lane graph/generated-view/guardrail checks, and any `dcm analyze` or `dcm calculate-metrics` command in CI workflows.

Completion Check:

CI structural tests fail on fixture/workflow examples with `continue-on-error`, benchmark machinery skips, missing PR docs projection checks, ordinary workflow baseline writes, release workflow baseline writes, release workflow not using `ubuntu-24.04`, release workflow not pinning Flutter `3.38.0` stable, missing release-lane benchmark run/diff exact commands, missing release-lane P14 graph check, missing release-lane P14 generated-view check, missing release-lane guardrail runner, or DCM commands. Positive workflow tests prove PR CI includes deterministic benchmark checks, docs projection, analyze, and guardrails; nightly/release CI includes release profile plus diff on the selected contour and blocks on benchmark diff, graph, generated-view, and guardrail failures; and manual baseline update is separate from PR/release readiness. No CI workflow contains `dcm analyze` or `dcm calculate-metrics`. Focused guardrail/CI tests pass, and local verification includes `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics test/guardrails tool/guardrails` when DCM is available locally.

Depends On:

Unit 2 and Unit 3.

### [x] Unit 5: ReleaseReadiness graph bridge and P14 generated view closure

Owner:

`tool/bench/src/release_readiness.dart`, `docs/architecture/architecture_graph.yaml`, generated architecture graph views, and graph closure tests.

Boundary:

Make P14 release measurement graph-checkable from the exact release tooling file without creating public API or runtime production behavior. This unit does not change benchmark numeric policy or CI lane behavior.

Change:

Add graph-checkable declaration `ReleaseReadiness` in `tool/bench/src/release_readiness.dart`. Do not place this declaration under `lib/**`, `docs/**`, or a public API facade. Preserve `release.measurement` as release owner and measurement scope. Rely on the existing release owner path prefix `tool/`; update graph coverage only if implementation evidence proves `tool/bench/src/release_readiness.dart` is not extracted, and then keep the update scoped to that exact tool path. Regenerate generated graph views after graph declaration or coverage changes. Ensure the declaration represents release benchmark readiness tooling, not a public runtime class, production feature, or app adapter.

Completion Check:

`dart run tool/architecture_graph/check.dart --phase P14` passes and would fail if `ReleaseReadiness` is missing from `tool/bench/src/release_readiness.dart` or placed outside accepted release tooling coverage. `dart run tool/architecture_graph/generate_views.dart --phase P14 --check` passes after generated views are updated. Public API/export tests and structural scans prove `ReleaseReadiness` is not exported from the public barrel and no runtime production owner imports benchmark/release tooling. Architecture-focused tests pass, and local verification includes `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics tool/bench tool/architecture_graph` when DCM is available locally.

Depends On:

Unit 1, Unit 2, and Unit 3.

### [ ] Unit 6: Release gate, guardrail, compatibility, and final proof closure

Owner:

`docs/verification/release_gates.md`, `docs/verification/guardrails.md`, `docs/verification/tests.md`, guardrail runner metadata/routes, final structural scans, benchmark release command documentation, and final verification checklist.

Boundary:

Connect benchmark readiness to the existing release proof flow and close compatibility/no-feature boundaries. This unit does not add new benchmark cases or production feature behavior beyond what earlier units already established.

Change:

Route benchmark release proof through the existing guardrail/release readiness flow so benchmark failures block release alongside graph/generated-view and guardrail failures. Update guardrail runner metadata or docs only where needed to make benchmark readiness discoverable and executable. Add structural scans for no public API export changes, no `AppCanvasPort`, `LegacyEngineAdapter`, or `NextEngineAdapter` in package source, no legacy imports in benchmark release proof, no benchmark-only production hooks, and no approved baseline rewrites outside the manual update path. Update verification docs/tests inventories to name the new benchmark, CI, graph, and release proof surfaces without duplicating numeric policy.

Completion Check:

`dart run tool/guardrails/run.dart` includes the required benchmark readiness proof route or documented release proof route and fails closed on benchmark diff violations. Release-gate tests or structural scans fail if benchmark gates are absent, if public API exports change for P14 benchmarking, if app adapter names are present in package source, if current benchmark release proof invokes `legacy/**`, if production source contains benchmark-only hooks, or if approved baselines can be rewritten outside the manual update path. Final local verification includes focused benchmark/tool/guardrail tests, `dart run tool/bench/run.dart --profile=smoke`, `dart run tool/bench/run.dart --profile=release`, `dart run tool/bench/diff.dart --profile=release --baseline=tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json --current=build/bench/current/release_ubuntu_24_04_flutter_3_38_0.json --output=build/bench/diff/release_ubuntu_24_04_flutter_3_38_0.json`, `dart analyze`, `dcm analyze .`, relevant `dcm calculate-metrics` scopes, `dart run docs/tool/sync_generated_docs.dart --check`, `dart run docs/tool/check_docs.dart`, `dart run tool/architecture_graph/check.dart --phase P14`, and `dart run tool/architecture_graph/generate_views.dart --phase P14 --check`. If Step 52 remains unchecked in `PLAN.md`, final release readiness reporting must explicitly state that package-level benchmark/release-measurement machinery is complete but full roadmap release readiness still has an open dependency.

Depends On:

Unit 1, Unit 2, Unit 3, Unit 4, and Unit 5.
