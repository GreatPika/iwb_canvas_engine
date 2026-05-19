<!-- CONTEXT:BEGIN -->
Registry id: `section_22_guardrails_machine_checks`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/guardrails.md`
Owns:
- 22. Guardrails and machine checks
Must read before editing:
- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
- `section_03_package_layout` -> `docs/architecture/02_package_boundaries.md`
Feeds phases:
- `P0`
- `P14`
Related donors:
- `tooling_schema_family_parity`
Related diagrams:
- `none`
Required tests:
- `test.api_contract.app_next_engine_adapter_compile_fixture`
- `test.guardrails.blocking_suite`
Guardrails:
- `oracle.legacy_capability_inventory_complete`
- `api.functional_ledger_complete`
- `api.integration_surface_complete`
- `api.v1_scope_gate_green_before_freeze`
- `api.no_legacy_public_types`
- `api.public_exports_complete`
- `api.public_types_complete`
- `api.public_api_compiles_as_written`
- `api.resource_source_app_key_publicly_readable`
- `api.preview_state_sealed_union_publicly_readable`
- `api.exported_dartdoc_complete`
- `api.public_class_modifiers_explicit`
- `api.public_signature_shape`
- `api.no_undefined_public_type_references`
- `api.dto_immutability`
- `api.equality_policy_explicit`
- `api.id_validation_no_extension_type_escape`
- `core.no_legacy_imports`
- `core.import_boundaries`
- `core.no_unapproved_part_files`
- `core.no_scene_controller_shape_dependency`
- `core.no_node_spec_patch_shape_dependency`
- `core.single_runtime_root`
- `store.no_public_document_live_state`
- `selection.owner_separate_from_document`
- `projection.only_explicit_read_paths`
- `edit.sync_non_nested`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
- `edit.operation_matrix_complete`
- `edit.no_global_invalidation_except_replacement`
- `edit.typed_effects_no_frame_dependency`
- `events.low_level_edit_no_user_actions`
- `events.commands_emit_user_actions`
- `events.runtime_created_timestamps_monotonic`
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`
- `preview.selected_move_main_repaint`
- `interaction.no_concrete_store_imports`
- `interaction.no_concrete_selection_imports`
- `interaction.no_resolver_on_cancel_paths`
- `interaction.no_stale_terminal_commit`
- `interaction.text_edit_stale_commit_guard`
- `geometry.no_legacy_scene_order`
- `geometry.eraser_exact_budget_no_partial`
- `spatial.no_full_clone_ordinary_edit`
- `spatial.stale_candidate_rejected`
- `spatial.fallback_budget_enforced`
- `frame.no_global_scene_sort`
- `frame.paint_plan_excludes_preview_delta`
- `frame.paint_plan_excludes_selection_state`
- `cache.keys_use_next_revisions_only`
- `cache.background_grid_not_element_visual`
- `cache.hot_caches_have_capacity_eviction`
- `resources.mutation_inside_edit_only`
- `resources.dirty_no_document_revision`
- `resources.app_key_only`
- `resources.resolver_boundary_owned_by_surface_session`
- `resources.resolver_frame_budget`
- `resources.no_same_frame_missing_retry`
- `resources.resolver_reentrancy_rejected`
- `codec.schema_v1_exact`
- `codec.known_fields_validated`
- `codec.no_runtime_side_effects`
- `diagnostics.disabled_no_alloc_hot_path`
- `diagnostics.sanitized_public_projection`
- `surface.pointer_samples_normalized_before_runtime`
- `surface.interactive_false_pending_line_preserved`
- `diagrams.all_required_present`
Do not assume:
- no non-blocking critical guardrail
<!-- CONTEXT:END -->

## 22. Guardrails and machine checks

### Guardrail runner contract

Guardrails are blocking architecture and release rules. They must be executable
through one project-owned entrypoint so developers and CI do not need to
remember individual proof commands.

The primary entrypoint is:

```bash
dart run tool/guardrails/run.dart
```

A run without arguments executes the full blocking guardrail suite. The runner
is a thin dispatcher over existing proof commands, such as Dart tests and
tool-owned structural checks. It must not become a second test framework or a
second source of truth for required guardrails.

The runner must support these selection modes:

```bash
dart run tool/guardrails/run.dart --suite=api
dart run tool/guardrails/run.dart --guardrail=core.import_boundaries
dart run tool/guardrails/run.dart --changed
```

`--suite=<name>` runs a named guardrail group. `--guardrail=<id>` runs one
guardrail id from the registry. `--changed` maps changed paths to guardrail ids
using runner-owned impact metadata. Changed-aware routing is conservative: if a
changed path cannot be mapped with confidence, the runner must widen the run to
the full blocking suite instead of silently skipping a required proof.

Runner metadata may live under `tool/guardrails/**`, but mandatory guardrail ids
come from `docs/_registry/sections.yaml` and this section. If runner metadata
omits a mandatory guardrail, `test.guardrails.blocking_suite` must fail.

