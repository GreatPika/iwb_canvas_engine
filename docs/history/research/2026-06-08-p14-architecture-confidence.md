---
date: 2026-06-08
researcher: Codex
commit: db8b1e5d
branch: new-architecture
research_question: "After closing P14, use DCM dependency graphs and codebase research to check whether the architecture is in order and locate any suspicious areas."
---

# Research: P14 Architecture Confidence

## Summary

The current package architecture is acyclic in the DCM graph slices inspected for this research. The current repo-wide DCM slice excluding `legacy/**` contains 619 nodes, 2599 DOT edges, and no strongly connected components larger than one node. The production-only `lib` DCM slice contains 179 nodes, 864 DOT edges, and no strongly connected components larger than one node. These counts come from command-generated DOT parsing of `dcm analyze-structure` output; the raw DOT files were temporary research inputs, not repository source-of-truth artifacts.

The repository-owned architecture checks that directly target P14 and the core/API boundaries passed in this environment: P14 graph closure, generated P14 graph views, docs sync/check, `core` guardrail suite, `api` guardrail suite, and `release.benchmark_readiness`. The full blocking guardrail runner did not pass: it stopped at `diagnostics.disabled_no_alloc_hot_path`, where the generated temporary consumer package fails to compile because it calls `decodeSchemaV1Document` and `decodeSchemaV1DocumentFromJson` through the public barrel (`test/diagnostics/disabled_no_alloc_hot_path_test.dart:21`, `test/diagnostics/disabled_no_alloc_hot_path_test.dart:25`, `test/diagnostics/disabled_no_alloc_hot_path_test.dart:96`). Those functions exist as internal codec functions (`lib/src/codec/schema_v1_decoder.dart:24`, `lib/src/codec/schema_v1_decoder.dart:83`) but are not public API exports; the public codec facade exports only encode helpers (`lib/src/api/canvas_codec.dart:12`, `lib/src/api/canvas_codec.dart:17`).

The main architecture picture is therefore: production owners and the current package dependency graph are acyclic and the official P14/core/API/release architecture gates are green, while one blocking diagnostics proof is stale or misaligned with the current public API boundary. No current-code edge from the current package into `legacy` was found in the parsed DCM graph. The full root DCM graph included `legacy` as a separate cluster, and all SCC cycles found in the full root graph were inside `legacy` by command-generated DOT parsing.

## Detailed Findings

### 1. DCM Dependency Graph

- **Location**: command-generated evidence from `dcm analyze-structure` output.
- **Description**: DCM `analyze-structure` produced temporary DOT graphs for the current package without `legacy/**`, production-only `lib`, full root graph, and package-level graph. The current slice had current-package top-level clusters for `test`, `tool`, `docs/tool`, `lib`, and `example`. The full root graph included external files and `legacy` clusters.
- **Dependencies**: The current package graph had external Dart, Flutter, and Pub package clusters.
- **Data flow**: Source files -> DCM DOT graph -> local DOT parser -> node/edge/SCC counts. Command-generated evidence exception: DCM DOT parse counted 619 current-slice nodes, 2599 current-slice edges, 1824 current internal edges, 775 current edges to external targets, and 0 SCC cycles; it counted 179 `lib` nodes, 864 `lib` edges, and 0 SCC cycles.

### 2. Documented Architecture Source Of Truth

