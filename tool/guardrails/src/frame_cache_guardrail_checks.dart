import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

const frameNoGlobalSceneSortGuardrailId = 'frame.no_global_scene_sort';
const framePaintPlanExcludesPreviewGuardrailId =
    'frame.paint_plan_excludes_preview_delta';
const framePaintPlanExcludesSelectionGuardrailId =
    'frame.paint_plan_excludes_selection_state';
const cacheKeysUseNextRevisionsGuardrailId =
    'cache.keys_use_next_revisions_only';
const cacheBackgroundGridGuardrailId =
    'cache.background_grid_not_element_visual';
const cacheHotCachesCapacityGuardrailId =
    'cache.hot_caches_have_capacity_eviction';

Future<List<GuardrailViolation>> checkFrameNoGlobalSceneSort() async {
  return checkFrameNoGlobalSceneSortSources(_productionFrameSources());
}

Future<List<GuardrailViolation>> checkPaintPlanExcludesPreviewDelta() async {
  return checkPaintPlanExcludesPreviewDeltaSources(_productionFrameSources());
}

Future<List<GuardrailViolation>> checkPaintPlanExcludesSelectionState() async {
  return checkPaintPlanExcludesSelectionStateSources(_productionFrameSources());
}

Future<List<GuardrailViolation>> checkCacheKeysUseNextRevisionsOnly() async {
  return checkCacheKeysUseNextRevisionsOnlySources(_productionFrameSources());
}

Future<List<GuardrailViolation>> checkCacheBackgroundGridNotElementVisual() {
  return Future.value(
    checkCacheBackgroundGridNotElementVisualSources(_productionFrameSources()),
  );
}

Future<List<GuardrailViolation>> checkCacheHotCachesHaveCapacityEviction() {
  return Future.value(
    checkCacheHotCachesHaveCapacityEvictionSources(_productionFrameSources()),
  );
}

List<GuardrailViolation> checkFrameNoGlobalSceneSortSources(
  Map<String, String> sources,
) {
  final frameUnits = {
    for (final entry in sources.entries)
      if (_isFrameSource(entry.key))
        entry.key: _parseGuardrailUnit(entry.value),
  };
  final topLevelHelperNames = _topLevelOrderTokenComparatorHelpers(
    frameUnits.values,
  );
  final topLevelQualifiedHelperNames =
      _topLevelQualifiedOrderTokenComparatorHelpers(frameUnits.values);
  final context = _FrameSceneSortGuardrailContext(
    frameUnits: frameUnits,
    topLevelHelperNames: topLevelHelperNames,
    topLevelQualifiedHelperNames: topLevelQualifiedHelperNames,
    helperCatalog: _orderTokenComparatorHelperCatalog(frameUnits),
  );

  return [
    for (final entry in frameUnits.entries)
      if (_containsForbiddenSceneRecordSort(entry.key, entry.value, context))
        GuardrailViolation(
          guardrailId: frameNoGlobalSceneSortGuardrailId,
          path: entry.key,
          message: 'frame code may not globally sort scene records',
        ),
  ];
}

List<GuardrailViolation> checkPaintPlanExcludesPreviewDeltaSources(
  Map<String, String> sources,
) {
  return _checkCachedPaintSurfacesExclude(
    guardrailId: framePaintPlanExcludesPreviewGuardrailId,
    sources: sources,
    tokens: const ['preview', 'selectedMove'],
    message: 'ordinary paint-plan caches may not include preview facts',
  );
}

List<GuardrailViolation> checkPaintPlanExcludesSelectionStateSources(
  Map<String, String> sources,
) {
  return _checkCachedPaintSurfacesExclude(
    guardrailId: framePaintPlanExcludesSelectionGuardrailId,
    sources: sources,
    tokens: const [
      'selection',
      'selectedElementIds',
      'selectedIds',
      'isSelected',
      'selectionRevision',
    ],
    message: 'ordinary paint-plan caches may not include selection state',
  );
}

List<GuardrailViolation> checkCacheKeysUseNextRevisionsOnlySources(
  Map<String, String> sources,
) {
  return _cacheKeyShapeViolations(sources);
}

List<GuardrailViolation> _cacheKeyShapeViolations(Map<String, String> sources) {
  final violations = <GuardrailViolation>[];
  for (final surface in _ordinaryCacheKeySurfaces) {
    final source = sources[surface.path];
    if (source == null) {
      continue;
    }
    final unit = _parseGuardrailUnit(source);
    for (final declaration in _cacheKeyClassDeclarations(
      unit,
      surface.className,
    )) {
      _addCacheKeyClassViolations(violations, surface, declaration);
    }
  }

  return violations;
}

