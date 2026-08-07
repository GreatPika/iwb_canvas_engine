---
date: 2026-06-08
researcher: Codex
commit: 19337513
branch: new-architecture
research_question: "Inventory the remaining legacy, legacy-parity, guardrail, phase-document, and related migration footprints after the legacy-to-new-architecture port."
---

# Research: Legacy And Phase Footprint

## Summary

The repository still contains a full nested legacy package under `legacy/iwb_canvas_engine`, but current root package configuration only references that path through the analyzer exclusion and through guardrail/test/documentation inputs. The inspected executable checks do not run legacy runtime code; the direct executable dependency on a legacy file is the public API guardrail reading `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt` as the retired-symbol set.

The current package also retains a phase and donor documentation system. `PLAN.md` indexes 58 checked step contracts, and `plan/step_52_legacy_example_full_parity_port.md` records completed example-port proof with all seven execution units checked. The documentation registry, generated indexes, architecture graph, generated Mermaid views, and documentation tools still encode phases P0-P14 and donor decisions as structured data.

Executable legacy-related enforcement exists in several forms: bans on legacy imports and retired shapes, example public-boundary checks, public API retired-symbol checks, geometry/frame guardrails that reject legacy scene-order patterns, benchmark metadata for legacy-equivalent baselines, release workflow legacy-path rejection, and selected-phase architecture closure checks.

## Detailed Findings

### 1. Legacy Package Directory
- **Location**: primary `legacy/iwb_canvas_engine/pubspec.yaml:1`; additional `legacy/iwb_canvas_engine/.metadata:10`, `legacy/iwb_canvas_engine/example/pubspec.yaml:1`
- **Description**: `legacy/` contains a nested Flutter/Dart package at `legacy/iwb_canvas_engine`. Its package metadata declares `name: iwb_canvas_engine`, `version: 5.1.0`, Flutter platform support, SDK constraints, package dependencies, dev dependencies, and asset `image/cat.png` (`legacy/iwb_canvas_engine/pubspec.yaml:1`, `legacy/iwb_canvas_engine/pubspec.yaml:3`, `legacy/iwb_canvas_engine/pubspec.yaml:23`, `legacy/iwb_canvas_engine/pubspec.yaml:27`, `legacy/iwb_canvas_engine/pubspec.yaml:32`, `legacy/iwb_canvas_engine/pubspec.yaml:40`). Flutter metadata marks it as a package (`legacy/iwb_canvas_engine/.metadata:10`). The nested legacy example depends on the parent package by `path: ../` (`legacy/iwb_canvas_engine/example/pubspec.yaml:12`) and uses `vector_math` (`legacy/iwb_canvas_engine/example/pubspec.yaml:14`).
- **Dependencies**: Flutter SDK, `path_drawing`, `flutter_test`, `flutter_lints`, `analyzer`, `test`, and `yaml` are declared in legacy package metadata (`legacy/iwb_canvas_engine/pubspec.yaml:27`, `legacy/iwb_canvas_engine/pubspec.yaml:32`).
- **Data flow**: Legacy package files are standalone package inputs. The root package does not reference them through root `pubspec.yaml`, root `pubspec.lock`, root `dart_test.yaml`, root `.dart_tool`, or root `.github` in the scoped searches.

