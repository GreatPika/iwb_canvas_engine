---
date: 2026-06-01
researcher: Codex
commit: 373fe15b
branch: new-architecture
research_question: "Какие уже существующие части кода, тестов, guardrails, контрактов и диаграмм относятся к P10 selection/marquee/selected move, и где сейчас находятся пробелы относительно требований этого этапа?"
---

# Research: P10 Selection And Move Readiness

## Summary

The current repository already contains the public selection, pointer, preview,
action-event, and move-resolver contracts that P10 will use. The implemented
selection owner is `SelectionKernel`, which stores selected ids and
`selectionRevision` separately from store-owned document revisions
(`lib/src/selection/selection_kernel.dart:7`,
`lib/src/store/revision_state.dart:1`). Runtime integration exposes
`CanvasSelectionPort` and publishes selection revisions into
`CanvasRuntimeState` (`lib/src/runtime/runtime_root.dart:136`,
`lib/src/runtime/runtime_root.dart:685`).

The current repository also contains staged `loadDocument` behavior and the P9
frame-side selected-move/marquee preview paths. `RuntimeRoot._loadDocument`
prepares the replacement before calling the load-interaction boundary, then
installs the replacement, clears selection, updates preview when requested, and
publishes load effects (`lib/src/runtime/runtime_root.dart:560`). Frame capture
routes `CanvasSelectedMovePreview` to the main frame and excludes it from
overlay, while `CanvasMarqueePreview` is admitted to overlay primitives
(`lib/src/frame/frame_capture_service.dart:28`,
`lib/src/frame/overlay_preview_planner.dart:108`).

The main current gap is that P10's production interaction layer does not exist
yet. Searches found no `lib/src/interaction/`, no production
`InteractionEngine`, no production `PointerToolCleanupCoordinator`, no pointer
session/normalizer/state-machine code, no production action emission calls, and
no `test/interaction/**` files. Several P10 guardrail ids are present in docs
and generated indexes, but runner-backed checks currently exist only for load
ordering, core import-boundary future paths, and selected-move main repaint.

## Detailed Findings

### 1. P10 Phase Scope And Contract Inputs

- **Location**: `docs/implementation/p10_selection_and_move.md:1`
- **Description**: P10 is the "selection, marquee, and selected move" phase. Its
  purpose includes selection APIs, marquee selection, selected move preview,
  selected move commit/cancel, move resolver safety, and typed user action
  events (`docs/implementation/p10_selection_and_move.md:5`).
- **Dependencies**: The phase depends on P5 edit core, P6 `loadDocument`, P8
  geometry/spatial, and P9 frame rendering
  (`docs/implementation/p10_selection_and_move.md:47`).
- **Data flow**: P10 states that interaction commits go only through
  `EditKernel` and that interaction reads selection/document facts through
  batched immutable query ports (`docs/implementation/p10_selection_and_move.md:27`,
  `docs/implementation/p10_selection_and_move.md:28`).

### 2. Public Selection API And SelectionKernel

- **Location**: `lib/src/contracts/public/canvas_runtime.dart:197`
- **Description**: `CanvasSelectionPort` exposes selected ids and selection
  commands: set, toggle, clear, selectAll, move, rotate, flip, and delete
  (`lib/src/contracts/public/canvas_runtime.dart:201`). Runtime's adapter
  forwards set/toggle/clear/selectAll and rejects document-mutating selection
  commands through `rejectSelectionDocumentMutation`
  (`lib/src/runtime/runtime_root.dart:779`,
  `lib/src/runtime/runtime_root.dart:808`,
  `lib/src/runtime/runtime_root.dart:833`).
- **Dependencies**: The public selection port lives in the runtime contract and
  uses `CanvasElementId` plus `Offset` for move commands
  (`lib/src/contracts/public/canvas_runtime.dart:7`,
  `lib/src/contracts/public/canvas_runtime.dart:202`,
  `lib/src/contracts/public/canvas_runtime.dart:207`).
- **Data flow**: `RuntimeRoot` constructs `SelectionKernel` with
  `_StoreSelectionMembership` (`lib/src/runtime/runtime_root.dart:98`), exposes
  `_RuntimeSelectionPort` (`lib/src/runtime/runtime_root.dart:136`), and maps
  selection facts into `CanvasRuntimeState.revisions.selection`
  (`lib/src/runtime/runtime_root.dart:676`,
  `lib/src/runtime/runtime_root.dart:687`).

