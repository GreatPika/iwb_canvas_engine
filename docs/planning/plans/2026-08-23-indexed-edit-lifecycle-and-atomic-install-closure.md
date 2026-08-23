# Change Contract

## Goal

Sparse and materialized edits use the already-delivered indexed-order implementation through separate owner-local state, one `StoreSparseMutation` journal is the only sparse transaction and promotion intent, exact location and split resource-reference facts replace edit-owned lists, scans, and replay mirrors, DraftDocument replacement swaps one completely prepared backing, and CommitApplier prepares one immutable apply state before either document-changing or selection-only installation branch so every pre-install failure leaves all accepted state unchanged and every post-document-install prepared-selection failure retains the state already accepted, without reopening Store candidate behavior or implementing runtime route and delivery work reserved for Contract 4.

## Source Inputs

| Category | Source ID | Location or authority |
| --- | --- | --- |
| Design | `sparse-commit-transaction-candidate-design` | docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md |
| Research | `element-resource-lookup-facts` | docs/history/research/2026-08-10-element-resource-lookup-facts.md |
| PLAN | `authoritative-committed-facts` | docs/history/plans/2026-08-12-authoritative-committed-facts.md |
| PLAN | `clear-content-layer-scope` | docs/history/plans/2026-08-13-clear-content-layer-scope.md |
| PLAN | `store-transaction-candidate` | docs/history/plans/2026-08-13-store-transaction-candidate.md |
| Other | `contract-three-request` | user request |
| Other | `repository-policy` | AGENTS.md |
| Other | `engineering-change-unit-criteria` | .agents/skills/change-contract/references/engineering-change-unit-criteria.md |
| Other | `planning-policy` | docs/planning/README.md |
| Other | `package-boundaries` | docs/architecture/02_package_boundaries.md |
| Other | `runtime-data-model` | docs/architecture/03_data_model.md |
| Other | `architecture-graph` | docs/architecture/architecture_graph.yaml |
| Other | `edit-owner` | docs/contracts/edit_kernel.md |
| Other | `operation-owner` | docs/contracts/operation_matrix.md |
| Other | `validation-owner` | docs/contracts/validation_limits.md |
| Other | `public-api-owner` | docs/contracts/public_api_v1.md |
| Other | `codec-owner` | docs/contracts/codec_boundary.md |
| Other | `verification-owner` | docs/verification/tests.md |
| Other | `guardrail-proof-policy` | docs/verification/guardrail_design_patterns.md |
| Other | `transaction-architecture-adr` | architecture/decisions/ADR-0017-store-transaction-candidate-and-derived-facts.md |
| Other | `committed-projection-adr` | architecture/decisions/ADR-0002-separate-committed-runtime-and-projection-state.md |
| Other | `store-finalization-adr` | architecture/decisions/ADR-0003-store-finalized-edit-transactions.md |
| Other | `atomic-load-adr` | architecture/decisions/ADR-0004-canonical-schema-reader-and-atomic-load.md |
| Other | `resource-resolution-adr` | architecture/decisions/ADR-0005-surface-owned-resource-resolution.md |
| Other | `indexed-order-owner` | lib/src/store/indexed_order_sequence.dart |
| Other | `store-kernel-owner` | lib/src/store/document_store_kernel.dart |
| Other | `family-table-owner` | lib/src/store/family_tables.dart |
| Other | `layer-table-owner` | lib/src/store/layer_table.dart |
| Other | `element-registry-owner` | lib/src/store/element_registry.dart |
| Other | `resource-table-owner` | lib/src/store/resource_table.dart |
| Other | `committed-document-owner` | lib/src/store/committed_document.dart |
| Other | `sparse-store-dto-owner` | lib/src/store/sparse_store_commit.dart |
| Other | `edit-session-owner` | lib/src/edit/edit_session.dart |
| Other | `draft-document-owner` | lib/src/edit/draft_document.dart |
| Other | `edit-kernel-owner` | lib/src/edit/edit_kernel.dart |
| Other | `commit-applier-owner` | lib/src/edit/commit_applier.dart |
| Other | `runtime-adapter-owner` | lib/src/runtime/runtime_root.dart |
| Other | `sparse-edit-verification-owner` | test/edit/fixtures/sparse_edit_session_fixture.dart |
| Other | `edit-matrix-verification-owner` | test/edit/fixtures/edit_matrix_effects_fixture.dart |
| Other | `net-no-op-verification-owner` | test/edit/fixtures/net_no_op_edit_commit_fixture.dart |
| Other | `rollback-verification-owner` | test/edit/fixtures/rollback_fixture.dart |
| Other | `selection-install-verification-owner` | test/edit/fixtures/selection_effect_commit_fixture.dart |
| Other | `clear-command-action-verification-owner` | test/api/fixtures/command_port_actions_fixture.dart |
| Other | `clear-spatial-verification-owner` | test/spatial/fixtures/runtime_delivery_order_fixture.dart |
| Other | `direct-store-verification-owner` | test/store/fixtures/sparse_store_commit/sparse_store_commit_fixture.dart |
| Other | `store-candidate-verification-owner` | test/store/fixtures/store_transaction_candidate_fixture.dart |
| Other | `projection-verification-owner` | test/store/fixtures/no_projection_hot_path_fixture.dart |
| Other | `accepted-finalization-guardrail` | test/guardrails/edit_accepted_finalization_guardrail_test.dart |
| Other | `document-input-guardrail` | tool/guardrails/src/document_load_input_guardrail.dart |
| Other | `guardrail-registry-owner` | tool/guardrails/src/guardrail_executor.dart |
| Other | `documentation-registry-owner` | docs/_registry/sections.yaml |

## Classification

Profile: `BEHAVIOR_CHANGE`
Obligations: `SEAM_MIGRATION`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `NEGATIVE_PROOF_AND_FIXTURE_QUARANTINE`, `TEMPORAL_SURFACE_CLOSURE`, `ALL_OR_NOTHING_FAILURE_BOUNDARY`, `SOURCE_OF_TRUTH_SINGULARITY`, `WORK_BUDGET_CLOSURE`

## Decision Trace

| Decision ID | Independent failure family | Source decision | Contract location | Acceptance or evidence target |
| --- | --- | --- | --- | --- |
| `sole-sparse-intent-journal` | Closure replay and mutation DTOs can encode different sparse intent or order. | Design D7 and the Contract-2 handoff require `StoreSparseMutation` to be the sole EditSession journal and promotion input. | Boundaries; Unit 1 | `promotion-replays-the-sole-journal` |
| `exhaustive-promotion-consumer` | A new mutation subtype can reach Store but be omitted or reinterpreted by promotion. | Design D4, D7, D14, and current exhaustive Store dispatch require one same-unit Draft consumer of every unchanged DTO with raw sequential indices. | Unit 1 | `promotion-dispatch-is-exhaustive` |
| `replay-mirror-retirement` | The closure journal or an equivalent replay history can remain after DTO promotion cutover. | Design D12 and the no-dual-truth boundary retire obsolete replay state at its first safe point. | Unit 1 | `replay-mirror-is-retired` |
| `early-journal-cutover-work-neutrality` | Replacing closure replay with DTO dispatch can add a second traversal, copy, scan, or repeated Draft application before indexed owners land. | The explicit user authority permits early journal cutover before indexed/count owners only when it preserves the current promotion work one-for-one and introduces no new multiplier or displaced phase; Units 2-5 remain mandatory cost closure. | Unit 1 | `early-journal-cutover-does-not-displace-work` |
| `accepted-finalization-private-shape-retirement` | An existing guardrail can keep private EditKernel helper names and bodies as authority after the journal/promotion seam changes. | Design D12 and the direct-consumer preflight require private-shape proof to migrate to stable prepared-DTO and behavioral owners at the first affected unit. | Unit 1; Verification Matrix | `private-shape-guardrail-authority-is-retired` |
| `sparse-order-authority` | Sparse callback order lists and placement overrides can become simultaneous ordering authorities. | Design D3, D8, and D12 require separate owner-local indexed sequences initialized from authoritative committed location/order facts. | Boundaries; Unit 2 | `sparse-placement-is-current` |
| `sparse-index-semantics` | Indexed callback order can change negative, oversized, null, or repeated same-index behavior. | Design D3-D4 preserve exact raw numeric-index and sequential clamping semantics. | Unit 2 | `sparse-index-semantics-are-exact` |
| `sparse-order-work` | Correct callback order can still rebuild, shift, scan, or flatten an order for each mutation. | Design D1, D3, D13, and the work-budget obligation require one lazy open per affected order and logarithmic rank work. | Unit 2 | `sparse-order-work-is-bounded` |
| `sparse-image-count-authority` | Sparse image references can drift or fall back to scanning accepted elements. | Design D6 assigns exact image counts to committed facts plus a session-local delta for every successful transition and clear barrier. | Unit 3 | `sparse-image-counts-are-exact` |
| `sparse-vector-count-authority` | Sparse vector references can drift independently from image references. | Design D6 requires a distinct exact vector count lifecycle with the same transition coverage. | Unit 3 | `sparse-vector-counts-are-exact` |
| `sparse-resource-order` | `removeUnusedResource` can observe pre-transition or post-clear references in the wrong order. | Design D6, D14, D20, and the maintained edit contract preserve current-state ordered resource decisions. | Unit 3 | `sparse-resource-decisions-are-current` |
| `sparse-reference-work` | Exact resource results can hide element scans, global count-map clones, or mutation-depth overlays. | Design D1, D6, and D13 forbid displaced `K`-multiplied reference work. | Unit 3 | `sparse-reference-work-is-bounded` |
| `draft-structural-authority` | Draft layer, background, content, membership, and placement lists/maps can disagree. | Design D3, D4, D8, and the Draft lifecycle lock require one direct structural backing with separate owner-local indexed sequences. | Boundaries; Unit 4 | `draft-structural-facts-are-direct` |
| `draft-structure-work` | Materialized editing can retain nested lookup, list shifts, or repeated flatten/rescan work. | Design D1, D3, D13 and Verification Strategy 4-5 require direct lookup and bounded indexed mutations at supported size. | Unit 4 | `draft-structure-work-is-bounded` |
| `draft-image-count-authority` | Draft image-reference decisions can scan all elements or drift after updates and clear. | Design D6 assigns exact Draft-local image counts derived from its current mutable rows. | Unit 5 | `draft-image-counts-are-exact` |
| `draft-vector-count-authority` | Draft vector-reference decisions can drift independently or be omitted from clear retention. | Design D6 and D20 require an exact vector count and a separate preserved-background witness. | Unit 5 | `draft-vector-counts-are-exact` |
| `draft-resource-authority` | A descriptor list and keyed lookup/count state can become simultaneous resource truths. | Design D6 and D12 require one insertion-ordered keyed descriptor owner and retirement of list/reference scans. | Unit 5 | `draft-resource-state-is-singular` |
| `three-path-parity` | Direct Store, sparse callback, and promoted Draft paths can produce different order, diagnostics, no-op, or resource results. | Design Outcome-Proof Fit and Verification Strategy 2-3 require identical traces across all three production paths. | Units 1-5; Verification Matrix | `edit-paths-have-exact-parity` |
| `clear-background-image-retention` | Layer-only clear can remove an image descriptor still referenced by a preserved background element. | Design D20 and the completed clear contract require image descriptor retention and actual-removal facts only across every backing. | Units 2, 4, and 5 | `three-path-parity-evidence` |
| `clear-background-vector-retention` | Layer-only clear can remove a vector descriptor still referenced by a preserved background element. | Design D20 and the completed clear contract require an independent vector retention route across every backing. | Units 2, 4, and 5 | `three-path-parity-evidence` |
| `clear-command-action-compatibility` | Accelerated edit backings can report or publish removed IDs that include preserved background elements/resources or omit actual ordinary removals. | The completed clear contract and design D20 require command results/actions to contain actual removals only. | Unit 5; Verification Matrix | `clear-command-action-evidence` |
| `clear-spatial-background-compatibility` | Clear acceleration can empty or stale the spatial owner while a preserved background element remains committed. | The completed clear contract and design D20 require preserved background elements to remain directly queryable before publication. | Unit 5; Verification Matrix | `clear-spatial-background-evidence` |
| `draft-replacement-atomicity` | Validated replacement can overwrite scalar, resource, or structural state incrementally and expose a mixed backing if later construction fails. | The design Draft lifecycle requires complete fresh backing construction and swap only after successful preparation. | Boundaries; Unit 6 | `draft-replacement-swaps-atomically` |
| `draft-replacement-alias-closure` | Caller-owned replacement collections or retired backing state can mutate the active draft after swap. | Design Verification Strategy 7 requires unaliased mutable working state and unreachable retired buffers. | Unit 6 | `draft-replacement-is-isolated` |
| `single-prepared-apply-state` | Materialized documents, delivery effects, or selection facts can be reconstructed on opposite sides of installation. | Design D11 and D16 require accepted document/selection/effects preparation before the applicable irreversible point. | Boundaries; Unit 7 | `materialized-apply-state-is-prepared-once` |
| `document-install-first-point` | A document-changing commit can install selection first, reprepare after document swap, or use the wrong rollback point. | Design D11 fixes document install as the first irreversible point followed by prepared selection install. | Unit 7 | `document-changing-install-order-is-exact` |
| `selection-only-first-point` | A selection-only commit can call Store or treat a nonexistent document install as its irreversible point. | Design D11 fixes prepared selection install as the first and only irreversible point for this branch. | Unit 7 | `selection-only-install-order-is-exact` |
| `preinstall-rollback-boundary` | Selection preparation, stale Store admission, or materialized preparation failure can leak document, selection, IDs, delivery, projection, or aliases. | Design D11, D16, and the all-or-nothing boundary require exact unchanged state before the applicable point. | Unit 7 | `preinstall-failure-preserves-state` |
| `postinstall-retention-boundary` | Failure after document installation can roll back or replace already accepted document/admission state. | Design D11 requires accepted-state retention after the applicable irreversible point. | Unit 7 | `postinstall-failure-retains-accepted-state` |
| `store-candidate-remains-closed` | Edit adoption can copy, bypass, reopen, or reimplement Contract-1/2 committed facts or Store finalization. | Archived Contracts 1-2 deliver the facts, indexed sequence, candidate, diagnostics, work, and immutable prepared result as closed dependencies. | Out of Scope; Verification Matrix | `direct-store-remains-independent` |
| `compatibility-surface-lock` | Internal edit migration can change public API, StoreSparseCommit, codec, projection, diagnostics, or graph direction. | Design D14 and the explicit user exclusion list preserve those surfaces exactly. | Boundaries; Verification Matrix | `compatibility-surfaces-remain-unchanged` |
| `runtime-route-future-boundary` | Contract 3 can absorb generated-ID routes, resolver behavior, cleanup, or delivery ordering, or leave edit correctness for Contract 4. | The required four-contract partition leaves Contract 4 only route-generated-ID and runtime temporal delivery closure. | Out of Scope; Unit 7; Verification Matrix | `contract-four-remains-runtime-owned` |
| `edit-truth-closure` | Maintained docs or ADR state can continue describing dual journals/list editing or claim future runtime delivery as current. | Design D15 requires current data-model/edit-contract/ADR truth to close with each delivered owner. | Units 1-7; Verification Matrix | `edit-lifecycle-documentation-evidence` |
| `aggregate-edit-work-closure` | Individually bounded owners can compose into repeated edit/promotion/materialization/install work. | Design D1, D13 and `WORK_BUDGET_CLOSURE` require an owner-attributed end-to-end bound with no cost displacement. | Boundaries; Unit 5; Verification Matrix | `aggregate-edit-work-is-bounded` |

