# Change Contract

## Goal

Implement P5 edit core as the single synchronous mutation boundary for the
runtime: public `CanvasRuntime.edits.edit` opens rollback-safe edit sessions,
low-level `CanvasEdit` mutations commit atomically across document and
selection owners, failed or no-op edits publish no side effects, and accepted
edits emit only typed post-install effects for downstream owners without
depending on concrete frame, spatial, resource, interaction, or Flutter
implementations.

## Evidence

- `.design/2026-05-24-p5-edit-core.md` / disposition and selected form: the
  design is ready for contract and selects an edit-owned transaction subsystem
  under `lib/src/edit/**`, composed by `RuntimeRoot` and exposed through the
  existing public edit API -> implement the P5 behavior through an EditKernel
  seam, not direct ad hoc mutations in `RuntimeRoot`.
- `.design/2026-05-24-p5-edit-core.md` / non-goals: undo/redo, command-owned
  user action events, interaction tools, load-document staging, frame
  rendering, resources, spatial indexes, and Flutter surface behavior are not
  P5 implementation scope -> this step must publish typed effects only and keep
  later owners as consumers, not prerequisites.
- `.design/2026-05-24-p5-edit-core.md` / target classification: the selected
  contract profile is BEHAVIOR_CHANGE with no additional obligations -> the
  work turns existing public edit declarations into runtime behavior without
  changing public signatures.
- `.design/2026-05-24-p5-edit-core.md` / verification impact: the design
  requires focused edit tests, cross-owner tests, P5 guardrails, and one real
  public edit step appended to `test/smoke/public_incremental_smoke_test.dart`
  through the root public barrel -> P5 proof must include both internal
  owner-focused tests and public consumer compatibility.
- `docs/implementation/p5_edit_core.md` / purpose and build scope: P5 owns
  synchronous edit sessions, atomic commit/rollback, `EditKernel`,
  `EditSession`, `DraftDocument`, `TouchedSet`, `CommitCompiler`,
  `CommitPlan`, `CommitApplier`, stale-handle rejection, exact touched
  invalidation, and typed effects -> these are the required implementation
  surfaces.
- `docs/implementation/p5_edit_core.md` / exit gate: P5 is complete only when
  sync/non-nested/async/stale, rollback, operation matrix, runtime state
  publication, exact touched invalidation, typed-effect, and low-level
  no-action-event proofs are green -> implementation must add or complete the
  named tests rather than relying on manual inspection.
- `docs/implementation/p5_edit_core.md` / donor decisions: P5 requires
  adapting `dto_document_helpers` into `DocumentStoreKernel`, `SelectionKernel`,
  and `EditKernel` helpers, and adapting `interaction_mutation_boundary` as the
  future interaction-owned bridge into `EditKernel` -> donor use is targeted
  adaptation only, not legacy structure copying.
- `docs/implementation/p5_edit_core.md` / forbidden donor structure: P5 must
  avoid `avoid_scene_controller_facades`, `avoid_interactive_runtime_whole`,
  `avoid_scene_builder_public_architecture`, `avoid_scene_codec_whole`, and
  `avoid_scene_store_controller_whole` -> implementation must not import,
  recreate, or rename legacy controller/builder/codec/store-controller shapes
  as the P5 edit architecture.
- `docs/_registry/donors.yaml` / `dto_document_helpers`: this donor may be
  adapted for pure document edit, clone, and selection helper behavior, but its
  ownership must not conflict with the store/selection/edit split -> helper
  placement must follow the owning kernel, not the donor file layout.
- `docs/_registry/donors.yaml` / `interaction_mutation_boundary`: this donor
  may be adapted only as the single interaction-owned bridge into committed
  writes and must not copy legacy bridge names or access types -> P5 may define
  the EditKernel-facing mutation seam, while interaction-specific behavior
  remains later-phase scope.
- `docs/_registry/donors.yaml` / avoid donors: the forbidden donors exist only
  as behavioral evidence or targeted references and explicitly block copying
  legacy public controller facades, whole interactive runtime callback graphs,
  scene builder API, whole scene codec coupling, or mixed scene store
  controller structure -> P5 must preserve the new architecture shape.
