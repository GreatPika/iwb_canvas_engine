# Design: Flutter Performance Verification Route

---
date: 2026-06-16
designer: Codex
commit: 63b1a2c7
branch: new-architecture
design_question: "How should the repository introduce an official release-blocking Flutter performance route through integration_test + flutter drive --profile, with every Flutter scenario from perf.md, after removing the old benchmark contour?"
---

## Disposition

READY_FOR_CONTRACT

## Product Outcome

The repository will have an official Flutter performance verification route
that is release-blocking now. The gate is scenario completion plus artifact
production for the full Flutter scenario catalog, not numeric performance
thresholds.

The route measures user scenarios through the example Flutter application as an
external package consumer. It does not restore internal benchmark case ids,
custom baseline diffing, or a repository-owned performance budget.

Non-goals:

- no Android Macrobenchmark implementation in the first Change Contract;
- no p95, p99, baseline-diff, or frame-budget pass/fail thresholds yet;
- no production runtime API or package behavior change unless the future
  contract finds a public route gap that must be explicitly escalated.

## Target Contract Classification

- Profile: SOURCE_OF_TRUTH_DOCS
- Obligations: none

The future contract is docs-led because the durable owner is the verification
and release-gate source of truth. It may add example integration-test code as
the executable proof surface, but it must not change production runtime behavior
as part of this design.

## Research Inputs

- `.research/2026-06-16-flutter-performance-docs-ssot.md` - factual research on
  active docs owners, absent performance routes, generated docs, and affected
  checks.
- Product draft input P1: untracked workspace file `perf.md`, supplied as the
  product draft for this design. Because it is untracked, it is not a future
  Change Contract source input. This design copies the requested Flutter
  scenario catalog and route semantics into the reviewed artifact below; future
  contracts must cite this design artifact's Required Flutter Scenario Catalog
  and selected route decisions instead of citing `perf.md`.

## Repository Evidence

`Evidence Consequence Link`: each fact below states the decision, boundary,
unit, proof surface, or review consequence it supports.

- `docs/README.md:3` - the docs portal routes task work to current
  source-of-truth documentation -> supports putting the durable performance
  route under `docs/`, not only in `perf.md` or `.research/`.
- `docs/README.md:23` - architecture, contracts, verification policy,
  structured relationships, and generated navigation are split into explicit
  source-of-truth families -> supports separating a verification route document
  from registry and generated index outputs.
- `docs/README.md:31` - `.design/` and `.research/` do not own active package
  behavior, release policy, guardrails, roadmaps, external routes, or runtime
  contracts -> supports using this design as handoff only, not as the final
  performance route owner.
- `.research/2026-06-16-flutter-performance-docs-ssot.md:22` - current
  verification source-of-truth docs are `tests.md`, `guardrails.md`, and
  `release_gates.md` -> supports adding a verification-owned performance
  section rather than inventing an unrelated docs area.
- `.research/2026-06-16-flutter-performance-docs-ssot.md:33` - no active
  `docs/verification/performance.md`, old benchmark docs, `tool/bench/`,
  `test/benchmarks/`, `example/integration_test/`, or `example/test_driver/`
  path was found -> supports a future contract that creates the new route and
  does not migrate remaining active benchmark files.
- `docs/_registry/sections.yaml:764` - `section_23_tests` is registered under
  `docs/verification/tests.md` with owner `test` and subsystem `quality_gates`
  -> supports linking the Flutter performance route from test policy.
- `docs/_registry/sections.yaml:919` - `section_27_final_release_gates` is
  registered under `docs/verification/release_gates.md` with owner `release`
  and subsystem `quality_gates` -> supports making the route release-blocking
  through the release-gate owner.
- `docs/verification/release_gates.md:102` - release is blocked unless all
  listed statements are true -> supports expressing the Flutter performance
  route as a release gate when enabled.
- `docs/verification/release_gates.md:167` - current release gates say no
  repository-owned release performance gate is claimed -> supports a mandatory
  future edit that replaces this negative statement.
- `docs/tool/generate_context_capsules.dart:123` - section context capsules are
  rendered from registry entries -> supports registering any new performance
  section in `docs/_registry/sections.yaml`.
- `docs/tool/generate_context_capsules.dart:157` - a registered section file
  must have exactly one generated context capsule at file start -> supports
  creating `docs/verification/performance.md` only with registry-backed capsule
  sync.
- `docs/tool/sync_generated_docs.dart:351` - generated indexes are rendered
  from section rows into the six locked index files -> supports running generated
  docs sync after adding a registered performance section.
- `docs/tool/sync_generated_docs.dart:601` - the release index includes
  sections whose owners contain `release` -> supports giving the new performance
  section a release owner if it owns a release-blocking performance gate.
- `docs/tool/check_docs.dart:29` - generated index paths are locked to the six
  current index files -> supports not recreating `docs/indexes/by_benchmark.md`.
- `docs/tool/check_docs.dart:255` - retired section fields include
  `benchmarks` -> supports not reintroducing benchmark registry metadata.
- `docs/tool/check_docs.dart:685` - markdown path checks scan
  `docs/verification` and indexes -> supports docs checks as the verification
  surface for new performance markdown paths and references.
- `AGENTS.md:74` - documentation-only changes run generated-docs and docs
  checks instead of Dart/DCM checks -> supports docs check commands for the
  docs-only portion of the future contract.
- `AGENTS.md:48` - every Dart code change, including production, test, and tool
  code, must run repository code checks -> supports carrying code verification
  into the future example integration-test and driver implementation units.
- `AGENTS.md:51` - required Dart code checks include `dart analyze` -> supports
  analyzer proof for changed example Dart files.
