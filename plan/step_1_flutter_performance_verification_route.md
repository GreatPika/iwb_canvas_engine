# Change Contract

## Goal

Introduce the official Flutter performance verification route as a
release-blocking path: the full Flutter scenario catalog runs through the
example app with `integration_test` plus `flutter drive --profile`, and release
acceptance is based on scenario completion plus trace artifact production rather
than numeric performance thresholds.

## Source Inputs

- Design: `.design/2026-06-16-flutter-performance-verification-route.md`
- Research: `.research/2026-06-16-flutter-performance-docs-ssot.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `AGENTS.md`, `docs/README.md`, `docs/verification/tests.md`,
  `docs/verification/release_gates.md`, `docs/_registry/sections.yaml`,
  `docs/contracts/public_api_v1.md`, `docs/contracts/validation_limits.md`,
  `.github/workflows/root_package.yml`,
  `test/api_contract/example_public_boundary_test.dart`,
  `test/guardrails/root_ci_target_test.dart`, `example/pubspec.yaml`,
  `https://api.flutter.dev/flutter/package-integration_test_integration_test/IntegrationTestWidgetsFlutterBinding/traceAction.html`,
  `https://api.flutter.dev/flutter/flutter_driver/TimelineSummary/writeTimelineToFile.html`,
  `https://docs.flutter.dev/cookbook/testing/integration/profiling`

## Classification

Profile: SOURCE_OF_TRUTH_DOCS

Obligations: none

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Durable performance route owner is a new registered `docs/verification/performance.md` section. | `Boundaries.Source of Truth`, `Unit 1` | `dart run docs/tool/sync_generated_docs.dart --check`, `dart run docs/tool/check_docs.dart`, generated context capsule and indexes |
| `D2` Route is release-blocking now as completion plus artifact production, not numeric thresholds. | `Boundaries.Compatibility`, `Unit 5` | `docs/verification/release_gates.md` no longer claims no performance gate and names completion plus artifacts as the gate |
| `D3` Flutter catalog must include every scenario row from the design catalog. | `Unit 1`, `Unit 3` | `flutter test test/performance/flutter_performance_route_contract_test.dart` proves performance-doc catalog ids match `PerformanceScenario.id` values and exact integration-test report keys |
| `D4` Route runs through `example` as an external public consumer and must not import `lib/src/**` or restore internal benchmark ids. | `Boundaries.Owner`, `Boundaries.Out of Scope`, `Unit 2` | `flutter test test/api_contract/example_public_boundary_test.dart`; no `package:iwb_canvas_engine/src/**` imports in example route sources |
| `D5` `TimelineSummary` and full timeline JSON are required artifacts for every scenario report key, where the report key is exactly the scenario id. | `Boundaries.Order Constraints`, `Unit 4` | profile `flutter drive` run plus `dart run tool/check_flutter_performance_artifacts.dart --catalog docs/verification/performance.md --results example/build/flutter_performance` |
| `D6` The 100k scenarios are catalog requirements, but 100k routes must not silently expand validation limits. | `Boundaries.Compatibility`, `Unit 3` | `cd example && flutter test test/performance_fixture_limits_test.dart` proves the exact fixture or fixtures for `load_document.100k` and `camera_pan.100k` fit current raw JSON and total-element limits, or implementation stops for a separate validation-limit design |
| `D7` Old benchmark registry, index, docs, and tooling routes remain retired. | `Boundaries.Out of Scope`, `Unit 1`, `Unit 5` | docs checks reject retired benchmark fields; review/search shows no restored `docs/_registry/benchmarks.yaml`, `docs/indexes/by_benchmark.md`, `docs/verification/benchmarks.md`, `tool/bench/**`, or `test/benchmarks/**` |
| `D8` Example Dart/test/driver/tool implementation must carry repository analyzer, DCM, metrics, focused-test, example-package, artifact-tool, and public-boundary proof. | `Boundaries.Order Constraints`, `Unit 2`, `Unit 3`, `Unit 4`, `Unit 5` | `dart analyze`, `dcm analyze .`, scoped `dcm calculate-metrics`, focused Flutter tests, artifact inventory tool command, example-package commands, and public-boundary test |

