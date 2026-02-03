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
      } else {
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

void main(List<String> args) {
  final cwd = Directory.current.path;
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
