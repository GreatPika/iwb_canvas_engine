---
schema: architecture-design/v4
date: 2026-08-25
commit: b40c25481bebcb5174db60c445888dcb9794dbc9
branch: main
disposition: READY_FOR_CONTRACT
outcome: R-001
---

# Design: Lightweight Canvas Appearance and Partial Palette/Grid Updates

## Basis

### Sources

| ID | Kind | Locator | Use |
| --- | --- | --- | --- |
| S-001 | research | `docs/history/research/2026-08-25-client-application-appearance-read-and-palette-grid-updates.md` | Historical evidence for the appearance-only read pressure, current public contracts, sparse edit path, projection path, and existing proof seams |
| S-002 | user | user request | Accepted engine API decisions for one coherent appearance snapshot, partial palette/grid updates, compatibility, transaction semantics, and engine-only scope |
| S-003 | repository | `lib/src/contracts/public/canvas_runtime.dart` | Current public edit interface authority |
| S-004 | repository | `lib/src/contracts/public/canvas_document.dart` | Current background, grid, palette, validation, and immutability authority |
| S-005 | repository | `lib/src/api/canvas_runtime.dart` | Current public runtime facade authority |
| S-006 | repository | `lib/src/runtime/runtime_root.dart` | Current runtime composition and Store delegation owner |
| S-007 | repository | `lib/src/edit/edit_session.dart` | Current sparse edit-session, promotion dispatch, and sparse local scalar-state owner |
| S-008 | repository | `lib/src/store/document_store_kernel.dart` | Current committed document facts, projection entry, sparse finalization, and no-op owner |
| S-009 | repository | `lib/src/store/document_projection_cache.dart` | Current full public-document projection owner |
| S-010 | repository | `docs/contracts/edit_kernel.md` | Current edit lifecycle, sparse fallback, atomicity, rollback, and accepted-fact contract |
| S-011 | repository | `docs/contracts/operation_matrix.md` | Current appearance mutation revision, projection, repaint, and no-op authority |
| S-012 | repository | `docs/architecture/03_data_model.md` | Current compact committed truth and lazy public projection authority |
| S-013 | repository | `docs/architecture/01_runtime_ownership.md` | Current public API, Store, EditKernel, and RuntimeRoot ownership authority |
| S-014 | repository | `docs/architecture/02_package_boundaries.md` | Current public-contract placement and dependency direction authority |
| S-015 | repository | `docs/contracts/public_api_v1.md` | Current semantic public runtime and edit contract authority |
| S-016 | repository | `docs/_registry/public_api_v1.yaml` | Current machine-readable public export inventory |
| S-017 | repository | `test/api_contract/public_api_v1_compiles_as_written_test.dart` | Current direct external-consumer compile seam for runtime and edit declarations |
| S-018 | repository | `test/store/fixtures/no_projection_hot_path_fixture.dart` | Current direct projection-build observation seam |
| S-019 | repository | `test/edit/fixtures/net_no_op_edit_commit_fixture.dart` | Current direct final-no-op observation seam |
| S-020 | repository | `test/edit/fixtures/rollback_fixture.dart` | Current direct edit rollback observation seam |
| S-021 | repository | `architecture/decisions/ADR-0002-separate-committed-runtime-and-projection-state.md` | Retained compact-truth and explicit-projection rationale |
| S-022 | repository | `architecture/decisions/ADR-0003-store-finalized-edit-transactions.md` | Retained Store-finalized edit and net-no-op rationale |
| S-023 | repository | `architecture/decisions/ADR-0013-documentation-graph-and-proof-ownership.md` | Retained semantic-owner, registry, graph, and external-proof rationale |
| S-024 | repository | `architecture/decisions/README.md` | ADR consultation and lifecycle-impact policy |
| S-025 | repository | `docs/architecture/architecture_graph.yaml` | Current expected public, runtime, Store, and EditKernel dependency authority |
| S-026 | repository | `lib/src/edit/draft_document.dart` | Current materialized draft appearance-state and whole-value mutation owner |
| S-027 | repository | `docs/diagrams/state_runtime_lifecycle.mmd` | Current semantic active/disposed runtime read lifecycle authority |
| S-028 | repository | `test/edit/fixtures/sync_non_nested_async_stale_fixture.dart` | Current direct stale-handle rejection proof for every public edit entry |
| S-029 | repository | `architecture/decisions/ADR-0001-single-maintained-acyclic-runtime.md` | Accepted single-package, contracts-led public boundary and acyclic dependency decision |
| S-030 | repository | `architecture/decisions/ADR-0017-store-transaction-candidate-and-derived-facts.md` | Accepted single Store candidate, sole sparse journal, exhaustive replay, and bounded publication decision |

### Source Coverage

| Kind | Sources or none |
| --- | --- |
| prior_design | none |
| research | S-001 |
| plan | none |
| user | S-002 |
| repository | S-003, S-004, S-005, S-006, S-007, S-008, S-009, S-010, S-011, S-012, S-013, S-014, S-015, S-016, S-017, S-018, S-019, S-020, S-021, S-022, S-023, S-024, S-025, S-026, S-027, S-028, S-029, S-030 |
| other | none |

### Evidence

| ID | Source | Locator | Observed fact |
| --- | --- | --- | --- |
| E-001 | S-001 | `lines 13-19` | Appearance-only consumers currently reach background/grid/palette through full committed or draft document reads, while ordinary setting setters already use the sparse edit route. |
| E-002 | S-001 | `lines 84-88` | No public `CanvasAppearance`, `CanvasPaletteUpdate`, or `CanvasGridUpdate` declaration currently exists. |
| E-003 | S-003 | `lines 147-176` | `CanvasEdit` currently exposes `readDraftDocument`, whole-value `setBackgroundColor`, `setGrid`, and `setPalette`, but no partial palette or grid update. |
| E-004 | S-004 | `lines 140-215` | `CanvasBackground` owns non-null color and grid values; `CanvasGrid` owns non-null enabled, cell-size, and color values and validates cell-size according to enabled state. |
| E-005 | S-004 | `lines 218-273` | `CanvasPalette` copies all three input iterables to unmodifiable lists and validates maximum list sizes and positive grid sizes. |
| E-006 | S-005 | `lines 28-45` | `CanvasRuntime` is the public facade, and its full document read delegates to `RuntimeRoot`. |
| E-007 | S-006 | `lines 920-922` | `RuntimeRoot.readDocument` delegates the committed read to `DocumentStoreKernel`. |
| E-008 | S-008 | `lines 327-340` | The Store exposes the full projection read separately from direct committed background and palette facts. |
| E-009 | S-009 | `lines 11-55` | The projection cache builds a complete `CanvasDocument`, including resources, background elements, layers, metadata, background, and a copied palette. |
| E-010 | S-007 | `lines 406-473` | `readDraftDocument` promotes a sparse session to a materialized draft and then projects the full draft document. |
| E-011 | S-007 | `lines 683-733` | Existing sparse background, grid, and palette setters merge from the latest session-local override or committed facts and suppress equal local values before journaling. |
| E-012 | S-010 | `lines 95-137` | Ordinary edit sessions read committed facts without building a public document; explicit draft reads are materialization fallbacks, and accepted effects derive from Store-finalized facts. |
| E-013 | S-010 | `lines 152-173` | Store finalization removes final no-ops, and installation remains behind the existing prepared, atomic edit boundary. |
| E-014 | S-011 | `lines 64-69` | Background color, grid, and palette changes already have distinct accepted revision, projection, and repaint effects. |
| E-015 | S-011 | `lines 89-109` | A final no-op has no state, revision, projection, repaint, or event effect, and sparse and materialized edit routes share Store-finalized accepted facts. |
| E-016 | S-012 | `lines 41-58` | Compact committed tables, not a public `CanvasDocument`, own persisted document truth. |
| E-017 | S-012 | `lines 69-123` | Sparse edits retain current scalar facts and install without constructing a public `CanvasDocument`; materialization remains only for explicit draft projection and replacement. |
| E-018 | S-013 | `lines 49-68` | Public API owns stable operations and DTOs, Store owns committed document state and projection cache, EditKernel owns synchronous edits/rollback, and RuntimeRoot owns public observation. |
| E-019 | S-014 | `lines 239-257` | Public declarations belong under `contracts/public`, while runtime composition and edit implementation stay in their established implementation owners. |
| E-020 | S-015 | `lines 413-422` | The full committed document read remains a supported post-dispose immutable read. |
| E-021 | S-015 | `lines 1492-1525` | Public edit callbacks are synchronous and atomic, rollback on callback error, publish only after install, and explicitly identify `readDraftDocument` as a materializing operation. |
| E-022 | S-016 | `lines 1-45` | The registry currently inventories the runtime, document/background/grid/palette values, and edit interfaces as public names. |
| E-023 | S-017 | `lines 340-360` | The external compile fixture directly consumes `CanvasRuntime.readDocument`. |
| E-024 | S-017 | `lines 860-925` | The external compile fixture directly implements the complete `CanvasEdit` interface and its existing setting methods. |
| E-025 | S-018 | `lines 139-158` | Ordinary sparse edits leave the projection build count at zero until an explicit draft read. |
| E-026 | S-019 | `lines 50-68` | Existing background and palette changes that compensate back to their base values are delivery-silent final no-ops. |
| E-027 | S-020 | `lines 45-67` | A callback exception after draft mutations preserves committed facts, revisions, projection identity, and delivery silence. |
| E-028 | S-021 | `lines 20-67` | The retained architecture keeps compact committed truth separate from explicit lazy public document projection. |
| E-029 | S-022 | `lines 20-82` | The retained edit architecture assigns synchronous session lifecycle to EditKernel, final equality to Store, and requires ordinary sparse edits to avoid public projection. |
| E-030 | S-023 | `lines 20-87` | Semantic contracts own behavior, the public registry owns export inventory, the architecture graph owns expected dependencies, and external consumers provide proof without becoming owners. |
| E-031 | S-024 | `lines 75-102` | Every design must declare exactly one ADR lifecycle impact, and retained current owners remain authoritative for changing facts. |
| E-032 | S-025 | `lines 38-89` | The current architecture graph records the public facade and public-contract layers as separate dependency owners. |
| E-033 | S-025 | `lines 157-218` | The current architecture graph records RuntimeRoot composition, Store ownership, and EditKernel ownership as established nodes. |
| E-034 | S-026 | `lines 61-80` | `DraftDocument` owns the current materialized background and palette values in one transaction backing. |
| E-035 | S-026 | `lines 375-400` | Materialized background, grid, and palette setters compare current values, preserve sibling fields, update the draft backing, and mark the established accepted-effect domains. |
| E-036 | S-015 | `lines 170-250` | Every future concrete public type must choose identity or value equality before implementation; unlisted types use identity equality, and `CanvasPalette` currently uses identity equality while `CanvasGrid` uses value equality. |
| E-037 | S-027 | `lines 20-87` | The semantic runtime lifecycle diagram explicitly enumerates `readDocument` as a non-mutating read in both active and disposed states. |
| E-038 | S-015 | `lines 1517-1525` | The public edit contract makes every captured `CanvasEdit` handle stale after its callback and requires stale-handle operations to throw `StateError`. |
| E-039 | S-028 | `lines 137-225` | The owning stale-handle fixture invokes every existing public edit entry after callback closure and requires rejection without state or effect delivery. |
| E-040 | S-029 | `lines 38-82` | The accepted package architecture keeps dependency-neutral public DTOs in the public-contract layer, API entry points facade-owned, implementation consumers below the facade, and external consumers outside package internals. |
| E-041 | S-030 | `lines 24-76` | The accepted Store architecture requires one private transaction candidate, owner-derived final facts, at most one aggregate publication, and one sole `StoreSparseMutation` journal with exhaustive Draft replay. |
| E-042 | S-015 | `lines 720-726` | Public DTOs are immutable; caller-owned collection inputs require defensive copy, runtime validation, and unmodifiable exposure, while public constructors with validation are non-const factories. |
| E-043 | S-015 | `lines 145-161` | Every exported public class requires an explicit Dart subtype modifier, and public signatures must not return nullable container types. |