### 2. Root Configuration And Direct Legacy Path References
- **Location**: primary `analysis_options.yaml:3`; additional `tool/guardrails/src/public_api_checks.dart:472`, `tool/guardrails/src/core_boundary_checks.dart:385`, `tool/guardrails/src/release_readiness_checks.dart:130`
- **Description**: Root analyzer configuration excludes `legacy/**` (`analysis_options.yaml:1`, `analysis_options.yaml:3`). Core boundary checks classify legacy import URIs and report `core.no_legacy_imports` (`tool/guardrails/src/core_boundary_checks.dart:385`, `tool/guardrails/src/core_boundary_checks.dart:391`). The public API check reads legacy public symbols from `$repositoryRoot/legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt` (`tool/guardrails/src/public_api_checks.dart:472`, `tool/guardrails/src/public_api_checks.dart:474`). Release readiness checks reject benchmark sources or workflow commands that mention legacy paths (`tool/guardrails/src/release_readiness_checks.dart:130`, `tool/guardrails/src/release_readiness_checks.dart:136`, `tool/guardrails/src/release_readiness_checks.dart:266`, `tool/guardrails/src/release_readiness_checks.dart:272`).
- **Dependencies**: Analyzer AST/resolution APIs are used by core boundary checks (`tool/guardrails/src/core_boundary_checks.dart:8`, `tool/guardrails/src/core_boundary_checks.dart:12`); public API checks use the public surface resolver and registry (`tool/guardrails/src/public_api_checks.dart:10`, `tool/guardrails/src/public_api_checks.dart:11`); release readiness uses YAML parsing and repository path helpers (`tool/guardrails/src/release_readiness_checks.dart:1`, `tool/guardrails/src/release_readiness_checks.dart:3`, `tool/guardrails/src/release_readiness_checks.dart:6`).
- **Data flow**: Root source or workflow text -> guardrail scanners -> `GuardrailViolation` lists. For public API retired-symbol checks, resolved public exports -> legacy golden symbol file -> exported-name intersection -> violations (`tool/guardrails/src/public_api_checks.dart:434`, `tool/guardrails/src/public_api_checks.dart:437`, `tool/guardrails/src/public_api_checks.dart:472`).

### 3. Executable Legacy-Related Tests And Guardrails
- **Location**: primary `test/api_contract/no_legacy_public_symbols_test.dart:7`; additional `test/guardrails/core_boundary_negative_fixtures_test.dart:50`, `test/api_contract/example_public_boundary_test.dart:66`, `test/geometry/no_legacy_scene_order_test.dart:13`
- **Description**: Executable tests cover retired public symbols, legacy import fixtures, example boundary scans, geometry scene-order bans, frame cache key shape, donor mapping, benchmark legacy-equivalence metadata, release readiness, and phase closure. `no_legacy_public_symbols_test` asserts that the current root public surface does not export retired legacy symbols (`test/api_contract/no_legacy_public_symbols_test.dart:7`). Core negative fixtures feed synthetic `../../legacy/iwb_canvas_engine.dart` imports into `checkCoreBoundaryFile` (`test/guardrails/core_boundary_negative_fixtures_test.dart:50`, `test/guardrails/core_boundary_negative_fixtures_test.dart:51`). The example boundary test scans `example/**` imports and retired symbols including `SceneController`, `SceneView`, `NodeSpec`, `NodePatch`, `Transform2D`, `encodeSceneToJson`, and `decodeSceneFromJson` (`test/api_contract/example_public_boundary_test.dart:10`, `test/api_contract/example_public_boundary_test.dart:66`, `test/api_contract/example_public_boundary_test.dart:185`).
- **Dependencies**: Tests use `package:test/test.dart`, analyzer parser APIs, repository path helpers, guardrail executors, and benchmark manifest/diff parsers (`test/geometry/no_legacy_scene_order_test.dart:1`, `test/geometry/no_legacy_scene_order_test.dart:3`, `test/guardrails/geometry_no_legacy_scene_order_guardrail_test.dart:3`, `test/benchmarks/benchmark_manifest_test.dart:5`, `test/benchmarks/benchmark_diff_test.dart:6`).
- **Data flow**: Production source, example source, synthetic source, or benchmark JSON -> parser/scanner/manifest loader -> assertions or `GuardrailViolation` output. Donor mapping tests are constant inventory assertions, not legacy runtime execution (`test/geometry/geometry_spatial_donor_mapping_test.dart:64`, `test/frame/frame_donor_mapping_test.dart:171`). Benchmark legacy-equivalence checks use manifest/report metadata, including `equivalent_legacy` and `legacy_avg_us`, not direct calls into `legacy/` code (`tool/bench/src/benchmark_manifest.dart:226`, `test/benchmarks/benchmark_diff_test.dart:1185`).

