# Change Contract

## Goal

Implement P12 eraser and context-action request behavior so public consumers can erase committed canvas elements with immutable corridor preview and atomic deletion, receive double-tap context-action requests for content or empty canvas targets, and commit request-originated text edits through guarded command semantics without adding engine-owned context menu or text editor UI.

## Source Inputs

- Design: `.design/2026-06-02-p12-eraser-and-context-action-request.md`
- Research: `.research/2026-06-02-p12-eraser-context-action-request.md`
- Phase: `docs/implementation/p12_eraser_and_text_request.md`
- PLAN: `PLAN.md`
- Other: `docs/contracts/public_api_v1.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/operation_matrix.md`, `docs/contracts/geometry.md`, `docs/contracts/diagnostics.md`, `docs/contracts/edit_kernel.md`, `docs/contracts/frame_rendering.md`, `docs/contracts/load_document.md`, `docs/diagrams/state_pending_context_action_request.mmd`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/architecture_graph.yaml`, `docs/verification/tests.md`, `docs/verification/guardrails.md`, `docs/indexes/by_guardrail.md`, `tool/guardrails/src/guardrail_registry.dart`, `tool/guardrails/src/guardrail_executor.dart`, `tool/guardrails/src/interaction_guardrail_checks.dart`, `tool/guardrails/src/selection_move_guardrail_suite.dart`, `test/guardrails/blocking_suite_test.dart`, `docs/donors/00_reuse_rules.md`, `docs/donors/07_donors_to_avoid.md`, `docs/_registry/donors.yaml`

## Classification

Profile: BEHAVIOR_CHANGE

Obligations:

- PUBLIC_API_CHANGE: existing public `CanvasToolPort.handleDoubleTap`, `CanvasCommandPort.commitTextEdit`, `CanvasRuntime.contextActionRequests`, `CanvasEraserPreview`, `CanvasEraseActionPayload`, and `CanvasTextEditActionPayload` become operational P12 behavior through the already exported public root barrel without changing public method signatures.
- SEAM_MIGRATION: retire P10 placeholder behavior for direct double tap and no-op text commit acceptance by installing the interaction-owned eraser, context router, request registry, cleanup, and edit-delivery seams instead of patching public facade methods directly.

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` P12 is one interaction-owner behavior slice, not separate eraser and text features. | `Boundaries.Owner`, `Boundaries.Order Constraints`, Units 1-6 | Focused interaction/runtime tests and final architecture graph closure prove eraser, context request, and text guard use shared interaction/runtime/edit boundaries. |
| `D2` `InteractionEngine` owns active eraser sessions, pending context tap state, preview publication, registry access, and cleanup coordinator calls. | `Boundaries.Owner`, Units 1, 2, 3, 4, 5, 6 | Interaction tests and guardrails prove active eraser session, pending context tap, preview, registry, and coordinator calls stay under `lib/src/interaction/**`. |
| `D3` Machines/router return typed cleanup requests or intents; only `InteractionEngine` calls `PointerToolCleanupCoordinator`. | `Boundaries.Order Constraints`, Units 2, 4, 6 | `interaction.pointer_cleanup_coordinator_only` and cleanup tests prove no direct coordinator call from `EraserMachine`, `ContextActionRouter`, RuntimeRoot delivery, or non-coordinator tests. |
| `D4` Add `EraserMachine` instead of using `DrawStrokeMachine` for eraser. | `Required Production Declarations`, Unit 2 | Naming/cohesion review plus machine tests prove eraser capture, preview, terminal budget, and commit decisions live in `eraser_machine.dart`. |
| `D5` Add `context_action_router.dart` and `interaction_request_registry.dart` under interaction. | `Required Production Declarations`, Units 4 and 5 | Router/registry tests and package-boundary graph checks prove selected filenames and owners; registry issuance exists before any request stream emission. |
| `D6` Eraser preview publishes immutable `CanvasEraserPreview(corridor, thickness)` and overlay-only repaint; preview refresh cannot mutate committed state. | `Boundaries.Compatibility`, Unit 2 | Preview state tests, operation matrix assertions, and P12 smoke eraser preview assertions. |
| `D7` Eraser geometry reads use `GeometryPolicy.corridorEnvelope`, `SpatialKernel.queryEraser`, and `HitTestPolicy.exactEraserHit`; no duplicate geometry constants. | `Boundaries.Source of Truth`, Units 1 and 2 | Geometry/read-port tests and semantic search prove no duplicate budget constants outside geometry policy/contract. |
| `D8` Preview budget overflow produces corridor-only preview; terminal budget overflow is cleanup/no-op with no partial erase. | `All-or-nothing constraints`, Units 2, 3, 6 | `test/geometry/eraser_exact_budget_no_partial_commit_test.dart` and guardrail `geometry.eraser_exact_budget_no_partial`. |
| `D9` Non-empty eraser terminal commits remove ids through `EditKernel` and action materializes only after atomic install. | `Temporal and all-or-nothing constraints`, Unit 3 | Runtime commit tests prove state publication before erase action and rollback/no partial mutation on failure. |
| `D10` Direct `handleDoubleTap` is host-recognized, finite-position validated, clears pending tap before target resolution, and bypasses pending first-tap requirement. | Unit 4 | Context request tests prove finite direct order and non-finite rejection before timestamp, cleanup, target read, registry issue, or stream emission. |
| `D11` Pointer-sample context recognition stores first tap privately and revalidates second tap against current facts. | Unit 4 | State-machine/context tests prove mismatch clears pending only and emits no request. |
| `D12` Context targets use visible content, topmost paint order, exact geometry, and do not require selectable; background-only coverage is empty canvas. | Unit 1 and Unit 4 | Read-port target tests and public smoke content/empty assertions. |
| `D13` Registry guard facts are id, target kind, controllerEpoch, retired status, and content id/generation/elementRevision/family; documentRevision is observation-only. | Units 4 and 5 | Context request tests prove id issuance and guard recording before stream emission; text stale guard tests prove every stale guard and unrelated document revision acceptance. |
| `D14` `commitTextEdit` validates text before retirement/draft mutation, privately retires known stale rejections, commits changed text through `EditKernel`, and retires accepted changed ids after install before public delivery. | Unit 5 | Text stale guard and typed action tests prove validation order, no raw text payload, single-use request ids, and state/action order. |
| `D15` Public smoke must append one P12 root-barrel workflow for eraser preview/commit, direct content/empty request, issued text commit, and unknown-id no-op. | Unit 7 | `test/smoke/public_incremental_smoke_test.dart` expands to P12 through the Flutter consumer harness and root package import only. |
| `D16` Load success prepared cleanup clears eraser/context state before install; load failure preserves state where required. | Unit 6 | Runtime load cleanup tests prove prepared cleanup ordering and failure preservation. |
| `D17` Source-of-truth updates include docs, diagrams, verification inventory, architecture graph, and generated graph views. | Unit 8 | P12 architecture checks, docs checks, and generated graph view checks. |
| `D18` Eraser budget exhaustion is not a DiagnosticsHub write. | Unit 6 | Diagnostics semantic search/no-allocation proof shows no `DiagnosticRecord`, no hub route, and no new diagnostics graph edge for eraser budgets. |

## Donor Handoff

Unit donor lists below inherit the exact decisions, target owners, forbidden structure, and proof obligations in this table. Donors are behavior and test inputs only; no production import from legacy runtime paths is allowed.