### Requirements

| ID | Kind | Statement | Basis | Open shape |
| --- | --- | --- | --- | --- |
| R-001 | outcome | The engine must provide a lightweight current-document appearance read and partial palette/grid updates so callers do not need full committed or draft document reads for those operations. | S-002, E-001, E-008, E-009, E-010 | Internal construction and delegation details are open; the lightweight read and partial-update outcome is locked. |
| R-002 | user_decision | `CanvasRuntime.readAppearance()` returns one `CanvasAppearance` containing the current background color, the complete current `CanvasGrid`, and the complete current `CanvasPalette`. | S-002, E-004, E-005 | Internal file placement and copying mechanics are open; public method/type names and contained values are locked. |
| R-003 | user_decision | Background, grid, and palette in one `CanvasAppearance` must come from one coherent committed state; separate sequential appearance-field read APIs are excluded. | S-002, E-008, E-016 | The internal snapshot-read mechanism is open; single-state coherence is locked. |
| R-004 | user_decision | `readAppearance()` must not materialize a full `CanvasDocument` or assemble document layers, elements, resources, or metadata. | S-002, E-009, E-016, E-017 | Internal scalar access is open; full-document materialization and assembly of the named domains are locked out. |
| R-005 | user_decision | `CanvasEdit.updatePalette(CanvasPaletteUpdate)` independently accepts optional named `penColors`, `backgroundColors`, and `gridSizes` constructor parameters. | S-002, E-003, E-005 | Exact collection input interfaces and public inspection getters are open to the Decision Register; method/type/parameter names, named optional construction, and independent-field capability are locked. |
| R-006 | user_decision | `CanvasEdit.updateGrid(CanvasGridUpdate)` independently accepts optional named `enabled`, `cellSize`, and `color` constructor parameters. | S-002, E-003, E-004 | Exact scalar types and public inspection getters are open to the Decision Register; method/type/parameter names, named optional construction, and independent-field capability are locked. |
| R-007 | user_decision | A null update DTO field means preserve that field because every updateable palette and grid value is non-null. | S-002, E-004, E-005 | Internal merge expression is open; null-as-absence semantics are locked and wrapper-based field-state types are excluded. |
| R-008 | user_decision | A supplied empty palette list is a value to install, not an absent field, and it remains subject to the engine's existing palette validation rules. | S-002, E-005 | Validation reuse mechanics are open; empty-list meaning and existing validation authority are locked. |
| R-009 | user_decision | The engine, not the caller, preserves every omitted palette or grid field from the current edit-session state. | S-002, E-011 | Merge helper organization is open; preservation ownership is locked to the edit path. |
| R-010 | user_decision | Multiple partial updates in one edit transaction apply sequentially to the latest session-local state, so later updates retain earlier updates. | S-002, E-011, E-012 | Local storage and journal representation are open; sequential semantics are locked. |
| R-011 | user_decision | An empty update or an update whose final values equal current values is delivery-silent: it causes no document change, revision advance, projection invalidation, repaint, event, or public state publication. | S-002, E-013, E-015, E-026 | Early-equality optimization is open; the complete delivery-silent no-op behavior is locked. |
| R-012 | user_decision | Partial palette and grid updates participate in the existing atomic edit transaction and fully roll back when the edit callback fails. | S-002, E-012, E-013, E-027 | Reuse of sparse or materialized backing mechanics is open; atomicity and rollback are locked. |
| R-013 | user_decision | Existing `readDocument`, `readDraftDocument`, `setGrid`, `setPalette`, and `setBackgroundColor` APIs remain available and are not deprecated. | S-002, E-003, E-020 | Internal reuse between whole-value and partial methods is open; additive compatibility is locked. |
| R-014 | user_decision | The new public contract is universal engine terminology and contains no application-domain preset or profile concepts. | S-002, E-018, E-019 | Documentation phrasing is open; the engine-level vocabulary boundary is locked. |
| R-015 | user_decision | `CanvasAppearance` is limited to persisted document appearance: background color, full grid, and full palette; camera, selection, metadata, layers, elements, and resources are excluded. | S-002, E-004, E-005, E-016 | Internal representation reuse is open; public scope and exclusions are locked. |
| R-016 | user_decision | Background-color mutation remains the existing point operation `CanvasEdit.setBackgroundColor`; no `updateBackground` API is added. | S-002, E-003, E-014 | Internal implementation reuse is open; public mutation surface is locked. |
| R-017 | exclusion | Application-specific adapters, domain concepts, migration steps, and repositories are outside this engine architecture design. | S-002 | No application-specific shape is open inside this design. |
| R-018 | repository_rule | `CanvasAppearance`, `CanvasPaletteUpdate`, and `CanvasGridUpdate` must each receive an explicit public equality policy before implementation. | S-015, E-036 | The selected policy is open to the Decision Register; leaving any new concrete public type unclassified is not open. |
| R-019 | repository_rule | Partial updates must preserve the accepted one private Store transaction candidate, sole `StoreSparseMutation` journal with exhaustive Draft replay, owner-derived final facts, and at most one immutable aggregate publication. | S-030, E-041 | Reuse of existing complete-value mutation variants is open to candidate selection; a second candidate or journal and repeated aggregate publication are not open. |
| R-020 | user_decision | Directly extending `CanvasEdit` is an accepted source-compatibility break: the only supported consumer requested the change, all maintained implementations migrate in the same release, and no compatibility fallback is required. | S-002 | Release version and migration-note wording remain open; direct interface extension and absence of a fallback are locked. |
| R-021 | repository_rule | New public DTOs must remain immutable; caller-owned collection inputs are defensively copied, validated at runtime, and exposed only through unmodifiable values, and validating public constructors are non-const. | S-015, E-042 | Private storage and validation-helper reuse remain open; immutability, alias isolation, runtime validation, unmodifiable exposure, and non-const validating construction are locked. |
| R-022 | repository_rule | Every new public class must use an explicit Dart subtype modifier, and its public inspection surface must not return nullable container types. | S-015, E-043 | The exact compliant modifier and absence-inspection shape are open to the Decision Register. |

