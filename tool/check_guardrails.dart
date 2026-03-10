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

enum _ExportedApiScanMode { fullScan, skip }

class _ExportedApiScanPolicy {
  const _ExportedApiScanPolicy.fullScan()
    : mode = _ExportedApiScanMode.fullScan,
      reason = null;

  const _ExportedApiScanPolicy.skip(this.reason)
    : mode = _ExportedApiScanMode.skip;

  final _ExportedApiScanMode mode;
  final String? reason;
}

class _EnsureCallInfo {
  const _EnsureCallInfo({required this.hasAllowAfterDispose});

  final bool hasAllowAfterDispose;
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
      _ExportedApiScanPolicy.skip(
        'interactive controller entrypoints expose stateful runtime behavior '
        'that is guarded by dedicated API checks instead of regex signature '
        'scans',
      ),
  '/lib/src/view/scene_view_interactive.dart': _ExportedApiScanPolicy.skip(
    'view widgets expose framework UI types that are outside the mutable core '
    'model leak scan',
  ),
  '/lib/src/serialization/scene_codec.dart': _ExportedApiScanPolicy.skip(
    'serialization exports are function entrypoints validated by codec tests, '
    'not contract-style type signatures',
  ),
};

const _mutableCoreTypeNames = <String>{
  'Scene',
  'ContentLayer',
  'SceneNode',
  'NodeType',
};

const _nodeIdBookkeepingNames = <String>{
  'writeNewNodeId',
  'writeContainsNodeId',
  'writeRegisterNodeId',
  'writeUnregisterNodeId',
  'writeRebuildNodeIdIndex',
};

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

