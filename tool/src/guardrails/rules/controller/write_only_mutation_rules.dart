import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../../support/guardrail_ast_utils.dart';
import '../../support/guardrail_context.dart';
import '../../support/guardrail_path_utils.dart';
import '../../core/element_violation_builder.dart';
import '../../core/guardrail_runner_support.dart';
import '../../core/resolved_surface_contract_support.dart';
import 'committed_read_side_rules.dart';
import '../../core/guardrail_element_utils.dart' as element_utils;
import '../../core/guardrail_violation.dart';

part 'prepared_replace_boundary_rules.dart';

Future<List<GuardrailViolation>> runControllerApiGuardrails({
  required GuardrailContext context,
}) async {
  final violations = <GuardrailViolation>[];
  final dartFiles = _controllerDartFiles(context);
  var hasControllerEpoch = false;
  for (final file in dartFiles) {
    final fileResult = await _checkControllerFile(context, file);
    hasControllerEpoch = hasControllerEpoch || fileResult.hasControllerEpoch;
    if (fileResult.violation case final violation?) {
      violations.add(violation);
      return violations;
    }
  }

  final committedReadSideViolation = await _checkCommittedReadSideHermeticity(
    context,
  );
  if (committedReadSideViolation != null) {
    violations.add(committedReadSideViolation);
    return violations;
  }

  final preparedReplaceSceneViolation =
      await _checkPreparedReplaceSceneBoundaryHermeticity(context);
  if (preparedReplaceSceneViolation != null) {
    violations.add(preparedReplaceSceneViolation);
    return violations;
  }

  if (dartFiles.isEmpty) {
    return violations;
  }

  if (!hasControllerEpoch) {
    violations.add(
      GuardrailViolation(
        filePath: '/lib/src/controller',
        line: 1,
        message:
            'controller API violation: controllerEpoch symbol is required '
            'for epoch invalidation guardrails',
      ),
    );
  }
  return violations;
}

const Set<String> _committedReadSideHelperNames = <String>{
  'queryHitTestCandidates',
  'queryPaintCandidates',
  'resolveSpatialCandidateSnapshot',
  'resolveSnapshotNodeById',
  'centerWorldForNodeSnapshots',
};

const Set<String> _allowedSceneStoreControllerSpatialAccessPublicMemberNames =
    _committedReadSideHelperNames;

const Set<String> _bannedCommittedReadSideHelperNames = <String>{
  'backgroundLayerNodes',
  'resolveSpatialCandidateNode',
  'resolveNodeById',
};

const Set<String> _allowedSceneHitTestSpatialCandidateFieldNames = <String>{
  'nodeId',
  'layerIndex',
  'nodeIndex',
  'hitTestBoundsWorld',
};

const Set<String> _allowedScenePaintSpatialCandidateFieldNames = <String>{
  'nodeId',
  'layerIndex',
  'nodeIndex',
  'paintBoundsWorld',
};

List<File> _controllerDartFiles(GuardrailContext context) {
  return collectSortedLibSrcDartFiles(context, relativePath: 'controller');
}

Future<ControllerFileResult> _checkControllerFile(
  GuardrailContext context,
  File file,
) async {
  final filePosixPath = toRepoRelPosixPath(
    absPosixPath: toPosixPath(file.absolute.path),
    rootAbsPosixPath: context.rootAbsPosixPath,
  );
  final parsed = parseUnitOrFail(
    context: context,
    absPath: file.absolute.path,
    filePathForDiag: filePosixPath,
    onFailure: _onParseFailure,
  );
  final resolved = await context.getResolvedUnitResult(file.absolute.path);
  final inspection = _inspectControllerFile(parsed);
  return ControllerFileResult(
    hasControllerEpoch: inspection.hasControllerEpoch,
    violation:
        _sceneViewRenderStateImportViolation(
          inspection: inspection,
          parsed: parsed,
          filePosixPath: filePosixPath,
        ) ??
        _sceneStoreControllerViewRenderStateViolation(
          context: context,
          resolved: resolved,
        ) ??
        _sceneWriterSelectionRoutingViolation(
          context: context,
          resolved: resolved,
          filePosixPath: filePosixPath,
        ),
  );
}

