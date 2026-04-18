part of 'write_only_mutation_rules.dart';

final class _PreparedReplacePreludeSpec {
  const _PreparedReplacePreludeSpec({
    required this.allowedTopLevelNames,
    this.requiredTopLevelNames,
  });

  final Set<String> allowedTopLevelNames;
  final Set<String>? requiredTopLevelNames;
}

final class _PreparedReplaceClassOwner {
  const _PreparedReplaceClassOwner({
    required this.element,
    required this.declaration,
  });

  final ClassElement element;
  final ClassDeclaration declaration;
}

final class _PreparedReplaceParameterSpec {
  const _PreparedReplaceParameterSpec.simple({
    required this.name,
    required this.typeSource,
  }) : isRequiredNamed = false;

  const _PreparedReplaceParameterSpec.requiredNamed({
    required this.name,
    required this.typeSource,
  }) : isRequiredNamed = true;

  final String name;
  final String typeSource;
  final bool isRequiredNamed;
}

final class _PreparedReplaceMethodSignatureSpec {
  const _PreparedReplaceMethodSignatureSpec({
    required this.detail,
    this.parameters = const <_PreparedReplaceParameterSpec>[],
  });

  final String detail;
  final List<_PreparedReplaceParameterSpec> parameters;
}

enum _PreparedReplaceConstructorPolicy {
  none,
  forbidExplicitPublicConstructors,
  requireSingleUnnamedPublicConstructor,
}

typedef _PreparedReplaceOwnerDeclarationValidator =
    GuardrailViolation? Function({
      required _PreparedReplaceClassOwner owner,
      required ParsedUnitResult parsed,
      required String filePath,
    });

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
  'getter:selectionRevision',
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

GuardrailViolation? _checkPreparedReplacePrelude({
  required GuardrailContext context,
  required ParsedUnitResult parsed,
  required ResolvedLibraryResult resolved,
  required String filePath,
  required _PreparedReplacePreludeSpec spec,
}) {
  final topLevelViolation = _publicTopLevelSurfaceViolation(
    context: context,
    filePath: filePath,
    library: resolved.element,
    allowedNames: spec.allowedTopLevelNames,
    requiredNames: spec.requiredTopLevelNames,
  );
  if (topLevelViolation != null) {
    return topLevelViolation;
  }

  return _unnamedExtensionSurfaceViolation(parsed: parsed, filePath: filePath);
}

GuardrailViolation? _missingPreparedReplaceOwnerViolation({
  required String filePath,
  required String ownerName,
}) {
  return GuardrailViolation(
    filePath: filePath,
    line: 1,
    message:
        'controller API violation: prepared replace-scene boundary owner '
        '"$ownerName" is required in $filePath.',
  );
}

_PreparedReplaceClassOwner? _requirePreparedReplaceClassOwner({
  required ParsedUnitResult parsed,
  required ResolvedLibraryResult resolved,
  required String ownerName,
}) {
  final element = _firstClassNamed(resolved.element.classes, ownerName);
  final declaration = _firstClassDeclarationNamed(
    parsed.unit.declarations,
    ownerName,
  );
  if (element == null || declaration == null) {
    return null;
  }

  return _PreparedReplaceClassOwner(element: element, declaration: declaration);
}

({_PreparedReplaceClassOwner? owner, GuardrailViolation? violation})
_checkPreparedReplaceClassOwnerSpec({
  required GuardrailContext context,
  required ParsedUnitResult parsed,
  required ResolvedLibraryResult resolved,
  required String filePath,
  required String ownerName,
  required Set<String> allowedNames,
  required String detailPrefix,
  Set<String>? requiredNames,
  _PreparedReplaceConstructorPolicy constructorPolicy =
      _PreparedReplaceConstructorPolicy.requireSingleUnnamedPublicConstructor,
  _PreparedReplaceOwnerDeclarationValidator? validateDeclaration,
}) {
  final owner = _requirePreparedReplaceClassOwner(
    parsed: parsed,
    resolved: resolved,
    ownerName: ownerName,
  );
  if (owner == null) {
    return (
      owner: null,
      violation: _missingPreparedReplaceOwnerViolation(
        filePath: filePath,
        ownerName: ownerName,
      ),
    );
  }

  final declarationViolation = validateDeclaration?.call(
    owner: owner,
    parsed: parsed,
    filePath: filePath,
  );
  if (declarationViolation != null) {
    return (owner: owner, violation: declarationViolation);
  }

  final constructorViolation = switch (constructorPolicy) {
    _PreparedReplaceConstructorPolicy.none => null,
    _PreparedReplaceConstructorPolicy.forbidExplicitPublicConstructors =>
      _explicitPublicConstructorViolation(
        parsed: parsed,
        declaration: owner.declaration,
        filePath: filePath,
        ownerName: ownerName,
      ),
    _PreparedReplaceConstructorPolicy.requireSingleUnnamedPublicConstructor =>
      _singleUnnamedPublicConstructorViolation(
        context: context,
        owner: owner.element,
        ownerName: ownerName,
      ),
  };
  if (constructorViolation != null) {
    return (owner: owner, violation: constructorViolation);
  }

  final memberViolation = _publicMemberSurfaceViolation(
    context: context,
    owner: owner.element,
    allowedNames: allowedNames,
    requiredNames: requiredNames,
    detailPrefix: detailPrefix,
  );
  return (owner: owner, violation: memberViolation);
}

