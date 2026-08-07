---
date: 2026-05-19
researcher: Codex
commit: f546f39
branch: new-architecture
research_question: "Research the docs-only architecture needed before introducing FrameFactsPort between FrameEngine and DocumentStoreKernel for frame capture facts."
---

# Research: FrameFactsPort Docs Research

## Summary

The current documentation describes `FrameEngine` as the owner of captured main and overlay frames, ordinary paint plans, selection decoration/staging, and repaint buses (`docs/architecture/01_runtime_ownership.md:58`). The documented main frame already has a bounded fact set: document/cache revisions, resource visual revision, view camera facts, viewport/device facts, selection facts/style, and selected-move delta (`docs/contracts/frame_rendering.md:60`). The overlay frame has a smaller fact set centered on preview and view camera facts (`docs/contracts/frame_rendering.md:80`).

The current component diagram still marks `FrameEngine -> DocumentStoreKernel` as an allowed relationship (`docs/diagrams/c4_component_runtime.mmd:35`). Main-paint and resource-resolution sequences also show `FrameEngine` reading committed tables/revisions/resources, resolving candidate handles, and reading descriptor snapshots directly from `DocumentStoreKernel` (`docs/diagrams/seq_main_paint.mmd:19`, `docs/diagrams/seq_main_paint.mmd:42`, `docs/diagrams/seq_main_paint.mmd:73`, `docs/diagrams/seq_resource_resolution.mmd:24`, `docs/diagrams/seq_resource_resolution.mmd:31`). The same docs constrain those reads: paint must not mutate the store, materialize `CanvasDocument`, read `DocumentProjectionCache`, perform public API reads, or let painters live-read runtime (`docs/diagrams/seq_main_paint.mmd:96`, `docs/diagrams/seq_main_paint.mmd:97`).

The existing docs already contain the adjacent boundary pattern for a future frame-facts boundary. The package layout names `document_facts_port.dart` and `selection_facts_port.dart` under `lib/src/runtime/` (`docs/architecture/02_package_boundaries.md:58`, `docs/architecture/02_package_boundaries.md:59`), P4 says later frame/spatial/resource/interaction phases obtain facts through narrow immutable document and selection read/query ports (`docs/implementation/p4_runtime_spine.md:27`), and the P4 exit gate requires later owners to obtain committed and selection facts only through narrow immutable query ports rather than concrete owner tables/internals (`docs/implementation/p4_runtime_spine.md:104`, `docs/implementation/p4_runtime_spine.md:106`).

## Detailed Findings

### 1. Current Frame Capture Contract

- **Location**: primary `docs/contracts/frame_rendering.md:56`; additional references `docs/contracts/frame_rendering.md:60`, `docs/contracts/frame_rendering.md:80`, `docs/diagrams/seq_main_paint.mmd:18`, `docs/diagrams/seq_main_paint.mmd:27`.
- **Description**: `CapturedMainFrame` currently includes `documentRevision`, `structuralRevision`, `boundsRevision`, `elementVisualRevision`, `backgroundRevision`, `gridRevision`, `gridStrokeWidth`, `selectionRevision`, `resourceVisualRevision`, `viewCameraRevision`, `viewCameraOffset`, `viewportRect`, `devicePixelRatio`, `selectionIds`, `selectionStyle`, and `selectedMoveDelta` (`docs/contracts/frame_rendering.md:60`). `CapturedOverlayFrame` includes `previewRevision`, `viewCameraRevision`, `viewCameraOffset`, `previewState`, and `selectionStyle` (`docs/contracts/frame_rendering.md:80`).
- **Dependencies**: The frame rendering contract says it must be read with the runtime data model, resource lifecycle, spatial kernel, and cache policy sections (`docs/contracts/frame_rendering.md:7`, `docs/contracts/frame_rendering.md:11`). P9 lists dependencies on P4 committed tables/revisions/query ports, P5 typed repaint/invalidation effects, P7 `SurfaceResourceSession`, and P8 geometry/spatial candidate lookup (`docs/implementation/p9_frame_rendering_and_caches.md:37`, `docs/implementation/p9_frame_rendering_and_caches.md:42`).
- **Data flow**: Paint request with viewport/device/style/session inputs (`docs/diagrams/seq_main_paint.mmd:18`) -> frame captures store/resource/view-camera/selection/preview facts once (`docs/diagrams/seq_main_paint.mmd:19`, `docs/diagrams/seq_main_paint.mmd:30`) -> frame builds immutable records/assets/caches for the painter (`docs/diagrams/seq_main_paint.mmd:91`).