void _addCacheKeyClassViolations(
  List<GuardrailViolation> violations,
  _OrdinaryCacheKeySurface surface,
  ClassDeclaration declaration,
) {
  for (final token in _cacheKeyClassForbiddenTokens(declaration, surface)) {
    violations.add(
      _cacheKeyViolation(
        surface,
        '${surface.className} may not include forbidden cache key token $token',
      ),
    );
  }
  for (final field in _classFieldNames(declaration)) {
    if (surface.allowedFields.contains(field)) {
      continue;
    }
    violations.add(
      _cacheKeyViolation(
        surface,
        '${surface.className} may not include non-owned cache key field $field',
      ),
    );
  }
}

List<GuardrailViolation> checkCacheBackgroundGridNotElementVisualSources(
  Map<String, String> sources,
) {
  return [
    for (final surface in const [
      _CachedPaintSurface('lib/src/frame/paint_plan.dart', 'PaintPlanKey'),
      _CachedPaintSurface(
        'lib/src/frame/paint_plan.dart',
        'OrdinaryPaintRecordKey',
      ),
    ])
      if (_classBody(sources[surface.path], surface.className) case final body?)
        if (_containsAny(body, const [
          'backgroundRevision',
          'gridRevision',
          'gridStrokeWidth',
          'viewCamera',
          'camera',
        ]))
          GuardrailViolation(
            guardrailId: cacheBackgroundGridGuardrailId,
            path: surface.path,
            message:
                'ordinary ${surface.className} may not include background, grid, or camera facts',
          ),
  ];
}

List<GuardrailViolation> checkCacheHotCachesHaveCapacityEvictionSources(
  Map<String, String> sources,
) {
  final violations = <GuardrailViolation>[];
  final frameCache = sources['lib/src/frame/frame_cache.dart'];
  if (frameCache != null &&
      !_containsAll(frameCache, const [
        'FrameCacheProbe',
        'capacity',
        'evictions',
      ])) {
    violations.add(
      const GuardrailViolation(
        guardrailId: cacheHotCachesCapacityGuardrailId,
        path: 'lib/src/frame/frame_cache.dart',
        message: 'frame cache owner must expose capacity and eviction probes',
      ),
    );
  }

  for (final entry in sources.entries) {
    if (!_isFrameSource(entry.key)) {
      continue;
    }
    for (final declaration in _frameCacheDeclarations(entry.value)) {
      if (_constructorSetsExplicitCapacity(declaration)) {
        continue;
      }
      violations.add(
        GuardrailViolation(
          guardrailId: cacheHotCachesCapacityGuardrailId,
          path: entry.key,
          message:
              '${declaration.name} must set an explicit frame cache capacity',
        ),
      );
    }
  }

  return violations;
}

Map<String, String> _productionFrameSources() {
  return {
    for (final file in dartFilesUnder('lib/src/frame'))
      relativePath(file): file.readAsStringSync(),
  };
}

bool _isFrameSource(String path) => path.startsWith('lib/src/frame/');

List<GuardrailViolation> _checkCachedPaintSurfacesExclude({
  required String guardrailId,
  required Map<String, String> sources,
  required Iterable<String> tokens,
  required String message,
}) {
  final violations = <GuardrailViolation>[];
  for (final surface in _ordinaryCachedPaintSurfaces) {
    final source = sources[surface.path];
    if (source == null) {
      continue;
    }
    final unit = _parseGuardrailUnit(source);
    for (final declaration in _cacheKeyClassDeclarations(
      unit,
      surface.className,
    )) {
      if (!_cacheSurfaceStoresForbiddenIdentifier(declaration, tokens)) {
        continue;
      }
      violations.add(
        GuardrailViolation(
          guardrailId: guardrailId,
          path: surface.path,
          message: '$message in ${surface.className}',
        ),
      );
    }
  }

  return violations;
}

const _ordinaryCachedPaintSurfaces = [
  _CachedPaintSurface('lib/src/frame/paint_plan.dart', 'PaintPlanKey'),
  _CachedPaintSurface(
    'lib/src/frame/paint_plan.dart',
    'OrdinaryPaintRecordKey',
  ),
  _CachedPaintSurface('lib/src/frame/paint_plan.dart', 'PaintPlan'),
  _CachedPaintSurface(
    'lib/src/frame/paint_plan.dart',
    'OrdinaryPaintRecordCacheEntry',
  ),
  _CachedPaintSurface(
    'lib/src/frame/render_element_record.dart',
    'RenderElementRecord',
  ),
  _CachedPaintSurface(
    'lib/src/frame/render_element_record.dart',
    'ImageRenderRow',
  ),
  _CachedPaintSurface(
    'lib/src/frame/render_element_record.dart',
    'PathRenderRow',
  ),
  _CachedPaintSurface(
    'lib/src/frame/render_element_record.dart',
    'TextRenderRow',
  ),
  _CachedPaintSurface(
    'lib/src/frame/render_element_record.dart',
    'StrokeRenderRow',
  ),
  _CachedPaintSurface(
    'lib/src/frame/render_element_record.dart',
    'LineRenderRow',
  ),
  _CachedPaintSurface(
    'lib/src/frame/render_element_record.dart',
    'RectRenderRow',
  ),
];

