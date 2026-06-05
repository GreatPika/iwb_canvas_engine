# Change Contract

## Goal

Repair P14 release benchmark measurement semantics so hot-path reports measure the engine action named by each case, while setup, lifecycle, memory, RSS, cleanup, and dense-stress costs remain visible through explicit manifest-owned boundary policy, versioned reports, and release diff gates.

## Source Inputs

- Design: `.design/2026-06-06-p14-benchmark-measurement-boundary.md`
- Research: `.research/2026-06-06-pixel6-release-benchmark-hotspots.md`
- Phase: none
- PLAN: `PLAN.md`, `plan/step_55_p14_release_readiness_benchmarks.md`
- Other: `.design/2026-06-05-p14-release-readiness-benchmarks.md`, `docs/_registry/benchmarks.yaml`, `docs/verification/benchmarks.md`, `docs/tool/check_docs.dart`, `tool/bench/src/benchmark_manifest.dart`, `tool/bench/src/benchmark_case_adapters.dart`, `tool/bench/src/benchmark_report.dart`, `tool/bench/src/benchmark_runner.dart`, `tool/bench/src/benchmark_diff.dart`, `tool/bench/baselines/manual/pixel6_android16_flutter_3_44_0.json`, `tool/guardrails/src/release_readiness_checks.dart`, `test/benchmarks/benchmark_probe_flutter.dart`, `test/benchmarks/benchmark_manifest_test.dart`, `test/benchmarks/required_cases_test.dart`, `test/guardrails/release_readiness_guardrail_test.dart`

## Classification

Profile: ANALYZER_RULE

Obligations: BUG_FIX, SEAM_MIGRATION

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Measurement boundary is manifest-owned policy. Every benchmark case must declare timed scope, setup scope, teardown scope, primary timing, primary memory, setup timing/memory metrics, and fixture shape. | `Boundaries.Source of Truth`, Unit 1 | Manifest parser/schema tests, per-case policy fingerprints, and docs projection checks prove the manifest owns boundary semantics. |
| `D2` Top-level `avg_us`, `p95_us`, `max_us`, `allocation_bytes`, and `rss_delta_bytes` mean primary boundary metrics: action-scoped for `action_only` and `projection_split`, lifecycle-scoped only for lifecycle cases. | `Boundaries.Compatibility`, Unit 2, Unit 4, Unit 5 | Fake harness timing/memory tests, report schema tests, and diff fixtures prove primary metrics do not include setup for hot/action cases. |
| `D3` Probe case execution must migrate from one-shot `_runOperation` to prepare, measure, cleanup case plans; warmup uses the same boundary but records no warmup samples. | `Temporal Surface Closure`, Unit 2 | Fake case event-order tests prove prepare precedes the action stopwatch, cleanup runs after timing in `finally`, and warmup follows the same ordering. |
| `D4` Hot/edit/input/query/frame/resource/runtime-diagnostic cases must use prepared fixtures before action timing and action memory/RSS measurement starts; mutating actions use per-sample fixtures. | Unit 3 | Real case migration tests and required-case boundary checks prove setup is outside primary action samples. |
| `D5` Bulk load and codec cases may keep lifecycle timing only because lifecycle/materialization work is the named operation. | Unit 1, Unit 3, Unit 5 | Manifest boundary rows and diff fixtures prove `codec.decode_v1` and `load_document.*` are lifecycle cases and are not treated as hot action gates. |
| `D6` `projection.read_document` must separate runtime setup from action timing and report first-read/cache-hit split metrics. | Unit 3, Unit 4 | Projection case tests prove runtime construction is outside top-level action samples while `first_read_us` and `cache_hit_us` remain required diagnostics. |
| `D7` Dense spatial fallback must be a named dense stress fixture, while ordinary `spatial.query_point` uses `normal_spread`. | Unit 1, Unit 3 | Manifest and required-case tests reject dense fixture shape under ordinary `spatial.query_point` and require a dense-stress case or fixture shape for fallback behavior. |
| `D8` Setup time, setup allocation, and setup RSS are diagnostics for hot/action paths and must not feed hot action gates unless a manifest setup/lifecycle gate explicitly consumes them. | Unit 4, Unit 5 | Report schema tests require setup diagnostics and diff tests prove hot gates ignore setup metrics while lifecycle gates compare lifecycle metrics. |
| `D9` Existing reports and baselines using old timing semantics must be rejected by schema or manifest version mismatch. | `Boundaries.Compatibility`, `All-Or-Nothing Failure Boundary`, Unit 4, Unit 5 | Adapter/report/diff fixtures reject old `elapsedUsSamples`-only payloads, stale tool schema versions, stale manifest versions, and old baselines before numeric comparison. |
| `D10` Required-case proof must fail missing boundary policy and fail any hot/edit/input/query/frame/resource/runtime-diagnostic case whose manifest or probe path measures setup time, setup allocation, or setup RSS as action. | Unit 4, supported by Unit 1 and Unit 2 | Required-case tests combine manifest metadata, fake harness boundary proof, and case-plan registry metadata so boundary drift fails mechanically. |
| `D11` Current case-family boundary decisions are locked by the selected-form table, including resource, runtime dispose, disabled diagnostics, projection, codec, load, and dense spatial cases. | Unit 1, Unit 3, Unit 6 | All-family boundary policy fingerprints and real-case tests prove implementation did not rediscover or weaken the design table. |

