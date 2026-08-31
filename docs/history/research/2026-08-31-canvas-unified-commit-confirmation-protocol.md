---
date: 2026-08-31
researcher: Codex
commit: 8aa192df
branch: main
research_question: "Прочитай планируемое изменение единого протокола подтверждения Canvas и подготовь исчерпывающий репозиторный research-артефакт для дальнейшего дизайна."
---

# Research: Canvas Unified Commit Confirmation Protocol

## Summary

The current public confirmation surface has two separate synchronous callbacks:
`CanvasRuntimeConfig.deletionCommitResolver` is required, while
`CanvasRuntimeConfig.moveCommitResolver` is optional
(`lib/src/contracts/public/canvas_runtime.dart:24`,
`lib/src/contracts/public/canvas_runtime.dart:40`,
`lib/src/contracts/public/canvas_runtime.dart:41`).  The move callback uses
move-specific request and resolution types in the public actions contract;
the deletion callback uses deletion-specific request, operation, entry, and
decision types in the deletion contract
(`lib/src/contracts/public/canvas_actions.dart:221`,
`lib/src/contracts/public/canvas_actions.dart:225`,
`lib/src/contracts/public/canvas_actions.dart:289`,
`lib/src/contracts/public/canvas_deletion.dart:7`,
`lib/src/contracts/public/canvas_deletion.dart:13`,
`lib/src/contracts/public/canvas_deletion.dart:65`).  No public type whose
name contains `Lease` was found in the searched public contracts.

The present operation routes are not temporally uniform. Delete selection and
erase prepare a deletion-specific, single-use deferred package before calling
the deletion resolver; acceptance consumes that package and cancellation
discards it (`lib/src/edit/edit_kernel.dart:159`,
`lib/src/edit/commit_applier.dart:291`,
`lib/src/edit/commit_applier.dart:355`,
`lib/src/edit/commit_applier.dart:380`). Move calls its resolver before the
edit preparation that updates element transforms
(`lib/src/runtime/runtime_root.dart:2744`,
`lib/src/runtime/runtime_root.dart:2830`). Draw, rotation, and flip commands
currently enter the ordinary interaction-commit path without a confirmation
callback (`lib/src/runtime/runtime_root.dart:2944`,
`lib/src/runtime/runtime_root.dart:1199`,
`lib/src/edit/edit_kernel.dart:121`).

For every accepted ordinary commit, the shared delivery route applies spatial
and resource effects, publishes runtime state, then emits committed actions
(`lib/src/runtime/runtime_root.dart:2416`,
`lib/src/runtime/runtime_root.dart:2448`,
`lib/src/runtime/runtime_root.dart:2459`,
`lib/src/runtime/runtime_root.dart:2483`,
`lib/src/runtime/runtime_root.dart:2484`).  Resolver callbacks already run
inside a mutation/reentrancy guard, and the deletion route records resolver
failures in diagnostics (`lib/src/runtime/runtime_root.dart:1936`,
`lib/src/runtime/runtime_root.dart:1964`,
`lib/src/runtime/runtime_root.dart:1108`).

## Detailed Findings

### 1. Existing public confirmation contracts and exports

- **Location**: `lib/src/contracts/public/canvas_runtime.dart:23`.
  **Description**: `CanvasRuntimeConfig` is a `final class` whose constructor
  requires `deletionCommitResolver` and accepts nullable `moveCommitResolver`.
  Both values are stored in `final` fields
  (`lib/src/contracts/public/canvas_runtime.dart:24`,
  `lib/src/contracts/public/canvas_runtime.dart:36`,
  `lib/src/contracts/public/canvas_runtime.dart:40`,
  `lib/src/contracts/public/canvas_runtime.dart:41`).
  **Dependencies**: The contract imports the public actions and deletion
  contracts, as well as document, element, pointer, tools, and diagnostics
  contracts (`lib/src/contracts/public/canvas_runtime.dart:11`,
  `lib/src/contracts/public/canvas_runtime.dart:20`).
  **Data flow**: A runtime caller supplies the two callbacks as configuration;
  the `RuntimeRoot` reads the move callback at delivery time
  (`lib/src/runtime/runtime_root.dart:2748`) and invokes the deletion callback
  through `_resolveDeletion` (`lib/src/runtime/runtime_root.dart:1108`).

- **Location**: `lib/src/contracts/public/canvas_actions.dart:221`.
  **Description**: `CanvasMoveCommitResolver` is a synchronous function type:
  `CanvasMoveResolution Function(CanvasMoveCommitRequest request)`
  (`lib/src/contracts/public/canvas_actions.dart:221`,
  `lib/src/contracts/public/canvas_actions.dart:222`).
  `CanvasMoveCommitRequest` contains a `CanvasDocumentSummary`, an immutable
  element-read list, `Offset proposedDelta`, and `Rect selectionBoundsWorld`
  (`lib/src/contracts/public/canvas_actions.dart:225`,
  `lib/src/contracts/public/canvas_actions.dart:233`,
  `lib/src/contracts/public/canvas_actions.dart:238`).  Its constructor copies
  the supplied elements to an unmodifiable list
  (`lib/src/contracts/public/canvas_actions.dart:231`,
  `lib/src/contracts/public/canvas_actions.dart:234`).
  **Data flow**: `RuntimeRoot._resolveSelectedMoveDelta` constructs this request
  from the terminal intent and supplies it to the configured callback
  (`lib/src/runtime/runtime_root.dart:2801`,
  `lib/src/runtime/runtime_root.dart:2814`).

- **Location**: `lib/src/contracts/public/canvas_actions.dart:242`.
  **Description**: Each `CanvasElementRead` exposes an element identifier,
  kind, revision, world bounds, transform, lock state, and transformability
  (`lib/src/contracts/public/canvas_actions.dart:253`,
  `lib/src/contracts/public/canvas_actions.dart:259`,
  `lib/src/contracts/public/canvas_actions.dart:265`,
  `lib/src/contracts/public/canvas_actions.dart:271`,
  `lib/src/contracts/public/canvas_actions.dart:277`,
  `lib/src/contracts/public/canvas_actions.dart:281`,
  `lib/src/contracts/public/canvas_actions.dart:283`).

- **Location**: `lib/src/contracts/public/canvas_actions.dart:289`.
  **Description**: `CanvasMoveResolution` is sealed. Its current alternatives
  are `CanvasMoveCommit`, carrying the resolver-provided delta, and
  `CanvasMoveCancel`, carrying an optional reason
  (`lib/src/contracts/public/canvas_actions.dart:289`,
  `lib/src/contracts/public/canvas_actions.dart:295`,
  `lib/src/contracts/public/canvas_actions.dart:306`,
  `lib/src/contracts/public/canvas_actions.dart:314`).
  **Data flow**: `RuntimeRoot` accepts a `CanvasMoveCommit` only after a finite
  delta check and maps `CanvasMoveCancel` to `null`
  (`lib/src/runtime/runtime_root.dart:2816`,
  `lib/src/runtime/runtime_root.dart:2828`).

- **Location**: `lib/src/contracts/public/canvas_deletion.dart:6`.
  **Description**: `CanvasDeletionCommitResolver` is a synchronous function
  type returning `CanvasDeletionDecision`
  (`lib/src/contracts/public/canvas_deletion.dart:7`,
  `lib/src/contracts/public/canvas_deletion.dart:8`).  The current decision
  values are `accept` and `cancel`, and the request operation is either
  `deleteSelection` or `erase`
  (`lib/src/contracts/public/canvas_deletion.dart:10`,
  `lib/src/contracts/public/canvas_deletion.dart:13`,
  `lib/src/contracts/public/canvas_deletion.dart:17`).

- **Location**: `lib/src/contracts/public/canvas_deletion.dart:51`.
  **Description**: `CanvasDeletionCommitRequest` holds a deletion operation
  and an immutable list of `CanvasDeletionEntry`
  (`lib/src/contracts/public/canvas_deletion.dart:51`,
  `lib/src/contracts/public/canvas_deletion.dart:57`,
  `lib/src/contracts/public/canvas_deletion.dart:65`,
  `lib/src/contracts/public/canvas_deletion.dart:75`).  Each entry exposes the
  public `CanvasElement`, its layer ID, and its element index
  (`lib/src/contracts/public/canvas_deletion.dart:58`,
  `lib/src/contracts/public/canvas_deletion.dart:59`,
  `lib/src/contracts/public/canvas_deletion.dart:60`).