### 4. Plan And Step Contracts
- **Location**: primary `PLAN.md:5`; additional `PLAN.md:74`, `plan/step_52_legacy_example_full_parity_port.md:169`, `plan/step_52_legacy_example_full_parity_port.md:313`
- **Description**: `PLAN.md` states that it is the active plan index (`PLAN.md:5`) and that detailed scope, closure rules, and verification live in linked step documents (`PLAN.md:12`, `PLAN.md:13`). It states that completed step contracts are historical records and may reference retired paths, APIs, or checks (`PLAN.md:15`, `PLAN.md:16`). Current command output counted 58 plan step entries, 58 checked entries, and 0 unchecked entries. Step 52 is checked in `PLAN.md` (`PLAN.md:74`), and its step document has checked Units 1 through 7, including Unit 1 at `plan/step_52_legacy_example_full_parity_port.md:169` and Unit 7 at `plan/step_52_legacy_example_full_parity_port.md:313`.
- **Dependencies**: `docs/README.md` exposes Change Contracts through `PLAN.md` and `plan/` (`docs/README.md:19`). Root repository instructions state that `PLAN.md` is the active roadmap and source of truth for planned work (`AGENTS.md:9`) and that completed plan steps update both `PLAN.md` and the linked step document (`AGENTS.md:18`, `AGENTS.md:19`).
- **Data flow**: `PLAN.md` -> linked `plan/step_*` contracts -> implementation and verification instructions recorded as historical step artifacts.

### 5. Documentation Registries, Donors, And Generated Indexes
- **Location**: primary `docs/README.md:3`; additional `docs/_registry/sections.yaml:299`, `docs/_registry/donors.yaml:1`, `docs/indexes/by_phase.md:1`, `docs/indexes/donor_to_phase.md:1`
- **Description**: `docs/README.md` describes a documentation portal for the new engine rebuild and routes users to phase implementation, donor decisions, generated lookup, and Change Contracts (`docs/README.md:3`, `docs/README.md:10`, `docs/README.md:15`, `docs/README.md:18`, `docs/README.md:19`). `docs/_registry/sections.yaml` maps `section_08_legacy_capability_inventory` to `docs/verification/legacy_capability_inventory.md`, P1, and subsystem `legacy_evidence` (`docs/_registry/sections.yaml:299`, `docs/_registry/sections.yaml:301`, `docs/_registry/sections.yaml:303`, `docs/_registry/sections.yaml:306`). `docs/_registry/donors.yaml` is a donor inventory with source paths, decisions, target phases, target owners, required tests, blocks, and related sections (`docs/_registry/donors.yaml:1`, `docs/_registry/donors.yaml:2`, `docs/_registry/donors.yaml:7`, `docs/_registry/donors.yaml:8`).
- **Dependencies**: Generated indexes name `docs/tool/sync_generated_docs.dart`, `docs/_registry/sections.yaml`, and `docs/_registry/donors.yaml` as their source (`docs/indexes/by_phase.md:1`, `docs/indexes/donor_to_phase.md:1`). `docs/verification/legacy_capability_inventory.md` names its registry source and must-read donor rules (`docs/verification/legacy_capability_inventory.md:2`, `docs/verification/legacy_capability_inventory.md:3`, `docs/verification/legacy_capability_inventory.md:8`).
- **Data flow**: `docs/_registry/sections.yaml` and `docs/_registry/donors.yaml` -> `docs/tool/sync_generated_docs.dart` -> generated indexes such as `docs/indexes/by_phase.md` and `docs/indexes/donor_to_phase.md`.

### 6. Architecture Graph And Phase Closure
- **Location**: primary `docs/architecture/architecture_graph.yaml:2`; additional `tool/architecture_graph/check.dart:7`, `tool/architecture_graph/generate_views.dart:7`, `docs/diagrams/generated/current_phase.mmd:2`
- **Description**: The architecture graph encodes phases P0-P14 with statuses and source documents (`docs/architecture/architecture_graph.yaml:2`, `docs/architecture/architecture_graph.yaml:3`, `docs/architecture/architecture_graph.yaml:85`, `docs/architecture/architecture_graph.yaml:87`). In the inspected graph, P10 and P13 have status `future`, while P14 has status `measurement` (`docs/architecture/architecture_graph.yaml:61`, `docs/architecture/architecture_graph.yaml:63`, `docs/architecture/architecture_graph.yaml:79`, `docs/architecture/architecture_graph.yaml:81`, `docs/architecture/architecture_graph.yaml:85`, `docs/architecture/architecture_graph.yaml:87`). The CLI tools require `--phase` (`tool/architecture_graph/check.dart:7`, `tool/architecture_graph/generate_views.dart:7`).
- **Dependencies**: `check.dart` loads the expected graph, extracts the actual graph, and runs phase closure (`tool/architecture_graph/check.dart:17`, `tool/architecture_graph/check.dart:28`, `tool/architecture_graph/check.dart:29`). Generated graph views include selected phase metadata (`tool/architecture_graph/src/graph_views.dart:485`, `tool/architecture_graph/src/graph_views.dart:490`), and `docs/diagrams/generated/current_phase.mmd` records source `docs/architecture/architecture_graph.yaml` and selected phase P14 (`docs/diagrams/generated/current_phase.mmd:2`, `docs/diagrams/generated/current_phase.mmd:4`).
- **Data flow**: `docs/architecture/architecture_graph.yaml` + actual source extraction + selected phase -> phase closure report -> generated Mermaid views or nonzero check result.

