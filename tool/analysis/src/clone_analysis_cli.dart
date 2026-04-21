import 'dart:io';

import 'clone_analysis_config.dart';
import 'clone_analysis_engine.dart';
import 'clone_analysis_report.dart';

const String _usage = '''
Usage:
  dart run tool/analysis/find_similar_clones.dart [options] [rootPath] [minTokens] [kGramSize] [windowSize] [minSharedFingerprints] [minOverlap] [maxBucketSize]

Options:
  -h, --help          Show this help message
  --json              Emit JSON instead of text
  --clusters          Emit connected clone clusters instead of pairs
  --exclude-main      Skip top-level function blocks named main
  --top N             Limit the report to the top N pairs or clusters
  --top=N             Limit the report to the top N pairs or clusters

Examples:
  dart run tool/analysis/find_similar_clones.dart
  dart run tool/analysis/find_similar_clones.dart . 60 30 5 4 0.55 12
  dart run tool/analysis/find_similar_clones.dart lib 50 30 5 4 0.55 12
  dart run tool/analysis/find_similar_clones.dart --exclude-main test 60 30 5 4 0.70 10
  dart run tool/analysis/find_similar_clones.dart --json --top 20 . 60 30 5 4 0.55 12
  dart run tool/analysis/find_similar_clones.dart --clusters --top 10 .
''';

Future<int> runCloneAnalysisCli(
  List<String> args, {
  required Stdout stdout,
  required IOSink stderr,
}) async {
  final parseResult = parseCloneAnalysisArgs(args);
  if (parseResult.showHelp) {
    stdout.writeln(_usage.trim());
    return 0;
  }

  final errorMessage = parseResult.errorMessage;
  if (errorMessage != null) {
    return _writeUsageError(stderr, errorMessage);
  }

  final config = parseResult.config;
  if (config == null) {
    return _writeUsageError(stderr, 'Missing clone analysis configuration.');
  }

  final validationError = config.validate();
  if (validationError != null) {
    return _writeUsageError(stderr, validationError);
  }

  final report = runCloneAnalysis(config);
  if (report.scannedFiles == 0) {
    stderr.writeln('No Dart files found.');
    return 1;
  }

  stdout.writeln(renderCloneAnalysisReport(report));
  return 0;
}

CloneAnalysisParseResult parseCloneAnalysisArgs(List<String> args) {
  var config = CloneAnalysisConfig.defaults();
  final positionals = <String>[];

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    final optionResult = _handleOption(arg, args, i, config);
    switch (optionResult) {
      case _OptionHelp():
        return CloneAnalysisParseResult.help();
      case _OptionError(:final message):
        return CloneAnalysisParseResult.error(message);
      case _OptionConfig(:final nextConfig, :final nextIndex):
        config = nextConfig;
        i = nextIndex;
      case _OptionNone():
        if (arg.startsWith('--')) {
          return CloneAnalysisParseResult.error('Unknown option: $arg');
        }
        positionals.add(arg);
    }
  }

  return _applyPositionalArgs(config, positionals);
}

CloneAnalysisParseResult _applyPositionalArgs(
  CloneAnalysisConfig config,
  List<String> positionals,
) {
  if (positionals.isEmpty) {
    return CloneAnalysisParseResult.success(config);
  }

  if (positionals.length > 7) {
    return CloneAnalysisParseResult.error(
      'Too many positional arguments. Expected at most 7 values.',
    );
  }

  final minTokens = _parsePositionalInt(positionals, 1, 'minTokens');
  if (minTokens case _ParsedPositionalError(:final message)) {
    return CloneAnalysisParseResult.error(message);
  }

  final kGramSize = _parsePositionalInt(positionals, 2, 'kGramSize');
  if (kGramSize case _ParsedPositionalError(:final message)) {
    return CloneAnalysisParseResult.error(message);
  }

  final windowSize = _parsePositionalInt(positionals, 3, 'windowSize');
  if (windowSize case _ParsedPositionalError(:final message)) {
    return CloneAnalysisParseResult.error(message);
  }

  final minSharedFingerprints = _parsePositionalInt(
    positionals,
    4,
    'minSharedFingerprints',
  );
  if (minSharedFingerprints case _ParsedPositionalError(:final message)) {
    return CloneAnalysisParseResult.error(message);
  }

  final minOverlap = _parsePositionalDouble(positionals, 5, 'minOverlap');
  if (minOverlap case _ParsedPositionalError(:final message)) {
    return CloneAnalysisParseResult.error(message);
  }

  final maxBucketSize = _parsePositionalInt(positionals, 6, 'maxBucketSize');
  if (maxBucketSize case _ParsedPositionalError(:final message)) {
    return CloneAnalysisParseResult.error(message);
  }

  return CloneAnalysisParseResult.success(
    config.copyWith(
      rootPath: positionals[0],
      minTokens: minTokens.value,
      kGramSize: kGramSize.value,
      windowSize: windowSize.value,
      minSharedFingerprints: minSharedFingerprints.value,
      minOverlap: minOverlap.value,
      maxBucketSize: maxBucketSize.value,
    ),
  );
}

