import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

final class PublicExportDirectiveFact {
  const PublicExportDirectiveFact({
    required this.source,
    required this.uriRefs,
    required this.filters,
  });

  final String source;
  final List<String> uriRefs;
  final List<Map<String, Object?>> filters;
}

List<PublicExportDirectiveFact> collectPublicExportDirectiveFacts(
  ParsedUnitResult parsedUnit,
) => [
  for (final directive
      in parsedUnit.unit.directives.whereType<ExportDirective>())
    PublicExportDirectiveFact(
      source: directive.toSource(),
      uriRefs: _collectDirectiveUriRefs(directive),
      filters: _collectDirectiveFilters(directive),
    ),
];

final class EffectivePublicExportedElement {
  const EffectivePublicExportedElement({
    required this.name,
    required this.element,
    required this.ownerPath,
  });

  final String name;
  final Element element;
  final String? ownerPath;

  String get kind => element.kind.displayName;
}

final class EffectivePublicExportNamespace {
  EffectivePublicExportNamespace({
    required List<EffectivePublicExportedElement> elements,
  }) : elements = List<EffectivePublicExportedElement>.unmodifiable(elements);

  final List<EffectivePublicExportedElement> elements;

  List<String> get symbolNames => elements
      .map((element) => element.name)
      .where((name) => !name.endsWith('='))
      .toList(growable: false);

  Set<String> get ownerPaths =>
      elements.map((element) => element.ownerPath).nonNulls.toSet();
}

EffectivePublicExportNamespace collectEffectivePublicExportNamespace({
  required ResolvedLibraryResult resolvedLibrary,
  required String rootAbsPath,
  required String packageName,
}) {
  final rootAbsPosixPath = toPublicExportNamespacePosixPath(rootAbsPath);
  final elements =
      resolvedLibrary.element.exportNamespace.definedNames2.entries
          .where((entry) => _isPublicExportedName(entry.key))
          .map(
            (entry) => EffectivePublicExportedElement(
              name: entry.key,
              element: entry.value,
              ownerPath: repoRelativePathForPublicExportElement(
                element: entry.value,
                rootAbsPosixPath: rootAbsPosixPath,
                packageName: packageName,
              ),
            ),
          )
          .toList(growable: false)
        ..sort((left, right) => left.name.compareTo(right.name));

  return EffectivePublicExportNamespace(elements: elements);
}

List<String> _collectDirectiveUriRefs(ExportDirective directive) {
  final refs = <String>[];

  void addUri(StringLiteral literal) {
    final uri = literal.stringValue;
    if (uri == null || uri.isEmpty) {
      return;
    }
    refs.add(uri);
  }

  addUri(directive.uri);
  for (final configuration in directive.configurations) {
    addUri(configuration.uri);
  }
  return refs;
}

List<Map<String, Object?>> _collectDirectiveFilters(
  ExportDirective directive,
) => directive.combinators
    .map(
      (combinator) => switch (combinator) {
        ShowCombinator() => <String, Object?>{
          'kind': 'show',
          'names':
              combinator.shownNames
                  .map((identifier) => identifier.name)
                  .toList(growable: false)
                ..sort(),
        },
        HideCombinator() => <String, Object?>{
          'kind': 'hide',
          'names':
              combinator.hiddenNames
                  .map((identifier) => identifier.name)
                  .toList(growable: false)
                ..sort(),
        },
      },
    )
    .toList(growable: false);

String? repoRelativePathForPublicExportElement({
  required Element element,
  required String rootAbsPosixPath,
  required String packageName,
}) {
  final source = element.firstFragment.libraryFragment?.source;
  if (source == null || source.uri.scheme == 'dart') {
    return null;
  }
  if (source.uri.scheme == 'package') {
    final segments = source.uri.pathSegments;
    if (segments.isNotEmpty && segments.first != packageName) {
      return null;
    }
  }

  final absPosixPath = toPublicExportNamespacePosixPath(source.fullName);
  if (!absPosixPath.startsWith('$rootAbsPosixPath/')) {
    return null;
  }
  return toPublicExportNamespaceRepoRelativePath(
    absPosixPath: absPosixPath,
    rootAbsPosixPath: rootAbsPosixPath,
  );
}

String toPublicExportNamespacePosixPath(String path) {
  return path.replaceAll('\\', '/');
}

String toPublicExportNamespaceRepoRelativePath({
  required String absPosixPath,
  required String rootAbsPosixPath,
}) {
  final abs = _normalizePosixPath(absPosixPath);
  final root = _normalizePosixPath(rootAbsPosixPath);
  if (abs == root) {
    return '/';
  }
  final rootPrefix = root.endsWith('/') ? root : '$root/';
  if (!abs.startsWith(rootPrefix)) {
    return abs;
  }
  final rel = abs.replaceFirst(root, '');
  return rel.startsWith('/') ? rel : '/$rel';
}

bool _isPublicExportedName(String name) {
  if (name.isEmpty || name.startsWith('_')) {
    return false;
  }
  if (name.endsWith('=')) {
    final setterBaseName = name.replaceFirst(RegExp(r'=$'), '');
    return setterBaseName.isNotEmpty && !setterBaseName.startsWith('_');
  }
  return true;
}

String _normalizePosixPath(String path) {
  final isAbs = path.startsWith('/');
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  final normalized = <String>[];
  for (final part in parts) {
    if (part == '.') {
      continue;
    }
    if (part == '..') {
      if (normalized.isNotEmpty) {
        normalized.removeLast();
      }
      continue;
    }
    normalized.add(part);
  }
  return '${isAbs ? '/' : ''}${normalized.join('/')}';
}