## Repository Evidence

- `user request` / architecture-consumption authority: Contract 3 must consume the active design's substantive accepted decisions as written and must not wait for, require, or create an `architecture-design/v4` migration or Contract Interface -> the current design remains architecture authority for this contract and v4 metadata is not an implementation prerequisite or later unit.
- `user request` / accepted Contract-3 cutover and cost boundary: promotion already applies operations one-for-one to list-backed `DraftDocument` through closures, so U1 may replace closures with exhaustive DTO dispatch when it adds no copy, scan, projection, repeated replay, or other work multiplier -> U1 is work-neutral rather than the performance closure; Units 2-5 must still eliminate every pre-existing sparse/Draft list and scan cost, and the final owner-attributed gate rejects displacement into promotion, Draft, materialization, finalization, apply, RuntimeRoot augmentation, or Contract 4.
- `docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:235` / migration order: sparse EditSession receives owner-local sequences, authoritative locations, count deltas, and the single DTO journal -> Units 1-3 must close every sparse owner path without a second replay/order/count truth.
- `docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:236` / Draft migration: DraftDocument adopts the same implementation with separate state and promotion replays DTOs -> Units 1, 4, and 5 share code only, never mutable instances.
- `docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:268` / atomicity authority: selection preparation precedes both irreversible branches, with document install first for document changes and selection install first for selection-only -> Unit 7 closes both branches together.
- `docs/history/plans/2026-08-12-authoritative-committed-facts.md:576` / completed Contract-1 handoff: direct family membership/reference summaries, layer locations, and admission facts are already delivered -> this contract may expose narrow reads but cannot reopen, mirror, or recompute those owners.
- `docs/history/plans/2026-08-13-store-transaction-candidate.md:132` / completed install boundary: stale validation, one document swap, and ledger-only admission already belong to Store -> Unit 7 consumes this unchanged installer rather than repairing Store.
- `docs/history/plans/2026-08-13-store-transaction-candidate.md:140` / pending edit state: current sparse backing intentionally remained with replay closures and DTOs -> Unit 1 retires the exact deferred mirror.
- `docs/history/plans/2026-08-13-store-transaction-candidate.md:141` / pending Draft state: DraftDocument remains a separate mutable lifecycle and indexed adoption/promotion parity are Contract 3 -> Units 4-6 own that work.
- `docs/history/plans/2026-08-13-store-transaction-candidate.md:162` / handoff exclusion: Contract 3 is limited to edit journal/order/promotion and CommitApplier adoption -> no Store finalizer or runtime route work is admissible.
- `lib/src/edit/edit_session.dart:338` / dual intent: `_SparseEditBacking` retains closure and DTO journals -> both cannot survive Unit 1.
- `lib/src/edit/edit_session.dart:366` / promotion source: current promotion replays closures and clears only that list -> DTO promotion must cut over atomically with its Draft consumer.
- `lib/src/edit/edit_session.dart:345` / sparse order mirrors: background, layer, and per-layer content orders are mutable lists beside location overrides -> Unit 2 replaces the complete structural working view, not one list.
- `lib/src/edit/edit_session.dart:893` / rank path: layer admission uses list membership/insertion, while element placement uses list insertion/removal at lines 946-966 -> current supported-size work is linear per mutation.
- `lib/src/edit/edit_session.dart:1013` / reference path: local overrides are scanned and some states fall back to all accepted elements -> Unit 3 must consume committed summaries plus exact deltas.
- `lib/src/edit/draft_document.dart:55` / Draft backing: descriptors, background elements, layers, and layer elements are copied into mutable lists -> Units 4-5 replace distinct structural and resource owners without sharing Store/editor state.
- `lib/src/edit/draft_document.dart:110` / Draft rank path: layer and element insertion uses `List.insert`; lookup later uses nested `indexWhere` at lines 438-500 -> Unit 4 closes both rank and direct lookup together.
- `lib/src/edit/draft_document.dart:210` / Draft descriptor path: resource lookup/update/remove uses list scans and copies -> Unit 5 replaces the complete descriptor/reference lifecycle.
- `lib/src/edit/draft_document.dart:301` / replacement path: validated replacement incrementally overwrites scalars, resources, background, and layers -> Unit 6 builds a complete backing before one swap.
- `lib/src/store/indexed_order_sequence.dart:62` / delivered reusable owner: the implicit AVL sequence has separate node/lookup state per instance and exact rank operations -> edit/draft import this implementation unchanged.
- `lib/src/store/family_tables.dart:91` / committed row owner: seven immutable family maps own element rows and current direct membership/reference reads -> sparse and Draft counts may consume owner facts but cannot copy family inventories or move committed policy.
- `lib/src/store/layer_table.dart:88` / committed layer owner: ordered layer rows own layer identity and content order -> the private sparse fact seam may expose exact current locations without introducing a second committed order.
- `lib/src/store/element_registry.dart:91` / committed registry owner: structural facts derive from family/layer owners and direct resource reference delegates to family tables -> edit-local indexed state is transaction working truth only and cannot become a committed registry mirror.
- `lib/src/store/resource_table.dart:60` / committed descriptor owner: one descriptor map owns resource membership and current values -> Draft's keyed descriptor backing is isolated mutable edit state and Store publication remains unchanged.
- `lib/src/store/committed_document.dart:53` / immutable publication owner: committed tables compose the installable document boundary -> Unit 7 reuses one accepted instance without changing projection, Store publication, or alias ownership.
- `lib/src/store/document_store_kernel.dart:233` / facts seam: committed background/layer orders and direct element/resource reads already exist -> exact owner-derived locations/counts can cross narrow direct queries without projection.
- `lib/src/runtime/runtime_root.dart:2558` / private adapter: RuntimeRoot already forwards one Store snapshot through `SparseEditSessionFacts` -> Units 2-3 extend this existing seam rather than adding public or reverse dependencies.
- `lib/src/edit/commit_applier.dart:95` / current branch skeleton: selection is prepared before optional document install and selection install -> Unit 7 preserves that order while preparing one immutable apply state.
- `lib/src/runtime/runtime_root.dart:1822` / duplicate materialized preparation: selection normalization constructs a `CommittedDocument` from an accepted materialized document, while `commit_applier.dart:130` constructs another for installation -> Unit 7 uses one prepared instance for both consumers.
- `lib/src/store/document_store_kernel.dart:817` / Store irreversible seam: stale-base rejection precedes `_document` assignment and admission ledgers follow the assignment -> direct Store behavior remains unchanged and supplies the document-branch first point.
- `test/edit/fixtures/sparse_edit_session_fixture.dart:228` / current promotion proof: existing cases observe promotion/replay but derive expectations from the closure path and do not falsify a DTO/closure divergence -> Unit 1 extends this owner evidence.
- `test/edit/fixtures/sparse_edit_session_fixture.dart:829` / current Draft work observation: clear counts background/resource passes but not indexed rank, direct membership, or exact split-count transitions -> Units 4-5 extend semantic owner counters.
- `test/api/fixtures/command_port_actions_fixture.dart:73` / clear command/action consumer: the current command result and clear action observe actual removed element/resource IDs while retaining background image/vector rows and descriptors -> Unit 5 reruns this unchanged compatibility owner after all backing cutovers.
- `test/spatial/fixtures/runtime_delivery_order_fixture.dart:91` / clear spatial consumer: the current command-clear trace observes the retained background candidate in direct spatial queries before publication -> Unit 5 preserves this unchanged runtime consumer without moving spatial delivery ownership into edit.
- `test/edit/fixtures/selection_effect_commit_fixture.dart:54` / selection-only witness: current events are prepare-selection then selection with no document install -> Unit 7 retains this direct branch oracle and adds both sides of the failure boundary.
- `test/edit/fixtures/selection_effect_commit_fixture.dart:239` / current rollback witness: selection preparation failure snapshots the sparse Store/selection state -> Unit 7 extends the snapshot through stale, IDs, projection, aliases, and post-install retention.
- `test/guardrails/edit_accepted_finalization_guardrail_test.dart:27` / direct-consumer mirror: the guardrail prescribes private EditKernel helper/body shape even though direct Store suites own accepted finalization -> Unit 1 removes or migrates those private-shape assertions to the stable prepared-DTO boundary and behavioral owners instead of preserving or widening the scanner.
- `test/edit/edit_matrix_effects_test.dart:92` / exact-parity validator: edit operation rows are derived from the maintained operation matrix and public edit surface -> public/matrix shapes stay unchanged while the existing semantic fixture remains a compatibility consumer.
- `tool/guardrails/src/document_load_input_guardrail.dart:292` / CanvasDocument input allowlist: DraftDocument, replacement, EditKernel, CommitApplier-adjacent Store preparation, and testing bridge declarations are centrally mirrored -> Units 4-7 preserve named input declarations or update this owning allowlist in the same unit only if a declaration genuinely moves.
- `tool/guardrails/src/guardrail_executor.dart:277` / verification registry: rollback and operation-matrix guarantees already route to edit owner suites -> new evidence extends those owners and does not create a second registry or test-name inventory.
- `docs/architecture/02_package_boundaries.md:311` / dependency direction: Store cannot import interaction/frame/surface and edit cannot import surface -> edit may consume the low-level Store sequence/facts along the current edit-to-store direction; no graph edge changes.
- `architecture/decisions/ADR-0017-store-transaction-candidate-and-derived-facts.md:62` / durable state: Store candidate/indexed/derived infrastructure is delivered while EditSession/DraftDocument adoption remains pending -> Units 1-6 update only that implementation state and leave route-generated ID/runtime delivery pending.
- `architecture/decisions/ADR-0002-separate-committed-runtime-and-projection-state.md:32` / projection boundary: compact committed tables remain authoritative and public documents are lazy explicit projections -> no edit or promotion optimization may materialize or replace this owner.
- `architecture/decisions/ADR-0003-store-finalized-edit-transactions.md:35` / finalization boundary: EditKernel owns session lifecycle while Store owns accepted facts/final comparison -> callback and Draft parity cannot move Store policy or finalization into edit-local state.
- `architecture/decisions/ADR-0004-canonical-schema-reader-and-atomic-load.md:32` / load boundary: codec-owned decoding and isolated runtime load preparation stay outside Draft replacement -> Unit 6 consumes validated input without changing load/schema ownership.
- `architecture/decisions/ADR-0005-surface-owned-resource-resolution.md:32` / resource runtime boundary: committed storage owns descriptors while resolution/cache policy stays runtime/surface-owned -> edit-local split counts never become resolver or delivery state.

## Boundaries

