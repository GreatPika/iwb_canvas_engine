# Change Contract

## Goal

The maintained runtime requires one deletion resolver and explicit runtime configuration so selection deletion and terminal erasing derive one final canonical removal set, offer every nonempty set to the client before mutation with no direct-install bypass, install an accepted deletion through the existing Store, Selection, EditKernel, CommitApplier, InteractionEngine, RuntimeRoot, and DiagnosticsHub owners, end empty or policy-rejected operations before resolver-specific construction, and keep bounded work, failure containment, cleanup, actions, documentation, and architecture projections consistent with the accepted design.

## Source Inputs

| Category | Source ID | Location or authority |
| --- | --- | --- |
| Design | `deletion-policies-design` | docs/planning/designs/2026-08-24-deletion-eraser-and-selection-policies.md |
| Research | `deletion-policies-research` | docs/history/research/2026-08-24-deletion-eraser-and-selection-policies.md |
| PLAN | none | none |
| Other | `user-request` | user request |
| Other | `public-runtime-contract` | lib/src/contracts/public/canvas_runtime.dart |
| Other | `public-element-contract` | lib/src/contracts/public/canvas_element.dart |
| Other | `selection-command-facts` | lib/src/runtime/runtime_command_facts_adapter.dart |
| Other | `eraser-read-adapter` | lib/src/runtime/runtime_interaction_read_adapter.dart |
| Other | `runtime-root` | lib/src/runtime/runtime_root.dart |
| Other | `edit-kernel` | lib/src/edit/edit_kernel.dart |
| Other | `commit-applier` | lib/src/edit/commit_applier.dart |
| Other | `document-store` | lib/src/store/document_store_kernel.dart |
| Other | `element-order` | lib/src/store/element_registry.dart |
| Other | `selection-kernel` | lib/src/selection/selection_kernel.dart |
| Other | `prepared-selection-effect` | lib/src/contracts/internal/prepared_selection_effect.dart |
| Other | `eraser-hit-policy` | lib/src/geometry/hit_test_policy.dart |
| Other | `public-api-contract` | docs/contracts/public_api_v1.md |
| Other | `operation-matrix` | docs/contracts/operation_matrix.md |
| Other | `eraser-commit-sequence` | docs/diagrams/seq_eraser_commit.mmd |
| Other | `runtime-config` | lib/src/runtime/runtime_config.dart |
| Other | `public-actions-contract` | lib/src/contracts/public/canvas_actions.dart |
| Other | `action-finalizer` | lib/src/runtime/runtime_action_finalizer.dart |
| Other | `diagnostics-contract` | docs/contracts/diagnostics.md |
| Other | `diagnostic-code` | lib/src/diagnostics/diagnostic_code.dart |
| Other | `interaction-diagnostics-adapter` | lib/src/runtime/runtime_interaction_diagnostics_adapter.dart |
| Other | `data-model` | docs/architecture/03_data_model.md |
| Other | `geometry-contract` | docs/contracts/geometry.md |
| Other | `eraser-budget-sequence` | docs/diagrams/seq_eraser_exact_budget.mmd |
| Other | `eraser-state` | docs/diagrams/state_eraser.mmd |
| Other | `public-api-registry` | docs/_registry/public_api_v1.yaml |
| Other | `edit-contract` | docs/contracts/edit_kernel.md |
| Other | `interaction-contract` | docs/contracts/interaction_engine.md |
| Other | `architecture-graph` | docs/architecture/architecture_graph.yaml |
| Other | `adr-policy` | architecture/decisions/README.md |
| Other | `store-candidate-adr` | architecture/decisions/ADR-0017-store-transaction-candidate-and-derived-facts.md |
| Other | `release-gates` | docs/verification/release_gates.md |
| Other | `external-selection-consumer` | test/api_contract/public_api_v1_compiles_as_written_test.dart |
| Other | `public-runtime-facade` | lib/src/api/canvas_runtime.dart |
| Other | `single-runtime-adr` | architecture/decisions/ADR-0001-single-maintained-acyclic-runtime.md |
| Other | `state-separation-adr` | architecture/decisions/ADR-0002-separate-committed-runtime-and-projection-state.md |
| Other | `store-finalization-adr` | architecture/decisions/ADR-0003-store-finalized-edit-transactions.md |
| Other | `selection-ownership-adr` | architecture/decisions/ADR-0008-selection-move-and-chrome-ownership.md |
| Other | `interaction-cleanup-adr` | architecture/decisions/ADR-0009-interaction-tool-machines-and-cleanup.md |
| Other | `diagnostics-routing-adr` | architecture/decisions/ADR-0012-internal-diagnostics-routing.md |
| Other | `documentation-ownership-adr` | architecture/decisions/ADR-0013-documentation-graph-and-proof-ownership.md |
| Other | `architecture-overview` | docs/architecture/00_architecture_overview.md |
| Other | `package-boundaries` | docs/architecture/02_package_boundaries.md |
| Other | `documentation-entry` | docs/README.md |
| Other | `architecture-entry` | docs/architecture/README.md |
| Other | `section-registry` | docs/_registry/sections.yaml |
| Other | `diagram-registry` | docs/_registry/diagrams.yaml |
| Other | `command-facts-contract` | lib/src/contracts/internal/command_facts_port.dart |
| Other | `runtime-ownership` | docs/architecture/01_runtime_ownership.md |

## Classification

Profile: `BEHAVIOR_CHANGE`
Obligations: `PUBLIC_API_CHANGE`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `TEMPORAL_SURFACE_CLOSURE`, `ALL_OR_NOTHING_FAILURE_BOUNDARY`, `SOURCE_OF_TRUTH_SINGULARITY`, `WORK_BUDGET_CLOSURE`, `NEGATIVE_PROOF_AND_FIXTURE_QUARANTINE`

## Decision Trace

| Decision ID | Independent failure family | Source decision | Contract location | Acceptance or evidence target |
| --- | --- | --- | --- | --- |
| `public-deletion-outcome` | A public deletion route can bypass whole-set pre-commit veto or existing commit owners. | R-001; D-001; A-001 | Unit 4; Matrix | `two-route-deletion-outcome-evidence` |
| `public-deletion-surface` | Public declarations, required constructor arguments, exports, remaining defaults, and owning documentation can disagree. | R-004, R-012, R-013; D-002; A-002 | Units 1, 2, 4; Matrix | `public-deletion-surface-evidence` |
| `eraser-config-copy` | Runtime eraser policy can alias caller mutation or collapse null and empty. | R-004, R-005; D-002; A-003 | Unit 2; Matrix | `eraser-config-copy-evidence` |
| `derived-delete-availability` | Delete availability can become duplicated or stale relative to document and selection revisions. | R-006; D-002; A-004 | Unit 1; Matrix | `derived-availability-evidence` |
| `direct-api-migration` | The required config/resolver and direct port extensions can leave repository constructions, an implementer, migration note, or release surface incompatible. | R-012; D-002; A-005 | Units 1, 4; Matrix | `public-deletion-surface-evidence` |
| `canonical-selection-facts` | Availability and delete execution can use different eligibility facts or stale UI state. | R-006, R-007; D-003; A-006 | Unit 1; Matrix | `canonical-selection-facts-evidence` |
| `eraser-prebudget-admission` | Kind filtering can diverge between preview and terminal or consume rejected-candidate budgets. | R-005; D-003; A-007 | Unit 2; Matrix | `eraser-prebudget-evidence` |
| `eraser-resolver-request-policy` | The terminal resolver route can rebuild or bypass the filtered eraser set after Unit 2 reads. | R-005; D-003; A-007 | Unit 4; Matrix | `eraser-resolver-request-policy-evidence` |
| `request-defensive-copy` | A deletion request can retain a mutable entry-list alias or replace element identity. | R-008, R-013; D-002; A-008 | Unit 4; Matrix | `request-immutability-evidence` |
| `deletion-equality-policy` | Request/entry identity equality or availability value equality can drift. | R-006, R-013; D-002; A-009 | Units 1, 4; Matrix | `deletion-equality-evidence` |
| `callback-entry-correctness` | Callback entries can be stale, incomplete, duplicated, misordered, or carry post-removal positions. | R-008; D-004; A-010 | Units 3, 4; Matrix | `two-route-callback-entry-evidence` |
| `store-projection-budget` | Store batch projection can become superlinear in k or dependent on unrelated N. | R-008; D-004; A-011 | Unit 3; Matrix | `store-projection-work-evidence` |
| `resolver-guard-semantics` | A deletion callback can block allowed reads or permit a public mutation, disposal, or nested resolver with side effects. | R-003; D-001, D-005; A-012 | Unit 4; Matrix | `two-route-guard-evidence` |
| `precallback-preparation` | Expected preparation failure can occur after the client callback begins. | R-003, R-010; D-005; A-013 | Unit 4; Matrix | `two-route-preparation-evidence` |
| `accepted-install-atomicity` | Accept can consume twice, publish a mixed state, or retain a normal post-accept failure. | R-003, R-010; D-005; A-014 | Unit 4; Matrix | `accepted-install-evidence` |
| `callback-install-continuity` | An external callback or publication can interleave after resolver return and before first Store install. | R-003; D-005 | Unit 4; Matrix | `two-route-callback-install-continuity-evidence` |
| `preparation-error-propagation` | A pre-callback preparation failure can be swallowed despite zero callback and no mutation. | R-010; D-005 | Unit 4; Matrix | `two-route-preparation-fail-fast-evidence` |
| `selection-delivery-failure-finality` | Selection delivery failure can roll back, retry, reinterpret accept, or mutate independent eraser state. | R-010; D-005 | Unit 4; Matrix | `selection-delivery-failure-evidence` |
| `cancel-no-effect` | Explicit cancel can leak committed, interaction, diagnostic, timestamp, or action effects. | R-002; D-005; A-015 | Unit 4; Matrix | `two-route-cancel-evidence` |
| `resolver-error-containment` | A resolver exception can escape or mutate committed or interaction state. | R-002; D-005; A-016 | Unit 4; Matrix | `two-route-error-evidence` |
| `eraser-cleanup-order` | A terminal branch or fallible listener can prevent eraser cleanup. | R-002, R-010; D-005; A-017 | Unit 4; Matrix | `eraser-cleanup-evidence` |
| `mandatory-resolver-path` | A nonempty deletion can bypass the required resolver, or an empty/rejected operation can allocate resolver state or invoke it. | R-009; D-005; A-018 | Unit 4; Matrix | `two-route-mandatory-resolver-evidence` |
| `deletion-action-compatibility` | Accepted deletion can change action types, payloads, IDs, or timestamp semantics. | R-010, R-014; D-005, D-007; A-019 | Unit 4; Matrix | `two-route-action-evidence` |
| `resolver-error-diagnostics` | Resolver failure diagnostics can be missing, duplicated, public, unbounded, or emitted for controls. | R-002, R-015; D-006; A-020 | Unit 4; Matrix | `resolver-diagnostic-evidence` |
| `durable-lifecycle-authority` | A production or semantic owner can retain stale policy, ordering, lifecycle, diagnostic, or cleanup meaning. | I-002; A-021 | Units 1-4; Matrix | `durable-authority-evidence` |
| `selection-route-budget` | Selection deletion can retain a full-handle walk or document projection outside Store. | R-008; D-004; A-022 | Unit 3; Matrix | `selection-route-work-evidence` |
| `eraser-route-budget` | Terminal eraser can retain a full-handle walk or document projection outside Store. | R-008; D-004; A-023 | Unit 3; Matrix | `eraser-route-work-evidence` |
| `resolver-cardinality` | Either public route can invoke the resolver for a no-op or more than once for a nonempty set. | R-002; D-005; A-024 | Unit 4; Matrix | `two-route-cardinality-evidence` |
| `empty-layer-retention` | Deleting a last element can implicitly remove, reorder, recreate, or mutate its layer. | R-011; D-003; A-025 | Unit 4; Matrix | `two-route-layer-retention-evidence` |
| `resource-retention` | Deleting a last reference can implicitly remove or mutate its resource descriptor. | R-011; D-003; A-026 | Unit 4; Matrix | `two-route-resource-retention-evidence` |
| `excluded-route-containment` | Resolver or deletion policies can spread into excluded command, edit, load, resource, clear, locking, or tool routes. | R-014; D-007; A-027 | Unit 4; Matrix | `excluded-route-evidence` |
| `diagnostic-graph-projection` | The new diagnostic obligation or generated views can be missing, over-broad, or stale. | I-004; D-006; A-028 | Unit 4; Matrix | `diagnostic-graph-evidence` |
| `unresolved-selection-fails-closed` | An unresolved selected ID can be ignored, removed, or classified inconsistently. | R-007; D-003, D-008; A-029 | Unit 1; Matrix | `unresolved-selection-evidence` |
| `noncontent-selection-fails-closed` | A resolved non-content selected ID can be treated as deletion-eligible. | R-007; D-003, D-008; A-030 | Unit 1; Matrix | `noncontent-selection-evidence` |
| `engine-undo-excluded` | The change can introduce engine-owned Undo state while public route behavior remains correct. | R-014; D-007 | Out of Scope; Matrix | `no-engine-undo-evidence` |
| `rollback-excluded` | The change can introduce a deletion rollback path while final outcomes remain correct. | R-003, R-014; D-005, D-007 | Out of Scope; Matrix | `no-rollback-evidence` |
| `coordinator-excluded` | The change can introduce a second deletion coordinator that duplicates existing ownership. | R-003, R-014; D-001, D-007 | Owner; Out of Scope; Matrix | `no-new-coordinator-evidence` |
| `transaction-framework-excluded` | The narrow seam can expand into a generic transaction framework. | R-003, R-014; D-001, D-007 | Owner; Out of Scope; Matrix | `no-general-transaction-framework-evidence` |
| `persistent-order-index-excluded` | Bounded ordering can be implemented by adding a second persistent order authority. | R-008, R-014; D-004, D-007 | Source of Truth; Out of Scope; Matrix | `no-persistent-order-index-evidence` |
| `compatibility-workaround-excluded` | A nullable/default resolver, omitted runtime config, V2 port, capability cast, duplicate getter, or runtime-state mirror can evade the accepted direct migration. | R-012, R-014; D-002, D-007 | Compatibility; Out of Scope; Matrix | `public-deletion-surface-evidence` |
| `mutation-work-budget` | N-dependent validation or ordering work can be displaced into sparse mutation/update/replay. | R-008; D-004; WORK_BUDGET_CLOSURE | Unit 4; Matrix | `deletion-mutation-work-evidence` |
| `install-work-budget` | Freeze/install/publication can repeat traversal or grow with unrelated N after bounded preparation. | R-003, R-008, R-010; D-005; WORK_BUDGET_CLOSURE | Unit 4; Matrix | `deletion-install-work-evidence` |
| `cleanup-work-budget` | Cancel/error/terminal cleanup can add document-wide traversal or rollback work. | R-002, R-010, R-014; D-005, D-007; WORK_BUDGET_CLOSURE | Unit 4; Matrix | `deletion-cleanup-work-evidence` |

## Repository Evidence

