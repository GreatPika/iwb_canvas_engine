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
    return GuardrailContext.forDirectory(Directory.current);
  }

  factory GuardrailContext.forDirectory(Directory root) {
    final absoluteRoot = Directory(root.absolute.path);
    return GuardrailContext._(
      root: absoluteRoot,
      rootAbsPosixPath: toPosixPath(absoluteRoot.path),
      packageName: readPackageNameOrFallback(absoluteRoot),
      analysisCollection: AnalysisContextCollection(
        includedPaths: <String>[absoluteRoot.path],
      ),
    );
  }

  final Directory root;
  final String rootAbsPosixPath;
  final String packageName;
  final AnalysisContextCollection _analysisCollection;
  final Map<String, ParsedUnitResult> _parsedUnitCache =
      <String, ParsedUnitResult>{};
  final Map<String, Future<ResolvedUnitResult?>> _resolvedUnitCache =
      <String, Future<ResolvedUnitResult?>>{};
  final Map<String, Future<ResolvedLibraryResult?>> _resolvedLibraryCache =
      <String, Future<ResolvedLibraryResult?>>{};

  String get publicEntrypointAbsPath =>
      '${root.absolute.path}${Platform.pathSeparator}lib'
      '${Platform.pathSeparator}iwb_canvas_engine.dart';

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

  Future<ResolvedUnitResult?> getResolvedUnitResult(String absPath) {
    final cached = _resolvedUnitCache[absPath];
    if (cached != null) {
      return cached;
    }
    final future = _resolveUnit(absPath);
    _resolvedUnitCache[absPath] = future;
    return future;
  }

  Future<ResolvedUnitResult?> _resolveUnit(String absPath) async {
    final context = _analysisCollection.contextFor(absPath);
    final result = await context.currentSession.getResolvedUnit(absPath);
    return result is ResolvedUnitResult ? result : null;
  }

  Future<ResolvedLibraryResult?> getResolvedLibraryResult(String absPath) {
    final cached = _resolvedLibraryCache[absPath];
    if (cached != null) {
      return cached;
    }
    final future = _resolveLibrary(absPath);
    _resolvedLibraryCache[absPath] = future;
    return future;
  }

  Future<ResolvedLibraryResult?> _resolveLibrary(String absPath) async {
    final context = _analysisCollection.contextFor(absPath);
    final result = await context.currentSession.getResolvedLibrary(absPath);
    return result is ResolvedLibraryResult ? result : null;
  }
}
