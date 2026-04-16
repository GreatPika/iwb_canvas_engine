import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../support/guardrail_ast_utils.dart';
import '../../support/guardrail_context.dart';
import '../../support/guardrail_path_utils.dart';
import '../controller/committed_read_side_rules.dart';
import '../../core/guardrail_violation.dart';
import 'committed_read_callback_rules.dart';
import 'resolver_purity_rules.dart';

part 'boundary_shape_token_rules.dart';

Future<List<GuardrailViolation>> runInteractiveApiGuardrails({
  required GuardrailContext context,
}) async {
  final violations = <GuardrailViolation>[];
  final file = _interactiveFile(context);
  if (!file.existsSync()) {
    return violations;
  }

  final filePosixPath = _interactiveFilePosixPath(context, file);
  final parsed = _parseInteractiveFile(context, file, filePosixPath);
  final interactiveClass = _findInteractiveClass(parsed.unit.declarations);
  if (interactiveClass == null) {
    return violations;
  }

  final rootViolation = _checkRootEntrypoints(
    interactiveClass,
    filePath: filePosixPath,
    lineFor: (offset) => lineForOffset(parsed, offset),
  );
  if (rootViolation != null) {
    violations.add(rootViolation);
    return violations;
  }

  final capabilityViolation = _checkCapabilityEntrypoints(context);
  if (capabilityViolation != null) {
    violations.add(capabilityViolation);
    return violations;
  }

  final mutationOwnerViolation = _checkMutationOwnerPolicies(context);
  if (mutationOwnerViolation != null) {
    violations.add(mutationOwnerViolation);
    return violations;
  }

  final committedReadSideViolation =
      await _checkCommittedReadSideCallbackHermeticity(context);
  if (committedReadSideViolation != null) {
    violations.add(committedReadSideViolation);
    return violations;
  }

  final boundaryViolation = _checkInteractiveBoundaryShape(context);
  if (boundaryViolation != null) {
    violations.add(boundaryViolation);
  }
  return violations;
}

File _interactiveFile(GuardrailContext context) {
  return File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}interactive${Platform.pathSeparator}'
    'scene_controller.dart',
  );
}

