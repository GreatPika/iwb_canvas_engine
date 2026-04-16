part of 'write_only_mutation_rules.dart';

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
      owner.constructors
          .where(element_utils.isPublicConstructor)
          .toList(growable: false)
        ..sort(_compareElementsBySourceOrder);
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
  if (parameters.length != 1) {
    return _preparedReplaceSceneSignatureError(
      filePath: filePath,
      line: lineForOffset(parsed, member.offset),
      detail:
          'SceneWriter.writeDocumentReplace must keep the sealed single-phase '
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
