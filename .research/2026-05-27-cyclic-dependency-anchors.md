---
date: 2026-05-27
researcher: Codex
commit: af4dbb9a
branch: new-architecture
research_question: "Find all code, documentation, guardrail, architecture graph, registry, and diagram anchors for the current cyclic dependencies so a later design can remove them."
---

# Research: Cyclic Dependency Anchors

## Summary

The current production source graph has module-level cycles anchored by the public runtime facade, runtime composition root, edit/load pipeline, selection kernel, store kernel, codec, and diagnostics hub. The central shape is `api -> runtime`, `runtime -> api/edit/selection/store`, `edit -> api/store/codec/diagnostics`, `selection -> api/runtime`, `store -> api`, `codec -> api/diagnostics`, and `diagnostics -> api`, with direct imports recorded in the files listed below.

The repository already has enforcement for selected import boundaries and public-API-internal import cycles, but the public API cycle checker only builds a graph from files under `lib/src/api/` and only keeps edges whose targets are also public API files (`tool/guardrails/src/public_api_import_cycle_checks.dart:36`, `tool/guardrails/src/public_api_import_cycle_checks.dart:50`). The source boundary checker explicitly permits the current `CanvasRuntime -> RuntimeRoot` import (`tool/guardrails/src/core_boundary_checks.dart:592`).

The same dependency shape is also represented in architecture documentation, the architecture graph registry, generated graph views, C4/DFD/sequence Mermaid diagrams, and plan/design artifacts. These artifacts record the runtime-root composition model, codec/public DTO relation, edit/store mutation boundary, load/store replacement boundary, and future P7 resource edges.

## Detailed Findings

### 1. Production Source Import Anchors

- **Location**: `lib/src/api/canvas_runtime.dart:22`
- **Description**: The public `CanvasRuntime` facade imports `../runtime/runtime_root.dart`, constructs a `RuntimeRoot`, and stores it as the backing runtime implementation (`lib/src/api/canvas_runtime.dart:34`, `lib/src/api/canvas_runtime.dart:37`).
- **Dependencies**: This creates the direct `api -> runtime` edge.
- **Data flow**: Public facade construction -> `RuntimeRoot` composition -> runtime-owned behavior delegation.

- **Location**: `lib/src/runtime/runtime_root.dart:13`
- **Description**: `RuntimeRoot` imports public API types and ports from `lib/src/api/`, then composes edit, selection, and store kernels (`lib/src/runtime/runtime_root.dart:18`, `lib/src/runtime/runtime_root.dart:23`, `lib/src/runtime/runtime_root.dart:24`). The constructor builds `DocumentStoreKernel` and runtime configuration (`lib/src/runtime/runtime_root.dart:42`, `lib/src/runtime/runtime_root.dart:43`), and wires load/selection behavior (`lib/src/runtime/runtime_root.dart:75`, `lib/src/runtime/runtime_root.dart:80`).
- **Dependencies**: This contributes `runtime -> api`, `runtime -> edit`, `runtime -> selection`, and `runtime -> store`.
- **Data flow**: Runtime composition root -> committed document store, edit pipeline, selection kernel, load pipeline.

- **Location**: `lib/src/runtime/runtime_config.dart:1`
- **Description**: Runtime configuration imports public API configuration and runtime value types, then adapts `CanvasRuntimeConfig` into runtime-internal `RuntimeConfig` (`lib/src/runtime/runtime_config.dart:8`).
- **Dependencies**: This contributes another `runtime -> api` edge.
- **Data flow**: Public runtime config -> runtime config adapter.

- **Location**: `lib/src/runtime/document_facts_port.dart:1`
- **Description**: Runtime fact ports import public API document and ID/value types. Additional runtime ports import public API types at `lib/src/runtime/frame_facts_port.dart:3`, `lib/src/runtime/selection_facts_port.dart:1`, and `lib/src/runtime/selection_membership_port.dart:1`.
- **Dependencies**: These files add `runtime -> api` edges through runtime-owned public-facing ports.
- **Data flow**: Runtime/store facts -> public DTO/value types exposed through ports.

- **Location**: `lib/src/edit/edit_kernel.dart:5`
- **Description**: The edit kernel imports public runtime and document types (`lib/src/edit/edit_kernel.dart:3`, `lib/src/edit/edit_kernel.dart:5`) and is instantiated as the edit owner (`lib/src/edit/edit_kernel.dart:19`).
- **Dependencies**: This contributes `edit -> api`.
- **Data flow**: Public edit operations -> edit kernel -> commit install seam.

- **Location**: `lib/src/edit/draft_document.dart:12`
- **Description**: Draft document imports public runtime DTOs and store owners (`lib/src/edit/draft_document.dart:12`, `lib/src/edit/draft_document.dart:13`, `lib/src/edit/draft_document.dart:14`).
- **Dependencies**: This contributes `edit -> api` and `edit -> store`.
- **Data flow**: Draft edit state -> public document DTOs -> store-backed committed document data.

- **Location**: `lib/src/edit/edit_session.dart:13`
- **Description**: Edit session imports public runtime types and committed store state (`lib/src/edit/edit_session.dart:13`, `lib/src/edit/edit_session.dart:14`).
- **Dependencies**: This contributes `edit -> api` and `edit -> store`.
- **Data flow**: Runtime edit handle -> edit session -> store-backed commit install.

