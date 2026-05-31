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

final class ActualGraphExtractionOptions {
  const ActualGraphExtractionOptions({
    this.sensitiveThrows = const [],
    this.placeholderCoverage = const [],
    this.compositionTypes = const {},
    this.delegationMembers = const {},
    this.delegationTargetTypes = const {},
    this.memberCallTargets = const {},
  });

  final List<SensitiveThrowCoverage> sensitiveThrows;
  final List<PlaceholderCoverage> placeholderCoverage;
  final Set<String> compositionTypes;
  final Set<String> delegationMembers;
  final Set<String> delegationTargetTypes;
  final Set<String> memberCallTargets;
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
    options: ActualGraphExtractionOptions(
      sensitiveThrows: expected.coverage.sensitiveThrows,
      placeholderCoverage: expected.coverage.placeholders,
      compositionTypes: _architectureCompositionTypes(expected),
      delegationMembers: _architectureDelegationMembers(expected),
      delegationTargetTypes: _architectureDelegationTargetTypes(expected),
      memberCallTargets: _architectureMemberCallTargets(expected),
    ),
  );
}

ActualArchitectureGraph extractActualArchitectureGraphFromPaths({
  required Iterable<String> paths,
  String repositoryRoot = '.',
  ActualGraphExtractionOptions options = const ActualGraphExtractionOptions(),
}) {
  final collector = _ActualGraphCollector();
  for (final path in paths.toSet().toList()..sort()) {
    _extractActualGraphFromFile(
      path: path,
      repositoryRoot: repositoryRoot,
      collector: collector,
      options: options,
    );
  }

  return collector.toGraph();
}

void _extractActualGraphFromFile({
  required String path,
  required String repositoryRoot,
  required _ActualGraphCollector collector,
  required ActualGraphExtractionOptions options,
}) {
  final file = File('$repositoryRoot/$path');
  if (!file.existsSync() || !path.endsWith('.dart')) {
    return;
  }
  final result = parseString(content: file.readAsStringSync(), path: path);
  final parsed = _ParsedGraphFile(
    path: path,
    unit: result.unit,
    lineInfo: result.lineInfo,
    collector: collector,
    options: options,
  );
  _visitSurfaceFacts(parsed);
  _visitBehaviorFacts(parsed);
}

final class _ParsedGraphFile {
  const _ParsedGraphFile({
    required this.path,
    required this.unit,
    required this.lineInfo,
    required this.collector,
    required this.options,
  });

  final String path;
  final CompilationUnit unit;
  final LineInfo lineInfo;
  final _ActualGraphCollector collector;
  final ActualGraphExtractionOptions options;
}

void _visitSurfaceFacts(_ParsedGraphFile file) {
  file.unit.visitChildren(
    _DirectiveGraphVisitor(
      path: file.path,
      lineInfo: file.lineInfo,
      collector: file.collector,
    ),
  );
  file.unit.visitChildren(
    _TypeDeclarationInventoryVisitor(
      sink: _DeclarationFactSink(file.path, file.lineInfo, file.collector),
    ),
  );
  file.unit.visitChildren(
    _TopLevelDeclarationInventoryVisitor(
      sink: _DeclarationFactSink(file.path, file.lineInfo, file.collector),
    ),
  );
}

void _visitBehaviorFacts(_ParsedGraphFile file) {
  _visitCompositionAndPlaceholders(file);
  _visitDelegationsAndRoutes(file);
}

void _visitCompositionAndPlaceholders(_ParsedGraphFile file) {
  file.unit.visitChildren(
    _CompositionFieldVisitor(
      sink: _CompositionFactSink(file.path, file.lineInfo, file.collector),
      compositionTypes: file.options.compositionTypes,
    ),
  );
  file.unit.visitChildren(
    _PlaceholderVisitor(
      path: file.path,
      lineInfo: file.lineInfo,
      collector: file.collector,
      options: file.options,
    ),
  );
}

