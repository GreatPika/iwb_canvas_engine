<!-- CONTEXT:BEGIN -->
Registry id: `section_23_tests`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/tests.md`
Owns:
- 23. Tests
Must read before editing:
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_22_guardrails_machine_checks` -> `docs/verification/guardrails.md`
Feeds phases:
- `P0`
- `P1`
- `P2`
- `P3`
- `P4`
- `P5`
- `P6`
- `P7`
- `P8`
- `P9`
- `P10`
- `P11`
- `P12`
- `P13`
- `P14`
Related donors:
- `direct_numeric_policy`
- `direct_local_bounds_policy`
- `direct_paint_admission`
- `direct_scan_resistant_cache`
- `direct_pointer_tap_tracking`
- `direct_flutter_pointer_routing`
- `direct_gesture_ownership`
- `direct_structure_validation`
- `foundation_transform2d`
- `foundation_core_geometry`
- `foundation_contract_limits`
- `foundation_error_contract`
- `foundation_validators`
- `foundation_tri_state_patch_semantics`
- `foundation_immutable_collections`
- `foundation_pointer_input_contract`
- `foundation_action_event_immutability`
- `geometry_node_geometry`
- `geometry_hit_test`
- `render_geometry_builder`
- `geometry_interactive_geometry`
- `geometry_eraser_exact_hit`
- `spatial_scene_spatial_index`
- `spatial_index_cache`
- `store_scene_controller_read_paths`
- `snapshot_paint_admission_bounds`
- `snapshot_paint_candidates`
- `frame_render_state`
- `scene_view_runtime_fast_path`
- `paint_candidate_stage`
- `scene_painter_frame`
- `scene_render_caches`
- `static_layer_cache`
- `text_stroke_path_metrics_caches`
- `dto_snapshot_behavior`
- `dto_node_spec_behavior`
- `dto_boundary_schema`
- `dto_scene_value_validation`
- `dto_node_boundary_mapping`
- `dto_document_helpers`
- `codec_guards`
- `codec_json_require`
- `codec_json_parse`
- `codec_metadata_decode`
- `codec_layer_decode`
- `codec_node_common_decode`
- `codec_family_decode`
- `codec_scene_codec_flow`
- `codec_validation_path_surface`
- `tooling_schema_family_parity`
- `interaction_pointer_host`
- `interaction_pointer_session`
- `interaction_pointer_normalizer`
- `interaction_event_dispatcher`
- `interaction_double_tap_router`
- `interaction_gesture_runtime`
- `interaction_move_session`
- `interaction_draw_coordinator`
- `interaction_mutation_boundary`
- `staged_load_runtime_materialization`
- `validated_import_draft`
- `interaction_public_controller_behavior`
- `avoid_scene_controller_facades`
- `avoid_interactive_runtime_whole`
- `avoid_scene_builder_public_architecture`
- `avoid_scene_codec_whole`
- `avoid_scene_store_controller_whole`
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
- `test.api_contract.no_legacy_public_symbols`
- `test.api_contract.dto_immutability`
- `test.api_contract.public_equality_policy`
- `test.api_contract.app_next_engine_adapter_compile_fixture`
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
- `test.flutter_bridge.interactive_false_pointer_routing`
- `test.flutter_bridge.interactive_false_active_session_cancel`
- `test.flutter_bridge.interactive_false_pending_line_preserved`
- `test.flutter_bridge.interactive_false_state_isolation`
- `test.flutter_bridge.single_active_surface`
- `test.flutter_bridge.surface_resource_session_lifecycle`
- `test.flutter_bridge.pointer_adapter_finite_normalization`
- `test.codec.constructor_and_schema_limits`
- `test.runtime.dispose_lifecycle`
- `test.runtime.runtime_state_publication`
- `test.smoke.public_incremental_smoke`
- `test.runtime.load_document_state_publication`
- `test.runtime.interaction_settings_state`
- `test.store.read_document_projection`
- `test.store.no_projection_hot_path`
- `test.store.public_document_is_projection_only`
- `test.edit.sync_non_nested_async_stale`
- `test.edit.rollback`
- `test.edit.field_update_admission_effects`
- `test.edit.edit_matrix_effects`
- `test.edit.exact_touched_invalidation`
- `test.edit.typed_effects_no_frame_dependency`
- `test.edit.staged_document_load_success_failure`
- `test.spatial.committed_spatial_read_boundary`
- `test.geometry.geometry_spatial_donor_mapping`
- `test.geometry.hit_policy`
- `test.geometry.no_legacy_scene_order`
- `test.geometry.eraser_exact_budget_inputs`
- `test.spatial.tile_outlier_membership`
- `test.spatial.touched_update`
- `test.spatial.no_full_clone_for_touched_update`
- `test.spatial.stale_generation_rejected`
- `test.spatial.fallback_budget_enforced`
- `test.spatial.invalid_index_fallback`
- `test.spatial.runtime_delivery_order`
- `test.frame.main_overlay_capture`
- `test.frame.no_live_runtime_read_in_painters`
- `test.guardrails.frame_committed_facts_via_frame_facts_port`
- `test.frame.frame_spatial_paint_admission`
- `test.frame.frame_drawable_policy`
- `test.frame.marquee_captured_style`
- `test.frame.paint_plan_write_all_or_nothing`
- `test.guardrails.geometry_no_legacy_scene_order`
- `test.guardrails.geometry_eraser_exact_budget_inputs`
- `test.guardrails.spatial_no_full_clone_ordinary_edit`
- `test.guardrails.spatial_stale_candidate_rejected`
- `test.guardrails.spatial_fallback_budget_enforced`
- `test.frame.paint_plan_excludes_preview_delta`
- `test.frame.camera_pan_preserves_ordinary_paint_plan`
- `test.frame.cache_keys_do_not_use_legacy_snapshot_shape`
- `test.frame.cache_capacity_eviction_policy`
- `test.frame.selected_supplement_staging_no_global_sort`
- `test.interaction.preview_public_state`
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
- `test.flutter_bridge.widget_paint`
- `test.benchmarks.required_cases`
- `test.guardrails.blocking_suite`
Guardrails:
- `none`
Do not assume:
- no donor reuse without ported or equivalent tests
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
- `test/api_contract/no_legacy_public_symbols_test.dart`
- `test/api_contract/dto_immutability_test.dart`
- `test/api_contract/public_equality_policy_test.dart`
- `test/api_contract/public_signature_shape_test.dart`
- `test/api_contract/id_validation_no_extension_type_escape_test.dart`
- `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart`
- `test/api_contract/public_facade_wrapper_compatibility_test.dart`
- `test/contracts/contract_declaration_shape_test.dart`
- `test/contracts/internal_seam_shape_test.dart`
- `test/guardrails/public_api_declaration_checks_test.dart`
- `test/guardrails/public_api_import_cycles_test.dart`
- `test/guardrails/import_boundaries_test.dart`
- `test/guardrails/owner_dag_import_boundaries_test.dart`
- `test/architecture_graph/phase_closure_checker_test.dart`
- `test/guardrails/frame_committed_facts_via_frame_facts_port_test.dart`
- `test/guardrails/blocking_suite_test.dart`
- `test/benchmarks/required_cases_test.dart`

