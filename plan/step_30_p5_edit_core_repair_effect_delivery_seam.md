# Change Contract

## Goal

Repair the completed P5 edit core so accepted edits deliver typed
post-install effects across the `CommitApplier -> RuntimeRoot` boundary after
atomic document and selection installation, while failed, no-op, stale, nested,
Future-return, validation-failure, and P6-owned replacement paths deliver no
effects. Keep public API signatures unchanged and preserve `CanvasEdit.replaceDraftDocument`
as rejection-only until P6.

## Evidence

- `.design/2026-05-24-p5-edit-core.md` / repair question: the design exists to
  repair under-specified effect delivery, replacement ownership,
  verification, and seam obligations -> this step is a repair, not a second
  full P5 implementation.
- `.design/2026-05-24-p5-edit-core.md` / product outcome and non-goals: P5
  defines the atomic edit and effect-delivery boundary, but does not implement
  load-document staging, executable draft replacement, frame rendering,
  resources, spatial indexes, or Flutter surface behavior -> the repair must
  expose typed effects without adding concrete downstream owners.
- `.design/2026-05-24-p5-edit-core.md` / target classification: the required
  obligations are BUG_FIX and SEAM_MIGRATION -> the repair must fix the
  incomplete handoff and make the seam consumable by later owners.
- `.design/2026-05-24-p5-edit-core.md` / selected form: `CommitApplier`
  installs document and selection effects and returns one immutable apply
  result to `RuntimeRoot` containing the public-state publication decision and
  typed post-install effects -> a `bool` publish result is not a complete P5
  boundary.
- `.design/2026-05-24-p5-edit-core.md` / source-of-truth impact:
  `docs/contracts/edit_kernel.md` must clarify the `CommitApplier -> RuntimeRoot`
  apply-result delivery seam, and `docs/contracts/operation_matrix.md` must
  clarify that P5 owns only the reserved `documentReplaced` invalidation/effect
  shape while P6 owns executable replacement -> implementation must repair both
  behavior and durable contract wording if the current docs remain ambiguous.
- `.design/2026-05-24-p5-edit-core.md` / verification impact:
  `CommitPlan.effects` alone is not sufficient proof; successful commits must
  expose typed effects through the apply result after atomic install, while
  no-op, rollback, validation failure, stale, nested, and Future-return paths
  expose none -> tests must observe effects beyond the plan/compiler boundary.
- `plan/step_29_p5_edit_core_rollback_safe_commits.md` / completed units:
  Step 29 already implemented the broad P5 edit-session, draft, compiler,
  applier, publication, guardrail, and graph closure work -> this repair must
  stay scoped to the missing effect-delivery seam and replacement split proof.
- `lib/src/edit/commit_applier.dart` / current apply boundary:
  `CommitApplier.apply` returns only `bool` and discards `CommitPlan.effects`
  after installation -> typed effects currently stop at the plan/applier
  boundary.
- `lib/src/runtime/runtime_root.dart` / current runtime consumer:
  `_applyEditCommit` consumes only the applier's `bool` publish decision and
  publishes state from store and selection facts -> `RuntimeRoot` cannot
  observe or dispatch the typed post-install effects selected by the design.
- `lib/src/edit/commit_plan.dart` / current typed effect model:
  `CommitPlan` already carries immutable `CommitEffect` values for projection,
  spatial, resource, repaint, selection, and public state -> the repair should
  reuse this effect model instead of introducing a duplicate effect taxonomy.
- `lib/src/edit/edit_session.dart` / current replacement behavior:
  `CanvasEdit.replaceDraftDocument` throws `UnsupportedError` with P6 ownership
  wording before replacing the draft -> the repair must preserve rejection-only
  behavior.
- `test/edit/fixtures/typed_effects_no_frame_dependency_fixture.dart` /
  current proof: the typed-effect test asserts effects on `CommitPlan` built
  from `DraftDocument` -> it does not prove effects leave the edit owner after
  atomic install.
- `test/edit/fixtures/edit_matrix_effects_fixture.dart` / current proof:
  operation-matrix checks assert `CommitPlan` effect contents and
  `documentReplaced` is false for P5 rows -> they do not by themselves prove
  runtime/applier delivery after install.
- `docs/contracts/edit_kernel.md` / write sequence: the durable contract says
  typed post-install effects are published through the runtime/applier
  boundary -> code and tests must match that wording.
