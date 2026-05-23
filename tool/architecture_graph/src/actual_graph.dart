import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'architecture_graph.dart';

final class ActualArchitectureGraph {
  const ActualArchitectureGraph({
    required this.exports,
    required this.imports,
    required this.declarations,
    required this.implementedInterfaces,
    required this.compositionFields,
    required this.placeholders,
    required this.exceptionThrows,
    required this.delegations,
    required this.memberCalls,
  });

  final List<ExportFact> exports;
  final List<ImportFact> imports;
  final List<DeclarationFact> declarations;
  final List<ImplementedInterfaceFact> implementedInterfaces;
  final List<CompositionFieldFact> compositionFields;
  final List<PlaceholderFact> placeholders;
  final List<ExceptionThrowFact> exceptionThrows;
  final List<DelegationFact> delegations;
  final List<MemberCallFact> memberCalls;
}

sealed class ActualGraphFact {
  const ActualGraphFact({required this.path, required this.line});

  final String path;
  final int line;
}

final class ExportFact extends ActualGraphFact {
  const ExportFact({
    required super.path,
    required super.line,
    required this.uri,
  });

  final String uri;
}

final class ImportFact extends ActualGraphFact {
  const ImportFact({
    required super.path,
    required super.line,
    required this.uri,
  });

  final String uri;
}

final class DeclarationFact extends ActualGraphFact {
  const DeclarationFact({
    required super.path,
    required super.line,
    required this.name,
    required this.kind,
  });

  final String name;
  final String kind;
}

final class ImplementedInterfaceFact extends ActualGraphFact {
  const ImplementedInterfaceFact({
    required super.path,
    required super.line,
    required this.declaration,
    required this.interface,
  });

  final String declaration;
  final String interface;
}

final class CompositionFieldFact extends ActualGraphFact {
  const CompositionFieldFact({
    required super.path,
    required super.line,
    required this.declaration,
    required this.field,
    required this.type,
  });

  final String declaration;
  final String field;
  final String type;
}

final class PlaceholderFact extends ActualGraphFact {
  const PlaceholderFact({
    required super.path,
    required super.line,
    required this.member,
    required this.throwType,
  });

  final String member;
  final String throwType;
}

final class ExceptionThrowFact extends ActualGraphFact {
  const ExceptionThrowFact({
    required super.path,
    required super.line,
    required this.exception,
    required this.owner,
    required this.member,
  });

  final String exception;
  final String? owner;
  final String? member;
}

final class DelegationFact extends ActualGraphFact {
  const DelegationFact({
    required super.path,
    required super.line,
    required this.member,
    required this.target,
    required this.targetType,
  });

  final String member;
  final String target;
  final String? targetType;
}

final class MemberCallFact extends ActualGraphFact {
  const MemberCallFact({
    required super.path,
    required super.line,
    required this.member,
    required this.target,
  });

  final String member;
  final String target;
}

ActualArchitectureGraph extractActualArchitectureGraph({
  ExpectedArchitectureGraph? expectedGraph,
  String repositoryRoot = '.',
}) {
  final expected = expectedGraph ?? loadExpectedArchitectureGraph();
  final paths = _coveredDartPaths(expected.coverage, repositoryRoot);

  return extractActualArchitectureGraphFromPaths(
    paths: paths,
    repositoryRoot: repositoryRoot,
    sensitiveThrows: expected.coverage.sensitiveThrows,
    placeholderCoverage: expected.coverage.placeholders,
    compositionTypes: _architectureCompositionTypes(expected),
    delegationMembers: _architectureDelegationMembers(expected),
    delegationTargetTypes: _architectureDelegationTargetTypes(expected),
    memberCallTargets: _architectureMemberCallTargets(expected),
  );
}

