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
  final body = _methodBody(source, 'commitTextEdit');
  if (body == null) {
    return const [
      GuardrailViolation(
        guardrailId: interactionTextEditStaleCommitGuardrailId,
        path: _runtimeRootPath,
        message: 'commitTextEdit method is missing',
      ),
    ];
  }

  return _textEditGuardViolations(body);
}

List<GuardrailViolation> _textEditGuardViolations(String body) {
  final markers = _TextEditGuardMarkers.fromBody(body);

  return [
    _validationBeforeGuardViolation(markers),
    _guardBeforePrepareViolation(markers),
    _guardAcceptedGateViolation(markers),
    _guardFactsFeedCommitViolation(markers),
    _retireBeforeDeliveryViolation(markers),
    _hardcodedAcceptedDecisionViolation(body),
  ].nonNulls.toList();
}

GuardrailViolation? _validationBeforeGuardViolation(
  _TextEditGuardMarkers markers,
) {
  return markers.validationBeforeGuard
      ? null
      : _textEditGuardViolation('text validation must precede guard');
}

GuardrailViolation? _guardBeforePrepareViolation(
  _TextEditGuardMarkers markers,
) {
  return markers.guardBeforePrepare
      ? null
      : _textEditGuardViolation('interaction guard must precede edit commit');
}

GuardrailViolation? _guardAcceptedGateViolation(_TextEditGuardMarkers markers) {
  return markers.acceptedGateBeforePrepare
      ? null
      : _textEditGuardViolation(
          'commit path must be controlled by the interaction guard decision',
        );
}

GuardrailViolation? _guardFactsFeedCommitViolation(
  _TextEditGuardMarkers markers,
) {
  return markers.guardFactsFeedCommit
      ? null
      : _textEditGuardViolation(
          'edit commit facts must come from the interaction guard decision',
        );
}

GuardrailViolation? _retireBeforeDeliveryViolation(
  _TextEditGuardMarkers markers,
) {
  return markers.retireAfterPrepareBeforeDelivery
      ? null
      : _textEditGuardViolation(
          'accepted changed text request must retire after install and before delivery',
        );
}

GuardrailViolation? _hardcodedAcceptedDecisionViolation(String body) {
  return body.contains('TextEditGuardDecision.accepted(')
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
const _runtimeRootPath = 'lib/src/runtime/runtime_root.dart';

String? _methodBody(String source, String methodName) {
  final match = RegExp('\\b$methodName\\s*\\(').firstMatch(source);
  if (match == null) {
    return null;
  }
  final parameterStart = source.indexOf('(', match.start);
  final parameterEnd = _balancedParameterEnd(source, parameterStart);
  if (parameterEnd == null) {
    return null;
  }
  final bodyStart = source.indexOf('{', parameterEnd);
  if (bodyStart < 0) {
    return null;
  }

  var depth = 0;
  for (var index = bodyStart; index < source.length; index += 1) {
    final char = source.codeUnitAt(index);
    if (char == 0x7B) {
      depth += 1;
    } else if (char == 0x7D) {
      depth -= 1;
      if (depth == 0) {
        return source.substring(bodyStart, index + 1);
      }
    }
  }

  return null;
}

int? _balancedParameterEnd(String source, int start) {
  if (start < 0) {
    return null;
  }

  var depth = 0;
  for (var index = start; index < source.length; index += 1) {
    final char = source.codeUnitAt(index);
    if (char == 0x28) {
      depth += 1;
    } else if (char == 0x29) {
      depth -= 1;
      if (depth == 0) {
        return index;
      }
    }
  }

  return null;
}

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

final class _TextEditGuardMarkers {
  const _TextEditGuardMarkers({
    required this.validation,
    required this.guard,
    required this.acceptedGate,
    required this.targetRead,
    required this.currentTextRead,
    required this.prepare,
    required this.retire,
    required this.deliver,
  });

  factory _TextEditGuardMarkers.fromBody(String body) {
    final guardName = _guardDecisionVariableName(body);

    return _TextEditGuardMarkers(
      validation: body.indexOf('_validateTextEditCommandInput'),
      guard: body.indexOf('_interactionEngine.textEditGuardDecision'),
      acceptedGate: _guardAcceptedGateIndex(body, guardName),
      targetRead: _guardFactReadIndex(body, guardName, 'targetElementId'),
      currentTextRead: _guardFactReadIndex(body, guardName, 'currentText'),
      prepare: body.indexOf('_editKernel.prepareInteractionCommit'),
      retire: body.lastIndexOf('_interactionEngine.retireTextEditRequest'),
      deliver: body.indexOf('_deliverEditCommitResult'),
    );
  }

  final int validation;
  final int guard;
  final int acceptedGate;
  final int targetRead;
  final int currentTextRead;
  final int prepare;
  final int retire;
  final int deliver;

  bool get validationBeforeGuard {
    return validation >= 0 && guard >= 0 && validation < guard;
  }

  bool get guardBeforePrepare {
    return guard >= 0 && prepare >= 0 && guard < prepare;
  }

  bool get acceptedGateBeforePrepare {
    return acceptedGate > guard && prepare >= 0 && acceptedGate < prepare;
  }

  bool get guardFactsFeedCommit {
    return targetRead > acceptedGate &&
        currentTextRead > acceptedGate &&
        prepare >= 0 &&
        targetRead < prepare &&
        currentTextRead < prepare;
  }

  bool get retireAfterPrepareBeforeDelivery {
    return prepare >= 0 && retire > prepare && deliver >= 0 && retire < deliver;
  }
}

String? _guardDecisionVariableName(String body) {
  return RegExp(
    r'(?:final|var)\s+(\w+)\s*=\s*_interactionEngine\.textEditGuardDecision\s*\(\s*requestId\s*\)\s*;',
  ).firstMatch(body)?.group(1);
}

int _guardAcceptedGateIndex(String body, String? guardName) {
  if (guardName == null) {
    return -1;
  }

  return body.indexOf('$guardName.kind != TextEditGuardDecisionKind.accepted');
}

int _guardFactReadIndex(String body, String? guardName, String factName) {
  if (guardName == null) {
    return -1;
  }

  return body.indexOf('$guardName.$factName');
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
