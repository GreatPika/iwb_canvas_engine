---
date: 2026-05-18
researcher: Codex
commit: 22dd9e8
branch: new-architecture
research_question: "Operation matrix field-effect taxonomy and HOLE-002 public operation coverage"
---

# Research: Operation Matrix Field-Effect Taxonomy

## Summary

The current repository treats the operation matrix as the contract owner for operation-level effects. The matrix table records `State touched`, `Revisions`, `Spatial`, `Projection`, `Repaint`, and `Events` for each row (`docs/contracts/operation_matrix.md:46`), and the section registry links it to `edit.operation_matrix_complete`, `test.edit.operation_matrix_effects`, `seq_edit_success`, and `seq_edit_rollback` (`docs/_registry/sections.yaml:433`, `docs/_registry/sections.yaml:460`).

The field-effect taxonomy topic exists today as a separate redesign note. It names a central `UpdateEffectCompiler`, takes an element update DTO as input, and returns typed effects (`redesign.md:7`, `redesign.md:12`). The existing public API already has field update DTOs (`docs/contracts/public_api_v1.md:283`, `docs/contracts/public_api_v1.md:964`), and the edit contract already describes `TouchedSet`, `CommitCompiler`, `CommitPlan`, typed `RepaintIntent`, and typed invalidation effects (`docs/contracts/edit_kernel.md:123`, `docs/contracts/edit_kernel.md:147`).

HOLE-002 is still open in the audit. It says the operation matrix must cover the public state/event/effect surface and prove revisions, repaint, spatial, projection, resource effects, user-action notifications, no-op behavior, and rollback semantics (`audit.md:37`, `audit.md:43`). Some named public operations already appear as grouped rows in `docs/contracts/operation_matrix.md`, while `audit.md` still lists them as unchecked alias/row work (`docs/contracts/operation_matrix.md:56`, `docs/contracts/operation_matrix.md:71`, `audit.md:47`, `audit.md:72`).

## Detailed Findings

### 1. Operation Matrix Ownership

- **Location**: primary `docs/contracts/operation_matrix.md:46`; related registry `docs/_registry/sections.yaml:433`.
- **Description**: The operation matrix has columns for operation, touched state, revisions, spatial effect, projection effect, repaint target, and events (`docs/contracts/operation_matrix.md:46`). The registry maps `section_13_operation_matrix` to `docs/contracts/operation_matrix.md` and title `13. Operation matrix` (`docs/_registry/sections.yaml:433`, `docs/_registry/sections.yaml:436`).
- **Dependencies**: The operation matrix context block requires `section_11_edit_kernel` before editing (`docs/contracts/operation_matrix.md:7`, `docs/contracts/operation_matrix.md:8`). The registry lists `section_11_edit_kernel` as must-read, `interaction_mutation_boundary` as donor, `seq_edit_success` and `seq_edit_rollback` as diagrams, `edit.operation_matrix_complete` and `events.commands_emit_user_actions` as guardrails, and `test.edit.operation_matrix_effects` as a test (`docs/_registry/sections.yaml:444`, `docs/_registry/sections.yaml:460`).
- **Data flow**: Operation row -> effect dimensions in the matrix -> executable mapping through `edit.operation_matrix_complete` and `test.edit.operation_matrix_effects` (`docs/contracts/operation_matrix.md:21`, `docs/contracts/operation_matrix.md:29`; `docs/indexes/by_guardrail.md:294`, `docs/indexes/by_guardrail.md:298`).

The matrix phase note says P5 closes edit-owned rows and the generic executable effect shape, P6 closes loadDocument success/failure rows, and P7 plus P10-P12 close resource and interaction rows when those owners land (`docs/contracts/operation_matrix.md:38`, `docs/contracts/operation_matrix.md:44`).

### 2. Current Matrix Granularity

