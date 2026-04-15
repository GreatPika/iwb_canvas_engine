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
  const exemptFiles = <String>{
    '/lib/src/controller/scene_controller_committed_mutation_access.dart',
    '/lib/src/controller/scene_writer_runtime.dart',
  };
  if (exemptFiles.contains(filePosixPath)) {
    return null;
  }
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

Future<GuardrailViolation?> _checkPreparedReplaceSceneBoundaryHermeticity(
  GuardrailContext context,
) async {
  for (final filePath in _preparedReplaceSceneBoundaryFilePaths) {
    final file = _controllerBoundaryFile(context, filePath);
    if (!file.existsSync()) {
      continue;
    }

    final resolved = await context.getResolvedLibraryResult(file.path);
    if (resolved == null) {
      continue;
    }
    final parsed = parseUnitOrFail(
      context: context,
      absPath: file.path,
      filePathForDiag: filePath,
      onFailure: _onParseFailure,
    );
    final forbiddenIdentifierViolation =
        _forbiddenPreparedReplaceSceneBoundaryIdentifierViolation(
          parsed: parsed,
          filePath: filePath,
        );
    if (forbiddenIdentifierViolation != null) {
      return forbiddenIdentifierViolation;
    }

    final violation = switch (filePath) {
      '/lib/src/controller/scene_controller_committed_mutation_access.dart' =>
        _checkCommittedMutationAccessPreparedReplaceBoundary(
          context: context,
          parsed: parsed,
          resolved: resolved,
          filePath: filePath,
        ),
      '/lib/src/controller/scene_store_controller.dart' =>
        _checkSceneStorePreparedReplaceBoundary(
          context: context,
          parsed: parsed,
          resolved: resolved,
          filePath: filePath,
        ),
      '/lib/src/controller/scene_writer.dart' =>
        _checkSceneWriterPreparedReplaceBoundary(
          context: context,
          parsed: parsed,
          resolved: resolved,
          filePath: filePath,
        ),
      _ => null,
    };
    if (violation != null) {
      return violation;
    }
  }
  return null;
}

const Set<String> _preparedReplaceSceneBoundaryFilePaths = <String>{
  '/lib/src/controller/scene_controller_committed_mutation_access.dart',
  '/lib/src/controller/scene_store_controller.dart',
  '/lib/src/controller/scene_writer.dart',
};

const Set<String> _allowedCommittedMutationAccessTopLevelNames = <String>{
  'SceneControllerCommittedMutationWriteResult',
  'SceneControllerCommittedMutationAccess',
  'SceneStoreControllerCommittedMutationAccess',
};

const Set<String> _allowedCommittedMutationAccessPublicMemberNames = <String>{
  'method:write',
  'method:writeExact',
  'method:addNode',
  'method:ensureLayer',
  'method:patchNode',
  'method:removeNode',
  'method:setBackgroundColor',
  'method:setGridEnabled',
  'method:setGridCellSize',
  'method:setCameraOffset',
  'method:clearSceneExactResult',
  'method:replaceScene',
  'method:requestRepaint',
  'method:replaceSelection',
  'method:toggleSelection',
  'method:clearSelection',
  'method:selectAll',
  'method:transformSelection',
  'method:deleteSelection',
  'method:commitDrawStroke',
  'method:commitDrawLineFromWorldSegment',
  'method:commitEraseNodes',
  'getter:snapshot',
  'getter:selectedNodeIds',
  'method:centerWorldForNodeSnapshots',
};

const Set<String> _allowedSceneStoreControllerTopLevelNames = <String>{
  'SceneStoreController',
  'SceneStoreControllerSpatialAccess',
  'SceneStoreControllerCommittedSceneReplacementAccess',
};

const Set<String> _allowedSceneStoreControllerPublicMemberNames = <String>{
  'field:textFontFamilyByDefault',
  'field:commands',
  'field:move',
  'field:draw',
  'getter:snapshot',
  'getter:selectedNodeIds',
  'getter:controllerEpoch',
  'getter:structuralRevision',
  'getter:boundsRevision',
  'getter:visualRevision',
  'getter:signals',
  'getter:debug',
  'method:write',
  'method:writeCommitted',
  'method:writeWithSceneWriter',
  'method:writeWithSceneWriterCommitted',
  'method:writeReplaceScene',
  'method:requestRepaint',
  'method:dispose',
};

const Set<String> _allowedSceneWriterTopLevelNames = <String>{'SceneWriter'};