ActualArchitectureGraph extractActualArchitectureGraphFromPaths({
  required Iterable<String> paths,
  String repositoryRoot = '.',
  List<SensitiveThrowCoverage> sensitiveThrows = const [],
  List<PlaceholderCoverage> placeholderCoverage = const [],
  Set<String> compositionTypes = const {},
  Set<String> delegationMembers = const {},
  Set<String> delegationTargetTypes = const {},
  Set<String> memberCallTargets = const {},
}) {
  final collector = _ActualGraphCollector();
  for (final path in paths.toSet().toList()..sort()) {
    final file = File('$repositoryRoot/$path');
    if (!file.existsSync() || !path.endsWith('.dart')) {
      continue;
    }
    final result = parseString(content: file.readAsStringSync(), path: path);
    final visitor = _ActualGraphVisitor(
      path: path,
      lineInfo: result.lineInfo,
      collector: collector,
      sensitiveThrows: sensitiveThrows,
      placeholderCoverage: placeholderCoverage,
      compositionTypes: compositionTypes,
      delegationMembers: delegationMembers,
      delegationTargetTypes: delegationTargetTypes,
      memberCallTargets: memberCallTargets,
    );
    result.unit.visitChildren(visitor);
  }

  return collector.toGraph();
}

final class _ActualGraphCollector {
  final List<ExportFact> exports = [];
  final List<ImportFact> imports = [];
  final List<DeclarationFact> declarations = [];
  final List<ImplementedInterfaceFact> implementedInterfaces = [];
  final List<CompositionFieldFact> compositionFields = [];
  final List<PlaceholderFact> placeholders = [];
  final List<ExceptionThrowFact> exceptionThrows = [];
  final List<DelegationFact> delegations = [];
  final List<MemberCallFact> memberCalls = [];
  final Set<String> materializationRouteHelperKeys = {};
  final List<_PendingMaterializationRouteFact> materializationRoutes = [];

  ActualArchitectureGraph toGraph() {
    _promoteMaterializationRoutes();

    return ActualArchitectureGraph(
      exports: exports,
      imports: imports,
      declarations: declarations,
      implementedInterfaces: implementedInterfaces,
      compositionFields: compositionFields,
      placeholders: placeholders,
      exceptionThrows: exceptionThrows,
      delegations: delegations,
      memberCalls: memberCalls,
    );
  }

  void _promoteMaterializationRoutes() {
    for (final pending in materializationRoutes) {
      if (!materializationRouteHelperKeys.contains(pending.helperKey)) {
        continue;
      }
      memberCalls.add(pending.memberCall);
      exceptionThrows.add(pending.exceptionThrow);
    }
  }
}

final class _PendingMaterializationRouteFact {
  const _PendingMaterializationRouteFact({
    required this.helperKey,
    required this.memberCall,
    required this.exceptionThrow,
  });

  final String helperKey;
  final MemberCallFact memberCall;
  final ExceptionThrowFact exceptionThrow;
}

final class _ActualGraphVisitor extends RecursiveAstVisitor<void> {
  _ActualGraphVisitor({
    required this.path,
    required this.lineInfo,
    required this.collector,
    required this.sensitiveThrows,
    required this.placeholderCoverage,
    required this.compositionTypes,
    required this.delegationMembers,
    required this.delegationTargetTypes,
    required this.memberCallTargets,
  });

  final String path;
  final LineInfo lineInfo;
  final _ActualGraphCollector collector;
  final List<SensitiveThrowCoverage> sensitiveThrows;
  final List<PlaceholderCoverage> placeholderCoverage;
  final Set<String> compositionTypes;
  final Set<String> delegationMembers;
  final Set<String> delegationTargetTypes;
  final Set<String> memberCallTargets;
  final Map<String, String> _targetTypes = {};
  String? _currentDeclaration;
  String? _currentMember;

