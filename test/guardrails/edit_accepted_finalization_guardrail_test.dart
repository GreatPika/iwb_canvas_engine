import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

void main() {
  test('sparse accepted finalization stays bounded and store-owned', () {
    final units = _parseGuardedSources();
    final unit = units['lib/src/store/document_store_kernel.dart']!;
    final finalizationUnit =
        units['lib/src/store/store_commit_finalization.dart']!;
    final sparseFinalizerSurface = _transitiveTopLevelFunctions(
      unit,
      '_sameSparseTouchedCommittedFacts',
    );
    final touchedFacts = _classDeclaration(
      unit,
      '_SparseTouchedCommittedFacts',
    );

    _expectAllMigrationSourcesAreParsed(units);
    _expectSparsePreparationUsesFinalizer(unit);
    _expectStorePreparationReturnsAcceptedDeltas(unit);
    _expectStorePreparationReturnsAcceptedTouchedFacts(unit, finalizationUnit);
    _expectSparseFinalizerAvoidsFullDiff(sparseFinalizerSurface);
    _expectTouchedFactsAreBounded(touchedFacts);
    expect(_forbiddenOwnerImports(unit), isEmpty);
    expect(_forbiddenOwnerImports(finalizationUnit), isEmpty);
  });
}

Map<String, CompilationUnit> _parseGuardedSources() {
  const paths = [
    'lib/src/edit/edit_kernel.dart',
    'lib/src/edit/edit_session.dart',
    'lib/src/edit/draft_document.dart',
    'lib/src/store/sparse_store_commit.dart',
    'lib/src/store/document_store_kernel.dart',
    'lib/src/store/store_commit_finalization.dart',
  ];

  return {
    for (final path in paths)
      path: parseString(content: File(path).readAsStringSync()).unit,
  };
}

void _expectAllMigrationSourcesAreParsed(Map<String, CompilationUnit> units) {
  expect(
    units.keys,
    unorderedEquals({
      'lib/src/edit/edit_kernel.dart',
      'lib/src/edit/edit_session.dart',
      'lib/src/edit/draft_document.dart',
      'lib/src/store/sparse_store_commit.dart',
      'lib/src/store/document_store_kernel.dart',
      'lib/src/store/store_commit_finalization.dart',
    }),
  );
}

void _expectStorePreparationReturnsAcceptedTouchedFacts(
  CompilationUnit storeUnit,
  CompilationUnit finalizationUnit,
) {
  final prepareMaterializedCommit = _classMethod(
    storeUnit,
    'DocumentStoreKernel',
    'prepareMaterializedCommit',
  );
  final prepareSparseCommit = _classMethod(
    storeUnit,
    'DocumentStoreKernel',
    'prepareSparseCommit',
  );
  final finalizationSource = finalizationUnit.toSource();

  expect(finalizationSource, contains('final AcceptedStoreTouchedFacts'));
  expect(
    finalizationSource,
    contains('final AcceptedStoreTouchedFacts touchedFacts'),
  );
  expect(
    prepareMaterializedCommit.toSource(),
    allOf(
      contains('touchedFacts: AcceptedStoreTouchedFacts.empty()'),
      contains('touchedFacts: _committedDocumentTouchedFacts'),
    ),
  );
  expect(
    prepareSparseCommit.toSource(),
    allOf(
      contains('touchedFacts: accepted'),
      contains('_sparseAcceptedTouchedFacts'),
      contains('AcceptedStoreTouchedFacts.empty()'),
    ),
  );
}

void _expectSparsePreparationUsesFinalizer(CompilationUnit unit) {
  final prepareSparseCommit = _classMethod(
    unit,
    'DocumentStoreKernel',
    'prepareSparseCommit',
  );

  expect(
    _methodInvocations(prepareSparseCommit),
    contains('_sameSparseTouchedCommittedFacts'),
  );
}

void _expectStorePreparationReturnsAcceptedDeltas(CompilationUnit unit) {
  final prepareMaterializedCommit = _classMethod(
    unit,
    'DocumentStoreKernel',
    'prepareMaterializedCommit',
  );
  final prepareSparseCommit = _classMethod(
    unit,
    'DocumentStoreKernel',
    'prepareSparseCommit',
  );

  expect(
    prepareMaterializedCommit.toSource(),
    allOf(
      contains('_committedDocumentRevisionDelta'),
      contains('revisionDelta: acceptedDelta'),
      isNot(contains('revisionDelta: providedDelta')),
    ),
    reason: 'materialized commits must derive accepted delta from final facts',
  );
  expect(
    prepareSparseCommit.toSource(),
    allOf(
      contains('final acceptedDelta = finalNoOp'),
      contains('acceptedDelta.advance(_document.revisions)'),
      contains('revisionDelta: accepted ? acceptedDelta'),
      isNot(contains('revisionDelta: accepted ? revisionDelta')),
    ),
    reason: 'sparse commits must not publish provisional delta as accepted',
  );
}