### 2. Current Direct Store Reads In Frame Paths

- **Location**: primary `docs/diagrams/c4_component_runtime.mmd:35`; additional references `docs/diagrams/seq_main_paint.mmd:19`, `docs/diagrams/seq_main_paint.mmd:42`, `docs/diagrams/seq_main_paint.mmd:73`, `docs/diagrams/dfd_main_paint_frame.mmd:73`, `docs/diagrams/dfd_main_paint_frame.mmd:91`, `docs/diagrams/dfd_main_paint_frame.mmd:117`.
- **Description**: The runtime component diagram declares `FrameEngine -> DocumentStoreKernel` as allowed (`docs/diagrams/c4_component_runtime.mmd:35`). The main paint sequence shows three store read categories: capture committed tables/document revisions/resources once, resolve candidate handles against captured structural revision/generation, and read committed descriptor snapshots by resource id (`docs/diagrams/seq_main_paint.mmd:19`, `docs/diagrams/seq_main_paint.mmd:42`, `docs/diagrams/seq_main_paint.mmd:73`).
- **Dependencies**: `DocumentStoreKernel` owns committed document state, document revisions, resource descriptors, and projection cache (`docs/architecture/01_runtime_ownership.md:54`, `docs/diagrams/c4_component_runtime.mmd:6`). `FrameEngine` owns captured frames, paint plans, and repaint buses (`docs/architecture/01_runtime_ownership.md:58`, `docs/diagrams/c4_component_runtime.mmd:11`).
- **Data flow**: `FrameEngine` capture/read path -> `DocumentStoreKernel` committed tables/revisions/resources (`docs/diagrams/seq_main_paint.mmd:19`) -> immutable row views, descriptor snapshots, or stale rejection (`docs/diagrams/seq_main_paint.mmd:44`, `docs/diagrams/seq_main_paint.mmd:74`) -> render records and paint assets (`docs/diagrams/seq_main_paint.mmd:45`, `docs/diagrams/seq_main_paint.mmd:75`).

### 3. Store Ownership And Projection Boundaries

- **Location**: primary `docs/architecture/03_data_model.md:47`; additional references `docs/architecture/03_data_model.md:62`, `docs/architecture/03_data_model.md:116`, `docs/architecture/03_data_model.md:186`, `docs/verification/guardrails.md:157`, `docs/verification/guardrails.md:159`.
- **Description**: `DocumentStoreKernel` stores compact committed tables, not a live mutable public `CanvasDocument` (`docs/architecture/03_data_model.md:47`). `CommittedDocument` contains metadata, resources, layer/element/family tables, admission, revisions, and projection cache (`docs/architecture/03_data_model.md:49`). Selection is runtime view state owned by `SelectionKernel`, and `CommittedDocument` stores no selected ids, selected order, or selection revision (`docs/architecture/03_data_model.md:62`).
- **Dependencies**: Public runtime state exposes stable public domains `document`, `selection`, `preview`, `viewCamera`, `resourceVisual`, `interaction`, and `epoch`, while internal cache/projection revisions remain private (`docs/architecture/03_data_model.md:132`). The projection policy is tied to `DocumentProjectionCache` and `projectionRevision` (`docs/architecture/03_data_model.md:188`).
- **Data flow**: Committed compact tables (`docs/architecture/03_data_model.md:47`) -> public projection cache only when explicit read/encode/test/tool/draft-read path asks for it (`docs/architecture/03_data_model.md:190`) -> no projection construction in pointer, hit-test, main paint, or overlay paint (`docs/architecture/03_data_model.md:193`, `docs/architecture/03_data_model.md:196`).

