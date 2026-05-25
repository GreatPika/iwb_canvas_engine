import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import 'public_api_type_references.dart';
import 'repository_paths.dart';

final class PublicApiSurface {
  PublicApiSurface._({
    required this.exportedNames,
    required this.exportedElements,
    required this.exportedNamedExtensionNames,
    required this.approvedExternalTypeKeys,
  });

  final Set<String> exportedNames;
  final Map<String, Element> exportedElements;
  final Set<String> exportedNamedExtensionNames;
  final Set<String> approvedExternalTypeKeys;
}

Future<PublicApiSurface> resolvePublicApiSurface({String? libraryPath}) async {
  final resolvedLibraryPath =
      libraryPath ?? '$repositoryRoot/lib/iwb_canvas_engine.dart';
  final collection = AnalysisContextCollection(
    includedPaths: [
      if (libraryPath == null) repositoryRoot else resolvedLibraryPath,
    ],
  );
  try {
    final context = collection.contextFor(resolvedLibraryPath);
    final result = await context.currentSession.getResolvedLibrary(
      resolvedLibraryPath,
    );
    if (result is! ResolvedLibraryResult) {
      throw StateError('Could not resolve $resolvedLibraryPath: $result');
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
      exportedNamedExtensionNames: _namedExtensionNames(publicEntries),
      approvedExternalTypeKeys: await _approvedExternalTypeKeys(
        context.currentSession,
      ),
    );
  } finally {
    await collection.dispose();
  }
}

Set<String> collectUndefinedPublicTypeReferences(PublicApiSurface surface) {
  return collectUndefinedTypeReferences(
    exportedElements: surface.exportedElements.values,
    exportedNamedExtensionNames: surface.exportedNamedExtensionNames,
    publicNames: surface.exportedNames,
    approvedExternalTypeKeys: surface.approvedExternalTypeKeys,
  );
}

Future<Set<String>> _approvedExternalTypeKeys(AnalysisSession session) async {
  final keys = <String>{};

  for (final uri in _approvedFlutterPublicTypeUris) {
    final result = await session.getLibraryByUri(uri);
    if (result is! LibraryElementResult) {
      throw StateError(
        'Could not resolve approved public API library $uri: $result',
      );
    }
    for (final element in result.element.exportNamespace.definedNames2.values) {
      if (element is InterfaceElement) {
        keys.add(externalTypeKey(element));
      }
    }
  }

  return keys;
}

bool _isPublicExportName(String name) {
  return !name.startsWith('_') && !name.endsWith('=');
}

Set<String> _namedExtensionNames(Map<String, Element> elements) {
  return {
    for (final entry in elements.entries)
      if (entry.value is ExtensionElement) entry.key,
  };
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

const _approvedFlutterPublicTypeUris = {
  'package:flutter/foundation.dart',
  'package:flutter/widgets.dart',
};
