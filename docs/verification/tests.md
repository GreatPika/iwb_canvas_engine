<!-- CONTEXT:BEGIN -->
Registry id: `section_23_tests`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/tests.md`
Owns:
- 23. Tests
Must read before editing:
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_22_guardrails_machine_checks` -> `docs/verification/guardrails.md`
Current owners:
- `test`
Benchmarks:
- `none`
Related diagrams:
- `none`
Required tests:
- `test.api_contract.public_readable_union_variants`
- `test.api_contract.preview_state_sealed_union`
- `test.api_contract.public_api_v1_compiles_as_written`
- `test.api_contract.public_exports_complete`
- `test.api_contract.api_facades_do_not_export_internal`
- `test.api_contract.public_api_no_unapproved_placeholders`
- `test.guardrails.public_api_declaration_checks`
- `test.guardrails.public_api_import_cycles`
- `test.api.canvas_transform`
- `test.api.canvas_field_update`
- `test.api_contract.canvas_field_update_static_semantics`
- `test.api_contract.no_undefined_public_type_references`
- `test.api_contract.dto_immutability`
- `test.api_contract.public_equality_policy`
- `test.api_contract.public_integration_compile_fixture`
- `test.guardrails.import_boundaries`
- `test.guardrails.store_projection_checks`
- `test.guardrails.selection_boundary_checks`
- `test.codec.schema_v1.known_fields_validation`
- `test.codec.schema_v1.canonical_encode_roundtrip`
- `test.codec.schema_v1.metadata_projection`
- `test.codec.schema_v1.resources_appkey_only`
- `test.codec.schema_v1.reject_unknown_element_kind`
- `test.codec.schema_v1.reject_unknown_resource_source_kind`
- `test.codec.decode_encode_no_runtime_side_effects`
- `test.guardrails.codec_no_runtime_imports`
- `test.diagnostics.sanitizer_and_public_projection`
- `test.diagnostics.disabled_no_alloc_hot_path`
- `test.diagnostics.diagnostics_public_surface`
- `test.resources.sync_image_resolver`
- `test.resources.app_owned_image_not_disposed`
- `test.resources.resource_dirty`
- `test.resources.mark_all_resources_dirty`
- `test.resources.missing_result_suppressed_per_frame`
- `test.resources.surface_session_cache_lifecycle`
- `test.resources.resolver_swap_starts_fresh_cache`
- `test.resources.resolver_frame_budget`
- `test.resources.resolver_reentrancy_rejected`
- `test.api.selection_port`
- `test.api.selection_transform_commands`
- `test.api.command_port_actions`
- `test.api.tool_port_settings`
- `test.api.typed_action_payloads`
- `test.api.runtime_timestamp_order`
- `test.interaction.runtime_created_timestamps_monotonic`
- `test.runtime.command_facts_port`
- `test.runtime.load_interaction_cleanup`
- `test.edit.low_level_mutations_do_not_emit_actions`
- `test.interaction.commands_emit_user_actions`
- `test.interaction.interaction_declarations`
- `test.interaction.pointer_session`
- `test.interaction.pointer_sample_normalizer`
- `test.interaction.interaction_read_port`
- `test.interaction.context_action_request`
- `test.runtime.text_editing_port`
- `test.surface.text_editing_overlay`
- `test.surface.interactive_false_pointer_routing`
- `test.surface.interactive_false_active_session_cancel`
- `test.surface.interactive_false_pending_line_preserved`
- `test.surface.interactive_false_state_isolation`
- `test.surface.single_active_surface`
- `test.surface.surface_resource_session_lifecycle`
- `test.surface.pointer_adapter_finite_normalization`
- `test.surface.canvas_surface_layout_constraints`
- `test.codec.constructor_and_schema_limits`
- `test.runtime.dispose_lifecycle`
- `test.runtime.runtime_state_publication`
- `test.smoke.public_incremental_smoke`
- `test.runtime.load_document_state_publication`
- `test.store.read_document_projection`
- `test.store.no_projection_hot_path`
- `test.store.public_document_is_projection_only`
- `test.store.store_commit_finalization`
- `test.edit.sync_non_nested_async_stale`
- `test.edit.rollback`
- `test.edit.field_update_admission_effects`
- `test.edit.edit_matrix_effects`
- `test.edit.net_no_op_edit_commit`
- `test.edit.exact_touched_invalidation`
- `test.edit.typed_effects_no_frame_dependency`
- `test.edit.staged_document_load_success_failure`
- `test.spatial.committed_spatial_read_boundary`
- `test.geometry.hit_policy`
- `test.geometry.committed_handle_order`
- `test.geometry.eraser_exact_budget_inputs`
- `test.geometry.eraser_exact_budget_no_partial_commit`
- `test.spatial.tile_outlier_membership`
- `test.spatial.touched_update`
- `test.spatial.no_full_clone_for_touched_update`
- `test.spatial.stale_generation_rejected`
- `test.spatial.fallback_budget_enforced`
- `test.spatial.invalid_index_fallback`
- `test.spatial.runtime_delivery_order`
- `test.frame.main_overlay_capture`
- `test.frame.frame_record_painter_boundary`
- `test.guardrails.frame_committed_facts_via_frame_facts_port`
- `test.frame.frame_spatial_paint_admission`
- `test.frame.frame_drawable_policy`
- `test.frame.marquee_captured_style`
- `test.surface.no_live_runtime_read_in_painters`
- `test.surface.overlay_drawable_policy`
- `test.surface.marquee_captured_style`
- `test.frame.selection_decoration_plan`
- `test.surface.selection_chrome_topmost_paint`
- `test.surface.selection_chrome_hit_target_boundary`
- `test.frame.paint_plan_write_all_or_nothing`
- `test.frame.measured_text_layout`
- `test.guardrails.edit_accepted_finalization_guardrail`
- `test.guardrails.text_surface_guardrail_checks`
- `test.guardrails.geometry_committed_handle_order`
- `test.guardrails.geometry_eraser_exact_budget_inputs`
- `test.guardrails.spatial_no_full_clone_ordinary_edit`
- `test.guardrails.spatial_stale_candidate_rejected`
- `test.guardrails.spatial_fallback_budget_enforced`
- `test.frame.paint_plan_excludes_preview_delta`
- `test.frame.camera_pan_preserves_ordinary_paint_plan`
- `test.frame.cache_keys_use_current_revisions`
- `test.frame.cache_capacity_eviction_policy`
- `test.frame.selected_supplement_staging_no_global_sort`
- `test.api.runtime_surface_frame_bridge`
- `test.surface.surface_frame_output_cache`
- `test.interaction.preview_public_state`
- `test.interaction.eraser_context_action_routing`
- `test.interaction.move_machine`
- `test.interaction.select_machine`
- `test.interaction.move_resolver_reentrancy`
- `test.interaction.move_resolver_not_called_on_cancel_cleanup`
- `test.interaction.pointer_tool_cleanup_coordinator`
- `test.interaction.text_edit_stale_commit_guard`
- `test.diagnostics.interaction_diagnostics`
- `test.frame.selected_move_main_repaint`
- `test.frame.marquee_overlay_repaint`
- `test.guardrails.action_after_state`
- `test.guardrails.interaction_guardrail_enforcement`
- `test.surface.widget_paint`
- `test.guardrails.release_readiness`
- `test.benchmarks.benchmark_manifest`
- `test.benchmarks.benchmark_diff`
- `test.benchmarks.benchmark_runner`
- `test.benchmarks.required_cases`
- `test.guardrails.blocking_suite`
Guardrails:
- `none`
Do not assume:
- shared behavior needs current owner tests
<!-- CONTEXT:END -->

