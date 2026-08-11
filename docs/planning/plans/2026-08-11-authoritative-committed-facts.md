# Change Contract

## Goal

Committed element families, layer rows, resource-reference summaries, and generated-id admission each expose their own exact authoritative facts without retained committed membership mirrors or repeated document-sized lookup work, while every existing public id, import, edit, diagnostic, projection, ordering, and immutable-publication behavior remains unchanged and the maintained runtime data-model documentation records only the owner state delivered by this first contract.

## Source Inputs

| Category | Source ID | Location or authority |
| --- | --- | --- |
| Design | `sparse-commit-transaction-candidate-design` | docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md |
| Research | `element-resource-lookup-facts` | docs/history/research/2026-08-10-element-resource-lookup-facts.md |
| PLAN | none | none |
| Other | `user-request` | user request |
| Other | `repository-policy` | AGENTS.md |
| Other | `engineering-change-unit-criteria` | ENGINEERING_CHANGE_UNIT_CRITERIA.md |
| Other | `planning-policy` | docs/planning/README.md |
| Other | `architecture-overview` | docs/architecture/00_architecture_overview.md |
| Other | `runtime-ownership` | docs/architecture/01_runtime_ownership.md |
| Other | `package-boundaries` | docs/architecture/02_package_boundaries.md |
| Other | `runtime-data-model` | docs/architecture/03_data_model.md |
| Other | `architecture-graph` | docs/architecture/architecture_graph.yaml |
| Other | `verification-tests` | docs/verification/tests.md |
| Other | `guardrail-design-patterns` | docs/verification/guardrail_design_patterns.md |
| Other | `public-api-owner` | docs/contracts/public_api_v1.md |
| Other | `edit-owner` | docs/contracts/edit_kernel.md |
| Other | `operation-owner` | docs/contracts/operation_matrix.md |
| Other | `validation-owner` | docs/contracts/validation_limits.md |
| Other | `codec-owner` | docs/contracts/codec_boundary.md |
| Other | `committed-projection-adr` | architecture/decisions/ADR-0002-separate-committed-runtime-and-projection-state.md |
| Other | `store-finalization-adr` | architecture/decisions/ADR-0003-store-finalized-edit-transactions.md |
| Other | `atomic-load-adr` | architecture/decisions/ADR-0004-canonical-schema-reader-and-atomic-load.md |
| Other | `family-table-owner` | lib/src/store/family_tables.dart |
| Other | `layer-table-owner` | lib/src/store/layer_table.dart |
| Other | `element-registry-owner` | lib/src/store/element_registry.dart |
| Other | `committed-document-owner` | lib/src/store/committed_document.dart |
| Other | `resource-table-owner` | lib/src/store/resource_table.dart |
| Other | `store-kernel-owner` | lib/src/store/document_store_kernel.dart |
| Other | `store-import-owner` | lib/src/store/schema_v1_store_import.dart |

## Classification

Profile: `REFACTOR`
Obligations: `SEAM_MIGRATION`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `NEGATIVE_PROOF_AND_FIXTURE_QUARANTINE`, `SOURCE_OF_TRUTH_SINGULARITY`

## Decision Trace