Owner: `EditSession` owns sparse callback-local intent and current sparse working facts; `DraftDocument` owns materialized working facts and complete replacement backing; `CommitApplier` owns one prepared apply lifetime and both installation branches. `DocumentStoreKernel`, `FamilyTables`, `LayerTable`, `ElementRegistry`, `ResourceTable`, `_IdAdmission`, `IndexedOrderSequence`, and `StoreSparseCommit` retain their completed Store ownership. `docs/contracts/edit_kernel.md`, the edit portion of `docs/architecture/03_data_model.md`, and ADR-0017 own maintained edit/install truth after each applicable cutover.
In Scope: One exhaustive Draft mutation consumer and atomic promotion cutover to the sole DTO journal; removal of replay closures; sparse EditSession background/layer/content owner-local indexed sequences, exact current placement, narrow direct committed-location facts, exact split committed reference counts plus session deltas, ordered clear/remove/re-add/resource transitions, work observations, and retirement of list/order/location/reference mirrors and scans; DraftDocument direct family membership/element placement/layer lookup, separate owner-local indexed layer/background/content sequences, insertion-ordered keyed descriptors, exact split counts, direct current-state resource decisions, one integrated materialization traversal per requested projection, complete fresh replacement backing and one swap; direct/callback/promoted differential parity for numeric indices, remove/re-add, clear, relationship order, resource transitions, diagnostics, no-op, promotion, and projection exclusion; CommitApplier construction of one immutable accepted-document/selection/base-effect preparation before installation, exact document-changing and selection-only branches, pre-install rollback, post-document-install accepted-state retention, alias closure, and current maintained documentation/ADR state.
Out of Scope: Migration of the accepted active design to `architecture-design/v4` or creation of a Contract Interface; public API or export changes; `StoreSparseCommit`, `StoreSparseMutation`, prepared Store payload, codec/schema/persisted data, validation limits, error taxonomy/message/path/precedence, projection policy, committed rows/orders, Store candidate/editor/finalization/normalization/publication/admission behavior, indexed-sequence algorithm/form, Contract-1 fact lifecycles, architecture graph nodes/edges, asynchronous editing, runtime route-generated-ID use, selected-move resolver behavior, changed-text listener interleaving, route cleanup/effect augmentation, resource/frame/state/action/observer delivery ordering, or callback failure routing after CommitApplier returns. Contract 4 receives only route-generated-ID behavior plus runtime-owned resolver/route cleanup/delivery ordering and cross-owner temporal verification; it cannot be required to compile, repair, or prove any edit/Draft/CommitApplier result in this contract.
Source of Truth: The immutable Store snapshot remains the sole committed truth. During a sparse callback, the ordered `StoreSparseMutation` list alone owns transaction intent; owner-local indexed sequences plus one current element-location view own sparse order/placement; exact committed image/vector counts plus transaction-local deltas own current reference counts; scalar/row/descriptor overlays own only their distinct current values. During materialized editing, one Draft backing owns direct element/layer/placement maps, separate indexed orders, insertion-ordered descriptors, split counts, and scalars; replacement publishes one wholly prepared backing. During apply, one immutable prepared state owns the exact accepted committed document, prepared selection, and sealed CommitApplier-owned base effect/action inputs used by both branches; the final `CommitDeliveryResult` may be assembled from those inputs and the selection-install result without fallible re-preparation. RuntimeRoot remains the sole owner of later route cleanup/effect augmentation and common delivery. No closure journal, list/index dual order, copied committed count inventory, promotion reconstruction, second materialized `CommittedDocument`, rollback clone, or post-install fallible re-preparation remains.
Compatibility: Preserve all public signatures and exports, `StoreSparseCommit`/mutation DTO structure and raw index values, synchronous non-nested callback behavior, exact numeric-index clamping and sequential interpretation, direct/callback/promoted final documents, accepted/no-op classification, final relationship timing and exact diagnostics, touched/revision/admission facts, layer-only clear and preserved background/grid/image/vector descriptors, projection contents/build policy, public state/effects/actions, stale prepared-commit error, forced replacement semantics, immutable committed state, Schema v1/codec output, validation limits, direct Store independence, selection normalization, and architecture dependency direction. The changed observations are removal of the known committed remove/re-add stale/duplicate sparse overlay, bounded internal edit/Draft work, single promotion intent, one atomic Draft backing swap, and one materialized committed value per apply lifetime; no route-generated-ID or runtime delivery behavior changes here.
Order Constraints: U1 atomically introduces the exhaustive Draft DTO consumer, routes promotion through it, and deletes closure replay. U2 and U4 may proceed independently after Contract 2 because their current methods are same-unit consumers. U3 consumes U2's single current placement/order view for every image/vector transition and clear. U5 consumes U1's sole promotion path, U3's completed sparse resource lifecycle, and U4's direct element/placement view to close cross-path semantic/work parity without rebuilding an element inventory. U6 consumes both U4 and U5 completed backing owners and switches existing replacement directly to build-then-swap. U7 is an independent CommitApplier migration placed last topologically; it prepares the accepted document, CommitApplier-owned base effect/action inputs, and selection before the applicable branch, then performs document followed by selection or selection alone. Each unit updates the maintained owner-truth it changes, then supplies nearest owner evidence before becoming authoritative and retires the replaced path in the same unit; no helper, index, DTO consumer, or prepared state waits for a later consumer.
Temporal Surface Closure: Public edit callbacks remain synchronous and non-nested. Promotion occurs only on explicit draft read/replacement and replays the sole DTO journal in order before later materialized mutations. Sparse and Draft mutations interpret each operation against the current state produced by prior operations; relationship validity remains final Store policy, missing-ID updates keep their current immediate short-circuit, and clear is a barrier for later mutations. U7 adds no callback, resolver, listener, stream, microtask, event-loop yield, or public observation: the accepted document, CommitApplier-owned base effect/action inputs, and selection preparation complete before the branch; document-changing apply reaches the unchanged Store stale check and document/admission install before prepared selection; selection-only apply skips Store and installs prepared selection; no-op reaches neither. Infallible result assembly may use the prepared inputs and selection-install outcome after the applicable point. EditKernel handle closure and all RuntimeRoot route/delivery surfaces remain in their current positions and belong to Contract 4 where not already proven as unchanged compatibility.
All-Or-Nothing Failure Boundary: Before the applicable U7 irreversible point, callback, promotion, Draft backing construction, materialized accepted-document preparation, base effect/action input preparation, selection preparation, Store validation, or stale rejection may fail without changing committed document identity/data, revisions, admission/cursor, selection, queued delivery/effects, public state, repaint, spatial/resource state, preview, projection state/count, or alias-visible working state. The document-changing first point is the unchanged Store document install; the selection-only first point is prepared selection install; no-op has none. After document installation, the accepted document, revisions, and admissions are retained if prepared selection installation fails; no rollback/reconstruction is attempted. Runtime route augmentation and delivery callbacks after CommitApplier returns are outside this contract and cannot be used as Unit-7 proof.
Negative Proof And Fixture Quarantine: Runtime behavior, differential traces, alias attempts, semantic owner counters, exact branch events, and bounded producer/consumer inspection are admissible. Existing private helper/body assertions, DTO self-dispatch, final-document equality alone, timing, DCM metrics, fixture row-name inventories, documentation wording, or source-token absence cannot prove journal singularity, work bounds, parity, atomicity, or failure retention. No new feature-local source scanner or copied mutation/API inventory is permitted; any affected existing central allowlist or registry is updated from its owner in the same unit and never becomes product truth.
Bounded Recognition Scope: The contract introduces no analyzer, schema recognizer, generated-output matcher, import scanner, or fixture-recognition architecture. Existing central guardrails and registries remain unchanged unless an actual declaration/artifact moves; any such same-unit update preserves their current bounded target and cannot infer runtime semantics from source text.
Work Budget And Cost Displacement: U1 is work-neutral, not the final performance closure: replacing closures with DTO dispatch preserves one ordered promotion traversal and the same Draft mutations, with zero added copy, scan, projection, replay, or mutation-depth work. Units 2-5 must then eliminate the pre-existing sparse and Draft list/scan costs and close the whole edit lifecycle before this contract can complete. Construction/promotion may perform one authorized whole-owner pass to seed each sparse/Draft order and exact maps/counts; it may not repeat that pass per mutation. Mutation uses expected-`O(1)` direct membership/location/count reads and worst-case `O(log M)` indexed rank changes, with each affected order opened once per owner lifetime and no global count-map clone, accepted-element scan, nested layer scan, or history-depth replay. Explicit Draft read/final materialized preparation may traverse each current owner once and flatten each order once per requested projection; flatten-then-equivalent-rescan is forbidden. U6 replacement validates and builds one fresh full backing and swaps once, with no partial overwrite or clone-back rollback. U7 prepares each accepted materialized document, selection, and CommitApplier-owned base effect/action input once; installation performs only the applicable Store/selection calls and ledger-owned Store work, and later result assembly cannot rebuild those inputs. Sparse session discard and failed Draft replacement drop owner-local buffers without a whole-document rollback copy. Cross-unit owner counters must compose to the design's `O(S + K log M + R)` boundary and cannot move work into promotion, final materialization, selection preparation, install, RuntimeRoot augmentation, or Contract 4.

## Execution Units

### [ ] Unit 1: Make the DTO journal the only sparse promotion intent

Owner: `EditSession` sparse intent/promotion boundary, with `DraftDocument` as the compile-atomic mutation consumer.
Boundary: Allowed production files are `lib/src/edit/edit_session.dart` and `lib/src/edit/draft_document.dart`, plus one cohesive private edit module only if it owns exhaustive `StoreSparseMutation` application and is consumed by promotion in this unit. The existing central accepted-finalization guardrail is an allowed non-production mirror only to remove its private helper/body authority while retaining stable prepared-DTO ownership; it cannot gain a copied mutation inventory. `lib/src/store/sparse_store_commit.dart`, Store dispatch/finalization, public API, runtime routes, indexed-order implementation, and unrelated edit owners are forbidden. Existing sparse/promotion and matrix fixtures are the nearest evidence owners; no copied DTO inventory, general scanner, extra journal traversal, collection copy, element/resource scan, or second replay may be added.
Verification Profile: `REFACTOR`
Change: Add one exhaustive Draft application seam for the unchanged `StoreSparseMutation` hierarchy, switch promotion to replay the existing ordered DTO list through that seam, route every successful pre-promotion mutation through that sole intent journal, and delete the replay-closure journal and equivalent promotion history in the same unit. Preserve the current list-backed Draft mutation work one-for-one during this cutover: one ordered DTO traversal performs the same Draft operations without extra copies, scans, projections, or replay. Migrate the existing accepted-finalization guardrail away from private helper/body authority to its stable prepared-DTO boundary and existing behavioral owners. Update maintained edit/data-model/ADR truth for the sole journal while leaving the existing sparse/Draft list costs explicitly pending for Units 2-5.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `promotion-replays-the-sole-journal` | A sparse session contains mixed successful mutations, no-ops, repeated indices, clear barriers, and later explicit materialization | `readDraftDocument` or `replaceDraftDocument` promotes the session | The promoted Draft state equals sequential application of the exact DTO journal and later mutations use only the materialized backing | No closure/replay history, copied mutation facts, projection during sparse recording, or mutation reordering remains |
| `promotion-dispatch-is-exhaustive` | Every current `StoreSparseMutation` subtype appears in direct deterministic traces, including scalar, resource, clear, update, add/remove, and layer variants | Promotion applies each DTO | Draft observes the same arguments, raw indices, immediate/no-op decisions, and order as the callback and direct Store paths | `StoreSparseCommit` and DTO classes remain byte-structurally unchanged; a future unhandled sealed subtype fails compilation rather than silently skipping |
| `replay-mirror-is-retired` | All producers and consumers of sparse promotion intent are traced after cutover | The unit becomes authoritative | Exactly one ordered mutation list feeds sparse Store preparation and promotion, and obsolete closure/listener replay state is absent | No renamed closure journal, mutation-to-closure adapter, shadow history, or later retirement task survives |
| `sparse-promotion-builds-no-projection` | Sparse recording completes and promotion is requested explicitly | Promotion replays the sole DTO journal | No public committed-document projection is built before explicit Draft materialization, and the promoted Draft remains the working owner | Projection exclusion is observed directly rather than inferred from source tokens |
| `early-journal-cutover-does-not-displace-work` | Current closure promotion and the DTO cutover replay identical mixed traces into list-backed Draft state | Unit 1 switches the authoritative journal | Exactly one DTO traversal invokes the same ordered Draft mutations with no additional collection copy, element/resource scan, projection, replay, or mutation-depth work | This outcome claims work neutrality only; Units 2-5 must still eliminate the existing list/scanning cost before Contract 3 completes |
| `private-shape-guardrail-authority-is-retired` | The accepted-finalization guardrail parses private EditKernel helper names/bodies while Store and owner behavior already own the stable guarantees | Unit 1 changes the promotion/prepared seam | Private helper/body assertions are removed or reduced to the stable prepared-DTO boundary, and semantic journal/finalization guarantees remain in their owning runtime suites | No replacement source scanner, copied helper list, or test-name inventory is introduced |
| `sole-journal-truth-is-current` | Maintained edit/data-model/ADR truth still describes the pre-unit sparse intent lifecycle | Unit 1 completes | The same unit records the DTO journal as sole sparse and promotion intent and removes closure replay from current truth | Indexed/count migrations remain explicitly pending and runtime delivery is unchanged |

Depends On: None

### [ ] Unit 2: Move sparse placement to owner-local indexed orders

