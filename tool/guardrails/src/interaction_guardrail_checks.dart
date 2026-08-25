import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

const interactionNoConcreteStoreImportsGuardrailId =
    'interaction.no_concrete_store_imports';
const interactionNoConcreteSelectionImportsGuardrailId =
    'interaction.no_concrete_selection_imports';
const interactionReadPortImmutableFactsGuardrailId =
    'interaction.read_port_immutable_facts';
const interactionNoCommandFactsImportGuardrailId =
    'interaction.no_command_facts_import';
const interactionCleanupCoordinatorDependencyBansGuardrailId =
    'interaction.cleanup_coordinator_dependency_bans';
const interactionNoResolverOnCancelPathsGuardrailId =
    'interaction.no_resolver_on_cancel_paths';
const interactionNoStaleTerminalCommitGuardrailId =
    'interaction.no_stale_terminal_commit';

Future<List<GuardrailViolation>> checkInteractionImportBoundaries() async {
  final violations = <GuardrailViolation>[];
  for (final file in dartFilesUnder('lib/src/interaction')) {
    final path = relativePath(file);
    violations.addAll(
      checkInteractionImportBoundaryFile(
        path: path,
        content: file.readAsStringSync(),
      ),
    );
  }

  return violations;
}

List<GuardrailViolation> checkInteractionImportBoundaryFile({
  required String path,
  required String content,
}) {
  final violations = <GuardrailViolation>[];
  for (final uri in _directiveUris(content)) {
    final target = _targetPath(path, uri);
    if (target == null && !uri.startsWith('package:flutter/')) {
      continue;
    }

    _addInteractionImportViolations(
      violations: violations,
      path: path,
      uri: uri,
      target: target,
    );
  }

  return violations;
}

void _addInteractionImportViolations({
  required List<GuardrailViolation> violations,
  required String path,
  required String uri,
  required String? target,
}) {
  if (_isInteractionStoreTarget(target)) {
    violations.add(
      GuardrailViolation(
        guardrailId: interactionNoConcreteStoreImportsGuardrailId,
        path: path,
        message: 'interaction code may not import concrete store code',
      ),
    );
  }
  if (_isInteractionSelectionTarget(target)) {
    violations.add(
      GuardrailViolation(
        guardrailId: interactionNoConcreteSelectionImportsGuardrailId,
        path: path,
        message: 'interaction code may not import concrete selection code',
      ),
    );
  }
  if (target == 'lib/src/contracts/internal/command_facts_port.dart') {
    violations.add(
      GuardrailViolation(
        guardrailId: interactionNoCommandFactsImportGuardrailId,
        path: path,
        message: 'interaction code may not import command facts',
      ),
    );
  }
  if (_isInteractionOwnerTarget(target) || uri.startsWith('package:flutter/')) {
    violations.add(
      GuardrailViolation(
        guardrailId: 'core.import_boundaries',
        path: path,
        message: 'interaction import boundary violation',
      ),
    );
  }
}

Future<List<GuardrailViolation>> checkCleanupCoordinatorDependencyBans() async {
  final violations = <GuardrailViolation>[];
  for (final path in _cleanupDependencyBanPaths) {
    final file = File('$repositoryRoot/$path');
    if (!file.existsSync()) {
      violations.add(
        GuardrailViolation(
          guardrailId: interactionCleanupCoordinatorDependencyBansGuardrailId,
          path: path,
          message: 'cleanup dependency-ban source is missing',
        ),
      );
      continue;
    }
    violations.addAll(
      checkCleanupCoordinatorDependencyFile(
        path: path,
        content: file.readAsStringSync(),
      ),
    );
  }

  return violations;
}

List<GuardrailViolation> checkCleanupCoordinatorDependencyFile({
  required String path,
  required String content,
}) {
  return [
    for (final uri in _directiveUris(content))
      if (_isCleanupCoordinatorForbiddenTarget(_targetPath(path, uri)) ||
          uri.startsWith('package:flutter/'))
        GuardrailViolation(
          guardrailId: interactionCleanupCoordinatorDependencyBansGuardrailId,
          path: path,
          message:
              'cleanup coordinator may not depend on implementation owners or resolver contracts',
        ),
  ];
}

Future<List<GuardrailViolation>> checkInteractionReadPortImmutableFacts() {
  final file = File('$repositoryRoot/$_interactionReadPortPath');
  if (!file.existsSync()) {
    return Future.value([
      const GuardrailViolation(
        guardrailId: interactionReadPortImmutableFactsGuardrailId,
        path: _interactionReadPortPath,
        message: 'interaction read port source is missing',
      ),
    ]);
  }

  return Future.value(
    checkInteractionReadPortImmutableFactsSources({
      _interactionReadPortPath: file.readAsStringSync(),
    }),
  );
}