| Donor id | Decision | Target owner | Forbidden structure | Required proof |
|---|---|---|---|---|
| `foundation_pointer_input_contract` | `copy/adapt` | Public pointer API, `PointerSampleNormalizer`, and `InteractionEngine` pointer routing. | Legacy pointer public boundary where v1 differs. | Eraser pointer lifecycle, stale terminal, non-finite direct double tap, and root-barrel pointer smoke tests. |
| `foundation_action_event_immutability` | `adapt` | Public action/request event value types, `CommitActionIntent`, `RuntimeActionFinalizer`, and context request stream delivery. | Legacy action event public names unless already in Public API v1. | Typed erase/editText payload tests, action-after-state tests, context request immutable snapshot tests. |
| `geometry_interactive_geometry` | `copy/adapt` | Eraser geometry helpers and context target read facts. | Legacy interactive geometry shell coupled to old runtime. | Eraser corridor preview, target hit/order, background-only empty target, and no duplicate geometry constants tests. |
| `geometry_eraser_exact_hit` | `adapt` | `EraserMachine`, `RuntimeInteractionReadAdapter`, `GeometryPolicy`, `HitTestPolicy`, and `SpatialKernel` eraser query path. | Legacy eraser exact-hit owner or duplicated budget constants. | Preview budget corridor-only and terminal budget no-partial proof. |
| `interaction_pointer_session` | `adapt` | `PointerSession` eraser payload and `InteractionEngine` active session state. | Legacy session shell, callback graph, or context pending tap stored as active pointer session. | Active eraser session lifecycle, cleanup, dispose, load, stale token/epoch tests. |
| `interaction_pointer_normalizer` | `copy/adapt` | Existing `PointerSampleNormalizer` and runtime direct double-tap camera offset conversion. | Wrong token/session keying or legacy normalizer ownership. | Pointer-sample eraser/context world-position tests and direct double-tap finite view/world assertions. |
| `interaction_event_dispatcher` | `adapt` | Runtime context request stream, action stream, timestamp resolver, and state-before-action ordering. | Legacy dispatcher callback order or public names outside v1. | Exactly-one request event, timestamp silence on rejected paths, state-before-action delivery. |
| `interaction_double_tap_router` | `adapt` | `ContextActionRouter` and pending context tap state machine. | Legacy router shell, UI/menu ownership, or direct runtime target resolution. | Direct content/empty, non-finite rejection, pending cleanup-before-target, and pointer-sample revalidation tests. |
| `interaction_gesture_runtime` | `adapt` | `InteractionEngine` routing, cleanup request orchestration, and RuntimeRoot delivery order. | Whole `interactive_runtime.dart`, legacy callback graph, direct cleanup coordinator calls. | Eraser/context cleanup, reentrant mutation guard, stale terminal, load/dispose cleanup, action/request ordering tests. |
| `interaction_draw_coordinator` | `adapt/rewrite` | `EraserMachine` as sibling to draw/line machines and shared draw-mode admission. | Eraser through `DrawStrokeMachine`, legacy draw coordinator shell, direct mutation callbacks. | Naming/cohesion review plus eraser machine tests proving separate eraser capture and budget decisions. |
| `interaction_mutation_boundary` | `adapt` | RuntimeRoot eraser/text delivery through `EditKernel.prepareInteractionCommit`. | Legacy bridge names, direct store/controller writes, request validity derived from public event payloads. | Erase/text rollback tests, state-before-action tests, and registry single-source guard proof. |

Forbidden donor structure for P12 is fixed: do not copy `avoid_scene_controller_facades`, `avoid_interactive_runtime_whole`, `avoid_scene_builder_public_architecture`, `avoid_scene_codec_whole`, or `avoid_scene_store_controller_whole`.

## Evidence