_PreparedReplaceMethodSignatureSpec _snapshotOnlyPreparedReplaceMethodSpec(
  String detail,
) {
  return _PreparedReplaceMethodSignatureSpec(
    detail: detail,
    parameters: const <_PreparedReplaceParameterSpec>[
      _PreparedReplaceParameterSpec.simple(
        name: 'snapshot',
        typeSource: 'SceneSnapshot',
      ),
    ],
  );
}

_PreparedReplaceMethodSignatureSpec
_snapshotBeforeApplyPreparedReplaceMethodSpec(String detail) {
  return _PreparedReplaceMethodSignatureSpec(
    detail: detail,
    parameters: const <_PreparedReplaceParameterSpec>[
      _PreparedReplaceParameterSpec.simple(
        name: 'snapshot',
        typeSource: 'SceneSnapshot',
      ),
      _PreparedReplaceParameterSpec.requiredNamed(
        name: 'beforeApply',
        typeSource: 'VoidCallback',
      ),
    ],
  );
}

GuardrailViolation? _checkCommittedMutationAccessPreparedReplaceBoundary({
  required GuardrailContext context,
  required ParsedUnitResult parsed,
  required ResolvedLibraryResult resolved,
  required String filePath,
}) {
  final preludeViolation = _checkPreparedReplacePrelude(
    context: context,
    parsed: parsed,
    resolved: resolved,
    filePath: filePath,
    spec: const _PreparedReplacePreludeSpec(
      allowedTopLevelNames: _allowedCommittedMutationAccessTopLevelNames,
    ),
  );
  if (preludeViolation != null) {
    return preludeViolation;
  }

  final interfaceResult = _checkPreparedReplaceClassOwnerSpec(
    context: context,
    parsed: parsed,
    resolved: resolved,
    filePath: filePath,
    ownerName: 'SceneControllerCommittedMutationAccess',
    allowedNames: _allowedCommittedMutationAccessPublicMemberNames,
    detailPrefix:
        'prepared replace-scene boundary owner '
        'SceneControllerCommittedMutationAccess public member surface',
    constructorPolicy:
        _PreparedReplaceConstructorPolicy.forbidExplicitPublicConstructors,
    validateDeclaration: ({required owner, required parsed, required filePath}) {
      if (owner.declaration.abstractKeyword != null &&
          owner.declaration.interfaceKeyword != null) {
        return null;
      }
      return GuardrailViolation(
        filePath: filePath,
        line: lineForOffset(parsed, owner.declaration.name.offset),
        message:
            'controller API violation: SceneControllerCommittedMutationAccess '
            'must remain an abstract interface class.',
      );
    },
  );
  if (interfaceResult.violation != null) {
    return interfaceResult.violation;
  }
  final interfaceOwner = interfaceResult.owner;
  if (interfaceOwner == null) {
    return interfaceResult.violation;
  }

  final adapterResult = _checkPreparedReplaceClassOwnerSpec(
    context: context,
    parsed: parsed,
    resolved: resolved,
    filePath: filePath,
    ownerName: 'SceneStoreControllerCommittedMutationAccess',
    allowedNames: _allowedCommittedMutationAccessPublicMemberNames,
    detailPrefix:
        'prepared replace-scene boundary owner '
        'SceneStoreControllerCommittedMutationAccess public member surface',
    validateDeclaration: ({required owner, required parsed, required filePath}) {
      if (owner.declaration.finalKeyword != null &&
          owner.declaration.implementsClause?.interfaces.length == 1 &&
          owner.declaration.implementsClause?.interfaces.single.toSource() ==
              'SceneControllerCommittedMutationAccess') {
        return null;
      }
      return GuardrailViolation(
        filePath: filePath,
        line: lineForOffset(parsed, owner.declaration.name.offset),
        message:
            'controller API violation: SceneStoreControllerCommittedMutationAccess '
            'must remain a final adapter implementing '
            'SceneControllerCommittedMutationAccess.',
      );
    },
  );
  if (adapterResult.violation != null) {
    return adapterResult.violation;
  }
  final adapterOwner = adapterResult.owner;
  if (adapterOwner == null) {
    return adapterResult.violation;
  }

  final interfaceReplaceScene = _firstMethodDeclarationNamed(
    interfaceOwner.declaration.members,
    'replaceScene',
  );
  final interfaceSignatureViolation = _preparedReplaceMethodSignatureViolation(
    parsed: parsed,
    member: interfaceReplaceScene,
    filePath: filePath,
    spec: _snapshotBeforeApplyPreparedReplaceMethodSpec(
      'SceneControllerCommittedMutationAccess.replaceScene must keep the sealed single-phase '
      'signature for the prepared replace-scene boundary.',
    ),
  );
  if (interfaceSignatureViolation != null) {
    return interfaceSignatureViolation;
  }

  final adapterReplaceScene = _firstMethodDeclarationNamed(
    adapterOwner.declaration.members,
    'replaceScene',
  );
  return _preparedReplaceMethodSignatureViolation(
    parsed: parsed,
    member: adapterReplaceScene,
    filePath: filePath,
    spec: _snapshotBeforeApplyPreparedReplaceMethodSpec(
      'SceneStoreControllerCommittedMutationAccess.replaceScene must keep the sealed single-phase '
      'signature for the prepared replace-scene boundary.',
    ),
  );
}