- `AGENTS.md:52` - required Dart code checks include `dcm analyze .` ->
  supports DCM proof for changed example Dart files.
- `AGENTS.md:53` - required Dart code checks include
  `dcm calculate-metrics` for changed owners -> supports metrics proof for
  `example/lib/perf`, `example/integration_test`, and `example/test_driver`
  owners when those Dart files are added.
- `AGENTS.md:61` - focused tests that cover changed behavior or changed tools
  must run -> supports focused example/performance route tests in addition to
  the profile-drive release run.
- `AGENTS.md:85` - mixed code and documentation changes require relevant code
  checks, focused tests, architecture checks when triggered, and documentation
  checks -> supports treating the future implementation as a mixed docs plus
  Dart-code contract.
- `.github/workflows/root_package.yml:55` - CI has a separate
  `example-package` job -> supports carrying example package checks into the
  future route implementation.
- `.github/workflows/root_package.yml:67` - the example package job runs
  `flutter pub get` in `example` -> supports dependency-lock/install proof for
  added `integration_test` and `flutter_driver` dependencies.
- `.github/workflows/root_package.yml:71` - the example package job runs
  `flutter test` in `example` -> supports the example package test proof for
  changed example support code.
- `.github/workflows/root_package.yml:75` - the example package job runs
  `flutter analyze` in `example` -> supports example-specific analyzer proof.
- `test/guardrails/root_ci_target_test.dart:125` - root CI structural proof
  requires the `example-package` job -> supports preserving the example CI
  route as a repository-owned proof surface.
- `test/guardrails/root_ci_target_test.dart:133` - the structural proof rejects
  bypass on the example package job and checks the example commands -> supports
  treating example package checks as mandatory, not optional local convenience.
- `docs/verification/tests.md:453` - `test/api_contract/example_public_boundary_test.dart`
  is the documented owner for example public-boundary proof -> supports using
  the existing test instead of an ad hoc import search as the primary boundary
  proof.
- `test/api_contract/example_public_boundary_test.dart:48` - the test proves
  example imports the engine only through the public barrel -> supports the
  performance route public consumer boundary.
- `test/api_contract/example_public_boundary_test.dart:67` - the test proves
  example sources do not reference private or retired seams -> supports old
  benchmark/retired-seam quarantine for example route additions.
- `test/api_contract/example_public_boundary_test.dart:99` - the test rejects
  current example-step diffs that also modify production `lib/**` source ->
  supports keeping example performance route work separate from production
  engine contracts.

Product draft input P1 named exception: the following `perf.md:*` lines are
untracked workspace draft provenance. They are copied into this reviewed design
artifact and are not future Change Contract source inputs while `perf.md`
remains untracked.

- `perf.md:3` - the proposed route measures real scenarios through `example` as
  an external Flutter consumer instead of internal old case ids -> supports the
  selected boundary of example app plus public API.
- `perf.md:7` - the Flutter route is `integration_test` plus
  `flutter drive --profile` with `Timeline`, `TimelineSummary`, skipped frames,
  slow build/raster, and full trace -> supports the gate artifact requirements.
- `perf.md:17` - the scenario matrix names the Flutter and Android columns ->
  supports deriving the Flutter catalog from rows marked `Da` in the Flutter
  column and treating startup rows as Android future pressure.
- `perf.md:19` - `startup.empty_canvas` is not primary for Flutter and is
  Android Macrobenchmark-owned -> supports excluding startup from the Flutter
  release gate while recording it as future Android pressure.
- `perf.md:21` - `load_document.1k` is a Flutter scenario -> supports including
  it in the required Flutter catalog.
- `perf.md:22` - `load_document.10k` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:23` - `load_document.50k` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:24` - `load_document.100k` is a Flutter scenario when it is inside
  contract limits -> supports including it in the catalog with a validation
  proof requirement.
- `perf.md:25` - `first_canvas_frame.50k` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:26` - `camera_pan.50k` is a Flutter scenario -> supports including
  it in the required Flutter catalog.
- `perf.md:27` - `camera_pan.100k` is a Flutter scenario -> supports including
  it in the required Flutter catalog.
- `perf.md:28` - `selection_tap.10k` is a Flutter scenario -> supports including
  it in the required Flutter catalog.
- `perf.md:29` - `selection_move.10k` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:30` - `selection_move.50k` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:31` - `marquee_select.50k` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:32` - `pencil_draw.10k` is a Flutter scenario -> supports including
  it in the required Flutter catalog.
- `perf.md:33` - `marker_draw.10k` is a Flutter scenario -> supports including
  it in the required Flutter catalog.
- `perf.md:34` - `line_two_tap.50k` is a Flutter scenario -> supports including
  it in the required Flutter catalog.
- `perf.md:35` - `eraser_normal.50k` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:36` - `eraser_dense_50k` is a Flutter scenario -> supports including
  it in the required Flutter catalog.
- `perf.md:37` - `context_delete.10k` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:38` - `text_edit.open_commit` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:39` - `text_style_change.10k` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:40` - `resource_image_cold` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:41` - `resource_image_warm` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:42` - `resource_mark_dirty` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:43` - `missing_resource` is a Flutter scenario -> supports including
  it in the required Flutter catalog.
- `perf.md:44` - `surface_runtime_swap` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:45` - `dispose_during_preview` is a Flutter scenario -> supports
  including it in the required Flutter catalog.
- `perf.md:46` - `json_export.50k` is a Flutter scenario -> supports including
  it in the required Flutter catalog.
- `perf.md:48` - the matrix is described as the full scenario list for the
  engine -> supports treating omissions from the Flutter catalog as contract
  drift.
- `perf.md:63` - the Flutter contour measures scenario timeline facts and
  completion without stuck preview, stale overlay, or crash -> supports release
  gate pass/fail semantics based on completion and artifacts, not numeric
  budgets.