const Set<String> _allowedSceneWriterPublicMemberNames = <String>{
  'getter:snapshot',
  'getter:selectedNodeIds',
  'method:writeNodeInsert',
  'method:writeLayerEnsure',
  'method:writeNodeErase',
  'method:writeNodePatch',
  'method:writeNodeTransformSet',
  'method:writeSelectionReplace',
  'method:writeSelectionToggle',
  'method:writeSelectionClear',
  'method:writeSelectionSelectAll',
  'method:writeSelectionTranslate',
  'method:writeSelectionTransform',
  'method:writeDeleteSelection',
  'method:writeClearSceneKeepBackground',
  'method:writeClearSceneKeepBackgroundResult',
  'method:writeCameraOffset',
  'method:writeGridEnable',
  'method:writeGridCellSize',
  'method:writeBackgroundColor',
  'method:writeDocumentReplace',
  'method:writeSignalEnqueue',
  'getter:runtime',
};

GuardrailViolation? _checkCommittedMutationAccessPreparedReplaceBoundary({
  required GuardrailContext context,
  required ParsedUnitResult parsed,
  required ResolvedLibraryResult resolved,
  required String filePath,
}) {
  final topLevelViolation = _publicTopLevelSurfaceViolation(
    context: context,
    filePath: filePath,
    library: resolved.element,
    allowedNames: _allowedCommittedMutationAccessTopLevelNames,
  );
  if (topLevelViolation != null) {
    return topLevelViolation;
  }
  final unnamedExtensionViolation = _unnamedExtensionSurfaceViolation(
    parsed: parsed,
    filePath: filePath,
  );
  if (unnamedExtensionViolation != null) {
    return unnamedExtensionViolation;
  }

  final interfaceElement = _firstClassNamed(
    resolved.element.classes,
    'SceneControllerCommittedMutationAccess',
  );
  final interfaceDeclaration = _firstClassDeclarationNamed(
    parsed.unit.declarations,
    'SceneControllerCommittedMutationAccess',
  );
  if (interfaceElement == null || interfaceDeclaration == null) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'controller API violation: prepared replace-scene boundary owner '
          '"SceneControllerCommittedMutationAccess" is required in $filePath.',
    );
  }
  if (interfaceDeclaration.abstractKeyword == null ||
      interfaceDeclaration.interfaceKeyword == null) {
    return GuardrailViolation(
      filePath: filePath,
      line: lineForOffset(parsed, interfaceDeclaration.name.offset),
      message:
          'controller API violation: SceneControllerCommittedMutationAccess '
          'must remain an abstract interface class.',
    );
  }
  final interfaceConstructorViolation = _explicitPublicConstructorViolation(
    parsed: parsed,
    declaration: interfaceDeclaration,
    filePath: filePath,
    ownerName: 'SceneControllerCommittedMutationAccess',
  );
  if (interfaceConstructorViolation != null) {
    return interfaceConstructorViolation;
  }
  final interfaceMemberViolation = _publicMemberSurfaceViolation(
    context: context,
    owner: interfaceElement,
    allowedNames: _allowedCommittedMutationAccessPublicMemberNames,
    detailPrefix:
        'prepared replace-scene boundary owner '
        'SceneControllerCommittedMutationAccess public member surface',
  );
  if (interfaceMemberViolation != null) {
    return interfaceMemberViolation;
  }

  final adapterElement = _firstClassNamed(
    resolved.element.classes,
    'SceneStoreControllerCommittedMutationAccess',
  );
  final adapterDeclaration = _firstClassDeclarationNamed(
    parsed.unit.declarations,
    'SceneStoreControllerCommittedMutationAccess',
  );
  if (adapterElement == null || adapterDeclaration == null) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'controller API violation: prepared replace-scene boundary owner '
          '"SceneStoreControllerCommittedMutationAccess" is required in '
          '$filePath.',
    );
  }
  if (adapterDeclaration.finalKeyword == null ||
      adapterDeclaration.implementsClause?.interfaces.length != 1 ||
      adapterDeclaration.implementsClause?.interfaces.single.toSource() !=
          'SceneControllerCommittedMutationAccess') {
    return GuardrailViolation(
      filePath: filePath,
      line: lineForOffset(parsed, adapterDeclaration.name.offset),
      message:
          'controller API violation: SceneStoreControllerCommittedMutationAccess '
          'must remain a final adapter implementing '
          'SceneControllerCommittedMutationAccess.',
    );
  }
  final adapterConstructorViolation = _singleUnnamedPublicConstructorViolation(
    context: context,
    owner: adapterElement,
    ownerName: 'SceneStoreControllerCommittedMutationAccess',
  );
  if (adapterConstructorViolation != null) {
    return adapterConstructorViolation;
  }
  final adapterMemberViolation = _publicMemberSurfaceViolation(
    context: context,
    owner: adapterElement,
    allowedNames: _allowedCommittedMutationAccessPublicMemberNames,
    detailPrefix:
        'prepared replace-scene boundary owner '
        'SceneStoreControllerCommittedMutationAccess public member surface',
  );
  if (adapterMemberViolation != null) {
    return adapterMemberViolation;
  }

  final interfaceReplaceScene = _firstMethodDeclarationNamed(
    interfaceDeclaration.members,
    'replaceScene',
  );
  final interfaceSignatureViolation = _replaceSceneSignatureViolation(
    parsed: parsed,
    member: interfaceReplaceScene,
    filePath: filePath,
    ownerName: 'SceneControllerCommittedMutationAccess',
  );
  if (interfaceSignatureViolation != null) {
    return interfaceSignatureViolation;
  }

  final adapterReplaceScene = _firstMethodDeclarationNamed(
    adapterDeclaration.members,
    'replaceScene',
  );
  return _replaceSceneSignatureViolation(
    parsed: parsed,
    member: adapterReplaceScene,
    filePath: filePath,
    ownerName: 'SceneStoreControllerCommittedMutationAccess',
  );
}