- `.design/2026-06-02-p12-eraser-and-context-action-request.md:13` / design disposition: P12 is `READY_FOR_CONTRACT` with no open decisions -> write a full contract rather than a blocker.
- `.design/2026-06-02-p12-eraser-and-context-action-request.md:27` / classification: the design selects `BEHAVIOR_CHANGE` with `PUBLIC_API_CHANGE` and `SEAM_MIGRATION` -> contract must include public compatibility and seam retirement proof.
- `.design/2026-06-02-p12-eraser-and-context-action-request.md:227` / selected form: Candidate A is selected -> implementation must extend existing interaction owners with focused P12 collaborators.
- `.design/2026-06-02-p12-eraser-and-context-action-request.md:231` / selected owner: `InteractionEngine` remains the active interaction state, pending context tap, preview, registry, and cleanup caller owner -> execution units must keep state and cleanup in interaction.
- `.design/2026-06-02-p12-eraser-and-context-action-request.md:232` / eraser file handoff: `eraser_machine.dart` owns eraser capture, preview, terminal target, budget, and commit-intent decisions -> Unit 2 must not use `DrawStrokeMachine` for eraser.
- `.design/2026-06-02-p12-eraser-and-context-action-request.md:233` / router file handoff: `context_action_router.dart` name and owner are locked -> Unit 4 must use that interaction owner unless the package-boundary source is changed first.
- `.design/2026-06-02-p12-eraser-and-context-action-request.md:234` / registry file handoff: `interaction_request_registry.dart` owns issued request ids and guard facts -> Unit 5 must not derive validity from public event payloads.
- `.design/2026-06-02-p12-eraser-and-context-action-request.md:237` / interaction admission handoff: `InteractionPointerAdmission` carries eraser commit and context request intents to RuntimeRoot -> Units 2 and 4 must extend the existing interaction-to-runtime return seam.
- `.design/2026-06-02-p12-eraser-and-context-action-request.md:535` / smoke handoff: public smoke must append a P12 root-barrel workflow -> Unit 7 requires `test/smoke/public_incremental_smoke_test.dart` expansion to P12.
- `.design/2026-06-02-p12-eraser-and-context-action-request.md:522` / verification handoff: P12 proof files include exact geometry, action payload, preview, context request, text guard, cleanup, load, selection, guardrail, and smoke tests -> execution units and verification commands must name the exact files rather than only test categories.
- `.design/2026-06-02-p12-eraser-and-context-action-request.md:577` / change-contract handoff: D1 through D18, profile, obligations, proof surfaces, and constraints are locked -> Decision Trace maps every design decision to units and checks.
- `docs/implementation/p12_eraser_and_text_request.md:11` / phase scope: P12 names eraser state machine, preview, exact hit, edit-kernel commit, budget behavior, erase action, context router, request id, guarded text commit, cleanup, and stale terminal rejection -> execution units must cover each named surface.
- `docs/implementation/p12_eraser_and_text_request.md:28` / cleanup seam: eraser/context machines may create typed cleanup requests but must not call `PointerToolCleanupCoordinator` directly -> Units 2, 4, and 6 need cleanup ownership proof.
- `docs/implementation/p12_eraser_and_text_request.md:52` / required donors: P12 lists exact donors and decisions -> this contract preserves donor lists globally and per unit.
- `docs/implementation/p12_eraser_and_text_request.md:66` / forbidden donors: scene controller, whole runtime, scene builder, scene codec, and scene store controller structures are forbidden -> guardrail/source search must prove they are not copied.
- `docs/implementation/p12_eraser_and_text_request.md:97` / proof inventory: P12 lists focused tests and guardrails -> completion checks must name direct proof surfaces instead of vague verification.
- `docs/implementation/p12_eraser_and_text_request.md:118` / exit gate: eraser preview, commit, double tap, text commit, stale terminal, and load cleanup behaviors define phase closure -> units must include those exit signals.
- `docs/contracts/interaction_engine.md:141` / cleanup rule: cleanup-capable machines return typed cleanup requests and `InteractionEngine` is the only coordinator caller -> owner boundary excludes direct coordinator calls.
- `docs/contracts/interaction_engine.md:144` / read boundary: committed facts for gesture decisions use narrow read-only interaction query ports -> Unit 1 must extend `InteractionReadPort`, not expose store internals.
- `docs/contracts/interaction_engine.md:244` / preview owner: `InteractionEngine` is the only producer of public preview variants -> eraser preview publication belongs in interaction.
- `docs/contracts/interaction_engine.md:279` / direct double tap: valid direct route resolves timestamp, clears pending tap, resolves target, issues id, records registry facts, and emits one request; non-finite rejects before target resolution/emission -> Unit 4 order is fixed.
- `docs/contracts/interaction_engine.md:304` / registry facts: registry records id, target kind, controllerEpoch, retired status, and content target facts -> Unit 5 registry schema and guards are fixed.
- `docs/contracts/interaction_engine.md:321` / text commit semantics: request-originated text changes commit through `commitTextEdit` and accept only current unretired text content requests after P12 -> Unit 5 owns guarded command acceptance.
- `docs/contracts/geometry.md:157` / eraser policy: eraser corridor, inflated envelope, exact segment-to-family checks, deletable-only content, and no background erase are geometry-owned -> Units 1 and 2 must reuse geometry/spatial policies.
- `docs/contracts/geometry.md:167` / budget policy: preview and terminal exact-check limits and no-partial terminal cleanup are fixed -> Units 2 and 3 must prove no partial erase.
- `docs/contracts/diagnostics.md:92` / diagnostics routing: eraser budget exhaustion is not a DiagnosticsHub write and allocates no `DiagnosticRecord` -> Unit 6 must include no-allocation/no-route proof.
- `docs/contracts/edit_kernel.md:91` / edit delivery seam: accepted commits return immutable delivery payloads after document and selection effects both install -> Units 3 and 5 must route erase/text mutation through atomic EditKernel delivery.
- `docs/contracts/edit_kernel.md:100` / publication order: EditKernel closes the session before RuntimeRoot consumes accepted results and publishes public state before observer effects -> Units 3 and 5 must preserve state-before-action/request command observation order.
- `docs/contracts/frame_rendering.md:97` / overlay frame: `CanvasEraserPreview` is admitted by overlay frame capture -> Units 2, 3, and 7 must prove eraser preview uses overlay repaint only.
- `docs/contracts/load_document.md:49` / prepared cleanup boundary: successful prepared load requests interaction cleanup before document install and must not call the interaction boundary after install -> Unit 6 must prove eraser/context cleanup follows prepared-load ordering.
- `docs/contracts/load_document.md:97` / load failure ordering: failed validation/materialization preserves active gesture state, preview, committed document, selection, repaint, state publication, and actions -> Unit 6 must prove P12 eraser/context state preservation on load failure.
- `docs/contracts/operation_matrix.md:90` / eraser preview row: preview touches preview revision and overlay only -> Unit 2 must prove no document/selection/action effects during preview.
- `docs/contracts/operation_matrix.md:91` / eraser commit row: commit removes elements, prunes selection if needed, updates document/selection/preview/internal state, repaints main+overlay, and emits erase if removed -> Unit 3 must publish one coherent state after accepted install.
- `docs/contracts/operation_matrix.md:92` / context request row: request delivery is stream-only, direct double tap clears pending before target resolution, and registry stores guard facts -> Unit 4 must emit no public state/action/repaint effects.
- `docs/contracts/operation_matrix.md:133` / text guard list: stale checks include request id, epoch, target kind, generation, elementRevision, missing, empty, non-text, and family mismatch while documentRevision is observation-only -> Unit 5 must test every guard.
- `docs/contracts/public_api_v1.md:1475` / command API: `commitTextEdit` public signature already exists -> P12 changes behavior without changing signature.
- `docs/contracts/public_api_v1.md:406` / dispose compatibility: mutating public operations after dispose throw `StateError('CanvasRuntime is disposed.')` -> Unit 5 must require the same exact `commitTextEdit` after-dispose signal.
- `docs/contracts/public_api_v1.md:2066` / preview API: `CanvasEraserPreview` copies corridor into an unmodifiable list and stores thickness -> Unit 2 and Unit 7 must prove public immutable preview behavior.
- `docs/contracts/public_api_v1.md:2219` / erase payload: `CanvasEraseActionPayload` carries eraser thickness, erased ids, and corridor point count -> Unit 3 action proof must assert these fields.
- `docs/contracts/public_api_v1.md:2231` / text payload: `CanvasTextEditActionPayload` carries request id and text lengths only -> Unit 5 action proof must forbid raw text payloads.
- `docs/contracts/public_api_v1.md:2288` / request event: `CanvasContextActionRequested` carries id, trigger, target, epoch, documentRevision, timestamp, view, and world positions -> Unit 4 and Unit 7 must assert public event fields.
- `docs/contracts/public_api_v1.md:2333` / context model: P12 emits exactly one request and application owns menu/editor UI -> out of scope excludes engine UI state.
- `docs/diagrams/state_pending_context_action_request.mmd:155` / disposed request state: later `commitTextEdit` after `runtime.dispose()` throws `StateError` -> Unit 5 completion check must not accept false/no-op as disposed behavior.
- `docs/architecture/02_package_boundaries.md:303` / package boundary: `context_action_router.dart` is the future route owner and may only read narrow query facts -> Unit 4 filename and dependency direction are fixed.
- `docs/architecture/architecture_graph.yaml:463` / graph placeholder: P12 `eraser_text.request` is future with placeholder declaration -> Unit 8 must replace placeholder graph facts with actual P12 declarations after implementation.
- `docs/verification/tests.md:568` / smoke policy: public incremental smoke proves root-barrel external consumer behavior and must expand only by appending the next public step -> Unit 7 must extend the smoke to P12.
- `docs/verification/tests.md:657` / tool-port proof: `test/api/tool_port_settings_test.dart` owns public tool-port compatibility including context request stream behavior -> Unit 4 must name this file for broadcast/close proof.
- `docs/verification/guardrails.md` / guardrail source of truth: guardrail documentation records runner-backed enforcement expectations -> Unit 8 must update this file when P12 guardrail coverage changes.
- `docs/indexes/by_guardrail.md` / guardrail index source of truth: generated/owned guardrail index exposes guardrail coverage by id -> Unit 8 must keep it aligned with P12 enforcement.
- `tool/guardrails/src/guardrail_registry.dart:166` / guardrail registry gap: adjacent interaction guardrails are registered but `interaction.text_edit_stale_commit_guard` is absent -> Unit 6 must add the registry entry.
- `tool/guardrails/src/guardrail_executor.dart:238` / proof route gap: runner proof paths map nearby interaction guardrails but omit `interaction.text_edit_stale_commit_guard` -> Unit 6 must add the proof route.
- `tool/guardrails/src/guardrail_executor.dart:386` / executor gap: executable check routes include nearby interaction guardrails but omit `interaction.text_edit_stale_commit_guard` -> Unit 6 must add the executable route.
- `tool/guardrails/src/interaction_guardrail_checks.dart:24` / interaction check owner: interaction guardrail ids and checks live in this file -> Unit 6 must add the guarded text edit check implementation here or in a focused companion file named by this contract before registering the route.
- `test/smoke/public_incremental_smoke_test.dart:9` / smoke harness: package-boundary harness name is fixed -> P12 smoke must continue using the external Flutter consumer harness.
- `test/smoke/public_incremental_smoke_test.dart:568` / current placeholder: smoke expects `handleDoubleTap` to throw `UnsupportedError` -> Unit 7 must retire or relocate that P10 expectation when P12 behavior lands.
- `test/smoke/public_incremental_smoke_test.dart:652` / current unknown text no-op: smoke expects unknown `commitTextEdit` to return false -> Unit 7 must preserve unknown-id no-op while adding issued-id behavior.
- `test/smoke/public_incremental_smoke_test.dart:700` / current append style: P11 smoke uses a public workflow helper -> Unit 7 should append a P12 helper rather than create a new smoke file.
- `lib/src/runtime/runtime_root.dart:740` / current placeholder: `commitTextEdit` validates input then returns false -> Unit 5 must replace placeholder acceptance only through registry guard semantics.
- `lib/src/runtime/runtime_root.dart:881` / current placeholder: direct `handleDoubleTap` throws P12 unsupported -> Unit 4 must retire this placeholder through interaction-owned direct route behavior.
- `lib/src/interaction/interaction_pointer_context.dart:14` / admission seam: `InteractionPointerAdmission` is the current interaction-to-runtime carrier for pointer decisions -> P12 eraser commit and pointer-sample context request intents must use this seam instead of adding a parallel return channel.
- `lib/src/runtime/runtime_root.dart:838` / admission consumer: RuntimeRoot handles `InteractionEngine.handlePointerSample` admissions before publishing state -> eraser and pointer-sample context request intents must be consumed in the same existing dispatch path.
- `lib/src/interaction/interaction_engine.dart:21` / current owner comment: pointer sessions, tool settings, preview cleanup, and revisions stay together -> P12 should extend this owner instead of adding a runtime-local coordinator.
- `lib/src/interaction/interaction_engine.dart:132` / cleanup call: `InteractionEngine` is the current caller of the cleanup coordinator -> P12 cleanup must route through this owner.
- `lib/src/interaction/pointer_session.dart:8` / current session variants: no eraser session kind exists -> Unit 2 must add a focused eraser payload.
- `lib/src/interaction/draw_stroke_machine.dart:112` / draw machine behavior: eraser currently maps to `CanvasNoPreview` and stroke style rejects eraser -> Unit 2 must add a separate `EraserMachine`.
- `lib/src/geometry/geometry_policy.dart:75` / geometry primitive: `corridorEnvelope` already computes finite eraser corridor facts -> Unit 1 must reuse this policy.
- `lib/src/geometry/hit_test_policy.dart:79` / exact primitive: `exactEraserHit` already exists by family -> Unit 1 must reuse it.
- `lib/src/geometry/spatial_kernel.dart:139` / spatial query: `queryEraser` uses paint index -> Unit 1 must consume this candidate source.
- `PLAN.md:5` / roadmap source: root plan is the active roadmap index -> Step 49 must be linked from this index.
- `PLAN.md:12` / roadmap order: step order defines intended implementation order -> Step 49 must follow completed Step 48 P11 draw tools.
- `PLAN.md:70` / current predecessor: Step 48 is the completed P11 draw tools entry -> Step 49 is appended after it.
- `PLAN.md:71` / new roadmap entry: Step 49 links this P12 eraser/context-action request contract -> implementation order is now explicit.

## Boundaries

Owner:

`InteractionEngine` under `lib/src/interaction/**` owns active eraser pointer sessions, pending context tap state, eraser preview publication, preview and interaction revisions, `InteractionRequestRegistry` access, and the only production call path into `PointerToolCleanupCoordinator`. `EraserMachine` owns eraser capture values, corridor/preview decisions, exact-check budget branching, terminal erased-id decisions, cleanup requests, and erase commit-intent values only. `ContextActionRouter` owns direct double-tap validation decisions, pending context first-tap and second-tap recognition decisions, target-class matching, cleanup-before-target intent, and context request emission intents only. `InteractionRequestRegistry` owns generated request ids, live/retired status, request target kind, controllerEpoch, content target id/generation/elementRevision/family, observation-only documentRevision, and request retirement. `RuntimeRoot` owns public tool/command adapters, context request stream emission, action stream delivery, runtime timestamp output, edit delivery, and one coherent public-state publication. `EditKernel` owns atomic committed document mutation and rollback. Geometry/spatial/frame owners provide candidate, exact-hit, bounds, and overlay rendering facts through existing policies and ports.

