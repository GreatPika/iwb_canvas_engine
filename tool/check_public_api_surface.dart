import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';

import 'src/guardrails/rules/public/public_export_namespace_support.dart';
import 'src/tool_command_result.dart';

// Invariants enforced by this tool:
// INV:INV-G-PUBLIC-ENTRYPOINTS

const String _defaultGoldenPath = '/tool/goldens/public_api_symbols.txt';
const String _publicEntrypointUri =
    'package:iwb_canvas_engine/iwb_canvas_engine.dart';

Future<ToolCommandResult> runPublicApiSurfaceTool(
  List<String> args, {
  Directory? root,
}) async {
  final updateGolden = args.contains('--update');
  final workingRoot = root ?? Directory.current;
  late final List<String> symbols;
  try {
    symbols = await _collectExportedSymbols(root: workingRoot);
  } on _PublicApiSurfaceFailure catch (error) {
    return ToolCommandResult(exitCode: error.exitCode, stderr: error.message);
  }
  final goldenFile = File(
    '${workingRoot.path}${Platform.pathSeparator}tool'
    '${Platform.pathSeparator}goldens'
    '${Platform.pathSeparator}public_api_symbols.txt',
  );

  if (updateGolden) {
    goldenFile.parent.createSync(recursive: true);
    goldenFile.writeAsStringSync('${symbols.join('\n')}\n');
    return ToolCommandResult(
      exitCode: 0,
      stdout:
          'Updated ${_defaultGoldenPath.substring(1)} '
          'with ${symbols.length} public symbols.\n',
    );
  }

  if (!goldenFile.existsSync()) {
    return ToolCommandResult(
      exitCode: 1,
      stderr:
          'FAIL: public API surface golden is missing: '
          '${_defaultGoldenPath.substring(1)}\n'
          'Run `dart run tool/check_public_api_surface.dart --update` to create it.\n',
    );
  }

  final expected = _readGoldenSymbols(goldenFile);
  final expectedSet = expected.toSet();
  if (expected.length != expectedSet.length) {
    return const ToolCommandResult(
      exitCode: 1,
      stderr:
          'FAIL: public API golden has duplicate symbol entries. '
          'Regenerate with --update.\n',
    );
  }
  final sortedExpected = expected.toList(growable: false)..sort();
  final sortedMismatchIndex = _firstMismatchIndex(expected, sortedExpected);
  if (sortedMismatchIndex != -1) {
    return ToolCommandResult(
      exitCode: 1,
      stderr:
          'FAIL: public API golden must be sorted lexicographically.\n'
          'First out-of-order symbol at index ${sortedMismatchIndex + 1}: '
          '"${expected[sortedMismatchIndex]}" (expected '
          '"${sortedExpected[sortedMismatchIndex]}").\n'
          'Run `dart run tool/check_public_api_surface.dart --update` to regenerate.\n',
    );
  }

  final actualSet = symbols.toSet();

  final added = actualSet.difference(expectedSet).toList()..sort();
  final removed = expectedSet.difference(actualSet).toList()..sort();

  if (added.isNotEmpty || removed.isNotEmpty) {
    final stderrBuffer = StringBuffer()
      ..writeln('FAIL: public API surface changed.');
    if (added.isNotEmpty) {
      stderrBuffer.writeln('Added symbols (${added.length}):');
      for (final symbol in added) {
        stderrBuffer.writeln('  + $symbol');
      }
    }
    if (removed.isNotEmpty) {
      stderrBuffer.writeln('Removed symbols (${removed.length}):');
      for (final symbol in removed) {
        stderrBuffer.writeln('  - $symbol');
      }
    }
    stderrBuffer.writeln(
      'If this is intentional, run '
      '`dart run tool/check_public_api_surface.dart --update` '
      'and commit the golden file.',
    );
    return ToolCommandResult(exitCode: 1, stderr: stderrBuffer.toString());
  }

  final orderMismatchIndex = _firstMismatchIndex(expected, symbols);
  if (orderMismatchIndex != -1) {
    return ToolCommandResult(
      exitCode: 1,
      stderr:
          'FAIL: public API surface order mismatch.\n'
          'First mismatch at index ${orderMismatchIndex + 1}: '
          'golden="${_symbolAt(expected, orderMismatchIndex)}", '
          'actual="${_symbolAt(symbols, orderMismatchIndex)}".\n'
          'Run `dart run tool/check_public_api_surface.dart --update` to regenerate.\n',
    );
  }

  return ToolCommandResult(
    exitCode: 0,
    stdout: 'Public API surface OK (${symbols.length} symbols).\n',
  );
}

Future<void> main(List<String> args) async {
  final result = await runPublicApiSurfaceTool(args);
  writeToolCommandResult(result);
  exitCode = result.exitCode;
}

List<String> _readGoldenSymbols(File goldenFile) {
  return goldenFile
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList(growable: false);
}

Future<List<String>> _collectExportedSymbols({required Directory root}) async {
  final rootPath = root.absolute.path;
  final entrypointPath = File(
    '$rootPath${Platform.pathSeparator}lib'
    '${Platform.pathSeparator}iwb_canvas_engine.dart',
  ).absolute.path;
  final collection = AnalysisContextCollection(
    includedPaths: <String>[rootPath],
  );
  final context = collection.contextFor(entrypointPath);
  final session = context.currentSession;
  final result = await session.getResolvedLibrary(entrypointPath);

  if (result is! ResolvedLibraryResult) {
    throw _PublicApiSurfaceFailure(
      exitCode: 1,
      message:
          'FAIL: unable to resolve public entrypoint library by URI: '
          '$_publicEntrypointUri '
          '(result: ${result.runtimeType})\n',
    );
  }

  return collectEffectivePublicExportNamespace(
    resolvedLibrary: result,
    rootAbsPath: rootPath,
    packageName: _readPackageName(root),
  ).symbolNames;
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

class _PublicApiSurfaceFailure implements Exception {
  const _PublicApiSurfaceFailure({
    required this.exitCode,
    required this.message,
  });

  final int exitCode;
  final String message;
}

int _firstMismatchIndex(List<String> left, List<String> right) {
  final minLength = left.length < right.length ? left.length : right.length;
  for (var i = 0; i < minLength; i++) {
    if (left[i] != right[i]) {
      return i;
    }
  }
  if (left.length != right.length) {
    return minLength;
  }
  return -1;
}

String _symbolAt(List<String> list, int index) {
  if (index < 0 || index >= list.length) {
    return '<absent>';
  }
  return list[index];
}