### 7. Documentation Tooling And CI-Style Release Checks
- **Location**: primary `docs/tool/sync_generated_docs.dart:153`; additional `docs/tool/check_docs.dart:130`, `.github/workflows/release_benchmarks.yml:24`, `tool/guardrails/src/release_readiness_checks.dart:247`
- **Description**: `sync_generated_docs.dart` runs delegated generators, loads diagrams/sections/donors registries, and syncs diagram catalog plus generated indexes (`docs/tool/sync_generated_docs.dart:153`, `docs/tool/sync_generated_docs.dart:157`, `docs/tool/sync_generated_docs.dart:163`, `docs/tool/sync_generated_docs.dart:165`). It hard-codes selected architecture graph phase P14 (`docs/tool/sync_generated_docs.dart:15`) and delegates graph view generation with `--phase P14` (`docs/tool/sync_generated_docs.dart:191`, `docs/tool/sync_generated_docs.dart:195`). `check_docs.dart` hard-codes P0-P14 phase docs and validates generated-doc parity, section/donor/diagram references, benchmark docs projection, and phase read-first references (`docs/tool/check_docs.dart:34`, `docs/tool/check_docs.dart:49`, `docs/tool/check_docs.dart:130`, `docs/tool/check_docs.dart:143`, `docs/tool/check_docs.dart:150`).
- **Dependencies**: Release workflow runs release benchmarks, diff, P14 graph check, P14 generated-view check, and guardrails (`.github/workflows/release_benchmarks.yml:24`, `.github/workflows/release_benchmarks.yml:25`, `.github/workflows/release_benchmarks.yml:28`, `.github/workflows/release_benchmarks.yml:31`, `.github/workflows/release_benchmarks.yml:34`, `.github/workflows/release_benchmarks.yml:37`). Release readiness guardrail requires exact release commands including P14 architecture graph checks (`tool/guardrails/src/release_readiness_checks.dart:247`, `tool/guardrails/src/release_readiness_checks.dart:250`, `tool/guardrails/src/release_readiness_checks.dart:251`).
- **Data flow**: Registries and graph YAML -> docs generators/checkers -> generated files and check result. Workflow YAML and benchmark sources -> release readiness guardrail -> `release.benchmark_readiness` violations.

### 8. Source, Example, And Benchmark Vocabulary Residue
- **Location**: primary `lib/src/contracts/public/canvas_pointer.dart:8`; additional `example/test/canvas_example_startup_test.dart:34`, `tool/bench/src/benchmark_manifest.dart:226`, `tool/bench/src/benchmark_diff.dart:1014`
- **Description**: Some search hits are not migration-phase artifacts. Public pointer API declares `CanvasPointerLifecyclePhase` (`lib/src/contracts/public/canvas_pointer.dart:8`) and stores `phase` in `CanvasPointerSample` (`lib/src/contracts/public/canvas_pointer.dart:95`, `lib/src/contracts/public/canvas_pointer.dart:117`, `lib/src/contracts/public/canvas_pointer.dart:125`). Example tests contain legacy wording around startup/default parity (`example/test/canvas_example_startup_test.dart:34`, `example/test/canvas_example_view_model_test.dart:448`). Benchmark tooling uses legacy-equivalence vocabulary as benchmark policy metadata: classifications include `equivalent_legacy` (`tool/bench/src/benchmark_manifest.dart:226`), reports include `bootstrap_legacy_equivalence` (`tool/bench/src/benchmark_manifest.dart:409`, `tool/bench/src/benchmark_report.dart:299`), and diff validation reads `legacy_avg_us` (`tool/bench/src/benchmark_diff.dart:1014`, `tool/bench/src/benchmark_diff.dart:1019`, `tool/bench/src/benchmark_diff.dart:1031`).
- **Dependencies**: Pointer phase vocabulary is consumed by surface pointer adaptation and interaction normalization (`lib/src/surface/pointer_adapter.dart:35`, `lib/src/interaction/pointer_sample_normalizer.dart:10`). Benchmark vocabulary is consumed by manifest parsing, report generation, and first-baseline/diff validation (`tool/bench/src/benchmark_manifest.dart:40`, `tool/bench/src/benchmark_diff.dart:181`, `tool/bench/src/benchmark_diff.dart:1943`).
- **Data flow**: Public pointer sample input -> surface/interaction routing. Benchmark manifest/report JSON -> parser/diff validator -> release benchmark policy output.

