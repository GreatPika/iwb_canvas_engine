import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'coverage_models.dart';

class CoverageDeclarationLocator {
  final Map<String, _ParsedSource?> _cache = <String, _ParsedSource?>{};

  List<DeclarationCoverageGap> locateExecutableGaps({
    required String path,
    required List<int> missedLines,
    required List<BranchCoverage> missedBranches,
  }) {
    final parsed = _cache.putIfAbsent(path, () => _parse(path));
    if (parsed == null) {
      return <DeclarationCoverageGap>[
        DeclarationCoverageGap(
          kind: _gapKind(
            hasLines: missedLines.isNotEmpty,
            hasBranches: missedBranches.isNotEmpty,
          ),
          path: path,
          symbol: null,
          scope: 'fs',
          range: _fallbackRange(missedLines, missedBranches),
          missedLines: List<MissedLineDiagnostic>.unmodifiable(
            missedLines
                .map((line) => MissedLineDiagnostic(line: line, source: null))
                .toList(),
          ),
          missedBranches: List<MissedBranchDiagnostic>.unmodifiable(
            missedBranches
                .map(
                  (branch) => MissedBranchDiagnostic(
                    line: branch.line,
                    block: branch.block,
                    branch: branch.branch,
                    taken: branch.takenRaw,
                    source: null,
                  ),
                )
                .toList(),
          ),
          snippet: '',
          testTargets: const <String>[],
          preferredVerificationScope: null,
        ),
      ];
    }

    final clusters = <String, _GapCluster>{};
    for (final line in missedLines) {
      final region = parsed.findRegionForLine(line);
      final key = _clusterKey(region);
      final cluster = clusters.putIfAbsent(
        key,
        () => _GapCluster(region: region, path: path),
      );
      cluster.missedLines.add(
        MissedLineDiagnostic(line: line, source: parsed.lineText(line)),
      );
    }
    for (final branch in missedBranches) {
      final region = parsed.findRegionForLine(branch.line);
      final key = _clusterKey(region);
      final cluster = clusters.putIfAbsent(
        key,
        () => _GapCluster(region: region, path: path),
      );
      cluster.missedBranches.add(
        MissedBranchDiagnostic(
          line: branch.line,
          block: branch.block,
          branch: branch.branch,
          taken: branch.takenRaw,
          source: parsed.lineText(branch.line),
        ),
      );
    }

    final gaps = clusters.values.map((cluster) {
      cluster.sortDiagnostics();
      return DeclarationCoverageGap(
        kind: _gapKind(
          hasLines: cluster.missedLines.isNotEmpty,
          hasBranches: cluster.missedBranches.isNotEmpty,
        ),
        path: cluster.path,
        symbol: cluster.region.symbol,
        scope: cluster.region.scope,
        range: cluster.region.range,
        missedLines: List<MissedLineDiagnostic>.unmodifiable(
          cluster.missedLines,
        ),
        missedBranches: List<MissedBranchDiagnostic>.unmodifiable(
          cluster.missedBranches,
        ),
        snippet: parsed.snippetForRegion(cluster.region),
        testTargets: const <String>[],
        preferredVerificationScope: null,
      );
    }).toList();

    gaps.sort(_compareGaps);
    return gaps;
  }

  CoverageRange _fallbackRange(
    List<int> missedLines,
    List<BranchCoverage> missedBranches,
  ) {
    final firstLine = <int>[
      ...missedLines,
      ...missedBranches.map((branch) => branch.line),
    ]..sort();
    final anchorLine = firstLine.isEmpty ? 1 : firstLine.first;
    return CoverageRange(
      startLine: anchorLine,
      startColumn: 1,
      endLine: anchorLine,
      endColumn: 1,
    );
  }