const _ordinaryCacheKeySurfaces = [
  _OrdinaryCacheKeySurface(
    'lib/src/frame/paint_plan.dart',
    'PaintPlanKey',
    {
      'structuralRevision',
      'boundsRevision',
      'elementVisualRevision',
      'viewportRect',
      'devicePixelRatio',
    },
    {'documentRevision', 'resourceRevision'},
  ),
  _OrdinaryCacheKeySurface(
    'lib/src/frame/paint_plan.dart',
    'OrdinaryPaintRecordKey',
    {
      'id',
      'structuralRevision',
      'boundsRevision',
      'elementVisualRevision',
      'generation',
      'orderToken',
    },
    {'documentRevision', 'resourceRevision'},
  ),
];

final class _CachedPaintSurface {
  const _CachedPaintSurface(this.path, this.className);

  final String path;
  final String className;
}

final class _OrdinaryCacheKeySurface {
  const _OrdinaryCacheKeySurface(
    this.path,
    this.className,
    this.allowedFields,
    this.forbiddenTokens,
  );

  final String path;
  final String className;
  final Set<String> allowedFields;
  final Set<String> forbiddenTokens;
}

GuardrailViolation _cacheKeyViolation(
  _OrdinaryCacheKeySurface surface,
  String message,
) {
  return GuardrailViolation(
    guardrailId: cacheKeysUseNextRevisionsGuardrailId,
    path: surface.path,
    message: message,
  );
}

bool _containsForbiddenSceneRecordSort(
  String path,
  CompilationUnit unit,
  _FrameSceneSortGuardrailContext context,
) {
  final projectionVisitor = _OrderTokenProjectionVisitor();
  unit.accept(projectionVisitor);
  final helperNames = {
    ...context.topLevelHelperNames,
    ..._orderTokenComparatorHelpers(unit),
  };
  final qualifiedHelperNames = {
    ...context.topLevelQualifiedHelperNames,
    ...context.importAliasQualifiedHelpers(path: path, unit: unit),
    ..._qualifiedOrderTokenComparatorHelpers(unit),
  };
  final helperInstances = _orderTokenComparatorHelperInstances(
    unit,
    _helperMethodsByClass(qualifiedHelperNames),
  );
  final visitor = _OrderTokenSortVisitor(
    helperNames: helperNames,
    qualifiedHelperNames: qualifiedHelperNames,
    helperInstances: helperInstances,
    orderTokenProjectionCollections: projectionVisitor.collectionNames,
  );
  unit.accept(visitor);

  return visitor.hasViolation;
}

