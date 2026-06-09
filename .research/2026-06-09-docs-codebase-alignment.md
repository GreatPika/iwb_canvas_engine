---
date: 2026-06-09
researcher: Codex
commit: aa2d372c
branch: new-architecture
research_question: "How does the current docs/ documentation correspond to the codebase, where does it still mention old/new or legacy API history, and where is it still not fully English?"
---

# Research: Docs Codebase Alignment

## Summary

The current documentation system is mechanically structured around registries and generated navigation. `docs/README.md` names `docs/_registry/` as structured relationships and `docs/indexes/` plus `docs/diagrams/catalog.md` as generated navigation (`docs/README.md:27`, `docs/README.md:28`). The documented checks are `dart run docs/tool/sync_generated_docs.dart --check`, `dart run docs/tool/check_docs.dart`, and the architecture graph generated-view check (`docs/README.md:38`, `docs/README.md:39`, `docs/README.md:40`, `docs/README.md:41`, `docs/README.md:42`). In this checkout, `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` both passed.

Russian prose is concentrated in six documentation files. The direct sources are `docs/architecture/00_architecture_overview.md`, `docs/architecture/01_runtime_ownership.md`, `docs/contracts/public_api_v1.md`, and `docs/_registry/sections.yaml`; generated Russian text in `docs/indexes/by_owner.md` and `docs/indexes/by_subsystem.md` is derived from registry section titles (`docs/_registry/sections.yaml:4`, `docs/_registry/sections.yaml:31`, `docs/_registry/sections.yaml:91`; `docs/indexes/by_owner.md:8`, `docs/indexes/by_owner.md:9`, `docs/indexes/by_owner.md:19`; `docs/indexes/by_subsystem.md:19`, `docs/indexes/by_subsystem.md:47`). `rg -n "[А-Яа-яЁё]" docs/diagrams` found no Cyrillic prose in Mermaid diagrams.

Legacy and retired terminology remains present in prose, registries, guardrail documentation, and diagrams. Some of it is historical narrative, especially `docs/architecture/00_architecture_overview.md:34` through `docs/architecture/00_architecture_overview.md:59`. Some of it is current machine-enforced negative contract surface: `docs/_registry/public_api_v1.yaml` owns `retired_public_exports` (`docs/_registry/public_api_v1.yaml:114`), public API documentation states those retired names are not exported (`docs/contracts/public_api_v1.md:97`, `docs/contracts/public_api_v1.md:98`, `docs/contracts/public_api_v1.md:99`), and guardrail docs describe checks for retired public exports and retired load routes (`docs/verification/guardrails.md:177`, `docs/verification/guardrails.md:179`).

## Detailed Findings

### 1. Documentation Generation And Registry Ownership

- **Location**: `docs/tool/sync_generated_docs.dart:120`; related registry inputs at `docs/tool/sync_generated_docs.dart:5`, `docs/tool/sync_generated_docs.dart:6`.
- **Description**: `_syncGeneratedDocs` loads section and diagram registries, syncs the diagram catalog, and renders generated indexes (`docs/tool/sync_generated_docs.dart:130`, `docs/tool/sync_generated_docs.dart:131`, `docs/tool/sync_generated_docs.dart:133`, `docs/tool/sync_generated_docs.dart:139`). It delegates context capsule generation and architecture graph view generation (`docs/tool/sync_generated_docs.dart:150`, `docs/tool/sync_generated_docs.dart:153`, `docs/tool/sync_generated_docs.dart:158`).
- **Dependencies**: Section rows come from `docs/_registry/sections.yaml`; diagram rows come from `docs/_registry/diagrams.yaml` (`docs/tool/sync_generated_docs.dart:5`, `docs/tool/sync_generated_docs.dart:6`).
- **Data flow**: Registry YAML -> generated context capsules, diagram catalog, and seven generated indexes. The seven index targets are hardcoded (`docs/tool/sync_generated_docs.dart:14`, `docs/tool/sync_generated_docs.dart:15`, `docs/tool/sync_generated_docs.dart:16`, `docs/tool/sync_generated_docs.dart:17`, `docs/tool/sync_generated_docs.dart:18`, `docs/tool/sync_generated_docs.dart:19`, `docs/tool/sync_generated_docs.dart:20`, `docs/tool/sync_generated_docs.dart:21`, `docs/tool/sync_generated_docs.dart:22`) and rendered from the loaded section list (`docs/tool/sync_generated_docs.dart:356`, `docs/tool/sync_generated_docs.dart:357`, `docs/tool/sync_generated_docs.dart:358`, `docs/tool/sync_generated_docs.dart:359`, `docs/tool/sync_generated_docs.dart:360`, `docs/tool/sync_generated_docs.dart:361`, `docs/tool/sync_generated_docs.dart:362`, `docs/tool/sync_generated_docs.dart:363`, `docs/tool/sync_generated_docs.dart:364`).