## 23. Tests

### Required Test Inventory

Required tests:

- `test/api_contract/public_api_v1_compiles_as_written_test.dart`
- `test/api_contract/public_exports_complete_test.dart`
- `test/api_contract/api_facades_do_not_export_internal_test.dart`
- `test/api_contract/public_api_no_unapproved_placeholders_test.dart`
- `test/api_contract/public_readable_union_variants_test.dart`
- `test/api_contract/preview_state_sealed_union_test.dart`
- `test/api/canvas_transform_test.dart`
- `test/api/canvas_field_update_test.dart`
- `test/api_contract/canvas_field_update_static_semantics_test.dart`
- `test/api_contract/no_undefined_public_type_references_test.dart`
- `test/api_contract/dto_immutability_test.dart`
- `test/api_contract/public_equality_policy_test.dart`
- `test/api_contract/public_signature_shape_test.dart`
- `test/api_contract/id_validation_no_extension_type_escape_test.dart`
- `test/api_contract/public_integration_compile_fixture_test.dart`
- `test/api_contract/public_facade_wrapper_test.dart`
- `test/contracts/contract_declaration_shape_test.dart`
- `test/contracts/internal_seam_shape_test.dart`
- `test/guardrails/public_api_declaration_checks_test.dart`
- `test/guardrails/public_api_import_cycles_test.dart`
- `test/guardrails/import_boundaries_test.dart`
- `test/guardrails/owner_dag_import_boundaries_test.dart`
- `test/architecture_graph/current_closure_checker_test.dart`
- `test/guardrails/frame_committed_facts_via_frame_facts_port_test.dart`
- `test/guardrails/blocking_suite_test.dart`
- `test/guardrails/release_readiness_guardrail_test.dart`
- `test/benchmarks/benchmark_manifest_test.dart`
- `test/benchmarks/benchmark_diff_test.dart`
- `test/benchmarks/benchmark_runner_test.dart`
- `test/benchmarks/required_cases_test.dart`

