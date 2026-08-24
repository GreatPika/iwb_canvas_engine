---
schema: architecture-design/v4
date: 2026-08-24
commit: 231bab0e86e89d631f2df794eee860cdeedbd89f
branch: main
disposition: READY_FOR_CONTRACT
outcome: R-001
---

# Design: Deletion Commit Interception and Policies

## Basis

### Sources

| ID | Kind | Locator | Use |
| --- | --- | --- | --- |
| S-001 | research | `docs/history/research/2026-08-24-deletion-eraser-and-selection-policies.md` | Historical mapping of deletion, eraser, selection, store, and action paths |
| S-002 | user | user request | Original specification, five added guarantees, and accepted Q1-Q23 decisions whose exact mandatory meaning is normalized in R-002 through R-014 |
| S-003 | repository | `lib/src/contracts/public/canvas_runtime.dart` | Current public configuration, runtime state, and selection-port authority |
| S-004 | repository | `lib/src/contracts/public/canvas_element.dart` | Current public element-kind and element authority |
| S-005 | repository | `lib/src/runtime/runtime_command_facts_adapter.dart` | Current selection command-facts owner and ordering route |
| S-006 | repository | `lib/src/runtime/runtime_interaction_read_adapter.dart` | Current eraser candidate, budget, exact-hit, and ordering route |
| S-007 | repository | `lib/src/runtime/runtime_root.dart` | Current deletion delivery, resolver guard, cleanup, and action-delivery coordination |
| S-008 | repository | `lib/src/edit/edit_kernel.dart` | Current sparse interaction-commit lifecycle boundary |
| S-009 | repository | `lib/src/edit/commit_applier.dart` | Current document-then-selection application owner |
| S-010 | repository | `lib/src/store/document_store_kernel.dart` | Current committed document facts, preparation, validation, and installation owner |
| S-011 | repository | `lib/src/store/element_registry.dart` | Current canonical document-order token authority |
| S-012 | repository | `lib/src/selection/selection_kernel.dart` | Current selection state and installation owner |
| S-013 | repository | `lib/src/contracts/internal/prepared_selection_effect.dart` | Current prepared-selection value boundary |
| S-014 | repository | `lib/src/geometry/hit_test_policy.dart` | Current eraser eligibility and kind-routing authority |
| S-015 | repository | `docs/contracts/public_api_v1.md` | Current documented public selection contract |
| S-016 | repository | `docs/contracts/operation_matrix.md` | Current operation effects, revision, cleanup, and action matrix |
| S-017 | repository | `docs/diagrams/seq_eraser_commit.mmd` | Current eraser commit sequence authority |
| S-018 | repository | `lib/src/runtime/runtime_config.dart` | Current public-to-runtime configuration propagation owner |
| S-019 | repository | `lib/src/contracts/public/canvas_actions.dart` | Current public resolver, request DTO, delete payload, and erase payload conventions |
| S-020 | repository | `lib/src/runtime/runtime_action_finalizer.dart` | Current delete and erase action-finalization owner |
| S-021 | repository | `docs/contracts/diagnostics.md` | Current diagnostic writer admission and bounded-details authority |
| S-022 | repository | `lib/src/diagnostics/diagnostic_code.dart` | Current internal interaction diagnostic code authority |
| S-023 | repository | `lib/src/runtime/runtime_interaction_diagnostics_adapter.dart` | Current runtime interaction diagnostic routing owner |
| S-024 | repository | `docs/architecture/03_data_model.md` | Current CommitApplier prepared-state and install-failure lifetime authority |
| S-025 | repository | `docs/contracts/geometry.md` | Current eraser eligibility and candidate/exact-budget contract |
| S-026 | repository | `docs/diagrams/seq_eraser_exact_budget.mmd` | Current eraser candidate, exact-budget, and direct-commit sequence |
| S-027 | repository | `docs/diagrams/state_eraser.mmd` | Current eraser preview, terminal, commit, cleanup, and publication lifecycle |
| S-028 | repository | `docs/_registry/public_api_v1.yaml` | Current machine-readable public export inventory |
| S-029 | repository | `docs/contracts/edit_kernel.md` | Current CommitApplier, prepared selection, Store installation, and delivery authority |
| S-030 | repository | `docs/contracts/interaction_engine.md` | Current pointer cleanup ownership and runtime delivery ordering authority |
| S-031 | repository | `docs/architecture/architecture_graph.yaml` | Current runtime, Store, Selection, EditKernel, interaction, diagnostics, and public dependency authority |
| S-032 | repository | `architecture/decisions/README.md` | ADR consultation and lifecycle-impact policy |
| S-033 | repository | `architecture/decisions/ADR-0017-store-transaction-candidate-and-derived-facts.md` | Applicable retained Store candidate, CommitApplier, and RuntimeRoot boundary rationale |
| S-034 | repository | `docs/verification/release_gates.md` | Current public API, architecture, and ownership release admission authority |
| S-035 | repository | `test/api_contract/public_api_v1_compiles_as_written_test.dart` | Current direct external `CanvasSelectionPort` consumer compile fixture |
| S-036 | repository | `lib/src/api/canvas_runtime.dart` | Current public runtime facade and lifecycle delegation |
| S-037 | repository | `architecture/decisions/ADR-0001-single-maintained-acyclic-runtime.md` | Applicable retained contracts-led single-runtime and dependency-direction rationale |
| S-038 | repository | `architecture/decisions/ADR-0002-separate-committed-runtime-and-projection-state.md` | Applicable retained Store/projection/selection ownership rationale |
| S-039 | repository | `architecture/decisions/ADR-0003-store-finalized-edit-transactions.md` | Applicable retained Store-finalized edit and action-notification rationale |
| S-040 | repository | `architecture/decisions/ADR-0008-selection-move-and-chrome-ownership.md` | Applicable retained selection, interaction, and edit ownership rationale |
| S-041 | repository | `architecture/decisions/ADR-0009-interaction-tool-machines-and-cleanup.md` | Applicable retained tool-machine and centralized cleanup rationale |
| S-042 | repository | `architecture/decisions/ADR-0012-internal-diagnostics-routing.md` | Applicable retained internal sanitized diagnostics rationale |
| S-043 | repository | `architecture/decisions/ADR-0013-documentation-graph-and-proof-ownership.md` | Applicable retained semantic-doc, graph, generated-view, and external-proof rationale |
| S-044 | repository | `docs/architecture/00_architecture_overview.md` | Current single maintained runtime and public-boundary authority |
| S-045 | repository | `docs/architecture/02_package_boundaries.md` | Current contracts-led package placement and dependency authority |
| S-046 | repository | `docs/README.md` | Current documentation source-class and verification-route authority |
| S-047 | repository | `docs/architecture/README.md` | Current architecture owner/read-path authority |
| S-048 | repository | `docs/_registry/sections.yaml` | Current structured section relationship authority |
| S-049 | repository | `docs/_registry/diagrams.yaml` | Current semantic/generated diagram registration authority |
| S-050 | repository | `lib/src/contracts/internal/command_facts_port.dart` | Current selection-delete command-facts contract and consumer seam |
| S-051 | repository | `docs/architecture/01_runtime_ownership.md` | Current RuntimeRoot composition, state-publication, Store, Selection, EditKernel, InteractionEngine, and DiagnosticsHub ownership authority |

### Source Coverage

| Kind | Sources or none |
| --- | --- |
| prior_design | none |
| research | S-001 |
| plan | none |
| user | S-002 |
| repository | S-003, S-004, S-005, S-006, S-007, S-008, S-009, S-010, S-011, S-012, S-013, S-014, S-015, S-016, S-017, S-018, S-019, S-020, S-021, S-022, S-023, S-024, S-025, S-026, S-027, S-028, S-029, S-030, S-031, S-032, S-033, S-034, S-035, S-036, S-037, S-038, S-039, S-040, S-041, S-042, S-043, S-044, S-045, S-046, S-047, S-048, S-049, S-050, S-051 |
| other | none |

### Evidence

