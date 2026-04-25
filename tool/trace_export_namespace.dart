import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import 'src/tool_command_result.dart';

Future<ToolCommandResult> runTraceExportNamespaceTool(
  List<String> args, {
  Directory? root,
}) async {
  if (args.isEmpty) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr:
          'Usage: dart run tool/trace_export_namespace.dart <entrypoint.dart> '
          '[--json] [--json-out=file] [--md] [--md-out=file]\n',
    );
  }

  final workingRoot = root ?? Directory.current;
  final entrypointArg = args.first;
  final jsonOutput = args.contains('--json');
  final jsonOutPath = _parseStringFlag(args, '--json-out');
  final markdownOutput = args.contains('--md');
  final markdownOutPath = _parseStringFlag(args, '--md-out');

  try {
    final report = await _buildReport(
      root: workingRoot,
      entrypointArg: entrypointArg,
    );
    final reportJson = const JsonEncoder.withIndent('  ').convert(report);
    final reportMarkdown = _renderMermaidDocument(report);

    if (jsonOutPath != null) {
      _writeOutputFile(workingRoot, jsonOutPath, '$reportJson\n');
    }
    if (markdownOutPath != null) {
      _writeOutputFile(workingRoot, markdownOutPath, '$reportMarkdown\n');
    }

    if (jsonOutput) {
      return ToolCommandResult(exitCode: 0, stdout: '$reportJson\n');
    }
    if (markdownOutput) {
      return ToolCommandResult(exitCode: 0, stdout: '$reportMarkdown\n');
    }

    return ToolCommandResult(exitCode: 0, stdout: _renderSummary(report));
  } on _TraceFailure catch (error) {
    return ToolCommandResult(exitCode: 1, stderr: 'FAIL: ${error.message}\n');
  }
}