- **Location**: primary `docs/README.md:21`.
- **Description**: The documentation entrypoint names normative architecture, contracts, verification policy, implementation sequencing, donor policy, structured registries, and generated navigation (`docs/README.md:23`, `docs/README.md:29`). P14 is declared in the architecture graph as "Benchmarks, diagrams, and release readiness" with `status: measurement` (`docs/architecture/architecture_graph.yaml:85`, `docs/architecture/architecture_graph.yaml:87`).
- **Dependencies**: P14 graph source docs are `docs/implementation/p14_benchmarks_diagrams_and_release_readiness.md` and `docs/verification/benchmarks.md` (`docs/architecture/architecture_graph.yaml:88`, `docs/architecture/architecture_graph.yaml:90`).
- **Data flow**: Architecture docs and graph YAML -> `tool/architecture_graph/check.dart` loads expected graph, extracts actual graph, checks phase closure, and exits by `report.isClosed` (`tool/architecture_graph/check.dart:17`, `tool/architecture_graph/check.dart:35`). Generated views load the expected graph, build views from actual extraction, and compare generated files in `--check` mode (`tool/architecture_graph/generate_views.dart:14`, `tool/architecture_graph/generate_views.dart:21`, `tool/architecture_graph/generate_views.dart:85`).

### 3. Production Owner Layout

- **Location**: primary `lib/src/runtime/runtime_root.dart:89`.
- **Description**: The production runtime composition root implements `DocumentFactsPort`, `FrameFactsPort`, `ResolverMutationGuard`, and `ResourceDirtyOutcomeSink` (`lib/src/runtime/runtime_root.dart:89`, `lib/src/runtime/runtime_root.dart:94`). It wires store, edit, resources, frame, interaction, geometry, selection, and diagnostics owners through explicit fields and constructors (`lib/src/runtime/runtime_root.dart:170`, `lib/src/runtime/runtime_root.dart:238`).
- **Dependencies**: The documented package boundary rules define source rules for root barrel, production `lib/**`, frame facts, contracts/public, and contracts/internal (`docs/architecture/02_package_boundaries.md:226`, `docs/architecture/02_package_boundaries.md:238`). The forbidden import matrix includes runtime, store, edit, interaction, frame, geometry, resources, codec, diagnostics, tools, surface, example, and all-lib rules (`docs/architecture/02_package_boundaries.md:278`, `docs/architecture/02_package_boundaries.md:306`).
- **Data flow**: Public facade calls create/use `RuntimeRoot`; runtime composes owners; owners communicate through contracts/internal and contracts/public seams. DCM DOT parse of `lib` found the most frequent cross-owner production edges as runtime -> contracts, edit -> contracts, frame -> contracts, store -> contracts, interaction -> contracts, api -> contracts, codec -> contracts, and geometry -> contracts.

### 4. Public API And Export Boundary

- **Location**: primary `lib/iwb_canvas_engine.dart:1`.
- **Description**: The public root barrel exports only `src/api/**` files (`lib/iwb_canvas_engine.dart:1`, `lib/iwb_canvas_engine.dart:18`). The public codec facade currently exposes `canvasSchemaVersionWrite`, `canvasSchemaVersionsRead`, `encodeCanvasDocument`, and `encodeCanvasDocumentToJson` (`lib/src/api/canvas_codec.dart:6`, `lib/src/api/canvas_codec.dart:18`).
- **Dependencies**: The public API contract says public codec API contains encode helpers and schema version introspection, while public schema v1 JSON load is the runtime command `CanvasEditPort.loadDocumentFromJson(String json)` rather than a public decode helper (`docs/contracts/public_api_v1.md:791`, `docs/contracts/public_api_v1.md:806`). The codec boundary states that public API does not expose `decodeCanvasDocument` or `decodeCanvasDocumentFromJson` as runtime load routes (`docs/contracts/codec_boundary.md:74`, `docs/contracts/codec_boundary.md:80`).
- **Data flow**: Root public barrel -> API facade files -> contracts/public declarations or named implementation bridges. API guardrails require the public barrel to match the registry and reject retired public decode/load routes (`docs/verification/guardrails.md:179`, `docs/verification/guardrails.md:180`).

### 5. Guardrails And Enforcement

