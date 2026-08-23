// This guardrail owns only the stable edit-to-prepared-DTO declaration
// boundary. Direct Store and edit seams own accepted-finalization behavior.
// ignore_for_file: number-of-external-imports

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

void main() {
  test(
    'accepted edit preparation retains the sparse prepared DTO boundary',
    () {
      final unit = parseString(
        content: File('lib/src/edit/edit_kernel.dart').readAsStringSync(),
      ).unit;
      final preparer = unit.declarations
          .whereType<GenericTypeAlias>()
          .singleWhere(
            (declaration) => declaration.name.lexeme == 'SparseCommitPreparer',
          );

      expect(
        preparer.functionType?.returnType?.toSource(),
        'PreparedSparseStoreCommit',
      );
    },
  );
}