The owner-DAG proof is split intentionally: `owner_dag_import_boundaries_test`
checks wrapper export, named facade bridge, implementation-to-api,
contracts-to-api, and contracts-to-implementation fixtures, while
`current_closure_checker_test` proves the same forbidden-edge classes in
`architecture_graph.yaml`.
- `test/codec/schema_v1/known_fields_validation_test.dart`
- `test/codec/schema_v1/canonical_encode_roundtrip_test.dart`
- `test/codec/schema_v1/metadata_projection_test.dart`
- `test/codec/schema_v1/resources_appkey_only_test.dart`
- `test/codec/schema_v1/reject_unknown_element_kind_test.dart`
- `test/codec/schema_v1/reject_unknown_resource_source_kind_test.dart`
- `test/codec/decode_encode_no_runtime_side_effects_test.dart`
- `test/guardrails/codec_no_runtime_imports_test.dart`
- `test/codec/validated_import_draft_test.dart`
- `test/codec/constructor_and_schema_limits_test.dart`
- `test/diagnostics/sanitizer_and_public_projection_test.dart`
- `test/diagnostics/disabled_no_alloc_hot_path_test.dart`
- `test/diagnostics/diagnostics_public_surface_test.dart`
- `test/resources/sync_image_resolver_test.dart`
- `test/resources/app_owned_image_not_disposed_test.dart`
- `test/runtime/resource_catalog_port_test.dart`
- `test/resources/resource_kernel_read_port_test.dart`
- `test/resources/resource_dirty_port_test.dart`
- `test/runtime/resource_dirty_runtime_delivery_test.dart`
- `test/resources/resource_dirty_test.dart`
- `test/resources/mark_all_resources_dirty_test.dart`
- `test/resources/missing_result_suppressed_per_frame_test.dart`
- `test/resources/surface_session_cache_lifecycle_test.dart`
- `test/resources/resolver_swap_starts_fresh_cache_test.dart`
- `test/resources/resolver_frame_budget_test.dart`
- `test/resources/resolver_reentrancy_rejected_test.dart`
- `test/api/selection_port_test.dart`
- `test/api/selection_transform_commands_test.dart`
- `test/api/command_port_actions_test.dart`
- `test/api/tool_port_settings_test.dart`
- `test/api/typed_action_payloads_test.dart`
- `test/api/runtime_timestamp_order_test.dart`
- `test/runtime/command_facts_port_test.dart`
- `test/runtime/load_interaction_cleanup_test.dart`
- `test/edit/low_level_mutations_do_not_emit_actions_test.dart`
- `test/interaction/commands_emit_user_actions_test.dart`
- `test/interaction/interaction_declarations_test.dart`
- `test/interaction/pointer_session_test.dart`
- `test/interaction/pointer_sample_normalizer_test.dart`
- `test/interaction/interaction_read_port_test.dart`
- `test/interaction/context_action_request_test.dart`
- `test/runtime/text_editing_port_test.dart`
- `test/surface/text_editing_overlay_test.dart`
- `test/runtime/dispose_lifecycle_test.dart`
- `test/runtime/runtime_state_publication_test.dart`
- `test/api/runtime_surface_frame_bridge_test.dart`
- `test/smoke/public_incremental_smoke_test.dart`
- `test/runtime/load_document_state_publication_test.dart`
- `test/surface/interactive_false_pointer_routing_test.dart`
- `test/surface/interactive_false_active_session_cancel_test.dart`
- `test/surface/interactive_false_pending_line_preserved_test.dart`
- `test/surface/interactive_false_state_isolation_test.dart`
- `test/surface/single_active_surface_test.dart`
- `test/surface/surface_resource_session_lifecycle_test.dart`
- `test/surface/pointer_adapter_finite_normalization_test.dart`
- `test/surface/canvas_surface_layout_constraints_test.dart`
- `test/surface/surface_frame_output_cache_test.dart`
- `test/surface/widget_paint_test.dart`
- `test/surface/surface_camera_frame_output_test.dart`
- `test/store/read_document_projection_test.dart`
- `test/store/no_projection_hot_path_test.dart`
- `test/store/public_document_is_projection_only_test.dart`
- `test/store/store_commit_finalization_test.dart`
- `test/edit/sync_non_nested_async_stale_test.dart`
- `test/edit/rollback_test.dart`
- `test/edit/field_update_admission_effects_test.dart`
- `test/edit/edit_matrix_effects_test.dart`
- `test/edit/net_no_op_edit_commit_test.dart`
- `test/edit/exact_touched_invalidation_test.dart`
- `test/edit/typed_effects_no_frame_dependency_test.dart`
- `test/edit/staged_document_load_success_failure_test.dart`
- `test/spatial/committed_spatial_read_boundary_test.dart`
- `test/geometry/hit_policy_test.dart`
- `test/geometry/geometry_committed_handle_order_test.dart`
- `test/geometry/eraser_exact_budget_inputs_test.dart`
- `test/geometry/eraser_exact_budget_no_partial_commit_test.dart`
- `test/spatial/tile_outlier_membership_test.dart`
- `test/spatial/touched_update_test.dart`
- `test/spatial/no_full_clone_for_touched_update_test.dart`
- `test/spatial/stale_generation_rejected_test.dart`
- `test/spatial/fallback_budget_enforced_test.dart`
- `test/spatial/invalid_index_fallback_test.dart`
- `test/spatial/runtime_delivery_order_test.dart`
- `test/api/canvas_runtime_preview_test.dart`
- `test/frame/main_overlay_capture_test.dart`
- `test/frame/frame_record_painter_boundary_test.dart`
- `test/frame/frame_spatial_paint_admission_test.dart`
- `test/frame/frame_drawable_policy_test.dart`
- `test/frame/marquee_captured_style_test.dart`
- `test/surface/no_live_runtime_read_in_painters_test.dart`
- `test/surface/overlay_drawable_policy_test.dart`
- `test/surface/marquee_captured_style_test.dart`
- `test/frame/selection_decoration_plan_test.dart`
- `test/surface/selection_chrome_topmost_paint_test.dart`
- `test/frame/paint_plan_write_all_or_nothing_test.dart`
- `test/frame/paint_asset_binding_service_test.dart`
- `test/frame/repaint_bus_output_test.dart`
- `test/frame/static_background_plan_test.dart`
- `test/frame/measured_text_layout_test.dart`
- `test/frame/cache_keys_use_current_revisions_test.dart`
- `test/frame/cache_capacity_eviction_policy_test.dart`
- `test/frame/paint_plan_excludes_preview_delta_test.dart`
- `test/frame/paint_plan_excludes_selection_state_test.dart`
- `test/frame/camera_pan_preserves_ordinary_paint_plan_test.dart`
- `test/frame/selected_supplement_staging_no_global_sort_test.dart`
- `test/frame/selected_move_main_repaint_test.dart`
- `test/frame/marquee_overlay_repaint_test.dart`
- `test/interaction/preview_public_state_test.dart`
- `test/interaction/eraser_context_action_routing_test.dart`
- `test/interaction/move_machine_test.dart`
- `test/interaction/select_machine_test.dart`
- `test/interaction/move_resolver_reentrancy_test.dart`
- `test/interaction/move_resolver_not_called_on_cancel_cleanup_test.dart`
- `test/interaction/pointer_tool_cleanup_coordinator_test.dart`
- `test/interaction/text_edit_stale_commit_guard_test.dart`
- `test/diagnostics/interaction_diagnostics_test.dart`
- `test/selection/runtime_owner_separation_test.dart`
- `test/guardrails/action_after_state_guardrail_test.dart`
- `test/guardrails/interaction_guardrail_enforcement_test.dart`
- `test/guardrails/selection_boundary_checks_test.dart`
- `test/guardrails/geometry_committed_handle_order_guardrail_test.dart`
- `test/guardrails/geometry_eraser_exact_budget_inputs_guardrail_test.dart`
- `test/guardrails/spatial_no_full_clone_ordinary_edit_guardrail_test.dart`
- `test/guardrails/spatial_stale_candidate_rejected_guardrail_test.dart`
- `test/guardrails/spatial_fallback_budget_enforced_guardrail_test.dart`
- `test/guardrails/frame_no_global_scene_sort_guardrail_test.dart`
- `test/guardrails/frame_paint_plan_excludes_preview_delta_guardrail_test.dart`
- `test/guardrails/frame_paint_plan_excludes_selection_state_guardrail_test.dart`
- `test/guardrails/cache_keys_use_next_revisions_only_guardrail_test.dart`
- `test/guardrails/cache_background_grid_not_element_visual_guardrail_test.dart`
- `test/guardrails/cache_hot_caches_have_capacity_eviction_guardrail_test.dart`
- `test/guardrails/edit_accepted_finalization_guardrail_test.dart`
- `test/guardrails/text_surface_guardrail_checks_test.dart`
- `test/guardrails/preview_selected_move_main_repaint_guardrail_test.dart`

### Behavioral Coverage Notes

`test.edit.edit_matrix_effects` covers expanded operation matrix dimensions:
touched state, public state revisions, internal revisions, spatial,
projection, resource effects, repaint, user-action events, no-op behavior, and
rollback behavior.

`test.edit.net_no_op_edit_commit`, `test.store.store_commit_finalization`, and
`test.guardrails.edit_accepted_finalization_guardrail` cover store-owned
accepted finalization for ordinary sparse and materialized edit candidates.
They prove compensating final fact no-ops collapse before edit plan
compilation, interaction augmentation, store install, public state publication,
typed effect delivery, action emission, observer notification, and public
projection reads, while explicit `replaceDraftDocument` remains the forced
replacement path.

`test.api.runtime_timestamp_order` covers the public runtime timestamp
contract for committed action events: nullable or backwards `timestampMs` hints
resolve through one runtime-local monotonic cursor, while loadDocument and
dispose stream-close paths create no timestamped action output.
`test.interaction.runtime_created_timestamps_monotonic` remains the
contract-level proof area for non-action runtime-created timestamp outputs
owned by later interaction work.

`test.codec.constructor_and_schema_limits` covers element transform admission
at public DTO construction and schema decode: non-invertible element
transforms reject with `fieldMustBeInvertible`, while `CanvasTransform` remains
the general affine value type.

`test.frame.measured_text_layout` covers the single measured text layout source:
frame-owned `FrameTextLayoutMeasurer` produces the local text bounds that
geometry, spatial membership, frame painting, and live edit geometry consume,
and those bounds stay stable across left, center, and right alignment changes.

`test.runtime.text_editing_port` and `test.surface.text_editing_overlay` cover
runtime-owned active text editing sessions, stale/read-only admission, guarded
commit/dismiss behavior, public custom-overlay replacement, multiline growth
from session geometry, live preservation of the resolved horizontal anchor and
top edit edge, committed preservation of the same anchors after text size
changes, and paint suppression without document visibility mutation.

`test.guardrails.text_surface_guardrail_checks` proves the runner-backed
structural checks for formula-based text bounds, duplicate overlay
`TextPainter` measurement, and `EditableText` imports outside the surface
production owner.

`test.edit.field_update_admission_effects` covers field-update admission and
effects: nullable clears, dynamic non-nullable clear rejection,
non-invertible transform rejection, mismatched update-kind rejection, geometry
revision effects, and selection pruning.