### 4. Documented Frame Fact Families

- **Location**: primary `docs/architecture/03_data_model.md:116`; additional references `docs/contracts/frame_rendering.md:60`, `docs/contracts/cache_policy.md:46`, `docs/contracts/cache_policy.md:47`, `docs/diagrams/dfd_cache_invalidation.mmd:30`, `docs/diagrams/dfd_cache_invalidation.mmd:82`.
- **Description**: The runtime data model defines revision families for `documentRevision`, `structuralRevision`, `resourceRevision`, `resourceVisualRevision`, `boundsRevision`, `elementVisualRevision`, `backgroundRevision`, `gridRevision`, `projectionRevision`, and `previewRevision` (`docs/architecture/03_data_model.md:116`). Main frame capture lists the frame-facing subset plus view camera, viewport/device, selection, style, and selected-move facts (`docs/contracts/frame_rendering.md:60`).
- **Dependencies**: `backgroundRevision` and `gridRevision` are internal persisted-document metadata facts; `CanvasSurface.gridStyle` and `CanvasSurface.selectionStyle` are captured paint inputs, not document revision families or public runtime revisions (`docs/architecture/03_data_model.md:154`). `resourceVisualRevision` is runtime resource state owned by ResourceKernel/RuntimeRoot orchestration, not committed document store state (`docs/architecture/03_data_model.md:171`, `docs/architecture/03_data_model.md:175`).
- **Data flow**: Commit/install updates typed revision state (`docs/diagrams/dfd_cache_invalidation.mmd:116`) -> exact revision families drive frame cache/repaint invalidation (`docs/diagrams/dfd_cache_invalidation.mmd:168`, `docs/diagrams/dfd_cache_invalidation.mmd:187`) -> public runtime state receives only public observation domains (`docs/diagrams/dfd_cache_invalidation.mmd:44`, `docs/diagrams/dfd_cache_invalidation.mmd:121`).

### 5. Render Rows And Paint Plan Cache Inputs

- **Location**: primary `docs/contracts/frame_rendering.md:128`; additional references `docs/contracts/frame_rendering.md:146`, `docs/contracts/frame_rendering.md:168`, `docs/contracts/cache_policy.md:47`, `docs/diagrams/dfd_main_paint_frame.mmd:45`, `docs/diagrams/dfd_main_paint_frame.mmd:84`.
- **Description**: Painters receive compact immutable `RenderElementRecord` values, not public `CanvasElement` DTOs (`docs/contracts/frame_rendering.md:128`). Records contain id, family, generation, order token, transform, opacity, paint/hit bounds, optional resource id, and row-specific immutable view (`docs/contracts/frame_rendering.md:132`). Family row views are documented for image, path, text, stroke, line, and rect rows (`docs/contracts/frame_rendering.md:152`).
- **Dependencies**: `PaintPlanCache` stores only ordinary committed `RenderElementRecord` data (`docs/contracts/frame_rendering.md:168`) and its key uses `structuralRevision`, `boundsRevision`, `elementVisualRevision`, `viewportRect`, and `devicePixelRatio` (`docs/contracts/frame_rendering.md:170`, `docs/contracts/cache_policy.md:47`).
- **Data flow**: Spatial candidate handles (`docs/diagrams/seq_main_paint.mmd:38`) -> frame resolves row data by captured structural revision/generation (`docs/diagrams/seq_main_paint.mmd:42`) -> ordinary committed records enter `PaintPlanCache` (`docs/diagrams/seq_main_paint.mmd:52`) -> painter receives immutable records (`docs/diagrams/seq_main_paint.mmd:91`).

### 6. Resource Descriptor Facts In Frame Rendering