String _withoutLineComments(String content) {
  return content
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

bool _containsAny(String content, Iterable<String> tokens) {
  final lowerContent = content.toLowerCase();

  return tokens.any((token) => lowerContent.contains(token.toLowerCase()));
}

bool _containsAll(String content, Iterable<String> tokens) {
  return tokens.every(content.contains);
}

CompilationUnit _parseGuardrailUnit(String source) {
  return parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
}

bool _cacheSurfaceStoresForbiddenIdentifier(
  ClassDeclaration declaration,
  Iterable<String> tokens,
) {
  final tokenSet = {for (final token in tokens) token.toLowerCase()};

  return _classStoredIdentifierNames(
    declaration,
  ).any((identifier) => _identifierMatchesAnyToken(identifier, tokenSet));
}

Iterable<String> _classStoredIdentifierNames(
  ClassDeclaration declaration,
) sync* {
  yield* _fieldStoredIdentifierNames(declaration);
  yield* _constructorStoredIdentifierNames(declaration);
  yield* _methodStoredIdentifierNames(declaration);
  final visitor = _ClassIdentifierVisitor();
  declaration.accept(visitor);
  yield* visitor.identifiers;
}

Iterable<String> _fieldStoredIdentifierNames(
  ClassDeclaration declaration,
) sync* {
  for (final member in declaration.body.members.whereType<FieldDeclaration>()) {
    if (member.isStatic) {
      continue;
    }
    yield* _identifierWords(member.fields.type?.toSource());
    for (final variable in member.fields.variables) {
      yield variable.name.lexeme;
    }
  }
}

Iterable<String> _constructorStoredIdentifierNames(
  ClassDeclaration declaration,
) sync* {
  for (final constructor
      in declaration.body.members.whereType<ConstructorDeclaration>()) {
    for (final parameter in constructor.parameters.parameters) {
      yield parameter.name?.lexeme ?? '';
      yield* _identifierWords(parameter.toSource().split('=').first);
    }
  }
}

Iterable<String> _methodStoredIdentifierNames(
  ClassDeclaration declaration,
) sync* {
  for (final method
      in declaration.body.members.whereType<MethodDeclaration>()) {
    if (method.isStatic) {
      continue;
    }
    yield method.name.lexeme;
    yield* _identifierWords(method.returnType?.toSource());
    final parameters = method.parameters;
    if (parameters == null) {
      continue;
    }
    for (final parameter in parameters.parameters) {
      yield parameter.name?.lexeme ?? '';
      yield* _identifierWords(parameter.toSource().split('=').first);
    }
  }
}

Iterable<String> _identifierWords(String? source) sync* {
  if (source == null) {
    return;
  }
  for (final match in RegExp(r'\b[A-Za-z_]\w*\b').allMatches(source)) {
    final word = match.group(0);
    if (word != null) {
      yield word;
    }
  }
}

bool _identifierMatchesAnyToken(String identifier, Set<String> tokens) {
  final lowerIdentifier = identifier.toLowerCase();

  return tokens.any(lowerIdentifier.contains);
}

final class _ClassIdentifierVisitor extends RecursiveAstVisitor<void> {
  final Set<String> identifiers = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    identifiers.add(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    identifiers.add(node.value);
    super.visitSimpleStringLiteral(node);
  }
}

Set<String> _topLevelOrderTokenComparatorHelpers(
  Iterable<CompilationUnit> units,
) {
  final helperNames = <String>{};
  for (final unit in units) {
    helperNames.addAll(_orderTokenComparatorHelpers(unit, topLevelOnly: true));
  }

  return helperNames;
}

Set<String> _topLevelQualifiedOrderTokenComparatorHelpers(
  Iterable<CompilationUnit> units,
) {
  final helperNames = <String>{};
  for (final unit in units) {
    helperNames.addAll(_qualifiedOrderTokenComparatorHelpers(unit));
  }

  return helperNames;
}

Map<String, _OrderTokenComparatorHelperNames>
_orderTokenComparatorHelperCatalog(Map<String, CompilationUnit> units) {
  return {
    for (final entry in units.entries)
      entry.key: _OrderTokenComparatorHelperNames(
        topLevel: _orderTokenComparatorHelpers(entry.value, topLevelOnly: true),
        qualified: _qualifiedOrderTokenComparatorHelpers(entry.value),
      ),
  };
}

final class _OrderTokenComparatorHelperNames {
  const _OrderTokenComparatorHelperNames({
    required this.topLevel,
    required this.qualified,
  });

  final Set<String> topLevel;
  final Set<String> qualified;
}

final class _FrameSceneSortGuardrailContext {
  const _FrameSceneSortGuardrailContext({
    required this.frameUnits,
    required this.topLevelHelperNames,
    required this.topLevelQualifiedHelperNames,
    required this.helperCatalog,
  });

  final Map<String, CompilationUnit> frameUnits;
  final Set<String> topLevelHelperNames;
  final Set<String> topLevelQualifiedHelperNames;
  final Map<String, _OrderTokenComparatorHelperNames> helperCatalog;

  Set<String> importAliasQualifiedHelpers({
    required String path,
    required CompilationUnit unit,
  }) {
    final helpers = <String>{};
    for (final directive in unit.directives.whereType<ImportDirective>()) {
      final alias = directive.prefix?.name;
      if (alias == null) {
        continue;
      }
      final importedPath = _resolvedFrameImportPath(path, directive);
      if (importedPath == null || !frameUnits.containsKey(importedPath)) {
        continue;
      }
      final importedHelpers = helperCatalog[importedPath];
      if (importedHelpers == null) {
        continue;
      }
      helpers.addAll(importedHelpers.topLevel.map((name) => '$alias.$name'));
      helpers.addAll(importedHelpers.qualified.map((name) => '$alias.$name'));
    }

    return helpers;
  }
}

String? _resolvedFrameImportPath(String sourcePath, ImportDirective directive) {
  final uri = directive.uri.stringValue;
  if (uri == null) {
    return null;
  }
  if (uri.startsWith('package:iwb_canvas_engine/src/frame/')) {
    return 'lib/${uri.replaceFirst('package:iwb_canvas_engine/', '')}';
  }
  if (uri.startsWith('dart:') ||
      uri.startsWith('package:') ||
      uri.startsWith('/')) {
    return null;
  }
  final directoryEnd = sourcePath.lastIndexOf('/');
  final directory = directoryEnd < 0
      ? ''
      : sourcePath.replaceRange(directoryEnd, sourcePath.length, '');
  final rawPath = directory.isEmpty ? uri : '$directory/$uri';

  return _normalizeRelativePath(rawPath);
}

String _normalizeRelativePath(String path) {
  final parts = <String>[];
  for (final part in path.split('/')) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    if (part == '..') {
      if (parts.isNotEmpty) {
        parts.removeLast();
      }
      continue;
    }
    parts.add(part);
  }

  return parts.join('/');
}

