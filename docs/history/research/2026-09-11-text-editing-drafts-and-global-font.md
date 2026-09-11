---
date: 2026-09-11
researcher: agent
commit: 2fcf57b2
branch: main
research_question: >-
  What existing APIs, runtime owners, Flutter overlay behavior, commit protocol,
  conflict guards, font resolution paths, compatibility contracts, and tests
  govern editing existing text blocks by ID (including empty blocks), drafting
  text and whole-block bold/italic/underline together, confirming or cancelling
  programmatically with distinguishable outcomes, retaining double-tap editing
  and genuine external-change conflicts, and setting a global font instead of
  specifying a font on every node?
---

# Research: Text editing drafts and global font

## Request Scope

The supplied request assigns draft text/whole-block B/I/U, stock-overlay input
state, and negotiated completion to the engine. The host owns keypad UI,
new-block placement, empty-block deletion, document saving and one Undo entry
per completed user edit. It explicitly retains the existing overlay and
consumers, and excludes a new engine keypad-input mechanism. These are user
requirements recorded as research context, not claims that every requested
capability already exists. The additional request is a global font setting;
it does not specify whether that setting is persisted in the document or is
an embedding/runtime preference.

## Summary

The package already exposes runtime-owned text editing, a stock Flutter
`CanvasTextEditingOverlay`, programmatic text updates, commit/dismiss methods,
and a host confirmation request containing the complete before/after text
elements. Session admission currently requires a retained context-action
request; there is no direct element-ID start method. The session draft contains
live text, while its style is read from captured frame facts. Its public
interface has no formatting mutation operation
(`lib/src/contracts/public/canvas_text_editing.dart:108`,
`lib/src/contracts/public/canvas_text_editing.dart:159`,
`lib/src/runtime/runtime_root.dart:4719`,
`lib/src/runtime/runtime_root.dart:4888`,
`lib/src/runtime/runtime_root.dart:4955`).

Ordinary per-element updates already accept text and B/I/U together, but this
route updates committed document data. A changed text-element update increases
its revision, which is one of the active session's conflict guards. The inline
commit route currently prepares only text and an optional anchor-preserving
transform. It returns `bool`: accepted changes and accepted no-ops both return
true, while several rejection conditions return false. Explicit dismissal is
void; host resolver cancellation is a distinct retryable outcome
(`lib/src/edit/element_update_application.dart:187`,
`lib/src/runtime/runtime_root.dart:4809`,
`lib/src/runtime/runtime_root.dart:1511`,
`lib/src/runtime/runtime_root.dart:1591`,
`lib/src/contracts/public/canvas_text_editing.dart:154`).

Font family is nullable per-element data that is serialized in schema v1 and
forwarded into measurement, cache identity, paint, and the editing overlay.
The inspected runtime/surface configurations contain no global font setting.
The package passes a null family to Flutter without resolving it through an
inherited application text theme. Existing tests cover text-only editing and
conflicts, initial overlay formatting, font serialization, and font-related
bounds effects; no test was found for live input interleaved with draft B/I/U
changes or a runtime-wide font default
(`lib/src/contracts/public/canvas_element.dart:172`,
`lib/src/contracts/public/canvas_runtime.dart:25`,
`lib/src/frame/frame_text_layout_measurer.dart:96`,
`lib/src/frame/frame_cache.dart:195`,
`lib/src/codec/schema_v1_encoder.dart:160`).

## Detailed Findings

### 1. Public API, admission, and existing double-tap route

- **Location:** `lib/iwb_canvas_engine.dart:1`,
  `lib/src/api/canvas_runtime.dart:29`,
  `lib/src/contracts/public/canvas_text_editing.dart:103`.
- **Description:** The root barrel exports the runtime, text-editing contracts,
  surface, and overlay through public facades. `runtime.textEditing` exposes
  `activeSession`, `sessionCandidateFor(request)`, `start(session)`,
  `startFromContextAction(request)`, `setReadOnly`, and `dismissActive`.
  A session exposes identity/guard fields, `initialText`, `liveText`, geometry,
  style, `isActive`, `isStale`, `updateText`, `commit`, and `dismiss`
  (`lib/src/api/canvas_text_editing.dart:1`,
  `lib/src/api/canvas_surface.dart:1`,
  `lib/src/contracts/public/canvas_text_editing.dart:108`,
  `lib/src/contracts/public/canvas_text_editing.dart:159`).
- **Dependencies:** Candidate creation uses the interaction request registry,
  current text-target guard facts, and frame facts. A fabricated public request
  alone does not establish the retained registry facts required by this route
  (`lib/src/runtime/runtime_root.dart:4719`,
  `lib/src/interaction/interaction_request_registry.dart:34`).
- **Data flow:** `CanvasToolPort.handleDoubleTap` → runtime → interaction
  target read → retained request → context-action stream → overlay subscription
  → `startFromContextAction` → candidate/start
  (`lib/src/contracts/public/canvas_tools.dart:110`,
  `lib/src/runtime/runtime_root.dart:1956`,
  `lib/src/interaction/interaction_engine.dart:368`,
  `lib/src/runtime/runtime_root.dart:3063`,
  `lib/src/surface/text_editing_overlay.dart:222`).

`CanvasSurface` and `CanvasTextEditingOverlay` are separate public widgets;
the surface does not construct the overlay. The example mounts the overlay
with `inlineEditOnDoubleTap: true`
(`lib/src/surface/canvas_surface_widget.dart:95`,
`lib/src/surface/text_editing_overlay.dart:27`,
`example/lib/src/canvas_example_screen.dart:169`).

`activeSession` is specifically a
`ValueListenable<CanvasTextEditSession?>`, and the port also exposes the
current `readOnly` value. Public `runtime.selection` deals in whole-element
IDs; it does not expose the editor's text-range selection. These are separate
observation surfaces (`lib/src/contracts/public/canvas_text_editing.dart:159`,
`lib/src/contracts/public/canvas_runtime.dart:212`).

