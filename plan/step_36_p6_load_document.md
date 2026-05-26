# Change Contract

## Goal

Implement P6 full document loading so a valid external replacement document is
prepared before side effects, installed as one committed runtime change, and
published once, while invalid load input leaves the current document, selection,
camera, preview, gesture state, repaint, actions, and public notifications
unchanged. The same step makes `CanvasEdit.replaceDraftDocument` executable as
a rollback-safe edit-session mutation without using external load behavior as
its proof.

## Evidence

- `.design/2026-05-26-p6-load-document.md` / selected design: disposition is
  `READY_FOR_CONTRACT` and the selected form is a P6 `LoadDocumentPipeline`
  with `RuntimeRoot` orchestration -> this step must implement that form rather
  than a normal edit-session shortcut, store-owned replacement, or
  interaction-owned replacement.
- `.design/2026-05-26-p6-load-document.md` / lock-required facts: preparation
  validates and materializes before interaction interruption, success then
  performs one atomic install/publication, and preparation failure performs no
  runtime or interaction side effects -> execution units must preserve that
  temporal boundary explicitly.
- `docs/contracts/load_document.md` / staged load contract: public
  `CanvasEditPort.loadDocument(document)` delegates orchestration to
  `RuntimeRoot`; the public API must not read from or install into
  `DocumentStoreKernel` directly -> public entrypoints stay thin and the runtime
  owner coordinates cross-owner replacement.
- `docs/contracts/load_document.md` / success and failure ordering: success
  validates, materializes `PreparedDocumentLoad`, interrupts interaction only
  after preparation, clears preview, atomically installs replacement document
  plus selection clear, initializes runtime view camera, increments revisions,
  invalidates caches/repaint, and publishes one `CanvasRuntimeState`; failure
  rethrows and publishes no state -> tests must prove both sides.
- `docs/contracts/load_document.md` / draft replacement: `CanvasEdit.replaceDraftDocument`
  is only valid inside an edit callback, has no external gesture interruption,
  is rollback-safe, and is not proved by external load tests -> draft
  replacement needs its own edit-session proof.
- `docs/contracts/operation_matrix.md` / P6 rows: P6 closes the `loadDocument`
  success/failure rows and the `CanvasEdit.replaceDraftDocument` behavior row
  -> operation-matrix tests must become executable for these rows.
- `docs/architecture/architecture_graph.yaml` / P6 graph node and edge: the
  future graph expects `LoadDocumentPipeline` and a
  `load_document.pipeline.replaces_store_document` mutation boundary into
  `DocumentStoreKernel` -> implementation must add the declaration and close
  graph status for P6 instead of hiding replacement in an existing owner.
- `docs/architecture/02_package_boundaries.md` / package layout: the target
  internal edit package reserves `staged_document_load.dart` beside the edit
  kernel -> the P6 pipeline and `PreparedDocumentLoad` should live in a focused
  staged-load implementation file unless implementation updates the package
  source of truth in the same unit.
- `lib/src/api/canvas_runtime.dart` / public API: `CanvasEditPort` already
  declares `loadDocument`, and `CanvasEdit` already declares
  `replaceDraftDocument` -> this step changes behavior without changing public
  method signatures.
- `lib/src/edit/edit_kernel.dart` and `lib/src/edit/edit_session.dart` /
  current placeholders: both public replacement methods currently throw P6
  `UnsupportedError`s after stale/disposed checks -> this step removes those
  placeholders while preserving stale, disposed, nested, and synchronous edit
  guards.
- `lib/src/codec/validated_import_draft.dart` / import validation: validated
  draft materialization already validates duplicate resource/layer/element ids
  and missing image resources with optional diagnostics -> P6 preparation should
  reuse or extend this validation path rather than add a parallel source of
  truth.
- `lib/src/runtime/runtime_root.dart` / runtime ownership: `RuntimeRoot`
  composes `DocumentStoreKernel`, `SelectionKernel`, `CommitApplier`, and
  `EditKernel`, owns runtime view camera and publication, and currently reports
  hard-coded preview and epoch revisions -> P6 must extend runtime-owned load
  revision/publication coordination without moving those facts into the store.