void _visitDelegationsAndRoutes(_ParsedGraphFile file) {
  file.unit.visitChildren(
    _TopLevelDelegationVisitor(
      sink: _DelegationFactSink(
        file.path,
        file.lineInfo,
        file.collector,
        file.options,
      ),
    ),
  );
  file.unit.visitChildren(
    _MemberDelegationVisitor(
      sink: _DelegationFactSink(
        file.path,
        file.lineInfo,
        file.collector,
        file.options,
      ),
    ),
  );
  file.unit.visitChildren(
    _ThrowRouteVisitor(
      path: file.path,
      lineInfo: file.lineInfo,
      collector: file.collector,
      options: file.options,
    ),
  );
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

final class _DirectiveGraphVisitor extends RecursiveAstVisitor<void> {
  _DirectiveGraphVisitor({
    required this.path,
    required this.lineInfo,
    required this.collector,
  });

  final String path;
  final LineInfo lineInfo;
  final _ActualGraphCollector collector;

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

  int _line(AstNode node) => lineInfo.getLocation(node.offset).lineNumber;
}

final class _TypeDeclarationInventoryVisitor extends RecursiveAstVisitor<void> {
  const _TypeDeclarationInventoryVisitor({required this.sink});

  final _DeclarationFactSink sink;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final name = node.namePart.typeName.lexeme;
    sink.addDeclaration(name, 'class', node);
    sink.addImplementedInterfaces(node);
    super.visitClassDeclaration(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    sink.addDeclaration(node.namePart.typeName.lexeme, 'enum', node);
    super.visitEnumDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    sink.addDeclaration(node.name.lexeme, 'mixin', node);
    super.visitMixinDeclaration(node);
  }
}

final class _TopLevelDeclarationInventoryVisitor
    extends RecursiveAstVisitor<void> {
  const _TopLevelDeclarationInventoryVisitor({required this.sink});

  final _DeclarationFactSink sink;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    sink.addDeclaration(node.name.lexeme, 'function', node);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    sink.addDeclaration(node.name.lexeme, 'typedef', node);
    super.visitGenericTypeAlias(node);
  }
}

final class _DeclarationFactSink {
  const _DeclarationFactSink(this.path, this.lineInfo, this.collector);

  final String path;
  final LineInfo lineInfo;
  final _ActualGraphCollector collector;

  void addDeclaration(String name, String kind, AstNode node) {
    collector.declarations.add(
      DeclarationFact(path: path, line: _line(node), name: name, kind: kind),
    );
  }

  void addImplementedInterfaces(ClassDeclaration node) {
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

  int _line(AstNode node) => lineInfo.getLocation(node.offset).lineNumber;
}

final class _CompositionFieldVisitor extends RecursiveAstVisitor<void> {
  _CompositionFieldVisitor({
    required this.sink,
    required this.compositionTypes,
  });

  final _CompositionFactSink sink;
  final Set<String> compositionTypes;
  String? _currentDeclaration;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final previous = _currentDeclaration;
    _currentDeclaration = node.namePart.typeName.lexeme;
    super.visitClassDeclaration(node);
    _currentDeclaration = previous;
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final owner = _currentDeclaration;
    final type = node.fields.type?.toSource();
    if (owner != null && type != null) {
      _recordCompositionFields(
        node: node,
        owner: owner,
        fieldType: _withoutNullability(type),
      );
    }
    super.visitFieldDeclaration(node);
  }

  void _recordCompositionFields({
    required FieldDeclaration node,
    required String owner,
    required String fieldType,
  }) {
    for (final variable in node.fields.variables) {
      if (!compositionTypes.contains(fieldType)) {
        continue;
      }
      sink.addField(
        node: node,
        owner: owner,
        variable: variable,
        type: fieldType,
      );
    }
  }
}

final class _CompositionFactSink {
  const _CompositionFactSink(this.path, this.lineInfo, this.collector);

  final String path;
  final LineInfo lineInfo;
  final _ActualGraphCollector collector;

  void addField({
    required FieldDeclaration node,
    required String owner,
    required VariableDeclaration variable,
    required String type,
  }) {
    collector.compositionFields.add(
      CompositionFieldFact(
        path: path,
        line: _line(node),
        declaration: owner,
        field: variable.name.lexeme,
        type: type,
      ),
    );
  }

  int _line(AstNode node) => lineInfo.getLocation(node.offset).lineNumber;
}

final class _PlaceholderVisitor extends RecursiveAstVisitor<void> {
  _PlaceholderVisitor({
    required this.path,
    required this.lineInfo,
    required this.collector,
    required this.options,
  });