- **Location**: `lib/src/edit/staged_document_load.dart:4`
- **Description**: Staged document loading imports codec, diagnostics, and store dependencies (`lib/src/edit/staged_document_load.dart:4`, `lib/src/edit/staged_document_load.dart:5`, `lib/src/edit/staged_document_load.dart:6`, `lib/src/edit/staged_document_load.dart:7`).
- **Dependencies**: This contributes `edit -> codec`, `edit -> diagnostics`, and `edit -> store`.
- **Data flow**: Encoded document load -> schema codec -> diagnostics -> store replacement pipeline.

- **Location**: `lib/src/edit/commit_applier.dart:2`
- **Description**: Commit application imports store-owned committed state (`lib/src/edit/commit_applier.dart:2`). Commit planning and compilation also import store state at `lib/src/edit/commit_plan.dart:1` and `lib/src/edit/commit_compiler.dart:2`.
- **Dependencies**: These files contribute `edit -> store`.
- **Data flow**: Edit commit plan/compiler/applier -> committed document/store structures.

- **Location**: `lib/src/selection/selection_kernel.dart:4`
- **Description**: The selection kernel imports runtime selection ports (`lib/src/selection/selection_kernel.dart:4`, `lib/src/selection/selection_kernel.dart:5`) and owns `SelectionKernel` (`lib/src/selection/selection_kernel.dart:7`).
- **Dependencies**: This contributes `selection -> runtime` while runtime root imports selection at `lib/src/runtime/runtime_root.dart:23`.
- **Data flow**: Runtime selection port contract -> selection kernel implementation.

- **Location**: `lib/src/store/document_store_kernel.dart:8`
- **Description**: Store imports public API document, fact, projection, and revision types (`lib/src/store/document_store_kernel.dart:8`, `lib/src/store/document_store_kernel.dart:12`) and defines the committed document owner (`lib/src/store/document_store_kernel.dart:23`).
- **Dependencies**: This contributes `store -> api`.
- **Data flow**: Committed store state -> public DTO/fact/projection/revision types.

- **Location**: `lib/src/store/committed_document.dart:1`
- **Description**: Store committed document imports public document, id, and metadata types (`lib/src/store/committed_document.dart:1`, `lib/src/store/committed_document.dart:3`). Additional store files import public API types at `lib/src/store/element_registry.dart:1`, `lib/src/store/family_tables.dart:6`, and `lib/src/store/resource_table.dart:4`.
- **Dependencies**: These files contribute `store -> api`.
- **Data flow**: Store data structures -> public document model/value types.

- **Location**: `lib/src/api/canvas_codec.dart:3`
- **Description**: Public codec facade imports schema v1 decoder and encoder (`lib/src/api/canvas_codec.dart:3`, `lib/src/api/canvas_codec.dart:4`).
- **Dependencies**: This contributes `api -> codec`.
- **Data flow**: Public codec API -> schema v1 encode/decode implementation.

- **Location**: `lib/src/codec/schema_v1_decoder.dart:8`
- **Description**: Schema v1 decoding imports public API DTOs and diagnostics (`lib/src/codec/schema_v1_decoder.dart:8`, `lib/src/codec/schema_v1_decoder.dart:16`, `lib/src/codec/schema_v1_decoder.dart:17`). Encoder imports the same direction at `lib/src/codec/schema_v1_encoder.dart:7`, `lib/src/codec/schema_v1_encoder.dart:11`, and `lib/src/codec/schema_v1_encoder.dart:12`.
- **Dependencies**: These files contribute `codec -> api` and `codec -> diagnostics`.
- **Data flow**: Encoded schema data -> public document DTOs -> diagnostics for schema failures.

- **Location**: `lib/src/codec/validated_import_draft.dart:1`
- **Description**: Validated import draft imports public API DTOs and diagnostics (`lib/src/codec/validated_import_draft.dart:1`, `lib/src/codec/validated_import_draft.dart:6`, `lib/src/codec/validated_import_draft.dart:7`).
- **Dependencies**: This contributes `codec -> api` and `codec -> diagnostics`.
- **Data flow**: Validation output -> public import draft DTO -> diagnostics.

- **Location**: `lib/src/codec/schema_v1_diagnostics.dart:1`
- **Description**: Schema v1 diagnostics imports public API and diagnostics types (`lib/src/codec/schema_v1_diagnostics.dart:1`, `lib/src/codec/schema_v1_diagnostics.dart:2`). Schema validation imports the same direction at `lib/src/codec/schema_v1_validation.dart:1` and `lib/src/codec/schema_v1_validation.dart:2`.
- **Dependencies**: These files contribute `codec -> api` and `codec -> diagnostics`.
- **Data flow**: Schema validation/failure creation -> public error/diagnostic DTOs -> diagnostics hub route.

- **Location**: `lib/src/diagnostics/diagnostics_hub.dart:1`
- **Description**: Diagnostics hub imports public sanitizer, diagnostics, and error types (`lib/src/diagnostics/diagnostics_hub.dart:1`, `lib/src/diagnostics/diagnostics_hub.dart:3`).
- **Dependencies**: This contributes `diagnostics -> api`.
- **Data flow**: Diagnostics hub -> public diagnostic/error DTOs.

### 2. Existing Enforcement and Non-Enforcement Anchors