- `test/runtime/fixtures/commit_effect_observer_fixture.dart` / synchronous
  callback proof: state listeners and post-publication effect observers already
  run inside a public mutation guard that includes `loadDocument` -> P6 must keep
  this guard active through the load publication and observer windows.
- `docs/verification/tests.md` and `docs/verification/guardrails.md` / required
  P6 proofs: the repository names
  `test/edit/staged_document_load_success_failure_test.dart`,
  `test/runtime/load_document_state_publication_test.dart`,
  `load.prepares_before_interrupt`, and
  `load.success_interrupts_before_install` -> this step must add or activate
  these focused proofs.

## Boundaries

Owner:

`LoadDocumentPipeline` owns P6 preparation, `PreparedDocumentLoad`, and the
graph-backed store replacement boundary under `RuntimeRoot` orchestration.
`RuntimeRoot` owns external load ordering, view camera, epoch/revision
publication, delivery guards, and coordination across store, selection,
interaction cleanup, cache/effect, and repaint facts. `EditKernel` and
`EditSession` own edit-session draft replacement and rollback.

In Scope:

- Add the focused staged-load implementation surface for `LoadDocumentPipeline`
  and `PreparedDocumentLoad`, using `ValidatedImportDraft` and existing DTO
  validation/diagnostics paths for preparation.
- Make `CanvasEditPort.loadDocument(CanvasDocument)` executable through
  runtime-orchestrated staged load success/failure behavior with one public
  post-install state publication on success and no side effects on preparation
  failure.
- Add the minimal P6 interaction cleanup boundary required by the load contract:
  success-only interruption/preview cleanup before install and post-install
  pointer-normalization/pending-tap cleanup, with no store mutation in the
  interaction boundary.
- Add runtime-owned epoch, preview, and view-camera revision handling needed for
  the load success row while keeping preview and full interaction engines
  otherwise deferred.
- Make `CanvasEdit.replaceDraftDocument(CanvasDocument)` a rollback-safe
  edit-session mutation that shares preparation validation/materialization but
  does not interrupt external interaction or clear preview. Successful draft
  replacement is still a full document replacement and must increment
  `state.revisions.epoch`; rollback and failed preparation must leave epoch
  unchanged.
- Emit load and replacement effect/revision facts needed by operation-matrix
  tests, public runtime-state tests, cache/repaint invalidation proofs, and
  future resource/frame owners.
- Add focused tests and guardrails for load success/failure ordering,
  successful-load publication, failure no-side-effects, draft replacement
  rollback, operation-matrix rows, diagnostics routing, and reentrant public
  mutation rejection during load publication/observer callbacks.
- Update architecture graph status, generated architecture views, and durable
  docs only where needed to reflect that P6 load-document ownership has moved
  from future to implemented.
- Mark Step 36 complete in `PLAN.md` and mark this file's execution-unit
  checkboxes complete only after implementation verification passes.

Out of Scope:

- Implementing full P10-P12 interaction pointer-session state machines, pointer
  tools, terminal resolver paths, or committed interaction feature behavior
  beyond the minimal cleanup boundary required by P6.
- Implementing P7 resource resolver, P8/P9 spatial/frame renderer caches, or
  surface-session resource lifecycle beyond typed invalidation/effect facts
  required by the P6 operation rows.
- Changing public method names, signatures, DTO schema shape, schema version,
  `CanvasRuntimeConfig` public fields, or public diagnostics payloads.
- Moving committed document ownership, selection ownership, runtime camera,
  epoch, preview state, or diagnostics records into a second durable source of
  truth.
- Replacing external `loadDocument` with a normal edit session or making
  `replaceDraftDocument` responsible for external gesture interruption.
- Porting legacy scene-controller facades, scene builder public architecture,
  scene codec wholesale behavior, or broad scene store controller structure.

