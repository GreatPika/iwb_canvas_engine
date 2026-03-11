import 'dart:math' as math;

import 'clone_analysis_collector.dart';
import 'clone_analysis_config.dart';
import 'clone_analysis_models.dart';

CloneAnalysisReport runCloneAnalysis(CloneAnalysisConfig config) {
  final collection = collectCloneBlocks(
    rootPath: config.rootPath,
    minTokens: config.minTokens,
    excludeMain: config.excludeMain,
  );
  final blocks = collection.blocks;
  if (blocks.isEmpty) {
    return CloneAnalysisReport(
      config: config,
      scannedFiles: collection.scannedFiles,
      scannedBlocks: 0,
      parseErrors: collection.parseErrors,
      results: const <SimilarityResult>[],
    );
  }

  _computeFingerprints(blocks, config);
  final results = _collectSimilarityResults(blocks, config);
  final limitedResults = _limitResults(results, config.topResults);

  return CloneAnalysisReport(
    config: config,
    scannedFiles: collection.scannedFiles,
    scannedBlocks: blocks.length,
    parseErrors: collection.parseErrors,
    results: limitedResults,
  );
}

void _computeFingerprints(List<CodeBlock> blocks, CloneAnalysisConfig config) {
  final vocabulary = Vocabulary();
  for (final block in blocks) {
    block.tokenIds = block.tokens.map(vocabulary.intern).toList();
    final hashes = buildKGramHashes(
      tokenIds: block.tokenIds,
      kGramSize: config.kGramSize,
    );
    block.fingerprints = selectFingerprints(
      hashes: hashes,
      windowSize: config.windowSize,
    );
  }
}

List<SimilarityResult> _collectSimilarityResults(
  List<CodeBlock> blocks,
  CloneAnalysisConfig config,
) {
  final byId = <int, CodeBlock>{for (final block in blocks) block.id: block};
  final fingerprintIndex = <int, List<FingerprintOccurrence>>{};
  _indexFingerprints(blocks, fingerprintIndex);

  final pairStats = <String, PairStat>{};
  for (final entry in fingerprintIndex.entries) {
    final occurrences = entry.value;
    if (occurrences.length > config.maxBucketSize) {
      continue;
    }
    _accumulatePairStats(occurrences, byId, pairStats);
  }

  final results = <SimilarityResult>[];
  for (final stat in pairStats.values) {
    final result = _buildSimilarityResult(stat, byId, config);
    if (result != null) {
      results.add(result);
    }
  }

  results.sort(_compareSimilarityResults);
  return results;
}

void _indexFingerprints(
  List<CodeBlock> blocks,
  Map<int, List<FingerprintOccurrence>> fingerprintIndex,
) {
  for (final block in blocks) {
    final seenHashesInBlock = <int>{};
    for (final fingerprint in block.fingerprints) {
      if (!seenHashesInBlock.add(fingerprint.hash)) {
        continue;
      }
      fingerprintIndex
          .putIfAbsent(fingerprint.hash, () => <FingerprintOccurrence>[])
          .add(
            FingerprintOccurrence(
              blockId: block.id,
              tokenPosition: fingerprint.tokenPosition,
            ),
          );
    }
  }
}

void _accumulatePairStats(
  List<FingerprintOccurrence> occurrences,
  Map<int, CodeBlock> byId,
  Map<String, PairStat> pairStats,
) {
  for (var i = 0; i < occurrences.length; i++) {
    for (var j = i + 1; j < occurrences.length; j++) {
      final left = occurrences[i];
      final right = occurrences[j];
      if (left.blockId == right.blockId) {
        continue;
      }

      final aId = math.min(left.blockId, right.blockId);
      final bId = math.max(left.blockId, right.blockId);
      final aBlock = byId[aId]!;
      final bBlock = byId[bId]!;
      if (_isNestedPairInSameFile(aBlock, bBlock)) {
        continue;
      }

      final key = '$aId:$bId';
      final stat = pairStats.putIfAbsent(
        key,
        () => PairStat(aId: aId, bId: bId),
      );
      _captureSampleIfNeeded(stat, left, right, aId);
      stat.sharedFingerprints += 1;
    }
  }
}

void _captureSampleIfNeeded(
  PairStat stat,
  FingerprintOccurrence left,
  FingerprintOccurrence right,
  int aId,
) {
  if (stat.hasSample) {
    return;
  }

  if (left.blockId == aId) {
    stat.samplePosA = left.tokenPosition;
    stat.samplePosB = right.tokenPosition;
  } else {
    stat.samplePosA = right.tokenPosition;
    stat.samplePosB = left.tokenPosition;
  }
  stat.hasSample = true;
}