GuardrailViolation? _sceneViewRenderStateImportViolation({
  required _ControllerFileInspection inspection,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  return _controllerSymbolOccurrenceViolation(
    occurrence: inspection.sceneViewRenderStateImport,
    parsed: parsed,
    filePosixPath: filePosixPath,
    message:
        'controller API violation: controller layer must not import '
        'scene_view_render_state.dart',
  );
}

GuardrailViolation? _sceneStoreControllerViewRenderStateViolation({
  required GuardrailContext context,
  required ResolvedUnitResult? resolved,
}) {
  if (resolved == null) {
    return null;
  }
  final controller = _firstClassNamed(
    resolved.libraryElement.classes,
    'SceneStoreController',
  );
  if (controller == null) {
    return null;
  }
  if (!_implementsForbiddenType(
    typeOwner: controller,
    context: context,
    forbiddenRepoRelPath: '/lib/src/contract/scene_view_render_state.dart',
    forbiddenTypeName: 'SceneViewRenderState',
  )) {
    return null;
  }
  return buildElementGuardrailViolation(
    context: context,
    sourceElement: controller,
    message:
        'controller API violation: SceneStoreController must not implement '
        'SceneViewRenderState',
  );
}

GuardrailViolation? _controllerSymbolOccurrenceViolation({
  required ControllerSymbolOccurrence? occurrence,
  required ParsedUnitResult parsed,
  required String filePosixPath,
  required String message,
}) {
  if (occurrence == null) {
    return null;
  }
  return GuardrailViolation(
    filePath: filePosixPath,
    line: lineForOffset(parsed, occurrence.offset),
    message: message,
  );
}

GuardrailViolation? _sceneWriterSelectionRoutingViolation({
  required GuardrailContext context,
  required ResolvedUnitResult? resolved,
  required String filePosixPath,
}) {
  if (filePosixPath != '/lib/src/controller/scene_writer_selection.dart' ||
      resolved == null) {
    return null;
  }

  final functionsByName = <String, FunctionDeclaration>{
    for (final declaration in resolved.unit.declarations)
      if (declaration is FunctionDeclaration)
        declaration.name.lexeme: declaration,
  };
  for (final spec in _selectionWriterRoutingSpecs) {
    final function = functionsByName[spec.functionName];
    if (function == null) {
      return GuardrailViolation(
        filePath: filePosixPath,
        line: 1,
        message:
            'controller API violation: selection writer entrypoint '
            '"${spec.functionName}" must route through canonical '
            '${spec.opTypeName} execution.',
      );
    }
    final routingAnalysis = _analyzeSelectionRouting(
      context: context,
      function: function,
      spec: spec,
    );
    if (routingAnalysis.hasCanonicalRoute &&
        !routingAnalysis.hasForbiddenDirectSelectionMutation) {
      continue;
    }
    return GuardrailViolation(
      filePath: filePosixPath,
      line: resolved.lineInfo.getLocation(function.name.offset).lineNumber,
      message:
          'controller API violation: selection writer entrypoint '
          '"${spec.functionName}" must route through canonical '
          '${spec.opTypeName} execution.',
    );
  }
  return null;
}

Future<GuardrailViolation?> _checkCommittedReadSideHermeticity(
  GuardrailContext context,
) async {
  final surfacePresence = await _committedReadSideSurfacePresence(context);
  if (!surfacePresence.hasAny) {
    return null;
  }
  final missingSurfaceViolation = _missingCommittedReadSideSurfaceViolation(
    surfacePresence,
  );
  if (missingSurfaceViolation != null) {
    return missingSurfaceViolation;
  }
  if (!surfacePresence.hasSpatialFile) {
    return null;
  }
  final spatialCandidateViolation = await _checkSpatialCandidateHermeticity(
    context,
  );
  if (spatialCandidateViolation != null) {
    return spatialCandidateViolation;
  }
  return _checkControllerReadHelperHermeticity(context);
}

Future<_CommittedReadSideSurfacePresence> _committedReadSideSurfacePresence(
  GuardrailContext context,
) async {
  final controllerFile = _sceneStoreControllerFile(context);
  final spatialFile = _sceneSpatialIndexFile(context);
  final controllerDeclaresCommittedReadSurface = controllerFile.existsSync()
      ? await _controllerFileDeclaresCommittedReadSurface(
          context,
          controllerFile,
        )
      : false;
  return _CommittedReadSideSurfacePresence(
    hasControllerFile: controllerFile.existsSync(),
    hasSpatialFile: spatialFile.existsSync(),
    controllerDeclaresCommittedReadSurface:
        controllerDeclaresCommittedReadSurface,
  );
}

GuardrailViolation? _missingCommittedReadSideSurfaceViolation(
  _CommittedReadSideSurfacePresence presence,
) {
  if (presence.hasSpatialFile && !presence.hasControllerFile) {
    return GuardrailViolation(
      filePath: '/lib/src/controller/scene_store_controller.dart',
      line: 1,
      message:
          'controller API violation: committed read helper owner file '
          'scene_store_controller.dart is required when '
          'scene_spatial_index.dart exists.',
    );
  }
  if (presence.controllerDeclaresCommittedReadSurface &&
      !presence.hasSpatialFile) {
    return GuardrailViolation(
      filePath: '/lib/src/core/scene_spatial_index.dart',
      line: 1,
      message:
          'controller API violation: committed spatial payload file '
          'scene_spatial_index.dart is required when committed read helpers '
          'exist.',
    );
  }
  return null;
}

Future<GuardrailViolation?> _checkSpatialCandidateHermeticity(
  GuardrailContext context,
) async {
  final spatialFile = _sceneSpatialIndexFile(context);
  if (!spatialFile.existsSync()) {
    return GuardrailViolation(
      filePath: '/lib/src/core/scene_spatial_index.dart',
      line: 1,
      message:
          'controller API violation: committed spatial payload file '
          'scene_spatial_index.dart is required.',
    );
  }

  final resolved = await context.getResolvedLibraryResult(spatialFile.path);
  if (resolved == null) {
    return null;
  }
  for (final aliasName in _requiredSpatialPayloadAliasNames) {
    if (_firstTypeAliasNamed(resolved.element.typeAliases, aliasName) != null) {
      continue;
    }
    return GuardrailViolation(
      filePath: '/lib/src/core/scene_spatial_index.dart',
      line: 1,
      message:
          'controller API violation: committed spatial payload owner '
          '"$aliasName" is required in scene_spatial_index.dart',
    );
  }
  final hitTestCandidate = _firstClassNamed(
    resolved.element.classes,
    'SceneHitTestSpatialCandidate',
  );
  if (hitTestCandidate == null) {
    return GuardrailViolation(
      filePath: '/lib/src/core/scene_spatial_index.dart',
      line: 1,
      message:
          'controller API violation: committed spatial payload owner '
          '"SceneHitTestSpatialCandidate" is required in '
          'scene_spatial_index.dart',
    );
  }
  final paintCandidate = _firstClassNamed(
    resolved.element.classes,
    'ScenePaintSpatialCandidate',
  );
  if (paintCandidate == null) {
    return GuardrailViolation(
      filePath: '/lib/src/core/scene_spatial_index.dart',
      line: 1,
      message:
          'controller API violation: committed spatial payload owner '
          '"ScenePaintSpatialCandidate" is required in '
          'scene_spatial_index.dart',
    );
  }

  final hitTestViolation = _sealedSpatialPayloadViolation(
    context: context,
    payloadOwner: hitTestCandidate,
    allowedFieldNames: _allowedSceneHitTestSpatialCandidateFieldNames,
  );
  if (hitTestViolation != null) {
    return hitTestViolation;
  }
  return _sealedSpatialPayloadViolation(
    context: context,
    payloadOwner: paintCandidate,
    allowedFieldNames: _allowedScenePaintSpatialCandidateFieldNames,
  );
}

GuardrailViolation? _sealedSpatialPayloadViolation({
  required GuardrailContext context,
  required ClassElement payloadOwner,
  required Set<String> allowedFieldNames,
}) {
  for (final field in payloadOwner.fields.where(
    (field) => !field.isSynthetic && isPublicName(field.displayName),
  )) {
    final leak = findForbiddenResolvedTypeLeak(
      type: field.type,
      sourceElement: field,
      context: context,
      forbiddenTypes: committedReadForbiddenTypeSpecs,
    );
    if (leak == null) {
      if (!allowedFieldNames.contains(field.displayName)) {
        return _committedReadSideViolation(
          context: context,
          sourceElement: field,
          detail:
              'committed spatial payload "${payloadOwner.displayName}.'
              '${field.displayName}" must not extend the sealed locator-only '
              'field surface.',
        );
      }
      continue;
    }
    return _committedReadSideViolation(
      context: context,
      sourceElement: field,
      detail:
          'committed spatial payload "${payloadOwner.displayName}.'
          '${field.displayName}" must not expose live runtime scene-graph '
          'types (${leak.forbiddenTypeName}).',
    );
  }

  final publicFieldNames = payloadOwner.fields
      .where((field) => !field.isSynthetic && isPublicName(field.displayName))
      .map((field) => field.displayName)
      .toSet();
  for (final requiredFieldName in allowedFieldNames) {
    if (publicFieldNames.contains(requiredFieldName)) {
      continue;
    }
    return _committedReadSideViolation(
      context: context,
      sourceElement: payloadOwner,
      detail:
          'committed spatial payload "${payloadOwner.displayName}" must '
          'keep required locator field "$requiredFieldName" on the sealed '
          'surface.',
    );
  }

  for (final constructor in payloadOwner.constructors) {
    final violation = _spatialCandidateConstructorViolation(
      constructor,
      context: context,
      payloadOwnerName: payloadOwner.displayName,
      allowedParameterNames: allowedFieldNames,
    );
    if (violation != null) {
      return violation;
    }
  }

  for (final getter in payloadOwner.getters.where(
    (getter) => !getter.isSynthetic && isPublicName(getter.displayName),
  )) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: getter,
      detail:
          'committed spatial payload "${payloadOwner.displayName}."'
          '${getter.displayName}" must not add custom public accessors '
          'outside the sealed locator-only field surface.',
    );
  }

  for (final setter in payloadOwner.setters.where(
    (setter) => !setter.isSynthetic && isPublicName(setter.displayName),
  )) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: setter,
      detail:
          'committed spatial payload "${payloadOwner.displayName}."'
          '${setter.displayName}" must not add custom public accessors '
          'outside the sealed locator-only field surface.',
    );
  }

  for (final method in payloadOwner.methods.where(
    (method) => isPublicName(method.displayName),
  )) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: method,
      detail:
          'committed spatial payload "${payloadOwner.displayName}."'
          '${method.displayName}" must not add public methods outside the '
          'sealed locator-only field surface.',
    );
  }

  return null;
}

