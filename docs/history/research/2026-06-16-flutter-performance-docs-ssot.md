---
date: 2026-06-16
researcher: Codex
commit: c58d67c1
branch: new-architecture
research_question: "Which SSOT docs in docs need to be added or changed to introduce an official Flutter performance contour through integration_test + flutter drive --profile after deleting the old benchmark contour?"
---

# Research: Flutter Performance Docs SSOT

## Summary

The active documentation source-of-truth surface is rooted at `docs/README.md`.
It routes verification work to `docs/verification/`, structured relationships
to `docs/_registry/`, and generated navigation to `docs/indexes/` plus
`docs/diagrams/catalog.md` (`docs/README.md:21`, `docs/README.md:25`,
`docs/README.md:26`, `docs/README.md:27`). `AGENTS.md` also names
`docs/README.md` as the documentation entry point for architecture, contracts,
verification policy, release gates, generated indexes, and registries
(`AGENTS.md:3`, `AGENTS.md:4`, `AGENTS.md:5`, `AGENTS.md:6`).

The current verification source-of-truth docs are `docs/verification/tests.md`,
`docs/verification/guardrails.md`, and
`docs/verification/release_gates.md`. They are registered in
`docs/_registry/sections.yaml` as quality-gate sections with owners `test`,
`guardrail`, and `release` (`docs/_registry/sections.yaml:663`,
`docs/_registry/sections.yaml:668`, `docs/_registry/sections.yaml:764`,
`docs/_registry/sections.yaml:769`, `docs/_registry/sections.yaml:919`,
`docs/_registry/sections.yaml:924`). The only active docs statement found for
performance gate status says no repository-owned release performance gate is
currently claimed (`docs/verification/release_gates.md:167`).

No active `docs/verification/performance.md`,
`docs/verification/benchmarks.md`, `docs/_registry/benchmarks.yaml`,
`docs/indexes/by_benchmark.md`, `tool/bench/`, `test/benchmarks/`,
`example/integration_test/`, or `example/test_driver/` path was found by
filesystem probes. Exact `integration_test`, `flutter drive`,
`TimelineSummary`, and `flutter drive --profile` terms were not found in
tracked `docs/` content. A root working-tree draft `perf.md` exists outside
`docs/` and contains the proposed official contour and old removed paths, but
it is not part of the active docs source-of-truth tree.

## Detailed Findings

### 1. Documentation Entry Points And SSOT Areas

- **Location**: `docs/README.md:3`.
- **Description**: The root docs page describes itself as a portal that routes
  task work to current source-of-truth documentation while generated navigation
  handles reverse lookup and drift checks (`docs/README.md:3`,
  `docs/README.md:4`, `docs/README.md:5`).
- **Dependencies**: Its task routes include verification, generated lookup,
  release work, owner/subsystem/guardrail/test/diagram indexes, and the diagram
  catalog (`docs/README.md:7`, `docs/README.md:11`,
  `docs/README.md:18`, `docs/README.md:19`).
- **Data flow**: Task route -> source-of-truth document family -> generated
  lookup. The source-of-truth list maps architecture to
  `docs/architecture/`, contracts to `docs/contracts/`, verification policy to
  `docs/verification/`, structured relationships to `docs/_registry/`, and
  generated navigation to `docs/indexes/` plus `docs/diagrams/catalog.md`
  (`docs/README.md:21`, `docs/README.md:23`, `docs/README.md:27`).

- **Location**: `docs/architecture/README.md:29`.
- **Description**: The architecture entry point states the boundary split:
  `docs/architecture/` owns target-system shape, `docs/contracts/` owns
  subsystem behavior and invariants, `docs/verification/` owns proof plans,
  guardrails, tests, and release gates, and `docs/_registry/` owns relationship
  metadata for generated navigation (`docs/architecture/README.md:29`,
  `docs/architecture/README.md:31`, `docs/architecture/README.md:34`).
- **Dependencies**: It also routes verification work to `docs/verification/`
  from the architecture work routes (`docs/architecture/README.md:15`,
  `docs/architecture/README.md:24`).
- **Data flow**: Architecture entrypoint -> verification route ->
  verification-owned proof/release docs.

### 2. Current Verification Owners