- **Location**: `tool/guardrails/src/public_api_import_cycle_checks.dart:13`
- **Description**: The public API cycle checker scans only `lib/src/api` (`tool/guardrails/src/public_api_import_cycle_checks.dart:10`, `tool/guardrails/src/public_api_import_cycle_checks.dart:15`). It filters sources to public API files (`tool/guardrails/src/public_api_import_cycle_checks.dart:36`) and only adds an edge when the resolved target is also in that public source set (`tool/guardrails/src/public_api_import_cycle_checks.dart:50`).
- **Dependencies**: It detects cycles inside `lib/src/api/**`, not cycles that leave API and return through runtime/store/edit/codec.
- **Data flow**: API source files -> public-only import graph -> Tarjan cycle finder (`tool/guardrails/src/public_api_import_cycle_checks.dart:201`).

- **Location**: `tool/guardrails/src/public_api_import_cycle_checks.dart:89`
- **Description**: `PublicApiImportCycleAllowlistEntry` exists, but supplied entries produce violations instead of active allowlisting (`tool/guardrails/src/public_api_import_cycle_checks.dart:120`, `tool/guardrails/src/public_api_import_cycle_checks.dart:142`).
- **Dependencies**: The cycle checker has no active allowlist for public API cycles.
- **Data flow**: Allowlist entries -> guardrail violations.

- **Location**: `tool/guardrails/src/guardrail_registry.dart:66`
- **Description**: The `api.no_public_api_import_cycles` guardrail is registered in the API guardrail suite (`tool/guardrails/src/guardrail_registry.dart:66`, `tool/guardrails/src/guardrail_registry.dart:68`).
- **Dependencies**: The runner invokes it from `tool/guardrails/src/guardrail_executor.dart:249`.
- **Data flow**: Guardrail suite -> public API cycle checker -> guardrail result.

- **Location**: `test/guardrails/public_api_import_cycles_test.dart:19`
- **Description**: The live guardrail test expects `checkNoPublicApiImportCycles()` to return no violations (`test/guardrails/public_api_import_cycles_test.dart:19`, `test/guardrails/public_api_import_cycles_test.dart:20`).
- **Dependencies**: The test covers the public-only graph described above.
- **Data flow**: Repository API files -> public-only cycle check -> empty violation expectation.

- **Location**: `tool/guardrails/src/core_boundary_checks.dart:442`
- **Description**: Source boundary rules forbid `lib/src/api/` imports to runtime/store/selection/edit/frame/interaction/resources/diagnostics/spatial/geometry/flutter_bridge (`tool/guardrails/src/core_boundary_checks.dart:445`, `tool/guardrails/src/core_boundary_checks.dart:458`), define store/edit/selection/resources/codec/diagnostics/frame/spatial rules (`tool/guardrails/src/core_boundary_checks.dart:460`, `tool/guardrails/src/core_boundary_checks.dart:557`), and skip forbidden reports when `_isAllowedBoundaryImport` returns true (`tool/guardrails/src/core_boundary_checks.dart:580`).
- **Dependencies**: The only allowed source-boundary exception is `lib/src/api/canvas_runtime.dart -> lib/src/runtime/runtime_root.dart` (`tool/guardrails/src/core_boundary_checks.dart:592`, `tool/guardrails/src/core_boundary_checks.dart:594`).
- **Data flow**: Import directive target -> boundary rule -> optional exception -> guardrail violation.

- **Location**: `test/guardrails/import_boundaries_test.dart:53`
- **Description**: Import-boundary tests exercise the allowed runtime-root exception and a forbidden runtime-config import (`test/guardrails/import_boundaries_test.dart:53`, `test/guardrails/import_boundaries_test.dart:71`).
- **Dependencies**: The test fixture records the current exception behavior.
- **Data flow**: Synthetic imports -> core boundary checker -> expected exception/prohibition results.

- **Location**: `tool/architecture_graph/src/actual_graph.dart:397`
- **Description**: Architecture graph collection records import directives as `ImportFact` values (`tool/architecture_graph/src/actual_graph.dart:397`, `tool/architecture_graph/src/actual_graph.dart:412`).
- **Dependencies**: Actual import facts are available to graph closure checks.
- **Data flow**: Parsed Dart unit imports -> actual graph facts.

- **Location**: `tool/architecture_graph/src/phase_closure.dart:253`
- **Description**: Phase closure checks configured `forbiddenEdges` as direct forbidden imports by owner prefixes (`tool/architecture_graph/src/phase_closure.dart:253`, `tool/architecture_graph/src/phase_closure.dart:289`).
- **Dependencies**: The checker enforces configured forbidden import edges, not arbitrary module-level cycles.
- **Data flow**: Architecture graph forbidden edge -> source owner prefix import facts -> violation.

- **Location**: `tool/architecture_graph/src/architecture_graph.dart:169`
- **Description**: The architecture graph schema includes `ForbiddenEdge` records (`tool/architecture_graph/src/architecture_graph.dart:169`, `tool/architecture_graph/src/architecture_graph.dart:186`) and loads top-level `forbiddenEdges` from YAML (`tool/architecture_graph/src/architecture_graph.dart:320`, `tool/architecture_graph/src/architecture_graph.dart:322`, `tool/architecture_graph/src/architecture_graph.dart:903`).
- **Dependencies**: Forbidden edge data comes from `docs/architecture/architecture_graph.yaml`.
- **Data flow**: YAML `forbiddenEdges` -> graph model -> phase closure checker.