GuardrailViolation? _checkSceneStorePreparedReplaceBoundary({
  required GuardrailContext context,
  required ParsedUnitResult parsed,
  required ResolvedLibraryResult resolved,
  required String filePath,
}) {
  final preludeViolation = _checkPreparedReplacePrelude(
    context: context,
    parsed: parsed,
    resolved: resolved,
    filePath: filePath,
    spec: const _PreparedReplacePreludeSpec(
      allowedTopLevelNames: _allowedSceneStoreControllerTopLevelNames,
      requiredTopLevelNames: <String>{
        'SceneStoreController',
        'SceneStoreControllerSpatialAccess',
      },
    ),
  );
  if (preludeViolation != null) {
    return preludeViolation;
  }

  final storeResult = _checkPreparedReplaceClassOwnerSpec(
    context: context,
    parsed: parsed,
    resolved: resolved,
    filePath: filePath,
    ownerName: 'SceneStoreController',
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
  if (storeResult.violation != null) {
    return storeResult.violation;
  }
  final storeOwner = storeResult.owner;
  if (storeOwner == null) {
    return storeResult.violation;
  }
  final classWriteReplaceScene = _firstMethodDeclarationNamed(
    storeOwner.declaration.members,
    'writeReplaceScene',
  );
  if (classWriteReplaceScene != null) {
    final classSignatureViolation = _preparedReplaceMethodSignatureViolation(
      parsed: parsed,
      member: classWriteReplaceScene,
      filePath: filePath,
      spec: _snapshotOnlyPreparedReplaceMethodSpec(
        'SceneStoreController.writeReplaceScene must keep the sealed single-phase '
        'signature for the prepared replace-scene boundary.',
      ),
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
  return _preparedReplaceMethodSignatureViolation(
    parsed: parsed,
    member: writeReplaceScene,
    filePath: filePath,
    spec: _snapshotOnlyPreparedReplaceMethodSpec(
      'SceneStoreControllerCommittedSceneReplacementAccess.writeReplaceScene must keep the sealed single-phase '
      'signature for the prepared replace-scene boundary.',
    ),
  );
}

GuardrailViolation? _checkSceneWriterPreparedReplaceBoundary({
  required GuardrailContext context,
  required ParsedUnitResult parsed,
  required ResolvedLibraryResult resolved,
  required String filePath,
}) {
  final preludeViolation = _checkPreparedReplacePrelude(
    context: context,
    parsed: parsed,
    resolved: resolved,
    filePath: filePath,
    spec: const _PreparedReplacePreludeSpec(
      allowedTopLevelNames: _allowedSceneWriterTopLevelNames,
    ),
  );
  if (preludeViolation != null) {
    return preludeViolation;
  }

  final writerResult = _checkPreparedReplaceClassOwnerSpec(
    context: context,
    parsed: parsed,
    resolved: resolved,
    filePath: filePath,
    ownerName: 'SceneWriter',
    allowedNames: _allowedSceneWriterPublicMemberNames,
    detailPrefix:
        'prepared replace-scene boundary owner '
        'SceneWriter public member surface',
  );
  if (writerResult.violation != null) {
    return writerResult.violation;
  }
  final writerOwner = writerResult.owner;
  if (writerOwner == null) {
    return writerResult.violation;
  }

  final writeDocumentReplace = _firstMethodDeclarationNamed(
    writerOwner.declaration.members,
    'writeDocumentReplace',
  );
  return _preparedReplaceMethodSignatureViolation(
    parsed: parsed,
    member: writeDocumentReplace,
    filePath: filePath,
    spec: _snapshotOnlyPreparedReplaceMethodSpec(
      'SceneWriter.writeDocumentReplace must keep the sealed single-phase '
      'signature for the prepared replace-scene boundary.',
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
    ..sort(element_utils.compareElementsBySourceOrder);
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
    ...library.classes.where(element_utils.isPublicNamedElement),
    ...library.enums.where(element_utils.isPublicNamedElement),
    ...library.mixins.where(element_utils.isPublicNamedElement),
    ...library.extensions.where(element_utils.isPublicNamedElement),
    ...library.extensionTypes.where(element_utils.isPublicNamedElement),
    ...library.typeAliases.where(element_utils.isPublicNamedElement),
    ...library.topLevelFunctions.where(element_utils.isPublicNamedElement),
    ...library.topLevelVariables.where(element_utils.isPublicNamedElement),
    ...library.getters.where(
      (element) =>
          !element.isSynthetic && element_utils.isPublicNamedElement(element),
    ),
    ...library.setters.where(
      (element) =>
          !element.isSynthetic && element_utils.isPublicNamedElement(element),
    ),
  ];
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
    ..sort(element_utils.compareElementsBySourceOrder);
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
      (field) =>
          !field.isSynthetic && element_utils.isPublicNamedElement(field),
    ),
    ...owner.getters.where(
      (getter) =>
          !getter.isSynthetic && element_utils.isPublicNamedElement(getter),
    ),
    ...owner.setters.where(
      (setter) =>
          !setter.isSynthetic && element_utils.isPublicNamedElement(setter),
    ),
    ...owner.methods.where(element_utils.isPublicNamedElement),
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
      owner.constructors
          .where(element_utils.isPublicConstructor)
          .toList(growable: false)
        ..sort(element_utils.compareElementsBySourceOrder);
  if (publicConstructors.length != 1 ||
      element_utils
          .normalizedConstructorName(publicConstructors.single)
          .isNotEmpty) {
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

GuardrailViolation? _preparedReplaceMethodSignatureViolation({
  required ParsedUnitResult parsed,
  required MethodDeclaration? member,
  required String filePath,
  required _PreparedReplaceMethodSignatureSpec spec,
}) {
  if (member == null ||
      member.returnType?.toSource() != 'void' ||
      member.typeParameters != null) {
    return _preparedReplaceSceneSignatureError(
      filePath: filePath,
      line: member == null ? 1 : lineForOffset(parsed, member.offset),
      detail: spec.detail,
    );
  }

  final parameters = member.parameters?.parameters ?? const <FormalParameter>[];
  if (parameters.length != spec.parameters.length) {
    return _preparedReplaceSceneSignatureError(
      filePath: filePath,
      line: lineForOffset(parsed, member.offset),
      detail: spec.detail,
    );
  }

  for (var index = 0; index < parameters.length; index++) {
    if (!_matchesPreparedReplaceParameter(
      parameters[index],
      spec.parameters[index],
    )) {
      return _preparedReplaceSceneSignatureError(
        filePath: filePath,
        line: lineForOffset(parsed, member.offset),
        detail: spec.detail,
      );
    }
  }

  return null;
}

bool _matchesPreparedReplaceParameter(
  FormalParameter actual,
  _PreparedReplaceParameterSpec expected,
) {
  if (!expected.isRequiredNamed) {
    return actual is SimpleFormalParameter &&
        actual.name?.lexeme == expected.name &&
        actual.type?.toSource() == expected.typeSource;
  }

  if (actual is! DefaultFormalParameter ||
      actual.isRequiredNamed != true ||
      actual.parameter is! SimpleFormalParameter) {
    return false;
  }

  final wrappedParameter = actual.parameter as SimpleFormalParameter;
  return wrappedParameter.name?.lexeme == expected.name &&
      wrappedParameter.type?.toSource() == expected.typeSource;
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
  return buildElementGuardrailViolation(
    context: context,
    sourceElement: sourceElement,
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