- **Location**: primary `docs/contracts/resources.md:54`; additional references `docs/contracts/resources.md:78`, `docs/diagrams/dfd_resource_resolution.mmd:22`, `docs/diagrams/dfd_resource_resolution.mmd:81`, `docs/diagrams/dfd_resource_resolution.mmd:84`, `docs/diagrams/seq_resource_resolution.mmd:31`.
- **Description**: `DocumentStoreKernel` owns resource descriptors as committed document state (`docs/contracts/resources.md:54`). Paint/resource resolution receives immutable descriptor snapshots and `resourceRevision` from an allowed committed-state reader such as `FrameEngine` or `RuntimeRoot` (`docs/contracts/resources.md:78`). The resource module itself must not import, read, or mutate `DocumentStoreKernel` (`docs/contracts/resources.md:80`).
- **Dependencies**: `SurfaceResourceSession` owns resolver reference, `resolverGeneration`, `ImageResolveCache`, per-frame budget, missing/null suppression, and budget follow-up throttle (`docs/contracts/resources.md:69`). `ImageResolveCache` is keyed by `resolverGeneration`, `resourceId`, and `resourceRevision` (`docs/contracts/cache_policy.md:48`).
- **Data flow**: Image render record carries `resourceId` (`docs/diagrams/dfd_resource_resolution.mmd:78`) -> committed descriptor lookup by resource id (`docs/diagrams/dfd_resource_resolution.mmd:81`) -> descriptor snapshot plus `resourceRevision` enters `SurfaceResourceSession` (`docs/diagrams/dfd_resource_resolution.mmd:84`) -> output is a resolved app-owned image or bounded placeholder (`docs/diagrams/dfd_resource_resolution.mmd:96`, `docs/diagrams/dfd_resource_resolution.mmd:99`).

### 7. Existing Query-Port Pattern

- **Location**: primary `docs/implementation/p4_runtime_spine.md:27`; additional references `docs/architecture/02_package_boundaries.md:58`, `docs/architecture/02_package_boundaries.md:59`, `docs/diagrams/c4_component_runtime.mmd:8`, `docs/diagrams/c4_component_runtime.mmd:36`, `docs/architecture/01_runtime_ownership.md:88`, `docs/architecture/01_runtime_ownership.md:93`.
- **Description**: P4 includes narrow immutable document and selection read/query ports for later frame, spatial, resource, and interaction phases (`docs/implementation/p4_runtime_spine.md:27`). The package layout already names `document_facts_port.dart` and `selection_facts_port.dart` under `lib/src/runtime/` (`docs/architecture/02_package_boundaries.md:58`, `docs/architecture/02_package_boundaries.md:59`). The runtime component diagram defines `SelectionFactsPort` as a query boundary for immutable selection facts used by interaction and frame capture (`docs/diagrams/c4_component_runtime.mmd:8`).
- **Dependencies**: Interaction documentation uses the same pattern: committed gesture facts are read through narrow read-only interaction query ports, selection facts through narrow immutable selection query ports, and query results never expose store tables, selection internals, or mutation methods (`docs/contracts/interaction_engine.md:109`, `docs/contracts/interaction_engine.md:115`).
- **Data flow**: Runtime/document and runtime/selection boundaries provide narrow immutable facts (`docs/architecture/02_package_boundaries.md:206`) -> later owners consume those facts instead of concrete store/selection internals (`docs/implementation/p4_runtime_spine.md:104`, `docs/implementation/p4_runtime_spine.md:106`) -> `SelectionFactsPort` is implemented by `SelectionKernel` for frame/interaction selection facts (`docs/diagrams/c4_component_runtime.mmd:36`, `docs/diagrams/c4_component_runtime.mmd:37`).

### 8. Explicitly Excluded Reads And State

