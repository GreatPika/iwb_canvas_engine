import 'dart:convert';
import 'dart:io';

import 'load_profile_policy.dart';

const _resultPrefix = 'IWB_BENCH_RESULT ';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final policy = loadProfilePolicyFor(options.profile);
  final profile = policy.profile;
  final outputPath =
      options.outputPath ?? 'build/bench/load_profiles_$profile.json';

  final command = <String>[
    'test',
    'tool/bench/load_profiles_cases_test.dart',
    '--reporter',
    'expanded',
  ];

  final process = await Process.start(
    'flutter',
    command,
    environment: <String, String>{
      ...Platform.environment,
      'IWB_BENCH_PROFILE': profile,
    },
    runInShell: true,
  );

  final parsedCases = <Map<String, Object?>>[];
  final stdoutDone = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        stdout.writeln(line);
        if (!line.startsWith(_resultPrefix)) {
          return;
        }
        final rawJson = line.substring(_resultPrefix.length);
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, Object?>) {
          parsedCases.add(decoded);
        }
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
    stderr.writeln('FAIL: flutter ${command.join(' ')} exited with $exitCode');
    exit(exitCode);
  }
  if (parsedCases.isEmpty) {
    stderr.writeln('FAIL: no benchmark cases were produced.');
    exit(1);
  }
  final validationIssues = validateCollectedBenchmarkCases(
    policy: policy,
    parsedCases: parsedCases,
  );
  if (validationIssues.isNotEmpty) {
    for (final issue in validationIssues) {
      stderr.writeln('FAIL: $issue');
    }
    exit(1);
  }
  final contractIssues = validateCollectedBenchmarkCaseContracts(
    policy: policy,
    parsedCases: parsedCases,
  );
  if (contractIssues.isNotEmpty) {
    for (final issue in contractIssues) {
      stderr.writeln('FAIL: $issue');
    }
    exit(1);
  }

  final report = <String, Object?>{
    'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'profile': profile,
    ...collectLoadProfileRuntimeMetadata(),
    'policy': policy.reportMetadata,
    'caseCount': parsedCases.length,
    'cases': parsedCases,
  };
  final reportIssues = validateReportRuntimeMetadata(report: report);
  if (reportIssues.isNotEmpty) {
    for (final issue in reportIssues) {
      stderr.writeln('FAIL: $issue');
    }
    exit(1);
  }

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  final encoder = const JsonEncoder.withIndent('  ');
  outputFile.writeAsStringSync('${encoder.convert(report)}\n');
  stdout.writeln('Benchmark report written: ${outputFile.path}');
}

Map<String, Object?> collectLoadProfileRuntimeMetadata() {
  return Map<String, Object?>.of(fixedHarnessRuntimeMetadata);
}

List<String> validateReportRuntimeMetadata({
  required Map<String, Object?> report,
}) {
  final issues = <String>[];
  for (final entry in fixedHarnessRuntimeMetadata.entries) {
    if (report[entry.key] != entry.value) {
      issues.add(
        'report ${entry.key} must equal fixed harness value ${entry.value}',
      );
    }
  }
  return issues;
}

List<String> validateCollectedBenchmarkCases({
  required LoadProfilePolicy policy,
  required List<Map<String, Object?>> parsedCases,
}) {
  final caseNames = <String>[];
  for (var i = 0; i < parsedCases.length; i++) {
    final rawName = parsedCases[i]['name'];
    if (rawName is! String || rawName.isEmpty) {
      return <String>['benchmark case #$i is missing a non-empty "name"'];
    }
    caseNames.add(rawName);
  }
  return validateProducedLoadProfileCaseNames(
    policy: policy,
    caseNames: caseNames,
  );
}