## Code References
- `analysis_options.yaml:3` - root analyzer excludes `legacy/**`.
- `AGENTS.md:5` - repository mode says the current task is the new engine described in `docs/`, not the legacy package.
- `AGENTS.md:9` - `PLAN.md` is the active roadmap and source of truth for planned work.
- `PLAN.md:15` - completed step contracts are historical records that may reference retired paths, APIs, or checks.
- `PLAN.md:74` - Step 52 is checked in the plan index.
- `plan/step_52_legacy_example_full_parity_port.md:169` - Step 52 Unit 1 is checked.
- `plan/step_52_legacy_example_full_parity_port.md:313` - Step 52 Unit 7 is checked.
- `legacy/iwb_canvas_engine/pubspec.yaml:1` - legacy package name.
- `legacy/iwb_canvas_engine/pubspec.yaml:40` - legacy package cat image asset.
- `legacy/iwb_canvas_engine/example/pubspec.yaml:12` - legacy example path dependency on parent package.
- `tool/guardrails/src/core_boundary_checks.dart:385` - core legacy import check entry.
- `tool/guardrails/src/core_boundary_checks.dart:391` - `core.no_legacy_imports` violation construction.
- `tool/guardrails/src/public_api_checks.dart:472` - legacy public API golden path construction.
- `tool/guardrails/src/public_api_checks.dart:474` - legacy public API golden file read.
- `tool/guardrails/src/release_readiness_checks.dart:130` - release readiness legacy import regex.
- `tool/guardrails/src/release_readiness_checks.dart:266` - release workflow legacy command scan.
- `test/api_contract/no_legacy_public_symbols_test.dart:7` - current root public surface retired-symbol test.
- `test/api_contract/example_public_boundary_test.dart:66` - example source retired seam boundary test.
- `test/guardrails/core_boundary_negative_fixtures_test.dart:50` - synthetic legacy import fixture.
- `test/geometry/no_legacy_scene_order_test.dart:13` - geometry policy source scan.
- `test/frame/frame_donor_mapping_test.dart:4` - frame donor mapping test group.
- `test/geometry/geometry_spatial_donor_mapping_test.dart:4` - geometry/spatial donor mapping test group.
- `docs/verification/legacy_capability_inventory.md:25` - legacy inventory described as P1 evidence input.
- `docs/verification/legacy_capability_inventory.md:116` - inventory rows feed later behavior tests and accepted-difference decisions.
- `docs/_registry/sections.yaml:299` - registry entry for legacy capability inventory section.
- `docs/_registry/donors.yaml:1` - donor registry start.
- `docs/architecture/architecture_graph.yaml:2` - phase inventory start.
- `docs/tool/sync_generated_docs.dart:15` - selected architecture graph phase P14.
- `docs/tool/check_docs.dart:34` - hard-coded phase document map start.
- `.github/workflows/release_benchmarks.yml:24` - release benchmark workflow step sequence.
- `tool/bench/src/benchmark_manifest.dart:226` - benchmark classification vocabulary.
- `tool/bench/src/benchmark_diff.dart:1014` - equivalent legacy case branch.

