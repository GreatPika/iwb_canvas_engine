# Change Contract

## Goal

Repair the remaining P6 `loadDocument` implementation gap so successful loads
prepare interaction cleanup before document install, carry an immutable
effect-only cleanup outcome across the install commit point, and never call the
interaction owner after install to finish pointer-normalization or pending-tap
cleanup. This step supersedes the stale cleanup-ordering wording in completed
Step 36 for future implementation work without rewriting that historical step.

## Evidence

- `.design/2026-05-26-p6-load-document.md` / selected form: the accepted repair is Candidate A, a single prepared cleanup outcome seam that replaces the two-method `LoadInteractionBoundary` and retires post-install `clearPostInstallFacts()` -> the implementation must migrate the shared seam, not only update one fixture assertion.
- `.research/2026-05-26-load-document-contract-review-gap.md` / current status: durable docs already require prepared cleanup before install, but `RuntimeRoot._loadDocument` and the ordering fixture still accept post-install cleanup -> the active plan step should target code and fixture drift rather than durable-doc repair.
- `docs/contracts/load_document.md` / staged contract: successful preparation requests prepared load cleanup, the boundary returns `PointerCleanupOutcome` before document install, and `RuntimeRoot` must not call the interaction boundary again after install -> the post-install interaction method is out of contract.
- `docs/contracts/interaction_engine.md` / cleanup outcome contract: `PointerCleanupOutcome` is effect-only; runtime may consume it after cleanup completes and after install, but must not re-read stale interaction state or call the interaction owner after install -> post-install runtime work may consume only already prepared data.
- `docs/contracts/operation_matrix.md` / `loadDocument success`: load success touches prepared interaction cleanup outcome, and after successful install runtime consumes the already prepared outcome without a post-install interaction owner boundary -> effect and repaint aggregation must use the prepared outcome.
- `docs/verification/guardrails.md` / load guardrails: `load.prepares_before_interrupt` and `load.success_interrupts_before_install` require failure to avoid interaction cleanup and success to prepare cleanup before atomic install with no post-install owner call -> focused ordering tests are the guardrail proof surface.
- `docs/implementation/p6_load_document.md` / exit gate: P6 requires successful load to interrupt before install, publish one atomic state, and perform no post-install interaction owner call to finish pointer-normalization or pending-tap cleanup -> the repair is required for phase closure.
- `lib/src/runtime/runtime_root.dart` / current seam: `_loadDocument` prepares, calls `interruptPreparedLoad()`, installs the prepared load, updates runtime facts, then calls `clearPostInstallFacts()`; `LoadInteractionBoundary` exposes both methods -> the current owner boundary still makes the forbidden post-install call representable.
- `test/runtime/fixtures/load_document_ordering_fixture.dart` / current proof: the success fixture expects `interrupt`, `post-install-cleanup`, `state`, `observer`, and the cleanup callback observes the replacement document -> the executable proof currently blesses the wrong temporal order.
- `test/runtime/load_document_ordering_test.dart` / guardrail runner target: the guardrail IDs execute through the load ordering fixture -> repairing that fixture updates the existing blocking guardrail proof instead of creating a parallel proof path.
- `test/runtime/fixtures/load_document_state_publication_fixture.dart` / publication proof: existing load state tests assert one post-install state, replacement document facts, load effects, and failure no-side-effects -> the seam repair must preserve the public publication and failure behavior.
- `docs/verification/tests.md` / public incremental smoke responsibility: the smoke test must expand only by appending the next real public user step after a future phase exposes one -> because P6 exposes `runtime.edits.loadDocument`, Step 37 must close the missing P6 smoke append while keeping detailed ordering and failure diagnostics in focused tests.
- `.design/2026-05-23-public-incremental-smoke-test.md` / future expansion rule: the expected P6 append is loading one second decoded document through `runtime.edits.loadDocument`, then asserting one atomic public state update and new `readDocument` content -> the smoke unit should append exactly that public happy-path step instead of adding private probes.
- `docs/architecture/architecture_graph.yaml` / load owner: the graph declares `load_document.pipeline` and its store replacement boundary for P6 -> the repair must keep document materialization and store mutation owned by the existing load pipeline and runtime orchestration.

## Boundaries

Owner:

`RuntimeRoot` owns external `loadDocument` orchestration and the install/publication window. The load-document pipeline owns validation, materialization, and store replacement consumption. The load interaction boundary owns interaction cleanup state behind a narrow seam and returns effect-only cleanup data; runtime must not take ownership of pointer-normalization or pending-tap state.

In Scope:

- Replace the current two-method `LoadInteractionBoundary` shape with one success-only prepared-cleanup call that returns a `PointerCleanupOutcome` before document install.
- Move the load interaction seam declarations out of `runtime_root.dart` into `lib/src/runtime/load_interaction_boundary.dart` to keep the boundary cohesive while preserving the existing internal test injection surface.
- Update `RuntimeRoot._loadDocument` so the order is: prepare document, request prepared cleanup outcome exactly once, install prepared document, clear selection, initialize runtime camera and revisions, consume the already prepared outcome for preview/effect/repaint facts, publish one state, deliver observer effects.
- Make failure before `PreparedDocumentLoad` success call no interaction boundary, mutate no runtime/store/selection/camera/preview facts, emit no repaint/action/effect, and publish no state.
- Update the load ordering fixture and guardrail proof so success proves the cleanup callback runs before install and cannot observe the replacement document, and so no boundary callback can run after install to finish cleanup.
- Append the missing P6 public user step to
  `test/smoke/public_incremental_smoke_test.dart`: load a second decoded
  document through `runtime.edits.loadDocument`, then assert one atomic public
  state update and new public `readDocument()` content.
- Preserve existing synchronous delivery guards for state listeners and commit-effect observer callbacks after the installed state is published.
- After implementation and verification pass, mark Step 37 complete in `PLAN.md`
  and mark this step document's completed execution-unit checkboxes in the same
  change.

Out of Scope:

- Do not implement the future P10-P12 interaction state machines, pointer tool machines, or full `PointerToolCleanupCoordinator`.
- Do not move pointer-normalization, pending-tap, preview-session, resolver, store, or selection ownership into `RuntimeRoot`.
- Do not change public `CanvasEditPort.loadDocument`, public DTOs, schema formats, or public runtime state API signatures.
- Do not relax unrelated P6 phase obligations from
  `docs/implementation/p6_load_document.md`, including
  `CanvasEdit.replaceDraftDocument` rollback behavior, staged document load
  success/failure coverage, operation matrix replacement rows, cache/effect
  invalidation, DTO ownership validation, or metadata validation.
- Do not rewrite completed Step 36 except by treating its stale post-install cleanup wording as historical and superseded by this Step 37, the accepted design, and current durable contracts.
- Do not edit durable docs or generated diagrams unless implementation discovers drift beyond the already-correct prepared-cleanup/no-post-install-owner-call ordering.

Source of Truth:

Current durable source of truth is `docs/contracts/load_document.md`,
`docs/contracts/interaction_engine.md`, `docs/contracts/operation_matrix.md`,
the load success/failure diagrams, and `docs/verification/guardrails.md`. The
accepted design input for this repair is
`.design/2026-05-26-p6-load-document.md`; it selects the architecture form for
this step but is not durable behavioral source of truth. For Unit 4 only,
`docs/verification/tests.md` and
`.design/2026-05-23-public-incremental-smoke-test.md` govern the append-only
public incremental smoke expansion. Step 36 is historical for this cleanup
ordering and must not override the current contracts.

Compatibility:

Public API signatures, public runtime state shape, schema/data formats, and
guardrail IDs remain stable. Internal `src` test fixtures may change with the
seam migration. Existing successful-load behavior still publishes one installed
state and delivers one post-publication effect batch; failed loads still rethrow
the validation/materialization error without side effects. Existing P6
replacement behavior outside the repaired cleanup seam remains compatible:
`replaceDraftDocument` stays rollback-safe inside edit sessions, operation
matrix load/draft rows remain executable, and load success still emits the
projection, spatial, resource, repaint, selection, and public-state effects
required by the operation matrix.

Order Constraints:

Validation and materialization must complete before any interaction cleanup
call. The only load interaction boundary callback must complete and return its
`PointerCleanupOutcome` before the document install commit point. The
irreversible point is the prepared document install plus selection-owner clear.
After that point, runtime may consume only the already prepared cleanup outcome
for preview revision, repaint/effect aggregation, public state publication, and
observer delivery. Synchronous state-listener callbacks run before the
commit-effect observer callback, and public mutations attempted from either
callback surface must keep throwing the existing post-commit delivery `StateError`.

## Execution Units

### [ ] Unit 1: Prepared cleanup seam

Owner:

Runtime load/interaction seam.

Boundary:

Internal `src` seam currently exposed as `LoadInteractionBoundary` to
`RuntimeRoot.test` and load ordering fixtures. The seam must represent one
success-only pre-install cleanup request and an immutable effect-only
`PointerCleanupOutcome`; it must not expose a post-install cleanup method.

Change:

Extract `LoadInteractionBoundary` into
`lib/src/runtime/load_interaction_boundary.dart` and replace
`interruptPreparedLoad()` plus `clearPostInstallFacts()` with one
prepared-load cleanup method named `prepareLoadCleanup()` that returns
`PointerCleanupOutcome` before document install. Add the minimal internal P6
outcome value in the same seam file with an explicit `previewChanged` fact and a
no-change/default outcome; future pointer-session fields remain out of scope
until the interaction owner lands. Keep the concrete no-op implementation
private to the seam file, expose it through
`const LoadInteractionBoundary noopLoadInteractionBoundary =
_NoopLoadInteractionBoundary();`, and update `RuntimeRoot` production
construction to use that const boundary. Keep the default production boundary
effect-only and unable to read or mutate `DocumentStoreKernel` or selection
state.

Completion Check:

`rg -n "clearPostInstallFacts|post-install-cleanup|onPostInstallCleanup" lib test`
prints no production or load ordering fixture references, while
`rg -n "PointerCleanupOutcome|abstract interface class LoadInteractionBoundary|class _NoopLoadInteractionBoundary" lib/src/runtime`
shows the focused runtime seam file, private no-op implementation, and
`noopLoadInteractionBoundary` const access point used by `RuntimeRoot`.
Add `test/runtime/load_interaction_boundary_shape_test.dart` as the focused
seam-shape proof. The test implements `LoadInteractionBoundary` with exactly
one override, `prepareLoadCleanup()` returning `PointerCleanupOutcome`; it must
fail to compile if `LoadInteractionBoundary` exposes any second cleanup phase
under any name. The same seam-shape proof must assert the outcome is
value-only: a `const` constructor, final data fields, no setters, no
callback/function fields, and no lazy owner reads after the boundary returns.
`rg -n "DocumentStoreKernel|SelectionKernel|selection_kernel|document_store_kernel" lib/src/runtime/load_interaction_boundary.dart`
prints no matches, proving the seam file does not import or reference concrete
store or selection owners.
`dart analyze` must report no missing method, import, or type errors for the
migrated seam. Runtime ordering behavior and fixture event assertions are
proved by Units 2 and 3.

Depends On:

None.

### [ ] Unit 2: Runtime load ordering and failure boundary

Owner:

`RuntimeRoot`.

Boundary:

`RuntimeRoot._loadDocument`, `_loadEffects`, runtime revision facts, and the
post-install state/effect delivery window. The load-document pipeline remains
the only document replacement materialization/store-consume owner, and
selection clear remains selection-owned.

Change:

Update `_loadDocument` so it prepares the document first, calls the load
interaction boundary exactly once to obtain the prepared cleanup outcome before
`_loadPipeline.consume(preparedLoad)`, then installs the document, clears
selection, initializes runtime camera/revisions, applies prepared cleanup
outcome facts without calling interaction again, and delivers one load result.
If boundary cleanup fails before the commit point, the load must not consume the
prepared load, clear selection, update camera/revisions, publish state, or
deliver effects; the failure is still before the irreversible install point.
Keep observer failures contained after publication as they are today.

Completion Check:

`test/runtime/load_document_ordering_test.dart` includes an executable case
where the prepared cleanup callback throws; the expected signal is that
`root.readDocument()`, selected ids, runtime camera, public state value, effect
batches, action stream, and boundary event list show no
install/publication/action event after the thrown cleanup error.
`dart test test/runtime/load_document_ordering_test.dart` passes and still
proves invalid document preparation calls no interaction boundary and emits no
`CanvasActionCommitted` event.
`rg -n "_loadInteractionBoundary\\." lib/src/runtime/runtime_root.dart` prints
exactly one call site, and that call appears before `_loadPipeline.consume(` in
`_loadDocument`; any additional interaction boundary callback before or after
install fails the unit. The load ordering fixture's recording boundary records
every `LoadInteractionBoundary` callback and asserts the successful load event
list contains exactly one interaction event before `state` and `observer`.

Depends On:

Unit 1.

### [ ] Unit 3: Ordering fixture and guardrail proof

Owner:

Load ordering test fixture.

Boundary:

`test/runtime/fixtures/load_document_ordering_fixture.dart` and its wrapper
`test/runtime/load_document_ordering_test.dart`, which are already the
registered proof for `load.prepares_before_interrupt` and
`load.success_interrupts_before_install`.

Change:

Rewrite the success fixture to record the prepared cleanup callback before
install, assert that the callback still observes the old document, and assert
that the first public state listener and the commit-effect observer observe the
replacement document after install. Add negative proof that the recording
boundary has no post-install cleanup callback surface and that the event order
cannot include an interaction owner boundary call between install and
publication. Preserve the existing synchronous reentrancy guard checks for
state listener and observer delivery callbacks.