## Evidence

- `docs/README.md:25` / source-of-truth families: verification policy is owned
  under `docs/verification/` -> the durable route belongs in verification docs.
- `docs/README.md:31` / evidence layers: `.design/` and `.research/` do not own
  active release policy or external routes -> this contract must move the route
  into docs source of truth.
- `.research/2026-06-16-flutter-performance-docs-ssot.md:22` / current
  verification owners: tests, guardrails, and release gates are the active
  verification docs -> the new route must integrate with tests and release
  gates rather than remain standalone.
- `.research/2026-06-16-flutter-performance-docs-ssot.md:33` / absent active
  performance route: no active performance doc, benchmark doc, benchmark
  registry, benchmark index, tool bench path, integration-test path, or driver
  path was found -> implementation creates the route instead of migrating an
  existing active route.
- `docs/_registry/sections.yaml:764` / test section registry: `section_23_tests`
  is the registered tests section with owner `test` -> test inventory links
  stay in `docs/verification/tests.md`.
- `docs/_registry/sections.yaml:919` / release section registry:
  `section_27_final_release_gates` is the registered release-gates section with
  owner `release` -> release-blocking wording stays in
  `docs/verification/release_gates.md`.
- `docs/verification/release_gates.md:102` / release gate semantics: release is
  blocked unless listed statements are true -> the Flutter performance route can
  be made blocking by adding a concrete listed statement.
- `docs/verification/release_gates.md:167` / current negative performance
  claim: no repository-owned performance gate is currently claimed -> Unit 5
  must replace that claim with the selected gate.
- `docs/tool/generate_context_capsules.dart:123` / generated context capsules:
  section context is rendered from registry data -> the new performance section
  must be registry-backed.
- `docs/tool/generate_context_capsules.dart:157` / section file sync:
  registered section files receive exactly generated context content -> Unit 1
  must run generated-doc sync for the new document.
- `docs/tool/sync_generated_docs.dart:351` / generated indexes: the six docs
  indexes are rendered from section rows -> adding a performance section
  requires generated index updates.
- `docs/tool/sync_generated_docs.dart:551` / test-area index generation:
  `docs/indexes/by_test_area.md` is generated from registry `tests` entries ->
  the new performance section must name durable test ids instead of relying only
  on `owners: test`.
- `docs/tool/sync_generated_docs.dart:601` / release index: release index rows
  come from sections whose owners include `release` -> the performance section
  needs release ownership if it owns a release-blocking route.
- `docs/tool/check_docs.dart:29` / generated index inventory: generated indexes
  are locked to six current files -> do not restore `docs/indexes/by_benchmark.md`.
- `docs/tool/check_docs.dart:255` / retired registry fields: `benchmarks` is a
  retired section field -> do not restore benchmark registry metadata.
- `docs/tool/check_docs.dart:685` / markdown path checks: docs checks scan
  `docs/verification` and indexes -> docs checks are the proof surface for
  performance doc links and generated navigation.
- `AGENTS.md:48` / Dart change verification: every Dart code change requires
  repository checks -> example performance Dart files require root verification.
- `AGENTS.md:51` / analyzer verification: `dart analyze` is mandatory after
  Dart changes -> include it in final proof.
- `AGENTS.md:52` / DCM verification: `dcm analyze .` is mandatory after Dart
  changes -> include it in final proof.
- `AGENTS.md:53` / metrics verification: scoped `dcm calculate-metrics` is
  mandatory for changed owners -> run it for changed example owners.
- `AGENTS.md:61` / focused tests: changed behavior or tooling needs focused
  tests -> integration route and driver changes need focused proof beyond docs.