Owner: `_SparseEditBacking` structural order and element-location working state.
Boundary: Allowed production files are `lib/src/edit/edit_session.dart`, a cohesive sparse structural module under `lib/src/edit/**`, `lib/src/store/document_store_kernel.dart` only for a narrow direct read of existing committed element-location facts, and `lib/src/runtime/runtime_root.dart` only for the existing private facts adapter. `lib/src/store/indexed_order_sequence.dart` is consumed unchanged; `ElementRegistry`, `LayerTable`, Store candidate policy, resource-count work, DraftDocument backing, public API, and runtime routes are forbidden. Nearest sparse-session evidence lands in the existing owner fixture.
Verification Profile: `BEHAVIOR_CHANGE`
Change: Replace sparse background/layer/per-layer content list order and parallel placement overrides with separate owner-local `IndexedOrderSequence` instances and one current location view, seeded lazily from the same Store snapshot through a narrow authoritative location query. Route ensure/add/remove/remove-re-add/clear/current membership and placement decisions through that state, preserve raw sequential index semantics, and retire list shifts, stale committed-location inference, and equivalent order/location mirrors immediately. Update maintained edit/data-model/ADR structural truth in this unit.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `sparse-placement-is-current` | A committed content or background element is removed, re-added at another placement/index, cleared, and followed by more mutations | Sparse callback operations execute | Every later lookup/removal/clear/promotion observes exactly one current occurrence at its new location and exact current order | Committed location seeds the first mutation; local location is authoritative afterward; no stale base/list overlay remains |
| `sparse-index-semantics-are-exact` | Layer/background/content traces use null, negative, oversized, front/middle/end, and repeated same indices | Sparse order mutations execute sequentially | Results match the current list oracle for clamping, duplicates, order, `first`/`last`, membership, and remove/re-add | Separate orders share implementation code only, never nodes/maps; raw DTO indices remain unchanged |
| `sparse-order-work-is-bounded` | Supported-size sessions vary 200,000 elements, 4,096 layers, affected/unaffected orders, early/late clear, and `K` rank mutations | Sparse structural owner events are observed | Each affected order opens/builds at most once, direct ID/location reads are expected-`O(1)`, rank mutations are worst-case `O(log M)`, and session cleanup performs at most one final/discard traversal | Timing, total event count without phase attribution, Store counters, or end-insert-only traces are rejected |
| `sparse-order-path-is-singular` | Former list/order/location producers and consumers are mapped after migration | Current callbacks and promotion run | Every sparse structural decision reaches the indexed/current-location owner and no list-shift, copied committed order, or parallel placement path remains | Bounded source inspection only proves retirement; semantic/work outcomes prove behavior |
| `sparse-structure-truth-is-current` | Maintained truth still describes sparse list/override placement | Unit 2 completes | The same unit records owner-local indexed orders and one current sparse location view | Count migration remains pending and Store ownership is unchanged |

Depends On: None

### [ ] Unit 3: Make sparse resource decisions count-based

Owner: `_SparseEditBacking` image/vector reference-count delta and current resource decision state.
Boundary: Allowed production files are `lib/src/edit/edit_session.dart`, a cohesive sparse reference module under `lib/src/edit/**`, `lib/src/store/document_store_kernel.dart` only for narrow direct reads of the existing committed split summaries, and `lib/src/runtime/runtime_root.dart` only for the existing private facts adapter. Contract-1 family/count maintenance, Store candidate/reference policy, DraftDocument, public API, codec, and runtime routes are forbidden. Existing sparse, clear, matrix, and no-op fixtures are the nearest evidence owners.
Verification Profile: `REFACTOR`
Change: Expose exact committed image and vector counts through the existing private facts seam, maintain transaction-local deltas for every successful add/remove/update/resource-ID transition/remove-re-add and clear barrier using Unit-2 current placement, answer `removeUnusedResource` from the current logical count, preserve resource membership/order/touched semantics, and retire override/all-accepted-element reference scans and copied count inventories. Update maintained edit/data-model/ADR sparse-count truth in this unit.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `sparse-image-counts-are-exact` | Image rows reference present or missing descriptors and undergo add/remove/resource-ID update/remove-re-add/clear transitions | Sparse mutations update logical references | Each queried image count equals an independent direct current-row count after every successful transition | Descriptor upsert/removal does not change counts; failed/no-op mutations do not change deltas |
| `sparse-vector-counts-are-exact` | Equivalent vector-only and mixed image/vector traces run | Sparse mutations update logical references | Each vector count and the summed logical reference decision are exact independently of image state | Same-ID cross-family transitions adjust the correct split summaries once |
| `sparse-resource-decisions-are-current` | `removeUnusedResource` occurs before/after referring row remove, update, re-add, clear, descriptor replacement, and missing-descriptor transitions | Callback executes in journal order | Removal/no-op, touched facts, revisions, descriptor order, and later mutation observations match the sequential oracle | Relationship validation remains Store-final; no eager rejection or callback-owned Store policy appears |
| `background-image-reference-survives-clear` | A preserved background image references a descriptor while ordinary content is cleared with cleanup | Sparse clear executes | The descriptor remains and only actually unreferenced descriptors appear in clear results/touched facts | Background order/state remain unchanged and no element/full-frame scan is used per descriptor |
| `background-vector-reference-survives-clear` | A preserved background vector independently references a descriptor under the same clear | Sparse clear executes | The vector descriptor remains with exact actual-removal facts | Image-only evidence cannot satisfy this outcome |
| `sparse-reference-work-is-bounded` | Many-resource and supported-size traces vary `K`, changed resource IDs, missing descriptors, mixed families, and clears | Reference work events are observed | Each transition performs constant-depth split-count work; queries are direct; no accepted-element scan, global summary clone, mutation-chain walk, or per-resource structural pass occurs | Counters identify image/vector/base/delta phases and cannot be inferred from returned booleans |
| `sparse-count-truth-is-current` | Maintained truth still describes sparse reference scans or non-exact local resource state | Unit 3 completes | The same unit records committed split summaries plus transaction-local deltas as current sparse reference truth | Contract-1 committed summary owners remain closed |

Depends On:
- Unit 2 — produces: one authoritative sparse current placement/order view; consumed as: the sole classification source for image/vector transitions, remove-re-add, and clear barriers

### [ ] Unit 4: Move Draft structure to direct indexed backing

Owner: `DraftDocument` structural membership, placement, and order backing.
Boundary: Allowed production files are `lib/src/edit/draft_document.dart` and cohesive private Draft structural modules under `lib/src/edit/**`. `lib/src/store/indexed_order_sequence.dart` is consumed unchanged. Sparse backing, Store facts/candidate, descriptor/count migration, replacement swap, public API, codec/load owners, and runtime routes are forbidden. Existing materialized, promotion, clear, matrix, update, and no-op fixtures own nearest evidence.
Verification Profile: `REFACTOR`
Change: Replace Draft layer/background/content lists and nested element/layer lookup with direct layer and element maps, one current placement view, and separate owner-local indexed sequences for layer, background, and each content order. Route ensure/add/update/remove/clear/summary/materialization through that single structural backing, preserve exact order and touched semantics, flatten each order once per explicit materialization, and retire list shifts, nested scans, and duplicate structural inventories. Update maintained edit/data-model/ADR Draft-structure truth in this unit.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `draft-structural-facts-are-direct` | Materialized edits mix layer admission, background/content add, update, remove/re-add, clear, selection pruning, and summary reads | Draft mutations and queries execute | Membership, element lookup, layer lookup, placement, counts, touched facts, and final order all read one current backing | No mutable collection is shared with Store, caller input, another Draft, or sparse session |
| `draft-index-semantics-are-exact` | Raw index traces cover null, negative, oversized, repeated same-index and all placement kinds | Draft rank mutations execute | Final order and every intermediate lookup match the independent list oracle exactly | Separate sequences retain mutable isolation and direct ID/rank parity |
| `draft-structure-work-is-bounded` | 200,000-element/4,096-layer traces vary front/middle/end operations, affected/unaffected orders, clear, compensation, and explicit reads | Draft structural work is observed | Construction opens each owner once, direct queries avoid nested scans, mutations are logarithmic, and each requested materialization visits/flattens each order once | Explicit repeated public reads may each materialize current state once; no flatten-then-rescan or timing proxy is allowed |
| `draft-list-paths-are-retired` | All Draft structural producers/consumers are mapped after cutover | Materialized and promoted edits run | No list-shift, layer `indexWhere`, nested element scan, or parallel placement/order path remains | Ordered output lists inside the public `CanvasDocument` are final projections, not mutable working truth |
| `draft-structure-truth-is-current` | Maintained truth still describes list-owned Draft structure | Unit 4 completes | The same unit records direct maps, current placement, and separate owner-local indexed orders as Draft structural truth | Resource/count and replacement work remain pending |

Depends On: None

### [ ] Unit 5: Make Draft resources keyed and count-owned

Owner: `DraftDocument` descriptor order/lookup and split image/vector reference counts.
Boundary: Allowed production files are `lib/src/edit/draft_document.dart` and cohesive private Draft resource modules under `lib/src/edit/**`; Unit-4 structural lookup is consumed but not duplicated. Sparse backing, Store reference summaries/editor, replacement swap, public API, codec/load, CommitApplier, command/action production, spatial production, and runtime routes are forbidden. Existing edit-matrix, materialized, clear, no-op, update, projection, command/action, and direct-spatial fixtures are the nearest evidence owners.
Verification Profile: `REFACTOR`
Change: Replace the resource list with one insertion-ordered keyed descriptor owner, build exact Draft-local image/vector counts from Unit-4 current rows, update the split counts on every successful element transition and clear, route upsert/remove-unused/resource touch decisions through direct descriptor/count reads, preserve descriptor order and final relationship timing, and retire descriptor `indexWhere`, all-element reference scans, and equivalent mirrors. Close full direct/callback/promoted semantic and composed-work parity after both sparse and Draft migrations, and update maintained edit/data-model/ADR resource lifecycle truth in this unit.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `draft-image-counts-are-exact` | Materialized/promoted image traces cover missing descriptors, add/remove/update/remove-re-add/clear and descriptor-only edits | Draft state changes | Current image counts equal an independent row count after each successful transition and drive exact visual/touched decisions | No scan or descriptor mutation updates count incorrectly |
| `draft-vector-counts-are-exact` | Equivalent vector-only and same-ID cross-family traces run | Draft state changes | Vector counts remain independently exact and sum with image counts only at the logical query | A passing image path cannot mask a vector drift |
| `draft-resource-state-is-singular` | Descriptors are inserted, replaced, removed, reinserted, cleared, and materialized | Draft resource operations execute | One keyed insertion-order owner determines membership, lookup, output order, and current descriptor value | No resource list, secondary ID set, copied order, or synchronization glue remains |
| `draft-resource-decisions-are-current` | `removeUnusedResource` and clear occur before/after referring row transitions in both mutation orders | Materialized/promoted operations run | Results, descriptor order, touched/revision facts, relationship diagnostics, and no-ops match the sequential oracle | Final relationship validation remains Store-owned and either resource/element callback order remains valid |
| `draft-resource-work-is-bounded` | Many-resource supported-size traces vary changed descriptors, missing references, mixed families, early/late clear, and compensation | Draft resource work is observed | Descriptor lookup/update is direct, reference transitions/queries are constant-depth, one materialization emits descriptor order once, and no row scan or global count clone occurs per mutation/resource | Owner/phase counters, not latency or final equality, are required |
| `edit-paths-have-exact-parity` | Identical deterministic and seeded shrinkable traces include remove/re-add, repeated indices, both relationship orders, missing/wrong-kind diagnostics, image/vector clear retention, no-op compensation, promotion before/after clear, and later mutation | The trace runs through direct `StoreSparseCommit`, sparse callback, and promoted Draft | Complete final document/order, accepted delta/touched/admission facts, exact first exception/code/message/path, results, and projection counts agree | The oracle is simple and independent; no implementation-generated expectations, final equality alone, or one-path proxy is accepted |
| `aggregate-edit-work-is-bounded` | Supported-size direct, callback, and promoted traces exercise sparse mutation, promotion, Draft mutation, and final materialization | Owner-attributed work observations are composed across the complete edit lifecycle | Total work fits one initial owner pass plus affected-order logarithmic mutations and direct resource work, with no repeated projection, rebuild, scan, copy, or history replay moved between owners | Phase attribution distinguishes sparse, promotion, Draft, materialization, and Store work; timing and aggregate totals without attribution are rejected |
| `clear-command-results-and-actions-remain-actual` | A document contains ordinary removable rows, preserved background image/vector rows, referenced and unused descriptors, and a command-action listener | Command clear runs after the backing migrations | Result and clear action contain exactly actual removed ordinary element/resource IDs, preserved background IDs never appear, and resource-only/no-op branches retain their current action behavior | Command/action production is unchanged and cannot serve as an edit-policy repair layer |
| `clear-spatial-background-remains-queryable` | A preserved background element and ordinary content are present in committed spatial state | Command clear runs and runtime delivery observes the accepted result | Direct spatial queries retain the background candidate before publication while removed ordinary content is absent | Spatial production/delivery order is unchanged and Contract 4 is not required to restore the candidate |
| `draft-resource-truth-is-current` | Maintained truth still describes descriptor lists and Draft element scans | Unit 5 completes | The same unit records the insertion-ordered keyed descriptor owner, split counts, and completed three-path semantic/work closure | Store descriptor/reference policy remains unchanged and all Contract-3 edit costs are now closed |

Depends On:
- Unit 1 — produces: the sole DTO journal and exhaustive promotion consumer; consumed as: the only promotion path exercised by cross-path semantic and work closure
- Unit 3 — produces: sparse exact resource decisions over Unit-2 placement; consumed as: the completed sparse path compared with Draft and direct Store
- Unit 4 — produces: one direct current Draft element/placement/structural view; consumed as: the sole row-transition and clear classification source for Draft split counts