- `perf.md:121` - the draft says the old documentation should be replaced by
  `docs/verification/performance.md` -> supports the new SSOT document.
- `perf.md:139` - the draft describes adding Flutter `integration_test`
  dependencies and route setup -> supports the future example implementation
  unit.
- `perf.md:237` - the perf screen principle uses `CanvasRuntime`,
  `CanvasSurface`, `CanvasResourceResolver`, and public commands, with no
  `lib/src/**` imports -> supports the public API boundary.
- `perf.md:322` - the integration test file is
  `example/integration_test/perf_canvas_surface_test.dart` -> supports the
  future proof file placement.
- `perf.md:463` - the official driver file is
  `example/test_driver/perf_driver.dart` -> supports the artifact-writing
  proof file placement.
- `perf.md:509` - the route runs from `example` with `flutter drive`,
  `--driver`, `--target`, `--profile`, and `--no-dds` -> supports the required
  documented command.
- `docs/contracts/public_api_v1.md:125` - the public integration compile
  fixture proves external package code can reference the public surface by
  importing only `package:iwb_canvas_engine/iwb_canvas_engine.dart` -> supports
  keeping performance scenarios as public consumer code.
- `docs/contracts/public_api_v1.md:362` - `CanvasRuntime` exposes document
  read, state, edits, selection, tools, commands, camera, resources, preview,
  actions, context requests, id generation, and dispose -> supports all scenario
  families being driven through public ports unless a future contract finds a
  specific gap.
- `docs/contracts/public_api_v1.md:505` - `CanvasSurface` is public and accepts
  runtime, resource resolver, styles, and interactive flag -> supports mounting
  the perf route through the public widget.
- `docs/contracts/public_api_v1.md:563` - `CanvasSurface` routes pointer input
  into the interaction engine -> supports pan, selection, draw, eraser, marquee,
  line, and preview scenarios through widget gestures.
- `docs/contracts/public_api_v1.md:1356` - `CanvasEditPort` exposes
  `loadDocumentFromJson` -> supports load-document scenarios through public
  API.
- `docs/contracts/public_api_v1.md:1496` - `CanvasCommandPort` exposes
  `removeElement`, `commitTextEdit`, and `clearContent` -> supports context
  delete, text commit, and export/save-path supporting actions.
- `docs/contracts/public_api_v1.md:1806` - `CanvasRuntime.tools` is public and
  non-throwing for mode, draw style, pointer policy, and pointer dispatch ->
  supports tool-switching scenarios.
- `docs/contracts/public_api_v1.md:1973` - v1 resource rules include app-key
  resources, no engine IO, synchronous resolver, app-owned images, and dirty
  invalidation -> supports resource cold, warm, dirty, and missing-resource
  scenarios.
- `docs/contracts/public_api_v1.md:2453` - application code decides whether to
  start text editing from context action or mount `CanvasTextEditingOverlay` ->
  supports the text edit scenario through public text-editing surface.
- `docs/contracts/public_api_v1.md:2478` - `CanvasTextEditingOverlay` is a
  public Flutter helper owned by surface -> supports a profile-mode text edit
  scenario without private imports.
- `docs/contracts/validation_limits.md:31` - max total elements is `200000` ->
  supports 100k element scenarios being below the total element-count limit.
- `docs/contracts/validation_limits.md:102` - raw JSON limit applies to
  `CanvasEditPort.loadDocumentFromJson(String json)` before parse -> supports
  requiring a fixture-size proof for `load_document.100k`.
- `docs/contracts/validation_limits.md:103` - under the current raw JSON limit,
  100k raw JSON load acceptance is outside v1 release readiness unless a later
  design changes the limit with memory proof -> supports keeping the 100k
  scenario in the catalog while forcing the future contract to prove the exact
  fixture fits current limits or stop before silently expanding limits.
- `example/pubspec.yaml:15` - the example currently has `flutter_test`,
  `flutter_lints`, and `yaml` dev dependencies only -> supports adding
  `integration_test` and `flutter_driver` in the future proof unit.

The `perf.md:*` citations above are Product draft input P1 evidence only. They
explain why this design locks the catalog and route semantics; they must not be
used as future Change Contract source inputs while `perf.md` remains untracked.

## Design Form Candidates

### Candidate A. Extend `tests.md` and `release_gates.md` only

- Form: put the performance command, scenario catalog, and gate wording directly
  into existing verification docs.
- Why it could work: the existing docs already own test inventory and release
  gates.
- Gate failures or risks: fails Source-Of-Truth Singularity because the full
  scenario catalog, route command, artifact contract, release semantics, and
  threshold non-claim would be scattered across multiple documents. It also
  makes generated discovery weaker because there is no registered performance
  section to index.

### Candidate B. Add a registered `docs/verification/performance.md` owner

- Form: create a new verification section registered in
  `docs/_registry/sections.yaml`; make it own the Flutter route command,
  scenario catalog, artifact contract, release-gate semantics, non-threshold
  policy, and old-benchmark-retirement boundary. Link it from tests and release
  gates.
- Why it could work: it gives performance verification one source of truth while
  preserving existing test and release-gate owners. Generated capsules and
  indexes remain registry-derived.
- Gate failures or risks: requires a future contract to update registry,
  generated docs, and related verification docs together. The `100k` scenarios
  require a fixture-size proof because current validation limits do not claim
  generic 100k raw JSON load release readiness.

### Candidate C. Keep `perf.md` as the route owner

- Form: leave the scenario catalog and route command in the root draft and link
  to it from future work.