Future<GuardrailViolation?> _checkControllerReadHelperHermeticity(
  GuardrailContext context,
) async {
  final controllerFile = _sceneStoreControllerFile(context);
  if (!controllerFile.existsSync()) {
    return null;
  }

  final resolved = await context.getResolvedLibraryResult(controllerFile.path);
  if (resolved == null) {
    return null;
  }
  final parsed = parseUnitOrFail(
    context: context,
    absPath: controllerFile.path,
    filePathForDiag: '/lib/src/controller/scene_store_controller.dart',
    onFailure: _onParseFailure,
  );
  final extensionElement = _firstExtensionNamed(
    resolved.element.extensions,
    'SceneStoreControllerSpatialAccess',
  );
  if (extensionElement == null) {
    return GuardrailViolation(
      filePath: '/lib/src/controller/scene_store_controller.dart',
      line: 1,
      message:
          'controller API violation: sealed helper surface owner '
          '"SceneStoreControllerSpatialAccess" is required in '
          'scene_store_controller.dart',
    );
  }
  final extensionDeclaration = _firstExtensionDeclarationNamed(
    parsed.unit.declarations,
    'SceneStoreControllerSpatialAccess',
  );
  if (extensionDeclaration == null) {
    return GuardrailViolation(
      filePath: '/lib/src/controller/scene_store_controller.dart',
      line: 1,
      message:
          'controller API violation: sealed helper surface owner '
          '"SceneStoreControllerSpatialAccess" is required in '
          'scene_store_controller.dart',
    );
  }
  if (!_hasDeclaredExtensionTarget(
    extensionElement: extensionElement,
    context: context,
    targetRepoRelPath: '/lib/src/controller/scene_store_controller.dart',
    targetTypeName: 'SceneStoreController',
  )) {
    return GuardrailViolation(
      filePath: '/lib/src/controller/scene_store_controller.dart',
      line: lineForOffset(parsed, extensionDeclaration.name?.offset ?? 0),
      message:
          'controller API violation: sealed helper surface owner '
          '"SceneStoreControllerSpatialAccess" must extend '
          'SceneStoreController.',
    );
  }
  final astMethodsByName = <String, MethodDeclaration>{
    for (final member in extensionDeclaration.members)
      if (member is MethodDeclaration &&
          member.name.lexeme.isNotEmpty &&
          isPublicName(member.name.lexeme))
        member.name.lexeme: member,
  };

  final publicMembers = <ExecutableElement>[
    ...extensionElement.methods.where(
      (method) =>
          method.displayName.isNotEmpty && isPublicName(method.displayName),
    ),
    ...extensionElement.getters.where(
      (getter) =>
          !getter.isSynthetic &&
          getter.displayName.isNotEmpty &&
          isPublicName(getter.displayName),
    ),
    ...extensionElement.setters.where(
      (setter) =>
          !setter.isSynthetic &&
          setter.displayName.isNotEmpty &&
          isPublicName(setter.displayName),
    ),
  ];

  for (final member in publicMembers) {
    if (_bannedCommittedReadSideHelperNames.contains(member.displayName)) {
      return _committedReadSideViolation(
        context: context,
        sourceElement: member,
        detail:
            'legacy committed read helper "${member.displayName}" must not '
            'remain on SceneStoreController.',
      );
    }
    if (!_allowedSceneStoreControllerSpatialAccessPublicMemberNames.contains(
      member.displayName,
    )) {
      return _committedReadSideViolation(
        context: context,
        sourceElement: member,
        detail:
            'SceneStoreControllerSpatialAccess public member '
            '"${member.displayName}" must not extend the sealed helper '
            'surface.',
      );
    }

    final leak = findForbiddenExecutableSignatureLeak(
      element: member,
      context: context,
      forbiddenTypes: committedReadForbiddenTypeSpecs,
    );
    if (leak == null) {
      final signatureViolation = _astCommittedReadHelperSignatureViolation(
        memberName: member.displayName,
        astMember: astMethodsByName[member.displayName],
        context: context,
        sourceElement: member,
      );
      if (signatureViolation != null) {
        return signatureViolation;
      }
      continue;
    }
    return _committedReadSideViolation(
      context: context,
      sourceElement: member,
      detail: _committedReadSideHelperNames.contains(member.displayName)
          ? 'committed read helper "${member.displayName}" must not expose '
                'live runtime scene-graph types '
                '(${leak.forbiddenTypeName}).'
          : 'committed controller surface member "${member.displayName}" '
                'must not expose live runtime scene-graph types '
                '(${leak.forbiddenTypeName}).',
    );
  }

  final publicMemberNames = publicMembers
      .map((member) => member.displayName)
      .toSet();
  for (final requiredHelperName in _committedReadSideHelperNames) {
    if (publicMemberNames.contains(requiredHelperName)) {
      continue;
    }
    return _committedReadSideViolation(
      context: context,
      sourceElement: extensionElement,
      detail:
          'SceneStoreControllerSpatialAccess must keep committed read helper '
          '"$requiredHelperName" on the sealed helper surface.',
    );
  }

  return null;
}

