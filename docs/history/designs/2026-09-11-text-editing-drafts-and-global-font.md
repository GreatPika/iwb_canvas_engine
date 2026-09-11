---
schema: architecture-design/v4
date: 2026-09-11
commit: a1e67ebfaddc1a0022d8590b68ea8f42163b0bfd
branch: main
disposition: READY_FOR_CONTRACT
outcome: R-001
---

# Design: Text editing drafts, atomic text creation, and runtime default font

## Basis

### Sources

| ID | Kind | Locator | Use |
| --- | --- | --- | --- |
| S-001 | user | user request | Accepted solution and successive Numicod requirements in this conversation, including the instruction to author the complete selected design without checkpoints or invented alternatives. |
| S-002 | research | `docs/history/research/2026-09-11-text-editing-drafts-and-global-font.md` | Historical investigation of entry, draft, overlay, confirmation, conflict, font, and verification owners; checked against current sources. |
| S-003 | other | `/tmp/iwb-text-design-codebase-design-SKILL.md` | Read-only retrieved source from https://github.com/mattpocock/skills/blob/main/skills/engineering/codebase-design/SKILL.md; user-supplied design guidance: keep orchestration behind the existing session interface and verify it through consumer-visible behavior. |
| S-004 | repository | `AGENTS.md` | Ownership, compatibility, planning lifecycle, and verification rules. |
| S-005 | repository | `docs/README.md` | Current documentation authority routing. |
| S-006 | repository | `docs/planning/README.md` | Active design and subsequent contract lifecycle. |
| S-007 | repository | `docs/contracts/public_api_v1.md` | Public signatures, confirmation, no-op, lease, and application history contracts. |
| S-008 | repository | `docs/architecture/01_runtime_ownership.md` | Runtime/session, frame, and surface ownership. |
| S-009 | repository | `docs/architecture/02_package_boundaries.md` | Contracts-led dependency direction and test ownership. |
| S-010 | repository | `docs/_registry/public_api_v1.yaml` | Canonical exported-name inventory. |
| S-011 | repository | `lib/src/contracts/public/canvas_text_editing.dart` | Existing final session and interface port declarations. |
| S-012 | repository | `lib/src/contracts/public/canvas_commit.dart` | Existing immutable requests and synchronous accept/cancel protocol. |
| S-013 | repository | `lib/src/contracts/public/canvas_runtime.dart` | Runtime configuration and low-level edit declarations. |
| S-014 | repository | `lib/src/runtime/runtime_root.dart` | Composition, session lifecycle, prepared commits, font projection, and common delivery. |
| S-015 | repository | `lib/src/interaction/interaction_engine.dart` | Current text request guard and consumption. |
| S-016 | repository | `lib/src/interaction/interaction_request_registry.dart` | Issued request identity and captured guard facts. |
| S-017 | repository | `lib/src/surface/text_editing_overlay.dart` | Stock editor, input-object lifetime, double-tap subscription, focus-loss and Escape paths. |
| S-018 | repository | `lib/src/edit/edit_kernel.dart` | Synchronous edits and deferred prepared interaction installation. |
| S-019 | repository | `lib/src/edit/edit_session.dart` | Existing sparse insertion and layer-default semantics. |
| S-020 | repository | `lib/src/frame/frame_text_layout_measurer.dart` | Single text layout and layout-key construction owner. |
| S-021 | repository | `lib/src/frame/render_element_record.dart` | Frame facts to text render input and key. |
| S-022 | repository | `lib/src/codec/schema_v1_encoder.dart` | Serialization of nullable per-element font family. |
| S-023 | repository | `docs/verification/tests.md` | Behavioral proof owners and external consumer harness rules. |
| S-024 | repository | `docs/contracts/operation_matrix.md` | Cross-owner effects, stale/no-op/changed terminals, and ordering. |
| S-025 | repository | `docs/contracts/edit_kernel.md` | Prepared package, final comparison, installation, and failure boundary. |
| S-026 | repository | `tool/guardrails/src/public_api_registry.dart` | Direct consumer of the exported-name authority. |
| S-027 | repository | `tool/guardrails/src/public_api_checks.dart` | Actual namespace versus registry parity enforcement. |
| S-028 | repository | `tool/guardrails/src/text_surface_guardrail_checks.dart` | Measurement and Flutter owner constraints. |
| S-029 | repository | `architecture/decisions/README.md` | ADR lifecycle and distinction between retained rationale and current behavior. |
| S-030 | repository | `architecture/decisions/ADR-0010-runtime-text-edit-session.md` | Retained runtime/frame/surface text ownership rationale. |
| S-031 | repository | `architecture/decisions/ADR-0003-store-finalized-edit-transactions.md` | Retained finalization, atomicity, and net-no-op rationale. |
| S-032 | repository | `architecture/decisions/ADR-0007-immutable-frame-planning-and-caches.md` | Retained immutable frame and cache ownership rationale. |
| S-033 | repository | `.agents/skills/architecture-design/SKILL.md` | Requested artifact workflow and design-only write boundary, subject to S-001's explicit workflow override. |
| S-034 | repository | `docs/architecture/architecture_graph.yaml` | Existing owner graph; this design does not introduce a new graph node. |
| S-035 | repository | `lib/src/contracts/public/canvas_actions.dart` | Existing editText and deletion action payloads; actions are notifications rather than history. |
| S-036 | repository | `lib/src/runtime/runtime_interaction_read_adapter.dart` | Visible content text guard admission. |

### Source Coverage

| Kind | Sources or none |
| --- | --- |
| prior_design | none |
| research | S-002 |
| plan | none |
| user | S-001 |
| repository | S-004, S-005, S-006, S-007, S-008, S-009, S-010, S-011, S-012, S-013, S-014, S-015, S-016, S-017, S-018, S-019, S-020, S-021, S-022, S-023, S-024, S-025, S-026, S-027, S-028, S-029, S-030, S-031, S-032, S-033, S-034, S-035, S-036 |
| other | S-003 |

### Evidence