- Why it could work: it already contains the desired catalog and route outline.
- Gate failures or risks: fails Ownership and Source-Of-Truth Singularity.
  `perf.md` is outside `docs/`, is currently untracked working-tree material,
  and is not registry-backed or generated-navigation-backed. It cannot own
  release policy.

## Known Future Pressures

| Pressure | Evidence | How the selected form responds | Accepted cost or risk |
|---|---|---|---|
| Full Flutter catalog must be preserved. | Product draft input P1 requested the full Flutter scenario list, and this artifact locks that list in Required Flutter Scenario Catalog. | The selected form makes the catalog table part of `docs/verification/performance.md` and requires matching integration-test report keys. | The future contract must implement or explicitly block every listed scenario; no silent partial MVP. |
| Release gate must exist before numeric budgets are credible. | `docs/verification/release_gates.md:167` currently denies a release performance gate, while this artifact locks completion and timeline artifacts as the selected release gate. | The selected form replaces the negative release-gate claim with scenario-completion plus artifact-production gate, while stating numeric budgets are not claimed yet. | Release work may require a manual or local device run until CI/device infrastructure exists. |
| 100k rows are desired but current raw JSON release readiness is constrained. | Required Flutter Scenario Catalog includes `load_document.100k` and `camera_pan.100k`; `docs/contracts/validation_limits.md:103` says generic 100k raw JSON load acceptance is outside v1 release readiness under current raw JSON limit. | The selected form includes both 100k scenarios in the catalog and requires the future contract to prove the exact fixture respects current limits or stop before changing limits. | If the exact fixture cannot fit current limits, a later validation-limit design with memory proof is required before claiming `load_document.100k` release readiness. |
| Android startup and Macrobenchmark route remains future pressure. | Product draft input P1 classifies startup as not primary for Flutter and Android-owned, while this artifact excludes startup from Required Flutter Scenario Catalog. | The selected form explicitly excludes startup from the Flutter release gate and records Android route as future source-of-truth scope. | Startup remains ungated by Flutter route until Android Macrobenchmark design and implementation. |
| Old benchmark metadata must not return. | `docs/tool/check_docs.dart:255` rejects the retired `benchmarks` section field, and `docs/tool/check_docs.dart:29` locks generated indexes to six files. | The selected form forbids `docs/_registry/benchmarks.yaml`, `docs/indexes/by_benchmark.md`, and `tool/bench/**` as successor route owners. | Any future benchmark-like metadata must use current section registry fields, not retired benchmark registries. |
| Generated docs must stay authoritative. | `docs/tool/generate_context_capsules.dart:157` requires registered section files to have generated context capsules; `docs/tool/sync_generated_docs.dart:351` renders generated indexes. | The selected form requires registry first, context capsule sync, and generated index sync in the future contract. | Docs-only changes become multi-file because generated outputs must be updated. |
| Example route code must carry repository Dart proof. | `AGENTS.md:48` requires checks after Dart code changes, `AGENTS.md:51` through `AGENTS.md:53` name analyzer/DCM/metrics commands, and `AGENTS.md:61` requires focused tests. | The selected form records separate docs proof and Dart-code proof surfaces for the future contract. | The first implementation cannot close on docs checks plus `flutter drive` alone; it must also run repository code checks for changed example owners. |
| Example package has its own CI proof route. | `.github/workflows/root_package.yml:55` defines `example-package`, `.github/workflows/root_package.yml:67` through `.github/workflows/root_package.yml:77` run example pub get/test/analyze, and `test/guardrails/root_ci_target_test.dart:125` structurally enforces that job. | The selected form makes those checks part of future handoff for any `example/**` implementation. | Future local verification is heavier but matches repository CI ownership. |
| Example public-boundary proof already exists. | `docs/verification/tests.md:453` documents `test/api_contract/example_public_boundary_test.dart`, and `test/api_contract/example_public_boundary_test.dart:48` proves public-barrel imports. | The selected form uses the existing structural test as primary proof, with semantic search only as a supplementary review aid if needed. | Future contract should not invent a parallel import checker unless the existing test cannot cover a new path. |

## Selected Form

Use Candidate B: add a registered `docs/verification/performance.md` source of
truth for the official performance route, then link it into the existing tests
and release-gate owners.

The selected form is the best fit because performance verification has enough
durable meaning to deserve its own owner: scenario catalog, command line,
artifacts, release-gate pass/fail semantics, non-threshold policy, public API
boundary, and future Android separation. Keeping these in `tests.md` or
`release_gates.md` would mix route ownership with inventories. Keeping them in
`perf.md` would leave active release policy outside the documented source of
truth.

The selected release gate is:

```text
The full Flutter performance catalog must run from `example` through
`flutter drive --profile`; each catalog scenario must complete without crash,
hang, stale preview/overlay completion failure, or missing result; the driver
must write a TimelineSummary artifact and full timeline JSON for every catalog
report key.
```

The selected non-gate is:

```text
No numeric frame-time, skipped-frame, p95/p99, baseline-diff, or regression
threshold is claimed until a later design/contract establishes device,
environment, repeat-count, artifact retention, and baseline policy.
```

### Required Flutter Scenario Catalog

The future `docs/verification/performance.md` must list all Flutter
`integration_test` plus `flutter drive --profile` scenarios below. The future
integration test report keys must map one-to-one to these scenario ids.