### [ ] Unit 6: Swap Draft replacements as one complete backing

Owner: `DraftDocument` replacement backing construction and publication boundary.
Boundary: Allowed production files are `lib/src/edit/draft_document.dart` and the private Draft backing modules completed by Units 3-4. Existing `ValidatedImportDraft` and staged-load preparation are consumed unchanged. Sparse session state, Store candidate/import/load behavior, public API, codec/schema, CommitApplier, selection, and runtime routes are forbidden. Replacement, rollback, alias, materialized finalization, and promotion fixtures own nearest evidence.
Verification Profile: `REFACTOR`
Change: Build scalars, direct structural maps/sequences, keyed descriptors, split counts, selection-validity facts, and replacement revision/touched state into one fresh Draft backing after existing validation succeeds; swap that complete backing once; retain the previous backing on every construction failure; make the retired backing unreachable; and delete incremental multi-field clear/refill replacement logic and any clone-back rollback path. Update maintained edit/data-model/ADR replacement truth in this unit.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `draft-replacement-swaps-atomically` | A changed Draft receives valid, invalid, equivalent, supported-size, and failure-injected replacement documents | `replaceDraftDocument` prepares the replacement | Validation/construction failure leaves every prior scalar/row/order/descriptor/count/revision/touched/selection fact unchanged; success exposes one complete replacement backing | No partial field overwrite, repair pass, clone-back, or mixed old/new observation occurs |
| `draft-replacement-is-isolated` | Caller collections and old/new backing handles available at owner test seams are retained and mutated after failure/success | Replacement returns or throws | Caller and retired backing aliases cannot mutate the active Draft; active maps/orders/descriptors/counts remain exact | Mutable Store owners are never shared and post-swap writes to retired state reject or are unreachable |
| `draft-replacement-semantics-are-preserved` | Equivalent and changed replacements exercise duplicate/relationship validation, selection pruning, revisions, forced replacement effects, materialization, and later mutations | Replacement succeeds | Current exact replacement diagnostics and forced-replacement plan/effect behavior remain, and later operations observe only the new backing | Store materialized finalization remains authoritative and no public/schema behavior changes |
| `draft-replacement-truth-is-current` | Maintained truth still describes incremental multi-field Draft replacement | Unit 6 completes | The same unit records complete backing construction followed by one swap and retention of the prior backing on failure | Validation/load owners remain unchanged |

Depends On:
- Unit 4 — produces: complete direct structural backing construction; consumed as: the structural half of the fresh replacement backing
- Unit 5 — produces: complete keyed descriptor and split-count backing construction; consumed as: the resource half of the fresh replacement backing

### [ ] Unit 7: Prepare once and close both CommitApplier install branches

Owner: `CommitApplier` accepted apply lifetime and document/selection installation seam.
Boundary: Allowed production files are `lib/src/edit/commit_applier.dart`, cohesive private apply-state code under `lib/src/edit/**`, and `lib/src/runtime/runtime_root.dart` only for compile-atomic accepted-document selection preparation/installer wiring. Internal `commit_delivery.dart` may change only to seal CommitApplier-owned base effect/action inputs or assemble the unchanged base result without changing consumers; RuntimeRoot route cleanup/effect augmentation remains forbidden. `EditKernel` accepted-document public-independent variants may be adjusted only when compile-atomic and without changing Store prepared DTOs. Store installers/candidate, SelectionKernel policy, public API, runtime routes/cleanup/delivery, generated IDs, resolver/listener/action/observer behavior, and architecture graph are forbidden. Existing selection-effect, rollback, no-op, accepted-interaction, and Store stale fixtures own nearest evidence.
Verification Profile: `REFACTOR`
Change: Prepare one immutable apply state before either branch: materialize an accepted full document at most once, use that exact value for selection normalization and installation, prepare immutable base effect/action inputs and prepared selection before mutation, and retain immutable aliases. Then execute exactly one of document install followed by prepared selection install, prepared selection install alone, or no-op. Preserve the unchanged Store stale boundary, retain accepted document/admission state on any later prepared-selection installation failure, perform no rollback after installation, and update only the CommitApplier branch portion of maintained edit/data-model/ADR truth in this unit while Contract-4 runtime augmentation/delivery remains pending.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `materialized-apply-state-is-prepared-once` | Forced replacement, prepared materialized, sparse prepared, unchanged-document, and selection-only accepted variants are applied | CommitApplier prepares the accepted document, base effect/action inputs, and selection | Each required committed document value is constructed/read once and the identical immutable value feeds selection normalization and installation | No post-install document or selection reconstruction and no fallible base-effect re-preparation, projection, mutable alias, or duplicate full-document pass occurs |
| `document-changing-install-order-is-exact` | A plan changes the document with and without a selection effect, including stale Store input | The prepared apply state installs | Preparation events precede stale check; successful events are document/admission then optional prepared selection; stale failure occurs before both installs | Store installer and ledger semantics are unchanged; no callback/yield/fallible re-preparation appears between installs |
| `selection-only-install-order-is-exact` | A plan replaces or prunes selection with no revision delta, including effective and no-op selection | The prepared apply state installs | Events are preparation then selection only; Store installers are never invoked; first irreversible point is the effective selection install | No document revision/projection/spatial/resource mutation or fake Store no-op call occurs |
| `preinstall-failure-preserves-state` | Failures occur during materialized construction, base effect/action input preparation, selection preparation, Store preparation, and stale admission | Apply throws before its applicable first point | Document identity/data, all revisions, admission/next IDs, selection, delivery/effect/action buffers, public state, repaint, spatial/resource, projection count, and alias-visible state equal the snapshot | Original exception/signal is preserved and no cleanup mutation or rollback copy is used |
| `postinstall-failure-retains-accepted-state` | Document installation succeeds and prepared selection installation fails | Apply throws after document first point | Accepted document/revisions/admission remain installed, selection reflects only work completed before its failure, and no prior state is restored | CommitApplier result assembly is infallible from sealed inputs; Runtime route augmentation and delivery failures remain Contract 4 and may not roll back accepted state |
| `apply-noop-has-no-irreversible-point` | Plan and accepted document contain no effective document or selection change | CommitApplier applies it | No preparation-dependent mutation, Store/selection install, delivery effect, action, or publication occurs | Existing silent no-op and compensating edit behavior remains exact |
| `prepared-apply-state-is-isolated` | Caller documents, plan collections, prepared Store payloads, and prepared selection/effect views are retained and mutated where the API permits attempts | Preparation and install complete or fail | The applied document, selection input, and returned base delivery result remains immutable and internally consistent | Unmodifiable wrappers over live mutable storage, identity-only checks, and source tokens are rejected |
| `direct-store-remains-independent` | All edit and apply migrations are complete while the unchanged direct sparse Store entry point remains available | Direct Store commits run without edit/runtime participation | Direct Store journal, finalization, diagnostic, work, alias, publication, and install behavior remains exactly owned by the completed Store path | No edit adapter compensates for, bypasses, or reimplements Contract-1/2 owners |
| `compatibility-surfaces-remain-unchanged` | The final Contract-3 diff is inspected across public, DTO, codec, validation, projection, graph, registry, and runtime boundaries | All seven units are complete | Only authorized private edit, narrow fact/adapter, owning verification, and maintained-truth surfaces changed; excluded interfaces and behavior remain exact | Green local edit tests alone cannot prove compatibility |
| `contract-four-remains-runtime-owned` | Contract 3 is complete and its remaining work is enumerated | The next ordered boundary is inspected | Contract 4 contains only route-generated-ID behavior, resolver/route cleanup/delivery ordering, and cross-owner temporal verification | Contract 4 is not needed to compile, pass edit/CommitApplier owner evidence, or restore obligatory behavior |
| `commit-apply-truth-is-current` | Maintained truth still permits duplicate materialized preparation or leaves the two irreversible branches implicit | Unit 7 completes | The same unit records one accepted-document/selection/base-effect preparation and exact document-changing versus selection-only install points | Runtime route augmentation and delivery remain explicitly pending |

Depends On: None

## Verification Matrix

| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | Pass signal | Evidence constraints and rejected proxy | Adversarial false-positive case and kill signal | Durable impact | Artifact target | Admission |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `sole-journal-promotion-evidence` | `promotion-replays-the-sole-journal`, `promotion-dispatch-is-exhaustive` | `TEST` | Extend `test/edit/sparse_edit_session_test.dart` owner fixture with complete DTO traces and injected closure/DTO-divergence characterization before retirement. | Current production records closures and DTOs separately at `edit_session.dart:338-340` and promotion consumes only closures. | Every mutation variant and mixed trace promotes from DTOs with exact callback/direct results; mutation hierarchy exhaustiveness is compile-checked. | Direct promoted state plus exact trace inputs is admissible; final equality for one trace, Store dispatch, or a copied subtype list is rejected. | Promotion still calls closures while a DTO test helper invokes the new seam separately; both tests pass alone, but a deliberately divergent callback/DTO argument produces different promoted order and kills it. | `EXTEND_COVERAGE` | Existing `test/edit/fixtures/sparse_edit_session_fixture.dart` | `journal-promotion-admission` |
| `early-journal-work-evidence` | `early-journal-cutover-does-not-displace-work` | `TEST` | Extend the sparse promotion owner fixture with owner/phase events comparing current closure replay and DTO dispatch for identical list-backed Draft traces. | No current evidence distinguishes one-for-one dispatch from an adapter that pre-copies, scans, projects, or replays before applying the same operations. | One DTO pass emits the same ordered Draft mutation events with zero added collection-copy, element/resource-visit, projection, secondary-replay, or history-depth events. | Owner/phase semantic work events are admissible; final Draft equality, elapsed time, DTO count alone, or later indexed-owner counters are rejected. | DTO dispatch first copies the journal and scans Draft resources, then applies every operation correctly; semantic parity passes while copy/visit events kill the displacement. | `EXTEND_COVERAGE` | Existing `test/edit/fixtures/sparse_edit_session_fixture.dart` | `early-journal-work-admission` |
| `replay-retirement-evidence` | `replay-mirror-is-retired` | `SOURCE_QUERY` | Bounded producer/consumer mapping of sparse intent across `edit_session.dart`, Draft application, EditKernel promotion, and fixtures after U1. | Two production journals and closure producers exist. | One DTO list is the only intent producer consumed by Store and promotion; closure replay and equivalent renamed histories are absent. | Complete data-flow inspection is admissible; token search, runtime semantics, or a permanent scanner is rejected. | `_journal` is deleted but DTOs are converted into retained closures at promotion-open time; name search passes while producer/consumer tracing exposes the second history and kills it. | `NONE` | None | None |
| `accepted-finalization-guardrail-retirement-evidence` | `private-shape-guardrail-authority-is-retired` | `SOURCE_QUERY` | Reduce `test/guardrails/edit_accepted_finalization_guardrail_test.dart` to the stable prepared-DTO boundary or remove assertions already owned by direct Store and edit behavior suites. | The guardrail currently parses `_acceptedCommitFor`, `_prepareMaterializedCommit`, `_prepareSparseCommit`, branch body substrings, and private compilation shape. | No private helper name/body remains authoritative; any retained guardrail assertion observes only the stable prepared-DTO seam, while direct Store/edit suites own finalization and promotion semantics. | Final guardrail diff plus owning behavioral routes is admissible; renaming tokens, replacing one helper inventory with another, or leaving source assertions as fallback is rejected. | Private helper assertions move to a new scanner helper or copied inventory and continue passing; bounded producer/consumer review finds the private-body dependency and kills it. | `REDUCE_OR_REMOVE` | Existing `test/guardrails/edit_accepted_finalization_guardrail_test.dart` | None |
| `sparse-order-semantic-evidence` | `sparse-placement-is-current`, `sparse-index-semantics-are-exact` | `TEST` | Existing sparse session fixture with sequential list/map oracle, committed location facts, remove/re-add across background/content/layers, clear, promotion, and raw index matrices. | Current list/override state can infer stale committed placement after remove/re-add and uses linear rank mutation. | Every intermediate and final placement/order/result matches the independent oracle with one current occurrence and exact numeric semantics. | Intermediate location/order and result observations are admissible; final ID set, Store order, or self-audit alone is rejected. | Re-add inserts the new occurrence but leaves the removed committed occurrence in an unopened content order; final membership passes while later clear/promotion order exposes the duplicate and kills it. | `EXTEND_COVERAGE` | Existing `test/edit/fixtures/sparse_edit_session_fixture.dart` | `sparse-order-semantics-admission` |
| `sparse-order-work-evidence` | `sparse-order-work-is-bounded` | `TEST` | Sparse owner work events for sequence open/build, ID/location query, node visits, flatten/discard across supported-size front/middle/end and clear traces. | Current callback order uses `List.insert`, `List.remove`, `contains`, and copied lists. | Per-order opens/builds are at most one, rank visits are logarithmically bounded, direct queries do constant map work, and no `K`-multiplied flatten/scan occurs. | Owner/phase counters at exact supported size are admissible; wall time, AVL private rotation counts, aggregate totals, or Store sequence tests alone are rejected. | A wrapper builds a fresh indexed sequence from the current list for every mutation; semantics and logarithmic operation counters pass, while repeated build/open visits kill it. | `EXTEND_COVERAGE` | Existing sparse edit owner fixture family under `test/edit/**` | `sparse-order-work-admission` |
| `sparse-order-retirement-evidence` | `sparse-order-path-is-singular` | `SOURCE_QUERY` | One-off bounded final data-flow inspection of sparse structural fields/producers/consumers. | List orders and multiple placement override collections are current production state. | Only indexed orders and one current placement view answer structural decisions; list-shift/copy and parallel location paths are absent. | Data-flow inspection is admissible; field-name absence or behavior/work claims from source alone are rejected. | Lists are renamed to queues and kept synchronized from the sequence for clear; semantic tests pass, while consumer tracing finds clear reading the mirror and kills it. | `NONE` | None | None |
| `sparse-image-count-evidence` | `sparse-image-counts-are-exact`, `background-image-reference-survives-clear` | `TEST` | Sparse deterministic/seeded image transitions and layer-only clear compared after every operation to an independent current-row image count. | Current sparse reference logic scans overlays/all accepted elements and has no exact image delta owner. | Image counts, remove-unused decisions, retained background descriptor, touched/revision/result facts, and later promotion match the oracle. | Direct per-step image count/result observations are admissible; boolean reference only, vector case, final document, or Store summary self-check is rejected. | Image delta is updated on add/remove but not `resourceId` update; clear-only tests pass while remove-unused after update returns the wrong result and kills it. | `EXTEND_COVERAGE` | Existing sparse edit owner fixture family under `test/edit/**` | `sparse-image-count-admission` |
| `sparse-vector-count-evidence` | `sparse-vector-counts-are-exact`, `background-vector-reference-survives-clear` | `TEST` | Independent vector-only, mixed-family, same-ID resource and clear transitions against a direct vector row-count oracle. | Current facts expose only a summed boolean and vector transitions are not directly count-falsified. | Vector counts and descriptor retention/removal remain exact independently from image state. | Direct vector counts and results are admissible; image parity, summed total alone, or one retained descriptor is rejected. | Image count masks an underflowing vector delta for the same resource; summed referenced stays true, while vector-only removal/clear oracle kills it. | `EXTEND_COVERAGE` | Existing sparse edit owner fixture family under `test/edit/**` | `sparse-vector-count-admission` |
| `sparse-resource-order-evidence` | `sparse-resource-decisions-are-current` | `TEST` | Ordered remove-unused/resource/element transition matrix including both mutation orders, missing descriptors, remove/re-add, clear barriers, compensation, and exact touched diagnostics. | Current fallback behavior can scan stale accepted/local overlays and its work is not tied to one count state. | Each immediate decision and final accepted/no-op/diagnostic result matches the sequential oracle in journal order. | Per-operation decisions plus final Store acceptance are admissible; only final document or one relationship order is rejected. | Counts are correct at final state but updated after `removeUnusedResource`; final document can compensate, while the immediate result/touched trace kills it. | `EXTEND_COVERAGE` | Existing sparse edit and matrix fixture owners | `sparse-resource-order-admission` |
| `sparse-reference-work-evidence` | `sparse-reference-work-is-bounded` | `TEST` | Split base/delta/query/transition counters for many-resource supported-size sparse traces. | Current `_isResourceReferenced` scans `_elementOverrides` and may scan all accepted elements. | Constant-depth split-count events occur per affected transition/query; accepted-element visits, full count-map copies, and history-depth walks are zero. | Semantic owner counters are admissible; elapsed time, correct booleans, Store family counters, or total allocations are rejected. | A cached boolean avoids scans after first query but rebuilds from all elements after each mutation; returned results pass while row-visit events kill it. | `EXTEND_COVERAGE` | Existing sparse edit owner fixture family under `test/edit/**` | `sparse-reference-work-admission` |
| `draft-structure-semantic-evidence` | `draft-structural-facts-are-direct`, `draft-index-semantics-are-exact` | `TEST` | Materialized and promoted Draft traces against independent list/map oracle with direct lookup, remove/re-add, clear, selection, and raw indices. | Current Draft uses lists, layer `indexWhere`, and nested element scans. | Every intermediate lookup/result/touched fact and final public order matches the oracle with independent owner-local instances. | Direct Draft observations are admissible; sparse path, sequence self-test, or final document alone is rejected. | Element map is direct but location/order is updated only on add, not remove/re-add; ordinary lookup passes while later remove/clear order kills it. | `EXTEND_COVERAGE` | Existing `test/edit/fixtures/sparse_edit_session_fixture.dart` and materialized edit fixture owner | `draft-structure-semantics-admission` |
| `draft-structure-work-evidence` | `draft-structure-work-is-bounded` | `TEST` | Draft owner counters at 200,000 elements/4,096 layers for construction, queries, rank mutations, clear, materialization, and discard. | Current Draft performs list shifts, nested scans, fold counts, and repeated list materialization. | One construction pass, direct lookup, logarithmic rank visits, and one per-order traversal per requested projection are observed with no displaced scan. | Phase-attributed counters are admissible; timing, sparse counters, final output size, or a single end-insert trace is rejected. | Direct maps exist but `_materialize` performs one flatten then scans layers again for counts/locations; semantics pass while second-pass visits kill it. | `EXTEND_COVERAGE` | Existing materialized Draft fixture family under `test/edit/**` | `draft-structure-work-admission` |
| `draft-structure-retirement-evidence` | `draft-list-paths-are-retired` | `SOURCE_QUERY` | Bounded producer/consumer inspection of Draft structural state and public projection construction. | Lists and nested scans own current Draft structure. | Indexed/direct backing is the only mutable truth; lists remain only immutable/public output values. | Data-flow inspection is admissible; source tokens or runtime performance claims are rejected. | A hidden list mirror feeds summary while sequence feeds output; order tests pass, but summary consumer mapping exposes and kills it. | `NONE` | None | None |
| `draft-image-count-evidence` | `draft-image-counts-are-exact` | `TEST` | Materialized/promoted image transition oracle with per-step counts, resource decisions, touched facts, and missing descriptors. | Draft `_isResourceReferenced` scans all elements and has no split summary. | Exact image counts drive every current decision with no drift across update/remove/re-add/clear. | Direct count/result evidence is admissible; sparse counts, summed boolean, or final document only is rejected. | Image count is rebuilt only at materialization, so final output is correct but immediate remove-unused is wrong and kills it. | `EXTEND_COVERAGE` | Existing materialized/promotion fixture owners under `test/edit/**` | `draft-image-count-admission` |
| `draft-vector-count-evidence` | `draft-vector-counts-are-exact` | `TEST` | Independent vector-only and mixed-family per-step count oracle including preserved background vector clear. | Existing clear visits background rows but does not own a maintained vector count. | Vector counts and all descriptor retention/removal decisions remain exact independently from images. | Direct vector observations are admissible; image or summed-only evidence is rejected. | Shared total count is correct but vector decrement is applied to image delta; mixed cases pass while vector-only query kills it. | `EXTEND_COVERAGE` | Existing materialized/promotion fixture owners under `test/edit/**` | `draft-vector-count-admission` |
| `draft-resource-owner-evidence` | `draft-resource-state-is-singular`, `draft-resource-decisions-are-current` | `TEST` | Descriptor insertion/replacement/removal/reinsert/clear and both relationship orders with exact output order, results, touched/revisions, and diagnostics. | Current descriptor list requires `indexWhere` and element scans. | One keyed insertion-order owner supplies exact current descriptors and output order; decisions match the sequential oracle. | Direct descriptor/order/results are admissible; map key equality, final relationship success, or source type is rejected. | A map supplies lookup but a retained list supplies output and misses reinsert order; membership passes while final descriptor order kills it. | `EXTEND_COVERAGE` | Existing edit matrix/materialized/promotion fixtures | `draft-resource-owner-admission` |
| `draft-resource-work-evidence` | `draft-resource-work-is-bounded` | `TEST` | Many-resource Draft counters for keyed operations, split transitions, clear, compensation, and materialization. | Current resource update/remove and reference query are linear and clear performs whole passes without exact owner attribution. | Direct keyed/count events are constant-depth per mutation and one descriptor-order traversal occurs per requested materialization/authorized clear. | Owner/phase counters are admissible; timing, returned results, sparse counters, or projection count alone is rejected. | Lookup is direct but every count update clones the whole count map; semantics pass while copy-entry counters kill it. | `EXTEND_COVERAGE` | Existing materialized Draft fixture family under `test/edit/**` | `draft-resource-work-admission` |
| `three-path-parity-evidence` | `edit-paths-have-exact-parity` | `TEST` | Extend existing direct Store and edit fixtures with one shared simple trace description applied independently to direct, callback, and promoted paths. | Current tests cover selected cases but no one oracle falsifies all three paths after journal/index/count cutovers. | Complete observables agree for seeded/shrunk traces and all named exact counterexamples. | Independent expected semantics and complete observables are admissible; implementation replay as oracle, final equality, callback-only, or test-name parity is rejected. | All paths use the same flawed helper for expectations and behavior; self-consistency passes, while the simple list/map expected result differs and kills it. | `EXTEND_COVERAGE` | Existing `test/edit/fixtures/sparse_edit_session_fixture.dart` plus direct Store fixture owner | `three-path-parity-admission` |
| `clear-command-action-evidence` | `clear-command-results-and-actions-remain-actual` | `TEST` | `flutter test test/api/command_port_actions_test.dart` | Not required: the existing command owner directly observes result/action IDs, preserved background image/vector rows and descriptors, resource-only cleanup, and no-op action behavior. | The file exits 0 unchanged after Units 1-5, with result/action payloads containing actual removals only and preserved background IDs absent. | Direct command result, action payload, retained document rows/descriptors, and no-op/resource-only observations are admissible; edit touched facts, final document alone, or source inspection is rejected. | Edit clear reports a preserved background descriptor as removed while Store keeps it; final document passes, but command result/action payload IDs kill the drift. | `NONE` | None | None |
| `clear-spatial-background-evidence` | `clear-spatial-background-remains-queryable` | `TEST` | `flutter test test/spatial/runtime_delivery_order_test.dart` | Not required: the existing runtime spatial owner observes retained background candidates before publication on command clear. | The file exits 0 unchanged after Units 1-5; direct spatial queries retain the background candidate and exclude removed ordinary content before publication. | Direct spatial query/order events are admissible; edit touched facts, final committed rows, source queries, or later observer state alone is rejected. | Clear touched facts omit or misclassify the background so runtime spatial state empties before publication; document equality passes while the direct candidate query kills it. | `NONE` | None | None |
| `promotion-projection-evidence` | `sparse-promotion-builds-no-projection` | `TEST` | `flutter test test/store/no_projection_hot_path_test.dart test/edit/sparse_edit_session_test.dart` | Not required: existing suites already observe sparse projection exclusion; migration can accidentally project during promotion setup. | Both files exit 0 with zero projection builds before explicit Draft read and unchanged explicit materialization behavior. | Direct projection build counts are admissible; absence of `readDocument` source text or final document equality is rejected. | Promotion reads the public document once before the explicit materialization observation but caches it; output passes while projection count becomes nonzero and kills it. | `NONE` | None | None |
| `aggregate-edit-work-evidence` | `aggregate-edit-work-is-bounded` | `TEST` | Existing sparse/materialized promotion work fixtures compose owner- and phase-attributed counters across supported-size lifecycle traces. | Individual owners can satisfy local bounds while rebuilding or rescanning the same state at promotion/materialization handoff. | Sparse, promotion, Draft, materialization, and Store phase totals compose to `O(S + K log M + R)` with one authorized owner pass and no displaced repeated work. | Exact owner/phase counters at supported size are admissible; elapsed time, final equality, or unpartitioned totals are rejected. | Sparse counters are bounded but promotion rebuilds every order and count before Draft work begins; local suites pass while the promotion phase visits kill it. | `EXTEND_COVERAGE` | Existing sparse and materialized edit work fixture owners | `aggregate-edit-work-admission` |
| `draft-replacement-atomicity-evidence` | `draft-replacement-swaps-atomically`, `draft-replacement-semantics-are-preserved` | `TEST` | Existing rollback/replacement owner with failure injection at validation, scalar, structural, descriptor, count, and final backing construction plus equivalent/changed acceptance. | Current `replaceDocument` writes fields and clears/refills collections incrementally after validation. | Every pre-swap failure preserves exact prior Draft/committed state; success performs one backing swap and retains forced replacement semantics. | Direct before/after Draft facts, events, and public effects are admissible; exception presence, final committed equality, or clone-back is rejected. | Construction fails after resources were replaced but before layers; a clone-back hides final public state, while retained old backing identity/counter/event observations expose and kill it. | `EXTEND_COVERAGE` | Existing `test/edit/fixtures/rollback_fixture.dart` and Draft replacement fixture owner | `draft-replacement-atomicity-admission` |
| `draft-replacement-alias-evidence` | `draft-replacement-is-isolated` | `TEST` | Retained caller inputs, old/new backing handles at test seam, exposed views, post-failure and post-swap mutation attempts. | Current replacement copies some values but mutates retained Draft collections in place; full backing isolation is not proven. | Active Draft state cannot be mutated through caller/retired aliases; old backing is unreachable/closed and new backing remains coherent. | Mutation attempts and identity/state observations are admissible; unmodifiable type/source tokens or GC assumptions are rejected. | New maps are unmodifiable views over caller lists; immediate tests pass, later caller mutation changes order/count and kills it. | `EXTEND_COVERAGE` | Existing Draft replacement/rollback fixture owner | `draft-replacement-alias-admission` |
| `single-apply-state-evidence` | `materialized-apply-state-is-prepared-once`, `prepared-apply-state-is-isolated` | `TEST` | CommitApplier owner counters/identity probes across all accepted document variants, retained aliases, and preparation failures. | RuntimeRoot and CommitApplier currently construct separate `CommittedDocument` values for one accepted materialized apply. | Exactly one materialized construction feeds selection and install by identity; prepared base-effect/selection values are immutable and built before install. | Stable identity/construction/alias events are admissible; final state, helper-call count, or source token is rejected. | Two equal committed documents are constructed but a counter is incremented only in one helper; identity at selection and installer differs and kills it. | `EXTEND_COVERAGE` | Existing `test/edit/fixtures/selection_effect_commit_fixture.dart` | `single-apply-state-admission` |
| `document-branch-atomicity-evidence` | `document-changing-install-order-is-exact`, `preinstall-failure-preserves-state`, `postinstall-failure-retains-accepted-state` | `TEST` | Direct CommitApplier plus RuntimeRoot snapshot/event cases for each preparation/stale gate, successful document+selection, and throwing prepared-selection install after document install. | Existing fixture proves selection preparation rollback but not every pre-point owner, stale boundary, or post-document-install retention. | Pre-point snapshots are identical; success events are prepare then document/admission then selection; post-document failure retains accepted document/revisions/admission without rollback. | Document identity/data, revisions, next IDs, selection, buffers, projection, aliases, and exact events are admissible; exception type alone, equality-only snapshot, or runtime delivery callback is rejected. | Code catches selection-install failure and restores the prior document but cannot restore admission cursor; final document equality passes while next-ID/identity events kill it. | `EXTEND_COVERAGE` | Existing selection-effect and rollback fixture owners | `document-branch-atomicity-admission` |
| `selection-only-atomicity-evidence` | `selection-only-install-order-is-exact`, `apply-noop-has-no-irreversible-point` | `TEST` | Direct selection replacement/prune effective/no-op cases with throwing preparation/install and Store installer sentinels. | Current fixture observes prepare-selection then selection but does not falsify every Store installer or branch failure point. | Effective branch calls only prepared selection install; preparation failure mutates nothing; selection no-op produces no delivery/actions; every Store sentinel remains untouched. | Exact installer events/state are admissible; zero revision delta, final selection alone, or document equality is rejected. | CommitApplier calls a harmless Store no-op before selection; final state/events without sentinels pass, while the Store sentinel kills it. | `EXTEND_COVERAGE` | Existing `test/edit/fixtures/selection_effect_commit_fixture.dart` | `selection-only-atomicity-admission` |
| `direct-store-compatibility-evidence` | `direct-store-remains-independent` | `TEST` | `flutter test test/store/sparse_store_commit_test.dart test/store/store_transaction_candidate_test.dart test/store/store_commit_finalization_test.dart` | Not required: these existing suites directly own completed Store semantics and are not changed by edit adoption. | All files exit 0 with unchanged direct journal, finalization, diagnostic, work, alias, publication, and install behavior. | Direct Store execution is admissible; edit parity, imports, or docs are rejected as Store proof. | Edit adapter compensates for a reopened Store bug and edit tests pass; direct Store suite fails and kills the bypass. | `NONE` | None | None |
| `compatibility-surface-evidence` | `compatibility-surfaces-remain-unchanged` | `SOURCE_QUERY` | Bounded final-diff and producer/consumer inspection of public exports, DTOs, codec/schema, validation, diagnostics, projection, operation matrix, graph, central allowlists/registries, and RuntimeRoot routes. | Edit/Draft/applier files sit on public and runtime boundaries and a private migration can widen them accidentally. | Only authorized private edit, narrow fact/adapter, owner test, maintained docs, and ADR surfaces change; excluded shapes/semantics remain exact and owning tests retain behavior. | Semantic diff plus owner evidence is admissible; diff stat, token absence, docs claims, or one green suite is rejected. | A mutation DTO gains a convenience field and every edit test adapts; local behavior passes while DTO/public diff inspection kills it. | `NONE` | None | None |
| `edit-lifecycle-documentation-evidence` | `sole-journal-truth-is-current`, `sparse-structure-truth-is-current`, `sparse-count-truth-is-current`, `draft-structure-truth-is-current`, `draft-resource-truth-is-current`, `draft-replacement-truth-is-current`, `commit-apply-truth-is-current` | `MANUAL_INSPECTION` | After each unit, compare its changed owner with `docs/contracts/edit_kernel.md`, applicable `docs/architecture/03_data_model.md`, ADR-0017, and the active-design boundary. | Current docs/ADR explicitly say EditSession/Draft indexed adoption remains pending and describe generic sparse replay. | Every unit leaves its current owner truth accurate; final truth names the sole journal, owner-local indexed/count backings, atomic Draft swap, both apply branches, and only route-generated-ID/runtime delivery pending. | Semantic comparison is admissible; docs checks, wording tokens, copied test/counter inventory, or prose as behavior proof is rejected. | Unit 4 lands indexed Draft structure but ADR still says all Draft adoption is pending until Unit 7; code tests pass while the immediate post-unit owner comparison kills it. | `NONE` | None | None |
| `contract-four-boundary-evidence` | `contract-four-remains-runtime-owned` | `SOURCE_QUERY` | Bounded final producer/consumer inspection of edit/Draft/CommitApplier obligations and the remaining runtime route/resolver/cleanup/delivery owners. | A locally green Contract 3 can still defer an edit-owned consumer, failure branch, or parity obligation into the runtime contract. | Every edit/Draft/CommitApplier producer has a current consumer and owner evidence; the only remaining production owners are runtime route-generated-ID, resolver, cleanup, and delivery ordering surfaces. | Complete bounded ownership/data-flow inspection is admissible; filename tokens, future-plan prose, or one green suite is rejected. | A promoted mutation subtype is left for a runtime adapter to repair; current named tests pass, while producer/consumer tracing exposes the missing edit consumer and kills it. | `NONE` | None | None |