  DeclarationCoverageGap locateMissingFileGap(String path) {
    final parsed = _cache.putIfAbsent(path, () => _parse(path));
    final range =
        parsed?.fileRange ??
        const CoverageRange(
          startLine: 1,
          startColumn: 1,
          endLine: 1,
          endColumn: 1,
        );
    final snippet = parsed?.fileSnippet ?? '';
    return DeclarationCoverageGap(
      kind: 'mf',
      path: path,
      symbol: null,
      scope: 'fs',
      range: range,
      missedLines: const <MissedLineDiagnostic>[],
      missedBranches: const <MissedBranchDiagnostic>[],
      snippet: snippet,
      testTargets: const <String>[],
      preferredVerificationScope: null,
    );
  }

  _ParsedSource? _parse(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final content = file.readAsStringSync();
    final parsed = parseString(
      path: path,
      content: content,
      throwIfDiagnostics: false,
    );
    return _ParsedSource(
      content: content,
      lineInfo: parsed.lineInfo,
      regions: _collectRegions(parsed.unit, parsed.lineInfo),
    );
  }

  List<_DeclarationRegion> _collectRegions(
    CompilationUnit unit,
    LineInfo lineInfo,
  ) {
    final collector = _ExecutableDeclarationCollector(lineInfo: lineInfo);
    unit.accept(collector);
    return List<_DeclarationRegion>.unmodifiable(collector.regions);
  }
}

int _compareGaps(DeclarationCoverageGap left, DeclarationCoverageGap right) {
  final pathCompare = left.path.compareTo(right.path);
  if (pathCompare != 0) {
    return pathCompare;
  }
  final startCompare = left.range.startLine.compareTo(right.range.startLine);
  if (startCompare != 0) {
    return startCompare;
  }
  return left.scope.compareTo(right.scope);
}

String _clusterKey(_DeclarationRegion region) =>
    '${region.scope}:${region.range.startLine}:${region.range.startColumn}:${region.range.endLine}:${region.range.endColumn}:${region.symbol ?? ''}';

String _gapKind({required bool hasLines, required bool hasBranches}) {
  if (hasLines && hasBranches) {
    return 'mx';
  }
  if (hasBranches) {
    return 'mb';
  }
  return 'ml';
}

class _GapCluster {
  _GapCluster({required this.region, required this.path});

  final _DeclarationRegion region;
  final String path;
  final List<MissedLineDiagnostic> missedLines = <MissedLineDiagnostic>[];
  final List<MissedBranchDiagnostic> missedBranches =
      <MissedBranchDiagnostic>[];

  void sortDiagnostics() {
    missedLines.sort((left, right) => left.line.compareTo(right.line));
    missedBranches.sort((left, right) {
      final lineCompare = left.line.compareTo(right.line);
      if (lineCompare != 0) {
        return lineCompare;
      }
      final blockCompare = left.block.compareTo(right.block);
      if (blockCompare != 0) {
        return blockCompare;
      }
      return left.branch.compareTo(right.branch);
    });
  }
}

class _ParsedSource {
  _ParsedSource({
    required this.content,
    required this.lineInfo,
    required this.regions,
  }) : _lines = content.split('\n');

  final String content;
  final LineInfo lineInfo;
  final List<_DeclarationRegion> regions;
  final List<String> _lines;

  CoverageRange get fileRange {
    final endLocation = lineInfo.getLocation(content.length);
    return CoverageRange(
      startLine: 1,
      startColumn: 1,
      endLine: endLocation.lineNumber,
      endColumn: endLocation.columnNumber,
    );
  }

  String get fileSnippet {
    if (_lines.isEmpty) {
      return '';
    }
    return _snippet(1, _lines.length < 6 ? _lines.length : 6);
  }

  String? lineText(int line) {
    if (line < 1 || line > _lines.length) {
      return null;
    }
    return _lines[line - 1].trimRight();
  }

  _DeclarationRegion findRegionForLine(int line) {
    final offset = _offsetForLine(line);
    _DeclarationRegion? bestMatch;
    for (final region in regions) {
      if (offset < region.startOffset || offset > region.endOffset) {
        continue;
      }
      if (bestMatch == null ||
          (region.endOffset - region.startOffset) <
              (bestMatch.endOffset - bestMatch.startOffset)) {
        bestMatch = region;
      }
    }
    return bestMatch ?? _fileScopeRegionForLine(line);
  }

