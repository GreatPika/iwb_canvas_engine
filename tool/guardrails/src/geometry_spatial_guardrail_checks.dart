import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

const geometryCommittedHandleOrderGuardrailId =
    'geometry.committed_handle_order';
const geometryEraserExactBudgetGuardrailId =
    'geometry.eraser_exact_budget_no_partial';
const spatialNoFullCloneGuardrailId = 'spatial.no_full_clone_ordinary_edit';
const spatialStaleCandidateGuardrailId = 'spatial.stale_candidate_rejected';
const spatialFallbackBudgetGuardrailId = 'spatial.fallback_budget_enforced';

Future<List<GuardrailViolation>> checkCommittedHandleOrder() async {
  return [
    for (final file in dartFilesUnder('lib/src/geometry'))
      ...checkCommittedHandleOrderSource(
        path: relativePath(file),
        content: file.readAsStringSync(),
      ),
  ];
}

List<GuardrailViolation> checkCommittedHandleOrderSource({
  required String path,
  required String content,
}) {
  const forbiddenTokens = [
    'SceneNode',
    'NodeSnapshot',
    'SceneController',
    'sceneOrder',
    'nodeOrder',
    'zOrder',
  ];

  return [
    for (final token in forbiddenTokens)
      if (content.contains(token))
        GuardrailViolation(
          guardrailId: geometryCommittedHandleOrderGuardrailId,
          path: path,
          message:
              'geometry/spatial code must use committed handle order tokens. '
              'Forbidden token: $token.',
        ),
  ];
}

Future<List<GuardrailViolation>> checkSpatialNoFullCloneOrdinaryEdit() async {
  return [
    ...checkSpatialNoFullCloneOrdinaryEditSource(
      path: 'lib/src/geometry/spatial_kernel.dart',
      content: File(
        '$repositoryRoot/lib/src/geometry/spatial_kernel.dart',
      ).readAsStringSync(),
    ),
    ...checkSpatialTouchedAdditionsSource(
      path: 'lib/src/geometry/spatial_entry_loader.dart',
      content: File(
        '$repositoryRoot/lib/src/geometry/spatial_entry_loader.dart',
      ).readAsStringSync(),
    ),
  ];
}

List<GuardrailViolation> checkSpatialNoFullCloneOrdinaryEditSource({
  required String path,
  required String content,
}) {
  final parsed = _ParsedFunctions(content);
  if (!parsed.memberOrReachableHelperContains(
        '_applyPreparedTouchedDelta',
        '.elementHandles',
      ) &&
      !parsed.memberOrReachableHelperContains(
        '_applyPreparedTouchedDelta',
        'spatialEntriesForFrame',
      )) {
    return const [];
  }

  return [_spatialNoFullCloneViolation(path)];
}

List<GuardrailViolation> checkSpatialTouchedAdditionsSource({
  required String path,
  required String content,
}) {
  final parsed = _ParsedFunctions(content);
  if (!parsed.memberOrReachableHelperContains(
        'spatialAdditionsForTouches',
        '.elementHandles',
      ) &&
      !parsed.memberOrReachableHelperContains(
        'spatialAdditionsForTouches',
        'spatialEntriesForFrame',
      )) {
    return const [];
  }

  return [_spatialNoFullCloneViolation(path)];
}

GuardrailViolation _spatialNoFullCloneViolation(String path) {
  return GuardrailViolation(
    guardrailId: spatialNoFullCloneGuardrailId,
    path: path,
    message:
        'ordinary spatial update path must not enumerate full frame handles.',
  );
}

Future<List<GuardrailViolation>> checkSpatialStaleCandidateRejected() async {
  final mapper = File(
    '$repositoryRoot/lib/src/geometry/spatial_candidate_handle_mapper.dart',
  ).readAsStringSync();
  final queryState = File(
    '$repositoryRoot/lib/src/geometry/spatial_kernel_query_state.dart',
  ).readAsStringSync();

  return checkSpatialStaleCandidateRejectedSources(
    mapperPath: 'lib/src/geometry/spatial_candidate_handle_mapper.dart',
    mapperContent: mapper,
    queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
    queryStateContent: queryState,
  );
}