### 3. Selection Revision Separation

- **Location**: `lib/src/selection/selection_kernel.dart:7`
- **Description**: `SelectionKernel` implements `SelectionFactsPort`, stores
  `_selectedIds`, and owns `_selectionRevision`
  (`lib/src/selection/selection_kernel.dart:12`,
  `lib/src/selection/selection_kernel.dart:13`). It increments the selection
  revision only when `_replaceSelection` changes membership
  (`lib/src/selection/selection_kernel.dart:71`,
  `lib/src/selection/selection_kernel.dart:79`).
- **Dependencies**: It depends on `SelectionMembershipPort` for normalization and
  select-all membership (`lib/src/selection/selection_kernel.dart:3`,
  `lib/src/contracts/internal/selection_membership_port.dart:3`).
- **Data flow**: Store revisions do not include selection revision:
  `RevisionState` owns document/projection/structural/bounds/visual/background/
  grid/resource revisions (`lib/src/store/revision_state.dart:1`), and
  `StoreRevisionDelta.advance` advances only those fields
  (`lib/src/store/store_revision_delta.dart:85`). `RuntimeRoot._runtimeState`
  combines store `documentRevision` and selection facts into one public state
  (`lib/src/runtime/runtime_root.dart:685`,
  `lib/src/runtime/runtime_root.dart:688`).

### 4. Selection Tests And Selection Guardrails

- **Location**: `test/selection/fixtures/runtime_owner_separation_fixture.dart:8`
- **Description**: The fixture verifies selection normalization, no document
  revision change, selection revision increment, selected count publication, and
  document projection reuse for selection-only changes
  (`test/selection/fixtures/runtime_owner_separation_fixture.dart:58`,
  `test/selection/fixtures/runtime_owner_separation_fixture.dart:62`,
  `test/selection/fixtures/runtime_owner_separation_fixture.dart:65`,
  `test/selection/fixtures/runtime_owner_separation_fixture.dart:66`). It also
  verifies edit-driven selection prune is published atomically with a document
  revision change (`test/selection/fixtures/runtime_owner_separation_fixture.dart:141`,
  `test/selection/fixtures/runtime_owner_separation_fixture.dart:145`,
  `test/selection/fixtures/runtime_owner_separation_fixture.dart:146`).
- **Dependencies**: The test uses public API plus internal `RuntimeRoot`
  (`test/selection/fixtures/runtime_owner_separation_fixture.dart:4`,
  `test/selection/fixtures/runtime_owner_separation_fixture.dart:5`).
- **Data flow**: `checkSelectionOwnerSeparation` scans forbidden owners under
  API/runtime/store/codec (`tool/guardrails/src/selection_boundary_checks.dart:15`,
  `tool/guardrails/src/selection_boundary_checks.dart:56`) and allows selection
  facts plus `RuntimeRoot` composition fields as exceptions
  (`tool/guardrails/src/selection_boundary_checks.dart:251`,
  `tool/guardrails/src/selection_boundary_checks.dart:261`).

### 5. Public Pointer, Preview, Action, And Resolver Types

- **Location**: `lib/src/contracts/public/canvas_pointer.dart:8`
- **Description**: Public pointer samples define `down`, `move`, `up`, and
  `cancel` lifecycle phases (`lib/src/contracts/public/canvas_pointer.dart:8`).
  `CanvasPointerSample` validates pointer id, position, and timestamp at
  construction (`lib/src/contracts/public/canvas_pointer.dart:92`,
  `lib/src/contracts/public/canvas_pointer.dart:99`,
  `lib/src/contracts/public/canvas_pointer.dart:100`).
- **Dependencies**: `CanvasToolPort` exposes pointer routing and double-tap entry
  points (`lib/src/contracts/public/canvas_tools.dart:110`,
  `lib/src/contracts/public/canvas_tools.dart:121`,
  `lib/src/contracts/public/canvas_tools.dart:122`).
