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
const interactionTextEditStaleCommitGuardrailId =
    'interaction.text_edit_stale_commit_guard';

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

Future<List<GuardrailViolation>> checkTextEditStaleCommitGuard() {
  final file = File('$repositoryRoot/$_runtimeRootPath');
  if (!file.existsSync()) {
    return Future.value([
      const GuardrailViolation(
        guardrailId: interactionTextEditStaleCommitGuardrailId,
        path: _runtimeRootPath,
        message: 'runtime text edit command owner is missing',
      ),
    ]);
  }

  return Future.value(
    checkTextEditStaleCommitGuardSources({
      _runtimeRootPath: file.readAsStringSync(),
    }),
  );
}

List<GuardrailViolation> checkTextEditStaleCommitGuardSources(
  Map<String, String> sources,
) {
  final source = sources[_runtimeRootPath];
  if (source == null) {
    return const [
      GuardrailViolation(
        guardrailId: interactionTextEditStaleCommitGuardrailId,
        path: _runtimeRootPath,
        message: 'runtime text edit command owner is missing',
      ),
    ];
  }
  final method = _methodDeclaration(source, 'commitTextEdit');
  if (method == null) {
    return const [
      GuardrailViolation(
        guardrailId: interactionTextEditStaleCommitGuardrailId,
        path: _runtimeRootPath,
        message: 'commitTextEdit method is missing',
      ),
    ];
  }

  return _textEditGuardViolations(method);
}

List<GuardrailViolation> _textEditGuardViolations(MethodDeclaration method) {
  final shape = _TextEditCommitShape.fromMethod(method);

  return [
    _validationBeforeGuardViolation(shape),
    _guardBeforePrepareViolation(shape),
    _guardAcceptedGateViolation(shape),
    _guardFactsFeedCommitViolation(shape),
    _consumeBeforeDeliveryViolation(shape),
    _hardcodedAcceptedDecisionViolation(shape),
  ].nonNulls.toList();
}

GuardrailViolation? _validationBeforeGuardViolation(
  _TextEditCommitShape shape,
) {
  return shape.validationBeforeGuard
      ? null
      : _textEditGuardViolation('text validation must precede guard');
}

GuardrailViolation? _guardBeforePrepareViolation(_TextEditCommitShape shape) {
  return shape.guardBeforePrepare
      ? null
      : _textEditGuardViolation('interaction guard must precede edit commit');
}

GuardrailViolation? _guardAcceptedGateViolation(_TextEditCommitShape shape) {
  return shape.acceptedGateControlsPrepare
      ? null
      : _textEditGuardViolation(
          'commit path must be controlled by the interaction guard decision',
        );
}

GuardrailViolation? _guardFactsFeedCommitViolation(_TextEditCommitShape shape) {
  return shape.guardFactsFeedCommit
      ? null
      : _textEditGuardViolation(
          'edit commit facts must come from the interaction guard decision',
        );
}

GuardrailViolation? _consumeBeforeDeliveryViolation(
  _TextEditCommitShape shape,
) {
  return shape.changedTextConsumesAfterSuccessfulPrepareBeforeDelivery
      ? null
      : _textEditGuardViolation(
          'accepted changed text request must consume after prepare success and before delivery',
        );
}

GuardrailViolation? _hardcodedAcceptedDecisionViolation(
  _TextEditCommitShape shape,
) {
  return shape.synthesizesAcceptedDecision
      ? _textEditGuardViolation(
          'commitTextEdit must not synthesize accepted text guard decisions',
        )
      : null;
}