## Candidate Analysis

- Comparison: `two_or_three`
- Result: `selected F-001`
- Result basis: F-001, F-002, F-003, M-001, M-002, M-003, M-004, M-005, M-006, M-007, M-008, M-009, M-010, M-011, M-012, M-013, M-014, M-015, M-016, M-017, M-018, M-019, M-020, M-021, M-022, M-023, M-024, R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-008, R-009, R-010, R-011, R-012, R-013, R-014, R-015, R-016, R-017, R-018, R-019, R-020, R-021, R-022, E-003, E-004, E-005, E-008, E-009, E-010, E-011, E-012, E-013, E-014, E-015, E-016, E-017, E-018, E-019, E-021, E-024, E-025, E-026, E-027, E-028, E-029, E-034, E-035, E-036, E-040, E-041, E-042, E-043

### Forms

| ID | Form | Hard constraints | Main trade-off | Basis |
| --- | --- | --- | --- | --- |
| F-001 | Extend the established owners in place: `DocumentStoreKernel` provides one synchronous coherent read of its committed background and palette facts and projects only the background color, grid, and palette into `CanvasAppearance`; `RuntimeRoot` and `CanvasRuntime` delegate that read; the sparse edit-session and materialized `DraftDocument` owners merge partial DTO fields into their latest local grid/palette and route the resulting complete values through the existing setter, validation, sole journal, Store-finalization, no-op, and rollback paths; `CanvasEdit` grows the two methods directly. | pass: the Store-owned coherent read boundary satisfies R-002 through R-004 without fixing its private capture tactic; owner-local merging satisfies R-005 through R-012; public declarations remain in the contracts-led acyclic boundary; partial updates preserve R-019's one Store candidate, sole `StoreSparseMutation` journal, exhaustive replay, and zero-or-one publication; R-020 accepts direct-interface migration; R-021 and R-022 close DTO immutability and public-shape rules; additive facade/edit declarations preserve R-013 and R-016; no application-specific surface enters the engine contract under R-014, R-015, or R-017; every new concrete public type can be classified under R-018. | Every partial palette call constructs one validated bounded `CanvasPalette` and therefore copies its three small lists even when one list changes, and direct implementers must add two methods, but the form adds no Store mutation family, compatibility fallback, second transaction policy, full-document projection, or duplicated committed state. | R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-008, R-009, R-010, R-011, R-012, R-013, R-014, R-015, R-016, R-017, R-018, R-019, R-020, R-021, R-022, E-003, E-004, E-005, E-008, E-009, E-010, E-011, E-012, E-013, E-016, E-017, E-018, E-019, E-021, E-024, E-025, E-026, E-027, E-028, E-029, E-034, E-035, E-036, E-040, E-041, E-042, E-043 |
| F-002 | Add Store-native partial grid and palette mutations: the same Store-local appearance projection serves `readAppearance`, while sparse edit sessions append new partial variants to the sole `StoreSparseMutation` journal and `DocumentStoreKernel` merges and validates them during the existing single-candidate replay; materialized `DraftDocument` gains corresponding exhaustive partial-variant application; `CanvasEdit` grows the two methods directly. | pass: the public surface, coherent projection-free read, sequential update results, validation, no-op, rollback, required equality/immutability/subtype classification, contracts-led dependency direction, R-019 Store constraints, and R-020 direct-interface migration can all be preserved. | Partial palette intent can remain field-granular until replay, but this expands the canonical mutation vocabulary, Store replay branches, and sparse/materialized partial-merge behavior even though the existing edit owners already hold the current local values and whole-value setters. | R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-008, R-009, R-010, R-011, R-012, R-013, R-014, R-015, R-016, R-017, R-018, R-019, R-020, R-021, R-022, E-004, E-005, E-010, E-011, E-012, E-013, E-017, E-024, E-029, E-034, E-035, E-036, E-040, E-041, E-042, E-043 |
| F-003 | Preserve direct-implementer source compatibility by leaving `CanvasEdit` unchanged and exposing extension methods backed by a new capability interface; capable engine edits use the partial path, while an arbitrary legacy implementer requires a full-draft reconstruction fallback or a runtime unsupported-operation branch. | fail: it contradicts R-020's accepted direct extension and no-fallback decision; a reconstructing fallback restores the materializing path this outcome removes, while a throwing fallback makes the universal method syntax non-functional for a valid `CanvasEdit`. | Existing direct implementers compile unchanged, but the public contract gains capability dispatch, dual behavior, and either forbidden full projection work or runtime failure instead of compile-time migration. | R-001, R-005, R-006, R-009, R-013, R-020, E-003, E-010, E-024 |

### Material-Obligation Delta

| ID | Material obligation | F-001 | F-002 | F-003 | Independent authority |
| --- | --- | --- | --- | --- | --- |
| M-001 | R-001 | yes | yes | yes | R-001 |
| M-002 | R-002 | yes | yes | yes | R-002 |
| M-003 | R-003 | yes | yes | yes | R-003 |
| M-004 | R-004 | yes | yes | yes | R-004 |
| M-005 | R-005 | yes | yes | yes | R-005 |
| M-006 | R-006 | yes | yes | yes | R-006 |
| M-007 | R-007 | yes | yes | yes | R-007 |
| M-008 | R-008 | yes | yes | yes | R-008 |
| M-009 | R-009 | yes | yes | yes | R-009 |
| M-010 | R-010 | yes | yes | yes | R-010 |
| M-011 | R-011 | yes | yes | yes | R-011 |
| M-012 | R-012 | yes | yes | yes | R-012 |
| M-013 | R-013 | yes | yes | yes | R-013 |
| M-014 | R-014 | yes | yes | yes | R-014 |
| M-015 | R-015 | yes | yes | yes | R-015 |
| M-016 | R-016 | yes | yes | yes | R-016 |
| M-017 | R-017 | yes | yes | yes | R-017 |
| M-018 | One canonical whole-value grid/palette mutation path owns validation, sparse journaling, Store finalization, and materialized fallback for both set and partial public methods. | yes | no | yes | R-009, R-010, R-011, R-012, E-011, E-012, E-013, E-017, E-029, E-034, E-035, E-041 |
| M-019 | New partial variants within the sole `StoreSparseMutation` vocabulary plus parallel sparse-candidate and materialized-draft merge paths. | no | yes | no | none |
| M-020 | R-018 | yes | yes | yes | R-018 |
| M-021 | R-019 | yes | yes | yes | R-019 |
| M-022 | R-020 | yes | yes | no | R-020 |
| M-023 | R-021 | yes | yes | yes | R-021 |
| M-024 | R-022 | yes | yes | yes | R-022 |

### Future Pressures

| ID | Pressure | Basis | Treatment | Closure refs | Accepted cost or risk |
| --- | --- | --- | --- | --- | --- |
| P-002 | A future appearance field may itself become nullable, invalidating null-as-absence update semantics. | R-007, E-004, E-005 | rejected | D-003 | Current updateable values remain non-null; any nullable field requires a new explicit field-state contract rather than silently changing these DTO semantics. |
| P-003 | Future callers may request camera, selection, metadata, layers, elements, resources, or application-domain fields in the lightweight snapshot. | R-014, R-015, R-017 | rejected | D-002 | `CanvasAppearance` remains deliberately narrow; expanding its ownership boundary requires architecture re-entry. |
| P-004 | A future release may require existing direct `CanvasEdit` implementers to compile unchanged. | R-020, E-024 | rejected | D-004 | The accepted release permits direct-interface migration; preserving old implementers would require reopening the compatibility form rather than adding a hidden materializing or throwing fallback. |

## Decision Register