- **Location**: `tool/architecture_graph/src/graph_views.dart:330`
- **Description**: Generated view checking validates graph view rendering/connectivity and isolated-node expectations (`tool/architecture_graph/src/graph_views.dart:330`, `tool/architecture_graph/src/graph_views.dart:354`).
- **Dependencies**: The view check validates generated graph views, not import-cycle absence.
- **Data flow**: Architecture graph view model -> generated Mermaid view -> check result.

- **Location**: `analysis_options.yaml:90`
- **Description**: DCM rules are configured under the repository analyzer options (`analysis_options.yaml:90`), with metrics including import count and external imports (`analysis_options.yaml:131`, `analysis_options.yaml:133`).
- **Dependencies**: The file configures metrics/rules but does not encode a repository-local module-cycle rule in the cited rules section.
- **Data flow**: Analyzer/DCM config -> static analysis and metrics.

### 3. Architecture Documents and Registry Anchors

- **Location**: `docs/architecture/01_runtime_ownership.md:58`
- **Description**: Runtime ownership documentation lists owners for Public API, DocumentStoreKernel, FrameFactsPort, SelectionKernel, EditKernel, InteractionEngine, FrameEngine, ResourceKernel, SurfaceResourceSession, SpatialKernel, CodecBoundary, and DiagnosticsHub (`docs/architecture/01_runtime_ownership.md:58`, `docs/architecture/01_runtime_ownership.md:69`).
- **Dependencies**: The document records the ownership model used by runtime/store/edit/selection/codec/diagnostics.
- **Data flow**: Public API/runtime ownership description -> owner responsibility matrix.

- **Location**: `docs/architecture/01_runtime_ownership.md:71`
- **Description**: The same document describes runtime observation ownership through `RuntimeRoot` (`docs/architecture/01_runtime_ownership.md:71`, `docs/architecture/01_runtime_ownership.md:76`), interaction facts through `InteractionReadPort` (`docs/architecture/01_runtime_ownership.md:109`, `docs/architecture/01_runtime_ownership.md:122`), frame facts through `FrameFactsPort -> DocumentStoreKernel` (`docs/architecture/01_runtime_ownership.md:124`, `docs/architecture/01_runtime_ownership.md:140`), and `RuntimeRoot` composition (`docs/architecture/01_runtime_ownership.md:181`, `docs/architecture/01_runtime_ownership.md:199`).
- **Dependencies**: These sections anchor the composition-root shape represented by source imports and diagrams.
- **Data flow**: RuntimeRoot -> store/facts/selection/edit/interaction/frame/spatial/resource/codec/diagnostics owners.

- **Location**: `docs/architecture/02_package_boundaries.md:187`
- **Description**: Package boundary documentation defines source boundary rules (`docs/architecture/02_package_boundaries.md:187`, `docs/architecture/02_package_boundaries.md:192`), consumer fixture boundaries (`docs/architecture/02_package_boundaries.md:203`, `docs/architecture/02_package_boundaries.md:205`), and the forbidden imports matrix (`docs/architecture/02_package_boundaries.md:235`, `docs/architecture/02_package_boundaries.md:248`).
- **Dependencies**: This document is a human-readable source for the boundary guardrails.
- **Data flow**: Package boundary policy -> guardrail rules and consumer fixture expectations.

- **Location**: `docs/contracts/codec_boundary.md:43`
- **Description**: Codec boundary contract states that codec owns schema v1 serialization/deserialization only (`docs/contracts/codec_boundary.md:43`, `docs/contracts/codec_boundary.md:44`), has no runtime/store side effects (`docs/contracts/codec_boundary.md:72`), and decode failure does not call `loadDocument` or mutate runtime/store (`docs/contracts/codec_boundary.md:75`, `docs/contracts/codec_boundary.md:78`).
- **Dependencies**: The contract anchors codec independence from runtime/store while source codec files still import public API DTOs and diagnostics.
- **Data flow**: Encoded document data -> codec DTO validation -> diagnostics without runtime/store mutation.

- **Location**: `docs/contracts/edit_kernel.md:52`
- **Description**: Edit kernel contract records the sequence participants API, EditKernel, Draft, CommitCompiler, CommitApplier, Store, Selection, and Runtime (`docs/contracts/edit_kernel.md:52`, `docs/contracts/edit_kernel.md:89`) and apply-result/runtime seam (`docs/contracts/edit_kernel.md:91`, `docs/contracts/edit_kernel.md:104`).
- **Dependencies**: This anchors edit/store/selection/runtime relationships.
- **Data flow**: Public edit command -> edit kernel/draft/compiler/applier -> store/selection/runtime result.

- **Location**: `docs/contracts/load_document.md:36`
- **Description**: Load document contract states that the public API delegates load orchestration to `RuntimeRoot`, not store (`docs/contracts/load_document.md:36`, `docs/contracts/load_document.md:43`), includes prepared interaction cleanup boundary (`docs/contracts/load_document.md:48`, `docs/contracts/load_document.md:58`), and records success ordering (`docs/contracts/load_document.md:64`, `docs/contracts/load_document.md:82`).
- **Dependencies**: This anchors public API -> runtime root -> load pipeline/store replacement.
- **Data flow**: Public load request -> RuntimeRoot orchestration -> validated replacement document -> runtime/store state.