| ID | Source | Locator | Observed fact |
| --- | --- | --- | --- |
| E-001 | S-001 | `lines 13-17` | Selection deletion and terminal eraser deletion use separate runtime routes into sparse interaction commits; public configuration has no deletion callback or eraser-kind policy, and selection deletion currently removes only its deletable subset. |
| E-002 | S-003 | `lines 22-36` | `CanvasRuntimeConfig` is const and currently owns immutable creation-time policies plus an optional synchronous move resolver; no deletion fields exist. |
| E-003 | S-003 | `lines 201-212` | `CanvasSelectionPort` currently exposes selected IDs and `deleteSelection`, but no delete-availability value. |
| E-004 | S-005 | `lines 60-71` | Selection delete facts walk document-ordered handles and retain selected elements whose facts resolve and satisfy the deletion predicate. |
| E-005 | S-006 | `lines 325-390` | Eraser reads resolve spatial candidates, apply candidate and exact budgets before exact hits, and then request document ordering for the erased subset. |
| E-006 | S-007 | `lines 935-955` | `deleteSelection` prepares its deletable removals and delete action intent in one interaction commit. |
| E-007 | S-007 | `lines 1563-1601` | The resolver guard is synchronous, rejects nested resolver calls, and rejects public runtime mutation while a resolver callback is active. |
| E-008 | S-008 | `lines 113-143` | `prepareInteractionCommit` currently prepares and installs in one call, so it exposes no callback window between complete preparation and installation. |
| E-009 | S-009 | `lines 177-203` | `CommitApplier` already prepares one apply state, then owns document-before-selection installation and delivery-result construction. |
| E-010 | S-010 | `lines 512-519` | The prepared materialized store installer performs a base-identity check that can throw during installation. |
| E-011 | S-012 | `lines 75-87` | Selection installation allocates a new `LinkedHashSet` before mutating selection and incrementing its revision. |
| E-012 | S-010 | `lines 229-258` | The committed store provides direct element, location, and per-layer order reads without materializing `CanvasDocument`. |
| E-013 | S-011 | `lines 1034-1084` | Global order tokens are dense and assigned in background order followed by document layer order and each layer's element order. |
| E-014 | S-010 | `lines 1096-1127` | Element removal changes element membership, placement, and resource reference facts without removing a resource descriptor. |
| E-015 | S-004 | `lines 11-18` | Current code has seven element kinds, including `vector`, while the historical research recorded six; current repository authority therefore supersedes that stale enumeration. |
| E-016 | S-006 | `lines 599-608` | The current shared ordering helper scans every supplied document handle to retain a target ID subset in canonical order. |
| E-017 | S-007 | `lines 2721-2783` | Terminal eraser prepares removals and an erase action intent, clears preview before public delivery, and retries cleanup on preparation or delivery failure. |
| E-018 | S-010 | `lines 832-838` | The sparse store installer performs a revision check that can throw during installation. |
| E-019 | S-010 | `lines 317-334` | The committed store provides a direct ID-to-global-order-token lookup for a structural revision. |
| E-020 | S-010 | `lines 1143-1169` | Resource descriptor removal is a separate explicit operation that succeeds only for an unreferenced resource. |
| E-021 | S-005 | `lines 134-137` | The current selection-delete predicate requires content location and `isDeletable` and does not consult `isLocked`. |
| E-022 | S-009 | `lines 228-269` | Current `_PreparedApplyState` already contains a prepared commit document, copied delivery effects, action intents, and a prepared selection effect before owner installation begins. |
| E-023 | S-013 | `lines 3-7` | `PreparedSelectionEffect` owns an immutable ID set before selection installation. |
| E-024 | S-014 | `lines 165-181` | Current exact eraser routing includes `vector` and every current public element kind. |
| E-025 | S-015 | `lines 1650-1686` | Current public documentation assigns selection commands to `CanvasSelectionPort`, limits deletion to selected `isDeletable` elements, and requires document order in selection actions. |
| E-026 | S-016 | `lines 61-84` | The current operation matrix records partial selection deletion, eraser selection pruning, cleanup revisions, and existing delete/erase action types. |
| E-027 | S-017 | `lines 150-173` | The current eraser sequence documents sequential irreversible document and selection installation followed by publish-false eraser cleanup before common delivery. |
| E-028 | S-018 | `lines 7-21` | `RuntimeConfig.from` is the current creation-time propagation owner for public runtime policy and resolver fields. |
| E-029 | S-019 | `lines 220-238` | The existing move resolver convention is a synchronous typedef whose request constructor takes an iterable and exposes an unmodifiable list. |
| E-030 | S-019 | `lines 86-94` | The current delete action payload exposes an unmodifiable removed-ID list. |
| E-031 | S-019 | `lines 144-156` | The current erase action payload exposes thickness, an unmodifiable erased-ID list, and corridor-point count. |
| E-032 | S-020 | `lines 44-73` | The action finalizer maps selection deletion to `deleteElements`, eraser to `erase`, and derives their existing payloads from action intents. |
| E-033 | S-021 | `lines 73-85` | Current diagnostics authority forbids an ordinary edit or commit failure record without a separately approved route and requires interaction diagnostics to contain bounded facts without runtime objects or document content. |
| E-034 | S-022 | `lines 51-59` | The internal interaction diagnostic code family currently includes resolver reentrant-mutation rejection but no deletion-resolver failure code. |
| E-035 | S-023 | `lines 91-98` | The runtime interaction diagnostics adapter currently routes resolver reentrant-mutation rejection with bounded operation details. |
| E-036 | S-015 | `lines 170-247` | Public API equality is explicit: request and element types currently use identity equality unless listed, while value-equality types must be named before implementation. |
| E-037 | S-024 | `lines 125-137` | Current data-model authority permits selection-install failure after successful Store install and records that failure as retaining the accepted document and revisions; deletion callback routes therefore require an explicit narrower prepared-install lifetime. |
| E-038 | S-025 | `lines 161-187` | Current eraser contract admits all deletable content kinds and applies fixed candidate/exact budgets without a client kind filter. |
| E-039 | S-026 | `lines 26-124` | Current eraser budget sequence counts returned candidates before exact checks and sends a non-empty terminal set directly into EditKernel installation with no deletion resolver branch. |
| E-040 | S-027 | `lines 47-120` | Current eraser state authority moves from final candidates directly to EditKernel commit and treats edit failure as cleanup-only; it has no pre-install resolver decision state. |
| E-041 | S-007 | `lines 1490-1501` | Runtime disposal already rejects execution while the resolver guard is active before any lifecycle cleanup or disposal effect. |
| E-042 | S-028 | `lines 1-35` | The registry is the machine-readable public export inventory while semantic signatures remain owned by the public API contract. |
| E-043 | S-029 | `lines 160-199` | Current CommitApplier prepares one immutable apply state before installation, Selection installs prepared IDs, and RuntimeRoot owns route cleanup and delivery after apply. |
| E-044 | S-030 | `lines 253-277` | InteractionEngine owns terminal pointer cleanup outcomes, including resolver cancel/error, while RuntimeRoot performs cleanup before common delivery; the cleanup owner does not own resolver or commit work. |
| E-045 | S-031 | `lines 400-738` | The architecture graph currently records CanvasRuntime-to-RuntimeRoot delegation, RuntimeRoot Store/Selection ownership, public delivery, interaction read adaptation, and eraser commit delegation through EditKernel. |
| E-046 | S-032 | `lines 75-102` | Every design must consult applicable accepted ADRs and declare one exact lifecycle impact; create, supersede, or retire transitions require explicit design authority. |
| E-047 | S-033 | `lines 24-109` | ADR-0017 retains one Store candidate/order authority plus current CommitApplier prepared-state and RuntimeRoot orchestration boundaries, with changing facts delegated to current contracts and code. |
| E-048 | S-034 | `lines 98-133` | Current release admission requires architecture closure, public export/type/signature checks, direct public consumer compilation, ownership tests, and resolver-boundary proof. |
| E-049 | S-035 | `lines 854-890` | The public API compile fixture contains a direct external implementation of `CanvasSelectionPort` that must adopt any direct interface extension. |
| E-050 | S-036 | `lines 27-55` | The public `CanvasRuntime.dispose` facade delegates synchronously to guarded `RuntimeRoot.dispose` before detaching bridges. |
| E-051 | S-037 | `lines 24-82` | ADR-0001 retains one contracts-led runtime, dependency-low public/internal declarations, public facade adaptation, and acyclic owner direction. |
| E-052 | S-038 | `lines 20-67` | ADR-0002 retains compact Store truth, no ordinary hot-path public projection, and selection state separate from committed document content. |
| E-053 | S-039 | `lines 20-82` | ADR-0003 retains Store-finalized accepted edits, fallible preparation before install, runtime-owned post-accept delivery, and actions as notifications rather than Undo truth. |
| E-054 | S-040 | `lines 20-78` | ADR-0008 retains SelectionKernel membership/revision ownership, interaction preview/cleanup ownership, and edit-boundary terminal mutation. |
| E-055 | S-041 | `lines 20-83` | ADR-0009 retains InteractionEngine tool composition, centralized cleanup, and edit-boundary mutation without cleanup owning resolver or publication. |
| E-056 | S-042 | `lines 20-82` | ADR-0012 retains one internal sanitized DiagnosticsHub route, disabled-record suppression, explicit route ownership, and no public diagnostics stream. |
| E-057 | S-043 | `lines 20-87` | ADR-0013 retains semantic Markdown, structured registry, generated projection, expected graph, and external-consumer proof as distinct authorities. |
| E-058 | S-044 | `lines 28-49` | Current architecture scope retains one package/runtime root and requires public, graph, generated-doc, and release proof closure. |
| E-059 | S-045 | `lines 32-90` | Current package authority places public/internal contracts below runtime, Store, Selection, and Edit implementation owners. |
| E-060 | S-046 | `lines 25-48` | Current documentation authority separates architecture, contracts, verification, registries, generated navigation, planning, and history and names their checks. |
| E-061 | S-047 | `lines 6-43` | The architecture read path requires overview, ownership, package, data-model, graph, and diagram owners and classifies generated navigation separately. |
| E-062 | S-048 | `lines 26-35` | The section registry owns the architecture-model relationship entry used by generated navigation. |
| E-063 | S-049 | `lines 414-430` | The diagram registry identifies the exact generated full-architecture and actual-versus-expected output files as projections of the architecture graph. |
| E-064 | S-050 | `lines 7-31` | `CommandFactsPort` currently owns `selectionDeleteFacts`, whose DTO exposes only an ordered deletable-ID list to runtime consumers. |
| E-065 | S-012 | `lines 29-72` | Public selection mutations normalize IDs through membership before storing them, so an unresolved selected ID requires an owner-level controlled-facts witness rather than a public-state setup. |
| E-066 | S-051 | `lines 49-73` | Runtime ownership is already split among Store, Selection, EditKernel, InteractionEngine, and DiagnosticsHub, while RuntimeRoot alone composes their facts into public state after accepted changes. |

### Requirements

