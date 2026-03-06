import 'dart:convert';
import 'dart:io';

import 'load_profile_policy.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  late final Map<String, Object?> report;
  var exitCode = 0;

  try {
    final baseline = _readJsonFileAsObject(options.baselinePath);
    final current = _readJsonFileAsObject(options.currentPath);
    report = buildDiffReport(
      baseline: baseline,
      current: current,
      requiredProfile: options.profile,
      baselinePath: options.baselinePath,
      currentPath: options.currentPath,
    );
    if (report['status'] != 'pass') {
      exitCode = 1;
      stderr.writeln('FAIL: benchmark diff policy violations detected.');
    }
  } on _DiffToolInputException catch (error) {
    report = _buildDiffFailureReport(
      baselinePath: options.baselinePath,
      currentPath: options.currentPath,
      profile: options.profile,
      message: error.message,
    );
    exitCode = 1;
    stderr.writeln('FAIL: ${error.message}');
  }

  final outputFile = File(options.outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln('Benchmark diff report written: ${outputFile.path}');
  if (exitCode != 0) {
    exit(exitCode);
  }
}

Map<String, Object?> buildDiffReport({
  required Map<String, Object?> baseline,
  required Map<String, Object?> current,
  String? requiredProfile,
  required String baselinePath,
  required String currentPath,
}) {
  final baselineReport = _readReportFromObject(
    baseline,
    sourcePath: baselinePath,
    requiredProfile: null,
  );
  final resolvedProfile = requiredProfile ?? baselineReport.profile;
  final currentReport = _readReportFromObject(
    current,
    sourcePath: currentPath,
    requiredProfile: resolvedProfile,
  );
  final policy = _requirePolicy(resolvedProfile);

  if (baselineReport.profile != resolvedProfile ||
      currentReport.profile != resolvedProfile) {
    throw _DiffToolInputException(
      'profile mismatch. baseline=${baselineReport.profile} '
      'current=${currentReport.profile} expected=$resolvedProfile',
    );
  }

  final baselineByCase = <String, _CaseReport>{
    for (final c in baselineReport.cases) c.name: c,
  };
  final currentByCase = <String, _CaseReport>{
    for (final c in currentReport.cases) c.name: c,
  };

  final allCaseNames = <String>{
    ...baselineByCase.keys,
    ...currentByCase.keys,
  }.toList(growable: false)..sort();

  final requiredCaseNames = policy.requiredCaseNames.toSet();
  final missingInBaseline = <String>[];
  final missingInCurrent = <String>[];
  final comparedCases = <Map<String, Object?>>[];
  final failures = <String>[];

  for (final caseName in allCaseNames) {
    final baselineCase = baselineByCase[caseName];
    final currentCase = currentByCase[caseName];
    if (baselineCase == null) {
      missingInBaseline.add(caseName);
      continue;
    }
    if (currentCase == null) {
      missingInCurrent.add(caseName);
      continue;
    }
    comparedCases.add(
      _diffCase(
        caseName: caseName,
        baseline: baselineCase,
        current: currentCase,
        requiredOperations: policy.requiredOperationsForCase(caseName),
        maxRegressionPctByMetric: policy.maxRegressionPctByMetric,
        maxAbsoluteValueByMetric: policy.maxAbsoluteValueByMetric,
      ),
    );
  }

  final missingRequiredInBaseline =
      requiredCaseNames
          .where((name) => !baselineByCase.containsKey(name))
          .toList()
        ..sort();
  final missingRequiredInCurrent =
      requiredCaseNames
          .where((name) => !currentByCase.containsKey(name))
          .toList()
        ..sort();

  if (missingInBaseline.isNotEmpty) {
    failures.add('missing cases in baseline: ${missingInBaseline.join(', ')}');
  }
  if (missingInCurrent.isNotEmpty) {
    failures.add('missing cases in current: ${missingInCurrent.join(', ')}');
  }
  if (missingRequiredInBaseline.isNotEmpty) {
    failures.add(
      'missing required cases in baseline: '
      '${missingRequiredInBaseline.join(', ')}',
    );
  }
  if (missingRequiredInCurrent.isNotEmpty) {
    failures.add(
      'missing required cases in current: '
      '${missingRequiredInCurrent.join(', ')}',
    );
  }

  for (final caseReport in comparedCases) {
    final caseName = caseReport['name'] as String;
    final summary = caseReport['summary'] as Map<String, Object?>;
    final missingRequiredOpsInBaseline =
        (summary['missingRequiredOperationsInBaseline'] as List<Object?>)
            .cast<String>();
    final missingRequiredOpsInCurrent =
        (summary['missingRequiredOperationsInCurrent'] as List<Object?>)
            .cast<String>();
    if (missingRequiredOpsInBaseline.isNotEmpty) {
      failures.add(
        '$caseName missing required operations in baseline: '
        '${missingRequiredOpsInBaseline.join(', ')}',
      );
    }
    if (missingRequiredOpsInCurrent.isNotEmpty) {
      failures.add(
        '$caseName missing required operations in current: '
        '${missingRequiredOpsInCurrent.join(', ')}',
      );
    }

    final operations = caseReport['operations'] as List<Object?>;
    for (final rawOperation in operations) {
      final operation = rawOperation as Map<String, Object?>;
      final operationName = operation['operation'] as String;
      final metrics = operation['metrics'] as List<Object?>;
      for (final rawMetric in metrics) {
        final metric = rawMetric as Map<String, Object?>;
        if (metric['status'] == 'regressed') {
          if (metric['deltaPct'] == null &&
              metric['maxAllowedAbsoluteValue'] != null) {
            failures.add(
              '$caseName/$operationName ${metric['metric']} current value '
              '${metric['currentUs']} exceeds absolute limit '
              '${metric['maxAllowedAbsoluteValue']}',
            );
          } else {
            failures.add(
              '$caseName/$operationName ${metric['metric']} regression '
              '${metric['deltaPct']}% exceeds '
              '${metric['maxAllowedRegressionPct']}%',
            );
          }
        }
      }
    }
  }

  final status = failures.isEmpty ? 'pass' : 'fail';
  return <String, Object?>{
    'profile': resolvedProfile,
    'baselinePath': baselinePath,
    'currentPath': currentPath,
    'status': status,
    'policy': <String, Object?>{
      'requiredCases': policy.requiredCaseNames,
      'maxRegressionPctByMetric': policy.maxRegressionPctByMetric,
      'maxAbsoluteValueByMetric': policy.maxAbsoluteValueByMetric,
    },
    'failures': failures,
    'summary': <String, Object?>{
      'totalUniqueCases': allCaseNames.length,
      'comparedCases': comparedCases.length,
      'missingInBaseline': missingInBaseline,
      'missingInCurrent': missingInCurrent,
      'missingRequiredInBaseline': missingRequiredInBaseline,
      'missingRequiredInCurrent': missingRequiredInCurrent,
      'failureCount': failures.length,
    },
    'cases': comparedCases,
  };
}