| Decision ID | Source decision | Contract location | Acceptance or evidence target |
| --- | --- | --- | --- |
| `first-contract-scope` | The user fixes this artifact as Contract 1 of four and names its topic “Authoritative committed facts”; later store-candidate, indexed edit-lifecycle/atomic-install, and runtime temporal-closure work is excluded. | Boundaries; Units 1 through 6 | `committed-facts-data-model-current` |
| `unit-boundaries-follow-authority` | Engineering change units must be the smallest dependency-closed transitions with one authority and one independently assessable result, and independent failure families must not be merged to reach a preferred count. | Units 1 through 6; Verification Matrix | `family-membership-is-direct` |
| `family-membership-authority` | Design D5 keeps element membership in the seven family maps, requires allocation-free direct membership, and forbids a permanent global element-id index. | Boundaries; Unit 1 | `family-membership-is-direct` |
| `split-reference-authority` | Design D6 assigns separate image and vector resource-reference counts to `FamilyTables`, includes references to missing descriptors, and forbids a global per-mutation count clone. | Boundaries; Unit 2 | `resource-reference-counts-are-exact` |
| `reference-query-work` | Design D1 and the resource-classification proof require committed reference lookup to avoid row scans after the owner snapshot exists; exact timing is not authority. | Unit 2; Verification Matrix | `resource-reference-query-is-bounded` |
| `layer-location-authority` | The selected form assigns an exact immutable layer-id-to-row/index fact to `LayerTable`, derived from ordered rows and verified for bidirectional parity. | Boundaries; Unit 3 | `layer-location-parity` |
| `layer-consumer-migration` | Design D5 requires layer membership and location consumers to read the layer owner rather than rebuild sets or scan rows. | Unit 3 | `layer-lookups-are-direct` |
| `admission-owner-cursor` | The Contract 1 portion of Design D17 requires each admission owner to establish and maintain a cursor at the first free generated id across construction/reset, explicit generation, and accepted `admitAll` growth. | Boundaries; Unit 4 | `admission-cursor-is-normalized` |
| `admission-mirror-retirement` | Design D5 and D12 retire committed element/layer admission sets, the order-import admission set, their set append overlays, and admission seeding through those mirrors after authoritative owner enumeration is available. | Boundaries; Unit 5 | `committed-admission-mirrors-are-retired` |
| `admission-distinct-lifecycles` | The design preserves construction-local duplicate detectors and the admission registry’s reservation history because they have distinct owners, lifecycles, and consumers and are not current-membership mirrors. | Boundaries; Units 1, 3, 4, and 5 | `committed-admission-mirrors-are-retired` |
| `generated-id-compatibility` | Public API v1 requires runtime-local generated ids to stay unique and load/reset to avoid loaded-id collisions; Contract 1 changes cursor work and admission seeding, not returned-id behavior. | Boundaries; Units 4 and 5 | `authoritative-seeding-preserves-generated-ids` |
| `family-counter-evidence` | Design D13 and the guardrail proof policy require executable owner counters for family lookup/allocation work and reject timing or source shape as sole performance proof. | Unit 1; Verification Matrix | `family-membership-direct-evidence` |
| `reference-counter-evidence` | Design D13 and the guardrail proof policy require executable owner counters for reference-query work and reject timing or source shape as sole performance proof. | Unit 2; Verification Matrix | `resource-reference-query-work-evidence` |
| `layer-counter-evidence` | Design D13 and the guardrail proof policy require executable owner counters for targeted layer work and reject timing or source shape as sole performance proof. | Unit 3; Verification Matrix | `layer-lookup-work-evidence` |
| `admission-counter-evidence` | Design D13 and the guardrail proof policy require executable owner counters for reset establishment, collision probes, and cursor advances and reject timing or source shape as sole performance proof. | Unit 4; Verification Matrix | `admission-cursor-work-evidence` |
| `private-fixture-quarantine` | The design rejects private-helper/source-shape fixtures as authority; the existing sparse-id fixture’s projection count cannot prove absence of membership or cursor scans. | Boundaries; Verification Matrix | `admission-cursor-work-evidence` |
| `committed-data-model-closure` | The design’s source-of-truth impact and repository knowledge policy require `docs/architecture/03_data_model.md` to record the delivered committed derived-fact and admission lifecycles without documenting later unimplemented architecture. | Unit 6 | `committed-facts-data-model-current` |
| `later-indexed-sequence-excluded` | An unused indexed-sequence utility would violate the engineering-unit present-value rule; its first production consumer belongs to a later contract. | Out of Scope | `committed-facts-data-model-current` |
| `later-store-candidate-excluded` | The user reserves the isolated transaction candidate, one-open/one-freeze transaction lifecycle, final normalization, and one-publication cutover for a later contract. | Out of Scope | `committed-facts-data-model-current` |
| `later-edit-install-excluded` | The user reserves sparse `EditSession`, `DraftDocument`, promotion, indexed edit lifecycle, and atomic-install work for a later contract. | Out of Scope | `committed-facts-data-model-current` |
| `later-runtime-temporal-excluded` | The user reserves draw/line read-only candidate consumption, rollback-safe failed-id reuse, resolver/text listener behavior, and delivery-order closure for the runtime temporal-closure contract. | Out of Scope | `committed-facts-data-model-current` |
| `program-lifecycle-remains-open` | The design’s ADR, full source-owner closure, and active-design retirement occur only after the remaining contract handoffs are implemented and verified. | Out of Scope; Verification Gate | `committed-data-model-review` |

## Repository Evidence