- `lib/src/contracts/public/canvas_runtime.dart:22` / public configuration owner: the const runtime configuration currently owns creation-time policies and has no deletion fields -> add the required non-null resolver plus the two accepted policy fields, preserving const construction and only the accepted policy defaults.
- `lib/src/api/canvas_runtime.dart:28` / public runtime construction boundary: `CanvasRuntime` currently defaults to `const CanvasRuntimeConfig()` -> make config required so the facade cannot hide a default-accept resolver, then migrate every repository config/runtime construction in the atomic public cutover.
- `lib/src/contracts/public/canvas_runtime.dart:201` / public selection port: the port currently exposes selection membership and commands but no availability -> extend the existing port directly and migrate both known implementers atomically.
- `test/api_contract/public_api_v1_compiles_as_written_test.dart:854` / direct external consumer: the repository contains the only non-runtime `CanvasSelectionPort` implementation -> it is the compile-time migration witness, not a second API owner.
- `docs/_registry/public_api_v1.yaml:1` / public export inventory: the registry explicitly owns exported-name membership while semantic signatures remain owned by the public API contract -> update both surfaces and retain parity validation without copying signatures into the registry.
- `tool/guardrails/src/public_api_checks.dart:14` / exact parity consumer: `api.public_exports_complete` compares the registry with the analyzer-resolved barrel -> all seven new public declarations must enter the inventory in their owning unit.
- `lib/src/runtime/runtime_config.dart:7` / runtime configuration materialization: public policy is copied into one runtime-owned config -> the eraser set receives exactly one unmodifiable runtime copy and no second live policy state.
- `lib/src/runtime/runtime_command_facts_adapter.dart:60` / selection deletion facts: current deletion walks document-wide handles and returns only deletable IDs -> replace this with one canonical existence/eligibility fact boundary used by availability and fresh command execution.
- `lib/src/runtime/runtime_command_facts_adapter.dart:134` / deletion predicate: current eligibility is content location plus `isDeletable` and ignores locking -> preserve that predicate and make unresolved/non-content facts fail closed.
- `lib/src/selection/selection_kernel.dart:29` / selection normalization: public selection mutations remove unresolved IDs before storage -> invalid unresolved and non-content states require fixture-owned facts at the real command-facts boundary rather than a production invalid-state path.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:325` / eraser reads: candidates and budgets are currently evaluated without a configured kind allow-list -> apply one immutable policy before both preview and terminal budget accounting.
- `lib/src/geometry/hit_test_policy.dart:165` / exact eraser routing: exact hit testing already routes every current public element kind -> the allow-list filters this existing truth and does not create a copied kind inventory.
- `lib/src/store/document_store_kernel.dart:229` / committed Store reads: Store exposes direct element, location, layer order, and token facts without a public document projection -> Store can own complete deletion-entry projection.
- `lib/src/store/document_store_kernel.dart:317` / order-token lookup: committed Store exposes ID-to-global-order-token reads -> derive canonical order and in-layer indices without a new persistent index.
- `lib/src/store/element_registry.dart:1034` / order authority: dense global tokens follow background, layer, and in-layer order -> token differences can derive source indices on one committed snapshot.
- `lib/src/edit/edit_kernel.dart:113` / interaction commit boundary: preparation and installation currently occur in one method -> resolver-enabled deletion needs a narrow prepare/consume split only when both real consumers land atomically.
- `lib/src/edit/commit_applier.dart:177` / apply-state owner: CommitApplier prepares document, selection, and delivery facts before ordered installation -> extend this owner with one deletion-only private single-use state rather than a new coordinator.
- `lib/src/store/document_store_kernel.dart:512` / materialized install: installation currently performs a base check that can fail -> deletion preparation must move every normal stale/validation check before callback.
- `lib/src/selection/selection_kernel.dart:75` / selection install: installation currently copies IDs before mutation -> deletion preparation must own the immutable backing before callback so accept has no normal copy failure.
- `lib/src/runtime/runtime_root.dart:937` / selection route: `deleteSelection` currently prepares and installs a partial deletion directly -> it is the first resolver consumer after canonical policy and projection exist.
- `lib/src/runtime/runtime_root.dart:1563` / resolver guard: the existing synchronous guard rejects nested callbacks and runtime mutation while allowing ordinary reads -> reuse it without a second guard or wider prohibition.
- `lib/src/runtime/runtime_root.dart:2721` / terminal eraser route: cleanup currently occurs after commit preparation and before common delivery, with failure cleanup in the catch path -> integrate resolver outcomes without moving cleanup ownership.
- `lib/src/runtime/runtime_action_finalizer.dart:44` / deletion action owner: existing selection and eraser intents map to their current public action types and payloads -> resolver integration changes no action surface.
- `docs/contracts/diagnostics.md:73` / diagnostic routing authority: new ordinary failure records require an admitted route with bounded facts -> add exactly the deletion-resolver exception row and no public stream.
- `lib/src/diagnostics/diagnostic_code.dart:51` / diagnostic code owner: interaction codes are centrally enumerated and tests consume `InteractionDiagnosticCode.values` -> add one code without a copied allow-list.
- `lib/src/runtime/runtime_interaction_diagnostics_adapter.dart:91` / diagnostic adapter: resolver reentrant rejection already routes bounded operation facts -> add the deletion-resolver exception method at the same owner.
- `docs/architecture/architecture_graph.yaml:400` / expected architecture graph: RuntimeRoot composition and diagnostic obligations are graph-owned -> add only the accepted RuntimeRoot-to-DiagnosticsHub obligation and regenerate its two registered projections.
- `docs/_registry/diagrams.yaml:414` / generated-view registry: the two architecture views are registered projections rather than semantic owners -> regenerate them without changing registry classification or introducing a mirror.
- `docs/verification/release_gates.md:98` / release policy: public API, architecture, ownership, diagnostics, edit, geometry, and interaction closure are release requirements -> the Verification Gate includes the established changed-owner and repository checks.
- `docs/architecture/02_package_boundaries.md:32` / package placement: public/internal contracts remain dependency-low and RuntimeRoot composes Store, Selection, Edit, Interaction, and Diagnostics owners -> all four units retain the existing dependency direction and add no graph node.
- `architecture/decisions/ADR-0017-store-transaction-candidate-and-derived-facts.md:24` / retained Store rationale: one Store order authority, prepared apply state, and RuntimeRoot orchestration remain current -> the contract extends those owners and creates no ADR lifecycle transition.

## Boundaries

Owner: `lib/src/contracts/public` owns public deletion declarations; `RuntimeConfig` owns the immutable runtime policy copy; `CommandFactsPort` with its runtime adapter owns canonical selection deletion facts; Store owns committed deletion entry projection and order; EditKernel and CommitApplier own prepared application and ordered Store/Selection installation; Selection owns selected membership/revision; InteractionEngine owns eraser preview/session cleanup; RuntimeRoot owns the two public deletion routes, resolver guard, publication, and action coordination; the runtime diagnostics adapter and DiagnosticsHub own the internal failure route; semantic docs, the public registry, and the architecture graph retain their existing distinct ownership.
In Scope: The exact three configuration fields with required non-null resolver, required `CanvasRuntime.config`, seven public declarations, direct `CanvasSelectionPort` getter extension, every repository config/runtime construction migration, runtime config copy, derived availability, partial/all-or-none selection policy, eraser kind admission, Store batch projection, deletion-only deferred install seam, guarded resolver integration for public selection delete and terminal erase, bounded internal resolver-error diagnostic, existing action compatibility, direct implementer migration, authoritative semantic documentation, public export inventory, exact graph obligation, generated graph views, and direct behavior/work/failure evidence required by R-001 through R-015 and A-001 through A-030.
Out of Scope: By R-012, R-014, and D-007, engine-owned Undo, interception of `CanvasCommandPort.removeElement`, `CanvasEdit.removeElement`, clear, import, resource operations, non-eraser tools, changed locking or general selection eligibility, changed action payloads, new coordinators, generic transaction frameworks, public prepared tokens, rollback, persistent ordering indexes, nullable/default-accept deletion resolver paths, an omitted-config `CanvasRuntime` facade, V2 ports, capability casts, duplicate availability getters, and a `CanvasRuntimeState` availability mirror are forbidden; any need for one re-enters architecture.
Source of Truth: Selection existence and eligibility are read once per operation from the canonical committed Store/Selection-backed `CommandFactsPort` surface and used directly by availability and command policy; Store tokens remain the only canonical deletion ordering/index authority; the runtime config owns the sole live eraser set copy; prepared deletion state is private single-use execution state rather than durable truth; `docs/contracts/public_api_v1.md` owns signatures while `docs/_registry/public_api_v1.yaml` owns export membership; `docs/architecture/architecture_graph.yaml` owns expected graph obligations and generated views remain projections. No cache, intent marker, copied inventory, policy duplicate, or sync bridge is added.
Compatibility: The required resolver, required runtime config, and direct selection-port extension are accepted source-breaking API changes because no external-user compatibility path is required; every repository config/runtime construction, including maintained `example/` sample, performance, and test consumers, every runtime implementation, and every direct external compile consumer migrates atomically, while the public contract and release gate record the exact requiredness and migration. Existing selection-policy and eraser-kind defaults, delete/erase action types, payload shapes, IDs, timestamp rules, document/resource formats, schemas, persisted values, and unrelated public APIs remain unchanged. No nullable/default-accept resolver or omitted-config facade coexists.
Order Constraints: Units 1 and 2 are independent. Unit 3 consumes Unit 1 canonical selection facts while migrating both current ordering routes. Unit 4 consumes Units 1, 2, and 3 and atomically lands the complete required public resolver/config surface, every repository construction migration, both public deletion consumers, the private prepare/consume seam, diagnostics, graph, cleanup ordering, and all route-local and cross-route evidence. Because Unit 4 is intentionally larger than the other units, implementation must pass through reviewable checkpoints on one unmerged change: first the shared public/private contracts, required-config call-site migration, prepared-install boundary, guard, and diagnostic plumbing with their focused evidence; then the selection route with its route-local evidence; then terminal eraser routing and cleanup with its route-local evidence; finally cross-route, public-surface, documentation, graph, and lifecycle closure. Mechanical config/runtime call-site migration must be reported separately from authored semantic changes during the first checkpoint, and the maintained `example/` migration must be reported as its own sub-checkpoint with its package compile/analyze/test evidence rather than hidden in the root call-site count. These checkpoints are implementation-control boundaries, not independently acceptable contract units: none may be merged, released, or marked complete before the entire Unit 4 surface and evidence close together. Within each unit and checkpoint, direct evidence and authoritative documentation land with behavior; source truth and guardrails precede dependent consumers; preparation precedes callback; callback decision precedes install; accepted Store install precedes Selection install; eraser cleanup precedes fallible state/action delivery; lifecycle closure follows implementation evidence.
Temporal Surface Closure: The required resolver is called synchronously exactly once only for a final nonempty set after all expected failures have been exhausted; no nonempty deletion has a direct-install bypass. Reads and client-owned Undo work remain permitted in the callback, while public runtime mutation/edit/tool calls, disposal, and nested resolvers are rejected without effects. Accept consumes the prepared state in the same uninterrupted stack; cancel and callback exception discard it; empty and policy-rejected sets return before request/deferred-state construction or callback. Terminal eraser cleanup covers empty, rejected, preparation-failed, accepted, cancelled, resolver-failed, and delivery-failed branches before fallible publication; selection deletion never changes independent eraser interaction state.
All-Or-Nothing Failure Boundary: Before callback, document, selection, validation, stale, normalization, request, revision, and action inputs are complete. After accept, a private token is consumable once and installs prepared document then prepared selection with no normal failure or public observation between them; VM-fatal allocation conditions are excluded. Cancel and ordinary resolver exceptions produce no document, selection, revision, timestamp, or action mutation; exceptions do not escape and only the approved bounded diagnostic is recorded. No rollback mechanism is introduced.
Negative Proof And Fixture Quarantine: Unresolved and resolved-non-content selected-ID witnesses enter only through fixture-owned Selection facts supplied to the real runtime command-facts adapter over a real committed Store snapshot. The fixture owns neither predicates nor location classification, never mutates SelectionKernel internals, adds no public invalid-state path, and remains isolated from production facts and contracts. Other negative proofs use real public/owner boundaries; no copied route inventory, private-name scanner, or prose parser becomes evidence authority.
Bounded Recognition Scope: No production analyzer, scanner, token heuristic, JSONPath recognizer, or generated-output recognizer is added. Existing AST/public-export, documentation, and architecture graph checkers retain their current bounded inputs and owners; invalid selection recognition is fixture-local construction, not a production recognizer.
Work Budget And Cost Displacement: Construction permits one O(m) copy of an m-kind eraser set per runtime and one O(k) request-entry copy for every final nonempty deletion; empty and policy-rejected operations create neither request nor deferred state. Query/read applies eraser kind admission before candidate/exact counters, derives selection facts without a whole-document projection, and projects k final removals from direct Store facts in O(k) reads, O(k) canonical ordering, or O(k log k) arbitrary ordering independent of unrelated N; the two complete routes perform zero full-handle ordering passes and zero `CanvasDocument` projections. Mutation/update/replay retains existing touched sparse preparation and forbids displacing N-dependent ordering or validation work into edit replay. Freeze/publication/install prepares selection backing and delivery inputs before callback, performs one Store then Selection install after accept, and emits no intermediate publication or duplicate traversal. Cleanup/rollback discards private prepared references and performs owner-local eraser cleanup without document-wide work; rollback traversal and persistent index maintenance are prohibited. Import/reset are unaffected because R-014 excludes those routes, so they gain no deletion policy, callback, projection, or displaced work.

## Execution Units

### [x] Unit 1: Establish canonical selection deletion policy and derived availability

Owner: Public runtime contracts, RuntimeConfig, CommandFactsPort/runtime adapter, RuntimeRoot selection port, public API registry/contract, release migration surface, and selection/API verification owners.
Boundary: Add only `CanvasSelectionDeletePolicy`, `CanvasSelectionDeleteAvailability`, the defaulted selection-policy config field, and the direct `CanvasSelectionPort.deleteAvailability` extension; keep availability derived and absent from runtime state; make availability and command execution consume the same fresh committed facts; quarantine invalid facts in owner-level fixtures; update the public owners changed by this independently useful resolver-free behavior.
Verification Profile: `BEHAVIOR_CHANGE`
Change: Selection deletion supports `partial` and `allOrNone` from one canonical eligibility boundary, clients can read current whole-selection availability, and the direct port migration is complete while current partial behavior remains the default.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `selection-policy-public-surface` | The public port lacks availability and runtime configuration lacks a selection deletion policy. | A direct consumer constructs default and explicit policy configurations and implements the extended selection port. | The accepted enum, value DTO, config field/default, getter, exports, signatures, migration note, runtime implementation, and external compile consumer agree. | The constructor remains const; default is `partial`; availability has value equality; no V2/capability/duplicate/runtime-state alternative exists; no unrelated public surface retires. |
| `derived-selection-availability` | Current committed document and selection facts can change independently. | A client reads availability, changes selection and document through public routes, observes existing revisions, and reads again. | Empty selection yields both fields false; nonempty values reflect the latest committed snapshot after either change. | Availability is absent from `CanvasRuntimeState`, owns no notification/cache lifecycle, and uses existing revision publication. |
| `canonical-selection-policy` | Empty, eligible, mixed-deletability, and locked selections exist under both policies. | The client reads availability, optionally changes facts, then calls delete without passing the prior value back. | Availability and execution use the same content-plus-`isDeletable` predicate; `partial` produces only eligible IDs; `allOrNone` produces all selected IDs only when all are eligible; locking is irrelevant. | Execution re-reads current facts before mandatory resolver admission; empty/rejected results never invoke it; no full `CanvasDocument` is materialized; last-element deletion retains layer/resource ownership semantics. |
| `unresolved-selection-facts` | Fixture-owned Selection facts contain eligible IDs plus an ID absent from the same committed Store snapshot. | The real runtime command-facts adapter supplies availability and both policy consumers. | Availability reports a nonempty not-fully-deletable selection, `allOrNone` removes none, and `partial` includes only independently resolved eligible IDs. | Invalid values and construction stay fixture-local; production predicates and location rules are not copied or bypassed. |
| `noncontent-selection-facts` | Fixture-owned Selection facts contain eligible content plus a Store-resolved non-content ID marked element-deletable. | The real runtime command-facts adapter supplies availability and both policy consumers. | The non-content ID is non-deletable, `allOrNone` removes none, and `partial` includes only eligible content. | The real Store location fact is used; public selection normalization and SelectionKernel internals are not modified to manufacture the state. |

Depends On: None

### [x] Unit 2: Apply eraser kind policy before preview and terminal budgets

Owner: Public/runtime configuration, runtime interaction read adapter, existing eraser hit policy, public API and geometry contract owners, eraser budget diagram, and geometry/runtime verification owners.
Boundary: Add only `eraserElementKinds`, make one runtime-owned unmodifiable copy, and filter preview and terminal candidates with identical null/empty/allow-list semantics before candidate and exact-check accounting; expose the filtered terminal final-read result as Unit 4 input without depending on the not-yet-created resolver request; do not duplicate `CanvasElementKind` or change exact hit routing.
Verification Profile: `BEHAVIOR_CHANGE`
Change: Eraser preview and terminal removal admit only configured element kinds before spending either work budget while null preserves unrestricted legacy behavior and empty disables erasure.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `runtime-owned-eraser-policy` | A caller supplies null, empty, or mutable nonempty kind sets. | A runtime is created and the caller mutates its original set afterward. | Runtime behavior preserves distinct null, empty, and exact allow-list semantics for its lifetime. | One unmodifiable runtime-owned copy is created; no caller alias or second policy state is consulted. |
| `eraser-policy-before-budgets` | Mixed-kind candidates surround candidate and exact-check limits in preview and terminal reads. | Preview and terminal reads run under null, empty, and explicit allow-lists. | Disallowed kinds appear in neither preview nor the terminal final-read output and consume neither budget; allowed kinds retain existing exact-hit semantics. | Preview and terminal use one policy; this unit constructs no resolver request; `CanvasElementKind` remains the sole kind truth. |

Depends On: None

### [x] Unit 3: Move deletion entry projection and both ordering routes to Store

Owner: DocumentStoreKernel and element-order facts, CommandFactsPort/runtime selection adapter, runtime terminal eraser ordering route, Store/data-order documentation, and Store plus end-to-end work verification owners.
Boundary: Add one Store-owned batch projection from final IDs to immutable element/layer/original-index/order facts on one snapshot; migrate the current selection and terminal eraser ordering consumers immediately; remove or bypass their O(N) full-handle scans without adding a persistent index or materializing `CanvasDocument`.
Verification Profile: `BEHAVIOR_CHANGE`
Change: Both current deletion routes obtain canonical complete pre-mutation entry facts from Store in O(k) for canonical IDs or O(k log k) for arbitrary IDs, independent of unrelated document size.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `canonical-deletion-entries` | Final removal IDs are interleaved across multiple layers and may arrive canonical or permuted. | Store batch projection and both current ordering consumers run before mutation. | Every projected element appears once with its exact immutable element reference, source layer, original in-layer index, and document-layer/in-layer order. | One committed snapshot supplies all facts; this unit proves the Store projection and current consumers, not the not-yet-created public callback request; no post-removal positions, duplicate order authority, public projection, or persistent index exists. |
| `store-projection-work-bounds` | k removal IDs and unrelated N document elements scale independently. | Store projects canonical and permuted IDs while stable fact-read/comparison counters observe work. | Canonical inputs use linear reads/order work, arbitrary inputs remain within comparison-sort growth, and fixed-k work is N-independent. | Wall-clock timing and helper-name assertions are rejected; counters observe stable Store fact/order seams. |
| `selection-route-work-bounds` | Public selection delete begins from canonical selected-ID facts. | The complete route reaches callback-entry facts with k and unrelated N scaled separately. | It performs O(k) canonical or O(k log k) arbitrary work, zero full-frame-handle ordering walks, and zero `CanvasDocument` projections. | Stable route and Store counters cover work outside as well as inside projection; policy remains from Unit 1. |
| `eraser-route-work-bounds` | Terminal eraser has final exact-hit IDs. | The complete ordering route reaches callback-entry facts with k and unrelated N scaled separately. | It performs O(k) canonical or O(k log k) arbitrary work, zero full-handle ordering walks, and zero `CanvasDocument` projections. | Existing exact-hit order is preserved; stable route counters detect any pre/post-Store pass. |
| `single-persistent-order-authority` | Existing dense Store order tokens own committed canonical order. | Bounded deletion projection is added and both routes consume it. | No second persistent order index, cache lifecycle, synchronization path, or schema field is introduced. | Store tokens remain the sole durable authority; private transient sorting of k input IDs is allowed. |

Depends On:
- Unit 1 — produces: canonical selection existence, eligibility, and final policy IDs; consumed as: Store projection input for the selection deletion route.

### [x] Unit 4: Cut over both public deletion routes to the resolver atomically

Owner: Public deletion contracts and registry, RuntimeConfig, RuntimeRoot selection and terminal eraser coordination plus resolver guard, EditKernel, CommitApplier, Store and Selection installers, existing InteractionEngine cleanup owner, runtime diagnostics adapter, DiagnosticsHub code/contract, action finalizer, maintained `example/` sample/performance/test consumers, architecture graph/generated views, public/edit/runtime/diagnostic and eraser lifecycle documentation/diagrams, and their nearest route-local and cross-route verification owners.
Boundary: Land the required non-null resolver configuration, required `CanvasRuntime.config`, and five public resolver/request/entry/decision/operation declarations simultaneously with every repository config/runtime construction—including all maintained `example/` consumers—and both accepted public deletion consumers; introduce only the deletion-specific private prepare/single-use consume seam; complete all expected failures before either callback; reuse the existing guard; contain callback errors through the admitted diagnostic route; guarantee terminal cleanup before fallible delivery; remove the direct-install bypass; migrate graph, direct public consumers, example package, and all route-local and cross-route evidence atomically. Execute this atomic unit through the mandatory shared-spine, selection-route, eraser-route, and final-cross-route checkpoints defined by Order Constraints, reviewing focused behavior and evidence at each checkpoint while keeping the whole unit unmerged until final closure.
Verification Profile: `BEHAVIOR_CHANGE`
Change: Public selection deletion and terminal eraser each present every complete nonempty Store-projected final set to the required resolver before mutation, safely accept or veto it as one unit through existing owners, preserve terminal cleanup ordering, and provide no nullable, default-accept, omitted-config, or direct-install compatibility path.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `deletion-resolver-public-surface` | The selection policy surface exists but resolver declarations/configuration do not, `CanvasRuntimeConfig` and `CanvasRuntime` still permit omitted resolver/config construction, and nine maintained example config/runtime constructions require migration—seven of them currently omit config. | Runtime, maintained example, and all repository/external compile consumers adopt the complete accepted deletion API. | Required non-null `deletionCommitResolver`, required `CanvasRuntime.config`, operation, decision, resolver, request, entry, and exact remaining fields/defaults/exports/docs are present with no extras; every repository construction compiles explicitly; the example package analyzes and its tests pass. | Request and entry use identity equality; config remains const; omitted/null resolver and omitted runtime config fail at the type boundary; example behavior uses an explicit accepted resolver policy rather than a hidden fallback; source-breaking getter migration from Unit 1 remains closed; no nullable/default-accept or parallel alternative appears. |
| `eraser-resolver-request-policy` | Unit 2 supplies a mixed-kind terminal final-read output under an explicit allow-list. | The real terminal eraser route prepares its public resolver request. | Request IDs and entries are exactly the Unit 2-filtered terminal output in the same accepted order; disallowed kinds never reappear. | RuntimeRoot consumes the filtered owner result directly; it does not rebuild admission from unfiltered candidates or duplicate the policy. |
| `deletion-request-immutability` | A mutable iterable contains entries holding immutable public element references. | A public request is constructed, the input mutates, and exposed-list mutation is attempted. | Request order/content remain unchanged, the list rejects mutation, and each exact element identity is retained. | One O(k) defensive copy occurs for every final nonempty deletion. |
| `selection-resolver-decision` | Selection policy produces a final nonempty Store-projected set. | Runtime invokes the required resolver under the existing guard and receives accept, cancel, or an ordinary exception. | Accept installs the whole prepared set; cancel installs none; exception does not escape and installs none. | Exactly one callback occurs; no engine Undo/rollback/public token or direct-install bypass exists; selection delete leaves independent eraser interaction state unchanged. |
| `selection-preparation-before-callback` | Each admitted document, selection, stale, validation, normalization, request, revision, and action-input failure can be injected at its owner. | Selection deletion prepares an operation for the required resolver. | Every expected failure occurs before resolver entry, with zero callbacks and unchanged committed effects. | No normal failure remains between accept and first owner installation; VM-fatal conditions are excluded. |
| `selection-preparation-fail-fast` | Each admitted ordinary preparation failure is injected before selection resolver entry. | Public selection deletion runs. | The same owner error propagates synchronously to the caller while resolver count remains zero and committed/interaction/action/timestamp state is unchanged. | The error is not translated into cancel, swallowed, or routed as a resolver diagnostic; VM-fatal conditions are excluded. |
| `single-use-atomic-install` | A complete prepared deletion state exists before callback. | Resolver accepts and the private state is consumed. | Document installs once, then prepared selection installs once, with no public observation or normal failure between them; second consumption is rejected without mutation. | Selection backing and delivery inputs are prepared before callback; no rollback or new coordinator is introduced. |
| `selection-callback-install-continuity` | Resolver is about to return accept with a complete prepared selection deletion. | Callback returns and runtime begins installation in the same synchronous call. | First Store install follows without any external callback, listener, microtask delivery, or public publication between resolver return and install. | Resolver return, first install, Store-to-Selection order, and publication are observed as one temporal trace; no asynchronous handoff is introduced. |
| `selection-resolver-guard` | A selection resolver is executing. | It performs representative runtime reads/client Undo work and attempts every public mutation/edit/tool family, disposal, and nested resolver entry. | Reads/client work succeed; every forbidden operation is rejected with unchanged document, selection, revisions, timestamps, actions, interaction, and lifecycle state. | Existing guard remains the only guard; rejection itself does not publish state or action. |
| `selection-resolver-cancel` | A nonempty selection deletion is fully prepared. | Resolver returns cancel. | Document, selection, revisions, timestamp, actions, diagnostics, and independent eraser state are unchanged. | Prepared state is discarded; cancel is distinct from error and records no diagnostic. |
| `selection-resolver-error` | A nonempty selection deletion is fully prepared. | Resolver throws a representative ordinary synchronous error. | The error is absorbed, committed/action/timestamp/interaction state remains unchanged, and the caller sees no exception. | Exactly one bounded diagnostic is handled separately; VM-fatal failures are excluded. |
| `selection-action-compatibility` | Selection deletion is accepted through the required resolver. | Runtime finalizes the committed action. | Existing `deleteElements` type and payload contain the installed IDs in accepted order with unchanged timestamp semantics. | No new deletion action or payload field is introduced; final state and action IDs agree. |
| `selection-post-install-delivery-failure` | Resolver accepts selection deletion and a state/action listener fails after both owner installs. | Runtime performs fallible external delivery. | Accepted document and selection remain installed, resolver count remains one, accept is not retried or reinterpreted, and independent eraser interaction state remains unchanged. | Delivery failure follows existing propagation semantics and cannot roll back, re-enter the resolver, or publish a compensating deletion state/action. |
| `selection-layer-retention` | Selection deletion targets the sole eligible element in background-adjacent and ordinary content layers. | Resolver accepts selection deletion. | Each emptied layer retains its identity, order, and metadata. | No explicit layer-removal operation runs; element absence or layer count alone is not the oracle. |
| `selection-resource-retention` | Selection deletion targets the sole image or vector reference to a resource descriptor. | Resolver accepts selection deletion and the resource catalog is read afterward. | Each descriptor remains unchanged and still requires explicit remove-unused-resource for deletion. | Callback entries, action IDs, and reference counts do not substitute for catalog observation. |
| `selection-excluded-route-containment` | Representative excluded command/edit removal, clear, import, resource, locking/general selection, and non-eraser routes are available with all new configuration enabled. | Each independently routed public family runs. | Existing committed and interaction effects remain and resolver count is zero. | No copied route inventory or private-name scan is admitted; selection resolver behavior is authoritative only on public selection deletion. |
| `selection-resolver-diagnostic` | Diagnostics are enabled or disabled and selection resolver accepts, cancels, fails preparation, or throws. | The real resolver and runtime diagnostics adapter execute. | Only ordinary resolver exception records exactly one internal interaction error with bounded operation/error-kind facts; controls record none; disabled mode retains/allocates no record. | No element, document, request, runtime object, or public diagnostic surface is exposed. |
| `diagnostic-architecture-route` | Existing graph obligations and registered generated views are current. | The exact RuntimeRoot-to-DiagnosticsHub deletion-resolver obligation is added and views are regenerated. | Graph closure recognizes only that new obligation and both named generated outputs match it. | Existing general obligations and registry classification remain unchanged; generated output never becomes semantic authority. |
| `deletion-mutation-work-bounds` | Fixed k deletion inputs are embedded in documents with increasing unrelated N. | Selection deletion performs validation, sparse mutation/update, and replay preparation before callback. | Stable owner counters show no N-dependent validation, ordering, element replay, or full-owner traversal beyond the source-authorized touched sparse work. | Correct final state is insufficient; counters cover the mutation/replay owners and exclude work already counted by Store projection. |
| `deletion-install-work-bounds` | A prepared accepted deletion with fixed k is installed while unrelated N scales. | The token freezes/consumes, Store and Selection install, and publication inputs are traversed. | Stable counters show one consume, one Store install, one Selection install, no duplicate list/owner pass, and N-independent install/publication work. | DCM metrics and final state are rejected; direct owner traversal/publication counters must kill duplicate or displaced passes. |
| `no-engine-undo-surface` | The runtime has no engine-owned deletion Undo lifecycle. | Public deletion interception is implemented. | No public or internal engine-owned Undo state, history command, or synchronization surface is added. | Client-owned Undo work inside the callback remains permitted; absence of engine ownership is distinct from cancel behavior. |
| `no-deletion-rollback-mechanism` | Complete preparation makes normal post-accept failure unnecessary. | The private accepted deletion seam is implemented. | No compensating Store/Selection mutation or replay path is added. | VM-fatal conditions remain outside the guarantee; ordinary failure is exhausted before callback. |
| `existing-owner-deletion-coordination` | RuntimeRoot, EditKernel/CommitApplier, Store, Selection, InteractionEngine, and DiagnosticsHub already own the required responsibilities. | Resolver behavior is integrated. | No second deletion coordinator or duplicated orchestration lifecycle appears. | Existing graph nodes and dependency direction remain; file decomposition inside an owner remains open. |
| `deletion-only-private-seam` | Only public selection deletion and terminal eraser require deferred acceptance. | The private prepare/consume capability is added. | The seam remains deletion-only, private, single-use, and has exactly the two accepted route consumers. | No reusable public or generic transaction abstraction is introduced. |
| `two-route-deletion-outcome` | Public selection and terminal eraser operations produce accepted, cancelled, empty, and policy-rejected sets under the required resolver configuration. | Both routes run through a real runtime. | Each nonempty route exposes the complete final set before mutation and accepts or vetoes it as one unit; empty/rejected routes do not call; existing owners install accepted work. | No engine Undo, rollback, public token, new coordinator, nullable/default resolver, or direct-install route bypass exists. |
| `two-route-callback-entry-correctness` | Both routes produce interleaved multi-layer final IDs from a known committed pre-mutation Store snapshot. | Each real public resolver callback receives its request. | Every callback entry exactly matches the Store projection's element identity, source layer, original in-layer index, and canonical order for that same snapshot. | Neither route rebuilds entries from post-mutation state, copied route facts, or a second ordering authority; Unit 3 Store correctness is consumed rather than extrapolated. |
| `two-route-resolver-guard` | Either deletion callback is active. | Representative reads/client Undo work and every forbidden public family, disposal, and nested resolver are attempted. | Allowed work succeeds and every forbidden route rejects without committed, interaction, stream, timestamp, or lifecycle effects. | Both real callback entrypoints use the existing guard; family coverage is not inferred from one command. |
| `two-route-preparation-before-callback` | Every admitted preparation failure is injectable for both deletion routes. | Each route prepares a deletion for the required resolver. | Failure yields zero resolver calls and no committed effects; terminal eraser also completes cleanup. | No expected failure or public observation remains between accept and first install. |
| `two-route-preparation-fail-fast` | Each admitted ordinary preparation failure is injected for each deletion route. | Public selection deletion or terminal eraser runs. | The same owner error propagates synchronously with zero resolver calls and unchanged committed/action/timestamp state; terminal eraser also completes cleanup. | Preparation failure is not swallowed, converted into cancel, or recorded as resolver failure; VM-fatal conditions are excluded. |
| `two-route-callback-install-continuity` | Either deletion resolver is about to return accept with complete prepared state. | Callback returns and the corresponding route begins Store installation. | No external callback, listener, microtask delivery, or public publication occurs before first Store install on either route. | The trace spans the real callback boundary through first install and then preserves Store-to-Selection order; selection-only evidence cannot stand for eraser. |
| `two-route-cancel-no-effect` | Both routes have nonempty prepared deletions. | Resolver cancels each route. | Neither route changes document, selection, revisions, timestamps, actions, or diagnostics; terminal eraser cleans preview/session and selection deletion leaves independent eraser state unchanged. | Prepared state is discarded exactly once and no delivery is emitted. |
| `two-route-error-no-effect` | Both routes have nonempty prepared deletions. | Resolver throws from each route. | Errors do not escape; committed/action/timestamp state is unchanged; terminal eraser cleans and selection deletion leaves independent eraser state unchanged. | Exactly one bounded diagnostic per thrown callback is observed separately; VM-fatal conditions are excluded. |
| `two-route-resolver-diagnostic` | Diagnostics are enabled or disabled and each public route accepts, cancels, fails preparation, or throws an ordinary callback error. | The real routes and runtime diagnostics adapter execute. | Only an ordinary thrown callback emits exactly one internal bounded record with operation and error-kind facts on each route; accept, cancel, preparation failure, and disabled mode emit or retain none. | Diagnostic containment is independent of the no-mutation oracle; no element, document, request, runtime object, or public diagnostic surface is exposed. |
| `eraser-cleanup-before-delivery` | Empty, policy-rejected, preparation-failed, accepted, cancelled, resolver-failed, and post-install delivery-failed terminal branches are available. | Terminal eraser completes each branch, including injected state/action listener failure. | Preview/session cleanup always completes before fallible external delivery, with the correct committed outcome for the branch. | InteractionEngine remains the sole cleanup owner; no test-only cleanup path or second owner is introduced. |
| `two-route-mandatory-resolver-path` | Required configuration is supplied and both routes produce nonempty, empty, invalid, and policy-rejected final sets. | Each public deletion operation runs. | Every nonempty set constructs one request/deferred state and invokes the resolver exactly once; empty/invalid/rejected sets construct neither and invoke it zero times. | Omitted/null resolver and omitted runtime config fail at the public type boundary; no default-accept or direct-install bypass exists. |
| `two-route-action-compatibility` | Both deletion routes accept through the required resolver. | Existing action finalization and public streams run. | Delete/erase action types, payload shapes, final IDs, and timestamp behavior match current contracts. | State precedes action; no new action type or callback-derived payload is exposed. |
| `two-route-resolver-cardinality` | Empty, invalid, rejected, accept, cancel, and throwing operations exist for both routes. | Each public operation runs one at a time. | Resolver count is zero for empty/invalid/rejected and exactly one for every nonempty accept/cancel/error operation. | Count observes the required public resolver boundary, not a private helper; no retry occurs. |
| `two-route-layer-retention` | Each route removes the sole eligible element from background-adjacent and ordinary content layers. | Accepted deletion installs. | Empty layer identity, order, and metadata remain unchanged. | No explicit layer-removal operation runs; layer count alone is not the oracle. |
| `two-route-resource-retention` | Each route removes the sole image and vector reference. | Accepted deletion installs and resources are read afterward. | Resource descriptors remain unchanged and still require the explicit remove-unused-resource operation for deletion. | Callback entries/action IDs do not substitute for catalog observation; no implicit resource effect is reported. |
| `excluded-route-containment` | All new fields are enabled and representative direct command/edit removal, clear, import, resource, locking/general selection, and non-eraser tool routes are available. | Each excluded public family runs. | Current committed and interaction behavior remains and resolver count stays zero. | No copied route inventory or private-name scanner is admitted; each independently routed family is exercised at its public owner. |
| `durable-deletion-authority` | All I-002 production owners and maintained semantic docs/diagrams exist in the resulting repository. | Their public, owner, work, temporal, diagnostic, invalid-facts, and cleanup observations are compared with D-001 through D-006. | No owner retains partial-only, unfiltered, O(N), direct-commit, fallible-post-accept, unguarded diagnostic, duplicated-availability, or implicit-cleanup semantics. | Every named semantic owner is updated with its behavior unit; prose is inspected directly but never parsed as product proof. |
| `deletion-cleanup-work-bounds` | Fixed k cancel/error and every terminal cleanup branch run while unrelated document size N scales. | Prepared state is discarded or eraser cleanup completes, including delivery failure. | Stable prepared-state/cleanup counters remain N-independent, perform no document traversal, rollback replay, or duplicate cleanup pass, and preserve the correct route outcome. | DCM metrics, elapsed time, or final cleanup state alone are rejected; direct owner counters distinguish discard, cleanup, and delivery work. |

Depends On:
- Unit 1 — produces: final canonical selection policy facts and direct availability/port migration; consumed as: the selection resolver's final removal set and existing public selection surface.
- Unit 2 — produces: the final eraser kind policy and pre-budget preview/terminal set; consumed as: the only IDs eligible for terminal resolver preparation.
- Unit 3 — produces: Store-owned complete canonical deletion entries and bounded ordering for both routes; consumed as: both pre-mutation callback requests.

## Verification Matrix

| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | Pass signal | Evidence constraints and rejected proxy | Adversarial false-positive case and kill signal | Durable impact | Artifact target | Admission |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `selection-public-surface-evidence` | `selection-policy-public-surface` | `BUILD_OR_COMPILE` | Existing direct public API compile, export-parity, signature, equality, and runtime implementation owners | Getter, enum, DTO, and config policy are absent and the external implementer lacks the getter. | Exact selection surface compiles with default/explicit usage, both implementers compile, export registry and semantic contract agree, and forbidden alternatives are absent. | Compile and analyzer-resolved exports are admissible; inventory-only or migration-note-only proof is rejected. | Registry and docs are updated but one direct implementer lacks the getter; direct external compile fails and kills the false positive. | `EXTEND_COVERAGE` | `test/api_contract/public_api_v1_compiles_as_written_test.dart` and existing public API owner suites | `selection-public-surface-admission` |
| `derived-availability-evidence` | `derived-selection-availability` | `TEST` | Public selection port and runtime state/revision behavior owner | No public availability exists. | Reads change after independent selection/document revisions and runtime state has no availability member or extra notification. | Public reads and state shape are admissible; DTO-only construction is rejected. | A cached getter updates on selection but not document changes; the document-revision witness kills it. | `EXTEND_COVERAGE` | `test/api/selection_port_test.dart` and runtime state publication owner suite | `derived-availability-admission` |
| `canonical-selection-facts-evidence` | `canonical-selection-policy` | `TEST` | Real RuntimeCommandFactsAdapter plus public getter/delete routes | Current facts expose only partial deletable IDs and execution has no all-or-none option. | Empty/eligible/mixed/locked and stale-client-value cases yield the accepted getter and both policy results from one fresh snapshot. | Real adapter/public consumers are admissible; copied predicate tests are rejected. | Getter and command use equivalent-looking separate predicates that diverge after a fact change; stale-read-then-delete kills it. | `EXTEND_COVERAGE` | `test/runtime/command_facts_port_test.dart` and `test/api/selection_transform_commands_test.dart` | `canonical-selection-facts-admission` |
| `direct-port-migration-evidence` | `selection-policy-public-surface` | `BUILD_OR_COMPILE` | Runtime implementation, direct external `CanvasSelectionPort` implementation, public contract, and release gate | The accepted direct getter extension is absent. | Both implementations compile against one extended interface, migration note and accepted policy defaults are present, and no parallel port/getter/state mirror exists. | Direct compile plus authoritative docs is admissible; source absence or prose alone is rejected. | Runtime compiles via a capability cast while external implementation remains old; direct interface compile and forbidden-surface inspection kill it. | `EXTEND_COVERAGE` | `test/api_contract/public_api_v1_compiles_as_written_test.dart` and `docs/verification/release_gates.md` | `direct-port-migration-admission` |
| `unresolved-selection-evidence` | `unresolved-selection-facts` | `TEST` | Real command-facts adapter with fixture-owned controlled Selection facts and real Store | Public setup normalizes unresolved IDs away, leaving this failure unproved. | Unresolved ID makes availability non-fully-deletable, blocks all-or-none, and never enters partial removal. | Controlled fixture input is admissible; production invalid path, SelectionKernel mutation, or copied predicate is rejected. | Fixture silently drops the unresolved ID before the real adapter; availability incorrectly becomes fully deletable, killing the false positive. | `EXTEND_COVERAGE` | Runtime command-facts owner-scoped fixture family; placement implementation-owned | `unresolved-selection-admission` |
| `noncontent-selection-evidence` | `noncontent-selection-facts` | `TEST` | Real command-facts adapter with fixture-owned Selection facts and committed non-content Store fact | Public setup normalizes non-content IDs away, leaving location fail-closed behavior unproved. | Resolved non-content ID is non-deletable for availability and both policies. | Real Store location facts are admissible; unresolved-ID substitution or copied location classification is rejected. | Fixture converts non-content to unresolved and still passes; the explicit resolved-location assertion kills it. | `EXTEND_COVERAGE` | Runtime command-facts owner-scoped fixture family; placement implementation-owned | `noncontent-selection-admission` |
| `eraser-config-copy-evidence` | `runtime-owned-eraser-policy` | `TEST` | RuntimeConfig materialization plus live eraser behavior | No eraser set exists. | Null/empty/nonempty remain distinct and later caller mutation cannot change runtime behavior or mutate stored policy. | Behavior after source mutation is admissible; constructor text or nominal wrapper type is rejected. | Runtime stores an unmodifiable view of caller backing; mutating the caller changes erasing and kills the false positive. | `EXTEND_COVERAGE` | `test/runtime/runtime_config_materialization_test.dart` and geometry eraser owner suite | `eraser-config-copy-admission` |
| `eraser-prebudget-evidence` | `eraser-policy-before-budgets` | `TEST` | Existing preview/terminal eraser read boundary with stable candidate/exact counters and terminal final-read output | Every deletable kind currently consumes budgets and can be erased. | Null/empty/allow-list behavior matches in preview/terminal, disallowed candidates consume zero candidate/exact work and never enter the terminal final-read output. | Stable budget counters and direct read outputs are admissible; resolver requests, removed-ID-only, or wall-clock proof are rejected as Unit 2 authority. | Filtering occurs after candidate counting but final IDs look correct; near-limit counters fail and kill it. | `EXTEND_COVERAGE` | `test/geometry/eraser_exact_budget_inputs_test.dart` and terminal eraser read owner suite | `eraser-prebudget-admission` |
| `store-entry-projection-evidence` | `canonical-deletion-entries` | `TEST` | Store batch projection plus both real current ordering consumers | Current routes expose only ordered IDs and use full-handle ordering. | Interleaved multi-layer inputs yield exact Store-projected element identities, layers, original indices, and order before mutation. | Direct Store facts on the same snapshot are admissible; future callback requests, action order, or copied expected construction are rejected as Unit 3 authority. | Projection order is right but indices are recomputed after an earlier removal; pre-mutation Store index comparison kills it. | `EXTEND_COVERAGE` | Store projection and current runtime ordering-consumer owner-scoped fixture families; placement implementation-owned | `store-entry-projection-admission` |
| `store-projection-work-evidence` | `store-projection-work-bounds` | `TEST` | Store-owned deterministic fact-read and comparison counters | No batch projection exists and current ordering scans N handles. | Canonical k is linear, arbitrary k is bounded by k-log-k comparison growth, and fixed-k work is unchanged as unrelated N grows. | Stable owner counters are admissible; timing and fixed-k/N-only proof are rejected. | Implementation always sorts canonical input; canonical-k comparison growth kills it. | `EXTEND_COVERAGE` | `test/store/no_projection_hot_path_test.dart` or cohesive Store projection work owner | `store-projection-work-admission` |
| `selection-route-work-evidence` | `selection-route-work-bounds` | `TEST` | Complete public selection-delete read-to-entry route counters | Current route walks all frame handles. | Zero full-handle iterations/projections and accepted k/N growth hold end to end. | Route plus Store counters are admissible; Store-local counters alone are rejected. | Store is bounded but command facts retain an O(N) pass; route handle counter kills it. | `EXTEND_COVERAGE` | Runtime selection deletion owner-scoped work fixture family; placement implementation-owned | `selection-route-work-admission` |
| `eraser-route-work-evidence` | `eraser-route-work-bounds` | `TEST` | Complete final-hit-to-entry eraser route counters | Current eraser ordering helper scans supplied document handles. | Zero full-handle iterations/projections and accepted k/N growth hold end to end. | Route plus Store counters are admissible; final entries or Store-only work are rejected. | Runtime reorders Store output with an O(N) helper; route handle counter kills it. | `EXTEND_COVERAGE` | Terminal eraser owner-scoped work fixture family; placement implementation-owned | `eraser-route-work-admission` |
| `public-deletion-surface-evidence` | `selection-policy-public-surface`, `deletion-resolver-public-surface` | `BUILD_OR_COMPILE` | Complete public compile/export/signature/requiredness/default/docs surface, every repository `CanvasRuntimeConfig`/`CanvasRuntime` construction, and the maintained example package after Unit 4 | All accepted deletion declarations are absent, current config/runtime construction permits omission, and nine example constructions require migration. | Every exact field, enum member, required constructor argument, remaining default, equality class, barrel export, registry entry, repository construction, direct implementer, semantic signature, and migration note agrees with R-004/R-012/R-013; omitted/null resolver and omitted runtime config fail compilation; `example/` analyzes and its tests pass with explicit resolver/config construction. | Analyzer-resolved compile/export, negative compile witnesses, all repository constructions, `cd example && flutter analyze`, `cd example && flutter test`, and owner docs are admissible; any single inventory, root-only compile, wording token, or declaration-presence proxy is rejected. | Root names export and positive fixtures compile, but an example performance replacement still calls `CanvasRuntime()`; example analysis kills it. | `EXTEND_COVERAGE` | Existing public API compile/signature/export/equality owners, repository compilation, example package CI surface, and release gate | `public-deletion-surface-admission` |
| `eraser-resolver-request-policy-evidence` | `eraser-resolver-request-policy` | `TEST` | Real terminal eraser route from Unit 2 final-read output through Unit 3 projection into the public resolver request | No resolver request exists before Unit 4. | Mixed-kind request IDs and exact entries equal the already-filtered terminal final-read set and contain no disallowed kind. | Direct Unit 2 output, same-operation Store projection, and real callback request are admissible; Unit 2 reads alone or removed IDs are rejected. | Unit 2 filters correctly but RuntimeRoot rebuilds the request from unfiltered candidates; request parity kills it. | `EXTEND_COVERAGE` | Terminal eraser resolver-route owner-scoped fixture family; placement implementation-owned | `eraser-resolver-request-policy-admission` |
| `request-immutability-evidence` | `deletion-request-immutability` | `TEST` | Public DTO behavior through the exported surface | Deletion request and entries do not exist. | Source iterable mutation cannot alter request, exposed mutation fails, order and exact element identities persist. | Runtime DTO behavior is admissible; source shape or collection type is rejected. | Request wraps caller list with an unmodifiable view; post-construction caller mutation kills it. | `EXTEND_COVERAGE` | `test/api_contract/dto_immutability_test.dart` | `request-immutability-admission` |
| `deletion-equality-evidence` | `selection-policy-public-surface`, `deletion-resolver-public-surface` | `TEST` | Exported public equality policy owner | New types do not exist. | Request/entry instances remain identity-distinct; availability equal/unequal pairs and hash collections behave consistently. | Runtime equality and hash behavior is admissible; method-presence text is rejected. | Availability overrides equality but not compatible hashCode; hash-set witness kills it. | `EXTEND_COVERAGE` | `test/api_contract/public_equality_policy_test.dart` | `deletion-equality-admission` |
| `selection-resolver-decision-evidence` | `selection-resolver-decision` | `TEST` | Real public selection deletion route through Store/Edit/Selection owners | Selection deletion installs directly without callback. | Accept installs the complete set; cancel/error install none; callback count is one; no engine Undo surface exists. | Full public route/state observation is admissible; DTO or private helper tests are rejected. | Resolver helper works but public route bypasses it; public callback count remains zero and kills it. | `EXTEND_COVERAGE` | Selection deletion resolver owner-scoped runtime fixture family; placement implementation-owned | `selection-resolver-decision-admission` |
| `selection-preparation-evidence` | `selection-preparation-before-callback` | `TEST` | Selection route owner-boundary injected preparation failures | Current route has no callback window. | Every admitted failure yields zero callbacks and unchanged committed effects before resolver. | Each real owner seam is admissible; one synthetic catch-all failure is rejected. | Request construction remains fallible after callback but other injections pass; request-boundary witness kills it. | `EXTEND_COVERAGE` | Selection deletion resolver owner-scoped runtime fixture family; placement implementation-owned | `selection-preparation-admission` |
| `selection-preparation-fail-fast-evidence` | `selection-preparation-fail-fast` | `TEST` | Public selection route with each real owner preparation failure | Current route has no resolver boundary against which propagation can be preserved. | The injected owner error is observed synchronously by the caller with zero resolver calls and exact no-effect state. | Error identity/type plus public no-effect observation is admissible; callback count and unchanged state without propagation are rejected. | Runtime catches the failure and returns as a no-op; caller non-throw assertion fails and kills it. | `EXTEND_COVERAGE` | Selection deletion resolver owner-scoped fail-fast fixture family; placement implementation-owned | `selection-preparation-fail-fast-admission` |
| `accepted-install-evidence` | `single-use-atomic-install` | `TEST` | CommitApplier/Store/Selection install and publication event boundaries | Current prepared install can fail selection after Store and has no single-use token. | Exactly one Store then Selection install occurs, second consume rejects without mutation, and no normal failure/publication exists between installs. | Stable owner/publication events and failure seams are admissible; final-state equality is rejected. | Final state is correct but selection throws normally after Store in an injected case; owner failure witness kills it. | `EXTEND_COVERAGE` | `test/edit/selection_effect_commit_test.dart` and deletion prepared-install owner family | `accepted-install-admission` |
| `selection-callback-install-continuity-evidence` | `selection-callback-install-continuity` | `TEST` | Temporal trace from real selection resolver return through first Store install | No resolver-to-install interval exists in current code. | Resolver-return is immediately followed by first Store install with zero intervening callback, listener, microtask delivery, or publication events. | Stable public callback/owner/publication events are admissible; Store-to-Selection-only tracing or final state is rejected. | Runtime schedules a listener after resolver return and before Store install while final state remains correct; intervening-event trace kills it. | `EXTEND_COVERAGE` | Selection deletion resolver temporal owner-scoped fixture family; placement implementation-owned | `selection-callback-install-continuity-admission` |
| `selection-guard-evidence` | `selection-resolver-guard` | `TEST` | Real selection callback over public facade families and lifecycle state | Existing resource resolver guard is not exercised by deletion. | Allowed reads/client work succeed; all mutation/edit/tool/dispose/nested families reject with exact no-effect observations. | Public facade calls and before/after state are admissible; one command or thrown-error-only proof is rejected. | Guard rejects one family after partial side effect; complete state/action/lifecycle comparison kills it. | `EXTEND_COVERAGE` | Existing resolver reentrancy owner plus deletion selection route coverage | `selection-guard-admission` |
| `selection-cancel-evidence` | `selection-resolver-cancel` | `TEST` | Public selection route complete snapshot/action/diagnostic observation | No cancel branch exists. | Cancel changes no committed or independent eraser state and emits no timestamp/action/diagnostic. | Complete public/internal admitted observations are required; document equality alone is rejected. | Document stays equal but selection revision or timestamp advances; full snapshot kills it. | `EXTEND_COVERAGE` | Selection deletion resolver owner-scoped runtime fixture family; placement implementation-owned | `selection-cancel-admission` |
| `selection-error-evidence` | `selection-resolver-error` | `TEST` | Public selection route exception containment observation | No deletion resolver exception branch exists. | Ordinary callback error does not escape or change committed/action/timestamp/interaction state. | Outcome evidence is independent of diagnostic evidence; diagnostic presence alone is rejected. | Error is logged but rethrown; caller non-throw assertion kills it. | `EXTEND_COVERAGE` | Selection deletion resolver owner-scoped runtime fixture family; placement implementation-owned | `selection-error-admission` |
| `selection-action-evidence` | `selection-action-compatibility` | `TEST` | Real action finalizer and public action stream | Current selection delete emits existing action only on direct commit. | Resolver-accepted deletion emits the same type, payload IDs, and timestamp behavior as installed state. | Real finalizer/stream is admissible; final document or declaration inspection is rejected. | Installed state is correct but callback entry IDs leak into a changed action order; stream comparison kills it. | `EXTEND_COVERAGE` | `test/interaction/commands_emit_user_actions_test.dart` and typed action owner | `selection-action-admission` |
| `selection-delivery-failure-evidence` | `selection-post-install-delivery-failure` | `TEST` | Accepted public selection route with injected post-install state/action listener failure | No resolver-accepted selection delivery failure path exists. | Document and selection remain accepted, eraser state is unchanged, resolver count stays one, and no retry, rollback, reinterpretation, or compensating delivery occurs. | Owner installs, resolver count, eraser state, and actual listener failure behavior are admissible; successful delivery or final document alone is rejected. | Listener failure triggers rollback or a second resolver call while final document later looks correct; retained-state/cardinality trace kills it. | `EXTEND_COVERAGE` | Selection deletion resolver delivery-failure fixture family; placement implementation-owned | `selection-delivery-failure-admission` |
| `selection-layer-retention-evidence` | `selection-layer-retention` | `TEST` | Public selection route plus committed document and Store layer facts | Current selection deletion has no resolver-aware empty-layer retention proof. | Sole-element deletion retains exact layer identity, order, and metadata in both relevant layer positions. | Full layer facts are admissible; element absence or layer count is rejected. | Runtime removes and recreates an equivalent-looking layer; identity/order/metadata comparison kills it. | `EXTEND_COVERAGE` | Selection deletion resolver owner-scoped layer-retention fixture family; placement implementation-owned | `selection-layer-retention-admission` |
| `selection-resource-retention-evidence` | `selection-resource-retention` | `TEST` | Public selection route plus resource catalog and explicit remove-unused-resource operation | Current selection deletion has no resolver-aware descriptor-retention proof. | Sole image/vector reference deletion retains the unchanged descriptor and explicit removal remains necessary. | Catalog values and explicit operation are admissible; action IDs, callback entries, or reference counts are rejected. | Descriptor is removed while element/action results look correct; catalog read kills it. | `EXTEND_COVERAGE` | Selection deletion resolver owner-scoped resource-retention fixture family; placement implementation-owned | `selection-resource-retention-admission` |
| `selection-excluded-route-evidence` | `selection-excluded-route-containment` | `TEST` | Representative real public operation from each excluded routing family after Unit 4 | New resolver configuration does not exist before implementation. | Every excluded family preserves current effects and records zero resolver calls. | Per-family public behavior is admissible; source search, copied inventory, or one representative for all families is rejected. | Direct removal remains clean but import or resource operations invoke the resolver indirectly; per-family callback count kills it. | `EXTEND_COVERAGE` | Selection deletion resolver owner-scoped excluded-route fixture families; placement implementation-owned | `selection-excluded-route-admission` |
| `selection-diagnostic-evidence` | `selection-resolver-diagnostic` | `TEST` | Real selection resolver, runtime diagnostics adapter, DiagnosticsHub, and public surface | No dedicated deletion failure code/route exists. | Throw records exactly one bounded internal error; cancel/preparation controls record zero; disabled mode allocates/retains none; public surface stays unchanged. | Real adapter/hub and bounded record are admissible; code-enum presence or log text is rejected. | Code exists and a record appears, but it includes request data or duplicates; cardinality/redaction assertions kill it. | `EXTEND_COVERAGE` | `test/diagnostics/interaction_diagnostics_test.dart` plus selection resolver route coverage | `selection-diagnostic-admission` |
| `diagnostic-graph-evidence` | `diagnostic-architecture-route` | `STRUCTURED_DATA_CHECK` | Expected architecture graph, current closure checker, and generated-view consistency | No deletion-resolver diagnostic obligation exists. | Exact new obligation is present, existing general obligations are unchanged, and both named generated views match the graph. | Graph source plus mechanical closure is admissible; generated output alone or prose inspection alone is rejected. | Views regenerate from an over-broad or wrong-owner edge and look consistent; exact obligation inspection kills it. | `UPDATE_EXISTING` | `docs/architecture/architecture_graph.yaml` and its two registered generated views | None |
| `no-engine-undo-evidence` | `no-engine-undo-surface` | `MANUAL_INSPECTION` | Public contracts, RuntimeConfig/RuntimeRoot state owners, and changed deletion owner diff | Engine-owned Undo is explicitly excluded but current route tests cannot detect unused internal Undo state. | No public or internal engine-owned Undo state, history lifecycle, command, or synchronization surface is introduced in the affected owners. | Bounded inspection of changed public/state/route owners is admissible; excluded-route behavior alone or broad repository token search is rejected. | An unused deletion Undo stack is added while every route test passes; changed-owner state inspection kills it. | `NONE` | None | None |
| `no-rollback-evidence` | `no-deletion-rollback-mechanism` | `MANUAL_INSPECTION` | Changed EditKernel, CommitApplier, Store, Selection, and RuntimeRoot deletion seams | Rollback is explicitly excluded and can remain invisible on successful outcomes. | The accepted design is implemented by complete pre-callback preparation and no-normal-failure install, with no compensating mutation/replay path. | Bounded owner-flow inspection plus atomic evidence is admissible; successful final state or private-name search is rejected. | A compensating Store/Selection replay path is added but never triggered by happy-path tests; owner control-flow inspection kills it. | `NONE` | None | None |
| `no-new-coordinator-evidence` | `existing-owner-deletion-coordination` | `MANUAL_INSPECTION` | Package ownership, architecture graph, and changed composition owners | A second deletion coordinator is forbidden but could delegate correctly enough for behavior tests to pass. | Existing RuntimeRoot, EditKernel/CommitApplier, Store, Selection, InteractionEngine, and DiagnosticsHub responsibilities remain; no new owner or duplicated orchestration lifecycle appears. | Bounded ownership/graph/diff inspection is admissible; file-count or symbol-name heuristics are rejected. | A new coordinator duplicates prepared state and delegates final effects correctly; ownership/graph inspection kills it. | `NONE` | None | None |
| `no-general-transaction-framework-evidence` | `deletion-only-private-seam` | `MANUAL_INSPECTION` | Changed public/internal contracts and edit/runtime owners | A generic transaction framework can wrap the narrow seam without breaking behavior. | The new capability remains deletion-only, private, single-use, and consumed only by the two accepted routes. | Bounded type/consumer/owner inspection is admissible; helper naming or test pass status alone is rejected. | A reusable public/general transaction abstraction is introduced with only two current consumers; scope/consumer inspection kills it. | `NONE` | None | None |
| `no-persistent-order-index-evidence` | `single-persistent-order-authority` | `MANUAL_INSPECTION` | Store order owners, committed state schema, construction/update/install paths, and changed architecture/data-model surfaces | A second persistent index can keep all performance tests green. | Existing dense Store order tokens remain the sole persistent order authority and no new maintained index, cache lifecycle, synchronization, or schema field is added. | Bounded Store state/lifecycle and authoritative docs inspection is admissible; performance counters or broad token searches are rejected. | A new persistent ID-to-rank map supplies bounded projection while tokens remain; state/lifecycle inspection kills it. | `NONE` | None | None |
| `deletion-mutation-work-evidence` | `deletion-mutation-work-bounds` | `TEST` | Stable sparse validation/mutation/update/replay owner counters with fixed k and scaling unrelated N | Current deletion ordering includes N-dependent route work and no resolver preparation phase exists. | Fixed-k mutation/replay counts remain N-independent with no full-owner validation/order/replay pass beyond touched sparse work. | Direct owner phase counters are admissible; DCM metrics, final state, timing, or projection counters are rejected. | Projection is bounded but EditSession replays all N elements during preparation; replay counter kills it. | `EXTEND_COVERAGE` | Deletion sparse mutation/replay work owner-scoped fixture family; placement implementation-owned | `deletion-mutation-work-admission` |
| `deletion-install-work-evidence` | `deletion-install-work-bounds` | `TEST` | Stable prepared-state freeze/consume, owner-install, list traversal, and publication-input counters | Current route has no deferred install phase to measure. | One consume/Store install/Selection install occurs, traversal counts scale with k only, and fixed-k work is unchanged as unrelated N grows. | Direct phase counters are admissible; DCM metrics, final state, or event ordering without work counts is rejected. | Installation order is correct but publication rebuilds all N document elements or traverses entries twice; phase counter kills it. | `EXTEND_COVERAGE` | Deletion prepared-install work owner-scoped fixture family; placement implementation-owned | `deletion-install-work-admission` |
| `two-route-deletion-outcome-evidence` | `two-route-deletion-outcome` | `TEST` | Both real public routes through the required resolver and existing commit owners | Neither route currently supports deletion interception. | Accept/cancel/empty/rejected cases for both routes exhibit complete-set pre-mutation veto and exact committed outcomes. | Public routes and complete effects are admissible; DTO/helper tests are rejected. | Selection is wired but eraser bypasses resolver; eraser callback-count witness kills it. | `EXTEND_COVERAGE` | Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned | `two-route-outcome-admission` |
| `two-route-callback-entry-evidence` | `two-route-callback-entry-correctness` | `TEST` | Both real public callback requests compared with Unit 3 Store projection facts from the same pre-mutation snapshot | Unit 3 can project facts but no public deletion callback request exists. | Both request lists exactly match Store element identities, layers, original indices, and canonical order for interleaved multi-layer inputs. | Same-operation Store facts and real callback requests are admissible; Unit 3 projection alone, one route, action IDs, or copied expected DTOs are rejected. | Store projection is correct but eraser rebuilds indices after an earlier removal; same-snapshot callback comparison kills it. | `EXTEND_COVERAGE` | Cross-route deletion callback-entry owner-scoped fixture family; placement implementation-owned | `two-route-callback-entry-admission` |
| `two-route-guard-evidence` | `two-route-resolver-guard` | `TEST` | Both callback entrypoints over public read/mutation/edit/tool/dispose/nested families | Neither deletion callback currently exists. | Each family has the same allow/reject/no-effect result from both callbacks. | Public family calls and full state are admissible; single-route extrapolation is rejected. | Eraser callback forgets the guard for disposal while selection passes; eraser lifecycle witness kills it. | `EXTEND_COVERAGE` | Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned | `two-route-guard-admission` |
| `two-route-preparation-evidence` | `two-route-preparation-before-callback` | `TEST` | Owner failure injection on both route preparations | Terminal eraser currently prepares and installs directly. | Every failure family is pre-callback on both routes; eraser cleanup completes and callback count stays zero. | Per-owner injection is admissible; selection-only or one synthetic failure is rejected. | Eraser action-input failure remains after callback while selection passes; eraser-specific injection kills it. | `EXTEND_COVERAGE` | Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned | `two-route-preparation-admission` |
| `two-route-preparation-fail-fast-evidence` | `two-route-preparation-fail-fast` | `TEST` | Both public routes with each real owner preparation failure | Neither route has a resolver boundary against which propagation can be preserved. | The injected owner error propagates synchronously on both routes with zero callbacks/no mutation and terminal eraser cleanup. | Error identity/type plus route-specific no-effect/cleanup observation is admissible; timing-only proof is rejected. | Eraser catches the preparation error as a silent cancel while selection propagates; caller error witness kills it. | `EXTEND_COVERAGE` | Cross-route deletion preparation fail-fast fixture family; placement implementation-owned | `two-route-preparation-fail-fast-admission` |
| `two-route-callback-install-continuity-evidence` | `two-route-callback-install-continuity` | `TEST` | Temporal traces from each real resolver return through first Store install | Neither route currently has a resolver-to-install interval. | Both routes contain zero intervening callback/listener/microtask/publication event before first install and preserve Store-to-Selection order. | Real callback/owner/publication traces are admissible; single-route or Store-to-Selection-only evidence is rejected. | Eraser schedules cleanup/publication between resolver return and Store install while final state passes; route trace kills it. | `EXTEND_COVERAGE` | Cross-route deletion callback-install temporal fixture family; placement implementation-owned | `two-route-callback-install-continuity-admission` |
| `two-route-cancel-evidence` | `two-route-cancel-no-effect` | `TEST` | Complete state/revision/action/diagnostic/interaction snapshots for both routes | Neither route currently has a resolver cancel branch. | Both cancel branches have exact no-effect semantics with route-specific cleanup/isolation. | Complete observations are admissible; document equality or single-route proof is rejected. | Eraser cancels document but leaks preview session; interaction snapshot kills it. | `EXTEND_COVERAGE` | Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned | `two-route-cancel-admission` |
| `two-route-error-evidence` | `two-route-error-no-effect` | `TEST` | Both public callbacks throwing ordinary errors | Neither route currently has resolver error containment. | Both errors are absorbed with exact no-mutation and route-specific cleanup/isolation. | Outcome and diagnostic evidence remain separate; logs are rejected. | Eraser logs and cleans but advances timestamp; full snapshot kills it. | `EXTEND_COVERAGE` | Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned | `two-route-error-admission` |
| `eraser-cleanup-evidence` | `eraser-cleanup-before-delivery` | `TEST` | Existing eraser lifecycle and common delivery temporal events across every terminal branch | Current resolver branches do not exist. | Cleanup is observed for every branch and before injected fallible state/action delivery; committed outcome remains correct. | Stable cleanup/delivery boundaries are admissible; success-only or second cleanup owner is rejected. | Accepted success passes but listener failure prevents cleanup; injected delivery failure kills it. | `EXTEND_COVERAGE` | `test/interaction/eraser_context_action_routing_test.dart` and runtime delivery owner | `eraser-cleanup-admission` |
| `two-route-mandatory-resolver-evidence` | `two-route-mandatory-resolver-path` | `TEST` | Required public config boundary, both public routes, request/deferred construction seam, resolver cardinality, and committed effects | Both current nonempty routes install directly and public construction permits omitted config/resolver. | Omitted/null resolver and omitted runtime config fail compilation; each nonempty route constructs exactly one request/deferred state and invokes once; empty/invalid/rejected cases construct none and invoke zero times. | Real public construction, callbacks, stable construction counters, and complete effects are admissible; a non-null field declaration, final state alone, private helper count, or broad heap profiling is rejected. | Selection uses the resolver but eraser direct-installs, or empty eraser eagerly constructs state without invoking; route-specific callback/construction/effect witnesses kill both false positives. | `EXTEND_COVERAGE` | Public API compile owner plus cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned | `two-route-mandatory-resolver-admission` |
| `two-route-action-evidence` | `two-route-action-compatibility` | `TEST` | Real action finalizer/public stream for both required resolver routes | Neither current route has resolver-aware action compatibility coverage. | Existing delete/erase types, payloads, final IDs, timestamp, and state-before-action order remain exact. | Real stream/finalizer is admissible; final state or declaration inspection is rejected. | Eraser emits correct final state but a new action type; stream type assertion kills it. | `EXTEND_COVERAGE` | `test/interaction/commands_emit_user_actions_test.dart`, typed action, and runtime delivery owners | `two-route-action-admission` |
| `resolver-diagnostic-evidence` | `two-route-resolver-diagnostic` | `TEST` | Both real resolver routes, diagnostics adapter/hub, accept/cancel/preparation controls, disabled mode, and public non-export | No deletion-resolver diagnostic route currently exists. | Exactly one bounded record appears per thrown callback on both routes, controls remain silent, disabled mode allocates/retains none, and no public surface appears. | Real routes/hub/public barrel are admissible; no-mutation outcome, enum presence, or copied expected records are rejected as diagnostic proof. | Selection diagnostic is correct but eraser records twice or leaks entries; eraser cardinality/redaction kills it. | `EXTEND_COVERAGE` | `test/diagnostics/interaction_diagnostics_test.dart` plus cross-route deletion coverage | `resolver-diagnostic-admission` |
| `two-route-cardinality-evidence` | `two-route-resolver-cardinality` | `TEST` | Configured public resolver boundary correlated to individual operations | No deletion callback exists initially. | Zero calls for empty/invalid/rejected and exactly one for nonempty accept/cancel/error on both routes. | Public configured boundary is admissible; private helper count or final state is rejected. | Duplicate callbacks return the same decision and final state remains correct; count kills it. | `EXTEND_COVERAGE` | Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned | `two-route-cardinality-admission` |
| `two-route-layer-retention-evidence` | `two-route-layer-retention` | `TEST` | Public committed document plus Store layer facts after both accepted routes | Existing deletion retention is not covered under both resolver routes. | Layer identity, order, and metadata remain after sole-element removal from both layer positions/routes. | Full layer facts are admissible; element absence/layer count is rejected. | Layer is removed and recreated identically enough for count; identity/order metadata witness kills it. | `EXTEND_COVERAGE` | Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned | `two-route-layer-retention-admission` |
| `two-route-resource-retention-evidence` | `two-route-resource-retention` | `TEST` | Public resource catalog plus explicit remove-unused-resource operation after both routes | Existing resource retention is not covered under both resolver routes. | Image/vector descriptors remain unchanged and explicit removal remains necessary. | Catalog values and explicit operation are admissible; reference counts/action payloads are rejected. | Descriptor is silently removed while action IDs look correct; catalog read kills it. | `EXTEND_COVERAGE` | Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned | `two-route-resource-retention-admission` |
| `excluded-route-evidence` | `excluded-route-containment` | `TEST` | Representative real public operation from each excluded routing family | New configuration/resolver surfaces do not exist. | Every excluded family records zero resolver calls and preserves existing committed/interaction effects. | Public route evidence is admissible; source-symbol search, copied inventory, or one representative for all families is rejected. | Direct command removal stays clean but import or resource path invokes shared resolver indirectly; per-family witness kills it. | `EXTEND_COVERAGE` | Cross-route/excluded-route owner-scoped fixture families; placement implementation-owned | `excluded-route-admission` |
| `durable-authority-evidence` | `durable-deletion-authority` | `MANUAL_INSPECTION` | Every exact I-002 production and semantic target, paired with its nearest direct behavior/work evidence | Current owners describe or implement partial-only, unfiltered, O(N), and direct-commit behavior. | All named targets agree with D-001 through D-006 and each semantic claim is backed by its direct Matrix owner. | Direct target inspection is admissible for documentation agreement; prose parsing or a duplicate checklist is rejected. | Behavior tests pass but one maintained diagram still shows direct irreversible commit; exact target inspection kills it. | `UPDATE_EXISTING` | Exact I-002 semantic owners and diagrams | None |
| `deletion-cleanup-work-evidence` | `deletion-cleanup-work-bounds` | `TEST` | Stable prepared-state discard, eraser cleanup, rollback-replay, and delivery-phase counters with fixed k and scaling unrelated N | Resolver cancel/error branches do not exist and cleanup work has no N-scaling proof. | Discard/cleanup counts remain N-independent, rollback replay count is zero, each branch cleans once, and delivery failure adds no document traversal. | Direct cleanup/discard/rollback counters are admissible; DCM metrics, timing, or final cleanup state is rejected. | Cancel looks correct but walks all N elements to reconstruct state or delivery failure repeats cleanup; counters kill it. | `EXTEND_COVERAGE` | Deletion cleanup/discard work owner-scoped fixture family; placement implementation-owned | `deletion-cleanup-work-admission` |

## Permanent Artifact Admissions

### `selection-public-surface-admission`: Selection policy and availability public surface

Covers: `selection-policy-public-surface`
Impact: `EXTEND_COVERAGE`
Failure family: direct public selection policy/availability declarations or implementers can be incomplete
Failure mode or stable invariant: one exact exported selection policy and derived availability surface compiles for runtime and an external port implementer with the accepted policy defaults
Verification owner: public API compile, signature, export, and equality suites
Current verification gap: none of the accepted selection policy, availability, config, or getter surfaces exists
Failing witness: a direct consumer cannot compile code that reads availability or chooses all-or-none
Durable and refactor-stable value: exported signatures and external implementation compatibility survive internal runtime refactors
Artifact target: `test/api_contract/public_api_v1_compiles_as_written_test.dart` and existing public API owner suites

### `derived-availability-admission`: Derived delete availability lifecycle

Covers: `derived-selection-availability`
Impact: `EXTEND_COVERAGE`
Failure family: availability can be stale or duplicated outside existing document/selection revisions
Failure mode or stable invariant: every read derives from current committed facts and no runtime-state/cache lifecycle is added
Verification owner: public selection port and runtime-state publication suites
Current verification gap: no availability value exists
Failing witness: the public getter cannot be exercised before implementation
Durable and refactor-stable value: derived-state behavior survives private fact representation changes
Artifact target: `test/api/selection_port_test.dart` and runtime state publication owner suite

### `canonical-selection-facts-admission`: Shared selection deletion facts and policies

Covers: `canonical-selection-policy`
Impact: `EXTEND_COVERAGE`
Failure family: availability and execution can disagree or apply stale/locked/partial policy incorrectly
Failure mode or stable invariant: getter and immediate execution consume one fresh content-plus-deletable fact authority for both policies
Verification owner: runtime command-facts and public selection command suites
Current verification gap: current facts expose only ordered deletable IDs and partial deletion
Failing witness: all-or-none and stale-read-then-delete outcomes are absent
Durable and refactor-stable value: behavior is anchored to public and facts boundaries rather than helper shape
Artifact target: `test/runtime/command_facts_port_test.dart` and `test/api/selection_transform_commands_test.dart`

### `direct-port-migration-admission`: Direct CanvasSelectionPort migration

Covers: `selection-policy-public-surface`
Impact: `EXTEND_COVERAGE`
Failure family: source-breaking getter extension can leave a direct implementer or release state incompatible
Failure mode or stable invariant: runtime and external implementations compile against one port with no compatibility workaround
Verification owner: public API compile/release owner
Current verification gap: the direct getter extension is absent
Failing witness: current external consumer has no delete-availability implementation
Durable and refactor-stable value: direct interface compatibility survives runtime implementation changes
Artifact target: `test/api_contract/public_api_v1_compiles_as_written_test.dart` and `docs/verification/release_gates.md`

### `unresolved-selection-admission`: Unresolved selected ID fails closed

Covers: `unresolved-selection-facts`
Impact: `EXTEND_COVERAGE`
Failure family: unresolved selected IDs can be ignored or treated as eligible
Failure mode or stable invariant: unresolved membership makes whole selection ineligible and never enters removal
Verification owner: runtime command-facts owner with quarantined fixture input
Current verification gap: public selection normalization removes the invalid state before the real boundary
Failing witness: no current public setup can retain an unresolved selected ID
Durable and refactor-stable value: owner-boundary fail-closed behavior survives public normalization and private adapter refactors
Artifact target: Runtime command-facts owner-scoped fixture family; placement implementation-owned

### `noncontent-selection-admission`: Resolved non-content selected ID fails closed

Covers: `noncontent-selection-facts`
Impact: `EXTEND_COVERAGE`
Failure family: Store-resolved background/non-content selected facts can be treated as deletable content
Failure mode or stable invariant: content location participates in the canonical eligibility decision for availability and both policies
Verification owner: runtime command-facts owner with quarantined fixture input
Current verification gap: public selection normalization prevents the state
Failing witness: no current proof distinguishes resolved non-content from unresolved selection facts
Durable and refactor-stable value: direct location-fact behavior survives predicate/helper refactors
Artifact target: Runtime command-facts owner-scoped fixture family; placement implementation-owned

### `eraser-config-copy-admission`: Runtime-owned eraser policy copy

Covers: `runtime-owned-eraser-policy`
Impact: `EXTEND_COVERAGE`
Failure family: live eraser behavior can alias caller-owned mutable configuration
Failure mode or stable invariant: one runtime-owned unmodifiable copy preserves null, empty, and nonempty policy for runtime lifetime
Verification owner: runtime configuration materialization suite
Current verification gap: no eraser-kind configuration exists
Failing witness: current config cannot accept or freeze a kind set
Durable and refactor-stable value: ownership behavior survives private storage changes
Artifact target: `test/runtime/runtime_config_materialization_test.dart` and geometry eraser owner suite

### `eraser-prebudget-admission`: Eraser kind admission before work budgets

Covers: `eraser-policy-before-budgets`
Impact: `EXTEND_COVERAGE`
Failure family: disallowed kinds can consume candidate/exact work or diverge between preview and terminal
Failure mode or stable invariant: one policy filters both reads before both budget counters
Verification owner: geometry eraser exact-budget and terminal route suites
Current verification gap: no kind policy exists and all candidates spend budget
Failing witness: an empty or restricted set cannot prevent current candidate accounting
Durable and refactor-stable value: work/admission behavior survives exact-hit implementation changes
Artifact target: `test/geometry/eraser_exact_budget_inputs_test.dart` and terminal eraser read owner suite

### `eraser-resolver-request-policy-admission`: Filtered eraser set reaches the resolver unchanged

Covers: `eraser-resolver-request-policy`
Impact: `EXTEND_COVERAGE`
Failure family: the terminal resolver route can rebuild or bypass Unit 2 kind admission
Failure mode or stable invariant: the real terminal callback request equals the filtered terminal final-read output
Verification owner: terminal eraser resolver route
Current verification gap: Unit 2 has no resolver request and Unit 4 does not exist
Failing witness: a correct filtered read can still feed an unfiltered RuntimeRoot request
Durable and refactor-stable value: route parity survives helper and request-construction refactors
Artifact target: Terminal eraser resolver-route owner-scoped fixture family; placement implementation-owned

### `store-entry-projection-admission`: Canonical complete Store deletion facts

Covers: `canonical-deletion-entries`
Impact: `EXTEND_COVERAGE`
Failure family: Store projection can produce wrong element, layer, index, or order
Failure mode or stable invariant: Store and both current ordering consumers use complete pre-mutation facts from one committed snapshot
Verification owner: Store projection and current runtime ordering consumers
Current verification gap: only ordered removal IDs exist
Failing witness: current Store surface cannot construct complete deletion entry facts
Durable and refactor-stable value: owner facts survive sorting/helper and future callback refactors
Artifact target: Store projection and current runtime ordering-consumer owner-scoped fixture families; placement implementation-owned

### `store-projection-work-admission`: Store projection complexity

Covers: `store-projection-work-bounds`
Impact: `EXTEND_COVERAGE`
Failure family: deletion entry projection can scan unrelated N or sort already canonical IDs
Failure mode or stable invariant: O(k) canonical and O(k log k) arbitrary projection with fixed-k N independence
Verification owner: Store fact/order work suite
Current verification gap: no batch projection or direct counter proof exists
Failing witness: current route uses an O(N) full-handle ordering scan
Durable and refactor-stable value: stable owner counters protect complexity across algorithm refactors
Artifact target: `test/store/no_projection_hot_path_test.dart` or cohesive Store projection work owner

### `selection-route-work-admission`: End-to-end selection ordering budget

Covers: `selection-route-work-bounds`
Impact: `EXTEND_COVERAGE`
Failure family: selection route can retain N-dependent work outside bounded Store projection
Failure mode or stable invariant: read-to-entry route performs zero full-handle/projection work and preserves k bounds
Verification owner: runtime selection deletion route work suite
Current verification gap: current command facts walk all frame handles
Failing witness: fixed-k work grows with unrelated document elements
Durable and refactor-stable value: end-to-end counters survive movement of private helpers
Artifact target: Runtime selection deletion owner-scoped work fixture family; placement implementation-owned

### `eraser-route-work-admission`: End-to-end eraser ordering budget

Covers: `eraser-route-work-bounds`
Impact: `EXTEND_COVERAGE`
Failure family: terminal eraser can retain N-dependent ordering around Store projection
Failure mode or stable invariant: final-hit-to-entry route performs zero full-handle/projection work and preserves k bounds
Verification owner: terminal eraser route work suite
Current verification gap: current ordering helper scans supplied document handles
Failing witness: fixed-k work grows with unrelated document elements
Durable and refactor-stable value: end-to-end counters survive private route refactors
Artifact target: Terminal eraser owner-scoped work fixture family; placement implementation-owned

### `public-deletion-surface-admission`: Complete deletion public API

Covers: `selection-policy-public-surface`, `deletion-resolver-public-surface`
Impact: `EXTEND_COVERAGE`
Failure family: the exact accepted deletion declarations, required constructor arguments, remaining defaults, root/example constructions, exports, and docs can diverge
Failure mode or stable invariant: one compiled/exported documented API matches R-004, R-012, and R-013 exactly, every root and maintained example construction supplies the resolver/config, the example package analyzes/tests, and omitted/null construction fails
Verification owner: public API compile, repository compile, example package CI, signature, export, equality, and migration suites
Current verification gap: all deletion-specific declarations are absent and current config/runtime construction permits omission
Failing witness: current consumer cannot name the accepted deletion resolver types and seven maintained example `CanvasRuntime()` calls still compile only because configuration is optional
Durable and refactor-stable value: public compatibility remains protected across internal reorganization
Artifact target: Existing public API compile/signature/export/equality owners, repository compilation, example package CI surface, and release gate

### `request-immutability-admission`: Deletion request defensive copy

Covers: `deletion-request-immutability`
Impact: `EXTEND_COVERAGE`
Failure family: callback request entries can alias mutable caller input
Failure mode or stable invariant: request owns one unmodifiable list while retaining exact element references
Verification owner: public DTO immutability suite
Current verification gap: request and entry DTOs do not exist
Failing witness: current public API cannot construct the request
Durable and refactor-stable value: observable immutability survives constructor/storage refactors
Artifact target: `test/api_contract/dto_immutability_test.dart`

### `deletion-equality-admission`: Deletion DTO equality policy

Covers: `selection-policy-public-surface`, `deletion-resolver-public-surface`
Impact: `EXTEND_COVERAGE`
Failure family: identity/value equality and hash behavior can contradict the public contract
Failure mode or stable invariant: request/entry use identity and availability uses consistent value equality/hash
Verification owner: public equality policy suite
Current verification gap: none of the new equality-bearing types exists
Failing witness: current suite cannot instantiate them
Durable and refactor-stable value: exported equality semantics survive private field implementation changes
Artifact target: `test/api_contract/public_equality_policy_test.dart`

### `selection-resolver-decision-admission`: Selection resolver decisions

Covers: `selection-resolver-decision`
Impact: `EXTEND_COVERAGE`
Failure family: public selection deletion can bypass resolver or apply the wrong whole-set decision
Failure mode or stable invariant: one callback accepts all or cancel/error installs none through existing owners
Verification owner: selection deletion runtime route suite
Current verification gap: no selection deletion resolver exists
Failing witness: current route installs directly
Durable and refactor-stable value: public route outcome survives helper and prepared-state refactors
Artifact target: Selection deletion resolver owner-scoped runtime fixture family; placement implementation-owned

### `selection-preparation-admission`: Selection preparation before callback

Covers: `selection-preparation-before-callback`
Impact: `EXTEND_COVERAGE`
Failure family: an expected selection deletion failure can occur after client Undo is recorded
Failure mode or stable invariant: every admitted normal failure occurs before callback
Verification owner: selection deletion runtime/edit owner failure suite
Current verification gap: no callback boundary exists
Failing witness: current prepare-and-install method cannot expose the required ordering
Durable and refactor-stable value: owner-boundary injections survive private implementation changes
Artifact target: Selection deletion resolver owner-scoped runtime fixture family; placement implementation-owned

### `selection-preparation-fail-fast-admission`: Selection preparation error propagation

Covers: `selection-preparation-fail-fast`
Impact: `EXTEND_COVERAGE`
Failure family: an ordinary selection preparation failure can be swallowed or converted into cancel
Failure mode or stable invariant: the owning error propagates synchronously before resolver entry with zero mutation
Verification owner: selection deletion runtime/edit owner failure suite
Current verification gap: no resolver boundary exists against which fail-fast propagation can be proved
Failing witness: current code cannot distinguish a future swallowed preparation error from resolver cancel
Durable and refactor-stable value: public error propagation and owner identity survive private preparation refactors
Artifact target: Selection deletion resolver owner-scoped fail-fast fixture family; placement implementation-owned

### `accepted-install-admission`: Single-use no-normal-failure install

Covers: `single-use-atomic-install`
Impact: `EXTEND_COVERAGE`
Failure family: accepted deletion can partly install, fail normally, publish mixed state, or consume twice
Failure mode or stable invariant: prepared Store then Selection installation is synchronous, single-use, and free of normal failure/publication
Verification owner: CommitApplier, Store, Selection, and runtime publication suites
Current verification gap: selection install can allocate after Store install and no private token exists
Failing witness: current accepted apply permits the documented selection-after-Store failure lifetime
Durable and refactor-stable value: stable owner events protect atomicity across token/helper refactors
Artifact target: `test/edit/selection_effect_commit_test.dart` and deletion prepared-install owner family

### `selection-callback-install-continuity-admission`: Selection callback-to-install continuity

Covers: `selection-callback-install-continuity`
Impact: `EXTEND_COVERAGE`
Failure family: external callback or publication can interleave after selection resolver return and before first install
Failure mode or stable invariant: resolver return and first Store install remain in one uninterrupted synchronous stack
Verification owner: selection deletion runtime temporal suite
Current verification gap: no resolver-to-install interval exists
Failing witness: current temporal evidence cannot observe an interval that has not been implemented
Durable and refactor-stable value: stable route/owner events survive private token and helper changes
Artifact target: Selection deletion resolver temporal owner-scoped fixture family; placement implementation-owned

### `selection-guard-admission`: Selection resolver guard coverage

Covers: `selection-resolver-guard`
Impact: `EXTEND_COVERAGE`
Failure family: one public mutation/lifecycle family can bypass the guard or mutate before rejection
Failure mode or stable invariant: allowed reads work and every forbidden family rejects without effects
Verification owner: resolver guard public-route suite
Current verification gap: existing guard proof has no deletion callback entry
Failing witness: no deletion resolver can attempt the public families
Durable and refactor-stable value: public-family evidence survives private dispatch changes
Artifact target: Existing resolver reentrancy owner plus deletion selection route coverage

### `selection-cancel-admission`: Selection cancel has no effects

Covers: `selection-resolver-cancel`
Impact: `EXTEND_COVERAGE`
Failure family: cancel can leak state, revision, timestamp, action, diagnostic, or interaction effects
Failure mode or stable invariant: prepared selection deletion is discarded without any observable effect
Verification owner: selection deletion runtime route suite
Current verification gap: no cancel branch exists
Failing witness: current route commits every nonempty final set
Durable and refactor-stable value: complete public snapshots survive internal state decomposition
Artifact target: Selection deletion resolver owner-scoped runtime fixture family; placement implementation-owned

### `selection-error-admission`: Selection resolver error containment

Covers: `selection-resolver-error`
Impact: `EXTEND_COVERAGE`
Failure family: an ordinary callback error can escape or leak deletion effects
Failure mode or stable invariant: error is absorbed and committed/action/timestamp/interaction state is unchanged
Verification owner: selection deletion runtime route suite
Current verification gap: no deletion callback error path exists
Failing witness: current route has no resolver to throw
Durable and refactor-stable value: outcome evidence is independent of diagnostic representation
Artifact target: Selection deletion resolver owner-scoped runtime fixture family; placement implementation-owned

### `selection-action-admission`: Selection action compatibility

Covers: `selection-action-compatibility`
Impact: `EXTEND_COVERAGE`
Failure family: resolver integration can change selection deletion action type, payload, IDs, or timestamp
Failure mode or stable invariant: existing action finalizer publishes the installed final IDs after state
Verification owner: command action and typed payload suites
Current verification gap: no resolver-enabled selection action exists
Failing witness: current suite cannot compare direct and resolver-accepted selection deletion
Durable and refactor-stable value: public event compatibility survives resolver orchestration refactors
Artifact target: `test/interaction/commands_emit_user_actions_test.dart` and typed action owner

### `selection-delivery-failure-admission`: Accepted selection survives delivery failure

Covers: `selection-post-install-delivery-failure`
Impact: `EXTEND_COVERAGE`
Failure family: post-install selection delivery failure can roll back, retry, reinterpret accept, or mutate eraser state
Failure mode or stable invariant: accepted owner state remains installed, resolver count remains one, and independent eraser state remains unchanged
Verification owner: selection deletion runtime delivery suite
Current verification gap: no resolver-accepted selection delivery failure path exists
Failing witness: current tests cannot combine resolver accept with injected post-install listener failure
Durable and refactor-stable value: public accepted-state finality survives delivery/helper refactors
Artifact target: Selection deletion resolver delivery-failure fixture family; placement implementation-owned

### `selection-layer-retention-admission`: Selection deletion retains emptied layers

Covers: `selection-layer-retention`
Impact: `EXTEND_COVERAGE`
Failure family: selection deletion of a sole element can remove, recreate, reorder, or mutate its layer
Failure mode or stable invariant: accepted selection deletion retains exact layer identity, order, and metadata
Verification owner: selection deletion runtime and Store layer-facts suite
Current verification gap: no resolver-aware selection layer-retention proof exists
Failing witness: current route cannot exercise an accepted resolver deletion
Durable and refactor-stable value: direct committed layer observations survive request/action/helper refactors
Artifact target: Selection deletion resolver owner-scoped layer-retention fixture family; placement implementation-owned

### `selection-resource-retention-admission`: Selection deletion retains resource descriptors

Covers: `selection-resource-retention`
Impact: `EXTEND_COVERAGE`
Failure family: selection deletion of a sole image/vector reference can implicitly remove or mutate its descriptor
Failure mode or stable invariant: accepted selection deletion retains the exact descriptor until explicit removal
Verification owner: selection deletion runtime and resource catalog suite
Current verification gap: no resolver-aware selection resource-retention proof exists
Failing witness: current route cannot exercise an accepted resolver deletion for both resource kinds
Durable and refactor-stable value: catalog observation survives request/action/helper refactors
Artifact target: Selection deletion resolver owner-scoped resource-retention fixture family; placement implementation-owned

### `selection-excluded-route-admission`: First-route excluded operations remain isolated

Covers: `selection-excluded-route-containment`
Impact: `EXTEND_COVERAGE`
Failure family: shared selection resolver/configuration work can spread into excluded public routing families
Failure mode or stable invariant: each excluded family preserves current behavior and never calls the deletion resolver
Verification owner: selection deletion and affected public route owner suites
Current verification gap: new deletion resolver configuration does not exist
Failing witness: no current operation can expose unintended propagation of the new resolver
Durable and refactor-stable value: per-family public behavior survives private routing and helper changes
Artifact target: Selection deletion resolver owner-scoped excluded-route fixture families; placement implementation-owned

### `selection-diagnostic-admission`: Selection resolver diagnostic route

Covers: `selection-resolver-diagnostic`
Impact: `EXTEND_COVERAGE`
Failure family: resolver error record can be absent, duplicated, unbounded, public, or emitted for controls
Failure mode or stable invariant: exactly one bounded internal record exists only for ordinary callback error and disabled mode retains none
Verification owner: interaction diagnostics suite plus selection route
Current verification gap: no dedicated code or producer route exists
Failing witness: current adapter cannot record deletion resolver failure
Durable and refactor-stable value: real adapter/hub observation survives code-name and helper changes
Artifact target: `test/diagnostics/interaction_diagnostics_test.dart` plus selection resolver route coverage

### `deletion-mutation-work-admission`: Sparse deletion mutation/replay work

Covers: `deletion-mutation-work-bounds`
Impact: `EXTEND_COVERAGE`
Failure family: bounded ordering work can be displaced into N-dependent validation, mutation, update, or replay
Failure mode or stable invariant: fixed-k pre-callback sparse mutation/replay work remains independent of unrelated N
Verification owner: edit/session sparse mutation and runtime deletion preparation work suite
Current verification gap: no resolver preparation phase or phase-specific N-scaling counters exist
Failing witness: current selection route already performs unrelated-N ordering work before sparse mutation
Durable and refactor-stable value: stable phase counters survive private journal/session implementation changes
Artifact target: Deletion sparse mutation/replay work owner-scoped fixture family; placement implementation-owned

### `deletion-install-work-admission`: Prepared deletion install/publication work

Covers: `deletion-install-work-bounds`
Impact: `EXTEND_COVERAGE`
Failure family: freeze, consume, install, or publication can repeat traversal or grow with unrelated N
Failure mode or stable invariant: one consume and one owner install each use only prepared/touched k-scale state without duplicate passes
Verification owner: CommitApplier, Store, Selection, and runtime publication work suite
Current verification gap: no deferred deletion install phase or direct work counters exist
Failing witness: current code cannot measure a future prepared token consume/publication phase
Durable and refactor-stable value: stable owner phase counters survive private prepared-state representation changes
Artifact target: Deletion prepared-install work owner-scoped fixture family; placement implementation-owned

### `two-route-outcome-admission`: Public two-route deletion outcome

Covers: `two-route-deletion-outcome`
Impact: `EXTEND_COVERAGE`
Failure family: either public deletion route can bypass whole-set interception
Failure mode or stable invariant: selection and terminal eraser expose the final nonempty set and obey whole-set decision
Verification owner: cross-route deletion lifecycle suite
Current verification gap: neither route currently supports interception
Failing witness: either route can still commit directly if the atomic cutover omits it
Durable and refactor-stable value: public-route evidence survives shared-helper refactors
Artifact target: Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned

### `two-route-callback-entry-admission`: Both callbacks receive Store-owned pre-mutation facts

Covers: `two-route-callback-entry-correctness`
Impact: `EXTEND_COVERAGE`
Failure family: either public route can rebuild stale, incomplete, duplicated, misordered, or post-mutation callback entries
Failure mode or stable invariant: both real callback requests exactly match one pre-mutation Store projection
Verification owner: cross-route deletion callback-entry suite
Current verification gap: Unit 3 can produce Store facts but neither public callback request exists
Failing witness: Store projection can be correct while one route reconstructs different request entries
Durable and refactor-stable value: callback semantics survive request-builder and route decomposition changes
Artifact target: Cross-route deletion callback-entry owner-scoped fixture family; placement implementation-owned

### `two-route-guard-admission`: Both deletion callbacks use the guard

Covers: `two-route-resolver-guard`
Impact: `EXTEND_COVERAGE`
Failure family: selection and eraser callback guard behavior can diverge by public family
Failure mode or stable invariant: both callbacks share exact allowed and rejected no-effect semantics
Verification owner: cross-route deletion lifecycle suite
Current verification gap: neither deletion route currently has a resolver entry
Failing witness: a cutover can guard selection while leaving terminal eraser unguarded
Durable and refactor-stable value: family-level public evidence survives internal routing changes
Artifact target: Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned

### `two-route-preparation-admission`: Both routes prepare before callback

Covers: `two-route-preparation-before-callback`
Impact: `EXTEND_COVERAGE`
Failure family: terminal eraser can retain an expected failure after callback begins
Failure mode or stable invariant: every admitted owner failure precedes both callbacks and eraser still cleans
Verification owner: cross-route deletion lifecycle and owner failure suites
Current verification gap: terminal route directly prepares and installs
Failing witness: no eraser callback ordering exists
Durable and refactor-stable value: owner failure seams survive internal preparation decomposition
Artifact target: Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned

### `two-route-preparation-fail-fast-admission`: Both routes propagate preparation failures

Covers: `two-route-preparation-fail-fast`
Impact: `EXTEND_COVERAGE`
Failure family: either deletion route can swallow or reinterpret an ordinary preparation failure
Failure mode or stable invariant: the same owner error propagates synchronously with zero callbacks/no mutation and eraser cleanup
Verification owner: cross-route deletion preparation failure suite
Current verification gap: neither route currently has a resolver boundary
Failing witness: eraser preparation can be changed to silent cancel without selection evidence detecting it
Durable and refactor-stable value: public fail-fast behavior survives shared preparation refactors
Artifact target: Cross-route deletion preparation fail-fast fixture family; placement implementation-owned

### `two-route-callback-install-continuity-admission`: Both callbacks install without interleaving

Covers: `two-route-callback-install-continuity`
Impact: `EXTEND_COVERAGE`
Failure family: either route can insert external work between resolver return and first Store install
Failure mode or stable invariant: both real callback returns lead directly to first Store install in one synchronous stack
Verification owner: cross-route deletion temporal suite
Current verification gap: neither route currently has a resolver callback
Failing witness: eraser can schedule cleanup/publication before install without selection trace detecting it
Durable and refactor-stable value: stable route/owner temporal events survive shared helper changes
Artifact target: Cross-route deletion callback-install temporal fixture family; placement implementation-owned

### `two-route-cancel-admission`: Both route cancels have no effects

Covers: `two-route-cancel-no-effect`
Impact: `EXTEND_COVERAGE`
Failure family: cancel outcome can differ between selection and eraser lifecycle
Failure mode or stable invariant: both discard prepared state; eraser cleans and selection isolates eraser state
Verification owner: cross-route deletion lifecycle suite
Current verification gap: no eraser resolver cancel exists
Failing witness: terminal eraser currently has no veto branch
Durable and refactor-stable value: complete route-specific snapshots survive helper refactors
Artifact target: Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned

### `two-route-error-admission`: Both route errors are contained

Covers: `two-route-error-no-effect`
Impact: `EXTEND_COVERAGE`
Failure family: error containment or route-specific cleanup can diverge
Failure mode or stable invariant: ordinary errors never escape or mutate; eraser cleans and selection isolates eraser state
Verification owner: cross-route deletion lifecycle suite
Current verification gap: no eraser resolver error branch exists
Failing witness: Unit 4 only establishes selection containment
Durable and refactor-stable value: outcome proof remains independent of diagnostic implementation
Artifact target: Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned

### `eraser-cleanup-admission`: Eraser cleanup before fallible delivery

Covers: `eraser-cleanup-before-delivery`
Impact: `EXTEND_COVERAGE`
Failure family: a terminal outcome or delivery failure can leave preview/session active
Failure mode or stable invariant: every terminal branch cleans before state/action delivery
Verification owner: eraser interaction and runtime delivery suites
Current verification gap: resolver cancel/error/preparation branches do not exist
Failing witness: current tests cannot exercise those cleanup outcomes
Durable and refactor-stable value: stable cleanup/delivery events survive private route restructuring
Artifact target: `test/interaction/eraser_context_action_routing_test.dart` and runtime delivery owner

### `two-route-mandatory-resolver-admission`: Required resolver is the sole nonempty route

Covers: `two-route-mandatory-resolver-path`
Impact: `EXTEND_COVERAGE`
Failure family: a nonempty route can bypass the required resolver or a no-op can spend resolver-specific construction/callback work
Failure mode or stable invariant: both routes require explicit configuration, invoke exactly once for nonempty final sets, and construct/invoke nothing for empty or rejected sets
Verification owner: public API construction and cross-route deletion lifecycle suites
Current verification gap: public construction permits omission and both current deletion routes install directly
Failing witness: terminal eraser can retain direct installation while selection uses the resolver, or an empty route can eagerly construct request state
Durable and refactor-stable value: public requiredness plus route/construction observations survive private orchestration refactors
Artifact target: Public API compile owner plus cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned

### `two-route-action-admission`: Both deletion actions remain compatible

Covers: `two-route-action-compatibility`
Impact: `EXTEND_COVERAGE`
Failure family: direct and resolver-accepted action behavior can diverge by route
Failure mode or stable invariant: existing delete/erase types, payloads, IDs, timestamps, and ordering remain exact
Verification owner: action finalizer, command action, typed payload, and runtime delivery suites
Current verification gap: no resolver-accepted action exists
Failing witness: current evidence covers only direct deletion
Durable and refactor-stable value: public action compatibility survives resolver/private-state refactors
Artifact target: `test/interaction/commands_emit_user_actions_test.dart`, typed action, and runtime delivery owners

### `resolver-diagnostic-admission`: Both resolver failure routes use one bounded diagnostic

Covers: `two-route-resolver-diagnostic`
Impact: `EXTEND_COVERAGE`
Failure family: diagnostic cardinality/redaction/control behavior can diverge between deletion routes
Failure mode or stable invariant: exactly one internal bounded record per ordinary thrown callback and none for controls/disabled mode
Verification owner: interaction diagnostics plus cross-route deletion suite
Current verification gap: no deletion resolver diagnostic producer exists
Failing witness: selection can report correctly while terminal eraser duplicates or leaks diagnostic facts
Durable and refactor-stable value: real route/adapter/hub evidence survives internal code naming
Artifact target: `test/diagnostics/interaction_diagnostics_test.dart` plus cross-route deletion coverage

### `two-route-cardinality-admission`: Resolver invocation cardinality

Covers: `two-route-resolver-cardinality`
Impact: `EXTEND_COVERAGE`
Failure family: callback can run for no-op, be skipped, or be retried/duplicated
Failure mode or stable invariant: zero calls for empty/invalid/rejected and exactly one for nonempty accept/cancel/error on both routes
Verification owner: cross-route deletion lifecycle suite
Current verification gap: no deletion resolver exists
Failing witness: callback count cannot currently be observed
Durable and refactor-stable value: public callback boundary survives shared-helper refactors
Artifact target: Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned

### `two-route-layer-retention-admission`: Empty layer retention

Covers: `two-route-layer-retention`
Impact: `EXTEND_COVERAGE`
Failure family: deletion of the last element can remove/recreate/reorder/mutate a layer
Failure mode or stable invariant: both routes retain exact layer identity, order, and metadata
Verification owner: cross-route deletion and Store layer facts suite
Current verification gap: no both-route resolver-aware retention proof exists
Failing witness: current evidence cannot compare accepted callback routes
Durable and refactor-stable value: direct committed layer facts survive action/request refactors
Artifact target: Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned

### `two-route-resource-retention-admission`: Resource descriptor retention

Covers: `two-route-resource-retention`
Impact: `EXTEND_COVERAGE`
Failure family: last-reference deletion can implicitly remove/mutate image or vector descriptors
Failure mode or stable invariant: both routes retain descriptors until explicit resource removal
Verification owner: cross-route deletion and resource catalog suite
Current verification gap: no both-route resolver-aware resource retention proof exists
Failing witness: current evidence cannot compare callback routes for both resource kinds
Durable and refactor-stable value: catalog observation survives action/request refactors
Artifact target: Cross-route deletion lifecycle owner-scoped fixture family; placement implementation-owned

### `excluded-route-admission`: Excluded route containment

Covers: `excluded-route-containment`
Impact: `EXTEND_COVERAGE`
Failure family: deletion policy/resolver can spread through independently routed excluded public families
Failure mode or stable invariant: every excluded family retains current effects and zero resolver calls
Verification owner: affected public route owner suites plus cross-route deletion suite
Current verification gap: new fields cannot currently influence any route
Failing witness: all new configuration is absent
Durable and refactor-stable value: public route observations survive symbol/helper movement
Artifact target: Cross-route/excluded-route owner-scoped fixture families; placement implementation-owned

### `deletion-cleanup-work-admission`: Prepared-state discard and cleanup work

Covers: `deletion-cleanup-work-bounds`
Impact: `EXTEND_COVERAGE`
Failure family: cancel/error/terminal cleanup can add N-dependent traversal, rollback replay, or duplicate cleanup
Failure mode or stable invariant: discard and owner-local cleanup remain N-independent, single-pass, and rollback-free across all branches
Verification owner: cross-route deletion cleanup/discard and runtime delivery work suite
Current verification gap: resolver cancel/error branches and their phase-specific work counters do not exist
Failing witness: current cleanup proof cannot detect a future whole-document reconstruction on cancel
Durable and refactor-stable value: stable discard/cleanup/rollback counters survive private cleanup decomposition
Artifact target: Deletion cleanup/discard work owner-scoped fixture family; placement implementation-owned

## Verification Gate

| Check | Scope | Future command or evidence | Pass signal |
| --- | --- | --- | --- |
| Changed Dart owners | All changed production, test, and guardrail Dart code | `dart analyze` from repository root | Exit 0 with no analyzer diagnostics. |
| Maintained example analysis | All migrated example sample, performance, and test constructions | `cd example && flutter analyze` | Exit 0; all nine known config/runtime constructions supply the accepted explicit resolver/config and no omitted-config call remains. |
| Maintained example behavior | Complete maintained example package after the required-constructor migration | `cd example && flutter test` | Exit 0 with sample and performance/test consumers preserving their existing behavior under the explicitly chosen resolver policy. |
| DCM analysis | Whole changed Dart repository | `dcm analyze .` from repository root | Exit 0 with no unsuppressed findings; any local metrics suppression follows AGENTS.md exact-name and rationale policy. |
| Production metrics | Changed `lib/src/contracts`, `lib/src/runtime`, `lib/src/edit`, `lib/src/store`, `lib/src/selection`, `lib/src/geometry`, and `lib/src/diagnostics` owners | Run `dcm calculate-metrics` separately for each listed changed owner from repository root. | Every changed owner is reported and any retained threshold signal is justified as a coherent-design trade-off rather than metric-shaped splitting. |
| Test metrics | Changed `test/api_contract`, `test/api`, `test/runtime`, `test/geometry`, `test/store`, `test/edit`, `test/diagnostics`, `test/interaction`, and `test/architecture_graph` owners actually touched | Run `dcm calculate-metrics` separately for each touched listed test owner from repository root. | Every touched test owner is reported with no metric-only fragmentation. |
| Architecture closure | Runtime-to-diagnostics expected graph obligation and current dependency closure | `dart run tool/architecture_graph/check.dart` from repository root | Exit 0 and the exact deletion-resolver diagnostic obligation resolves to the intended existing owners without an extra graph node or changed unrelated obligation. |
| Generated architecture views | The two I-004 generated projections | `dart run tool/architecture_graph/generate_views.dart --check` from repository root | Exit 0 and both checked-in views match the graph-owned expected state. |
| Documentation synchronization | All changed semantic docs, registries, diagrams, and generated navigation | `dart run docs/tool/sync_generated_docs.dart --check` from repository root | Exit 0 with no stale generated documentation. |
| Documentation validity | All changed files under `docs/` | `dart run docs/tool/check_docs.dart` from repository root | Exit 0 with valid registries, links, ownership metadata, and documentation constraints. |
| Canonical public route | Root barrel, public declarations, required config/runtime constructors, every repository construction including maintained `example/`, registry, semantic signatures, runtime adapter, and direct external implementer | Existing public API compile/export/signature/requiredness/default/equality, repository compile, example analyze/test, negative construction, and direct-consumer checks selected by `docs/verification/release_gates.md` | All exact new names and fields are reachable once, every root/example construction and both implementers compile explicitly, the example package passes, omitted/null resolver and omitted runtime config fail, remaining defaults/equality match, and no nullable/default/omitted-config/V2/capability/duplicate/state-mirror alternative appears. |
| Cross-unit deletion closure | Units 1-4 on one resulting repository state | Matrix evidence for `eraser-resolver-request-policy`, `two-route-deletion-outcome`, `two-route-callback-entry-correctness`, `two-route-resolver-guard`, `two-route-preparation-before-callback`, `two-route-cancel-no-effect`, `two-route-error-no-effect`, `two-route-resolver-diagnostic`, `two-route-mandatory-resolver-path`, `two-route-action-compatibility`, `two-route-resolver-cardinality`, `two-route-layer-retention`, `two-route-resource-retention`, and `excluded-route-containment` | Every nonempty deletion passes through the required resolver with the exact policy-filtered, Store-projected callback entries and real public owners, diagnostics stay separate and bounded, empty/rejected operations stop before resolver construction, all stop conditions remain false, and no unit-local proof is extrapolated to the other route. |
| Residual work-budget closure | Complete selection/eraser construction, read, projection, mutation/replay, install/publication, and cleanup/rollback routes | Direct Matrix counters for eraser admission, Store and end-to-end ordering, nonempty request/deferred construction, empty/rejected early exit, sparse mutation/replay, prepared install/publication, and discard/cleanup on the resulting repository state | Canonical k is linear, arbitrary k stays k-log-k, fixed-k is N-independent in every applicable phase, filtered eraser candidates spend no budget, every nonempty set creates exactly one resolver state while empty/rejected sets create none, accepted install/publication has no duplicate pass, and cleanup performs no rollback or N-dependent work; DCM remains a separate maintainability signal and is not acceptance evidence. |
| Finding disposition | All implementation/review findings against this contract | For every finding, record the owning unit and evidence-backed disposition in the implementation review workflow. | No unresolved blocker, high/medium correctness finding, source conflict, or triggered H-001/H-002/H-003 remains. |
| Diff hygiene | Whole change | `git diff --check` | Exit 0 |
| Lifecycle closure | Active contract and source design | After every unit and required evidence is complete, move this plan to `docs/history/plans/2026-08-24-deletion-eraser-and-selection-policies.md`; move the design to `docs/history/designs/2026-08-24-deletion-eraser-and-selection-policies.md` only when no active plan still references it, then run the documentation checks. | The plan is historical, the design moves only if its entire handoff is covered and unreferenced by active plans, direct-child active registration is accurate, and generated documentation remains current. |
