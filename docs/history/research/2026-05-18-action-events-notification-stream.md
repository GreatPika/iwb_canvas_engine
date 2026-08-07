---
date: 2026-05-18
researcher: Codex
commit: bf89178
branch: new-architecture
research_question: "Action events as a user-action notification stream, not an undo/redo journal"
---

# Research: Action Events Notification Stream

## Summary

The repository root is the active architecture rebuild target, and the new engine is described through `docs/` rather than the legacy package (`AGENTS.md:3`, `AGENTS.md:5`). In the current public API v1 contract, `CanvasRuntime` exposes `Stream<CanvasActionCommitted> get actions` (`docs/contracts/public_api_v1.md:341`), and `CanvasActionCommitted` is a public event record with an action id, type, affected element ids, timestamp, and typed payload (`docs/contracts/public_api_v1.md:1744`, `docs/contracts/public_api_v1.md:1757`).

The current v1 documentation mostly treats action output as user-action events or notifications emitted by high-level commands and interaction commits after atomic install. Low-level `CanvasEdit` operations, programmatic edits, no-ops, rollback, load, resource dirty, view settings, and dispose paths are documented as not emitting action events (`docs/contracts/public_api_v1.md:1205`, `docs/contracts/public_api_v1.md:1213`, `docs/contracts/public_api_v1.md:1887`, `docs/contracts/public_api_v1.md:1910`). One line in the public API contract still names the app stream an `undo/redo action stream` (`docs/contracts/public_api_v1.md:1245`).

Legacy code and legacy docs contain the older undo/redo wording. The legacy `ActionType` comment says interactive controllers emit discrete actions for app-level undo/redo (`legacy/iwb_canvas_engine/lib/src/core/action_events.dart:7`), while the legacy README/API/architecture state that app-level undo/redo storage is host/application-owned (`legacy/iwb_canvas_engine/README.md:29`, `legacy/iwb_canvas_engine/README.md:33`, `legacy/iwb_canvas_engine/API_GUIDE.md:26`, `legacy/iwb_canvas_engine/API_GUIDE.md:31`, `legacy/iwb_canvas_engine/ARCHITECTURE.md:52`, `legacy/iwb_canvas_engine/ARCHITECTURE.md:59`).

## Detailed Findings

### 1. Public Runtime Action Stream

- **Location**: primary `docs/contracts/public_api_v1.md:341`; registry at `docs/_registry/public_api_v1.yaml:74`.
- **Description**: `CanvasRuntime` declares `Stream<CanvasActionCommitted> get actions` as part of the public runtime surface (`docs/contracts/public_api_v1.md:330`, `docs/contracts/public_api_v1.md:341`). The public export registry includes `CanvasActionCommitted`, `CanvasActionType`, `CanvasActionPayload`, and the typed action payload classes (`docs/_registry/public_api_v1.yaml:74`, `docs/_registry/public_api_v1.yaml:85`).
- **Dependencies**: The markdown contract owns public API semantics, signature rules, and declaration contracts, while the YAML registry is the machine-readable exported-name inventory (`docs/contracts/public_api_v1.md:79`, `docs/contracts/public_api_v1.md:84`; `docs/_registry/public_api_v1.yaml:1`, `docs/_registry/public_api_v1.yaml:2`).
- **Data flow**: Runtime produces committed action records -> applications subscribe to `actions` -> `dispose` closes the actions stream (`docs/contracts/public_api_v1.md:341`, `docs/contracts/public_api_v1.md:368`).

### 2. Action Event Shape And Payload Content

- **Location**: primary `docs/contracts/public_api_v1.md:1744`.
- **Description**: `CanvasActionCommitted` constructor input consists of `actionId`, `type`, `elementIds`, `timestampMs`, and `payload`; the public fields expose the same record facts (`docs/contracts/public_api_v1.md:1744`, `docs/contracts/public_api_v1.md:1757`). The payload base type is `sealed class CanvasActionPayload` (`docs/contracts/public_api_v1.md:1760`).
- **Dependencies**: The event record uses `CanvasActionId`, `CanvasActionType`, `CanvasElementId`, and `CanvasActionPayload` (`docs/contracts/public_api_v1.md:1753`, `docs/contracts/public_api_v1.md:1757`). `CanvasActionCommitted` and action payload family types use default identity equality, and the contract groups these objects with operation records and event records (`docs/contracts/public_api_v1.md:173`, `docs/contracts/public_api_v1.md:188`, `docs/contracts/public_api_v1.md:194`, `docs/contracts/public_api_v1.md:199`).
- **Data flow**: Constructor input -> defensive copies for collection-bearing fields -> public event record on the runtime stream (`docs/contracts/public_api_v1.md:1744`, `docs/contracts/public_api_v1.md:1757`, `docs/contracts/public_api_v1.md:1873`, `docs/contracts/public_api_v1.md:1885`). `CanvasTextEditActionPayload` carries request id and text lengths, and the payload rules say it never carries raw previous or next text content (`docs/contracts/public_api_v1.md:1860`, `docs/contracts/public_api_v1.md:1870`, `docs/contracts/public_api_v1.md:1882`).

