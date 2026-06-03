# Change Contract

## Goal

Close the post-P12 findings as durable behavior and enforcement fixes: rejected spatial context-target reads must not emit empty-canvas requests, accepted context requests must have an explicit asynchronous delivery contract, request ids must be consumed instead of retained forever, text-edit and immutable read-fact guardrails must reject structural bypasses, and repository source-of-truth docs must describe current P12 behavior without changing public request or command shapes.

## Source Inputs

- Design: `.design/2026-06-03-p12-findings-closure.md`
- Research: `.research/2026-06-03-p12-findings-architecture-facts.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `plan/step_49_p12_eraser_and_context_action_request.md`, `docs/contracts/spatial_kernel.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/operation_matrix.md`, `docs/contracts/public_api_v1.md`, `docs/contracts/diagnostics.md`, `docs/verification/tests.md`, `docs/verification/guardrails.md`, `docs/verification/guardrail_design_patterns.md`, `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, `docs/diagrams/seq_context_action_request.mmd`, `docs/diagrams/state_pending_context_action_request.mmd`, `lib/src/interaction/interaction_engine.dart`, `lib/src/interaction/interaction_read_port.dart`, `lib/src/interaction/interaction_request_registry.dart`, `lib/src/runtime/runtime_interaction_read_adapter.dart`, `lib/src/runtime/runtime_root.dart`, `test/diagnostics/interaction_diagnostics_test.dart`, `test/diagnostics/fixtures/interaction_diagnostics_fixture.dart`, `test/smoke/public_incremental_smoke_test.dart`, `test/api_contract/public_api_v1_compiles_as_written_test.dart`, `tool/guardrails/src/interaction_guardrail_checks.dart`

## Classification

Profile: ANALYZER_RULE

Obligations: BUG_FIX, SEAM_MIGRATION

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Non-candidate context spatial results are rejected internal outcomes, not empty-canvas targets. | `Boundaries.Owner`, `Boundaries.Source of Truth`, Unit 1 | Invalid-index, stale-index, and budget-exceeded context target tests assert no request id, no public request after async flush, no timestamp, and no public effects. |
| `D2` `ContextTargetReadFacts.emptyCanvas` is valid only after a candidate query succeeds and no topmost context hit is found. | `Boundaries.Compatibility`, Unit 1 | Valid empty-canvas control test proves an admitted candidate/no-hit query still emits one empty-canvas request with the existing public payload shape. |
| `D3` `InteractionEngine` issues request ids only after target admission succeeds. | `Boundaries.Order Constraints`, Unit 1 | Direct and pointer route tests assert rejected outcomes never reach registry issuance and admitted outcomes issue before stream add. |
| `D4` Direct rejected target reads do not reserve runtime timestamps. | `Boundaries.Order Constraints`, Unit 1 | Rejected direct target read followed by an accepted request/action proves the runtime timestamp cursor did not advance on rejection. |
| `D5` Rejected stale-index and budget-exceeded target reads record bounded diagnostics; rejected invalid-index reads do not. | `Boundaries.Owner`, Unit 1 | Stale and budget fixtures assert bounded interaction diagnostics; invalid-index fixture asserts no diagnostics and no public request. |
| `D6` Context request stream remains asynchronous broadcast delivery. | `Boundaries.Temporal Surface Closure`, Unit 3 | Timing test asserts listener is not called before `handleDoubleTap` or pointer admission returns and is called after an event-loop flush. |
| `D7` Context request stream close preserves queued accepted requests for subscribed listeners before done. | `Boundaries.Temporal Surface Closure`, Unit 3 | Dispose-after-add runtime lifecycle test observes accepted request before done for a subscribed listener. |
| `D8` Registry stores live request facts only; known rejected, same-text accepted, and successful changed-text accepted requests are consumed once. | `Boundaries.Source of Truth`, Unit 2 | Registry/text guard tests assert consumed ids have no live facts, repeated commits are unknown/consumed no-ops, and failed changed-text prepare keeps the request live. |
| `D9` Accepted changed text follows `guard accepted -> prepare succeeds -> consume/remove -> public state/action delivery`. | `Boundaries.All-Or-Nothing Failure Boundary`, Unit 2 and Unit 4 | Runtime delivery-order fixture and semantic guardrail proof assert consume after successful prepare and before `_deliverEditCommitResult` or action listener observation. |
| `D10` Load success and dispose clear remaining live request facts. | `Boundaries.Order Constraints`, Unit 2 | Runtime lifecycle tests assert ids issued before successful load/dispose have no live guard facts and later commits are no-effect. |
| `D11` Text-edit guardrail uses semantic event sequence, not string marker positions. | `Classification`, Unit 4 | Guardrail negative fixtures with accepted-gate markers but rejected branches reaching prepare fail under the runner. |
| `D12` Immutable read-fact guardrail derives copied-field obligations and covers eraser fields. | `Classification`, Unit 4 | Guardrail tests remove `List.unmodifiable` from eraser corridor/ids and add a synthetic iterable/list copied-field fixture that must be derived or explicitly rejected. |
| `D13` Behavior tests remain the direct proof of read-fact immutability; guardrail prevents structural drift. | `Boundaries.Source of Truth`, Unit 4 | Existing eraser read-fact immutability behavior tests stay focused, while guardrail tests prove structural enforcement. |
| `D14` Source-of-truth docs must be repaired to current P12 behavior and consume/remove registry semantics. | `Boundaries.Source of Truth`, Unit 5 | Docs checks, generated-doc sync, semantic searches, and diagram/architecture checks where triggered prove no stale current-P12 wording remains. |
| `D15` Public API compatibility is preserved. | `Boundaries.Compatibility`, Units 1, 2, 3, 5 | Public API and smoke tests prove no new public target variants, request id types, context request payload fields, or command signatures are added. |
| `D16` Pointer context target rejection is a state decision: rejected first tap stores no pending context tap and rejected second tap clears existing pending tap without issuing a request. | `Boundaries.Owner`, `Boundaries.Order Constraints`, Unit 1 | Pointer routing tests assert rejected first-tap no-pending-state and rejected second-tap cleanup/no-request/no-effect behavior. |

