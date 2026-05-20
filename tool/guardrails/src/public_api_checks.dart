import 'guardrail_violation.dart';
import 'public_api_registry.dart';
import 'public_api_surface.dart';
import 'repository_paths.dart';

Future<List<GuardrailViolation>> checkPublicExportsComplete() async {
  final registryNames = readPublicApiRegistry();
  final surface = await resolvePublicApiSurface();
  final extra = surface.exportedNames.difference(registryNames);
  final missing = registryNames.difference(surface.exportedNames);

  return [
    if (extra.isNotEmpty)
      GuardrailViolation(
        guardrailId: 'api.public_exports_complete',
        path: 'lib/iwb_canvas_engine.dart',
        message: 'exports names absent from registry: ${_list(extra)}',
      ),
    if (missing.isNotEmpty)
      GuardrailViolation(
        guardrailId: 'api.public_exports_complete',
        path: 'docs/_registry/public_api_v1.yaml',
        message: 'registry names missing from public barrel: ${_list(missing)}',
      ),
  ];
}

Future<List<GuardrailViolation>> checkPublicTypesComplete({
  String? libraryPath,
}) async {
  final surface = await resolvePublicApiSurface(libraryPath: libraryPath);
  final undefined = collectUndefinedPublicTypeReferences(surface);

  if (undefined.isEmpty) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'api.public_types_complete',
      path: _displayPath(libraryPath),
      message: 'undefined public type references: ${_list(undefined)}',
    ),
  ];
}

Future<List<GuardrailViolation>> checkNoLegacyPublicTypes() async {
  final surface = await resolvePublicApiSurface();
  final exportedLegacy = surface.exportedNames.intersection(_legacySymbols);

  if (exportedLegacy.isEmpty) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'api.no_legacy_public_types',
      path: 'lib/iwb_canvas_engine.dart',
      message: 'exports retired legacy symbols: ${_list(exportedLegacy)}',
    ),
  ];
}

String _displayPath(String? libraryPath) {
  if (libraryPath == null) {
    return 'lib/iwb_canvas_engine.dart';
  }

  final prefix = '$repositoryRoot/';

  return libraryPath.startsWith(prefix)
      ? libraryPath.substring(prefix.length)
      : libraryPath;
}

String _list(Iterable<String> names) {
  final sorted = names.toList()..sort();

  return sorted.join(', ');
}

const _legacySymbols = {
  'SceneController',
  'SceneSnapshot',
  'NodeSpec',
  'NodePatch',
  'PatchField',
  'SceneWriteTxn',
  'SceneBuilder',
  'SceneCodec',
  'decodeScene',
  'decodeSceneFromJson',
  'encodeScene',
  'encodeSceneToJson',
  'schemaVersionWrite',
  'schemaVersionsRead',
};