List<GuardrailViolation> checkSpatialStaleCandidateRejectedSources({
  required String mapperPath,
  required String mapperContent,
  required String queryStatePath,
  required String queryStateContent,
}) {
  final violations = <GuardrailViolation>[];
  if (!_hasOrderedStaleCandidateChecks(mapperContent)) {
    violations.add(
      GuardrailViolation(
        guardrailId: spatialStaleCandidateGuardrailId,
        path: mapperPath,
        message:
            'spatial candidates must remap stale structural, generation, and order-token handles through the frame boundary.',
      ),
    );
  }
  if (!_queryStateReturnsTypedStaleResult(queryStateContent)) {
    violations.add(
      GuardrailViolation(
        guardrailId: spatialStaleCandidateGuardrailId,
        path: queryStatePath,
        message: 'spatial queries must return a typed stale-candidate result.',
      ),
    );
  }

  return violations;
}

bool _hasOrderedStaleCandidateChecks(String content) {
  final body = _executableBody(content, 'call');
  if (body is! BlockFunctionBody) {
    return false;
  }

  return _staleCandidateMapperUsesCommittedBoundary(body.block);
}

bool _queryStateReturnsTypedStaleResult(String content) {
  final body = _executableBody(content, 'runQuery');

  return body != null &&
      _bodyContainsInstanceCreation(body, 'SpatialStaleCandidateResult');
}

final class _ParsedFunctions {
  _ParsedFunctions(String content) {
    final parsed = parseString(content: content, throwIfDiagnostics: false);
    final visitor = _FunctionSourceCollector();
    parsed.unit.accept(visitor);
    _sources.addAll(visitor.sources);
  }

  final Map<String, String> _sources = {};

  bool memberOrReachableHelperContains(String memberName, String needle) {
    if (!_sources.containsKey(memberName)) {
      return false;
    }
    final pending = <String>[memberName];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final currentName = pending.removeLast();
      if (!visited.add(currentName)) {
        continue;
      }
      final source = _sources[currentName];
      if (source == null) {
        continue;
      }
      if (source.contains(needle)) {
        return true;
      }
      for (final helperName in _sources.keys) {
        if (!visited.contains(helperName) &&
            helperName != currentName &&
            source.contains('$helperName(')) {
          pending.add(helperName);
        }
      }
    }

    return false;
  }
}

final class _FunctionSourceCollector extends RecursiveAstVisitor<void> {
  final Map<String, String> sources = {};

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    sources[node.name.lexeme] = node.toSource();
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    sources[node.name.lexeme] = node.toSource();
    super.visitMethodDeclaration(node);
  }
}

FunctionBody? _executableBody(String content, String name) {
  final parsed = parseString(content: content, throwIfDiagnostics: false);
  final visitor = _ExecutableBodyFinder(name);
  parsed.unit.accept(visitor);

  return visitor.body;
}

bool _bodyContainsInvocation(FunctionBody body, String invocationName) {
  final visitor = _InvocationFinder(invocationName);
  body.accept(visitor);

  return visitor.found;
}

bool _bodyContainsInstanceCreation(FunctionBody body, String typeName) {
  final visitor = _InstanceCreationFinder(typeName);
  body.accept(visitor);

  return visitor.found;
}

bool _bodyContainsComparison(
  FunctionBody body,
  String leftNeedle,
  String rightNeedle,
) {
  final visitor = _ComparisonFinder(leftNeedle, rightNeedle);
  body.accept(visitor);

  return visitor.found;
}

bool _bodyContainsIdentifier(FunctionBody body, String identifierName) {
  final visitor = _IdentifierFinder(identifierName);
  body.accept(visitor);

  return visitor.found;
}

bool _bodyContainsToken(FunctionBody body, String token) {
  final visitor = _SourceTokenFinder(token);
  body.accept(visitor);

  return visitor.found;
}

final class _ExecutableBodyFinder extends RecursiveAstVisitor<void> {
  _ExecutableBodyFinder(this.name);

  final String name;
  FunctionBody? body;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.name.lexeme == name) {
      body = node.functionExpression.body;
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == name) {
      body = node.body;
    }
    super.visitMethodDeclaration(node);
  }
}

final class _InvocationFinder extends RecursiveAstVisitor<void> {
  _InvocationFinder(this.invocationName);

  final String invocationName;
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == invocationName) {
      found = true;
    }
    super.visitMethodInvocation(node);
  }
}