- `docs/contracts/edit_kernel.md` / write sequence: edit calls enter through
  `CanvasEditPort.edit`, open an `EditKernel` session, create a draft, run
  synchronous mutations, compile a plan, atomically apply document and
  selection effects, publish typed post-install effects, close the handle, and
  return the callback result -> this sequence fixes the owner, order, and
  completion boundary.
- `docs/contracts/edit_kernel.md` / rollback sequence and obligations: failed
  edits discard buffered events and repaint requests, close the handle, rethrow
  or reject, and leave committed document identity, revisions, projection,
  spatial, resource, selection, preview, actions, text events, public state,
  and repaint unchanged -> rollback must be tested across committed owners and
  side-effect buffers.
- `docs/contracts/edit_kernel.md` / touched set and taxonomy: `TouchedSet`
  includes element, resource, layer, selection, persisted camera, background,
  grid, palette, and document replacement flags; generic global invalidation is
  forbidden except document replacement; `CommitCompiler` owns the
  field-effect taxonomy and must not depend on concrete `FrameEngine` -> typed
  invalidation belongs in the edit compiler.
- `docs/contracts/edit_kernel.md` / selection and publication: selection
  effects are not draft fields inside committed document state, and accepted
  edits publish exactly one public runtime snapshot while no-op edits publish
  none -> selection install remains selection-owned but atomic with document
  install.
- `docs/contracts/operation_matrix.md` / edit-owned rows: P5 closes adding
  content/background elements, element updates, low-level remove/clear,
  persisted camera edits, metadata edits, resource descriptor edits, and no-op
  edit rows; document replacement remains a P6 consumer of the edit plan shape
  -> P5 tests must assert executable effects for P5-owned rows without
  treating replacement as a public P5 operation.
- `docs/contracts/operation_matrix.md` / publication rules: rows that change a
  public revision publish one coherent `CanvasRuntimeState`, selection-only
  effects do not increment document/projection/spatial state, and no-op
  operations publish no snapshot -> commit application must preserve coherent
  state publication.
- `docs/contracts/public_api_v1.md` / public edit API: `CanvasEditPort` and
  `CanvasEdit` signatures already exist and require synchronous callbacks,
  nested edit rejection, Future rejection, atomic draft mutations, rollback,
  post-install notifications, stale-handle `StateError`, and no user action
  events for low-level remove/clear -> public compatibility forbids signature
  changes.
- `docs/contracts/public_api_v1.md` / edit admission outcomes:
  `CanvasEdit.addElement` with an id collision throws `CanvasDataException`
  `duplicateElementId`, adding an element with a missing resource reference
  throws `CanvasDataException` `missingResourceReference`, and
  `removeUnusedResource` returns `false` when the resource is referenced ->
  Unit 2 must pin public error and boolean formats instead of using generic
  rejection.
- `docs/contracts/public_api_v1.md` / persisted camera: `CanvasEdit.setCameraOffset`
  changes document camera state and projection but never directly mutates the
  runtime view camera -> edit behavior must preserve the P4 camera separation.
- `docs/contracts/resources.md` / resource removal:
  `removeUnusedResource(id)` returns `false` when the id is missing or still
  referenced, removes only unused descriptors, invalidates resource cache state
  only on removal, emits no action event, and increments document/resource
  revision only when removed -> P5 resource scope is descriptor-table mutation
  through edit commit, not resource loading.
- `docs/contracts/operation_matrix.md` / resource row no-op behavior: missing
  or still-referenced resource removal publishes no state and rollback leaves
  descriptor table, document revision, projection, resource cache, repaint, and
  notifications unchanged -> resource no-op/rollback behavior must be tested
  as part of P5 operation matrix effects.
- `docs/implementation/p6_load_document.md` / P6 build scope:
  `CanvasEditPort.loadDocument`, staged document load, and
  `CanvasEdit.replaceDraftDocument` are P6-owned and depend on P5 edit core ->
  P5 must not partially implement load or replacement behavior when wiring the
  edit port.
- `docs/architecture/01_runtime_ownership.md` / owner table:
  `DocumentStoreKernel` owns committed document facts and projection cache,
  `SelectionKernel` owns selected ids and `selectionRevision`, and `EditKernel`
  owns synchronous edit sessions, drafts, touched sets, and cross-owner
  commit/rollback coordination -> P5 must keep responsibilities separated.