String _interactiveFilePosixPath(GuardrailContext context, File file) {
  return toRepoRelPosixPath(
    absPosixPath: toPosixPath(file.absolute.path),
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
}

ParsedUnitResult _parseInteractiveFile(
  GuardrailContext context,
  File file,
  String filePosixPath,
) {
  return parseUnitOrFail(
    context: context,
    absPath: file.absolute.path,
    filePathForDiag: filePosixPath,
    onFailure: _onInteractiveParseFailure,
  );
}

ClassDeclaration? _findInteractiveClass(
  NodeList<CompilationUnitMember> declarations,
) {
  for (final declaration in declarations) {
    if (declaration is ClassDeclaration &&
        declaration.name.lexeme == 'SceneController') {
      return declaration;
    }
  }
  return null;
}

class EnsureCallInfo {
  const EnsureCallInfo({required this.hasAllowAfterDispose});

  final bool hasAllowAfterDispose;
}

class InteractiveGuardContext {
  const InteractiveGuardContext({
    required this.firstStatement,
    required this.expressionStatement,
  });

  final Statement firstStatement;
  final ExpressionStatement expressionStatement;
}

String? _publicEntrypointName(ClassMember member) {
  if (member is! MethodDeclaration) {
    return null;
  }
  if (member.isStatic || member.isGetter) {
    return null;
  }
  final name = member.name.lexeme;
  if (!isPublicName(name) || name == 'SceneController') {
    return null;
  }
  if (name == 'addListener' || name == 'removeListener') {
    return null;
  }
  return name;
}

GuardrailViolation? _checkRootEntrypoints(
  ClassDeclaration interactiveClass, {
  required String filePath,
  required int Function(int offset) lineFor,
}) {
  for (final member in interactiveClass.members) {
    final name = _publicEntrypointName(member);
    if (name == null) {
      continue;
    }
    final violation = _checkInteractiveEntrypointGuard(
      member: member as MethodDeclaration,
      name: name,
      filePath: filePath,
      lineFor: lineFor,
    );
    if (violation != null) {
      return violation;
    }
  }
  return null;
}

GuardrailViolation? _checkInteractiveEntrypointGuard({
  required MethodDeclaration member,
  required String name,
  required String filePath,
  required int Function(int offset) lineFor,
}) {
  final guardContext = _interactiveGuardContext(
    member: member,
    filePath: filePath,
    lineFor: lineFor,
  );
  final violation = _guardContextViolation(guardContext);
  if (violation != null) {
    return violation;
  }
  if (guardContext is! InteractiveGuardContext) {
    return null;
  }

  final ensureCallInfo = _ensureCallInfoFromExpression(
    guardContext.expressionStatement.expression,
  );
  return _validateEnsureCall(
    ensureCallInfo: ensureCallInfo,
    name: name,
    filePath: filePath,
    line: lineFor(guardContext.firstStatement.offset),
  );
}

Object? _interactiveGuardContext({
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
}) {
  final body = member.body;
  if (body is! BlockFunctionBody) {
    return _GuardViolation(
      GuardrailViolation(
        filePath: filePath,
        line: lineFor(member.offset),
        message:
            'interactive API violation: public SceneController '
            'entrypoint "${member.name.lexeme}" must use a block body guarded '
            'by _ensurePublicSideEffectAllowed(...).',
      ),
    );
  }
  final statements = body.block.statements;
  if (statements.isEmpty) {
    return _GuardViolation(
      _interactiveGuardViolation(
        filePath: filePath,
        line: lineFor(member.offset),
      ),
    );
  }
  final firstStatement = statements.first;
  if (firstStatement is! ExpressionStatement) {
    return _GuardViolation(
      _interactiveGuardViolation(
        filePath: filePath,
        line: lineFor(firstStatement.offset),
      ),
    );
  }
  return InteractiveGuardContext(
    firstStatement: firstStatement,
    expressionStatement: firstStatement,
  );
}

EnsureCallInfo? _ensureCallInfoFromExpression(Expression expression) {
  if (expression is! MethodInvocation) {
    return null;
  }
  if (expression.target != null) {
    return null;
  }
  if (expression.methodName.name != '_ensurePublicSideEffectAllowed') {
    return null;
  }

  var hasAllowAfterDispose = false;
  for (final argument in expression.argumentList.arguments) {
    if (argument is! NamedExpression) {
      continue;
    }
    if (argument.name.label.name != 'allowAfterDispose') {
      continue;
    }
    final value = argument.expression;
    if (value is BooleanLiteral && value.value) {
      hasAllowAfterDispose = true;
    }
  }
  return EnsureCallInfo(hasAllowAfterDispose: hasAllowAfterDispose);
}

GuardrailViolation _interactiveGuardViolation({
  required String filePath,
  required int line,
}) {
  return GuardrailViolation(
    filePath: filePath,
    line: line,
    message:
        'interactive API violation: public SceneController '
        'entrypoints must guard resolver purity with '
        '_ensurePublicSideEffectAllowed(...).',
  );
}

class _GuardViolation {
  const _GuardViolation(this.violation);

  final GuardrailViolation violation;
}

GuardrailViolation? _guardContextViolation(Object? guardContext) {
  if (guardContext case _GuardViolation(:final violation)) {
    return violation;
  }
  return null;
}

GuardrailViolation? _validateEnsureCall({
  required EnsureCallInfo? ensureCallInfo,
  required String name,
  required String filePath,
  required int line,
}) {
  if (ensureCallInfo == null) {
    return _interactiveGuardViolation(filePath: filePath, line: line);
  }
  if (name == 'dispose') {
    return ensureCallInfo.hasAllowAfterDispose
        ? null
        : GuardrailViolation(
            filePath: filePath,
            line: line,
            message:
                'interactive API violation: dispose() must guard resolver '
                'purity with allowAfterDispose: true.',
          );
  }
  return ensureCallInfo.hasAllowAfterDispose
      ? GuardrailViolation(
          filePath: filePath,
          line: line,
          message:
              'interactive API violation: only dispose() may call '
              '_ensurePublicSideEffectAllowed(..., allowAfterDispose: true).',
        )
      : null;
}

final class CapabilityGuardSpec {
  const CapabilityGuardSpec({
    required this.relativePath,
    required this.className,
    required this.primaryGuardCall,
    this.secondaryGuardCallsByMethod = const <String, String>{},
  });

  final String relativePath;
  final String className;
  final String primaryGuardCall;
  final Map<String, String> secondaryGuardCallsByMethod;
}

const List<CapabilityGuardSpec> _capabilityGuardSpecs = <CapabilityGuardSpec>[
  CapabilityGuardSpec(
    relativePath: 'scene_controller_interaction.dart',
    className: 'SceneControllerInteractionOwner',
    primaryGuardCall: '_access.runtime.ensurePublicSideEffectAllowed',
  ),
  CapabilityGuardSpec(
    relativePath: 'scene_controller_scene.dart',
    className: 'SceneControllerSceneOwner',
    primaryGuardCall: 'ensurePublicSideEffectAllowed',
  ),
  CapabilityGuardSpec(
    relativePath: 'scene_controller_selection.dart',
    className: 'SceneControllerSelectionOwner',
    primaryGuardCall: '_runtime.ensurePublicSideEffectAllowed',
  ),
];

GuardrailViolation? _checkCapabilityEntrypoints(GuardrailContext context) {
  for (final spec in _capabilityGuardSpecs) {
    final file = _interactiveSupportFile(context, spec.relativePath);
    if (!file.existsSync()) {
      return GuardrailViolation(
        filePath: _interactiveFilePosixPath(context, _interactiveFile(context)),
        line: 1,
        message:
            'interactive API violation: missing required capability owner '
            '${spec.className} at ${_interactiveFilePosixPath(context, file)}.',
      );
    }

    final filePath = _interactiveFilePosixPath(context, file);
    final parsed = _parseInteractiveFile(context, file, filePath);
    final capabilityClass = _findClassByName(
      parsed.unit.declarations,
      spec.className,
    );
    if (capabilityClass == null) {
      return GuardrailViolation(
        filePath: filePath,
        line: 1,
        message:
            'interactive API violation: ${spec.className} must remain the '
            'canonical capability owner in $filePath.',
      );
    }

    for (final member in capabilityClass.members) {
      final name = _publicEntrypointName(member);
      if (name == null) {
        continue;
      }
      final violation = _checkCapabilityEntrypointGuard(
        member: member as MethodDeclaration,
        filePath: filePath,
        lineFor: (offset) => lineForOffset(parsed, offset),
        className: spec.className,
        name: name,
        primaryGuardCall: spec.primaryGuardCall,
        secondaryGuardCall: spec.secondaryGuardCallsByMethod[name],
      );
      if (violation != null) {
        return violation;
      }
    }
  }
  return null;
}

GuardrailViolation? _checkMutationOwnerPolicies(GuardrailContext context) {
  for (final spec in mutationOwnerGuardSpecs) {
    final file = _interactiveSupportFile(context, spec.relativePath);
    if (!file.existsSync()) {
      return GuardrailViolation(
        filePath: _interactiveFilePosixPath(context, _interactiveFile(context)),
        line: 1,
        message:
            'interactive API violation: missing required mutation owner '
            '${spec.className} at ${_interactiveFilePosixPath(context, file)}.',
      );
    }

    final filePath = _interactiveFilePosixPath(context, file);
    final parsed = _parseInteractiveFile(context, file, filePath);
    final ownerClass = _findClassByName(
      parsed.unit.declarations,
      spec.className,
    );
    if (ownerClass == null) {
      return GuardrailViolation(
        filePath: filePath,
        line: 1,
        message:
            'interactive API violation: ${spec.className} must remain the '
            'canonical mutation owner in $filePath.',
      );
    }

    for (final policy in spec.policies) {
      final member = _findMethodByName(ownerClass.members, policy.methodName);
      if (member == null) {
        return GuardrailViolation(
          filePath: filePath,
          line: 1,
          message:
              'interactive API violation: '
              '${spec.className}.${policy.methodName} '
              'must remain part of the canonical mutation-owner surface.',
        );
      }
      final violation = _checkMutationOwnerPolicy(
        member: member,
        filePath: filePath,
        lineFor: (offset) => lineForOffset(parsed, offset),
        className: spec.className,
        methodName: policy.methodName,
        policyCall: policy.policyCall,
        policyIndex: policy.policyIndex,
      );
      if (violation != null) {
        return violation;
      }
    }
  }
  return null;
}

ClassDeclaration? _findClassByName(
  NodeList<CompilationUnitMember> declarations,
  String className,
) {
  for (final declaration in declarations) {
    if (declaration is ClassDeclaration &&
        declaration.name.lexeme == className) {
      return declaration;
    }
  }
  return null;
}

MethodDeclaration? _findMethodByName(
  NodeList<ClassMember> members,
  String name,
) {
  for (final member in members) {
    if (member is MethodDeclaration && member.name.lexeme == name) {
      return member;
    }
  }
  return null;
}

GuardrailViolation? _checkCapabilityEntrypointGuard({
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required String name,
  required String primaryGuardCall,
  required String? secondaryGuardCall,
}) {
  final body = member.body;
  if (body is! BlockFunctionBody) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(member.offset),
      detail:
          'public $className entrypoints must use a block body guarded by '
          '$primaryGuardCall(...).',
    );
  }

  final statements = body.block.statements;
  if (statements.isEmpty) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(member.offset),
      detail:
          'public $className entrypoints must guard resolver purity with '
          '$primaryGuardCall(...).',
    );
  }

  final firstCall = _qualifiedInvocationNameFromStatement(statements.first);
  if (firstCall != primaryGuardCall) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(statements.first.offset),
      detail:
          'public $className entrypoints must guard resolver purity with '
          '$primaryGuardCall(...).',
    );
  }

  if (secondaryGuardCall == null) {
    return null;
  }
  if (statements.length < 2) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(statements.first.offset),
      detail:
          '$className.$name must guard active-gesture exclusivity with '
          '$secondaryGuardCall(...).',
    );
  }

  final secondCall = _qualifiedInvocationNameFromStatement(statements[1]);
  if (secondCall != secondaryGuardCall) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(statements[1].offset),
      detail:
          '$className.$name must guard active-gesture exclusivity with '
          '$secondaryGuardCall(...).',
    );
  }
  return null;
}