List<GuardrailViolation> checkInteractionReadPortImmutableFactsSources(
  Map<String, String> sources,
) {
  final source = sources[_interactionReadPortPath];
  if (source == null) {
    return const [
      GuardrailViolation(
        guardrailId: interactionReadPortImmutableFactsGuardrailId,
        path: _interactionReadPortPath,
        message: 'interaction read facts owner is missing',
      ),
    ];
  }

  final unit = _parseGuardrailUnit(source);
  final copiedFields = _readPortCopiedFields(unit);

  return [
    for (final field in copiedFields)
      if (!_hasMatchingListUnmodifiableInitializer(unit, field))
        GuardrailViolation(
          guardrailId: interactionReadPortImmutableFactsGuardrailId,
          path: _interactionReadPortPath,
          message:
              '${field.className}.${field.fieldName} must defensively copy caller-provided facts',
        ),
  ];
}

Iterable<String> _directiveUris(String content) sync* {
  final pattern = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  for (final match in pattern.allMatches(content)) {
    final uri = match.group(1);
    if (uri != null) {
      yield uri;
    }
  }
}

String? _targetPath(String sourcePath, String uri) {
  if (uri.startsWith('package:iwb_canvas_engine/')) {
    return uri.replaceFirst('package:iwb_canvas_engine/', '');
  }
  if (!uri.startsWith('.')) {
    return null;
  }

  final sourceSegments = sourcePath.split('/')..removeLast();
  for (final segment in uri.split('/')) {
    if (segment == '.' || segment.isEmpty) {
      continue;
    }
    if (segment == '..') {
      if (sourceSegments.isNotEmpty) {
        sourceSegments.removeLast();
      }
      continue;
    }
    sourceSegments.add(segment);
  }

  return sourceSegments.join('/');
}

bool _isInteractionStoreTarget(String? target) {
  return target != null && target.startsWith('lib/src/store/');
}

bool _isInteractionSelectionTarget(String? target) {
  return target != null && target.startsWith('lib/src/selection/');
}

bool _isInteractionOwnerTarget(String? target) {
  if (target == null) {
    return false;
  }

  return _isInteractionStoreTarget(target) ||
      _isInteractionSelectionTarget(target) ||
      target.startsWith('lib/src/resources/') ||
      target.startsWith('lib/src/frame/') ||
      target.startsWith('lib/src/runtime/') ||
      _isSurfaceAdapterTarget(target) ||
      target == 'lib/src/contracts/internal/command_facts_port.dart';
}

bool _isCleanupCoordinatorForbiddenTarget(String? target) {
  if (target == null) {
    return false;
  }

  return target.startsWith('lib/src/edit/') ||
      target == 'lib/src/contracts/internal/resolver_mutation_guard.dart' ||
      target == 'lib/src/contracts/public/canvas_actions.dart' ||
      target.startsWith('lib/src/frame/') ||
      _isSurfaceAdapterTarget(target) ||
      target.startsWith('lib/src/resources/') ||
      target.startsWith('lib/src/runtime/') ||
      target.startsWith('lib/src/store/') ||
      target.startsWith('lib/src/selection/');
}

bool _isSurfaceAdapterTarget(String target) {
  return target.startsWith('lib/src/surface/') ||
      target.startsWith('lib/src/flutter_bridge/');
}

CompilationUnit _parseGuardrailUnit(String content) {
  return parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
}

bool _hasMatchingListUnmodifiableInitializer(
  CompilationUnit unit,
  _ReadPortCopiedField field,
) {
  final visitor = _ConstructorCopyVisitor(field);
  unit.accept(visitor);

  return visitor.didCopyField;
}

bool _constructorCopiesField(
  ConstructorDeclaration constructor,
  _ReadPortCopiedField field,
) {
  for (final initializer in constructor.initializers) {
    if (initializer is! ConstructorFieldInitializer) {
      continue;
    }
    if (initializer.fieldName.name != field.fieldName) {
      continue;
    }
    if (_isMatchingListUnmodifiableCall(
      initializer.expression,
      field.sourceParameterName,
    )) {
      return true;
    }
  }

  return false;
}

bool _isMatchingListUnmodifiableCall(
  Expression expression,
  String sourceParameterName,
) {
  if (expression is! MethodInvocation ||
      expression.target is! SimpleIdentifier ||
      (expression.target as SimpleIdentifier).name != 'List' ||
      expression.methodName.name != 'unmodifiable') {
    return false;
  }
  final argument = expression.argumentList.arguments.singleOrNull;

  return argument is Expression &&
      _isSourceParameterExpression(argument, sourceParameterName);
}

bool _isSourceParameterExpression(Expression expression, String name) {
  if (expression is ParenthesizedExpression) {
    return _isSourceParameterExpression(expression.expression, name);
  }
  if (expression is AsExpression) {
    return _isSourceParameterExpression(expression.expression, name);
  }

  return expression is SimpleIdentifier && expression.name == name;
}

const _interactionReadPortPath =
    'lib/src/interaction/interaction_read_port.dart';
const _cleanupDependencyBanPaths = [
  'lib/src/interaction/pointer_tool_cleanup_coordinator.dart',
  'lib/src/interaction/pointer_cleanup_protocol.dart',
];

