import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/load_interaction_boundary.dart';
import 'package:test/test.dart';

void main() {
  _testCommitDeliveryShape();
  _testResourceHandoffShape();
  _testDocumentAndFramePortShape();
  _testSelectionPortShape();
  _testLoadBoundaryShape();
  _testInternalContractsDoNotImportImplementationOwners();
}

void _testCommitDeliveryShape() {
  test('commit delivery is value-only and hides edit/store internals', () {
    final source = _contractSource('commit_delivery.dart');
    final unit = _parse(source);
    final touchedSet = _parse(_contractSource('touched_set.dart'));

    expect(
      _topLevelNames(unit),
      containsAll([
        'CommitDeliveryResult',
        'CommitDeliveryEffect',
        'CommitEffectObserver',
        'CommitApplyResultDelivery',
      ]),
    );
    expect(_topLevelNames(touchedSet), contains('TouchedSet'));
    expect(source, contains('final TouchedSet touchedSet'));
    expect(source, isNot(contains('CommitDeliveryTouchedFacts')));
    expect(source, isNot(contains('StoreRevisionDelta')));

    _expectOnlyFinalFields(unit, 'CommitDeliveryResult');
    _expectOnlyFinalFields(touchedSet, 'TouchedSet');
    _expectNoFunctionFields(touchedSet, 'TouchedSet');
    expect(source, contains('effects = List.unmodifiable(effects)'));
    expect(
      _contractSource('touched_set.dart'),
      contains('Set.unmodifiable(addedElementIds)'),
    );
  });
}

void _testResourceHandoffShape() {
  test('P7 resource handoff seams are declaration-only', () {
    final catalog = _contractSource('resource_catalog_port.dart');
    final dirtyOutcome = _contractSource('resource_dirty_outcome.dart');
    final resolverGuard = _contractSource('resolver_mutation_guard.dart');
    final catalogUnit = _parse(catalog);

    expect(_topLevelNames(catalogUnit), contains('ResourceCatalogPort'));
    _expectResourceCatalogPortShape(catalogUnit);
    _expectResourceCatalogImports(catalog);
    _expectResourceCatalogDoesNotNameImplementationOwners(catalog);

    expect(dirtyOutcome, contains('final class ResourceDirtyOutcome'));
    expect(dirtyOutcome, contains('Set<CanvasResourceId> dirtyResourceIds'));
    expect(dirtyOutcome, contains('final bool allResourcesDirty'));
    expect(dirtyOutcome, isNot(contains('ResourceKernel')));
    expect(dirtyOutcome, isNot(contains('SurfaceResourceSession')));

    _expectResolverGuardShape(resolverGuard);
  });
}

void _expectResolverGuardShape(String resolverGuard) {
  expect(
    resolverGuard,
    contains('abstract interface class ResolverMutationGuard'),
  );
  expect(resolverGuard, contains('final class ResolverCallbackRejection'));
  expect(resolverGuard, contains('extends StateError'));
  expect(resolverGuard, contains('runResolverCallback'));
  expect(resolverGuard, contains('ensureRuntimeMutationAllowed'));
  expect(resolverGuard, isNot(contains('ResourceKernel')));
  expect(resolverGuard, isNot(contains('CanvasRuntime')));
}

void _testDocumentAndFramePortShape() {
  test('document and frame fact ports are contract-owned', () {
    expect(
      _topLevelNames(_parse(_contractSource('document_facts_port.dart'))),
      containsAll(['DocumentFacts', 'DocumentFactsPort']),
    );
    expect(
      _topLevelNames(_parse(_contractSource('frame_facts_port.dart'))),
      containsAll([
        'FrameRevisionFacts',
        'FrameElementHandle',
        'FrameElementFacts',
        'FrameResourceDescriptorFacts',
        'FrameFactsPort',
      ]),
    );
    _expectFrameResourceDescriptorSeamShape(
      _parse(_contractSource('frame_facts_port.dart')),
    );
  });
}

void _testSelectionPortShape() {
  test('selection ports are contract-owned', () {
    expect(
      _topLevelNames(_parse(_contractSource('selection_facts_port.dart'))),
      containsAll(['SelectionFacts', 'SelectionFactsPort']),
    );
    expect(
      _topLevelNames(_parse(_contractSource('selection_membership_port.dart'))),
      contains('SelectionMembershipPort'),
    );
  });
}