GuardrailViolation? _astCommittedReadHelperSignatureViolation({
  required String memberName,
  required MethodDeclaration? astMember,
  required GuardrailContext context,
  required Element sourceElement,
}) {
  final expected = switch (memberName) {
    'queryHitTestCandidates' => (
      returnType: 'List<SceneHitTestSpatialCandidate>',
      parameters:
          <
            ({
              String type,
              String name,
              bool isNamed,
              bool isRequiredNamed,
              String? defaultValueSource,
            })
          >[
            (
              type: 'Rect',
              name: 'worldBounds',
              isNamed: false,
              isRequiredNamed: false,
              defaultValueSource: null,
            ),
          ],
    ),
    'queryPaintCandidates' => (
      returnType: 'List<ScenePaintSpatialCandidate>',
      parameters:
          <
            ({
              String type,
              String name,
              bool isNamed,
              bool isRequiredNamed,
              String? defaultValueSource,
            })
          >[
            (
              type: 'Rect',
              name: 'worldBounds',
              isNamed: false,
              isRequiredNamed: false,
              defaultValueSource: null,
            ),
            (
              type: 'ScenePaintSpatialQueryScope',
              name: 'scope',
              isNamed: true,
              isRequiredNamed: false,
              defaultValueSource:
                  'ScenePaintSpatialQueryScope.contentLayersOnly',
            ),
          ],
    ),
    'resolveSpatialCandidateSnapshot' => (
      returnType: 'NodeSnapshot?',
      parameters:
          <
            ({
              String type,
              String name,
              bool isNamed,
              bool isRequiredNamed,
              String? defaultValueSource,
            })
          >[
            (
              type: 'SceneSpatialCandidateReference',
              name: 'candidate',
              isNamed: false,
              isRequiredNamed: false,
              defaultValueSource: null,
            ),
          ],
    ),
    'resolveSnapshotNodeById' => (
      returnType: '({NodeSnapshot node, int layerIndex, int nodeIndex})?',
      parameters:
          <
            ({
              String type,
              String name,
              bool isNamed,
              bool isRequiredNamed,
              String? defaultValueSource,
            })
          >[
            (
              type: 'NodeId',
              name: 'nodeId',
              isNamed: false,
              isRequiredNamed: false,
              defaultValueSource: null,
            ),
          ],
    ),
    'centerWorldForNodeSnapshots' => (
      returnType: 'Offset',
      parameters:
          <
            ({
              String type,
              String name,
              bool isNamed,
              bool isRequiredNamed,
              String? defaultValueSource,
            })
          >[
            (
              type: 'Iterable<NodeSnapshot>',
              name: 'snapshots',
              isNamed: false,
              isRequiredNamed: false,
              defaultValueSource: null,
            ),
          ],
    ),
    _ => null,
  };
  if (expected == null) {
    return null;
  }
  if (astMember == null || astMember.typeParameters != null) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: sourceElement,
      detail:
          'committed read helper "$memberName" must keep the exact sealed '
          'signature.',
    );
  }
  final returnType = astMember.returnType;
  if (returnType == null ||
      _nodeSourceText(returnType) != expected.returnType) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: sourceElement,
      detail:
          'committed read helper "$memberName" must keep the exact sealed '
          'signature.',
    );
  }
  final parameters =
      astMember.parameters?.parameters ?? const <FormalParameter>[];
  if (parameters.length != expected.parameters.length) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: sourceElement,
      detail:
          'committed read helper "$memberName" must keep the exact sealed '
          'signature.',
    );
  }
  for (var i = 0; i < parameters.length; i++) {
    final parameter = parameters[i];
    final expectedParameter = expected.parameters[i];
    if (!_matchesSealedCommittedReadParameter(
      parameter,
      type: expectedParameter.type,
      name: expectedParameter.name,
      isNamed: expectedParameter.isNamed,
      isRequiredNamed: expectedParameter.isRequiredNamed,
      defaultValueSource: expectedParameter.defaultValueSource,
    )) {
      return _committedReadSideViolation(
        context: context,
        sourceElement: sourceElement,
        detail:
            'committed read helper "$memberName" must keep the exact sealed '
            'signature.',
      );
    }
  }
  return null;
}