### 3. Event Emission Matrix

- **Location**: primary `docs/contracts/public_api_v1.md:1887`.
- **Description**: The public contract has an event emission matrix with columns for operation, whether an action emits, action type, and payload (`docs/contracts/public_api_v1.md:1887`, `docs/contracts/public_api_v1.md:1890`). Programmatic add/update, `CanvasEdit.removeElement`, `CanvasEdit.clearContent`, and API selection setting emit no action (`docs/contracts/public_api_v1.md:1891`, `docs/contracts/public_api_v1.md:1897`).
- **Dependencies**: High-level command remove/clear, marquee selection, selected move, selection transforms, delete selection, drawing tools, eraser, and changed guarded text edit commits are the paths that can emit typed actions (`docs/contracts/public_api_v1.md:1895`, `docs/contracts/public_api_v1.md:1906`). Stale/no-op text edit, `loadDocument`, camera/background/grid/palette changes, and `markResourceDirty` emit no action (`docs/contracts/public_api_v1.md:1907`, `docs/contracts/public_api_v1.md:1910`).
- **Data flow**: Operation -> high-level or interaction commit decision -> typed `CanvasActionCommitted` output only for matrix rows that say `yes` (`docs/contracts/public_api_v1.md:1887`, `docs/contracts/public_api_v1.md:1910`).

### 4. Low-Level Edit And Atomic Install Semantics

- **Location**: primary `docs/contracts/public_api_v1.md:1201`.
- **Description**: The edit contract says callbacks are synchronous, draft mutations are atomic, callback exceptions roll back document/resources/selection-owner changes, signals, and repaint, and public notifications occur only after atomic install (`docs/contracts/public_api_v1.md:1201`, `docs/contracts/public_api_v1.md:1206`). The same contract says `CanvasEdit.removeElement` and `CanvasEdit.clearContent` are low-level document edits and emit no user action event (`docs/contracts/public_api_v1.md:1213`, `docs/contracts/public_api_v1.md:1214`).
- **Dependencies**: P5 documents rollback without committed state, revision, event, repaint, resource, spatial, preview, or projection side effects (`docs/implementation/p5_edit_core.md:20`, `docs/implementation/p5_edit_core.md:23`). P5 also lists low-level edit no-action behavior as a phase scope item and exit-gate fact (`docs/implementation/p5_edit_core.md:22`, `docs/implementation/p5_edit_core.md:104`).
- **Data flow**: Low-level edit callback -> draft mutation -> atomic install/public notifications when changed -> no user action event from low-level `CanvasEdit` rows (`docs/contracts/public_api_v1.md:1204`, `docs/contracts/public_api_v1.md:1206`, `docs/contracts/public_api_v1.md:1213`, `docs/contracts/public_api_v1.md:1214`).

### 5. High-Level Commands And Notification Wording

- **Location**: primary `docs/contracts/public_api_v1.md:1242`.
- **Description**: The high-level command section describes commands as public user-intent operations that use EditKernel for atomic mutation and own user action event emission (`docs/contracts/public_api_v1.md:1242`, `docs/contracts/public_api_v1.md:1244`). The same paragraph says this keeps low-level `CanvasEdit` usable for programmatic synchronization without polluting the app's `undo/redo action stream` (`docs/contracts/public_api_v1.md:1244`, `docs/contracts/public_api_v1.md:1245`).
- **Dependencies**: Verification guardrails map `events.low_level_edit_no_user_actions` to low-level remove/clear emitting no user action events, and `events.commands_emit_user_actions` to high-level commands and interaction commits owning user action events (`docs/verification/guardrails.md:165`, `docs/verification/guardrails.md:166`). The guardrail index uses the same rule and calls changed `commitTextEdit` commits `editText` notifications (`docs/indexes/by_guardrail.md:157`, `docs/indexes/by_guardrail.md:164`).
- **Data flow**: Command or interaction commit -> EditKernel atomic mutation -> command/interaction owner emits user action event after install (`docs/contracts/public_api_v1.md:1242`, `docs/contracts/public_api_v1.md:1244`; `docs/indexes/by_test_area.md:158`, `docs/indexes/by_test_area.md:159`).