| ID | Kind | Statement | Basis | Open shape |
| --- | --- | --- | --- | --- |
| R-001 | outcome | Clients can safely own deletion Undo by receiving and vetoing complete final selection-delete and eraser removals, while independently configuring eraser-kind and selection-delete policies and reading whole-selection delete availability. | S-002, E-001, E-003, E-005, E-006 | Private helper names, file decomposition, and internal token representation remain open. |
| R-002 | user_decision | The resolver runs once only for a non-empty final removal set; explicit cancel creates no diagnostic, while resolver exception has the same no-mutation outcome plus one dedicated bounded `interaction` error diagnostic that does not escape and is fully absorbed when diagnostics are disabled. Both outcomes preserve document and selection revisions and emit no committed action or timestamp. Terminal erase additionally completes its preview/session cleanup; selection delete leaves independent eraser interaction state unchanged. | S-002, E-006, E-007, E-017, E-033, E-034, E-035, E-044 | Diagnostic code identifier and private cleanup-reason identifier remain open. |
| R-003 | user_decision | The existing `CommitApplier` and Store/Selection owners gain only the minimal internal deferred-install seam needed by `deleteSelection` and terminal `erase`: before the resolver all normally fallible preparation is complete; after accept one private single-use token installs document then selection synchronously without a normal validation, stale, or copy failure. The existing resolver guard permits runtime reads and client-owned Undo mutation while rejecting every public runtime mutation/edit/tool command, runtime disposal, and nested resolver call during the callback. Callback return and prepared installation remain in one uninterrupted synchronous stack with no external callback or publication between them. No new coordinator, general transaction framework, public token, or rollback is permitted. | S-002, E-007, E-008, E-009, E-010, E-011, E-018, E-022, E-023, E-037, E-039, E-040, E-041, E-043, E-050 | Allocation-only copying whose only failure is VM-fatal and whether the guard flag remains set after callback return are open; private token and no-fail consumer identifiers remain open; unrelated commit paths remain unchanged. |
| R-004 | user_decision | `CanvasRuntimeConfig` keeps its const constructor and adds exactly `CanvasDeletionCommitResolver? deletionCommitResolver`, `Set<CanvasElementKind>? eraserElementKinds`, and `CanvasSelectionDeletePolicy selectionDeletePolicy = CanvasSelectionDeletePolicy.partial`; `RuntimeConfig.from` takes one runtime-owned unmodifiable copy of a supplied set. | S-002, E-002, E-015, E-028 | Private runtime-config field storage remains open. |
| R-005 | user_decision | Eraser kind admission treats null as unrestricted, empty as admitting no kinds, and a non-empty set as an exact allow-list; the same filter applies to preview and terminal reads before candidate-limit and exact-check accounting, independently of resolver presence. | S-002, E-005, E-015, E-024, E-038, E-039 | Local predicate and set-lookup mechanics remain open. |
| R-006 | user_decision | `CanvasSelectionPort.deleteAvailability` returns value-equal immutable `CanvasSelectionDeleteAvailability(hasSelection, allSelectedElementsDeletable)`, with both false for empty selection. Availability is not copied into `CanvasRuntimeState`; clients re-read it after document or selection revision changes, and `deleteSelection` re-reads the same canonical facts immediately before execution rather than trusting UI state. | S-002, E-003, E-004, E-021, E-025, E-036, E-064 | Private canonical-facts representation remains open. |
| R-007 | user_decision | `CanvasSelectionDeletePolicy.partial` remains the default and removes only the eligible subset; `allOrNone` removes the whole selection only when every selected ID resolves to content with `isDeletable == true`. Unresolved IDs fail closed, `isLocked` does not affect deletion eligibility, and the policy applies without a resolver. | S-002, E-004, E-021, E-025, E-064, E-065 | Local policy-switch placement remains open. |
| R-008 | user_decision | `CanvasDeletionCommitRequest` contains `CanvasDeletionOperation operation` and an unmodifiable-copy list of `CanvasDeletionEntry`; each entry contains the existing immutable `CanvasElement` reference, source `CanvasLayerId`, and original `elementIndex`. Entries are built before mutation in document-layer then in-layer order by a committed-store batch read using direct element/location/order-token facts. The complete selection-delete and terminal-eraser ordering routes retire or bypass their existing full-handle scans and perform no `CanvasDocument` materialization, persistent-index addition, or O(N) ordering pass. | S-002, E-004, E-012, E-013, E-016, E-019, E-029, E-036 | Internal batch-fact type and sorting algorithm remain open; each complete route is O(k log k) for arbitrary IDs and O(k) for canonical IDs. |
| R-009 | user_decision | When `deletionCommitResolver` is null, deletion retains the current one-phase installation path and constructs neither callback DTOs nor a deferred token; selection and eraser policies still apply. | S-002, E-002, E-006, E-008, E-028 | Shared private helper reuse remains open only when it removes duplication. |
| R-010 | user_decision | Accept consumes the prepared token and installs document plus selection without intermediate publication, then terminal erase guarantees its cleanup before state publication and unchanged delete/erase action delivery; selection delete does not change eraser interaction state. Post-install delivery failure cannot roll back deletion or reinterpret accept; preparation failure before the callback remains fail-fast, never invokes the resolver, and still guarantees terminal-eraser cleanup. VM-fatal conditions such as out-of-memory are outside this atomicity guarantee. | S-002, E-009, E-017, E-026, E-027, E-030, E-031, E-032, E-037, E-044 | Existing delivery helper and private cleanup-reason decomposition remain open. |
| R-011 | user_decision | Selection deletion and eraser removal do not implicitly remove empty layers or resource descriptors; the callback entry's element, layer ID, and source index are sufficient for client-owned Undo. | S-002, E-014, E-020 | Documentation placement for this guarantee remains open. |
| R-012 | user_decision | The new selection-port getter is an accepted source-breaking direct interface extension with a migration note in the public API contract and release treatment through the current release-gate owner; optional configuration defaults preserve current runtime behavior. No V2 port, capability cast, duplicate getter, or `CanvasRuntimeState` mirror may be introduced as a compatibility workaround. | S-002, E-002, E-003, E-025, E-042, E-048, E-049 | Release version identifier remains governed by the release process. |
| R-013 | user_decision | The public callback contract consists exactly of `CanvasSelectionDeletePolicy { partial, allOrNone }`, `CanvasDeletionOperation { deleteSelection, erase }`, `CanvasDeletionDecision { accept, cancel }`, `CanvasDeletionCommitResolver`, `CanvasDeletionCommitRequest`, `CanvasDeletionEntry`, and `CanvasSelectionDeleteAvailability`. The resolver accepts or cancels the whole prepared set only; request and entry use identity equality, availability uses value equality, and no extra metadata or resolution variants are added. | S-002, E-029, E-036 | Public declaration file placement and documentation ordering remain open. |
| R-014 | exclusion | Engine-owned Undo, interception of `CanvasCommandPort.removeElement`, `CanvasEdit.removeElement`, clear/import/resource operations, changed action payloads, changed locking or selection eligibility, non-eraser tools, new coordinators, generic transaction frameworks, public prepared tokens, rollback, and new persistent ordering indexes are out of scope. | S-002, E-026, E-030, E-031, E-032 | None; adding any excluded surface requires architecture re-entry. |
| R-015 | repository_rule | A deletion-resolver failure diagnostic requires an explicit new diagnostics routing row and internal interaction code with bounded operation and error-kind facts only; element content, runtime objects, resolver payloads, and public diagnostic streams remain forbidden. | S-021, S-022, S-023, E-033, E-034, E-035 | Exact bounded error-kind encoding remains open inside diagnostics authority. |

## Candidate Analysis

- Comparison: `single_viable`
- Result: `selected F-001`
- Result basis: F-001, M-001, M-002, M-003, M-004, M-005, M-006, M-007, M-008, M-009, M-010, M-011, M-012, M-013, M-014, M-015, R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-008, R-009, R-010, R-011, R-012, R-013, R-014, R-015, E-008, E-009, E-010, E-011, E-012, E-016, E-018, E-019, E-022, E-023, E-037, E-038, E-039, E-040, E-043, E-044, E-045, E-046, E-047, E-051, E-052, E-053, E-054, E-055, E-056, E-057, E-058, E-059, E-060, E-061, E-062, E-063, E-064, E-065

### Forms

| ID | Form | Hard constraints | Main trade-off | Basis |
| --- | --- | --- | --- | --- |
| F-001 | Extend the existing committed-store facts seam and the current `CommitApplier` prepared state with a narrow deletion batch projection and deletion-only deferred installation; keep runtime orchestration, Store and Selection ownership, resolver guarding, and the no-callback one-phase route in their current owners. | pass: resolver-before-prepare leaves expected failures after client Undo registration; resolver-after-install cannot veto mutation; a new coordinator, generic transaction layer, runtime-owned installer pair, or rollback path violates R-003 and R-014; closure or helper-name variations are incidental implementation shape rather than architecture forms. | Adds one private single-use installation lifecycle only to the two intercepted deletion routes while leaving allocation-only copy and post-callback guard-release mechanics open; in return it adds no coordinator, general transaction abstraction, rollback path, document materialization, persistent index, or O(N) deletion-order scan. | R-001, R-002, R-003, R-006, R-008, R-009, R-014, R-015, E-008, E-009, E-010, E-011, E-012, E-016, E-018, E-019, E-022, E-023, E-037, E-038, E-039, E-040, E-043, E-044, E-045, E-046, E-047, E-051, E-052, E-053, E-054, E-055, E-056, E-057, E-058, E-059, E-060, E-061, E-062, E-063, E-064, E-065, E-066 |

### Material-Obligation Delta

| ID | Material obligation | F-001 | Independent authority |
| --- | --- | --- | --- |
| M-001 | R-001 | yes | R-001 |
| M-002 | R-002 | yes | R-002 |
| M-003 | R-003 | yes | R-003 |
| M-004 | R-004 | yes | R-004 |
| M-005 | R-005 | yes | R-005 |
| M-006 | R-006 | yes | R-006 |
| M-007 | R-007 | yes | R-007 |
| M-008 | R-008 | yes | R-008 |
| M-009 | R-009 | yes | R-009 |
| M-010 | R-010 | yes | R-010 |
| M-011 | R-011 | yes | R-011 |
| M-012 | R-012 | yes | R-012 |
| M-013 | R-013 | yes | R-013 |
| M-014 | R-014 | yes | R-014 |
| M-015 | R-015 | yes | R-015 |

### Future Pressures

| ID | Pressure | Basis | Treatment | Closure refs | Accepted cost or risk |
| --- | --- | --- | --- | --- | --- |
| P-001 | New `CanvasElementKind` values may be added after this change. | R-004, R-005, E-015, E-024 | absorbed | D-002, D-003 | A null eraser allow-list continues to admit current and future kinds; clients choosing an explicit set accept allow-list maintenance. |
| P-002 | A client may later request interception for direct element removal, clear, import, resource operations, or non-eraser tools. | R-014, E-026, E-030, E-031, E-032 | rejected | D-007 | Those routes remain outside this contract; adding one requires architecture re-entry instead of broadening the deletion seam speculatively. |
| P-003 | A client may later request per-entry callback decisions or additional deletion metadata. | R-013, R-014, E-029, E-036 | rejected | D-002, D-007 | The callback remains a minimal whole-set veto with the three Undo facts; any broader public contract requires a new product decision and migration review. |

