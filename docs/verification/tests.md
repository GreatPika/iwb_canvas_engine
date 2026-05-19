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
- `test.api.canvas_field_update`
- `test.api_contract.canvas_field_update_static_semantics`
- `test.api_contract.no_undefined_public_type_references`
- `test.api_contract.no_legacy_public_symbols`
- `test.api_contract.dto_immutability`
- `test.api_contract.public_equality_policy`
- `test.api_contract.app_next_engine_adapter_compile_fixture`
- `test.guardrails.import_boundaries`
- `test.codec.schema_v1.known_fields_validation`
- `test.codec.schema_v1.resources_appkey_only`
- `test.codec.schema_v1.reject_unknown_element_kind`
- `test.codec.schema_v1.reject_unknown_resource_source_kind`
- `test.codec.decode_encode_no_runtime_side_effects`
- `test.diagnostics.sanitizer_and_public_projection`
- `test.resources.sync_image_resolver`
- `test.resources.app_owned_image_not_disposed`
- `test.resources.resource_dirty`
- `test.resources.mark_all_resources_dirty`
- `test.resources.painter_never_calls_resolver_directly`
- `test.resources.missing_result_suppressed_per_frame`
- `test.resources.surface_session_cache_lifecycle`
- `test.resources.resolver_swap_starts_fresh_cache`
- `test.resources.resolver_frame_budget`
- `test.resources.resolver_reentrancy_rejected`
- `test.api.typed_action_payloads`
- `test.edit.low_level_mutations_do_not_emit_actions`
- `test.interaction.commands_emit_user_actions`
- `test.flutter_bridge.interactive_false_pointer_routing`
- `test.flutter_bridge.interactive_false_active_session_cancel`
- `test.flutter_bridge.interactive_false_pending_line_preserved`
- `test.flutter_bridge.interactive_false_state_isolation`
- `test.flutter_bridge.single_active_surface`
- `test.flutter_bridge.surface_resource_session_lifecycle`
- `test.flutter_bridge.pointer_adapter_finite_normalization`
- `test.functional_ledger.legacy_capability_inventory`
- `test.functional_ledger.row_specific_tests`
- `test.api_contract.v1_scope_gate`
- `test.codec.constructor_and_schema_limits`
- `test.runtime.dispose_lifecycle`
- `test.runtime.runtime_state_publication`
- `test.runtime.load_document_state_publication`
- `test.runtime.interaction_settings_state`
- `test.store.read_document_projection`
- `test.store.no_projection_hot_path`
- `test.store.public_document_is_projection_only`
- `test.edit.sync_non_nested_async_stale`
- `test.edit.rollback`
- `test.edit.field_update_nullable_semantics`
- `test.edit.operation_matrix_effects`
- `test.edit.exact_touched_invalidation`
- `test.edit.typed_effects_no_frame_dependency`
- `test.edit.staged_document_load_success_failure`
- `test.geometry.hit_policy`
- `test.geometry.no_legacy_scene_order`
- `test.geometry.eraser_exact_budget_no_partial_commit`
- `test.spatial.touched_update`
- `test.spatial.no_full_clone_for_touched_update`
- `test.spatial.stale_generation_rejected`
- `test.spatial.fallback_budget_enforced`
- `test.frame.main_overlay_capture`
- `test.frame.no_live_runtime_read_in_painters`
- `test.frame.paint_plan_excludes_preview_delta`
- `test.frame.camera_pan_preserves_ordinary_paint_plan`
- `test.frame.cache_keys_do_not_use_legacy_snapshot_shape`
- `test.frame.cache_capacity_eviction_policy`
- `test.frame.selected_supplement_staging_no_global_sort`
- `test.interaction.preview_public_state`
- `test.interaction.state_machines`
- `test.interaction.move_resolver_reentrancy`
- `test.interaction.move_resolver_not_called_on_cancel_cleanup`
- `test.interaction.no_stale_terminal_commit`
- `test.interaction.text_edit_stale_commit_guard`
- `test.flutter_bridge.widget_paint`
- `test.benchmarks.required_cases`
- `test.guardrails.required_diagrams_present`
- `test.guardrails.blocking_suite`
Guardrails:
- `oracle.legacy_capability_inventory_complete`
- `api.functional_ledger_complete`
Do not assume:
- no donor reuse without ported or equivalent tests
<!-- CONTEXT:END -->

## 23. Tests

Required tests:

```text
test/api_contract/public_api_v1_compiles_as_written_test.dart
test/api_contract/public_readable_union_variants_test.dart
test/api_contract/preview_state_sealed_union_test.dart
test/api/canvas_field_update_test.dart
test/api_contract/canvas_field_update_static_semantics_test.dart
test/api_contract/no_undefined_public_type_references_test.dart
test/api_contract/no_legacy_public_symbols_test.dart
test/api_contract/dto_immutability_test.dart
test/api_contract/public_equality_policy_test.dart
test/api_contract/v1_scope_gate_test.dart
test/api_contract/app_next_engine_adapter_compile_fixture_test.dart
test/guardrails/import_boundaries_test.dart
test/guardrails/required_diagrams_present_test.dart
test/guardrails/blocking_suite_test.dart
test/functional_ledger/row_specific_tests_test.dart
test/benchmarks/required_cases_test.dart

test/codec/schema_v1/known_fields_validation_test.dart
test/codec/schema_v1/resources_appkey_only_test.dart
test/codec/schema_v1/reject_unknown_element_kind_test.dart
test/codec/schema_v1/reject_unknown_resource_source_kind_test.dart
test/codec/decode_encode_no_runtime_side_effects_test.dart
test/codec/constructor_and_schema_limits_test.dart
test/diagnostics/sanitizer_and_public_projection_test.dart

test/resources/sync_image_resolver_test.dart
test/resources/app_owned_image_not_disposed_test.dart
test/resources/resource_dirty_test.dart
test/resources/mark_all_resources_dirty_test.dart
test/resources/painter_never_calls_resolver_directly_test.dart
test/resources/missing_result_suppressed_per_frame_test.dart
test/resources/surface_session_cache_lifecycle_test.dart
test/resources/resolver_swap_starts_fresh_cache_test.dart
test/resources/resolver_frame_budget_test.dart
test/resources/resolver_reentrancy_rejected_test.dart

test/api/typed_action_payloads_test.dart
test/edit/low_level_mutations_do_not_emit_actions_test.dart
test/interaction/commands_emit_user_actions_test.dart

test/runtime/dispose_lifecycle_test.dart
test/runtime/runtime_state_publication_test.dart
test/runtime/load_document_state_publication_test.dart
test/runtime/interaction_settings_state_test.dart
test/flutter_bridge/interactive_false_pointer_routing_test.dart
test/flutter_bridge/interactive_false_active_session_cancel_test.dart
test/flutter_bridge/interactive_false_pending_line_preserved_test.dart
test/flutter_bridge/interactive_false_state_isolation_test.dart
test/flutter_bridge/single_active_surface_test.dart
test/flutter_bridge/surface_resource_session_lifecycle_test.dart
test/flutter_bridge/pointer_adapter_finite_normalization_test.dart
test/flutter_bridge/widget_paint_test.dart

test/store/read_document_projection_test.dart
test/store/no_projection_hot_path_test.dart
test/store/public_document_is_projection_only_test.dart
test/edit/sync_non_nested_async_stale_test.dart
test/edit/rollback_test.dart
test/edit/field_update_nullable_semantics_test.dart
test/edit/operation_matrix_effects_test.dart
test/edit/exact_touched_invalidation_test.dart
test/edit/typed_effects_no_frame_dependency_test.dart
test/edit/staged_document_load_success_failure_test.dart

`test.edit.operation_matrix_effects` covers expanded operation matrix dimensions:
touched state, public state revisions, internal revisions, spatial,
projection, resource effects, repaint, user-action events, no-op behavior, and
rollback behavior.

`test.codec.constructor_and_schema_limits` covers element transform admission
at public DTO construction and schema decode: non-invertible element
transforms reject with `fieldMustBeInvertible`, while `CanvasTransform` remains
the general affine value type.

`test.edit.field_update_nullable_semantics` covers
`CanvasElementUpdate.transform` validation for generated and dynamic field
updates: a non-invertible transform is rejected before draft mutation.

`test.edit.staged_document_load_success_failure` covers `loadDocument`
rejection of non-invertible element transforms before `PreparedDocumentLoad`
success, interaction interruption, repaint, action events, or public state
publication.

test/geometry/hit_policy_test.dart
test/geometry/no_legacy_scene_order_test.dart
test/geometry/eraser_exact_budget_no_partial_commit_test.dart
test/spatial/touched_update_test.dart
test/spatial/no_full_clone_for_touched_update_test.dart
test/spatial/stale_generation_rejected_test.dart
test/spatial/fallback_budget_enforced_test.dart
test/frame/main_overlay_capture_test.dart
test/frame/no_live_runtime_read_in_painters_test.dart
test/frame/cache_keys_do_not_use_legacy_snapshot_shape_test.dart
test/frame/cache_capacity_eviction_policy_test.dart
test/frame/paint_plan_excludes_preview_delta_test.dart
test/frame/paint_plan_excludes_selection_state_test.dart
test/frame/camera_pan_preserves_ordinary_paint_plan_test.dart
test/frame/selected_supplement_staging_no_global_sort_test.dart
test/interaction/preview_public_state_test.dart
test/interaction/state_machines_test.dart
test/interaction/move_resolver_reentrancy_test.dart
test/interaction/move_resolver_not_called_on_cancel_cleanup_test.dart
test/interaction/no_stale_terminal_commit_test.dart
test/interaction/text_edit_stale_commit_guard_test.dart
test/selection/runtime_owner_separation_test.dart
test/guardrails/selection_boundary_imports_test.dart
```