### 6. Diagrams For Commit, No-Op, Rollback, And Dispose

- **Location**: primary `docs/diagrams/dfd_pointer_preview_commit.mmd:60`.
- **Description**: The pointer preview/commit data-flow diagram names `Actions` as typed user action events only when terminal commit changes state (`docs/diagrams/dfd_pointer_preview_commit.mmd:60`). It shows atomic install publishing changed terminal action to `Actions`, and rollback leaving committed document, selection, revisions, and action events unchanged (`docs/diagrams/dfd_pointer_preview_commit.mmd:116`, `docs/diagrams/dfd_pointer_preview_commit.mmd:121`).
- **Dependencies**: The successful edit sequence stages a commit event buffer and notes that low-level `CanvasEdit` commits stage no user action events (`docs/diagrams/seq_edit_success.mmd:49`, `docs/diagrams/seq_edit_success.mmd:50`). The rollback sequence discards buffered events/effects and publishes no action event (`docs/diagrams/seq_edit_rollback.mmd:56`, `docs/diagrams/seq_edit_rollback.mmd:63`).
- **Data flow**: Interaction commit intent -> EditKernel draft/compile -> atomic install -> action notification only on changed terminal commit; rollback/no-op paths leave action output unchanged (`docs/diagrams/dfd_pointer_preview_commit.mmd:104`, `docs/diagrams/dfd_pointer_preview_commit.mmd:116`, `docs/diagrams/dfd_pointer_preview_commit.mmd:121`).

### 7. Diagram-Level Action Notifications

- **Location**: primary `docs/diagrams/seq_selected_move_preview_commit.mmd:168`.
- **Description**: Several sequence diagrams use notification wording when publishing actions: selected move publishes a move action notification (`docs/diagrams/seq_selected_move_preview_commit.mmd:168`), marquee publishes a `selectMarquee` action notification (`docs/diagrams/seq_marquee_select.mmd:125`), pencil/marker publishes a draw action notification (`docs/diagrams/seq_pencil_marker_commit.mmd:126`), line publishes a `drawLine` action notification (`docs/diagrams/seq_line_two_tap_commit.mmd:151`), and eraser publishes an erase action notification (`docs/diagrams/seq_eraser_commit.mmd:169`).
- **Dependencies**: These notifications are paired with materializing or staging `CanvasActionCommitted` after install or at the commit boundary (`docs/diagrams/seq_selected_move_preview_commit.mmd:140`, `docs/diagrams/seq_selected_move_preview_commit.mmd:154`; `docs/diagrams/seq_pencil_marker_commit.mmd:116`; `docs/diagrams/seq_line_two_tap_commit.mmd:141`; `docs/diagrams/seq_eraser_commit.mmd:159`).
- **Data flow**: Successful terminal commit -> materialize or stage `CanvasActionCommitted` -> publish action notification to public signals (`docs/diagrams/seq_pencil_marker_commit.mmd:116`, `docs/diagrams/seq_pencil_marker_commit.mmd:126`; `docs/diagrams/seq_eraser_commit.mmd:159`, `docs/diagrams/seq_eraser_commit.mmd:169`).

### 8. Text Edit Notification Shape

- **Location**: primary `plan/step_10_interaction_request_text_edit_stale_guard.md:33`.
- **Description**: Step 10 describes successful changed text commits as EditKernel-backed document edits with user-action notification semantics, and it adds a text-edit action notification shape without raw text content (`plan/step_10_interaction_request_text_edit_stale_guard.md:33`, `plan/step_10_interaction_request_text_edit_stale_guard.md:35`). Its decision table says changed text commits emit `editText` action notifications without raw text content (`plan/step_10_interaction_request_text_edit_stale_guard.md:382`).
- **Dependencies**: The public API contract defines `CanvasTextEditActionPayload` with request id, previous text length, and next text length (`docs/contracts/public_api_v1.md:1860`, `docs/contracts/public_api_v1.md:1870`). The payload rules say raw previous or next text content is not carried (`docs/contracts/public_api_v1.md:1882`, `docs/contracts/public_api_v1.md:1883`).
- **Data flow**: Changed guarded text commit -> `editText` action notification -> payload carries request id and text lengths only (`docs/contracts/public_api_v1.md:1906`, `docs/contracts/public_api_v1.md:1860`, `docs/contracts/public_api_v1.md:1870`).

