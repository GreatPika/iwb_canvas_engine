import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../guardrail_support/guardrail_ast_utils.dart';
import '../guardrail_support/guardrail_context.dart';
import '../guardrail_support/guardrail_path_utils.dart';
import 'public_surface_guardrails.dart';

Future<List<GuardrailViolation>> runMutableTypeLeakGuardrails({
  required GuardrailContext context,
  required Map<String, ExportedLibrarySurface> exportedSurfaces,
}) async {
  final violations = <GuardrailViolation>[];
  if (exportedSurfaces.isEmpty) {
    return violations;
  }

  final exportedFiles = exportedSurfaces.keys.toSet();
  validateExportedApiScanPolicies(
    exportedFiles: exportedFiles,
    violations: violations,
  );
  if (violations.isNotEmpty) {
    return violations;
  }

  final filesToCheck = _mutableLeakScanTargets(exportedFiles);

  for (final repoRel in filesToCheck) {
    final surface = exportedSurfaces[repoRel];
    if (surface == null) {
      continue;
    }
    final fileScan = _buildMutableLeakFileScan(
      context: context,
      repoRel: repoRel,
      surface: surface,
    );
    if (fileScan == null) {
      continue;
    }

    final violation = _scanLibraryForMutableTypeLeak(
      parsed: fileScan.parsed,
      repoRel: fileScan.repoRel,
      surface: fileScan.surface,
      policy: fileScan.policy,
    );
    if (violation != null) {
      violations.add(violation);
      return violations;
    }
  }

  return violations;
}

List<String> _mutableLeakScanTargets(Set<String> exportedFiles) {
  final filesToCheck =
      exportedFiles
          .where(
            (path) =>
                path.startsWith('/lib/src/contract/') ||
                nonContractExportedApiScanPolicies.containsKey(path),
          )
          .toList(growable: false)
        ..sort();
  return filesToCheck;
}

MutableLeakFileScan? _buildMutableLeakFileScan({
  required GuardrailContext context,
  required String repoRel,
  required ExportedLibrarySurface surface,
}) {
  final file = File(posixJoin(context.root.path, repoRel.substring(1)));
  if (!file.existsSync()) {
    return null;
  }
  return MutableLeakFileScan(
    repoRel: repoRel,
    surface: surface,
    policy:
        nonContractExportedApiScanPolicies[repoRel] ??
        const ExportedApiScanPolicy.fullScan(),
    parsed: parseUnitOrFail(
      context: context,
      absPath: file.absolute.path,
      filePathForDiag: repoRel,
      onFailure: _onMutableLeakParseFailure,
    ),
  );
}