- **Location**: primary `docs/diagrams/seq_main_paint.mmd:96`; additional references `docs/diagrams/seq_main_paint.mmd:97`, `docs/diagrams/seq_overlay_paint.mmd:45`, `docs/diagrams/seq_overlay_paint.mmd:47`, `docs/diagrams/dfd_main_paint_frame.mmd:138`, `docs/contracts/diagnostics.md:67`.
- **Description**: Main painter consumes immutable records, resolved assets, and bounded frame render caches (`docs/diagrams/seq_main_paint.mmd:91`). It performs no live runtime reads (`docs/diagrams/seq_main_paint.mmd:96`). Main paint forbids store mutation, `CanvasDocument` projection, `DocumentProjectionCache` reads, public API reads, and `InteractionEngine` mutation (`docs/diagrams/seq_main_paint.mmd:97`).
- **Dependencies**: Overlay paint uses captured frame facts and immutable primitives only (`docs/diagrams/seq_overlay_paint.mmd:42`) and forbids `CanvasDocument` materialization, projection cache reads, store mutation, cache invalidation, repaint scheduling, and action events (`docs/diagrams/seq_overlay_paint.mmd:47`). Diagnostics are internal, sanitized, and cannot expose runtime objects, images, closures, handles, canvases, or full scene dumps (`docs/contracts/diagnostics.md:29`, `docs/contracts/diagnostics.md:76`).
- **Data flow**: Capture boundary freezes frame facts (`docs/diagrams/seq_main_paint.mmd:30`, `docs/diagrams/seq_overlay_paint.mmd:19`) -> painter receives immutable records/primitives/assets (`docs/diagrams/seq_main_paint.mmd:91`, `docs/diagrams/seq_overlay_paint.mmd:42`) -> forbidden reads/effects stay outside painter and paint hot paths (`docs/diagrams/dfd_main_paint_frame.mmd:140`, `docs/diagrams/dfd_overlay_frame.mmd:61`).

### 9. Verification Surface Around Frame Facts

- **Location**: primary `docs/implementation/p9_frame_rendering_and_caches.md:99`; additional references `docs/indexes/by_test_area.md:291`, `docs/indexes/by_test_area.md:362`, `docs/indexes/by_test_area.md:369`, `docs/indexes/by_test_area.md:397`, `docs/indexes/by_guardrail.md:252`, `docs/indexes/by_guardrail.md:398`.
- **Description**: P9 lists planned tests for no projection hot paths, main/overlay capture, no live runtime reads in painters, cache-key shape, capacity/eviction, paint-plan exclusion of preview/selection state, selection owner separation, camera pan preserving ordinary paint plans, and selected supplement staging (`docs/implementation/p9_frame_rendering_and_caches.md:101`, `docs/implementation/p9_frame_rendering_and_caches.md:110`).
- **Dependencies**: Mandatory guardrails include `store.no_public_document_live_state`, `projection.only_explicit_read_paths`, frame paint-plan exclusion rules, cache key rules, resource resolver boundary/budget rules, and diagnostics sanitization (`docs/verification/guardrails.md:157`, `docs/verification/guardrails.md:191`, `docs/verification/guardrails.md:197`).
- **Data flow**: Guardrails and test indexes map architectural facts to planned executable proof: no projection hot path (`docs/indexes/by_test_area.md:291`), main/overlay capture (`docs/indexes/by_test_area.md:362`), no live painter reads (`docs/indexes/by_test_area.md:369`), cache key ownership (`docs/indexes/by_test_area.md:490`), and store projection-only state (`docs/indexes/by_test_area.md:612`).

## Code References

