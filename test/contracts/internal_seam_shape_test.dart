import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
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

    expect(
      _topLevelNames(unit),
      containsAll([
        'CommitDeliveryResult',
        'CommitDeliveryEffect',
        'CommitDeliveryTouchedFacts',
        'CommitEffectObserver',
        'CommitApplyResultDelivery',
      ]),
    );
    expect(source, isNot(contains('TouchedSet')));
    expect(source, isNot(contains('StoreRevisionDelta')));

    _expectOnlyFinalFields(unit, 'CommitDeliveryResult');
    _expectOnlyFinalFields(unit, 'CommitDeliveryTouchedFacts');
    _expectNoFunctionFields(unit, 'CommitDeliveryTouchedFacts');
    expect(source, contains('effects = List.unmodifiable(effects)'));
    expect(source, contains('Set.unmodifiable(addedElementIds)'));
  });
}

void _testResourceHandoffShape() {
  test('P7 resource handoff seams are declaration-only', () {
    final dirtyOutcome = _contractSource('resource_dirty_outcome.dart');
    final resolverGuard = _contractSource('resolver_mutation_guard.dart');

    expect(dirtyOutcome, contains('final class ResourceDirtyOutcome'));
    expect(dirtyOutcome, contains('Set<CanvasResourceId> dirtyResourceIds'));
    expect(dirtyOutcome, contains('final bool allResourcesDirty'));
    expect(dirtyOutcome, isNot(contains('ResourceKernel')));
    expect(dirtyOutcome, isNot(contains('SurfaceResourceSession')));

    expect(
      resolverGuard,
      contains('abstract interface class ResolverMutationGuard'),
    );
    expect(resolverGuard, contains('runResolverCallback'));
    expect(resolverGuard, contains('ensureRuntimeMutationAllowed'));
    expect(resolverGuard, isNot(contains('ResourceKernel')));
    expect(resolverGuard, isNot(contains('CanvasRuntime')));
  });
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
  test('load boundary contract has no noop implementation', () {
    final loadBoundarySource = _contractSource(
      'load_interaction_boundary.dart',
    );
    final loadBoundary = _parse(loadBoundarySource);

    expect(
      _topLevelNames(loadBoundary),
      containsAll(['PointerCleanupOutcome', 'LoadInteractionBoundary']),
    );
    expect(
      _topLevelNames(loadBoundary),
      isNot(contains('_NoopLoadInteractionBoundary')),
    );
    expect(loadBoundarySource, isNot(contains('noopLoadInteractionBoundary')));
  });
}

void _testInternalContractsDoNotImportImplementationOwners() {
  test('internal contracts do not import API or implementation owners', () {
    final forbidden = RegExp(
      r"(\.\./api/|package:iwb_canvas_engine/src/api|"
      r"\.\./(runtime|edit|store|selection|codec|diagnostics|resources|frame|interaction|spatial|flutter_bridge)/|"
      r"package:iwb_canvas_engine/src/(runtime|edit|store|selection|codec|diagnostics|resources|frame|interaction|spatial|flutter_bridge))",
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

ClassDeclaration _classDeclaration(CompilationUnit unit, String className) {
  return unit.declarations.whereType<ClassDeclaration>().singleWhere(
    (declaration) => declaration.namePart.typeName.lexeme == className,
  );
}
