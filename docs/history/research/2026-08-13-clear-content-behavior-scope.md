---
date: 2026-08-13
researcher: Codex
commit: b9e2ddab
branch: main
research_question: "Determine the complete current owner and test surface of clearContent for layer-only clearing, background/backgroundElements preservation, and resource retention."
---

# Research: Clear Content Behavior Scope

## Scope

This research records the present `clearContent` behavior and the code, contract, and test locations that own it. It covers materialized editing, sparse editing and storage, command routing, resource-reference handling, commit effects, and existing regression coverage.

## Summary

`clearContent` currently removes both `backgroundElements` and elements in ordinary layers. It leaves `CanvasBackground` metadata untouched, so the background color and grid are not assigned by either clear path. The materialized and sparse-store implementations remove every resource when `removeUnusedResources` is true, without testing whether a background or layer element still references that resource. `isDeletable` is not read by the edit clear paths; the command-facts adapter also currently enumerates background and non-deletable elements for clear.

The behavior is implemented twice: once in the materialized `DraftDocument` path and once in the sparse `EditSession` / `DocumentStoreKernel` path. The two paths converge into the same generic touched-set, commit, delivery, and spatial machinery. The generic machinery has no separate `clearContent` branch.

## Current Behavior and Owners

### Public and command surfaces

- `CanvasEdit.clearContent` exposes `removeUnusedResources`, defaulting to `false`; `CanvasCommandPort.clearContent` also accepts an optional timestamp. `CanvasClearResult` contains immutable removed-element IDs, removed-resource IDs, and `didClearContent`. `lib/src/contracts/public/canvas_runtime.dart:145`, `lib/src/contracts/public/canvas_runtime.dart:163`, `lib/src/contracts/public/canvas_runtime.dart:183`, `lib/src/contracts/public/canvas_runtime.dart:191`
- `RuntimeRoot.clearContentByCommand` obtains clear facts, returns a no-op when both returned ID lists are empty, and otherwise invokes `edit.clearContent` through `EditKernel`. It adds `ClearContentActionIntent` only when the resulting removed-element list is non-empty. `lib/src/runtime/runtime_root.dart:989`, `lib/src/runtime/runtime_root.dart:1012`
- `RuntimeCommandFactsAdapter.clearContentFacts` enumerates every resolvable frame handle without filtering on location kind, `isDeletable`, or `isLocked`. With `removeUnusedResources` it also enumerates every resource-catalog ID. `lib/src/runtime/runtime_command_facts_adapter.dart:87`, `lib/src/runtime/runtime_command_facts_adapter.dart:88`, `lib/src/runtime/runtime_command_facts_adapter.dart:94`
- `ClearContentFacts` retains immutable clear candidate lists together with the document summary. `lib/src/contracts/internal/command_facts_port.dart:40`, `lib/src/contracts/internal/command_facts_port.dart:45`, `lib/src/contracts/internal/command_facts_port.dart:48`, `lib/src/contracts/internal/command_facts_port.dart:49`
- `RuntimeActionFinalizer` maps `ClearContentActionIntent` to `CanvasActionType.clearContent` and builds its payload from the removed-element and removed-resource IDs. `lib/src/runtime/runtime_action_finalizer.dart:44`, `lib/src/runtime/runtime_action_finalizer.dart:110`

### Materialized edit path

- `DraftDocument.clearContent` gathers IDs from `backgroundElements` and all ordinary layers, then clears both collections. `lib/src/edit/draft_document.dart:261`, `lib/src/edit/draft_document.dart:346`, `lib/src/edit/draft_document.dart:358`
- `CanvasBackground` is a separate field. `clearContent` does not assign that field or call the background-color and grid setters. `lib/src/edit/draft_document.dart:37`, `lib/src/edit/draft_document.dart:224`, `lib/src/edit/draft_document.dart:233`, `lib/src/edit/draft_document.dart:261`
- `_clearResources` gathers each resource ID and invokes `resources.clear()` when the flag is set. The path does not call the existing `_isResourceReferenced` helper. That helper scans both `backgroundElements` and ordinary-layer elements through `_allElements`. `lib/src/edit/draft_document.dart:369`, `lib/src/edit/draft_document.dart:373`, `lib/src/edit/draft_document.dart:376`, `lib/src/edit/draft_document.dart:469`, `lib/src/edit/draft_document.dart:475`
- Removed background IDs set `backgroundLayerChanged`; removed IDs intersecting the initial selection set a selection touch; element and resource changes contribute their respective revision deltas. `lib/src/edit/draft_document.dart:267`, `lib/src/edit/draft_document.dart:384`, `lib/src/edit/draft_document.dart:397`, `lib/src/edit/draft_document.dart:501`, `lib/src/edit/draft_document.dart:527`
- `DraftDocument.removeElement` also removes a located element without reading `isDeletable`. `lib/src/edit/draft_document.dart:169`, `lib/src/edit/draft_document.dart:174`