final class _ReadPortCopiedField {
  const _ReadPortCopiedField(
    this.className,
    this.constructorOffset,
    this.fieldName,
    this.sourceParameterName,
  );

  final String className;
  final int constructorOffset;
  final String fieldName;
  final String sourceParameterName;
}

List<_ReadPortCopiedField> _readPortCopiedFields(CompilationUnit unit) {
  return [
    for (final classDeclaration
        in unit.declarations.whereType<ClassDeclaration>())
      for (final constructor
          in classDeclaration.body.members.whereType<ConstructorDeclaration>())
        ..._constructorCopiedFields(classDeclaration, constructor),
  ];
}

Iterable<_ReadPortCopiedField> _constructorCopiedFields(
  ClassDeclaration classDeclaration,
  ConstructorDeclaration constructor,
) sync* {
  for (final initializer in constructor.initializers) {
    if (initializer is! ConstructorFieldInitializer) {
      continue;
    }
    final sourceParameterName = _fieldInitializerCopyParameterName(
      classDeclaration,
      constructor,
      initializer,
    );
    if (sourceParameterName != null) {
      yield _ReadPortCopiedField(
        classDeclaration.namePart.typeName.lexeme,
        constructor.offset,
        initializer.fieldName.name,
        sourceParameterName,
      );
    }
  }
  for (final parameter in constructor.parameters.parameters) {
    final fieldName = _fieldFormalParameterName(parameter);
    if (fieldName != null &&
        _fieldFormalNeedsImmutableCopy(classDeclaration, fieldName)) {
      yield _ReadPortCopiedField(
        classDeclaration.namePart.typeName.lexeme,
        constructor.offset,
        fieldName,
        fieldName,
      );
    }
  }
}

String? _fieldInitializerCopyParameterName(
  ClassDeclaration classDeclaration,
  ConstructorDeclaration constructor,
  ConstructorFieldInitializer initializer,
) {
  final fieldType = _fieldTypeSource(
    classDeclaration,
    initializer.fieldName.name,
  );

  if (!_isCollectionTypeSource(fieldType)) {
    return null;
  }

  return _constructorCollectionParameterForInitializer(
    constructor,
    initializer,
  );
}

bool _fieldFormalNeedsImmutableCopy(
  ClassDeclaration classDeclaration,
  String fieldName,
) {
  return _isCollectionTypeSource(_fieldTypeSource(classDeclaration, fieldName));
}

String? _fieldFormalParameterName(FormalParameter parameter) {
  final normalParameter = parameter is DefaultFormalParameter
      ? parameter.parameter
      : parameter;
  if (normalParameter is FieldFormalParameter) {
    return normalParameter.name.lexeme;
  }

  return null;
}

String? _fieldTypeSource(ClassDeclaration classDeclaration, String fieldName) {
  for (final member
      in classDeclaration.body.members.whereType<FieldDeclaration>()) {
    for (final variable in member.fields.variables) {
      if (variable.name.lexeme == fieldName) {
        return member.fields.type?.toSource();
      }
    }
  }

  return null;
}

String? _constructorCollectionParameterForInitializer(
  ConstructorDeclaration constructor,
  ConstructorFieldInitializer initializer,
) {
  for (final parameter in constructor.parameters.parameters) {
    final normalParameter = parameter is DefaultFormalParameter
        ? parameter.parameter
        : parameter;
    if (normalParameter is SimpleFormalParameter &&
        _isCollectionTypeSource(normalParameter.type?.toSource())) {
      final parameterName = normalParameter.name?.lexeme;
      if (parameterName != null &&
          (parameterName == initializer.fieldName.name ||
              _expressionMentionsIdentifier(
                initializer.expression,
                parameterName,
              ))) {
        return parameterName;
      }
    }
  }

  return null;
}

bool _isCollectionTypeSource(String? source) {
  if (source == null) {
    return false;
  }

  return source.startsWith('Iterable<') ||
      source.startsWith('List<') ||
      source.startsWith('Set<') ||
      source.startsWith('Map<');
}

bool _expressionMentionsIdentifier(Expression expression, String name) {
  final visitor = _IdentifierMentionVisitor(name);
  expression.accept(visitor);

  return visitor.didMentionIdentifier;
}

final class _IdentifierMentionVisitor extends RecursiveAstVisitor<void> {
  _IdentifierMentionVisitor(this.name);

  final String name;
  bool didMentionIdentifier = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name) {
      didMentionIdentifier = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

final class _ConstructorCopyVisitor extends RecursiveAstVisitor<void> {
  _ConstructorCopyVisitor(this.field);

  final _ReadPortCopiedField field;
  bool didCopyField = false;
  final List<String> _classStack = [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _classStack.add(node.namePart.typeName.lexeme);
    super.visitClassDeclaration(node);
    _classStack.removeLast();
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (_classStack.lastOrNull == field.className &&
        node.offset == field.constructorOffset &&
        _constructorCopiesField(node, field)) {
      didCopyField = true;
    }
    super.visitConstructorDeclaration(node);
  }
}