`test.edit.staged_document_load_success_failure` covers `loadDocument`
rejection of non-invertible element transforms before `PreparedDocumentLoad`
success, interaction interruption, repaint, action events, or public state
publication.

geometry/spatial `test.geometry.hit_policy` coverage for corrupted committed hit rows proves
the implemented behavior: a non-invertible element transform returns miss,
continues candidate scan, has no coarse fallback acceptance, mutates no state,
and allocates no DiagnosticsHub record. The policy-gated corrupted-row
DiagnosticsHub route is deferred after geometry/spatial.

Future diagnostics sanitizer coverage must cover corrupted-row diagnostic
sanitization when that deferred route is implemented.
`test.diagnostics.disabled_no_alloc_hot_path` covers only the schema/codec
disabled-diagnostics no-allocation subset; pointer and paint hot-path proof
remains deferred until those runtime owners exist.

### Test Shape Rules

In-package unit and behavior tests run directly in the package under test. They
should use ordinary `test(...)` bodies and must not create temporary Flutter
consumer packages unless the behavior being proved is external consumer access.

External consumer behavior tests prove that ordinary package users can import
`package:iwb_canvas_engine/iwb_canvas_engine.dart` and execute public behavior
from a temporary Flutter consumer package. These tests must use
`test/support/flutter_consumer_test_harness.dart`; the feature test owns only
the package name, generated test file name, and consumer test source. Do not
duplicate temp-directory, pubspec, process-output, or cleanup logic in feature
tests.

Compile/static/analyzer tests may keep local runners when they are not ordinary
consumer behavior tests, such as compile-only fixtures, analyzer static
semantics checks, AST/import scans, or tests that must write more than one
generated file before running a command. Those local runners must keep the
custom behavior visible in the test file instead of hiding it behind the generic
consumer harness.

Guardrail tests are executable proofs for repository guardrails. Behavioral
proof belongs in tests; shared scanner logic, runner metadata, or reusable
structural checks belong in tooling. A guardrail runner may dispatch proofs, but
it must not replace the behavioral test that proves the rule.

### Guardrail Test Ownership

`test/guardrails/**` owns executable proof tests that make cross-cutting
guardrails part of the normal package test gates and CI. Dart-only guardrail and
benchmark proof may run through `dart test`; Flutter-dependent package tests run
through `flutter test`. `tool/guardrails/**` owns the guardrail runner, runner
metadata or manifests, and reusable structural check logic. Simple guardrails
may live entirely as tests. Shared scanner logic or logic used by both tests and
the runner belongs under `tool/guardrails/**`, with a thin test under
`test/guardrails/**`.

The runner is only a dispatcher over proof commands. It must not replace
behavioral tests, and the required guardrail list remains owned by
`section_22_guardrails_machine_checks`.

### Test Responsibilities

#### `test/api_contract/public_integration_compile_fixture_test.dart`
- compiles test/api_contract/fixtures/public_integration_compile_fixture.dart;
- proves external application adapter code can use the public integration
  surface through package:iwb_canvas_engine/iwb_canvas_engine.dart only;
- rejects fixture imports of src/\*\*, package-internal or unregistered public symbols, or internal
  runtime classes;
- covers runtime lifecycle, state/document observation, edit/load,
  selection/camera/tools, high-level commands, actions/context-action
  requests, guarded text commit, resources, and CanvasSurface construction
  with public resolver/style inputs.

#### `test/api_contract/example_public_boundary_test.dart`
- scans rebuilt root example Dart sources under `example/**`, excluding
  generated `.dart_tool` and build output;
- proves example engine imports use only
  `package:iwb_canvas_engine/iwb_canvas_engine.dart`;
- rejects example imports of engine internals, package-internal paths, package-internal symbols, and app-adapter responsibility
  names;
- when the current unstaged, staged, or untracked diff includes non-generated
  `example/**` changes, fails that current diff if it also modifies production
  `lib/**` files, reserving engine changes for a separate owner contract;
- when `EXAMPLE_BOUNDARY_DIFF_BASE` and `EXAMPLE_BOUNDARY_DIFF_HEAD` are set,
  fails if that committed range modifies production `lib/**` files;
- proves production engine source under `lib/**` does not contain
  `application canvas port` or `application adapter`.

#### `test/api_contract/public_api_v1_compiles_as_written_test.dart`
- compiles the exported API declarations in an empty consumer package;
- instantiates and calls public constructors, getters, methods,
  defaults, and return shapes through the public barrel.

#### `test/api_contract/public_exports_complete_test.dart`
- proves every public API declaration registered for v1 is exported by the
  package barrel;
- proves frame-private collaborators and other implementation owners do not
  become public exports by omission from the public registry.

#### `test/api_contract/api_facades_do_not_export_internal_test.dart`
- proves API facade export files do not expose declarations marked `@internal`;
- protects frame, resource, and other implementation-owned collaborators from
  accidental facade export.

#### `test/guardrails/public_api_declaration_checks_test.dart`
- checks exported public declarations for non-empty dartdoc summaries for
  api.exported_dartdoc_complete;
- checks exported public classes for explicit Dart 3 subtype policy
  modifiers for api.public_class_modifiers_explicit.

#### `test/guardrails/public_api_import_cycles_test.dart`
- checks import-cycle fixtures and the live public API import graph for
  api.no_public_api_import_cycles.

#### `test/api_contract/no_undefined_public_type_references_test.dart`
- verifies every exported signature type is exported or from Flutter/Dart SDK;

#### `test/api_contract/public_signature_shape_test.dart`
- uses resolved analyzer public-surface traversal to reject FutureOr<T>,
  nullable async/container returns, generic bounds with forbidden public
  shape, and dynamic outside approved JSON or diagnostic boundaries for
  api.public_signature_shape.

#### `test/api_contract/dto_immutability_test.dart`
- proves public DTO constructors defensively copy caller-owned Iterable, List,
  Set, Map, and metadata input;
- proves public collection getters and CanvasMetadata projections are
  unmodifiable and deep-frozen;
- proves invalid public construction is rejected before DTO exposure;
- proves public constructors accepting caller-provided values with documented
  runtime validation or sanitization are non-const factories, while
  marker/empty/default/private storage forms keep only approved const forms.

#### `test/api_contract/id_validation_no_extension_type_escape_test.dart`
- proves public id constructors validate invalid values from an external
  consumer package;
- proves v1 ids are public classes, not public extension types with unchecked
  value escape.

#### `test/api_contract/preview_state_sealed_union_test.dart`
- proves CanvasPreviewState is a sealed public union with exported readable
  concrete variants and stable CanvasPreviewKind values;
- proves CanvasStrokePreview is the shared public pencil/marker preview base;
- proves preview iterable payloads are defensively copied and unmodifiable;
- proves selected ids, pointer tokens, active pointer ids, session ids, and
  tool-discriminated generic stroke payloads are not public preview state.

#### `test/guardrails/import_boundaries_test.dart`
- verifies package-owned source paths obey the forbidden import matrix;
- rejects imports from another package's src/**;
- rejects concrete interaction imports of src/store and src/selection owner
  internals outside approved query-port abstractions;