## Permanent Artifact Admissions

### `journal-promotion-admission`: Sole mutation journal and promotion parity

Covers: `promotion-replays-the-sole-journal`, `promotion-dispatch-is-exhaustive`
Impact: `EXTEND_COVERAGE`
Failure family: sparse promotion can omit, reorder, or reinterpret a Store mutation while sparse Store preparation remains correct
Failure mode or stable invariant: the unchanged DTO journal is the only intent and every subtype applies to Draft in exact sequential order
Verification owner: sparse EditSession promotion suite
Current verification gap: current promotion tests exercise the closure journal and cannot detect closure/DTO divergence
Failing witness: current production can record different arguments in `_journal` and `_mutations`, after which Store and promotion consume different intent
Durable and refactor-stable value: complete DTO trace parity survives private promotion helper and Draft backing refactors
Artifact target: Existing `test/edit/fixtures/sparse_edit_session_fixture.dart`

### `early-journal-work-admission`: Early DTO cutover work neutrality

Covers: `early-journal-cutover-does-not-displace-work`
Impact: `EXTEND_COVERAGE`
Failure family: semantically correct DTO promotion can add a traversal, collection copy, element/resource scan, projection, secondary replay, or mutation-depth multiplier before indexed owners land
Failure mode or stable invariant: one ordered DTO pass invokes the same list-backed Draft mutations as current closure replay with no additional work phase or cost multiplier
Verification owner: sparse EditSession promotion work suite
Current verification gap: current promotion evidence observes results but does not attribute traversal, copy, visit, projection, replay, or history-depth work during the cutover
Failing witness: an adapter copies the DTO journal and scans Draft resources before dispatching every mutation correctly
Durable and refactor-stable value: owner/phase work events keep the early cutover neutral across private dispatch and later Draft backing refactors
Artifact target: Existing `test/edit/fixtures/sparse_edit_session_fixture.dart`

### `sparse-order-semantics-admission`: Sparse indexed placement semantics

Covers: `sparse-placement-is-current`, `sparse-index-semantics-are-exact`
Impact: `EXTEND_COVERAGE`
Failure family: sparse current placement/order can retain a stale or duplicate committed occurrence or change numeric rank semantics
Failure mode or stable invariant: one current location and separate owner-local indexed orders match a sequential list/map oracle after every mutation
Verification owner: sparse EditSession owner suite
Current verification gap: current cases do not directly falsify every committed remove/re-add placement and raw-index interleaving
Failing witness: removing a committed content element and re-adding it elsewhere can leave the original content occurrence in an unopened list
Durable and refactor-stable value: semantic placement/order observations survive AVL node, helper, and file decomposition changes
Artifact target: Existing `test/edit/fixtures/sparse_edit_session_fixture.dart`

### `sparse-order-work-admission`: Sparse order work boundary

Covers: `sparse-order-work-is-bounded`
Impact: `EXTEND_COVERAGE`
Failure family: correct sparse order can rebuild or linearly shift an owner for every mutation
Failure mode or stable invariant: each affected order opens once, direct lookups are expected constant work, and rank operations are logarithmically bounded
Verification owner: sparse EditSession work suite
Current verification gap: existing sparse facts counters do not observe sequence builds, rank node visits, or repeated flattens
Failing witness: current list front/middle insertion shifts up to the full order per mutation
Durable and refactor-stable value: owner/phase counters enforce the accepted work boundary without timing or private tree shape
Artifact target: Existing sparse edit owner fixture family under `test/edit/**`

### `sparse-image-count-admission`: Sparse image reference counts

Covers: `sparse-image-counts-are-exact`, `background-image-reference-survives-clear`
Impact: `EXTEND_COVERAGE`
Failure family: image reference delta can drift on update/remove/re-add/clear and release a live descriptor
Failure mode or stable invariant: logical image counts equal direct current image-row counts after every successful transition
Verification owner: sparse EditSession resource suite
Current verification gap: current production exposes only scans/boolean reference decisions, not exact session image counts
Failing witness: a resource-ID update can leave the prior image descriptor counted and the new one absent
Durable and refactor-stable value: per-step count/result parity survives overlay and backing representation changes
Artifact target: Existing sparse edit owner fixture family under `test/edit/**`

### `sparse-vector-count-admission`: Sparse vector reference counts

Covers: `sparse-vector-counts-are-exact`, `background-vector-reference-survives-clear`
Impact: `EXTEND_COVERAGE`
Failure family: vector reference delta can drift independently or be masked by an image count
Failure mode or stable invariant: logical vector counts equal direct current vector-row counts and preserve background vector descriptors
Verification owner: sparse EditSession resource suite
Current verification gap: no independent session vector count oracle exists
Failing witness: a shared resource ID remains referenced by an image while an underflowing vector delta stays invisible to a summed boolean
Durable and refactor-stable value: split-family correctness survives count storage and transition helper refactors
Artifact target: Existing sparse edit owner fixture family under `test/edit/**`

### `sparse-resource-order-admission`: Ordered sparse resource decisions

Covers: `sparse-resource-decisions-are-current`
Impact: `EXTEND_COVERAGE`
Failure family: immediate remove-unused and clear decisions can read counts from the wrong journal state
Failure mode or stable invariant: each resource decision observes all and only preceding successful transitions
Verification owner: sparse EditSession/matrix suite
Current verification gap: existing cases do not cover the complete before/after/remove-re-add/clear/compensation matrix under exact counts
Failing witness: final counts are correct but `removeUnusedResource` runs before the preceding decrement is applied
Durable and refactor-stable value: ordered result/touched evidence preserves callback semantics independently of count implementation
Artifact target: Existing sparse edit and matrix fixture owners

### `sparse-reference-work-admission`: Sparse reference work boundary

Covers: `sparse-reference-work-is-bounded`
Impact: `EXTEND_COVERAGE`
Failure family: exact sparse reference decisions can still scan elements or clone summaries per mutation
Failure mode or stable invariant: split base/delta transitions and queries perform constant-depth affected-ID work
Verification owner: sparse EditSession work suite
Current verification gap: current fixture counts fact calls but not element visits, count-map copies, or delta depth
Failing witness: current fallback scans every accepted element when committed removals or overrides exist
Durable and refactor-stable value: semantic work attribution prevents cost displacement across sparse state refactors
Artifact target: Existing sparse edit owner fixture family under `test/edit/**`

### `draft-structure-semantics-admission`: Direct indexed Draft structure

Covers: `draft-structural-facts-are-direct`, `draft-index-semantics-are-exact`
Impact: `EXTEND_COVERAGE`
Failure family: Draft direct maps, placement, and indexed orders can disagree while final membership remains plausible
Failure mode or stable invariant: every intermediate structural fact and final order matches an independent list/map oracle
Verification owner: materialized Draft and promotion suite
Current verification gap: current list-owned Draft has no cross-map/index/current-location invariant to falsify
Failing witness: a remove/re-add updates the ID map but leaves the old sequence occurrence
Durable and refactor-stable value: direct semantic observations survive backing module and private sequence refactors
Artifact target: Existing `test/edit/fixtures/sparse_edit_session_fixture.dart` and materialized edit fixture owner

### `draft-structure-work-admission`: Draft structural work boundary

Covers: `draft-structure-work-is-bounded`
Impact: `EXTEND_COVERAGE`
Failure family: Draft can preserve output while retaining nested scans, list shifts, repeated builds, or duplicate materialization passes
Failure mode or stable invariant: construction/materialization are single owner passes, direct queries avoid scans, and rank work is logarithmic
Verification owner: materialized Draft work suite
Current verification gap: existing clear counters do not cover general lookup/rank/materialization work
Failing witness: current layer/element lookup walks nested lists and front insertion shifts the current order
Durable and refactor-stable value: phase counters preserve work across private backing and flatten decomposition
Artifact target: Existing materialized Draft fixture family under `test/edit/**`