- `AGENTS.md:85` / mixed change verification: mixed docs and code changes need
  both code and documentation checks -> final proof must include both families.
- `.github/workflows/root_package.yml:55` / example CI job: the repository has a
  separate `example-package` job -> example route changes must keep standalone
  example checks green.
- `.github/workflows/root_package.yml:67` / example dependency install:
  example CI runs `flutter pub get` -> new integration dependencies require
  example dependency proof.
- `.github/workflows/root_package.yml:71` / example tests: example CI runs
  `flutter test` -> example route support must not break example tests.
- `.github/workflows/root_package.yml:75` / example analysis: example CI runs
  `flutter analyze` -> example route sources must analyze in package context.
- `test/guardrails/root_ci_target_test.dart:125` / structural CI proof:
  guardrails require the `example-package` job -> example route proof should use
  the existing CI route rather than bypass it.
- `test/guardrails/root_ci_target_test.dart:133` / example CI commands:
  structural proof rejects bypass and checks example commands -> final proof
  includes the same example package commands.
- `docs/verification/tests.md:453` / documented public-boundary test:
  `test/api_contract/example_public_boundary_test.dart` is the documented owner
  for example public-boundary proof -> use this test as the import boundary
  proof surface.
- `test/api_contract/example_public_boundary_test.dart:48` / public import
  boundary: example imports the engine only through the public barrel ->
  performance route code must preserve public-consumer behavior.
- `test/api_contract/example_public_boundary_test.dart:67` / retired seam
  boundary: example sources must not reference private or retired seams -> old
  benchmark route names and private imports stay quarantined.
- `test/api_contract/example_public_boundary_test.dart:99` / example diff
  boundary: example-step diffs must not modify production `lib/**` source ->
  this route does not change production runtime behavior unless escalated by a
  separate contract.
- `.design/2026-06-16-flutter-performance-verification-route.md:367` /
  selected form: Candidate B creates a registered `docs/verification/performance.md`
  owner -> Unit 1 owns that document and registry row.
- `.design/2026-06-16-flutter-performance-verification-route.md:379` /
  selected release gate: all catalog scenarios must complete via
  `flutter drive --profile` and write `TimelineSummary` plus full timeline JSON
  -> Units 3 and 4 own scenario/report-key and artifact proof.
- `.design/2026-06-16-flutter-performance-verification-route.md:389` /
  selected non-gate: no numeric frame-time, p95/p99, baseline-diff, or
  regression threshold is claimed -> Unit 5 must avoid numeric threshold
  release wording.
- `.design/2026-06-16-flutter-performance-verification-route.md:397` /
  required catalog: the future performance doc must list every Flutter scenario
  id and report keys must map one-to-one -> Units 1 and 3 must preserve the full
  catalog.
- `.design/2026-06-16-flutter-performance-verification-route.md:498` /
  state/data ownership: scenario fixtures are test-host data and timeline
  outputs are generated release-run artifacts -> route files must not create new
  production state or source-of-truth artifact storage.
- `.design/2026-06-16-flutter-performance-verification-route.md:501` /
  entry boundary: route runs from `example`, with each scenario wrapped in
  `traceAction()` and a stable report key -> Units 3 and 4 must preserve stable
  report-key boundaries.
- `.design/2026-06-16-flutter-performance-verification-route.md:511` / order:
  docs SSOT comes first, then example host, scenarios, driver/artifacts, and
  release-gate wording -> execution units follow that order.
- `.design/2026-06-16-flutter-performance-verification-route.md:514` /
  temporal surface: no production temporal invariant changes; test trace windows
  begin before scenario action and end after settle/failure -> Unit 3
  completion checks must prove stable `traceAction()` windows.
- `.design/2026-06-16-flutter-performance-verification-route.md:520` /
  all-or-nothing boundary: release acceptance happens only after drive return
  and artifact inventory check -> Unit 4 owns rejection of missing scenario or
  artifact output as release-gate failure.