## Evidence

- `.design/2026-06-03-p12-findings-closure.md:13` / disposition: design is `READY_FOR_CONTRACT` -> write a full contract, not a blocker.
- `.design/2026-06-03-p12-findings-closure.md:29` / classification: design selects `ANALYZER_RULE` -> contract must include guardrail rewrite proof, not behavior tests alone.
- `.design/2026-06-03-p12-findings-closure.md:30` / obligations: design selects `BUG_FIX` and `SEAM_MIGRATION` -> contract must repair production defects and migrate internal seams.
- `.design/2026-06-03-p12-findings-closure.md:21` / non-goal: no new public context target variants or spatial failure payloads -> compatibility excludes public API shape changes.
- `.design/2026-06-03-p12-findings-closure.md:24` / non-goal: no runtime-owned context/text session manager -> ownership stays in interaction registry and app-owned UI.
- `.design/2026-06-03-p12-findings-closure.md:288` / selected seam: admitted/rejected context target outcome is the successor seam -> Unit 1 must introduce an internal outcome before issue-site migration.
- `.design/2026-06-03-p12-findings-closure.md:294` / execution order: tests first, then outcome migration, registry migration, guardrails, docs -> order constraints preserve the selected migration.
- `.design/2026-06-03-p12-findings-closure.md:295` / temporal closure: context requests are accepted after candidate-admitted target read and delivered asynchronously -> Unit 3 must prove listener timing.
- `.design/2026-06-03-p12-findings-closure.md:296` / all-or-nothing boundary: context query/admission happens before timestamp/id/stream add; changed-text prepare happens before consumption -> Units 1 and 2 must prove failure projection and sequencing.
- `.design/2026-06-03-p12-findings-closure.md:397` / source truth: spatial kernel remains candidate admission truth -> Unit 5 should cross-link rather than redefine spatial semantics.
- `.design/2026-06-03-p12-findings-closure.md:398` / source truth: interaction docs must describe rejected query no-request behavior, diagnostics, and consume/remove registry semantics -> Unit 5 owns docs repair.
- `.design/2026-06-03-p12-findings-closure.md:404` / guardrail source truth: pattern docs must be updated before immutable read-fact scanner rewrite is complete -> Unit 4 must include source-of-truth update proof.
- `.design/2026-06-03-p12-findings-closure.md:441` / handoff: D1 through D16 are required decision trace rows -> this contract maps every design decision to a unit or proof surface.
- `docs/contracts/spatial_kernel.md:109` / spatial contract: only `SpatialCandidatesResult` carries candidate handles -> context admission must use candidate status as source of truth.
- `docs/contracts/spatial_kernel.md:111` / spatial contract: non-candidate typed results must not project as successful empty candidate sets -> non-candidate context reads must emit no empty-canvas request.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:318` / current read owner: `_contextTargetFacts` owns atomic context target reads -> admission belongs at the read-port/adapter boundary.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:338` / current bug point: null `hitFacts` returns `ContextTargetReadFacts.emptyCanvas` -> current fact-only seam cannot distinguish valid empty canvas from non-candidate results.
- `lib/src/interaction/interaction_read_port.dart:150` / query facts: statuses already distinguish candidates, invalid-index, stale-index, and budget-exceeded -> internal outcome can be typed without public payload changes.
- `lib/src/interaction/interaction_read_port.dart:271` / target kinds: context target kinds are only content element and empty canvas -> do not add public-like failure target kinds.
- `lib/src/interaction/interaction_engine.dart:244` / direct route: direct double tap enters `InteractionEngine` -> request admission stays interaction-owned.
- `lib/src/interaction/interaction_engine.dart:255` / current order: direct double tap resolves timestamp before target facts -> migration must move timestamp reservation after target admission.
- `lib/src/interaction/interaction_engine.dart:1102` / issue owner: `_issueContextRequest` owns registry issuance and request intent creation -> Unit 1 must keep registry writes after admission, not in the read adapter.
- `docs/contracts/diagnostics.md:89` / diagnostics contract: interaction-observed query budget and stale candidate reliability events are interaction diagnostics that must not mutate state, emit actions, or resolve timestamps -> Unit 1 diagnostics proof belongs to interaction diagnostics tests and no-effect assertions.
- `lib/src/interaction/interaction_engine.dart:1288` / diagnostics owner: `_recordQueryDiagnostics` returns for invalid-index, records stale-candidate diagnostics for stale-index, and records query-budget diagnostics for budget-exceeded -> Unit 1 must preserve stale/budget diagnostics and invalid-index silence for rejected context target reads.
- `test/diagnostics/interaction_diagnostics_test.dart:6` / diagnostic proof owner: interaction diagnostics route through the dedicated diagnostics fixture -> Unit 1 should extend this owner or explicitly named context-action diagnostics fixtures, not an unspecified test surface.
- `lib/src/interaction/interaction_request_registry.dart:77` / registry state: `_facts` stores issued facts -> registry is the owner for live fact retention and consumption policy.
- `lib/src/interaction/interaction_request_registry.dart:121` / current retirement: `retire` rewrites facts in the map -> Unit 2 must replace permanent retired facts with consume/remove semantics.
- `lib/src/interaction/interaction_engine.dart:111` / guard owner: `textEditGuardDecision` is the interaction-owned guard boundary -> Unit 2 must keep stale classification in interaction.
- `lib/src/runtime/runtime_root.dart:743` / command boundary: `commitTextEdit` is the public command entrypoint -> runtime keeps input validation and edit delivery ownership.
- `lib/src/runtime/runtime_root.dart:762` / mutation boundary: changed text uses `EditKernel.prepareInteractionCommit` -> changed-text consumption must not happen before successful prepare.
- `lib/src/runtime/runtime_root.dart:782` / current delivery order: accepted changed request retires before `_deliverEditCommitResult` -> Unit 2 preserves non-live-before-delivery semantics with consume/remove.
- `lib/src/runtime/runtime_root.dart:158` / action delivery: action stream is synchronous -> text-edit delivery-order proof must account for synchronous listener callbacks.
- `lib/src/runtime/runtime_root.dart:160` / request delivery: context request stream is default broadcast -> asynchronous stream timing is compatibility-preserving.
- `docs/contracts/interaction_engine.md:273` / P12 contract: accepted context targets emit exactly one request -> rejected target reads are not accepted targets.
- `docs/contracts/operation_matrix.md:92` / effect matrix: context request delivery has no document, selection, preview, spatial, projection, resource, repaint, or action effects -> rejected target reads must also have no public effects.
- `docs/contracts/operation_matrix.md:133` / text guard list: stale guards exclude documentRevision -> registry migration must not add documentRevision as a stale guard.
- `docs/verification/tests.md:662` / docs drift: P10 tool-port prose still says double tap remains P12 unsupported and context requests are empty -> Unit 5 must repair phase-context wording.
- `docs/verification/tests.md:719` / docs drift: the same inventory also lists P12 context-action tests -> Unit 5 must reconcile historical P10 and current P12 descriptions.
- `docs/verification/guardrail_design_patterns.md:25` / guardrail pattern: statement-order rules should collect semantic events -> text-edit guardrail rewrite should not stay string-index based.
- `docs/verification/guardrails.md:218` / guardrail source truth: current `interaction.text_edit_stale_commit_guard` wording still says unknown/already-retired ids and privately retired rejected requests -> Unit 4 must update this row to consume/remove semantics as an unconditional source-of-truth repair.
- `tool/guardrails/src/interaction_guardrail_checks.dart:484` / current immutable scanner: copied-field list stops before P12 eraser iterable fields -> Unit 4 must cover eraser fields and future iterable/list copied fields.
- `tool/guardrails/src/interaction_guardrail_checks.dart:516` / current text scanner: marker discovery starts from string body indexes -> Unit 4 must add semantic event proof and bypass fixtures.
- `lib/src/interaction/interaction_read_port.dart:232` / eraser request: eraser request accepts iterable corridor points -> immutable copied-field guardrail must cover request inputs.
- `lib/src/interaction/interaction_read_port.dart:242` / eraser facts: eraser facts accept iterable corridor points and erased ids -> immutable copied-field guardrail must cover fact outputs.
- `test/interaction/fixtures/interaction_read_port_fixture.dart:203` / existing behavior proof: tests mutate caller-owned eraser corridor after read -> behavior immutability already has direct proof.
- `test/interaction/fixtures/interaction_read_port_fixture.dart:217` / existing behavior proof: tests assert exposed eraser lists throw on clear -> guardrail should enforce structure without replacing behavior proof.

