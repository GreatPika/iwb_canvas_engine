import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

final class WrapperCandidate {
  const WrapperCandidate({
    required this.repoRelativePath,
    required this.ownerName,
    required this.memberName,
    required this.targetName,
    required this.classification,
    required this.line,
    required this.forwardedParameterCount,
    required this.parameterCount,
    required this.guardCount,
    required this.invocationCount,
    required this.sameNameForwarding,
  });

  final String repoRelativePath;
  final String ownerName;
  final String memberName;
  final String targetName;
  final String classification;
  final int line;
  final int forwardedParameterCount;
  final int parameterCount;
  final int guardCount;
  final int invocationCount;
  final bool sameNameForwarding;
}

List<WrapperCandidate> collectWrapperCandidates({
  required Directory root,
  required String targetPath,
  bool includePrivate = false,
}) {
  final candidates = <WrapperCandidate>[];
  final type = FileSystemEntity.typeSync(
    '${root.path}${Platform.pathSeparator}$targetPath',
  );
  final files =
      switch (type) {
          FileSystemEntityType.file => <File>[
            File('${root.path}${Platform.pathSeparator}$targetPath'),
          ],
          FileSystemEntityType.directory =>
            Directory('${root.path}${Platform.pathSeparator}$targetPath')
                .listSync(recursive: true)
                .whereType<File>()
                .where((file) => file.path.endsWith('.dart')),
          _ => const <File>[],
        }.toList(growable: false)
        ..sort((left, right) => left.path.compareTo(right.path));

  for (final file in files) {
    final repoRelativePath = file.path
        .replaceFirst('${root.path}${Platform.pathSeparator}', '')
        .replaceAll('\\', '/');
    final parsed = parseString(
      path: file.path,
      content: file.readAsStringSync(),
      throwIfDiagnostics: false,
    );
    final lineInfo = parsed.lineInfo;
    for (final declaration
        in parsed.unit.declarations.whereType<ClassDeclaration>()) {
      for (final member in declaration.members.whereType<MethodDeclaration>()) {
        final candidate = _classifyMethod(
          repoRelativePath: repoRelativePath,
          ownerName: declaration.name.lexeme,
          member: member,
          lineInfo: lineInfo,
          includePrivate: includePrivate,
        );
        if (candidate != null) {
          candidates.add(candidate);
        }
      }
    }
  }

  candidates.sort((left, right) {
    final classCompare = left.classification.compareTo(right.classification);
    if (classCompare != 0) {
      return classCompare;
    }
    final fileCompare = left.repoRelativePath.compareTo(right.repoRelativePath);
    if (fileCompare != 0) {
      return fileCompare;
    }
    return left.line.compareTo(right.line);
  });
  return candidates;
}

WrapperCandidate? _classifyMethod({
  required String repoRelativePath,
  required String ownerName,
  required MethodDeclaration member,
  required LineInfo lineInfo,
  required bool includePrivate,
}) {
  if (!includePrivate && member.name.lexeme.startsWith('_')) {
    return null;
  }
  final body = member.body;
  if (body is! BlockFunctionBody && body is! ExpressionFunctionBody) {
    return null;
  }

  final parameters =
      member.parameters?.parameters
          .map((parameter) => parameter.name?.lexeme)
          .whereType<String>()
          .toSet() ??
      const <String>{};
  if (parameters.isEmpty) {
    return null;
  }

  final inspector = _WrapperInspector();
  body.accept(inspector);
  if (inspector.invocations.length != 1) {
    return null;
  }

  final invocation = inspector.invocations.single;
  final targetName = invocation.methodName;
  if (targetName == null) {
    return null;
  }

  final forwardedCount = invocation.argumentNames
      .where(parameters.contains)
      .length;
  final sameNameForwarding = targetName == member.name.lexeme;
  final forwardingRatio = forwardedCount / parameters.length;

  if (!sameNameForwarding && forwardingRatio < 0.8) {
    return null;
  }

  final classification = switch ((
    inspector.guardCount,
    inspector.hasExtraNonGuardStatements,
  )) {
    (0, false) => 'pure-forwarder',
    (_, false) => 'guarded-forwarder',
    (_, true) => 'forwarder-with-side-effects',
  };

  final location = lineInfo.getLocation(member.name.offset);
  return WrapperCandidate(
    repoRelativePath: repoRelativePath,
    ownerName: ownerName,
    memberName: member.name.lexeme,
    targetName: targetName,
    classification: classification,
    line: location.lineNumber,
    forwardedParameterCount: forwardedCount,
    parameterCount: parameters.length,
    guardCount: inspector.guardCount,
    invocationCount: inspector.invocations.length,
    sameNameForwarding: sameNameForwarding,
  );
}

final class _WrapperInspector extends RecursiveAstVisitor<void> {
  final List<_InvocationSummary> invocations = <_InvocationSummary>[];
  int guardCount = 0;
  bool hasExtraNonGuardStatements = false;

  @override
  void visitBlock(Block node) {
    for (final statement in node.statements) {
      if (_isGuardStatement(statement)) {
        guardCount++;
        continue;
      }
      if (statement case ReturnStatement(:final expression?)) {
        expression.accept(this);
        continue;
      }
      if (statement case ExpressionStatement(:final expression)) {
        expression.accept(this);
        if (expression is MethodInvocation ||
            expression is FunctionExpressionInvocation ||
            expression is PrefixedIdentifier) {
          continue;
        }
      }
      hasExtraNonGuardStatements = true;
      statement.accept(this);
    }
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    node.expression.accept(this);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(
      _InvocationSummary(
        methodName: node.methodName.name,
        argumentNames: _collectArgumentNames(node.argumentList.arguments),
      ),
    );
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    invocations.add(
      _InvocationSummary(
        methodName: null,
        argumentNames: _collectArgumentNames(node.argumentList.arguments),
      ),
    );
  }
}

bool _isGuardStatement(Statement statement) {
  if (statement is! IfStatement) {
    return false;
  }
  if (statement.elseStatement != null) {
    return false;
  }
  return _returnsImmediately(statement.thenStatement);
}

bool _returnsImmediately(Statement statement) {
  if (statement is ReturnStatement) {
    return true;
  }
  if (statement is Block) {
    final statements = statement.statements;
    return statements.length == 1 && statements.single is ReturnStatement;
  }
  return false;
}

Set<String> _collectArgumentNames(NodeList<Expression> arguments) {
  final names = <String>{};
  for (final argument in arguments) {
    switch (argument) {
      case NamedExpression(:final expression):
        if (expression is SimpleIdentifier) {
          names.add(expression.name);
        }
      case SimpleIdentifier():
        names.add(argument.name);
      default:
        continue;
    }
  }
  return names;
}

final class _InvocationSummary {
  const _InvocationSummary({
    required this.methodName,
    required this.argumentNames,
  });

  final String? methodName;
  final Set<String> argumentNames;
}