- **Location**: `docs/verification/tests.md:2`.
- **Description**: `docs/verification/tests.md` owns registry section
  `section_23_tests`, has document path `docs/verification/tests.md`, and owns
  “23. Tests” (`docs/verification/tests.md:2`,
  `docs/verification/tests.md:4`, `docs/verification/tests.md:5`,
  `docs/verification/tests.md:6`). Its context capsule lists current owner
  `test` (`docs/verification/tests.md:10`, `docs/verification/tests.md:11`).
- **Dependencies**: It must read public API and guardrail sections before
  editing (`docs/verification/tests.md:7`, `docs/verification/tests.md:8`,
  `docs/verification/tests.md:9`).
- **Data flow**: Section registry -> generated context capsule -> required
  test inventory and test responsibilities. The required test inventory starts
  at `docs/verification/tests.md:160` and current test responsibilities include
  shape rules for in-package tests, external consumer tests, compile/static
  tests, and guardrail tests (`docs/verification/tests.md:399`,
  `docs/verification/tests.md:401`, `docs/verification/tests.md:405`,
  `docs/verification/tests.md:413`, `docs/verification/tests.md:420`).

- **Location**: `docs/verification/guardrails.md:2`.
- **Description**: `docs/verification/guardrails.md` owns
  `section_22_guardrails_machine_checks`, has owner `guardrail`, and defines
  guardrails as blocking architecture and release rules
  (`docs/verification/guardrails.md:2`, `docs/verification/guardrails.md:10`,
  `docs/verification/guardrails.md:108`).
- **Dependencies**: The full runner command is
  `dart run tool/guardrails/run.dart` (`docs/verification/guardrails.md:112`,
  `docs/verification/guardrails.md:115`). Runner metadata under
  `tool/guardrails/**` owns executable guardrail ids, suite membership, and
  dispatch routing for checks that run through the entrypoint
  (`docs/verification/guardrails.md:155`,
  `docs/verification/guardrails.md:156`).
- **Data flow**: Guardrail section -> mandatory guardrail ids -> runner
  metadata/executable proof. Future mandatory guardrails remain owned by
  `docs/_registry/sections.yaml` and this section until implementation
  contracts add executable proof (`docs/verification/guardrails.md:157`,
  `docs/verification/guardrails.md:158`,
  `docs/verification/guardrails.md:159`).

- **Location**: `docs/verification/release_gates.md:2`.
- **Description**: `docs/verification/release_gates.md` owns
  `section_27_final_release_gates`, has owner `release`, and states release is
  blocked unless all listed statements are true
  (`docs/verification/release_gates.md:2`,
  `docs/verification/release_gates.md:10`,
  `docs/verification/release_gates.md:102`).
- **Dependencies**: It must read guardrails and tests before editing
  (`docs/verification/release_gates.md:7`,
  `docs/verification/release_gates.md:8`,
  `docs/verification/release_gates.md:9`).
- **Data flow**: Release-gate section -> architecture graph checks, generated
  graph checks, required tests, guardrail runner, and release statements
  (`docs/verification/release_gates.md:104`,
  `docs/verification/release_gates.md:109`,
  `docs/verification/release_gates.md:161`,
  `docs/verification/release_gates.md:164`).

### 3. Performance Gate And Old Benchmark References

- **Location**: `docs/verification/release_gates.md:167`.
- **Description**: Current release gates state: no repository-owned release
  performance gate is currently claimed (`docs/verification/release_gates.md:167`).
- **Dependencies**: The statement is inside the final release gate list that is
  introduced by “Release is blocked unless all statements are true”
  (`docs/verification/release_gates.md:100`,
  `docs/verification/release_gates.md:102`).
- **Data flow**: Release gate list -> current release readiness status.

- **Location**: `docs/tool/check_docs.dart:255`.
- **Description**: The structural docs checker rejects retired section fields,
  including `benchmarks` (`docs/tool/check_docs.dart:255`,
  `docs/tool/check_docs.dart:256`, `docs/tool/check_docs.dart:257`,
  `docs/tool/check_docs.dart:258`).