Completion Check:

`dart test test/runtime/load_document_ordering_test.dart` passes with expected
success order equivalent to `prepared-cleanup`, `state`, `observer`; the
prepared cleanup assertion fails if it observes the replacement document, and
the fixture has no `post-install-cleanup` event or callback field. The same test
continues to reject public mutations during synchronous state-listener and
observer callbacks with the existing post-commit delivery `StateError`.

Depends On:

Units 1 and 2.

### [ ] Unit 4: Public P6 smoke append

Owner:

Public incremental smoke test.

Boundary:

`test/smoke/public_incremental_smoke_test.dart`, using only the generated
external consumer package and the root public barrel import. The smoke remains
one readable public user journey and must not import `src/**`, instantiate
`RuntimeRoot`, inspect private revisions, or duplicate focused failure tests.

Change:

Append the P6 public load step after the existing decode, selection, and public
edit steps. The generated consumer test must decode a second schema v1 document,
subscribe to public runtime state snapshots around the load step, call
`runtime.edits.loadDocument(secondDocument)`, and assert exactly one public state
update for the load, replacement document summary/revisions, cleared selection,
runtime view camera initialized from the second document's persisted camera, and
`runtime.readDocument()` exposing the second document content. Keep the smoke
happy-path only; ordering, failure, interaction cleanup, and operation-matrix
details remain in focused tests.

Completion Check:

`dart test test/smoke/public_incremental_smoke_test.dart` passes. The generated
consumer source contains one P6 load step using
`runtime.edits.loadDocument(secondDocument)` through
`package:iwb_canvas_engine/iwb_canvas_engine.dart`, observes exactly one load
state snapshot, and contains no `src/`, `RuntimeRoot`, projection-cache,
store-kernel, frame/spatial/geometry internal, interaction-boundary, invalid
input, or private-revision assertions.

Depends On:

Units 1, 2, and 3.

### [ ] Unit 5: Publication and verification closure

Owner:

Runtime load publication tests and repository verification.

Boundary:

Existing load state publication fixture, focused load tests, static analysis,
DCM checks, and architecture/docs checks only if implementation edits their
owned surfaces.

Change:

Update the load state publication fixture to assert that one installed public
state and one post-publication effect batch are still published from the
committed result plus the prepared cleanup outcome. Add a focused publication
case with an injected boundary returning `PointerCleanupOutcome(previewChanged:
true)`; the successful load must publish exactly one installed state, increment
`state.revisions.preview` from the pre-load value in that state, and still
deliver a single post-publication effect batch. Keep failed-load no-side-effects
coverage for document, selection, camera, generated id floor, state snapshots,
and effect batches. Do not duplicate the ordering fixture's seam-level proof
here. After implementation and verification pass, update `PLAN.md` and this step
document so Step 37 and each completed execution unit are marked complete in the
same change.

Completion Check:

Run `dart test test/runtime/load_document_ordering_test.dart` and
`dart test test/runtime/load_document_state_publication_test.dart`; both pass.
The state publication test includes an injected
`PointerCleanupOutcome(previewChanged: true)` success case whose expected signal
is exactly one installed public state with `state.revisions.preview` incremented
from the pre-load value and exactly one post-publication effect batch.
The publication proof must consume only the already returned value-only
`PointerCleanupOutcome`; it must not rely on callbacks, function-backed getters,
or any post-install read from the interaction boundary or interaction owner.
After the Dart code change, run `dart analyze`, `dcm analyze .`, and
`dcm calculate-metrics .` from the repository root. Also run
`dart test test/edit/staged_document_load_success_failure_test.dart` and
`dart test test/edit/edit_matrix_effects_test.dart` so Step 37 does not regress
the broader P6 staged load/draft replacement and operation matrix obligations.
Run `dart test test/smoke/public_incremental_smoke_test.dart` so the public
incremental smoke includes the P6 load step expected by the smoke expansion
rule.
Run `dart run tool/architecture_graph/check.dart --phase P6` and
`dart run tool/architecture_graph/generate_views.dart --phase P5 --check`
because this step changes a production load/interaction seam. Run
`dart run docs/tool/sync_generated_docs.dart --check` and
`dart run docs/tool/check_docs.dart` only if docs or generated documentation
tools changed. Before the implementation change is considered complete,
`PLAN.md` shows Step 37 checked and this step document shows Units 1-5 checked.

Depends On:

Units 1, 2, 3, and 4.