- **Location**: `lib/src/api/canvas_actions.dart:1` and
  `lib/src/api/canvas_runtime.dart:21`.
  **Description**: The actions facade exports the actions contract, while the
  runtime facade exports both the runtime and deletion contracts
  (`lib/src/api/canvas_actions.dart:1`,
  `lib/src/api/canvas_runtime.dart:21`,
  `lib/src/api/canvas_runtime.dart:22`).  The root barrel exports these facades
  (`lib/iwb_canvas_engine.dart:1`, `lib/iwb_canvas_engine.dart:15`).
  **Downstream design scope**: Existing move types reach package clients through
  the actions facade; existing deletion types reach them through the runtime
  facade.

- **Location**: `lib/src/runtime/runtime_config.dart:9`.
  **Description**: `RuntimeConfig.from` retains the public move and deletion
  resolver references, selection-delete policy, an unmodifiable copy of
  `eraserElementKinds`, and a materialized diagnostics policy
  (`lib/src/runtime/runtime_config.dart:10`,
  `lib/src/runtime/runtime_config.dart:15`,
  `lib/src/runtime/runtime_config.dart:21`,
  `lib/src/runtime/runtime_config.dart:27`,
  `lib/src/runtime/runtime_config.dart:31`,
  `lib/src/runtime/runtime_config.dart:34`,
  `lib/src/runtime/runtime_config.dart:37`).  `RuntimeRoot` creates that
  internal configuration when it is constructed
  (`lib/src/runtime/runtime_root.dart:228`,
  `lib/src/runtime/runtime_root.dart:248`).
  **Test witness**: `runtime_config_materialization_fixture.dart` covers the
  default and explicit deletion policies and a caller mutation of the supplied
  eraser-kind set after construction
  (`test/runtime/fixtures/runtime_config_materialization_fixture.dart:65`,
  `test/runtime/fixtures/runtime_config_materialization_fixture.dart:82`,
  `test/runtime/fixtures/runtime_config_materialization_fixture.dart:90`,
  `test/runtime/fixtures/runtime_config_materialization_fixture.dart:149`).

- **Location**: `lib/src/contracts/public/canvas_runtime.dart:147`.
  **Description**: The current public editing surface exposes
  `CanvasEditPort.edit`, `loadDocumentFromJson`, the listed `CanvasEdit`
  operations, public command methods, and public selection commands
  (`lib/src/contracts/public/canvas_runtime.dart:147`,
  `lib/src/contracts/public/canvas_runtime.dart:149`,
  `lib/src/contracts/public/canvas_runtime.dart:157`,
  `lib/src/contracts/public/canvas_runtime.dart:179`,
  `lib/src/contracts/public/canvas_runtime.dart:197`,
  `lib/src/contracts/public/canvas_runtime.dart:215`,
  `lib/src/contracts/public/canvas_runtime.dart:228`).  Searches of the root
  barrel, public API facades, and public contract declarations found no public
  `beginTransaction` or `rollback`; the only searched public `commit()` match
  belongs to the text-edit session
  (`lib/src/contracts/public/canvas_text_editing.dart:155`).  Internal contract
  files are not exported by the root barrel
  (`lib/iwb_canvas_engine.dart:1`, `lib/iwb_canvas_engine.dart:19`).

### 2. Current normative resolver, no-op, and delivery contract

- **Location**: `docs/contracts/public_api_v1.md:577`.
  **Description**: The maintained public API contract states that the deletion
  resolver receives a complete, nonempty selection-delete or terminal-eraser
  projection before mutation; cancellation leaves committed state unchanged and
  resolver exceptions are contained through diagnostics
  (`docs/contracts/public_api_v1.md:577`).

- **Location**: `docs/contracts/public_api_v1.md:2951`.
  **Description**: The maintained public API contract states that the selected
  move resolver is called once at terminal pointer-up, is not called for zero
  movement, empty movable selection, or load/mode/dispose cleanup, and that
  cancel or returned zero delta emits no action
  (`docs/contracts/public_api_v1.md:2951`,
  `docs/contracts/public_api_v1.md:2954`,
  `docs/contracts/public_api_v1.md:2956`,
  `docs/contracts/public_api_v1.md:2961`,
  `docs/contracts/public_api_v1.md:2964`).

- **Location**: `docs/contracts/operation_matrix.md:58`.
  **Description**: The operation matrix records the current ordering difference:
  selected move calls its configured resolver before preparation, whereas
  selection deletion and eraser prepare before their resolver. On accepted
  deletion/erase, one bound Store install and one owned Selection install occur;
  on cancellation/error, the deferred package is discarded without a commit
  (`docs/contracts/operation_matrix.md:58`,
  `docs/contracts/operation_matrix.md:60`,
  `docs/contracts/operation_matrix.md:85`).  The same matrix records no
  state/action publication for no-op, cancellation, resolver cancellation,
  resolver zero delta, resolver exception, and selected-move preparation failure
  (`docs/contracts/operation_matrix.md:190`,
  `docs/contracts/operation_matrix.md:193`).

- **Location**: `docs/architecture/03_data_model.md:128`.
  **Description**: The architectural data-model contract identifies the Store
  transaction candidate as private. Rejected or final-no-op candidates construct
  no aggregate; accepted candidates construct one
  (`docs/architecture/03_data_model.md:128`,
  `docs/architecture/03_data_model.md:135`,
  `docs/architecture/03_data_model.md:136`).  Before mutation, `CommitApplier`
  seals delivery and action inputs and selects a Store/admission installation
  branch, an optional prepared-selection-only branch, or a true no-op; after a
  successful Store install no rollback follows
  (`docs/architecture/03_data_model.md:149`,
  `docs/architecture/03_data_model.md:154`,
  `docs/architecture/03_data_model.md:156`,
  `docs/architecture/03_data_model.md:157`).  This contract also states that
  no-op runtime operations do not change revisions or publish a new current
  public state snapshot (`docs/architecture/03_data_model.md:340`,
  `docs/architecture/03_data_model.md:344`).

### 3. Resolver callback guard and existing failure handling

- **Location**: `lib/src/runtime/runtime_root.dart:1936`.
  **Description**: `runResolverCallback` rejects nested resolver invocation,
  sets `_isRunningResolverCallback` while the callback is executing, and clears
  that flag in `finally` (`lib/src/runtime/runtime_root.dart:1938`,
  `lib/src/runtime/runtime_root.dart:1944`,
  `lib/src/runtime/runtime_root.dart:1953`).
  **Data flow**: Resolver calls from the deletion and move paths enter this
  callback seam (`lib/src/runtime/runtime_root.dart:1114`,
  `lib/src/runtime/runtime_root.dart:2805`).

- **Location**: `lib/src/runtime/runtime_root.dart:1964`.
  **Description**: `ensureRuntimeMutationAllowed` checks disposed, active edit
  callback, document load, and resolver-callback states. During a resolver
  callback it records a diagnostic and throws `ResolverCallbackRejection`
  (`lib/src/runtime/runtime_root.dart:1964`,
  `lib/src/runtime/runtime_root.dart:1974`,
  `lib/src/runtime/runtime_root.dart:1977`,
  `lib/src/runtime/runtime_root.dart:1984`,
  `lib/src/runtime/runtime_root.dart:2001`).  The rejection type is a
  `StateError` declared in the internal guard seam
  (`lib/src/contracts/internal/resolver_mutation_guard.dart:1`,
  `lib/src/contracts/internal/resolver_mutation_guard.dart:8`).

- **Location**: `lib/src/runtime/runtime_root.dart:1108`.
  **Description**: `_resolveDeletion` calls the configured deletion resolver
  under the resolver guard. A `ResolverCallbackRejection` and other resolver
  exceptions/errors take the non-acceptance route; ordinary resolver failures
  are recorded as interaction diagnostics
  (`lib/src/runtime/runtime_root.dart:1108`,
  `lib/src/runtime/runtime_root.dart:1121`,
  `lib/src/runtime/runtime_root.dart:1131`,
  `lib/src/runtime/runtime_root.dart:1143`).

