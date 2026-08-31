---
schema: architecture-design/v4
date: 2026-08-31
commit: 12c277cd
branch: main
disposition: READY_FOR_CONTRACT
outcome: R-001
---

# Design: Canvas Unified Commit Confirmation Protocol

## Basis

### Sources

| ID | Kind | Locator | Use |
| --- | --- | --- | --- |
| S-001 | user | user request | Accepted design request, external Undo, Q1=A, Q2=A, Q3=A, final Q4=remove the created empty layer, simplicity constraint, and final scope confirmation; the earlier retain-layer proposal was explicitly superseded. The later TextEdit amendment adds only that seventh operation and supersedes the earlier text-editing exclusion. |
| S-002 | other | `/Users/blackpika/.codex/attachments/03c044b6-f7d7-4bb8-991e-9b07810d641b/pasted-text.txt` | Complete supplied specification, including exact public protocol names and failure ordering. |
| S-003 | research | `docs/history/research/2026-08-31-canvas-unified-commit-confirmation-protocol.md` | Historical route investigation, checked against current owners; not future behavioral authority. |
| S-004 | repository | `AGENTS.md` | Repository lifecycle, verification, and architecture ownership rules. |
| S-005 | repository | `docs/planning/README.md` | Active design and future Change Contract lifecycle. |
| S-006 | repository | `lib/src/contracts/public/canvas_runtime.dart` | Current configuration, editing capabilities, and command surfaces. |
| S-007 | repository | `lib/src/contracts/public/canvas_actions.dart` | Current Move request and action payload contracts. |
| S-008 | repository | `lib/src/contracts/public/canvas_deletion.dart` | Current deletion projection and policy types. |
| S-009 | repository | `lib/src/edit/edit_kernel.dart` | Sparse edit lifecycle and current immediate/deferred split. |
| S-010 | repository | `lib/src/edit/commit_applier.dart` | Prepared state, one-use deletion ownership, and install boundary. |
| S-011 | repository | `lib/src/store/document_store_kernel.dart` | Sparse preparation, bound install, candidate IDs, and structural reads. |
| S-012 | repository | `lib/src/edit/edit_session.dart` | Implicit layer creation, explicit restoration, and sparse journal admission. |
| S-013 | repository | `lib/src/edit/sparse_edit_structure.dart` | Element removal preserves its ordinary layer. |
| S-014 | repository | `lib/src/selection/selection_kernel.dart` | Selection normalization, ownership transfer, and revision advance. |
| S-015 | repository | `lib/src/runtime/runtime_root.dart` | Semantic routes, mutation guards, publication, actions, and callback delivery. |
| S-016 | repository | `lib/src/runtime/runtime_interaction_read_adapter.dart` | Move terminal reads and eraser facts. |
| S-017 | repository | `lib/src/interaction/pointer_session.dart` | Existing gesture capture lifetime. |
| S-018 | repository | `docs/contracts/public_api_v1.md` | Current public API authority and compatibility baseline. |
| S-019 | repository | `docs/contracts/edit_kernel.md` | Current edit preparation, rollback, and publication authority. |
| S-020 | repository | `docs/architecture/03_data_model.md` | Current sparse state ownership and work bounds. |
| S-021 | repository | `docs/architecture/02_package_boundaries.md` | Import and public/internal owner boundaries. |
| S-022 | repository | `docs/architecture/01_runtime_ownership.md` | Runtime and subsystem responsibilities. |
| S-023 | repository | `docs/contracts/operation_matrix.md` | Current operation classification and observable effects. |
| S-024 | repository | `docs/contracts/diagnostics.md` | Runtime diagnostics authority. |
| S-025 | repository | `docs/_registry/public_api_v1.yaml` | Machine-readable exported-name inventory, not signature authority. |
| S-026 | repository | `docs/architecture/architecture_graph.yaml` | Current architecture declarations and generated-view inputs. |
| S-027 | repository | `docs/verification/tests.md` | Existing behavioral coverage and permanent verification policy. |
| S-028 | repository | `test/runtime/fixtures/draw_commit_delivery_fixture.dart` | Draw preparation, candidate-ID, cleanup, and delivery witnesses. |
| S-029 | repository | `test/interaction/fixtures/move_machine_fixture.dart` | Existing Move resolution, cancellation, stale selection, and cleanup witnesses. |
| S-030 | repository | `test/api/fixtures/selection_deletion_resolver_fixture.dart` | Exact deletion projection and host-read/local-state callback witness. |
| S-031 | repository | `test/runtime/fixtures/common_commit_delivery_fixture.dart` | Delivery order, listener containment, and guard witnesses. |
| S-032 | repository | `test/api/fixtures/command_port_actions_fixture.dart` | Existing direct-command deletion policy witness. |
| S-033 | repository | `docs/README.md` | Durable documentation ownership and generated navigation entry point. |
| S-034 | repository | `docs/planning/FOLLOW_UPS.md` | Current unresolved-work registry; no registered competing work. |
| S-035 | repository | `docs/contracts/resources.md` | Application ownership of assets and runtime borrow release. |
| S-036 | repository | `lib/src/contracts/public/canvas_document.dart` | Public document, layer, and summary values. |
| S-037 | repository | `lib/src/contracts/public/canvas_element.dart` | Complete existing text element and inherited immutable fields. |
| S-038 | repository | `lib/src/contracts/public/canvas_element_update.dart` | Existing public text-field restoration capability. |
| S-039 | repository | `lib/src/edit/element_update_application.dart` | Text update identity and revision semantics. |
| S-040 | repository | `test/runtime/fixtures/text_editing_port_fixture.dart` | Existing text session, dismissal callback, and failure witnesses. |
| S-041 | repository | `test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart` | Text request consumption, validation, and preparation-failure witnesses. |
| S-042 | repository | `lib/src/store/family_tables.dart` | Exact per-element text projection from committed/prepared rows. |
| S-043 | repository | `lib/src/frame/frame_text_layout_measurer.dart` | Existing text sizing inputs and derived measured bounds. |

### Source Coverage

| Kind | Sources or none |
| --- | --- |
| prior_design | none |
| research | S-003 |
| plan | none |
| user | S-001 |
| repository | S-004, S-005, S-006, S-007, S-008, S-009, S-010, S-011, S-012, S-013, S-014, S-015, S-016, S-017, S-018, S-019, S-020, S-021, S-022, S-023, S-024, S-025, S-026, S-027, S-028, S-029, S-030, S-031, S-032, S-033, S-034, S-035, S-036, S-037, S-038, S-039, S-040, S-041, S-042, S-043 |
| other | S-002 |

### Evidence

| ID | Source | Locator | Observed fact |
| --- | --- | --- | --- |
| E-001 | S-003 | `lines 1-48` | The research describes separate Move and deletion callbacks and a deletion-only deferred package at commit 8aa192df. |
| E-002 | S-006 | `lines 23-42` | Public configuration currently requires deletion confirmation and permits an absent Move resolver. |
| E-003 | S-007 | `lines 221-314` | Move requests contain element reads and proposed displacement; their decisions have no lease. |
| E-004 | S-008 | `lines 51-75` | Deletion entries contain the complete element, a non-null ordinary layer ID, and element index. |
| E-005 | S-009 | `lines 86-192` | Ordinary edit/interaction preparation installs immediately; deletion preparation returns a deferred package and closes its edit handle. |
| E-006 | S-010 | `lines 291-407` | Deferred deletion prepares Store/selection ownership, then permits one consume or discard. |
| E-007 | S-011 | `lines 1107-1172` | Ordinary sparse install checks freshness; deletion binds the checked document and ID ledgers before its later assignment. |
| E-008 | S-014 | `lines 98-133` | Selection installs owned normalized IDs and advances its revision only when membership changes. |
| E-009 | S-015 | `lines 975-984` | The direct Move command currently enters the immediate transform route without Move confirmation. |
| E-010 | S-015 | `lines 1248-1271` | Direct element removal currently installs an edit and emits a removal action without deletion confirmation. |
| E-011 | S-015 | `lines 1937-2002` | The callback guard rejects nested callbacks and public mutation; its entry also rejects invocation during commit-effect delivery. |
| E-012 | S-015 | `lines 2416-2498` | Common delivery publishes state before actions while holding the delivery guard. |
| E-013 | S-016 | `lines 243-280` | Move terminal reads reconstruct current participating element facts rather than compare their revisions with gesture-start snapshots. |
| E-014 | S-017 | `lines 25-97` | The selected-move session captures IDs, selection revision, and pointer origin, but no initial element transforms or revisions. |
| E-015 | S-012 | `lines 534-579` | Adding a draw element without a target layer can create default-layer when no ordinary layer exists. |
| E-016 | S-013 | `lines 113-131` | Removing an element removes its membership but does not delete its ordinary layer. |
| E-017 | S-006 | `lines 157-180` | Public editing supports layer creation and element restoration, but has no empty-layer removal or selection-setting operation. |
| E-018 | S-012 | `lines 939-964` | Explicit element admission rejects a currently present ID rather than every historically used ID. |
| E-019 | S-007 | `lines 58-162` | Current action payloads do not provide complete deleted elements or drawn stroke geometry for independent reconstruction. |
| E-020 | S-020 | `lines 128-158` | Store owns the private sparse candidate, bounded preparation, and accepted installation; a successful Store install is not rolled back. |
| E-021 | S-019 | `lines 223-269` | Runtime owns cleanup and delivery after closed edit preparation; the deletion branch pre-binds Store and Selection installation. |
| E-022 | S-018 | `lines 1811-1829` | Selection excludes background; transformability requires unlocked elements while deletion uses the separate deletable flag. |
| E-023 | S-032 | `lines 49-80` | A direct removal command is exercised on an element whose isDeletable flag is false. |
| E-024 | S-025 | `lines 1-12` | The exported-name registry explicitly lists the legacy deletion confirmation family and delegates semantic authority to the public API contract. |
| E-025 | S-026 | `lines 1-20` | The architecture graph covers contracts, runtime, Store, selection, edit, interaction, and frame owners. |
| E-026 | S-030 | `lines 340-357` | A deletion resolver reads the full document, pushes and pops it in a host-local list, then cancels; this witnesses callback reads/local work, not Undo replay. |
| E-027 | S-028 | `lines 397-468` | Draw preparation-failure coverage observes unchanged revision and an available candidate element ID. |
| E-028 | S-029 | `lines 1208-1285` | Move coverage observes a resolver-adjusted displacement in both the resulting transform and action. |
| E-029 | S-031 | `lines 447-490` | An ordinary throwing action listener does not prevent a peer listener and observer from seeing the accepted commit. |
| E-030 | S-035 | `lines 159-170` | Application-owned assets are not disposed when the engine releases its borrow. |
| E-031 | S-036 | `lines 14-36` | A public document can have no ordinary layers. |
| E-032 | S-015 | `lines 2077-2126` | Runtime publication constructs state, publishes the root and mirrored surface frames, and then assigns the public state notifier. |
| E-033 | S-011 | `lines 3732-3795` | ID candidate observation, reservation, and accepted-ledger admission have separate roles. |
| E-034 | S-005 | `lines 21-56` | Direct-child designs and plans are active registrations; historical artifacts do not own current behavior. |
| E-035 | S-034 | `lines 1-14` | The follow-up registry contains no current concern entries. |
| E-036 | S-015 | `lines 1310-1394` | commitTextEdit validates and qualifies the request, consumes equal-text no-ops without an action, and currently installs changed text before common delivery without confirmation. |
| E-037 | S-037 | `lines 18-250` | CanvasTextElement includes text, formatting/layout inputs, inherited identity/revision, transform, flags, and metadata; measured width and height are not stored element fields. |
| E-038 | S-015 | `lines 1360-1470` | Changed-text preparation may compensate transform translation using current/next measured layout to preserve the existing horizontal anchor and top edit edge. |
| E-039 | S-018 | `lines 1752-1769` | Current changed-text delivery clears a matching active session before common delivery and expressly permits its listener to complete a separate nested mutation first. |
| E-040 | S-040 | `lines 732-770` | Injected failed preparation and invalid text preserve the active session and live request; these cases do not establish recovery from a real Store installation failure. |
| E-041 | S-041 | `lines 361-412` | Command coverage keeps a request live after a non-publishing preparation result and successfully retries after input validation fails. |
| E-042 | S-011 | `lines 887-918` | Sparse Store preparation normalizes and freezes rows before returning the accepted document, which is available before installation. |
| E-043 | S-042 | `lines 2025-2049` | TextRow.toElement projects the complete text element, including revision, transform, metadata, and every formatting/layout field. |
| E-044 | S-038 | `lines 14-208` | Public text updates accept the text-specific and common mutable element fields; host restoration need not remove and re-add an existing text element. |
| E-045 | S-039 | `lines 192-214` | A text update preserves element ID and creates the resulting element with revision incremented by one rather than restoring a supplied historical revision. |
| E-046 | S-043 | `lines 76-107` | Text layout consumes fontSize, lineHeight, and maxWidth and derives painter width/height and local bounds; those measurements remain layout-owned data. |
| E-047 | S-015 | `lines 3861-4063` | Text-session notification already supports silent value replacement and later explicit notification; matching-request dismissal currently notifies synchronously. |
| E-048 | S-015 | `lines 4268-4288` | Session commit delegates to commitTextEdit; subsequent dismissal checks session identity and cannot dismiss a different newly active session. |

