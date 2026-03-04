import 'dart:io';

class _FileCoverage {
  _FileCoverage(this.path);

  final String path;
  int? lf;
  int? lh;
  final Set<int> instrumentedLines = <int>{};
  final Set<int> hitLines = <int>{};
  final Set<int> missedLines = <int>{};

  int get effectiveLf => lf ?? instrumentedLines.length;
  int get effectiveLh => lh ?? hitLines.length;
}

String _toPosixPath(String path) => path.replaceAll('\\', '/');

Set<String> _collectLibSrcDartFiles({required String cwd}) {
  final srcRoot = Directory('lib/src');
  if (!srcRoot.existsSync()) {
    return <String>{};
  }

  final files = <String>{};
  for (final entity in srcRoot.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    files.add(_normalizePath(_toPosixPath(entity.path), cwd));
  }
  return files;
}

String _normalizePath(String path, String cwd) {
  var p = path.replaceAll('\\', '/');
  final libSrcIndex = p.lastIndexOf('lib/src/');
  if (libSrcIndex != -1) {
    return p.substring(libSrcIndex);
  }

  try {
    final absolute = File(p).absolute.path.replaceAll('\\', '/');
    final cwdNormalized = cwd.replaceAll('\\', '/');
    if (absolute.startsWith('$cwdNormalized/')) {
      return absolute.substring(cwdNormalized.length + 1);
    }
    return absolute;
  } catch (_) {
    return p;
  }
}

Map<String, _FileCoverage> _parseLcov(String content, {required String cwd}) {
  final byFile = <String, _FileCoverage>{};
  _FileCoverage? current;

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trimRight();
    if (line.startsWith('SF:')) {
      final normalized = _normalizePath(line.substring(3), cwd);
      current = byFile.putIfAbsent(normalized, () => _FileCoverage(normalized));
      continue;
    }
    if (current == null) continue;

    if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) continue;
      final lineNo = int.tryParse(parts[0]);
      final hits = int.tryParse(parts[1]);
      if (lineNo == null || hits == null) continue;
      current.instrumentedLines.add(lineNo);
      if (hits > 0) {
        current.hitLines.add(lineNo);
        current.missedLines.remove(lineNo);
      } else {
        if (current.hitLines.contains(lineNo)) continue;
        current.missedLines.add(lineNo);
      }
      continue;
    }

    if (line.startsWith('LF:')) {
      current.lf = int.tryParse(line.substring(3));
      continue;
    }
    if (line.startsWith('LH:')) {
      current.lh = int.tryParse(line.substring(3));
      continue;
    }
  }

  return byFile;
}

String _formatPercent(int lh, int lf) {
  if (lf == 0) return '100.00%';
  final pct = (lh / lf) * 100.0;
  return '${pct.toStringAsFixed(2)}%';
}

bool _isExportOnlyUnit(String repoRelativePath) {
  final file = File(repoRelativePath);
  if (!file.existsSync()) {
    return false;
  }

  final meaningfulLines = <String>[];
  for (final rawLine in file.readAsLinesSync()) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('//')) continue;
    if (trimmed.startsWith('/*')) continue;
    if (trimmed.startsWith('*')) continue;
    if (trimmed.startsWith('*/')) continue;
    meaningfulLines.add(trimmed);
  }

  if (meaningfulLines.isEmpty) {
    return false;
  }

  return meaningfulLines.every((line) => line.startsWith('export '));
}

void main(List<String> args) {
  final cwd = Directory.current.path;
  // Declaration-only Dart units may not be emitted by VM lcov as SF records.
  // Keep this list minimal and limited to const/enum/interface/typedef files.
  const excludedFromLcov = <String>{
    'lib/src/core/defaults.dart',
    'lib/src/core/grid_safety_limits.dart',
    'lib/src/core/interaction_types.dart',
    'lib/src/core/scene_limits.dart',
    'lib/src/contract/path_fill_rule.dart',
    'lib/src/contract/scene_render_state.dart',
    'lib/src/contract/scene_write_txn.dart',
    'lib/src/model/scene_value_validation.dart',
  };
  final libSrcFiles = _collectLibSrcDartFiles(cwd: cwd);
  final lcovFile = File('coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info not found. Run: flutter test --coverage',
    );
    exitCode = 2;
    return;
  }

  final content = lcovFile.readAsStringSync();
  final all = _parseLcov(content, cwd: cwd);
  final missingFromLcov =
      libSrcFiles
          .where(
            (path) =>
                !excludedFromLcov.contains(path) &&
                !all.containsKey(path) &&
                !_isExportOnlyUnit(path),
          )
          .toList()
        ..sort();
  final entries = <_FileCoverage>[];
  for (final entry in all.entries) {
    final path = entry.key;
    if (path.startsWith('lib/src/')) {
      entries.add(entry.value);
    }
  }

  entries.sort((a, b) => a.path.compareTo(b.path));

  if (entries.isEmpty) {
    stderr.writeln('No coverage entries found for lib/src/**.');
    exitCode = 2;
    return;
  }

  if (missingFromLcov.isNotEmpty) {
    stderr.writeln(
      'FAIL: ${missingFromLcov.length} lib/src/** file(s) are missing from coverage/lcov.info.',
    );
    stderr.writeln('These files are not covered at all (no lcov record):');
    for (final path in missingFromLcov) {
      stderr.writeln('  $path');
    }
    exitCode = 1;
    return;
  }

  var totalLf = 0;
  var totalLh = 0;
  var hasMisses = false;
  final missed = <String>[];

  stdout.writeln('Coverage report for lib/src/**');

  for (final file in entries) {
    final lf = file.effectiveLf;
    final lh = file.effectiveLh;
    totalLf += lf;
    totalLh += lh;
    final pct = _formatPercent(lh, lf);
    stdout.writeln('  $pct  $lh/$lf  ${file.path}');

    if (lh != lf) {
      hasMisses = true;
      final lines = file.missedLines.toList()..sort();
      for (final lineNo in lines) {
        missed.add('${file.path}:$lineNo');
      }
    }
  }

  stdout.writeln(
    'TOTAL: ${_formatPercent(totalLh, totalLf)}  $totalLh/$totalLf',
  );

  if (hasMisses) {
    stdout.writeln('MISSED LINES (${missed.length}):');
    for (final item in missed) {
      stdout.writeln('  $item');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('OK: 100% line coverage for lib/src/**');
}