- `docs/contracts/operation_matrix.md` / phase ownership and replacement row:
  P5 closes edit-owned rows and generic executable effect shape, while P6
  closes load-document rows; the table also describes
  `CanvasEdit.replaceDraftDocument` replacement effects -> the repair must
  make the P5/P6 split unambiguous in implementation proof.
- `docs/implementation/p6_load_document.md` / P6 scope:
  `CanvasEditPort.loadDocument`, staged load, and executable
  `CanvasEdit.replaceDraftDocument` belong to P6 and depend on P5 edit core ->
  this repair must not implement load or replacement success behavior.

## Boundaries

Owner:

`CommitApplier` owns the immutable post-install apply result. `EditKernel`
owns closing and staling the active edit handle before any post-install
runtime publication or effect observation occurs. `RuntimeRoot` owns consuming
the post-close apply result, publishing public runtime state, and invoking an
internal `CommitEffectObserver` callback seam for future owners. The observer
is a synchronous `lib/src/runtime/commit_effect_observer.dart`-owned callback
type with this exact signature:
`typedef CommitEffectObserver = void Function(List<CommitEffect> effects);`.
The observer receives a non-null immutable post-install `List<CommitEffect>`
after atomic install and after edit-session closure. Empty lists are not
delivered; no-op commits skip observer invocation. Async/Future-returning
observer delivery is out of scope for this repair: `RuntimeRoot` must not
`await`, schedule, or store observer futures. The observer defaults to no-op
in normal runtime construction and is injected through an optional named
`CommitEffectObserver? commitEffectObserver` parameter on the existing
`RuntimeRoot` constructor. The private `RuntimeRoot._` constructor receives a
required non-null observer after defaulting. `RuntimeRoot` also owns a
post-commit delivery guard that rejects public runtime mutations while the
observer is running. `CommitPlan` remains the typed effect source. Existing
store and selection owners keep their Step 29 responsibilities.

In Scope:

Replace the `bool`-only `CommitApplier.apply` result with an immutable
apply-result value that contains at least the public-state publication decision
and the typed post-install effects that were delivered after atomic install.
Change the edit/runtime handoff so the install callback returns that
`CommitApplyResult` to `EditKernel`; `EditKernel` then closes and stales the
active `EditSession`, clears its active-session flag, and only after that asks
`RuntimeRoot` to publish the accepted apply result. `RuntimeRoot` must publish
public state from the result before invoking the observer, matching the design
sequence: apply result -> close/stale handle -> publish state -> observe typed
effects -> return the callback result. Add the runtime-local
`CommitEffectObserver` callback as the concrete internal seam: the typedef
lives in `lib/src/runtime/commit_effect_observer.dart` with exact signature
`void Function(List<CommitEffect> effects)`, the existing `RuntimeRoot`
constructor accepts optional named `commitEffectObserver`, production
construction omits it and gets a no-op observer, and focused tests instantiate
`RuntimeRoot` directly with a recording observer. Observer
failures are non-transactional post-commit notification failures: they are
caught by `RuntimeRoot`, never roll back or mutate committed document,
selection, revision, projection, or public state, never rethrow from
`CanvasEditPort.edit`, and never replace the callback result. Diagnostics for
observer failures are out of scope until a diagnostics-owned runtime reporting
seam is explicitly added. Preserve no-op behavior as no install, no state
publication, and no observer invocation. While the observer is running,
`RuntimeRoot` must reject public runtime mutations and reentrant edits with
`StateError` before draft creation, committed-state mutation, state
publication, or effect delivery. Preserve rollback, callback exception,
Future-return, nested edit, stale handle, validation failure, and P6-owned
load/replacement rejection behavior as no committed state mutation and no
observer invocation. Async observer delivery, awaiting observer work, and
async observer failure reporting are out of scope. Reuse the existing
`CommitEffect` taxonomy from
`CommitPlan`; do not create a parallel effect hierarchy. Update focused tests
so at least one successful edit through `RuntimeRoot.edits.edit` proves
effects leave `CommitApplier` and reach `RuntimeRoot` after store/selection
install and after handle closure, and negative paths prove no effects reach
the runtime/applier boundary. Clarify durable docs for the apply-result seam,
post-close delivery order, observer failure policy, observer reentrancy guard,
and P5/P6 replacement split before code changes.

Out of Scope:

Do not reimplement the Step 29 edit subsystem. Do not change public API
signatures, schema v1, public DTO shapes, public exception formats, or runtime
config. Do not implement `CanvasEditPort.loadDocument` success or failure
staging. Do not implement executable `CanvasEdit.replaceDraftDocument`. Do not
add concrete frame, spatial, resource resolver/cache, interaction, Flutter
surface, repaint bus, undo/redo, or command action event consumers. Do not
rename the edit effect taxonomy or move field-effect ownership out of
`CommitCompiler`.

Source of Truth:

`.design/2026-05-24-p5-edit-core.md` is the repair design input.
`plan/step_29_p5_edit_core_rollback_safe_commits.md` is historical completed
P5 scope and must not be rewritten for this repair. `docs/contracts/edit_kernel.md`
owns the runtime/applier effect-delivery seam and must name the immutable
apply-result handoff. `docs/contracts/operation_matrix.md` owns phase row
ownership and must name the P5/P6 replacement split.
`docs/implementation/p6_load_document.md` owns executable load and replacement
behavior after P5. `lib/src/edit/commit_plan.dart` owns existing typed effect
values. `lib/src/edit/commit_applier.dart` owns `CommitApplyResult`.
`lib/src/runtime/commit_effect_observer.dart` owns `CommitEffectObserver`.
`EditKernel` owns session lifetime and active-session state. `RuntimeRoot`
remains the public state publication owner, observer failure containment
owner, and post-commit delivery reentrancy guard owner.

Compatibility:

Public `CanvasRuntime.edits`, `CanvasEditPort`, `CanvasEdit`, public runtime
state, public document projection, and all Step 29 P5 behavior remain source
and behavior compatible. `CanvasEditPort.loadDocument` and
`CanvasEdit.replaceDraftDocument` continue to throw `UnsupportedError` with P6
ownership wording and no side effects until P6. Future owners may consume typed
effects through the repaired seam later, but no concrete future owner is
required in this step.

Order Constraints:

Clarify durable contract wording before changing code. Add the immutable apply
result at the `CommitApplier` boundary before changing edit/runtime
consumption. Change the edit/runtime handoff before observer delivery so
`EditKernel` receives the apply result, closes the session, clears the active
edit flag, and only then lets `RuntimeRoot` publish state and invoke the
observer. Add the internal `CommitEffectObserver` callback seam to
`RuntimeRoot` before writing runtime-level delivery tests. Wire observer
invocation only after atomic install, after edit-session closure, after public
state publication, and only when the apply result carries post-install effects.
Catch observer exceptions inside `RuntimeRoot` so accepted commits remain
accepted and public edit calls return the original callback result. Reject
public runtime mutations attempted during observer delivery before any draft,
committed-state, public-state, or effect change. Add successful delivery and
observer reentrancy proof before relying on the seam in negative-path tests.
Preserve and rerun existing Step 29 focused tests after adding the repair.

## Execution Units

### [ ] Unit 1: Durable repair wording

Owner:

`docs/contracts/edit_kernel.md`, `docs/contracts/operation_matrix.md`, and
`docs/verification/tests.md` if verification ownership wording changes.

Boundary:

Only the durable wording for the `CommitApplier -> RuntimeRoot` apply result,
post-install effect delivery, and the P5/P6 replacement split. No generated
docs, diagrams, or broad P5 contract rewrite belongs in this unit unless the
repository documentation tools require generated updates from these source
changes.

Change:

Clarify that P5 completion requires typed effects to cross the
runtime/applier boundary through an immutable apply result after atomic
document and selection install and after the edit session is closed/stale.
Clarify the exact synchronous observer typedef and its owner:
`lib/src/runtime/commit_effect_observer.dart` defines
`typedef CommitEffectObserver = void Function(List<CommitEffect> effects);`.
Clarify that observer failures are contained post-commit notification failures
that do not roll back accepted edits, do not rethrow from public edit calls,
and do not replace the edit callback result. Clarify that observer delivery is
not a reentrant mutation window: public runtime mutations attempted from the
observer are rejected before draft creation or committed-state mutation.
Clarify that P5 owns the reserved `documentReplaced` invalidation/effect shape
and generic-global-invalidation exception only, while executable
`CanvasEdit.replaceDraftDocument` and load-document success/failure remain
P6-owned. Update test inventory wording only if the repair introduces or
renames a focused proof file.

Completion Check:

`docs/contracts/edit_kernel.md` names the apply-result delivery seam, states
that effect observation happens after edit-session closure, names the exact
synchronous `CommitEffectObserver` typedef and owner file, defines contained
observer failure behavior, defines observer reentrancy rejection, and does not
allow `CommitPlan.effects` alone to satisfy P5 effect delivery.
`docs/contracts/operation_matrix.md` states that executable
`CanvasEdit.replaceDraftDocument` is excluded from P5
operation-matrix closure while its reserved effect shape remains available for
P6. If files under `docs/` change,
`dart run docs/tool/sync_generated_docs.dart --check` and
`dart run docs/tool/check_docs.dart` pass.

Depends On:

None.

### [ ] Unit 2: Commit apply result boundary

Owner:

`lib/src/edit/commit_applier.dart`, `lib/src/edit/commit_plan.dart` only if the
existing effect container needs a small compatibility accessor, and focused
edit tests under `test/edit/**`.

Boundary:

The applier return value and post-install effect payload. Document install,
selection install, draft mutation, field taxonomy, public API declarations,
and concrete downstream consumers remain outside this unit.

Change:

Introduce immutable `CommitApplyResult` in `lib/src/edit/commit_applier.dart`
and return it from `CommitApplier.apply`. For accepted changes, the result
must report whether public runtime state should be published and must carry an
immutable copy/view of the typed effects from the accepted `CommitPlan` after
document and selection effects have been installed. For no-op plans, the
result must report no publication and no effects. The result must not expose
mutable plan internals and must not create a second effect taxonomy.

Completion Check:

A focused test proves `CommitApplier.apply` returns an apply result with
`shouldPublishState == true` and the accepted plan's typed effects only after
the supplied document and selection installers have run. The same test proves
an empty plan returns `shouldPublishState == false`, an empty effect list, and
does not call installers. Existing tests that assert Step 29 commit behavior
continue to compile against the new result.

Depends On:

Unit 1.

### [ ] Unit 3: Runtime effect delivery seam

Owner:

`lib/src/edit/edit_kernel.dart`, `lib/src/runtime/runtime_root.dart`, and
runtime/edit tests that exercise the internal runtime root through the public
edit port.

Boundary:

Post-close consumption of `CommitApplyResult`, public state publication from
the result, and the internal `CommitEffectObserver` callback seam. Concrete
frame, spatial, resource, surface, interaction, Flutter, and command-event
consumers remain outside this unit.

Change:

Wire the edit/runtime handoff so `RuntimeRoot._applyEditCommit` returns
`CommitApplyResult` instead of consuming a `bool` inline. `EditKernel` must
capture the accepted apply result, close and stale the `EditSession`, clear
its active-session flag, and then call a runtime-owned post-commit delivery
callback before returning the original edit callback result. Continue to
publish exactly one public `CanvasRuntimeState` only when the result says
publication is required. Define the concrete runtime seam as the synchronous
internal callback type `CommitEffectObserver` in
`lib/src/runtime/commit_effect_observer.dart` with exact signature
`typedef CommitEffectObserver = void Function(List<CommitEffect> effects);`.
Add optional named `CommitEffectObserver? commitEffectObserver` to the
existing `RuntimeRoot` constructor, default it to a no-op before forwarding to
`RuntimeRoot._`, store the resulting non-null observer, and invoke it with the
immutable non-empty post-install effect list only after session closure and
public state publication. The observer is not exported from the root public
barrel and does not change `CanvasRuntime`, `CanvasEditPort`, or `CanvasEdit`
signatures. `RuntimeRoot` must not await, schedule, or store observer futures.
Focused tests observe delivery by constructing `RuntimeRoot` directly with a
recording observer and then invoking `root.edits.edit`. If the observer throws,
`RuntimeRoot` catches the exception, keeps the committed state and already
published public state intact, does not invoke the observer again for the same
commit, and lets `CanvasEditPort.edit` return the original callback result.
While invoking the observer, `RuntimeRoot` sets a delivery guard so any public
runtime mutation, including `root.edits.edit`, selection changes, camera
changes, id generation, and disposal, throws `StateError` before mutation or
effect delivery.

Completion Check:

A focused runtime-root test proves a successful edit through
`RuntimeRoot.edits.edit` installs document/selection state first, closes and
stales the edit handle, publishes the expected public state snapshot, and only
then invokes the injected `CommitEffectObserver` once with the expected
immutable typed effects. The same test proves observer delivery occurs while
`EditKernel.hasOpenSession` is false, and that an observer which attempts each
public runtime mutation path receives `StateError` from the post-commit
delivery guard before draft creation, committed-state mutation, public-state
publication, or effect delivery. The required covered entry points are
`root.edits.edit`, `root.edits.loadDocument`, selection mutation, camera
mutation, element id generation, layer id generation, resource id generation,
and `root.dispose`. A focused
observer-failure test proves a throwing observer does not roll back document
or selection state, does not publish an extra state snapshot, does not
re-invoke the observer for the same commit, and does not prevent
`CanvasEditPort.edit` from returning the original callback result. The tests
must observe delivery through the injected observer at `RuntimeRoot`, not by
directly reading `DraftDocument.commitPlan` or `CommitPlan.effects`.

Depends On:

Unit 2.

### [ ] Unit 4: Negative paths and replacement split proof

Owner:

Focused edit/runtime tests under `test/edit/**` and `test/runtime/**`, plus
any existing P5 guardrail fixture only if its proof would otherwise miss the
repaired seam.

Boundary:

Negative-path proof for runtime/applier effect delivery and executable
replacement exclusion. No new replacement behavior, load behavior, or concrete
downstream owner implementation belongs in this unit.

Change:

Extend or add tests proving no typed effects reach the runtime/applier seam
for no-op edits, callback exceptions, Future-return rejection, nested edit
rejection, stale handle use, validation/preflight failure, and P6-owned
`loadDocument`/`replaceDraftDocument` rejection. Preserve the existing
`documentReplaced` reserved plan shape for future P6 while proving no
executable P5 edit operation produces a delivered replacement effect and that
`CanvasEdit.replaceDraftDocument` remains `UnsupportedError` before draft or
committed-state mutation.

Completion Check:

`dart test test/edit/sync_non_nested_async_stale_test.dart
test/edit/rollback_test.dart test/edit/field_update_nullable_semantics_test.dart
test/edit/edit_matrix_effects_test.dart test/edit/exact_touched_invalidation_test.dart
test/edit/typed_effects_no_frame_dependency_test.dart
test/runtime/runtime_state_publication_test.dart` passes and includes explicit
assertions that the repaired runtime/applier seam receives no effects on every
negative path named above. The tests also prove executable P5 operation-matrix
closure excludes `CanvasEdit.replaceDraftDocument` while preserving its P6
`UnsupportedError` behavior.

Depends On:

Units 2 and 3.

### [ ] Unit 5: Repair verification and graph consistency

Owner:

Repository verification commands, P5 architecture graph checks, and generated
docs or graph outputs only if source changes require regeneration.

Boundary:

Verification after Units 1-4. No production behavior beyond fixes required to
make the repaired seam and tests pass belongs in this unit.

Change:

Run the focused repair tests, repository checks required for Dart and
documentation changes, and P5 architecture graph checks. This step changes the
runtime/applier seam, so P5 graph closure must be verified even if the graph
source itself does not change. Update generated docs or generated graph views
only through repository tooling when checks report stale generated output.

Completion Check:

From the repository root, the implementation handoff reports these passing
after the repair:
`dart test test/edit/sync_non_nested_async_stale_test.dart
test/edit/rollback_test.dart test/edit/field_update_nullable_semantics_test.dart
test/edit/edit_matrix_effects_test.dart test/edit/exact_touched_invalidation_test.dart
test/edit/typed_effects_no_frame_dependency_test.dart
test/edit/low_level_mutations_do_not_emit_actions_test.dart
test/runtime/runtime_state_publication_test.dart
test/selection/runtime_owner_separation_test.dart
test/smoke/public_incremental_smoke_test.dart
test/guardrails/blocking_suite_test.dart`, `dart run tool/guardrails/run.dart`,
`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .`. If files under
`docs/` changed, it also reports
`dart run docs/tool/sync_generated_docs.dart --check` and
`dart run docs/tool/check_docs.dart` passing. If architecture-owned seams,
diagrams, graph source, generated graph views, or P5 phase closure state
changed, generated outputs are updated only through repository tooling. It
always reports `dart run tool/architecture_graph/check.dart --phase P5` and
`dart run tool/architecture_graph/generate_views.dart --phase P5 --check`
passing for this repair.

Depends On:

Units 1, 2, 3, and 4.