## Search Coverage
- **Inspected**: `AGENTS.md`, `PLAN.md`, `plan/step_52_legacy_example_full_parity_port.md`, root `analysis_options.yaml`, selected root configs, `legacy/iwb_canvas_engine/pubspec.yaml`, `legacy/iwb_canvas_engine/.metadata`, `legacy/iwb_canvas_engine/analysis_options.yaml`, `legacy/iwb_canvas_engine/dart_test.yaml`, `legacy/iwb_canvas_engine/example/pubspec.yaml`, selected guardrail implementations, selected benchmark tooling, selected documentation tooling, selected docs registries, selected generated indexes, selected architecture graph files, and selected tests named in Code References.
- **Searched**: `rg --files`; `find legacy -maxdepth 3 -type d`; `find . -path './legacy' -prune -o -type f \( -name '*legacy*' -o -name '*phase*' -o -name '*donor*' -o -name '*parity*' -o -name '*migration*' \) -print`; broad `rg` for `legacy`, `Legacy`, `donor`, `Donor`, `parity`, `Parity`, `migration`, `Migration`, `migrated`, `Migrated`, `phase`, `Phase`, `P[0-9]{1,2}`, `scene_controller`, `SceneController`, `scene_`; focused searches over `test`, `tool`, `docs`, `lib`, `example`, `PLAN.md`, and `plan`.
- **Command output facts**: current `PLAN.md` count is `plan_step_entries=58`, `plan_checked=58`, and `plan_unchecked=0`; filesystem count for `plan/step_*.md` is 58.
- **Not found**: scoped searches found no root `legacy/` matches in root `pubspec.yaml`, root `pubspec.lock`, root `dart_test.yaml`, root `.dart_tool`, or root `.github`. Scoped executable searches found no direct execution of legacy runtime code from inspected tests/guardrails.
- **Not inspected**: every file under `legacy/iwb_canvas_engine` was not read completely because the research question targeted current root-package footprints and non-legacy references. Historical `.design/` and older `.research/` files with legacy references were searched and sampled through reported matches, but not fully synthesized as current sources of truth.

## Observed Architecture Facts
- Pattern observed: legacy package is isolated by root analyzer exclusion and by guardrails that reject legacy imports in production or release paths (`analysis_options.yaml:3`, `tool/guardrails/src/core_boundary_checks.dart:385`, `tool/guardrails/src/release_readiness_checks.dart:266`).
- Pattern observed: public API retired-symbol enforcement currently depends on the legacy public API golden file under `legacy/iwb_canvas_engine/tool/goldens/` (`tool/guardrails/src/public_api_checks.dart:472`, `tool/guardrails/src/public_api_checks.dart:474`).
- Pattern observed: phase state is mechanically encoded in the architecture graph and documentation tooling, not only prose (`docs/architecture/architecture_graph.yaml:2`, `tool/architecture_graph/check.dart:7`, `docs/tool/sync_generated_docs.dart:15`).
- Data flow: `docs/_registry/sections.yaml` and `docs/_registry/donors.yaml` -> docs generator -> generated indexes (`docs/tool/sync_generated_docs.dart:163`, `docs/tool/sync_generated_docs.dart:165`, `docs/indexes/by_phase.md:1`).
- Data flow: benchmark manifest/report fields -> benchmark diff and release readiness policy (`tool/bench/src/benchmark_manifest.dart:226`, `tool/bench/src/benchmark_diff.dart:1014`, `tool/guardrails/src/release_readiness_checks.dart:247`).
- Key dependency: `PLAN.md` and `plan/` are still exposed by `docs/README.md` as the Change Contract route (`docs/README.md:19`).

## Open Questions
- The architecture graph currently marks P10 and P13 as `future` while `PLAN.md` marks Step 47 P10 and Step 51 P13 as checked; this research records the two source states but does not resolve their relationship (`docs/architecture/architecture_graph.yaml:61`, `docs/architecture/architecture_graph.yaml:63`, `docs/architecture/architecture_graph.yaml:79`, `docs/architecture/architecture_graph.yaml:81`, `PLAN.md:69`, `PLAN.md:73`).
- The public API guardrail reads a legacy golden from `legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt`; this research records that input path but does not determine an alternative source for the retired-symbol set (`tool/guardrails/src/public_api_checks.dart:472`, `tool/guardrails/src/public_api_checks.dart:474`).
