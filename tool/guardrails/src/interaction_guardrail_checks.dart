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
  final file = File(
    '$repositoryRoot/lib/src/interaction/pointer_tool_cleanup_coordinator.dart',
  );
  if (!file.existsSync()) {
    return const [
      GuardrailViolation(
        guardrailId: interactionCleanupCoordinatorDependencyBansGuardrailId,
        path: 'lib/src/interaction/pointer_tool_cleanup_coordinator.dart',
        message: 'cleanup coordinator source is missing',
      ),
    ];
  }

  return checkCleanupCoordinatorDependencyFile(
    path: 'lib/src/interaction/pointer_tool_cleanup_coordinator.dart',
    content: file.readAsStringSync(),
  );
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

  return [
    for (final field in _readPortCopiedFields)
      if (!_hasListUnmodifiableInitializer(unit, field))
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

bool _hasListUnmodifiableInitializer(
  CompilationUnit unit,
  _ReadPortCopiedField field,
) {
  final visitor = _ConstructorCopyVisitor(field);
  unit.accept(visitor);

  return visitor.didCopyField;
}

bool _constructorCopiesField(ConstructorDeclaration constructor, String field) {
  for (final initializer in constructor.initializers) {
    if (initializer is! ConstructorFieldInitializer) {
      continue;
    }
    if (initializer.fieldName.name != field) {
      continue;
    }
    if (_isListUnmodifiableCall(initializer.expression)) {
      return true;
    }
  }

  return false;
}

bool _isListUnmodifiableCall(Expression expression) {
  return expression is MethodInvocation &&
      expression.target is SimpleIdentifier &&
      (expression.target as SimpleIdentifier).name == 'List' &&
      expression.methodName.name == 'unmodifiable';
}

const _interactionReadPortPath =
    'lib/src/interaction/interaction_read_port.dart';

const _readPortCopiedFields = [
  _ReadPortCopiedField('SelectedMoveStartFacts', 'selectedIds'),
  _ReadPortCopiedField('SelectedMoveStartFacts', 'movableSelectedIds'),
  _ReadPortCopiedField('SelectedMoveCommitReadRequest', 'sessionSelectedIds'),
  _ReadPortCopiedField('SelectedMoveCommitReadRequest', 'sessionMovableIds'),
  _ReadPortCopiedField('SelectedMoveCommitFacts', 'movableIds'),
  _ReadPortCopiedField('SelectedMoveCommitFacts', 'movedElements'),
  _ReadPortCopiedField('SelectedMoveCommitFacts', '_skippedSessionIds'),
  _ReadPortCopiedField('MarqueeStartFacts', 'previousSelectedIds'),
  _ReadPortCopiedField('MarqueeCommitFacts', 'previousSelectedIds'),
  _ReadPortCopiedField('MarqueeCommitFacts', 'nextSelectedIds'),
];

final class _ReadPortCopiedField {
  const _ReadPortCopiedField(this.className, this.fieldName);

  final String className;
  final String fieldName;
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
        _constructorCopiesField(node, field.fieldName)) {
      didCopyField = true;
    }
    super.visitConstructorDeclaration(node);
  }
}