### 9. Lifecycle And Non-Emission Cases

- **Location**: primary `docs/contracts/public_api_v1.md:362`.
- **Description**: Dispose is idempotent, closes the actions and text edit streams, does not increment committed document revision by itself, and delivers no further state notifications after it returns (`docs/contracts/public_api_v1.md:362`, `docs/contracts/public_api_v1.md:376`). The dispose-during-gesture diagram says dispose closes the `CanvasActionCommitted` stream and emits no `CanvasActionCommitted` or text edit request (`docs/diagrams/seq_dispose_during_gesture.mmd:72`, `docs/diagrams/seq_dispose_during_gesture.mmd:83`).
- **Dependencies**: Successful load publishes runtime state after install while emitting no `CanvasActionCommitted`, and failed load emits no `CanvasActionCommitted`, text edit event, repaint, or public state publication (`docs/diagrams/seq_load_document_success.mmd:70`, `docs/diagrams/seq_load_document_failure.mmd:54`). Resource dirty and preview-only pointer changes are verified as not emitting action events (`docs/verification/tests.md:383`, `docs/verification/tests.md:392`).
- **Data flow**: Lifecycle/no-op/resource/preview-only operations -> public state or stream lifecycle behavior as documented -> no `CanvasActionCommitted` output for the listed paths (`docs/contracts/public_api_v1.md:368`, `docs/diagrams/seq_load_document_success.mmd:70`, `docs/verification/tests.md:386`, `docs/verification/tests.md:392`).

### 10. Legacy Action Stream And Undo/Redo Wording

- **Location**: primary `legacy/iwb_canvas_engine/lib/src/core/action_events.dart:7`.
- **Description**: Legacy `ActionType` is documented as discrete actions emitted by interactive controllers for app-level undo/redo (`legacy/iwb_canvas_engine/lib/src/core/action_events.dart:7`). Legacy `ActionCommitted` stores `actionId`, `type`, `nodeIds`, `timestampMs`, and optional `payload` (`legacy/iwb_canvas_engine/lib/src/core/action_events.dart:40`, `legacy/iwb_canvas_engine/lib/src/core/action_events.dart:78`).
- **Dependencies**: Legacy public docs list application-level or app-level undo/redo storage as a host-owned concern rather than scene graph ownership (`legacy/iwb_canvas_engine/README.md:29`, `legacy/iwb_canvas_engine/README.md:33`; `legacy/iwb_canvas_engine/API_GUIDE.md:26`, `legacy/iwb_canvas_engine/API_GUIDE.md:31`; `legacy/iwb_canvas_engine/ARCHITECTURE.md:52`, `legacy/iwb_canvas_engine/ARCHITECTURE.md:59`).
- **Data flow**: Legacy interactive controllers -> `InteractiveEventDispatcher` broadcast action stream -> public `SceneController.actions` delegation (`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:8`, `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:18`, `legacy/iwb_canvas_engine/lib/src/interactive/scene_controller.dart:75`).

### 11. Legacy Async Notification Behavior

- **Location**: primary `legacy/iwb_canvas_engine/API_GUIDE.md:396`.
- **Description**: The legacy API guide says `SceneController`, `actions`, and `editTextRequests` are asynchronous from an integration point of view, and that notifications are deferred/coalesced rather than emitted inline from every mutation call (`legacy/iwb_canvas_engine/API_GUIDE.md:396`, `legacy/iwb_canvas_engine/API_GUIDE.md:406`). Migration notes say to treat `actions`, `editTextRequests`, and controller notifications as asynchronous integration signals (`legacy/iwb_canvas_engine/API_GUIDE.md:591`, `legacy/iwb_canvas_engine/API_GUIDE.md:607`).
- **Dependencies**: Legacy tests verify action stream delivery after event-queue pumping for `removeNode`, and verify no immediate trace ordering guarantee between action and notify callbacks (`legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:715`, `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:741`, `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:744`, `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:779`).
- **Data flow**: Legacy mutation call -> deferred stream/controller notifications -> application observes action/notify asynchronously after event queue progress (`legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:715`, `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:779`).