## Decision Register

### D-001 — Existing-owner deletion form
- Concerns: `form`, `owner`, `in_scope`, `dependency`
- Lock: RuntimeRoot coordinates only final `CanvasSelectionPort.deleteSelection` and terminal eraser removals through the existing resolver guard and existing EditKernel/CommitApplier, Store, and Selection owner boundaries. Inside the callback, runtime reads and client-owned Undo mutation remain permitted, while public runtime mutation/edit/tool commands, runtime disposal, and nested resolver calls are rejected without committed or lifecycle effects. Existing owners are extended narrowly rather than bypassed or replaced.
- Open: Private helper names, file decomposition, internal request projection, and the representation of private prepared state remain implementation choices inside those boundaries.
- Basis: R-001, R-003, R-014, E-006, E-007, E-008, E-009, E-022, E-041, E-045, E-047, E-050, E-051, E-053, E-054, E-055, E-059, E-066
- Form: F-001
- Realizes: M-001
- Depends on: none
- Contract targets: `classification`, `owner`, `scope`, `dependency`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: The existing owners already hold the relevant facts, preparation, install order, guard, and delivery lifecycle, so a local extension satisfies the outcome without a second coordinator or transaction architecture. It preserves the applicable accepted ADR ownership split: contracts remain dependency-low, Store and Selection retain their facts, EditKernel/CommitApplier retain accepted installation, InteractionEngine retains terminal cleanup, RuntimeRoot retains orchestration, and ADR-0017's one Store order authority remains unchanged. No accepted decision is created, superseded, or retired, so no ADR lifecycle transition is required.

### D-002 — Public configuration, DTOs, and compatibility
- Concerns: `compatibility`, `migration_retirement`, `state_data`
- Lock: The public surface adds exactly the three configured fields and seven public deletion policy/request/availability declarations in R-004 and R-013; configuration is immutable per runtime, the eraser set is copied once into runtime-owned unmodifiable state, deletion request entries are an unmodifiable copy of retainable immutable element references, and delete availability remains a value-equal derived port value rather than duplicated runtime state. Migration extends the existing port and configuration in place: declarations, runtime implementation, export inventory, owning contract, and consumer compile fixtures become consistent before release; external `CanvasSelectionPort` implementers add the getter when adopting that source-breaking release. No old public surface is retired, and no V2 port, capability cast, duplicate getter, or runtime-state mirror may coexist. Release admission requires the migration note, compatible defaults, exact public export/signature checks, and successful compilation of both the runtime implementation and a direct external port implementation.
- Open: Declaration file placement, documentation ordering, private runtime field storage, private availability-facts representation, and the release version chosen by the release process remain open.
- Basis: R-004, R-006, R-012, R-013, E-002, E-003, E-028, E-029, E-036, E-042, E-048, E-049, E-051, E-052, E-056, E-057
- Form: F-001
- Realizes: M-004, M-006, M-012, M-013
- Depends on: D-001
- Contract targets: `compatibility`, `migration_retirement`, `state_data`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: One creation-time configuration source and one derived selection-port value preserve compatibility defaults and avoid a second state lifecycle while exposing the exact client contract.

### D-003 — Canonical selection and eraser policy
- Concerns: `policy`, `source_of_truth`
- Lock: One canonical `CommandFactsPort` boundary backed by committed Store and Selection facts owns selection existence and deletion eligibility for both `deleteAvailability` and command execution; eligibility is resolvable content-layer membership plus `isDeletable == true`, unresolved IDs fail closed, and `isLocked` is irrelevant. `partial` and `allOrNone` apply independently of resolver presence. Eraser kind admission uses the immutable runtime set with null/empty/nonempty semantics and is applied identically to preview and terminal candidates before candidate and exact-check budgets. Element deletion does not imply layer or resource-descriptor deletion.
- Open: The internal facts DTO decomposition, local predicate, policy-switch, and set-membership helper shape remain open as long as both consumers use the same facts boundary.
- Basis: R-005, R-006, R-007, R-011, E-004, E-005, E-014, E-020, E-021, E-024, E-025, E-052, E-054, E-064, E-065
- Form: F-001
- Realizes: M-005, M-007, M-011
- Depends on: D-001, D-002
- Contract targets: `policy`, `source_of_truth`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: Policy at the committed-facts boundary gives availability and execution one truth, applies budget admission before work is spent, and leaves unrelated resource and layer lifecycles untouched.

### D-004 — Store-owned canonical deletion projection
- Concerns: `order`
- Lock: The committed Store resolves the final IDs against one committed snapshot into full element, source layer, original in-layer index, and canonical order facts before mutation. It uses direct element, location, and order-token reads; the source index is derived from element token minus first token in the layer, arbitrary IDs are sorted by order token, and already canonical IDs remain linear. Both complete public routes retire or bypass their current full-handle ordering walks; neither route may materialize `CanvasDocument`, add a persistent index, or scan all N document elements merely to order k removals.
- Open: The internal batch-fact type, detection of already canonical input, and concrete sorting implementation remain open within the O(k log k), or O(k) when already canonical, bound.
- Basis: R-008, E-012, E-013, E-016, E-019, E-052, E-057
- Form: F-001
- Realizes: M-008
- Depends on: D-003
- Contract targets: `order`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: Store already owns location and dense document-order tokens, so a batch projection removes the existing O(N) scan without duplicating order truth or adding an index lifecycle.

### D-005 — Resolver temporal and atomic boundary
- Concerns: `temporal`, `atomicity`
- Lock: With a configured resolver, final nonempty deletion facts, callback request, validated candidate document, normalized selection backing, revision/action inputs, and private single-use install state are complete before the callback. The existing synchronous resolver guard permits reads and client Undo mutation while rejecting public runtime mutation/edit/tool commands, runtime disposal, and nested resolver calls without committed or lifecycle effects during the callback. Accept then consumes the state once in the same uninterrupted synchronous stack and installs document then selection without intervening publication or any normal validation, stale, or copy failure. Terminal eraser cleanup is guaranteed before fallible external delivery, followed by current state and action delivery; selection delete leaves eraser interaction state unchanged. Cancel or callback exception discards prepared state with no document, selection, revision, timestamp, or action effect and performs terminal-eraser cleanup only for erase. Preparation failure occurs before callback and keeps current fail-fast semantics. With no resolver, the current one-phase install route remains and creates neither callback DTO nor deferred state. VM-fatal conditions remain outside the guarantee.
- Open: Private single-use state representation, no-fail consumer identifiers, allocation-only copy mechanics, guard release after callback return, cleanup-reason decomposition, and reuse of a private helper where it reduces duplication remain open.
- Basis: R-002, R-003, R-009, R-010, E-006, E-007, E-008, E-009, E-010, E-011, E-017, E-018, E-022, E-023, E-027, E-041, E-043, E-044, E-047, E-050, E-053, E-054, E-055
- Form: F-001
- Realizes: M-002, M-003, M-009, M-010
- Depends on: D-001, D-003, D-004
- Contract targets: `temporal`, `atomicity`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: The callback creates exactly one new failure boundary; local deferred installation closes it without changing unrelated commits or introducing rollback.

### D-006 — Resolver-exception diagnostics
- Concerns: `owner`
- Lock: Only an exception thrown by the deletion resolver routes through the existing runtime interaction diagnostics adapter to DiagnosticsHub as one dedicated internal `interaction` error code with bounded operation and error-kind facts. The diagnostic contains no elements, document content, request payload, runtime object, or public stream exposure; disabled diagnostics fully absorbs the exception, and explicit cancel or pre-callback preparation failure does not use this route.
- Open: The internal diagnostic-code identifier and bounded error-kind encoding remain open within the diagnostics authority.
- Basis: R-002, R-015, E-033, E-034, E-035, E-056
- Form: F-001
- Realizes: M-015
- Depends on: D-005
- Contract targets: `owner`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: Extending the admitted interaction route keeps diagnostic ownership and redaction centralized while distinguishing resolver failure from an intentional veto.

### D-007 — Explicit scope boundary
- Concerns: `out_of_scope`
- Lock: Engine-owned Undo, direct command/edit element removal, clear, import, resource operations, action-payload changes, locking or general selection-eligibility changes, non-eraser tools, new coordinators, generic transaction frameworks, public prepared tokens, rollback, persistent ordering indexes, V2/capability compatibility surfaces, duplicate availability getters, and runtime-state availability mirrors remain excluded.
- Open: None; any excluded surface or mechanism requires architecture re-entry.
- Basis: R-014, E-026, E-030, E-031, E-032
- Form: F-001
- Realizes: M-014
- Depends on: D-001
- Contract targets: `scope`, `acceptance`, `unit_family`
- Rationale: The boundary keeps the change proportional to the two requested deletion routes and prevents the callback requirement from becoming a general transaction redesign.

### D-008 — Invalid-selection negative-proof fixture
- Concerns: `negative_proof_fixture`
- Lock: The two invalid proof states are controlled Selection facts snapshots containing either a selected ID absent from the same committed Store snapshot or a selected ID that resolves there as a background/non-content element. They enter only through fixture-owned inputs to the real runtime command-facts adapter and production `CommandFactsPort` boundary. Separate direct oracles observe availability plus `partial` and `allOrNone` results for each state. Fixture-only values, invalid-state recognition, and construction helpers remain quarantined from production Selection APIs, production facts, and public contracts and own no deletion predicate, policy, location classification, or ID vocabulary.
- Open: Private test-fixture construction and test-file placement remain open within the quarantine boundary.
- Basis: R-007, E-021, E-025, E-064, E-065
- Form: F-001
- Realizes: none
- Depends on: D-003
- Contract targets: `negative_proof_fixture`, `acceptance`, `evidence`, `verification`, `unit_family`
- Rationale: Public selection normalization makes this failure family unreachable through valid public setup, so a narrow owner-level fixture is required to prove fail-closed behavior without adding an invalid production path or duplicating policy truth.

## Impact Register

