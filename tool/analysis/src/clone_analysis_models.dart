import 'clone_analysis_config.dart';

class CodeBlock {
  CodeBlock({
    required this.id,
    required this.filePath,
    required this.kind,
    required this.name,
    required this.startLine,
    required this.endLine,
    required this.tokens,
    required this.tokenLines,
  });

  final int id;
  final String filePath;
  final String kind;
  final String name;
  final int startLine;
  final int endLine;
  final List<String> tokens;
  final List<int> tokenLines;

  late final List<int> tokenIds;
  late final List<Fingerprint> fingerprints;

  int get fingerprintCount => fingerprints.length;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'filePath': filePath,
      'kind': kind,
      'name': name,
      'startLine': startLine,
      'endLine': endLine,
      'tokenCount': tokens.length,
      'fingerprintCount': fingerprintCount,
    };
  }
}

class Fingerprint {
  Fingerprint({required this.hash, required this.tokenPosition});

  final int hash;
  final int tokenPosition;
}

class FingerprintOccurrence {
  FingerprintOccurrence({required this.blockId, required this.tokenPosition});

  final int blockId;
  final int tokenPosition;
}

class PairStat {
  PairStat({required this.aId, required this.bId});

  final int aId;
  final int bId;

  int sharedFingerprints = 0;
  int samplePosA = 0;
  int samplePosB = 0;
  bool hasSample = false;
}

enum CloneMatchKind { exact, structural }

class SimilarityResult {
  SimilarityResult({
    required this.a,
    required this.b,
    required this.sharedFingerprints,
    required this.overlap,
    required this.jaccard,
    required this.sampleAStartLine,
    required this.sampleAEndLine,
    required this.sampleBStartLine,
    required this.sampleBEndLine,
  });

  final CodeBlock a;
  final CodeBlock b;
  final int sharedFingerprints;
  final double overlap;
  final double jaccard;
  final int sampleAStartLine;
  final int sampleAEndLine;
  final int sampleBStartLine;
  final int sampleBEndLine;

  CloneMatchKind get matchKind {
    final exactOverlap = overlap == 1;
    final exactJaccard = jaccard == 1;
    if (exactOverlap && exactJaccard) {
      return CloneMatchKind.exact;
    }
    return CloneMatchKind.structural;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'matchKind': matchKind.name,
      'sharedFingerprints': sharedFingerprints,
      'overlap': overlap,
      'jaccard': jaccard,
      'sampleAStartLine': sampleAStartLine,
      'sampleAEndLine': sampleAEndLine,
      'sampleBStartLine': sampleBStartLine,
      'sampleBEndLine': sampleBEndLine,
      'a': a.toJson(),
      'b': b.toJson(),
    };
  }
}

class CloneClusterMember {
  CloneClusterMember({
    required this.block,
    required this.strongestOverlap,
    required this.strongestSharedFingerprints,
  });

  final CodeBlock block;
  final double strongestOverlap;
  final int strongestSharedFingerprints;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'strongestOverlap': strongestOverlap,
      'strongestSharedFingerprints': strongestSharedFingerprints,
      'block': block.toJson(),
    };
  }
}

class CloneCluster {
  CloneCluster({
    required this.members,
    required this.pairCount,
    required this.bestPair,
    required this.minOverlap,
    required this.maxOverlap,
    required this.avgOverlap,
    required this.minSharedFingerprints,
    required this.maxSharedFingerprints,
    required this.matchKinds,
  });

  final List<CloneClusterMember> members;
  final int pairCount;
  final SimilarityResult bestPair;
  final double minOverlap;
  final double maxOverlap;
  final double avgOverlap;
  final int minSharedFingerprints;
  final int maxSharedFingerprints;
  final Set<CloneMatchKind> matchKinds;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'memberCount': members.length,
      'pairCount': pairCount,
      'bestPair': bestPair.toJson(),
      'minOverlap': minOverlap,
      'maxOverlap': maxOverlap,
      'avgOverlap': avgOverlap,
      'minSharedFingerprints': minSharedFingerprints,
      'maxSharedFingerprints': maxSharedFingerprints,
      'matchKinds': matchKinds.map((kind) => kind.name).toList()..sort(),
      'members': members.map((member) => member.toJson()).toList(),
    };
  }
}

class Vocabulary {
  final Map<String, int> _ids = <String, int>{};
  int _nextId = 1;

  int intern(String token) {
    return _ids.putIfAbsent(token, () => _nextId++);
  }
}

class CloneAnalysisReport {
  CloneAnalysisReport({
    required this.config,
    required this.scannedFiles,
    required this.scannedBlocks,
    required this.parseErrors,
    required this.results,
    required this.clusters,
  });

  final CloneAnalysisConfig config;
  final int scannedFiles;
  final int scannedBlocks;
  final List<String> parseErrors;
  final List<SimilarityResult> results;
  final List<CloneCluster> clusters;
}