- `docs/architecture/03_data_model.md` / public runtime state:
  `RuntimeRoot` publishes one immutable `CanvasRuntimeState` after accepted
  runtime-visible changes reach their owner, selection/document effects can be
  published atomically, persisted camera edits are document edits, and no-op
  edits publish no state -> `RuntimeRoot` remains the public snapshot owner.
- `docs/verification/tests.md` / P5 inventory: required tests include edit
  sync, rollback, field update nullable semantics, operation matrix effects,
  exact touched invalidation, typed effects without frame dependency, runtime
  state publication, and selection runtime owner separation -> those tests are
  the focused proof set for this step.
- `docs/verification/tests.md` / public smoke responsibility:
  `test/smoke/public_incremental_smoke_test.dart` must expand only by appending
  the next real public user step after a future phase exposes one -> P5 must add
  one public edit step there instead of creating a private smoke probe.
- `docs/verification/guardrail_design_patterns.md` / P5 guardrail patterns:
  edit guardrails use behavioral seam tests, semantic sequence checks, effect
  matrix proof, resolved element identity, and runner inventory; in particular
  `edit.operation_matrix_complete` requires runner inclusion -> P5 guardrails
  must be registered and executable through the guardrail runner.
- `docs/implementation/p5_edit_core.md` / supporting guardrails:
  `selection.owner_separate_from_document` and `core.single_runtime_root` remain
  part of the P5 proof set -> P5 must preserve those existing guardrails while
  adding the new edit/event guardrails.
- `tool/guardrails/src/guardrail_registry.dart` / current inventory: the
  blocking guardrail inventory currently includes P0-P4 API, codec,
  diagnostics, core, store, projection, and selection guardrails, but no P5
  edit or low-level edit event guardrails -> P5 must add executable guardrail
  entries and routing for the new guardrail ids.
- `docs/_registry/sections.yaml` / required test registry: the EditKernel
  section binds `test.edit.field_update_nullable_semantics` and related P5
  required tests to generated verification context -> registry-backed test ids
  must remain aligned if any verification inventory changes are needed.
- `docs/architecture/architecture_graph.yaml` / phase and nodes: P5 is
  currently future, `lib/src/edit/**` is an architecture owner, `edit.kernel`
  and `edit.kernel.mutates_store` are required by P5, and
  `CanvasRuntime.edits` is allowed only as a deferred P5 placeholder -> P5
  implementation must close the edit graph obligations instead of leaving the
  placeholder accepted.
- `lib/src/api/canvas_runtime.dart` / public facade: `CanvasRuntime.edits`
  currently throws `UnimplementedError` while the public `CanvasEditPort` and
  `CanvasEdit` declarations already exist -> the facade must be wired to the
  runtime edit owner without changing the public declarations.
- `lib/src/runtime/runtime_root.dart` / composition root: `RuntimeRoot`
  composes store, selection, runtime camera, and public state publication, and
  still rejects selection-owned document mutation as later edit-phase work ->
  P5 must replace that rejection with the shared edit commit boundary.
- `lib/src/store/document_store_kernel.dart` / store owner:
  `DocumentStoreKernel` currently owns committed document facts, revisions,
  projection cache, id admission, frame facts, resource descriptors, and
  selection normalization inputs -> document installs and projection
  invalidation must go through this owner.
- `lib/src/selection/selection_kernel.dart` / selection owner:
  `SelectionKernel` owns selected ids and increments `selectionRevision` only
  when membership changes -> edit-driven selection prune/clear effects must be
  installed by this owner, not stored inside document draft state.
- `docs/diagrams/c4_code_edit_kernel.mmd`,
  `docs/diagrams/c4_component_runtime.mmd`,
  `docs/diagrams/dfd_cache_invalidation.mmd`,
  `docs/diagrams/dfd_public_edit.mmd`, `docs/diagrams/seq_edit_success.mmd`,
  `docs/diagrams/seq_edit_rollback.mmd`, and
  `docs/diagrams/state_edit_session.mmd` / P5 diagrams: the diagrams already
  define the intended session, draft, compiler, plan, applier, rollback, and
  effect-dispatch flow -> implementation should update diagrams only if code
  intentionally changes that selected architecture.

## Boundaries

Owner:

`lib/src/edit/**` owns edit sessions, draft handles, touched collection, commit
plan compilation, typed edit effects, and rollback coordination. `RuntimeRoot`
owns public edit-port composition and public runtime state publication.
`DocumentStoreKernel` owns committed document installation and projection/cache
facts. `SelectionKernel` owns selection effect installation and
`selectionRevision`.