GuardrailViolation? _checkSceneStorePreparedReplaceBoundary({
  required GuardrailContext context,
  required ParsedUnitResult parsed,
  required ResolvedLibraryResult resolved,
  required String filePath,
}) {
  final topLevelViolation = _publicTopLevelSurfaceViolation(
    context: context,
    filePath: filePath,
    library: resolved.element,
    allowedNames: _allowedSceneStoreControllerTopLevelNames,
    requiredNames: const <String>{
      'SceneStoreController',
      'SceneStoreControllerSpatialAccess',
    },
  );
  if (topLevelViolation != null) {
    return topLevelViolation;
  }
  final unnamedExtensionViolation = _unnamedExtensionSurfaceViolation(
    parsed: parsed,
    filePath: filePath,
  );
  if (unnamedExtensionViolation != null) {
    return unnamedExtensionViolation;
  }

  final storeElement = _firstClassNamed(
    resolved.element.classes,
    'SceneStoreController',
  );
  if (storeElement == null) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'controller API violation: prepared replace-scene boundary owner '
          '"SceneStoreController" is required in $filePath.',
    );
  }
  final storeMemberViolation = _publicMemberSurfaceViolation(
    context: context,
    owner: storeElement,
    allowedNames: _allowedSceneStoreControllerPublicMemberNames,
    requiredNames: const <String>{
      'field:textFontFamilyByDefault',
      'field:commands',
      'field:move',
      'field:draw',
      'getter:snapshot',
      'getter:selectedNodeIds',
      'getter:controllerEpoch',
      'getter:structuralRevision',
      'getter:boundsRevision',
      'getter:visualRevision',
      'getter:signals',
      'getter:debug',
      'method:write',
      'method:writeCommitted',
      'method:writeWithSceneWriter',
      'method:writeWithSceneWriterCommitted',
      'method:requestRepaint',
      'method:dispose',
    },
    detailPrefix:
        'prepared replace-scene boundary owner '
        'SceneStoreController public member surface',
  );
  if (storeMemberViolation != null) {
    return storeMemberViolation;
  }
  final storeConstructorViolation = _singleUnnamedPublicConstructorViolation(
    context: context,
    owner: storeElement,
    ownerName: 'SceneStoreController',
  );
  if (storeConstructorViolation != null) {
    return storeConstructorViolation;
  }

  final storeDeclaration = _firstClassDeclarationNamed(
    parsed.unit.declarations,
    'SceneStoreController',
  );
  final classWriteReplaceScene = _firstMethodDeclarationNamed(
    storeDeclaration?.members ?? const <ClassMember>[],
    'writeReplaceScene',
  );
  if (classWriteReplaceScene != null) {
    final classSignatureViolation = _writeReplaceSceneSignatureViolation(
      parsed: parsed,
      member: classWriteReplaceScene,
      filePath: filePath,
      ownerName: 'SceneStoreController',
    );
    if (classSignatureViolation != null) {
      return classSignatureViolation;
    }
  }

  final committedExtensionElement = _firstExtensionNamed(
    resolved.element.extensions,
    'SceneStoreControllerCommittedSceneReplacementAccess',
  );
  final committedExtensionDeclaration = _firstExtensionDeclarationNamed(
    parsed.unit.declarations,
    'SceneStoreControllerCommittedSceneReplacementAccess',
  );
  if (classWriteReplaceScene != null && committedExtensionDeclaration != null) {
    return GuardrailViolation(
      filePath: filePath,
      line: lineForOffset(parsed, classWriteReplaceScene.offset),
      message:
          'controller API violation: prepared replace-scene boundary must keep '
          'exactly one non-controller-private SceneStoreController.'
          'writeReplaceScene owner, not both class and dedicated extension.',
    );
  }
  if (committedExtensionElement == null ||
      committedExtensionDeclaration == null) {
    if (classWriteReplaceScene != null) {
      return null;
    }
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'controller API violation: prepared replace-scene boundary must keep '
          'single-phase SceneStoreController.writeReplaceScene(SceneSnapshot) '
          'either on SceneStoreController or on '
          'SceneStoreControllerCommittedSceneReplacementAccess.',
    );
  }
  if (committedExtensionDeclaration.onClause?.extendedType.toSource() !=
      'SceneStoreController') {
    return GuardrailViolation(
      filePath: filePath,
      line: lineForOffset(
        parsed,
        committedExtensionDeclaration.name?.offset ?? 0,
      ),
      message:
          'controller API violation: prepared replace-scene boundary owner '
          'SceneStoreControllerCommittedSceneReplacementAccess must extend '
          'SceneStoreController.',
    );
  }
  final extensionMemberViolation = _publicMemberSurfaceViolation(
    context: context,
    owner: committedExtensionElement,
    allowedNames: const <String>{'method:writeReplaceScene'},
    detailPrefix:
        'prepared replace-scene boundary owner '
        'SceneStoreControllerCommittedSceneReplacementAccess public member '
        'surface',
  );
  if (extensionMemberViolation != null) {
    return extensionMemberViolation;
  }

  final writeReplaceScene = _firstMethodDeclarationNamed(
    committedExtensionDeclaration.members,
    'writeReplaceScene',
  );
  return _writeReplaceSceneSignatureViolation(
    parsed: parsed,
    member: writeReplaceScene,
    filePath: filePath,
    ownerName: 'SceneStoreControllerCommittedSceneReplacementAccess',
  );
}