Map<String, Object?> _diffCase({
  required String caseName,
  required _CaseReport baseline,
  required _CaseReport current,
  required List<String> requiredOperations,
  required Map<String, double> maxRegressionPctByMetric,
  required Map<String, double> maxAbsoluteValueByMetric,
}) {
  final operationNames = <String>{
    ...baseline.metricsByOperation.keys,
    ...current.metricsByOperation.keys,
  }.toList(growable: false)..sort();

  final missingInBaseline = <String>[];
  final missingInCurrent = <String>[];
  final operations = <Map<String, Object?>>[];

  for (final op in operationNames) {
    final baselineMetrics = baseline.metricsByOperation[op];
    final currentMetrics = current.metricsByOperation[op];
    if (baselineMetrics == null) {
      missingInBaseline.add(op);
      continue;
    }
    if (currentMetrics == null) {
      missingInCurrent.add(op);
      continue;
    }

    final metricDiffs = <Map<String, Object?>>[];
    for (final metricKey in loadProfileRequiredMetricKeys) {
      final baselineValue = baselineMetrics[metricKey]!;
      final currentValue = currentMetrics[metricKey]!;
      final deltaAbsUs = currentValue - baselineValue;
      final threshold = maxRegressionPctByMetric[metricKey];
      final absoluteThreshold = maxAbsoluteValueByMetric[metricKey];
      final metricDiff = <String, Object?>{
        'metric': metricKey,
        'baselineUs': baselineValue,
        'currentUs': currentValue,
        'deltaAbsUs': deltaAbsUs,
        'maxAllowedRegressionPct': threshold,
        'maxAllowedAbsoluteValue': absoluteThreshold,
      };
      if (baselineValue <= 0) {
        metricDiff['deltaPct'] = null;
        metricDiff['deltaPctNote'] = 'baseline_is_zero_or_negative';
        if (absoluteThreshold != null && currentValue > absoluteThreshold) {
          metricDiff['status'] = 'regressed';
        } else if (absoluteThreshold != null) {
          metricDiff['status'] = 'ok';
        } else {
          metricDiff['status'] = threshold == null
              ? 'not_gated'
              : 'baseline_zero';
        }
      } else {
        final deltaPct = _roundTo3(((deltaAbsUs / baselineValue) * 100));
        metricDiff['deltaPct'] = deltaPct;
        if (threshold == null) {
          metricDiff['status'] = 'not_gated';
        } else if (deltaPct > threshold) {
          metricDiff['status'] = 'regressed';
        } else {
          metricDiff['status'] = 'ok';
        }
      }
      metricDiffs.add(metricDiff);
    }
    operations.add(<String, Object?>{'operation': op, 'metrics': metricDiffs});
  }

  final requiredOperationSet = requiredOperations.toSet();
  final missingRequiredInBaseline =
      requiredOperationSet
          .where((op) => !baseline.metricsByOperation.containsKey(op))
          .toList()
        ..sort();
  final missingRequiredInCurrent =
      requiredOperationSet
          .where((op) => !current.metricsByOperation.containsKey(op))
          .toList()
        ..sort();

  return <String, Object?>{
    'name': caseName,
    'summary': <String, Object?>{
      'missingOperationsInBaseline': missingInBaseline,
      'missingOperationsInCurrent': missingInCurrent,
      'missingRequiredOperationsInBaseline': missingRequiredInBaseline,
      'missingRequiredOperationsInCurrent': missingRequiredInCurrent,
    },
    'operations': operations,
  };
}