GuardrailViolation? _checkMutationOwnerPolicy({
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required String methodName,
  required String policyCall,
  required int policyIndex,
}) {
  final body = member.body;
  if (body is! BlockFunctionBody) {
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(member.offset),
      detail:
          '$className.$methodName must guard active-gesture exclusivity with '
          '$policyCall(...).',
    );
  }

  final statements = body.block.statements;
  if (statements.length <= policyIndex) {
    if (_isAllowedReplaceSceneInterruptForwarding(
      methodName: methodName,
      policyCall: policyCall,
      body: body,
    )) {
      return null;
    }
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(member.offset),
      detail:
          '$className.$methodName must guard active-gesture exclusivity with '
          '$policyCall(...).',
    );
  }

  final actualCall = _qualifiedInvocationNameFromStatement(
    statements[policyIndex],
  );
  if (actualCall != policyCall) {
    if (_isAllowedReplaceSceneInterruptForwarding(
      methodName: methodName,
      policyCall: policyCall,
      body: body,
    )) {
      return null;
    }
    return _capabilityGuardViolation(
      filePath: filePath,
      line: lineFor(statements[policyIndex].offset),
      detail:
          '$className.$methodName must guard active-gesture exclusivity with '
          '$policyCall(...).',
    );
  }
  return null;
}