- **Location**: `lib/src/runtime/runtime_root.dart:2744`.
  **Description**: The move path uses `intent.proposedDelta` if
  `moveCommitResolver` is `null`; otherwise it invokes the move resolver
  (`lib/src/runtime/runtime_root.dart:2748`,
  `lib/src/runtime/runtime_root.dart:2753`).  A resolver exception clears the
  selected-move interaction with the `resolverError` cleanup reason and is
  rethrown; a cancellation or zero resolved delta clears it with the
  `resolverCancel` cleanup reason without proceeding to the edit preparation
  (`lib/src/runtime/runtime_root.dart:2754`,
  `lib/src/runtime/runtime_root.dart:2757`,
  `lib/src/runtime/runtime_root.dart:2758`,
  `lib/src/runtime/runtime_root.dart:2761`).

- **Location**: `lib/src/diagnostics/diagnostics_hub.dart:19`.
  **Description**: A disabled diagnostics policy returns before evaluating
  diagnostic details; enabled policies create sanitised records
  (`lib/src/diagnostics/diagnostics_hub.dart:29`,
  `lib/src/diagnostics/diagnostics_hub.dart:34`,
  `lib/src/diagnostics/diagnostics_hub.dart:45`).  The runtime interaction
  diagnostics adapter maps resolver reentrant mutation rejection and deletion
  resolver failure to interaction diagnostic events
  (`lib/src/runtime/runtime_interaction_diagnostics_adapter.dart:123`,
  `lib/src/runtime/runtime_interaction_diagnostics_adapter.dart:132`).

### 4. Current prepared commit, document, revision, and selection boundaries

- **Location**: `lib/src/edit/edit_kernel.dart:121`.
  **Description**: The ordinary `prepareInteractionCommit` opens an edit
  session, runs the supplied synchronous callback, prepares the accepted
  document and plan, and immediately installs a changed accepted document
  (`lib/src/edit/edit_kernel.dart:121`,
  `lib/src/edit/edit_kernel.dart:141`,
  `lib/src/edit/edit_kernel.dart:148`,
  `lib/src/edit/edit_kernel.dart:156`).
  **Data flow**: Draw and selection transforms use this ordinary path
  (`lib/src/runtime/runtime_root.dart:2944`,
  `lib/src/runtime/runtime_root.dart:1237`).

- **Location**: `lib/src/edit/edit_kernel.dart:158`.
  **Description**: `prepareDeletionInteractionCommit` opens a sparse edit
  session, builds an accepted plan with deleted IDs, and returns a
  `PreparedDeletionCommit` for a changed plan. Its session is closed in a
  `finally` block (`lib/src/edit/edit_kernel.dart:158`,
  `lib/src/edit/edit_kernel.dart:182`,
  `lib/src/edit/edit_kernel.dart:189`,
  `lib/src/edit/edit_kernel.dart:192`,
  `lib/src/edit/edit_kernel.dart:280`).
  **Data flow**: Selection deletion and eraser both obtain this deferred
  deletion package before they invoke the deletion resolver
  (`lib/src/runtime/runtime_root.dart:1026`,
  `lib/src/runtime/runtime_root.dart:1054`,
  `lib/src/runtime/runtime_root.dart:3148`,
  `lib/src/runtime/runtime_root.dart:3211`).

- **Location**: `lib/src/edit/commit_applier.dart:291`.
  **Description**: `CommitApplier.prepareDeletion` accepts only a changed
  sparse prepared-store document, prepares selection backing and delivery
  state, obtains a Store-specific deletion install capability, and returns
  `PreparedDeletionApply` (`lib/src/edit/commit_applier.dart:291`,
  `lib/src/edit/commit_applier.dart:300`,
  `lib/src/edit/commit_applier.dart:315`,
  `lib/src/edit/commit_applier.dart:326`).
  **Data captured before resolver**: The prepared apply state includes the
  document, delivery effects, action intents, and prepared selection effect
  (`lib/src/edit/commit_applier.dart:444`,
  `lib/src/edit/commit_applier.dart:455`,
  `lib/src/edit/commit_applier.dart:497`,
  `lib/src/edit/commit_applier.dart:506`).

- **Location**: `lib/src/edit/commit_applier.dart:337`.
  **Description**: `PreparedDeletionApply` owns the current deferred deletion
  package. `consume()` transfers the selection backing, installs the bound
  Store commit, and installs the owned selection IDs
  (`lib/src/edit/commit_applier.dart:337`,
  `lib/src/edit/commit_applier.dart:355`,
  `lib/src/edit/commit_applier.dart:363`,
  `lib/src/edit/commit_applier.dart:376`).  `discard()` releases owned state
  without calling the Store or selection installers
  (`lib/src/edit/commit_applier.dart:380`,
  `lib/src/edit/commit_applier.dart:389`).  Its private ownership transfer
  raises `StateError` after a previous terminal call
  (`lib/src/edit/commit_applier.dart:391`,
  `lib/src/edit/commit_applier.dart:407`).

- **Location**: `lib/src/store/document_store_kernel.dart:803`.
  **Description**: Sparse preparation creates a transaction journal and a
  transaction candidate over the current committed document
  (`lib/src/store/document_store_kernel.dart:803`,
  `lib/src/store/document_store_kernel.dart:820`).  It replays mutations,
  performs relationship, delta, and deferred validation, freezes owners, and
  returns a `PreparedSparseStoreCommit` with base revisions, accepted document,
  touched facts, and admitted identifiers
  (`lib/src/store/document_store_kernel.dart:829`,
  `lib/src/store/document_store_kernel.dart:899`,
  `lib/src/store/document_store_kernel.dart:924`,
  `lib/src/store/document_store_kernel.dart:928`).

- **Location**: `lib/src/store/document_store_kernel.dart:1107`.
  **Description**: Ordinary sparse installation verifies base revisions and
  then assigns the prepared document to the Store
  (`lib/src/store/document_store_kernel.dart:1107`,
  `lib/src/store/document_store_kernel.dart:1118`).  Deletion preparation
  verifies a changed commit and base revisions before the resolver, while the
  bound deletion install performs the document assignment and accepts its
  captured admitted identifiers on consumption
  (`lib/src/store/document_store_kernel.dart:1120`,
  `lib/src/store/document_store_kernel.dart:1151`,
  `lib/src/store/document_store_kernel.dart:1153`,
  `lib/src/store/document_store_kernel.dart:1168`).

- **Location**: `lib/src/runtime/runtime_root.dart:2351`.
  **Description**: Runtime selection preparation normalizes source selection
  IDs against the prepared document; sparse normalization first validates base
  revisions (`lib/src/runtime/runtime_root.dart:2351`,
  `lib/src/runtime/runtime_root.dart:2378`,
  `lib/src/store/document_store_kernel.dart:646`,
  `lib/src/store/document_store_kernel.dart:665`).  The selection kernel either
  retains identical membership or assigns new owned IDs and increments
  `selectionRevision` (`lib/src/selection/selection_kernel.dart:98`,
  `lib/src/selection/selection_kernel.dart:102`,
  `lib/src/selection/selection_kernel.dart:130`).

### 5. Move route and temporary interaction state

- **Location**: `lib/src/interaction/interaction_engine.dart:486`.
  **Description**: In move mode, pointer-down reads selected-move facts and
  asks `MoveMachine.start` to create a selected-move session or a marquee
  session (`lib/src/interaction/interaction_engine.dart:486`,
  `lib/src/interaction/interaction_engine.dart:520`,
  `lib/src/interaction/interaction_engine.dart:524`).  A selected-move start
  decision captures selected IDs, movable IDs, prior selection, and selection
  revision (`lib/src/interaction/move_machine.dart:27`,
  `lib/src/interaction/move_machine.dart:31`,
  `lib/src/interaction/move_machine.dart:92`,
  `lib/src/interaction/move_machine.dart:96`).