| ID | Source | Locator | Observed fact |
| --- | --- | --- | --- |
| E-001 | S-011 | `lines 108-179` | The final session exposes text mutation and bool/void completion; the abstract interface port admits request-derived candidates and has no ID start, formatting mutation, or typed completion. |
| E-002 | S-014 | `lines 4719-4790` | Candidate creation captures current guard and frame facts; session style reads the captured base facts. |
| E-003 | S-017 | `lines 239-302` | The same session identity retains editing objects; a new identity installs new controller/focus state. |
| E-004 | S-017 | `lines 323-361` | Equal live/controller text leaves the editing value untouched; a different string collapses selection and clears composition. |
| E-005 | S-014 | `lines 1511-1645` | Current text confirmation guards, checks text equality, prepares an update, resolves a full before/after request, installs, and delivers; formatting is not part of its input. |
| E-006 | S-015 | `lines 199-255` | Existing guards compare kind, epoch, generation, and element revision; rejected known requests are consumed. |
| E-007 | S-014 | `lines 4662-4713` | Current consumed-request cleanup closes a matching stale active session, which must change for the accepted retention requirement. |
| E-008 | S-012 | `lines 13-80` | Confirmation and lease callbacks are synchronous; request snapshots contain document revision, summary, and selected-before IDs. |
| E-009 | S-012 | `lines 105-117` | Existing deletion confirmation carries immutable original entries with placement via CanvasCommitElementEntry. |
| E-010 | S-018 | `lines 91-118` | Ordinary edit callbacks finish synchronously and install accepted changes before returning; they cannot span user input. |
| E-011 | S-018 | `lines 170-217` | The existing deferred interaction route prepares a closed private package before later consume/discard. |
| E-012 | S-019 | `lines 630-674` | Sparse addElement reuses layer admission and records an insertion; a missing named layer can be admitted and omitted placement uses the existing default rules. |
| E-013 | S-019 | `lines 1074-1089` | Omitted layer chooses the last content layer or default-layer when no layer exists. |
| E-014 | S-013 | `lines 25-49` | Runtime config has no global font property. |
| E-015 | S-014 | `lines 819-822` | Store-to-frame projection forwards nullable family and independently requests measured layout. |
| E-016 | S-014 | `lines 923-984` | Initial and draft measurement construct inputs from facts, including family and formatting. |
| E-017 | S-020 | `lines 80-118` | Cache keys and TextPainter receive the same input family and B/I/U. |
| E-018 | S-021 | `lines 265-307` | Text render rows derive their layout input and cache key from frame facts. |
| E-019 | S-022 | `lines 160-180` | Text serialization writes the element family value; no runtime family default is serialized. |
| E-020 | S-017 | `lines 222-231` | Stock double-tap admission calls startFromContextAction without an empty-text policy. |
| E-021 | S-014 | `lines 1194-1252` | The common resolver owner normalizes compatible accept, cancel, incompatible resolution, and guarded callback failure. |
| E-022 | S-007 | `lines 3058-3077` | Prepared installation precedes final state, committed lease, action/observer, and matching text-session close notification; callbacks reject public mutation. |
| E-023 | S-008 | `lines 245-254` | Runtime owns text sessions; frame owns measured geometry and suppression; Flutter editing is outside runtime. |
| E-024 | S-007 | `lines 87-108` | Public semantics/signatures and the canonical machine-readable export inventory have distinct authoritative owners. |
| E-025 | S-026 | `lines 7-20` | Registry consumers read the canonical YAML rather than a copied export list. |
| E-026 | S-027 | `lines 15-36` | Namespace parity compares resolved exports with that registry. |
| E-027 | S-023 | `lines 492-516` | Owner behavior tests and external consumer access tests have distinct homes; external behavior uses the shared consumer harness. |
| E-028 | S-030 | `lines 35-56` | The retained text decision assigns session state to runtime, measurement to frame, input objects to surface, and commits to the existing edit boundary. |
| E-029 | S-029 | `lines 1-12` | ADRs retain rationale and must not become current behavior inventories. |
| E-030 | S-002 | `lines 403-465` | Existing proof covers text-only sessions, conflicts, initial overlay formatting, and family serialization, but not the requested combined draft or global default. |
| E-031 | S-035 | `lines 10-21` | editText and deleteElements already identify the relevant high-level notification families. |
| E-032 | S-036 | `lines 483-513` | Text guard facts admit visible content and reject missing, hidden, or non-content targets; they do not reject based on text length. |
| E-033 | S-014 | `lines 1438-1456` | Direct removal already prepares deletion through EditKernel and the shared resolver using exact original entries. |
| E-034 | S-028 | `lines 4-20` | Existing guardrails identify one measurement source and confine EditableText to surface. |
| E-035 | S-031 | `lines 35-58` | Store final comparison and edit installation own atomic committed truth; user actions are not an undo journal. |
| E-036 | S-032 | `lines 36-65` | Frame capture and bounded caches are derived inputs; painters do not resolve live runtime state. |

### Requirements

| ID | Kind | Statement | Basis | Open shape |
| --- | --- | --- | --- | --- |
| R-001 | outcome | Numicod can complete one text-editing gesture through the stock overlay as an atomic accepted update, creation, or policy-selected deletion, with readable conflicts, stable input state, and a runtime default font shared by measurement and display. | S-001 | Private decomposition and exact names of new result types remain open; the observable distinctions below are mandatory. |
| R-002 | user_decision | Extend the existing runtime text session and confirmation pipeline; the candidate has already been selected. Author the complete design without checkpoint cycles or invented alternative candidates. | S-001, S-003, S-033 | Private helpers and file decomposition remain open; this is not a requirement for a new controller or transaction service. |
| R-003 | user_decision | Start existing empty or nonempty text by ID without hit coordinates; distinguish missing target, wrong type, read-only, another active session, stale same-target session, and unavailable content; reuse only the same valid active session. | S-001 | Result representation remains open within typed success/session and typed refusal semantics. |
| R-004 | user_decision | Text and whole-block bold, italic, and underline belong to one draft; formatting updates immediately preserve the active session, focus, cursor, selection, and composing state in the stock editor. | S-001 | Parameter and internal draft representation remain open; partial formatting updates preserve omitted fields. |
| R-005 | user_decision | Programmatic finish distinguishes committed, unchanged, cancelled, rejected, stale, and noActiveSession; retain existing bool commit and void dismissal entrypoints. | S-001 | Result type name and explicit commit/cancel argument representation remain open. |
| R-006 | user_decision | A detected stale session must not overwrite the document or silently restart; its draft remains readable and explicitly cancellable. Real external target changes remain conflicts while unrelated document changes do not invalidate existing-target editing. | S-001, E-006 | Private stale marking and retention representation remain open. |
| R-007 | user_decision | A net-unchanged existing draft produces no mutation, resolver request, action, or history entry; cancelling discards both text and formatting. | S-001 | Equality implementation remains with current accepted-fact owners. |
| R-008 | user_decision | startNew stages an application-positioned text seed outside the document, then creates the final nonempty block in one accepted operation; Escape and empty confirmation leave no new block, layer, Undo entry, or document-dirty transition. | S-001 | Seed/placement parameter packaging remains open; no pre-insertion is allowed. |
| R-009 | user_decision | Empty means text.trim().isEmpty for new-block suppression and policy-selected existing-block deletion; nonempty text is never trimmed before storage. | S-001 | No alternative whitespace classification is introduced. |
| R-010 | user_decision | Existing sessions capture emptyTextBehavior with compatible keepElement default and explicit deleteElement option; empty confirmation under deleteElement prepares one deletion request rather than an empty update followed by removal. | S-001, E-009, E-033 | The policy enum name remains open; the accepted value meanings are fixed. |
| R-011 | user_decision | The stock double-tap overlay exposes emptyTextBehavior and forwards it into the common session admission path, giving Numicod the same policy as explicit ID admission. | S-001, E-020 | Internal parameter plumbing remains open; no global application singleton is required. |
| R-012 | user_decision | Immutable CanvasRuntimeConfig.defaultFontFamily supplies the family only when element.fontFamily is null; one resolution policy feeds measurement, cache identity, paint, and editing without persisting inherited family into the element. | S-001, E-014, E-015, E-017 | Private effective-style representation remains open. |
| R-013 | constraint | The application owns keypad UI, seed position, document saving, dirty-state interpretation, and Undo/Redo; record one history entry only after the accepted lease commits. The engine owns the draft and atomic installation, including opted-in deletion. | S-001, E-008, E-035 | Application history storage and UI stay outside this package. |
| R-014 | user_decision | Preserve existing call shapes and defaults with additive APIs; explicitly document external port-implementer updates and exhaustive commit-request, action-type, and action-payload switch migration, plus the changed stale-retention behavior. Preserve Schema v1 and existing request before/after field types. | S-001, E-001, E-024 | New type identifiers remain open; migration must be concrete and compile-checked. |
| R-015 | repository_rule | Keep the contracts-led owner DAG, final prepared Store facts, guarded synchronous resolver/lease callbacks, current common delivery ordering, and frame-owned single measurement authority. | S-004, S-009, S-016, S-024, S-025, S-031, S-032, S-034, E-022, E-034 | Local implementation tactics inside existing owners remain open. |
| R-016 | exclusion | No engine keypad input protocol, selection/cursor mirror in runtime, generic long-lived document transaction, automatic conflict merge/force overwrite, dynamic font setter/loader, document-level font schema, or new engine Undo manager is included. | S-001, S-003, E-003, E-010 | Host integration remains free to use the existing public Flutter TextInputControl. |
| R-017 | repository_rule | Current contracts, architecture, and registries own durable meaning; this design and the research are planning/evidence inputs. Required tests observe behavior at the owning or public consumer interface, not copied inventories or private helper shape. | S-004, S-005, S-006, S-007, S-009, S-010, S-023, S-029, E-024, E-025, E-026, E-027, E-030 | Cohesive proof placement stays with established owner test areas. |
| R-018 | user_decision | Creation emits createText and existing-block modification retains editText; the public action must distinguish creation directly rather than treating it as an edit from fictional empty content. | S-001, E-031 | New payload type spelling remains open; its fields describe creation rather than a before/after edit. |