  final String path;
  final LineInfo lineInfo;
  final _ActualGraphCollector collector;
  final ActualGraphExtractionOptions options;
  String? _currentDeclaration;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final previous = _currentDeclaration;
    _currentDeclaration = node.namePart.typeName.lexeme;
    super.visitClassDeclaration(node);
    _currentDeclaration = previous;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _recordPlaceholder(
      _PlaceholderCandidate(
        path: path,
        lineInfo: lineInfo,
        collector: collector,
        options: options,
        qualifiedMember: _qualifiedMember(node.name.lexeme),
        node: node,
      ),
    );
    super.visitMethodDeclaration(node);
  }

  String _qualifiedMember(String member) {
    final owner = _currentDeclaration;

    return owner == null ? member : '$owner.$member';
  }
}

final class _TopLevelDelegationVisitor extends RecursiveAstVisitor<void> {
  _TopLevelDelegationVisitor({required this.sink})
    : _targets = _TargetTypeScope();

  final _DelegationFactSink sink;
  final _TargetTypeScope _targets;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _targets.withParameterTypes(node.functionExpression.parameters, () {
      _recordDelegation(
        _DelegationCandidate(
          sink: sink,
          qualifiedMember: node.name.lexeme,
          targetTypes: _targets.values,
          node: node,
          body: node.functionExpression.body,
        ),
      );
      super.visitFunctionDeclaration(node);
    });
  }
}

final class _MemberDelegationVisitor extends RecursiveAstVisitor<void> {
  _MemberDelegationVisitor({required this.sink})
    : _targets = _TargetTypeScope();

  final _DelegationFactSink sink;
  final _TargetTypeScope _targets;
  String? _currentDeclaration;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final previous = _currentDeclaration;
    _currentDeclaration = node.namePart.typeName.lexeme;
    super.visitClassDeclaration(node);
    _currentDeclaration = previous;
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    _targets.recordFieldTypes(node);
    super.visitFieldDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _targets.withParameterTypes(node.parameters, () {
      _recordDelegation(
        _DelegationCandidate(
          sink: sink,
          qualifiedMember: _qualifiedMember(node.name.lexeme),
          targetTypes: _targets.values,
          node: node,
          body: node.body,
        ),
      );
      super.visitMethodDeclaration(node);
    });
  }

  String _qualifiedMember(String member) {
    final owner = _currentDeclaration;

    return owner == null ? member : '$owner.$member';
  }
}

final class _ThrowRouteVisitor extends RecursiveAstVisitor<void> {
  _ThrowRouteVisitor({
    required this.path,
    required this.lineInfo,
    required this.collector,
    required this.options,
  }) : _throws = _ThrowRouteRecorder(path, lineInfo, collector, options);

  final String path;
  final LineInfo lineInfo;
  final _ActualGraphCollector collector;
  final ActualGraphExtractionOptions options;
  final _ThrowRouteRecorder _throws;
  String? _currentDeclaration;
  String? _currentMember;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final previous = _currentDeclaration;
    _currentDeclaration = node.namePart.typeName.lexeme;
    super.visitClassDeclaration(node);
    _currentDeclaration = previous;
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final previousMember = _currentMember;
    _currentMember = node.name.lexeme;
    super.visitFunctionDeclaration(node);
    _currentMember = previousMember;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final previousMember = _currentMember;
    _currentMember = _qualifiedMember(node.name.lexeme);
    super.visitMethodDeclaration(node);
    _currentMember = previousMember;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _throws.recordCall(
      member: _currentMember,
      owner: _currentDeclaration,
      node: node,
    );
    super.visitMethodInvocation(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    _throws.recordThrow(
      owner: _currentDeclaration,
      member: _currentMember,
      node: node,
    );
    super.visitThrowExpression(node);
  }

  String _qualifiedMember(String member) {
    final owner = _currentDeclaration;

    return owner == null ? member : '$owner.$member';
  }
}

final class _DelegationCandidate {
  const _DelegationCandidate({
    required this.sink,
    required this.qualifiedMember,
    required this.targetTypes,
    required this.node,
    required this.body,
  });

  final _DelegationFactSink sink;
  final String qualifiedMember;
  final Map<String, String> targetTypes;
  final AstNode node;
  final FunctionBody body;
}

final class _PlaceholderCandidate {
  const _PlaceholderCandidate({
    required this.path,
    required this.lineInfo,
    required this.collector,
    required this.options,
    required this.qualifiedMember,
    required this.node,
  });

