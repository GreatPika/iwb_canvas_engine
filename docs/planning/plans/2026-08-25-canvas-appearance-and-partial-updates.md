# Change Contract

## Goal

The maintained engine exposes one lightweight coherent appearance snapshot and additive partial palette and grid updates through the root public API, while preserving the existing whole-document and whole-value operations, keeping committed appearance truth in Store and transaction-local truth in the existing edit backings, avoiding full document projection and new mutation or publication families, and retaining the established synchronous, sparse, atomic, no-op, rollback, lifecycle, effect, and dependency boundaries.

## Source Inputs

| Category | Source ID | Location or authority |
| --- | --- | --- |
| Design | `appearance-partial-updates-design` | docs/planning/designs/2026-08-25-canvas-appearance-and-partial-updates.md |
| Research | `appearance-partial-updates-research` | docs/history/research/2026-08-25-client-application-appearance-read-and-palette-grid-updates.md |
| PLAN | none | none |
| Other | `user-request` | user request |
| Other | `public-edit-contract` | lib/src/contracts/public/canvas_runtime.dart |
| Other | `public-document-contract` | lib/src/contracts/public/canvas_document.dart |
| Other | `public-runtime-facade` | lib/src/api/canvas_runtime.dart |
| Other | `runtime-root` | lib/src/runtime/runtime_root.dart |
| Other | `edit-session` | lib/src/edit/edit_session.dart |
| Other | `document-store` | lib/src/store/document_store_kernel.dart |
| Other | `document-projection-cache` | lib/src/store/document_projection_cache.dart |
| Other | `edit-kernel-contract` | docs/contracts/edit_kernel.md |
| Other | `operation-matrix` | docs/contracts/operation_matrix.md |
| Other | `data-model` | docs/architecture/03_data_model.md |
| Other | `runtime-ownership` | docs/architecture/01_runtime_ownership.md |
| Other | `package-boundaries` | docs/architecture/02_package_boundaries.md |
| Other | `public-api-contract` | docs/contracts/public_api_v1.md |
| Other | `public-api-registry` | docs/_registry/public_api_v1.yaml |
| Other | `public-api-compile-consumer` | test/api_contract/public_api_v1_compiles_as_written_test.dart |
| Other | `projection-hot-path-fixture` | test/store/fixtures/no_projection_hot_path_fixture.dart |
| Other | `net-no-op-fixture` | test/edit/fixtures/net_no_op_edit_commit_fixture.dart |
| Other | `rollback-fixture` | test/edit/fixtures/rollback_fixture.dart |
| Other | `committed-projection-adr` | architecture/decisions/ADR-0002-separate-committed-runtime-and-projection-state.md |
| Other | `store-finalization-adr` | architecture/decisions/ADR-0003-store-finalized-edit-transactions.md |
| Other | `documentation-ownership-adr` | architecture/decisions/ADR-0013-documentation-graph-and-proof-ownership.md |
| Other | `adr-policy` | architecture/decisions/README.md |
| Other | `architecture-graph` | docs/architecture/architecture_graph.yaml |
| Other | `materialized-draft` | lib/src/edit/draft_document.dart |
| Other | `runtime-lifecycle-diagram` | docs/diagrams/state_runtime_lifecycle.mmd |
| Other | `stale-handle-fixture` | test/edit/fixtures/sync_non_nested_async_stale_fixture.dart |
| Other | `single-runtime-adr` | architecture/decisions/ADR-0001-single-maintained-acyclic-runtime.md |
| Other | `store-candidate-adr` | architecture/decisions/ADR-0017-store-transaction-candidate-and-derived-facts.md |
| Other | `effect-matrix-fixture` | test/edit/fixtures/edit_matrix_effects_fixture.dart |
| Other | `effect-matrix-wrapper` | test/edit/edit_matrix_effects_test.dart |
| Other | `change-contract-rules` | .agents/skills/change-contract/references/contract-rules.md |
| Other | `repository-instructions` | AGENTS.md |
| Other | `test-structure-owner` | docs/verification/tests.md |
| Other | `public-constructor-test-pattern` | test/api_contract/pointer_input_public_constructor_test.dart |
| Other | `guardrail-contract` | docs/verification/guardrails.md |
| Other | `guardrail-patterns` | docs/verification/guardrail_design_patterns.md |
| Other | `release-gates` | docs/verification/release_gates.md |
| Other | `section-registry` | docs/_registry/sections.yaml |
| Other | `guardrail-registry` | tool/guardrails/src/guardrail_registry.dart |
| Other | `guardrail-executor` | tool/guardrails/src/guardrail_executor.dart |

## Classification

Profile: `BEHAVIOR_CHANGE`
Obligations: `SEAM_MIGRATION`, `PUBLIC_API_CHANGE`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `NEGATIVE_PROOF_AND_FIXTURE_QUARANTINE`, `TEMPORAL_SURFACE_CLOSURE`, `ALL_OR_NOTHING_FAILURE_BOUNDARY`, `SOURCE_OF_TRUTH_SINGULARITY`, `WORK_BUDGET_CLOSURE`

## Decision Trace

| Decision ID | Independent failure family | Source decision | Contract location | Acceptance or evidence target |
| --- | --- | --- | --- | --- |
| `lightweight-public-workflow` | The root public API can expose declarations that do not complete the lightweight read plus both partial-update workflow against a real runtime. | R-001; D-001; A-001 | Unit 8; Matrix | `lightweight-public-workflow-evidence` |
| `coherent-appearance-state` | One appearance value can mix committed states or omit a required persisted appearance field. | R-002, R-003; D-002; A-002 | Unit 2; Matrix | `appearance-coherence-evidence` |
| `single-appearance-read-surface` | Separate public appearance-field read operations can make callers assemble a sequential, incoherent snapshot beside `readAppearance`. | R-003; D-002 | Unit 2; Matrix | `appearance-single-read-surface-evidence` |
| `projection-free-appearance-read` | Appearance reads can enter or warm full public projection or traverse unrelated document owners. | R-004; D-001, D-002; A-003 | Unit 2; Matrix | `appearance-projection-evidence` |
| `appearance-read-lifecycle` | Appearance reads can expose draft state, publish during a callback, miss install/rollback boundaries, or reject after dispose. | D-002; A-004 | Unit 2; Matrix | `appearance-lifecycle-evidence` |
| `appearance-collection-view-immutability` | A public appearance palette collection can be mutable or expose an alias that changes committed state without another edit. | R-021; D-002; A-016 | Unit 2; Matrix | `appearance-collection-view-evidence` |
| `palette-presence-empty-application` | Palette omission and supplied-empty values can be interpreted identically or applied to the wrong sibling field. | R-005, R-007, R-008, R-022; D-003; A-005 | Unit 3; Matrix | `palette-presence-evidence` |
| `palette-context-free-constructor-validation` | Invalid supplied palette values can survive DTO construction and fail only after edit/backing access. | R-005, R-021; D-003; A-005, A-016 | Unit 3; Matrix | `palette-constructor-validation-evidence` |
| `grid-presence-merged-validation` | Grid omission or context-dependent validation can bypass the established complete-value boundary. | R-006, R-007; D-003; A-005 | Unit 4; Matrix | `grid-validation-evidence` |
| `grid-context-free-constructor-validation` | An unconditionally invalid supplied grid scalar can survive DTO construction and fail only after edit/backing access. | D-003; A-005 | Unit 4; Matrix | `grid-constructor-validation-evidence` |
| `palette-sequential-backing-parity` | Later palette updates can merge from committed rather than latest transaction-local state or diverge after materialization. | R-009, R-010; D-003; A-006 | Unit 3; Matrix | `palette-sequential-evidence` |
| `grid-sequential-backing-parity` | Later grid updates can merge from committed rather than latest transaction-local state or diverge after materialization. | R-009, R-010; D-003; A-006 | Unit 4; Matrix | `grid-sequential-evidence` |
| `palette-no-op-silence` | Empty, equal, or compensating palette updates can advance revisions, invalidate projection, repaint, emit, or publish. | R-011; D-003; A-007 | Unit 3; Matrix | `palette-no-op-evidence` |
| `grid-no-op-silence` | Empty, equal, or compensating grid updates can advance revisions, invalidate projection, repaint, emit, or publish. | R-011; D-003; A-007 | Unit 4; Matrix | `grid-no-op-evidence` |
| `partial-update-callback-atomicity` | A caught per-call rejection can erase earlier work, or an escaping validation/callback failure can leak either partial-update family. | R-012; D-003; A-008 | Unit 5; Matrix | `partial-update-atomicity-evidence` |
| `partial-update-preinstall-failure-order` | A partial-specific expected owner failure can occur after irreversible installation or be masked by compensating rollback. | R-012; D-003; A-008 | Unit 6; Matrix | `partial-update-preinstall-failure-evidence` |
| `palette-effect-parity` | Palette partial updates can diverge from `setPalette` in committed facts, revisions, invalidation, repaint, events, or publication. | R-005; D-003; A-009 | Unit 3; Matrix | `palette-effect-evidence` |
| `grid-effect-parity` | Grid partial updates can diverge from `setGrid` in committed facts, revisions, invalidation, repaint, events, or publication. | R-006; D-003; A-009 | Unit 4; Matrix | `grid-effect-evidence` |
| `operation-matrix-proof-authority` | The registered `edit.operation_matrix_complete` guarantee requires copied/parsing exact parity that conflicts with the repository's verification-ownership rule. | Authority Preflight; Verification Ownership And Gate | Unit 1; Matrix | `operation-matrix-guardrail-retirement-evidence` |
| `remaining-guardrail-route-preservation` | Removing one registered ID can orphan the registry/executor, break release dispatch, or stale the generated guardrail index. | Authority Preflight; Verification Ownership And Gate | Unit 1; Matrix | `remaining-guardrail-route-evidence` |
| `effect-proof-sensitivity-preservation` | Removing invalid completeness mirrors can accidentally remove the direct install, typed-effect, rollback, or no-action detections they surrounded. | Authority Preflight; Verification Ownership And Gate | Unit 1; Matrix | `effect-proof-sensitivity-evidence` |
| `appearance-signature-authority-alignment` | Appearance declarations, root exports, semantic docs, inventory, facade, implementation, and positive consumer can disagree. | R-002, R-013, R-022; D-002, D-004; I-001; A-010 | Unit 2; Matrix | `appearance-public-signature-evidence` |
| `palette-signature-authority-alignment` | Palette-update declarations, root exports, semantic docs, inventory, implementation, and positive consumers can disagree. | R-005, R-013, R-020, R-022; D-003, D-004; I-001; A-010 | Unit 3; Matrix | `palette-public-signature-evidence` |
| `grid-signature-authority-alignment` | Grid-update declarations, root exports, semantic docs, inventory, implementation, and positive consumers can disagree. | R-006, R-013, R-020, R-022; D-003, D-004; I-001; A-010 | Unit 4; Matrix | `grid-public-signature-evidence` |
| `appearance-public-type-equality` | `CanvasAppearance` can accidentally gain structural equality or inconsistent identity hash behavior. | R-018; D-002; A-011 | Unit 2; Matrix | `appearance-public-equality-evidence` |
| `palette-public-type-equality` | `CanvasPaletteUpdate` can accidentally gain structural equality or inconsistent identity hash behavior. | R-018; D-003; A-011 | Unit 3; Matrix | `palette-public-equality-evidence` |
| `grid-public-type-equality` | `CanvasGridUpdate` can accidentally gain structural equality or inconsistent identity hash behavior. | R-018; D-003; A-011 | Unit 4; Matrix | `grid-public-equality-evidence` |
| `palette-implementer-migration` | A final direct `CanvasEdit` implementer can omit `updatePalette` while also omitting grid or relying on a fallback. | R-020; D-004; A-012 | Unit 4; Matrix | `palette-implementer-negative-evidence` |
| `grid-implementer-migration` | A direct `CanvasEdit` implementer can omit `updateGrid` while a copied inventory or unrelated positive consumer remains green. | R-020; D-004; A-012 | Unit 4; Matrix | `grid-implementer-negative-evidence` |
| `appearance-durable-owner-transition` | Runtime, Store, public contract, data model, or lifecycle diagram can retain stale appearance-read ownership. | I-002; A-013 | Unit 2; Matrix | `appearance-durable-owner-evidence` |
| `palette-durable-owner-transition` | Edit, Draft, Store, public contract, or operation matrix can retain stale palette-update ownership. | I-002; A-013 | Unit 3; Matrix | `palette-durable-owner-evidence` |
| `grid-durable-owner-transition` | Edit, Draft, Store, public contract, or operation matrix can retain stale grid-update ownership. | I-002; A-013 | Unit 4; Matrix | `grid-durable-owner-evidence` |
| `retained-architecture-graph` | Implementation can introduce a new owner, node, cache, service, or reversed dependency while ordinary analysis stays green. | D-001; A-014 | Units 2-4; Matrix | `architecture-closure-evidence` |
| `appearance-truth-singularity` | Runtime or another owner can store a second committed appearance value or bypass Store while returned values remain correct. | D-001; A-015 | Unit 2; Matrix | `appearance-singularity-evidence` |
| `palette-alias-isolation` | Mutable palette inputs or update collection views can change a DTO or later public appearance without another edit. | R-021; D-002, D-003; A-016 | Unit 3; Matrix | `palette-alias-evidence` |
| `retained-document-read-behavior` | Existing full document reads can be removed, deprecated, or redirected by the appearance surface. | R-013; D-004; A-017 | Unit 2; Matrix | `retained-document-read-evidence` |
| `retained-draft-document-read-behavior` | `readDraftDocument` can change result, materialization, callback lifecycle, or stale semantics when partial edit seams are added. | R-013; D-004; A-017 | Unit 3; Matrix | `retained-draft-document-read-evidence` |
| `retained-background-color-setter-behavior` | `setBackgroundColor` can change sibling preservation, transaction, effects, no-op, rollback, or public availability when grid partial merging is added beside it. | R-013; D-004; A-017 | Unit 4; Matrix | `retained-background-setter-evidence` |
| `retained-whole-palette-behavior` | `setPalette` can be removed, deprecated, or behaviorally redirected by the partial method. | R-013; D-004; A-017 | Unit 3; Matrix | `retained-palette-setter-evidence` |
| `retained-whole-grid-behavior` | `setGrid` can be removed, deprecated, or behaviorally redirected by the partial method. | R-013; D-004; A-017 | Unit 4; Matrix | `retained-grid-setter-evidence` |
| `forbidden-appearance-members` | Camera, selection, metadata, layers, elements, or resources can resolve on `CanvasAppearance`. | R-015; D-002, D-004; A-018 | Unit 2; Matrix | `forbidden-appearance-negative-evidence` |
| `forbidden-background-update` | An `updateBackground` method or fallback can enter the public edit surface. | R-016; D-004; A-018 | Unit 4; Matrix | `forbidden-background-update-evidence` |
| `appearance-engine-only-boundary` | Application vocabulary, adapter, state, or dependency can enter the appearance read. | R-014, R-017; D-001, D-002; A-019 | Unit 2; Matrix | `appearance-engine-boundary-evidence` |
| `palette-engine-only-boundary` | Application vocabulary, adapter, state, or dependency can enter palette partial updates. | R-014, R-017; D-001, D-003; A-019 | Unit 3; Matrix | `palette-engine-boundary-evidence` |
| `grid-engine-only-boundary` | Application vocabulary, adapter, state, or dependency can enter grid partial updates. | R-014, R-017; D-001, D-003; A-019 | Unit 4; Matrix | `grid-engine-boundary-evidence` |
| `palette-stale-handle-order` | A stale `updatePalette` call can reach backing access or validation before `StateError`, or leak observable effects. | D-003; A-020 | Unit 3; Matrix | `palette-stale-evidence` |
| `grid-stale-handle-order` | A stale `updateGrid` call can reach merged validation before `StateError`, or leak observable effects. | D-003; A-020 | Unit 4; Matrix | `grid-stale-evidence` |
| `palette-single-journal-candidate-publication` | Palette partial updates can add a second journal/candidate/mutation family, duplicate replay, or publish multiple aggregates. | R-019; D-001, D-003; A-021 | Unit 3; Matrix | `palette-single-candidate-evidence` |
| `grid-single-journal-candidate-publication` | Grid partial updates can add a second journal/candidate/mutation family, duplicate replay, or publish multiple aggregates. | R-019; D-001, D-003; A-021 | Unit 4; Matrix | `grid-single-candidate-evidence` |
| `appearance-query-work-budget` | Query work can grow with unrelated layers, elements, resources, or metadata or be displaced into projection. | R-004; D-002; WORK_BUDGET_CLOSURE | Unit 2; Matrix | `appearance-projection-evidence` |
| `palette-construction-work-budget` | Defensive copying or validation can become unbounded or be repeated in edit, replay, install, or cleanup. | R-021; D-003; WORK_BUDGET_CLOSURE | Unit 3; Matrix | `palette-construction-work-evidence` |
| `palette-mutation-replay-install-work-budget` | A palette call can add unrelated work, more than one complete mutation, a second replay, or repeated publication. | R-019; D-003; WORK_BUDGET_CLOSURE | Unit 3; Matrix | `palette-single-candidate-evidence` |
| `grid-construction-mutation-replay-install-work-budget` | Grid construction/application can add non-O(1) or unrelated-document work despite correct journal/replay/publication cardinality. | R-006, R-019; D-003; WORK_BUDGET_CLOSURE | Unit 4; Matrix | `grid-work-budget-evidence` |
| `partial-cleanup-rollback-work-budget` | Validation, callback, or preparation failure can add pure traversal, displaced cleanup, compensating install, or a second rollback lifecycle while final state remains atomic. | R-012, R-019; D-003; WORK_BUDGET_CLOSURE | Unit 7; Matrix | `partial-cleanup-work-evidence` |
| `nullable-update-field-stop` | A palette/grid field can become nullable while null remains overloaded as absence. | H-002 | Boundaries; Gate before Units 3-4 | `nullable-update-field-stop-evidence` |
| `structural-snapshot-expansion-stop` | Metadata, layers, elements, or resources can enter the snapshot without reopening coherence and projection architecture. | H-003 | Boundaries; Gate before Unit 2 | `structural-snapshot-expansion-stop-evidence` |
| `direct-implementer-compatibility-stop` | A release can require old direct implementers to compile unchanged while this contract still mandates direct interface extension. | H-004 | Compatibility; Gate before Units 3-4 | `direct-implementer-compatibility-stop-evidence` |
| `draft-visible-appearance-stop` | Appearance reads can be required to expose sparse/materialized draft intermediates without a new draft-read owner. | H-005 | Temporal Surface Closure; Gate before Unit 2 | `draft-visible-appearance-stop-evidence` |
| `application-state-snapshot-stop` | Application-domain state can enter the snapshot without a cross-boundary owner and dependency decision. | H-006 | Out of Scope; Gate before Unit 2 | `application-state-snapshot-stop-evidence` |
| `runtime-local-snapshot-stop` | Camera or selection can enter the snapshot without cross-owner coherence, lifecycle, and proof authority. | H-007 | Out of Scope; Gate before Unit 2 | `runtime-local-snapshot-stop-evidence` |