- `docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md:5` / design disposition: the design is `READY_FOR_CONTRACT` and has no open decisions -> Contract 1 authoring is permitted.
- `ENGINEERING_CHANGE_UNIT_CRITERIA.md:13` / unit definition: a unit must be the smallest dependency-closed valid transition with one dominant intent and falsifying evidence -> membership, reference summaries, layer locations, admission migration, and documentation closure remain separate units.
- `ENGINEERING_CHANGE_UNIT_CRITERIA.md:137` / preparatory value: unused infrastructure is not a valid unit -> the reusable indexed sequence is excluded until a later contract has its first production consumer.
- `lib/src/store/family_tables.dart:69` / element truth: seven maps own every committed family row, while `contains` at `:77` constructs the `admittedElementIds` union from `:143` -> direct membership and owner enumeration belong here without a new global index.
- `lib/src/store/family_tables.dart:79` / reference query: every lookup scans image then vector rows -> exact split owner summaries are required before changed-resource classification can be bounded by changed ids.
- `lib/src/store/family_tables.dart:99` / family mutations: add, remove, clear, and batch replacement all publish through the family owner -> reference-summary parity must cover every construction/import/mutation path rather than one caller.
- `lib/src/store/layer_table.dart:26` / layer truth: ordered rows are the layer identity/order owner, while `contains` at `:40` rebuilds a set and add-element lookup at `:71` scans rows -> the derived location fact and its direct consumers belong to `LayerTable`.
- `lib/src/store/layer_table.dart:127` / import duplicate detector: `_admittedLayerIds` exists only inside the consume-once import builder -> it remains a permitted boundary-local duplicate detector rather than committed truth.
- `lib/src/store/element_registry.dart:49` / committed manual mirrors: registry construction stores `admittedElementIds` and `admittedLayerIds` beside family/layer truth, and the same fields are retained at `:116` -> both committed mirrors must retire.
- `lib/src/store/element_registry.dart:270` / append mirrors: append optimization extends the two retained admission sets through `_AppendedReadOnlySet` while token/location maps have separate consumers -> Contract 1 removes the set overlays but does not claim the later map-overlay or candidate retirement.
- `lib/src/store/element_registry.dart:387` / import mirror: the order-import builder collects and publishes a separate admitted-element set at `:425` -> family import rows, not order import, must seed element admission after migration.
- `lib/src/store/committed_document.dart:100` / mirror consumer: the committed aggregate forwards element, layer, and resource admission collections to the kernel -> admission reset/install must consume authoritative family/layer/resource owners directly.
- `lib/src/store/document_store_kernel.dart:46` / reset consumer: all three admission owners are reconstructed from `CommittedDocument` admission getters -> reset, replacement, prepared load, and schema import must migrate atomically to direct owner enumeration.
- `lib/src/store/document_store_kernel.dart:260` / install consumers: full/materialized installs admit complete committed collections, while sparse install later admits only its ordered delta -> Contract 1 preserves both lifecycle meanings and changes only the complete-owner enumeration route.
- `lib/src/store/document_store_kernel.dart:2429` / reservation owner: `_IdAdmission` owns admitted/reserved history, starts `_next` at zero, scans collisions in `nextValue`, and `admitAll` does not normalize the cursor -> the first-free invariant and one-time crossing evidence belong here.
- `lib/src/store/resource_table.dart:52` / resource truth: descriptor keys already provide authoritative resource ids -> resource admission seeding can enumerate this owner without adding another retained set.
- `lib/src/store/schema_v1_store_import.dart:87` / atomic import handoff: family, layer, order, and resource builders are consumed into one committed document before prepared publication -> new derived facts must be complete before the imported aggregate is exposed.
- `docs/architecture/03_data_model.md:43` / current data-model owner: committed tables and admission are current architecture truth, but the document omits split reference summaries, layer locations, and normalized admission cursor lifecycle -> Unit 6 must update this owner after production facts exist.
- `docs/architecture/02_package_boundaries.md:261` / test ownership: production-owner tests mirror `lib/src/store/**` under `test/store/**`, while cross-cutting guardrails stay separate -> new fact and work evidence belongs to focused store-owner artifacts, not a feature-local scanner.
- `docs/verification/guardrail_design_patterns.md:12` / proof selection: runtime and work claims require owner-seam tests and executable counters -> source searches and elapsed time are rejected proxies for the new work guarantees.
- `docs/history/research/2026-08-10-element-resource-lookup-facts.md:509` / verification gap: no direct `FamilyTables.contains` test or work-count probe exists -> new permanent owner evidence is admitted for the uncovered failure families.
- `docs/contracts/public_api_v1.md:318` / generated-id compatibility: element, layer, and resource ids are generated in prefix order and remain unique within a runtime, with load reset avoiding collisions -> normalized cursor work cannot alter public results.
- `docs/architecture/architecture_graph.yaml:178` / graph owner: `DocumentStoreKernel` already owns committed descriptor/final-relationship/projection input -> Contract 1 changes internal facts without adding a graph node or dependency edge.

## Boundaries