- **Dependencies**: It loads `docs/_registry/sections.yaml` as the section
  registry (`docs/tool/check_docs.dart:13`,
  `docs/tool/check_docs.dart:215`,
  `docs/tool/check_docs.dart:219`).
- **Data flow**: Section registry row -> retired-field rejection -> docs check
  failure.

- **Location**: `test/docs/current_docs_navigation_test.dart:42`.
- **Description**: The docs navigation test checks that
  `docs/_registry/sections.yaml` does not contain retired metadata fields
  `phases`, `donors`, or `benchmarks`
  (`test/docs/current_docs_navigation_test.dart:42`,
  `test/docs/current_docs_navigation_test.dart:44`,
  `test/docs/current_docs_navigation_test.dart:48`,
  `test/docs/current_docs_navigation_test.dart:49`,
  `test/docs/current_docs_navigation_test.dart:79`).
- **Dependencies**: The same test also checks current generated index routes
  and retired phase/donor routes (`test/docs/current_docs_navigation_test.dart:17`,
  `test/docs/current_docs_navigation_test.dart:23`,
  `test/docs/current_docs_navigation_test.dart:24`,
  `test/docs/current_docs_navigation_test.dart:25`).
- **Data flow**: Test reads registry text -> rejects retired section fields.

- **Location**: `docs/verification/guardrail_design_patterns.md:26`.
- **Description**: Guardrail pattern guidance states that invariants about
  performance, allocation, budget, or cache capacity require an executable
  probe, counter, or budget assertion rather than prose
  (`docs/verification/guardrail_design_patterns.md:21`,
  `docs/verification/guardrail_design_patterns.md:26`,
  `docs/verification/guardrail_design_patterns.md:27`).
- **Dependencies**: The same file states mandatory guardrail ids are owned by
  `docs/verification/guardrails.md` and `docs/_registry/sections.yaml`
  (`docs/verification/guardrail_design_patterns.md:3`,
  `docs/verification/guardrail_design_patterns.md:6`,
  `docs/verification/guardrail_design_patterns.md:7`).
- **Data flow**: Mandatory guardrail invariant -> pattern selection -> proof
  implementation shape.

- **Location**: command-surface not-found evidence.
- **Description**: Filesystem probes found no active paths named
  `docs/verification/benchmarks.md`, `docs/_registry/benchmarks.yaml`,
  `docs/indexes/by_benchmark.md`, `tool/bench/`, or `test/benchmarks/`.
- **Dependencies**: `docs/tool/check_docs.dart` also locks generated indexes to
  six paths and rejects unlocked `docs/indexes/*.md` files
  (`docs/tool/check_docs.dart:29`, `docs/tool/check_docs.dart:35`,
  `docs/tool/check_docs.dart:306`, `docs/tool/check_docs.dart:315`).
- **Data flow**: Active docs tree/filesystem -> absence of old benchmark route
  paths -> generated-index lock remains six current paths.

- **Location**: `docs/README.md:31`.
- **Description**: `.design/` and `.research/` are described as evidence and
  source-input layers only, and do not own active package behavior, release
  policy, guardrails, roadmaps, external routes, removed planning routes, or
  runtime contracts (`docs/README.md:31`, `docs/README.md:32`,
  `docs/README.md:33`).
- **Dependencies**: Searches found historical benchmark references in
  `docs/history/designs/2026-06-05-p14-release-readiness-benchmarks.md`,
  `docs/history/designs/2026-06-06-p14-benchmark-measurement-boundary.md`, and
  `docs/history/research/2026-06-06-pixel6-release-benchmark-hotspots.md`; those files are
  not active docs owners under the root docs policy (`docs/README.md:28`,
  `docs/README.md:31`, `docs/README.md:32`).
- **Data flow**: Historical evidence notes -> source inputs only -> not active
  ownership of release/performance routes.

### 4. Existing Evidence For A Flutter Performance Route Owner

- **Location**: `docs/verification/tests.md:399`.
- **Description**: Current test policy documents in-package unit/behavior
  tests, external consumer behavior tests, compile/static/analyzer tests, and
  guardrail tests (`docs/verification/tests.md:399`,
  `docs/verification/tests.md:401`, `docs/verification/tests.md:405`,
  `docs/verification/tests.md:413`, `docs/verification/tests.md:420`).
