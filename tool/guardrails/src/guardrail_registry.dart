import 'dart:io';

import 'package:yaml/yaml.dart';

import 'repository_paths.dart';

enum GuardrailStatus { executable, deferred }

final class GuardrailEntry {
  const GuardrailEntry({
    required this.id,
    required this.suites,
    required this.status,
    this.deferredPhase,
  });

  final String id;
  final Set<String> suites;
  final GuardrailStatus status;
  final String? deferredPhase;
}

Map<String, GuardrailEntry> guardrailInventory() {
  final entries = <String, GuardrailEntry>{};

  for (final entry in _p0Entries) {
    entries[entry.id] = entry;
  }

  for (final entry in _deferredGuardrailPhases.entries) {
    entries[entry.key] = GuardrailEntry(
      id: entry.key,
      suites: const {'deferred'},
      status: GuardrailStatus.deferred,
      deferredPhase: entry.value,
    );
  }

  return entries;
}

Set<String> blockingGuardrailIds() {
  return _p0Entries.map((entry) => entry.id).toSet();
}

Set<String> suiteGuardrailIds(String suite) {
  return guardrailInventory().values
      .where((entry) => entry.status == GuardrailStatus.executable)
      .where((entry) => entry.suites.contains(suite))
      .map((entry) => entry.id)
      .toSet();
}

Set<String> mandatoryGuardrailIds() {
  return {
    ..._guardrailsFromVerificationDoc(),
    ..._guardrailsFromSectionRegistry(),
  };
}

Set<String> _guardrailsFromVerificationDoc() {
  final content = File(
    '$repositoryRoot/docs/verification/guardrails.md',
  ).readAsStringSync();
  final pattern = RegExp(r'\| `([^`]+)` \|');

  return pattern
      .allMatches(content)
      .map((match) => match.group(1))
      .nonNulls
      .toSet();
}

Set<String> _guardrailsFromSectionRegistry() {
  final sections =
      loadYaml(
            File(
              '$repositoryRoot/docs/_registry/sections.yaml',
            ).readAsStringSync(),
          )
          as YamlList;
  final ids = <String>{};

  for (final section in sections.cast<YamlMap>()) {
    final guardrails =
        (section['guardrails'] as YamlList?)?.cast<String>() ?? const [];
    ids.addAll(guardrails.where((id) => id != 'none'));
  }

  return ids;
}

const _p0Entries = [
  GuardrailEntry(
    id: 'api.no_legacy_public_types',
    suites: {'blocking', 'api'},
    status: GuardrailStatus.executable,
  ),
  GuardrailEntry(
    id: 'api.public_exports_complete',
    suites: {'blocking', 'api'},
    status: GuardrailStatus.executable,
  ),
  GuardrailEntry(
    id: 'api.public_types_complete',
    suites: {'blocking', 'api'},
    status: GuardrailStatus.executable,
  ),
  GuardrailEntry(
    id: 'core.no_legacy_imports',
    suites: {'blocking', 'core'},
    status: GuardrailStatus.executable,
  ),
  GuardrailEntry(
    id: 'core.import_boundaries',
    suites: {'blocking', 'core'},
    status: GuardrailStatus.executable,
  ),
  GuardrailEntry(
    id: 'core.no_unapproved_part_files',
    suites: {'blocking', 'core'},
    status: GuardrailStatus.executable,
  ),
  GuardrailEntry(
    id: 'core.no_scene_controller_shape_dependency',
    suites: {'blocking', 'core'},
    status: GuardrailStatus.executable,
  ),
  GuardrailEntry(
    id: 'core.no_node_spec_patch_shape_dependency',
    suites: {'blocking', 'core'},
    status: GuardrailStatus.executable,
  ),
  GuardrailEntry(
    id: 'core.single_runtime_root',
    suites: {'blocking', 'core'},
    status: GuardrailStatus.executable,
  ),
  GuardrailEntry(
    id: 'diagrams.all_required_present',
    suites: {'blocking', 'diagrams'},
    status: GuardrailStatus.executable,
  ),
];

