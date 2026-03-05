import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';

// Invariants enforced by this tool:
// INV:INV-G-PUBLIC-ENTRYPOINTS

const String _defaultGoldenPath = '/tool/goldens/public_api_symbols.txt';
const String _publicEntrypointUri =
    'package:iwb_canvas_engine/iwb_canvas_engine.dart';

Future<void> main(List<String> args) async {
  final updateGolden = args.contains('--update');
  final root = Directory.current;
  final symbols = await _collectExportedSymbols(root: root);
  final goldenFile = File(
    '${root.path}${Platform.pathSeparator}tool'
    '${Platform.pathSeparator}goldens'
    '${Platform.pathSeparator}public_api_symbols.txt',
  );

  if (updateGolden) {
    goldenFile.parent.createSync(recursive: true);
    goldenFile.writeAsStringSync('${symbols.join('\n')}\n');
    stdout.writeln(
      'Updated ${_defaultGoldenPath.substring(1)} '
      'with ${symbols.length} public symbols.',
    );
    return;
  }

  if (!goldenFile.existsSync()) {
    stderr.writeln(
      'FAIL: public API surface golden is missing: '
      '${_defaultGoldenPath.substring(1)}',
    );
    stderr.writeln(
      'Run `dart run tool/check_public_api_surface.dart --update` to create it.',
    );
    exit(1);
  }

  final expected = _readGoldenSymbols(goldenFile);
  final expectedSet = expected.toSet();
  if (expected.length != expectedSet.length) {
    stderr.writeln(
      'FAIL: public API golden has duplicate symbol entries. '
      'Regenerate with --update.',
    );
    exit(1);
  }
  final sortedExpected = expected.toList(growable: false)..sort();
  final sortedMismatchIndex = _firstMismatchIndex(expected, sortedExpected);
  if (sortedMismatchIndex != -1) {
    stderr.writeln('FAIL: public API golden must be sorted lexicographically.');
    stderr.writeln(
      'First out-of-order symbol at index ${sortedMismatchIndex + 1}: '
      '"${expected[sortedMismatchIndex]}" (expected '
      '"${sortedExpected[sortedMismatchIndex]}").',
    );
    stderr.writeln(
      'Run `dart run tool/check_public_api_surface.dart --update` to regenerate.',
    );
    exit(1);
  }

  final actualSet = symbols.toSet();

  final added = actualSet.difference(expectedSet).toList()..sort();
  final removed = expectedSet.difference(actualSet).toList()..sort();

  if (added.isNotEmpty || removed.isNotEmpty) {
    stderr.writeln('FAIL: public API surface changed.');
    if (added.isNotEmpty) {
      stderr.writeln('Added symbols (${added.length}):');
      for (final symbol in added) {
        stderr.writeln('  + $symbol');
      }
    }
    if (removed.isNotEmpty) {
      stderr.writeln('Removed symbols (${removed.length}):');
      for (final symbol in removed) {
        stderr.writeln('  - $symbol');
      }
    }
    stderr.writeln(
      'If this is intentional, run '
      '`dart run tool/check_public_api_surface.dart --update` '
      'and commit the golden file.',
    );
    exit(1);
  }

  final orderMismatchIndex = _firstMismatchIndex(expected, symbols);
  if (orderMismatchIndex != -1) {
    stderr.writeln('FAIL: public API surface order mismatch.');
    stderr.writeln(
      'First mismatch at index ${orderMismatchIndex + 1}: '
      'golden="${_symbolAt(expected, orderMismatchIndex)}", '
      'actual="${_symbolAt(symbols, orderMismatchIndex)}".',
    );
    stderr.writeln(
      'Run `dart run tool/check_public_api_surface.dart --update` to regenerate.',
    );
    exit(1);
  }

  stdout.writeln('Public API surface OK (${symbols.length} symbols).');
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
  final result = await session.getLibraryByUri(_publicEntrypointUri);

  if (result is! LibraryElementResult) {
    stderr.writeln(
      'FAIL: unable to resolve public entrypoint library by URI: '
      '$_publicEntrypointUri '
      '(result: ${result.runtimeType})',
    );
    exit(1);
  }

  final names =
      result.element.exportNamespace.definedNames2.keys
          .where((name) => name.isNotEmpty && !name.startsWith('_'))
          .where((name) => !name.endsWith('='))
          .toList(growable: false)
        ..sort();
  return names;
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