bool _isAllowedReplaceSceneInterruptForwarding({
  required String methodName,
  required String policyCall,
  required BlockFunctionBody body,
}) {
  if (methodName != 'replaceScene' ||
      policyCall != interruptForExternalMutationCall) {
    return false;
  }
  return body.toSource().contains(
    'interruptBeforeApply: interruptForExternalMutation',
  );
}

String? _qualifiedInvocationNameFromStatement(Statement statement) {
  if (statement is! ExpressionStatement) {
    return null;
  }
  return _qualifiedInvocationName(statement.expression);
}

String? _qualifiedInvocationName(Expression expression) {
  if (expression is! MethodInvocation) {
    return null;
  }

  final target = expression.target;
  final methodName = expression.methodName.name;
  if (target == null) {
    return methodName;
  }
  final qualifiedTarget = _qualifiedTargetName(target);
  if (qualifiedTarget == null) {
    return null;
  }
  return '$qualifiedTarget.$methodName';
}

String? _qualifiedTargetName(Expression expression) {
  return switch (expression) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final prefix, :final identifier) =>
      '${prefix.name}.${identifier.name}',
    PropertyAccess(:final target?, :final propertyName) =>
      '${_qualifiedTargetName(target)}.${propertyName.name}',
    ThisExpression() => 'this',
    _ => null,
  };
}