- **Location**: `lib/src/interaction/interaction_engine.dart:730`.
  **Description**: Pointer movement produces a `CanvasSelectedMovePreview`;
  the preview delta is current world position minus session start world position
  (`lib/src/interaction/interaction_engine.dart:730`,
  `lib/src/interaction/interaction_engine.dart:748`,
  `lib/src/interaction/move_machine.dart:47`,
  `lib/src/interaction/move_machine.dart:53`).  The engine stores preview and
  interaction revisions independently (`lib/src/interaction/interaction_engine.dart:98`,
  `lib/src/interaction/interaction_engine.dart:107`).  Provisional selection
  replacement carries expected prior IDs and revision
  (`lib/src/interaction/interaction_engine.dart:751`,
  `lib/src/interaction/interaction_engine.dart:766`).

- **Location**: `lib/src/interaction/interaction_engine.dart:1559`.
  **Description**: On a terminal selected-move event, the engine obtains
  `SelectedMoveCommitFacts`, reports stale session IDs, and invokes
  `MoveMachine.terminal` (`lib/src/interaction/interaction_engine.dart:1563`,
  `lib/src/interaction/interaction_engine.dart:1575`,
  `lib/src/interaction/interaction_engine.dart:1583`).  The move machine
  rejects a zero proposed delta, an empty movable set, stale selection without
  provisional replacement, controller-epoch mismatch, and operations without
  document changes (`lib/src/interaction/move_machine.dart:55`,
  `lib/src/interaction/move_machine.dart:68`).  A permitted terminal route
  creates an intent containing the proposed delta, moved element reads,
  document summary, and selection bounds
  (`lib/src/interaction/move_machine.dart:137`,
  `lib/src/interaction/move_machine.dart:158`).

- **Location**: `lib/src/runtime/runtime_root.dart:2744`.
  **Description**: The runtime resolves the move delta before opening the edit
  callback. After an accepted non-zero delta, it creates a translation transform
  and uses each captured element transform to issue a typed element update
  (`lib/src/runtime/runtime_root.dart:2763`,
  `lib/src/runtime/runtime_root.dart:2830`,
  `lib/src/runtime/runtime_root.dart:2835`,
  `lib/src/runtime/runtime_root.dart:2844`).  The same edit callback adds a
  `MoveSelectionActionIntent` with moved IDs, transform, and timestamp hint
  (`lib/src/runtime/runtime_root.dart:2845`,
  `lib/src/runtime/runtime_root.dart:2852`).

- **Location**: `lib/src/runtime/runtime_action_finalizer.dart:93`.
  **Description**: The finalizer maps the move intent to
  `CanvasActionType.moveSelection` and a `CanvasTransformActionPayload` whose
  operation is `move` (`lib/src/runtime/runtime_action_finalizer.dart:93`,
  `lib/src/runtime/runtime_action_finalizer.dart:105`,
  `lib/src/runtime/runtime_action_finalizer.dart:149`,
  `lib/src/runtime/runtime_action_finalizer.dart:155`).  The action intent
  itself stores IDs and a transform, rather than a separate delta field
  (`lib/src/contracts/internal/commit_action_intent.dart:28`,
  `lib/src/contracts/internal/commit_action_intent.dart:43`).

- **Location**: `lib/src/frame/selected_move_supplement_planner.dart:58`.
  **Description**: A non-zero selected-move preview is rendered through the
  main-frame supplement planner, which replaces movable selected records with
  translated supplement records (`lib/src/frame/selected_move_supplement_planner.dart:58`,
  `lib/src/frame/selected_move_supplement_planner.dart:123`,
  `lib/src/frame/selected_move_supplement_planner.dart:135`,
  `lib/src/frame/selected_move_supplement_planner.dart:146`).  The overlay
  planner does not create an overlay primitive for this preview
  (`lib/src/frame/overlay_preview_planner.dart:108`,
  `lib/src/frame/overlay_preview_planner.dart:113`).

### 6. Draw, delete-selection, and erase routes

- **Location**: `lib/src/surface/pointer_adapter.dart:34`.
  **Description**: The surface pointer adapter converts Flutter pointer events
  into `CanvasPointerSample` and sends them to runtime input handling
  (`lib/src/surface/pointer_adapter.dart:34`,
  `lib/src/surface/pointer_adapter.dart:60`).  `RuntimeRoot.handlePointer`
  passes the sample, camera, epoch, selection, and timestamps into the
  interaction engine (`lib/src/runtime/runtime_root.dart:1591`,
  `lib/src/runtime/runtime_root.dart:1602`).

- **Location**: `lib/src/interaction/interaction_engine.dart:537`.
  **Description**: Pencil and marker input create a draw-stroke pointer session
  and an immutable stroke capture preview (`lib/src/interaction/interaction_engine.dart:537`,
  `lib/src/interaction/interaction_engine.dart:556`,
  `lib/src/interaction/draw_stroke_machine.dart:74`,
  `lib/src/interaction/draw_stroke_machine.dart:97`).  Pointer movement updates
  that temporary capture and preview (`lib/src/interaction/interaction_engine.dart:787`,
  `lib/src/interaction/interaction_engine.dart:810`).  The terminal route
  creates a `DrawStrokeCommitIntent` (`lib/src/interaction/interaction_engine.dart:1330`,
  `lib/src/interaction/interaction_engine.dart:1349`,
  `lib/src/interaction/draw_stroke_machine.dart:138`,
  `lib/src/interaction/draw_stroke_machine.dart:153`).

- **Location**: `lib/src/interaction/draw_stroke_machine.dart:12`.
  **Description**: The stroke machine admits only pencil and marker. Its
  terminal handling creates `DrawStrokeCommitIntent` even when the terminal
  point duplicates the prior point; duplicate preview points are its local
  `noChange` result, rather than a terminal no-op
  (`lib/src/interaction/draw_stroke_machine.dart:14`,
  `lib/src/interaction/draw_stroke_machine.dart:32`,
  `lib/src/interaction/draw_stroke_machine.dart:51`,
  `lib/src/interaction/draw_stroke_machine.dart:59`,
  `lib/src/interaction/draw_stroke_machine.dart:117`).  The existing machine
  test includes a terminal commit with one point
  (`test/interaction/draw_stroke_machine_test.dart:75`,
  `test/interaction/draw_stroke_machine_test.dart:96`).

- **Location**: `lib/src/interaction/line_machine.dart:27`.
  **Description**: Line is a distinct draw path. A first line tap beyond
  `tapSlop` is rejected; an admitted first tap is retained as a pending line in
  the interaction engine (`lib/src/interaction/line_machine.dart:27`,
  `lib/src/interaction/interaction_engine.dart:1391`,
  `lib/src/interaction/interaction_engine.dart:1418`).  Its endpoint terminal
  creates `DrawLineCommitIntent` without a length check, including an endpoint
  equal to the pending point (`lib/src/interaction/line_machine.dart:66`,
  `lib/src/interaction/line_machine.dart:73`,
  `test/interaction/line_machine_test.dart:125`,
  `test/interaction/line_machine_test.dart:140`).

- **Location**: `lib/src/interaction/interaction_engine.dart:1330`.
  **Description**: A missing stroke capture produces `noOpTerminal` cleanup;
  cancellation and stale terminals produce no stroke commit
  (`lib/src/interaction/interaction_engine.dart:1335`,
  `lib/src/interaction/interaction_engine.dart:906`,
  `lib/src/interaction/interaction_engine.dart:1487`).  Missing line captures
  likewise take no-op terminal cleanup
  (`lib/src/interaction/interaction_engine.dart:1396`,
  `lib/src/interaction/interaction_engine.dart:1433`).  Draw/line interaction
  fixtures witness no commit for cancelled, stale, or no-active stroke
  terminals and cleanup-only line endpoints/pending lines
  (`test/interaction/fixtures/draw_stroke_interaction_routing_fixture.dart:141`,
  `test/interaction/fixtures/draw_stroke_interaction_routing_fixture.dart:157`,
  `test/interaction/fixtures/draw_stroke_interaction_routing_fixture.dart:174`,
  `test/interaction/fixtures/line_interaction_routing_fixture.dart:305`,
  `test/interaction/fixtures/line_interaction_routing_fixture.dart:339`,
  `test/interaction/fixtures/line_interaction_routing_fixture.dart:357`).