  final String path;
  final LineInfo lineInfo;
  final _ActualGraphCollector collector;
  final ActualGraphExtractionOptions options;
  final String qualifiedMember;
  final MethodDeclaration node;
}

final class _TargetTypeScope {
  final Map<String, String> values = {};

  void recordFieldTypes(FieldDeclaration node) {
    final type = node.fields.type?.toSource();
    if (type == null) {
      return;
    }
    for (final variable in node.fields.variables) {
      values[variable.name.lexeme] = _withoutNullability(type);
    }
  }

  void withParameterTypes(FormalParameterList? parameters, void Function() fn) {
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
      oldValues[name] = values[name];
      values[name] = type;
    }
    fn();
    for (final entry in oldValues.entries) {
      final oldValue = entry.value;
      if (oldValue == null) {
        values.remove(entry.key);
      } else {
        values[entry.key] = oldValue;
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
}

void _recordPlaceholder(_PlaceholderCandidate candidate) {
  if (!_isPlaceholderCovered(candidate.path, candidate.options)) {
    return;
  }
  final throwType = _placeholderThrow(candidate.node.body, candidate);
  if (throwType == null || throwType != 'UnimplementedError') {
    return;
  }
  candidate.collector.placeholders.add(
    PlaceholderFact(
      path: candidate.path,
      line: _line(candidate.lineInfo, candidate.node),
      member: candidate.qualifiedMember,
      throwType: throwType,
    ),
  );
}

String? _placeholderThrow(FunctionBody body, _PlaceholderCandidate candidate) {
  return switch (body) {
    ExpressionFunctionBody(:final expression) => _throwType(
      expression,
      candidate.options,
      candidate.path,
    ),
    BlockFunctionBody(:final block) => _blockThrow(block, candidate),
    _ => null,
  };
}

String? _blockThrow(Block block, _PlaceholderCandidate candidate) {
  if (block.statements.length != 1) {
    return null;
  }
  final statement = block.statements.single;
  if (statement is ExpressionStatement &&
      statement.expression is ThrowExpression) {
    return _throwType(
      (statement.expression as ThrowExpression).expression,
      candidate.options,
      candidate.path,
    );
  }

  return null;
}

bool _isPlaceholderCovered(String path, ActualGraphExtractionOptions options) {
  return options.placeholderCoverage.any(
    (entry) => _matchesGlob(path, entry.under),
  );
}

void _recordDelegation(_DelegationCandidate candidate) {
  if (!candidate.sink.options.delegationMembers.contains(
    candidate.qualifiedMember,
  )) {
    return;
  }
  for (final targetName in _delegationTargets(candidate.body)) {
    final targetType = candidate.targetTypes[targetName];
    if (targetType == null ||
        !candidate.sink.options.delegationTargetTypes.contains(targetType)) {
      continue;
    }
    candidate.sink.addDelegation(
      DelegationFact(
        path: candidate.sink.path,
        line: candidate.sink.line(candidate.node),
        member: candidate.qualifiedMember,
        target: targetName,
        targetType: targetType,
      ),
    );
  }
}

final class _DelegationFactSink {
  const _DelegationFactSink(
    this.path,
    this.lineInfo,
    this.collector,
    this.options,
  );

  final String path;
  final LineInfo lineInfo;
  final _ActualGraphCollector collector;
  final ActualGraphExtractionOptions options;

  void addDelegation(DelegationFact fact) {
    collector.delegations.add(fact);
  }

  int line(AstNode node) => lineInfo.getLocation(node.offset).lineNumber;
}

Iterable<String> _delegationTargets(FunctionBody body) {
  final expression = switch (body) {
    ExpressionFunctionBody(:final expression) => expression,
    _ => null,
  };
  final expressionTarget = _delegationTargetFromExpression(expression);
  if (expressionTarget != null) {
    return [expressionTarget];
  }
  if (body is! BlockFunctionBody) {
    return const [];
  }

  final visitor = _DelegationTargetVisitor()..visitBlock(body.block);

  return visitor.targets;
}

String? _delegationTargetFromExpression(Expression? expression) {
  return switch (expression) {
    MethodInvocation(:final target?) => target.toSource(),
    PropertyAccess(:final target?) => target.toSource(),
    SimpleIdentifier(:final name) => name,
    _ => null,
  };
}

final class _DelegationTargetVisitor extends RecursiveAstVisitor<void> {
  final Set<String> targets = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = _delegationTargetFromExpression(node.target);
    if (target != null) {
      targets.add(target);
    }
    super.visitMethodInvocation(node);
  }
}

final class _ThrowRouteRecorder {
  const _ThrowRouteRecorder(
    this.path,
    this.lineInfo,
    this.collector,
    this.options,
  );