bool _matchesSealedCommittedReadParameter(
  FormalParameter parameter, {
  required String type,
  required String name,
  required bool isNamed,
  required bool isRequiredNamed,
  required String? defaultValueSource,
}) {
  if (!isNamed) {
    if (parameter is! SimpleFormalParameter) {
      return false;
    }
    final parameterType = parameter.type;
    return parameter.name?.lexeme == name &&
        parameterType != null &&
        _nodeSourceText(parameterType) == type &&
        parameter.isPositional;
  }

  if (parameter is! DefaultFormalParameter) {
    return false;
  }
  final inner = parameter.parameter;
  if (inner is! SimpleFormalParameter) {
    return false;
  }
  final innerType = inner.type;
  if (inner.name?.lexeme != name ||
      innerType == null ||
      _nodeSourceText(innerType) != type) {
    return false;
  }
  if (!parameter.isNamed || parameter.isRequiredNamed != isRequiredNamed) {
    return false;
  }
  final defaultValue = parameter.defaultValue;
  final actualDefault = defaultValue == null
      ? null
      : _nodeSourceText(defaultValue);
  return actualDefault == defaultValueSource;
}

String _nodeSourceText(AstNode node) {
  final buffer = StringBuffer();
  Token? previous;
  var token = node.beginToken;
  while (true) {
    if (previous != null && _needsSpaceBetweenTokens(previous, token)) {
      buffer.write(' ');
    }
    buffer.write(token.lexeme);
    if (identical(token, node.endToken)) {
      break;
    }
    previous = token;
    final nextToken = token.next;
    if (nextToken == null) {
      break;
    }
    token = nextToken;
  }
  return buffer.toString();
}

bool _needsSpaceBetweenTokens(Token previous, Token next) {
  final previousLexeme = previous.lexeme;
  final nextLexeme = next.lexeme;
  if (previousLexeme == ',' || previousLexeme == ':') {
    return true;
  }
  if (_noTrailingSpaceTokenLexemes.contains(previousLexeme) ||
      _noLeadingSpaceTokenLexemes.contains(nextLexeme)) {
    return false;
  }
  return _isWordLikeTokenLexeme(previousLexeme) &&
      _isWordLikeTokenLexeme(nextLexeme);
}