### 2. Documentation Checks

- **Location**: `docs/tool/check_docs.dart:108`.
- **Description**: The docs checker runs required entrypoint checks, active route policy checks, portal README checks, generated docs parity, generated index validation, section reference checks, diagram catalog checks, benchmark docs projection, Markdown path checks, and must-read graph checks (`docs/tool/check_docs.dart:109`, `docs/tool/check_docs.dart:110`, `docs/tool/check_docs.dart:111`, `docs/tool/check_docs.dart:113`, `docs/tool/check_docs.dart:114`, `docs/tool/check_docs.dart:120`, `docs/tool/check_docs.dart:121`, `docs/tool/check_docs.dart:122`, `docs/tool/check_docs.dart:123`, `docs/tool/check_docs.dart:124`).
- **Dependencies**: It loads YAML (`docs/tool/check_docs.dart:11`) and benchmark manifest/report helpers (`docs/tool/check_docs.dart:13`, `docs/tool/check_docs.dart:14`).
- **Data flow**: Documentation and registry files -> structural validation. Generated parity is checked by running `dart run docs/tool/sync_generated_docs.dart --check` (`docs/tool/check_docs.dart:550`, `docs/tool/check_docs.dart:551`, `docs/tool/check_docs.dart:552`, `docs/tool/check_docs.dart:553`, `docs/tool/check_docs.dart:554`, `docs/tool/check_docs.dart:555`, `docs/tool/check_docs.dart:556`, `docs/tool/check_docs.dart:557`, `docs/tool/check_docs.dart:558`, `docs/tool/check_docs.dart:559`, `docs/tool/check_docs.dart:560`, `docs/tool/check_docs.dart:561`).
- **Current verification**: `dart run docs/tool/sync_generated_docs.dart --check` printed `Context capsule check passed.` and `Generated docs check passed.`; `dart run docs/tool/check_docs.dart` printed `Docs check passed.`

### 3. Russian Prose In Current Docs

- **Location**: registry title sources at `docs/_registry/sections.yaml:4`, `docs/_registry/sections.yaml:31`, `docs/_registry/sections.yaml:91`.
- **Description**: `docs/_registry/sections.yaml` contains Russian section titles for status/scope, architecture model, and public API v1. Those titles appear in generated indexes (`docs/indexes/by_owner.md:8`, `docs/indexes/by_owner.md:9`, `docs/indexes/by_owner.md:19`; `docs/indexes/by_subsystem.md:19`, `docs/indexes/by_subsystem.md:47`).
- **Dependencies**: Generated index text is rendered from section titles (`docs/tool/sync_generated_docs.dart:661`, `docs/tool/sync_generated_docs.dart:662`).
- **Data flow**: `docs/_registry/sections.yaml` title fields -> `docs/tool/sync_generated_docs.dart` -> generated index bullets.

- **Location**: `docs/architecture/00_architecture_overview.md:34`.
- **Description**: `docs/architecture/00_architecture_overview.md` contains Russian prose for the v1 boundary, prior model replacement, fixed decision, functional oracle wording, forbidden package contents, and app adapter boundary (`docs/architecture/00_architecture_overview.md:34`, `docs/architecture/00_architecture_overview.md:35`, `docs/architecture/00_architecture_overview.md:37`, `docs/architecture/00_architecture_overview.md:41`, `docs/architecture/00_architecture_overview.md:42`, `docs/architecture/00_architecture_overview.md:43`, `docs/architecture/00_architecture_overview.md:44`, `docs/architecture/00_architecture_overview.md:45`, `docs/architecture/00_architecture_overview.md:46`, `docs/architecture/00_architecture_overview.md:47`, `docs/architecture/00_architecture_overview.md:48`, `docs/architecture/00_architecture_overview.md:51`, `docs/architecture/00_architecture_overview.md:55`, `docs/architecture/00_architecture_overview.md:56`, `docs/architecture/00_architecture_overview.md:57`, `docs/architecture/00_architecture_overview.md:58`, `docs/architecture/00_architecture_overview.md:59`, `docs/architecture/00_architecture_overview.md:77`, `docs/architecture/00_architecture_overview.md:81`, `docs/architecture/00_architecture_overview.md:88`, `docs/architecture/00_architecture_overview.md:100`, `docs/architecture/00_architecture_overview.md:101`, `docs/architecture/00_architecture_overview.md:102`, `docs/architecture/00_architecture_overview.md:103`, `docs/architecture/00_architecture_overview.md:104`, `docs/architecture/00_architecture_overview.md:105`).
- **Dependencies**: The file is registered as `section_00_status_and_scope` (`docs/_registry/sections.yaml:1`, `docs/_registry/sections.yaml:3`, `docs/_registry/sections.yaml:4`).
- **Data flow**: Manual architecture prose -> section registry title -> generated indexes.