Set<String> _orderTokenComparatorHelpers(
  CompilationUnit unit, {
  bool topLevelOnly = false,
}) {
  final visitor = _OrderTokenHelperVisitor(topLevelOnly: topLevelOnly);
  unit.accept(visitor);

  return visitor.helperNames;
}

final class _OrderTokenHelperVisitor extends RecursiveAstVisitor<void> {
  _OrderTokenHelperVisitor({this.topLevelOnly = false});

  final bool topLevelOnly;
  final Set<String> helperNames = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if ((!topLevelOnly || _isTopLevelVariableDeclaration(node)) &&
        initializer != null &&
        _nodeMentionsIdentifier(initializer, 'orderToken')) {
      helperNames.add(node.name.lexeme);
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if ((!topLevelOnly || node.parent is CompilationUnit) &&
        _nodeMentionsIdentifier(node.functionExpression.body, 'orderToken')) {
      helperNames.add(node.name.lexeme);
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!topLevelOnly && _nodeMentionsIdentifier(node.body, 'orderToken')) {
      helperNames.add(node.name.lexeme);
    }
    super.visitMethodDeclaration(node);
  }
}

bool _isTopLevelVariableDeclaration(VariableDeclaration node) {
  return node.parent?.parent is TopLevelVariableDeclaration;
}

Set<String> _qualifiedOrderTokenComparatorHelpers(CompilationUnit unit) {
  final visitor = _QualifiedOrderTokenHelperVisitor();
  unit.accept(visitor);

  return visitor.helperNames;
}

final class _QualifiedOrderTokenHelperVisitor
    extends RecursiveAstVisitor<void> {
  final Set<String> helperNames = {};
  final List<String> _classNames = [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _classNames.add(node.namePart.typeName.lexeme);
    super.visitClassDeclaration(node);
    _classNames.removeLast();
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (_classNames.isNotEmpty &&
        _nodeMentionsIdentifier(node.body, 'orderToken')) {
      helperNames.add('${_classNames.last}.${node.name.lexeme}');
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (_classNames.isNotEmpty &&
        initializer != null &&
        _nodeMentionsIdentifier(initializer, 'orderToken')) {
      helperNames.add('${_classNames.last}.${node.name.lexeme}');
    }
    super.visitVariableDeclaration(node);
  }
}

final class _OrderTokenSortVisitor extends RecursiveAstVisitor<void> {
  _OrderTokenSortVisitor({
    required this.helperNames,
    required this.qualifiedHelperNames,
    required this.helperInstances,
    required this.orderTokenProjectionCollections,
  });

  final Set<String> helperNames;
  final Set<String> qualifiedHelperNames;
  final Map<String, Set<String>> helperInstances;
  final Set<String> orderTokenProjectionCollections;
  bool hasViolation = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'sort' &&
        _sortInvocationMentionsOrderToken(node)) {
      hasViolation = true;
    }
    super.visitMethodInvocation(node);
  }

  bool _sortInvocationMentionsOrderToken(MethodInvocation node) {
    return _nodeMentionsIdentifier(node.argumentList, 'orderToken') ||
        _sortArgumentsUseOrderTokenHelper(node.argumentList) ||
        _sortReceiverIsOrderTokenProjection(node);
  }

  bool _sortArgumentsUseOrderTokenHelper(ArgumentList argumentList) {
    if (_nodeMentionsQualifiedHelper(
      argumentList,
      qualifiedHelperNames,
      helperInstances,
    )) {
      return true;
    }

    return _helperIdentifierReferences(argumentList, helperNames).any(
      (identifier) => !_isLocallyShadowedByNonOrderTokenDeclaration(identifier),
    );
  }

  bool _sortReceiverIsOrderTokenProjection(MethodInvocation node) {
    final target = node.realTarget;
    if (target == null) {
      return false;
    }

    return _expressionIsOrderTokenProjection(target);
  }

  bool _expressionIsOrderTokenProjection(Expression expression) {
    if (expression is SimpleIdentifier &&
        orderTokenProjectionCollections.contains(expression.name)) {
      return true;
    }

    return _nodeMentionsIdentifier(expression, 'orderToken') ||
        _nodeMentionsAnyIdentifier(expression, orderTokenProjectionCollections);
  }
}

bool _nodeMentionsQualifiedHelper(
  AstNode node,
  Set<String> qualifiedNames,
  Map<String, Set<String>> helperInstances,
) {
  if (qualifiedNames.isEmpty && helperInstances.isEmpty) {
    return false;
  }
  final visitor = _QualifiedHelperPresenceVisitor(
    qualifiedNames,
    helperInstances,
  );
  node.accept(visitor);

  return visitor.found;
}

final class _QualifiedHelperPresenceVisitor extends RecursiveAstVisitor<void> {
  _QualifiedHelperPresenceVisitor(this.qualifiedNames, this.helperInstances);