bool _isWordLikeTokenLexeme(String lexeme) {
  return RegExp(r'^[A-Za-z0-9_$]+$').hasMatch(lexeme);
}

const Set<String> _noTrailingSpaceTokenLexemes = <String>{'(', '{', '<', '.'};

const Set<String> _noLeadingSpaceTokenLexemes = <String>{
  ',',
  ')',
  '}',
  '>',
  '?',
  '.',
  ';',
};

final class _CommittedReadSideSurfacePresence {
  const _CommittedReadSideSurfacePresence({
    required this.hasControllerFile,
    required this.hasSpatialFile,
    required this.controllerDeclaresCommittedReadSurface,
  });

  final bool hasControllerFile;
  final bool hasSpatialFile;
  final bool controllerDeclaresCommittedReadSurface;

  bool get hasAny => hasControllerFile || hasSpatialFile;
}

Future<bool> _controllerFileDeclaresCommittedReadSurface(
  GuardrailContext context,
  File controllerFile,
) async {
  final resolved = await context.getResolvedLibraryResult(controllerFile.path);
  if (resolved == null) {
    return false;
  }
  final extension = _firstExtensionNamed(
    resolved.element.extensions,
    'SceneStoreControllerSpatialAccess',
  );
  if (extension != null) {
    return true;
  }
  return _libraryDeclaresAnyNamedSurface(
    resolved.element,
    names: <String>{
      ..._committedReadSideHelperNames,
      ..._allowedSceneStoreControllerSpatialAccessPublicMemberNames,
      ..._bannedCommittedReadSideHelperNames,
    },
  );
}

File _sceneStoreControllerFile(GuardrailContext context) {
  return libSrcFile(
    context,
    relativePath: 'controller/scene_store_controller.dart',
  );
}

File _sceneSpatialIndexFile(GuardrailContext context) {
  return libSrcFile(context, relativePath: 'core/scene_spatial_index.dart');
}

GuardrailViolation? _spatialCandidateConstructorViolation(
  ConstructorElement constructor, {
  required GuardrailContext context,
  required String payloadOwnerName,
  required Set<String> allowedParameterNames,
}) {
  final constructorName = element_utils.normalizedConstructorName(constructor);
  return validatePublicConstructorSurface(
    constructor: constructor,
    context: context,
    allowedParameterNames: allowedParameterNames,
    findForbiddenSignatureLeak: (constructor) {
      final leak = findForbiddenExecutableSignatureLeak(
        element: constructor,
        context: context,
        forbiddenTypes: committedReadForbiddenTypeSpecs,
      );
      if (leak == null) {
        return null;
      }
      return (
        forbiddenTypeName: leak.forbiddenTypeName,
        sourceElement: leak.sourceElement,
      );
    },
    buildViolation: _committedReadSideViolation,
    namedConstructorDetail:
        'committed spatial payload "$payloadOwnerName.$constructorName" '
        'must not add public named constructors outside the sealed '
        'locator-only field surface.',
    forbiddenTypeDetail: (forbiddenTypeName) =>
        'committed spatial payload constructor for "$payloadOwnerName" '
        'must not expose live runtime scene-graph types '
        '($forbiddenTypeName).',
    extraParameterDetail: (parameterName) =>
        'committed spatial payload constructor for "$payloadOwnerName" '
        'must not extend the sealed locator-only field surface with '
        'parameter "$parameterName".',
  );
}

ClassElement? _firstClassNamed(Iterable<ClassElement> classes, String name) {
  for (final element in classes) {
    if (element.displayName == name) {
      return element;
    }
  }
  return null;
}

TypeAliasElement? _firstTypeAliasNamed(
  Iterable<TypeAliasElement> typeAliases,
  String name,
) {
  for (final element in typeAliases) {
    if (element.displayName == name) {
      return element;
    }
  }
  return null;
}

ExtensionElement? _firstExtensionNamed(
  Iterable<ExtensionElement> extensions,
  String name,
) {
  for (final element in extensions) {
    if (element.displayName == name) {
      return element;
    }
  }
  return null;
}

ExtensionDeclaration? _firstExtensionDeclarationNamed(
  Iterable<CompilationUnitMember> declarations,
  String name,
) {
  for (final declaration in declarations) {
    if (declaration is ExtensionDeclaration &&
        declaration.name?.lexeme == name) {
      return declaration;
    }
  }
  return null;
}

GuardrailViolation? _committedReadSideViolation({
  required GuardrailContext context,
  required Element sourceElement,
  required String detail,
}) {
  return buildElementGuardrailViolation(
    context: context,
    sourceElement: sourceElement,
    message: 'controller API violation: $detail',
  );
}

