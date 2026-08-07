---
date: 2026-05-19
researcher: Codex
commit: 410ac5f
branch: new-architecture
research_question: "HOLE-010 — Monotonic runtime-created timestamps do not have explicit proof mapping"
---

# Research: Monotonic Runtime-Created Timestamps

## Summary

The legacy package has an explicit runtime timestamp concept centered on `timestampMs`.
For legacy action/text events, `ActionCommitted.timestampMs` and
`EditTextRequested.timestampMs` are documented as monotonic runtime timestamps in
milliseconds (`legacy/iwb_canvas_engine/lib/src/core/action_events.dart:74`,
`legacy/iwb_canvas_engine/lib/src/core/action_events.dart:93`). The allocator is
local to `InteractiveEventDispatcher`: it starts at `-1`, resolves null or
backwards hints to the next cursor value, accepts forward hints, and stores the
resolved value as the new cursor
(`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:15`,
`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:21`,
`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:23`,
`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:26`).

The new architecture documents timestamp-bearing public shapes and action-event
emission surfaces, but the exact mapping id
`runtime_created_timestamps_monotonic` appears only in the audit checklist
(`audit.md:42`). The legacy capability inventory records “runtime-created
timestamps are monotonic” (`docs/verification/legacy_capability_inventory.md:63`),
while the functional ledger maps the broader action event capability to
`CanvasActionCommitted` typed payloads and `functional.action_events`
(`docs/verification/functional_ledger.md:67`).

The root package currently has package metadata but no root `lib/` or `test/`
implementation tree found by the research search; `pubspec.yaml` defines the
package name and dependencies (`pubspec.yaml:1`, `pubspec.yaml:10`,
`pubspec.yaml:15`). Existing release gates and guardrails cover user-action
events generally, but do not name monotonic timestamp ordering as a separate
proof obligation (`docs/verification/guardrails.md:163`,
`docs/verification/release_gates.md:184`, `docs/verification/release_gates.md:197`).

## Detailed Findings

### 1. Legacy Timestamp Model

- **Location**: primary `legacy/iwb_canvas_engine/lib/src/core/action_events.dart:37`; additional references below.
- **Description**: `ActionCommitted` accepts a required `timestampMs`, stores it
  as a final field, and documents the field as a monotonic runtime timestamp in
  milliseconds (`legacy/iwb_canvas_engine/lib/src/core/action_events.dart:40`,
  `legacy/iwb_canvas_engine/lib/src/core/action_events.dart:44`,
  `legacy/iwb_canvas_engine/lib/src/core/action_events.dart:74`). `EditTextRequested`
  also accepts a required `timestampMs` and documents it with the same monotonic
  runtime wording (`legacy/iwb_canvas_engine/lib/src/core/action_events.dart:82`,
  `legacy/iwb_canvas_engine/lib/src/core/action_events.dart:86`,
  `legacy/iwb_canvas_engine/lib/src/core/action_events.dart:93`).
- **Dependencies**: `ActionCommitted` freezes node ids and payload collections
  through `freezeList` and `freezePayloadMap`, while `timestampMs` is passed
  through as the provided integer (`legacy/iwb_canvas_engine/lib/src/core/action_events.dart:47`,
  `legacy/iwb_canvas_engine/lib/src/core/action_events.dart:51`).
- **Data flow**: caller supplies or runtime resolves `timestampMs` -> event
  factory/constructor stores it -> stream observers receive the immutable event
  payload (`legacy/iwb_canvas_engine/lib/src/core/action_events.dart:44`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:38`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:42`).

### 2. Legacy Timestamp Creation And Normalization