| Scenario id | Release gate status | Evidence |
|---|---|---|
| `load_document.1k` | required | Product draft input P1, locked by this reviewed design |
| `load_document.10k` | required | Product draft input P1, locked by this reviewed design |
| `load_document.50k` | required | Product draft input P1, locked by this reviewed design |
| `load_document.100k` | required with current-limit fixture proof | Product draft input P1; `docs/contracts/validation_limits.md:103` |
| `first_canvas_frame.50k` | required | Product draft input P1, locked by this reviewed design |
| `camera_pan.50k` | required | Product draft input P1, locked by this reviewed design |
| `camera_pan.100k` | required with current-limit fixture proof | Product draft input P1; `docs/contracts/validation_limits.md:103` |
| `selection_tap.10k` | required | Product draft input P1, locked by this reviewed design |
| `selection_move.10k` | required | Product draft input P1, locked by this reviewed design |
| `selection_move.50k` | required | Product draft input P1, locked by this reviewed design |
| `marquee_select.50k` | required | Product draft input P1, locked by this reviewed design |
| `pencil_draw.10k` | required | Product draft input P1, locked by this reviewed design |
| `marker_draw.10k` | required | Product draft input P1, locked by this reviewed design |
| `line_two_tap.50k` | required | Product draft input P1, locked by this reviewed design |
| `eraser_normal.50k` | required | Product draft input P1, locked by this reviewed design |
| `eraser_dense_50k` | required | Product draft input P1, locked by this reviewed design |
| `context_delete.10k` | required | Product draft input P1, locked by this reviewed design |
| `text_edit.open_commit` | required | Product draft input P1, locked by this reviewed design |
| `text_style_change.10k` | required | Product draft input P1, locked by this reviewed design |
| `resource_image_cold` | required | Product draft input P1, locked by this reviewed design |
| `resource_image_warm` | required | Product draft input P1, locked by this reviewed design |
| `resource_mark_dirty` | required | Product draft input P1, locked by this reviewed design |
| `missing_resource` | required | Product draft input P1, locked by this reviewed design |
| `surface_runtime_swap` | required | Product draft input P1, locked by this reviewed design |
| `dispose_during_preview` | required | Product draft input P1, locked by this reviewed design |
| `json_export.50k` | required | Product draft input P1, locked by this reviewed design |

`startup.empty_canvas` and `startup.canvas_ready_1k` are intentionally not part
of this Flutter route because Product draft input P1 classified them as not
primary for Flutter and Android Macrobenchmark-owned.

## Decision Trace

Preserve `Decision Chain Of Custody`: source inputs and locked decisions must
map to the future contract field, execution unit, or proof surface that carries
them forward.

| Decision ID | Decision | Evidence | Contract handoff target |
|---|---|---|---|
| D1 | The durable performance route owner is a new registered `docs/verification/performance.md` section. | `docs/README.md:23`, `.research/2026-06-16-flutter-performance-docs-ssot.md:33`, this design's Selected Form | `Boundaries.Source of Truth`, `Unit 1` docs registry and performance doc |
| D2 | The route is release-blocking now as completion plus artifact production, not numeric thresholds. | `docs/verification/release_gates.md:102`, `docs/verification/release_gates.md:167`, this design's selected release gate | `Boundaries.Release Gate`, `Unit 2` release gate update |
| D3 | The Flutter catalog must include every scenario row in this design's Required Flutter Scenario Catalog. | Product draft input P1 copied into this reviewed design artifact | `Unit 1` scenario catalog, `Unit 4` integration test report-key coverage |
| D4 | The route runs through `example` as an external public consumer and must not import `lib/src/**` or restore internal benchmark ids. | `docs/contracts/public_api_v1.md:125`, this design's selected public-consumer boundary | `Boundaries.Entry`, `Unit 3` example perf host, proof surface public import check |
| D5 | `TimelineSummary` and full timeline JSON are required artifacts for every scenario report key. | This design's selected release gate and Verification Strategy | `Completion Checks`, `Unit 5` driver and artifact verification |
| D6 | The 100k scenarios are catalog requirements, but `load_document.100k` must not silently expand validation limits. | Required Flutter Scenario Catalog, `docs/contracts/validation_limits.md:31`, `docs/contracts/validation_limits.md:103` | `Risks`, `Unit 3` fixture sizing proof, `Unit 4` 100k scenario implementation |
| D7 | Old benchmark registry/index/tooling routes remain retired. | `docs/tool/check_docs.dart:29`, `docs/tool/check_docs.dart:255`, `.research/2026-06-16-flutter-performance-docs-ssot.md:33` | `Out of Scope`, semantic search proof for no retired benchmark route |
| D8 | Any future example Dart/test/driver implementation must carry the repository's Dart analyzer, DCM, metrics, focused-test, example-package, and example public-boundary proof surfaces. | `AGENTS.md:48`, `AGENTS.md:51`, `AGENTS.md:52`, `AGENTS.md:53`, `AGENTS.md:61`, `AGENTS.md:85`, `.github/workflows/root_package.yml:55`, `.github/workflows/root_package.yml:67`, `test/guardrails/root_ci_target_test.dart:125`, `docs/verification/tests.md:453`, `test/api_contract/example_public_boundary_test.dart:48` | `Completion Checks`, `Unit 3` example perf host, `Unit 4` integration scenarios, `Unit 5` driver and artifact verification |

## Outcome-Proof Fit