Never _onParseFailure({
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

class ControllerSymbolOccurrence {
  const ControllerSymbolOccurrence({required this.name, required this.offset});

  final String name;
  final int offset;
}

final class _ControllerFileInspection {
  const _ControllerFileInspection({
    required this.hasControllerEpoch,
    required this.sceneViewRenderStateImport,
  });

  final bool hasControllerEpoch;
  final ControllerSymbolOccurrence? sceneViewRenderStateImport;
}

_ControllerFileInspection _inspectControllerFile(ParsedUnitResult parsed) {
  final collector = _ControllerSyntaxCollector();
  parsed.unit.accept(collector);
  return _ControllerFileInspection(
    hasControllerEpoch: collector.hasControllerEpoch,
    sceneViewRenderStateImport: collector.sceneViewRenderStateImport,
  );
}

final class _ControllerSyntaxCollector extends RecursiveAstVisitor<void> {
  bool hasControllerEpoch = false;
  ControllerSymbolOccurrence? sceneViewRenderStateImport;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'controllerEpoch') {
      hasControllerEpoch = true;
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri != null && uri.endsWith('scene_view_render_state.dart')) {
      sceneViewRenderStateImport = ControllerSymbolOccurrence(
        name: uri,
        offset: node.uri.offset,
      );
    }
    super.visitImportDirective(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.name.lexeme == 'controllerEpoch') {
      hasControllerEpoch = true;
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'controllerEpoch') {
      hasControllerEpoch = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

const Set<String> _requiredSpatialPayloadAliasNames = <String>{
  'SceneSpatialCandidateLocation',
  'SceneSpatialCandidateReference',
};

final class _SelectionWriterRoutingSpec {
  const _SelectionWriterRoutingSpec({
    required this.functionName,
    required this.opTypeName,
  });

  final String functionName;
  final String opTypeName;
}

const List<_SelectionWriterRoutingSpec> _selectionWriterRoutingSpecs =
    <_SelectionWriterRoutingSpec>[
      _SelectionWriterRoutingSpec(
        functionName: 'sceneWriterWriteSelectionReplaceResult',
        opTypeName: 'ReplaceSelectionOp',
      ),
      _SelectionWriterRoutingSpec(
        functionName: 'sceneWriterWriteSelectionToggle',
        opTypeName: 'ToggleSelectionOp',
      ),
      _SelectionWriterRoutingSpec(
        functionName: 'sceneWriterWriteSelectionClear',
        opTypeName: 'ClearSelectionOp',
      ),
      _SelectionWriterRoutingSpec(
        functionName: 'sceneWriterWriteSelectionSelectAllResult',
        opTypeName: 'SelectAllSelectionOp',
      ),
    ];

final class _SelectionRoutingAnalysis {
  const _SelectionRoutingAnalysis({
    required this.hasCanonicalRoute,
    required this.hasForbiddenDirectSelectionMutation,
  });

  final bool hasCanonicalRoute;
  final bool hasForbiddenDirectSelectionMutation;
}

_SelectionRoutingAnalysis _analyzeSelectionRouting({
  required GuardrailContext context,
  required FunctionDeclaration function,
  required _SelectionWriterRoutingSpec spec,
}) {
  var foundCanonicalRoute = false;
  var foundForbiddenDirectSelectionMutation = false;
  function.functionExpression.body.accept(
    _SelectionRoutingCollector(
      onMethodInvocation: (invocation) {
        if (!foundCanonicalRoute) {
          foundCanonicalRoute = _matchesSelectionRoutingInvocation(
            context: context,
            invocation: invocation,
            spec: spec,
          );
        }
      },
      onPropertyAccess: (propertyAccess) {
        if (foundForbiddenDirectSelectionMutation) {
          return;
        }
        foundForbiddenDirectSelectionMutation = _isForbiddenSelectionSinkAccess(
          propertyAccess.propertyName,
        );
      },
      onPrefixedIdentifier: (identifier) {
        if (foundForbiddenDirectSelectionMutation) {
          return;
        }
        foundForbiddenDirectSelectionMutation = _isForbiddenSelectionSinkAccess(
          identifier.identifier,
        );
      },
    ),
  );
  return _SelectionRoutingAnalysis(
    hasCanonicalRoute: foundCanonicalRoute,
    hasForbiddenDirectSelectionMutation: foundForbiddenDirectSelectionMutation,
  );
}

bool _matchesSelectionRoutingInvocation({
  required GuardrailContext context,
  required MethodInvocation invocation,
  required _SelectionWriterRoutingSpec spec,
}) {
  if (invocation.methodName.name != 'execute') {
    return false;
  }
  final methodElement = invocation.methodName.element;
  if (methodElement is! MethodElement ||
      !_matchesElementIdentity(
        element: methodElement.enclosingElement,
        repoRelPath: '/lib/src/controller/scene_writer_runtime.dart',
        typeName: 'SceneWriterRuntime',
        context: context,
      )) {
    return false;
  }
  final arguments = invocation.argumentList.arguments;
  if (arguments.length != 1) {
    return false;
  }
  final opExpression = switch (arguments.single) {
    NamedExpression(:final expression) => expression.unParenthesized,
    _ => arguments.single.unParenthesized,
  };
  if (opExpression is! InstanceCreationExpression) {
    return false;
  }
  final constructor = opExpression.constructorName.element;
  return matchesTypeIdentity(
    context: context,
    element: constructor?.enclosingElement,
    spec: SurfaceContractTypeIdentitySpec(
      repoRelPath: '/lib/src/controller/mutation_op.dart',
      typeName: spec.opTypeName,
    ),
  );
}

bool _implementsForbiddenType({
  required InterfaceElement typeOwner,
  required GuardrailContext context,
  required String forbiddenRepoRelPath,
  required String forbiddenTypeName,
}) {
  return typeOwner.interfaces.any(
    (interfaceType) => matchesTypeIdentity(
      context: context,
      element: interfaceType.element,
      spec: SurfaceContractTypeIdentitySpec(
        repoRelPath: forbiddenRepoRelPath,
        typeName: forbiddenTypeName,
      ),
    ),
  );
}

bool _hasDeclaredExtensionTarget({
  required ExtensionElement extensionElement,
  required GuardrailContext context,
  required String targetRepoRelPath,
  required String targetTypeName,
}) {
  return matchesTypeIdentity(
    context: context,
    element: extensionElement.extendedType.element,
    spec: SurfaceContractTypeIdentitySpec(
      repoRelPath: targetRepoRelPath,
      typeName: targetTypeName,
    ),
  );
}

bool _matchesElementIdentity({
  required Element? element,
  required String repoRelPath,
  required String typeName,
  required GuardrailContext context,
}) {
  if (element == null || element.displayName != typeName) {
    return false;
  }
  return element_utils.repoRelPathForElement(
        element: element,
        context: context,
      ) ==
      repoRelPath;
}

bool _libraryDeclaresAnyNamedSurface(
  LibraryElement library, {
  required Set<String> names,
}) {
  final normalizedNames = _normalizedSurfaceNames(names);
  final declaredSurfaceNames = <String>{
    ...library.classes.expand(_surfaceNameVariants),
    ...library.extensions.expand(_surfaceNameVariants),
    ...library.typeAliases.expand(_surfaceNameVariants),
    ...library.topLevelFunctions.expand(_surfaceNameVariants),
    ...library.topLevelVariables
        .where((element) => !element.isSynthetic)
        .expand((element) => _prefixedSurfaceNameVariants(element, 'field')),
    ...library.getters
        .where((element) => !element.isSynthetic)
        .expand((element) => _prefixedSurfaceNameVariants(element, 'getter')),
    ...library.setters
        .where((element) => !element.isSynthetic)
        .expand((element) => _prefixedSurfaceNameVariants(element, 'setter')),
    ...library.classes.expand(_memberSurfaceNamesForInterfaceOwner),
    ...library.extensions.expand(_memberSurfaceNamesForExtensionOwner),
  };
  return normalizedNames.any(declaredSurfaceNames.contains);
}

Iterable<String> _memberSurfaceNamesForInterfaceOwner(
  InterfaceElement owner,
) sync* {
  for (final field in owner.fields.where(
    (field) => !field.isSynthetic && isPublicName(field.displayName),
  )) {
    yield* _prefixedSurfaceNameVariants(field, 'field');
  }
  for (final method in owner.methods.where(
    (method) => isPublicName(method.displayName),
  )) {
    yield* _prefixedSurfaceNameVariants(method, 'method');
  }
  for (final getter in owner.getters.where(
    (getter) => !getter.isSynthetic && isPublicName(getter.displayName),
  )) {
    yield* _prefixedSurfaceNameVariants(getter, 'getter');
  }
  for (final setter in owner.setters.where(
    (setter) => !setter.isSynthetic && isPublicName(setter.displayName),
  )) {
    yield* _prefixedSurfaceNameVariants(setter, 'setter');
  }
}

Iterable<String> _memberSurfaceNamesForExtensionOwner(
  ExtensionElement owner,
) sync* {
  for (final method in owner.methods.where(
    (method) => isPublicName(method.displayName),
  )) {
    yield* _prefixedSurfaceNameVariants(method, 'method');
  }
  for (final getter in owner.getters.where(
    (getter) => !getter.isSynthetic && isPublicName(getter.displayName),
  )) {
    yield* _prefixedSurfaceNameVariants(getter, 'getter');
  }
  for (final setter in owner.setters.where(
    (setter) => !setter.isSynthetic && isPublicName(setter.displayName),
  )) {
    yield* _prefixedSurfaceNameVariants(setter, 'setter');
  }
}

final class _SelectionRoutingCollector extends RecursiveAstVisitor<void> {
  _SelectionRoutingCollector({
    required this.onMethodInvocation,
    required this.onPropertyAccess,
    required this.onPrefixedIdentifier,
  });

  final void Function(MethodInvocation invocation) onMethodInvocation;
  final void Function(PropertyAccess propertyAccess) onPropertyAccess;
  final void Function(PrefixedIdentifier identifier) onPrefixedIdentifier;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    onMethodInvocation(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    onPropertyAccess(node);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    onPrefixedIdentifier(node);
    super.visitPrefixedIdentifier(node);
  }
}

bool _isForbiddenSelectionSinkAccess(SimpleIdentifier identifier) {
  return const <String>{
    'workingSelection',
    'changeSet',
  }.contains(identifier.name);
}

Set<String> _normalizedSurfaceNames(Set<String> names) {
  return <String>{
    for (final name in names) ..._surfaceNameVariantsFromRaw(name),
  };
}

Iterable<String> _surfaceNameVariants(Element element) sync* {
  final name = element.displayName;
  if (name.isEmpty) {
    return;
  }
  yield name;
}

Iterable<String> _prefixedSurfaceNameVariants(
  Element element,
  String prefix,
) sync* {
  final name = element.displayName;
  if (name.isEmpty) {
    return;
  }
  yield '$prefix:$name';
  yield name;
}

Iterable<String> _surfaceNameVariantsFromRaw(String name) sync* {
  yield name;
  final separatorIndex = name.indexOf(':');
  if (separatorIndex <= 0 || separatorIndex == name.length - 1) {
    return;
  }
  yield name.substring(separatorIndex + 1);
}