The owner-DAG proof is split intentionally: `owner_dag_import_boundaries_test`
checks wrapper export, named facade bridge, implementation-to-api,
contracts-to-api, and contracts-to-implementation fixtures, while
`phase_closure_checker_test` proves the same forbidden-edge classes in
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
- `test/runtime/dispose_lifecycle_test.dart`
- `test/runtime/runtime_state_publication_test.dart`
- `test/smoke/public_incremental_smoke_test.dart`
- `test/runtime/load_document_state_publication_test.dart`
- `test/runtime/interaction_settings_state_test.dart`
- `test/flutter_bridge/interactive_false_pointer_routing_test.dart`
- `test/flutter_bridge/interactive_false_active_session_cancel_test.dart`
- `test/flutter_bridge/interactive_false_pending_line_preserved_test.dart`
- `test/flutter_bridge/interactive_false_state_isolation_test.dart`
- `test/flutter_bridge/single_active_surface_test.dart`
- `test/flutter_bridge/surface_resource_session_lifecycle_test.dart`
- `test/flutter_bridge/pointer_adapter_finite_normalization_test.dart`
- `test/flutter_bridge/widget_paint_test.dart`
- `test/flutter_bridge/surface_camera_frame_output_test.dart`
- `test/store/read_document_projection_test.dart`
- `test/store/no_projection_hot_path_test.dart`
- `test/store/public_document_is_projection_only_test.dart`
- `test/edit/sync_non_nested_async_stale_test.dart`
- `test/edit/rollback_test.dart`
- `test/edit/field_update_admission_effects_test.dart`
- `test/edit/edit_matrix_effects_test.dart`
- `test/edit/exact_touched_invalidation_test.dart`
- `test/edit/typed_effects_no_frame_dependency_test.dart`
- `test/edit/staged_document_load_success_failure_test.dart`
- `test/spatial/committed_spatial_read_boundary_test.dart`
- `test/geometry/geometry_spatial_donor_mapping_test.dart`
- `test/geometry/hit_policy_test.dart`
- `test/geometry/no_legacy_scene_order_test.dart`
- `test/geometry/eraser_exact_budget_inputs_test.dart`
- `test/spatial/tile_outlier_membership_test.dart`
- `test/spatial/touched_update_test.dart`
- `test/spatial/no_full_clone_for_touched_update_test.dart`
- `test/spatial/stale_generation_rejected_test.dart`
- `test/spatial/fallback_budget_enforced_test.dart`
- `test/spatial/invalid_index_fallback_test.dart`
- `test/spatial/runtime_delivery_order_test.dart`
- `test/api/canvas_runtime_preview_test.dart`
- `test/frame/main_overlay_capture_test.dart`
- `test/frame/frame_donor_mapping_test.dart`
- `test/frame/no_live_runtime_read_in_painters_test.dart`
- `test/frame/frame_spatial_paint_admission_test.dart`
- `test/frame/frame_drawable_policy_test.dart`
- `test/frame/marquee_captured_style_test.dart`
- `test/frame/paint_plan_write_all_or_nothing_test.dart`
- `test/frame/paint_asset_binding_service_test.dart`
- `test/frame/repaint_bus_output_test.dart`
- `test/frame/static_background_plan_test.dart`
- `test/frame/cache_keys_do_not_use_legacy_snapshot_shape_test.dart`
- `test/frame/cache_capacity_eviction_policy_test.dart`
- `test/frame/paint_plan_excludes_preview_delta_test.dart`
- `test/frame/paint_plan_excludes_selection_state_test.dart`
- `test/frame/camera_pan_preserves_ordinary_paint_plan_test.dart`
- `test/frame/selected_supplement_staging_no_global_sort_test.dart`
- `test/frame/selected_move_main_repaint_test.dart`
- `test/frame/marquee_overlay_repaint_test.dart`
- `test/interaction/preview_public_state_test.dart`
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
- `test/guardrails/selection_boundary_imports_test.dart`
- `test/guardrails/geometry_no_legacy_scene_order_guardrail_test.dart`
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
- `test/guardrails/preview_selected_move_main_repaint_guardrail_test.dart`

