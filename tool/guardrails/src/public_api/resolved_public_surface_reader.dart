import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:yaml/yaml.dart';

final class ResolvedPublicSurfaceReader {
  const ResolvedPublicSurfaceReader(this.root);

  final Directory root;

  Future<ResolvedPublicSurface> read() async {
    final rootDirectory = Directory(root.absolute.path);
    final barrel = File('${rootDirectory.path}/lib/iwb_canvas_engine.dart');
    final collection = AnalysisContextCollection(
      includedPaths: <String>[rootDirectory.path],
    );
    final session = collection.contextFor(barrel.path).currentSession;
    final result = await session.getResolvedLibrary(barrel.path);

    if (result is! ResolvedLibraryResult) {
      return const ResolvedPublicSurface(
        elements: <ResolvedPublicElement>[],
        violations: <String>['Unable to resolve public barrel library'],
        typeDiagnostics: <String>[],
      );
    }

    return ResolvedPublicSurface(
      elements: _publicElements(result, rootDirectory),
      violations: const <String>[],
      typeDiagnostics: _typeDiagnostics(result),
    );
  }

  List<ResolvedPublicElement> _publicElements(
    ResolvedLibraryResult result,
    Directory rootDirectory,
  ) {
    final packageName = readPackageName(rootDirectory);
    final rootAbsPosixPath = toPosixPath(rootDirectory.path);
    final elements = result.element.exportNamespace.definedNames2.entries
        .where((entry) => _isPublicExportedName(entry.key))
        .map(
          (entry) => ResolvedPublicElement(
            name: entry.key,
            element: entry.value,
            ownerPath: repoRelativePathForElement(
              element: entry.value,
              packageName: packageName,
              rootAbsPosixPath: rootAbsPosixPath,
            ),
          ),
        )
        .toList(growable: false);

    elements.sort((left, right) => left.name.compareTo(right.name));
    return elements;
  }
}

final class ResolvedPublicSurface {
  const ResolvedPublicSurface({
    required this.elements,
    required this.violations,
    required this.typeDiagnostics,
  });

  final List<ResolvedPublicElement> elements;
  final List<String> violations;
  final List<String> typeDiagnostics;

  Set<String> get publicNames =>
      elements.map((element) => element.name).toSet();

  Map<String, Set<String>> get publicTypeOwnersByName {
    final owners = <String, Set<String>>{};

    for (final exportedElement in elements) {
      if (!_isPublicVisibleTypeElement(exportedElement.element)) {
        continue;
      }

      final ownerPath = exportedElement.ownerPath;
      if (ownerPath == null) {
        continue;
      }

      owners.putIfAbsent(exportedElement.name, () => <String>{}).add(ownerPath);
    }

    return owners;
  }
}

final class ResolvedPublicElement {
  const ResolvedPublicElement({
    required this.name,
    required this.element,
    required this.ownerPath,
  });

  final String name;
  final Element element;
  final String? ownerPath;
}

String? repoRelativePathForElement({
  required Element element,
  required String packageName,
  required String rootAbsPosixPath,
}) {
  final source = element.firstFragment.libraryFragment?.source;
  if (source == null || source.uri.scheme == 'dart') {
    return null;
  }

  if (source.uri.scheme == 'package' &&
      !_isElementFromPackage(source.uri, packageName)) {
    return null;
  }

  final absPath = toPosixPath(source.fullName);
  if (!absPath.startsWith('$rootAbsPosixPath/')) {
    return null;
  }

  final relativePath = absPath.substring(rootAbsPosixPath.length);
  return relativePath.startsWith('/') ? relativePath : '/$relativePath';
}

String readPackageName(Directory root) {
  final pubspec = File('${root.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    return 'iwb_canvas_engine';
  }

  final yaml = loadYaml(pubspec.readAsStringSync());
  if (yaml is YamlMap && yaml['name'] is String) {
    return yaml['name'] as String;
  }

  return 'iwb_canvas_engine';
}

String pathWithoutLeadingSlash(String? path) {
  if (path == null || path.isEmpty) {
    return '<unknown>';
  }

  return path.startsWith('/') ? path.substring(1) : path;
}

String packageNameForElementUri(Uri uri) {
  return uri.scheme == 'package' && uri.pathSegments.isNotEmpty
      ? uri.pathSegments.first
      : 'iwb_canvas_engine';
}

String rootPathForElementSource(String? sourceFullName) {
  if (sourceFullName == null) {
    return '';
  }

  final posixPath = toPosixPath(sourceFullName);
  final libIndex = posixPath.indexOf('/lib/');
  return libIndex == -1 ? '' : posixPath.substring(0, libIndex);
}

String toPosixPath(String path) => path.replaceAll('\\', '/');

List<String> _typeDiagnostics(ResolvedLibraryResult result) {
  final diagnostics = <String>[];

  for (final unit in result.units) {
    final path = pathWithoutLeadingSlash(
      _repoRelativePathForResolvedUnit(unit),
    );

    for (final diagnostic in unit.diagnostics) {
      final name = _extractTypeDiagnosticName(diagnostic.message);
      if (name != null) {
        diagnostics.add('Undefined public signature type $name in $path');
      }
    }
  }

  return diagnostics;
}

String? _repoRelativePathForResolvedUnit(ResolvedUnitResult unit) {
  final absPath = toPosixPath(unit.path);
  final libIndex = absPath.indexOf('/lib/');
  return libIndex == -1 ? null : absPath.substring(libIndex + 1);
}

String? _extractTypeDiagnosticName(String message) {
  if (!message.contains("isn't a type") &&
      !message.contains('Undefined class')) {
    return null;
  }

  final quotedName = RegExp("'([^']+)'").firstMatch(message)?.group(1);
  return quotedName == null || quotedName.isEmpty ? 'InvalidType' : quotedName;
}

bool _isPublicVisibleTypeElement(Element element) =>
    element is InterfaceElement || element is TypeAliasElement;

bool _isPublicExportedName(String name) {
  if (name.isEmpty || name.startsWith('_')) {
    return false;
  }

  if (name.endsWith('=')) {
    final setterName = name.substring(0, name.length - 1);
    return setterName.isNotEmpty && !setterName.startsWith('_');
  }

  return true;
}

bool _isElementFromPackage(Uri uri, String packageName) {
  final segments = uri.pathSegments;
  return segments.isEmpty || segments.first == packageName;
}
