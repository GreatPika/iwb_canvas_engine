# Guardrail design patterns

This document defines current repository proof patterns for mandatory guardrails. Use it before adding, implementing, or rewriting any
mandatory guardrail from `docs/verification/guardrails.md`.

The mandatory guardrail ids remain owned by `docs/verification/guardrails.md`
and `docs/_registry/sections.yaml`. This document owns the implementation
pattern selection for those ids.

## Design rule

Choose the guardrail pattern from the invariant owner, not from the first
syntax shape that looks easy to scan.

- If the invariant is already encoded in a registry, contract file, or
  manifest, make the guardrail a parity check against that source of truth.
- If the invariant is about import/export/part directives, file placement, or
  simple declaration shape, use parsed AST scans with precise offset diagnostics.
- If the invariant is about exported API identity, type leaks, symbol ownership,
  or indirection that string scans can miss, use analyzer resolution.
- If the invariant is about runtime behavior, sequencing, rollback, cache
  admission, or state publication, prove it at the owning public or internal
  seam with Dart tests, and let the guardrail runner dispatch that proof.
- If the invariant is about statement order inside a method or command, collect
  semantic events first and evaluate the sequence separately from traversal.
- If the invariant is about performance, allocation, budget, or cache capacity,
  require an executable probe, counter, or budget assertion rather than prose.

The runner stays a dispatcher. Shared scanners, manifests, and impact metadata
may live under `tool/guardrails/**`; cross-cutting integration with normal test
and CI stays under `test/guardrails/**`.

## Assessment method

Assign a pattern by writing the invariant passport first:

- invariant owner: the document, registry, runtime seam, analyzer, or subsystem
  that owns the rule once;
- accepted source of truth: the table, contract, API inventory, diagram
  catalog, runtime behavior, or code boundary the guardrail must prove;
- bypasses: the ways a weaker check can go green while the invariant is broken;
- primary pattern: the cheapest pattern that proves the owner-level invariant;
- secondary patterns: only the extra checks needed to close aliases,
  indirection, runtime behavior, declaration shape, budgets, or runner coverage.

The confidence labels mean:

- `strong repository precedent`: the repository research contains the same failure class
  and the same effective pattern family.
- `derived from repository pattern`: the repository pattern is proven, but the exact
  current invariant, owner, or seam is different.
- `owner-based repository pattern`: the pattern is selected by owner and bypass
  analysis, but there is no direct existing repository analog; re-check it when implementing
  the executable guardrail.

The pattern map is therefore a design starting point with explicit confidence,
not a claim that every future executable rule has already been proven by current repository checks.

## Repository proof patterns

| Pattern id | Pattern | Use when | Implementation shape | Evidence note |
|---|---|---|---|---|
| `runner_inventory` | Fixed inventory plus fail-fast dispatcher | A guardrail must be mandatory, selectable, and included in the full suite | One metadata-bearing rule inventory, runner selection by id/suite, and a blocking-suite proof that inventory and executable entries match | Current guardrail runner pattern |
| `registry_parity` | Source-of-truth parity | The accepted rule is already listed in a registry, contract, or public API inventory | Compare structured docs or manifests with generated/public facts; fail on missing, stale, or extra entries | Current registry parity pattern |
| `parsed_ast_directive` | Parsed AST directive and declaration scan | The rule depends on imports, exports, parts, directives, comments, or shallow declarations | Use analyzer parsed units, directive nodes, visitors, offsets, and line mapping; avoid string-only scans | Current analyzer directive pattern |
| `resolved_element_identity` | Resolver-backed ownership and identity | The rule must distinguish the actual referenced symbol, owner, accessor, constructor, or source path | Use resolved units/libraries, analyzer elements, repo-relative source paths, and element-backed diagnostics | Current resolver-backed identity pattern |
| `resolved_public_surface` | Resolved public surface and signature traversal | The rule protects exported API shape or rejects type leaks hidden behind aliases/generics/functions/records | Collect the effective exported namespace, sort elements deterministically, traverse `DartType` shapes with caller-owned classifiers | Current public surface traversal pattern |
| `semantic_sequence` | Semantic event sequence | The rule protects command/body ordering, prelude shape, guard-before-route behavior, or forbidden terminal flow | Traverse once, emit typed events, then evaluate the ordering policy independent of AST traversal | Current event-sequence pattern |
| `behavioral_seam_test` | Owner-seam behavioral proof | The invariant is observable behavior, state publication, rollback, rejection, cache admission, or user action emission | Write the proof at the narrow owning seam; the guardrail runner dispatches the test instead of reimplementing behavior checks | Current owner-seam test pattern |
| `effect_matrix` | Matrix-backed exhaustiveness | A rule must cover every operation/effect combination and reject incomplete rows | Keep the operation/effect source of truth explicit and assert coverage, no-op behavior, rollback behavior, and dependency exclusions | Current effect-matrix pattern |
| `budget_probe` | Budget, capacity, and allocation probe | The rule is about max work, cache size, allocation, retry suppression, or hot-path cost | Use executable counters, cache metadata assertions, allocation probes, or budget-exceeded result tests | Current budget probe pattern |
| `forbidden_shape` | Forbidden-shape rejection | A current-package rule must prevent forbidden concepts from reappearing under forbidden names or imports | Combine parsed directive scans, resolved identity checks, and public-symbol deny lists; prefer resolver-backed proof when aliases or re-exports can hide the forbidden shape | Current forbidden-shape pattern |