- **Location**: primary `docs/contracts/operation_matrix.md:48`; related audit `audit.md:37`.
- **Description**: The matrix currently includes grouped rows such as `update visual only` and `update geometry/transform` (`docs/contracts/operation_matrix.md:50`, `docs/contracts/operation_matrix.md:51`). It also groups selection operations into `setSelection/toggleSelection/clearSelection/selectAll` (`docs/contracts/operation_matrix.md:56`), resource dirty operations into `markResourceDirty/markAllResourcesDirty` (`docs/contracts/operation_matrix.md:70`), and tool-setting operations into `setMode/setDrawStyle/setDrawTool/setDrawColor/setPointerPolicy` (`docs/contracts/operation_matrix.md:71`).
- **Dependencies**: Matrix notes state that rows changing a public revision publish one coherent `CanvasRuntimeState`; selection-only rows do not increment document revision, evict projection, or update spatial indexes; and no-op operations publish no new public state snapshot (`docs/contracts/operation_matrix.md:91`, `docs/contracts/operation_matrix.md:106`).
- **Data flow**: Grouped matrix row -> public revision and repaint/projection/spatial/event behavior -> row-specific or alias coverage tracked by HOLE-002 (`audit.md:47`, `audit.md:72`).

Within the visible operation table from `docs/contracts/operation_matrix.md:46` through `docs/contracts/operation_matrix.md:87`, rows are present for grouped selection, grouped resource dirty, grouped interaction settings, text double-tap request, and three guarded `commitTextEdit` outcomes (`docs/contracts/operation_matrix.md:56`, `docs/contracts/operation_matrix.md:70`, `docs/contracts/operation_matrix.md:71`, `docs/contracts/operation_matrix.md:81`, `docs/contracts/operation_matrix.md:84`). In the same table range, no row text names `removeUnusedResource` or `replaceDraftDocument`.

### 3. Field Update DTOs And Existing Typed Effects

- **Location**: primary `docs/contracts/public_api_v1.md:283`; related edit contract `docs/contracts/edit_kernel.md:123`.
- **Description**: Public field updates use `CanvasFieldUpdate<T>` with absent, non-null set, and nullable clear semantics instead of legacy `PatchField` (`docs/contracts/public_api_v1.md:283`, `docs/contracts/public_api_v1.md:287`). `CanvasElementUpdate` contains common field updates for `transform`, `opacity`, `hitPadding`, `isVisible`, `isSelectable`, `isLocked`, `isDeletable`, `isTransformable`, and `metadata` (`docs/contracts/public_api_v1.md:964`, `docs/contracts/public_api_v1.md:987`).
- **Dependencies**: `CanvasEdit.updateElement(CanvasElementUpdate update)` is declared on the edit surface (`docs/contracts/public_api_v1.md:1175`, `docs/contracts/public_api_v1.md:1182`). Update semantics say mismatched update kind throws before draft mutation, no-op update returns false and emits no action, changed update increments element revision, and changed update invalidates only typed touched sets (`docs/contracts/public_api_v1.md:1151`, `docs/contracts/public_api_v1.md:1158`).
- **Data flow**: Element update DTO -> `CanvasEdit.updateElement` -> typed touched set -> `CommitCompiler` -> typed repaint/invalidation effects -> runtime/applier boundary (`docs/contracts/public_api_v1.md:1182`; `docs/contracts/edit_kernel.md:72`, `docs/contracts/edit_kernel.md:82`).

The edit contract defines `TouchedSet` categories for added, removed, updated, transformed, geometry-changed, visual-changed, resource descriptor/visual changes, layer/background changes, selection changes, persisted camera, background, grid, palette, and document replacement (`docs/contracts/edit_kernel.md:123`, `docs/contracts/edit_kernel.md:143`). `CommitCompiler` must produce exact invalidation, generic global invalidation is forbidden except `documentReplaced`, and the compiler produces a `CommitPlan` with typed `RepaintIntent` and invalidation effects (`docs/contracts/edit_kernel.md:145`, `docs/contracts/edit_kernel.md:149`).

The redesign note separately names `UpdateEffectCompiler` and gives a field taxonomy example for `opacity`, `transform`, `hitPadding`, `isVisible`, `isSelectable`, `text`, `fontSize`, `resourceId`, and `metadata` (`redesign.md:3`, `redesign.md:18`, `redesign.md:63`). It states effects are computed in one way rather than spread across handlers (`redesign.md:66`).