Owner: `FamilyTables` owns the seven element row maps, direct membership, immediate authoritative id enumeration, and separate derived image/vector resource-reference counts. `LayerTable` owns ordered layer rows plus one exact immutable layer-id-to-row/index derived fact and immediate id enumeration. The existing store admission owner owns generated-id reservation history and the normalized first-free cursor. `DocumentStoreKernel` consumes those owner facts for committed reads and admission construction/install. `docs/architecture/03_data_model.md` owns the maintained description of the delivered committed fact lifecycles.
In Scope: allocation-free family membership across all seven maps; immediate family-id enumeration without a retained committed union; exact split image/vector reference counts across materialized construction, Schema v1 import, add, remove, replace, resource-id transition, and clear; exact layer row/index facts across construction/import and current layer mutations; migration of current layer lookup consumers; first-free element/layer/resource admission cursor establishment and monotonic maintenance across construction, full replacement, prepared load, Schema v1 import, explicit generation, full/materialized admission, sparse accepted-ledger admission, and reset; retirement of `ElementRegistry` committed admission sets, the order-import admission set, their set append overlays, and `CommittedDocument` admission getters; focused semantic/work evidence; and the delivered committed-facts update to `docs/architecture/03_data_model.md`.
Out of Scope: the reusable deterministic indexed-order sequence and all rank-mutation behavior; the isolated store transaction candidate, transaction-local count deltas, one-open/one-freeze work, final normalization, finalization-gate migration, one structural flatten, and one immutable candidate publication; sparse `EditSession`, private facts-adapter, single DTO journal, `DraftDocument`, promotion, atomic install, selection branch, resolver, changed-text, delivery-order, and other runtime temporal work; a read-only next-id candidate method or any draw/line call-site change; failed draw/line id reuse; public API, codec/schema, validation-limit, diagnostic, projection, or order-semantics changes; ADR-0017 creation; architecture graph node/edge changes; active-design retirement; and exact latency or GC constants. These exclusions are authorized by the user’s four-contract split and remain required later design handoffs rather than optional work.
Source of Truth: Family row maps are the sole committed element membership and row truth. Ordered layer rows are the sole layer identity/order truth; the layer location map is a derived cache rebuilt or updated by the same owner and must have exact bidirectional parity. Image and vector rows are the sole forward resource-reference truth; separate owner-local count maps are derived caches, include missing-descriptor references, and are queried by logical sum without becoming descriptor truth. Resource descriptor keys are the resource membership truth. Admission state is intentionally distinct reservation history: its admitted/reserved sets may retain generated or transiently admitted ids no longer present in the document, and its cursor always denotes the first free generated id. Consume-once family/layer import duplicate sets and prepared-load membership payloads retain their boundary-local lifecycles; they are not committed membership mirrors. No retained `ElementRegistry` element/layer admission set, order-import admission set, global element index, global reference-count map, or second cursor truth remains.
Compatibility: Preserve every public signature, returned generated-id sequence, runtime-local uniqueness rule, load/reset collision avoidance, duplicate-id rejection type/code/path, Schema v1 input/output and consume-once behavior, exact element/layer/resource order, family precedence, `removeUnusedResource` result, accepted/no-op/revision/touched behavior, final relationship diagnostic type/code/message/path/precedence, direct-store behavior, lazy projection behavior, and immutable committed publication. Private derived facts must not enter public DTOs, codec payloads, architecture graph ownership, or test expectations about helper/class/file shape.
Order Constraints: Unit 4 establishes the normalized admission cursor lifecycle while the current committed admission inputs remain available. Units 1 and 3 publish authoritative family and layer enumeration independently. Unit 5 then switches every complete-document/reset consumer to direct family/layer/resource enumeration and deletes the obsolete committed/order-import mirrors in the same dependency-closed change; it depends on Units 1, 3, and 4. Unit 2 is independent and closes its own family-reference result. Every owner constructs or updates its derived fact before exposing the owning immutable snapshot. Unit 6 documents only the facts delivered by Units 1 through 5. Later contracts may consume these facts only after this contract’s owner evidence passes.
Temporal Surface Closure: Contract 1 changes no resolver, edit callback, install branch, public listener, action stream, observer, draw/line route, or post-commit delivery order. Current synchronous ordering and reentrancy behavior remain unchanged; the later runtime temporal-closure contract owns the design’s callback and delivery changes.
All-Or-Nothing Failure Boundary: Family, layer, and import constructors must finish duplicate admission and all derived-fact construction before exposing a new immutable owner. Complete-document admission rebuild creates each replacement admission owner from a fully accepted committed document before that lifecycle becomes observable; sparse install continues to admit only its already accepted ordered ledger. No new external/fallible work is added after a committed install point. Any constructor/import/preparation failure preserves the prior committed document, admission state, revisions, projection cache, and public behavior under the existing store/edit/load boundaries.
Negative Proof And Fixture Quarantine: Focused owner tests and dormant semantic work counters prove direct membership, exact count/location parity, bounded lookup, reset establishment, cursor collision probes, and cursor advances. Timing, final document equality alone, projection-build counts, private helper names, field-name scans, and the current `_admitsSparseIdsWithoutDocumentScan` assertion are rejected as work proof. Bounded source inspection may prove obsolete committed mirrors are absent but may not prescribe replacement private decomposition. Consume-once duplicate detectors, prepared-load membership payloads, and admission reservation sets are explicitly quarantined from false-positive mirror retirement because their distinct lifecycles are source-authorized.
Bounded Recognition Scope: Not applicable because this contract introduces no analyzer, guardrail recognizer, registry, syntax matcher, generated-output recognizer, or policy-classification boundary; permanent work proof is executable at the owning store seams.

## Execution Units

### [ ] Unit 1: Make family membership direct

Owner: `FamilyTables` element membership and authoritative element-id enumeration.
Boundary: Replace membership-through-materialized-union with direct lookup across the seven existing maps and expose only immediate owner enumeration for admission consumers; retain construction-local duplicate detection, family precedence, row storage, projection, and mutation behavior, and add no permanent element-id index.
Verification Profile: `REFACTOR`
Change: Make every current family construction/import/mutation snapshot answer membership directly from its authoritative maps and provide non-retained element-id enumeration suitable for Unit 5 without changing family rows, errors, or projections.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `family-membership-is-direct` | Any valid or invalid element id is queried against empty, materialized, imported, added, updated, removed, or cleared family tables. | The family owner performs membership and enumerates current ids for an owner consumer. | Membership matches the seven map key sets exactly, and enumeration yields each current family id exactly once. | A lookup performs only the bounded explicit family-map probes; it allocates no document-sized union and adds no global element index; duplicate-id type/code/path and family precedence remain exact; construction-local duplicate sets remain private and consume-once. |

Depends On: None

### [ ] Unit 2: Publish exact split resource-reference summaries

Owner: `FamilyTables` image/vector reference-summary lifecycle and logical reference query.
Boundary: Add separate private image and vector `resourceId -> count` derived facts and exact transition maintenance to every family construction/import/mutation path; do not change descriptor ownership, relationship validation order, sparse transaction representation, or add a global cross-family summary.
Verification Profile: `REFACTOR`
Change: Build and maintain exact owner-local image/vector reference counts so committed reference queries sum direct counts without scanning rows while preserving all current element and resource behavior.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `resource-reference-counts-are-exact` | Family tables contain any mix of image/vector references, including shared ids, references to missing descriptors, and non-referring families. | Materialized construction, Schema v1 import, add, remove, same-family replacement, resource-id change, remove/re-add, or clear publishes a new family snapshot. | Each private image/vector count equals a direct count of its owning rows, and the logical query is their sum for every resource id. | Descriptor add/remove never changes counts; no negative count, cross-family drift, caller alias, global summary, or descriptor truth is introduced; committed immutability remains exact. |
| `resource-reference-query-is-bounded` | A committed family snapshot already owns exact split counts, including supported-size referring families. | Current store reads, remove-unused decisions, or accepted resource-touch classification query one or many resource ids. | Each logical query performs bounded direct summary lookups independent of image/vector row count. | Owner counters, not timing, observe reads and row visits; queries do not scan rows or materialize a global count clone; the later transaction contract still owns one-open/one-freeze transaction-delta work. |