  final Set<String> qualifiedNames;
  final Map<String, Set<String>> helperInstances;
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target != null && _targetOwnsHelper(target, node.methodName.name)) {
      found = true;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (_simpleTargetOwnsHelper(node.prefix, node.identifier.name)) {
      found = true;
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target != null && _targetOwnsHelper(target, node.propertyName.name)) {
      found = true;
    }
    super.visitPropertyAccess(node);
  }

  bool _targetOwnsHelper(Expression target, String method) {
    if (target is SimpleIdentifier) {
      return _simpleTargetOwnsHelper(target, method);
    }
    if (target is PrefixedIdentifier) {
      return _qualifiedReceiverOwnsHelper(target.toSource(), method) &&
          !_unitShadowsQualifiedHelper(target, target.identifier.name, method);
    }
    final constructedType = _constructedTypeName(target);

    return constructedType != null &&
        _qualifiedReceiverOwnsHelper(constructedType, method) &&
        !_unitShadowsQualifiedHelper(target, constructedType, method);
  }

  bool _simpleTargetOwnsHelper(SimpleIdentifier target, String method) {
    return (helperInstances[target.name]?.contains(method) ?? false) ||
        (_qualifiedReceiverOwnsHelper(target.name, method) &&
            !_unitShadowsQualifiedHelper(target, target.name, method));
  }

  bool _qualifiedReceiverOwnsHelper(String receiver, String method) {
    return qualifiedNames.contains('$receiver.$method') ||
        (helperInstances[receiver]?.contains(method) ?? false);
  }
}

String? _constructedTypeName(Expression expression) {
  if (expression is InstanceCreationExpression) {
    return expression.constructorName.type.name.lexeme;
  }
  if (expression is MethodInvocation && expression.target == null) {
    return expression.methodName.name;
  }

  return null;
}

bool _unitShadowsQualifiedHelper(
  AstNode node,
  String receiverName,
  String methodName,
) {
  for (final ancestor in _ancestorNodes(node)) {
    if (ancestor is CompilationUnit) {
      return _unitHasNonOrderTokenClassMethod(
        ancestor,
        receiverName,
        methodName,
      );
    }
  }

  return false;
}

bool _unitHasNonOrderTokenClassMethod(
  CompilationUnit unit,
  String className,
  String methodName,
) {
  for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
    if (declaration.namePart.typeName.lexeme != className) {
      continue;
    }
    for (final member
        in declaration.body.members.whereType<MethodDeclaration>()) {
      if (member.name.lexeme == methodName &&
          !_nodeMentionsIdentifier(member.body, 'orderToken')) {
        return true;
      }
    }
  }

  return false;
}

Iterable<SimpleIdentifier> _helperIdentifierReferences(
  AstNode node,
  Set<String> names,
) {
  if (names.isEmpty) {
    return const [];
  }
  final visitor = _HelperIdentifierReferenceVisitor(names);
  node.accept(visitor);

  return visitor.references;
}

final class _HelperIdentifierReferenceVisitor
    extends RecursiveAstVisitor<void> {
  _HelperIdentifierReferenceVisitor(this.names);

  final Set<String> names;
  final List<SimpleIdentifier> references = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (names.contains(node.name)) {
      references.add(node);
    }
    super.visitSimpleIdentifier(node);
  }
}

Map<String, Set<String>> _helperMethodsByClass(Set<String> qualifiedNames) {
  final methodsByClass = <String, Set<String>>{};
  for (final qualifiedName in qualifiedNames) {
    final separator = qualifiedName.indexOf('.');
    if (separator <= 0 || separator == qualifiedName.length - 1) {
      continue;
    }
    final parts = qualifiedName.split('.');
    final className = parts.first;
    final methodName = parts.last;
    methodsByClass.putIfAbsent(className, () => {}).add(methodName);
  }

  return methodsByClass;
}

Map<String, Set<String>> _orderTokenComparatorHelperInstances(
  CompilationUnit unit,
  Map<String, Set<String>> helperMethodsByClass,
) {
  if (helperMethodsByClass.isEmpty) {
    return const {};
  }
  final visitor = _OrderTokenComparatorHelperInstanceVisitor(
    helperMethodsByClass,
  );
  unit.accept(visitor);

  return visitor.methodsByInstance;
}

final class _OrderTokenComparatorHelperInstanceVisitor
    extends RecursiveAstVisitor<void> {
  _OrderTokenComparatorHelperInstanceVisitor(this.helperMethodsByClass);

  final Map<String, Set<String>> helperMethodsByClass;
  final Map<String, Set<String>> methodsByInstance = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final methods = _helperMethodsForVariable(node, helperMethodsByClass);
    if (methods != null) {
      methodsByInstance[node.name.lexeme] = methods;
    }
    super.visitVariableDeclaration(node);
  }
}

