import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'src/layer_guardrails.dart';

// Invariants enforced by this tool:
// INV:INV-ENG-NO-EXTERNAL-MUTATION
// INV:INV-ENG-WRITE-ONLY-MUTATION
// INV:INV-ENG-TXN-ATOMIC-COMMIT
// INV:INV-ENG-EPOCH-INVALIDATION
// INV:INV-G-PUBLIC-ENTRYPOINTS
// INV:INV-ENG-SAFE-TXN-API
// INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY

class _Violation {
  _Violation({
    required this.filePath,
    required this.line,
    required this.message,
  });

  final String filePath;
  final int line;
  final String message;

  @override
  String toString() => '$filePath:$line: $message';
}

class _DirectiveUriRef {
  const _DirectiveUriRef({required this.uri, required this.offset});

  final String uri;
  final int offset;
}

enum _ExportedApiScanMode { fullScan, targetedSkip }

class _ExportedApiScanPolicy {
  const _ExportedApiScanPolicy.fullScan()
    : bannedTypeNames = _mutableContractTypeNames,
      mode = _ExportedApiScanMode.fullScan,
      reason = null,
      skippedTopLevelNames = const <String>{};

  const _ExportedApiScanPolicy.targetedSkip({
    required this.reason,
    required this.skippedTopLevelNames,
    this.bannedTypeNames = _mutableContractTypeNames,
  }) : mode = _ExportedApiScanMode.targetedSkip;

  final _ExportedApiScanMode mode;
  final String? reason;
  final Set<String> skippedTopLevelNames;
  final Set<String> bannedTypeNames;
}

class _ExportedLibrarySurface {
  const _ExportedLibrarySurface({
    required this.repoRelPath,
    required this.directiveCombinators,
  });

  final String repoRelPath;
  final List<_DirectiveCombinators> directiveCombinators;

  bool get exportsUnnamedExtensions =>
      directiveCombinators.any((directive) => directive.exportsAllNames);

  bool exportsTopLevelName(String name) {
    return directiveCombinators.any(
      (directive) => directive.exportsTopLevelName(name),
    );
  }
}

enum _DirectiveFilterMode { show, hide }

class _DirectiveFilter {
  const _DirectiveFilter({required this.mode, required this.names});

  final _DirectiveFilterMode mode;
  final Set<String> names;
}

class _DirectiveCombinators {
  const _DirectiveCombinators({
    required this.exportsAllNames,
    required this.filters,
  });

  final bool exportsAllNames;
  final List<_DirectiveFilter> filters;

  bool exportsTopLevelName(String name) {
    var isVisible = exportsAllNames;
    for (final filter in filters) {
      switch (filter.mode) {
        case _DirectiveFilterMode.show:
          isVisible = filter.names.contains(name);
        case _DirectiveFilterMode.hide:
          if (filter.names.contains(name)) {
            isVisible = false;
          }
      }
    }
    return isVisible;
  }
}

class _MutableTypeReferenceVisitor extends RecursiveAstVisitor<void> {
  _MutableTypeReferenceVisitor(this.bannedTypeNames);

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

const _nonContractExportedApiScanPolicies = <String, _ExportedApiScanPolicy>{
  '/lib/src/core/action_events.dart': _ExportedApiScanPolicy.fullScan(),
  '/lib/src/core/interaction_types.dart': _ExportedApiScanPolicy.fullScan(),
  '/lib/src/core/pointer_input.dart': _ExportedApiScanPolicy.fullScan(),
  '/lib/src/model/scene_builder_api.dart': _ExportedApiScanPolicy.fullScan(),
  '/lib/src/interactive/scene_controller_interactive.dart':
      _ExportedApiScanPolicy.targetedSkip(
        reason:
            'SceneController is a public alias that mirrors the scanned '
            'SceneControllerInteractive class surface.',
        skippedTopLevelNames: <String>{'SceneController'},
        bannedTypeNames: _mutableCoreTypeNames,
      ),
  '/lib/src/view/scene_view_interactive.dart':
      _ExportedApiScanPolicy.targetedSkip(
        reason:
            'SceneView is a public alias that mirrors the scanned '
            'SceneViewInteractive class surface.',
        skippedTopLevelNames: <String>{'SceneView'},
        bannedTypeNames: _mutableCoreTypeNames,
      ),
  '/lib/src/serialization/scene_codec.dart': _ExportedApiScanPolicy.fullScan(),
};

const _mutableCoreTypeNames = <String>{
  'Scene',
  'ContentLayer',
  'SceneNode',
  'NodeType',
};

const _mutableRuntimeTypeNames = <String>{
  'SceneController',
  'SceneControllerInteractive',
};

const _mutableContractTypeNames = <String>{
  ..._mutableCoreTypeNames,
  ..._mutableRuntimeTypeNames,
};

const _nodeIdBookkeepingNames = <String>{
  'writeNewNodeId',
  'writeContainsNodeId',
  'writeRegisterNodeId',
  'writeUnregisterNodeId',
  'writeRebuildNodeIdIndex',
};

class _EnsureCallInfo {
  const _EnsureCallInfo({required this.hasAllowAfterDispose});

  final bool hasAllowAfterDispose;
}

class _InteractiveGuardContext {
  const _InteractiveGuardContext({
    required this.firstStatement,
    required this.expressionStatement,
  });

  final Statement firstStatement;
  final ExpressionStatement expressionStatement;
}

class _ControllerSymbolOccurrence {
  const _ControllerSymbolOccurrence({required this.name, required this.offset});