Source of Truth:

- The selected architecture form and lock-required facts come from
  `.design/2026-05-26-p6-load-document.md`.
- Staged load behavior is defined by `docs/contracts/load_document.md`.
- Draft replacement and rollback behavior are defined by
  `docs/contracts/edit_kernel.md` and the P6 rows in
  `docs/contracts/operation_matrix.md`.
- Runtime view-camera and revision ownership remain defined by
  `docs/architecture/03_data_model.md`.
- Graph closure remains defined by `docs/architecture/architecture_graph.yaml`
  and generated graph views.
- Roadmap closure state remains owned by `PLAN.md` and this linked step file.

Compatibility:

Public API signatures and schema v1 compatibility must remain unchanged. Invalid
load input must keep throwing `CanvasDataException` or `StateError` with the same
boundary semantics as the existing validation path, while diagnostics recording
remains internal and observational. Existing disposed, stale handle, nested edit,
async edit, and post-commit/publication mutation guards must remain enforced.

Order Constraints:

Implement and prove preparation before enabling side effects. External
`loadDocument` success must follow this order: validate/materialize, success-only
interaction interruption and preview cleanup, atomic store replacement plus
selection-owner clear, runtime view-camera/epoch/revision updates, post-install
pointer cleanup, invalidation/repaint effects, then one public state
publication with delivery guards active through state listeners and observers.
On preparation failure, none of those side effects may run. Draft replacement
must use the shared preparation path but remain inside the edit transaction,
carry a full-document-replacement fact through the `CommitPlan`/`CommitApplyResult`
seam to `RuntimeRoot`, increment epoch only for accepted replacement commits,
and be proved separately from external load.

## Execution Units

### [x] Unit 1: Prepared Load Pipeline And Consume Boundary

Owner:

`lib/src/edit/staged_document_load.dart` as the focused staged-load owner,
with `LoadDocumentPipeline` composing `DocumentStoreKernel` and
`docs/architecture/architecture_graph.yaml` tracking the declaration and store
replacement mutation boundary.

Boundary:

Only the P6 pipeline-owned staged-load seam: `LoadDocumentPipeline`,
`PreparedDocumentLoad`, reuse or extension of `ValidatedImportDraft`, optional
internal diagnostics threading, `DocumentStoreKernel` composition, and the
one-shot consume/store-replacement boundary for a prepared load.

Change:

Create the P6 pipeline that validates public `CanvasDocument` input before any
runtime or interaction side effect, materializes an immutable
`PreparedDocumentLoad` containing replacement committed document/id-admission
facts and revision inputs, and routes validation failures through the existing
diagnostics helpers when runtime diagnostics are enabled. Disabled diagnostics
must pass no effective recording surface, allocate and record nothing, and
failure semantics must stay `CanvasDataException` or `StateError`. The same
pipeline owns consuming a `PreparedDocumentLoad` exactly once through its
`DocumentStoreKernel` composition field to install the replacement committed
document; `RuntimeRoot` orchestrates when consume is called but does not replace
the store directly.

Completion Check:

Focused codec/load-preparation tests prove successful preparation, duplicate
ids, missing image resources, invalid metadata or DTO ownership, non-invertible
element transforms, enabled diagnostics recording, disabled diagnostics
no-effective-recording-surface/no-allocation/no-record behavior, one-shot
prepared-load consumption through the pipeline store boundary, and no
mutation/publication/interaction calls during failed preparation.
`dart test test/codec/validated_import_draft_test.dart test/edit/staged_document_load_success_failure_test.dart`
passes, with the P6 preparation/no-side-effect and diagnostics-routing proof
owned by `test/edit/staged_document_load_success_failure_test.dart`.

Depends On:

None.

### [x] Unit 2: Runtime External Load Commit

Owner:

`lib/src/runtime/runtime_root.dart`, with `lib/src/edit/edit_kernel.dart` as the
public edit-port handoff and `lib/src/edit/staged_document_load.dart` owning the
pipeline consume/store-replacement call that `RuntimeRoot` orchestrates.