## Boundaries

Owner:

`InteractionEngine`, `RuntimeInteractionReadAdapter`, `InteractionReadPort`, `ContextActionRouter`, and `InteractionRequestRegistry` own context-target admission, request issuance, pending context tap state, guard facts, and live request consumption. `RuntimeRoot` owns public command/tool entrypoints, context request stream timing/closure, runtime timestamp reservation, edit delivery, public state/action publication, and lifecycle composition. `EditKernel` remains the changed-text mutation boundary. `tool/guardrails/src/interaction_guardrail_checks.dart` and runner-backed guardrail tests own executable structural enforcement. Docs, diagrams, registries, and architecture graph YAML own repository source-of-truth wording after implementation; generated docs, indexes, and graph views are mechanically regenerated and checked outputs from those owning sources.

In Scope:

Add an internal admitted/rejected context target outcome at the interaction read boundary; migrate direct and pointer context routes so only admitted content/empty targets can issue request ids and stream intents; record stale/budget rejected-query diagnostics while keeping invalid-index diagnostics-silent; move timestamp reservation after target admission; migrate request registry from retained retired facts to live facts consumed/removed by rejected known commands, accepted same-text commands, successful changed-text prepare, load success, and dispose; update text-edit runtime sequencing proof; rewrite `interaction.text_edit_stale_commit_guard` as semantic-event/control-flow proof; rewrite `interaction.read_port_immutable_facts` to derive copied-field obligations and include eraser/future iterable list fields; repair current P12 docs, diagrams, guardrail pattern/source entries, registries, generated docs, and architecture graph outputs where changed surfaces require it.