Empty text is valid element/update data: validation limits length but does not
require nonempty text. Candidate admission requires a current visible content
text target, not a nonempty string. These facts establish empty-value support
in the model and session admission; they do not establish an ID-based API or
guarantee coordinate hit admission for every empty block
(`lib/src/contracts/public/canvas_element.dart:195`,
`lib/src/contracts/public/canvas_element_update.dart:331`,
`lib/src/runtime/runtime_root.dart:4719`,
`lib/src/runtime/runtime_interaction_read_adapter.dart:483`,
`lib/src/runtime/runtime_interaction_read_adapter.dart:752`).

### 2. Session draft, identity, and conflict ownership

- **Location:** `lib/src/runtime/runtime_root.dart:4507`.
- **Description:** `_RuntimeTextEditingPort` owns candidate states, one active
  session, read-only state, the active-session notifier, and a paint-suppression
  token. Candidate lookup reuses the same non-stale request. Start rejects
  read-only, foreign/unknown, stale, or competing candidates; the same active
  identity is reusable (`lib/src/runtime/runtime_root.dart:4537`,
  `lib/src/runtime/runtime_root.dart:4559`).
- **Dependencies:** Retained request identity includes target kind, epoch,
  generation, and element revision. Session style uses captured `baseFacts`;
  only `liveText` is mutated by the session text update
  (`lib/src/interaction/interaction_request_registry.dart:7`,
  `lib/src/runtime/runtime_root.dart:4758`,
  `lib/src/runtime/runtime_root.dart:4888`,
  `lib/src/runtime/runtime_root.dart:4955`).
- **Data flow:** retained request facts + fresh adapter facts → guard match →
  candidate/session or rejected terminal command
  (`lib/src/runtime/runtime_root.dart:4809`,
  `lib/src/interaction/interaction_engine.dart:199`,
  `lib/src/runtime/runtime_interaction_read_adapter.dart:483`).

The guard requires target existence, text kind, matching controller epoch,
generation and element revision, a registered content target, and non-null
current text. Document revision is recorded but is not compared. Consequently,
an unrelated document edit can leave a text session valid
(`lib/src/interaction/interaction_engine.dart:245`,
`lib/src/runtime/runtime_root.dart:4809`,
`test/runtime/fixtures/text_editing_port_fixture.dart:957`).

`CanvasTextElementUpdate` already accepts text and all formatting fields in
one update. Semantic equality includes those fields and filters no-op updates.
A changed update constructs a text element with `revision + 1`; formatting
changes therefore participate in the same stale check as other target changes
(`lib/src/contracts/public/canvas_element_update.dart:151`,
`lib/src/edit/element_update_application.dart:24`,
`lib/src/edit/element_update_application.dart:83`,
`lib/src/edit/element_update_application.dart:187`). The existing example B/I/U
buttons issue document edits, not session draft updates
(`example/lib/src/canvas_example_view_model.dart:217`,
`example/lib/src/canvas_example_view_model.dart:365`).

| Event | Current behavior and evidence |
| --- | --- |
| Same-target formatting change | Changed element revision invalidates the captured guard; the fixture uses a font-size change to demonstrate staleness (`lib/src/edit/element_update_application.dart:187`; `test/runtime/fixtures/text_editing_port_fixture.dart:1463`; `test/runtime/fixtures/text_editing_port_fixture.dart:908`). |
| Target hidden or removed | Fresh adapter facts become missing; guard rejects (`lib/src/runtime/runtime_interaction_read_adapter.dart:483`; `lib/src/interaction/interaction_engine.dart:217`). |
| Lock field changed | The text update carries the common field and advances element revision. The adapter has no separate lock condition in its text guard read (`lib/src/edit/element_update_application.dart:187`; `lib/src/runtime/runtime_interaction_read_adapter.dart:483`). |
| Same ID removed/re-added or replaced by another kind | Matching requires the captured generation and text kind; the fixture covers same-ID vector replacement (`lib/src/interaction/interaction_engine.dart:245`; `test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart:250`). |
| Unrelated document edit | Document revision alone does not stale the session (`lib/src/runtime/runtime_root.dart:4809`; `test/runtime/fixtures/text_editing_port_fixture.dart:957`). |
| Generic accepted document replacement | Common delivery increments the epoch; later stale reads compare it. Generic delivery does not call text transient cleanup (`lib/src/runtime/runtime_root.dart:2745`; `lib/src/runtime/runtime_root.dart:2801`; `lib/src/runtime/runtime_root.dart:4854`). |
| Successful document load | Load clears text transient state and interaction requests; failed load preserves the session in the fixture (`lib/src/runtime/runtime_root.dart:2589`; `test/runtime/fixtures/text_editing_port_fixture.dart:1279`). |
| Read-only enabled | Active editing is dismissed (`lib/src/runtime/runtime_root.dart:4601`). |
| Explicit dismiss or runtime disposal | Active state/editor suppression is removed; disposal also clears transient candidates and requests (`lib/src/runtime/runtime_root.dart:4610`; `lib/src/runtime/runtime_root.dart:4711`; `lib/src/runtime/runtime_root.dart:1980`). |

### 3. Stock overlay, input state, and live geometry

- **Location:** `lib/src/surface/text_editing_overlay.dart:66`.
- **Description:** Widget state owns the Flutter text controller, focus node,
  and optional scroll controller. It subscribes to active-session and runtime
  state notifications. A different session object disposes and recreates these
  objects; a notification for the same session synchronizes text conditionally
  and rebuilds (`lib/src/surface/text_editing_overlay.dart:76`,
  `lib/src/surface/text_editing_overlay.dart:239`,
  `lib/src/surface/text_editing_overlay.dart:275`).
- **Dependencies:** `EditableText` receives the controller/focus node,
  multiline/newline configuration, session-derived text and strut styles,
  optional selection controls, and `_commitSession` on editing completion
  (`lib/src/surface/text_editing_overlay.dart:188`).
- **Data flow:** Flutter controller text change → `session.updateText` →
  runtime `liveText` → synchronous active-session notification → same-session
  synchronization/rebuild (`lib/src/surface/text_editing_overlay.dart:323`,
  `lib/src/runtime/runtime_root.dart:4888`,
  `lib/src/surface/text_editing_overlay.dart:239`).