- **Data flow**: Public action payloads are typed and immutable by constructor:
  `CanvasActionCommitted` and payload classes use unmodifiable collections
  (`lib/src/contracts/public/canvas_actions.dart:25`,
  `lib/src/contracts/public/canvas_actions.dart:33`,
  `lib/src/contracts/public/canvas_actions.dart:70`). The move resolver public
  surface is declared as `CanvasMoveCommitResolver`,
  `CanvasMoveCommitRequest`, and sealed `CanvasMoveResolution`
  (`lib/src/contracts/public/canvas_actions.dart:220`,
  `lib/src/contracts/public/canvas_actions.dart:224`,
  `lib/src/contracts/public/canvas_actions.dart:289`).

### 6. Public Preview Variants

- **Location**: `lib/src/contracts/public/canvas_preview.dart:15`
- **Description**: `CanvasPreviewState` is sealed and includes marquee and
  selected-move variants (`lib/src/contracts/public/canvas_preview.dart:16`,
  `lib/src/contracts/public/canvas_preview.dart:19`,
  `lib/src/contracts/public/canvas_preview.dart:21`). `CanvasSelectedMovePreview`
  stores only `Offset delta` and reports `CanvasPreviewKind.selectedMove`
  (`lib/src/contracts/public/canvas_preview.dart:70`,
  `lib/src/contracts/public/canvas_preview.dart:73`,
  `lib/src/contracts/public/canvas_preview.dart:75`).
- **Dependencies**: Preview contracts use `dart:ui` for `Rect`, `Offset`, and
  `Color` (`lib/src/contracts/public/canvas_preview.dart:1`).
- **Data flow**: Consumer tests pattern-match `CanvasSelectedMovePreview` and
  read only the delta (`test/api_contract/preview_state_sealed_union_test.dart:82`,
  `test/api_contract/public_readable_union_variants_test.dart:93`).

### 7. EditKernel And Staged Load

- **Location**: `lib/src/edit/edit_kernel.dart:18`
- **Description**: `EditKernel` receives an `installLoadedDocument` callback
  (`lib/src/edit/edit_kernel.dart:16`,
  `lib/src/edit/edit_kernel.dart:25`) and its `loadDocument` checks mutation
  guard and active edit session before calling the installer
  (`lib/src/edit/edit_kernel.dart:82`,
  `lib/src/edit/edit_kernel.dart:89`).
- **Dependencies**: `RuntimeRoot` wires `installLoadedDocument` to `_loadDocument`
  (`lib/src/runtime/runtime_root.dart:127`,
  `lib/src/runtime/runtime_root.dart:133`).
- **Data flow**: `LoadDocumentPipeline.prepare` validates/materializes with
  `ValidatedImportDraft.fromDocument` and returns a `PreparedDocumentLoad`
  (`lib/src/edit/staged_document_load.dart:54`,
  `lib/src/edit/staged_document_load.dart:60`). `consume` validates owner token,
  rejects double consume, and calls `_store.replaceDocument`
  (`lib/src/edit/staged_document_load.dart:70`,
  `lib/src/edit/staged_document_load.dart:76`,
  `lib/src/edit/staged_document_load.dart:81`).

### 8. LoadDocument Cleanup And Publication Ordering

- **Location**: `lib/src/runtime/runtime_root.dart:560`
- **Description**: Runtime load success order is prepare load, prepare
  interaction cleanup, consume prepared load, clear selection, initialize view
  camera, clear preview if cleanup says it changed, increment epoch, and deliver
  load effects (`lib/src/runtime/runtime_root.dart:561`,
  `lib/src/runtime/runtime_root.dart:563`,
  `lib/src/runtime/runtime_root.dart:564`,
  `lib/src/runtime/runtime_root.dart:565`,
  `lib/src/runtime/runtime_root.dart:566`,
  `lib/src/runtime/runtime_root.dart:568`,
  `lib/src/runtime/runtime_root.dart:572`,
  `lib/src/runtime/runtime_root.dart:573`).
- **Dependencies**: The current cleanup seam is `LoadInteractionBoundary` with a
  `PointerCleanupOutcome` that has only `previewChanged`
  (`lib/src/contracts/internal/load_interaction_boundary.dart:1`,
  `lib/src/contracts/internal/load_interaction_boundary.dart:9`). Default
  production cleanup is the noop boundary
  (`lib/src/runtime/noop_load_interaction_boundary.dart:3`,
  `lib/src/runtime/noop_load_interaction_boundary.dart:10`).