- `https://api.flutter.dev/flutter/package-integration_test_integration_test/IntegrationTestWidgetsFlutterBinding/traceAction.html`
  / `IntegrationTestWidgetsFlutterBinding.traceAction`:
  trace API contract: `traceAction` accepts the async action as the first
  argument and stores the timeline under `reportKey` -> the traced runner must
  call `binding.traceAction(() async { ... }, reportKey: scenario.id)`.
- `https://api.flutter.dev/flutter/flutter_driver/TimelineSummary/writeTimelineToFile.html`
  / `TimelineSummary.writeTimelineToFile`: official artifact
  naming: `writeTimelineToFile(traceName, destinationDirectory: ..., includeSummary: true)`
  writes `$traceName.timeline.json` and `$traceName.timeline_summary.json` ->
  the driver must use `scenario.id` as `traceName` and the checker must expect
  official Flutter file names.
- `https://docs.flutter.dev/cookbook/testing/integration/profiling` / official
  driver route: performance
  profiling uses `integrationDriver`, `Timeline.fromJson`,
  `TimelineSummary.summarize`, `writeTimelineToFile`, and
  `flutter drive --profile` -> the local checker may validate inventory and JSON
  shape only, not compute performance pass/fail or define a second result
  format.
- `docs/contracts/public_api_v1.md:125` / external public integration:
  external package code must reference the public surface by importing only
  `package:iwb_canvas_engine/iwb_canvas_engine.dart` -> example route must use
  the public barrel.
- `docs/contracts/public_api_v1.md:362` / public runtime: `CanvasRuntime` is
  public -> performance host may construct and drive runtime through public API.
- `docs/contracts/public_api_v1.md:505` / public surface: `CanvasSurface` is a
  public Flutter widget with runtime and resource resolver inputs -> profile
  route can mount the surface without private imports.
- `docs/contracts/public_api_v1.md:563` / pointer routing: `CanvasSurface`
  routes pointer input into the interaction engine -> gesture scenarios belong
  at the public widget boundary.
- `docs/contracts/public_api_v1.md:1356` / edit port: `CanvasEditPort` exposes
  `loadDocumentFromJson` -> load-document scenarios can be public API
  scenarios.
- `docs/contracts/public_api_v1.md:1496` / command port: public commands
  include remove and text commit -> context delete and text commit scenarios can
  be public API scenarios.
- `docs/contracts/public_api_v1.md:1806` / tool port: `CanvasRuntime.tools` is
  public and non-throwing for modes, styles, pointer policy, and pointer
  dispatch -> draw, select, move, pan, and eraser scenarios can stay public.
- `docs/contracts/public_api_v1.md:1973` / resource rules: resources are
  app-key and app-owned with no engine IO -> resource cold, warm, dirty, and
  missing-resource scenarios stay app-boundary scenarios.
- `docs/contracts/public_api_v1.md:2453` / text editing entry: applications
  decide how to start text editing from context action or overlay -> text-edit
  scenario can use public application-owned routing.
- `docs/contracts/public_api_v1.md:2478` / text editing overlay: the official
  overlay is a public Flutter helper -> inline text route need not use private
  surface internals.
- `docs/contracts/validation_limits.md:31` / total element limit: max total
  elements is `200000` -> 100k element scenarios are within total element limit.
- `docs/contracts/validation_limits.md:102` / raw JSON limit: raw JSON length
  is checked before parse -> `load_document.100k` needs exact fixture-size
  proof.
- `docs/contracts/validation_limits.md:103` / 100k readiness caveat: generic
  100k raw JSON load acceptance is outside v1 release readiness under current
  limit -> implementation must not silently expand limits or claim generic 100k
  readiness.