## Evidence

- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:13` / disposition: design is `READY_FOR_CONTRACT` -> write a full step contract, not a blocker.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:17` / product outcome: hot edit, input, query, and frame cases should report named action cost while setup and cleanup are reported separately -> contract must change benchmark policy/reporting, not thresholds.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:24` / non-goals: no threshold lowering, no hidden engine costs, no production benchmark-only hooks or public API -> production `lib/**` changes and threshold-only repairs are out of scope.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:31` / classification: required profile is `ANALYZER_RULE` with `BUG_FIX` and `SEAM_MIGRATION` -> units must add enforcement, fix misleading timing claims, and retire the one-shot probe seam.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:43` / source input: Pixel 6 hotspot research maps current report rows, probe timing scope, setup paths, and hotspots -> research drives boundary repair.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:49` / source input: Step 55 locked manifest, runner, diff, CI, graph, and docs placement but not per-case boundaries -> this follow-up repairs Step 55 assumptions without re-owning benchmark placement.
- `.research/2026-06-06-pixel6-release-benchmark-hotspots.md:35` / root cause: current sample timer wraps complete `_runOperation`, including setup and dispose -> owner-level fix belongs at probe lifecycle/report boundary.
- `.research/2026-06-06-pixel6-release-benchmark-hotspots.md:48` / repeated facts: document generation, runtime construction, spatial rebuild, edit projection/copy, load validation, and candidate budgets are mixed into rows -> contract must classify setup, action, lifecycle, and diagnostics explicitly.
- `.research/2026-06-06-pixel6-release-benchmark-hotspots.md:604` / open question: research has not run alternate probes to separate setup cost from steady-state cost -> implementation proof must add fake/sentinel boundary tests before making new numeric claims.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:250` / selected alternative: manifest-owned case lifecycle with action and setup metrics fixes the shared owner cause -> avoid local inner stopwatch patches.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:291` / selected form: every case row declares `measurement_boundary` and `fixture_shape` -> Unit 1 owns manifest schema and parser changes.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:296` / field shape: timed/setup/teardown/primary timing/primary memory/setup metric enums are locked -> Unit 1 completion must validate enum-like fields, not free-form prose.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:313` / primary metrics: action-only top-level time, allocation, and RSS are computed from action boundary only -> Unit 2 and Unit 5 must prove setup exclusion for both time and memory.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:325` / lifecycle policy: lifecycle cases can include lifecycle work only when the named operation is lifecycle/materialization -> Unit 5 must keep lifecycle gates separate from hot gates.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:332` / projection policy: `projection.read_document` prepares runtime before action timing and still reports split metrics -> Unit 3 must include projection-specific proof.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:347` / case family table: edit/input/frame/resources/projection/codec/load/spatial/runtime/diagnostics boundaries are locked -> Unit 1 and Unit 3 must encode every current family.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:362` / spatial policy: ordinary query and dense fallback must be separated by fixture shape or stress-named case -> Unit 1 and Unit 3 must prevent dense fallback from defining ordinary query expectations.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:369` / seam migration: sample stopwatch wrapping `_runOperation` is replaced by prepare fixture -> action stopwatch -> cleanup -> Unit 2 owns the successor seam.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:381` / warmup/failure order: warmup uses the same boundary, prepare failure fails before timing claims, cleanup runs in `finally` and fails the case on cleanup failure -> Temporal Surface Closure must name these signals.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:388` / non-hiding rule: edit projection/materialization and projection first-read costs remain visible where they are part of the action -> setup exclusion must not hide real engine work.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:408` / decision trace D1: manifest owns boundary policy -> Source of Truth must be `docs/_registry/benchmarks.yaml`.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:409` / decision trace D2: top-level metrics are primary boundary metrics -> report schema and diff semantics must be versioned.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:416` / decision trace D9: old reports and baselines must be rejected by version mismatch -> compatibility is deliberate breakage for benchmark reports, not engine API.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:424` / outcome proof: fake action-only case with slow setup must report setup separately while action metrics match action samples -> Unit 2 cannot rely on real benchmark timings alone.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:425` / outcome proof: fake allocation/RSS setup must not feed `allocation_bytes` or `rss_delta_bytes` for action-scoped cases -> Unit 2 and Unit 5 must prove memory boundary separately from timing.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:446` / sequencing: manifest schema precedes probe lifecycle, real case migration, report schema, diff compatibility, docs projection, and required-case proof -> execution unit order is locked.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:447` / temporal closure: sample order and rejection behavior are probe-owned -> Unit 2 completion checks must prove prepare/measure/cleanup order and failure projection.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:548` / source-of-truth impact: manifest, parser, report, adapter, runner, diff, docs checker, docs projection, Step 55 assumptions, reports, and baselines must change -> scope includes tool/docs/test surfaces and excludes production API.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:580` / verification impact: required proof surfaces include manifest schema tests, required-case boundary tests, fake harness tests, projection tests, spatial tests, report schema tests, diff tests, and docs checks -> completion checks must name those surfaces.
- `.design/2026-06-06-p14-benchmark-measurement-boundary.md:633` / handoff: D1 through D11, exact evidence, sequencing, no production hooks, and setup metrics exclusion are mandatory -> contract preserves all design decisions.
- `test/benchmarks/benchmark_probe_flutter.dart:64` / current warmup path: warmups call `_measureOperation` -> new warmup must use the same action boundary as measured samples.
- `test/benchmarks/benchmark_probe_flutter.dart:82` / current report path: top-level metrics derive from collected samples -> action samples must become the only source for hot top-level metrics.
- `test/benchmarks/benchmark_probe_flutter.dart:131` / current sample seam: `_measureOperation` starts RSS and stopwatch before `_runOperation` -> setup is currently included in action timing/RSS.
- `test/benchmarks/benchmark_probe_flutter.dart:150` / current dispatch: `_runOperation` is one case switch -> migration should replace the shared seam, not add scattered local stopwatches.
- `test/benchmarks/benchmark_probe_flutter.dart:197` / edit setup: `edit.add_element` constructs runtime inside operation body -> edit setup is currently included in action timing.
- `test/benchmarks/benchmark_probe_flutter.dart:448` / projection setup: `projection.read_document` constructs runtime before first-read/cache-hit metrics -> top-level projection timing needs explicit boundary repair.
- `test/benchmarks/benchmark_probe_flutter.dart:650` / lifecycle case: `load_document.success` constructs empty runtime and then loads a document -> load may remain lifecycle-scoped because load is the named operation.
- `test/benchmarks/benchmark_probe_flutter.dart:666` / spatial setup: `spatial.query_point` constructs runtime before query -> ordinary query timing currently includes fixture setup.
- `test/benchmarks/benchmark_probe_flutter.dart:734` / dispose setup: runtime dispose case constructs runtime and starts gesture before dispose -> active gesture setup must be excluded from the dispose action.
- `test/benchmarks/benchmark_probe_flutter.dart:743` / diagnostics setup: disabled pointer case constructs runtime and resets counters before action -> zero-allocation claim applies only to disabled-pointer routing.
- `test/benchmarks/benchmark_probe_flutter.dart:924` / scale map: scale ids include `100k` and `dense_50k` -> fixture shape must be manifest-owned, not inferred from scale alone.
- `tool/bench/src/benchmark_case_adapters.dart:83` / adapter payload: current adapter decodes `elapsedUsSamples` -> report payload must distinguish action samples from setup diagnostics and reject ambiguous old payloads.
- `tool/bench/src/benchmark_manifest.dart:106` / manifest model: `BenchmarkCase` currently has no measurement boundary or fixture shape field -> parser and tests must add those fields.
- `tool/bench/src/benchmark_manifest.dart:303` / parser owner: case parsing validates row schema in one owner -> boundary schema validation belongs there.
- `tool/bench/src/benchmark_runner.dart:97` / runner validation: required metrics and invariants are already per-case all-or-nothing validation -> boundary field/report validation belongs in the same path.
- `tool/bench/src/benchmark_diff.dart:1086` / diff owner: regression metrics include timing, allocation, and RSS keys -> diff must interpret those keys by manifest boundary and ignore setup diagnostics for hot gates.
- `docs/_registry/benchmarks.yaml:1` / manifest version: manifest has explicit version -> boundary semantics require version bump.
- `docs/_registry/benchmarks.yaml:2` / report schema version: manifest stores tool schema version -> action/setup report semantics require schema bump and old-report rejection.
- `docs/_registry/benchmarks.yaml:115` / case rows: existing cases list policy fields but no boundary field -> manifest must grow `measurement_boundary` and `fixture_shape`.
- `docs/_registry/benchmarks.yaml:343` / projection case: `projection.read_document` currently requires split metrics but not top-level action timing -> projection boundary must be explicit.
- `docs/_registry/benchmarks.yaml:389` / spatial case: ordinary query scales include large scales without fixture shape -> dense stress must no longer be implicit.
- `docs/verification/benchmarks.md:31` / docs policy: manifest is the structured source of truth for cases, scales, metrics, budgets, invariants, and profiles -> boundary policy belongs in manifest, not independent docs prose.
- `docs/tool/check_docs.dart:232` / docs checker: manifest projection serializes benchmark policy -> docs fingerprint must include boundary and fixture shape.
- `test/benchmarks/required_cases_test.dart:13` / required-case owner: current test runs `dry_run` over every manifest case/scale -> it should fail missing boundary metadata and wrong case-plan boundary.
- `test/benchmarks/benchmark_manifest_test.dart:92` / manifest tests: policy inventory is fixture-locked -> update fingerprints to include boundary policy for every current family.
- `plan/step_55_p14_release_readiness_benchmarks.md:25` / prior decision: Step 55 made manifest the owner of cases, scales, budget classes, metric keys, invariants, and profile membership -> this step extends that owner rather than creating a new policy source.
- `plan/step_55_p14_release_readiness_benchmarks.md:127` / prior Unit 1: benchmark manifest and docs were source of truth -> boundary schema repair starts there.
- `plan/step_55_p14_release_readiness_benchmarks.md:149` / prior Unit 2: runner/profiles/required-case dry-run proof were established -> probe seam migration happens after manifest boundary schema repair.
- `tool/bench/baselines/manual/pixel6_android16_flutter_3_44_0.json:1723` / old report row: `projection.read_document/100k` exists under current schema -> old reports are evidence of current bug but must not remain comparable after migration.
- `tool/bench/baselines/manual/pixel6_android16_flutter_3_44_0.json:1740` / old timing: same projection row reports `avg_us: 1184379` while split metrics are narrower -> old top-level timing semantics are stale.
- `tool/bench/baselines/manual/pixel6_android16_flutter_3_44_0.json:2099` / dense fallback: ordinary spatial query row reports fallback count 4097 -> dense fallback behavior needs stress naming or dense fixture shape.
- `tool/guardrails/src/release_readiness_checks.dart:8` / guardrail id: `release.benchmark_readiness` is a concrete guardrail surface -> Unit 6 structural proof should extend this owner when boundary semantics need release-readiness enforcement.
- `test/guardrails/release_readiness_guardrail_test.dart:13` / guardrail test owner: release benchmark readiness already has runner-backed tests -> Unit 6 can add boundary-specific structural proof there instead of creating a second guardrail owner.

## Boundaries

Owner:

P14 benchmark measurement boundary owns `docs/_registry/benchmarks.yaml`, benchmark manifest parsing, report schema, probe payload decoding, runner validation, diff/baseline interpretation, docs benchmark projection checks, and `test/benchmarks/**` proof for boundary policy. Production engine code under `lib/**` remains only the measured subject and must not import, expose, or own benchmark policy.

In Scope:

Add manifest-owned `measurement_boundary` and `fixture_shape` policy for every benchmark case and bump manifest/report schema versions. Validate enum-like timed/setup/teardown/primary timing/primary memory/setup metric fields in the manifest parser. Migrate the Flutter probe from one-shot `_runOperation` timing to case plans with prepare, measure, and cleanup. Emit action timing/memory samples and setup timing/memory diagnostics through a versioned report schema. Migrate real case families to the selected-form boundary table, including projection split behavior, lifecycle codec/load cases, resource cases, runtime dispose, disabled diagnostics, ordinary spatial query, and dense spatial stress. Update adapter, runner, required-case tests, report schema tests, diff fixtures, docs checker, docs projection, generated/current report compatibility, and baseline comparison behavior so old report semantics are rejected.

Out of Scope:

Do not lower thresholds to make reports pass. Do not add production benchmark-only hooks, public API, runtime feature behavior, or production `lib/**` dependencies on benchmark policy. Do not create a second benchmark policy file or rely on docs prose, report JSON, baseline JSON, or case-id conventions as the source of truth. Do not hide setup costs; setup timing, allocation, and RSS must remain report-visible when setup is non-trivial. Do not compare old-schema reports or baselines under new action timing semantics. Do not change Step 52 or full release readiness status except to preserve the existing roadmap dependency if it remains unchecked.

Source of Truth:

The design `.design/2026-06-06-p14-benchmark-measurement-boundary.md` is the decision handoff. Durable benchmark boundary policy lives in `docs/_registry/benchmarks.yaml`; docs remain a checked projection through `docs/tool/check_docs.dart` and `docs/verification/benchmarks.md`. Parser/runtime enforcement lives in `tool/bench/src/benchmark_manifest.dart`, `tool/bench/src/benchmark_case_adapters.dart`, `tool/bench/src/benchmark_report.dart`, `tool/bench/src/benchmark_runner.dart`, and `tool/bench/src/benchmark_diff.dart`. Boundary proof lives under `test/benchmarks/**`. Existing Pixel 6 reports and approved baselines are generated/transient or accepted measurement data only; they do not define case policy or timing semantics.

Compatibility:

Engine public API, schema v1 document behavior, runtime behavior, and production package compatibility must remain unchanged. Benchmark report compatibility intentionally breaks by manifest/tool schema version: old `elapsedUsSamples`-only payloads, old report schema versions, old manifest versions, and old baselines are rejected before numeric comparison. The same top-level metric names remain allowed, but under the new schema `avg_us`, `p95_us`, `max_us`, `allocation_bytes`, and `rss_delta_bytes` mean the manifest-declared primary boundary metrics.

Order Constraints:

First update manifest schema, parser validation, docs projection fingerprinting, and manifest tests. Then introduce prepare/measure/cleanup case-plan lifecycle and fake harness tests for setup exclusion from action timing, allocation, and RSS. Then migrate real probe cases and fixture shapes. Then update report schema, adapter decoding, runner validation, and required-case boundary proof. Then update diff/baseline compatibility and old-schema rejection. Finally refresh docs projection and regenerate current/manual reports only after schema and boundary migration is complete. No new baseline comparison may be accepted until old schema/version reports are rejected.

Temporal Surface Closure:

The temporal invariant is that every sample completes prepare before action timing and action memory/RSS measurement start, stops action measurement before cleanup begins, and runs cleanup in `finally` for both warmup and measured samples. Synchronous callback surfaces are benchmark-local case plan `prepare`, `measure`, and `cleanup` calls, probe sample loop callbacks, adapter probe-process decoding, runner per-case validation, and diff/baseline comparison. The probe harness owns the ordering guard. Public observation order is manifest validation -> case prepare -> action measurement -> cleanup -> report row validation -> diff/baseline comparison. Expected rejection signal is non-zero command/test failure and no successful report row or release comparison when manifest boundary validation, prepare, measure, cleanup, payload decoding, old-schema rejection, or diff validation fails.

All-Or-Nothing Failure Boundary:

The irreversible points are emitting a successful report row and accepting a release diff/baseline comparison. Fallible work before those points includes manifest/schema parsing, boundary validation, fixture prepare, action measurement, cleanup, report payload decoding, required metric/invariant checks, old schema/version checks, and diff/baseline validation. Report writing after successful validation is accepted output. Failure projection is command/test failure plus no successful release comparison; no path may silently rewrite baselines, reuse old-schema timing semantics, or accept a partial report with cleanup or boundary failure.

## Execution Units

### [ ] Unit 1: Manifest boundary schema and docs source of truth

Owner:

`docs/_registry/benchmarks.yaml`, `tool/bench/src/benchmark_manifest.dart`, `docs/tool/check_docs.dart`, `docs/verification/benchmarks.md`, and manifest/docs tests.

Boundary:

Make benchmark measurement boundary policy manifest-owned and docs-checked before probe or diff behavior changes consume it.

Change:

Add manifest version and tool schema version bumps. Add `measurement_boundary` and `fixture_shape` to every case row with validated enum-like fields using these exact keys: `measurement_boundary.timed_scope`, `measurement_boundary.setup_scope`, `measurement_boundary.teardown_scope`, `measurement_boundary.primary_timing`, `measurement_boundary.primary_memory`, `measurement_boundary.setup_metrics`, `measurement_boundary.setup_memory_metrics`, and `fixture_shape`. Validate `timed_scope` values `action_only`, `lifecycle`, and `projection_split`; `setup_scope` values `none`, `per_run_prepared_fixture`, and `per_sample_prepared_fixture`; `teardown_scope` values `excluded` and `measured_lifecycle`; `primary_timing` values `action`, `lifecycle`, and `projection_action_total`; `primary_memory` values `action`, `lifecycle`, and `none`; setup metric keys starting with `setup_us`; setup memory metric keys starting with `setup_allocation_bytes` and `setup_rss_delta_bytes`; and fixture shape values `normal_spread`, `dense_stress`, `resource_set`, `active_preview`, `invalid_document`, `codec_fixture`, `hot_pointer`, or another manifest-validated value introduced by a future contract. Encode the selected-form case-family table: action-only edit/input/frame/resource/spatial/runtime/diagnostic cases, lifecycle codec/load cases, projection split, ordinary `spatial.query_point` as `normal_spread`, and a dense-stress fixture or stress-named case for dense fallback. Extend manifest parser validation and docs fingerprint/projection so docs cannot define independent boundary policy. Repair Step 55 assumptions by keeping the existing manifest owner and extending it to measurement boundary policy rather than adding a new policy source.

Completion Check:

Manifest schema tests fail on missing `measurement_boundary`, missing `measurement_boundary.timed_scope`, missing `measurement_boundary.setup_scope`, missing `measurement_boundary.teardown_scope`, missing `measurement_boundary.primary_timing`, missing `measurement_boundary.primary_memory`, missing `measurement_boundary.setup_metrics`, missing `measurement_boundary.setup_memory_metrics`, missing `fixture_shape`, unknown enum value, stale manifest/tool schema version expectations, lifecycle timing or lifecycle memory for hot/edit/input/query/frame/resource/runtime-diagnostic cases, dense fixture under ordinary `spatial.query_point`, missing dense-stress policy for dense fallback behavior, missing setup metrics for non-trivial setup scopes, or stale all-family policy fingerprints. Docs checks prove `docs/verification/benchmarks.md` projects boundary labels/fingerprint from `docs/_registry/benchmarks.yaml` and fails if docs or manifest drift independently. `dart run docs/tool/sync_generated_docs.dart --check`, `dart run docs/tool/check_docs.dart`, focused manifest/docs tests, `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics docs/tool tool/bench test/benchmarks` pass after implementation changes.

Depends On:

None.

### [ ] Unit 2: Probe case lifecycle seam and fake boundary proof

Owner:

`test/benchmarks/benchmark_probe_flutter.dart`, probe harness support code under `test/benchmarks/**`, benchmark probe tests, and fake/sentinel case-plan fixtures.

Boundary:

Replace one-shot sample timing around `_runOperation` with a prepare, measure, cleanup case lifecycle before migrating all real benchmark cases.

Change:

Introduce a case-plan seam where each case prepares a fixture, measures only the claimed action under action stopwatch and action memory/RSS measurement, and cleans up in `finally`. Warmup and measured samples use the same prepare/measure/cleanup order, but warmup action samples are not recorded. Setup timing and setup memory/RSS are collected as diagnostics outside primary action samples. Prepare failure fails before timing claims. Cleanup failure fails the case instead of emitting a successful partial report. Keep fake proof fixtures test-owned; do not add fixture-only ids or sentinels to production manifest, public API, schemas, durable docs, or generated public surfaces.

Completion Check:

Fake harness tests prove a deliberately slow setup and fast action reports setup timing separately while `avg_us`, `p95_us`, and `max_us` equal action samples only. Fake memory/RSS tests prove setup allocation and setup RSS are reported as setup diagnostics while `allocation_bytes` and `rss_delta_bytes` equal action memory/RSS for action-scoped cases only. Event-order tests prove warmup and measured samples both execute prepare -> action measurement -> cleanup, action timing starts after prepare, action timing stops before cleanup, warmup samples are not recorded, and cleanup runs in `finally` after action failure. Failure tests prove prepare failure, action failure, cleanup failure, and boundary validation failure produce non-zero command/test failure and no successful report row. Focused probe tests, `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics test/benchmarks` pass.

Depends On:

Unit 1.

### [ ] Unit 3: Real case migration and fixture-shape enforcement

Owner:

Real benchmark case plans and fixtures under `test/benchmarks/**`, probe case migration tests, and required-case boundary fixtures.

Boundary:

Move current real cases onto the new boundary table without changing production engine behavior or hiding real action costs.

Change:

Migrate edit, input, frame, resource, projection, codec, load, spatial, runtime dispose, and diagnostics cases from one-shot `_runOperation` setup/action/cleanup timing to manifest-classified case plans. Use per-sample prepared fixtures for mutating actions and per-run prepared fixtures only for immutable or explicitly reset read-only cases. Keep edit projection, draft copy, materialize, commit, delivery, and touched spatial update inside edit action timing when the edit operation performs them. Keep projection first-read/cache-hit diagnostics visible while excluding runtime construction from top-level projection timing. Keep codec and load lifecycle/materialization work lifecycle-scoped. Separate ordinary `spatial.query_point` normal-spread fixture from dense fallback stress behavior through a dense-stress case or fixture shape.

Completion Check:

Real case tests prove each current family matches the selected-form table and that required-case boundary proof fails if any current case uses the wrong timed scope, setup scope, primary memory scope, or fixture shape. Projection tests prove `projection.read_document` top-level action samples exclude runtime construction and require `first_read_us` and `cache_hit_us`. Spatial tests prove ordinary `spatial.query_point` uses `normal_spread` and rejects dense fixture shape, while dense fallback remains visible through stress naming or `dense_stress`. Edit/input/frame/resource/runtime/diagnostic tests prove runtime/document/session/tool/gesture/counter setup happens before action measurement and action-visible engine work remains inside the action. Focused real-case tests, `dart run tool/bench/run.dart --profile=dry_run`, `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics test/benchmarks` pass.

Depends On:

Unit 1 and Unit 2.

### [ ] Unit 4: Versioned report schema, adapter decoding, runner validation, and required-case proof

Owner:

`tool/bench/src/benchmark_report.dart`, `tool/bench/src/benchmark_case_adapters.dart`, `tool/bench/src/benchmark_runner.dart`, `test/benchmarks/required_cases_test.dart`, report schema tests, adapter tests, and runner tests.

Boundary:

Make action/setup semantics observable and all-or-nothing at the probe-process, report, and runner boundary before diff gates interpret numbers.

Change:

Bump report/tool schema and serialize this exact new-schema probe/report payload shape. The probe JSON emitted after `BENCHMARK_PROBE_JSON:` must contain `probeSchemaVersion`, `actionUsSamples`, `setupUsSamples`, `metrics`, `setupMetrics`, `measurementBoundary`, `fixtureShape`, and `runtime`; it must not contain `elapsedUsSamples`. `actionUsSamples` is the only source for `avg_us`, `p95_us`, and `max_us` in action-scoped cases. `setupUsSamples` feeds `setupMetrics.setup_us` and the report-visible diagnostic metric `setup_us`, never hot action timing gates. `metrics` contains primary boundary metrics and action diagnostics, including `allocation_bytes` and `rss_delta_bytes` with action or lifecycle meaning determined by `measurementBoundary.primaryMemory`. `setupMetrics` contains `setup_us`, `setup_allocation_bytes`, and `setup_rss_delta_bytes` when setup is non-trivial. `measurementBoundary` in report JSON uses camelCase keys `timedScope`, `setupScope`, `teardownScope`, `primaryTiming`, `primaryMemory`, `setupMetrics`, and `setupMemoryMetrics`, copied from the manifest row. `fixtureShape` is copied from manifest `fixture_shape`. The case report JSON must add `measurementBoundary`, `fixtureShape`, `actionUsSamples`, `setupUsSamples`, and `setupMetrics`, while the top-level report continues to carry `schemaVersion`, `manifestVersion`, and `manifestFingerprint`. Adapter decoding must reject any new-schema probe payload that contains `elapsedUsSamples` with the exact failure signal containing the case/scale and phrase `old elapsedUsSamples probe payload`; old report/baseline JSON is rejected by stale `schemaVersion` or `manifestVersion` before numeric comparison. Teach adapter decoding and runner validation to require boundary fields, required action metrics, setup diagnostics required by setup scope, required action memory semantics, exact invariants, and case-plan registry metadata consistent with the manifest. Extend required-case tests so every manifest case/scale must dry-run with boundary metadata and correct report semantics.

Completion Check:

Report schema tests reject old `elapsedUsSamples`-only payloads, any new-schema payload that still contains `elapsedUsSamples`, old tool schema versions, missing `probeSchemaVersion`, missing `actionUsSamples`, missing `setupUsSamples`, missing `setupMetrics`, missing action samples for action cases, missing `setup_us`/`setup_allocation_bytes`/`setup_rss_delta_bytes` for non-trivial setup, missing `measurementBoundary`, missing `measurementBoundary.timedScope`, missing `measurementBoundary.setupScope`, missing `measurementBoundary.teardownScope`, missing `measurementBoundary.primaryTiming`, missing `measurementBoundary.primaryMemory`, missing `measurementBoundary.setupMetrics`, missing `measurementBoundary.setupMemoryMetrics`, missing `fixtureShape`, missing top-level `manifestVersion` or `manifestFingerprint`, missing required split diagnostics, and lifecycle/action memory scope mismatches. Adapter tests prove old probe payloads fail before runner acceptance with an error containing `old elapsedUsSamples probe payload`. Runner tests prove report rows carry manifest boundary semantics and fail closed on case-plan metadata drift. `test/benchmarks/required_cases_test.dart` fails on any case lacking boundary metadata, required action timing, required setup diagnostics, required action memory semantics, exact invariants, or executable dry-run. Focused adapter/runner/report/required-case tests, `dart run tool/bench/run.dart --profile=dry_run`, `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics tool/bench test/benchmarks` pass.

Depends On:

Unit 1, Unit 2, and Unit 3.

### [ ] Unit 5: Diff, baseline compatibility, and gate interpretation

Owner:

`tool/bench/src/benchmark_diff.dart`, diff fixtures, approved-baseline compatibility fixtures, report comparison tests, and baseline update validation tests.

Boundary:

Interpret release reports by manifest boundary semantics and reject old report/baseline semantics before numeric comparison.

Change:

Update diff and baseline compatibility so hot/action gates compare only action top-level timing, action allocation, and action RSS for `action_only` and `projection_split` cases; lifecycle gates compare lifecycle timing and lifecycle allocation/RSS only for lifecycle cases; setup metrics are ignored by hot gates unless manifest policy explicitly declares setup/lifecycle consumption. Reject old tool schema versions, old manifest versions, old baselines, old Pixel 6 current reports, missing boundary metadata, missing setup diagnostics, and metric-scope mismatches before numeric comparison. Preserve existing first-baseline, approved-baseline, metadata contour, exact invariant, and fail-closed baseline write policy from Step 55 while updating it to the new boundary semantics.

Completion Check:

Diff fixtures prove hot gates ignore `setup_us`, `setup_allocation_bytes`, and `setup_rss_delta_bytes`; lifecycle cases compare lifecycle metrics; projection split uses action total plus required `first_read_us` and `cache_hit_us`; setup diagnostics remain present in reports but do not cause hot gate failures unless explicitly declared; old schema/current report/baseline inputs fail before numeric comparison; manifest version mismatch fails before numeric comparison; and no ordinary diff/release path rewrites approved baselines. Regression fixture tests cover avg/P95/max, allocation/RSS, lifecycle memory, exact invariant, missing metric, missing boundary metadata, stale schema, stale manifest, and valid same-boundary comparison. Focused diff/baseline tests, `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics tool/bench test/benchmarks` pass.

Depends On:

Unit 1 and Unit 4.

### [ ] Unit 6: Final boundary closure, docs projection, generated report refresh, and repository verification

Owner:

Benchmark docs/checks, generated/current benchmark report handling, `release.benchmark_readiness` guardrail ownership, root `PLAN.md`, this step file, and final verification reporting.

Boundary:

Close the measurement-boundary migration after manifest, probe, real cases, report, runner, and diff semantics are enforceable.

Change:

Refresh docs projection after manifest changes. Regenerate or explicitly invalidate current/manual reports and baselines using old schema only after new schema and old-report rejection are in place. Extend the existing `release.benchmark_readiness` guardrail and `test/guardrails/release_readiness_guardrail_test.dart` only where the new boundary semantics need release-readiness structural enforcement, and keep that enforcement in the existing release-readiness owner. Preserve Step 52 roadmap dependency if it remains unchecked, and do not mark this step complete until implementation evidence exists for every unit.

Completion Check:

Docs checks pass and prove boundary labels/fingerprints are manifest-derived. `release.benchmark_readiness` guardrail tests fail on public API export changes, benchmark-only production hooks, production imports of benchmark policy, stale old-schema report acceptance, or release comparison against old baselines. Focused benchmark commands include `dart run tool/bench/run.dart --profile=smoke`; after the new schema can emit release reports, implementation verification also runs `dart run tool/bench/run.dart --profile=release` and the Step 55 exact diff entrypoint remains normative: `dart run tool/bench/diff.dart --profile=release --baseline=tool/bench/baselines/approved/release_ubuntu_24_04_flutter_3_38_0.json --current=build/bench/current/release_ubuntu_24_04_flutter_3_38_0.json --output=build/bench/diff/release_ubuntu_24_04_flutter_3_38_0.json`. Final local verification includes focused benchmark/tool/guardrail tests, `dart analyze`, `dcm analyze .`, relevant `dcm calculate-metrics` scopes for `tool/bench`, `test/benchmarks`, `test/guardrails`, and `docs/tool`, `dart run docs/tool/sync_generated_docs.dart --check`, and `dart run docs/tool/check_docs.dart`. Unit and `PLAN.md` checkboxes remain unchecked until the later implementation workflow supplies implementation, verification, review, and commit evidence.

Depends On:

Unit 1, Unit 2, Unit 3, Unit 4, and Unit 5.