int _writeUsageError(IOSink stderr, String message) {
  stderr.writeln(message);
  stderr.writeln('');
  stderr.writeln(_usage.trim());
  return 64;
}

sealed class _OptionResult {}

final class _OptionNone extends _OptionResult {}

final class _OptionHelp extends _OptionResult {}

final class _OptionError extends _OptionResult {
  _OptionError(this.message);

  final String message;
}

final class _OptionConfig extends _OptionResult {
  _OptionConfig({required this.nextConfig, required this.nextIndex});

  final CloneAnalysisConfig nextConfig;
  final int nextIndex;
}

_OptionResult _handleOption(
  String arg,
  List<String> args,
  int index,
  CloneAnalysisConfig config,
) {
  final simpleFlagResult = _handleSimpleFlag(arg, config, index);
  if (simpleFlagResult is! _OptionNone) {
    return simpleFlagResult;
  }

  if (arg.startsWith('--top=')) {
    return _handleTopValue(arg.substring('--top='.length), config, index);
  }
  if (arg == '--top') {
    return _handleSeparateTopOption(args, index, config);
  }

  return _OptionNone();
}

_OptionResult _handleSimpleFlag(
  String arg,
  CloneAnalysisConfig config,
  int index,
) {
  switch (arg) {
    case '-h':
    case '--help':
      return _OptionHelp();
    case '--json':
      return _OptionConfig(
        nextConfig: config.copyWith(
          outputFormat: CloneAnalysisOutputFormat.json,
        ),
        nextIndex: index,
      );
    case '--clusters':
      return _OptionConfig(
        nextConfig: config.copyWith(
          reportMode: CloneAnalysisReportMode.clusters,
        ),
        nextIndex: index,
      );
    case '--exclude-main':
      return _OptionConfig(
        nextConfig: config.copyWith(excludeMain: true),
        nextIndex: index,
      );
    default:
      return _OptionNone();
  }
}

_OptionResult _handleSeparateTopOption(
  List<String> args,
  int index,
  CloneAnalysisConfig config,
) {
  final valueIndex = index + 1;
  if (valueIndex >= args.length) {
    return _OptionError('Missing integer value after --top.');
  }

  return _handleTopValue(args[valueIndex], config, valueIndex);
}

_OptionResult _handleTopValue(
  String rawValue,
  CloneAnalysisConfig config,
  int nextIndex,
) {
  final top = int.tryParse(rawValue);
  if (top == null) {
    return _OptionError('Invalid value for --top: $rawValue');
  }

  return _OptionConfig(
    nextConfig: config.copyWith(topResults: top),
    nextIndex: nextIndex,
  );
}

sealed class _ParsedPositionalValue<T extends num> {
  const _ParsedPositionalValue();

  T? get value;
}

final class _ParsedPositionalSuccess<T extends num>
    extends _ParsedPositionalValue<T> {
  const _ParsedPositionalSuccess(this.value);

  @override
  final T? value;
}

final class _ParsedPositionalError<T extends num>
    extends _ParsedPositionalValue<T> {
  const _ParsedPositionalError(this.message);

  final String message;

  @override
  T? get value => null;
}

_ParsedPositionalValue<int> _parsePositionalInt(
  List<String> values,
  int index,
  String name,
) {
  if (index >= values.length) {
    return const _ParsedPositionalSuccess<int>(null);
  }

  final value = int.tryParse(values[index]);
  if (value == null) {
    return _ParsedPositionalError<int>(
      'Invalid integer value for $name: ${values[index]}',
    );
  }
  return _ParsedPositionalSuccess<int>(value);
}

_ParsedPositionalValue<double> _parsePositionalDouble(
  List<String> values,
  int index,
  String name,
) {
  if (index >= values.length) {
    return const _ParsedPositionalSuccess<double>(null);
  }

  final value = double.tryParse(values[index]);
  if (value == null) {
    return _ParsedPositionalError<double>(
      'Invalid double value for $name: ${values[index]}',
    );
  }
  return _ParsedPositionalSuccess<double>(value);
}