Only the string is forwarded into the runtime draft. Cursor, selection and
composing state reside in the Flutter controller value, not in the public
session. If runtime text equals controller text, synchronization leaves the
controller value alone. If they differ, it assigns a new `TextEditingValue`
with selection collapsed at the end and an empty composing range. This
distinguishes ordinary controller-originated typing from external
`session.updateText` that changes the string
(`lib/src/contracts/public/canvas_text_editing.dart:108`,
`lib/src/surface/text_editing_overlay.dart:323`,
`lib/src/surface/text_editing_overlay.dart:345`).

Every build reads `session.style`; B/I/U are mapped to Flutter font weight,
font style and text decoration. Runtime style still comes from the session's
captured facts. Geometry uses live text measurement, an anchor-preserving
transform, and `GeometryPolicy`; the overlay consumes these bounds rather
than measuring with its own `TextPainter`
(`lib/src/surface/text_editing_overlay.dart:138`,
`lib/src/surface/text_editing_overlay.dart:476`,
`lib/src/runtime/runtime_root.dart:4925`,
`lib/src/runtime/runtime_root.dart:4955`,
`test/surface/fixtures/text_editing_overlay_fixture.dart:378`).

Overlay commit calls `session.commit()` without an additional controller-value
flush; runtime commit reads the synchronously maintained `state.liveText`.
Focus-loss commit is deferred to a microtask and rechecks session identity,
focus-node identity, generation, focus and liveness. Escape and disposal use
dismissal (`lib/src/surface/text_editing_overlay.dart:363`,
`lib/src/surface/text_editing_overlay.dart:393`,
`lib/src/surface/text_editing_overlay.dart:114`,
`lib/src/runtime/runtime_root.dart:4900`).

The existing overlay constructor exposes `commitOnFocusLoss`, `autofocus`,
and `dismissOnEscape` (all default true), while `inlineEditOnDoubleTap`
defaults false. It also accepts optional selection controls and an editor
height limit. A runtime change in `didUpdateWidget` removes the old listeners,
dismisses the old session and installs the new runtime's session/editor state.
Thus changing the overlay's runtime already has a dismissal path, distinct
from explicitly confirming input before a workspace change
(`lib/src/surface/text_editing_overlay.dart:29`,
`lib/src/surface/text_editing_overlay.dart:88`).

The overlay exposes no local `TextInputControl` setting and uses stock
`EditableText`. Repository searches found no direct `TextInputControl`,
`TextInputClient`, or input-connection integration in the surface, example, or
their test paths. The external application's verified keypad integration is
task context, not a repository-tested behavior
(`lib/src/surface/text_editing_overlay.dart:29`,
`lib/src/surface/text_editing_overlay.dart:188`; search evidence below).

The overlay agent also inspected the local Flutter SDK input declarations:
`TextInput.setInputControl` changes the global control and notifies the
current client; the `TextInputControl` mixin declares attach/detach,
show/hide, editing-state, geometry, selection, caret and style callbacks.
`EditableTextState` opens its connection through `TextInput.attach` and sends
editing state/style to that connection
(`/Users/blackpika/Dev/flutter/packages/flutter/lib/src/services/text_input.dart:2015`,
`/Users/blackpika/Dev/flutter/packages/flutter/lib/src/services/text_input.dart:2524`,
`/Users/blackpika/Dev/flutter/packages/flutter/lib/src/widgets/editable_text.dart:4105`).
These exact paths/lines identify the local SDK inspected during research;
they are external source observations, not package-versioned contracts or
proof of the host application's integration.

### 4. Negotiated commit, no-op, cancellation, and completion results

- **Location:** `lib/src/runtime/runtime_root.dart:1511`.
- **Description:** Both the direct public command and session callback route
  through `RuntimeRoot.commitTextEdit`. The public command accepts a request
  ID and text; the session method supplies its draft. Both return `bool`
  (`lib/src/contracts/public/canvas_runtime.dart:198`,
  `lib/src/runtime/runtime_root.dart:4217`,
  `lib/src/runtime/runtime_root.dart:4900`).
- **Dependencies:** Interaction guard, deferred edit preparation, shared host
  resolver/lease normalization, prepared store consume/discard, common delivery
  and runtime action finalization
  (`lib/src/interaction/interaction_engine.dart:199`,
  `lib/src/edit/edit_kernel.dart:170`,
  `lib/src/runtime/runtime_root.dart:1194`,
  `lib/src/runtime/runtime_root.dart:2745`).
- **Data flow:** validate → guard → text no-op check → prepare text/optional
  transform → host `CanvasTextEditCommitRequest(before, after)` → accept or
  discard → consume/store → retire request and matching session → deliver
  state, lease completion, action and observer → session-close notification
  (`lib/src/runtime/runtime_root.dart:1511`,
  `lib/src/runtime/runtime_root.dart:1591`,
  `lib/src/contracts/public/canvas_commit.dart:213`,
  `lib/src/runtime/runtime_root.dart:2745`).

The host request already contains full text-element snapshots. The current
session preparation sets only text and optional anchor transform; it does not
take draft B/I/U input. The action is sealed from the prepared sparse
before/after pair before store installation. Its public payload contains the
request ID and old/new text lengths, not the complete style snapshots
(`lib/src/runtime/runtime_root.dart:1597`,
`lib/src/runtime/runtime_root.dart:1626`,
`lib/src/contracts/public/canvas_actions.dart:157`,
`lib/src/runtime/runtime_action_finalizer.dart:264`). Undo/redo is documented
as application-owned (`docs/contracts/public_api_v1.md:1642`).

