import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/source/line_info.dart';

List<File> collectFunctionAuditDartFiles(Directory root, List<String> targets) {
  final files = <File>[];
  for (final target in targets) {
    final absolute = target.startsWith('/')
        ? target
        : '${root.path}${Platform.pathSeparator}$target';
    final file = File(absolute);
    if (file.existsSync()) {
      files.add(file);
      continue;
    }
    final directory = Directory(absolute);
    if (!directory.existsSync()) {
      continue;
    }
    for (final entity in directory.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
  }
  files.sort((left, right) => left.path.compareTo(right.path));
  return files;
}

String functionAuditRepoRelativePath(Directory root, File file) {
  final rootPath = root.path.endsWith(Platform.pathSeparator)
      ? root.path
      : '${root.path}${Platform.pathSeparator}';
  if (!file.path.startsWith(rootPath)) {
    return file.path;
  }
  return file.path.replaceFirst(rootPath, '').replaceAll(r'\', '/');
}

List<FunctionAuditAnalysis> collectFunctionAuditAnalyses(
  CompilationUnit unit,
  String filePath,
) {
  final visitor = _FunctionCollector(filePath: filePath);
  unit.accept(visitor);
  return visitor.analyses;
}

/// A parsed source file shared by function-order audits.
final class FunctionAuditSource {
  FunctionAuditSource._({
    required this.file,
    required this.repoRelativePath,
    required this.analyses,
    required LineInfo lineInfo,
  }) : _lineInfo = lineInfo,
       callGraph = FunctionAuditCallGraph(analyses);

  final File file;
  final String repoRelativePath;
  final List<FunctionAuditAnalysis> analyses;
  final LineInfo _lineInfo;
  final FunctionAuditCallGraph callGraph;

  int lineForOffset(int offset) => _lineInfo.getLocation(offset).lineNumber;
}

/// Parses every selected file once so order audits share AST and path setup.
List<FunctionAuditSource> loadFunctionAuditSources(
  Directory root,
  List<File> files,
) => [for (final file in files) _loadFunctionAuditSource(root, file)];

FunctionAuditSource _loadFunctionAuditSource(Directory root, File file) {
  final parsed = parseString(
    path: file.absolute.path,
    content: file.readAsStringSync(),
    throwIfDiagnostics: false,
  );
  return FunctionAuditSource._(
    file: file,
    repoRelativePath: functionAuditRepoRelativePath(root, file),
    analyses: collectFunctionAuditAnalyses(parsed.unit, file.path),
    lineInfo: parsed.lineInfo,
  );
}

final class FunctionAuditAnalysis {
  const FunctionAuditAnalysis({
    required this.filePath,
    required this.simpleName,
    required this.displayName,
    required this.offset,
    required this.directCalls,
    required this.abortOffsets,
  });

  final String filePath;
  final String simpleName;
  final String displayName;
  final int offset;
  final List<FunctionAuditCallOccurrence> directCalls;
  final List<int> abortOffsets;
}

final class FunctionAuditCallOccurrence {
  const FunctionAuditCallOccurrence({
    required this.name,
    required this.offset,
    required this.inFinally,
  });

  final String name;
  final int offset;
  final bool inFinally;
}

/// Resolves same-file calls for the two source-order audits from one AST pass.
final class FunctionAuditCallGraph {
  FunctionAuditCallGraph(List<FunctionAuditAnalysis> analyses)
    : _calleesByName = _indexBySimpleName(analyses);

  final Map<String, Set<FunctionAuditAnalysis>> _calleesByName;

  Set<FunctionAuditAnalysis>? calleesFor(FunctionAuditCallOccurrence call) =>
      _calleesByName[call.name];

  bool reachesDirectCall(
    FunctionAuditAnalysis analysis,
    bool Function(FunctionAuditCallOccurrence call) matches,
  ) {
    final memo = <FunctionAuditAnalysis, bool>{};
    return _reachesDirectCall(
      analysis,
      matches,
      memo,
      <FunctionAuditAnalysis>{},
    );
  }

  bool _reachesDirectCall(
    FunctionAuditAnalysis analysis,
    bool Function(FunctionAuditCallOccurrence call) matches,
    Map<FunctionAuditAnalysis, bool> memo,
    Set<FunctionAuditAnalysis> active,
  ) {
    final cached = memo[analysis];
    if (cached != null) {
      return cached;
    }
    if (!active.add(analysis)) {
      return false;
    }
    final result = analysis.directCalls.any(
      (call) =>
          matches(call) ||
          (calleesFor(call)?.any(
                (callee) => _reachesDirectCall(callee, matches, memo, active),
              ) ??
              false),
    );
    active.remove(analysis);
    memo[analysis] = result;
    return result;
  }
}

Map<String, Set<FunctionAuditAnalysis>> _indexBySimpleName(
  List<FunctionAuditAnalysis> analyses,
) {
  final result = <String, Set<FunctionAuditAnalysis>>{};
  for (final analysis in analyses) {
    result
        .putIfAbsent(analysis.simpleName, () => <FunctionAuditAnalysis>{})
        .add(analysis);
  }
  return result;
}

final class _FunctionCollector extends RecursiveAstVisitor<void> {
  _FunctionCollector({required this.filePath});

  final String filePath;
  final List<FunctionAuditAnalysis> analyses = <FunctionAuditAnalysis>[];
  final List<String> _ownerStack = <String>[];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _ownerStack.add(_className(node));
    super.visitClassDeclaration(node);
    _ownerStack.removeLast();
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final name = node.name?.lexeme;
    if (name != null) {
      _ownerStack.add(name);
    }
    super.visitExtensionDeclaration(node);
    if (name != null) {
      _ownerStack.removeLast();
    }
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _addAnalysis(
      node.name.lexeme,
      node.name.offset,
      node.functionExpression.body,
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _addAnalysis(node.name.lexeme, node.name.offset, node.body);
    super.visitMethodDeclaration(node);
  }

  void _addAnalysis(String name, int offset, FunctionBody body) {
    final collector = _CallCollector();
    body.visitChildren(collector);
    analyses.add(
      FunctionAuditAnalysis(
        filePath: filePath,
        simpleName: name,
        displayName: _displayName(name),
        offset: offset,
        directCalls: collector.calls,
        abortOffsets: collector.abortOffsets,
      ),
    );
  }

  String _displayName(String functionName) => _ownerStack.isEmpty
      ? functionName
      : '${_ownerStack.join('.')}.$functionName';
}

String _className(ClassDeclaration declaration) {
  final namePart = declaration.namePart;
  return switch (namePart) {
    NameWithTypeParameters(:final typeName) => typeName.lexeme,
    PrimaryConstructorDeclaration() => namePart.beginToken.lexeme,
  };
}

// The collector intentionally visits the distinct syntax forms that determine
// immediate cleanup order; splitting visitors would obscure that one boundary.
// ignore: coupling-between-object-classes, reason: One visitor must inspect the syntax forms that define immediate cleanup order.
final class _CallCollector extends RecursiveAstVisitor<void> {
  final List<FunctionAuditCallOccurrence> calls =
      <FunctionAuditCallOccurrence>[];
  final List<int> abortOffsets = <int>[];
  var _finallyDepth = 0;

  @override
  void visitTryStatement(TryStatement node) {
    node.body.accept(this);
    for (final catchClause in node.catchClauses) {
      catchClause.accept(this);
    }
    final finallyBlock = node.finallyBlock;
    if (finallyBlock != null) {
      _finallyDepth++;
      finallyBlock.accept(this);
      _finallyDepth--;
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    calls.add(
      FunctionAuditCallOccurrence(
        name: node.methodName.name,
        offset: node.methodName.offset,
        inFinally: _finallyDepth > 0,
      ),
    );
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final function = node.function;
    if (function is SimpleIdentifier) {
      calls.add(
        FunctionAuditCallOccurrence(
          name: function.name,
          offset: function.offset,
          inFinally: _finallyDepth > 0,
        ),
      );
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    abortOffsets.add(node.returnKeyword.offset);
    super.visitReturnStatement(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    abortOffsets.add(node.throwKeyword.offset);
    super.visitThrowExpression(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Deferred callbacks are not part of either audit's immediate cleanup path.
    return;
  }
}