- `example/pubspec.yaml:15` / example dev dependencies: current dev
  dependencies do not include `integration_test` or `flutter_driver` -> Unit 2
  owns dependency addition for the profile-drive route.

## Boundaries

Owner: `docs/verification/performance.md` owns the official Flutter performance
route. `docs/_registry/sections.yaml` owns its registry metadata and generated
navigation inputs. `docs/verification/tests.md` owns test inventory references.
`docs/verification/release_gates.md` owns release-blocking wording.
`example/lib/perf/**`, `example/integration_test/**`, and
`example/test_driver/perf_driver.dart` own the executable example profile-drive
route. Production `lib/**` remains out of scope unless a separate contract
explicitly escalates a public API gap.

In Scope: create the registered performance verification document; list every
required Flutter scenario id from the design catalog; define the profile-drive
command, artifact contract, completion semantics, non-threshold policy, and
retired benchmark boundary; update generated docs; add example dependencies,
profile host, integration scenarios, driver, report-key coverage proof, and
artifact inventory proof; update tests and release-gate references; run the
repository documentation, Dart, DCM, metrics, focused-test, example-package,
public-boundary, profile-drive, and artifact checks required by the changed
surfaces.

Out of Scope: Android Macrobenchmark implementation; startup scenarios as part
of this Flutter gate; p95, p99, frame-budget, baseline-diff, regression
threshold, custom baseline, or manual-history pass/fail policy; production
runtime behavior or public API changes; `docs/_registry/benchmarks.yaml`;
`docs/indexes/by_benchmark.md`; `docs/verification/benchmarks.md`;
`tool/bench/**`; `test/benchmarks/**`; internal benchmark case ids; private
`package:iwb_canvas_engine/src/**` imports from the example route.

Source of Truth: `docs/verification/performance.md` owns the route meaning.
`docs/_registry/sections.yaml` owns section metadata. Generated context
capsules and indexes are derived consumers checked by generated-doc sync. This
design remains a source input only. The untracked `perf.md` draft is not a
future contract source input while it remains untracked.

Compatibility: No public package API, schema, config, validation limit, or
production behavior may change under this contract. The route must use
`package:iwb_canvas_engine/iwb_canvas_engine.dart` as an external consumer.
`load_document.100k` may be claimed only for the exact fixture that proves it
fits current raw JSON and total-element limits; expanding limits requires a
separate validation-limit design and contract. The release gate claims
completion and artifacts only; numeric performance thresholds remain
non-claimed.

Order Constraints: First create the docs source of truth and registry-backed
navigation, then add example dependencies and the public perf host, then add the
full catalog integration scenarios and 100k fixture proof, then add the
profile driver and artifact inventory proof, then update tests and release
gates and run final generated-doc sync. The release acceptance point is after
the profile drive command returns and the artifact inventory check passes;
missing scenario output, missing artifact, non-zero command exit, crash, hang,
or stale preview/overlay completion failure is release-gate failure, not
partial success. No production temporal invariant changes are allowed; the
test-only temporal invariant is that each `traceAction()` window starts before
the scenario action and ends only after the scenario settles or fails. The
stable report key for every scenario is exactly its scenario id from
`docs/verification/performance.md`.

## Execution Units

### [ ] Unit 1: Register the performance verification source of truth

Owner: `docs/verification/performance.md`,
`docs/_registry/sections.yaml`, generated docs.

Boundary: Documentation source of truth and generated navigation only.

Change: Create the registered `docs/verification/performance.md` section with
the generated context capsule, full Flutter scenario catalog, profile-drive
command, artifact contract, completion-only release semantics, non-threshold
policy, public-consumer boundary, Android-startup exclusion, and retired
benchmark-route exclusions. Add the section row to `docs/_registry/sections.yaml`
with owners including `test` and `release`, subsystem `quality_gates`, and
must-read links to `section_23_tests` and `section_27_final_release_gates`.
Set registry `tests:` entries to these durable ids:
`test.performance.flutter_route_contract`,
`test.example.performance_host_smoke`,
`test.example.performance_fixture_limits`, and
`test.example.performance_profile_drive_artifacts`. Run generated-doc sync so
registry-derived context and indexes are updated.