GuardrailViolation _textEditGuardViolation(String message) {
  return GuardrailViolation(
    guardrailId: interactionTextEditStaleCommitGuardrailId,
    path: _runtimeRootPath,
    message: message,
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
    return uri.substring('package:iwb_canvas_engine/'.length);
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
      target.startsWith('lib/src/flutter_bridge/') ||
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
      target.startsWith('lib/src/flutter_bridge/') ||
      target.startsWith('lib/src/resources/') ||
      target.startsWith('lib/src/runtime/') ||
      target.startsWith('lib/src/store/') ||
      target.startsWith('lib/src/selection/');
}

CompilationUnit _parseGuardrailUnit(String content) {
  return parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
}

MethodDeclaration? _methodDeclaration(String source, String methodName) {
  final unit = _parseGuardrailUnit(source);
  final visitor = _MethodDeclarationFinder(methodName);
  unit.accept(visitor);

  return visitor.method;
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
const _runtimeRootPath = 'lib/src/runtime/runtime_root.dart';
const _cleanupDependencyBanPaths = [
  'lib/src/interaction/pointer_tool_cleanup_coordinator.dart',
  'lib/src/interaction/pointer_cleanup_protocol.dart',
];

final class _ReadPortCopiedField {
  const _ReadPortCopiedField(
    this.className,
    this.fieldName,
    this.sourceParameterName,
  );

  final String className;
  final String fieldName;
  final String sourceParameterName;
}

final class _MethodDeclarationFinder extends RecursiveAstVisitor<void> {
  _MethodDeclarationFinder(this.methodName);

  final String methodName;
  MethodDeclaration? method;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (method == null && node.name.lexeme == methodName) {
      method = node;
      return;
    }
    super.visitMethodDeclaration(node);
  }
}

final class _TextEditCommitShape {
  _TextEditCommitShape.fromMethod(MethodDeclaration method) {
    method.accept(_TextEditCommitVisitor(this));

    final body = method.body;
    if (body is BlockFunctionBody) {
      _readTextEditTopLevelShape(this, body.block);
    }
  }

  int validationOffset = -1;
  int guardOffset = -1;
  String? guardName;
  String? targetElementIdLocalName;
  String? currentTextLocalName;
  int acceptedGateEnd = -1;
  int targetReadOffset = -1;
  int currentTextReadOffset = -1;
  int targetElementIdLocalWriteOffset = -1;
  int currentTextLocalWriteOffset = -1;
  int prepareOffset = -1;
  bool prepareUsesGuardFacts = false;
  int prepareSuccessGateEnd = -1;
  int changedConsumeOffset = -1;
  int deliverOffset = -1;
  bool synthesizesAcceptedDecision = false;
  bool rejectedBranchReachesPrepare = false;
  bool sameTextBranchReachesPrepare = false;
  bool failedPrepareBranchConsumesOrDelivers = false;
  bool changedPathConsumesBeforePrepareSuccess = false;

  bool get validationBeforeGuard {
    return validationOffset >= 0 &&
        guardOffset >= 0 &&
        validationOffset < guardOffset;
  }

  bool get guardBeforePrepare {
    return guardOffset >= 0 &&
        prepareOffset >= 0 &&
        guardOffset < prepareOffset;
  }

  bool get acceptedGateControlsPrepare {
    return acceptedGateEnd > guardOffset &&
        prepareOffset >= 0 &&
        acceptedGateEnd < prepareOffset &&
        !rejectedBranchReachesPrepare &&
        !sameTextBranchReachesPrepare;
  }

  bool get guardFactsFeedCommit {
    return targetReadOffset > acceptedGateEnd &&
        currentTextReadOffset > acceptedGateEnd &&
        prepareOffset >= 0 &&
        targetReadOffset < prepareOffset &&
        currentTextReadOffset < prepareOffset &&
        !_guardLocalWriteBeforePrepare(
          targetElementIdLocalWriteOffset,
          prepareOffset,
        ) &&
        !_guardLocalWriteBeforePrepare(
          currentTextLocalWriteOffset,
          prepareOffset,
        ) &&
        prepareUsesGuardFacts;
  }

  bool get changedTextConsumesAfterSuccessfulPrepareBeforeDelivery {
    return prepareOffset >= 0 &&
        prepareSuccessGateEnd > prepareOffset &&
        changedConsumeOffset > prepareSuccessGateEnd &&
        deliverOffset > changedConsumeOffset &&
        !failedPrepareBranchConsumesOrDelivers &&
        !changedPathConsumesBeforePrepareSuccess;
  }
}

bool _guardLocalWriteBeforePrepare(int writeOffset, int prepareOffset) {
  return writeOffset >= 0 && prepareOffset >= 0 && writeOffset < prepareOffset;
}

void _readTextEditTopLevelShape(_TextEditCommitShape shape, Block block) {
  final guardReject = _guardRejectStatement(block);
  if (guardReject != null) {
    shape.acceptedGateEnd = guardReject.end;
    shape.rejectedBranchReachesPrepare = _containsPrepare(
      guardReject.thenStatement,
    );
  }

  final sameTextBranch = _sameTextStatement(block);
  if (sameTextBranch != null) {
    shape.sameTextBranchReachesPrepare = _containsPrepare(
      sameTextBranch.thenStatement,
    );
  }

  final prepareStatement = _firstPrepareStatement(block);
  if (prepareStatement != null) {
    shape.prepareOffset = _firstPrepareOffset(prepareStatement);
  }

  final failureGate = _prepareFailureStatement(block);
  if (failureGate != null) {
    shape.prepareSuccessGateEnd = failureGate.end;
    shape.failedPrepareBranchConsumesOrDelivers =
        _containsConsume(failureGate.thenStatement) ||
        _containsDelivery(failureGate.thenStatement);
  }

  _readChangedPathDelivery(shape, block, sameTextBranch?.thenStatement);
}

void _readChangedPathDelivery(
  _TextEditCommitShape shape,
  Block block,
  Statement? sameTextBody,
) {
  final consumeNodes = _methodInvocationsWhere(
    block,
    (node) => _isInteractionEngineInvocation(node, 'consumeTextEditRequest'),
  );
  for (final node in consumeNodes) {
    if (_nodeWithin(node, sameTextBody)) {
      continue;
    }
    if (node.offset < shape.prepareSuccessGateEnd) {
      shape.changedPathConsumesBeforePrepareSuccess = true;
      continue;
    }
    shape.changedConsumeOffset = node.offset;
    break;
  }

  shape.deliverOffset =
      _methodInvocationsWhere(
        block,
        _isDeliverEditCommitResultInvocation,
      ).firstOrNull?.offset ??
      -1;
}

// This visitor records one semantic event stream from commitTextEdit's AST.
// Splitting by AST node type would scatter the ordering proof across visitors.
// ignore: coupling-between-object-classes, weighted-methods-per-class
final class _TextEditCommitVisitor extends RecursiveAstVisitor<void> {
  _TextEditCommitVisitor(this.shape);

  final _TextEditCommitShape shape;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (initializer is MethodInvocation &&
        _isInteractionEngineInvocation(initializer, 'textEditGuardDecision')) {
      shape.guardName = node.name.lexeme;
      shape.guardOffset = initializer.offset;
    }
    if (_isGuardFactRead(initializer, 'targetElementId')) {
      shape.targetElementIdLocalName = node.name.lexeme;
    }
    if (_isGuardFactRead(initializer, 'currentText')) {
      shape.currentTextLocalName = node.name.lexeme;
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isUnqualifiedInvocation(node, '_validateTextEditCommandInput') &&
        shape.validationOffset < 0) {
      shape.validationOffset = node.offset;
    }
    if (_isPrepareInvocation(node) && _prepareUsesGuardFacts(node, shape)) {
      shape.prepareUsesGuardFacts = true;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructorName = node.constructorName;
    if (constructorName.type.name.lexeme == 'TextEditGuardDecision' &&
        constructorName.name?.name == 'accepted') {
      shape.synthesizesAcceptedDecision = true;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final leftHandSide = node.leftHandSide;
    if (leftHandSide is SimpleIdentifier) {
      _recordGuardLocalWrite(leftHandSide.name, node.offset);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _recordGuardFactRead(node.prefix.name, node.identifier.name, node.offset);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target is SimpleIdentifier) {
      _recordGuardFactRead(target.name, node.propertyName.name, node.offset);
    }
    super.visitPropertyAccess(node);
  }

  void _recordGuardFactRead(
    String targetName,
    String propertyName,
    int offset,
  ) {
    if (targetName != shape.guardName) {
      return;
    }
    if (propertyName == 'targetElementId' && shape.targetReadOffset < 0) {
      shape.targetReadOffset = offset;
    }
    if (propertyName == 'currentText' && shape.currentTextReadOffset < 0) {
      shape.currentTextReadOffset = offset;
    }
  }

  void _recordGuardLocalWrite(String name, int offset) {
    if (name == shape.targetElementIdLocalName &&
        offset > shape.targetReadOffset &&
        shape.targetElementIdLocalWriteOffset < 0) {
      shape.targetElementIdLocalWriteOffset = offset;
    }
    if (name == shape.currentTextLocalName &&
        offset > shape.currentTextReadOffset &&
        shape.currentTextLocalWriteOffset < 0) {
      shape.currentTextLocalWriteOffset = offset;
    }
  }

  bool _isGuardFactRead(Expression? expression, String propertyName) {
    if (expression is AsExpression) {
      return _isGuardFactRead(expression.expression, propertyName);
    }
    final guardName = shape.guardName;
    if (guardName == null || expression == null) {
      return false;
    }

    return _isPropertyRead(expression, guardName, propertyName);
  }
}

bool _prepareUsesGuardFacts(
  MethodInvocation invocation,
  _TextEditCommitShape shape,
) {
  final targetLocal = shape.targetElementIdLocalName;
  final textLocal = shape.currentTextLocalName;
  if (targetLocal == null || textLocal == null) {
    return false;
  }
  final fields = _prepareRecordFields(invocation);

  return fields['targetElementId'] == targetLocal &&
      fields['previousText'] == textLocal;
}

Map<String, String> _prepareRecordFields(MethodInvocation invocation) {
  final firstArgument = invocation.argumentList.arguments.firstOrNull;
  if (firstArgument is! RecordLiteral) {
    return const {};
  }

  return {
    for (final field in firstArgument.fields)
      if (field is NamedExpression)
        field.name.label.name: field.expression.toSource(),
  };
}

IfStatement? _guardRejectStatement(Block block) {
  final guardName = _guardName(block);

  return _firstWhereOrNull(
    block.statements.whereType<IfStatement>(),
    (statement) =>
        _isAcceptedGuardRejectCondition(statement.expression, guardName),
  );
}

String? _guardName(Block block) {
  for (final statement
      in block.statements.whereType<VariableDeclarationStatement>()) {
    for (final variable in statement.variables.variables) {
      final initializer = variable.initializer;
      if (initializer is MethodInvocation &&
          _isInteractionEngineInvocation(
            initializer,
            'textEditGuardDecision',
          )) {
        return variable.name.lexeme;
      }
    }
  }

  return null;
}

bool _isAcceptedGuardRejectCondition(Expression expression, String? guardName) {
  if (guardName == null || expression is! BinaryExpression) {
    return false;
  }

  return expression.operator.lexeme == '!=' &&
      _isPropertyRead(expression.leftOperand, guardName, 'kind') &&
      expression.rightOperand.toSource() ==
          'TextEditGuardDecisionKind.accepted';
}

IfStatement? _sameTextStatement(Block block) {
  return _firstWhereOrNull(
    block.statements.whereType<IfStatement>(),
    (statement) =>
        statement.expression is BinaryExpression &&
        (statement.expression as BinaryExpression).operator.lexeme == '==' &&
        statement.expression.toSource().contains('previousText') &&
        statement.expression.toSource().contains('newText'),
  );
}

Statement? _firstPrepareStatement(Block block) {
  return _firstWhereOrNull(block.statements, _containsPrepare);
}

int _firstPrepareOffset(AstNode node) {
  return _methodInvocationsWhere(
        node,
        _isPrepareInvocation,
      ).firstOrNull?.offset ??
      -1;
}

IfStatement? _prepareFailureStatement(Block block) {
  return _firstWhereOrNull(
    block.statements.whereType<IfStatement>(),
    (statement) =>
        statement.expression is PrefixExpression &&
        statement.expression.toSource() == '!applyResult.shouldPublishState',
  );
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) {
      return value;
    }
  }

  return null;
}