### I-001 — Public deletion API and migration surface
- Action: update
- Surface: `lib/src/contracts/public/canvas_runtime.dart`; `lib/src/contracts/public/canvas_actions.dart`; `lib/src/runtime/runtime_config.dart`; `docs/contracts/public_api_v1.md`; `docs/_registry/public_api_v1.yaml`; `test/api_contract/public_api_v1_compiles_as_written_test.dart`; `docs/verification/release_gates.md`
- Required by: D-002
- Resulting authority: D-002
- Contract requirement: Update the public declaration owners, runtime-owned configuration copy, authoritative signatures and migration note, equality policy, no-retirement posture, direct external port compile consumer, exported-name inventory, and final public-API release gate for the exact configuration, resolver, request, entry, policy, decision, operation, and availability surfaces locked by D-002.

### I-002 — Deletion policy and commit lifecycle contracts
- Action: update
- Surface: `lib/src/runtime/runtime_root.dart`; `lib/src/contracts/internal/command_facts_port.dart`; `lib/src/runtime/runtime_command_facts_adapter.dart`; `lib/src/runtime/runtime_interaction_read_adapter.dart`; `lib/src/edit/edit_kernel.dart`; `lib/src/edit/commit_applier.dart`; `lib/src/store/document_store_kernel.dart`; `lib/src/selection/selection_kernel.dart`; `lib/src/contracts/internal/prepared_selection_effect.dart`; `docs/architecture/01_runtime_ownership.md`; `docs/architecture/03_data_model.md`; `docs/contracts/geometry.md`; `docs/contracts/operation_matrix.md`; `docs/contracts/edit_kernel.md`; `docs/contracts/interaction_engine.md`; `docs/diagrams/seq_eraser_commit.mmd`; `docs/diagrams/seq_eraser_exact_budget.mmd`; `docs/diagrams/state_eraser.mmd`
- Required by: D-001, D-002, D-003, D-004, D-005, D-006
- Resulting authority: D-001, D-002, D-003, D-004, D-005, D-006
- Contract requirement: Update RuntimeRoot's configuration, availability, callback, guard, install, cleanup, delivery, and diagnostic-initiation integration together with the exact internal command-facts, interaction-read, edit/apply, Store, Selection, and prepared-selection owners plus every maintained policy/lifecycle contract and semantic diagram. The resulting route must publish one canonical availability/execution facts boundary, filtered eraser-budget policy, Store-owned O(k log k)/O(k) deletion projection without `CanvasDocument` materialization, guarded callback prepare-veto-install boundary with exact cardinality, dedicated diagnostic handoff, cancel/error/no-callback effects, cleanup/publication/action order, and unchanged layer/resource semantics.

### I-003 — Deletion-resolver diagnostic route
- Action: update
- Surface: `lib/src/diagnostics/diagnostic_code.dart`; `lib/src/runtime/runtime_interaction_diagnostics_adapter.dart`; `docs/contracts/diagnostics.md`
- Required by: D-006
- Resulting authority: D-006
- Contract requirement: Extend the existing interaction-to-diagnostics authority with the dedicated deletion-resolver exception route, bounded operation/error-kind detail policy, disabled-diagnostics behavior, and explicit exclusions for cancel and pre-callback preparation failure without creating a public diagnostics surface.

### I-004 — Architecture graph and generated views
- Action: update
- Surface: `docs/architecture/architecture_graph.yaml`; `docs/diagrams/generated/full_architecture.mmd`; `docs/diagrams/generated/actual_vs_expected_diff.mmd`
- Required by: D-006
- Resulting authority: D-006
- Contract requirement: Add only the exact RuntimeRoot-to-DiagnosticsHub diagnostic-route obligation for deletion-resolver exceptions, then regenerate the two named graph outputs without changing their registry classification. Existing general runtime, Store, Selection, interaction-read, EditKernel, and action-delivery obligations remain unchanged.

## Assurance Register

### A-001 — Public deletion outcome
- Verifies: R-001, D-001/owner, D-001/dependency
- Claim: Through the real public selection-delete and terminal eraser routes, a client receives the final nonempty removable set before mutation and can accept or veto the whole prepared deletion without engine-owned Undo.
- Failure: Either public route bypasses the resolver boundary or existing commit owners, invokes the resolver for an empty or policy-rejected set, mutates after veto, or requires an engine Undo lifecycle.
- Oracle: Exercise both public routes through a real runtime with accepted, cancelled, empty, and policy-rejected scenarios; observe resolver calls and complete committed effects while confirming that no engine Undo API or state exists.
- Proxy risk: A resolver DTO unit test or private helper invocation can pass while one public route bypasses interception or mutates through another owner.
- Evidence constraints: Cover both entry routes and their real delivery boundary with a failing witness for bypass or post-veto mutation; keep the durable regression at the runtime owner and do not substitute copied inventories or helper-shape assertions.
- Architecture seam: D-001

### A-002 — Public declarations, exports, and defaults
- Verifies: R-004, R-012, R-013, D-002/compatibility, I-001
- Claim: The public API exposes exactly the accepted deletion configuration, policy, resolver, request, entry, decision, operation, and availability declarations with legacy-preserving defaults, and its owning contract and export inventory agree.
- Failure: A declaration, signature, enum member, export, or default is missing, extra, or incompatible with R-004, R-012, or R-013.
- Oracle: Compile a consumer against every exact public signature and default, inspect the root public export, and compare the resulting authoritative contract and export inventory with the compiled surface.
- Proxy risk: An inventory-only check can pass while declarations or defaults differ, and compilation alone can pass while the owning contract remains stale.
- Evidence constraints: Use the real public barrel and typed consumer boundary plus the authoritative contract/inventory; do not make a copied declaration list or test fixture the production owner.
- Architecture seam: D-002

### A-003 — Runtime-owned eraser configuration copy
- Verifies: R-004, D-002/state_data, I-001
- Claim: Runtime creation copies a supplied eraser-kind set exactly once into unmodifiable runtime-owned configuration, so later caller mutation cannot change the live policy while null, empty, and nonempty values remain distinct.
- Failure: The runtime aliases caller-owned mutable state, normalizes empty to null, changes the set after creation, or exposes a mutable runtime copy.
- Oracle: Create runtimes from null, empty, and nonempty caller-owned sets, mutate the original set after construction, and observe unchanged runtime behavior and immutable stored policy for the runtime lifetime.
- Proxy risk: Constructor inspection or an unmodifiable type assertion can pass while the runtime still consults the caller set or collapses null and empty.
- Evidence constraints: Exercise the real public constructor and later eraser behavior; use identity/mutation witnesses without locking the private storage field or collection implementation.
- Architecture seam: D-002

### A-004 — Derived availability state lifecycle
- Verifies: R-006, D-002/state_data
- Claim: `deleteAvailability` is derived from current committed document and selection state, is absent from `CanvasRuntimeState`, and is re-readable after document or selection revision changes without a second cached lifecycle.
- Failure: Availability is duplicated in runtime state, remains stale after either revision changes, or requires a notification independent of existing document/selection revisions.
- Oracle: Observe the runtime-state public shape, read availability, mutate selection and document independently through public routes, observe the corresponding existing revision notification, and re-read the updated value.
- Proxy risk: DTO construction or a single selection-only scenario cannot detect a runtime-state mirror or document-driven staleness.
- Evidence constraints: Use the real state listenable and selection port across both revision families; do not accept private cache inspection as the freshness oracle.
- Architecture seam: D-002

### A-005 — Direct interface migration and no-retirement gate
- Verifies: R-012, D-002/migration_retirement, I-001
- Claim: The source-breaking release extends the existing configuration and `CanvasSelectionPort` directly, migrates the runtime and a direct external implementer before release, documents the migration, retires no old public surface, and admits no V2 port, capability cast, duplicate getter, or runtime-state mirror.
- Failure: A release-visible state has incompatible declarations/implementers, lacks the migration note, retains a parallel compatibility surface, or publishes before exact public compile/export/default checks pass.
- Oracle: Compile the runtime implementation and a direct external `CanvasSelectionPort` implementation against the resulting public declarations, inspect the public barrel and runtime-state surface for forbidden alternatives, and verify the migration note and release classification in the same release state.
- Proxy risk: A migration note alone cannot prove implementer compatibility or absence of a parallel surface, while source absence alone cannot prove release ordering.
- Evidence constraints: Evaluate the complete release-visible state and real interface implementers; negative proof is bounded to public declarations, exports, runtime state, and direct port consumers rather than a repository-wide token scan.
- Architecture seam: D-002

### A-006 — Canonical selection deletion facts
- Verifies: R-006, R-007, D-003/policy, D-003/source_of_truth
- Claim: For every publicly reachable selection, availability and immediate command execution read one committed-facts authority whose predicate is content-layer membership plus `isDeletable == true`; command execution re-reads current facts rather than trusting a prior UI value, `isLocked` is ignored, `partial` removes only eligible IDs, and `allOrNone` removes nothing unless every selected ID is eligible.
- Failure: Availability and execution disagree on one snapshot, command execution trusts stale prior availability, locking changes eligibility, or either policy produces the wrong final set for a publicly reachable selection.
- Oracle: Exercise empty, fully eligible, mixed-deletability, and locked selections through the public getter and command under both policies; additionally read availability, change document or selection facts, then execute delete without refreshing the client value and compare the command outcome with the new Store-owned snapshot.
- Proxy risk: Separate predicate unit tests can pass while getter and command use different snapshots or policy paths; public setup cannot prove the unresolved-ID fallback covered by A-029.
- Evidence constraints: Drive the real selection port and committed Store owner for publicly reachable states; keep the controlled unresolved-facts witness at the internal owner boundary.
- Architecture seam: D-003

### A-007 — Eraser admission before work budgets
- Verifies: R-005, D-003/policy
- Claim: Null, empty, and nonempty eraser-kind policies apply identically to preview and terminal reads before candidate-limit and exact-check accounting, independently of resolver presence.
- Failure: A disallowed kind appears in preview or commit, consumes either budget, null or empty semantics collapse, or callback presence changes admission.
- Oracle: Use mixed-kind spatial candidates around both limits and observe preview hits, terminal removals, candidate accounting, and exact-check accounting for null, empty, and explicit allow-lists with and without a resolver.
- Proxy risk: Final removed-ID assertions cannot detect budget spent on filtered candidates or preview/commit drift.
- Evidence constraints: Instrument the existing candidate and exact-check owner boundaries without replacing their counters or geometry with a test-only policy implementation.
- Architecture seam: D-003