### 12. Redesign Note In Repository

- **Location**: primary `redesign.md:1`.
- **Description**: `redesign.md` contains a section about action events as a notification stream rather than undo/redo (`redesign.md:1`). It states that action event payloads do not contain enough data for full undo/redo (`redesign.md:3`) and gives replacement contract wording: `CanvasActionCommitted is a user-action notification stream`, `It is not an undo/redo journal`, and `Undo/redo is application-owned` (`redesign.md:8`, `redesign.md:10`).
- **Dependencies**: The note lists public event uses as analytics, application notifications, toolbar state, domain reactions, and external logging (`redesign.md:15`, `redesign.md:20`). It names the documentation phrase `app's undo/redo action stream` and the replacement phrase `app's user-action notification stream` (`redesign.md:26`, `redesign.md:32`).
- **Data flow**: Existing documented phrase -> replacement wording in the redesign note -> payloads remain unchanged for v1 without inverse patches (`redesign.md:23`, `redesign.md:35`).

## Code References

- `AGENTS.md:3` - repository root is the canonical architecture rebuild target package.
- `AGENTS.md:5` - new engine is described in `docs/`, with `docs/README.md` as the entry point.
- `docs/contracts/public_api_v1.md:341` - public runtime exposes `Stream<CanvasActionCommitted> get actions`.
- `docs/contracts/public_api_v1.md:368` - dispose closes the actions stream.
- `docs/contracts/public_api_v1.md:1206` - public notifications occur only after atomic install.
- `docs/contracts/public_api_v1.md:1213` - `CanvasEdit.removeElement` emits no user action event.
- `docs/contracts/public_api_v1.md:1214` - `CanvasEdit.clearContent` emits no user action event.
- `docs/contracts/public_api_v1.md:1242` - high-level commands are public user-intent operations.
- `docs/contracts/public_api_v1.md:1244` - high-level commands own user action event emission.
- `docs/contracts/public_api_v1.md:1245` - current contract uses the phrase `undo/redo action stream`.
- `docs/contracts/public_api_v1.md:1744` - `CanvasActionCommitted` class declaration.
- `docs/contracts/public_api_v1.md:1757` - `CanvasActionCommitted` public payload field.
- `docs/contracts/public_api_v1.md:1882` - text edit action payload does not carry raw previous or next text content.
- `docs/contracts/public_api_v1.md:1887` - event emission matrix begins.
- `docs/contracts/public_api_v1.md:1910` - matrix lists non-emitting resource dirty path.
- `docs/_registry/public_api_v1.yaml:74` - public export registry includes `CanvasActionCommitted`.
- `docs/_registry/public_api_v1.yaml:85` - public export registry includes `CanvasTextEditActionPayload`.
- `docs/implementation/p5_edit_core.md:22` - low-level remove/clear emit no user action events.
- `docs/implementation/p5_edit_core.md:104` - P5 exit gate repeats low-level no-action behavior.
- `docs/indexes/by_guardrail.md:157` - guardrail index maps low-level edits to no user action events.
- `docs/indexes/by_guardrail.md:164` - changed `commitTextEdit` commits are named `editText` notifications.
- `docs/indexes/by_test_area.md:159` - high-level commands and changed commits emit user action notifications only after atomic install.
- `docs/verification/guardrails.md:165` - guardrail table states low-level remove/clear emit no user action events.
- `docs/verification/guardrails.md:166` - guardrail table states high-level commands and interaction commits own user action events.
- `docs/verification/functional_ledger.md:67` - functional ledger maps action committed event to `CanvasActionCommitted` typed payloads.
- `docs/diagrams/dfd_pointer_preview_commit.mmd:60` - typed user action events happen only when terminal commit changes state.
- `docs/diagrams/dfd_pointer_preview_commit.mmd:121` - rollback leaves action events unchanged.
- `docs/diagrams/seq_edit_success.mmd:50` - low-level `CanvasEdit` commits stage no user action events.
- `docs/diagrams/seq_edit_rollback.mmd:63` - rollback publishes no action event.
- `docs/diagrams/seq_selected_move_preview_commit.mmd:168` - selected move publishes a move action notification.
- `docs/diagrams/seq_marquee_select.mmd:125` - marquee publishes a `selectMarquee` action notification.
- `docs/diagrams/seq_pencil_marker_commit.mmd:126` - pencil/marker publishes a draw action notification.
- `docs/diagrams/seq_line_two_tap_commit.mmd:151` - line commit publishes a `drawLine` action notification.
- `docs/diagrams/seq_eraser_commit.mmd:169` - eraser commit publishes an erase action notification.
- `docs/diagrams/seq_text_edit_request.mmd:88` - changed text publishes `editText` action after atomic install.
- `docs/diagrams/seq_dispose_during_gesture.mmd:83` - dispose emits no `CanvasActionCommitted`.
- `docs/diagrams/seq_load_document_success.mmd:70` - successful load emits no `CanvasActionCommitted`.
- `docs/diagrams/seq_load_document_failure.mmd:54` - failed load emits no `CanvasActionCommitted`.
- `plan/step_10_interaction_request_text_edit_stale_guard.md:33` - changed text commits use user-action notification semantics.
- `plan/step_10_interaction_request_text_edit_stale_guard.md:382` - changed text commits emit `editText` notifications without raw text content.
- `plan/step_6_public_runtime_state_and_view_camera_ownership.md:435` - view camera navigation avoids implying undo/redo work.
- `legacy/iwb_canvas_engine/lib/src/core/action_events.dart:7` - legacy action events are described as app-level undo/redo events.
- `legacy/iwb_canvas_engine/lib/src/core/action_events.dart:40` - legacy `ActionCommitted` constructor input.
- `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:18` - legacy dispatcher exposes the actions stream.
- `legacy/iwb_canvas_engine/API_GUIDE.md:396` - legacy actions are asynchronous integration signals.
- `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:744` - legacy action/notify ordering test.
- `redesign.md:1` - repository note for action events as notification stream, not undo/redo.
- `redesign.md:35` - repository note says payloads are not expanded to inverse patches in v1.