void _testLoadBoundaryShape() {
  test('load boundary contract exposes prepared cleanup only', () {
    final boundary = _CompileTimeLoadBoundary();
    final loadBoundary = _parse(
      _contractSource('load_interaction_boundary.dart'),
    );

    expect(
      boundary.prepareLoadCleanup(),
      const LoadInteractionCleanupOutcome(previewChanged: true),
    );
    expect(
      _topLevelNames(loadBoundary),
      containsAll(['LoadInteractionCleanupOutcome', 'LoadInteractionBoundary']),
    );
    expect(
      _topLevelNames(loadBoundary),
      isNot(contains('_NoopLoadInteractionBoundary')),
    );
    expect(
      _contractSource('load_interaction_boundary.dart'),
      isNot(contains('noopLoadInteractionBoundary')),
    );

    _expectBoundaryMethodShape(loadBoundary);
    _expectLoadInteractionCleanupOutcomeShape(loadBoundary);
  });
}

void _testInternalContractsDoNotImportImplementationOwners() {
  test('internal contracts do not import API or implementation owners', () {
    final forbidden = RegExp(
      r"(\.\./api/|package:iwb_canvas_engine/src/api|"
      r"\.\./(runtime|edit|store|selection|codec|diagnostics|resources|frame|interaction|geometry|surface|flutter_bridge)/|"
      r"package:iwb_canvas_engine/src/(runtime|edit|store|selection|codec|diagnostics|resources|frame|interaction|geometry|surface|flutter_bridge))",
    );

    for (final file in Directory('lib/src/contracts/internal').listSync()) {
      if (file is! File || !file.path.endsWith('.dart')) {
        continue;
      }
      expect(file.readAsStringSync(), isNot(matches(forbidden)));
    }
  });
}

String _contractSource(String fileName) {
  return File('lib/src/contracts/internal/$fileName').readAsStringSync();
}