- **Location**: `lib/src/runtime/runtime_root.dart:2944`.
  **Description**: Stroke and line delivery routes read an element ID candidate,
  create the corresponding element, and invoke the ordinary interaction-commit
  path (`lib/src/runtime/runtime_root.dart:2949`,
  `lib/src/runtime/runtime_root.dart:2992`,
  `lib/src/runtime/runtime_root.dart:3000`,
  `lib/src/runtime/runtime_root.dart:3033`,
  `lib/src/runtime/runtime_root.dart:3038`,
  `lib/src/runtime/runtime_root.dart:3081`,
  `lib/src/runtime/runtime_root.dart:3090`).  They clear pointer state and
  preview before common delivery (`lib/src/runtime/runtime_root.dart:2962`,
  `lib/src/runtime/runtime_root.dart:2980`).  These routes do not invoke
  `_resolveDeletion`, `_resolveSelectedMoveDelta`, or `runResolverCallback`;
  the configured commit-resolver call sites are the deletion and move routes
  (`lib/src/runtime/runtime_root.dart:1111`,
  `lib/src/runtime/runtime_root.dart:2805`).

- **Location**: `lib/src/store/document_store_kernel.dart:680`.
  **Description**: `readElementIdCandidate()` only observes an ID candidate;
  `generateElementId()` is the separate API that reserves the candidate
  (`lib/src/store/document_store_kernel.dart:674`,
  `lib/src/store/document_store_kernel.dart:680`,
  `lib/src/store/document_store_kernel.dart:3741`,
  `lib/src/store/document_store_kernel.dart:3751`).  Sparse accepted-add
  accounting includes IDs in `admittedElementIds`, and Store installation
  assigns the document before accepting that ledger
  (`lib/src/store/document_store_kernel.dart:3201`,
  `lib/src/store/document_store_kernel.dart:3298`,
  `lib/src/store/document_store_kernel.dart:3314`,
  `lib/src/store/document_store_kernel.dart:1107`,
  `lib/src/store/document_store_kernel.dart:1114`).

- **Location**: `lib/src/runtime/runtime_root.dart:1026`.
  **Description**: `deleteSelection` reads removal entries and returns without
  a deletion commit when the entry set is empty
  (`lib/src/runtime/runtime_root.dart:1026`,
  `lib/src/runtime/runtime_root.dart:1030`,
  `lib/src/runtime/runtime_root.dart:1145`,
  `lib/src/runtime/runtime_root.dart:1167`).  For entries, it prepares deferred
  deletion, creates a request containing copied deletion entries, resolves it,
  then either discards or consumes the prepared package
  (`lib/src/runtime/runtime_root.dart:1035`,
  `lib/src/runtime/runtime_root.dart:1054`,
  `lib/src/runtime/runtime_root.dart:1060`,
  `lib/src/runtime/runtime_root.dart:1065`,
  `lib/src/runtime/runtime_root.dart:1067`,
  `lib/src/runtime/runtime_root.dart:1105`).

- **Location**: `lib/src/interaction/eraser_machine.dart:14`.
  **Description**: The eraser starts only for the eraser draw tool and stores
  a corridor capture with thickness (`lib/src/interaction/eraser_machine.dart:17`,
  `lib/src/interaction/eraser_machine.dart:31`).  Pointer movement updates an
  eraser preview (`lib/src/interaction/interaction_engine.dart:813`,
  `lib/src/interaction/interaction_engine.dart:851`).  Terminal facts contain
  an immutable corridor, Store-derived entries, exact-check count, budget flag,
  and query facts (`lib/src/interaction/interaction_read_port.dart:183`,
  `lib/src/interaction/interaction_read_port.dart:218`).  Empty entries and an
  exceeded exact-check budget terminate as no-op cases
  (`lib/src/interaction/eraser_machine.dart:47`,
  `lib/src/interaction/eraser_machine.dart:58`,
  `lib/src/interaction/eraser_machine.dart:276`,
  `lib/src/interaction/eraser_machine.dart:293`).

- **Location**: `lib/src/runtime/runtime_root.dart:3148`.
  **Description**: The eraser route prepares deferred deletion, appends an
  `EraseActionIntent`, creates a deletion request with operation `erase`, and
  resolves it through the shared deletion resolver
  (`lib/src/runtime/runtime_root.dart:3148`,
  `lib/src/runtime/runtime_root.dart:3184`,
  `lib/src/runtime/runtime_root.dart:3211`,
  `lib/src/runtime/runtime_root.dart:3238`).  Cancellation or resolver error
  discards the prepared package and performs eraser cleanup; acceptance
  consumes it and performs post-success cleanup
  (`lib/src/runtime/runtime_root.dart:3167`,
  `lib/src/runtime/runtime_root.dart:3183`,
  `lib/src/runtime/runtime_root.dart:3185`,
  `lib/src/runtime/runtime_root.dart:3204`).

### 7. Rotate and reflect-equivalent command routes

- **Location**: `lib/src/contracts/public/canvas_runtime.dart:218`.
  **Description**: `CanvasSelectionPort` declares clockwise and
  counter-clockwise rotation plus vertical and horizontal flip commands
  (`lib/src/contracts/public/canvas_runtime.dart:218`,
  `lib/src/contracts/public/canvas_runtime.dart:224`,
  `lib/src/contracts/public/canvas_runtime.dart:227`).  The implementation
  delegates these commands to `RuntimeRoot`
  (`lib/src/runtime/runtime_root.dart:3531`,
  `lib/src/runtime/runtime_root.dart:3547`).

- **Location**: `lib/src/runtime/runtime_root.dart:990`.
  **Description**: The rotate entry points construct +90 and -90 degree
  transforms; flip entry points construct scale transforms `(1, -1)` and
  `(-1, 1)` (`lib/src/runtime/runtime_root.dart:990`,
  `lib/src/runtime/runtime_root.dart:1006`,
  `lib/src/runtime/runtime_root.dart:1008`,
  `lib/src/runtime/runtime_root.dart:1024`).  All enter
  `_deliverSelectionTransformAroundCenter`
  (`lib/src/runtime/runtime_root.dart:1177`,
  `lib/src/runtime/runtime_root.dart:1194`).

- **Location**: `lib/src/runtime/selection_transform_facts_reader.dart:37`.
  **Description**: The shared transform route reads selected IDs, resolves
  document-order handles, filters movable elements, and unions their paint
  bounds (`lib/src/runtime/selection_transform_facts_reader.dart:42`,
  `lib/src/runtime/selection_transform_facts_reader.dart:72`).  An element is
  movable only when it is content, unlocked, and transformable
  (`lib/src/runtime/selection_transform_facts_reader.dart:89`,
  `lib/src/runtime/selection_transform_facts_reader.dart:93`).

- **Location**: `lib/src/runtime/runtime_root.dart:1177`.
  **Description**: The shared route returns without a commit when it has no
  movable elements or no selection bounds. Otherwise it calculates a centre
  pivot and composes the requested transform around it
  (`lib/src/runtime/runtime_root.dart:1182`,
  `lib/src/runtime/runtime_root.dart:1185`,
  `lib/src/runtime/runtime_root.dart:1186`,
  `lib/src/runtime/runtime_root.dart:1193`,
  `lib/src/runtime/runtime_root.dart:3407`,
  `lib/src/runtime/runtime_root.dart:3411`).

- **Location**: `lib/src/runtime/runtime_root.dart:1199`.
  **Description**: For each movable element, the route produces a typed update
  with `transform.multiply(element.transform)`, records a
  `TransformSelectionActionIntent`, and invokes the ordinary interaction-commit
  path (`lib/src/runtime/runtime_root.dart:1206`,
  `lib/src/runtime/runtime_root.dart:1210`,
  `lib/src/runtime/runtime_root.dart:1220`,
  `lib/src/runtime/runtime_root.dart:1244`,
  `lib/src/runtime/runtime_root.dart:3413`,
  `lib/src/runtime/runtime_root.dart:3445`).