Out of Scope:

Do not add public context target failure variants, expose spatial failure details through `CanvasContextActionRequested`, change `CanvasInteractionRequestId`, change `CanvasContextActionRequested`, change `CanvasCommandPort.commitTextEdit`, or change public context target payload shapes. Do not add a runtime-owned editor/context-menu/session manager, engine-owned UI, IME/focus/accessibility/text-selection policy, or documentRevision stale guard. Do not patch one request issuance call site while leaving fact-only target reads or retained retired registry facts as the source of truth. Do not close docs drift without executable behavior and guardrail proof.

Source of Truth:

Spatial candidate admission belongs to `docs/contracts/spatial_kernel.md` and `SpatialCandidatesResult`. Context target success/failure belongs to the internal interaction read outcome seam, not to public target variants or empty resolved candidate lists. Request validity belongs to live `InteractionRequestRegistry` facts that are consumed once and then absent. Text-edit mutation order belongs to `RuntimeRoot.commitTextEdit` plus semantic guardrail proof. Guardrail pattern choices belong to `docs/verification/guardrail_design_patterns.md`, `docs/verification/guardrails.md`, `docs/_registry/sections.yaml`, and runner-backed guardrail tests. Current P12 behavior belongs to `docs/contracts/interaction_engine.md`, `docs/contracts/operation_matrix.md`, `docs/contracts/public_api_v1.md`, `docs/verification/tests.md`, relevant diagrams, and architecture graph YAML when those files are changed. Generated docs, indexes, and graph views are not source-of-truth owners; they must be regenerated and checked from the owning docs, registries, diagrams, and graph sources.