bool _containsPrepare(AstNode node) {
  return _methodInvocationsWhere(node, _isPrepareInvocation).isNotEmpty;
}

bool _containsConsume(AstNode node) {
  return _methodInvocationsWhere(
    node,
    (invocation) =>
        _isInteractionEngineInvocation(invocation, 'consumeTextEditRequest'),
  ).isNotEmpty;
}

bool _containsDelivery(AstNode node) {
  return _methodInvocationsWhere(
    node,
    _isDeliverEditCommitResultInvocation,
  ).isNotEmpty;
}

bool _isPrepareInvocation(MethodInvocation node) {
  return _isUnqualifiedInvocation(node, '_prepareTextEditCommit') ||
      _isEditKernelInvocation(node, 'prepareInteractionCommit');
}

bool _isDeliverEditCommitResultInvocation(MethodInvocation node) {
  return _isUnqualifiedInvocation(node, '_deliverEditCommitResult');
}

bool _isInteractionEngineInvocation(MethodInvocation node, String methodName) {
  if (!_isTargetInvocation(node, '_interactionEngine', methodName)) {
    return false;
  }

  return switch (methodName) {
    'textEditGuardDecision' ||
    'consumeTextEditRequest' => _hasSingleRequestIdArgument(node),
    _ => true,
  };
}