### Requirements

| ID | Kind | Statement | Basis | Open shape |
| --- | --- | --- | --- | --- |
| R-001 | outcome | A host can approve or reject each supported user document operation before commitment and reliably record only applied operations for its own Undo. | S-001, S-002 | Host history storage, grouping, and UI remain host choices. |
| R-002 | constraint | Preserve the specification's synchronous CanvasCommitResolver with the approved TextEdit amendment: seven immutable sealed request variants, resolution variants, CanvasCommitLease callbacks, and prohibition on exposing internal transaction values. | S-001, S-002 | Public request data beyond the specified fields is designed here; private decomposition is not prescribed. |
| R-003 | constraint | Draw, Delete, Erase, Rotate, Reflect, and TextEdit are fully validated and exactly prepared before resolution; Move captures its immutable basis first and exactly prepares only the accepted final displacement. Each admitted non-no-op operation invokes the resolver exactly once, with no second call for an adjusted Move. | S-001, S-002 | Preparation implementation is free inside the accepted ownership and timing boundary. |
| R-004 | constraint | Move acceptance replaces proposedDelta with the complete displacement relative to operation-start transforms; one operation has at most one document application and one committed action carrying the actual displacement. | S-002 | The existing transform action representation may be retained if it expresses the applied displacement without ambiguity. |
| R-005 | constraint | Successful application irrevocably selects committed; only non-application selects aborted. After an acceptance returns, the selected lease method is attempted exactly once. Public-state publication precedes committed and action delivery follows it; notification failures cannot change the selected result, and a throwing committed callback cannot suppress the action. | S-002 | Internal lifecycle representation is free; no retry of a terminal callback is permitted. |
| R-006 | constraint | Cancellation, resolver error, incompatible resolution, and pre-install failure leave committed document, document revisions, commit-owned selection, and ID admission unchanged and emit no committed action; temporary interaction cleanup remains permitted. | S-002 | Cleanup representation is free, including restoration of still-owned provisional selection. |
| R-007 | constraint | A document no-op skips the resolver; accepted final Move zero or final unchanged preparation aborts its lease without installation or action. | S-002, E-020 | Existing valid dot strokes and zero-length line additions remain document changes. |
| R-008 | constraint | Resolver and lease callbacks reject public mutation and nested callback entry; callback failures are contained and diagnosed without sensitive request data or a change to the operation result. | S-002, S-024, E-011 | Reuse the runtime diagnostics owner; bounded diagnostic codes and internal helpers are implementation choices. |
| R-009 | user_decision | Requests and accepted-operation observation must let hosts retain sufficient immutable data to undo and redo the named document operations without retaining a whole-document copy. | S-001, E-004, E-019, E-026 | Hosts choose their history representation; public domain snapshots may share immutable backing. |
| R-010 | user_decision | Confirmation covers Draw, Delete, Erase, Move, Rotate, Reflect, and TextEdit through gestures and corresponding semantic commands, including direct moveSelection, commands.removeElement, and commitTextEdit; service edits and history replay bypass confirmation and do not create user actions. | S-001, E-009, E-010, E-005 | Route-local adapters are free; there is no inferred user intent for arbitrary edit callbacks. |
| R-011 | user_decision | Hosts can restore document content and desired selection together in one atomic existing edit operation. | S-001, E-017 | Extend existing editing capabilities; do not add a second public transaction lifecycle. |
| R-012 | user_decision | A gesture Move is cancelled as a whole when any participating element changes or external selection changes; accepted external edits remain applied, while unrelated object edits do not cancel the Move. | S-001, E-013, E-014 | Capture and conflict-detection representation are open; the operation-start basis cannot be silently rebased. |
| R-013 | user_decision | A host can remove the empty layer created by the undone Draw in the same edit as document/selection restoration; pre-existing or nonempty layers must not be removed as a side effect of that Undo. | S-001, E-015, E-016, E-017, E-031 | Add only the missing empty-layer editing capability; the host owns history provenance. |
| R-014 | user_decision | Build on existing deferred deletion and shared owner boundaries with the smallest complete change; do not introduce a universal transaction manager or speculative abstractions. | S-001, E-005, E-006, E-020 | Private helper names, count, and file decomposition remain open. |
| R-015 | exclusion | No engine-owned Undo/history, public beginTransaction/commit/rollback, post-commit inverse transaction, whole-document confirmation snapshot, asynchronous resolver, per-tool resolver, second corrective Move, or new confirmation for arbitrary edit, load, clear-content, text-session setup/live draft updates, camera, or selection-only operations. | S-001, S-002 | Existing independent behaviors of these excluded routes remain authoritative. |
| R-016 | repository_rule | Preserve sparse affected-owner preparation and existing immutable sharing; no new full-document scans/copies or second mutable document/selection authority are introduced for confirmation or history reconstruction. | S-004, S-020, E-020 | Work may scale with changed elements, their actual snapshot geometry, selected IDs where already required, and affected structural owners. |
| R-017 | constraint | Replace both old configuration callbacks and retire their obsolete resolver/request/resolution surfaces with a coherent source-breaking public migration, while retaining independently useful deletion policy/availability and element-read contracts. | S-002, E-002, E-003, E-004, E-024 | Names explicitly mandated by the specification are fixed; unrelated API and serialized document schema remain compatible. |
| R-018 | constraint | Preserve existing operation eligibility, tools, pivot rules, resource retention, and action families except the explicitly approved confirmation, gesture-conflict, and restoration-capability changes. | S-001, S-018, S-023, S-035, E-022, E-023 | Internal routes can consolidate without redefining deletion protection or adding tools. |
| R-019 | repository_rule | Durable behavior belongs to current contracts/architecture and their owning code; verification must observe real boundary outcomes and admit each permanent failure family independently rather than freeze private shape or scan prose. | S-004, S-005, S-021, S-022, S-027, S-033 | Existing verification owners and fixtures are preferred; fixture layout is not locked. |
| R-020 | constraint | Generalize the private PreparedInteractionCommit consume/discard lifetime, terminal at most once. Every supported application atomically installs document, revisions, admitted IDs, and commit-owned selection: all fallible validation, data preparation, and ownership checks precede the first committed mutation, with no fallible callbacks or further checks in the install tail. Post-commit publication and notifications are outside that tail. | S-002, E-006, E-007, E-008 | Existing sealed delivery results may be reused; no second transaction payload or rollback mechanism is required. |
| R-021 | user_decision | Add only TextEdit to the previously approved protocol scope. CanvasTextEditCommitRequest carries full immutable CanvasTextElement before and after values, including text, formatting, sizing inputs, metadata, and transform. Existing commitTextEdit uses the same non-Move preparation, resolver, lease, atomicity, no-op, failure, and existing editText action rules. These snapshots must support external Undo/Redo without engine history or a new text-layout/data model. | S-001, E-036, E-037, E-038, E-044, E-045, E-046 | Existing text rendering, UI, and public editing capabilities remain; measured dimensions stay derived and restoration does not rewind revisions. |

## Candidate Analysis

- Comparison: `two_or_three`
- Result: `selected F-001`
- Result basis: F-001, F-002, M-001, M-002, M-003, M-004, M-005, M-006, M-007, R-014, E-005, E-006, E-011, E-012, E-020, E-021