CompilationUnit _parse(String content) {
  return parseString(
    content: content,
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
}

Set<String> _topLevelNames(CompilationUnit unit) {
  return unit.declarations.map(_declarationName).nonNulls.toSet();
}

String? _declarationName(CompilationUnitMember declaration) {
  return switch (declaration) {
    ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
    EnumDeclaration(:final namePart) => namePart.typeName.lexeme,
    ExtensionDeclaration(:final name) => name?.lexeme,
    FunctionDeclaration(:final name) => name.lexeme,
    GenericTypeAlias(:final name) => name.lexeme,
    MixinDeclaration(:final name) => name.lexeme,
    TopLevelVariableDeclaration(:final variables) =>
      variables.variables.isEmpty
          ? null
          : variables.variables.first.name.lexeme,
    _ => null,
  };
}

void _expectOnlyFinalFields(CompilationUnit unit, String className) {
  final declaration = _classDeclaration(unit, className);
  final fields = declaration.body.members.whereType<FieldDeclaration>();

  expect(fields, isNotEmpty);
  for (final field in fields) {
    expect(field.fields.isFinal || field.fields.isConst, isTrue);
  }
}

void _expectNoFunctionFields(CompilationUnit unit, String className) {
  final declaration = _classDeclaration(unit, className);
  final fieldTypes = [
    for (final field in declaration.body.members.whereType<FieldDeclaration>())
      field.fields.type?.toSource() ?? '',
  ];

  expect(fieldTypes.any((type) => type.contains('Function')), isFalse);
}

void _expectBoundaryMethodShape(CompilationUnit unit) {
  final declaration = _classDeclaration(unit, 'LoadInteractionBoundary');
  final methods = declaration.body.members
      .whereType<MethodDeclaration>()
      .toList();

  expect(methods, hasLength(1));
  expect(methods.single.name.lexeme, 'prepareLoadCleanup');
  expect(
    methods.single.returnType?.toSource(),
    'LoadInteractionCleanupOutcome',
  );
}

void _expectResourceCatalogPortShape(CompilationUnit unit) {
  final declaration = _classDeclaration(unit, 'ResourceCatalogPort');
  final methods = declaration.body.members
      .whereType<MethodDeclaration>()
      .toList();
  final resourcesGetter = methods.singleWhere(
    (method) => method.name.lexeme == 'resources',
  );
  final countGetter = methods.singleWhere(
    (method) => method.name.lexeme == 'resourceCount',
  );
  final lookupMethod = methods.singleWhere(
    (method) => method.name.lexeme == 'resourceById',
  );

  expect(methods, hasLength(3));
  expect(countGetter.isGetter, isTrue);
  expect(countGetter.returnType?.toSource(), 'int');
  expect(resourcesGetter.isGetter, isTrue);
  expect(resourcesGetter.returnType?.toSource(), 'List<CanvasResource>');
  expect(lookupMethod.returnType?.toSource(), 'CanvasResource?');
  expect(
    lookupMethod.parameters?.parameters.single.toSource(),
    'CanvasResourceId id',
  );
}

void _expectResourceCatalogImports(String source) {
  final imports = RegExp(
    r"import '([^']+)';",
  ).allMatches(source).map((match) => match.group(1)).toSet();

  expect(imports, {
    '../public/canvas_ids.dart',
    '../public/canvas_resource.dart',
  });
}

void _expectResourceCatalogDoesNotNameImplementationOwners(String source) {
  const forbiddenNames = [
    'DocumentStoreKernel',
    'RuntimeRoot',
    'FrameFactsPort',
    'ResourceKernel',
    'SurfaceResourceSession',
    'Resolver',
    'resolver',
    'Cache',
    'cache',
    'callback',
    'Callback',
  ];

  for (final name in forbiddenNames) {
    expect(source, isNot(contains(name)));
  }
}

void _expectFrameResourceDescriptorSeamShape(CompilationUnit unit) {
  final declaration = _classDeclaration(unit, 'FrameFactsPort');
  final descriptorMethods = declaration.body.members
      .whereType<MethodDeclaration>()
      .where((method) => method.name.lexeme.contains('resourceDescriptor'))
      .toList();

  expect(descriptorMethods, hasLength(1));
  expect(descriptorMethods.single.name.lexeme, 'resourceDescriptor');
  expect(
    descriptorMethods.single.returnType?.toSource(),
    'FrameResourceDescriptorFacts?',
  );
}

void _expectLoadInteractionCleanupOutcomeShape(CompilationUnit unit) {
  final declaration = _classDeclaration(unit, 'LoadInteractionCleanupOutcome');

  _expectConstConstructor(declaration);
  _expectValueOnlyFields(declaration);
}

void _expectConstConstructor(ClassDeclaration declaration) {
  expect(
    declaration.body.members.whereType<ConstructorDeclaration>().any(
      (constructor) => constructor.constKeyword != null,
    ),
    isTrue,
  );
}

void _expectValueOnlyFields(ClassDeclaration declaration) {
  expect(declaration.body.members.whereType<MethodDeclaration>(), isEmpty);
  final fields = declaration.body.members
      .whereType<FieldDeclaration>()
      .toList();

  expect(fields, hasLength(greaterThanOrEqualTo(2)));
  for (final field in fields) {
    expect(field.fields.isFinal || field.fields.isConst, isTrue);
  }
  final fieldsByName = _fieldTypesByName(fields);
  expect(fieldsByName, containsPair('previewChanged', 'bool'));
  expect(
    fieldsByName,
    containsPair('noChange', 'LoadInteractionCleanupOutcome'),
  );
}

Map<String, String> _fieldTypesByName(List<FieldDeclaration> fields) {
  return {
    for (final field in fields)
      for (final variable in field.fields.variables)
        variable.name.lexeme: field.fields.type?.toSource() ?? '',
  };
}

final class _CompileTimeLoadBoundary implements LoadInteractionBoundary {
  @override
  LoadInteractionCleanupOutcome prepareLoadCleanup() {
    return const LoadInteractionCleanupOutcome(previewChanged: true);
  }
}

ClassDeclaration _classDeclaration(CompilationUnit unit, String className) {
  return unit.declarations.whereType<ClassDeclaration>().singleWhere(
    (declaration) => declaration.namePart.typeName.lexeme == className,
  );
}