List<String> validateCollectedBenchmarkCaseContracts({
  required LoadProfilePolicy policy,
  required List<Map<String, Object?>> parsedCases,
}) {
  final issues = <String>[];

  for (final parsedCase in parsedCases) {
    final caseName = parsedCase['name'];
    if (caseName is! String || caseName.isEmpty) {
      continue;
    }

    final requiredOperations = policy.requiredOperationsForCase(caseName);
    if (requiredOperations.isNotEmpty) {
      final rawMetrics = parsedCase['metrics'];
      if (rawMetrics is! Map<String, Object?>) {
        issues.add('benchmark case "$caseName" is missing a "metrics" object');
      } else {
        final metricsByOperation = <String, Map<String, num>>{};
        _collectMetricLeaves(
          root: rawMetrics,
          metricKeys: policy.requiredMetricKeys,
          caseName: caseName,
          pathPrefix: '',
          sink: metricsByOperation,
          issues: issues,
        );
        for (final operationName in requiredOperations) {
          final operationMetrics = metricsByOperation[operationName];
          if (operationMetrics == null) {
            issues.add(
              'benchmark case "$caseName" is missing metrics for '
              '"$operationName"',
            );
          }
        }
      }
    }

    final requiredProbeKeys = policy.requiredProbeKeysForCase(caseName);
    if (requiredProbeKeys.isEmpty) {
      continue;
    }

    final rawProbes = parsedCase['probes'];
    if (rawProbes is! Map<String, Object?>) {
      issues.add('benchmark case "$caseName" is missing a "probes" object');
      continue;
    }

    requiredProbeKeys.forEach((operationName, probeKeys) {
      final rawOperation = rawProbes[operationName];
      if (rawOperation is! Map<String, Object?>) {
        issues.add(
          'benchmark case "$caseName" is missing probes for "$operationName"',
        );
        return;
      }

      for (final probeKey in probeKeys) {
        final probeValue = rawOperation[probeKey];
        if (probeValue is! num || !probeValue.isFinite) {
          issues.add(
            'benchmark case "$caseName" probe '
            '"$operationName.$probeKey" must be a finite number',
          );
        }
      }
    });
  }

  return issues;
}

void _collectMetricLeaves({
  required Map<String, Object?> root,
  required List<String> metricKeys,
  required String caseName,
  required String pathPrefix,
  required Map<String, Map<String, num>> sink,
  required List<String> issues,
}) {
  final hasAnyRequiredKey = metricKeys.any(root.containsKey);
  if (hasAnyRequiredKey) {
    final operationName = _normalizeMetricOperationPath(pathPrefix);
    final metricValues = <String, num>{};
    for (final metricKey in metricKeys) {
      final rawValue = root[metricKey];
      if (rawValue is! num || !rawValue.isFinite) {
        final metricPath = operationName == 'root'
            ? metricKey
            : '$operationName.$metricKey';
        issues.add(
          'benchmark case "$caseName" metric '
          '"$metricPath" must be a finite number',
        );
      } else {
        metricValues[metricKey] = rawValue;
      }
    }
    final existing = sink[operationName];
    if (existing != null) {
      issues.add(
        'benchmark case "$caseName" has duplicate metrics for '
        '"$operationName" after path normalization',
      );
      return;
    }
    sink[operationName] = metricValues;
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
      metricKeys: metricKeys,
      caseName: caseName,
      pathPrefix: childPath,
      sink: sink,
      issues: issues,
    );
  }
}

String _normalizeMetricOperationPath(String path) {
  if (path.isEmpty) {
    return 'root';
  }
  var normalized = path;
  while (normalized.startsWith('metrics.')) {
    normalized = normalized.substring('metrics.'.length);
  }
  return normalized;
}

_Options _parseArgs(List<String> args) {
  var profile = 'smoke';
  String? outputPath;

  for (final arg in args) {
    if (arg.startsWith('--profile=')) {
      profile = arg.substring('--profile='.length).trim().toLowerCase();
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

  loadProfilePolicyFor(profile);

  return _Options(profile: profile, outputPath: outputPath);
}

Never _printUsageAndExit(int code) {
  stdout.writeln(
    'Usage: dart run tool/bench/run_load_profiles.dart '
    '--profile=<smoke|full> [--output=<path>]',
  );
  stdout.writeln(
    '  smoke: product-realistic diagnostics (<=1000 nodes, includes 3840x2160 viewport)',
  );
  stdout.writeln(
    '  full: stress/nightly diagnostics (10k+ scenes and worst-case coverage)',
  );
  exit(code);
}

class _Options {
  const _Options({required this.profile, required this.outputPath});

  final String profile;
  final String? outputPath;
}