- **Location**: `lib/src/contracts/public/canvas_preview.dart:5`.
  **Description**: The preview enum contains no rotate or flip variant; the
  selection-transform preview holds only a move delta
  (`lib/src/contracts/public/canvas_preview.dart:5`,
  `lib/src/contracts/public/canvas_preview.dart:14`,
  `lib/src/contracts/public/canvas_preview.dart:37`,
  `lib/src/contracts/public/canvas_preview.dart:43`).  Searches in
  `lib/src/interaction`, `lib/src/diagnostics`, `lib/src/frame`, and
  `lib/src/surface` found no production pointer/tool initiation, temporary
  preview, confirmation callback, or dedicated diagnostic for rotate or flip.

### 8. Common delivery, runtime publication, and actions

- **Location**: `lib/src/edit/commit_compiler.dart:12`.
  **Description**: The compiler derives selection prune and delivery effects
  from accepted revisions and touched facts
  (`lib/src/edit/commit_compiler.dart:12`,
  `lib/src/edit/commit_compiler.dart:29`,
  `lib/src/edit/commit_compiler.dart:42`,
  `lib/src/edit/commit_compiler.dart:89`).  `CommitApplier.apply` prepares
  document and selection state before install, installs the prepared document,
  then installs the selection effect
  (`lib/src/edit/commit_applier.dart:257`,
  `lib/src/edit/commit_applier.dart:283`,
  `lib/src/edit/commit_applier.dart:423`,
  `lib/src/edit/commit_applier.dart:442`).

- **Location**: `lib/src/runtime/runtime_root.dart:2416`.
  **Description**: `_deliverEditCommitResult` enables a delivery guard, applies
  spatial effects, applies resource effects, publishes state when required,
  emits actions, invokes the effect observer, and disables the guard in
  `finally` (`lib/src/runtime/runtime_root.dart:2416`,
  `lib/src/runtime/runtime_root.dart:2440`,
  `lib/src/runtime/runtime_root.dart:2448`,
  `lib/src/runtime/runtime_root.dart:2459`,
  `lib/src/runtime/runtime_root.dart:2483`,
  `lib/src/runtime/runtime_root.dart:2484`,
  `lib/src/runtime/runtime_root.dart:2490`,
  `lib/src/runtime/runtime_root.dart:2498`).

- **Location**: `lib/src/runtime/runtime_root.dart:2077`.
  **Description**: `_publishRuntimeState` builds `CanvasRuntimeState` from
  Store, selection, and revision facts, publishes a surface frame where needed,
  and then assigns the state notifier
  (`lib/src/runtime/runtime_root.dart:2080`,
  `lib/src/runtime/runtime_root.dart:2093`,
  `lib/src/runtime/runtime_root.dart:2095`,
  `lib/src/runtime/runtime_root.dart:2101`).

- **Location**: `lib/src/runtime/runtime_root.dart:2671`.
  **Description**: `_emitActions` finalizes commit action intents and adds each
  `CanvasActionCommitted` to a synchronous broadcast controller
  (`lib/src/runtime/runtime_root.dart:2671`,
  `lib/src/runtime/runtime_root.dart:2676`,
  `lib/src/runtime/runtime_root.dart:2683`,
  `lib/src/runtime/runtime_root.dart:2685`).  The controller is configured as
  broadcast and synchronous (`lib/src/runtime/runtime_root.dart:325`,
  `lib/src/runtime/runtime_root.dart:326`), and the public facade exposes it
  through `CanvasRuntime.actions` (`lib/src/api/canvas_runtime.dart:48`).

- **Location**: `lib/src/runtime/runtime_action_finalizer.dart:35`.
  **Description**: Finalization allocates sequence-based action IDs and applies
  a monotonic timestamp cursor (`lib/src/runtime/runtime_action_finalizer.dart:35`,
  `lib/src/runtime/runtime_action_finalizer.dart:37`,
  `lib/src/runtime/runtime_action_finalizer.dart:77`,
  `lib/src/runtime/runtime_action_finalizer.dart:89`).  The current type
  mapping includes move, transform, delete, pencil/marker/line, and erase
  intents (`lib/src/runtime/runtime_action_finalizer.dart:93`,
  `lib/src/runtime/runtime_action_finalizer.dart:105`).

### 9. Existing test witnesses relevant to confirmation semantics

- **Location**: `test/resources/fixtures/resolver_reentrancy_rejected_fixture.dart:29`.
  **Description**: The fixture covers nested resolver invocation, public
  mutation, and disposal attempted during resolver execution. Its witnesses
  expect `ResolverCallbackRejection`, unchanged document/resource/selection/
  camera state, no action, and a subsequent successful resolver route
  (`test/resources/fixtures/resolver_reentrancy_rejected_fixture.dart:29`,
  `test/resources/fixtures/resolver_reentrancy_rejected_fixture.dart:50`,
  `test/resources/fixtures/resolver_reentrancy_rejected_fixture.dart:89`,
  `test/resources/fixtures/resolver_reentrancy_rejected_fixture.dart:170`,
  `test/resources/fixtures/resolver_reentrancy_rejected_fixture.dart:220`).

- **Location**: `test/runtime/fixtures/common_commit_delivery_fixture.dart:105`.
  **Description**: The common delivery fixture checks the trace
  `guard -> spatial -> [resource] -> frame -> bridge-frame -> state -> action
  -> observer -> guard-release` for marquee, clear-content, and changed-text
  commits (`test/runtime/fixtures/common_commit_delivery_fixture.dart:105`,
  `test/runtime/fixtures/common_commit_delivery_fixture.dart:126`,
  `test/runtime/fixtures/common_commit_delivery_fixture.dart:151`,
  `test/runtime/fixtures/common_commit_delivery_fixture.dart:175`,
  `test/runtime/fixtures/common_commit_delivery_fixture.dart:211`,
  `test/runtime/fixtures/common_commit_delivery_fixture.dart:238`).

- **Location**: `test/runtime/fixtures/common_commit_delivery_fixture.dart:447`.
  **Description**: The fixture has a throwing action-listener case in which a
  peer listener and observer continue and the document remains committed
  (`test/runtime/fixtures/common_commit_delivery_fixture.dart:447`,
  `test/runtime/fixtures/common_commit_delivery_fixture.dart:489`).  It also
  verifies post-delivery mutation rejections and observer-failure containment
  (`test/runtime/fixtures/common_commit_delivery_fixture.dart:518`,
  `test/runtime/fixtures/common_commit_delivery_fixture.dart:603`,
  `test/runtime/fixtures/common_commit_delivery_fixture.dart:635`,
  `test/runtime/fixtures/common_commit_delivery_fixture.dart:699`).

- **Location**: `test/runtime/fixtures/draw_commit_delivery_fixture.dart:59`.
  **Description**: Draw tests cover pencil, marker, and line cleanup before
  common delivery, emitted draw actions, committed revision visibility, and
  failed draw/line preparation that leaves the document revision unchanged and
  emits no action (`test/runtime/fixtures/draw_commit_delivery_fixture.dart:59`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:171`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:228`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:389`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:397`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:491`).  The failed
  route keeps `generateElementId()` at `e0`; work probes distinguish one
  candidate observation for failed draw from accepted ledger admission for
  successful pencil/line routes
  (`test/runtime/fixtures/draw_commit_delivery_fixture.dart:397`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:430`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:451`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:468`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:581`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:643`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:896`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:904`).  These are
  preparation-failure witnesses: current Draw has no resolver, accept result,
  or lease stage (`lib/src/runtime/runtime_root.dart:2944`,
  `lib/src/runtime/runtime_root.dart:3033`).