| Condition | Public result and retained state |
| --- | --- |
| Invalid text/timestamp | Throws before consuming the request; validation failure is retryable (`lib/src/runtime/runtime_root.dart:1516`; `lib/src/runtime/runtime_root.dart:4245`; `test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart:485`). |
| Unknown, consumed, invalid target, or stale request | `false`; invalid/stale guard rejection consumes the retained request where present; matching stale active state is cleared (`lib/src/interaction/interaction_engine.dart:199`; `lib/src/runtime/runtime_root.dart:1519`; `lib/src/runtime/runtime_root.dart:4662`). |
| Equal current text and draft | `true`; request/session retired without preparation, resolver, mutation or edit-text action (`lib/src/runtime/runtime_root.dart:1525`; `test/runtime/fixtures/text_editing_port_fixture.dart:757`). |
| Preparation declines | `false`; current request/document/session remain retryable (`lib/src/runtime/runtime_root.dart:1533`; `test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart:366`). |
| Host `CanvasCommitCancel`, resolver exception, guarded resolver rejection, or incompatible resolution | `false`; prepared work discarded, applicable lease aborted, draft/request retained for retry (`lib/src/runtime/runtime_root.dart:1194`; `lib/src/runtime/runtime_root.dart:1552`; `test/runtime/fixtures/text_editing_port_fixture.dart:796`). |
| Accepted changed text | `true`; one prepared change and one edit-text action, request retired and matching active session cleared (`lib/src/runtime/runtime_root.dart:1558`; `test/runtime/fixtures/text_editing_port_fixture.dart:563`). |
| Prepared consume throws | Lease aborted, exception rethrown (`lib/src/runtime/runtime_root.dart:1558`). |
| Explicit session `dismiss()` / port `dismissActive()` | `void`; closes active editing without applying draft text. This is distinct from host resolver cancellation that keeps the active draft (`lib/src/contracts/public/canvas_text_editing.dart:154`; `lib/src/runtime/runtime_root.dart:4610`; `lib/src/runtime/runtime_root.dart:4917`; `test/surface/fixtures/text_editing_overlay_fixture.dart:244`). |

Resolver/lease callbacks are guarded against reentrant public mutation.
Accepted notification failures are contained by delivery helpers. Common
delivery publishes state before invoking `lease.committed`, then emits action
intents and the observer; session-close notification follows this delivery
(`lib/src/runtime/runtime_root.dart:2202`,
`lib/src/runtime/runtime_root.dart:1253`,
`lib/src/runtime/runtime_root.dart:2404`,
`lib/src/runtime/runtime_root.dart:2801`,
`lib/src/runtime/runtime_root.dart:1574`).

The public resolver maps a request synchronously to `CanvasCommitResolution`;
its declared return type is not a future. An accepted lease has one terminal
attempt, and the shared lease wrapper contains callback failures. The current
protocol therefore does not expose an asynchronous pending-confirmation
result (`lib/src/contracts/public/canvas_commit.dart:13`,
`lib/src/runtime/runtime_root.dart:176`,
`lib/src/runtime/runtime_root.dart:1253`).

### 5. Font model, defaults, measurement, and cache identity

- **Location:** `lib/src/contracts/public/canvas_element.dart:172`.
- **Description:** Each text element has nullable `fontFamily`, default size
  `24.0`, and false B/I/U defaults. Non-null family must be nonempty and no
  longer than the 256-character contract limit
  (`lib/src/contracts/public/canvas_element.dart:177`,
  `lib/src/contracts/public/canvas_element.dart:208`,
  `lib/src/contracts/public/canvas_contract_limits.dart:22`).
- **Dependencies:** Text rows, frame facts, measured-layout inputs, layout
  cache, render rows, geometry policy and overlay style
  (`lib/src/store/family_tables.dart:1983`,
  `lib/src/frame/frame_text_layout_measurer.dart:23`,
  `lib/src/frame/render_element_record.dart:265`,
  `lib/src/geometry/geometry_policy.dart:405`).
- **Data flow:** element/import event → `TextRow.fontFamily` → fact family →
  runtime/render layout input → keyed `TextPainter` layout → paint and bounds;
  captured session facts → session style → overlay text/strut style
  (`lib/src/store/family_tables.dart:555`,
  `lib/src/runtime/runtime_root.dart:923`,
  `lib/src/frame/render_element_record.dart:292`,
  `lib/src/frame/frame_text_layout_measurer.dart:96`,
  `lib/src/frame/main_frame_record_painter.dart:169`,
  `lib/src/runtime/runtime_root.dart:4955`,
  `lib/src/surface/text_editing_overlay.dart:481`).

| Surface | Existing family behavior |
| --- | --- |
| Element construction | Omitted family is null (`lib/src/contracts/public/canvas_element.dart:182`). |
| Partial update | Absent preserves existing family; set/clear resolves through the nullable-field update helper (`lib/src/contracts/public/canvas_element_update.dart:171`; `lib/src/edit/element_update_application.dart:202`; `lib/src/edit/element_update_application.dart:333`). |
| Runtime/surface/tool configuration | No font-default property in the inspected declarations; draw tools enumerate pencil, marker, line and eraser (`lib/src/contracts/public/canvas_runtime.dart:25`; `lib/src/runtime/runtime_config.dart:9`; `lib/src/surface/canvas_surface_widget.dart:20`; `lib/src/contracts/public/canvas_tools.dart:10`). |
| Runtime and render measurement | `facts.fontFamily` forwarded without a literal family fallback (`lib/src/runtime/runtime_root.dart:938`; `lib/src/runtime/runtime_root.dart:966`; `lib/src/frame/render_element_record.dart:301`). |
| Layout cache | Family participates in key equality/hash alongside text, size, color, alignment, direction, B/I/U, width and line height; capacity is 1024 (`lib/src/frame/frame_cache.dart:175`; `lib/src/frame/frame_cache.dart:195`; `lib/src/frame/frame_text_layout_measurer.dart:80`). |
| Paint/geometry | Paint uses the cached painter; paint/hit/selection/edit bounds read the measured layout (`lib/src/frame/main_frame_record_painter.dart:175`; `lib/src/geometry/geometry_policy.dart:405`). |
| Overlay | Family goes directly to both `TextStyle` and `StrutStyle` (`lib/src/surface/text_editing_overlay.dart:481`; `lib/src/surface/text_editing_overlay.dart:493`). |

Family changes contribute `elementBounds` effects; text color and underline
use the visual-effect branch. The cache key includes the family name but no
font-asset generation or font revision. Searches found no package-owned
`FontLoader`, `systemFonts`, font registration, or font-asset invalidation
route. These are source/cache identity observations, not verification of
host-side dynamic font loading
(`lib/src/store/document_store_kernel.dart:2731`,
`lib/src/frame/frame_cache.dart:195`; search evidence below).