### `draft-image-count-admission`: Draft image reference counts

Covers: `draft-image-counts-are-exact`
Impact: `EXTEND_COVERAGE`
Failure family: Draft image counts can drift and change immediate resource/touched behavior
Failure mode or stable invariant: current image counts equal direct row counts after every materialized/promoted transition
Verification owner: materialized Draft resource suite
Current verification gap: current Draft computes reference membership by scanning all elements
Failing witness: an image resource-ID update followed by remove-unused can remove the new descriptor or retain the old one
Durable and refactor-stable value: count/result parity survives keyed descriptor and structural backing refactors
Artifact target: Existing materialized/promotion fixture owners under `test/edit/**`

### `draft-vector-count-admission`: Draft vector reference counts

Covers: `draft-vector-counts-are-exact`
Impact: `EXTEND_COVERAGE`
Failure family: Draft vector counts can drift independently or disappear from clear retention
Failure mode or stable invariant: current vector counts equal direct row counts and preserve vector-only background descriptors
Verification owner: materialized Draft resource suite
Current verification gap: current Draft has no independent vector count owner or oracle
Failing witness: image/vector shared-ID totals stay nonzero while the vector-specific transition is wrong
Durable and refactor-stable value: independent family proof survives summary and backing representation changes
Artifact target: Existing materialized/promotion fixture owners under `test/edit/**`

### `draft-resource-owner-admission`: Keyed Draft resource semantics

Covers: `draft-resource-state-is-singular`, `draft-resource-decisions-are-current`
Impact: `EXTEND_COVERAGE`
Failure family: keyed membership/current value and descriptor output order can diverge or read the wrong transition state
Failure mode or stable invariant: one insertion-ordered keyed owner supplies exact descriptor operations, order, touched facts, and diagnostics
Verification owner: materialized Draft/edit matrix suite
Current verification gap: current descriptor list does not exercise a keyed/order parity invariant
Failing witness: removal and reinsert updates a map but a retained list publishes the old descriptor order
Durable and refactor-stable value: public result/order evidence survives private map implementation changes
Artifact target: Existing edit matrix/materialized/promotion fixtures

### `draft-resource-work-admission`: Draft resource work boundary

Covers: `draft-resource-work-is-bounded`
Impact: `EXTEND_COVERAGE`
Failure family: correct Draft resources can hide list scans, element scans, or global count-map clones
Failure mode or stable invariant: keyed/count operations are affected-ID bounded and authorized whole-owner passes occur once
Verification owner: materialized Draft work suite
Current verification gap: current clear counters do not cover ordinary descriptor/count mutations or map copying
Failing witness: each reference transition clones the full image/vector summary
Durable and refactor-stable value: owner/phase counters prevent cost displacement across resource backing refactors
Artifact target: Existing materialized Draft fixture family under `test/edit/**`

### `three-path-parity-admission`: Direct, callback, and promoted edit parity

Covers: `edit-paths-have-exact-parity`
Impact: `EXTEND_COVERAGE`
Failure family: one edit backing can preserve local tests while diverging from another on intermediate policy or exact diagnostics
Failure mode or stable invariant: identical independent traces produce complete identical observables through all three production paths
Verification owner: cross-path sparse/materialized/direct parity suite
Current verification gap: existing distributed cases do not share one independent trace oracle across all paths after cutover
Failing witness: callback remove/re-add order differs from direct Store while each path's own golden accepts its result
Durable and refactor-stable value: cross-owner parity survives private backing, promotion, and Store editor refactors
Artifact target: Existing `test/edit/fixtures/sparse_edit_session_fixture.dart` plus direct Store fixture owner

### `aggregate-edit-work-admission`: Composed edit lifecycle work boundary

Covers: `aggregate-edit-work-is-bounded`
Impact: `EXTEND_COVERAGE`
Failure family: locally bounded sparse and Draft owners can still repeat whole-owner work at promotion or materialization handoffs
Failure mode or stable invariant: owner- and phase-attributed work composes to one initial pass plus logarithmic affected-order mutations and direct resource transitions without displaced scans, copies, rebuilds, or replay
Verification owner: sparse/materialized edit lifecycle work suite
Current verification gap: existing counters observe selected sparse facts and Draft clear work but do not compose the complete promotion/materialization lifecycle by owner and phase
Failing witness: sparse mutation remains bounded while promotion rebuilds every order and split count before constructing an independently rescanned Draft backing
Durable and refactor-stable value: phase attribution preserves the accepted end-to-end work boundary across private owner and handoff refactors
Artifact target: Existing sparse and materialized edit work fixture owners

### `draft-replacement-atomicity-admission`: Complete Draft backing swap

Covers: `draft-replacement-swaps-atomically`, `draft-replacement-semantics-are-preserved`
Impact: `EXTEND_COVERAGE`
Failure family: replacement can expose or retain a partially overwritten Draft backing on construction failure
Failure mode or stable invariant: failure preserves every old fact and success swaps one complete prepared backing with unchanged replacement behavior
Verification owner: Draft replacement/rollback suite
Current verification gap: current tests validate callback/finalization rollback but cannot inject each backing-construction phase
Failing witness: current replacement overwrites scalars/resources before layers are rebuilt
Durable and refactor-stable value: before/after state and swap events survive private backing construction decomposition
Artifact target: Existing `test/edit/fixtures/rollback_fixture.dart` and Draft replacement fixture owner

### `draft-replacement-alias-admission`: Draft replacement alias isolation

Covers: `draft-replacement-is-isolated`
Impact: `EXTEND_COVERAGE`
Failure family: caller or retired backing aliases can mutate active Draft state after swap/failure
Failure mode or stable invariant: active backing owns unaliased mutable state and retired/caller state cannot affect it
Verification owner: Draft replacement/rollback suite
Current verification gap: no retained-alias attempts span the complete replacement backing
Failing witness: an unmodifiable view still references a caller-owned element or descriptor collection
Durable and refactor-stable value: mutation attempts preserve isolation across collection and module changes
Artifact target: Existing Draft replacement/rollback fixture owner

### `single-apply-state-admission`: One immutable CommitApplier preparation

Covers: `materialized-apply-state-is-prepared-once`, `prepared-apply-state-is-isolated`
Impact: `EXTEND_COVERAGE`
Failure family: selection and installation can consume distinct reconstructed committed documents or mutable base-effect/selection inputs
Failure mode or stable invariant: one immutable prepared apply state supplies the exact same document and sealed payloads to every consumer
Verification owner: CommitApplier/selection-effect suite
Current verification gap: current tests do not observe duplicate `CommittedDocument` construction or cross-consumer identity
Failing witness: RuntimeRoot constructs one committed document for selection and CommitApplier constructs another for install
Durable and refactor-stable value: stable construction/identity/alias observations survive helper and private apply-state refactors
Artifact target: Existing `test/edit/fixtures/selection_effect_commit_fixture.dart`

### `document-branch-atomicity-admission`: Document-changing install boundary

Covers: `document-changing-install-order-is-exact`, `preinstall-failure-preserves-state`, `postinstall-failure-retains-accepted-state`
Impact: `EXTEND_COVERAGE`
Failure family: the document branch can leak pre-install state, reorder document/selection, or roll back accepted document/admission after a later failure
Failure mode or stable invariant: all preparation/stale failures mutate nothing; accepted document/admission precede selection; later failure retains accepted state
Verification owner: CommitApplier selection/rollback suite
Current verification gap: existing rollback coverage does not directly snapshot all owners at every gate or force post-document selection failure
Failing witness: a catch path restores document data after selection failure but leaves consumed admission IDs or changed identity
Durable and refactor-stable value: exact owner snapshots and semantic install events survive installer/helper refactors
Artifact target: Existing selection-effect and rollback fixture owners

### `selection-only-atomicity-admission`: Selection-only install boundary

Covers: `selection-only-install-order-is-exact`, `apply-noop-has-no-irreversible-point`
Impact: `EXTEND_COVERAGE`
Failure family: selection-only/no-op apply can invoke Store, publish effects incorrectly, or use the wrong first point
Failure mode or stable invariant: effective selection installs once after preparation with no Store call; no-op installs/publishes nothing
Verification owner: CommitApplier selection-effect suite
Current verification gap: current event trace does not sentinel every Store installer or preparation/install failure
Failing witness: a harmless Store installer call occurs before selection and stays invisible in final state
Durable and refactor-stable value: installer sentinels and state/effect observations survive branch implementation changes
Artifact target: Existing `test/edit/fixtures/selection_effect_commit_fixture.dart`

## Verification Gate

| Check | Scope | Future command or evidence | Pass signal |
| --- | --- | --- | --- |
| Changed-owner static analysis | All changed Dart production/test/guardrail owners | `dart analyze` | Exit 0 |
| Changed-owner DCM analysis | Repository Dart sources | `dcm analyze .` | Exit 0 |
| Edit production metrics review | Changed edit owners and cohesive new edit modules | `dcm calculate-metrics lib/src/edit` | Report reviewed; each declaration remains cohesive, no metric-only split or broad suppression is introduced |
| Runtime/store adapter metrics review | Narrow changed Store/runtime adapter scopes, when changed | `dcm calculate-metrics lib/src/store lib/src/runtime` | Report reviewed; only direct existing-fact and compile-atomic adapter wiring changes, with no Store/runtime route expansion |
| Edit verification metrics review | Changed edit tests/fixtures | `dcm calculate-metrics test/edit` | Report reviewed; each admitted failure family remains independently legible and shared traces do not merge unrelated oracles |
| Focused edit lifecycle closure | Units 1-6 owners | `flutter test test/edit/sparse_edit_session_test.dart test/edit/edit_matrix_effects_test.dart test/edit/net_no_op_edit_commit_test.dart test/edit/rollback_test.dart` | Exit 0 with sole-journal, indexed/count, clear, promotion, no-op, replacement, and rollback outcomes exact |
| CommitApplier branch closure | Unit 7 owner | `flutter test test/edit/selection_effect_commit_test.dart test/edit/accepted_interaction_commit_test.dart` | Exit 0 with one prepared state, both install branches, pre-point rollback, and post-point retention exact |
| Prepared DTO guardrail closure | Unchanged EditKernel-to-Store prepared boundary | `flutter test test/guardrails/edit_accepted_finalization_guardrail_test.dart` | Exit 0 without widening private-shape recognition; any genuinely moved declaration is reconciled with its central owner |
| Import boundary closure | Edit consumption of Store sequence/facts and unchanged runtime direction | `flutter test test/guardrails/import_boundaries_test.dart test/guardrails/owner_dag_import_boundaries_test.dart` | Exit 0; Store imports no edit/runtime route state, edit imports no surface, and no new owner edge is required |
| Architecture graph closure | Existing Store/edit/runtime nodes and seams | `dart run tool/architecture_graph/check.dart` and `dart run tool/architecture_graph/generate_views.dart --check` | Both exit 0 with no graph node, edge, placeholder, or generated view change |
| Documentation closure | Updated edit/data-model/ADR/verification truth and generated docs | `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` | Both exit 0 with current generated documentation, registries, links, and ADR catalog state |
| `edit-work-budget-gate` | Cross-unit composition of Units 1-7 | Owner-attributed journal, sequence, lookup, split-count, backing-build/materialization, replacement, apply-preparation, projection, and install events at supported size | Construction/import/promotion use one allowed owner pass; mutation is `K log M` plus affected-ID work; materialization/replacement is one owner traversal/publication; apply prepares once; no multiplier moves into another owner, phase, or Contract 4 |
| `three-path-terminal-gate` | Complete direct/callback/promoted semantic closure after Units 1-6 | Seeded/shrunk trace results plus exact named counterexamples and owner events | All complete observables agree; no owner evidence was deferred and no common implementation supplies its own expected truth |
| `compatibility-and-mirror-gate` | Public/DTO/codec/projection/diagnostic/graph surfaces and every direct consumer/manual mirror named in Source Inputs | Final semantic diff, producer/consumer map, owning tests, allowlist/registry comparison, and bounded old-path retirement inspection | Excluded surfaces are unchanged; every copied inventory remains either unaffected central ownership or is reconciled in the same unit; no replay/order/count/apply mirror remains |
| `contract-four-boundary-gate` | Preliminary handoff to Runtime route and temporal delivery closure | Final code/test/docs diff and active-design boundary comparison | Contract 4 receives only route-generated-ID behavior, resolver/route cleanup/delivery ordering, and cross-owner temporal verification; Contract 3 compiles and passes all edit/CommitApplier owner evidence without it |
| Finding disposition | All implementation and review findings for Units 1-7 | Review records plus final diff and evidence mapping | Every finding is fixed, source-authorized as non-applicable, or blocks completion; none is silently deferred to Contract 4 |
| Diff hygiene | Whole change | `git diff --check` | Exit 0 |
| Lifecycle closure | This active plan, active design, ADR-0017, and ordered four-contract sequence | Planning/ADR directory inspection after all units and evidence complete | This plan moves to `docs/history/plans/` with the same filename; ADR-0017 remains accepted/partially implemented only for route/runtime work; the design remains active because Contract 4 is pending; no Contract-4 plan is created by this contract |