double _roundTo3(double value) => (value * 1000).round() / 1000;

Map<String, Object?> _readJsonFileAsObject(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw _DiffToolInputException('report file does not exist: $path');
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    throw _DiffToolInputException('invalid json in $path: ${error.message}');
  }

  if (decoded is! Map<String, Object?>) {
    throw _DiffToolInputException('report root must be an object: $path');
  }
  return decoded;
}

LoadProfilePolicy _requirePolicy(String profile) {
  try {
    return loadProfilePolicyFor(profile);
  } on ArgumentError {
    throw _DiffToolInputException(
      'unsupported benchmark profile "$profile"; expected smoke or full',
    );
  }
}

Map<String, Object?> _buildDiffFailureReport({
  required String baselinePath,
  required String currentPath,
  required String? profile,
  required String message,
}) {
  return <String, Object?>{
    'profile': profile,
    'baselinePath': baselinePath,
    'currentPath': currentPath,
    'status': 'fail',
    'policy': null,
    'failures': <String>[message],
    'summary': <String, Object?>{
      'totalUniqueCases': 0,
      'comparedCases': 0,
      'missingInBaseline': const <String>[],
      'missingInCurrent': const <String>[],
      'missingRequiredInBaseline': const <String>[],
      'missingRequiredInCurrent': const <String>[],
      'failureCount': 1,
    },
    'cases': const <Map<String, Object?>>[],
  };
}

_Report _readReportFromObject(
  Map<String, Object?> decoded, {
  required String sourcePath,
  required String? requiredProfile,
}) {
  final profile = _requireString(decoded, 'profile', sourcePath: sourcePath);
  if (requiredProfile != null && profile != requiredProfile) {
    throw _DiffToolInputException(
      'report profile mismatch for $sourcePath. '
      'actual=$profile expected=$requiredProfile',
    );
  }

  final rawCases = decoded['cases'];
  if (rawCases is! List) {
    throw _DiffToolInputException(
      'report field "cases" must be a list: $sourcePath',
    );
  }

  final cases = <_CaseReport>[];
  for (var i = 0; i < rawCases.length; i++) {
    final rawCase = rawCases[i];
    if (rawCase is! Map<String, Object?>) {
      throw _DiffToolInputException(
        'cases[$i] must be an object in $sourcePath',
      );
    }
    final caseName = _requireString(
      rawCase,
      'name',
      sourcePath: '$sourcePath#cases[$i]',
    );
    final rawMetrics = rawCase['metrics'];
    if (rawMetrics is! Map<String, Object?>) {
      throw _DiffToolInputException(
        'cases[$i].metrics must be an object in $sourcePath',
      );
    }

    final metricsByOperation = <String, Map<String, double>>{};
    _collectMetricLeaves(
      root: rawMetrics,
      pathPrefix: '',
      sourcePath: '$sourcePath#cases[$i]',
      sink: metricsByOperation,
    );
    if (metricsByOperation.isEmpty) {
      throw _DiffToolInputException(
        'cases[$i].metrics has no benchmark metric leaves in $sourcePath',
      );
    }

    cases.add(
      _CaseReport(name: caseName, metricsByOperation: metricsByOperation),
    );
  }
  return _Report(profile: profile, cases: cases);
}