### 4. Public Operations Named By HOLE-002

- **Location**: primary `audit.md:47`; public API surface `docs/contracts/public_api_v1.md:1170`.
- **Description**: HOLE-002 lists unchecked row or alias-row work for `removeUnusedResource`, `replaceDraftDocument`, `toggleSelection`, `clearSelection`, `selectAll`, `setMode`, `setDrawStyle`, `setDrawTool`, `setDrawColor`, `setPointerPolicy`, and `markAllResourcesDirty` (`audit.md:47`, `audit.md:57`). The same checklist marks text double-tap / text edit request and guarded `commitTextEdit` as checked (`audit.md:58`, `audit.md:59`).
- **Dependencies**: The public API declares `removeUnusedResource` and `replaceDraftDocument` on `CanvasEdit` (`docs/contracts/public_api_v1.md:1186`, `docs/contracts/public_api_v1.md:1194`), selection operations on `CanvasSelectionPort` (`docs/contracts/public_api_v1.md:1294`, `docs/contracts/public_api_v1.md:1300`), tool setters on `CanvasToolPort` (`docs/contracts/public_api_v1.md:1386`, `docs/contracts/public_api_v1.md:1395`), and `markAllResourcesDirty` on `CanvasResourcePort` (`docs/contracts/public_api_v1.md:1446`, `docs/contracts/public_api_v1.md:1451`).
- **Data flow**: Public operation declaration -> subsystem contract facts -> operation matrix row or grouped row -> guardrail/test mapping (`docs/contracts/resources.md:126`; `docs/contracts/load_document.md:105`; `docs/contracts/operation_matrix.md:56`, `docs/contracts/operation_matrix.md:71`).

`removeUnusedResource(id)` is documented in the resource contract as returning false if the resource does not exist or if any element references it; references include background, hidden, locked, and non-deletable elements; if unused, it removes the resource and invalidates resource cache; it emits no action event and increments document/resource revision if removed (`docs/contracts/resources.md:126`, `docs/contracts/resources.md:135`).

`CanvasEdit.replaceDraftDocument(document)` is documented as different from external `loadDocument`: valid only inside an edit callback, no external gesture interruption, rollback-safe, and participating in the same atomic edit session (`docs/contracts/load_document.md:105`, `docs/contracts/load_document.md:112`). Edit-session touched state includes `documentReplaced` (`docs/contracts/edit_kernel.md:142`, `docs/contracts/edit_kernel.md:143`).

Selection operations are grouped in the matrix as selection-owner changes with `state.revisions.selection`, no spatial effect, no projection eviction, main repaint, and no events (`docs/contracts/operation_matrix.md:56`). The public API states selection-only changes update `selectionRevision`, not `documentRevision`, and do not evict public document projection (`docs/contracts/public_api_v1.md:1320`, `docs/contracts/public_api_v1.md:1321`).

Tool setting operations are grouped in the matrix as interaction-settings changes with `state.revisions.interaction`, conditional `state.revisions.selection` on draw-mode selection clear, conditional `state.revisions.preview` on active preview cleanup, no spatial effect, no projection eviction, repaint only for changed affected state, and no events (`docs/contracts/operation_matrix.md:71`). The runtime data model states interaction setting changes such as mode, draw style, active draw tool, draw color, and pointer policy increment public `state.revisions.interaction` without changing document revision (`docs/architecture/03_data_model.md:168`, `docs/architecture/03_data_model.md:170`).

`markAllResourcesDirty` is declared on `CanvasResourcePort` (`docs/contracts/public_api_v1.md:1450`, `docs/contracts/public_api_v1.md:1451`). The resource contract states it applies the same dirty-resource rule to every registered resource and clears the active session cache if a session exists (`docs/contracts/resources.md:168`, `docs/contracts/resources.md:169`). Dirty-resource semantics do not change document revision, increment `state.revisions.resourceVisual`, publish main repaint intent, emit no action, do not clear selection, and do not clear preview (`docs/contracts/resources.md:146`, `docs/contracts/resources.md:159`).

### 5. Runtime Revision And Effect Domains