In Scope:

Add the internal edit subsystem selected by the design and wire
`CanvasRuntime.edits` to it through `RuntimeRoot`. Implement synchronous
non-nested edit sessions, callback-result preservation, Future-return
rejection, disposed-runtime rejection, stale-handle rejection, rollback-safe
draft mutation, and no-op edit silence. Implement the existing low-level
`CanvasEdit` mutation surface for document, layer, element, resource,
background, grid, palette, persisted camera, and clear-content operations.
Compile exact `TouchedSet` facts and field-granular
`CanvasEdit.updateElement` effects into immutable `CommitPlan` values. Apply
accepted document and selection effects atomically through store and selection
owners, publish exactly one coherent `CanvasRuntimeState` when a public
revision changes, and publish no state for no-op edits. Emit typed
post-install effects for projection, spatial, resource, repaint, selection, and
public state consumers without importing concrete future owners. Add or
complete the P5 tests and guardrails named by the implementation and
verification documents, including runner inventory/routes for the P5 guardrail
ids. Append one real public edit step to
`test/smoke/public_incremental_smoke_test.dart` using only the public root
barrel. Keep `CanvasEditPort.loadDocument` and
`CanvasEdit.replaceDraftDocument` as explicit P6-owned temporary rejections
that throw `UnsupportedError` before draft mutation, committed-state mutation,
interaction interruption, repaint/effect buffering, or public state
publication. P5 owns resource descriptor table mutations only through the edit
draft/commit path; `ResourceKernel`, visual cache/session invalidation,
resolver behavior, concrete resource loading, and resource dirty operations
remain future-owner scope. Close the P5 architecture graph obligations and
remove or update edit placeholder allowances that are no longer valid.
Allowed donor use is limited to targeted adaptation of `dto_document_helpers`
for pure document edit, clone, resource descriptor, and selection helper
behavior under the owning store/selection/edit kernels, plus the
EditKernel-facing side of `interaction_mutation_boundary` so later interaction
owners can enter the same transaction seam.

Out of Scope:

Do not implement undo/redo, command-owned user action event emission,
interaction tools, pointer routing, text-edit request flows, load-document
staging, `CanvasEditPort.loadDocument` success/failure behavior,
`CanvasEdit.replaceDraftDocument` replacement behavior, frame rendering,
concrete spatial indexing, concrete resource resolution/cache sessions,
Flutter surface behavior, benchmarks, schema v2, or public API signature
changes. Do not make `RuntimeRoot` the direct owner of field taxonomy, draft
mutation semantics, or concrete downstream side effects. Do not emit low-level
`CanvasEdit.removeElement` or `CanvasEdit.clearContent` as user action events.
Do not implement `ResourceKernel`, resource resolver sessions, visual cache
dirtying, concrete resource loading, or resource-owner runtime APIs as part of
the descriptor-table edits in P5.
Do not copy or recreate `avoid_scene_controller_facades`,
`avoid_interactive_runtime_whole`, `avoid_scene_builder_public_architecture`,
`avoid_scene_codec_whole`, or `avoid_scene_store_controller_whole`; do not
preserve legacy donor names, public facade shapes, callback graphs, codec
coupling, builder APIs, or mixed controller/store ownership when adapting
allowed donor behavior.
Do not weaken P5 source contracts, graph obligations, or test inventory to
make implementation easier.

Source of Truth:

`.design/2026-05-24-p5-edit-core.md` is the selected architecture design input.
`docs/implementation/p5_edit_core.md` owns phase scope and exit gates.
`docs/implementation/p6_load_document.md` owns successful load-document and
draft-replacement behavior after P5, so P5 temporary `UnsupportedError`
behavior must not be treated as the final load/replacement contract.
`docs/contracts/edit_kernel.md`, `docs/contracts/operation_matrix.md`,
`docs/contracts/public_api_v1.md`, `docs/contracts/resources.md`,
`docs/architecture/01_runtime_ownership.md`, and
`docs/architecture/03_data_model.md` own edit behavior, effect taxonomy,
public compatibility, resource descriptor removal semantics, owner boundaries,
and public runtime state semantics.
`docs/_registry/donors.yaml` owns required and forbidden donor decisions:
`dto_document_helpers` and `interaction_mutation_boundary` are adapt-only
inputs, while the five `avoid_*` donors are forbidden structure.
`docs/architecture/architecture_graph.yaml` owns P5 graph closure facts.
`docs/verification/tests.md` owns required P5 proof surfaces and public smoke
responsibility. `docs/verification/guardrail_design_patterns.md` owns the
allowed guardrail implementation patterns for the P5 guardrail ids.
`docs/_registry/sections.yaml` owns registry alignment for generated
verification context when test or proof inventory changes.

