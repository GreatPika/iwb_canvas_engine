import 'dart:convert';
import 'dart:io';

import 'load_profile_policy.dart';

const _resultPrefix = 'IWB_BENCH_RESULT ';

Future<void> main(List<String> args) async {
  final options = parseSelectionControlDiagnosticArgs(args);
  loadProfilePolicyFor(options.profile);

  final reports = <Map<String, Object?>>[];
  for (final descriptor in _selectionDiagnosticCases(options.profile)) {
    stdout.writeln(
      'Running selection control diagnostic '
      '${descriptor.name} profile=${options.profile} repeats=${options.repeats}',
    );
    final runs = <SelectionCaseRun>[];
    for (var i = 0; i < options.repeats; i++) {
      final run = await _runSelectionCase(
        profile: options.profile,
        caseName: descriptor.name,
        plainName: descriptor.plainName,
      );
      runs.add(run);
      stdout.writeln(
        '  run=${i + 1} no=${run.paintNoSelectionAvgUs} '
        'with=${run.paintWithSelectionAvgUs} '
        'ratio=${run.withOverNoRatio.toStringAsFixed(4)}',
      );
    }
    reports.add(_buildSelectionCaseReport(descriptor.name, runs));
  }

  final report = <String, Object?>{
    'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'profile': options.profile,
    'repeats': options.repeats,
    'caseCount': reports.length,
    'cases': reports,
  };

  final outputFile = File(options.outputPath);
  outputFile.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  outputFile.writeAsStringSync('${encoder.convert(report)}\n');
  stdout.writeln('Selection diagnostic report written: ${outputFile.path}');
}

SelectionControlDiagnosticOptions parseSelectionControlDiagnosticArgs(
  List<String> args,
) {
  var profile = 'smoke';
  var repeats = 7;
  String? outputPath;

  for (final arg in args) {
    if (arg.startsWith('--profile=')) {
      profile = arg.substring('--profile='.length).trim().toLowerCase();
      continue;
    }
    if (arg.startsWith('--repeats=')) {
      final rawRepeats = int.tryParse(
        arg.substring('--repeats='.length).trim(),
      );
      if (rawRepeats == null || rawRepeats <= 0) {
        throw ArgumentError.value(arg, 'repeats', 'Must be a positive int.');
      }
      repeats = rawRepeats;
      continue;
    }
    if (arg.startsWith('--output=')) {
      outputPath = arg.substring('--output='.length).trim();
      continue;
    }
    if (arg == '--help' || arg == '-h') {
      _printUsageAndExit(0);
    }
    stderr.writeln('Unknown argument: $arg');
    _printUsageAndExit(2);
  }

  return SelectionControlDiagnosticOptions(
    profile: profile,
    repeats: repeats,
    outputPath:
        outputPath ?? 'build/bench/selection_control_diagnostics_$profile.json',
  );
}

List<_SelectionDiagnosticCase> _selectionDiagnosticCases(String profile) {
  return <_SelectionDiagnosticCase>[
    _SelectionDiagnosticCase(
      name: selectionPathPainterOnlyCaseName,
      plainName: 'load profile selection-path-painter-only profile=$profile',
    ),
    _SelectionDiagnosticCase(
      name: selectionPathEndToEndPaintCaseName,
      plainName:
          'load profile selection-path-end-to-end-paint profile=$profile',
    ),
  ];
}

Future<SelectionCaseRun> _runSelectionCase({
  required String profile,
  required String caseName,
  required String plainName,
}) async {
  final process = await Process.start(
    'flutter',
    <String>[
      'test',
      'tool/bench/load_profiles_cases_test.dart',
      '--reporter',
      'expanded',
      '--plain-name',
      plainName,
    ],
    environment: <String, String>{
      ...Platform.environment,
      'IWB_BENCH_PROFILE': profile,
    },
    runInShell: true,
  );

  final stdoutLines = <String>[];
  final stdoutDone = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        stdoutLines.add(line);
        stdout.writeln(line);
      })
      .asFuture<void>();
  final stderrDone = process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(stderr.writeln)
      .asFuture<void>();

  final exitCode = await process.exitCode;
  await Future.wait(<Future<void>>[stdoutDone, stderrDone]);
  if (exitCode != 0) {
    throw ProcessException(
      'flutter',
      <String>[
        'test',
        'tool/bench/load_profiles_cases_test.dart',
        '--reporter',
        'expanded',
        '--plain-name',
        plainName,
      ],
      'Selection case exited with $exitCode.',
      exitCode,
    );
  }

  final result = extractBenchResult(stdoutLines, expectedCaseName: caseName);
  return parseSelectionCaseRun(result);
}