In Scope:

Add P12 intent-specific interaction read requests/results and runtime adapter implementations for eraser preview, eraser terminal, context target resolution, pending tap storage/revalidation, and text commit guard facts. Add `eraser_machine.dart`, eraser session payload support in `pointer_session.dart`, eraser routing in `interaction_engine.dart`, eraser cleanup requests, preview publication, terminal budget/no-partial decisions, eraser `InteractionPointerAdmission` commit intent handoff, and runtime erase commit delivery through `EditKernel`. Add `context_action_router.dart`, pending context tap state, direct `handleDoubleTap` routing, pointer-sample two-tap recognition, target request intents, `interaction_request_registry.dart` issuance/guard-fact recording, pointer-sample context request `InteractionPointerAdmission` handoff, and stream emission. Add guarded `commitTextEdit` behavior, including stale/private retirement/no-op/changed commit paths and editText action payload finalization. Extend focused tests, guardrails, public incremental smoke, architecture graph, diagrams/docs where implementation names or behavior require it, generated docs/views, and this step checklist only after implementation evidence exists.

Out of Scope:

Do not create application UI for context menus, Flutter text editor overlays, IME, focus, accessibility, hide/show policy, text selection, or editor lifetime. Do not introduce new public method signatures, a text-specific public request id type, public scene/controller facades, scene-builder public architecture, scene codec, scene store controller, legacy runtime dependency, runtime-level P12 coordinator outside interaction, direct store/family-table mutation, context requests as preview/selection/document state, eraser through `DrawStrokeMachine`, direct `PointerToolCleanupCoordinator` calls from eraser/router/runtime delivery, duplicated eraser budget constants, or a new DiagnosticsHub writer/graph edge for eraser budget exhaustion. Do not treat `documentRevision` as a stale text edit guard. Do not emit raw text in action payloads. Do not replace focused stale/budget/two-tap matrices with smoke-only proof.

Source of Truth:

The P12 design source of truth is `.design/2026-06-02-p12-eraser-and-context-action-request.md`; current factual research is `.research/2026-06-02-p12-eraser-context-action-request.md`; phase scope is `docs/implementation/p12_eraser_and_text_request.md`. Public command/tool/request/preview/action contracts belong in `docs/contracts/public_api_v1.md` and `lib/src/contracts/public/**`. Interaction ownership, cleanup, pending context tap, preview, and request registry behavior belong in `docs/contracts/interaction_engine.md` and `lib/src/interaction/**`. Eraser budget constants and exact-hit policy belong in `docs/contracts/geometry.md`, `GeometryPolicy`, `HitTestPolicy`, and `SpatialKernel`; do not duplicate them elsewhere. Operation effects belong in `docs/contracts/operation_matrix.md`. Diagnostics routing belongs in `docs/contracts/diagnostics.md`. Architecture closure belongs in `docs/architecture/architecture_graph.yaml` and generated graph views. Verification inventory belongs in `docs/verification/tests.md`. Guardrail source-of-truth surfaces are `docs/verification/guardrails.md`, `docs/indexes/by_guardrail.md`, and runner-backed guardrail tests. The roadmap source of truth is `PLAN.md` plus this linked step contract.

Compatibility:

The public package remains source-compatible. P12 changes behavior through already exported declarations: `CanvasDrawTool.eraser`, `CanvasToolPort.handlePointer`, `CanvasToolPort.handleDoubleTap`, `CanvasRuntime.contextActionRequests`, `CanvasCommandPort.commitTextEdit`, `CanvasEraserPreview`, `CanvasContextActionRequested`, `CanvasInteractionRequestId`, `CanvasEraseActionPayload`, and `CanvasTextEditActionPayload`. Existing unknown or retired `commitTextEdit` request ids still return `false` without effects. The P10 direct double-tap `UnsupportedError` compatibility placeholder is retired only when P12 request-producing behavior lands. Request delivery is stream-only and must not publish runtime state, mutate document/selection/preview/spatial/projection/resource state, repaint, or emit actions. Accepted erase and changed text commits publish public state before action events.

Order Constraints:

For each behavior branch, add or update focused tests before production acceptance for that branch: read-model/payload tests before Unit 1 production changes, eraser machine/routing tests before Unit 2 acceptance, eraser runtime delivery tests before Unit 3 acceptance, context router/request tests before Unit 4 acceptance, text stale guard tests before Unit 5 acceptance, and cleanup/guardrail/diagnostics tests before Unit 6 acceptance. Add and prove public payload constructors/copy semantics only where existing payload behavior is incomplete before runtime action finalization depends on them. Add P12 read-model request/result types and runtime adapter facts before eraser and context machines consume them. Add `EraserMachine` and eraser pointer-session payload before routing eraser down/move/terminal through `InteractionEngine`; extend `InteractionPointerAdmission` with eraser commit intent only after eraser-owned result types exist. Add runtime erase delivery after eraser terminal commit intents exist. Add `InteractionRequestRegistry` issuance and guard-fact recording before any context request stream emission. Add `ContextActionRouter` and pending context tap state before direct `handleDoubleTap` or pointer-sample two-tap emits public requests; extend `InteractionPointerAdmission` with pointer-sample context request intent only after router/registry result types exist. Add guarded text commit after registry consume/retire semantics exist. Add lifecycle cleanup and diagnostics no-hub proof before closure relies on cleanup-only or budget-overflow paths. Expand public smoke only after focused P12 behavior is green, and keep detailed stale/budget/revalidation matrices in focused tests. Update docs/architecture/diagrams/generated outputs after production declarations and tests exist. Do not mark `PLAN.md` or execution unit checkboxes complete during this planning step.

Temporal and all-or-nothing constraints:

Eraser preview: `CanvasToolPort.handlePointer` may publish `CanvasEraserPreview` and preview revision only; no document, selection, spatial, projection, action, timestamp, or main repaint effect occurs during preview.

Eraser commit: accepted non-empty eraser terminal order is normalize/validate terminal sample, read current candidates and exact hits through narrow ports, return an erase commit intent without mutation, prepare `EditKernel` interaction commit, remove ids through `CanvasEdit.removeElement`, attach erase action intent, accept atomic install, run post-success cleanup without re-reading stale active session state, publish one coherent public state including document/selection/preview effects, then emit one erase action. The irreversible document point is accepted `EditKernel` install. Candidate/exact checks, budget decisions, edit preflight, and draft mutation are fallible before install. Failure before install projects as cleanup/no-op with prior document/selection/spatial/projection/action unchanged. Post-install cleanup, public state, repaint, and action delivery are accepted commit effects.

Context request: non-finite direct `handleDoubleTap` rejects before timestamp resolution, cleanup, target query, registry issue, or stream emission. Finite direct double tap resolves timestamp through the runtime cursor, clears any pending context tap through `PointerToolCleanupCoordinator` via `InteractionEngine`, resolves current target through narrow read facts, issues one registry id, records guard facts, and emits exactly one `CanvasContextActionRequested`. Request stream emission after registry issue is the accepted result; request delivery itself has no public runtime state/action/repaint or document mutation effect.

Text commit: `newText` validation happens before request retirement and before draft mutation. Unknown/retired ids return false as pure no-op. Known live stale, empty, non-text, missing, epoch/generation/elementRevision/family-mismatched ids return false and privately retire only. Same-text accepted ids return true and privately retire only. Changed text commits use `EditKernel`; for changed text, the request id is retired only after successful install and before public state publication, action delivery, repaint delivery, observer callback, method return, or later command observation. The irreversible text point is accepted `EditKernel` install. If changed text preinstall work fails, no document/action/public effect is emitted and the id is not consumed as an accepted changed commit.

## Required Production Declarations