- `docs/architecture/01_runtime_ownership.md:54` - `DocumentStoreKernel` owns committed document state, document revisions, resource descriptors, and projection cache.
- `docs/architecture/01_runtime_ownership.md:58` - `FrameEngine` owns captured frames, ordinary paint plans, selection decoration/staging, and repaint buses.
- `docs/architecture/01_runtime_ownership.md:88` - committed facts for gesture decisions use narrow read-only interaction query boundaries.
- `docs/architecture/02_package_boundaries.md:58` - planned package layout includes `document_facts_port.dart`.
- `docs/architecture/02_package_boundaries.md:59` - planned package layout includes `selection_facts_port.dart`.
- `docs/architecture/02_package_boundaries.md:197` - `lib/src/frame/**` may not import public document projection as paint input.
- `docs/architecture/03_data_model.md:47` - store uses compact committed tables rather than live mutable public `CanvasDocument`.
- `docs/architecture/03_data_model.md:62` - selection state is owned by `SelectionKernel`, not committed document content.
- `docs/architecture/03_data_model.md:116` - revision family list includes document, structural, resource, resource visual, bounds, element visual, background, grid, projection, and preview revisions.
- `docs/architecture/03_data_model.md:186` - public document projection policy begins.
- `docs/contracts/frame_rendering.md:60` - `CapturedMainFrame` field list begins.
- `docs/contracts/frame_rendering.md:80` - `CapturedOverlayFrame` field list begins.
- `docs/contracts/frame_rendering.md:101` - frame rules include capture-once and no live-read/no-projection constraints.
- `docs/contracts/frame_rendering.md:128` - painters receive `RenderElementRecord`, not public `CanvasElement`.
- `docs/contracts/frame_rendering.md:168` - selected supplement staging algorithm starts with ordinary paint plan lookup/cache rules.
- `docs/contracts/resources.md:54` - resource descriptors are committed document state.
- `docs/contracts/resources.md:78` - paint/resource resolution receives immutable descriptor snapshots and `resourceRevision`.
- `docs/contracts/cache_policy.md:46` - `StaticBackgroundCache` key and invalidation row.
- `docs/contracts/cache_policy.md:47` - `PaintPlanCache` key and invalidation row.
- `docs/contracts/cache_policy.md:48` - `ImageResolveCache` key and invalidation row.
- `docs/diagrams/c4_component_runtime.mmd:35` - current diagram allows `FrameEngine -> DocumentStoreKernel`.
- `docs/diagrams/c4_component_runtime.mmd:36` - current diagram allows `FrameEngine -> SelectionFactsPort`.
- `docs/diagrams/seq_main_paint.mmd:19` - main paint captures committed tables, document revisions, and resources from store.
- `docs/diagrams/seq_main_paint.mmd:42` - main paint resolves candidate handles against captured structural revision/generation via store.
- `docs/diagrams/seq_main_paint.mmd:73` - main paint reads descriptor snapshots from store.
- `docs/diagrams/seq_main_paint.mmd:97` - main paint forbidden store/projection/public API/interaction effects.
- `docs/diagrams/dfd_main_paint_frame.mmd:73` - main DFD reads committed frame facts once.
- `docs/diagrams/dfd_main_paint_frame.mmd:117` - main DFD reads descriptor snapshots by committed revision.
- `docs/diagrams/seq_resource_resolution.mmd:24` - resource resolution sequence captures committed main-frame facts from store.
- `docs/diagrams/seq_resource_resolution.mmd:31` - resource resolution sequence reads committed descriptor snapshot and resource revision.
- `docs/implementation/p4_runtime_spine.md:104` - later owners obtain committed facts only through narrow immutable query ports.
- `docs/implementation/p9_frame_rendering_and_caches.md:30` - P9 scope forbids live runtime reads in painters.
- `docs/implementation/p9_frame_rendering_and_caches.md:31` - P9 scope forbids `CanvasDocument` projection in paint.
- `docs/verification/guardrails.md:159` - projection guardrail forbids projection in pointer/hit/paint hot paths.
- `docs/verification/guardrails.md:185` - background/grid/view camera changes must not invalidate ordinary element paint plans.
- `docs/indexes/by_test_area.md:397` - planned camera-pan test covers ordinary paint-plan preservation with background/grid static invalidation.

## Observed Architecture Facts