## Candidate Analysis

- Comparison: `single_viable`
- Result: `selected F-001`
- Result basis: R-002, R-003, R-004, R-008, R-010, R-012, R-015, F-001, M-001, M-002, M-003, M-004, M-005, M-006, M-007, R-018, E-001, E-005, E-010, E-023

### Forms

| ID | Form | Hard constraints | Main trade-off | Basis |
| --- | --- | --- | --- | --- |
| F-001 | Extend the runtime-owned session to stage existing/new text and formatting, keep the stock surface input owner, select one prepared update/add/delete at finish, and resolve a runtime font default before frame measurement. This is the user-selected form, not a fresh competitive search. | pass | Adds typed admission/completion and creation confirmation, requiring the accepted source migration; avoids host-side close/reopen and insert/delete compensation. | R-002, R-003, R-004, R-008, R-010, R-012, R-014, E-005, E-010, E-023 |

### Material-Obligation Delta

| ID | Material obligation | F-001 | Independent authority |
| --- | --- | --- | --- |
| M-001 | R-003 | yes | R-003 |
| M-002 | R-004 | yes | R-004 |
| M-003 | R-008 | yes | R-008 |
| M-004 | R-010 | yes | R-010 |
| M-005 | R-012 | yes | R-012 |
| M-006 | R-014 | yes | R-014 |
| M-007 | R-018 | yes | R-018 |

### Future Pressures

| ID | Pressure | Basis | Treatment | Closure refs | Accepted cost or risk |
| --- | --- | --- | --- | --- | --- |
| P-001 | Numicod must finish input before save/workspace commands and group first creation with editing. | S-001, R-005, R-008, R-013 | absorbed | D-005, D-007, D-009 | The host must branch on rejected/stale results and must not proceed as though they were successful saves. |
| P-002 | Per-document or live-changeable global fonts could be requested later. | S-002, R-012, R-016 | deferred | D-010, D-011 | A document opened under a different runtime default can have different layout; portable font policy and runtime invalidation would require another accepted design. |
| P-003 | External integrations may implement the port or exhaustively switch on commit requests, action types, or action payloads. | R-014, E-001, E-024 | absorbed | D-012, I-001, I-002 | Additive call compatibility does not imply source compatibility for those implementers and switches. |

## Decision Register

### D-001 — Existing owner allocation
- Concerns: `form`, `owner`, `source_of_truth`, `dependency`
- Lock: F-001 deepens CanvasTextEditingPort inside RuntimeRoot. Store remains committed document truth and EditKernel remains finalization/install owner; interaction owns issued request guard facts; frame owns measured text and immutable paint inputs; surface owns Flutter input objects. No new graph node, public controller, mirrored document, or alternate install path is introduced. ADR-0010, ADR-0003, and ADR-0007 retain their ownership rationale; their current-behavior refinements are carried by I-001, I-003, and I-004 rather than by rewriting historical ADR bodies.
- Open: Private collaborator extraction within existing owner nodes and immutable internal draft value shape remain open.
- Basis: R-001, R-002, R-015, R-017, E-010, E-011, E-023, E-028, E-035, E-036
- Form: F-001
- Realizes: none
- Depends on: none
- Contract targets: `classification`, `owner`, `source_of_truth`, `dependency`, `unit_family`
- Rationale: The owning session already concentrates admission, draft observation, suppression, and completion; expanding it removes repeated orchestration from integrations.

### D-002 — Typed admission and route parity
- Concerns: `policy`, `state_data`
- Lock: startForElement accepts ID plus emptyTextBehavior and returns typed success containing the session or typed refusal. Refusal distinguishes readOnly, anotherSessionActive, stale for the same active target, notFound, unsupportedType, and unavailable for hidden/non-content targets. Admission checks read-only and the active slot before admitting a new target; same-target success requires current guards and preserves its captured policy. A different active session, including a stale one, is never replaced. Empty strings bypass no ID-based eligibility rule. ID admission obtains real current target facts and issues a guarded identity without hit testing or emitting a fabricated context event. Existing context-action admission and candidate/start methods delegate to the same admission policy and retain nullable-result compatibility; their optional emptyTextBehavior defaults to keepElement. CanvasTextEditingOverlay captures its configured emptyTextBehavior when auto-starting a double-tap session. Later overlay property changes and repeat starts affect no already-admitted session.
- Open: Concrete result/variant names and private request-fact construction remain open; refusal meanings and policy capture do not.
- Basis: R-003, R-010, R-011, E-001, E-002, E-020, E-032
- Form: F-001
- Realizes: M-001
- Depends on: D-001
- Contract targets: `policy`, `state_data`, `acceptance`, `verification`, `unit_family`
- Rationale: One owner must determine whether editing may start, regardless of the UI gesture.

### D-003 — One text and formatting draft
- Concerns: `state_data`, `policy`
- Lock: Each session retains its immutable base/seed and one mutable draft text plus B/I/U. updateFormatting changes only supplied flags and not committed data. style and geometry read that same draft; notify the existing active-session listenable without replacing session identity. Initial and draft layout, including style-only changes, use frame measurement and the same anchor-preservation rule so the accepted element agrees with the last editor geometry. Runtime does not retain selection, caret, composing range, FocusNode, or TextEditingController; the stock overlay keeps these objects and leaves their value untouched on formatting-only changes. Programmatic updateText retains its existing different-string selection semantics. Host toolbar/keypad focus behavior must respect the existing commitOnFocusLoss option; formatting itself neither steals nor restores unrelated host focus.
- Open: A small value object versus individual draft fields and internal notification naming remain open.
- Basis: R-004, R-015, E-003, E-004, E-016, E-017, E-023
- Form: F-001
- Realizes: M-002
- Depends on: D-001
- Contract targets: `state_data`, `policy`, `acceptance`, `verification`, `unit_family`
- Rationale: Stable session identity already preserves Flutter input state; formatting must also participate in layout rather than only in paint.