Compatibility:

Public API signatures, public DTO shapes, public exception/data formats,
schema v1, runtime config schema, and existing P0-P4 behavior must remain
compatible. `CanvasRuntime.edits` may stop throwing only by satisfying the P5
edit-session contract for `edit(fn)`. Until P6, `CanvasEditPort.loadDocument`
must throw `UnsupportedError` with a P6 ownership message and no side effects.
Until P6, `CanvasEdit.replaceDraftDocument` must throw `UnsupportedError` with
a P6 ownership message before changing the draft or committed state. Future
owners must be able to consume typed effects later, but P5 must not require
their concrete implementations.

Order Constraints:

Introduce the edit session and draft boundary before exposing
`CanvasRuntime.edits`. Add store-owned document install/preflight support
before compiling commit plans that depend on it. Add selection effect install
support before enabling operations that prune or clear selected ids. Compile
typed effects before dispatching or publishing them through the runtime/applier
boundary. Prove rollback and no-op silence before closing operation matrix
rows. Retire the edit placeholder and close the P5 architecture graph only
after the public edit facade and required tests are in place. Mark this plan
step complete only after all execution units, focused tests, repository checks,
documentation checks triggered by changed docs, and P5 graph checks pass.

## Execution Units

### [x] Unit 1: Edit session lifecycle and public facade

Owner:

`lib/src/edit/**`, `RuntimeRoot`, and the public `CanvasRuntime.edits` facade.

Boundary:

Edit-port composition, session admission, callback lifetime, stale handle
state, disposed-runtime checks, nested edit rejection, Future-return rejection,
callback result propagation, P6-owned `loadDocument` temporary rejection, and
no-op session silence. No document or selection install behavior beyond the
minimal empty-session path belongs in this unit.

Change:

Create the edit-owned session boundary selected by the design, compose it from
`RuntimeRoot`, and route `CanvasRuntime.edits` to it. The session must reject
disposed runtime edits, reject nested sessions before opening a second draft,
reject callback results that are `Future`, close handles after callback
completion or failure, throw `StateError` for stale-handle operations, preserve
the callback result for successful synchronous edits, and publish no state or
effects for empty/no-op sessions. The returned `CanvasEditPort.loadDocument`
method must remain a P6-owned temporary rejection in P5: it throws
`UnsupportedError` before validation, draft creation, committed-state mutation,
interaction interruption, effect buffering, or public state publication.

Completion Check:

`dart test test/edit/sync_non_nested_async_stale_test.dart` passes and proves
successful synchronous callback result propagation, disposed-runtime rejection,
nested edit rejection, Future-return rejection before commit planning, stale
handle `StateError`, handle closure after exceptions, and no public state
notification for no-op edit sessions. The same file also proves
`CanvasEditPort.loadDocument` throws `UnsupportedError` with a P6 ownership
message and leaves runtime state, committed document, selection, and effect
buffers unchanged. `CanvasRuntime.edits` no longer appears as an unimplemented
public placeholder after this unit, while no public P5 contract claims load
success behavior.

Depends On:

None.

### [x] Unit 2: Store-owned draft mutation and committed document install

Owner:

`DocumentStoreKernel` and edit-owned `DraftDocument` integration.

Boundary:

Rollback-safe document/resource draft data, document admission/preflight,
document install payloads, document revision families, projection cache
invalidation, id admission, public document projection, and document-owned
resource descriptor tables. Selection mutation and public runtime publication
are outside this unit except for exposing the document facts needed by later
units.

Change:

Implement the document/resource mutation substrate needed by the existing
`CanvasEdit` surface: add content/background elements, ensure layers, update
elements with public update DTO validation, remove elements, upsert resources,
remove unused resources, set background/grid/palette/persisted camera, clear
content, and the document-replacement typed effect shape needed by later P6
without enabling public replacement behavior. `CanvasEdit.replaceDraftDocument`
must remain a P6-owned temporary rejection in P5 and must not mutate the draft.
Draft changes must not mutate committed store state until install. Store
preflight must reject id collisions, missing resource references, invalid
generated/dynamic updates, and invalid mutation payloads before committed state
is changed. Public admission outcomes are fixed: duplicate element ids throw
`CanvasDataException` with `CanvasDataErrorCode.duplicateElementId`; missing
resource references throw `CanvasDataException` with
`CanvasDataErrorCode.missingResourceReference`; `CanvasEdit.removeUnusedResource`
returns `false` with no draft, committed, revision, projection,
resource-effect, repaint, action, or public-state changes when the resource is
missing or still referenced by any content/background element, including hidden,
locked, or non-deletable elements. Only unused existing resource descriptors
are removed. Successful document installs must advance only the
document/internal revision families named by the compiled effects and must
invalidate the public projection cache through the store owner.

Completion Check:

`dart test test/edit/rollback_test.dart` passes and proves draft mutation does
not change `readDocument()`, document revisions, projection build count, or
frame/resource facts before a successful install or after rollback.
`dart test test/edit/field_update_nullable_semantics_test.dart` passes and
proves generated and dynamic non-nullable clear requests and non-invertible
transform updates reject before draft mutation.
`dart test test/edit/operation_matrix_effects_test.dart` passes and proves
accepted document edits become visible through `CanvasRuntime.readDocument()`
only after commit; duplicate element ids throw `CanvasDataException` with
`CanvasDataErrorCode.duplicateElementId`; missing resource references throw
`CanvasDataException` with `CanvasDataErrorCode.missingResourceReference`;
missing or still-referenced `removeUnusedResource` returns `false` without
draft, committed, revision, projection, resource-effect, repaint, action, or
public-state changes; unused existing resource descriptors are removed with the
resource/document effects required by the operation matrix; and `CommitPlan`
plus `TouchedSet` expose the reserved document-replacement shape only as future
P6 input, with no executable P5 edit producing a `documentReplaced` plan.
`test/edit/sync_non_nested_async_stale_test.dart` also proves
`CanvasEdit.replaceDraftDocument` throws `UnsupportedError` with a P6 ownership
message and leaves draft-visible and committed state unchanged.

Depends On:

Unit 1.

### [x] Unit 3: Commit compiler, touched set, and typed effect plan

Owner:

`CommitCompiler`, `TouchedSet`, and `CommitPlan` under `lib/src/edit/**`.

Boundary:

Field-effect taxonomy, exact touched invalidation, no-op detection, immutable
commit plans, typed projection/spatial/resource/repaint/public-state/selection
effect descriptions, future-compatible document-replacement effect shape, and
preflight-to-plan conversion. Concrete frame, spatial, resource resolver,
interaction, Flutter surface, and event-stream owners remain outside this unit.

Change:

Compile draft mutations into an immutable `CommitPlan` with exact `TouchedSet`
facts and typed effects. Implement the `CanvasEdit.updateElement` field-effect
taxonomy from `docs/contracts/edit_kernel.md`, including no-op behavior,
internal revision families, projection eviction, resource reference validation,
repaint intent, spatial touch scope, and selection-prune requirements. Forbid
generic global invalidation for executable P5 edit operations; the only
reserved global-invalidation shape is future P6 document replacement. Keep
low-level
remove/clear command-free and produce typed event/effect buffers that rollback
can discard before any downstream publication.

Completion Check:

`dart test test/edit/exact_touched_invalidation_test.dart`,
`dart test test/edit/typed_effects_no_frame_dependency_test.dart`, and
`dart test test/edit/operation_matrix_effects_test.dart` pass. The typed-effect
test proves `CommitCompiler` and `CommitPlan` do not import concrete
`lib/src/frame/**`, `lib/src/spatial/**`, `lib/src/resources/**`,
`lib/src/interaction/**`, `lib/src/surface/**`, or Flutter widget owners. The
exact-invalidation test proves ordinary edits record only the touched ids and
flags required by the taxonomy, and that global invalidation is unavailable to
ordinary P5 edits. Any `documentReplaced` or global-invalidation plan shape is
reserved for the future P6 replacement path.