- **Location**: `test/interaction/fixtures/move_machine_fixture.dart:1208`.
  **Description**: The move fixture verifies that an accepted resolver delta
  `(7, 8)` becomes the applied transform and emitted action transform. It also
  covers one callback for cancellation and zero returned delta, no action for
  both, resolver error/non-finite delta cleanup, cleanup without callback, a
  preparation failure after one callback, and later successful execution
  (`test/interaction/fixtures/move_machine_fixture.dart:1208`,
  `test/interaction/fixtures/move_machine_fixture.dart:1221`,
  `test/interaction/fixtures/move_machine_fixture.dart:1225`,
  `test/interaction/fixtures/move_machine_fixture.dart:1231`,
  `test/interaction/fixtures/move_machine_fixture.dart:1248`,
  `test/interaction/fixtures/move_machine_fixture.dart:1287`,
  `test/interaction/fixtures/move_machine_fixture.dart:1329`,
  `test/interaction/fixtures/move_machine_fixture.dart:1351`,
  `test/interaction/fixtures/move_machine_fixture.dart:1397`,
  `test/interaction/fixtures/move_machine_fixture.dart:1448`,
  `test/interaction/fixtures/move_machine_fixture.dart:1548`,
  `test/interaction/fixtures/move_machine_fixture.dart:1606`).

- **Location**: `test/api/fixtures/selection_deletion_resolver_fixture.dart:28`.
  **Description**: The selection-delete fixture covers the immutable canonical
  Store entry projection, cancellation, ordinary resolver throws,
  resolver-silent empty and all-or-none-rejected selections, reentrant
  mutation diagnostics, preparation failure before a resolver call, and
  accepted state/action listener failures
  (`test/api/fixtures/selection_deletion_resolver_fixture.dart:28`,
  `test/api/fixtures/selection_deletion_resolver_fixture.dart:34`,
  `test/api/fixtures/selection_deletion_resolver_fixture.dart:40`,
  `test/api/fixtures/selection_deletion_resolver_fixture.dart:46`,
  `test/api/fixtures/selection_deletion_resolver_fixture.dart:66`,
  `test/api/fixtures/selection_deletion_resolver_fixture.dart:70`).  Its
  accepted case asserts operation, entry order, immutable entry list, one
  delete action, and state-before-action ordering; its cancellation case
  asserts one callback and no diagnostic
  (`test/api/fixtures/selection_deletion_resolver_fixture.dart:157`,
  `test/api/fixtures/selection_deletion_resolver_fixture.dart:168`,
  `test/api/fixtures/selection_deletion_resolver_fixture.dart:172`,
  `test/api/fixtures/selection_deletion_resolver_fixture.dart:181`,
  `test/api/fixtures/selection_deletion_resolver_fixture.dart:201`,
  `test/api/fixtures/selection_deletion_resolver_fixture.dart:219`,
  `test/api/fixtures/selection_deletion_resolver_fixture.dart:225`).

- **Location**: `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:40`.
  **Description**: The eraser fixture covers exact Store entry projection and
  cleanup before delivery, kind filtering, cancellation and ordinary resolver
  throws without commit, resolver-silent non-delete terminals, preparation
  failure before a resolver call, and accepted delivery failures
  (`test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:40`,
  `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:46`,
  `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:52`,
  `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:69`,
  `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:75`,
  `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:981`).
  It asserts the `erase` operation, exact entries, cleanup before action
  delivery, one callback with unchanged document/cleared preview and session
  on cancellation or throw, and diagnostics only for the throw case
  (`test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:303`,
  `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:309`,
  `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:317`,
  `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:328`,
  `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:492`,
  `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:539`,
  `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:544`,
  `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart:550`).

- **Location**: `test/runtime/fixtures/deletion_resolver_work_fixture.dart:28`.
  **Description**: The deletion work fixture covers a single bounded package
  construction and consumption for both deletion routes, fixed-K work as
  unrelated document size grows, request-entry copies, accepted eraser cleanup
  through delivery failure, and discard without rollback replay
  (`test/runtime/fixtures/deletion_resolver_work_fixture.dart:28`,
  `test/runtime/fixtures/deletion_resolver_work_fixture.dart:86`,
  `test/runtime/fixtures/deletion_resolver_work_fixture.dart:134`,
  `test/runtime/fixtures/deletion_resolver_work_fixture.dart:188`).  Its shared
  oracle expects one callback, one construction marker, accepted prepare/
  install/selection work or a discarded package with no selection installation
  (`test/runtime/fixtures/deletion_resolver_work_fixture.dart:429`,
  `test/runtime/fixtures/deletion_resolver_work_fixture.dart:436`,
  `test/runtime/fixtures/deletion_resolver_work_fixture.dart:447`,
  `test/runtime/fixtures/deletion_resolver_work_fixture.dart:469`).

- **Location**: `test/api/fixtures/selection_transform_commands_fixture.dart:147`.
  **Description**: Existing fixtures witness centre-pivot behaviour, rotate
  action emission, and horizontal flip action emission
  (`test/api/fixtures/selection_transform_commands_fixture.dart:147`,
  `test/api/fixtures/selection_transform_commands_fixture.dart:161`).  Typed
  action payload coverage includes rotate and vertical flip
  (`test/api/fixtures/typed_action_payloads_runtime_fixture.dart:255`).

- **Location**: `test/diagnostics/fixtures/interaction_diagnostics_fixture.dart:192`.
  **Description**: Diagnostic tests witness resolver reentrant-mutation records
  and verify that the rejected mutation emits no action while the transform
  remains identity (`test/diagnostics/fixtures/interaction_diagnostics_fixture.dart:192`,
  `test/diagnostics/fixtures/interaction_diagnostics_fixture.dart:259`).

## Code References

- `lib/src/contracts/public/canvas_runtime.dart:24` — configured deletion and move callback parameters.
- `lib/src/contracts/public/canvas_actions.dart:221` — move resolver type.
- `lib/src/contracts/public/canvas_actions.dart:225` — immutable move request.
- `lib/src/contracts/public/canvas_deletion.dart:7` — deletion resolver type.
- `lib/src/contracts/public/canvas_deletion.dart:65` — immutable deletion request.
- `lib/src/runtime/runtime_config.dart:9` — materialization of public resolver configuration.
- `lib/src/runtime/runtime_root.dart:1108` — deletion resolver execution.
- `lib/src/runtime/runtime_root.dart:1936` — resolver mutation guard.
- `docs/contracts/public_api_v1.md:2951` — current selected-move resolver call/no-op rules.
- `docs/contracts/operation_matrix.md:58` — current route-specific resolver ordering.
- `docs/architecture/03_data_model.md:128` — private Store candidate and accepted/no-op aggregate rules.
- `lib/src/edit/edit_kernel.dart:121` — immediate ordinary interaction commit.
- `lib/src/edit/edit_kernel.dart:159` — deferred deletion preparation.
- `lib/src/edit/commit_applier.dart:291` — deletion-only prepared apply package.
- `lib/src/edit/commit_applier.dart:355` — deferred deletion consumption.
- `lib/src/edit/commit_applier.dart:380` — deferred deletion discard.
- `lib/src/store/document_store_kernel.dart:803` — sparse candidate preparation.
- `lib/src/store/document_store_kernel.dart:1107` — sparse document installation.
- `lib/src/runtime/runtime_root.dart:2744` — move resolver before transform preparation.
- `lib/src/runtime/runtime_root.dart:2830` — accepted move transform preparation.
- `lib/src/runtime/runtime_root.dart:2944` — direct draw preparation.
- `lib/src/interaction/line_machine.dart:27` — distinct line input and terminal route.
- `lib/src/store/document_store_kernel.dart:680` — candidate observation rather than reservation.
- `lib/src/runtime/runtime_root.dart:3148` — eraser deferred deletion preparation.
- `lib/src/runtime/runtime_root.dart:990` — rotate and flip entry points.
- `lib/src/runtime/runtime_root.dart:1177` — shared selection-transform command route.
- `lib/src/runtime/runtime_root.dart:2416` — common commit delivery ordering.
- `lib/src/runtime/runtime_root.dart:2671` — action finalization and emission.

## Search Coverage

- **Inspected**: Public runtime, actions, deletion, preview, geometry,
  diagnostics, and error contracts; public facades and root barrel; runtime
  resolver, publication, delivery, action-finalization, command-facts, and
  interaction diagnostics owners; interaction move/draw/line/eraser owners;
  edit kernel, commit applier/compiler/plan, Store sparse/deletion/ID-admission
  installation, and selection owners; frame preview planners; the listed
  fixtures; public API/operation-matrix/data-model contracts; and historical
  runtime delivery plan.