| File | Required primary declarations | Unit | Contract constraint |
|---|---|---|---|
| `lib/src/interaction/interaction_read_port.dart` | P12 read request/result values for eraser preview, eraser terminal, context direct target, pending context tap, second-tap revalidation, and text guard facts | Unit 1 | Immutable, intent-specific facts only; no store tables, draft access, mutation methods, frame cache internals, resource sessions, or public document projection. |
| `lib/src/runtime/runtime_interaction_read_adapter.dart` | P12 adapter methods using frame, spatial, geometry, document summary/revision, selection, and family facts | Unit 1 | Reuses `GeometryPolicy`, `HitTestPolicy`, and `SpatialKernel.queryEraser`; no duplicate budget constants. |
| `lib/src/interaction/interaction_pointer_context.dart` | `InteractionPointerAdmission` eraser commit intent and pointer-sample context request intent fields | Units 2 and 4 | Existing interaction-to-runtime return carrier remains the only pointer-result handoff; no parallel runtime polling or stream side channel. |
| `lib/src/interaction/eraser_machine.dart` | `EraserMachine` and eraser transition/result/capture/commit-intent values | Unit 2 | Owns eraser lifecycle decisions only; no cleanup coordinator, runtime, edit, store, frame, resource, action stream, or public stream dependency. |
| `lib/src/interaction/pointer_session.dart` | Eraser session kind and eraser payload accessors | Unit 2 | Eraser session stores session id, token, pointer id, controller epoch, finite thickness, start/current world, and corridor points; context pending tap is not a pointer session. |
| `lib/src/interaction/interaction_engine.dart` | Eraser routing, pending context tap state, direct double-tap entrypoint, registry-backed command decision APIs, cleanup outcome application | Units 2, 4, 5, 6 | Remains active state owner and only cleanup coordinator caller. |
| `lib/src/interaction/context_action_router.dart` | `ContextActionRouter` and direct/pointer-sample context request decision values | Unit 4 | Filename and owner are locked by package-boundary docs; owns recognition/target decisions only, not app UI or mutations. |
| `lib/src/interaction/interaction_request_registry.dart` | Request id issuance, live/retired facts, consume/retire semantics, and guard value types | Units 4 and 5 | Unit 4 creates issuance/guard-recording before request emission; Unit 5 consumes/retire facts for text edit. The registry is the single source of request validity; public events are delivery payloads, not commit authority. |
| `lib/src/contracts/internal/commit_action_intent.dart` | Erase and text edit action intents if missing or incomplete | Units 3 and 5 | Internal intents carry public payload facts, timestamp hints, and no raw text. |
| `lib/src/runtime/runtime_action_finalizer.dart` | Erase and editText action finalization if missing or incomplete | Units 3 and 5 | Emits existing public action types after accepted install only. |
| `lib/src/runtime/runtime_root.dart` | Eraser commit delivery, context request stream emission, direct double-tap adapter, guarded text edit delivery | Units 3, 4, 5, 6 | Runtime composes interaction/edit/streams and does not own eraser/router/registry state or target resolution decisions. |
## Required Public P12 Action And Request Proof

P12 must preserve this public compatibility matrix with focused tests and public smoke assertions:

| Operation | Public output | Required assertion |
|---|---|---|
| Eraser preview | `CanvasEraserPreview` | Corridor and thickness match public pointer route; corridor is unmodifiable; only preview revision advances; overlay repaint only; no document/selection/action change. |
| Eraser terminal accepted with removed ids | `CanvasActionType.erase` | Removed ids disappear after atomic install; selected erased ids prune in same public state if needed; `CanvasEraseActionPayload.eraserThickness`, `erasedElementIds`, and `corridorPointCount` match the accepted eraser facts; action arrives after state publication. |
| Eraser terminal budget overflow | No action | Original document/selection/spatial/projection/action state remains unchanged; active preview cleans up only if present; no partial erase occurs. |
| Direct content double tap | `CanvasContextActionRequested` | Exactly one event with trigger `doubleTap`, content target snapshot, `boundsWorld`, id, epoch, documentRevision, timestamp, finite view/world positions; request delivery has no state/action/repaint effect. |
| Direct empty/background double tap | `CanvasContextActionRequested` | Exactly one empty-canvas target event and no state/action/repaint effect. |
| Pointer-sample two-tap match | `CanvasContextActionRequested` | First tap stores private pending history only; second tap revalidates current facts before issuing exactly one event. |
| Pointer-sample two-tap mismatch | No request | Pending context tap clears only; no public state/action/repaint/document mutation occurs. |
| Unknown or retired text edit request | `false` | No public/private mutation for unknown; already-retired remains no-op; no action/state/repaint effect. |
| Known live stale/invalid text edit request | `false` | Request privately retires only; no public state/action/repaint/document effect. |
| Same-text accepted text edit request | `true` | Request privately retires only; no document revision, repaint, or action. |
| Changed text edit request | `true` plus `CanvasActionType.editText` | Text changes through `EditKernel`; request id retires before public delivery; payload contains request id and previous/next lengths only; retrying same id returns false with no new effect. |

## Execution Units

### [ ] Unit 1: P12 Read Model And Payload Foundation

Owner:

`lib/src/interaction/interaction_read_port.dart`, `lib/src/runtime/runtime_interaction_read_adapter.dart`, `test/interaction/interaction_read_port_test.dart`, `test/geometry/eraser_exact_budget_inputs_test.dart`, `test/api/typed_action_payloads_test.dart`, `test/api_contract/preview_state_sealed_union_test.dart`.

Donors:

- Use `geometry_interactive_geometry` (`copy/adapt`) for context target hit/order facts and eraser corridor geometry reads.
- Use `geometry_eraser_exact_hit` (`adapt`) for exact eraser candidate facts and budget result shape.
- Use `foundation_action_event_immutability` (`adapt`) only if existing erase, text edit, or context request payload constructors/copy semantics are incomplete.

Design Decisions Preserved:

- `D7`
- `D12`
- `D13`
- `D18`

Boundary:

Read-model and value-surface foundation only. Do not route eraser gestures, emit context requests, accept text edits, call cleanup coordinator, or mutate document/selection/spatial/projection/resource state in this unit.

Change:

Add or update focused read-model and payload tests before accepting production read-model changes. Add immutable P12 read request/result types for eraser preview candidates, eraser terminal candidates, direct context target resolution, pending context first tap facts, context second-tap revalidation facts, and text commit guard facts. Implement runtime adapter methods through `FrameFactsPort`, `SpatialKernel.queryEraser`, `HitTestPolicy.exactEraserHit`, `GeometryPolicy.corridorEnvelope`, document summary/revision/generation/elementRevision/family facts, and selection facts only where selection pruning proof needs them. Repair public payload constructor defensive-copy/value behavior only if focused tests prove an existing P12 public payload is incomplete.

Completion Check:

`test/interaction/interaction_read_port_test.dart` and `test/geometry/eraser_exact_budget_inputs_test.dart` are added or updated before production acceptance and prove read results are immutable snapshots, target facts distinguish content-element and empty-canvas targets without requiring selectable content, background-only coverage is empty canvas, eraser reads use geometry/spatial policies without duplicate budget constants, text guard facts include id/target kind/epoch/generation/elementRevision/family and observation-only documentRevision, and no P12 read request exposes store tables, draft access, selection internals, mutation methods, frame cache internals, resource sessions, or public document projection. If public payload constructors are touched, `test/api/typed_action_payloads_test.dart` and `test/api_contract/preview_state_sealed_union_test.dart` assert defensive copies and no raw text.

Depends On:

None.

### [ ] Unit 2: Eraser Machine, Session, Preview, And Budget Decisions

Owner:

`lib/src/interaction/eraser_machine.dart`, `lib/src/interaction/pointer_session.dart`, `lib/src/interaction/interaction_pointer_context.dart`, `lib/src/interaction/interaction_engine.dart`, `test/geometry/eraser_exact_budget_no_partial_commit_test.dart`, `test/interaction/preview_public_state_test.dart`, `test/interaction/state_machines_test.dart`, `test/interaction/pointer_tool_cleanup_coordinator_test.dart`.

Donors:

- Use `foundation_pointer_input_contract` (`copy/adapt`) for down/move/up/cancel/stale terminal semantics and one-active-pointer policy.
- Use `geometry_interactive_geometry` (`copy/adapt`) for corridor preview geometry.
- Use `geometry_eraser_exact_hit` (`adapt`) for preview and terminal exact-hit/budget branching.
- Use `interaction_pointer_session` (`adapt`) for eraser session payload, token/epoch, dispose/load/settings cleanup safety.
- Use `interaction_pointer_normalizer` (`copy/adapt`) through the existing normalizer for pointer-sample world positions.
- Use `interaction_draw_coordinator` (`adapt/rewrite`) only to preserve draw-mode admission shape while implementing eraser as a separate machine, not as `DrawStrokeMachine`.
- Use `interaction_gesture_runtime` (`adapt`) for interaction routing and cleanup request return shape.

Design Decisions Preserved:

- `D2`
- `D3`
- `D4`
- `D6`
- `D7`
- `D8`

Boundary:

Interaction-owned eraser decisions only. `EraserMachine` must not call `PointerToolCleanupCoordinator`, `EditKernel`, runtime streams, frame, store, selection owner, resources, or action dispatchers. Runtime document mutation and action finalization are Unit 3.

Change:

Add or update focused eraser machine/routing tests before accepting production eraser behavior. Add `EraserMachine` as a sibling to draw and line machines; add eraser pointer-session payload under `PointerSession`; extend `InteractionPointerAdmission` with an eraser commit intent field carried through the existing pointer-result handoff; wire draw-mode eraser down/move/up/cancel/stale/invalid/no-op routing in `InteractionEngine`; publish immutable `CanvasEraserPreview` corridor/thickness through interaction preview state; produce cleanup-only decisions for empty ids, invalid/stale terminals, cancel, and budget overflow; produce erase commit intents only for terminal non-empty exact erased ids within budget; keep preview overflow as corridor-only preview with no tentative partial ids.

Completion Check:

`test/geometry/eraser_exact_budget_no_partial_commit_test.dart`, `test/interaction/preview_public_state_test.dart`, `test/interaction/state_machines_test.dart`, and `test/interaction/pointer_tool_cleanup_coordinator_test.dart` are added or updated before production acceptance and prove draw-mode eraser admission, one active pointer, finite thickness and world corridor capture, duplicate/finite corridor behavior, preview publication as immutable `CanvasEraserPreview`, preview revision only with overlay repaint, no document/selection/action effects during preview, preview budget overflow corridor-only behavior, terminal budget overflow cleanup/no-op with no commit intent, stale token/epoch terminal cleanup without commit, cancel/no-op/empty-id cleanup without action, eraser commit intent is carried by `InteractionPointerAdmission`, and `DrawStrokeMachine` still rejects eraser. `interaction.pointer_cleanup_coordinator_only`, `interaction.no_concrete_store_imports`, and `interaction.no_stale_terminal_commit` pass for P12 eraser files.

Depends On:

Unit 1.

### [ ] Unit 3: Atomic Eraser Commit And Erase Action Delivery

Owner:

`lib/src/runtime/runtime_root.dart`, `lib/src/contracts/internal/commit_action_intent.dart`, `lib/src/runtime/runtime_action_finalizer.dart`, `test/interaction/commands_emit_user_actions_test.dart`, `test/api/typed_action_payloads_test.dart`, `test/selection/runtime_owner_separation_test.dart`, `test/geometry/eraser_exact_budget_no_partial_commit_test.dart`.

Donors:

- Use `foundation_action_event_immutability` (`adapt`) for erase action payload finalization and state-before-action event delivery.
- Use `interaction_event_dispatcher` (`adapt`) for timestamp reservation only after accepted output-producing commit paths.
- Use `interaction_gesture_runtime` (`adapt`) for runtime delivery order, cleanup-after-success, cleanup-on-error, and reentrant mutation guard behavior.
- Use `interaction_mutation_boundary` (`adapt`) for committing erased ids through `EditKernel.prepareInteractionCommit`.

Design Decisions Preserved:

- `D3`
- `D8`
- `D9`
- `D18`

Boundary:

Runtime delivery and edit mutation only. RuntimeRoot consumes interaction erase commit intents and cleanup outcomes, but must not own eraser hit decisions, eraser session state, target candidate reads, registry state, or cleanup policy.

Change:

Add or update runtime eraser delivery tests before accepting production erase delivery. Add internal erase action intent/finalizer support if missing; add RuntimeRoot eraser delivery that consumes the eraser commit intent from `InteractionPointerAdmission`, removes each erased id through `CanvasEdit.removeElement` inside `EditKernel.prepareInteractionCommit`, attaches `CanvasEraseActionPayload`, applies post-success eraser cleanup through `InteractionEngine`, publishes one coherent public state after document/selection/preview effects are combined, and emits erase action only after accepted install. Ensure edit failure before install leaves document/selection/spatial/projection/action unchanged, routes edit-failure cleanup, and emits no erase action.

Completion Check:

`test/interaction/commands_emit_user_actions_test.dart`, `test/api/typed_action_payloads_test.dart`, `test/selection/runtime_owner_separation_test.dart`, and `test/geometry/eraser_exact_budget_no_partial_commit_test.dart` are added or updated before production acceptance and prove non-empty eraser commit deletes ids atomically through EditKernel, selection pruning for erased selected ids appears in the same public state, spatial/projection invalidation and main+overlay repaint effects occur only after accepted install, public state listeners observe committed document/selection/preview cleanup before `runtime.actions`, `CanvasEraseActionPayload` fields and `CanvasActionCommitted.elementIds` are correct and defensively copied, empty/budget/no-op cleanup emits no erase action, edit failure before install rolls back without action/timestamp advancement, and reentrant public mutation during state/action delivery is rejected by the existing runtime/edit guard without partial eraser mutation.

Depends On:

Units 1 and 2.

### [ ] Unit 4: Context Action Router And Request Emission

Owner:

`lib/src/interaction/context_action_router.dart`, `lib/src/interaction/interaction_request_registry.dart`, `lib/src/interaction/interaction_pointer_context.dart`, `lib/src/interaction/interaction_engine.dart`, `lib/src/runtime/runtime_root.dart`, `test/interaction/context_action_request_test.dart`, `test/interaction/state_machines_test.dart`, `test/api/tool_port_settings_test.dart`.

Donors:

- Use `foundation_pointer_input_contract` (`copy/adapt`) for pointer-sample tap lifecycle and direct host-recognized finite position validation.
- Use `foundation_action_event_immutability` (`adapt`) for immutable context request event payloads and element snapshots.
- Use `geometry_interactive_geometry` (`copy/adapt`) for current target hit/order facts.
- Use `interaction_pointer_normalizer` (`copy/adapt`) for pointer-sample world positions and direct double-tap view/camera conversion.
- Use `interaction_event_dispatcher` (`adapt`) for exactly-one request stream delivery and timestamp silence on rejected routes.
- Use `interaction_double_tap_router` (`adapt`) for direct and pointer-sample context request recognition.
- Use `interaction_gesture_runtime` (`adapt`) for cleanup-before-target ordering and no-effect routing.

Design Decisions Preserved:

- `D2`
- `D3`
- `D5`
- `D10`
- `D11`
- `D12`
- `D13`

Boundary:

Context request recognition and stream-intent creation only. The router must not mutate document, selection, preview, spatial, projection, resources, action state, or app UI. RuntimeRoot emits stream events but must not resolve target data itself except by providing composed ports/context.

Change:

Add or update context request focused tests before accepting production request emission. Add `ContextActionRouter` with direct `handleDoubleTap` decisions and engine-owned pointer-sample two-tap recognition. Add pending context tap state under `InteractionEngine` rather than `PointerSession`. Add registry issuance and guard-fact recording before any `CanvasContextActionRequested` stream emission. Add direct RuntimeRoot adapter that validates runtime mutability, delegates finite position/camera/epoch/timestamp resolver to interaction, and emits returned request intent through `_contextActionRequests`. Add pointer-sample first-tap storage, second-tap revalidation, cleanup-only mismatch behavior, direct pending-tap cleanup before current target resolution, pointer-sample context request intent handoff through `InteractionPointerAdmission`, and exactly-one content/empty request emission.

Completion Check:

`test/interaction/context_action_request_test.dart` and `test/interaction/state_machines_test.dart` are added or updated before production acceptance and prove direct content double tap records registry guard facts before emitting exactly one event with immutable content element snapshot, boundsWorld, trigger, id, epoch, documentRevision, timestamp, finite view/world positions, and no document/selection/preview/repaint/spatial/projection/resource/action effect; direct empty/background-only double tap emits one empty target event with no public effects; direct non-finite position rejects before timestamp resolution, cleanup, target query, registry issue, or stream emission; direct valid double tap clears existing pending context tap through `InteractionEngine`/coordinator before current-target resolution; pointer-sample first tap stores private history only; pointer-sample second tap revalidates current target facts and returns request intent through `InteractionPointerAdmission` only on match; mismatch/hidden/family-changed/current-target-changed second tap clears pending only and emits no request. `test/api/tool_port_settings_test.dart` proves `contextActionRequests` remains broadcast and closes on dispose.

Depends On:

Unit 1.

### [ ] Unit 5: Request Registry And Guarded Text Edit Commit

Owner:

`lib/src/interaction/interaction_request_registry.dart`, `lib/src/interaction/interaction_engine.dart`, `lib/src/runtime/runtime_root.dart`, `lib/src/contracts/internal/commit_action_intent.dart`, `lib/src/runtime/runtime_action_finalizer.dart`, `test/interaction/text_edit_stale_commit_guard_test.dart`, `test/api/typed_action_payloads_test.dart`.

Donors:

- Use `foundation_action_event_immutability` (`adapt`) for editText action payload fields and no raw text.
- Use `interaction_event_dispatcher` (`adapt`) for state-before-action delivery and timestamp reservation on accepted changed commits only.
- Use `interaction_double_tap_router` (`adapt`) because issued context request facts feed registry validity.
- Use `interaction_gesture_runtime` (`adapt`) for command routing, stale/private retirement, and no-effect behavior.
- Use `interaction_mutation_boundary` (`adapt`) for changed text commits through `EditKernel`.