- **Dependencies**: External consumer behavior tests use
  `test/support/flutter_consumer_test_harness.dart` and compile/static tests may
  keep local runners for compile-only fixtures, analyzer checks, AST/import
  scans, or multi-file generated commands (`docs/verification/tests.md:405`,
  `docs/verification/tests.md:407`, `docs/verification/tests.md:408`,
  `docs/verification/tests.md:413`, `docs/verification/tests.md:416`).
- **Data flow**: Test shape category -> required proof command or harness.
  Current docs do not mention `integration_test`, `flutter drive`, or
  `TimelineSummary` in this policy; that absence is recorded in Search Coverage.

- **Location**: `docs/verification/release_gates.md:164`.
- **Description**: Current final release gates include a full guardrail runner
  gate and an executable proof gate for every mandatory guardrail
  (`docs/verification/release_gates.md:164`,
  `docs/verification/release_gates.md:165`,
  `docs/verification/release_gates.md:166`).
- **Dependencies**: The same list currently contains the negative performance
  gate claim (`docs/verification/release_gates.md:167`).
- **Data flow**: Release proof status -> required release gate list.

- **Location**: command-surface not-found evidence.
- **Description**: No `docs/verification/performance.md` file exists, no
  `section_*performance*` row was found in `docs/_registry/sections.yaml`, and
  no active docs content was found for `integration_test`, `flutter drive`, or
  `TimelineSummary`.
- **Dependencies**: `docs/tool/generate_context_capsules.dart` renders context
  capsules from section registry fields into section files
  (`docs/tool/generate_context_capsules.dart:123`,
  `docs/tool/generate_context_capsules.dart:130`,
  `docs/tool/generate_context_capsules.dart:146`,
  `docs/tool/generate_context_capsules.dart:157`).
- **Data flow**: Registered section row -> generated context capsule -> section
  file metadata. No registered performance section row was found.

### 5. Generated Docs, Indexes, Registries, And Checks Affected By A Registered Verification Section

- **Location**: `docs/tool/sync_generated_docs.dart:117`.
- **Description**: Generated docs sync delegates generators, loads diagrams and
  sections, then syncs the diagram catalog and generated indexes
  (`docs/tool/sync_generated_docs.dart:117`,
  `docs/tool/sync_generated_docs.dart:121`,
  `docs/tool/sync_generated_docs.dart:127`,
  `docs/tool/sync_generated_docs.dart:136`).
- **Dependencies**: Delegated generators are
  `docs/tool/generate_context_capsules.dart` and
  `tool/architecture_graph/generate_views.dart`
  (`docs/tool/sync_generated_docs.dart:147`,
  `docs/tool/sync_generated_docs.dart:150`,
  `docs/tool/sync_generated_docs.dart:153`,
  `docs/tool/sync_generated_docs.dart:155`).
- **Data flow**: Section registry / diagram registry -> delegated generators ->
  diagram catalog -> generated indexes.

- **Location**: `docs/tool/sync_generated_docs.dart:351`.
- **Description**: Generated indexes are rendered from section rows into
  `docs/indexes/by_owner.md`, `docs/indexes/by_subsystem.md`,
  `docs/indexes/by_guardrail.md`, `docs/indexes/by_test_area.md`,
  `docs/indexes/by_diagram.md`, and `docs/indexes/by_release.md`
  (`docs/tool/sync_generated_docs.dart:351`,
  `docs/tool/sync_generated_docs.dart:352`,
  `docs/tool/sync_generated_docs.dart:357`).
- **Dependencies**: The release index includes sections whose owners contain
  `release` (`docs/tool/sync_generated_docs.dart:601`,
  `docs/tool/sync_generated_docs.dart:603`,
  `docs/tool/sync_generated_docs.dart:606`,
  `docs/tool/sync_generated_docs.dart:611`).
- **Data flow**: Section owners/subsystems/guardrails/tests/diagrams ->
  generated lookup pages. A registered verification section with owner,
  subsystem, guardrail, test, diagram, or release metadata flows into the
  corresponding generated index renderers.