- **Location**: primary `docs/contracts/public_api_v1.md:397`; related data model `docs/architecture/03_data_model.md:116`.
- **Description**: `CanvasRuntimeRevisions` exposes public fields `document`, `selection`, `preview`, `viewCamera`, `resourceVisual`, `interaction`, and `epoch` (`docs/contracts/public_api_v1.md:397`, `docs/contracts/public_api_v1.md:414`). Internal cache/projection revisions such as structural, bounds, element visual, background, grid, projection, or resource descriptor revisions are not public API fields (`docs/contracts/public_api_v1.md:432`, `docs/contracts/public_api_v1.md:438`).
- **Dependencies**: The runtime data model defines internal revision meanings for document, controller epoch, structural, resource, resource visual, bounds, element visual, background, grid, projection, and preview revisions (`docs/architecture/03_data_model.md:116`, `docs/architecture/03_data_model.md:130`).
- **Data flow**: Owner-specific mutation -> internal revision/effect facts -> public `CanvasRuntimeState` snapshot after owning boundary accepts the change (`docs/architecture/03_data_model.md:132`, `docs/architecture/03_data_model.md:138`).

Selection-only changes increment selection revision, schedule selection UI repaint, and do not increment document revision, evict projection, or update spatial indexes (`docs/architecture/03_data_model.md:140`, `docs/architecture/03_data_model.md:145`). Runtime view camera changes increment `state.revisions.viewCamera`, repaint affected surfaces, and do not increment document revision, evict projection, or change persisted camera state (`docs/architecture/03_data_model.md:147`, `docs/architecture/03_data_model.md:152`). Resource dirty operations increment `state.revisions.resourceVisual`, and this public dirty-resource domain is a repaint observation signal (`docs/architecture/03_data_model.md:171`, `docs/architecture/03_data_model.md:175`).

The frame contract captures main-frame facts including document, structural, bounds, element visual, background, grid, selection, resource visual, view camera, viewport, DPR, selected ids, and selected move delta (`docs/contracts/frame_rendering.md:56`, `docs/contracts/frame_rendering.md:77`). Overlay frames capture preview revision, view camera revision, view camera offset, preview state, and selection style (`docs/contracts/frame_rendering.md:79`, `docs/contracts/frame_rendering.md:88`). The cache policy keys `PaintPlanCache` by structural, bounds, elementVisual, viewport, and DPR, while excluding background, grid, view camera, preview, selection-only, and style-only changes (`docs/contracts/cache_policy.md:47`).

### 6. Rollback, No-Op, And Text Request Semantics

- **Location**: primary `docs/contracts/edit_kernel.md:87`; related matrix notes `docs/contracts/operation_matrix.md:106`.
- **Description**: Edit rollback discards buffered events and repaint requests, closes the edit handle, and rethrows (`docs/contracts/edit_kernel.md:97`, `docs/contracts/edit_kernel.md:103`). Rollback obligations include unchanged committed document identity, revisions, projection cache, spatial index, resource cache, selection owner, preview, no actions, no text edit event, no public state publication, no scene repaint, and no overlay repaint (`docs/contracts/edit_kernel.md:106`, `docs/contracts/edit_kernel.md:120`).
- **Dependencies**: Command mutations must go through EditKernel and inherit rollback/stale/dispose checks (`docs/contracts/public_api_v1.md:1269`). Accepted edit commits publish one public state snapshot combining document, selection-prune, resource-visual, preview cleanup, interaction, and epoch effects; no-op edits publish no new snapshot (`docs/contracts/edit_kernel.md:159`, `docs/contracts/edit_kernel.md:162`).
- **Data flow**: Failed edit/session -> rollback sequence -> no persisted state/effect publication; accepted no-op -> no public state snapshot (`docs/contracts/edit_kernel.md:87`, `docs/contracts/operation_matrix.md:85`, `docs/contracts/operation_matrix.md:106`).

The matrix includes explicit no-op rows for `ensureLayer no-op`, `commitTextEdit no-op accepted`, `no-op edit`, and `loadDocument failure` (`docs/contracts/operation_matrix.md:54`, `docs/contracts/operation_matrix.md:73`, `docs/contracts/operation_matrix.md:83`, `docs/contracts/operation_matrix.md:85`).