void _expectSparseFinalizerAvoidsFullDiff(
  List<FunctionDeclaration> finalizerSurface,
) {
  final invocations = _combinedMethodInvocations(finalizerSurface);

  expect(
    finalizerSurface.map((function) => function.name.lexeme),
    containsAll({
      '_sameSparseTouchedCommittedFacts',
      '_sameTouchedResources',
      '_sameTouchedElements',
    }),
    reason: 'guardrail must inspect delegated sparse finalizer helpers',
  );
  expect(
    invocations,
    isNot(contains('_sameCommittedDocumentFacts')),
    reason: 'ordinary sparse finalization must not use the full document diff',
  );
  expect(
    invocations,
    isNot(contains('readDocument')),
    reason: 'ordinary sparse finalization must not build public projection',
  );
  expect(
    _combinedCreatedTypeNames(finalizerSurface),
    isNot(contains('DocumentProjectionCache')),
  );
}

void _expectTouchedFactsAreBounded(ClassDeclaration touchedFacts) {
  expect(
    touchedFacts.toSource(),
    allOf(
      contains('Set<CanvasElementId> elementIds'),
      contains('Set<CanvasLayerId> layerIds'),
      contains('Set<CanvasResourceId> resourceIds'),
    ),
    reason: 'sparse finalization must be bounded by candidate-touched facts',
  );
}

MethodDeclaration _classMethod(
  CompilationUnit unit,
  String className,
  String methodName,
) {
  final declaration = _classDeclaration(unit, className);

  return declaration.body.members.whereType<MethodDeclaration>().singleWhere((
    method,
  ) {
    return method.name.lexeme == methodName;
  });
}

ClassDeclaration _classDeclaration(CompilationUnit unit, String className) {
  return unit.declarations.whereType<ClassDeclaration>().singleWhere((
    declaration,
  ) {
    return declaration.namePart.typeName.lexeme == className;
  });
}

List<FunctionDeclaration> _transitiveTopLevelFunctions(
  CompilationUnit unit,
  String rootName,
) {
  final functions = {
    for (final declaration
        in unit.declarations.whereType<FunctionDeclaration>())
      declaration.name.lexeme: declaration,
  };
  final pending = <String>[rootName];
  final visited = <String>{};
  while (pending.isNotEmpty) {
    final name = pending.removeLast();
    if (!visited.add(name)) {
      continue;
    }
    final function = functions[name];
    if (function == null) {
      continue;
    }
    pending.addAll(
      _methodInvocations(
        function,
      ).where((invocation) => functions.containsKey(invocation)),
    );
  }

  return [for (final name in visited) ?functions[name]];
}

Set<String> _methodInvocations(AstNode node) {
  final visitor = _MethodInvocationVisitor();
  node.accept(visitor);

  return visitor.invocations;
}

Set<String> _createdTypeNames(AstNode node) {
  final visitor = _InstanceCreationVisitor();
  node.accept(visitor);

  return visitor.typeNames;
}

Set<String> _combinedMethodInvocations(Iterable<AstNode> nodes) {
  return {for (final node in nodes) ..._methodInvocations(node)};
}

Set<String> _combinedCreatedTypeNames(Iterable<AstNode> nodes) {
  return {for (final node in nodes) ..._createdTypeNames(node)};
}

Set<String> _forbiddenOwnerImports(CompilationUnit unit) {
  const forbiddenSegments = {'/runtime/', '/frame/', '/selection/'};

  return {
    for (final uri
        in unit.directives
            .whereType<ImportDirective>()
            .map((directive) => directive.uri.stringValue)
            .nonNulls)
      if (forbiddenSegments.any(uri.contains)) uri,
  };
}

final class _MethodInvocationVisitor extends RecursiveAstVisitor<void> {
  final Set<String> invocations = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node.methodName.name);
    super.visitMethodInvocation(node);
  }
}

final class _InstanceCreationVisitor extends RecursiveAstVisitor<void> {
  final Set<String> typeNames = {};

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    typeNames.add(node.constructorName.type.name.lexeme);
    super.visitInstanceCreationExpression(node);
  }
}