String _requireString(
  Map<String, Object?> map,
  String key, {
  required String sourcePath,
}) {
  final value = map[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw _DiffToolInputException(
    'field "$key" must be a non-empty string in $sourcePath',
  );
}

_Options _parseArgs(List<String> args) {
  String? profile;
  String? baselinePath;
  String? currentPath;
  String? outputPath;

  for (final arg in args) {
    if (arg.startsWith('--profile=')) {
      profile = arg.substring('--profile='.length).trim();
      continue;
    }
    if (arg.startsWith('--baseline=')) {
      baselinePath = arg.substring('--baseline='.length).trim();
      continue;
    }
    if (arg.startsWith('--current=')) {
      currentPath = arg.substring('--current='.length).trim();
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

  if (baselinePath == null || baselinePath.isEmpty) {
    stderr.writeln('Missing required --baseline=<path>');
    _printUsageAndExit(2);
  }
  if (currentPath == null || currentPath.isEmpty) {
    stderr.writeln('Missing required --current=<path>');
    _printUsageAndExit(2);
  }
  if (outputPath == null || outputPath.isEmpty) {
    stderr.writeln('Missing required --output=<path>');
    _printUsageAndExit(2);
  }

  if (profile != null && profile.isNotEmpty) {
    final normalized = profile.trim().toLowerCase();
    if (normalized != 'smoke' && normalized != 'full') {
      stderr.writeln('Invalid --profile value: $profile');
      _printUsageAndExit(2);
    }
    profile = normalized;
  } else {
    profile = null;
  }

  return _Options(
    profile: profile,
    baselinePath: baselinePath,
    currentPath: currentPath,
    outputPath: outputPath,
  );
}

Never _printUsageAndExit(int code) {
  stdout.writeln(
    'Usage: dart run tool/bench/diff_load_profiles.dart '
    '--baseline=<path> --current=<path> --output=<path> '
    '[--profile=<smoke|full>]',
  );
  exit(code);
}

class _Options {
  const _Options({
    required this.profile,
    required this.baselinePath,
    required this.currentPath,
    required this.outputPath,
  });

  final String? profile;
  final String baselinePath;
  final String currentPath;
  final String outputPath;
}

class _Report {
  const _Report({required this.profile, required this.cases});

  final String profile;
  final List<_CaseReport> cases;
}

class _CaseReport {
  const _CaseReport({required this.name, required this.metricsByOperation});

  final String name;
  final Map<String, Map<String, double>> metricsByOperation;
}

class _DiffToolInputException implements Exception {
  const _DiffToolInputException(this.message);

  final String message;

  @override
  String toString() => message;
}

void _collectMetricLeaves({
  required Map<String, Object?> root,
  required String pathPrefix,
  required String sourcePath,
  required Map<String, Map<String, double>> sink,
}) {
  final hasAnyRequiredKey = loadProfileRequiredMetricKeys.any(root.containsKey);
  if (hasAnyRequiredKey) {
    final metricValues = <String, double>{};
    for (final metricKey in loadProfileRequiredMetricKeys) {
      final raw = root[metricKey];
      if (raw is! num || !raw.isFinite) {
        final metricPath = pathPrefix.isEmpty
            ? metricKey
            : '$pathPrefix.$metricKey';
        throw _DiffToolInputException(
          'cases metrics.$metricPath must be a finite number in $sourcePath',
        );
      }
      metricValues[metricKey] = raw.toDouble();
    }
    final rawMetricPath = pathPrefix.isEmpty ? 'root' : pathPrefix;
    final metricPath = _normalizeOperationPath(rawMetricPath);
    final existing = sink[metricPath];
    if (existing != null && existing.toString() != metricValues.toString()) {
      throw _DiffToolInputException(
        'duplicate operation path after normalization: '
        '$rawMetricPath -> $metricPath in $sourcePath',
      );
    }
    sink[metricPath] = metricValues;
    return;
  }

  final keys = root.keys.toList(growable: false)..sort();
  for (final key in keys) {
    final child = root[key];
    if (child is! Map<String, Object?>) {
      continue;
    }
    final childPath = pathPrefix.isEmpty ? key : '$pathPrefix.$key';
    _collectMetricLeaves(
      root: child,
      pathPrefix: childPath,
      sourcePath: sourcePath,
      sink: sink,
    );
  }
}

String _normalizeOperationPath(String path) {
  if (path == 'root') {
    return path;
  }
  var normalized = path;
  while (normalized.startsWith('metrics.')) {
    normalized = normalized.substring('metrics.'.length);
  }
  return normalized;
}