Compatibility:

Public APIs and payload shapes remain source-compatible. Accepted content and empty-canvas context targets still emit `CanvasContextActionRequested` with existing request id, trigger, epoch, document revision, timestamp, positions, and target payloads. Rejected non-candidate spatial queries become no-request/no-public-effect outcomes instead of erroneous empty-canvas requests. Unknown or already-consumed text-edit request ids remain false/no-effect. Known stale/invalid text-edit request ids remain false/no-public-effect but consume live guard facts privately. Accepted same-text commits still return true without document/action effects. Accepted changed-text commits still publish public state before synchronous action listeners and action listeners observe the request id as no longer live.

Order Constraints:

Add or update focused failing tests before production acceptance for each behavior seam: non-candidate no-request and valid empty-canvas control before context outcome migration; registry consume/remove and failed-prepare-live tests before registry replacement; async timing and dispose-after-add tests before stream contract docs; guardrail negative fixtures before scanner rewrites; guardrail pattern/source-of-truth entries before the immutable read-fact scanner rewrite is considered complete; general docs/diagram/source-truth updates after behavior and guardrail semantics land. Introduce the context target outcome before changing request issue sites. Migrate direct and pointer routes before relying on docs changes. Migrate registry consumption before updating text-edit guardrail sequence expectations. Repair generated docs/indexes after source docs/registry edits. Do not mark execution units complete until implementation, focused verification, review, and commit evidence exist.

Temporal Surface Closure:

Context request invariant: candidate-admitted context targets are the only target reads that may reserve a timestamp, issue a request id, build a public request, or call the runtime stream add. Context request listeners observe accepted requests asynchronously after the initiating `handleDoubleTap` or pointer admission returns; rejected target reads return with no stream event, no timestamp, no public state/action/repaint/effect, and no registry id. Dispose after accepted stream add must deliver the queued request before done for subscribed listeners. Text-edit invariant: synchronous action listeners during changed-text delivery observe the request id as already consumed. Runtime mutation guards remain the rejection signal for reentrant/interleaved mutation attempts during synchronous edit delivery.

All-Or-Nothing Failure Boundary:

For context requests, spatial query and target admission are fallible and occur before timestamp reservation, registry issuance, request construction, and stream add. Once the runtime stream add is reached for an admitted target, request delivery is accepted and close must preserve the queued event for subscribed listeners. Failure before stream add projects as no request, no timestamp, no diagnostics for invalid-index, bounded diagnostics for stale/budget, and no public effects. For changed text, input validation, guard lookup, stale classification, current target read, and edit prepare are fallible before request consumption; consume/remove happens only after successful prepare and before public delivery. Failed prepare projects as false/no public effects with the request still live.

## Execution Units

### [ ] Unit 1: Context Target Outcome And Issue Admission

Owner:

`lib/src/interaction/interaction_read_port.dart`, `lib/src/runtime/runtime_interaction_read_adapter.dart`, `lib/src/interaction/interaction_engine.dart`, `lib/src/interaction/context_action_router.dart`, `lib/src/interaction/interaction_request_registry.dart`, `test/interaction/context_action_request_test.dart`, `test/interaction/eraser_context_action_routing_test.dart`, `test/diagnostics/interaction_diagnostics_test.dart`, `test/diagnostics/fixtures/interaction_diagnostics_fixture.dart`.

Boundary:

Context target admission and request issuance only. Do not change public request payload shapes, text-edit consumption, stream controller type, docs, or guardrail scanners in this unit.

Change:

Add an internal admitted/rejected context target outcome or equivalently named cohesive seam at the interaction read boundary. Admit only `InteractionReadQueryStatus.candidates`; admitted content and admitted empty-canvas targets carry the existing target facts. Reject invalid-index, stale-index, and budget-exceeded results without constructing public targets. Migrate direct `handleDoubleTap` and pointer-sample context recognition so timestamp reservation, registry issuance, router request construction, and stream intents happen only after admitted target outcome. Keep rejected first-tap and rejected second-tap pointer state behavior explicit, including cleanup of stale pending context tap state without request issuance. Record bounded diagnostics for stale/budget rejected context reads and no diagnostics for invalid-index rejected reads.

Completion Check:

`test/interaction/context_action_request_test.dart` and pointer routing fixtures prove invalid-index, stale-index, and budget-exceeded target reads produce no request id, no registry live facts, no public request after `Future<void>.delayed(Duration.zero)`, no runtime timestamp reservation, and no state/action/repaint/effects. `test/diagnostics/interaction_diagnostics_test.dart` through `test/diagnostics/fixtures/interaction_diagnostics_fixture.dart`, or an explicitly named context-action diagnostics fixture under the same diagnostics owner, proves stale and budget rejected target reads emit bounded interaction diagnostics while invalid-index emits none. A separate valid candidate/no-hit test proves one empty-canvas request still emits with the existing public payload shape. Pointer tests prove rejected first tap stores no pending context tap, rejected second tap clears any existing pending tap without request issuance, and admitted pointer/direct targets still issue exactly once. `test/smoke/public_incremental_smoke_test.dart` continues to observe admitted content and empty-canvas context requests through the public barrel without new public target variants or payload fields.

Depends On:

None.

### [ ] Unit 2: Request Registry Consumption And Text Commit Sequencing

Owner:

`lib/src/interaction/interaction_request_registry.dart`, `lib/src/interaction/interaction_engine.dart`, `lib/src/runtime/runtime_root.dart`, `test/interaction/text_edit_stale_commit_guard_test.dart`, `test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart`, `test/api/typed_action_payloads_test.dart`, `test/api/fixtures/typed_action_payloads_runtime_fixture.dart`, `test/runtime/load_interaction_cleanup_test.dart`, `test/runtime/fixtures/load_interaction_cleanup_fixture.dart`.

Boundary:

Request validity and guarded text commit lifecycle only. Do not alter context target admission beyond consuming the admitted facts produced by Unit 1. Do not add app/editor session state or documentRevision stale guards.

Change:

Replace permanent retired-fact retention with live fact consume/remove semantics. Unknown or already-consumed ids remain pure false/no-effect. Known live empty-canvas, non-text, stale, missing, epoch/generation/elementRevision/family-mismatched ids are consumed and return false without public effects. Accepted same-text requests are consumed and return true without document/action effects. Changed-text accepted requests consume only after successful `EditKernel.prepareInteractionCommit` and before `_deliverEditCommitResult`; failed prepare returns false, emits no public effects, and leaves the request live. Successful document load and dispose clear remaining live request facts.

Completion Check:

Focused text guard and runtime tests prove accepted no-op, successful accepted changed, known stale rejected, non-text/empty rejected, unknown, and already-consumed request ids have the documented return values and public no-effect behavior. Live-fact probes assert consumed ids are absent rather than retained retired facts, repeated commits are unknown/consumed no-ops, failed changed-text prepare leaves the request live, and successful load/dispose clears live facts. Delivery-order proof asserts action listeners during changed-text delivery observe the request id as already not live, while the edit still uses the existing `EditKernel` path and public payload shape. `test/api/typed_action_payloads_test.dart`, `test/api/fixtures/typed_action_payloads_runtime_fixture.dart`, and `test/smoke/public_incremental_smoke_test.dart` prove changed-text public action/request payload compatibility through existing public command and request types with no raw text or signature changes.

