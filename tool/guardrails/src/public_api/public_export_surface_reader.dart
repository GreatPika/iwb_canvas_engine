import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

final class PublicExportSurfaceReader {
  const PublicExportSurfaceReader(this.root);

  final Directory root;

  PublicExportSurface read() {
    final barrel = File('${root.path}/lib/iwb_canvas_engine.dart');
    final parsedBarrel = _parseFile(root, barrel);
    final violations = <String>[...parsedBarrel.violations];
    final exportedFiles = _collectBarrelExports(
      root,
      barrel,
      parsedBarrel.unit,
      violations,
    );

    return _readPendingApiExports(root, exportedFiles, violations);
  }
}

List<_PendingExportFile> _collectBarrelExports(
  Directory root,
  File barrel,
  CompilationUnit unit,
  List<String> violations,
) {
  final files = <_PendingExportFile>[];

  for (final directive in unit.directives.whereType<ExportDirective>()) {
    _addDirectiveTargets(
      _DirectiveTargetRequest(
        root: root,
        target: files,
        directive: directive,
        filters: <_ExportFilter>[_ExportFilter.fromDirective(directive)],
        from: barrel,
        violations: violations,
        violationMessage: (uri) =>
            'Public barrel export is outside lib/src/api/**: $uri',
      ),
    );
  }

  return files;
}

PublicExportSurface _readPendingApiExports(
  Directory root,
  List<_PendingExportFile> initialFiles,
  List<String> violations,
) {
  final publicNames = <String>{};
  final pendingFiles = <_PendingExportFile>[...initialFiles];
  final seenPaths = <String>{};

  while (pendingFiles.isNotEmpty) {
    final pendingFile = pendingFiles.removeAt(0);
    if (!_markPendingFileSeen(root, pendingFile, seenPaths)) {
      continue;
    }

    final parsed = _parseFile(root, pendingFile.file);
    violations.addAll(parsed.violations);
    publicNames.addAll(_filteredPublicNames(parsed.unit, pendingFile.filters));
    _addNestedExports(root, pendingFile, parsed.unit, pendingFiles, violations);
  }

  return PublicExportSurface(publicNames: publicNames, violations: violations);
}

bool _markPendingFileSeen(
  Directory root,
  _PendingExportFile pendingFile,
  Set<String> seenPaths,
) {
  final relativePath = _relative(root, pendingFile.file);
  return seenPaths.add('$relativePath:${pendingFile.filterKey}');
}

Set<String> _filteredPublicNames(
  CompilationUnit unit,
  List<_ExportFilter> filters,
) {
  return _applyExportFilters(_publicNames(unit), filters);
}

// Keeping traversal inputs explicit is clearer than hiding mutable queue and
// violation state behind a metrics-only wrapper.
// ignore: metrics
void _addNestedExports(
  Directory root,
  _PendingExportFile pendingFile,
  CompilationUnit unit,
  List<_PendingExportFile> pendingFiles,
  List<String> violations,
) {
  final relativePath = _relative(root, pendingFile.file);

  for (final directive in unit.directives.whereType<ExportDirective>()) {
    _addDirectiveTargets(
      _DirectiveTargetRequest(
        root: root,
        target: pendingFiles,
        directive: directive,
        filters: <_ExportFilter>[
          _ExportFilter.fromDirective(directive),
          ...pendingFile.filters,
        ],
        from: pendingFile.file,
        violations: violations,
        violationMessage: (uri) =>
            'Public API export is outside lib/src/api/**: $relativePath -> $uri',
      ),
    );
  }
}

void _addDirectiveTargets(_DirectiveTargetRequest request) {
  for (final uri in _exportUris(request.directive)) {
    final resolvedFile = _resolveApiExport(
      request.root,
      uri,
      from: request.from,
    );

    if (resolvedFile == null) {
      request.violations.add(request.violationMessage(uri));
    } else {
      request.target.add(_PendingExportFile(resolvedFile, request.filters));
    }
  }
}

Iterable<String?> _exportUris(ExportDirective directive) sync* {
  yield directive.uri.stringValue;
  for (final configuration in directive.configurations) {
    yield configuration.uri.stringValue;
  }
}

File? _resolveApiExport(Directory root, String? uri, {required File from}) {
  if (uri == null || uri.startsWith('dart:')) {
    return null;
  }

  final packagePrefix = 'package:iwb_canvas_engine/';
  final rawPath = uri.startsWith(packagePrefix)
      ? 'lib/${uri.substring(packagePrefix.length)}'
      : '${_parentPath(_relative(root, from))}/$uri';
  final path = _normalizePath(rawPath);

  return path.startsWith('lib/src/api/') ? File('${root.path}/$path') : null;
}