- **Location**: `docs/tool/check_docs.dart:94`.
- **Description**: The docs checker runs required entrypoint checks, active route
  policy checks, portal README checks, README inventory checks, generated docs
  parity, generated index checks, section reference checks, diagram
  catalog/registry symmetry checks, markdown path checks, and must-read graph
  checks (`docs/tool/check_docs.dart:94`, `docs/tool/check_docs.dart:99`,
  `docs/tool/check_docs.dart:106`, `docs/tool/check_docs.dart:109`).
- **Dependencies**: It requires `docs/verification/`, `docs/indexes/`, and
  `docs/_registry/` directories (`docs/tool/check_docs.dart:179`,
  `docs/tool/check_docs.dart:182`, `docs/tool/check_docs.dart:184`,
  `docs/tool/check_docs.dart:185`).
- **Data flow**: Docs tree -> structural checker -> missing paths, retired
  routes, stale generated docs, unknown section ids, broken document paths, and
  must-read cycles.

- **Location**: `docs/tool/check_docs.dart:685`.
- **Description**: Markdown path checks scan `docs/architecture`,
  `docs/contracts`, `docs/verification`, `docs/diagrams`, and `docs/indexes`
  for section ids, document path references, and retired source claims
  (`docs/tool/check_docs.dart:21`, `docs/tool/check_docs.dart:24`,
  `docs/tool/check_docs.dart:685`, `docs/tool/check_docs.dart:698`).
- **Dependencies**: Document path references in code spans and markdown links are
  required to exist (`docs/tool/check_docs.dart:803`,
  `docs/tool/check_docs.dart:804`, `docs/tool/check_docs.dart:815`).
- **Data flow**: New markdown under `docs/verification` -> scanned markdown
  roots -> section-id and document-path validation.

- **Location**: `docs/tool/generate_context_capsules.dart:157`.
- **Description**: For each registered section file, the context capsule sync
  requires exactly one context capsule at file start and checks/replaces it
  against registry-rendered content (`docs/tool/generate_context_capsules.dart:157`,
  `docs/tool/generate_context_capsules.dart:164`,
  `docs/tool/generate_context_capsules.dart:171`,
  `docs/tool/generate_context_capsules.dart:181`,
  `docs/tool/generate_context_capsules.dart:192`).
- **Dependencies**: The rendered capsule includes registry id/source, document
  path, owns, must-read links, owners, diagrams, tests, guardrails, and
  do-not-assume (`docs/tool/generate_context_capsules.dart:123`,
  `docs/tool/generate_context_capsules.dart:130`,
  `docs/tool/generate_context_capsules.dart:146`).
- **Data flow**: `docs/_registry/sections.yaml` row -> generated context block
  at the top of the section file.

### 6. Current Test And CI Surfaces For Docs And Verification Routes

- **Location**: `.github/workflows/root_package.yml:31`.
- **Description**: Root CI runs generated docs check and docs check
  (`.github/workflows/root_package.yml:31`,
  `.github/workflows/root_package.yml:32`,
  `.github/workflows/root_package.yml:34`,
  `.github/workflows/root_package.yml:35`).
- **Dependencies**: The same workflow runs all Flutter tests, Dart analyze, and
  the guardrail runner (`.github/workflows/root_package.yml:43`,
  `.github/workflows/root_package.yml:47`,
  `.github/workflows/root_package.yml:49`,
  `.github/workflows/root_package.yml:52`).
- **Data flow**: PR/push workflow -> docs checks -> Flutter tests -> analyze ->
  guardrails.

- **Location**: `test/guardrails/root_ci_target_test.dart:113`.
- **Description**: The root CI structural test requires workflow commands
  `dart run docs/tool/sync_generated_docs.dart --check` and
  `dart run docs/tool/check_docs.dart`, and rejects workflow path filters
  (`test/guardrails/root_ci_target_test.dart:113`,
  `test/guardrails/root_ci_target_test.dart:116`,
  `test/guardrails/root_ci_target_test.dart:120`,
  `test/guardrails/root_ci_target_test.dart:121`,
  `test/guardrails/root_ci_target_test.dart:122`).
- **Dependencies**: The same test checks the root workflow runs
  `flutter test`, `dart analyze`, and `dart run tool/guardrails/run.dart`
  (`test/guardrails/root_ci_target_test.dart:54`,
  `test/guardrails/root_ci_target_test.dart:58`,
  `test/guardrails/root_ci_target_test.dart:62`,
  `test/guardrails/root_ci_target_test.dart:63`).