| Claim | Direct outcome | Proxy risk | Required proof surface or strategy |
|---|---|---|---|
| `docs/verification/performance.md` owns the route. | Registered section file exists, has generated context capsule, and appears in generated indexes. | A markdown file exists but is not registry-backed or discoverable. | `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart`; inspect generated diff when sync changes files. |
| Release gate exists now. | `docs/verification/release_gates.md` no longer says no performance gate is claimed and instead requires the Flutter route completion/artifacts. | Docs mention performance but release gates remain negative or non-blocking. | Docs check plus focused review of release-gate wording against D2. |
| Full Flutter catalog is preserved. | The performance doc lists every scenario id from this design's Required Flutter Scenario Catalog, and integration-test report keys map one-to-one. | A few smoke scenarios pass while omitted scenarios are not visible. | Catalog-to-reportKey structural test or script in future contract, plus manual review against this design table. |
| Route uses public consumer boundary. | Example perf host imports public package facade and drives `CanvasRuntime`, `CanvasSurface`, public ports, and public widgets only. | Integration tests call package internals and pass without proving consumer route. | `flutter test test/api_contract/example_public_boundary_test.dart`; example `flutter analyze`; existing structural test coverage for public barrel imports and retired/private seam references. |
| Artifacts are official Flutter trace artifacts. | Driver writes `TimelineSummary` and full timeline JSON for every `perf_` report key. | Tests pass but no usable trace files are produced. | Future focused verification checks artifact files after a profile drive run, or documents exact release-run checklist when device execution is manual. |
| Example Dart code satisfies repository code gates. | `dart analyze`, `dcm analyze .`, `dcm calculate-metrics` for changed example owners, and focused tests all run for the future Dart changes. | A profile-drive route works locally but violates repository static-analysis, metrics, or focused-test requirements. | Future contract completion checks must include the AGENTS-mandated code verification commands for `example/lib/perf`, `example/integration_test`, `example/test_driver`, and any other changed Dart owner. |
| Example package remains green as its own package. | `cd example && flutter pub get`, `cd example && flutter test`, and `cd example && flutter analyze` all pass. | Root checks pass while the standalone example package fails dependency resolution, package tests, or package analysis. | Future contract completion checks must include the existing example-package commands from CI. |
| Numeric thresholds are not claimed. | Performance doc and release gate explicitly state no p95/p99/baseline budget gate exists yet. | Teams treat trace output as a pass/fail budget without environment policy. | Docs review against non-threshold wording; no threshold fields in registry or custom baseline tooling. |
| 100k inclusion does not bypass validation limits. | Future contract proves the exact 100k fixture respects current raw JSON limit, or stops and records the blocker before implementation claims release readiness. | The route raises limits or truncates the scenario silently. | Fixture-size assertion and validation-limits citation in future contract; if limit change is needed, separate design with memory proof. |

## Hard Gate Check

| Gate | Result | Evidence |
|---|---|---|
| Owner-Level Fix | pass | The missing owner is an official verification route, not a production hot-path bug; `docs/README.md:23` places verification policy under `docs/verification/`, and this design selects `docs/verification/performance.md`. |
| Ownership | pass | The selected form gives the route one docs owner while keeping release decision in `release_gates.md`; `docs/_registry/sections.yaml:919` shows release gates remain the release owner. |
| Source-Of-Truth Singularity | pass | `docs/README.md:31` says `.design/` and `.research/` do not own active routes, so the future owner must be a registered docs section. |
| Boundary-Owned Policy | pass | Product draft input P1 requested public commands and no `lib/src/**`; `docs/contracts/public_api_v1.md:125` proves external public-import boundary exists. |
| Negative Proof And Fixture Quarantine | pass | Scenario ids are durable user scenarios locked in Required Flutter Scenario Catalog, not phase/slice/fixture names. Retired benchmark fields remain rejected by `docs/tool/check_docs.dart:255`. |
| Dependency direction | pass | Example code consumes `package:iwb_canvas_engine/iwb_canvas_engine.dart`; public API evidence is at `docs/contracts/public_api_v1.md:125`. No production layer import direction changes are selected. |
| State/data | pass | The route observes runtime and Flutter timeline state only; it does not introduce duplicate committed document, cache, resource, or benchmark state. This design's selected release gate defines timeline/completion outputs. |
| Sequenced Migration And Retirement | pass | Old benchmark route paths are absent by research, and retired benchmark registry/index forms are rejected by current docs tooling. Future sequence is add new docs owner, add proof route, then make release gate positive. |
| Temporal Surface Closure | pass | The trace window is owned by `IntegrationTestWidgetsFlutterBinding.traceAction()` around each scenario action, and completion requires no stuck preview/overlay/crash per this design's selected release gate. No production callback ordering is changed. |
| All-Or-Nothing Failure Boundary | pass | A release run is accepted only if every required scenario completes and every expected trace artifact is written; missing scenario or artifact fails the gate. No partial catalog pass is accepted. |
| Outcome-Proof Fit | pass | The table above maps each claim to a direct outcome and required proof. |
| Verification | pass | Docs checks are owned by `AGENTS.md:74` through `AGENTS.md:83`; Dart code checks are required by `AGENTS.md:48` through `AGENTS.md:61`; Flutter route proof is the future `flutter drive --profile` command locked in this design's Verification Impact. |
| Future pressure | pass | Android Macrobenchmark, numeric budgets, old route retirement, generated docs, and 100k validation limits are all recorded in Known Future Pressures. |

## Lock-Required Facts

- Owner: `docs/verification/performance.md` owns the official Flutter
  performance route; `docs/verification/release_gates.md` owns the
  release-blocking statement; `docs/verification/tests.md` owns test inventory
  references.
- Owning layer/module/document family: `docs/verification/` plus
  `docs/_registry/sections.yaml` for section metadata and generated navigation.
- Seam: example app profile-drive seam: `example/lib/perf/**`,
  `example/integration_test/**`, and `example/test_driver/perf_driver.dart`.
- Dependency/import direction: example and integration tests may import
  `package:iwb_canvas_engine/iwb_canvas_engine.dart` and Flutter SDK packages;
  they must not import `package:iwb_canvas_engine/src/**`.
- State/data ownership: scenario fixture documents are test-host data, not
  production state. Timeline outputs are generated release-run artifacts, not
  source-of-truth docs.
- Entry boundaries: `flutter drive --profile` from `example`; each scenario
  wrapped in `IntegrationTestWidgetsFlutterBinding.traceAction()` with a stable
  report key.