Map<String, Object?> extractBenchResult(
  Iterable<String> stdoutLines, {
  required String expectedCaseName,
}) {
  for (final line in stdoutLines) {
    if (!line.startsWith(_resultPrefix)) {
      continue;
    }
    final decoded = jsonDecode(line.substring(_resultPrefix.length));
    if (decoded is! Map<String, Object?>) {
      continue;
    }
    if (decoded['name'] == expectedCaseName) {
      return decoded;
    }
  }
  throw StateError('Missing benchmark result for "$expectedCaseName".');
}

SelectionCaseRun parseSelectionCaseRun(Map<String, Object?> benchResult) {
  final metrics = benchResult['metrics'];
  if (metrics is! Map<String, Object?>) {
    throw StateError('Selection benchmark result is missing "metrics".');
  }
  final noSelection = metrics['paint_no_selection'];
  final withSelection = metrics['paint_with_selection'];
  if (noSelection is! Map<String, Object?> ||
      withSelection is! Map<String, Object?>) {
    throw StateError(
      'Selection benchmark result must include paint_no_selection and '
      'paint_with_selection metrics.',
    );
  }

  final probes = benchResult['probes'];
  final noSelectionProbe = probes is Map<String, Object?>
      ? probes['paint_no_selection']
      : null;
  final withSelectionProbe = probes is Map<String, Object?>
      ? probes['paint_with_selection']
      : null;

  return SelectionCaseRun(
    paintNoSelectionAvgUs: _readRequiredMetric(
      noSelection,
      key: 'avgUs',
      context: 'paint_no_selection',
    ),
    paintWithSelectionAvgUs: _readRequiredMetric(
      withSelection,
      key: 'avgUs',
      context: 'paint_with_selection',
    ),
    paintNoSelectionAvgRssDeltaBytes: _readRequiredMetric(
      noSelection,
      key: 'avgRssDeltaBytes',
      context: 'paint_no_selection',
    ),
    paintWithSelectionAvgRssDeltaBytes: _readRequiredMetric(
      withSelection,
      key: 'avgRssDeltaBytes',
      context: 'paint_with_selection',
    ),
    paintNoSelectionProbe: _parseSelectionProbe(noSelectionProbe),
    paintWithSelectionProbe: _parseSelectionProbe(withSelectionProbe),
  );
}

num _readRequiredMetric(
  Map<String, Object?> operation, {
  required String key,
  required String context,
}) {
  final value = operation[key];
  if (value is! num || !value.isFinite) {
    throw StateError('Selection metric "$context.$key" must be a finite num.');
  }
  return value;
}

SelectionCaseProbe? _parseSelectionProbe(Object? rawProbe) {
  if (rawProbe is! Map<String, Object?>) {
    return null;
  }
  final saveLayerCount = rawProbe['saveLayerCount'];
  final unboundedSaveLayerCount = rawProbe['unboundedSaveLayerCount'];
  final saveLayerBoundsArea = rawProbe['saveLayerBoundsArea'];
  if (saveLayerCount is! num ||
      unboundedSaveLayerCount is! num ||
      saveLayerBoundsArea is! num ||
      !saveLayerCount.isFinite ||
      !unboundedSaveLayerCount.isFinite ||
      !saveLayerBoundsArea.isFinite) {
    return null;
  }
  return SelectionCaseProbe(
    saveLayerCount: saveLayerCount,
    unboundedSaveLayerCount: unboundedSaveLayerCount,
    saveLayerBoundsArea: saveLayerBoundsArea,
  );
}

Map<String, Object?> _buildSelectionCaseReport(
  String caseName,
  List<SelectionCaseRun> runs,
) {
  final noValues = runs.map((run) => run.paintNoSelectionAvgUs).toList();
  final withValues = runs.map((run) => run.paintWithSelectionAvgUs).toList();
  final ratioValues = runs.map((run) => run.withOverNoRatio).toList();
  final deltaPctValues = ratioValues
      .map((ratio) => (ratio - 1) * 100)
      .toList(growable: false);

  final noProbeSummary = _buildProbeSummary(
    runs
        .map((run) => run.paintNoSelectionProbe)
        .whereType<SelectionCaseProbe>()
        .toList(growable: false),
  );
  final withProbeSummary = _buildProbeSummary(
    runs
        .map((run) => run.paintWithSelectionProbe)
        .whereType<SelectionCaseProbe>()
        .toList(growable: false),
  );

  return <String, Object?>{
    'name': caseName,
    'runCount': runs.length,
    'summary': <String, Object?>{
      'paintNoSelectionMedianAvgUs': _median(noValues),
      'paintWithSelectionMedianAvgUs': _median(withValues),
      'paintNoSelectionMeanAvgUs': _mean(noValues),
      'paintWithSelectionMeanAvgUs': _mean(withValues),
      'medianWithOverNoRatio': _median(ratioValues),
      'meanWithOverNoRatio': _mean(ratioValues),
      'medianWithOverNoDeltaPct': _median(deltaPctValues),
      'meanWithOverNoDeltaPct': _mean(deltaPctValues),
      if (noProbeSummary != null)
        'paintNoSelectionProbeSummary': noProbeSummary,
      if (withProbeSummary != null)
        'paintWithSelectionProbeSummary': withProbeSummary,
    },
    'runs': runs.map((run) => run.toJson()).toList(growable: false),
  };
}