### D-001 — Existing-owner appearance form
- Concerns: `form`, `owner`, `in_scope`, `out_of_scope`, `dependency`, `source_of_truth`
- Lock: Extend existing owners without a new appearance service, cache, committed-state mirror, Store mutation family, transaction candidate, journal, or application-specific seam. `DocumentStoreKernel` remains the sole committed appearance owner; `RuntimeRoot` and `CanvasRuntime` only delegate the public read. Sparse `EditSession` and materialized `DraftDocument` remain the current transaction-state owners and reduce partial updates to the established whole-value grid/palette mutation path before Store finalization. The existing one private Store transaction candidate and sole `StoreSparseMutation` journal remain authoritative. Public declarations remain dependency-low under `contracts/public`, the facade remains under `api`, implementation owners consume contracts rather than the facade, and no implementation-to-API back edge is introduced.
- Open: Private helper names, declaration-file decomposition inside `contracts/public`, local constructor helpers, and delegation method names below the locked public surface remain implementation choices.
- Basis: R-001, R-009, R-012, R-014, R-017, R-019, E-002, E-008, E-011, E-012, E-013, E-016, E-017, E-018, E-019, E-028, E-029, E-031, E-032, E-033, E-034, E-035, E-040, E-041
- Form: F-001
- Realizes: M-001, M-014, M-017, M-018, M-021
- Depends on: none
- Contract targets: `classification`, `owner`, `scope`, `source_of_truth`, `dependency`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: The Store already owns one immutable committed aggregate and direct appearance facts, while both edit backings already own their current grid/palette values and whole-value validation/no-op paths. Extending those owners removes the full-projection cause without adding synchronization or a second transaction vocabulary. ADR-0001's contracts-led acyclic boundary, ADR-0002's compact committed truth, ADR-0003's Store-finalized edits, and ADR-0017's single candidate/journal/publication constraints are retained without lifecycle change; no accepted ADR is created, superseded, or retired.

### D-002 — Public appearance snapshot contract
- Concerns: `state_data`, `temporal`, `out_of_scope`, `compatibility`
- Lock: Add the synchronous signature `CanvasAppearance CanvasRuntime.readAppearance()`. `CanvasAppearance` is declared `@immutable final class CanvasAppearance` with the exact public const constructor `const CanvasAppearance({required this.backgroundColor, required this.grid, required this.palette})` and exact public final fields `Color backgroundColor`, `CanvasGrid grid`, and `CanvasPalette palette`; it is publicly constructible and has no other public state. `DocumentStoreKernel` owns the synchronous coherence boundary and constructs the appearance from one coherent committed state containing its background and palette facts without calling the full projection cache, assembling layers/elements/resources/metadata, or creating a second stored appearance value. Camera, selection, metadata, layers, elements, resources, and application-domain values are absent. The synchronous read is permitted during an active edit callback and observes only the last installed committed appearance, never sparse or materialized draft intermediates; the new appearance becomes readable only after accepted Store installation. The read itself mutates nothing and publishes nothing. It is also allowed after runtime disposal and returns appearance from the last committed Store state, matching the retained immutable-read lifecycle of `readDocument`. `CanvasAppearance`, `CanvasPaletteUpdate`, and `CanvasGridUpdate` use identity equality; existing `CanvasGrid` value equality and `CanvasPalette` identity equality do not change.
- Open: Local aggregate capture versus equivalent Store-internal direct fact access, construction order, reuse versus defensive reconstruction of already-immutable `CanvasGrid` and `CanvasPalette` instances, dartdoc wording, declaration-file placement, and private Store-to-root delegation shape remain open as long as the exact public declaration, one-state coherence, projection avoidance, and source-of-truth semantics remain unchanged and no mutable caller alias or stored duplicate truth appears.
- Basis: R-002, R-003, R-004, R-014, R-015, R-018, R-021, R-022, E-004, E-005, E-006, E-007, E-008, E-009, E-016, E-017, E-018, E-020, E-028, E-030, E-036, E-037, E-040, E-042, E-043
- Form: F-001
- Realizes: M-002, M-003, M-004, M-015, M-020
- Depends on: D-001
- Contract targets: `state_data`, `temporal`, `scope`, `compatibility`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: The existing synchronous Store-owned committed-state boundary is the smallest authority that can guarantee coherence while preserving the compact-truth/lazy-projection architecture; its private capture or access tactic remains an implementation choice. Matching the existing read-only post-dispose lifecycle adds no new guard state, while identity equality avoids inventing deep palette semantics not required by the outcome.

### D-003 — Partial update merge and validation semantics
- Concerns: `policy`, `state_data`, `order`, `temporal`, `atomicity`
- Lock: `CanvasPaletteUpdate` is an `@immutable final class` with the exact non-const public factory `CanvasPaletteUpdate({Iterable<Color>? penColors, Iterable<Color>? backgroundColors, Iterable<double>? gridSizes})`. Its exact public inspection surface is `bool get hasPenColors`, `bool get hasBackgroundColors`, `bool get hasGridSizes`, `List<Color> get penColors`, `List<Color> get backgroundColors`, and `List<double> get gridSizes`; each list getter is unmodifiable and returns the supplied constructor-time snapshot when its matching presence getter is true, while an absent field has a false presence getter and an empty unmodifiable list. `CanvasGridUpdate` is an `@immutable final class` with the exact non-const public factory `CanvasGridUpdate({bool? enabled, double? cellSize, Color? color})` and exact public nullable scalar getters of those same names and types. Null constructor input means absent and a supplied empty palette collection is present. Each factory performs every context-free validation applicable to supplied values; `CanvasPaletteUpdate` defensively copies every non-null collection before exposure, and the edit call applies the existing complete-value validation after merging context-dependent values. Both `CanvasEdit.updatePalette` and `CanvasEdit.updateGrid` return `void` and must pass through the existing active/stale `CanvasEdit` boundary before reading transaction backing, merging fields, or validating a result; after callback closure, each operation throws `StateError` and causes no mutation or delivery. For an active handle, the methods merge every present field into the latest value owned by the active sparse `EditSession` or materialized `DraftDocument`, construct the resulting complete `CanvasPalette` or `CanvasGrid`, and then use the corresponding existing whole-value setter path. A successful changed sparse call therefore appends the existing complete-value `StoreSparseMutation` exactly once; no partial mutation variant or second journal is added, promotion remains exhaustive over the sole journal, final facts remain owner-derived, and Store publishes at most one immutable aggregate after finalization. Each call validates its own resulting complete value before that call mutates the draft; a validation failure caught inside the callback leaves earlier successful callback edits intact, while an escaping failure triggers existing whole-callback rollback. Repeated successful calls therefore compose in callback order. After normal callback return, partial updates reuse the existing Store-prepared commit and accepted-effect boundary: all partial-update merge, construction, validation, final equality, and effect derivation finish before the existing irreversible committed-document installation; no new partial-update-specific fallible work may occur after that point, and only the existing accepted delivery/publication work may follow it. Empty, locally equal, compensating-final-equal, and otherwise unchanged updates remain completely delivery-silent. Accepted changes retain exactly the existing whole-value effect domains: palette changes document/projection with no canvas repaint; any grid-value change uses grid revision/projection/main repaint; no new revision, event, action, or publication family is introduced. Downstream evidence must directly observe committed appearance plus document/grid/projection revisions, projection-build or invalidation behavior, repaint, events/actions, public state publication, journal admission/replay, and aggregate publication count across changed success, caught per-call validation failure, escaping callback failure, empty/equal update, compensating final no-op, and stale-handle rejection; a setter-call or journal-entry proxy is insufficient.
- Open: Private storage fields, shared validation-helper placement, and local merge-helper decomposition and reuse between sparse and materialized backings remain open; public input/getter types, presence semantics, constructibility, const posture, return types, subtype modifiers, new Store mutation variants, and parallel validation policy are not open.
- Basis: R-005, R-006, R-007, R-008, R-009, R-010, R-011, R-012, R-016, R-019, R-021, R-022, E-003, E-004, E-005, E-010, E-011, E-012, E-013, E-014, E-015, E-017, E-021, E-025, E-026, E-027, E-029, E-034, E-035, E-038, E-039, E-041, E-042, E-043
- Form: F-001
- Realizes: M-005, M-006, M-007, M-008, M-009, M-010, M-011, M-012
- Depends on: D-001
- Contract targets: `policy`, `state_data`, `order`, `temporal`, `atomicity`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: Both current edit backings can determine the complete next value at the public mutation boundary, so the existing validators, setters, sole journal, exhaustive Draft replay, Store candidate, owner-derived final equality, and rollback lifecycle remain the single semantic path. This preserves sequential edit meaning without pushing caller-preservation policy into Store replay and retains ADR-0017 without lifecycle change.