### Forms

| ID | Form | Hard constraints | Main trade-off | Basis |
| --- | --- | --- | --- | --- |
| F-001 | Runtime-owned confirmation lifecycle over generalized Edit/Store prepared installation; ordinary service edits remain immediate consumers of their shared preparation, with only the two accepted restoration capabilities added and TextEdit admitted through its existing semantic command. | pass | Keeps the resolver, callback guard, and publication/lease ordering at their current runtime owner; preserves lower-level document and selection owners and the service-edit exemption. | R-003, R-010, R-011, R-013, R-014, R-021, E-005, E-006, E-011, E-012, E-021, E-036, E-039 |
| F-002 | Edit-owned confirmation lifecycle over the same generalized prepared installation; runtime passes semantic requests into Edit and exposes a delivery continuation so Edit can settle a lease between state and action. | pass | Can satisfy the same outcomes, but additionally transfers semantic request/lease ownership into Edit and requires a cross-owner publication-stage continuation while the guard and delivery remain runtime-owned. | R-003, R-005, R-010, R-021, E-005, E-011, E-012, E-021, E-036, E-039 |

### Material-Obligation Delta

| ID | Material obligation | F-001 | F-002 | Independent authority |
| --- | --- | --- | --- | --- |
| M-001 | R-003 | yes | yes | R-003, E-005, E-006, E-020 |
| M-002 | R-005 | yes | yes | R-005, E-011, E-012, E-021 |
| M-003 | R-010 | yes | yes | R-010, E-005, E-009, E-010 |
| M-004 | R-011 | yes | yes | R-011, E-008, E-017 |
| M-005 | R-013 | yes | yes | R-013, E-015, E-016, E-017 |
| M-006 | Cross-owner semantic confirmation and publication-stage continuation | no | yes | none |
| M-007 | R-020 | yes | yes | R-020, E-006, E-007, E-008 |
| M-008 | R-021 | yes | yes | R-021, E-036, E-039 |

### Future Pressures

| ID | Pressure | Basis | Treatment | Closure refs | Accepted cost or risk |
| --- | --- | --- | --- | --- | --- |
| P-001 | External history retains operation data beyond the synchronous confirmation callback and replays it later. | R-009, E-004, E-019, E-026 | absorbed | D-002, D-007, D-008 | Hosts retain immutable operation facts and their own assets; the engine does not acquire history persistence or asset-storage responsibilities. |

## Decision Register

### D-001 — Runtime confirmation and existing subsystem ownership
- Concerns: `form`, `owner`, `in_scope`, `out_of_scope`, `source_of_truth`, `dependency`
- Lock: Runtime owns semantic operation classification, resolver invocation, lease settlement, and delivery order. Edit owns preparation and the single-use apply lifetime; Store owns committed document/revisions/admitted IDs; Selection owns selection and its revision; Interaction owns gesture capture and cleanup. Shared declaration-only contracts stay below implementation owners, and the public facade exports public values only. The admitted routes are pencil/marker strokes and all line terminal additions as Draw, selection deletion and direct command removal as Delete, terminal eraser as Erase, pointer and command selection movement as Move, the existing two rotations as Rotate, both existing flips as Reflect, and changed commitTextEdit calls (including CanvasTextEditSession.commit delegation) as TextEdit. Route eligibility remains unchanged: selection deletion respects its policy, direct removal retains its existing broader eligibility including background, and locked/deletable flags retain their separate meanings. Direct removal returns true only after actual application, false for cancellation or no-op. R-015 routes retain their independent behavior and cannot acquire confirmation by inference from low-level add/remove/update operations. The host alone owns Undo records and asset retention; the engine retains neither completed requests nor leases as history.
- Open: Cohesive runtime-local helper extraction, private method names, and declaration file layout; no new cross-owner transaction manager or configurable routing registry.
- Basis: R-001, R-010, R-014, R-015, R-018, R-019, R-021, E-001, E-035, E-036, E-005, E-006, E-009, E-010, E-011, E-012, E-020, E-021, E-022, E-023, E-030
- Form: F-001
- Realizes: M-003
- Depends on: none
- Contract targets: `classification`, `owner`, `scope`, `source_of_truth`, `dependency`, `acceptance`, `verification`, `durable_impact`, `unit_family`
- Rationale: The runtime already knows the user operation and owns both guarded callbacks and publication; retaining that responsibility avoids the additional continuation obligation of F-002 without duplicating Store or Selection authority.

### D-002 — Public operation facts for confirmation and external history
- Concerns: `state_data`, `policy`
- Lock: One required CanvasRuntimeConfig.commitResolver uses the specified synchronous sealed request and resolution families. Requests expose pre-resolution documentSummary and documentRevision plus an immutable selectedElementIdsBefore snapshot; for a pointer Move that selection snapshot is the pre-gesture selection, before provisional replacement. Collections are owned immutable snapshots, not lazy reads from live runtime state. A public immutable CanvasCommitElementEntry carries the complete CanvasElement, nullable layerId, and elementIndex; null layerId unambiguously means the ordered background list, otherwise the index is within that ordinary layer. Draw supplies its exact proposed entry, pencil/marker/line tool, target layerIndex, and createsLayer flag from prepared structural facts. This supports restoring the layer only when that Draw created it, without exposing a transaction plan. Delete supplies the complete canonical ordered removal entries; Erase supplies those entries plus immutable corridorWorld points and eraserThickness. Move preserves immutable movedElements using CanvasElementRead, proposedDelta, and initial selectionBoundsWorld; the reads contain each participant's initial transform and element revision. Rotate and Reflect supply immutable affected CanvasElementRead values, pivotWorld, the exact world transform, and the existing CanvasTransformOperation restricted respectively to the two rotations or two flips. TextEdit supplies CanvasTextEditCommitRequest extends CanvasCommitRequest with final CanvasTextElement before and final CanvasTextElement after. Both are complete immutable elements with the same target ID: all text, formatting/layout inputs, metadata, transform, inherited flags, and revision are retained. before is the current committed target after request qualification; after is projected from the exact normalized prepared candidate, including any existing anchor-preserving transform compensation and its resulting revision. Sizing means the existing element fields such as fontSize, maxWidth, and lineHeight; measured width/height remain derived layout facts, not new stored fields. Existing addressable Store projections supply these two public values without exposing the prepared transaction or materializing the whole document. Only Move permits a changed proposal through its accepted delta. Accepted requests may be retained by the host after the callback; only that host owns their longer lifetime. Existing immutable element/geometry backing may be shared. Removed resource descriptors remain in the document under existing deletion semantics; retaining or restoring externally discarded assets/descriptors belongs to the host, not this protocol.
- Open: Constructor organization and immutable-list implementation. The specified protocol names and the facts and meanings above are fixed; no new general-purpose public diff or transaction type is needed.
- Basis: R-002, R-003, R-009, R-013, R-017, R-018, R-021, E-002, E-003, E-004, E-015, E-019, E-022, E-026, E-030, E-037, E-038, E-042, E-043, E-046
- Form: F-001
- Realizes: none
- Depends on: D-001
- Contract targets: `state_data`, `policy`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: Per-operation domain facts provide exactly the content, placement, and transforms needed for host reversal while keeping internal apply capabilities private and avoiding whole-document history snapshots.

### D-003 — Single-use preparation and the irreversible install boundary
- Concerns: `owner`, `state_data`, `atomicity`
- Lock: Generalize the existing deletion package into an internal PreparedInteractionCommit with consume and discard terminals. Its PreparedInteractionApplyResult uses the existing sealed CommitDeliveryResult meaning, not another mutable result or lease-bearing cross-owner payload. Edit preparation closes the edit handle before returning the package. Store validates and prepares the changed sparse candidate; a private affected-element projection makes its exact TextEdit after value available before resolution, without a second preparation; the applier seals exact delivery/action inputs, precomputes selection normalization and its resulting revision, validates all installer capabilities, and binds the document and admitted-ID ledgers. Before the first committed assignment, consume checks one-use ownership and freshness and transfers every backing needed by the install tail. That first Store assignment is irreversible; the remaining tail only installs already prepared ID and selection ownership and returns sealed data. It performs no fallible callbacks, validation, normalization, copying, or public notification. No mutation observer can run between document and selection installation. discard releases private references and never installs; repeated terminals fail before mutation. A pre-install failure releases the package without a rollback transaction. Ordinary service edits reuse the same preparation/installation invariants and consume immediately without a resolver; explicit materialized-draft fallback must preserve the same atomic restoration guarantee rather than bypass it. An unchanged document with a changed explicit selection uses the existing selection-only branch, and a completely unchanged candidate uses neither installer.
- Open: Bound capability representation, private terminal-state encoding, and reuse or aliasing of the existing result type. No public access to prepared ownership and no new independently mutable committed-state copy.
- Basis: R-003, R-006, R-011, R-014, R-020, R-021, E-005, E-006, E-007, E-008, E-020, E-021, E-042, E-043
- Form: F-001
- Realizes: M-001, M-007
- Depends on: D-001
- Contract targets: `owner`, `state_data`, `atomicity`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: Moving the deletion guarantee to the owning apply boundary closes the shared partial-install risk instead of adding cancellation or rollback patches to each tool.

