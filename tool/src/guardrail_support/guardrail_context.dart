import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';

import 'guardrail_path_utils.dart';

class GuardrailContext {
  GuardrailContext._({
    required this.root,
    required this.rootAbsPosixPath,
    required this.packageName,
    required AnalysisContextCollection analysisCollection,
  }) : _analysisCollection = analysisCollection;

  factory GuardrailContext.forCurrentDirectory() {
    final root = Directory.current;
    return GuardrailContext._(
      root: root,
      rootAbsPosixPath: toPosixPath(root.absolute.path),
      packageName: readPackageNameOrFallback(root),
      analysisCollection: AnalysisContextCollection(
        includedPaths: <String>[root.absolute.path],
      ),
    );
  }

  final Directory root;
  final String rootAbsPosixPath;
  final String packageName;
  final AnalysisContextCollection _analysisCollection;
  final Map<String, ParsedUnitResult> _parsedUnitCache =
      <String, ParsedUnitResult>{};

  Object getParsedUnitResult(String absPath) {
    final cached = _parsedUnitCache[absPath];
    if (cached != null) {
      return cached;
    }
    final context = _analysisCollection.contextFor(absPath);
    final result = context.currentSession.getParsedUnit(absPath);
    if (result is ParsedUnitResult) {
      _parsedUnitCache[absPath] = result;
    }
    return result;
  }
}