- **Location**: primary `tool/guardrails/src/guardrail_registry.dart:35`.
- **Description**: The blocking guardrail inventory includes API, codec, diagnostics, release, core, store, projection, selection, interaction, edit, resources, frame, cache, surface, and related guardrails (`tool/guardrails/src/guardrail_registry.dart:35`, `tool/guardrails/src/guardrail_registry.dart:138`). `diagnostics.disabled_no_alloc_hot_path` is in the blocking and diagnostics suites (`tool/guardrails/src/guardrail_registry.dart:104`, `tool/guardrails/src/guardrail_registry.dart:108`), and owner DAG import boundaries are in the blocking and core suites (`tool/guardrails/src/guardrail_registry.dart:132`, `tool/guardrails/src/guardrail_registry.dart:137`).
- **Dependencies**: The executor runs proof tests first, then structural checks when both are registered (`tool/guardrails/src/guardrail_executor.dart:102`, `tool/guardrails/src/guardrail_executor.dart:117`). Structural checks include public API route checks, single runtime root, projection, selection, interaction import boundaries, owner DAG import boundaries, resource/surface/frame/cache/text checks, and release readiness (`tool/guardrails/src/guardrail_executor.dart:413`, `tool/guardrails/src/guardrail_executor.dart:460`).
- **Data flow**: Guardrail id selection -> proof test path or structural checker -> early exit on first non-zero guardrail. In this research, `core`, `api`, and `release.benchmark_readiness` passed as commands; the full default blocking runner failed at `diagnostics.disabled_no_alloc_hot_path`.

### 6. Non-Production Consumers

- **Location**: primary `test/api_contract/example_public_boundary_test.dart:47`.
- **Description**: The example public-boundary test requires example code to import the engine through the public barrel and rejects example imports containing `package:iwb_canvas_engine/src/`, `/lib/src/`, `../lib/src/`, or `legacy/` (`test/api_contract/example_public_boundary_test.dart:47`, `test/api_contract/example_public_boundary_test.dart:190`). Example source files import `package:iwb_canvas_engine/iwb_canvas_engine.dart` through the public barrel, as observed by research subagent coverage.
- **Dependencies**: In-package benchmark and test fixtures import `lib/src/**` directly for internal proof surfaces; for example the benchmark probe imports private API, contracts, diagnostics, frame, geometry, resources, and runtime owners (`test/benchmarks/benchmark_probe_flutter.dart:14`, `test/benchmarks/benchmark_probe_flutter.dart:40`).
- **Data flow**: External-like example/consumer fixtures -> public barrel. In-package fixtures/probes -> internal owners for structural and behavioral proof. The test shape policy says in-package unit and behavior tests should not create temporary Flutter consumer packages unless proving external consumer access (`docs/verification/tests.md:475`, `docs/verification/tests.md:479`).

### 7. Blocking Diagnostics Proof Drift

- **Location**: primary `test/diagnostics/disabled_no_alloc_hot_path_test.dart:21`.
- **Description**: The diagnostics no-allocation proof builds a temporary Flutter consumer package and imports `package:iwb_canvas_engine/iwb_canvas_engine.dart` plus internal diagnostics files (`test/diagnostics/disabled_no_alloc_hot_path_test.dart:21`, `test/diagnostics/disabled_no_alloc_hot_path_test.dart:27`). Its codec-success subtest calls `decodeSchemaV1Document` and `decodeSchemaV1DocumentFromJson` (`test/diagnostics/disabled_no_alloc_hot_path_test.dart:82`, `test/diagnostics/disabled_no_alloc_hot_path_test.dart:97`).
- **Dependencies**: Those decoder functions exist under `lib/src/codec/schema_v1_decoder.dart` (`lib/src/codec/schema_v1_decoder.dart:24`, `lib/src/codec/schema_v1_decoder.dart:83`) but are not exported by `lib/src/api/canvas_codec.dart`, which exports only encode helpers (`lib/src/api/canvas_codec.dart:12`, `lib/src/api/canvas_codec.dart:18`). The public API negative compile test explicitly treats retired public load/decode routes as non-compiling from an external consumer (`test/api_contract/public_api_v1_compiles_as_written_test.dart:17`, `test/api_contract/public_api_v1_compiles_as_written_test.dart:22`, `test/api_contract/public_api_v1_compiles_as_written_test.dart:76`, `test/api_contract/public_api_v1_compiles_as_written_test.dart:83`).
- **Data flow**: Guardrail runner -> `test/diagnostics/disabled_no_alloc_hot_path_test.dart` -> temporary consumer package -> public barrel and selected internal diagnostics imports -> compile failure before runtime assertions. The focused `dart test test/diagnostics/disabled_no_alloc_hot_path_test.dart` command and `dart run tool/guardrails/run.dart --guardrail=diagnostics.disabled_no_alloc_hot_path` both failed with method-not-found errors for these two decoder functions.