## Mandatory guardrail pattern map

The primary pattern is the default implementation strategy. Secondary patterns
are required only when the primary proof would otherwise miss aliases,
indirection, runtime behavior, or runner coverage.

| Guardrail id | Primary pattern | Secondary pattern | Confidence | Design note |
|---|---|---|---|---|
| `api.integration_surface_complete` | `behavioral_seam_test` | `parsed_ast_directive`, `runner_inventory` | `derived from repository pattern` | Compile the external app fixture and AST-check that it imports only the public barrel. |
| `api.public_exports_complete` | `registry_parity` | `resolved_public_surface` | `strong repository precedent` | Compare `public_api_v1.yaml` names with the resolved root public exports. |
| `api.facades_do_not_export_internal` | `resolved_public_surface` | `behavioral_seam_test` | `owner-based repository pattern` | Resolve every `lib/src/api/**` facade export and reject any exported declaration marked `@internal`, with a negative fixture proving broad facade exports are caught. |
| `api.public_types_complete` | `resolved_public_surface` | `registry_parity` | `strong repository precedent` | Resolve exported signatures and verify every referenced public type exists in the accepted inventory. |
| `api.public_api_compiles_as_written` | `behavioral_seam_test` | `resolved_public_surface` | `derived from repository pattern` | Compile the public declarations in an empty consumer package and keep signature checks resolver-backed. |
| `api.resource_source_app_key_publicly_readable` | `behavioral_seam_test` | `resolved_public_surface` | `owner-based repository pattern` | Prove an external consumer can read the value through exported public types only. |
| `api.preview_state_sealed_union_publicly_readable` | `behavioral_seam_test` | `resolved_public_surface` | `owner-based repository pattern` | Prove public type tests and payload reads through the public barrel only. |
| `api.exported_dartdoc_complete` | `parsed_ast_directive` | `resolved_public_surface` | `derived from repository pattern` | Walk exported declarations and require non-empty public documentation summaries. |
| `api.public_class_modifiers_explicit` | `parsed_ast_directive` | `resolved_public_surface` | `derived from repository pattern` | Walk exported class declarations and require explicit Dart subtype policy. |
| `api.no_public_api_import_cycles` | `parsed_ast_directive` | `runner_inventory` | `owner-based repository pattern` | Parse public API import directives, resolve relative and same-package imports, and reject SCC cycles with stable diagnostics. |
| `api.public_signature_shape` | `resolved_public_surface` | `registry_parity` | `strong repository precedent` | Traverse exported signature types, aliases, generics, functions, and records with classifier callbacks. |
| `api.no_undefined_public_type_references` | `resolved_public_surface` | `registry_parity` | `strong repository precedent` | Resolve signature references and classify them as exported, SDK/Flutter, or violation. |
| `api.dto_immutability` | `behavioral_seam_test` | `resolved_public_surface`, `parsed_ast_directive` | `derived from repository pattern` | Prove constructor/getter behavior, exported shape constraints, and const/factory declaration policy. |
| `api.equality_policy_explicit` | `behavioral_seam_test` | `registry_parity` | `derived from repository pattern` | Prove equality semantics for concrete public values and compare required coverage with the public inventory. |
| `api.id_validation_no_extension_type_escape` | `behavioral_seam_test` | `resolved_public_surface`, `parsed_ast_directive` | `owner-based repository pattern` | Prove invalid construction paths fail and exported declarations do not expose unchecked id construction or public extension-type escape. |
| `core.no_unapproved_external_package_imports` | `parsed_ast_directive` | `forbidden_shape` | `strong repository precedent` | Scan imports and package paths; add forbidden-shape checks when forbidden public/runtime concepts can reappear. |
| `core.import_boundaries` | `parsed_ast_directive` | `resolved_element_identity` | `strong repository precedent` | Start with import matrix scans and use resolver-backed exceptions only for narrow query-port ownership. |
| `core.owner_dag_import_boundaries` | `parsed_ast_directive` | `runner_inventory`, `forbidden_shape` | `owner-based repository pattern` | Keep the selected owner DAG in one table, generate import/export fixtures from it, add positive fixtures for API wrapper exports to `contracts/public/**` and named facade bridges, add negative assertions for implementation-to-api, contracts-to-api, contracts-to-implementation, and other forbidden owner edges, and prove the allowed edge table is acyclic before production scanning. |
| `core.no_unapproved_part_files` | `parsed_ast_directive` | `registry_parity` | `strong repository precedent` | Scan `part`/`part of` directives and compare generated-code exceptions with an explicit approval list. |
| `core.no_unapproved_controller_shape_dependency` | `forbidden_shape` | `resolved_element_identity` | `derived from repository pattern` | Reject ownership bypasses by public symbol, import, and resolved owner when needed. |
| `core.no_unapproved_patch_shape_dependency` | `forbidden_shape` | `resolved_element_identity` | `derived from repository pattern` | Reject update-owner shape bypasses beyond text-only names. |
| `core.single_runtime_root` | `resolved_element_identity` | `parsed_ast_directive` | `derived from repository pattern` | Resolve production declarations and prove there is exactly one owning runtime root. |
| `store.no_public_document_live_state` | `behavioral_seam_test` | `resolved_element_identity` | `owner-based repository pattern` | Prove store/public projection behavior and block concrete live-state leakage by ownership checks. |
| `selection.owner_separate_from_document` | `resolved_element_identity` | `behavioral_seam_test` | `derived from repository pattern` | Verify ownership boundaries structurally and prove selected-id publication behavior at runtime seams. |
| `projection.only_explicit_read_paths` | `behavioral_seam_test` | `resolved_element_identity`, `parsed_ast_directive` | `owner-based repository pattern` | Prove projection is absent from pointer/hit/paint hot paths and block bypass calls/imports structurally. |
| `edit.sync_non_nested` | `behavioral_seam_test` | `semantic_sequence` | `derived from repository pattern` | Prove nested and async edit rejection at the edit seam; use sequence checks if body ordering becomes shared. |
| `edit.rollback_no_effects` | `behavioral_seam_test` | `effect_matrix` | `derived from repository pattern` | Prove rollback drops every effect family and keep coverage tied to the operation/effect matrix. |
| `edit.stale_handle_rejected` | `behavioral_seam_test` | `semantic_sequence` | `derived from repository pattern` | Prove stale edit handles fail before mutation effects can escape. |
| `edit.operation_matrix_complete` | `effect_matrix` | `registry_parity`, `runner_inventory` | `derived from repository pattern` | Assert every matrix row has proof for all required dimensions and runner inclusion. |
| `edit.no_global_invalidation_except_replacement` | `effect_matrix` | `behavioral_seam_test` | `derived from repository pattern` | Use the operation/effect matrix to distinguish ordinary edits from replacement/load paths. |
| `edit.typed_effects_no_frame_dependency` | `resolved_element_identity` | `effect_matrix` | `strong repository precedent` | Use import/element ownership to block FrameEngine dependency and matrix proof for typed effects. |
| `events.low_level_edit_no_user_actions` | `behavioral_seam_test` | `effect_matrix` | `derived from repository pattern` | Prove low-level edit operations emit no user action events. |
| `events.commands_emit_user_actions` | `behavioral_seam_test` | `semantic_sequence`, `effect_matrix` | `derived from repository pattern` | Prove high-level commands and interaction commits own user action emission, ordering, and matrix coverage. |
| `events.runtime_created_timestamps_monotonic` | `behavioral_seam_test` | `semantic_sequence`, `effect_matrix` | `derived from repository pattern` | Prove runtime-created timestamp outputs resolve nullable and backwards hints through one runtime-local monotonic cursor, and use matrix coverage to keep no-output paths from creating timestamped actions or context requests. |
| `load.prepares_before_interrupt` | `semantic_sequence` | `behavioral_seam_test` | `strong repository precedent` | Model load ordering as events and prove failed load does not interrupt active gesture state. |
| `load.success_interrupts_before_install` | `semantic_sequence` | `behavioral_seam_test` | `strong repository precedent` | Model success ordering as events and prove prepared interaction cleanup happens before install with no post-install interaction owner cleanup call. |
| `preview.selected_move_main_repaint` | `behavioral_seam_test` | `effect_matrix` | `derived from repository pattern` | Prove selected move preview advances the main repaint domain and not the overlay domain. |
| `interaction.no_concrete_store_imports` | `parsed_ast_directive` | `resolved_element_identity` | `strong repository precedent` | Scan imports first and use resolver-backed ownership for narrow query-port exceptions. |
| `interaction.no_concrete_selection_imports` | `parsed_ast_directive` | `resolved_element_identity` | `strong repository precedent` | Scan imports first and resolve concrete selection owner access when indirection could bypass path checks. |
| `interaction.no_resolver_on_cancel_paths` | `semantic_sequence` | `behavioral_seam_test` | `strong repository precedent` | Prove cancel/load/mode/dispose paths cannot reach resolver calls before terminal cleanup. |
| `interaction.no_stale_terminal_commit` | `semantic_sequence` | `behavioral_seam_test` | `strong repository precedent` | Prove stale terminal samples are rejected before commit intent creation. |
| `interaction.pointer_cleanup_coordinator_only` | `resolved_element_identity` | `semantic_sequence`, `behavioral_seam_test` | `owner-based repository pattern` | Prove cleanup-capable tool machines return typed cleanup requests to InteractionEngine, only InteractionEngine calls PointerToolCleanupCoordinator, and coordinator outcome behavior covers repaint target, pending line/context cleanup, no resolver, no stale commit, and no user action emission. |
| `interaction.read_port_immutable_facts` | `parsed_ast_directive` | `behavioral_seam_test` | `owner-based repository pattern` | Derive copied collection obligations from read-port constructor/field shape and require immutable copies for every caller-provided collection, including eraser request/fact lists and future matching fields. |
| `interaction.text_edit_stale_commit_guard` | `semantic_sequence` | `behavioral_seam_test`, `effect_matrix` | `derived from repository pattern` | Prove text commit acceptance is limited to current text content-target context requests; known rejected requests consume live facts without public effects; changed-text commits prepare successfully before consume/remove and consume before public delivery. |
| `geometry.committed_handle_order` | `behavioral_seam_test` | `forbidden_shape` | `derived from repository pattern` | Prove accepted current hit order and keep a forbidden-shape check for scene-order reintroduction. |
| `geometry.eraser_exact_budget_no_partial` | `budget_probe` | `behavioral_seam_test`, `effect_matrix` | `derived from repository pattern` | Use budget-exceeded proof and matrix coverage to reject partial erase behavior and leaked effects. |
| `spatial.no_full_clone_ordinary_edit` | `budget_probe` | `effect_matrix`, `behavioral_seam_test` | `derived from repository pattern` | Prove ordinary spatial updates are touched-id/page bounded and reserve full rebuild for replacement/load. |
| `spatial.stale_candidate_rejected` | `behavioral_seam_test` | `semantic_sequence` | `derived from repository pattern` | Prove generation and structuralRevision checks reject stale candidates before use. |
| `spatial.fallback_budget_enforced` | `budget_probe` | `behavioral_seam_test` | `derived from repository pattern` | Assert fallback candidate limits, non-hub budget counters, and typed budget-exceeded results. |
| `frame.no_global_scene_sort` | `behavioral_seam_test` | `budget_probe`, `forbidden_shape` | `derived from repository pattern` | Prove selected supplement staging merges by orderToken and does not hide a full-scene sort. |
| `frame.paint_plan_excludes_preview_delta` | `behavioral_seam_test` | `effect_matrix` | `derived from repository pattern` | Prove paint-plan keys and values exclude preview deltas. |
| `frame.paint_plan_excludes_selection_state` | `behavioral_seam_test` | `effect_matrix` | `derived from repository pattern` | Prove paint-plan keys and values exclude selected ids, selection revision, and selection flags. |
| `cache.keys_use_next_revisions_only` | `behavioral_seam_test` | `registry_parity`, `forbidden_shape` | `derived from repository pattern` | Prove actual cache keys use current package-owned revision facts, match cache policy rows, and avoid non-owned snapshot shapes. |
| `cache.background_grid_not_element_visual` | `behavioral_seam_test` | `effect_matrix` | `derived from repository pattern` | Prove background/grid/camera changes avoid ordinary element paint-plan invalidation. |
| `cache.hot_caches_have_capacity_eviction` | `registry_parity` | `budget_probe` | `derived from repository pattern` | Require cache-policy rows for capacity, eviction, invalidation owner, and metric/probe, then prove the declared probe runs. |
| `resources.mutation_inside_edit_only` | `resolved_element_identity` | `behavioral_seam_test` | `derived from repository pattern` | Block resource descriptor mutation outside CanvasEdit and prove public attempts route through edit. |
| `resources.dirty_no_document_revision` | `behavioral_seam_test` | `effect_matrix` | `derived from repository pattern` | Prove markResourceDirty and markAllResourcesDirty change resource visual revision for accepted calls, leave missing/empty calls as no-ops, and do not change document revision. |
| `resources.app_key_only` | `resolved_public_surface` | `registry_parity`, `behavioral_seam_test`, `forbidden_shape` | `strong repository precedent` | Prove the public source union exposes only app-key resources, schema/docs agree, behavior rejects other sources, and no hidden engine IO shape returns. |
| `resources.resolver_boundary_owned_by_surface_session` | `resolved_element_identity` | `behavioral_seam_test` | `derived from repository pattern` | Block typed CanvasResourceResolver ownership in painters, frame code, and resource code outside SurfaceResourceSession, then prove SurfaceResourceSession behavior. |
| `resources.resolver_frame_budget` | `budget_probe` | `behavioral_seam_test`, `registry_parity` | `derived from repository pattern` | Assert per-frame sync call budget, cache-policy row coverage, and non-cached budget-exceeded placeholders. |
| `resources.no_same_frame_missing_retry` | `behavioral_seam_test` | `semantic_sequence`, `budget_probe` | `derived from repository pattern` | Prove null-result suppression by generation, resourceId, and resourceRevision within a frame, with missing descriptors and absent resolvers staying bounded without resolver calls. |
| `resources.resolver_reentrancy_rejected` | `behavioral_seam_test` | `semantic_sequence` | `derived from repository pattern` | Prove public mutation inside resolver throws without runtime effects. |
| `codec.schema_v1_exact` | `registry_parity` | `behavioral_seam_test` | `derived from repository pattern` | Compare codec entrypoints and schema constants with v1-only contract and prove no alternate version path. |
| `codec.known_fields_validated` | `behavioral_seam_test` | `registry_parity` | `derived from repository pattern` | Prove known fields validate and canonical encoder writes only accepted fields. |
| `codec.no_runtime_side_effects` | `behavioral_seam_test` | `resolved_element_identity` | `derived from repository pattern` | Prove encode/decode do not mutate runtime/store and block codec imports of mutation owners. |
| `diagnostics.disabled_no_alloc_hot_path` | `budget_probe` | `behavioral_seam_test` | `derived from repository pattern` | Use allocation/probe proof for the currently implemented owner; schema/codec success paths are covered now, and pointer/paint hot paths must add proof when those runtime owners exist. |
| `diagnostics.sanitized_public_projection` | `behavioral_seam_test` | `registry_parity`, `resolved_public_surface` | `derived from repository pattern` | Prove details are bounded public data, select explicitly classified diagnostics-facing public declarations from `diagnostics_public_surface`, and traverse resolved public signatures so classifier-owned runtime-like types cannot bypass the guard through non-prefix names. |
| `surface.pointer_samples_normalized_before_runtime` | `semantic_sequence` | `behavioral_seam_test` | `strong repository precedent` | Prove the Flutter boundary normalizes finite samples before runtime routing. |
| `surface.interactive_false_pending_line_preserved` | `semantic_sequence` | `behavioral_seam_test` | `derived from repository pattern` | Prove interactive=false cancellation order and pending-line preservation. |