- **Data flow**: Load delivery publishes spatial effects, state, and observer
  effects under the delivery guard (`lib/src/runtime/runtime_root.dart:612`,
  `lib/src/runtime/runtime_root.dart:615`,
  `lib/src/runtime/runtime_root.dart:616`,
  `lib/src/runtime/runtime_root.dart:617`). `_loadEffects` includes projection,
  spatial replacement, resource replacement, main+overlay repaint, selection
  effect when clearing, and public state (`lib/src/runtime/runtime_root.dart:652`,
  `lib/src/runtime/runtime_root.dart:660`).

### 9. Load Tests And Load Guardrails

- **Location**: `test/runtime/fixtures/load_document_ordering_fixture.dart:10`
- **Description**: Failed load does not call the boundary, leaves the old
  document and state unchanged, and emits no actions
  (`test/runtime/fixtures/load_document_ordering_fixture.dart:33`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:45`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:46`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:48`). Successful
  load records `prepared-cleanup`, then state, then observer
  (`test/runtime/fixtures/load_document_ordering_fixture.dart:95`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:97`).
- **Dependencies**: The fixture implements `_RecordingLoadBoundary` directly
  (`test/runtime/fixtures/load_document_ordering_fixture.dart:308`,
  `test/runtime/fixtures/load_document_ordering_fixture.dart:313`).
- **Data flow**: Runner guardrails route `load.prepares_before_interrupt` and
  `load.success_interrupts_before_install` to load-ordering tests
  (`tool/guardrails/src/guardrail_executor.dart:238`,
  `tool/guardrails/src/guardrail_executor.dart:242`).

### 10. Frame Selected-Move Main Preview

- **Location**: `lib/src/frame/frame_capture_service.dart:28`
- **Description**: Main capture stores `CanvasSelectedMovePreview` in
  `CapturedMainFrame.selectedMovePreview`
  (`lib/src/frame/frame_capture_service.dart:31`,
  `lib/src/frame/frame_capture_service.dart:33`). Overlay capture maps
  `CanvasSelectedMovePreview` to null (`lib/src/frame/frame_capture_service.dart:40`,
  `lib/src/frame/frame_capture_service.dart:45`,
  `lib/src/frame/frame_capture_service.dart:46`).
- **Dependencies**: `FrameCaptureService` consumes `FrameFactsPort`,
  `SelectionFactsPort`, and spatial query results
  (`lib/src/frame/frame_capture_service.dart:16`,
  `lib/src/frame/frame_capture_service.dart:18`,
  `lib/src/frame/frame_capture_service.dart:19`).
- **Data flow**: `FrameEngine` builds ordinary records, then selected-move
  supplement, and assigns main repaint reason `selected_move_preview` when the
  preview is active (`lib/src/frame/frame_engine.dart:97`,
  `lib/src/frame/frame_engine.dart:99`,
  `lib/src/frame/frame_engine.dart:183`,
  `lib/src/frame/frame_engine.dart:187`).

### 11. Selected-Move Supplement Planner

- **Location**: `lib/src/frame/selected_move_supplement_planner.dart:58`
- **Description**: The planner returns ordinary records unchanged when no
  selected-move preview exists (`lib/src/frame/selected_move_supplement_planner.dart:62`,
  `lib/src/frame/selected_move_supplement_planner.dart:300`). When active, it
  queries a shifted spatial window, filters movable selected ids, builds shifted
  records, and merges by order token
  (`lib/src/frame/selected_move_supplement_planner.dart:67`,
  `lib/src/frame/selected_move_supplement_planner.dart:91`,
  `lib/src/frame/selected_move_supplement_planner.dart:147`,
  `lib/src/frame/selected_move_supplement_planner.dart:204`,
  `lib/src/frame/selected_move_supplement_planner.dart:225`).
- **Dependencies**: It uses `FrameFactsPort.resolveElement` and
  `RenderElementRecord.fromFacts` (`lib/src/frame/selected_move_supplement_planner.dart:193`,
  `lib/src/frame/selected_move_supplement_planner.dart:205`).
- **Data flow**: Probe data records selected filtering, supplement count, stale
  skips, zero global sorts, and zero ordinary-cache writes during supplement
  (`lib/src/frame/selected_move_supplement_planner.dart:16`,
  `lib/src/frame/selected_move_supplement_planner.dart:119`,
  `lib/src/frame/selected_move_supplement_planner.dart:120`).

### 12. Marquee Overlay Preview