Depends On: None

### [ ] Unit 3: Make layer identity and location direct

Owner: `LayerTable` ordered rows, layer membership, and derived layer-id-to-row/index facts.
Boundary: Build one exact immutable location fact from ordered rows at materialized/import construction and maintain it through current layer operations; migrate existing store/registry layer membership, row, index, append-placement, and per-layer element-id consumers without changing row order or element placement.
Verification Profile: `REFACTOR`
Change: Make `LayerTable` answer membership, row, and index queries from its owner-local location fact while keeping ordered rows as the sole layer order truth.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `layer-location-parity` | Empty, materialized, Schema v1-imported, ensured, default-created, explicit-created, element-removed, or cleared layer tables are published. | The owner builds or updates the derived location fact. | Every row id maps to exactly its current row and index, every location maps back to the same ordered row, and no absent id has a location. | Ordered rows remain the only order truth; duplicate layer rejection type/code/path, metadata, element order, immutability, and consume-once import behavior remain exact. |
| `layer-lookups-are-direct` | Current consumers ask for layer membership, a row/index, append placement, touched-layer facts, or element ids in one layer. | The consumer reads the `LayerTable` owner seam. | The result matches current behavior without rebuilding an admitted-id set or scanning rows for the target id. | Iteration that intentionally publishes all ordered layers remains row-owned and allowed; no second order list, global index, or edit/runtime reverse dependency appears. |

Depends On: None

### [ ] Unit 4: Normalize the generated-id admission cursor

Owner: `DocumentStoreKernel` generated-id admission lifecycle and its element/layer/resource first-free cursors.
Boundary: Establish and preserve the first-free cursor in each existing admission owner while continuing to consume the current committed admission inputs; cover construction/reset, explicit generation, complete install, and sparse accepted-ledger growth without changing admission seeding sources or adding a read-only candidate operation.
Verification Profile: `REFACTOR`
Change: Normalize element/layer/resource admission cursors at construction/reset and after every explicit reservation or `admitAll` transition so collision work is paid once and public generated-id results remain unchanged.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `admission-cursor-is-normalized` | Admission is created or reset from arbitrary authoritative ids, or its reservation history grows through explicit generation, complete install, or sparse accepted-ledger admission. | The admission owner establishes or advances its cursor and later generates an id. | The cursor always denotes the first free generated id, construction/reset pays any admitted-prefix scan once, and each occupied generated id is crossed at most once between resets. | Element/layer/resource prefixes are covered; explicit generation reserves immediately; `admitAll` preserves transient reservation history; repeated current-cursor reads are not exposed in this contract; counters distinguish reset establishment, collision probes, and advances. |
| `generated-id-contract-is-preserved` | A runtime contains committed, loaded, explicitly reserved, sparsely admitted, removed, non-contiguous, or prefix-generated ids. | Public element/layer/resource generation runs before and after reset/install lifecycles. | Returned ids are the same first-free prefix values as current behavior, remain unique within the runtime, and do not collide after load. | No public API, error, callback order, draw/line behavior, candidate read, rollback rule, or speculative reservation protocol changes. |

Depends On: None

### [ ] Unit 5: Seed admission from authoritative owners and retire mirrors

Owner: `DocumentStoreKernel` complete-document admission seeding consuming `FamilyTables`, `LayerTable`, and `ResourceTable` authoritative membership, plus obsolete committed/order-import membership surfaces.
Boundary: Rebuild complete admission state from immediate family/layer/resource owner enumerations and keep sparse accepted ledgers as incremental reservation input; remove only the obsolete `ElementRegistry`/order-import element/layer membership mirrors, their set append overlays, and `CommittedDocument` admission getters while preserving distinct duplicate-detection, prepared-load, order-map, and reservation lifecycles.
Verification Profile: `REFACTOR`
Change: Migrate element/layer/resource admission construction, replacement, prepared load, Schema v1 import, and full/materialized install consumers to direct owner enumeration, then delete the redundant committed/order-import admission surfaces in the same dependency-closed change.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `committed-admission-mirrors-are-retired` | Family maps, ordered layer rows, descriptor keys, order facts, import builders, and admission reservation history have their distinct owners. | Complete admission consumers migrate to direct owner enumeration and obsolete surfaces are removed. | No retained `ElementRegistry` admitted-element/layer set, order-import admitted-element set, set append overlay, or `CommittedDocument` admission getter remains. | Unit 4's normalized cursor remains the sole first-free owner; construction-local duplicate sets, prepared-load membership payloads, order token/location maps, their current map append overlays, and admission admitted/reserved sets remain only for their distinct source-authorized lifecycles; no copied inventory replaces the deleted mirrors. |
| `authoritative-seeding-preserves-generated-ids` | Complete admission lifecycle currently seeds element/layer/resource reservations through committed aggregate getters. | Construction, full/materialized install, replacement, prepared load, or Schema v1 import seeds Unit 4's normalized admission owner directly from family/layer/resource membership. | The next public element/layer/resource ids remain the same first-free prefix values, remain unique, and do not collide with committed or loaded ids. | Complete seeding enumerates each authoritative owner once; sparse install still consumes only its accepted ordered ledger; no public API, draw/line candidate, reservation protocol, or copied membership inventory appears. |