- Pattern observed: committed document facts and selection facts already have a narrow immutable query-port pattern in P4 and package layout references (`docs/implementation/p4_runtime_spine.md:27`, `docs/architecture/02_package_boundaries.md:58`, `docs/architecture/02_package_boundaries.md:59`).
- Pattern observed: `SelectionFactsPort` is a named query boundary for immutable selection facts used by interaction and frame capture (`docs/diagrams/c4_component_runtime.mmd:8`, `docs/diagrams/c4_component_runtime.mmd:36`).
- Data flow: `FrameEngine` currently reads committed frame facts from `DocumentStoreKernel`, builds `CapturedMainFrame`, looks up or builds `PaintPlanCache`, resolves resource descriptor snapshots through committed state, and sends immutable records/assets to the painter (`docs/diagrams/seq_main_paint.mmd:19`, `docs/diagrams/seq_main_paint.mmd:32`, `docs/diagrams/seq_main_paint.mmd:73`, `docs/diagrams/seq_main_paint.mmd:91`).
- Data flow: resource descriptor ownership is split from resolved image ownership; descriptors live in committed store, while `SurfaceResourceSession` owns resolver/cache/budget behavior (`docs/contracts/resources.md:54`, `docs/contracts/resources.md:69`, `docs/diagrams/dfd_resource_resolution.mmd:84`).
- Key dependencies: ordinary paint-plan identity is based on `structuralRevision`, `boundsRevision`, `elementVisualRevision`, `viewportRect`, and `devicePixelRatio`; it excludes background/grid/view camera/preview/selection/style-only facts (`docs/contracts/frame_rendering.md:170`, `docs/contracts/frame_rendering.md:172`, `docs/contracts/cache_policy.md:65`).
- Key exclusions: public `CanvasDocument` projection is limited to explicit read/encode/test/tool/draft-read paths and is never built in pointer move, hit-test, main paint, or overlay paint (`docs/architecture/03_data_model.md:190`, `docs/architecture/03_data_model.md:197`).
- Key exclusions: diagnostics public projection is sanitized and bounded; diagnostics cannot expose runtime objects, handles, images, closures, canvases, or full scene dumps (`docs/contracts/diagnostics.md:67`, `docs/contracts/diagnostics.md:76`).
- Verification mapping: current indexes connect no-projection, frame capture, no live painter reads, paint-plan exclusion, cache-key ownership, and store projection-only rules to planned tests and guardrails (`docs/indexes/by_test_area.md:291`, `docs/indexes/by_test_area.md:362`, `docs/indexes/by_test_area.md:390`, `docs/indexes/by_test_area.md:490`, `docs/indexes/by_test_area.md:612`).

## Open Questions

- The docs inspected for this research do not define a named `FrameFactsPort` owner or file. The nearest existing documented names are `document_facts_port.dart`, `selection_facts_port.dart`, and `SelectionFactsPort` (`docs/architecture/02_package_boundaries.md:58`, `docs/architecture/02_package_boundaries.md:59`, `docs/diagrams/c4_component_runtime.mmd:8`).
- The current C4 component diagram simultaneously documents `FrameEngine -> DocumentStoreKernel` and `FrameEngine -> SelectionFactsPort` as allowed relationships (`docs/diagrams/c4_component_runtime.mmd:35`, `docs/diagrams/c4_component_runtime.mmd:36`).
- The main paint sequence currently separates selection facts through `SelectionFactsPort` but keeps committed row/revision/resource and descriptor reads as direct `FrameEngine -> Store` messages (`docs/diagrams/seq_main_paint.mmd:19`, `docs/diagrams/seq_main_paint.mmd:25`, `docs/diagrams/seq_main_paint.mmd:42`, `docs/diagrams/seq_main_paint.mmd:73`).
- The resource contract allows committed descriptor snapshots to come from an allowed committed-state reader such as `FrameEngine` or `RuntimeRoot`; it does not name a dedicated frame facts boundary for descriptor snapshots (`docs/contracts/resources.md:78`).
- The package layout already contains `document_facts_port.dart`, but the researched docs do not specify whether frame capture committed facts are owned by that port, by a future frame-specific port, or by a different runtime boundary (`docs/architecture/02_package_boundaries.md:58`, `docs/implementation/p4_runtime_spine.md:104`).
