import 'dart:convert';
import 'dart:io';

import 'src/check_coverage/coverage_declaration_locator.dart';
import 'src/check_coverage/coverage_lcov_parser.dart';
import 'src/check_coverage/coverage_machine_report.dart';
import 'src/check_coverage/coverage_models.dart';
import 'src/check_coverage/coverage_test_target_locator.dart';

const _excludedDeclarationOnlyFromLcov = <String>{
  'lib/src/core/tool_defaults.dart',
  'lib/src/core/grid_safety_limits.dart',
  'lib/src/core/interaction_types.dart',
  'lib/src/core/scene_limits.dart',
  'lib/src/contract/path_fill_rule.dart',
  'lib/src/contract/scene_defaults.dart',
  'lib/src/contract/scene_render_state.dart',
  'lib/src/contract/scene_view_runtime.dart',
  'lib/src/contract/scene_view_render_state.dart',
  'lib/src/interactive/internal/interactive_draw_eraser_projection.dart',
  'lib/src/interactive/internal/interactive_draw_style.dart',
};

File requireLcovFile() {
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

CoverageOptions parseOptions(List<String> args) {
  var json = false;
  var includeUncoveredBranches = false;
  var changedOnly = false;

  for (final arg in args) {
    if (arg == '--json') {
      json = true;
      continue;
    }
    if (arg == '--uncovered-branches') {
      includeUncoveredBranches = true;
      continue;
    }
    if (arg == '--changed-only') {
      changedOnly = true;
      continue;
    }

    stderr.writeln('Unknown argument: $arg');
    exitCode = 64;
    throw ArgumentError.value(arg, 'arg', 'Unsupported flag');
  }

  return CoverageOptions(
    json: json,
    includeUncoveredBranches: includeUncoveredBranches,
    changedOnly: changedOnly,
  );
}

List<String> collectMissingFromLcov(
  Set<String> libSrcFiles,
  Map<String, FileCoverage> all,
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

bool reportMissingFromLcov(List<String> missingFromLcov) {
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

bool reportMissedLines(List<FileCoverage> entries) {
  var totalLf = 0;
  var totalLh = 0;
  final missed = <String>[];

  stdout.writeln('Coverage report for lib/src/**');
  for (final file in entries) {
    totalLf += file.effectiveLf;
    totalLh += file.effectiveLh;
    stdout.writeln(
      '  ${formatPercent(file.effectiveLh, file.effectiveLf)}  '
      '${file.effectiveLh}/${file.effectiveLf}  ${file.path}',
    );
    final lines = file.missedLines.toList()..sort();
    for (final lineNo in lines) {
      missed.add('${file.path}:$lineNo');
    }
  }

  stdout.writeln(
    'TOTAL: ${formatPercent(totalLh, totalLf)}  $totalLh/$totalLf',
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

bool reportMissedBranches(List<FileCoverage> entries) {
  final missed = <String>[];
  for (final file in entries) {
    final branches = collectUncoveredBranchesForFile(file);
    for (final branch in branches) {
      missed.add(
        '${file.path}:${branch.line} block=${branch.block} branch=${branch.branch} taken=${branch.takenRaw}',
      );
    }
  }

  if (missed.isEmpty) {
    return false;
  }

  stdout.writeln('MISSED BRANCHES (${missed.length}):');
  for (final item in missed) {
    stdout.writeln('  $item');
  }
  exitCode = 1;
  return true;
}

String formatPercent(int lh, int lf) {
  if (lf == 0) {
    return '100.00%';
  }
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
    if (trimmed.isEmpty) {
      continue;
    }
    if (trimmed.startsWith('//') ||
        trimmed.startsWith('/*') ||
        trimmed.startsWith('*') ||
        trimmed.startsWith('*/')) {
      continue;
    }
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

class _ChangedFileSelection {
  const _ChangedFileSelection({
    required this.paths,
    required this.applied,
    required this.warnings,
  });

  final Set<String> paths;
  final bool applied;
  final List<String> warnings;
}

_ChangedFileSelection _resolveChangedFileSelection() {
  final result = Process.runSync('git', <String>[
    'status',
    '--porcelain=v1',
    '--untracked-files=all',
    '--',
    'lib/src',
  ]);
  if (result.exitCode != 0) {
    return const _ChangedFileSelection(
      paths: <String>{},
      applied: false,
      warnings: <String>[
        'git status metadata is unavailable; changed-only coverage filtering was skipped.',
      ],
    );
  }

  final changedPaths = <String>{};
  for (final rawLine in result.stdout.toString().split(RegExp(r'\r?\n'))) {
    if (rawLine.isEmpty) {
      continue;
    }
    final line = rawLine.length > 3 ? rawLine.substring(3) : rawLine.trim();
    final normalized = line.replaceAll('\\', '/');
    if (normalized.contains(' -> ')) {
      final parts = normalized.split(' -> ');
      if (parts.length == 2) {
        changedPaths.add(parts.last);
      }
      continue;
    }
    changedPaths.add(normalized);
  }

  return _ChangedFileSelection(
    paths: changedPaths.where((path) => path.startsWith('lib/src/')).toSet(),
    applied: true,
    warnings: const <String>[],
  );
}

List<DeclarationCoverageGap> _buildMachineGaps({
  required List<String> missingFromLcov,
  required List<FileCoverage> entries,
  required bool includeUncoveredBranches,
  required CoverageDeclarationLocator declarationLocator,
  required CoverageTestTargetLocator testTargetLocator,
}) {
  final gaps = <DeclarationCoverageGap>[];

  for (final path in missingFromLcov) {
    gaps.add(
      _attachTargets(
        declarationLocator.locateMissingFileGap(path),
        testTargetLocator,
      ),
    );
  }

  for (final entry in entries) {
    final missedLineNumbers = entry.missedLines.toList()..sort();
    final missedBranches = includeUncoveredBranches
        ? collectUncoveredBranchesForFile(entry)
        : const <BranchCoverage>[];
    if (missedLineNumbers.isEmpty && missedBranches.isEmpty) {
      continue;
    }

    final located = declarationLocator.locateExecutableGaps(
      path: entry.path,
      missedLines: missedLineNumbers,
      missedBranches: missedBranches,
    );
    for (final gap in located) {
      gaps.add(_attachTargets(gap, testTargetLocator));
    }
  }

  return gaps;
}

DeclarationCoverageGap _attachTargets(
  DeclarationCoverageGap gap,
  CoverageTestTargetLocator locator,
) {
  final resolved = locator.resolve(gap.path);
  return DeclarationCoverageGap(
    kind: gap.kind,
    path: gap.path,
    symbol: gap.symbol,
    scope: gap.scope,
    range: gap.range,
    missedLines: gap.missedLines,
    missedBranches: gap.missedBranches,
    snippet: gap.snippet,
    testTargets: resolved.testTargets,
    preferredVerificationScope: resolved.preferredVerificationScope,
  );
}

void main(List<String> args) {
  late final CoverageOptions options;
  try {
    options = parseOptions(args);
  } on ArgumentError {
    return;
  }

  final cwd = Directory.current.path;
  final allLibSrcFiles = collectLibSrcDartFiles(cwd: cwd);
  final warnings = <String>[];
  var changedOnlyApplied = false;
  Set<String>? selectedChangedPaths;
  var selectedLibSrcFiles = allLibSrcFiles;

  if (options.changedOnly) {
    final selection = _resolveChangedFileSelection();
    warnings.addAll(selection.warnings);
    changedOnlyApplied = selection.applied;
    if (selection.applied) {
      selectedChangedPaths = selection.paths;
      selectedLibSrcFiles = allLibSrcFiles
          .where((path) => selection.paths.contains(path))
          .toSet();
    }
  }

  late final File lcovFile;
  try {
    lcovFile = requireLcovFile();
  } on StateError {
    return;
  }

  final allCoverage = parseLcov(lcovFile.readAsStringSync(), cwd: cwd);
  final allEntries = collectLibSrcEntries(allCoverage);
  if (allEntries.isEmpty) {
    if (options.json) {
      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert(<String, Object>{
          'gaps': const <Object>[],
          'warnings': warnings,
          'branchDataAvailable': false,
          'changedOnlyApplied': changedOnlyApplied,
          'error': 'No coverage entries found for lib/src/**.',
        }),
      );
    } else {
      stderr.writeln('No coverage entries found for lib/src/**.');
    }
    exitCode = 2;
    return;
  }

  final entries = changedOnlyApplied
      ? () {
          final changedPaths = selectedChangedPaths;
          if (changedPaths == null) {
            throw StateError(
              'changedOnlyApplied requires selectedChangedPaths to be present.',
            );
          }
          return allEntries
              .where((entry) => changedPaths.contains(entry.path))
              .toList();
        }()
      : allEntries;
  final coverageIndex = <String, FileCoverage>{
    for (final entry in entries) entry.path: entry,
  };
  final missingFromLcov = collectMissingFromLcov(
    selectedLibSrcFiles,
    coverageIndex,
  );

  if (options.json) {
    final branchDataAvailable = hasBranchData(entries);
    if (options.includeUncoveredBranches && !branchDataAvailable) {
      warnings.add(
        'coverage/lcov.info does not contain BRDA entries; uncovered branch diagnostics are unavailable.',
      );
    }

    final declarationLocator = CoverageDeclarationLocator();
    final testTargetLocator = CoverageTestTargetLocator();
    final report = buildCoverageMachineReport(
      gaps: _buildMachineGaps(
        missingFromLcov: missingFromLcov,
        entries: entries,
        includeUncoveredBranches: options.includeUncoveredBranches,
        declarationLocator: declarationLocator,
        testTargetLocator: testTargetLocator,
      ),
      warnings: warnings,
      branchDataAvailable: branchDataAvailable,
      changedOnlyApplied: changedOnlyApplied,
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
    exitCode = report.gaps.isEmpty ? 0 : 1;
    return;
  }

  if (_reportMissingThenReturn(missingFromLcov)) {
    return;
  }
  if (reportMissedLines(entries)) {
    return;
  }
  if (options.includeUncoveredBranches && reportMissedBranches(entries)) {
    return;
  }

  stdout.writeln('OK: 100% line coverage for lib/src/**');
}

bool _reportMissingThenReturn(List<String> missingFromLcov) {
  if (!reportMissingFromLcov(missingFromLcov)) {
    return false;
  }
  return true;
}