- **Location**: `docs/architecture/01_runtime_ownership.md:33`.
- **Description**: `docs/architecture/01_runtime_ownership.md` contains Russian prose for the library role, app domain location, engine-owned state, and ownership table headings/constraints (`docs/architecture/01_runtime_ownership.md:33`, `docs/architecture/01_runtime_ownership.md:37`, `docs/architecture/01_runtime_ownership.md:38`, `docs/architecture/01_runtime_ownership.md:39`, `docs/architecture/01_runtime_ownership.md:42`, `docs/architecture/01_runtime_ownership.md:43`, `docs/architecture/01_runtime_ownership.md:44`, `docs/architecture/01_runtime_ownership.md:45`, `docs/architecture/01_runtime_ownership.md:46`, `docs/architecture/01_runtime_ownership.md:47`, `docs/architecture/01_runtime_ownership.md:51`, `docs/architecture/01_runtime_ownership.md:53`, `docs/architecture/01_runtime_ownership.md:55`, `docs/architecture/01_runtime_ownership.md:56`, `docs/architecture/01_runtime_ownership.md:58`, `docs/architecture/01_runtime_ownership.md:59`, `docs/architecture/01_runtime_ownership.md:60`, `docs/architecture/01_runtime_ownership.md:63`, `docs/architecture/01_runtime_ownership.md:64`, `docs/architecture/01_runtime_ownership.md:65`, `docs/architecture/01_runtime_ownership.md:66`, `docs/architecture/01_runtime_ownership.md:67`).
- **Dependencies**: The file is registered as `section_02_architecture_model` (`docs/_registry/sections.yaml:29`, `docs/_registry/sections.yaml:30`, `docs/_registry/sections.yaml:31`).
- **Data flow**: Manual architecture prose and registry title -> generated indexes.

- **Location**: `docs/contracts/public_api_v1.md:6`.
- **Description**: `docs/contracts/public_api_v1.md` contains Russian text only in the section title and generated context capsule title lines found by the Cyrillic search (`docs/contracts/public_api_v1.md:6`, `docs/contracts/public_api_v1.md:76`).
- **Dependencies**: The title source is `docs/_registry/sections.yaml:91`.
- **Data flow**: Registry title -> context capsule/title text in the contract document and generated indexes.

### 4. Legacy And Old/New API Narrative

- **Location**: `docs/architecture/00_architecture_overview.md:34`.
- **Description**: The architecture overview states that the document fixes the v1 boundary and replaces a previous model where the new runtime had to preserve the old public API shape (`docs/architecture/00_architecture_overview.md:34`, `docs/architecture/00_architecture_overview.md:35`). It also records a new package, new public API v1, new runtime, functional compatibility with the old engine, no API compatibility with the old engine, no legacy facade, and no old runtime in the delivered artifact (`docs/architecture/00_architecture_overview.md:41`, `docs/architecture/00_architecture_overview.md:42`, `docs/architecture/00_architecture_overview.md:43`, `docs/architecture/00_architecture_overview.md:44`, `docs/architecture/00_architecture_overview.md:45`, `docs/architecture/00_architecture_overview.md:46`, `docs/architecture/00_architecture_overview.md:47`, `docs/architecture/00_architecture_overview.md:48`).
- **Dependencies**: The same file says the old engine is only a functional oracle and not the source of public API shape, not imported, not a fallback, and not wrapped by the runtime (`docs/architecture/00_architecture_overview.md:51`, `docs/architecture/00_architecture_overview.md:55`, `docs/architecture/00_architecture_overview.md:56`, `docs/architecture/00_architecture_overview.md:57`, `docs/architecture/00_architecture_overview.md:58`, `docs/architecture/00_architecture_overview.md:59`).
- **Data flow**: Historical architecture statement -> downstream generated registry/index references through section metadata.

- **Location**: `docs/contracts/public_api_v1.md:97`.
- **Description**: The public API contract says the registry owns `retired_public_exports`; names in that list are retired public symbols from the legacy package and are not exported by this package (`docs/contracts/public_api_v1.md:97`, `docs/contracts/public_api_v1.md:98`, `docs/contracts/public_api_v1.md:99`). It also says natural concepts may exist under next-owned names while retired public shapes are banned (`docs/contracts/public_api_v1.md:99`, `docs/contracts/public_api_v1.md:100`).
- **Dependencies**: The machine-readable deny-list starts at `docs/_registry/public_api_v1.yaml:114`.
- **Data flow**: Public API contract prose and registry deny-list -> guardrail checks and API contract tests.