Depends On:

Unit 1 for admitted-only issued request facts.

### [ ] Unit 3: Async Context Request Stream Contract

Owner:

`lib/src/runtime/runtime_root.dart`, `test/interaction/context_action_request_test.dart`, `test/interaction/fixtures/context_action_request_fixture.dart`, `test/runtime/load_interaction_cleanup_test.dart`, `test/runtime/fixtures/load_interaction_cleanup_fixture.dart`, public API context request coverage in `test/smoke/public_incremental_smoke_test.dart`.

Boundary:

Context request stream timing and closure only. Do not change action stream sync behavior, request payload fields, registry state ownership, or context target admission policy in this unit.

Change:

Make the existing asynchronous broadcast context request delivery a tested contract. Preserve action stream synchronous delivery separately. Add lifecycle proof that an accepted request queued before dispose is delivered before done for subscribed listeners, and that rejected target reads never enqueue stream events. If the current default broadcast controller cannot preserve request-before-done for dispose-after-add, add the smallest `RuntimeRoot`-owned asynchronous delivery queue needed to preserve queued accepted requests while keeping public request listener delivery asynchronous.

Completion Check:

A timing test subscribes to `contextActionRequests`, invokes accepted direct and/or pointer context request issuance, asserts the listener has not run before the initiating method returns, then observes the request after an event-loop flush. A dispose-after-add test with an active subscription invokes an accepted request and immediately disposes, then asserts request-before-done order. Existing action delivery tests continue to prove synchronous action listeners where relevant, so the stream timing difference is intentional and documented. `test/smoke/public_incremental_smoke_test.dart` preserves root-barrel public context request observation with existing public request types and no new public payload variants.

Depends On:

Unit 1 for admitted/rejected request issuance behavior.

### [ ] Unit 4: Guardrail Semantic Sequence And Immutable Read-Fact Enforcement

Owner:

`tool/guardrails/src/interaction_guardrail_checks.dart`, guardrail runner registry/executor surfaces if the rule inventory changes, `test/guardrails/interaction_guardrail_enforcement_test.dart`, `docs/verification/guardrail_design_patterns.md`, `docs/verification/guardrails.md`, `docs/_registry/sections.yaml` when registry entries need updates.

Boundary:

Executable guardrail enforcement and its source-of-truth pattern entries only. Do not encode fixture-only classes or synthetic names into production source-of-truth files, public API registries, generated docs, or runtime code.

Change:

Rewrite `interaction.text_edit_stale_commit_guard` away from string marker indexes to semantic events over the parsed `commitTextEdit` method and its control-flow-sensitive branches. The rule must prove validation before guard read, guard decision before target/current-text reads, accepted branch gates all prepare paths, rejected/unknown branches cannot reach `_editKernel.prepareInteractionCommit`, changed-text prepare succeeds before request consumption, and consumption occurs before public delivery. Before the immutable read-fact scanner rewrite is complete, update the guardrail source-of-truth entries that own the selected pattern, including `docs/verification/guardrail_design_patterns.md`; update the stale `docs/verification/guardrails.md` row for `interaction.text_edit_stale_commit_guard` from retired/already-retired wording to consume/remove semantics; update `docs/_registry/sections.yaml` if registry entries change. Then rewrite `interaction.read_port_immutable_facts` so copied-field obligations are derived from read-port constructor/field shape where possible and include P12 eraser iterable/list fields plus future matching copied fields.

Completion Check:

`docs/verification/guardrail_design_patterns.md` contains the selected pattern/source entry for `interaction.read_port_immutable_facts`; `docs/verification/guardrails.md` updates the `interaction.text_edit_stale_commit_guard` row to consume/remove semantics and no longer describes retained retired/already-retired registry facts as current behavior; and any stale owning guardrail registry rows are updated before the scanner rewrite is accepted. `test/guardrails/interaction_guardrail_enforcement_test.dart` includes negative fixtures that keep the old marker strings but let rejected/unknown branches reach prepare, consume changed-text requests before successful prepare, deliver before consumption, or bypass guard facts; each fixture fails under `dart run tool/guardrails/run.dart` or the focused guardrail test. Immutable read-fact negative fixtures remove `List.unmodifiable` from eraser request corridor, eraser facts corridor, and eraser erased ids, and add a synthetic iterable/list copied-field fixture; each fixture fails without adding fixture-only obligations to production source files. Positive guardrail tests prove production `runtime_root.dart` and `interaction_read_port.dart` pass.