- **Data flow**: Workflow YAML -> structural test -> required command set.

- **Location**: `test/docs/current_docs_navigation_test.dart:17`.
- **Description**: Docs navigation tests require current generated index routes
  and reject retired `by_phase` / `donor_to_phase` indexes
  (`test/docs/current_docs_navigation_test.dart:17`,
  `test/docs/current_docs_navigation_test.dart:23`,
  `test/docs/current_docs_navigation_test.dart:24`,
  `test/docs/current_docs_navigation_test.dart:25`).
- **Dependencies**: The current index set is six generated indexes
  (`test/docs/current_docs_navigation_test.dart:63`,
  `test/docs/current_docs_navigation_test.dart:69`).
- **Data flow**: `docs/indexes` directory -> current-route test.

- **Location**: `AGENTS.md:74`.
- **Description**: Documentation-only changes use
  `dart run docs/tool/sync_generated_docs.dart --check` and
  `dart run docs/tool/check_docs.dart`; stale generated docs require running
  `dart run docs/tool/sync_generated_docs.dart`, reviewing generated diff, and
  rerunning docs checks (`AGENTS.md:74`, `AGENTS.md:77`, `AGENTS.md:78`,
  `AGENTS.md:80`, `AGENTS.md:82`, `AGENTS.md:83`).
- **Dependencies**: Mixed code and documentation changes require relevant code
  checks, focused tests, architecture checks when triggered, and documentation
  checks (`AGENTS.md:85`, `AGENTS.md:86`).
- **Data flow**: Change type -> repository-local verification command set.

- **Location**: `AGENTS.md:63`.
- **Description**: Architecture checks are required when changing
  architecture-owned production seams, `docs/architecture/architecture_graph.yaml`,
  generated architecture diagrams, architecture documentation, or release gates
  that depend on current graph closure (`AGENTS.md:63`, `AGENTS.md:66`,
  `AGENTS.md:67`, `AGENTS.md:69`, `AGENTS.md:70`, `AGENTS.md:71`).
- **Dependencies**: Architecture graph commands are
  `dart run tool/architecture_graph/check.dart` and
  `dart run tool/architecture_graph/generate_views.dart --check`
  (`AGENTS.md:66`, `AGENTS.md:67`).
- **Data flow**: Release gate / architecture graph closure change ->
  architecture graph verification.

### 7. Current Flutter Integration-Test Catalog Evidence

- **Location**: command-surface not-found evidence.
- **Description**: Exact searches found no active tracked docs entries for
  `integration_test`, `package:integration_test`, `IntegrationTestWidgetsFlutterBinding`,
  `flutter drive`, `flutter drive --profile`, `TimelineSummary`, or timeline
  JSON artifacts. The only `integration_test` string found in tracked docs/test
  search output was the substring in
  `test/runtime/draw_cleanup_integration_test.dart` referenced by
  `docs/verification/tests.md:673`, not Flutter's `integration_test` package.
- **Dependencies**: Current test catalog is the required test inventory in
  `docs/verification/tests.md` (`docs/verification/tests.md:160`,
  `docs/verification/tests.md:164`, `docs/verification/tests.md:330`).
- **Data flow**: Current required test inventory -> no Flutter
  `integration_test` route or `flutter drive --profile` artifact catalog found.

- **Location**: `docs/verification/tests.md:732`.
- **Description**: Current surface Flutter tests are documented under the
  “surface Flutter surface tests” section and cover `CanvasSurface` behavior via
  normal test files such as `test/surface/single_active_surface_test.dart`,
  `test/surface/widget_paint_test.dart`, and
  `test/smoke/public_incremental_smoke_test.dart`
  (`docs/verification/tests.md:732`, `docs/verification/tests.md:733`,
  `docs/verification/tests.md:760`, `docs/verification/tests.md:780`).
- **Dependencies**: Guardrail test ownership says Flutter-dependent package
  tests run through `flutter test` (`docs/verification/tests.md:425`,
  `docs/verification/tests.md:427`, `docs/verification/tests.md:429`).
