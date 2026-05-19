import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import 'public_api_type_references.dart';

final class PublicApiSurface {
  PublicApiSurface._({
    required this.exportedNames,
    required this.exportedElements,
  });

  final Set<String> exportedNames;
  final Map<String, Element> exportedElements;
}

Future<PublicApiSurface> resolvePublicApiSurface() async {
  final collection = AnalysisContextCollection(includedPaths: [repoRoot]);
  try {
    final libraryPath = '$repoRoot/lib/iwb_canvas_engine.dart';
    final context = collection.contextFor(libraryPath);
    final result = await context.currentSession.getResolvedLibrary(libraryPath);
    if (result is! ResolvedLibraryResult) {
      throw StateError('Could not resolve $libraryPath: $result');
    }
    _throwOnErrorDiagnostics(result);
    final namespace = result.element.exportNamespace;
    final elements = namespace.definedNames2;
    final publicEntries = Map.fromEntries(
      elements.entries.where((entry) => _isPublicExportName(entry.key)),
    );

    return PublicApiSurface._(
      exportedNames: publicEntries.keys.toSet(),
      exportedElements: publicEntries,
    );
  } finally {
    await collection.dispose();
  }
}

Set<String> collectUndefinedPublicTypeReferences(PublicApiSurface surface) {
  return collectUndefinedTypeReferences(
    exportedElements: surface.exportedElements.values,
    publicNames: surface.exportedNames,
  );
}

String get repoRoot => Directory.current.absolute.path;

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
