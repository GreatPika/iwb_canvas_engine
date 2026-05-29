import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'guardrail_violation.dart';
import 'repository_paths.dart';

const geometryNoLegacySceneOrderGuardrailId = 'geometry.no_legacy_scene_order';
const geometryEraserExactBudgetGuardrailId =
    'geometry.eraser_exact_budget_no_partial';
const spatialNoFullCloneGuardrailId = 'spatial.no_full_clone_ordinary_edit';
const spatialStaleCandidateGuardrailId = 'spatial.stale_candidate_rejected';
const spatialFallbackBudgetGuardrailId = 'spatial.fallback_budget_enforced';

Future<List<GuardrailViolation>> checkNoLegacySceneOrder() async {
  return [
    for (final file in dartFilesUnder('lib/src/geometry'))
      ...checkNoLegacySceneOrderSource(
        path: relativePath(file),
        content: file.readAsStringSync(),
      ),
  ];
}

List<GuardrailViolation> checkNoLegacySceneOrderSource({
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
          guardrailId: geometryNoLegacySceneOrderGuardrailId,
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
  if (!queryStateContent.contains('SpatialStaleCandidateResult')) {
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
  final remap = content.indexOf('elementHandleForId');
  final generationCheck = content.indexOf(
    'handle.generation != current.generation',
  );
  final orderCheck = content.indexOf('handle.orderToken != current.orderToken');
  final structuralCheck = content.indexOf('handle.structuralRevision');
  final handleReturn = content.indexOf('return handle');

  return remap != -1 &&
      generationCheck != -1 &&
      orderCheck != -1 &&
      structuralCheck != -1 &&
      handleReturn != -1 &&
      remap < generationCheck &&
      generationCheck < handleReturn &&
      orderCheck < handleReturn &&
      structuralCheck < handleReturn;
}

final class _ParsedFunctions {
  _ParsedFunctions(String content) {
    final parsed = parseString(content: content);
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
  if (!tileIndexContent.contains('candidates.length >') ||
      !tileIndexContent.contains('SpatialBudgetExceededResult') ||
      !tileIndexContent.contains('recordFallbackCandidateBudgetExceeded')) {
    violations.add(
      GuardrailViolation(
        guardrailId: spatialFallbackBudgetGuardrailId,
        path: tileIndexPath,
        message:
            'tile fallback must enforce candidate budget with typed no-partial result.',
      ),
    );
  }
  if (!queryStateContent.contains('context.indexedEntryCount >') ||
      !queryStateContent.contains('recordFallbackCandidateBudgetExceeded') ||
      !queryStateContent.contains('SpatialBudgetExceededResult')) {
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
            'P8 eraser guardrail covers primitive and exact-check budget inputs.',
      ),
    );
  }
  if (!hitContent.contains('exactEraserHit')) {
    violations.add(
      GuardrailViolation(
        guardrailId: geometryEraserExactBudgetGuardrailId,
        path: hitPath,
        message: 'P8 eraser exact-hit helper must remain family-owned.',
      ),
    );
  }
  if (geometryContent.contains('partialErase') ||
      hitContent.contains('partialErase')) {
    violations.add(
      GuardrailViolation(
        guardrailId: geometryEraserExactBudgetGuardrailId,
        path: geometryPath,
        message: 'P8 eraser budget checks must not implement partial erases.',
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
      return content.substring(declaration.offset, declaration.end);
    }
  }

  return null;
}
