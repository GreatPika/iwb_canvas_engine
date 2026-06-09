import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import 'document_load_input_guardrail.dart';
import 'guardrail_violation.dart';
import 'public_api_registry.dart';
import 'public_api_surface.dart';
import 'repository_paths.dart';

Future<List<GuardrailViolation>> checkPublicExportsComplete({
  String? libraryPath,
}) async {
  final registryNames = readPublicApiRegistry();
  final surface = await resolvePublicApiSurface(libraryPath: libraryPath);
  final extra = surface.exportedNames.difference(registryNames);
  final missing = registryNames.difference(surface.exportedNames);

  return [
    if (extra.isNotEmpty)
      GuardrailViolation(
        guardrailId: 'api.public_exports_complete',
        path: _displayPath(libraryPath),
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

Future<List<GuardrailViolation>> checkCurrentDocumentLoadSurfaceOnly({
  Map<String, String>? sourceOverrides,
  Set<String>? registryNamesOverride,
  Set<String>? exportedNamesOverride,
  Map<String, String>? publicExportOriginsOverride,
}) async {
  final registryNames =
      registryNamesOverride ??
      _publicRegistryNames(sourceOverrides: sourceOverrides);
  final surface = publicExportOriginsOverride == null
      ? await resolvePublicApiSurface()
      : null;
  final exportedNames =
      exportedNamesOverride ?? surface?.exportedNames ?? const <String>{};
  final exportedElements =
      surface?.exportedElements ?? const <String, Element>{};

  return [
    ..._retiredPublicRouteDeclarationViolations(sourceOverrides),
    ..._retiredLoadRouteUsageViolations(sourceOverrides),
    ..._internalLoadExportViolations(
      registryNames,
      exportedNames,
      exportedElements: exportedElements,
      publicExportOriginsOverride: publicExportOriginsOverride,
    ),
  ];
}

List<GuardrailViolation> _retiredPublicRouteDeclarationViolations(
  Map<String, String>? sourceOverrides,
) {
  return [
    for (final check in _retiredPublicRouteChecks)
      if (_retiredPublicRouteCheckMatches(check, sourceOverrides))
        GuardrailViolation(
          guardrailId: 'api.current_document_load_surface_only',
          path: check.path,
          message: check.message,
        ),
  ];
}

bool _retiredPublicRouteCheckMatches(
  _RetiredPublicRouteCheck check,
  Map<String, String>? sourceOverrides,
) {
  final source =
      sourceOverrides?[check.path] ??
      File('$repositoryRoot/${check.path}').readAsStringSync();

  return check.pattern.hasMatch(source);
}

List<GuardrailViolation> _retiredLoadRouteUsageViolations(
  Map<String, String>? sourceOverrides,
) {
  return [
    for (final hit in _retiredLoadRouteUsageHits(sourceOverrides))
      GuardrailViolation(
        guardrailId: 'api.current_document_load_surface_only',
        path: hit.path,
        message: hit.message,
      ),
  ];
}

List<GuardrailViolation> _internalLoadExportViolations(
  Set<String> registryNames,
  Set<String> exportedNames, {
  required Map<String, Element> exportedElements,
  required Map<String, String>? publicExportOriginsOverride,
}) {
  final publicNames = {...registryNames, ...exportedNames};
  final leakedInternalNames = publicNames.where((name) {
    final origin =
        publicExportOriginsOverride?[name] ??
        _exportedElementOrigin(name, exportedElements);

    return origin != null && _isInternalLoadPublicExportOrigin(origin);
  }).toSet();
  if (leakedInternalNames.isEmpty) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'api.current_document_load_surface_only',
      path: 'lib/iwb_canvas_engine.dart',
      message:
          'public API must not expose internal load/import/store types: '
          '${_list(leakedInternalNames)}',
    ),
  ];
}

String? _exportedElementOrigin(String name, Map<String, Element> elements) {
  return elements[name]?.library?.uri.toString();
}

Future<List<GuardrailViolation>> checkNoUnapprovedDocumentLoadInputs({
  Map<String, String>? sourceOverrides,
}) async {
  final hits = collectCanvasDocumentLoadInputHits(
    sourceOverrides: sourceOverrides,
  );

  if (hits.isEmpty) {
    return const [];
  }

  return [
    GuardrailViolation(
      guardrailId: 'api.no_unapproved_document_load_inputs',
      path: 'lib/src',
      message:
          'unapproved CanvasDocument load/admission inputs: ${_list(hits)}',
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

final class _RetiredPublicRouteCheck {
  const _RetiredPublicRouteCheck({
    required this.path,
    required this.pattern,
    required this.message,
  });

  final String path;
  final RegExp pattern;
  final String message;
}

final _retiredPublicRouteChecks = [
  _RetiredPublicRouteCheck(
    path: 'lib/src/api/canvas_runtime.dart',
    pattern: RegExp(r'CanvasRuntime\s*\(\s*\{[^}]*\binitialDocument\b'),
    message:
        'CanvasRuntime public facade must not expose initialDocument input',
  ),
  _RetiredPublicRouteCheck(
    path: 'lib/src/contracts/public/canvas_runtime.dart',
    pattern: RegExp(r'\bloadDocument\s*\(\s*CanvasDocument\b'),
    message:
        'CanvasEditPort public contract must not expose loadDocument(CanvasDocument)',
  ),
  _RetiredPublicRouteCheck(
    path: 'lib/src/api/canvas_codec.dart',
    pattern: RegExp(r'\bdecodeCanvasDocument(?:FromJson)?\b'),
    message: 'public codec facade must not expose decodeCanvasDocument helpers',
  ),
  _RetiredPublicRouteCheck(
    path: 'docs/_registry/public_api_v1.yaml',
    pattern: RegExp(r'\bdecodeCanvasDocument(?:FromJson)?\b'),
    message: 'public API registry must not list public decode helpers',
  ),
];

final class _RetiredLoadRouteUsageHit {
  const _RetiredLoadRouteUsageHit({required this.path, required this.message});

  final String path;
  final String message;
}

final class _RetiredLoadRouteUsageSource {
  const _RetiredLoadRouteUsageSource({required this.path, required this.text});

  final String path;
  final String text;
}

List<_RetiredLoadRouteUsageHit> _retiredLoadRouteUsageHits(
  Map<String, String>? sourceOverrides,
) {
  return [
    for (final source in _retiredLoadRouteUsageSources(sourceOverrides))
      ..._retiredLoadRouteUsageHitsIn(source),
  ];
}

Iterable<_RetiredLoadRouteUsageSource> _retiredLoadRouteUsageSources(
  Map<String, String>? sourceOverrides,
) sync* {
  if (sourceOverrides != null) {
    for (final entry in sourceOverrides.entries) {
      if (_isRetiredLoadRouteUsagePath(entry.key)) {
        yield _RetiredLoadRouteUsageSource(path: entry.key, text: entry.value);
      }
    }

    return;
  }

  for (final directory in _retiredLoadRouteUsageDirectories) {
    for (final file in dartSourceFilesUnder(directory)) {
      yield _RetiredLoadRouteUsageSource(
        path: file.path,
        text: File(file.absolutePath).readAsStringSync(),
      );
    }
  }
}

List<_RetiredLoadRouteUsageHit> _retiredLoadRouteUsageHitsIn(
  _RetiredLoadRouteUsageSource source,
) {
  final hits = <_RetiredLoadRouteUsageHit>[];
  if (_retiredDecodeHelperUsage.hasMatch(source.text)) {
    hits.add(
      _RetiredLoadRouteUsageHit(
        path: source.path,
        message:
            'runtime/load/example surfaces must not call decodeCanvasDocument helpers',
      ),
    );
  }
  if (_retiredLoadDocumentCall.hasMatch(source.text)) {
    hits.add(
      _RetiredLoadRouteUsageHit(
        path: source.path,
        message:
            'runtime/load/example surfaces must not call loadDocument(document)',
      ),
    );
  }

  return hits;
}

bool _isRetiredLoadRouteUsagePath(String path) {
  return _retiredLoadRouteUsageDirectories.any(
    (directory) => path.startsWith('$directory/'),
  );
}

const _retiredLoadRouteUsageDirectories = {
  'example/lib',
  'lib/src/codec',
  'lib/src/edit',
  'lib/src/runtime',
  'lib/src/store',
};

final _retiredDecodeHelperUsage = RegExp(
  r'\bdecodeCanvasDocument(?:FromJson)?\b',
);
final _retiredLoadDocumentCall = RegExp(r'\bloadDocument\s*\(');

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

Set<String> _publicRegistryNames({Map<String, String>? sourceOverrides}) {
  final override = sourceOverrides?['docs/_registry/public_api_v1.yaml'];
  if (override != null) {
    return readPublicApiRegistryFromYaml(override).publicExports;
  }

  return readPublicApiRegistry();
}

bool _isInternalLoadPublicExportOrigin(String origin) {
  return _internalLoadPublicExportOrigins.contains(origin);
}

const _internalLoadPublicExportOrigins = {
  'package:iwb_canvas_engine/src/codec/schema_v1_import_emitter.dart',
  'package:iwb_canvas_engine/src/codec/validated_import_draft.dart',
  'package:iwb_canvas_engine/src/contracts/internal/schema_v1_import_events.dart',
  'package:iwb_canvas_engine/src/edit/staged_document_load.dart',
  'package:iwb_canvas_engine/src/store/committed_document.dart',
  'package:iwb_canvas_engine/src/store/document_store_kernel.dart',
  'package:iwb_canvas_engine/src/store/element_registry.dart',
  'package:iwb_canvas_engine/src/store/family_tables.dart',
  'package:iwb_canvas_engine/src/store/layer_table.dart',
  'package:iwb_canvas_engine/src/store/resource_table.dart',
  'package:iwb_canvas_engine/src/store/schema_v1_store_import.dart',
};

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