Future<GuardrailViolation?> _checkCommittedReadSideCallbackHermeticity(
  GuardrailContext context,
) async {
  final callbackFiles = <_InteractiveCommittedReadCallbackTarget, File>{
    for (final target in _interactiveCommittedReadCallbackTargets)
      target: _interactiveSupportFile(context, target.relativePath),
  };
  final hasAnyCallbackFile = callbackFiles.values.any(
    (file) => file.existsSync(),
  );
  if (!hasAnyCallbackFile) {
    return GuardrailViolation(
      filePath: '/lib/src/interactive/internal',
      line: 1,
      message:
          'interactive API violation: committed read callback files are '
          'required for the interactive committed read surface.',
    );
  }

  for (final entry in callbackFiles.entries) {
    final target = entry.key;
    final file = entry.value;
    if (!file.existsSync()) {
      return GuardrailViolation(
        filePath: '/lib/src/interactive/${target.relativePath}',
        line: 1,
        message:
            'interactive API violation: committed read callback file '
            '${target.relativePath} is required for "${target.className}".',
      );
    }

    final resolved = await context.getResolvedLibraryResult(file.path);
    if (resolved == null) {
      continue;
    }
    final parsed = parseUnitOrFail(
      context: context,
      absPath: file.path,
      filePathForDiag: '/lib/src/interactive/${target.relativePath}',
      onFailure: _onInteractiveParseFailure,
    );
    final callbackClass = _findResolvedClassByName(
      resolved.element.classes,
      target.className,
    );
    if (callbackClass == null) {
      return GuardrailViolation(
        filePath: '/lib/src/interactive/${target.relativePath}',
        line: 1,
        message:
            'interactive API violation: committed read callback owner '
            '"${target.className}" is required in ${target.relativePath}.',
      );
    }
    final callbackClassDeclaration = _findClassDeclarationByName(
      parsed.unit.declarations,
      target.className,
    );
    if (callbackClassDeclaration == null) {
      return GuardrailViolation(
        filePath: '/lib/src/interactive/${target.relativePath}',
        line: 1,
        message:
            'interactive API violation: committed read callback owner '
            '"${target.className}" is required in ${target.relativePath}.',
      );
    }

    for (final field in callbackClass.fields.where(
      (field) => !field.isSynthetic && isPublicName(field.displayName),
    )) {
      final leak = findForbiddenResolvedTypeLeak(
        type: field.type,
        sourceElement: field,
        context: context,
        forbiddenTypes: committedReadForbiddenTypeSpecs,
      );
      if (leak == null) {
        if (!target.allowedPublicFieldNames.contains(field.displayName)) {
          return _interactiveCommittedReadViolation(
            context: context,
            sourceElement: field,
            detail:
                'committed read callback "${target.className}.'
                '${field.displayName}" must not extend the sealed callback '
                'surface.',
          );
        }
        final signatureViolation = _interactiveExactFieldSignatureViolation(
          target: target,
          field: field,
          context: context,
        );
        if (signatureViolation != null) {
          return signatureViolation;
        }
        continue;
      }
      return _interactiveCommittedReadViolation(
        context: context,
        sourceElement: field,
        detail:
            'committed read callback "${target.className}.${field.displayName}" '
            'must not expose live runtime scene-graph types '
            '(${leak.forbiddenTypeName}).',
      );
    }

    final publicFieldNames = callbackClass.fields
        .where((field) => !field.isSynthetic && isPublicName(field.displayName))
        .map((field) => field.displayName)
        .toSet();
    for (final requiredFieldName in target.allowedPublicFieldNames) {
      if (publicFieldNames.contains(requiredFieldName)) {
        continue;
      }
      return _interactiveCommittedReadViolation(
        context: context,
        sourceElement: callbackClass,
        detail:
            'committed read callback "${target.className}" must keep required '
            'field "$requiredFieldName" on the sealed callback surface.',
      );
    }

    for (final constructor in callbackClass.constructors) {
      final violation = _interactiveCallbackConstructorViolation(
        constructor,
        target: target,
        context: context,
      );
      if (violation != null) {
        return violation;
      }
    }

    for (final getter in callbackClass.getters.where(
      (getter) => !getter.isSynthetic && isPublicName(getter.displayName),
    )) {
      return _interactiveCommittedReadViolation(
        context: context,
        sourceElement: getter,
        detail:
            'committed read callback "${target.className}.${getter.displayName}" '
            'must not add custom public accessors outside the sealed '
            'callback surface.',
      );
    }

    for (final setter in callbackClass.setters.where(
      (setter) => !setter.isSynthetic && isPublicName(setter.displayName),
    )) {
      return _interactiveCommittedReadViolation(
        context: context,
        sourceElement: setter,
        detail:
            'committed read callback "${target.className}.${setter.displayName}" '
            'must not add custom public accessors outside the sealed '
            'callback surface.',
      );
    }

    for (final method in callbackClass.methods.where(
      (method) => isPublicName(method.displayName),
    )) {
      return _interactiveCommittedReadViolation(
        context: context,
        sourceElement: method,
        detail:
            'committed read callback "${target.className}.${method.displayName}" '
            'must not add public methods outside the sealed callback surface.',
      );
    }
  }
  return null;
}

