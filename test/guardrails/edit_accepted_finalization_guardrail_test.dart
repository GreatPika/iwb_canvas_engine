// This guardrail owns only stable edit-to-prepared-DTO boundaries. Guarantee
// transfer is deliberately non-executable: direct Store evidence owns
// candidate finalization order, accepted facts, and publication work in
// test/store/store_transaction_candidate_test.dart; no-projection remains in
// test/store/no_projection_hot_path_test.dart; direct Store compatibility
// remains in test/store/sparse_store_commit_test.dart.
// ignore_for_file: number-of-external-imports

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:characters/characters.dart';
import 'package:test/test.dart';

void main() {
  test('accepted edit routes retain the prepared DTO boundary', () {
    final editKernel = parseString(
      content: File('lib/src/edit/edit_kernel.dart').readAsStringSync(),
    ).unit;

    expect(editKernel.declarations, isNotEmpty);
    _expectEditRoutesCompileFromAcceptedFinalization(editKernel);
  });
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

  expect(edit.toSource(), contains('_acceptedCommitFor(session'));
  expect(edit.toSource(), isNot(contains('session.commitPlan')));
  expect(
    prepareInteractionCommit.toSource(),
    allOf(
      contains('_acceptedCommitFor(session'),
      contains('augmentPlan?.call(accepted.plan)'),
      isNot(contains('session.commitPlan')),
    ),
  );

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
  _expectAcceptedPreparedStoreCommitBoundary(acceptedPreparedStoreCommit);
}

void _expectAcceptedPreparedStoreCommitBoundary(
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

MethodDeclaration _classMethod(
  CompilationUnit unit,
  String className,
  String methodName,
) {
  final declaration = unit.declarations
      .whereType<ClassDeclaration>()
      .singleWhere(
        (candidate) => candidate.namePart.typeName.lexeme == className,
      );
  return declaration.body.members.whereType<MethodDeclaration>().singleWhere(
    (method) => method.name.lexeme == methodName,
  );
}

FunctionDeclaration _topLevelFunctionByName(
  CompilationUnit unit,
  String functionName,
) => unit.declarations.whereType<FunctionDeclaration>().singleWhere(
  (declaration) => declaration.name.lexeme == functionName,
);