GuardrailViolation? _checkSceneWriterPreparedReplaceBoundary({
  required GuardrailContext context,
  required ParsedUnitResult parsed,
  required ResolvedLibraryResult resolved,
  required String filePath,
}) {
  final topLevelViolation = _publicTopLevelSurfaceViolation(
    context: context,
    filePath: filePath,
    library: resolved.element,
    allowedNames: _allowedSceneWriterTopLevelNames,
  );
  if (topLevelViolation != null) {
    return topLevelViolation;
  }
  final unnamedExtensionViolation = _unnamedExtensionSurfaceViolation(
    parsed: parsed,
    filePath: filePath,
  );
  if (unnamedExtensionViolation != null) {
    return unnamedExtensionViolation;
  }

  final writerElement = _firstClassNamed(
    resolved.element.classes,
    'SceneWriter',
  );
  final writerDeclaration = _firstClassDeclarationNamed(
    parsed.unit.declarations,
    'SceneWriter',
  );
  if (writerElement == null || writerDeclaration == null) {
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'controller API violation: prepared replace-scene boundary owner '
          '"SceneWriter" is required in $filePath.',
    );
  }
  final constructorViolation = _singleUnnamedPublicConstructorViolation(
    context: context,
    owner: writerElement,
    ownerName: 'SceneWriter',
  );
  if (constructorViolation != null) {
    return constructorViolation;
  }
  final memberViolation = _publicMemberSurfaceViolation(
    context: context,
    owner: writerElement,
    allowedNames: _allowedSceneWriterPublicMemberNames,
    detailPrefix:
        'prepared replace-scene boundary owner '
        'SceneWriter public member surface',
  );
  if (memberViolation != null) {
    return memberViolation;
  }

  final writeDocumentReplace = _firstMethodDeclarationNamed(
    writerDeclaration.members,
    'writeDocumentReplace',
  );
  return _writeDocumentReplaceSignatureViolation(
    parsed: parsed,
    member: writeDocumentReplace,
    filePath: filePath,
  );
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

