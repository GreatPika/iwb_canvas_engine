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
    'policy': policy.reportMetadata,
    'caseCount': parsedCases.length,
    'cases': parsedCases,
  };

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  final encoder = const JsonEncoder.withIndent('  ');
  outputFile.writeAsStringSync('${encoder.convert(report)}\n');
  stdout.writeln('Benchmark report written: ${outputFile.path}');
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