- **Location**: `docs/architecture/architecture_graph.yaml:456`
- **Description**: The graph defines `api.public_surface.exports_runtime` from public surface to runtime facade (`docs/architecture/architecture_graph.yaml:456`, `docs/architecture/architecture_graph.yaml:468`) and `api.canvas_runtime.composes_runtime_root` from facade to runtime root (`docs/architecture/architecture_graph.yaml:469`, `docs/architecture/architecture_graph.yaml:483`).
- **Dependencies**: These graph edges anchor `api.public_surface -> api.canvas_runtime -> runtime.root`.
- **Data flow**: Public package exports -> CanvasRuntime -> RuntimeRoot.

- **Location**: `docs/architecture/architecture_graph.yaml:484`
- **Description**: Runtime graph edges record `runtime.root.owns_store` (`docs/architecture/architecture_graph.yaml:484`, `docs/architecture/architecture_graph.yaml:496`) and `runtime.root.owns_selection` (`docs/architecture/architecture_graph.yaml:497`, `docs/architecture/architecture_graph.yaml:509`).
- **Dependencies**: These graph edges anchor runtime root composition of store and selection.
- **Data flow**: RuntimeRoot -> DocumentStoreKernel and SelectionKernel.

- **Location**: `docs/architecture/architecture_graph.yaml:556`
- **Description**: Codec graph edges record `codec.schema_v1.uses_public_dto` (`docs/architecture/architecture_graph.yaml:556`, `docs/architecture/architecture_graph.yaml:570`) and `codec.schema_v1.failures.report_to_diagnostics` (`docs/architecture/architecture_graph.yaml:570`, `docs/architecture/architecture_graph.yaml:588`).
- **Dependencies**: These graph edges anchor codec -> public DTO and codec -> diagnostics relationships.
- **Data flow**: Schema v1 codec -> public DTOs -> diagnostics route for failures.

- **Location**: `docs/architecture/architecture_graph.yaml:589`
- **Description**: The graph records `edit.kernel.mutates_store` (`docs/architecture/architecture_graph.yaml:589`, `docs/architecture/architecture_graph.yaml:603`) and `load_document.pipeline.replaces_store_document` (`docs/architecture/architecture_graph.yaml:604`, `docs/architecture/architecture_graph.yaml:616`).
- **Dependencies**: These graph edges anchor edit/load -> store mutation boundaries.
- **Data flow**: Edit/load behavior -> committed document store mutation.

- **Location**: `docs/architecture/architecture_graph.yaml:617`
- **Description**: Future P7 resource graph edges record runtime root ownership of resource kernel (`docs/architecture/architecture_graph.yaml:617`, `docs/architecture/architecture_graph.yaml:631`), resource kernel invalidation of surface session (`docs/architecture/architecture_graph.yaml:632`, `docs/architecture/architecture_graph.yaml:645`), and frame renderer usage of surface resource session (`docs/architecture/architecture_graph.yaml:646`, `docs/architecture/architecture_graph.yaml:659`).
- **Dependencies**: These future edges anchor the P7/P9 resource/session/frame relationships that would be added to the existing graph shape.
- **Data flow**: RuntimeRoot -> ResourceKernel -> SurfaceResourceSession; FrameRenderer -> SurfaceResourceSession.

- **Location**: `docs/architecture/architecture_graph.yaml:841`
- **Description**: The graph has one configured forbidden edge, `codec.schema_v1.forbidden_runtime_dependency`, from codec schema v1 to runtime root (`docs/architecture/architecture_graph.yaml:841`, `docs/architecture/architecture_graph.yaml:852`).
- **Dependencies**: This forbids direct `codec.schema_v1 -> runtime.root` imports.
- **Data flow**: YAML forbidden edge -> phase closure direct forbidden import check.

- **Location**: `docs/_registry/sections.yaml:31`
- **Description**: The registry records the architecture model as a documentation source (`docs/_registry/sections.yaml:31`), links package layout to the architecture model (`docs/_registry/sections.yaml:71`, `docs/_registry/sections.yaml:73`), and registers runtime data model, edit kernel, load document, and codec boundary sections (`docs/_registry/sections.yaml:350`, `docs/_registry/sections.yaml:352`, `docs/_registry/sections.yaml:392`, `docs/_registry/sections.yaml:394`, `docs/_registry/sections.yaml:437`, `docs/_registry/sections.yaml:439`, `docs/_registry/sections.yaml:747`).
- **Dependencies**: The registry anchors docs that describe the same dependency boundaries.
- **Data flow**: Registry entries -> generated documentation indexes/checks.

- **Location**: `docs/_registry/diagrams.yaml:578`
- **Description**: Diagram registry entries register generated architecture graph views sourced from `docs/architecture/architecture_graph.yaml` (`docs/_registry/diagrams.yaml:578`, `docs/_registry/diagrams.yaml:626`).
- **Dependencies**: Generated diagram artifacts are tied to the architecture graph YAML.
- **Data flow**: Architecture graph YAML -> generated Mermaid graph views -> registry.

- **Location**: `docs/indexes/by_phase.md:40`
- **Description**: Generated phase index includes P4/P5/P6 sections that reference runtime spine, edit kernel, and load document work (`docs/indexes/by_phase.md:40`, `docs/indexes/by_phase.md:56`).
- **Dependencies**: The generated index surfaces the same phase-owned documentation.
- **Data flow**: Registry -> generated phase index.