Future<void> main(List<String> args) async {
  final result = await runTraceExportNamespaceTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

Future<Map<String, Object?>> _buildReport({
  required Directory root,
  required String entrypointArg,
}) async {
  final rootAbsPath = root.absolute.path;
  final rootAbsPosixPath = _toPosixPath(rootAbsPath);
  final entrypointFile = File(_resolveAgainstRoot(root, entrypointArg));
  if (!entrypointFile.existsSync()) {
    throw _TraceFailure('Entrypoint file not found: $entrypointArg');
  }

  final entrypointAbsPath = entrypointFile.absolute.path;
  final entrypointRepoRelPath = _toRepoRelativePosixPath(
    absPosixPath: _toPosixPath(entrypointAbsPath),
    rootAbsPosixPath: rootAbsPosixPath,
  );
  final packageName = _readPackageName(root);

  final collection = AnalysisContextCollection(
    includedPaths: <String>[rootAbsPath],
  );
  final context = collection.contextFor(entrypointAbsPath);
  final session = context.currentSession;
  final parsedResult = session.getParsedUnit(entrypointAbsPath);
  if (parsedResult is! ParsedUnitResult) {
    throw _TraceFailure(
      'Unable to parse $entrypointRepoRelPath '
      '(result: ${parsedResult.runtimeType}).',
    );
  }
  final resolvedResult = await session.getResolvedLibrary(entrypointAbsPath);
  if (resolvedResult is! ResolvedLibraryResult) {
    throw _TraceFailure(
      'Unable to resolve $entrypointRepoRelPath '
      '(result: ${resolvedResult.runtimeType}).',
    );
  }

  final entrypointDirRepoRelPosix = _posixDirname(entrypointRepoRelPath);
  final directExports = <Map<String, Object?>>[];
  final directTargets = <String>{};
  for (final directive
      in parsedResult.unit.directives.whereType<ExportDirective>()) {
    final targets = <String>[];
    for (final uriRef in _collectDirectiveUriRefs(directive)) {
      final resolvedTarget = _resolveToRepoRelTargetPosix(
        targetPosix: _toPosixPath(uriRef),
        packageName: packageName,
        fileDirRepoRelPosix: entrypointDirRepoRelPosix,
      );
      if (resolvedTarget != null) {
        directTargets.add(resolvedTarget);
        targets.add(resolvedTarget);
      }
    }
    directExports.add(<String, Object?>{
      'directive': directive.toSource(),
      'targets': targets,
      'filters': _collectDirectiveFilters(directive),
    });
  }

  final effectiveSymbols = <Map<String, Object?>>[];
  final effectiveOwnerPaths = <String>{};
  final transitiveSymbols = <Map<String, Object?>>[];
  final entries =
      resolvedResult.element.exportNamespace.definedNames2.entries
          .where((entry) => entry.key.isNotEmpty && !entry.key.startsWith('_'))
          .where((entry) => !entry.key.endsWith('='))
          .toList(growable: false)
        ..sort((left, right) => left.key.compareTo(right.key));

  for (final entry in entries) {
    final ownerPath = _repoRelPathForElement(
      element: entry.value,
      rootAbsPosixPath: rootAbsPosixPath,
      packageName: packageName,
    );
    if (ownerPath != null) {
      effectiveOwnerPaths.add(ownerPath);
    }
    final record = <String, Object?>{
      'name': entry.key,
      'kind': entry.value.kind.displayName,
      'ownerPath': ownerPath,
      'directlyExportedOwner':
          ownerPath != null && directTargets.contains(ownerPath),
    };
    effectiveSymbols.add(record);
    if (ownerPath != null && !directTargets.contains(ownerPath)) {
      transitiveSymbols.add(record);
    }
  }

  final transitiveOwnerPaths = effectiveOwnerPaths.difference(directTargets)
    ..removeWhere((path) => path == '/');
  final sortedDirectTargets = directTargets.toList(growable: false)..sort();
  final directTargetOwnerPaths = <Map<String, Object?>>[];
  for (final target in sortedDirectTargets) {
    final resolved = await _resolveLibraryForRepoRelPath(
      session: session,
      root: root,
      repoRelPath: target,
    );
    final visibleOwnerPaths = <String>{};
    if (resolved != null) {
      for (final entry
          in resolved.element.exportNamespace.definedNames2.entries) {
        if (entry.key.isEmpty ||
            entry.key.startsWith('_') ||
            entry.key.endsWith('=')) {
          continue;
        }
        final ownerPath = _repoRelPathForElement(
          element: entry.value,
          rootAbsPosixPath: rootAbsPosixPath,
          packageName: packageName,
        );
        if (ownerPath != null) {
          visibleOwnerPaths.add(ownerPath);
        }
      }
    }
    directTargetOwnerPaths.add(<String, Object?>{
      'target': target,
      'visibleOwnerPaths': visibleOwnerPaths.toList(growable: false)..sort(),
      'transitiveOwnerPaths':
          visibleOwnerPaths
              .where((path) => path != target)
              .toList(growable: false)
            ..sort(),
    });
  }

  return <String, Object?>{
    'entrypoint': entrypointRepoRelPath,
    'directExports': directExports,
    'directExportTargets': sortedDirectTargets,
    'directTargetOwnerPaths': directTargetOwnerPaths,
    'effectiveOwnerPaths': effectiveOwnerPaths.toList(growable: false)..sort(),
    'transitiveOwnerPaths': transitiveOwnerPaths.toList(growable: false)
      ..sort(),
    'effectiveSymbols': effectiveSymbols,
    'transitivelyExportedSymbols': transitiveSymbols,
  };
}

Future<ResolvedLibraryResult?> _resolveLibraryForRepoRelPath({
  required AnalysisSession session,
  required Directory root,
  required String repoRelPath,
}) async {
  final relPath = repoRelPath.startsWith('/')
      ? repoRelPath.substring(1)
      : repoRelPath;
  final file = File('${root.path}${Platform.pathSeparator}$relPath');
  if (!file.existsSync()) {
    return null;
  }
  final result = await session.getResolvedLibrary(file.absolute.path);
  return result is ResolvedLibraryResult ? result : null;
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

List<Map<String, Object?>> _collectDirectiveFilters(ExportDirective directive) {
  return directive.combinators
      .map((combinator) {
        return switch (combinator) {
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
        };
      })
      .toList(growable: false);
}

String? _repoRelPathForElement({
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

  final absPosixPath = _toPosixPath(source.fullName);
  if (!absPosixPath.startsWith('$rootAbsPosixPath/')) {
    return null;
  }
  return _toRepoRelativePosixPath(
    absPosixPath: absPosixPath,
    rootAbsPosixPath: rootAbsPosixPath,
  );
}

String _renderSummary(Map<String, Object?> report) {
  final directTargets =
      report['directExportTargets'] as List<Object?>? ?? const <Object?>[];
  final effectiveSymbols =
      report['effectiveSymbols'] as List<Object?>? ?? const <Object?>[];
  final transitiveOwnerPaths =
      report['transitiveOwnerPaths'] as List<Object?>? ?? const <Object?>[];
  final transitiveSymbols =
      report['transitivelyExportedSymbols'] as List<Object?>? ??
      const <Object?>[];

  final buffer = StringBuffer()
    ..writeln('Entrypoint: ${report['entrypoint']}')
    ..writeln('Direct export targets: ${directTargets.length}')
    ..writeln('Effective exported symbols: ${effectiveSymbols.length}')
    ..writeln(
      'Transitively exported owner files: ${transitiveOwnerPaths.length}',
    )
    ..writeln('Transitively exported symbols: ${transitiveSymbols.length}');

  if (transitiveOwnerPaths.isNotEmpty) {
    buffer.writeln('Transitively exported owner files:');
    for (final path in transitiveOwnerPaths.cast<String>()) {
      buffer.writeln('- $path');
    }
  }
  return buffer.toString();
}

String _renderMermaidDocument(Map<String, Object?> report) {
  final buffer = StringBuffer()
    ..writeln('# Export Namespace Trace')
    ..writeln()
    ..writeln('```mermaid')
    ..writeln(_renderMermaid(report))
    ..writeln('```')
    ..writeln()
    ..writeln('Entrypoint summary:')
    ..writeln('- Entrypoint: `${report['entrypoint']}`')
    ..writeln(
      '- Direct export targets: ${(report['directExportTargets'] as List<Object?>).length}',
    )
    ..writeln(
      '- Effective exported symbols: ${(report['effectiveSymbols'] as List<Object?>).length}',
    )
    ..writeln(
      '- Transitively exported owner files: ${(report['transitiveOwnerPaths'] as List<Object?>).length}',
    )
    ..writeln(
      '- Transitively exported symbols: ${(report['transitivelyExportedSymbols'] as List<Object?>).length}',
    );
  return buffer.toString().trimRight();
}

String _renderMermaid(Map<String, Object?> report) {
  final buffer = StringBuffer()..writeln('flowchart LR');
  final nodeIds = <String, String>{};
  var nextId = 0;

  String nodeIdFor(String key) =>
      nodeIds.putIfAbsent(key, () => 'N${nextId++}');

  String quote(String value) => value.replaceAll('"', r'\"');

  final entrypoint = report['entrypoint'] as String;
  final entrypointId = nodeIdFor('entrypoint:$entrypoint');
  buffer.writeln('  $entrypointId["${quote(entrypoint)}"]');

  for (final targetEntry
      in (report['directTargetOwnerPaths'] as List<Object?>)
          .cast<Map<String, Object?>>()) {
    final target = targetEntry['target'] as String;
    final targetId = nodeIdFor('target:$target');
    buffer.writeln('  $targetId["${quote(target)}"]');
    buffer.writeln('  $entrypointId --> $targetId');
    for (final ownerPath
        in (targetEntry['transitiveOwnerPaths'] as List<Object?>)
            .cast<String>()) {
      final ownerId = nodeIdFor('owner:$ownerPath');
      buffer.writeln('  $ownerId["${quote(ownerPath)}"]');
      buffer.writeln('  $targetId --> $ownerId');
    }
  }

  return buffer.toString().trimRight();
}

String? _parseStringFlag(List<String> args, String flag) {
  final prefix = '$flag=';
  for (final arg in args.skip(1)) {
    if (arg.startsWith(prefix)) {
      return arg.substring(prefix.length);
    }
  }
  return null;
}

void _writeOutputFile(Directory root, String relativePath, String content) {
  final target = File(_resolveAgainstRoot(root, relativePath));
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(content);
}

String _resolveAgainstRoot(Directory root, String path) {
  if (_looksAbsolute(path)) {
    return path;
  }
  return '${root.path}${Platform.pathSeparator}$path';
}

bool _looksAbsolute(String path) {
  return path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);
}

String _readPackageName(Directory root) {
  final pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
  if (!pubspec.existsSync()) {
    return 'iwb_canvas_engine';
  }
  for (final line in pubspec.readAsLinesSync()) {
    final match = RegExp(r'^\s*name:\s*([A-Za-z0-9_]+)\s*$').firstMatch(line);
    if (match != null) {
      return match.group(1)!;
    }
  }
  return 'iwb_canvas_engine';
}

String _toPosixPath(String path) => path.replaceAll('\\', '/');

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

String _posixJoin(String base, String target) {
  if (target.startsWith('/')) {
    return _normalizePosixPath(target);
  }
  if (base.isEmpty) {
    return _normalizePosixPath(target);
  }
  return _normalizePosixPath('${base.endsWith('/') ? base : '$base/'}$target');
}

String _posixDirname(String path) {
  final normalized = _normalizePosixPath(path);
  if (normalized == '/' || normalized.isEmpty) {
    return normalized;
  }
  final slashIndex = normalized.lastIndexOf('/');
  if (slashIndex <= 0) {
    return normalized.startsWith('/') ? '/' : '';
  }
  return normalized.substring(0, slashIndex);
}

String _toRepoRelativePosixPath({
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
  final rel = abs.substring(root.length);
  return rel.startsWith('/') ? rel : '/$rel';
}

String? _resolveToRepoRelTargetPosix({
  required String targetPosix,
  required String packageName,
  required String fileDirRepoRelPosix,
}) {
  if (targetPosix.startsWith('dart:')) {
    return null;
  }
  if (targetPosix.startsWith('package:')) {
    final prefix = 'package:$packageName/';
    if (!targetPosix.startsWith(prefix)) {
      return null;
    }
    return _normalizePosixPath('/lib/${targetPosix.substring(prefix.length)}');
  }
  return _posixJoin(fileDirRepoRelPosix, targetPosix);
}

final class _TraceFailure implements Exception {
  const _TraceFailure(this.message);

  final String message;
}