## Repository Evidence

- `lib/src/contracts/public/canvas_runtime.dart:157` / public edit authority: `CanvasEdit` owns one interface containing the existing whole-value setters -> each partial method must land atomically with every maintained direct implementation and consumer, without a V2 or extension fallback.
- `lib/src/contracts/public/canvas_document.dart:140` / public appearance value authority: background, grid, and palette already own immutable non-null appearance values and validation -> new snapshot/update types reuse those value boundaries rather than duplicating rules.
- `lib/src/api/canvas_runtime.dart:21` / facade export route: the runtime facade re-exports the public runtime contract and the root barrel exports this facade -> new runtime/edit declarations remain on the existing single public route.
- `lib/src/api/canvas_runtime.dart:37` / public read facade: `readDocument` is a direct facade delegation -> add `readAppearance` as the corresponding exact synchronous delegation without moving its coherence owner into API.
- `lib/src/runtime/runtime_root.dart:921` / runtime observation owner: committed document reads delegate to Store -> the new read uses the same facade/root ownership chain and remains allowed during callbacks and after disposal.
- `lib/src/store/document_store_kernel.dart:327` / committed read boundary: full document reads alone enter `DocumentProjectionCache`, while direct Store getters expose coherent background and palette from `_document` -> Store can construct appearance without another stored value or public projection.
- `lib/src/store/document_projection_cache.dart:28` / full projection owner: a public document build traverses resources, background elements, layers, metadata, background, and palette -> appearance evidence must kill any entry into this owner or equivalent unrelated assembly.
- `lib/src/store/committed_document.dart:174` / committed scalar truth: one immutable aggregate owns background and palette together -> it remains the sole durable appearance truth and coherence boundary.
- `lib/src/edit/edit_session.dart:58` / public edit implementation: one `EditSession` handle intentionally centralizes stale guarding for every entry -> both new methods must call `_ensureActive` before backing access, merge, or validation.
- `lib/src/edit/edit_session.dart:223` / intentional backing mirror: the private backing interface mirrors `CanvasEdit` only to keep one stale guard and sparse/materialized dispatch -> both methods extend this transaction-local dispatch in the same owning unit as their public interface change.
- `lib/src/edit/edit_session.dart:390` / sparse transaction state: one callback-local journal plus `_backgroundOverride` and `_paletteOverride` own latest local state until promotion, commit, rollback, or close -> omitted fields merge from this lifecycle-bounded truth rather than a new Store mutation family or durable mirror.
- `lib/src/edit/edit_session.dart:406` / promotion boundary: the sole journal replays exhaustively into one materialized Draft -> partial updates reduce to existing complete-value mutations so promotion requires no partial replay vocabulary.
- `lib/src/edit/edit_session.dart:683` / sparse whole-value paths: background/grid/palette setters already merge against the latest local override, suppress local equality, and append complete mutations -> palette and grid partial units reuse these independent semantic owners.
- `lib/src/edit/draft_document.dart:375` / materialized whole-value paths: Draft preserves sibling background fields, validates complete values, compares current values, and marks established effects -> materialized partial updates must converge on these same setters.
- `lib/src/store/document_store_kernel.dart:793` / Store finalization: one private candidate replays the sole journal, validates, derives final equality, and discards no-ops before installation -> partial updates cannot add a second candidate, journal, or acceptance source.
- `lib/src/store/document_store_kernel.dart:1097` / irreversible install: sparse installation occurs only after preparation and stale validation -> all partial-specific merge, construction, validation, and failure work must complete before this boundary.
- `lib/src/store/document_store_kernel.dart:1191` / exhaustive mutation consumer: Store replay already recognizes complete background and palette variants -> no partial Store mutation variant is authorized.
- `docs/contracts/operation_matrix.md:66` / accepted effect authority: background, grid, and palette have separate revision, projection, repaint, and no-event domains -> palette and grid belong in separate end-to-end units and evidence families.
- `docs/contracts/operation_matrix.md:89` / no-op authority: compensating final no-ops have no state or effect -> empty, equal, and compensating partial updates reuse that Store-finalized outcome.
- `test/edit/fixtures/edit_matrix_effects_fixture.dart:270` / copied test inventory: `_requiredEditOperationRows` manually repeats the fixture case labels and has no distinct durable meaning -> retire this list rather than extending it for partial rows.
- `test/edit/fixtures/edit_matrix_effects_fixture.dart:847` / self-referential parity: the fixture compares its case-label set with the copied list while direct cases already execute install, typed effects, rollback, and no-action observations -> remove the parity assertion and retain those direct behavioral guarantees.
- `test/edit/edit_matrix_effects_test.dart:19` / prose/private-shape parser: the wrapper parses operation-matrix Markdown and implemented method names to require exact fixture-label parity -> retire this invalid documentation/private-shape proof; `docs/contracts/operation_matrix.md` remains semantic authority and direct effect cases remain verification.
- `.agents/skills/change-contract/references/contract-rules.md:238` / verification ownership rule: tests may consume but never own or mirror product/documentation truth, and prose parsing, copied inventories, and self-referential fixtures are rejected -> the affected effect owner must delete these mirrors before adding partial cases.
- `docs/verification/guardrails.md:200` / registered completeness claim: `edit.operation_matrix_complete` promises executable proof for every semantic row and dimension -> because its only completeness mechanism is a forbidden copied/prose-parsing parity consumer, the ID and claim must be retired rather than left registered without proof.
- `docs/verification/guardrail_design_patterns.md:110` / prescribed invalid mechanism: the guardrail explicitly requires registry parity and runner inventory -> retire this pattern entry while preserving separately owned direct effect, rollback, invalidation, and no-op guarantees.
- `tool/guardrails/src/guardrail_registry.dart:195` / guardrail registration: the ID is registered as a current guarantee -> remove it atomically with its executor and durable consumers.
- `tool/guardrails/src/guardrail_executor.dart:280` / guardrail execution: the ID dispatches a test group -> remove the route while keeping the remaining executor registry closed and runnable.
- `docs/_registry/sections.yaml:350` / section consumer: operation-matrix and related sections require the ID -> remove every section reference and regenerate the guardrail index from registry truth.
- `docs/verification/release_gates.md:48` / release consumer: the ID is release-required -> retire that requirement in the same unit rather than leave a passing no-op gate.
- `docs/contracts/edit_kernel.md:95` / sparse lifecycle authority: every successful pre-materialization operation records one unchanged mutation and explicit draft reads are the materialization fallback -> partial updates preserve one mutation and zero projection on untouched sparse routes.
- `docs/contracts/public_api_v1.md:170` / public equality authority: every new concrete public type must choose equality before implementation -> all three new types use the design-selected identity policy while existing grid/palette policies remain unchanged.
- `docs/contracts/public_api_v1.md:720` / public DTO authority: caller-owned collections require defensive copy, runtime validation, and unmodifiable exposure -> `CanvasPaletteUpdate` performs those operations at construction and exposes no nullable list.
- `docs/contracts/public_api_v1.md:1514` / public edit lifecycle: callbacks are synchronous and atomic, callback failure rolls back, publication follows install, and stale handles throw `StateError` -> both new edit entries inherit the complete lifecycle.
- `docs/_registry/public_api_v1.yaml:1` / intentional exported-name inventory: this YAML owns only public name membership while semantic signatures remain in the public contract -> add exactly the three new names without copying fields or methods into the registry.
- `tool/guardrails/src/public_api_checks.dart:14` / registry consumer: the parity guard compares the registry with analyzer-resolved root exports in both directions -> the manual inventory has a distinct lifecycle, invariant, and direct verification and is not a conflicting semantic mirror.
- `test/api_contract/public_api_v1_compiles_as_written_test.dart:856` / direct external consumer: the maintained compile consumer implements `CanvasEdit` directly -> it migrates with each interface method and remains proof rather than API authority.
- `docs/architecture/02_package_boundaries.md:178` / production structure: stable public declarations belong under `contracts/public`, facade entries under `api`, and implementation owners consume contracts -> each unit preserves the existing owner graph and wrapper route.
- `docs/architecture/02_package_boundaries.md:260` / external fixture boundary: API-contract fixtures import only the root barrel and may not use `src/**` -> positive and negative public-surface proof stays quarantined at this boundary.
- `docs/architecture/02_package_boundaries.md:267` / test structure: owner tests mirror production owners while cross-cutting public proof stays under `test/api_contract/**` -> owner behavior and external compatibility evidence remain separated.
- `docs/verification/tests.md:463` / test shape owner: in-package behavior tests use ordinary package tests, external-consumer behavior must use `test/support/flutter_consumer_test_harness.dart`, and compile/analyzer fixtures may retain local runners only for their specialized source generation -> new artifacts use exact owner paths and these support/import boundaries.
- `test/api_contract/pointer_input_public_constructor_test.dart:6` / focused constructor-boundary precedent: an independent public constructor validation family owns one exact API-contract test using the shared external consumer harness -> palette and grid construction validation each receive a dedicated owner-scoped artifact rather than entering DTO immutability.
- `docs/architecture/03_data_model.md:69` / sole journal and candidate authority: Store and Draft consume the same mutation list, Store owns one candidate, and accepted publication constructs at most one aggregate -> partial palette/grid methods may add no replay or publication family.
- `docs/diagrams/state_runtime_lifecycle.mmd:20` / active read lifecycle: `readDocument` is a non-mutating active self-transition -> `readAppearance` must be documented on the same semantic lifecycle.
- `docs/diagrams/state_runtime_lifecycle.mmd:87` / disposed read lifecycle: the last committed document remains readable after dispose -> appearance inherits this exact last-committed read posture.
- `architecture/decisions/README.md:75` / ADR lifecycle authority: planning consumes the design-declared ADR impact rather than inventing one -> `ADR Impact: none` requires no ADR edit.
- `docs/architecture/architecture_graph.yaml:31` / expected graph authority: public facade/contracts and Store/Edit/RuntimeRoot already have registered nodes -> implementation must close the existing graph without adding or editing a node or edge.

## Boundaries

Owner: `DocumentStoreKernel` remains the sole committed appearance owner and coherence boundary; `CanvasRuntime` and `RuntimeRoot` only expose and delegate the read; `CanvasEdit` plus `EditSession` own the public mutation and stale-handle seam; sparse `EditSession` and materialized `DraftDocument` own transaction-local current palette/grid values; existing whole-value setters, the sole `StoreSparseMutation` journal, Store candidate, finalization, and effect owners remain authoritative. `docs/contracts/public_api_v1.md` owns semantic public signatures, while `docs/_registry/public_api_v1.yaml` owns only exported-name membership with direct analyzer parity.
In Scope: Add the exact `CanvasAppearance`, `CanvasPaletteUpdate`, and `CanvasGridUpdate` public contracts; add synchronous `CanvasRuntime.readAppearance`, `CanvasEdit.updatePalette`, and `CanvasEdit.updateGrid`; extend existing Store/root/facade and sparse/materialized edit owners; migrate every maintained direct implementer and positive public consumer; add quarantined negative public-surface witnesses; update runtime, Store, edit, data-model, operation-matrix, public API, lifecycle-diagram, export-inventory, and owning verification surfaces required by D-001 through D-004 and I-001 through I-002; retire the copied `_requiredEditOperationRows`, its self-parity assertion, the wrapper's Markdown/private-method exact-parity scan, and the now-unprovable `edit.operation_matrix_complete` guardrail across its contract, pattern, registry, executor, section, release-gate, and generated-index consumers while retaining separately owned direct install/effect/rollback/no-action guarantees.
Out of Scope: Application adapters, presets, profiles, client repositories or migrations; camera, selection, metadata, layers, elements, resources, or application state in `CanvasAppearance`; separate public appearance-field read operations that require callers to assemble a sequential snapshot; `updateBackground`; deprecation or removal of existing full reads/setters; V2/capability/extension fallbacks; new services, caches, stored appearance mirrors, Store mutation variants, journals, candidates, revisions, events, actions, publications, graph nodes/edges, ADR transitions, schemas, configuration, persistence fields, or general analyzers.
Source of Truth: The immutable committed Store aggregate is the only durable background/palette truth and supplies one coherent appearance read. Sparse overrides and the materialized Draft are intentional callback-local candidate state with a distinct lifecycle: only active edit backings consume them; each successful partial merge reduces to one complete existing mutation; promotion, Store finalization, callback rollback, or close terminates that state; sparse/materialized parity, sole-journal replay, no-op, rollback, and aggregate-publication evidence directly verify the invariant. Update DTOs own caller intent snapshots only and never become committed truth. Semantic signatures remain in Dart plus `docs/contracts/public_api_v1.md`; the YAML registry owns names only.
Compatibility: `readAppearance` is additive; `readDocument`, `readDraftDocument`, `setBackgroundColor`, `setGrid`, and `setPalette` remain available, non-deprecated, and behaviorally unchanged. Directly extending `CanvasEdit` is the accepted source break: every maintained implementation/consumer gains each method in its owning unit, both methods ship in the same completed release, and no compatibility fallback exists. Public types, signatures, identity equality, const posture, list exposure, errors, root exports, docs, and registry match D-002 through D-004. Persisted values, schema v1, JSON, configuration, existing events/actions/revisions, and external application concepts remain unchanged.
Order Constraints: Unit 1 first retires the invalid parity mirrors and unprovable guardrail while preserving direct detections and remaining guardrail closure. Unit 2 independently produces appearance after separate H-003, H-005, H-006, and H-007 checks. Unit 3 follows Units 1-2 and closes palette after H-002/H-004 checks. Unit 4 follows Units 1 and 3, closes grid plus final omission variants after fresh H-002/H-004 checks, and directly closes grid work budget. Unit 5 follows Units 3-4 and owns only mixed callback atomicity. Unit 6 independently follows Units 3-4 and owns only preparation/install failure. Unit 7 follows Units 5-6 and owns only cross-failure cleanup work-budget inspection. Unit 8 follows Units 2-4 for the external workflow. Within each unit, owners, consumers, docs/registries when affected, and unit-specific evidence land atomically. No release or lifecycle closure occurs until all eight units, six separate re-entry gates, negative/bypass evidence, temporal/atomicity/work-budget evidence, and final repository gates close. No production path is retired. H-002 requires an approved tri-state field contract and compatibility/migration semantics; H-003 requires a new coherence/projection/work decision; H-004 requires an approved compatibility/versioning form; H-005 requires a new draft-read owner with coherence/materialization/stale/rollback semantics; H-006 requires an approved cross-boundary owner/dependency/coherence decision; H-007 requires approved cross-owner coherence, lifecycle, and verification authority. Each true trigger stops only the affected upcoming unit before mutation; none permits a fallback or contract reinterpretation.
Temporal Surface Closure: `readAppearance` is synchronous, non-mutating, and reads only the last installed committed appearance before, during, and after an edit callback; it never exposes sparse/materialized draft intermediates, becomes current only after accepted Store installation, retains the old value after rollback, publishes nothing itself, and remains readable after dispose. Partial calls run synchronously on an active handle, merge in callback order from latest local state, validate before mutating that call's backing, become stale after every callback closure path, install/publish only after normal callback return, and reuse existing caught-versus-escaping failure semantics.
All-Or-Nothing Failure Boundary: Palette collection snapshot/validation occurs in DTO construction; context-dependent complete palette/grid validation occurs after merge and before that call mutates the backing. A caught invalid call preserves earlier valid callback changes, while an escaping validation or callback failure reaches no Store install or delivery. All partial-specific fallible work, Store final equality, and effect derivation finish before the existing irreversible install; accepted delivery uses the existing post-install boundary and is not rolled back. Appearance reads are side-effect-free and cannot create a partial mutation state.
Negative Proof And Fixture Quarantine: External-style negative inputs independently omit `updatePalette`, omit `updateGrid`, resolve each forbidden `CanvasAppearance` member, and resolve `CanvasEdit.updateBackground` against the real root barrel. They live only in `test/api_contract/**` owner-scoped input, never enter production/docs/registry truth, never copy an interface or name inventory, and never become a general source scanner. Stale, invalid-construction, invalid-merge, no-op, and rollback witnesses remain in their owning edit/API/runtime fixtures and cannot introduce invalid production state. The effect fixture keeps direct behavioral cases but no copied required-row inventory, Markdown parser, implemented-method parser, or exact-parity scanner.
Bounded Recognition Scope: No custom recognizer is introduced. The Dart analyzer/compiler is invoked only on the exact isolated invalid expressions authorized by D-004 and must return the corresponding missing-implementation or unresolved-member diagnostics from the real exported declarations. The target artifact is the quarantined external consumer source; the stop rule is the listed two method omissions, six forbidden appearance members, and `updateBackground`. Token searches, arbitrary syntax/JSONPath recognition, copied allowlists, and repository-wide feature scanners are forbidden.
Work Budget And Cost Displacement: Construction/import/reset: `CanvasAppearance` construction is O(1); a palette-update DTO snapshots and validates each supplied list once, bounded by existing palette limits; grid update construction is O(1); import/reset paths do not change. Mutation/update/replay: each palette call may construct and validate one complete merged `CanvasPalette`, including its accepted copy of all three bounded lists under F-001; each grid call is O(1); each successful changed sparse call appends exactly one existing complete-value mutation; replay uses the sole journal without another partial-specific collection pass, unrelated-document traversal, or second replay. Freeze/publication/install: existing Store finalization may perform its authorized whole-owner work once and constructs zero or one aggregate; partial updates add no extra freeze, install, publication, or aggregate pass. Query/read: `readAppearance` reads one coherent committed scalar aggregate in O(1), performs zero full projection builds, and does no work proportional to unrelated layers/elements/resources/metadata. Cleanup/rollback: existing callback-local journal/backing disposal is the only cleanup; failures add no projection, document-wide traversal, compensating install, or second rollback lifecycle. Work may not be displaced beyond the DTO snapshot and one F-001-compliant complete merged-value construction.