No production `Theme.of`, `DefaultTextStyle`, `DefaultTextStyle.of`, or
`InheritedTheme` lookup was found under `lib/`. Measurement and overlay create
their styles directly; null-family fallback selection belongs to Flutter and
the embedding environment, and is not named by this package
(`lib/src/frame/frame_text_layout_measurer.dart:96`,
`lib/src/surface/text_editing_overlay.dart:481`).

### 6. Font persistence, imports, and example assets

- **Location:** `lib/src/codec/schema_v1_encoder.dart:160`.
- **Description:** Schema v1 encodes family on each text element. The reader
  accepts an optional nonempty, bounded family string, puts it into the text
  import event, and the decoder/store preserve it
  (`lib/src/codec/schema_v1_reader.dart:950`,
  `lib/src/contracts/internal/schema_v1_import_events.dart:138`,
  `lib/src/codec/schema_v1_decoder.dart:265`,
  `lib/src/store/family_tables.dart:1998`).
- **Dependencies:** Public text element, schema import event and family row;
  the encoder emits `schemaVersion: 1`
  (`lib/src/codec/schema_v1_encoder.dart:13`).
- **Data flow:** document text family → encoded text key → optional-string
  read → import event → decoded element or imported text row → public
  projection (`lib/src/codec/schema_v1_encoder.dart:170`,
  `lib/src/codec/schema_v1_reader.dart:995`,
  `lib/src/store/family_tables.dart:2025`,
  `lib/src/runtime/runtime_interaction_read_mapping.dart:187`).

The example creates sample text with size 20 and no family, and exposes
selected-text B/I/U, size, alignment, line-height and color controls but no
family setter. Neither package manifest declares fonts; the example declares
only its image asset in the Flutter asset section. Tracked-file searches found
no font file or font manifest
(`example/lib/src/canvas_example_view_model.dart:204`,
`example/lib/src/canvas_example_view_model.dart:517`,
`example/pubspec.yaml:25`, `pubspec.yaml:1`).

### 7. Requirement-to-current-behavior and proof matrix

This matrix distinguishes declared capabilities and existing proof from
searched absences. It does not specify a future API or implementation.

| Requested behavior | Current capability | Existing proof / search result |
| --- | --- | --- |
| Start by ID, empty/nonempty | Empty text is legal; start is request/session-based, with no ID-start member (`lib/src/contracts/public/canvas_element.dart:195`; `lib/src/contracts/public/canvas_text_editing.dart:159`). | Candidate/read-only/active-session cases exist (`test/runtime/fixtures/text_editing_port_fixture.dart:30`). No start-by-ID API or associated test found. |
| Input → B/I/U → continued input, preserving caret/selection/focus | Session has string-only mutation; overlay retains Flutter editing objects for the same session (`lib/src/contracts/public/canvas_text_editing.dart:151`; `lib/src/surface/text_editing_overlay.dart:239`). | Initial style adoption is covered (`test/surface/fixtures/text_editing_overlay_fixture.dart:41`); no live-style interleaving test with caret/selection/focus assertions found. |
| One negotiated text-and-style commit | Full before/after request exists; current session preparation sets text/optional transform (`lib/src/contracts/public/canvas_commit.dart:213`; `lib/src/runtime/runtime_root.dart:1597`). | Exact prepared snapshots and resolver/lease order are tested (`test/runtime/fixtures/text_editing_port_fixture.dart:998`; `test/runtime/fixtures/text_editing_port_fixture.dart:1080`). No style-bearing session draft/commit found. |
| Cancel both draft components | Explicit dismissal exists for text draft; there is no session style draft (`lib/src/runtime/runtime_root.dart:4610`; `lib/src/contracts/public/canvas_text_editing.dart:108`). | Escape preserves original text and emits no action (`test/surface/fixtures/text_editing_overlay_fixture.dart:244`). Host resolver cancellation retaining draft is separately tested (`test/runtime/fixtures/text_editing_port_fixture.dart:796`). |
| Unchanged draft creates no mutation | Equal-text commit returns true and retires request without changed-commit path (`lib/src/runtime/runtime_root.dart:1525`). | Text-only no-op test (`test/runtime/fixtures/text_editing_port_fixture.dart:757`). |
| Programmatic finish and distinguishable result | Session `commit`, `dismiss`, port `dismissActive`, and direct command already exist; return types are bool/void (`lib/src/contracts/public/canvas_text_editing.dart:154`; `lib/src/contracts/public/canvas_runtime.dart:198`). | Direct-command cleanup is tested (`test/runtime/fixtures/text_editing_port_fixture.dart:602`); no typed result distinguishing changed/no-op/stale/host rejection is declared. |
| Existing double-tap editing | Public tool/context-action and overlay subscription routes exist (`lib/src/runtime/runtime_root.dart:1956`; `lib/src/surface/text_editing_overlay.dart:222`). | Auto-start enabled/disabled (`test/surface/fixtures/text_editing_overlay_fixture.dart:134`), double-tap routing (`test/interaction/fixtures/eraser_context_action_routing_fixture.dart:232`). |
| Genuine external-change conflicts | Kind/epoch/generation/element-revision guard remains active (`lib/src/interaction/interaction_engine.dart:245`). | Stale and generation/kind/unknown request tests (`test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart:25`), style-induced staleness (`test/runtime/fixtures/text_editing_port_fixture.dart:908`), unrelated revision acceptance (`test/runtime/fixtures/text_editing_port_fixture.dart:957`), example stale inline commit (`example/test/canvas_example_screen_test.dart:478`). |
| Global font and element overrides | Per-element family exists; no runtime/surface global default found (`lib/src/contracts/public/canvas_element.dart:182`; `lib/src/contracts/public/canvas_runtime.dart:25`). | Schema family round-trip (`test/codec/schema_v1/canonical_encode_roundtrip_test.dart:121`; `test/codec/schema_v1/canonical_encode_roundtrip_test.dart:242`; `test/codec/schema_v1/canonical_encode_roundtrip_test.dart:747`), family update bounds effect (`test/edit/fixtures/edit_matrix_effects_fixture.dart:435`), initial overlay family (`test/surface/fixtures/text_editing_overlay_fixture.dart:41`). No global-default test found. |
| Font cache identity | Family is in key equality/hash (`lib/src/frame/frame_cache.dart:195`). | Capacity fixture constructs keys with null family (`test/frame/fixtures/cache_capacity_eviction_policy_fixture.dart:241`); no test comparing keys differing only in family was found. |

