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
  GuardrailEntry(id: 'api.no_legacy_public_types', suites: {'blocking', 'api'}),
  GuardrailEntry(
    id: 'api.public_exports_complete',
    suites: {'blocking', 'api'},
  ),
  GuardrailEntry(id: 'api.public_types_complete', suites: {'blocking', 'api'}),
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
