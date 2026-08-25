import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'src/analysis_dart_sdk_path.dart';
import 'src/public_export_namespace_support.dart';
import 'src/tool_command_result.dart';

// One export trace owns resolution and all render formats for the same namespace.
// ignore: halstead-volume, reason: One export trace owns resolution and every report format.
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

// Namespace closure, direct-export provenance, and owner attribution require
// one resolved-library snapshot; splitting them would duplicate that snapshot.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code, maintainability-index, reason: One resolved-library snapshot owns namespace closure and provenance.
Future<Map<String, Object?>> _buildReport({
  required Directory root,
  required String entrypointArg,
}) async {
  final rootAbsPath = root.absolute.path;
  final rootAbsPosixPath = toPublicExportNamespacePosixPath(rootAbsPath);
  final entrypointFile = File(_resolveAgainstRoot(root, entrypointArg));
  if (!entrypointFile.existsSync()) {
    throw _TraceFailure('Entrypoint file not found: $entrypointArg');
  }

  final entrypointAbsPath = entrypointFile.absolute.path;
  final entrypointRepoRelPath = _toRepoRelativePosixPath(
    absPosixPath: toPublicExportNamespacePosixPath(entrypointAbsPath),
    rootAbsPosixPath: rootAbsPosixPath,
  );
  final packageName = _readPackageName(root);

  final collection = AnalysisContextCollection(
    includedPaths: <String>[rootAbsPath],
    sdkPath: resolveAnalysisDartSdkPath(),
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
  for (final directive in collectPublicExportDirectiveFacts(parsedResult)) {
    final targets = <String>[];
    for (final uriRef in directive.uriRefs) {
      final resolvedTarget = _resolveToRepoRelTargetPosix(
        targetPosix: toPublicExportNamespacePosixPath(uriRef),
        packageName: packageName,
        fileDirRepoRelPosix: entrypointDirRepoRelPosix,
      );
      if (resolvedTarget != null) {
        directTargets.add(resolvedTarget);
        targets.add(resolvedTarget);
      }
    }
    directExports.add(<String, Object?>{
      'directive': directive.source,
      'targets': targets,
      'filters': directive.filters,
    });
  }

  final effectiveSymbols = <Map<String, Object?>>[];
  final effectiveOwnerPaths = <String>{};
  final transitiveSymbols = <Map<String, Object?>>[];
  final effectiveNamespace = collectEffectivePublicExportNamespace(
    resolvedLibrary: resolvedResult,
    rootAbsPath: rootAbsPath,
    packageName: packageName,
  );

  for (final exportedElement in effectiveNamespace.elements) {
    final ownerPath = exportedElement.ownerPath;
    if (ownerPath != null) {
      effectiveOwnerPaths.add(ownerPath);
    }
    final record = <String, Object?>{
      'name': exportedElement.name,
      'kind': exportedElement.kind,
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
      final targetNamespace = collectEffectivePublicExportNamespace(
        resolvedLibrary: resolved,
        rootAbsPath: rootAbsPath,
        packageName: packageName,
      );
      for (final exportedElement in targetNamespace.elements) {
        final ownerPath = exportedElement.ownerPath;
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
      ? repoRelPath.replaceFirst('/', '')
      : repoRelPath;
  final file = File('${root.path}${Platform.pathSeparator}$relPath');
  if (!file.existsSync()) {
    return null;
  }
  final result = await session.getResolvedLibrary(file.absolute.path);
  return result is ResolvedLibraryResult ? result : null;
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

// Mermaid nodes share one id namespace across every direct and transitive edge.
// ignore: halstead-volume, reason: Direct and transitive edges require one Mermaid id namespace.
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
      return arg.replaceFirst(prefix, '');
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
      final packageName = match.group(1);
      if (packageName != null) {
        return packageName;
      }
    }
  }
  return 'iwb_canvas_engine';
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
  final parts = normalized.split('/');
  return parts.take(parts.length - 1).join('/');
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
  final rel = abs.replaceFirst(root, '');
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
    return _normalizePosixPath('/lib/${targetPosix.replaceFirst(prefix, '')}');
  }
  return _posixJoin(fileDirRepoRelPosix, targetPosix);
}

final class _TraceFailure implements Exception {
  const _TraceFailure(this.message);

  final String message;
}