## Code References

- `lib/iwb_canvas_engine.dart:1` - root public barrel exports only API facade files.
- `lib/src/api/canvas_codec.dart:12` - public codec facade exposes encode helper.
- `lib/src/codec/schema_v1_decoder.dart:24` - internal schema v1 map decoder declaration.
- `lib/src/codec/schema_v1_decoder.dart:83` - internal schema v1 JSON decoder declaration.
- `lib/src/runtime/runtime_root.dart:89` - runtime composition root and implemented ports.
- `docs/architecture/02_package_boundaries.md:278` - forbidden import matrix begins.
- `docs/architecture/architecture_graph.yaml:85` - P14 phase entry.
- `docs/contracts/public_api_v1.md:801` - public codec API excludes public decode route.
- `docs/verification/guardrails.md:195` - `core.no_legacy_imports` rule.
- `docs/verification/guardrails.md:197` - `core.owner_dag_import_boundaries` rule.
- `docs/verification/guardrails.md:254` - `diagnostics.disabled_no_alloc_hot_path` rule.
- `docs/verification/tests.md:475` - in-package test shape rule.
- `tool/architecture_graph/check.dart:17` - phase graph checker loads expected graph.
- `tool/architecture_graph/generate_views.dart:85` - generated graph view stale-file check.
- `tool/guardrails/src/guardrail_executor.dart:50` - guardrail runner entry.
- `tool/guardrails/src/guardrail_registry.dart:104` - diagnostics disabled no-allocation guardrail entry.
- `test/diagnostics/disabled_no_alloc_hot_path_test.dart:96` - failing consumer call to internal decoder name.
- `test/api_contract/public_api_v1_compiles_as_written_test.dart:17` - retired public route non-compilation test.

## Search Coverage