- **Searched**: `lib/src`, `test`, public-contract and architecture documents,
  and applicable historical documentation for
  `prepared`, `transaction`, `commit`, `resolver`, `lease`, `move`, `draw`,
  `delete`, `erase`, `rotate`, `rotation`, `reflect`, `reflection`, `flip`,
  `transform`, `state`, `action`, `publication`, `diagnostic`, `reentrancy`,
  `mutation-guard`, `beginTransaction`, `rollback`, candidate-ID observation,
  reservation, admission, and no-op terminal terms.
- **Not found**: A public confirmation type containing `Lease` in its name;
  a public `beginTransaction` or `rollback` API in the root barrel, public API
  facades, or public contract declarations;
  a production rotate/flip pointer or tool interaction route; a rotate/flip
  preview variant; a rotate/flip confirmation resolver; rotate/flip-specific
  diagnostics; and a production construction path for `PreparedDeletionApply`
  other than `CommitApplier.prepareDeletion`.
- **Not inspected**: No production operation family named by the research
  question was intentionally left unexamined. The rendering implementation was
  inspected only where needed to confirm selected-move preview routing; it was
  not traced as a full rendering architecture investigation.

## Observed Architecture Facts

- **Current confirmation split**: Public configuration owns separate deletion
  and move callbacks (`lib/src/contracts/public/canvas_runtime.dart:24`,
  `lib/src/contracts/public/canvas_runtime.dart:40`,
  `lib/src/contracts/public/canvas_runtime.dart:41`); their request and result
  types live in separate public contracts
  (`lib/src/contracts/public/canvas_actions.dart:221`,
  `lib/src/contracts/public/canvas_deletion.dart:7`).

- **Existing deferred boundary**: Deletion preparation creates a private,
  single-use package before resolver execution. Its terminal operations either
  install document and selection ownership or release ownership without either
  install (`lib/src/edit/edit_kernel.dart:159`,
  `lib/src/edit/commit_applier.dart:291`,
  `lib/src/edit/commit_applier.dart:355`,
  `lib/src/edit/commit_applier.dart:380`).

- **Move temporal boundary**: Move preview and provisional selection are held in
  interaction state before terminal resolution, and transform edit preparation
  happens only after final delta resolution
  (`lib/src/interaction/interaction_engine.dart:730`,
  `lib/src/interaction/interaction_engine.dart:1559`,
  `lib/src/runtime/runtime_root.dart:2744`,
  `lib/src/runtime/runtime_root.dart:2830`).

- **Store and selection install boundary**: Sparse Store commits are prepared
  with base revisions and become committed when installation assigns the
  prepared document; prepared selection IDs are installed by the selection
  kernel, which increments selection revision only when membership changes
  (`lib/src/store/document_store_kernel.dart:899`,
  `lib/src/store/document_store_kernel.dart:1107`,
  `lib/src/selection/selection_kernel.dart:102`,
  `lib/src/selection/selection_kernel.dart:130`).

- **Commit publication boundary**: Common delivery publishes state before
  action emission, after spatial and resource effects
  (`lib/src/runtime/runtime_root.dart:2448`,
  `lib/src/runtime/runtime_root.dart:2459`,
  `lib/src/runtime/runtime_root.dart:2483`,
  `lib/src/runtime/runtime_root.dart:2484`).

- **Resolver safety boundary**: Resolver callbacks are guarded against nested
  callbacks and public runtime mutation; diagnostics have an existing
  interaction-error path (`lib/src/runtime/runtime_root.dart:1936`,
  `lib/src/runtime/runtime_root.dart:1964`,
  `lib/src/runtime/runtime_interaction_diagnostics_adapter.dart:123`).

- **Current resolver timing and silence**: The maintained contract records one
  selected-move callback only at a qualified terminal pointer-up, with no call
  for the documented no-op and cleanup cases. It records resolver-before-
  preparation for move and preparation-before-resolver for delete/erase
  (`docs/contracts/public_api_v1.md:2951`,
  `docs/contracts/public_api_v1.md:2954`,
  `docs/contracts/operation_matrix.md:58`,
  `docs/contracts/operation_matrix.md:60`,
  `docs/contracts/operation_matrix.md:85`).

- **Candidate-ID lifecycle**: Draw reads a candidate ID without reserving it;
  the Store reserves through a different API and admits accepted add IDs through
  the prepared sparse ledger after document assignment
  (`lib/src/store/document_store_kernel.dart:674`,
  `lib/src/store/document_store_kernel.dart:680`,
  `lib/src/store/document_store_kernel.dart:3741`,
  `lib/src/store/document_store_kernel.dart:3751`,
  `lib/src/store/document_store_kernel.dart:1107`,
  `lib/src/store/document_store_kernel.dart:1114`).

## Open Questions

- The supplied planned-change text names distinct public request classes for
  Draw, Delete, Erase, Move, Rotate, and Reflect, but gives explicit request
  data only for `CanvasMoveCommitRequest.proposedDelta`. Current public data
  differs by route: move has document summary, element reads, proposed delta,
  and selection bounds (`lib/src/contracts/public/canvas_actions.dart:225`),
  while deletion has an operation plus deletion entries
  (`lib/src/contracts/public/canvas_deletion.dart:51`). The current Draw and
  selection-transform routes do not expose confirmation request types
  (`lib/src/runtime/runtime_root.dart:2944`,
  `lib/src/runtime/runtime_root.dart:1199`).

- The current `Draw` family contains separate pencil/marker stroke and line
  terminal intents, with different temporary-state paths
  (`lib/src/interaction/draw_stroke_machine.dart:51`,
  `lib/src/interaction/line_machine.dart:66`,
  `lib/src/runtime/runtime_root.dart:2944`,
  `lib/src/runtime/runtime_root.dart:3033`). The supplied planned-change text
  names one `CanvasDrawCommitRequest` without specifying whether the request
  distinguishes these current paths or which stroke/line facts it contains.

- The supplied planned-change text uses one `Reflect` operation. Existing
  public commands and actions distinguish `flipSelectionVertical` and
  `flipSelectionHorizontal`, and their runtime operations are
  `flipVertical` and `flipHorizontal`
  (`lib/src/contracts/public/canvas_runtime.dart:224`,
  `lib/src/contracts/public/canvas_runtime.dart:227`,
  `lib/src/runtime/runtime_root.dart:1008`,
  `lib/src/runtime/runtime_root.dart:1024`).

- The supplied planned-change text introduces `CanvasCommitLease`. No public
  lease type was found in the searched public contracts, and current resolver
  result types have no callback ownership field
  (`lib/src/contracts/public/canvas_actions.dart:289`,
  `lib/src/contracts/public/canvas_deletion.dart:13`).

- Current Draw preparation-failure tests run before any Draw resolver,
  acceptance result, or lease stage because no such stage exists on the current
  Draw routes (`lib/src/runtime/runtime_root.dart:2944`,
  `lib/src/runtime/runtime_root.dart:3033`,
  `test/runtime/fixtures/draw_commit_delivery_fixture.dart:397`).

- The supplied planned-change text requires a prepared commit for each named
  operation. Current pre-resolver prepared ownership exists only for deletion;
  draw and selection transforms use the immediate preparation-and-install route,
  while move prepares its transform after resolution
  (`lib/src/edit/edit_kernel.dart:121`,
  `lib/src/edit/edit_kernel.dart:159`,
  `lib/src/runtime/runtime_root.dart:2744`,
  `lib/src/runtime/runtime_root.dart:2944`,
  `lib/src/runtime/runtime_root.dart:1199`).

- The supplied planned-change text requires the committed Move action to carry
  the applied final delta. The current move action intent and public transform
  payload use a transform matrix and operation label; this research did not
  find a separately stored move delta in that action path
  (`lib/src/contracts/internal/commit_action_intent.dart:28`,
  `lib/src/contracts/internal/commit_action_intent.dart:43`,
  `lib/src/runtime/runtime_action_finalizer.dart:149`,
  `lib/src/runtime/runtime_action_finalizer.dart:155`).
