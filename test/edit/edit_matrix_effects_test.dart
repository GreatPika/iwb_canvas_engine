import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

import '../support/flutter_in_package_test_harness.dart';

void main() {
  test('edit document and resource rows install through the store', () {
    return expectLater(
      runFlutterInPackageTest(
        'test/edit/fixtures/edit_matrix_effects_fixture.dart',
      ),
      completes,
    );
  });

  test('edit operation matrix fixture covers every edit-owned row', () {
    expect(
      _operationMatrixRowsCoveredByFixture(),
      _editOwnedRowsFromOperationMatrix(),
    );
    expect(_implementedEditMethodsMissingFromOperationMatrix(), isEmpty);
  });

  test('updateElement taxonomy fixture covers every field token', () {
    expect(
      _updateTaxonomyTokensCoveredByFixture(),
      _updateElementTaxonomyTokens(),
    );
  });
}

Set<String> _operationMatrixRowsCoveredByFixture() {
  final source = File(
    'test/edit/fixtures/edit_matrix_effects_fixture.dart',
  ).readAsStringSync();
  final rowPattern = RegExp(r"_EditOperationMatrixCase\(\s*'([^']+)'");

  return {for (final match in rowPattern.allMatches(source)) ?match.group(1)};
}

Set<String> _updateTaxonomyTokensCoveredByFixture() {
  final source = File(
    'test/edit/fixtures/edit_matrix_effects_fixture.dart',
  ).readAsStringSync();
  final tokenPattern = RegExp(r"_UpdateTaxonomyCase\(\s*'([^']+)'");

  return {for (final match in tokenPattern.allMatches(source)) ?match.group(1)};
}

Set<String> _editOwnedRowsFromOperationMatrix() {
  final rows = _operationMatrixOperationRows();
  final editMethods = _implementedEditMutationNames();

  return {
    for (final row in rows)
      if (_isEditOwnedOperationRow(row, editMethods)) row,
  };
}

Set<String> _implementedEditMethodsMissingFromOperationMatrix() {
  final rows = _operationMatrixOperationRows();

  return {
    for (final method in _implementedEditMutationNames())
      if (!_operationRowsContainEditMethod(rows, method)) method,
  };
}

bool _isEditOwnedOperationRow(String row, Set<String> editMethods) {
  if (row == 'no-op edit') {
    return true;
  }

  final method = _editMethodNameFromOperationRow(row);

  return method != null && editMethods.contains(method);
}

bool _operationRowsContainEditMethod(Set<String> rows, String method) {
  return rows.any((row) => _editMethodNameFromOperationRow(row) == method);
}

String? _editMethodNameFromOperationRow(String row) {
  const qualifiedPrefix = 'CanvasEdit.';
  final operation = row.startsWith(qualifiedPrefix)
      ? row.substring(qualifiedPrefix.length)
      : row;
  final method = operation.split(' ').first;
  if (!RegExp(r'^[a-z][A-Za-z0-9]+$').hasMatch(method)) {
    return null;
  }

  return method;
}

Set<String> _operationMatrixOperationRows() {
  final source = File('docs/contracts/operation_matrix.md').readAsStringSync();
  final tableStart = source.indexOf('| Operation | State touched |');
  final tableEnd = source.indexOf('\nNotes:', tableStart);

  return _markdownTableFirstColumnFromSource(
    source.substring(tableStart, tableEnd),
  );
}

Set<String> _implementedEditMutationNames() {
  final apiSource = File(
    'lib/src/contracts/public/canvas_runtime.dart',
  ).readAsStringSync();
  final unsupported = _unsupportedEditMethods();

  return {
    for (final method in _canvasEditMethodNames(apiSource))
      if (!_readOnlyEditMethods.contains(method) &&
          !unsupported.contains(method))
        method,
  };
}

Set<String> _unsupportedEditMethods() {
  final source = File('lib/src/edit/edit_session.dart').readAsStringSync();
  final unsupportedPattern = RegExp(
    r'CanvasEdit\.([A-Za-z0-9_]+) is owned by ',
  );

  return _firstCaptureGroups(unsupportedPattern, source);
}

Set<String> _firstCaptureGroups(RegExp pattern, String source) {
  final values = <String>{};
  for (final match in pattern.allMatches(source)) {
    final value = match.group(1);
    if (value != null) {
      values.add(value);
    }
  }

  return values;
}

Set<String> _updateElementTaxonomyTokens() {
  final source = File('docs/contracts/edit_kernel.md').readAsStringSync();
  final taxonomyStart = source.indexOf('Field taxonomy:');
  final taxonomyEnd = source.indexOf(
    '`CommitCompiler` may implement',
    taxonomyStart,
  );
  final taxonomy = source.substring(taxonomyStart, taxonomyEnd);
  final rows = _markdownTableFirstColumnFromSource(taxonomy);
  final tokenPattern = RegExp(r'`([^`]+)`');

  return {
    for (final row in rows)
      for (final match in tokenPattern.allMatches(row)) ?match.group(1),
  };
}

Set<String> _markdownTableFirstColumnFromSource(String source) {
  return {
    for (final line in source.split('\n'))
      if (line.startsWith('| ') &&
          !line.startsWith('|---') &&
          !line.startsWith('| Operation ') &&
          !line.startsWith('| Field token '))
        line.split('|')[1].trim(),
  };
}

Set<String> _canvasEditMethodNames(String source) {
  final unit = parseString(content: source).unit;
  final declaration = unit.declarations
      .whereType<ClassDeclaration>()
      .firstWhere((node) => node.namePart.typeName.lexeme == 'CanvasEdit');

  return {
    for (final member
        in declaration.body.members.whereType<MethodDeclaration>())
      if (!member.isGetter && !member.isSetter) member.name.lexeme,
  };
}

const _readOnlyEditMethods = {'readDraftDocument'};