Depends On:

Unit 2.

### [x] Unit 4: Atomic commit applier and runtime publication

Owner:

`CommitApplier`, `RuntimeRoot`, `DocumentStoreKernel`, and `SelectionKernel`
at the runtime/applier boundary.

Boundary:

Atomic installation of preflighted document and selection effects, runtime
state snapshot publication, rollback discard behavior, public revision
coherence, and low-level no-action-event behavior. Command-owned user action
events, interaction text events, concrete repaint buses, concrete spatial
indexes, and concrete resource visual caches remain outside this unit.

Change:

Apply preflighted commit plans so document and selection effects become visible
only at the atomic install boundary. Selection prune/clear effects must be
installed through `SelectionKernel` and published with document effects as one
coherent `CanvasRuntimeState`. Rollback, validation failure, callback
exception, and Future-return rejection must leave committed document identity,
all revisions, projection cache, selection owner, resource facts, preview,
action streams, text events, public state notifications, and repaint/effect
buffers unchanged. Accepted low-level remove/clear operations must emit no user
action event. Persisted camera edits must advance document/projection state
without mutating the runtime view camera.

Completion Check:

`dart test test/edit/rollback_test.dart`,
`dart test test/edit/low_level_mutations_do_not_emit_actions_test.dart`,
`dart test test/runtime/runtime_state_publication_test.dart`, and
`dart test test/selection/runtime_owner_separation_test.dart` pass. Rollback
tests prove no committed owner or side-effect buffer changes before atomic
install. Runtime publication tests prove ordinary document edits publish one
state snapshot, no-op edits publish none, and persisted camera edits do not
change `state.revisions.viewCamera`. Selection tests prove document removal,
clear, and taxonomy-required pruning publish document and selection revisions
atomically.

Depends On:

Units 1, 2, and 3.

### [x] Unit 5: P5 architecture closure and repository verification

Owner:

Architecture graph source, generated architecture views when required, P5 test
inventory, and repository verification commands.

Boundary:

P5 graph status and obligations, edit placeholder retirement, P5 guardrail
runner inventory/routes, generated graph outputs caused by source changes,
public smoke expansion, documentation checks for changed docs, focused
edit/runtime/selection tests, analysis, DCM analysis, and metrics. No
production behavior beyond fixes required by Units 1-4 belongs in this unit.

Change:

Close P5 graph obligations after the edit facade, edit owner, mutation
boundary, tests, guardrails, public smoke step, and typed effect seams exist.
Remove or update any P5-specific placeholder allowance for
`CanvasRuntime.edits` once the public facade is implemented. Add the P5
guardrail ids to `tool/guardrails/src/guardrail_registry.dart`, add their
routes/proof integration through the guardrail executor, and update guardrail
suite tests so runner selection proves the new ids are executable.

Each P5 guardrail must use the existing pattern selected for that id in
`docs/verification/guardrail_design_patterns.md`; do not create a new
guardrail style or one-off checker shape for P5. The required guardrail cases
are:

- `edit.sync_non_nested`: use `behavioral_seam_test` plus
  `semantic_sequence`. It must protect against a nested `edit(fn)` opening a
  second session while a callback is active, against Future-returning callbacks
  reaching commit planning, and against either rejection changing draft,
  committed state, public state, or effect buffers.
- `edit.rollback_no_effects`: use `behavioral_seam_test` plus
  `effect_matrix`. It must protect rollback for callback throw, Future
  rejection, validation failure, and preflight failure, proving committed
  document identity, all revisions, projection cache, resource descriptors,
  selection owner, public state notifications, action/text events, repaint, and
  typed effect buffers are unchanged.
- `edit.stale_handle_rejected`: use `behavioral_seam_test` plus
  `semantic_sequence`. It must protect every public `CanvasEdit` handle entry
  point, including reads, summary access, mutation methods, and
  `replaceDraftDocument`, so stale handles throw `StateError` before draft
  mutation, preflight, commit planning, or effect buffering.
- `edit.operation_matrix_complete`: use `effect_matrix`,
  `registry_parity`, and `runner_inventory`. It must protect every P5-owned
  operation matrix row across state touched, public revisions, internal
  revisions, spatial scope, projection effects, resource effects, repaint,
  user-action events, no-op behavior, and rollback behavior. The matrix must
  include add content/background element, ensureLayer, updateElement field
  taxonomy, removeElement, clearContent, persisted camera, background, grid,
  palette, resource descriptor upsert/remove, and no-op edit rows; it must
  exclude P6 load/replacement success rows from P5 closure.