bool _hasSingleRequestIdArgument(MethodInvocation node) {
  final arguments = node.argumentList.arguments;

  return arguments.length == 1 && arguments.single.toSource() == 'requestId';
}

bool _isEditKernelInvocation(MethodInvocation node, String methodName) {
  return _isTargetInvocation(node, '_editKernel', methodName);
}

bool _isTargetInvocation(
  MethodInvocation node,
  String targetName,
  String methodName,
) {
  final target = node.target;

  return target is SimpleIdentifier &&
      target.name == targetName &&
      node.methodName.name == methodName;
}

bool _isUnqualifiedInvocation(MethodInvocation node, String methodName) {
  return node.target == null && node.methodName.name == methodName;
}

bool _isPropertyRead(
  Expression expression,
  String targetName,
  String property,
) {
  if (expression is PrefixedIdentifier) {
    return expression.prefix.name == targetName &&
        expression.identifier.name == property;
  }
  if (expression is PropertyAccess && expression.target is SimpleIdentifier) {
    return (expression.target as SimpleIdentifier).name == targetName &&
        expression.propertyName.name == property;
  }

  return false;
}

List<MethodInvocation> _methodInvocationsWhere(
  AstNode node,
  bool Function(MethodInvocation node) test,
) {
  final visitor = _MethodInvocationCollector(test);
  node.accept(visitor);

  return visitor.invocations;
}

final class _MethodInvocationCollector extends RecursiveAstVisitor<void> {
  _MethodInvocationCollector(this.test);

  final bool Function(MethodInvocation node) test;
  final List<MethodInvocation> invocations = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (test(node)) {
      invocations.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

bool _nodeWithin(AstNode node, AstNode? owner) {
  return owner != null && node.offset >= owner.offset && node.end <= owner.end;
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
        _constructorCopiesField(node, field)) {
      didCopyField = true;
    }
    super.visitConstructorDeclaration(node);
  }
}