`test.geometry.hit_policy` covers corrupted committed hit rows: a
non-invertible element transform records only policy-gated diagnostics, returns
miss, continues candidate scan, and has no coarse fallback acceptance.

`test.diagnostics.sanitizer_and_public_projection` covers corrupted-row
diagnostic sanitization and the disabled diagnostics no-allocation hot-path
policy.

Guardrail test ownership:

`test/guardrails/**` owns executable proof tests that make cross-cutting
guardrails part of normal `dart test` and CI. `tool/guardrails/**` owns the
guardrail runner, runner metadata or manifests, and reusable structural check
logic. Simple guardrails may live entirely as tests. Shared scanner logic,
changed-aware routing, or logic used by both tests and the runner belongs under
`tool/guardrails/**`, with a thin test under `test/guardrails/**`.

The runner is only a dispatcher over proof commands. It must not replace
behavioral tests, and the required guardrail list remains owned by
`section_22_guardrails_machine_checks`.

```text
test/api_contract/app_next_engine_adapter_compile_fixture_test.dart
  -> compiles test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart;
  -> proves external application adapter code can use the public integration
     surface through package:iwb_canvas_engine/iwb_canvas_engine.dart only;
  -> rejects fixture imports of src/**, legacy package symbols, or internal
     runtime classes;
  -> covers runtime lifecycle, state/document observation, edit/load,
     selection/camera/tools, high-level commands, actions/text-edit requests,
     resources, and CanvasSurface construction with public resolver/style inputs.

test/api_contract/public_api_v1_compiles_as_written_test.dart
  -> compiles the exported API declarations in an empty consumer package;
  -> uses analyzer AST over exported public declarations to verify non-empty
     dartdoc summaries for api.exported_dartdoc_complete;
  -> uses analyzer AST over exported public classes to verify explicit Dart 3
     subtype policy modifiers for api.public_class_modifiers_explicit.

test/api_contract/no_undefined_public_type_references_test.dart
  -> verifies every exported signature type is exported or from Flutter/Dart SDK;
  -> uses analyzer AST over exported public signatures to reject FutureOr<T>
     returns, nullable async/container returns, and dynamic outside approved
     JSON or diagnostic boundaries for api.public_signature_shape;
  -> verifies metadata-bearing DTO signatures use exported CanvasMetadata and
     raw Map<String, Object?> metadata appears only at codec or diagnostic
     boundaries.

test/api_contract/dto_immutability_test.dart
  -> proves public DTO constructors defensively copy caller-owned Iterable, List,
     Set, Map, and metadata input;
  -> proves public collection getters and CanvasMetadata projections are
     unmodifiable and deep-frozen;
  -> proves invalid public construction is rejected before DTO exposure;
  -> proves public constructors accepting caller-provided values with documented
     runtime validation or sanitization are non-const factories, while
     marker/empty/default/private storage forms keep only approved const forms.

test/api_contract/preview_state_sealed_union_test.dart
  -> proves CanvasPreviewState is a sealed public union with exported readable
     concrete variants and stable CanvasPreviewKind values;
  -> proves CanvasStrokePreview is the shared public pencil/marker preview base;
  -> proves preview iterable payloads are defensively copied and unmodifiable;
  -> proves selected ids, pointer tokens, active pointer ids, session ids, and
     tool-discriminated generic stroke payloads are not public preview state.

test/guardrails/import_boundaries_test.dart
  -> verifies package-owned source paths obey the forbidden import matrix;
  -> rejects imports from another package's src/**;
  -> rejects concrete interaction imports of src/store and src/selection owner
     internals outside approved query-port abstractions;
  -> scans production lib/** Dart files for part/part of directives and allows
     them only through an explicit generated-code approval list.

test/functional_ledger/legacy_capability_inventory_test.dart
  -> verifies P1 legacy capability inventory rows have a capability, legacy
     oracle, and evidence focus without requiring next API mapping.

test/guardrails/blocking_suite_test.dart
  -> proves every mandatory blocking guardrail from
     section_22_guardrails_machine_checks is represented by executable proof;
  -> proves every mandatory blocking guardrail is included in the full
     guardrail runner suite.

test/runtime/dispose_lifecycle_test.dart
  -> proves runtime dispose keeps state.value readable;
  -> verifies dispose does not increment state.revisions.document and state
     only notifies during first dispose when active preview cleanup advances
     state.revisions.preview;
  -> verifies no public state notifications are delivered after dispose
     returns, repeated dispose is silent, and listeners can be removed after
     dispose.

test/runtime/runtime_state_publication_test.dart
  -> proves ordinary document edits publish one CanvasRuntimeState with
     state.revisions.document advanced and unrelated public domains unchanged;
  -> proves no-op edits and no-op runtime operations do not publish a new
     CanvasRuntimeState.

test/runtime/load_document_state_publication_test.dart
  -> proves successful loadDocument publishes exactly one post-install
     CanvasRuntimeState that includes document, selection, viewCamera, epoch,
     and conditional preview cleanup revisions;
  -> proves loadDocument failure publishes no public state snapshot.

test/runtime/interaction_settings_state_test.dart
  -> proves mode, draw tool, draw style, draw color, and pointer policy changes
     publish state.revisions.interaction without changing document,
     resourceVisual, or viewCamera revisions;
  -> proves selection and preview revisions are unchanged for no-cleanup
     settings changes, and advance only when the operation also owns draw-mode
     selection clear or active preview cleanup.

test/selection/runtime_owner_separation_test.dart
  -> proves selection-only changes publish state.revisions.selection without
     incrementing state.revisions.document, evicting DocumentProjectionCache,
     or updating SpatialKernel;
  -> proves document replacement, delete, clear, and eraser paths publish
     document and selection effects as one atomic CanvasRuntimeState;
  -> proves selectedOrder is derived from selectionRevision and
     structuralRevision, not stored as an independent source of truth.

test/frame/paint_plan_excludes_selection_state_test.dart
  -> proves ordinary PaintPlanCache keys and cached ordinary records exclude
     selected ids, selectionRevision, selection flags, and selected-move preview
     state;
  -> proves selection changes rebuild selection decoration without evicting the
     ordinary committed paint plan;
  -> proves selected element bounds changes rebuild SelectionDecorationPlan even
     when selection membership is unchanged;
  -> proves captured selectionStyle changes rebuild SelectionDecorationPlan
     without entering StaticBackgroundCache or ordinary PaintPlanCache identity.

test/interaction/preview_public_state_test.dart
  -> proves preview-only pointer changes publish state.revisions.preview without
     changing document, selection, resourceVisual, interaction, or viewCamera
     revisions and without emitting action events;
  -> proves cleanup against already-empty preview state is public-state silent.

test/resources/resource_dirty_test.dart
  -> proves markResourceDirty publishes state.revisions.resourceVisual without
     incrementing state.revisions.document, evicting public document projection,
     clearing selection, clearing preview, or emitting an action event.

test/frame/camera_pan_preserves_ordinary_paint_plan_test.dart
  -> proves CanvasCameraPort.setOffset and panBy publish
     state.revisions.viewCamera without incrementing state.revisions.document,
     invalidating public document projection, or changing persisted document
     camera;
  -> proves camera pan preserves ordinary PaintPlanCache entries while scheduling
     repaint for the main and overlay surfaces affected by the runtime view;
  -> proves backgroundRevision and gridRevision invalidate StaticBackgroundCache
     without invalidating ordinary PaintPlanCache entries;
  -> proves CanvasEdit.setCameraOffset changes persisted document camera through
     the explicit edit boundary, including the
     setCameraOffset(runtime.camera.offset) persistence path, and readDocument
     returns that persisted camera instead of the runtime view camera.

test/guardrails/selection_boundary_imports_test.dart
  -> proves InteractionEngine does not import concrete SelectionKernel or
     DocumentStoreKernel internals;
  -> proves interaction selection/document reads are routed through
     intent-specific immutable query ports.
```

Legacy capability inventory rows require inventory-only tests. Functional
ledger mappings still require row-specific next API tests.
Runtime coverage must include api, edit, interaction, frame, spatial, geometry, codec/schema_v1, resources, flutter_bridge, and diagnostics tests.

---