Set<String>? _helperMethodsForVariable(
  VariableDeclaration node,
  Map<String, Set<String>> helperMethodsByClass,
) {
  final declaredType = _variableDeclaredType(node);
  if (declaredType != null && helperMethodsByClass.containsKey(declaredType)) {
    return helperMethodsByClass[declaredType];
  }
  final initializerType = _constructorInitializerType(node.initializer);
  if (initializerType != null &&
      helperMethodsByClass.containsKey(initializerType)) {
    return helperMethodsByClass[initializerType];
  }

  return null;
}

String? _variableDeclaredType(VariableDeclaration node) {
  final parent = node.parent;
  if (parent is! VariableDeclarationList) {
    return null;
  }
  final type = parent.type;
  if (type is NamedType) {
    return type.name.lexeme;
  }

  return null;
}

String? _constructorInitializerType(Expression? initializer) {
  if (initializer is InstanceCreationExpression) {
    return initializer.constructorName.type.name.lexeme;
  }
  if (initializer is MethodInvocation && initializer.target == null) {
    return initializer.methodName.name;
  }

  return null;
}

bool _isLocallyShadowedByNonOrderTokenDeclaration(SimpleIdentifier identifier) {
  for (final node in _ancestorNodes(identifier)) {
    if (node is FormalParameter &&
        _parameterDeclaresName(node, identifier.name)) {
      return true;
    }
    if (node is FunctionBody &&
        _functionBodyDeclaresParameter(node, identifier.name)) {
      return true;
    }
    if (node is Block &&
        _blockHasVisibleNonOrderTokenDeclaration(node, identifier)) {
      return true;
    }
    if (node is CompilationUnit &&
        _unitHasNonOrderTokenDeclaration(node, identifier.name)) {
      return true;
    }
  }

  return false;
}

Iterable<AstNode> _ancestorNodes(AstNode node) sync* {
  var current = node.parent;
  while (current != null) {
    yield current;
    current = current.parent;
  }
}

bool _parameterDeclaresName(FormalParameter parameter, String name) {
  return parameter.name?.lexeme == name &&
      !_nodeMentionsIdentifier(parameter, 'orderToken');
}

bool _functionBodyDeclaresParameter(FunctionBody body, String name) {
  final parent = body.parent;
  if (parent is FunctionExpression) {
    return _parameterListDeclaresName(parent.parameters, name);
  }
  if (parent is MethodDeclaration) {
    return _parameterListDeclaresName(parent.parameters, name);
  }
  if (parent is ConstructorDeclaration) {
    return _parameterListDeclaresName(parent.parameters, name);
  }

  return false;
}

bool _parameterListDeclaresName(FormalParameterList? parameters, String name) {
  if (parameters == null) {
    return false;
  }

  return parameters.parameters.any(
    (parameter) => _parameterDeclaresName(parameter, name),
  );
}

bool _blockHasVisibleNonOrderTokenDeclaration(
  Block block,
  SimpleIdentifier identifier,
) {
  for (final statement in block.statements) {
    if (statement.offset >= identifier.offset) {
      continue;
    }
    if (_statementDeclaresNonOrderTokenName(statement, identifier.name)) {
      return true;
    }
  }

  return false;
}

bool _statementDeclaresNonOrderTokenName(Statement statement, String name) {
  if (statement is FunctionDeclarationStatement) {
    final declaration = statement.functionDeclaration;

    return declaration.name.lexeme == name &&
        !_nodeMentionsIdentifier(
          declaration.functionExpression.body,
          'orderToken',
        );
  }
  if (statement is VariableDeclarationStatement) {
    return _variableListDeclaresNonOrderTokenName(statement.variables, name);
  }

  return false;
}

bool _unitHasNonOrderTokenDeclaration(CompilationUnit unit, String name) {
  for (final declaration in unit.declarations) {
    if (declaration is FunctionDeclaration &&
        declaration.name.lexeme == name &&
        !_nodeMentionsIdentifier(
          declaration.functionExpression.body,
          'orderToken',
        )) {
      return true;
    }
    if (declaration is TopLevelVariableDeclaration &&
        _variableListDeclaresNonOrderTokenName(declaration.variables, name)) {
      return true;
    }
  }

  return false;
}

bool _variableListDeclaresNonOrderTokenName(
  VariableDeclarationList variables,
  String name,
) {
  for (final variable in variables.variables) {
    final initializer = variable.initializer;
    if (variable.name.lexeme == name &&
        (initializer == null ||
            !_nodeMentionsIdentifier(initializer, 'orderToken'))) {
      return true;
    }
  }

  return false;
}

