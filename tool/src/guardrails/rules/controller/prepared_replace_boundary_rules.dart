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

enum _PreparedReplaceConstructorPolicy {
  none,
  forbidExplicitPublicConstructors,
  requireSingleUnnamedPublicConstructor,
}

typedef _PreparedReplaceOwnerDeclarationValidator =
    GuardrailViolation? Function({
      required _PreparedReplaceClassOwner owner,
      required GuardrailContext context,
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
  final topLevelViolation = validateExactPublicTopLevelSurface(
    context: context,
    library: resolved.element,
    allowedNames: spec.allowedTopLevelNames,
    requiredNames: spec.requiredTopLevelNames,
    buildViolation: _controllerPreparedReplaceViolation,
    unexpectedDetail: (unexpectedName) =>
        'prepared replace-scene boundary surface in $filePath must not add '
        'public top-level declaration "$unexpectedName".',
    missingDetail: (requiredName) =>
        'prepared replace-scene boundary surface in $filePath must keep '
        'public top-level declaration "$requiredName".',
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
    context: context,
  );
  if (declarationViolation != null) {
    return (owner: owner, violation: declarationViolation);
  }

  final constructorViolation = switch (constructorPolicy) {
    _PreparedReplaceConstructorPolicy.none => null,
    _PreparedReplaceConstructorPolicy.forbidExplicitPublicConstructors =>
      validateNoExplicitPublicConstructors(
        context: context,
        owner: owner.element,
        buildViolation: _controllerPreparedReplaceViolation,
        detail:
            '$ownerName must not add explicit public constructors on the '
            'prepared replace-scene boundary surface.',
      ),
    _PreparedReplaceConstructorPolicy.requireSingleUnnamedPublicConstructor =>
      validateSingleUnnamedPublicConstructor(
        context: context,
        owner: owner.element,
        buildViolation: _controllerPreparedReplaceViolation,
        detail:
            '$ownerName must keep exactly one unnamed public constructor on '
            'the prepared replace-scene boundary surface.',
      ),
  };
  if (constructorViolation != null) {
    return (owner: owner, violation: constructorViolation);
  }

  final memberViolation = validateExactPublicMemberSurface(
    context: context,
    owner: owner.element,
    allowedNames: allowedNames,
    requiredNames: requiredNames,
    buildViolation: _controllerPreparedReplaceViolation,
    unexpectedDetail: (member) =>
        '$detailPrefix must not add ${describePublicMemberSurface(member)}.',
    missingDetail: (requiredKey) =>
        '$detailPrefix must keep ${describePublicMemberSurfaceKey(requiredKey)}.',
  );
  return (owner: owner, violation: memberViolation);
}

SurfaceContractMethodSignatureSpec _snapshotOnlyPreparedReplaceMethodSpec(
  String detail,
) {
  return SurfaceContractMethodSignatureSpec(
    detail: detail,
    parameters: const <SurfaceContractParameterSpec>[
      SurfaceContractParameterSpec.positional(
        name: 'snapshot',
        typeSource: 'SceneSnapshot',
      ),
    ],
  );
}

SurfaceContractMethodSignatureSpec
_snapshotBeforeApplyPreparedReplaceMethodSpec(String detail) {
  return SurfaceContractMethodSignatureSpec(
    detail: detail,
    parameters: const <SurfaceContractParameterSpec>[
      SurfaceContractParameterSpec.positional(
        name: 'snapshot',
        typeSource: 'SceneSnapshot',
      ),
      SurfaceContractParameterSpec.requiredNamed(
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
    validateDeclaration: ({required owner, required context}) {
      if (owner.element.isAbstract && owner.element.isInterface) {
        return null;
      }
      return _controllerPreparedReplaceViolation(
        context: context,
        sourceElement: owner.element,
        detail:
            'SceneControllerCommittedMutationAccess must remain an abstract '
            'interface class.',
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
    validateDeclaration: ({required owner, required context}) {
      final interfaceViolation = validateExactImplementedInterfaces(
        context: context,
        owner: owner.element,
        exactInterfaces: const <SurfaceContractTypeIdentitySpec>[
          SurfaceContractTypeIdentitySpec(
            repoRelPath:
                '/lib/src/controller/scene_controller_committed_mutation_access.dart',
            typeName: 'SceneControllerCommittedMutationAccess',
          ),
        ],
        buildViolation: _controllerPreparedReplaceViolation,
        detail:
            'SceneStoreControllerCommittedMutationAccess must remain a final '
            'adapter implementing SceneControllerCommittedMutationAccess.',
      );
      if (owner.element.isFinal && interfaceViolation == null) {
        return null;
      }
      return _controllerPreparedReplaceViolation(
        context: context,
        sourceElement: owner.element,
        detail:
            'SceneStoreControllerCommittedMutationAccess must remain a final '
            'adapter implementing SceneControllerCommittedMutationAccess.',
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
  final interfaceSignatureViolation = validateExactMethodSignature(
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
  return validateExactMethodSignature(
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
    final classSignatureViolation = validateExactMethodSignature(
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
  if (!matchesTypeIdentity(
    context: context,
    element: committedExtensionElement.extendedType.element,
    spec: const SurfaceContractTypeIdentitySpec(
      repoRelPath: '/lib/src/controller/scene_store_controller.dart',
      typeName: 'SceneStoreController',
    ),
  )) {
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
  final extensionMemberViolation = validateExactPublicMemberSurface(
    context: context,
    owner: committedExtensionElement,
    allowedNames: const <String>{'method:writeReplaceScene'},
    buildViolation: _controllerPreparedReplaceViolation,
    unexpectedDetail: (member) =>
        'prepared replace-scene boundary owner '
        'SceneStoreControllerCommittedSceneReplacementAccess public member '
        'surface must not add ${describePublicMemberSurface(member)}.',
    missingDetail: (requiredKey) =>
        'prepared replace-scene boundary owner '
        'SceneStoreControllerCommittedSceneReplacementAccess public member '
        'surface must keep ${describePublicMemberSurfaceKey(requiredKey)}.',
  );
  if (extensionMemberViolation != null) {
    return extensionMemberViolation;
  }

  final writeReplaceScene = _firstMethodDeclarationNamed(
    committedExtensionDeclaration.members,
    'writeReplaceScene',
  );
  return validateExactMethodSignature(
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
  return validateExactMethodSignature(
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