final class _InstanceCreationFinder extends RecursiveAstVisitor<void> {
  _InstanceCreationFinder(this.typeName);

  final String typeName;
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == typeName) {
      found = true;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.toSource() == typeName) {
      found = true;
    }
    super.visitInstanceCreationExpression(node);
  }
}

final class _ComparisonFinder extends RecursiveAstVisitor<void> {
  _ComparisonFinder(this.leftNeedle, this.rightNeedle);

  final String leftNeedle;
  final String rightNeedle;
  bool found = false;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final source = node.toSource();
    if (node.operator.lexeme == '>' &&
        source.contains(leftNeedle) &&
        source.contains(rightNeedle)) {
      found = true;
    }
    super.visitBinaryExpression(node);
  }
}

final class _IdentifierFinder extends RecursiveAstVisitor<void> {
  _IdentifierFinder(this.identifierName);

  final String identifierName;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == identifierName) {
      found = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

final class _SourceTokenFinder extends RecursiveAstVisitor<void> {
  _SourceTokenFinder(this.token);

  final String token;
  bool found = false;

  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.expression.toSource() == token) {
      found = true;
    }
    super.visitNamedExpression(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.toSource() == token) {
      found = true;
    }
    super.visitPrefixedIdentifier(node);
  }
}

bool _staleCandidateMapperUsesCommittedBoundary(Block body) {
  if (!_declaresCurrentFromCommittedBoundary(body)) {
    return false;
  }
  final returns = _ReturnCollector();
  body.accept(returns);
  if (returns.statements.isEmpty) {
    return false;
  }

  var returnsCurrentForStructuralStale = false;
  for (final statement in returns.statements) {
    final expression = statement.expression;
    if (expression is! SimpleIdentifier) {
      return false;
    }
    if (expression.name == 'current') {
      if (_enclosingStructuralCurrentIf(statement) != null) {
        return false;
      }
      returnsCurrentForStructuralStale = true;
      continue;
    }
    if (expression.name != 'handle' ||
        !_handleReturnIsProtectedByStaleGuards(statement)) {
      return false;
    }
  }

  return returnsCurrentForStructuralStale;
}

bool _declaresCurrentFromCommittedBoundary(Block body) {
  final visitor = _CurrentBoundaryDeclarationFinder();
  body.accept(visitor);

  return visitor.found;
}

bool _handleReturnIsProtectedByStaleGuards(ReturnStatement statement) {
  final structuralIf = _enclosingStructuralCurrentIf(statement);
  if (structuralIf == null) {
    return false;
  }
  final guardFinder = _MismatchThrowGuardFinder(statement.offset);
  structuralIf.thenStatement.accept(guardFinder);

  return guardFinder.generationGuardFound && guardFinder.orderGuardFound;
}

IfStatement? _enclosingStructuralCurrentIf(AstNode node) {
  var current = node.parent;
  while (current != null) {
    if (current is IfStatement &&
        _isStructuralCurrentCheck(current.expression) &&
        _nodeContains(current.thenStatement, node)) {
      return current;
    }
    current = current.parent;
  }

  return null;
}

bool _isStructuralCurrentCheck(Expression expression) {
  return _expressionHasComparison(
    expression,
    leftNeedle: 'handle.structuralRevision',
    rightNeedle: '_structuralRevision',
    operator: '==',
  );
}

bool _isGenerationMismatchCheck(Expression expression) {
  return _expressionHasComparison(
    expression,
    leftNeedle: 'handle.generation',
    rightNeedle: 'current.generation',
    operator: '!=',
  );
}

bool _isOrderTokenMismatchCheck(Expression expression) {
  return _expressionHasComparison(
    expression,
    leftNeedle: 'handle.orderToken',
    rightNeedle: 'current.orderToken',
    operator: '!=',
  );
}

bool _expressionHasComparison(
  Expression expression, {
  required String leftNeedle,
  required String rightNeedle,
  required String operator,
}) {
  final visitor = _ExpressionComparisonFinder(
    leftNeedle: leftNeedle,
    rightNeedle: rightNeedle,
    operator: operator,
  );
  expression.accept(visitor);

  return visitor.found;
}

bool _nodeContains(AstNode container, AstNode node) {
  return container.offset <= node.offset && node.end <= container.end;
}

