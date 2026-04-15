import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../guardrail_support/guardrail_ast_utils.dart';
import '../guardrail_support/guardrail_context.dart';
import '../guardrail_support/guardrail_path_utils.dart';
import 'committed_read_side_hermeticity_support.dart';
import 'public_surface_guardrails.dart';

Future<List<GuardrailViolation>> runControllerApiGuardrails({
  required GuardrailContext context,
}) async {
  final violations = <GuardrailViolation>[];
  final dartFiles = _controllerDartFiles(context);
  var hasControllerEpoch = false;
  for (final file in dartFiles) {
    final fileResult = _checkControllerFile(context, file);
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
  'querySpatialCandidates',
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

const Set<String> _allowedSceneSpatialCandidateFieldNames = <String>{
  'nodeId',
  'layerIndex',
  'nodeIndex',
  'candidateBoundsWorld',
};

List<File> _controllerDartFiles(GuardrailContext context) {
  final controllerDir = Directory(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}controller',
  );
  if (!controllerDir.existsSync()) {
    return const <File>[];
  }
  final dartFiles =
      controllerDir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList(growable: false)
        ..sort((a, b) => a.path.compareTo(b.path));
  return dartFiles;
}

ControllerFileResult _checkControllerFile(GuardrailContext context, File file) {
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
  final collector = ControllerSymbolCollector();
  parsed.unit.accept(collector);
  return ControllerFileResult(
    hasControllerEpoch: collector.hasControllerEpoch,
    violation:
        _sceneViewRenderStateImportViolation(
          collector: collector,
          parsed: parsed,
          filePosixPath: filePosixPath,
        ) ??
        _sceneStoreControllerViewRenderStateViolation(
          collector: collector,
          parsed: parsed,
          filePosixPath: filePosixPath,
        ) ??
        _sceneWriterSelectionBypassViolation(
          parsed: parsed,
          filePosixPath: filePosixPath,
        ) ??
        _replaceSceneEpochViolation(
          collector: collector,
          parsed: parsed,
          filePosixPath: filePosixPath,
        ) ??
        _mutatingSymbolViolation(
          collector: collector,
          parsed: parsed,
          filePosixPath: filePosixPath,
        ),
  );
}

GuardrailViolation? _sceneViewRenderStateImportViolation({
  required ControllerSymbolCollector collector,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  final importOccurrence = collector.sceneViewRenderStateImport;
  if (importOccurrence == null) {
    return null;
  }
  return GuardrailViolation(
    filePath: filePosixPath,
    line: lineForOffset(parsed, importOccurrence.offset),
    message:
        'controller API violation: controller layer must not import '
        'scene_view_render_state.dart',
  );
}

GuardrailViolation? _sceneStoreControllerViewRenderStateViolation({
  required ControllerSymbolCollector collector,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  final occurrence = collector.sceneStoreControllerViewRenderStateOccurrence;
  if (occurrence == null) {
    return null;
  }
  return GuardrailViolation(
    filePath: filePosixPath,
    line: lineForOffset(parsed, occurrence.offset),
    message:
        'controller API violation: SceneStoreController must not implement '
        'SceneViewRenderState',
  );
}

GuardrailViolation? _sceneWriterSelectionBypassViolation({
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  if (filePosixPath != '/lib/src/controller/scene_writer_selection.dart') {
    return null;
  }

  const guardedFunctions = <String>{
    'sceneWriterWriteSelectionReplaceResult',
    'sceneWriterWriteSelectionToggle',
    'sceneWriterWriteSelectionClear',
    'sceneWriterWriteSelectionSelectAllResult',
  };
  for (final declaration in parsed.unit.declarations) {
    if (declaration case FunctionDeclaration(
      name: final name,
      functionExpression: final expression,
    )) {
      if (!guardedFunctions.contains(name.lexeme)) {
        continue;
      }
      final bodySource = expression.body.toSource();
      if (bodySource.contains('workingSelection') ||
          bodySource.contains('changeSet')) {
        return GuardrailViolation(
          filePath: filePosixPath,
          line: lineForOffset(parsed, name.offset),
          message:
              'controller API violation: selection writer entrypoints must '
              'route through canonical selection-state mutation ops instead '
              'of touching workingSelection/changeSet directly',
        );
      }
    }
  }
  return null;
}

GuardrailViolation? _replaceSceneEpochViolation({
  required ControllerSymbolCollector collector,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  final replaceSceneOccurrence = collector.occurrences.firstWhere(
    (occurrence) => occurrence.name == 'replaceScene',
    orElse: () => const ControllerSymbolOccurrence(name: '', offset: -1),
  );
  if (replaceSceneOccurrence.offset == -1 || collector.hasControllerEpoch) {
    return null;
  }
  return GuardrailViolation(
    filePath: filePosixPath,
    line: lineForOffset(parsed, replaceSceneOccurrence.offset),
    message:
        'controller API violation: replaceScene-like entrypoints '
        'must preserve epoch invalidation '
        '(missing controllerEpoch usage in file)',
  );
}

GuardrailViolation? _mutatingSymbolViolation({
  required ControllerSymbolCollector collector,
  required ParsedUnitResult parsed,
  required String filePosixPath,
}) {
  for (final occurrence in collector.occurrences) {
    if (_isAllowedControllerOccurrence(occurrence.name)) {
      continue;
    }
    if (collector.allowsWhitelistedMutatingOccurrence(occurrence)) {
      continue;
    }
    if (_looksMutatingSymbol(occurrence.name)) {
      return GuardrailViolation(
        filePath: filePosixPath,
        line: lineForOffset(parsed, occurrence.offset),
        message:
            'controller API violation: mutating symbol "${occurrence.name}" '
            'must be routed through write*/txn* transaction API',
      );
    }
  }
  return null;
}

Future<GuardrailViolation?> _checkCommittedReadSideHermeticity(
  GuardrailContext context,
) async {
  final surfacePresence = _committedReadSideSurfacePresence(context);
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

_CommittedReadSideSurfacePresence _committedReadSideSurfacePresence(
  GuardrailContext context,
) {
  final controllerFile = _sceneStoreControllerFile(context);
  final spatialFile = _sceneSpatialIndexFile(context);
  return _CommittedReadSideSurfacePresence(
    hasControllerFile: controllerFile.existsSync(),
    hasSpatialFile: spatialFile.existsSync(),
    controllerDeclaresCommittedReadSurface:
        controllerFile.existsSync() &&
        _controllerFileDeclaresCommittedReadSurface(controllerFile),
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
  final spatialCandidate = _firstClassNamed(
    resolved.element.classes,
    'SceneSpatialCandidate',
  );
  if (spatialCandidate == null) {
    return GuardrailViolation(
      filePath: '/lib/src/core/scene_spatial_index.dart',
      line: 1,
      message:
          'controller API violation: committed spatial payload owner '
          '"SceneSpatialCandidate" is required in scene_spatial_index.dart',
    );
  }

  for (final field in spatialCandidate.fields.where(
    (field) => !field.isSynthetic && isPublicName(field.displayName),
  )) {
    final leak = findForbiddenResolvedTypeLeak(
      type: field.type,
      sourceElement: field,
      context: context,
      forbiddenTypes: committedReadForbiddenTypeSpecs,
    );
    if (leak == null) {
      if (!_allowedSceneSpatialCandidateFieldNames.contains(
        field.displayName,
      )) {
        return _committedReadSideViolation(
          context: context,
          sourceElement: field,
          detail:
              'committed spatial payload "${spatialCandidate.displayName}.'
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
          'committed spatial payload "${spatialCandidate.displayName}.'
          '${field.displayName}" must not expose live runtime scene-graph '
          'types (${leak.forbiddenTypeName}).',
    );
  }

  final publicFieldNames = spatialCandidate.fields
      .where((field) => !field.isSynthetic && isPublicName(field.displayName))
      .map((field) => field.displayName)
      .toSet();
  for (final requiredFieldName in _allowedSceneSpatialCandidateFieldNames) {
    if (publicFieldNames.contains(requiredFieldName)) {
      continue;
    }
    return _committedReadSideViolation(
      context: context,
      sourceElement: spatialCandidate,
      detail:
          'committed spatial payload "${spatialCandidate.displayName}" must '
          'keep required locator field "$requiredFieldName" on the sealed '
          'surface.',
    );
  }

  for (final constructor in spatialCandidate.constructors) {
    final violation = _spatialCandidateConstructorViolation(
      constructor,
      context: context,
    );
    if (violation != null) {
      return violation;
    }
  }

  for (final getter in spatialCandidate.getters.where(
    (getter) => !getter.isSynthetic && isPublicName(getter.displayName),
  )) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: getter,
      detail:
          'committed spatial payload "${spatialCandidate.displayName}."'
          '${getter.displayName}" must not add custom public accessors '
          'outside the sealed locator-only field surface.',
    );
  }

  for (final setter in spatialCandidate.setters.where(
    (setter) => !setter.isSynthetic && isPublicName(setter.displayName),
  )) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: setter,
      detail:
          'committed spatial payload "${spatialCandidate.displayName}."'
          '${setter.displayName}" must not add custom public accessors '
          'outside the sealed locator-only field surface.',
    );
  }

  for (final method in spatialCandidate.methods.where(
    (method) => isPublicName(method.displayName),
  )) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: method,
      detail:
          'committed spatial payload "${spatialCandidate.displayName}."'
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
  if (extensionDeclaration.onClause?.extendedType.toSource() !=
      'SceneStoreController') {
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
    'querySpatialCandidates' => (
      returnType: 'List<SceneSpatialCandidate>',
      parameterType: 'Rect',
      parameterName: 'worldBounds',
    ),
    'resolveSpatialCandidateSnapshot' => (
      returnType: 'NodeSnapshot?',
      parameterType: 'SceneSpatialCandidate',
      parameterName: 'candidate',
    ),
    'resolveSnapshotNodeById' => (
      returnType: '({NodeSnapshot node, int layerIndex, int nodeIndex})?',
      parameterType: 'NodeId',
      parameterName: 'nodeId',
    ),
    'centerWorldForNodeSnapshots' => (
      returnType: 'Offset',
      parameterType: 'Iterable<NodeSnapshot>',
      parameterName: 'snapshots',
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
  if (astMember.returnType?.toSource() != expected.returnType) {
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
  if (parameters.length != 1) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: sourceElement,
      detail:
          'committed read helper "$memberName" must keep the exact sealed '
          'signature.',
    );
  }
  final parameter = parameters.single;
  if (parameter is! SimpleFormalParameter ||
      parameter.name?.lexeme != expected.parameterName ||
      parameter.type?.toSource() != expected.parameterType) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: sourceElement,
      detail:
          'committed read helper "$memberName" must keep the exact sealed '
          'signature.',
    );
  }
  return null;
}

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

bool _controllerFileDeclaresCommittedReadSurface(File controllerFile) {
  final source = controllerFile.readAsStringSync();
  if (source.contains('SceneStoreControllerSpatialAccess')) {
    return true;
  }

  for (final token in <String>{
    ..._committedReadSideHelperNames,
    ..._allowedSceneStoreControllerSpatialAccessPublicMemberNames,
    ..._bannedCommittedReadSideHelperNames,
  }) {
    if (source.contains(token)) {
      return true;
    }
  }
  return false;
}

File _sceneStoreControllerFile(GuardrailContext context) {
  return File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}controller${Platform.pathSeparator}'
    'scene_store_controller.dart',
  );
}

File _sceneSpatialIndexFile(GuardrailContext context) {
  return File(
    '${context.root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
    'src${Platform.pathSeparator}core${Platform.pathSeparator}'
    'scene_spatial_index.dart',
  );
}

GuardrailViolation? _spatialCandidateConstructorViolation(
  ConstructorElement constructor, {
  required GuardrailContext context,
}) {
  if (!_isPublicConstructor(constructor)) {
    return null;
  }

  final constructorName = _normalizedConstructorName(constructor);
  if (constructorName.isNotEmpty) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: constructor,
      detail:
          'committed spatial payload "SceneSpatialCandidate.$constructorName" '
          'must not add public named constructors outside the sealed '
          'locator-only field surface.',
    );
  }

  final leak = findForbiddenExecutableSignatureLeak(
    element: constructor,
    context: context,
    forbiddenTypes: committedReadForbiddenTypeSpecs,
  );
  if (leak != null) {
    return _committedReadSideViolation(
      context: context,
      sourceElement: leak.sourceElement,
      detail:
          'committed spatial payload constructor for "SceneSpatialCandidate" '
          'must not expose live runtime scene-graph types '
          '(${leak.forbiddenTypeName}).',
    );
  }

  for (final parameter in constructor.formalParameters) {
    if (_allowedSceneSpatialCandidateFieldNames.contains(
      parameter.displayName,
    )) {
      continue;
    }
    return _committedReadSideViolation(
      context: context,
      sourceElement: parameter,
      detail:
          'committed spatial payload constructor for "SceneSpatialCandidate" '
          'must not extend the sealed locator-only field surface with '
          'parameter "${parameter.displayName}".',
    );
  }

  return null;
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

ClassElement? _firstClassNamed(Iterable<ClassElement> classes, String name) {
  for (final element in classes) {
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
  final filePath = repoRelForElement(element: sourceElement, context: context);
  final line = lineForElement(sourceElement);
  if (filePath == null || line == null) {
    return null;
  }
  return GuardrailViolation(
    filePath: filePath,
    line: line,
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

class ControllerFileResult {
  const ControllerFileResult({
    required this.hasControllerEpoch,
    required this.violation,
  });

  final bool hasControllerEpoch;
  final GuardrailViolation? violation;
}

class ControllerSymbolOccurrence {
  const ControllerSymbolOccurrence({required this.name, required this.offset});

  final String name;
  final int offset;
}

class ControllerSymbolCollector extends RecursiveAstVisitor<void> {
  final List<ControllerSymbolOccurrence> occurrences =
      <ControllerSymbolOccurrence>[];
  final List<ControllerAllowedMutatingRange> _allowedMutatingRanges =
      <ControllerAllowedMutatingRange>[];
  bool hasControllerEpoch = false;
  ControllerSymbolOccurrence? sceneViewRenderStateImport;
  ControllerSymbolOccurrence? sceneStoreControllerViewRenderStateOccurrence;

  bool allowsWhitelistedMutatingOccurrence(
    ControllerSymbolOccurrence occurrence,
  ) {
    return _allowedMutatingRanges.any(
      (range) =>
          occurrence.offset >= range.start && occurrence.offset < range.end,
    );
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
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.name.lexeme == 'SceneStoreController' &&
        node.implementsClause?.interfaces.any(
              (type) => type.toSource() == 'SceneViewRenderState',
            ) ==
            true) {
      sceneStoreControllerViewRenderStateOccurrence =
          ControllerSymbolOccurrence(
            name: node.name.lexeme,
            offset: node.name.offset,
          );
    }
    if (_isCommittedMutationBridgeDeclaration(node)) {
      _allowedMutatingRanges.add(
        ControllerAllowedMutatingRange(start: node.offset, end: node.end),
      );
    }
    super.visitClassDeclaration(node);
  }

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
      ControllerSymbolOccurrence(
        name: node.name.lexeme,
        offset: node.name.offset,
      ),
    );
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    occurrences.add(
      ControllerSymbolOccurrence(
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
        ControllerSymbolOccurrence(
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
        ControllerSymbolOccurrence(
          name: function.name,
          offset: function.offset,
        ),
      );
    }
    super.visitFunctionExpressionInvocation(node);
  }
}

class ControllerAllowedMutatingRange {
  const ControllerAllowedMutatingRange({
    required this.start,
    required this.end,
  });

  final int start;
  final int end;
}

bool _isCommittedMutationBridgeDeclaration(ClassDeclaration node) {
  return _isCommittedMutationAccessInterface(node) ||
      _isCommittedMutationAccessAdapter(node);
}

bool _isCommittedMutationAccessInterface(ClassDeclaration node) {
  return node.name.lexeme == 'SceneControllerCommittedMutationAccess' &&
      node.abstractKeyword != null &&
      node.interfaceKeyword != null;
}

bool _isCommittedMutationAccessAdapter(ClassDeclaration node) {
  if (node.name.lexeme != 'SceneStoreControllerCommittedMutationAccess' ||
      node.finalKeyword == null) {
    return false;
  }
  final interfaces = node.implementsClause?.interfaces;
  if (interfaces == null || interfaces.length != 1) {
    return false;
  }
  return interfaces.single.toSource() ==
      'SceneControllerCommittedMutationAccess';
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