Never _onMutableLeakParseFailure({
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

class MutableLeakFileScan {
  const MutableLeakFileScan({
    required this.repoRel,
    required this.surface,
    required this.policy,
    required this.parsed,
  });

  final String repoRel;
  final ExportedLibrarySurface surface;
  final ExportedApiScanPolicy policy;
  final ParsedUnitResult parsed;
}

class MutableTypeReferenceVisitor extends RecursiveAstVisitor<void> {
  MutableTypeReferenceVisitor(this.bannedTypeNames);

  final Set<String> bannedTypeNames;
  AstNode? firstMatch;

  @override
  void visitNamedType(NamedType node) {
    if (firstMatch != null) {
      return;
    }
    final typeName = node.name.lexeme;
    if (bannedTypeNames.contains(typeName)) {
      firstMatch = node;
      return;
    }
    super.visitNamedType(node);
  }
}

GuardrailViolation? _scanLibraryForMutableTypeLeak({
  required ParsedUnitResult parsed,
  required String repoRel,
  required ExportedLibrarySurface surface,
  required ExportedApiScanPolicy policy,
}) {
  for (final declaration in parsed.unit.declarations) {
    final mutableTypeMatch = _mutableTypeLeakInDeclaration(
      declaration,
      surface: surface,
      policy: policy,
    );
    if (mutableTypeMatch == null) {
      continue;
    }
    return GuardrailViolation(
      filePath: repoRel,
      line: lineForOffset(parsed, mutableTypeMatch.offset),
      message:
          'public contract violation: exported API must not expose '
          'mutable core types '
          '(Scene/ContentLayer/SceneNode/NodeType).',
    );
  }
  return null;
}

AstNode? _mutableTypeLeakInDeclaration(
  CompilationUnitMember declaration, {
  required ExportedLibrarySurface surface,
  required ExportedApiScanPolicy policy,
}) {
  if (!shouldScanDeclaration(
    declaration: declaration,
    surface: surface,
    policy: policy,
  )) {
    return null;
  }
  return _firstMutableTypeInDeclarationSignature(
    declaration,
    policy.bannedTypeNames,
  );
}

AstNode? _firstMutableTypeInDeclarationSignature(
  CompilationUnitMember member,
  Set<String> bannedTypeNames,
) {
  final namedTypeMatch = _firstMutableTypeInNamedTypeMemberSignature(
    member,
    bannedTypeNames,
  );
  if (namedTypeMatch != null) {
    return namedTypeMatch;
  }

  final aliasMatch = _firstMutableTypeInTypeAliasSignature(
    member,
    bannedTypeNames,
  );
  if (aliasMatch != null) {
    return aliasMatch;
  }

  if (member is FunctionDeclaration) {
    return _firstMutableTypeInTopLevelFunctionSignature(
      member,
      bannedTypeNames,
    );
  }
  if (member is TopLevelVariableDeclaration) {
    return _firstMutableTypeInTopLevelVariableSignature(
      member,
      bannedTypeNames,
    );
  }
  return null;
}

AstNode? _firstMutableTypeInNamedTypeMemberSignature(
  CompilationUnitMember member,
  Set<String> bannedTypeNames,
) {
  return switch (member) {
    ClassDeclaration() => _firstMutableTypeInNamedTypeDeclaration(
      name: member.name.lexeme,
      declarationNodes: <AstNode?>[
        member.typeParameters,
        member.extendsClause,
        member.withClause,
        member.implementsClause,
      ],
      members: member.members,
      bannedTypeNames: bannedTypeNames,
    ),
    EnumDeclaration() => _firstMutableTypeInNamedTypeDeclaration(
      name: member.name.lexeme,
      declarationNodes: <AstNode?>[member.withClause, member.implementsClause],
      members: member.members,
      bannedTypeNames: bannedTypeNames,
    ),
    MixinDeclaration() => _firstMutableTypeInNamedTypeDeclaration(
      name: member.name.lexeme,
      declarationNodes: <AstNode?>[
        member.typeParameters,
        member.onClause,
        member.implementsClause,
      ],
      members: member.members,
      bannedTypeNames: bannedTypeNames,
    ),
    ExtensionDeclaration() => _firstMutableTypeInNamedTypeDeclaration(
      name: member.name?.lexeme,
      declarationNodes: <AstNode?>[member.typeParameters, member.onClause],
      members: member.members,
      bannedTypeNames: bannedTypeNames,
    ),
    _ => null,
  };
}

AstNode? _firstMutableTypeInTypeAliasSignature(
  CompilationUnitMember member,
  Set<String> bannedTypeNames,
) {
  return switch (member) {
    ClassTypeAlias() => _firstMutableTypeInAliasSignature(
      name: member.name.lexeme,
      nodes: <AstNode?>[
        member.typeParameters,
        member.superclass,
        member.withClause,
        member.implementsClause,
      ],
      bannedTypeNames: bannedTypeNames,
    ),
    GenericTypeAlias() => _firstMutableTypeInAliasSignature(
      name: member.name.lexeme,
      nodes: <AstNode?>[member.typeParameters, member.functionType],
      bannedTypeNames: bannedTypeNames,
    ),
    _ => null,
  };
}

AstNode? _firstMutableTypeInNamedTypeDeclaration({
  required String? name,
  required List<AstNode?> declarationNodes,
  required List<ClassMember> members,
  required Set<String> bannedTypeNames,
}) {
  if (name != null && !isPublicName(name)) {
    return null;
  }
  final declarationMatch = _firstMutableTypeInNodes(
    declarationNodes,
    bannedTypeNames,
  );
  if (declarationMatch != null) {
    return declarationMatch;
  }
  return _firstMutableTypeInMembers(members, bannedTypeNames);
}

AstNode? _firstMutableTypeInAliasSignature({
  required String name,
  required List<AstNode?> nodes,
  required Set<String> bannedTypeNames,
}) {
  if (!isPublicName(name)) {
    return null;
  }
  return _firstMutableTypeInNodes(nodes, bannedTypeNames);
}

AstNode? _firstMutableTypeInMembers(
  List<ClassMember> members,
  Set<String> bannedTypeNames,
) {
  for (final member in members) {
    final memberMatch = _firstMutableTypeInClassMemberSignature(
      member,
      bannedTypeNames,
    );
    if (memberMatch != null) {
      return memberMatch;
    }
  }
  return null;
}

AstNode? _firstMutableTypeInClassMemberSignature(
  ClassMember member,
  Set<String> bannedTypeNames,
) {
  if (member is FieldDeclaration) {
    return _firstMutableTypeInFieldSignature(member, bannedTypeNames);
  }
  if (member is MethodDeclaration) {
    return _firstMutableTypeInMethodSignature(member, bannedTypeNames);
  }
  if (member is ConstructorDeclaration) {
    return _firstMutableTypeInConstructorSignature(member, bannedTypeNames);
  }
  return null;
}

AstNode? _firstMutableTypeInFieldSignature(
  FieldDeclaration member,
  Set<String> bannedTypeNames,
) {
  final hasPublicVariable = member.fields.variables.any(
    (variable) => isPublicName(variable.name.lexeme),
  );
  if (!hasPublicVariable) {
    return null;
  }
  return _firstMutableTypeInNode(member.fields.type, bannedTypeNames);
}

AstNode? _firstMutableTypeInMethodSignature(
  MethodDeclaration member,
  Set<String> bannedTypeNames,
) {
  if (!isPublicName(member.name.lexeme)) {
    return null;
  }
  if (member.isGetter) {
    return _firstMutableTypeInNode(member.returnType, bannedTypeNames);
  }
  return _firstMutableTypeInFunctionSignature(
    returnType: member.isSetter ? null : member.returnType,
    typeParameters: member.isSetter ? null : member.typeParameters,
    parameters: member.parameters,
    bannedTypeNames: bannedTypeNames,
  );
}

AstNode? _firstMutableTypeInConstructorSignature(
  ConstructorDeclaration member,
  Set<String> bannedTypeNames,
) {
  final constructorName = member.name?.lexeme;
  if (constructorName != null && !isPublicName(constructorName)) {
    return null;
  }
  final typeNodes = <AstNode?>[];
  _collectTypeNodesFromFormalParameterList(member.parameters, typeNodes);
  typeNodes.add(member.redirectedConstructor?.type);
  return _firstMutableTypeInNodes(typeNodes, bannedTypeNames);
}

AstNode? _firstMutableTypeInTopLevelFunctionSignature(
  FunctionDeclaration member,
  Set<String> bannedTypeNames,
) {
  if (!isPublicName(member.name.lexeme)) {
    return null;
  }
  if (member.isGetter) {
    return _firstMutableTypeInNode(member.returnType, bannedTypeNames);
  }
  return _firstMutableTypeInFunctionSignature(
    returnType: member.isSetter ? null : member.returnType,
    typeParameters: member.isSetter
        ? null
        : member.functionExpression.typeParameters,
    parameters: member.functionExpression.parameters,
    bannedTypeNames: bannedTypeNames,
  );
}

AstNode? _firstMutableTypeInTopLevelVariableSignature(
  TopLevelVariableDeclaration member,
  Set<String> bannedTypeNames,
) {
  final hasPublicVariable = member.variables.variables.any(
    (variable) => isPublicName(variable.name.lexeme),
  );
  if (!hasPublicVariable) {
    return null;
  }
  return _firstMutableTypeInNode(member.variables.type, bannedTypeNames);
}

AstNode? _firstMutableTypeInFunctionSignature({
  required TypeAnnotation? returnType,
  required TypeParameterList? typeParameters,
  required FormalParameterList? parameters,
  required Set<String> bannedTypeNames,
}) {
  final typeNodes = <AstNode?>[returnType];
  _collectTypeNodesFromTypeParameters(typeParameters, typeNodes);
  _collectTypeNodesFromFormalParameterList(parameters, typeNodes);
  return _firstMutableTypeInNodes(typeNodes, bannedTypeNames);
}

AstNode? _firstMutableTypeInNode(AstNode? node, Set<String> bannedTypeNames) {
  if (node == null) {
    return null;
  }
  final visitor = MutableTypeReferenceVisitor(bannedTypeNames);
  node.accept(visitor);
  return visitor.firstMatch;
}

AstNode? _firstMutableTypeInNodes(
  Iterable<AstNode?> nodes,
  Set<String> bannedTypeNames,
) {
  for (final node in nodes) {
    final match = _firstMutableTypeInNode(node, bannedTypeNames);
    if (match != null) {
      return match;
    }
  }
  return null;
}

void _collectTypeNodesFromTypeParameters(
  TypeParameterList? typeParameters,
  List<AstNode?> out,
) {
  if (typeParameters == null) {
    return;
  }
  for (final typeParameter in typeParameters.typeParameters) {
    out.add(typeParameter.bound);
  }
}

void _collectTypeNodesFromFormalParameter(
  FormalParameter parameter,
  List<AstNode?> out,
) {
  if (parameter is DefaultFormalParameter) {
    _collectTypeNodesFromFormalParameter(parameter.parameter, out);
    return;
  }
  if (parameter is SimpleFormalParameter) {
    out.add(parameter.type);
    return;
  }
  if (parameter is FieldFormalParameter) {
    out.add(parameter.type);
    final nested = parameter.parameters;
    if (nested != null) {
      _collectTypeNodesFromFormalParameterList(nested, out);
    }
    return;
  }
  if (parameter is SuperFormalParameter) {
    out.add(parameter.type);
    final nested = parameter.parameters;
    if (nested != null) {
      _collectTypeNodesFromFormalParameterList(nested, out);
    }
    return;
  }
  if (parameter is FunctionTypedFormalParameter) {
    out.add(parameter.returnType);
    _collectTypeNodesFromTypeParameters(parameter.typeParameters, out);
    _collectTypeNodesFromFormalParameterList(parameter.parameters, out);
  }
}

void _collectTypeNodesFromFormalParameterList(
  FormalParameterList? parameters,
  List<AstNode?> out,
) {
  if (parameters == null) {
    return;
  }
  for (final parameter in parameters.parameters) {
    _collectTypeNodesFromFormalParameter(parameter, out);
  }
}