_ParsedUnit _parseFile(Directory root, File file) {
  if (!file.existsSync()) {
    return _ParsedUnit(
      unit: parseString(content: '').unit,
      violations: <String>['Missing file: ${_relative(root, file)}'],
    );
  }

  final result = parseString(path: file.path, content: file.readAsStringSync());

  return _ParsedUnit(
    unit: result.unit,
    violations: result.errors
        .map(
          (error) =>
              '${_relative(root, file)}:${error.offset}: '
              '${error.message}',
        )
        .toList(),
  );
}

Set<String> _publicNames(CompilationUnit unit) {
  final names = <String>{};

  for (final declaration in unit.declarations) {
    if (declaration is NamedCompilationUnitMember) {
      names.add(declaration.name.lexeme);
    } else if (declaration is TopLevelVariableDeclaration) {
      names.addAll(
        declaration.variables.variables.map((node) => node.name.lexeme),
      );
    }
  }

  names.removeWhere((name) => name.startsWith('_'));
  return names;
}

String _relative(Directory root, File file) {
  final prefix = '${root.path}/';
  return file.path.startsWith(prefix)
      ? file.path.substring(prefix.length)
      : file.path;
}

String _parentPath(String path) {
  final lastSlash = path.lastIndexOf('/');
  return lastSlash == -1 ? '' : path.substring(0, lastSlash);
}

String _normalizePath(String path) {
  final parts = <String>[];

  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }

    if (segment == '..') {
      if (parts.isEmpty) {
        return '..';
      }

      parts.removeLast();
    } else {
      parts.add(segment);
    }
  }

  return parts.join('/');
}

Set<String> _applyExportFilters(
  Set<String> names,
  List<_ExportFilter> filters,
) {
  var filteredNames = Set<String>.of(names);

  for (final filter in filters) {
    filteredNames = filter.apply(filteredNames);
  }

  return filteredNames;
}

final class _DirectiveTargetRequest {
  const _DirectiveTargetRequest({
    required this.root,
    required this.target,
    required this.directive,
    required this.filters,
    required this.from,
    required this.violations,
    required this.violationMessage,
  });

  final Directory root;
  final List<_PendingExportFile> target;
  final ExportDirective directive;
  final List<_ExportFilter> filters;
  final File from;
  final List<String> violations;
  final String Function(String? uri) violationMessage;
}

final class _ParsedUnit {
  const _ParsedUnit({required this.unit, required this.violations});

  final CompilationUnit unit;
  final List<String> violations;
}

final class _PendingExportFile {
  const _PendingExportFile(this.file, this.filters);

  final File file;
  final List<_ExportFilter> filters;

  String get filterKey => filters.map((filter) => filter.key).join('|');
}

final class _ExportFilter {
  const _ExportFilter(this.steps);

  factory _ExportFilter.fromDirective(ExportDirective directive) {
    return _ExportFilter(
      directive.combinators.map(_ExportFilterStep.fromCombinator).toList(),
    );
  }

  final List<_ExportFilterStep> steps;

  String get key => steps.map((step) => step.key).join(',');

  Set<String> apply(Set<String> names) {
    var result = Set<String>.of(names);

    for (final step in steps) {
      result = step.apply(result);
    }

    return result;
  }
}

final class _ExportFilterStep {
  const _ExportFilterStep.show(this.names) : isShow = true;

  const _ExportFilterStep.hide(this.names) : isShow = false;

  factory _ExportFilterStep.fromCombinator(Combinator combinator) {
    return switch (combinator) {
      ShowCombinator() => _ExportFilterStep.show(
        combinator.shownNames.map((name) => name.name).toSet(),
      ),
      HideCombinator() => _ExportFilterStep.hide(
        combinator.hiddenNames.map((name) => name.name).toSet(),
      ),
    };
  }

  final bool isShow;
  final Set<String> names;

  String get key {
    final sortedNames = names.toList()..sort();
    return '${isShow ? 'show' : 'hide'}:${sortedNames.join('+')}';
  }

  Set<String> apply(Set<String> inputNames) {
    if (isShow) {
      return inputNames.intersection(names);
    }

    return Set<String>.of(inputNames)..removeAll(names);
  }
}

final class PublicExportSurface {
  const PublicExportSurface({
    required this.publicNames,
    required this.violations,
  });

  final Set<String> publicNames;
  final List<String> violations;
}