File _controllerBoundaryFile(GuardrailContext context, String repoRelPath) {
  return File(posixJoin(context.root.path, repoRelPath.substring(1)));
}

const List<String> _forbiddenPreparedReplaceSceneBoundaryNameFragments =
    <String>[
      'preparedscenereplacement',
      'preparedscenepayload',
      'scenereplacementpayload',
      'preparescenereplacement',
      'stagescenereplacement',
      'applyscenereplacement',
      'preparescenepayload',
      'adoptscenepayload',
      'writeprepareddocumentreplace',
      'writepreparedscenereplacement',
    ];

GuardrailViolation? _forbiddenPreparedReplaceSceneBoundaryIdentifierViolation({
  required ParsedUnitResult parsed,
  required String filePath,
}) {
  for (final occurrence in _preparedReplaceSceneBoundaryIdentifierOccurrences(
    parsed,
  )) {
    if (!_isForbiddenPreparedReplaceSceneBoundaryIdentifier(occurrence.name)) {
      continue;
    }
    return GuardrailViolation(
      filePath: filePath,
      line: lineForOffset(parsed, occurrence.offset),
      message:
          'controller API violation: prepared replace-scene boundary surface '
          'in $filePath must not reference or declare helper or payload symbol '
          '"${occurrence.name}" even privately.',
    );
  }
  return null;
}

bool _isForbiddenPreparedReplaceSceneBoundaryIdentifier(String rawName) {
  final normalizedName = _normalizePreparedReplaceSceneBoundaryIdentifier(
    rawName,
  );
  if (normalizedName.isEmpty) {
    return false;
  }
  return _forbiddenPreparedReplaceSceneBoundaryNameFragments.any(
    normalizedName.contains,
  );
}

String _normalizePreparedReplaceSceneBoundaryIdentifier(String rawName) {
  return rawName
      .replaceFirst(RegExp(r'^_+'), '')
      .replaceAll('_', '')
      .toLowerCase();
}

Iterable<_PreparedReplaceSceneBoundaryIdentifierOccurrence>
_preparedReplaceSceneBoundaryIdentifierOccurrences(
  ParsedUnitResult parsed,
) sync* {
  for (var token = parsed.unit.beginToken; !token.isEof;) {
    final lexeme = token.lexeme;
    if (!_looksLikePreparedReplaceSceneBoundaryIdentifier(lexeme)) {
      final next = token.next;
      if (next == null) {
        break;
      }
      token = next;
      continue;
    }
    yield _PreparedReplaceSceneBoundaryIdentifierOccurrence(
      name: lexeme,
      offset: token.offset,
    );
    final next = token.next;
    if (next == null) {
      break;
    }
    token = next;
  }
}

bool _looksLikePreparedReplaceSceneBoundaryIdentifier(String lexeme) {
  return RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(lexeme);
}

GuardrailViolation? _publicTopLevelSurfaceViolation({
  required GuardrailContext context,
  required String filePath,
  required LibraryElement library,
  required Set<String> allowedNames,
  Set<String>? requiredNames,
}) {
  final publicElements = _publicTopLevelElements(library)
    ..sort(_compareElementsBySourceOrder);
  for (final element in publicElements) {
    if (allowedNames.contains(element.displayName)) {
      continue;
    }
    return _controllerPreparedReplaceViolation(
      context: context,
      sourceElement: element,
      detail:
          'prepared replace-scene boundary surface in $filePath must not add '
          'public top-level declaration "${element.displayName}".',
    );
  }

  final effectiveRequiredNames = requiredNames ?? allowedNames;
  for (final requiredName in effectiveRequiredNames) {
    final present = publicElements.any(
      (element) => element.displayName == requiredName,
    );
    if (present) {
      continue;
    }
    return GuardrailViolation(
      filePath: filePath,
      line: 1,
      message:
          'controller API violation: prepared replace-scene boundary surface '
          'in $filePath must keep public top-level declaration '
          '"$requiredName".',
    );
  }
  return null;
}