  String snippetForRegion(_DeclarationRegion region) {
    final startLine = region.range.startLine;
    final endLine = region.range.endLine;
    final cappedEnd = endLine - startLine >= 7 ? startLine + 7 : endLine;
    return _snippet(startLine, cappedEnd);
  }

  _DeclarationRegion _fileScopeRegionForLine(int line) {
    final safeLine = line < 1 ? 1 : line;
    final source = lineText(safeLine) ?? '';
    return _DeclarationRegion(
      symbol: null,
      scope: 'fs',
      range: CoverageRange(
        startLine: safeLine,
        startColumn: 1,
        endLine: safeLine,
        endColumn: source.isEmpty ? 1 : source.length,
      ),
      startOffset: _offsetForLine(safeLine),
      endOffset: _offsetForLine(safeLine) + source.length,
    );
  }

  int _offsetForLine(int line) {
    if (line <= 1) {
      return 0;
    }
    if (line - 1 >= _lines.length) {
      return content.length;
    }
    return lineInfo.getOffsetOfLine(line - 1);
  }

  String _snippet(int startLine, int endLine) {
    if (_lines.isEmpty) {
      return '';
    }
    final normalizedStart = startLine < 1 ? 1 : startLine;
    final normalizedEnd = endLine > _lines.length ? _lines.length : endLine;
    final buffer = StringBuffer();
    for (var line = normalizedStart; line <= normalizedEnd; line++) {
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.write(_lines[line - 1].trimRight());
    }
    return buffer.toString();
  }
}

class _DeclarationRegion {
  const _DeclarationRegion({
    required this.symbol,
    required this.scope,
    required this.range,
    required this.startOffset,
    required this.endOffset,
  });

  final String? symbol;
  final String scope;
  final CoverageRange range;
  final int startOffset;
  final int endOffset;
}

class _ExecutableDeclarationCollector extends RecursiveAstVisitor<void> {
  _ExecutableDeclarationCollector({required this.lineInfo});

  final LineInfo lineInfo;
  final List<_DeclarationRegion> regions = <_DeclarationRegion>[];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    regions.add(
      _regionForNode(node, symbol: _functionSymbol(node), scope: 'td'),
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    regions.add(
      _regionForNode(
        node,
        symbol: _memberSymbol(node.name.lexeme, node),
        scope: 'md',
      ),
    );
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final className = node.returnType.toSource();
    final constructorName = node.name?.lexeme;
    final symbol = constructorName == null
        ? '$className.new'
        : '$className.$constructorName';
    regions.add(_regionForNode(node, symbol: symbol, scope: 'md'));
    super.visitConstructorDeclaration(node);
  }

  _DeclarationRegion _regionForNode(
    AstNode node, {
    required String symbol,
    required String scope,
  }) {
    final start = lineInfo.getLocation(node.offset);
    final end = lineInfo.getLocation(node.end);
    return _DeclarationRegion(
      symbol: symbol,
      scope: scope,
      range: CoverageRange(
        startLine: start.lineNumber,
        startColumn: start.columnNumber,
        endLine: end.lineNumber,
        endColumn: end.columnNumber,
      ),
      startOffset: node.offset,
      endOffset: node.end,
    );
  }

  String _functionSymbol(FunctionDeclaration node) {
    final parent = node.parent;
    final name = node.name.lexeme;
    if (parent is CompilationUnit) {
      return name;
    }
    return _memberSymbol(name, node);
  }

  String _memberSymbol(String name, AstNode node) {
    final classDeclaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDeclaration != null) {
      return '${classDeclaration.name.lexeme}.$name';
    }
    final extensionDeclaration = node
        .thisOrAncestorOfType<ExtensionDeclaration>();
    if (extensionDeclaration != null) {
      final extensionName = extensionDeclaration.name?.lexeme ?? 'extension';
      return '$extensionName.$name';
    }
    final mixinDeclaration = node.thisOrAncestorOfType<MixinDeclaration>();
    if (mixinDeclaration != null) {
      return '${mixinDeclaration.name.lexeme}.$name';
    }
    return name;
  }
}