### Behavioral Coverage Notes

`test.edit.edit_matrix_effects` covers expanded operation matrix dimensions:
touched state, public state revisions, internal revisions, spatial,
projection, resource effects, repaint, user-action events, no-op behavior, and
rollback behavior.

`test.api.runtime_timestamp_order` covers the public runtime timestamp
contract for committed action events: nullable or backwards `timestampMs` hints
resolve through one runtime-local monotonic cursor, while loadDocument and
dispose stream-close paths create no timestamped action output.
`test.interaction.runtime_created_timestamps_monotonic` remains the
contract-level proof area for non-action runtime-created timestamp outputs
owned by later interaction phases.

`test.codec.constructor_and_schema_limits` covers element transform admission
at public DTO construction and schema decode: non-invertible element
transforms reject with `fieldMustBeInvertible`, while `CanvasTransform` remains
the general affine value type.

`test.edit.field_update_admission_effects` covers field-update admission and
effects: nullable clears, dynamic non-nullable clear rejection,
non-invertible transform rejection, mismatched update-kind rejection, geometry
revision effects, and selection pruning.

`test.edit.staged_document_load_success_failure` covers `loadDocument`
rejection of non-invertible element transforms before `PreparedDocumentLoad`
success, interaction interruption, repaint, action events, or public state
publication.