The artifact contract documented here is fixed: profile-drive outputs live
under `example/build/flutter_performance/`; each scenario id owns one directory
named exactly `<scenario_id>`; each scenario directory must contain
`<scenario_id>.timeline_summary.json` for `TimelineSummary` data and
`<scenario_id>.timeline.json` for the full timeline trace, matching
`TimelineSummary.writeTimelineToFile(scenario.id, destinationDirectory: scenarioDirectory, includeSummary: true)`;
no alternate checked-in artifact location is introduced by this step.

Completion Check: `docs/verification/performance.md` exists with a generated
context capsule for its registry id; `docs/indexes/by_owner.md`,
`docs/indexes/by_subsystem.md`, `docs/indexes/by_test_area.md`, and
`docs/indexes/by_release.md` discover the new section from registry data;
`docs/indexes/by_test_area.md` lists the new section under exactly
`test.performance.flutter_route_contract`,
`test.example.performance_host_smoke`,
`test.example.performance_fixture_limits`, and
`test.example.performance_profile_drive_artifacts`; the
performance catalog contains exactly the required Flutter scenario ids from
`.design/2026-06-16-flutter-performance-verification-route.md:397` through
`.design/2026-06-16-flutter-performance-verification-route.md:430`, excludes
the startup rows from the Flutter gate, and states that numeric thresholds are
not claimed. `dart run docs/tool/sync_generated_docs.dart --check` and
`dart run docs/tool/check_docs.dart` pass after sync. Search/review confirms no
restored `docs/_registry/benchmarks.yaml`, `docs/indexes/by_benchmark.md`,
`docs/verification/benchmarks.md`, `tool/bench/**`, or `test/benchmarks/**`.
The documented artifact contract names
`example/build/flutter_performance/<scenario_id>/<scenario_id>.timeline_summary.json`
and
`example/build/flutter_performance/<scenario_id>/<scenario_id>.timeline.json`
as the only required per-scenario release-run files.

Depends On: none

### [ ] Unit 2: Add the example profile-drive host as a public consumer

Owner: `example/pubspec.yaml`, `example/lib/perf/**`,
`example/test/performance_host_smoke_test.dart`, example package checks,
public-boundary proof.

Boundary: Example package setup and profile host code; no production `lib/**`
changes.

Change: Add the Flutter performance route dependencies needed by
`integration_test` and `flutter drive --profile`, and add an example perf host
that constructs and drives `CanvasRuntime`, `CanvasSurface`, public resource
resolution, public commands, public tools, and public text-editing helpers
through `package:iwb_canvas_engine/iwb_canvas_engine.dart` only. Add a
`PerformanceScenario` descriptor/helper under `example/lib/perf/**` whose
stable `id` is the exact report key and whose traced runner owns the
`binding.traceAction(() async { action-and-settle }, reportKey: id)` boundary.
Keep scenario fixtures as test-host data and timeline outputs as generated
release-run artifacts.

Completion Check: `cd example && flutter pub get` resolves the added
dependencies; `cd example && flutter analyze` passes for the example package;
`cd example && flutter test test/performance_host_smoke_test.dart` mounts the
perf host and fails unless it constructs the public `CanvasRuntime` and
`CanvasSurface`, resolves an app-key resource through the public resolver,
executes at least one public command, switches at least one public tool, and can
enter the public text-editing helper path without private imports;
`flutter test test/api_contract/example_public_boundary_test.dart` passes and
proves example route files import only the public engine barrel, do not
reference private or retired seams, and do not mix production `lib/**` changes
into this example route work. Root `dart analyze`, `dcm analyze .`, and
`dcm calculate-metrics example/lib/perf` pass when `example/lib/perf` exists;
`dcm calculate-metrics example/test` passes for the changed example smoke-test
owner.