Additional existing proof relevant to retaining the current lifecycle includes
listener/notifier failures after accepted commits
(`test/runtime/fixtures/text_editing_port_fixture.dart:416`), live multiline
editor sizing (`test/surface/fixtures/text_editing_overlay_fixture.dart:291`),
focus-loss commit after the focus notification
(`test/surface/fixtures/text_editing_overlay_fixture.dart:251`),
overlay disposal (`test/surface/fixtures/text_editing_overlay_fixture.dart:361`),
and example B/I/U controls updating the committed element
(`example/test/canvas_example_screen_test.dart:796`,
`example/test/canvas_example_screen_test.dart:825`). Font-related fixtures
include rich-text measurement with the same explicit family in the element
and expected painter, plus measured-layout inputs with null family
(`test/runtime/fixtures/text_editing_port_fixture.dart:1698`,
`test/runtime/fixtures/text_editing_port_fixture.dart:1727`,
`test/frame/fixtures/measured_text_layout_fixture.dart:238`). These establish
their individual behaviors, not the requested combined draft-style flow.

The focused runtime/surface/interaction test entrypoints invoke Flutter fixture
harnesses; existing runnable commands include the following. These tests were
inspected, not executed during this documentation-only research
(`test/runtime/text_editing_port_test.dart:6`,
`test/surface/text_editing_overlay_test.dart:6`,
`test/interaction/context_action_request_test.dart:6`).

```sh
dart test test/runtime/text_editing_port_test.dart
dart test test/surface/text_editing_overlay_test.dart
dart test test/interaction/text_edit_stale_commit_guard_test.dart
dart test test/interaction/context_action_request_test.dart
dart test test/guardrails/text_surface_guardrail_checks_test.dart
dart test test/codec/schema_v1/canonical_encode_roundtrip_test.dart
# From example/:
flutter test test/canvas_example_view_model_test.dart test/canvas_example_screen_test.dart
```

### 8. Compatibility contracts, guardrails, and planning context

- **Location:** `docs/_registry/public_api_v1.yaml:63`.
- **Description:** Public text types and overlay are registered. Guardrails
  enforce registry parity, facade export boundaries, compile-as-written,
  Dartdoc, class modifiers, import cycles and public signature/type shape
  (`tool/guardrails/src/guardrail_registry.dart:35`,
  `tool/guardrails/src/guardrail_executor.dart:413`).
- **Dependencies:** Public integration fixtures import the root barrel; the
  compile-as-written test exercises the session fields and lifecycle methods
  (`test/api_contract/fixtures/public_integration_compile_fixture.dart:1`,
  `test/api_contract/public_api_v1_compiles_as_written_test.dart:1107`).
- **Data flow:** Public registry and declarations → guardrail/consumer compile
  checks; runtime/edit/session owners → normative behavior contracts
  (`tool/guardrails/src/guardrail_executor.dart:413`,
  `docs/contracts/public_api_v1.md:2699`).

The current ownership documentation assigns the active text session and
guarded lifecycle to the runtime-owned port. The operation matrix records
stale/no-op/changed commit ordering, and the edit-kernel contract records
prepared action sealing. Text/surface guardrails require the shared measured
layout source and confine `EditableText` to surface code
(`docs/architecture/01_runtime_ownership.md:245`,
`docs/contracts/operation_matrix.md:89`,
`docs/contracts/edit_kernel.md:239`,
`tool/guardrails/src/text_surface_guardrail_checks.dart:4`).

At inspection, `docs/planning/designs/` and `docs/planning/plans/` were absent
and the follow-up table was empty. This is a filesystem observation, not a
claim about future planning. Directory membership owns active registration;
research is historical evidence from creation
(`docs/planning/README.md:8`, `docs/planning/README.md:15`,
`docs/planning/FOLLOW_UPS.md:10`). No code/contract contradiction was identified
in the reported text and font routes; missing requested capabilities are
recorded as current surface facts above.

## Code References