final class _CurrentBoundaryDeclarationFinder
    extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (node.name.lexeme == 'current' &&
        initializer != null &&
        initializer.toSource().contains('elementHandleForId') &&
        initializer.toSource().contains('_structuralRevision') &&
        initializer.toSource().contains('handle.id')) {
      found = true;
    }
    super.visitVariableDeclaration(node);
  }
}

final class _ReturnCollector extends RecursiveAstVisitor<void> {
  final List<ReturnStatement> statements = [];

  @override
  void visitReturnStatement(ReturnStatement node) {
    statements.add(node);
    super.visitReturnStatement(node);
  }
}

final class _MismatchThrowGuardFinder extends RecursiveAstVisitor<void> {
  _MismatchThrowGuardFinder(this.beforeOffset);

  final int beforeOffset;
  bool generationGuardFound = false;
  bool orderGuardFound = false;

  @override
  void visitIfStatement(IfStatement node) {
    if (node.offset < beforeOffset && _statementThrows(node.thenStatement)) {
      if (_isGenerationMismatchCheck(node.expression)) {
        generationGuardFound = true;
      }
      if (_isOrderTokenMismatchCheck(node.expression)) {
        orderGuardFound = true;
      }
    }
    super.visitIfStatement(node);
  }
}

bool _statementThrows(Statement statement) {
  final visitor = _ThrowFinder();
  statement.accept(visitor);

  return visitor.found;
}

final class _ThrowFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitThrowExpression(ThrowExpression node) {
    found = true;
    super.visitThrowExpression(node);
  }
}

final class _ExpressionComparisonFinder extends RecursiveAstVisitor<void> {
  _ExpressionComparisonFinder({
    required this.leftNeedle,
    required this.rightNeedle,
    required this.operator,
  });

  final String leftNeedle;
  final String rightNeedle;
  final String operator;
  bool found = false;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final source = node.toSource();
    if (node.operator.lexeme == operator &&
        source.contains(leftNeedle) &&
        source.contains(rightNeedle)) {
      found = true;
    }
    super.visitBinaryExpression(node);
  }
}

Future<List<GuardrailViolation>> checkSpatialFallbackBudgetEnforced() async {
  final tileIndex = File(
    '$repositoryRoot/lib/src/geometry/tile_index.dart',
  ).readAsStringSync();
  final queryState = File(
    '$repositoryRoot/lib/src/geometry/spatial_kernel_query_state.dart',
  ).readAsStringSync();

  return checkSpatialFallbackBudgetEnforcedSources(
    tileIndexPath: 'lib/src/geometry/tile_index.dart',
    tileIndexContent: tileIndex,
    queryStatePath: 'lib/src/geometry/spatial_kernel_query_state.dart',
    queryStateContent: queryState,
  );
}

List<GuardrailViolation> checkSpatialFallbackBudgetEnforcedSources({
  required String tileIndexPath,
  required String tileIndexContent,
  required String queryStatePath,
  required String queryStateContent,
}) {
  final violations = <GuardrailViolation>[];
  if (!_tileIndexEnforcesSpatialBudgets(tileIndexContent)) {
    violations.add(
      GuardrailViolation(
        guardrailId: spatialFallbackBudgetGuardrailId,
        path: tileIndexPath,
        message:
            'tile fallback must enforce candidate budget with typed no-partial result.',
      ),
    );
  }
  if (!_invalidIndexFallbackEnforcesCandidateBudget(queryStateContent)) {
    violations.add(
      GuardrailViolation(
        guardrailId: spatialFallbackBudgetGuardrailId,
        path: queryStatePath,
        message: 'invalid-index fallback must enforce the candidate budget.',
      ),
    );
  }

  return violations;
}