### Sparse edit and store path

- `EditSession.clearContent` delegates to `DraftDocument` when a materialized draft exists. Otherwise it builds a sparse candidate. `lib/src/edit/edit_session.dart:142`, `lib/src/edit/edit_session.dart:311`, `lib/src/edit/edit_session.dart:736`, `lib/src/edit/edit_session.dart:742`
- The sparse candidate gathers current background IDs and ordinary-layer IDs into its removed-element list. With the resource flag it gathers every current resource ID. `lib/src/edit/edit_session.dart:772`, `lib/src/edit/edit_session.dart:775`, `lib/src/edit/edit_session.dart:780`, `lib/src/edit/edit_session.dart:783`, `lib/src/edit/edit_session.dart:1064`, `lib/src/edit/edit_session.dart:1071`, `lib/src/edit/edit_session.dart:1089`
- Sparse clear records a replay callback and `StoreSparseClearContent`; it then records removed IDs, a background-layer touch when background IDs were removed, selection touch, and revision deltas. `lib/src/edit/edit_session.dart:789`, `lib/src/edit/edit_session.dart:793`, `lib/src/edit/edit_session.dart:799`, `lib/src/edit/edit_session.dart:833`
- The sparse overlay clears background and content order. It does not assign background, camera, or palette overrides. `lib/src/edit/edit_session.dart:357`, `lib/src/edit/edit_session.dart:359`, `lib/src/edit/edit_session.dart:854`, `lib/src/edit/edit_session.dart:865`
- `SparseEditSessionFacts` already provides `backgroundElementIds`, layer element IDs, resource IDs, and `isResourceReferenced`. Sparse clear uses current resource IDs rather than its `isResourceReferenced` method. `lib/src/edit/edit_session.dart:164`, `lib/src/edit/edit_session.dart:170`, `lib/src/edit/edit_session.dart:172`, `lib/src/edit/edit_session.dart:174`, `lib/src/edit/edit_session.dart:177`, `lib/src/edit/edit_session.dart:783`, `lib/src/edit/edit_session.dart:1025`
- `StoreSparseClearContent` carries only `removeUnusedResources`; it has no element-ID or resource-ID collections. `lib/src/store/sparse_store_commit.dart:97`
- `DocumentStoreKernel` dispatches this mutation to `_clearContent`. The method clears family rows and the element registry structure when elements exist, and clears the entire resource table when the resource flag is set. `lib/src/store/document_store_kernel.dart:673`, `lib/src/store/document_store_kernel.dart:710`, `lib/src/store/document_store_kernel.dart:994`, `lib/src/store/document_store_kernel.dart:1014`, `lib/src/store/document_store_kernel.dart:1018`, `lib/src/store/document_store_kernel.dart:1020`
- `ElementRegistry.clearContentStructure` empties `backgroundElementIds`; `LayerTable.clearElements` separately keeps layer rows and metadata while emptying their element-ID lists. `lib/src/store/element_registry.dart:292`, `lib/src/store/layer_table.dart:337`, `lib/src/store/layer_table.dart:342`
- `FamilyTablesEditor.clearElements` empties seven family buffers and the image/vector reference summaries. Its `referencesResource` method reports a positive combined image/vector reference count. `lib/src/store/family_tables.dart:1075`, `lib/src/store/family_tables.dart:1189`, `lib/src/store/family_tables.dart:1343`, `lib/src/store/family_tables.dart:1375`, `lib/src/store/family_tables.dart:1396`
- `ResourceTable.clear` produces an empty descriptor table. The separate sparse unused-resource mutation checks `familyEditor.referencesResource` before removal. `lib/src/store/resource_table.dart:166`, `lib/src/store/document_store_kernel.dart:961`, `lib/src/store/document_store_kernel.dart:969`, `lib/src/store/document_store_kernel.dart:1020`
- Sparse accepted facts mark full element/resource comparison for clear. Background-layer change is derived from a comparison of background element order. `lib/src/store/document_store_kernel.dart:1274`, `lib/src/store/document_store_kernel.dart:1313`, `lib/src/store/document_store_kernel.dart:1839`, `lib/src/store/document_store_kernel.dart:1943`, `lib/src/store/document_store_kernel.dart:2022`, `lib/src/store/document_store_kernel.dart:2056`, `lib/src/store/document_store_kernel.dart:2485`
- `CommittedDocument` materializes background elements and ordinary layers through `ElementRegistry`, and resources through `ResourceTable`. `DocumentProjectionCache` later materializes a `CanvasDocument` from resource descriptors, background-element IDs, and layer element IDs. `lib/src/store/committed_document.dart:31`, `lib/src/store/committed_document.dart:35`, `lib/src/store/committed_document.dart:44`, `lib/src/store/document_projection_cache.dart:11`, `lib/src/store/document_projection_cache.dart:28`, `lib/src/store/document_projection_cache.dart:33`, `lib/src/store/document_projection_cache.dart:37`