### D-004 — Resolution, lease finality, cleanup, and notification order
- Concerns: `temporal`, `order`, `policy`
- Lock: Runtime executes a synchronous operation-local lifecycle: validated non-no-op preparation or Move basis, one guarded resolver call, cancellation/discard or compatible acceptance, optional final Move preparation, consume, operation-owned publish-suppressed cleanup, shared spatial/resource effects and root/bridged frame publication, public-state publication, guarded lease.committed, one action, existing observer, guard release. Without application, an obtained lease receives aborted exactly once; a Cancel or thrown resolver with no returned lease has no lease terminal. A mismatched acceptance still transfers its returned lease and therefore aborts it while diagnosing the incompatible result. An unhandled resolver or guard error discards and cleans up; a callback that catches a rejected nested mutation may still return a valid resolution. Lease ownership is taken before any accepted-delta validation, and the terminal method is marked attempted before calling host code; a thrown terminal is never retried or followed by its opposite. Application irrevocably selects committed, so later notification errors cannot enter an abort path. Runtime contains failures at post-install notification boundaries, including a thrown frame bridge or error-reporting callback, and continues public state, lease, and action delivery from sealed data; no inverse edit follows. Ordinary input/preparation failures retain their owning error channel after required discard/abort and cleanup, while resolver and lease failures are diagnostic-only. Runtime uses the same callback mutation exclusion for resolver and lease but separates its private guarded-callback entry from the public delivery-entry check, allowing lease callbacks inside existing delivery without permitting nested public mutation, ID generation, disposal, or a second resolver. Public reads and host-local history work remain allowed. Rejection cleanup affects only the operation's own session/preview/provisional selection. Diagnostics use bounded operation, phase, and error-category facts, never request contents, arbitrary reason/error text, element data, or leases; a guard rejection is not double-recorded as a resolver failure. Disabled diagnostics do not build details. Diagnostics reporting itself cannot prevent lease settlement or action delivery. This guarantee covers recoverable synchronous validation and callback failures, not process termination or exhaustion that prevents execution.
- Open: Runtime-local lifecycle representation, bounded internal diagnostic codes, and callback-containment helpers; existing resource/observer behavior outside the admitted operations is not expanded into a new diagnostics project.
- Basis: R-003, R-005, R-006, R-007, R-008, R-010, R-020, E-011, E-012, E-021, E-026, E-029, E-032
- Form: F-001
- Realizes: M-002
- Depends on: D-001, D-002, D-003
- Contract targets: `temporal`, `order`, `policy`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: Keeping a returned lease in runtime-local ownership allows every exit to settle it according to actual application while preserving the required state-before-lease-before-action sequence.

### D-005 — Move capture, conflict detection, and preview lifetime
- Concerns: `state_data`, `temporal`
- Lock: Interaction captures the admitted participant set, initial transforms/element revisions, initial bounds, prior selection, and existing session/epoch identity when the selected Move gesture starts. Runtime obtains those immutable intent-specific facts through the existing read boundaries, not a public document projection. A command Move captures its basis at command entry and has no pointer-session ownership. While a gesture is active, the shared runtime accepted-change boundary compares actual accepted touched element IDs with its participants and observes external selection changes. An intersection, including same-ID replacement, cancels the whole gesture before publishing the external change; the external accepted document/selection remains authoritative. No-op candidate edits do not invalidate a gesture. Unrelated object edits do not cancel it: global document revision inequality is not a stale predicate. Existing load/mode/dispose cleanup remains effective. The successful gesture's own application closes that session before external-change invalidation is considered. Provisional selection restoration checks existing ownership/revision conditions and cannot overwrite a newer external selection. Preview capture uses the immutable admitted participant IDs; it must not adopt newly transformable selected objects. Runtime supplies this session-owned read-only view through the existing frame capture inputs without a new mutable mirror or changing the public delta-only preview contract. Because an accepted participating change terminates the session before publication, active preview may reuse current participant geometry while its transform basis remains the captured start. Terminal qualification verifies session identity and the retained conflict outcome before invoking the resolver; invalidated gestures cannot emit a partial-subset Move or a resolver call. All retained basis references are released by terminal cleanup.
- Open: How existing accepted touched facts and selection outcomes reach Interaction, and the internal frame-input field layout. No persistent per-element generation registry or whole-document revision guard is required.
- Basis: R-003, R-006, R-012, R-014, R-016, E-013, E-014, E-020
- Form: F-001
- Realizes: none
- Depends on: D-001, D-002, D-003
- Contract targets: `state_data`, `temporal`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: Accepted changed-element facts detect replacements that an initial id-plus-revision comparison can miss, without cancelling gestures for unrelated edits or introducing another persistent identity owner.

### D-006 — Final Move displacement and no-op boundary
- Concerns: `policy`
- Lock: Before resolution, validate the proposed Move and freeze its basis without installing or building an exact final transaction. After CanvasMoveCommitAccept, validate both delta coordinates as finite; zero aborts the returned lease without preparing a changed commit. Otherwise construct one exact transaction by applying CanvasTransform.translation(finalDelta) to every captured initial transform, validate all resulting elements through their existing admission, and prepare against the current unchanged-during-resolution Store baseline. Overflow, invalid transforms, stale ownership, or final committed-fact equality take the non-application exit. The action retains the existing CanvasTransformActionPayload with operation move and delta equal to CanvasTransform.translation(finalDelta); tx and ty are explicitly the full applied displacement, with no extra correction and no duplicated displacement field. Proposed-zero, empty/ineligible participants, and cleanup-only terminals remain resolver-silent. Dot strokes and zero-length line additions remain eligible Draw changes when current geometry validation accepts them; document equality, not visual extent, defines the general no-op boundary.
- Open: Existing typed update dispatch and finite-validation helper reuse; no new snapping policy, correction pass, or action family.
- Basis: R-003, R-004, R-007, R-018, E-003, E-019, E-027, E-028
- Form: F-001
- Realizes: none
- Depends on: D-002, D-003, D-004, D-005
- Contract targets: `policy`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: A host can choose the final displacement once and record exactly the transform the engine will apply, while the existing action contract remains sufficient and unambiguous.

### D-007 — Selection restoration in the existing edit transaction
- Concerns: `state_data`, `atomicity`
- Lock: Extend CanvasEdit with void setSelection(Iterable<CanvasElementId> ids). The edit session snapshots a pending desired-selection intent; it never calls the live Selection setter during the callback. Last explicit selection intent wins and is normalized by the Selection owner against the final prepared document, using existing content/visibility/selectability rules. An explicit intent replaces implicit prune or replacement-clear behavior; without it those existing defaults remain unchanged. Setter order relative to element restoration or draft materialization does not alter final-document normalization. Edit preparation carries document and this optional selection outcome into D-003's one install boundary and publishes once after both are visible, without resolver, lease, or user action. This works for ordinary sparse edits, explicit draft promotion, and document replacement without bypassing replacement validation. A selection-only effective change advances only selection revision; unchanged normalized selection with unchanged document is silent. Callback/preparation failure discards the intent with the draft. Existing selection commands outside an edit remain unchanged. Hosts may restore IDs and transforms in the same callback and choose whether to supply selection at all; the engine does not choose their Undo policy or restore historical revision counters.
- Open: Session-local intent storage and compiler plumbing into existing prepared-selection effects; no public draft-selection reader is required.
- Basis: R-009, R-010, R-011, R-014, R-020, E-005, E-008, E-017, E-018, E-020
- Form: F-001
- Realizes: M-004
- Depends on: D-001, D-003
- Contract targets: `state_data`, `atomicity`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: The missing capability is staging desired selection beside existing document edits, not introducing a separate restoration transaction or synchronizing two publications.

### D-008 — Empty-layer removal for complete Draw reversal
- Concerns: `state_data`, `atomicity`, `policy`
- Lock: Extend CanvasEdit with bool removeEmptyLayer(CanvasLayerId id). The owning edit structure returns false without mutation when the ordinary layer is absent or nonempty in the current callback-local state, and removes only that layer when empty. It never deletes elements, descriptors, or background, and never performs automatic empty-layer garbage collection. Sparse journal replay, direct Store preparation, and explicit Draft promotion/materialization share this operation's semantics, final-state equality, structural revision, and projection rules. Removing a just-undrawn element and its newly created empty layer composes with D-007 in one edit and D-003's atomic installation. D-002's createsLayer and placement facts let the host identify the layer created by that Draw; the host uses that provenance and must not treat a pre-existing empty layer as part of the Draw reversal. The engine validates current emptiness rather than storing an Undo-specific layer-origin registry. Re-adding on redo can use existing ensureLayer and addElement placement; explicit reuse of removed IDs remains supported and generators do not rewind. A remove/recreate sequence whose final document and selection equal the baseline is a no-op under existing finalization.
- Open: Internal structural mutation DTO and operation implementation inside current owners. No general layer-reordering, cascading deletion, history, or resource-cleanup API is introduced.
- Basis: R-009, R-011, R-013, R-014, R-018, R-020, E-015, E-016, E-017, E-018, E-020, E-031, E-033
- Form: F-001
- Realizes: M-005
- Depends on: D-002, D-003, D-007
- Contract targets: `state_data`, `atomicity`, `policy`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: A guarded empty-layer edit fills the confirmed restoration gap and composes with existing mutation ownership; origin tracking stays with the application that actually owns the history.

### D-009 — Coherent public and internal migration
- Concerns: `compatibility`, `migration_retirement`
- Lock: This is an intentional source-breaking API revision, not a serialized document-format migration. Replace the two config callbacks with required commitResolver; preserve pointer/tool settings, deletion policy/availability, eraser-kind filtering, and CanvasElementRead. Replace the old Move resolution family and deletion confirmation request/decision/operation family with the new sealed protocol; replace deletion-only entries with the general public entry projection. Retire obsolete moveCommitResolver, deletionCommitResolver, CanvasMoveCommitResolver, CanvasDeletionCommitResolver, CanvasMoveResolution/CanvasMoveCommit/CanvasMoveCancel, CanvasDeletionCommitRequest/CanvasDeletionDecision/CanvasDeletionOperation/CanvasDeletionEntry exports and production references after their consumers are migrated. Move the retained CanvasMoveCommitRequest meaning into the new hierarchy. Public consumers switch over request type, return the matching acceptance with a host-owned lease or Cancel, and use the original proposed delta when accepting an unadjusted Move. A host with no history can supply its own no-op lease. Existing accepted action type/transform payloads stay compatible. TextEdit adds its new request variant but retains CanvasActionType.editText and the existing length-only CanvasTextEditActionPayload; full text and metadata belong in before/after, never in that action or diagnostics. Its changed-session close notification adopts D-012's post-delivery position; the former nested-before-outer-action listener order is intentionally retired as part of adding TextEdit to the unified protocol. The safe migration order is shared prepared/restoration capabilities, public protocol and coordinated runtime/config/route consumers, then retirement of obsolete paths once every admitted route uses the new owner. No published intermediate version runs old and new confirmation for one operation. Ordinary service-edit behavior remains exempt, public declarations remain cycle-free, and internal prepared types stay unexported. Existing compile/export/integration consumers and owning behavioral witnesses are migrated with the API; version/release notes must identify this source break without changing schema_v1. Historical research and completed plans keep their historical API descriptions.
- Open: Commit grouping and internal symbol renames that preserve these dependency and retirement gates; no compatibility shim or dual-resolver precedence policy.
- Basis: R-002, R-010, R-014, R-017, R-018, R-019, R-021, E-002, E-003, E-004, E-024, E-025, E-034, E-039
- Form: F-001
- Realizes: none
- Depends on: D-001, D-002, D-003, D-004, D-005, D-006, D-007, D-008
- Contract targets: `compatibility`, `migration_retirement`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: One coordinated breaking migration removes parallel policy ownership rather than retaining permanent adapters between the old confirmation families.

