class BranchCoverage {
  const BranchCoverage({
    required this.line,
    required this.block,
    required this.branch,
    required this.takenRaw,
  });

  final int line;
  final String block;
  final String branch;
  final String takenRaw;

  bool get isCovered {
    final taken = int.tryParse(takenRaw);
    return taken != null && taken > 0;
  }
}

class FileCoverage {
  FileCoverage(this.path);

  final String path;
  int? lf;
  int? lh;
  final Set<int> instrumentedLines = <int>{};
  final Set<int> hitLines = <int>{};
  final Set<int> missedLines = <int>{};
  final List<BranchCoverage> branches = <BranchCoverage>[];

  int get effectiveLf => lf ?? instrumentedLines.length;
  int get effectiveLh => lh ?? hitLines.length;
}

class CoverageOptions {
  const CoverageOptions({
    required this.json,
    required this.includeUncoveredBranches,
    required this.changedOnly,
  });

  final bool json;
  final bool includeUncoveredBranches;
  final bool changedOnly;
}

class MissedLineDiagnostic {
  const MissedLineDiagnostic({required this.line, required this.source});

  final int line;
  final String? source;

  Map<String, Object?> toJson() => <String, Object?>{
    'line': line,
    'source': source,
  };
}

class MissedBranchDiagnostic {
  const MissedBranchDiagnostic({
    required this.line,
    required this.block,
    required this.branch,
    required this.taken,
    required this.source,
  });

  final int line;
  final String block;
  final String branch;
  final String taken;
  final String? source;

  Map<String, Object?> toJson() => <String, Object?>{
    'line': line,
    'block': block,
    'branch': branch,
    'taken': taken,
    'source': source,
  };
}

class CoverageRange {
  const CoverageRange({
    required this.startLine,
    required this.startColumn,
    required this.endLine,
    required this.endColumn,
  });

  final int startLine;
  final int startColumn;
  final int endLine;
  final int endColumn;

  Map<String, Object> toJson() => <String, Object>{
    'sl': startLine,
    'sc': startColumn,
    'el': endLine,
    'ec': endColumn,
  };
}

class DeclarationCoverageGap {
  const DeclarationCoverageGap({
    required this.kind,
    required this.path,
    required this.symbol,
    required this.scope,
    required this.range,
    required this.missedLines,
    required this.missedBranches,
    required this.snippet,
    required this.testTargets,
    required this.preferredVerificationScope,
  });

  final String kind;
  final String path;
  final String? symbol;
  final String scope;
  final CoverageRange range;
  final List<MissedLineDiagnostic> missedLines;
  final List<MissedBranchDiagnostic> missedBranches;
  final String snippet;
  final List<String> testTargets;
  final String? preferredVerificationScope;

  Map<String, Object?> toJson() => <String, Object?>{
    'k': kind,
    'p': path,
    'sym': symbol,
    'scope': scope,
    'rng': range.toJson(),
    'ml': missedLines.map((line) => line.toJson()).toList(),
    'mb': missedBranches.map((branch) => branch.toJson()).toList(),
    'sn': snippet,
    'tt': testTargets,
    'sh': preferredVerificationScope,
  };
}

class CoverageMachineReport {
  const CoverageMachineReport({
    required this.gaps,
    required this.warnings,
    required this.branchDataAvailable,
    required this.changedOnlyApplied,
  });

  final List<DeclarationCoverageGap> gaps;
  final List<String> warnings;
  final bool branchDataAvailable;
  final bool changedOnlyApplied;

  Map<String, Object?> toJson() => <String, Object?>{
    'gaps': gaps.map((gap) => gap.toJson()).toList(),
    'warnings': warnings,
    'branchDataAvailable': branchDataAvailable,
    'changedOnlyApplied': changedOnlyApplied,
  };
}

class TestTargetResolution {
  const TestTargetResolution({
    required this.testTargets,
    required this.preferredVerificationScope,
  });

  final List<String> testTargets;
  final String? preferredVerificationScope;
}