### D-004 — Additive surface and direct-implementer migration
- Concerns: `compatibility`, `migration_retirement`, `negative_proof_fixture`
- Lock: Extend the existing `abstract interface class CanvasEdit` directly with the exact methods `void updatePalette(CanvasPaletteUpdate update)` and `void updateGrid(CanvasGridUpdate update)`, and extend the existing public `CanvasRuntime` facade with `CanvasAppearance readAppearance()`. Export the exact `@immutable final` public classes and constructors/getters locked by D-002 and D-003 from the root package surface. The direct-interface source break is accepted under R-020: every maintained implementation and direct compile fixture adopts both methods in the same release, and no unchanged external-implementer compatibility is promised. Keep `readDocument`, `readDraftDocument`, `setGrid`, `setPalette`, and `setBackgroundColor` available without deprecation or semantic change; do not add a V2 interface, capability cast, extension-only fallback, `updateBackground`, or legacy full-read implementation of the new methods. The semantic public contract, export inventory, facade, implementation, examples that directly consume the surface, and external compile seam must agree before release. The invalid public-interface states are exactly: a direct external-style `CanvasEdit` implementer omits `updatePalette`; one omits `updateGrid`; an external consumer attempts to resolve `camera`, `selection`, `metadata`, `layers`, `elements`, or `resources` on `CanvasAppearance`; or an external consumer attempts to resolve `CanvasEdit.updateBackground`. The real exported Dart declarations are the production boundary, and the analyzer/compiler must reject every isolated invalid-state witness. Negative witnesses remain quarantined external-consumer fixtures and never become production allowlists, copied API inventories, interface authorities, or general source scanners; registry/name-presence checks are not substitutes. No old declaration is retired, and the release process owns version selection and migration-note placement.
- Open: Declaration ordering, exact release version, migration-note location, and source edit order within one unreleased change remain open.
- Basis: R-005, R-006, R-013, R-014, R-015, R-016, R-017, R-020, R-021, R-022, E-003, E-006, E-020, E-022, E-023, E-024, E-030, E-040, E-042, E-043
- Form: F-001
- Realizes: M-013, M-016, M-022, M-023, M-024
- Depends on: D-002, D-003
- Contract targets: `compatibility`, `migration_retirement`, `negative_proof_fixture`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: The accepted `edit.updatePalette` and `edit.updateGrid` calls require the existing public edit interface to grow. Migrating all maintained direct implementers atomically is the only form that preserves the exact surface without a parallel interface or a materializing extension fallback, while keeping ADR-0001's one public barrel, contracts-led declarations, facade ownership, and external-consumer boundary unchanged.

## Impact Register

### I-001 — Public appearance API and source migration
- Action: update
- Surface: `lib/src/contracts/public/**`; `lib/src/api/canvas_runtime.dart`; `docs/contracts/public_api_v1.md`; `docs/_registry/public_api_v1.yaml`; `test/api_contract/public_api_v1_compiles_as_written_test.dart`; `test/api_contract/fixtures/public_integration_compile_fixture.dart`
- Required by: D-001, D-002, D-003, D-004
- Resulting authority: D-001, D-002, D-003, D-004
- Contract requirement: Add the exact synchronous `CanvasAppearance readAppearance()` facade method and exact `void updatePalette(CanvasPaletteUpdate update)` / `void updateGrid(CanvasGridUpdate update)` interface methods. Add the exact `@immutable final` constructible types, constructors, public fields/getters, presence getters, non-null unmodifiable palette-list inspection, const/non-const posture, identity equality, defensive copies, and validation boundaries locked by D-002 through D-004. Preserve coherent/projection-free/post-dispose/reentrant committed-read semantics, retain existing methods without deprecation, and add no application-domain vocabulary. Update the existing API-wrapper exposure, semantic contract, exported-name inventory, maintained positive consumers, and each direct `CanvasEdit` implementer together while retaining the already-complete root barrel route unchanged. Quarantined external-style negative consumers must prove that each partial-method omission, every forbidden `CanvasAppearance` member, and `CanvasEdit.updateBackground` fail against the real exported declarations without becoming production truth.

### I-002 — Appearance read and edit owner contracts
- Action: update
- Surface: `lib/src/runtime/runtime_root.dart`; `lib/src/store/document_store_kernel.dart`; `lib/src/edit/edit_session.dart`; `lib/src/edit/draft_document.dart`; `docs/architecture/01_runtime_ownership.md`; `docs/architecture/03_data_model.md`; `docs/contracts/edit_kernel.md`; `docs/contracts/operation_matrix.md`; `docs/diagrams/state_runtime_lifecycle.mmd`; `test/edit/fixtures/sync_non_nested_async_stale_fixture.dart`
- Required by: D-001, D-002, D-003
- Resulting authority: D-001, D-002, D-003
- Contract requirement: Extend the existing Store/RuntimeRoot internal read chain with one Store-owned coherent committed-state `CanvasAppearance` projection that never enters `DocumentProjectionCache`, while leaving local aggregate capture versus equivalent Store-internal fact access open, and extend both sparse and materialized edit owners with current-state partial merges that produce complete validated values before the established whole-value mutation path. The semantic runtime lifecycle diagram must enumerate `readAppearance` as a non-mutating read in both active and disposed states, consistent with D-002. Both new edit entries must use the existing active/stale handle boundary before backing access, merge, or validation, and the owning exhaustive stale fixture must cover them. Sparse partial changes must reuse the existing complete-value variant in the sole `StoreSparseMutation` journal, its exhaustive Draft replay, the one Store transaction candidate, owner-derived final facts, and the zero-or-one aggregate publication boundary. The resulting authorities must define callback-order composition, per-call validation timing, caught versus escaping failure, Store-prepared atomic installation, unchanged effect domains, complete no-op silence, active-edit committed-read visibility, post-install visibility, and the absence of a new cache, revision, event, Store mutation family, or application-specific seam.

## Assurance Register

### A-001 — Lightweight public appearance outcome
- Verifies: R-001, D-001/in_scope
- Claim: A caller obtains current persisted appearance through `CanvasRuntime.readAppearance` and applies palette/grid field subsets through `CanvasEdit.updatePalette` and `CanvasEdit.updateGrid` without supplying or reading a full `CanvasDocument`.
- Failure: Any accepted operation is absent from the real public barrel, requires a `CanvasDocument`, or fails to produce its committed public behavior.
- Oracle: Compile and execute an external-style public-barrel consumer that reads appearance and performs both partial updates against a real runtime, then observe the committed results through the public API.
- Proxy risk: Compiling DTO declarations or invoking private helpers cannot prove that the real public operations produce committed behavior.
- Evidence constraints: Use only the root package import and real runtime/edit entry points; do not use `src/**`, private backing access, or an application adapter.
- Architecture seam: D-001

### A-002 — Coherent appearance contents
- Verifies: R-002, R-003, D-002/state_data
- Claim: Each `CanvasAppearance` contains the background color, complete grid, and complete palette from one committed state.
- Failure: Fields come from different committed revisions or any required grid or palette field is missing or stale.
- Oracle: Install distinguishable appearance values in successive committed states, read at each boundary, and compare every required public appearance field with direct Store facts from the same coherent committed-state boundary.
- Proxy risk: Comparing only background color or reading after a quiescent single change can miss mixed-state grid/palette assembly and accidental extra fields.
- Evidence constraints: Use at least two states with all appearance fields distinct; the expected values come from one coherent Store state rather than from `readDocument` or copied fixture truth, without fixing the private capture tactic.
- Architecture seam: D-002

### A-003 — Appearance read never enters full projection
- Verifies: R-004, D-001/source_of_truth, D-002/state_data
- Claim: `readAppearance` reads only Store-owned appearance facts and performs zero public-document projection builds and zero layer, element, resource, or metadata assembly work regardless of unrelated document size.
- Failure: The read calls or warms `DocumentProjectionCache`, builds a `CanvasDocument`, projects resources/layers/elements/metadata, or its appearance-read work grows with unrelated document content.
- Oracle: Seed committed documents with increasing unrelated layers, elements, resources, and metadata while keeping appearance fixed; call only `readAppearance`, directly observe an unchanged projection-build count, and perform a bounded audit of the selected Store read boundary proving that it reads only Store-owned coherent background/palette facts and does not call projection or collection owners; then confirm a later explicit `readDocument` remains the first projection build.
- Proxy risk: Fast wall-clock timing or a cached full document can hide projection/traversal work, and projection-build count alone cannot detect unrelated assembly outside the cache.
- Evidence constraints: Use the stable Store projection-build observation plus a bounded production owner/dependency audit; do not invent an assembly-event seam, assert private helper names, or rely on timing thresholds.
- Architecture seam: D-001, D-002