final class _OrderTokenProjectionVisitor extends RecursiveAstVisitor<void> {
  final Set<String> collectionNames = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (initializer != null && _expressionDerivesOrderToken(initializer)) {
      collectionNames.add(node.name.lexeme);
    }
    super.visitVariableDeclaration(node);
  }

  bool _expressionDerivesOrderToken(Expression expression) {
    return _nodeMentionsIdentifier(expression, 'orderToken') ||
        _nodeMentionsAnyIdentifier(expression, collectionNames);
  }
}

bool _nodeMentionsIdentifier(AstNode node, String name) {
  final visitor = _IdentifierPresenceVisitor(name);
  node.accept(visitor);

  return visitor.found;
}

final class _IdentifierPresenceVisitor extends RecursiveAstVisitor<void> {
  _IdentifierPresenceVisitor(this.name);

  final String name;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    found = found || node.name == name;
    super.visitSimpleIdentifier(node);
  }
}

bool _nodeMentionsAnyIdentifier(AstNode node, Set<String> names) {
  if (names.isEmpty) {
    return false;
  }
  final visitor = _AnyIdentifierPresenceVisitor(names);
  node.accept(visitor);

  return visitor.found;
}

final class _AnyIdentifierPresenceVisitor extends RecursiveAstVisitor<void> {
  _AnyIdentifierPresenceVisitor(this.names);

  final Set<String> names;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    found = found || names.contains(node.name);
    super.visitSimpleIdentifier(node);
  }
}

Iterable<ClassDeclaration> _cacheKeyClassDeclarations(
  CompilationUnit unit,
  String className,
) sync* {
  for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
    if (!_classDeclarationHasName(declaration, className)) {
      continue;
    }
    yield declaration;
  }
}

bool _classDeclarationHasName(ClassDeclaration declaration, String className) {
  return declaration.namePart.typeName.lexeme == className;
}

Iterable<String> _classFieldNames(ClassDeclaration declaration) sync* {
  for (final member in declaration.body.members.whereType<FieldDeclaration>()) {
    if (member.isStatic) {
      continue;
    }
    for (final variable in member.fields.variables) {
      yield variable.name.lexeme;
    }
  }
}

Iterable<String> _cacheKeyClassForbiddenTokens(
  ClassDeclaration declaration,
  _OrdinaryCacheKeySurface surface,
) sync* {
  final source = _withoutLineComments(declaration.toSource());
  for (final token in surface.forbiddenTokens) {
    if (RegExp('\\b$token\\b').hasMatch(source)) {
      yield token;
    }
  }
}

Iterable<_ClassDeclaration> _frameCacheDeclarations(String source) sync* {
  final classMatches = RegExp(
    r'\b(?:abstract\s+|base\s+|final\s+|interface\s+|sealed\s+)*class\s+'
    r'([A-Za-z_]\w*)[^{]*extends\s+'
    r'Frame(?:LruCache|ScanResistantLruCache)\b[^{]*\{',
    dotAll: true,
  ).allMatches(source);

  for (final match in classMatches) {
    final name = match.group(1);
    final bodyStart = source.indexOf('{', match.start);
    if (name == null || bodyStart < 0) {
      continue;
    }
    final body = _balancedBody(source, bodyStart);
    if (body == null) {
      continue;
    }
    yield _ClassDeclaration(name: name, body: body);
  }
}

bool _constructorSetsExplicitCapacity(_ClassDeclaration declaration) {
  final escapedName = RegExp.escape(declaration.name);
  final constructorPattern = RegExp(
    '\\b$escapedName'
    r'(?:\.[A-Za-z_]\w*)?\s*\([^;{}]*\)\s*:\s*[^;{}]*'
    r'\bsuper\s*\(\s*capacity\s*:',
    dotAll: true,
  );

  return constructorPattern.hasMatch(declaration.body);
}

final class _ClassDeclaration {
  const _ClassDeclaration({required this.name, required this.body});

  final String name;
  final String body;
}

String? _classBody(String? source, String className) {
  if (source == null) {
    return null;
  }
  final classMatch = RegExp(
    r'\b(?:abstract\s+|base\s+|final\s+|interface\s+|sealed\s+)*class\s+' +
        RegExp.escape(className) +
        r'\b',
  ).firstMatch(source);
  if (classMatch == null) {
    return null;
  }
  final bodyStart = source.indexOf('{', classMatch.end);
  if (bodyStart < 0) {
    return null;
  }

  return _balancedBody(source, bodyStart);
}

String? _balancedBody(String source, int bodyStart) {
  var depth = 0;
  for (var index = bodyStart; index < source.length; index += 1) {
    final character = source[index];
    if (character == '{') {
      depth += 1;
    } else if (character == '}') {
      depth -= 1;
      if (depth == 0) {
        // Body indexes are derived from source code-unit positions; substring
        // keeps the extracted method body aligned with those parser offsets.
        // ignore: avoid-substring
        return source.substring(bodyStart + 1, index);
      }
    }
  }

  return null;
}