GuardrailViolation? _interactiveCallbackConstructorViolation(
  ConstructorElement constructor, {
  required _InteractiveCommittedReadCallbackTarget target,
  required GuardrailContext context,
}) {
  if (!_isPublicConstructor(constructor)) {
    return null;
  }

  final constructorName = _normalizedConstructorName(constructor);
  if (constructorName.isNotEmpty) {
    return _interactiveCommittedReadViolation(
      context: context,
      sourceElement: constructor,
      detail:
          'committed read callback "${target.className}.$constructorName" '
          'must not add public named constructors outside the sealed '
          'callback surface.',
    );
  }

  final leak = findForbiddenExecutableSignatureLeak(
    element: constructor,
    context: context,
    forbiddenTypes: committedReadForbiddenTypeSpecs,
  );
  if (leak != null) {
    return _interactiveCommittedReadViolation(
      context: context,
      sourceElement: leak.sourceElement,
      detail:
          'committed read callback constructor for "${target.className}" must '
          'not expose live runtime scene-graph types '
          '(${leak.forbiddenTypeName}).',
    );
  }

  for (final parameter in constructor.formalParameters) {
    if (target.allowedPublicFieldNames.contains(parameter.displayName)) {
      continue;
    }
    return _interactiveCommittedReadViolation(
      context: context,
      sourceElement: parameter,
      detail:
          'committed read callback constructor for "${target.className}" must '
          'not extend the sealed callback surface with parameter '
          '"${parameter.displayName}".',
    );
  }

  return null;
}

GuardrailViolation? _interactiveExactFieldSignatureViolation({
  required _InteractiveCommittedReadCallbackTarget target,
  required FieldElement field,
  required GuardrailContext context,
}) {
  final expected = target.exactCommittedReadFieldSignatures[field.displayName];
  if (expected == null) {
    return null;
  }
  final type = field.type;
  if (type is! FunctionType) {
    return _interactiveCommittedReadViolation(
      context: context,
      sourceElement: field,
      detail:
          'committed read callback "${target.className}.${field.displayName}" '
          'must keep the exact sealed signature.',
    );
  }
  if (type.returnType.getDisplayString() != expected.returnType) {
    return _interactiveCommittedReadViolation(
      context: context,
      sourceElement: field,
      detail:
          'committed read callback "${target.className}.${field.displayName}" '
          'must keep the exact sealed signature.',
    );
  }
  final parameters = type.formalParameters;
  if (parameters.length != 1) {
    return _interactiveCommittedReadViolation(
      context: context,
      sourceElement: field,
      detail:
          'committed read callback "${target.className}.${field.displayName}" '
          'must keep the exact sealed signature.',
    );
  }
  final parameter = parameters.single;
  if (!parameter.isRequiredPositional ||
      parameter.type.getDisplayString() != expected.parameterType) {
    return _interactiveCommittedReadViolation(
      context: context,
      sourceElement: field,
      detail:
          'committed read callback "${target.className}.${field.displayName}" '
          'must keep the exact sealed signature.',
    );
  }
  return null;
}