### A-008 — Deletion request defensive immutability
- Verifies: R-008, R-013, D-002/state_data
- Claim: A deletion request makes one unmodifiable copy of its entry iterable, preserves each exact immutable `CanvasElement` reference, and exposes no mutable list alias.
- Failure: Mutating the source iterable changes the request, mutating the exposed entries succeeds, entries are copied into different element objects, or repeated reads expose mutable backing.
- Oracle: Construct the public request from a mutable entry source, mutate that source after construction, attempt mutation through the exposed list, and assert retained entry order and exact element identities.
- Proxy risk: Type declarations and nominally unmodifiable collection types do not prove defensive copying or immutable exposure.
- Evidence constraints: Exercise only the public DTO boundary with real element variants; do not inspect its private backing field.
- Architecture seam: D-002

### A-009 — Public equality policy
- Verifies: R-006, R-013, D-002/state_data
- Claim: `CanvasDeletionCommitRequest` and `CanvasDeletionEntry` retain identity equality, while equal `CanvasSelectionDeleteAvailability` values compare equal and produce equal hash codes.
- Failure: Separately constructed request or entry values compare equal, equal availability values compare unequal, unequal availability values compare equal, or hash behavior contradicts equality.
- Oracle: Compare separate public instances covering equal and unequal availability fields plus structurally identical request and entry instances, including hash-based collection behavior.
- Proxy risk: Source inspection or generated-method presence can miss exported behavior and hash/equality disagreement.
- Evidence constraints: Use public constructors and operators; do not infer equality from private implementation or element equality.
- Architecture seam: D-002

### A-010 — Canonical callback entry correctness
- Verifies: R-008, D-004/order
- Claim: Before the first mutation, Store-owned batch facts produce every final removed element, source layer, and original in-layer index in document-layer then element order for both selection delete and terminal eraser.
- Failure: An entry is missing, duplicated, stale, misordered, has a post-removal index or wrong layer, or either public route bypasses the Store projection.
- Oracle: Delete interleaved elements across multiple layers through both routes and compare callback entries with direct pre-mutation Store element/location/order-token facts on the same snapshot.
- Proxy risk: Removed-ID action order alone cannot prove full element identity, original source indices, snapshot consistency, or eraser-route parity.
- Evidence constraints: Capture expected facts through the committed Store boundary before mutation and preserve exact element identity; do not materialize a document solely for the oracle.
- Architecture seam: D-004

### A-011 — Deletion projection work bounds
- Verifies: R-008, D-004/order
- Claim: Store-owned projection performs O(k) fact reads for k removals, O(k) ordering work when IDs are already canonical, and O(k log k) comparison work for arbitrary order, while fixed k remains independent of unrelated document size N.
- Failure: Canonical input performs superlinear work, arbitrary input exceeds comparison-sort growth, or increasing unrelated N increases projection reads/comparisons for fixed k.
- Oracle: Observe deterministic Store-owned fact-read and order-comparison counters while scaling k over canonical and permuted IDs, then scale unrelated N at fixed k; assert linear canonical growth, bounded k-log-k arbitrary growth, and N-independent fixed-k work.
- Proxy risk: Wall-clock timing is noisy, and only growing N at fixed k cannot distinguish O(k) from superlinear work in k.
- Evidence constraints: Counters must belong at stable Store fact/order seams and measure work rather than private helper names; retain separate canonical-k, arbitrary-k, and fixed-k/growing-N witnesses.
- Architecture seam: D-004

### A-012 — Existing resolver guard semantics
- Verifies: R-003, D-001/owner, D-005/temporal
- Claim: During deletion resolution, runtime reads and client-owned Undo mutation remain permitted, while every public runtime mutation, edit, tool command, runtime disposal, and nested resolver attempt is rejected by the existing guard without document, selection, revision, timestamp, action, interaction, or lifecycle effects.
- Failure: A permitted read or client Undo update is blocked, a forbidden runtime operation or disposal succeeds or changes state, or a nested resolver executes.
- Oracle: From both deletion callbacks, perform representative runtime reads and client Undo writes, then attempt each public mutation/edit/tool family, `CanvasRuntime.dispose`, and a nested resolver call; observe the expected rejection and exact before/after runtime, interaction, stream, and lifecycle state.
- Proxy risk: Testing one command family or only the thrown error can miss another mutation path or a side effect before rejection.
- Evidence constraints: Cover the public command families admitted by `ensureRuntimeMutationAllowed`, the facade-to-root disposal route, and the real nested-callback route; assertions must include unchanged committed, interaction, stream, and disposal state.
- Architecture seam: D-001, D-005

### A-013 — Preparation completes before callback
- Verifies: R-003, R-010, D-005/temporal
- Claim: Every expected document, selection, validation, stale-check, normalization, request, revision, and action-input failure occurs before the resolver, so a failed preparation cannot cause a client to record Undo for a deletion that is not ready to install.
- Failure: The resolver runs before an expected preparation failure or any expected-failure operation remains between accept and first owner installation.
- Oracle: Inject each admitted preparation failure at its owning boundary for both deletion routes and assert zero resolver calls, unchanged committed effects, and terminal eraser cleanup.
- Proxy risk: A single synthetic failure cannot prove all expected-failure owners were moved before the callback.
- Evidence constraints: Use owner-boundary failure injection for Store, Selection, request, validation/base, and action-input preparation; do not treat VM-fatal failures as part of this contract.
- Architecture seam: D-005

### A-014 — Accepted deletion installs atomically
- Verifies: R-003, R-010, D-005/atomicity
- Claim: Resolver accept consumes one private token once and synchronously installs prepared document then selection with no expected failure or state/action publication between owner installations.
- Failure: The token installs twice, selection can fail normally after document mutation, publication observes a mixed snapshot, or a normal stale/validation/copy failure remains possible after accept.
- Oracle: Accept both deletion routes while observing owner-install and publication events, assert exactly one document/selection installation and no intermediate public notification, and use the prepared owners' failure seams to prove no normal failure remains post-accept while allowing allocation-only work whose only failure is VM-fatal.
- Proxy risk: Final-state equality cannot detect transient mixed publication, duplicate consumption, or a latent post-accept failure window.
- Evidence constraints: Observe stable owner and publication boundaries without exposing the private token as public API or requiring rollback.
- Architecture seam: D-005

### A-015 — Explicit cancel has no committed effect
- Verifies: R-002, D-005/temporal, D-005/atomicity
- Claim: Explicit resolver cancel discards prepared state, changes no document or selection state/revision/timestamp/action, and emits no committed action or error diagnostic. Terminal erase completes its preview/session cleanup; selection delete leaves independent eraser interaction state unchanged.
- Failure: Any prepared mutation leaks, a committed delivery or diagnostic occurs, terminal erase retains preview/session state, or selection delete changes unrelated eraser interaction state.
- Oracle: Cancel both routes and compare complete pre/post committed snapshots, revisions, timestamps, action stream, and diagnostics; additionally require terminal-eraser cleanup and unchanged independent eraser state for selection delete.
- Proxy risk: Checking document equality alone misses selection, revisions, delivery, diagnostics, and interaction cleanup.
- Evidence constraints: Use public observations plus the admitted internal diagnostics sink; explicit cancel remains distinct from callback failure.
- Architecture seam: D-005

### A-016 — Resolver exception preserves committed state
- Verifies: R-002, D-005/temporal, D-005/atomicity
- Claim: A resolver exception is absorbed as cancel for deletion effects: prepared state is discarded and document, selection, revisions, timestamp, and actions remain unchanged. Terminal erase completes its preview/session cleanup; selection delete leaves independent eraser interaction state unchanged.
- Failure: The exception escapes, any committed effect or action occurs, terminal erase leaks interaction state, or selection delete changes unrelated eraser interaction state.
- Oracle: Throw representative synchronous errors from both route callbacks and compare complete pre/post committed observations, requiring terminal-eraser cleanup and unchanged independent eraser state for selection delete while separately inspecting diagnostics under A-020.
- Proxy risk: Diagnostic presence does not prove exception containment or no-mutation semantics.
- Evidence constraints: Keep outcome assertions independent of diagnostic-record assertions and exclude VM-fatal conditions such as out-of-memory.
- Architecture seam: D-005

### A-017 — Eraser cleanup precedes fallible delivery
- Verifies: R-002, R-010, D-005/temporal
- Claim: Terminal eraser preview/session cleanup is guaranteed for empty/policy-rejected, preparation-failed, accepted, cancelled, resolver-failed, and post-install delivery-failed outcomes, and occurs before fallible external state/action delivery.
- Failure: Any terminal branch retains preview/session state or an external delivery failure can prevent cleanup.
- Oracle: Exercise every terminal branch, inject state/action listener failure after accepted install, and observe cleanup ordering plus the correct committed outcome for each branch.
- Proxy risk: A successful terminal gesture cannot cover early exits or listener-failure ordering.
- Evidence constraints: Observe the existing eraser lifecycle and delivery boundaries; do not add a second cleanup owner for testing.
- Architecture seam: D-005

### A-018 — Resolver-null one-phase route
- Verifies: R-009, D-005/temporal
- Claim: When the resolver is absent, both deletion routes retain current one-phase prepare-and-install behavior and create neither deletion callback DTOs nor deferred install state, while selection and eraser policies still apply.
- Failure: Resolver-specific allocation or deferred installation occurs, legacy action/effect behavior changes, or either policy is bypassed.
- Oracle: Exercise both routes with resolver absent and instrument only the DTO/deferred-state construction seams plus public effects under each policy.
- Proxy risk: Matching final state cannot prove the required fast path or absence of resolver-specific work.
- Evidence constraints: Use a narrow allocation/construction witness owned by the new seam, not broad heap profiling or private helper-name assertions.
- Architecture seam: D-005