Design Decisions Preserved:

- `D2`
- `D5`
- `D13`
- `D14`

Boundary:

Registry and guarded text command only. The registry is not public API, preview state, active editor session, menu state, text selection state, or UI lifetime owner. RuntimeRoot must not infer request validity from public event payloads.

Change:

Add or update text stale guard tests before accepting production text commit behavior. Complete registry consume/guard/retire APIs for text commits on top of the Unit 4 id issuance and guard-fact recording foundation. Replace `RuntimeRoot.commitTextEdit` placeholder with validation-before-retirement semantics, unknown/retired no-op false, known stale/invalid private-retire false, same-text accepted private-retire true/no public effect, and changed-text EditKernel commit with private retirement after successful install and before public state/action/repaint/observer delivery. Preserve disposal compatibility: after `runtime.dispose()`, `commitTextEdit` must throw `StateError('CanvasRuntime is disposed.')` before registry read, request retirement, draft mutation, timestamp resolution, public state, repaint, or action. Add `CanvasTextEditActionPayload` finalization with request id and lengths only if missing.

Completion Check:

`test/interaction/text_edit_stale_commit_guard_test.dart` is added or updated before production acceptance and proves unknown, retired, empty-canvas, non-text, stale epoch, missing target, generation mismatch, elementRevision mismatch, family mismatch, unrelated documentRevision change, same-text no-op, changed text commit, validation-before-retirement, retry-after-accepted false, and exact disposed behavior: `commitTextEdit` after `runtime.dispose()` throws `StateError('CanvasRuntime is disposed.')` without registry read, request retirement, draft mutation, timestamp resolution, public state, repaint, or action. `test/api/typed_action_payloads_test.dart` proves changed text uses `EditKernel`, emits one state update before one `editText` action, privately retires request id before public delivery or method return, carries request id plus previous/next text lengths only, never emits raw text, does not reserve timestamps for unknown/stale/no-op rejected paths, and leaves request id unaccepted if changed-text preinstall work fails.

Depends On:

Units 1 and 4.

### [ ] Unit 6: Lifecycle Cleanup, Stale Terminals, Diagnostics, And Donor-Equivalent Guardrails

Owner:

`lib/src/interaction/pointer_tool_cleanup_coordinator.dart`, `lib/src/interaction/interaction_engine.dart`, `lib/src/runtime/runtime_root.dart`, `tool/guardrails/src/guardrail_registry.dart`, `tool/guardrails/src/guardrail_executor.dart`, `tool/guardrails/src/interaction_guardrail_checks.dart`, `tool/guardrails/src/selection_move_guardrail_suite.dart`, `test/interaction/pointer_tool_cleanup_coordinator_test.dart`, `test/runtime/load_interaction_cleanup_test.dart`, `test/geometry/eraser_exact_budget_no_partial_commit_test.dart`, `test/guardrails/interaction_guardrail_enforcement_test.dart`, `test/guardrails/blocking_suite_test.dart`.

Donors:

- Use `foundation_pointer_input_contract` (`copy/adapt`) for stale terminal and cleanup/no-op pointer behavior.
- Use `interaction_pointer_session` (`adapt`) for eraser active-session cleanup and context pending tap separation.
- Use `interaction_gesture_runtime` (`adapt`) for dispose/load/settings/interactive cleanup order and exception-safe cleanup.
- Use `interaction_event_dispatcher` (`adapt`) for timestamp silence on cleanup-only paths.
- Use `geometry_eraser_exact_hit` (`adapt`) only for budget-overflow diagnostics no-hub proof tied to eraser exact budget paths.

Design Decisions Preserved:

- `D2`
- `D3`
- `D8`
- `D16`
- `D18`

Boundary:

Cleanup, stale rejection, diagnostics, donor-equivalent proof, and enforcement only. Do not add feature behavior here unless it is required to route cleanup outcomes from Units 2, 4, or 5 through existing owners. Do not create fixture-only production names, public registry entries, fake schema elements, docs-only guardrails, or broad guardrail matches unrelated to P12 owner surfaces.

Change:

Add or update cleanup, guardrail, diagnostics, and donor-equivalent tests before accepting production cleanup/enforcement changes. Extend cleanup outcome handling only as needed for eraser preview/session cleanup and pending context tap cleanup. Ensure mode/tool/style/pointer-policy changes, `interactive=false`, dispose, successful prepared load cleanup, load failure preservation, stale/invalid/no-op terminal, edit failure, and post-success commit paths produce the documented public effects. Add executable enforcement for `interaction.text_edit_stale_commit_guard`: register the id in `tool/guardrails/src/guardrail_registry.dart`; add proof paths and executable route in `tool/guardrails/src/guardrail_executor.dart`; add the check implementation in `tool/guardrails/src/interaction_guardrail_checks.dart`; include the id in `tool/guardrails/src/selection_move_guardrail_suite.dart`; and update `test/guardrails/blocking_suite_test.dart` plus `test/guardrails/interaction_guardrail_enforcement_test.dart` to prove it is runner-backed and fails on negative fixtures. Extend guardrails and diagnostics proof so P12 eraser/context files cannot bypass cleanup, stale terminal, text guard, or concrete-store import boundaries. Prove eraser preview/terminal budget exhaustion remains outside DiagnosticsHub through `test/geometry/eraser_exact_budget_no_partial_commit_test.dart` assertions that preview/terminal budget exhaustion leaves `DiagnosticRecord.allocations` and runtime diagnostics records unchanged. Add P12 negative fixtures inline in `test/guardrails/interaction_guardrail_enforcement_test.dart` under its structural negative proof helpers; do not create separate fixture-only production files. Preserve donor-equivalent tests without importing legacy donor runtime paths, copying forbidden donor shells, or relying on docs-only proof.

Completion Check:

`test/interaction/pointer_tool_cleanup_coordinator_test.dart`, `test/runtime/load_interaction_cleanup_test.dart`, `test/geometry/eraser_exact_budget_no_partial_commit_test.dart`, `test/guardrails/interaction_guardrail_enforcement_test.dart`, and `test/guardrails/blocking_suite_test.dart` are added or updated before production acceptance and prove eraser overlay cleanup and pending context tap cleanup dispositions, cleanup-only paths emit no erase action or document state, empty no-preview cleanup is silent, loadDocument prepared cleanup is produced before install and clears eraser/context state on success, load failure preserves required eraser/context state, dispose closes streams after cleanup, stale terminal samples never create commit/request intents, and timestamp cursor does not advance on cleanup-only paths. `test/geometry/eraser_exact_budget_no_partial_commit_test.dart` proves preview/terminal eraser budget exhaustion allocates no `DiagnosticRecord`, writes no runtime diagnostics record, and preserves no-partial-erase behavior. `test/guardrails/interaction_guardrail_enforcement_test.dart` adds inline P12 negative fixtures and proves `interaction.no_concrete_store_imports`, `interaction.no_stale_terminal_commit`, `interaction.pointer_cleanup_coordinator_only`, and `interaction.text_edit_stale_commit_guard` cover P12 files and fail on fixture snippets containing forbidden direct cleanup, direct store, stale terminal, unguarded text edit, legacy runtime path, or forbidden donor shell patterns. `test/guardrails/blocking_suite_test.dart` proves `interaction.text_edit_stale_commit_guard` is registered, in the blocking/interaction route, runner-backed through `tool/guardrails/src/guardrail_executor.dart`, and included in the same interaction guardrail grouping as the P12 files it protects. The required semantic-search proof is fixed to these commands and expected result: `rg -n "eraser|Eraser" lib/src/diagnostics lib/src/runtime/runtime_interaction_diagnostics_adapter.dart docs/architecture/architecture_graph.yaml` returns no P12 eraser budget DiagnosticsHub writer or graph edge, and `rg -n "DiagnosticRecord|DiagnosticsHub|recordInteractionReliabilityDiagnostic|recordSchemaV1FailureDiagnostic" lib/src/interaction lib/src/geometry` returns no eraser budget writer path outside the existing interaction reliability route.

Depends On:

Units 2, 4, and 5.

### [ ] Unit 7: Public Incremental Smoke Expansion To P12

Owner:

`test/smoke/public_incremental_smoke_test.dart` and the external Flutter consumer harness.

Donors:

- Use `foundation_pointer_input_contract` (`copy/adapt`) for public eraser pointer samples through `CanvasToolPort.handlePointer`.
- Use `foundation_action_event_immutability` (`adapt`) for public action and request payload observations from root-barrel consumers.
- Use `interaction_pointer_normalizer` (`copy/adapt`) indirectly through public pointer/direct double-tap view/world assertions.
- Use `interaction_event_dispatcher` (`adapt`) for public state-before-action and exactly-one request observations.
- Use `interaction_double_tap_router` (`adapt`) for direct content and empty target request workflow.
- Use `interaction_mutation_boundary` (`adapt`) for public erased document and text edit commit observations.