- **Location**: `docs/indexes/by_guardrail.md:80`
- **Description**: Generated guardrail index includes codec, architecture, and load/edit guardrail entries (`docs/indexes/by_guardrail.md:80`, `docs/indexes/by_guardrail.md:88`, `docs/indexes/by_guardrail.md:112`, `docs/indexes/by_guardrail.md:144`, `docs/indexes/by_guardrail.md:184`, `docs/indexes/by_guardrail.md:212`).
- **Dependencies**: The generated index surfaces guardrail ownership for the affected areas.
- **Data flow**: Registry guardrail metadata -> generated guardrail index.

### 4. Diagram and Generated View Anchors

- **Location**: `docs/diagrams/c4_component_runtime.mmd:28`
- **Description**: Runtime component diagram shows `PublicAPI -> RuntimeRoot`, `RuntimeRoot -> DocumentStoreKernel/SelectionKernel/EditKernel`, and runtime root links to ResourceKernel, SurfaceResourceSession, CodecBoundary, and DiagnosticsHub (`docs/diagrams/c4_component_runtime.mmd:28`, `docs/diagrams/c4_component_runtime.mmd:41`). It also shows `CodecBoundary -> DiagnosticsHub` (`docs/diagrams/c4_component_runtime.mmd:69`).
- **Dependencies**: This diagram anchors the runtime composition and codec/diagnostics route.
- **Data flow**: Public API -> RuntimeRoot -> store/selection/edit/resources/codec/diagnostics.

- **Location**: `docs/diagrams/c4_container.mmd:2`
- **Description**: Container diagram shows public export/surface to runtime root and runtime components (`docs/diagrams/c4_container.mmd:2`, `docs/diagrams/c4_container.mmd:16`) and interaction-to-edit flow (`docs/diagrams/c4_container.mmd:21`).
- **Dependencies**: This diagram anchors the high-level container dependency shape.
- **Data flow**: Public API -> RuntimeRoot -> store/frame facts/selection/edit/resource/codec/diagnostics.

- **Location**: `docs/diagrams/c4_code_edit_kernel.mmd:19`
- **Description**: Edit kernel code diagram shows PublicAPI -> RuntimeRoot, RuntimeRoot -> EditSession, EditSession -> Store, compiler/applier -> Store, and applier -> Selection/Store/Diagnostics (`docs/diagrams/c4_code_edit_kernel.mmd:19`, `docs/diagrams/c4_code_edit_kernel.mmd:33`).
- **Dependencies**: This diagram anchors edit/session/store/selection/diagnostics relationships.
- **Data flow**: Public edit request -> runtime root -> edit session/kernel -> store/selection/diagnostics.

- **Location**: `docs/diagrams/dfd_public_edit.mmd:43`
- **Description**: Public edit DFD records the API/edit/runtime/store/selection flows through subgraphs and transitions (`docs/diagrams/dfd_public_edit.mmd:13`, `docs/diagrams/dfd_public_edit.mmd:45`, `docs/diagrams/dfd_public_edit.mmd:58`, `docs/diagrams/dfd_public_edit.mmd:77`).
- **Dependencies**: This diagram anchors public edit data movement across API, edit, runtime, store, and selection.
- **Data flow**: Public edit input -> edit pipeline -> runtime/store/selection outputs.

- **Location**: `docs/diagrams/dfd_schema_v1_decode_encode.mmd:8`
- **Description**: Schema v1 DFD includes public, codec, and diagnostics areas and records encode/decode/failure flows (`docs/diagrams/dfd_schema_v1_decode_encode.mmd:8`, `docs/diagrams/dfd_schema_v1_decode_encode.mmd:15`, `docs/diagrams/dfd_schema_v1_decode_encode.mmd:38`, `docs/diagrams/dfd_schema_v1_decode_encode.mmd:58`, `docs/diagrams/dfd_schema_v1_decode_encode.mmd:108`).
- **Dependencies**: This diagram anchors codec/public DTO/diagnostics relationships.
- **Data flow**: Public document DTOs <-> schema v1 codec -> diagnostics; no runtime/store mutation path.

- **Location**: `docs/diagrams/seq_schema_v1_decode_encode_order.mmd:7`
- **Description**: Schema sequence diagram includes CodecBoundary, DiagnosticsHub, RuntimeRoot, and DocumentStoreKernel participants (`docs/diagrams/seq_schema_v1_decode_encode_order.mmd:7`, `docs/diagrams/seq_schema_v1_decode_encode_order.mmd:12`) and records diagnostics/no runtime-store side-effect points (`docs/diagrams/seq_schema_v1_decode_encode_order.mmd:23`, `docs/diagrams/seq_schema_v1_decode_encode_order.mmd:86`).
- **Dependencies**: This diagram anchors codec side-effect boundaries.
- **Data flow**: Schema decode/encode -> diagnostics route -> explicit absence of runtime/store mutation.

- **Location**: `docs/diagrams/dfd_resource_resolution.mmd:70`
- **Description**: Resource resolution DFD records descriptor/edit/frame/session/resource dirty flows (`docs/diagrams/dfd_resource_resolution.mmd:70`, `docs/diagrams/dfd_resource_resolution.mmd:73`, `docs/diagrams/dfd_resource_resolution.mmd:84`, `docs/diagrams/dfd_resource_resolution.mmd:111`).
- **Dependencies**: This diagram anchors future resource/edit/frame/session relationships.
- **Data flow**: Resource descriptors and edit changes -> resource kernel/session -> frame binding.