- **Location**: primary `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:21`; additional references below.
- **Description**: `InteractiveEventDispatcher` owns `_timestampCursorMs` and
  `resolveTimestampMs`. The cursor starts at `-1`; `next` is cursor plus one;
  a null hint or a hint lower than `next` resolves to `next`; otherwise the hint
  is accepted, then `_timestampCursorMs` is updated to the resolved value
  (`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:15`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:21`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:23`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:26`).
- **Dependencies**: the same dispatcher owns both `StreamController<ActionCommitted>`
  and `StreamController<EditTextRequested>` (`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:8`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:9`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:11`).
- **Data flow**: nullable public/manual timestamp hint -> `resolveTimestampMs` ->
  normalized `PointerSample` or action/request timestamp -> emitted action or
  text request (`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_pointer_normalizer.dart:37`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_pointer_normalizer.dart:40`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_double_tap_router.dart:46`).

### 3. Legacy Time Sources And Monotonicity Scope

- **Location**: primary `legacy/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart:41`; additional references below.
- **Description**: Flutter-host pointer events create `PointerSample.timestampMs`
  from `event.timeStamp.inMilliseconds` (`legacy/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart:41`,
  `legacy/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart:46`,
  `legacy/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart:49`).
  Manual `CanvasPointerInput.timestampMs` is nullable and documented as an
  optional hint; when null, the controller assigns a monotonic internal timestamp
  (`legacy/iwb_canvas_engine/lib/src/contract/canvas_pointer_input.dart:19`,
  `legacy/iwb_canvas_engine/lib/src/contract/canvas_pointer_input.dart:21`).
- **Dependencies**: `PointerSample.timestampMs` is documented as a host-provided
  ordering hint that runtime controllers normalize before emitted actions/signals
  (`legacy/iwb_canvas_engine/lib/src/contract/pointer_input.dart:19`,
  `legacy/iwb_canvas_engine/lib/src/contract/pointer_input.dart:21`).
- **Data flow**: Flutter event timestamp or manual hint -> public pointer input
  -> `InteractivePointerNormalizer` -> runtime cursor normalization -> pointer
  sample used by gesture/event code (`legacy/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart:55`,
  `legacy/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart:59`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_pointer_normalizer.dart:40`).
- **Scope fact**: one `InteractiveEventDispatcher` is created when the interaction
  runtime is created, and that dispatcher is wired into the runtime object
  (`legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_interaction_runtime.dart:161`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_interaction_runtime.dart:169`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_interaction_runtime.dart:177`).
  This makes the observed legacy monotonic cursor scoped to the dispatcher/runtime
  instance, not to a documented global process clock.
- **Wall-clock rollback fact**: no separate wall-clock branch was found in the
  allocator; backwards timestamp input is handled by the same
  `hintTimestampMs < next` comparison
  (`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:21`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:23`).

### 4. Legacy Events And Operations Receiving Timestamps

- **Location**: primary `legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_mutation_boundary.dart:96`; additional references below.
- **Description**: legacy public scene/selection commands that emit actions
  resolve optional timestamps at commit time. Remove node emits delete, clear
  scene emits clear, delete selection emits delete, and transform selection emits
  transform with resolved timestamps
  (`legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_mutation_boundary.dart:96`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_mutation_boundary.dart:102`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_mutation_boundary.dart:149`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_mutation_boundary.dart:157`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_mutation_boundary.dart:268`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_mutation_boundary.dart:285`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_mutation_boundary.dart:381`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_mutation_boundary.dart:396`).
- **Dependencies**: public APIs expose `timestampMs` for remove/clear and selection
  transform/delete operations (`legacy/iwb_canvas_engine/lib/src/interactive/scene_controller_scene.dart:19`,
  `legacy/iwb_canvas_engine/lib/src/interactive/scene_controller_scene.dart:20`,
  `legacy/iwb_canvas_engine/lib/src/interactive/scene_controller_selection.dart:10`,
  `legacy/iwb_canvas_engine/lib/src/interactive/scene_controller_selection.dart:13`).
- **Data flow**: public command timestamp hint -> mutation boundary resolves via
  dispatcher -> `emitAction` creates `ActionCommitted` (`legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_interaction_runtime.dart:345`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_interaction_runtime.dart:348`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:38`).
- **Additional timestamp-bearing event paths**: draw-line, draw-stroke/marker,
  erase, marquee selection, and text edit request paths carry timestamps into
  emitted actions or requests
  (`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_action_emitter.dart:45`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_action_emitter.dart:62`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_action_emitter.dart:77`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_selection_coordinator.dart:67`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_double_tap_router.dart:46`).

### 5. Legacy Test Evidence

- **Location**: primary `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:616`; additional references below.
- **Description**: one legacy test is named “handlePointer accepts null timestamp
  hint and keeps monotonic time”; it sends pointer inputs without `timestampMs`
  and expects the second emitted draw action timestamp to be greater than the
  first (`legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:616`,
  `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:636`,
  `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:653`,
  `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:675`).
- **Dependencies**: another legacy test sends remove-node timestamps `5` then `3`
  and expects the second emitted delete timestamp to be greater than the first
  (`legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:682`,
  `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:701`,
  `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:706`,
  `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:711`,
  `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:712`).
- **Data flow**: test input events/commands -> runtime normalization -> action
  stream collection -> timestamp ordering assertions
  (`legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:632`,
  `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:633`,
  `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:672`,
  `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:675`).