## Execution Units

### [ ] Unit 1: Retire copied effect-proof authority

Owner: Existing edit effect verification plus the guardrail contract, pattern catalog, registry, executor, section/release consumers, and generated guardrail index; the semantic operation matrix remains behavior authority, not a machine-parsed inventory.
Boundary: Remove `_requiredEditOperationRows`, its self-parity assertion, the wrapper's Markdown/implemented-method parser, and the `edit.operation_matrix_complete` ID from every owning/consuming guardrail surface; regenerate only the owned index. Retain direct fixture cases and separate guardrails/assertions for installation, typed effects, rollback, invalidation, no-action, and runner execution. Do not add a replacement inventory/parser/scanner, production behavior change, or semantic operation row in this unit.
Verification Profile: `TEST_REFACTOR`
Change: The repository stops claiming an unenforceable exact row-completeness guardrail, while direct runtime guarantees and the remaining guardrail registry/release routes remain executable and authoritative.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `operation-matrix-guardrail-retirement` | A copied list/parser and registered `edit.operation_matrix_complete` claim compete with the semantic owner and current verification rules. | The mechanism, guardrail ID, documentation/pattern entries, registry/executor route, section/release references, and generated index entry are removed together. | No repository surface claims exact row parity and the retired ID has no orphan authority or consumer. | No replacement inventory/parser/scanner remains; semantic operation rows and production behavior are unchanged. |
| `remaining-guardrail-route-preserved` | The guardrail registry, executor, section/release consumers, and generated index are closed before retirement. | Existing registry/executor and root-CI ownership tests run after the one-ID retirement and docs regeneration. | Every remaining registered guardrail still has a valid dispatch/release route and generated index membership with no orphan or missing runner. | This runtime/structural result is not inferred from source absence or docs checks alone. |
| `effect-proof-sensitivity-preserved` | Direct cases detect installation, typed effects, rollback, and no-action behavior before the refactor. | The retained effect suite runs after mirror retirement with its behavioral assertions intact. | The same runtime guarantees remain directly executable for every retained case. | Passing source inspection is not a proxy; no detection is retired or transferred under this unit. |

Depends On: None

### [ ] Unit 2: Expose one coherent projection-free appearance read

Owner: Public appearance declaration, Store committed appearance read, RuntimeRoot and CanvasRuntime delegation, public API/export inventory, runtime/data-model/lifecycle documentation, and Store, lifecycle, projection, and public-contract verification owners.
Boundary: Add `CanvasAppearance` and `readAppearance` end-to-end through existing owners; preserve exact identity/public shape, immutable public collection views, one Store coherence boundary, zero full projection, active-edit last-committed visibility, rollback/post-install/dispose behavior, forbidden-member absence, engine-only dependencies, and unchanged `readDocument`. Owner behavior remains an ordinary package test; positive and isolated negative public-surface variants remain with the existing specialized analyzer owner and import only the root barrel.
Verification Profile: `BEHAVIOR_CHANGE`
Change: Public callers synchronously read exactly background color, complete grid, and complete palette from one committed Store state without constructing or warming a full `CanvasDocument` projection.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `appearance-exact-public-surface` | The root barrel exposes `readDocument` and the existing document values but no appearance type or read. | A root-barrel consumer constructs `CanvasAppearance` and calls `CanvasRuntime.readAppearance`. | The exact D-002 constructor, fields, synchronous return, identity equality, export, semantic docs, and inventory membership are available. | The type is `@immutable final`, has no additional public state, and existing public reads/signatures remain non-deprecated and unchanged. |
| `appearance-coherent-projection-free` | Successive committed states have distinguishable background color, every grid field, every palette field, and increasing unrelated document content. | The runtime reads appearance at each committed boundary. | Every returned field comes from the same committed state, projection-build count remains unchanged, and a later `readDocument` performs the first full projection. | The read assembles no layers, elements, resources, or metadata; work is independent of unrelated document size; no cache, mirror, or service is added. |
| `appearance-lifecycle-visibility` | A runtime is active before, during, and after successful and failing callbacks, then disposed. | The caller reads appearance at each boundary. | Reads during callbacks return last installed state; success becomes visible only after install; rollback preserves the old state; dispose returns the last committed state. | The read itself causes no mutation, revision, projection invalidation/build, repaint, event/action, or public-state publication. |
| `appearance-collection-views-immutable` | A committed appearance contains non-empty palette collections. | A caller obtains every collection through `readAppearance` and attempts mutation. | Every mutation attempt fails and a second appearance read returns unchanged committed values without another edit. | Only public appearance views are used; nominal list types, annotations, or private backing inspection are rejected. |
| `appearance-forbidden-surface` | External consumer variants attempt every excluded appearance member. | Each variant is analyzed against the real root barrel. | `camera`, `selection`, `metadata`, `layers`, `elements`, and `resources` are individually unresolved. | Fixtures are isolated and quarantined; registry absence, grep, copied declarations, or a custom scanner are not accepted proof. |
| `appearance-single-read-surface` | The completed public runtime already has the full-document read and the new coherent appearance read. | The final exported runtime/edit declarations and semantic public contract are inspected together. | `readAppearance` is the only new appearance-specific public read; no operation exposes background color, grid, or palette as separately sequenced appearance reads. | The outcome does not prohibit existing full `readDocument`; it rejects any additional per-field appearance read regardless of private name or declaration-file placement. |
| `appearance-existing-owner-boundary` | Store committed facts, existing facade/root delegation, and registered architecture owners are current. | The appearance route and semantic documentation are added. | Store remains the sole committed owner and the existing facade-to-root-to-Store plus contracts-led dependency direction remains closed. | No graph node/edge, ADR transition, API back edge, application dependency, duplicate truth, cache, or synchronization lifecycle appears. |
| `appearance-durable-owner-alignment` | Runtime, Store, data-model, public API, and lifecycle owners describe only full document reads. | The lightweight read is implemented and each semantic owner is updated. | All named owners agree on coherent Store ownership, projection avoidance, active/edit/install/rollback/dispose visibility, and public shape. | Generated docs remain projections; passing runtime tests or docs checks alone does not substitute for direct semantic-owner agreement. |
| `appearance-engine-only-boundary` | The existing runtime/read dependency route contains only engine owners and engine-domain types. | The new appearance type and read route are added. | Exported declarations, implementation owners, and dependency edges remain engine-only. | No application adapter, preset/profile concept, migration, state, or dependency enters the package. |
| `retained-document-read-behavior` | `readDocument` is the supported full projection with active and post-dispose semantics. | The additive appearance route is implemented. | `readDocument` retains its declaration, projection, caching, lifecycle, and immutable result behavior. | The lightweight route does not redirect, deprecate, or weaken the explicit full-document route. |
| `structural-snapshot-expansion-stop` | H-003 is checked before Unit 2 against the complete requested snapshot. | The required field set is compared with the accepted three persisted appearance domains. | No structural domain has entered scope, or Unit 2 stops before mutation for new coherence/projection/work authority. | Renamed or nested metadata/layer/element/resource fields count as a true trigger. |
| `draft-visible-appearance-stop` | H-005 is checked before Unit 2 against exact temporal requirements. | Required callback visibility is compared with last-installed committed semantics. | Draft intermediates are not required, or Unit 2 stops before mutation for a draft-read owner/lifecycle decision. | An existing draft read does not authorize changing `readAppearance`. |
| `application-state-snapshot-stop` | H-006 is checked before Unit 2 against requested types, fields, and dependencies. | Each requested snapshot domain is mapped to its owner. | No application-domain state enters scope, or Unit 2 stops for cross-boundary owner/coherence authority. | Generic naming does not hide an application-owned type or adapter. |
| `runtime-local-snapshot-stop` | H-007 is checked before Unit 2 against camera and selection owners. | Each requested snapshot field is compared with persisted and runtime-local ownership. | Camera and selection remain excluded, or Unit 2 stops for cross-owner coherence/lifecycle/proof authority. | Renamed or nested runtime-local state counts as a true trigger. |

Depends On: None

### [ ] Unit 3: Add transaction-local partial palette updates

Owner: `CanvasPaletteUpdate`, the `CanvasEdit.updatePalette` public seam, EditSession stale/backing dispatch, sparse and materialized palette mutation owners, public contract/export inventory, and palette behavior, DTO, equality, effect, no-op, rollback, stale, Store, and public-contract verification owners.
Boundary: Add palette intent snapshotting, presence inspection, construction validation, latest-local merge, sparse/materialized parity, exact whole-setter effects, direct palette rollback/no-op/stale behavior, and maintained direct-consumer migration end-to-end. Application behavior remains an ordinary edit test; copying/view proof extends DTO immutability, while constructor validation uses a dedicated owner-scoped API-contract test with the shared external consumer harness. Consume Unit 1's cleaned effect owner and Unit 2's public appearance read; create no omission analyzer source, grid method, cross-family scenario, partial Store variant, second journal, full draft read, or compatibility fallback.
Verification Profile: `BEHAVIOR_CHANGE`
Change: Public callers independently replace any supplied palette field, including with an empty list, while omitted fields retain the latest transaction-local palette and the existing whole-palette transaction semantics remain authoritative.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `palette-update-exact-public-surface` | `CanvasEdit` exposes only `setPalette`, and no palette update DTO exists. | A root-barrel consumer constructs absent, empty, and populated updates and invokes `updatePalette`. | The exact factory, presence getters, non-null list getters, `void` method, identity equality, export, docs, registry, and all maintained Unit 3 direct consumers agree. | Existing methods remain unchanged; Unit 3 compiles independently and creates no future-only analyzer artifact; no fallback or copied interface truth exists. |
| `palette-update-presence-application` | Absent, supplied-empty, and populated fields are distinguishable. | Each shape is constructed and applied over distinguishable transaction-local palette values. | Presence getters distinguish omission from empty replacement, omitted fields retain latest-local values, and supplied empty lists clear only their own fields. | List getters remain non-null and unmodifiable; all-null intent is a no-op. |
| `palette-update-context-free-construction` | Each supplied palette field is exercised against every applicable existing context-free validation family. | `CanvasPaletteUpdate` construction runs before an edit callback or backing access for each isolated invalid field/rule case. | Construction rejects every over-item field case and every grid-size numeric failure family with the existing public error/path. | No representative subset, late edit validation, copied limit table, mutation, projection, or publication is accepted. |
| `palette-update-alias-isolation` | Caller-owned mutable lists are passed to the DTO and later changed, and exposed getters are mutation-attempted. | The DTO is inspected before and after application through the public appearance read. | The update DTO and installed appearance retain constructor-time intent and every update/appearance list view rejects mutation. | DTO construction snapshots each supplied bounded list once; F-001 separately authorizes one complete merged `CanvasPalette` construction during the call. |
| `palette-construction-work-bound` | Supplied lists are bounded by established palette limits and F-001 authorizes one complete merged value per call. | Construction, edit, replay, install, and cleanup paths are inspected after implementation. | DTO construction performs one supplied-list snapshot/validation and edit performs at most one complete merged `CanvasPalette` construction/copy/validation. | No additional collection pass is displaced into replay, install, publication, or rollback and no unrelated document owner is traversed. |
| `palette-update-sequential-backing-parity` | Distinguishable base palette values exist in untouched sparse and deliberately materialized sessions. | Disjoint and overlapping partial palette calls run in callback order on both backings. | Later calls preserve omitted fields from the latest local palette and both backings commit the same complete palette. | Untouched sparse calls build no public projection, each changed call records one complete palette mutation, and explicit draft read remains the only promotion trigger. |
| `palette-update-effects-and-no-op` | Identical bases reach a final palette through `setPalette` or partial calls, including all-null, locally equal, and compensating-final-equal sequences. | Changed parity routes and every no-op form execute on untouched sparse and deliberately materialized backings while all effect domains are observed. | Changed routes agree with the whole setter; every no-op form on both backings delivers nothing. | Final Store facts own acceptance; sparse success cannot proxy materialized silence; existing whole-value behavior remains unchanged. |
| `palette-update-rollback-boundary` | A valid palette partial update precedes an escaping callback error. | The callback fails after the update. | No palette fact, revision, invalidation, repaint, event/action, or public-state publication escapes. | All palette-specific fallible work precedes install; cleanup builds no projection and adds no compensating install. |
| `palette-update-stale-boundary` | Handles from successful, escaping-failure, and rejected-async callback closure paths are captured. | Each stale handle invokes `updatePalette`. | Every call throws `StateError` with unchanged committed/effect state. | Stale rejection precedes backing/merge access and no collection work is displaced after the call begins. |
| `palette-update-single-store-path` | Store has one candidate, one mutation journal, complete palette mutation replay, owner-derived equality, and zero-or-one aggregate publication. | Sparse palette partial sequences run with and without later promotion. | Each changed call admits exactly one existing complete palette mutation, promotion replays it once, final facts derive from owners, and Store publishes at most one aggregate. | No partial mutation family, second candidate/journal, history-derived acceptance, duplicate replay, or displaced install/cleanup pass exists. |
| `palette-engine-only-boundary` | Palette mutation currently uses engine DTOs and the established edit/Store owners. | Partial palette support is added. | Public declarations, edit backings, Store mutation path, and dependency edges remain engine-only. | No application adapter, preset/profile concept, migration, or duplicate policy owner appears. |
| `retained-whole-palette-behavior` | `setPalette` owns complete-value validation, transaction, effect, no-op, and rollback behavior. | The additive palette method is implemented. | `setPalette` retains its declaration and all established behavior. | The partial method reduces to the existing whole-value path without changing whole-setter semantics. |
| `retained-draft-document-read-behavior` | `readDraftDocument` owns explicit materialization, current callback-local result, and stale-handle lifecycle. | Unit 3 extends the edit and backing seams. | Draft reads retain exact result, explicit-promotion behavior, synchronous callback availability, and stale rejection. | Using the read only as a promotion trigger is not evidence; existing result/lifecycle owners must pass directly. |