Depends On:

Unit 2 for final text-edit consume/remove sequencing.

### [ ] Unit 5: Source-Of-Truth And Generated Documentation Repair

Owner:

`docs/contracts/interaction_engine.md`, `docs/contracts/operation_matrix.md`, `docs/contracts/public_api_v1.md`, `docs/verification/tests.md`, `docs/verification/guardrails.md`, `docs/verification/guardrail_design_patterns.md`, `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/architecture_graph.yaml`, `docs/diagrams/seq_context_action_request.mmd`, `docs/diagrams/state_pending_context_action_request.mmd`, `docs/_registry/sections.yaml`, mechanically generated indexes/diagrams touched by docs tooling, `PLAN.md`, this step file.

Boundary:

General P12 behavior source-of-truth repair only after implemented behavior and guardrails are in place. The guardrail pattern/source entries required to complete the immutable read-fact scanner belong to Unit 4, not this unit. Do not use prose to claim behavior that lacks the focused tests and guardrails from Units 1 through 4.

Change:

Update current P12 docs to state accepted content/empty targets emit asynchronous stream requests, rejected invalid/stale/budget context target reads emit no public request, stale and budget rejected reads record bounded interaction diagnostics, invalid-index rejected reads record none, request registry facts are live and consumed/removed rather than permanently retired, and public API shapes remain unchanged. Preserve P10 unsupported/empty-stream statements only as historical phase context. Update diagrams, architecture docs, registries, and architecture graph YAML only where their owned wording or structured source entries change. Regenerate generated docs/indexes/views required by changed owning docs, registries, diagrams, or graph sources. After implementation evidence exists, update this step and `PLAN.md` checkboxes in the same change.

Completion Check:

`dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` pass after generated updates. Semantic searches for stale current-P12 wording show no remaining claims that P12 double tap is unsupported/currently empty or that registry retired facts are durable state; any remaining P10 statements are clearly historical. If architecture graph, architecture docs, generated graph views, or durable diagrams change, `dart run tool/architecture_graph/check.dart --phase P12` and `dart run tool/architecture_graph/generate_views.dart --phase P12 --check` pass. This step file and `PLAN.md` are marked complete only with implementation evidence from the later workflow.

`test/smoke/public_incremental_smoke_test.dart` and `test/api_contract/public_api_v1_compiles_as_written_test.dart` remain green after source-truth repair, proving the public P12 request and command surfaces still compile through the public barrel without new public target variants, request id types, context request payload fields, or command signatures.

Depends On:

Units 1, 2, 3, and 4.

## Required Verification Commands

Run after the implementation units and source-truth repairs land:

- `dart analyze`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/interaction`
- `dcm calculate-metrics lib/src/runtime`
- `dcm calculate-metrics test/interaction`
- `dcm calculate-metrics test/runtime`
- `dcm calculate-metrics test/diagnostics`
- `dcm calculate-metrics test/api`
- `dcm calculate-metrics test/smoke`
- `dcm calculate-metrics test/guardrails`
- `dcm calculate-metrics tool/guardrails`
- Focused tests named by the changed units, including `dart test test/interaction/context_action_request_test.dart test/interaction/text_edit_stale_commit_guard_test.dart test/diagnostics/interaction_diagnostics_test.dart test/api/typed_action_payloads_test.dart test/smoke/public_incremental_smoke_test.dart test/api_contract/public_api_v1_compiles_as_written_test.dart`
- `dart run tool/guardrails/run.dart`
- `dart run docs/tool/sync_generated_docs.dart --check`
- `dart run docs/tool/check_docs.dart`
- If architecture graph, architecture docs, generated graph views, or durable diagrams change: `dart run tool/architecture_graph/check.dart --phase P12`
- If architecture graph, architecture docs, generated graph views, or durable diagrams change: `dart run tool/architecture_graph/generate_views.dart --phase P12 --check`