- **Data flow**: Surface behavior proof -> `flutter test` package tests, not
  a documented profile-mode drive route.

## Code References

- `AGENTS.md:3` - Repository root is the canonical maintained package and
  `docs/README.md` is the documentation entry point.
- `AGENTS.md:74` - Documentation-only changes use docs checks instead of
  Dart/DCM code checks.
- `AGENTS.md:80` - Docs checks run when changing anything under `docs/` or
  documentation generation/checking tools.
- `docs/README.md:21` - Root docs source-of-truth list.
- `docs/README.md:31` - `.design/` and `.research/` are evidence/source-input
  layers only.
- `docs/architecture/README.md:29` - Documentation family ownership boundary.
- `docs/_registry/sections.yaml:663` - Guardrails section registry row.
- `docs/_registry/sections.yaml:764` - Tests section registry row.
- `docs/_registry/sections.yaml:919` - Final release gates section registry row.
- `docs/verification/tests.md:160` - Required test inventory starts.
- `docs/verification/tests.md:399` - Test shape rules start.
- `docs/verification/guardrails.md:108` - Guardrails are blocking architecture
  and release rules.
- `docs/verification/guardrails.md:155` - Runner metadata owns executable
  guardrail ids, suite membership, and dispatch routing.
- `docs/verification/guardrail_design_patterns.md:26` - Performance/allocation/
  budget/cache-capacity invariants require executable probes/counters/budget
  assertions.
- `docs/verification/release_gates.md:102` - Release is blocked unless listed
  statements are true.
- `docs/verification/release_gates.md:167` - No current repository-owned release
  performance gate is claimed.
- `docs/tool/check_docs.dart:1` - Structural documentation checker scope.
- `docs/tool/check_docs.dart:29` - Locked generated index paths.
- `docs/tool/check_docs.dart:255` - Retired section field rejection.
- `docs/tool/check_docs.dart:685` - Markdown path checks scan docs roots.
- `docs/tool/sync_generated_docs.dart:117` - Generated docs sync flow.
- `docs/tool/sync_generated_docs.dart:351` - Generated index outputs.
- `docs/tool/generate_context_capsules.dart:123` - Context capsule rendering
  from section registry.
- `test/docs/current_docs_navigation_test.dart:17` - Generated index route test.
- `test/docs/current_docs_navigation_test.dart:42` - Retired section metadata
  field test.
- `test/guardrails/root_ci_target_test.dart:113` - Root CI docs-check command
  test.
- `.github/workflows/root_package.yml:31` - CI generated-docs check.

## Search Coverage

- **Inspected**: `AGENTS.md`, `PLAN.md`, `docs/README.md`,
  `docs/architecture/README.md`, `docs/verification/tests.md`,
  `docs/verification/guardrails.md`,
  `docs/verification/guardrail_design_patterns.md`,
  `docs/verification/release_gates.md`, `docs/_registry/sections.yaml`,
  `docs/_registry/diagrams.yaml`, `docs/_registry/public_api_v1.yaml`,
  `docs/indexes/by_owner.md`, `docs/indexes/by_subsystem.md`,
  `docs/indexes/by_guardrail.md`, `docs/indexes/by_test_area.md`,
  `docs/indexes/by_diagram.md`, `docs/indexes/by_release.md`,
  `docs/tool/check_docs.dart`, `docs/tool/sync_generated_docs.dart`,
  `docs/tool/generate_context_capsules.dart`,
  `test/docs/current_docs_navigation_test.dart`,
  `test/guardrails/root_ci_target_test.dart`,
  `.github/workflows/root_package.yml`.