Design guidance for implementing or rewriting individual guardrails lives in
`docs/verification/guardrail_design_patterns.md`. Each mandatory guardrail must
choose a pattern from that document before executable proof is added, so new
checks reuse the legacy-proven scanner, resolver, sequence, parity, behavior,
and budget patterns instead of inventing bespoke enforcement.

Mandatory guardrails:

| Guardrail id | Rule |
|---|---|
| `oracle.legacy_capability_inventory_complete` | every P1 legacy capability inventory row has a legacy oracle and evidence focus, without requiring next API mapping |
| `api.functional_ledger_complete` | every legacy capability inventory row has a matching functional ledger API mapping and row-specific test |
| `api.integration_surface_complete` | external app-adapter compile fixture imports only the public barrel and proves the public surface is enough for app-level `NextEngineAdapter` responsibilities, while the adapter itself is not in package |
| `api.v1_scope_gate_green_before_freeze` | P1.5 scope gate passed before public API freeze starts |
| `api.no_legacy_public_types` | legacy public golden symbols not exported by root package |
| `api.public_exports_complete` | all public names listed in `docs/_registry/public_api_v1.yaml` are exported by the root package public barrel |
| `api.public_types_complete` | all public signatures reference defined public types |
| `api.public_api_compiles_as_written` | public API declarations compile in an empty consumer package, including `CanvasRuntime.state` and exported runtime state snapshot types while excluding retired document/preview listener getters |
| `api.resource_source_app_key_publicly_readable` | external resolver code can read `CanvasAppKeyResourceSource.key` from `CanvasImageResource.source` through the public barrel only |
| `api.preview_state_sealed_union_publicly_readable` | external preview consumers can type-test exported sealed CanvasPreviewState variants and read variant payloads through the public barrel only |
| `api.exported_dartdoc_complete` | exported public declarations have non-empty Dart documentation summaries before API freeze |
| `api.public_class_modifiers_explicit` | every exported public class chooses an explicit Dart 3 subtype/implementation policy |
| `api.public_signature_shape` | public signatures avoid `FutureOr`, nullable async/container returns, and `dynamic` outside approved JSON or diagnostic boundaries; metadata-bearing DTO signatures use exported `CanvasMetadata` |
| `api.no_undefined_public_type_references` | every exported signature type is exported or from Flutter/Dart SDK |
| `api.dto_immutability` | DTO collections are defensively copied and unmodifiable; `CanvasMetadata` is deep-frozen; public constructors with caller-provided validated or sanitized values are non-const factories while marker/empty/default/private storage forms keep only approved const forms |
| `api.equality_policy_explicit` | public value equality is explicit for concrete public classes, including runtime state snapshot types, and covered by API contract tests |
| `api.id_validation_no_extension_type_escape` | ids cannot be publicly constructed without validation |
| `core.no_legacy_imports` | no import of legacy package/runtime |
| `core.import_boundaries` | package-owned source paths obey source boundary rules and the forbidden import matrix from `section_03_package_layout` |
| `core.no_unapproved_part_files` | production code has no `part` or `part of` files unless generated-code use is explicitly approved |
| `core.no_scene_controller_shape_dependency` | no `SceneController` concept in core |
| `core.no_node_spec_patch_shape_dependency` | no legacy NodeSpec/NodePatch/PatchField in core |
| `core.single_runtime_root` | exactly one production RuntimeRoot |
| `store.no_public_document_live_state` | DocumentStoreKernel stores compact committed tables, not a live mutable `CanvasDocument` |
| `selection.owner_separate_from_document` | selected ids and selectionRevision are owned by the internal selection owner, not DocumentStoreKernel, CommittedDocument, CanvasDocument projection, schema v1, or public DTO state |
| `projection.only_explicit_read_paths` | `CanvasDocument` projection is built only by read/encode/test/tool or explicit draft-read paths, never pointer/hit/paint hot paths |
| `edit.sync_non_nested` | nested/async edit rejected |
| `edit.rollback_no_effects` | rollback discards events/repaint/resources/spatial |
| `edit.stale_handle_rejected` | stale edit handle throws |
| `edit.operation_matrix_complete` | every operation matrix row has executable assertions for expanded operation matrix dimensions: touched state, public state revisions, internal revisions, spatial, projection, resource effects, repaint, user-action events, no-op behavior, and rollback behavior |
| `edit.no_global_invalidation_except_replacement` | ordinary edits compile exact touched invalidation; only document replacement may use global invalidation |
| `edit.typed_effects_no_frame_dependency` | CommitCompiler produces typed effects and does not depend on concrete FrameEngine |
| `events.low_level_edit_no_user_actions` | CanvasEdit.removeElement/clearContent emit no user action events |
| `events.commands_emit_user_actions` | high-level commands and interaction commits own user action events |
| `events.runtime_created_timestamps_monotonic` | runtime-created `timestampMs` outputs resolve nullable hints through one runtime-local monotonic cursor, including action events, text edit requests, pending line start previews, and selected move resolver requests |
| `load.prepares_before_interrupt` | failed load does not interrupt gesture |
| `load.success_interrupts_before_install` | success interrupt happens before atomic install |
| `preview.selected_move_main_repaint` | selected move preview increments main repaint, not overlay |
| `interaction.no_concrete_store_imports` | InteractionEngine uses EditKernel and narrow read-only query ports, not concrete store imports or mutations |
| `interaction.no_concrete_selection_imports` | InteractionEngine uses intent-specific selection query ports and EditKernel commits, not concrete SelectionKernel imports or mutations |
| `interaction.no_resolver_on_cancel_paths` | selected-move resolver is not called on cancel, load, mode-change, `interactive=false`, stale terminal, or dispose paths |
| `interaction.no_stale_terminal_commit` | stale or controllerEpoch-mismatched terminal samples cannot create commit intent |
| `interaction.text_edit_stale_commit_guard` | request-originated text commits reject unknown, retired, epoch-stale, generation-stale, revision-stale, missing, or non-text targets while allowing unrelated documentRevision changes |
| `geometry.no_legacy_scene_order` | geometry and hit-test policy does not reuse legacy SceneNode traversal or legacy scene order logic |
| `geometry.eraser_exact_budget_no_partial` | eraser exact-check budget exceeded paths produce corridor-only preview or terminal no-op cleanup, never partial erase |
| `spatial.no_full_clone_ordinary_edit` | ordinary spatial updates touch only changed ids/pages; full rebuild is reserved for replacement/load paths |
| `spatial.stale_candidate_rejected` | stale candidate handles are rejected by generation and structuralRevision checks before frame/hit use |
| `spatial.fallback_budget_enforced` | fallback candidate union enforces maxFallbackCandidates, diagnostic counter, and typed budget-exceeded result |
| `frame.no_global_scene_sort` | selected supplement staging merges by orderToken and does not globally sort all scene elements |
| `frame.paint_plan_excludes_preview_delta` | PaintPlanCache stores ordinary committed records only and excludes selectedMoveDelta/previewDelta from keys and values |
| `frame.paint_plan_excludes_selection_state` | PaintPlanCache stores ordinary committed records only and excludes selected ids, selectionRevision, and selection flags from keys and values |
| `cache.keys_use_next_revisions_only` | cache keys use next-owned revision facts and stable inputs, not legacy snapshot shapes |
| `cache.background_grid_not_element_visual` | backgroundRevision/gridRevision changes and runtime view camera changes must not invalidate ordinary element paint plans |
| `cache.hot_caches_have_capacity_eviction` | hot caches declare capacity, eviction policy, invalidation owner, and metric/probe |
| `resources.mutation_inside_edit_only` | resource descriptor mutation only via CanvasEdit |
| `resources.dirty_no_document_revision` | markResourceDirty publishes `state.revisions.resourceVisual` and does not increment `state.revisions.document` |
| `resources.app_key_only` | resource descriptors use appKey only |
| `resources.resolver_boundary_owned_by_surface_session` | painters and frame code never call CanvasResourceResolver directly; SurfaceResourceSession owns resolver access for an active surface |
| `resources.resolver_frame_budget` | SurfaceResourceSession enforces per-frame sync resolver call budget and budget-exceeded placeholders are not cached as null/missing |
| `resources.no_same_frame_missing_retry` | missing/null resource resolve results are suppressed by resolverGeneration, resourceId, and resourceRevision for the frame instead of retried immediately; resolver swap clears suppression state |
| `resources.resolver_reentrancy_rejected` | public runtime mutation from inside CanvasResourceResolver throws StateError without runtime effects |
| `codec.schema_v1_exact` | only schema v1 read/write |
| `codec.known_fields_validated` | known schema v1 fields are validated and canonical encoder writes only v1 fields |
| `codec.no_runtime_side_effects` | schema v1 decode/encode validates and materializes DTOs without mutating runtime or store state |
| `diagnostics.disabled_no_alloc_hot_path` | no record allocation on successful hot path |
| `diagnostics.sanitized_public_projection` | diagnostic details expose only sanitized bounded public data and never runtime objects, images, closures, or full scene dumps |
| `surface.pointer_samples_normalized_before_runtime` | Flutter surface adapters pass only normalized finite pointer samples into runtime routing |
| `surface.interactive_false_pending_line_preserved` | interactive=false cancels active routed pointers, preserves pending line state not owned by an active routed pointer, and does not mutate runtime mode, committed document, selection, or resources |
| `diagrams.all_required_present` | required Mermaid files exist |

`api.integration_surface_complete` is executable only when the guardrail runner
or its delegated proof compiles
`test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart` and
checks that the fixture imports only
`package:iwb_canvas_engine/iwb_canvas_engine.dart`. The fixture must not import
`src/**`, legacy symbols, or internal runtime classes, and it must exercise the
required external adapter operation families from the public API contract.

---