- Exit boundaries: `TimelineSummary` artifact and full timeline JSON for every
  report key; non-zero command exit, missing artifact, crash, hang, or scenario
  completion failure blocks release.
- File placement basis: route docs under `docs/verification/`; generated
  navigation through registry; executable Flutter proof under `example` because
  Product draft input P1 selected external consumer scenarios and this design
  locks that boundary.
- Execution order constraints: future Change Contract should update and verify
  docs SSOT first, then example dependencies/host, then integration scenarios,
  then driver/artifact checks, then release-gate wording and final docs sync.
- `Temporal Surface Closure` invariant, synchronous callback surfaces,
  guard/boundary owner, public observation order, and expected
  rejection/no-mutation signal: no production temporal invariant changes. The
  test-only temporal invariant is that each trace window begins before the user
  scenario action and ends only after the scenario settles or fails; the release
  boundary rejects incomplete runs by missing result/artifact.
- `All-Or-Nothing Failure Boundary` irreversible point, fallible-before-
  irreversible work, later infallible/failure-contained/accepted work, failure
  projection, and proof surface: the release gate acceptance point is after the
  drive command returns and artifact inventory is checked. All scenario
  execution and artifact writes are fallible before that point. Missing scenario
  output projects as release-gate failure, not partial success.
- Rejected alternatives: scatter route across existing docs only; keep `perf.md`
  as owner; restore old benchmark registry/index/tooling.
- Verification strategy: docs checks for SSOT, the existing
  `test/api_contract/example_public_boundary_test.dart` for public boundary,
  repository Dart analyzer/DCM/metrics checks for changed example owners,
  example-package `flutter pub get`/`flutter test`/`flutter analyze`, focused
  tests for changed example behavior/tooling, profile-drive execution for
  scenario completion and artifacts, and catalog-to-reportKey coverage proof for
  no omitted scenarios.

## Diagram Need Assessment

| Design question | Needed? | Diagram kind | Reason |
|---|---:|---|---|
| Does the design change ownership, layer, package, or component boundaries? | no | none | It adds a docs owner and example proof route but does not change production ownership or package boundaries. |
| Does it change data flow, state ownership, cache ownership, resource movement, or lifecycle movement? | no | none | Scenario fixture data and timeline artifacts are test/release-run outputs, not production state or cache ownership. |
| Does it depend on call order, lifecycle order, sync/async ordering, failure ordering, or migration order? | no | none | The future contract has an execution order, but no architecture diagram is needed to understand it. |
| Does it introduce or alter observer/listener/callback delivery, guard windows, public-state publication, or reentrancy-sensitive ordering? | no | none | The route observes existing public behavior only. |
| Does it introduce or alter modes, statuses, terminal states, sessions, or transition rules? | no | none | It measures existing canvas modes and sessions but does not change their state machines. |
| Does it create, replace, migrate, or retire a shared seam under `Sequenced Migration And Retirement`? | no | none | Old benchmark route is already absent; this design forbids restoring retired route shapes. |
| Does it change public API consumer flow, payload shape, or compatibility behavior? | no | none | It consumes the current public API from `example`; no public API shape change is selected. |
| Does it introduce or change analyzer, guardrail, or structural-recognition pipeline behavior? | no | none | A future structural test may prove catalog/reportKey coverage, but no new analyzer or guardrail pipeline is designed here. |

## Provisional Diagrams

None.

## Source-Of-Truth Impact

Future Change Contract must update these source-of-truth files and generated
outputs as one coherent route:

- `docs/verification/performance.md`: new registered owner for the Flutter
  performance route, full scenario catalog, command, artifacts, release
  semantics, non-threshold policy, and old benchmark retirement boundary.
- `docs/_registry/sections.yaml`: new section row for the performance document,
  with owners including `test` and `release`, subsystem `quality_gates`, and
  must-read links to `section_23_tests` and `section_27_final_release_gates`
  unless the future contract proves a different acyclic placement.
- `docs/verification/tests.md`: reference the Flutter profile-drive route as a
  distinct example integration performance route, not an ordinary package
  `flutter test` surface test.
- `docs/verification/release_gates.md`: replace the current no-performance-gate
  statement with the scenario-completion plus artifact-production release gate.
- Generated context capsules and indexes from
  `dart run docs/tool/sync_generated_docs.dart`.

The future contract must not create or restore:

- `docs/_registry/benchmarks.yaml`;
- `docs/indexes/by_benchmark.md`;
- `docs/verification/benchmarks.md`;
- `tool/bench/**`;
- `test/benchmarks/**`;
- custom baseline/diff/manual-history command routes.

## Verification Impact

Future Change Contract should use these proof surfaces:

- `dart run docs/tool/sync_generated_docs.dart --check`;
- `dart run docs/tool/check_docs.dart`;
- if generated docs are stale, run `dart run docs/tool/sync_generated_docs.dart`
  and rerun both docs checks;
- `dart analyze` for any future Dart code changes;
- `dcm analyze .` for any future Dart code changes;
- `dcm calculate-metrics` for changed Dart owners, starting with
  `example/lib/perf`, `example/integration_test`, and `example/test_driver`
  when those owners are added or changed;
- focused tests that cover changed example behavior or changed driver/tooling;
- `cd example && flutter pub get`;
- `cd example && flutter test`;
- `cd example && flutter analyze`;
- `flutter test test/api_contract/example_public_boundary_test.dart`;
- `flutter test test/guardrails/root_ci_target_test.dart` if the future
  contract changes CI workflow expectations or relies on example-package CI
  routing;
- existing example public-boundary structural proof for no engine-internal
  imports, no private/retired seams, and no mixed example-plus-production diff;