Boundary:

Only external `CanvasEditPort.loadDocument` orchestration, the runtime-owned
load commit path around the pipeline consume call, and minimal load-specific
interaction cleanup adapter needed by the P6 contract. `RuntimeRoot` may call
`LoadDocumentPipeline.consume(preparedLoad)` but must not bypass the pipeline to
install the replacement document directly into `DocumentStoreKernel`.

Change:

Replace the external `loadDocument` placeholder with runtime-orchestrated staged
load behavior. The runtime prepares first, interrupts/cleans preview only after
preparation succeeds, calls the pipeline-owned one-shot consume/store-replacement
boundary, clears selection through the selection owner in the same atomic
result, initializes runtime view camera from the loaded document's persisted
camera, increments document/selection/view-camera/epoch and conditional preview
revisions, clears post-install pointer normalization and pending tap facts
through the interaction boundary, emits invalidation/repaint effects, and
publishes exactly one public state snapshot after install.

Completion Check:

`dart test test/runtime/load_document_state_publication_test.dart` passes and
proves successful load publishes exactly one post-install state containing the
replacement document summary, cleared selection, initialized view camera,
incremented epoch/revisions, and conditional preview cleanup; failed load
publishes no state and leaves committed document, selection, view camera,
preview, active gesture state, pending line, pointer normalization, repaint,
actions, and observers
unchanged.

Depends On:

Unit 1.

### [x] Unit 3: Draft Replacement In Edit Sessions

Owner:

`lib/src/edit/edit_session.dart`, `lib/src/edit/draft_document.dart`, and
`lib/src/edit/commit_compiler.dart`/`commit_plan.dart` as needed for the edit
transaction effect shape, with `RuntimeRoot` consuming the accepted
`CommitApplyResult` replacement fact for epoch publication.

Boundary:

Only `CanvasEdit.replaceDraftDocument(CanvasDocument)` inside an active edit
callback and its commit/rollback effects.

Change:

Replace the edit-session `replaceDraftDocument` placeholder with a draft-only
replacement mutation that uses the shared preparation/materialization path,
marks whole-document replacement effects, clears selection through the existing
selection-owner effect when the committed selection is invalid for the
replacement document, carries a full-document-replacement fact through the
`CommitPlan`/`CommitApplyResult` seam, increments `state.revisions.epoch` only
after an accepted replacement commit reaches `RuntimeRoot`, and remains
rollback-safe when the edit callback throws, returns an async value, or
otherwise fails. Rollback, failed preparation, stale-handle rejection, and async
edit rejection must leave epoch unchanged. It must not interrupt external
interaction, clear preview, publish external-load state, or emit user actions.

Completion Check:

`dart test test/edit/staged_document_load_success_failure_test.dart test/edit/rollback_test.dart test/edit/edit_matrix_effects_test.dart`
passes with cases proving successful draft replacement commits the replacement
document and effects, increments epoch, failed preparation rolls back without
committed changes or epoch changes, callback failure rolls back the replacement
and epoch change, stale handles reject, async edits reject, `edit_matrix_effects_test.dart`
covers the replacement row's epoch effect, and external load tests are not the
only proof for
`replaceDraftDocument`.

Depends On:

Unit 1.

### [x] Unit 4: Ordering, Guards, And Operation Proofs

Owner:

Focused tests and guardrails under `test/runtime`, `test/edit`,
`test/guardrails`, `tool/guardrails/src/guardrail_registry.dart`,
`tool/guardrails/src/guardrail_executor.dart`, and the operation-matrix proof
surfaces.

Boundary:

Only executable proof for P6 temporal ordering, public mutation guards, and
operation-matrix rows.

Change:

Add or update behavioral tests/guardrails for `load.prepares_before_interrupt`,
`load.success_interrupts_before_install`, operation-matrix completion for
`loadDocument` success/failure and `replaceDraftDocument`, and reentrant public
mutation rejection during load state listener and post-publication observer
callbacks. Register both P6 load guardrail ids in the guardrail inventory,
route them through the guardrail executor to executable proof targets, and keep
the blocking suite aware of them. The proof must name the synchronous callback
surfaces and show the allowed public observation order: installed committed
state, one state listener snapshot, post-publication effects/observer work,
then return to the caller.

Completion Check:

`dart test test/runtime/runtime_state_publication_test.dart test/edit/edit_matrix_effects_test.dart test/guardrails/blocking_suite_test.dart`
passes; `dart run tool/guardrails/run.dart --guardrail=load.prepares_before_interrupt`
and `dart run tool/guardrails/run.dart --guardrail=load.success_interrupts_before_install`
both pass; and the new P6 ordering tests fail if interaction cleanup happens
before successful preparation, if install happens before success-only
interaction interruption, or if a second load, edit, selection mutation, camera
mutation, id generation, dispose, or another publication can reenter during
load publication/observer delivery. Any load-specific observer fixture must be
run through an executable wrapper test, not directly as a `dart test` target.

Depends On:

Units 2 and 3.

### [x] Unit 5: Architecture And Documentation Closure

Owner:

`docs/architecture/architecture_graph.yaml`, generated graph views, and any
durable docs whose P6 status or implemented seam changes.

Boundary:

Only source-of-truth updates required by the implemented P6 ownership, graph
closure, operation rows, diagrams, and verification inventory.

Change:

Move the `load_document.pipeline` node and its store mutation boundary from
future to implemented status, update generated graph views, and update durable
docs/tests/guardrail inventories only where the implementation changes their
meaning. Check the P6 diagrams named by `docs/implementation/p6_load_document.md`
and update them only if implementation changes their success/failure ordering,
data flow, or lifecycle meaning. Do not rewrite P6 design history or create
prose-only enforcement when tests or graph checks can enforce the constraint.

Completion Check:

`dart run tool/architecture_graph/check.dart --phase P6`,
`dart run tool/architecture_graph/generate_views.dart --phase P6 --check`,
`dart run docs/tool/sync_generated_docs.dart --check`, and
`dart run docs/tool/check_docs.dart` pass, or the implementer updates generated
docs first and then reruns these checks successfully.

Depends On:

Units 1, 2, 3, and 4.

### [x] Unit 6: Close Roadmap Step State

Owner:

`PLAN.md` and `plan/step_36_p6_load_document.md`.

Boundary:

Only roadmap completion state for Step 36.

Change:

After Units 1-5 are implemented and all step verification commands pass, mark
Step 36 as complete in `PLAN.md` and mark each execution-unit checkbox in this
step file complete.

Completion Check:

`PLAN.md` lists Step 36 with `[x]`, this file marks Units 1-6 with `[x]`, and
the implementer's final report names the successful verification commands from
`Step Verification`.

Depends On:

Units 1, 2, 3, 4, and 5.

## Step Verification

Run from the repository root after implementation:

```bash
dart analyze
dcm analyze .
dcm calculate-metrics .
dart test test/codec/validated_import_draft_test.dart test/runtime/load_document_state_publication_test.dart test/runtime/runtime_state_publication_test.dart test/edit/staged_document_load_success_failure_test.dart test/edit/rollback_test.dart test/edit/edit_matrix_effects_test.dart test/selection/runtime_owner_separation_test.dart test/guardrails/blocking_suite_test.dart
dart run tool/guardrails/run.dart --guardrail=load.prepares_before_interrupt
dart run tool/guardrails/run.dart --guardrail=load.success_interrupts_before_install
dart run tool/architecture_graph/check.dart --phase P6
dart run tool/architecture_graph/generate_views.dart --phase P6 --check
dart run docs/tool/sync_generated_docs.dart --check
dart run docs/tool/check_docs.dart
```

If implementation touches additional focused behavior, add the smallest
relevant focused tests to this verification list before marking Unit 6 complete.