### 6. New Public Contract Timestamp Shapes

- **Location**: primary `docs/contracts/public_api_v1.md:2005`; additional references below.
- **Description**: the public runtime exposes `actions` and `textEditRequests`
  streams (`docs/contracts/public_api_v1.md:358`,
  `docs/contracts/public_api_v1.md:359`). `CanvasActionCommitted` has
  `timestampMs` (`docs/contracts/public_api_v1.md:2005`,
  `docs/contracts/public_api_v1.md:2010`,
  `docs/contracts/public_api_v1.md:2017`). `CanvasTextEditRequested` also has
  required `timestampMs` (`docs/contracts/public_api_v1.md:2176`,
  `docs/contracts/public_api_v1.md:2183`,
  `docs/contracts/public_api_v1.md:2195`).
- **Dependencies**: other public shapes also carry timestamps: pending line start
  preview (`docs/contracts/public_api_v1.md:1922`,
  `docs/contracts/public_api_v1.md:1925`,
  `docs/contracts/public_api_v1.md:1931`) and move commit request
  (`docs/contracts/public_api_v1.md:2237`,
  `docs/contracts/public_api_v1.md:2243`,
  `docs/contracts/public_api_v1.md:2250`).
- **Data flow**: public input/command APIs accept nullable timestamp hints
  (`docs/contracts/public_api_v1.md:1411`,
  `docs/contracts/public_api_v1.md:1415`,
  `docs/contracts/public_api_v1.md:1419`,
  `docs/contracts/public_api_v1.md:1460`,
  `docs/contracts/public_api_v1.md:1465`,
  `docs/contracts/public_api_v1.md:1644`) and timestamp-bearing public events
  expose non-null `timestampMs` fields
  (`docs/contracts/public_api_v1.md:2017`,
  `docs/contracts/public_api_v1.md:2195`).

### 7. Operation Matrix And Event Linkage

- **Location**: primary `docs/contracts/operation_matrix.md:46`; additional references below.
- **Description**: the operation matrix has an `Events` column
  (`docs/contracts/operation_matrix.md:46`), and the expanded dimension labels
  that column as the user-action notification dimension
  (`docs/contracts/operation_matrix.md:159`).
- **Dependencies**: matrix rows name event-emitting operations: command remove
  emits `deleteElements` if removed (`docs/contracts/operation_matrix.md:52`);
  marquee emits `selectMarquee` if changed (`docs/contracts/operation_matrix.md:56`);
  selected move emits `moveSelection` (`docs/contracts/operation_matrix.md:58`);
  rotate/flip emits `transformSelection` (`docs/contracts/operation_matrix.md:59`);
  delete selection emits `deleteElements` (`docs/contracts/operation_matrix.md:60`);
  command clear emits `clearContent` if removed (`docs/contracts/operation_matrix.md:62`);
  pencil/marker commit emits `drawPencil/drawMarker`
  (`docs/contracts/operation_matrix.md:76`); line commit emits `drawLine`
  (`docs/contracts/operation_matrix.md:79`); eraser commit emits `erase` if removed
  (`docs/contracts/operation_matrix.md:81`); text double-tap emits
  `textEditRequested` (`docs/contracts/operation_matrix.md:82`); changed text
  edit emits `editText` (`docs/contracts/operation_matrix.md:85`).
- **Data flow**: operation -> matrix `Events` cell -> guardrail/test dimension
  for user-action notifications (`docs/contracts/operation_matrix.md:159`,
  `docs/verification/guardrails.md:163`,
  `docs/verification/tests.md:251`,
  `docs/verification/tests.md:253`).

### 8. Current Proof Mapping And Release Gates

- **Location**: primary `audit.md:31`; additional references below.
- **Description**: HOLE-010 states that monotonic runtime-created timestamps lack
  explicit proof mapping to public contract, operation matrix, tests, and release
  gates (`audit.md:31`, `audit.md:35`, `audit.md:36`, `audit.md:37`,
  `audit.md:38`). Its checklist calls for the mapping id
  `runtime_created_timestamps_monotonic`, timestamp definition, creation site,
  time source, monotonicity scope, wall-clock rollback behavior, event coverage,
  operation matrix linkage, release gate linkage, and a monotonic order test
  (`audit.md:42`, `audit.md:43`, `audit.md:44`, `audit.md:45`, `audit.md:46`,
  `audit.md:47`, `audit.md:48`, `audit.md:49`, `audit.md:50`, `audit.md:51`).