Depends On:

- Unit 1 — produces: direct family membership and immediate authoritative element-id enumeration; consumed as: the sole current committed element-membership input to admission construction/reset.
- Unit 3 — produces: exact layer membership/location and immediate authoritative layer-id enumeration; consumed as: the sole current committed layer-membership input to admission construction/reset.
- Unit 4 — produces: normalized element/layer/resource admission cursor lifecycle; consumed as: the admission owner preserved while complete seeding inputs migrate and mirrors retire.

### [ ] Unit 6: Record delivered committed fact ownership

Owner: `docs/architecture/03_data_model.md` maintained runtime data-model truth.
Boundary: Document only the committed membership, derived reference/location, normalized admission, and mirror-retirement lifecycles implemented by Units 1 through 5; preserve current public/edit/codec/projection/selection/runtime ownership and leave every later contract decision in the active design.
Verification Profile: `DOCUMENTATION`
Change: Update the runtime data model to name authoritative family/layer/resource owners, derived-cache invariants, direct admission seeding, and the distinct reservation-history cursor without describing the not-yet-implemented transaction editor, indexed edit lifecycle, atomic-install changes, runtime temporal closure, or ADR-0017 as current behavior.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `committed-facts-data-model-current` | The maintained data-model document describes compact committed tables and generic admission but omits the delivered owner facts and still implies admitted-id handoff facts. | The architecture owner is updated after Units 1 through 5 are implemented. | The document identifies one source for membership/order/descriptors/reservations, the exact derived location/reference lifecycles, direct reset enumeration, and first-free cursor invariant. | No later editor/sequence/edit/runtime behavior is stated as implemented; public API, schema, projection, selection, and graph ownership stay unchanged; prose is checked against code/design by bounded review rather than parsed as behavior proof. |

Depends On:

- Unit 1 — produces: direct family membership and immediate id enumeration; consumed as: documented committed element-membership ownership.
- Unit 2 — produces: exact split image/vector reference summaries; consumed as: documented derived-cache ownership and invariant.
- Unit 3 — produces: exact layer location facts and direct lookup; consumed as: documented layer order/location ownership.
- Unit 4 — produces: normalized admission cursor lifecycle; consumed as: documented reservation-history/cursor invariant.
- Unit 5 — produces: direct committed owner seeding and retired membership mirrors; consumed as: documented singular reset route and mirror-free ownership.

## Verification Matrix

| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | Pass signal | Evidence constraints and rejected proxy | Durable impact | Artifact target | Admission |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `family-membership-direct-evidence` | `family-membership-is-direct` | `TEST` | Focused `FamilyTables` store-owner behavior plus dormant semantic membership/map-probe counters under `test/store/**`; cohesive path chosen by implementation. | Current `contains` materializes the seven-map id union and research found no direct owner test or allocation/work probe. | Empty, every family, missing, import, add/update/remove/clear, and enumeration cases match authoritative keys; lookup counters show only bounded family probes and zero union materializations. | Direct returned booleans and final document equality are admissible only with semantic probe evidence; source text, helper names, elapsed time, projection counts, or a copied expected family inventory are rejected. | `EXTEND_COVERAGE` | Focused FamilyTables membership artifact family under `test/store/**` | `family-membership-admission` |
| `resource-reference-summary-parity-evidence` | `resource-reference-counts-are-exact` | `TEST` | Focused FamilyTables reference-summary owner tests under `test/store/**` comparing derived counts with an independently calculated simple row oracle across every construction/mutation boundary. | No committed reference summary exists, so current tests cannot fail on summary drift across add/remove/update/import/clear. | Image and vector counts and their logical sum match direct row counts for missing descriptors, shared ids, id transitions, remove/re-add, non-referring families, and all owner construction/mutation routes. | The oracle reads row inputs independently; implementation-produced counts, descriptor presence, boolean-only spot checks, final document equality, or a self-referential fixture are rejected. | `EXTEND_COVERAGE` | Focused FamilyTables reference-summary parity artifact family under `test/store/**` | `resource-reference-summary-parity-admission` |
| `resource-reference-query-work-evidence` | `resource-reference-query-is-bounded` | `TEST` | Supported-size store-owner budget probe observing semantic reference-summary reads and image/vector row visits. | Current `referencesResource` scans image/vector row values for every query, so many changed ids repeat row work. | After snapshot construction, each queried id performs bounded summary reads with zero row visits, including absent ids and ids shared across both referring families. | Owner counters are admissible; wall-clock timing, a small fixture, source-shape scans, or correct booleans without work observation are rejected. | `EXTEND_COVERAGE` | Focused committed reference-query work artifact family under `test/store/**` | `resource-reference-query-work-admission` |
| `layer-location-parity-evidence` | `layer-location-parity` | `TEST` | Focused LayerTable store-owner parity tests under `test/store/**` with a simple ordered-row oracle across construction/import/mutation paths. | LayerTable has only ordered rows and an on-demand admitted-id set; no retained location fact or parity evidence exists. | Every valid row/id/index round-trips exactly, absent ids miss, and duplicate/import/mutation behavior remains exact for empty, 4,096-layer, default, explicit, removed-element, and clear cases. | Ordered rows are the independent oracle; querying the new location map to derive expected values, testing one placement, or asserting private field shape is rejected. | `EXTEND_COVERAGE` | Focused LayerTable location parity artifact family under `test/store/**` | `layer-location-parity-admission` |
| `layer-lookup-work-evidence` | `layer-lookups-are-direct` | `TEST` | Store-owner budget probe covering current membership/row/index/per-layer-element consumers with semantic row-visit counters. | Current membership rebuilds a set, add/append placement uses `indexWhere`, and `elementIdsInLayer` scans rows. | Targeted lookups perform bounded owner-fact reads independent of layer count, while intentional full ordered iteration remains explicitly counted and unchanged. | Counters at the owner/consumer seam are admissible; timing, source searches, a last-layer-only fixture, or correct results without visit counts are rejected. | `EXTEND_COVERAGE` | Focused layer lookup work artifact family under `test/store/**` | `layer-lookup-work-admission` |
| `admission-cursor-work-evidence` | `admission-cursor-is-normalized` | `TEST` | Store-owner admission lifecycle probes across construction, full/materialized install, sparse ledger admission, replacement, prepared load, Schema v1 import, explicit generation, and reset, including a supported-size contiguous prefix. | Current admission starts at zero, scans collisions lazily in `nextValue`, and `admitAll` leaves the cursor stale; the existing sparse fixture observes only returned ids and projection builds. | Reset establishes the first-free cursor once; explicit generation and every admission route return current expected ids; repeated operations cross each occupied generated id at most once between resets; counters separate reset scans, reads, collision probes, and advances. | Stable returned ids plus semantic counters are admissible; projection count, timing, private helper/source shape, or a generated-id ticket is rejected. | `EXTEND_COVERAGE` | Focused id-admission cursor lifecycle/work artifact family under `test/store/**` | `admission-cursor-work-admission` |
| `committed-admission-mirror-absence` | `committed-admission-mirrors-are-retired` | `SOURCE_QUERY` | Bounded inspection of committed store owners and direct admission consumers after migration. | `ElementRegistry`, order-import facts, and `CommittedDocument` currently retain/forward element/layer membership mirrors and set append overlays. | The forbidden committed/order-import mirror surfaces and their consumers are absent; direct family/layer/resource enumeration feeds complete admission lifecycle; authorized transient duplicate, prepared-load, order-map, and reservation state remains. | This query proves only structural retirement; it cannot prove generated-id behavior or work and must not become a permanent private-name scanner. | `NONE` | None | None |
| `generated-id-public-parity` | `generated-id-contract-is-preserved`, `authoritative-seeding-preserves-generated-ids` | `TEST` | Existing public/runtime id generation coverage via `flutter test test/runtime/runtime_id_generation_test.dart`, plus load/reset cases exercised by the focused admission owner coverage. | Existing coverage fixes current first-free prefix outputs and duplicate admission but does not prove normalized cursor work or direct owner seeding. | The established runtime test exits 0 and focused reset/import cases produce the same element/layer/resource ids without collisions. | Public outputs and errors are admissible for compatibility only; they are not a proxy for cursor work or mirror absence. | `NONE` | None | None |
| `committed-data-model-review` | `committed-facts-data-model-current` | `MANUAL_INSPECTION` | Bounded review of `docs/architecture/03_data_model.md` against Units 1 through 5, the active design, and the final production diff. | The current owner omits split reference/location facts and normalized cursor semantics and still names generic admitted-id handoff facts. | Every delivered owner/invariant is current, later-contract behavior is absent, graph/public/schema ownership is unchanged, and no second inventory or generated semantic owner appears. | Semantic diff review is admissible; docs tooling green, wording tokens, or parsing prose as product behavior are rejected proxies. | `NONE` | None | None |

## Permanent Artifact Admissions

### `family-membership-admission`: Direct committed family membership

Covers: `family-membership-is-direct`
Impact: `EXTEND_COVERAGE`
Failure family: element membership can allocate or diverge from the seven authoritative family maps
Failure mode or stable invariant: every current id is found directly in exactly one authoritative family map and every absent id misses without a document-sized union or duplicate global index
Verification owner: committed FamilyTables store-owner suite
Current verification gap: no direct FamilyTables membership test or semantic allocation/work probe exists
Failing witness: current `contains` constructs the full admitted-id union for each query
Durable and refactor-stable value: map-owned membership and bounded lookup survive private helper, file, and transaction-editor refactors
Artifact target: Focused FamilyTables membership artifact family under `test/store/**`

### `resource-reference-summary-parity-admission`: Exact split committed reference summaries

Covers: `resource-reference-counts-are-exact`
Impact: `EXTEND_COVERAGE`
Failure family: image/vector reference summaries can drift from authoritative family rows across construction or mutation
Failure mode or stable invariant: each split count equals its family-row reference multiplicity and the logical count is their sum for every resource id, including missing descriptors
Verification owner: committed FamilyTables reference-summary store-owner suite
Current verification gap: no committed summaries or parity coverage exists
Failing witness: the current implementation derives only a scan-time boolean and cannot expose summary drift cases
Durable and refactor-stable value: row-to-summary parity remains valid across private map/cache representation and later transaction-editor changes
Artifact target: Focused FamilyTables reference-summary parity artifact family under `test/store/**`