  @override
  void visitExportDirective(ExportDirective node) {
    collector.exports.add(
      ExportFact(
        path: path,
        line: _line(node),
        uri: normalizeDirectiveUri(
          sourcePath: path,
          uri: node.uri.stringValue ?? '',
        ),
      ),
    );
    super.visitExportDirective(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    collector.imports.add(
      ImportFact(
        path: path,
        line: _line(node),
        uri: normalizeDirectiveUri(
          sourcePath: path,
          uri: node.uri.stringValue ?? '',
        ),
      ),
    );
    super.visitImportDirective(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final name = node.namePart.typeName.lexeme;
    _addDeclaration(name, 'class', node);
    final previous = _currentDeclaration;
    _currentDeclaration = name;
    _implementedInterfaces(node);
    super.visitClassDeclaration(node);
    _currentDeclaration = previous;
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _addDeclaration(node.namePart.typeName.lexeme, 'enum', node);
    super.visitEnumDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _addDeclaration(node.name.lexeme, 'mixin', node);
    super.visitMixinDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _addDeclaration(node.name.lexeme, 'function', node);
    final previousMember = _currentMember;
    _currentMember = node.name.lexeme;
    _withParameterTypes(node.functionExpression.parameters, () {
      _delegation(node.name.lexeme, node, node.functionExpression.body);
      super.visitFunctionDeclaration(node);
    });
    _currentMember = previousMember;
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    _addDeclaration(node.name.lexeme, 'typedef', node);
    super.visitGenericTypeAlias(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final owner = _currentDeclaration;
    final type = node.fields.type?.toSource();
    if (owner != null && type != null) {
      for (final variable in node.fields.variables) {
        final fieldType = _withoutNullability(type);
        _targetTypes[variable.name.lexeme] = fieldType;
        if (!compositionTypes.contains(fieldType)) {
          continue;
        }
        collector.compositionFields.add(
          CompositionFieldFact(
            path: path,
            line: _line(node),
            declaration: owner,
            field: variable.name.lexeme,
            type: fieldType,
          ),
        );
      }
    }
    super.visitFieldDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final previousMember = _currentMember;
    _currentMember = _qualifiedMember(node.name.lexeme);
    _placeholder(node.name.lexeme, node);
    _delegation(node.name.lexeme, node, node.body);
    super.visitMethodDeclaration(node);
    _currentMember = previousMember;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final member = _currentMember;
    final target = node.methodName.name;
    if (member != null && memberCallTargets.contains(target)) {
      collector.memberCalls.add(
        MemberCallFact(
          path: path,
          line: _line(node),
          member: member,
          target: target,
        ),
      );
    }
    _pendingMaterializationRoute(member, node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    final exception = _throwType(node.expression);
    if (exception != null) {
      _verifiedMaterializationRouteHelper(node.expression, exception);
      collector.exceptionThrows.add(
        ExceptionThrowFact(
          path: path,
          line: _line(node),
          exception: exception,
          owner: _currentDeclaration ?? _sensitiveOwner(path, exception),
          member: _currentMember,
        ),
      );
    }
    super.visitThrowExpression(node);
  }

  void _addDeclaration(String name, String kind, AstNode node) {
    collector.declarations.add(
      DeclarationFact(path: path, line: _line(node), name: name, kind: kind),
    );
  }

  void _implementedInterfaces(ClassDeclaration node) {
    final implementsClause = node.implementsClause;
    if (implementsClause == null) {
      return;
    }
    for (final interface in implementsClause.interfaces) {
      collector.implementedInterfaces.add(
        ImplementedInterfaceFact(
          path: path,
          line: _line(interface),
          declaration: node.namePart.typeName.lexeme,
          interface: interface.name.lexeme,
        ),
      );
    }
  }

  void _placeholder(String member, MethodDeclaration node) {
    if (!_isPlaceholderCovered()) {
      return;
    }
    final body = node.body;
    final throwType = switch (body) {
      ExpressionFunctionBody(:final expression) => _throwType(expression),
      BlockFunctionBody(:final block) => _blockPlaceholderThrow(block),
      _ => null,
    };
    if (throwType == null || throwType != 'UnimplementedError') {
      return;
    }
    collector.placeholders.add(
      PlaceholderFact(
        path: path,
        line: _line(node),
        member: _qualifiedMember(member),
        throwType: throwType,
      ),
    );
  }

  void _delegation(String member, AstNode node, FunctionBody body) {
    final expression = switch (body) {
      ExpressionFunctionBody(:final expression) => expression,
      _ => null,
    };
    if (expression is! MethodInvocation &&
        expression is! PropertyAccess &&
        expression is! SimpleIdentifier) {
      return;
    }
    final targetName = switch (expression) {
      MethodInvocation(:final target?) => target.toSource(),
      PropertyAccess(:final target?) => target.toSource(),
      SimpleIdentifier(:final name) => name,
      _ => null,
    };
    if (targetName == null) {
      return;
    }
    final qualifiedMember = _qualifiedMember(member);
    final targetType = _targetTypes[targetName];
    if (!delegationMembers.contains(qualifiedMember) ||
        targetType == null ||
        !delegationTargetTypes.contains(targetType)) {
      return;
    }
    collector.delegations.add(
      DelegationFact(
        path: path,
        line: _line(node),
        member: qualifiedMember,
        target: targetName,
        targetType: targetType,
      ),
    );
  }

  String? _blockPlaceholderThrow(Block block) {
    if (block.statements.length != 1) {
      return null;
    }
    final statement = block.statements.single;
    if (statement is ExpressionStatement &&
        statement.expression is ThrowExpression) {
      return _throwType((statement.expression as ThrowExpression).expression);
    }

    return null;
  }

  String? _throwType(Expression expression) {
    if (expression is ThrowExpression) {
      return _throwType(expression.expression);
    }
    if (expression is InstanceCreationExpression) {
      return expression.constructorName.type.name.lexeme;
    }
    if (expression is MethodInvocation && expression.target == null) {
      final routeException = _sensitiveThrowRouteException(
        expression.methodName.name,
      );
      if (routeException != null) {
        return routeException;
      }

      return expression.methodName.name;
    }

    return null;
  }

  String? _sensitiveThrowRouteException(String methodName) {
    if (!memberCallTargets.contains(methodName)) {
      return null;
    }

    final exceptions = {
      for (final entry in sensitiveThrows)
        if (_matchesGlob(path, entry.under)) entry.exception,
    };
    if (exceptions.length == 1) {
      return exceptions.single;
    }

    return null;
  }

  void _pendingMaterializationRoute(String? member, MethodInvocation node) {
    if (member == null || node.methodName.name != '_materialize') {
      return;
    }
    for (final route in memberCallTargets) {
      final exception = _sensitiveThrowRouteException(route);
      if (exception == null) {
        continue;
      }
      collector.materializationRoutes.add(
        _PendingMaterializationRouteFact(
          helperKey: _materializationRouteHelperKey(node.methodName.name),
          memberCall: MemberCallFact(
            path: path,
            line: _line(node),
            member: member,
            target: route,
          ),
          exceptionThrow: ExceptionThrowFact(
            path: path,
            line: _line(node),
            exception: exception,
            owner: _currentDeclaration ?? _sensitiveOwner(path, exception),
            member: member,
          ),
        ),
      );
    }
  }

  void _verifiedMaterializationRouteHelper(
    Expression expression,
    String exception,
  ) {
    final member = _currentMember;
    if (member == null ||
        member != '_materialize' ||
        _sensitiveOwner(path, exception) == null) {
      return;
    }
    final route = _throwRoute(expression);
    if (route != null && memberCallTargets.contains(route)) {
      collector.materializationRouteHelperKeys.add(
        _materializationRouteHelperKey(member),
      );
    }
  }

  String _materializationRouteHelperKey(String helperName) {
    return '$path::$helperName';
  }

  String? _throwRoute(Expression expression) {
    final thrown = expression is ThrowExpression
        ? expression.expression
        : expression;

    return switch (thrown) {
      MethodInvocation(:final target, :final methodName) when target == null =>
        methodName.name,
      _ => null,
    };
  }

  String _qualifiedMember(String member) {
    final owner = _currentDeclaration;

    return owner == null ? member : '$owner.$member';
  }

  int _line(AstNode node) => lineInfo.getLocation(node.offset).lineNumber;

  void _withParameterTypes(
    FormalParameterList? parameters,
    void Function() fn,
  ) {
    if (parameters == null) {
      fn();
      return;
    }
    final oldValues = <String, String?>{};
    for (final parameter in parameters.parameters) {
      final name = parameter.name?.lexeme;
      final type = _parameterType(parameter);
      if (name == null || type == null) {
        continue;
      }
      oldValues[name] = _targetTypes[name];
      _targetTypes[name] = type;
    }
    fn();
    for (final entry in oldValues.entries) {
      final oldValue = entry.value;
      if (oldValue == null) {
        _targetTypes.remove(entry.key);
      } else {
        _targetTypes[entry.key] = oldValue;
      }
    }
  }

  String? _parameterType(FormalParameter parameter) {
    final NormalFormalParameter? normal;
    if (parameter is DefaultFormalParameter) {
      normal = parameter.parameter;
    } else if (parameter is NormalFormalParameter) {
      normal = parameter;
    } else {
      normal = null;
    }

    return switch (normal) {
      SimpleFormalParameter(:final type?) => _withoutNullability(
        type.toSource(),
      ),
      _ => null,
    };
  }

  bool _isPlaceholderCovered() {
    return placeholderCoverage.any((entry) => _matchesGlob(path, entry.under));
  }

  String? _sensitiveOwner(String path, String exception) {
    for (final entry in sensitiveThrows) {
      if (_matchesGlob(path, entry.under) && entry.exception == exception) {
        return entry.owner;
      }
    }

    return null;
  }
}

String normalizeDirectiveUri({
  required String sourcePath,
  required String uri,
}) {
  if (uri.startsWith('dart:')) {
    return uri;
  }
  const packagePrefix = 'package:iwb_canvas_engine/';
  if (uri.startsWith(packagePrefix)) {
    return 'lib/${uri.substring(packagePrefix.length)}';
  }
  if (uri.startsWith('package:')) {
    return uri;
  }
  final segments = sourcePath.split('/')..removeLast();
  for (final segment in uri.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (segments.isNotEmpty) {
        segments.removeLast();
      }
    } else {
      segments.add(segment);
    }
  }

  return segments.join('/');
}

List<String> _coveredDartPaths(
  ArchitectureCoverage coverage,
  String repositoryRoot,
) {
  final included = <String>{};
  for (final pattern in [
    ...coverage.publicSurfaces,
    ...coverage.architectureOwners,
  ]) {
    included.addAll(_expandPattern(pattern, repositoryRoot));
  }

  return included.where((path) => !_isIgnored(path, coverage.ignored)).toList();
}

List<String> _expandPattern(String pattern, String repositoryRoot) {
  if (pattern.endsWith('/**')) {
    final directory = Directory(
      '$repositoryRoot/${pattern.substring(0, pattern.length - 3)}',
    );
    if (!directory.existsSync()) {
      return const [];
    }

    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => _relativePath(file.path, repositoryRoot))
        .where((path) => path.endsWith('.dart'))
        .toList();
  }
  if (File('$repositoryRoot/$pattern').existsSync()) {
    return [pattern];
  }

  return const [];
}

bool _isIgnored(String path, List<String> ignoredPatterns) {
  return ignoredPatterns.any((pattern) {
    if (pattern == '**/fixtures/**') {
      return path.contains('/fixtures/');
    }
    if (pattern == '**/*_helper.dart') {
      return path.endsWith('_helper.dart');
    }

    return path == pattern;
  });
}

String _relativePath(String path, String repositoryRoot) {
  final rootPrefix = '${Directory(repositoryRoot).absolute.path}/';
  final absolutePath = File(path).absolute.path;

  return absolutePath.startsWith(rootPrefix)
      ? absolutePath.substring(rootPrefix.length)
      : path;
}

String _withoutNullability(String type) {
  return type.endsWith('?') ? type.substring(0, type.length - 1) : type;
}

bool _matchesGlob(String path, String pattern) {
  if (pattern.endsWith('/**')) {
    return path.startsWith(pattern.substring(0, pattern.length - 3));
  }

  return path == pattern;
}

Set<String> _architectureCompositionTypes(ExpectedArchitectureGraph graph) {
  return {for (final edge in graph.edges) ...edge.actual.compositionFields};
}

Set<String> _architectureDelegationMembers(ExpectedArchitectureGraph graph) {
  return {
    for (final node in graph.nodes) ...node.actual.delegationMembers,
    for (final edge in graph.edges) ...edge.actual.delegationMembers,
  };
}

Set<String> _architectureDelegationTargetTypes(
  ExpectedArchitectureGraph graph,
) {
  return {
    for (final node in graph.nodes) ...node.actual.delegationTargets,
    for (final edge in graph.edges) ...edge.actual.delegationTargets,
  };
}

Set<String> _architectureMemberCallTargets(ExpectedArchitectureGraph graph) {
  return {
    for (final node in graph.nodes) ...node.actual.sensitiveThrowRoutes,
    for (final edge in graph.edges) ...edge.actual.sensitiveThrowRoutes,
  };
}