### Commit, delivery, and spatial effects

- `EditKernel` maps accepted sparse facts into `TouchedSet` and then uses `CommitCompiler`; it has no clear-specific commit-routing branch. `lib/src/edit/edit_kernel.dart:186`, `lib/src/edit/edit_kernel.dart:223`, `lib/src/edit/edit_kernel.dart:248`, `lib/src/edit/edit_kernel.dart:255`, `lib/src/edit/edit_kernel.dart:281`
- `TouchedSetBuilder` provides the generic removed-element/resource and background-layer APIs used by clear. `lib/src/edit/touched_set_builder.dart:29`, `lib/src/edit/touched_set_builder.dart:57`, `lib/src/edit/touched_set_builder.dart:69`, `lib/src/edit/touched_set_builder.dart:97`
- `TouchedSet` stores removed-element IDs, resource descriptor and visual IDs, layer IDs, and separate background-layer, background, grid, and selection flags. Its `hasTouches` predicate includes these collections and flags. `lib/src/contracts/internal/touched_set.dart:3`, `lib/src/contracts/internal/touched_set.dart:34`, `lib/src/contracts/internal/touched_set.dart:40`, `lib/src/contracts/internal/touched_set.dart:42`, `lib/src/contracts/internal/touched_set.dart:44`, `lib/src/contracts/internal/touched_set.dart:45`, `lib/src/contracts/internal/touched_set.dart:47`, `lib/src/contracts/internal/touched_set.dart:48`, `lib/src/contracts/internal/touched_set.dart:70`
- `CommitCompiler` requests spatial delivery when layer IDs or `backgroundLayerChanged` are present, and requests resource delivery for a resource revision. `lib/src/edit/commit_compiler.dart:23`, `lib/src/edit/commit_compiler.dart:57`, `lib/src/edit/commit_compiler.dart:70`
- `CommitApplier` installs an accepted document when the revision delta has changes, returns delivery effects only when a document or selection change was accepted, and forwards action intents only when public state is published. `lib/src/edit/commit_applier.dart:85`, `lib/src/edit/commit_applier.dart:100`, `lib/src/edit/commit_applier.dart:111`, `lib/src/edit/commit_applier.dart:115`, `lib/src/edit/commit_applier.dart:119`, `lib/src/edit/commit_applier.dart:169`
- `RuntimeRoot` delivers spatial effects before resource effects. Spatial delivery calls `_spatial.applyTouched`; resource delivery releases the whole resource set for `allResourceVisualsChanged`, or the listed resource IDs otherwise. `lib/src/runtime/runtime_root.dart:1872`, `lib/src/runtime/runtime_root.dart:1984`, `lib/src/runtime/runtime_root.dart:1990`
- `SpatialKernel.applyTouched` resets its index only when there are removals and the current frame has zero elements. When that predicate is false, background-layer or layer touches route to a frame rebuild. `lib/src/geometry/spatial_kernel.dart:67`, `lib/src/geometry/spatial_kernel.dart:75`, `lib/src/geometry/spatial_kernel.dart:184`, `lib/src/geometry/spatial_kernel.dart:198`

## Located File Surface

### Direct implementation owners

The current behavior is owned by the following production files:

- `lib/src/edit/draft_document.dart` — materialized element and resource clearing, result IDs, touched flags, and revision deltas.
- `lib/src/edit/edit_session.dart` — sparse candidate IDs, overlay state, sparse mutation creation, result IDs, touched flags, and revision deltas.
- `lib/src/store/document_store_kernel.dart` — sparse mutation application, stored element/resource state, and accepted touched facts.
- `lib/src/store/element_registry.dart` — stored background-element order and ordinary-layer element-order clearing.
- `lib/src/store/family_tables.dart` — stored element families and image/vector resource-reference summaries.
- `lib/src/runtime/runtime_command_facts_adapter.dart` — command-path clear candidate enumeration.