List<Element> _publicTopLevelElements(LibraryElement library) {
  return <Element>[
    ...library.classes.where(_isPublicNamedElement),
    ...library.enums.where(_isPublicNamedElement),
    ...library.mixins.where(_isPublicNamedElement),
    ...library.extensions.where(_isPublicNamedElement),
    ...library.extensionTypes.where(_isPublicNamedElement),
    ...library.typeAliases.where(_isPublicNamedElement),
    ...library.topLevelFunctions.where(_isPublicNamedElement),
    ...library.topLevelVariables.where(_isPublicNamedElement),
    ...library.getters.where(
      (element) => !element.isSynthetic && _isPublicNamedElement(element),
    ),
    ...library.setters.where(
      (element) => !element.isSynthetic && _isPublicNamedElement(element),
    ),
  ];
}

int _compareElementsBySourceOrder(Element left, Element right) {
  final leftPath = left.firstFragment.libraryFragment?.source.fullName ?? '';
  final rightPath = right.firstFragment.libraryFragment?.source.fullName ?? '';
  final pathCompare = leftPath.compareTo(rightPath);
  if (pathCompare != 0) {
    return pathCompare;
  }
  return left.firstFragment.offset.compareTo(right.firstFragment.offset);
}

bool _isPublicNamedElement(Element element) {
  final name = element.displayName;
  return name.isNotEmpty && isPublicName(name);
}

String _publicMemberSurfaceKey(Element member) {
  final name = member.displayName;
  if (member is FieldElement) {
    return 'field:$name';
  }
  if (member is PropertyAccessorElement) {
    return member is SetterElement ? 'setter:$name' : 'getter:$name';
  }
  if (member is MethodElement) {
    return 'method:$name';
  }
  return 'member:$name';
}

String _publicMemberSurfaceDescription(Element member) {
  if (member is FieldElement) {
    return 'public field "${member.displayName}"';
  }
  if (member is PropertyAccessorElement) {
    return member is SetterElement
        ? 'public setter "${member.displayName}"'
        : 'public getter "${member.displayName}"';
  }
  if (member is MethodElement) {
    return 'public method "${member.displayName}"';
  }
  return 'public member "${member.displayName}"';
}

String _publicMemberSurfaceDescriptionForKey(String key) {
  final parts = key.split(':');
  if (parts.length != 2) {
    return 'public member "$key"';
  }
  final kind = parts.first;
  final name = parts.last;
  return switch (kind) {
    'field' => 'public field "$name"',
    'getter' => 'public getter "$name"',
    'setter' => 'public setter "$name"',
    'method' => 'public method "$name"',
    _ => 'public member "$name"',
  };
}

GuardrailViolation? _publicMemberSurfaceViolation({
  required GuardrailContext context,
  required InstanceElement owner,
  required Set<String> allowedNames,
  required String detailPrefix,
  Set<String>? requiredNames,
}) {
  final publicMembers = _publicInstanceMembers(owner)
    ..sort(_compareElementsBySourceOrder);
  for (final member in publicMembers) {
    final memberKey = _publicMemberSurfaceKey(member);
    if (allowedNames.contains(memberKey)) {
      continue;
    }
    return _controllerPreparedReplaceViolation(
      context: context,
      sourceElement: member,
      detail:
          '$detailPrefix must not add ${_publicMemberSurfaceDescription(member)}.',
    );
  }

  final publicMemberNames = publicMembers.map(_publicMemberSurfaceKey).toSet();
  final effectiveRequiredNames = requiredNames ?? allowedNames;
  for (final requiredName in effectiveRequiredNames) {
    if (publicMemberNames.contains(requiredName)) {
      continue;
    }
    return _controllerPreparedReplaceViolation(
      context: context,
      sourceElement: owner,
      detail:
          '$detailPrefix must keep ${_publicMemberSurfaceDescriptionForKey(requiredName)}.',
    );
  }
  return null;
}

List<Element> _publicInstanceMembers(InstanceElement owner) {
  return <Element>[
    ...owner.fields.where(
      (field) => !field.isSynthetic && _isPublicNamedElement(field),
    ),
    ...owner.getters.where(
      (getter) => !getter.isSynthetic && _isPublicNamedElement(getter),
    ),
    ...owner.setters.where(
      (setter) => !setter.isSynthetic && _isPublicNamedElement(setter),
    ),
    ...owner.methods.where(_isPublicNamedElement),
  ];
}