- **Searched**:
  - `rg -n "performance|benchmark|bench|flutter drive|integration_test|TimelineSummary|timeline|profile|release gate|release_gates|verification|generated|registry|navigation|docs/README|guardrail|route" docs AGENTS.md PLAN.md plan test tool lib pubspec.yaml .github`
  - `rg -n "integration_test|IntegrationTestWidgetsFlutterBinding|flutter drive|flutter_driver|TimelineSummary|timeline_summary|traceTimeline|profile mode|--profile|profile" . -g '!build/**' -g '!.dart_tool/**' -g '!perf.md'`
  - `rg -n "benchmark|benchmarks|bench|performance gate|performance|perf" . -g '!build/**' -g '!.dart_tool/**' -g '!perf.md'`
  - `rg --files -g 'integration_test/**' -g 'test_driver/**' -g '*benchmark*' -g '*perf*' -g '*performance*'`
  - `find . -maxdepth 3 (...) -type d -name integration_test -o -type d -name test_driver -o -type f -iname '*benchmark*' -o -type f -iname '*perf*' -o -type f -iname '*performance*'`
  - `find docs -path 'docs/verification/benchmarks.md' -o -path 'docs/_registry/benchmarks.yaml' -o -path 'docs/indexes/by_benchmark.md' -o -path 'docs/implementation' -o -path 'docs/donors' -print`
  - `find test tool docs -path '*/benchmarks/*' -o -path '*/bench/*' -o -name '*benchmark*' -o -name '*bench*' -print`
  - `git ls-files | rg '(^docs/verification/benchmarks\\.md$|^docs/_registry/benchmarks\\.yaml$|^docs/indexes/by_benchmark\\.md$|^test/benchmarks/|^tool/bench/|benchmark|bench)'`
- **Not found**:
  - Active tracked docs for Flutter `integration_test`, `flutter drive`,
    `flutter drive --profile`, `TimelineSummary`, or timeline JSON artifacts.
  - Active paths `docs/verification/performance.md`,
    `docs/verification/benchmarks.md`, `docs/_registry/benchmarks.yaml`,
    `docs/indexes/by_benchmark.md`, `tool/bench/`, `test/benchmarks/`,
    `example/integration_test/`, `example/test_driver/`, or
    `example/android/macrobenchmark/`.
  - Exact repository terms `verification route`, `verification_route`,
    `route catalog`, and `route_catalog`; route behavior appears through docs
    navigation and guardrail runner selection.
- **Not inspected**:
  - Full contents of every historical `.design/` and `.research/` benchmark
    note. Searches identified benchmark remnants there, but `docs/README.md`
    states those directories are evidence/source-input layers only and do not
    own active release policy or removed planning routes (`docs/README.md:31`,
    `docs/README.md:32`, `docs/README.md:33`).
  - Untracked root `perf.md` was searched and identified as a working-tree draft
    outside `docs/`; it is not part of the active docs tree or generated docs
    registries.

## Observed Architecture Facts

- Pattern observed: root docs routing is explicit and generated navigation is
  registry-derived (`docs/README.md:3`, `docs/README.md:21`,
  `docs/tool/sync_generated_docs.dart:351`).
- Pattern observed: verification ownership is split across tests, guardrails,
  and release gates, all registered under `quality_gates`
  (`docs/_registry/sections.yaml:663`, `docs/_registry/sections.yaml:764`,
  `docs/_registry/sections.yaml:919`, `docs/indexes/by_subsystem.md:22`).
- Pattern observed: context capsules in registered section files are generated
  from `docs/_registry/sections.yaml`
  (`docs/tool/generate_context_capsules.dart:123`,
  `docs/tool/generate_context_capsules.dart:157`).
- Pattern observed: generated indexes are locked to six files; `benchmarks` is a
  retired section field, and old benchmark index/registry paths were not found
  (`docs/tool/check_docs.dart:29`, `docs/tool/check_docs.dart:255`,
  `test/docs/current_docs_navigation_test.dart:79`).
- Data flow: `docs/_registry/sections.yaml` -> context capsules -> generated
  indexes -> docs checks -> CI docs-check commands
  (`docs/tool/generate_context_capsules.dart:123`,
  `docs/tool/sync_generated_docs.dart:351`,
  `docs/tool/check_docs.dart:353`,
  `.github/workflows/root_package.yml:31`).
- Key dependencies: release gates depend on guardrails and tests
  (`docs/verification/release_gates.md:7`,
  `docs/verification/release_gates.md:9`); guardrails depend on runner metadata
  and executable proof (`docs/verification/guardrails.md:155`,
  `docs/verification/guardrails.md:159`).

## Open Questions

- None from repository evidence. No active docs owner for a Flutter
  `integration_test` + `flutter drive --profile` performance route was found.