### A-019 — Existing deletion action compatibility
- Verifies: R-010, R-014
- Claim: Accepted selection delete and terminal erase emit their existing committed action types and payload shapes with the accepted final removed IDs and unchanged timestamp semantics.
- Failure: An action type or payload changes, a new deletion action is introduced, removed IDs diverge from the installed set, or timestamp behavior changes.
- Oracle: Accept both deletion routes with and without a configured resolver and compare emitted public actions with the existing delete/erase action contracts for type, payload, IDs, and timestamp behavior.
- Proxy risk: Final document state cannot prove public action compatibility, while declaration inspection cannot prove runtime payload construction.
- Evidence constraints: Exercise the real action finalizer and public action stream; do not copy action construction into a test-only oracle.
- Architecture seam: D-005, D-007

### A-020 — Contained resolver-exception diagnostics
- Verifies: R-002, R-015, D-006/owner, I-003
- Claim: A deletion-resolver exception records exactly one dedicated internal `interaction` error through the existing adapter with bounded operation and error-kind facts only; explicit cancel and preparation failure record none, disabled diagnostics allocates or exposes no record, and no public diagnostic surface is added.
- Failure: The record is missing, duplicated, routed elsewhere, leaks element/document/request/runtime data, appears for controls, or survives disabled diagnostics.
- Oracle: Throw representative resolver errors with enabled and disabled diagnostics, compare cancel and preparation-failure controls, inspect the bounded internal record and public surface, and validate the owning diagnostic contract and graph route.
- Proxy risk: Merely finding the new code or code enum cannot prove cardinality, redaction, disabled behavior, or route ownership.
- Evidence constraints: Exercise the real resolver and runtime diagnostics adapter; never log callback payloads as evidence.
- Architecture seam: D-006

### A-021 — Durable deletion lifecycle authority
- Verifies: I-002
- Claim: All production owners and maintained contracts/semantic diagrams named by I-002 agree on runtime configuration and availability integration, canonical command facts, pre-budget eraser filtering, Store-owned bounded projection, guarded prepare-veto-install ordering, diagnostic initiation, cleanup/publication/action order, and unchanged layer/resource effects.
- Failure: A named owner or durable surface preserves old partial-only, unfiltered, O(N), direct-commit, fallible-post-accept, unguarded diagnostic, duplicated-availability, or implicit-cleanup semantics.
- Oracle: Review every exact I-002 target against D-001 through D-006 and exercise its direct public, owner, work-budget, temporal, diagnostic, and unresolved-facts observations on the same resulting repository state.
- Proxy risk: Individual behavior tests can pass while one production owner or maintained semantic contract remains stale.
- Evidence constraints: Require direct evidence from every named target and its nearest stable owner assurance; do not create a duplicate checklist or make a prose parser authoritative.
- Architecture seam: D-001, D-002, D-003, D-004, D-005, D-006

### A-022 — Selection-delete end-to-end ordering work
- Verifies: R-008, D-004/order
- Claim: From the selected-ID facts read through callback-entry completion, selection delete bypasses the current full-frame-handle walk, builds no `CanvasDocument`, and performs O(k) work for canonical IDs or O(k log k) work for arbitrary IDs independently of unrelated document size N.
- Failure: The route retains an O(N) handle pass or document projection before the Store batch seam, canonical k grows superlinearly, arbitrary k exceeds comparison-sort growth, or fixed-k work grows with N.
- Oracle: At the complete selection-delete route, observe stable fact-read, ordering-comparison, full-handle-iteration, and document-projection counters while separately scaling canonical k, permuted k, and unrelated N at fixed k; require zero full-handle iterations and zero document projections.
- Proxy risk: Store projection counters alone can pass while RuntimeRoot or command-facts preparation still scans or materializes the whole document.
- Evidence constraints: Instrument stable route and owner boundaries rather than private helper identifiers; retain distinct canonical-k, arbitrary-k, and fixed-k/growing-N witnesses.
- Architecture seam: D-004

### A-023 — Terminal-eraser end-to-end ordering work
- Verifies: R-008, D-004/order
- Claim: From the final exact-hit IDs through callback-entry completion, terminal eraser bypasses its current full-handle ordering walk, builds no `CanvasDocument`, and performs O(k) work for canonical IDs or O(k log k) work for arbitrary IDs independently of unrelated document size N.
- Failure: The route retains an O(N) handle pass or document projection around the Store batch seam, canonical k grows superlinearly, arbitrary k exceeds comparison-sort growth, or fixed-k work grows with N.
- Oracle: At the complete terminal-eraser ordering route, observe stable fact-read, ordering-comparison, full-handle-iteration, and document-projection counters while separately scaling canonical k, permuted k, and unrelated N at fixed k; require zero full-handle iterations and zero document projections.
- Proxy risk: Final entry correctness or Store-local work counters cannot detect a retained runtime ordering pass before or after the Store projection.
- Evidence constraints: Instrument stable eraser-route and owner boundaries rather than private helper identifiers; retain distinct canonical-k, arbitrary-k, and fixed-k/growing-N witnesses.
- Architecture seam: D-004

### A-024 — Resolver invocation cardinality
- Verifies: R-002, D-005/temporal
- Claim: Each public deletion route invokes the resolver zero times for empty, invalid, or policy-rejected final sets and exactly once for every nonempty final set, whether that single invocation accepts, cancels, or throws.
- Failure: A resolver is called for a no-op set, skipped for a nonempty set, retried after a decision or exception, or invoked more than once for one deletion operation.
- Oracle: Count resolver entry at the real callback boundary for selection delete and terminal eraser across empty, invalid/policy-rejected, accept, cancel, and throwing cases, correlating each count with one public operation and its final prepared set.
- Proxy risk: Final state and action observations can remain correct despite a duplicate callback that records client Undo twice.
- Evidence constraints: Count the public configured resolver boundary, not a private helper, and cover both routes plus every terminal decision family in one operation-at-a-time witnesses.
- Architecture seam: D-005

### A-025 — Empty layer retention
- Verifies: R-011, D-003/policy
- Claim: Removing the last element from a source layer through selection delete or terminal erase retains that layer and its existing order and metadata.
- Failure: Element deletion implicitly removes, reorders, recreates, or changes the emptied layer.
- Oracle: Delete the sole eligible element from background-adjacent and ordinary content layers through both routes and compare layer identity, order, and metadata before and after.
- Proxy risk: Element absence or layer count alone cannot detect layer recreation, reordering, or metadata drift.
- Evidence constraints: Observe the public committed document and Store layer facts without invoking an explicit layer-removal operation.
- Architecture seam: D-003

### A-026 — Resource descriptor retention
- Verifies: R-011, D-003/policy
- Claim: Removing the last element reference through selection delete or terminal erase retains the resource descriptor; descriptor removal remains a separate explicit operation.
- Failure: Deletion implicitly removes or mutates the now-unreferenced descriptor or reports descriptor removal as a deletion effect.
- Oracle: Delete the sole image and vector references through both routes, then read the unchanged descriptors and separately prove that the existing explicit remove-unused-resource operation remains required.
- Proxy risk: Element removal and reference-count changes cannot prove descriptor membership or descriptor-value retention.
- Evidence constraints: Observe the committed resource catalog and existing explicit resource operation; do not infer retention from callback entries or action payloads.
- Architecture seam: D-003

### A-027 — Excluded-route containment
- Verifies: R-014, D-007/out_of_scope
- Claim: Deletion interception, selection all-or-none policy, and eraser kind admission affect only public selection delete and terminal eraser; direct command/edit removal, clear, import, resource operations, locking/general selection eligibility, and non-eraser tools retain current behavior without resolver calls.
- Failure: An excluded route invokes the deletion resolver, adopts either policy, changes its effects, or gains an engine Undo/transaction/rollback surface.
- Oracle: Exercise one representative public operation from each excluded family with all new configuration fields enabled and compare resolver count plus existing committed and interaction effects with current contracts.
- Proxy risk: Searching for resolver symbols cannot detect indirect policy spread, while one excluded route cannot stand for independently routed families.
- Evidence constraints: Use the real public route boundaries and existing owner-level behavior witnesses; no permanent private-name scanner or duplicate route inventory is admitted.
- Architecture seam: D-007

### A-028 — Architecture graph projection closure
- Verifies: I-004
- Claim: The exact new RuntimeRoot-to-DiagnosticsHub deletion-resolver diagnostic obligation and two generated outputs named by I-004 represent the added diagnostic route without changing existing general graph obligations or generated-view ownership.
- Failure: The new diagnostic obligation is absent or points to the wrong owner, an unchanged general obligation is unnecessarily rewritten, either generated output differs from the graph, or a generated view becomes semantic authority.
- Oracle: Inspect the new runtime-to-diagnostics obligation in `architecture_graph.yaml`, confirm the existing general route obligations are unchanged, then run graph closure and generated-view consistency and compare both exact output files with that graph state.
- Proxy risk: Passing generated-view checks cannot prove semantic edge ownership, while graph prose inspection cannot detect stale outputs.
- Evidence constraints: Use the checked-in expected graph, its mechanical closure commands, and the two named generated files; do not use generated content as an independent owner.
- Architecture seam: D-006

### A-029 — Unresolved selection facts fail closed
- Verifies: R-007, D-003/policy, D-003/source_of_truth, D-008/negative_proof_fixture
- Claim: At the canonical command-facts boundary, a controlled selected ID that does not resolve in the committed Store is non-deletable: availability reports a nonempty not-fully-deletable selection, `allOrNone` yields no removal, and `partial` retains only the independently resolved eligible subset.
- Failure: An unresolved ID is ignored when computing whole-selection eligibility, enters a removal set, or causes availability and either policy consumer to disagree.
- Oracle: Supply controlled Selection facts containing resolved eligible IDs plus an unresolved ID to the real command-facts adapter over one committed Store snapshot, then observe the shared facts consumed by availability and both policy branches.
- Proxy risk: Public selection setup normalizes unresolved IDs away, while testing a copied predicate cannot prove the canonical boundary or both consumers.
- Evidence constraints: Use the real `CommandFactsPort` implementation with controlled fixture-owned Selection inputs and real Store resolution; quarantine invalid-state values and recognition in the test fixture, and do not mutate SelectionKernel internals, add a public invalid-selection path, or copy the production predicate into the fixture.
- Architecture seam: D-003, D-008