- catalog-to-reportKey coverage proof that every required scenario id in the
  performance doc maps to an integration-test report key;
- `cd example && flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/perf_canvas_surface_test.dart --profile --no-dds`
  on an appropriate local device or emulator;
- artifact inventory check proving every scenario report key produced
  `TimelineSummary` and full timeline JSON.

Architecture graph checks are not required by this design unless the future
contract changes architecture docs, generated architecture diagrams,
`docs/architecture/architecture_graph.yaml`, or release gates that depend on
current graph closure.

## Verification Strategy

The first release-blocking performance gate verifies that the official route is
complete and usable:

1. The full catalog is documented and discoverable through docs registry and
   generated indexes.
2. The example app exposes a profile-drive host that uses only public package
   APIs.
3. Changed example Dart owners pass `dart analyze`, `dcm analyze .`,
   `dcm calculate-metrics`, and focused tests required by `AGENTS.md`.
4. The standalone example package passes `flutter pub get`, `flutter test`, and
   `flutter analyze`.
5. The existing example public-boundary test proves the new example route uses
   only the public engine barrel and does not mix production `lib/**` changes
   into the example route contract.
6. Every catalog scenario has a stable `traceAction()` report key.
7. The profile drive command completes.
8. The driver writes both summary and full timeline artifacts for every report
   key.

Frame-time numbers remain analysis artifacts until a later design establishes a
numerical budget policy with environment and baseline controls.

## Change Contract Handoff

- Required profile: SOURCE_OF_TRUTH_DOCS
- Required obligations: none
- Decision IDs / Decision Trace rows to preserve: D1, D2, D3, D4, D5, D6, D7,
  D8
- Evidence to cite:
  - `docs/README.md:23`
  - `docs/README.md:31`
  - `docs/verification/release_gates.md:102`
  - `docs/verification/release_gates.md:167`
  - `docs/tool/check_docs.dart:29`
  - `docs/tool/check_docs.dart:255`
  - `docs/tool/sync_generated_docs.dart:351`
  - `docs/tool/generate_context_capsules.dart:123`
  - `AGENTS.md:48`
  - `AGENTS.md:51`
  - `AGENTS.md:52`
  - `AGENTS.md:53`
  - `AGENTS.md:61`
  - `AGENTS.md:85`
  - `.github/workflows/root_package.yml:55`
  - `.github/workflows/root_package.yml:67`
  - `.github/workflows/root_package.yml:71`
  - `.github/workflows/root_package.yml:75`
  - `test/guardrails/root_ci_target_test.dart:125`
  - `test/guardrails/root_ci_target_test.dart:133`
  - `docs/verification/tests.md:453`
  - `test/api_contract/example_public_boundary_test.dart:48`
  - `test/api_contract/example_public_boundary_test.dart:67`
  - `test/api_contract/example_public_boundary_test.dart:99`
  - `.design/2026-06-16-flutter-performance-verification-route.md` Required
    Flutter Scenario Catalog
  - `.design/2026-06-16-flutter-performance-verification-route.md` Selected
    Form
  - `.design/2026-06-16-flutter-performance-verification-route.md`
    Verification Impact
  - `docs/contracts/public_api_v1.md:125`
  - `docs/contracts/public_api_v1.md:362`
  - `docs/contracts/public_api_v1.md:505`
  - `docs/contracts/public_api_v1.md:563`
  - `docs/contracts/public_api_v1.md:1356`
  - `docs/contracts/public_api_v1.md:1496`
  - `docs/contracts/public_api_v1.md:1806`
  - `docs/contracts/public_api_v1.md:1973`
  - `docs/contracts/public_api_v1.md:2453`
  - `docs/contracts/public_api_v1.md:2478`
  - `docs/contracts/validation_limits.md:31`
  - `docs/contracts/validation_limits.md:102`
  - `docs/contracts/validation_limits.md:103`
- Contract constraints or sequencing facts:
  - Write the SSOT performance doc and registry row before adding cross-links
    that reference it.
  - Do not restore retired benchmark docs, registries, indexes, or tools.
  - Include every scenario id from the Required Flutter Scenario Catalog.
  - Do not use untracked `perf.md` as a future Change Contract source input
    while it remains untracked; use this reviewed design artifact's locked
    catalog and route decisions.
  - Treat startup rows as Android future pressure, not Flutter route omissions.
  - Include 100k rows, but require exact fixture-size proof before claiming
    `load_document.100k` release readiness under current validation limits.
  - Release gate is completion plus artifacts only; numeric thresholds are a
    later design/contract.
  - Any future Dart code under `example/lib/perf`, `example/integration_test`,
    `example/test_driver`, or related changed owners must carry analyzer, DCM,
    metrics, and focused-test proof from `AGENTS.md`.
  - Any future `example/**` code change must carry standalone example-package
    proof: `flutter pub get`, `flutter test`, and `flutter analyze` from the
    `example` directory.
  - Public-boundary proof must use the existing
    `test/api_contract/example_public_boundary_test.dart` owner test rather than
    relying only on an ad hoc import grep.
- Required proof surfaces:
  - docs generated sync/check;
  - docs structural check;
  - `dart analyze`;
  - `dcm analyze .`;
  - `dcm calculate-metrics` for changed example Dart owners;
  - focused tests for changed example behavior/tooling;
  - `cd example && flutter pub get`;
  - `cd example && flutter test`;
  - `cd example && flutter analyze`;
  - `flutter test test/api_contract/example_public_boundary_test.dart`;
  - `flutter test test/guardrails/root_ci_target_test.dart` when CI route
    expectations are changed or relied on by the contract;
  - catalog-to-reportKey coverage proof;
  - profile `flutter drive` run;
  - per-reportKey timeline artifact inventory.

## Open Decisions

None.