- **Inspected**: temporary DCM DOT output from `dcm analyze-structure`; `lib/iwb_canvas_engine.dart`; `lib/src/api/canvas_codec.dart`; `lib/src/codec/schema_v1_decoder.dart`; `lib/src/runtime/runtime_root.dart` import/composition areas; `docs/README.md`; `docs/architecture/00_architecture_overview.md`; `docs/architecture/01_runtime_ownership.md`; `docs/architecture/02_package_boundaries.md`; `docs/architecture/architecture_graph.yaml`; `docs/contracts/public_api_v1.md`; `docs/contracts/codec_boundary.md`; `docs/contracts/diagnostics.md`; `docs/verification/guardrails.md`; `docs/verification/tests.md`; `tool/architecture_graph/check.dart`; `tool/architecture_graph/generate_views.dart`; `tool/guardrails/src/guardrail_registry.dart`; `tool/guardrails/src/guardrail_executor.dart`; `tool/guardrails/src/owner_dag_import_checks.dart`; `tool/guardrails/src/public_api_checks.dart`; `test/diagnostics/disabled_no_alloc_hot_path_test.dart`; `test/api_contract/public_api_v1_compiles_as_written_test.dart`; `test/support/flutter_consumer_test_harness.dart`.
- **Searched**: `rg -n "decodeSchemaV1Document|decodeCanvasDocument|CanvasEditPort.loadDocumentFromJson|no_retired_public_load_routes|disabled_no_alloc_hot_path" lib test tool docs`; `rg -n "Architecture|runtime|boundary|graph|phase|p14|P14|public API|legacy" docs/README.md docs/architecture/00_architecture_overview.md docs/architecture/01_runtime_ownership.md docs/architecture/02_package_boundaries.md docs/verification/guardrails.md docs/verification/release_gates.md PLAN.md`; `find lib test tool docs example -maxdepth 3 -type f`; DCM DOT parser for node/edge/SCC counts and cross-owner edge counts.
- **Commands run**: `dcm analyze-structure . --show-external-packages --exclude='legacy/**' --no-congratulate`; `dcm analyze-structure lib --show-external-packages --no-congratulate`; `dcm analyze-structure . --per-package --show-external-packages --no-congratulate`; `dart run tool/architecture_graph/check.dart --phase P14`; `dart run tool/architecture_graph/generate_views.dart --phase P14 --check`; `dart run docs/tool/sync_generated_docs.dart --check`; `dart run docs/tool/check_docs.dart`; `dart run tool/guardrails/run.dart --suite=core`; `dart run tool/guardrails/run.dart --suite=api`; `dart run tool/guardrails/run.dart --guardrail=release.benchmark_readiness`; `dart run tool/guardrails/run.dart`; `dart run tool/guardrails/run.dart --guardrail=diagnostics.disabled_no_alloc_hot_path`; `dart test test/diagnostics/disabled_no_alloc_hot_path_test.dart`.
- **Not found**: no SCC cycles in the current package DCM slice; no SCC cycles in production-only `lib`; no current-package-to-legacy DCM edge in parsed graph; no `legacy/` import in example source imports per subagent search; no direct `package:iwb_canvas_engine/src/` imports under `tool` per subagent search.
- **Not inspected**: `legacy/**` source contents were not read, except DCM graph labels proving the full root graph includes legacy. Full production behavior tests outside the guardrail runner were not run. DCM `check-dependencies` did not produce a full report in this environment because the available license reported plan/report limits.

## Observed Architecture Facts

- Pattern observed: public consumers use `lib/iwb_canvas_engine.dart`, which exports API facade files only (`lib/iwb_canvas_engine.dart:1`, `lib/iwb_canvas_engine.dart:18`).
- Pattern observed: `RuntimeRoot` is the composition boundary for store, edit, resources, frame, interaction, geometry, selection, and diagnostics (`lib/src/runtime/runtime_root.dart:89`, `lib/src/runtime/runtime_root.dart:238`).
- Pattern observed: source boundary and owner DAG rules are documented and mechanically checked by guardrails (`docs/architecture/02_package_boundaries.md:278`, `tool/guardrails/src/owner_dag_import_checks.dart:340`).
- Data flow: architecture graph YAML -> actual graph extractor -> phase closure checker -> P14 closure report (`tool/architecture_graph/check.dart:17`, `tool/architecture_graph/check.dart:35`).
- Data flow: public API registry/contract -> public barrel/API guardrails -> external consumer compile checks (`docs/contracts/public_api_v1.md:801`, `test/api_contract/public_api_v1_compiles_as_written_test.dart:9`).
- Key dependency signal: current package DCM graph and production `lib` DCM graph are acyclic by command-generated SCC parsing.
- Blocking drift: `diagnostics.disabled_no_alloc_hot_path` currently fails before assertions because its consumer test references non-exported internal decoder functions (`test/diagnostics/disabled_no_alloc_hot_path_test.dart:96`, `test/diagnostics/disabled_no_alloc_hot_path_test.dart:97`).

## Open Questions

- The current production owner graph and P14/core/API/release architecture gates did not expose a production dependency-cycle or legacy import issue.
- The full blocking guardrail suite remains open because `diagnostics.disabled_no_alloc_hot_path` fails at compile/load time in its temporary consumer package.
- DCM `check-dependencies` reported license/report limits in this environment, so dependency issue localization from that command was not available for this research.