Depends On: Unit 1

### [ ] Unit 3: Implement the full Flutter scenario catalog

Owner: `example/lib/perf/performance_scenario.dart`,
`example/integration_test/perf_canvas_surface_test.dart`, example scenario
fixtures, `example/test/performance_fixture_limits_test.dart`,
`test/performance/flutter_performance_route_contract_test.dart`.

Boundary: Integration-test scenario execution through the example host and
public package surface only.

Change: Implement every required Flutter scenario id from the performance doc
as a `PerformanceScenario` descriptor whose `id` is also the exact
integration-test report key. Each scenario must execute through the single
traced runner from `example/lib/perf/performance_scenario.dart`, which wraps the
scenario action and settle/failure boundary in
`binding.traceAction(() async { ... }, reportKey: scenario.id)`:
`load_document.1k`,
`load_document.10k`, `load_document.50k`, `load_document.100k`,
`first_canvas_frame.50k`, `camera_pan.50k`, `camera_pan.100k`,
`selection_tap.10k`, `selection_move.10k`, `selection_move.50k`,
`marquee_select.50k`, `pencil_draw.10k`, `marker_draw.10k`,
`line_two_tap.50k`, `eraser_normal.50k`, `eraser_dense_50k`,
`context_delete.10k`, `text_edit.open_commit`, `text_style_change.10k`,
`resource_image_cold`, `resource_image_warm`, `resource_mark_dirty`,
`missing_resource`, `surface_runtime_swap`, `dispose_during_preview`, and
`json_export.50k`. Add fixture sizing proof for the exact 100k fixture or
fixtures before claiming `load_document.100k` or `camera_pan.100k` readiness
under current validation limits.

Completion Check: `flutter test test/performance/flutter_performance_route_contract_test.dart`
fails if any required scenario id in `docs/verification/performance.md` is
missing from `example/lib/perf/performance_scenario.dart`, if any
`PerformanceScenario.id` differs from its exact integration-test report key, if
`example/integration_test/perf_canvas_surface_test.dart` bypasses the traced
runner or calls `traceAction()` directly, if the traced runner does not call
`binding.traceAction(() async { ... }, reportKey: scenario.id)` around action
plus settle/failure handling, if a startup scenario is included in the Flutter
gate, or if extra internal benchmark case ids are used as route keys.
`cd example && flutter test test/performance_fixture_limits_test.dart`
fails unless the exact fixture or fixtures used by both `load_document.100k`
and `camera_pan.100k` are below the current raw JSON limit and remain within
`200000` total elements; if either 100k proof cannot be made, implementation
stops for a separate validation-limit design instead of changing limits.
`cd example && flutter test integration_test/perf_canvas_surface_test.dart` and
`cd example && flutter test` pass. Root `dart analyze`, `dcm analyze .`, and
`dcm calculate-metrics example/integration_test`,
`dcm calculate-metrics example/test`, and
`dcm calculate-metrics test/performance` pass for the changed integration,
example-test, and root performance-test owners.

Depends On: Unit 2

### [ ] Unit 4: Add the profile driver and artifact inventory proof

Owner: `example/test_driver/perf_driver.dart`,
`tool/check_flutter_performance_artifacts.dart`, generated profile-run
artifacts, artifact inventory verification.

Boundary: Profile-drive execution and generated artifacts; artifacts are
release-run outputs, not checked-in source-of-truth files unless a later
contract establishes artifact retention policy.

