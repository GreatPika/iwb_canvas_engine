# Guardrail design patterns

This document turns the legacy guardrail research into design guidance for new
engine guardrails. Use it before adding, implementing, or rewriting any
mandatory guardrail from `docs/verification/guardrails.md`.

The mandatory guardrail ids remain owned by `docs/verification/guardrails.md`
and `docs/_registry/sections.yaml`. This document owns the implementation
pattern selection for those ids.

## Design rule

Choose the guardrail pattern from the invariant owner, not from the first
syntax shape that looks easy to scan.

- If the invariant is already encoded in a registry, phase file, or
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

- `strong legacy precedent`: the legacy research contains the same failure class
  and the same effective pattern family.
- `derived from legacy pattern`: the legacy pattern is proven, but the exact
  new-engine invariant, owner, or seam is different.
- `new-engine extrapolation`: the pattern is selected by owner and bypass
  analysis, but there is no direct legacy analog; re-check it when implementing
  the executable guardrail.

The pattern map is therefore a design starting point with explicit confidence,
not a claim that every future executable rule has already been proven in legacy.

## Legacy-proven patterns

| Pattern id | Pattern | Use when | Implementation shape | Legacy evidence |
|---|---|---|---|---|
| `runner_inventory` | Fixed inventory plus fail-fast dispatcher | A guardrail must be mandatory, selectable, and included in the full suite | One metadata-bearing rule inventory, runner selection by id/suite, and a blocking-suite proof that inventory and executable entries match | `.research/2026-05-19-legacy-ast-guardrail-patterns.md` sections 1 and 9 |
| `registry_parity` | Source-of-truth parity | The accepted rule is already listed in a registry, phase, contract, or public API inventory | Compare structured docs or manifests with generated/public facts; fail on missing, stale, or extra entries | `.research/2026-05-19-legacy-ast-guardrail-patterns.md` sections 7 and 9 |
| `parsed_ast_directive` | Parsed AST directive and declaration scan | The rule depends on imports, exports, parts, directives, comments, or shallow declarations | Use analyzer parsed units, directive nodes, visitors, offsets, and line mapping; avoid string-only scans | `.research/2026-05-19-legacy-ast-guardrail-patterns.md` sections 2 and 9 |
| `resolved_element_identity` | Resolver-backed ownership and identity | The rule must distinguish the actual referenced symbol, owner, accessor, constructor, or source path | Use resolved units/libraries, analyzer elements, repo-relative source paths, and element-backed diagnostics | `.research/2026-05-19-legacy-ast-guardrail-patterns.md` sections 3, 4, and 5 |
| `resolved_public_surface` | Resolved public surface and signature traversal | The rule protects exported API shape or rejects type leaks hidden behind aliases/generics/functions/records | Collect the effective exported namespace, sort elements deterministically, traverse `DartType` shapes with caller-owned classifiers | `.research/2026-05-19-legacy-ast-guardrail-patterns.md` sections 7 and 8 |
| `semantic_sequence` | Semantic event sequence | The rule protects command/body ordering, prelude shape, guard-before-route behavior, or forbidden terminal flow | Traverse once, emit typed events, then evaluate the ordering policy independent of AST traversal | `.research/2026-05-19-legacy-ast-guardrail-patterns.md` section 6 |
| `behavioral_seam_test` | Owner-seam behavioral proof | The invariant is observable behavior, state publication, rollback, rejection, cache admission, or user action emission | Write the proof at the narrow owning seam; the guardrail runner dispatches the test instead of reimplementing behavior checks | `.research/2026-05-19-legacy-ast-guardrail-patterns.md` sections 1 and 9 |
| `effect_matrix` | Matrix-backed exhaustiveness | A rule must cover every operation/effect combination and reject incomplete rows | Keep the operation/effect source of truth explicit and assert coverage, no-op behavior, rollback behavior, and dependency exclusions | `.research/2026-05-19-legacy-ast-guardrail-patterns.md` sections 6 and 9 |
| `budget_probe` | Budget, capacity, and allocation probe | The rule is about max work, cache size, allocation, retry suppression, or hot-path cost | Use executable counters, cache metadata assertions, allocation probes, or budget-exceeded result tests | `.research/2026-05-19-legacy-ast-guardrail-patterns.md` section 9 |
| `negative_legacy_shape` | Retired-shape rejection | A new-engine rule must prevent legacy concepts from reappearing under new names or imports | Combine parsed directive scans, resolved identity checks, and public-symbol deny lists; prefer resolver-backed proof when aliases or re-exports can hide the legacy shape | `.research/2026-05-19-legacy-ast-guardrail-patterns.md` sections 3, 7, and 9 |