The following production files participate in the current route but contain generic behavior rather than a `clearContent` branch:

- `lib/src/contracts/public/canvas_runtime.dart`
- `lib/src/contracts/internal/command_facts_port.dart`
- `lib/src/contracts/internal/touched_set.dart`
- `lib/src/runtime/runtime_root.dart`
- `lib/src/edit/edit_kernel.dart`
- `lib/src/edit/touched_set_builder.dart`
- `lib/src/edit/commit_compiler.dart`
- `lib/src/edit/commit_applier.dart`
- `lib/src/geometry/spatial_kernel.dart`
- `lib/src/runtime/runtime_action_finalizer.dart`
- `lib/src/store/sparse_store_commit.dart`
- `lib/src/store/layer_table.dart`
- `lib/src/store/resource_table.dart`
- `lib/src/store/committed_document.dart`
- `lib/src/store/document_projection_cache.dart`

### Existing direct test coverage

- `test/edit/fixtures/sparse_edit_session_fixture.dart` — sparse clear of background/content IDs, resource removal, no-op behavior, result order, and background touch. `test/edit/fixtures/sparse_edit_session_fixture.dart:149`, `test/edit/fixtures/sparse_edit_session_fixture.dart:171`, `test/edit/fixtures/sparse_edit_session_fixture.dart:324`, `test/edit/fixtures/sparse_edit_session_fixture.dart:388`, `test/edit/fixtures/sparse_edit_session_fixture.dart:405`
- `test/edit/fixtures/exact_touched_invalidation_fixture.dart` — materialized clear with a background element and separate background/grid touched assertions. `test/edit/fixtures/exact_touched_invalidation_fixture.dart:79`, `test/edit/fixtures/exact_touched_invalidation_fixture.dart:91`, `test/edit/fixtures/exact_touched_invalidation_fixture.dart:99`, `test/edit/fixtures/exact_touched_invalidation_fixture.dart:117`
- `test/edit/fixtures/edit_matrix_effects_fixture.dart` — edit and committed effect plans; the existing clear input contains an element with `isDeletable: false`. `test/edit/fixtures/edit_matrix_effects_fixture.dart:190`, `test/edit/fixtures/edit_matrix_effects_fixture.dart:1103`, `test/edit/fixtures/edit_matrix_effects_fixture.dart:1512`, `test/edit/fixtures/edit_matrix_effects_fixture.dart:1516`, `test/edit/fixtures/edit_matrix_effects_fixture.dart:1936`
- `test/store/fixtures/sparse_store_commit_fixture.dart` — sparse-store clear, retained layer count, cleared element/resource counts, and resource-only clear. `test/store/fixtures/sparse_store_commit_fixture.dart:661`, `test/store/fixtures/sparse_store_commit_fixture.dart:677`, `test/store/fixtures/sparse_store_commit_fixture.dart:692`, `test/store/fixtures/sparse_store_commit_fixture.dart:705`
- `test/runtime/fixtures/command_facts_port_fixture.dart` — command clear facts include a background-located handle, a locked handle, a non-deletable handle, and a resource ID. `test/runtime/fixtures/command_facts_port_fixture.dart:91`, `test/runtime/fixtures/command_facts_port_fixture.dart:100`, `test/runtime/fixtures/command_facts_port_fixture.dart:183`, `test/runtime/fixtures/command_facts_port_fixture.dart:200`
- `test/api/fixtures/command_port_actions_fixture.dart` — command clear currently expects a background element, ordinary elements including a non-deletable element, and an image resource in the result; it also covers the action payload, repeated no-op, and resource-only cleanup without an action. `test/api/fixtures/command_port_actions_fixture.dart:73`, `test/api/fixtures/command_port_actions_fixture.dart:90`, `test/api/fixtures/command_port_actions_fixture.dart:97`, `test/api/fixtures/command_port_actions_fixture.dart:129`, `test/api/fixtures/command_port_actions_fixture.dart:142`
- `test/edit/fixtures/selection_effect_commit_fixture.dart` — selection/revision effects and clear action intent. `test/edit/fixtures/selection_effect_commit_fixture.dart:200`, `test/edit/fixtures/selection_effect_commit_fixture.dart:262`, `test/edit/fixtures/selection_effect_commit_fixture.dart:275`
- `test/spatial/fixtures/touched_update_fixture.dart` — generic empty-frame index reset after removed IDs. `test/spatial/fixtures/touched_update_fixture.dart:60`, `test/spatial/fixtures/touched_update_fixture.dart:74`
- `test/edit/fixtures/low_level_mutations_do_not_emit_actions_fixture.dart` and `test/smoke/public_incremental_smoke_test.dart` contain low-level no-action and public command workflow coverage. `test/edit/fixtures/low_level_mutations_do_not_emit_actions_fixture.dart:9`, `test/edit/fixtures/low_level_mutations_do_not_emit_actions_fixture.dart:17`, `test/edit/fixtures/low_level_mutations_do_not_emit_actions_fixture.dart:22`, `test/smoke/public_incremental_smoke_test.dart:700`, `test/smoke/public_incremental_smoke_test.dart:705`
- `test/edit/fixtures/sync_non_nested_async_stale_fixture.dart` and `test/edit/fixtures/sparse_edit_session_fixture.dart` contain stale-handle error coverage for `clearContent`. `test/edit/fixtures/sync_non_nested_async_stale_fixture.dart:221`, `test/edit/fixtures/sparse_edit_session_fixture.dart:494`, `test/edit/fixtures/sparse_edit_session_fixture.dart:508`