const List<_InteractiveCommittedReadCallbackTarget>
_interactiveCommittedReadCallbackTargets =
    <_InteractiveCommittedReadCallbackTarget>[
      _InteractiveCommittedReadCallbackTarget(
        relativePath: 'internal/interactive_runtime_callbacks.dart',
        className: 'InteractiveRuntimeCallbacks',
        allowedPublicFieldNames: <String>{
          'schedulePublicNotify',
          'scheduleSceneNotify',
          'scheduleOverlayNotify',
          'readSnapshot',
          'readSelectedNodeIds',
          'readMode',
          'readDragStartSlop',
          'readDrawStyle',
          'querySpatialCandidates',
          'resolveSpatialCandidateSnapshot',
          'writeSelectionReplace',
          'writeSelectionClear',
          'commitMoveSelection',
          'commitDrawStroke',
          'commitDrawLineFromWorldSegment',
          'commitEraseNodes',
        },
        exactCommittedReadFieldSignatures:
            <String, _CommittedReadFieldSignature>{
              'querySpatialCandidates': _CommittedReadFieldSignature(
                returnType: 'List<SceneSpatialCandidate>',
                parameterType: 'Rect',
              ),
              'resolveSpatialCandidateSnapshot': _CommittedReadFieldSignature(
                returnType: 'NodeSnapshot?',
                parameterType: 'SceneSpatialCandidate',
              ),
            },
      ),
      _InteractiveCommittedReadCallbackTarget(
        relativePath: 'internal/interactive_move_callbacks.dart',
        className: 'InteractiveMoveSessionCallbacks',
        allowedPublicFieldNames: <String>{
          'onPublicStateChanged',
          'onSceneStateChanged',
          'onOverlayStateChanged',
          'readSnapshot',
          'readSelectedNodeIds',
          'querySpatialCandidates',
          'resolveSpatialCandidateSnapshot',
          'writeSelectionReplace',
          'writeSelectionClear',
          'commitMoveSelection',
          'emitAction',
        },
        exactCommittedReadFieldSignatures:
            <String, _CommittedReadFieldSignature>{
              'querySpatialCandidates': _CommittedReadFieldSignature(
                returnType: 'List<SceneSpatialCandidate>',
                parameterType: 'Rect',
              ),
              'resolveSpatialCandidateSnapshot': _CommittedReadFieldSignature(
                returnType: 'NodeSnapshot?',
                parameterType: 'SceneSpatialCandidate',
              ),
            },
      ),
      _InteractiveCommittedReadCallbackTarget(
        relativePath: 'internal/interactive_draw_coordinator_callbacks.dart',
        className: 'InteractiveDrawCoordinatorCallbacks',
        allowedPublicFieldNames: <String>{
          'onOverlayStateChanged',
          'emitAction',
          'commitDrawStroke',
          'commitDrawLineFromWorldSegment',
          'querySpatialCandidates',
          'resolveSpatialCandidateSnapshot',
          'commitEraseNodes',
        },
        exactCommittedReadFieldSignatures:
            <String, _CommittedReadFieldSignature>{
              'querySpatialCandidates': _CommittedReadFieldSignature(
                returnType: 'List<SceneSpatialCandidate>',
                parameterType: 'Rect',
              ),
              'resolveSpatialCandidateSnapshot': _CommittedReadFieldSignature(
                returnType: 'NodeSnapshot?',
                parameterType: 'SceneSpatialCandidate',
              ),
            },
      ),
      _InteractiveCommittedReadCallbackTarget(
        relativePath: 'internal/interactive_draw_eraser_engine.dart',
        className: 'InteractiveDrawEraserEngineCallbacks',
        allowedPublicFieldNames: <String>{
          'onOverlayStateChanged',
          'querySpatialCandidates',
          'resolveSpatialCandidateSnapshot',
          'commitEraseNodes',
        },
        exactCommittedReadFieldSignatures:
            <String, _CommittedReadFieldSignature>{
              'querySpatialCandidates': _CommittedReadFieldSignature(
                returnType: 'List<SceneSpatialCandidate>',
                parameterType: 'Rect',
              ),
              'resolveSpatialCandidateSnapshot': _CommittedReadFieldSignature(
                returnType: 'NodeSnapshot?',
                parameterType: 'SceneSpatialCandidate',
              ),
            },
      ),
      _InteractiveCommittedReadCallbackTarget(
        relativePath: 'internal/interactive_draw_eraser_targets.dart',
        className: 'InteractiveDrawEraserTargetsCallbacks',
        allowedPublicFieldNames: <String>{
          'querySpatialCandidates',
          'resolveSpatialCandidateSnapshot',
          'onSpatialQuery',
        },
        exactCommittedReadFieldSignatures:
            <String, _CommittedReadFieldSignature>{
              'querySpatialCandidates': _CommittedReadFieldSignature(
                returnType: 'List<SceneSpatialCandidate>',
                parameterType: 'Rect',
              ),
              'resolveSpatialCandidateSnapshot': _CommittedReadFieldSignature(
                returnType: 'NodeSnapshot?',
                parameterType: 'SceneSpatialCandidate',
              ),
            },
      ),
    ];