- **Dependencies**: the legacy capability inventory records the monotonic runtime
  timestamp capability (`docs/verification/legacy_capability_inventory.md:63`).
  The functional ledger maps the broader action-event capability to
  `CanvasActionCommitted` typed payloads and `functional.action_events`
  (`docs/verification/functional_ledger.md:67`).
- **Data flow**: legacy inventory capability -> functional ledger action event
  row -> public event shapes and event matrix -> operation matrix event rows ->
  guardrail/release gates for user-action events
  (`docs/verification/legacy_capability_inventory.md:63`,
  `docs/verification/functional_ledger.md:67`,
  `docs/contracts/public_api_v1.md:2148`,
  `docs/contracts/operation_matrix.md:52`,
  `docs/verification/release_gates.md:197`).
- **Release/test facts**: `edit.operation_matrix_complete` requires executable
  assertions for every matrix row including user-action events
  (`docs/verification/guardrails.md:163`). `events.commands_emit_user_actions`
  requires high-level commands and interaction commits to own user action events
  (`docs/verification/guardrails.md:167`). Release gates require operation matrix
  tests to be green and separately require action typed payload tests to be green
  (`docs/verification/release_gates.md:184`,
  `docs/verification/release_gates.md:185`,
  `docs/verification/release_gates.md:186`,
  `docs/verification/release_gates.md:197`).

## Code References

- `audit.md:42` - HOLE-010 names missing `runtime_created_timestamps_monotonic` mapping.
- `docs/verification/legacy_capability_inventory.md:63` - legacy inventory records monotonic runtime-created timestamps.
- `docs/verification/functional_ledger.md:67` - action committed event maps to `CanvasActionCommitted` typed payloads and `functional.action_events`.
- `docs/contracts/public_api_v1.md:2017` - `CanvasActionCommitted.timestampMs`.
- `docs/contracts/public_api_v1.md:2195` - `CanvasTextEditRequested.timestampMs`.
- `docs/contracts/operation_matrix.md:52` - command remove event row.
- `docs/contracts/operation_matrix.md:82` - text double-tap request event row.
- `docs/verification/guardrails.md:163` - operation matrix guardrail includes user-action events.
- `docs/verification/release_gates.md:197` - release gate for action typed payload tests.
- `legacy/iwb_canvas_engine/lib/src/core/action_events.dart:74` - legacy action timestamp doc comment.
- `legacy/iwb_canvas_engine/lib/src/core/action_events.dart:93` - legacy text request timestamp doc comment.
- `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:21` - timestamp normalization algorithm.
- `legacy/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart:49` - Flutter pointer timestamp source.
- `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:616` - legacy null-hint monotonic test.
- `legacy/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart:682` - legacy backwards-hint monotonic test.

## Observed Architecture Facts

- Pattern observed: timestamp hints are nullable at public command/input boundaries
  and non-null on emitted public event/request/read models
  (`docs/contracts/public_api_v1.md:1411`,
  `docs/contracts/public_api_v1.md:1542`,
  `docs/contracts/public_api_v1.md:2017`,
  `docs/contracts/public_api_v1.md:2195`).
- Pattern observed: legacy monotonicity is cursor-based and accepts forward
  hints while clamping null/backwards hints to the next runtime cursor value
  (`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:21`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:23`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:26`).
- Data flow: legacy Flutter pointer event -> `PointerSample.timestampMs` from
  `event.timeStamp.inMilliseconds` -> `CanvasPointerInput.timestampMs` -> runtime
  normalizer/cursor -> emitted action/request timestamp
  (`legacy/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart:49`,
  `legacy/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart:59`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_pointer_normalizer.dart:40`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart:21`).
- Key dependency: new docs currently connect action events to guardrails and
  release gates through general event/action checks, not through a separately
  named monotonic timestamp proof id
  (`docs/verification/guardrails.md:163`,
  `docs/verification/guardrails.md:167`,
  `docs/verification/release_gates.md:184`,
  `docs/verification/release_gates.md:197`).

## Open Questions

- `runtime_created_timestamps_monotonic` was not found outside `audit.md:42`.
- Explicit monotonic timestamp contract wording was not found in the public API
  timestamp field descriptions around `CanvasActionCommitted.timestampMs` and
  `CanvasTextEditRequested.timestampMs` (`docs/contracts/public_api_v1.md:2017`,
  `docs/contracts/public_api_v1.md:2195`).
- A new-runtime implementation or root `test/` coverage for monotonic timestamp
  ordering was not found in the current root package search; the root package
  currently exposes package metadata in `pubspec.yaml` (`pubspec.yaml:1`).