Map<String, Object?>? _buildProbeSummary(List<SelectionCaseProbe> probes) {
  if (probes.isEmpty) {
    return null;
  }
  return <String, Object?>{
    'medianSaveLayerCount': _median(
      probes.map((probe) => probe.saveLayerCount).toList(growable: false),
    ),
    'medianUnboundedSaveLayerCount': _median(
      probes
          .map((probe) => probe.unboundedSaveLayerCount)
          .toList(growable: false),
    ),
    'medianSaveLayerBoundsArea': _median(
      probes.map((probe) => probe.saveLayerBoundsArea).toList(growable: false),
    ),
  };
}

double _mean(List<num> values) {
  if (values.isEmpty) {
    throw ArgumentError.value(values, 'values', 'Must not be empty.');
  }
  return values.fold<double>(0, (sum, value) => sum + value) / values.length;
}

double _median(List<num> values) {
  if (values.isEmpty) {
    throw ArgumentError.value(values, 'values', 'Must not be empty.');
  }
  final sorted = values.map((value) => value.toDouble()).toList()..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[mid];
  }
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

Never _printUsageAndExit(int code) {
  stdout.writeln(
    'Usage: dart run tool/bench/run_selection_control_diagnostics.dart '
    '[--profile=<smoke|full>] [--repeats=<positive-int>] [--output=<path>]',
  );
  exit(code);
}

class SelectionControlDiagnosticOptions {
  const SelectionControlDiagnosticOptions({
    required this.profile,
    required this.repeats,
    required this.outputPath,
  });

  final String profile;
  final int repeats;
  final String outputPath;
}

class SelectionCaseRun {
  const SelectionCaseRun({
    required this.paintNoSelectionAvgUs,
    required this.paintWithSelectionAvgUs,
    required this.paintNoSelectionAvgRssDeltaBytes,
    required this.paintWithSelectionAvgRssDeltaBytes,
    required this.paintNoSelectionProbe,
    required this.paintWithSelectionProbe,
  });

  final num paintNoSelectionAvgUs;
  final num paintWithSelectionAvgUs;
  final num paintNoSelectionAvgRssDeltaBytes;
  final num paintWithSelectionAvgRssDeltaBytes;
  final SelectionCaseProbe? paintNoSelectionProbe;
  final SelectionCaseProbe? paintWithSelectionProbe;

  double get withOverNoRatio =>
      paintWithSelectionAvgUs.toDouble() / paintNoSelectionAvgUs.toDouble();

  Map<String, Object?> toJson() {
    final paintNoSelectionProbe = this.paintNoSelectionProbe;
    final paintWithSelectionProbe = this.paintWithSelectionProbe;
    return <String, Object?>{
      'paintNoSelectionAvgUs': paintNoSelectionAvgUs,
      'paintWithSelectionAvgUs': paintWithSelectionAvgUs,
      'withOverNoRatio': withOverNoRatio,
      'paintNoSelectionAvgRssDeltaBytes': paintNoSelectionAvgRssDeltaBytes,
      'paintWithSelectionAvgRssDeltaBytes': paintWithSelectionAvgRssDeltaBytes,
      if (paintNoSelectionProbe != null)
        'paintNoSelectionProbe': paintNoSelectionProbe.toJson(),
      if (paintWithSelectionProbe != null)
        'paintWithSelectionProbe': paintWithSelectionProbe.toJson(),
    };
  }
}

class SelectionCaseProbe {
  const SelectionCaseProbe({
    required this.saveLayerCount,
    required this.unboundedSaveLayerCount,
    required this.saveLayerBoundsArea,
  });

  final num saveLayerCount;
  final num unboundedSaveLayerCount;
  final num saveLayerBoundsArea;

  Map<String, Object?> toJson() => <String, Object?>{
    'saveLayerCount': saveLayerCount,
    'unboundedSaveLayerCount': unboundedSaveLayerCount,
    'saveLayerBoundsArea': saveLayerBoundsArea,
  };
}

class _SelectionDiagnosticCase {
  const _SelectionDiagnosticCase({required this.name, required this.plainName});

  final String name;
  final String plainName;
}