- **Location**: `docs/contracts/public_api_v1.md:322`.
- **Description**: The public API contract compares next-owned API concepts to legacy names: `PatchField` is not used (`docs/contracts/public_api_v1.md:322`), and partial updates use `CanvasFieldUpdate`, not legacy `NodePatch` (`docs/contracts/public_api_v1.md:1119`).
- **Dependencies**: `CanvasFieldUpdate` exists as a public contract declaration (`lib/src/contracts/public/canvas_field_update.dart:4`).
- **Data flow**: Public API prose -> exported public declarations via the API facade and root barrel.

- **Location**: `docs/contracts/resources.md:169`.
- **Description**: The resources contract states that legacy `notifySceneChanged()` is replaced by `runtime.resources.markResourceDirty(resourceId)` and `runtime.resources.markAllResourcesDirty()` (`docs/contracts/resources.md:169`, `docs/contracts/resources.md:172`, `docs/contracts/resources.md:173`).
- **Dependencies**: `ResourceKernel` exists at `lib/src/resources/resource_kernel.dart:7`, `RuntimeRoot` exists at `lib/src/runtime/runtime_root.dart:89`, and `SurfaceResourceSession` exists at `lib/src/resources/surface_resource_session.dart:17`.
- **Data flow**: Resource contract prose -> runtime/resource owner implementation.

### 5. Retired Public API Enforcement

- **Location**: `docs/_registry/public_api_v1.yaml:114`.
- **Description**: `retired_public_exports` lists retired names including `NodePatch`, `PatchField`, `SceneBuilder`, `SceneController`, `SceneWriteTxn`, `decodeScene`, `encodeScene`, and related names (`docs/_registry/public_api_v1.yaml:125`, `docs/_registry/public_api_v1.yaml:146`, `docs/_registry/public_api_v1.yaml:151`, `docs/_registry/public_api_v1.yaml:162`, `docs/_registry/public_api_v1.yaml:163`, `docs/_registry/public_api_v1.yaml:172`, `docs/_registry/public_api_v1.yaml:173`).
- **Dependencies**: The registry comment says semantic rules and signatures remain owned by `docs/contracts/public_api_v1.md` (`docs/_registry/public_api_v1.yaml:1`, `docs/_registry/public_api_v1.yaml:2`).
- **Data flow**: Registry deny-list -> public API guardrail and API contract tests.

- **Location**: `docs/verification/guardrails.md:177`.
- **Description**: `api.no_retired_public_exports` checks that names in the current retired public export registry are not exported by the root package (`docs/verification/guardrails.md:177`). `api.no_retired_public_load_routes` blocks retired public load shapes such as `CanvasRuntime(initialDocument:)`, `CanvasEditPort.loadDocument(CanvasDocument)`, public `decodeCanvasDocument*` helpers, and public importer/row/prepared payload types (`docs/verification/guardrails.md:179`).
- **Dependencies**: Guardrail executor routes public API checks through `_baseViolationChecks` (`tool/guardrails/src/guardrail_executor.dart:440`, `tool/guardrails/src/guardrail_executor.dart:441`).
- **Data flow**: Guardrail registry/docs -> executable guardrail runner -> current source checks.

- **Location**: `tool/guardrails/src/public_api_checks.dart:14`.
- **Description**: `checkPublicExportsComplete()` reads the public API registry and resolved root barrel surface before reporting extra or missing names (`tool/guardrails/src/public_api_checks.dart:14`, `tool/guardrails/src/public_api_checks.dart:15`, `tool/guardrails/src/public_api_checks.dart:16`, `tool/guardrails/src/public_api_checks.dart:17`, `tool/guardrails/src/public_api_checks.dart:18`).
- **Dependencies**: `resolvePublicApiSurface()` resolves `lib/iwb_canvas_engine.dart` by default (`tool/guardrails/src/public_api_surface.dart:24`, `tool/guardrails/src/public_api_surface.dart:25`) and reads the analyzer export namespace (`tool/guardrails/src/public_api_surface.dart:42`, `tool/guardrails/src/public_api_surface.dart:43`, `tool/guardrails/src/public_api_surface.dart:44`).
- **Data flow**: Root barrel export namespace -> exported name set -> comparison with `docs/_registry/public_api_v1.yaml`.

### 6. Current Public API Code Shape