### D-004 — Conflict retention and lifecycle
- Concerns: `state_data`, `temporal`, `negative_proof_fixture`
- Lock: Before any confirmed mutation, existing-target guards compare the captured epoch, kind, generation, element revision, and current visible content eligibility. Document revision alone never invalidates an existing target. Stale detection makes the session terminal for mutation without rebasing; it keeps the same active session and its last text/style/geometry available for reads and explicit cancel. Subsequent draft mutations have no effect and subsequent commit returns stale. A consumed/invalid guard cannot become valid through a repeated start or commit. Stale sessions no longer suppress committed scene content but retain their editor draft; cancellation clears only their own transient state. Resolver refusal remains retryable and is not stale. Explicit lifecycle reset through successful document load, runtime/overlay disposal or replacement, and enabling read-only retains existing dismissal behavior; callers must finish or copy a draft before those explicit resets. Failed load preserves the session. Negative fixtures exercise real external changes through public edits and never define production guard values.
- Open: Private stale latch versus retained immutable guard representation remains open if stale is irreversible and draft reads survive request retirement.
- Basis: R-006, R-014, R-015, R-017, E-006, E-007, E-022, E-028
- Form: F-001
- Realizes: none
- Depends on: D-001, D-002, D-003
- Contract targets: `state_data`, `temporal`, `negative_proof_fixture`, `acceptance`, `verification`, `unit_family`
- Rationale: Conflict authority and draft lifetime are different responsibilities; retiring authorization must not destroy the user's recoverable input.

### D-005 — One finish operation and compatible adapters
- Concerns: `policy`, `compatibility`, `order`
- Lock: finishActive takes an explicit commit/cancel choice and returns committed, unchanged, cancelled, rejected, stale, or noActiveSession. committed covers an installed update, insertion, or deletion; unchanged closes without document work; cancelled discards the active draft even when stale; rejected keeps a retryable draft; stale follows D-004. Cancel requires no valid commit guard. The session bool commit delegates to the same terminal owner and maps committed/unchanged to true, all non-successful commit outcomes to false; existing void dismiss and dismissActive delegate to cancellation. Stock overlay confirmation uses this terminal owner. The legacy direct commitTextEdit request API keeps its text argument and bool mapping; without a matching active session it remains a guarded text-only update, while a matching session supplies draft formatting and captured empty policy to the same terminal candidate. Validation/disposal/reentrancy exceptions retain existing contract categories rather than being misreported as host rejection. A matching stale session is retained even when a legacy command encounters its consumed request.
- Open: Enum/type names and forwarding implementation remain open; no parallel terminal algorithm is allowed.
- Basis: R-005, R-006, R-014, E-001, E-005, E-021
- Form: F-001
- Realizes: none
- Depends on: D-002, D-003, D-004
- Contract targets: `policy`, `compatibility`, `order`, `acceptance`, `verification`, `unit_family`
- Rationale: The host needs reliable completion semantics before saving, while existing callers must remain usable.

### D-006 — Existing-target update, deletion, and no-op
- Concerns: `policy`, `atomicity`
- Lock: After guards and validation, emptyTextBehavior=deleteElement with draft.text.trim().isEmpty chooses only the existing direct-removal eligibility and prepared deletion path. It sends one CanvasDeleteCommitRequest containing the original element and its exact current placement; no draft text/style update is installed first and no automatic empty-layer cleanup is added. Refused/ineligible deletion leaves the original and draft intact and reports rejected. Otherwise compare the complete draft text/B/I/U against the base using accepted semantic equality: a net-equal candidate closes as unchanged without resolver, installation, document revision, action, or history. Changed candidates prepare one CanvasTextElementUpdate containing text, B/I/U, and required anchor transform, then send the existing non-null CanvasTextEditCommitRequest.before/after. Empty deletion is an explicit operation even when the original element was already empty, so it is not suppressed by text equality. Preparation and final Store equality remain in existing owners.
- Open: Shared preparation helpers remain open; routing precedence and original deletion facts do not.
- Basis: R-007, R-009, R-010, R-013, E-005, E-009, E-033, E-035
- Form: F-001
- Realizes: M-004
- Depends on: D-003, D-004, D-005
- Contract targets: `policy`, `atomicity`, `acceptance`, `verification`, `unit_family`
- Rationale: Choosing the operation before preparation gives the resolver one exact proposal and prevents two document transitions for one gesture.

### D-007 — New-block staging and placement
- Concerns: `state_data`, `policy`, `atomicity`
- Lock: startNew accepts a CanvasTextElement seed plus the existing addElement-style layerId/index placement and uses the same active-session slot and stock overlay. The seed, draft, chosen placement, and creation guard are runtime transient data; no element, layer, selection change, or document revision is installed at start. Resolve omitted layer using the existing last-layer/default-layer rule at admission and retain that chosen destination, not a later retargeting. A named absent layer is a prospective layer, created only with accepted insertion. Capture whether the destination existed; loss of an existing destination, occupation of a prospective destination by external creation, occupied element ID, or changed document epoch makes creation stale. Numeric insertion/append uses existing addElement normalization in the retained destination at preparation; unrelated changes do not require a whole-document equality guard. Duplicate seed ID is a typed start refusal; invalid seed/input validation keeps established validation exceptions. New/existing origin is explicit in the public session. Existing guard getters keep their types: for new origin elementRevision is the seed revision and generation is zero as a documented not-yet-committed value, never a Store generation or authorization. A real issued requestId identifies the session, while creation eligibility uses the separate creation facts and cannot pass the existing-target guard accidentally.
- Open: Internal origin/creation-fact representation and placement storage remain open; no long-lived CanvasEdit or synthetic committed element is allowed.
- Basis: R-008, R-014, R-015, E-001, E-010, E-011, E-012, E-013
- Form: F-001
- Realizes: M-003
- Depends on: D-001, D-002, D-003, D-004, D-005
- Contract targets: `state_data`, `policy`, `atomicity`, `acceptance`, `verification`, `unit_family`
- Rationale: A creation draft is the minimum additional state needed to avoid committing an empty placeholder and later compensating for it.

### D-008 — New-block completion and exact creation request
- Concerns: `policy`, `atomicity`
- Lock: Confirming a valid new draft with text.trim().isEmpty closes unchanged before any prepare or resolver; Escape cancels identically to other sessions. A nonempty draft preserves its exact untrimmed text and formatting, then prepares one addElement with any necessary destination-layer creation through the existing deferred EditKernel route. CanvasTextCreateCommitRequest is a new public readable request variant carrying the prepared CanvasCommitElementEntry, exact layer index, and createsLayer flag, plus existing common request facts. Ordinary CanvasCommitAccept accepts it. Existing CanvasTextEditCommitRequest.before remains non-null and is never populated with a fictional pre-insertion element. Refusal/discard keeps the draft; successful insertion returns committed and closes it. New-block confirmation uses the seed's measured anchor consistently with D-003; even a nonempty seed unchanged since start still represents a real insertion.
- Open: Constructor layout and private sealed prepared-package representation remain open.
- Basis: R-008, R-009, R-013, R-014, E-008, E-010, E-011, E-012
- Form: F-001
- Realizes: none
- Depends on: D-007
- Contract targets: `policy`, `atomicity`, `acceptance`, `verification`, `unit_family`
- Rationale: The host needs insertion facts rather than an invented update pair to undo the first editing gesture.

