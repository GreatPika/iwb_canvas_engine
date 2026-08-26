<!-- CONTEXT:BEGIN -->
Registry id: `section_27_final_release_gates`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/release_gates.md`
Owns:
- 27. Final release gates
Must read before editing:
- `section_22_guardrails_machine_checks` -> `docs/verification/guardrails.md`
- `section_23_tests` -> `docs/verification/tests.md`
Current owners:
- `release`
Related diagrams:
- `none`
Required tests:
- `test.api_contract.public_integration_compile_fixture`
- `test.guardrails.frame_committed_facts_via_frame_facts_port`
- `test.guardrails.blocking_suite`
Guardrails:
- `api.integration_surface_complete`
- `api.public_exports_complete`
- `api.facades_do_not_export_internal`
- `api.public_types_complete`
- `api.public_api_compiles_as_written`
- `api.resource_source_app_key_publicly_readable`
- `api.preview_state_sealed_union_publicly_readable`
- `api.exported_dartdoc_complete`
- `api.public_class_modifiers_explicit`
- `api.no_public_api_import_cycles`
- `api.public_signature_shape`
- `api.no_undefined_public_type_references`
- `api.no_public_internal_load_types`
- `api.no_unapproved_document_load_inputs`
- `api.dto_immutability`
- `api.equality_policy_explicit`
- `api.id_validation_no_extension_type_escape`
- `core.no_unapproved_external_package_imports`
- `core.import_boundaries`
- `core.no_unapproved_part_files`
- `core.no_unapproved_controller_shape_dependency`
- `core.no_unapproved_patch_shape_dependency`
- `core.single_runtime_root`
- `store.no_public_document_live_state`
- `selection.owner_separate_from_document`
- `projection.only_explicit_read_paths`
- `edit.sync_non_nested`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
- `edit.no_global_invalidation_except_replacement`
- `edit.typed_effects_no_frame_dependency`
- `events.low_level_edit_no_user_actions`
- `events.commands_emit_user_actions`
- `events.action_after_state_order`
- `events.runtime_created_timestamps_monotonic`
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`
- `preview.selected_move_main_only`
- `preview.marquee_overlay_only`
- `interaction.no_concrete_store_imports`
- `interaction.no_concrete_selection_imports`
- `interaction.read_port_immutable_facts`
- `interaction.no_command_facts_import`
- `interaction.cleanup_coordinator_dependency_bans`
- `interaction.no_resolver_on_cancel_paths`
- `interaction.no_stale_terminal_commit`
- `interaction.pointer_cleanup_coordinator_only`
- `geometry.committed_handle_order`
- `geometry.eraser_exact_budget_no_partial`
- `spatial.no_full_clone_ordinary_edit`
- `spatial.stale_candidate_rejected`
- `spatial.fallback_budget_enforced`
- `frame.committed_facts_via_frame_facts_port`
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
- `tools.public_port_behavior`
- `surface.pointer_samples_normalized_before_runtime`
- `surface.interactive_false_pending_line_preserved`
Do not assume:
- no release with blocked imports, private facades, or unproved behavior
<!-- CONTEXT:END -->

## 27. Final release gates

Release is blocked unless all statements are true:

For current-closure work, graph-checkable architecture obligations are checked by
the standalone current commands:

```bash
dart run tool/architecture_graph/check.dart
dart run tool/architecture_graph/generate_views.dart --check
```

A non-zero current graph-closure or generated-view result is a blocking
release-gate failure for the current graph. Repair the implementation or update
the accepted current graph obligations before continuing dependent architecture
work.

```text
1. Public API, public integration, public internal load type, and validation checks are green.
2. api.public_exports_complete is green.
3. api.facades_do_not_export_internal is green.
4. api.public_types_complete is green.
5. api.public_api_compiles_as_written is green, including the
   `CanvasRuntime.state` surface and exported runtime state snapshot types.
6. public dartdoc, class modifier, public signature shape, and sealed preview
   state readability guardrails are green.
7. core.no_unapproved_external_package_imports is green.
8. core.import_boundaries and core.no_unapproved_part_files are green.
9. core.single_runtime_root is green.
10. store/projection/selection ownership tests are green.
11. schema v1 encode/decode contract is green.
12. codec no-runtime-side-effect tests are green.
13. validation limits are green.
14. diagnostics disabled hot-path allocation and sanitizer tests are green.
15. resource lifecycle, resolver-boundary, and resolver-frame-budget tests are green.
16. edit rollback/stale/nested/async tests are green.
17. operation matrix and exact touched invalidation tests are green, including
    expanded operation matrix dimensions for public state revisions, internal revisions,
    resource effects, no-op behavior, and rollback behavior.
18. loadDocument staged success/failure tests are green.
19. public runtime state publication, load publication, interaction settings state,
    preview public state, and dispose lifecycle tests are green.
20. geometry/spatial committed-order, eraser exact-budget, stale-candidate, and fallback-budget tests are green.
21. frame capture, cache-key, cache-policy, frame-meta, paint-plan,
    runtime-view-camera vs persisted-document-camera separation,
    selection-state cache independence, and selected supplement staging tests are green.
22. selected move preview main repaint test is green.
23. overlay preview repaint split tests are green.
24. direct `handleDoubleTap`, pointer-sample context-action request, and guarded
    text commit integration tests are green.
25. action typed payload tests are green.
26. runtime-created timestamp monotonicity tests are green.
27. low-level edit emits no user action events tests are green.
28. interaction stale terminal, selection-boundary import, resolver-cancel, and interactive=false routing, cancel, pending-line, and state-isolation tests are green.
29. surface single-active-surface, resource-session lifecycle, pointer
    normalization, public surface smoke, and resource-backed paint tests are
    green.
30. DTO immutability, `CanvasMetadata` deep-freeze, validating-constructor
    factory policy, approved const-form policy, and public equality policy tests
    are green, including runtime state snapshot value equality.
31. no CanvasDocument projection in paint/pointer/hit tests are green.
32. all required diagrams exist and match owners.
33. current graph guardrail alignment is green, and generated graph views match
    `docs/architecture/architecture_graph.yaml`.
34. full `dart run tool/guardrails/run.dart` is green.
35. every mandatory guardrail has a runner entry and executable proof, including
    the `api.integration_surface_complete` external app-adapter compile fixture.
36. The Flutter performance verification route is green: the full scenario
    group catalog in `docs/verification/performance.md` completes through
    `cd example && flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/perf_canvas_surface_test.dart --profile --no-dds`,
    and the artifact checker for the active route verifies the required nested
    timeline artifacts, `performance_run_manifest.json`, and
    `comparison_summary.json` for every report key.
37. p95, p99, frame-budget, baseline-diff, and regression threshold gates remain
    unclaimed until a later design and contract establish device, environment,
    repeat-count, artifact-retention, and baseline policy.
38. application canvas port and application adapter names are not present in the engine package.
39. Direct `CanvasSelectionPort` implementations expose `deleteAvailability`,
    and `CanvasSelectionDeletePolicy.partial` remains the default runtime
    configuration policy without a parallel availability state surface.
40. `CanvasRuntime.config` and its non-null deletion resolver remain required
    at the external compile boundary; selection deletion and terminal eraser
    resolver suites prove their distinct public routes, guarded prepare/consume
    behavior, bounded work, and bounded diagnostics.
41. The maintained example is verified separately with
    `cd example && flutter analyze` and `cd example && flutter test`.
```

---