- **Location**: `lib/iwb_canvas_engine.dart:1`.
- **Description**: The root barrel exports API facade files from `lib/src/api`, including actions, codec, diagnostics, document, element, element update, errors, field update, geometry, ids, metadata, pointer, preview, resource, runtime, surface, text editing, and tools (`lib/iwb_canvas_engine.dart:1`, `lib/iwb_canvas_engine.dart:2`, `lib/iwb_canvas_engine.dart:3`, `lib/iwb_canvas_engine.dart:4`, `lib/iwb_canvas_engine.dart:5`, `lib/iwb_canvas_engine.dart:6`, `lib/iwb_canvas_engine.dart:7`, `lib/iwb_canvas_engine.dart:8`, `lib/iwb_canvas_engine.dart:9`, `lib/iwb_canvas_engine.dart:10`, `lib/iwb_canvas_engine.dart:11`, `lib/iwb_canvas_engine.dart:12`, `lib/iwb_canvas_engine.dart:13`, `lib/iwb_canvas_engine.dart:14`, `lib/iwb_canvas_engine.dart:15`, `lib/iwb_canvas_engine.dart:16`, `lib/iwb_canvas_engine.dart:17`, `lib/iwb_canvas_engine.dart:18`).
- **Dependencies**: The public API contract says the root package exports exactly the names listed in the public API registry (`docs/contracts/public_api_v1.md:80`, `docs/contracts/public_api_v1.md:82`, `docs/contracts/public_api_v1.md:85`).
- **Data flow**: `lib/iwb_canvas_engine.dart` -> API facade wrappers -> public contract declarations and selected surface implementation.

- **Location**: `lib/src/api/canvas_runtime.dart:27`.
- **Description**: `CanvasRuntime` exists as a current public API declaration wrapper/implementation (`lib/src/api/canvas_runtime.dart:23`, `lib/src/api/canvas_runtime.dart:27`) and exposes `state` and `edits` (`lib/src/api/canvas_runtime.dart:37`, `lib/src/api/canvas_runtime.dart:38`). `CanvasEditPort.loadDocumentFromJson` exists as a public contract declaration (`lib/src/contracts/public/canvas_runtime.dart:135`, `lib/src/contracts/public/canvas_runtime.dart:138`).
- **Dependencies**: Public compile fixtures use `runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(document))` (`test/api_contract/public_api_v1_compiles_as_written_test.dart:287`).
- **Data flow**: Public runtime -> edit port -> current JSON load surface.

- **Location**: `lib/src/api/canvas_surface.dart:2`.
- **Description**: The API surface exports the surface-owned `CanvasSurface` implementation (`lib/src/api/canvas_surface.dart:2`).
- **Dependencies**: The public API contract records the facade export of `CanvasSurface` (`docs/contracts/public_api_v1.md:524`).
- **Data flow**: API facade -> surface widget implementation.

### 7. Non-Public Contract Legacy Mentions And Owner Alignment

- **Location**: `docs/contracts/edit_kernel.md:36`.
- **Description**: The edit contract says not to assume legacy `SceneWriteTxn` or a legacy controller shell (`docs/contracts/edit_kernel.md:36`, `docs/contracts/edit_kernel.md:37`). `EditKernel` exists at `lib/src/edit/edit_kernel.dart:35`; `CommitCompiler` exists at `lib/src/edit/commit_compiler.dart:9`; `CommitApplier` exists at `lib/src/edit/commit_applier.dart:70`; `DocumentStoreKernel` exists at `lib/src/store/document_store_kernel.dart:32`; `RuntimeRoot` exists at `lib/src/runtime/runtime_root.dart:89`.
- **Dependencies**: The document names those owners in its edit session sequence (`docs/contracts/edit_kernel.md:49`, `docs/contracts/edit_kernel.md:51`, `docs/contracts/edit_kernel.md:52`, `docs/contracts/edit_kernel.md:53`, `docs/contracts/edit_kernel.md:54`).
- **Data flow**: Public edit call -> edit session owners -> store/runtime coordination.

- **Location**: `docs/contracts/codec_boundary.md:27`.
- **Description**: The codec boundary says not to assume a legacy `SceneCodec` surface as next API and not to assume schema v7 production read/write (`docs/contracts/codec_boundary.md:27`, `docs/contracts/codec_boundary.md:28`). No `CodecBoundary` symbol was found by the researcher in the requested current code paths; codec functions exist as `encodeSchemaV1Document` and diagnostic recording (`lib/src/codec/schema_v1_encoder.dart:15`, `lib/src/codec/schema_v1_diagnostics.dart:5`).
- **Dependencies**: The document names `CodecBoundary` and schema v1 encode/import validation (`docs/contracts/codec_boundary.md:35`).
- **Data flow**: Schema v1 JSON boundary -> codec implementation functions -> public encode/load surfaces.