### D-010 — Boundary verification without private-shape enforcement
- Concerns: `negative_proof_fixture`, `recognition`
- Lock: Invalid resolutions, reentrant mutation attempts, repeated prepared terminals, invalid final transforms, stale gestures, and nonempty-layer removal are observed at their real production owning boundaries. Synthetic invalid inputs and failure injection remain test-only and cannot become production truth or exported capabilities. Reuse existing owner-level failure injection/observation seams where adequate; any missing seam must target a real pre-install boundary and cannot inject a normal fallible callback into the committed install tail. Public migration recognition is bounded to the analyzer-resolved root package export namespace, public signatures, and the current exported-name registry; it rejects retired confirmation exports and leaked private prepared types, not alternative coherent private implementations. Dependency recognition remains the existing architecture graph/import boundary machinery. Do not add a feature-local source scanner, prose-parsing test, copied inventory, or exact helper-layout assertion. Each independent durable regression family requires its own admission identifying its stable failure/invariant, owner, failing witness, and lasting value; existing fixtures may be adapted instead of multiplied.
- Open: Fixture organization and assertion mechanics that directly observe the claimed behavior; no fixed test names or exact private call sequence is an oracle.
- Basis: R-014, R-017, R-019, R-020, E-006, E-024, E-025, E-027, E-028, E-029
- Form: F-001
- Realizes: none
- Depends on: D-001, D-003, D-004, D-009
- Contract targets: `negative_proof_fixture`, `recognition`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: Behavioral failure boundaries and the existing central public-surface machinery are sufficient; a new general analyzer or duplicated registry would not establish the operation guarantees.

### D-011 — Bounded preparation and retained-state cost
- Concerns: `state_data`, `policy`
- Lock: Preserve the Store's existing sparse affected-owner work bound and immutable structural sharing. Non-Move exact preparation is not repeated after acceptance; Move prepares its exact transaction once from finalDelta, not once for preview and again for correction. Requests copy only needed collections of affected facts and actual draw/eraser geometry and affected text snapshot data, never a public whole-document snapshot or a duplicate mutable Store. Gesture basis is a temporary immutable historical value with a distinct purpose from live Store state; it shares backing with request/preview reads where safe and dies at cleanup unless the host retains the public request. Conflict checks consume accepted touched IDs and active participant membership rather than rescan the document. Staging selection and removing an empty layer use existing selected-set/structural-owner normalization and finalization rather than rebuilding the entire document. TextEdit uses the existing target-local layout preparation and projects its accepted after once before resolution; neither its exact transaction nor anchor/layout work is repeated after acceptance. consume/discard do not hide preparation work or a rollback replay. No universal constant-time guarantee is claimed for copying a large stroke, normalizing selection, or changing an existing structural owner; existing owner cost remains explicit. IDs are merely observed during Draw preparation and admitted only by successful installation.
- Open: Local immutable collection representation and owner-level instrumentation, preserving the existing preparation bound rather than imposing arbitrary numerical thresholds.
- Basis: R-003, R-006, R-014, R-016, R-021, E-007, E-015, E-020, E-027, E-033, E-038, E-042, E-043, E-046
- Form: F-001
- Realizes: none
- Depends on: D-002, D-003, D-005, D-007, D-008
- Contract targets: `state_data`, `policy`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: Generalization must retain the sparse mechanism's useful property: cost follows the affected operation and owning structures instead of total unrelated document size or discarded reconstruction.

### D-012 — TextEdit request lifetime and session completion
- Concerns: `state_data`, `temporal`, `policy`, `compatibility`
- Lock: Existing commitTextEdit remains the sole semantic text-commit entry for direct request callers and session.commit; retain current input validation and request identity/epoch/generation/element-revision qualification, with unrelated document revision changes still permitted. Unknown or consumed requests return false without effects; known stale/invalid targets keep their existing private consumption and matching-session cleanup. Equal text returns true and consumes/closes the matching request/session as today, without resolver, document change, or action. For valid changed text, prepare the complete candidate and D-002 snapshots once before the common resolver; TextEdit accepts CanvasCommitAccept or Cancel and has no adjustable-result variant. Cancel, resolver failure, or an unapplied acceptance leaves the valid request and matching live editor draft available for retry, returning false for contained cancellation while preparation/input exceptions retain their existing error channel. D-004 alone governs returned-lease settlement, including incompatible resolutions. On application, consume the request and silently clear only its matching active session, paint suppression, and owned candidate state; record the applicable interaction revision before frame/state capture. Use the existing silent-notifier and matching-cleanup mechanisms rather than clearing unrelated session candidates. Common guarded delivery publishes state, settles the lease, emits one existing editText action and the observer, then releases its guard. Only afterward notify the already-cleared active-session value, before the command returns true. This notification may read session getters and start a separate public mutation, but cannot interleave one before the outer lease/action completes. Contain recoverable notification/error-reporting failures without changing the applied result; do not retry lease delivery. A direct commit without a matching active session emits no close notification or extra interaction revision. Preserve session identity checks so the wrapper cannot close a new session started by that late notification. This changes only changed-text close-notification order; no-op/stale dismissal, text UI, live draft updates, layout/anchor rules, and other operations remain unchanged. Hosts reverse/replay text through existing CanvasTextElementUpdate fields, including nullable clears, preserving identity and placement while revisions advance normally; optional selection restoration still composes through D-007.
- Open: Private projection plumbing, exact placement of the existing matching-cleanup silent-notification option, and cohesive runtime helper organization. No new public text editor, measured-size fields, transaction lifecycle, history owner, or text-specific resolver is introduced.
- Basis: R-003, R-005, R-006, R-008, R-009, R-010, R-018, R-020, R-021, E-036, E-038, E-039, E-040, E-041, E-044, E-045, E-047, E-048
- Form: F-001
- Realizes: M-008
- Depends on: D-001, D-002, D-003, D-004, D-007
- Contract targets: `state_data`, `temporal`, `policy`, `compatibility`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: The existing text command and field-update API already own the required edit. Exact before/after projection adds confirmation data; moving its session-close callback after complete delivery preserves listener reads and separate mutations without allowing them to dispose or change the runtime while the outer lease is still unsettled.

## Impact Register

### I-001 — Unified public protocol and restoration contract
- Action: update
- Surface: `lib/src/contracts/public/canvas_runtime.dart`, `lib/src/contracts/public/canvas_actions.dart`, `lib/src/contracts/public/canvas_deletion.dart`, `lib/iwb_canvas_engine.dart`, `docs/contracts/public_api_v1.md`, and `docs/_registry/public_api_v1.yaml`.
- Required by: D-001, D-002, D-006, D-007, D-008, D-009, D-012
- Resulting authority: D-001, D-002, D-006, D-007, D-008, D-009, D-012
- Contract requirement: Replace the old confirmation surface and migrate its current package consumers together under D-009; document all seven request variants, matching resolutions, lease lifetime, route scope, final Move delta, and the two CanvasEdit capabilities. Include complete TextEdit before/after values and existing field-update Undo/Redo with normally advancing revisions; preserve the existing length-only editText action and migrate changed-session close notification to D-012. Record the intentional source break and host migration in the existing public contract; preserve serialized schema and unrelated deletion policy/read APIs. Do not create a parallel protocol document or compatibility inventory.