Depends On:
- Unit 1 — produces: direct effect verification without copied/prose-parsing authority; consumed as: the palette partial effect case and retained behavior run.
- Unit 2 — produces: public `readAppearance` and immutable appearance collection views; consumed as: A-016's post-application alias oracle through the required public seam.

### [ ] Unit 4: Add transaction-local partial grid updates

Owner: `CanvasGridUpdate`, the `CanvasEdit.updateGrid` public seam, EditSession stale/backing dispatch, sparse and materialized grid mutation owners, public contract/export inventory, and grid behavior, constructor, effect, no-op, rollback, stale, Store, and public-contract verification owners.
Boundary: Add grid presence/merge/validation, context-free constructor validation, sparse/materialized parity, whole-setter effects, direct grid rollback/no-op/stale behavior, and accepted direct-interface migration end-to-end. Application behavior remains an ordinary edit test; constructor validation uses its own owner-scoped API-contract test with the shared external consumer harness. Consume Unit 1's cleaned effect owner, migrate every maintained Unit 3 shared-interface consumer to implement `updateGrid`, and create both final isolated one-method-omission variants here; add no palette runtime scenario, combined workflow, background-update method, partial Store variant, second journal, or compatibility fallback.
Verification Profile: `BEHAVIOR_CHANGE`
Change: Public callers independently update grid fields from the latest transaction-local state with complete-value validation while existing whole-grid semantics remain authoritative.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `grid-update-exact-public-surface` | `CanvasEdit` exposes only `setGrid`, and no grid update DTO exists. | A root-barrel consumer constructs field subsets and invokes `updateGrid`. | The exact non-const factory, nullable scalar getters, `void` method, identity equality, export, docs, registry, consumers, and direct implementers agree. | Final isolated sources each omit exactly one new method: palette omission implements grid, grid omission implements palette; `updateBackground` remains unresolved. |
| `final-interface-one-method-omissions` | The final `CanvasEdit` interface contains both new methods and all maintained consumers have migrated. | Two isolated external implementers each omit one different new method while implementing the other. | Each source is rejected only for its one missing implementation and every maintained consumer compiles. | Palette omission implements grid; grid omission implements palette; no default, extension, capability, or copied-interface fallback exists. |
| `grid-update-context-free-construction` | A caller supplies each distinct cell-size class invalid regardless of transaction-local sibling fields. | `CanvasGridUpdate` construction runs for isolated non-finite, negative, and above-maximum cases before edit/backing access. | Every context-free invalid family throws the existing public validation error immediately. | Context-dependent zero/below-enabled-minimum remains merge-owned; representative subsets, copied tables, late rejection, mutation, projection, or publication are rejected. |
| `grid-update-presence-and-validation` | Current transaction-local grid facts make some constructor-valid field subsets valid and others invalid only after merge. | Each field alone, all-null, valid boundaries, and context-dependent invalid updates execute. | Null preserves its field; valid merged complete grids install; invalid merged grids throw the existing public validation error and mutate none of that call's fields. | Stale guard runs first; complete-value validation remains owned by `CanvasGrid`; no copied validation table or partial invalid state exists. |
| `grid-update-sequential-backing-parity` | Distinguishable base grid values exist in untouched sparse and deliberately materialized sessions. | Disjoint and overlapping partial grid calls run in callback order on both backings. | Later calls preserve omitted fields from the latest local grid and both backings commit the same complete grid. | Untouched sparse calls build no public projection, each changed call records one complete background mutation, and explicit draft read remains the only promotion trigger. |
| `grid-update-effects-and-no-op` | Identical bases reach a final grid through `setGrid` or partial calls, including all-null, locally equal, and compensating-final-equal sequences. | Changed parity routes and every no-op form execute on untouched sparse and deliberately materialized backings while all effect domains are observed. | Changed routes agree with the whole setter; every no-op form on both backings delivers nothing. | Final Store facts own acceptance; sparse success cannot proxy materialized silence; whole-grid behavior and revision families remain unchanged. |
| `grid-update-rollback-boundary` | A valid grid partial update precedes an escaping validation or callback error. | The callback lets the failure escape. | No grid fact, revision, invalidation, repaint, event/action, or public-state publication escapes. | All grid-specific fallible work precedes install; cleanup builds no projection and adds no compensating install. |
| `grid-update-stale-boundary` | Handles are captured after successful callback, escaping failure, and rejected async callback closure. | Each stale handle invokes `updateGrid` with a constructor-valid value that would fail only after merge. | Every call throws `StateError` and leaves committed facts, revisions, projection, repaint, events/actions, and state publication unchanged. | Stale rejection precedes merged-value validation and backing access; private guard names are not part of the oracle. |
| `grid-update-single-store-path` | Store has one candidate, one journal, complete background mutation replay, owner-derived equality, and zero-or-one publication. | Sparse grid partial sequences run with and without later promotion. | Each changed call admits exactly one existing complete background mutation, promotion replays it once, final facts derive from owners, and Store publishes at most one aggregate. | No partial mutation family, second candidate/journal, history-derived acceptance, duplicate replay, or displaced install/cleanup pass exists. |
| `grid-update-work-bound` | Grid DTO construction and each update start with only scalar fields and the existing complete background mutation path. | Constructor, sparse/materialized mutation, replay, finalization, install, and publication owners are inspected after Unit 4. | Construction and merge remain O(1), each changed call creates one complete background mutation, and later phases add no partial-specific or unrelated-document pass. | Correct journal/publication counts do not proxy work: any layer/element/resource traversal, second replay, or displaced phase pass violates the outcome. |
| `grid-engine-only-boundary` | Grid mutation currently uses engine DTOs and the established edit/Store owners. | Partial grid support is added. | Public declarations, edit backings, Store mutation path, and dependency edges remain engine-only. | No application adapter, preset/profile concept, migration, or duplicate policy owner appears. |
| `retained-whole-grid-behavior` | `setGrid` owns complete-value validation, transaction, effect, no-op, and rollback behavior. | The additive grid method is implemented. | `setGrid` retains its declaration and all established behavior. | The partial method reduces to the existing whole-value path without changing whole-setter semantics. |
| `retained-background-color-setter-behavior` | `setBackgroundColor` owns color validation, grid sibling preservation, sparse/materialized transaction behavior, effects, no-op, rollback, and public availability. | Unit 4 changes the neighboring background/grid merge and shared edit/backing seams. | Every established background-color setter behavior remains unchanged and non-deprecated. | Grid partial success or declaration presence cannot substitute for direct whole-setter behavior. |
| `nullable-update-field-stop` | H-002 is checked before Unit 3 and again before Unit 4 against every updateable field/value. | Current requirements are compared with null-as-absence semantics. | All stored values remain non-null, or only the affected upcoming unit stops for tri-state/compatibility authority. | A nullable field in either DTO is a true trigger even if the other family remains non-null. |
| `direct-implementer-compatibility-stop` | H-004 is checked before Unit 3 and again before Unit 4 against release compatibility requirements. | The accepted direct source break is compared with current legacy-implementer expectations. | Old implementers need not compile unchanged, or only the affected upcoming unit stops for versioning/compatibility authority. | A default/extension fallback is not an allowed way to keep the trigger false. |

Depends On:
- Unit 1 — produces: direct effect verification without copied/prose-parsing authority; consumed as: the grid partial effect case and retained behavior run.
- Unit 3 — produces: the palette-extended maintained `CanvasEdit` consumer set; consumed as: mandatory interface migration to add `updateGrid` everywhere before Unit 4 creates its two final isolated omission witnesses.

### [ ] Unit 5: Prove cross-family transaction atomicity

Owner: Cross-family edit integration verification using public edit entries.
Boundary: Add only direct mixed palette/grid witnesses for caught per-call rejection and escaping validation/callback failure. Do not extend the preparation/install injection owner, change production/public/docs, or duplicate owner-specific happy paths, validation tables, effect inventories, or Store internals.
Verification Profile: `BEHAVIOR_CHANGE`
Change: The two independently completed partial-update families are proven to share the existing callback transaction boundary without leaking mixed intermediate state or erasing earlier valid work after a caught rejection.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `partial-update-transaction-atomicity` | Earlier valid palette and grid partial calls precede a caught invalid grid call, an escaping validation failure, or a later callback exception. | The callback catches or lets each failure escape. | Caught rejection preserves earlier valid work for normal commit; every escaping failure installs and publishes none of either family. | Every committed/effect/publication domain is observed; cleanup adds no projection, traversal, compensating install, or second rollback path. |

Depends On:
- Unit 3 — produces: complete `CanvasEdit.updatePalette` behavior; consumed as: one side of mixed transaction witnesses.
- Unit 4 — produces: complete `CanvasEdit.updateGrid` behavior; consumed as: rejection and the other side of mixed transaction witnesses.

### [ ] Unit 6: Prove the pre-install owner-failure boundary

Owner: Existing stable preparation/install failure-injection verification.
Boundary: Extend only the existing admitted preparation failure scenario so valid palette and grid partial work precedes the injected owner failure; observe every installer and public delivery boundary. Do not create a new failure hook, cross-family callback integration owner, production/public/docs change, post-install compensation, or VM-fatal case.
Verification Profile: `BEHAVIOR_CHANGE`
Change: The existing preparation/install oracle proves that partial-specific accepted work cannot move an expected owner failure past irreversible installation.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `partial-update-preinstall-failure-boundary` | Valid palette and grid partial work reaches the existing stable preparation boundary with installer and delivery observations armed. | The admitted owner failure is injected during preparation. | The expected failure escapes with zero installer calls, zero public delivery, and unchanged committed/effect state. | The injection uses the existing preparation seam; post-install compensation, VM-fatal injection, or a new production hook is forbidden. |

Depends On:
- Unit 3 — produces: complete palette partial-update behavior; consumed as: valid work before preparation failure.
- Unit 4 — produces: complete grid partial-update behavior; consumed as: valid work before preparation failure.

### [ ] Unit 7: Close partial-update cleanup work budgets

Owner: Existing callback-local edit backing disposal, Store preparation/finalization failure exit, and rollback lifecycle owners.
Boundary: Inspect cleanup paths for caught validation rejection, escaping validation/callback failure, and admitted preparation failure after partial updates. Prove absence of projection, unrelated-document traversal, compensating install, repeated replay, and a second rollback lifecycle. Do not add instrumentation, tests, production cleanup, or substitute final atomic state for work-path evidence.
Verification Profile: `BEHAVIOR_CHANGE`
Change: Failure handling is closed not only for atomic results but also for the absence of displaced or repeated cleanup work.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `partial-update-cleanup-work-bound` | Units 5 and 6 prove functional callback/preparation failure results. | Bounded owner-level inspection follows every partial-update failure exit through backing disposal, Store preparation, installer bypass, and delivery bypass. | Each failure uses the existing single cleanup/rollback lifecycle with no projection, unrelated traversal, compensating install, repeated replay, or displaced owner pass. | A pure extra traversal or second rollback pass fails even when all final facts/effects remain unchanged. |

Depends On:
- Unit 5 — produces: caught and escaping callback failure routes; consumed as: cleanup exits under inspection.
- Unit 6 — produces: admitted preparation failure route; consumed as: pre-install cleanup exit under inspection.

### [ ] Unit 8: Prove the external lightweight appearance workflow

Owner: External public-consumer behavior using the repository's shared Flutter consumer harness; the feature test owns its package name, generated filename, and root-barrel-only consumer source.
Boundary: Execute one real-runtime external consumer workflow that reads appearance, applies palette and grid subsets in one synchronous edit, and reads appearance again. Prove only root-barrel behavior and that consumer code makes no full committed/draft read; internal projection avoidance remains Unit 2's Store/projection proof. Do not import implementation sources, inspect private Store/edit owners, duplicate public signature inventories, introduce a local runner, or change production/docs in this unit.
Verification Profile: `BEHAVIOR_CHANGE`
Change: A downstream consumer is proven able to use the completed root public surface without reading either a committed or draft full document.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `lightweight-appearance-partial-update-workflow` | A real runtime has distinguishable persisted appearance and unrelated document content. | A root-barrel consumer calls `readAppearance`, applies palette and grid subsets in one synchronous edit, and calls `readAppearance` again. | The committed appearance contains both requested partial results while consumer source uses no full committed/draft read. | The shared external harness is used; internal projection avoidance is proven only by Unit 2 and no excluded appearance/application surface is accessed. |

Depends On:
- Unit 2 — produces: synchronous coherent `CanvasRuntime.readAppearance`; consumed as: before/after external observation.
- Unit 3 — produces: `CanvasEdit.updatePalette`; consumed as: external palette input.
- Unit 4 — produces: `CanvasEdit.updateGrid`; consumed as: external grid input.

## Verification Matrix

| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | Pass signal | Evidence constraints and rejected proxy | Adversarial false-positive case and kill signal | Durable impact | Artifact target | Admission |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `lightweight-public-workflow-evidence` | `lightweight-appearance-partial-update-workflow` | `TEST` | `test/api_contract/appearance_partial_updates_public_behavior_test.dart` using `test/support/flutter_consumer_test_harness.dart`, with root-barrel-only generated consumer source. | No appearance read or partial update declaration exists, so the root-barrel workflow cannot compile or execute. | A real runtime completes the exact before/edit/after workflow with both partial results and consumer source invokes no full committed/draft read. | Shared external harness, root barrel, and real runtime/edit entries are admissible; implementation imports, local runners, private calls, compile-only DTO use, or projection-counter claims are rejected. | The external workflow can only observe the result by calling `readDocument`; the owned consumer source and successful appearance-only assertions kill it. | `ADD` | `test/api_contract/appearance_partial_updates_public_behavior_test.dart` | `lightweight-public-workflow-admission` |
| `appearance-coherence-evidence` | `appearance-coherent-projection-free` | `TEST` | Ordinary package test `test/store/appearance_read_test.dart` with `test/store/fixtures/appearance_read_fixture.dart`, using two distinguishable committed boundaries and direct same-boundary Store facts. | `CanvasAppearance` and `readAppearance` are absent, so no coherent appearance value can be observed. | Every public field equals facts from the same committed aggregate at both boundaries, including complete grid and palette. | Direct Store facts plus the public read are admissible; `readDocument`, copied expected inventories, one field, or one quiescent state are rejected. | Background comes from the new state but palette is captured from the prior state; distinct complete values kill it. | `ADD` | `test/store/appearance_read_test.dart` and `test/store/fixtures/appearance_read_fixture.dart` | `appearance-coherence-admission` |
| `appearance-single-read-surface-evidence` | `appearance-single-read-surface` | `MANUAL_INSPECTION` | Bounded comparison of the final exported `CanvasRuntime`/public contract declarations with D-002 and R-003. | The current surface has no lightweight appearance read; sequential-field exclusion becomes material only when the new neighboring surface is added. | Exactly one new appearance-specific read returns the coherent aggregate, and no separate background-color, grid, or palette appearance read operation is exported. | Direct exported declaration and semantic-contract review are admissible; absence of guessed names, registry membership, grep, positive workflow success, or a custom scanner are rejected. | `readAppearance` is coherent and all behavior tests pass, but another public method independently returns the current grid; complete exported-surface inspection kills it. | `NONE` | None | None |
| `appearance-projection-evidence` | `appearance-coherent-projection-free` | `TEST` | Existing projection observation owner through `dart test test/store/no_projection_hot_path_test.dart`, extended with the new public appearance-read failure family, plus bounded Store read-boundary inspection. | No lightweight read exists; the only public committed appearance route is `readDocument`, which builds full projection. | Repeated appearance reads across increasing unrelated content leave projection builds at zero, later `readDocument` is the first build, and Store reads no unrelated collection owner. | Stable projection observation and bounded owner audit are admissible; sparse-edit projection cases, timing, cached speed, helper names, or count alone are rejected. | Sparse edits remain projection-free but `readAppearance` calls `readDocument`; the new direct read case kills it. | `EXTEND_COVERAGE` | `test/store/fixtures/no_projection_hot_path_fixture.dart` | `appearance-projection-admission` |
| `appearance-lifecycle-evidence` | `appearance-lifecycle-visibility` | `TEST` | `test/store/appearance_read_test.dart`, `test/store/fixtures/appearance_read_fixture.dart`, and existing `test/runtime/dispose_lifecycle_test.dart`, `test/runtime/runtime_state_publication_test.dart`, and `test/edit/rollback_test.dart`. | The read is absent, so active-edit, rollback, post-install, and post-dispose appearance visibility cannot be observed. | Distinct intermediate values prove last-committed visibility, success-after-install, rollback retention, delivery silence, and post-dispose readability. | Real public runtime/edit boundaries are admissible; before/after-success only, full document reads, or exception-only assertions are rejected. | Success/dispose pass but an active callback exposes draft grid; the intermediate callback read kills it. | `EXTEND_COVERAGE` | `test/store/appearance_read_test.dart`, `test/store/fixtures/appearance_read_fixture.dart`, and named existing lifecycle tests | `appearance-lifecycle-admission` |
| `appearance-collection-view-evidence` | `appearance-collection-views-immutable` | `TEST` | Public read cases in `test/store/appearance_read_test.dart` and `test/store/fixtures/appearance_read_fixture.dart`. | `CanvasAppearance` is absent, so its palette collection views cannot be mutation-probed. | Mutation through every appearance palette collection view fails and a subsequent public read returns unchanged values without an edit. | Real public reads and collection views are admissible; annotations, nominal types, private fields, or update DTO views as proxy are rejected. | One palette list is a mutable alias while the others reject mutation; per-view attempts and reread kill it. | `ADD` | `test/store/appearance_read_test.dart` and `test/store/fixtures/appearance_read_fixture.dart` | `appearance-collection-view-admission` |
| `palette-presence-evidence` | `palette-update-presence-application` | `TEST` | `test/edit/palette_update_test.dart` with `test/edit/fixtures/palette_update_fixture.dart`. | The DTO/method are absent, so omission and supplied-empty replacement cannot be distinguished in real application. | Absent, empty, populated, each-field-only, and all-null cases preserve or replace exactly the intended latest-local fields. | Real DTO and edit application are admissible; nullable getters, constructor-only assertions, final palette without distinguishable siblings, or copied field inventories are rejected. | Empty is treated as absent and the prior list survives; the supplied-empty case kills it. | `ADD` | `test/edit/palette_update_test.dart` and `test/edit/fixtures/palette_update_fixture.dart` | `palette-presence-admission` |
| `palette-constructor-validation-evidence` | `palette-update-context-free-construction` | `TEST` | Dedicated `test/api_contract/palette_update_public_constructor_test.dart` using `test/support/flutter_consumer_test_harness.dart` and root-barrel-only source. | `CanvasPaletteUpdate` is absent, so invalid supplied lists cannot be rejected at its boundary. | Constructor-time witnesses cover over-item validation independently for pen colors, background colors, and grid sizes, plus every distinct public grid-size numeric failure family before edit entry. | Public constructor, existing validators, exact paths/codes, and one isolated failure per field/rule family are admissible; implementation imports, copied limits, late rejection, representative subsets, or another field's failure are rejected. | Pen/background limits and one bad grid size fail, but over-maximum grid size is stored until edit; its isolated constructor source succeeds and kills it. | `ADD` | `test/api_contract/palette_update_public_constructor_test.dart` | `palette-constructor-validation-admission` |
| `palette-alias-evidence` | `palette-update-alias-isolation` | `TEST` | Existing `test/api_contract/dto_immutability_test.dart` plus public-update/application/read cases in `test/edit/fixtures/palette_update_fixture.dart`. | The DTO is absent, so source and update getter aliases cannot be observed through application. | Every valid source is mutated before edit and again after edit; every update list view rejects mutation; `readAppearance` retains constructor-time installed values. | Public constructors, update views, real edit application, and public appearance read are admissible; annotations, private fields, nominal types, direct Store facts, or unmodifiable-view-only checks are rejected. | An update getter is unmodifiable but views mutable source; source mutation changes the later public appearance and kills it. | `EXTEND_COVERAGE` | `test/api_contract/dto_immutability_test.dart` and `test/edit/fixtures/palette_update_fixture.dart` | `palette-alias-admission` |
| `palette-construction-work-evidence` | `palette-construction-work-bound` | `SOURCE_QUERY` | Bounded final diff inspection of DTO construction and palette edit/replay/install/cleanup owners against F-001. | No update DTO or partial route exists. | DTO construction snapshots/validates each supplied list once; each partial call constructs/validates at most one complete merged `CanvasPalette`; no further collection pass is displaced. | Named phase owners and accepted F-001 form are admissible; timing, allocation heuristics, counters, or token absence alone are rejected. | Edit constructs two complete palettes or replay recopies lists; bounded phase inspection kills it. | `NONE` | None | None |
| `grid-validation-evidence` | `grid-update-presence-and-validation` | `TEST` | `test/edit/grid_update_test.dart` with `test/edit/fixtures/grid_update_fixture.dart`. | The DTO/method are absent, so independent fields and merge-dependent validation cannot be exercised. | Each field alone, all-null, valid boundaries, and constructor-valid/merge-invalid states produce the exact committed value or existing public validation error with no per-call mutation. | Real DTO/edit/`CanvasGrid` boundary is admissible; copied validation tables, constructor-only checks, helper calls, or exception type alone are rejected. | Validation runs before merging and accepts a combination invalid for the latest local state; the distinguishable case kills it. | `ADD` | `test/edit/grid_update_test.dart` and `test/edit/fixtures/grid_update_fixture.dart` | `grid-validation-admission` |
| `grid-constructor-validation-evidence` | `grid-update-context-free-construction` | `TEST` | Dedicated `test/api_contract/grid_update_public_constructor_test.dart` using `test/support/flutter_consumer_test_harness.dart` and root-barrel-only source. | `CanvasGridUpdate` is absent, so unconditionally invalid supplied scalars cannot be rejected at construction. | Isolated constructor witnesses cover every cell-size class invalid regardless of sibling state: non-finite, negative, and above maximum; context-dependent zero/below-enabled-minimum remains merge evidence. | Public constructor, existing diagnostics, and every context-free family are admissible; implementation imports, copied tables, representative subsets, late rejection, or merged-grid failure are rejected. | Non-finite and negative fail but above-maximum survives until edit; its constructor-only source succeeds and kills it. | `ADD` | `test/api_contract/grid_update_public_constructor_test.dart` | `grid-constructor-validation-admission` |
| `palette-sequential-evidence` | `palette-update-sequential-backing-parity` | `TEST` | `test/edit/palette_update_test.dart` and `test/edit/fixtures/palette_update_fixture.dart`, covering sparse and explicitly materialized backings. | No partial method exists, so stale-base omission and backing parity are unverified. | Distinguishable disjoint/overlapping sequences on both backings commit identical latest-local values with zero sparse projection builds before explicit promotion. | Public operations, both real backings, and stable projection observation are admissible; one call or private merge-helper assertions are rejected. | Sparse rereads committed palette for the second call while materialized passes; disjoint values kill it. | `ADD` | `test/edit/palette_update_test.dart` and `test/edit/fixtures/palette_update_fixture.dart` | `palette-sequential-admission` |
| `grid-sequential-evidence` | `grid-update-sequential-backing-parity` | `TEST` | `test/edit/grid_update_test.dart` and `test/edit/fixtures/grid_update_fixture.dart`, covering sparse and explicitly materialized backings. | No partial method exists, so stale-base omission and backing parity are unverified. | Distinguishable disjoint/overlapping sequences on both backings commit identical latest-local grids with zero sparse projection builds before explicit promotion. | Public operations, both real backings, and stable projection observation are admissible; one call or private merge-helper assertions are rejected. | Sparse rebuilds from committed grid and loses the first field; the cross-field sequence kills it. | `ADD` | `test/edit/grid_update_test.dart` and `test/edit/fixtures/grid_update_fixture.dart` | `grid-sequential-admission` |
| `palette-no-op-evidence` | `palette-update-effects-and-no-op` | `TEST` | Existing net-no-op owner extended with every palette partial no-op form on untouched sparse and deliberately materialized backings. | Partial no-op forms cannot be expressed before `updatePalette` exists. | All-null, local-equal, and compensating-final-equal cases on both backings preserve facts, revisions, projection identity/build count, repaint, streams, and public state. | Complete observations and explicit backing selection are admissible; sparse-only coverage, field equality, invocation, or journal size are rejected. | Sparse is silent but materialized local-equal advances publication; the matching materialized witness kills it. | `EXTEND_COVERAGE` | `test/edit/fixtures/net_no_op_edit_commit_fixture.dart` | `palette-no-op-admission` |
| `grid-no-op-evidence` | `grid-update-effects-and-no-op` | `TEST` | Existing net-no-op owner extended with every grid partial no-op form on untouched sparse and deliberately materialized backings. | Partial no-op forms cannot be expressed before `updateGrid` exists. | All-null, local-equal, and compensating-final-equal cases on both backings preserve every committed/effect/publication domain. | Complete observations and explicit backing selection are admissible; sparse-only coverage, final grid equality, or lack of repaint alone are rejected. | Sparse is silent but materialized compensation advances grid revision or repaint; the matching materialized witness kills it. | `EXTEND_COVERAGE` | `test/edit/fixtures/net_no_op_edit_commit_fixture.dart` | `grid-no-op-admission` |
| `partial-update-atomicity-evidence` | `partial-update-transaction-atomicity` | `TEST` | `test/edit/appearance_partial_updates_integration_test.dart` with `test/edit/fixtures/appearance_partial_updates_integration_fixture.dart`. | Neither partial method exists, so caught rejection and escaping mixed-family rollback are absent. | Caught invalid grid leaves earlier valid partial work committable; escaping validation/callback failures preserve all committed/effect/publication state and occur before install. | Real public callback and full effect observations are admissible; thrown error, final fields alone, owner-specific rollback proxies, or post-install rollback are rejected. | Final document is old but a transient state notification leaked; full observation kills it. | `ADD` | `test/edit/appearance_partial_updates_integration_test.dart` and `test/edit/fixtures/appearance_partial_updates_integration_fixture.dart` | `partial-update-atomicity-admission` |
| `partial-update-preinstall-failure-evidence` | `partial-update-preinstall-failure-boundary` | `TEST` | Existing stable failure-injection owner through `dart test test/edit/selection_effect_commit_test.dart`, extending `test/edit/fixtures/selection_effect_commit_fixture.dart`. | Existing preparation failure cases do not precede the injected failure with both new partial-update families. | Valid palette/grid partial work reaches preparation, the admitted failure escapes, and installer count, public delivery, and every committed/effect domain remain zero/unchanged. | Existing preparation/install injection and direct counters are admissible; callback throws, final fields alone, a new hook, or post-install compensation are rejected. | Installation occurs and is then compensated before final assertion; nonzero installer count kills it. | `EXTEND_COVERAGE` | `test/edit/fixtures/selection_effect_commit_fixture.dart` | `partial-update-preinstall-failure-admission` |
| `partial-cleanup-work-evidence` | `partial-update-cleanup-work-bound` | `SOURCE_QUERY` | Bounded inspection of callback validation exits, sparse/materialized backing disposal, Store preparation/finalization failure exits, installer bypass, and delivery bypass after Units 5-6. | Existing cleanup has one callback-local lifecycle; partial routes are absent. | Every caught/escaping/preparation failure returns through the same single cleanup/rollback lifecycle with no projection, unrelated collection traversal, repeated replay, compensating install, or displaced phase work. | Exact failure-exit owners and final diff are admissible; atomic final state, exception tests, timing, token absence, or Gate-only inspection are rejected. | All atomicity tests pass but escaping grid validation performs a pure layer traversal or invokes a second rollback pass; bounded control/data-flow inspection kills it. | `NONE` | None | None |
| `palette-effect-evidence` | `palette-update-effects-and-no-op` | `TEST` | Existing effect matrix owner through `dart test test/edit/edit_matrix_effects_test.dart`. | The partial route is absent and cannot be compared with `setPalette`. | Equivalent final values have identical accepted document/projection revisions, invalidation, no repaint, no event/action, and public-state publication. | Real commit delivery domains are admissible; final appearance, helper branches, or general green suites are rejected. | Both routes commit the right palette but partial update requests main repaint; repaint observation kills it. | `EXTEND_COVERAGE` | `test/edit/fixtures/edit_matrix_effects_fixture.dart` | `palette-effect-admission` |
| `grid-effect-evidence` | `grid-update-effects-and-no-op` | `TEST` | Existing effect matrix owner through `dart test test/edit/edit_matrix_effects_test.dart`. | The partial route is absent and cannot be compared with `setGrid`. | Equivalent final values have identical document/grid/projection revisions, invalidation, main repaint, no event/action, and public-state publication. | Real commit delivery domains are admissible; final grid, helper branches, or general green suites are rejected. | Both routes commit the right grid but partial update misses grid revision; revision observation kills it. | `EXTEND_COVERAGE` | `test/edit/fixtures/edit_matrix_effects_fixture.dart` | `grid-effect-admission` |
| `operation-matrix-guardrail-retirement-evidence` | `operation-matrix-guardrail-retirement` | `SOURCE_QUERY` | Bounded final inspection of the effect fixture/wrapper, semantic matrix guardrail list, guardrail contract/pattern/registry/executor, section registry, release gates, and generated guardrail index. | Copied/parsing parity exists and `edit.operation_matrix_complete` is documented, registered, dispatched, section-bound, and release-required. | The copied mechanism and every authoritative/consumer reference to that ID are gone; the generated index no longer lists it. | Exact named owner comparison is admissible; grep alone, another inventory/parser, deleting only the test, or runner success as source-ownership proxy are rejected. | Parser code is gone but the ID remains registered or release-required; owner comparison kills it. | `REDUCE_OR_REMOVE` | `test/edit/fixtures/edit_matrix_effects_fixture.dart`, `test/edit/edit_matrix_effects_test.dart`, `docs/contracts/operation_matrix.md`, `docs/verification/guardrails.md`, `docs/verification/guardrail_design_patterns.md`, `docs/verification/release_gates.md`, `docs/_registry/sections.yaml`, `tool/guardrails/src/guardrail_registry.dart`, `tool/guardrails/src/guardrail_executor.dart`, and generated `docs/indexes/by_guardrail.md` | None |
| `remaining-guardrail-route-evidence` | `remaining-guardrail-route-preserved` | `TEST` | Existing guardrail closure owners through `dart test test/guardrails/blocking_suite_test.dart test/guardrails/root_ci_target_test.dart` after documentation regeneration. | The current registry/executor/release/index route is closed before retirement. | After removing only the invalid ID, every remaining registry entry is dispatched, root-CI ownership remains valid, and generated docs are current. | Existing structural/runtime guardrail tests are admissible; ID absence, source inspection, or docs checks alone are rejected. | A remaining ID loses its executor route while retired-ID inspection passes; blocking-suite closure kills it. | `NONE` | None | None |
| `effect-proof-sensitivity-evidence` | `effect-proof-sensitivity-preserved` | `TEST` | Existing direct effect suite through `dart test test/edit/edit_matrix_effects_test.dart`, executed before and after Unit 1. | Current direct cases detect installation, typed effects, rollback, and no-action behavior. | The same retained cases and assertions pass after mirror retirement without removal or weakening. | Direct runtime assertions and before/after diff are admissible; source inspection, row counts, labels, or new partial cases are rejected. | Mirror code is removed together with rollback assertions and remaining happy paths pass; retained assertion/case comparison kills it. | `NONE` | None | None |
| `appearance-public-signature-evidence` | `appearance-exact-public-surface` | `BUILD_OR_COMPILE` | Existing external compile/integration owner through the public API compile test and root-barrel fixture, plus direct appearance owner comparison. | Appearance type/read source cannot compile before Unit 2. | At Unit 2 closure, exact new and retained read signatures compile and Dart, facade, semantic docs, and one-name registry delta agree. | Analyzer-resolved root consumer and bounded appearance-owner comparison are admissible; waiting for palette/grid, implementation imports, registry alone, or deleting retained calls are rejected. | Appearance compiles but `readDocument` is deprecated or docs differ; retained consumer/owner comparison kills it. | `EXTEND_COVERAGE` | `test/api_contract/public_api_v1_compiles_as_written_test.dart` and `test/api_contract/fixtures/public_integration_compile_fixture.dart` | `appearance-public-signature-admission` |
| `palette-public-signature-evidence` | `palette-update-exact-public-surface` | `BUILD_OR_COMPILE` | The same existing external compile/integration owner, extended only with Unit 3 palette declarations and direct consumers. | Palette DTO/method source cannot compile before Unit 3. | At Unit 3 closure, exact palette and retained signatures compile, every then-current direct consumer migrates, and Dart/docs/one-name registry delta agree without grid. | Root consumer and bounded palette-owner comparison are admissible; final grid witness, registry alone, or deleting retained calls are rejected. | Palette compiles but a maintained Unit 3 implementer or semantic contract is stale; direct compilation/comparison kills it. | `EXTEND_COVERAGE` | `test/api_contract/public_api_v1_compiles_as_written_test.dart` and `test/api_contract/fixtures/public_integration_compile_fixture.dart` | `palette-public-signature-admission` |
| `grid-public-signature-evidence` | `grid-update-exact-public-surface` | `BUILD_OR_COMPILE` | The same existing external compile/integration owner, extended with Unit 4 grid declarations and migration of all shared-interface consumers. | Grid DTO/method source cannot compile before Unit 4. | At Unit 4 closure, exact grid and retained signatures compile, every maintained consumer implements both methods, and Dart/docs/final registry agree. | Root consumer and bounded grid/shared-interface comparison are admissible; registry alone, omission-negative failure, or deleting retained calls are rejected. | Grid compiles in one fixture but a Unit 3 consumer remains stale; whole maintained consumer compilation kills it. | `EXTEND_COVERAGE` | `test/api_contract/public_api_v1_compiles_as_written_test.dart` and `test/api_contract/fixtures/public_integration_compile_fixture.dart` | `grid-public-signature-admission` |
| `appearance-public-equality-evidence` | `appearance-exact-public-surface` | `TEST` | Existing equality policy owner through `dart test test/api_contract/public_equality_policy_test.dart`, extended only with `CanvasAppearance`. | Appearance instances cannot be constructed before Unit 2. | At Unit 2 closure, separate identical appearance instances are unequal, self-comparison succeeds, and hash membership follows identity. | Public constructor/operators are admissible; future DTOs, absence of overrides, or private inspection are rejected. | Appearance gains structural equality; separate-instance comparison kills it. | `EXTEND_COVERAGE` | `test/api_contract/public_equality_policy_test.dart` | `appearance-public-equality-admission` |
| `palette-public-equality-evidence` | `palette-update-exact-public-surface` | `TEST` | Existing equality policy owner extended only with `CanvasPaletteUpdate`. | Palette update instances cannot be constructed before Unit 3. | At Unit 3 closure, separate identical update instances are unequal and hash membership follows identity. | Public constructor/operators are admissible; future grid DTO, absence of overrides, or existing appearance result are rejected. | Palette DTO gains structural equality; separate-instance comparison kills it. | `EXTEND_COVERAGE` | `test/api_contract/public_equality_policy_test.dart` | `palette-public-equality-admission` |
| `grid-public-equality-evidence` | `grid-update-exact-public-surface` | `TEST` | Existing equality policy owner extended only with `CanvasGridUpdate`. | Grid update instances cannot be constructed before Unit 4. | At Unit 4 closure, separate identical update instances are unequal and hash membership follows identity. | Public constructor/operators are admissible; prior two types, absence of overrides, or private inspection are rejected. | Grid DTO gains structural equality; separate-instance comparison kills it. | `EXTEND_COVERAGE` | `test/api_contract/public_equality_policy_test.dart` | `grid-public-equality-admission` |
| `palette-implementer-negative-evidence` | `final-interface-one-method-omissions` | `BUILD_OR_COMPILE` | Unit 4 adds one isolated source variant to the existing public API compile test, implementing grid and omitting only palette. | Before both methods exist, final one-method omission cannot be expressed. | Against the final interface, the source implements grid, omits only palette, and is rejected with the missing-implementation diagnostic. | Existing analyzer runner is admissible; copied interfaces, omission of both methods, or preparatory earlier artifacts are rejected. | It omits both methods and stays red for the wrong reason; exact source/diagnostic kills it. | `EXTEND_COVERAGE` | `test/api_contract/public_api_v1_compiles_as_written_test.dart` | `palette-implementer-negative-admission` |
| `grid-implementer-negative-evidence` | `final-interface-one-method-omissions` | `BUILD_OR_COMPILE` | Unit 4 adds one isolated source variant to the existing public API compile test, implementing palette and omitting only grid. | Before both methods exist, final one-method omission cannot be expressed. | Against the final interface, the source implements palette, omits only grid, and is rejected with the missing-implementation diagnostic. | Existing analyzer runner is admissible; copied interfaces, omission of both methods, or unrelated consumers are rejected. | It also omits palette and stays red after a grid fallback; exact source/diagnostic kills it. | `EXTEND_COVERAGE` | `test/api_contract/public_api_v1_compiles_as_written_test.dart` | `grid-implementer-negative-admission` |
| `forbidden-appearance-negative-evidence` | `appearance-forbidden-surface` | `BUILD_OR_COMPILE` | Unit 2 adds six isolated source variants to `test/api_contract/public_api_v1_compiles_as_written_test.dart`, one per forbidden member. | The type is absent, so exclusion cannot yet be proven against the accepted type. | Each exact member expression fails independently against the root-exported type with the unresolved-member diagnostic. | Existing analyzer runner and one expression per variant are admissible; registry absence, grep, combined failures, or custom scanners are rejected. | `camera` exists while another combined failure stays red; isolated camera source compiles and kills it. | `EXTEND_COVERAGE` | `test/api_contract/public_api_v1_compiles_as_written_test.dart` | `forbidden-appearance-negative-admission` |
| `forbidden-background-update-evidence` | `grid-update-exact-public-surface` | `BUILD_OR_COMPILE` | Unit 4 adds one isolated source variant to `test/api_contract/public_api_v1_compiles_as_written_test.dart`, invoking `CanvasEdit.updateBackground`. | The forbidden neighbor is absent but accepted partial methods do not yet exist. | The exact call remains unresolved against the completed real interface. | Existing analyzer runner is admissible; inventory, positive compile, grep, or another missing member are rejected. | An extension exports `updateBackground`; the exact source compiles and kills it. | `EXTEND_COVERAGE` | `test/api_contract/public_api_v1_compiles_as_written_test.dart` | `forbidden-background-update-admission` |
| `appearance-durable-owner-evidence` | `appearance-durable-owner-alignment` | `MANUAL_INSPECTION` | Unit 2 production owners compared with runtime ownership, data model, public API contract, and lifecycle diagram. | These owners describe only full reads. | At Unit 2 closure, all agree on Store coherence, projection avoidance, lifecycle, and appearance shape without mentioning future partial methods. | Direct Unit 2 owner comparison is admissible; later-unit docs, tests alone, or wording tokens are rejected. | Read behavior passes but lifecycle docs reject post-dispose appearance; comparison kills it. | `UPDATE_EXISTING` | `docs/architecture/01_runtime_ownership.md`, `docs/architecture/03_data_model.md`, `docs/contracts/public_api_v1.md`, and `docs/diagrams/state_runtime_lifecycle.mmd` | None |
| `palette-durable-owner-evidence` | `palette-update-single-store-path` | `MANUAL_INSPECTION` | Unit 3 production owners compared with data model, edit kernel, operation matrix, and public API contract. | These owners describe only whole palette setters. | At Unit 3 closure, all agree on palette merge/order/validation/effects and the existing mutation/publication path without requiring grid. | Direct palette-owner comparison is admissible; later grid docs, tests alone, or wording tokens are rejected. | Palette behavior passes but operation matrix assigns repaint; comparison kills it. | `UPDATE_EXISTING` | `docs/architecture/03_data_model.md`, `docs/contracts/edit_kernel.md`, `docs/contracts/operation_matrix.md`, and `docs/contracts/public_api_v1.md` | None |
| `grid-durable-owner-evidence` | `grid-update-single-store-path` | `MANUAL_INSPECTION` | Unit 4 production owners compared with data model, edit kernel, operation matrix, and public API contract. | These owners describe only whole grid setters. | At Unit 4 closure, all agree on grid merge/order/validation/effects and the existing mutation/publication path. | Direct grid-owner comparison is admissible; palette evidence, tests alone, or wording tokens are rejected. | Grid behavior passes but semantic owner assigns wrong repaint/revision; comparison kills it. | `UPDATE_EXISTING` | `docs/architecture/03_data_model.md`, `docs/contracts/edit_kernel.md`, `docs/contracts/operation_matrix.md`, and `docs/contracts/public_api_v1.md` | None |
| `architecture-closure-evidence` | `appearance-existing-owner-boundary` | `STATIC_ANALYSIS` | Existing architecture graph commands in Verification Gate plus bounded changed-import inspection. | Existing graph closes before the feature exists. | Expected-versus-actual closure and generated views remain unchanged while changed imports preserve the contracts-led facade/root/Store/edit direction. | Existing graph authority and changed edges are admissible; general analyzer success or unchanged Mermaid files alone are rejected. | A runtime-to-API back edge is introduced without a new node; graph closure or direct changed-edge inspection kills it. | `NONE` | None | None |
| `appearance-singularity-evidence` | `appearance-existing-owner-boundary` | `SOURCE_QUERY` | Bounded changed-owner audit of committed/runtime state fields, read route, cache/service ownership, transaction-local backings, and direct consumers. | Store owns one committed aggregate; no appearance-specific state exists. | The implementation adds only an ephemeral returned value and delegates to Store; no stored appearance, cache, service, intent marker, or synchronization path appears. | Stable owner fields/routes and changed diff are admissible; functional equality, token absence alone, or copied state inventories are rejected. | Tests pass while RuntimeRoot caches the last appearance with its own invalidation; owner-field audit kills it. | `NONE` | None | None |
| `retained-document-read-evidence` | `retained-document-read-behavior` | `TEST` | Existing `readDocument`, projection, lifecycle, and API compile owners executed at Unit 2 closure. | Current behavior is already directly observed. | Full read declaration, projection, cache, lifecycle, and immutable result behavior remain unchanged after Unit 2. | Nearest existing behavior is admissible; partial tests or declaration presence alone are rejected. | Appearance passes but `readDocument` caching changes; existing projection owner kills it. | `NONE` | None | None |
| `retained-draft-document-read-evidence` | `retained-draft-document-read-behavior` | `TEST` | Existing draft-result/promotion and lifecycle owners through `dart test test/edit/sparse_edit_session_test.dart test/edit/sync_non_nested_async_stale_test.dart test/edit/rollback_test.dart`, plus public compilation. | Current draft read result, explicit materialization, callback visibility, rollback use, and stale rejection are directly observed. | After Unit 3, the read returns the same current draft shape, remains the explicit sparse-to-materialized trigger, is synchronous inside active callbacks, and rejects every stale closure path. | Nearest draft behavior owners are admissible; using the read only to set up another test, declaration presence, or partial-update parity is rejected. | Partial updates pass but `readDraftDocument` no longer exposes a prior mutation or remains usable after closure; direct result/lifecycle cases kill it. | `NONE` | None | None |
| `retained-background-setter-evidence` | `retained-background-color-setter-behavior` | `TEST` | Existing setter owners through the edit effect, net-no-op, rollback, sparse-edit-session, stale-handle, and public compile suites. | Current setter validation/sibling preservation, both backings, effects, no-op, rollback, stale lifecycle, and signature are directly observed. | After Unit 4, `setBackgroundColor` remains non-deprecated and preserves grid siblings with unchanged validation, transaction, effects, no-op, rollback, and stale behavior. | Direct existing whole-setter cases are admissible; grid partial behavior, final color alone, declaration presence, or one backing is rejected. | Grid work passes but the setter resets grid or changes repaint/revision on materialized backing; existing sibling/effect cases kill it. | `NONE` | None | None |
| `retained-palette-setter-evidence` | `retained-whole-palette-behavior` | `TEST` | Existing whole-palette validation, transaction, effect, no-op, rollback, and API compile owners executed at Unit 3 closure. | Current `setPalette` behavior is directly observed. | Whole setter remains available, non-deprecated, and behaviorally unchanged after Unit 3. | Nearest whole-setter owners are admissible; new partial cases are rejected as proxy. | `setPalette` routes through absence semantics; existing validation case kills it. | `NONE` | None | None |
| `retained-grid-setter-evidence` | `retained-whole-grid-behavior` | `TEST` | Existing whole-grid validation, transaction, effect, no-op, rollback, and API compile owners executed at Unit 4 closure. | Current `setGrid` behavior is directly observed. | Whole setter remains available, non-deprecated, and behaviorally unchanged after Unit 4. | Nearest whole-setter owners are admissible; new partial cases are rejected as proxy. | `setGrid` changes validation; existing boundary case kills it. | `NONE` | None | None |
| `appearance-engine-boundary-evidence` | `appearance-engine-only-boundary` | `MANUAL_INSPECTION` | Unit 2 declarations, semantic owners, changed dependencies, and graph closure. | Current read path contains only engine owners. | Unit 2 adds no application type, adapter, state, dependency, or graph owner. | Concrete Unit 2 edges are admissible; later units or word searches are rejected. | Runtime delegates to an application adapter; edge inspection kills it. | `NONE` | None | None |
| `palette-engine-boundary-evidence` | `palette-engine-only-boundary` | `MANUAL_INSPECTION` | Unit 3 declarations, semantic owners, and changed edit/Store dependencies. | Current palette mutation path is engine-only. | Unit 3 adds no application concept, adapter, migration, state, or dependency. | Concrete palette edges are admissible; appearance/grid success is rejected as proxy. | Palette DTO imports an application preset; edge inspection kills it. | `NONE` | None | None |
| `grid-engine-boundary-evidence` | `grid-engine-only-boundary` | `MANUAL_INSPECTION` | Unit 4 declarations, semantic owners, and changed edit/Store dependencies. | Current grid mutation path is engine-only. | Unit 4 adds no application concept, adapter, migration, state, or dependency. | Concrete grid edges are admissible; palette success is rejected as proxy. | Grid route calls an application profile adapter; edge inspection kills it. | `NONE` | None | None |
| `palette-rollback-evidence` | `palette-update-rollback-boundary` | `TEST` | Existing `test/edit/rollback_test.dart` and `test/edit/fixtures/rollback_fixture.dart`, extended with a direct palette partial witness. | Palette partial rollback cannot be expressed before the method exists. | An escaping callback after a valid palette update preserves all committed/effect/publication domains. | Direct palette entry and complete observations are admissible; mixed-family evidence, final palette alone, or exception-only assertions are rejected. | Palette rolls back but a transient notification leaks; publication observation kills it. | `EXTEND_COVERAGE` | `test/edit/fixtures/rollback_fixture.dart` | `palette-rollback-admission` |
| `grid-rollback-evidence` | `grid-update-rollback-boundary` | `TEST` | Existing `test/edit/rollback_test.dart` and `test/edit/fixtures/rollback_fixture.dart`, extended with a direct grid partial witness. | Grid partial rollback cannot be expressed before the method exists. | An escaping validation/callback failure after a valid grid update preserves all committed/effect/publication domains. | Direct grid entry and complete observations are admissible; mixed-family evidence, final grid alone, or exception-only assertions are rejected. | Grid rolls back but projection invalidation leaks; full observation kills it. | `EXTEND_COVERAGE` | `test/edit/fixtures/rollback_fixture.dart` | `grid-rollback-admission` |
| `palette-stale-evidence` | `palette-update-stale-boundary` | `TEST` | Existing exhaustive stale fixture through `dart test test/edit/sync_non_nested_async_stale_test.dart`. | The new entry is absent from the exhaustive handle surface. | Handles from success, escaping failure, and rejected async callback all throw `StateError` on `updatePalette` with every state/effect domain unchanged; bounded entry inspection confirms guard-before-backing. | Direct public calls are admissible; exception type only, one closure path, source grep, or private guard names are rejected. | The method begins backing access before stale rejection but still throws; guard-order observation kills it. | `UPDATE_EXISTING` | `test/edit/fixtures/sync_non_nested_async_stale_fixture.dart` | None |
| `grid-stale-evidence` | `grid-update-stale-boundary` | `TEST` | Existing exhaustive stale fixture through `dart test test/edit/sync_non_nested_async_stale_test.dart`. | The new entry is absent from the exhaustive handle surface. | Handles from all closure paths throw `StateError` before merge validation with every state/effect domain unchanged. | A constructor-valid grid value invalid only after merge is admissible; exception-only, valid happy path, one closure path, or private guard name are rejected. | Merged validation runs first and throws `CanvasDataException`; the context-dependent stale witness kills it. | `UPDATE_EXISTING` | `test/edit/fixtures/sync_non_nested_async_stale_fixture.dart` | None |
| `palette-single-candidate-evidence` | `palette-update-single-store-path` | `TEST` | Existing Store candidate owner plus palette sparse/materialized behavior through `test/store/store_transaction_candidate_test.dart` and the palette update suite. | Palette partial admission/replay/publication is absent. | At Unit 3 closure, each changed palette call emits one complete mutation, promotes/replays once, derives owner facts, and publishes zero or one aggregate with no extra phase pass. | Stable candidate/journal/replay/publication observations are admissible; grid calls, final equality alone, helper names, DCM, or timing are rejected. | Palette final state is right but a partial plus complete mutation is appended; event cardinality kills it. | `EXTEND_COVERAGE` | `test/store/fixtures/store_transaction_candidate_fixture.dart` and `test/edit/fixtures/palette_update_fixture.dart` | `palette-single-candidate-admission` |
| `grid-single-candidate-evidence` | `grid-update-single-store-path` | `TEST` | Existing Store candidate owner plus grid sparse/materialized behavior through `test/store/store_transaction_candidate_test.dart` and the grid update suite. | Grid partial admission/replay/publication is absent. | At Unit 4 closure, each changed grid call emits one complete mutation, promotes/replays once, derives owner facts, and publishes zero or one aggregate with no extra phase pass. | Stable candidate/journal/replay/publication observations are admissible; palette calls, final equality alone, helper names, DCM, or timing are rejected. | Grid final state is right but an intermediate aggregate publishes; event cardinality kills it. | `EXTEND_COVERAGE` | `test/store/fixtures/store_transaction_candidate_fixture.dart` and `test/edit/fixtures/grid_update_fixture.dart` | `grid-single-candidate-admission` |
| `grid-work-budget-evidence` | `grid-update-work-bound` | `SOURCE_QUERY` | Bounded inspection of grid DTO construction, sparse/materialized merge, complete background mutation creation, journal replay, Store finalization/install, and publication owners. | Grid partial construction/application paths are absent. | Constructor and merge are scalar O(1); each changed call admits one existing complete background mutation; replay/install/publication add no partial-specific pass or unrelated layer/element/resource/metadata traversal. | Exact changed owners and phase boundaries are admissible; journal/publication cardinality alone, timing, DCM, helper names, or Gate-only inspection are rejected. | Counts are correct but each grid call scans layers before building the same mutation; direct changed-control/data-flow inspection kills it. | `NONE` | None | None |
| `nullable-update-field-stop-evidence` | `nullable-update-field-stop` | `MANUAL_INSPECTION` | Current requirements and complete palette/grid update field contracts checked separately before Units 3 and 4. | H-002 is recorded but no nullable stored value currently requires tri-state intent. | Every updateable value remains non-null and null is only absence; otherwise the affected unit stops for an approved tri-state/compatibility decision. | Complete field/value comparison is admissible; happy-path tests, one DTO, or Out of Scope prose are rejected. | Palette fields stay non-null but one grid value becomes legitimately nullable and overloads absence; complete Unit 4 contract review kills it. | `NONE` | None | None |
| `structural-snapshot-expansion-stop-evidence` | `structural-snapshot-expansion-stop` | `MANUAL_INSPECTION` | Current request and complete `CanvasAppearance` field contract checked before Unit 2. | H-003 is recorded and current scope is exactly background color, grid, and palette. | Metadata, layers, elements, and resources remain excluded; otherwise Unit 2 stops for a new coherence/projection/work decision. | Full accepted snapshot contract is admissible; forbidden-name spot checks or behavior success are rejected. | Metadata is added under a differently named aggregate field while listed forbidden members stay absent; full field/type review kills it. | `NONE` | None | None |
| `direct-implementer-compatibility-stop-evidence` | `direct-implementer-compatibility-stop` | `MANUAL_INSPECTION` | Current release compatibility requirement and direct-interface migration form checked before Units 3 and 4. | H-004 is recorded and current design accepts a source break with complete migration. | No requirement asks old implementers to compile unchanged; otherwise the affected unit stops for approved versioning/compatibility authority. | Direct product/release requirement comparison is admissible; fallback compilation, a default method, or one migrated consumer is rejected. | A new release requirement demands legacy compilation and implementation adds a default method; exact requirement comparison kills it before mutation. | `NONE` | None | None |
| `draft-visible-appearance-stop-evidence` | `draft-visible-appearance-stop` | `MANUAL_INSPECTION` | Required temporal read semantics checked against H-005 before Unit 2. | Current read is last-installed committed state during callbacks. | No requirement exposes sparse/materialized draft intermediates; otherwise Unit 2 stops for a draft-read owner/lifecycle decision. | Exact temporal requirement and design comparison is admissible; before/after tests or an existing draft read are rejected. | A new requirement asks `readAppearance` to preview a callback-local grid; direct temporal comparison kills it before committed-read implementation. | `NONE` | None | None |
| `application-state-snapshot-stop-evidence` | `application-state-snapshot-stop` | `MANUAL_INSPECTION` | Required snapshot domains and dependencies checked against H-006 before Unit 2. | Current scope contains engine persisted appearance only. | No application-domain type/state/dependency is requested; otherwise Unit 2 stops for cross-boundary owner/coherence authority. | Concrete requested fields/types/dependencies are admissible; generic naming, engine tests, or package compilation are rejected. | An application profile is hidden behind a generic options type; dependency/type owner review kills it. | `NONE` | None | None |
| `runtime-local-snapshot-stop-evidence` | `runtime-local-snapshot-stop` | `MANUAL_INSPECTION` | Required snapshot fields checked against camera/selection ownership and H-007 before Unit 2. | Current scope excludes runtime-local camera and selection. | Neither domain enters the snapshot; otherwise Unit 2 stops for cross-owner coherence/lifecycle/proof authority. | Complete snapshot-to-owner comparison is admissible; only checking public names or persisted fields is rejected. | Selection is included under a generic interaction field while `selection` remains absent; owner/type comparison kills it. | `NONE` | None | None |