### A-004 — Appearance read lifecycle and visibility
- Verifies: D-002/temporal
- Claim: During an active edit callback `readAppearance` returns the last installed committed appearance without mutation or publication; after accepted installation it returns the new appearance, after callback rollback it retains the old appearance, and after dispose it returns the last committed appearance.
- Failure: The read exposes draft/intermediate fields, triggers state notification or mutation, misses an accepted install, exposes a rolled-back value, or throws solely because the runtime is disposed.
- Oracle: Read before, between multiple partial calls inside one callback, immediately after successful return, after an escaping callback failure, and after dispose while observing committed facts, state notifications, revisions, and returned values.
- Proxy risk: Reading only before and after success cannot detect draft leakage, publication during the callback, rollback leakage, or post-dispose divergence.
- Evidence constraints: Use the real public runtime read and edit callback with distinct intermediate values; observe public notification windows and committed owner facts without materializing the draft.
- Architecture seam: D-002

### A-005 — Partial DTO presence, empty values, and validation
- Verifies: R-005, R-006, R-007, R-008, D-003/policy, D-003/state_data
- Claim: Every palette/grid field can be independently present; null preserves it, supplied empty palette collections replace it, and each context-dependent merged complete value follows existing `CanvasPalette`/`CanvasGrid` validation.
- Failure: An omitted field changes, an empty collection is treated as omission, a named field cannot update independently, or post-merge complete-value validation is bypassed or differs from the established value boundary.
- Oracle: Through valid public DTO construction and real edits, cover each field alone, all-null DTOs, supplied-empty palette lists, valid boundary values, and `CanvasGridUpdate` values that become invalid only after merging with distinguishable current enabled/cell-size transaction state; compare exact committed appearance and public edit errors. Invalid supplied palette collections belong exclusively to A-016's constructor boundary.
- Proxy risk: DTO field inspection, constructor-only failures, or happy-path compilation cannot prove merge presence, empty-value meaning, or context-dependent complete-value validation.
- Evidence constraints: Exercise both palette and grid through public edit calls and the real complete-value constructors; constructor-time collection validation belongs only to A-016, and expected merged validation comes from the current public value boundary rather than a copied rule table.
- Architecture seam: D-003

### A-006 — Sequential sparse and materialized update composition
- Verifies: R-009, R-010, D-003/order, D-003/state_data
- Claim: Repeated partial calls compose in callback order from the latest transaction-local value in both untouched sparse sessions and sessions already materialized by an explicit draft read; changed partial calls on the untouched route remain sparse and do not build a public draft/document projection.
- Failure: A later call restores an omitted field to the pre-transaction value, sparse and materialized results differ, caller code must read and rebuild a whole value, or any untouched sparse partial sequence promotes/materializes the draft.
- Oracle: Apply disjoint and overlapping palette/grid sequences first from an untouched sparse session while requiring unchanged projection-build count, then perform an explicit draft read and require it to cause the first projection build; separately repeat the sequences after deliberate materialization and compare final committed appearance and accepted effect domains for parity.
- Proxy risk: A single update or two updates to the same value cannot expose stale-base merging or backing divergence.
- Evidence constraints: Use sequences with distinguishable base, first-update, and second-update values, the stable Store projection-build observation, and both backing routes without private merge-helper assertions.
- Architecture seam: D-003

### A-007 — Complete no-op silence
- Verifies: R-011, D-003/temporal, D-003/atomicity
- Claim: All-null, locally equal, and compensating-final-equal partial updates install nothing and advance no document/grid/projection revision, projection invalidation/build, repaint, event/action, or public-state notification.
- Failure: Any listed no-op form changes committed identity/facts or emits any revision, invalidation, repaint, event/action, or state observation.
- Oracle: Capture committed facts, revisions, projection identity/build count, repaint/effect observations, action/event streams, and state notifications before each no-op family on sparse and materialized routes, then require complete equality and delivery silence afterward.
- Proxy risk: Document-field equality alone misses revisions, invalidation, repaint, streams, or transient publication.
- Evidence constraints: Keep early local equality and final Store compensation as distinct witnesses; use stable owner/public observation seams and no private journal-size assertion.
- Architecture seam: D-003

### A-008 — Validation and callback failure atomicity
- Verifies: R-012, D-003/temporal, D-003/atomicity
- Claim: A context-dependent invalid grid partial call mutates none of its fields; if caught inside the callback, earlier successful palette/grid edits may still commit normally, while an escaping grid-validation or callback failure installs and publishes none of the callback's updates. All partial-specific fallible work completes before the existing irreversible Store installation.
- Failure: A rejected grid call partially mutates, a caught rejection removes prior valid work, an escaping grid-validation or callback failure leaks any committed/effect state, or a partial-specific expected failure occurs after Store installation.
- Oracle: Observe owner preparation/install and public delivery boundaries for caught context-dependent invalid grid calls after prior valid palette/grid changes, escaping grid-validation failures, and an explicit later callback exception after valid updates of both families; compare committed appearance, revisions, projection, repaint, events/actions, and state publication, and inject admitted pre-install owner failures. Invalid supplied palette collections belong exclusively to A-016's constructor boundary.
- Proxy risk: Asserting only the thrown error or final document fields cannot locate the irreversible boundary or detect leaked downstream effects.
- Evidence constraints: Failure injection remains at stable validation/preparation/install boundaries; exclude VM-fatal conditions and do not add rollback after successful Store installation.
- Architecture seam: D-003

### A-009 — Changed-update effect parity
- Verifies: R-005, R-006, D-003/policy
- Claim: A changed palette partial update has the same accepted document/projection and no-canvas-repaint effects as `setPalette`, while any changed grid partial update has the same document/grid/projection/main-repaint effects as `setGrid`; neither emits an action/event or new revision family.
- Failure: Partial and whole-value routes diverge in accepted facts, revisions, invalidation, repaint, publication, or events for the same final value.
- Oracle: From identical base documents, reach the same final palette/grid once through the whole setter and once through partial updates, then compare committed appearance and every accepted effect/public observation domain.
- Proxy risk: Matching final appearance cannot prove revision, repaint, invalidation, publication, or event parity.
- Evidence constraints: Compare palette and grid as separate effect families and use real commit delivery observations rather than inspecting compiler branches.
- Architecture seam: D-003

### A-010 — Public signature and authority alignment
- Verifies: R-002, R-005, R-006, R-013, R-020, R-022, D-002/compatibility, D-004/compatibility, I-001
- Claim: The root public API exposes the exact accepted new method, class, constructor, getter, return, parameter, subtype-modifier, and const/non-const signatures and all named retained signatures without deprecation, while exported declarations, the semantic public contract, and the exported-name inventory agree.
- Failure: A required new or retained declaration, signature, export, or non-deprecation guarantee is missing, or declarations, semantic contract, registry inventory, and compiled consumer disagree.
- Oracle: Compile an external-style positive consumer against every exact new and retained signature from the root barrel, then compare the real exported declarations with the semantic contract and exported-name inventory.
- Proxy risk: Registry/name checks cannot prove signatures or root-barrel usability, while positive compilation alone cannot prove the durable semantic contract and inventory were migrated.
- Evidence constraints: Treat exported declarations and semantic docs as authorities, registry as inventory, and consumer compilation as proof; do not promote a copied declaration list or application adapter to authority.
- Architecture seam: D-002, D-004

### A-011 — New public-type equality policy
- Verifies: R-018, D-002/state_data, I-001
- Claim: Independently constructed structurally identical `CanvasAppearance`, `CanvasPaletteUpdate`, and `CanvasGridUpdate` instances remain identity-unequal and their hash behavior is consistent with identity equality.
- Failure: Any new type gains unintended structural equality or hash semantics, or hash-based collection behavior contradicts identity equality.
- Oracle: Compare separate public instances with identical fields and the same instances with themselves, including hash-based collection membership behavior.
- Proxy risk: Absence of an explicit equality override does not prove exported operator/hash behavior or guard against generated value semantics.
- Evidence constraints: Use public constructors and operators; do not inspect private fields or generated-method presence.
- Architecture seam: D-002

### A-012 — Direct-implementer migration negative proof
- Verifies: R-020, D-004/migration_retirement, D-004/negative_proof_fixture, I-001
- Claim: Every maintained direct `CanvasEdit` implementer supplies both new methods, and an isolated external-style implementer omitting either one is rejected by the analyzer/compiler against the real exported interface.
- Failure: A maintained implementation remains stale, either single-method omission compiles, or the negative witness depends on a copied interface/inventory instead of the package export.
- Oracle: Compile the maintained positive direct implementer, then analyze two quarantined negative consumer variants that each omit one different method while importing the real package barrel and require the missing-implementation diagnostic.
- Proxy risk: A public-name registry check, source grep, or one omission witness cannot prove interface conformance for both methods.
- Evidence constraints: Negative variants live only in test-owned external consumer input and never enter production, docs authority, registry truth, or a general source scanner.
- Architecture seam: D-004

