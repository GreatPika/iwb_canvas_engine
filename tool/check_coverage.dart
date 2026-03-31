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
    current = _updateCurrentFile(
      line,
      byFile: byFile,
      current: current,
      cwd: cwd,
    );
    if (current == null) continue;
    _recordCoverageLine(current, line);
  }

  return byFile;
}

_FileCoverage? _updateCurrentFile(
  String line, {
  required Map<String, _FileCoverage> byFile,
  required _FileCoverage? current,
  required String cwd,
}) {
  if (!line.startsWith('SF:')) {
    return current;
  }

  final normalized = _normalizePath(line.substring(3), cwd);
  return byFile.putIfAbsent(normalized, () => _FileCoverage(normalized));
}

void _recordCoverageLine(_FileCoverage current, String line) {
  if (line.startsWith('DA:')) {
    _recordDataLine(current, line.substring(3));
    return;
  }

  if (line.startsWith('LF:')) {
    current.lf = int.tryParse(line.substring(3));
    return;
  }

  if (line.startsWith('LH:')) {
    current.lh = int.tryParse(line.substring(3));
  }
}

void _recordDataLine(_FileCoverage current, String data) {
  final parts = data.split(',');
  if (parts.length < 2) return;

  final lineNo = int.tryParse(parts[0]);
  final hits = int.tryParse(parts[1]);
  if (lineNo == null || hits == null) return;

  current.instrumentedLines.add(lineNo);
  if (hits > 0) {
    current.hitLines.add(lineNo);
    current.missedLines.remove(lineNo);
    return;
  }

  if (current.hitLines.contains(lineNo)) return;
  current.missedLines.add(lineNo);
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

  var sawExport = false;
  var awaitingExportTerminator = false;
  for (final line in meaningfulLines) {
    if (awaitingExportTerminator) {
      if (line.endsWith(';')) {
        awaitingExportTerminator = false;
      }
      continue;
    }

    if (!line.startsWith('export ')) {
      return false;
    }

    sawExport = true;
    if (!line.endsWith(';')) {
      awaitingExportTerminator = true;
    }
  }

  return sawExport && !awaitingExportTerminator;
}

const _excludedDeclarationOnlyFromLcov = <String>{
  'lib/src/core/tool_defaults.dart',
  'lib/src/core/grid_safety_limits.dart',
  'lib/src/core/interaction_types.dart',
  'lib/src/core/scene_limits.dart',
  'lib/src/contract/path_fill_rule.dart',
  'lib/src/contract/scene_defaults.dart',
  'lib/src/contract/scene_render_state.dart',
  'lib/src/contract/scene_view_render_state.dart',
  'lib/src/interactive/internal/interactive_draw_eraser_projection.dart',
  'lib/src/interactive/internal/interactive_draw_style.dart',
};

File _requireLcovFile() {
  final lcovFile = File('coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info not found. Run: flutter test --coverage',
    );
    exitCode = 2;
    throw StateError('missing lcov.info');
  }
  return lcovFile;
}

List<String> _collectMissingFromLcov(
  Set<String> libSrcFiles,
  Map<String, _FileCoverage> all,
) {
  final missing = libSrcFiles
      .where(
        (path) =>
            !_excludedDeclarationOnlyFromLcov.contains(path) &&
            !all.containsKey(path) &&
            !_isExportOnlyUnit(path),
      )
      .toList();
  missing.sort();
  return missing;
}

List<_FileCoverage> _collectLibSrcEntries(Map<String, _FileCoverage> all) {
  final entries = all.entries
      .where((entry) => entry.key.startsWith('lib/src/'))
      .map((entry) => entry.value)
      .toList();
  entries.sort((a, b) => a.path.compareTo(b.path));
  return entries;
}

bool _reportMissingFromLcov(List<String> missingFromLcov) {
  if (missingFromLcov.isEmpty) {
    return false;
  }

  stderr.writeln(
    'FAIL: ${missingFromLcov.length} lib/src/** file(s) are missing from coverage/lcov.info.',
  );
  stderr.writeln('These files are not covered at all (no lcov record):');
  for (final path in missingFromLcov) {
    stderr.writeln('  $path');
  }
  exitCode = 1;
  return true;
}

bool _reportMissedLines(List<_FileCoverage> entries) {
  var totalLf = 0;
  var totalLh = 0;
  final missed = <String>[];

  stdout.writeln('Coverage report for lib/src/**');
  for (final file in entries) {
    totalLf += file.effectiveLf;
    totalLh += file.effectiveLh;
    _reportFileCoverage(file, missed);
  }

  stdout.writeln(
    'TOTAL: ${_formatPercent(totalLh, totalLf)}  $totalLh/$totalLf',
  );
  if (missed.isEmpty) {
    return false;
  }

  stdout.writeln('MISSED LINES (${missed.length}):');
  for (final item in missed) {
    stdout.writeln('  $item');
  }
  exitCode = 1;
  return true;
}

void _reportFileCoverage(_FileCoverage file, List<String> missed) {
  final lf = file.effectiveLf;
  final lh = file.effectiveLh;
  stdout.writeln('  ${_formatPercent(lh, lf)}  $lh/$lf  ${file.path}');

  if (lh == lf) {
    return;
  }

  final lines = file.missedLines.toList()..sort();
  for (final lineNo in lines) {
    missed.add('${file.path}:$lineNo');
  }
}

void main(List<String> _) {
  final cwd = Directory.current.path;
  final libSrcFiles = _collectLibSrcDartFiles(cwd: cwd);
  late final File lcovFile;
  try {
    lcovFile = _requireLcovFile();
  } on StateError {
    return;
  }

  final all = _parseLcov(lcovFile.readAsStringSync(), cwd: cwd);
  final missingFromLcov = _collectMissingFromLcov(libSrcFiles, all);
  final entries = _collectLibSrcEntries(all);

  if (entries.isEmpty) {
    stderr.writeln('No coverage entries found for lib/src/**.');
    exitCode = 2;
    return;
  }

  if (_reportMissingFromLcov(missingFromLcov)) {
    return;
  }

  if (_reportMissedLines(entries)) {
    return;
  }

  stdout.writeln('OK: 100% line coverage for lib/src/**');
}