## Permanent Artifact Admissions

### `lightweight-public-workflow-admission`: External lightweight appearance workflow

Covers: `lightweight-appearance-partial-update-workflow`
Impact: `ADD`
Failure family: public declarations can exist without a real root-barrel runtime workflow that avoids consumer full-document reads
Failure mode or stable invariant: an external consumer reads appearance, applies both partial-update families, and observes the committed result without calling full committed/draft reads
Verification owner: external-consumer behavior under `test/api_contract/**`
Current verification gap: current external fixtures compile full-document and whole-setter use only and do not execute the requested workflow
Failing witness: the current root barrel has no appearance read or partial update declarations, so the workflow cannot compile
Durable and refactor-stable value: root-barrel usability and appearance-only consumer behavior survive internal Store, facade, and edit refactors
Artifact target: `test/api_contract/appearance_partial_updates_public_behavior_test.dart`

### `appearance-coherence-admission`: Coherent committed appearance snapshot

Covers: `appearance-coherent-projection-free`
Impact: `ADD`
Failure family: one public appearance value can mix background, grid, and palette from different committed states
Failure mode or stable invariant: every appearance field comes from one coherent committed Store aggregate
Verification owner: Store committed-read behavior
Current verification gap: existing Store projection tests observe full documents and cannot call a lightweight appearance read
Failing witness: no `CanvasAppearance` or `readAppearance` exists before implementation
Durable and refactor-stable value: committed-state coherence survives private capture and delegation refactors
Artifact target: `test/store/appearance_read_test.dart` and `test/store/fixtures/appearance_read_fixture.dart`