### D-009 — Installation, delivery, and application history
- Concerns: `temporal`, `atomicity`, `order`
- Lock: Each changed terminal prepares and validates one closed package and immutable exact request before the synchronous resolver. Cancellation, incompatible resolution, callback failure, or pre-install failure installs nothing and never records history; any acquired lease is aborted once. The irreversible point is existing prepared-package consumption/atomic Store and selection installation. After it, perform existing guarded common delivery only: final public state, committed lease once, one action, observer, guard release, then the matching session-close notification. Contained post-install notification failures cannot convert an accepted mutation to rejected or trigger lease abortion. Session cleanup targets the completed identity and cannot clear a new session started by a close listener. Resolver and lease callbacks permit reads/host-local bookkeeping and reject engine mutation, ID generation, nested confirmation, and disposal before side effects. Existing-block updates emit one editText notification with the existing CanvasTextEditActionPayload and its before/after text lengths. Creations emit one createText notification with a dedicated public readable CanvasTextCreateActionPayload carrying requestId and the created text length; it has no fictional previous-text field. The enclosing CanvasActionCommitted.elementIds identifies the created element without duplicating its ID in the payload. Policy deletion emits the existing deleteElements notification. Actions remain insufficient as Undo payloads. Hosts construct history from exact request facts and append it only in lease.committed; insertion Undo removes the new element and only its operation-created layer when empty, deletion Undo restores the original entry, update Undo restores before. Draft notifications do not advance document revision or imply dirty state; host saving must honor rejected/stale finish results.
- Open: Existing internal delivery helpers and host history representation remain open; common ordering and one-operation cardinality are fixed.
- Basis: R-005, R-008, R-010, R-013, R-015, R-018, E-008, E-009, E-011, E-021, E-022, E-031, E-035
- Form: F-001
- Realizes: M-007
- Depends on: D-001, D-005, D-006, D-008
- Contract targets: `temporal`, `atomicity`, `order`, `acceptance`, `verification`, `unit_family`
- Rationale: Reusing the existing lease/install boundary gives the application one durable history boundary without engine-owned Undo.

### D-010 — Runtime font default and effective layout
- Concerns: `source_of_truth`, `policy`, `state_data`
- Lock: Add nullable immutable CanvasRuntimeConfig.defaultFontFamily, validated by the existing per-element family constraints. Resolve element.fontFamily ?? defaultFontFamily in the runtime Store-to-frame projection and initial measurement handoff using one policy; derived frame/session inputs carry the effective family. Subsequent draft measurement, render rows, layout keys, cached painters, overlay TextStyle and StrutStyle consume that effective value. Existing explicit families win, null runtime default preserves Flutter fallback, and independent runtimes may use independent defaults. The captured seed/base keeps the original nullable element value for commit and serialization; reading or confirming a draft must not write the inherited family into document data. Configuration lives for the runtime lifetime; fonts are made available by the host before use. No setter, font-asset generation, theme lookup, document schema field, or process-global state is added.
- Open: A private resolver function versus effective input construction remains open; all consumers must share the policy.
- Basis: R-012, R-015, R-016, E-014, E-015, E-016, E-017, E-018, E-019, E-036
- Form: F-001
- Realizes: M-005
- Depends on: D-001
- Contract targets: `source_of_truth`, `policy`, `state_data`, `acceptance`, `verification`, `unit_family`
- Rationale: Resolving before geometry and rendering prevents mismatched bounds and font display without duplicating font metadata on every node.

### D-011 — Scope and implementation limits
- Concerns: `in_scope`, `out_of_scope`
- Lock: R-003 through R-014 and R-018 define the included public text-editing behavior and font default; R-016 remains excluded. Production changes stay within existing public contracts/facades, runtime, interaction request/read seams, edit preparation, frame facts, and surface owners. Tests stay with existing runtime/surface/frame and public integration proof owners. No general scanner, new graph node, independent benchmark system, or external Numicod implementation is required.
- Open: Cohesive private source/test placement within these owners remains open and must follow S-009 and S-023.
- Basis: R-003, R-004, R-005, R-006, R-007, R-008, R-009, R-010, R-011, R-012, R-013, R-014, R-016, R-017, R-018, E-023, E-027, E-034
- Form: F-001
- Realizes: none
- Depends on: D-001
- Contract targets: `scope`, `unit_family`
- Rationale: The accepted feature does not require a new general editing framework or an engine-owned keypad.

### D-012 — Compatibility and durable handoff
- Concerns: `compatibility`, `migration_retirement`
- Lock: Existing callers retain bool/void entrypoints, optional defaults, per-element family, and Schema v1. The accepted behavior change keeps stale sessions readable rather than auto-dismissing. New optional arguments, port members, session origin/formatting, typed result declarations, CanvasTextCreateCommitRequest, CanvasActionType.createText, and CanvasTextCreateActionPayload require an atomic producer/consumer public-seam update: exported-name registry, public facades, readable variants, compile-as-written contracts, and exhaustive in-repository consumers must agree before release. External implements of CanvasTextEditingPort require new/updated members; exhaustive CanvasCommitRequest switches require a creation branch; exhaustive CanvasActionType and CanvasActionPayload switches require createText and its creation payload respectively. Existing editText values and CanvasTextEditActionPayload fields retain their meaning for existing-block changes. Append createText after existing action-type enum values so their existing indices do not shift. No capability-cast adapter or deprecated parallel implementation is retained. Migration examples show matching overlay/startForElement empty policy and startNew with create/update/delete lease-backed Undo handling; existing low-level addElement remains immediate for ordinary service edits. I-001 through I-005 own the durable transitions.
- Open: Concrete new type spelling and cohesive documentation/example layout remain open; changed call signatures and switch cases must be explicit.
- Basis: R-014, R-017, R-018, E-001, E-008, E-024, E-025, E-026, E-027, E-029
- Form: F-001
- Realizes: M-006
- Depends on: D-002, D-005, D-006, D-008, D-010
- Contract targets: `compatibility`, `migration_retirement`, `acceptance`, `verification`, `durable_impact`, `unit_family`
- Rationale: Additive API use is compatible for callers but not automatically for implementers or closed-union readers; documenting and compiling the migration is part of the feature.

## Impact Register

### I-001 — Public text and font contracts with migration guidance
- Action: update
- Surface: `docs/contracts/public_api_v1.md` and its corresponding declarations under `lib/src/contracts/public/` and public facades under `lib/src/api/`
- Required by: D-012
- Resulting authority: D-012, R-017
- Contract requirement: Publish the new entry, result, origin, formatting, creation-request, createText action/payload, empty-policy, stale-retention, and runtime-font semantics together with concrete migration examples for port implementations, request/action switches, stock double-tap configuration, and lease-backed host Undo; preserve the existing declared compatibility boundaries.