- **Location**: `docs/diagrams/seq_resource_resolution.mmd:7`
- **Description**: Resource sequence diagram includes RuntimeRoot, ResourceKernel, FrameFactsPort, Store, and Session participants (`docs/diagrams/seq_resource_resolution.mmd:7`, `docs/diagrams/seq_resource_resolution.mmd:16`) and records runtime/resource/frame/session flows (`docs/diagrams/seq_resource_resolution.mmd:26`, `docs/diagrams/seq_resource_resolution.mmd:61`, `docs/diagrams/seq_resource_resolution.mmd:110`, `docs/diagrams/seq_resource_resolution.mmd:115`).
- **Dependencies**: This diagram anchors P7 resource ownership and session invalidation relationships.
- **Data flow**: RuntimeRoot -> ResourceKernel -> SurfaceResourceSession; frame facts/store -> resource resolution.

- **Location**: `docs/diagrams/dfd_main_paint_frame.mmd:80`
- **Description**: Main paint frame DFD records capture, facts, resource, and session flows (`docs/diagrams/dfd_main_paint_frame.mmd:80`, `docs/diagrams/dfd_main_paint_frame.mmd:88`, `docs/diagrams/dfd_main_paint_frame.mmd:130`, `docs/diagrams/dfd_main_paint_frame.mmd:136`).
- **Dependencies**: This diagram anchors frame/resource/session data movement.
- **Data flow**: Runtime/frame facts -> paint planning -> resource/session binding.

- **Location**: `docs/diagrams/dfd_cache_invalidation.mmd:114`
- **Description**: Cache invalidation DFD records cache/revision/session/resource flows (`docs/diagrams/dfd_cache_invalidation.mmd:114`, `docs/diagrams/dfd_cache_invalidation.mmd:126`, `docs/diagrams/dfd_cache_invalidation.mmd:162`, `docs/diagrams/dfd_cache_invalidation.mmd:206`).
- **Dependencies**: This diagram anchors resource/session invalidation and revision relationships.
- **Data flow**: Edit/load/resource changes -> revision/cache/session invalidation.

- **Location**: `docs/diagrams/generated/current_phase.mmd:1`
- **Description**: Generated current phase graph states it is generated from `docs/architecture/architecture_graph.yaml` for phase P6 (`docs/diagrams/generated/current_phase.mmd:1`, `docs/diagrams/generated/current_phase.mmd:4`) and includes edges such as `api_canvas_runtime -> runtime_root`, `codec_schema_v1 -> diagnostics_hub`, `codec_schema_v1 -> api_public_surface`, `edit_kernel -> store_document_kernel`, and `runtime_root -> selection_kernel/store_document_kernel` (`docs/diagrams/generated/current_phase.mmd:17`, `docs/diagrams/generated/current_phase.mmd:26`).
- **Dependencies**: This generated view anchors the current selected-phase graph.
- **Data flow**: Architecture graph YAML -> current phase Mermaid graph.

- **Location**: `docs/diagrams/generated/full_architecture.mmd:1`
- **Description**: Generated full architecture graph states it is generated from `docs/architecture/architecture_graph.yaml` (`docs/diagrams/generated/full_architecture.mmd:1`, `docs/diagrams/generated/full_architecture.mmd:4`) and includes nodes/edges for current and future graph relationships (`docs/diagrams/generated/full_architecture.mmd:25`, `docs/diagrams/generated/full_architecture.mmd:46`).
- **Dependencies**: This generated view anchors the full expected architecture graph.
- **Data flow**: Architecture graph YAML -> full Mermaid graph.

- **Location**: `docs/diagrams/generated/future_target.mmd:1`
- **Description**: Generated future target graph states it is generated from `docs/architecture/architecture_graph.yaml` (`docs/diagrams/generated/future_target.mmd:1`, `docs/diagrams/generated/future_target.mmd:5`) and includes future runtime/frame/resource edges (`docs/diagrams/generated/future_target.mmd:17`, `docs/diagrams/generated/future_target.mmd:28`).
- **Dependencies**: This generated view anchors planned future graph relationships.
- **Data flow**: Architecture graph YAML -> future target Mermaid graph.

- **Location**: `docs/diagrams/generated/actual_vs_expected_diff.mmd:1`
- **Description**: Generated actual-vs-expected graph states it is generated from `docs/architecture/architecture_graph.yaml` (`docs/diagrams/generated/actual_vs_expected_diff.mmd:1`, `docs/diagrams/generated/actual_vs_expected_diff.mmd:5`) and includes expected/diff edges (`docs/diagrams/generated/actual_vs_expected_diff.mmd:17`, `docs/diagrams/generated/actual_vs_expected_diff.mmd:28`).
- **Dependencies**: This generated view anchors current expected-vs-actual visualization.
- **Data flow**: Architecture graph YAML and actual graph facts -> generated diff view.

- **Location**: `docs/diagrams/generated/release_verification.mmd:1`
- **Description**: Generated release verification graph states it is generated from `docs/architecture/architecture_graph.yaml` (`docs/diagrams/generated/release_verification.mmd:1`, `docs/diagrams/generated/release_verification.mmd:6`).
- **Dependencies**: This generated view is part of the generated graph view set registered from the architecture graph.
- **Data flow**: Architecture graph YAML -> release verification Mermaid graph.

### 5. Plan and Design Artifact Anchors