### `appearance-projection-admission`: Projection-free appearance read

Covers: `appearance-coherent-projection-free`
Impact: `EXTEND_COVERAGE`
Failure family: the new appearance read can enter or warm full projection while existing sparse-edit hot-path cases remain green
Failure mode or stable invariant: repeated public appearance reads build zero projection and a later explicit full read remains the first build
Verification owner: existing Store no-projection hot-path suite
Current verification gap: no appearance read exists and current cases exercise different sparse-edit routes
Failing witness: before Unit 2, only full `readDocument` can expose committed appearance and it builds projection
Durable and refactor-stable value: direct read-path projection avoidance survives Store/root delegation and projection-cache refactors
Artifact target: `test/store/fixtures/no_projection_hot_path_fixture.dart`

### `appearance-lifecycle-admission`: Appearance read lifecycle and visibility

Covers: `appearance-lifecycle-visibility`
Impact: `EXTEND_COVERAGE`
Failure family: a non-mutating appearance read can expose draft/rolled-back values or diverge after install/dispose
Failure mode or stable invariant: reads observe only last installed committed state throughout callback, rollback, success, and disposal boundaries
Verification owner: existing runtime lifecycle/state and edit rollback suites
Current verification gap: those suites cover `readDocument` and general state but cannot invoke the absent appearance read
Failing witness: active-edit and post-dispose appearance behavior is absent before implementation
Durable and refactor-stable value: lifecycle visibility survives private Store/root delegation and edit-backing refactors
Artifact target: `test/store/appearance_read_test.dart`, `test/store/fixtures/appearance_read_fixture.dart`, and named existing lifecycle tests

### `appearance-collection-view-admission`: Public appearance collection immutability

Covers: `appearance-collection-views-immutable`
Impact: `ADD`
Failure family: one public appearance palette collection view can remain mutable while other views and value checks pass
Failure mode or stable invariant: mutation through every appearance collection view fails and cannot change a later public appearance read
Verification owner: Store committed appearance-read behavior
Current verification gap: no public appearance value or collection view exists
Failing witness: `readAppearance` and `CanvasAppearance` are absent
Durable and refactor-stable value: public committed-value immutability survives Store capture and collection implementation refactors
Artifact target: `test/store/appearance_read_test.dart` and `test/store/fixtures/appearance_read_fixture.dart`

### `palette-presence-admission`: Palette presence and empty replacement

Covers: `palette-update-presence-application`
Impact: `ADD`
Failure family: omission and supplied-empty palette intent can collapse to one meaning or update a sibling field
Failure mode or stable invariant: each present field replaces exactly itself, including with an empty list, while omission retains latest-local state
Verification owner: palette partial-update behavior
Current verification gap: whole-palette setters cannot express per-field omission or empty replacement
Failing witness: `CanvasPaletteUpdate` and `updatePalette` are absent
Durable and refactor-stable value: public presence/application semantics survive private DTO and edit-backing refactors
Artifact target: `test/edit/palette_update_test.dart` and `test/edit/fixtures/palette_update_fixture.dart`

### `palette-constructor-validation-admission`: Palette construction validation

Covers: `palette-update-context-free-construction`
Impact: `ADD`
Failure family: invalid supplied palette data can survive DTO construction and fail only after edit access
Failure mode or stable invariant: construction validates supplied lists through existing palette boundaries before any callback action
Verification owner: dedicated palette-update public constructor API-contract suite using the shared consumer harness
Current verification gap: no focused owner exists because the partial DTO is absent
Failing witness: `CanvasPaletteUpdate` does not exist
Durable and refactor-stable value: immediate public boundary rejection survives private merge and backing refactors
Artifact target: `test/api_contract/palette_update_public_constructor_test.dart`

### `palette-alias-admission`: Palette caller-alias isolation

Covers: `palette-update-alias-isolation`
Impact: `EXTEND_COVERAGE`
Failure family: an update view can reject direct mutation yet reflect later source mutation and change the publicly read installed appearance
Failure mode or stable invariant: constructor-time list snapshots alone determine the DTO and later `readAppearance` values
Verification owner: public DTO immutability plus palette behavior
Current verification gap: existing DTO checks cannot construct or apply the new update type
Failing witness: no palette update DTO exists for source/getter alias probes
Durable and refactor-stable value: input-to-public-output alias isolation survives collection, read, and edit-backing refactors
Artifact target: `test/api_contract/dto_immutability_test.dart` and `test/edit/fixtures/palette_update_fixture.dart`

### `grid-validation-admission`: Context-dependent partial grid validation

Covers: `grid-update-presence-and-validation`
Impact: `ADD`
Failure family: individually valid update fields can form an invalid complete grid after merging with transaction-local state
Failure mode or stable invariant: each call merges first, validates through the established complete-value boundary, and mutates none of that call on rejection
Verification owner: grid partial-update behavior
Current verification gap: existing whole-grid tests have no absent-field merge and cannot distinguish constructor-valid from merge-invalid input
Failing witness: `CanvasGridUpdate` and `CanvasEdit.updateGrid` do not exist
Durable and refactor-stable value: public merge/validation/no-mutation semantics survive private helper and backing refactors
Artifact target: `test/edit/grid_update_test.dart` and `test/edit/fixtures/grid_update_fixture.dart`

### `grid-constructor-validation-admission`: Context-free grid update construction validation

Covers: `grid-update-context-free-construction`
Impact: `ADD`
Failure family: an unconditionally invalid supplied grid scalar can survive DTO construction and be rejected only after edit/backing access
Failure mode or stable invariant: every applicable context-free grid field rule is enforced by `CanvasGridUpdate` construction before any edit action
Verification owner: dedicated grid-update public constructor API-contract suite using the shared consumer harness
Current verification gap: no focused owner exists because the partial DTO is absent
Failing witness: `CanvasGridUpdate` does not exist, so its constructor cannot reject any supplied scalar
Durable and refactor-stable value: immediate public boundary validation survives private edit, merge, and backing refactors
Artifact target: `test/api_contract/grid_update_public_constructor_test.dart`

### `palette-sequential-admission`: Palette latest-local sparse/materialized parity

Covers: `palette-update-sequential-backing-parity`
Impact: `ADD`
Failure family: omitted palette fields can merge from stale committed state or diverge between sparse and materialized backings
Failure mode or stable invariant: repeated partial palette calls compose in callback order from latest local state on both backings without implicit projection
Verification owner: palette partial-update behavior
Current verification gap: whole-palette setters cannot prove absent-field preservation across repeated partial calls
Failing witness: the partial palette method is absent
Durable and refactor-stable value: transaction-local order and backing parity survive private merge and journal refactors
Artifact target: `test/edit/palette_update_test.dart` and `test/edit/fixtures/palette_update_fixture.dart`

### `grid-sequential-admission`: Grid latest-local sparse/materialized parity

Covers: `grid-update-sequential-backing-parity`
Impact: `ADD`
Failure family: omitted grid fields can merge from stale committed state or diverge between sparse and materialized backings
Failure mode or stable invariant: repeated partial grid calls compose in callback order from latest local state on both backings without implicit projection
Verification owner: grid partial-update behavior
Current verification gap: whole-grid setters cannot prove absent-field preservation across repeated partial calls
Failing witness: the partial grid method is absent
Durable and refactor-stable value: transaction-local order and backing parity survive private merge and journal refactors
Artifact target: `test/edit/grid_update_test.dart` and `test/edit/fixtures/grid_update_fixture.dart`

### `palette-no-op-admission`: Palette partial no-op silence

Covers: `palette-update-effects-and-no-op`
Impact: `EXTEND_COVERAGE`
Failure family: partial palette sequences can leave final facts equal while advancing an effect or publication domain
Failure mode or stable invariant: all-null, local-equal, and compensating-final-equal palette updates deliver no state or effect
Verification owner: existing net-no-op edit commit suite
Current verification gap: existing cases cannot invoke the new partial method
Failing witness: partial palette no-op forms are unrepresentable before implementation
Durable and refactor-stable value: final-fact-owned no-op silence survives journal and setter refactors
Artifact target: `test/edit/fixtures/net_no_op_edit_commit_fixture.dart`

### `grid-no-op-admission`: Grid partial no-op silence

Covers: `grid-update-effects-and-no-op`
Impact: `EXTEND_COVERAGE`
Failure family: partial grid sequences can leave final facts equal while advancing an effect or publication domain
Failure mode or stable invariant: all-null, local-equal, and compensating-final-equal grid updates deliver no state or effect
Verification owner: existing net-no-op edit commit suite
Current verification gap: existing cases cannot invoke the new partial method
Failing witness: partial grid no-op forms are unrepresentable before implementation
Durable and refactor-stable value: final-fact-owned no-op silence survives journal and setter refactors
Artifact target: `test/edit/fixtures/net_no_op_edit_commit_fixture.dart`

### `partial-update-atomicity-admission`: Mixed palette/grid callback atomicity

Covers: `partial-update-transaction-atomicity`
Impact: `ADD`
Failure family: owner-specific behavior can pass while mixed partial updates leak or erase state across caught and escaping failures
Failure mode or stable invariant: caught rejection preserves earlier valid work and every escaping failure publishes neither family
Verification owner: cross-family edit integration behavior
Current verification gap: existing rollback checks and absent methods cannot exercise mixed partial-update transactions
Failing witness: neither partial method exists, so the scenario cannot compile
Durable and refactor-stable value: the shared public transaction boundary survives private palette/grid implementation refactors
Artifact target: `test/edit/appearance_partial_updates_integration_test.dart` and `test/edit/fixtures/appearance_partial_updates_integration_fixture.dart`

### `partial-update-preinstall-failure-admission`: Partial-update preparation failure boundary

Covers: `partial-update-preinstall-failure-boundary`
Impact: `EXTEND_COVERAGE`
Failure family: an admitted owner failure after partial work can reach an installer and be hidden by compensation
Failure mode or stable invariant: preparation failure after valid palette/grid updates reaches zero installers and zero public delivery
Verification owner: existing selection/commit preparation-install boundary suite
Current verification gap: existing injected failures do not carry both new partial-update families into preparation
Failing witness: the partial methods are absent and cannot precede the injected owner failure
Durable and refactor-stable value: the irreversible install boundary survives edit, Store, and delivery refactors
Artifact target: `test/edit/fixtures/selection_effect_commit_fixture.dart`

### `palette-effect-admission`: Palette partial-to-whole effect parity