## Mandatory guardrail pattern map

The primary pattern is the default implementation strategy. Secondary patterns
are required only when the primary proof would otherwise miss aliases,
indirection, runtime behavior, or runner coverage.

| Guardrail id | Primary pattern | Secondary pattern | Confidence | Design note |
|---|---|---|---|---|
| `api.integration_surface_complete` | `behavioral_seam_test` | `parsed_ast_directive`, `runner_inventory` | `derived from legacy pattern` | Compile the external app fixture and AST-check that it imports only the public barrel. |
| `api.no_legacy_public_types` | `negative_legacy_shape` | `resolved_public_surface` | `strong legacy precedent` | Reject legacy exported symbols through the effective public namespace, not just root-barrel text. |
| `api.public_exports_complete` | `registry_parity` | `resolved_public_surface` | `strong legacy precedent` | Compare `public_api_v1.yaml` names with the resolved root public exports. |
| `api.public_types_complete` | `resolved_public_surface` | `registry_parity` | `strong legacy precedent` | Resolve exported signatures and verify every referenced public type exists in the accepted inventory. |
| `api.public_api_compiles_as_written` | `behavioral_seam_test` | `resolved_public_surface` | `derived from legacy pattern` | Compile the public declarations in an empty consumer package and keep signature checks resolver-backed. |
| `api.resource_source_app_key_publicly_readable` | `behavioral_seam_test` | `resolved_public_surface` | `new-engine extrapolation` | Prove an external consumer can read the value through exported public types only. |
| `api.preview_state_sealed_union_publicly_readable` | `behavioral_seam_test` | `resolved_public_surface` | `new-engine extrapolation` | Prove public type tests and payload reads through the public barrel only. |
| `api.exported_dartdoc_complete` | `parsed_ast_directive` | `resolved_public_surface` | `derived from legacy pattern` | Walk exported declarations and require non-empty public documentation summaries. |
| `api.public_class_modifiers_explicit` | `parsed_ast_directive` | `resolved_public_surface` | `derived from legacy pattern` | Walk exported class declarations and require explicit Dart subtype policy. |
| `api.no_public_api_import_cycles` | `parsed_ast_directive` | `runner_inventory` | `new-engine extrapolation` | Parse public API import directives, resolve relative and same-package imports, and reject SCC cycles with stable diagnostics. |
| `api.public_signature_shape` | `resolved_public_surface` | `registry_parity` | `strong legacy precedent` | Traverse exported signature types, aliases, generics, functions, and records with classifier callbacks. |
| `api.no_undefined_public_type_references` | `resolved_public_surface` | `registry_parity` | `strong legacy precedent` | Resolve signature references and classify them as exported, SDK/Flutter, or violation. |
| `api.dto_immutability` | `behavioral_seam_test` | `resolved_public_surface`, `parsed_ast_directive` | `derived from legacy pattern` | Prove constructor/getter behavior, exported shape constraints, and const/factory declaration policy. |
| `api.equality_policy_explicit` | `behavioral_seam_test` | `registry_parity` | `derived from legacy pattern` | Prove equality semantics for concrete public values and compare required coverage with the public inventory. |
| `api.id_validation_no_extension_type_escape` | `behavioral_seam_test` | `resolved_public_surface`, `parsed_ast_directive` | `new-engine extrapolation` | Prove invalid construction paths fail and exported declarations do not expose unchecked id construction or public extension-type escape. |
| `core.no_legacy_imports` | `parsed_ast_directive` | `negative_legacy_shape` | `strong legacy precedent` | Scan imports and package paths; add retired-shape checks when copied legacy public/runtime concepts can reappear. |
| `core.import_boundaries` | `parsed_ast_directive` | `resolved_element_identity` | `strong legacy precedent` | Start with import matrix scans and use resolver-backed exceptions only for narrow query-port ownership. |
| `core.no_unapproved_part_files` | `parsed_ast_directive` | `registry_parity` | `strong legacy precedent` | Scan `part`/`part of` directives and compare generated-code exceptions with an explicit approval list. |
| `core.no_scene_controller_shape_dependency` | `negative_legacy_shape` | `resolved_element_identity` | `derived from legacy pattern` | Reject the legacy controller concept by public symbol, import, and resolved owner when needed. |
| `core.no_node_spec_patch_shape_dependency` | `negative_legacy_shape` | `resolved_element_identity` | `derived from legacy pattern` | Reject legacy NodeSpec/NodePatch/PatchField shapes beyond text-only names. |
| `core.single_runtime_root` | `resolved_element_identity` | `parsed_ast_directive` | `derived from legacy pattern` | Resolve production declarations and prove there is exactly one owning runtime root. |
| `store.no_public_document_live_state` | `behavioral_seam_test` | `resolved_element_identity` | `new-engine extrapolation` | Prove store/public projection behavior and block concrete live-state leakage by ownership checks. |
| `selection.owner_separate_from_document` | `resolved_element_identity` | `behavioral_seam_test` | `derived from legacy pattern` | Verify ownership boundaries structurally and prove selected-id publication behavior at runtime seams. |
| `projection.only_explicit_read_paths` | `behavioral_seam_test` | `resolved_element_identity`, `parsed_ast_directive` | `new-engine extrapolation` | Prove projection is absent from pointer/hit/paint hot paths and block bypass calls/imports structurally. |
| `edit.sync_non_nested` | `behavioral_seam_test` | `semantic_sequence` | `derived from legacy pattern` | Prove nested and async edit rejection at the edit seam; use sequence checks if body ordering becomes shared. |
| `edit.rollback_no_effects` | `behavioral_seam_test` | `effect_matrix` | `derived from legacy pattern` | Prove rollback drops every effect family and keep coverage tied to the operation/effect matrix. |
| `edit.stale_handle_rejected` | `behavioral_seam_test` | `semantic_sequence` | `derived from legacy pattern` | Prove stale edit handles fail before mutation effects can escape. |
| `edit.operation_matrix_complete` | `effect_matrix` | `registry_parity`, `runner_inventory` | `derived from legacy pattern` | Assert every matrix row has proof for all required dimensions and runner inclusion. |
| `edit.no_global_invalidation_except_replacement` | `effect_matrix` | `behavioral_seam_test` | `derived from legacy pattern` | Use the operation/effect matrix to distinguish ordinary edits from replacement/load paths. |
| `edit.typed_effects_no_frame_dependency` | `resolved_element_identity` | `effect_matrix` | `strong legacy precedent` | Use import/element ownership to block FrameEngine dependency and matrix proof for typed effects. |
| `events.low_level_edit_no_user_actions` | `behavioral_seam_test` | `effect_matrix` | `derived from legacy pattern` | Prove low-level edit operations emit no user action events. |
| `events.commands_emit_user_actions` | `behavioral_seam_test` | `semantic_sequence`, `effect_matrix` | `derived from legacy pattern` | Prove high-level commands and interaction commits own user action emission, ordering, and matrix coverage. |
| `events.runtime_created_timestamps_monotonic` | `behavioral_seam_test` | `semantic_sequence`, `effect_matrix` | `derived from legacy pattern` | Prove runtime-created timestamp outputs resolve nullable and backwards hints through one runtime-local monotonic cursor, and use matrix coverage to keep no-output paths from creating timestamped actions or context requests. |
| `load.prepares_before_interrupt` | `semantic_sequence` | `behavioral_seam_test` | `strong legacy precedent` | Model load ordering as events and prove failed load does not interrupt active gesture state. |
| `load.success_interrupts_before_install` | `semantic_sequence` | `behavioral_seam_test` | `strong legacy precedent` | Model success ordering as events and prove interrupt happens before install. |
| `preview.selected_move_main_repaint` | `behavioral_seam_test` | `effect_matrix` | `derived from legacy pattern` | Prove selected move preview advances the main repaint domain and not the overlay domain. |
| `interaction.no_concrete_store_imports` | `parsed_ast_directive` | `resolved_element_identity` | `strong legacy precedent` | Scan imports first and use resolver-backed ownership for narrow query-port exceptions. |
| `interaction.no_concrete_selection_imports` | `parsed_ast_directive` | `resolved_element_identity` | `strong legacy precedent` | Scan imports first and resolve concrete selection owner access when indirection could bypass path checks. |
| `interaction.no_resolver_on_cancel_paths` | `semantic_sequence` | `behavioral_seam_test` | `strong legacy precedent` | Prove cancel/load/mode/dispose paths cannot reach resolver calls before terminal cleanup. |
| `interaction.no_stale_terminal_commit` | `semantic_sequence` | `behavioral_seam_test` | `strong legacy precedent` | Prove stale terminal samples are rejected before commit intent creation. |
| `interaction.pointer_cleanup_coordinator_only` | `resolved_element_identity` | `semantic_sequence`, `behavioral_seam_test` | `new-engine seam migration` | Prove cleanup-capable tool machines return typed cleanup requests to InteractionEngine, only InteractionEngine calls PointerToolCleanupCoordinator, and coordinator outcome behavior covers repaint target, pending line/context cleanup, no resolver, no stale commit, and no user action emission. |
| `interaction.text_edit_stale_commit_guard` | `behavioral_seam_test` | `semantic_sequence`, `effect_matrix` | `derived from legacy pattern` | Prove text commit acceptance is limited to current text content-target context requests, every stale/missing/non-text/empty-canvas request guard, operation-matrix effects, and the allowed unrelated document revision case. |
| `geometry.no_legacy_scene_order` | `behavioral_seam_test` | `negative_legacy_shape` | `derived from legacy pattern` | Prove accepted next-owned hit order and keep a retired-shape check for legacy scene-order reintroduction. |
| `geometry.eraser_exact_budget_no_partial` | `budget_probe` | `behavioral_seam_test`, `effect_matrix` | `derived from legacy pattern` | Use budget-exceeded proof and matrix coverage to reject partial erase behavior and leaked effects. |
| `spatial.no_full_clone_ordinary_edit` | `budget_probe` | `effect_matrix`, `behavioral_seam_test` | `derived from legacy pattern` | Prove ordinary spatial updates are touched-id/page bounded and reserve full rebuild for replacement/load. |
| `spatial.stale_candidate_rejected` | `behavioral_seam_test` | `semantic_sequence` | `derived from legacy pattern` | Prove generation and structuralRevision checks reject stale candidates before use. |
| `spatial.fallback_budget_enforced` | `budget_probe` | `behavioral_seam_test` | `derived from legacy pattern` | Assert fallback candidate limits, diagnostics, and typed budget-exceeded results. |
| `frame.no_global_scene_sort` | `behavioral_seam_test` | `budget_probe`, `negative_legacy_shape` | `derived from legacy pattern` | Prove selected supplement staging merges by orderToken and does not hide a full-scene sort. |
| `frame.paint_plan_excludes_preview_delta` | `behavioral_seam_test` | `effect_matrix` | `derived from legacy pattern` | Prove paint-plan keys and values exclude preview deltas. |
| `frame.paint_plan_excludes_selection_state` | `behavioral_seam_test` | `effect_matrix` | `derived from legacy pattern` | Prove paint-plan keys and values exclude selected ids, selection revision, and selection flags. |
| `cache.keys_use_next_revisions_only` | `behavioral_seam_test` | `registry_parity`, `negative_legacy_shape` | `derived from legacy pattern` | Prove actual cache keys use next-owned revision facts, match cache policy rows, and avoid legacy snapshot shapes. |
| `cache.background_grid_not_element_visual` | `behavioral_seam_test` | `effect_matrix` | `derived from legacy pattern` | Prove background/grid/camera changes avoid ordinary element paint-plan invalidation. |
| `cache.hot_caches_have_capacity_eviction` | `registry_parity` | `budget_probe` | `derived from legacy pattern` | Require cache-policy rows for capacity, eviction, invalidation owner, and metric/probe, then prove the declared probe runs. |
| `resources.mutation_inside_edit_only` | `resolved_element_identity` | `behavioral_seam_test` | `derived from legacy pattern` | Block resource descriptor mutation outside CanvasEdit and prove public attempts route through edit. |
| `resources.dirty_no_document_revision` | `behavioral_seam_test` | `effect_matrix` | `derived from legacy pattern` | Prove markResourceDirty changes resource visual revision and not document revision. |
| `resources.app_key_only` | `resolved_public_surface` | `registry_parity`, `behavioral_seam_test`, `negative_legacy_shape` | `strong legacy precedent` | Prove the public source union exposes only app-key resources, schema/docs agree, behavior rejects other sources, and no hidden engine IO shape returns. |
| `resources.resolver_boundary_owned_by_surface_session` | `resolved_element_identity` | `behavioral_seam_test` | `derived from legacy pattern` | Block direct resolver calls from painters/frame code and prove SurfaceResourceSession ownership. |
| `resources.resolver_frame_budget` | `budget_probe` | `behavioral_seam_test`, `registry_parity` | `derived from legacy pattern` | Assert per-frame sync call budget, cache-policy row coverage, and non-cached budget-exceeded placeholders. |
| `resources.no_same_frame_missing_retry` | `behavioral_seam_test` | `semantic_sequence`, `budget_probe` | `derived from legacy pattern` | Prove missing/null suppression by generation, resourceId, and resourceRevision within a frame. |
| `resources.resolver_reentrancy_rejected` | `behavioral_seam_test` | `semantic_sequence` | `derived from legacy pattern` | Prove public mutation inside resolver throws without runtime effects. |
| `codec.schema_v1_exact` | `registry_parity` | `behavioral_seam_test` | `derived from legacy pattern` | Compare codec entrypoints and schema constants with v1-only contract and prove no alternate version path. |
| `codec.known_fields_validated` | `behavioral_seam_test` | `registry_parity` | `derived from legacy pattern` | Prove known fields validate and canonical encoder writes only accepted fields. |
| `codec.no_runtime_side_effects` | `behavioral_seam_test` | `resolved_element_identity` | `derived from legacy pattern` | Prove encode/decode do not mutate runtime/store and block codec imports of mutation owners. |
| `diagnostics.disabled_no_alloc_hot_path` | `budget_probe` | `behavioral_seam_test` | `derived from legacy pattern` | Use allocation/probe proof for the currently implemented owner; schema/codec success paths are covered now, and pointer/paint hot paths must add proof when those runtime owners exist. |
| `diagnostics.sanitized_public_projection` | `behavioral_seam_test` | `registry_parity`, `resolved_public_surface` | `derived from legacy pattern` | Prove details are bounded public data, select explicitly classified diagnostics-facing public declarations from `diagnostics_public_surface`, and traverse resolved public signatures so classifier-owned runtime-like types cannot bypass the guard through non-prefix names. |
| `surface.pointer_samples_normalized_before_runtime` | `semantic_sequence` | `behavioral_seam_test` | `strong legacy precedent` | Prove the Flutter boundary normalizes finite samples before runtime routing. |
| `surface.interactive_false_pending_line_preserved` | `semantic_sequence` | `behavioral_seam_test` | `derived from legacy pattern` | Prove interactive=false cancellation order and pending-line preservation. |