- `edit.no_global_invalidation_except_replacement`: use `effect_matrix` plus
  `behavioral_seam_test`. It must protect ordinary executable P5 edits from
  producing document-wide/global invalidation and reserve any
  `documentReplaced` or global-invalidation plan shape for the future P6
  replacement path.
- `edit.typed_effects_no_frame_dependency`: use
  `resolved_element_identity` plus `effect_matrix`. Its structural proof must
  parse or resolve the relevant edit-owned declarations and block
  `CommitCompiler`, `CommitPlan`, `TouchedSet`, typed edit effects, and their
  private helpers from importing or referencing concrete downstream owners,
  including `FrameEngine`, `SpatialKernel`, `ResourceKernel`,
  `SurfaceResourceSession`, interaction/tool engines, Flutter widgets, and
  concrete surface/resource/session implementations. The effect-matrix proof
  must still show the compiler emits typed descriptions that future owners can
  consume after atomic install.
- `events.low_level_edit_no_user_actions`: use `behavioral_seam_test` plus
  `effect_matrix`. It must protect all low-level `CanvasEdit` operations from
  emitting `CanvasActionCommitted`; at minimum removeElement and clearContent
  must be covered as explicit public compatibility cases.

Append one public edit step to `test/smoke/public_incremental_smoke_test.dart`
through `package:iwb_canvas_engine/iwb_canvas_engine.dart`; the smoke must
remain a coarse public consumer path and must not import `src/**` or assert
private runtime internals. Update generated architecture graph outputs only
through the repository tooling if graph source changes require regeneration.
If P5 test or guardrail inventories change, update the registry-owned source
and generated documentation rather than hand-editing generated context.

Completion Check:

From the repository root, the implementation handoff reports all of these
commands passing after Units 1-4 are complete:
`dart test test/edit/sync_non_nested_async_stale_test.dart
test/edit/rollback_test.dart test/edit/field_update_nullable_semantics_test.dart
test/edit/operation_matrix_effects_test.dart
test/edit/exact_touched_invalidation_test.dart
test/edit/typed_effects_no_frame_dependency_test.dart
test/edit/low_level_mutations_do_not_emit_actions_test.dart
test/runtime/runtime_state_publication_test.dart
test/selection/runtime_owner_separation_test.dart
test/smoke/public_incremental_smoke_test.dart
test/guardrails/blocking_suite_test.dart`,
`dart run tool/guardrails/run.dart`,
`dart analyze`, `dcm analyze .`, `dcm calculate-metrics .`,
`dart run tool/architecture_graph/check.dart --phase P5`, and
`dart run tool/architecture_graph/generate_views.dart --phase P4 --check`.
`tool/guardrails/src/guardrail_registry.dart` contains executable entries for
`edit.sync_non_nested`, `edit.rollback_no_effects`,
`edit.stale_handle_rejected`, `edit.operation_matrix_complete`,
`edit.no_global_invalidation_except_replacement`,
`edit.typed_effects_no_frame_dependency`, and
`events.low_level_edit_no_user_actions`; runner/suite tests prove those ids are
selected by the blocking runner and routed to executable proof. Existing
supporting guardrails `core.single_runtime_root` and
`selection.owner_separate_from_document` remain in the blocking runner and pass
alongside the new P5 edit/event guardrails. The guardrail
implementation uses only the existing pattern set named above, and the
guardrail tests include positive proof for the required cases plus negative
fixtures or structural scan assertions for the `resolved_element_identity`
typed-effect dependency guard. The public smoke test contains one appended edit
flow through the root public barrel and contains no `src/`, `RuntimeRoot`,
store, selection, edit-kernel, projection cache, frame, spatial, resource, or
private effect assertions.
If any docs under `docs/` or documentation generation sources changed,
`dart run docs/tool/sync_generated_docs.dart --check` and
`dart run docs/tool/check_docs.dart` also pass. Any intentional DCM metrics
suppression is local, uses exact metric names, and has a nearby plain-language
reason.

Depends On:

Units 1, 2, 3, and 4.