SimilarityResult? _buildSimilarityResult(
  PairStat stat,
  Map<int, CodeBlock> byId,
  CloneAnalysisConfig config,
) {
  final a = byId[stat.aId]!;
  final b = byId[stat.bId]!;
  if (a.fingerprints.isEmpty || b.fingerprints.isEmpty) {
    return null;
  }

  final shared = stat.sharedFingerprints;
  final minFingerprintCount = math.min(a.fingerprintCount, b.fingerprintCount);
  final unionFingerprints = a.fingerprintCount + b.fingerprintCount - shared;
  if (minFingerprintCount == 0 || unionFingerprints <= 0) {
    return null;
  }

  final overlap = shared / minFingerprintCount;
  if (shared < config.minSharedFingerprints || overlap < config.minOverlap) {
    return null;
  }

  final jaccard = shared / unionFingerprints;
  return SimilarityResult(
    a: a,
    b: b,
    sharedFingerprints: shared,
    overlap: overlap,
    jaccard: jaccard,
    sampleAStartLine: _tokenPosToLine(a, stat.samplePosA),
    sampleAEndLine: _sampleEndLine(a, stat.samplePosA, config.kGramSize),
    sampleBStartLine: _tokenPosToLine(b, stat.samplePosB),
    sampleBEndLine: _sampleEndLine(b, stat.samplePosB, config.kGramSize),
  );
}

int _sampleEndLine(CodeBlock block, int sampleTokenPos, int kGramSize) {
  final lastTokenIndex = block.tokenLines.length - 1;
  final endTokenPos = math.min(sampleTokenPos + kGramSize - 1, lastTokenIndex);
  return _tokenPosToLine(block, endTokenPos);
}

int _tokenPosToLine(CodeBlock block, int tokenPos) {
  if (block.tokenLines.isEmpty) {
    return block.startLine;
  }
  final safePos = tokenPos.clamp(0, block.tokenLines.length - 1);
  return block.tokenLines[safePos];
}

bool _isNestedPairInSameFile(CodeBlock a, CodeBlock b) {
  if (a.filePath != b.filePath) {
    return false;
  }
  return _containsLineRange(a, b) || _containsLineRange(b, a);
}

bool _containsLineRange(CodeBlock outer, CodeBlock inner) {
  return outer.startLine <= inner.startLine && outer.endLine >= inner.endLine;
}

int _compareSimilarityResults(SimilarityResult left, SimilarityResult right) {
  final overlapCompare = right.overlap.compareTo(left.overlap);
  if (overlapCompare != 0) {
    return overlapCompare;
  }

  final sharedCompare = right.sharedFingerprints.compareTo(
    left.sharedFingerprints,
  );
  if (sharedCompare != 0) {
    return sharedCompare;
  }

  final rightTotalTokens = right.a.tokens.length + right.b.tokens.length;
  final leftTotalTokens = left.a.tokens.length + left.b.tokens.length;
  return rightTotalTokens.compareTo(leftTotalTokens);
}

List<Fingerprint> buildKGramHashes({
  required List<int> tokenIds,
  required int kGramSize,
}) {
  if (tokenIds.length < kGramSize) {
    return <Fingerprint>[];
  }

  const offsetBasis = 1469598103934665603;
  const prime = 1099511628211;
  final result = <Fingerprint>[];

  for (var start = 0; start <= tokenIds.length - kGramSize; start++) {
    var hash = offsetBasis;
    for (var i = 0; i < kGramSize; i++) {
      hash = (hash ^ tokenIds[start + i]).toUnsigned(64);
      hash = (hash * prime).toUnsigned(64);
    }
    result.add(Fingerprint(hash: hash, tokenPosition: start));
  }

  return result;
}

List<Fingerprint> selectFingerprints({
  required List<Fingerprint> hashes,
  required int windowSize,
}) {
  if (hashes.isEmpty) {
    return <Fingerprint>[];
  }

  final actualWindow = math.max(1, windowSize);
  if (hashes.length <= actualWindow) {
    return <Fingerprint>[_pickRightmostMinimum(hashes, 0, hashes.length - 1)];
  }

  final result = <Fingerprint>[];
  int? lastSelectedPosition;
  for (var start = 0; start <= hashes.length - actualWindow; start++) {
    final end = start + actualWindow - 1;
    final picked = _pickRightmostMinimum(hashes, start, end);
    if (lastSelectedPosition == picked.tokenPosition) {
      continue;
    }
    result.add(picked);
    lastSelectedPosition = picked.tokenPosition;
  }
  return result;
}

Fingerprint _pickRightmostMinimum(
  List<Fingerprint> hashes,
  int start,
  int end,
) {
  var best = hashes[start];
  for (var i = start + 1; i <= end; i++) {
    final current = hashes[i];
    if (current.hash < best.hash) {
      best = current;
      continue;
    }
    if (current.hash == best.hash &&
        current.tokenPosition > best.tokenPosition) {
      best = current;
    }
  }
  return best;
}

List<SimilarityResult> _limitResults(
  List<SimilarityResult> results,
  int? topResults,
) {
  if (topResults == null || results.length <= topResults) {
    return results;
  }
  return results.take(topResults).toList(growable: false);
}