### A-013 — Appearance owner authority transition
- Verifies: I-002
- Claim: The named runtime, Store, sparse edit, materialized draft, architecture, edit, operation-matrix, and semantic lifecycle-diagram owners consistently define and implement one projection-free committed appearance read plus one existing whole-value mutation/effect path for partial updates.
- Failure: A named owner remains stale, assigns the behavior to another owner, documents a full projection or new mutation family, or disagrees on validation, order, atomicity, no-op, or effects.
- Oracle: Review the exact named semantic owners and production boundaries together, then exercise their public behavior through A-003 through A-009 and run the repository's documentation consistency route.
- Proxy risk: Passing behavior tests cannot prove durable contracts were updated, while docs checks alone cannot prove runtime behavior.
- Evidence constraints: Current semantic Markdown and production owners retain meaning; tests and generated navigation remain evidence only.
- Architecture seam: D-001, D-002, D-003

### A-014 — Retained architecture graph closure
- Verifies: D-001/dependency, D-001/out_of_scope
- Claim: The existing expected graph continues to cover the generic facade-to-RuntimeRoot-to-Store delegation and public-contract-below-implementation direction without a new appearance node, service, cache, or application-specific dependency; no graph or generated-view transition is required.
- Failure: Actual dependencies bypass owners or reverse direction, an excluded appearance/application node or edge is introduced, or implementation requires an expected graph delta that this design did not authorize.
- Oracle: Run the architecture expected-versus-actual closure and generated-view checks without editing graph authority or generated projections, then inspect any reported delta against D-001 before implementation can proceed.
- Proxy risk: Analyzer success alone cannot prove expected graph coverage, and unchanged generated Mermaid files alone cannot prove actual dependency direction.
- Evidence constraints: `architecture_graph.yaml` remains the unchanged expected-relationship authority and generated files remain projections; any required semantic graph delta triggers architecture re-entry rather than an implementation-side update.
- Architecture seam: D-001, D-002

### A-015 — Appearance source-of-truth singularity
- Verifies: D-001/form, D-001/owner, D-001/source_of_truth
- Claim: Store committed background/palette facts remain the only durable appearance truth; no new cache, mirror, synchronization state, or appearance service is introduced, and runtime/read code does not bypass the established committed owner.
- Failure: Another owner stores appearance for synchronization, a cache gains independent invalidation/lifecycle, an appearance service becomes a second truth, or runtime/read code bypasses the established committed owner.
- Oracle: Audit committed/runtime appearance state fields, cache/service ownership, and dependency boundaries, correlating them with the direct read behavior and architecture graph; Store candidate, journal, mutation-family, replay, acceptance, and publication policy belong only to A-021.
- Proxy risk: Functional equality and zero projection builds can pass while duplicate state or a second mutation policy silently drifts.
- Evidence constraints: Inspect stable committed owner fields, read boundaries, cache/service ownership, and graph relationships rather than private helper names; no test-owned allowlist or copied state inventory becomes production authority.
- Architecture seam: D-001

### A-016 — Public collection immutability and alias isolation
- Verifies: R-021, D-002/state_data, D-003/state_data, I-001
- Claim: `CanvasAppearance` exposes only immutable grid/palette values and unmodifiable palette collections; the non-const `CanvasPaletteUpdate` factory validates and snapshots every supplied collection into an unmodifiable list at construction, exposes absence through separate presence getters rather than nullable container returns, and prevents source mutation before or after edit application from changing the already-created DTO or committed engine state.
- Failure: Mutation through an exposed collection succeeds, a collection getter is nullable, presence getters cannot distinguish absence from a supplied empty list, source mutation after DTO construction changes that DTO or its later applied value, invalid supplied collection data bypasses constructor validation, or runtime appearance changes through a caller alias without another edit.
- Oracle: Construct absent, supplied-empty, valid mutable-source, and invalid-source palette updates; compare every presence/list getter, require constructor-time validation for invalid supplied values, mutate every valid source before entering an edit and require DTO values to remain unchanged, apply the DTO, mutate the sources again, and attempt mutation through every update and appearance collection view; require the constructor-time values to remain installed and every exposed mutation attempt to fail without another edit.
- Proxy risk: Nominal `List` typing, an `@immutable` annotation, or successful value construction does not prove defensive copying, unmodifiable exposure, or applied-state isolation.
- Evidence constraints: Use only public constructors, collection views, real edit application, and public appearance reads; do not inspect private backing fields.
- Architecture seam: D-002, D-003

### A-017 — Retained whole-value behavior
- Verifies: R-013, D-004/compatibility
- Claim: `readDocument`, `readDraftDocument`, `setGrid`, `setPalette`, and `setBackgroundColor` retain their pre-change public behavior and remain available without deprecation.
- Failure: Any retained operation is removed, deprecated, behaviorally changed, or redirected through semantics that alter its established result, validation, transaction, or effect behavior.
- Oracle: Run the existing owning behavioral contracts for every retained operation and the positive external-consumer compile seam, comparing their established results, failures, transaction behavior, and accepted effect domains before and after the release change.
- Proxy risk: Declaration presence and compilation cannot prove retained runtime semantics, while new partial-update tests cannot substitute for the whole-value owners.
- Evidence constraints: Reuse the nearest existing behavior owners and fixtures; add no duplicate rule table or parallel compatibility implementation.
- Architecture seam: D-004

### A-018 — Forbidden appearance surface negative proof
- Verifies: R-015, R-016, D-002/out_of_scope, D-004/negative_proof_fixture
- Claim: `CanvasAppearance` exposes none of `camera`, `selection`, `metadata`, `layers`, `elements`, or `resources`, and `CanvasEdit` exposes no `updateBackground` operation.
- Failure: Any isolated forbidden member or method resolves through the real package surface, including through an extension, fallback, or alternate exported declaration.
- Oracle: Analyze one quarantined external-consumer variant for each forbidden `CanvasAppearance` member and one for `CanvasEdit.updateBackground`, all importing the real root barrel, and require the corresponding unresolved-member diagnostic from the analyzer/compiler.
- Proxy risk: Absence from a registry, docs page, grep result, or positive fixture cannot prove that the Dart public surface rejects the forbidden expression.
- Evidence constraints: Keep each witness isolated in test-owned external consumer input; never copy the public interface into the fixture or turn the witness set into production inventory or a general source scanner.
- Architecture seam: D-002, D-004

### A-019 — Engine-only vocabulary and dependency boundary
- Verifies: R-014, R-017, D-001/out_of_scope, D-002/out_of_scope
- Claim: The appearance read and partial-update contract is expressed only with engine-domain concepts and introduces no application-specific type, adapter, migration, package dependency, or state owner.
- Failure: An exported declaration, owning implementation path, durable engine contract, or dependency edge introduces application-domain concepts or delegates ownership to an application-specific seam.
- Oracle: Review the actual exported declarations and named semantic owners, then run the architecture expected-versus-actual dependency check and inspect its concrete edges for any new application dependency or owner outside the accepted engine path.
- Proxy risk: Searching for a single product word cannot establish semantic ownership or dependency direction and would turn prose vocabulary into a brittle source scanner.
- Evidence constraints: Use exported declarations, named owner contracts, and the repository architecture graph as the evidence boundaries; application repositories, adapters, and migrations remain outside the artifact and its verification fixtures.
- Architecture seam: D-001, D-002

### A-020 — Partial-update stale-handle rejection
- Verifies: D-003/temporal, I-002
- Claim: After a successful callback, an escaping callback failure, or rejection of a callback-returned `Future`, every captured `CanvasEdit` handle rejects both `updatePalette` and `updateGrid` with `StateError` before backing access, merge, or validation and delivers no observable change.
- Failure: Either new operation succeeds or reaches value validation through a stale handle, returns a different public failure, mutates committed appearance, advances a revision, invalidates or builds projection, repaints, emits an event/action, or publishes public state.
- Oracle: Extend the owning exhaustive stale-handle fixture to invoke both new methods with valid DTOs through handles captured from each closure path and require `StateError` plus unchanged committed appearance, revisions, projection identity/build count, repaint, events/actions, and public state. For `updateGrid`, also use a DTO that is constructor-valid but would become invalid against the prior enabled/cell-size state, proving stale rejection precedes merged-value validation; for `updatePalette`, use a bounded audit of the public edit-entry boundary to prove the same guard-before-backing/merge ordering because no constructor-valid context-dependent invalid palette witness exists.
- Proxy risk: Testing only one method, one callback closure path, or only the exception type can miss a bypass in the other entry or mutation/effect leakage before rejection.
- Evidence constraints: Exercise the real public edit entries and established lifecycle fixture; do not assert a private guard helper name or replace direct calls with source scanning.
- Architecture seam: D-003