P8 `test.geometry.hit_policy` coverage for corrupted committed hit rows proves
the implemented behavior: a non-invertible element transform returns miss,
continues candidate scan, has no coarse fallback acceptance, mutates no state,
and allocates no DiagnosticsHub record. The policy-gated corrupted-row
DiagnosticsHub route is deferred after P8.

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
guardrails part of normal `dart test` and CI. `tool/guardrails/**` owns the
guardrail runner, runner metadata or manifests, and reusable structural check
logic. Simple guardrails may live entirely as tests. Shared scanner logic or
logic used by both tests and the runner belongs under `tool/guardrails/**`,
with a thin test under `test/guardrails/**`.

The runner is only a dispatcher over proof commands. It must not replace
behavioral tests, and the required guardrail list remains owned by
`section_22_guardrails_machine_checks`.

### Test Responsibilities

#### `test/api_contract/app_next_engine_adapter_compile_fixture_test.dart`
- compiles test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart;
- proves external application adapter code can use the public integration
  surface through package:iwb_canvas_engine/iwb_canvas_engine.dart only;
- rejects fixture imports of src/\*\*, legacy package symbols, or internal
  runtime classes;
- covers runtime lifecycle, state/document observation, edit/load,
  selection/camera/tools, high-level commands, actions/context-action
  requests, guarded text commit, resources, and CanvasSurface construction
  with public resolver/style inputs.

#### `test/api_contract/public_api_v1_compiles_as_written_test.dart`
- compiles the exported API declarations in an empty consumer package;
- instantiates and calls P2-owned public constructors, getters, methods,
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
- proves the executable P0 hard-boundary guardrail ids are represented in
  runner inventory;
- proves the full guardrail runner, `--suite=api`, `--suite=core`, and
  explicit `--guardrail=<id>` selection modes execute the intended P0 ids;
- proves unknown or empty suite selection fails instead of silently running
  an unintended guardrail set.

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
  decode schema v1 documents, construct CanvasRuntime, observe initial state
  and readDocument output, and perform public selection, resource, edit, and
  load operations;
- appends P8 public compatibility coverage for background geometry,
  overlapping transformed content, one public geometry-changing edit, and a
  replacement geometry-rich load while asserting only public runtime/document
  outcomes;
- appends P9 public compatibility coverage for reading `runtime.preview` and
  pumping a resource-free `CanvasSurface` through the public API until the
  `ValueKey<String>('iwb_canvas_surface.paint_host')` `CustomPaint` host is
  present;
- appends public interaction compatibility coverage for non-throwing tool,
  empty context-request stream, marquee replacement selection, selected-move
  preview and resolved commit, typed action delivery, remove-element command,
  unknown text-edit no-op, and clear-content command behavior;
- appends P11 draw coverage for pencil and marker stroke previews, two-tap
  line pending/endpoint previews, public `CanvasSurface(interactive: false)`
  pending-line preservation, committed stroke/line document elements, and typed
  draw action delivery after accepted state publication;
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

#### `test/geometry/geometry_spatial_donor_mapping_test.dart`
- proves every required P8 geometry/spatial donor is mapped to copied,
  adapted, rejected, or deferred ownership evidence;
- proves forbidden legacy scene/controller/codec/cache-shell structures remain
  excluded from the P8 implementation.

#### `test/geometry/eraser_exact_budget_inputs_test.dart`
- proves P8 eraser corridor, exact-hit input limits, and preview/terminal
  candidate and exact-check budget input shapes;
- intentionally leaves terminal cleanup/no-op commit behavior to P12.

#### `test/spatial/tile_outlier_membership_test.dart`
- proves tile membership, outlier routing, max-cells behavior, and query
  candidate ordering for the implemented `SpatialKernel` indexes.

#### `test/spatial/invalid_index_fallback_test.dart`
- proves invalid spatial index fallback returns typed invalid/budget results
  without silently scanning the full scene.

#### `test/spatial/runtime_delivery_order_test.dart`
- proves `RuntimeRoot` applies spatial update/rebuild delivery before public
  runtime state publication and before observer callbacks can run.

#### P8 guardrail proof tests
- `test/guardrails/geometry_no_legacy_scene_order_guardrail_test.dart`,
  `test/guardrails/geometry_eraser_exact_budget_inputs_guardrail_test.dart`,
  `test/guardrails/spatial_no_full_clone_ordinary_edit_guardrail_test.dart`,
  `test/guardrails/spatial_stale_candidate_rejected_guardrail_test.dart`, and
  `test/guardrails/spatial_fallback_budget_enforced_guardrail_test.dart`
  prove the P8 guardrail ids are registered, runner-backed where structural
  proof is required, and fail on fixtures containing the forbidden pattern.