  final String path;
  final LineInfo lineInfo;
  final _ActualGraphCollector collector;
  final ActualGraphExtractionOptions options;

  void recordCall({
    required String? member,
    required String? owner,
    required MethodInvocation node,
  }) {
    final target = node.methodName.name;
    if (member != null && options.memberCallTargets.contains(target)) {
      collector.memberCalls.add(
        MemberCallFact(
          path: path,
          line: _line(node),
          member: member,
          target: target,
        ),
      );
    }
    _pendingMaterializationRoute(member: member, owner: owner, node: node);
  }

  void recordThrow({
    required String? owner,
    required String? member,
    required ThrowExpression node,
  }) {
    final exception = _throwType(node.expression, options, path);
    if (exception == null) {
      return;
    }
    _verifiedMaterializationRouteHelper(member, node.expression, exception);
    collector.exceptionThrows.add(
      ExceptionThrowFact(
        path: path,
        line: _line(node),
        exception: exception,
        owner: owner ?? _sensitiveOwner(exception),
        member: member,
      ),
    );
  }

  void _pendingMaterializationRoute({
    required String? member,
    required String? owner,
    required MethodInvocation node,
  }) {
    if (member == null || node.methodName.name != '_materialize') {
      return;
    }
    for (final route in options.memberCallTargets) {
      final exception = _sensitiveThrowRouteException(route);
      if (exception == null) {
        continue;
      }
      collector.materializationRoutes.add(
        _PendingMaterializationRouteFact(
          helperKey: _materializationRouteHelperKey(
            node.methodName.name,
            route,
          ),
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
            owner: owner ?? _sensitiveOwner(exception),
            member: member,
          ),
        ),
      );
    }
  }

  void _verifiedMaterializationRouteHelper(
    String? member,
    Expression expression,
    String exception,
  ) {
    if (member == null ||
        member != '_materialize' ||
        _sensitiveOwner(exception) == null) {
      return;
    }
    final helperName = member;
    final route = _throwRoute(expression);
    if (route != null && options.memberCallTargets.contains(route)) {
      collector.materializationRouteHelperKeys.add(
        _materializationRouteHelperKey(helperName, route),
      );
    }
  }

  String? _sensitiveThrowRouteException(String methodName) {
    if (!options.memberCallTargets.contains(methodName)) {
      return null;
    }

    final exceptions = {
      for (final entry in options.sensitiveThrows)
        if (_matchesGlob(path, entry.under)) entry.exception,
    };
    if (exceptions.length == 1) {
      return exceptions.single;
    }

    return null;
  }

  String? _sensitiveOwner(String exception) {
    for (final entry in options.sensitiveThrows) {
      if (_matchesGlob(path, entry.under) && entry.exception == exception) {
        return entry.owner;
      }
    }

    return null;
  }

  String _materializationRouteHelperKey(String helperName, String routeTarget) {
    return '$path::$helperName::$routeTarget';
  }

  int _line(AstNode node) => lineInfo.getLocation(node.offset).lineNumber;
}

String? _throwType(
  Expression expression,
  ActualGraphExtractionOptions options,
  String path,
) {
  if (expression is ThrowExpression) {
    return _throwType(expression.expression, options, path);
  }
  if (expression is InstanceCreationExpression) {
    return expression.constructorName.type.name.lexeme;
  }
  if (expression is MethodInvocation && expression.target == null) {
    final routeException = _routeException(
      expression.methodName.name,
      options,
      path,
    );
    if (routeException != null) {
      return routeException;
    }

    return expression.methodName.name;
  }

  return null;
}

String? _routeException(
  String methodName,
  ActualGraphExtractionOptions options,
  String path,
) {
  if (!options.memberCallTargets.contains(methodName)) {
    return null;
  }

  final exceptions = {
    for (final entry in options.sensitiveThrows)
      if (_matchesGlob(path, entry.under)) entry.exception,
  };
  if (exceptions.length == 1) {
    return exceptions.single;
  }

  return null;
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

int _line(LineInfo lineInfo, AstNode node) {
  return lineInfo.getLocation(node.offset).lineNumber;
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