### A-021 — Single Store candidate, journal, and publication
- Verifies: R-019, D-001/source_of_truth, D-003/order, D-003/atomicity, I-002
- Claim: Partial palette/grid updates introduce no second Store candidate, journal, or mutation family: each successful changed sparse call appends one existing complete-value `StoreSparseMutation`, promotion replays the sole journal exhaustively, final facts derive from owners, and accepted Store work publishes at most one immutable aggregate.
- Failure: A partial call uses a parallel candidate or journal, appends both partial and complete mutations, adds a partial Store replay family, is lost or duplicated during promotion, derives acceptance from mutation history, or publishes more than one aggregate.
- Oracle: Exercise distinguishable sparse partial sequences with and without later explicit promotion, observe the stable Store candidate/journal/replay owner events and aggregate publication boundary, and compare final owner-derived facts with the equivalent whole-value route while requiring one existing mutation admission per changed sparse call and zero-or-one aggregate publication.
- Proxy risk: Final document equality alone cannot reveal duplicate journal admission, a parallel candidate, non-exhaustive replay, mutation-history truth, or intermediate aggregate publication.
- Evidence constraints: Use the established `StoreSparseMutation` contract and stable owner-event/publication observations; do not infer correctness from helper names, source grep, or a copied mutation inventory.
- Architecture seam: D-001, D-003

## Stop Conditions

### H-002 — An updateable value becomes nullable
- Trigger: Any current or new palette/grid field admitted to these DTOs must support null as a real stored value rather than only as absence.
- Invalidates: D-003, A-005
- Resolution requires: Define and approve an explicit tri-state field contract and its compatibility/migration semantics before extending either update DTO.

### H-003 — Document-structural snapshot scope expands
- Trigger: The engine contract must add metadata, layers, elements, or resources to `CanvasAppearance`.
- Invalidates: D-002, D-004, I-001, I-002, A-002, A-003, A-018
- Resolution requires: Re-enter architecture to select the new coherence and projection boundary, materialization/work guarantee, lifecycle, and verification seams rather than widening the lightweight appearance DTO locally.

### H-004 — Direct edit implementers must remain source-compatible
- Trigger: Release policy or a supported external-implementer commitment requires existing direct `CanvasEdit` implementations to compile unchanged after the new operations ship.
- Invalidates: D-004, I-001, A-010, A-012
- Resolution requires: Select and approve a different public compatibility form or versioned migration contract; do not add an extension fallback that reads a full draft or a runtime capability cast under this design.

### H-005 — Active-edit reads must expose draft appearance
- Trigger: `readAppearance` is required to return sparse or materialized draft intermediates while an edit callback is active instead of the last installed committed appearance.
- Invalidates: D-001, D-002, I-001, I-002, A-002, A-003, A-004, A-013, A-014
- Resolution requires: Define a separate draft-read owner and coherence/materialization contract, including stale-handle, rollback, and sequential visibility semantics, before changing the runtime read.

### H-006 — Application-domain state enters the appearance contract
- Trigger: `CanvasAppearance` must include an application-domain value or type in its public snapshot.
- Invalidates: D-001, D-002, I-001, I-002, A-002, A-014, A-015, A-019
- Resolution requires: Re-enter architecture to define the cross-boundary owner, dependency direction, coherence semantics, terminology, and verification authority; do not widen this engine-only snapshot locally.

### H-007 — Runtime-local state enters the appearance snapshot
- Trigger: The engine contract must add camera or selection state to `CanvasAppearance`.
- Invalidates: D-001, D-002, D-004, I-001, I-002, A-002, A-014, A-015, A-018
- Resolution requires: Re-enter architecture to define the cross-owner coherence point, dependency direction, lifecycle, and verification authority for runtime-local state before changing the snapshot.

## Contract Interface

- Profile: `BEHAVIOR_CHANGE`
- Obligations: `SEAM_MIGRATION`, `PUBLIC_API_CHANGE`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `NEGATIVE_PROOF_AND_FIXTURE_QUARANTINE`, `TEMPORAL_SURFACE_CLOSURE`, `ALL_OR_NOTHING_FAILURE_BOUNDARY`, `SOURCE_OF_TRUTH_SINGULARITY`, `WORK_BUDGET_CLOSURE`
- ADR Impact: none
- Sources: S-001, S-002, S-003, S-004, S-005, S-006, S-007, S-008, S-009, S-010, S-011, S-012, S-013, S-014, S-015, S-016, S-017, S-018, S-019, S-020, S-021, S-022, S-023, S-024, S-025, S-026, S-027, S-028, S-029, S-030
- Requirements: R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-008, R-009, R-010, R-011, R-012, R-013, R-014, R-015, R-016, R-017, R-018, R-019, R-020, R-021, R-022
- Commitments: D-001, D-002, D-003, D-004
- Assurance: A-001, A-002, A-003, A-004, A-005, A-006, A-007, A-008, A-009, A-010, A-011, A-012, A-013, A-014, A-015, A-016, A-017, A-018, A-019, A-020, A-021
- Impacts: I-001, I-002
- Stops: H-002, H-003, H-004, H-005, H-006, H-007

## Diagrams

None: D-001, D-002, and D-003 already make the committed-read path, transaction-local merge path, and irreversible installation boundary explicit; a diagram would duplicate rather than clarify the decision graph.

## Readiness Matrix

### Architecture Closure

| Concern | Status | Support refs |
| --- | --- | --- |
| owner | closed | D-001 |
| in_scope | closed | D-001, A-001 |
| out_of_scope | closed | D-001, D-002, A-014, A-018, A-019 |
| source_of_truth | closed | D-001, A-003, A-015, A-021 |
| compatibility | closed | R-020, D-002, D-004, A-010, A-012, A-017 |
| order | closed | D-003, A-006, A-021 |
| policy | closed | D-003, A-005, A-009 |
| dependency | closed | D-001, A-014 |
| state_data | closed | D-002, D-003, A-002, A-005, A-006, A-011, A-016 |
| migration_retirement | closed | R-020, D-004, A-012, I-001, H-004 |
| temporal | closed | D-002, D-003, A-004, A-007, A-008, A-020, H-005 |
| atomicity | closed | D-003, A-007, A-008, A-021 |
| negative_proof_fixture | closed | D-004, A-012, A-018 |
| recognition | not_applicable | E-024, E-030 |

### Gate Closure

| Gate | Status | Support refs |
| --- | --- | --- |
| Owner-Level Fix | pass | R-001, D-001, D-002, D-003, A-003, A-015, A-021, E-008, E-010, E-011, E-041 |
| Ownership | pass | D-001, D-002, D-003, A-015 |
| Source-Of-Truth Singularity | pass | D-001, A-003, A-015, A-021 |
| Source-Truth Minimality | pass | D-001, F-001, M-018, M-019, M-021, A-015, A-021, E-041 |
| Boundary-Owned Policy | pass | D-003, A-005, A-008, A-009 |
| Dependency Direction | pass | D-001, A-014, E-019, E-032, E-033, E-040 |
| Solution Proportionality | pass | F-001, F-002, F-003, M-001, M-002, M-003, M-004, M-005, M-006, M-007, M-008, M-009, M-010, M-011, M-012, M-013, M-014, M-015, M-016, M-017, M-018, M-019, M-020, M-021, M-022, M-023, M-024, R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-008, R-009, R-010, R-011, R-012, R-013, R-014, R-015, R-016, R-017, E-011, E-012, E-013, E-017, E-029, E-034, E-035, E-041, R-018, R-019, R-020, R-021, R-022 |
| Outcome-Proof Fit | pass | A-001, A-002, A-003 |
| Verification | pass | A-001, A-002, A-003, A-004, A-005, A-006, A-007, A-008, A-009, A-010, A-011, A-012, A-013, A-014, A-015, A-016, A-017, A-018, A-019, A-020, A-021 |
| Future Pressure | pass | P-002, P-003, P-004, H-002, H-003, H-006, H-007 |
| Handoff Consumability | pass | CONTRACT, H-002, H-003, H-004, H-005, H-006, H-007 |
| Negative Proof And Fixture Quarantine | pass | D-004, A-012, A-018 |
| State/Data Ownership | pass | D-002, D-003, A-002, A-005, A-006, A-011, A-016 |
| Sequenced Migration And Retirement | pass | D-004, A-012, I-001, H-004 |
| Temporal Surface Closure | pass | D-002, D-003, A-004, A-007, A-008, A-020, H-005 |
| All-Or-Nothing Failure Boundary | pass | D-003, A-007, A-008, A-021 |
| Bounded Recognition Scope | not_applicable | E-024, E-030 |

## Open Blockers

None