#### `test/runtime/load_document_state_publication_test.dart`
- proves successful loadDocument publishes exactly one post-install
  CanvasRuntimeState that includes document, selection, viewCamera, epoch,
  and conditional preview cleanup revisions;
- proves loadDocument failure publishes no public state snapshot.

#### `test/runtime/interaction_settings_state_test.dart`
- proves mode, draw tool, draw style, draw color, and pointer policy changes
  publish state.revisions.interaction without changing document,
  resourceVisual, or viewCamera revisions;
- proves selection and preview revisions are unchanged for no-cleanup
  settings changes, and advance only when the operation also owns draw-mode
  selection clear or active preview cleanup.

#### P10 public command and tool tests
- `test/api/selection_port_test.dart` proves direct public selection changes
  update the selection revision domain without emitting user actions.
- `test/api/selection_transform_commands_test.dart` proves public selection
  transform/delete command eligibility, transform math, pivot selection,
  document-order ids, no-op behavior, selection pruning, validation errors,
  and typed action emission.
- `test/api/command_port_actions_test.dart` proves command-port remove, clear,
  and unknown text-edit behavior plus their action payloads.
- `test/api/tool_port_settings_test.dart` proves P10 tool-port compatibility:
  initial settings are visible, effective changes advance interaction
  revision, no-ops stay silent, active sessions clean up on setting changes,
  pencil draw-mode pointer input publishes preview-only public state, double
  tap remains P12 unsupported, and context-action requests are a non-throwing
  empty stream.
- `test/api/runtime_timestamp_order_test.dart` proves runtime-created action
  timestamps are resolved through one runtime-local monotonic cursor.
- `test/runtime/command_facts_port_test.dart` proves immutable command fact
  bundles, document order, center pivot, removed-resource facts, and no
  interaction dependency.
- `test/runtime/load_interaction_cleanup_test.dart` proves load and dispose
  use interaction-owned cleanup without post-install interaction calls.

#### P11 draw tool tests
- `test/interaction/draw_stroke_machine_test.dart` proves pencil and marker
  stroke decisions, duplicate-point handling, and max-point replacement.
- `test/interaction/draw_stroke_engine_test.dart` proves pencil and marker
  preview publication, commit intents, second-pointer ignore, cancel/stale
  cleanup, and no timestamp resolution on rejected stroke terminals.
- `test/interaction/line_machine_test.dart` proves two-tap line decisions,
  pending-line facts, endpoint preview facts, and line commit intent payload.
- `test/interaction/line_engine_test.dart` proves accepted first-tap pending
  preview timestamps, rejected first-tap timestamp silence, endpoint preview
  and commit intents, same-point line acceptance, stale/invalid/cancel cleanup,
  and pending-line ownership behavior.
- `test/runtime/draw_commit_delivery_test.dart` proves accepted pencil, marker,
  and line commits create public stroke/line elements through the edit kernel,
  emit typed draw actions after public state publication, preserve
  programmatic `CanvasEdit.addElement` action silence, and roll back failed
  draw delivery without action or timestamp advancement.
- `test/runtime/draw_cleanup_integration_test.dart` proves draw cleanup paths,
  load success, load failure, `interactive=false`, settings changes, cancel,
  and no-op terminals do not reserve the next draw output timestamp.
- `test/flutter_bridge/interactive_false_pending_line_preserved_test.dart`
  proves public `CanvasSurface(interactive: false)` preserves non-owned
  pending line state, clears active endpoint state, and cleans the old runtime
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
  guardrails are runner-backed or structurally checked for the P11 draw and
  line owner surfaces.
- `test/architecture_graph/generated_graph_views_test.dart` proves generated
  architecture graph Mermaid views are reproducible for the selected P11 phase
  and stay synchronized with `docs/architecture/architecture_graph.yaml`.

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
- proves the frame-owned drawable policy renders one-point committed strokes,
  one-point overlay stroke previews, one-point eraser corridors, and same-point
  lines through explicit point or circle commands;
- proves empty point lists remain no-op draw inputs.

#### `test/frame/marquee_captured_style_test.dart`
- proves marquee overlay primitives carry captured selection style color,
  stroke width, and fill opacity;