Change: Add the official driver for
`cd example && flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/perf_canvas_surface_test.dart --profile --no-dds`.
The driver must write a `TimelineSummary` artifact and full timeline JSON for
every scenario-id report key produced by the integration test, and expose an
inventory check through `tool/check_flutter_performance_artifacts.dart` that
rejects missing scenario outputs, missing artifacts, malformed JSON, or
unexpected extra scenario directories. The fixed output layout is
`example/build/flutter_performance/<scenario_id>/<scenario_id>.timeline_summary.json`
and
`example/build/flutter_performance/<scenario_id>/<scenario_id>.timeline.json`.
The driver must use the official route:
`integrationDriver(responseDataCallback: ...)`, `Timeline.fromJson`,
`TimelineSummary.summarize(timeline)`, and
`summary.writeTimelineToFile(scenario.id, destinationDirectory: scenarioDirectory, includeSummary: true)`.
The checker is limited to inventory and validation: it may compare catalog ids
to generated Flutter timeline files, parse JSON, and reject missing, malformed,
or extra files, but it must not compute performance pass/fail, write summaries,
define a custom benchmark-result schema, or become a second performance engine.

Completion Check: On an appropriate local device or emulator, the official
profile command exits zero. For every required report key, the artifact
inventory command
`dart run tool/check_flutter_performance_artifacts.dart --catalog docs/verification/performance.md --results example/build/flutter_performance`
finds exactly one directory per required scenario id and, in each directory,
both `<scenario_id>.timeline_summary.json` containing valid `TimelineSummary`
JSON and `<scenario_id>.timeline.json` containing valid full timeline JSON.
Missing scenario directory, unexpected scenario directory, missing required
file, malformed JSON, checker-created summary files, checker-created benchmark
result files, crash, hang, stale preview/overlay completion failure, or
non-zero drive/checker exit fails the route. Root `dart analyze`,
`dcm analyze .`,
`dcm calculate-metrics example/test_driver`, and `dcm calculate-metrics tool`
pass.

Depends On: Unit 3

### [ ] Unit 5: Promote the route into test inventory and release gates

Owner: `docs/verification/tests.md`, `docs/verification/release_gates.md`,
generated docs, final verification commands.

Boundary: Test inventory and release policy references; no numeric performance
budget policy and no Android Macrobenchmark route.

Change: Link the performance route from the tests documentation as a distinct
example integration performance route. Replace the current no-performance-gate
release statement with a release-blocking statement that requires the full
Flutter catalog to complete through the profile drive route and requires
summary plus full timeline artifacts for every report key. Preserve explicit
non-threshold wording: p95, p99, frame-budget, baseline-diff, and regression
threshold gates remain unclaimed until a later design/contract establishes
device, environment, repeat-count, artifact retention, and baseline policy.
Run final generated-doc sync and final checks for all changed surfaces.

Completion Check: `docs/verification/release_gates.md` no longer says no
repository-owned release performance gate is claimed, and its replacement gate
matches completion plus artifact production without numeric thresholds.
`docs/verification/tests.md` links the route as example integration
performance verification, not as ordinary package `flutter test` coverage.
Final verification passes: `dart run docs/tool/sync_generated_docs.dart --check`;
`dart run docs/tool/check_docs.dart`; `dart analyze`; `dcm analyze .`; scoped
`dcm calculate-metrics` for every changed Dart owner, including production,
test, example, and tool scopes;
`flutter test test/performance/flutter_performance_route_contract_test.dart`;
`cd example && flutter test test/performance_host_smoke_test.dart`;
`cd example && flutter test test/performance_fixture_limits_test.dart`;
`cd example && flutter test integration_test/perf_canvas_surface_test.dart`;
`dart run tool/check_flutter_performance_artifacts.dart --catalog docs/verification/performance.md --results example/build/flutter_performance`;
`cd example && flutter pub get`; `cd example && flutter test`;
`cd example && flutter analyze`;
`flutter test test/api_contract/example_public_boundary_test.dart`;
`flutter test test/guardrails/root_ci_target_test.dart` if CI route
expectations changed or are relied on by the implementation; the official
profile-drive command; and the per-reportKey artifact inventory check.

Depends On: Unit 4
