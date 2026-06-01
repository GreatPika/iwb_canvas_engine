# Change Contract

## Goal

Implement P10 as the first production interaction slice: public consumers can use selection, move-mode pointer handling, marquee replacement selection, selected-move preview and commit, move resolver safety, high-level selection/command actions, and load/dispose cleanup while interaction ownership remains separated from selection, edit, frame, diagnostics, and later draw/text/surface phases.

## Source Inputs

- Design: `.design/2026-06-01-p10-selection-and-move.md`
- Research: `.research/2026-06-01-p10-selection-and-move-readiness.md`
- Phase: `docs/implementation/p10_selection_and_move.md`
- PLAN: `PLAN.md`
- Other: `docs/contracts/public_api_v1.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/operation_matrix.md`, `docs/contracts/load_document.md`, `docs/contracts/geometry.md`, `docs/contracts/frame_rendering.md`, `docs/contracts/diagnostics.md`, `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/03_data_model.md`, `docs/architecture/architecture_graph.yaml`, `docs/verification/tests.md`, `docs/verification/guardrails.md`

## Classification

Profile: BEHAVIOR_CHANGE

Obligations:

- SEAM_MIGRATION: migrate load interaction cleanup, preview ownership, pointer-session state, read facts, and command facts into production seams owned by interaction/runtime/edit instead of placeholders or direct local state.
- PUBLIC_API_CHANGE: `CanvasRuntime.tools`, `CanvasRuntime.commands`, `CanvasRuntime.contextActionRequests`, existing selection-command methods, preview state, actions, and move resolver semantics become operational for the P10-supported public surface without exporting new internal implementation owners.

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D-P10-01` Source-of-truth contradictions and normative gaps must be repaired before production interaction code, including double-tap/P12 scope, transform pivots, cleanup semantics, diagnostics reliability codes, graph placeholder splits, geometry diagnostics graph contradiction, and package-boundary file additions. | `Boundaries.Source of Truth`, `Boundaries.Order Constraints`, Unit 0 | Unit 0 docs checks, targeted P10 architecture graph checks, and no production declarations marked implemented before their later units exist. |
| `D-P10-02` `InteractionEngine` owns pointer sessions, mode state, preview producer state, cleanup orchestration, and interaction revision under `lib/src/interaction/`. | `Boundaries.Owner`, Units 1 and 3 | Interaction value/session tests, tool setting tests, preview-public-state tests, and interaction import guardrails. |
| `D-P10-03` `PointerToolCleanupCoordinator` is effect-policy only and is called only by `InteractionEngine`. | `Boundaries.Owner`, Unit 2 | Cleanup coordinator unit tests plus dependency and caller-origin guardrails. |
| `D-P10-04` `SelectionKernel` remains the selected-id and selection-revision owner; direct selection set/toggle/clear/selectAll stay direct selection-owner APIs. | `Boundaries.Owner`, Unit 10 | Direct selection revision-domain tests and action-stream silence tests. |
| `D-P10-05` Marquee replacement, selected move commit, selection transforms/delete, remove, and clear commit through `EditKernel`; accepted operations preserve the P10 typed action payload matrix. | `Boundaries.Source of Truth`, Units 5, 8, 9, and 10 | Edit bridge tests, command tests, `test/api/typed_action_payloads_test.dart`, stale terminal guardrails, and rollback/no-op proof. |
| `D-P10-06` Interaction reads immutable batched facts through `InteractionReadPort` only. | `Boundaries.Owner`, `Boundaries.Source of Truth`, Unit 7 | Read-port adapter tests and import guardrails rejecting direct store/selection/resource/frame reads. |
| `D-P10-07` Interaction owns preview value/revision while `RuntimeRoot` publishes delegated state and frame inputs. | `Boundaries.Owner`, Unit 3 | Preview revision tests, public state tests, and frame capture selected-move/main plus marquee/overlay proof. |
| `D-P10-08` Selected-move preview is delta-only and main-scene only. | `Boundaries.Compatibility`, Unit 8 | Selected-move state-machine tests, public preview sealed-union proof, and main-repaint guardrail. |
| `D-P10-09` Marquee preview is overlay-only. | `Boundaries.Compatibility`, Unit 9 | Marquee state-machine tests and overlay repaint proof. |
| `D-P10-10` Pointer positions are converted from view space to world space as `sample.position + runtime.viewCameraOffset`. | `Boundaries.Order Constraints`, Units 1, 8, and 9 | Pointer normalizer/session tests and selected-move/marquee geometry assertions. |
| `D-P10-11` Selected-move commit transform order is `CanvasTransform.translation(delta).multiply(oldTransform)`. | Unit 8 | Transform math tests matching selected-move frame preview ordering. |
| `D-P10-12` Rotate/flip selected elements use the center of eligible selected elements' union bounds as pivot. | Unit 0 and Unit 10 | Public API/operation matrix repair plus command transform tests and payload assertions. |
| `D-P10-13` Move resolver runs exactly once only on valid terminal selected-move commit and uses the existing `RuntimeRoot` mutation guard. | `Temporal and all-or-nothing constraints`, Unit 8 | Resolver spy tests, reentrancy tests, timestamp tests, and no-resolver-on-cancel guardrail. |
| `D-P10-14` Public actions emit only after accepted atomic public state install and runtime timestamp/id assignment; no-op/stale/cancel paths remain timestamp-silent. | `Temporal and all-or-nothing constraints`, Unit 0 and Unit 6 | Unit 0 operation-matrix repair plus Unit 6 ordered stream tests, timestamp tests, and action-after-state guardrail. |
| `D-P10-15` `handleDoubleTap` remains P12-owned in P10 and throws `UnsupportedError` after source-of-truth repair. | `Boundaries.Out of Scope`, Units 0 and 10 | Public tool-port compatibility tests proving no request/action/state/timestamp effects. |
| `D-P10-16` `commitTextEdit` returns false for unknown ids until the P12 `InteractionRequestRegistry` exists. | `Boundaries.Out of Scope`, Units 0 and 10 | Command-port tests proving no document, selection, preview, interaction, action, or timestamp effects. |
| `D-P10-17` Interaction diagnostics use internal `DiagnosticCode.interaction(InteractionDiagnosticCode)` values and bounded sanitized facts. | `Boundaries.Source of Truth`, Unit 11 | Diagnostics contract/tests and graph edge update without public API export. |
| `D-P10-18` Load success performs prepared interaction cleanup before document install and never calls interaction after install for that load. | `Temporal and all-or-nothing constraints`, Unit 4 | Load success/failure tests with active selected-move and marquee sessions. |
| `D-P10-19` High-level command fact reads use `CommandFactsPort`, not `InteractionReadPort`, and interaction must not import command facts. | `Boundaries.Owner`, `Boundaries.Source of Truth`, Unit 10 | Command facts tests and interaction forbidden-import guardrail. |
| `D-P10-20` `CanvasToolPort` getters/setters become real for P10 state, cleanup, and compatibility behavior while draw/line/eraser/context behavior remains deferred. Initial tool config is visible without construction-time `interactionRevision` bump; entering draw mode clears selection in the same public state only when `clearSelectionOnDrawModeEnter` is true; empty `contextActionRequests` closes on dispose. | `Boundaries.Compatibility`, Units 0, 1, and 10 | Tool setting tests, draw-mode pointer no-op tests, selection-clear-on-draw-mode tests, empty request stream close tests, and graph placeholder split checks. |
| `D-P10-21` Architecture graph facade placeholders for `tools` and `contextActionRequests` must be split so P10 owns non-throwing supported behavior and later phases retain only deferred behavior. | `Boundaries.Source of Truth`, Unit 0 and Unit 13 | P10 architecture graph checks, generated view checks, and Unit 10 public facade tests. |

## Evidence

- `.design/2026-06-01-p10-selection-and-move.md:15` / design readiness: P10 is `READY_FOR_CONTRACT` and the design is the source for interaction ownership, command routing, cleanup ordering, typed action emission, and move/marquee semantics -> write a full contract and preserve locked decisions.
- `.design/2026-06-01-p10-selection-and-move.md:29` / classification: the design selects `BEHAVIOR_CHANGE` with `SEAM_MIGRATION` and `PUBLIC_API_CHANGE` -> contract must include public behavior and seam migration proof, not only refactor tasks.
- `.design/2026-06-01-p10-selection-and-move.md:329` / selected form: the design fixes production interaction files and responsibilities -> execution units must introduce these owners with the named responsibilities.
- `.design/2026-06-01-p10-selection-and-move.md:392` / P12 scope: double-tap behavior currently conflicts with P10 scope and must be repaired before tool-port code -> Unit 0 must run before public tool exposure.
- `.design/2026-06-01-p10-selection-and-move.md:934` / decision trace: the design provides lock-required D-P10 decisions -> this contract maps those decisions to units and proof surfaces.
- `.design/2026-06-01-p10-selection-and-move.md:1212` / source-of-truth impact: source-of-truth contradiction repair is separated from implementation-backed graph closure -> Unit 0 repairs normative gaps while later units update graph edges only after declarations exist.
- `.design/2026-06-01-p10-selection-and-move.md:1322` / handoff: the design prescribes execution unit order from source-of-truth repair through final verification -> contract order follows that sequence.
- `.design/2026-06-01-p10-selection-and-move.md:61` and `docs/contracts/frame_rendering.md:4` / source input naming: the design's `docs/contracts/frame_pipeline.md` reference is an outdated/nonexistent frame contract path, while the repository registry owns the frame contract at `docs/contracts/frame_rendering.md` -> this contract lists the existing source-of-truth frame contract path rather than carrying a dead input path.
- `docs/implementation/p10_selection_and_move.md:5` / phase purpose: P10 implements selection APIs, marquee selection, selected move preview/commit/cancel, resolver safety, and typed action events -> contract scope must cover the complete P10 interaction behavior.
- `docs/implementation/p10_selection_and_move.md:22` / preview payload: selected move preview uses `CanvasSelectedMovePreview` with a delta-only public payload -> Units 3 and 8 must preserve preview compatibility.
- `docs/implementation/p10_selection_and_move.md:24` / resolver path: selected-move resolver is called only on valid terminal commit -> Unit 8 and guardrails must prove cancel/stale/invalid/load/dispose silence.
- `docs/implementation/p10_selection_and_move.md:34` / cleanup seam: P10 first introduces the cleanup coordinator seam -> Unit 2 must establish coordinator behavior before load/pointer machines depend on it.
- `docs/implementation/p10_selection_and_move.md:40` / cleanup outcomes: coordinator outcomes must cover main preview, overlay preview, no-preview, resolver-error cleanup, and pending-line preservation -> Unit 2 completion checks must name those fields directly.
- `docs/implementation/p10_selection_and_move.md:145` / exit gate: marquee commits through `EditKernel` -> Unit 5 and Unit 9 must support selection-set effects, not direct selection mutation from interaction.
- `docs/implementation/p10_selection_and_move.md:147` / exit gate: selected-move preview exposes only `CanvasSelectedMovePreview.delta` while selected ids stay in selection capture -> Unit 8 must reject internal ids in public preview.
- `docs/contracts/public_api_v1.md:373` / public runtime: `CanvasRuntime` exposes `selection`, `tools`, `commands`, `preview`, `actions`, and `contextActionRequests` -> Unit 10 must close P10-supported public placeholders without exporting internals.
- `docs/contracts/public_api_v1.md:1456` / timestamp contract: resolver request and preview/request outputs use the runtime-local timestamp resolver while rejected paths do not create timestamped outputs -> Units 6 and 8 must prove timestamp order and silence.
- `docs/contracts/public_api_v1.md:1520` / selection port: `CanvasSelectionPort` is the public boundary for selection commands -> Unit 10 owns command behavior through runtime-owned facts.
- `docs/contracts/public_api_v1.md:1700` / tool port: `CanvasToolPort` declares mode/tool/pointer handling and double tap entry points -> Units 0, 1, and 10 must settle P10-compatible behavior.
- `docs/contracts/public_api_v1.md:1716` / double tap: current public API text describes double-tap context request publication -> Unit 0 must repair P10/P12 scope before implementation.
- `docs/contracts/public_api_v1.md:1868` / preview state: public preview variants are sealed API shapes including marquee and selected move -> Unit 3 must migrate producer ownership without changing payload shape.
- `docs/contracts/public_api_v1.md:2335` / resolver: move commit resolver is synchronous and guarded; exceptions clear preview and rethrow -> Unit 8 must preserve cleanup-before-rethrow and reentrant rejection behavior.
- `docs/contracts/interaction_engine.md:109` / pointer boundary: `InteractionEngine` receives normalized pointer samples -> Units 1, 8, and 9 must put sample normalization before state-machine handling.
- `docs/contracts/interaction_engine.md:115` / cleanup caller: `InteractionEngine` is the only cleanup coordinator caller -> Unit 2 and guardrails must enforce caller origin.
- `docs/contracts/interaction_engine.md:124` / mutation boundary: interaction commits only through `EditKernel` -> Units 5, 8, and 9 must route accepted mutations through edit delivery.
- `docs/contracts/interaction_engine.md:133` / read port: marquee and selected-move queries flow through `InteractionReadPort` -> Unit 7 must provide immutable batched fact bundles.
- `docs/contracts/interaction_engine.md:153` / cleanup coordinator: coordinator is internal and must avoid resolver/edit/event/frame/store/selection/resource dependencies -> Unit 2 dependency proof must be structural, not prose-only.
- `docs/contracts/interaction_engine.md:204` / repaint targets: selected move is main-scene only and marquee/stroke/line/eraser previews are overlay-only -> Units 8 and 9 must preserve frame routing.
- `docs/contracts/load_document.md:49` / load success: prepared load cleanup happens before document install and without resolver/commit terminal paths -> Unit 4 must replace the minimal boundary without changing load failure preservation.
- `docs/contracts/diagnostics.md:89` / diagnostics plan: interaction reliability events are planned for P10 through an internal code seam with no public API export -> Unit 11 must implement bounded diagnostics, not action events.
- `docs/architecture/01_runtime_ownership.md:63` / ownership: `InteractionEngine` owns pointer sessions, tools, preview state, terminal commit requests, guard facts, and cleanup coordinator composition -> Units 1 and 3 own interaction state rather than `RuntimeRoot` local logic.
- `docs/architecture/01_runtime_ownership.md:84` / cleanup policy: cleanup coordinator must remain an `InteractionEngine` collaborator and not emit actions, call resolvers, open edits, or read stores/selection internals -> Unit 2 must preserve effect-only policy.
- `docs/architecture/01_runtime_ownership.md:111` / read facts: interaction input facts come through `InteractionReadPort` -> Unit 7 must prevent direct interaction reads from owner internals.
- `docs/architecture/02_package_boundaries.md:196` / package boundary: cleanup coordinator is interaction-internal and not exported -> Unit 2 must keep public package compatibility.
- `docs/architecture/02_package_boundaries.md:271` / import restriction: cleanup coordinator may not import resolver callbacks, `EditKernel`, repaint buses, Flutter bridge, resource sessions, concrete store internals, or concrete selection internals -> Unit 12 guardrails must enforce this.
- `docs/architecture/02_package_boundaries.md:283` / query port: interaction facts are supplied through `InteractionReadPort` and narrow selection facts ports -> Unit 7 must not duplicate source-of-truth state.
- `docs/architecture/03_data_model.md:176` / revisions: preview cleanup increments preview revision without document revision -> Units 2 and 3 must prove no-preview cleanup is silent and active preview cleanup is revision-scoped.
- `docs/architecture/architecture_graph.yaml:433` / graph: `InteractionEngine` is the future boundary for pointer sessions, tool preview intents, selection/move behavior, and terminal commit coordination -> graph closure belongs to units that create the declarations.
- `docs/architecture/architecture_graph.yaml:811` / graph: interaction action emission is a P10 graph obligation -> Units 5 and 6 must update action route evidence after implementation exists.
- `docs/architecture/architecture_graph.yaml:955` / graph: preview is already implemented as readable in P9 and must not return to a throwing placeholder -> Unit 3 must delegate preview ownership without regressing the public read path.
- `docs/verification/guardrails.md:195` / guardrail inventory: high-level commands and interaction commits own user action events -> Units 6, 10, and 12 must add executable action-order proof.
- `docs/verification/guardrails.md:199` / guardrail inventory: selected move preview increments main repaint, not overlay -> Unit 8 must keep existing P9 proof active while adding P10 producer behavior.
- `docs/verification/guardrails.md:200` / guardrail inventory: interaction cannot import concrete store internals -> Unit 12 must enforce boundary rules.
- `docs/verification/guardrails.md:204` / guardrail inventory: cleanup-capable machines return typed cleanup requests and only `InteractionEngine` calls the coordinator -> Unit 12 must register and prove the guardrail.
- `lib/src/api/canvas_runtime.dart:41` / current placeholder: `CanvasRuntime.tools` still throws -> Unit 10 must expose the real P10 tool port.
- `lib/src/api/canvas_runtime.dart:42` / current placeholder: `CanvasRuntime.commands` still throws -> Unit 10 must expose the real P10 command port.
- `lib/src/api/canvas_runtime.dart:47` / current placeholder: `CanvasRuntime.contextActionRequests` still throws -> Unit 10 must return the P10 empty broadcast stream.
- `lib/src/runtime/runtime_root.dart:120` / current preview owner: `RuntimeRoot` stores `_previewRevision` and `_preview` locally -> Unit 3 must migrate source-of-truth to interaction and keep runtime publication.
- `lib/src/runtime/runtime_root.dart:456` / current dispose order: runtime owns stream and frame disposal -> Unit 4 and Unit 10 must add interaction cleanup before stream closure without resolver/edit/action side effects.
- `lib/src/runtime/runtime_root.dart:560` / load order: load currently requests minimal interaction cleanup before consuming prepared load -> Unit 4 can replace the boundary while preserving P6 order.
- `lib/src/contracts/internal/load_interaction_boundary.dart:2` / current load cleanup outcome: `LoadInteractionCleanupOutcome` is only the prepared-load publication fact -> Unit 2 must add the interaction-owned typed cleanup outcome before machines consume cleanup policy.
- `lib/src/frame/frame_capture_service.dart:33` / frame route: selected move preview is captured only into main frame -> Unit 8 must not reroute selected move into overlay.
- `lib/src/frame/overlay_preview_planner.dart:111` / frame route: overlay planner admits marquee/stroke/line/eraser previews and excludes selected move -> Unit 9 must keep marquee overlay-only.
- `tool/guardrails/src/guardrail_registry.dart:188` / guardrail registry: `preview.selected_move_main_repaint` is already registered -> P10 must keep and extend runner-backed preview-route proof instead of replacing it with prose.
- `PLAN.md:8` / roadmap format: each step has a linked document -> this step must add a dedicated `plan/step_47_p10_selection_and_move.md` entry.
- `PLAN.md:12` / roadmap order: step order defines intended implementation order -> append Step 47 after completed Step 46.

## Boundaries

Owner:

Primary interaction behavior owner is `InteractionEngine` under `lib/src/interaction/**`: mode state, draw-style and pointer-policy state, active pointer sessions, pointer sample normalization, selected-move and marquee state machines, preview producer state, interaction revision, typed cleanup request orchestration, and interaction diagnostics trigger points. `PointerToolCleanupCoordinator` owns cleanup effect policy only and is callable only by `InteractionEngine`. `RuntimeRoot` remains the composition root and owns public state snapshots, stream delivery, timestamp cursor, resolver mutation guard, action finalization, load orchestration, command/tool/selection adapters, and frame invalidation bridge. `SelectionKernel` owns selected ids and `selectionRevision`; `EditKernel` owns accepted commits and rollback boundaries; frame, geometry/spatial, diagnostics, and resource owners remain separate.

In Scope:

Repair P10 source-of-truth contradictions before production code; add interaction value types, session model, read port, pointer sample normalizer, selected-move/marquee machines, cleanup coordinator, and runtime composition; migrate preview ownership to interaction while preserving public preview shape and frame routing; replace the minimal load interaction boundary with interaction-backed prepared cleanup; extend edit commit delivery for selection-set effects and internal action intents; finalize public actions only after accepted state; add immutable read adapters and `CommandFactsPort`; implement selected-move, marquee, selection transform/delete, command port remove/clear/text-unknown behavior, tool port settings and pointer dispatch compatibility; implement bounded internal interaction diagnostics; add P10 guardrails, diagrams, graph updates, generated docs/indexes, tests, and final verification.

Out of Scope:

Do not implement P11 draw/line production behavior, P12 eraser/text/context request behavior, P13 Flutter raw pointer routing or active surface lifecycle, async move resolver support, public preview mutation APIs, public interaction/frame/diagnostics internals, or geometry corrupted-row diagnostics. Do not expose `InteractionEngine`, read ports, cleanup coordinator, `CommandFactsPort`, diagnostics code types, frame collaborators, or runtime root internals through the public package barrel. Do not add single-click select/toggle pointer semantics unless a separate source-of-truth change is accepted before implementation. Do not use direct interaction mutation of store or selection owners.

Source of Truth:

The P10 design source of truth is `.design/2026-06-01-p10-selection-and-move.md`; readiness evidence is `.research/2026-06-01-p10-selection-and-move-readiness.md`; phase scope is `docs/implementation/p10_selection_and_move.md`. Public API behavior belongs in `docs/contracts/public_api_v1.md`; pointer/session/cleanup behavior belongs in `docs/contracts/interaction_engine.md`; operation rows belong in `docs/contracts/operation_matrix.md`; load sequencing belongs in `docs/contracts/load_document.md`; diagnostics code routing belongs in `docs/contracts/diagnostics.md`; package and ownership boundaries belong in `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/03_data_model.md`, and `docs/architecture/architecture_graph.yaml`; test and guardrail inventories belong in `docs/verification/tests.md`, `docs/verification/guardrails.md`, and `tool/guardrails/**`. The roadmap source of truth is `PLAN.md` plus this linked step contract.

Compatibility:

The public package remains source-compatible. Existing public constructors and sealed preview/action payload shapes remain valid. `CanvasRuntime.tools`, `commands`, and `contextActionRequests` change from throwing placeholders to P10-supported public behavior: real tool/settings/pointer dispatch, real command port methods in P10 scope, and an empty broadcast context request stream that closes on dispose. P10 keeps `handleDoubleTap` unsupported with an explicit P12-naming `UnsupportedError`; `commitTextEdit` returns false for unknown ids until P12; draw-mode pointer input is a no-op compatibility path except cleanup-capable terminal handling. Internal `SpatialQueryResult`, diagnostics, interaction, and command-fact seams may change only within internal boundaries.

Order Constraints:

Start with Unit 0 source-of-truth repair and graph placeholder split before production interaction code. Then introduce interaction value/session/read/normalizer seams. Then add cleanup coordinator and outcome model. Then migrate preview ownership and frame/public-state publication. Then replace load cleanup boundary. Then extend edit commit delivery and action intent transport before selected-move/marquee terminal commits. Then add runtime action finalization and immutable read adapters. Then implement selected move before marquee because selected move depends on resolver and main-scene proof, while marquee depends on selection-set edit effects and overlay proof. Then expose full P10 public command/tool ports and command facts. Then add diagnostics, guardrails, graph/docs/diagram closure, and final verification. Do not mark `PLAN.md` or unit checkboxes complete during this planning step.

Temporal and all-or-nothing constraints:

Resolver invocation is the only P10 synchronous user callback. `RuntimeRoot` owns the resolver mutation guard and timestamp cursor. Valid selected-move terminal flow is: validate token/epoch and facts, assign resolver request timestamp when needed, enter resolver guard, call resolver once, exit guard, build edit intent, accept through `EditKernel`, cleanup active preview/session, publish atomic public state, assign action timestamp/id, then emit typed action. Reentrant public mutation from resolver throws `StateError` and creates no runtime effects. No-op, stale, invalid, cancel, resolver cancel/error, edit rollback/failure, load, dispose, and command no-op paths emit no action and no action timestamp.

All-or-nothing boundary: `EditKernel` acceptance is the irreversible document/selection point. Validation, read-port facts, resolver call, edit planning, and rollback/no-op detection are fallible before acceptance. After acceptance, preview/session cleanup, public state publication, repaint signaling, and action delivery are failure-contained follow-up work that cannot roll back accepted state. Load success irreversible install occurs only after prepared interaction cleanup completes; load failure does not call interaction cleanup and preserves active interaction state.

## Required Production Declarations

These declarations are part of the contract, not implementation suggestions. The implementer must create or update the named files and primary declarations below unless a prior source-of-truth repair explicitly changes this table. Private helpers may be added only when they remain subordinate to the listed owner and do not create a second source of truth.

| File | Required primary declarations | Unit | Contract constraint |
|---|---|---|---|
| `lib/src/interaction/interaction_engine.dart` | `InteractionEngine` | Unit 1, expanded by Units 3, 4, 8, 9, and 10 | Owns interaction mode, draw style, pointer policy, active session, preview producer state, cleanup orchestration, interaction revision, and public tool-port implementation hooks. Must not import concrete store, `SelectionKernel`, resource internals, frame internals, Flutter, or public runtime implementation internals. |
| `lib/src/interaction/interaction_read_port.dart` | `InteractionReadPort`; immutable fact value types for selected-move start, selected-move commit, marquee start, and marquee commit | Unit 1, implemented in Unit 7 | The only interaction read seam. It exposes intent-specific immutable facts only and no mutable document, draft, store, resource, selection-kernel, frame-cache, public stream, resolver, or edit-session internals. |
| `lib/src/interaction/pointer_session.dart` | `PointerSession`, `PointerSessionKind`, and token/epoch/session-id value types | Unit 1 | Owns active pointer token, controller epoch, session id, pointer id, tool mode, world-space start/current positions, captured selection revision, captured selected ids, captured movable ids, previous selection ids, and last preview value. |
| `lib/src/interaction/pointer_sample_normalizer.dart` | `PointerSampleNormalizer`, `NormalizedPointerSample`, and invalid-terminal cleanup decision value types | Unit 1 | Normalizes constructible public pointer samples and internal/raw terminal facts; does not read document, selection, spatial, resolver, edit, or runtime stream state. |
| `lib/src/interaction/pointer_tool_cleanup_coordinator.dart` | `PointerToolCleanupCoordinator`, `PointerCleanupRequest`, `PointerCleanupReason`, `PointerCleanupOutcome`, preview/session/pending disposition enums | Unit 2 | Effect-policy only; called only by `InteractionEngine`; imports no resolver callbacks, `EditKernel`, action dispatchers, frame repaint buses, concrete store, concrete selection, resources, Flutter, or runtime implementation internals. |
| `lib/src/interaction/move_machine.dart` | `MoveMachine` and selected-move transition/result value types | Unit 8 | Owns selected-move state transitions and returns preview intents, commit intents, diagnostics triggers, or typed cleanup requests. It does not call the resolver, `EditKernel`, action stream, frame engine, store, or selection kernel directly. |
| `lib/src/interaction/select_machine.dart` | `SelectMachine` and marquee transition/result value types | Unit 9 | Owns marquee state transitions and returns preview intents, selection commit intents, diagnostics triggers, or typed cleanup requests. It does not mutate selection directly and does not implement single-click select/toggle behavior. |
| `lib/src/contracts/internal/command_facts_port.dart` | `CommandFactsPort`; immutable command fact value types for selection transform, selection delete, remove element, and clear content | Unit 10 | Runtime-owned high-level command read seam. It must not be imported by `lib/src/interaction/**` and exposes no preview, pointer, cleanup, mode, context-action, mutable document, draft, store, selection-kernel, resource-table, frame-cache, resolver, public stream, or edit-session internals. |
| `lib/src/diagnostics/diagnostic_code.dart` | `DiagnosticCode`, `DiagnosticDataCode`, `DiagnosticInteractionCode`, `InteractionDiagnosticCode` | Unit 11 | Internal diagnostics code family only. `DiagnosticCode` has exactly the `data(CanvasDataErrorCode)` and `interaction(InteractionDiagnosticCode)` factory constructors; none of these declarations are exported from the public package barrel. |
| `lib/src/runtime/runtime_root.dart` | Runtime-owned adapters for `CanvasToolPort`, `CanvasCommandPort`, direct selection API, `InteractionReadPort`, and `CommandFactsPort`; action finalization; resolver guard integration | Units 3, 4, 6, 7, 8, 9, and 10 | May compose owners and publish public state/actions, but must not absorb interaction state-machine ownership, selection ownership, edit rollback ownership, frame ownership, or diagnostics code ownership. |
| `lib/src/api/canvas_runtime.dart` | Non-throwing `tools`, `commands`, and `contextActionRequests` getters | Unit 10 | Public facade only. It must not expose `InteractionEngine`, `RuntimeRoot`, command facts, diagnostics code, cleanup coordinator, or interaction read-port declarations. |

## Required Public Action Payload Proof

P10 must preserve the public typed action payload matrix below. These payloads are public compatibility, so they require direct assertions in `test/api/typed_action_payloads_test.dart` in addition to behavioral command/interaction tests.

| Operation | Public action type | Required payload assertion |
|---|---|---|
| Marquee changed selection | `CanvasActionType.selectMarquee` | `CanvasSelectionActionPayload(previousSelection: previousIds, nextSelection: nextIds, marqueeRectWorld: rectWorld)` and `CanvasActionCommitted.elementIds == nextIds` in document order. |
| Selected move terminal accepted | `CanvasActionType.moveSelection` | `CanvasTransformActionPayload(delta: CanvasTransform.translation(finalDelta), operation: CanvasTransformOperation.move, pivotWorld: null)` and `CanvasActionCommitted.elementIds == movedIds` in document order. |
| `CanvasSelectionPort.moveSelection` accepted | `CanvasActionType.moveSelection` | `CanvasTransformActionPayload(delta: CanvasTransform.translation(delta), operation: CanvasTransformOperation.move, pivotWorld: null)` and `CanvasActionCommitted.elementIds == movedIds` in document order. |
| Rotate/flip selection accepted | `CanvasActionType.transformSelection` | `CanvasTransformActionPayload(delta: commandTransform, operation: rotateClockwise/rotateCounterClockwise/flipHorizontal/flipVertical, pivotWorld: pivot)` and `CanvasActionCommitted.elementIds == eligibleIds` in document order. |
| `deleteSelection` accepted | `CanvasActionType.deleteElements` | `CanvasDeleteActionPayload(removedElementIds: removedIds)` and `CanvasActionCommitted.elementIds == removedIds` in document order. |
| `CanvasCommandPort.removeElement` accepted | `CanvasActionType.deleteElements` | `CanvasDeleteActionPayload(removedElementIds: [id])` and `CanvasActionCommitted.elementIds == [id]`. |
| `CanvasCommandPort.clearContent` removed elements | `CanvasActionType.clearContent` | `CanvasClearActionPayload(removedElementIds: removedElementIds, removedResourceIds: removedResourceIds)` and `CanvasActionCommitted.elementIds == removedElementIds` in document order. |

## Execution Units

### [ ] Unit 0: Source-Of-Truth P10 Scope Repair

Owner:

`docs/contracts/public_api_v1.md`, `docs/contracts/operation_matrix.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/load_document.md`, `docs/contracts/diagnostics.md`, `docs/architecture/02_package_boundaries.md`, `docs/architecture/architecture_graph.yaml`, generated architecture graph views, docs indexes affected by generated-doc sync, and focused graph/docs consistency tests.

Donors:

None. This unit repairs P10 source-of-truth scope before donor material is adapted into production code.

Design Decisions Preserved:

- `D-P10-01`
- `D-P10-12`
- `D-P10-14`
- `D-P10-15`
- `D-P10-16`
- `D-P10-17`
- `D-P10-19`
- `D-P10-20`
- `D-P10-21`

Boundary:

Normative source-of-truth repair only. Do not add production interaction declarations, do not mark graph nodes implemented before declarations exist, and do not update implementation completion checkboxes.

Change:

Document P10-compatible public behavior for unsupported double tap, empty `contextActionRequests`, draw-mode pointer no-op compatibility, tool setting getter/setter cleanup and revision behavior, configured initial tool state without construction-time `interactionRevision` bump, `clearSelectionOnDrawModeEnter` true/false behavior when entering draw mode, deterministic rotate/flip center pivot, `commitTextEdit` unknown-id false behavior, action-after-state ordering, no-op/stale/cancel timestamp silence, cleanup request reasons/outcome fields, expanded load cleanup outcome semantics, internal interaction diagnostics code seam, deferred geometry corrupted-row diagnostics, `pointer_sample_normalizer.dart`, `command_facts_port.dart`, and the forbidden interaction import of command facts. Split architecture graph placeholders so P10 owns non-throwing supported `tools` and empty `contextActionRequests`, while P11/P12/P13 own only deferred draw/context/surface behavior.

Completion Check:

`dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` pass. `dart test test/architecture_graph/phase_closure_checker_test.dart` passes with focused assertions for the source-of-truth repair and facade placeholder splits without requiring full P10 phase closure while interaction implementation nodes still remain future/deferred. `dart run tool/architecture_graph/generate_views.dart --phase P10 --check` passes for generated views produced from the repaired graph. A focused docs or graph assertion proves `geometry.spatial_index.corrupted_rows.report_to_diagnostics` is not required for P10 closure, and graph placeholder assertions prove the whole `CanvasRuntime.tools` and `CanvasRuntime.contextActionRequests` members are no longer treated as later-phase placeholders. Operation matrix proof shows P10 rows explicitly encode action-after-state ordering and no-op/stale/cancel timestamp silence before production interaction code begins.

Depends On:

None.

### [ ] Unit 1: Interaction Value Types And Pointer Admission Seams

Owner:

`lib/src/interaction/interaction_engine.dart`, `lib/src/interaction/interaction_read_port.dart`, `lib/src/interaction/pointer_session.dart`, `lib/src/interaction/pointer_sample_normalizer.dart`, runtime composition surfaces needed to construct the engine, and focused interaction seam tests.

Donors:

- `direct_pointer_tap_tracking`
- `direct_gesture_ownership`
- `foundation_pointer_input_contract`
- `interaction_pointer_session`
- `interaction_pointer_normalizer`
- `interaction_gesture_runtime`

Design Decisions Preserved:

- `D-P10-02`
- `D-P10-10`
- `D-P10-20`

Boundary:

Interaction state and admission declarations only: mode/draw-style/pointer-policy state, active pointer token/epoch/session values, session lifecycle value types, read-port interfaces, public-sample normalization, internal invalid-terminal cleanup decisions, and initial runtime composition. No selected-move/marquee commit behavior, no cleanup coordinator policy, no edit/action bridge, no diagnostics graph closure beyond declaration evidence.

Change:

Introduce the interaction engine facade with initial mode/draw-style/pointer-policy state from `CanvasRuntimeConfig`, a non-public active session model, interaction revision ownership, `InteractionReadPort` fact interfaces, and `PointerSampleNormalizer` that converts constructible public samples to finite normalized world-space samples and exposes an internal seam for invalid terminal cleanup decisions. Convert view-space positions to world-space positions using runtime view camera offset. Keep interactions read-only and free of concrete store, selection, resource, frame, Flutter, and public runtime implementation imports.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/interaction test/interaction` pass for changed interaction owners. A declaration/import proof asserts `interaction_engine.dart`, `interaction_read_port.dart`, `pointer_session.dart`, and `pointer_sample_normalizer.dart` contain the required primary declarations from `Required Production Declarations` and are not replaced by umbrella files or alternate names. `flutter test test/interaction/pointer_session_test.dart` proves one active routed pointer, pointer id and controller epoch admission, stale non-terminal ignore behavior, stale terminal cleanup-only decisions, and world-position conversion using view camera offset. `flutter test test/interaction/pointer_sample_normalizer_test.dart` proves finite public sample acceptance and internal invalid-terminal cleanup decisions without depending on impossible public constructor states. Import-boundary guardrails prove `lib/src/interaction/**` does not import concrete store, selection kernel, resource internals, frame internals, Flutter, or public runtime implementation internals.

Depends On:

Unit 0.

### [ ] Unit 2: Cleanup Coordinator And Outcome Policy

Owner:

`lib/src/interaction/pointer_tool_cleanup_coordinator.dart`, interaction cleanup request/outcome value files, `lib/src/contracts/internal/load_interaction_boundary.dart` outcome type where needed, and cleanup coordinator tests/guardrails.

Donors:

- `direct_gesture_ownership`
- `interaction_gesture_runtime`
- `interaction_move_session`

Design Decisions Preserved:

- `D-P10-02`
- `D-P10-03`

Boundary:

Cleanup policy only. The coordinator is infallible, effect-only, and does not mutate runtime state, call resolvers, call edit, emit actions, schedule repaints, or read frame/store/selection/resource internals. No selected-move/marquee machine behavior except typed cleanup request construction surfaces needed for tests.

Change:

Add typed cleanup requests with reasons for selected move, marquee, mode/tool change, interactive false, prepared load success, dispose, stale/invalid/no-op terminal, resolver cancel/error, edit failure, and post-success commit. Add outcome fields for previous preview kind, preview changed, public state needed, repaint target, active token released, session closed, pending line disposition, pending context tap cleanup, load prepared-before-install, and dispose-before-stream-close. Make `InteractionEngine` the only production caller. After `InteractionEngine`, pointer session, read port, normalizer, and cleanup coordinator declarations exist, update `docs/architecture/architecture_graph.yaml` and generated graph views for those actual declarations without closing later behavior edges.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/interaction test/interaction test/guardrails tool/guardrails` pass for changed owners. A declaration/import proof asserts `pointer_tool_cleanup_coordinator.dart` contains the required primary declarations from `Required Production Declarations`. `dart test test/interaction/pointer_tool_cleanup_coordinator_test.dart` proves all cleanup reasons and outcome fields, including selected-move main repaint, marquee overlay repaint, no-preview/no-repaint cleanup, resolver-error cleanup without action, active-token release, and pending-line preservation when cleanup does not own pending line. Guardrail tests prove the coordinator imports none of resolver callbacks, `EditKernel`, action dispatchers, frame repaint buses, concrete store, concrete selection, resource internals, or Flutter, and that production coordinator calls originate only from `InteractionEngine`. `dart test test/architecture_graph/phase_closure_checker_test.dart` passes with focused assertions for the now-existing interaction engine, read-port, pointer-session, normalizer, and cleanup coordinator declarations without requiring unrelated P10 behavior edges to close before their units land. `dart run tool/architecture_graph/generate_views.dart --phase P10 --check` passes after generated views are updated for those graph changes.

Depends On:

Unit 1.

### [ ] Unit 3: Interaction-Owned Preview Publication

Owner:

`lib/src/interaction/interaction_engine.dart`, `lib/src/runtime/runtime_root.dart`, frame capture bridge inputs where preview is read, preview public-state tests, and affected architecture graph/diagram docs.

Donors:

- `direct_gesture_ownership`
- `interaction_gesture_runtime`

Design Decisions Preserved:

- `D-P10-07`
- `D-P10-08`
- `D-P10-09`

Boundary:

Preview source-of-truth migration and publication only. No selected-move or marquee terminal commit behavior, no action emission, and no public preview mutation API.

Change:

Move current `CanvasPreviewState` and preview revision ownership from `RuntimeRoot` local fields into `InteractionEngine`. Keep `RuntimeRoot.preview`, `CanvasRuntime.preview`, `CanvasRuntimeState`, and frame capture reading the same delegated value. Increment preview revision only when preview value changes or active preview cleanup clears/replaces preview; cleanup against already-empty preview is public-state silent. Preserve `CanvasSelectedMovePreview(delta)` as delta-only and marquee as overlay-preview data without ids or session state.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/interaction lib/src/runtime lib/src/frame test/interaction test/frame test/api` pass for changed owners. `dart test test/interaction/preview_public_state_test.dart` proves preview-only pointer changes publish `state.revisions.preview` without changing document, selection, resourceVisual, interaction, or viewCamera revisions and without actions; it also proves cleanup against already-empty preview is silent. `dart test test/api_contract/preview_state_sealed_union_test.dart` still proves public preview shape and selected-move delta-only payload. Focused frame tests prove selected-move preview feeds main capture only and marquee preview feeds overlay only. `dart test test/architecture_graph/phase_closure_checker_test.dart` passes with focused assertions for now-existing preview ownership declarations, and `dart run tool/architecture_graph/generate_views.dart --phase P10 --check` passes after generated views are updated for those graph changes.

Depends On:

Units 1 and 2.

### [ ] Unit 4: Load And Dispose Interaction Cleanup

Owner:

`lib/src/runtime/runtime_root.dart`, `lib/src/contracts/internal/load_interaction_boundary.dart`, interaction load/dispose cleanup adapters, load tests, `docs/diagrams/seq_load_document_success.mmd`, and `docs/diagrams/seq_load_document_failure.mmd`.

Donors:

- `interaction_gesture_runtime`
- `staged_load_runtime_materialization`

Design Decisions Preserved:

- `D-P10-03`
- `D-P10-18`

Boundary:

Prepared load success/failure and dispose cleanup orchestration. Do not implement selected-move/marquee terminal commits, command port behavior, or action emission. Preserve P6 load atomicity and failure preservation.

Change:

Replace the minimal no-op load interaction boundary with an interaction-backed boundary. On load success, `RuntimeRoot` prepares the load, requests interaction cleanup before document install, lets `InteractionEngine` route a `preparedLoadSuccess` request through the coordinator and apply owned cleanup, consumes the prepared load through `EditKernel`, clears selection according to load contract, publishes one atomic public state, emits no action, and never calls interaction again after install for that load. Load failure preserves active session, preview, pending line, pointer normalizer state, and public state. Dispose asks interaction for cleanup before stream close and emits no resolver/edit/action.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/runtime lib/src/interaction test/runtime test/edit test/interaction` pass for changed owners. `dart test test/runtime/load_interaction_cleanup_test.dart` proves prepared load success cleanup occurs before document install for active selected-move and marquee sessions, no post-install interaction call occurs, no resolver/edit terminal path or action runs during cleanup, and load failure preserves active interaction state. Dispose-focused tests prove final cleanup state publishes only when preview/session cleanup changes observable state before streams close and no resolver/edit/action runs. Updated load diagrams pass docs checks.

Depends On:

Units 2 and 3.

### [ ] Unit 5: EditKernel Selection Effects And Action Intents

Owner:

`lib/src/edit/**`, `lib/src/contracts/internal/commit_delivery.dart`, touched-set/commit-plan model files, runtime commit callers needed to accept new delivery facts, and edit bridge tests.

Donors:

- `foundation_action_event_immutability`
- `interaction_mutation_boundary`

Design Decisions Preserved:

- `D-P10-05`
- `D-P10-14`

Boundary:

Edit commit model and internal delivery effects only. No public action stream emission inside `EditKernel`, no pointer state machines, no command/tool facade exposure. Direct public selection APIs remain direct `SelectionKernel` operations and do not use fake edit plans.

Change:

Extend `CommitPlan.hasChanges` to account for selection-set effects as well as document deltas. Represent selection replacement separately from deletion pruning. Carry accepted internal action intents through commit delivery without public ids/timestamps. Drop action intents on rollback/no-op plans. Expose accepted delivery facts needed for `RuntimeRoot` to publish state and then emit actions in contract order.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/edit lib/src/contracts/internal test/edit test/runtime` pass for changed owners. Focused edit tests prove selection-set-only marquee commits are accepted with selection revision changes and no document revision delta; document deletion/clear prunes selection atomically; no-op or rollback plans drop action intents and emit no delivery facts that could become public actions; existing low-level edit guardrail/tests still prove low-level `CanvasEdit` mutations do not emit user actions.

Depends On:

Unit 0.

### [ ] Unit 6: Runtime Action Finalization And Timestamp Ordering

Owner:

`lib/src/runtime/runtime_root.dart`, action intent value/adapters under internal contracts if needed, `lib/src/contracts/public/canvas_actions.dart` only if public declarations require contract-consistent additions, and action/timestamp tests.

Donors:

- `foundation_action_event_immutability`
- `interaction_event_dispatcher`

Design Decisions Preserved:

- `D-P10-14`

Boundary:

Runtime-owned public action finalization: state-first publication, runtime-local action id, timestamp resolution, and typed stream emission. No state-machine commit behavior except testable internal intents. No public action emission from `EditKernel` or interaction machines directly.

Change:

Make `RuntimeRoot` consume accepted internal action intents after `EditKernel` acceptance, publish atomic public state first, resolve action timestamp through the runtime cursor, assign monotonically increasing runtime-local action id, and emit typed `CanvasActionCommitted` events on `actions`. Ensure rejected paths and no-op command/interaction paths emit no action and no action timestamp. Update architecture graph action-route edges and any action-order diagrams in this same unit after the route is implemented.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/runtime lib/src/contracts test/api test/interaction test/guardrails tool/guardrails` pass for changed owners. `dart test test/interaction/commands_emit_user_actions_test.dart` proves typed action events emit only after accepted state for move/marquee/transform/delete/remove/clear intents. `dart test test/api/typed_action_payloads_test.dart` proves runtime action finalization preserves the public payload families and `CanvasActionCommitted.elementIds` fields required by `Required Public Action Payload Proof`. `dart test test/api/runtime_timestamp_order_test.dart` proves resolver request timestamps, action timestamps, nullable/backwards hints, and no-op/cancel/load/dispose timestamp silence. A runner-backed action-after-state guardrail fails on a fixture that emits an action before accepted public state. `dart test test/architecture_graph/phase_closure_checker_test.dart` and docs checks triggered by changed action diagrams pass for the implemented action-route edge without requiring full P10 phase closure before later graph obligations are implemented. `dart run tool/architecture_graph/generate_views.dart --phase P10 --check` passes after generated views are updated for the action-route graph change.

Depends On:

Unit 5.

### [ ] Unit 7: Immutable Interaction Read Adapter

Owner:

`lib/src/interaction/interaction_read_port.dart`, runtime-local read adapter code, selection/geometry/spatial/document read model adapters, and read-port tests/guardrails.

Donors:

- `geometry_interactive_geometry`
- `interaction_move_session`
- `interaction_mutation_boundary`

Design Decisions Preserved:

- `D-P10-06`
- `D-P10-10`
- `D-P10-17`

Boundary:

Read-only fact bundles for interaction. No mutation, no resolver callbacks, no edit sessions, no frame cache reads, no public streams, and no high-level command facts.

Change:

Implement `InteractionReadPort` using immutable, batched, intent-specific facts for selected-move start, selected-move commit, marquee start, and marquee commit. Read from existing selection facts, geometry/spatial query APIs, and committed document read models without exposing concrete kernels or mutable/draft objects to interaction. Preserve document-order ids, controller epoch, selection revision, movable/selectable/deleted/stale filtering, marquee world rect normalization, hit-test fallback diagnostics trigger facts, and query budget/stale candidate facts needed by Unit 11. Update architecture graph read-port adapter edges after the adapter exists.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/interaction lib/src/runtime lib/src/geometry test/interaction test/runtime test/guardrails tool/guardrails` pass for changed owners. `dart test test/interaction/interaction_read_port_test.dart` proves each fact bundle returns immutable data, document-order ids, world-rect marquee facts, stale/deleted candidate handling, locked-selectable marquee behavior, and no mutable document/draft/store/resource/selection internals. Import guardrails reject direct interaction imports of concrete store, `SelectionKernel`, resource internals, frame internals, public streams, and command facts. `dart test test/architecture_graph/phase_closure_checker_test.dart` passes for the implemented read-port adapter edges without requiring full P10 phase closure before later graph obligations are implemented. `dart run tool/architecture_graph/generate_views.dart --phase P10 --check` passes after generated views are updated for the read-port graph change.

Depends On:

Unit 1.

### [ ] Unit 8: Selected Move State Machine And Resolver Commit

Owner:

`lib/src/interaction/move_machine.dart`, `lib/src/interaction/interaction_engine.dart`, runtime resolver bridge/guard use, selected-move commit integration through Units 5 and 6, frame repaint proof tests, resolver guardrails, `docs/diagrams/state_pointer_session.mmd`, `docs/diagrams/state_selected_move.mmd`, `docs/diagrams/seq_selected_move_preview_commit.mmd`, and `docs/diagrams/seq_selected_move_cancel.mmd`.

Donors:

- `foundation_pointer_input_contract`
- `foundation_action_event_immutability`
- `interaction_event_dispatcher`
- `interaction_gesture_runtime`
- `interaction_move_session`
- `interaction_mutation_boundary`

Design Decisions Preserved:

- `D-P10-02`
- `D-P10-03`
- `D-P10-05`
- `D-P10-08`
- `D-P10-10`
- `D-P10-11`
- `D-P10-13`
- `D-P10-14`
- `D-P10-17`

Boundary:

Move-mode selected-move pointer behavior only. Do not implement marquee terminal commit, command-port `moveSelection`, draw/line/eraser/text/context behavior, or public preview payloads beyond delta-only selected move.

Change:

On pointer down in move mode, admit selected move only when selected ids exist, at least one selected element is movable, and the top visible/selectable hit at the world position is one of the movable selected ids. Capture selected and movable ids in document order, selection revision, pointer token, and start world position. Publish delta-only selected-move preview to main frame on movement. On valid terminal up, compute proposed world delta, reject zero/stale/invalid/empty/no-effective-change paths with cleanup only, call the configured move resolver exactly once only after valid terminal facts, use `RuntimeRoot` resolver guard and request timestamp, handle resolver cancel/error/non-finite delta with cleanup/no edit/no action, commit accepted deltas through `EditKernel`, apply `CanvasTransform.translation(delta).multiply(oldTransform)`, cleanup after accepted edit, publish state, and emit typed move action through runtime finalization. Update selected-move and pointer-session diagrams in this same unit to match the implemented state/call order.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/interaction lib/src/runtime test/interaction test/frame test/guardrails tool/guardrails` pass for changed owners. A declaration/import proof asserts `move_machine.dart` contains the required primary declarations from `Required Production Declarations`. `dart test test/interaction/move_machine_test.dart` proves admission, delta preview, same-delta no-op preview, resolver request shape, cancel, stale terminal, invalid terminal, zero delta, empty movable set, resolver error cleanup/rethrow, edit failure cleanup, accepted commit transform math, post-success cleanup, and the selected-move action intent facts needed for `CanvasActionType.moveSelection`. `dart test test/api/typed_action_payloads_test.dart` proves accepted selected-move terminal payload shape and element-id ordering from `Required Public Action Payload Proof`. `dart test test/interaction/move_resolver_reentrancy_test.dart` proves reentrant public mutation throws `StateError` and creates no runtime effects. `dart test test/interaction/move_resolver_not_called_on_cancel_cleanup_test.dart` proves resolver is not called for cancel, load, mode change, interactive false, stale, invalid, dispose, or preview-only paths. `dart test test/frame/selected_move_main_repaint_test.dart` proves selected-move preview is main-only. Guardrails prove stale terminals cannot edit/action and resolver is unreachable on cancel paths. `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` pass after selected-move and pointer-session diagrams are updated.

Depends On:

Units 2, 3, 5, 6, and 7.

### [ ] Unit 9: Marquee Selection State Machine

Owner:

`lib/src/interaction/select_machine.dart`, `lib/src/interaction/interaction_engine.dart`, marquee read/commit integration through Units 5 and 6, frame overlay proof tests, marquee interaction tests, `docs/diagrams/state_select_marquee.mmd`, and `docs/diagrams/seq_marquee_select.mmd`.

Donors:

- `foundation_action_event_immutability`
- `geometry_interactive_geometry`
- `interaction_event_dispatcher`
- `interaction_gesture_runtime`
- `interaction_move_session`
- `interaction_mutation_boundary`

Design Decisions Preserved:

- `D-P10-02`
- `D-P10-03`
- `D-P10-05`
- `D-P10-09`
- `D-P10-10`
- `D-P10-14`
- `D-P10-17`

Boundary:

Move-mode marquee pointer behavior only. Do not add single-click select/toggle semantics, selected-move resolver behavior, draw/line/eraser/text/context behavior, or direct `SelectionKernel` mutation from interaction.

Change:

When move-mode pointer down is not admitted as selected move, open a marquee session, capture previous selected ids in document order, and publish zero-area marquee overlay preview. On movement, normalize the world rect and publish overlay preview only when the rect changes. On valid terminal up, read marquee commit facts through `InteractionReadPort`, query spatial/exact filtering, include visible/selectable content including locked selectable elements, skip stale/deleted candidates, normalize ids to document order, cleanup-only when next selection equals previous selection, and commit changed selection replacement through `EditKernel` selection-set effects. Emit typed `selectMarquee` action only after accepted state. Update marquee state/sequence diagrams in this same unit to match the implemented state/call order.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/interaction lib/src/runtime test/interaction test/frame` pass for changed owners. A declaration/import proof asserts `select_machine.dart` contains the required primary declarations from `Required Production Declarations`. `dart test test/interaction/select_machine_test.dart` proves marquee overlay preview, normalized world rect, same-rect no-op preview, spatial/exact filtering, locked selectable inclusion, stale/deleted candidate skipping, unchanged-selection cleanup-only behavior, changed-selection edit commit, previous/next selection action intent facts, and action element ids in document order. `dart test test/api/typed_action_payloads_test.dart` proves accepted marquee payload shape and element-id ordering from `Required Public Action Payload Proof`. Frame overlay tests prove marquee preview remains overlay-only and selected-move remains excluded from overlay capture. `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` pass after marquee diagrams are updated.

Depends On:

Units 2, 3, 5, 6, 7, and 8.

### [ ] Unit 10: Public Selection, Command, And Tool Ports

Owner:

`lib/src/runtime/runtime_root.dart`, `lib/src/api/canvas_runtime.dart`, `lib/src/contracts/internal/command_facts_port.dart`, runtime command/selection/tool adapters, public API tests, and command/tool guardrails.

Donors:

- `foundation_pointer_input_contract`
- `foundation_action_event_immutability`
- `interaction_event_dispatcher`
- `interaction_gesture_runtime`
- `interaction_mutation_boundary`

Design Decisions Preserved:

- `D-P10-04`
- `D-P10-05`
- `D-P10-12`
- `D-P10-15`
- `D-P10-16`
- `D-P10-19`
- `D-P10-20`
- `D-P10-21`

Boundary:

P10 public facade behavior and runtime-owned command facts. Interaction machines may be consumed through `CanvasToolPort.handlePointer`, but draw/line/eraser/text/context production behavior remains out of scope. Direct selection APIs stay direct `SelectionKernel` operations.

Change:

Expose non-throwing `CanvasRuntime.tools`, `CanvasRuntime.commands`, and `CanvasRuntime.contextActionRequests`. Add `CommandFactsPort` under `lib/src/contracts/internal/` for selection transform/delete, remove element, and clear content immutable facts, consumed only by runtime-owned adapters and forbidden to interaction. Implement direct selection set/toggle/clear/selectAll revision-domain behavior with no P10 actions. Implement selection move/rotate/flip/delete commands through `EditKernel`, eligible ids in document order, finite/range delta validation, center pivot for rotate/flip, deletion pruning, no-op silence, and typed action payloads. Implement command port `removeElement`, `clearContent`, and `commitTextEdit` unknown-id false behavior. Implement tool getters/setters, configured initial tool state visible at runtime construction without incrementing `interactionRevision`, interaction revision increments only on effective post-construction changes, mode/tool/pointer-policy cleanup, draw-mode pointer no-op compatibility, `clearSelectionOnDrawModeEnter == true` selection clearing through `SelectionKernel` in the same public state when entering draw mode, flag-false/no-op mode-change silence, `handleDoubleTap` unsupported compatibility, and an empty broadcast context request stream that closes on dispose. Update command/tool facade graph edges and generated views in the same unit after the public facades are implemented.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/api lib/src/runtime lib/src/contracts/internal test/api test/runtime test/interaction test/guardrails tool/guardrails` pass for changed owners. A declaration/import proof asserts `command_facts_port.dart` contains the required primary declarations from `Required Production Declarations`, `CanvasRuntime.tools`, `CanvasRuntime.commands`, and `CanvasRuntime.contextActionRequests` are non-throwing facade getters, and no internal interaction/runtime declarations are exported from the public barrel. `dart test test/api/selection_port_test.dart` proves direct selection revision domains and no action emission. `dart test test/api/selection_transform_commands_test.dart` proves move/rotate/flip/delete eligibility, transform math, center pivot, document order, no-op behavior, selection pruning, validation errors, and typed actions. `dart test test/api/command_port_actions_test.dart` proves remove/clear/text-unknown behavior and action payloads. `dart test test/api/typed_action_payloads_test.dart` proves selection move, rotate, flip, delete, remove element, and clear content payload shapes and element-id ordering from `Required Public Action Payload Proof`. `dart test test/api/tool_port_settings_test.dart` proves configured initial mode/draw style/pointer policy are visible without a construction-time `interactionRevision` bump; getter values and setter no-ops are stable; effective setter changes increment `interactionRevision`; mode/tool/pointer-policy changes cleanup active sessions; entering draw mode with `clearSelectionOnDrawModeEnter == true` clears selection through `SelectionKernel` in the same public state with no action or timestamp; flag-false and no-op mode changes do not clear selection or publish; draw-mode pointer input stays no-op compatible; double tap throws the P12-naming `UnsupportedError`; and `contextActionRequests` is broadcast-empty and closes on dispose. `dart test test/runtime/command_facts_port_test.dart` proves immutable command fact bundles, command document order, center pivot, removed resources, and no interaction dependency. Guardrails prove interaction does not import `command_facts_port.dart`, public facades do not export internals, and tool-port compatibility paths do not emit unexpected request/action/timestamp/state effects. `dart test test/architecture_graph/phase_closure_checker_test.dart` passes for command facts, command port, tool port, and context request facade edges without requiring full P10 phase closure before residual graph obligations are implemented. `dart run tool/architecture_graph/generate_views.dart --phase P10 --check` passes after generated views are updated for the command/tool facade graph changes.

Depends On:

Units 0, 1, 2, 5, 6, 8, and 9.

### [ ] Unit 11: Interaction Diagnostics Route

Owner:

`lib/src/diagnostics/diagnostic_code.dart`, existing diagnostics hub/event/record internals, interaction diagnostics trigger points, diagnostics tests, and diagnostics graph/docs.

Donors:

None. This unit implements the diagnostics seam specified by the P10 design rather than adapting donor interaction behavior.

Design Decisions Preserved:

- `D-P10-17`

Boundary:

Internal reliability diagnostics only. Do not export diagnostics code types publicly, do not emit public actions, do not affect commit acceptance, and do not log document content, text values, resource bytes, or resolver-provided sensitive payloads.

Change:

Add internal sealed `DiagnosticCode` with `DiagnosticCode.data(CanvasDataErrorCode code)` and `DiagnosticCode.interaction(InteractionDiagnosticCode code)` backed by data and interaction variants. Change internal `DiagnosticEvent.code` and `DiagnosticRecord.code` to `DiagnosticCode`, wrapping existing data diagnostics. Add internal `InteractionDiagnosticCode` values: `hitTestFallbackObserved`, `interactionQueryBudgetExceeded`, `staleCandidateRejected`, `staleTerminalRejected`, `invalidTerminalCleanup`, `selectedMoveStartDeniedNotMovable`, and `resolverReentrantMutationRejected`. Emit bounded sanitized reliability events from interaction/read/resolver guard paths and update the interaction diagnostics graph edge after declarations exist.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics lib/src/diagnostics lib/src/interaction test/diagnostics test/interaction` pass for changed owners. A declaration/import proof asserts `diagnostic_code.dart` contains the required primary declarations from `Required Production Declarations` and none are exported from the public package barrel. `dart test test/diagnostics/interaction_diagnostics_test.dart` proves all P10 interaction codes can be recorded internally with sanitized details, no public action/state/timestamp effects, codec/data diagnostics remain wrapped as data codes, and neither `DiagnosticCode` nor `InteractionDiagnosticCode` is exported from the public barrel. `dart test test/architecture_graph/phase_closure_checker_test.dart` passes with focused assertions for `interaction.engine.reliability_events.report_to_diagnostics`, and `dart run tool/architecture_graph/generate_views.dart --phase P10 --check` passes after generated views are updated for that diagnostics graph change while the deferred geometry corrupted-row diagnostics route remains outside P10.

Depends On:

Units 7, 8, and 9.

### [ ] Unit 12: P10 Guardrail Enforcement

Owner:

`tool/guardrails/src/**`, `test/guardrails/**`, `docs/verification/guardrails.md`, guardrail registry/executor entries, and negative fixtures.

Donors:

None. This unit enforces P10 boundaries and fixture quarantine; donor-adapted behavior is proven by the production/test units above.

Design Decisions Preserved:

- `D-P10-02`
- `D-P10-03`
- `D-P10-05`
- `D-P10-06`
- `D-P10-08`
- `D-P10-09`
- `D-P10-13`
- `D-P10-14`
- `D-P10-19`
- `D-P10-20`

Boundary:

Executable repository-local enforcement for P10 invariants. Fixture-only names and bypass values must remain in guardrail test surfaces, not production docs, public API registries, schemas, generated docs, or durable runtime code.

Change:

Register and implement guardrails for interaction import boundaries, `InteractionReadPort` immutable fact exposure, interaction forbidden import of `command_facts_port.dart`, cleanup coordinator dependency bans, coordinator caller-origin, resolver-not-called on cancel/stale/invalid/load/dispose/mode/interactive paths, stale terminal no edit/action, action-after-state order, selected-move main-only preview, marquee overlay-only preview, tool-port P10 compatibility, and fixture quarantine for step/phase scheduling metadata in production names/comments.

Completion Check:

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics tool/guardrails test/guardrails` pass for changed guardrail owners. Focused guardrail tests prove every P10 guardrail id is registered, runner-backed or structurally checked as appropriate, fails on a negative fixture containing the forbidden pattern/path/order, and passes positive fixtures. `dart test test/guardrails/blocking_suite_test.dart` proves P10 guardrails are included in the blocking suite. `dart run tool/guardrails/run.dart --suite=blocking` passes and includes P10 interaction/action/preview/load guardrail ids plus existing public API and frame preview route guardrails.

Depends On:

Units 1, 2, 6, 7, 8, 9, 10, and 11.

### [ ] Unit 13: Graph, Diagrams, Docs, And Implementation Inventory

Owner:

`docs/architecture/architecture_graph.yaml`, generated architecture graph views, residual P10 diagrams not owned by earlier units, `docs/implementation/p10_selection_and_move.md`, `docs/verification/tests.md`, `docs/verification/guardrails.md`, generated docs indexes, `PLAN.md`, and this step file.

Donors:

None. This unit aligns source-of-truth inventories after donor use has already been declared and proven in the owning implementation units.

Design Decisions Preserved:

- `D-P10-01`
- `D-P10-17`
- `D-P10-21`

Boundary:

Residual durable source-of-truth alignment after production declarations and executable checks exist. Do not create temporary implementation notes and do not mark roadmap/unit checkboxes complete until final verification passes in Unit 14.

Change:

Repair any residual graph, diagram, implementation inventory, verification inventory, guardrail docs, and generated-doc alignment not already owned by Units 2, 3, 4, 6, 7, 8, 9, 10, 11, or 12. Regenerate graph views and docs indexes. Update P10 implementation inventory, verification tests, and guardrail docs to the concrete test/guardrail paths added by the implementation.

Completion Check:

`dart run tool/architecture_graph/check.dart --phase P10` and `dart run tool/architecture_graph/generate_views.dart --phase P10 --check` pass after residual graph and generated views are aligned. `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` pass after residual docs, diagrams, verification inventories, and generated indexes are aligned. The diff does not mark `PLAN.md` Step 47 or execution-unit checkboxes complete; those completion signals belong to Unit 14 after final verification evidence.

Depends On:

Units 0 through 12.

### [ ] Unit 14: Final P10 Verification

Owner:

Full changed production/test/tool/docs surfaces from Units 0 through 13 and final verification commands.

Donors:

None. This unit verifies the completed P10 change and does not adapt additional donor material.

Design Decisions Preserved:

- `D-P10-01` through `D-P10-21`

Boundary:

Final verification only after all implementation units are complete. Do not use this unit to add new behavior; failures must be repaired in the owning earlier unit.

Change:

Run the full P10 verification set, repair owner-scoped failures, and confirm that P10 did not complete P11/P12/P13 behavior early or weaken public API compatibility. Confirm no interaction production file directly mutates store or selection, no cleanup coordinator path calls resolver/edit/action/frame, no stale/invalid/no-op terminal reaches `EditKernel`, no cancel/load/dispose path calls the move resolver, no action emits before accepted state, no public preview includes internal ids/session data, and no public internals are exported. If any final verification check fails, stop completion and repair the failure in the owning earlier unit. After all final verification checks pass, update `docs/implementation/p10_selection_and_move.md` checklist/completion status, mark `PLAN.md` Step 47 complete, and mark completed execution-unit checkboxes in this step file in the same final implementation change.

Completion Check:

`dart analyze`, `dcm analyze .`, and scoped `dcm calculate-metrics lib/src/interaction lib/src/runtime lib/src/api lib/src/edit lib/src/contracts lib/src/diagnostics test/interaction test/api test/runtime test/edit test/frame test/diagnostics test/guardrails tool/guardrails` pass from the repository root. Focused tests named by Units 1 through 12 pass, including `dart test test/api/typed_action_payloads_test.dart`. `dart run tool/guardrails/run.dart --suite=blocking` passes with P10 guardrails present. `dart run tool/architecture_graph/check.dart --phase P10`, `dart run tool/architecture_graph/generate_views.dart --phase P10 --check`, `dart run docs/tool/sync_generated_docs.dart --check`, and `dart run docs/tool/check_docs.dart` pass. Public API compile/export guardrails prove no internal interaction, diagnostics, command fact, frame, or runtime root surface is exported. The final implementation diff updates `docs/implementation/p10_selection_and_move.md` completion/checklist state, marks `PLAN.md` Step 47 checked, and marks each completed `### [x] Unit N` checkbox only after this final verification evidence is available.

Depends On:

Unit 13.