GuardrailViolation? _unnamedExtensionSurfaceViolation({
  required ParsedUnitResult parsed,
  required String filePath,
}) {
  for (final declaration in parsed.unit.declarations) {
    if (declaration is ExtensionDeclaration && declaration.name == null) {
      return GuardrailViolation(
        filePath: filePath,
        line: lineForOffset(parsed, declaration.offset),
        message:
            'controller API violation: prepared replace-scene boundary surface '
            'in $filePath must not add unnamed extensions.',
      );
    }
  }
  return null;
}

GuardrailViolation? _explicitPublicConstructorViolation({
  required ParsedUnitResult parsed,
  required ClassDeclaration declaration,
  required String filePath,
  required String ownerName,
}) {
  for (final member in declaration.members) {
    if (member is! ConstructorDeclaration) {
      continue;
    }
    final constructorName = member.name?.lexeme ?? '';
    if (constructorName.isNotEmpty && !isPublicName(constructorName)) {
      continue;
    }
    return GuardrailViolation(
      filePath: filePath,
      line: lineForOffset(parsed, member.offset),
      message:
          'controller API violation: $ownerName must not add explicit public '
          'constructors on the prepared replace-scene boundary surface.',
    );
  }
  return null;
}

GuardrailViolation? _singleUnnamedPublicConstructorViolation({
  required GuardrailContext context,
  required InterfaceElement owner,
  required String ownerName,
}) {
  final publicConstructors =
      owner.constructors.where(_isPublicConstructor).toList(growable: false)
        ..sort(_compareElementsBySourceOrder);
  if (publicConstructors.length != 1 ||
      _normalizedConstructorName(publicConstructors.single).isNotEmpty) {
    return _controllerPreparedReplaceViolation(
      context: context,
      sourceElement: publicConstructors.isEmpty
          ? owner
          : publicConstructors.first,
      detail:
          '$ownerName must keep exactly one unnamed public constructor on the '
          'prepared replace-scene boundary surface.',
    );
  }
  return null;
}

GuardrailViolation? _replaceSceneSignatureViolation({
  required ParsedUnitResult parsed,
  required MethodDeclaration? member,
  required String filePath,
  required String ownerName,
}) {
  if (member == null ||
      member.returnType?.toSource() != 'void' ||
      member.typeParameters != null) {
    return _preparedReplaceSceneSignatureError(
      filePath: filePath,
      line: member == null ? 1 : lineForOffset(parsed, member.offset),
      detail:
          '$ownerName.replaceScene must keep the sealed single-phase '
          'signature for the prepared replace-scene boundary.',
    );
  }
  final parameters = member.parameters?.parameters ?? const <FormalParameter>[];
  if (parameters.length != 2) {
    return _preparedReplaceSceneSignatureError(
      filePath: filePath,
      line: lineForOffset(parsed, member.offset),
      detail:
          '$ownerName.replaceScene must keep the sealed single-phase '
          'signature for the prepared replace-scene boundary.',
    );
  }
  final snapshotParam = parameters.first;
  final beforeApplyParam = parameters.last;
  if (snapshotParam is! SimpleFormalParameter ||
      snapshotParam.name?.lexeme != 'snapshot' ||
      snapshotParam.type?.toSource() != 'SceneSnapshot' ||
      beforeApplyParam is! DefaultFormalParameter ||
      beforeApplyParam.isRequiredNamed != true ||
      beforeApplyParam.parameter is! SimpleFormalParameter ||
      (beforeApplyParam.parameter as SimpleFormalParameter).name?.lexeme !=
          'beforeApply' ||
      (beforeApplyParam.parameter as SimpleFormalParameter).type?.toSource() !=
          'VoidCallback') {
    return _preparedReplaceSceneSignatureError(
      filePath: filePath,
      line: lineForOffset(parsed, member.offset),
      detail:
          '$ownerName.replaceScene must keep the sealed single-phase '
          'signature for the prepared replace-scene boundary.',
    );
  }
  return null;
}