### Related storage primitive coverage

- `test/store/fixtures/layer_table_location_fixture.dart` directly exercises `ElementRegistry.clearContent()` and expects empty element-ID lists in ordinary layers. `test/store/fixtures/layer_table_location_fixture.dart:393`
- `test/store/fixtures/sparse_family_editor_lifecycle_fixture.dart` covers family-table clear without copying base entries and clear-and-restore of all family rows within a sparse commit. `test/store/fixtures/sparse_family_editor_lifecycle_fixture.dart:61`, `test/store/fixtures/sparse_family_editor_lifecycle_fixture.dart:270`
- `test/store/fixtures/sparse_family_editor_current_state_fixture.dart` covers the sparse clear barrier decision trace. `test/store/fixtures/sparse_family_editor_current_state_fixture.dart:684`
- `test/store/fixtures/resource_reference_summary_fixture.dart` covers the resource-reference summary used by `StoreSparseRemoveUnusedResource`; this fixture does not contain `StoreSparseClearContent`. `test/store/fixtures/resource_reference_summary_fixture.dart:193`

### Current contract and verification documentation

- `docs/contracts/public_api_v1.md` defines separate document fields for background, grid, background elements, layers, and resources; it also documents `clearContent`, `CanvasClearResult`, resource-reference validation, and the `deleteSelection` `isDeletable` rule. `docs/contracts/public_api_v1.md:680`, `docs/contracts/public_api_v1.md:692`, `docs/contracts/public_api_v1.md:695`, `docs/contracts/public_api_v1.md:738`, `docs/contracts/public_api_v1.md:954`, `docs/contracts/public_api_v1.md:1444`, `docs/contracts/public_api_v1.md:1470`, `docs/contracts/public_api_v1.md:1495`, `docs/contracts/public_api_v1.md:1614`, `docs/contracts/public_api_v1.md:1647`
- `docs/contracts/operation_matrix.md` records clear as an element/selection/resource operation and separately records background-color and grid operations. `docs/contracts/operation_matrix.md:64`, `docs/contracts/operation_matrix.md:65`, `docs/contracts/operation_matrix.md:68`, `docs/contracts/operation_matrix.md:69`
- `docs/contracts/edit_kernel.md` records touched flags, clear selection effects, resource-reference validation, and `isDeletable` as a projection-only element field. `docs/contracts/edit_kernel.md:178`, `docs/contracts/edit_kernel.md:231`, `docs/contracts/edit_kernel.md:261`, `docs/contracts/edit_kernel.md:273`
- `docs/contracts/spatial_kernel.md` records an empty spatial-index reset for the operation-matrix clear path. `docs/contracts/spatial_kernel.md:60`, `docs/contracts/spatial_kernel.md:81`
- `docs/verification/tests.md` lists the existing command, runtime-facts, and document/selection test suites as verification evidence. `docs/verification/tests.md:688`, `docs/verification/tests.md:698`, `docs/verification/tests.md:839`

## Existing Assertions Relevant to the Research Question