### `resource-reference-query-work-admission`: Bounded committed reference queries

Covers: `resource-reference-query-is-bounded`
Impact: `EXTEND_COVERAGE`
Failure family: resource-reference queries can rescan all referring rows for every changed descriptor or remove-unused decision
Failure mode or stable invariant: after owner snapshot construction, each logical reference query performs bounded split-summary reads and zero family-row traversal
Verification owner: committed store reference-query work-budget suite
Current verification gap: existing resource semantics tests contain no row-visit or allocation/work observation
Failing witness: current `referencesResource` walks image then vector row values on every query
Durable and refactor-stable value: semantic owner counters detect reintroduced `R`-by-row work without locking helper or cache layout
Artifact target: Focused committed reference-query work artifact family under `test/store/**`

### `layer-location-parity-admission`: Exact committed layer locations

Covers: `layer-location-parity`
Impact: `EXTEND_COVERAGE`
Failure family: a derived layer location can become stale or disagree with ordered layer rows
Failure mode or stable invariant: every row id maps bidirectionally to its exact current row/index and no absent id maps
Verification owner: committed LayerTable store-owner suite
Current verification gap: LayerTable has no location fact or owner-level parity coverage
Failing witness: current callers reconstruct membership or scan rows, so no test can detect a stale derived location
Durable and refactor-stable value: ordered-row/location parity survives private map representation and later transaction-editor changes
Artifact target: Focused LayerTable location parity artifact family under `test/store/**`

### `layer-lookup-work-admission`: Bounded committed layer lookup

Covers: `layer-lookups-are-direct`
Impact: `EXTEND_COVERAGE`
Failure family: targeted layer consumers can rebuild full id sets or scan ordered rows
Failure mode or stable invariant: membership, row, index, append-placement, and per-layer element lookup use bounded owner-fact reads independent of layer count
Verification owner: committed layer lookup work-budget suite
Current verification gap: existing fixtures assert results but do not observe row visits or admitted-set materialization
Failing witness: current `contains`, `indexWhere`, and `elementIdsInLayer` paths perform document-layer-sized work
Durable and refactor-stable value: semantic visit counters preserve the targeted lookup bound while allowing private owner refactors
Artifact target: Focused layer lookup work artifact family under `test/store/**`

### `admission-cursor-work-admission`: Normalized first-free admission cursor

Covers: `admission-cursor-is-normalized`
Impact: `EXTEND_COVERAGE`
Failure family: reset or accepted admission can leave the generated-id cursor stale and recreate repeated prefix collision work
Failure mode or stable invariant: reset establishes the first free prefix id once and monotonic reservation/admission crosses each occupied generated id at most once between resets
Verification owner: DocumentStoreKernel id-admission lifecycle/work-budget suite
Current verification gap: current tests observe selected returned ids but not reset scans, collision probes, `admitAll` cursor maintenance, or supported-prefix work
Failing witness: current admission initializes `_next` to zero, scans only inside `nextValue`, and `admitAll` does not advance it
Durable and refactor-stable value: cursor correctness and amortized collision crossing survive private admission decomposition and later read-only candidate consumption
Artifact target: Focused id-admission cursor lifecycle/work artifact family under `test/store/**`

## Verification Gate

| Check | Scope | Future command or evidence | Pass signal |
| --- | --- | --- | --- |
| Changed-owner static analysis | All changed Dart production and test owners | `dart analyze` | Exit 0 |
| Changed-owner DCM analysis | Repository Dart sources | `dcm analyze .` | Exit 0 |
| Production metrics review | Changed store production owners | `dcm calculate-metrics lib/src/store` | Report reviewed; no metric-only split or unjustified new suppression |
| Store-test metrics review | Changed store test owners | `dcm calculate-metrics test/store` | Report reviewed; each admitted failure family remains cohesive and independently legible |
| Existing sparse-store verification | Current sparse membership, resource, admission, no-op, diagnostic, and projection behavior | `flutter test test/store/sparse_store_commit_test.dart` | Exit 0 with current observable behavior unchanged |
| Existing Schema v1 store-import verification | Consume-once builders, duplicate admission, committed import facts, and no-projection install | `flutter test test/store/schema_v1_store_import_test.dart` | Exit 0 with current import and diagnostic behavior unchanged |
| Architecture graph closure | Existing store owner/node/edge closure | `dart run tool/architecture_graph/check.dart` | Exit 0 and no new node or edge |
| Architecture generated-view closure | Generated architecture views | `dart run tool/architecture_graph/generate_views.dart --check` | Exit 0 with generated views current |
| Generated documentation closure | Documentation generated outputs | `dart run docs/tool/sync_generated_docs.dart --check` | Exit 0 with no stale generated documentation |
| Documentation consistency | Changed runtime data-model owner and repository docs | `dart run docs/tool/check_docs.dart` | Exit 0 |
| Finding disposition | All implementation and review findings for Units 1 through 6 | Review records plus final diff and evidence mapping | Every finding is fixed, explicitly source-authorized as non-applicable, or blocks completion; none is silently deferred into a later contract |
| Diff hygiene | Whole change | `git diff --check` | Exit 0 |
| Lifecycle closure | Contract 1 plan and the still-active four-contract design | Planning-directory inspection after all units and evidence complete | This plan moves to `docs/history/plans/` with the same filename; the design remains active because later store/edit/runtime handoffs and ADR closure are intentionally outstanding |
