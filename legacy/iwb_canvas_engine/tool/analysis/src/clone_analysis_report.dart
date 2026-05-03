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
  final hasResults = config.reportMode == CloneAnalysisReportMode.pairs
      ? report.results.isNotEmpty
      : report.clusters.isNotEmpty;

  _writeReportHeader(buffer, report, config);

  if (!hasResults) {
    buffer.writeln('No similar fragments found.');
    buffer.writeln('');
  } else if (config.reportMode == CloneAnalysisReportMode.pairs) {
    for (var i = 0; i < report.results.length; i++) {
      _writeResultBlock(buffer, report.results[i], i + 1);
    }
  } else {
    for (var i = 0; i < report.clusters.length; i++) {
      _writeClusterBlock(buffer, report.clusters[i], i + 1);
    }
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
  };
  if (config.reportMode == CloneAnalysisReportMode.pairs) {
    payload['results'] = report.results
        .map((result) => result.toJson())
        .toList();
  } else {
    payload['clusters'] = report.clusters
        .map((cluster) => cluster.toJson())
        .toList();
  }
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
  if (config.reportMode == CloneAnalysisReportMode.pairs) {
    buffer.writeln('Found similar pairs: ${report.results.length}');
  } else {
    buffer.writeln('Found clone clusters: ${report.clusters.length}');
  }
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
  buffer.writeln('  topResults=${_formatTopResults(config)}');
  buffer.writeln('  reportMode=${config.reportMode.name}');
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

void _writeClusterBlock(StringBuffer buffer, CloneCluster cluster, int index) {
  final matchKinds = cluster.matchKinds.map((kind) => kind.name).toList()
    ..sort();
  final bestPair = cluster.bestPair;

  buffer.writeln(
    'Cluster $index  [${cluster.members.length} members, ${cluster.pairCount} pairs, '
    '${matchKinds.join(', ')}]',
  );
  buffer.writeln(
    '  members=${cluster.members.length}  '
    'pairs=${cluster.pairCount}  '
    'overlap=${_formatPercent(cluster.minOverlap)}'
    '..${_formatPercent(cluster.maxOverlap)}  '
    'avgOverlap=${_formatPercent(cluster.avgOverlap)}',
  );
  buffer.writeln(
    '  sharedFingerprints=${cluster.minSharedFingerprints}'
    '..${cluster.maxSharedFingerprints}',
  );
  buffer.writeln(
    '  bestPair=${bestPair.a.name} <-> ${bestPair.b.name}  '
    'overlap=${_formatPercent(bestPair.overlap)}  '
    'sharedFingerprints=${bestPair.sharedFingerprints}',
  );

  for (final member in cluster.members) {
    buffer.writeln(
      '  - ${member.block.filePath}:${member.block.startLine}-${member.block.endLine}  '
      '${member.block.kind} ${member.block.name}  '
      'strongestOverlap=${_formatPercent(member.strongestOverlap)}  '
      'sharedFingerprints=${member.strongestSharedFingerprints}',
    );
  }
  buffer.writeln('');
}

String _formatTopResults(CloneAnalysisConfig config) {
  final topResults = config.topResults;
  if (topResults == null) {
    return config.reportMode == CloneAnalysisReportMode.pairs
        ? 'all pairs'
        : 'all clusters';
  }

  return config.reportMode == CloneAnalysisReportMode.pairs
      ? 'top $topResults pairs'
      : 'top $topResults clusters';
}

void _writeParseErrors(StringBuffer buffer, List<String> parseErrors) {
  buffer.writeln('Parse errors:');
  for (final parseError in parseErrors) {
    buffer.writeln('  $parseError');
  }
}