Text double-tap on a visible selectable text element emits `CanvasTextEditRequested`, does not mutate document, and does not select/deselect by itself (`docs/contracts/interaction_engine.md:161`, `docs/contracts/interaction_engine.md:165`). Request-originated text commits through `CanvasCommandPort.commitTextEdit`; stale or retired ids are rejected with no document/repaint/action effect, accepted no-op and changed requests are retired, and changed text delegates to EditKernel before emitting `CanvasActionType.editText` (`docs/contracts/interaction_engine.md:183`, `docs/contracts/interaction_engine.md:190`).

### 7. Verification Mapping

- **Location**: primary `docs/verification/guardrails.md:129`; related indexes `docs/indexes/by_guardrail.md:294`.
- **Description**: `edit.operation_matrix_complete` is a mandatory guardrail, and its rule is that every operation matrix row has an executable effect assertion for revisions, spatial, projection, repaint, and events (`docs/verification/guardrails.md:129`, `docs/verification/guardrails.md:162`).
- **Dependencies**: The guardrail index maps `edit.operation_matrix_complete` to `section_13_operation_matrix`, `section_22_guardrails_machine_checks`, and `section_27_final_release_gates`; it lists `test.edit.field_update_nullable_semantics`, `test.edit.operation_matrix_effects`, and `test.guardrails.blocking_suite` (`docs/indexes/by_guardrail.md:294`, `docs/indexes/by_guardrail.md:298`).
- **Data flow**: Matrix row -> guardrail rule -> required test id -> release gate (`docs/indexes/by_test_area.md:448`, `docs/verification/release_gates.md:183`).

The test area index maps `test.edit.operation_matrix_effects` to `test/edit/operation_matrix_effects_test.dart`, `section_13_operation_matrix`, `section_23_tests`, and guardrail `edit.operation_matrix_complete` (`docs/indexes/by_test_area.md:448`, `docs/indexes/by_test_area.md:453`). The release gates require operation matrix and exact touched invalidation tests to be green, and separately require text edit request plus guarded stale text commit integration tests to be green (`docs/verification/release_gates.md:183`, `docs/verification/release_gates.md:193`).

## Code References

- `redesign.md:3` - field-effect taxonomy heading.
- `redesign.md:7` - central field-effect table and compiler statement.
- `redesign.md:18` - example taxonomy begins with `opacity`.
- `redesign.md:56` - `resourceId` example effects.
- `redesign.md:61` - `metadata` example effects.
- `audit.md:37` - HOLE-002 heading.
- `audit.md:41` - HOLE-002 effect proof dimensions.
- `audit.md:47` - HOLE-002 missing/alias operation checklist begins.
- `audit.md:60` - HOLE-002 required per-row facts begin.
- `audit.md:72` - HOLE-002 guardrail/test mapping item.
- `docs/contracts/operation_matrix.md:46` - operation matrix columns.
- `docs/contracts/operation_matrix.md:50` - `update visual only` row.
- `docs/contracts/operation_matrix.md:51` - `update geometry/transform` row.
- `docs/contracts/operation_matrix.md:56` - grouped selection row.
- `docs/contracts/operation_matrix.md:70` - grouped resource dirty row.
- `docs/contracts/operation_matrix.md:71` - grouped interaction settings row.
- `docs/contracts/operation_matrix.md:81` - text double-tap request row.
- `docs/contracts/operation_matrix.md:84` - changed `commitTextEdit` row.
- `docs/contracts/public_api_v1.md:283` - field update patch semantics.
- `docs/contracts/public_api_v1.md:964` - `CanvasElementUpdate` declaration.
- `docs/contracts/public_api_v1.md:1151` - update semantics.
- `docs/contracts/public_api_v1.md:1170` - edit API declarations.
- `docs/contracts/public_api_v1.md:1186` - `removeUnusedResource` declaration.
- `docs/contracts/public_api_v1.md:1194` - `replaceDraftDocument` declaration.
- `docs/contracts/public_api_v1.md:1294` - selection API declaration.
- `docs/contracts/public_api_v1.md:1386` - tool API declaration.
- `docs/contracts/public_api_v1.md:1446` - resource API declaration.
- `docs/contracts/edit_kernel.md:123` - `TouchedSet` begins.
- `docs/contracts/edit_kernel.md:145` - exact invalidation rule.
- `docs/contracts/edit_kernel.md:147` - typed effects and downstream owners.
- `docs/contracts/resources.md:126` - `removeUnusedResource` contract.
- `docs/contracts/resources.md:146` - dirty-resource semantics.
- `docs/contracts/load_document.md:105` - `replaceDraftDocument` distinction.
- `docs/contracts/interaction_engine.md:161` - text double-tap contract.
- `docs/contracts/frame_rendering.md:56` - main frame captured facts.
- `docs/contracts/cache_policy.md:47` - `PaintPlanCache` key and invalidation.
- `docs/indexes/by_guardrail.md:294` - `edit.operation_matrix_complete` mapping.
- `docs/indexes/by_test_area.md:448` - `test.edit.operation_matrix_effects` mapping.
- `docs/verification/release_gates.md:183` - operation matrix release gate.

