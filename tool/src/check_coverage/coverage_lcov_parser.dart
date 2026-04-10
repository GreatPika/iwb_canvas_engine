import 'dart:io';

import 'coverage_models.dart';

String toPosixPath(String path) => path.replaceAll('\\', '/');

String normalizeRepoPath(String path, String cwd) {
  var normalized = toPosixPath(path);
  final libSrcIndex = normalized.lastIndexOf('lib/src/');
  if (libSrcIndex != -1) {
    return normalized.substring(libSrcIndex);
  }

  try {
    final absolute = File(normalized).absolute.path.replaceAll('\\', '/');
    final cwdNormalized = cwd.replaceAll('\\', '/');
    if (absolute.startsWith('$cwdNormalized/')) {
      return absolute.substring(cwdNormalized.length + 1);
    }
    return absolute;
  } catch (_) {
    return normalized;
  }
}

Set<String> collectLibSrcDartFiles({required String cwd}) {
  final srcRoot = Directory('lib/src');
  if (!srcRoot.existsSync()) {
    return <String>{};
  }

  final files = <String>{};
  for (final entity in srcRoot.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    files.add(normalizeRepoPath(entity.path, cwd));
  }
  return files;
}

Map<String, FileCoverage> parseLcov(String content, {required String cwd}) {
  final byFile = <String, FileCoverage>{};
  FileCoverage? current;

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trimRight();
    current = _updateCurrentFile(
      line,
      byFile: byFile,
      current: current,
      cwd: cwd,
    );
    if (current == null) {
      continue;
    }
    _recordCoverageLine(current, line);
  }

  return byFile;
}

FileCoverage? _updateCurrentFile(
  String line, {
  required Map<String, FileCoverage> byFile,
  required FileCoverage? current,
  required String cwd,
}) {
  if (!line.startsWith('SF:')) {
    return current;
  }

  final normalized = normalizeRepoPath(line.substring(3), cwd);
  return byFile.putIfAbsent(normalized, () => FileCoverage(normalized));
}

void _recordCoverageLine(FileCoverage current, String line) {
  if (line.startsWith('DA:')) {
    _recordDataLine(current, line.substring(3));
    return;
  }

  if (line.startsWith('BRDA:')) {
    _recordBranchDataLine(current, line.substring(5));
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

void _recordDataLine(FileCoverage current, String data) {
  final parts = data.split(',');
  if (parts.length < 2) {
    return;
  }

  final lineNo = int.tryParse(parts[0]);
  final hits = int.tryParse(parts[1]);
  if (lineNo == null || hits == null) {
    return;
  }

  current.instrumentedLines.add(lineNo);
  if (hits > 0) {
    current.hitLines.add(lineNo);
    current.missedLines.remove(lineNo);
    return;
  }

  if (current.hitLines.contains(lineNo)) {
    return;
  }
  current.missedLines.add(lineNo);
}

void _recordBranchDataLine(FileCoverage current, String data) {
  final parts = data.split(',');
  if (parts.length != 4) {
    return;
  }

  final lineNo = int.tryParse(parts[0]);
  if (lineNo == null) {
    return;
  }

  current.branches.add(
    BranchCoverage(
      line: lineNo,
      block: parts[1],
      branch: parts[2],
      takenRaw: parts[3],
    ),
  );
}

List<FileCoverage> collectLibSrcEntries(Map<String, FileCoverage> all) {
  final entries = all.entries
      .where((entry) => entry.key.startsWith('lib/src/'))
      .map((entry) => entry.value)
      .toList();
  entries.sort((left, right) => left.path.compareTo(right.path));
  return entries;
}

List<BranchCoverage> collectUncoveredBranchesForFile(FileCoverage file) {
  final branches = file.branches.where((branch) => !branch.isCovered).toList();
  branches.sort((left, right) {
    final lineCompare = left.line.compareTo(right.line);
    if (lineCompare != 0) {
      return lineCompare;
    }
    final blockCompare = left.block.compareTo(right.block);
    if (blockCompare != 0) {
      return blockCompare;
    }
    return left.branch.compareTo(right.branch);
  });
  return branches;
}

bool hasBranchData(List<FileCoverage> entries) =>
    entries.any((file) => file.branches.isNotEmpty);