- **Location**: `lib/src/frame/overlay_preview_planner.dart:108`
- **Description**: Overlay planning returns no primitive for
  `CanvasSelectedMovePreview`, but maps `CanvasMarqueePreview` to
  `MarqueeOverlayPrimitive` (`lib/src/frame/overlay_preview_planner.dart:111`,
  `lib/src/frame/overlay_preview_planner.dart:113`,
  `lib/src/frame/overlay_preview_planner.dart:142`).
- **Dependencies**: Marquee primitive uses captured selection style color,
  stroke width, and fill opacity (`lib/src/frame/overlay_preview_planner.dart:146`,
  `lib/src/frame/overlay_preview_planner.dart:149`,
  `lib/src/frame/overlay_preview_planner.dart:152`).
- **Data flow**: `OverlayFramePainter` paints marquee fill and stroke from the
  primitive fields (`lib/src/frame/overlay_frame_painter.dart:31`,
  `lib/src/frame/overlay_frame_painter.dart:46`,
  `lib/src/frame/overlay_frame_painter.dart:51`).

### 13. Frame Tests And Preview Guardrail

- **Location**: `test/frame/fixtures/repaint_bus_output_fixture.dart:21`
- **Description**: The repaint fixture asserts selected move invalidates main
  and overlay previews invalidate overlay
  (`test/frame/fixtures/repaint_bus_output_fixture.dart:23`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:27`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:28`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:29`,
  `test/frame/fixtures/repaint_bus_output_fixture.dart:37`).
- **Dependencies**: The selected-move repaint guardrail is runner-backed and
  points to that frame fixture
  (`test/guardrails/preview_selected_move_main_repaint_guardrail_test.dart:7`,
  `test/guardrails/preview_selected_move_main_repaint_guardrail_test.dart:20`,
  `tool/guardrails/src/guardrail_executor.dart:260`).
- **Data flow**: `main_overlay_capture_fixture` verifies selected move enters
  main capture and not overlay capture
  (`test/frame/fixtures/main_overlay_capture_fixture.dart:147`,
  `test/frame/fixtures/main_overlay_capture_fixture.dart:154`,
  `test/frame/fixtures/main_overlay_capture_fixture.dart:155`). The marquee
  style fixture verifies captured style enters primitive and painter output
  (`test/frame/fixtures/marquee_captured_style_fixture.dart:14`,
  `test/frame/fixtures/marquee_captured_style_fixture.dart:21`,
  `test/frame/fixtures/marquee_captured_style_fixture.dart:26`).

### 14. Interaction Contract And Diagrams

- **Location**: `docs/contracts/interaction_engine.md:86`
- **Description**: The contract describes the target pointer session lifecycle:
  one active routed pointer, normalized samples, stale terminal cleanup only,
  cleanup requests returned to `InteractionEngine`, query ports for committed
  facts, and commits only through `EditKernel`
  (`docs/contracts/interaction_engine.md:104`,
  `docs/contracts/interaction_engine.md:109`,
  `docs/contracts/interaction_engine.md:110`,
  `docs/contracts/interaction_engine.md:114`,
  `docs/contracts/interaction_engine.md:117`,
  `docs/contracts/interaction_engine.md:124`).
- **Dependencies**: The target `PointerToolCleanupCoordinator` is specified as
  `lib/src/interaction/pointer_tool_cleanup_coordinator.dart`
  (`docs/contracts/interaction_engine.md:153`,
  `docs/contracts/interaction_engine.md:155`,
  `docs/contracts/interaction_engine.md:157`).
- **Data flow**: The contract maps preview repaint targets and classifies
  `CanvasSelectedMovePreview` as main scene only
  (`docs/contracts/interaction_engine.md:204`,
  `docs/contracts/interaction_engine.md:212`,
  `docs/contracts/interaction_engine.md:220`). P10 diagrams describe selected
  move preview/commit (`docs/diagrams/seq_selected_move_preview_commit.mmd:49`,
  `docs/diagrams/seq_selected_move_preview_commit.mmd:158`,
  `docs/diagrams/seq_selected_move_preview_commit.mmd:191`), marquee selection
  (`docs/diagrams/seq_marquee_select.mmd:45`,
  `docs/diagrams/seq_marquee_select.mmd:90`), selected move state
  (`docs/diagrams/state_selected_move.mmd:29`,
  `docs/diagrams/state_selected_move.mmd:69`), marquee state
  (`docs/diagrams/state_select_marquee.mmd:26`,
  `docs/diagrams/state_select_marquee.mmd:77`), and generic pointer session
  cleanup (`docs/diagrams/state_pointer_session.mmd:30`,
  `docs/diagrams/state_pointer_session.mmd:112`).

### 15. Donor Materials Relevant To P10

- **Location**: `docs/donors/06_interaction_edit_event_staged_load.md:13`
- **Description**: Interaction/edit/staged-load donors list P10-relevant legacy
  behaviors: finite admission and terminal release in `finally`
  (`docs/donors/06_interaction_edit_event_staged_load.md:15`), pointer session
  detach/dispose and pending tap timer (`docs/donors/06_interaction_edit_event_staged_load.md:16`),
  non-finite sample filtering and terminal recovery
  (`docs/donors/06_interaction_edit_event_staged_load.md:17`), dispatch order and
  terminal cleanup (`docs/donors/06_interaction_edit_event_staged_load.md:20`),
  move preview/marquee selection/commit-on-up/cancel restore
  (`docs/donors/06_interaction_edit_event_staged_load.md:21`), mutation boundary
  into committed writes (`docs/donors/06_interaction_edit_event_staged_load.md:23`),
  and staged load validate/materialize-first plus interrupt-before-apply
  (`docs/donors/06_interaction_edit_event_staged_load.md:24`).
- **Dependencies**: Donor index maps `interaction_move_session` to P10 and to
  "Move and marquee interaction machines using SelectionKernel query ports"
  (`docs/indexes/donor_to_phase.md:342`,
  `docs/indexes/donor_to_phase.md:345`,
  `docs/indexes/donor_to_phase.md:346`). It maps pointer session, normalizer,
  event dispatcher, gesture runtime, mutation boundary, and staged load to P10
  as well (`docs/indexes/donor_to_phase.md:312`,
  `docs/indexes/donor_to_phase.md:318`,
  `docs/indexes/donor_to_phase.md:324`,
  `docs/indexes/donor_to_phase.md:336`,
  `docs/indexes/donor_to_phase.md:354`,
  `docs/indexes/donor_to_phase.md:360`).
- **Data flow**: The donor-to-avoid list marks legacy controller facade,
  interactive runtime whole, scene builder public architecture, scene codec
  whole, and scene store controller whole as non-structure donors
  (`docs/donors/07_donors_to_avoid.md:13`,
  `docs/donors/07_donors_to_avoid.md:15`,
  `docs/donors/07_donors_to_avoid.md:17`,
  `docs/donors/07_donors_to_avoid.md:19`,
  `docs/donors/07_donors_to_avoid.md:21`).

### 16. Current Interaction-Layer Absence

- **Location**: `lib/src/api/canvas_runtime.dart:41`
- **Description**: Public `CanvasRuntime.tools`, `commands`, and
  `contextActionRequests` are current placeholders that throw
  `UnimplementedError` (`lib/src/api/canvas_runtime.dart:41`,
  `lib/src/api/canvas_runtime.dart:42`,
  `lib/src/api/canvas_runtime.dart:47`).
- **Dependencies**: Runtime currently owns selection, edit, frame, resources,
  spatial, and load cleanup composition, but imports no interaction production
  owner (`lib/src/runtime/runtime_root.dart:13`,
  `lib/src/runtime/runtime_root.dart:41`,
  `lib/src/runtime/runtime_root.dart:43`).
- **Data flow**: No production action emission was found; `_actions` is created
  and exposed (`lib/src/runtime/runtime_root.dart:116`,
  `lib/src/runtime/runtime_root.dart:156`), but searches found no `_actions.add`
  or `add(CanvasActionCommitted(...))` calls under `lib/src`.

### 17. Guardrail State For Interaction Boundaries

- **Location**: `tool/guardrails/src/core_boundary_checks.dart:683`
- **Description**: Core import-boundary rules already include future
  `lib/src/interaction/` restrictions against concrete store and selection
  imports (`tool/guardrails/src/core_boundary_checks.dart:683`,
  `tool/guardrails/src/core_boundary_checks.dart:685`,
  `tool/guardrails/src/core_boundary_checks.dart:686`,
  `tool/guardrails/src/core_boundary_checks.dart:688`,
  `tool/guardrails/src/core_boundary_checks.dart:690`).
- **Dependencies**: The same file has path-specific restrictions for future
  `interaction_read_port.dart` and `pointer_tool_cleanup_coordinator.dart`
  (`tool/guardrails/src/core_boundary_checks.dart:693`,
  `tool/guardrails/src/core_boundary_checks.dart:704`).
- **Data flow**: Negative fixtures exercise those future paths
  (`test/guardrails/core_boundary_negative_fixtures_test.dart:98`,
  `test/guardrails/core_boundary_negative_fixtures_test.dart:103`,
  `test/guardrails/core_boundary_negative_fixtures_test.dart:118`,
  `test/guardrails/core_boundary_negative_fixtures_test.dart:123`). Searches
  found no runner-backed implementations for P10-specific interaction guardrail
  ids such as `interaction.no_resolver_on_cancel_paths`,
  `interaction.no_stale_terminal_commit`, or
  `interaction.pointer_cleanup_coordinator_only`.

## Code References

- `docs/implementation/p10_selection_and_move.md:11` - P10 build scope includes
  selection API, pointer lifecycle, cleanup coordinator, machines, selected move
  preview, resolver rules, action payloads, and load ordering.
- `lib/src/contracts/public/canvas_runtime.dart:197` - public
  `CanvasSelectionPort`.
- `lib/src/selection/selection_kernel.dart:7` - internal selection owner.
- `lib/src/contracts/internal/selection_facts_port.dart:3` - immutable
  `SelectionFacts` read boundary.
- `lib/src/contracts/internal/selection_membership_port.dart:3` - membership
  normalization boundary used by `SelectionKernel`.
- `lib/src/runtime/runtime_root.dart:98` - runtime composes
  `SelectionKernel`.
- `lib/src/runtime/runtime_root.dart:560` - current loadDocument install and
  cleanup ordering.
- `lib/src/contracts/internal/load_interaction_boundary.dart:1` - current
  minimal `PointerCleanupOutcome`.
- `lib/src/frame/frame_capture_service.dart:28` - selected move captured into
  main frame.
- `lib/src/frame/overlay_preview_planner.dart:108` - selected move excluded
  from overlay, marquee admitted to overlay primitive.
- `lib/src/frame/selected_move_supplement_planner.dart:58` - frame-side
  selected-move supplement staging.
- `docs/contracts/interaction_engine.md:153` - target cleanup coordinator
  contract.
- `docs/donors/06_interaction_edit_event_staged_load.md:21` - move/marquee
  donor behavior.

## Search Coverage

- **Inspected**: `docs/implementation/p10_selection_and_move.md` completely;
  `lib/src/selection/selection_kernel.dart` completely;
  `lib/src/contracts/internal/selection_facts_port.dart` completely;
  `lib/src/contracts/internal/selection_membership_port.dart` completely;
  `lib/src/store/revision_state.dart` completely;
  `lib/src/store/store_revision_delta.dart` completely;
  `lib/src/edit/edit_kernel.dart` completely;
  `lib/src/edit/staged_document_load.dart` completely;
  `lib/src/contracts/internal/commit_delivery.dart` completely;
  `lib/src/contracts/internal/load_interaction_boundary.dart` completely;
  `lib/src/runtime/noop_load_interaction_boundary.dart` completely;
  `lib/src/runtime/runtime_root.dart` completely; `lib/src/frame/frame_capture_service.dart`
  completely; `lib/src/frame/frame_engine.dart` completely;
  `lib/src/frame/overlay_preview_planner.dart` completely;
  `lib/src/frame/selected_move_supplement_planner.dart` completely; selected
  ranges of public contracts, runtime/load/frame tests, guardrails, diagrams,
  and donor docs cited above.
- **Searched**: `rg -n "CanvasSelectionPort|SelectionKernel|selectionRevision|documentRevision|CanvasSelectedMovePreview|PointerToolCleanupCoordinator|PointerCleanupOutcome|InteractionEngine|MoveResolver|resolver|marquee|selected move|selectedMove|loadDocument|staged|prepared cleanup|cleanup" lib docs test tool plan -g '!legacy/**'`; `find lib/src -maxdepth 2 -type d`; `find test -maxdepth 2 -type d`; `rg --files lib/src/interaction test/interaction tool/guardrails/src test/guardrails`; `rg -n "PointerToolCleanupCoordinator|class PointerToolCleanupCoordinator" lib/src test tool/guardrails/src`; `rg -n "\b(final class|class|abstract interface class)\s+InteractionEngine\b|\bInteractionEngine\b" lib/src test tool/guardrails/src`; `rg -n "PointerSession|PointerNormalizer|normalize.*Pointer|normalized.*Pointer|CanvasPointerSample.*normalize|PointerCleanupRequest|CleanupRequest|SelectedMoveState|MarqueeState|MoveState|eraser_context_action_routing|no_stale_terminal_commit|no_resolver_on_cancel_paths" lib/src test tool/guardrails/src`; `rg -n "_actions\.add|\.add\(CanvasActionCommitted\(" lib/src`; `rg -n "interaction\.no_concrete_store_imports|interaction\.no_concrete_selection_imports|interaction\.no_resolver_on_cancel_paths|interaction\.no_stale_terminal_commit|interaction\.pointer_cleanup_coordinator_only|events\.commands_emit_user_actions|events\.runtime_created_timestamps_monotonic|surface\.pointer_samples_normalized_before_runtime|surface\.interactive_false_pending_line_preserved" tool/guardrails/src test/guardrails`.
- **Not found**: No `lib/src/interaction/` directory; no `test/interaction/`
  directory; no production `InteractionEngine`; no production
  `PointerToolCleanupCoordinator`; no pointer session or pointer normalizer
  symbols; no selected-move/marquee machines; no production action emission call
  to `_actions.add`; no runner-backed implementations for the P10-specific
  interaction guardrail ids searched above.
- **Not inspected**: Legacy source files under `legacy/**` were not opened
  directly. Donor relevance was taken from current repository donor
  documentation and indexes, because the research question asks which donor
  materials in `docs/donors` are relevant for transfer.

## Observed Architecture Facts

- Pattern observed: selection ownership is runtime-local and separated from
  committed document state. `SelectionKernel` owns selected ids and
  `selectionRevision` (`lib/src/selection/selection_kernel.dart:12`), while
  `RevisionState` owns document-family revisions only
  (`lib/src/store/revision_state.dart:13`).
- Pattern observed: selection-only public calls publish runtime state without
  document/projection/spatial effects. Runtime calls `_publishSelectionChange`
  after selection changes (`lib/src/runtime/runtime_root.dart:412`,
  `lib/src/runtime/runtime_root.dart:540`), and the selection fixture verifies
  unchanged document revision and projection reuse
  (`test/selection/fixtures/runtime_owner_separation_fixture.dart:62`,
  `test/selection/fixtures/runtime_owner_separation_fixture.dart:66`).
- Data flow: public `CanvasRuntime.edits` -> `RuntimeRoot.edits` ->
  `EditKernel.port` -> `EditKernel.loadDocument` -> `RuntimeRoot._loadDocument`
  (`lib/src/api/canvas_runtime.dart:39`,
  `lib/src/runtime/runtime_root.dart:155`,
  `lib/src/edit/edit_kernel.dart:107`,
  `lib/src/runtime/runtime_root.dart:560`).
- Data flow: selected move preview -> `FrameCaptureService.captureMainFrame` ->
  `SelectedMoveSupplementPlanner` -> `FrameEngine` main repaint signal
  (`lib/src/frame/frame_capture_service.dart:33`,
  `lib/src/frame/selected_move_supplement_planner.dart:58`,
  `lib/src/frame/frame_engine.dart:99`,
  `lib/src/frame/frame_engine.dart:183`).
- Data flow: marquee preview -> `FrameCaptureService.captureOverlayFrame` ->
  `OverlayPreviewPlanner` -> `OverlayFramePainter`
  (`lib/src/frame/frame_capture_service.dart:40`,
  `lib/src/frame/overlay_preview_planner.dart:113`,
  `lib/src/frame/overlay_frame_painter.dart:31`).
- Key dependency: P10 interaction contracts require query-port reads and
  `EditKernel` commits only (`docs/contracts/interaction_engine.md:117`,
  `docs/contracts/interaction_engine.md:124`), but no production interaction
  owner exists in current `lib/src`.

## Open Questions

- No additional open research questions remain for this snapshot. The confirmed
  absences above identify the current implementation gaps relative to the P10
  scope.