Design Decisions Preserved:

- `D6`
- `D1`
- `D9`
- `D10`
- `D12`
- `D14`
- `D15`

Boundary:

Package-boundary smoke only. Do not move detailed stale, budget, diagnostics, cleanup, or two-tap matrices into smoke. Keep smoke as a coarse public root-barrel compatibility proof.

Change:

Extend `test/smoke/public_incremental_smoke_test.dart` to P12. Preserve the external Flutter consumer harness and import only `package:iwb_canvas_engine/iwb_canvas_engine.dart` from the embedded consumer source. Replace or relocate the retired P10 expectation that `handleDoubleTap` throws so P12 behavior is asserted instead. Preserve unknown `commitTextEdit(CanvasInteractionRequestId('unknown'), ...) == false`. Add `_exercisePublicEraserAndContextRequestWorkflow(WidgetTester tester)` and call it from a new public consumer widget test that creates deletable content, non-deletable/background or background-only area, and text content; subscribes to `runtime.actions` and `runtime.contextActionRequests`; erases through public draw-mode eraser pointer samples; asserts immutable eraser preview and accepted erase action; calls direct content and empty double tap; commits issued text edit; retries retired id; and verifies no raw text action payload.

Completion Check:

The smoke test passes through the shared Flutter consumer harness. Assertions prove only root-barrel public imports are used; eraser preview is visible and immutable during gesture; preview does not advance document revision; terminal erase removes the content element and emits one `CanvasEraseActionPayload`; direct content double tap emits exactly one content request with public snapshot/bounds/id/epoch/documentRevision/timestamp/view/world facts and no public state/action effects; direct empty/background double tap emits exactly one empty request and no public state/action effects; issued text request `commitTextEdit` returns true, updates text, emits one `editText` action after state update with id and lengths only; retrying the same id returns false with no new state/action; unknown id remains false. `dcm calculate-metrics test/smoke` is run for the changed smoke owner.

Depends On:

Units 1 through 6.

### [ ] Unit 8: Source-Of-Truth, Architecture Graph, And Verification Closure

Owner:

`docs/contracts/**`, `docs/verification/tests.md`, `docs/verification/guardrails.md`, `docs/indexes/by_guardrail.md`, `docs/architecture/architecture_graph.yaml`, generated architecture graph views, `docs/diagrams/dfd_pointer_preview_commit.mmd`, `docs/diagrams/dfd_public_edit.mmd`, `docs/diagrams/seq_eraser_commit.mmd`, `docs/diagrams/seq_eraser_exact_budget.mmd`, `docs/diagrams/seq_context_action_request.mmd`, `docs/diagrams/state_eraser.mmd`, `docs/diagrams/state_pending_context_action_request.mmd`, `docs/diagrams/state_pointer_session.mmd`, `docs/diagrams/catalog.md`, `tool/guardrails/src/guardrail_registry.dart`, `tool/guardrails/src/guardrail_executor.dart`, `tool/guardrails/src/interaction_guardrail_checks.dart`, `tool/guardrails/src/selection_move_guardrail_suite.dart`, runner-backed guardrail tests, `PLAN.md`, and this step document.

Donors:

- No donor implementation behavior is used in this documentation/closure unit. This unit records the actual P12 owners and proof surfaces after production behavior lands and verifies forbidden donor structure remains excluded.

Design Decisions Preserved:

- `D5`
- `D1`
- `D15`
- `D17`
- `D18`

Boundary:

Durable source-of-truth closure only. Do not duplicate implementation facts into new non-authoritative docs. Update existing owning docs/graph/diagrams/tests inventory only when production declarations, tests, and guardrails are already in place. Do not let fixture-only names or temporary scheduling metadata leak into stable source.

Change:

Update source-of-truth surfaces to reflect actual P12 declaration names, route order, effect matrix, verification inventory, guardrail coverage, and architecture graph status. Update `docs/verification/guardrails.md`, `docs/indexes/by_guardrail.md`, and runner-backed guardrail tests to reflect P12 enforcement for cleanup coordinator ownership, stale terminal prevention, text edit stale guard, concrete-store import prevention, diagnostics no-hub proof, and forbidden donor structure. Replace `eraser_text.request` placeholder declarations with actual selected P12 declarations such as `EraserMachine`, `ContextActionRouter`, and `InteractionRequestRegistry` unless implementation has first updated the package-boundary source of truth for a different name. Regenerate/check graph views and generated docs. Keep names such as `p12`, `phase_12`, `step_49`, fixture-only request ids, and placeholder graph labels out of production source, fixtures that claim to be durable model data, public registries, schemas, and stable docs unless the identifier is a real phase/protocol/source-of-truth reference. Mark Step 49 and execution unit checkboxes complete only during implementation closure after unit evidence exists.

Completion Check:

`docs/verification/tests.md` names P12 focused tests and the P12 public smoke append; `docs/verification/guardrails.md` and `docs/indexes/by_guardrail.md` match runner-backed enforcement; `tool/guardrails/src/guardrail_registry.dart`, `tool/guardrails/src/guardrail_executor.dart`, `tool/guardrails/src/interaction_guardrail_checks.dart`, and `tool/guardrails/src/selection_move_guardrail_suite.dart` include `interaction.text_edit_stale_commit_guard`; `test/guardrails/interaction_guardrail_enforcement_test.dart` and `test/guardrails/blocking_suite_test.dart` cover P12 guardrail ids and negative fixtures; `docs/architecture/architecture_graph.yaml` moves P12 graph nodes/edges from future placeholders to actual declarations; generated graph views are synchronized by `dart run tool/architecture_graph/check.dart --phase P12` and `dart run tool/architecture_graph/generate_views.dart --phase P12 --check`; docs generated output is synchronized by `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart`; semantic search shows forbidden donor structure, legacy runtime paths, fixture-only production names, and temporary scheduling names such as `p12`, `phase_12`, or `step_49` were not introduced outside real phase/protocol/source-of-truth references; `PLAN.md` and this step document are marked complete only after implementation proof exists.

Depends On:

Units 1 through 7.

## Required Verification Commands

After Dart code changes:

- `dart analyze`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/interaction`
- `dcm calculate-metrics lib/src/runtime`
- `dcm calculate-metrics lib/src/api` when API facade or surface code changes
- `dcm calculate-metrics lib/src/contracts/public` when public payload/request/action values change
- `dcm calculate-metrics lib/src/contracts/internal` when internal action intent or delivery values change
- `dcm calculate-metrics lib/src/geometry` when geometry or eraser budget code changes
- `dcm calculate-metrics lib/src/frame` when frame repaint or preview capture code changes
- `dcm calculate-metrics test/interaction`
- `dcm calculate-metrics test/runtime`
- `dcm calculate-metrics test/api`
- `dcm calculate-metrics test/geometry`
- `dcm calculate-metrics test/guardrails`
- `dcm calculate-metrics test/smoke`
- `dcm calculate-metrics tool/guardrails` when guardrail code or fixtures change
- `dcm calculate-metrics` for every other changed production, test, or tool owner not listed above
- Focused tests named in the execution unit completion checks.
- `dart test test/interaction/interaction_read_port_test.dart`
- `dart test test/geometry/eraser_exact_budget_inputs_test.dart`
- `dart test test/geometry/eraser_exact_budget_no_partial_commit_test.dart`
- `dart test test/api/typed_action_payloads_test.dart`
- `dart test test/api/tool_port_settings_test.dart`
- `dart test test/api_contract/preview_state_sealed_union_test.dart`
- `dart test test/interaction/commands_emit_user_actions_test.dart`
- `dart test test/interaction/preview_public_state_test.dart`
- `dart test test/interaction/state_machines_test.dart`
- `dart test test/interaction/context_action_request_test.dart`
- `dart test test/interaction/text_edit_stale_commit_guard_test.dart`
- `dart test test/interaction/pointer_tool_cleanup_coordinator_test.dart`
- `dart test test/runtime/load_interaction_cleanup_test.dart`
- `dart test test/selection/runtime_owner_separation_test.dart`
- `dart test test/guardrails/interaction_guardrail_enforcement_test.dart`
- `dart test test/guardrails/blocking_suite_test.dart`
- `dart test test/smoke/public_incremental_smoke_test.dart`

When architecture graph or generated graph views change:

- `dart run tool/architecture_graph/check.dart --phase P12`
- `dart run tool/architecture_graph/generate_views.dart --phase P12 --check`

When docs or docs generation outputs change:

- `dart run docs/tool/sync_generated_docs.dart --check`
- `dart run docs/tool/check_docs.dart`

For mixed code and documentation changes, run the relevant code, focused test, architecture, and documentation checks above.
