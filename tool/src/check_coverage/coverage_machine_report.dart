import 'coverage_models.dart';

CoverageMachineReport buildCoverageMachineReport({
  required List<DeclarationCoverageGap> gaps,
  required List<String> warnings,
  required bool branchDataAvailable,
  required bool changedOnlyApplied,
}) {
  final sortedWarnings = warnings.toList()..sort();
  final sortedGaps = gaps.toList()
    ..sort((left, right) {
      final pathCompare = left.path.compareTo(right.path);
      if (pathCompare != 0) {
        return pathCompare;
      }
      final lineCompare = left.range.startLine.compareTo(right.range.startLine);
      if (lineCompare != 0) {
        return lineCompare;
      }
      return left.kind.compareTo(right.kind);
    });

  return CoverageMachineReport(
    gaps: List<DeclarationCoverageGap>.unmodifiable(sortedGaps),
    warnings: List<String>.unmodifiable(sortedWarnings),
    branchDataAvailable: branchDataAvailable,
    changedOnlyApplied: changedOnlyApplied,
  );
}