### I-002 — Existing implementation owners and atomic preparation contract
- Action: update
- Surface: `lib/src/runtime/`, `lib/src/edit/`, `lib/src/store/`, `lib/src/selection/`, `lib/src/interaction/`, `lib/src/frame/`, their declaration-only seams in `lib/src/contracts/internal/`, `docs/contracts/edit_kernel.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/frame_rendering.md`, `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, and `docs/architecture/03_data_model.md`.
- Required by: D-001, D-003, D-004, D-005, D-007, D-008, D-011, D-012
- Resulting authority: D-001, D-003, D-004, D-005, D-007, D-008, D-011, D-012
- Contract requirement: Generalize the existing prepared apply path, retain runtime-local confirmation, add staged restoration in existing edit owners, and align the named contracts with the irreversible install boundary and Move basis lifetime. Carry TextEdit through the same prepared owner with a private affected-element after projection, preserving existing layout/anchor rules. Update text request/session lifecycle and callback order under D-012, including retry after non-application and silent matching cleanup before publication. Align active Move preview participant capture with D-005 while preserving ordinary frame capture and selection-decoration rules. Update only affected seams; do not add history storage, duplicated state owners, or a transaction-management subsystem. Retire superseded deletion-only internal confirmation paths after their consumers migrate.

### I-003 — Operation coverage and service-edit exemption
- Action: update
- Surface: `docs/contracts/operation_matrix.md`.
- Required by: D-001, D-004, D-006, D-007, D-008, D-009, D-012
- Resulting authority: D-001, D-004, D-006, D-007, D-008, D-009, D-012
- Contract requirement: Represent all admitted gesture and command routes, cancellation/final-zero behavior, and restoration edits with their exact resolver/action exemption. Include direct commitTextEdit and session.commit, equal-text/stale rejection without resolution, valid request/draft retention after cancellation, and the post-delivery close notification. Preserve current eligibility and unrelated operation rows; do not infer user operation type from low-level mutations.

### I-004 — Bounded confirmation failure diagnostics
- Action: update
- Surface: `docs/contracts/diagnostics.md` and existing diagnostics declarations/recording in `lib/src/diagnostics/` and `lib/src/runtime/`.
- Required by: D-004
- Resulting authority: D-004
- Contract requirement: Replace deletion-only callback failure descriptions with unified resolver/lease failure semantics under D-004, retaining disabled-mode behavior and redaction. Do not add a sink, telemetry system, or request-payload logging.

### I-005 — Architecture graph and generated views
- Action: update
- Surface: `docs/architecture/architecture_graph.yaml`, `docs/diagrams/generated/full_architecture.mmd`, and `docs/diagrams/generated/actual_vs_expected_diff.mmd`.
- Required by: D-001, D-003, D-005, D-009, D-010
- Resulting authority: D-001, D-003, D-005, D-009, D-010
- Contract requirement: Reconcile changed prepared/callback/interaction-frame seams with existing graph owners and regenerate dependent graph views through the owning mechanism. Keep the shared declaration layer below implementation owners and private prepared capabilities outside the public facade; do not add a second boundary scanner.

### I-006 — Existing behavioral diagrams
- Action: update
- Surface: `docs/diagrams/seq_edit_success.mmd`, `docs/diagrams/seq_edit_rollback.mmd`, `docs/diagrams/seq_eraser_commit.mmd`, `docs/diagrams/seq_eraser_exact_budget.mmd`, `docs/diagrams/seq_line_two_tap_commit.mmd`, `docs/diagrams/seq_pencil_marker_commit.mmd`, `docs/diagrams/seq_selected_move_preview_commit.mmd`, `docs/diagrams/seq_selected_move_cancel.mmd`, `docs/diagrams/seq_dispose_during_gesture.mmd`, `docs/diagrams/state_edit_session.mmd`, `docs/diagrams/state_selected_move.mmd`, `docs/diagrams/state_pointer_session.mmd`, `docs/diagrams/state_eraser.mmd`, `docs/diagrams/state_pencil_marker_draw.mmd`, `docs/diagrams/state_two_tap_line.mmd`, `docs/diagrams/dfd_cache_invalidation.mmd`, `docs/diagrams/dfd_pointer_preview_commit.mmd`, `docs/diagrams/dfd_public_edit.mmd`, `docs/diagrams/seq_main_paint.mmd`, `docs/diagrams/dfd_main_paint_frame.mmd`, `docs/diagrams/c4_code_edit_kernel.mmd`, `docs/diagrams/seq_context_action_request.mmd`, and `docs/diagrams/state_pending_context_action_request.mmd`.
- Required by: D-001, D-003, D-004, D-005, D-006, D-007, D-008, D-009, D-012
- Resulting authority: D-001, D-003, D-004, D-005, D-006, D-007, D-008, D-009, D-012
- Contract requirement: Replace affected immediate/deletion-only/old-Move narratives with the selected preparation, guarded confirmation, cleanup, state/lease/action ordering, and conflict behavior, including the captured participant source for active Move preview without changing selection decoration or ordinary frame capture. Reconcile explicit selection restoration during edit replacement with D-007 while preserving the separate loadDocument behavior. In the existing context-action/text diagrams, add TextEdit resolution and cancellation/retry and replace immediate application/early session-close notification with D-012; keep unrelated context-action issuance and load behavior unchanged. Preserve each diagram's existing explanatory purpose; do not create a diagram per request type or restate the same protocol in new files.

### I-007 — Owning behavioral and public-surface verification
- Action: update
- Surface: Existing owning coverage under `test/api/`, `test/api_contract/`, `test/diagnostics/`, `test/runtime/`, `test/interaction/`, `test/edit/`, `test/store/`, `test/frame/`, `test/surface/`, and `test/smoke/`; `docs/verification/tests.md`; `docs/verification/release_gates.md`; `docs/_registry/sections.yaml`; and generated coverage blocks owned by `docs/tool/sync_generated_docs.dart`.
- Required by: D-002, D-003, D-004, D-005, D-006, D-007, D-008, D-009, D-010, D-011, D-012
- Resulting authority: D-002, D-003, D-004, D-005, D-006, D-007, D-008, D-009, D-010, D-011, D-012
- Contract requirement: Migrate affected existing consumers and adapt nearest-owner fixtures to the Assurance Register's independent failure families. Migrate the existing TextEdit session-order witness and retain real surface/overlay consumers; distinguish the current injected non-publishing preparation fixture from evidence of real Store failure atomicity. Admit each added durable family with its concrete invariant, owner, failing witness, and lasting value; reuse existing fixtures when sufficient. Update the affected release-gate rules from deletion-only to the unified required resolver, and update coverage mappings and their generated projections when owning coverage changes, without adding prose scanners, copied inventories, or private-layout locks.

## Assurance Register

### A-001 — Semantic route coverage and no-op silence
- Verifies: R-003, R-007, R-010, R-015, R-018, D-001/in_scope, D-001/out_of_scope, R-021, D-012/policy
- Claim: Every admitted changing gesture or command reaches one resolver with the correct request family; excluded and no-op routes do not acquire confirmation or additional actions.
- Failure: A command bypasses confirmation, a gesture resolves twice, a valid dot/line is misclassified as no-op, or history replay confirms itself.
- Oracle: Drive actual public gesture/command/edit entries and observe resolver calls, request type, final document, and action count for accepted, cancelled, ineligible, and unchanged inputs. Observe direct removal's boolean alongside actual application, including its existing background eligibility. For TextEdit, observe direct commitTextEdit and session.commit: changed text resolves once, equal text returns true without document mutation/resolution/action, and invalid or stale requests do not resolve.
- Proxy risk: Calling a shared resolver helper directly does not prove that every public route reaches it.
- Evidence constraints: Exercise pencil, marker, both line completion modes, deletion command/selection, terminal eraser, pointer/command Move, both rotations and flips, and TextEdit through both public entries; retain focused coverage for service edits and the named excluded routes, including text-session setup/live draft updates, without inventing new semantics for them.
- Architecture seam: Runtime semantic entry routes and public action delivery under D-001.

### A-002 — Preparation failure cannot partially install
- Verifies: R-006, R-020, D-003/owner, D-003/state_data, D-003/atomicity
- Claim: Before the irreversible install point, failure preserves committed document, revisions, ID admission, and commit-owned selection; successful installation makes the prepared document and selection visible together.
- Failure: A rejected preparation advances an ID/revision, or Store changes before a later selection check fails.
- Oracle: Compare actual committed owner facts before and after failures at each real pre-install boundary; on success, read document and selection from the first public observation and find both final values. Audit the install boundary to establish that validation and backing transfers precede its first committed assignment.
- Proxy risk: Document equality alone misses admitted IDs, revision changes, selection, or a fallible step after Store replacement.
- Evidence constraints: Cover generalized interaction preparation, including TextEdit before/after consistency on real pre-install failures, ordinary sparse restoration, and materialized/replacement restoration through their real owners. Use test-only failure injection before installation; never add a fallible production callback inside the install tail to manufacture a witness. A stubbed non-publishing TextEdit result proves caller behavior only, not Store atomicity.
- Architecture seam: Edit/Store/Selection preparation and installation under D-003.

### A-003 — Prepared ownership terminates once
- Verifies: R-020, D-003/state_data, D-010/negative_proof_fixture
- Claim: A prepared operation can install once or be discarded; neither terminal permits a later installation or reuse of transferred backing.
- Failure: Repeated consume changes revisions twice, or consume after discard installs abandoned state.
- Oracle: At the private owning boundary, exercise repeated and mixed terminal attempts and observe the actual Store/Selection/ID effects and terminal rejection, including release of unused preparation ownership.
- Proxy risk: Counting helper calls or testing a replacement fake package does not prove production lifetime enforcement.
- Evidence constraints: Exercise the real prepared capability with invalid terminal sequences confined to tests; assert effects and lifetime, not private state-field names.
- Architecture seam: The private single-use capability in D-003.

### A-004 — Applied commit settles before its action
- Verifies: R-005, D-004/temporal, D-004/order, D-012/temporal
- Claim: Applied state is published before the committed lease callback, and the operation action follows one attempted committed callback even when that callback throws; TextEdit closes its matching session silently before publication and notifies closure only after guarded lease/action/observer delivery.
- Failure: A lease observes old public state, a successful install reaches aborted, a terminal is retried, or a recoverable notification failure suppresses the lease/action.
- Oracle: Record observations from real state/frame subscribers, lease callbacks, action subscribers, and the existing observer. The applied document/selection must be final before committed, committed must be attempted once, aborted never, and the final action must follow. For a changed TextEdit session, the first state observation sees the final text and cleared session/suppression; the close listener observes completed outer lease/action delivery, can read session getters, and can start a separate mutation after guard release. A new session it starts survives the old wrapper return. A direct request without a matching session adds no closure notification or interaction revision. Repeat with throwing lease, notifier/error-reporting, and action callbacks at the applicable delivery boundaries, including a failing late TextEdit session listener/error reporter; it cannot change success or repeat settlement.
- Proxy risk: A standalone lease mock or ordinary listener failure does not cover a throwing frame bridge or error-reporting callback.
- Evidence constraints: Use recoverable synchronous callback failures in actual runtime delivery; distinguish attempted terminal delivery from host callback completion. Do not claim survival of process termination or execution-preventing exhaustion.
- Architecture seam: Runtime post-install delivery and guarded lease entry under D-004.

### A-005 — Non-application settles a returned lease
- Verifies: R-005, R-006, D-004/policy, D-004/temporal, D-012/state_data, D-012/policy
- Claim: Non-applied accepted requests abort their returned lease once and preserve committed state; valid unapplied TextEdit requests and matching drafts remain retryable.
- Failure: Cancellation mutates committed content or a mismatched acceptance leaks a lease.
- Oracle: Observe actual document/revision/selection/ID facts and action count after cancel, thrown resolver, incompatible resolution, and accepted preparation failure. Returned leases abort once and never commit; callbacks that return no lease have no terminal. For TextEdit, observe false on contained cancellation, the unchanged active draft, and a subsequent successful retry of the same valid request; real preparation failures preserve those facts while retaining their existing error channel.
- Proxy risk: Checking only a thrown error misses already-applied side effects or an unsettled returned lease.
- Evidence constraints: Include operation-owned preview/provisional-selection cleanup without treating it as committed mutation; ensure cleanup does not overwrite externally owned selection. Observe actual non-application exits, not test-only substitutes. Include actual TextEdit preparation failure where atomicity is claimed, not only the existing injected non-publishing result.
- Architecture seam: Runtime non-application exits under D-004.

### A-006 — Diagnostic containment and redaction
- Verifies: R-008, D-004/policy, I-004
- Claim: Confirmation failures produce only bounded permitted diagnostic facts and diagnostics cannot change operation finality.
- Failure: Diagnostics retain request/element/lease/error text, duplicate a guard failure, build disabled details, or interrupt terminal delivery.
- Oracle: Inspect emitted diagnostics for callback failures with deliberately sensitive request/reason/error contents, and observe unchanged lease/action outcomes; observe absence of detail construction when disabled and the owning guard's existing single diagnostic treatment.
- Proxy risk: Searching source for a logging call cannot establish emitted content or disabled behavior.
- Evidence constraints: Use the existing diagnostics boundary and its direct observations; synthetic sensitive values remain test data, including full TextEdit text and metadata. Confirm the existing editText action still carries lengths only, not before/after contents. Reuse existing containment seams instead of introducing a configurable sink.
- Architecture seam: Runtime safe error projection into the existing diagnostics owner under D-004.

### A-007 — Move conflict and preview membership
- Verifies: R-012, D-005/state_data, D-005/temporal
- Claim: A Move gesture retains its initial participants and cancels as a whole when one changes or external selection changes, while unrelated accepted edits and no-ops preserve it.
- Failure: Preview starts moving a newly eligible object, a partial group commits, an unrelated edit cancels the gesture, or the final Move overwrites an external participating edit.
- Oracle: During actual active gestures, apply participant transform/style/eligibility changes, removal/same-ID replacement, external selection changes, and unrelated edits. Observe session/preview cleanup before external publication, preserved external state, and no terminal resolver/action after conflict. For nonconflicting edits, observe unchanged participant membership and the final start-relative transform.
- Proxy risk: A terminal revision comparison alone misses same-ID replacement and incorrect intermediate preview membership.
- Evidence constraints: Include group and provisional-selection gestures, unchanged final edits, and an initially selected but nonparticipating object becoming movable. Observe frame output or its admitted records plus public state, not just stored participant IDs.
- Architecture seam: Interaction's captured basis, accepted-change notification, and frame capture under D-005.

### A-008 — Public facts support host-owned reversal
- Verifies: R-001, R-009, D-002/state_data, D-002/policy, R-021, D-012/state_data
- Claim: A host can retain immutable operation facts, record only applied operations, and undo/redo each admitted operation without a production whole-document snapshot.
- Failure: Deleted data or placement cannot be restored, retained request values change later, or cancelled/aborted operations enter history.
- Oracle: A host harness retains only the public request and its chosen final Move delta, records it through committed, then reverses/replays through public edits. Compare restored content, element identity/order, transforms, background placement, and chosen selection against independently captured test-only expectations; verify no replay resolver/action and no record from cancellation/abort.
- Proxy risk: Pushing/popping a document or request from a list proves neither reversal nor sufficiency of the public projection.
- Evidence constraints: Cover Draw, Delete, Erase, Move, Rotate, Reflect, and TextEdit, complete deleted element data, multiple element kinds, and retained immutable collections after later edits. TextEdit replay restores every mutable text/common field from before/after, including nullable-field clears, metadata, sizing inputs, and compensated transform, while preserving ID and structural placement. Use expected content equality with normally advancing revisions, not historical revision equality. Test-only full snapshots may serve as an oracle, never as the host harness's history input. Resource assets remain the host's responsibility and revisions are not rewound.
- Architecture seam: Public request/lease and existing edit capabilities under D-002, D-007, D-008, and D-012.

### A-009 — One final Move transform
- Verifies: R-004, R-007, D-006/policy
- Claim: The accepted Move delta is the full start-relative displacement, represented exactly by the final transform action, with no corrective application.
- Failure: The engine adds proposed and accepted deltas, commits twice, or installs/acts after zero or invalid final delta.
- Oracle: Accept a delta different from the proposal and observe final transforms and the action's translation tx/ty. Observe one document application and action for a valid change; zero, non-finite, overflowed, or unchanged final preparation produces no application/action and one aborted lease.
- Proxy risk: Reading the acceptance object alone does not prove the installed transform or action payload.
- Evidence constraints: Exercise both pointer and command Move with nontrivial initial transforms and a multi-element basis; assertions concern actual state and delivered action, not helper composition.
- Architecture seam: Final-delta validation and exact preparation under D-006.

### A-010 — Atomic desired selection restoration
- Verifies: R-011, D-007/state_data, D-007/atomicity
- Claim: Explicit selection in an edit is normalized against its final document and installed with it; absent intent preserves existing implicit behavior.
- Failure: Live selection changes during the callback, setter order changes the result, replacement erases explicit intent, or an observer sees restored content with stale selection.
- Oracle: Restore elements and stage desired IDs in either order, including repeated setters, sparse edits, draft promotion, replacement, failure, and selection-only/no-op outcomes. Observe the final normalized IDs, exact applicable revision changes, and the first published document/selection pair.
- Proxy risk: Calling the normal selection command after an edit produces the final pair but leaves an intermediate public state.
- Evidence constraints: Exercise existing public edit ownership, content/visibility/selectability normalization, and both explicit and absent intent. The independent loadDocument path retains its existing selection behavior.
- Architecture seam: Edit-staged intent and Selection preparation under D-007.

### A-011 — Safe empty-layer reversal
- Verifies: R-013, D-008/state_data, D-008/atomicity, D-008/policy
- Claim: A host can undo a first Draw back to a zero-layer document in the same restoration edit, without deleting pre-existing or nonempty layers as that Draw's side effect.
- Failure: An unremovable empty layer remains, unrelated contents disappear, or layer removal diverges after draft materialization.
- Oracle: Use createsLayer and placement from an actual Draw request to undo/redo content, its created layer, and chosen selection together. Observe exact final layer/content order, false/no-mutation removal for absent or nonempty layers, and identical semantics through sparse and materialized edits. A final remove/recreate equality is silent.
- Proxy risk: Removing a hand-constructed empty layer does not prove that Draw exposes usable provenance or that complete Undo composes atomically.
- Evidence constraints: Include an existing empty layer, zero-layer initial document, later content in the created layer, same-ID replay, and unrelated background/resources. Do not require the engine to infer host history provenance.
- Architecture seam: The existing structural edit owner and Draw projection under D-008.

### A-012 — Coherent public migration
- Verifies: R-002, R-017, D-009/compatibility, D-009/migration_retirement, D-010/recognition, I-001, D-012/compatibility
- Claim: Public consumers use the required unified sealed protocol and restoration methods; retired confirmation exports and internal prepared capabilities are unavailable, while retained policy/read/action/schema surfaces remain compatible.
- Failure: Old and new resolver APIs coexist, consumers require private imports, or replacing confirmation accidentally removes independently useful deletion policy or changes serialized data.
- Oracle: Inspect the analyzer-resolved root export namespace and actual public signatures with existing owning checks, and compile representative external consumers against public imports only. Observe migrated integration behavior and preserved serialized round trips through existing owning coverage. For TextEdit, exercise external session listeners and real overlay consumers against the documented later close notification, preserving session-getter reads and separate mutations after outer delivery while retaining the existing text UI and length-only action payload.
- Proxy risk: A hand-maintained expected-name list or successful internal compilation can hide leaked private types and broken external consumers.
- Evidence constraints: Consume the current registry as inventory authority; use real declarations and existing central public-surface machinery. Bounded recognition ends at the root export/signature boundary, not arbitrary source syntax or private helper layout.
- Architecture seam: The public facade and existing central API recognition under D-009 and D-010.

### A-013 — Single ownership and dependency direction
- Verifies: R-014, R-016, R-019, D-001/owner, D-001/source_of_truth, D-001/dependency, D-010/negative_proof_fixture, I-005
- Claim: Semantic confirmation remains runtime-owned over existing Edit/Store/Selection/Interaction owners, and test-only negative inputs do not become production authority.
- Failure: A second transaction/history owner appears, lower-level service edits infer semantic intent, implementation owners form a forbidden dependency, or fixtures dictate production values.
- Oracle: Trace real semantic and service entry paths to their owning state and callback boundaries; reconcile actual imports with the central architecture graph and generated views. Review fixture dependency direction and production value provenance at the changed boundaries.
- Proxy risk: Matching a diagram or counting classes cannot prove actual ownership; a new private implementation layout may be equally valid.
- Evidence constraints: Use current production paths, analyzer/import evidence, and existing graph checks. Review only the selected seams; do not introduce a general scanner or a second registry to certify the architecture.
- Architecture seam: Runtime composition and declaration-only internal boundaries under D-001 and D-010.

### A-014 — Affected-owner preparation cost
- Verifies: R-016, D-011/state_data, D-011/policy
- Claim: Confirmation retains existing sparse locality and immutable sharing rather than copying or scanning the unrelated document.
- Failure: A fixed-size operation materializes the document or traverses unrelated element rows for its request, conflict check, selection intent, or empty-layer removal.
- Oracle: With fixed affected facts and controlled owning structures, increase unrelated document rows and observe actual preparation/projection/row-read work through existing owner-level evidence. Account separately for affected geometry, selected sets, and structural-owner work allowed by R-016.
- Proxy risk: Wall-clock timing alone or a small fixture can conceal whole-document work; unchanged total time does not establish locality.
- Evidence constraints: Use direct existing counters/observations and targeted owner inspection, not arbitrary performance thresholds. Cover representative Draw, deletion/erase, transforms, TextEdit with fixed text/layout inputs, and the new sparse structural operation without demanding constant time for large affected inputs.
- Architecture seam: Sparse preparation and request projection under D-011.

### A-015 — Preparation is not duplicated or deferred into consume
- Verifies: R-003, R-020, R-021, D-003/atomicity, D-011/policy
- Claim: Non-Move exact preparation completes once before resolution; Move exact preparation occurs once after final acceptance, and consume/discard do not reconstruct or reverse the transaction.
- Failure: Confirmation prepares the same operation again, final Move applies a correction, or consume/discard hides validation, copying, or inverse work.
- Oracle: Observe the real preparation phase boundaries around resolver and terminal use, together with actual install effects. Non-Move requests must already correspond to the sealed candidate when the resolver runs; Move's one exact candidate must use the returned delta. For TextEdit, observe one exact preparation and its anchor/layout work before resolution; the accepted after comes from that candidate and acceptance does not repeat preparation or anchor computation. Audit terminal work at the owning boundary.
- Proxy risk: One public action can conceal two preparations or an internal corrective edit.
- Evidence constraints: Use existing owner-level phase observations plus boundary inspection; do not lock helper names, add a second production phase ledger, or insert callbacks into the install tail.
- Architecture seam: Prepared lifetime and runtime resolution sequence under D-003 and D-011.

### A-016 — Current authority and coverage reconciliation
- Verifies: R-019, I-001, I-002, I-003, I-004, I-005, I-006, I-007
- Claim: Current contracts, diagrams, registries, release gates, and coverage describe the implemented unified protocol and retain their existing authority roles.
- Failure: A current document still mandates an old resolver or contradicts lease/selection/preview semantics, generated output diverges from its owner, or new durable tests lack an admitted failure family.
- Oracle: Semantically compare each registered impacted surface with the implemented public/owner boundaries and direct behavioral evidence; verify generated projections through their existing owning checks. Inspect coverage admissions for the actual failure, owner, failing witness, and lasting value of each added family.
- Proxy risk: Passing documentation/link checks establishes structural consistency, not behavioral truth; copied prose or a passing fixture cannot authorize product semantics.
- Evidence constraints: Human/agent semantic reconciliation plus existing documentation, API, and graph verification are admissible. Do not create tests that parse prose or require a separate permanent artifact just to certify this review. Historical documents remain historical.
- Architecture seam: Existing current contract, registry, and generation ownership represented by I-001 through I-007.

### A-017 — Callback mutation and reentrancy exclusion
- Verifies: R-008, D-004/policy, D-004/temporal
- Claim: Resolver and lease callbacks allow public reads and host-local work but cannot mutate the runtime or enter a nested confirmation.
- Failure: A callback changes committed or interaction state reentrantly, generates an ID, disposes the runtime, or blocks permitted reads.
- Oracle: Attempt actual public mutation, ID generation, disposal, and nested confirmation inside resolver and both lease terminals; observe rejection and unchanged owning state, readable public facts, and allowed host-local changes. A resolver callback that catches the rejection may still return a valid acceptance without altering its normal terminal outcome.
- Proxy risk: A thrown exception alone does not prove that the attempted mutation had no effect, and testing only the resolver misses the lease inside delivery.
- Evidence constraints: Use actual runtime callback boundaries and existing owning fixtures, which may also cover A-005; no separate test file or production seam is required by the distinct assurance records.
- Architecture seam: Runtime private guarded-callback entry and public mutation guards under D-004.

### A-018 — Request context matches the actual proposal
- Verifies: R-002, R-003, D-002/state_data, D-002/policy, R-021, D-012/state_data
- Claim: The resolver receives accurate common context and operation-specific facts for the operation it is deciding.
- Failure: The request contains stale document context, the wrong selection snapshot or placement, incorrect eraser geometry, or transform/pivot data different from the prepared proposal.
- Oracle: Inside the real resolver, compare documentSummary/documentRevision and each operation's D-002 facts with independently captured initial facts and actual input. Include final Draw entry/layer provenance, canonical deletion order, eraser corridor/thickness, Move initial participant transforms/bounds and proposed delta, rotation/reflection pivot, operation, and world transform; and TextEdit before/after. TextEdit before equals the complete current committed target; after equals the eventual accepted element in every field, including revision and independently expected anchor-preserving transform. The proposal includes all unchanged fields and does not become a live reference after later edits. For Move with an unrelated intervening edit, document context is current while participant basis and prior selection retain their defined start meanings.
- Proxy risk: Correct request types, compilable signatures, or successful Undo can coexist with inaccurate context used by the host's approval policy.
- Evidence constraints: Exercise public operation routes using existing owning fixtures and immutable expected inputs across all seven variants; do not derive expected values by calling the projection being verified or add a production projection just for testing.
- Architecture seam: Runtime public request projection under D-002.

## Stop Conditions

### H-001 — A current authority contradicts the accepted behavior
- Trigger: Contract authoring or implementation finds a current owning rule or public consumer requirement incompatible with the selected operation scope, preserved eligibility, source-breaking migration, approved Move conflict/Undo behavior, or TextEdit request/session completion.
- Invalidates: D-001, D-005, D-007, D-008, D-009, D-012, A-001, A-012
- Resolution requires: Identify the exact conflicting authority and resolve it against the accepted requirements before implementation continues. A changed product decision requires the user's decision; do not silently narrow scope, add compatibility precedence, or reinterpret existing protection rules.

### H-002 — Prepared installation requires a different boundary
- Trigger: Concrete owning-code evidence shows that the selected routes cannot achieve D-003's install guarantee and D-011's existing work bounds through the generalized current preparation path, or require a fallible callback after the first committed mutation.
- Invalidates: D-003, D-004, D-011, A-002, A-004, A-014, A-015, I-002
- Resolution requires: Re-enter architecture with the exact failing boundary and minimum alternatives. Do not compensate with rollback after commitment, a second mutable document, hidden whole-document preparation, or aborting an already applied lease.

### H-003 — Public operation facts cannot support the approved restoration
- Trigger: An actual admitted operation has a persistent effect or restoration requirement that the selected public facts and existing edit capabilities plus D-007/D-008 cannot reconstruct without whole-document history or a new engine-owned history mechanism.
- Invalidates: D-002, D-007, D-008, D-012, A-008, A-011, A-018, I-001
- Resolution requires: Identify the missing effect and its existing owner, then resolve the smallest public-fact or capability correction before contract authoring proceeds. Do not add a generic diff protocol, asset store, or history subsystem by inference; any material scope change returns to the user.

## Contract Interface

- Profile: `BEHAVIOR_CHANGE`
- Obligations: `SEAM_MIGRATION`, `PUBLIC_API_CHANGE`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `NEGATIVE_PROOF_AND_FIXTURE_QUARANTINE`, `TEMPORAL_SURFACE_CLOSURE`, `ALL_OR_NOTHING_FAILURE_BOUNDARY`, `SOURCE_OF_TRUTH_SINGULARITY`, `WORK_BUDGET_CLOSURE`
- ADR Impact: none
- Sources: S-001, S-002, S-003, S-004, S-005, S-006, S-007, S-008, S-009, S-010, S-011, S-012, S-013, S-014, S-015, S-016, S-017, S-018, S-019, S-020, S-021, S-022, S-023, S-024, S-025, S-026, S-027, S-028, S-029, S-030, S-031, S-032, S-033, S-034, S-035, S-036, S-037, S-038, S-039, S-040, S-041, S-042, S-043
- Requirements: R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-008, R-009, R-010, R-011, R-012, R-013, R-014, R-015, R-016, R-017, R-018, R-019, R-020, R-021
- Commitments: D-001, D-002, D-003, D-004, D-005, D-006, D-007, D-008, D-009, D-010, D-011, D-012
- Assurance: A-001, A-002, A-003, A-004, A-005, A-006, A-007, A-008, A-009, A-010, A-011, A-012, A-013, A-014, A-015, A-016, A-017, A-018
- Impacts: I-001, I-002, I-003, I-004, I-005, I-006, I-007
- Stops: H-001, H-002, H-003

## Diagrams

None: D-001 and D-003 identify ownership and the irreversible boundary; D-004 specifies success and failure ordering, D-005 specifies Move capture and cancellation, and D-012 specifies TextEdit session completion. These locks answer the material questions without a second design representation. I-005 and I-006 own the required later updates to existing explanatory diagrams.

## Readiness Matrix

### Architecture Closure

| Concern | Status | Support refs |
| --- | --- | --- |
| owner | closed | D-001, D-003 |
| in_scope | closed | D-001 |
| out_of_scope | closed | D-001 |
| source_of_truth | closed | D-001 |
| compatibility | closed | D-009, D-012 |
| order | closed | D-004 |
| policy | closed | D-002, D-004, D-006, D-008, D-011, D-012 |
| dependency | closed | D-001 |
| state_data | closed | D-002, D-003, D-005, D-007, D-008, D-011, D-012 |
| migration_retirement | closed | D-009 |
| temporal | closed | D-004, D-005, D-012 |
| atomicity | closed | D-003, D-007, D-008 |
| negative_proof_fixture | closed | D-010 |
| recognition | closed | D-010 |

### Gate Closure

| Gate | Status | Support refs |
| --- | --- | --- |
| Owner-Level Fix | pass | D-001, D-003, A-002, A-013, E-005, E-006 |
| Ownership | pass | D-001, D-003, A-002, A-013 |
| Source-Of-Truth Singularity | pass | D-001, A-013 |
| Source-Truth Minimality | pass | D-001, D-011, A-013, A-014, M-006 |
| Boundary-Owned Policy | pass | A-001, A-008, D-002, D-004, D-006, D-008, D-011, A-005, A-006, A-009, A-011, A-014, A-015, A-017, A-018, D-012 |
| Dependency Direction | pass | D-001, A-013 |
| Solution Proportionality | pass | F-001, F-002, M-001, M-002, M-003, M-004, M-005, M-006, M-007, M-008, R-003, E-005, E-006, E-020, R-005, E-011, E-012, E-021, R-010, E-009, E-010, R-011, E-008, E-017, R-013, E-015, E-016, R-020, E-007, R-021, E-036, E-039 |
| Outcome-Proof Fit | pass | A-008 |
| Verification | pass | A-001, A-002, A-003, A-004, A-005, A-006, A-007, A-008, A-009, A-010, A-011, A-012, A-013, A-014, A-015, A-016, A-017, A-018 |
| Future Pressure | pass | P-001 |
| Handoff Consumability | pass | CONTRACT, H-001, H-002, H-003 |
| Negative Proof And Fixture Quarantine | pass | D-010, A-003, A-013 |
| State/Data Ownership | pass | A-005, D-002, D-003, D-005, D-007, D-008, D-011, A-002, A-003, A-007, A-008, A-010, A-011, A-014, A-018, D-012 |
| Sequenced Migration And Retirement | pass | D-009, A-012 |
| Temporal Surface Closure | pass | D-004, D-005, A-004, A-005, A-007, A-017, D-012 |
| All-Or-Nothing Failure Boundary | pass | D-003, D-007, D-008, A-002, A-010, A-011, A-015 |
| Bounded Recognition Scope | pass | D-010, A-012 |

## Open Blockers

None