Covers: `palette-update-effects-and-no-op`
Impact: `EXTEND_COVERAGE`
Failure family: partial palette updates can reach the correct value with different revision, projection, repaint, event, or publication effects
Failure mode or stable invariant: an accepted partial palette result has exactly the established `setPalette` effect domains
Verification owner: existing edit effect-matrix suite
Current verification gap: the suite covers only the whole-value palette entry
Failing witness: no partial palette route exists for comparison
Durable and refactor-stable value: accepted effect parity survives private edit, Store, and delivery refactors
Artifact target: `test/edit/fixtures/edit_matrix_effects_fixture.dart`

### `grid-effect-admission`: Grid partial-to-whole effect parity

Covers: `grid-update-effects-and-no-op`
Impact: `EXTEND_COVERAGE`
Failure family: partial grid updates can reach the correct value with different revision, projection, repaint, event, or publication effects
Failure mode or stable invariant: an accepted partial grid result has exactly the established `setGrid` effect domains
Verification owner: existing edit effect-matrix suite
Current verification gap: the suite covers only the whole-value grid entry
Failing witness: no partial grid route exists for comparison
Durable and refactor-stable value: accepted effect parity survives private edit, Store, and delivery refactors
Artifact target: `test/edit/fixtures/edit_matrix_effects_fixture.dart`

### `appearance-public-signature-admission`: Unit 2 appearance public surface

Covers: `appearance-exact-public-surface`
Impact: `EXTEND_COVERAGE`
Failure family: appearance signatures, root export, semantic contract, facade, or inventory can disagree independently of partial methods
Failure mode or stable invariant: exact new/retained read signatures compile and all Unit 2 authorities agree
Verification owner: existing external public API compile/integration suite
Current verification gap: current consumers contain no appearance type or read
Failing witness: exact appearance consumer source fails before Unit 2
Durable and refactor-stable value: Unit 2 root source shape survives internal read refactors
Artifact target: `test/api_contract/public_api_v1_compiles_as_written_test.dart` and `test/api_contract/fixtures/public_integration_compile_fixture.dart`

### `palette-public-signature-admission`: Unit 3 palette public surface

Covers: `palette-update-exact-public-surface`
Impact: `EXTEND_COVERAGE`
Failure family: palette signatures and then-current direct consumers can disagree while appearance remains green
Failure mode or stable invariant: exact palette/retained signatures compile and every Unit 3 consumer migrates without requiring grid
Verification owner: existing external public API compile/integration suite
Current verification gap: current consumers contain no palette update DTO/method
Failing witness: exact palette consumer source fails before Unit 3
Durable and refactor-stable value: Unit 3 root/interface shape survives internal palette refactors
Artifact target: `test/api_contract/public_api_v1_compiles_as_written_test.dart` and `test/api_contract/fixtures/public_integration_compile_fixture.dart`

### `grid-public-signature-admission`: Unit 4 grid public surface

Covers: `grid-update-exact-public-surface`
Impact: `EXTEND_COVERAGE`
Failure family: grid signatures or a previously migrated shared-interface consumer can remain stale
Failure mode or stable invariant: exact grid/retained signatures compile and every maintained consumer implements the final interface
Verification owner: existing external public API compile/integration suite
Current verification gap: current consumers contain no grid update DTO/method
Failing witness: exact grid consumer source fails before Unit 4
Durable and refactor-stable value: final root/interface shape survives internal grid refactors
Artifact target: `test/api_contract/public_api_v1_compiles_as_written_test.dart` and `test/api_contract/fixtures/public_integration_compile_fixture.dart`

### `appearance-public-equality-admission`: Appearance identity equality

Covers: `appearance-exact-public-surface`
Impact: `EXTEND_COVERAGE`
Failure family: only the appearance type can gain structural equality while later DTO checks remain irrelevant
Failure mode or stable invariant: identical separate appearances remain identity-unequal with consistent hash behavior
Verification owner: existing public equality policy suite
Current verification gap: appearance instances cannot be constructed
Failing witness: the type is absent before Unit 2
Durable and refactor-stable value: equality policy survives declaration implementation refactors
Artifact target: `test/api_contract/public_equality_policy_test.dart`

### `palette-public-equality-admission`: Palette update identity equality

Covers: `palette-update-exact-public-surface`
Impact: `EXTEND_COVERAGE`
Failure family: only the palette update type can gain structural equality
Failure mode or stable invariant: identical separate palette updates remain identity-unequal with consistent hash behavior
Verification owner: existing public equality policy suite
Current verification gap: palette update instances cannot be constructed
Failing witness: the type is absent before Unit 3
Durable and refactor-stable value: equality policy survives DTO implementation refactors
Artifact target: `test/api_contract/public_equality_policy_test.dart`

### `grid-public-equality-admission`: Grid update identity equality

Covers: `grid-update-exact-public-surface`
Impact: `EXTEND_COVERAGE`
Failure family: only the grid update type can gain structural equality
Failure mode or stable invariant: identical separate grid updates remain identity-unequal with consistent hash behavior
Verification owner: existing public equality policy suite
Current verification gap: grid update instances cannot be constructed
Failing witness: the type is absent before Unit 4
Durable and refactor-stable value: equality policy survives DTO implementation refactors
Artifact target: `test/api_contract/public_equality_policy_test.dart`

### `palette-single-candidate-admission`: Palette single candidate and publication path

Covers: `palette-update-single-store-path`
Impact: `EXTEND_COVERAGE`
Failure family: palette partial updates can add a second mutation/candidate/replay/publication path
Failure mode or stable invariant: every palette call reduces to one complete mutation and zero-or-one existing aggregate publication
Verification owner: existing Store candidate owner plus palette behavior
Current verification gap: palette partial calls cannot enter the candidate route
Failing witness: the method is absent before Unit 3
Durable and refactor-stable value: Store path cardinality survives edit and finalization refactors
Artifact target: `test/store/fixtures/store_transaction_candidate_fixture.dart` and `test/edit/fixtures/palette_update_fixture.dart`

### `grid-single-candidate-admission`: Grid single candidate and publication path

Covers: `grid-update-single-store-path`
Impact: `EXTEND_COVERAGE`
Failure family: grid partial updates can add a second mutation/candidate/replay/publication path
Failure mode or stable invariant: every grid call reduces to one complete mutation and zero-or-one existing aggregate publication
Verification owner: existing Store candidate owner plus grid behavior
Current verification gap: grid partial calls cannot enter the candidate route
Failing witness: the method is absent before Unit 4
Durable and refactor-stable value: Store path cardinality survives edit and finalization refactors
Artifact target: `test/store/fixtures/store_transaction_candidate_fixture.dart` and `test/edit/fixtures/grid_update_fixture.dart`

### `palette-implementer-negative-admission`: Missing palette method rejection

Covers: `final-interface-one-method-omissions`
Impact: `EXTEND_COVERAGE`
Failure family: a direct external `CanvasEdit` implementation can omit only `updatePalette`
Failure mode or stable invariant: the analyzer rejects the isolated incomplete implementer against the real exported interface
Verification owner: specialized analyzer variants in the existing public API contract test
Current verification gap: no negative interface-completeness fixture exists for an absent future method
Failing witness: omitting `updatePalette` is currently valid because the method is absent
Durable and refactor-stable value: real interface completeness survives declaration placement and implementation refactors
Artifact target: `test/api_contract/public_api_v1_compiles_as_written_test.dart`

### `grid-implementer-negative-admission`: Missing grid method rejection

Covers: `final-interface-one-method-omissions`
Impact: `EXTEND_COVERAGE`
Failure family: a direct external `CanvasEdit` implementation can omit only `updateGrid`
Failure mode or stable invariant: the analyzer rejects the isolated incomplete implementer against the real exported interface
Verification owner: specialized analyzer variants in the existing public API contract test
Current verification gap: no negative interface-completeness fixture exists for an absent future method
Failing witness: omitting `updateGrid` is currently valid because the method is absent
Durable and refactor-stable value: real interface completeness survives declaration placement and implementation refactors
Artifact target: `test/api_contract/public_api_v1_compiles_as_written_test.dart`

### `forbidden-appearance-negative-admission`: Excluded appearance member rejection

Covers: `appearance-forbidden-surface`
Impact: `EXTEND_COVERAGE`
Failure family: any one excluded appearance domain can accidentally enter the public snapshot while another missing member keeps a combined fixture red
Failure mode or stable invariant: each of the six excluded members is independently unresolved against the real exported `CanvasAppearance`
Verification owner: specialized analyzer variants in the existing public API contract test
Current verification gap: the type is absent and no isolated excluded-member witnesses exist
Failing witness: no accepted appearance type exists against which the exclusions can be proven
Durable and refactor-stable value: public scope exclusion survives internal state and declaration-file refactors
Artifact target: `test/api_contract/public_api_v1_compiles_as_written_test.dart`

### `forbidden-background-update-admission`: Excluded background update rejection

Covers: `grid-update-exact-public-surface`
Impact: `EXTEND_COVERAGE`
Failure family: an unintended `updateBackground` extension or method can accompany the accepted partial APIs
Failure mode or stable invariant: the exact `CanvasEdit.updateBackground` call remains unresolved against the completed real interface
Verification owner: specialized analyzer variants in the existing public API contract test
Current verification gap: there is no partial appearance mutation surface or isolated witness for this exclusion
Failing witness: the call is absent today but the accepted neighboring APIs do not yet exist
Durable and refactor-stable value: the background mutation boundary remains `setBackgroundColor` across internal/public file refactors
Artifact target: `test/api_contract/public_api_v1_compiles_as_written_test.dart`

### `palette-rollback-admission`: Direct palette rollback boundary

Covers: `palette-update-rollback-boundary`
Impact: `EXTEND_COVERAGE`
Failure family: palette facts can roll back while an effect or public-state notification leaks
Failure mode or stable invariant: an escaping callback after a valid palette partial update leaves every committed/effect/publication domain unchanged
Verification owner: existing edit rollback suite
Current verification gap: it cannot invoke the absent palette partial entry
Failing witness: no palette partial rollback scenario exists before implementation
Durable and refactor-stable value: direct palette atomicity survives shared callback and Store refactors
Artifact target: `test/edit/fixtures/rollback_fixture.dart`

### `grid-rollback-admission`: Direct grid rollback boundary

Covers: `grid-update-rollback-boundary`
Impact: `EXTEND_COVERAGE`
Failure family: grid facts can roll back while an effect or public-state notification leaks
Failure mode or stable invariant: an escaping validation or callback failure after a valid grid partial update leaves every domain unchanged
Verification owner: existing edit rollback suite
Current verification gap: it cannot invoke the absent grid partial entry
Failing witness: no grid partial rollback scenario exists before implementation
Durable and refactor-stable value: direct grid atomicity survives shared callback and Store refactors
Artifact target: `test/edit/fixtures/rollback_fixture.dart`

## Verification Gate

| Check | Scope | Future command or evidence | Pass signal |
| --- | --- | --- | --- |
| Static analysis | All changed Dart owners | `dart analyze` from repository root | Exit 0 |
| DCM analysis | Maintained package | `dcm analyze .` from repository root | Exit 0 |
| Public/API production metrics | Changed public contracts and facade | `dcm calculate-metrics lib/src/contracts/public lib/src/api` from repository root | Exit 0 with no unreviewed changed-owner finding |
| Runtime/Store production metrics | Changed committed read owners | `dcm calculate-metrics lib/src/runtime lib/src/store` from repository root | Exit 0 with no unreviewed changed-owner finding |
| Edit production metrics | Changed edit and materialized-draft owners | `dcm calculate-metrics lib/src/edit` from repository root | Exit 0 with no unreviewed changed-owner finding |
| Guardrail tool metrics | Changed guardrail registry/executor owners | `dcm calculate-metrics tool/guardrails` from repository root | Exit 0 with no unreviewed changed-owner finding |
| Test metrics | Changed API-contract, runtime, Store, edit, and guardrail proof owners | `dcm calculate-metrics test/api_contract test/runtime test/store test/edit test/guardrails` from repository root | Exit 0 with no unreviewed changed-owner finding |
| Unit 1 focused guardrail verification | Retired ID closure and retained direct effects | `dart test test/guardrails/blocking_suite_test.dart test/guardrails/root_ci_target_test.dart test/edit/edit_matrix_effects_test.dart` from repository root | Remaining guardrail routes are closed and direct effect detections pass after retirement |
| Documentation generation | Changed semantic docs, registries, diagram, and lifecycle artifacts | `dart run docs/tool/sync_generated_docs.dart --check` from repository root | Generated documentation is current; any generator-produced diff is reviewed in its owning unit |
| Documentation structure | Changed documentation | `dart run docs/tool/check_docs.dart` from repository root | Docs check passes |
| Architecture graph closure | Changed architecture-owned production seams | `dart run tool/architecture_graph/check.dart` from repository root | Existing expected graph closes without node or edge changes |
| Architecture view parity | Registered generated architecture views | `dart run tool/architecture_graph/generate_views.dart --check` from repository root | Generated views remain current and unchanged unless produced mechanically from an authorized source change |
| Verification-authority cleanup | Unit 1 effect and guardrail owners | `operation-matrix-guardrail-retirement-evidence`, `remaining-guardrail-route-evidence`, and `effect-proof-sensitivity-evidence` before Units 3-4 extend the effect fixture | Invalid parity and its claim are retired across all owners, remaining guardrails execute, and direct runtime detections remain executable |
| Cross-family callback atomicity | Unit 5 after Units 3-4 | `partial-update-atomicity-evidence` | Mixed caught/escaping failures leak nothing and preserve earlier valid work after caught rejection |
| Pre-install owner failure | Unit 6 after Units 3-4 | `partial-update-preinstall-failure-evidence` | Admitted preparation failure reaches no installer or publication boundary |
| Cleanup work budget | Unit 7 after Units 5-6 | `partial-cleanup-work-evidence` | Every functional failure route uses one existing cleanup lifecycle without pure extra traversal, repeated replay, compensating install, or displaced work |
| External public workflow | Unit 8 after Units 2-4 | `lightweight-public-workflow-evidence`; projection avoidance remains `appearance-projection-evidence` | One real shared-harness consumer closes A-001 through the root barrel without implementation imports or consumer full-document calls, while Unit 2 independently proves zero projection |
| Work-budget closure | Construction, mutation/replay, freeze/install/publication, query/read, and cleanup/rollback phases | Direct Matrix evidence `palette-construction-work-evidence`, `grid-work-budget-evidence`, `appearance-projection-evidence`, `palette-single-candidate-evidence`, `grid-single-candidate-evidence`, `partial-cleanup-work-evidence`, `partial-update-atomicity-evidence`, and `partial-update-preinstall-failure-evidence` | Every owner-level phase and remaining cross-unit coordination meet the stated bound with no unrelated-document pass or displaced work |
| H-002 nullable-value re-entry | Before Units 3 and 4 | `nullable-update-field-stop-evidence` | Trigger remains false or only the affected unit stops before mutation for tri-state/compatibility authority |
| H-003 structural snapshot re-entry | Before Unit 2 | `structural-snapshot-expansion-stop-evidence` | Trigger remains false or Unit 2 stops before mutation for coherence/projection/work authority |
| H-004 implementer compatibility re-entry | Before Units 3 and 4 | `direct-implementer-compatibility-stop-evidence` | Trigger remains false or only the affected unit stops before mutation for compatibility/versioning authority |
| H-005 draft visibility re-entry | Before Unit 2 | `draft-visible-appearance-stop-evidence` | Trigger remains false or Unit 2 stops before mutation for a draft-read owner/lifecycle decision |
| H-006 application-state re-entry | Before Unit 2 | `application-state-snapshot-stop-evidence` | Trigger remains false or Unit 2 stops before mutation for cross-boundary owner/dependency/coherence authority |
| H-007 runtime-local re-entry | Before Unit 2 | `runtime-local-snapshot-stop-evidence` | Trigger remains false or Unit 2 stops before mutation for cross-owner coherence/lifecycle/proof authority |
| Canonical route integrity | Public declarations, registry, facade/root/Store read, edit backing/Store mutation path, and semantic owners | Bounded final diff and direct-consumer review against D-001 through D-004 and I-001 through I-002 | No fallback, bypass, mirror, second journal/candidate, stale owner, or unauthorized consumer remains |
| Finding disposition | Whole implementation diff | Review findings are resolved at their owning source or explicitly reported as blockers before lifecycle closure | No unresolved correctness, compatibility, temporal, atomicity, work-budget, source-of-truth, or unit-boundary finding remains |
| Diff hygiene | Whole change | `git diff --check` | Exit 0 |
| Lifecycle closure | Active contract and linked active design | After all outcomes and required evidence are complete, move this contract to `docs/history/plans/` with the same filename and move the linked design to `docs/history/designs/` with the same filename only when no other active plan references it | No completed plan remains active; the linked design is historical only when its last active contract closes; research remains under `docs/history/research/` |