### I-002 — Public name admission and direct consumers
- Action: update
- Surface: `docs/_registry/public_api_v1.yaml`, `lib/iwb_canvas_engine.dart` through its facade exports, and existing public export/compile consumers
- Required by: D-012
- Resulting authority: D-012, R-017
- Contract requirement: Admit exactly the implemented public additions and migrate direct consumers without a second name list, weakening guardrails, or making generated output authoritative.

### I-003 — Runtime lifecycle and operation semantics
- Action: update
- Surface: `docs/architecture/01_runtime_ownership.md`, `docs/contracts/operation_matrix.md`, and `docs/contracts/edit_kernel.md`
- Required by: D-012
- Resulting authority: D-001, D-004, D-009
- Contract requirement: Replace context-only and stale-clears-draft descriptions with the selected session semantics; describe prepared creation and empty-policy deletion alongside update/no-op while preserving Store finalization and delivery ownership.

### I-004 — Effective font and draft geometry contracts
- Action: update
- Surface: `docs/contracts/frame_rendering.md` and `docs/contracts/cache_policy.md`
- Required by: D-012
- Resulting authority: D-003, D-010
- Contract requirement: Describe effective family and draft-formatting participation in measurement/rendering and stale-session suppression release without introducing font persistence, duplicate layout, or new cache authority.

### I-005 — Owner proof coverage and generated relationships
- Action: update
- Surface: `docs/verification/tests.md`, existing runtime/surface/frame and public integration proof owners, `docs/_registry/sections.yaml` and generated documentation consumers when their relationships change
- Required by: D-012
- Resulting authority: R-017, D-011
- Contract requirement: Carry every A record as its own falsifiable failure family into the Change Contract, extend the nearest established proof owner, and update only actual changed coverage relationships using existing documentation tooling. Do not use copied inventories or prose assertions as product behavior proof.

## Assurance Register

### A-001 — ID admission and refusal distinctions
- Verifies: R-001, R-003, D-001/owner, D-002/policy
- Claim: Public ID admission starts visible empty/nonempty text, distinguishes the specified refusals, and reuses only a valid same-target session.
- Failure: An empty element requires coordinates, refusal reasons collapse, or a stale/other session is silently replaced.
- Oracle: Observe typed start results, session identity and target, and unchanged document while exercising actual eligible, missing, wrong-type, unavailable, read-only, active-other and stale targets.
- Proxy risk: Constructing result DTOs or checking a method declaration cannot prove admission.
- Evidence constraints: Runtime behavioral evidence crosses the real public port; no fabricated retained registry entries.
- Architecture seam: D-002 public session admission.

### A-002 — Double-tap policy parity
- Verifies: R-011, D-002/state_data
- Claim: Stock double-tap captures the same deleteElement policy as explicit ID admission, with keepElement as the compatible default.
- Failure: The overlay omits policy forwarding, or a later property change silently rewrites an active session's policy.
- Oracle: Start through stock double-tap and through ID, then confirm whitespace-only input and observe matching deletion requests/results; repeat with omitted policy and with an already-active session.
- Proxy risk: Inspecting constructor fields or testing only explicit ID admission misses the stock route.
- Evidence constraints: Surface behavior must traverse actual context delivery, overlay subscription, and runtime completion.
- Architecture seam: D-002 overlay-to-port admission.

### A-003 — Input state survives formatting
- Verifies: R-001, R-004, D-003/state_data
- Claim: Typing, B/I/U, and continued typing retain session identity, focus, selection/caret, and composition.
- Failure: Formatting replaces the controller/session, collapses a range, loses composition, or changes committed text.
- Oracle: Observe the stock EditableText editing value and focus before/after formatting and subsequent input, together with document immutability.
- Proxy risk: Checking only displayed bold text or draft string misses input-state loss.
- Evidence constraints: Widget behavior includes a noncollapsed selection and composing range; do not mirror input state into runtime.
- Architecture seam: D-003 session notification and existing overlay controller.

### A-004 — Draft layout equals accepted geometry
- Verifies: D-003/policy
- Claim: Style-only and mixed draft changes use matching layout/anchor geometry in the editor and accepted element.
- Failure: B/I/U updates paint while geometry or accepted transform still uses base style.
- Oracle: Observe measured draft bounds and world anchor against accepted frame bounds for text and formatting changes, including unchanged text with changed weight/style.
- Proxy risk: Text or style equality alone cannot expose wrong bounds or an anchor jump.
- Evidence constraints: Exercise frame-backed geometry with metrics that distinguish the styles; no private helper-call assertions or overlay measurement implementation.
- Architecture seam: D-003 frame measurement and commit geometry.

### A-005 — Stale draft survives without overwrite
- Verifies: R-006, D-004/state_data, D-004/temporal, D-004/negative_proof_fixture
- Claim: External target/identity/epoch changes reject mutation while the same draft remains readable and explicitly cancellable; unrelated existing-target edits remain admissible.
- Failure: Stale completion clears the draft, overwrites external content, becomes valid on retry, or confuses unrelated document revision with a target conflict.
- Oracle: Mutate through real public edit/replacement routes, confirm through typed and legacy entrypoints, read draft values, repeat start/commit, and explicitly cancel; compare committed element/revision and resolver silence.
- Proxy risk: A bool false assertion can pass after draft loss or partial mutation.
- Evidence constraints: Observe same-ID replacement, removal/style change and unrelated edit; isolate explicit load/dispose resets from stale completion and keep fixture values out of production authority.
- Architecture seam: D-004 guard plus retained runtime session.

### A-006 — Typed finish and lifecycle adapters
- Verifies: R-005, D-005/policy, D-005/compatibility, D-005/order
- Claim: Every finish result identifies its actual document and session outcome, and legacy/overlay paths use the same semantics.
- Failure: No-op is reported as mutation, refusal as conflict, or an adapter bypasses draft style/policy or closes the wrong session.
- Oracle: Observe results, document state, active-session state and request kinds across committed/unchanged/cancelled/rejected/stale/no-session and matching legacy paths.
- Proxy risk: Enum coverage alone proves neither state nor shared behavior.
- Evidence constraints: Public behavior plus compile evidence for retained call shapes; retain existing validation/guard exception categories.
- Architecture seam: D-005 common text completion.

### A-007 — One accepted update and true net no-op
- Verifies: R-001, R-007, D-006/atomicity
- Claim: Text and formatting update together once; style-only changes commit; cancelling and reverting to the base produce no document mutation.
- Failure: Two commits, text-only preparation, or a toggled-back draft creates a revision/action/history entry.
- Oracle: Inspect exact resolver before/after, install/document revision and action cardinality, then exercise cancel and net-equal text/B/I/U.
- Proxy risk: Final element equality can hide intermediate mutations.
- Evidence constraints: Observe delivery counts and resolver absence for no-op, not just final values.
- Architecture seam: D-006 prepared existing-target update.

### A-008 — Whitespace deletion is one operation
- Verifies: R-009, R-010, D-006/policy
- Claim: deleteElement routes empty/space/newline text to one original-entry deletion; keepElement retains normal update/no-op behavior.
- Failure: An empty update is installed first, original formatting is lost from Undo facts, or unchanged originally-empty text bypasses explicit deletion.
- Oracle: Observe one CanvasDeleteCommitRequest, original entry/placement, no intermediate text update, final removal and one lease; exercise refusal and non-deletable eligibility without fallback mutation.
- Proxy risk: Final absence alone also passes after update-then-delete.
- Evidence constraints: Use operation/request/lease cardinality and original-value observations, including whitespace and already-empty input.
- Architecture seam: D-006 operation selection before preparation.

