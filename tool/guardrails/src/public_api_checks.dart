import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

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

Future<List<GuardrailViolation>> checkApiFacadesDoNotExportInternal({
  List<String>? facadePaths,
}) async {
  final paths = facadePaths ?? _apiFacadePaths();
  final collection = AnalysisContextCollection(
    includedPaths: [repositoryRoot],
    sdkPath: analysisDartSdkPath,
  );
  final violations = <GuardrailViolation>[];

  try {
    for (final path in paths) {
      final context = collection.contextFor(path);
      final result = await context.currentSession.getResolvedLibrary(path);
      if (result is! ResolvedLibraryResult) {
        throw StateError('Could not resolve $path: $result');
      }
      _throwOnErrorDiagnostics(result);

      final leaked = _exportedInternalNames(
        result.element.exportNamespace.definedNames2,
      );
      if (leaked.isEmpty) {
        continue;
      }

      violations.add(
        GuardrailViolation(
          guardrailId: 'api.facades_do_not_export_internal',
          path: _displayPath(path),
          message: 'API facade exports @internal names: ${_list(leaked)}',
        ),
      );
    }
  } finally {
    await collection.dispose();
  }

  return violations;
}

Future<List<GuardrailViolation>> checkPublicTypesComplete({
  String? libraryPath,
}) {
  return _checkUndefinedPublicTypeReferences(
    guardrailId: 'api.public_types_complete',
    libraryPath: libraryPath,
  );
}

List<String> _apiFacadePaths() {
  final directory = Directory('$repositoryRoot/lib/src/api');
  final files =
      directory
          .listSync()
          .whereType<File>()
          .map((file) => file.path)
          .where((path) => path.endsWith('.dart'))
          .toList()
        ..sort();

  return files;
}

Set<String> _exportedInternalNames(Map<String, Element> elements) {
  return {
    for (final entry in elements.entries)
      if (_isPublicExportName(entry.key) && entry.value.metadata.hasInternal)
        entry.key,
  };
}

bool _isPublicExportName(String name) {
  return !name.startsWith('_') && !name.endsWith('=');
}

void _throwOnErrorDiagnostics(ResolvedLibraryResult result) {
  final errors = result.units
      .expand((unit) => unit.diagnostics)
      .where((diagnostic) {
        return diagnostic.diagnosticCode.severity == DiagnosticSeverity.ERROR;
      })
      .map((diagnostic) {
        return '${diagnostic.source.fullName}:${diagnostic.offset}: '
            '${diagnostic.message}';
      })
      .toList();

  if (errors.isNotEmpty) {
    throw StateError(errors.join('\n'));
  }
}

Future<List<GuardrailViolation>> checkNoUndefinedPublicTypeReferences({
  String? libraryPath,
}) {
  return _checkUndefinedPublicTypeReferences(
    guardrailId: 'api.no_undefined_public_type_references',
    libraryPath: libraryPath,
  );
}

Future<List<GuardrailViolation>> _checkUndefinedPublicTypeReferences({
  required String guardrailId,
  String? libraryPath,
}) async {
  final surface = await resolvePublicApiSurface(libraryPath: libraryPath);
  final undefined = collectUndefinedPublicTypeReferences(surface);

  if (undefined.isEmpty) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: guardrailId,
      path: _displayPath(libraryPath),
      message: 'undefined public type references: ${_list(undefined)}',
    ),
  ];
}

Future<List<GuardrailViolation>> checkNoLegacyPublicTypes({
  String? libraryPath,
}) async {
  final surface = await resolvePublicApiSurface(libraryPath: libraryPath);
  final legacySymbols = await _readLegacyPublicSymbols();
  final exportedLegacy = surface.exportedNames.intersection(legacySymbols);

  if (exportedLegacy.isEmpty) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'api.no_legacy_public_types',
      path: _displayPath(libraryPath),
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
      ? libraryPath.replaceFirst(prefix, '')
      : libraryPath;
}

String _list(Iterable<String> names) {
  final sorted = names.toList()..sort();

  return sorted.join(', ');
}

Future<Set<String>> _readLegacyPublicSymbols() async {
  final golden = File(
    '$repositoryRoot/legacy/iwb_canvas_engine/tool/goldens/'
    'public_api_symbols.txt',
  );
  final lines = await golden.readAsLines();

  return lines
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toSet();
}