- **Location**: `docs/contracts/spatial_kernel.md:34`.
- **Description**: The spatial contract says not to port legacy `Scene` or locator maps (`docs/contracts/spatial_kernel.md:34`). `SpatialKernel` exists under geometry at `lib/src/geometry/spatial_kernel.dart:12`; `TileIndex` exists at `lib/src/geometry/tile_index.dart:14`; `OutlierIndex` exists at `lib/src/geometry/outlier_index.dart:5`; `SpatialQueryResult` exists at `lib/src/geometry/spatial_query_result.dart:3`.
- **Dependencies**: The document names `SpatialKernel`, `TileIndex`, `OutlierIndex`, and spatial query results (`docs/contracts/spatial_kernel.md:43`, `docs/contracts/spatial_kernel.md:44`, `docs/contracts/spatial_kernel.md:46`, `docs/contracts/spatial_kernel.md:108`).
- **Data flow**: Geometry-owned spatial index -> typed spatial query result.

- **Location**: `docs/contracts/interaction_engine.md:92`.
- **Description**: The interaction contract says not to assume a legacy callback graph (`docs/contracts/interaction_engine.md:92`), names retired package paths as forbidden coordinator dependencies (`docs/contracts/interaction_engine.md:299`), and states legacy selected-move repaint behavior that next behavior preserves (`docs/contracts/interaction_engine.md:320`). `InteractionEngine`, `PointerToolCleanupCoordinator`, `MoveMachine`, and `InteractionRequestRegistry` exist in current code (`lib/src/interaction/interaction_engine.dart:33`, `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:3`, `lib/src/interaction/move_machine.dart:12`, `lib/src/interaction/interaction_request_registry.dart:31`).
- **Dependencies**: `CanvasToolPort.handleDoubleTap` is declared in public contracts (`lib/src/contracts/public/canvas_tools.dart:122`) and `RuntimeRoot` delegates double tap into the interaction engine (`lib/src/runtime/runtime_root.dart:1331`, `lib/src/runtime/runtime_root.dart:1333`).
- **Data flow**: Public tool/command interaction -> runtime root -> interaction engine.

- **Location**: `docs/contracts/validation_limits.md:27`.
- **Description**: The validation limits contract says v1 limits intentionally preserve legacy safety limits where a legacy equivalent exists (`docs/contracts/validation_limits.md:27`).
- **Dependencies**: It lists boundary application points for public DTO construction, edit/update construction, schema v1 JSON validation/import, store load preparation, resource upsert, interaction config mutation, and pointer routing (`docs/contracts/validation_limits.md:66`, `docs/contracts/validation_limits.md:79`).
- **Data flow**: Public/JSON/runtime boundary inputs -> validation limits -> accepted or rejected data.

### 8. Diagram Legacy Mentions

- **Location**: `docs/diagrams/state_runtime_lifecycle.mmd:9`.
- **Description**: Runtime lifecycle diagram says no legacy `SceneController`, `NodeSpec`, or `PatchField` entities are involved (`docs/diagrams/state_runtime_lifecycle.mmd:9`).
- **Dependencies**: The diagram is cataloged through `docs/_registry/diagrams.yaml`, and diagram catalog generation is owned by `docs/tool/sync_generated_docs.dart` (`docs/tool/sync_generated_docs.dart:426`, `docs/tool/sync_generated_docs.dart:430`, `docs/tool/sync_generated_docs.dart:433`).
- **Data flow**: Diagram registry -> catalog -> Mermaid diagram content.

- **Location**: `docs/diagrams/state_edit_session.mmd:31`.
- **Description**: Edit session diagram excludes legacy `SceneController`, `SceneWriteTxn`, `NodeSpec`, and `PatchField` (`docs/diagrams/state_edit_session.mmd:31`, `docs/diagrams/state_edit_session.mmd:32`) and states no legacy entities are part of the lifecycle (`docs/diagrams/state_edit_session.mmd:142`).
- **Dependencies**: The diagram appears in generated diagram ownership indexes from section registry relationships (`docs/indexes/by_diagram.md:84`, `docs/indexes/by_diagram.md:88`).
- **Data flow**: Section registry diagram relation -> generated diagram index -> Mermaid content.

- **Location**: `docs/diagrams/seq_hit_test_candidate_resolution.mmd:60`.
- **Description**: Hit-test sequence diagram states legacy `SceneNode` traversal and legacy scene order logic are not normative input (`docs/diagrams/seq_hit_test_candidate_resolution.mmd:60`).
- **Dependencies**: The spatial and geometry contract areas document current geometry/spatial owners (`docs/contracts/geometry.md:35`, `docs/contracts/spatial_kernel.md:43`).
- **Data flow**: Spatial/geometry contracts -> sequence diagram narrative.

