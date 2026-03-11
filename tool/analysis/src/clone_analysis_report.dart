import 'dart:convert';

import 'clone_analysis_config.dart';
import 'clone_analysis_models.dart';

String renderCloneAnalysisReport(CloneAnalysisReport report) {
  final config = report.config;
  if (config.outputFormat == CloneAnalysisOutputFormat.json) {
    return _renderJsonReport(report, config);
  }
  return _renderTextReport(report, config);
}

String _renderTextReport(
  CloneAnalysisReport report,
  CloneAnalysisConfig config,
) {
  final buffer = StringBuffer();
  if (report.results.isEmpty) {
    buffer.writeln('No similar fragments found.');
    return buffer.toString().trimRight();
  }

  _writeReportHeader(buffer, report, config);

  for (var i = 0; i < report.results.length; i++) {
    _writeResultBlock(buffer, report.results[i], i + 1);
  }

  if (report.parseErrors.isNotEmpty) {
    _writeParseErrors(buffer, report.parseErrors);
  }

  return buffer.toString().trimRight();
}

String _renderJsonReport(
  CloneAnalysisReport report,
  CloneAnalysisConfig config,
) {
  final payload = <String, Object?>{
    'config': config.toJson(),
    'scannedFiles': report.scannedFiles,
    'scannedBlocks': report.scannedBlocks,
    'parseErrors': report.parseErrors,
    'results': report.results.map((result) => result.toJson()).toList(),
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

String _formatPercent(double value) {
  return '${(value * 100).toStringAsFixed(1)}%';
}

void _writeReportHeader(
  StringBuffer buffer,
  CloneAnalysisReport report,
  CloneAnalysisConfig config,
) {
  buffer.writeln('Found similar pairs: ${report.results.length}');
  buffer.writeln('');
  buffer.writeln('Scan summary:');
  buffer.writeln('  scannedFiles=${report.scannedFiles}');
  buffer.writeln('  scannedBlocks=${report.scannedBlocks}');
  buffer.writeln('  parseErrors=${report.parseErrors.length}');
  buffer.writeln('');
  buffer.writeln('Parameters:');
  buffer.writeln('  rootPath=${config.rootPath}');
  buffer.writeln('  minTokens=${config.minTokens}');
  buffer.writeln('  kGramSize=${config.kGramSize}');
  buffer.writeln('  windowSize=${config.windowSize}');
  buffer.writeln('  minSharedFingerprints=${config.minSharedFingerprints}');
  buffer.writeln('  minOverlap=${config.minOverlap}');
  buffer.writeln('  maxBucketSize=${config.maxBucketSize}');
  buffer.writeln('  excludeMain=${config.excludeMain}');
  buffer.writeln('  topResults=${config.topResults ?? 'all'}');
  buffer.writeln('');
}

void _writeResultBlock(
  StringBuffer buffer,
  SimilarityResult result,
  int index,
) {
  buffer.writeln('Pair $index  [${result.matchKind.name}]');
  buffer.writeln(
    '  overlap=${_formatPercent(result.overlap)}  '
    'jaccard=${_formatPercent(result.jaccard)}  '
    'sharedFingerprints=${result.sharedFingerprints}',
  );
  buffer.writeln(
    '  A: ${result.a.filePath}:${result.a.startLine}-${result.a.endLine}  '
    '${result.a.kind} ${result.a.name}',
  );
  buffer.writeln(
    '     sample window: '
    'lines ${result.sampleAStartLine}-${result.sampleAEndLine}',
  );
  buffer.writeln(
    '  B: ${result.b.filePath}:${result.b.startLine}-${result.b.endLine}  '
    '${result.b.kind} ${result.b.name}',
  );
  buffer.writeln(
    '     sample window: '
    'lines ${result.sampleBStartLine}-${result.sampleBEndLine}',
  );
  buffer.writeln('');
}

void _writeParseErrors(StringBuffer buffer, List<String> parseErrors) {
  buffer.writeln('Parse errors:');
  for (final parseError in parseErrors) {
    buffer.writeln('  $parseError');
  }
}