- `lib/src/contracts/public/canvas_text_editing.dart:108` — session API.
- `lib/src/contracts/public/canvas_text_editing.dart:159` — admission/lifecycle port.
- `lib/src/runtime/runtime_root.dart:1511` — text terminal pipeline.
- `lib/src/runtime/runtime_root.dart:1591` — prepared text update and anchor.
- `lib/src/runtime/runtime_root.dart:4507` — session-state owner.
- `lib/src/runtime/runtime_root.dart:4809` — captured/current guard match.
- `lib/src/interaction/interaction_engine.dart:199` — command guard decision.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:483` — fresh target facts.
- `lib/src/surface/text_editing_overlay.dart:239` — session identity/rebuild.
- `lib/src/surface/text_editing_overlay.dart:345` — text/selection/composing synchronization.
- `lib/src/edit/element_update_application.dart:187` — text/style update and revision.
- `lib/src/contracts/public/canvas_commit.dart:213` — full before/after host request.
- `lib/src/frame/frame_text_layout_measurer.dart:96` — font-to-painter projection.
- `lib/src/frame/frame_cache.dart:195` — text layout cache identity.
- `lib/src/store/document_store_kernel.dart:2731` — font/style revision effects.
- `lib/src/codec/schema_v1_reader.dart:950` — persisted font validation.
- `tool/guardrails/src/text_surface_guardrail_checks.dart:4` — text surface boundaries.

## Search Coverage

### Division and complete-file inspection

Six independent research agents covered public API/entrypoints, session and
conflicts, overlay/input, commit negotiation, fonts/persistence, and
tests/contracts/examples. The parent waited during their investigation and
combined their evidence. One follow-up completed remaining whole-file reads
and font-specific proof/loading searches; no implementation was performed.

The synthesis was subsequently cross-checked against all six reports and the
font addendum. The cross-check retained the runtime-swap and overlay settings,
selection-observation distinction, synchronous resolver/lease facts, local
Flutter input-control seam, and additional lifecycle/font proof references.

The combined complete-file inspection set for the reported owners includes:

- Entry/facades/contracts: `lib/iwb_canvas_engine.dart`;
  `lib/src/api/canvas_runtime.dart`, `canvas_surface.dart`,
  `canvas_text_editing.dart`, `canvas_tools.dart`, `canvas_actions.dart`,
  `canvas_element_update.dart`, `canvas_runtime_surface_bridge.dart`,
  `canvas_runtime_frame_bridge.dart`; public contracts
  `canvas_text_editing.dart`, `canvas_runtime.dart`, `canvas_commit.dart`,
  `canvas_element.dart`, `canvas_element_update.dart`, `canvas_actions.dart`,
  `canvas_tools.dart`, `canvas_surface_styles.dart`; internal
  `measured_text_layout.dart` and `schema_v1_import_events.dart`.
- Runtime/interaction/edit/store: `lib/src/runtime/runtime_root.dart`,
  `runtime_config.dart`, `runtime_interaction_read_adapter.dart`,
  `runtime_interaction_read_mapping.dart`, `runtime_action_finalizer.dart`;
  `lib/src/interaction/interaction_engine.dart`, `interaction_request_registry.dart`,
  `interaction_read_port.dart`, `text_edit_guard_decision.dart`,
  `context_action_router.dart`; `lib/src/edit/element_update_application.dart`,
  `draft_document.dart`, `edit_session.dart`, `edit_kernel.dart`;
  `lib/src/store/document_store_kernel.dart`, `canvas_element_snapshot.dart`,
  `store_revision_delta.dart`, `committed_document.dart`, `family_tables.dart`.
- Overlay/frame/codec: `lib/src/surface/text_editing_overlay.dart`,
  `canvas_surface_widget.dart`, `pointer_adapter.dart`, `layer_paint_host.dart`,
  `main_painter.dart`, `overlay_painter.dart`;
  `lib/src/frame/frame_text_layout_measurer.dart`, `frame_cache.dart`,
  `render_element_record.dart`, `render_family_caches.dart`,
  `main_frame_record_painter.dart`, `captured_frame.dart`;
  `lib/src/geometry/geometry_policy.dart`;
  `lib/src/codec/schema_v1_encoder.dart`, `schema_v1_reader.dart`,
  `schema_v1_decoder.dart`.
- Proof/example: runtime `text_editing_port` fixture and entrypoint; interaction
  `text_edit_stale_commit_guard`, `context_action_request`, and
  `eraser_context_action_routing` fixtures/entrypoints; surface
  `text_editing_overlay` fixture and entrypoint; API integration and
  compile-as-written tests; text-surface guardrail tests; codec
  `canonical_encode_roundtrip_test.dart`; edit `edit_matrix_effects` fixture;
  frame `cache_capacity_eviction_policy` and `measured_text_layout` fixtures;
  `example/lib/src/canvas_example_screen.dart`, `canvas_example_view_model.dart`,
  `canvas_text_options_panel.dart`, `canvas_example_defaults.dart`; example
  view-model/screen tests; both package manifests.
- Repository context: `AGENTS.md`, both invoked skills, `docs/README.md`,
  `docs/planning/README.md`, `docs/planning/FOLLOW_UPS.md`, public API registry,
  public export/declaration/contract and text-surface guardrail sources.
  Current architecture/operation/edit/public contract passages cited above
  were included in the agents' documentation coverage. Historical inputs
  included research dated 2026-05-18 (text stale guard), 2026-05-19 (double-tap),
  2026-06-04 (inline editing), 2026-06-11 (net no-op), and 2026-06-14
  (runtime text boundary); they were not treated as current behavior owners.

### Mechanical probes and evidence consequences

All six zones used repository-local tracing. Initial unqualified member or
class-declaration probes sometimes failed symbol lookup or call-hierarchy
preparation. Agents inspected tool source and retried qualified callable
members. The locator recognizes `Class.member`; a missing class call-hierarchy
item is a tool/LSP limitation, not evidence that the API is unused
(`tool/src/lsp/symbol_locator.dart:43`, `tool/lsp_trace_symbol.dart:31`).

| Probe | Observed result and factual consequence |
| --- | --- |
| `dart run tool/trace_export_namespace.dart lib/iwb_canvas_engine.dart --json` | Effective text/session/overlay symbols resolve through public facades to contract/surface owners. This is exploration evidence; enforcement remains in registry guardrails (`lib/src/api/canvas_text_editing.dart:1`; `lib/src/api/canvas_surface.dart:1`; `tool/guardrails/src/guardrail_executor.dart:413`). |
| `dart run tool/lsp_trace_symbol.dart lib/src/runtime/runtime_root.dart RuntimeRoot.commitTextEdit --direction=both --depth=4 --json` | Incoming command/session callers and outgoing guard, prepare, resolver, consume/discard, request cleanup and delivery confirm the shared terminal owner (`lib/src/runtime/runtime_root.dart:1511`). |
| `dart run tool/lsp_trace_flow.dart lib/src/runtime/runtime_root.dart RuntimeRoot.commitTextEdit --depth=5 --json` | Primary mutation-guard route plus terminal side branches. Flow output selects one primary outgoing route, so source inspection establishes ordering across branches (`tool/src/lsp/trace_support.dart:172`; `lib/src/runtime/runtime_root.dart:1511`). |
| Qualified `_RuntimeTextEditingPort.start` and `startFromContextAction` symbol traces | Overlay and test incoming callers, admission/stale/notifier outgoing calls establish context-request admission (`lib/src/runtime/runtime_root.dart:4559`; `lib/src/surface/text_editing_overlay.dart:222`). |
| Qualified `_CanvasTextEditingOverlayState._commitSession` symbol/flow traces | Incoming build/focus-loss callers and outgoing session commit establish the stock overlay terminal route (`lib/src/surface/text_editing_overlay.dart:363`; `lib/src/surface/text_editing_overlay.dart:393`). |
| Qualified `RuntimeRoot.handleDoubleTap` and overlay context-subscription flow traces | Interaction engine and public stream/start side branches confirm the existing double-tap route (`lib/src/runtime/runtime_root.dart:1956`; `lib/src/surface/text_editing_overlay.dart:222`). |
| `FrameTextLayoutMeasurer.measureTextLayout`, `RenderFamilyCaches.bindAll`, and `_paintTextRecord` symbol traces, depth 1 | Runtime measurement callers and render cache binding/painter callers establish the family-to-layout-to-paint chain (`lib/src/runtime/runtime_root.dart:923`; `lib/src/frame/render_family_caches.dart:32`; `lib/src/frame/main_frame_record_painter.dart:169`). |
| `encodeSchemaV1Document` symbol trace, depth 1 | Public encoder incoming call and element-writer outgoing route locate persisted text-family ownership (`lib/src/codec/schema_v1_encoder.dart:11`; `lib/src/codec/schema_v1_encoder.dart:160`). |
| `dart run tool/lsp_find_boundary_bypasses.dart lib/src/runtime/runtime_root.dart RuntimeRoot --must-pass=commitTextEdit --depth=4` | Returned broad candidates because every public runtime method was checked against a text-only required hop. This configuration does not establish a text boundary bypass; relevant routes are supported by the focused traces above (`tool/lsp_find_boundary_bypasses.dart:41`; `tool/lsp_find_boundary_bypasses.dart:60`). |

### Searches, confirmed absences, and limits

- **Searched:** `CanvasTextEdit`, session lifecycle/start/begin/finish/end
  variants, `updateText`, style/toggle operations, B/I/U, `commitTextEdit`,
  context requests/double-tap, stale/generation/revision, document load/replace,
  delete/visibility/lock/read-only, selection/caret/focus/composing, Undo,
  resolver/lease, font/default/global/family terms across `lib`, `test`,
  `example`, `docs`, and `tool`.
- **Exact font/theme probes:**
  `rg -n --glob '*.dart' 'DefaultTextStyle|Theme\.of|InheritedTheme|DefaultTextStyle\.of' lib`;
  tracked asset search for font directories, `.ttf`, `.otf`, `.woff`, `.woff2`,
  and font manifests; searches for `FontLoader`, `systemFonts`, `fontAsset`,
  `fontRevision`, `FontManifest`, `loadFont`, `fontCache`, `registerFont`, and
  `fonts:` outside generated build/tool state and historical documents.
- **Not found:** direct ID-based session admission, a session formatting
  mutation or style draft, a typed completion result beyond bool/void, runtime
  cursor/selection/composing fields, a global font configuration, application
  theme lookup in canvas text production code, package-owned font loading or
  font-generation cache invalidation, tracked font assets, an example family
  control, live B/I/U input-state preservation tests, or a cache test comparing
  two keys differing only by family. These are scoped search observations,
  supported by the fully inspected owning declarations and matrices above.
- **Not inspected / not executed:** the external application's code, installed
  keypad control, document save/workspace switching and Undo implementation;
  platform fallback font choice; end-to-end dynamic font installation;
  unrelated vector/resource/store suites. Behavioral tests and Dart/DCM code
  checks were not run because this task produced documentation only.
- **Evidence exceptions:** Git revision/branch, absent planning directories,
  command outputs and no-match searches are command/filesystem observations
  without stable source lines. Source-level facts retain exact path/line
  references. External Flutter SDK call paths were inspected by the overlay
  agent as context, but are not treated here as repository-owned contracts.

## Observed Architecture Facts

- Session lifetime and draft text belong to the runtime port; Flutter input
  selection/focus/composition belong to the stock overlay's editing objects
  (`lib/src/runtime/runtime_root.dart:4507`,
  `lib/src/surface/text_editing_overlay.dart:66`).
- Request registry identity and fresh target facts are the shared conflict
  boundary for session and direct-command text completion
  (`lib/src/interaction/interaction_request_registry.dart:7`,
  `lib/src/interaction/interaction_engine.dart:199`,
  `lib/src/runtime/runtime_root.dart:4809`).
- Deferred preparation precedes host acceptance; state installation and
  ordered state/lease/action delivery occur after acceptance
  (`lib/src/runtime/runtime_root.dart:1533`,
  `lib/src/runtime/runtime_root.dart:1558`,
  `lib/src/runtime/runtime_root.dart:2745`).
- Per-element family is shared input to measured text, render cache identity,
  geometry and overlay style; no second package font-default owner was found
  (`lib/src/frame/frame_text_layout_measurer.dart:80`,
  `lib/src/geometry/geometry_policy.dart:405`,
  `lib/src/runtime/runtime_root.dart:4955`).
- Public exports and text measurement/surface boundaries have explicit
  registry/guardrail owners
  (`docs/_registry/public_api_v1.yaml:63`,
  `tool/guardrails/src/text_surface_guardrail_checks.dart:4`).

## Open Questions

No unresolved repository routing question remains for the scoped API, draft,
overlay, conflict, confirmation, persistence and font paths. The following
limits are distinct from unknown implementation routes:

- No dedicated inspected active-session fixture covers generic document
  replacement, target visibility change or target lock change. Their current
  outcomes above are source-path evidence, whereas successful/failed document
  load has direct fixture coverage (`lib/src/runtime/runtime_root.dart:2801`,
  `lib/src/runtime/runtime_interaction_read_adapter.dart:483`,
  `lib/src/edit/element_update_application.dart:187`,
  `test/runtime/fixtures/text_editing_port_fixture.dart:1279`).
- The external application's global `TextInputControl` setup and its save,
  workspace and Undo orchestration are outside the inspected repository.
  The package exposes stock `EditableText` and documents application-owned
  Undo (`lib/src/surface/text_editing_overlay.dart:188`,
  `docs/contracts/public_api_v1.md:1642`).
- The request does not define the lifetime or persistence of a future global
  font setting. This is a product-scope question, not missing repository
  research: the current family is per-element schema data and runtime
  configuration has no font field (`lib/src/codec/schema_v1_encoder.dart:160`,
  `lib/src/contracts/public/canvas_runtime.dart:25`).
- The concrete font selected for a null family depends on Flutter/platform
  behavior; this package forwards null and does not name that family
  (`lib/src/frame/frame_text_layout_measurer.dart:103`,
  `lib/src/surface/text_editing_overlay.dart:485`).