- **Location**: `docs/diagrams/dfd_schema_v1_import_encode.mmd:53`.
- **Description**: Schema v1 data-flow diagram includes `LegacySchemaBlocked["No production legacy schema read/write"]` (`docs/diagrams/dfd_schema_v1_import_encode.mmd:53`) and links canonical encoder flow to the blocked legacy schema node (`docs/diagrams/dfd_schema_v1_import_encode.mmd:101`).
- **Dependencies**: Codec boundary contract states no schema v7 read/write in production core (`docs/contracts/codec_boundary.md:28`).
- **Data flow**: Schema v1 import/encode diagram -> codec boundary constraint.

## Code References

- `docs/README.md:27` - identifies `docs/_registry/` as structured relationships.
- `docs/README.md:28` - identifies `docs/indexes/` and `docs/diagrams/catalog.md` as generated navigation.
- `docs/tool/sync_generated_docs.dart:14` - begins the generated index path list.
- `docs/tool/sync_generated_docs.dart:356` - maps generated index paths to section-registry renderers.
- `docs/tool/check_docs.dart:108` - starts docs validation orchestration.
- `docs/tool/check_docs.dart:550` - checks generated docs parity through the sync command.
- `docs/_registry/sections.yaml:4` - Russian section 0 title source.
- `docs/_registry/sections.yaml:31` - Russian section 2 title source.
- `docs/_registry/sections.yaml:91` - Russian public API section title source.
- `docs/architecture/00_architecture_overview.md:35` - old/new public API narrative in Russian.
- `docs/architecture/01_runtime_ownership.md:33` - Russian architecture prose.
- `docs/contracts/public_api_v1.md:97` - retired public exports prose.
- `docs/_registry/public_api_v1.yaml:114` - retired public export deny-list begins.
- `docs/verification/guardrails.md:177` - retired public export guardrail.
- `docs/verification/guardrails.md:179` - retired public load route guardrail.
- `lib/iwb_canvas_engine.dart:1` - root package public export surface begins.
- `lib/src/api/canvas_runtime.dart:27` - current `CanvasRuntime` public API implementation.
- `lib/src/contracts/public/canvas_runtime.dart:138` - current `CanvasEditPort.loadDocumentFromJson`.
- `tool/guardrails/src/public_api_checks.dart:14` - public export completeness check reads registry and surface.
- `tool/guardrails/src/public_api_surface.dart:24` - analyzer-resolved public API surface entrypoint.

## Search Coverage

- Inspected:
  - `docs/README.md`.
  - `docs/tool/generate_context_capsules.dart`, `docs/tool/sync_generated_docs.dart`, `docs/tool/check_docs.dart`.
  - `docs/_registry/sections.yaml`, `docs/_registry/diagrams.yaml`, `docs/_registry/benchmarks.yaml`, `docs/_registry/public_api_v1.yaml`.
  - All seven generated `docs/indexes/*.md` files.
  - `docs/diagrams/catalog.md`.
  - `docs/architecture/00_architecture_overview.md`, `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/03_data_model.md`.
  - All non-public `docs/contracts/*.md` plus focused public API contract ranges in `docs/contracts/public_api_v1.md`.
  - `docs/verification/guardrails.md`, `docs/verification/guardrail_design_patterns.md`, `docs/verification/tests.md`, `docs/verification/release_gates.md`, `docs/verification/benchmarks.md`.
  - `lib/iwb_canvas_engine.dart`, `lib/src/api/*.dart`, `lib/src/contracts/public/*.dart`.
  - Focused owner paths under `lib/src/codec`, `lib/src/diagnostics`, `lib/src/edit`, `lib/src/frame`, `lib/src/geometry`, `lib/src/interaction`, `lib/src/resources`, `lib/src/runtime`, `lib/src/store`, and `lib/src/contracts`.
  - Focused files under `test/api_contract` and `test/guardrails`.