GuardrailViolation? _writeReplaceSceneSignatureViolation({
  required ParsedUnitResult parsed,
  required MethodDeclaration? member,
  required String filePath,
  required String ownerName,
}) {
  if (member == null ||
      member.returnType?.toSource() != 'void' ||
      member.typeParameters != null) {
    return _preparedReplaceSceneSignatureError(
      filePath: filePath,
      line: member == null ? 1 : lineForOffset(parsed, member.offset),
      detail:
          '$ownerName.writeReplaceScene must keep the sealed single-phase '
          'signature for the prepared replace-scene boundary.',
    );
  }
  final parameters = member.parameters?.parameters ?? const <FormalParameter>[];
  if (parameters.length != 1) {
    return _preparedReplaceSceneSignatureError(
      filePath: filePath,
      line: lineForOffset(parsed, member.offset),
      detail:
          '$ownerName.writeReplaceScene must keep the sealed single-phase '
          'signature for the prepared replace-scene boundary.',
    );
  }
  final snapshotParam = parameters.single;
  if (snapshotParam is! SimpleFormalParameter ||
      snapshotParam.name?.lexeme != 'snapshot' ||
      snapshotParam.type?.toSource() != 'SceneSnapshot') {
    return _preparedReplaceSceneSignatureError(
      filePath: filePath,
      line: lineForOffset(parsed, member.offset),
      detail:
          '$ownerName.writeReplaceScene must keep the sealed single-phase '
          'signature for the prepared replace-scene boundary.',
    );
  }
  return null;
}

GuardrailViolation? _writeDocumentReplaceSignatureViolation({
  required ParsedUnitResult parsed,
  required MethodDeclaration? member,
  required String filePath,
}) {
  if (member == null ||
      member.returnType?.toSource() != 'void' ||
      member.typeParameters != null) {
    return _preparedReplaceSceneSignatureError(
      filePath: filePath,
      line: member == null ? 1 : lineForOffset(parsed, member.offset),
      detail:
          'SceneWriter.writeDocumentReplace must keep the sealed single-phase '
          'signature for the prepared replace-scene boundary.',
    );
  }
  final parameters = member.parameters?.parameters ?? const <FormalParameter>[];
  if (parameters.length != 2) {
    return _preparedReplaceSceneSignatureError(
      filePath: filePath,
      line: lineForOffset(parsed, member.offset),
      detail:
          'SceneWriter.writeDocumentReplace must keep the sealed single-phase '
          'signature for the prepared replace-scene boundary.',
    );
  }
  final snapshotParam = parameters.first;
  final beforeApplyParam = parameters.last;
  if (snapshotParam is! SimpleFormalParameter ||
      snapshotParam.name?.lexeme != 'snapshot' ||
      snapshotParam.type?.toSource() != 'SceneSnapshot' ||
      beforeApplyParam is! DefaultFormalParameter ||
      beforeApplyParam.isRequiredNamed ||
      beforeApplyParam.parameter is! SimpleFormalParameter ||
      (beforeApplyParam.parameter as SimpleFormalParameter).name?.lexeme !=
          'beforeApply' ||
      (beforeApplyParam.parameter as SimpleFormalParameter).type?.toSource() !=
          'void Function()?') {
    return _preparedReplaceSceneSignatureError(
      filePath: filePath,
      line: lineForOffset(parsed, member.offset),
      detail:
          'SceneWriter.writeDocumentReplace must keep the sealed single-phase '
          'signature for the prepared replace-scene boundary.',
    );
  }
  return null;
}

GuardrailViolation _preparedReplaceSceneSignatureError({
  required String filePath,
  required int line,
  required String detail,
}) {
  return GuardrailViolation(
    filePath: filePath,
    line: line,
    message: 'controller API violation: $detail',
  );
}

GuardrailViolation? _controllerPreparedReplaceViolation({
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

ClassDeclaration? _firstClassDeclarationNamed(
  Iterable<CompilationUnitMember> declarations,
  String name,
) {
  for (final declaration in declarations) {
    if (declaration is ClassDeclaration && declaration.name.lexeme == name) {
      return declaration;
    }
  }
  return null;
}

MethodDeclaration? _firstMethodDeclarationNamed(
  Iterable<ClassMember> members,
  String name,
) {
  for (final member in members) {
    if (member is MethodDeclaration && member.name.lexeme == name) {
      return member;
    }
  }
  return null;
}

class ControllerFileResult {
  const ControllerFileResult({
    required this.hasControllerEpoch,
    required this.violation,
  });

  final bool hasControllerEpoch;
  final GuardrailViolation? violation;
}

class _PreparedReplaceSceneBoundaryIdentifierOccurrence {
  const _PreparedReplaceSceneBoundaryIdentifierOccurrence({
    required this.name,
    required this.offset,
  });

  final String name;
  final int offset;
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
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'controllerEpoch') {
      hasControllerEpoch = true;
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'controllerEpoch') {
      hasControllerEpoch = true;
    }
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