- scans production lib/** Dart files for part/part of directives and allows
  them only through an explicit generated-code approval list.

#### `test/guardrails/blocking_suite_test.dart`
- proves the executable hard-boundary guardrail ids are represented in
  runner inventory;
- proves the full guardrail runner, `--suite=api`, `--suite=core`, and
  explicit `--guardrail=<id>` selection modes execute the intended hard-boundary ids;
- proves unknown or empty suite selection fails instead of silently running
  an unintended guardrail set.

#### `test/guardrails/release_readiness_guardrail_test.dart`
- proves `release.benchmark_readiness` is runner-backed in the blocking and
  release suites without running the full benchmark matrix;
- rejects public benchmark exports, public integration names in production
  source, retired benchmark package imports, and rogue approved baseline writers
  in benchmark tooling.

#### `test/runtime/dispose_lifecycle_test.dart`
- proves runtime dispose keeps state.value readable;
- verifies dispose does not increment state.revisions.document and state
  only notifies during first dispose when active preview cleanup advances
  state.revisions.preview;
- verifies no public state notifications are delivered after dispose
  returns, repeated dispose is silent, and listeners can be removed after
  dispose.

#### `test/runtime/runtime_state_publication_test.dart`
- proves ordinary document edits publish one CanvasRuntimeState with
  state.revisions.document advanced and unrelated public domains unchanged;
- proves no-op edits and no-op runtime operations do not publish a new
  CanvasRuntimeState.

#### `test/smoke/public_incremental_smoke_test.dart`
- proves an external Flutter consumer can import only the root public barrel,
  construct CanvasRuntime, load schema v1 JSON through
  `runtime.edits.loadDocumentFromJson(json)`, observe initial state and
  readDocument output, and perform public selection, resource, edit, and load
  operations;
- appends geometry/spatial public API coverage for background geometry,
  overlapping transformed content, one public geometry-changing edit, and a
  replacement geometry-rich load while asserting only public runtime/document
  outcomes;
- appends frame/cache public API coverage for reading `runtime.preview` and
  pumping a resource-free `CanvasSurface` through the public API until the
  `ValueKey<String>('iwb_canvas_surface.paint_host')` `CustomPaint` host is
  present;
- appends public interaction coverage for non-throwing tool,
  empty context-request stream, marquee replacement selection, selected-move
  preview and resolved commit, typed action delivery, remove-element command,
  unknown text-edit no-op, and clear-content command behavior;
- appends draw coverage for pencil and marker stroke previews, first-drag
  and two-tap line previews/commits, public `CanvasSurface(interactive: false)`
  pending-line preservation, committed stroke/line document elements, and typed
  draw action delivery after accepted state publication;
- appends surface `public consumer uses CanvasSurface pointer and resource bridge`
  coverage for resource-free zero resolver calls, app-key image resource
  resolution through `CanvasSurface`, resolver replacement, bounded null
  resolver behavior, Flutter pointer gestures on the public paint host,
  `interactive=false` no-route isolation, and pending-line preservation through
  Flutter events;
- uses the shared Flutter consumer harness as the package-boundary proof;
- stays intentionally coarse so focused codec, runtime, selection, and cache
  interaction tests own detailed diagnostics;
- must expand only by appending the next real public user step after the public
  API exposes one.

#### `test/spatial/committed_spatial_read_boundary_test.dart`
- proves `FrameFactsPort` exposes `locationKind` and nullable `layerId` as
  resolved current-row facts for background and content rows;
- proves callers cannot bypass structuralRevision, generation, or orderToken
  validation by supplying stale handles, and geometry/spatial code does not
  read concrete store tables.

#### `test/geometry/eraser_exact_budget_inputs_test.dart`
- proves geometry/spatial eraser corridor, exact-hit input limits, and preview/terminal
  candidate and exact-check budget input shapes;
- intentionally leaves terminal cleanup/no-op commit behavior to eraser/context-action.

#### `test/spatial/tile_outlier_membership_test.dart`
- proves tile membership, outlier routing, max-cells behavior, and query
  candidate ordering for the implemented `SpatialKernel` indexes.

#### `test/spatial/invalid_index_fallback_test.dart`
- proves invalid spatial index fallback returns typed invalid/budget results
  without silently scanning the full scene.

#### `test/spatial/runtime_delivery_order_test.dart`
- proves `RuntimeRoot` applies spatial update/rebuild delivery before public
  runtime state publication and before observer callbacks can run.

#### geometry/spatial guardrail proof tests
- `test/guardrails/geometry_committed_handle_order_guardrail_test.dart`,
  `test/guardrails/geometry_eraser_exact_budget_inputs_guardrail_test.dart`,
  `test/guardrails/spatial_no_full_clone_ordinary_edit_guardrail_test.dart`,
  `test/guardrails/spatial_stale_candidate_rejected_guardrail_test.dart`, and
  `test/guardrails/spatial_fallback_budget_enforced_guardrail_test.dart`
  prove the geometry/spatial guardrail ids are registered, runner-backed where structural
  proof is required, and fail on fixtures containing the forbidden pattern.

#### `test/runtime/load_document_state_publication_test.dart`
- proves successful loadDocumentFromJson publishes exactly one post-install
  CanvasRuntimeState that includes document, selection, viewCamera, epoch,
  and conditional preview cleanup revisions;
- proves loadDocumentFromJson failure publishes no public state snapshot.

#### Public command and tool tests
- `test/api/selection_port_test.dart` proves direct public selection changes
  update the selection revision domain without emitting user actions.
- `test/api/selection_transform_commands_test.dart` proves public selection
  transform/delete command eligibility, transform math, pivot selection,
  document-order ids, no-op behavior, selection pruning, validation errors,
  and typed action emission.
- `test/api/command_port_actions_test.dart` proves command-port remove, clear,
  and unknown text-edit behavior plus their action payloads.
- `test/api/tool_port_settings_test.dart` proves public tool-port behavior:
  initial settings are visible, effective changes advance interaction
  revision, no-ops stay silent, active sessions clean up on setting changes,
  pencil draw-mode pointer input publishes preview-only public state,
  direct double tap emits a bounded asynchronous context-action request, and
  context-action requests use a non-throwing broadcast stream.
- `test/api/runtime_timestamp_order_test.dart` proves runtime-created action
  timestamps are resolved through one runtime-local monotonic cursor.
- `test/runtime/command_facts_port_test.dart` proves immutable command fact
  bundles, document order, center pivot, removed-resource facts, and no
  interaction dependency.
- `test/runtime/load_interaction_cleanup_test.dart` proves load and dispose
  use interaction-owned cleanup without post-install interaction calls.

#### Draw tool tests
- `test/interaction/draw_stroke_machine_test.dart` proves pencil and marker
  stroke decisions, duplicate-point handling, and max-point replacement.
- `test/interaction/draw_stroke_interaction_routing_test.dart` proves
  `InteractionEngine` pencil and marker routing for preview publication,
  commit intents, second-pointer ignore, cancel/stale cleanup, and no timestamp
  resolution on rejected stroke terminals.
- `test/interaction/line_machine_test.dart` proves two-tap line decisions,
  pending-line facts, endpoint preview facts, and line commit intent payload.
- `test/interaction/line_interaction_routing_test.dart` proves
  `InteractionEngine` line routing for first-pointer-drag preview/commit,
  accepted first-tap pending preview timestamps, rejected first-tap timestamp
  silence, endpoint preview and commit intents, same-point line acceptance,
  stale/invalid/cancel cleanup, and pending-line ownership behavior.
- `test/runtime/draw_commit_delivery_test.dart` proves accepted pencil, marker,
  and line commits create public stroke/line elements through the edit kernel,
  emit typed draw actions after public state publication, preserve
  programmatic `CanvasEdit.addElement` action silence, and roll back failed
  draw delivery without action or timestamp advancement.
- `test/runtime/draw_cleanup_integration_test.dart` proves draw cleanup paths,
  load success, load failure, `interactive=false`, settings changes, cancel,
  and no-op terminals do not reserve the next draw output timestamp.
- `test/surface/interactive_false_pending_line_preserved_test.dart`
  proves public `CanvasSurface(interactive: false)` preserves non-owned
  pending line state, clears active endpoint state, and cleans the current runtime
  on runtime-swap plus `interactive` disable.
- `test/api/typed_action_payloads_test.dart` proves public draw action payload
  fields and runtime finalization for `drawPencil`, `drawMarker`, and
  `drawLine`.
- `test/smoke/public_incremental_smoke_test.dart` appends root-barrel public
  consumer coverage for drawing pencil, marker, and line, observing public
  preview variants, preserving pending line preview across a public surface
  `interactive=false` update, reading committed stroke/line elements, and
  observing typed draw actions after accepted state publication.
- `test/guardrails/interaction_guardrail_enforcement_test.dart` proves
  `interaction.no_stale_terminal_commit`,
  `interaction.pointer_cleanup_coordinator_only`, and interaction import
  guardrails are runner-backed or structurally checked for draw/line and
  eraser/context-action eraser owner surfaces.
- `test/architecture_graph/generated_graph_views_test.dart` proves generated
  architecture graph Mermaid views are reproducible for the selected eraser/context-action view
  and stay synchronized with `docs/architecture/architecture_graph.yaml`.

#### eraser/context-action eraser and context-action request tests
- `test/interaction/interaction_read_port_test.dart` proves eraser/context-action immutable read
  facts for eraser, context targets, and text guard inputs without exposing
  store tables or mutation owners to interaction machines.
- `test/interaction/eraser_context_action_routing_test.dart` proves eraser machine routing,
  immutable preview publication, terminal commit intent decisions, direct
  double-tap request production, and two-tap context revalidation behavior.
- `test/interaction/context_action_request_test.dart` proves direct and
  pointer-sample context-action request issuance, target classification,
  request id generation, live registry guard facts, finite-position validation,
  selection taps preserving the first-tap context history for universal
  double-tap recognition, rejected invalid/stale/budget target reads with no
  public request, accepted asynchronous stream delivery, and stream-only public
  effects.
- `test/geometry/eraser_exact_budget_no_partial_commit_test.dart` proves
  terminal eraser budget overflow cleans up without partial document mutation,
  action delivery, or DiagnosticsHub allocation.
- `test/runtime/load_interaction_cleanup_test.dart` proves successful document
  load prepares eraser/context-action eraser/context cleanup before install while failed load
  preserves active interaction state where required.
- `test/interaction/text_edit_stale_commit_guard_test.dart` proves guarded
  request-originated text commits, including unknown/already-consumed no-ops,
  stale/private consumption, unrelated documentRevision acceptance, single-use
  accepted ids, and no raw text action payload.
- `test/api/typed_action_payloads_test.dart` proves public erase and editText
  action payload constructors, defensive copies, and runtime finalization.
- `test/smoke/public_incremental_smoke_test.dart` appends root-barrel public
  consumer coverage for eraser preview/commit, content and background-only
  context requests, issued text commit, consumed/unknown text no-ops, and no
  raw text leakage through observed action payloads.
- `test/guardrails/interaction_guardrail_enforcement_test.dart` and
  `test/guardrails/blocking_suite_test.dart` prove
  `interaction.text_edit_stale_commit_guard` is runner-backed, selected by the
  blocking suite, and rejects hardcoded or bypassed text guard facts.

#### surface Flutter surface tests
- `test/surface/single_active_surface_test.dart` proves exactly one active
  `CanvasSurface` per `CanvasRuntime`, rejected attach all-or-nothing behavior,
  and independent active surfaces for independent runtimes.
- `test/surface/surface_resource_session_lifecycle_test.dart` proves accepted
  attach creates the active surface resource session, resolver replacement uses
  the fresh resolver, dirty invalidation reaches the active session, and detach,
  dispose, runtime swap, and runtime dispose drop session state without
  disposing app-owned images.
- `test/surface/pointer_adapter_finite_normalization_test.dart` proves the
  surface `Listener` converts finite Flutter down/move/up/cancel events to
  public pointer samples, maps non-finite up/cancel to terminal cleanup input,
  leaves world normalization in interaction, and keeps stale callbacks and
  non-finite down/move events runtime-effect silent.
- `test/surface/canvas_surface_layout_constraints_test.dart` proves bounded
  `CanvasSurface` layout preserves the finite paint host size, vertically and
  horizontally unbounded layout constraints report a FlutterError on the
  ordinary execution path, and the rejection stays local to the constant-time
  surface layout boundary instead of debug-only, release-excluded, or runtime,
  frame, cache, painter, pointer, resource, or interaction work.
- `test/surface/interactive_false_pointer_routing_test.dart`,
  `test/surface/interactive_false_active_session_cancel_test.dart`,
  `test/surface/interactive_false_pending_line_preserved_test.dart`, and
  `test/surface/interactive_false_state_isolation_test.dart` prove
  `interactive=false` removes pointer routing, cancels only active routed
  pointer state through interaction cleanup, preserves non-owned pending-line
  preview, ignores stale terminal events after re-enable, and does not mutate
  committed document, selection, resources, mode, or actions.
- `test/surface/widget_paint_test.dart` and
  `test/surface/surface_camera_frame_output_test.dart` prove the public surface
  wrapper remains stable while frame-owned main and overlay outputs render
  through independently repaintable surface-owned layer hosts.
- `test/api/runtime_surface_frame_bridge_test.dart` proves the internal
  runtime-surface bridge publishes `CanvasRuntimeSurfaceFrame` values with
  runtime-owned `CanvasSurfaceRepaintTarget` values before output construction,
  maps preview, selection, resource, load, camera, and fallback paths to the
  expected main/overlay flags, preserves the public runtime state value, and
  does not expose or import `FrameRepaintSignal`.
- `test/surface/surface_frame_output_cache_test.dart` proves
  `SurfaceFrameOutputCache` calls only the targeted main and/or overlay output
  builders, maps local surface inputs to layer invalidation, leaves untouched
  layer output identity and notifier state stable, and publishes no notifier
  update until the targeted build succeeds.
- `test/surface/widget_paint_test.dart` proves real `CanvasSurface` bootstrap,
  local input, runtime swap, resource dirty, resolver replacement, budget
  follow-up, and inactive/rejected attach paths route through the surface
  listener, frame builders, layer output notifiers, and render paint marks
  without using painter-owned output construction.
- `test/smoke/public_incremental_smoke_test.dart` appends the surface root-barrel
  public consumer scenario named
  `public consumer uses CanvasSurface pointer and resource bridge`, covering
  resource-free paint, resource-backed resolver calls, resolver replacement,
  Flutter pointer draw output, `interactive=false` no-route isolation, and
  pending-line preservation without internal package imports.

#### `test/selection/runtime_owner_separation_test.dart`
- proves selection-only changes publish state.revisions.selection without
  incrementing state.revisions.document, evicting DocumentProjectionCache,
  or updating SpatialKernel;
- proves document replacement, delete, clear, and eraser paths publish
  document and selection effects as one atomic CanvasRuntimeState;
- proves selectedOrder is derived from selectionRevision and
  structuralRevision, not stored as an independent source of truth.

#### `test/frame/frame_spatial_paint_admission_test.dart`
- proves frame paint admission accepts only explicit spatial candidate results;
- proves typed budget-exceeded, invalid-index, and stale-candidate spatial
  results remain rejected admissions instead of successful empty candidate
  streams.

#### `test/frame/paint_plan_write_all_or_nothing_test.dart`
- proves ordinary cache writes occur only after ordinary spatial admission and
  current row resolution complete;
- proves rejected selected-move shifted admission returns ordinary records
  unchanged and performs no ordinary cache write.

#### `test/frame/frame_drawable_policy_test.dart`
- proves the frame-owned record painter renders one-point committed strokes and
  same-point lines through explicit point or circle commands;
- proves non-degenerate committed lines use round caps and committed stroke
  paths use solid round joins;
- proves empty point lists remain no-op draw inputs.

#### `test/frame/marquee_captured_style_test.dart`
- proves marquee overlay primitives carry captured selection style color,
  stroke width, and fill opacity.

#### `test/surface/no_live_runtime_read_in_painters_test.dart`
- proves surface-owned `MainFramePainter` and `OverlayFramePainter` consume
  immutable frame paint outputs and do not read runtime, store, document
  projection, resolver, or session state during paint;
- proves main and overlay painters are installed below distinct repaint
  boundaries and receive output through layer output listenables.

#### `test/surface/overlay_drawable_policy_test.dart`
- proves the surface-owned overlay painter renders one-point stroke previews and
  eraser corridors through explicit drawable policy, keeps empty point lists
  no-op, paints multi-point stroke preview turns as solid round path joins, and
  paints overlay line previews with round caps.

#### `test/surface/marquee_captured_style_test.dart`
- proves surface-owned overlay painting uses captured marquee primitive fill and
  stroke style instead of live style state.

#### `test/frame/selection_decoration_plan_test.dart`
- proves single selection emits one decoration primitive for the selected
  element and multi-select emits one group-box primitive from the union of
  selected paint bounds;
- proves selected-move preview hides selection decoration without entering
  ordinary paint cache identity or rebuilding the empty decoration on delta
  churn;
- proves chrome placement metadata and structural invalidation stay
  frame-owned, and that selected document order is not the chrome paint source.

#### `test/surface/selection_chrome_topmost_paint_test.dart`
- proves `MainFramePainter` paints selection chrome after the main record stream
  so selected chrome remains above higher-order content;
- proves outside-box stroke placement for box chrome stays outside primitive
  bounds;
- proves topmost decoration painting remains a bounded pass over immutable frame
  output, with no global scene sort, `saveLayer`, ordinary cache write, or live
  runtime read.

#### `test/frame/paint_plan_excludes_selection_state_test.dart`
- proves OrdinaryPaintRecordCache keys and cached ordinary records exclude
  selected ids, selectionRevision, selection flags, and selected-move preview
  state;
- proves selection changes rebuild selection decoration without evicting the
  ordinary committed paint plan;
- proves selected element bounds changes rebuild SelectionDecorationPlan even
  when selection membership is unchanged;
- proves selected-move preview state does not enter ordinary committed paint
  cache identity;
- proves captured selectionStyle changes rebuild SelectionDecorationPlan
  without entering StaticBackgroundCache or OrdinaryPaintRecordCache identity.

#### `test/interaction/preview_public_state_test.dart`
- proves preview-only pointer changes publish state.revisions.preview without
  changing document, selection, resourceVisual, interaction, or viewCamera
  revisions and without emitting action events;
- proves cleanup against already-empty preview state is public-state silent.

#### Interaction boundary tests
- `test/interaction/interaction_declarations_test.dart` proves the required
  interaction declarations live in their owning files instead of umbrella
  or placeholder modules.
- `test/interaction/pointer_session_test.dart` proves active-pointer token,
  controller-epoch, stale terminal cleanup, stale non-terminal ignore, and
  world-position conversion behavior for interaction sessions.
- `test/interaction/pointer_sample_normalizer_test.dart` proves finite public
  pointer sample admission and invalid-terminal cleanup decisions.
- `test/interaction/interaction_read_port_test.dart` proves read-port facts
  are immutable, intent-specific, document-ordered, stale/deleted filtered,
  and free of mutable document, draft, store, resource, and selection internals.
- `test/interaction/move_machine_test.dart` proves selected-move admission,
  preview, resolver request shape, commit, cancel, stale/invalid terminal,
  zero-delta/no-movable cleanup, resolver/edit failure cleanup, transform math,
  post-success cleanup, and move action intent facts.
- `test/interaction/select_machine_test.dart` proves marquee preview,
  normalized world rects, point-click topmost hit selection including line
  hits, spatial/exact filtering, stale/deleted skipping, unchanged-selection
  cleanup, changed-selection commit, previous/next selection action facts, and
  document-order action ids.

#### `test/interaction/pointer_tool_cleanup_coordinator_test.dart`
- proves `PointerToolCleanupCoordinator` outcomes for cleanup reason plus
  ownership context: selected-move cleanup targets main repaint, overlay
  previews target overlay repaint, no-preview cleanup is public-state silent,
  active token/session facts are released before public effects, non-owned
  pending line state is preserved on `interactive=false`, line-owned cleanup
  clears pending line state, pending context tap cleanup emits no context
  request, no resolver runs on cleanup-only paths, stale terminal cleanup
  creates no commit intent, and cleanup emits no user action.

#### Frame and interaction guardrail proof tests
- `test/frame/selected_move_main_repaint_test.dart` and
  `test/frame/marquee_overlay_repaint_test.dart` prove selected-move preview is
  main-only and marquee preview is overlay-only through the frame repaint
  output fixture.
- `test/guardrails/action_after_state_guardrail_test.dart` proves
  state-before-action ordering is runner-backed and rejects inverted action
  fixture order.
- `test/guardrails/interaction_guardrail_enforcement_test.dart` proves
  guardrail ids are registered, blocking, runner-backed or structurally
  checked as appropriate, and reject contract-owned negative fixtures for
  interaction imports, command-fact imports, cleanup coordinator dependencies,
  and mutable read-port fact exposure.

#### `test/resources/resource_dirty_test.dart`
Current implemented proof:
- lives in `test/resources/resource_dirty_port_test.dart`,
  `test/resources/resource_dirty_test.dart`, and
  `test/runtime/resource_dirty_runtime_delivery_test.dart`: committed
  catalog dirty calls publish `state.revisions.resourceVisual`, leave document,
  resource, selection, preview, view-camera, interaction, epoch, action, and
  public document projection state unchanged, prove missing-target and empty
  mark-all no-ops, prove active-session target cache eviction before dirty
  publication, and prove guard rejection before dirty side effects.
- proves markResourceDirty publishes state.revisions.resourceVisual without
  incrementing state.revisions.document, evicting public document projection,
  clearing selection, clearing preview, or emitting an action event.
- proves markResourceDirty(resourceId) evicts the target ImageResolveCache
  entry in the active SurfaceResourceSession and the next session resolve uses
  dirty target again instead of reusing the previous resolved image.

#### `test/resources/resource_image_cache_memory_accounting_test.dart`
- proves `ImageResolveCache` enforces entry-cap LRU with a test-controlled
  capacity and a decoded-byte budget using `ui.Image.width * ui.Image.height *
  4`;
- proves `currentSizeBytes` stays consistent across byte eviction, read
  promotion, same-key replacement, oversized replacement, target invalidation,
  and clear;
- proves a single oversized image is not retained and immediately misses on the
  next cache read;
- proves descriptor `byteLength` remains descriptor metadata and does not drive
  cache pressure or cache identity.

#### `test/resources/surface_session_cache_lifecycle_test.dart`
- proves `SurfaceResourceSession` returns an oversized resolver result as
  `ResolvedResourceImage` for the current resolve while the injected
  small-budget `ImageResolveCache` does not retain it for a later hit;
- preserves existing proofs for target/all invalidation, document replacement
  reset, default 1024-entry LRU behavior, dropped sessions, resolver budget
  state, and same-frame null suppression.

#### `test/resources/app_owned_image_not_disposed_test.dart`
- proves entry eviction, byte eviction, target invalidation, all invalidation,
  resolver replacement, document replacement reset, drop, and dispose remove
  cache references without disposing app-owned `ui.Image` instances;
- proves byte eviction is observable as a later resolver call for the evicted
  key while the evicted app-owned image remains undisposed until the fixture
  explicitly disposes it.

#### `test/resources/mark_all_resources_dirty_test.dart`
- proves markAllResourcesDirty() clears the active SurfaceResourceSession
  ImageResolveCache while preserving document revision, public document
  projection, selection, preview, dirty repaint/effect delivery, and
  action-event behavior.

#### `test/frame/camera_pan_preserves_ordinary_paint_plan_test.dart`
- proves CanvasCameraPort.setOffset and panBy publish
  state.revisions.viewCamera without incrementing state.revisions.document,
  invalidating public document projection, or changing persisted document
  camera;
- proves camera pan preserves OrdinaryPaintRecordCache entries while ordinary
  admission follows the current effective world viewport and schedules
  repaint for the main and overlay surfaces affected by the runtime view;
- proves backgroundRevision and gridRevision invalidate StaticBackgroundCache
  without invalidating OrdinaryPaintRecordCache entries;
- proves CanvasEdit.setCameraOffset changes persisted document camera through
  the explicit edit boundary, including the
  setCameraOffset(runtime.camera.offset) persistence path, and readDocument
  returns that persisted camera instead of the runtime view camera.

#### `test/frame/ordinary_paint_primitive_policy_test.dart`
- proves ordinary element opacity is represented through primitive paint alpha
  and does not require implicit saveLayer behavior in the hot ordinary paint
  path.

#### `test/frame/render_primitive_cache_snapshot_test.dart`
- proves ordinary planning exposes text, path, and stroke cache primitives
  through `RenderPrimitiveCacheSnapshot` for painter consumption.

#### `test/surface/surface_camera_frame_output_test.dart`
- proves the public `CanvasSurface` passive frame path rebuilds both captured
  layer outputs after runtime camera pan while preserving ordinary paint plan
  identity and capturing the runtime preview source.

#### `test/guardrails/selection_boundary_checks_test.dart`
- proves InteractionEngine does not import concrete SelectionKernel or
  DocumentStoreKernel internals;
- proves interaction selection/document reads are routed through
  intent-specific immutable query ports.

#### `test/guardrails/frame_committed_facts_via_frame_facts_port_test.dart`
- proves production `lib/src/frame/**` code does not import concrete
  `DocumentStoreKernel`, `CommittedDocument`, family tables, resource
  tables, `DocumentProjectionCache`, drafts, or public projection internals
  for frame capture, row resolution, or descriptor lookup;
- proves frame committed facts, immutable row snapshots with stale
  structuralRevision/generation/orderToken rejection, immutable descriptor snapshots,
  and `resourceRevision` are obtained through `FrameFactsPort`;
- proves `FrameFactsPort` does not expose frame-owned render models,
  selection facts, resolver state, mutation APIs, or public document
  projection access.

#### Frame/cache guardrail proof tests
- `test/guardrails/frame_no_global_scene_sort_guardrail_test.dart`,
  `test/guardrails/frame_paint_plan_excludes_preview_delta_guardrail_test.dart`,
  `test/guardrails/frame_paint_plan_excludes_selection_state_guardrail_test.dart`,
  `test/guardrails/cache_keys_use_next_revisions_only_guardrail_test.dart`,
  `test/guardrails/cache_background_grid_not_element_visual_guardrail_test.dart`,
  `test/guardrails/cache_hot_caches_have_capacity_eviction_guardrail_test.dart`,
  and `test/guardrails/preview_selected_move_main_repaint_guardrail_test.dart`
  prove the frame, cache, and preview guardrail ids are registered,
  runner-backed or structurally checked where required, and reject fixtures
  containing only the forbidden contract shapes. The frame scene-sort proof
  covers direct sort calls, cascades, multi-line statements, and named
  comparator/helper indirection while preserving unrelated local scalar sorts.
  The ordinary-cache exclusion proofs use the guardrail-owned ordinary-cache
  surface registry, including `PaintPlanKey`, `OrdinaryPaintRecordKey`,
  `OrdinaryPaintRecordCacheEntry`, `PaintPlan`, `RenderElementRecord`, and
  registered row payloads.

Capability inventory rows require inventory-only tests. Current API
behavior is proved by focused API, subsystem, and integration tests, not by
mapping rows.
Runtime coverage must include api, edit, interaction, frame, spatial, geometry, codec/schema_v1, resources, surface, and diagnostics tests.

---
