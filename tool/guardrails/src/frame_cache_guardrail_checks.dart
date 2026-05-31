import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

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
  return [
    for (final entry in sources.entries)
      if (_isFrameSource(entry.key) &&
          _containsForbiddenSceneRecordSort(entry.value))
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
    tokens: const ['selection', 'selectedElementIds', 'selectionRevision'],
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
    final unit = parseString(content: source, throwIfDiagnostics: false).unit;
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
  return [
    for (final surface in _cachedPaintSurfaces)
      if (_classBody(sources[surface.path], surface.className) case final body?)
        if (_containsAny(body, tokens))
          GuardrailViolation(
            guardrailId: guardrailId,
            path: surface.path,
            message: '$message in ${surface.className}',
          ),
  ];
}

const _cachedPaintSurfaces = [
  _CachedPaintSurface('lib/src/frame/paint_plan.dart', 'PaintPlanKey'),
  _CachedPaintSurface(
    'lib/src/frame/paint_plan.dart',
    'OrdinaryPaintRecordKey',
  ),
  _CachedPaintSurface('lib/src/frame/paint_plan.dart', 'PaintPlan'),
  _CachedPaintSurface(
    'lib/src/frame/render_element_record.dart',
    'RenderElementRecord',
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

bool _containsForbiddenSceneRecordSort(String content) {
  final uncommented = _withoutLineComments(content);
  final matches = RegExp(r'\.sort\s*\(').allMatches(uncommented);

  return matches.any(
    (match) => _sortComparatorMentionsOrderToken(uncommented, match.start),
  );
}

String _withoutLineComments(String content) {
  return content
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

bool _sortComparatorMentionsOrderToken(String content, int sortStart) {
  final nextStatement = content.indexOf(';', sortStart);
  final fallbackEnd = sortStart + 240 > content.length
      ? content.length
      : sortStart + 240;
  final expressionEnd = nextStatement < 0 ? fallbackEnd : nextStatement;
  final expression = content.substring(sortStart, expressionEnd);

  return expression.contains('orderToken');
}

bool _containsAny(String content, Iterable<String> tokens) {
  final lowerContent = content.toLowerCase();

  return tokens.any((token) => lowerContent.contains(token.toLowerCase()));
}

bool _containsAll(String content, Iterable<String> tokens) {
  return tokens.every(content.contains);
}

Iterable<ClassDeclaration> _cacheKeyClassDeclarations(
  CompilationUnit unit,
  String className,
) sync* {
  for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
    if (declaration.namePart.typeName.lexeme != className) {
      continue;
    }
    yield declaration;
  }
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
        return source.substring(bodyStart + 1, index);
      }
    }
  }

  return null;
}