- Searched:
  - `find docs -maxdepth 3 -type f | sort`.
  - `rg -n "[А-Яа-яЁё]" docs -S`.
  - `rg -n "legacy|old API|new API|old public|new public|retired|schema v7|SceneBuilder|PatchField|NodePatch|previous|prior|стар|нов|преж" docs -S`.
  - `rg -n "generated|registry|sections|public_api_v1|sync_generated_docs|check_docs|by_owner|by_subsystem|by_release|by_diagram|by_guardrail|by_test_area|by_benchmark" docs/README.md docs/tool docs/_registry docs/indexes -S`.
  - `rg -n "export 'src/api|export 'src/contracts/public|CanvasRuntime|CanvasSurface|CanvasEditPort|loadDocumentFromJson|NodePatch|PatchField|SceneBuilder|SceneController" lib/iwb_canvas_engine.dart lib/src/api lib/src/contracts/public test/api_contract test/guardrails -S`.
  - `rg -n -i "legacy" docs/diagrams`.
  - `rg -n -i "old api|new api|old-api|new-api|old API|new API|new .*api|old .*api|api.*old|api.*new" docs/diagrams`.
  - `rg -n "PatchField|PatchFieldState|SceneController|SceneControllerInteraction|SceneControllerScene|SceneControllerSelection|CanvasTextEditCandidate|CanvasTextEditToken|decodeCanvasDocument|decodeCanvasDocumentFromJson" lib/iwb_canvas_engine.dart lib/src/api lib/src/contracts/public`.
  - Verification commands: `dart run docs/tool/sync_generated_docs.dart --check`; `dart run docs/tool/check_docs.dart`.
- Not found:
  - `rg -n "[А-Яа-яЁё]" docs/diagrams` found no Cyrillic prose in Mermaid diagrams.
  - `rg -n "[А-Яа-яЁё]" docs/tool/*.dart` found no Cyrillic prose in docs tooling.
  - Exact English phrases `old API`, `new API`, `previous engine`, and `prior engine` were not found under `docs/` in focused searches; old/new API comparison is expressed through Russian text and mixed English/Russian wording in `docs/architecture/00_architecture_overview.md:35` through `docs/architecture/00_architecture_overview.md:48`.
  - `PatchField`, `PatchFieldState`, `SceneController`, `SceneControllerInteraction`, `SceneControllerScene`, `SceneControllerSelection`, `CanvasTextEditCandidate`, `CanvasTextEditToken`, `decodeCanvasDocument`, and `decodeCanvasDocumentFromJson` were not found under `lib/iwb_canvas_engine.dart`, `lib/src/api`, or `lib/src/contracts/public`; these names were observed in docs/tests/tooling as deny-list, negative fixture, or guardrail text.
  - `lib/src/spatial` does not exist; the current `SpatialKernel` declaration is under `lib/src/geometry/spatial_kernel.dart:12`.
- Not inspected:
  - Broader production implementation outside the focused owner paths.
  - Non-requested test areas outside `test/api_contract` and `test/guardrails`.
  - Architecture graph implementation internals under `tool/architecture_graph/`, except through documented generated-view commands and generated docs checks.
  - Benchmark runner internals beyond docs checker imports and benchmark registry projection.

## Observed Architecture Facts

- Registry-backed docs generation: `docs/_registry/sections.yaml` and `docs/_registry/diagrams.yaml` feed generated indexes and diagram catalog through `docs/tool/sync_generated_docs.dart` (`docs/tool/sync_generated_docs.dart:5`, `docs/tool/sync_generated_docs.dart:6`, `docs/tool/sync_generated_docs.dart:356`).
- Public API source-of-truth split: `docs/contracts/public_api_v1.md` owns semantics, while `docs/_registry/public_api_v1.yaml` owns exported-name inventory and retired export deny-list (`docs/_registry/public_api_v1.yaml:1`, `docs/_registry/public_api_v1.yaml:2`, `docs/contracts/public_api_v1.md:82`, `docs/contracts/public_api_v1.md:85`, `docs/contracts/public_api_v1.md:97`).
- Public API enforcement flow: `lib/iwb_canvas_engine.dart` exports API wrappers (`lib/iwb_canvas_engine.dart:1`), analyzer-resolved public surface is collected by `resolvePublicApiSurface()` (`tool/guardrails/src/public_api_surface.dart:24`), and export completeness compares registry data with that surface (`tool/guardrails/src/public_api_checks.dart:14`, `tool/guardrails/src/public_api_checks.dart:15`, `tool/guardrails/src/public_api_checks.dart:16`).
- Current docs checks enforce structure, generated parity, routes, registry references, diagram/catalog symmetry, benchmark docs projection, Markdown path references, and must-read graph cycles (`docs/tool/check_docs.dart:108`, `docs/tool/check_docs.dart:124`).
- Current docs checks do not appear in the inspected code paths as a Cyrillic-language ban or a general ban on legacy narrative; `dart run docs/tool/check_docs.dart` passed while Cyrillic and legacy mentions remain in the searched docs.

## Open Questions

- No additional repository areas were identified as necessary for answering this research question beyond the inspected documentation, public API, guardrail, and focused owner paths.
