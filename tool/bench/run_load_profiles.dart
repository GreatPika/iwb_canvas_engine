import 'dart:convert';
import 'dart:io';

const _resultPrefix = 'IWB_BENCH_RESULT ';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final profile = options.profile;
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

  final report = <String, Object?>{
    'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'profile': profile,
    'caseCount': parsedCases.length,
    'cases': parsedCases,
  };

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  final encoder = const JsonEncoder.withIndent('  ');
  outputFile.writeAsStringSync('${encoder.convert(report)}\n');
  stdout.writeln('Benchmark report written: ${outputFile.path}');
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

  if (profile != 'smoke' && profile != 'full') {
    stderr.writeln('Invalid --profile value: $profile');
    _printUsageAndExit(2);
  }

  return _Options(profile: profile, outputPath: outputPath);
}

Never _printUsageAndExit(int code) {
  stdout.writeln(
    'Usage: dart run tool/bench/run_load_profiles.dart '
    '--profile=<smoke|full> [--output=<path>]',
  );
  exit(code);
}

class _Options {
  const _Options({required this.profile, required this.outputPath});

  final String profile;
  final String? outputPath;
}