### A-009 — New session is genuinely transient
- Verifies: R-001, R-008, D-007/state_data, D-007/atomicity
- Claim: Opening, editing, cancelling, or empty-confirming a new draft creates no element/layer/document revision or host history.
- Failure: A placeholder, layer, selection effect, or dirty transition leaks before accepted creation.
- Oracle: Compare document, layer structure, selection, document revision, resolver/action/lease counts and host dirty/history state across the full draft lifecycle.
- Proxy risk: Seeing no element after cancellation hides a compensating removal.
- Evidence constraints: Observe intermediate states and whitespace-only confirmation, including an initially absent destination layer.
- Architecture seam: D-007 transient session and D-008 empty terminal.

### A-010 — Creation guard prevents retargeting
- Verifies: D-007/policy
- Claim: A creation draft inserts only into its admitted document/destination and never overwrites an occupied element ID.
- Failure: A changed last layer silently retargets creation, a lost destination is silently recreated, or a conflicting ID is overwritten.
- Oracle: Change destination/epoch/ID conditions through public document operations, then observe stale plus retained draft and zero insertion; unrelated changes retain the captured destination.
- Proxy risk: Testing only successful insertion misses admission-to-confirmation drift.
- Evidence constraints: Observe public structure and draft retention; do not synthesize committed generation facts for a new seed.
- Architecture seam: D-007 creation admission and confirmation guard.

### A-011 — Exact atomic creation proposal
- Verifies: R-008, D-008/policy, D-008/atomicity
- Claim: Nonempty creation yields one exact insertion request and one accepted block, preserving text whitespace, B/I/U and placement.
- Failure: The request fabricates a before value, omits operation-created layer facts, trims content, or inserts before resolver acceptance.
- Oracle: Observe document absence during resolver, prepared entry and layer metadata, accepted element, request/lease count and unchanged nonempty-seed insertion.
- Proxy risk: A final nonempty block does not prove exact request facts or pre-acceptance silence.
- Evidence constraints: Public resolver and runtime behavior, including refusal/discard; compare full element values, not object identity.
- Architecture seam: D-008 prepared insertion request.

### A-012 — Common delivery and failure atomicity
- Verifies: R-015, D-009/temporal, D-009/atomicity, D-009/order
- Claim: Update/create/delete preserve guarded preparation, one irreversible install, lease terminal cardinality, delivery order and identity-safe closure.
- Failure: Reentrancy mutates state, a pre-install failure leaks an effect, a lease is aborted after install, or close notification clears a replacement session.
- Oracle: Record actual state/lease/action/observer/close observations, exercise rejected callbacks and preparation/consume failure at the existing owner seam, and start a fresh session from close notification.
- Proxy risk: Only counting resolver calls misses installation/order errors and post-install failure handling.
- Evidence constraints: Behavioral evidence at RuntimeRoot/EditKernel delivery using existing failure seams; no new generic fault-injection framework or private call-shape oracle.
- Architecture seam: D-009 prepared package and guarded common delivery.

### A-013 — Host can undo one completed gesture
- Verifies: R-013
- Claim: An external consumer can build one Undo/Redo entry from accepted update/create/delete request facts and no entry for cancelled, empty-new, unchanged, rejected or stale completion.
- Failure: Undo restores an empty intermediate value, leaves an operation-created layer, loses original placement, or records unsuccessful attempts.
- Oracle: A public-only host history example executes the gesture, appends in lease.committed, replays Undo/Redo through existing edit APIs, and compares full document and dirty/history transitions.
- Proxy risk: An action-count test alone cannot prove replay data or restoration.
- Evidence constraints: Use the existing external consumer harness and public barrel; never add engine history state or require access to internal request/store facts.
- Architecture seam: D-009 public request/lease and existing CanvasEdit replay.

### A-014 — Effective family is consistent everywhere
- Verifies: R-001, R-012, D-010/source_of_truth, D-010/policy, D-010/state_data
- Claim: Inherited and explicit family produce consistent measured geometry, layout keys, painted text and overlay styles, independently per runtime.
- Failure: Only overlay inherits, measurement/paint disagree, explicit family loses precedence, or one runtime contaminates another.
- Oracle: Compare a null-family element under a configured default with an explicit-family equivalent through actual frame/layout and editor surfaces; observe different-family keys and independent runtime settings.
- Proxy risk: Checking only a config field or using indistinguishable fallback metrics misses a broken resolution path.
- Evidence constraints: Frame/surface behavior with a reliably distinguishable available font fixture where geometric claims need it; key/style observations complement rather than replace geometry.
- Architecture seam: D-010 runtime-to-frame effective text input.

### A-015 — Inheritance never changes stored font
- Verifies: R-014, D-010/source_of_truth
- Claim: Default-font rendering and text confirmation preserve the element's original nullable family and Schema v1 serialization.
- Failure: An inherited default is written into an element or serialized as new document metadata.
- Oracle: Read and encode elements before/after existing and new draft confirmation under a runtime default, preserving null and explicit values while observing effective display.
- Proxy risk: Correct visual font does not prove storage compatibility.
- Evidence constraints: Public element values and codec round-trip evidence, including no-default behavior.
- Architecture seam: D-010 effective-versus-stored family boundary.

### A-016 — Public migration is complete
- Verifies: D-012/compatibility, D-012/migration_retirement, I-001, I-002
- Claim: Existing call patterns outside the declared exhaustive-switch/port-implementation migrations compile; new readable results, creation requests and creation action payloads are exported, and documented migrations are sufficient for an external consumer.
- Failure: A public result references an unexported type, old call shapes break unexpectedly, or examples omit a required new switch/member.
- Oracle: Compile public-only old and migrated consumers and resolve actual exports against the canonical registry; inspect migration examples against actual declarations.
- Proxy risk: Updating an inventory or passing internal compilation alone misses external access and migration omissions.
- Evidence constraints: Existing public compiler/namespace guardrails consume owning sources; no copied name allowlist and no prose-token behavioral test.
- Architecture seam: D-012 public declaration/facade and external consumer boundary.

### A-017 — Durable owners describe the selected semantics
- Verifies: R-017, I-003, I-004, I-005
- Claim: Current runtime/edit/frame/verification owners and derived relationships describe and point to the selected behavior without promoting design, history, tests or generated navigation to product authority.
- Failure: Current docs still mandate context-only start/stale draft loss, effective family is omitted, or proof/navigation relationships point to nonexistent coverage.
- Oracle: Bounded review of the changed owning contracts against D-001 through D-012 and actual code/proof owners, plus established structured documentation relationship and generation checks.
- Proxy risk: A wording search or edited generated file can appear current while the semantic owner remains contradictory.
- Evidence constraints: Manual semantic inspection and structured checks; runtime behavior credit stays with A-001 through A-016 and A-019.
- Architecture seam: D-012 durable authority handoff.