const _deferredGuardrailPhases = {
  'api.dto_immutability': 'P1.5',
  'api.equality_policy_explicit': 'P1.5',
  'api.exported_dartdoc_complete': 'P1.5',
  'api.functional_ledger_complete': 'P1.5',
  'api.id_validation_no_extension_type_escape': 'P1.5',
  'api.integration_surface_complete': 'P1.5',
  'api.no_undefined_public_type_references': 'P1.5',
  'api.preview_state_sealed_union_publicly_readable': 'P1.5',
  'api.public_api_compiles_as_written': 'P1.5',
  'api.public_class_modifiers_explicit': 'P1.5',
  'api.public_signature_shape': 'P1.5',
  'api.resource_source_app_key_publicly_readable': 'P1.5',
  'api.v1_scope_gate_green_before_freeze': 'P1.5',
  'cache.background_grid_not_element_visual': 'P9',
  'cache.hot_caches_have_capacity_eviction': 'P9',
  'cache.keys_use_next_revisions_only': 'P9',
  'codec.known_fields_validated': 'P3',
  'codec.no_runtime_side_effects': 'P3',
  'codec.schema_v1_exact': 'P3',
  'diagnostics.disabled_no_alloc_hot_path': 'P3',
  'diagnostics.sanitized_public_projection': 'P3',
  'edit.no_global_invalidation_except_replacement': 'P5',
  'edit.operation_matrix_complete': 'P5',
  'edit.rollback_no_effects': 'P5',
  'edit.stale_handle_rejected': 'P5',
  'edit.sync_non_nested': 'P5',
  'edit.typed_effects_no_frame_dependency': 'P5',
  'events.commands_emit_user_actions': 'P5',
  'events.low_level_edit_no_user_actions': 'P5',
  'events.runtime_created_timestamps_monotonic': 'P5',
  'frame.committed_facts_via_frame_facts_port': 'P9',
  'frame.no_global_scene_sort': 'P9',
  'frame.paint_plan_excludes_preview_delta': 'P9',
  'frame.paint_plan_excludes_selection_state': 'P9',
  'geometry.eraser_exact_budget_no_partial': 'P8',
  'geometry.no_legacy_scene_order': 'P8',
  'interaction.no_concrete_selection_imports': 'P10',
  'interaction.no_concrete_store_imports': 'P10',
  'interaction.no_resolver_on_cancel_paths': 'P10',
  'interaction.no_stale_terminal_commit': 'P10',
  'interaction.pointer_cleanup_coordinator_only': 'P10',
  'interaction.text_edit_stale_commit_guard': 'P1.5',
  'load.prepares_before_interrupt': 'P6',
  'load.success_interrupts_before_install': 'P6',
  'oracle.legacy_capability_inventory_complete': 'P1',
  'preview.selected_move_main_repaint': 'P10',
  'projection.only_explicit_read_paths': 'P4',
  'resources.app_key_only': 'P7',
  'resources.dirty_no_document_revision': 'P7',
  'resources.mutation_inside_edit_only': 'P7',
  'resources.no_same_frame_missing_retry': 'P7',
  'resources.resolver_boundary_owned_by_surface_session': 'P7',
  'resources.resolver_frame_budget': 'P7',
  'resources.resolver_reentrancy_rejected': 'P7',
  'selection.owner_separate_from_document': 'P4',
  'spatial.fallback_budget_enforced': 'P8',
  'spatial.no_full_clone_ordinary_edit': 'P8',
  'spatial.stale_candidate_rejected': 'P8',
  'store.no_public_document_live_state': 'P4',
  'surface.interactive_false_pending_line_preserved': 'P1.5',
  'surface.pointer_samples_normalized_before_runtime': 'P10',
};