  final String name;
  final int offset;
}

class _ControllerSymbolCollector extends RecursiveAstVisitor<void> {
  final List<_ControllerSymbolOccurrence> occurrences =
      <_ControllerSymbolOccurrence>[];
  bool hasControllerEpoch = false;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.name.lexeme == 'controllerEpoch') {
      hasControllerEpoch = true;
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    occurrences.add(
      _ControllerSymbolOccurrence(
        name: node.name.lexeme,
        offset: node.name.offset,
      ),
    );
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    occurrences.add(
      _ControllerSymbolOccurrence(
        name: node.name.lexeme,
        offset: node.name.offset,
      ),
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && !node.isCascaded) {
      occurrences.add(
        _ControllerSymbolOccurrence(
          name: node.methodName.name,
          offset: node.methodName.offset,
        ),
      );
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final function = node.function;
    if (function is SimpleIdentifier) {
      occurrences.add(
        _ControllerSymbolOccurrence(
          name: function.name,
          offset: function.offset,
        ),
      );
    }
    super.visitFunctionExpressionInvocation(node);
  }
}

String _normalizePosixPath(String path) {
  final isAbs = path.startsWith('/');
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  final out = <String>[];

  for (final part in parts) {
    if (part == '.') continue;
    if (part == '..') {
      if (out.isNotEmpty) out.removeLast();
      continue;
    }
    out.add(part);
  }

  return '${isAbs ? '/' : ''}${out.join('/')}';
}

String _posixJoin(String a, String b) {
  if (b.startsWith('/')) return _normalizePosixPath(b);
  if (a.isEmpty) return _normalizePosixPath(b);
  return _normalizePosixPath('${a.endsWith('/') ? a : '$a/'}$b');
}

String _toPosixPath(String path) => path.replaceAll('\\', '/');

String _toRepoRelPosixPath({
  required String absPosixPath,
  required String rootAbsPosixPath,
}) {
  final abs = _normalizePosixPath(absPosixPath);
  final root = _normalizePosixPath(rootAbsPosixPath);
  if (abs == root) return '/';
  final rootPrefix = root.endsWith('/') ? root : '$root/';
  if (!abs.startsWith(rootPrefix)) return abs;
  final rel = abs.substring(root.length);
  return rel.startsWith('/') ? rel : '/$rel';
}

String _posixDirname(String posixPath) {
  final n = _normalizePosixPath(posixPath);
  if (n == '/' || n.isEmpty) return n;
  final idx = n.lastIndexOf('/');
  if (idx <= 0) return n.startsWith('/') ? '/' : '';
  return n.substring(0, idx);
}

String _readPackageNameOrFallback(Directory root) {
  final pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
  if (!pubspec.existsSync()) return 'iwb_canvas_engine';

  for (final line in pubspec.readAsLinesSync()) {
    final trimmed = line.trimLeft();
    final match = RegExp(r'^name:\s*([A-Za-z0-9_]+)\s*$').firstMatch(trimmed);
    if (match != null) {
      final packageName = match.group(1);
      if (packageName != null) {
        return packageName;
      }
    }
  }
  return 'iwb_canvas_engine';
}

String? _resolveToRepoRelTargetPosix({
  required String targetPosix,
  required String packageName,
  required String fileDirRepoRelPosix,
}) {
  if (targetPosix.startsWith('dart:')) return null;
  if (targetPosix.startsWith('package:')) {
    final prefix = 'package:$packageName/';
    if (!targetPosix.startsWith(prefix)) return null;
    final rest = targetPosix.substring(prefix.length);
    return _normalizePosixPath('/lib/$rest');
  }
  return _posixJoin(fileDirRepoRelPosix, targetPosix);
}

bool _looksMutatingSymbol(String symbol) {
  const prefixes = <String>[
    'add',
    'remove',
    'delete',
    'clear',
    'replace',
    'update',
    'set',
    'move',
    'insert',
    'mutate',
    'commit',
    'apply',
  ];
  return prefixes.any(symbol.startsWith);
}

Never _fail(_Violation violation) {
  stderr.writeln('FAIL: guardrails');
  stderr.writeln('- $violation');
  exit(1);
}

List<_DirectiveUriRef> _collectDirectiveUriRefs(UriBasedDirective directive) {
  final refs = <_DirectiveUriRef>[];

  void addUri(StringLiteral literal) {
    final uri = literal.stringValue;
    if (uri == null || uri.isEmpty) {
      return;
    }
    refs.add(_DirectiveUriRef(uri: uri, offset: literal.offset));
  }

  addUri(directive.uri);
  if (directive is NamespaceDirective) {
    for (final configuration in directive.configurations) {
      addUri(configuration.uri);
    }
  }

  return refs;
}

_DirectiveCombinators _collectDirectiveCombinators(
  NamespaceDirective directive,
) {
  Set<String>? showNames;
  final filters = <_DirectiveFilter>[];

  for (final combinator in directive.combinators) {
    if (combinator is ShowCombinator) {
      showNames ??= <String>{};
      final shownNames = Set<String>.unmodifiable(
        combinator.shownNames.map((identifier) => identifier.name).toSet(),
      );
      showNames.addAll(shownNames);
      filters.add(
        _DirectiveFilter(mode: _DirectiveFilterMode.show, names: shownNames),
      );
      continue;
    }
    if (combinator is HideCombinator) {
      filters.add(
        _DirectiveFilter(
          mode: _DirectiveFilterMode.hide,
          names: Set<String>.unmodifiable(
            combinator.hiddenNames.map((identifier) => identifier.name).toSet(),
          ),
        ),
      );
    }
  }

  return _DirectiveCombinators(
    exportsAllNames: showNames == null,
    filters: List<_DirectiveFilter>.unmodifiable(filters),
  );
}

int _lineForOffset(ParsedUnitResult result, int offset) {
  return result.lineInfo.getLocation(offset).lineNumber;
}

String? _declarationPrimaryName(CompilationUnitMember member) {
  return switch (member) {
    ClassDeclaration(:final name) => name.lexeme,
    EnumDeclaration(:final name) => name.lexeme,
    MixinDeclaration(:final name) => name.lexeme,
    ExtensionDeclaration(:final name?) => name.lexeme,
    ClassTypeAlias(:final name) => name.lexeme,
    GenericTypeAlias(:final name) => name.lexeme,
    FunctionDeclaration(:final name) => name.lexeme,
    _ => null,
  };
}

bool _shouldScanDeclaration({
  required CompilationUnitMember declaration,
  required _ExportedLibrarySurface surface,
  required _ExportedApiScanPolicy policy,
}) {
  final primaryName = _declarationPrimaryName(declaration);
  if (primaryName != null) {
    return _isScannableTopLevelName(
      primaryName,
      surface: surface,
      policy: policy,
    );
  }

  if (declaration is TopLevelVariableDeclaration) {
    return _hasScannableTopLevelVariable(
      declaration,
      surface: surface,
      policy: policy,
    );
  }

  return _isScannableUnnamedExtension(declaration, surface: surface);
}

bool _isScannableTopLevelName(
  String name, {
  required _ExportedLibrarySurface surface,
  required _ExportedApiScanPolicy policy,
}) {
  return _isPublicName(name) &&
      surface.exportsTopLevelName(name) &&
      !policy.skippedTopLevelNames.contains(name);
}

bool _hasScannableTopLevelVariable(
  TopLevelVariableDeclaration declaration, {
  required _ExportedLibrarySurface surface,
  required _ExportedApiScanPolicy policy,
}) {
  return declaration.variables.variables.any(
    (variable) => _isScannableTopLevelName(
      variable.name.lexeme,
      surface: surface,
      policy: policy,
    ),
  );
}

bool _isScannableUnnamedExtension(
  CompilationUnitMember declaration, {
  required _ExportedLibrarySurface surface,
}) {
  return declaration is ExtensionDeclaration &&
      declaration.name == null &&
      surface.exportsUnnamedExtensions;
}

Future<ParsedUnitResult> _parseUnitOrFail({
  required AnalysisContextCollection analysisCollection,
  required String absPath,
  required String filePathForDiag,
}) {
  final context = analysisCollection.contextFor(absPath);
  final result = context.currentSession.getParsedUnit(absPath);
  if (result is ParsedUnitResult) {
    return Future<ParsedUnitResult>.value(result);
  }
  _fail(
    _Violation(
      filePath: filePathForDiag,
      line: 1,
      message:
          'tool failure: unable to parse Dart unit (result: ${result.runtimeType})',
    ),
  );
}

bool _isPublicName(String name) => !name.startsWith('_');

AstNode? _firstMutableTypeInNode(AstNode? node, Set<String> bannedTypeNames) {
  if (node == null) {
    return null;
  }
  final visitor = _MutableTypeReferenceVisitor(bannedTypeNames);
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
    return;
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

AstNode? _firstMutableTypeInFunctionSignature({
  required TypeAnnotation? returnType,
  required TypeParameterList? typeParameters,
  required FormalParameterList? parameters,
  required Set<String> bannedTypeNames,
}) {
  final typeNodes = <AstNode?>[];
  typeNodes.add(returnType);
  _collectTypeNodesFromTypeParameters(typeParameters, typeNodes);
  _collectTypeNodesFromFormalParameterList(parameters, typeNodes);
  return _firstMutableTypeInNodes(typeNodes, bannedTypeNames);
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
    (variable) => _isPublicName(variable.name.lexeme),
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
  if (!_isPublicName(member.name.lexeme)) {
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
  if (constructorName != null && !_isPublicName(constructorName)) {
    return null;
  }
  final typeNodes = <AstNode?>[];
  _collectTypeNodesFromFormalParameterList(member.parameters, typeNodes);
  typeNodes.add(member.redirectedConstructor?.type);
  return _firstMutableTypeInNodes(typeNodes, bannedTypeNames);
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
  if (name != null && !_isPublicName(name)) {
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

AstNode? _firstMutableTypeInAliasSignature({
  required String name,
  required List<AstNode?> nodes,
  required Set<String> bannedTypeNames,
}) {
  if (!_isPublicName(name)) {
    return null;
  }
  return _firstMutableTypeInNodes(nodes, bannedTypeNames);
}

AstNode? _firstMutableTypeInTopLevelFunctionSignature(
  FunctionDeclaration member,
  Set<String> bannedTypeNames,
) {
  if (!_isPublicName(member.name.lexeme)) {
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
    (variable) => _isPublicName(variable.name.lexeme),
  );
  if (!hasPublicVariable) {
    return null;
  }
  return _firstMutableTypeInNode(member.variables.type, bannedTypeNames);
}

void _checkLibSrcStructuralGuardrails({
  required Directory root,
  required String rootAbsPosix,
}) {
  final srcRoot = Directory(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src',
  );
  if (!srcRoot.existsSync()) {
    return;
  }

  final violations = collectTopLevelLibSrcLayoutViolations(
    srcRoot: srcRoot,
    rootAbsPosixPath: rootAbsPosix,
    toPosixPath: _toPosixPath,
    toRepoRelPosixPath: _toRepoRelPosixPath,
  );
  if (violations.isEmpty) {
    return;
  }

  final violation = violations.first;
  _fail(
    _Violation(filePath: violation.path, line: 1, message: violation.message),
  );
}

Future<void> _checkExportedApiImports({
  required Directory root,
  required String packageName,
  required Iterable<String> exportedFiles,
  required AnalysisContextCollection analysisCollection,
}) async {
  final filesToCheck =
      exportedFiles
          .where(
            (path) =>
                path.startsWith('/lib/src/contract/') ||
                path == '/lib/src/model/scene_builder_api.dart',
          )
          .toList(growable: false)
        ..sort();
  if (filesToCheck.isEmpty) return;

  for (final filePosixPath in filesToCheck) {
    final absPath = _toPosixPath(
      _posixJoin(root.path, filePosixPath.substring(1)),
    );
    final file = File(absPath);
    if (!file.existsSync()) continue;

    final fileDirRepoRelPosix = _posixDirname(filePosixPath);
    final parsed = await _parseUnitOrFail(
      analysisCollection: analysisCollection,
      absPath: file.absolute.path,
      filePathForDiag: filePosixPath,
    );

    _checkExportedApiDirectives(
      parsed: parsed,
      packageName: packageName,
      filePosixPath: filePosixPath,
      fileDirRepoRelPosix: fileDirRepoRelPosix,
    );
  }
}

void _checkExportedApiDirectives({
  required ParsedUnitResult parsed,
  required String packageName,
  required String filePosixPath,
  required String fileDirRepoRelPosix,
}) {
  for (final directive in parsed.unit.directives) {
    final uriDirective = switch (directive) {
      ImportDirective() || ExportDirective() => directive as UriBasedDirective,
      _ => null,
    };
    if (uriDirective == null) {
      continue;
    }
    _checkExportedApiDirectiveTargets(
      directive: uriDirective,
      parsed: parsed,
      packageName: packageName,
      filePosixPath: filePosixPath,
      fileDirRepoRelPosix: fileDirRepoRelPosix,
    );
  }
}

void _checkExportedApiDirectiveTargets({
  required UriBasedDirective directive,
  required ParsedUnitResult parsed,
  required String packageName,
  required String filePosixPath,
  required String fileDirRepoRelPosix,
}) {
  for (final uriRef in _collectDirectiveUriRefs(directive)) {
    final resolvedRepoRelPosix = _resolveToRepoRelTargetPosix(
      targetPosix: _toPosixPath(uriRef.uri),
      packageName: packageName,
      fileDirRepoRelPosix: fileDirRepoRelPosix,
    );
    if (_isDisallowedExportedApiTarget(resolvedRepoRelPosix)) {
      _fail(
        _Violation(
          filePath: filePosixPath,
          line: _lineForOffset(parsed, uriRef.offset),
          message:
              'public export violation: exported contract/** and the '
              'model facade must not import/export controller/**, '
              'render/**, view/**, or serialization/** '
              '($resolvedRepoRelPosix)',
        ),
      );
    }
  }
}

bool _isDisallowedExportedApiTarget(String? resolvedRepoRelPosix) {
  if (resolvedRepoRelPosix == null) {
    return false;
  }
  return const <String>[
    '/lib/src/controller/',
    '/lib/src/render/',
    '/lib/src/view/',
    '/lib/src/serialization/',
  ].any(resolvedRepoRelPosix.startsWith);
}

Future<Map<String, _ExportedLibrarySurface>> _collectEntrypointExportSurfaces({
  required Directory root,
  required String rootAbsPosix,
  required String packageName,
  required AnalysisContextCollection analysisCollection,
}) async {
  final entrypointFile = File(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}iwb_canvas_engine.dart',
  );
  if (!entrypointFile.existsSync()) {
    return const <String, _ExportedLibrarySurface>{};
  }

  final entrypointAbsPosixPath = _toPosixPath(entrypointFile.absolute.path);
  final entrypointPosixPath = _toRepoRelPosixPath(
    absPosixPath: entrypointAbsPosixPath,
    rootAbsPosixPath: rootAbsPosix,
  );
  final entrypointDirRepoRelPosix = _posixDirname(entrypointPosixPath);
  final targets = <String, _ExportedLibrarySurface>{};

  final parsed = await _parseUnitOrFail(
    analysisCollection: analysisCollection,
    absPath: entrypointFile.absolute.path,
    filePathForDiag: entrypointPosixPath,
  );

  final combinatorsByTarget = _collectExportCombinatorsByTarget(
    parsed: parsed,
    packageName: packageName,
    entrypointDirRepoRelPosix: entrypointDirRepoRelPosix,
  );
  targets.addAll(_buildExportedLibrarySurfaces(combinatorsByTarget));
  return targets;
}

Map<String, List<_DirectiveCombinators>> _collectExportCombinatorsByTarget({
  required ParsedUnitResult parsed,
  required String packageName,
  required String entrypointDirRepoRelPosix,
}) {
  final combinatorsByTarget = <String, List<_DirectiveCombinators>>{};
  for (final directive in parsed.unit.directives.whereType<ExportDirective>()) {
    _recordExportDirectiveTargets(
      directive: directive,
      packageName: packageName,
      fileDirRepoRelPosix: entrypointDirRepoRelPosix,
      combinatorsByTarget: combinatorsByTarget,
    );
  }
  return combinatorsByTarget;
}

void _recordExportDirectiveTargets({
  required ExportDirective directive,
  required String packageName,
  required String fileDirRepoRelPosix,
  required Map<String, List<_DirectiveCombinators>> combinatorsByTarget,
}) {
  final directiveCombinators = _collectDirectiveCombinators(directive);
  for (final uriRef in _collectDirectiveUriRefs(directive)) {
    final resolvedRepoRelPosix = _resolveToRepoRelTargetPosix(
      targetPosix: _toPosixPath(uriRef.uri),
      packageName: packageName,
      fileDirRepoRelPosix: fileDirRepoRelPosix,
    );
    if (resolvedRepoRelPosix == null) {
      continue;
    }
    final existing = combinatorsByTarget.putIfAbsent(
      resolvedRepoRelPosix,
      () => <_DirectiveCombinators>[],
    );
    existing.add(directiveCombinators);
  }
}

Map<String, _ExportedLibrarySurface> _buildExportedLibrarySurfaces(
  Map<String, List<_DirectiveCombinators>> combinatorsByTarget,
) {
  final targets = <String, _ExportedLibrarySurface>{};
  for (final MapEntry(key: target, value: combinators)
      in combinatorsByTarget.entries) {
    targets[target] = _ExportedLibrarySurface(
      repoRelPath: target,
      directiveCombinators: List<_DirectiveCombinators>.unmodifiable(
        combinators,
      ),
    );
  }
  return targets;
}

Future<Map<String, _ExportedLibrarySurface>> _checkEntrypointGuardrails({
  required Directory root,
  required String rootAbsPosix,
  required String packageName,
  required AnalysisContextCollection analysisCollection,
}) async {
  final exports = await _collectEntrypointExportSurfaces(
    root: root,
    rootAbsPosix: rootAbsPosix,
    packageName: packageName,
    analysisCollection: analysisCollection,
  );
  if (exports.isEmpty) {
    return exports;
  }

  const forbiddenExports = <String>{
    '/lib/src/core/scene.dart',
    '/lib/src/core/nodes.dart',
  };
  for (final path in forbiddenExports) {
    if (exports.containsKey(path)) {
      _fail(
        _Violation(
          filePath: '/lib/iwb_canvas_engine.dart',
          line: 1,
          message:
              'public export violation: lib/iwb_canvas_engine.dart must not '
              'export mutable core model ($path).',
        ),
      );
    }
  }
  return exports;
}

Future<void> _checkRootLibFilesAreExportOnly({
  required Directory root,
  required String rootAbsPosix,
  required AnalysisContextCollection analysisCollection,
}) async {
  final libDir = Directory('${root.path}${Platform.pathSeparator}lib');
  if (!libDir.existsSync()) return;

  final rootLibFiles =
      libDir
          .listSync(recursive: false, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList(growable: false)
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in rootLibFiles) {
    final filePosixPath = _toRepoRelPosixPath(
      absPosixPath: _toPosixPath(file.absolute.path),
      rootAbsPosixPath: rootAbsPosix,
    );
    _failForAdditionalRootEntrypoint(filePosixPath);
    final parsed = await _parseUnitOrFail(
      analysisCollection: analysisCollection,
      absPath: file.absolute.path,
      filePathForDiag: filePosixPath,
    );
    _checkRootLibFileContents(parsed: parsed, filePosixPath: filePosixPath);
  }
}

void _failForAdditionalRootEntrypoint(String filePosixPath) {
  if (filePosixPath == '/lib/iwb_canvas_engine.dart') {
    return;
  }
  _fail(
    _Violation(
      filePath: filePosixPath,
      line: 1,
      message:
          'public entrypoint violation: root lib/*.dart files must not '
          'introduce additional entrypoints; '
          'lib/iwb_canvas_engine.dart is the only supported root entrypoint.',
    ),
  );
}

void _checkRootLibFileContents({
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  Directive? invalidDirective;
  for (final directive in parsed.unit.directives) {
    if (directive is LibraryDirective || directive is ExportDirective) {
      continue;
    }
    invalidDirective = directive;
    break;
  }
  if (invalidDirective != null) {
    _failForNonExportOnlyRootLibNode(
      filePosixPath: filePosixPath,
      parsed: parsed,
      offset: invalidDirective.offset,
    );
  }
  if (parsed.unit.declarations.isNotEmpty) {
    _failForNonExportOnlyRootLibNode(
      filePosixPath: filePosixPath,
      parsed: parsed,
      offset: parsed.unit.declarations.first.offset,
    );
  }
}

void _failForNonExportOnlyRootLibNode({
  required String filePosixPath,
  required ParsedUnitResult parsed,
  required int offset,
}) {
  _fail(
    _Violation(
      filePath: filePosixPath,
      line: _lineForOffset(parsed, offset),
      message:
          'public entrypoint violation: root lib/*.dart files must '
          'contain only library/docs/comments/export directives.',
    ),
  );
}

void _checkSceneWriteTxnMember({
  required ClassMember member,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  final memberName = _sceneWriteTxnMemberName(member);
  if (memberName == null || !_isPublicName(memberName)) {
    return;
  }

  _failForSceneWriteTxnViolation(
    memberName: memberName,
    parsed: parsed,
    filePosixPath: filePosixPath,
    offset: member.offset,
  );
}

String? _sceneWriteTxnMemberName(ClassMember member) {
  if (member is MethodDeclaration) {
    return member.name.lexeme;
  }
  if (member is! FieldDeclaration) {
    return null;
  }
  for (final variable in member.fields.variables) {
    final name = variable.name.lexeme;
    if (_isPublicName(name)) {
      return name;
    }
  }
  return null;
}

void _failForSceneWriteTxnViolation({
  required String memberName,
  required ParsedUnitResult parsed,
  required String filePosixPath,
  required int offset,
}) {
  final message = _sceneWriteTxnViolationMessage(memberName);
  if (message == null) {
    return;
  }
  _fail(
    _Violation(
      filePath: filePosixPath,
      line: _lineForOffset(parsed, offset),
      message: message,
    ),
  );
}

String? _sceneWriteTxnViolationMessage(String memberName) {
  if (memberName == 'scene') {
    return 'public contract violation: exported SceneWriteTxn must not '
        'expose raw scene access.';
  }
  if (memberName == 'writeFindNode') {
    return 'public contract violation: exported SceneWriteTxn must not '
        'expose writeFindNode.';
  }
  if (RegExp(r'^writeMark[A-Za-z0-9_]*$').hasMatch(memberName)) {
    return 'public contract violation: exported SceneWriteTxn must not '
        'expose writeMark* escape hatches.';
  }
  if (_nodeIdBookkeepingNames.contains(memberName)) {
    return 'public contract violation: exported SceneWriteTxn must not '
        'expose node-id bookkeeping methods.';
  }
  return null;
}

Future<void> _checkSceneWriteTxnContract({
  required Directory root,
  required String rootAbsPosix,
  required AnalysisContextCollection analysisCollection,
}) async {
  final txnApiFile = File(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src${Platform.pathSeparator}contract${Platform.pathSeparator}scene_write_txn.dart',
  );
  if (!txnApiFile.existsSync()) return;

  final fileAbsPosixPath = _toPosixPath(txnApiFile.absolute.path);
  final filePosixPath = _toRepoRelPosixPath(
    absPosixPath: fileAbsPosixPath,
    rootAbsPosixPath: rootAbsPosix,
  );

  final parsed = await _parseUnitOrFail(
    analysisCollection: analysisCollection,
    absPath: txnApiFile.absolute.path,
    filePathForDiag: filePosixPath,
  );

  for (final declaration in parsed.unit.declarations) {
    if (declaration is! ClassDeclaration) {
      continue;
    }
    if (declaration.name.lexeme != 'SceneWriteTxn') {
      continue;
    }

    for (final member in declaration.members) {
      _checkSceneWriteTxnMember(
        member: member,
        parsed: parsed,
        filePosixPath: filePosixPath,
      );
    }
    return;
  }
}

Future<void> _checkExportedApiMutableTypeLeak({
  required Directory root,
  required Map<String, _ExportedLibrarySurface> exportedSurfaces,
  required AnalysisContextCollection analysisCollection,
}) async {
  if (exportedSurfaces.isEmpty) return;
  final exportedFiles = exportedSurfaces.keys.toSet();
  _validateExportedApiScanPolicies(exportedFiles);
  final filesToCheck = _mutableLeakScanTargets(exportedFiles);
  if (filesToCheck.isEmpty) return;

  for (final repoRel in filesToCheck) {
    final surface = exportedSurfaces[repoRel];
    if (surface == null) {
      continue;
    }
    final policy =
        _nonContractExportedApiScanPolicies[repoRel] ??
        const _ExportedApiScanPolicy.fullScan();
    final absPath = _toPosixPath(_posixJoin(root.path, repoRel.substring(1)));
    final file = File(absPath);
    if (!file.existsSync()) continue;

    final parsed = await _parseUnitOrFail(
      analysisCollection: analysisCollection,
      absPath: file.absolute.path,
      filePathForDiag: repoRel,
    );
    _scanLibraryForMutableTypeLeak(
      parsed: parsed,
      repoRel: repoRel,
      surface: surface,
      policy: policy,
    );
  }
}

void _validateExportedApiScanPolicies(Set<String> exportedFiles) {
  final policyKeys = _nonContractExportedApiScanPolicies.keys.toSet();
  final nonContractExportSet = exportedFiles
      .where((path) => !path.startsWith('/lib/src/contract/'))
      .toSet();
  _failForMissingExportedApiPolicies(nonContractExportSet, policyKeys);
  _failForStaleExportedApiPolicies(nonContractExportSet, policyKeys);
}

void _failForMissingExportedApiPolicies(
  Set<String> nonContractExportSet,
  Set<String> policyKeys,
) {
  final missingPolicyEntries =
      nonContractExportSet.difference(policyKeys).toList(growable: false)
        ..sort();
  if (missingPolicyEntries.isEmpty) {
    return;
  }
  final path = missingPolicyEntries.first;
  _fail(
    _Violation(
      filePath: '/lib/iwb_canvas_engine.dart',
      line: 1,
      message:
          'public entrypoint violation: exported API owner $path must '
          'declare a mutable-type leak scan policy in '
          'tool/check_guardrails.dart.',
    ),
  );
}

void _failForStaleExportedApiPolicies(
  Set<String> nonContractExportSet,
  Set<String> policyKeys,
) {
  final stalePolicyEntries =
      policyKeys.difference(nonContractExportSet).toList(growable: false)
        ..sort();
  if (stalePolicyEntries.isEmpty) {
    return;
  }
  final path = stalePolicyEntries.first;
  final policy = _nonContractExportedApiScanPolicies[path]!;
  final reasonSuffix =
      policy.mode == _ExportedApiScanMode.targetedSkip && policy.reason != null
      ? ' Remove or update this targeted skip: ${policy.reason}.'
      : '';
  _fail(
    _Violation(
      filePath: '/lib/iwb_canvas_engine.dart',
      line: 1,
      message:
          'public entrypoint violation: exported API policy entry $path is '
          'stale because lib/iwb_canvas_engine.dart no longer exports it.'
          '$reasonSuffix',
    ),
  );
}

List<String> _mutableLeakScanTargets(Set<String> exportedFiles) {
  return exportedFiles
      .where(
        (path) =>
            path.startsWith('/lib/src/contract/') ||
            _nonContractExportedApiScanPolicies.containsKey(path),
      )
      .toList(growable: false)
    ..sort();
}

void _scanLibraryForMutableTypeLeak({
  required ParsedUnitResult parsed,
  required String repoRel,
  required _ExportedLibrarySurface surface,
  required _ExportedApiScanPolicy policy,
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
    _fail(
      _Violation(
        filePath: repoRel,
        line: _lineForOffset(parsed, mutableTypeMatch.offset),
        message:
            'public contract violation: exported API must not expose '
            'mutable core types '
            '(Scene/ContentLayer/SceneNode/NodeType).',
      ),
    );
  }
}

AstNode? _mutableTypeLeakInDeclaration(
  CompilationUnitMember declaration, {
  required _ExportedLibrarySurface surface,
  required _ExportedApiScanPolicy policy,
}) {
  if (!_shouldScanDeclaration(
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

String? _interactiveEntrypointName(ClassMember member) {
  if (member is! MethodDeclaration) {
    return null;
  }
  if (member.isStatic || member.isGetter) {
    return null;
  }
  final name = member.name.lexeme;
  if (!_isPublicName(name) || name == 'SceneControllerInteractive') {
    return null;
  }
  return name;
}

_EnsureCallInfo? _ensureCallInfoFromExpression(Expression expression) {
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

  return _EnsureCallInfo(hasAllowAfterDispose: hasAllowAfterDispose);
}

void _checkInteractiveEntrypointGuard({
  required MethodDeclaration member,
  required String name,
  required ParsedUnitResult parsed,
  required String filePath,
}) {
  final guardContext = _interactiveGuardContext(
    member: member,
    parsed: parsed,
    filePath: filePath,
  );
  if (guardContext == null) {
    return;
  }
  final ensureCallInfo = _ensureCallInfoFromExpression(
    guardContext.expressionStatement.expression,
  );
  _failIfInteractiveEnsureMissing(
    ensureCallInfo,
    parsed: parsed,
    filePath: filePath,
    offset: guardContext.firstStatement.offset,
  );
  if (ensureCallInfo == null) {
    return;
  }
  _validateAllowAfterDisposeUsage(
    name: name,
    ensureCallInfo: ensureCallInfo,
    parsed: parsed,
    filePath: filePath,
    offset: guardContext.firstStatement.offset,
  );
}

_InteractiveGuardContext? _interactiveGuardContext({
  required MethodDeclaration member,
  required ParsedUnitResult parsed,
  required String filePath,
}) {
  final body = member.body;
  _failIfInteractiveBodyIsNotBlock(
    body: body,
    parsed: parsed,
    filePath: filePath,
    offset: member.offset,
    name: member.name.lexeme,
  );
  if (body is! BlockFunctionBody) {
    return null;
  }
  final statements = body.block.statements;
  _failIfInteractiveStatementsUngarded(
    statements.isEmpty,
    parsed: parsed,
    filePath: filePath,
    offset: member.offset,
  );
  if (statements.isEmpty) {
    return null;
  }
  final firstStatement = statements.first;
  _failIfInteractiveFirstStatementInvalid(
    firstStatement,
    parsed: parsed,
    filePath: filePath,
  );
  if (firstStatement is! ExpressionStatement) {
    return null;
  }
  return _InteractiveGuardContext(
    firstStatement: firstStatement,
    expressionStatement: firstStatement,
  );
}

void _failIfInteractiveBodyIsNotBlock({
  required FunctionBody body,
  required ParsedUnitResult parsed,
  required String filePath,
  required int offset,
  required String name,
}) {
  if (body is BlockFunctionBody) {
    return;
  }
  _fail(
    _Violation(
      filePath: filePath,
      line: _lineForOffset(parsed, offset),
      message:
          'interactive API violation: public SceneControllerInteractive '
          'entrypoint "$name" must use a block body guarded by '
          '_ensurePublicSideEffectAllowed(...).',
    ),
  );
}

void _failIfInteractiveStatementsUngarded(
  bool condition, {
  required ParsedUnitResult parsed,
  required String filePath,
  required int offset,
}) {
  if (!condition) {
    return;
  }
  _fail(_interactiveGuardViolation(parsed, filePath, offset));
}

void _failIfInteractiveFirstStatementInvalid(
  Statement firstStatement, {
  required ParsedUnitResult parsed,
  required String filePath,
}) {
  if (firstStatement is ExpressionStatement) {
    return;
  }
  _fail(_interactiveGuardViolation(parsed, filePath, firstStatement.offset));
}

void _failIfInteractiveEnsureMissing(
  _EnsureCallInfo? ensureCallInfo, {
  required ParsedUnitResult parsed,
  required String filePath,
  required int offset,
}) {
  if (ensureCallInfo != null) {
    return;
  }
  _fail(_interactiveGuardViolation(parsed, filePath, offset));
}

_Violation _interactiveGuardViolation(
  ParsedUnitResult parsed,
  String filePath,
  int offset,
) {
  return _Violation(
    filePath: filePath,
    line: _lineForOffset(parsed, offset),
    message:
        'interactive API violation: public SceneControllerInteractive '
        'entrypoints must guard resolver purity with '
        '_ensurePublicSideEffectAllowed(...).',
  );
}

void _validateAllowAfterDisposeUsage({
  required String name,
  required _EnsureCallInfo ensureCallInfo,
  required ParsedUnitResult parsed,
  required String filePath,
  required int offset,
}) {
  if (name == 'dispose') {
    if (!ensureCallInfo.hasAllowAfterDispose) {
      _fail(
        _Violation(
          filePath: filePath,
          line: _lineForOffset(parsed, offset),
          message:
              'interactive API violation: dispose() must guard resolver '
              'purity with allowAfterDispose: true.',
        ),
      );
    }
    return;
  }
  if (ensureCallInfo.hasAllowAfterDispose) {
    _fail(
      _Violation(
        filePath: filePath,
        line: _lineForOffset(parsed, offset),
        message:
            'interactive API violation: only dispose() may call '
            '_ensurePublicSideEffectAllowed(..., allowAfterDispose: true).',
      ),
    );
  }
}

Future<void> _checkInteractiveResolverPurityGuardrails({
  required Directory root,
  required String rootAbsPosix,
  required AnalysisContextCollection analysisCollection,
}) async {
  final file = File(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src${Platform.pathSeparator}interactive${Platform.pathSeparator}scene_controller_interactive.dart',
  );
  if (!file.existsSync()) {
    return;
  }

  final filePosixPath = _toRepoRelPosixPath(
    absPosixPath: _toPosixPath(file.absolute.path),
    rootAbsPosixPath: rootAbsPosix,
  );

  final parsed = await _parseUnitOrFail(
    analysisCollection: analysisCollection,
    absPath: file.absolute.path,
    filePathForDiag: filePosixPath,
  );

  ClassDeclaration? interactiveClass;
  for (final declaration in parsed.unit.declarations) {
    if (declaration is ClassDeclaration &&
        declaration.name.lexeme == 'SceneControllerInteractive') {
      interactiveClass = declaration;
      break;
    }
  }
  if (interactiveClass == null) {
    return;
  }

  for (final member in interactiveClass.members) {
    final name = _interactiveEntrypointName(member);
    if (name == null) {
      continue;
    }
    _checkInteractiveEntrypointGuard(
      member: member as MethodDeclaration,
      name: name,
      parsed: parsed,
      filePath: filePosixPath,
    );
  }
}

Future<void> _checkControllerGuardrails({
  required Directory root,
  required String rootAbsPosix,
  required AnalysisContextCollection analysisCollection,
}) async {
  final controllerDir = Directory(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}src${Platform.pathSeparator}controller',
  );
  if (!controllerDir.existsSync()) return;

  final dartFiles =
      controllerDir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList(growable: false)
        ..sort((a, b) => a.path.compareTo(b.path));
  if (dartFiles.isEmpty) return;

  var hasControllerEpoch = false;

  for (final file in dartFiles) {
    final hasEpochInFile = await _checkControllerFileGuardrails(
      file: file,
      rootAbsPosix: rootAbsPosix,
      analysisCollection: analysisCollection,
    );
    if (hasEpochInFile) {
      hasControllerEpoch = true;
    }
  }

  _failIfControllerEpochMissing(hasControllerEpoch);
}

Future<bool> _checkControllerFileGuardrails({
  required File file,
  required String rootAbsPosix,
  required AnalysisContextCollection analysisCollection,
}) async {
  final filePosixPath = _toRepoRelPosixPath(
    absPosixPath: _toPosixPath(file.absolute.path),
    rootAbsPosixPath: rootAbsPosix,
  );
  final parsed = await _parseUnitOrFail(
    analysisCollection: analysisCollection,
    absPath: file.absolute.path,
    filePathForDiag: filePosixPath,
  );
  final collector = _ControllerSymbolCollector();
  parsed.unit.accept(collector);
  _failForMissingEpochOnReplaceScene(
    collector: collector,
    parsed: parsed,
    filePosixPath: filePosixPath,
  );
  _failForUnroutedMutatingSymbols(
    collector: collector,
    parsed: parsed,
    filePosixPath: filePosixPath,
  );
  return collector.hasControllerEpoch;
}

void _failForMissingEpochOnReplaceScene({
  required _ControllerSymbolCollector collector,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  final replaceSceneOccurrence = collector.occurrences.firstWhere(
    (occurrence) => occurrence.name == 'replaceScene',
    orElse: () => const _ControllerSymbolOccurrence(name: '', offset: -1),
  );
  if (replaceSceneOccurrence.offset == -1 || collector.hasControllerEpoch) {
    return;
  }
  _fail(
    _Violation(
      filePath: filePosixPath,
      line: _lineForOffset(parsed, replaceSceneOccurrence.offset),
      message:
          'controller API violation: replaceScene-like entrypoints '
          'must preserve epoch invalidation '
          '(missing controllerEpoch usage in file)',
    ),
  );
}

void _failForUnroutedMutatingSymbols({
  required _ControllerSymbolCollector collector,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  for (final occurrence in collector.occurrences) {
    if (_isAllowedControllerOccurrence(occurrence.name)) {
      continue;
    }
    if (_looksMutatingSymbol(occurrence.name)) {
      _fail(
        _Violation(
          filePath: filePosixPath,
          line: _lineForOffset(parsed, occurrence.offset),
          message:
              'controller API violation: mutating symbol "${occurrence.name}" '
              'must be routed through write*/txn* transaction API',
        ),
      );
    }
  }
}

bool _isAllowedControllerOccurrence(String symbol) {
  if (const <String>{
    'if',
    'for',
    'while',
    'switch',
    'assert',
    'return',
    'super',
    'this',
  }.contains(symbol)) {
    return true;
  }
  return const <String>['write', 'txn'].any(symbol.startsWith);
}

void _failIfControllerEpochMissing(bool hasControllerEpoch) {
  if (hasControllerEpoch) {
    return;
  }
  _fail(
    _Violation(
      filePath: '/lib/src/controller',
      line: 1,
      message:
          'controller API violation: controllerEpoch symbol is required '
          'for epoch invalidation guardrails',
    ),
  );
}

Future<void> _runGuardrails() async {
  final root = Directory.current;
  final rootAbsPosix = _toPosixPath(root.absolute.path);
  final packageName = _readPackageNameOrFallback(root);
  final analysisCollection = AnalysisContextCollection(
    includedPaths: <String>[root.absolute.path],
  );
  _checkLibSrcStructuralGuardrails(root: root, rootAbsPosix: rootAbsPosix);
  final exportedFiles = await _checkEntrypointGuardrails(
    root: root,
    rootAbsPosix: rootAbsPosix,
    packageName: packageName,
    analysisCollection: analysisCollection,
  );
  await _runPublicSurfaceGuardrails(
    root: root,
    rootAbsPosix: rootAbsPosix,
    packageName: packageName,
    analysisCollection: analysisCollection,
    exportedFiles: exportedFiles,
  );
  await _checkInteractiveResolverPurityGuardrails(
    root: root,
    rootAbsPosix: rootAbsPosix,
    analysisCollection: analysisCollection,
  );
  await _checkControllerGuardrails(
    root: root,
    rootAbsPosix: rootAbsPosix,
    analysisCollection: analysisCollection,
  );
}

Future<void> _runPublicSurfaceGuardrails({
  required Directory root,
  required String rootAbsPosix,
  required String packageName,
  required AnalysisContextCollection analysisCollection,
  required Map<String, _ExportedLibrarySurface> exportedFiles,
}) async {
  await _checkExportedApiImports(
    root: root,
    packageName: packageName,
    exportedFiles: exportedFiles.keys,
    analysisCollection: analysisCollection,
  );
  await _checkRootLibFilesAreExportOnly(
    root: root,
    rootAbsPosix: rootAbsPosix,
    analysisCollection: analysisCollection,
  );
  await _checkSceneWriteTxnContract(
    root: root,
    rootAbsPosix: rootAbsPosix,
    analysisCollection: analysisCollection,
  );
  await _checkExportedApiMutableTypeLeak(
    root: root,
    exportedSurfaces: exportedFiles,
    analysisCollection: analysisCollection,
  );
}

Future<void> main(List<String> _) async {
  await _runGuardrails();
  stdout.writeln('OK: guardrails');
}
