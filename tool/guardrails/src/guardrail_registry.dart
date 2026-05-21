final class GuardrailEntry {
  const GuardrailEntry({required this.id, required this.suites});

  final String id;
  final Set<String> suites;
}

Map<String, GuardrailEntry> guardrailInventory() {
  return {for (final entry in _blockingEntries) entry.id: entry};
}

Set<String> blockingGuardrailIds() {
  return _blockingEntries.map((entry) => entry.id).toSet();
}

Set<String> suiteGuardrailIds(String suite) {
  return guardrailInventory().values
      .where((entry) => entry.suites.contains(suite))
      .map((entry) => entry.id)
      .toSet();
}

const _blockingEntries = [
  GuardrailEntry(
    id: 'api.integration_surface_complete',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(id: 'api.no_legacy_public_types', suites: {'blocking', 'api'}),
  GuardrailEntry(
    id: 'api.public_exports_complete',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(id: 'api.public_types_complete', suites: {'blocking', 'api'}),
  GuardrailEntry(
    id: 'api.public_api_compiles_as_written',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.resource_source_app_key_publicly_readable',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.preview_state_sealed_union_publicly_readable',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.exported_dartdoc_complete',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.public_class_modifiers_explicit',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.no_public_api_import_cycles',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(id: 'api.public_signature_shape', suites: {'blocking', 'api'}),
  GuardrailEntry(
    id: 'api.no_undefined_public_type_references',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(id: 'api.dto_immutability', suites: {'blocking', 'api'}),
  GuardrailEntry(
    id: 'api.equality_policy_explicit',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(
    id: 'api.id_validation_no_extension_type_escape',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(id: 'codec.schema_v1_exact', suites: {'blocking', 'codec'}),
  GuardrailEntry(
    id: 'codec.known_fields_validated',
    suites: {'blocking', 'codec'},
  ),
  GuardrailEntry(
    id: 'codec.no_runtime_side_effects',
    suites: {'blocking', 'codec'},
  ),
  GuardrailEntry(
    id: 'diagnostics.disabled_no_alloc_hot_path',
    suites: {'blocking', 'diagnostics'},
  ),
  GuardrailEntry(
    id: 'diagnostics.sanitized_public_projection',
    suites: {'blocking', 'diagnostics'},
  ),
  GuardrailEntry(id: 'core.no_legacy_imports', suites: {'blocking', 'core'}),
  GuardrailEntry(id: 'core.import_boundaries', suites: {'blocking', 'core'}),
  GuardrailEntry(
    id: 'core.no_unapproved_part_files',
    suites: {'blocking', 'core'},
  ),
  GuardrailEntry(
    id: 'core.no_scene_controller_shape_dependency',
    suites: {'blocking', 'core'},
  ),
  GuardrailEntry(
    id: 'core.no_node_spec_patch_shape_dependency',
    suites: {'blocking', 'core'},
  ),
  GuardrailEntry(id: 'core.single_runtime_root', suites: {'blocking', 'core'}),
];
