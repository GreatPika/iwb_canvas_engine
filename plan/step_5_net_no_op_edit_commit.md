# Change Contract

## Goal

Accepted edit commits whose final committed document facts match the original
committed facts must behave as no-op edits. They must not advance document
revisions, invalidate caches, publish runtime state, emit action intents,
deliver typed effects, notify commit observers, or build public document
projections, while explicit `replaceDraftDocument` replacement remains a forced
replacement even when the replacement document is equivalent to the base.

## Source Inputs

- Design: `.design/2026-06-11-net-no-op-edit-commit.md`
- Research: `.research/2026-06-11-net-no-op-edit-commit.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `docs/README.md`, `docs/architecture/01_runtime_ownership.md`,
  `docs/contracts/edit_kernel.md`, `docs/contracts/operation_matrix.md`,
  `docs/contracts/cache_policy.md`, `docs/_registry/benchmarks.yaml`,
  `docs/verification/benchmarks.md`, `docs/verification/tests.md`,
  `docs/verification/guardrails.md`

## Classification

Profile: BEHAVIOR_CHANGE

Obligations: BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Accepted document fact truth is store-owned and derived from base-vs-final committed facts, not provisional operation journals. | `Boundaries.Owner`, `Boundaries.Source of Truth`, `Unit 2` | Store finalizer tests for sparse compensating background/palette/camera/add-remove no-op with unchanged revisions and projection build count. |
| `D2` `EditKernel` compiles `CommitPlan` only after accepted finalization, so final no-op deltas become empty plans before install or delivery. | `Boundaries.Order Constraints`, `Unit 3` | Public edit and interaction commit tests prove accepted net no-ops return without install, state publication, action emission, observer delivery, or typed effects. |
| `D3` `CommitCompiler` remains the typed effect taxonomy owner; its inputs change to accepted deltas and touched facts. | `Boundaries.Owner`, `Unit 3` | Operation-matrix and exact invalidation tests prove mutating accepted edits still produce the documented effects while final no-ops produce none. |
| `D4` Sparse no-op detection must not build public `CanvasDocument` projection or eagerly materialize `DraftDocument`. | `Boundaries.Out of Scope`, `Unit 2`, `Unit 4` | No-projection fixture and sparse-route AST guardrail prove no `readDocument`, eager `DraftDocument`, `readDraftDocument`, or projection cache build on ordinary sparse commit/no-op routing. |
| `D5` `replaceDraftDocument` with an equivalent document remains forced replacement. | `Boundaries.Compatibility`, `Unit 3` | Replacement regression proves equivalent replacement advances replacement/epoch effects and is not collapsed by final equality. |
| `D6` `StoreSparseCommit.revisionDelta` and `DraftDocument.revisionDelta` cease to be accepted commit truth. | `Boundaries.Order Constraints`, `Unit 3` | `test/guardrails/edit_accepted_finalization_guardrail_test.dart` fails if document-change `CommitPlan` construction can consume provisional session/draft revision deltas as accepted truth. |
| `D7` Edit commit ordering and operation-matrix no-op coverage are source-of-truth updates. | `Boundaries.Source of Truth`, `Unit 4` | `docs/contracts/edit_kernel.md`, `docs/contracts/operation_matrix.md`, and verification docs update with generated-doc checks passing. |
| `D8` Performance proof uses existing edit action benchmarks and no-projection tests; benchmark registry changes are optional unless a new tracked case is intentionally added. | `Boundaries.Order Constraints`, `Unit 4` | Targeted benchmark diff or explicit manual benchmark note covers changed incremental edit action paths without adding proof-only registry entries. |

## Evidence

- `.design/2026-06-11-net-no-op-edit-commit.md:11` / source design: disposition section records the design readiness -> contract can proceed from design to step contract.
- `.design/2026-06-11-net-no-op-edit-commit.md:293` / selected form: Candidate D is the accepted commit finalization seam before plan compilation -> contract preserves this architecture and does not reopen rejected alternatives.
- `.design/2026-06-11-net-no-op-edit-commit.md:517` / verification impact: compensating proof includes resources when public routes support them -> resource compensation must be an explicit proof path, not generic effect silence.
- `.research/2026-06-11-net-no-op-edit-commit.md:18` / problem statement: EDIT-002 allows an edit callback to restore final facts while current deltas follow intermediate operations -> contract carries `BUG_FIX` and requires compensating mutation proof.
- `.research/2026-06-11-net-no-op-edit-commit.md:20` / current root cause: draft, sparse, and store routes accumulate operation-journal deltas -> contract fixes the owning accepted-change boundary rather than one setter or one caller.
- `.research/2026-06-11-net-no-op-edit-commit.md:22` / runtime consequence: revision deltas drive install, state publication, and effect delivery -> contract moves no-op collapse before planning, install, and delivery.
- `.research/2026-06-11-net-no-op-edit-commit.md:72` / test coverage: existing tests do not cover successful compensating mutation sequences -> Unit 1 must add direct regression proof before seam migration.
- `docs/architecture/01_runtime_ownership.md:57` / ownership: `DocumentStoreKernel` owns committed document state, revisions, resource descriptors, and projection cache -> store owns final committed fact acceptance.
- `docs/architecture/01_runtime_ownership.md:60` / ownership: `EditKernel` owns synchronous edit sessions, drafts, touched sets, and commit/rollback coordination -> edit owns callback ordering and migration to accepted finalization.
- `lib/src/store/committed_document.dart:8` / source of truth: committed document facts and derived variants stay together -> final comparison must use the committed aggregate, not a public projection.
- `lib/src/edit/edit_kernel.dart:83` / current order: public edit reads `session.commitPlan` before accepted document selection -> Unit 3 must move plan compilation after accepted finalization.
- `lib/src/edit/edit_kernel.dart:121` / current order: interaction commit also reads `session.commitPlan` before accepted document selection -> Unit 3 must migrate both routes together.
- `lib/src/edit/edit_kernel.dart:177` / current handoff: accepted document selection currently happens after plan construction -> contract replaces the handoff with accepted finalization before compile.
- `lib/src/edit/commit_plan.dart:56` / current change predicate: `hasChanges` follows revision delta or selection effect -> empty accepted final deltas must be the only document-change signal seen by the applier.
- `lib/src/edit/commit_compiler.dart:12` / compiler input: compiler consumes revision delta and touched set -> compiler remains taxonomy owner while inputs become accepted final data.
- `lib/src/edit/commit_compiler.dart:57` / compiler output: ordinary effects are derived from revision delta and touched set -> exact invalidation proof must cover accepted mutating edits and accepted no-ops.
- `lib/src/edit/commit_applier.dart:79` / delivery boundary: empty plans return no publication -> accepted no-op must reach `CommitPlan.empty()`.
- `lib/src/edit/commit_applier.dart:88` / install boundary: accepted documents install only when plan revision delta has changes -> no-op collapse before compile prevents store install.
- `lib/src/runtime/runtime_root.dart:216` / runtime wiring: runtime wires edit to store preparation, apply, and delivery callbacks -> contract preserves runtime/edit/store boundary direction.
- `lib/src/runtime/runtime_root.dart:1638` / delivery: runtime delivers spatial/resource effects, publishes state, emits actions, and notifies observers from `CommitDeliveryResult` -> no-op proof must include delivery silence, not only unchanged rows.
- `lib/src/store/document_store_kernel.dart:340` / store seam: sparse preparation is the store entry point -> store or a store-owned collaborator owns final sparse fact acceptance.
- `lib/src/store/document_store_kernel.dart:341` / current sparse input: sparse preparation validates caller-provided revision delta before applying mutations -> Unit 2 must stop treating caller delta as accepted truth.
- `lib/src/store/document_store_kernel.dart:344` / current sparse mutation flag: `didMutateFacts` accumulates intermediate mutation changes -> Unit 2 must compare final committed facts against the base.
- `lib/src/store/document_store_kernel.dart:394` / prepared sparse result: current prepared result keeps next document and provided delta when any intermediate mutation changed facts -> Unit 2 must emit empty accepted change for final no-op.
- `lib/src/store/sparse_store_commit.dart:9` / sparse payload: `StoreSparseCommit` carries mutations and `revisionDelta` -> `SEAM_MIGRATION` must remove, rename, or quarantine provisional delta from accepted truth.
- `lib/src/edit/draft_document.dart:61` / draft payload: `DraftDocument` stores accumulated `_revisionDelta` -> materialized route must compare accepted final facts before commit acceptance.
- `lib/src/edit/draft_document.dart:64` / draft predicate: materialized `didChange` follows `_revisionDelta.hasChanges` -> Unit 3 must not use it as accepted commit truth.
- `lib/src/edit/edit_session.dart:386` / sparse planning: sparse session compiles a plan from provisional `_revisionDelta` and touched set -> Unit 3 must remove this accepted-truth path.
- `lib/src/edit/edit_session.dart:406` / sparse commit: sparse commit returns mutation and revision-delta payloads -> Unit 3 must keep mutations as candidate state while retiring provisional delta as accepted truth.
- `docs/contracts/edit_kernel.md:88` / contract: ordinary edit and interaction routes open sparse sessions without public projection -> contract forbids projection diff or eager materialization.
- `docs/contracts/edit_kernel.md:198` / compiler contract: sparse and materialized routes both use `CommitCompiler` for typed effects -> Unit 3 keeps compiler ownership.
- `docs/contracts/edit_kernel.md:260` / public contract: accepted edits publish one snapshot and no-op edits publish none -> compatibility posture is to remove buggy public updates for compensating no-op edits.
- `docs/contracts/operation_matrix.md:89` / operation matrix: no-op edit has no revisions, spatial, projection, repaint, or events -> Unit 4 must update matrix coverage for compensating no-op semantics.
- `docs/contracts/operation_matrix.md:217` / operation matrix: successful no-op paths publish no public snapshot and no typed effects unless named -> Unit 1 and Unit 3 proof must assert delivery silence.
- `docs/contracts/operation_matrix.md:290` / replacement exception: equivalent replacement is still document replacement -> Unit 3 must preserve forced replacement behavior.
- `lib/src/contracts/public/canvas_runtime.dart:157` / public API: `CanvasEdit` exposes `upsertResource` -> resource compensation is supported by an existing public edit route.
- `lib/src/contracts/public/canvas_runtime.dart:158` / public API: `CanvasEdit` exposes `removeUnusedResource` -> add/remove resource compensation is supported when the resource is unused.
- `lib/src/edit/edit_session.dart:102` / edit route: public edit sessions route `upsertResource` through the edit backing -> resource compensation must be covered through the same accepted finalization path.
- `lib/src/edit/edit_session.dart:598` / sparse resource mutation: sparse backing records resource upsert mutations and revision deltas -> resource compensation is vulnerable to provisional delta truth unless accepted finalization covers it.
- `lib/src/edit/edit_session.dart:620` / sparse resource removal: sparse backing can remove unused resources -> add/remove resource compensation has a public sparse candidate path.
- `docs/contracts/cache_policy.md:55` / cache policy: accepted sparse edits must not call `readDocument` or build projection cache during ordinary callback, sparse preparation/install, selection-only interaction commit, or no-op routing -> Units 2 and 4 must preserve no-projection guardrails.
- `docs/contracts/cache_policy.md:51` / cache policy: cache misses in hot paths must be bounded by candidate count, not total scene size -> ordinary sparse final comparison must be scoped to candidate-touched rows/families, not full-document or store-wide diff.
- `test/store/fixtures/no_projection_hot_path_fixture.dart:61` / fixture: sparse store add, update, and no-op do not build projection until explicit read -> Unit 2 proof extends this seam.
- `test/store/fixtures/no_projection_hot_path_fixture.dart:91` / fixture: ordinary public edit route does not build projection before explicit read -> Unit 4 proof keeps this hot path.
- `test/guardrails/edit_sparse_routes_no_eager_projection_guardrail_test.dart:9` / guardrail: ordinary edit and interaction routes must open sparse sessions -> Unit 4 updates or preserves the route guardrail.
- `test/guardrails/edit_sparse_routes_no_eager_projection_guardrail_test.dart:22` / guardrail: guarded routes must not eagerly create `DraftDocument` -> Unit 4 rejects materialized fallback for sparse no-op detection.
- `test/guardrails/edit_sparse_routes_no_eager_projection_guardrail_test.dart:28` / guardrail: guarded routes must not call `_readDocument` before accepting sparse commits -> Unit 4 rejects public projection equality checks.
- `tool/guardrails/src/guardrail_executor.dart:230` / guardrail registry: `projection.only_explicit_read_paths` includes no-projection hot path, store projection, and sparse-route guardrail tests -> Unit 4 must keep this enforcement active.
- `docs/_registry/benchmarks.yaml:188` / benchmark source: `edit.add_element` is action-only incremental edit coverage -> verification must include targeted benchmark diff when action overhead changes.
- `docs/_registry/benchmarks.yaml:209` / benchmark source: `edit.update_visual` tracks touched-count incremental edit behavior -> broad invalidation cannot hide behind functional tests.
- `docs/_registry/benchmarks.yaml:230` / benchmark source: `edit.update_transform` tracks action-only incremental edit behavior -> finalizer overhead must remain scoped.
- `docs/_registry/benchmarks.yaml:272` / benchmark source: `edit.set_camera_offset` requires ordinary paint-plan invalidations to stay zero -> accepted finalization must preserve exact invalidation.
- `docs/verification/benchmarks.md:62` / benchmark policy: benchmark registry is the source of truth -> registry changes are not required unless adding a deliberate tracked case.
- `docs/verification/benchmarks.md:111` / release policy: no GitHub release benchmark gate is currently claimed -> benchmark proof is local/manual unless a future contract changes the gate.
- `docs/README.md:24` / documentation source of truth: normative architecture, contracts, verification policy, registries, and generated navigation own durable meaning -> implementation must update owning docs rather than leaving behavior only in code or chat.

## Boundaries

Owner: `DocumentStoreKernel` or a store-owned collaborator owns accepted
document fact finalization and accepted revision deltas; `EditKernel` owns
synchronous callback/session/rollback ordering; `CommitCompiler` owns typed
effect taxonomy; `CommitApplier` and `RuntimeRoot` own install and delivery
consumption; `docs/contracts/edit_kernel.md` and
`docs/contracts/operation_matrix.md` own durable behavior wording.

In Scope: add test-first compensating no-op coverage; introduce a store-owned
accepted finalization descriptor for sparse and materialized candidates; keep
ordinary sparse final comparison bounded to candidate-touched committed
rows/families rather than full-document, full-store, or public projection diff;
migrate public edit and interaction commit routes so `CommitPlan` is compiled
only from accepted finalizer output; preserve forced replacement semantics for
`replaceDraftDocument`; remove, rename, or quarantine provisional revision
deltas so they cannot be consumed as accepted truth; update route-order and
no-projection guardrails; update owning docs and generated docs; run focused
tests, Dart/DCM checks, documentation checks, guardrails, architecture checks if
architecture-owned seams or graph surfaces change, and targeted benchmarks or a
manual benchmark note for changed edit action paths.

Out of Scope: changing `CanvasEdit.replaceDraftDocument` to be
equality-sensitive; adding a broad full-document/public projection diff to every
sparse edit; building `CanvasDocument` projection or eager `DraftDocument` for
ordinary sparse no-op detection; adding synchronizers between sparse,
materialized, store, compiler, and runtime state; adding proof-only benchmark
registry entries; changing public DTO formats, schema v1, or release benchmark
gate policy; scanning every committed row or every committed document family for
ordinary sparse finalization when the candidate touched only a bounded subset.

Source of Truth: final accepted document-change truth comes from the
store-owned committed fact aggregate and accepted finalization output, not from
operation-journal revision deltas, public projections, runtime delivery state,
or duplicated canonicalizers. Durable behavior belongs in
`docs/contracts/edit_kernel.md` and `docs/contracts/operation_matrix.md`;
verification mappings belong in `docs/verification/**` and guardrail registry
entries when enforcement changes; benchmark cases remain owned by
`docs/_registry/benchmarks.yaml`.

Compatibility: this intentionally removes buggy observable updates for
compensating no-op edits. Consumers may observe fewer revision increments,
public state notifications, action intents, typed effects, and commit observer
payloads only when final committed document facts are unchanged. Forced
replacement through `replaceDraftDocument` remains compatible with the existing
replacement contract and continues to publish replacement effects even for an
equivalent document.

Order Constraints: add failing desired-behavior compensating no-op tests before
changing the seam; introduce accepted finalization output before retiring
provisional revision-delta truth; migrate `EditKernel.edit` and
`EditKernel.prepareInteractionCommit` together; compile `CommitPlan` only after
accepted finalization and only from accepted deltas/touched facts; invoke
interaction `augmentPlan` only for accepted non-empty plans; prepare selection
before irreversible install; install document and selection through
`CommitApplier`; close the edit handle before runtime delivery; update
source-of-truth docs in the same implementation change that changes public
behavior.

Temporal Surface Closure: the temporal invariant is callback completes
synchronously, future results are rejected, accepted finalization runs, plan
compilation runs from accepted facts, optional interaction `augmentPlan` runs
only for an accepted non-empty plan, selection is prepared, install happens,
the edit handle closes, then runtime delivery publishes state/effects/actions.
The synchronous callback surfaces are public edit callback and interaction
`augmentPlan`. `EditKernel` owns the session guard and nested/asynchronous
callback rejection. Public observation may start only after handle close and
runtime delivery. Accepted net no-op must return the callback result with no
install, no state publication, no action emission, no effect observer delivery,
and no projection build; reentrant or interleaved mutation attempts during the
open session or observer delivery remain rejected with no committed mutation.

All-Or-Nothing Failure Boundary: the irreversible point is document/selection
install in `CommitApplier`. Sparse/materialized validation, final fact
comparison, accepted delta derivation, plan compilation, interaction
augmentation for non-empty plans, and selection preparation are fallible work
that must complete before that point. Runtime delivery consumes an accepted
result after install and remains failure-contained by existing delivery
semantics. Failures before install must leave committed document, selection,
revisions, projection cache, spatial/resource state, actions, effect observer
delivery, and public state listeners unchanged.

## Execution Units

### [ ] Unit 1: Compensating no-op failing proof

Owner: edit/runtime/store tests and guardrail fixtures.

Boundary: public `CanvasRuntime.edit`, `EditKernel.prepareInteractionCommit`,
materialized `CanvasEdit.readDraftDocument` fallback, sparse store preparation,
and existing no-projection fixtures. This unit may add tests and guardrail
fixtures only; production behavior changes are out of scope for this unit.

Change: add focused failing desired-behavior coverage for compensating
background A -> B -> A, palette A -> B -> A, camera A -> B -> A, add element
then remove the same element, resource compensation through either
`upsertResource` A -> B -> A or add unused resource then remove the same
resource, materialized fallback compensation after `readDraftDocument`, and
sparse store compensation before production seam migration. Additional
characterization may be added only as supplementary context, not as an
alternative to the failing desired-behavior reproducers. Include listener/effect
observer/action/revision/projection assertions so final document equality alone
is not accepted as proof.

Completion Check: focused desired-behavior tests fail against the old
provisional-delta behavior before production migration on public/runtime and
sparse store routes. The asserted direct outcomes are unchanged document
revisions, unchanged projection build count, no public state notification, no
action intents, no spatial/resource/projection/repaint delivery effects, and no
commit-effect observer payload for accepted final no-op routes, including the
resource compensation route. The sparse store fixture must show a final no-op
prepared commit has empty revision delta, no admitted ids including resource
ids, and unchanged projection build count without reading a public projection.

Depends On: none.

### [ ] Unit 2: Store-owned accepted finalization

Owner: `DocumentStoreKernel` or a store-owned internal collaborator and
store-owned accepted-change data structures.

Boundary: committed document fact comparison and accepted revision-delta
derivation for sparse and materialized document candidates. The finalizer may
inspect committed store aggregates and candidate facts; it must not call
`readDocument`, build `DocumentProjectionCache`, import runtime/frame/selection
owners, or perform runtime delivery.

Change: introduce the accepted finalization seam that validates candidates,
compares final committed facts against the base committed aggregate, advances
revisions only for accepted changed fact families, emits accepted touched facts
and accepted revision deltas for real changes, and emits an empty accepted
document change for ordinary final no-op candidates. Ordinary sparse comparison
must inspect only candidate-touched committed rows/families and their directly
affected aggregate facts; it must reject full-document, full-store, or public
projection diff as the sparse hot-path strategy. Sparse mutations remain
candidate input; provisional sparse revision deltas may only be validation or
early-pruning hints until Unit 3 retires them as accepted truth.

Completion Check: sparse store tests prove compensating sparse candidates
prepare as accepted no-ops with base revisions preserved, empty accepted
revision delta, no admitted ids including resource ids, unchanged projection
build count, and no public projection read; sparse resource compensation through
resource upsert rollback or add-unused/remove-same-resource must be one of these
accepted no-op cases. Materialized finalizer tests prove an ordinary
materialized candidate after `readDraftDocument` can collapse a compensating
final no-op, including resource compensation, to an empty accepted change, and
that a mutating ordinary materialized candidate still emits the exact accepted
delta and touched facts. Equivalent-document forced replacement is proved at
the route boundary in Unit 3, not as an ordinary materialized finalizer no-op.
Mutating sparse candidates still produce exact accepted revision families and
admitted ids. Add or extend
`test/guardrails/edit_accepted_finalization_guardrail_test.dart` as the
structural proof seam: it parses `lib/src/edit/edit_kernel.dart`,
`lib/src/edit/edit_session.dart`, `lib/src/edit/draft_document.dart`,
`lib/src/store/sparse_store_commit.dart`, and the store-owned finalizer source
introduced by this unit; it must pass only when ordinary sparse finalization is
bounded by candidate-touched rows/families, contains no public projection read
or `DocumentProjectionCache` construction, contains no full-document/full-store
ordinary sparse comparison, and has no dependency on runtime/frame/selection
owners. Benchmark diff may only supplement this guardrail when action overhead
changes.

Depends On: Unit 1.

### [ ] Unit 3: Edit route and compiler migration

Owner: `EditKernel`, `EditSession`, `DraftDocument`, `StoreSparseCommit`,
`CommitCompiler`, and internal accepted commit payloads.

Boundary: synchronous edit callback coordination through accepted finalization
and `CommitPlan` construction. This unit may change internal edit/store/compiler
seams; it must preserve public edit API signatures and public DTO formats.

Change: migrate `EditKernel.edit` and `EditKernel.prepareInteractionCommit`
together so both create sparse/materialized candidates, ask the store-owned
finalizer for accepted document-change data, and compile `CommitPlan` only from
accepted finalizer output. Preserve `CommitCompiler` as typed taxonomy owner.
Distinguish ordinary sparse candidate, ordinary materialized candidate, and
forced materialized replacement from `replaceDraftDocument`. Remove, rename, or
quarantine `StoreSparseCommit.revisionDelta`, `DraftDocument.revisionDelta`,
and any `session.commitPlan` route so provisional deltas cannot be treated as
accepted document-change truth.

Completion Check: public edit and interaction commit tests prove compensating
net no-ops return with unchanged revisions, no install, no public state
publication, no action intents, no typed delivery effects, and no commit-effect
observer payload. An interaction commit no-op test uses a spying or throwing
`augmentPlan` to prove accepted net no-op does not invoke `augmentPlan`, and a
non-empty interaction commit test proves `augmentPlan` still runs after accepted
finalization for accepted non-empty plans. Reentrancy tests exercise public edit
callback nested mutation, interaction `augmentPlan` nested mutation, and
commit-effect observer delivery mutation; each must reject with `StateError`
before any additional committed document mutation, public state publication,
action emission, projection build, or delivery effect. All-or-nothing tests
exercise fallible work before the `CommitApplier` install boundary: sparse
candidate validation failure, ordinary materialized finalization failure,
throwing non-empty interaction `augmentPlan`, and selection preparation failure
where the accepted document candidate invalidates selected ids. Each failure
must leave committed document, selection, document revisions, projection cache,
spatial/resource state, action intents, effect observer payloads, and public
state listener count unchanged. Operation-matrix and exact invalidation tests
prove accepted mutating edits still produce the documented typed effects. A
replacement regression proves `replaceDraftDocument` with an equivalent
document still advances replacement/epoch effects. Public edit route tests also
prove resource compensation reaches accepted no-op semantics through the
finalizer, with no resource revision advance, resource delivery effect, action
intent, state publication, observer payload, or projection build. The
`test/guardrails/edit_accepted_finalization_guardrail_test.dart` structural
proof must also pass only when document-change `CommitPlan` construction in
`EditKernel.edit` and `EditKernel.prepareInteractionCommit` consumes accepted
finalizer output, `augmentPlan` is ordered after accepted non-empty
finalization, and provisional `session.revisionDelta`,
`DraftDocument.revisionDelta`, or `StoreSparseCommit.revisionDelta` cannot be
consumed as accepted commit truth.

Depends On: Unit 2.

### [ ] Unit 4: Guardrails, source-of-truth docs, and verification closure

Owner: docs contracts, verification docs, guardrail registry/tests, generated
documentation, and local verification commands.

Boundary: durable behavior documentation and mechanical enforcement for edit
ordering, no-op semantics, no-projection sparse routing, replacement exception,
and benchmark interpretation. This unit must not create non-authoritative
proof-only artifacts or benchmark registry entries unless a new tracked
benchmark case is intentionally adopted as source of truth.

Change: update `docs/contracts/edit_kernel.md` to describe accepted
finalization before `CommitCompiler` plan/effect construction and no-op
delivery silence for final fact no-ops. Update
`docs/contracts/operation_matrix.md` to cover compensating no-op edit behavior
while preserving the equivalent-document replacement row. Update
`docs/verification/tests.md`, `docs/verification/guardrails.md`, generated
indexes, and guardrail registry mappings when new tests or guardrails are added.
Preserve or update the sparse-route no-eager-projection guardrail so the new
finalizer seam remains recognized without allowing `_readDocument`,
`readDraftDocument`, eager `DraftDocument`, or projection-cache construction on
ordinary sparse commit/no-op routing.

Completion Check: `dart analyze`, `dcm analyze .`, local
`dcm calculate-metrics` for changed production/test/tool owners, focused edit,
runtime, store, guardrail, operation-matrix, exact-invalidation, replacement,
rollback, and no-projection tests, `dart run docs/tool/sync_generated_docs.dart
--check`, `dart run docs/tool/check_docs.dart`,
`dart run tool/architecture_graph/check.dart`, and
`dart run tool/architecture_graph/generate_views.dart --check` all pass. If
implementation changes incremental edit action overhead, a targeted local
benchmark diff for the affected existing edit cases from
`docs/_registry/benchmarks.yaml` is recorded in the implementation handoff or
an explicit manual benchmark note states why it was not practical; no benchmark
registry change is made unless a new tracked benchmark case is intentionally
added.

Depends On: Unit 3.