int _lineForOffset(ParsedUnitResult result, int offset) {
  return result.lineInfo.getLocation(offset).lineNumber;
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

AstNode? _firstMutableTypeInNode(AstNode? node) {
  if (node == null) {
    return null;
  }
  final visitor = _MutableTypeReferenceVisitor(_mutableCoreTypeNames);
  node.accept(visitor);
  return visitor.firstMatch;
}

AstNode? _firstMutableTypeInNodes(Iterable<AstNode?> nodes) {
  for (final node in nodes) {
    final match = _firstMutableTypeInNode(node);
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
}) {
  final typeNodes = <AstNode?>[];
  typeNodes.add(returnType);
  _collectTypeNodesFromTypeParameters(typeParameters, typeNodes);
  _collectTypeNodesFromFormalParameterList(parameters, typeNodes);
  return _firstMutableTypeInNodes(typeNodes);
}

AstNode? _firstMutableTypeInClassMemberSignature(ClassMember member) {
  if (member is FieldDeclaration) {
    final hasPublicVariable = member.fields.variables.any(
      (variable) => _isPublicName(variable.name.lexeme),
    );
    if (!hasPublicVariable) {
      return null;
    }
    return _firstMutableTypeInNode(member.fields.type);
  }

  if (member is MethodDeclaration) {
    if (!_isPublicName(member.name.lexeme)) {
      return null;
    }
    if (member.isGetter) {
      return _firstMutableTypeInNode(member.returnType);
    }
    if (member.isSetter) {
      return _firstMutableTypeInFunctionSignature(
        returnType: null,
        typeParameters: null,
        parameters: member.parameters,
      );
    }
    return _firstMutableTypeInFunctionSignature(
      returnType: member.returnType,
      typeParameters: member.typeParameters,
      parameters: member.parameters,
    );
  }

  if (member is ConstructorDeclaration) {
    final constructorName = member.name?.lexeme;
    if (constructorName != null && !_isPublicName(constructorName)) {
      return null;
    }
    final typeNodes = <AstNode?>[];
    _collectTypeNodesFromFormalParameterList(member.parameters, typeNodes);
    typeNodes.add(member.redirectedConstructor?.type);
    return _firstMutableTypeInNodes(typeNodes);
  }

  return null;
}

AstNode? _firstMutableTypeInDeclarationSignature(CompilationUnitMember member) {
  if (member is ClassDeclaration) {
    if (!_isPublicName(member.name.lexeme)) {
      return null;
    }
    final declarationMatch = _firstMutableTypeInNodes(<AstNode?>[
      member.typeParameters,
      member.extendsClause,
      member.withClause,
      member.implementsClause,
    ]);
    if (declarationMatch != null) {
      return declarationMatch;
    }
    for (final classMember in member.members) {
      final memberMatch = _firstMutableTypeInClassMemberSignature(classMember);
      if (memberMatch != null) {
        return memberMatch;
      }
    }
    return null;
  }

  if (member is EnumDeclaration) {
    if (!_isPublicName(member.name.lexeme)) {
      return null;
    }
    final declarationMatch = _firstMutableTypeInNodes(<AstNode?>[
      member.withClause,
      member.implementsClause,
    ]);
    if (declarationMatch != null) {
      return declarationMatch;
    }
    for (final enumMember in member.members) {
      final memberMatch = _firstMutableTypeInClassMemberSignature(enumMember);
      if (memberMatch != null) {
        return memberMatch;
      }
    }
    return null;
  }

  if (member is MixinDeclaration) {
    if (!_isPublicName(member.name.lexeme)) {
      return null;
    }
    final declarationMatch = _firstMutableTypeInNodes(<AstNode?>[
      member.typeParameters,
      member.onClause,
      member.implementsClause,
    ]);
    if (declarationMatch != null) {
      return declarationMatch;
    }
    for (final mixinMember in member.members) {
      final memberMatch = _firstMutableTypeInClassMemberSignature(mixinMember);
      if (memberMatch != null) {
        return memberMatch;
      }
    }
    return null;
  }

  if (member is ExtensionDeclaration) {
    final extensionName = member.name?.lexeme;
    if (extensionName != null && !_isPublicName(extensionName)) {
      return null;
    }
    final declarationMatch = _firstMutableTypeInNodes(<AstNode?>[
      member.typeParameters,
      member.onClause,
    ]);
    if (declarationMatch != null) {
      return declarationMatch;
    }
    for (final extensionMember in member.members) {
      final memberMatch = _firstMutableTypeInClassMemberSignature(
        extensionMember,
      );
      if (memberMatch != null) {
        return memberMatch;
      }
    }
    return null;
  }

  if (member is ClassTypeAlias) {
    if (!_isPublicName(member.name.lexeme)) {
      return null;
    }
    return _firstMutableTypeInNodes(<AstNode?>[
      member.typeParameters,
      member.superclass,
      member.withClause,
      member.implementsClause,
    ]);
  }

  if (member is GenericTypeAlias) {
    if (!_isPublicName(member.name.lexeme)) {
      return null;
    }
    return _firstMutableTypeInNodes(<AstNode?>[
      member.typeParameters,
      member.functionType,
    ]);
  }

  if (member is FunctionDeclaration) {
    if (!_isPublicName(member.name.lexeme)) {
      return null;
    }
    if (member.isGetter) {
      return _firstMutableTypeInNode(member.returnType);
    }
    if (member.isSetter) {
      return _firstMutableTypeInFunctionSignature(
        returnType: null,
        typeParameters: null,
        parameters: member.functionExpression.parameters,
      );
    }
    return _firstMutableTypeInFunctionSignature(
      returnType: member.returnType,
      typeParameters: member.functionExpression.typeParameters,
      parameters: member.functionExpression.parameters,
    );
  }

  if (member is TopLevelVariableDeclaration) {
    final hasPublicVariable = member.variables.variables.any(
      (variable) => _isPublicName(variable.name.lexeme),
    );
    if (!hasPublicVariable) {
      return null;
    }
    return _firstMutableTypeInNode(member.variables.type);
  }

  return null;
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
  required Set<String> exportedFiles,
  required AnalysisContextCollection analysisCollection,
}) async {
  final disallowedPrefixes = <String>[
    '/lib/src/controller/',
    '/lib/src/render/',
    '/lib/src/view/',
    '/lib/src/serialization/',
  ];

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

    for (final directive in parsed.unit.directives) {
      if (directive is! ImportDirective && directive is! ExportDirective) {
        continue;
      }
      final uriDirective = directive as UriBasedDirective;
      for (final uriRef in _collectDirectiveUriRefs(uriDirective)) {
        final resolvedRepoRelPosix = _resolveToRepoRelTargetPosix(
          targetPosix: _toPosixPath(uriRef.uri),
          packageName: packageName,
          fileDirRepoRelPosix: fileDirRepoRelPosix,
        );
        if (resolvedRepoRelPosix == null) continue;
        final isDisallowed = disallowedPrefixes.any(
          resolvedRepoRelPosix.startsWith,
        );
        if (isDisallowed) {
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
  }
}

Future<Set<String>> _collectEntrypointExportTargets({
  required Directory root,
  required String rootAbsPosix,
  required String packageName,
  required AnalysisContextCollection analysisCollection,
}) async {
  final entrypointFile = File(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}iwb_canvas_engine.dart',
  );
  if (!entrypointFile.existsSync()) {
    return const <String>{};
  }

  final entrypointAbsPosixPath = _toPosixPath(entrypointFile.absolute.path);
  final entrypointPosixPath = _toRepoRelPosixPath(
    absPosixPath: entrypointAbsPosixPath,
    rootAbsPosixPath: rootAbsPosix,
  );
  final entrypointDirRepoRelPosix = _posixDirname(entrypointPosixPath);
  final targets = <String>{};

  final parsed = await _parseUnitOrFail(
    analysisCollection: analysisCollection,
    absPath: entrypointFile.absolute.path,
    filePathForDiag: entrypointPosixPath,
  );

  for (final directive in parsed.unit.directives.whereType<ExportDirective>()) {
    for (final uriRef in _collectDirectiveUriRefs(directive)) {
      final resolvedRepoRelPosix = _resolveToRepoRelTargetPosix(
        targetPosix: _toPosixPath(uriRef.uri),
        packageName: packageName,
        fileDirRepoRelPosix: entrypointDirRepoRelPosix,
      );
      if (resolvedRepoRelPosix != null) {
        targets.add(resolvedRepoRelPosix);
      }
    }
  }
  return targets;
}

Future<Set<String>> _checkEntrypointGuardrails({
  required Directory root,
  required String rootAbsPosix,
  required String packageName,
  required AnalysisContextCollection analysisCollection,
}) async {
  final advancedFile = File(
    '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}advanced.dart',
  );
  if (advancedFile.existsSync()) {
    _fail(
      _Violation(
        filePath: '/lib/advanced.dart',
        line: 1,
        message:
            'public entrypoint violation: advanced.dart is forbidden; '
            'lib/iwb_canvas_engine.dart is the only supported root entrypoint.',
      ),
    );
  }

  final exports = await _collectEntrypointExportTargets(
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
    if (exports.contains(path)) {
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
    final parsed = await _parseUnitOrFail(
      analysisCollection: analysisCollection,
      absPath: file.absolute.path,
      filePathForDiag: filePosixPath,
    );

    for (final directive in parsed.unit.directives) {
      if (directive is LibraryDirective || directive is ExportDirective) {
        continue;
      }
      _fail(
        _Violation(
          filePath: filePosixPath,
          line: _lineForOffset(parsed, directive.offset),
          message:
              'public entrypoint violation: root lib/*.dart files must '
              'contain only library/docs/comments/export directives.',
        ),
      );
    }

    if (parsed.unit.declarations.isNotEmpty) {
      final declaration = parsed.unit.declarations.first;
      _fail(
        _Violation(
          filePath: filePosixPath,
          line: _lineForOffset(parsed, declaration.offset),
          message:
              'public entrypoint violation: root lib/*.dart files must '
              'contain only library/docs/comments/export directives.',
        ),
      );
    }
  }
}

void _checkSceneWriteTxnMember({
  required ClassMember member,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  String? memberName;
  if (member is MethodDeclaration) {
    memberName = member.name.lexeme;
  } else if (member is FieldDeclaration) {
    for (final variable in member.fields.variables) {
      final name = variable.name.lexeme;
      if (!_isPublicName(name)) {
        continue;
      }
      memberName = name;
      break;
    }
  }

  if (memberName == null || !_isPublicName(memberName)) {
    return;
  }

  if (memberName == 'scene') {
    _fail(
      _Violation(
        filePath: filePosixPath,
        line: _lineForOffset(parsed, member.offset),
        message:
            'public contract violation: exported SceneWriteTxn must not '
            'expose raw scene access.',
      ),
    );
  }

  if (memberName == 'writeFindNode') {
    _fail(
      _Violation(
        filePath: filePosixPath,
        line: _lineForOffset(parsed, member.offset),
        message:
            'public contract violation: exported SceneWriteTxn must not '
            'expose writeFindNode.',
      ),
    );
  }

  if (RegExp(r'^writeMark[A-Za-z0-9_]*$').hasMatch(memberName)) {
    _fail(
      _Violation(
        filePath: filePosixPath,
        line: _lineForOffset(parsed, member.offset),
        message:
            'public contract violation: exported SceneWriteTxn must not '
            'expose writeMark* escape hatches.',
      ),
    );
  }

  if (_nodeIdBookkeepingNames.contains(memberName)) {
    _fail(
      _Violation(
        filePath: filePosixPath,
        line: _lineForOffset(parsed, member.offset),
        message:
            'public contract violation: exported SceneWriteTxn must not '
            'expose node-id bookkeeping methods.',
      ),
    );
  }
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
  required Set<String> exportedFiles,
  required AnalysisContextCollection analysisCollection,
}) async {
  if (exportedFiles.isEmpty) return;
  final policyKeys = _nonContractExportedApiScanPolicies.keys.toSet();
  final nonContractExports = exportedFiles
      .where((path) => !path.startsWith('/lib/src/contract/'))
      .toList(growable: false);
  final nonContractExportSet = nonContractExports.toSet();
  final missingPolicyEntries =
      nonContractExportSet.difference(policyKeys).toList(growable: false)
        ..sort();
  if (missingPolicyEntries.isNotEmpty) {
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
  final stalePolicyEntries =
      policyKeys.difference(nonContractExportSet).toList(growable: false)
        ..sort();
  if (stalePolicyEntries.isNotEmpty) {
    final path = stalePolicyEntries.first;
    final policy = _nonContractExportedApiScanPolicies[path]!;
    final reasonSuffix =
        policy.mode == _ExportedApiScanMode.skip && policy.reason != null
        ? ' Remove or update this skip policy: ${policy.reason}.'
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

  final filesToCheck =
      exportedFiles
          .where((path) {
            if (path.startsWith('/lib/src/contract/')) return true;
            final policy = _nonContractExportedApiScanPolicies[path];
            return policy?.mode == _ExportedApiScanMode.fullScan;
          })
          .toList(growable: false)
        ..sort();
  if (filesToCheck.isEmpty) return;

  for (final repoRel in filesToCheck) {
    final absPath = _toPosixPath(_posixJoin(root.path, repoRel.substring(1)));
    final file = File(absPath);
    if (!file.existsSync()) continue;

    final parsed = await _parseUnitOrFail(
      analysisCollection: analysisCollection,
      absPath: file.absolute.path,
      filePathForDiag: repoRel,
    );

    for (final declaration in parsed.unit.declarations) {
      final mutableTypeMatch = _firstMutableTypeInDeclarationSignature(
        declaration,
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
  final body = member.body;
  if (body is! BlockFunctionBody) {
    _fail(
      _Violation(
        filePath: filePath,
        line: _lineForOffset(parsed, member.offset),
        message:
            'interactive API violation: public SceneControllerInteractive '
            'entrypoint "$name" must use a block body guarded by '
            '_ensurePublicSideEffectAllowed(...).',
      ),
    );
  }

  final statements = body.block.statements;
  if (statements.isEmpty) {
    _fail(
      _Violation(
        filePath: filePath,
        line: _lineForOffset(parsed, member.offset),
        message:
            'interactive API violation: public SceneControllerInteractive '
            'entrypoints must guard resolver purity with '
            '_ensurePublicSideEffectAllowed(...).',
      ),
    );
  }

  final firstStatement = statements.first;
  if (firstStatement is! ExpressionStatement) {
    _fail(
      _Violation(
        filePath: filePath,
        line: _lineForOffset(parsed, firstStatement.offset),
        message:
            'interactive API violation: public SceneControllerInteractive '
            'entrypoints must guard resolver purity with '
            '_ensurePublicSideEffectAllowed(...).',
      ),
    );
  }

  final ensureCallInfo = _ensureCallInfoFromExpression(
    firstStatement.expression,
  );
  if (ensureCallInfo == null) {
    _fail(
      _Violation(
        filePath: filePath,
        line: _lineForOffset(parsed, firstStatement.offset),
        message:
            'interactive API violation: public SceneControllerInteractive '
            'entrypoints must guard resolver purity with '
            '_ensurePublicSideEffectAllowed(...).',
      ),
    );
  }

  if (name == 'dispose') {
    if (!ensureCallInfo.hasAllowAfterDispose) {
      _fail(
        _Violation(
          filePath: filePath,
          line: _lineForOffset(parsed, firstStatement.offset),
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
        line: _lineForOffset(parsed, firstStatement.offset),
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
  const allowedMutationPrefixes = <String>['write', 'txn'];
  const ignoredSymbols = <String>{
    'if',
    'for',
    'while',
    'switch',
    'assert',
    'return',
    'super',
    'this',
  };

  for (final file in dartFiles) {
    final fileAbsPosixPath = _toPosixPath(file.absolute.path);
    final filePosixPath = _toRepoRelPosixPath(
      absPosixPath: fileAbsPosixPath,
      rootAbsPosixPath: rootAbsPosix,
    );

    final parsed = await _parseUnitOrFail(
      analysisCollection: analysisCollection,
      absPath: file.absolute.path,
      filePathForDiag: filePosixPath,
    );

    final collector = _ControllerSymbolCollector();
    parsed.unit.accept(collector);

    if (collector.hasControllerEpoch) {
      hasControllerEpoch = true;
    }

    final replaceSceneOccurrence = collector.occurrences.firstWhere(
      (occurrence) => occurrence.name == 'replaceScene',
      orElse: () => const _ControllerSymbolOccurrence(name: '', offset: -1),
    );
    if (replaceSceneOccurrence.offset != -1 && !collector.hasControllerEpoch) {
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

    for (final occurrence in collector.occurrences) {
      final symbol = occurrence.name;
      if (ignoredSymbols.contains(symbol)) continue;
      if (allowedMutationPrefixes.any(symbol.startsWith)) continue;
      if (_looksMutatingSymbol(symbol)) {
        _fail(
          _Violation(
            filePath: filePosixPath,
            line: _lineForOffset(parsed, occurrence.offset),
            message:
                'controller API violation: mutating symbol "$symbol" must '
                'be routed through write*/txn* transaction API',
          ),
        );
      }
    }
  }

  if (!hasControllerEpoch) {
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
}

Future<void> main(List<String> _) async {
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

  await _checkExportedApiImports(
    root: root,
    packageName: packageName,
    exportedFiles: exportedFiles,
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
    exportedFiles: exportedFiles,
    analysisCollection: analysisCollection,
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

  stdout.writeln('OK: guardrails');
}
