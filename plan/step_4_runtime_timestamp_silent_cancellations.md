# Change Contract

## Goal

Runtime outputs that are suppressed or cancelled before public delivery must not
consume the runtime timestamp cursor. Because this package has no external users
to preserve, selected-move resolver callbacks stop exposing a pre-accept
`timestampMs`; accepted context-action requests and accepted actions remain the
only relevant timestamped runtime outputs for this step.

## Source Inputs

- Design: none
- Research: `.research/2026-06-11-runtime-002-timestamp-cursor.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `AGENTS.md`; `docs/README.md`; `docs/contracts/public_api_v1.md`; `docs/contracts/operation_matrix.md`; `docs/contracts/interaction_engine.md`; `docs/diagrams/seq_context_action_request.mmd`; `docs/diagrams/state_pending_context_action_request.mmd`; `docs/verification/guardrails.md`; `docs/verification/guardrail_design_patterns.md`; `lib/src/contracts/public/canvas_actions.dart`; `lib/src/runtime/runtime_action_finalizer.dart`; `lib/src/runtime/runtime_root.dart`; `lib/src/interaction/interaction_engine.dart`; `lib/src/interaction/context_action_router.dart`; `lib/src/interaction/interaction_runtime_intents.dart`; `lib/src/interaction/interaction_pointer_context.dart`; `test/api_contract/public_api_v1_compiles_as_written_test.dart`; `test/api_contract/dto_immutability_test.dart`; `test/api_contract/fixtures/public_integration_compile_fixture.dart`; `test/api/runtime_timestamp_order_test.dart`; `test/api/fixtures/runtime_timestamp_order_fixture.dart`; `test/runtime/load_interaction_cleanup_test.dart`; `test/runtime/fixtures/load_interaction_cleanup_fixture.dart`; `test/interaction/context_action_request_test.dart`; `test/interaction/fixtures/context_action_request_fixture.dart`; `test/interaction/move_machine_test.dart`; `test/interaction/fixtures/move_machine_fixture.dart`; `test/smoke/public_incremental_smoke_test.dart`

## Classification

Profile: BREAKING_API_CLEANUP

Obligations: BUG_FIX; PUBLIC_API_SHAPE_CHANGE; TEMPORAL_SURFACE_CLOSURE; ALL_OR_NOTHING_FAILURE_BOUNDARY; NEGATIVE_PROOF; SOURCE_OF_TRUTH_UPDATE

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| Runtime has one CanvasRuntime-local timestamp cursor, owned by runtime timestamp finalization, and nullable host timestamps are hints. | `Boundaries.Owner`; `Boundaries.Source of Truth`; Units 1 and 2 | Units 1 and 2 keep timestamp resolution at accepted/deliverable output boundaries and preserve accepted action timestamp monotonicity |
| The package has no external users, so resolver callback timestamp compatibility is not worth preserving. | `Goal`; `Boundaries.Compatibility`; Unit 2 | Unit 2 removes `CanvasMoveCommitRequest.timestampMs` from public API/docs/tests instead of preserving any pre-accept resolver timestamp |
| Suppressed queued context-action requests are not publicly delivered and load/dispose cleanup remains timestamp-silent. | `Boundaries.Temporal Surface Closure`; `Boundaries.All-Or-Nothing Failure Boundary`; Unit 1 | Unit 1 stores timestamp hints until delivery, commits only after deliverability filtering, and proves load/dispose suppression is cursor-silent |
| Context-action request delivery is asynchronous and may be suppressed before the scheduled microtask. | `Boundaries.Temporal Surface Closure`; Unit 1 | Unit 1 pending request shape and structural source guard prove timestamp resolution happens only at stream delivery, not at request admission or discard |
| Normative interaction docs and sequence diagrams currently place context request timestamp resolution before queue delivery. | `Boundaries.Source of Truth`; Unit 1 | Unit 1 updates context-request runtime behavior and matching docs/diagrams in the same unit |
| Selected-move resolver callbacks are synchronous, but resolver cancel and zero resolved delta emit no accepted move action. | `Boundaries.Temporal Surface Closure`; Unit 2 | Unit 2 removes resolver callback timestamp publication and proves cancel/zero leave the next accepted timestamp unchanged |
| Existing accepted selected-move behavior has a resolver callback before accepted action finalization. | `Boundaries.Order Constraints`; Unit 2 | Unit 2 commits no resolver timestamp; the accepted move action resolves its timestamp after finite non-zero resolver output and before action publication |
| Public API/docs/compile fixtures currently include `CanvasMoveCommitRequest.timestampMs`. | `Boundaries.In Scope`; Unit 2 | Unit 2 updates public DTO shape, public API contract docs, API compile fixtures, DTO tests, and smoke expectations for the breaking cleanup |
| Verification guardrails currently include selected move resolver requests in the runtime-created monotonic timestamp invariant. | `Boundaries.Source of Truth`; Unit 2 | Unit 2 updates guardrails and proof patterns so resolver callbacks are not classified as committed timestamp outputs |
| Existing tests cover suppression/cancel effects but not cursor continuity after those paths. | `Boundaries.In Scope`; Units 1 and 2 | Units 1 and 2 add direct regression proof for next accepted timestamp continuity after suppression/cancel/zero |

## Evidence

- `.research/2026-06-11-runtime-002-timestamp-cursor.md:13` / research summary: `RuntimeActionFinalizer` owns one cursor and advances it for action finalization and timestamp reservations -> timestamp ownership stays in the runtime finalizer instead of downstream consumers.
- `.research/2026-06-11-runtime-002-timestamp-cursor.md:15` / research summary: context-action requests and selected-move resolver requests currently resolve timestamps before public delivery or acceptance is certain -> contract must close both temporal windows.
- `.research/2026-06-11-runtime-002-timestamp-cursor.md:17` / research summary: existing tests cover suppression/cancel effects but not next accepted timestamp after suppression/cancel -> new proof must assert cursor continuity after those paths.
- `PLAN.md:5` / plan index: each listed step has a dedicated document -> Step 4 remains the linked roadmap contract.
- `docs/README.md:25` / docs source of truth: `docs/contracts/` is normative source of truth -> public API and interaction contract changes must update the relevant contract text.
- `lib/src/contracts/public/canvas_actions.dart:225` / public DTO: `CanvasMoveCommitRequest` owns the resolver callback request shape -> removing `timestampMs` is a public API shape change owned by this DTO and its contract tests.
- `lib/src/contracts/public/canvas_actions.dart:231` / public DTO constructor: `CanvasMoveCommitRequest` currently requires `timestampMs` -> Unit 2 must update constructor call sites and compile fixtures.
- `lib/src/contracts/public/canvas_actions.dart:238` / public DTO field: `timestampMs` is currently public -> Unit 2 must remove the field and update equality/immutability/API compile tests that instantiate or read it.
- `docs/contracts/public_api_v1.md:1459` / timestamp contract: `CanvasMoveCommitRequest.timestampMs` is currently documented as a timestamped runtime output -> Unit 2 must update public docs so resolver callback requests are not timestamped outputs.
- `docs/contracts/public_api_v1.md:2595` / move resolver contract: the public API sample includes `CanvasMoveCommitRequest.timestampMs` -> Unit 2 must remove it from the normative public API contract.
- `docs/contracts/operation_matrix.md:170` / operation matrix: rows resolve timestamps through the public runtime timestamp contract before publishing timestamped action, request, preview, or resolver request outputs -> Unit 2 must remove resolver callback requests from the timestamped-output category.
- `docs/verification/guardrails.md:211` / guardrail registry: `events.runtime_created_timestamps_monotonic` includes selected move resolver requests -> Unit 2 must update the guardrail wording to committed timestamp outputs only.
- `docs/verification/guardrail_design_patterns.md:115` / guardrail proof pattern: no-output paths must not create timestamped actions or context requests -> Unit 2 must extend the pattern to resolver callbacks that no longer carry timestamp output.
- `docs/contracts/interaction_engine.md:351` / context request contract: direct double tap currently resolves timestamp before issuing request id and queueing request -> Unit 1 must update interaction docs to delivery-time timestamp resolution.
- `docs/diagrams/seq_context_action_request.mmd:53` / context request sequence: content-target path resolves timestamp before enqueue -> Unit 1 must move timestamp resolution to delivery branch.
- `docs/diagrams/seq_context_action_request.mmd:66` / context request sequence: empty-canvas path resolves timestamp before enqueue -> Unit 1 must move timestamp resolution to delivery branch.
- `docs/diagrams/state_pending_context_action_request.mmd:146` / context request state: issued request currently includes timestamp before suppression branch -> Unit 1 must distinguish unresolved queued request from delivered timestamped request.
- `lib/src/runtime/runtime_action_finalizer.dart:7` / current owner: `_timestampCursor` starts at `-1` -> final verification must prove first accepted null/backwards hint behavior remains unchanged.
- `lib/src/runtime/runtime_action_finalizer.dart:14` / current API: `reserveTimestamp` immediately delegates to `_resolveTimestamp` -> runtime call sites must call it only at accepted/deliverable output boundaries.
- `lib/src/runtime/runtime_action_finalizer.dart:23` / action finalization: accepted actions resolve timestamps during finalization -> accepted actions remain the finalizer-owned committed timestamp path.
- `lib/src/runtime/runtime_root.dart:1818` / context queue: `_emitContextRequest` queues requests and schedules microtask delivery -> Unit 1 delivery queue is the owner boundary for committing context request timestamps.
- `lib/src/runtime/runtime_root.dart:1835` / suppression: `_suppressPendingContextRequests` increments generation and clears pending requests -> Unit 1 suppression must discard unresolved timestamp hints.
- `lib/src/runtime/runtime_root.dart:1864` / selected move path: resolver timestamp is reserved before resolver callback -> Unit 2 must remove this eager reservation.
- `lib/src/runtime/runtime_root.dart:1910` / resolver request construction: `CanvasMoveCommitRequest` is built before resolver outcome is known -> Unit 2 must build this request without timestamp output.
- `lib/src/runtime/runtime_root.dart:1953` / accepted move action: move action uses `timestampHintMs` when the commit is prepared -> Unit 2 must pass the original terminal timestamp hint to accepted action finalization instead of a resolver-request timestamp.
- `test/api_contract/public_api_v1_compiles_as_written_test.dart:480` / public API compile fixture: compile proof constructs `CanvasMoveCommitRequest` with `timestampMs` -> Unit 2 must update API compile proof.
- `test/api_contract/dto_immutability_test.dart:130` / DTO contract proof: immutability proof constructs `CanvasMoveCommitRequest` with `timestampMs` -> Unit 2 must update public DTO tests.
- `test/api_contract/fixtures/public_integration_compile_fixture.dart:192` / integration compile fixture: public integration reads `request.timestampMs` -> Unit 2 must remove that public read.
- `test/interaction/fixtures/move_machine_fixture.dart:919` / accepted resolver proof: resolver request timestamp is asserted as `0` -> Unit 2 must replace this with no timestamp field and action timestamp proof.
- `test/interaction/fixtures/move_machine_fixture.dart:954` / accepted action proof: accepted move action timestamp is asserted as `1` after resolver request `0` -> Unit 2 must update accepted action expectation to the accepted action's own resolved timestamp.
- `test/interaction/fixtures/move_machine_fixture.dart:1155` / edit-failure proof: existing selected move edit-failure fixture uses finite large delta `Offset(1e8, 0)` to trigger `_prepareSelectedMoveCommit` failure after the resolver returns -> Unit 2 must extend this existing fixture mechanism with next accepted timestamp proof instead of adding a new testing hook.
- `test/smoke/public_incremental_smoke_test.dart:653` / public smoke proof: resolver request currently receives timestamp `21` -> Unit 2 must remove this expectation.
- `test/smoke/public_incremental_smoke_test.dart:664` / public smoke proof: accepted move action currently receives timestamp `22` after resolver request `21` -> Unit 2 must update smoke proof to the accepted action timestamp resolved from the pointer-up hint, expected `21`.

## Boundaries

Owner: `RuntimeActionFinalizer` owns committed runtime timestamp cursor state. `RuntimeRoot` owns runtime output delivery boundaries: pending context request delivery/suppression and selected-move resolver acceptance/cancel. `CanvasMoveCommitRequest` owns the resolver callback DTO shape. `InteractionEngine` may pass timestamp hints or request builders but must not own the cursor.

In Scope:

- Remove `timestampMs` from `CanvasMoveCommitRequest` and all public API/docs/tests that construct or read it.
- Keep selected-move resolver callbacks synchronous and keep all non-timestamp request facts (`documentSummary`, `movedElements`, `proposedDelta`, `selectionBoundsWorld`).
- Stop reserving a timestamp before selected-move resolver callbacks.
- Resolve the accepted selected-move action timestamp only after the resolver returns a finite non-zero delta and the action is finalized.
- Defer context-action request timestamp resolution until queued requests are deliverable and immediately before adding `CanvasContextActionRequested` to `contextActionRequests`.
- Ensure load/dispose cleanup of queued context requests discards unresolved timestamp hints and does not advance the cursor.
- Update public timestamp docs, operation matrix, interaction docs/diagrams, verification guardrails, and proof patterns in the same units as the behavior they describe.
- Add focused regression tests for cursor continuity after suppressed queued context requests, resolver cancel, resolver zero delta, resolver exception, and selected-move edit-preparation failure.

Out of Scope:

- Preserving source compatibility for `CanvasMoveCommitRequest.timestampMs`.
- Changing timestamp semantics for accepted actions, accepted context-action request delivery, pending line previews, document revisions, selection revisions, or schema data.
- Changing non-timestamp fields on `CanvasMoveCommitRequest`.
- Reworking interaction target admission, spatial reads, context request guard facts, selected-move commit math, move resolver callback synchrony, or edit/store commit behavior.
- Adding durable timestamp state to documents, schemas, resources, selection state, preview revisions, or any source outside the runtime-local finalizer.
- Reordering public context request delivery relative to the existing scheduled microtask beyond resolving timestamp at delivery time.

Source of Truth: `docs/contracts/public_api_v1.md` owns the public `CanvasMoveCommitRequest` shape and public timestamp semantics. `docs/contracts/operation_matrix.md`, `docs/verification/guardrails.md`, and `docs/verification/guardrail_design_patterns.md` own repository verification wording for timestamped outputs and no-output proof patterns. `RuntimeActionFinalizer` implements the single runtime-local committed cursor. `RuntimeRoot` owns the commit/discard boundary for runtime outputs that may be suppressed or cancelled. No new durable source of truth for timestamp state may be introduced.

`docs/contracts/interaction_engine.md`, `docs/diagrams/seq_context_action_request.mmd`, and `docs/diagrams/state_pending_context_action_request.mmd` own interaction-flow order and must be updated with the same delivery-time timestamp boundary as the implementation.

Compatibility: This is an intentional breaking API cleanup for `CanvasMoveCommitRequest.timestampMs`. Accepted action timestamp monotonicity, accepted context-action request delivery, resolver callback synchrony, request guard cleanup, and load/dispose suppression behavior must remain compatible. Existing public signatures and DTO fields outside `CanvasMoveCommitRequest.timestampMs` must remain unchanged.

Order Constraints:

1. Migrate context-action request timestamp timing and update matching interaction contract/diagrams in the same execution unit.
2. Remove selected-move resolver callback timestamp publication and update public API/docs/guardrails/tests in the same execution unit.
3. Preserve accepted-path timestamp tests while adding suppressed/cancelled continuity tests.
4. After Unit 2, run focused API/runtime/interaction/smoke tests, docs checks, architecture diagram generation checks, and repository verification for all changed owners as part of Unit 2 completion.

Temporal Surface Closure:

- Context request admission may run synchronously from `RuntimeRoot.handleDoubleTap` and pointer handling, but `CanvasContextActionRequested.timestampMs` must be resolved only inside the scheduled delivery boundary after closed-stream and generation discard filtering have selected an already-deliverable pending payload, immediately before adding the request to `_contextActionRequests`. If load or dispose cleanup runs before that microtask, `_suppressPendingContextRequests` and closed-stream/generation filtering are discard boundaries and no timestamp cursor change is allowed.
- Selected-move resolver callback remains synchronous but is no longer a timestamped runtime output. `CanvasMoveCommitRequest` must be built without reserving or exposing a timestamp. `CanvasMoveCancel`, resolver-returned zero delta, and resolver exceptions therefore cannot consume cursor state. A finite non-zero resolver result only permits the later accepted move action to resolve its own timestamp during action finalization.
- Accepted actions still commit timestamps at action finalization. For accepted selected moves, the move action uses the original terminal timestamp hint, so the public smoke path with pointer-up hint `21` resolves the accepted move action to `21` rather than spending `21` on the resolver callback and `22` on the action.

All-Or-Nothing Failure Boundary:

- Context request delivery irreversible point: adding `CanvasContextActionRequested` to `_contextActionRequests`. Fallible or suppressible work before that point includes target admission, request fact registration, queued microtask delay, load cleanup, dispose cleanup, closed-stream handling, and generation filtering. Timestamp commit for context requests must occur only for pending payloads that have already passed closed-stream and generation filtering, immediately before building and adding the public request. If load/dispose suppression, stream close, or generation mismatch happens first, the failure projection is no public request and no finalizer cursor advancement. Direct proof must fail if request admission, pending storage, suppression, closed-stream handling, or generation-filter discard paths resolve or commit the timestamp.
- Selected-move resolver irreversible point for timestamps is accepted move action finalization, not resolver callback entry. Fallible work before that point includes resolver callback execution, finite/non-zero delta validation, and selected-move edit preparation. If the resolver cancels, returns zero delta, throws, or edit preparation fails, the failure projection is cleanup/no accepted move action and no cursor advancement from selected-move resolver handling. Direct proof must fail if any of those pre-action paths consumes a timestamp.

## Execution Units

### [ ] Unit 1: Make Suppressed Context Requests Timestamp-Silent

Owner: `RuntimeRoot` context request delivery boundary, with `InteractionEngine` request intent shape and matching interaction source-of-truth docs/diagrams only as needed to stop eager timestamp resolution for context-action requests.

Boundary: `lib/src/runtime/runtime_root.dart`, `lib/src/interaction/interaction_engine.dart`, `lib/src/interaction/context_action_router.dart`, `lib/src/interaction/interaction_runtime_intents.dart`, `lib/src/interaction/interaction_pointer_context.dart`, `docs/contracts/interaction_engine.md`, `docs/diagrams/seq_context_action_request.mmd`, `docs/diagrams/state_pending_context_action_request.mmd`, `test/runtime/fixtures/load_interaction_cleanup_fixture.dart`, `test/interaction/fixtures/context_action_request_fixture.dart`, and new focused structural source guard test `test/runtime/context_request_timestamp_placement_test.dart`.

Change: Change context-action request construction so direct and pointer context-action requests carry an internal pending request payload with the original timestamp hint and all non-timestamp request facts until `_emitContextRequest` delivery time. Resolve and commit the request timestamp only for entries that `_takeDeliverablePendingContextRequests` will deliver to `_contextActionRequests`, then build the public `CanvasContextActionRequested` immediately before `_contextActionRequests.add`. Load/dispose cleanup through `_suppressPendingContextRequests` must discard queued work before timestamp resolution. Update the interaction contract and context-action request diagrams in the same unit so they describe delivery-time timestamp resolution and timestamp-silent suppression. Pointer line preview timestamp behavior remains outside this migration.

Completion Check: Focused tests cover both direct double-tap and pointer-sample context-action request flows: an accepted delivered request with null/backwards/forward hints receives runtime-local monotonic `CanvasContextActionRequested.timestampMs`; a queued request suppressed by successful `loadDocumentFromJson` emits no request and the next accepted timestamped output resolves as if the suppressed request never existed. Dispose suppression uses `test/runtime/context_request_timestamp_placement_test.dart`: the test reads the bounded production sources for `InteractionEngine.handleDoubleTap`, pointer context request admission, pending request storage, `_suppressPendingContextRequests`, `_takeDeliverablePendingContextRequests`, and `_emitContextRequest`; fails if context request admission, pending storage, suppression, closed-stream handling, or generation-filter discard paths contain context-request timestamp resolve/commit calls; and requires the finalizer-owned timestamp commit to occur only for already-deliverable pending payloads after closed-stream/generation filtering and immediately before building/adding `CanvasContextActionRequested` to `_contextActionRequests`. Existing assertions that load/dispose clear live request facts, suppress queued requests, and close the stream must still pass. Unit 1 verification runs focused test entrypoints `test/runtime/load_interaction_cleanup_test.dart`, `test/interaction/context_action_request_test.dart`, and `test/runtime/context_request_timestamp_placement_test.dart`; runs `dart analyze`; runs `dcm analyze .`; runs `dcm calculate-metrics` for changed production/test scopes including `lib/src/runtime`, `lib/src/interaction`, `test/runtime`, and `test/interaction`; and runs `dart run docs/tool/sync_generated_docs.dart --check`, `dart run docs/tool/check_docs.dart`, `dart run tool/architecture_graph/check.dart`, and `dart run tool/architecture_graph/generate_views.dart --check` after the docs/diagram update.

Depends On: none.

### [ ] Unit 2: Remove Resolver Callback Timestamp Output

Owner: `CanvasMoveCommitRequest` public DTO shape and `RuntimeRoot` selected-move resolver boundary.

Boundary: `lib/src/contracts/public/canvas_actions.dart`, `lib/src/runtime/runtime_root.dart`, `docs/contracts/public_api_v1.md`, `docs/contracts/operation_matrix.md`, `docs/verification/guardrails.md`, `docs/verification/guardrail_design_patterns.md`, `test/api_contract/public_api_v1_compiles_as_written_test.dart`, `test/api_contract/dto_immutability_test.dart`, `test/api_contract/fixtures/public_integration_compile_fixture.dart`, selected-move resolver tests in `test/interaction/fixtures/move_machine_fixture.dart`, and accepted resolver smoke verification in `test/smoke/public_incremental_smoke_test.dart`.

Change: Remove `timestampMs` from `CanvasMoveCommitRequest`, its constructor, docs, compile fixtures, and public DTO tests. Stop calling `_actionFinalizer.reserveTimestamp` before selected-move resolver callbacks. Pass the original terminal timestamp hint through to accepted move action finalization only after the resolver returns a finite non-zero delta and edit preparation succeeds far enough to create an accepted action. Update public timestamp docs, operation matrix, and verification guardrails so selected-move resolver callbacks are not timestamped runtime outputs.

Completion Check: Focused selected-move tests prove `CanvasMoveCancel`, resolver-returned zero delta, resolver exception, and selected-move edit-preparation failure leave `scenario.actions` empty, clear preview, expose no `timestampMs` on `CanvasMoveCommitRequest`, and make the next accepted timestamped action/request resolve as if the failed resolver path never existed. The edit-preparation failure proof must extend the existing `selected move edit failure cleans preview and rethrows` fixture by keeping its finite large delta `CanvasMoveCommit(delta: Offset(1e8, 0))` failure path and adding next accepted timestamp continuity assertions; do not add a new testing hook for this proof. Accepted resolver tests continue to assert the accepted move action timestamp is monotonic with surrounding accepted outputs. The public smoke accepted resolver proof must update from `21 -> 22` to accepted action `timestampMs == 21` because the resolver callback no longer consumes `21`. Public API compile, immutability, equality, and integration fixtures must compile without `CanvasMoveCommitRequest.timestampMs`. `docs/contracts/public_api_v1.md`, `docs/contracts/operation_matrix.md`, `docs/verification/guardrails.md`, and `docs/verification/guardrail_design_patterns.md` no longer state or imply that selected-move resolver callback requests are timestamped runtime outputs. Final Unit 2 verification runs focused test entrypoints `test/api_contract/public_api_v1_compiles_as_written_test.dart`, `test/api_contract/dto_immutability_test.dart`, `test/api/runtime_timestamp_order_test.dart`, `test/runtime/load_interaction_cleanup_test.dart`, `test/interaction/context_action_request_test.dart`, `test/interaction/move_machine_test.dart`, `test/smoke/public_incremental_smoke_test.dart`, and `test/runtime/context_request_timestamp_placement_test.dart`; verifies direct assertions for cursor continuity after load suppression, dispose suppression through post-filter source-placement proof, resolver cancel, resolver zero delta, resolver exception, selected-move edit-preparation failure via the finite large delta fixture path, accepted resolver action timestamp `21`, and accepted-path monotonicity; and runs `dart analyze`, `dcm analyze .`, `dcm calculate-metrics` for changed production/test owner scopes, `dart run docs/tool/sync_generated_docs.dart --check`, `dart run docs/tool/check_docs.dart`, `dart run tool/architecture_graph/check.dart`, and `dart run tool/architecture_graph/generate_views.dart --check`.

Depends On: Unit 1.
