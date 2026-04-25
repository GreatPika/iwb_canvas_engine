import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../support/guardrail_ast_utils.dart';
import '../../support/guardrail_context.dart';
import '../../support/guardrail_path_utils.dart';
import '../../core/element_violation_builder.dart';
import '../../core/guardrail_rule.dart';
import '../../core/guardrail_rule_metadata.dart';
import '../../core/guardrail_run_state.dart';
import '../../core/resolved_surface_contract_support.dart';
import '../../core/semantic_sequence_routing_support.dart';
import '../../core/guardrail_runner_support.dart';
import '../../core/guardrail_element_utils.dart' as element_utils;
import '../controller/committed_read_side_rules.dart';
import '../../core/guardrail_violation.dart';
import 'committed_read_callback_rules.dart';

part 'interactive_architecture_boundary_rules.dart';
part 'interactive_architecture_boundary_structure_rules.dart';
part 'interactive_architecture_boundary_facade_rules.dart';
part 'interactive_architecture_boundary_graph_rules.dart';
part 'interactive_architecture_boundary_view_rules.dart';
part 'interactive_architecture_boundary_view_host_rules.dart';
part 'interactive_architecture_boundary_view_surface_rules.dart';
part 'interactive_architecture_boundary_pointer_rules.dart';
part 'interactive_architecture_boundary_pointer_host_rules.dart';
part 'interactive_architecture_boundary_mutation_rules.dart';
part 'interactive_architecture_boundary_mutation_runtime_rules.dart';
part 'interactive_architecture_boundary_draw_rules.dart';
part 'interactive_architecture_boundary_file_support.dart';
part 'interactive_architecture_boundary_declaration_support.dart';
part 'interactive_architecture_boundary_matcher_support.dart';
part 'interactive_architecture_boundary_signature_support.dart';
part 'interactive_architecture_boundary_owner_support.dart';
part 'interactive_architecture_boundary_flow_support.dart';
part 'interactive_architecture_boundary_expression_support.dart';
part 'interactive_architecture_boundary_collector_support.dart';
part 'interactive_committed_read_callback_guard_rules.dart';
part 'interactive_mutation_owner_guard_rules.dart';
part 'resolved_entrypoint_guard_rules.dart';
part 'resolved_entrypoint_guard_support.dart';

final GuardrailRule interactiveApiGuardrailRule = GuardrailRule(
  metadata: const GuardrailRuleMetadata(
    id: 'interactive-api',
    invariantIds: <String>[
      'INV-ENG-INTERACTIVE-RESOLVER-PURITY',
      'INV-ENG-INTERACTIVE-MUTATION-BOUNDARY',
      'INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY',
      'INV-ENG-INTERACTIVE-POINTER-SESSION-LIFECYCLE',
      'INV-ENG-COMMITTED-READ-SIDE-HERMETICITY',
      'INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY',
      'INV-ENG-PREPARED-REPLACE-SCENE-BOUNDARY-HERMETICITY',
    ],
    area: 'interactive',
    description:
        'Validates interactive entrypoint purity, mutation ownership, '
        'committed-read callbacks, and architecture boundaries.',
  ),
  run: _runInteractiveApiGuardrailRule,
);

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

  final rootViolation = await _checkRootEntrypoints(
    context,
    file: file,
    filePath: filePosixPath,
  );
  if (rootViolation != null) {
    violations.add(rootViolation);
    return violations;
  }

  final capabilityViolation = await _checkCapabilityEntrypoints(context);
  if (capabilityViolation != null) {
    violations.add(capabilityViolation);
    return violations;
  }

  final mutationOwnerViolation = await _checkMutationOwnerPolicies(context);
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

  final boundaryViolation = await _checkInteractiveArchitectureBoundary(
    context,
  );
  if (boundaryViolation != null) {
    violations.add(boundaryViolation);
  }
  return violations;
}

Future<List<GuardrailViolation>> _runInteractiveApiGuardrailRule(
  GuardrailContext context,
  GuardrailRunState state,
) {
  return runInteractiveApiGuardrails(context: context);
}

File _interactiveFile(GuardrailContext context) {
  return libSrcFile(context, relativePath: 'interactive/scene_controller.dart');
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
    primaryGuardCall: '_runtime.ensurePublicSideEffectAllowed',
  ),
  CapabilityGuardSpec(
    relativePath: 'scene_controller_scene.dart',
    className: 'SceneControllerSceneOwner',
    primaryGuardCall: '_runtime.ensurePublicSideEffectAllowed',
  ),
  CapabilityGuardSpec(
    relativePath: 'scene_controller_selection.dart',
    className: 'SceneControllerSelectionOwner',
    primaryGuardCall: '_runtime.ensurePublicSideEffectAllowed',
  ),
];

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