### A-018 — Existing ownership and dependency direction
- Verifies: D-001/source_of_truth, D-001/dependency
- Claim: Session/committed/input state remains at its declared owner and production consumers cross the existing contracts-led seams without a second authority.
- Failure: A second committed draft, input-state mirror or font policy appears, or a surface/interaction consumer bypasses its declared owner.
- Oracle: Inspect changed production state ownership and use established graph/import and text-measurement boundary enforcement against the actual resulting dependency paths.
- Proxy risk: Successful behavior alone can conceal duplicated authority or forbidden imports.
- Evidence constraints: Read-only source inspection and existing structural checks, combined with behavioral oracles in the owning A records; no new scanner or private helper/cardinality assertion.
- Architecture seam: D-001 existing owner DAG and state allocation.

### A-019 — Creation and modification have distinct action meaning
- Verifies: R-018, D-009/order
- Claim: Accepted creation emits exactly one createText action with creation-only payload, while accepted existing-block text or formatting changes emit exactly one editText action with the existing edit payload.
- Failure: Creation is labeled editText, carries fictional previous-text data, emits both actions, or an existing edit is relabeled as creation.
- Oracle: Capture actual public actions after accepted new, existing-text and style-only completions; inspect action type, readable payload variant, session requestId, enclosing elementIds, and final text lengths against the accepted request/element.
- Proxy risk: A correct request kind or final element can hide a misclassified action.
- Evidence constraints: Public runtime action observations distinguish both successful branches and include action silence for cancelled, rejected and whitespace-only new drafts; compile-only export checks do not establish runtime classification.
- Architecture seam: D-009 finalized public action delivery.

## Stop Conditions

### H-001 — Session or commit ownership contradiction
- Trigger: Implementation requires bypassing current Store/EditKernel installation, keeping a CanvasEdit open across input, moving Flutter input state into runtime, or adding a new owner node.
- Invalidates: D-001, D-003, D-007, D-009
- Resolution requires: Reconcile the actual owner seam and accepted scope in architecture before contract implementation continues.

### H-002 — Atomic public history facts are insufficient
- Trigger: Prepared creation/deletion cannot expose exact replay placement/layer facts or one accepted lease without a second document mutation.
- Invalidates: D-006, D-008, D-009, A-013
- Resolution requires: Resolve the missing prepared facts at their current owning layer; do not compensate by host-side placeholder insertion or post-commit deletion.

### H-003 — Runtime-only font assumption changes
- Trigger: The host requires live font replacement, post-start font loading invalidation, document-persisted defaults, or forced override of explicit element families.
- Invalidates: D-010
- Resolution requires: Obtain the new product semantics and design lifetime, persistence and layout/cache invalidation before extending the current feature.

### H-004 — Compatibility exceeds the accepted migration
- Trigger: A proposed implementation changes existing data schemas or old call behavior beyond explicit stale retention and opted-in empty policy, or requires more public union/port migration than D-012 declares.
- Invalidates: D-005, D-012, I-001, I-002
- Resolution requires: Verify the concrete consumer break and close the migration or obtain a revised compatibility decision before proceeding.

## Contract Interface

- Profile: `BEHAVIOR_CHANGE`
- Obligations: `PUBLIC_API_CHANGE`, `SOURCE_OF_TRUTH_SINGULARITY`, `SEAM_MIGRATION`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `TEMPORAL_SURFACE_CLOSURE`, `ALL_OR_NOTHING_FAILURE_BOUNDARY`, `NEGATIVE_PROOF_AND_FIXTURE_QUARANTINE`
- ADR Impact: none
- Sources: S-001, S-002, S-003, S-004, S-005, S-006, S-007, S-008, S-009, S-010, S-011, S-012, S-013, S-014, S-015, S-016, S-017, S-018, S-019, S-020, S-021, S-022, S-023, S-024, S-025, S-026, S-027, S-028, S-029, S-030, S-031, S-032, S-033, S-034, S-035, S-036
- Requirements: R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-008, R-009, R-010, R-011, R-012, R-013, R-014, R-015, R-016, R-017, R-018
- Commitments: D-001, D-002, D-003, D-004, D-005, D-006, D-007, D-008, D-009, D-010, D-011, D-012
- Assurance: A-001, A-002, A-003, A-004, A-005, A-006, A-007, A-008, A-009, A-010, A-011, A-012, A-013, A-014, A-015, A-016, A-017, A-018, A-019
- Impacts: I-001, I-002, I-003, I-004, I-005
- Stops: H-001, H-002, H-003, H-004

## Diagrams

None: D-002 through D-010 explicitly close admission, operation selection, failure retention, installation order, and font resolution; another representation is unnecessary for the selected form.

## Readiness Matrix

### Architecture Closure

| Concern | Status | Support refs |
| --- | --- | --- |
| owner | closed | D-001 |
| in_scope | closed | D-011 |
| out_of_scope | closed | D-011 |
| source_of_truth | closed | D-001, D-010 |
| compatibility | closed | D-005, D-012 |
| order | closed | D-005, D-009 |
| policy | closed | D-002, D-003, D-005, D-006, D-007, D-008, D-010 |
| dependency | closed | D-001 |
| state_data | closed | D-002, D-003, D-004, D-007, D-010 |
| migration_retirement | closed | D-012 |
| temporal | closed | D-004, D-009 |
| atomicity | closed | D-006, D-007, D-008, D-009 |
| negative_proof_fixture | closed | D-004 |
| recognition | not_applicable | R-016, E-034 |

### Gate Closure

| Gate | Status | Support refs |
| --- | --- | --- |
| Owner-Level Fix | pass | D-001, D-003, E-002, E-023, A-001, A-003 |
| Ownership | pass | D-001, A-001 |
| Source-Of-Truth Singularity | pass | D-001, D-010, A-014, A-015, A-018 |
| Source-Truth Minimality | pass | D-001, D-010, M-002, M-003, A-003, A-009, A-014, A-015, A-018 |
| Boundary-Owned Policy | pass | D-002, D-003, D-005, D-006, D-007, D-008, D-010, A-001, A-002, A-004, A-006, A-008, A-010, A-011, A-014 |
| Dependency Direction | pass | D-001, A-018, E-023, E-034 |
| Solution Proportionality | pass | F-001, M-001, M-002, M-003, M-004, M-005, M-006, M-007, R-003, R-004, R-008, R-010, R-012, R-014, R-018 |
| Outcome-Proof Fit | pass | A-001, A-002, A-003, A-004, A-005, A-006, A-007, A-008, A-009, A-010, A-011, A-012, A-013, A-014, A-015, A-016, A-017, A-018, A-019 |
| Verification | pass | A-001, A-002, A-003, A-004, A-005, A-006, A-007, A-008, A-009, A-010, A-011, A-012, A-013, A-014, A-015, A-016, A-017, A-018, A-019 |
| Future Pressure | pass | P-001, P-002, P-003 |
| Handoff Consumability | pass | CONTRACT, H-001, H-002, H-003, H-004 |
| Negative Proof And Fixture Quarantine | pass | D-004, A-005 |
| State/Data Ownership | pass | D-002, D-003, D-004, D-007, D-010, A-002, A-003, A-005, A-009, A-014 |
| Sequenced Migration And Retirement | pass | D-012, A-016 |
| Temporal Surface Closure | pass | D-004, D-009, A-005, A-012 |
| All-Or-Nothing Failure Boundary | pass | D-006, D-007, D-008, D-009, A-007, A-009, A-011, A-012 |
| Bounded Recognition Scope | not_applicable | R-016, E-034 |

## Open Blockers

None