## Observed Architecture Facts

- Pattern observed: public v1 separates low-level programmatic edits from high-level user-intent action events (`docs/contracts/public_api_v1.md:1213`, `docs/contracts/public_api_v1.md:1242`, `docs/contracts/public_api_v1.md:1244`).
- Pattern observed: action event publication is documented after atomic install for changed high-level or interaction commits (`docs/contracts/public_api_v1.md:1206`, `docs/indexes/by_test_area.md:159`, `docs/diagrams/dfd_pointer_preview_commit.mmd:116`).
- Pattern observed: rollback, no-op, dispose, load, preview-only, resource dirty, and low-level edit paths are documented as no-action paths (`docs/diagrams/seq_edit_rollback.mmd:63`, `docs/contracts/public_api_v1.md:1907`, `docs/contracts/public_api_v1.md:1910`, `docs/diagrams/seq_dispose_during_gesture.mmd:83`).
- Data flow: user-intent command or terminal interaction -> EditKernel atomic mutation -> typed `CanvasActionCommitted` notification when the event matrix allows it (`docs/contracts/public_api_v1.md:1242`, `docs/contracts/public_api_v1.md:1887`, `docs/contracts/public_api_v1.md:1906`).
- Data flow: low-level edit or non-user-action runtime operation -> state/revision/public notification behavior as applicable -> no `CanvasActionCommitted` output (`docs/contracts/public_api_v1.md:1213`, `docs/contracts/public_api_v1.md:1214`, `docs/contracts/public_api_v1.md:1908`, `docs/contracts/public_api_v1.md:1910`).
- Key dependency: the public export registry includes action event names, but contract semantics are owned by `docs/contracts/public_api_v1.md` (`docs/contracts/public_api_v1.md:79`, `docs/contracts/public_api_v1.md:84`; `docs/_registry/public_api_v1.yaml:74`, `docs/_registry/public_api_v1.yaml:85`).
- Legacy contrast: legacy source uses undo/redo wording for action events, while legacy product docs state app-level undo/redo storage is outside the package (`legacy/iwb_canvas_engine/lib/src/core/action_events.dart:7`, `legacy/iwb_canvas_engine/README.md:33`, `legacy/iwb_canvas_engine/API_GUIDE.md:31`, `legacy/iwb_canvas_engine/ARCHITECTURE.md:59`).

## Open Questions

No open questions were identified from the researched files.