## Observed Architecture Facts

- Pattern observed: operation-level effects are currently centralized in `docs/contracts/operation_matrix.md`, while field-level effect taxonomy is recorded in `redesign.md` (`docs/contracts/operation_matrix.md:46`, `redesign.md:3`).
- Pattern observed: public update DTOs are field-granular, but the current matrix update rows are still grouped as visual-only and geometry/transform rows (`docs/contracts/public_api_v1.md:964`, `docs/contracts/operation_matrix.md:50`, `docs/contracts/operation_matrix.md:51`).
- Data flow: `CanvasElementUpdate` -> `CanvasEdit.updateElement` -> `TouchedSet` -> `CommitCompiler` -> `CommitPlan` typed effects -> frame/spatial/resource/projection/public-state owners (`docs/contracts/public_api_v1.md:1182`, `docs/contracts/edit_kernel.md:72`, `docs/contracts/edit_kernel.md:150`).
- Data flow: selection-only operation -> `SelectionKernel` owner -> `state.revisions.selection` -> main repaint without document revision/projection/spatial changes (`docs/contracts/operation_matrix.md:56`, `docs/architecture/03_data_model.md:140`, `docs/architecture/03_data_model.md:145`).
- Data flow: dirty-resource operation -> resource visual domain -> active session target/all invalidation -> main repaint intent -> `state.revisions.resourceVisual` (`docs/contracts/resources.md:146`, `docs/contracts/resources.md:169`).
- Key dependency: `edit.operation_matrix_complete` is the guardrail that maps operation matrix rows to executable effect assertions for revisions, spatial, projection, repaint, and events (`docs/verification/guardrails.md:162`).

## Open Questions

- `audit.md` still lists grouped operations such as `toggleSelection`, `clearSelection`, `selectAll`, tool setters, pointer policy, and `markAllResourcesDirty` as unchecked row-or-alias work, while `docs/contracts/operation_matrix.md` already contains grouped rows for those operation families (`audit.md:47`, `audit.md:57`; `docs/contracts/operation_matrix.md:56`, `docs/contracts/operation_matrix.md:70`, `docs/contracts/operation_matrix.md:71`).
- `redesign.md` names `UpdateEffectCompiler`, while the current edit contract names `CommitCompiler` and `CommitPlan`; the current documents do not link those names to each other (`redesign.md:10`, `docs/contracts/edit_kernel.md:58`, `docs/contracts/edit_kernel.md:76`).
- `removeUnusedResource` and `replaceDraftDocument` have public API and subsystem contract facts, but no visible row text in the current operation matrix table from `docs/contracts/operation_matrix.md:46` through `docs/contracts/operation_matrix.md:87` names either operation (`docs/contracts/public_api_v1.md:1186`, `docs/contracts/public_api_v1.md:1194`; `docs/contracts/resources.md:126`; `docs/contracts/load_document.md:105`).