bool _tileIndexEnforcesSpatialBudgets(String content) {
  final parsed = _ParsedFunctions(content);
  final query = _executableBody(content, 'query');
  final candidateBudget = _executableBody(
    content,
    'spatialCandidateResultWithinBudget',
  );

  return query != null &&
      candidateBudget != null &&
      _bodyContainsComparison(
        query,
        'queryTileCount',
        'kCanvasMaxQueryCells',
      ) &&
      _bodyContainsInvocation(query, 'recordQueryTileBudgetExceeded') &&
      _bodyContainsInstanceCreation(query, 'SpatialBudgetExceededResult') &&
      _bodyContainsToken(
        query,
        'SpatialBudgetExceededReason.queryTileBudgetExceeded',
      ) &&
      !_bodyContainsIdentifier(query, 'fallbackCandidates') &&
      !_bodyContainsInvocation(query, 'addAll') &&
      parsed.memberOrReachableHelperContains(
        'query',
        'recordFallbackCandidateBudgetExceeded',
      ) &&
      parsed.memberOrReachableHelperContains(
        'query',
        'kCanvasMaxFallbackCandidates',
      ) &&
      _bodyContainsComparison(
        candidateBudget,
        'candidates.length',
        'kCanvasMaxFallbackCandidates',
      ) &&
      _bodyContainsInvocation(
        candidateBudget,
        'recordFallbackCandidateBudgetExceeded',
      ) &&
      _bodyContainsInstanceCreation(
        candidateBudget,
        'SpatialBudgetExceededResult',
      );
}

bool _invalidIndexFallbackEnforcesCandidateBudget(String content) {
  final body = _executableBody(content, 'runQuery');

  return body != null &&
      _bodyContainsComparison(
        body,
        'context.indexedEntryCount',
        'kCanvasMaxFallbackCandidates',
      ) &&
      _bodyContainsInvocation(body, 'recordFallbackCandidateBudgetExceeded') &&
      _bodyContainsInstanceCreation(body, 'SpatialBudgetExceededResult');
}

Future<List<GuardrailViolation>> checkGeometryEraserExactBudgetInputs() async {
  final geometry = File(
    '$repositoryRoot/lib/src/geometry/geometry_policy.dart',
  ).readAsStringSync();
  final hit = File(
    '$repositoryRoot/lib/src/geometry/hit_test_policy.dart',
  ).readAsStringSync();

  return checkGeometryEraserExactBudgetInputSources(
    geometryPath: 'lib/src/geometry/geometry_policy.dart',
    geometryContent: geometry,
    hitPath: 'lib/src/geometry/hit_test_policy.dart',
    hitContent: hit,
  );
}

List<GuardrailViolation> checkGeometryEraserExactBudgetInputSources({
  required String geometryPath,
  required String geometryContent,
  required String hitPath,
  required String hitContent,
}) {
  final violations = <GuardrailViolation>[];
  if (!geometryContent.contains('eraserPreviewBudgetInputs') ||
      !geometryContent.contains('eraserTerminalBudgetInputs') ||
      !_eraserBudgetInputShapeIsLimitsOnly(geometryContent)) {
    violations.add(
      GuardrailViolation(
        guardrailId: geometryEraserExactBudgetGuardrailId,
        path: geometryPath,
        message:
            'Eraser guardrail covers primitive and exact-check budget inputs.',
      ),
    );
  }
  if (!hitContent.contains('exactEraserHit')) {
    violations.add(
      GuardrailViolation(
        guardrailId: geometryEraserExactBudgetGuardrailId,
        path: hitPath,
        message: 'Eraser exact-hit helper must remain family-owned.',
      ),
    );
  }
  if (geometryContent.contains('partialErase') ||
      hitContent.contains('partialErase')) {
    violations.add(
      GuardrailViolation(
        guardrailId: geometryEraserExactBudgetGuardrailId,
        path: geometryPath,
        message: 'Eraser budget checks must not implement partial erases.',
      ),
    );
  }

  return violations;
}

bool _eraserBudgetInputShapeIsLimitsOnly(String content) {
  final classSource = _classSource(content, 'EraserExactBudgetInputs');
  if (classSource == null) {
    return false;
  }

  return classSource.contains('final int candidateLimit;') &&
      classSource.contains('final int exactCheckLimit;') &&
      !classSource.contains('List<') &&
      !classSource.contains('Iterable<') &&
      !classSource.contains('CanvasElementId') &&
      !classSource.contains('FrameElementHandle');
}

String? _classSource(String content, String className) {
  final parsed = parseString(content: content);
  for (final declaration in parsed.unit.declarations) {
    if (declaration is ClassDeclaration &&
        declaration.namePart.typeName.lexeme == className) {
      // Analyzer offsets are String code-unit offsets; substring preserves the
      // exact declaration range reported by the parser.
      // ignore: avoid-substring
      return content.substring(declaration.offset, declaration.end);
    }
  }

  return null;
}