class _InteractiveCommittedReadCallbackTarget {
  const _InteractiveCommittedReadCallbackTarget({
    required this.relativePath,
    required this.className,
    required this.allowedPublicFieldNames,
    required this.exactCommittedReadFieldSignatures,
  });

  final String relativePath;
  final String className;
  final Set<String> allowedPublicFieldNames;
  final Map<String, _CommittedReadFieldSignature>
  exactCommittedReadFieldSignatures;
}

class _CommittedReadFieldSignature {
  const _CommittedReadFieldSignature({
    required this.returnType,
    required this.parameterType,
  });

  final String returnType;
  final String parameterType;
}

bool _isPublicConstructor(ConstructorElement constructor) {
  final typeName = constructor.enclosingElement.displayName;
  if (typeName.isEmpty || !isPublicName(typeName)) {
    return false;
  }
  final constructorName = _normalizedConstructorName(constructor);
  return constructorName.isEmpty || isPublicName(constructorName);
}

String _normalizedConstructorName(ConstructorElement constructor) {
  final constructorName = constructor.name ?? '';
  return constructorName == 'new' ? '' : constructorName;
}

ClassElement? _findResolvedClassByName(
  Iterable<ClassElement> classes,
  String className,
) {
  for (final element in classes) {
    if (element.displayName == className) {
      return element;
    }
  }
  return null;
}

ClassDeclaration? _findClassDeclarationByName(
  NodeList<CompilationUnitMember> declarations,
  String className,
) {
  for (final declaration in declarations) {
    if (declaration is ClassDeclaration &&
        declaration.name.lexeme == className) {
      return declaration;
    }
  }
  return null;
}

GuardrailViolation _capabilityGuardViolation({
  required String filePath,
  required int line,
  required String detail,
}) {
  return GuardrailViolation(
    filePath: filePath,
    line: line,
    message: 'interactive API violation: $detail',
  );
}

GuardrailViolation? _interactiveCommittedReadViolation({
  required GuardrailContext context,
  required Element sourceElement,
  required String detail,
}) {
  final filePath = repoRelForElement(element: sourceElement, context: context);
  final line = lineForElement(sourceElement);
  if (filePath == null || line == null) {
    return null;
  }
  return GuardrailViolation(
    filePath: filePath,
    line: line,
    message: 'interactive API violation: $detail',
  );
}

Never _onInteractiveParseFailure({
  required String filePathForDiag,
  required String resultType,
}) {
  throw GuardrailToolFailure(
    GuardrailViolation(
      filePath: filePathForDiag,
      line: 1,
      message: 'tool failure: unable to parse Dart unit (result: $resultType)',
    ),
  );
}