- proves overlay painting uses those primitive fields instead of live style
  state.

#### `test/frame/paint_plan_excludes_selection_state_test.dart`
- proves OrdinaryPaintRecordCache keys and cached ordinary records exclude
  selected ids, selectionRevision, selection flags, and selected-move preview
  state;
- proves selection changes rebuild selection decoration without evicting the
  ordinary committed paint plan;
- proves selected element bounds changes rebuild SelectionDecorationPlan even
  when selection membership is unchanged;
- proves captured selectionStyle changes rebuild SelectionDecorationPlan
  without entering StaticBackgroundCache or OrdinaryPaintRecordCache identity.

#### `test/interaction/preview_public_state_test.dart`
- proves preview-only pointer changes publish state.revisions.preview without
  changing document, selection, resourceVisual, interaction, or viewCamera
  revisions and without emitting action events;
- proves cleanup against already-empty preview state is public-state silent.

#### P10 interaction seam tests
- `test/interaction/interaction_declarations_test.dart` proves the required
  P10 interaction declarations live in their owning files instead of umbrella
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
  normalized world rects, spatial/exact filtering, stale/deleted skipping,
  unchanged-selection cleanup, changed-selection commit, previous/next
  selection action facts, and document-order action ids.

#### `test/interaction/pointer_tool_cleanup_coordinator_test.dart`
- proves `PointerToolCleanupCoordinator` outcomes for cleanup reason plus
  ownership context: selected-move cleanup targets main repaint, overlay
  previews target overlay repaint, no-preview cleanup is public-state silent,
  active token/session facts are released before public effects, non-owned
  pending line state is preserved on `interactive=false`, line-owned cleanup
  clears pending line state, pending context tap cleanup emits no context
  request, no resolver runs on cleanup-only paths, stale terminal cleanup
  creates no commit intent, and cleanup emits no user action.

#### P10 frame and interaction guardrail proof tests
- `test/frame/selected_move_main_repaint_test.dart` and
  `test/frame/marquee_overlay_repaint_test.dart` prove selected-move preview is
  main-only and marquee preview is overlay-only through the frame repaint
  output fixture.
- `test/guardrails/action_after_state_guardrail_test.dart` proves
  state-before-action ordering is runner-backed and rejects inverted action
  fixture order.
- `test/guardrails/interaction_guardrail_enforcement_test.dart` proves P10
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

#### `test/flutter_bridge/surface_camera_frame_output_test.dart`
- proves the public `CanvasSurface` passive frame path rebuilds captured frame
  output after runtime camera pan while preserving ordinary paint plan identity
  and capturing the runtime preview source.

#### `test/guardrails/selection_boundary_imports_test.dart`
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

#### P9 frame/cache guardrail proof tests
- `test/guardrails/frame_no_global_scene_sort_guardrail_test.dart`,
  `test/guardrails/frame_paint_plan_excludes_preview_delta_guardrail_test.dart`,
  `test/guardrails/frame_paint_plan_excludes_selection_state_guardrail_test.dart`,
  `test/guardrails/cache_keys_use_next_revisions_only_guardrail_test.dart`,
  `test/guardrails/cache_background_grid_not_element_visual_guardrail_test.dart`,
  `test/guardrails/cache_hot_caches_have_capacity_eviction_guardrail_test.dart`,
  and `test/guardrails/preview_selected_move_main_repaint_guardrail_test.dart`
  prove the P9 frame, cache, and preview guardrail ids are registered,
  runner-backed or structurally checked where required, and reject fixtures
  containing only the forbidden contract shapes. The frame scene-sort proof
  covers direct sort calls, cascades, multi-line statements, and named
  comparator/helper indirection while preserving unrelated local scalar sorts.
  The ordinary-cache exclusion proofs use the guardrail-owned ordinary-cache
  surface registry, including `PaintPlanKey`, `OrdinaryPaintRecordKey`,
  `OrdinaryPaintRecordCacheEntry`, `PaintPlan`, `RenderElementRecord`, and
  registered row payloads.

Legacy capability inventory rows require inventory-only tests. Next API
behavior is proved by focused API, subsystem, and integration tests, not by
mapping rows.
Runtime coverage must include api, edit, interaction, frame, spatial, geometry, codec/schema_v1, resources, flutter_bridge, and diagnostics tests.

---