- **Location**: `plan/step_25_architecture_graph_closure_checker.md:250`
- **Description**: Step 25 plan artifact references architecture graph closure behavior and generated views at multiple points (`plan/step_25_architecture_graph_closure_checker.md:250`, `plan/step_25_architecture_graph_closure_checker.md:265`, `plan/step_25_architecture_graph_closure_checker.md:348`, `plan/step_25_architecture_graph_closure_checker.md:397`, `plan/step_25_architecture_graph_closure_checker.md:483`, `plan/step_25_architecture_graph_closure_checker.md:779`).
- **Dependencies**: This plan artifact anchors the architecture graph closure/checking implementation path.
- **Data flow**: Step contract -> graph closure checker/tooling/tests.

- **Location**: `.design/2026-05-22-architecture-graph-closure-checker.md:149`
- **Description**: Architecture graph closure design artifact records closure-checker design points and expected graph behavior (`.design/2026-05-22-architecture-graph-closure-checker.md:149`, `.design/2026-05-22-architecture-graph-closure-checker.md:162`).
- **Dependencies**: This design artifact anchors why the graph closure checker exists and what it checks.
- **Data flow**: Design artifact -> step contract/tooling implementation.

## Code References

- `lib/src/api/canvas_runtime.dart:22` - public facade imports runtime root.
- `lib/src/runtime/runtime_root.dart:13` - runtime root imports public API types and composes runtime-owned kernels.
- `lib/src/runtime/runtime_config.dart:1` - runtime config imports public API config/value types.
- `lib/src/runtime/document_facts_port.dart:1` - runtime fact port imports public API document/value types.
- `lib/src/edit/edit_kernel.dart:5` - edit kernel imports public runtime/document types.
- `lib/src/edit/draft_document.dart:12` - draft document imports public runtime DTOs and store owners.
- `lib/src/edit/edit_session.dart:13` - edit session imports public runtime types and store state.
- `lib/src/edit/staged_document_load.dart:4` - load staging imports codec, diagnostics, and store.
- `lib/src/edit/commit_applier.dart:2` - commit application imports store state.
- `lib/src/selection/selection_kernel.dart:4` - selection kernel imports runtime selection ports.
- `lib/src/store/document_store_kernel.dart:8` - store kernel imports public API document/fact/projection/revision types.
- `lib/src/store/committed_document.dart:1` - committed document imports public document/id/metadata types.
- `lib/src/api/canvas_codec.dart:3` - public codec facade imports schema v1 codec implementation.
- `lib/src/codec/schema_v1_decoder.dart:8` - schema decoder imports public DTOs and diagnostics.
- `lib/src/codec/schema_v1_encoder.dart:7` - schema encoder imports public DTOs and diagnostics.
- `lib/src/codec/validated_import_draft.dart:1` - validated import draft imports public DTOs and diagnostics.
- `lib/src/diagnostics/diagnostics_hub.dart:1` - diagnostics hub imports public diagnostic/error DTOs.
- `tool/guardrails/src/public_api_import_cycle_checks.dart:36` - cycle checker filters to public API sources only.
- `tool/guardrails/src/core_boundary_checks.dart:592` - boundary checker allows `CanvasRuntime -> RuntimeRoot`.
- `tool/architecture_graph/src/phase_closure.dart:253` - phase closure checks configured forbidden direct imports.
- `docs/architecture/architecture_graph.yaml:469` - architecture graph records facade-to-runtime-root composition.
- `docs/architecture/architecture_graph.yaml:617` - architecture graph records future P7 resource ownership edge.

## Observed Architecture Facts

- Current production imports form module-level cycles through direct edges `api -> runtime`, `runtime -> api`, `runtime -> edit`, `edit -> api`, `runtime -> selection`, `selection -> runtime`, `runtime -> store`, `store -> api`, `api -> codec`, `codec -> api`, `codec -> diagnostics`, and `diagnostics -> api`, with the direct import anchors listed in "Production Source Import Anchors".
- The current repository-local cycle guardrail is scoped to cycles inside `lib/src/api/**` (`tool/guardrails/src/public_api_import_cycle_checks.dart:36`, `tool/guardrails/src/public_api_import_cycle_checks.dart:50`).
- The source-boundary guardrail contains an explicit exception for `lib/src/api/canvas_runtime.dart` importing `lib/src/runtime/runtime_root.dart` (`tool/guardrails/src/core_boundary_checks.dart:592`, `tool/guardrails/src/core_boundary_checks.dart:594`).
- The architecture graph records expected edges for facade/runtime composition, runtime/store/selection ownership, codec/public DTO usage, codec/diagnostics reporting, edit/store mutation, load/store replacement, and future P7 resource/session relationships (`docs/architecture/architecture_graph.yaml:456`, `docs/architecture/architecture_graph.yaml:659`).
- Generated graph diagrams are sourced from `docs/architecture/architecture_graph.yaml` and are registered under `docs/_registry/diagrams.yaml:578`.

## Open Questions

- Which future design should own the public runtime construction boundary currently represented by `lib/src/api/canvas_runtime.dart:22` and the allowed exception in `tool/guardrails/src/core_boundary_checks.dart:592`?
- Which package/module should own public DTO/value types currently imported by runtime, edit, store, codec, and diagnostics?
- Should architecture graph closure continue to enforce only configured direct forbidden imports, or should a later design introduce repository-local module-cycle enforcement?
