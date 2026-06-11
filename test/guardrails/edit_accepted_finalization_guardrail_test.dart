// This cohesive guardrail parses production ASTs and slices source markers in
// one route check; splitting imports across files would make the enforced edit
// migration order harder to audit than this localized file-metric exception.
// ignore_for_file: number-of-external-imports

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:characters/characters.dart';
import 'package:test/test.dart';

void main() {
  test('sparse accepted finalization stays bounded and store-owned', () {
    final units = _parseGuardedSources();
    final unit = units['lib/src/store/document_store_kernel.dart']!;
    final finalizationUnit =
        units['lib/src/store/store_commit_finalization.dart']!;
    final sparseAcceptedDeltaSurface = _transitiveTopLevelFunctions(
      unit,
      '_sparseAcceptedRevisionDelta',
    );
    final touchedFacts = _classDeclaration(
      unit,
      '_SparseTouchedCommittedFacts',
    );

    _expectAllMigrationSourcesAreParsed(units);
    _expectSparsePreparationUsesFinalizer(unit);
    _expectStorePreparationReturnsAcceptedDeltas(unit);
    _expectStorePreparationReturnsAcceptedTouchedFacts(unit, finalizationUnit);
    _expectEditRoutesCompileFromAcceptedFinalization(
      units['lib/src/edit/edit_kernel.dart']!,
    );
    _expectSparseAcceptedDeltaAvoidsFullDiff(sparseAcceptedDeltaSurface);
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

void _expectEditRoutesCompileFromAcceptedFinalization(
  CompilationUnit editKernelUnit,
) {
  final edit = _classMethod(editKernelUnit, 'EditKernel', 'edit');
  final prepareInteractionCommit = _classMethod(
    editKernelUnit,
    'EditKernel',
    'prepareInteractionCommit',
  );
  final acceptedCommitFor = _classMethod(
    editKernelUnit,
    'EditKernel',
    '_acceptedCommitFor',
  );
  final acceptedPreparedStoreCommit = _topLevelFunctionByName(
    editKernelUnit,
    '_acceptedPreparedStoreCommit',
  );

  _expectPublicEditRouteUsesAcceptedCommit(edit);
  _expectInteractionRouteUsesAcceptedCommit(prepareInteractionCommit);
  _expectAcceptedCommitSelectsFinalizer(acceptedCommitFor);
  _expectAcceptedStoreCommitCompilesAcceptedFacts(acceptedPreparedStoreCommit);
}

void _expectPublicEditRouteUsesAcceptedCommit(MethodDeclaration edit) {
  expect(edit.toSource(), contains('_acceptedCommitFor(session'));
  expect(edit.toSource(), isNot(contains('session.commitPlan')));
}

void _expectInteractionRouteUsesAcceptedCommit(
  MethodDeclaration prepareInteractionCommit,
) {
  expect(
    prepareInteractionCommit.toSource(),
    allOf(
      contains('_acceptedCommitFor(session'),
      contains('augmentPlan?.call(accepted.plan)'),
      isNot(contains('session.commitPlan')),
    ),
  );
}

void _expectAcceptedCommitSelectsFinalizer(
  MethodDeclaration acceptedCommitFor,
) {
  final source = acceptedCommitFor.toSource();
  expect(
    source,
    allOf(
      contains('_prepareMaterializedCommit'),
      contains('_prepareSparseCommit'),
      contains('session.didReplaceDraftDocument'),
    ),
  );
  _expectOnlyForcedReplacementCompilesSessionDelta(source);
  _expectOrdinaryBranchesUsePreparedAcceptedPayloads(source);
}

void _expectOnlyForcedReplacementCompilesSessionDelta(String source) {
  final replacementBranch = _substringBetween(
    source,
    'if (session.didReplaceDraftDocument) {',
    'final prepared = _prepareMaterializedCommit',
  );
  final ordinaryTail = _substringFrom(
    source,
    source.indexOf('final prepared = _prepareMaterializedCommit'),
  );

  expect(replacementBranch, contains('CommitCompiler().compile'));
  expect(replacementBranch, contains('revisionDelta: session.revisionDelta'));
  expect(ordinaryTail, isNot(contains('CommitCompiler().compile')));
  expect(ordinaryTail, isNot(contains('revisionDelta: session.revisionDelta')));
  expect(ordinaryTail, isNot(contains('session.commitPlan')));
}

void _expectOrdinaryBranchesUsePreparedAcceptedPayloads(String source) {
  final materializedBranch = _substringBetween(
    source,
    'final prepared = _prepareMaterializedCommit',
    'final prepared = _prepareSparseCommit',
  );
  final sparseBranch = _substringFrom(
    source,
    source.indexOf('final prepared = _prepareSparseCommit'),
  );

  expect(materializedBranch, contains('revisionDelta: prepared.revisionDelta'));
  expect(materializedBranch, contains('touchedFacts: prepared.touchedFacts'));
  expect(sparseBranch, contains('revisionDelta: prepared.revisionDelta'));
  expect(sparseBranch, contains('touchedFacts: prepared.touchedFacts'));
}

void _expectAcceptedStoreCommitCompilesAcceptedFacts(
  FunctionDeclaration acceptedPreparedStoreCommit,
) {
  expect(
    acceptedPreparedStoreCommit.toSource(),
    allOf(
      contains('revisionDelta: input.revisionDelta'),
      contains('_touchedSetForAcceptedFacts'),
      isNot(contains('session.commitPlan')),
    ),
  );
}

String _substringBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, isNonNegative, reason: 'expected start marker: $start');
  expect(endIndex, isNonNegative, reason: 'expected end marker: $end');

  return source.characters.getRange(startIndex, endIndex).toString();
}

String _substringFrom(String source, int startIndex) {
  expect(startIndex, isNonNegative, reason: 'expected substring start marker');

  return source.characters.getRange(startIndex).toString();
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
    allOf(
      contains('_sparseAcceptedRevisionDelta'),
      contains('_validateSparseRevisionCoverage'),
    ),
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
      contains('final acceptedDelta = didMutateFacts'),
      contains('_sparseAcceptedRevisionDelta'),
      contains('_validateSparseRevisionCoverage'),
      contains('acceptedDelta.advance(_document.revisions)'),
      contains('revisionDelta: accepted ? acceptedDelta'),
      isNot(contains('revisionDelta: accepted ? revisionDelta')),
    ),
    reason: 'sparse commits must not publish provisional delta as accepted',
  );
}

void _expectSparseAcceptedDeltaAvoidsFullDiff(
  List<FunctionDeclaration> acceptedDeltaSurface,
) {
  final invocations = _combinedMethodInvocations(acceptedDeltaSurface);

  expect(
    acceptedDeltaSurface.map((function) => function.name.lexeme),
    containsAll({
      '_sparseAcceptedRevisionDelta',
      '_sameTouchedResources',
      '_sparseTouchedElementRevisionDelta',
    }),
    reason: 'guardrail must inspect delegated sparse accepted-delta helpers',
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
    _combinedCreatedTypeNames(acceptedDeltaSurface),
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
      contains('bool allElements'),
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

FunctionDeclaration _topLevelFunctionByName(
  CompilationUnit unit,
  String functionName,
) {
  return unit.declarations.whereType<FunctionDeclaration>().singleWhere((
    declaration,
  ) {
    return declaration.name.lexeme == functionName;
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