### A-030 — Resolved non-content selection facts fail closed
- Verifies: R-007, D-003/policy, D-003/source_of_truth, D-008/negative_proof_fixture
- Claim: At the canonical command-facts boundary, a controlled selected ID that resolves in the committed Store as a background/non-content element is non-deletable even when its element-level `isDeletable` flag is true: availability reports a nonempty not-fully-deletable selection, `allOrNone` yields no removal, and `partial` retains only independently resolved eligible content elements.
- Failure: A resolved non-content ID is treated as deletion-eligible, enters a removal set, or causes availability and either policy consumer to disagree.
- Oracle: Supply controlled Selection facts containing an eligible content ID plus a resolved background/non-content ID to the real command-facts adapter over one committed Store/frame snapshot, then observe the shared facts consumed by availability and both policy branches.
- Proxy risk: Public selection setup normalizes non-content IDs away, while an unresolved-ID witness cannot prove that location classification participates in the canonical predicate.
- Evidence constraints: Use the real `CommandFactsPort` implementation with controlled fixture-owned Selection inputs and real committed location facts; quarantine invalid-state values and recognition in the test fixture, and do not mutate SelectionKernel internals, add a public invalid-selection path, or copy the production predicate/location classifier into the fixture.
- Architecture seam: D-003, D-008

## Stop Conditions

### H-001 — Existing-owner no-normal-failure installation is infeasible
- Trigger: Current implementation evidence shows that a normal validation, stale, or copy failure or an observable publication must remain between resolver accept and completion of both document and selection installation unless a new coordinator, rollback path, or general transaction framework is introduced. Allocation-only copying whose only failure is VM-fatal does not trigger this stop.
- Invalidates: D-001, D-005, A-001, A-013, A-014, A-017, A-021, I-002
- Resolution requires: Stop contract authoring or implementation and re-enter architecture with the concrete unavoidable failure/interleaving evidence; do not weaken the client Undo guarantee or silently broaden scope.

### H-002 — Order tokens cannot support the accepted batch projection
- Trigger: Current Store evidence shows that document-order tokens are not snapshot-stable and dense enough to derive original in-layer indices, or that resolving k removals necessarily scans/materializes N document elements without adding a new persistent authority.
- Invalidates: D-004, A-010, A-011, A-022, A-023, I-002
- Resolution requires: Re-enter architecture with measured Store facts and choose a new ordering/index authority explicitly before changing the accepted complexity or entry-index guarantee.

### H-003 — Public compatibility policy rejects the direct port extension
- Trigger: The release owner determines that the source-breaking `CanvasSelectionPort.deleteAvailability` addition cannot ship under the repository's active semver and migration policy in the intended release.
- Invalidates: D-002, A-002, A-005, A-021, I-001, I-002
- Resolution requires: Obtain a new product and architecture decision on the public compatibility surface; do not introduce an unapproved V2 port, capability cast, duplicated getter, or runtime-state mirror as an implementation workaround.

## Contract Interface

- Profile: `BEHAVIOR_CHANGE`
- Obligations: `PUBLIC_API_CHANGE`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `TEMPORAL_SURFACE_CLOSURE`, `ALL_OR_NOTHING_FAILURE_BOUNDARY`, `SOURCE_OF_TRUTH_SINGULARITY`, `WORK_BUDGET_CLOSURE`, `NEGATIVE_PROOF_AND_FIXTURE_QUARANTINE`
- ADR Impact: none
- Sources: S-001, S-002, S-003, S-004, S-005, S-006, S-007, S-008, S-009, S-010, S-011, S-012, S-013, S-014, S-015, S-016, S-017, S-018, S-019, S-020, S-021, S-022, S-023, S-024, S-025, S-026, S-027, S-028, S-029, S-030, S-031, S-032, S-033, S-034, S-035, S-036, S-037, S-038, S-039, S-040, S-041, S-042, S-043, S-044, S-045, S-046, S-047, S-048, S-049, S-050, S-051
- Requirements: R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-008, R-009, R-010, R-011, R-012, R-013, R-014, R-015
- Commitments: D-001, D-002, D-003, D-004, D-005, D-006, D-007, D-008
- Assurance: A-001, A-002, A-003, A-004, A-005, A-006, A-007, A-008, A-009, A-010, A-011, A-012, A-013, A-014, A-015, A-016, A-017, A-018, A-019, A-020, A-021, A-022, A-023, A-024, A-025, A-026, A-027, A-028, A-029, A-030
- Impacts: I-001, I-002, I-003, I-004
- Stops: H-001, H-002, H-003

## Diagrams

### DG-001 — Deletion resolver and installation boundary
- Type: `sequence`
- Question: Where do policy, callback, irreversible installation, eraser cleanup, diagnostics, and public delivery occur relative to one another?
- Supports: D-001, D-003, D-004, D-005, D-006, A-010, A-012, A-013, A-014, A-015, A-016, A-017, A-018, A-020, A-024, I-002, I-003

```mermaid
sequenceDiagram
  participant Entry as Delete / terminal Eraser
  participant Facts as Committed facts owners
  participant Apply as EditKernel + CommitApplier
  participant Resolver as Client resolver
  participant Owners as Store + Selection
  participant Diag as Interaction diagnostics
  participant Public as State + action delivery

  Note right of Entry: Selection delete preserves independent Eraser interaction state
  Entry->>Facts: resolve current eligibility and policy
  alt final removal set is empty
    Facts-->>Entry: no-op
    opt terminal Eraser only
      Entry-->>Entry: cleanup preview and session
    end
  else resolver is absent
    Entry->>Apply: current one-phase prepare + install
    alt preparation succeeds
      Apply->>Owners: document then selection
      opt terminal Eraser only
        Entry-->>Entry: cleanup preview and session
      end
      Entry->>Public: publish state and existing action
    else preparation fails
      opt terminal Eraser only
        Entry-->>Entry: cleanup preview and session
      end
    end
  else resolver is configured
    Entry->>Facts: batch-project canonical element/layer/index entries
    Entry->>Apply: prepare validated document + selection + delivery inputs
    alt preparation fails before resolver
      opt terminal Eraser only
        Entry-->>Entry: cleanup preview and session
      end
    else preparation succeeds
      Apply-->>Entry: private single-use prepared install
      Entry->>Resolver: request under existing mutation guard
      Note over Entry,Resolver: Runtime reads and client Undo allowed; runtime mutation/edit/tool/dispose and nested resolver rejected without effects
      alt accept
        Entry->>Apply: consume once in same synchronous stack
        Apply->>Owners: no-normal-failure document then selection install
        opt terminal Eraser only
          Entry-->>Entry: cleanup before fallible delivery
        end
        Entry->>Public: publish state and existing action
      else explicit cancel
        Entry-->>Apply: discard prepared install; no committed effects
        opt terminal Eraser only
          Entry-->>Entry: cleanup preview and session
        end
      else resolver throws
        Entry-->>Apply: discard prepared install; no committed effects
        Entry->>Diag: bounded internal interaction error
        opt terminal Eraser only
          Entry-->>Entry: cleanup preview and session
        end
      end
    end
  end
```

## Readiness Matrix

### Architecture Closure

| Concern | Status | Support refs |
| --- | --- | --- |
| owner | closed | D-001, D-006 |
| in_scope | closed | D-001 |
| out_of_scope | closed | D-007 |
| source_of_truth | closed | D-003 |
| compatibility | closed | D-002 |
| order | closed | D-004 |
| policy | closed | D-003 |
| dependency | closed | D-001 |
| state_data | closed | D-002 |
| migration_retirement | closed | D-002 |
| temporal | closed | D-005 |
| atomicity | closed | D-005 |
| negative_proof_fixture | closed | D-008 |
| recognition | not_applicable | R-014, E-026 |

### Gate Closure

| Gate | Status | Support refs |
| --- | --- | --- |
| Owner-Level Fix | pass | D-001, D-003, D-004, D-005, D-006, A-001, A-012, A-020, R-001, R-015, E-009, E-012, E-033 |
| Ownership | pass | D-001, D-006, A-001, A-012, A-020 |
| Source-Of-Truth Singularity | pass | D-002, D-003, D-004, A-004, A-006, A-010, A-011, A-022, A-023, A-029, A-030 |
| Source-Truth Minimality | pass | D-002, D-003, D-004, A-004, A-006, F-001, M-006, M-008 |
| Boundary-Owned Policy | pass | D-003, A-006, A-007, A-025, A-026, A-030 |
| Dependency Direction | pass | D-001, A-001, A-012, A-028, E-051, E-059 |
| Solution Proportionality | pass | F-001, M-001, M-002, M-003, M-004, M-005, M-006, M-007, M-008, M-009, M-010, M-011, M-012, M-013, M-014, M-015, R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-008, R-009, R-010, R-011, R-012, R-013, R-014, R-015 |
| Outcome-Proof Fit | pass | A-001 |
| Verification | pass | A-001, A-002, A-003, A-004, A-005, A-006, A-007, A-008, A-009, A-010, A-011, A-012, A-013, A-014, A-015, A-016, A-017, A-018, A-019, A-020, A-021, A-022, A-023, A-024, A-025, A-026, A-027, A-028, A-029, A-030 |
| Future Pressure | pass | P-001, P-002, P-003 |
| Handoff Consumability | pass | CONTRACT, H-001, H-002, H-003 |
| Negative Proof And Fixture Quarantine | pass | D-008, A-029, A-030 |
| State/Data Ownership | pass | D-002, A-003, A-004, A-008, A-009 |
| Sequenced Migration And Retirement | pass | D-002, A-005, I-001, H-003 |
| Temporal Surface Closure | pass | D-005, A-012, A-013, A-015, A-016, A-017, A-018, A-024, H-001 |
| All-Or-Nothing Failure Boundary | pass | D-005, A-014, A-015, A-016, H-001 |
| Bounded Recognition Scope | not_applicable | R-014, E-026 |

## Open Blockers

None