- Sparse edit coverage currently expects a clear with resources to remove two background IDs, two ordinary-layer IDs, and two resources. `test/edit/fixtures/sparse_edit_session_fixture.dart:149`, `test/edit/fixtures/sparse_edit_session_fixture.dart:153`, `test/edit/fixtures/sparse_edit_session_fixture.dart:159`
- Materialized touched coverage currently expects a background ID in `removedElementIds` and `backgroundLayerChanged == true` after clear. `test/edit/fixtures/exact_touched_invalidation_fixture.dart:79`, `test/edit/fixtures/exact_touched_invalidation_fixture.dart:89`, `test/edit/fixtures/exact_touched_invalidation_fixture.dart:91`, `test/edit/fixtures/exact_touched_invalidation_fixture.dart:93`
- The edit-matrix clear case uses a hidden, locked image with `isDeletable: false` and expects the image and its resource to be removed after commit. `test/edit/fixtures/edit_matrix_effects_fixture.dart:1103`, `test/edit/fixtures/edit_matrix_effects_fixture.dart:1110`, `test/edit/fixtures/edit_matrix_effects_fixture.dart:1113`, `test/edit/fixtures/edit_matrix_effects_fixture.dart:1116`, `test/edit/fixtures/edit_matrix_effects_fixture.dart:1117`, `test/edit/fixtures/edit_matrix_effects_fixture.dart:1512`, `test/edit/fixtures/edit_matrix_effects_fixture.dart:1516`
- Command-facts coverage currently expects clear candidates to include the background-located element and the non-deletable ordinary-layer element. `test/runtime/fixtures/command_facts_port_fixture.dart:91`, `test/runtime/fixtures/command_facts_port_fixture.dart:100`, `test/runtime/fixtures/command_facts_port_fixture.dart:183`, `test/runtime/fixtures/command_facts_port_fixture.dart:200`
- Store coverage currently expects a sparse clear to leave one layer while reducing element and resource counts to zero. `test/store/fixtures/sparse_store_commit_fixture.dart:661`, `test/store/fixtures/sparse_store_commit_fixture.dart:677`
- The public command fixture has a resource-only clear case with `didClearContent == true`, no removed element IDs, one removed resource ID, and no action. `test/api/fixtures/command_port_actions_fixture.dart:97`, `test/api/fixtures/command_port_actions_fixture.dart:106`
- No inspected fixture combines preservation of `background`, `grid`, a background vector element, and that vector's referenced resource with removal of a non-deletable ordinary-layer element in one clear scenario.

## Search Coverage

Searched current source, tests, and documentation under `lib/`, `test/`, and `docs/` using these terms:

- `clearContent`, `StoreSparseClearContent`, `ClearContentFacts`, and `ClearContentActionIntent` for public, runtime, edit, and store routing.
- `backgroundElements`, `backgroundLayerChanged`, `setBackgroundColor`, and `setGrid` for separate background metadata and background-element behavior.
- `removeUnusedResources`, `_isResourceReferenced`, and `referencesResource` for materialized and sparse resource-reference handling.
- `isDeletable`, `isLocked`, and `FrameElementLocationKind.background` for delete/clear eligibility and command facts.
- `clearContentStructure`, `clearElements`, `FamilyTablesEditor`, `ResourceTable.clear`, and `LayerTable.clearElements` for stored family, order, and resource state.

The search located no additional `clearContent`-specific mutation branch in `EditKernel`, `CommitCompiler`, `CommitApplier`, `RuntimeRoot` delivery, or `SpatialKernel`; those files process generic revisions, touched sets, and delivery effects.

## Architecture Facts

```text
CanvasCommandPort.clearContent
  -> RuntimeRoot.clearContentByCommand
  -> RuntimeCommandFactsAdapter.clearContentFacts
  -> EditKernel / EditSession.clearContent
       -> DraftDocument.clearContent (materialized)
       -> StoreSparseClearContent -> DocumentStoreKernel._clearContent (sparse)
  -> accepted touched facts -> TouchedSet -> CommitCompiler
  -> RuntimeRoot delivery -> SpatialKernel and resource release
```

`CanvasEdit.clearContent` enters the same `EditKernel` and edit-session route without the command-facts and action-intent stages. `lib/src/edit/edit_kernel.dart:175`, `lib/src/edit/edit_kernel.dart:186`, `lib/src/edit/edit_kernel.dart:221`, `lib/src/edit/edit_kernel.dart:248`

## Open Questions

None identified in the inspected current implementation, contract documents, and direct test fixtures.
